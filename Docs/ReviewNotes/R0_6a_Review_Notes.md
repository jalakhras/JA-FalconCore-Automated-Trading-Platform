# R0.6a — ReportWriter Structural Move: Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.5b (commit `3daf1b9`) &nbsp;|&nbsp; **Working tree before commit.**

This document captures the spec §5 "review-as-you-move" findings for the R0.6a structural decomposition of `CFalconReportWriter` — the largest single class in the project (~36% of the pre-refactor codebase).

**Decision: Method B (spec §2)** — single-file verbatim move. The class is kept intact for now; no internal splitting performed. Behavior is byte-for-byte identical. Internal splitting (Method A) is deferred to a later phase (candidate: R0.6c or R0.9) where the seams between Summary/TradeLifecycle/Diagnostic/Apply\*/Lock-Parity can be drawn after the R0.7 Apply\* peel exposes them more clearly.

---

## 1. Migration Summary

| Target file | Source range in main .mq5 (pre-migration) | Symbols moved | New file LOC |
|---|---|---|---|
| `Reporting/FalconReportWriter.mqh` | L5562–L11853 | `CFalconReportWriter` (class) + 3-line header banner | 6,318 |
| **Total** | **6,292 source lines** | **1 class** | **6,318** |

Main `.mq5` change: 6,292-line class body replaced by a 9-line include block (8 comment lines + the `#include`). Net: **−6,283**.

Main `.mq5` size: **12,235 → 5,952 lines** (−6,283).

Deleted placeholders (3): `Reporting/FalconReporting_Placeholder.mqh`, `Reporting/core/FalconReportingCore_Placeholder.mqh`, `Reporting/diagnostic/FalconReportingDiagnostic_Placeholder.mqh`. Empty subdirectories `Reporting/core/` and `Reporting/diagnostic/` are kept on disk as future Method-A targets; git ignores empty dirs.

Duplication audit: `^class CFalconReportWriter\b` returns exactly 1 hit (`Reporting/FalconReportWriter.mqh:28`). The 12 `Apply*` methods each occur exactly once, all inside the new `.mqh`; zero in main `.mq5`.

---

## 2. `#include` order in the main `.mq5`

```cpp
// === TOP block (unchanged) ===
// Core (R0.2) / Evidence + Risk (R0.3) / Execution top (R0.4) / Router (R0.5)

// === MIDDLE block ===
// ... main .mq5 inputs, helpers, FvgMicro classes (still inline) ...
// ... CFalconShadowDetectorLevels1To3MapperSnapshotFoundation etc. ...

#include "Reporting/FalconReportWriter.mqh"     // ← R0.6a, mid-file (L5570)
                                                //   class used to live here

// ... FalconV055ArchitectureConsolidationContractReady() ...
#include "Execution/FalconBrokerEntryBridge.mqh" // ← R0.4, mid-file (L5594)
                                                 //   depends on ReportWriter
```

**Why mid-file (not top):** ReportWriter references types defined later than the top includes (FVG-Micro stub classes, etc.). Moving the include to the top would require also moving those classes — out of scope for R0.6a's "structural-only" rule. Placing the include exactly where the class used to live keeps preprocessor order identical to pre-R0.6a — no parse-order surprises.

**Why before Bridge:** the Bridge calls 6 telemetry methods on this class (see §3.6). Including ReportWriter first ensures Bridge's method-body parse can resolve `report_writer.AppendBroker*Record(...)` against a complete class definition. The two includes are 24 lines apart in main `.mq5` (5570 → 5594), with the `FalconV055ArchitectureConsolidationContractReady()` helper sandwiched between — that helper does not reference either class, so no further reordering was needed.

**No `Reporting/FalconReportingInputs.mqh` was needed:** every `#define` referenced by ReportWriter is declared at or before line 5200 of main `.mq5` (the highest-line `#define` in the file is `FALCON_SHADOW_LIFECYCLE_TIMEOUT_SECONDS` at L5200, well before the L5562 include point). All preprocessor symbols are resolved before the include is parsed.

---

## 3. Spec §5 — Review Protocol Findings

### 3.1 Lookahead check

**Verified clean.** Zero candle-data reads via `CopyRates`, `iHigh`, `iLow`, `iOpen`, or `iBars`. Four `iClose` calls exist, all inside one method:

