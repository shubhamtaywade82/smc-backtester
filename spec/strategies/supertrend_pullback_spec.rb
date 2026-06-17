# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/pipeline_helper'

module STPullbackFixture
  module_function

  def long_pullback_candles
    CandleBuilder.sequence([
      { open: 10, high: 12, low: 9, close: 11 },
      { open: 11, high: 12, low: 9.6, close: 10.5 },
      { open: 10.5, high: 13, low: 10.4, close: 12.5 },
      { open: 12.5, high: 14, low: 12, close: 13.5 },
      { open: 13.5, high: 15, low: 13, close: 14.5 },
      { open: 14.5, high: 16, low: 14, close: 15.5 },
      { open: 15.5, high: 17, low: 15, close: 16.5 },
      { open: 16.5, high: 18, low: 16, close: 17.5 },
      { open: 17.5, high: 19, low: 17, close: 18.5 },
      { open: 18.5, high: 20, low: 18, close: 19.5 },
      { open: 19.5, high: 21, low: 19, close: 20.5 },
      { open: 20.5, high: 22, low: 20, close: 21.5 }
    ])
  end

  def synthetic_uptrend_candles(count: 60)
    specs = count.times.map do |index|
      base = 100.0 + (index * 1.5)
      { open: base, high: base + 2.0, low: base - 1.0, close: base + 1.0 }
    end
    CandleBuilder.sequence(specs)
  end
end

describe SMC::Strategy::SupertrendPullbackStrategy do
  subject(:strategy) do
    described_class.new(
      period: period,
      multiplier: multiplier,
      htf_group_size: htf_group_size,
      proximity_threshold_pct: proximity_threshold_pct,
      enable_pullback: enable_pullback,
      enable_flip_entry: enable_flip_entry
    )
  end

  let(:period) { 5 }
  let(:multiplier) { 2.0 }
  let(:htf_group_size) { 4 }
  let(:proximity_threshold_pct) { 0.02 }
  let(:enable_pullback) { true }
  let(:enable_flip_entry) { false }

  describe '#pullback?' do
    it 'detects a long pullback when price hugs the supertrend line' do
      previous = CandleBuilder.build(open: 11, high: 12, low: 9.6, close: 10.5)
      current = CandleBuilder.build(open: 10.5, high: 13, low: 10.4, close: 12.5)
      indicator = { trend: :long, line: 9.5 }

      expect(strategy.pullback?(current, previous, indicator)).to be(true)
    end
  end

  describe '#evaluate' do
    context 'when HTF and LTF trends disagree' do
      let(:candles) { STPullbackFixture.long_pullback_candles }

      it 'returns nil' do
        signal = evaluate_st_pullback(candles, index: candles.size - 1, strategy: strategy)
        expect(signal).to be_nil
      end
    end

    context 'when a sustained uptrend is present' do
      let(:enable_flip_entry) { true }
      let(:candles) { STPullbackFixture.synthetic_uptrend_candles }

      it 'can produce a long signal during trend continuation' do
        signals = (20...(candles.size - 1)).map do |index|
          evaluate_st_pullback(candles, index: index, strategy: strategy)
        end.compact

        expect(signals).not_to be_empty
        expect(signals.first[:type]).to eq(:long)
        expect(signals.first[:playbook]).to eq('ST-Pullback')
        expect(signals.first[:risk_reward]).to be >= 3.0
      end
    end
  end
end
