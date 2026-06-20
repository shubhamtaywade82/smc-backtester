# frozen_string_literal: true

module SMC
  module Playbook
    # Describes a single phase in playbook formation.
    class FormationPhase
      attr_reader :rule_id, :rule_name, :required, :status, :detail, :weight

      def initialize(rule_id:, rule_name:, required:, status:, detail:, weight:)
        @rule_id = rule_id
        @rule_name = rule_name
        @required = required
        @status = status.to_sym
        @detail = detail
        @weight = weight
      end

      def required?
        @required
      end

      def passed?
        @status == :passed
      end

      def pending?
        @status == :pending
      end

      def failed?
        @status == :failed
      end

      def to_h
        {
          id: @rule_id,
          name: @rule_name,
          required: @required,
          status: @status,
          detail: @detail,
          weight: @weight
        }
      end
    end
  end
end