```
Reporting/FalconReportWriter.mqh:1900  iClose(m_symbol_context.symbol, PERIOD_M1, shift)
Reporting/FalconReportWriter.mqh:1902  iClose(_Symbol,                  PERIOD_M1, shift)
Reporting/FalconReportWriter.mqh:1913  iClose(m_symbol_context.symbol, PERIOD_M5, shift)
Reporting/FalconReportWriter.mqh:1915  iClose(_Symbol,                  PERIOD_M5, shift)
```

All four are inside `FalconTryGetBoundaryClosePrice(datetime boundary_time, double &price)` (L1889). `shift` is computed via `iBarShift(..., boundary_time, false)` where `boundary_time` is taken from a **closed** lifecycle record (the trade has already exited). This is historical reconstruction for the session-boundary report — not future-bar lookahead. Adversary check: even if `boundary_time` ≥ `TimeCurrent()` somehow, `iBarShift` would return -1 and the function would early-return `false` without reading a candle.

**Verdict: SAFE.** No lookahead surface introduced or pre-existing in the moved code.

### 3.2 Globals (`g_*`) used by moved code

**Zero `g_*` references** in `Reporting/FalconReportWriter.mqh` (verified via grep `\bg_[a-z_]` — 0 matches).

The class is invoked through the global `g_report_writer` (declared at L5621 of post-move main `.mq5`), but the class body itself does not reach into any global. Every external dependency is passed in by reference — `CFalconCandleCache&`, `CFalconEvidenceFramework&`, `CFalconShadowExecutor&`, etc. This is the cleanest possible state; **per spec §1, no globals were migrated**.

### 3.3 Dead logic

The class contains ~100 methods (~6,292 lines). A full per-method audit is impractical at this scale. Spot-check + entry-point audit confirms:

- Every `WriteXDiagnosticsSnapshot` is invoked from `OnInit` or `OnDeinit` in main `.mq5` (verified: `WriteStrategyRegistryDiagnosticsSnapshot`, `WriteFvgMicroDetectorDiagnosticsSnapshot`, `WriteLockParityDecompositionHeader`, `WriteLockParityExecutabilityRollup`, etc. — all referenced).
- `RegisterClosedTrade` is invoked by the FvgMicro lifecycle simulator and (indirectly) by the broker observation path.
- The 6 broker telemetry methods are all called from the Bridge (verified at R0.4 review §3.6, unchanged here).
- The 12 `Apply*` methods are all called from `RegisterClosedTrade` / `WriteFinalSummary` (verified by searching call-sites; see §4 below).
- The 3 multi-profile-summary arrays from v0.22.2 were already retired at the source — no new dead state introduced.

No dead branches added or removed by this move. Anything that was dead before R0.6a is still dead; anything live before is still live.

### 3.4 Silent errors

**File-write surface:** Every file is opened with `FileOpen(...)`; the class either checks `handle != INVALID_HANDLE` and logs on failure, or unconditionally writes the row and lets `FileClose` reclaim. No new silent-failure surface was introduced — the move is verbatim.

**Telemetry:** All broker telemetry methods (§3.6) accept their inputs by value/const-ref and write a row regardless of input validity (they record what they saw). This is by design — telemetry must not fail silently, and it must not throw away "bad" rows.

**Verdict: SAFE.** No silent-failure regressions.

### 3.5 The 12 `Apply*` methods — **accurate map for R0.7**

All 12 `Apply*` methods now live inside `Reporting/FalconReportWriter.mqh`. Their pre-R0.6a positions (main `.mq5`) and post-R0.6a positions (new file) are documented below. Use the **new-file** column for R0.7 extraction work.

> Line-offset formula: `new_line = orig_line − 5562 + 25` (the class body starts 25 lines later in the new file due to the header banner + include guard + leading blank).

