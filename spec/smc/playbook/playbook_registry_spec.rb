# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SMC::Playbook::PlaybookRegistry do
  before do
    described_class.reset_default!
    SMC::Playbook::PbDefinitions.register_all
  end

  subject { described_class.default }

  describe '.default' do
    it 'is a registry instance' do
      expect(described_class.default).to be_a(described_class)
    end
  end

  describe '#all' do
    it 'contains all 15 playbooks' do
      expect(subject.all.size).to eq(15)
    end

    it 'includes all expected IDs' do
      ids = %w[PB-1 PB-2 PB-3 PB-4 PB-5 PB-6 PB-7 PB-8 PB-C PB-D PB-E PB-F PB-G PB-H PB-MTF]
      expect(subject.ids).to match_array(ids)
    end
  end

  describe '#find' do
    it 'finds PB-7' do
      pb = subject.find('PB-7')
      expect(pb).to be_a(SMC::Playbook::Playbook)
      expect(pb.name).to eq('Liquidity Sweep + OB (Core A Setup)')
      expect(pb.complexity).to eq(:high)
      expect(pb.rr_range).to eq({ min: 4.0, max: 8.0 })
    end

    it 'returns nil for unknown ID' do
      expect(subject.find('PB-999')).to be_nil
    end
  end

  describe '#by_type' do
    it 'filters base playbooks' do
      base = subject.by_type(:base)
      expect(base.size).to eq(8)
      expect(base.map(&:id)).to match_array(%w[PB-1 PB-2 PB-3 PB-4 PB-5 PB-6 PB-7 PB-8])
    end

    it 'filters ICT playbooks' do
      ict = subject.by_type(:ict)
      expect(ict.size).to eq(7)
      expect(ict.map(&:id)).to match_array(%w[PB-C PB-D PB-E PB-F PB-G PB-H PB-MTF])
    end
  end

  describe '#by_complexity' do
    it 'filters by complexity' do
      low = subject.by_complexity(:low)
      expect(low.map(&:id)).to contain_exactly('PB-1', 'PB-2')

      very_high = subject.by_complexity(:very_high)
      expect(very_high.map(&:id)).to include('PB-8', 'PB-F', 'PB-MTF')
    end
  end

  describe '#by_direction' do
    it 'filters long setups' do
      long = subject.by_direction(:long)
      expect(long.size).to eq(15)
    end

    it 'filters short setups' do
      short = subject.by_direction(:short)
      expect(short.size).to eq(15)
    end
  end

  describe '#by_tag' do
    it 'finds playbooks with :ob tag' do
      ob_playbooks = subject.by_tag(:ob)
      expect(ob_playbooks.map(&:id)).to include('PB-5', 'PB-6', 'PB-7', 'PB-8')
    end

    it 'finds playbooks with :sweep tag' do
      sweep_playbooks = subject.by_tag(:sweep)
      expect(sweep_playbooks.map(&:id)).to include('PB-6', 'PB-D', 'PB-H')
    end

    it 'finds playbooks with :ssl tag' do
      ssl_playbooks = subject.by_tag(:ssl)
      expect(ssl_playbooks.map(&:id)).to include('PB-6', 'PB-7', 'PB-8', 'PB-MTF')
    end
  end

  describe '#size' do
    it 'returns 15' do
      expect(subject.size).to eq(15)
    end
  end
end
