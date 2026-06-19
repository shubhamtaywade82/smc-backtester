# frozen_string_literal: true

module SMC
  module Playbook
    # Top-level container for the entire SMC playbook knowledge base.
    # Provides querying and compatibility filtering.
    class KnowledgeBase
      attr_reader :registry

      def initialize(registry: PlaybookRegistry.default)
        @registry = registry
      end

      def playbook(id)
        @registry.find(id)
      end

      def playbooks
        @registry.all
      end

      def compatible_playbooks(direction, candles, current_idx,
                               market_structure, liquidity_sweep, ob_detector,
                               min_score_ratio: 0.5,
                               lookback_candles: 30)
        setup = @registry.by_direction(direction)
        setup.map do |pb|
          result = pb.checklist.evaluate(
            direction, candles, current_idx, nil,
            market_structure, liquidity_sweep, ob_detector,
            lookback_candles: lookback_candles
          )
          next nil unless result[:setup_valid]
          next nil if result[:max_score].zero?

          ratio = result[:score].to_f / result[:max_score]
          next nil if ratio < min_score_ratio

          { playbook: pb, checklist: result, score_ratio: ratio }
        end.compact.sort_by { |r| -r[:score_ratio] }
      end
    end
  end
end
