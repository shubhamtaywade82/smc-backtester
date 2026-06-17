# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/candle_builder'

describe SMC::ATR do
  subject(:atr) { described_class.new(period: period, smoothing: smoothing) }

  let(:period) { 3 }
  let(:smoothing) { :wilder }

  describe '#initialize' do
    context 'when period is zero' do
      it 'raises ArgumentError' do
        expect { described_class.new(period: 0) }.to raise_error(ArgumentError, /period/)
      end
    end

    context 'when period is negative' do
      it 'raises ArgumentError' do
        expect { described_class.new(period: -1) }.to raise_error(ArgumentError, /period/)
      end
    end

    context 'when smoothing is unsupported' do
      it 'raises ArgumentError' do
        expect { described_class.new(period: 3, smoothing: :ema) }.to raise_error(ArgumentError, /smoothing/)
      end
    end
  end

  describe '#true_range' do
    context 'when there is no previous close' do
      let(:candle) { build(open: 10, high: 12, low: 9, close: 11) }

      it 'uses high minus low' do
        expect(atr.true_range(candle, nil)).to eq(3.0)
      end
    end

    context 'when the bar range is the largest component' do
      let(:candle) { build(open: 50, high: 52, low: 48, close: 51) }
      let(:previous_close) { 50.0 }

      it 'returns high minus low' do
        expect(atr.true_range(candle, previous_close)).to eq(4.0)
      end
    end

    context 'when gap up dominates true range' do
      let(:candle) { build(open: 108, high: 110, low: 107, close: 109) }
      let(:previous_close) { 100.0 }

      it 'returns high minus previous close' do
        expect(atr.true_range(candle, previous_close)).to eq(10.0)
      end
    end

    context 'when gap down dominates true range' do
      let(:candle) { build(open: 92, high: 93, low: 88, close: 90) }
      let(:previous_close) { 100.0 }

      it 'returns previous close minus low' do
        expect(atr.true_range(candle, previous_close)).to eq(12.0)
      end
    end

    context 'when high equals low on a flat bar' do
      let(:candle) { build(open: 100, high: 100, low: 100, close: 100) }
      let(:previous_close) { 100.0 }

      it 'returns zero' do
        expect(atr.true_range(candle, previous_close)).to eq(0.0)
      end
    end
  end

  describe '#true_ranges' do
    context 'when candles is empty' do
      it 'returns an empty array' do
        expect(atr.true_ranges([])).to eq([])
      end
    end

    context 'when a single candle is provided' do
      let(:candles) { [build(open: 10, high: 13, low: 9, close: 12)] }

      it 'returns one true range based on high-low' do
        expect(atr.true_ranges(candles)).to eq([4.0])
      end
    end

    context 'when multiple candles include gaps' do
      let(:candles) do
        sequence([
          { open: 10, high: 12, low: 9, close: 11 },
          { open: 11, high: 14, low: 10, close: 13 },
          { open: 13, high: 15, low: 12, close: 14 }
        ])
      end

      it 'returns true range for every candle' do
        expect(atr.true_ranges(candles)).to eq([3.0, 4.0, 3.0])
      end
    end
  end

  describe '#sufficient_data?' do
    let(:candles) do
      sequence([
        { open: 10, high: 12, low: 9, close: 11 },
        { open: 11, high: 14, low: 10, close: 13 },
        { open: 13, high: 15, low: 11, close: 14 }
      ])
    end

    context 'when candle count is below period' do
      it 'returns false' do
        expect(atr.sufficient_data?(candles[0, 2])).to be(false)
      end
    end

    context 'when candle count equals period' do
      it 'returns true' do
        expect(atr.sufficient_data?(candles)).to be(true)
      end
    end

    context 'when candles is empty' do
      it 'returns false' do
        expect(atr.sufficient_data?([])).to be(false)
      end
    end
  end

  describe '#value_at' do
    context 'with Wilder smoothing' do
      let(:period) { 3 }
      let(:candles) do
        sequence([
          { open: 10, high: 12, low: 9, close: 11 },
          { open: 11, high: 14, low: 10, close: 13 },
          { open: 13, high: 15, low: 12, close: 14 },
          { open: 14, high: 16, low: 13, close: 15 }
        ])
      end

      it 'returns nil before the first completable index' do
        expect(atr.value_at(candles, 0)).to be_nil
        expect(atr.value_at(candles, 1)).to be_nil
      end

      it 'returns SMA of true ranges at the seed index' do
        expect(atr.value_at(candles, 2)).to be_within(0.0001).of(10.0 / 3.0)
      end

      it 'applies Wilder smoothing on subsequent indices' do
        seed = 10.0 / 3.0
        expected = ((seed * 2) + 3.0) / 3.0
        expect(atr.value_at(candles, 3)).to be_within(0.0001).of(expected)
      end
    end

    context 'with SMA smoothing' do
      let(:smoothing) { :sma }
      let(:period) { 2 }
      let(:candles) do
        sequence([
          { open: 10, high: 12, low: 9, close: 11 },
          { open: 11, high: 14, low: 10, close: 13 },
          { open: 13, high: 15, low: 11, close: 14 }
        ])
      end

      it 'returns nil before enough candles exist' do
        expect(atr.value_at(candles, 0)).to be_nil
      end

      it 'returns a rolling simple average of true ranges' do
        expect(atr.value_at(candles, 1)).to be_within(0.0001).of(3.5)
        expect(atr.value_at(candles, 2)).to be_within(0.0001).of(4.0)
      end
    end

    context 'when index is out of bounds' do
      let(:candles) { [build(open: 10, high: 12, low: 9, close: 11)] }

      it 'returns nil for negative index' do
        expect(atr.value_at(candles, -1)).to be_nil
      end

      it 'returns nil for index beyond last candle' do
        expect(atr.value_at(candles, 5)).to be_nil
      end
    end
  end

  describe '#series' do
    let(:period) { 2 }
    let(:smoothing) { :sma }
    let(:candles) do
      sequence([
        { open: 10, high: 12, low: 9, close: 11 },
        { open: 11, high: 14, low: 10, close: 13 },
        { open: 13, high: 15, low: 11, close: 14 }
      ])
    end

    it 'returns an array equal in length to candles' do
      expect(atr.series(candles).size).to eq(candles.size)
    end

    it 'prefixes nil until the first computable index' do
      expect(atr.series(candles)).to eq([nil, 3.5, 4.0])
    end
  end

  describe '#latest' do
    context 'when there is enough data' do
      let(:candles) do
        sequence([
          { open: 10, high: 12, low: 9, close: 11 },
          { open: 11, high: 13, low: 10, close: 12 },
          { open: 12, high: 14, low: 11, close: 13 }
        ])
      end

      it 'returns ATR at the last index' do
        expect(atr.latest(candles)).to eq(atr.value_at(candles, candles.size - 1))
      end
    end

    context 'when there is insufficient data' do
      let(:candles) { [build(open: 10, high: 12, low: 9, close: 11)] }

      it 'returns nil' do
        expect(atr.latest(candles)).to be_nil
      end
    end

    context 'when candles is empty' do
      it 'returns nil' do
        expect(atr.latest([])).to be_nil
      end
    end
  end

  describe '#within_tolerance?' do
    let(:period) { 2 }
    let(:candles) do
      sequence([
        { open: 10, high: 12, low: 9, close: 11 },
        { open: 11, high: 14, low: 10, close: 13 },
        { open: 13, high: 15, low: 11, close: 14 }
      ])
    end

    context 'when prices are within ATR-scaled tolerance' do
      it 'returns true' do
        reference_atr = atr.latest(candles)
        expect(atr.within_tolerance?(100.0, 100.0 + (reference_atr * 0.05), candles, multiplier: 0.1)).to be(true)
      end
    end

    context 'when prices exceed ATR-scaled tolerance' do
      it 'returns false' do
        reference_atr = atr.latest(candles)
        expect(atr.within_tolerance?(100.0, 100.0 + (reference_atr * 0.5), candles, multiplier: 0.1)).to be(false)
      end
    end

    context 'when ATR cannot be computed' do
      it 'returns false' do
        expect(atr.within_tolerance?(100.0, 100.1, [build(open: 10, high: 12, low: 9, close: 11)], multiplier: 0.1)).to be(false)
      end
    end

    context 'when multiplier is zero' do
      it 'requires exact price match' do
        expect(atr.within_tolerance?(100.0, 100.0, candles, multiplier: 0.0)).to be(true)
        expect(atr.within_tolerance?(100.0, 100.01, candles, multiplier: 0.0)).to be(false)
      end
    end
  end

  describe '#tolerance_band' do
    let(:candles) do
      sequence([
        { open: 10, high: 12, low: 9, close: 11 },
        { open: 11, high: 14, low: 10, close: 13 },
        { open: 13, high: 15, low: 11, close: 14 }
      ])
    end

    it 'returns ATR multiplied by the given factor' do
      expect(atr.tolerance_band(candles, multiplier: 0.2)).to be_within(0.0001).of(atr.latest(candles) * 0.2)
    end

    context 'when ATR is unavailable' do
      it 'returns nil' do
        expect(atr.tolerance_band([build(open: 10, high: 12, low: 9, close: 11)], multiplier: 0.2)).to be_nil
      end
    end
  end
end
