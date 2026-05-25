# JA FalconCore — Project State Snapshot
## Compiled 2026-05-24 (after R1.2d BreachFix, commit `5be1778`)

Anchored structured summary built from `JA_FalconCore_Project_Memory_R1_2d.md`,
`Docs/ReviewNotes/R1_2d_Review_Notes.md` (§1–§12), `Docs/Specs/JA_FalconCore_R1_2d*_SPEC.md`,
and `Docs/ProjectMemory/JA_FalconCore_Project_Memory_R1_2c.md`. Verbatim identifiers preserved
(no paraphrasing of file paths / function names / numbers).

---

## 1. Official LOCK Baseline (the "truth gauge")

| Layer | Value |
|---|---|
| LOCKED memory artifact | `Docs/ProjectMemory/JA_FalconCore_Project_Memory_v0_55_12a_fix2_LOCKED.docx` (last `.docx` LOCKED) |
| Operational divergence point | `dev` branch at v0.57.4, commit `5a7e961` — refactor `R0.*` branched from here |
| Behaviour invariant ("zero behaviour change") | **FixedLot April** with gates closed must produce **byte-for-byte**: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, BrokerNet `200 → 157.49` (delta `−42.51`) |
| Architecture frozen at baseline | Single `.mq5` (~17,343 lines), 18 classes, 22 structs, 22 enums, 693 `#define`, 85 globals, 46 inputs, 12 `Apply*` functions |
| Active strategy at baseline | `FVG_MICRO_RETEST` (S00), US100_Spot, M5 |
| Symbolic link | Project dir mirrored into `…\MQL5\Experts\JassarBot` (any new `.mqh` auto-visible to compiler) |

The `585.17 / 1104.89 / 157.49` triple is THE regression gauge — any drift means the candidate broke something.

---

## 2. Current Candidate — R1.2d (4 sub-commits, one logical phase)

| Field | Value |
|---|---|
| Branch | `refactor` (forked from `dev` at v0.57.4) |
| Head commit | `5be1778` — "R1.2d - S00 fully integrated into reporting: central TradeLifecycle, reconciliation linkage, unique trade_id, correct structural SL" |
| `EA_VERSION_TAG` | `R1_2d` |
| `EA_BUILD_TAG` | `CentralLifecycleRegistration` |
| Compile status | `0 errors, 0 warnings, 12918 ms elapsed, cpu='X64 Regular'` |
| Working tree | clean except `JA_FalconCore_Project_Memory_R1_2d.md` untracked at root |
| Globals | 86 → 29 (vs baseline) |
| Layered structure | `Core/` `Evidence/` `Risk/` `TradeManagement/` `Execution/` `Router/` `Strategies/` `Reporting/`; trade logic lives in `CFalconRiskLifecycleProcessor`; `CFalconReportWriter` is writer-only |

### R1.2d sub-commit chain (all in current candidate)

| Commit | Purpose | Files touched |
|---|---|---|
| `997cf73` | R1.2b — real entry execution for S00 via broker bridge (Tester only) | bridge + S00 entry |
| `ae42caa` | R1.2c — real close execution; S00 closes by logic, not broker stops | `FalconBrokerEntryBridge.mqh` (`TryManagedCloseFromS00Trade`), `S00_EntryLogic.mqh::CloseActiveTrade` |
| `757aade` | R1.2d core — S00 calls `RegisterClosedTrade(lifecycle_record)` → central reports populate | `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` (`BuildLifecycleRecordFromS00Trade` private helper), `Core/FalconConstants.mqh:10-11` (tag bump) |
| `9656168` | R1.2d completion — `StorePaperFinalRecord` made public + called from S00; `m_trade_sequence` counter → `S00_SCALP_FVG_<unix>_<seq>` unique ids | `Execution/FalconBrokerEntryBridge.mqh` (public:/private: markers; body untouched), `S00_EntryLogic.mqh` (member + init + unified `s00_unique_id`) |
| `5be1778` | R1.2d BreachFix — frozen `original_structural_sl` field captured at open from `plan.stop_loss` so BE-armed trades don't write `entry_price==structural_sl` into the lifecycle record | `S00_EntryLogic.mqh` only (~12 lines: new struct field on `S00PaperTrade`, init in step 3e, read in `BuildLifecycleRecordFromS00Trade`) |

### Numbers the candidate currently produces

