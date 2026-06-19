# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb03
        long_setup = Setup.new(
          direction: :long,
          description: 'After a confirmed BOS, wait for the pullback and enter continuation. Pure market structure play.',
          steps: [
            'HL → HH (existing structure)',
            'Bullish BOS — close above prev HH',
            'Retracement begins',
            'Pullback to prev BOS level or 50% retrace',
            'HL forms — structure holds',
            'BUY at new HL'
          ],
          entry_rules: [
            EntryRule.new(id: :trend, description: 'Bullish trend confirmed', required: true, weight: 3, tags: [:trend]),
            EntryRule.new(id: :bullish_bos, description: 'Bullish BOS confirmed (full candle close)', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :pullback, description: 'Pullback does NOT break below the BOS origin', required: true, weight: 3, tags: [:pullback]),
            EntryRule.new(id: :new_hl, description: 'New HL forms on LTF (structure intact)', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :ob_or_fvg, description: 'OB or FVG at pullback zone strengthens entry', required: false, weight: 1, tags: [:ob, :fvg]),
            EntryRule.new(id: :discount, description: 'Entry in discount zone', required: false, weight: 1, tags: [:premium_discount])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below the new HL', anchor_type: :hl_price, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing high / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'After a confirmed bearish BOS, wait for the pullback and enter continuation.',
          steps: [
            'LH → LL (existing structure)',
            'Bearish BOS — close below prev LL',
            'Retracement begins',
            'Pullback to prev BOS level or 50% retrace',
            'LH forms — structure holds bearish',
            'SELL at new LH'
          ],
          entry_rules: [
            EntryRule.new(id: :trend, description: 'Bearish trend confirmed', required: true, weight: 3, tags: [:trend]),
            EntryRule.new(id: :bearish_bos, description: 'Bearish BOS confirmed (full candle close)', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :pullback, description: 'Pullback does NOT breach above BOS origin', required: true, weight: 3, tags: [:pullback]),
            EntryRule.new(id: :new_lh, description: 'New LH forms on LTF', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :ob_or_fvg, description: 'Bearish OB or FVG at pullback zone', required: false, weight: 1, tags: [:ob, :fvg]),
            EntryRule.new(id: :premium, description: 'Entry in premium zone', required: false, weight: 1, tags: [:premium_discount])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above the new LH', anchor_type: :lh_price, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing low / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-3',
          name: 'BOS Pullback Continuation',
          short_name: 'BOS Pullback',
          playbook_type: :base,
          complexity: :medium,
          win_rate: :high,
          rr_range: { min: 2.0, max: 4.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Pullback breaks below BOS origin (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Pullback breaks above BOS origin (short)', invalidation_type: :price_close_above, applies_to: :short),
            InvalidationRule.new(description: 'New LL after entry (long)', invalidation_type: :new_ll, applies_to: :long),
            InvalidationRule.new(description: 'New HH after entry (short)', invalidation_type: :new_hh, applies_to: :short)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'OB at pullback', description: 'Order Block at pullback zone', impact_on_rr: :tighter_sl, tags: [:ob]),
            ConfluenceFilter.new(name: 'Discount/Premium', description: 'Enter in correct PD zone', impact_on_rr: :higher_win_rate, tags: [:premium_discount])
          ],
          description: 'After a confirmed Break of Structure, institutions rarely reverse immediately. Price retraces, collects liquidity, and continues in the BOS direction. No Order Block required — this is pure structure play. High win rate in trend.',
          strategy_class: SMC::Strategy::BosPullbackStrategy
        )
      end
    end
  end
end
