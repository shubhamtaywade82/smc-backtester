# frozen_string_literal: true

require_relative 'playbook_helpers'

module SMC
  module Strategy
    # Generic Strategy::Base adapter that wraps any SMC::Playbook::Playbook
    # and evaluates it using the playbook's Checklist. Supports both direct
    # playbook references and playbook IDs resolved via the registry.
    class PlaybookStrategyAdapter < Base
      include PlaybookHelpers

      attr_reader :playbook, :lookback_candles, :min_risk_reward, :require_entry_confirmation

      def initialize(
        playbook_or_id:,
        lookback_candles: 30,
        min_risk_reward: 3.0,
        require_entry_confirmation: true
      )
        @playbook = resolve_playbook(playbook_or_id)
        super(name: "#{@playbook.name}")
        @lookback_candles = lookback_candles
        @min_risk_reward = min_risk_reward.to_f
        @require_entry_confirmation = require_entry_confirmation
      end

      def evaluate(candles, current_idx, pivot_detector, market_structure, liquidity_sweep, ob_detector)
        current_candle = candles[current_idx]

        evaluate_direction(:long, candles, current_idx, current_candle, pivot_detector, market_structure, liquidity_sweep, ob_detector) ||
          evaluate_direction(:short, candles, current_idx, current_candle, pivot_detector, market_structure, liquidity_sweep, ob_detector)
      end

      private

      def resolve_playbook(playbook_or_id)
        case playbook_or_id
        when SMC::Playbook::Playbook then playbook_or_id
        when String then SMC::Playbook::PlaybookRegistry.default.find(playbook_or_id)
        when Symbol then SMC::Playbook::PlaybookRegistry.default.find(playbook_or_id.to_s.gsub('_', '-'))
        else
          raise ArgumentError, "Cannot resolve playbook from: #{playbook_or_id.class}"
        end
      end

      def evaluate_direction(direction, candles, current_idx, current_candle, pivot_detector, market_structure, liquidity_sweep, ob_detector)
        setup = @playbook.setup_for(direction)
        return nil unless setup

        result = @playbook.checklist.evaluate(
          direction, candles, current_idx, pivot_detector,
          market_structure, liquidity_sweep, ob_detector,
          lookback_candles: @lookback_candles
        )

        return nil unless result[:setup_valid]

        # Calculate SL from the playbook's stop-loss rules
        sl_price = calculate_sl(direction, current_candle, candles, current_idx, market_structure, liquidity_sweep, ob_detector, setup)
        return nil if sl_price.nil?

        entry = current_candle.close
        risk = (entry - sl_price).abs
        return nil unless risk.positive?

        # Calculate TP3 from dealing range or protected levels
        tp3 = calculate_tp3(direction, entry, sl_price, market_structure, current_candle)
        return nil if tp3.nil?

        rr = reward_risk_ratio(entry, sl_price, tp3)
        return nil if rr < @min_risk_reward

        tp1 = direction == :long ? entry + risk : entry - risk
        tp2 = direction == :long ? entry + (risk * 2.0) : entry - (risk * 2.0)

        {
          type: direction,
          playbook: @playbook.id,
          entry: entry,
          sl: sl_price,
          tp1: tp1,
          tp2: tp2,
          tp3: tp3,
          risk_reward: rr.round(2),
          rules_checked: result[:details].transform_values { |v| v[:pass] }
        }
      end

      def calculate_sl(direction, current_candle, candles, current_idx, market_structure, liquidity_sweep, ob_detector, setup)
        return nil if setup.stop_loss_rules.empty?

        primary = setup.stop_loss_rules.first
        anchor = primary.anchor_type

        case anchor
        when :ob_low
          ob = find_relevant_ob(direction, current_candle, ob_detector, current_idx)
          return nil unless ob
          ob.low - buffer_for(ob.low, primary)
        when :ob_high
          ob = find_relevant_ob(direction, current_candle, ob_detector, current_idx)
          return nil unless ob
          ob.high + buffer_for(ob.high, primary)
        when :sweep_low
          sweep = recent_sweep(liquidity_sweep, current_idx, direction == :long ? :ssl_sweep : :bsl_sweep, lookback:)
          return nil unless sweep
          sweep[:price] - buffer_for(sweep[:price], primary)
        when :sweep_high
          sweep = recent_sweep(liquidity_sweep, current_idx, direction == :long ? :ssl_sweep : :bsl_sweep, lookback:)
          return nil unless sweep
          sweep[:price] + buffer_for(sweep[:price], primary)
        when :strong_low
          return nil unless market_structure&.protected_low
          market_structure.protected_low[:price] - buffer_for(market_structure.protected_low[:price], primary)
        when :strong_high
          return nil unless market_structure&.protected_high
          market_structure.protected_high[:price] + buffer_for(market_structure.protected_high[:price], primary)
        when :hl_price
          hl = find_hl_swing(market_structure)
          return nil unless hl
          hl[:price] - buffer_for(hl[:price], primary)
        when :lh_price
          lh = find_lh_swing(market_structure)
          return nil unless lh
          lh[:price] + buffer_for(lh[:price], primary)
        when :swing_low
          lows = market_structure&.swings&.select { |s| s.type == :low }
          return nil if lows.nil? || lows.empty?
          lows.last.price - buffer_for(lows.last.price, primary)
        when :swing_high
          highs = market_structure&.swings&.select { |s| s.type == :high }
          return nil if highs.nil? || highs.empty?
          highs.last.price + buffer_for(highs.last.price, primary)
        when :flip_zone
          # S/R flip zone — use nearest swing extreme as proxy
          if direction == :long
            lows = market_structure&.swings&.select { |s| s.type == :low }
            return nil if lows.nil? || lows.empty?
            lows.last.price - buffer_for(lows.last.price, primary)
          else
            highs = market_structure&.swings&.select { |s| s.type == :high }
            return nil if highs.nil? || highs.empty?
            highs.last.price + buffer_for(highs.last.price, primary)
          end
        when :breaker_outer_edge
          # No breaker detector yet; fallback to swing extreme
          if direction == :long
            lows = market_structure&.swings&.select { |s| s.type == :low }
            return nil if lows.nil? || lows.empty?
            lows.last.price - buffer_for(lows.last.price, primary)
          else
            highs = market_structure&.swings&.select { |s| s.type == :high }
            return nil if highs.nil? || highs.empty?
            highs.last.price + buffer_for(highs.last.price, primary)
          end
        when :fvg_far_edge
          # FVG detection not yet implemented; fallback to swing extreme
          if direction == :long
            lows = market_structure&.swings&.select { |s| s.type == :low }
            return nil if lows.nil? || lows.empty?
            lows.last.price - buffer_for(lows.last.price, primary)
          else
            highs = market_structure&.swings&.select { |s| s.type == :high }
            return nil if highs.nil? || highs.empty?
            highs.last.price + buffer_for(highs.last.price, primary)
          end
        when :below_3rd_touch, :above_3rd_touch
          if direction == :long
            lows = market_structure&.swings&.select { |s| s.type == :low }
            return nil if lows.nil? || lows.empty?
            current_candle.low - buffer_for(current_candle.low, primary)
          else
            highs = market_structure&.swings&.select { |s| s.type == :high }
            return nil if highs.nil? || highs.empty?
            current_candle.high + buffer_for(current_candle.high, primary)
          end
        else
          nil
        end
      end

      def buffer_for(price, rule)
        if rule.buffer_absolute
          rule.buffer_absolute
        elsif rule.buffer_pct
          price * rule.buffer_pct
        else
          price * 0.001
        end
      end

      def find_relevant_ob(direction, current_candle, ob_detector, current_idx)
        active = direction == :long ? ob_detector&.active_bullish_obs : ob_detector&.active_bearish_obs
        active ||= []
        active.select { |ob| ob.created_at < current_idx }.find do |ob|
          if direction == :long
            current_candle.low <= ob.high && current_candle.close >= ob.low
          else
            current_candle.high >= ob.low && current_candle.close <= ob.high
          end
        end
      end

      def find_hl_swing(market_structure)
        lows = market_structure&.swings&.select { |s| s.type == :low }
        return nil unless lows
        lows.reverse.find { |s| market_structure.classified_swings[s.index] == :HL }
      end

      def find_lh_swing(market_structure)
        highs = market_structure&.swings&.select { |s| s.type == :high }
        return nil unless highs
        highs.reverse.find { |s| market_structure.classified_swings[s.index] == :LH }
      end

      def calculate_tp3(direction, entry, sl_price, market_structure, current_candle)
        if direction == :long
          high_target = market_structure&.protected_high&.fetch(:price, nil) || current_candle.high
          low_anchor = sl_price
          return nil unless high_target > low_anchor
          high_target
        else
          low_target = market_structure&.protected_low&.fetch(:price, nil) || current_candle.low
          high_anchor = sl_price
          return nil unless high_anchor > low_target
          low_target
        end
      end

      def lookback
        @lookback_candles
      end
    end
  end
end
