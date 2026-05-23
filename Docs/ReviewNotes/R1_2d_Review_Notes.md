# R1.2d — S00 closed trades registered in the central TradeLifecycle (dual report complete)

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.2c (commit `ae42caa`).

R1.2d closes the reporting half of the R1.2 line. R1.2b wired real broker entries from S00; R1.2c wired real broker closes by reverse deal. Both phases left the **central** TradeLifecycle / Summary / Reconciliation reports empty — the diagnostic state the exploration report captured as `TotalTrades=0` in `Summary.csv` and `BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE` on every Reconciliation row. R1.2d sits in the one missing seam: when `CS00EntryLogic::CloseActiveTrade` finalizes a paper trade, it now also builds a `FalconTradeLifecycleRecord` and calls `g_report_writer.RegisterClosedTrade(...)`. That single call drives the rest of the report layer (the 12-step Apply chain, Summary totals, TradeLifecycle CSV row, Lock-Parity decomposition, Reconciliation pair) — same as the legacy `FVG_MICRO_RETEST` strategy has done since v0.5x.

> Active spec: `Docs/Specs/JA_FalconCore_R1_2d_SPEC.md` (moved into `Docs/Specs/` per the R0.9 convention; the R1.2c root spec was deleted in the same commit).

---

## 1. What was built

| Item | Path | Notes |
|---|---|---|
| `BuildLifecycleRecordFromS00Trade` helper | `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` (private, immediately above `CloseActiveTrade`) | 18-line helper that maps the 13 mandatory `FalconTradeLifecycleRecord` fields out of `m_active_trade`. All P&L / index-points fields are left zero-initialised (MQL5 auto-zeros struct locals); `RegisterClosedTrade → FalconFinalizeTradeMetrics` derives them from `direction`, `entry_price`, `exit_price`, `lot_size`. No manual P&L math in the strategy. |
| Central registration call | `S00_EntryLogic.mqh` (`CloseActiveTrade`, inside the existing R1.2c three-gate `if` block, before `TryManagedCloseFromS00Trade`) | `FalconTradeLifecycleRecord lifecycle_record; BuildLifecycleRecordFromS00Trade(lifecycle_record); g_report_writer.RegisterClosedTrade(lifecycle_record);`. Placed BEFORE the bridge close so a Paper TradeLifecycle row exists by the time the bridge writes its BrokerExecutionLifecycle row — Reconciliation finds the Paper-vs-Broker pair instead of flagging `BROKER_ONLY_TRADE_NOT_IN_LOCK`. |
| `EA_VERSION_TAG` + `EA_BUILD_TAG` | `Core/FalconConstants.mqh:10-11` | `R1_2c` → `R1_2d`; `RealisticCloseExecution` → `CentralLifecycleRegistration`. |

**Net file delta (2 code files + 3 doc files):**
- `Core/FalconConstants.mqh`: 2 lines changed (version + build tag).
- `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh`: ~50 lines added (helper function + comment block) and ~7 lines added inside the existing gate (call sequence + header comment).
- `Docs/Specs/JA_FalconCore_R1_2d_SPEC.md`: moved here from repo root (rename only).
- `JA_FalconCore_R1_2c_SPEC.md`: deleted from repo root (R1.2c shipped in commit `ae42caa`).
- `Docs/Ideas_Backlog.md`: item #65 struck through (closed by R1.2d); item #66 appended (revisit `stage` semantics).
- `Docs/ReviewNotes/R1_2d_Review_Notes.md`: new (this file).

Main `.mq5` is **not** touched. `FalconReportWriter.mqh`, `FalconBrokerEntryBridge.mqh`, `FalconRiskLifecycleProcessor.mqh`, and the `FalconTradeLifecycleRecord` struct are **not** touched.

---

## 2. The pre-commit verifications the spec asked for

### 2.1 `stage` field: behavioural branching audit — **decision: `PAPER`**

