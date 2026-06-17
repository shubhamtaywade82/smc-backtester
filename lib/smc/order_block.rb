# frozen_string_literal: true

module SMC
  # Manages the detection, tracking, and mitigation of Order Blocks
  class OrderBlock
    attr_reader :type, :high, :low, :index, :candle, :created_at
    attr_accessor :mitigated, :mitigated_at, :invalidated, :invalidated_at

    def initialize(type:, high:, low:, index:, candle:, created_at:)
      @type = type
      @high = high.to_f
      @low = low.to_f
      @index = index
      @candle = candle
      @created_at = created_at
      @mitigated = false
      @mitigated_at = nil
      @invalidated = false
      @invalidated_at = nil
    end

    def range
      @high - @low
    end

    def mean_threshold # 50% equilibrium level of the OB
      @low + (range / 2.0)
    end
  end

  class OrderBlockDetector
    attr_reader :order_blocks

    def initialize
      @order_blocks = []
    end

    # Scan for new Order Blocks when a BOS or CHoCH event is detected
    def check_for_new_ob(event, candles, current_idx)
      direction = event[:direction]
      event_idx = event[:index]

      # Bullish BOS/CHoCH creates a Bullish Order Block
      if direction == :bullish
        # Look back from the event candle to find the last bearish candle before the upward move began
        ob_candle = nil
        ob_idx = nil
        
        # Scan backward up to 10 candles
        (1..10).each do |lookback|
          idx = event_idx - lookback
          break if idx < 0
          c = candles[idx]
          if c.bearish?
            ob_candle = c
            ob_idx = idx
            break
          end
        end

        # If we found a bearish candle, create the OB
        if ob_candle
          # Avoid duplicates
          return if @order_blocks.any? { |ob| ob.index == ob_idx && ob.type == :bullish }

          @order_blocks << OrderBlock.new(
            type: :bullish,
            high: ob_candle.high,
            low: ob_candle.low,
            index: ob_idx,
            candle: ob_candle,
            created_at: current_idx
          )
        end

      # Bearish BOS/CHoCH creates a Bearish Order Block
      elsif direction == :bearish
        ob_candle = nil
        ob_idx = nil
        
        (1..10).each do |lookback|
          idx = event_idx - lookback
          break if idx < 0
          c = candles[idx]
          if c.class == SMC::Candle && c.bullish?
            ob_candle = c
            ob_idx = idx
            break
          end
        end

        if ob_candle
          return if @order_blocks.any? { |ob| ob.index == ob_idx && ob.type == :bearish }

          @order_blocks << OrderBlock.new(
            type: :bearish,
            high: ob_candle.high,
            low: ob_candle.low,
            index: ob_idx,
            candle: ob_candle,
            created_at: current_idx
          )
        end
      end
    end

    # Updates mitigation and invalidation of order blocks with the current candle
    def update_mitigations(current_candle, current_idx)
      @order_blocks.each do |ob|
        next if ob.mitigated || ob.invalidated

        # Only evaluate OBs created before the current candle
        next if ob.created_at >= current_idx

        if ob.type == :bullish
          # Mitigated if price dips into the OB high
          if current_candle.low <= ob.high
            ob.mitigated = true
            ob.mitigated_at = current_idx
          end
          # Invalidated if price closes below the OB low
          if current_candle.close < ob.low
            ob.invalidated = true
            ob.invalidated_at = current_idx
          end
        elsif ob.type == :bearish
          # Mitigated if price rallies into the OB low
          if current_candle.high >= ob.low
            ob.mitigated = true
            ob.mitigated_at = current_idx
          end
          # Invalidated if price closes above the OB high
          if current_candle.close > ob.high
            ob.invalidated = true
            ob.invalidated_at = current_idx
          end
        end
      end
    end

    def active_bullish_obs
      @order_blocks.select { |ob| ob.type == :bullish && !ob.invalidated }
    end

    def active_bearish_obs
      @order_blocks.select { |ob| ob.type == :bearish && !ob.invalidated }
    end
  end
end
