# frozen_string_literal: true

module SMC
  class ATR
    SUPPORTED_SMOOTHING = %i[wilder sma].freeze

    attr_reader :period, :smoothing

    def initialize(period: 14, smoothing: :wilder)
      raise ArgumentError, 'period must be a positive integer' unless period.is_a?(Integer) && period.positive?
      unless SUPPORTED_SMOOTHING.include?(smoothing)
        raise ArgumentError, "smoothing must be one of: #{SUPPORTED_SMOOTHING.join(', ')}"
      end

      @period = period
      @smoothing = smoothing
    end

    def true_range(candle, previous_close)
      high_low = candle.high - candle.low

      return high_low if previous_close.nil?

      [
        high_low,
        (candle.high - previous_close).abs,
        (candle.low - previous_close).abs
      ].max
    end

    def true_ranges(candles)
      return [] if candles.empty?

      ranges = []
      candles.each_with_index do |candle, index|
        previous_close = index.zero? ? nil : candles[index - 1].close
        ranges << true_range(candle, previous_close)
      end
      ranges
    end

    def sufficient_data?(candles)
      candles.size >= period
    end

    def value_at(candles, index)
      return nil if index.negative? || index >= candles.size

      ranges = true_ranges(candles)
      first_index = period - 1
      return nil if index < first_index

      case smoothing
      when :sma
        window = ranges[(index - period + 1)..index]
        window.sum / period.to_f
      when :wilder
        seed = ranges[0...period].sum / period.to_f
        return seed if index == first_index

        atr_value = seed
        ((first_index + 1)..index).each do |i|
          atr_value = ((atr_value * (period - 1)) + ranges[i]) / period.to_f
        end
        atr_value
      end
    end

    def series(candles)
      candles.each_index.map { |index| value_at(candles, index) }
    end

    def latest(candles)
      return nil if candles.empty?

      value_at(candles, candles.size - 1)
    end

    def tolerance_band(candles, multiplier:)
      reference = latest(candles)
      return nil if reference.nil?

      reference * multiplier
    end

    def within_tolerance?(price_a, price_b, candles, multiplier:)
      band = tolerance_band(candles, multiplier: multiplier)
      return false if band.nil?

      (price_a - price_b).abs <= band
    end
  end
end
