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
