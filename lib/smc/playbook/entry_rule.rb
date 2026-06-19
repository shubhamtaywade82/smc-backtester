# frozen_string_literal: true

module SMC
  module Playbook
    # Represents a single entry condition within a playbook setup.
    # Each rule has a description, weight for confluence scoring,
    # required flag, and a set of semantic tags for querying and evaluation.
    class EntryRule
      attr_reader :id, :description, :required, :weight, :tags

      def initialize(id:, description:, required: true, weight: 1, tags: [])
        @id = id
        @description = description
        @required = required
        @weight = weight.to_i
        @tags = tags.map(&:to_sym)
      end

      def required?
        @required
      end

      def to_h
        {
          id: @id,
          description: @description,
          required: @required,
          weight: @weight,
          tags: @tags
        }
      end
    end
  end
end
