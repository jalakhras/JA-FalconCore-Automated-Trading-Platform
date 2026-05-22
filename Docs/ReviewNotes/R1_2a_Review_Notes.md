# R1.2a — Real-Execution Prep: Coexistence Gate + S00 Lot Sizing

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.1c-fix (commit `a0c4b6b`).

R1.2a is the **preparation** phase for moving S00 ScalpFvgMicro from paper-isolated to real broker execution. It builds the two pieces that real-execution wiring (R1.2b) needs already in place — without sending a single broker order yet:

1. A **coexistence gate** — one input, `S00_RealExecution` (default `false`). When `true`, the legacy `FVG_MICRO_RETEST` runtime/shadow pipeline does not run for that tester session. The gate is *built* in R1.2a but the input stays `false` everywhere in this phase, so the legacy strategy keeps producing the canonical `585.17 / 1104.89 / 157.49` FixedLot April baseline byte-for-byte.

2. **Lot-size plumbing on the S00 paper-trade record** — one input (`S00_LotSize`, default `0.01`), one struct field (`S00PaperTrade::lot_size`), one CSV column (`LotSize`). S00 still does not send any broker order. The lot size is computed at trade open and recorded in the trades CSV so the operator can audit the sized value *before* R1.2b wires the OrderSend.

Zero behavior change is the headline invariant: with `S00_RealExecution=false` the FixedLot April run is identical to R1.1c-fix, and the S00 paper trades for the same window are identical to R1.1c-fix *except* for the new `LotSize` column populated at `0.01` on every row.

> Active spec: `Docs/Specs/JA_FalconCore_R1_2a_SPEC.md` (moved into `Docs/Specs/` per the R0.9 convention).

---

## 1. What was built (per `JA_FalconCore_R1_2a_SPEC.md` §1 → §3)

