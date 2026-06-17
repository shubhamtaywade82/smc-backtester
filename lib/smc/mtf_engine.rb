# frozen_string_literal: true

require 'time'
require_relative 'candle'
require_relative 'pivot_detector'
require_relative 'market_structure'
require_relative 'liquidity_sweep'
require_relative 'order_block'

module SMC
  # Manages multiple timeframes and ensures bias-free alignment during backtests
  class MTFEngine
    attr_reader :feeds, :durations, :engines

    # Represents the processed indicators and state of a single timeframe
    class TimeframeState
      attr_reader :timeframe, :candles, :pivot_detector, :market_structure, :liquidity_sweep, :ob_detector

      def initialize(timeframe, left_bars: 4, right_bars: 4)
        @timeframe = timeframe
        @candles = []
        @pivot_detector = SMC::PivotDetector.new(left_bars: left_bars, right_bars: right_bars)
        @market_structure = SMC::MarketStructure.new
        @liquidity_sweep = SMC::LiquiditySweep.new
        @ob_detector = SMC::OrderBlockDetector.new
      end

      # Process a newly closed candle for this timeframe
      def process_candle(candle)
        @candles << candle
        idx = @candles.size - 1

        # Run pipeline
        confirmed_swings = @pivot_detector.detect_swings(@candles)
        @market_structure.update(confirmed_swings, candle, idx)

        # Register OBs on BOS/CHoCH
        recent_bos = @market_structure.bos_events.last
        if recent_bos && recent_bos[:index] == idx
          @ob_detector.check_for_new_ob(recent_bos, @candles, idx)
        end
        recent_choch = @market_structure.choch_events.last
        if recent_choch && recent_choch[:index] == idx
          @ob_detector.check_for_new_ob(recent_choch, @candles, idx)
        end

        @liquidity_sweep.update_equal_levels(confirmed_swings)
        @liquidity_sweep.detect_sweeps(confirmed_swings, candle, idx)
        @ob_detector.update_mitigations(candle, idx)
      end
    end

    def initialize(ltf_interval: "5m", itf_interval: "15m", htf_interval: "1h")
      @feeds = {
        ltf: [],
        itf: [],
        htf: []
      }
      
      @durations = {
        ltf: interval_to_seconds(ltf_interval),
        itf: interval_to_seconds(itf_interval),
        htf: interval_to_seconds(htf_interval)
      }

      @engines = {
        ltf: TimeframeState.new(:ltf, left_bars: 2, right_bars: 2),
        itf: TimeframeState.new(:itf, left_bars: 2, right_bars: 2),
        htf: TimeframeState.new(:htf, left_bars: 2, right_bars: 2)
      }

      @processed_until = {
        itf: 0,
        htf: 0
      }
    end

    # Set candles for each timeframe
    def set_feed(tf, candles)
      @feeds[tf] = candles
    end

    # Advances the HTF and ITF engines up to the current LTF candle's end time
    # This aligns the context and prevents peeking into future higher timeframe candles.
    def align_and_process(ltf_candle)
      # Calculate the end time of the current LTF candle
      ltf_end_time = parse_time(ltf_candle.time) + @durations[:ltf]

      # 1. Align ITF (15m)
      itf_feed = @feeds[:itf]
      itf_idx = @processed_until[:itf]
      
      while itf_idx < itf_feed.size
        c = itf_feed[itf_idx]
        c_end_time = parse_time(c.time) + @durations[:itf]
        
        break if c_end_time > ltf_end_time # Not closed yet

        @engines[:itf].process_candle(c)
        itf_idx += 1
      end
      @processed_until[:itf] = itf_idx

      # 2. Align HTF (1h)
      htf_feed = @feeds[:htf]
      htf_idx = @processed_until[:htf]

      while htf_idx < htf_feed.size
        c = htf_feed[htf_idx]
        c_end_time = parse_time(c.time) + @durations[:htf]

        break if c_end_time > ltf_end_time # Not closed yet

        @engines[:htf].process_candle(c)
        htf_idx += 1
      end
      @processed_until[:htf] = htf_idx
    end

    private

    def parse_time(time_val)
      case time_val
      when Time
        time_val
      when String
        Time.parse(time_val)
      when Integer
        Time.at(time_val) # seconds or ms
      else
        raise "Unsupported time type: #{time_val.class}"
      end
    end

    def interval_to_seconds(interval)
      case interval
      when "1m" then 60
      when "5m" then 300
      when "15m" then 900
      when "1h" then 3600
      when "4h" then 14400
      when "1d" then 86400
      else
        # fallback parsing
        num = interval.to_i
        unit = interval[-1]
        case unit
        when 'm' then num * 60
        when 'h' then num * 3600
        when 'd' then num * 86400
        else 300
        end
      end
    end
  end
end
