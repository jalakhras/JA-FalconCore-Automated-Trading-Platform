# R1.4a — Broker-truth meter (reporting-only)

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.3a (commit `9b5e9bc`) &nbsp;|&nbsp; **Version:** `EA_VERSION_TAG = R1_4a`, `EA_BUILD_TAG = BrokerTruthMeterReporting`.

R1.4a is Phase 2a — a **pure reporting change**. The `PaperBrokerGap` diagnosis (`Docs/ReviewNotes/JA_FalconCore_Diagnosis_PaperBrokerGap_R1_3a.md`) established that paper `FinalWorkingNetUSD` is not the truth (it zeroes 589 emergency-BLOCKED trades the broker actually executed), and that the Summary carries **no aggregate broker-net figure** at all. R1.4a surfaces the existing broker truth and tags the ghost gap category — **adding columns only**, touching no calculation, no Apply chain, no emergency logic, no execution code.

> Active spec: `Docs/Specs/JA_FalconCore_R1_4a_BrokerTruthMeter_SPEC.md` (moved from repo root on phase completion, R0.9 convention).

---

## 1. What was built (2 code files only)

### `Reporting/FalconReportWriter.mqh`

**a. Broker-truth accumulators (private members of `CFalconReportWriter`).**
Three members added next to `m_broker_entry_bridge_order_send_attempts` (~`:84`):
```
double m_broker_actual_net_usd;
int    m_broker_actual_win_trades;
int    m_broker_actual_lose_trades;
```
They live on the report-writer class, **not** in `FalconReportTotals`, because that struct is declared in `Core/FalconDataStructures.mqh` — a file this reporting-only phase must not touch. Reset in `ResetTotals()` (so both the constructor and `Initialize()` zero them per run).

**b. Accumulation mirrors the `BrokerActualUSD` column.** In **both** reconciliation-row writers — `AppendBrokerPaperTradeReconciliationRecord` and `AppendBrokerOnlyTradeReconciliationRecord` — at the point each row is written:
```
m_broker_actual_net_usd += link.broker_actual_balance_delta;
if(link.broker_actual_balance_delta > 0.0)      m_broker_actual_win_trades++;
else if(link.broker_actual_balance_delta < 0.0) m_broker_actual_lose_trades++;
```
This is the same field (`link.broker_actual_balance_delta`) the `BrokerActualUSD` column already prints (`:976` paper / `:1092` broker-only), summed across the same rows. Therefore `BrokerActualNetUSD == sum(BrokerActualUSD column)` **by construction** — the internal-consistency acceptance check holds definitionally. Intermediate trace rows (pre-exit) carry a 0 delta, so they add nothing and trigger no win/lose; each executed trade's real delta appears on exactly one row.

**c. Summary — 4 columns appended at the END** of `SlimSummaryHeaderV0555()` and `WriteFinalSummary`'s `summary_row`:
`BrokerActualNetUSD` (`m_broker_actual_net_usd`, 2dp), `BrokerActualWinTrades`, `BrokerActualLoseTrades`, `PrimaryResultMetric` (constant `BROKER_ACTUAL_NET_USD`). No existing column moved or recomputed.

**d. Reconciliation — 1 column appended at the END** of `WriteBrokerPaperTradeReconciliationHeader` and **both** row writers: `LockParityGapIsEmergencyZeroingArtifact`.
- Paper rows: `YES` iff `MathAbs(paper_final_points) < 1e-9 && record.falcon_emergency_status == "BLOCKED"`, else `NO`.
- Broker-only rows: always `NO` (no paper emergency context).

### `Core/FalconConstants.mqh`
`EA_VERSION_TAG` `R1_3a → R1_4a`; `EA_BUILD_TAG` `S01HarnessDeterministicEntry → BrokerTruthMeterReporting`.

---

## 2. Constraints honoured

- `Risk/FalconRiskLifecycleProcessor.mqh` — **untouched**. Apply chain order — untouched. Emergency logic — untouched.
- No existing column deleted or reordered; the four/one new columns are appended at the end of each header (and the matching values at the end of each row). Column counts verified aligned: Summary +4 header / +4 row; Reconciliation +1 header / +1 row in both writers.
- No existing value recomputed (`RawNetUSD`, `FinalWorkingNetUSD`, `BrokerActualUSD` read as-is).
- No execution code, no strategy file touched. No existing category renamed (the ghost is tagged by a new column, per the spec).
- Only `Reporting/FalconReportWriter.mqh` + `Core/FalconConstants.mqh` changed.

---

## 3. Build & Problems

`MetaEditor64.exe /compile` of `JA_FalconCore_Automated_Trading_Platform.mq5`:
**`Result: 0 errors, 0 warnings`** (code generated 100%). Problems panel: clean.

---

## 4. Tests — handoff (must run in the MT5 Strategy Tester)

The Strategy Tester is interactive; it could not be driven headlessly from the build host. Run both and confirm. Reports land in `C:\Users\jalak\AppData\Roaming\MetaQuotes\Terminal\Common\Files`.

**Test A — regression (April legacy baseline, R0 base run mode):**
- `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, `TotalTrades = 536` — literally, at their (unchanged) positions.
- `TradeLifecycle.csv` byte-identical to a pre-2a run (this phase does not write TradeLifecycle).
- The four new Summary columns appear populated; `BrokerActualNetUSD` equals the sum of the `BrokerActualUSD` column in the same run's Reconciliation; `PrimaryResultMetric = BROKER_ACTUAL_NET_USD`.

**Test B — broker truth surfaced (S01, same R1.3a Test-B settings):**
- `BrokerActualNetUSD` ≈ sum of `BrokerActualUSD` in Reconciliation (~+243$), **not** −34.23$.
- `LockParityGapIsEmergencyZeroingArtifact = YES` on the emergency-zeroed (BLOCKED) trades, `NO` otherwise.
- Reports carry `Version = R1_4a`.

> Known ordering caveat: accumulators are summed as reconciliation rows are written during the run; trades still open at test end are flushed at deinit. If `WriteFinalSummary` runs before that flush, a handful of end-of-test deltas could be excluded — the same population as the ~85$ Reconciliation↔MT5 thread (#69-adjacent). Hence Test B is `≈`, not `==`.

---

## 5. Backlog

Three ideas logged in `Docs/Ideas_Backlog.md`: **#70** (make emergency a real entry-blocking governance — Phase 4), **#71** (rename the misleading `MANAGED_CLOSE_PRICE_POINTS_GAP` category in a cleanup phase), **#72** (pin a broker-side regression baseline; the paper `1104.89` is going stale — linked to #58).
