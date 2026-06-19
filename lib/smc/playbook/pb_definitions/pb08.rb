# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb08
        long_setup = Setup.new(
          direction: :long,
          description: 'Every filter stacked simultaneously. The rarest setup but offers 1:5–1:10 RR. The holy grail setup.',
          steps: [
            'HTF Bullish (Daily/Weekly trend)',
            'Ascending trendline — 3rd touch',
            '3rd touch aligns with support zone',
            'Sell-side liquidity swept (SSL hunt)',
            'Strong Low formed',
            'Bullish CHoCH',
            'Bullish BOS',
            'Bullish OB at Discount (OTE 62–79%)',
            'OB retest + LTF confirmation',
            'BUY — Maximum size'
          ],
          entry_rules: [
            EntryRule.new(id: :htf_trend, description: 'HTF trend confirmed bullish (Daily/Weekly)', required: true, weight: 3, tags: [:trend, :htf_bias]),
            EntryRule.new(id: :trendline_touch, description: 'Trendline 3rd touch reached', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :horizontal_sr, description: 'Horizontal S/R at the same level', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :liquidity_build, description: 'Liquidity built (2+ S/R tests, EQH/EQL)', required: true, weight: 2, tags: [:liquidity_build]),
            EntryRule.new(id: :ssl_sweep, description: 'Liquidity swept (SSL or BSL taken)', required: true, weight: 3, tags: [:ssl]),
            EntryRule.new(id: :strong_low, description: 'Strong High or Low from sweep', required: true, weight: 2, tags: [:strong_level]),
            EntryRule.new(id: :choch, description: 'CHoCH confirmed', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :bos, description: 'BOS confirmed — structural trend shift', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :ob_caused_bos, description: 'Order Block caused the BOS (no orphan OB)', required: true, weight: 2, tags: [:ob, :bos]),
            EntryRule.new(id: :ob_retest, description: 'Price retested the OB (50–100% mitigation)', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :discount, description: 'Entry is in Discount (long) or Premium (short)', required: true, weight: 2, tags: [:premium_discount]),
            EntryRule.new(id: :ltf_confirmation, description: 'LTF confirmation candle present at entry', required: true, weight: 1, tags: [:entry_confirmation]),
            EntryRule.new(id: :min_rr, description: 'Risk:Reward ≥ 1:5 measured before entry', required: true, weight: 3, tags: [:structure])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below SSL sweep low', anchor_type: :sweep_low, buffer_pct: 0.001),
            StopLossRule.new(description: 'Below Strong Low', anchor_type: :strong_low, buffer_pct: 0.001),
            StopLossRule.new(description: 'Below Bullish OB low', anchor_type: :ob_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: 'Internal liquidity / prev Internal HH', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'External liquidity / Major Swing HH', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'HTF target — Daily/Weekly Highs', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Every filter stacked for maximum confluence short entry.',
          steps: [
            'HTF Bearish (Daily/Weekly trend)',
            'Descending trendline — 3rd touch',
            '3rd touch aligns with resistance zone',
            'Buy-side liquidity swept (BSL hunt)',
            'Strong High formed',
            'Bearish CHoCH',
            'Bearish BOS',
            'Bearish OB at Premium (OTE 62–79%)',
            'OB retest + LTF confirmation',
            'SELL — Maximum size'
          ],
          entry_rules: [
            EntryRule.new(id: :htf_trend, description: 'HTF trend confirmed bearish (Daily/Weekly)', required: true, weight: 3, tags: [:trend, :htf_bias]),
            EntryRule.new(id: :trendline_touch, description: 'Trendline 3rd touch reached', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :horizontal_sr, description: 'Horizontal S/R at the same level', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :liquidity_build, description: 'Liquidity built (2+ S/R tests, EQH/EQL)', required: true, weight: 2, tags: [:liquidity_build]),
            EntryRule.new(id: :bsl_sweep, description: 'Liquidity swept (BSL taken)', required: true, weight: 3, tags: [:bsl]),
            EntryRule.new(id: :strong_high, description: 'Strong High from sweep', required: true, weight: 2, tags: [:strong_level]),
            EntryRule.new(id: :choch, description: 'Bearish CHoCH confirmed', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :bos, description: 'Bearish BOS confirmed', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :ob_caused_bos, description: 'Bearish OB caused the BOS', required: true, weight: 2, tags: [:ob, :bos]),
            EntryRule.new(id: :ob_retest, description: 'Price retested the Bearish OB', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :premium, description: 'Entry in Premium zone', required: true, weight: 2, tags: [:premium_discount]),
            EntryRule.new(id: :ltf_confirmation, description: 'LTF bearish confirmation at entry', required: true, weight: 1, tags: [:entry_confirmation]),
            EntryRule.new(id: :min_rr, description: 'Risk:Reward ≥ 1:5 measured before entry', required: true, weight: 3, tags: [:structure])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above BSL sweep high', anchor_type: :sweep_high, buffer_pct: 0.001),
            StopLossRule.new(description: 'Above Strong High', anchor_type: :strong_high, buffer_pct: 0.001),
            StopLossRule.new(description: 'Above Bearish OB high', anchor_type: :ob_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: 'Internal liquidity / prev Internal LL', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'External liquidity / Major Swing LL', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'HTF target — Daily/Weekly Lows', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-8',
          name: 'Full Confluence A+',
          short_name: 'Full A+',
          playbook_type: :base,
          complexity: :very_high,
          win_rate: :rare,
          rr_range: { min: 5.0, max: 10.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Any of the 12 required filters fails', invalidation_type: :price_close_below, applies_to: :both),
            InvalidationRule.new(description: 'Price closes below Strong Low (long)', invalidation_type: :below_strong_low, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above Strong High (short)', invalidation_type: :above_strong_high, applies_to: :short),
            InvalidationRule.new(description: 'OB tested more than twice', invalidation_type: :ob_tested_more_than_twice, applies_to: :both)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'All filters stacked', description: 'Every checklist item present', impact_on_rr: :clear_target, tags: %i[trend structure sweep choch bos ob premium_discount entry_confirmation])
          ],
          description: 'Every filter stacked simultaneously. This is the rarest setup but offers 1:5–1:10 RR. This is the setup you wait for, size up on, and execute with maximum discipline. All prior playbooks collapse into this one at peak conditions.'
        )
      end
    end
  end
end
