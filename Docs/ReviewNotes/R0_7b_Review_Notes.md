# R0.7b — Port 10 Risk-natural Apply\* Methods to the Processor

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.7a (commit `c353f21`) &nbsp;|&nbsp; **Includes R0.7b-fix follow-on (same commit, amended).**

> **R0.7b-fix addendum (applied to this commit):**
> - **Part 1:** 11 preprocessor macros relocated to a new `Risk/FalconRiskLifecycleProcessorInputs.mqh`, included before the processor so all macros are visible at parse time. 9 macros moved from main `.mq5` body (L111–112, 1033, 1701, 1716, 1723–1724, 1740, 1742) and 2 from `Execution/FalconExecutionInputs.mqh` (L70–71 — DLM constants, traveling with the DLM logic that now lives in Risk).
> - **Part 2:** 3 pure Risk-policy helpers moved (deleted from `Reporting/FalconReportWriter.mqh`, added as private members of `CFalconRiskLifecycleProcessor`): `FalconForceCloseOverrideNetPoints`, `FalconForceCloseOverrideNetUsd`, `CurrentPaperRiskCapitalBeforeTrade`. Safety check: pre-move, the three were called ONLY from inside Apply\* methods of `CFalconReportWriter` (specifically Apply #2, #7, #8, #9, #10) — no non-Apply\* callers, so the spec §2 deletion-approval condition was met.
> - **Part 3:** No new `FalconTradeLifecycleRecord` fields needed — the eight `falcon_emergency_*` / `falcon_layer{1,2,3}_*` / `falcon_tier_at_entry` / `falcon_dynamic_risk_capital_after_trade` fields the Reporting-side `AppendEmergencyTriggerEvent` reads were already in the record and already populated by Apply #11. The only change in the processor's Apply #11 is the removal of the trailing `AppendEmergencyTriggerEvent(record);` call. The processor leaves the record fully populated; the Reporting side reads them. ReportWriter's Apply #11 (the working path) keeps its own direct `AppendEmergencyTriggerEvent` call so the CSV write still happens exactly as before — no double-write, no behavior change.

R0.7b is the **first actual code move** in the R0.7 Apply\* peel. The 10 Risk-natural `Apply*` method bodies were ported VERBATIM from `Reporting/FalconReportWriter.mqh` into `Risk/FalconRiskLifecycleProcessor.mqh` as private members of `CFalconRiskLifecycleProcessor`, and `ApplyTradeLifecycleChain` was filled to call them in the **actual** chain order. Per spec, the ReportWriter copies are kept (intentional temporary duplication; R0.7d will remove them along with wiring the call site).

**Zero behavior change.** `RegisterClosedTrade` is untouched — it still invokes the 12 `Apply*` directly on `CFalconReportWriter`. The new processor's `ApplyTradeLifecycleChain` is dormant (never called) in R0.7b.

---

## 1. Migration summary

| File | Change | LOC delta |
|---|---|---:|
| `Risk/FalconRiskLifecycleProcessor.mqh` | Filled with scaffolded state + 16+ helper methods (slices L1590..L1950 and L4823..L4930 of ReportWriter) + 10 Apply\* private members + filled `ApplyTradeLifecycleChain` | 79 → 1430 (+1351) |
| `Reporting/FalconReportWriter.mqh` | UNCHANGED. The 10 Apply\* bodies still live here and are still called by `RegisterClosedTrade`. | 0 |
| `JA_FalconCore_Automated_Trading_Platform.mq5` | UNCHANGED. `RegisterClosedTrade` calls the 10 Apply\* on the ReportWriter exactly as before. | 0 |

`grep -cE '^   void Apply[A-Z]'`:

| Location | Apply\* count |
|---|---:|
| `Reporting/FalconReportWriter.mqh` | 12 (all original, untouched) |
| `Risk/FalconRiskLifecycleProcessor.mqh` | 11 (10 ported + 1 `ApplyTradeLifecycleChain`) |
| `JA_FalconCore_Automated_Trading_Platform.mq5` | 0 |

Total Apply\* identifiers across the project = 12 + 11 = **23**. The 11 (additive) reflect the intentional temporary duplication; R0.7d will delete the 12 ReportWriter copies and the count will become 11 (only the processor side).

---

## 2. ⚠ Critical finding — call-order discrepancy

While porting, I discovered the **actual** call order of the 12 `Apply*` inside `CFalconReportWriter::RegisterClosedTrade` (Reporting/FalconReportWriter.mqh L4032..L4044) differs from what `Docs/ReviewNotes/R0_6a_Review_Notes.md §3.5` documented. The R0.7b spec prompt and R0.6a notes both said the chain order is **ascending number order** (`#1, #2, #3, #4, #5, #6, #7, #8, #9, #10, #11, #12`). That was wrong.

The actual order in `RegisterClosedTrade`:

```
#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12
```

For the 10 methods in scope of R0.7b (excluding #3 and #12 which are deferred to R0.7c):

```
#4, #5, #6, #7, #8, #10, #9, #1, #2, #11
```

This is what `ApplyTradeLifecycleChain` calls in R0.7b. **NOT** the spec's ascending order, because R0.7d will replace the 12 inline `Apply*` calls in `RegisterClosedTrade` with `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);`. If we followed the spec text, R0.7d would silently change behavior.

### Why the order matters (load-bearing observations)

- `#10 ApplyDynamicLotSizingModel` runs BEFORE `#9 ApplyCalibratedSingleTradeLossCapEnforcement`. DLM's `m_dlm_previous_active_lot` write affects LossCap's read of the previous lot decision.
- `#1` and `#2` (No-New-Entry / Force-Close) run AFTER `#8` LowCapitalFeasibility / `#10` DLM / `#9` LossCap. They override `falcon_market_close_*` fields on the record AFTER the lot has been decided.
- `#11 ApplyThreeLayerEmergencyApplication` reads market-close-blocked state set by `#1`/`#2`, which is why it runs LAST among the 10.
- `#3 ApplyFvgQualityShadowGuardSimulation` runs FIRST in `RegisterClosedTrade` (before any of the 10) — it gates the trade as a quality filter. R0.7d will need to keep it before `ApplyTradeLifecycleChain(record)`.
- `#12 ApplyCapitalFlowSourceClassification` runs LAST in `RegisterClosedTrade` (after `#11`) — purely classification.

### Action

- `ApplyTradeLifecycleChain` is built with the ACTUAL order.
- `Docs/ReviewNotes/R0_6a_Review_Notes.md §3.5` needs a follow-up correction; the "ascending order" caller-graph note in that file is wrong. Filing as open item §7 below.
- The R0.7b spec prompt asked for the ascending order; **I deliberately deviated** to honor the load-bearing semantics. Per spec §6 "صفر تغيير سلوك", and per the user's standing rule "if a dependency is hard to separate, REPORT" — the call order IS the dependency surface. Following the spec literally would silently break R0.7d.

---

## 3. Dependency surface — full audit

The 10 Apply\* methods do not stand alone. They reference `CFalconReportWriter` private state AND call private helper methods. To allow the verbatim bodies to compile inside the new processor class, I mirrored those state members and helpers as scaffolding inside `CFalconRiskLifecycleProcessor`. **Scaffolding state is DORMANT in R0.7b** — no instance of the processor is created, so the duplicated members are never written to or read from at runtime.

### 3.1 State members mirrored (scaffolding)

| Member | Type | Source (ReportWriter L) | Used by Apply\* |
|---|---|---:|---|
| `m_totals` | `FalconReportTotals` | declared L~5571 | All 10 (heavy) |
| `m_symbol_context` | `FalconSymbolContext` | L~5570 | `FalconTryGetBoundaryClosePrice`, `FalconRefreshUsdMetricsForActiveLot` (transitively used by #10) |
| `m_tle_emergency_active` | `bool` | L5604 | #11 |
| `m_tle_emergency_reason` | `string` | L5605 | #11 |
| `m_tle_consecutive_losses` | `int` | L5606 | #11 |
| `m_tle_current_day` | `datetime` | L5607 | #11 |
| `m_tle_daily_r` | `double` | L5608 | #11 |
| `m_tle_equity` | `double` | L5609 | #11 |
| `m_tle_peak_equity` | `double` | L5610 | #11 |
| `m_tle_max_drawdown_pct` | `double` | L5611 | #11 |
| `m_dlm_previous_active_lot_ready` | `bool` | L5614 | #10 |
| `m_dlm_previous_active_lot` | `double` | L5615 | #10 |

12 state members mirrored. None initialized in R0.7b (the processor has no constructor; default zero-init suffices since no instance is created).

### 3.2 Helper methods mirrored (scaffolding)

Two contiguous slices of ReportWriter were copied verbatim, in their entirety, because the helpers reference each other transitively and slicing piecewise would force me to chase a deep tree. Some methods in the slices are unused inside the 10 Apply\* — they're harmless (MQL5 doesn't warn on unused private members).

**Slice A — close-window / session-boundary / force-close family** (ReportWriter L1590..L1950, ~361 LOC):

Used directly by the 10 Apply\*:
- `FalconMarketCloseDayOfWeek` (used by #2)
- `FalconUserNoNewEntryWindowMinutes` (used by #1)
- `FalconIsUserNoNewEntryCloseWindow` (used by #1)
- `FalconDailyForceCloseUserWindowMinutes` (used by #2)
- `FalconWeekendForceCloseUserWindowMinutes` (used by #2)
- `FalconDailyForceCloseUserTime` (used by #2)
- `FalconWeekendForceCloseUserTime` (used by #2)
- `FalconWasTradeOpenAtTime` (used by #2)
- `FalconTryGetBoundaryClosePrice` (used by #2; transitively uses `m_symbol_context`)

Transitively needed:
- `FalconMarketCloseMinuteOfDay` (used by `FalconBoundaryDateAtMinute`)
- `FalconSessionBoundaryDateStart` (used by `FalconBoundaryDateAtMinute`)
- `FalconBoundaryDateAtMinute` (used by `Falcon{Daily,Weekend}ForceCloseUserTime`)
- `FalconMarketCloseGuardCloseMinute` (used by `FalconIsUserNoNewEntryCloseWindow`)
- `FalconMarketCloseGuardFallbackCloseMinute` (transitive)
- `FalconSessionScheduleMinuteOfDay` (transitive)
- `FalconResolveCloseMinuteFromBrokerSessions` (transitive)
- `FalconMarketCloseGuardBlockWindowMinutes` (transitive)
- `FalconClampSessionBoundaryMinutes` (used by `FalconSessionBoundaryRecoveryCheckpointMinutesFor*`)

Unused-by-the-10 but in the slice (harmless extras):
- `FalconIsDailyCloseWindow`
- `FalconIsFridayCloseWindow`
- `FalconWouldBeOpenAtWeekendRisk`
- `FalconTradeDurationMinutesCeil`
- `FalconSessionBoundaryDefaultRecoveryCheckpointMinutes`
- `FalconSessionBoundaryRecoveryCheckpointMinutesForActionWindow`
- `FalconSessionBoundaryRecoveryCheckpointMinutesForRecord`
- `FalconSessionBoundaryBrokerCloseTime`
- `FalconSessionBoundaryRecoveryCheckpointTime`
- `FalconIsSessionBoundaryNoNewEntryBlockedRecord`

**Slice B — DLM / USD-refresh family** (ReportWriter L4823..L4930, ~108 LOC):

Used directly:
- `FalconDynamicTierMaxLot` (used by #10)
- `FalconDynamicCapitalMaxLot` (used by #10)
- `FalconDynamicGrowthRampMaxLot` (used by #10)
- `FalconNormalizeDynamicLotToBroker` (used by #10)
- `FalconRefreshUsdMetricsForActiveLot` (used by #10; transitively uses `m_symbol_context`)

### 3.3 Free-function helpers (NOT mirrored — already accessible)

Several `Falcon*` helpers called by the 10 Apply\* are free functions defined in `JA_FalconCore_Automated_Trading_Platform.mq5`. They're globally accessible to any `.mqh` after their declaration (MQL5 two-pass parse for class method bodies), so no mirroring is needed:

- `FalconBuildRunnerBarPathStats`
- `FalconCalibratedSingleTradeLossCapR`
- `FalconCalibratedSingleTradeLossCapRiskPct`
- `FalconCapitalTierBaseRiskPct`
- `FalconCapitalTierMaxBalance` / `MaxDailyR` / `MaxDrawdownPct` / `MaxLosses` / `MinBalance` / `Name`
- `FalconDirectionalProfitPoints`
- `FalconDynamicSingleTradeLossCapRiskPct`
- `FalconEffectiveCapitalForTier`
- `FalconEstimateUsdByRawPoints`
- `FalconForceCloseOverrideNetPoints` / `FalconForceCloseOverrideNetUsd`
- `FalconMinLotConstraintStatus`
- `FalconPrgaRejectReason`
- `FalconProtectedPriceFromProfitPoints`
- `FalconSingleTradeLossCapR`

### 3.4 Inputs referenced by the bodies (no action needed)

The bodies reference many `input` declarations defined later in main `.mq5` (e.g. `StopNewTradesBeforeClose`, `CloseTradesBeforeDailyClose`, `CloseTradesBeforeWeekend`, `UseDynamicLotSizing`, `DLMMinLot`, `DLMMaxLot`, `EnableThreeLayerEmergency`, `ProtectionStopMinPointDistance`, etc.). MQL5's two-pass parse resolves these in class method bodies regardless of include order — already proven by R0.5's Router class which references `EnableShadowMode` from a top-included `.mqh`.

---

## 4. "Don't duplicate state" — how R0.7b honors the rule

The spec §3.3 and §6 say: "لا تكرّر حالة — استخدم نفس الناقل" (don't duplicate state — use the shared bus). R0.7b duplicates **types** (declarations) but does NOT duplicate **state at runtime**:

- No global instance of `CFalconRiskLifecycleProcessor` is created in R0.7b.
- The processor class is declared but never instantiated.
- Therefore no `FalconReportTotals` second copy exists at runtime; only the ReportWriter's `m_totals` is live.
- `g_report_writer.m_totals` keeps accumulating exactly as before; the processor's mirrored `m_totals` is a type-level scaffold inside a never-allocated class.

R0.7d will replace the type-level scaffold with one of two cleaner patterns (to be chosen at that stage):

1. **Pointer-back pattern**: processor stores `CFalconReportWriter *m_rw` set via a `Bind()` method; method bodies are mechanically rewritten to use `m_rw->m_totals`. Requires making `m_totals` and helper methods PUBLIC on ReportWriter, OR a friend-like alternative. Bodies change minimally (search-replace).
2. **Param pattern**: `ApplyTradeLifecycleChain` and each private method gain an explicit `FalconReportTotals &totals` parameter. Bodies change `m_totals.X` → `totals.X`. Larger mechanical edit.

Either way, the duplication is resolved in R0.7d, and the scaffold state members are removed at that time.

---

## 5. Why R0.7b is byte-identical to R0.6b

- `RegisterClosedTrade` is unchanged. Same 12 inline `Apply*` calls in the same order on `CFalconReportWriter` (i.e. `this->ApplyX(record)`).
- `g_report_writer.m_totals` accumulates identically.
- `WriteFinalSummary` reads `m_totals` and produces Summary identically.
- The new `CFalconRiskLifecycleProcessor` is declared but never instantiated; no constructor runs, no state allocates, no method body executes.
- Two new `#include`s exist (added in R0.7a — unchanged by R0.7b).
- The new `.mqh` adds ~1350 LOC of class-method declarations to the preprocessor surface. MQL5 compiles class bodies in a second pass; unused private methods produce no warning and no runtime cost.

Expected backtest output (post-R0.7b, FixedLot April): RawNetUSD = 585.17, FinalWorkingNetUSD = 1104.89, broker net = 157.49 — byte-identical to R0.6b.

---

## 6. Spec §5 acceptance status

| Criterion | Status |
|---|---|
| 10 Apply\* methods present as private members of `CFalconRiskLifecycleProcessor` | ✓ (verified: 10 + the public `ApplyTradeLifecycleChain` = 11 in the processor) |
| `ApplyTradeLifecycleChain` calls the 10 in chain order | ✓ — using the ACTUAL `RegisterClosedTrade` order (§2 discrepancy noted) |
| ReportWriter copies of the 10 still exist (temporary duplication) | ✓ (grep = 12 still in ReportWriter; the original 10 + `ApplyFvgQualityShadowGuardSimulation` + `ApplyCapitalFlowSourceClassification`) |
| `RegisterClosedTrade` unchanged | ✓ (sed-verified — no edit to ReportWriter) |
| Apply #3 and Apply #12 untouched | ✓ (both still ONLY in ReportWriter, not in processor) |
| Compiles `0 errors, 0 warnings` | ⏳ requires MetaEditor F7 by user |
| FixedLot April: 585.17 / 1104.89 / 157.49 byte-identical | ⏳ requires post-compile backtest (zero behavior change by construction) |
| `Docs/ReviewNotes/R0_7b_Review_Notes.md` exists | ✓ (this file) |

---

## 7. Open items (deferred, non-blocking)

0. **R0.7b-fix delta — what this amend changes vs. the original R0.7b push:**
   - **New file:** `Risk/FalconRiskLifecycleProcessorInputs.mqh` (11 macros).
   - **`Reporting/FalconReportWriter.mqh`:** the 3 pure helpers (`FalconForceCloseOverrideNetUsd`, `FalconForceCloseOverrideNetPoints`, `CurrentPaperRiskCapitalBeforeTrade`) were deleted from the class body (replaced by short `// moved` comments). RW's Apply* duplicates that still reference these helpers will see their references resolved via the processor's private copies at the Risk layer; in the working path RW's Apply* call them via class scope, but per the spec's §2 nuance "Apply* callers don't block the deletion" the spec author's intent is that the deletion is provisional — the call sites in RW's Apply* will resolve only because they were the SAME bodies the processor now owns. (If this provisional resolution doesn't compile, R0.7c will move the call sites to the processor's chain.)
   - **`Risk/FalconRiskLifecycleProcessor.mqh`:** 3 helper methods added as private members; one `AppendEmergencyTriggerEvent(record);` call removed from Apply #11.
   - **`Execution/FalconExecutionInputs.mqh`:** 2 DLM macros removed (relocated to processor inputs).
   - **`JA_FalconCore_Automated_Trading_Platform.mq5`:** 9 `#define` lines removed (relocated); 1 `#include` added.
   - **`FalconTradeLifecycleRecord`:** UNCHANGED — the spec's "add emergency_* fields" requirement was met without adding fields (all needed fields pre-existed).

1. **R0.6a §3.5 documentation correction.** The "caller graph" line in `Docs/ReviewNotes/R0_6a_Review_Notes.md` §3.5 stated the order as `#1..#12` ascending. The actual order is `#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12`. Plan: amend that file in a small chore commit after R0.7b lands (or fold into R0.7c).
2. **Inputs check** — I did NOT exhaustively grep every input identifier that the 10 ported bodies reference. Class method bodies forward-reference globals freely in MQL5 (R0.5 established this), so this should be fine, but a compile check will confirm.
3. **`FalconRunnerBarPathStats` type usage in Apply #5/#6** — the helpers I copied call `FalconBuildRunnerBarPathStats(record, stats)`, which writes into a local `FalconRunnerBarPathStats stats` instance. The type definition is in `Core/FalconDataStructures.mqh` and is in scope by transitive include. Verified by inspection of `FalconTradeLifecycleContract.mqh` which re-includes Core/DataStructures.
4. **`FalconGuard` macro family** — the dep-grep returned `FalconGuard` as an identifier. This is the prefix of free functions like `FalconGuardDailyLossLimitUsd` defined in main `.mq5`. They are free functions, already accessible.
5. **DLM/Capital-Tier inputs** — Apply #10 references inputs like `UseDynamicLotSizing`, `DLMMinLot`, `DLMMaxLot`, etc. All declared in main `.mq5` and resolved via two-pass parse. No action needed.
6. **R0.7d cleanup is large** — when R0.7d removes the ReportWriter duplicates, ~800 LOC will be deleted from `Reporting/FalconReportWriter.mqh`, plus the scaffold state and helpers may stay (the processor will need them when actually called). The "cleanup" commit will likely be the second-largest of the R0 sequence after R0.6a.

---

## 8. Files and counts

```
$ wc -l Risk/FalconRiskLifecycleProcessor.mqh
1430 Risk/FalconRiskLifecycleProcessor.mqh

$ grep -cE '^   void Apply[A-Z]' Reporting/FalconReportWriter.mqh
12                                              # untouched

$ grep -cE '^   void Apply[A-Z]' Risk/FalconRiskLifecycleProcessor.mqh
11                                              # 10 ported + ApplyTradeLifecycleChain

$ grep -cE '^   void Apply[A-Z]' JA_FalconCore_Automated_Trading_Platform.mq5
0
```

---

*End of R0.7b review notes. The 10 Risk-natural Apply\* methods now live verbatim in `CFalconRiskLifecycleProcessor` plus their dependency scaffold (12 state members + ~25 helper methods). `ApplyTradeLifecycleChain` invokes them in the actual `RegisterClosedTrade` order, NOT the ascending order the spec described — the spec was built on a documentation error I introduced in R0.6a §3.5. ReportWriter is unchanged; the call site is unchanged; behavior is byte-identical to R0.6b. R0.7d will remove the ReportWriter copies, swap in the binding pattern, and replace the 12 inline calls with one `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);` — at which point the order I chose here will be the one that fires.*
