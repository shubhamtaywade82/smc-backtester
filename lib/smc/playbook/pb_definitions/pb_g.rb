# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb_g
        long_setup = Setup.new(
          direction: :long,
          description: 'OB or FVG at 62–79% retrace. 70.5% sweet spot. Tighter SL, higher win rate.',
          steps: [
            'Draw Fib from Swing Low (100%) to Swing High (0%) after confirmed Bullish BOS',
            '62%–79% = OTE zone (Optimal Trade Entry)',
            '70.5% = ICT sweet spot if OB/FVG aligns',
            'OB or FVG must exist within OTE zone',
            'Entry: limit at 70.5% or OB midpoint',
            'SL: below Swing Low or OB low'
          ],
          entry_rules: [
            EntryRule.new(id: :bos, description: 'Confirmed Bullish BOS', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :fib_drawn, description: 'Fib drawn from swing low to swing high', required: true, weight: 2, tags: [:fib]),
            EntryRule.new(id: :ote_zone, description: 'Price in 62%–79% OTE zone', required: true, weight: 3, tags: [:ote]),
            EntryRule.new(id: :sweet_spot, description: '70.5% sweet spot if OB/FVG aligns', required: false, weight: 1, tags: [:ote, :ob, :fvg]),
            EntryRule.new(id: :ob_or_fvg_present, description: 'OB or FVG exists within OTE zone', required: true, weight: 3, tags: [:ob, :fvg]),
            EntryRule.new(id: :discount, description: 'Entry in Discount zone', required: false, weight: 1, tags: [:premium_discount])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below Swing Low or OB low', anchor_type: :swing_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing high / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'OTE Fibonacci short entry. 62–79% retrace zone.',
          steps: [
            'Draw Fib from Swing High (100%) to Swing Low (0%) after Bearish BOS',
            '62%–79% retrace = OTE zone for short',
            '70.5% sweet spot if Bearish OB/FVG aligns',
            'OB or FVG in OTE = highest confluence short',
            'Entry: limit at 70.5% or OB midpoint',
            'SL: above Swing High or OB high'
          ],
          entry_rules: [
            EntryRule.new(id: :bos, description: 'Confirmed Bearish BOS', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :fib_drawn, description: 'Fib drawn from swing high to swing low', required: true, weight: 2, tags: [:fib]),
            EntryRule.new(id: :ote_zone, description: 'Price in 62%–79% OTE zone for short', required: true, weight: 3, tags: [:ote]),
            EntryRule.new(id: :sweet_spot, description: '70.5% sweet spot if OB/FVG aligns', required: false, weight: 1, tags: [:ote, :ob, :fvg]),
            EntryRule.new(id: :ob_or_fvg_present, description: 'Bearish OB or FVG in OTE zone', required: true, weight: 3, tags: [:ob, :fvg]),
            EntryRule.new(id: :premium, description: 'Entry in Premium zone', required: false, weight: 1, tags: [:premium_discount])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above Swing High or OB high', anchor_type: :swing_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing low / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-G',
          name: 'OTE Fibonacci Entry',
          short_name: 'OTE Fib',
          playbook_type: :ict,
          complexity: :medium,
          win_rate: :high,
          rr_range: { min: 3.0, max: 5.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes below swing low (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above swing high (short)', invalidation_type: :price_close_above, applies_to: :short),
            InvalidationRule.new(description: 'New LL after entry (long)', invalidation_type: :new_ll, applies_to: :long),
            InvalidationRule.new(description: 'New HH after entry (short)', invalidation_type: :new_hh, applies_to: :short)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'OB/FVG at OTE', description: 'Order Block or FVG inside OTE zone', impact_on_rr: :tighter_sl, tags: [:ote, :ob, :fvg])
          ],
          description: 'OB or FVG at 62–79% retrace. 70.5% sweet spot. Tighter SL, higher win rate. Draw Fib from swing extremes after confirmed BOS. Only valid when OB or FVG exists within the OTE zone.'
        )
      end
    end
  end
end