| Test | Result | Notes |
|---|---|---|
| FixedLot April, `S00_RealExecution=false` | `585.17 / 1104.89 / 157.49` | Must remain byte-for-byte — gate-closed regression check |
| 3-month March–May 2026, `S00_RealExecution=true` (after BreachFix) | Paper: 29 trades (6 wins / 13 BE / 10 loss); `RawNetUSD=+38.30$`, `FinalWorkingNetUSD=+40.22$`. Broker: **`+0.10$`** — 25 executed, 4 rejected (single-position cap). Monthly: Mar `−5.20$`, Apr `+17.43$`, May `−12.13$` | Reports now populated; dual-report works |
| 3-month with R1.2d baseline (April 2026) BEFORE BreachFix | `TotalTrades=536`, `InvariantBreaches=2` | After BreachFix: `InvariantBreaches=1` (only the pre-existing `paper_state_snapshot` debt) |
| Safety guards | `BrokerModifySent=0`, `RuntimeSLChanged=0` ✓ | Held all the way through |

---

## 3. Failed / Rejected / Superseded Versions

| Version | Status | Why |
|---|---|---|
| `v0.55.4d_Candidate` | Rejected (not promoted to LOCKED) | Static validation issues — see `JA_FalconCore_v0_55_4d_Static_Validation.txt` |
| `v0.55.7c_Candidate` | Rejected | Did not advance to LOCKED — see `…7c_Static_Validation.txt` |
| `v0.55.7d_Candidate` | Rejected | Did not advance to LOCKED — see `…7d_Static_Validation.txt` |
| R1.2b (commit `997cf73`) — entry-only | Superseded | Broker entries wired but real-execution P&L was `−86.42$` over 3 months because closes still hit broker stops, not S00 logic |
| R1.2c (commit `ae42caa`) — close wired but reports empty | Superseded | Real-close worked (25/25 closed via `EXPERT_CLOSE_EXIT`; P&L jumped `−86.42$` → `+0.10$`) but central reports stayed empty (`Summary.TotalTrades=0`, every Reconciliation row `BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE`) |
| R1.2d core (commit `757aade`) — reports populated but with three gaps | Superseded by completion | (a) Reconciliation still flagged broker-only because `StorePaperFinalRecord` never called from S00 path; (b) `trade_id = S00_SCALP_FVG_<unix>` duplicated across same-bar entries; (c) `shadow_id` and `trade_id` built at two separate sites — drift hazard |
| R1.2d completion (commit `9656168`) — Reconciliation linked + ids unique | Superseded by BreachFix | Three-month run revealed `InvariantBreaches = 2` vs legacy `1`: extra +1 from `dynamic_lotsizing_invalid_trades++` because BE-armed S00 trades wrote `record.structural_sl == record.entry_price` (`stop_loss` was mutated by BE arming at `S00_EntryLogic.mqh:465`) |

**Old refactor stages (R0.1 → R0.9, R1.1a/b/c, R1.2a)** are all rolled into the current `refactor` branch history — none are "rejected", they are sequential predecessors merged forward.

---

## 4. Current Blocker (the open question)

**S00 real-execution weakness — no diagnosis yet.**

- Historical paper record (R1.2a) for S00 showed **+19,151 winning points** on paper.
- 3-month real-execution run (Mar–May 2026) gives **`+0.10$` — effectively breakeven**.
- **84% of real-execution trades close at stop or BE.** Win rate 21% (6/29 paper), real 25/29 executed.
- Mechanically reports are clean now (post-BreachFix): `BROKER_ONLY_*` gone, no duplicate `trade_id`, `dynamic_lotsizing_invalid_trades = 0`, `structural_sl` correct, `BrokerModifySent=0`, `RuntimeSLChanged=0`.
- The remaining `InvariantBreaches = 1` is the **pre-existing project-wide debt** `paper_state_snapshot_written_rows != total_trades` at `FalconReportWriter.mqh:4012-4013` — present in legacy baseline too (`PaperStateRecoveryMode = FOUNDATION_ONLY_STATE_RESTORE_DISABLED`). NOT a candidate-introduced regression. Logged as backlog **#68/#69**.

**The big question for the next phase (no guessing — Rule 10 says start with data):**
- Was the +19,151 paper figure from a different period or different parameter set?
- How much edge does spread / slippage / broker cost eat?
- Is breakeven protection arming at the right moment?
- Why do 84% of trades end at stop or BE?

---

## 5. Next Safe Development Step

**Data-driven diagnosis of S00 real-execution weakness — analysis, NOT code yet.**

