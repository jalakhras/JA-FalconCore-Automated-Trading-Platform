# R1.6a Review Notes — Diagnostic Report Cleanup

**Phase type:** cleanup (scaffolding removal, no new behaviour).
**Spec:** `JA_FalconCore_SPEC_R1_6a_DiagnosticReportCleanup.md`.
**Basis:** `JA_FalconCore_Exploration_DeadSurfaceAudit.md` (the code-proven inventory).
**Version:** `EA_VERSION_TAG = R1_6a`, `EA_BUILD_TAG = DiagnosticReportCleanup` (`Core/FalconConstants.mqh:10-11`).
**Scope decision (operator):** remove **all write paths** for each DIAG-EXP report (not just the Initialize-block trigger), so a retired report does not reappear even with its switch ON. Behaviour-neutral because the removed paths are gated-off in the test config and do not feed any core counter (the one exception is handled — see §3).

---

## 1. What was removed (DIAG-EXP report write-paths)

**Group A — inside the `EnableBrokerReports` block (`Reporting/FalconReportWriter.mqh`), surgical (risk R1):**
- `BrokerRebasedPaperComparison`: Initialize header call (was `:170`) **and** the per-trade `AppendBrokerRebasedPaperComparisonRecord(record)` hook in `RegisterClosedTrade` (was `:3947`).
- `BrokerContractRealityAudit`: the one-shot `WriteBrokerContractRealityAudit()` Initialize call (was `:172`).
- **Kept:** the `if(EnableBrokerReports)` block, the switch, and the 3 core broker reports — `BrokerExecutionLifecycle`, `BrokerTradeManagementEventTimeline`, `BrokerPaperTradeReconciliation`.

**Group B — group-05 switch reports:**
- `EnableTierEmergencyReports`: Initialize header calls for `TierTransitions` / `EmergencyTriggers` / `PaperStateSnapshot`; the `AppendEmergencyTriggerEvent(record)` hook in `RegisterClosedTrade`; the `PaperStateSnapshot` file-write body (see §3 — counter preserved). `AppendTierTransitionEvent` had **no caller** already (confirmed by grep) — only its dead Initialize header was removed.
- `EnableLockParityReports`: Initialize header call; the `AppendLockParityDecompositionRecord(record)` hook (was `:3952`); the `WriteLockParityExecutabilityRollup()` call in `WriteFinalSummary` (was `:4204`). **Kept `UpdateLockParityTotals(record)`** — it is computation that feeds totals, not a report write (audit + R0.6b confirm it is ungated).
- `EnableVirtualTrailingReport`: Initialize header call; the `AppendVirtualTrailingExitLifecycleRecord(...)` call in `Execution/FalconBrokerEntryBridge.mqh::UpdateVirtualTrailingForOpenLinks` (was `:2166`). The reverse-close itself is unchanged; the report-only `trailing_status` local and the no-longer-read `sent` return capture were removed with it.
- `EnableStrategyRegistryReport`: `WriteStrategyRegistryDiagnosticsSnapshot` OnInit call.
- `EnableDebugDiagnostics`: the ~16 deep diagnostic snapshots (Market, CandleCache, Evidence, Shadow, NoLookahead, StrategyAdapter, 5×FvgMicro, ReportCalibration, FvgMicroSmokeTest, FvgMicroRuntimeReportAudit, FvgMicroLifecycleSimulation) across `OnInit` / `OnTick` / `OnDeinit` / `FalconRunFvgMicroRuntimeShadowPipeline`; `WriteRuntimeReportVerificationSnapshot` (all 4 hook calls); `WriteReportCreationGuaranteeFile` (Initialize); `FalconWriteAutoPeriodManifest` (both calls, inside `FalconFinalizeAndRenameReportFiles` — the rename loop is untouched).

**Group C — S00 diagnostics:**
- `S00_FvgDetection_Diagnostics`: the `if(S00_DiagReport) AppendDiagnosticsRow(...)` call in `Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh`.
- `S00_Trades_Diagnostics`: the `AppendTradeRow(m_active_trade)` call in `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` (the method also self-gates on `S00_DiagReport`).

