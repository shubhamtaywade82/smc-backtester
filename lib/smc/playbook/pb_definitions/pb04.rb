# frozen_string_literal: true

module SMC
  module Playbook
    module PbDefinitions
      def self.pb04
        long_setup = Setup.new(
          direction: :long,
          description: 'The Change of Character is the earliest signal that the trend is shifting — earlier than BOS. Higher risk, highest RR potential.',
          steps: [
            'Bearish trend: LH → LL sequence',
            'New LL printed',
            'Price aggressively breaks previous LH',
            'Bullish CHoCH confirmed',
            'Retrace or OB forms',
            'BUY — first structural shift entry'
          ],
          entry_rules: [
            EntryRule.new(id: :prior_trend, description: 'Prior bearish trend (LH-LL chain)', required: true, weight: 3, tags: [:trend]),
            EntryRule.new(id: :choch_break, description: 'LH broken on the close (not just wick)', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :displacement, description: 'CHoCH candle is aggressive (displacement)', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :htf_alignment, description: 'HTF also showing signs of bullish reversal', required: false, weight: 1, tags: [:htf_bias])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Below the LL that preceded CHoCH', anchor_type: :swing_low, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing high / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        short_setup = Setup.new(
          direction: :short,
          description: 'Bearish CHoCH — price aggressively breaks previous HL to signal trend shift.',
          steps: [
            'Bullish trend: HL → HH sequence',
            'New HH printed',
            'Price aggressively breaks previous HL',
            'Bearish CHoCH confirmed',
            'Retrace or OB forms',
            'SELL — first structural shift entry'
          ],
          entry_rules: [
            EntryRule.new(id: :prior_trend, description: 'Prior bullish trend (HL-HH chain)', required: true, weight: 3, tags: [:trend]),
            EntryRule.new(id: :choch_break, description: 'HL broken on the close (not just wick)', required: true, weight: 3, tags: [:choch]),
            EntryRule.new(id: :displacement, description: 'CHoCH candle is aggressive', required: true, weight: 2, tags: [:structure]),
            EntryRule.new(id: :htf_alignment, description: 'HTF showing distribution or reversal signs', required: false, weight: 1, tags: [:htf_bias])
          ],
          stop_loss_rules: [
            StopLossRule.new(description: 'Above the HH that preceded CHoCH', anchor_type: :swing_high, buffer_pct: 0.001)
          ],
          profit_targets: [
            ProfitTarget.new(level: :tp1, description: '1R target', position_pct: 30, action: :move_to_breakeven, risk_multiple: 1.0),
            ProfitTarget.new(level: :tp2, description: 'Previous swing low / 2R', position_pct: 40, action: :trail, risk_multiple: 2.0),
            ProfitTarget.new(level: :tp3, description: 'External liquidity / HTF target', position_pct: 30, action: :close_final, risk_multiple: nil)
          ]
        )

        Playbook.new(
          id: 'PB-4',
          name: 'CHoCH Reversal',
          short_name: 'CHoCH Reversal',
          playbook_type: :base,
          complexity: :medium,
          win_rate: :medium,
          rr_range: { min: 3.0, max: 6.0 },
          long_setup: long_setup,
          short_setup: short_setup,
          invalidation_rules: [
            InvalidationRule.new(description: 'Price closes below the LL that preceded CHoCH (long)', invalidation_type: :price_close_below, applies_to: :long),
            InvalidationRule.new(description: 'Price closes above the HH that preceded CHoCH (short)', invalidation_type: :price_close_above, applies_to: :short),
            InvalidationRule.new(description: 'HTF prints new LL after entry (long)', invalidation_type: :new_ll, applies_to: :long),
            InvalidationRule.new(description: 'HTF prints new HH after entry (short)', invalidation_type: :new_hh, applies_to: :short)
          ],
          confluence_filters: [
            ConfluenceFilter.new(name: 'HTF alignment', description: 'HTF also showing reversal signs', impact_on_rr: :higher_win_rate, tags: [:htf_bias])
          ],
          description: 'The Change of Character is the earliest signal that the trend is shifting — earlier than BOS. Higher risk because you are catching the turn before it is confirmed. Highest RR potential because you are early. Best used when HTF bias is also reversing.'
        )
      end
    end
  end
end
