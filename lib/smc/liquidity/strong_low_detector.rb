# frozen_string_literal: true

module SMC
  module Liquidity
    class StrongLowDetector
      attr_reader :displacement, :max_displacement_bars, :max_bos_bars,
                  :accept_choch_as_structure_break, :strong_lows, :protected_low

      def initialize(
        displacement: nil,
        max_displacement_bars: 5,
        max_bos_bars: 10,
        accept_choch_as_structure_break: false
      )
        unless max_displacement_bars.is_a?(Integer) && max_displacement_bars.positive?
          raise ArgumentError, 'max_displacement_bars must be a positive integer'
        end
        unless max_bos_bars.is_a?(Integer) && max_bos_bars.positive?
          raise ArgumentError, 'max_bos_bars must be a positive integer'
        end

        @displacement = displacement || Displacement.new
        @max_displacement_bars = max_displacement_bars
        @max_bos_bars = max_bos_bars
        @accept_choch_as_structure_break = accept_choch_as_structure_break
        @strong_lows = []
        @protected_low = nil
        @confirmed_swing_indices = {}
      end

      def evaluate_swing(candles, swing, bos_events:, choch_events: [])
        return nil unless swing.type == :low

        displacement_event = @displacement.find_after(
          candles,
          start_index: swing.index,
          direction: :bullish,
          lookback: @max_displacement_bars
        )
        return nil unless displacement_event

        structure_break = find_structure_break_after(
          bos_events: bos_events,
          choch_events: choch_events,
          after_index: displacement_event[:index]
        )
        return nil unless structure_break

        build_strong_low(swing, displacement_event, structure_break)
      end

      def detect_all(candles, swings, bos_events:, choch_events: [])
        Array(swings).compact
          .select { |swing| swing.type == :low }
          .filter_map do |swing|
            next if @confirmed_swing_indices[swing.index]

            result = evaluate_swing(
              candles,
              swing,
              bos_events: bos_events,
              choch_events: choch_events
            )
            register(result) if result
            result
          end
      end

      def confirm(candles, swing, bos_events:, choch_events: [])
        result = evaluate_swing(
          candles,
          swing,
          bos_events: bos_events,
          choch_events: choch_events
        )
        register(result) if result
        result
      end

      def strong_low?(swing_index)
        @confirmed_swing_indices.key?(swing_index)
      end

      def latest
        @protected_low
      end

      private

      def find_structure_break_after(bos_events:, choch_events:, after_index:)
        bullish_bos = bos_events.select do |event|
          event[:direction] == :bullish &&
            event[:index] > after_index &&
            event[:index] <= after_index + @max_bos_bars
        end

        if bullish_bos.any?
          event = bullish_bos.min_by { |candidate| candidate[:index] }
          return { event: event, type: :bos }
        end

        return nil unless @accept_choch_as_structure_break

        bullish_choch = choch_events.select do |event|
          event[:direction] == :bullish &&
            event[:index] > after_index &&
            event[:index] <= after_index + @max_bos_bars
        end
        return nil if bullish_choch.empty?

        event = bullish_choch.min_by { |candidate| candidate[:index] }
        { event: event, type: :choch }
      end

      def build_strong_low(swing, displacement_event, structure_break)
        {
          swing: swing,
          price: swing.price,
          swing_index: swing.index,
          displacement: displacement_event,
          bos: structure_break[:event],
          structure_break_type: structure_break[:type],
          confirmed_at: structure_break[:event][:index],
          protected: true
        }
      end

      def register(result)
        @confirmed_swing_indices[result[:swing_index]] = true
        @strong_lows << result
        @protected_low = result
      end
    end
  end
end
