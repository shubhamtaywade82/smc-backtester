# SMC Backtester — Tracked Implementation Plan

**Source of truth:** `smc-playbook-knowledge-base.md`  
**Baseline audit date:** 2026-06-17  
**Current coverage:** ~25–30% of full KB spec

Use checkboxes to track progress. Phases are ordered by dependency and KB automation priority.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Done |
| ⚠️ | Partial — needs work |
| ❌ | Not started |
| 🔧 | Modify existing file |
| ➕ | Create new file |

---

## Phase 0 — Shared Foundation (prerequisite for all phases)

Goal: extract duplicated logic, add config, standardize tolerances.

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `lib/smc/candle.rb` | Add `to_time`, `atr_contribution`, `engulfing?`, `rejection_wick?(:bullish/:bearish)` |
| ✅ | ➕ | `lib/smc/atr.rb` | Rolling ATR(N); used by trendline touch, equal highs/lows, displacement |
| ❌ | ➕ | `spec/smc/atr_spec.rb` | True range, Wilder/SMA, tolerance helpers — **done** |
| ❌ | ➕ | `lib/smc/config.rb` | Load `config/settings.yml` — pivot bars, tolerances, session windows, risk defaults |
| ❌ | ➕ | `config/settings.yml` | Pivot length, ATR period, sweep tolerance, session UTC ranges, R:R minimum |
| ❌ | ➕ | `lib/smc/context.rb` | Per-bar snapshot: trend, events, zones, premium/discount, playbook flags |
| ❌ | ➕ | `lib/smc/event_bus.rb` | Publish `:swing`, `:bos`, `:choch`, `:sweep`, `:ob_created`, `:signal` |
| ❌ | ➕ | `lib/smc/signal.rb` | KB agent output: `signal`, `playbook`, `confidence`, `entry`, `sl`, `tp1–3`, `reasons` |
| ⚠️ | 🔧 | `lib/smc.rb` | Require new modules in dependency order |

**Acceptance:** `SMC::Context` built from one bar update; `SMC::Signal#to_h` matches KB JSON schema.

---

## Phase 1 — Core Detectors (KB Stages 1–12)

Goal: implement every detection module the playbooks depend on.

### 1A — Market structure (exists, needs hardening)

| Status | Action | File | Work |
|--------|--------|------|------|
| ✅ | 🔧 | `lib/smc/pivot_detector.rb` | Keep; expose `confirmed_swings_up_to(candles, idx)` helper |
| ⚠️ | 🔧 | `lib/smc/market_structure.rb` | Enforce KB CHoCH rule: break most recent confirmed LH/HL; require `LH→LL` / `HL→HH` prior structure |
| ⚠️ | 🔧 | `lib/smc/market_structure.rb` | Trend = last two highs **and** lows increasing/decreasing (not single pair) |
| ⚠️ | 🔧 | `lib/smc/market_structure.rb` | BOS only when `close > previous HH` in bullish trend (mirror bearish) |
| ❌ | ➕ | `spec/market_structure/bos_choch_spec.rb` | BOS vs CHoCH classification matrix |
| ❌ | ➕ | `spec/market_structure/trend_spec.rb` | `HL→HH→HL→HH` bullish; `LH→LL→LH→LL` bearish |

### 1B — Liquidity (exists, needs completion)

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `lib/smc/liquidity_sweep.rb` | Use `equal_lows` / `equal_highs` in sweep detection (not only single swings) |
| ⚠️ | 🔧 | `lib/smc/liquidity_sweep.rb` | Switch tolerance from fixed `%` to `ATR × 0.1` (KB Level 9) |
| ✅ | ➕ | `lib/smc/liquidity/strong_low_detector.rb` | Swing low → bullish displacement → BOS ⇒ protected low — **done** |
| ✅ | ➕ | `spec/liquidity/strong_low_detector_spec.rb` | Full rule chain, CHoCH option, integration — **done** |
| ✅ | ➕ | `lib/smc/liquidity/strong_high_detector.rb` | Swing high → bearish displacement → BOS ⇒ protected high — **done** |
| ✅ | ➕ | `spec/liquidity/strong_high_detector_spec.rb` | Mirror of strong low scenarios + integration — **done** |
| ✅ | ➕ | `lib/smc/liquidity/displacement.rb` | Body/range threshold vs prior-bar ATR — **done** |
| ✅ | ➕ | `spec/liquidity/displacement_spec.rb` | Bullish/bearish, swing follow-through, range scan — **done** |
| ❌ | ➕ | `spec/liquidity/sweep_spec.rb` | SSL: break below + reclaim; BSL mirror |
| ❌ | ➕ | `spec/liquidity/strong_level_spec.rb` | Strong low/high tied to BOS |

