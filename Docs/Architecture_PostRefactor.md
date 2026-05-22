# JA FalconCore — Architecture (Post-R0 Refactor)

This document is the **shipping shape** of the codebase after the R0
structural refactor (R0.2 → R0.9). It answers four questions:

1. Where does each layer live?
2. Which direction do dependencies flow?
3. Who owns the trade lifecycle?
4. Who owns the report writing — and how do they talk?

This is the reference R1.x will consult when building the S00 scalp
strategy on top of the now-stable structural surface.

---

## 1. Folder map (final post-R0)

```
JA-FalconCore-Automated-Trading-Platform/
│
├── JA_FalconCore_Automated_Trading_Platform.mq5     ← main glue (~6,024 LOC)
│
├── Core/             ← foundations: constants, enums, structs, logging,
│                       market context, candle cache (7 files, ~1,829 LOC)
│
├── Evidence/         ← evidence framework (1 file, ~101 LOC)
│
├── Risk/             ← risk foundations + the 12-step Apply* chain
│                       + the data-bus contract (6 files, ~1,991 LOC)
│   └── FalconRiskLifecycleProcessor.mqh   ← OWNS THE 12 Apply* + chain
│
├── TradeManagement/  ← placeholder folder; populated in R1.x+
│                       (1 placeholder file)
│
├── Execution/        ← broker bridge + execution guard + runtime safety
│                       + shadow executor (5 files, ~2,962 LOC)
│
├── Router/           ← strategy registry + adapter shell
│                       (3 files, ~394 LOC)
│
├── Strategies/       ← placeholder folder + S00 scalp slot, populated R1.x
│                       (2 placeholder files)
│   └── S00_ScalpFvgMicro/                  ← R1.x lands the scalp here
│
└── Reporting/        ← single monolithic writer (~5,313 LOC)
    └── FalconReportWriter.mqh              ← OWNS m_totals + all CSV writers
```

Folder layout is intentional **layer separation**, not "everything is a
namespace." Each folder contains files that depend only on layers
**above** it (per §2). The placeholder folders (`TradeManagement/`,
`Strategies/`) exist so the R1.x author can see the slot without
guessing where it lives.

---

## 2. Dependency direction

The dependency graph is a **directed acyclic** spine. No back-edges.
Read from top to bottom — anything higher can call anything lower; the
reverse is forbidden.

```
                    ┌──────────────────────────────┐
                    │   main .mq5  (OnInit/OnTick) │
                    │   + the FVG-Micro classes    │
                    │   that R1.x will move to     │
                    │   Strategies/S00_ScalpFvgMicro│
                    └──────┬──────────┬────────────┘
                           │          │
                           │          ▼
                           │   ┌──────────────────┐
                           │   │   Reporting/     │
                           │   │   FalconReport-  │
                           │   │   Writer.mqh     │  ← orchestrates the chain
                           │   └──────┬───────────┘     via one call to:
                           │          │
                           │          ▼
                           │   ┌─────────────────────────────┐
                           │   │  Risk/                      │
                           │   │  FalconRiskLifecycle-       │ ← owns the
                           │   │  Processor (the chain)      │   12 Apply*
                           │   │  + RiskFoundation           │
                           │   │  + RiskTradeManagement      │
                           │   └─────┬───────────────────────┘
                           │         │
                           │         ▼
                           │   ┌──────────────────────────────┐
                           │   │  Execution/                  │
                           │   │  Bridge + Guard + Shadow     │
                           │   │  + RuntimeSafetyGuard        │
                           │   └─────┬────────────────────────┘
                           │         │
                           │         ▼
                           │   ┌──────────────────────────────┐
                           │   │  Router/                     │
                           │   │  StrategyRegistry            │
                           │   │  + StrategyAdapterShell      │
                           │   └─────┬────────────────────────┘
                           │         │
                           ▼         ▼
                    ┌────────────────────────────┐
                    │  Evidence/                 │
                    │  EvidenceFramework         │
                    └────┬───────────────────────┘
                         │
                         ▼
                    ┌────────────────────────────┐
                    │  Core/                     │
                    │  Constants, Enums,         │
                    │  DataStructures, Logger,   │
                    │  MarketContext, CandleCache│
                    └────────────────────────────┘
```

