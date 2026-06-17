# frozen_string_literal: true

module SMC
  # Classifies market structure and tracks BOS, CHoCH, and trends
  class MarketStructure
    attr_reader :swings, :classified_swings, :trend, :bos_events, :choch_events, :protected_low, :protected_high

    def initialize
      @swings = []
      @classified_swings = {} # maps swing object/index to classification symbol (:HH, :LH, :HL, :LL)
      @trend = :RANGE # :BULLISH, :BEARISH, :RANGE
      @bos_events = []
      @choch_events = []
      @protected_low = nil # { price: float, index: int, candle: Candle }
      @protected_high = nil
      @broken_swings = {} # tracks which swings have been broken/swept to avoid double-counting BOS
    end

    # Update structure with new swings confirmed up to the current candle index
    def update(confirmed_swings, current_candle, current_idx)
      @swings = confirmed_swings
      classify_swings
      update_trend
      detect_bos_and_choch(current_candle, current_idx)
    end

    private

    # Classifies confirmed swings as HH, LH, HL, LL
    def classify_swings
      highs = @swings.select { |s| s.type == :high }
      lows = @swings.select { |s| s.type == :low }

      highs.each_with_index do |swing, i|
        if i == 0
          @classified_swings[swing.index] = :H
          next
        end
        prev_swing = highs[i - 1]
        if swing.price > prev_swing.price
          @classified_swings[swing.index] = :HH
        else
          @classified_swings[swing.index] = :LH
        end
      end

      lows.each_with_index do |swing, i|
        if i == 0
          @classified_swings[swing.index] = :L
          next
        end
        prev_swing = lows[i - 1]
        if swing.price > prev_swing.price
          @classified_swings[swing.index] = :HL
        else
          @classified_swings[swing.index] = :LL
        end
      end
    end

    # Trend logic:
    # Bullish: Recent swing low is HL, recent swing high is HH
    # Bearish: Recent swing low is LL, recent swing high is LH
    # Range: Otherwise
    def update_trend
      highs = @swings.select { |s| s.type == :high }
      lows = @swings.select { |s| s.type == :low }

      return if highs.empty? || lows.empty?

      last_high_class = @classified_swings[highs.last.index]
      last_low_class = @classified_swings[lows.last.index]

      if last_high_class == :HH && last_low_class == :HL
        @trend = :BULLISH
      elsif last_high_class == :LH && last_low_class == :LL
        @trend = :BEARISH
      else
        # If we just had a BOS/CHoCH, we might align trend based on that
        # otherwise default to RANGE or keep previous trend
      end
    end

    # Real-time BOS/CHoCH detection on close of current candle
    def detect_bos_and_choch(candle, idx)
      highs = @swings.select { |s| s.type == :high }
      lows = @swings.select { |s| s.type == :low }

      # 1. Bullish BOS / CHoCH
      # Look at the most recent confirmed swing high that hasn't been broken yet
      unbroken_high = highs.reverse.find { |s| s.index < idx && !@broken_swings[s.index] }
      if unbroken_high && candle.close > unbroken_high.price
        @broken_swings[unbroken_high.index] = true
        classification = @classified_swings[unbroken_high.index]
        
        # If breaking a Lower High, it's a CHoCH
        if classification == :LH || @trend == :BEARISH
          @choch_events << { direction: :bullish, index: idx, price: candle.close, swing: unbroken_high, candle: candle }
          @trend = :BULLISH # Reversal to bullish
        else
          # Breaking a Higher High is a BOS
          @bos_events << { direction: :bullish, index: idx, price: candle.close, swing: unbroken_high, candle: candle }
        end

        # Establish Protected Low (the lowest low between the swing high and the break index)
        # Typically the last swing low is the protected low
        recent_low = lows.last
        if recent_low
          @protected_low = { price: recent_low.price, index: recent_low.index, candle: recent_low.candle }
        end
      end

      # 2. Bearish BOS / CHoCH
      # Look at the most recent confirmed swing low that hasn't been broken yet
      unbroken_low = lows.reverse.find { |s| s.index < idx && !@broken_swings[s.index] }
      if unbroken_low && candle.close < unbroken_low.price
        @broken_swings[unbroken_low.index] = true
        classification = @classified_swings[unbroken_low.index]

        # If breaking a Higher Low, it's a CHoCH
        if classification == :HL || @trend == :BULLISH
          @choch_events << { direction: :bearish, index: idx, price: candle.close, swing: unbroken_low, candle: candle }
          @trend = :BEARISH # Reversal to bearish
        else
          # Breaking a Lower Low is a BOS
          @bos_events << { direction: :bearish, index: idx, price: candle.close, swing: unbroken_low, candle: candle }
        end

        # Establish Protected High
        recent_high = highs.last
        if recent_high
          @protected_high = { price: recent_high.price, index: recent_high.index, candle: recent_high.candle }
        end
      end
    end
  end
end
