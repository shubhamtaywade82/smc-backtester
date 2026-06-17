# frozen_string_literal: true

require_relative '../playbook_helpers'

module SMC
  module Strategy
    class SweepReversalStrategy < Base
      include PlaybookHelpers

      PLAYBOOK = 'PB6'

      attr_reader :lookback_candles, :min_risk_reward, :require_entry_confirmation

      def initialize(
        lookback_candles: 30,
        min_risk_reward: 3.0,
        require_entry_confirmation: true
      )
        super(name: 'PB6: Sweep Reversal')
        @lookback_candles = lookback_candles
        @min_risk_reward = min_risk_reward.to_f
        @require_entry_confirmation = require_entry_confirmation
      end

      def evaluate(candles, current_idx, _pivot_detector, market_structure, liquidity_sweep, _ob_detector)
        current_candle = candles[current_idx]

        evaluate_long(candles, current_idx, current_candle, market_structure, liquidity_sweep) ||
          evaluate_short(candles, current_idx, current_candle, market_structure, liquidity_sweep)
      end

      private

      def evaluate_long(candles, current_idx, current_candle, market_structure, liquidity_sweep)
        return nil unless market_structure.trend == :BULLISH

        sweep = recent_sweep(liquidity_sweep, current_idx, :ssl_sweep, lookback: @lookback_candles)
        return nil unless sweep

        choch = structure_break_after(
          market_structure.choch_events,
          sweep[:index],
          direction: :bullish
        )
        return nil unless choch

        return nil if structure_break_after(
          market_structure.bos_events,
          sweep[:index],
          direction: :bullish
        )

        protected_low = sweep[:price]
        target_high = liquidity_target_high(market_structure, sweep[:index], choch[:price])
        return nil unless entry_confirmed?(candles, current_idx, direction: :long, required: @require_entry_confirmation)

        build_long_signal(
          entry: current_candle.close,
          sweep_price: protected_low,
          target_high: target_high,
          rules_checked: {
            playbook: PLAYBOOK,
            trend_bullish: true,
            ssl_sweep: true,
            bullish_choch: true,
            entry_confirmation: true
          }
        )
      end

      def evaluate_short(candles, current_idx, current_candle, market_structure, liquidity_sweep)
        return nil unless market_structure.trend == :BEARISH

        sweep = recent_sweep(liquidity_sweep, current_idx, :bsl_sweep, lookback: @lookback_candles)
        return nil unless sweep

        choch = structure_break_after(
          market_structure.choch_events,
          sweep[:index],
          direction: :bearish
        )
        return nil unless choch

        return nil if structure_break_after(
          market_structure.bos_events,
          sweep[:index],
          direction: :bearish
        )

        protected_high = sweep[:price]
        target_low = liquidity_target_low(market_structure, sweep[:index], choch[:price])
        return nil unless entry_confirmed?(candles, current_idx, direction: :short, required: @require_entry_confirmation)

        build_short_signal(
          entry: current_candle.close,
          sweep_price: protected_high,
          target_low: target_low,
          rules_checked: {
            playbook: PLAYBOOK,
            trend_bearish: true,
            bsl_sweep: true,
            bearish_choch: true,
            entry_confirmation: true
          }
        )
      end

      def liquidity_target_high(market_structure, sweep_index, choch_price)
        swing_highs = market_structure.swings
          .select { |swing| swing.type == :high && swing.index >= sweep_index }
          .map(&:price)

        candidates = swing_highs + [choch_price, market_structure.protected_high&.fetch(:price, nil)].compact
        candidates.max
      end

      def liquidity_target_low(market_structure, sweep_index, choch_price)
        swing_lows = market_structure.swings
          .select { |swing| swing.type == :low && swing.index >= sweep_index }
          .map(&:price)

        candidates = swing_lows + [choch_price, market_structure.protected_low&.fetch(:price, nil)].compact
        candidates.min
      end

      def build_long_signal(entry:, sweep_price:, target_high:, rules_checked:)
        buffer = sweep_price * 0.001
        sl_price = sweep_price - buffer
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

      def build_short_signal(entry:, sweep_price:, target_low:, rules_checked:)
        buffer = sweep_price * 0.001
        sl_price = sweep_price + buffer
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