### 1C — Order blocks (exists, needs BOS-causality)

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `lib/smc/order_block.rb` | OB valid only if displacement caused BOS/CHoCH (link to `Displacement` + event) |
| ⚠️ | 🔧 | `lib/smc/order_block.rb` | Retest: track mitigation % (50–100% of OB range) |
| ❌ | ➕ | `lib/smc/order_blocks/ob_retest_detector.rb` | Price inside OB + optional engulfing/wick/LTF CHoCH |
| ❌ | ➕ | `spec/order_blocks/order_block_spec.rb` | Bullish OB = last bearish before displacement BOS |
| ❌ | ➕ | `spec/order_blocks/retest_spec.rb` | Mitigation % and invalidation paths |

### 1D — Trendlines (missing)

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/trendlines/trendline.rb` | Value object: slope, intercept, pivot anchors, direction |
| ❌ | ➕ | `lib/smc/trendlines/trendline_builder.rb` | Connect HL1→HL2 (bull) or LH1→LH2 (bear) from swings |
| ❌ | ➕ | `lib/smc/trendlines/touch_counter.rb` | Touch when `abs(price - line) <= ATR × 0.2` |
| ❌ | ➕ | `lib/smc/trendlines/third_touch_detector.rb` | `touch_count == 3` ⇒ opportunity zone |
| ❌ | ➕ | `spec/trendlines/third_touch_spec.rb` | 2 touches invalid; 3rd touch fires |

### 1E — Support / resistance (missing)

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/support_resistance/sr_level.rb` | Zone with price, touches, type (`:support` / `:resistance`) |
| ❌ | ➕ | `lib/smc/support_resistance/cluster_detector.rb` | Cluster pivots within `0.2%` or ATR band; `touches >= 2` |
| ❌ | ➕ | `lib/smc/support_resistance/sr_detector.rb` | Active S/R from recent swings |
| ❌ | ➕ | `lib/smc/support_resistance/flip_detector.rb` | Close beyond level + retest ⇒ flip (PB2) |
| ❌ | ➕ | `spec/support_resistance/flip_spec.rb` | Resistance break → retest → support |

### 1F — FVG (missing)

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/fvg/fair_value_gap.rb` | Value object: high, low, midpoint (CE), index |
| ❌ | ➕ | `lib/smc/fvg/bullish_fvg_detector.rb` | `low[i] > high[i-2]` |
| ❌ | ➕ | `lib/smc/fvg/bearish_fvg_detector.rb` | `high[i] < low[i-2]` |
| ❌ | ➕ | `spec/fvg/fvg_spec.rb` | 3-candle gap detection |

### 1G — Premium / discount & sessions (missing)

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/premium_discount.rb` | Dealing range from protected low/high; EQ; discount/premium/OTE 62–79% |
| ❌ | ➕ | `lib/smc/session_filter.rb` | London `07:00–10:00 UTC`, NY `13:30–16:00 UTC`; `allowed?(time)` |
| ❌ | ➕ | `spec/premium_discount_spec.rb` | Price below EQ = discount |
| ❌ | ➕ | `spec/session_filter_spec.rb` | Blocks Asian chop by default |

---

## Phase 2 — Pipeline & State Machine (KB Layers 5–7)

Goal: single bar-update path feeding all detectors and strategies.

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/state_machine.rb` | Orchestrate: swings → structure → events → zones → context |
| ⚠️ | 🔧 | `lib/smc/backtester.rb` | Delegate to `StateMachine#on_bar`; remove inline pipeline duplication |
| ⚠️ | 🔧 | `lib/smc/mtf_engine.rb` | Use `StateMachine` per timeframe; process LTF bar in `align_and_process` |
| ❌ | ➕ | `lib/smc/playbook_registry.rb` | Register PB1–PB8; priority order PB8→PB7→…→PB1 |
| ❌ | ➕ | `lib/smc/confidence_scorer.rb` | Point-based score (KB Pine §Step 5) |
| ❌ | ➕ | `spec/integration/state_machine_spec.rb` | One synthetic bar sequence produces expected context |

**Acceptance:** One `on_bar` call updates all detectors and returns `Context` without look-ahead.

---

## Phase 3 — Playbook Strategies (PB1–PB8)

Goal: one strategy class per playbook; compose shared rules.

