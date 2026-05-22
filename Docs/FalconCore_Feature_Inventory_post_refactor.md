# FalconCore — Feature Inventory (Post-Refactor)

> Read-only snapshot of the codebase shape after R0 structural refactor.
> Working tree: `refactor` branch, after R0.9 closure commit.
> Companion to the broader-feature snapshot in
> `FalconCore_Feature_Inventory_v0_57_4.md` (which still catalogs every
> input, method, and report-file emitted by the pre-refactor monolith;
> the structural facts in that file are now superseded by this one).

This file does **not** replicate the input catalog or per-method dump
from the v0.57.4 inventory. Its job is to answer "where does each piece
of the system live now, and how do they fit together?" — the question
R1.x will keep asking as it builds the scalp strategy on top.

---

## 1. Version tags (post-refactor)

| Constant | Value | Source |
|---|---|---|
| `EA_VERSION_TAG` | `"R0_9"` (was `"v0.57.4"` pre-refactor) | `Core/FalconConstants.mqh:10` |
| `EA_NAME` | `"JA FalconCore Automated Trading Platform"` | `Core/FalconConstants.mqh:9` |
| `EA_BUILD_TAG` | `"StructuralBreakeven"` (unchanged) | `Core/FalconConstants.mqh:11` |

The R0.8b → R0.8c → R0.9 sequence bumped the tag once per phase. Report
file names carry this tag, so each refactor phase emits its own report
bucket.

---

## 2. File layout — final post-R0 structure

```
JA-FalconCore-Automated-Trading-Platform/
├── JA_FalconCore_Automated_Trading_Platform.mq5      (~6,024 lines — main glue)
├── Core/                  (foundations: constants, enums, structs, logging,
│   ├── FalconConstants.mqh                  ─── market context, candle cache)
│   ├── FalconEnums.mqh
│   ├── FalconCoreInputs.mqh
│   ├── FalconDataStructures.mqh
│   ├── FalconLogger.mqh
│   ├── FalconMarketContext.mqh
│   └── FalconCandleCache.mqh
│   (7 files, ~1,829 LOC)
│
├── Evidence/              (evidence framework)
│   └── FalconEvidenceFramework.mqh
│   (1 file, ~101 LOC)
│
├── Risk/                  (risk foundations + the 12-step Apply* chain
│   ├── FalconRiskInputs.mqh                 ─── + the data-bus contract)
│   ├── FalconRiskFoundation.mqh
│   ├── FalconRiskTradeManagement.mqh
│   ├── FalconTradeLifecycleContract.mqh
│   ├── FalconRiskLifecycleProcessorInputs.mqh
│   └── FalconRiskLifecycleProcessor.mqh     (owns the 12 Apply* + chain)
│   (6 files, ~1,991 LOC)
│
├── TradeManagement/       (placeholder folder — population R1.x+)
│   └── FalconTradeManagement_Placeholder.mqh
│   (1 file, ~8 LOC)
│
├── Execution/             (broker bridge, execution guard, runtime safety,
│   ├── FalconExecutionInputs.mqh            ─── shadow executor)
│   ├── FalconExecutionGuard.mqh
│   ├── FalconRuntimeSafetyGuard.mqh
│   ├── FalconShadowExecutor.mqh
│   └── FalconBrokerEntryBridge.mqh
│   (5 files, ~2,962 LOC)
│
├── Router/                (strategy registry + adapter shell)
│   ├── FalconRouterInputs.mqh
│   ├── FalconStrategyRegistry.mqh
│   └── FalconStrategyAdapterShell.mqh
│   (3 files, ~394 LOC)
│
├── Strategies/            (placeholder folder — S00 scalp built in R1.x)
│   ├── FalconStrategies_Placeholder.mqh
│   └── S00_ScalpFvgMicro/FalconScalpFvgMicro_Placeholder.mqh
│   (2 files, ~16 LOC)
│
├── Reporting/             (CFalconReportWriter monolith — ~5,313 LOC;
│   └── FalconReportWriter.mqh               ─── internal split deferred)
│   (1 file, ~5,313 LOC)
│
└── Docs/
    ├── Specs/             (in-flight SPECs; completed-phase SPECs deleted)
    ├── ReviewNotes/       (one Review_Notes.md per R0 phase)
    ├── ProjectMemory/     (snapshot at each phase milestone)
    ├── Archive/           (CSVs + patches preserved for reference)
    ├── Ideas_Backlog.md
    ├── Architecture_PostRefactor.md
    ├── FalconCore_Feature_Inventory_v0_57_4.md            (pre-refactor)
    ├── FalconCore_Feature_Inventory_post_refactor.md      (this file)
    └── falconcore_ea_operational_rules.md
```

