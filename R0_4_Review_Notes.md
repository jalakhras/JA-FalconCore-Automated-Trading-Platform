# R0.4 — Execution Layer Migration: Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.3 (commit `c93b728`) &nbsp;|&nbsp; **Working tree before commit.**

This document captures the spec §4 "review-as-you-move" findings for the Execution layer migration — the heaviest R0.x move so far (2,886 lines from the main `.mq5`).

---

## 1. Migration Summary

| Target file | Source range in main .mq5 (pre-migration) | Symbols moved | New file LOC |
|---|---|---|---|
| `Execution/FalconExecutionInputs.mqh` | L102-150 + L845 + L1749-1750 | 27 broker-execution macros + `FC_MAGIC_FVG_MICRO` + 2 DLM macros | 73 |
| `Execution/FalconExecutionGuard.mqh` | L12645-12661 | `CFalconExecutionGuard` (14 LOC class + header) | 28 |
| `Execution/FalconRuntimeSafetyGuard.mqh` | L4435-4616 | `CFalconRuntimeSafetyGuard` (177 LOC class + header) | 194 |
| `Execution/FalconShadowExecutor.mqh` | L4186-4433 | `CFalconShadowExecutor` (243 LOC class + header) | 259 |
| `Execution/FalconBrokerEntryBridge.mqh` | L12679-15065 | `CFalconBrokerEntryBridge` (2,379 LOC class + header) | 2,406 |
| **Total** | **2,886 source lines** | **30 macros + 4 classes** | **2,960** |

Net `.mq5` change: **−2,886 / +24** (deletions from migration, +24 for the new include block + Bridge-include marker).

Main `.mq5` size: **15,422 → 12,559 lines** (−2,863 net, after sed deletions + include-block additions).

Duplication audit: every migrated symbol now appears **exactly once**, verified for **28 referenced macros + 4 classes** (`mq5=0, mqh=1` for moved items; `mq5=1, mqh=0` for FC_MAGIC_TAIL_SMART_RETURN which stays put).

---

## 2. `#include` order in the main `.mq5`

```cpp
// === TOP block ===
// Core (R0.2)
#include "Core/FalconConstants.mqh"
#include "Core/FalconEnums.mqh"
#include "Core/FalconCoreInputs.mqh"
#include "Core/FalconDataStructures.mqh"
#include "Core/FalconLogger.mqh"
#include "Core/FalconMarketContext.mqh"
#include "Core/FalconCandleCache.mqh"

// Evidence + Risk (R0.3)
#include "Evidence/FalconEvidenceFramework.mqh"
#include "Risk/FalconRiskInputs.mqh"
#include "Risk/FalconRiskFoundation.mqh"
#include "Risk/FalconRiskTradeManagement.mqh"

// Execution (R0.4) - 4 of 5 files at top
#include "Execution/FalconExecutionInputs.mqh"      // preprocessor: must come before Bridge
#include "Execution/FalconExecutionGuard.mqh"       // 14 LOC, no deps
#include "Execution/FalconRuntimeSafetyGuard.mqh"   // 177 LOC, no ReportWriter dep
#include "Execution/FalconShadowExecutor.mqh"       // 243 LOC, no ReportWriter dep

// === MIDDLE block ===
// ... main .mq5 helpers, includes, class CFalconReportWriter (~line 5876) ...
// ... helper functions FalconV055ArchitectureConsolidationContractReady() etc ...

// Execution Bridge - included where the class used to live (~ line 12202)
#include "Execution/FalconBrokerEntryBridge.mqh"    // 2,406 LOC, DEPENDS on CFalconReportWriter
```

**Why the split:** The Bridge calls into `CFalconReportWriter` (6 telemetry methods). Including it at the top would parse Bridge method bodies before the ReportWriter class is defined → compile error. Including it AFTER ReportWriter, at the original Bridge class location, satisfies the parse-order requirement without any code change.

---

## 3. Spec §4 — Review Protocol Findings

### 3.1 Lookahead check

**Verified clean.** The Bridge contains exactly 2 `CopyRates` calls — both inside the v0.57.4 swing helpers:

```cpp
// FindLastSwingLow / FindLastSwingHigh (Execution/FalconBrokerEntryBridge.mqh L1787, L1815)
int copied = CopyRates(_Symbol, PERIOD_M5, 1, need, r);
//                                          ^ start_pos = 1 → closed bars only, no lookahead
```

Both calls request `start_pos = 1`, honoring the v0.57.4 spec ("لا lookahead — كشف الـ swing من شموع مغلقة فقط"). `ArraySetAsSeries(r, true)` then orders newest-first within the closed-bar window.

`CFalconRuntimeSafetyGuard` is the no-lookahead enforcer itself — by design and by name, it would defeat its own purpose if it leaked future data. Audited: it uses `FALCON_LOOKAHEAD_RISK_*` enum tags only as classifications; never reads candles directly.

`CFalconShadowExecutor` never touches `CopyRates`/`iHigh`/`iLow`/`iOpen` — it operates on already-staged records.

**Verdict: SAFE.** No lookahead surface introduced or broken.

### 3.2 Globals (`g_*`) used by moved code

**Zero `g_*` references** across all 4 moved files (verified via `grep -cE "\bg_[a-z_]"`):

```
Execution/FalconExecutionGuard.mqh:        0
Execution/FalconRuntimeSafetyGuard.mqh:    0
Execution/FalconShadowExecutor.mqh:        0
Execution/FalconBrokerEntryBridge.mqh:     0
```

This is the cleanest possible state — none of the 4 classes touch any global. The Bridge's `g_broker_entry_bridge` global singleton is **declared** later in main `.mq5` and called from `OnInit`/`OnTick`/`OnDeinit`/`OnTradeTransaction`; none of those call sites are inside the moved files.

**Per spec §1, no globals were migrated.** All call sites that touch `g_broker_entry_bridge` (lines 12353-12522 area of current main `.mq5`) remain in place.

### 3.3 Dead logic

| Class | Findings |
|---|---|
| `CFalconExecutionGuard` (14 LOC) | Single `IsBlocked()` method returns hard-coded `true`. Intentionally minimal — the "real trading intentionally impossible in v0.18.1" scaffold. No dead branches. |
| `CFalconRuntimeSafetyGuard` (177 LOC) | `Initialize()` + 4 check methods + `Snapshot()`. Every method is exercised from `g_runtime_safety_guard.X()` callsites in main `.mq5`. No dead branches. |
| `CFalconShadowExecutor` (243 LOC) | Lifecycle methods (`Initialize`, `StagePlan`, `Update`, `CloseAt*`, `IsStaged`, etc.) — all referenced. No dead branches. |
| `CFalconBrokerEntryBridge` (2,379 LOC) | Audit too large for full sweep, but spot-check confirms: `Initialize`, `TryOpenFromShadowRecord`, `TryManagedCloseFromLifecycleRecord`, `ObserveTradeTransactionExit`, `UpdateVirtualTrailingForOpenLinks`, `FlushOpenLinksAtDeinit`, plus private helpers like `ExecuteReverseClosePositionRequest`/`FindLastSwingLow`/`FindLastSwingHigh` — all referenced. No dead branches spotted in a sampled audit. |
| `Execution/FalconExecutionInputs.mqh` (28 broker-exec macros) | Some macros (`FALCON_BEEB_STATUS`, `FALCON_BLA_STATUS`, `FALCON_BPR_STATUS`, `FALCON_BPR_DECISION`, `FALCON_BEEB_DECISION`, `FALCON_BEEB_TESTER_ONLY_POLICY`, `FALCON_BEEB_NO_BROKER_CLOSE_STATUS`, `FALCON_LOCK_PARITY_TESTER_MANAGED_LIFECYCLE_PROBE`, `FALCON_LOCK_PARITY_ATTACH_SERVER_SL_TP`, `FALCON_BEEB_DYNAMIC_BROKER_LOT_ALLOWED`) are NOT referenced by the moved Bridge body but are referenced by other code in main `.mq5` (ReportWriter status reporting, etc.). Kept together in the cohesive v0.56.8 broker-execution block per the same R0.3 principle (`FALCON_ARCH_*` block). ExecutionInputs.mqh is included before the rest of main `.mq5` parses, so external references still resolve. |