Mandatory inputs for each diagnosis pass (operator-uploaded after every real-execution test):
1. `Summary.csv`
2. `TradeLifecycle.csv`
3. `BrokerExecutionLifecycle.csv`
4. `BrokerPaperTradeReconciliation.csv`

Hard verification protocol unchanged: dual-criterion gate.
- Gates closed (`S00_RealExecution=false`) → `585.17 / 1104.89 / 157.49` byte-for-byte.
- Gates open → 3-month run, current candidate behaviour reproduces or improves.

Strategy decision still **deferred to R1.0** per Decision #8 — S00's logical core is known weak (raw edge: avg win `2.97` vs avg loss `2.96` — doesn't survive execution costs).

---

## 6. Files That MUST NOT Be Used / Touched

### Hard prohibitions (project rules — never broken)

| Path / Symbol | Reason |
|---|---|
| `OrderModify` / `BrokerModify` / `TRADE_ACTION_SLTP` | Banned operations — never appear in repo |
| `RuntimeSLChanged` events | Never raised — Bridge closes are reverse-deal only |
| `OrderSend` inside any Strategy Engine | Strategies only signal; execution is the Bridge |
| Any open-bar / live-price reads (lookahead) | Closed candles only |
| Early Break-Even logic | SL is structural; BE arming uses `original_structural_sl` snapshot |
| `EnableRealExecution` outside `MQL_TESTER` | Real execution is tester-only until promotion |

### Files that ship in the candidate but must NOT be edited as part of S00 diagnosis

| Path | Why |
|---|---|
| `JA_FalconCore_Automated_Trading_Platform.mq5` (main) | Untouched in R1.2c/d — keep that way |
| `Reporting/FalconReportWriter.mqh` | Writer-only; Apply chain dispatcher; do not change |
| `Risk/FalconRiskLifecycleProcessor.mqh` (entire 1643-line file) | Contains the 12 `Apply*` methods — Rule "no editing Apply* during refactor" |
| `Core/FalconDataStructures.mqh` → `FalconTradeLifecycleRecord` struct | Schema frozen — fields only filled, never added/removed |
| `Execution/FalconBrokerEntryBridge.mqh` → `TryManagedCloseFromLifecycleRecord` | Legacy close path — must remain byte-stable |
| `Execution/FalconBrokerEntryBridge.mqh` → `StorePaperFinalRecord` body | Access changed to `public:`; body itself stays verbatim |
| `Execution/FalconShadowExecutor.mqh` | Legacy shadow plumbing — only emitter of `FALCON_TRADE_STAGE_SHADOW` |
| `FalconShadowTradeRecord` plumbing (e.g. `S00_EntryLogic.mqh:787` `s00_record.structural_sl = m_active_trade.stop_loss`) | Reads `stop_loss` at OPEN time when `stop_loss == original_structural_sl` exactly — leave alone |
| Legacy strategy path: the `if(!S00_RealExecution)` block in `OnTick` | Verbatim — must remain so `S00_RealExecution=false` reproduces baseline |
| `Strategies/FalconStrategies_Placeholder.mqh` | Placeholder only — not a real consumer |

### 12 `Apply*` chain order (load-bearing — DO NOT REORDER)

`#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12` — not ascending; this order is what produces `585.17 / 1104.89`.

### Archive / historical (read-only reference, never source-of-truth)

- All `Docs/ProjectMemory/*v0_55_*_LOCKED.docx` — historical lock points
- All `Docs/ProjectMemory/*Candidate.docx` — rejected lineage
- All `Docs/ReviewNotes/R0_*.md` and `Docs/Specs/JA_FalconCore_R1_1*.md` — superseded by R1.2d artifacts
- `Docs/Archive/` — quarantine
- `JA_FalconCore_Project_Memory_R1_2d.md` (root) is the active memory (will move into `Docs/ProjectMemory/` per convention on the next phase commit)

### Disabled by design (do not "fix" without a dedicated phase)

- `paper_state_snapshot` writer (`AppendPaperStateSnapshotRecord` not wired for S00) → causes `InvariantBreaches=1` in BOTH baseline and candidate. Backlog items **#68/#69**. Out of scope for S00 diagnosis.

---

## 7. Required Regression Tests

### A. PRIMARY — gate-closed byte-stability (every commit on `refactor`)

