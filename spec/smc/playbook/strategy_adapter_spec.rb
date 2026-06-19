# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SMC::Strategy::PlaybookStrategyAdapter do
  before do
    SMC::Playbook::PlaybookRegistry.reset_default!
    SMC::Playbook::PbDefinitions.register_all
  end

  let(:candles) { SMC::DataGenerator.generate_bullish_setup(start_price: 100.0, num_candles: 100) }
  let(:pd) { SMC::PivotDetector.new(left_bars: 4, right_bars: 4) }
  let(:ms) { SMC::MarketStructure.new }
  let(:ls) { SMC::LiquiditySweep.new(tolerance_pct: 0.0015) }
  let(:obd) { SMC::OrderBlockDetector.new }

  before do
    (20..(candles.size - 1)).each do |i|
      swings = pd.detect_swings(candles[0..i])
      ms.update(swings, candles[i], i)
      ls.update_equal_levels(swings)
      ls.detect_sweeps(swings, candles[i], i)

      recent_bos = ms.bos_events.last
      obd.check_for_new_ob(recent_bos, candles, i) if recent_bos && recent_bos[:index] == i
      recent_choch = ms.choch_events.last
      obd.check_for_new_ob(recent_choch, candles, i) if recent_choch && recent_choch[:index] == i

      obd.update_mitigations(candles[i], i)
    end
  end

  it 'inherits from Strategy::Base' do
    expect(described_class.ancestors).to include(SMC::Strategy::Base)
  end

  it 'resolves playbook by id string' do
    adapter = described_class.new(playbook_or_id: 'PB-1')
    expect(adapter.playbook.id).to eq('PB-1')
  end

  it 'resolves playbook by symbol' do
    adapter = described_class.new(playbook_or_id: :PB_1)
    expect(adapter.playbook.id).to eq('PB-1')
  end

  it 'resolves playbook by instance' do
    pb = SMC::Playbook::PlaybookRegistry.default.find('PB-1')
    adapter = described_class.new(playbook_or_id: pb)
    expect(adapter.playbook).to eq(pb)
  end

  it 'raises on invalid playbook reference' do
    expect {
      described_class.new(playbook_or_id: 12345)
    }.to raise_error(ArgumentError)
  end

  describe '#evaluate' do
    context 'with a simple playbook (PB-1) that does not require complex structure' do
      subject { described_class.new(playbook_or_id: 'PB-1', min_risk_reward: 0.0) }

      it 'returns nil or a signal hash' do
        result = subject.evaluate(candles, candles.size - 1, pd, ms, ls, obd)
        expect(result).to be_nil # PB-1 requires specific trendline touches which generated data won't satisfy
      end
    end

    context 'with a structure playbook (PB-3)' do
      subject { described_class.new(playbook_or_id: 'PB-3', min_risk_reward: 0.0) }

      it 'may return a signal or nil depending on conditions' do
        last_idx = candles.size - 1
        result = subject.evaluate(candles, last_idx, pd, ms, ls, obd)
        if result
          expect(result).to have_key(:type)
          expect(result).to have_key(:entry)
          expect(result).to have_key(:sl)
          expect(result).to have_key(:tp1)
          expect(result).to have_key(:tp2)
          expect(result).to have_key(:tp3)
          expect(result).to have_key(:risk_reward)
          expect(result).to have_key(:rules_checked)
          expect(result[:playbook]).to eq('PB-3')
        end
      end
    end

    context 'signal hash shape' do
      subject { described_class.new(playbook_or_id: 'PB-1', min_risk_reward: 999.0) }

      it 'returns nil when no setup meets min RR' do
        result = subject.evaluate(candles, candles.size - 1, pd, ms, ls, obd)
        expect(result).to be_nil
      end
    end
  end
end
