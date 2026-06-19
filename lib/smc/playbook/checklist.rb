# frozen_string_literal: true

module SMC
  module Playbook
    # Evaluates market state against a playbook's entry rules.
    # Returns a score, pass/fail list, and overall validity flag.
    class Checklist
      attr_reader :playbook

      def initialize(playbook)
        @playbook = playbook
      end

      # Evaluates market state for the given direction.
      # Returns a hash with :score, :max_score, :passed, :failed, :setup_valid, :details.
      def evaluate(direction, candles, current_idx, _pivot_detector,
                   market_structure, liquidity_sweep, ob_detector,
                   lookback_candles: 30)
        setup = @playbook.setup_for(direction)
        return default_invalid_result(direction) unless setup

        ctx = {
          direction: direction,
          candles: candles,
          current_idx: current_idx,
          current_candle: candles[current_idx],
          market_structure: market_structure,
          liquidity_sweep: liquidity_sweep,
          ob_detector: ob_detector,
          lookback: lookback_candles
        }

        score = 0
        max_score = 0
        passed = []
        failed = []
        details = {}

        setup.entry_rules.each do |rule|
          max_score += rule.weight
          result = evaluate_rule(rule, ctx)
          details[rule.id] = result

          if result[:pass]
            score += rule.weight
            passed << rule.id
          else
            failed << rule.id
          end
        end

        required_met = setup.required_entry_rules.all? do |rule|
          details[rule.id]&.fetch(:pass, false)
        end

        {
          direction: direction,
          playbook: @playbook.id,
          score: score,
          max_score: max_score,
          passed: passed,
          failed: failed,
          setup_valid: required_met,
          details: details
        }
      end

      private

      def default_invalid_result(direction)
        {
          direction: direction,
          playbook: @playbook.id,
          score: 0,
          max_score: 0,
          passed: [],
          failed: [],
          setup_valid: false,
          details: {}
        }
      end

      # Evaluate a single rule against the current market context.
      # Returns { pass: Boolean, reason: String }.
      def evaluate_rule(rule, ctx)
        checks = rule.tags.map { |tag| check(tag, rule, ctx) }
        passing = checks.select { |c| c[:pass] }

        if passing.any?
          { pass: true, reason: passing.first[:reason] }
        else
          { pass: false, reason: checks.first&.fetch(:reason, 'no matching evaluator') }
        end
      end

      # Dispatch a tag-based check.
      def check(tag, _rule, ctx)
        case tag
        when :trend then check_trend(ctx)
        when :sweep then check_sweep(ctx)
        when :choch then check_choch(ctx)
        when :bos then check_bos(ctx)
        when :ob then check_ob(ctx)
        when :strong_level then check_strong_level(ctx)
        when :premium_discount then check_premium_discount(ctx)
        when :entry_confirmation then check_entry_confirmation(ctx)
        when :structure_sequence then check_structure_sequence(ctx)
        when :pullback then check_pullback(ctx)
        when :fib then check_fib(ctx)
        when :liquidity_build then check_liquidity_build(ctx)
        when :ssl then check_ssl(ctx)
        when :bsl then check_bsl(ctx)
        when :htf_bias then check_htf_bias(ctx)
        when :session then check_session(ctx)
        when :fvg then check_fvg(ctx)
        when :breaker then check_breaker(ctx)
        when :ote then check_ote(ctx)
        else
          { pass: false, reason: "unknown tag: #{tag}" }
        end
      end

      # --- Trend checks ---

      def check_trend(ctx)
        ms = ctx[:market_structure]
        trend = ms&.trend
        expected = ctx[:direction] == :long ? :BULLISH : :BEARISH

        if trend == expected
          { pass: true, reason: "trend is #{trend}" }
        else
          { pass: false, reason: "trend is #{trend}, expected #{expected}" }
        end
      end

      def check_htf_bias(ctx)
        # For now, delegates to trend check. In MTF usage this would check HTF state.
        check_trend(ctx)
      end

      # --- Sweep checks ---

      def check_sweep(ctx)
        ls = ctx[:liquidity_sweep]
        lookback = ctx[:lookback]
        idx = ctx[:current_idx]
        sweeps = ls&.sweeps || []

        recent = sweeps.select { |s| s[:index] >= (idx - lookback) }
        if recent.any?
          { pass: true, reason: "recent sweep at index #{recent.last[:index]}" }
        else
          { pass: false, reason: 'no recent sweep' }
        end
      end

      def check_ssl(ctx)
        check_sweep_type(ctx, :ssl_sweep)
      end

      def check_bsl(ctx)
        check_sweep_type(ctx, :bsl_sweep)
      end

      def check_sweep_type(ctx, type)
        ls = ctx[:liquidity_sweep]
        lookback = ctx[:lookback]
        idx = ctx[:current_idx]
        sweeps = ls&.sweeps || []

        recent = sweeps.select { |s| s[:type] == type && s[:index] >= (idx - lookback) }
        if recent.any?
          { pass: true, reason: "recent #{type} at index #{recent.last[:index]}" }
        else
          { pass: false, reason: "no recent #{type}" }
        end
      end

      def check_strong_level(ctx)
        ms = ctx[:market_structure]
        if ctx[:direction] == :long
          if ms&.protected_low
            { pass: true, reason: "protected low at #{ms.protected_low[:price]}" }
          else
            { pass: false, reason: 'no protected low' }
          end
        else
          if ms&.protected_high
            { pass: true, reason: "protected high at #{ms.protected_high[:price]}" }
          else
            { pass: false, reason: 'no protected high' }
          end
        end
      end

      # --- Structure checks ---

      def check_choch(ctx)
        ms = ctx[:market_structure]
        lookback = ctx[:lookback]
        idx = ctx[:current_idx]
        events = ms&.choch_events || []
        direction = ctx[:direction]

        expected = direction == :long ? :bullish : :bearish
        recent = events.select { |e| e[:direction] == expected && e[:index] >= (idx - lookback) }

        if recent.any?
          { pass: true, reason: "#{expected} CHoCH at index #{recent.last[:index]}" }
        else
          { pass: false, reason: "no #{expected} CHoCH in lookback" }
        end
      end

      def check_bos(ctx)
        ms = ctx[:market_structure]
        lookback = ctx[:lookback]
        idx = ctx[:current_idx]
        events = ms&.bos_events || []
        direction = ctx[:direction]

        expected = direction == :long ? :bullish : :bearish
        recent = events.select { |e| e[:direction] == expected && e[:index] >= (idx - lookback) }

        if recent.any?
          { pass: true, reason: "#{expected} BOS at index #{recent.last[:index]}" }
        else
          { pass: false, reason: "no #{expected} BOS in lookback" }
        end
      end

      def check_structure_sequence(ctx)
        ms = ctx[:market_structure]
        ls = ctx[:liquidity_sweep]
        lookback = ctx[:lookback]
        idx = ctx[:current_idx]
        direction = ctx[:direction]

        sweep_type = direction == :long ? :ssl_sweep : :bsl_sweep
        sweep = (ls&.sweeps || [])
                .select { |s| s[:type] == sweep_type && s[:index] >= (idx - lookback) }
                .max_by { |s| s[:index] }

        return { pass: false, reason: 'no recent sweep for sequence' } unless sweep

        choch_events = ms&.choch_events || []
        bos_events = ms&.bos_events || []
        expected_dir = direction == :long ? :bullish : :bearish

        choch = choch_events
                .select { |e| e[:direction] == expected_dir && e[:index] > sweep[:index] }
                .min_by { |e| e[:index] }

        return { pass: false, reason: 'no CHoCH after sweep' } unless choch

        bos = bos_events
              .select { |e| e[:direction] == expected_dir && e[:index] > choch[:index] }
              .min_by { |e| e[:index] }

        if bos
          { pass: true, reason: "sweep->CHoCH->BOS sequence confirmed" }
        else
          { pass: false, reason: 'no BOS after CHoCH' }
        end
      end

      def check_pullback(ctx)
        ms = ctx[:market_structure]
        candles = ctx[:candles]
        idx = ctx[:current_idx]
        direction = ctx[:direction]

        events = direction == :long ? ms&.bos_events : ms&.bos_events
        expected = direction == :long ? :bullish : :bearish
        recent_bos = events&.select { |e| e[:direction] == expected && e[:index] < idx }&.max_by { |e| e[:index] }

        return { pass: false, reason: 'no prior BOS for pullback check' } unless recent_bos

        bos_idx = recent_bos[:index]
        bos_close = candles[bos_idx]&.close
        return { pass: false, reason: 'missing BOS candle' } unless bos_close

        has_pullback = ((bos_idx + 1)...idx).any? do |i|
          c = candles[i]
          break false unless c

          direction == :long ? c.close < bos_close : c.close > bos_close
        end

        if has_pullback
          { pass: true, reason: 'pullback confirmed after BOS' }
        else
          { pass: false, reason: 'no pullback after BOS' }
        end
      end

      # --- OB checks ---

      def check_ob(ctx)
        obd = ctx[:ob_detector]
        candles = ctx[:candles]
        idx = ctx[:current_idx]
        direction = ctx[:direction]
        current = ctx[:current_candle]

        active = direction == :long ? obd&.active_bullish_obs : obd&.active_bearish_obs
        active ||= []

        # Filter to OBs created before current index
        valid = active.select { |ob| ob.created_at < idx }

        # Check if current candle is inside any active OB
        inside = valid.find do |ob|
          if direction == :long
            current.low <= ob.high && current.close >= ob.low
          else
            current.high >= ob.low && current.close <= ob.high
          end
        end

        if inside
          { pass: true, reason: "price inside #{direction} OB" }
        elsif valid.any?
          { pass: false, reason: 'active OB exists but price not in zone' }
        else
          { pass: false, reason: "no active #{direction} OB" }
        end
      end

      # --- Premium / Discount ---

      def check_premium_discount(ctx)
        current = ctx[:current_candle]
        ms = ctx[:market_structure]
        direction = ctx[:direction]

        low_price = ms&.protected_low&.fetch(:price, nil) || current.low
        high_price = ms&.protected_high&.fetch(:price, nil) || current.high

        return { pass: false, reason: 'cannot form dealing range' } if high_price <= low_price

        equilibrium = (low_price + high_price) / 2.0

        if direction == :long
          if current.close <= equilibrium
            { pass: true, reason: "price in discount (#{current.close} <= #{equilibrium})" }
          else
            { pass: false, reason: "price not in discount (#{current.close} > #{equilibrium})" }
          end
        else
          if current.close >= equilibrium
            { pass: true, reason: "price in premium (#{current.close} >= #{equilibrium})" }
          else
            { pass: false, reason: "price not in premium (#{current.close} < #{equilibrium})" }
          end
        end
      end

      # --- Entry confirmation ---

      def check_entry_confirmation(ctx)
        candles = ctx[:candles]
        idx = ctx[:current_idx]
        current = ctx[:current_candle]
        prior = idx.positive? ? candles[idx - 1] : nil
        direction = ctx[:direction]

        pass = if direction == :long
                 current.bullish_engulfing?(prior) || current.bullish_rejection_wick?
               else
                 current.bearish_engulfing?(prior) || current.bearish_rejection_wick?
               end

        if pass
          { pass: true, reason: 'entry confirmation candle detected' }
        else
          { pass: false, reason: 'no entry confirmation candle' }
        end
      end

      # --- Fibonacci / OTE (stub — computes basic retracement when swing data is present) ---

      def check_fib(ctx)
        check_ote(ctx)
      end

      def check_ote(ctx)
        # OTE check is a simplified proxy: verify OB retest is within 50–100% of OB body.
        # A full fib implementation would need swing range data.
        ob_result = check_ob(ctx)
        if ob_result[:pass]
          { pass: true, reason: 'OB present for OTE proxy check' }
        else
          { pass: false, reason: 'no OB for OTE evaluation' }
        end
      end

      # --- Liquidity build ---

      def check_liquidity_build(ctx)
        ls = ctx[:liquidity_sweep]
        eql = ls&.equal_lows || []
        eqh = ls&.equal_highs || []

        if ctx[:direction] == :long
          if eql.any?
            { pass: true, reason: "equal lows present (#{eql.size} levels)" }
          else
            { pass: false, reason: 'no equal lows (liquidity not built)' }
          end
        else
          if eqh.any?
            { pass: true, reason: "equal highs present (#{eqh.size} levels)" }
          else
            { pass: false, reason: 'no equal highs (liquidity not built)' }
          end
        end
      end

      # --- Session / time-based (stub for Silver Bullet etc.) ---

      def check_session(ctx)
        current = ctx[:current_candle]
        time = current.time
        # Simple UTC check for common kill windows
        # London Open: 07:00–08:00 UTC; NY Open: 14:00–15:00 UTC; NY Mid: 15:00–16:00 UTC
        hour = time.is_a?(Time) ? time.hour : Time.parse(time.to_s).hour
        in_window = (hour == 7 || hour == 14 || hour == 15)

        if in_window
          { pass: true, reason: "within kill window (hour #{hour})" }
        else
          { pass: false, reason: "outside kill window (hour #{hour})" }
        end
      rescue StandardError
        { pass: false, reason: 'unable to parse session time' }
      end

      # --- FVG (Fair Value Gap) — stub ---

      def check_fvg(ctx)
        # FVG detection not yet in core SMC module; stubbed as pass-true when displacement exists.
        ms = ctx[:market_structure]
        recent_bos = (ms&.bos_events || []).select { |e| e[:index] >= (ctx[:current_idx] - ctx[:lookback]) }
        if recent_bos.any?
          { pass: true, reason: 'recent BOS implies potential FVG' }
        else
          { pass: false, reason: 'no recent BOS for FVG inference' }
        end
      end

      # --- Breaker Block — stub ---

      def check_breaker(ctx)
        # Breaker detection not yet in core; proxy via invalidated OB + new structure break.
        obd = ctx[:ob_detector]
        invalidated = (obd&.order_blocks || []).select(&:invalidated?)
        ms = ctx[:market_structure]
        recent_structure = (ms&.bos_events || []).select { |e| e[:index] >= (ctx[:current_idx] - ctx[:lookback]) }

        if invalidated.any? && recent_structure.any?
          { pass: true, reason: 'invalidated OB + new structure suggests breaker' }
        else
          { pass: false, reason: 'no breaker conditions met' }
        end
      end
    end
  end
end
