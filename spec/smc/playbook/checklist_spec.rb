# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SMC::Playbook::Checklist do
  let(:long_setup) do
    SMC::Playbook::Setup.new(
      direction: :long,
      entry_rules: [
        SMC::Playbook::EntryRule.new(id: :trend, description: 'Trend bullish', required: true, weight: 3, tags: [:trend]),
        SMC::Playbook::EntryRule.new(id: :sweep, description: 'SSL sweep', required: true, weight: 3, tags: [:sweep]),
        SMC::Playbook::EntryRule.new(id: :choch, description: 'Bullish CHoCH', required: true, weight: 2, tags: [:choch]),
        SMC::Playbook::EntryRule.new(id: :ob, description: 'OB retest', required: false, weight: 2, tags: [:ob]),
        SMC::Playbook::EntryRule.new(id: :discount, description: 'In discount', required: false, weight: 1, tags: [:premium_discount])
      ]
    )
  end

  let(:playbook) { SMC::Playbook::Playbook.new(id: 'PB-CHK', name: 'Checklist Test', long_setup: long_setup) }
  subject { described_class.new(playbook) }

  describe '#evaluate' do
    context 'with bullish generated data at final candle' do
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

      let(:result) do
        subject.evaluate(:long, candles, candles.size - 1, pd, ms, ls, obd)
      end

      it 'returns a hash with required keys' do
        expect(result).to have_key(:score)
        expect(result).to have_key(:max_score)
        expect(result).to have_key(:passed)
        expect(result).to have_key(:failed)
        expect(result).to have_key(:setup_valid)
        expect(result).to have_key(:details)
        expect(result).to have_key(:direction)
        expect(result).to have_key(:playbook)
      end

      it 'has max_score equal to sum of rule weights' do
        expect(result[:max_score]).to eq(11) # 3+3+2+2+1
      end

      it 'passes the trend rule when bullish' do
        trend_detail = result[:details][:trend]
        expect(trend_detail[:pass]).to be true
        expect(trend_detail[:reason]).to match(/trend is BULLISH/)
      end

      it 'includes trend in passed list when bullish' do
        expect(result[:passed]).to include(:trend)
      end
    end

    context 'with no setup for direction' do
      let(:pb_no_short) do
        SMC::Playbook::Playbook.new(id: 'PB-NS', name: 'No Short', long_setup: long_setup, short_setup: nil)
      end
      let(:candles) { SMC::DataGenerator.generate_bullish_setup }

      it 'returns default invalid result for missing direction' do
        checklist = described_class.new(pb_no_short)
        result = checklist.evaluate(:short, candles, 50, nil, nil, nil, nil)

        expect(result[:setup_valid]).to be false
        expect(result[:score]).to eq(0)
        expect(result[:max_score]).to eq(0)
        expect(result[:passed]).to be_empty
        expect(result[:failed]).to be_empty
      end
    end

    context 'with empty rules' do
      let(:empty_setup) { SMC::Playbook::Setup.new(direction: :long, entry_rules: []) }
      let(:pb_empty) do
        SMC::Playbook::Playbook.new(id: 'PB-EMPTY', name: 'Empty', long_setup: empty_setup)
      end
      let(:candles) { SMC::DataGenerator.generate_bullish_setup }

      it 'returns valid with zero score when no rules exist' do
        checklist = described_class.new(pb_empty)
        result = checklist.evaluate(:long, candles, 50, nil, nil, nil, nil)

        expect(result[:setup_valid]).to be true
        expect(result[:score]).to eq(0)
        expect(result[:max_score]).to eq(0)
      end
    end
  end
end
