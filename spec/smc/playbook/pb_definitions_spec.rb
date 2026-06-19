# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Playbook Definitions' do
  before do
    SMC::Playbook::PlaybookRegistry.reset_default!
    SMC::Playbook::PbDefinitions.register_all
  end

  let(:registry) { SMC::Playbook::PlaybookRegistry.default }

  %w[PB-1 PB-2 PB-3 PB-4 PB-5 PB-6 PB-7 PB-8 PB-C PB-D PB-E PB-F PB-G PB-H PB-MTF].each do |id|
    describe "#{id}" do
      subject { registry.find(id) }

      it 'exists in registry' do
        expect(subject).to be_a(SMC::Playbook::Playbook)
      end

      it 'has an id' do
        expect(subject.id).to eq(id)
      end

      it 'has a name' do
        expect(subject.name).to be_a(String)
        expect(subject.name).not_to be_empty
      end

      it 'has a playbook type' do
        expect(%i[base ict]).to include(subject.playbook_type)
      end

      it 'has a complexity' do
        expect(%i[low medium high very_high]).to include(subject.complexity)
      end

      it 'has a win rate' do
        expect(%i[low medium high very_high rare]).to include(subject.win_rate)
      end

      it 'has an rr_range' do
        expect(subject.rr_range).to have_key(:min)
        expect(subject.rr_range).to have_key(:max)
        expect(subject.rr_range[:max]).to be >= subject.rr_range[:min]
      end

      it 'supports long' do
        expect(subject.supports_long?).to be true
      end

      it 'supports short' do
        expect(subject.supports_short?).to be true
      end

      it 'has a long setup with entry rules' do
        expect(subject.long_setup).to be_a(SMC::Playbook::Setup)
        expect(subject.long_setup.entry_rules).not_to be_empty
      end

      it 'has a short setup with entry rules' do
        expect(subject.short_setup).to be_a(SMC::Playbook::Setup)
        expect(subject.short_setup.entry_rules).not_to be_empty
      end

      it 'has stop loss rules in long setup' do
        expect(subject.long_setup.stop_loss_rules).not_to be_empty
      end

      it 'has profit targets in long setup' do
        expect(subject.long_setup.profit_targets).not_to be_empty
        expect(subject.long_setup.profit_targets.map(&:level)).to include(:tp1, :tp2, :tp3)
      end

      it 'has invalidation rules' do
        expect(subject.invalidation_rules).not_to be_empty
      end

      it 'has a non-empty description' do
        expect(subject.description).to be_a(String)
        expect(subject.description).not_to be_empty
      end

      it 'returns a checklist' do
        expect(subject.checklist).to be_a(SMC::Playbook::Checklist)
      end
    end
  end

  describe 'PB-3' do
    subject { registry.find('PB-3') }

    it 'references BosPullbackStrategy' do
      expect(subject.strategy_class).to eq(SMC::Strategy::BosPullbackStrategy)
    end
  end

  describe 'PB-6' do
    subject { registry.find('PB-6') }

    it 'references SweepReversalStrategy' do
      expect(subject.strategy_class).to eq(SMC::Strategy::SweepReversalStrategy)
    end
  end

  describe 'PB-7' do
    subject { registry.find('PB-7') }

    it 'references SweepOB' do
      expect(subject.strategy_class).to eq(SMC::Strategy::SweepOB)
    end

    it 'has very high win rate' do
      expect(subject.win_rate).to eq(:very_high)
    end

    it 'has high complexity' do
      expect(subject.complexity).to eq(:high)
    end
  end

  describe 'PB-MTF' do
    subject { registry.find('PB-MTF') }

    it 'references MTFConfluence' do
      expect(subject.strategy_class).to eq(SMC::Strategy::MTFConfluence)
    end
  end
end