### Shared strategy infrastructure

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `lib/smc/strategy.rb` | `evaluate(context)` instead of passing 6 raw objects; extract rule helpers |
| ❌ | ➕ | `lib/smc/strategy/rules/` | One rule class per KB condition (`SslSweepRule`, `BullishChochRule`, etc.) |
| ❌ | ➕ | `lib/smc/strategy/playbook_result.rb` | `matched?`, `playbook_id`, `confidence`, `signal` |

### PB1 — Trendline 3rd Touch

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/strategy/trendline/third_touch_strategy.rb` | Bull trend + 3rd touch + bullish rejection → long |
| ❌ | ➕ | `spec/strategies/pb1_third_touch_spec.rb` | Long and short fixtures |

### PB2 — S/R Flip

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/strategy/sr/sr_flip_strategy.rb` | Resistance tested ≥2 → BOS above → retest → rejection |
| ❌ | ➕ | `spec/strategies/pb2_sr_flip_spec.rb` | Flip long + short |

### PB3 — BOS Pullback

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/strategy/structure/bos_pullback_strategy.rb` | Bullish BOS → pullback → HL → long (no OB required) |
| ❌ | ➕ | `spec/strategies/pb3_bos_pullback_spec.rb` | Highest automation priority per KB |

### PB4 — CHoCH Reversal

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/strategy/structure/choch_reversal_strategy.rb` | Bearish trend → break LH → bullish CHoCH → long |
| ❌ | ➕ | `spec/strategies/pb4_choch_reversal_spec.rb` | Reversal without OB |

### PB5 — OB Retest

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/strategy/order_blocks/ob_retest_strategy.rb` | BOS → OB → retest (standalone, not sweep-dependent) |
| ❌ | ➕ | `spec/strategies/pb5_ob_retest_spec.rb` | OB must have caused BOS |

### PB6 — Liquidity Sweep Reversal

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/strategy/liquidity/sweep_reversal_strategy.rb` | SSL sweep → bullish CHoCH → long |
| ❌ | ➕ | `spec/strategies/pb6_sweep_reversal_spec.rb` | CHoCH required (gap in current PB7) |

### PB7 — Sweep + OB (complete existing)

| Status | Action | File | Work |
|--------|--------|------|------|
| ✅ | 🔧 | `lib/smc/strategy/sweep_ob.rb` | Enforce sequence: sweep → CHoCH → BOS → OB → retest |
| ✅ | 🔧 | `lib/smc/strategy/sweep_ob.rb` | Require strong low/high; entry confirmation (engulfing or wick) |
| ✅ | 🔧 | `lib/smc/strategy/sweep_ob.rb` | SL = `min(sweep_low, ob_low, protected)`; guard against SL inside OB |
| ✅ | 🔧 | `lib/smc/strategy/sweep_ob.rb` | TP1/TP2/TP3 + min R:R ≥ 3 |
| ✅ | ➕ | `spec/strategies/pb7_sweep_ob_spec.rb` | Deterministic long/short fixtures via `spec/support/pb7_fixture.rb` |

### PB8 — A+ Full Confluence

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `lib/smc/strategy/mtf_confluence.rb` | Add: trendline 3rd touch, S/R zone, strong low, CHoCH, BOS on LTF |
| ❌ | ➕ | `lib/smc/strategy/confluence/a_plus_strategy.rb` | All PB8 filters; use as sniper (high confidence threshold) |
| ❌ | ➕ | `spec/strategies/pb8_a_plus_spec.rb` | Few trades; all filters true |

**Acceptance:** `PlaybookRegistry#active(context)` returns ranked matches; each PB has passing spec.

---

## Phase 4 — Risk & Trade Management (KB Level 16–17)

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `lib/smc/risk_manager.rb` | Enforce `R:R >= 1:3` before `open_position` |
| ⚠️ | 🔧 | `lib/smc/risk_manager.rb` | `max_open_trades` (default 3); `max_daily_loss` (2R) |
| ❌ | ➕ | `lib/smc/trailing_stop.rb` | Trail remainder after TP2 (structure or ATR) |
| ❌ | ➕ | `lib/smc/sl_engine.rb` | Structure SL: sweep low, strong low, OB low — lowest for long |
| ❌ | ➕ | `lib/smc/tp_engine.rb` | TP1=1R, TP2=internal liquidity, TP3=external/HTF swing |
| ❌ | ➕ | `spec/execution/risk_manager_spec.rb` | Daily loss halts new entries |
| ❌ | ➕ | `spec/execution/partial_exits_spec.rb` | 30/40/30 + breakeven after TP1 |

