# frozen_string_literal: true

module SMC
  # Orchestrates the backtest run bar-by-bar over a series of candles
  class Backtester
    attr_reader :candles, :pivot_detector, :market_structure, :liquidity_sweep
    attr_reader :ob_detector, :strategy, :risk_manager, :equity_curve

    def initialize(candles:, pivot_detector:, market_structure:, liquidity_sweep:, ob_detector:, strategy:, risk_manager:)
      @candles = candles
      @pivot_detector = pivot_detector
      @market_structure = market_structure
      @liquidity_sweep = liquidity_sweep
      @ob_detector = ob_detector
      @strategy = strategy
      @risk_manager = risk_manager
      @equity_curve = []
    end

    def run
      # Start running after we have enough candles to form initial structure (e.g. left_bars + right_bars + 10)
      start_idx = [@pivot_detector.left_bars + @pivot_detector.right_bars + 15, 30].max

      (start_idx..(@candles.size - 1)).each do |i|
        candle = @candles[i]

        # 1. Detect swings using data available UP TO candle `i`
        # Pivot detection requires looking ahead by `right_bars` to confirm.
        # So at index `i`, we only pass candles up to `i` to detect pivots.
        # Swings confirmed will be at index <= i - right_bars.
        confirmed_swings = @pivot_detector.detect_swings(@candles[0..i])

        # 2. Update Market Structure
        @market_structure.update(confirmed_swings, candle, i)

        # 3. If BOS or CHoCH occurred on this candle, register it with OB Detector
        recent_bos = @market_structure.bos_events.last
        if recent_bos && recent_bos[:index] == i
          @ob_detector.check_for_new_ob(recent_bos, @candles, i)
        end
        recent_choch = @market_structure.choch_events.last
        if recent_choch && recent_choch[:index] == i
          @ob_detector.check_for_new_ob(recent_choch, @candles, i)
        end

        # 4. Update Liquidity Sweep levels
        @liquidity_sweep.update_equal_levels(confirmed_swings)
        @liquidity_sweep.detect_sweeps(confirmed_swings, candle, i)

        # 5. Update Order Block mitigations
        @ob_detector.update_mitigations(candle, i)

        # 6. Update open positions in RiskManager
        active_positions = @risk_manager.trades.select { |t| t.status == :open }
        @risk_manager.update_positions(active_positions, candle, i)

        # 7. Check if we can open a new trade
        # For simplicity, we only allow 1 open trade at a time
        if active_positions.empty?
          signal = @strategy.evaluate(
            @candles,
            i,
            @pivot_detector,
            @market_structure,
            @liquidity_sweep,
            @ob_detector
          )

          if signal
            @risk_manager.open_position(
              type: signal[:type],
              entry: signal[:entry],
              sl: signal[:sl],
              tp1: signal[:tp1],
              tp2: signal[:tp2],
              tp3: signal[:tp3],
              index: i
            )
          end
        end

        # 8. Record equity curve
        # Open positions contribute to floating equity
        floating_pnl = @risk_manager.trades.select { |t| t.status == :open }.map do |pos|
          if pos.long?
            pos.size * (candle.close - pos.entry_price)
          else
            pos.size * (pos.entry_price - candle.close)
          end
        end.sum
        
        @equity_curve << {
          index: i,
          time: candle.time,
          equity: @risk_manager.capital + floating_pnl
        }
      end

      report_statistics
    end

    def report_statistics
      closed_trades = @risk_manager.trades.select { |t| t.status == :closed }
      total_trades = closed_trades.size
      
      winning_trades = closed_trades.select { |t| t.pnl > 0 }
      losing_trades = closed_trades.select { |t| t.pnl < 0 }
      
      win_rate = total_trades > 0 ? (winning_trades.size.to_f / total_trades * 100).round(2) : 0.0
      
      gross_profit = winning_trades.map(&:pnl).sum
      gross_loss = losing_trades.map(&:pnl).sum.abs
      profit_factor = gross_loss > 0 ? (gross_profit / gross_loss).round(2) : (gross_profit > 0 ? "Infinity" : 0.0)
      
      net_profit = @risk_manager.capital - @risk_manager.initial_capital
      net_profit_pct = (net_profit / @risk_manager.initial_capital * 100).round(2)

      {
        initial_capital: @risk_manager.initial_capital,
        final_capital: @risk_manager.capital,
        net_profit: net_profit,
        net_profit_pct: net_profit_pct,
        total_trades: total_trades,
        wins: winning_trades.size,
        losses: losing_trades.size,
        win_rate: win_rate,
        profit_factor: profit_factor,
        trades: closed_trades.map do |t|
          {
            type: t.type,
            entry_price: t.entry_price,
            entry_idx: t.entry_idx,
            exit_price: t.exit_price,
            exit_idx: t.exit_idx,
            pnl: t.pnl.round(2),
            win: t.pnl > 0
          }
        end,
        equity_curve: @equity_curve
      }
    end
  end
end