### 2.1 Cross-layer rules (enforced by the file structure, not just convention)

1. **Risk → Reporting is forbidden.** The chain (in `Risk/`) writes
   into the `record` it received by reference; the writer (in
   `Reporting/`) reads `record.*` fields after the chain returns.
   `Risk/FalconRiskLifecycleProcessor.mqh` contains **zero** references
   to `CFalconReportWriter` or `g_report_writer`.

2. **Reporting → Risk is one call.** `RegisterClosedTrade` in the
   writer invokes the chain once:
   ```cpp
   g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record, m_totals);
   ```
   It is also allowed (since R0.8b) to read the canonical symbol
   context from the processor via the `SymbolContext()` forwarder —
   that is the only state the writer "borrows" from the Risk layer.

3. **Core has no incoming class dependencies except the structs.** All
   layers reference the structs defined in
   `Core/FalconDataStructures.mqh` (`FalconTradeLifecycleRecord`,
   `FalconReportTotals`, `FalconSymbolContext`, `FalconCandleSnapshot`,
   etc.) and the constants/enums. Nothing in Core needs to know any
   class above it exists.

4. **The FVG-Micro classes still inline in main `.mq5`** are intentional
   placeholders for the R1.x S00 scalp strategy. They will move into
   `Strategies/S00_ScalpFvgMicro/` when the strategy interface
   finalizes. Until then, they live where the inputs that gate them
   also live (main `.mq5`).

---

## 3. Trade lifecycle — who owns what

The flow of a closed trade from event to CSV row:

```
   broker exit / paper close detected
         │
         ▼
   CFalconBrokerEntryBridge::ObserveTradeTransactionExit
         │   builds FalconTradeLifecycleRecord
         │   passes to:
         ▼
   CFalconReportWriter::RegisterClosedTrade(record)
         │
         ├── FalconFinalizeTradeMetrics(record, _sc)
         │      where _sc = SymbolContext() forwarder
         │      ↓ fills record.net_index_points / .net_usd
         │
         ├── g_risk_lifecycle_processor
         │       .ApplyTradeLifecycleChain(record, m_totals)
         │      ↓ runs the 12 Apply* in load-bearing actual order:
         │         #3 → #4 → #5 → #6 → #7 → #8 →
         │         #10 → #9 → #1 → #2 → #11 → #12
         │      ↓ mutates record.* in place
         │      ↓ mutates m_totals.X (only Apply #2 does this, via
         │         the FalconReportTotals &totals param)
         │      ↓ updates processor state (m_tle_*, m_dlm_*) — these
         │         are private to the processor; no other class reads
         │         or writes them
         │
         ├── AppendEmergencyTriggerEvent(record)
         │      ↑ reads record.falcon_emergency_* and emits
         │        EmergencyTriggers.csv row if triggered
         │
         ├── UpdateTotals(record)
         │      ↑ accumulates record.* into m_totals (the same
         │        FalconReportTotals the chain wrote into)
         │
         ├── AppendTradeRecord(record)            → TradeLifecycle.csv
         ├── AppendPaperStateSnapshotRecord       → PaperStateSnapshot.csv
         ├── AppendBrokerExecutionLifecycleAudit  → BrokerExecution....csv
         ├── AppendBrokerRebasedPaperComparison   → BrokerRebasedPaper.csv
         ├── AppendBrokerTradeManagementTimeline  → BrokerTMTimeline.csv
         └── UpdateLockParityTotals + AppendLockParityDecomp
                                                  → LockParity*.csv
```

Single direction at every layer boundary:
- **Risk writes record fields.** Reporting reads them.
- **Risk writes `totals` through a chain param.** Reporting accumulates further into the same totals after the chain returns.
- **Reporting writes CSV rows.** Risk never touches a file.

---

## 4. The 29 file-scope class instances + runtime state

Listed in order they appear in `OnInit`'s "Global Runtime Objects"
block (`JA_FalconCore_Automated_Trading_Platform.mq5:~5663-5687`):

### 4.1 Class-instance singletons (18) — the layer doors

