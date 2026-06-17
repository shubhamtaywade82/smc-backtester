# frozen_string_literal: true

require_relative '../strategy'

module SMC
  module Strategy
    # Confluenced Multi-Timeframe Strategy
    # HTF Bias (1H) + ITF Sweep (15M) + LTF OB Retest (5M)
    class MTFConfluence < Base
      attr_reader :itf_lookback, :ltf_lookback

      def initialize(itf_lookback: 8, ltf_lookback: 15)
        super(name: "MTF Playbook: HTF Bias + ITF Sweep + LTF OB")
        @itf_lookback = itf_lookback # lookback in ITF (15m) candles
        @ltf_lookback = ltf_lookback # lookback in LTF (5m) candles
      end

      # Evaluates the confluenced MTF rules using the aligned states in the MTFEngine
      def evaluate_mtf(ltf_candles, ltf_idx, mtf_engine)
        ltf_candle = ltf_candles[ltf_idx]
        
        # Get active states from the engine
        htf_state = mtf_engine.engines[:htf]
        itf_state = mtf_engine.engines[:itf]
        ltf_state = mtf_engine.engines[:ltf]

        # ─── LONG SETUP RULES (BULLISH CONFLUENCE) ───
        # 1. HTF (1H) Trend is BULLISH
        # 2. ITF (15M) has a recent SSL Sweep
        # 3. LTF (5M) has a confirmed trend direction or recent BOS/CHoCH
        # 4. LTF (5M) active OB exists and is retested by the current candle
        # 5. Price is in LTF Discount
        
        if htf_state.market_structure.trend == :BULLISH
          # Check ITF for recent Sell-Side Liquidity sweeps
          itf_sweeps = itf_state.liquidity_sweep.sweeps.select do |s|
            s[:type] == :ssl_sweep && s[:index] >= (itf_state.candles.size - @itf_lookback)
          end

          unless itf_sweeps.empty?
            # Check for active bullish order blocks on LTF
            active_ltf_obs = ltf_state.ob_detector.active_bullish_obs.select { |ob| ob.created_at < ltf_idx }
            
            unless active_ltf_obs.empty?
              # Retesting active LTF OB
              matching_ob = active_ltf_obs.find do |ob|
                ltf_candle.low <= ob.high && ltf_candle.close >= ob.low
              end

              if matching_ob
                # Check Discount (dealing range is LTF Protected Low to current high)
                p_low = ltf_state.market_structure.protected_low ? ltf_state.market_structure.protected_low[:price] : matching_ob.low
                p_high = ltf_state.market_structure.protected_high ? ltf_state.market_structure.protected_high[:price] : ltf_candle.high
                
                if p_high > p_low
                  eq = (p_low + p_high) / 2.0
                  if ltf_candle.close <= eq
                    sl_price = [matching_ob.low, p_low].min - (matching_ob.range * 0.1)
                    risk = ltf_candle.close - sl_price
                    
                    if risk > 0
                      return {
                        type: :long,
                        entry: ltf_candle.close,
                        sl: sl_price,
                        tp1: ltf_candle.close + risk,
                        tp2: ltf_candle.close + (risk * 2.0),
                        tp3: p_high,
                        rules_checked: {
                          htf_trend_bullish: true,
                          itf_ssl_sweep: true,
                          ltf_ob_retest: true,
                          in_discount: true
                        }
                      }
                    end
                  end
                end
              end
            end
          end
        end

        # ─── SHORT SETUP RULES (BEARISH CONFLUENCE) ───
        # 1. HTF (1H) Trend is BEARISH
        # 2. ITF (15M) has a recent BSL Sweep
        # 3. LTF (5M) active OB exists and is retested by the current candle
        # 4. Price is in LTF Premium
        
        if htf_state.market_structure.trend == :BEARISH
          itf_sweeps = itf_state.liquidity_sweep.sweeps.select do |s|
            s[:type] == :bsl_sweep && s[:index] >= (itf_state.candles.size - @itf_lookback)
          end

          unless itf_sweeps.empty?
            active_ltf_obs = ltf_state.ob_detector.active_bearish_obs.select { |ob| ob.created_at < ltf_idx }

            unless active_ltf_obs.empty?
              matching_ob = active_ltf_obs.find do |ob|
                ltf_candle.high >= ob.low && ltf_candle.close <= ob.high
              end

              if matching_ob
                p_low = ltf_state.market_structure.protected_low ? ltf_state.market_structure.protected_low[:price] : ltf_candle.low
                p_high = ltf_state.market_structure.protected_high ? ltf_state.market_structure.protected_high[:price] : matching_ob.high

                if p_high > p_low
                  eq = (p_low + p_high) / 2.0
                  if ltf_candle.close >= eq
                    sl_price = [matching_ob.high, p_high].max + (matching_ob.range * 0.1)
                    risk = sl_price - ltf_candle.close

                    if risk > 0
                      return {
                        type: :short,
                        entry: ltf_candle.close,
                        sl: sl_price,
                        tp1: ltf_candle.close - risk,
                        tp2: ltf_candle.close - (risk * 2.0),
                        tp3: p_low,
                        rules_checked: {
                          htf_trend_bearish: true,
                          itf_bsl_sweep: true,
                          ltf_ob_retest: true,
                          in_premium: true
                        }
                      }
                    end
                  end
                end
              end
            end
          end
        end

        nil
      end

      # Override base evaluate to support standard backtester (polymorphic fallback)
      def evaluate(candles, current_idx, pivot_detector, market_structure, liquidity_sweep, ob_detector)
        # In a single timeframe context, we can treat it as a standard PB7 strategy
        @single_tf_strategy ||= SMC::Strategy::SweepOB.new(lookback_candles: @ltf_lookback)
        @single_tf_strategy.evaluate(candles, current_idx, pivot_detector, market_structure, liquidity_sweep, ob_detector)
      end
    end
  end
end
