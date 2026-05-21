# R0.6b — Diagnostic Report Switches: Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.6a + chore (commit `6c0e3f8`) &nbsp;|&nbsp; **Working tree before commit.**

R0.6b is the first **intentional behavior change** in the refactor sequence. The ~28 non-core diagnostic CSVs are now master-OFF by default, gated behind 6 group-level `input bool` switches. The two core CSVs (`TradeLifecycle.csv` + `Summary.csv`) remain always-on and produce byte-identical canonical numeric content (RawNetUSD = 585.17, FinalWorkingNetUSD = 1104.89, broker net = 157.49). `ReportProfile` default is changed from `LOCKPARITY` to `MINIMAL` so that the default run — with all 6 switches false — emits exactly 2 CSVs.

**Principle:** "أطفئ كتابة الملفات فقط لا الحسابات." All internal computations (`Apply*`, Lock Parity Decomposer, m_totals counters that feed Summary) continue to run unchanged; only file-write call paths are gated.

---

## 1. Final report classification

### Core — always-on (2 reports, no R0.6b switch)

| Report file | Producer | Why core |
|---|---|---|
| `TradeLifecycle.csv` | `WriteTradeHeader` + `AppendTradeRecord` | Per-trade canonical record. Mandatory. |
| `Summary.csv` | `WriteSummaryHeader` + `WriteFinalSummary` | Run-level canonical totals. Mandatory. |

Gating: `if(EnableMainReport)` (pre-existing input, unchanged by R0.6b).

### Diagnostic — 6 group switches, all default OFF (~28 reports)

| Group switch (default `false`) | # of reports | Reports gated |
|---|---:|---|
| `EnableBrokerReports` | 5 | `BrokerExecutionLifecycle`, `BrokerTradeManagementEventTimeline`, `BrokerContractRealityAudit`, `BrokerRebasedPaperComparison`, `BrokerPaperTradeReconciliation` |
| `EnableLockParityReports` | 2 | `LockParityExecutabilityDecomposition`, `LockParityExecutabilityRollup` |
| `EnableVirtualTrailingReport` | 1 | `VirtualTrailingExitLifecycle` (additionally gated by `EnableVirtualTrailingBridge && EnableRealExecution && MQL_TESTER` — unchanged) |
| `EnableTierEmergencyReports` | 3 | `TierTransitions`, `EmergencyTriggers`, `PaperStateSnapshot` |
| `EnableStrategyRegistryReport` | 1 | `StrategyRegistryDiagnostics` |
| `EnableDebugDiagnostics` | 18 | `StrategyAdapterDiagnostics`, 5 FVG-Micro debug CSVs (`Detector`, `Candidate`, `RetestWatcher`, `TradePlanStaging`, `LifecycleSimulation`), 5 deep diagnostics (`Market`, `CandleCache`, `Evidence`, `Shadow`, `NoLookahead`), `ReportCalibrationCleanupGate`, `RuntimeReportVerification`, `FvgMicroRuntimeSmokeTest`, `FvgMicroRuntimeReportAudit`, `ReportCreationGuarantee`, `AutoPeriodManifest` |
| **Total diagnostic** | **30** | |