**Layer total: ~12,634 LOC across the layer folders, plus ~6,024 LOC in
the main `.mq5` glue.** Pre-refactor was a single 17,343-line `.mq5`;
post-refactor splits roughly 65% / 35% main-vs-layered.

---

## 3. Class location map

Every `CFalcon*` class and where it lives after R0:

### 3.1 Layer-owned (16 classes)

| Class | File | Layer |
|---|---|---|
| `CFalconLogger` | `Core/FalconLogger.mqh` | Core |
| `CFalconMarketContext` | `Core/FalconMarketContext.mqh` | Core |
| `CFalconCandleCache` | `Core/FalconCandleCache.mqh` | Core |
| `CFalconEvidenceFramework` | `Evidence/FalconEvidenceFramework.mqh` | Evidence |
| `CFalconRiskFoundation` | `Risk/FalconRiskFoundation.mqh` | Risk |
| `CFalconRiskLifecycleProcessor` | `Risk/FalconRiskLifecycleProcessor.mqh` | Risk |
| `CFalconRiskTradeManagementArchitecture` | `Risk/FalconRiskTradeManagement.mqh` | Risk |
| `CFalconBrokerEntryBridge` | `Execution/FalconBrokerEntryBridge.mqh` | Execution |
| `CFalconExecutionGuard` | `Execution/FalconExecutionGuard.mqh` | Execution |
| `CFalconRuntimeSafetyGuard` | `Execution/FalconRuntimeSafetyGuard.mqh` | Execution |
| `CFalconShadowExecutor` | `Execution/FalconShadowExecutor.mqh` | Execution |
| `CFalconFirstShadowStrategyAdapterShell` | `Router/FalconStrategyAdapterShell.mqh` | Router |
| `CFalconStrategyRegistry` | `Router/FalconStrategyRegistry.mqh` | Router |
| `CFalconReportWriter` | `Reporting/FalconReportWriter.mqh` | Reporting |

### 3.2 Still in main `.mq5` (5 FVG-Micro classes)

| Class | Source line | Notes |
|---|---:|---|
| `CFalconFvgMicroShadowDetectorStub` | `JA_FalconCore_Automated_Trading_Platform.mq5:4031` | Strategy-adjacent; awaits S00 scalp population |
| `CFalconFvgMicroShadowCandidateBuilder` | `4321` | — |
| `CFalconFvgMicroRetestWatcher` | `4553` | — |
| `CFalconFvgMicroTradePlanStagingDryRun` | `4981` | — |
| `CFalconFvgMicroShadowLifecycleSimulation` | `5271` | — |

These were intentionally left inline because R1.x's S00 scalp strategy
is the next consumer — they will likely move into
`Strategies/S00_ScalpFvgMicro/` then. Moving them now (before the
strategy interface is finalized) would invite a second move.

---

## 4. The 12-step Apply\* chain — single owner

All 12 `Apply*` methods live as `private` members of
`CFalconRiskLifecycleProcessor` (`Risk/FalconRiskLifecycleProcessor.mqh`).
Verify counts:

```
^   void Apply[A-Z]  in Risk/FalconRiskLifecycleProcessor.mqh : 13
   (12 private Apply* + 1 public ApplyTradeLifecycleChain)
^   void Apply[A-Z]  in Reporting/FalconReportWriter.mqh      : 0
^   void Apply[A-Z]  in JA_FalconCore_Automated_Trading_Platform.mq5 : 0
```

### 4.1 Load-bearing call order (NOT ascending)

`ApplyTradeLifecycleChain(record, totals)` invokes them in:

```
#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12
```

#### Why this order is load-bearing
- `#10 ApplyDynamicLotSizingModel` runs **before** `#9 ApplyCalibratedSingleTradeLossCapEnforcement` — the cap reads the lot decision.
- `#1 / #2` (user-override pair) run **after** `#7–#10` — they override the lot AFTER it's decided.
- `#11 ApplyThreeLayerEmergencyApplication` reads market-close state set by `#1 / #2`.
- `#3 ApplyFvgQualityShadowGuardSimulation` is a pre-chain filter — runs first.
- `#12 ApplyCapitalFlowSourceClassification` is post-chain annotation — runs last.

