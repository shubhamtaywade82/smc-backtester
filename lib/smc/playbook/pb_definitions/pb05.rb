# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb05
        long_setup = Setup.new(
          direction: :long,
          description: 'The institutional entry zone. After displacement causes a BOS, the last opposing candle (OB) before that displacement is where institutions placed their initial orders.',
          steps: [
            'Bullish displacement candle(s)',
            'Bullish BOS — prior HH broken',
            'Last bearish candle before displacement = Bullish OB',
            'Price retraces',
            'Price enters OB zone (50–100%)',
            'LTF bullish confirmation',
            'BUY'
          ],
          entry_rules: [
            EntryRule.new(id: :displacement, description: 'Displacement created a clear BOS', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :ob_identified, description: 'OB is the last bearish candle BEFORE displacement', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :ob_caused_bos, description: 'OB caused the BOS (no orphan OBs)', required: true, weight: 3, tags: [:ob, :bos]),
            EntryRule.new(id: :ob_retest, description: 'Price enters 50–100% of OB body', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :fvg_above, description: 'FVG above OB = extra confluence', required: false, weight: 1, tags: [:fvg]),
            EntryRule.new(id: :ltf_confirmation, description: 'LTF bullish confirmation at OB retest', required: false, weight: 1, tags: [:entry_confirmation])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below the OB low (never inside)', anchor_type: :ob_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing high / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Bearish OB retest. Price returns to fill remaining sell orders.',
          steps: [
            'Bearish displacement candle(s)',
            'Bearish BOS — prior LL broken',
            'Last bullish candle before displacement = Bearish OB',
            'Price retraces upward',
            'Price enters OB zone (50–100%)',
            'LTF bearish confirmation',
            'SELL'
          ],
          entry_rules: [
            EntryRule.new(id: :displacement, description: 'Bearish displacement → BOS', required: true, weight: 3, tags: [:bos]),
            EntryRule.new(id: :ob_identified, description: 'Last bullish candle before displacement = OB', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :ob_caused_bos, description: 'OB caused the BOS — not just any candle', required: true, weight: 3, tags: [:ob, :bos]),
            EntryRule.new(id: :ob_retest, description: 'Price retraces into OB (50–100%)', required: true, weight: 3, tags: [:ob]),
            EntryRule.new(id: :premium_zone, description: 'OB in Premium zone (above 50% of range)', required: false, weight: 1, tags: [:premium_discount]),
            EntryRule.new(id: :ltf_confirmation, description: 'LTF bearish confirmation at OB retest', required: false, weight: 1, tags: [:entry_confirmation])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above OB high', anchor_type: :ob_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing low / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-5',
          name: 'Order Block Retest',
          short_name: 'OB Retest',
          playbook_type: :base,
          complexity: :medium,
          win_rate: :high,
          rr_range: { min: 3.0, max: 5.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes below Bullish OB low (long)', invalidation_type: :below_strong_low, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above Bearish OB high (short)', invalidation_type: :above_strong_high, applies_to: :short),
            InvalidationRule.new(description: 'OB is tested more than twice (losing freshness)', invalidation_type: :ob_tested_more_than_twice, applies_to: :both)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'FVG above OB', description: 'FVG nested above or inside OB', impact_on_rr: :tighter_sl, tags: [:fvg, :ob]),
            ConfluenceFilter.new(name: 'Premium/Discount OB', description: 'OB in correct PD zone', impact_on_rr: :higher_win_rate, tags: [:premium_discount, :ob])
          ],
          description: 'The institutional entry zone. After displacement causes a BOS, the last opposing candle (OB) before that displacement is where institutions placed their initial orders. Price returns to fill remaining orders — your entry.'
        )
      end
    end
  end
end