**Group D — ungated:**
- `StartupBootstrap`: the `FalconWriteStartupBootstrapFile()` call in `OnInit` (this was the only DIAG-EXP report written in the default tree, since it had no gate).

**Explicitly NOT touched:** the 6 core reports (`TradeLifecycle`, `Summary`, `BrokerExecutionLifecycle`, `BrokerPaperTradeReconciliation`, `TradeManagementCoordinatorAudit`) and `BrokerTradeManagementEventTimeline`; `Risk/FalconRiskLifecycleProcessor.mqh` and the `Apply*` chain; every `input` and every gating switch (all remain defined); `TradeManagement_DiagReport` and its core report.

---

## 2. What was kept and why (switches, methods, computation)

- **No input removed or renamed.** The audit proved 0 dead inputs; removal is the deferred input-cleanup phase (backlog #82), gated on the operator's `.set` files (risk R3).
- **No gating switch removed.** Each switch (incl. all group-05 + `S00_DiagReport`) stays defined as an `input` — it may live in a saved `.set` (R3). R1.6a removed only what they *wrote*.
- **Orphaned writer method bodies left in place** (`WriteTierTransitionsHeader`, `AppendEmergencyTriggerEvent`, `WriteBrokerContractRealityAudit`, `AppendBrokerRebasedPaperComparisonRecord`, the LockParity/VirtualTrailing/diagnostic-snapshot writers, S00 `AppendDiagnosticsRow`/`AppendTradeRow`, the free functions `FalconWriteStartupBootstrapFile` / `FalconWriteAutoPeriodManifest` / `FalconShouldWriteRuntimeDiagnosticsNow`). Per spec "doubt ⇒ delete the call, leave the function." MQL5 emits no warning for unused methods/functions (build: 0 warnings), so leaving them is risk-free; a dead-code sweep can remove them later.
- **`UpdateLockParityTotals` kept** — computation feeding totals, not a report write.

---

## 3. Counter-preservation (the one calc-feeds-core-counter landmine)

`AppendPaperStateSnapshotRecord` (`Reporting/FalconReportWriter.mqh`) incremented `m_totals.paper_state_snapshot_evaluated_trades` **before** its `EnableTierEmergencyReports` gate, and **Summary's integrity-status section reads that counter** (the accepted #69 debt). Deleting the call would have changed Summary → broken equivalence. Resolution: **the call in `RegisterClosedTrade` is kept**, and the method body was reduced to just that counter increment — the file-write body (header + row + the gated `write_failures`/`written_rows` counters) was removed. In every gated-off run the body never executed and `written_rows` stayed 0, so this is byte-for-byte behaviour-neutral and preserves the existing #69 `ReportIntegrityStatus` state. This is the spec's "remove the file-write only, never the computation that feeds a core counter."

---

## 4. Build (acceptance criterion #1)

MetaEditor CLI compile (`metaeditor64.exe /compile`):

```
Result: 0 errors, 0 warnings, 11631 ms elapsed, cpu='X64 Regular'
```

`0 errors, 0 warnings` → no new warnings; the `write_runtime_diagnostics` / `trailing_status` / `sent` removals and the orphaned definitions produced none. Problems panel: clean (the compile log is authoritative).

---

## 5. Behavioural-equivalence test (acceptance criteria #2–#4) — **PASS**

Per the agreed split, the build is done here; the operator ran the Strategy Tester (GUI, single-instance). **Config:** S01 harness, April, protection OFF (`Enable_S01_Protection=false`), `EnableBrokerReports=true` + `EnableMainReport=true` (to produce the broker reconciliation + the `BrokerActualNetUSD` meter), same `.set` as the R1.5a reference run. **Reports dir:** `C:\Users\jalak\AppData\Roaming\MetaQuotes\Terminal\Common\Files`.

### المعايير المُعتمَدة (المعايير الصحيحة لاختبار التكافؤ)

`FinalWorkingNetUSD` **رقمٌ مراقَب، لا بوّابة قبول** — اعتماده كبوّابة في الجولة الأولى كان خطأً منهجيًّا (المعرفة المُثبَتة #١: الرقم الورقيّ مسموم). البوّابة الصحيحة أربعة مقاييس مستقلّة عن طبقات الحماية/الـ runner الورقيّة:

- **`RawNetUSD` = 1233.88** — مطابق للـ baseline.
- **`BrokerActualNetUSD` ≈ 321.9** — مطابق للـ baseline.
- **`TotalTrades` = 1146** — مطابق للـ baseline.
- **`Reconciliation diffs` ≈ 0** — `VisibleRawNetUSDDiff` و`VisibleFinalNetUSDDiff` صفر صفًّا صفًّا.

الأربعة تطابقت بين الـ baseline وR1.6a ⇒ **تكافؤ سلوكيّ مُثبَت**.

**Must disappear from the reports dir:** `StartupBootstrap`, and (with their switches on) `BrokerRebasedPaperComparison`, `BrokerContractRealityAudit`, `TierTransitions`, `EmergencyTriggers`, `PaperStateSnapshot`, `LockParity*`, `VirtualTrailingExitLifecycle`, `StrategyRegistryDiagnostics`, the ~16 debug diagnostics, `RuntimeReportVerification`, `ReportCreationGuarantee`, `AutoPeriodManifest`, `S00_FvgDetection_Diagnostics`, `S00_Trades_Diagnostics`.
**Must remain:** the 6 core reports + `BrokerTradeManagementEventTimeline`.

### تفسير الانحراف 42.60 → 1612.07 (ليس انحدارَ R1.6a)

`FinalWorkingNetUSD` قفز من 42.60 (في baseline ما قبل R1.5a) إلى 1612.07 (في تشغيلَي R1.6a). هذا **ليس** أثرًا لتنظيف التقارير — استكشاف الـ diff سطرًا سطرًا أثبت أن R1.6a لمست **صفر أسطر** في كود الحماية/Risk/المنسّق. السببان الحقيقيّان:

1. **تغيّر تعريف ضمنيّ في R1.5a:** حين أُضيف محرّك الحماية (Phase 3a)، صار `FinalWorkingNetUSD` يحمل أثر تعديلات الحماية/الـ runner الورقيّة. تعريف المقياس تغيّر، فلا تصحّ مقارنته عبر حدّ R1.5a (انظر Backlog: «إعادة تصنيف 42.60»).
2. **عيب gate في المفتاحين** (مسجَّل بصفته Problem #6): `Enable_TradeManagement=false` و`Enable_S01_Protection=false` **لا يطفئان** فعلًا طبقة الحماية/الـ runner الورقيّة — تشتغل بصرف النظر. تشغيلَا أبريل Prot ON/OFF أعطيا 1612.07 و1609.36 بـ `ProtectionActivated=662` في الحالتين، وعُدِّل صافي 115 صفقة بالحماية و214 بالـ runner رغم OFF. البروكر مستقرّ بين التشغيلين — العيب في الـ gate الورقيّ، لا في مسار التنفيذ.

⇒ اختبار التكافؤ الأصليّ كان معيبًا بنيويًّا (قارن قيمةً عبر حدودِ تعريفِ المقياس). الـ commit انعقد على المعايير الصحيحة الأربعة أعلاه.

---

## 6. Risks honoured (from the DeadSurfaceAudit)

- **R1 (broker shared-switch coupling):** surgical — only the 2 expired broker reports' write-paths removed; `EnableBrokerReports` + block + 3 core reports preserved.
- **R2 (`_DiagReport` naming trap):** `TradeManagement_DiagReport` and `TradeManagementCoordinatorAudit` untouched; only `S00_DiagReport`'s expired reports removed.
- **R3 (`.set` invisibility):** no input or switch removed — nothing a saved `.set` references was deleted.
- **R5 (counters survive report-off):** confirmed and protected — see §3.
