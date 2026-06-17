# SMC Backtester Gem

`smc-backtester` is a pure Ruby Object-Oriented rules engine and simulator implementing Smart Money Concepts (SMC) and ICT institutional trading playbook rules.

## Features

- **Pivot Detection**: Swing Highs and Swing Lows.
- **Market Structure Shift Detection**: Break of Structure (BOS) and Change of Character (CHoCH).
- **Liquidity Sweeps**: Detects Equal Highs/Lows and tracks structural sweep events.
- **Order Blocks (OB)**: Tracks the formation, mitigation, and invalidation of bullish and bearish Order Blocks.
- **Risk Management**: Enforces position sizing based on account capital, risk percentages, and stop loss distance.
- **Multi-Timeframe Engine (MTF)**: Runs bar-by-bar alignment of higher timeframe feeds (e.g., 15M/1H) against lower timeframe entry charts (e.g., 5M/1M) to prevent look-ahead bias.
- **Interactive Visual Dashboard**: Generates standard JSON execution records that plug directly into the premium HTML dashboard (`smc-playbook.html`).

---

## Installation

### From Source
Clone the repository and build/install the gem locally:

```bash
git clone https://github.com/shubhamtaywade82/smc-backtester.git
cd smc-backtester
gem build smc-backtester.gemspec
gem install smc-backtester-1.0.0.gem
```

### In a Gemfile
Add this line to your application's `Gemfile`:

```ruby
gem 'smc-backtester', path: 'path/to/smc-backtester'
```

---

## Command Line Interface (CLI)

The gem exposes three executable commands for simulating trading rules:

### 1. Standard Backtester
Run a single-timeframe backtest over simulated price feeds or your custom JSON candle files:

```bash
# Run with simulated mock market data
smc-backtest

# Run with a custom JSON candle feed
smc-backtest --feed path/to/candles.json
```

### 2. Multi-Timeframe (MTF) Backtester
Simulates the advanced confluenced strategy (HTF Trend Bias $\rightarrow$ ITF Liquidity Sweep $\rightarrow$ LTF OB Retest Entry):

```bash
smc-mtf-backtest
```

### 3. CoinDCX Data Integrator & Simulator
Fetches public candle data for any pair directly from the CoinDCX API and executes the backtester on it:

```bash
# Fetch 150 5m candles for BTC/USDT and backtest them
smc-fetch-coindcx -p B-BTC_USDT -i 5m -l 150
```

*Options for `smc-fetch-coindcx`:*
- `-p`, `--pair PAIR`: CoinDCX pair name (default: `B-BTC_USDT`)
- `-i`, `--interval INTERVAL`: Candle interval: `1m`, `5m`, `1h`, etc. (default: `5m`)
- `-l`, `--limit LIMIT`: Number of candles to retrieve (default: `150`)
- `-o`, `--output FILE`: Output JSON file path (default: `coindcx_candles.json`)
- `--[no-]backtest`: Run the backtester on the fetched data (default: `true`)

---

## Dashboard Visualization

Every backtest execution generates a `backtest_results.js` file in the current working directory containing simulation statistics, equity curve coordinates, and event markers (swings, sweeps, BOS, CHoCH, OBs).

To view the simulation on the interactive dashboard:
1. Run a backtest command (e.g. `smc-mtf-backtest`).
2. Open `smc-playbook.html` in your web browser.
3. Click the **Backtest Simulator** tab to analyze the interactive chart overlays, metrics, and rule matrices.

---

## Library Usage

You can require the library and build your own custom strategies:

```ruby
require 'smc'

# Create candles
candles = [
  SMC::Candle.new(time: Time.now, open: 100, high: 105, low: 98, close: 102, volume: 1500)
]

# Detect Pivot Swings
pivot_detector = SMC::PivotDetector.new(left_bars: 2, right_bars: 2)
swings = pivot_detector.detect_swings(candles)

# Analyze market structure
market_structure = SMC::MarketStructure.new
market_structure.update(swings, candles.last, 0)
puts "Current Trend: #{market_structure.trend}" # :BULLISH, :BEARISH, or :RANGE
```

---

## Running Development Tests

Run the test suite using Rake:

```bash
bundle exec rake test
```
