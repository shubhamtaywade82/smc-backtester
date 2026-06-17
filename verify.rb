# frozen_string_literal: true

require 'test/unit'
require_relative 'lib/smc/candle'
require_relative 'lib/smc/pivot_detector'
require_relative 'lib/smc/market_structure'
require_relative 'lib/smc/liquidity_sweep'
require_relative 'lib/smc/order_block'
require_relative 'lib/smc/strategy'
require_relative 'lib/smc/risk_manager'
require_relative 'lib/smc/backtester'
require_relative 'lib/smc/data_generator'

class TestSMCBacktester < Test::Unit::TestCase
  def setup
    # Generate test candles
    @candles = SMC::DataGenerator.generate_bullish_setup(start_price: 100.0, num_candles: 60)
  end

  def test_candle_properties
    candle = SMC::Candle.new(time: Time.now, open: 10, high: 15, low: 8, close: 12, volume: 100)
    assert_true candle.bullish?
    assert_false candle.bearish?
    assert_equal 2.0, candle.body_size
    assert_equal 12.0, candle.body_high
    assert_equal 10.0, candle.body_low
    assert_equal 3.0, candle.upper_wick
    assert_equal 2.0, candle.lower_wick
    assert_equal 7.0, candle.size
  end

  def test_pivot_detection
    detector = SMC::PivotDetector.new(left_bars: 2, right_bars: 2)
    # Create a sequence with a clear swing high
    candles = [
      SMC::Candle.new(time: Time.now, open: 10, high: 11, low: 9, close: 10),
      SMC::Candle.new(time: Time.now, open: 10, high: 11, low: 9, close: 10),
      SMC::Candle.new(time: Time.now, open: 10, high: 15, low: 9, close: 10), # Swing High here
      SMC::Candle.new(time: Time.now, open: 10, high: 11, low: 9, close: 10),
      SMC::Candle.new(time: Time.now, open: 10, high: 11, low: 9, close: 10)
    ]
    swings = detector.detect_swings(candles)
    assert_equal 1, swings.size
    assert_equal :high, swings.first.type
    assert_equal 15.0, swings.first.price
    assert_equal 2, swings.first.index
  end

  def test_market_structure_bos
    ms = SMC::MarketStructure.new
    # Create fake swing highs
    swing_high1 = SMC::PivotDetector::Swing.new(:high, 110.0, 10, SMC::Candle.new(time: Time.now, open: 109, high: 110, low: 108, close: 109))
    
    confirmed_swings = [swing_high1]
    
    # Candle that closes above the swing high (BOS)
    break_candle = SMC::Candle.new(time: Time.now, open: 112, high: 115, low: 111, close: 114)
    ms.update(confirmed_swings, break_candle, 25)
    
    assert_equal 1, ms.bos_events.size
    assert_equal :bullish, ms.bos_events.first[:direction]
    assert_equal 110.0, ms.bos_events.first[:swing].price
  end

  def test_order_block_mitigation
    detector = SMC::OrderBlockDetector.new
    ob = SMC::OrderBlock.new(
      type: :bullish,
      high: 105.0,
      low: 100.0,
      index: 10,
      candle: SMC::Candle.new(time: Time.now, open: 104, high: 105, low: 100, close: 101),
      created_at: 15
    )
    detector.order_blocks << ob

    # Candle that mitigates OB (dips below 105.0)
    mitigating_candle = SMC::Candle.new(time: Time.now, open: 107, high: 108, low: 104, close: 106)
    detector.update_mitigations(mitigating_candle, 20)
    assert_true ob.mitigated
    assert_equal 20, ob.mitigated_at
    assert_false ob.invalidated
  end

  def test_risk_manager_size
    rm = SMC::RiskManager.new(initial_capital: 100000.0, max_risk_pct: 0.01)
    size = rm.calculate_position_size(100.0, 98.0)
    assert_equal 500, size
  end

  def test_mtf_alignment
    require_relative 'lib/smc/mtf_engine'
    
    # 5M ltf, 15M itf, 1H htf
    engine = SMC::MTFEngine.new(ltf_interval: "5m", itf_interval: "15m", htf_interval: "1h")
    
    # Create 5M candle representing 09:10-09:15 (closed at 09:15)
    ltf_candle = SMC::Candle.new(time: Time.utc(2026, 6, 1, 9, 10), open: 100, high: 101, low: 99, close: 100)
    
    # Create 15M candles:
    # 1. 09:00-09:15 (closed at 09:15) -> should be processed
    # 2. 09:15-09:30 (closed at 09:30) -> should NOT be processed
    itf_candle1 = SMC::Candle.new(time: Time.utc(2026, 6, 1, 9, 0), open: 100, high: 102, low: 98, close: 101)
    itf_candle2 = SMC::Candle.new(time: Time.utc(2026, 6, 1, 9, 15), open: 101, high: 103, low: 99, close: 102)
    
    engine.set_feed(:itf, [itf_candle1, itf_candle2])
    
    engine.align_and_process(ltf_candle)
    
    # Check that only the first 15m candle is processed
    assert_equal 1, engine.engines[:itf].candles.size
    assert_equal Time.utc(2026, 6, 1, 9, 0), engine.engines[:itf].candles.first.time
  end
end
