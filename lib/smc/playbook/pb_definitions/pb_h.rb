# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb_h
        long_setup = Setup.new(
          direction: :long,
          description: 'Internal range liquidity taken first, then expansion to external range liquidity target.',
          steps: [
            'Identify internal range (recent swings)',
            'Internal range liquidity taken (EQL or EQH swept)',
            'CHoCH confirms direction',
            'Price targets external range liquidity',
            'Enter on OB/FVG retrace toward external target'
          ],
          entry_rules: [
            EntryRule.new(id: :internal_range, description: 'Internal range identified (recent swings)', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :irl_taken, description: 'Internal range liquidity taken (EQL or EQH swept)', required: true, weight: 3, tags: [:sweep, :liquidity_build]),
            EntryRule.new(id: :choch, description: 'CHoCH confirms direction after IRL sweep', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :erl_target, description: 'External range liquidity target identified', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :entry_zone, description: 'Enter on OB/FVG retrace toward external target', required: false, weight: 1, tags: [:ob, :fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below internal sweep low or OB low', anchor_type: :ob_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: 'Internal range opposite side', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'External range liquidity / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'Beyond external range / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Internal range liquidity taken, then expansion to external range. Short variant.',
          steps: [
            'Identify internal range',
            'Internal range liquidity taken (EQH or EQL swept)',
            'Bearish CHoCH confirms direction',
            'External range target identified',
            'Enter on OB/FVG retrace'
          ],
          entry_rules: [
            EntryRule.new(id: :internal_range, description: 'Internal range identified', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :irl_taken, description: 'Internal range liquidity taken', required: true, weight: 3, tags: [:sweep, :liquidity_build]),
            EntryRule.new(id: :choch, description: 'Bearish CHoCH confirms direction', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :erl_target, description: 'External range liquidity target identified', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :entry_zone, description: 'Enter on OB/FVG retrace toward external target', required: false, weight: 1, tags: [:ob, :fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above internal sweep high or OB high', anchor_type: :ob_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: 'Internal range opposite side', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'External range liquidity / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'Beyond external range / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-H',
          name: 'IRL → ERL',
          short_name: 'IRL→ERL',
          playbook_type: :ict,
          complexity: :medium,
          win_rate: :medium,
          rr_range: { min: 2.0, max: 4.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price reclaims internal range liquidity (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Price reclaims internal range liquidity (short)', invalidation_type: :price_close_above, applies_to: :short)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'CHoCH after IRL sweep', description: 'Structure confirms direction after internal liquidity taken', impact_on_rr: :higher_win_rate, tags: [:choch, :sweep])
          ],
          description: 'Internal range liquidity taken first, then expansion to external range liquidity target. The key is waiting for the internal sweep to complete before entering in the direction of the external draw.'
        )
      end
    end
  end
end
