# frozen_string_literal: true

module SMC
  module Liquidity
    class Displacement
      SUPPORTED_DIRECTIONS = %i[bullish bearish].freeze

      attr_reader :atr, :body_multiplier, :range_multiplier, :min_body_ratio

      def initialize(
        atr: nil,
        body_multiplier: 1.5,
        range_multiplier: 2.0,
        min_body_ratio: 0.6
      )
        raise ArgumentError, 'body_multiplier must be positive' unless body_multiplier.is_a?(Numeric) && body_multiplier.positive?
        raise ArgumentError, 'range_multiplier must be positive' unless range_multiplier.is_a?(Numeric) && range_multiplier.positive?
        unless min_body_ratio.is_a?(Numeric) && min_body_ratio >= 0.0 && min_body_ratio <= 1.0
          raise ArgumentError, 'min_body_ratio must be between 0.0 and 1.0'
        end

        @atr = atr || SMC::ATR.new
        @body_multiplier = body_multiplier.to_f
        @range_multiplier = range_multiplier.to_f
        @min_body_ratio = min_body_ratio.to_f
      end

      def atr_at(candles, index)
        return nil if index.negative? || index >= candles.size

        reference_index = index.positive? ? index - 1 : index
        atr.value_at(candles, reference_index)
      end

      def bullish_at?(candles, index)
        !displacement_at(candles, index, direction: :bullish).nil?
      end

      def bearish_at?(candles, index)
        !displacement_at(candles, index, direction: :bearish).nil?
      end

      def direction_at(candles, index)
        displacement_at(candles, index)&.fetch(:direction)
      end

      def displacement_at(candles, index, direction: nil)
        return nil if index.negative? || index >= candles.size

        candle = candles[index]
        atr_value = atr_at(candles, index)
        return nil if atr_value.nil?

        detected_direction = detect_direction(candle, atr_value)
        return nil if detected_direction.nil?
        return nil if direction && detected_direction != direction

        build_event(
          direction: detected_direction,
          index: index,
          candle: candle,
          atr_value: atr_value
        )
      end

      def find_after(candles, start_index:, direction:, lookback:)
        validate_direction!(direction)
        raise ArgumentError, 'lookback must be a positive integer' unless lookback.is_a?(Integer) && lookback.positive?

        from_index = [start_index + 1, 0].max
        to_index = [from_index + lookback - 1, candles.size - 1].min

        (from_index..to_index).each do |index|
          event = displacement_at(candles, index, direction: direction)
          return event if event
        end

        nil
      end

      def from_swing?(candles, swing, direction:, max_bars_after: 3)
        validate_direction!(direction)
        raise ArgumentError, 'max_bars_after must be a positive integer' unless max_bars_after.is_a?(Integer) && max_bars_after.positive?

        expected_swing_type = direction == :bullish ? :low : :high
        return false unless swing.type == expected_swing_type

        find_after(
          candles,
          start_index: swing.index,
          direction: direction,
          lookback: max_bars_after
        ) != nil
      end

      def events_in_range(candles, from_index:, to_index:)
        return [] if from_index > to_index
        return [] if candles.empty?

        start_index = [[from_index, 0].max, candles.size - 1].min
        end_index = [[to_index, 0].max, candles.size - 1].min
        return [] if start_index > end_index

        (start_index..end_index).filter_map do |index|
          displacement_at(candles, index)
        end
      end

      private

      def detect_direction(candle, atr_value)
        return :bullish if bullish_displacement?(candle, atr_value)
        return :bearish if bearish_displacement?(candle, atr_value)

        nil
      end

      def bullish_displacement?(candle, atr_value)
        return false unless candle.bullish?

        qualifies_by_body?(candle, atr_value) || qualifies_by_range?(candle, atr_value)
      end

      def bearish_displacement?(candle, atr_value)
        return false unless candle.bearish?

        qualifies_by_body?(candle, atr_value) || qualifies_by_range?(candle, atr_value)
      end

      def qualifies_by_body?(candle, atr_value)
        candle.body_size >= (atr_value * body_multiplier)
      end

      def qualifies_by_range?(candle, atr_value)
        range = candle.size
        return false if range.zero?

        range >= (atr_value * range_multiplier) && (candle.body_size / range) >= min_body_ratio
      end

      def build_event(direction:, index:, candle:, atr_value:)
        {
          direction: direction,
          index: index,
          candle: candle,
          body: candle.body_size,
          range: candle.size,
          atr: atr_value,
          body_threshold: atr_value * body_multiplier,
          range_threshold: atr_value * range_multiplier
        }
      end

      def validate_direction!(direction)
        return if SUPPORTED_DIRECTIONS.include?(direction)

        raise ArgumentError, "direction must be one of: #{SUPPORTED_DIRECTIONS.join(', ')}"
      end
    end
  end
end