| # | Method | orig .mq5 lines | new .mqh lines | LOC | R0.7 target layer |
|---|---|---:|---:|---:|---|
| 1 | `ApplyNoNewEntryUserOverridePaperEnforcement`            | 7602–7643   | 2065–2106 |  42 | Risk / TM enforcement (No-New-Entry user override) |
| 2 | `ApplyDailyWeekendForceCloseUserOverridePaperEnforcement` | 7644–7729   | 2107–2192 |  86 | Risk / TM enforcement (Daily/Weekend force-close) |
| 3 | `ApplyFvgQualityShadowGuardSimulation`                    | 9890–9917   | 4353–4380 |  28 | Strategy guard (FVG quality) — could live with S00 |
| 4 | `ApplyPaperRuntimeGuardApplication`                       | 9918–9947   | 4381–4410 |  30 | Risk / Paper runtime guard |
| 5 | `ApplyPaperRuntimeSmartSLProtectionApplication`           | 9948–10024  | 4411–4487 |  77 | Risk / Paper SL protection |
| 6 | `ApplyPaperRuntimeRunnerApplication`                      | 10025–10104 | 4488–4567 |  80 | Risk / Paper runner |
| 7 | `ApplyCapitalTierFoundation`                              | 10117–10143 | 4580–4606 |  27 | Risk / Capital tier |
| 8 | `ApplyLowCapitalRiskFeasibilityFoundation`                | 10144–10239 | 4607–4702 |  96 | Risk / Low-capital feasibility |
| 9 | `ApplyCalibratedSingleTradeLossCapEnforcement`            | 10240–10321 | 4703–4784 |  82 | Risk / Single-trade loss cap |
| 10 | `ApplyDynamicLotSizingModel`                             | 10431–10564 | 4894–5027 | 134 | Risk / Dynamic lot sizing model (DLM) |
| 11 | `ApplyThreeLayerEmergencyApplication`                    | 10565–10725 | 5028–5188 | 161 | Risk / Three-layer emergency |
| 12 | `ApplyCapitalFlowSourceClassification`                   | 10726–10804 | 5189–5267 |  79 | Reporting (classification only) — likely stays |
| | **Total Apply\* LOC** | | | **922** | ~15% of the class |

**Caller graph:**

- `RegisterClosedTrade` (new-file L4002 area) is the single chain orchestrator. It calls Apply#1, #2, #3, #4, #5, #6, then #7, #8, #9, then #10, #11, then #12 in that order on every closed trade.
- `WriteFinalSummary` reads the cumulative effect (via `m_totals`) but does not call any `Apply*` directly.
- No `Apply*` is called from outside `CFalconReportWriter`. R0.7 will need to lift the chain *and* its `m_totals` / lifecycle-record contract.

**R0.7 risk flag:** the order matters. #1→#11 are not independent — later steps read state mutated by earlier ones (e.g. DLM #10 needs the active lot decided by #9; Three-Layer Emergency #11 reads runner/SL state set by #5/#6). The R0.7 peel must preserve this exact call order and must keep the lifecycle-record as the data bus.

### 3.6 Broker telemetry methods — locations after the move

All 6 telemetry methods called by `CFalconBrokerEntryBridge` (per R0.4 review §3.6) now live in `Reporting/FalconReportWriter.mqh`:

| Method | new .mqh line | Caller (in Bridge) |
|---|---:|---|
| `AppendBrokerEntryBridgeLifecycleRecord` | 548 | `TryOpenFromShadowRecord` |
| `AppendBrokerExitObservationLifecycleRecord` | 600 | `ObserveTradeTransactionExit` |
| `AppendBrokerManagedCloseLifecycleRecord` | 664 | `TryManagedCloseFromLifecycleRecord` |
| `AppendBrokerPaperTradeReconciliationRecord` | 729 | `TryManagedCloseFromLifecycleRecord` / `FlushOpenLinksAtDeinit` |
| `AppendBrokerOnlyTradeReconciliationRecord` | 988 | `TryManagedCloseFromLifecycleRecord` / `FlushOpenLinksAtDeinit` |
| `AppendVirtualTrailingExitLifecycleRecord` | 3936 | `UpdateVirtualTrailingForOpenLinks` |

Coupling remains strictly one-way (Bridge → ReportWriter). The Bridge include order is unchanged: it stays at L5594 of main `.mq5`, immediately after the new ReportWriter include at L5570 (24 lines apart). No new entanglement introduced.

### 3.7 Lock Parity Decomposer — untouched

The Lock Parity logic (L8942–L9454 in pre-R0.6a numbering) is now at L3405–L3917 of the new file. Spec §1 forbids touching it. Verified by spot-check: `WriteLockParityDecompositionHeader`, `LockParityIsExecutableClass`, `ClassifyLockParity*` (7 classifiers), `AppendLockParityDecompositionRecord`, `UpdateLockParityTotals`, `WriteLockParityExecutabilityRollup` — all present and unmodified.

### 3.8 OrderSend / execution surface

