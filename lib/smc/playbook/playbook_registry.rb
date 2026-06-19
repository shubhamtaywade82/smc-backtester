# frozen_string_literal: true

module SMC
  module Playbook
    # Holds and indexes Playbook instances. Supports querying by
    # id, type, complexity, direction, and tags.
    class PlaybookRegistry
      def initialize
        @playbooks = {}
      end

      def self.default
        @default ||= new
      end

      def self.reset_default!
        @default = new
      end

      def register(playbook)
        @playbooks[playbook.id] = playbook
      end

      def find(id)
        @playbooks[id.to_s]
      end

      def all
        @playbooks.values
      end

      def by_type(type)
        @playbooks.values.select { |p| p.playbook_type == type.to_sym }
      end

      def by_complexity(complexity)
        @playbooks.values.select { |p| p.complexity == complexity.to_sym }
      end

      def by_direction(direction)
        @playbooks.values.select do |p|
          case direction.to_sym
          when :long then p.supports_long?
          when :short then p.supports_short?
          else false
          end
        end
      end

      def by_tag(tag)
        tag_sym = tag.to_sym
        @playbooks.values.select { |p| p.tags.include?(tag_sym) }
      end

      def by_win_rate(win_rate)
        @playbooks.values.select { |p| p.win_rate == win_rate.to_sym }
      end

      def ids
        @playbooks.keys.sort
      end

      def size
        @playbooks.size
      end
    end
  end
end
