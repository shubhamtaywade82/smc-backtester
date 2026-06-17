# frozen_string_literal: true

require_relative '../../indicators/supertrend'

module SMC
  module Strategy
    class SupertrendPullbackStrategy < Base
      PLAYBOOK = 'ST-Pullback'

      attr_reader :period, :multiplier, :htf_group_size, :proximity_threshold_pct,
                  :enable_pullback, :enable_flip_entry, :take_profit_risk_multiple

      def initialize(
        period: 10,
        multiplier: 3.0,
        htf_group_size: 12,
        proximity_threshold_pct: 0.002,
        enable_pullback: true,
        enable_flip_entry: true,
        take_profit_risk_multiple: 3.0
      )
        super(name: 'Supertrend Pullback')
        @period = period.to_i
        @multiplier = multiplier.to_f
        @htf_group_size = htf_group_size.to_i
        @proximity_threshold_pct = proximity_threshold_pct.to_f
        @enable_pullback = enable_pullback
        @enable_flip_entry = enable_flip_entry
        @take_profit_risk_multiple = take_profit_risk_multiple.to_f
        @ltf_supertrend = SMC::Indicators::Supertrend.new(period: @period, multiplier: @multiplier)
        @htf_supertrend = SMC::Indicators::Supertrend.new(period: @period, multiplier: @multiplier)
        reset_cache!
      end

      def evaluate(candles, current_idx, _pivot_detector, _market_structure, _liquidity_sweep, _ob_detector)
        reset_cache! if cache_stale?(candles)

        ltf_series = ltf_indicator_series(candles)
        return nil if current_idx < 2 || ltf_series[current_idx].nil? || ltf_series[current_idx - 1].nil?

        htf_context = htf_alignment_at(candles, current_idx)
        return nil if htf_context.nil?

        signal_kind = entry_signal_kind(
          ltf_candles: candles,
          current_idx: current_idx,
          ltf_series: ltf_series,
          htf_indicator: htf_context[:indicator]
        )
        return nil unless signal_kind

        build_trade_signal(
          signal_kind: signal_kind,
          entry: candles[current_idx].close,
          stop: ltf_series[current_idx][:line]
        )
      end

      def pullback?(candle, previous_candle, ltf_indicator)
        return false unless candle && previous_candle && ltf_indicator

        if ltf_indicator[:trend] == :long
          distance = (previous_candle.low - ltf_indicator[:line]) / ltf_indicator[:line]
        else
          distance = (ltf_indicator[:line] - previous_candle.high) / ltf_indicator[:line]
        end

        distance.abs <= @proximity_threshold_pct
      end

      private

      def cache_stale?(candles)
        @cache_key != [candles.object_id, candles.length]
      end

      def reset_cache!
        @cache_key = nil
        @ltf_series = nil
        @htf_candles = nil
        @htf_series = nil
        @htf_alignments = nil
      end

      def ltf_indicator_series(candles)
        @cache_key = [candles.object_id, candles.length]
        @ltf_series ||= @ltf_supertrend.compute(candles)
      end

      def htf_candles(candles)
        @htf_candles ||= aggregate_candles(candles, @htf_group_size)
      end

      def htf_indicator_series(candles)
        @htf_series ||= @htf_supertrend.compute(htf_candles(candles))
      end

      def htf_alignment_at(candles, index)
        htf_alignment_series(candles)[index]
      end

      def htf_alignment_series(candles)
        @htf_alignments ||= align_timeframes(
          candles,
          htf_candles(candles),
          htf_indicator_series(candles)
        )
      end

      def align_timeframes(ltf_candles, htf_candles, htf_indicators)
        alignments = []
        htf_index = 0

        ltf_candles.each do |ltf_candle|
          while htf_index + 1 < htf_candles.size &&
                candle_epoch(htf_candles[htf_index + 1]) <= candle_epoch(ltf_candle)
            htf_index += 1
          end

          if htf_index < htf_candles.size && candle_epoch(htf_candles[htf_index]) <= candle_epoch(ltf_candle)
            alignments << { candle: htf_candles[htf_index], indicator: htf_indicators[htf_index] }
          else
            alignments << nil
          end
        end

        alignments
      end

      def entry_signal_kind(ltf_candles:, current_idx:, ltf_series:, htf_indicator:)
        return nil if htf_indicator.nil?

        current_candle = ltf_candles[current_idx]
        previous_candle = ltf_candles[current_idx - 1]
        latest_ltf = ltf_series[current_idx]
        previous_ltf = ltf_series[current_idx - 1]
        trend_bias = htf_indicator[:trend]
        trend_flip = previous_ltf[:trend] != latest_ltf[:trend]

        if trend_bias == :long && latest_ltf[:trend] == :long
          return :long_flip if @enable_flip_entry && trend_flip
          return :long_pullback if pullback_entry?(:long, current_candle, previous_candle, latest_ltf)
        elsif trend_bias == :short && latest_ltf[:trend] == :short
          return :short_flip if @enable_flip_entry && trend_flip
          return :short_pullback if pullback_entry?(:short, current_candle, previous_candle, latest_ltf)
        end

        nil
      end

      def pullback_entry?(side, current_candle, previous_candle, latest_ltf)
        return false unless @enable_pullback

        if side == :long
          distance = (previous_candle.low - latest_ltf[:line]) / latest_ltf[:line]
          distance.abs <= @proximity_threshold_pct && current_candle.close > previous_candle.high
        else
          distance = (latest_ltf[:line] - previous_candle.high) / latest_ltf[:line]
          distance.abs <= @proximity_threshold_pct && current_candle.close < previous_candle.low
        end
      end

      def build_trade_signal(signal_kind:, entry:, stop:)
        side = signal_kind.to_s.start_with?('long') ? :long : :short
        risk = (entry - stop).abs
        return nil if risk.zero?

        take_profit = entry + (risk * @take_profit_risk_multiple * (side == :long ? 1 : -1))
        tp1 = entry + (risk * (side == :long ? 1 : -1))
        tp2 = entry + (risk * 2 * (side == :long ? 1 : -1))

        {
          type: side,
          playbook: PLAYBOOK,
          entry: entry,
          sl: stop,
          tp1: tp1,
          tp2: tp2,
          tp3: take_profit,
          risk_reward: @take_profit_risk_multiple,
          rules_checked: {
            playbook: PLAYBOOK,
            signal: signal_kind,
            htf_trend: side == :long ? :long : :short,
            ltf_trend: side == :long ? :long : :short
          }
        }
      end

      def aggregate_candles(candles, group_size)
        aggregated = []
        candles.each_slice(group_size) do |slice|
          next if slice.size < group_size

          aggregated << SMC::Candle.new(
            time: slice.first.time,
            open: slice.first.open,
            high: slice.map(&:high).max,
            low: slice.map(&:low).min,
            close: slice.last.close,
            volume: slice.map(&:volume).sum
          )
        end
        aggregated
      end

      def candle_epoch(candle)
        candle.time.is_a?(Time) ? candle.time.to_i : candle.time.to_i
      end
    end
  end
end