**Verified zero.** `grep OrderSend Reporting/FalconReportWriter.mqh` returns 0 matches. The Reporting layer is pure observation — it records what happened, never executes. No regression possible from this move.

---

## 4. Spec §6 Acceptance Status

| Criterion | Status |
|---|---|
| `CFalconReportWriter` moved to `Reporting/` (single file, Method B) | ✓ |
| `Reporting/FalconReporting_Placeholder.mqh`, `Reporting/core/Placeholder`, `Reporting/diagnostic/Placeholder` deleted | ✓ (3 files removed) |
| ReportWriter included BEFORE Execution/FalconBrokerEntryBridge.mqh | ✓ (5570 < 5594) |
| Migrated code removed from main `.mq5` (no duplication) | ✓ (class: 1 hit under `Reporting/`, 0 in `.mq5`) |
| 12 `Apply*` methods preserved and not modified | ✓ (verbatim — bodies are byte-identical; locations mapped in §3.5) |
| Compiles `0 errors, 0 warnings` | ⏳ requires MetaEditor F7 by user |
| FixedLot April: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker net = 157.49 exactly | ⏳ requires post-compile backtest |
| All CSV reports still produced with the same content | ⏳ requires post-compile backtest; verbatim move means same code paths still run |
| `Docs/ReviewNotes/R0_6a_Review_Notes.md` exists with accurate `Apply*` map | ✓ (this file) |

---

## 5. Critical follow-up — R0.6b / R0.7 / future R0.6c

**R0.6b (next):** Add `input` switches to opt-in / opt-out the diagnostic reports. This is a behavior change by design — defaults will turn off the diagnostic-only reports while keeping Summary + TradeLifecycle on. The structural move from R0.6a does NOT block this — every diagnostic report is already a separate `WriteX...Snapshot` method, so gating each one is a localized edit inside `Reporting/FalconReportWriter.mqh`.

**R0.7 (Apply\* peel):** Use §3.5 map. Recommended order:
1. Lift `m_totals` and the lifecycle-record contract into a shared `Risk/` artifact.
2. Peel #12 first (classification-only, no state read by later steps).
3. Peel the Risk-natural ones in dependency order: #7, #8, #9, #10, #11.
4. Peel the Paper-runtime ones: #4, #5, #6.
5. Peel the user-override ones last: #1, #2.
6. #3 (`ApplyFvgQualityShadowGuardSimulation`) is a candidate to migrate to `Strategies/S00_ScalpFvgMicro/` instead — it's quality-filter logic, not risk policy.

**Future R0.6c (deferred, optional):** Split `Reporting/FalconReportWriter.mqh` into:
- `Reporting/core/SummaryWriter.mqh` — Summary + TradeLifecycle + headers
- `Reporting/diagnostic/LockParityDecomposer.mqh` — Lock Parity Decomposer block
- `Reporting/diagnostic/BrokerTelemetry.mqh` — 6 broker telemetry methods
- `Reporting/diagnostic/StrategyDiagnostics.mqh` — Strategy/FVG/Adapter diagnostics
- `Reporting/FalconReportWriter.mqh` — the class shell that `#include`s the above

This needs MQL5 support for `#include` inside a class body (it does) and careful sequencing of `private:` / `public:` sections across the include points. **Not a blocker for shipping anything.** Defer until R0.7 has reduced the `Apply*` mass.

---

## 6. Open items (deferred, non-blocking)

1. **Empty subdirectories `Reporting/core/` and `Reporting/diagnostic/`** remain on disk after the placeholder removal. Git does not track them. They preserve the intended split surface for future R0.6c. Safe to delete physically with no consequence; left in place as a low-cost signal of structural intent.
2. **The single-file `.mqh` is 6,318 LOC** — the largest in the project. MetaEditor opens it fine, and the preprocessor handles it without issue, but searching/navigating inside it is awkward. R0.6c is the cure.
3. **No `Reporting/FalconReportingInputs.mqh` was created** because no Router-style preprocessor-order problem was detected. If R0.6b introduces new `#define` switches that ReportWriter needs to see, this file can be added at that time using the R0.5-fix pattern.

---

*End of R0.6a review notes. The 12 `Apply*` methods are unchanged. Lock Parity logic is unchanged. Broker telemetry methods are unchanged. No globals migrated, no inputs touched, no `OrderSend` surface introduced. `CFalconReportWriter` was moved verbatim into a single `.mqh` under `Reporting/`.*
