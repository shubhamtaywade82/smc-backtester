# frozen_string_literal: true

require_relative 'candle'

module SMC
  # Generates realistic mock price candles containing specific SMC/ICT setups
  class DataGenerator
    # Generates a sequence of candles containing a clean PB7 Bullish Sweep + OB setup
    def self.generate_bullish_setup(start_price: 100.0, num_candles: 100)
      candles = []
      price = start_price
      time = Time.utc(2026, 6, 1, 9, 0)
      
      # 1. Generate initial uptrend (HL -> HH -> HL -> HH)
      # 1-30: Bullish drift
      (0..29).each do |i|
        open_val = price
        close_val = price + rand(-1.0..2.0)
        high_val = [open_val, close_val].max + rand(0.1..0.8)
        low_val = [open_val, close_val].min - rand(0.1..0.8)
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: rand(1000..5000))
        price = close_val
      end

      # 2. Form support/equal lows around price level
      # 30-45: Pullback and sideways range forming equal lows around 108.0
      support_level = price - 2.0
      (30..44).each do |i|
        open_val = price
        # Keep close near support_level
        close_val = support_level + rand(-0.2..0.8)
        high_val = [open_val, close_val].max + rand(0.1..0.5)
        # Ensure lows test the support level but don't break it yet
        low_val = support_level - rand(0.0..0.1)
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: rand(800..3000))
        price = close_val
      end

      # 3. Smart Money Stop Hunt / Sweep (Candle 45)
      # Explosive dip below support_level (e.g. to 105.0) and reclaim
      open_val = price
      low_val = support_level - 3.5 # Sharp break below equal lows
      close_val = support_level + 0.5 # Reclaims above support
      high_val = [open_val, close_val].max + 0.2
      candles << SMC::Candle.new(time: time + (45 * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 15000) # High volume sweep
      price = close_val

      # 4. Bullish Displacement & BOS (Candles 46-50)
      # Strong candles moving up to new highs, establishing an OB at candle 46 (red before the move)
      # Candle 46 is a small bearish pullback/consolidation candle
      open_val = price
      close_val = price - 0.5 # Red candle
      high_val = open_val + 0.2
      low_val = close_val - 0.2
      candles << SMC::Candle.new(time: time + (46 * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 3000)
      ob_price_high = high_val
      ob_price_low = low_val
      price = close_val

      # Candles 47-50: Massive displacement up, breaking previous swing highs (BOS/CHoCH)
      (47..50).each do |i|
        open_val = price
        close_val = price + 4.0 # Big green bar
        high_val = close_val + 0.5
        low_val = open_val - 0.1
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 10000)
        price = close_val
      end

      # 5. Retracement / OB Retest (Candles 51-55)
      # Price drifts back down to test the Bullish OB range (ob_price_high to ob_price_low)
      (51..54).each do |i|
        open_val = price
        close_val = price - 2.5 # Red candles
        high_val = open_val + 0.2
        low_val = close_val - 0.2
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 2000)
        price = close_val
      end

      # Candle 55 touches the OB high and triggers entry
      open_val = price
      close_val = ob_price_high - 0.2 # close inside OB
      low_val = ob_price_low + 0.1 # stays above OB low (protected low)
      high_val = open_val + 0.1
      candles << SMC::Candle.new(time: time + (55 * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 6000)
      price = close_val

      # 6. Expansion to targets (Candles 56-100)
      # Price resumes uptrend and breaks to new highs, hitting TP1, TP2, TP3
      (56..(num_candles - 1)).each do |i|
        open_val = price
        close_val = price + rand(-1.0..3.5) # Strong positive drift
        high_val = [open_val, close_val].max + rand(0.1..0.8)
        low_val = [open_val, close_val].min - rand(0.1..0.8)
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: rand(3000..8000))
        price = close_val
      end

      candles
    end

    # Generates a sequence of candles containing a clean PB7 Bearish Sweep + OB setup
    def self.generate_bearish_setup(start_price: 100.0, num_candles: 100)
      candles = []
      price = start_price
      time = Time.utc(2026, 6, 1, 9, 0)

      # 1. Generate initial downtrend (LH -> LL -> LH -> LL)
      (0..29).each do |i|
        open_val = price
        close_val = price - rand(-1.0..2.0)
        high_val = [open_val, close_val].max + rand(0.1..0.8)
        low_val = [open_val, close_val].min - rand(0.1..0.8)
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: rand(1000..5000))
        price = close_val
      end

      # 2. Form resistance/equal highs around price level
      resistance_level = price + 2.0
      (30..44).each do |i|
        open_val = price
        close_val = resistance_level - rand(-0.2..0.8)
        high_val = resistance_level + rand(0.0..0.1)
        low_val = [open_val, close_val].min - rand(0.1..0.5)
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: rand(800..3000))
        price = close_val
      end

      # 3. Buy-side liquidity (BSL) Sweep
      open_val = price
      high_val = resistance_level + 3.5 # Sharp break above equal highs
      close_val = resistance_level - 0.5 # Reclaims below resistance
      low_val = [open_val, close_val].min - 0.2
      candles << SMC::Candle.new(time: time + (45 * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 15000)
      price = close_val

      # 4. Bearish Displacement & BOS
      # Candle 46: small bullish candle (OB)
      open_val = price
      close_val = price + 0.5
      high_val = close_val + 0.2
      low_val = open_val - 0.2
      candles << SMC::Candle.new(time: time + (46 * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 3000)
      ob_price_high = high_val
      ob_price_low = low_val
      price = close_val

      # Candles 47-50: Massive displacement down
      (47..50).each do |i|
        open_val = price
        close_val = price - 4.0
        high_val = open_val + 0.1
        low_val = close_val - 0.5
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 10000)
        price = close_val
      end

      # 5. Retracement / OB Retest
      (51..54).each do |i|
        open_val = price
        close_val = price + 2.5
        high_val = close_val + 0.2
        low_val = open_val - 0.2
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 2000)
        price = close_val
      end

      # Candle 55 touches OB low
      open_val = price
      close_val = ob_price_low + 0.2
      high_val = ob_price_high - 0.1 # Stays below OB high (protected high)
      low_val = open_val - 0.1
      candles << SMC::Candle.new(time: time + (55 * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: 6000)
      price = close_val

      # 6. Expansion
      (56..(num_candles - 1)).each do |i|
        open_val = price
        close_val = price - rand(-1.0..3.5)
        high_val = [open_val, close_val].max + rand(0.1..0.8)
        low_val = [open_val, close_val].min - rand(0.1..0.8)
        candles << SMC::Candle.new(time: time + (i * 300), open: open_val, high: high_val, low: low_val, close: close_val, volume: rand(3000..8000))
        price = close_val
      end

      candles
    end
  end
end