The spec called out: *if any of the 12 Apply* methods branches behaviourally on `record.stage`, use `FALCON_TRADE_STAGE_SHADOW` (legacy) instead and report the change*. Grep across the entire codebase:

| Reference | Type |
|---|---|
| `FalconStageToString(record.stage)` in `Reporting/FalconReportWriter.mqh:5282` | CSV output only |
| `lifecycle_record.stage = FALCON_TRADE_STAGE_SHADOW` in `Execution/FalconShadowExecutor.mqh:222` | Legacy shadow-stage setter |
| `record.stage = FALCON_TRADE_STAGE_NONE` in `JA_FalconCore_Automated_Trading_Platform.mq5:5542` | Lifecycle-record zero-init helper |
| `Risk/FalconRiskLifecycleProcessor.mqh` — entire 1643-line file | **Zero** references to `stage` or `FALCON_TRADE_STAGE_*` |

The 12-step Apply chain is stage-agnostic. The field is consumed only by `FalconStageToString` for the `TradeLifecycle.csv` `Stage` column. `PAPER` is the descriptively-correct choice for an R1.2d S00 trade: the broker path is wired (so it is no longer pure shadow simulation), but the *strategy decision* is still made paper-side from closed-bar candle data. Recorded as backlog item #66 — the enum semantics should be revisited once a second real-executing strategy lands and the field starts being read by a downstream filter or report.

### 2.2 `FalconTradeLifecycleRecord` visibility from `S00_EntryLogic.mqh`

Include order in `JA_FalconCore_Automated_Trading_Platform.mq5`:

```
line  15  #include "Core/FalconConstants.mqh"
line  16  #include "Core/FalconEnums.mqh"            // FALCON_DIRECTION_BUY/SELL, FALCON_TRADE_STAGE_PAPER, FALCON_TRADE_OUTCOME_OPEN
line  18  #include "Core/FalconDataStructures.mqh"   // struct FalconTradeLifecycleRecord
...
line  97  #include "Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh"
...
line 5652 #include "Reporting/FalconReportWriter.mqh"     // g_report_writer (resolved via MQL5 two-pass parse)
line 5676 #include "Execution/FalconBrokerEntryBridge.mqh" // g_broker_entry_bridge (same)
```

`FalconTradeLifecycleRecord` and the enum constants are all defined **above** line 97 — visible directly from S00. `g_report_writer` is resolved by the same two-pass class-method parse pattern that R1.2b already uses for `g_broker_entry_bridge.TryOpenFromShadowRecord(...)` at the entry side. Compile confirms it (§3); no include reorder was needed.

---

## 3. Compile result

Built with MetaEditor `metaeditor64.exe /compile:JA_FalconCore_Automated_Trading_Platform.mq5`:

```
Result: 0 errors, 0 warnings, 13897 ms elapsed, cpu='X64 Regular'
```

All R1.2d identifiers resolve (`FalconTradeLifecycleRecord`, `FALCON_DIRECTION_BUY`, `FALCON_DIRECTION_SELL`, `FALCON_TRADE_STAGE_PAPER`, `FALCON_TRADE_OUTCOME_OPEN`, `g_report_writer.RegisterClosedTrade`). No signature mismatches, no unresolved identifiers.

---

## 4. Why this single call drives the rest of the report layer

`CFalconReportWriter::RegisterClosedTrade(record)` is the single funnel between the strategy and the central reporting/Apply* machinery (see `Reporting/FalconReportWriter.mqh:3893`). One call writes to (or seeds the totals for) every downstream surface:

```
RegisterClosedTrade(record)
  ├── FalconFinalizeTradeMetrics(record, _sc)              // P&L + indices from direction/prices/lot
  ├── g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record, m_totals)
  │     // 12 Apply* steps in load-bearing order: #3,#4,#5,#6,#7,#8,#10,#9,#1,#2,#11,#12
  ├── AppendEmergencyTriggerEvent(record)                  // self-gated by record.falcon_emergency_status
  ├── UpdateTotals(record)                                 // → Summary.csv totals
  ├── AppendTradeRecord(record)                            // → TradeLifecycle.csv row
  ├── AppendPaperStateSnapshotRecord(record)               // → PaperStateSnapshot.csv
  ├── AppendBrokerExecutionLifecycleAuditRecord(record)
  ├── AppendBrokerRebasedPaperComparisonRecord(record)     // → RebasedPaperComparison.csv
  ├── AppendBrokerTradeManagementTimelineForRecord(record) // → TradeManagementEventTimeline.csv
  ├── UpdateLockParityTotals(record)                       // v0.57.0 Lock-Parity Decomposer
  └── AppendLockParityDecompositionRecord(record)
```

S00's R1.2b/c work was entry- and close-side broker plumbing. R1.2d is the seam that finally lights up all these surfaces for S00.

---

## 5. Ordering inside the close gate — why `RegisterClosedTrade` runs before `TryManagedCloseFromS00Trade`

The spec's prescribed order:

```mql5
AppendTradeRow(m_active_trade);                          // S00 diagnostic CSV (R1.1b)

if(MQL_TESTER && EnableRealExecution && S00_RealExecution)
{
   // 1. Central Paper TradeLifecycle row — R1.2d.
   FalconTradeLifecycleRecord lifecycle_record;
   BuildLifecycleRecordFromS00Trade(lifecycle_record);
   g_report_writer.RegisterClosedTrade(lifecycle_record);

   // 2. Bridge close (real broker reverse deal) — R1.2c.
   g_broker_entry_bridge.TryManagedCloseFromS00Trade(
      m_active_trade.trade_id, exit_price, reason, g_report_writer);
}
```

The two operations were spec'd as two `if` blocks for clarity; they live inside the same gate here because that is structurally cleaner and the spec explicitly permitted the merge (*يمكن دمج البوّابتين في واحدة إن كان أنظف — قرار تنفيذيّ*).

Rationale for **register-then-close**:
- `RegisterClosedTrade` writes the Paper TradeLifecycle row + updates `m_totals` for `Summary.csv`.
- `TryManagedCloseFromS00Trade` (via `ExecuteReverseClosePositionRequest`) writes a `BrokerManagedCloseLifecycle` row and updates the broker-side audit surfaces.
- Reconciliation (`AppendBrokerPaperTradeReconciliationRecord` and the Lock-Parity decomposer) matches Paper rows against Broker rows on `trade_id`. With Paper present first, Reconciliation finds the pair; reverse the order and a same-tick reconciliation pass would (currently or in some future audit hook) re-flag `BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE` — the exact failure mode R1.2d is here to remove.

---

## 6. The hard verification constraint — what `S00_RealExecution = false` must still produce

The legacy FixedLot April baseline `RawNetUSD = 585.17 / FinalWorkingNetUSD = 1104.89 / broker = 157.49` is the load-bearing safety check. With `S00_RealExecution = false` (default):

- The new `if(MQL_TESTER && EnableRealExecution && S00_RealExecution)` block is **false at its third clause** — `BuildLifecycleRecordFromS00Trade` never runs, `RegisterClosedTrade` is never called from S00, and the only `RegisterClosedTrade` calls on the run remain the legacy ones from `FVG_MICRO_RETEST` via `g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord(...)`. The legacy path is untouched.
- `BuildLifecycleRecordFromS00Trade` is a private method on `CS00EntryLogic` — its body is parsed by the compiler but never called when the gate is shut. Adding it has zero runtime cost in the legacy lane.
- `FalconConstants.mqh` only changed two `#define` string tags (`EA_VERSION_TAG`, `EA_BUILD_TAG`). The macros are emitted to log lines and the `Summary.csv` header; they do not gate any numeric computation.

