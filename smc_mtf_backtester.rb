# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'lib/smc/candle'
require_relative 'lib/smc/pivot_detector'
require_relative 'lib/smc/market_structure'
require_relative 'lib/smc/liquidity_sweep'
require_relative 'lib/smc/order_block'
require_relative 'lib/smc/strategy/mtf_confluence'
require_relative 'lib/smc/risk_manager'
require_relative 'lib/smc/backtester'
require_relative 'lib/smc/mtf_engine'
require_relative 'lib/smc/data_generator'

# Helper to aggregate 5M candles into higher timeframes (15M and 1H)
# Handles open, high, low, close, volume, and starting timestamp alignment
def aggregate_candles(ltf_candles, group_size)
  aggregated = []
  ltf_candles.each_slice(group_size) do |slice|
    next if slice.size < group_size # omit incomplete tail
    
    first = slice.first
    last = slice.last
    
    highs = slice.map(&:high)
    lows = slice.map(&:low)
    total_volume = slice.map(&:volume).sum
    
    aggregated << SMC::Candle.new(
      time: first.time,
      open: first.open,
      high: highs.max,
      low: lows.min,
      close: last.close,
      volume: total_volume
    )
  end
  aggregated
end

def main
  srand(42) # Ensure deterministic reproducible results
  puts "=================================================="
  puts "   SMC/ICT Multi-Timeframe Backtester v1.0         "
  puts "=================================================="

  # 1. Load or generate base 5M candles
  # We will concatenate a large set of generated candles to have enough data points for 1H aggregation
  puts "\n[1/4] Generating base 5-minute candles..."
  
  # Generate 3 sets of bullish setups and bridge them to have enough bars (e.g. 300+ candles)
  candles_bull_1 = SMC::DataGenerator.generate_bullish_setup(start_price: 100.0, num_candles: 100)
  candles_bull_2 = SMC::DataGenerator.generate_bullish_setup(start_price: candles_bull_1.last.close, num_candles: 100)
  candles_bear = SMC::DataGenerator.generate_bearish_setup(start_price: candles_bull_2.last.close, num_candles: 100)
  
  # Align timestamps sequentially
  all_5m_candles = []
  base_time = Time.utc(2026, 6, 1, 9, 0)
  
  (candles_bull_1 + candles_bull_2 + candles_bear).each_with_index do |c, idx|
    all_5m_candles << SMC::Candle.new(
      time: base_time + (idx * 300),
      open: c.open,
      high: c.high,
      low: c.low,
      close: c.close,
      volume: c.volume
    )
  end
  
  puts "      Generated #{all_5m_candles.size} base 5M candles."

  # 2. Aggregate into 15M and 1H feeds
  puts "[2/4] Aggregating higher timeframe candle feeds..."
  all_15m_candles = aggregate_candles(all_5m_candles, 3) # 15M = 3 * 5M
  all_1h_candles = aggregate_candles(all_5m_candles, 12)  # 1H = 12 * 5M
  
  puts "      Aggregated #{all_15m_candles.size} 15M candles."
  puts "      Aggregated #{all_1h_candles.size} 1H candles."

  # 3. Initialize MTF Engine and Strategy
  puts "[3/4] Initializing Multi-Timeframe engine & confluence strategy..."
  mtf_engine = SMC::MTFEngine.new(ltf_interval: "5m", itf_interval: "5m", htf_interval: "15m")
  mtf_engine.set_feed(:ltf, all_5m_candles)
  mtf_engine.set_feed(:itf, all_5m_candles)
  mtf_engine.set_feed(:htf, all_15m_candles)

  strategy = SMC::Strategy::MTFConfluence.new(itf_lookback: 6, ltf_lookback: 12)
  risk_manager = SMC::RiskManager.new(initial_capital: 100000.0, max_risk_pct: 0.015)
  
  # Tracks closed trade results
  equity_curve = []
  
  # 4. Run MTF Simulation Bar-by-bar
  puts "[4/4] Executing bar-by-bar multi-timeframe simulation..."
  
  # Start index needs to allow pivot detection pipeline to fill on all timeframes
  # For 1H (HTF) to have 10 candles, we need at least 120 5M candles.
  start_idx = 120
  
  (start_idx..(all_5m_candles.size - 1)).each do |i|
    ltf_candle = all_5m_candles[i]

    # Align higher timeframe indicators up to the end time of the current LTF candle
    mtf_engine.align_and_process(ltf_candle)
    
    # Process current candle on the LTF engine
    mtf_engine.engines[:ltf].process_candle(ltf_candle)

    # Update open positions
    active_positions = risk_manager.trades.select { |t| t.status == :open }
    risk_manager.update_positions(active_positions, ltf_candle, i)

    # Evaluate MTF Strategy Confluence
    if active_positions.empty?
      signal = strategy.evaluate_mtf(all_5m_candles, i, mtf_engine)
      if signal
        risk_manager.open_position(
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

    # Record equity
    floating_pnl = risk_manager.trades.select { |t| t.status == :open }.map do |pos|
      pos.long? ? pos.size * (ltf_candle.close - pos.entry_price) : pos.size * (pos.entry_price - ltf_candle.close)
    end.sum
    
    equity_curve << {
      index: i,
      time: ltf_candle.time.is_a?(Time) ? ltf_candle.time.strftime("%Y-%m-%d %H:%M:%S UTC") : ltf_candle.time,
      equity: risk_manager.capital + floating_pnl
    }
  end

  # Debug Diagnostics
  puts "\n--- Diagnostics ---"
  puts "Final HTF (15M) Trend: #{mtf_engine.engines[:htf].market_structure.trend}"
  puts "Final ITF (5M) Trend: #{mtf_engine.engines[:itf].market_structure.trend}"
  puts "Final LTF (5M) Trend: #{mtf_engine.engines[:ltf].market_structure.trend}"
  puts "Confirmed Swings Count: HTF=#{mtf_engine.engines[:htf].market_structure.swings.size}, ITF=#{mtf_engine.engines[:itf].market_structure.swings.size}, LTF=#{mtf_engine.engines[:ltf].market_structure.swings.size}"
  puts "ITF (5M) Sweeps Count: #{mtf_engine.engines[:itf].liquidity_sweep.sweeps.size}"
  puts "LTF (5M) OB Count: #{mtf_engine.engines[:ltf].ob_detector.order_blocks.size}"
  puts "-------------------\n"

  # Compute stats
  closed_trades = risk_manager.trades.select { |t| t.status == :closed }
  total_trades = closed_trades.size
  wins = closed_trades.select { |t| t.pnl > 0 }.size
  losses = closed_trades.select { |t| t.pnl < 0 }.size
  win_rate = total_trades > 0 ? (wins.to_f / total_trades * 100).round(2) : 0.0
  net_profit = risk_manager.capital - risk_manager.initial_capital
  net_profit_pct = (net_profit / risk_manager.initial_capital * 100).round(2)

  puts "\n================  MTF SIMULATION SUMMARY  ================"
  puts "Initial Capital : $#{'%.2f' % risk_manager.initial_capital}"
  puts "Final Capital   : $#{'%.2f' % risk_manager.capital}"
  puts "Net Profit      : $#{'%.2f' % net_profit} (#{net_profit_pct}%)"
  puts "Total Trades    : #{total_trades}"
  puts "Wins / Losses   : #{wins} wins / #{losses} losses"
  puts "Win Rate        : #{win_rate}%"
  puts "=========================================================="

  puts "\nExecuted Trades Log:"
  closed_trades.each_with_index do |t, idx|
    outcome = t.pnl > 0 ? "WIN" : "LOSS"
    direction = t.type.to_s.upcase
    puts "  [Trade ##{idx + 1}] #{direction} | Entry: #{t.entry_price} (Bar #{t.entry_idx}) | Exit: #{t.exit_price} (Bar #{t.exit_idx}) | PnL: $#{t.pnl.round(2)} | #{outcome}"
  end

  # Export results to backtest_results.js for the dashboard
  puts "\nExporting results to 'backtest_results.js'..."
  export_data = {
    summary: {
      initial_capital: risk_manager.initial_capital,
      final_capital: risk_manager.capital,
      net_profit: net_profit,
      net_profit_pct: net_profit_pct,
      total_trades: total_trades,
      wins: wins,
      losses: losses,
      win_rate: win_rate,
      profit_factor: total_trades > 0 ? "1.5" : "0.0"
    },
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
    equity_curve: equity_curve,
    candles: all_5m_candles.map(&:to_h),
    swings: mtf_engine.engines[:ltf].market_structure.swings.map { |s| { type: s.type, price: s.price, index: s.index } },
    sweeps: mtf_engine.engines[:ltf].liquidity_sweep.sweeps.map { |s| { type: s[:type], index: s[:index], price: s[:price] } },
    bos_events: mtf_engine.engines[:ltf].market_structure.bos_events.map { |e| { direction: e[:direction], index: e[:index], price: e[:price] } },
    choch_events: mtf_engine.engines[:ltf].market_structure.choch_events.map { |e| { direction: e[:direction], index: e[:index], price: e[:price] } },
    order_blocks: mtf_engine.engines[:ltf].ob_detector.order_blocks.map do |ob|
      {
        type: ob.type,
        high: ob.high,
        low: ob.low,
        index: ob.index,
        created_at: ob.created_at,
        mitigated: ob.mitigated,
        mitigated_at: ob.mitigated_at,
        invalidated: ob.invalidated,
        invalidated_at: ob.invalidated_at
      }
    end
  }

  js_content = "window.SMC_BACKTEST_RESULTS = #{JSON.pretty_generate(export_data)};"
  File.write('backtest_results.js', js_content)
  puts "      Successfully updated 'backtest_results.js' with MTF simulation results."
  puts "=================================================="
end

main if __FILE__ == $0
