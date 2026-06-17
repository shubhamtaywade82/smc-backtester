# frozen_string_literal: true

require 'json'
require_relative 'lib/smc/candle'
require_relative 'lib/smc/pivot_detector'
require_relative 'lib/smc/market_structure'
require_relative 'lib/smc/liquidity_sweep'
require_relative 'lib/smc/order_block'
require_relative 'lib/smc/strategy'
require_relative 'lib/smc/risk_manager'
require_relative 'lib/smc/backtester'
require_relative 'lib/smc/data_generator'

def main
  puts "=================================================="
  puts "   SMC/ICT Institutional Backtest Engine v1.0     "
  puts "=================================================="

  # 1. Load data from JSON feed if provided, otherwise generate mock data
  feed_file = nil
  if ARGV[0] == '--feed' && ARGV[1]
    feed_file = ARGV[1]
  end

  all_candles = []
  if feed_file && File.file?(feed_file)
    puts "\n[1/4] Loading candles from JSON feed file '#{feed_file}'..."
    begin
      raw_data = JSON.parse(File.read(feed_file))
      all_candles = raw_data.map do |c|
        SMC::Candle.new(
          time: c["t"],
          open: c["o"],
          high: c["h"],
          low: c["l"],
          close: c["c"],
          volume: c["v"]
        )
      end
    rescue StandardError => e
      puts "Error loading feed file: #{e.message}. Falling back to mock data."
      feed_file = nil
    end
  end

  if feed_file.nil?
    puts "\n[1/4] Generating high-fidelity mock market data..."
    bull_candles = SMC::DataGenerator.generate_bullish_setup(start_price: 100.0, num_candles: 80)
    
    # Transition candles to bridge bullish and bearish setups
    last_bull_price = bull_candles.last.close
    bridge_candles = []
    time = bull_candles.last.time
    (1..10).each do |i|
      bridge_candles << SMC::Candle.new(
        time: time + (i * 300),
        open: last_bull_price,
        high: last_bull_price + 0.5,
        low: last_bull_price - 0.5,
        close: last_bull_price - 0.2,
        volume: 1000
      )
      last_bull_price -= 0.2
    end

    bear_candles = SMC::DataGenerator.generate_bearish_setup(start_price: last_bull_price, num_candles: 80)
    
    # Adjust times for bear candles to follow bridge candles
    start_bear_time = bridge_candles.last.time + 300
    adjusted_bear_candles = bear_candles.each_with_index.map do |c, idx|
      SMC::Candle.new(
        time: start_bear_time + (idx * 300),
        open: c.open,
        high: c.high,
        low: c.low,
        close: c.close,
        volume: c.volume
      )
    end

    all_candles = bull_candles + bridge_candles + adjusted_bear_candles
  end

  puts "      Loaded #{all_candles.size} total candles."

  # 2. Initialize SMC Engine Components
  puts "[2/4] Initializing engine components (SOLID design)..."
  pivot_detector = SMC::PivotDetector.new(left_bars: 4, right_bars: 4)
  market_structure = SMC::MarketStructure.new
  liquidity_sweep = SMC::LiquiditySweep.new(tolerance_pct: 0.0015)
  ob_detector = SMC::OrderBlockDetector.new
  strategy = SMC::Strategy::SweepOB.new(lookback_candles: 15)
  risk_manager = SMC::RiskManager.new(initial_capital: 100000.0, max_risk_pct: 0.01)

  # 3. Create and run the backtester
  puts "[3/4] Running backtest simulation over candles..."
  tester = SMC::Backtester.new(
    candles: all_candles,
    pivot_detector: pivot_detector,
    market_structure: market_structure,
    liquidity_sweep: liquidity_sweep,
    ob_detector: ob_detector,
    strategy: strategy,
    risk_manager: risk_manager
  )

  stats = tester.run

  # 4. Print Summary Terminal Report
  puts "\n================  SIMULATION SUMMARY  ================"
  puts "Initial Capital : $#{'%.2f' % stats[:initial_capital]}"
  puts "Final Capital   : $#{'%.2f' % stats[:final_capital]}"
  puts "Net Profit      : $#{'%.2f' % stats[:net_profit]} (#{stats[:net_profit_pct]}%)"
  puts "Total Trades    : #{stats[:total_trades]}"
  puts "Wins / Losses   : #{stats[:wins]} wins / #{stats[:losses]} losses"
  puts "Win Rate        : #{stats[:win_rate]}%"
  puts "Profit Factor   : #{stats[:profit_factor]}"
  puts "======================================================"

  # Print detailed trade log
  puts "\nExecuted Trades Log:"
  stats[:trades].each_with_index do |t, idx|
    outcome = t[:win] ? "WIN" : "LOSS"
    direction = t[:type].to_s.upcase
    puts "  [Trade ##{idx + 1}] #{direction} | Entry: #{t[:entry_price]} (Bar #{t[:entry_idx]}) | Exit: #{t[:exit_price]} (Bar #{t[:exit_idx]}) | PnL: $#{t[:pnl]} | #{outcome}"
  end

  # 5. Export results to backtest_results.js
  puts "\n[4/4] Exporting backtest data to 'backtest_results.js'..."
  
  # Package additional metrics for visual rendering
  export_data = {
    summary: {
      initial_capital: stats[:initial_capital],
      final_capital: stats[:final_capital],
      net_profit: stats[:net_profit],
      net_profit_pct: stats[:net_profit_pct],
      total_trades: stats[:total_trades],
      wins: stats[:wins],
      losses: stats[:losses],
      win_rate: stats[:win_rate],
      profit_factor: stats[:profit_factor]
    },
    trades: stats[:trades],
    equity_curve: stats[:equity_curve],
    candles: all_candles.map(&:to_h),
    swings: market_structure.swings.map { |s| { type: s.type, price: s.price, index: s.index } },
    sweeps: liquidity_sweep.sweeps.map { |s| { type: s[:type], index: s[:index], price: s[:price] } },
    bos_events: market_structure.bos_events.map { |e| { direction: e[:direction], index: e[:index], price: e[:price] } },
    choch_events: market_structure.choch_events.map { |e| { direction: e[:direction], index: e[:index], price: e[:price] } },
    order_blocks: ob_detector.order_blocks.map do |ob|
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
  
  File.write('/home/nemesis/project/trading-workspace/smc-backtester/backtest_results.js', js_content)
  puts "      Successfully wrote 'backtest_results.js'."
  puts "=================================================="
end

main if __FILE__ == $0
