# R1.3a — `ReportIntegrityStatus = FAIL` is the pre-existing #69 structural debt, not an R1.3a regression

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.2d (commit `5be1778`) &nbsp;|&nbsp; **R1.3a:** commit `9b5e9bc` (`Version = R1_3a`, `Build = S01HarnessDeterministicEntry`).

R1.3a adds the S01 deterministic-entry harness (`Strategies/S01_Harness/`, a `#include` + an `OnTick` call in the main `.mq5`). During its verification, every R1.3a run showed four FAIL flags in `Summary.csv`. This note records the **read-only diagnosis** of those flags and the decision taken: they are the **already-documented structural false-positive** of `Docs/Ideas_Backlog.md` items **#68 / #69**, re-confirmed in the R1.3a lane — **not** a regression introduced by S01. No code in `Reporting/FalconReportWriter.mqh` was touched. Phase 1a is closed on this basis.

> Diagnosis was conducted as a pure code-analysis pass (no build, no edit to the check logic). All `path:line` references below are against the R1.3a tree.

---

## 1. What was observed

In `Summary.csv`, on **every** R1.3a run — including a **legacy-only** run with S01 disabled and zero `S01_HARNESS` rows:

| Column | Value |
|---|---|
| `ReportIntegrityStatus` | `FAIL` |
| `PaperStateStatus` | `FAIL` |
| `TradeRowsVsSummaryStatus` | `FAIL` |
| `InvariantBreaches` | `1` |

In contrast, the per-row and capital checks all PASS: `TradeLifecyclePhysicalRowStatus = PASS`, `CapitalFlowIntegrityStatus = PASS`. So the failure lives in the **summary-level aggregate** check, not in the trade rows.

---

## 2. Root cause — one symptom, one cause

All four flags are a single breach: `paper_state_snapshot_written_rows = 0` while `paper_state_snapshot_evaluated_trades == total_trades`.

The asymmetry is created in `AppendPaperStateSnapshotRecord` (`Reporting/FalconReportWriter.mqh:1439-1505`):

```
m_totals.paper_state_snapshot_evaluated_trades++;          // :1447  — BEFORE the gate, always runs
if(!EnableTierEmergencyReports) return; // R0.6b group gate // :1448  — returns here
...
m_totals.paper_state_snapshot_written_rows++;              // :1504  — only if the gate is passed AND write succeeds
```

The input defaults to OFF:

```
input bool EnableTierEmergencyReports = false;   // JA_FalconCore_Automated_Trading_Platform.mq5:1895
```

The R0.6b comment at `:1441-1446` documents the split intentionally: *"turn off the file write only, not the computation … the file-write-conditional counters (`written_rows`, `write_failures`) remain inside the gate."* So `evaluated_trades` always keeps pace with `total_trades`, while `written_rows` stays `0` whenever the snapshot file is gated off — which is the default profile (`ReportProfile = FALCON_REPORT_MINIMAL`, `JA_FalconCore_Automated_Trading_Platform.mq5:1872`).

Breach trace in `WriteFinalSummary`:

- `:4010` `total_trades != paper_state_snapshot_evaluated_trades` → **false** (both equal) → no increment.
- `:4012` `total_trades != paper_state_snapshot_written_rows` → **true** → `integrity_breaches` becomes exactly **1**.

That single breach cascades to all three status fields:

| Field | Line | Why it FAILs |
|---|---|---|
| `report_integrity_status` | `:4038` | `integrity_breaches != 0` (it is 1) |
| `paper_state_snapshot_status` | `:4031-4033` | requires `total_trades == written_rows` |
| `row_count_status` (`TradeRowsVsSummaryStatus`) | `:4046` | requires `total_trades == written_rows` |

The other `integrity_breaches` contributors (USD diffs, the other `*_evaluated_trades` counters, `physical_trade_rows_status`) are all clean — consistent with the count being exactly 1.

---

## 3. Naming caveat — `InvariantBreaches` carries `integrity_breaches`

The Summary column labelled `InvariantBreaches` (header `:5228`) is written from the **aggregate** `integrity_breaches`, not the local `invariant_breaches`:

```
:4154   summary_row += IntegerToString(integrity_breaches) + ",";
```

`invariant_breaches` itself (`:3977-3979`) only counts two true invariants (`dynamic_lotsizing_invalid_trades`, `layer_reset_duplicate_triggers`) and is **0** here. So "`InvariantBreaches = 1`" means *one aggregate integrity breach* (the paper-snapshot row mismatch) — **not** a lot-sizing or layer-reset invariant violation. The column name is misleading but the value is correct.

---

## 4. Not an R1.3a regression

- `Reporting/FalconReportWriter.mqh` is **byte-identical** between R1.2d and R1.3a — `git diff --stat 5be1778 9b5e9bc -- Reporting/FalconReportWriter.mqh` returns empty. The integrity logic did not change.
- The R1.3a delta (`git diff --stat 5be1778 9b5e9bc`) touches only: `Core/FalconConstants.mqh` (version/build tags), the main `.mq5` (+13 lines: S01 `#include` + `OnTick`), `S00_EntryLogic.mqh` (+15 diagnostic lines), the two new `S01_Harness/*` files, and root doc files. None touch a summary counter or the check logic.
- S01 reaches the report layer only through the same `g_report_writer.RegisterClosedTrade(...)` path S00 uses, and only when `Enable_S01_Harness` (default false) plus the real-execution gates are on. The FAIL reproduces with S01 disabled, so S01 is excluded as a cause.
- Origin is **R0.6b** (the `evaluated++`-before-gate / `written_rows++`-after-gate split), well before this phase.

---

## 5. Decision — accepted as known structural debt (#69)

This is a **structural false-positive**, not a data-integrity defect. The check at `:4012` / `:4031-4033` / `:4046` requires a **gated file-write counter** (`written_rows`) to equal the trade count, while R0.6b deliberately allows that write to be off. The meaningful invariant — *did the diagnostic computation run for every trade?* — is `evaluated_trades == total_trades`, and it **passes**.

`Docs/Ideas_Backlog.md` **#68 / #69** already document this exact debt. #69 confirms the identical figures in the **legacy April baseline** (`evaluated = 536`, `written = 0`, at `FalconReportWriter.mqh:4012-4013`) and frames it as a project-wide structural breach with two deferred remediation options:

- **(a)** make the check conditional on `PaperStateRecoveryMode != "..._DISABLED"` so the perpetual breach does not drown future real signals; or
- **(b)** wire `AppendPaperStateSnapshotRecord` for all writer paths (legacy + S00).

**Resolution for R1.3a / Phase 1a:** accept as the known #69 false-positive. **No change** to `FalconReportWriter.mqh` in this cycle. Options (a)/(b) remain deferred in #69 pending the operator's intent decision. The breach is now confirmed across three lanes: legacy, S00, and the R1.3a S01 harness.

---

## 6. How a reviewer verifies (read-only)

Open any failing `Summary.csv` and confirm the two adjacent columns:

- `PaperStateSnapshotEvaluatedTrades` == `TotalTrades` (e.g. 536 legacy / 1146 with S01),
- `PaperStateSnapshotWrittenRows` == `0`,
- `PaperStateSnapshotWriteFailures` == `0`.

If all three hold, the breach is the gated-write false-positive — no missing trade data. (A non-zero, non-matching `WrittenRows` together with `WriteFailures > 0` would instead indicate a genuine partial-write fault — not the case here.)
