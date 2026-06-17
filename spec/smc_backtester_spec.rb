# frozen_string_literal: true

require 'spec_helper'

describe SMC::Candle do
  describe '#bullish?' do
    context 'when close is higher than open' do
      subject(:candle) { described_class.new(time: Time.now, open: 10, high: 15, low: 8, close: 12, volume: 100) }

      it { is_expected.to be_bullish }
      it { is_expected.not_to be_bearish }
    end
  end

  describe 'wick and body helpers' do
    subject(:candle) { described_class.new(time: Time.now, open: 10, high: 15, low: 8, close: 12, volume: 100) }

    it 'returns the correct body size' do
      expect(candle.body_size).to eq(2.0)
    end

    it 'returns the correct body high' do
      expect(candle.body_high).to eq(12.0)
    end

    it 'returns the correct body low' do
      expect(candle.body_low).to eq(10.0)
    end

    it 'returns the correct upper wick' do
      expect(candle.upper_wick).to eq(3.0)
    end

    it 'returns the correct lower wick' do
      expect(candle.lower_wick).to eq(2.0)
    end

    it 'returns the correct total size' do
      expect(candle.size).to eq(7.0)
    end
  end
end

describe SMC::PivotDetector do
  describe '#detect_swings' do
    subject(:detector) { described_class.new(left_bars: 2, right_bars: 2) }
    let(:candles) do
      [
        SMC::Candle.new(time: Time.now, open: 10, high: 11, low: 9, close: 10),
        SMC::Candle.new(time: Time.now, open: 10, high: 11, low: 9, close: 10),
        SMC::Candle.new(time: Time.now, open: 10, high: 15, low: 9, close: 10), # Swing High
        SMC::Candle.new(time: Time.now, open: 10, high: 11, low: 9, close: 10),
        SMC::Candle.new(time: Time.now, open: 10, high: 11, low: 9, close: 10)
      ]
    end

    it 'detects a swing high correctly' do
      swings = detector.detect_swings(candles)
      expect(swings.size).to eq(1)
      expect(swings.first.type).to eq(:high)
      expect(swings.first.price).to eq(15.0)
      expect(swings.first.index).to eq(2)
    end
  end
end

describe SMC::MarketStructure do
  describe '#update' do
    subject(:market_structure) { described_class.new }
    let(:swing_high) do
      SMC::PivotDetector::Swing.new(
        :high,
        110.0,
        10,
        SMC::Candle.new(time: Time.now, open: 109, high: 110, low: 108, close: 109)
      )
    end
    let(:break_candle) { SMC::Candle.new(time: Time.now, open: 112, high: 115, low: 111, close: 114) }

    it 'registers a Break of Structure (BOS) when price closes above a swing high' do
      market_structure.update([swing_high], break_candle, 25)
      expect(market_structure.bos_events.size).to eq(1)
      expect(market_structure.bos_events.first[:direction]).to eq(:bullish)
      expect(market_structure.bos_events.first[:swing].price).to eq(110.0)
    end
  end
end

describe SMC::OrderBlockDetector do
  describe '#update_mitigations' do
    subject(:detector) { described_class.new }
    let(:ob) do
      SMC::OrderBlock.new(
        type: :bullish,
        high: 105.0,
        low: 100.0,
        index: 10,
        candle: SMC::Candle.new(time: Time.now, open: 104, high: 105, low: 100, close: 101),
        created_at: 15
      )
    end
    let(:mitigating_candle) { SMC::Candle.new(time: Time.now, open: 107, high: 108, low: 104, close: 106) }

    before do
      detector.order_blocks << ob
    end

    it 'mitigates the order block when price penetrates the zone' do
      detector.update_mitigations(mitigating_candle, 20)
      expect(ob).to be_mitigated
      expect(ob.mitigated_at).to eq(20)
      expect(ob).not_to be_invalidated
    end
  end
end

describe SMC::RiskManager do
  describe '#calculate_position_size' do
    subject(:risk_manager) { described_class.new(initial_capital: 100000.0, max_risk_pct: 0.01) }

    it 'calculates position size based on risk parameters' do
      size = risk_manager.calculate_position_size(100.0, 98.0)
      expect(size).to eq(500)
    end
  end
end

describe SMC::MTFEngine do
  describe '#align_and_process' do
    subject(:engine) { described_class.new(ltf_interval: "5m", itf_interval: "15m", htf_interval: "1h") }
    let(:ltf_candle) { SMC::Candle.new(time: Time.utc(2026, 6, 1, 9, 10), open: 100, high: 101, low: 99, close: 100) }
    let(:itf_candle1) { SMC::Candle.new(time: Time.utc(2026, 6, 1, 9, 0), open: 100, high: 102, low: 98, close: 101) }
    let(:itf_candle2) { SMC::Candle.new(time: Time.utc(2026, 6, 1, 9, 15), open: 101, high: 103, low: 99, close: 102) }

    before do
      engine.set_feed(:itf, [itf_candle1, itf_candle2])
    end

    it 'only processes higher timeframe candles closed at or before the current LTF candle start time' do
      engine.align_and_process(ltf_candle)
      expect(engine.engines[:itf].candles.size).to eq(1)
      expect(engine.engines[:itf].candles.first.time).to eq(Time.utc(2026, 6, 1, 9, 0))
    end
  end
end