A test run with the default gates therefore must reproduce `585.17 / 1104.89 / 157.49` byte-for-byte. The operator should re-run this immediately as the gate-closed regression check.

---

## 7. The three-month verification run that R1.2d unlocks

The R1.2d acceptance criteria from the spec require a three-month (March–April–May 2026) tester run with `S00_RealExecution = true` to confirm:
- `Summary.csv`: `TotalTrades > 0` (expected ≈ 25 per R1.2c's audit).
- `TradeLifecycle.csv`: one row per S00 closed trade.
- `BrokerPaperTradeReconciliation.csv`: every row now finds a Paper match — no more `BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE`.
- `BrokerExecutionLifecycle.csv` and `BrokerRebasedPaperComparison.csv`: populated for S00 closes.
- Safety guards: `BrokerModifySent = 0`, `RuntimeSLChanged = 0`, `InvariantBreaches = 0`.

That run is the operator's next step. The code change itself ships green; the verification run is out of scope for this commit (same pattern as R1.2c's three-month run, deferred for the same reason).

---

## 8. What is NOT in R1.2d

- **No S00 entry-logic change.** R1.2c's broker entry and close paths are untouched. The strategy decisions (target, structural stop, breakeven trigger, timeout) are byte-for-byte identical.
- **No `FalconTradeLifecycleRecord` schema change.** Only the 13 fields the strategy can meaningfully populate from `m_active_trade` are set; everything else relies on MQL5's automatic struct zero-init plus `FalconFinalizeTradeMetrics`.
- **No new manual P&L computation in the strategy.** `RegisterClosedTrade` owns the metric pipeline; S00 just hands it the inputs.
- **No `OrderModify` / `BrokerModify` / `TRADE_ACTION_SLTP`.** No `RuntimeSLChanged` either — the lookahead and no-modify-SL invariants are preserved (no new bar reads at all).
- **No diagnosis of S00's real-execution weakness.** R1.2c's audit observed that ~84% of real closes hit the stop. R1.2d completes the reporting that makes that diagnosis possible; it does not perform the diagnosis itself. That is the next phase.

---

## 9. Files changed

```
Core/FalconConstants.mqh                                       | 2 ± lines (version + build)
Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh                | ~57 + lines (helper + call + comments)
Docs/Specs/JA_FalconCore_R1_2d_SPEC.md                         | moved from repo root
JA_FalconCore_R1_2c_SPEC.md                                    | deleted from repo root
Docs/Ideas_Backlog.md                                          | item #65 struck; item #66 appended
Docs/ReviewNotes/R1_2d_Review_Notes.md                         | new (this file)
```

No other files modified. Main `.mq5` untouched. `FalconReportWriter.mqh` untouched. `FalconBrokerEntryBridge.mqh` untouched. The `FalconTradeLifecycleRecord` struct is untouched. The Apply chain is untouched.

---

## 10. Sanity checks before commit

- ☑ Compile: `0 errors, 0 warnings`.
- ☑ Stage decision verified — `PAPER` is correct because the 12-step Apply chain has zero `stage` branching (backlog item #66 logged for the future).
- ☑ `FalconTradeLifecycleRecord` visible from S00 via the existing include order (no include reorder).
- ☑ FixedLot April baseline guarantee: gates default-off → `RegisterClosedTrade` is never called from S00 → legacy `585.17 / 1104.89 / 157.49` chain is the only writer to the central reports (must be re-confirmed by the operator's regression run).
- ☑ No `OrderModify` / `BrokerModify` / `TRADE_ACTION_SLTP` introduced (grepped; still zero in the repo).
- ☑ No `FalconFinalizeTradeMetrics` call from the strategy (handled by `RegisterClosedTrade`).
- ☑ Lookahead invariant preserved — no new bar/price reads.
- ☑ R1.2c SPEC removed from repo root; R1.2d SPEC moved into `Docs/Specs/` per the R0.9 convention.
