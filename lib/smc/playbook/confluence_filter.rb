# frozen_string_literal: true

module SMC
  module Playbook
    # A confluence factor that strengthens a setup when present.
    # Used to explain why certain combinations of signals produce higher edge.
    class ConfluenceFilter
      attr_reader :name, :description, :impact_on_rr, :tags

      def initialize(name:, description:, impact_on_rr:, tags: [])
        @name = name
        @description = description
        @impact_on_rr = impact_on_rr.to_sym
        @tags = tags.map(&:to_sym)
      end

      def to_h
        {
          name: @name,
          description: @description,
          impact_on_rr: @impact_on_rr,
          tags: @tags
        }
      end
    end
  end
end
