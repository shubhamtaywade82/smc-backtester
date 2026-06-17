# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/candle_builder'
require_relative '../support/pipeline_helper'
require_relative '../support/pb7_fixture'

describe SMC::Strategy::SweepOB do
  subject(:strategy) do
    described_class.new(
      lookback_candles: lookback_candles,
      min_risk_reward: min_risk_reward,
      require_strong_level: require_strong_level,
      require_entry_confirmation: require_entry_confirmation
    )
  end

  let(:lookback_candles) { 30 }
  let(:min_risk_reward) { 3.0 }
  let(:require_strong_level) { true }
  let(:require_entry_confirmation) { true }

  def entry_index_for(candles)
    (30..(candles.size - 1)).find do |index|
      signal = evaluate_pb7(
        candles,
        index: index,
        strategy: described_class.new(
          lookback_candles: lookback_candles,
          min_risk_reward: min_risk_reward,
          require_strong_level: require_strong_level,
          require_entry_confirmation: false
        )
      )
      !signal.nil?
    end
  end

  describe '#evaluate' do
    context 'when the full PB7 long chain is present' do
      let(:candles) { PB7Fixture.long_candles }
      let(:entry_index) { PB7Fixture::LONG_ENTRY_INDEX }

      it 'finds an entry window in the generated fixture' do
        expect(entry_index_for(candles)).to eq(entry_index)
      end

      it 'returns a long signal with PB7 metadata when entry confirmation is present' do
        candles[entry_index] = build(
          open: 104.0,
          high: 104.2,
          low: 102.5,
          close: 104.1,
          time: candles[entry_index].time
        )

        signal = evaluate_pb7(candles, index: entry_index, strategy: strategy)

        expect(signal).not_to be_nil
        expect(signal[:type]).to eq(:long)
        expect(signal[:playbook]).to eq('PB7')
        expect(signal[:rules_checked]).to include(
          ssl_sweep: true,
          bullish_choch: true,
          bullish_bos: true,
          ob_retest: true,
          in_discount: true,
          entry_confirmation: true
        )
        expect(signal[:risk_reward]).to be >= min_risk_reward
        expect(signal[:sl]).to be < signal[:entry]
        expect(signal[:tp3]).to be > signal[:entry]
      end
    end

    context 'when entry confirmation is required but absent' do
      let(:candles) { PB7Fixture.long_candles }
      let(:entry_index) { PB7Fixture::LONG_ENTRY_INDEX }

      it 'returns nil' do
        candles[entry_index] = build(
          open: 104.0,
          high: 104.05,
          low: 103.98,
          close: 104.02,
          time: candles[entry_index].time
        )

        signal = evaluate_pb7(candles, index: entry_index, strategy: strategy)
        expect(signal).to be_nil
      end
    end

    context 'when CHoCH is missing after the sweep' do
      let(:candles) { PB7Fixture.long_candles }
      let(:entry_index) { PB7Fixture::LONG_ENTRY_INDEX }

      it 'returns nil' do
        state = run_pipeline(candles, up_to_index: entry_index)
        state[:market_structure].instance_variable_set(:@choch_events, [])

        signal = strategy.evaluate(
          candles,
          entry_index,
          state[:pivot_detector],
          state[:market_structure],
          state[:liquidity_sweep],
          state[:ob_detector]
        )

        expect(signal).to be_nil
      end
    end

    context 'when BOS is missing after CHoCH' do
      let(:candles) { PB7Fixture.long_candles }
      let(:entry_index) { PB7Fixture::LONG_ENTRY_INDEX }

      it 'returns nil' do
        state = run_pipeline(candles, up_to_index: entry_index)
        state[:market_structure].instance_variable_set(:@bos_events, [])

        signal = strategy.evaluate(
          candles,
          entry_index,
          state[:pivot_detector],
          state[:market_structure],
          state[:liquidity_sweep],
          state[:ob_detector]
        )

        expect(signal).to be_nil
      end
    end

    context 'when BOS occurs before CHoCH' do
      let(:sweep) { { type: :ssl_sweep, index: 10, price: 9.0 } }
      let(:choch_events) { [{ direction: :bullish, index: 15, price: 11.0 }] }
      let(:bos_events) { [{ direction: :bullish, index: 12, price: 11.5 }] }

      it 'is rejected by the PB7 sequence rule' do
        expect(
          strategy.send(
            :pb7_structure_sequence?,
            sweep,
            choch_events,
            bos_events,
            direction: :bullish
          )
        ).to be(false)
      end
    end

    context 'when price is outside the discount zone' do
      let(:candles) { PB7Fixture.long_candles }
      let(:entry_index) { PB7Fixture::LONG_ENTRY_INDEX }
      let(:require_entry_confirmation) { false }

      it 'returns nil' do
        candles[entry_index] = build(
          open: 104.0,
          high: 115.0,
          low: 103.5,
          close: 114.0,
          time: candles[entry_index].time
        )

        signal = evaluate_pb7(candles, index: entry_index, strategy: strategy)
        expect(signal).to be_nil
      end
    end

    context 'when risk-reward is below the minimum threshold' do
      let(:min_risk_reward) { 10.0 }
      let(:require_entry_confirmation) { false }
      let(:candles) { PB7Fixture.long_candles }
      let(:entry_index) { PB7Fixture::LONG_ENTRY_INDEX }

      it 'returns nil' do
        signal = evaluate_pb7(candles, index: entry_index, strategy: strategy)
        expect(signal).to be_nil
      end
    end

    context 'when the full PB7 short chain is present' do
      let(:candles) { PB7Fixture.short_candles }
      let(:require_entry_confirmation) { false }

      it 'can produce a short signal in the bearish fixture' do
        signal = evaluate_pb7(
          candles,
          index: PB7Fixture::SHORT_ENTRY_INDEX,
          strategy: strategy
        )

        expect(signal).not_to be_nil
        expect(signal[:type]).to eq(:short)
        expect(signal[:playbook]).to eq('PB7')
        expect(signal[:rules_checked]).to include(
          bsl_sweep: true,
          bearish_choch: true,
          bearish_bos: true,
          ob_retest: true,
          in_premium: true
        )
      end
    end
  end

  describe 'entry confirmation helpers' do
    it 'accepts bullish engulfing candles' do
      prior = build(open: 10.5, high: 10.8, low: 10.2, close: 10.3)
      current = build(open: 10.2, high: 11.0, low: 10.1, close: 10.9)

      expect(strategy.send(:entry_confirmed?, [prior, current], 1, direction: :long)).to be(true)
    end

    it 'accepts bullish rejection wick candles' do
      current = build(open: 10.4, high: 10.6, low: 9.5, close: 10.45)

      expect(strategy.send(:entry_confirmed?, [current], 0, direction: :long)).to be(true)
    end

    it 'accepts bearish engulfing candles' do
      prior = build(open: 10.2, high: 10.8, low: 10.1, close: 10.7)
      current = build(open: 10.8, high: 10.9, low: 9.8, close: 9.9)

      expect(strategy.send(:entry_confirmed?, [prior, current], 1, direction: :short)).to be(true)
    end
  end
end