| Symbol | Class | Layer | Role |
|---|---|---|---|
| `g_market_context` | `CFalconMarketContext` | Core | Market data + tick/quote/candle observation |
| `g_risk_foundation` | `CFalconRiskFoundation` | Risk | Input validation (parameters, broker symbol props) |
| `g_candle_cache` | `CFalconCandleCache` | Core | M1/M5 candle history cache |
| `g_evidence_framework` | `CFalconEvidenceFramework` | Evidence | Evidence-pack assembly |
| `g_shadow_executor` | `CFalconShadowExecutor` | Execution | Stages trade plans into the shadow ledger (no broker orders) |
| `g_runtime_safety_guard` | `CFalconRuntimeSafetyGuard` | Execution | No-Lookahead + geometry safety checks |
| `g_strategy_registry` | `CFalconStrategyRegistry` | Router | Strategy enable/disable + metadata |
| `g_first_strategy_adapter` | `CFalconFirstShadowStrategyAdapterShell` | Router | Strategy ↔ engine adapter |
| `g_fvg_micro_detector_stub` | `CFalconFvgMicroShadowDetectorStub` | (Strategy-adjacent, inline) | FVG candidate detection |
| `g_fvg_micro_candidate_builder` | `CFalconFvgMicroShadowCandidateBuilder` | (Strategy-adjacent, inline) | Builds candidate snapshots |
| `g_fvg_micro_retest_watcher` | `CFalconFvgMicroRetestWatcher` | (Strategy-adjacent, inline) | Retest freshness + age tracking |
| `g_fvg_micro_tradeplan_stager` | `CFalconFvgMicroTradePlanStagingDryRun` | (Strategy-adjacent, inline) | Builds + validates a `FalconTradePlan` |
| `g_fvg_micro_lifecycle_simulator` | `CFalconFvgMicroShadowLifecycleSimulation` | (Strategy-adjacent, inline) | Simulates lifecycle exits in Shadow mode |
| `g_report_writer` | `CFalconReportWriter` | Reporting | **All CSV writers + `m_totals` owner** |
| `g_broker_entry_bridge` | `CFalconBrokerEntryBridge` | Execution | Optional broker-side entry, paper reconciliation |
| `g_execution_guard` | `CFalconExecutionGuard` | Execution | Pre-OrderSend guards |
| `g_risk_tm_architecture` | `CFalconRiskTradeManagementArchitecture` | Risk | Trade-management architecture pinning |
| `g_risk_lifecycle_processor` | `CFalconRiskLifecycleProcessor` | Risk | **Owns the 12 Apply\* chain + m_tle_\* + m_dlm_\* + m_symbol_context** |

### 4.2 Runtime state singletons (4)

| Symbol | Type | Role | Touched by |
|---|---|---|---|
| `g_is_initialized` | `bool` | OnInit-set flag; OnTick guard | OnInit (set true at L5934 / false at L5950); OnTick (read at L5967) |
| `g_runtime_tick_counter` | `long` | Wall-clock tick count for diagnostic cadence | OnInit (reset L5839); OnTick (`++` at L5970); `FalconShouldWriteRuntimeDiagnosticsNow` (read) |
| `g_last_processed_m5_closed_candle_time` | `datetime` | "Last M5 candle close we acted on" | `FalconShouldRefreshFvgDetectorOnThisTick` |
| `g_last_staged_fvg_candidate_id` | `string` | Dedup key for FVG staging | `FalconRunFvgMicroRuntimeShadowPipeline` |

### 4.3 Capital baseline (1)

| Symbol | Type | Role |
|---|---|---|
| `g_falcon_session_start_balance` | `double` | Snapshot of `AccountInfoDouble(ACCOUNT_BALANCE)` at OnInit; read by `FalconEffectiveCapitalForTier` |

### 4.4 Report period (6 — used as a group)

`g_report_period_first_time`, `g_report_period_last_time`,
`g_report_initial_from_tag`, `g_report_initial_to_tag`,
`g_report_active_from_tag`, `g_report_active_to_tag` — all consumed by
the `FalconInitializeReportPeriodTags / FalconUpdateReportPeriodLastSeen
/ FalconFinalizeReportPeriodTags / FalconWriteAutoPeriodManifest /
FalconFinalizeAndRenameReportFiles` group. Multi-function readers and
writers; live as globals because the call paths are spread across
OnInit, OnTick, and OnDeinit.

