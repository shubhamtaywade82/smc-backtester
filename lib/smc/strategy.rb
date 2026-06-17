# frozen_string_literal: true

module SMC
  module Strategy
    # Base strategy class defining interface
    class Base
      attr_reader :name

      def initialize(name:)
        @name = name
      end

      # Evaluate market data at current state and return trade signal if any
      # Return hash: { type: :long|:short, sl: float, tp1: float, tp2: float, tp3: float } or nil
      def evaluate(candles, current_idx, pivot_detector, market_structure, liquidity_sweep, ob_detector)
        raise NotImplementedError
      end
    end
  end
end

require_relative 'strategy/sweep_ob'
