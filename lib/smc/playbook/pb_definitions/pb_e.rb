# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb_e
        long_setup = Setup.new(
          direction: :long,
          description: 'A time-specific scalp setup that uses a 1-hour kill window to enter displacement FVGs. Demands prior AMD directional bias.',
          steps: [
            'AMD bias established before window opens',
            'Enter Kill Window',
            'Displacement Candle within window',
            'FVG created',
            'Retrace into FVG',
            'ENTRY'
          ],
          entry_rules: [
            EntryRule.new(id: :amd_bias, description: 'AMD direction must be clear before window opens', required: true, weight: 3, tags: [:trend]),
            EntryRule.new(id: :kill_window, description: 'Displacement occurs within 60-min kill window', required: true, weight: 3, tags: [:session]),
            EntryRule.new(id: :fvg_created, description: 'FVG formed (gap between candle 1 and candle 3)', required: true, weight: 3, tags: [:fvg]),
            EntryRule.new(id: :retrace, description: 'Price retraces into FVG', required: true, weight: 2, tags: [:fvg]),
            EntryRule.new(id: :entry_zone, description: 'Enter at FVG consequent encroachment (50% midpoint)', required: false, weight: 1, tags: [:fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Beyond far edge of FVG', anchor_type: :fvg_far_edge, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Next liquidity pool', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'Opposite HTF level', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Time-specific scalp short within kill windows.',
          steps: [
            'AMD bearish bias established',
            'Enter Kill Window',
            'Bearish displacement within window',
            'FVG created',
            'Retrace into FVG',
            'SELL'
          ],
          entry_rules: [
            EntryRule.new(id: :amd_bias, description: 'AMD bearish bias before window', required: true, weight: 3, tags: [:trend]),
            EntryRule.new(id: :kill_window, description: 'Displacement within 60-min kill window', required: true, weight: 3, tags: [:session]),
            EntryRule.new(id: :fvg_created, description: 'Bearish FVG formed', required: true, weight: 3, tags: [:fvg]),
            EntryRule.new(id: :retrace, description: 'Price retraces into FVG', required: true, weight: 2, tags: [:fvg]),
            EntryRule.new(id: :entry_zone, description: 'Enter at FVG CE (50% midpoint)', required: false, weight: 1, tags: [:fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Beyond far edge of FVG', anchor_type: :fvg_far_edge, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Next liquidity pool', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'Opposite HTF level', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-E',
          name: 'Silver Bullet',
          short_name: 'Silver Bullet',
          playbook_type: :ict,
          complexity: :high,
          win_rate: :high,
          rr_range: { min: 3.0, max: 6.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Displacement outside kill window', invalidation_type: :time_expired, applies_to: :both),
            InvalidationRule.new(description: 'Price closes beyond FVG far edge', invalidation_type: :price_close_below, applies_to: :both)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'Kill Window timing', description: 'Institutional timing alignment', impact_on_rr: :higher_win_rate, tags: [:session])
          ],
          description: 'A time-specific scalp setup that uses a 1-hour kill window to enter displacement FVGs. The setup demands prior AMD directional bias. Outside the window = no trade. Kill windows: London Open 07:00–08:00 UTC, NY Open 14:00–15:00 UTC, NY Mid-Session 15:00–16:00 UTC.'
        )
      end
    end
  end
end