| Setting | Required output |
|---|---|
| Period | April 2026, FixedLot |
| Inputs | `EnableRealExecution = ` (default), `S00_RealExecution = false` |
| Result | **EXACT**: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, BrokerNet `200 → 157.49` (delta `−42.51`) |
| Failure | Any deviation = candidate broke legacy lane → block commit |

### B. SECONDARY — gate-open 3-month real-execution

| Setting | Required output |
|---|---|
| Period | March–April–May 2026 |
| Inputs | `EnableRealExecution = true`, `S00_RealExecution = true`, FixedLot |
| Summary | `TotalTrades > 0` (current ≈ 29 paper / 25 broker-executed; April-only ≈ 536) |
| Reports | `TradeLifecycle.csv` populated, `BrokerExecutionLifecycle.csv` populated, `BrokerPaperTradeReconciliation.csv` finds Paper match (no `BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE` rows for S00) |
| Uniqueness | `awk -F, '{print $trade_id_col}' TradeLifecycle.csv | sort | uniq -d` returns empty (zero duplicate `trade_id`) |
| `dynamic_lotsizing_invalid_trades` | `0` |
| Safety guards | `BrokerModifySent = 0`, `RuntimeSLChanged = 0` |
| `InvariantBreaches` | `1` allowed (paper_state_snapshot pre-existing baseline debt) — `2` or higher = regression |

### C. COMPILE

| Step | Required output |
|---|---|
| `metaeditor64.exe /compile:JA_FalconCore_Automated_Trading_Platform.mq5` | `Result: 0 errors, 0 warnings` |
| VS Code Problems window | `0 issues` |

### D. SANITY (manual, per phase)

- `EA_VERSION_TAG` matches the phase being tested (rebuild required if not).
- `git diff --stat` matches the spec's "files touched" table — no scope creep.
- Reports uploaded to Claude after each gate-open run before further changes.

---

## 8. Rules That Will Not Bend (Operational Constants)

1. **No `OrderSend` in any Strategy Engine.**
2. **No lookahead — closed bars only.**
3. **No early break-even; SL is structural.**
4. **No `BrokerModify` / `TRADE_ACTION_SLTP` / `RuntimeSLChanged`.**
5. **`EnableRealExecution` default off; real execution tester-only via `MQL_TESTER`.**
6. **Every release: 0 errors compile → tested → committed in ONE commit before next.**
7. **No history-rewriting git ops** (reset/rebase) except for extreme need.
8. **No editing `Apply*` chain or entry logic during refactor.**
9. **Phase work flows:** Claude (plan/SPEC) → Claude Code (edits) → user F7 in MetaEditor → Strategy Tester → reports back to Claude.
10. **No guessing — data first.** Diagnosis starts with the four core reports, not hypotheses.

---

## 9. Deferred Items (Backlog — NOT for this phase)

From `Docs/Ideas_Backlog.md` (current open items relevant to S00):
- **#65** ✓ closed by R1.2d core
- **#66** — Revisit `stage` enum semantics once a second real-executing strategy lands
- **#67** — Decision on whether to block multiple S00 entries on the same bar (strategy decision)
- **#68 / #69** — Enable `paper_state_snapshot` writer for S00 path (closes the `InvariantBreaches=1` debt project-wide)
- Multi-strategy magic-number isolation + Bridge generalization
- Removal of legacy `FVG_MICRO_RETEST` strategy
- Wave-analysis strategy (S0x)
- Runner / trailing stop above winning structural base
- Fix `PenetrationDepth` column
- S00 time filter

---

## Probe Recovery Anchors (compression-validation)

If a future session probes this summary, these answers must be derivable:
- **"What is the LOCK baseline number?"** → `585.17 / 1104.89 / 157.49` for FixedLot April, gates closed.
- **"What is the current candidate?"** → R1.2d, branch `refactor`, head `5be1778`, `EA_VERSION_TAG=R1_2d`, `EA_BUILD_TAG=CentralLifecycleRegistration`.
- **"Which files were changed in R1.2d BreachFix?"** → `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` only (~12 lines), plus docs.
- **"What is the blocker?"** → S00 real-execution edge collapses to `+0.10$` over 3 months; 84% close at stop/BE; root cause not yet diagnosed.
- **"What's the next safe step?"** → Data-driven analysis on the four core reports; no code change.
- **"What is the Apply* order?"** → `#3,#4,#5,#6,#7,#8,#10,#9,#1,#2,#11,#12` — load-bearing, never reorder.
- **"What `InvariantBreaches` value is acceptable?"** → `1` (paper_state_snapshot pre-existing baseline debt).
