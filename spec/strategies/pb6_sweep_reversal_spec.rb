# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/pipeline_helper'
require_relative '../support/pb6_fixture'
require_relative '../support/pb7_fixture'

describe SMC::Strategy::SweepReversalStrategy do
  subject(:strategy) do
    described_class.new(
      lookback_candles: lookback_candles,
      min_risk_reward: min_risk_reward,
      require_entry_confirmation: require_entry_confirmation
    )
  end

  let(:lookback_candles) { 30 }
  let(:min_risk_reward) { 3.0 }
  let(:require_entry_confirmation) { false }

  describe '#evaluate' do
    context 'when the full PB6 long chain is present' do
      let(:candles) { PB6Fixture.long_candles }
      let(:entry_index) { PB6Fixture::LONG_ENTRY_INDEX }

      it 'produces a long signal after SSL sweep and bullish CHoCH' do
        signal = evaluate_pb6(candles, index: entry_index, strategy: strategy)

        expect(signal).not_to be_nil
        expect(signal[:type]).to eq(:long)
        expect(signal[:playbook]).to eq('PB6')
        expect(signal[:rules_checked]).to include(
          ssl_sweep: true,
          bullish_choch: true
        )
        expect(signal[:risk_reward]).to be >= min_risk_reward
        expect(signal[:sl]).to be < signal[:entry]
        expect(signal[:tp3]).to be > signal[:entry]
      end
    end

    context 'when the full PB6 short chain is present' do
      let(:candles) { PB6Fixture.short_candles }

      it 'produces a short signal after BSL sweep and bearish CHoCH' do
        signal = evaluate_pb6(
          candles,
          index: PB6Fixture::SHORT_ENTRY_INDEX,
          strategy: strategy
        )

        expect(signal).not_to be_nil
        expect(signal[:type]).to eq(:short)
        expect(signal[:playbook]).to eq('PB6')
        expect(signal[:rules_checked]).to include(
          bsl_sweep: true,
          bearish_choch: true
        )
      end
    end

    context 'when CHoCH is missing after the sweep' do
      let(:candles) { PB6Fixture.long_candles }
      let(:entry_index) { PB6Fixture::LONG_ENTRY_INDEX }

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

    context 'when a BOS occurs after the sweep' do
      let(:candles) { PB7Fixture.long_candles }
      let(:entry_index) { PB7Fixture::LONG_ENTRY_INDEX }

      it 'returns nil to keep PB6 distinct from PB7' do
        state = run_pipeline(candles, up_to_index: entry_index)
        expect(state[:market_structure].bos_events).not_to be_empty

        signal = evaluate_pb6(candles, index: entry_index, strategy: strategy)
        expect(signal).to be_nil
      end
    end

    context 'when entry confirmation is required but absent' do
      let(:require_entry_confirmation) { true }
      let(:candles) { PB6Fixture.long_candles }
      let(:entry_index) { PB6Fixture::LONG_ENTRY_INDEX }

      it 'returns nil' do
        candles[entry_index] = build(
          open: 113.0,
          high: 113.05,
          low: 112.95,
          close: 113.02,
          time: candles[entry_index].time
        )

        signal = evaluate_pb6(candles, index: entry_index, strategy: strategy)
        expect(signal).to be_nil
      end
    end
  end
end
