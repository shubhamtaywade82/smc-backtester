# frozen_string_literal: true

module SMC
  module Indicators
    class Supertrend
      attr_reader :period, :multiplier

      def initialize(period: 10, multiplier: 3.0)
        raise ArgumentError, 'period must be positive' unless period.to_i.positive?
        raise ArgumentError, 'multiplier must be positive' unless multiplier.to_f.positive?

        @period = period.to_i
        @multiplier = multiplier.to_f
      end

      def compute(candles)
        return [] if candles.size < @period

        atr_values = calculate_atr(candles)
        results = []
        prev_trend = :long

        candles.each_with_index do |candle, index|
          if index < @period - 1
            results << nil
            next
          end

          atr = atr_values[index]
          hl2 = (candle.high + candle.low) / 2.0

          basic_upper_band = hl2 + (@multiplier * atr)
          basic_lower_band = hl2 - (@multiplier * atr)

          prev_result = results[index - 1]
          prev_upper_band = prev_result ? prev_result[:upper_band] : basic_upper_band
          prev_lower_band = prev_result ? prev_result[:lower_band] : basic_lower_band
          prev_trend = prev_result ? prev_result[:trend] : :long

          upper_band = if basic_upper_band < prev_upper_band || candles[index - 1].close > prev_upper_band
                         basic_upper_band
                       else
                         prev_upper_band
                       end
          lower_band = if basic_lower_band > prev_lower_band || candles[index - 1].close < prev_lower_band
                         basic_lower_band
                       else
                         prev_lower_band
                       end

          current_trend = prev_trend
          if prev_trend == :long && candle.close < lower_band
            current_trend = :short
          elsif prev_trend == :short && candle.close > upper_band
            current_trend = :long
          end

          line = current_trend == :long ? lower_band : upper_band

          results << {
            time: candle.time,
            upper_band: upper_band,
            lower_band: lower_band,
            trend: current_trend,
            line: line
          }
        end

        results
      end

      private

      def calculate_atr(candles)
        tr_values = [candles.first.high - candles.first.low]

        candles.each_cons(2) do |previous, current|
          tr_values << [
            current.high - current.low,
            (current.high - previous.close).abs,
            (current.low - previous.close).abs
          ].max
        end

        atr = Array.new(candles.size, 0.0)
        atr[@period - 1] = tr_values[0...@period].sum / @period

        (@period...candles.size).each do |index|
          atr[index] = (atr[index - 1] * (@period - 1) + tr_values[index]) / @period
        end
        atr
      end
    end
  end
end
