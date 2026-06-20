# frozen_string_literal: true

require_relative 'formation_phase'
require_relative 'formation_report'

module SMC
  module Playbook
    # Analyzes market state to determine which playbooks are in the process
    # of forming, what triggers are pending, and what levels are projected.
    class FormationAnalyzer
      attr_reader :candles, :current_idx, :pivot_detector,
                  :market_structure, :liquidity_sweep, :ob_detector

      def initialize(candles:, current_idx:, pivot_detector:,
                     market_structure:, liquidity_sweep:, ob_detector:)
        @candles = candles
        @current_idx = current_idx
        @pivot_detector = pivot_detector
        @market_structure = market_structure
        @liquidity_sweep = liquidity_sweep
        @ob_detector = ob_detector
      end

      # Analyze a single playbook for both directions
      def analyze_playbook(playbook, lookback: 30)
        reports = []
        %i[long short].each do |direction|
          report = analyze_direction(playbook, direction, lookback: lookback)
          reports << report if report
        end
        reports
      end

      # Analyze ALL registered playbooks
      def analyze_all(registry: PlaybookRegistry.default, lookback: 30, min_formation: 0.05)
        all = []
        registry.all.each do |pb|
          reports = analyze_playbook(pb, lookback: lookback)
          all.concat(reports.select { |r| r.formation_pct >= (min_formation * 100) })
        end
        all.sort_by { |r| -r.formation_pct }
      end

      private

      def analyze_direction(playbook, direction, lookback:)
        setup = playbook.setup_for(direction)
        return nil unless setup

        result = playbook.checklist.evaluate(
          direction, candles, current_idx, pivot_detector,
          market_structure, liquidity_sweep, ob_detector,
          lookback_candles: lookback
        )

        max_score = setup.max_score
        return nil if max_score.zero?

        phases = build_phases(setup, result, direction)
        formation_pct = compute_formation_pct(phases, max_score)
        status = classify_status(formation_pct, result[:setup_valid])
        levels = project_levels(direction, setup) if formation_pct >= 40

        FormationReport.new(
          playbook: playbook,
          direction: direction,
          checklist_result: result,
          phases: phases,
          formation_pct: formation_pct,
          status: status,
          projected_levels: levels || {},
          next_trigger: find_next_trigger(phases, direction)
        )
      end

      def build_phases(setup, result, direction)
        setup.entry_rules.map do |rule|
          detail = result[:details][rule.id]
          status = detail && detail[:pass] ? :passed : :pending

          trigger_detail = if status == :pending
            compute_trigger(rule, direction)
          else
            detail&.fetch(:reason, 'complete')
          end

          FormationPhase.new(
            rule_id: rule.id,
            rule_name: rule.description,
            required: rule.required?,
            status: status,
            detail: trigger_detail,
            weight: rule.weight
          )
        end
      end

      def compute_formation_pct(phases, max_score)
        earned = phases.select(&:passed?).sum(&:weight)
        (earned.to_f / max_score * 100).round(1)
      end

      def classify_status(pct, setup_valid)
        return :executing if pct >= 100.0
        return :ready if pct >= 85.0
        return :forming if pct >= 50.0
        return :warming_up if pct >= 25.0
        :dormant
      end

      # Compute the trigger price/condition for a pending rule
      def compute_trigger(rule, direction)
        # Map rule id to the appropriate trigger computation
        case rule.id
        when :trend then "Trend is #{market_structure.trend}"
        when :swing_low, :ssl_sweep, :sweep
          eq = target_equal_low
          eq ? "Price must sweep below #{eq[:level].round(2)} (EQL)" : "Wait for EQL near lows"
        when :swing_high, :bsl_sweep
          eq = target_equal_high
          eq ? "Price must sweep above #{eq[:level].round(2)} (EQH)" : "Wait for EQH near highs"
        when :choch, :bullish_choch, :bearish_choch
          t = choch_trigger(direction)
          t ? "Break #{direction == :long ? 'above last LH' : 'below last HL'} at #{t.round(2)}" : "Wait for swing break"
        when :bos, :bullish_bos, :bearish_bos
          t = bos_trigger(direction)
          t ? "Close #{direction == :long ? 'above last HH' : 'below last LL'} at #{t.round(2)}" : "Wait for structure break"
        when :ob_identified, :ob_retest, :ltf_ob
          ob = best_active_ob(direction)
          ob ? "Entry zone: #{ob.low.round(2)} - #{ob.high.round(2)}" : "No active OB"
        when :discount, :in_discount?
          "Price below #{equilibrium.round(2)} (dealing range midpoint)"
        when :premium, :in_premium?
          "Price above #{equilibrium.round(2)} (dealing range midpoint)"
        when :pullback
          "Pullback from BOS close"
        when :strong_low, :strong_high, :strong_level
          pl = direction == :long ? market_structure.protected_low : market_structure.protected_high
          pl ? "Protected at #{pl[:price].round(2)}" : "No protected level yet"
        when :entry_confirmation
          "Wait for engulfing / rejection wick"
        when :htf_trend
          "HTF bias required"
        when :fib_drawn, :ote_zone, :sweet_spot
          "OTE needs swing range + fib calculation"
        when :ltf_choch, :choch?
          "Wait for LTF structure reversal"
        when :itf_sweep
          "Wait for ITF liquidity sweep"
        when :kill_window
          "Wait for kill-window timing"
        else
          "Pending: #{rule.description}"
        end
      end

      def find_next_trigger(phases, direction)
        first_pending = phases.find(&:pending?)
        return nil unless first_pending

        {
          rule: first_pending.rule_id,
          description: first_pending.detail,
          price: extract_price(first_pending.detail)
        }
      end

      def extract_price(detail_str)
        return nil unless detail_str.is_a?(String)

        numbers = detail_str.scan(/[\d.]+/).map(&:to_f)
        numbers.any? ? numbers.last : nil
      end

      def project_levels(direction, setup)
        return {} unless setup.stop_loss_rules.any?

        sl_rule = setup.stop_loss_rules.first
        entry = candles[current_idx]&.close
        return {} if entry.nil?

        sl = project_sl(direction, sl_rule)
        risk = sl ? (entry - sl).abs : nil

        levels = { entry: entry.round(2) }
        levels[:sl] = sl.round(2) if sl

        if risk && risk > 0
          levels[:tp1] = (direction == :long ? entry + risk : entry - risk).round(2)
          levels[:tp2] = (direction == :long ? entry + risk * 2 : entry - risk * 2).round(2)
        end

        # TP3 from dealing range extreme
        if direction == :long
          h = market_structure.protected_high&.fetch(:price, nil)
          levels[:tp3] = h.round(2) if h
        else
          l = market_structure.protected_low&.fetch(:price, nil)
          levels[:tp3] = l.round(2) if l
        end

        if risk && risk > 0
          tp3 = levels[:tp3]
          rr = tp3 ? (tp3 - entry).abs / risk : nil
          levels[:rr] = rr&.round(2)
        end

        levels
      end

      # --- Pipeline state helpers ---

      def target_equal_low
        lows = liquidity_sweep.equal_lows
        lows.last
      end

      def target_equal_high
        highs = liquidity_sweep.equal_highs
        highs.last
      end

      def choch_trigger(direction)
        swings = market_structure.swings
        highs = swings.select { |s| s.type == :high && market_structure.classified_swings[s.index] == :LH }
        lows  = swings.select { |s| s.type == :low  && market_structure.classified_swings[s.index] == :HL }

        direction == :long ? highs.last&.price : lows.last&.price
      end

      def bos_trigger(direction)
        swings = market_structure.swings
        highs = swings.select { |s| s.type == :high }
        lows  = swings.select { |s| s.type == :low  }

        direction == :long ? highs.last&.price : lows.last&.price
      end

      def best_active_ob(direction)
        active = direction == :long ? ob_detector.active_bullish_obs : ob_detector.active_bearish_obs
        active&.select { |ob| ob.created_at < current_idx }&.last
      end

      def equilibrium
        lows = market_structure.swings.select { |s| s.type == :low }
        highs = market_structure.swings.select { |s| s.type == :high }
        return 0.0 if lows.empty? || highs.empty?
        (lows.last.price + highs.last.price) / 2.0
      end

      def project_sl(direction, rule)
        case rule.anchor_type
        when :ob_low
          ob = best_active_ob(direction)
          ob&.low
        when :ob_high
          ob = best_active_ob(direction)
          ob&.high
        when :sweep_low
          target_equal_low&.fetch(:level, nil)
        when :sweep_high
          target_equal_high&.fetch(:level, nil)
        when :strong_low
          market_structure.protected_low&.fetch(:price, nil)
        when :strong_high
          market_structure.protected_high&.fetch(:price, nil)
        when :swing_low
          market_structure.swings.select { |s| s.type == :low }&.last&.price
        when :swing_high
          market_structure.swings.select { |s| s.type == :high }&.last&.price
        else
          nil
        end
      end
    end
  end
end