### 4.5 Telemetry counters (the remaining 56)

These are the FVG-micro / quality-profile / quality-distribution /
retest / hold-quality / OTTU / qguard-runtime counter blocks. They are
declared file-scope but **not consumed by any current reporting
writer**. R0.8c attempted to retire most of them; the rollback in
commit `ae556ea` restored them. See `Docs/Ideas_Backlog.md` #19 for the
deferred cleanup pattern.

---

## 5. Key invariants (R0 ship)

The following invariants are now **structurally enforced** — not just
documented:

1. **Apply\* chain order is the load-bearing actual order:**
   `#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12`.
   Source of truth: `Risk/FalconRiskLifecycleProcessor.mqh::ApplyTradeLifecycleChain`.
   Any future reorder must produce byte-identical FixedLot April:
   `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker `157.49`.

2. **OnInit order is load-bearing.**
   ```
   g_report_writer.Initialize(symbol_context);             // file naming
   g_risk_lifecycle_processor.Initialize(symbol_context);  // SEED Risk state
   ```
   (Reverse would still work today because RW's `Initialize` body
   doesn't call `SymbolContext()`, but a future RW `Initialize` that
   reads `SymbolContext()` would see zero values before the processor
   is seeded — see `Docs/Ideas_Backlog.md` #17.)

3. **`EmergencyTriggers.csv` writer is called exactly once per closed
   trade** by `RegisterClosedTrade` (post-chain), gated internally on
   `record.falcon_emergency_status != "TRIGGERED"` → early return.
   No double-write surface.

4. **The chain is invoked exactly once per closed trade.** Single call
   site: `Reporting/FalconReportWriter.mqh::RegisterClosedTrade`.

5. **`m_totals` lives in `CFalconReportWriter`. Single owner.**
   The chain receives it as a reference param.
   Apply #2 is the only chain step that mutates it.

6. **`m_tle_*` + `m_dlm_*` + `m_symbol_context` live in
   `CFalconRiskLifecycleProcessor`. Single owner.**
   `SymbolContext()` forwarder returns a value-copy on demand.

---

## 6. What this architecture is NOT

- **Not split-by-namespace.** MQL5 has no namespaces; we use **folder
  paths + `#include` order** to enforce layer separation.
- **Not heavily abstracted.** No interfaces, no virtual dispatch, no
  templates. Each class is concrete. Future strategies in
  `Strategies/S00_ScalpFvgMicro/` will use the `CFalconStrategyAdapter`
  pattern already wired in `Router/`, not deep polymorphism.
- **Not "<600 lines per file".** That goal was cancelled by the R0.9
  spec — internal organization matters, total line count does not.
  `Reporting/FalconReportWriter.mqh` is ~5,313 LOC and that is fine
  given its internal structure (Summary / TradeLifecycle / 6 broker
  telemetry methods / Lock Parity Decomposer / Diagnostics writers).
  Internal splitting is a candidate for an R1.x or beyond effort if
  and only if a real reason to touch the file arrives.

---

## 7. Reference

- **Pre-refactor inventory:** `Docs/FalconCore_Feature_Inventory_v0_57_4.md`
- **Post-refactor inventory:** `Docs/FalconCore_Feature_Inventory_post_refactor.md`
- **Per-phase migration notes:** `Docs/ReviewNotes/R0_*_Review_Notes.md`
- **Per-phase project memory snapshots:** `Docs/ProjectMemory/JA_FalconCore_Project_Memory_R0_*.md`
- **Open items for R1.x and beyond:** `Docs/Ideas_Backlog.md`
- **Original refactor plan:** `Docs/JA_FalconCore_Refactor_Plan_v0_57_4.md` (if present)
- **EA operational rules:** `Docs/falconcore_ea_operational_rules.md`

---

*End of architecture document. R0 refactor — STRUCTURAL — is complete.
R1.x is strategy work, not structure.*