---

## Phase 5 — Backtesting & Analytics

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `lib/smc/backtester.rb` | Export playbook id, confidence, rules_checked per trade |
| ❌ | ➕ | `lib/smc/backtesting/replay_engine.rb` | Candle-by-candle replay (TradingView-style) |
| ❌ | ➕ | `lib/smc/backtesting/metrics.rb` | Sharpe, expectancy, max DD, R-multiples |
| ❌ | ➕ | `lib/smc/backtesting/optimizer.rb` | Grid search pivot/ATR/tolerance params |
| ❌ | ➕ | `lib/smc/backtesting/walk_forward.rb` | Train/test window splits |
| ❌ | ➕ | `lib/smc/backtesting/monte_carlo.rb` | Shuffle trade order / bootstrap equity |
| ❌ | ➕ | `lib/smc/reports/trade_statistics.rb` | Win rate, PF, avg R |
| ❌ | ➕ | `lib/smc/reports/equity_curve.rb` | Equity + drawdown series |
| ❌ | ➕ | `lib/smc/reports/html_report.rb` | Optional static report beyond `backtest_results.js` |
| ❌ | ➕ | `spec/backtesting/metrics_spec.rb` | Known trade set → expected metrics |

---

## Phase 6 — Adapters & CLI

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `exe/smc-fetch-coindcx` | Use `StateMachine` + `PlaybookRegistry`; output `Signal` JSON |
| ❌ | ➕ | `lib/smc/adapters/csv/csv_loader.rb` | Load OHLCV from CSV |
| ❌ | ➕ | `lib/smc/adapters/coindcx/candle_loader.rb` | Extract fetch logic from exe |
| ❌ | ➕ | `lib/smc/adapters/coindcx/paper_executor.rb` | WS → signal → paper portfolio |
| ❌ | ➕ | `lib/smc/adapters/coindcx/live_executor.rb` | Signal → risk → CoinDCX order API |
| ❌ | ➕ | `exe/smc-replay` | Replay mode CLI |
| ❌ | ➕ | `exe/smc-optimize` | Optimizer CLI |
| ❌ | ➕ | `exe/smc-paper-trade` | Paper trading CLI |
| ❌ | ➕ | `exe/smc-live-trade` | Live trading CLI (behind explicit flag) |
| ❌ | ➕ | `lib/smc/utils/timeframes.rb` | Interval parsing + aggregation (extract from `smc-mtf-backtest`) |
| ❌ | ➕ | `lib/smc/utils/logger.rb` | Structured event logging |
| 🔧 | 🔧 | `smc-backtester.gemspec` | Register new executables |

---

## Phase 7 — Test & Fixture Infrastructure

| Status | Action | File | Work |
|--------|--------|------|------|
| ⚠️ | 🔧 | `spec/spec_helper.rb` | Shared candle builders, freeze time |
| ❌ | ➕ | `spec/fixtures/pb7_bullish.json` | Frozen OHLCV for PB7 long |
| ❌ | ➕ | `spec/fixtures/pb3_bullish.json` | BOS pullback sequence |
| ❌ | ➕ | `spec/integration/full_pipeline_spec.rb` | End-to-end backtest on fixtures |
| ⚠️ | 🔧 | `lib/smc/data_generator.rb` | Add generators for PB1–PB6 (not only PB7) |
| 🔧 | 🔧 | `Rakefile` | `rake spec`, `rake integration` tasks |

**Acceptance:** `bundle exec rake spec` green; coverage for every detector and playbook.

---

## Phase 8 — Advanced / Discretionary (lower priority)

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `lib/smc/fvg/breaker_block.rb` | Failed OB → breaker flip |
| ❌ | ➕ | `lib/smc/strategy/fvg/fvg_retest_strategy.rb` | FVG CE entry |
| ❌ | ➕ | `lib/smc/strategy/session/amd_strategy.rb` | Asia range → London sweep → NY expansion |
| ❌ | ➕ | `lib/smc/strategy/session/silver_bullet_strategy.rb` | Kill-window + displacement FVG |
| ❌ | ➕ | `lib/smc/strategy/confluence/unicorn_strategy.rb` | HTF OB + breaker + FVG (discretionary flag) |

KB explicitly rates these 3–6/10 for automation — implement only after PB1–PB8 validate statistically.

---

## Phase 9 — Optional DSL / YAML (KB Trading Domain Engine)

