# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb06
        long_setup = Setup.new(
          direction: :long,
          description: 'The most popular SMC model. Stops are hunted, then price aggressively reverses. No OB required — the CHoCH after the sweep is the entry trigger.',
          steps: [
            'Support or swing low forms',
            'Stop-loss cluster builds below',
            'Price sweeps below — SSL taken',
            'Aggressive reclaim above the low',
            'Bullish CHoCH — LH broken',
            'BUY at CHoCH close or retrace'
          ],
          entry_rules: [
            EntryRule.new(id: :swing_low, description: 'Clear swing low with stops clustered below', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :ssl_sweep, description: 'SSL swept (wick or full candle below)', required: true, weight: 3, tags: [:ssl]),
            EntryRule.new(id: :reclaim, description: 'Price aggressively reclaims the level', required: true, weight: 3, tags: [:sweep]),
            EntryRule.new(id: :bullish_choch, description: 'Bullish CHoCH confirmed', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :entry_timing, description: 'Enter on CHoCH candle close or wait for OB retest', required: false, weight: 1, tags: [:ob])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below the sweep low', anchor_type: :sweep_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing high / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Buy-side liquidity swept, then price aggressively reverses. Works at swing highs.',
          steps: [
            'Resistance or swing high forms',
            'Buy-stop cluster builds above',
            'Price sweeps above — BSL taken',
            'Aggressive rejection back below',
            'Bearish CHoCH — HL broken',
            'SELL at CHoCH close or OB retest'
          ],
          entry_rules: [
            EntryRule.new(id: :swing_high, description: 'Clear swing high with buy-stops above', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :bsl_sweep, description: 'BSL swept (wick or candle above level)', required: true, weight: 3, tags: [:bsl]),
            EntryRule.new(id: :rejection, description: 'Aggressive rejection back below', required: true, weight: 3, tags: [:sweep]),
            EntryRule.new(id: :bearish_choch, description: 'Bearish CHoCH confirmed', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :entry_timing, description: 'Enter on CHoCH close or OB retest', required: false, weight: 1, tags: [:ob])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above the sweep high', anchor_type: :sweep_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing low / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-6',
          name: 'Liquidity Sweep Reversal',
          short_name: 'Sweep Reversal',
          playbook_type: :base,
          complexity: :medium,
          win_rate: :high,
          rr_range: { min: 3.0, max: 6.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes below sweep low (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above sweep high (short)', invalidation_type: :price_close_above, applies_to: :short),
            InvalidationRule.new(description: 'SSL sweep immediately followed by new LL (no CHoCH)', invalidation_type: :new_ll, applies_to: :long),
            InvalidationRule.new(description: 'BSL sweep immediately followed by new HH (no CHoCH)', invalidation_type: :new_hh, applies_to: :short)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'OB retest after sweep', description: 'Wait for OB retest after CHoCH for tighter stop', impact_on_rr: :tighter_sl, tags: [:ob])
          ],
          description: 'The most popular SMC model. Stops are hunted, then price aggressively reverses. No OB required — the CHoCH after the sweep is the entry trigger. Works at swing lows (longs) and swing highs (shorts). Pairs naturally with PB-5 when an OB is also present.',
          strategy_class: SMC::Strategy::SweepReversalStrategy
        )
      end
    end
  end
end
