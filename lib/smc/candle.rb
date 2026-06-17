# frozen_string_literal: true

module SMC
  # Represents a single price bar (OHLCV)
  class Candle
    attr_reader :time, :open, :high, :low, :close, :volume

    def initialize(time:, open:, high:, low:, close:, volume: 0)
      @time = time
      @open = open.to_f
      @high = high.to_f
      @low = low.to_f
      @close = close.to_f
      @volume = volume.to_f
    end

    def bullish?
      @close > @open
    end

    def bearish?
      @close < @open
    end

    def body_size
      (@close - @open).abs
    end

    def body_high
      bullish? ? @close : @open
    end

    def body_low
      bullish? ? @open : @close
    end

    def upper_wick
      @high - body_high
    end

    def lower_wick
      body_low - @low
    end

    def size
      @high - @low
    end

    def bullish_engulfing?(prior_candle)
      return false if prior_candle.nil? || !prior_candle.bearish? || !bullish?

      open <= prior_candle.close &&
        close >= prior_candle.open &&
        body_size > prior_candle.body_size
    end

    def bearish_engulfing?(prior_candle)
      return false if prior_candle.nil? || !prior_candle.bullish? || !bearish?

      open >= prior_candle.close &&
        close <= prior_candle.open &&
        body_size > prior_candle.body_size
    end

    def bullish_rejection_wick?(min_wick_ratio: 0.5)
      return false if size.zero?

      lower_wick >= (size * min_wick_ratio) && close > (low + (size * 0.25))
    end

    def bearish_rejection_wick?(min_wick_ratio: 0.5)
      return false if size.zero?

      upper_wick >= (size * min_wick_ratio) && close < (high - (size * 0.25))
    end

    def to_h
      {
        t: @time,
        o: @open,
        h: @high,
        l: @low,
        c: @close,
        v: @volume
      }
    end
  end
end
