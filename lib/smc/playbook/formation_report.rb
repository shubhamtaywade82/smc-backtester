# frozen_string_literal: true

module SMC
  module Playbook
    # Tracks the formation state of a playbook setup.
    # Reports passed phases, pending triggers, projected entry/SL/TP levels.
    class FormationReport
      PHASE_STATUS = %i[dormant warming_up forming ready executing].freeze

      attr_reader :playbook, :direction, :checklist_result, :phases,
                  :formation_pct, :status, :projected_levels, :next_trigger

      def initialize(
        playbook:, direction:,
        checklist_result:, phases:, formation_pct:, status:,
        projected_levels:, next_trigger:
      )
        @playbook = playbook
        @direction = direction
        @checklist_result = checklist_result
        @phases = phases
        @formation_pct = formation_pct.to_f
        @status = status
        @projected_levels = projected_levels
        @next_trigger = next_trigger
      end

      def formed?
        @status == :executing && formation_pct >= 100.0
      end

      def warming_up?
        @status == :warming_up
      end

      def forming?
        @status == :forming
      end

      def ready?
        @status == :ready || @status == :executing
      end

      def to_h
        {
          playbook: @playbook.id,
          name: @playbook.name,
          direction: @direction,
          formation_pct: @formation_pct.round(1),
          status: @status,
          phases: @phases.map(&:to_h),
          next_trigger: @next_trigger,
          projected_levels: @projected_levels
        }
      end
    end
  end
end
