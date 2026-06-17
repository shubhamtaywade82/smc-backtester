# frozen_string_literal: true

module SMC
  module Strategy
    module PlaybookHelpers
      private

      def structure_break_after(events, after_index, direction:)
        events
          .select { |event| event[:direction] == direction && event[:index] > after_index }
          .min_by { |event| event[:index] }
      end

      def recent_event(events, current_idx, direction:, lookback:)
        events
          .select { |event| event[:direction] == direction && event[:index] >= (current_idx - lookback) }
          .max_by { |event| event[:index] }
      end

      def recent_sweep(liquidity_sweep, current_idx, sweep_type, lookback:)
        liquidity_sweep.sweeps
          .select { |event| event[:type] == sweep_type && event[:index] >= (current_idx - lookback) }
          .max_by { |event| event[:index] }
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

      def entry_confirmed?(candles, current_idx, direction:, required:)
        return true unless required

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

      def reward_risk_ratio(entry, stop, target)
        risk = (entry - stop).abs
        return 0.0 if risk.zero?

        (target - entry).abs / risk
      end
    end
  end
end
