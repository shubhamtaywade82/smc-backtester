# frozen_string_literal: true

module SMC
  # Detects Swing Highs and Swing Lows from a series of candles
  class PivotDetector
    Swing = Struct.new(:type, :price, :index, :candle)

    attr_reader :left_bars, :right_bars

    def initialize(left_bars: 5, right_bars: 5)
      @left_bars = left_bars
      @right_bars = right_bars
    end

    # Scans the whole list or a subset of candles and returns all swings detected
    # Note: A swing is only confirmed once we have @right_bars candles after it.
    def detect_swings(candles)
      swings = []
      (left_bars..(candles.size - 1 - right_bars)).each do |i|
        candle = candles[i]
        
        # Check swing high
        is_high = true
        (1..left_bars).each { |l| is_high = false if candles[i - l].high >= candle.high }
        (1..right_bars).each { |r| is_high = false if candles[i + r].high >= candle.high }
        
        if is_high
          swings << Swing.new(:high, candle.high, i, candle)
          next
        end

        # Check swing low
        is_low = true
        (1..left_bars).each { |l| is_low = false if candles[i - l].low <= candle.low }
        (1..right_bars).each { |r| is_low = false if candles[i + r].low <= candle.low }

        if is_low
          swings << Swing.new(:low, candle.low, i, candle)
        end
      end
      swings
    end
  end
end
