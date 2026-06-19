# frozen_string_literal: true

module SMC
  module Playbook
    # Represents a directional setup (long or short) within a playbook.
    # Holds the step-by-step execution flow, entry rules, stop-loss rules,
    # and profit targets for one direction.
    class Setup
      attr_reader :direction, :description, :steps, :entry_rules,
                  :stop_loss_rules, :profit_targets

      def initialize(direction:, description: '', steps: [], entry_rules: [],
                     stop_loss_rules: [], profit_targets: [])
        @direction = direction.to_sym
        @description = description
        @steps = steps.dup
        @entry_rules = entry_rules.dup
        @stop_loss_rules = stop_loss_rules.dup
        @profit_targets = profit_targets.dup
      end

      def long?
        @direction == :long
      end

      def short?
        @direction == :short
      end

      def required_entry_rules
        @entry_rules.select(&:required?)
      end

      def optional_entry_rules
        @entry_rules.reject(&:required?)
      end

      def max_score
        @entry_rules.sum(&:weight)
      end

      def to_h
        {
          direction: @direction,
          description: @description,
          steps: @steps,
          entry_rules: @entry_rules.map(&:to_h),
          stop_loss_rules: @stop_loss_rules.map(&:to_h),
          profit_targets: @profit_targets.map(&:to_h)
        }
      end
    end
  end
end
