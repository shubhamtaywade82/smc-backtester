# frozen_string_literal: true

module SMC
  module Strategy
    class SweepOB < Base
      PLAYBOOK = 'PB7'

      attr_reader :lookback_candles, :min_risk_reward, :require_strong_level, :require_entry_confirmation

      def initialize(
        lookback_candles: 20,
        min_risk_reward: 3.0,
        require_strong_level: true,
        require_entry_confirmation: true
      )
        super(name: 'PB7: Sweep + OB')
        @lookback_candles = lookback_candles
        @min_risk_reward = min_risk_reward.to_f
        @require_strong_level = require_strong_level
        @require_entry_confirmation = require_entry_confirmation
      end

      def evaluate(candles, current_idx, _pivot_detector, market_structure, liquidity_sweep, ob_detector)
        current_candle = candles[current_idx]

        evaluate_long(
          candles,
          current_idx,
          current_candle,
          market_structure,
          liquidity_sweep,
          ob_detector
        ) || evaluate_short(
          candles,
          current_idx,
          current_candle,
          market_structure,
          liquidity_sweep,
          ob_detector
        )
      end

      private

      def evaluate_long(candles, current_idx, current_candle, market_structure, liquidity_sweep, ob_detector)
        return nil unless market_structure.trend == :BULLISH

        sweep = recent_sweep(liquidity_sweep, current_idx, :ssl_sweep)
        return nil unless sweep

        return nil unless pb7_structure_sequence?(
          sweep,
          market_structure.choch_events,
          market_structure.bos_events,
          direction: :bullish
        )

        choch = latest_choch_after(sweep, market_structure.choch_events, :bullish)
        return nil unless choch

        bos = structure_break_after(
          market_structure.bos_events,
          sweep[:index],
          direction: :bullish,
          after_index: choch[:index]
        )
        return nil unless bos

        active_obs = bullish_obs_for_pb7(ob_detector, current_idx, choch[:index], bos[:index])
        return nil if active_obs.empty?

        matching_ob = active_obs.find { |ob| ob_retest?(current_candle, ob, direction: :long) }
        return nil unless matching_ob

        protected_low = protected_level_price(market_structure.protected_low, sweep[:price])
        return nil if @require_strong_level && protected_low.nil?

        dealing = dealing_range(
          low_price: protected_low || sweep[:price],
          high_price: market_structure.protected_high&.fetch(:price, nil) || current_candle.high
        )
        return nil unless in_discount?(current_candle.close, dealing)

        return nil unless entry_confirmed?(candles, current_idx, direction: :long)

        build_signal(
          type: :long,
          entry: current_candle.close,
          ob: matching_ob,
          sweep_price: sweep[:price],
          protected_level: protected_low,
          dealing: dealing,
          rules_checked: {
            playbook: PLAYBOOK,
            trend_bullish: true,
            ssl_sweep: true,
            bullish_choch: true,
            bullish_bos: true,
            strong_low: !@require_strong_level || !protected_low.nil?,
            ob_exists: true,
            ob_retest: true,
            in_discount: true,
            entry_confirmation: true
          }
        )
      end

      def evaluate_short(candles, current_idx, current_candle, market_structure, liquidity_sweep, ob_detector)
        return nil unless market_structure.trend == :BEARISH

        sweep = recent_sweep(liquidity_sweep, current_idx, :bsl_sweep)
        return nil unless sweep

        return nil unless pb7_structure_sequence?(
          sweep,
          market_structure.choch_events,
          market_structure.bos_events,
          direction: :bearish
        )

        choch = latest_choch_after(sweep, market_structure.choch_events, :bearish)
        return nil unless choch

        bos = structure_break_after(
          market_structure.bos_events,
          sweep[:index],
          direction: :bearish,
          after_index: choch[:index]
        )
        return nil unless bos

        active_obs = bearish_obs_for_pb7(ob_detector, current_idx, choch[:index], bos[:index])
        return nil if active_obs.empty?

        matching_ob = active_obs.find { |ob| ob_retest?(current_candle, ob, direction: :short) }
        return nil unless matching_ob

        protected_high = protected_level_price(market_structure.protected_high, sweep[:price])
        return nil if @require_strong_level && protected_high.nil?

        dealing = dealing_range(
          low_price: market_structure.protected_low&.fetch(:price, nil) || current_candle.low,
          high_price: protected_high || sweep[:price]
        )
        return nil unless in_premium?(current_candle.close, dealing)

        return nil unless entry_confirmed?(candles, current_idx, direction: :short)

        build_signal(
          type: :short,
          entry: current_candle.close,
          ob: matching_ob,
          sweep_price: sweep[:price],
          protected_level: protected_high,
          dealing: dealing,
          rules_checked: {
            playbook: PLAYBOOK,
            trend_bearish: true,
            bsl_sweep: true,
            bearish_choch: true,
            bearish_bos: true,
            strong_high: !@require_strong_level || !protected_high.nil?,
            ob_exists: true,
            ob_retest: true,
            in_premium: true,
            entry_confirmation: true
          }
        )
      end

      def bullish_obs_for_pb7(ob_detector, current_idx, choch_index, bos_index)
        ob_detector.active_bullish_obs.select do |ob|
          ob.created_at < current_idx &&
            ob.created_at >= choch_index &&
            ob.created_at <= bos_index &&
            ob.index < bos_index
        end
      end

      def bearish_obs_for_pb7(ob_detector, current_idx, choch_index, bos_index)
        ob_detector.active_bearish_obs.select do |ob|
          ob.created_at < current_idx &&
            ob.created_at >= choch_index &&
            ob.created_at <= bos_index &&
            ob.index < bos_index
        end
      end

      def recent_sweep(liquidity_sweep, current_idx, sweep_type)
        liquidity_sweep.sweeps
          .select { |event| event[:type] == sweep_type && event[:index] >= (current_idx - @lookback_candles) }
          .max_by { |event| event[:index] }
      end

      def pb7_structure_sequence?(sweep, choch_events, bos_events, direction:)
        choch = latest_choch_after(sweep, choch_events, direction)
        return false unless choch

        bos = structure_break_after(bos_events, sweep[:index], direction: direction, after_index: choch[:index])
        !bos.nil?
      end

      def latest_choch_after(sweep, choch_events, direction)
        structure_break_after(choch_events, sweep[:index], direction: direction)
      end

      def structure_break_after(events, sweep_index, direction:, after_index: sweep_index)
        events
          .select do |event|
            event[:direction] == direction &&
              event[:index] > after_index &&
              event[:index] > sweep_index
          end
          .min_by { |event| event[:index] }
      end

      def ob_retest?(candle, ob, direction:)
        case direction
        when :long
          candle.low <= ob.high && candle.close >= ob.low
        when :short
          candle.high >= ob.low && candle.close <= ob.high
        else
          false
        end
      end

      def protected_level_price(protected_level, sweep_price)
        return sweep_price if protected_level.nil?

        protected_level[:price]
      end

      def dealing_range(low_price:, high_price:)
        return nil unless low_price && high_price && high_price > low_price

        { low: low_price, high: high_price, equilibrium: (low_price + high_price) / 2.0 }
      end

      def in_discount?(price, dealing)
        dealing && price <= dealing[:equilibrium]
      end

      def in_premium?(price, dealing)
        dealing && price >= dealing[:equilibrium]
      end

      def entry_confirmed?(candles, current_idx, direction:)
        return true unless @require_entry_confirmation

        current = candles[current_idx]
        prior = current_idx.positive? ? candles[current_idx - 1] : nil

        case direction
        when :long
          current.bullish_engulfing?(prior) || current.bullish_rejection_wick?
        when :short
          current.bearish_engulfing?(prior) || current.bearish_rejection_wick?
        else
          false
        end
      end

      def build_signal(type:, entry:, ob:, sweep_price:, protected_level:, dealing:, rules_checked:)
        buffer = ob.range * 0.1

        if type == :long
          sl_anchor = [ob.low, sweep_price, protected_level].compact.min
          sl_price = sl_anchor - buffer
          return nil if sl_price >= ob.low

          risk = entry - sl_price
          return nil unless risk.positive?

          tp1 = entry + risk
          tp2 = entry + (risk * 2.0)
          tp3 = dealing[:high]
          return nil unless reward_risk_ratio(entry, sl_price, tp3) >= @min_risk_reward

          {
            type: :long,
            playbook: PLAYBOOK,
            entry: entry,
            sl: sl_price,
            tp1: tp1,
            tp2: tp2,
            tp3: tp3,
            risk_reward: reward_risk_ratio(entry, sl_price, tp3).round(2),
            rules_checked: rules_checked
          }
        else
          sl_anchor = [ob.high, sweep_price, protected_level].compact.max
          sl_price = sl_anchor + buffer
          return nil if sl_price <= ob.high

          risk = sl_price - entry
          return nil unless risk.positive?

          tp1 = entry - risk
          tp2 = entry - (risk * 2.0)
          tp3 = dealing[:low]
          return nil unless reward_risk_ratio(entry, sl_price, tp3) >= @min_risk_reward

          {
            type: :short,
            playbook: PLAYBOOK,
            entry: entry,
            sl: sl_price,
            tp1: tp1,
            tp2: tp2,
            tp3: tp3,
            risk_reward: reward_risk_ratio(entry, sl_price, tp3).round(2),
            rules_checked: rules_checked
          }
        end
      end

      def reward_risk_ratio(entry, stop, target)
        risk = (entry - stop).abs
        return 0.0 if risk.zero?

        (target - entry).abs / risk
      end
    end
  end
end
