# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb_c
        long_setup = Setup.new(
          direction: :long,
          description: 'Failed OB → Breaker. FVG nested inside. Dual institutional pressure at one zone.',
          steps: [
            'OB exists',
            'OB fails / broken with full candle close through it',
            'New HH or LL past structure',
            'Breaker formed',
            'FVG inside Breaker',
            'Retrace to FVG mid',
            'ENTRY'
          ],
          entry_rules: [
            EntryRule.new(id: :original_ob, description: 'Original OB confirmed, then fully broken', required: true, weight: 3, tags: [:ob, :breaker]),
            EntryRule.new(id: :liquidity_swept, description: 'Liquidity swept on the break (new HH or LL)', required: true, weight: 3, tags: [:sweep, :breaker]),
            EntryRule.new(id: :retrace_zone, description: 'Price must retrace BACK into the old OB zone', required: true, weight: 3, tags: [:breaker]),
            EntryRule.new(id: :ltf_choch, description: 'LTF CHoCH or FVG inside the zone for entry trigger', required: true, weight: 2, tags: [:choch, :fvg]),
            EntryRule.new(id: :fvg_entry, description: 'Enter at FVG consequent encroachment (50% of FVG)', required: false, weight: 1, tags: [:fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: "Beyond the Breaker's outer edge", anchor_type: :breaker_outer_edge, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Next draw on liquidity', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'Opposite liquidity pool', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Failed OB flips to Breaker with nested FVG. Dual institutional supply pressure.',
          steps: [
            'OB exists (bearish)',
            'OB fails / broken with full candle close',
            'New LL past structure',
            'Breaker formed',
            'FVG inside Breaker',
            'Retrace to FVG mid',
            'ENTRY'
          ],
          entry_rules: [
            EntryRule.new(id: :original_ob, description: 'Original bearish OB confirmed, then fully broken', required: true, weight: 3, tags: [:ob, :breaker]),
            EntryRule.new(id: :liquidity_swept, description: 'Liquidity swept on the break', required: true, weight: 3, tags: [:sweep, :breaker]),
            EntryRule.new(id: :retrace_zone, description: 'Price retraces back into old OB zone', required: true, weight: 3, tags: [:breaker]),
            EntryRule.new(id: :ltf_choch, description: 'LTF CHoCH or FVG inside zone for trigger', required: true, weight: 2, tags: [:choch, :fvg]),
            EntryRule.new(id: :fvg_entry, description: 'Enter at FVG CE (50% midpoint)', required: false, weight: 1, tags: [:fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: "Beyond the Breaker's outer edge", anchor_type: :breaker_outer_edge, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Next draw on liquidity', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'Opposite liquidity pool', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-C',
          name: 'FVG + Breaker Block',
          short_name: 'FVG Breaker',
          playbook_type: :ict,
          complexity: :high,
          win_rate: :high,
          rr_range: { min: 3.0, max: 6.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes beyond Breaker outer edge', invalidation_type: :price_close_below, applies_to: :both)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'Breaker + FVG', description: 'Dual institutional pressure', impact_on_rr: :tighter_sl, tags: [:breaker, :fvg])
          ],
          description: 'When a former Order Block is broken with a full candle close through it, it flips into a Breaker Block. If a Fair Value Gap is nested inside the Breaker, the zone becomes extremely high-confluence for re-entry in the new direction.'
        )
      end
    end
  end
end