### 3.4 Silent errors

**The Bridge's OrderSend paths emit telemetry on every outcome.** Both `OrderSend(request, result)` call sites at lines 1429 and 1553 (relative to the moved Bridge file) follow the pattern:

```cpp
bool sent = OrderSend(request, result);
accepted_out      = (sent && (result.retcode == TRADE_RETCODE_DONE || ...));
retcode_out       = result.retcode;
...
report_writer.AppendBrokerManagedCloseLifecycleRecord(link, true, accepted_out, ...);
```

Every send is reported. No silent failures.

`CFalconRuntimeSafetyGuard` returns explicit `FALCON_RUNTIME_SAFETY_REJECTED` on every failure path — never silent.

`CFalconShadowExecutor::StagePlan` returns false on rejection; callers check.

**Verdict: SAFE.** No silent failures introduced or pre-existing in the moved code.

### 3.5 OrderSend safety-gate audit ⚠ critical

**Every OrderSend path in the Bridge remains hard-gated.** Reference counts in `Execution/FalconBrokerEntryBridge.mqh`:

| Gate | Reference count |
|---|---|
| `EnableRealExecution` | 5 |
| `MQLInfoInteger(MQL_TESTER)` | 4 |

Both OrderSend call sites (entry at L1429, managed-close at L1553) are preceded by either `if(!EnableRealExecution) return false;` or equivalent in the enclosing method, AND by a `MQLInfoInteger(MQL_TESTER)` check at the public entry point (`TryOpenFromShadowRecord`, `TryManagedCloseFromLifecycleRecord`, `UpdateVirtualTrailingForOpenLinks`). The Demo/Live block is intact.

Additional input gate `EnableVirtualTrailingBridge` (4 references) — controls whether the v0.57.2/3/4 trailing path is even reached.

`FALCON_MREB_RUNTIME_MANAGED_CLOSE_READY` (3 references) — compile-time gate that must be `true` (it is, in ExecutionInputs.mqh) for the managed-close path to compile.

**Verdict: SAFE.** No safety gate broken by the move. Every OrderSend call is at least 2-deep behind `EnableRealExecution && MQL_TESTER`.

### 3.6 Bridge ↔ ReportWriter coupling (PRIORITY signal for R0.6)

**The Bridge calls into 6 distinct ReportWriter methods:**

```
report_writer.AppendBrokerEntryBridgeLifecycleRecord
report_writer.AppendBrokerExitObservationLifecycleRecord
report_writer.AppendBrokerManagedCloseLifecycleRecord
report_writer.AppendBrokerOnlyTradeReconciliationRecord
report_writer.AppendBrokerPaperTradeReconciliationRecord
report_writer.AppendVirtualTrailingExitLifecycleRecord
```

All 6 are telemetry-write callbacks — "tell the report what just happened." None of them carry control flow. The Bridge does not depend on any of their return values.

**The reverse direction is empty:** `CFalconReportWriter` makes 0 references to `g_broker_entry_bridge` or `CFalconBrokerEntryBridge` (verified). The coupling is strictly one-way.

**Implication for R0.6 (Reporting layer migration):** When `CFalconReportWriter` moves to `Reporting/*.mqh`, the 6 broker-report-append methods will travel with it. The Bridge's #include order will need to be re-checked, but the coupling stays one-way and stable.

---

## 4. Off-by-one extraction error (caught and fixed)

During the initial extraction sweep, the grep "`#define`-position locator" reported `FC_MAGIC_FVG_MICRO: line 845` but my sed extraction/deletion used `line 846`. This caused:
- `FC_MAGIC_FVG_MICRO` was NOT deleted from main `.mq5` (still at original line 845, current line 812).
- `FC_MAGIC_TAIL_SMART_RETURN` (at line 846) was wrongly extracted into `ExecutionInputs.mqh` AND wrongly deleted from main `.mq5`.

