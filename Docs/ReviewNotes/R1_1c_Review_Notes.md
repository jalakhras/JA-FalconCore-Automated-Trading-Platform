# R1.1c — S00 ScalpFvgMicro: Protection (Fixed-Threshold Breakeven)

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.1c (commit `4067f6c`, now rolled back) &nbsp;|&nbsp; **Final form:** R1.1c-fix.

R1.1c originally attempted a half-cut-at-+1R + runner-ATR-trail mechanism. The three-month backtest exposed two opposing failures (see §1). **R1.1c-fix rips the runner out** and replaces it with the simplest possible protection: when unrealised profit reaches a *fixed* `S00_BreakevenTrigger` points, the stop moves to entry. No split. No partial close. No trailing. One knob, one effect. That is the form this file documents.

> A self-contained §0 below summarises why the R1.1c attempt was rolled back, so the file remains a complete record. The active spec is `Docs/Specs/JA_FalconCore_R1_1c_fix_SPEC.md`; the rolled-back design is documented in `Docs/Specs/JA_FalconCore_R1_1c_SPEC.md` and remains useful as historical context for the data-driven decision recorded in `Ideas_Backlog.md` #53.

---

## 0. Why R1.1c was rolled back

The R1.1c three-month paper run took the total from +5,641 points (R1.1b-purity baseline) to **−1,083** points. The data revealed two opposing failures:

1. **Half-cut clipped large winners.** S00 lives on the rare large winner (the three-month mean winner was ~4,250 points). Closing half of every trade at +1R systematically capped those winners. A trade that should have been +5,150 came in at +3,370.

2. **1R protection didn't fire when it mattered.** The breakeven trigger was tied to the structural stop's distance (R = |entry − stop_loss|). When R was large (wide stops on volatile setups), trades could reach a meaningful unrealised profit (e.g. +5,307 points) and reverse all the way back without ever passing 1R — so the protection never armed. A trade that printed +5,307 then collapsed to −5,768 went unprotected.

Both failures came from the SAME design choice: tying both the cut and the protection to R. A simulation pass on the same March + April + May data showed that a **fixed-points** breakeven threshold (no cut, no trailing) makes the three months profitable together. Thresholds in the 500–1,000 range all worked; ~700–800 was the cluster centre with no overfitting to any single month.

