# frozen_string_literal: true

module SMC
  module Playbook
    # Defines a profit target level (TP1, TP2, TP3) with
    # position percentage to close and the action to take on hit.
    class ProfitTarget
      LEVELS = %i[tp1 tp2 tp3].freeze
      ACTIONS = %i[move_to_breakeven trail close_final none].freeze

      attr_reader :level, :description, :position_pct, :action, :risk_multiple

      def initialize(level:, description:, position_pct:, action:, risk_multiple: nil)
        @level = level.to_sym
        @description = description
        @position_pct = position_pct.to_i
        @action = action.to_sym
        @risk_multiple = risk_multiple&.to_f
      end

      def to_h
        {
          level: @level,
          description: @description,
          position_pct: @position_pct,
          action: @action,
          risk_multiple: @risk_multiple
        }
      end
    end
  end
end
