# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb07
        long_setup = Setup.new(
          direction: :long,
          description: 'The setup most profitable ICT/SMC traders actually execute. Sweep provides directional confirmation, BOS confirms structure, OB provides precision entry.',
          steps: [
            'Sell-side liquidity swept',
            'Strong bullish rejection',
            'Bullish CHoCH',
            'Bullish BOS confirmed',
            'Bullish OB identified (last bearish before BOS)',
            'Price retraces to OB',
            'LTF confirmation',
            'BUY'
          ],
          entry_rules: [
            EntryRule.new(id: :ssl_sweep, description: 'SSL swept with conviction', required: true, weight: 3, tags: [:ssl]),
            EntryRule.new(id: :bullish_choch, description: 'Bullish CHoCH after sweep', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :bullish_bos, description: 'Bullish BOS (structure fully shifted)', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :ob_identified, description: 'OB identified and retest occurs', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :ob_discount, description: 'OB in Discount zone (below 50%)', required: false, weight: 1, tags: [:premium_discount]),
            EntryRule.new(id: :fvg_inside, description: 'FVG inside OB = tighter stop', required: false, weight: 1, tags: [:fvg]),
            EntryRule.new(id: :ltf_confirmation, description: 'LTF confirmation at OB retest', required: false, weight: 1, tags: [:entry_confirmation]),
            EntryRule.new(id: :structure_sequence, description: 'Sweep → CHoCH → BOS sequence confirmed', required: true, weight: 2, tags: [:structure_sequence])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below sweep low or OB low (whichever is lowest)', anchor_type: :ob_low, buffer_pct: 0.001),
            StopLossRule.new(description: 'Below strong low', anchor_type: :strong_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target / Internal liquidity', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing high / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / Major Swing HH', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Buy-side liquidity swept, then full bearish structure shift with OB precision entry.',
          steps: [
            'Buy-side liquidity swept',
            'Strong bearish rejection',
            'Bearish CHoCH',
            'Bearish BOS confirmed',
            'Bearish OB identified (last bullish before BOS)',
            'Price retraces to OB',
            'LTF bearish confirmation',
            'SELL'
          ],
          entry_rules: [
            EntryRule.new(id: :bsl_sweep, description: 'BSL swept with conviction', required: true, weight: 3, tags: [:bsl]),
            EntryRule.new(id: :bearish_choch, description: 'Bearish CHoCH after sweep', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :bearish_bos, description: 'Bearish BOS confirmed', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :ob_identified, description: 'Bearish OB retest occurs', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :ob_premium, description: 'OB in Premium zone (above 50%)', required: false, weight: 1, tags: [:premium_discount]),
            EntryRule.new(id: :fvg_inside, description: 'FVG inside OB for tighter stop', required: false, weight: 1, tags: [:fvg]),
            EntryRule.new(id: :ltf_confirmation, description: 'LTF bearish confirmation at OB retest', required: false, weight: 1, tags: [:entry_confirmation]),
            EntryRule.new(id: :structure_sequence, description: 'Sweep → CHoCH → BOS sequence confirmed', required: true, weight: 2, tags: [:structure_sequence])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above sweep high or OB high (whichever is highest)', anchor_type: :ob_high, buffer_pct: 0.001),
            StopLossRule.new(description: 'Above strong high', anchor_type: :strong_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target / Internal liquidity', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing low / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / Major Swing LL', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-7',
          name: 'Liquidity Sweep + OB (Core A Setup)',
          short_name: 'Sweep + OB',
          playbook_type: :base,
          complexity: :high,
          win_rate: :very_high,
          rr_range: { min: 4.0, max: 8.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes below sweep low (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above sweep high (short)', invalidation_type: :price_close_above, applies_to: :short),
            InvalidationRule.new(description: 'Price closes below Bullish OB low (long)', invalidation_type: :below_strong_low, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above Bearish OB high (short)', invalidation_type: :above_strong_high, applies_to: :short),
            InvalidationRule.new(description: 'OB tested more than twice', invalidation_type: :ob_tested_more_than_twice, applies_to: :both)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'Sweep + CHoCH + BOS', description: 'All three structure filters stacked', impact_on_rr: :higher_win_rate, tags: [:sweep, :choch, :bos]),
            ConfluenceFilter.new(name: 'OB in Discount/Premium', description: 'OB in correct PD zone', impact_on_rr: :higher_win_rate, tags: [:premium_discount, :ob]),
            ConfluenceFilter.new(name: 'FVG inside OB', description: 'Nested FVG for tighter SL', impact_on_rr: :tighter_sl, tags: [:fvg, :ob])
          ],
          description: 'The setup most profitable ICT/SMC traders actually execute. The sweep provides directional confirmation, the BOS confirms structure, and the OB provides precision entry. Combining all three filters dramatically reduces false entries.',
          strategy_class: SMC::Strategy::SweepOB
        )
      end
    end
  end
end