Documented inside `ApplyTradeLifecycleChain` itself (see
`Risk/FalconRiskLifecycleProcessor.mqh:~1586`).

### 4.2 The 12 + `ApplyTradeLifecycleChain`

| # | Method (private on processor) | Role |
|---|---|---|
| 3 | `ApplyFvgQualityShadowGuardSimulation` | FVG quality pre-filter |
| 4 | `ApplyPaperRuntimeGuardApplication` | Paper runtime guard |
| 5 | `ApplyPaperRuntimeSmartSLProtectionApplication` | Paper SL protection |
| 6 | `ApplyPaperRuntimeRunnerApplication` | Paper runner |
| 7 | `ApplyCapitalTierFoundation` | Capital tier classification |
| 8 | `ApplyLowCapitalRiskFeasibilityFoundation` | Low-capital feasibility |
| 10 | `ApplyDynamicLotSizingModel` | DLM (lot decision) |
| 9 | `ApplyCalibratedSingleTradeLossCapEnforcement` | Single-trade loss cap |
| 1 | `ApplyNoNewEntryUserOverridePaperEnforcement` | No-new-entry user override |
| 2 | `ApplyDailyWeekendForceCloseUserOverridePaperEnforcement` | Daily/weekend force-close (takes `totals`) |
| 11 | `ApplyThreeLayerEmergencyApplication` | Three-layer emergency |
| 12 | `ApplyCapitalFlowSourceClassification` | Capital-flow classification |
| — | `ApplyTradeLifecycleChain(record, totals)` | Public entry (the only one called from outside the class) |

### 4.3 Sole caller

`CFalconReportWriter::RegisterClosedTrade` (`Reporting/FalconReportWriter.mqh:~3906`):

```cpp
g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record, m_totals);
```

One call site, one direction.

---

## 5. State ownership (post-R0.8b)

