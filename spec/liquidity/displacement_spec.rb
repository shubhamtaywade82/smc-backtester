# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/candle_builder'

describe SMC::Liquidity::Displacement do
  subject(:displacement) do
    described_class.new(
      atr: atr,
      body_multiplier: body_multiplier,
      range_multiplier: range_multiplier,
      min_body_ratio: min_body_ratio
    )
  end

  let(:atr) { SMC::ATR.new(period: 3, smoothing: :wilder) }
  let(:body_multiplier) { 1.5 }
  let(:range_multiplier) { 2.0 }
  let(:min_body_ratio) { 0.6 }

  def quiet_candles(count: 3, base: 10.0)
    sequence(
      Array.new(count) { { open: base, high: base + 1, low: base, close: base + 0.5 } }
    )
  end

  describe '#initialize' do
    context 'when body_multiplier is zero' do
      it 'raises ArgumentError' do
        expect do
          described_class.new(body_multiplier: 0)
        end.to raise_error(ArgumentError, /body_multiplier/)
      end
    end

    context 'when range_multiplier is negative' do
      it 'raises ArgumentError' do
        expect do
          described_class.new(range_multiplier: -1)
        end.to raise_error(ArgumentError, /range_multiplier/)
      end
    end

    context 'when min_body_ratio is outside zero and one' do
      it 'raises ArgumentError' do
        expect do
          described_class.new(min_body_ratio: 1.5)
        end.to raise_error(ArgumentError, /min_body_ratio/)
      end
    end
  end

  describe '#atr_at' do
    let(:candles) { quiet_candles(count: 4) }

    it 'delegates to the configured ATR calculator using the prior bar' do
      expect(displacement.atr_at(candles, 3)).to eq(atr.value_at(candles, 2))
    end

    context 'when index is out of bounds' do
      it 'returns nil' do
        expect(displacement.atr_at(candles, 99)).to be_nil
      end
    end
  end

  describe '#bullish_at?' do
    context 'when candle has a large bullish body relative to ATR' do
      let(:candles) do
        quiet_candles + [build(open: 10.5, high: 13.0, low: 10.5, close: 12.5)]
      end
      let(:index) { candles.size - 1 }

      it 'returns true' do
        expect(displacement.bullish_at?(candles, index)).to be(true)
      end
    end

    context 'when body is just below the ATR threshold' do
      let(:candles) do
        quiet_candles + [build(open: 10.5, high: 11.7, low: 10.5, close: 11.4)]
      end
      let(:index) { candles.size - 1 }

      it 'returns false' do
        expect(displacement.bullish_at?(candles, index)).to be(false)
      end
    end

    context 'when body is exactly at the ATR threshold' do
      let(:candles) do
        quiet_candles + [build(open: 10.5, high: 12.0, low: 10.5, close: 12.0)]
      end
      let(:index) { candles.size - 1 }

      it 'returns true' do
        expect(displacement.bullish_at?(candles, index)).to be(true)
      end
    end

    context 'when range is explosive but body is too small' do
      let(:candles) do
        quiet_candles + [build(open: 10.5, high: 13.5, low: 10.5, close: 10.8)]
      end
      let(:index) { candles.size - 1 }

      it 'returns false because body ratio is below min_body_ratio' do
        expect(displacement.bullish_at?(candles, index)).to be(false)
      end
    end

    context 'when range qualifies via range_multiplier and body ratio is sufficient' do
      let(:body_multiplier) { 2.5 }
      let(:candles) do
        quiet_candles + [build(open: 10.5, high: 13.0, low: 10.5, close: 12.1)]
      end
      let(:index) { candles.size - 1 }

      it 'returns true' do
        expect(displacement.bullish_at?(candles, index)).to be(true)
      end
    end

    context 'when candle is bearish' do
      let(:candles) do
        quiet_candles + [build(open: 12.0, high: 12.0, low: 10.0, close: 10.0)]
      end
      let(:index) { candles.size - 1 }

      it 'returns false' do
        expect(displacement.bullish_at?(candles, index)).to be(false)
      end
    end

    context 'when ATR is not yet available' do
      let(:candles) { [build(open: 10, high: 15, low: 10, close: 14)] }

      it 'returns false' do
        expect(displacement.bullish_at?(candles, 0)).to be(false)
      end
    end

    context 'when index is out of bounds' do
      let(:candles) { quiet_candles }

      it 'returns false' do
        expect(displacement.bullish_at?(candles, -1)).to be(false)
        expect(displacement.bullish_at?(candles, candles.size)).to be(false)
      end
    end
  end

  describe '#bearish_at?' do
    context 'when candle has a large bearish body relative to ATR' do
      let(:candles) do
        quiet_candles + [build(open: 12.5, high: 12.5, low: 10.0, close: 10.0)]
      end
      let(:index) { candles.size - 1 }

      it 'returns true' do
        expect(displacement.bearish_at?(candles, index)).to be(true)
      end
    end

    context 'when body is below threshold' do
      let(:candles) do
        quiet_candles + [build(open: 11.0, high: 11.0, low: 10.5, close: 10.6)]
      end
      let(:index) { candles.size - 1 }

      it 'returns false' do
        expect(displacement.bearish_at?(candles, index)).to be(false)
      end
    end

    context 'when candle is bullish' do
      let(:candles) do
        quiet_candles + [build(open: 10.0, high: 13.0, low: 10.0, close: 12.5)]
      end
      let(:index) { candles.size - 1 }

      it 'returns false' do
        expect(displacement.bearish_at?(candles, index)).to be(false)
      end
    end

    context 'when range qualifies with sufficient bearish body ratio' do
      let(:candles) do
        quiet_candles + [build(open: 12.3, high: 12.3, low: 9.5, close: 10.5)]
      end
      let(:index) { candles.size - 1 }

      it 'returns true' do
        expect(displacement.bearish_at?(candles, index)).to be(true)
      end
    end
  end

  describe '#direction_at' do
    context 'when candle is bullish displacement' do
      let(:candles) do
        quiet_candles + [build(open: 10.5, high: 13.0, low: 10.5, close: 12.5)]
      end

      it 'returns :bullish' do
        expect(displacement.direction_at(candles, candles.size - 1)).to eq(:bullish)
      end
    end

    context 'when candle is bearish displacement' do
      let(:candles) do
        quiet_candles + [build(open: 12.5, high: 12.5, low: 10.0, close: 10.0)]
      end

      it 'returns :bearish' do
        expect(displacement.direction_at(candles, candles.size - 1)).to eq(:bearish)
      end
    end

    context 'when candle is not displacement' do
      let(:candles) do
        quiet_candles + [build(open: 10.5, high: 11.0, low: 10.4, close: 10.7)]
      end

      it 'returns nil' do
        expect(displacement.direction_at(candles, candles.size - 1)).to be_nil
      end
    end
  end

  describe '#displacement_at' do
    let(:candles) do
      quiet_candles + [build(open: 10.5, high: 13.0, low: 10.5, close: 12.5)]
    end
    let(:index) { candles.size - 1 }

    it 'returns event metadata when displacement exists' do
      event = displacement.displacement_at(candles, index)

      expect(event).to include(
        direction: :bullish,
        index: index,
        candle: candles[index],
        body: candles[index].body_size,
        range: candles[index].size
      )
      expect(event[:atr]).to be_a(Float)
      expect(event[:body_threshold]).to eq(event[:atr] * body_multiplier)
      expect(event[:range_threshold]).to eq(event[:atr] * range_multiplier)
    end

    context 'when no displacement exists' do
      let(:candles) do
        quiet_candles + [build(open: 10.5, high: 11.0, low: 10.4, close: 10.7)]
      end

      it 'returns nil' do
        expect(displacement.displacement_at(candles, index)).to be_nil
      end
    end
  end

  describe '#find_after' do
    let(:candles) do
      quiet_candles +
        [
          build(open: 10.5, high: 11.0, low: 10.4, close: 10.7),
          build(open: 10.7, high: 13.0, low: 10.7, close: 12.5),
          build(open: 12.5, high: 12.5, low: 10.0, close: 10.0)
        ]
    end

    it 'finds the first bullish displacement after start_index' do
      event = displacement.find_after(candles, start_index: 2, direction: :bullish, lookback: 5)

      expect(event[:index]).to eq(4)
      expect(event[:direction]).to eq(:bullish)
    end

    it 'finds the first bearish displacement after start_index' do
      event = displacement.find_after(candles, start_index: 4, direction: :bearish, lookback: 3)

      expect(event[:index]).to eq(5)
      expect(event[:direction]).to eq(:bearish)
    end

    context 'when no displacement exists in lookback window' do
      it 'returns nil' do
        expect(
          displacement.find_after(candles, start_index: 2, direction: :bearish, lookback: 2)
        ).to be_nil
      end
    end

    context 'when direction is invalid' do
      it 'raises ArgumentError' do
        expect do
          displacement.find_after(candles, start_index: 2, direction: :sideways, lookback: 3)
        end.to raise_error(ArgumentError, /direction/)
      end
    end

    context 'when lookback is zero' do
      it 'raises ArgumentError' do
        expect do
          displacement.find_after(candles, start_index: 2, direction: :bullish, lookback: 0)
        end.to raise_error(ArgumentError, /lookback/)
      end
    end
  end

  describe '#from_swing?' do
    let(:swing) do
      SMC::PivotDetector::Swing.new(
        :low,
        10.0,
        2,
        build(open: 10.2, high: 10.5, low: 10.0, close: 10.3)
      )
    end

    context 'when bullish displacement follows a swing low' do
      let(:candles) do
        quiet_candles +
          [
            build(open: 10.3, high: 10.6, low: 10.0, close: 10.2),
            build(open: 10.2, high: 12.5, low: 10.1, close: 12.0)
          ]
      end

      it 'returns true' do
        expect(displacement.from_swing?(candles, swing, direction: :bullish, max_bars_after: 3)).to be(true)
      end
    end

    context 'when only a small candle follows the swing low' do
      let(:candles) do
        quiet_candles +
          [
            build(open: 10.3, high: 10.6, low: 10.0, close: 10.2),
            build(open: 10.2, high: 10.5, low: 10.1, close: 10.4)
          ]
      end

      it 'returns false' do
        expect(displacement.from_swing?(candles, swing, direction: :bullish, max_bars_after: 3)).to be(false)
      end
    end

    context 'when displacement occurs too many bars after the swing' do
      let(:candles) do
        quiet_candles +
          [
            build(open: 10.3, high: 10.5, low: 10.1, close: 10.2),
            build(open: 10.2, high: 10.5, low: 10.1, close: 10.3),
            build(open: 10.3, high: 10.6, low: 10.2, close: 10.4),
            build(open: 10.4, high: 12.5, low: 10.3, close: 12.0)
          ]
      end

      it 'returns false when outside max_bars_after' do
        expect(displacement.from_swing?(candles, swing, direction: :bullish, max_bars_after: 2)).to be(false)
      end
    end

    context 'when checking bearish displacement from a swing high' do
      let(:swing) do
        SMC::PivotDetector::Swing.new(
          :high,
          12.0,
          2,
          build(open: 11.8, high: 12.0, low: 11.5, close: 11.7)
        )
      end
      let(:candles) do
        quiet_candles +
          [
            build(open: 11.7, high: 12.0, low: 11.5, close: 11.6),
            build(open: 11.8, high: 11.8, low: 9.5, close: 9.9)
          ]
      end

      it 'returns true' do
        expect(displacement.from_swing?(candles, swing, direction: :bearish, max_bars_after: 3)).to be(true)
      end
    end
  end

  describe '#events_in_range' do
    let(:candles) do
      quiet_candles +
        [
          build(open: 10.5, high: 13.0, low: 10.5, close: 12.5),
          build(open: 12.5, high: 12.5, low: 10.0, close: 10.0),
          build(open: 10.0, high: 10.5, low: 9.8, close: 10.2)
        ]
    end

    it 'returns all displacement events in the inclusive range' do
      events = displacement.events_in_range(candles, from_index: 3, to_index: 5)

      expect(events.size).to eq(2)
      expect(events.map { |event| event[:direction] }).to eq([:bullish, :bearish])
      expect(events.map { |event| event[:index] }).to eq([3, 4])
    end

    context 'when range has no displacement' do
      it 'returns an empty array' do
        expect(displacement.events_in_range(candles, from_index: 5, to_index: 5)).to eq([])
      end
    end

    context 'when from_index is greater than to_index' do
      it 'returns an empty array' do
        expect(displacement.events_in_range(candles, from_index: 5, to_index: 3)).to eq([])
      end
    end
  end
end
