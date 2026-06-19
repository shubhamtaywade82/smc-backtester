# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb_mtf
        long_setup = Setup.new(
          direction: :long,
          description: 'Multi-Timeframe Confluence. HTF bias + ITF sweep + LTF OB precision entry. The ultimate confluenced execution model.',
          steps: [
            'HTF (15M/1H) Trend: Confirmed Bullish (recent HL and HH)',
            'ITF (5M/15M) Sweep: Sell-Side Liquidity (SSL) swept and candle closed back inside support',
            'LTF (5M/1M) CHoCH: Reversal break of the last LTF swing high',
            'LTF (5M/1M) OB Retest: Candle low penetrates the top of LTF Bullish Order Block',
            'Discount Zone: Entry price must be in discount territory',
            'Sizing: Max 1.5% capital risk per trade'
          ],
          entry_rules: [
            EntryRule.new(id: :htf_trend, description: 'HTF trend confirmed bullish (recent Higher Low and Higher High)', required: true, weight: 3, tags: [:trend, :htf_bias]),
            EntryRule.new(id: :itf_sweep, description: 'ITF Sell-Side Liquidity (SSL) swept and closed back inside', required: true, weight: 3, tags: [:ssl, :sweep]),
            EntryRule.new(id: :ltf_choch, description: 'LTF CHoCH — reversal break of last LTF swing high', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :ltf_ob, description: 'LTF OB retest — candle low penetrates top of bullish OB', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :discount, description: 'Entry in discount territory (below dealing range midpoint)', required: true, weight: 2, tags: [:premium_discount]),
            EntryRule.new(id: :sizing, description: 'Max 1.5% capital risk per trade', required: false, weight: 1, tags: [:structure])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below OB or Sweep low', anchor_type: :ob_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: 'Internal liquidity / prev Internal HH', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'External liquidity / Major Swing HH', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'HTF target — Daily/Weekly Highs', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Multi-Timeframe Confluence short. HTF bearish + ITF BSL sweep + LTF bearish OB.',
          steps: [
            'HTF (15M/1H) Trend: Confirmed Bearish (recent Lower High and Lower Low)',
            'ITF (5M/15M) Sweep: Buy-Side Liquidity (BSL) swept and closed back below',
            'LTF (5M/1M) CHoCH: Reversal break of last LTF swing low',
            'LTF (5M/1M) OB Retest: Candle high penetrates bottom of bearish OB',
            'Premium Zone: Entry in premium territory',
            'Sizing: Max 1.5% capital risk per trade'
          ],
          entry_rules: [
            EntryRule.new(id: :htf_trend, description: 'HTF trend confirmed bearish (recent Lower High and Lower Low)', required: true, weight: 3, tags: [:trend, :htf_bias]),
            EntryRule.new(id: :itf_sweep, description: 'ITF Buy-Side Liquidity (BSL) swept and closed back below', required: true, weight: 3, tags: [:bsl, :sweep]),
            EntryRule.new(id: :ltf_choch, description: 'LTF bearish CHoCH — break of last LTF swing low', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :ltf_ob, description: 'LTF bearish OB retest', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :premium, description: 'Entry in premium territory (above dealing range midpoint)', required: true, weight: 2, tags: [:premium_discount]),
            EntryRule.new(id: :sizing, description: 'Max 1.5% capital risk per trade', required: false, weight: 1, tags: [:structure])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above OB or Sweep high', anchor_type: :ob_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: 'Internal liquidity / prev Internal LL', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'External liquidity / Major Swing LL', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'HTF target — Daily/Weekly Lows', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-MTF',
          name: 'Multi-Timeframe Confluence',
          short_name: 'MTF Playbook',
          playbook_type: :ict,
          complexity: :very_high,
          win_rate: :very_high,
          rr_range: { min: 5.0, max: 10.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'HTF prints new LL after entry (long)', invalidation_type: :new_ll, applies_to: :long),
            InvalidationRule.new(description: 'HTF prints new HH after entry (short)', invalidation_type: :new_hh, applies_to: :short),
            InvalidationRule.new(description: 'Price closes below OB low (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above OB high (short)', invalidation_type: :price_close_above, applies_to: :short)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: '3-timeframe alignment', description: 'HTF bias + ITF sweep + LTF entry', impact_on_rr: :clear_target, tags: [:htf_bias, :sweep, :ob]),
            ConfluenceFilter.new(name: 'Premium/Discount', description: 'Entry in correct PD zone', impact_on_rr: :higher_win_rate, tags: [:premium_discount])
          ],
          description: 'The ultimate confluenced execution model. By combining structures across three distinct timeframes, we align our trades with institutional momentum while entering at high-precision low-timeframe zones.',
          strategy_class: SMC::Strategy::MTFConfluence
        )
      end
    end
  end
end
