# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/candle_builder'

describe SMC::Liquidity::StrongLowDetector do
  subject(:detector) do
    described_class.new(
      displacement: displacement,
      max_displacement_bars: max_displacement_bars,
      max_bos_bars: max_bos_bars,
      accept_choch_as_structure_break: accept_choch
    )
  end

  let(:displacement) { SMC::Liquidity::Displacement.new(atr: SMC::ATR.new(period: 3, smoothing: :wilder)) }
  let(:max_displacement_bars) { 4 }
  let(:max_bos_bars) { 5 }
  let(:accept_choch) { false }

  def quiet_candles(count: 4, base: 10.0)
    sequence(Array.new(count) { { open: base, high: base + 1, low: base, close: base + 0.5 } })
  end

  def swing_low(index:, price:, candle: nil)
    candle ||= build(open: price + 0.2, high: price + 0.5, low: price, close: price + 0.1)
    SMC::PivotDetector::Swing.new(:low, price, index, candle)
  end

  def swing_high(index:, price:, candle: nil)
    candle ||= build(open: price - 0.2, high: price, low: price - 0.5, close: price - 0.1)
    SMC::PivotDetector::Swing.new(:high, price, index, candle)
  end

  def bullish_bos(index:, price: 12.0, swing: nil)
    { direction: :bullish, index: index, price: price, swing: swing, candle: build(open: price - 1, high: price, low: price - 2, close: price) }
  end

  def bullish_choch(index:, price: 12.0, swing: nil)
    { direction: :bullish, index: index, price: price, swing: swing, candle: build(open: price - 1, high: price, low: price - 2, close: price) }
  end

  describe '#initialize' do
    context 'when max_displacement_bars is zero' do
      let(:max_displacement_bars) { 0 }

      it 'raises ArgumentError' do
        expect { detector }.to raise_error(ArgumentError, /max_displacement_bars/)
      end
    end

    context 'when max_bos_bars is negative' do
      let(:max_bos_bars) { -1 }

      it 'raises ArgumentError' do
        expect { detector }.to raise_error(ArgumentError, /max_bos_bars/)
      end
    end
  end

  describe '#evaluate_swing' do
    let(:swing) { swing_low(index: 5, price: 9.0) }
    let(:broken_high) { swing_high(index: 3, price: 11.0) }
    let(:bos_events) { [bullish_bos(index: 8, price: 11.5, swing: broken_high)] }
    let(:choch_events) { [] }
    let(:candles) do
      quiet_candles +
        [
          build(open: 10.5, high: 11.0, low: 10.0, close: 10.5),
          build(open: 10.5, high: 10.8, low: 9.0, close: 9.2),
          build(open: 9.2, high: 9.6, low: 9.0, close: 9.4),
          build(open: 9.4, high: 12.0, low: 9.3, close: 11.8),
          build(open: 11.8, high: 12.0, low: 11.5, close: 11.9)
        ]
    end

    context 'when swing low is followed by bullish displacement and bullish BOS' do
      it 'returns a strong low event' do
        result = detector.evaluate_swing(candles, swing, bos_events: bos_events, choch_events: choch_events)

        expect(result).to include(
          swing: swing,
          price: 9.0,
          swing_index: 5,
          confirmed_at: 8
        )
        expect(result[:displacement][:direction]).to eq(:bullish)
        expect(result[:displacement][:index]).to eq(7)
        expect(result[:bos][:direction]).to eq(:bullish)
        expect(result[:protected]).to be(true)
      end
    end

    context 'when swing is a high instead of a low' do
      let(:swing) { swing_high(index: 5, price: 12.0) }

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when no bullish displacement follows the swing low' do
      let(:candles) do
        quiet_candles +
          [
            build(open: 10.5, high: 10.8, low: 9.0, close: 9.2),
            build(open: 9.2, high: 9.5, low: 9.0, close: 9.3),
            build(open: 9.3, high: 9.5, low: 9.1, close: 9.4),
            build(open: 9.4, high: 9.6, low: 9.2, close: 9.5)
          ]
      end

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when displacement exists but no bullish BOS follows' do
      let(:bos_events) { [] }

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when BOS occurs before displacement' do
      let(:bos_events) { [bullish_bos(index: 6, price: 11.5, swing: broken_high)] }

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when BOS occurs too many bars after displacement' do
      let(:max_bos_bars) { 1 }
      let(:bos_events) { [bullish_bos(index: 9, price: 12.0, swing: broken_high)] }

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when displacement occurs too many bars after the swing low' do
      let(:max_displacement_bars) { 1 }
      let(:candles) do
        quiet_candles +
          [
            build(open: 10.5, high: 10.8, low: 9.0, close: 9.2),
            build(open: 9.2, high: 9.5, low: 9.0, close: 9.3),
            build(open: 9.3, high: 9.5, low: 9.1, close: 9.35),
            build(open: 9.35, high: 9.6, low: 9.2, close: 9.4),
            build(open: 9.4, high: 12.0, low: 9.3, close: 11.8)
          ]
      end

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when only bullish CHoCH occurs and CHoCH is not accepted' do
      let(:bos_events) { [] }
      let(:choch_events) { [bullish_choch(index: 8, price: 11.5, swing: broken_high)] }

      it 'returns nil' do
        expect(
          detector.evaluate_swing(candles, swing, bos_events: bos_events, choch_events: choch_events)
        ).to be_nil
      end
    end

    context 'when bullish CHoCH is accepted as structure break' do
      let(:accept_choch) { true }
      let(:bos_events) { [] }
      let(:choch_events) { [bullish_choch(index: 8, price: 11.5, swing: broken_high)] }

      it 'returns a strong low confirmed by CHoCH' do
        result = detector.evaluate_swing(candles, swing, bos_events: bos_events, choch_events: choch_events)

        expect(result[:bos][:direction]).to eq(:bullish)
        expect(result[:structure_break_type]).to eq(:choch)
      end
    end

    context 'when bearish BOS is provided' do
      let(:bos_events) do
        [{ direction: :bearish, index: 8, price: 8.0, swing: swing, candle: build(open: 9.0, high: 9.0, low: 8.0, close: 8.0) }]
      end

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end
  end

  describe '#detect_all' do
    let(:first_swing) { swing_low(index: 5, price: 9.0) }
    let(:second_swing) { swing_low(index: 9, price: 8.5) }
    let(:swings) { [first_swing, second_swing] }
    let(:bos_events) do
      [
        bullish_bos(index: 8, price: 11.5, swing: swing_high(index: 3, price: 11.0)),
        bullish_bos(index: 12, price: 12.0, swing: swing_high(index: 7, price: 12.0))
      ]
    end
    let(:candles) do
      quiet_candles +
        [
          build(open: 10.5, high: 10.8, low: 9.0, close: 9.2),
          build(open: 9.2, high: 9.6, low: 9.0, close: 9.4),
          build(open: 9.4, high: 12.0, low: 9.3, close: 11.8),
          build(open: 11.8, high: 12.0, low: 11.5, close: 11.9),
          build(open: 11.9, high: 12.0, low: 11.0, close: 11.2),
          build(open: 11.2, high: 11.4, low: 8.5, close: 8.8),
          build(open: 8.8, high: 9.0, low: 8.5, close: 8.9),
          build(open: 8.9, high: 14.0, low: 8.8, close: 13.5),
          build(open: 13.5, high: 14.0, low: 13.2, close: 13.8)
        ]
    end

    it 'returns all valid strong lows in swing order' do
      results = detector.detect_all(candles, swings, bos_events: bos_events)

      expect(results.size).to eq(2)
      expect(results.map { |event| event[:swing_index] }).to eq([5, 9])
      expect(results.all? { |event| event[:protected] }).to be(true)
    end

    context 'when only one swing low qualifies' do
      let(:bos_events) { [bullish_bos(index: 8, price: 11.5, swing: swing_high(index: 3, price: 11.0))] }

      it 'returns a single result' do
        results = detector.detect_all(candles, swings, bos_events: bos_events)

        expect(results.size).to eq(1)
        expect(results.first[:swing_index]).to eq(5)
      end
    end

    context 'when no swing lows qualify' do
      let(:bos_events) { [] }

      it 'returns an empty array' do
        expect(detector.detect_all(candles, swings, bos_events: bos_events)).to eq([])
      end
    end

    it 'does not duplicate the same swing on repeated scans' do
      detector.detect_all(candles, swings, bos_events: bos_events)
      second_scan = detector.detect_all(candles, swings, bos_events: bos_events)

      expect(second_scan).to eq([])
      expect(detector.strong_lows.size).to eq(2)
    end
  end

  describe '#confirm' do
    let(:swing) { swing_low(index: 5, price: 9.0) }
    let(:bos_events) { [bullish_bos(index: 8, price: 11.5, swing: swing_high(index: 3, price: 11.0))] }
    let(:candles) do
      quiet_candles +
        [
          build(open: 10.5, high: 10.8, low: 9.0, close: 9.2),
          build(open: 9.2, high: 9.6, low: 9.0, close: 9.4),
          build(open: 9.4, high: 12.0, low: 9.3, close: 11.8),
          build(open: 11.8, high: 12.0, low: 11.5, close: 11.9)
        ]
    end

    it 'registers the strong low and updates protected_low' do
      result = detector.confirm(candles, swing, bos_events: bos_events)

      expect(result[:swing_index]).to eq(5)
      expect(detector.protected_low).to eq(result)
      expect(detector.strong_low?(5)).to be(true)
    end

    context 'when the swing does not qualify' do
      let(:bos_events) { [] }

      it 'returns nil and does not register' do
        expect(detector.confirm(candles, swing, bos_events: bos_events)).to be_nil
        expect(detector.protected_low).to be_nil
        expect(detector.strong_low?(5)).to be(false)
      end
    end
  end

  describe '#latest' do
    it 'returns the most recently confirmed strong low' do
      swing = swing_low(index: 5, price: 9.0)
      bos_events = [bullish_bos(index: 8, price: 11.5, swing: swing_high(index: 3, price: 11.0))]
      candles = quiet_candles +
                [
                  build(open: 10.5, high: 10.8, low: 9.0, close: 9.2),
                  build(open: 9.2, high: 9.6, low: 9.0, close: 9.4),
                  build(open: 9.4, high: 12.0, low: 9.3, close: 11.8),
                  build(open: 11.8, high: 12.0, low: 11.5, close: 11.9)
                ]

      detector.confirm(candles, swing, bos_events: bos_events)

      expect(detector.latest[:swing_index]).to eq(5)
    end

    context 'when nothing has been confirmed' do
      it 'returns nil' do
        expect(detector.latest).to be_nil
      end
    end
  end

  describe 'integration with market structure pipeline' do
    subject(:integration_detector) do
      described_class.new(
        displacement: displacement,
        accept_choch_as_structure_break: true
      )
    end

    it 'detects a strong low from live structure events' do
      pivot_detector = SMC::PivotDetector.new(left_bars: 2, right_bars: 2)
      market_structure = SMC::MarketStructure.new
      candles = quiet_candles(count: 4, base: 20.0) +
                [
                  build(open: 20.0, high: 21.5, low: 20.0, close: 21.0),
                  build(open: 21.0, high: 21.2, low: 20.5, close: 20.8),
                  build(open: 20.8, high: 21.0, low: 17.5, close: 18.0),
                  build(open: 18.0, high: 18.5, low: 17.8, close: 18.3),
                  build(open: 18.3, high: 18.8, low: 18.0, close: 18.6),
                  build(open: 18.6, high: 22.0, low: 18.5, close: 21.5),
                  build(open: 21.5, high: 22.5, low: 21.2, close: 22.2)
                ]

      candles.each_with_index do |candle, index|
        swings = pivot_detector.detect_swings(candles[0..index])
        market_structure.update(swings, candle, index)
      end

      swing_lows = market_structure.swings.select { |swing| swing.type == :low }
      target_swing = swing_lows.min_by(&:price)
      expect(target_swing).not_to be_nil
      expect(market_structure.bos_events + market_structure.choch_events).not_to be_empty

      results = integration_detector.detect_all(
        candles,
        [target_swing],
        bos_events: market_structure.bos_events,
        choch_events: market_structure.choch_events
      )

      expect(results.size).to eq(1)
      expect(results.first[:price]).to eq(target_swing.price)
      expect(results.first[:confirmed_at]).to be > results.first[:displacement][:index]
    end
  end
end