R1.1c-fix implements the simpler design. The R1.1c half-cut and ATR-trail mechanisms are deleted, not preserved as toggles — they failed on the data and the spec is explicit that complexity is added back later, only by test (Ideas_Backlog #54 / #55 / #56).

---

## 1. What was built (per `JA_FalconCore_R1_1c_fix_SPEC.md` §1 → §2)

| Item | Path | Notes |
|---|---|---|
| New input + 3 removed | `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | Added `S00_BreakevenTrigger = 800.0` ("Profit in points that moves stop to entry"). Removed `S00_RunnerSplitPct`, `S00_ProtectTriggerR`, `S00_RunnerTrailAtrMult`. Kept `S00_AtrPeriod` (still feeds the R1.1a strength filter) and `S00_MaxTradeDurationBars` (still gates trade lifetime). All in the existing `── S00 FVG Scalp ──` group with R1.1a-labels-style display comments. |
| Struct shrunk | `S00_EntryLogic.mqh` (`S00PaperTrade`) | Removed 8 R1.1c fields (`r_price`, `protect_trigger_level`, `trigger_fired`, `trigger_bar_time`, the 3 `insurance_exit_*`, `runner_virtual_stop`, `runner_open`). Added 2 fields: `breakeven_armed`, `breakeven_arm_bar_time`. Net struct delta: −6 fields. |
| Enum reverted | `S00_EntryLogic.mqh` (`ENUM_S00_TRADE_EXIT_REASON`) | Removed `S00_EXIT_TRAIL = 4` and `S00_EXIT_BREAKEVEN = 5`. Back to the R1.1b-purity set: `NONE` / `TARGET` / `STOP` / `TIMEOUT`. `STOP` now covers both the pre-arm structural stop and the post-arm BE stop — the `BreakevenArmed` CSV column tells the analyst which one fired. |
| Helpers removed | `S00_EntryLogic.mqh` | Deleted: `EnsureRunnerAtrHandle`, `ReadRunnerAtr`, `FireTriggerEvent`, `UpdateRunnerVirtualStop`, `CloseFullTrade`, `CloseRunnerOnly`. Restored: a single `CloseActiveTrade(exit_time, exit_price, reason)`. The `m_runner_atr_handle` / cache fields on the class are gone. |
| `RunExitEvaluation` rewritten | `S00_EntryLogic.mqh` | Now a single-phase per-bar evaluator. Pessimistic short-circuit ordering: stop → target → arm BE → timeout. Details in §2. |
| Step 3e simplified | `S00_EntryLogic.mqh` | Removed the R1.1c init block (`r_price`, `protect_trigger_level`, etc.). Added the two BE init fields. Same-bar fill check still delegates to `RunExitEvaluation(bar1)`. |
| CSV simplified | `S00_EntryLogic.mqh` (header + row) | Removed the 7 R1.1c columns (`RPoints`, `TriggerFired`, `RunnerExitPrice`, `InsuranceExitTime`, `InsuranceExitPrice`, `InsuranceResultPoints`, `NetResultPoints`). Added 1 column: `BreakevenArmed` (`YES`/`NO`). Header now has 21 columns (20 R1.1b-diag + 1 R1.1c-fix). |
| Constructor cleanup | `S00_EntryLogic.mqh` | Dropped the R1.1c ATR-handle init. Body shrinks back toward the R1.1b-purity shape. |
| `EA_VERSION_TAG` | `Core/FalconConstants.mqh:10` | `R1_1c` → `R1_1c_fix`. |

**Net file delta:** `S00_EntryLogic.mqh` shrinks 822 → 636 lines (the R1.1c additions, ~+186, fully removed). `S00_ScalpFvgMicroInputs.mqh` rewritten with one new input + three removed.

---

## 2. The exit evaluator — `RunExitEvaluation(bar)`

Called from two sites (unchanged from R1.1c):
1. `UpdateOpenTradeOnBar(bar)` — once per closed M5 bar (step 2 of `EvaluateOnNewBar`), after `MFE/MAE` refresh + `elapsed_bars++`.
2. The entry-bar same-bar fill check inside step 3e — *after* `m_active_trade.open = true` and the BE init fields; `elapsed_bars` stays 0 here so the entry bar itself doesn't count toward `S00_MaxTradeDurationBars`.

### 2.1 Order (short-circuit, first match wins)

1. **Stop hit** (`bull ? bar.low ≤ stop_loss : bar.high ≥ stop_loss`). Closes at `stop_loss` with reason `STOP`. The `stop_loss` field carries the **current effective stop**: structural pre-arm, entry post-arm. So the same check handles both forms. The `BreakevenArmed` CSV column tells the analyst which form fired:
   - `ExitReason=STOP, BreakevenArmed=NO` → structural stop (full loss).
   - `ExitReason=STOP, BreakevenArmed=YES` → BE stop (flat result).
2. **Target hit** (`bull ? bar.high ≥ target : bar.low ≤ target`). Closes at `target` with reason `TARGET`. Pessimistic same-bar rule: stop has priority over target (step 1 already ran).
3. **Arm BE** (`!breakeven_armed && hit_trigger`). `trigger_price = entry ± S00_BreakevenTrigger × point`. `hit_trigger = bull ? bar.high ≥ trigger_price : bar.low ≤ trigger_price`. If hit, set `breakeven_armed = true`, record `breakeven_arm_bar_time`, mutate `stop_loss` to `entry_price`. **No exit on this bar** — the new BE stop applies on subsequent bars only (matches the spec wording "بعدها: إن انعكس السعر، تُغلَق عند نقطة الدخول"). The bar that arms BE gets a pass on the new stop.
4. **Timeout** (`elapsed_bars ≥ S00_MaxTradeDurationBars`). Closes at `bar.close` with reason `TIMEOUT`. Counts from entry — armed or not.

### 2.2 Pessimistic edge case — same-bar structural-stop + BE-trigger

If a bar's range covers both the original structural stop AND the BE trigger price, the structural stop wins (step 1 runs first, returns true). The BE never arms. This matches the R1.1c pessimistic rule and the spirit of the spec: same-bar order is unknowable, so favour the trader's downside.

### 2.3 Pessimistic edge case — same-bar BE-stop + target (post-arm)

Once BE has armed, `stop_loss == entry_price`. If a subsequent bar's range covers both `entry_price` (going against the trade) AND `target`, the stop check runs first → close at entry, flat result. The trade doesn't capture the favourable move on that same bar. Pessimistic, matches the trader-safe priority.

### 2.4 Same-bar BE arming + reversal to entry — design choice documented

If a single bar's range goes through the trigger price (favorable) AND back through the entry price (reversal), the arm-check is INTENTIONALLY ordered AFTER the stop check at the top of the evaluator. So:
- Top of evaluator: `hit_stop` checks the pre-arm structural stop (still in `stop_loss`). bar.low > structural_stop → no hit.
- Step 2: target check.
- Step 3: BE arms. `stop_loss` mutates to entry.
- Bar processing ends — the new BE stop is **not** re-checked against this bar's range.

The next bar is the first BE-stop-eligible bar. This matches the spec's "بعدها" ("afterwards") wording and avoids double-evaluating the arming bar.

### 2.5 Lookahead

Read sites in `Strategies/S00_ScalpFvgMicro/*.mqh` after R1.1c-fix:

| File | Site | Closed-bar guarantee |
|---|---|---|
| `S00_FvgDetector.mqh:74` | `CopyBuffer(m_atr_handle, 0, 1, 1, buf)` | `start=1` (closed ATR bar). Unchanged since R1.1a. |
| `S00_FvgDetector.mqh:82` | `CopyBuffer(m_ma_handle, 0, 1, 1, buf)` | `start=1` (closed MA bar). Unchanged. |
| `S00_FvgDetector.mqh:94` | `GetCandleSnapshot(PERIOD_M5, shift, snap)` | Inside `ReadClosedM5`; `shift < 1` returns false. Unchanged. |
| `S00_TradePlan.mqh:55–57` | swing-high scan (`k-1`, `k`, `k+1` with `k ≥ 2`) | All shifts ≥ 1. Unchanged. |
| `S00_TradePlan.mqh:79–81` | swing-low scan, mirror | Unchanged. |
| `S00_EntryLogic.mqh:~426` | `GetCandleSnapshot(PERIOD_M5, 1, bar1)` | `shift=1` (most recent closed). Unchanged. |

**9 sites total** — same as R1.1b-purity. The R1.1c runner ATR handle (which added a 10th `CopyBuffer` site at `S00_EntryLogic.mqh`) is gone. Zero `iClose`/`iHigh`/`iLow`/`iOpen`/`CopyRates`/`SymbolInfoTick`. All closed-bar.

---

## 3. Paper isolation — what R1.1c-fix did NOT touch

R1.1c-fix reads zero of: `g_report_writer`, `g_broker_entry_bridge`, `g_shadow_executor`, `g_risk_lifecycle_processor`, `g_risk_foundation`, `g_risk_tm_architecture`. Zero `OrderSend` / `BrokerModify` / `TRADE_ACTION_SLTP` / `RuntimeSLChanged`. The "stop movement" when BE arms is a write to `m_active_trade.stop_loss` (a `double` field on the `S00PaperTrade` struct) — paper-only. No broker order ever existed for the trade.

Legacy FixedLot April `585.17 / 1104.89 / 157.49` is untouched (the legacy chain that produces those numbers is not reached by S00 in any form).

---

## 4. Trade CSV — `S00_Trades_Diagnostics.csv` (now 21 columns)

The 20 R1.1b-diag columns are preserved verbatim. R1.1c-fix adds **1 column**:

| Column | Meaning |
|---|---|
| `BreakevenArmed` | `YES` if the BE protection fired during the trade's life, else `NO`. |

R1.1c's 7 columns (`RPoints`, `TriggerFired`, `RunnerExitPrice`, `InsuranceExitTime`, `InsuranceExitPrice`, `InsuranceResultPoints`, `NetResultPoints`) are removed. Existing analysis pipelines written against the R1.1b-diag shape still work; R1.1c-specific pipelines need to be re-pointed at the simpler shape.

**Analysis rules with the new column:**
- `ExitReason=STOP, BreakevenArmed=NO` → structural-stop loss (full R-loss).
- `ExitReason=STOP, BreakevenArmed=YES` → BE-stop exit (≈ flat result; `ResultPoints` should be near 0).
- `ExitReason=TARGET, BreakevenArmed=*` → target hit. BE may or may not have armed earlier; doesn't change the outcome.
- `ExitReason=TIMEOUT, BreakevenArmed=*` → forced close at `bar.close`. If `BreakevenArmed=YES`, the trade exited at whatever the close happened to be (could be slightly above entry, at entry, or somewhere along the way).

---

## 5. Acceptance status (per `JA_FalconCore_R1_1c_fix_SPEC.md` §7)

| Criterion | Status |
|---|---|
| R1.1c runner / 1R protection mechanism removed | ✓ §1 |
| Protection = `S00_BreakevenTrigger` fixed-points threshold | ✓ §2 |
| No half-cut, no partial close, no trailing | ✓ no `Split`/`Trail`/`Insurance` code paths remain |
| No change to FVG detection, filters, entry, purity, structural stop, target | ✓ files outside `S00_EntryLogic.mqh` + the inputs file are untouched (except detector / filter rename ripple from R1.1c, which is also unchanged here) |
| `S00_BreakevenTrigger` input added, clean label, S00 group | ✓ |
| No lookahead | ✓ §2.5 |
| Legacy code unaffected | ✓ §3 |
| `EA_VERSION_TAG = R1_1c_fix` | ✓ |
| Review notes + Backlog updated | ✓ this file + #53 strike-through, #54-56 added |
| Compile `0 errors, 0 warnings` | ⏳ MetaEditor F7 by user |
| Three-month test (March → today) shows all months profitable | ⏳ user backtest |

---

## 6. Touch surface (R1.1c-fix only — relative to R1.1c HEAD `4067f6c`)

| File | Change |
|---|---|
| `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | Rewrite: −3 runner inputs, +1 BE input, header note updated |
| `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` | −186 net lines (runner mechanism rip-out, simpler evaluator, simpler CSV) |
| `Core/FalconConstants.mqh` | `EA_VERSION_TAG` bump |
| `Docs/Ideas_Backlog.md` | #53 struck-through + superseded note; #54, #55, #56 added |
| `Docs/ReviewNotes/R1_1c_Review_Notes.md` | this file (full rewrite) |
| `Docs/Specs/JA_FalconCore_R1_1c_fix_SPEC.md` | added (moved from root) |

Untouched: `S00_FvgDetector.mqh`, `S00_FvgQualityFilter.mqh`, `S00_TradePlan.mqh`, `JA_FalconCore_Automated_Trading_Platform.mq5`, anything under `Risk/`, `Reporting/`, `Execution/`, `Router/`, `Core/` (other than the EA_VERSION_TAG line).

---

## 7. What did NOT happen (per spec §3 + §8)

- No half-cut, no partial close, no trailing.
- No protection tied to 1R or any R-multiple. The trigger is pure fixed points.
- No change to FVG detection, the four quality filters, confirmation (body + purity), revisit, invalidation, expiry, structural stop, or target.
- No `OrderSend` / `BrokerModify` / `TRADE_ACTION_SLTP` / `RuntimeSLChanged`.
- No lookahead — 9 read sites, all closed-bar.
- No new input from a single-month tuning. `S00_BreakevenTrigger = 800` is from a three-month simulation; the spec note's range of 500–1,000 (all working) was preserved by picking the middle (not the top, to avoid overfitting).
- No Ideas_Backlog item executed beyond R1.1c-fix's strict scope. Trailing-after-BE and partial-cut-at-high-threshold are logged (#54, #55) with the explicit rule (#56) that each is tested alone on top of this baseline.

---

## 8. Next steps

1. **Compile** (MetaEditor F7). Most likely failure points if any: a stale reference to `S00_ProtectTriggerR` / `S00_RunnerSplitPct` / `S00_RunnerTrailAtrMult` somewhere outside the S00 folder. `grep -nrE "S00_(ProtectTriggerR|RunnerSplitPct|RunnerTrailAtrMult|EXIT_TRAIL|EXIT_BREAKEVEN)\b"` should return zero hits in code files.
2. **Three-month backtest** (March 1 → today, S00 only). Diagnostic CSV must have the 21-column shape and the new `BreakevenArmed` flag populated.
3. **Analyze** the three months separately (March / April / May / June onwards). Expected per spec §4: all months profitable, total clearly positive (simulation ~+19,000 at 800 threshold).
4. **Tune** `S00_BreakevenTrigger` across the three-month window jointly — never from a single month. Range to consider: 500–1,000 per the simulation.
5. If the three-month baseline is confirmed: optionally add ONE enhancement at a time per Backlog #54 (trailing after BE) or #55 (small-fraction cut at a high threshold). Per #56, keep only if the total improves AND no single month regresses.
6. **R1.2** opens when the paper baseline is locked: move S00 from paper-isolated to real Strategy Tester execution to measure broker costs against the paper baseline.

---

*End of R1.1c review notes. The runner machine was a wrong turn; the data rejected it. R1.1c-fix is the simpler, baseline-correct protection: one fixed-points trigger, one stop move, one trade. The data tells us what — if anything — to add on top.*
