# R1.1c — S00 ScalpFvgMicro: Runner + Protection (Unified Exit Logic)

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.1b-purity (commit `45e486f`) &nbsp;|&nbsp; **Working tree before commit.**

R1.1c is the exit-side counterpart to the R1.1b/diag/purity entry work. The May April-CSV diagnostic identified the failure mode as "exit, not entry" — winning trades reversed before any take-profit captured the favorable excursion (no protection), and runs that could have extended to a liquidity target were cut at fixed 1:2 (no runner). R1.1c implements the unified two-half model from `R1_1c_Runner_Protection_SPEC.md` + `ScalpFvgMicro_SPEC §6–§7`: one trigger at `+S00_ProtectTriggerR × R`, two simultaneous events (insurance close, runner stop → breakeven), then ATR trailing on the runner half. S00 stays paper-isolated; no entry, FVG-detection, filter, invalidation, expiry, structural-stop, or target logic is touched.

---

## 1. What was built (per spec §1 → §2)

| Item | Path | Notes |
|---|---|---|
| 4 new inputs + 1 promoted + 1 renamed | `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | `S00_RunnerSplitPct = 50.0`, `S00_ProtectTriggerR = 1.0`, `S00_RunnerTrailAtrMult = 2.0`. Promoted `#define S00_ATR_PERIOD 14` → `input int S00_AtrPeriod = 14` (single source for the strength filter AND the runner trail). Renamed `S00_MaxTradeBars` → `S00_MaxTradeDurationBars` to match the SPEC wording. All in the existing `── S00 FVG Scalp ──` group; clean R1.1a-labels-style display comments. |
| Detector / filter rename ripple | `Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh` + `S00_FvgQualityFilter.mqh` | Mechanical replace `S00_ATR_PERIOD` → `S00_AtrPeriod` (3 sites: 1 `iATR` call + 2 comment references). Zero logic change. |
| Two-half trade struct + enum | `S00_EntryLogic.mqh` (`S00PaperTrade` + `ENUM_S00_TRADE_EXIT_REASON`) | Added 8 fields to `S00PaperTrade`: `r_price`, `protect_trigger_level`, `trigger_fired`, `trigger_bar_time`, `insurance_exit_*` (3), `runner_virtual_stop`, `runner_open`. Added 2 enum members: `S00_EXIT_TRAIL = 4`, `S00_EXIT_BREAKEVEN = 5`. |
| ATR handle + cache | `S00_EntryLogic.mqh` | `m_runner_atr_handle` lazy-allocated against `(S_M5, S00_AtrPeriod)`; `ReadRunnerAtr(bar_time)` caches the value per bar to avoid redundant `CopyBuffer` calls. Closed-bar read (`start=1`). |
| Trigger event | `S00_EntryLogic.mqh::FireTriggerEvent(bar)` | Sets `trigger_fired = true`, records `trigger_bar_time`, captures the insurance half's exit at `protect_trigger_level`, moves `runner_virtual_stop` to `entry_price` (breakeven). Runner exit eval is deferred to the NEXT bar (skip-on-trigger-bar rule). |
| Virtual-stop update | `S00_EntryLogic.mqh::UpdateRunnerVirtualStop(bar)` | After trigger: `vs = max(vs, close − mult × ATR, breakeven)` for bullish (and `min` mirror for bearish). Ratchets monotonically toward the favorable direction; the breakeven floor enforces the spec's "trade as a whole cannot become net negative". |
| Unified per-bar evaluator | `S00_EntryLogic.mqh::RunExitEvaluation(bar)` | Single entry point handling both pre-trigger and post-trigger phases, with the spec's pessimistic ordering. Returns true if the trade fully closed. |
| Close paths | `S00_EntryLogic.mqh::CloseFullTrade(...)` / `CloseRunnerOnly(...)` | Replaces the old `CloseActiveTrade`. `CloseFullTrade` mirrors insurance fields onto the runner exit so a no-trigger trade reads cleanly (single price); `CloseRunnerOnly` keeps the previously-captured insurance half intact. Both write one CSV row per trade. |
| CSV header + row | `S00_EntryLogic.mqh::WriteTradesHeader` + `AppendTradeRow` | Added 2 new exit-reason labels (`TRAIL`, `BREAKEVEN`) and 7 R1.1c columns. CSV grew 20 → 27 columns. Details in §4. |
| OnTick wiring | unchanged | `g_s00_entry_logic.EvaluateOnNewBar(g_market_context)` is the single OnTick hook from R1.1b; no change. |
| `EA_VERSION_TAG` | `Core/FalconConstants.mqh:10` | `R1_1b_purity` → `R1_1c`. |

