# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/pipeline_helper'
require_relative '../support/pb3_fixture'

describe SMC::Strategy::BosPullbackStrategy do
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
    context 'when the full PB3 long chain is present' do
      let(:candles) { PB3Fixture.long_candles }
      let(:entry_index) { PB3Fixture::LONG_ENTRY_INDEX }

      it 'produces a long signal at the fixture entry index' do
        signal = evaluate_pb3(candles, index: entry_index, strategy: strategy)

        expect(signal).not_to be_nil
        expect(signal[:type]).to eq(:long)
        expect(signal[:playbook]).to eq('PB3')
        expect(signal[:rules_checked]).to include(
          bullish_bos: true,
          pullback: true,
          hl_formed: true,
          hl_touch: true,
          in_discount: true
        )
        expect(signal[:risk_reward]).to be >= min_risk_reward
        expect(signal[:sl]).to be < signal[:entry]
        expect(signal[:tp3]).to be > signal[:entry]
      end
    end

    context 'when the full PB3 short chain is present' do
      let(:candles) { PB3Fixture.short_candles }

      it 'produces a short signal at the fixture entry index' do
        signal = evaluate_pb3(
          candles,
          index: PB3Fixture::SHORT_ENTRY_INDEX,
          strategy: strategy
        )

        expect(signal).not_to be_nil
        expect(signal[:type]).to eq(:short)
        expect(signal[:playbook]).to eq('PB3')
        expect(signal[:rules_checked]).to include(
          bearish_bos: true,
          pullback: true,
          lh_formed: true,
          lh_touch: true,
          in_premium: true
        )
      end
    end

    context 'when no bullish BOS exists in lookback' do
      let(:candles) { PB3Fixture.long_candles }
      let(:entry_index) { PB3Fixture::LONG_ENTRY_INDEX }

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

    context 'when no HL forms after the BOS' do
      let(:candles) { PB3Fixture.long_candles }
      let(:entry_index) { PB3Fixture::LONG_ENTRY_INDEX }

      it 'returns nil' do
        state = run_pipeline(candles, up_to_index: entry_index)
        lows = state[:market_structure].swings.select { |swing| swing.type == :low }
        lows.each do |swing|
          state[:market_structure].classified_swings[swing.index] = :LL
        end

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
  end
end