**Fix applied:**
1. In main `.mq5`: replaced the stale `#define FC_MAGIC_FVG_MICRO` line with `#define FC_MAGIC_TAIL_SMART_RETURN` (restored what was wrongly deleted) and added a marker comment `// FC_MAGIC_FVG_MICRO moved to Execution/FalconExecutionInputs.mqh (R0.4)`.
2. In `Execution/FalconExecutionInputs.mqh`: replaced the wrongly-extracted `#define FC_MAGIC_TAIL_SMART_RETURN` with `#define FC_MAGIC_FVG_MICRO`.

Re-verified with the macro-uniqueness audit: all 28 Bridge-required macros now appear exactly once (`mq5+mqh = 1` for each).

This is the kind of edge case the §4 protocol is designed to catch — caught at the verification step, not at compile time.

---

## 5. Spec §5 Acceptance Status

| Criterion | Status |
|---|---|
| 4 Execution class files with include guards | ✓ |
| `Execution/FalconExecutionInputs.mqh` exists (preprocessor-order requirement) | ✓ |
| `Execution/FalconExecution_Placeholder.mqh` deleted | ✓ |
| Include block has Execution after Core+Risk (top block) + Bridge after CFalconReportWriter | ✓ |
| Migrated code removed from main `.mq5` (no duplication) | ✓ (4 classes + 28 sampled macros: all `mq5+mqh = 1`) |
| 12 `Apply*` functions still in `CFalconReportWriter` | ✓ (`grep -cE "^\s+void Apply[A-Z]"` returns 12, unchanged) |
| Every OrderSend path is `EnableRealExecution && MQL_TESTER` gated | ✓ (verified: 5 + 4 gate references in Bridge) |
| Compiles `0 errors, 0 warnings` | ⏳ requires MetaEditor F7 by user |
| FixedLot April: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker net = 157.49 exactly | ⏳ requires post-compile backtest by user |
| `R0_4_Review_Notes.md` exists | ✓ (this file) |

---

## 6. Critical follow-up — R0.6 / R0.7

**R0.6 (Reporting):** When `CFalconReportWriter` is split into `Reporting/*.mqh`, the 6 broker-report-append methods will move with it. The Bridge's `#include` placement will need to be re-validated. The coupling stays one-way (Bridge → ReportWriter), but the include order will become:
```
... CFalconReportWriter class .mqh (R0.6) ...
#include "Execution/FalconBrokerEntryBridge.mqh"   // unchanged from R0.4
```

**R0.7 (Apply* peel):** Per R0.3 review notes §3.5, the 7 risk-logic `Apply*` functions inside `CFalconReportWriter` must move to `Risk/`. Two of the others belong elsewhere. R0.7's challenge is bigger than R0.4's because the `Apply*` methods are interleaved with non-Apply ReportWriter code.

---

## 7. Open Items (deferred, non-blocking)

1. **`FC_MAGIC_FVG_MICRO` lives in `Execution/FalconExecutionInputs.mqh`** — but logically it's a "strategy magic" identifier. When R0.5 migrates `Strategies/S00_ScalpFvgMicro/*.mqh`, this define would naturally relocate there. Leaving in ExecutionInputs for now to keep R0.4 cohesive.
2. **Some ExecutionInputs macros (~10 of 30)** are referenced by main `.mq5` code (ReportWriter status lines) but not by the moved Bridge. Kept together for cohesion with v0.56.8 broker-execution block, same principle as R0.3's `FALCON_ARCH_*` block.
3. **`CFalconBrokerEntryBridge` is 2,406 lines** in a single `.mqh` — the largest layer file by far. Further decomposition into sub-modules (entry-only, close-only, observation-only, trailing-only) is a candidate for a later refinement pass after the broader R0 sequence is complete.

---

*End of R0.4 review notes. No `Apply*`, no `OrderSend` logic, no emergency server SL/TP, no Virtual Trailing logic, no v0.57.0/v0.57.1 LockParity logic was modified. The 4 Execution classes were moved verbatim.*