| State | Owner | Reader(s) | How |
|---|---|---|---|
| `m_symbol_context` | `CFalconRiskLifecycleProcessor` | RW via `SymbolContext()` forwarder | Returns by value |
| `m_tle_*` (8 fields) | `CFalconRiskLifecycleProcessor` | Processor only (Apply #11 + day-boundary checks) | Direct member access |
| `m_dlm_*` (2 fields) | `CFalconRiskLifecycleProcessor` | Processor only (Apply #10) | Direct member access |
| `m_totals` (`FalconReportTotals`) | `CFalconReportWriter` | RW + processor Apply #2 (via `FalconReportTotals &totals` chain param) | RW direct; processor via reference param |

The duplicated-state bug that broke `FinalWorkingNetUSD` in R0.7cd
(latched processor `m_tle_emergency_active` with reset code operating
on RW's separate copy) is now structurally impossible — each piece of
state has exactly one owner.

---

## 6. Globals (post-rollback inventory — 86 file-scope `g_*`)

R0.8c attempted to reduce to 29 via classification (48 dead + 9
localize) but the main `.mq5` deletions were rolled back in commit
`ae556ea`. The current file-scope count is **86**, broken down as:

| Bucket | Count | Examples |
|---|---:|---|
| Layer-singleton class instances | 18 | `g_report_writer`, `g_risk_lifecycle_processor`, `g_market_context`, etc. |
| Runtime state singletons | 4 | `g_is_initialized`, `g_runtime_tick_counter`, `g_last_processed_m5_closed_candle_time`, `g_last_staged_fvg_candidate_id` |
| Capital baseline | 1 | `g_falcon_session_start_balance` |
| Report-period state | 8 | `g_report_period_first_time`, `..._last_time`, `..._initial_from_tag`, `..._initial_to_tag`, `..._active_from_tag`, `..._active_to_tag`, `..._initialized`, `..._finalized` |
| FVG-micro candidate counters | 9 | `g_fvg_micro_candidate_builder_evaluations`, `..._detected_candidates`, ... |
| FVG quality profile counters | 9 | `g_fvg_quality_calibration_evaluated`, `..._profile_balanced_passed`, ... |
| FVG quality distribution + spread buckets | 12 | `g_fvg_quality_distribution_count`, `..._size_min_points`, `..._spread_le_50_count`, ... |
| FVG retest + hold quality counters | 15 | `g_fvg_retest_watch_evaluated`, `..._touched`, `g_fvg_hold_quality_score_min`, ... |
| OTTU broker-event counters | 4 | `g_ottu_transactions_observed`, `..._deal_events_routed`, ... |
| FVG qguard runtime counters | 6 | `g_fvg_qguard_runtime_candidate_evaluated`, `..._candidate_passed`, ... |

The 67 counter globals (everything below the runtime + capital +
report-period bucket) are telemetry that's written but largely
un-consumed by any reporting writer. See `Docs/Ideas_Backlog.md` #19
for the post-R0 cleanup pattern.

---

## 7. Include graph (main `.mq5` top, condensed)

```
Core/FalconConstants.mqh                                   (L15)
Core/FalconEnums.mqh                                       (L16)
Core/FalconCoreInputs.mqh                                  (L17, preproc gate)
Core/FalconDataStructures.mqh                              (L18)
Core/FalconLogger.mqh                                      (L19)
Core/FalconMarketContext.mqh                               (L20)
Core/FalconCandleCache.mqh                                 (L21)
…
Evidence/FalconEvidenceFramework.mqh                       (L27)
Risk/FalconRiskInputs.mqh                                  (L28, preproc gate)
Risk/FalconRiskFoundation.mqh                              (L29)
Risk/FalconRiskTradeManagement.mqh                         (L30)
…
Risk/FalconTradeLifecycleContract.mqh                      (L41)
Risk/FalconRiskLifecycleProcessorInputs.mqh                (L42, preproc gate)
Risk/FalconRiskLifecycleProcessor.mqh                      (L43)
…
Execution/FalconExecutionInputs.mqh                        (L56, preproc gate)
Execution/FalconExecutionGuard.mqh                         (L57)
Execution/FalconRuntimeSafetyGuard.mqh                     (L58)
Execution/FalconShadowExecutor.mqh                         (L59)
…
Router/FalconRouterInputs.mqh                              (L76, preproc gate)
Router/FalconStrategyRegistry.mqh                          (L77)
Router/FalconStrategyAdapterShell.mqh                      (L78)
…
Reporting/FalconReportWriter.mqh                           (L5639, mid-file)
Execution/FalconBrokerEntryBridge.mqh                      (L5663, after RW)
```

Two mid-file includes (`Reporting/FalconReportWriter.mqh` at L5639 and
`Execution/FalconBrokerEntryBridge.mqh` at L5663) are deliberate — they
sit where the FVG-Micro classes finish being declared inline in the
main `.mq5`, so by the time the writer / bridge are parsed they can see
the FVG-Micro types. Moving them to the top would require also moving
the FVG-Micro classes (which is R1.x scope).

---

## 8. What changed vs. `FalconCore_Feature_Inventory_v0_57_4.md`

The pre-refactor inventory was generated when the entire EA lived in
one 17,343-line `.mq5`. It catalogs:

- **46 input variables** across 6 input groups — STILL VALID. Inputs
  were not added or removed during R0 refactor (per spec's "zero
  behavior change" mandate, including for R0.6b which added group
  switches via `Enable*Reports` `#define`s, not new `input` keywords).
- **All `CFalcon*` methods** — STILL VALID by name and signature
  (R0.8b changed `ApplyTradeLifecycleChain`'s signature to take
  `FalconReportTotals &totals` — see §4 above). All other methods are
  byte-identical moves into their new layer files.
- **Report file names** — STILL VALID, but the `EA_VERSION_TAG`
  embedded in each name now reads `R0_9` instead of `v0.57.4`.

The structural facts (file paths, line numbers, "everything in one
file") are now stale — this post-refactor inventory replaces them.

---

## 9. Cross-references

- **Per-phase migrations:** see each `Docs/ReviewNotes/R0_X_Review_Notes.md`.
- **Architecture diagram + dependency direction:** see
  `Docs/Architecture_PostRefactor.md`.
- **Open items for R1.x and beyond:** see `Docs/Ideas_Backlog.md`.
- **Original refactor goals + completion status:** see
  `Docs/ReviewNotes/R0_9_Review_Notes.md` §3 (success criteria
  cross-check).

---

*End of post-refactor inventory. The refactor (R0 series) is complete.
Strategy work (R1.x — S00 scalp on FVG-Micro retest) is the next mile.*