| Item | Path | Notes |
|---|---|---|
| 2 new inputs | `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | `S00_RealExecution = false` ("Enable real broker execution for S00 (Tester only)") and `S00_LotSize = 0.01` ("Fixed lot size for S00 trades"). Both in the existing `── S00 FVG Scalp ──` group, ordered after `S00_BreakevenTrigger` and before `S00_DiagReport`. Display comments follow the R1.1a-labels rule (functional English, no phase tags). |
| Coexistence gate — OnInit | `JA_FalconCore_Automated_Trading_Platform.mq5` (`OnInit`, ~L5921–5932) | Both legacy-path init touches now guarded: `g_broker_entry_bridge.TryOpenFromShadowRecord(...)` is gated by `if(!S00_RealExecution && g_fvg_micro_tradeplan_stager.GetSnapshot().staged_to_shadow_executor)`, and the `g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord(...)` branch is gated by `if(!S00_RealExecution && g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord(close_record))`. An R1.2a comment block above the section documents the gate's purpose and the byte-identical baseline guarantee. |
| Coexistence gate — OnTick | `JA_FalconCore_Automated_Trading_Platform.mq5` (`OnTick`, ~L5989+) | Entire legacy block wrapped in `if(!S00_RealExecution) { ... }`. Block contents: `FalconRunFvgMicroRuntimeShadowPipeline`, the virtual-trailing call, `g_fvg_micro_lifecycle_simulator.Refresh`, the `ExtractClosedLifecycleRecord` branch with `RegisterClosedTrade` + `TryManagedCloseFromLifecycleRecord` + diagnostic snapshots, and the else-branch tick snapshot. Inner content indented one level; no logic moved. Comment block above describes the gate. |
| S00 paper-trade struct | `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` (`S00PaperTrade`) | Added `double lot_size;` (placed after `target`, before `fvg_formation_time` — kept near the price/size cluster). Field carries the size computed at open; consumed only by the CSV row in R1.2a. |
| Populate at trade open | `S00_EntryLogic.mqh` (step 3e) | Added `m_active_trade.lot_size = S00_LotSize;` adjacent to the existing `breakeven_armed = false;` initialisation. No conditional — fixed-mode sizing is the only mode in R1.2a (per spec §2.1). |
| CSV header | `S00_EntryLogic.mqh` (`WriteTradesHeader`) | Appended `LotSize` after the R1.1c-fix `BreakevenArmed` column. Header now has 22 columns (21 R1.1c-fix + 1 R1.2a). |
| CSV row | `S00_EntryLogic.mqh` (`AppendTradeRow`) | Appended `DoubleToString(t.lot_size, 2)` after the R1.1c-fix `BreakevenArmed` YES/NO ternary. Two-decimal format matches MQL5's standard lot display. |
| `EA_VERSION_TAG` | `Core/FalconConstants.mqh:10` | `R1_1c_fix` → `R1_2a`. |
| Spec relocation | `Docs/Specs/JA_FalconCore_R1_2a_SPEC.md` | Moved from repo root into `Docs/Specs/` per the R0.9 convention. |
| Three forward-looking items | `Docs/Ideas_Backlog.md` | Items #57 (multi-strategy magics + bridge generalization), #58 (legacy `FVG_MICRO_RETEST` removal — deferred until S00 proven + alternative baseline exists), #59 (percent-risk lot-sizing mode for S00). All three explicitly **not implemented now**, recorded per spec §6. |

**Net file delta:** `S00_EntryLogic.mqh` +5 lines (one struct field, one assignment, one CSV column header line, one CSV row append line, comment delta). `S00_ScalpFvgMicroInputs.mqh` +2 lines. Main `.mq5` adds ~10 lines of gate wrapping + ~12 lines of comment-block explanation across two touch sites. No file deletions.

---

## 2. The coexistence gate — what it does and what it doesn't

### 2.1 Gate choice — skip the legacy call sites

Two implementation options were on the table (spec §1.1):

- **(A) Skip-call wrapping** — wrap each legacy entry call site in `if(!S00_RealExecution) { ... }` so the call never fires when S00 is active.
- **(B) Force the legacy strategy switch off** — at OnInit, set `EnableStrategy_FvgMicroRetest = false` when `S00_RealExecution = true`.

R1.2a chose **(A)**. Two reasons:

1. **MQL5 `input` variables are immutable at runtime.** Option (B) would need a parallel runtime variable that shadows the input, which adds a second source of truth for the same on/off state. (A) keeps the legacy switch as its own user-visible input and adds an orthogonal R1.2a-level gate on top.
2. **(A) makes the gate visible at every call site.** A reader of `OnTick` sees the `if(!S00_RealExecution)` wrap immediately and understands that the legacy block does not run when S00 takes over. (B) would hide that choice behind an init-time mutation that's invisible at the call sites.

### 2.2 What the gate covers and what it deliberately doesn't

**Covered (gated by `!S00_RealExecution`):**
- `OnInit` — the `g_broker_entry_bridge.TryOpenFromShadowRecord(...)` retry call and the `ExtractClosedLifecycleRecord` close-handler at the bottom of the init sequence.
- `OnTick` — the entire legacy execution + diagnostic block: `FalconRunFvgMicroRuntimeShadowPipeline`, virtual-trailing refresh, lifecycle-simulator refresh, the `ExtractClosedLifecycleRecord` branch (with its `RegisterClosedTrade` + `TryManagedCloseFromLifecycleRecord` + diagnostic snapshots), and the else-branch tick-snapshot.

**Deliberately NOT gated:**
- `OnTradeTransaction` — purely observational. Reads transactions, filters by magic, updates broker telemetry counters. Safe to leave running because (a) it only fires when actual trades happen, and (b) in R1.2a there are no S00 broker trades to be confused with the legacy ones. R1.2b will need to revisit this when S00 starts emitting transactions of its own.
- `OnDeinit::FlushOpenLinksAtDeinit` — cleanup-only. Closes book-keeping for any open shadow records before unload. Already filtered by magic. Safe.

The mental model the gate establishes: **with `S00_RealExecution = true`, the legacy strategy does not *execute or diagnose* anything; observation and cleanup paths continue.** That's the right shape for a swap — the new strategy takes over the live path, the old strategy stops touching state.

### 2.3 Why "everything inside the legacy OnTick block" rather than just the bridge call

The OnTick legacy block has four distinct sub-pieces (execution wiring, lifecycle simulator, close handling, diagnostics). Gating only the execution call would leave the simulator + diagnostics running on stale state and could either (a) produce confusing reports that mix S00 and legacy, or (b) leak partial legacy events into the report writer. Gating the entire block at the top is the cleanest mental contract: "when S00 owns the live path, the legacy path is dark."

### 2.4 Zero behavior change in R1.2a

`S00_RealExecution` defaults to `false` and is never set `true` in this phase. The gate condition `!S00_RealExecution` is therefore always `true`, so the legacy block executes exactly as in R1.1c-fix. The byte-for-byte FixedLot April baseline `585.17 / 1104.89 / 157.49` is preserved by construction.

---

## 3. S00 lot-size plumbing

### 3.1 Why a separate `S00_LotSize` instead of reusing `FixedLotSize`

`FixedLotSize` is the project-wide pre-refactor input used by the legacy `FVG_MICRO_RETEST` execution path. Sharing it would couple S00's sizing to the legacy strategy's. R1.2a keeps them separate so:

- The S00 paper run can carry its own sizing independent of any legacy-strategy operator config.
- R1.2b can wire S00 to send orders sized by `S00_LotSize` without disturbing the FixedLot baseline (which keeps using `FixedLotSize`).
- The per-strategy input-grouping convention (R1.1a-labels rule 2) stays intact: S00 sizing lives under `── S00 FVG Scalp ──`.

### 3.2 Fixed-mode only

R1.2a intentionally ships only fixed-mode sizing (`m_active_trade.lot_size = S00_LotSize;`). Percent-of-equity sizing is the natural next mode — it is deliberately deferred per the input-design rules (don't build what you don't need yet). The struct field and CSV column are sizing-mode-agnostic, so adding the mode later is a pure-input + pure-compute change with no downstream churn (recorded in `Ideas_Backlog.md` #59).

### 3.3 CSV column

The new `LotSize` column is the 22nd CSV column. Two-decimal display (`DoubleToString(t.lot_size, 2)`) matches MQL5's standard lot rendering and gives the operator a column that's both readable in a spreadsheet and exact for the default `0.01` minimum. The column lives at the end of the row so the existing R1.1c-fix column ordering is unaffected.

### 3.4 No broker order sent

The R1.2a hard constraint: S00 **computes and records** the lot size; it does not call `OrderSend`, `g_broker_entry_bridge.TryOpenFromShadowRecord`, or any execution layer. Lot-size becomes a real live field only in R1.2b.

---

## 4. Invariants verified

| Invariant | How it holds |
|---|---|
| **No `OrderSend` in any strategy engine.** | S00 still does not call `OrderSend`. `g_broker_entry_bridge.TryOpenFromShadowRecord` is gated by `!S00_RealExecution` (with `S00_RealExecution=false`, only the legacy strategy can call it — same as R1.1c-fix). |
| **Zero-lookahead.** | No new reads added. The only new read in `EvaluateOnNewBar` is `S00_LotSize`, which is an `input` constant. |
| **No early break-even / no `BrokerModify` / no `RuntimeSLChanged`.** | R1.2a touches no SL logic — the R1.1c-fix fixed-threshold breakeven mechanism is preserved verbatim. |
| **`EnableRealExecution` locked off by default.** | The project-wide switch is unchanged. The new `S00_RealExecution` is also `false` by default; in R1.2a it is `false` everywhere. |
| **Single commit per phase + `EA_VERSION_TAG` bump.** | `Core/FalconConstants.mqh` bumped to `R1_2a`. One commit at the end of R1.2a. |
| **FixedLot April baseline byte-identical to R1.1c-fix.** | The coexistence gate condition `!S00_RealExecution` is always `true` in R1.2a, so the legacy block executes exactly as before. No legacy code changed. |
| **S00 paper trades byte-identical to R1.1c-fix except for the new `LotSize` column.** | S00 logic (detection / filters / entry / exit / breakeven) is untouched. The only new state on `S00PaperTrade` is `lot_size`, populated from a constant input. CSV gets one new column appended; existing columns are unchanged in name, order, and format. |

---

## 5. Out of scope — explicitly NOT done in R1.2a

Per spec §4 + §8:

- **Real broker execution for S00.** No `OrderSend`, no `g_broker_entry_bridge` call from S00, no execution layer touched. That is R1.2b.
- **Multi-strategy magic routing.** `FC_MAGIC_FVG_MICRO` stays hard-coded in the bridge (12 sites). The R1.2a coexistence gate is the *single-strategy-at-a-time* contract that defers this work cleanly. Captured in `Ideas_Backlog.md` #57.
- **Legacy `FVG_MICRO_RETEST` removal.** Stays in place as the verification-baseline producer. Captured in `Ideas_Backlog.md` #58.
- **Percent-risk lot sizing.** Fixed-mode only in R1.2a. Captured in `Ideas_Backlog.md` #59.
- **Real-vs-paper reporting.** Belongs to R1.2b once the OrderSend exists and produces broker-side rows to compare against the paper rows.
- **Pre-refactor input cleanup.** R1.1a-labels item #36 stays deferred.

---

## 6. Files touched

| File | Change |
|---|---|
| `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | +2 inputs (`S00_RealExecution`, `S00_LotSize`). |
| `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` | +1 struct field (`lot_size`), +1 init assignment at step 3e, +1 CSV header column (`LotSize`), +1 CSV row field. |
| `JA_FalconCore_Automated_Trading_Platform.mq5` | Coexistence gate at 2 touch sites (`OnInit` retry/close-handler, `OnTick` legacy block) + 2 R1.2a comment blocks. |
| `Core/FalconConstants.mqh` | `EA_VERSION_TAG`: `R1_1c_fix` → `R1_2a`. |
| `Docs/Specs/JA_FalconCore_R1_2a_SPEC.md` | Moved here from repo root. |
| `Docs/Ideas_Backlog.md` | +3 items (#57, #58, #59) under a new "From R1.2a" section. |
| `Docs/ReviewNotes/R1_2a_Review_Notes.md` | This file. |

---

## 7. Verification plan (for the operator running tests)

R1.2a is a no-op-on-defaults change, so verification is regression-style:

1. **Compile clean.** `F7` in MetaEditor — must produce `0 errors, 0 warnings`.
2. **FixedLot April baseline.** Run the legacy `FVG_MICRO_RETEST` tester profile on the April window. Expected: `RawNetUSD=585.17`, `FinalWorkingNetUSD=1104.89`, broker net `157.49`. With `S00_RealExecution=false` (default), this must match R1.1c-fix exactly.
3. **S00 paper run (March → today).** Run the S00 paper-isolated profile across the same multi-month window used for R1.1c-fix. Expected: same trade count, same per-trade `EntryTime / Direction / EntryPrice / StopLoss / Target / ExitTime / ExitReason / ResultPoints / BreakevenArmed` as R1.1c-fix. The new `LotSize` column should be `0.01` on every row.
4. **R1.2a flag still off.** Confirm `S00_RealExecution = false` in the parameters dialog for both runs. (R1.2b is the phase that flips this.)

If any of the three verification numbers move in step 2, or any S00 row differs in step 3 (outside the new `LotSize` column), R1.2a has regressed and needs investigation before R1.2b can start.

---

## 8. Next phase — R1.2b

R1.2b is "wire S00 to real execution":

- Add a real `OrderSend` path for S00 that fires when `S00_RealExecution = true`.
- Route S00 tickets through a magic that does **not** collide with the legacy `FC_MAGIC_FVG_MICRO`.
- Add a "real vs paper" report so the operator can see broker fills against the S00 paper plan side-by-side (the standard exposure of slippage + spread + commission costs).
- Decide the order-management strategy: simple market-at-confirmation vs. limit-at-CE vs. stop-on-confirmation. The decision should be driven by the same data discipline that produced R1.1c-fix (test → measure → keep what works).

R1.2a leaves the table set: the gate is in place, the lot-size field is plumbed and visible in the report, and the legacy strategy is one input-flip away from being dark for the session.
