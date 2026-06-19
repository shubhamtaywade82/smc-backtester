# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb_f
        long_setup = Setup.new(
          direction: :long,
          description: 'Triple confluence: Breaker Block + FVG nested inside + HTF Order Block alignment. Appears ~2× per week.',
          steps: [
            'HTF OB identified (Daily or 4H)',
            'LTF OB fails → Breaker',
            'FVG inside Breaker',
            'Breaker in HTF OB zone',
            'Retrace to FVG inside Breaker',
            'UNICORN ENTRY'
          ],
          entry_rules: [
            EntryRule.new(id: :htf_ob, description: 'Valid HTF OB (untested) that caused a previous BOS', required: true, weight: 3, tags: [:ob, :htf_bias]),
            EntryRule.new(id: :htf_ob_zone, description: 'HTF OB in Discount (long) or Premium (short)', required: true, weight: 2, tags: [:premium_discount, :htf_bias]),
            EntryRule.new(id: :ltf_breaker, description: 'LTF OB fully broken with close, liquidity swept on break', required: true, weight: 3, tags: [:breaker]),
            EntryRule.new(id: :breaker_overlap, description: 'Breaker overlaps HTF OB zone', required: true, weight: 3, tags: [:breaker, :ob]),
            EntryRule.new(id: :fvg_inside, description: 'FVG inside or overlapping the Breaker', required: true, weight: 3, tags: [:fvg, :breaker]),
            EntryRule.new(id: :fvg_entry, description: 'Enter at FVG CE (50% midpoint)', required: false, weight: 1, tags: [:fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: "Beyond Breaker outer edge", anchor_type: :breaker_outer_edge, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Next liquidity / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'HTF OB target / external liquidity', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Triple confluence short variant: HTF OB + LTF Breaker + FVG inside.',
          steps: [
            'HTF bearish OB identified',
            'LTF bullish OB fails → Breaker',
            'FVG inside Breaker',
            'Breaker in HTF OB zone',
            'Retrace to FVG inside Breaker',
            'UNICORN ENTRY'
          ],
          entry_rules: [
            EntryRule.new(id: :htf_ob, description: 'Valid bearish HTF OB (untested) that caused BOS', required: true, weight: 3, tags: [:ob, :htf_bias]),
            EntryRule.new(id: :htf_ob_zone, description: 'HTF OB in Premium zone', required: true, weight: 2, tags: [:premium_discount, :htf_bias]),
            EntryRule.new(id: :ltf_breaker, description: 'LTF OB fully broken with close', required: true, weight: 3, tags: [:breaker]),
            EntryRule.new(id: :breaker_overlap, description: 'Breaker overlaps HTF OB zone', required: true, weight: 3, tags: [:breaker, :ob]),
            EntryRule.new(id: :fvg_inside, description: 'FVG inside or overlapping Breaker', required: true, weight: 3, tags: [:fvg, :breaker]),
            EntryRule.new(id: :fvg_entry, description: 'Enter at FVG CE (50% midpoint)', required: false, weight: 1, tags: [:fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: "Beyond Breaker outer edge", anchor_type: :breaker_outer_edge, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Next liquidity / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'HTF OB target / external liquidity', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-F',
          name: 'The Unicorn',
          short_name: 'Unicorn',
          playbook_type: :ict,
          complexity: :very_high,
          win_rate: :very_high,
          rr_range: { min: 5.0, max: 10.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes beyond Breaker outer edge', invalidation_type: :price_close_below, applies_to: :both),
            InvalidationRule.new(description: 'Any of the three layers invalidated independently', invalidation_type: :price_close_above, applies_to: :both)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'Triple confluence', description: 'HTF OB + LTF Breaker + FVG inside', impact_on_rr: :tighter_sl, tags: [:ob, :breaker, :fvg])
          ],
          description: 'Triple confluence: Breaker Block + FVG nested inside + HTF Order Block alignment. Appears approximately 2× per week. When it shows up: take it. The probability is extremely high. All three layers must align independently — do not force this setup.'
        )
      end
    end
  end
end
