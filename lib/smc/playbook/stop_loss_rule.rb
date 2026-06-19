# frozen_string_literal: true

module SMC
  module Playbook
    # Defines where stop-loss should be placed for a setup.
    # The anchor_type indicates the structural level to anchor against.
    class StopLossRule
      ANCHOR_TYPES = %i[
        ob_low ob_high
        sweep_low sweep_high
        strong_low strong_high
        swing_low swing_high
        hl_price lh_price
        trendline
        below_3rd_touch above_3rd_touch
        flip_zone
        fvg_far_edge breaker_outer_edge
      ].freeze

      attr_reader :description, :anchor_type, :buffer_pct, :buffer_absolute

      def initialize(description:, anchor_type:, buffer_pct: nil, buffer_absolute: nil)
        @description = description
        @anchor_type = anchor_type.to_sym
        @buffer_pct = buffer_pct&.to_f
        @buffer_absolute = buffer_absolute&.to_f
      end

      def to_h
        {
          description: @description,
          anchor_type: @anchor_type,
          buffer_pct: @buffer_pct,
          buffer_absolute: @buffer_absolute
        }
      end
    end
  end
end
