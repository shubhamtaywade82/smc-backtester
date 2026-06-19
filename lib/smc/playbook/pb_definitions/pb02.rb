# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb02
        long_setup = Setup.new(
          direction: :long,
          description: 'Broken resistance becomes support on retest. BOS through level → wait for retest → enter continuation.',
          steps: [
            'Resistance level tested multiple times',
            'Bullish BOS — close above resistance',
            'Price runs above',
            'Retest of former resistance (now support)',
            'Bullish rejection from new support',
            'BUY'
          ],
          entry_rules: [
            EntryRule.new(id: :resistance_tested, description: 'Resistance tested 2+ times before break', required: true, weight: 3, tags: [:structure, :liquidity_build]),
            EntryRule.new(id: :bullish_bos, description: 'Clean BOS (close above resistance, not just wick)', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :retest_hold, description: 'Retest holds as support', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :rejection, description: 'Bullish rejection from new support', required: true, weight: 2, tags: [:entry_confirmation]),
            EntryRule.new(id: :ob_or_fvg, description: 'FVG or OB at the retest zone (extra confluence)', required: false, weight: 1, tags: [:ob, :fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below the flip zone', anchor_type: :flip_zone, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing high / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Broken support becomes resistance on retest. BOS below support → wait for retest → enter continuation.',
          steps: [
            'Support level tested multiple times',
            'Bearish BOS — close below support',
            'Price drops',
            'Retest of former support (now resistance)',
            'Bearish rejection from new resistance',
            'SELL'
          ],
          entry_rules: [
            EntryRule.new(id: :support_tested, description: 'Support tested 2+ times before break', required: true, weight: 3, tags: [:structure, :liquidity_build]),
            EntryRule.new(id: :bearish_bos, description: 'Clean close below support (not just wick)', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :retest_hold, description: 'Retest holds as resistance', required: true, weight: 3, tags: [:structure]),
            EntryRule.new(id: :rejection, description: 'Bearish rejection from new resistance', required: true, weight: 2, tags: [:entry_confirmation]),
            EntryRule.new(id: :ob_or_fvg, description: 'OB or FVG at the flip zone', required: false, weight: 1, tags: [:ob, :fvg])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above the flip zone', anchor_type: :flip_zone, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing low / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-2',
          name: 'Support → Resistance Flip',
          short_name: 'S/R Flip',
          playbook_type: :base,
          complexity: :low,
          win_rate: :medium,
          rr_range: { min: 2.0, max: 4.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes back below flip zone (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Price closes back above flip zone (short)', invalidation_type: :price_close_above, applies_to: :short)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'OB at flip zone', description: 'Use an Order Block at the flip zone instead of raw price level', impact_on_rr: :tighter_sl, tags: [:ob])
          ],
          description: 'When a resistance level is broken with conviction, it becomes support on the retest (and vice versa). This is the structural memory of institutional order flow at that price. Common in equities, indices, and trending crypto.'
        )
      end
    end
  end
end
