# frozen_string_literal: true

module SMC
  module Strategy
    # Base strategy class defining interface
    class Base
      attr_reader :name

      def initialize(name:)
        @name = name
      end

      # Evaluate market data at current state and return trade signal if any
      # Return hash: { type: :long|:short, sl: float, tp1: float, tp2: float, tp3: float } or nil
      def evaluate(candles, current_idx, pivot_detector, market_structure, liquidity_sweep, ob_detector)
        raise NotImplementedError
      end
    end

    # Implements Playbook 7: Sweep + OB (Primary A+ Setup)
    class SweepOB < Base
      attr_reader :lookback_candles

      def initialize(lookback_candles: 20)
        super(name: "PB7: Sweep + OB")
        @lookback_candles = lookback_candles
      end

      def evaluate(candles, current_idx, pivot_detector, market_structure, liquidity_sweep, ob_detector)
        current_candle = candles[current_idx]

        # ─── LONG SETUP RULES ───
        # 1. HTF/Current Trend is Bullish
        # 2. SSL Sweep occurred recently
        # 3. Bullish CHoCH or BOS confirmed after sweep
        # 4. Active Bullish OB exists
        # 5. Price has retraced and is currently inside the Bullish OB
        # 6. Price is in Discount (below dealing range midpoint)
        
        # Check if we have active bullish order blocks
        active_bull_obs = ob_detector.active_bullish_obs.select { |ob| ob.created_at < current_idx }
        
        if market_structure.trend == :BULLISH && !active_bull_obs.empty?
          # Find recent SSL sweeps within lookback
          recent_sweeps = liquidity_sweep.sweeps.select do |s|
            s[:type] == :ssl_sweep && s[:index] >= (current_idx - @lookback_candles)
          end

          unless recent_sweeps.empty?
            # Check if current candle is retesting an active Bullish OB
            matching_ob = active_bull_obs.find do |ob|
              current_candle.low <= ob.high && current_candle.close >= ob.low
            end

            if matching_ob
              # Check Premium vs Discount
              # Dealing range is Protected Low to current candle high (or last swing high)
              p_low = market_structure.protected_low ? market_structure.protected_low[:price] : recent_sweeps.last[:price]
              p_high = market_structure.protected_high ? market_structure.protected_high[:price] : candles[current_idx].high
              
              if p_high > p_low
                eq = (p_low + p_high) / 2.0
                if current_candle.close <= eq # Inside discount
                  # Calculate SL and TPs
                  sl_price = [matching_ob.low, p_low].min - (matching_ob.range * 0.1) # 10% room below OB/Low
                  risk = current_candle.close - sl_price
                  
                  if risk > 0
                    return {
                      type: :long,
                      entry: current_candle.close,
                      sl: sl_price,
                      tp1: current_candle.close + risk, # 1:1 R:R
                      tp2: current_candle.close + (risk * 2.0), # 1:2 R:R
                      tp3: p_high, # Swing High target
                      rules_checked: {
                        trend_bullish: true,
                        ssl_sweep: true,
                        ob_exists: true,
                        ob_retest: true,
                        in_discount: true
                      }
                    }
                  end
                end
              end
            end
          end
        end

        # ─── SHORT SETUP RULES ───
        # 1. Bearish Trend
        # 2. BSL Sweep occurred recently
        # 3. Bearish CHoCH or BOS confirmed after sweep
        # 4. Active Bearish OB exists
        # 5. Price is currently inside the Bearish OB
        # 6. Price is in Premium (above dealing range midpoint)
        
        active_bear_obs = ob_detector.active_bearish_obs.select { |ob| ob.created_at < current_idx }
        
        if market_structure.trend == :BEARISH && !active_bear_obs.empty?
          recent_sweeps = liquidity_sweep.sweeps.select do |s|
            s[:type] == :bsl_sweep && s[:index] >= (current_idx - @lookback_candles)
          end

          unless recent_sweeps.empty?
            matching_ob = active_bear_obs.find do |ob|
              current_candle.high >= ob.low && current_candle.close <= ob.high
            end

            if matching_ob
              p_low = market_structure.protected_low ? market_structure.protected_low[:price] : candles[current_idx].low
              p_high = market_structure.protected_high ? market_structure.protected_high[:price] : recent_sweeps.last[:price]

              if p_high > p_low
                eq = (p_low + p_high) / 2.0
                if current_candle.close >= eq # Inside premium
                  sl_price = [matching_ob.high, p_high].max + (matching_ob.range * 0.1)
                  risk = sl_price - current_candle.close
                  
                  if risk > 0
                    return {
                      type: :short,
                      entry: current_candle.close,
                      sl: sl_price,
                      tp1: current_candle.close - risk,
                      tp2: current_candle.close - (risk * 2.0),
                      tp3: p_low,
                      rules_checked: {
                        trend_bearish: true,
                        bsl_sweep: true,
                        ob_exists: true,
                        ob_retest: true,
                        in_premium: true
                      }
                    }
                  end
                end
              end
            end
          end
        end

        nil # No trade setup found
      end
    end
  end
end
