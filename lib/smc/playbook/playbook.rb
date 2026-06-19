# frozen_string_literal: true

module SMC
  module Playbook
    # Models a single trading playbook from the SMC + ICT knowledge base.
    # Hold metadata (name, complexity, RR) plus directional Setups,
    # invalidation rules, confluence filters, and an optional custom
    # Strategy::Base subclass reference.
    class Playbook
      attr_reader :id, :name, :short_name, :playbook_type, :directions,
                  :complexity, :win_rate, :rr_range,
                  :long_setup, :short_setup,
                  :invalidation_rules, :confluence_filters,
                  :description, :strategy_class

      def initialize(
        id:, name:, short_name: nil, playbook_type: :base,
        directions: %i[long short], complexity: :medium,
        win_rate: :medium, rr_range: { min: 2.0, max: 3.0 },
        long_setup: nil, short_setup: nil,
        invalidation_rules: [], confluence_filters: [],
        description: '', strategy_class: nil
      )
        @id = id.to_s
        @name = name.to_s
        @short_name = (short_name || name).to_s
        @playbook_type = playbook_type.to_sym
        @directions = Array(directions).map(&:to_sym)
        @complexity = complexity.to_sym
        @win_rate = win_rate.to_sym
        @rr_range = rr_range.dup.transform_values(&:to_f)
        @long_setup = long_setup
        @short_setup = short_setup
        @invalidation_rules = invalidation_rules.dup
        @confluence_filters = confluence_filters.dup
        @description = description.to_s
        @strategy_class = strategy_class
      end

      def base?
        @playbook_type == :base
      end

      def ict?
        @playbook_type == :ict
      end

      def supports_long?
        @directions.include?(:long)
      end

      def supports_short?
        @directions.include?(:short)
      end

      def setup_for(direction)
        case direction.to_sym
        when :long then @long_setup
        when :short then @short_setup
        end
      end

      def tags
        all_tags = []
        [@long_setup, @short_setup].compact.each do |setup|
          setup.entry_rules.each { |r| all_tags.concat(r.tags) }
        end
        all_tags.uniq.sort
      end

      def checklist
        @checklist ||= Checklist.new(self)
      end

      def to_h
        {
          id: @id,
          name: @name,
          short_name: @short_name,
          playbook_type: @playbook_type,
          directions: @directions,
          complexity: @complexity,
          win_rate: @win_rate,
          rr_range: @rr_range,
          long_setup: @long_setup&.to_h,
          short_setup: @short_setup&.to_h,
          invalidation_rules: @invalidation_rules.map(&:to_h),
          confluence_filters: @confluence_filters.map(&:to_h),
          description: @description,
          strategy_class: @strategy_class&.name
        }
      end
    end
  end
end
