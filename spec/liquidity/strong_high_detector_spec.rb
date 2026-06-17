# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/candle_builder'

describe SMC::Liquidity::StrongHighDetector do
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

  def bearish_bos(index:, price: 8.0, swing: nil)
    {
      direction: :bearish,
      index: index,
      price: price,
      swing: swing,
      candle: build(open: price + 1, high: price + 2, low: price, close: price)
    }
  end

  def bearish_choch(index:, price: 8.0, swing: nil)
    {
      direction: :bearish,
      index: index,
      price: price,
      swing: swing,
      candle: build(open: price + 1, high: price + 2, low: price, close: price)
    }
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
    let(:swing) { swing_high(index: 5, price: 12.0) }
    let(:broken_low) { swing_low(index: 3, price: 9.0) }
    let(:bos_events) { [bearish_bos(index: 8, price: 8.8, swing: broken_low)] }
    let(:choch_events) { [] }
    let(:candles) do
      quiet_candles +
        [
          build(open: 10.5, high: 11.0, low: 10.0, close: 10.5),
          build(open: 10.5, high: 12.0, low: 10.8, close: 11.8),
          build(open: 11.8, high: 12.0, low: 11.5, close: 11.7),
          build(open: 11.7, high: 11.8, low: 9.2, close: 9.5),
          build(open: 9.5, high: 9.8, low: 9.0, close: 9.2)
        ]
    end

    context 'when swing high is followed by bearish displacement and bearish BOS' do
      it 'returns a strong high event' do
        result = detector.evaluate_swing(candles, swing, bos_events: bos_events, choch_events: choch_events)

        expect(result).to include(
          swing: swing,
          price: 12.0,
          swing_index: 5,
          confirmed_at: 8
        )
        expect(result[:displacement][:direction]).to eq(:bearish)
        expect(result[:displacement][:index]).to eq(7)
        expect(result[:bos][:direction]).to eq(:bearish)
        expect(result[:protected]).to be(true)
      end
    end

    context 'when swing is a low instead of a high' do
      let(:swing) { swing_low(index: 5, price: 9.0) }

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when no bearish displacement follows the swing high' do
      let(:candles) do
        quiet_candles +
          [
            build(open: 10.5, high: 12.0, low: 10.8, close: 11.8),
            build(open: 11.8, high: 12.0, low: 11.6, close: 11.9),
            build(open: 11.9, high: 12.1, low: 11.7, close: 12.0),
            build(open: 12.0, high: 12.2, low: 11.8, close: 12.1)
          ]
      end

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when displacement exists but no bearish BOS follows' do
      let(:bos_events) { [] }

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when BOS occurs before displacement' do
      let(:bos_events) { [bearish_bos(index: 6, price: 8.8, swing: broken_low)] }

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when BOS occurs too many bars after displacement' do
      let(:max_bos_bars) { 1 }
      let(:bos_events) { [bearish_bos(index: 9, price: 8.0, swing: broken_low)] }

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when displacement occurs too many bars after the swing high' do
      let(:max_displacement_bars) { 1 }
      let(:candles) do
        quiet_candles +
          [
            build(open: 10.5, high: 12.0, low: 10.8, close: 11.8),
            build(open: 11.8, high: 12.0, low: 11.6, close: 11.9),
            build(open: 11.9, high: 12.1, low: 11.7, close: 12.0),
            build(open: 12.0, high: 12.2, low: 11.8, close: 12.05),
            build(open: 12.05, high: 12.1, low: 9.0, close: 9.5)
          ]
      end

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end

    context 'when only bearish CHoCH occurs and CHoCH is not accepted' do
      let(:bos_events) { [] }
      let(:choch_events) { [bearish_choch(index: 8, price: 8.8, swing: broken_low)] }

      it 'returns nil' do
        expect(
          detector.evaluate_swing(candles, swing, bos_events: bos_events, choch_events: choch_events)
        ).to be_nil
      end
    end

    context 'when bearish CHoCH is accepted as structure break' do
      let(:accept_choch) { true }
      let(:bos_events) { [] }
      let(:choch_events) { [bearish_choch(index: 8, price: 8.8, swing: broken_low)] }

      it 'returns a strong high confirmed by CHoCH' do
        result = detector.evaluate_swing(candles, swing, bos_events: bos_events, choch_events: choch_events)

        expect(result[:bos][:direction]).to eq(:bearish)
        expect(result[:structure_break_type]).to eq(:choch)
      end
    end

    context 'when bullish BOS is provided' do
      let(:bos_events) do
        [{ direction: :bullish, index: 8, price: 12.0, swing: swing, candle: build(open: 11.0, high: 12.0, low: 10.0, close: 12.0) }]
      end

      it 'returns nil' do
        expect(detector.evaluate_swing(candles, swing, bos_events: bos_events)).to be_nil
      end
    end
  end

  describe '#detect_all' do
    let(:first_swing) { swing_high(index: 5, price: 12.0) }
    let(:second_swing) { swing_high(index: 9, price: 13.5) }
    let(:swings) { [first_swing, second_swing] }
    let(:bos_events) do
      [
        bearish_bos(index: 8, price: 8.8, swing: swing_low(index: 3, price: 9.0)),
        bearish_bos(index: 12, price: 8.0, swing: swing_low(index: 7, price: 9.5))
      ]
    end
    let(:candles) do
      quiet_candles +
        [
          build(open: 10.5, high: 12.0, low: 10.8, close: 11.8),
          build(open: 11.8, high: 12.0, low: 11.5, close: 11.7),
          build(open: 11.7, high: 11.8, low: 9.2, close: 9.5),
          build(open: 9.5, high: 9.8, low: 9.0, close: 9.2),
          build(open: 9.2, high: 13.5, low: 9.0, close: 13.2),
          build(open: 13.2, high: 13.5, low: 13.0, close: 13.3),
          build(open: 13.3, high: 13.5, low: 8.5, close: 9.0),
          build(open: 9.0, high: 9.2, low: 8.8, close: 9.1),
          build(open: 9.1, high: 9.3, low: 8.6, close: 8.8)
        ]
    end

    it 'returns all valid strong highs in swing order' do
      results = detector.detect_all(candles, swings, bos_events: bos_events)

      expect(results.size).to eq(2)
      expect(results.map { |event| event[:swing_index] }).to eq([5, 9])
      expect(results.all? { |event| event[:protected] }).to be(true)
    end

    context 'when only one swing high qualifies' do
      let(:bos_events) { [bearish_bos(index: 8, price: 8.8, swing: swing_low(index: 3, price: 9.0))] }

      it 'returns a single result' do
        results = detector.detect_all(candles, swings, bos_events: bos_events)

        expect(results.size).to eq(1)
        expect(results.first[:swing_index]).to eq(5)
      end
    end

    context 'when no swing highs qualify' do
      let(:bos_events) { [] }

      it 'returns an empty array' do
        expect(detector.detect_all(candles, swings, bos_events: bos_events)).to eq([])
      end
    end

    it 'does not duplicate the same swing on repeated scans' do
      detector.detect_all(candles, swings, bos_events: bos_events)
      second_scan = detector.detect_all(candles, swings, bos_events: bos_events)

      expect(second_scan).to eq([])
      expect(detector.strong_highs.size).to eq(2)
    end
  end

  describe '#confirm' do
    let(:swing) { swing_high(index: 5, price: 12.0) }
    let(:bos_events) { [bearish_bos(index: 8, price: 8.8, swing: swing_low(index: 3, price: 9.0))] }
    let(:candles) do
      quiet_candles +
        [
          build(open: 10.5, high: 12.0, low: 10.8, close: 11.8),
          build(open: 11.8, high: 12.0, low: 11.5, close: 11.7),
          build(open: 11.7, high: 11.8, low: 9.2, close: 9.5),
          build(open: 9.5, high: 9.8, low: 9.0, close: 9.2)
        ]
    end

    it 'registers the strong high and updates protected_high' do
      result = detector.confirm(candles, swing, bos_events: bos_events)

      expect(result[:swing_index]).to eq(5)
      expect(detector.protected_high).to eq(result)
      expect(detector.strong_high?(5)).to be(true)
    end

    context 'when the swing does not qualify' do
      let(:bos_events) { [] }

      it 'returns nil and does not register' do
        expect(detector.confirm(candles, swing, bos_events: bos_events)).to be_nil
        expect(detector.protected_high).to be_nil
        expect(detector.strong_high?(5)).to be(false)
      end
    end
  end

  describe '#latest' do
    it 'returns the most recently confirmed strong high' do
      swing = swing_high(index: 5, price: 12.0)
      bos_events = [bearish_bos(index: 8, price: 8.8, swing: swing_low(index: 3, price: 9.0))]
      candles = quiet_candles +
                [
                  build(open: 10.5, high: 12.0, low: 10.8, close: 11.8),
                  build(open: 11.8, high: 12.0, low: 11.5, close: 11.7),
                  build(open: 11.7, high: 11.8, low: 9.2, close: 9.5),
                  build(open: 9.5, high: 9.8, low: 9.0, close: 9.2)
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

    it 'detects a strong high from live structure events' do
      pivot_detector = SMC::PivotDetector.new(left_bars: 2, right_bars: 2)
      market_structure = SMC::MarketStructure.new
      candles = quiet_candles(count: 4, base: 20.0) +
                [
                  build(open: 20.0, high: 23.0, low: 19.5, close: 22.0),
                  build(open: 22.0, high: 22.5, low: 19.0, close: 20.0),
                  build(open: 20.0, high: 26.5, low: 20.0, close: 26.0),
                  build(open: 26.0, high: 26.2, low: 25.5, close: 25.8),
                  build(open: 25.8, high: 26.0, low: 25.6, close: 25.9),
                  build(open: 25.9, high: 26.0, low: 19.2, close: 19.4),
                  build(open: 19.4, high: 19.6, low: 17.0, close: 17.2)
                ]

      candles.each_with_index do |candle, index|
        swings = pivot_detector.detect_swings(candles[0..index])
        market_structure.update(swings, candle, index)
      end

      swing_highs = market_structure.swings.select { |swing| swing.type == :high }
      target_swing = swing_highs.max_by(&:price)
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