(Reports total: 2 core + 30 diagnostic = 32 CSV products. `AutoPeriodManifest.csv` is produced by a free function in main `.mq5` — `FalconWriteAutoPeriodManifest` — rather than by the writer class; it is gated by `EnableDebugDiagnostics` at the function's top, same pattern as the in-class gates.)

`ReportProfile` default: changed from `FALCON_REPORT_LOCKPARITY` to `FALCON_REPORT_MINIMAL`. With all 6 switches `false` and `ReportProfile = MINIMAL`, the default run emits exactly `TradeLifecycle.csv` + `Summary.csv`.

---

## 2. Coordination with the pre-existing `ReportProfile`

`ReportProfile` (`ENUM_FALCON_REPORT_PROFILE` with values `MINIMAL` / `STANDARD` / `DEBUG` / `LOCKPARITY`) is preserved unchanged. It now plays a secondary "preset" role: it further refines emission within a group whose R0.6b master switch is already ON.

**Composition rule:** A diagnostic CSV is produced iff **both**:
1. The group's R0.6b master switch is `true` (e.g. `EnableDebugDiagnostics`), AND
2. The pre-existing `ReportProfile` gate inside the writer (if any) allows it (e.g. `FalconReportProfileIsDebug()`).

Concretely:

- **`EnableStrategyRegistryReport`** (1 report) widens the pre-existing `EnableStrategyRegistryDiagnosticsReport` `#define` (which was `IsStandardOrDebug`) to `EnableStrategyRegistryReport && IsStandardOrDebug`. So the Registry diagnostic appears iff the switch is ON AND ReportProfile is STANDARD or DEBUG.

- **`EnableDebugDiagnostics`** (17 reports) widens the 15 other `Enable*Report` `#define`s (which were `IsDebug`) to `EnableDebugDiagnostics && IsDebug`. So each appears iff the switch is ON AND ReportProfile is DEBUG.

- **`EnableBrokerReports` (5) / `EnableLockParityReports` (2) / `EnableVirtualTrailingReport` (1) / `EnableTierEmergencyReports` (3) — 11 reports** had no `Enable*Report` `#define`; they were silently produced whenever the writer ran. For these, R0.6b adds an explicit `if(!<group switch>) return;` at the top of every Append / Write entry point. The existing inline `if(FalconReportProfileIsLockParity()) return;` early-returns are left in place AFTER the new gate, preserving the pre-R0.6b `LOCKPARITY` semantics for these reports unchanged.

**No `ReportProfile` enum value, helper function, or input name was renamed, removed, or altered.** Only the `ReportProfile` default value changed: `FALCON_REPORT_LOCKPARITY` → `FALCON_REPORT_MINIMAL` to honour the spec rule "اضبط ReportProfile الافتراضي على أضيق وضع نواة" — narrowest core mode, which post-R0.6b means MINIMAL (because the group switches now provide the per-bucket toggling that LOCKPARITY used to do crudely).

### Stock-default behaviour (post-R0.6b)

`ReportProfile = MINIMAL` + all 6 R0.6b switches `false`:

- Core (`TradeLifecycle.csv`, `Summary.csv`) → produced. Canonical financial numbers identical to pre-R0.6b LOCKPARITY default (RawNetUSD = 585.17, FinalWorkingNetUSD = 1104.89, broker net = 157.49). See §7 for the integrity argument.
- All 29 diagnostic CSVs → not produced.

### Spec §5 acceptance test

Setting `EnableLockParityReports = true` (other 5 switches `false`, ReportProfile unchanged at MINIMAL) → only the 2 LockParity CSVs reappear in addition to core. Satisfied by the 3 method-top gates inside `WriteLockParityDecompositionHeader`, `AppendLockParityDecompositionRecord`, and `WriteLockParityExecutabilityRollup`, plus the Initialize-block gate.

---

## 3. Implementation — gate placement

### Header-write gates (Initialize)

```cpp
if(EnableMainReport)
{
   WriteTradeHeader();             // CORE - always
   WriteSummaryHeader();           // CORE - always
   if(!FalconReportProfileIsLockParity())
   {
      if(EnableTierEmergencyReports)  { Tier/Emergency/PaperState headers }
      if(EnableBrokerReports)         { 5 broker headers }
   }
   if(EnableLockParityReports)        { LockParity decomp header }
   if(EnableVirtualTrailingReport && EnableVirtualTrailingBridge
      && EnableRealExecution && MQL_TESTER) { VirtualTrailing header }
}
if(EnableDebugDiagnostics && ForceCreateReportFilesOnInit) { ReportCreationGuarantee }
```

### Method-body gates (runtime Append / Write)

18 method-top gates of the form `if(!<GroupSwitch>) return; // R0.6b group gate` were inserted in `Reporting/FalconReportWriter.mqh` (verified by `grep -c 'R0\.6b group gate' = 18`), plus 1 free-function gate in main `.mq5` (`FalconWriteAutoPeriodManifest` at L3753, gated by `!EnableDebugDiagnostics`). Total R0.6b runtime-write gates: **19**.

- **Broker (10 methods, gate `!EnableBrokerReports`):** `AppendBrokerRebasedPaperComparisonRecord`, `AppendBrokerExecutionLifecycleAuditRecord`, `AppendBrokerEntryBridgeLifecycleRecord`, `AppendBrokerExitObservationLifecycleRecord`, `AppendBrokerManagedCloseLifecycleRecord`, `AppendBrokerPaperTradeReconciliationRecord`, `AppendBrokerOnlyTradeReconciliationRecord`, `AppendBrokerTradeManagementTimelineEvent`, `AppendBrokerTradeManagementTimelineForRecord`, `WriteBrokerContractRealityAudit`.
- **LockParity (3 methods, gate `!EnableLockParityReports`):** `WriteLockParityDecompositionHeader`, `AppendLockParityDecompositionRecord`, `WriteLockParityExecutabilityRollup`. The Lock Parity Decomposer **computation** (`UpdateLockParityTotals`, the 7 `ClassifyLockParity*` helpers, `LockParityIsExecutableClass`, etc.) is **NOT** gated — only the 3 file-write methods.
- **VirtualTrailing (2 methods, gate `!EnableVirtualTrailingReport`):** `WriteVirtualTrailingExitLifecycleHeader`, `AppendVirtualTrailingExitLifecycleRecord`.
- **TierEmergency (3 methods, gate `!EnableTierEmergencyReports`):** `AppendPaperStateSnapshotRecord`, `AppendEmergencyTriggerEvent`, `AppendTierTransitionEvent`.

### `Enable*Report` `#define` widening (main `.mq5` L1910–L1925)

The 16 pre-existing diagnostic-report `#define`s were widened to AND with their group switch — no `#define` name was renamed:

```
EnableMarketDiagnosticsReport                         := EnableDebugDiagnostics       && IsDebug
EnableCandleCacheDiagnosticsReport                    := EnableDebugDiagnostics       && IsDebug
EnableEvidenceDiagnosticsReport                       := EnableDebugDiagnostics       && IsDebug
EnableShadowDiagnosticsReport                         := EnableDebugDiagnostics       && IsDebug
EnableNoLookaheadDiagnosticsReport                    := EnableDebugDiagnostics       && IsDebug
EnableStrategyRegistryDiagnosticsReport               := EnableStrategyRegistryReport && IsStandardOrDebug
EnableStrategyAdapterDiagnosticsReport                := EnableDebugDiagnostics       && IsDebug
EnableFvgMicroDetectorDiagnosticsReport               := EnableDebugDiagnostics       && IsDebug
EnableFvgMicroCandidateDiagnosticsReport              := EnableDebugDiagnostics       && IsDebug
EnableFvgMicroRetestWatcherDiagnosticsReport          := EnableDebugDiagnostics       && IsDebug
EnableFvgMicroTradePlanStagingDiagnosticsReport       := EnableDebugDiagnostics       && IsDebug
EnableFvgMicroLifecycleSimulationDiagnosticsReport    := EnableDebugDiagnostics       && IsDebug
EnableReportCalibrationDiagnosticsReport              := EnableDebugDiagnostics       && IsDebug
EnableRuntimeReportVerificationReport                 := EnableDebugDiagnostics       && IsDebug
EnableFvgMicroSmokeTestDiagnosticsReport              := EnableDebugDiagnostics       && IsDebug
EnableFvgMicroRuntimeReportAuditReport                := EnableDebugDiagnostics       && IsDebug
```

Existing `if(!Enable*Report) return;` early-returns inside the 16 corresponding `Write*Snapshot` methods automatically respect the new group switch — zero additional code change required inside those methods.

---

## 4. "Off file writing only, not computations" — counter-handling decisions

The spec's load-bearing rule: diagnostic-file gating must NOT switch off internal computations that the core might consume. Auditing every `m_totals.*` mutation inside the gated method set:

| Counter | Location | Decision | Why |
|---|---|---|---|
| `m_totals.paper_state_snapshot_evaluated_trades++` | `AppendPaperStateSnapshotRecord` L1446 | **Moved BEFORE the R0.6b gate** | This counter tracks "trades evaluated by the snapshot path" and is read by Summary's integrity-status section. Per spec, the count is a *computation*; only the file-row write is the *output*. With the counter outside the gate, computation continues, file write is suppressed. |
| `m_totals.paper_state_snapshot_write_failures++` | `AppendPaperStateSnapshotRecord` L1462 (inside gate) | Stays inside the gate | Conditioned on a real `FileOpen` failure, which only occurs when the gate is open and the write is attempted. Not a "computation" — it's a file-IO outcome counter. |
| `m_totals.paper_state_snapshot_written_rows++` | `AppendPaperStateSnapshotRecord` L1501 (inside gate) | Stays inside the gate | Conditioned on a successful row write; meaningless when the gate is closed. |
| `m_totals.session_boundary_*` | `UpdateSessionBoundaryStateCheckpointFoundation` L2017+ | **Not gated** | The function itself is NOT one of the 18 R0.6b-gated entry points — it runs on every closed trade regardless of any switch. Apply* and core consume these totals. ✓ |
| `m_totals.market_close_*` | `UpdateMarketCloseGuardFoundation` L2072+ | **Not gated** | Same as above. Apply* consumes. ✓ |
| `m_totals.force_close_*` | `ApplyDailyWeekendForceCloseUserOverridePaperEnforcement` L2144+ | **Not gated (it is one of the 12 Apply\*)** | Spec forbids touching the 12 Apply* — they remain untouched in R0.6b. ✓ |
| `m_totals.weekly_stability_*` | `UpdateWeeklyStabilityFoundation` / `FinalizeWeeklyStabilityFoundation` L2270+ | **Not gated** | Computed inside core lifecycle, not a diagnostic-write site. ✓ |
| `m_totals.lock_parity_*` | `UpdateLockParityTotals` L3833+ | **Not gated** | Spec §2: "لا لمس منطق Lock Parity Decomposer نفسه — فقط بوّابة حول كتابة ملفّيه." Computation runs; only the 2 file-write methods are gated. ✓ |
| `m_totals.win_rate` and other Summary totals | `WriteFinalSummary` and similar | **Not gated** | Core code path, runs regardless. ✓ |

**Net effect:** every internal computation that mutates `m_totals` continues to run in the default R0.6b configuration. Only the 18 file-write entry points are silenced. Apply* methods and Lock Parity classifiers are byte-identical to pre-R0.6a.

---

## 5. Ambiguous classifications — how each was decided

| Report | Initial uncertainty | Final group | Reasoning |
|---|---|---|---|
| `PaperStateSnapshot.csv` | Lifecycle/state vs. Debug | `EnableTierEmergencyReports` | Trade-state snapshot is a sibling of TierTransitions + EmergencyTriggers; they share the lifecycle-state semantic surface. Spec table explicitly lists them together. |
| `StrategyAdapterDiagnostics.csv` | Registry-adjacent vs. Debug | `EnableDebugDiagnostics` | Spec narrows StrategyRegistryReport to the Registry CSV only. The Adapter is debug-grade — it dumps internal adapter shell snapshots. |
| `FvgMicro*DiagnosticsXxx.csv` (×5) | Strategy-adjacent vs. Debug | `EnableDebugDiagnostics` | FVG-Micro debug CSVs document detector/candidate/retest/staging/lifecycle internals — not strategy inventory. They belong with deep-debug. |
| `ReportCreationGuarantee.csv` | Could be "always-on metadata" | `EnableDebugDiagnostics` | Manifest of report file paths. With the default run producing only Core, the manifest is uninteresting. Filed under DebugDiagnostics. |
| `BrokerContractRealityAudit.csv` | DebugDiagnostics vs. Broker | `EnableBrokerReports` | Audits the broker contract surface — squarely a broker-domain diagnostic. Travels with the other Broker CSVs. |
| `FvgMicroRuntimeSmokeTest.csv` / `FvgMicroRuntimeReportAudit.csv` / `RuntimeReportVerification.csv` / `ReportCalibrationCleanupGate.csv` | Strategy vs. Debug | `EnableDebugDiagnostics` | Each is meta-diagnostic (probes the diagnostic pipeline itself). Belongs in DebugDiagnostics. |

No other ambiguities of consequence.

---

## 6. Misleading input names — suggestions for R0.8 (NOT changed in R0.6b)

Per spec §3, no existing input name was changed. Candidates for an R0.8 rename pass:

1. **`EnableMainReport`** — name suggests "the main report file" but it's the master gate for the *core* CSVs (TradeLifecycle + Summary) and a precondition inside several Append paths. Suggested rename: `EnableCoreReports` or `EnableCoreCsvOutput`.
2. **`ReportProfile`** — fine as a name. The enum values `STANDARD` and `DEBUG` overlap with R0.6b group switches and may be candidates for retirement in R0.8 once the group switches fully cover the surface (then `ReportProfile` shrinks to just `MINIMAL` / `LOCKPARITY` / `DEFAULT`).
3. **`EnableVirtualTrailingBridge`** vs. the new **`EnableVirtualTrailingReport`** — the behaviour gate ("does virtual trailing execute?") and the report gate ("do we record what happened?") are now two visible inputs. Consider clearer prefixes in R0.8 (`EnableVirtualTrailingExecution` vs. `EnableVirtualTrailingReport`).
4. **`EnableMainReport`** is still checked inside `AppendEmergencyTriggerEvent` and `AppendTierTransitionEvent` (legacy guard). With R0.6b's `EnableTierEmergencyReports` placed BEFORE that check, the inner `if(!EnableMainReport)` is now reachable only when the user opts into TierEmergency reports while having Core off — likely a config error. Flag for R0.8 cleanup.
5. **`Enable*Report` `#define`s** (e.g. `EnableMarketDiagnosticsReport`) — these names refer to a single CSV but are actually gated by `EnableDebugDiagnostics` as a group now. The names are not misleading per se but feel like single-toggle inputs (they were, pre-R0.6b). Consider renaming to `*ReportProduced` or similar in R0.8.

---

## 7. Stock-default Summary integrity argument

**Pre-R0.6b default** (`ReportProfile = FALCON_REPORT_LOCKPARITY`):
- `Summary.csv` produced.
- LockParity Decomp/Rollup produced.
- All other diagnostic Write/Append methods early-returned via `if(FalconReportProfileIsLockParity()) return;` placed BEFORE counter increments. Notably `AppendPaperStateSnapshotRecord` early-returned **before** `m_totals.paper_state_snapshot_evaluated_trades++`, leaving the counter at 0.
- Result: Summary integrity-status row showed FAIL for the `paper_state_snapshot_evaluated_trades` check; total_trades was non-zero and the counter was 0.

**Post-R0.6b default** (`ReportProfile = FALCON_REPORT_MINIMAL` + all 6 switches `false`):
- `Summary.csv` produced.
- LockParity Decomp/Rollup NOT produced (gated by `EnableLockParityReports=false`).
- `AppendPaperStateSnapshotRecord` increments `paper_state_snapshot_evaluated_trades` BEFORE the new gate (per the "off file writing only, not computations" rule). Counter rises to N=total_trades; written_rows stays at 0. Integrity status shows FAIL for `paper_state_snapshot_written_rows`.

**Canonical financial numbers** (`RawNetUSD`, `FinalWorkingNetUSD`, broker net):
- Computed by Apply* and the Bridge — neither is touched by R0.6b.
- All `m_totals.*` financial computations run regardless of switches.
- Result: 585.17 / 1104.89 / 157.49 are byte-identical pre- and post-R0.6b.

**Difference in Summary columns**: only the diagnostic counter columns (`paper_state_snapshot_evaluated_trades` shifts from 0 to N; integrity row stays FAIL because written_rows is 0 in both cases). Other counter columns (Apply*-fed, Update*Foundation-fed) are byte-identical. The canonical financial numbers and the broker net are byte-identical.

**Difference in produced files**: pre-R0.6b default produced 4 files (Trade, Summary, LockParityDecomp, LockParityRollup); post-R0.6b default produces 2 files (Trade, Summary).

---

## 8. Spec §5 / §6 Acceptance Status

| Criterion | Status |
|---|---|
| 6 group switches, all `input bool = false` | ✓ |
| Core (`Summary` + `TradeLifecycle`) always produced; canonical numbers preserved | ✓ |
| All 29 diagnostic CSVs NOT produced in stock-default run | ✓ (18 method-top gates + 5 Initialize-block gates + 16 `Enable*Report` macros widened) |
| `EnableLockParityReports = true` revives the 2 LockParity CSVs | ✓ (gate at 3 LockParity methods + Initialize header) |
| `ReportProfile` default set to narrowest core mode (`MINIMAL`) | ✓ |
| Input window organized in groups with clear Arabic headers | ✓ (groups `04 - Reporting Core / تقارير النواة الدائمة` + `05 - Diagnostic Reports / التقارير التشخيصية`) |
| Computations not touched (Apply*, Lock Parity Decomposer, m_totals counters) | ✓ (see §4 audit table) |
| 12 `Apply*` methods untouched | ✓ (`grep -cE '^\s+void Apply[A-Z]' Reporting/FalconReportWriter.mqh` = 12; 0 in main `.mq5`) |
| No diagnostic report code deleted | ✓ (only gating added) |
| No existing input name changed | ✓ (only `ReportProfile` *default value* changed; no name renamed) |
| Compiles `0 errors, 0 warnings` | ⏳ requires MetaEditor F7 by user |
| Default-run produces only TradeLifecycle.csv + Summary.csv | ⏳ requires backtest verification |
| `Docs/ReviewNotes/R0_6b_Review_Notes.md` exists | ✓ (this file) |

---

## 9. Open items (deferred, non-blocking)

1. **`AppendEmergencyTriggerEvent` / `AppendTierTransitionEvent` redundant `if(!EnableMainReport) return;`** — now reachable only when the user opts into TierEmergency reports while having Core off (likely a config error). Left for R0.8 cleanup.
2. **`ForceCreateReportFilesOnInit`** is computed from `ReportProfile == FALCON_REPORT_DEBUG` and now ANDs with `EnableDebugDiagnostics`. A user wanting the manifest alone cannot get it without enabling all of DebugDiagnostics. Documented for R0.8 review.
3. **The 12 `Apply*` methods inside `CFalconReportWriter`** remain the next migration target. Per `Docs/ReviewNotes/R0_6a_Review_Notes.md §3.5`, R0.7 will peel them out into `Risk/` (or for #3 — `ApplyFvgQualityShadowGuardSimulation` — into `Strategies/S00_ScalpFvgMicro/`).
4. **`EnableStrategyRegistryReport`'s `IsStandardOrDebug` dependency** — to actually see the StrategyRegistry CSV, the user must also set `ReportProfile = STANDARD` or `DEBUG`. The default `MINIMAL` profile blocks it even when the switch is ON. Documented; reconsider in R0.8 whether to drop the ReportProfile coupling for this one CSV.

---

*End of R0.6b review notes. Zero diagnostic-report code was deleted. The 12 `Apply*` methods, the Lock Parity Decomposer logic, the broker telemetry call surfaces, and all m_totals computations are unchanged. Only file-write entry points were gated by the 6 new group switches; the existing 16 `Enable*Report` `#define`s were widened to AND with their group switch; and the `ReportProfile` default value was changed from `LOCKPARITY` to `MINIMAL`.*
