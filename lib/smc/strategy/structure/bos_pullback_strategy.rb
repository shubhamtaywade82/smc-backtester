# frozen_string_literal: true

require_relative '../playbook_helpers'

module SMC
  module Strategy
    class BosPullbackStrategy < Base
      include PlaybookHelpers

      PLAYBOOK = 'PB3'

      attr_reader :lookback_candles, :min_risk_reward, :require_entry_confirmation, :hl_touch_tolerance_pct

      def initialize(
        lookback_candles: 30,
        min_risk_reward: 3.0,
        require_entry_confirmation: true,
        hl_touch_tolerance_pct: 0.002
      )
        super(name: 'PB3: BOS Pullback')
        @lookback_candles = lookback_candles
        @min_risk_reward = min_risk_reward.to_f
        @require_entry_confirmation = require_entry_confirmation
        @hl_touch_tolerance_pct = hl_touch_tolerance_pct.to_f
      end

      def evaluate(candles, current_idx, _pivot_detector, market_structure, _liquidity_sweep, _ob_detector)
        current_candle = candles[current_idx]

        evaluate_long(candles, current_idx, current_candle, market_structure) ||
          evaluate_short(candles, current_idx, current_candle, market_structure)
      end

      private

      def evaluate_long(candles, current_idx, current_candle, market_structure)
        return nil unless market_structure.trend == :BULLISH

        bos = recent_event(market_structure.bos_events, current_idx, direction: :bullish, lookback: @lookback_candles)
        return nil unless bos

        hl_swing = higher_low_after(market_structure, bos[:index])
        return nil unless hl_swing

        return nil unless pullback_after_bos?(candles, bos, current_idx, direction: :bullish)
        return nil unless hl_touch?(current_candle, hl_swing.price)
        return nil unless entry_confirmed?(candles, current_idx, direction: :long, required: @require_entry_confirmation)

        target_high = bos_target_high(bos, candles)
        dealing = dealing_range(low_price: hl_swing.price, high_price: target_high)
        return nil unless in_discount?(current_candle.close, dealing)

        build_long_signal(
          entry: current_candle.close,
          hl_price: hl_swing.price,
          target_high: target_high,
          rules_checked: {
            playbook: PLAYBOOK,
            trend_bullish: true,
            bullish_bos: true,
            pullback: true,
            hl_formed: true,
            hl_touch: true,
            in_discount: true,
            entry_confirmation: true
          }
        )
      end

      def evaluate_short(candles, current_idx, current_candle, market_structure)
        return nil unless market_structure.trend == :BEARISH

        bos = recent_event(market_structure.bos_events, current_idx, direction: :bearish, lookback: @lookback_candles)
        return nil unless bos

        lh_swing = lower_high_after(market_structure, bos[:index])
        return nil unless lh_swing

        return nil unless pullback_after_bos?(candles, bos, current_idx, direction: :bearish)
        return nil unless lh_touch?(current_candle, lh_swing.price)
        return nil unless entry_confirmed?(candles, current_idx, direction: :short, required: @require_entry_confirmation)

        target_low = bos_target_low(bos, candles)
        dealing = dealing_range(low_price: target_low, high_price: lh_swing.price)
        return nil unless in_premium?(current_candle.close, dealing)

        build_short_signal(
          entry: current_candle.close,
          lh_price: lh_swing.price,
          target_low: target_low,
          rules_checked: {
            playbook: PLAYBOOK,
            trend_bearish: true,
            bearish_bos: true,
            pullback: true,
            lh_formed: true,
            lh_touch: true,
            in_premium: true,
            entry_confirmation: true
          }
        )
      end

      def higher_low_after(market_structure, bos_index)
        market_structure.swings
          .select { |swing| swing.type == :low && swing.index > bos_index }
          .reverse
          .find { |swing| market_structure.classified_swings[swing.index] == :HL }
      end

      def lower_high_after(market_structure, bos_index)
        market_structure.swings
          .select { |swing| swing.type == :high && swing.index > bos_index }
          .reverse
          .find { |swing| market_structure.classified_swings[swing.index] == :LH }
      end

      def pullback_after_bos?(candles, bos, current_idx, direction:)
        bos_close = candles[bos[:index]].close
        ((bos[:index] + 1)...current_idx).any? do |index|
          case direction
          when :bullish
            candles[index].close < bos_close
          when :bearish
            candles[index].close > bos_close
          else
            false
          end
        end
      end

      def hl_touch?(candle, hl_price)
        tolerance = hl_price * @hl_touch_tolerance_pct
        candle.low <= (hl_price + tolerance) && candle.close >= hl_price
      end

      def lh_touch?(candle, lh_price)
        tolerance = lh_price * @hl_touch_tolerance_pct
        candle.high >= (lh_price - tolerance) && candle.close <= lh_price
      end

      def bos_target_high(bos, candles)
        [
          bos[:swing]&.price,
          bos[:price],
          candles[bos[:index]].high
        ].compact.max
      end

      def bos_target_low(bos, candles)
        [
          bos[:swing]&.price,
          bos[:price],
          candles[bos[:index]].low
        ].compact.min
      end

      def build_long_signal(entry:, hl_price:, target_high:, rules_checked:)
        buffer = hl_price * 0.001
        sl_price = hl_price - buffer
        risk = entry - sl_price
        return nil unless risk.positive?

        tp1 = entry + risk
        tp2 = entry + (risk * 2.0)
        tp3 = target_high
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
      end

      def build_short_signal(entry:, lh_price:, target_low:, rules_checked:)
        buffer = lh_price * 0.001
        sl_price = lh_price + buffer
        risk = sl_price - entry
        return nil unless risk.positive?

        tp1 = entry - risk
        tp2 = entry - (risk * 2.0)
        tp3 = target_low
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
  end
end