**Net lines:** ~+260 in `S00_EntryLogic.mqh`; ~+5 in `S00_ScalpFvgMicroInputs.mqh`; minimal ripple in detector / filter; 1-line bump in `FalconConstants.mqh`.

---

## 2. Unified exit evaluator — `RunExitEvaluation(bar)`

Called from two sites:
1. `UpdateOpenTradeOnBar(bar)` — once per closed M5 bar (step 2 of `EvaluateOnNewBar`), after `MFE/MAE` refresh + `elapsed_bars++`.
2. The entry-bar same-bar fill check inside step 3e — *after* `m_active_trade.open = true` and the R1.1c fields are initialised; `elapsed_bars` stays 0 here so the entry bar itself doesn't count toward `S00_MaxTradeDurationBars`.

### 2.1 Pre-trigger phase (spec §1.3–§1.5 + §1.8)

Order (short-circuit, first match wins) — **pessimistic**:

1. **Structural stop hit.** `bull ? bar.low ≤ struct_sl : bar.high ≥ struct_sl`. Closes the full trade at `struct_sl` with reason `STOP`. Pessimistic edge case §1.8: if the bar contains both the structural stop AND the trigger level, the structural stop wins → full loss, trigger does NOT fire. Implemented by checking structural stop first.
2. **Trigger hit** (`bull ? bar.high ≥ trig_level : bar.low ≤ trig_level`). Fires `FireTriggerEvent(bar)`. Returns false (runner stays open). Per spec, runner exit eval is suppressed for the rest of THIS bar.
3. **Target hit alone.** `bull ? bar.high ≥ target : bar.low ≤ target`. Closes the full trade at `target` with reason `TARGET`. (Pre-trigger means trigger didn't fire on this bar — target-without-trigger is unusual but possible if the bar overshoots the target without holding above trigger; the SPEC's pessimistic chain places target after trigger in the ordering, so this branch fires only when the trigger didn't.)
4. **Timeout.** `elapsed_bars ≥ S00_MaxTradeDurationBars` (only reachable on non-entry bars where `elapsed_bars++` ran). Closes at `bar.close` with reason `TIMEOUT`.

### 2.2 Post-trigger phase (spec §1.6 + §1.7 + §1.8)

Skips the trigger bar itself: `if(bar.time == trigger_bar_time) return false;`. Otherwise:

1. **Update virtual stop.** `UpdateRunnerVirtualStop(bar)`: refresh ATR for `bar.time`, compute `trail = close ∓ mult × ATR`, ratchet `runner_virtual_stop = max(vs, trail, breakeven)` for bull (mirror for bear). If ATR isn't warm yet (`atr ≤ 0`), the stop stays where it is.
2. **Virtual stop hit** (`bull ? bar.low ≤ vs : bar.high ≥ vs`). Closes the runner at `vs`. Reason: `TRAIL` if `vs` has ratcheted strictly above (bull) / below (bear) entry, else `BREAKEVEN`. This gives the analysis CSV a clean way to count "stopped at breakeven" vs "stopped after a profitable trail."
3. **Target hit** (`bull ? bar.high ≥ target : bar.low ≤ target`). Closes the runner at `target` with reason `TARGET`. Pessimistic edge §1.8.4: if the bar contains both the virtual stop and the target, the virtual stop wins.
4. **Timeout.** Same `elapsed_bars` rule; closes at `bar.close` with reason `TIMEOUT`.

### 2.3 Trigger-bar handling

The trigger fires on bar T. On bar T:
- Pre-trigger eval: structural stop check (no hit), trigger check (hit) → `FireTriggerEvent(bar T)`, return false.
- Runner exit eval is NOT executed for the rest of bar T (the `if(bar.time == trigger_bar_time) return false;` at the top of the post-trigger branch guarantees this).
- The CSV row for the trade is not written yet — runner is still open.

On bar T+1 (first eligible runner exit bar):
- `is_trigger_bar = (T == T+1) = false` → runner eval proceeds.
- `UpdateRunnerVirtualStop(bar T+1)`: ATR + trail compute, virtual stop may ratchet up.
- Stop / target / timeout checks against bar T+1's range.

This eliminates the "ordering inside one bar" ambiguity that would otherwise let the runner be unfairly stopped on the same bar its breakeven stop was set.

### 2.4 Lookahead

All eval input is closed-bar:
- `bar` parameter is `bar1` from `GetCandleSnapshot(PERIOD_M5, 1, bar1)` at the top of `EvaluateOnNewBar` — closed.
- `ReadRunnerAtr` uses `CopyBuffer(handle, 0, 1, 1)` — `start=1` is the closed bar.

No new `iClose`/`iHigh`/`iLow`/`iOpen`/`CopyRates`/`SymbolInfoTick`. Total read-site count in `Strategies/S00_ScalpFvgMicro/*.mqh` after R1.1c: same 9 pre-existing sites (Detector ×3 + TradePlan ×6 + EntryLogic ×1) + 1 new closed-bar `CopyBuffer` for the runner ATR = 10 read sites, all closed-bar.

---

## 3. Paper isolation — what R1.1c did NOT touch

R1.1c reads zero of the following legacy contracts/globals:
- `g_report_writer.*`
- `g_broker_entry_bridge.*`
- `g_shadow_executor.*`
- `g_risk_lifecycle_processor.*`
- `g_risk_foundation.*`
- `g_risk_tm_architecture.*`

Zero `OrderSend` / `BrokerModify` / `TRADE_ACTION_SLTP` / `RuntimeSLChanged` anywhere. Every stop movement is on `m_active_trade.runner_virtual_stop` — a local double on `CS00EntryLogic`'s `S00PaperTrade` struct. The structural stop on the broker side is untouched (still the original `plan.stop_loss`); only the *virtual* stop the strategy uses for exit decisions moves.

Therefore: the legacy FixedLot April reproducer (`585.17 / 1104.89 / 157.49`) is unaffected — those numbers come from the legacy chain that R1.1c never reaches.

Per spec §13: the "zero behavior change" rule does NOT apply to R1.1c. The S00 trades themselves *will* change — that's the whole point. Compare against R1.1b-purity baseline, not against R0.8b.

---

## 4. Trade CSV — `S00_Trades_Diagnostics.csv` (now 27 columns)

The 20 columns from R1.1b-diag are kept verbatim — analysis pipelines written against the post-purity CSV still work. R1.1c **appends** 7 columns:

| Column | Meaning |
|---|---|
| `RPoints` | `r_price / point` — the 1R distance in points (≡ structural stop distance) |
| `TriggerFired` | `YES` if the +1R trigger event ran during the trade's life, else `NO` |
| `RunnerExitPrice` | duplicate of `t.exit_price` for explicit naming (the existing `ResultPoints` column already encodes the runner's signed result; the price was missing from the CSV) |
| `InsuranceExitTime` | bar time at which the insurance half closed (= trigger bar time when fired; mirrors runner exit time when not fired) |
| `InsuranceExitPrice` | `protect_trigger_level` when fired; mirrors runner exit price when not fired |
| `InsuranceResultPoints` | signed points: `(insurance_exit - entry)/point` for bull (mirror for bear). Equals `≈ ProtectTriggerR × RPoints` when the trigger fired cleanly; equals the runner's points when the trigger did not fire (no-trigger case = both halves exit together). |
| `NetResultPoints` | size-weighted combined result: `split × insurance_points + (1−split) × runner_points`, where `split = S00_RunnerSplitPct / 100`. This is the "net trade points" for size-weighted analysis. When the trigger doesn't fire, both halves share the price so this collapses to the single-leg result. |

`ExitReason` semantics also extended:
- Pre-trigger close → existing labels (`STOP`, `TARGET`, `TIMEOUT`).
- Post-trigger runner close → new labels (`TRAIL`, `BREAKEVEN`, `TARGET`, `TIMEOUT`).
- `STOP` continues to mean "pre-trigger structural-stop full loss" — a `STOP` row always has `TriggerFired = NO`.

The spec §11 "runner breakdown" report is computable directly from the CSV: group by trade, filter `TriggerFired = YES`, group runner rows by `ExitReason`, count percentages, compute avg `R = ResultPoints / RPoints`. No separate file needed for R1.1c.

---

## 5. Edge cases — implementation map

| Spec §1.8 case | Implementation |
|---|---|
| Structural stop hit before trigger | `RunExitEvaluation` pre-trigger branch, step 1 (struct stop wins). |
| Trigger + structural stop on same bar | Pre-trigger branch checks struct stop FIRST → pessimistic full loss, trigger does NOT fire. |
| Runner exit eval skipped on trigger bar | `if(bar.time == trigger_bar_time) return false;` at the top of the post-trigger branch. |
| Virtual stop + target on same bar (post-trigger) | Post-trigger branch checks `hit_vstop` BEFORE `hit_target` → pessimistic stop wins. |
| Timeout before trigger | Pre-trigger branch, step 4 → `CloseFullTrade(..., TIMEOUT)`. |
| Invalidation / expiry of FVG | Untouched (step 3a / 3b of the per-FVG loop in `EvaluateOnNewBar`); R1.1c only governs what happens after entry. |
| One trade at a time | Enforced upstream in `EvaluateOnNewBar` step 3d/3e (existing R1.1b logic — `if(m_active_trade.open) continue;` and `BUSY` drop reason). R1.1c does not relax this. |

---

## 6. What did NOT happen (per spec §3 + §8)

- No change to FVG detection, the four quality filters (SIZE/MAXSIZE/ATR/TREND), confirmation (body + purity), revisit, invalidation, expiry, structural stop, or target.
- No change to the 1:2 trade-plan gate.
- No `OrderSend`, no `BrokerModify`, no `TRADE_ACTION_SLTP`, no `RuntimeSLChanged`.
- No `Apply*` chain reordering (the chain is in `Risk/`, not even called from S00).
- No new lookahead surface — same 9 read sites + 1 new closed-bar `CopyBuffer`.
- No tuning. The four defaults (`50.0 / 1.0 / 2.0 / 14`) are starting points per spec §2; tuning is a separate three-period (March + April + May) test the operator runs next.

---

## 7. Touch surface (files modified, line-level)

| File | Lines | Why |
|---|---|---|
| `Core/FalconConstants.mqh` | +1/−1 | `EA_VERSION_TAG` bump |
| `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | rewrite (+5 net) | Promote `S00_AtrPeriod`, rename `S00_MaxTradeDurationBars`, add 3 R1.1c inputs, refresh header comment |
| `Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh` | 3 site replaces | `S00_ATR_PERIOD` → `S00_AtrPeriod` |
| `Strategies/S00_ScalpFvgMicro/S00_FvgQualityFilter.mqh` | 1 comment replace | `S00_ATR_PERIOD` → `S00_AtrPeriod` |
| `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` | ~+260 net | R1.1c struct + enum extensions, ATR handle + cache, `FireTriggerEvent` / `UpdateRunnerVirtualStop` / `RunExitEvaluation` / `CloseFullTrade` / `CloseRunnerOnly`, refactored `UpdateOpenTradeOnBar` to delegate, step 3e initialises new fields + calls `RunExitEvaluation` for same-bar fill, CSV header + row extended |
| `Docs/Ideas_Backlog.md` | +1 item (#53) | Structural trailing as a data-driven alternative to ATR trailing |
| `Docs/ReviewNotes/R1_1c_Review_Notes.md` | new | this file |
| `Docs/Specs/JA_FalconCore_R1_1c_SPEC.md` | new (moved from root) | per convention; will be staged in the same commit |

What R1.1c did NOT touch:
- `Risk/*`, `Reporting/*`, `Execution/*`, `Router/*`, `Evidence/*`, `TradeManagement/*`.
- `Core/*` other than `EA_VERSION_TAG`.
- The 12-step `Apply*` chain.
- Any pre-refactor input.
- Any existing report writer or CSV path.

---

## 8. Acceptance status (per spec §7)

| Criterion | Status |
|---|---|
| Two-half split at entry (`S00_RunnerSplitPct`) | ✓ `r_price` set, virtual stop initialised at structural stop pre-trigger |
| `+1R` trigger on closed bars only — closes insurance, moves runner to BE | ✓ `RunExitEvaluation` pre-trigger branch + `FireTriggerEvent` |
| Runner ATR-trailing virtual stop, ratchets monotonically, breakeven floor | ✓ `UpdateRunnerVirtualStop` |
| Final runner exit by target / trail / timeout | ✓ post-trigger branch + new enum labels |
| Pessimistic rules (struct+trigger same bar; vstop+target same bar; skip runner eval on trigger bar) | ✓ §2.3 + §5 |
| 4 inputs added (3 new + 1 promoted) with clean labels in S00 group | ✓ `S00_ScalpFvgMicroInputs.mqh` |
| No change to entry / FVG / filters / invalidation / expiry / struct stop / target | ✓ §6 + §7 |
| No `OrderSend` / `BrokerModify` / `TRADE_ACTION_SLTP` / `RuntimeSLChanged` | ✓ §3 |
| No lookahead | ✓ §2.4 |
| Trade CSV separates insurance / runner / net | ✓ §4 |
| `EA_VERSION_TAG = R1_1c` | ✓ |
| Compile `0 errors, 0 warnings` | ⏳ MetaEditor F7 by user |
| Three-month test (March + April + May) | ⏳ user backtest + analysis |
| Review Notes + Backlog updated | ✓ |

---

## 9. After R1.1c — next steps

1. **Compile** (MetaEditor F7). If anything breaks, the most likely culprit is the `S00_MaxTradeBars` → `S00_MaxTradeDurationBars` rename — `grep -nE "S00_MaxTradeBars\\b"` should return zero hits across the project tree.
2. **Three-month backtest** (March + April + May 2026, S00 only). Diagnostic CSV must include the 7 new R1.1c columns.
3. **Runner breakdown analysis** (spec §4): from the trigger-fired subset, count exit reasons (`TARGET / TRAIL / BREAKEVEN / TIMEOUT`) and the average runner `R = ResultPoints / RPoints`. The success criterion is an enlarged winner/loser margin compared to the R1.1b-purity baseline AND positive net after costs across all three months.
4. **Tune the four defaults** by test: `S00_RunnerSplitPct`, `S00_ProtectTriggerR`, `S00_RunnerTrailAtrMult`, `S00_AtrPeriod`. Per spec §2 + §13: tune over the three-month window jointly — never from a single month.
5. If runners die at breakeven disproportionately: consider switching to structural trailing per Backlog #53 (already logged), or relaxing `S00_RunnerTrailAtrMult`.
6. **R1.2** is the next phase — move S00 from paper-isolated to real Strategy Tester execution to measure broker costs against the paper baseline. The two-half CSV from R1.1c is what makes that comparison meaningful.

---

*End of R1.1c review notes. The exit logic is unified — one trigger, two events, then the runner trails on ATR. No legacy chain touched, no broker order sent. The two-half CSV is in place; the data now decides.*
