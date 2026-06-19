# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb_d
        long_setup = Setup.new(
          direction: :long,
          description: 'The ICT Power of 3 model. Markets cycle through three intraday phases: Asia Range → London Judas sweep → NY distribution.',
          steps: [
            'Asia Range: Tight consolidation. Mark Asia High and Asia Low.',
            'London Judas Swing: Sweeps one side of Asia range (stop hunt), then reverses.',
            'NY Expansion: True directional move. Enter on NY retrace into London FVG or OB.',
            'Target: opposite extreme of Asia range and beyond.'
          ],
          entry_rules: [
            EntryRule.new(id: :asia_range, description: 'Asia High and Asia Low marked', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :london_sweep, description: 'London sweeps one side of Asia range', required: true, weight: 3, tags: [:sweep]),
            EntryRule.new(id: :london_displacement, description: 'Sharp reversal with displacement after sweep', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :london_fvg, description: 'FVG created in London displacement', required: true, weight: 2, tags: [:fvg]),
            EntryRule.new(id: :ny_retrace, description: 'NY retrace into London FVG or OB', required: true, weight: 3, tags: [:ob, :fvg]),
            EntryRule.new(id: :bias_aligned, description: 'HTF bias aligned with direction', required: false, weight: 1, tags: [:htf_bias])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below London FVG / OB low', anchor_type: :ob_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: 'Asia High or Low (opposite side)', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Prior day high/low', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'HTF liquidity target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'AMD model short variant. Asia range → London Judas sweep up → NY distribution down.',
          steps: [
            'Asia Range marked',
            'London sweeps Asia High',
            'Sharp bearish reversal / displacement',
            'FVG created in displacement',
            'NY retrace into London FVG/OB',
            'SELL'
          ],
          entry_rules: [
            EntryRule.new(id: :asia_range, description: 'Asia High and Asia Low marked', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :london_sweep, description: 'London sweeps Asia High', required: true, weight: 3, tags: [:sweep]),
            EntryRule.new(id: :london_displacement, description: 'Sharp bearish reversal after sweep', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :london_fvg, description: 'FVG created in London displacement', required: true, weight: 2, tags: [:fvg]),
            EntryRule.new(id: :ny_retrace, description: 'NY retrace into London FVG or OB', required: true, weight: 3, tags: [:ob, :fvg]),
            EntryRule.new(id: :bias_aligned, description: 'HTF bias aligned with direction', required: false, weight: 1, tags: [:htf_bias])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above London FVG / OB high', anchor_type: :ob_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: 'Asia Low (opposite side)', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Prior day low', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'HTF liquidity target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-D',
          name: 'AMD Session Play',
          short_name: 'AMD Session',
          playbook_type: :ict,
          complexity: :high,
          win_rate: :high,
          rr_range: { min: 3.0, max: 6.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price re-enters Asia range and breaks opposing side', invalidation_type: :price_close_below, applies_to: :both)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'HTF bias', description: 'Weekly/daily bias aligns with session direction', impact_on_rr: :higher_win_rate, tags: [:htf_bias])
          ],
          description: 'The ICT Power of 3 model. Markets cycle through three intraday phases: Accumulation (Asia range), Manipulation (London Judas sweep), Distribution (NY expansion). The Judas Swing is the manipulation — a false move that sweeps liquidity before the true directional expansion.'
        )
      end
    end
  end
end
