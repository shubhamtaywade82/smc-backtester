# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SMC::Playbook::KnowledgeBase do
  before do
    SMC::Playbook::PlaybookRegistry.reset_default!
    SMC::Playbook::PbDefinitions.register_all
  end

  subject { described_class.new }

  describe '#playbook' do
    it 'finds PB-7' do
      pb = subject.playbook('PB-7')
      expect(pb).to be_a(SMC::Playbook::Playbook)
      expect(pb.id).to eq('PB-7')
    end

    it 'returns nil for unknown' do
      expect(subject.playbook('PB-999')).to be_nil
    end
  end

  describe '#playbooks' do
    it 'returns all 15' do
      expect(subject.playbooks.size).to eq(15)
    end
  end

  describe '#compatible_playbooks' do
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

    it 'returns an array of compatible results' do
      results = subject.compatible_playbooks(:long, candles, candles.size - 1, ms, ls, obd, min_score_ratio: 0.0)
      expect(results).to be_an(Array)
      results.each do |r|
        expect(r).to have_key(:playbook)
        expect(r).to have_key(:checklist)
        expect(r).to have_key(:score_ratio)
      end
    end

    it 'filters by min score ratio' do
      high_results = subject.compatible_playbooks(:long, candles, candles.size - 1, ms, ls, obd, min_score_ratio: 0.8)
      all_results = subject.compatible_playbooks(:long, candles, candles.size - 1, ms, ls, obd, min_score_ratio: 0.0)
      expect(high_results.size).to be <= all_results.size
    end

    it 'sorts by descending score ratio' do
      results = subject.compatible_playbooks(:long, candles, candles.size - 1, ms, ls, obd, min_score_ratio: 0.0)
      next if results.size < 2

      ratios = results.map { |r| r[:score_ratio] }
      expect(ratios).to eq(ratios.sort.reverse)
    end
  end
end
