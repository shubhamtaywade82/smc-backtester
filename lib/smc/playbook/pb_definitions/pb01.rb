# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb01
        long_setup = Setup.new(
          direction: :long,
          description: 'The oldest price-action model. Bull: 3rd touch of ascending TL → bullish continuation. Entry on rejection candle.',
          steps: [
            'Uptrend confirmed (HL-HH sequence)',
            'Minimum 2 prior TL touches',
            '3rd touch + bullish rejection candle',
            'TL aligns with horizontal support (extra confluence)',
            'SL: below the 3rd touch candle low'
          ],
          entry_rules: [
            EntryRule.new(id: :trend, description: 'Uptrend confirmed (HL-HH sequence)', required: true, weight: 3, tags: [:trend]),
            EntryRule.new(id: :prior_touches, description: 'Minimum 2 prior TL touches confirmed', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :third_touch, description: '3rd touch arrives on trendline', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :rejection_candle, description: 'Bullish rejection candle at 3rd touch', required: true, weight: 3, tags: [:entry_confirmation]),
            EntryRule.new(id: :horizontal_support, description: 'TL aligns with horizontal support (extra confluence)', required: false, weight: 1, tags: [:confluence])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below the 3rd touch candle low', anchor_type: :below_3rd_touch, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target (risk amount replicated as reward)', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing high', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity pool (HTF level)', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Bear: 3rd touch of descending TL → sell. Entry on rejection candle.',
          steps: [
            'Downtrend confirmed (LH-LL sequence)',
            '2 prior TL touches',
            '3rd touch + bearish rejection candle',
            'TL aligns with horizontal resistance',
            'SL: above the 3rd touch candle high'
          ],
          entry_rules: [
            EntryRule.new(id: :trend, description: 'Downtrend confirmed (LH-LL sequence)', required: true, weight: 3, tags: [:trend]),
            EntryRule.new(id: :prior_touches, description: '2 prior TL touches confirmed', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :third_touch, description: '3rd touch arrives on trendline', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :rejection_candle, description: 'Bearish rejection candle at 3rd touch', required: true, weight: 3, tags: [:entry_confirmation]),
            EntryRule.new(id: :horizontal_resistance, description: 'TL aligns with horizontal resistance (extra confluence)', required: false, weight: 1, tags: [:confluence])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above the 3rd touch candle high', anchor_type: :above_3rd_touch, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing low', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity pool (HTF level)', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-1',
          name: 'Trendline 3rd Touch',
          short_name: 'TL 3rd Touch',
          playbook_type: :base,
          complexity: :low,
          win_rate: :medium,
          rr_range: { min: 2.0, max: 3.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes below the 3rd touch low (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above the 3rd touch high (short)', invalidation_type: :price_close_above, applies_to: :short)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'Horizontal S/R alignment', description: 'Trendline coincides with horizontal support/resistance', impact_on_rr: :tighter_sl, tags: [:confluence])
          ],
          description: 'The oldest price-action model. Markets respect trendlines because clusters of traders use them. The 3rd touch is the entry — not the 1st or 2nd. Origin: Classical price action, no ICT or SMC concepts required.'
        )
      end
    end
  end
end
