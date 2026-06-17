# frozen_string_literal: true

module SMC
  # Detects Equal Highs/Lows and tracks liquidity sweep events
  class LiquiditySweep
    attr_reader :equal_highs, :equal_lows, :sweeps

    def initialize(tolerance_pct: 0.001) # 0.1% price tolerance for equal highs/lows
      @tolerance_pct = tolerance_pct
      @equal_highs = [] # list of price levels/swings representing equal highs
      @equal_lows = []
      @sweeps = []
      @swept_swings = {} # prevents sweeping the same swing low/high multiple times
    end

    # Scan swings and identify equal highs / equal lows
    def update_equal_levels(swings)
      highs = swings.select { |s| s.type == :high }
      lows = swings.select { |s| s.type == :low }

      @equal_highs = []
      highs.each_with_index do |h1, i|
        highs[(i + 1)..-1].each do |h2|
          diff = (h1.price - h2.price).abs / [h1.price, h2.price].min
          if diff <= @tolerance_pct
            @equal_highs << { level: (h1.price + h2.price) / 2.0, swings: [h1, h2] }
          end
        end
      end

      @equal_lows = []
      lows.each_with_index do |l1, i|
        lows[(i + 1)..-1].each do |l2|
          diff = (l1.price - l2.price).abs / [l1.price, l2.price].min
          if diff <= @tolerance_pct
            @equal_lows << { level: (l1.price + l2.price) / 2.0, swings: [l1, l2] }
          end
        end
      end
    end

    # Checks if the current candle sweeps any liquidity level
    # SSL Sweep: Candle low dips below a swing low (or equal low level), but candle close reclaims above it
    # BSL Sweep: Candle high rises above a swing high (or equal high level), but candle close closes below it
    def detect_sweeps(swings, current_candle, current_idx)
      highs = swings.select { |s| s.type == :high && s.index < current_idx && !@swept_swings[s.index] }
      lows = swings.select { |s| s.type == :low && s.index < current_idx && !@swept_swings[s.index] }

      # 1. Sell-side liquidity (SSL) sweep
      # Find any swing low that is swept by the current candle
      lows.each do |swing|
        if current_candle.low < swing.price && current_candle.close > swing.price
          @swept_swings[swing.index] = true
          @sweeps << {
            type: :ssl_sweep,
            index: current_idx,
            price: swing.price,
            candle: current_candle,
            swept_swing: swing
          }
          break # Only record one sweep event per candle
        end
      end

      # 2. Buy-side liquidity (BSL) sweep
      highs.each do |swing|
        if current_candle.high > swing.price && current_candle.close < swing.price
          @swept_swings[swing.index] = true
          @sweeps << {
            type: :bsl_sweep,
            index: current_idx,
            price: swing.price,
            candle: current_candle,
            swept_swing: swing
          }
          break
        end
      end
    end
  end
end
