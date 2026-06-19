# frozen_string_literal: true

module SMC
  module Playbook
    # Defines a condition that invalidates an active trade or setup.
    # If triggered, the setup is no longer valid and open positions should be exited.
    class InvalidationRule
      INVALIDATION_TYPES = %i[
        price_close_below price_close_above
        new_ll new_hh
        double_test
        below_strong_low above_strong_high
        ob_tested_more_than_twice
        time_expired
      ].freeze

      attr_reader :description, :invalidation_type, :applies_to

      def initialize(description:, invalidation_type:, applies_to: :both)
        @description = description
        @invalidation_type = invalidation_type.to_sym
        @applies_to = applies_to.to_sym
      end

      def applies_to_long?
        @applies_to == :long || @applies_to == :both
      end

      def applies_to_short?
        @applies_to == :short || @applies_to == :both
      end

      def to_h
        {
          description: @description,
          invalidation_type: @invalidation_type,
          applies_to: @applies_to
        }
      end
    end
  end
end