| Status | Action | File | Work |
|--------|--------|------|------|
| ❌ | ➕ | `specs/playbooks/pb7.yml` | Declarative playbook conditions |
| ❌ | ➕ | `lib/smc/playbook_loader.rb` | YAML → rule composition |
| ❌ | ➕ | `docs/strategies.md` | Playbook → file mapping |

Defer until Ruby strategies are stable; avoids maintaining two sources of truth too early.

---

## Dependency Graph (build order)

```text
Phase 0 (ATR, Config, Context, Signal)
    ↓
Phase 1 (all detectors)
    ↓
Phase 2 (StateMachine, Registry)
    ↓
Phase 3 (PB3, PB2, PB6, PB7-complete, PB5, PB1, PB4, PB8)
    ↓
Phase 4 (Risk enhancements)
    ↓
Phase 5 (Analytics)
    ↓
Phase 6 (Adapters / CLI)
    ↓
Phase 7 (Tests — run continuously from Phase 1 onward)
    ↓
Phase 8–9 (optional)
```

---

## Suggested Sprint Slices

### Sprint 1 — Close PB7 gaps ✅
- ✅ `lib/smc/atr.rb`
- ✅ `lib/smc/liquidity/displacement.rb`
- ✅ `lib/smc/liquidity/strong_low_detector.rb`
- ✅ `lib/smc/liquidity/strong_high_detector.rb`
- ✅ `lib/smc/strategy/sweep_ob.rb`
- ✅ `spec/strategies/pb7_sweep_ob_spec.rb`
- ✅ `spec/support/pb7_fixture.rb`

### Sprint 2 — PB3 + PB6 (1–2 days)
- `lib/smc/strategy/structure/bos_pullback_strategy.rb`
- `lib/smc/strategy/liquidity/sweep_reversal_strategy.rb`
- Specs for both

### Sprint 3 — S/R + PB2 (2–3 days)
- `lib/smc/support_resistance/*`
- `lib/smc/strategy/sr/sr_flip_strategy.rb`

### Sprint 4 — Trendlines + PB1 (2–3 days)
- `lib/smc/trendlines/*`
- `lib/smc/strategy/trendline/third_touch_strategy.rb`

### Sprint 5 — State machine + registry (2 days)
- `lib/smc/state_machine.rb`
- `lib/smc/context.rb`
- `lib/smc/playbook_registry.rb`
- Refactor `backtester.rb` + `mtf_engine.rb`

### Sprint 6 — PB4, PB5, PB8 complete (2–3 days)
- Remaining strategy files
- 🔧 `mtf_confluence.rb` → full PB8

### Sprint 7 — Risk + analytics + replay (3–4 days)
- Phase 4 + Phase 5 core files
- `exe/smc-replay`

---

## File Inventory Summary

| Category | Exists | Partial | Missing | Total planned |
|----------|--------|---------|---------|---------------|
| Core (`lib/smc/`) | 10 | 6 | 4 | 20 |
| Detectors (subdirs) | 0 | 2 | 18 | 20 |
| Strategies | 2 | 2 | 10 | 14 |
| Execution / risk | 1 | 1 | 4 | 6 |
| Backtesting / reports | 1 | 0 | 8 | 9 |
| Adapters | 0 | 1 | 4 | 5 |
| CLI (`exe/`) | 3 | 0 | 4 | 7 |
| Specs | 1 | 0 | 20+ | 21+ |
| Config / docs | 0 | 1 | 3 | 4 |

---

## Progress Tracker (update as you ship)

| Phase | Description | Status | Target |
|-------|-------------|--------|--------|
| 0 | Foundation | ❌ | |
| 1 | Core detectors | ⚠️ ~40% | |
| 2 | State machine | ❌ | |
| 3 | PB1–PB8 strategies | ⚠️ ~15% | |
| 4 | Risk / trade mgmt | ⚠️ ~40% | |
| 5 | Analytics | ❌ | |
| 6 | Adapters / CLI | ⚠️ ~25% | |
| 7 | Test infrastructure | ⚠️ ~15% | |
| 8 | Advanced ICT | ❌ | |
| 9 | YAML DSL | ❌ | deferred |

**Overall KB alignment:** ~28% → target 90%+ after Phases 0–7.

---

## Notes

1. **Do not** expand `smc-playbook.html` until Ruby engines match — HTML is ahead of code.
2. **CHoCH definition** must be frozen in `market_structure.rb` and documented in `docs/architecture.md` once written.
3. **CoinDCX** stays adapter-only; no broker logic in detectors or strategies.
4. Write **failing specs first** for each new detector/strategy (TDD per workspace rules).
