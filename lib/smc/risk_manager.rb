# frozen_string_literal: true

module SMC
  # Manages position sizes, SL/TP levels, and partial exits
  class RiskManager
    attr_reader :max_risk_pct, :initial_capital, :capital, :trades

    # Represents an active trade position
    class Position
      attr_reader :type, :entry_price, :entry_idx, :initial_size, :sl, :tp1, :tp2, :tp3
      attr_accessor :size, :status, :tp1_hit, :tp2_hit, :pnl, :exit_price, :exit_idx

      def initialize(type:, entry_price:, entry_idx:, size:, sl:, tp1:, tp2:, tp3:)
        @type = type
        @entry_price = entry_price.to_f
        @entry_idx = entry_idx
        @initial_size = size.to_f
        @size = size.to_f
        @sl = sl.to_f
        @tp1 = tp1.to_f
        @tp2 = tp2.to_f
        @tp3 = tp3.to_f
        @status = :open # :open, :closed
        @tp1_hit = false
        @tp2_hit = false
        @pnl = 0.0
        @exit_price = nil
        @exit_idx = nil
      end

      def long?
        @type == :long
      end

      def short?
        @type == :short
      end

      def update_stop_loss(new_sl)
        @sl = new_sl.to_f
      end
    end

    def initialize(initial_capital: 100000.0, max_risk_pct: 0.01)
      @initial_capital = initial_capital.to_f
      @capital = @initial_capital
      @max_risk_pct = max_risk_pct.to_f
      @trades = []
    end

    # Calculate position size based on max capital risk
    def calculate_position_size(entry, sl)
      risk_per_share = (entry - sl).abs
      return 0.0 if risk_per_share <= 0
      
      allowed_risk_amount = @capital * @max_risk_pct
      (allowed_risk_amount / risk_per_share).floor
    end

    # Open a new position
    def open_position(type:, entry:, sl:, tp1:, tp2:, tp3:, index:)
      size = calculate_position_size(entry, sl)
      return nil if size <= 0

      pos = Position.new(
        type: type,
        entry_price: entry,
        entry_idx: index,
        size: size,
        sl: sl,
        tp1: tp1,
        tp2: tp2,
        tp3: tp3
      )
      @trades << pos
      pos
    end

    # Check active positions against the current candle and execute partials / stops
    def update_positions(active_positions, candle, index)
      active_positions.each do |pos|
        next if pos.status == :closed

        if pos.long?
          # 1. Check Stop Loss
          if candle.low <= pos.sl
            # Close the remaining position
            close_qty = pos.size
            pos.pnl += close_qty * (pos.sl - pos.entry_price)
            pos.size = 0.0
            pos.status = :closed
            pos.exit_price = pos.sl
            pos.exit_idx = index
            @capital += pos.pnl
            next
          end

          # 2. Check TP1 (30% exit, move SL to breakeven)
          if !pos.tp1_hit && candle.high >= pos.tp1
            sell_qty = (pos.initial_size * 0.3).floor
            sell_qty = pos.size if sell_qty > pos.size
            pos.pnl += sell_qty * (pos.tp1 - pos.entry_price)
            pos.size -= sell_qty
            pos.tp1_hit = true
            pos.update_stop_loss(pos.entry_price) # Move SL to Breakeven
          end

          # 3. Check TP2 (40% exit)
          if pos.tp1_hit && !pos.tp2_hit && candle.high >= pos.tp2
            sell_qty = (pos.initial_size * 0.4).floor
            sell_qty = pos.size if sell_qty > pos.size
            pos.pnl += sell_qty * (pos.tp2 - pos.entry_price)
            pos.size -= sell_qty
            pos.tp2_hit = true
          end

          # 4. Check TP3 (Remaining 30% exit)
          if pos.tp2_hit && candle.high >= pos.tp3
            close_qty = pos.size
            pos.pnl += close_qty * (pos.tp3 - pos.entry_price)
            pos.size = 0.0
            pos.status = :closed
            pos.exit_price = pos.tp3
            pos.exit_idx = index
            @capital += pos.pnl
          end

        elsif pos.short?
          # 1. Check Stop Loss
          if candle.high >= pos.sl
            close_qty = pos.size
            pos.pnl += close_qty * (pos.entry_price - pos.sl)
            pos.size = 0.0
            pos.status = :closed
            pos.exit_price = pos.sl
            pos.exit_idx = index
            @capital += pos.pnl
            next
          end

          # 2. Check TP1 (30% exit, move SL to breakeven)
          if !pos.tp1_hit && candle.low <= pos.tp1
            sell_qty = (pos.initial_size * 0.3).floor
            sell_qty = pos.size if sell_qty > pos.size
            pos.pnl += sell_qty * (pos.entry_price - pos.tp1)
            pos.size -= sell_qty
            pos.tp1_hit = true
            pos.update_stop_loss(pos.entry_price) # Move SL to Breakeven
          end

          # 3. Check TP2 (40% exit)
          if pos.tp1_hit && !pos.tp2_hit && candle.low <= pos.tp2
            sell_qty = (pos.initial_size * 0.4).floor
            sell_qty = pos.size if sell_qty > pos.size
            pos.pnl += sell_qty * (pos.entry_price - pos.tp2)
            pos.size -= sell_qty
            pos.tp2_hit = true
          end

          # 4. Check TP3 (Remaining 30% exit)
          if pos.tp2_hit && candle.low <= pos.tp3
            close_qty = pos.size
            pos.pnl += close_qty * (pos.entry_price - pos.tp3)
            pos.size = 0.0
            pos.status = :closed
            pos.exit_price = pos.tp3
            pos.exit_idx = index
            @capital += pos.pnl
          end
        end
      end
    end
  end
end
