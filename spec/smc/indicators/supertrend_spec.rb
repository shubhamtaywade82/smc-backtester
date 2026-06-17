# frozen_string_literal: true

require 'spec_helper'

describe SMC::Indicators::Supertrend do
  subject(:supertrend) { described_class.new(period: 3, multiplier: 2.0) }

  describe '#compute' do
    context 'when candles are fewer than the period' do
      it 'returns an empty array' do
        candles = CandleBuilder.sequence([
          { open: 10, high: 12, low: 9, close: 11 },
          { open: 11, high: 13, low: 10, close: 12 }
        ])

        expect(supertrend.compute(candles)).to eq([])
      end
    end

    context 'when candles are sufficient' do
      let(:candles) do
        CandleBuilder.sequence([
          { open: 10, high: 12, low: 9, close: 11 },
          { open: 11, high: 13, low: 10, close: 12 },
          { open: 12, high: 14, low: 11, close: 13 },
          { open: 13, high: 15, low: 12, close: 14 }
        ])
      end

      it 'returns a supertrend line for each candle after warmup' do
        results = supertrend.compute(candles)

        expect(results.size).to eq(4)
        expect(results[0]).to be_nil
        expect(results[1]).to be_nil
        expect(results[2]).not_to be_nil
        expect(results[3]).not_to be_nil
        expect(results[2][:trend]).to eq(:long)
        expect(results[2][:line]).to be_a(Float)
      end
    end
  end
end
