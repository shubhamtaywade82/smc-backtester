# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SMC::Playbook::Playbook do
  let(:long_setup) do
    SMC::Playbook::Setup.new(
      direction: :long,
      description: 'Long setup test',
      steps: ['Step 1', 'Step 2'],
      entry_rules: [
        SMC::Playbook::EntryRule.new(id: :trend, description: 'Trend up', required: true, weight: 3, tags: [:trend])
      ],
      stop_loss_rules: [
        SMC::Playbook::StopLossRule.new(description: 'Below OB low', anchor_type: :ob_low, buffer_pct: 0.001)
      ],
      profit_targets: [
        SMC::Playbook::ProfitTarget.new(level: :tp1, description: '1R', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0)
      ]
    )
  end

  let(:short_setup) do
    SMC::Playbook::Setup.new(
      direction: :short,
      description: 'Short setup test',
      steps: ['Step A'],
      entry_rules: [
        SMC::Playbook::EntryRule.new(id: :trend, description: 'Trend down', required: true, weight: 3, tags: [:trend])
      ],
      stop_loss_rules: [
        SMC::Playbook::StopLossRule.new(description: 'Above OB high', anchor_type: :ob_high, buffer_pct: 0.001)
      ],
      profit_targets: [
        SMC::Playbook::ProfitTarget.new(level: :tp1, description: '1R', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0)
      ]
    )
  end

  subject do
    described_class.new(
      id: 'PB-TEST',
      name: 'Test Playbook',
      short_name: 'Test',
      playbook_type: :base,
      directions: %i[long short],
      complexity: :medium,
      win_rate: :high,
      rr_range: { min: 2.0, max: 4.0 },
      long_setup: long_setup,
      short_setup: short_setup,
      invalidation_rules: [
        SMC::Playbook::InvalidationRule.new(description: 'Close below strong low', invalidation_type: :price_close_below, applies_to: :long)
      ],
      confluence_filters: [
        SMC::Playbook::ConfluenceFilter.new(name: 'OB + FVG', description: 'Overlap', impact_on_rr: :tighter_sl, tags: [:ob, :fvg])
      ],
      description: 'A test playbook'
    )
  end

  it 'exposes metadata attributes' do
    expect(subject.id).to eq('PB-TEST')
    expect(subject.name).to eq('Test Playbook')
    expect(subject.short_name).to eq('Test')
    expect(subject.playbook_type).to eq(:base)
    expect(subject.complexity).to eq(:medium)
    expect(subject.win_rate).to eq(:high)
    expect(subject.rr_range).to eq({ min: 2.0, max: 4.0 })
  end

  it 'classifies type predicates' do
    expect(subject.base?).to be true
    expect(subject.ict?).to be false
  end

  it 'classifies direction support' do
    expect(subject.supports_long?).to be true
    expect(subject.supports_short?).to be true
  end

  it 'returns the correct setup for a direction' do
    expect(subject.setup_for(:long)).to eq(long_setup)
    expect(subject.setup_for(:short)).to eq(short_setup)
    expect(subject.setup_for(:unknown)).to be_nil
  end

  it 'collects tags from entry rules' do
    expect(subject.tags).to eq([:trend])
  end

  it 'provides a checklist instance' do
    expect(subject.checklist).to be_a(SMC::Playbook::Checklist)
    expect(subject.checklist.playbook).to eq(subject)
  end

  it 'serializes to a hash' do
    h = subject.to_h
    expect(h[:id]).to eq('PB-TEST')
    expect(h[:name]).to eq('Test Playbook')
    expect(h[:long_setup]).to be_a(Hash)
    expect(h[:short_setup]).to be_a(Hash)
  end
end

RSpec.describe SMC::Playbook::Setup do
  subject do
    described_class.new(
      direction: :long,
      description: 'Test setup',
      steps: ['Step 1'],
      entry_rules: [
        SMC::Playbook::EntryRule.new(id: :r1, description: 'Rule 1', required: true, weight: 2, tags: [:trend]),
        SMC::Playbook::EntryRule.new(id: :r2, description: 'Rule 2', required: false, weight: 1, tags: [:sweep])
      ]
    )
  end

  it 'identifies direction' do
    expect(subject.long?).to be true
    expect(subject.short?).to be false
  end

  it 'partitions required and optional rules' do
    expect(subject.required_entry_rules.map(&:id)).to eq([:r1])
    expect(subject.optional_entry_rules.map(&:id)).to eq([:r2])
  end

  it 'computes max score' do
    expect(subject.max_score).to eq(3)
  end
end

RSpec.describe SMC::Playbook::EntryRule do
  subject do
    described_class.new(
      id: :test_rule,
      description: 'Test description',
      required: true,
      weight: 2,
      tags: [:trend, :structure]
    )
  end

  it 'stores attributes' do
    expect(subject.id).to eq(:test_rule)
    expect(subject.description).to eq('Test description')
    expect(subject.required?).to be true
    expect(subject.weight).to eq(2)
    expect(subject.tags).to eq(%i[trend structure])
  end

  it 'serializes to hash' do
    expect(subject.to_h[:id]).to eq(:test_rule)
  end
end

RSpec.describe SMC::Playbook::StopLossRule do
  subject do
    described_class.new(description: 'Below OB low', anchor_type: :ob_low, buffer_pct: 0.001)
  end

  it 'stores attributes' do
    expect(subject.anchor_type).to eq(:ob_low)
    expect(subject.buffer_pct).to eq(0.001)
  end
end

RSpec.describe SMC::Playbook::ProfitTarget do
  subject do
    described_class.new(level: :tp1, description: '1R', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0)
  end

  it 'stores attributes' do
    expect(subject.level).to eq(:tp1)
    expect(subject.position_pct).to eq(30)
    expect(subject.action).to eq(:move_to_breakeven)
    expect(subject.risk_multiple).to eq(1.0)
  end
end

RSpec.describe SMC::Playbook::InvalidationRule do
  subject do
    described_class.new(description: 'Close below OB', invalidation_type: :price_close_below, applies_to: :long)
  end

  it 'stores attributes' do
    expect(subject.invalidation_type).to eq(:price_close_below)
    expect(subject.applies_to_long?).to be true
    expect(subject.applies_to_short?).to be false
  end
end

RSpec.describe SMC::Playbook::ConfluenceFilter do
  subject do
    described_class.new(name: 'OB+FVG', description: 'Overlap', impact_on_rr: :tighter_sl, tags: [:ob, :fvg])
  end

  it 'stores attributes' do
    expect(subject.name).to eq('OB+FVG')
    expect(subject.impact_on_rr).to eq(:tighter_sl)
    expect(subject.tags).to eq(%i[ob fvg])
  end
end
