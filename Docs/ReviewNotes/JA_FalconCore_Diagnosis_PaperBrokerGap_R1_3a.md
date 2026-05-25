# R1.3a Diagnosis — Paper↔Broker gap for S01 trades: which number is the truth?

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.3a (commit `9b5e9bc`). &nbsp;|&nbsp; **Type:** read-only code diagnosis (no execution/report code touched).

Phase 1a closed with the execution spine proven (S01 trades really executed on the broker). But the Phase-1b tester reports showed the **paper truth-meter disagreeing with the broker** for the same S01 trades. Before Phase 2 (trade-management coordination + engine interface) is built on top of a success metric, this note establishes — from code, not guesswork — **which number is the truth and why the two close layers diverge.**

The pairing exploration brief is `Docs/ReviewNotes/JA_FalconCore_Exploration_PaperBrokerGap_R1_3a.md`.

---

## 0. The four numbers (observed, same S01 cohort)

| Metric | Value | Source column / field |
|---|---|---|
| `PaperRawUSD` | **+648.71** | `record.net_usd` (raw P&L at the planned exit) — `FalconReportWriter.mqh:974` |
| `PaperFinalWorkingUSD` | **−34.23** | `FalconTimelineFinalWorkingTradeUsd` → `record.falcon_emergency_after_net_usd` — `:975` |
| `BrokerActualUSD` | **+243.21** | `link.broker_actual_balance_delta` — `:976` |
| MT5 account net | **+328.59** | full account (incl. ~85 unobserved) |
| `LockParityGapUSD` | **+277.44** | `link.broker_actual_balance_delta − paper_final_usd` — `:977` |
| `MANAGED_CLOSE_PRICE_POINTS_GAP` | **540 / 585** | dominant gap category |

---

## Verdict (up front)

`PaperFinalWorkingUSD` is **NOT the truth**. The truth is the **broker side** (`BrokerActualUSD`, reconciled toward the MT5 account net). The gap is **(B) a semantic divergence between two different clocks — not a calculation bug and not, primarily, market slippage.** Its dominant driver is that the three-layer emergency system is a **paper-only, post-hoc overlay** that zeroes the P&L of 589 trades the broker actually executed, while broker entry is never gated by it.

---

## 1. How `PaperFinalWorkingUSD` is computed, and at what price

The Summary/Reconciliation field reads one record field:

```
Reporting/FalconReportWriter.mqh:314-317
double FalconTimelineFinalWorkingTradeUsd(const FalconTradeLifecycleRecord &record)
{ return record.falcon_emergency_after_net_usd; }
```
It is accumulated into the Summary total at `FalconReportWriter.mqh:4622` and `:4637`.

**Paper close price is the planned SL/TP level — literally, not a tick:**
```
Strategies/S01_Harness/S01_EntryLogic.mqh:155   CloseActiveTrade(bar.time, sl, S01_EXIT_STOP);
Strategies/S01_Harness/S01_EntryLogic.mqh:160   CloseActiveTrade(bar.time, tp, S01_EXIT_TARGET);
```
`record.exit_price` is set to that exact `sl`/`tp` level (`S01_EntryLogic.mqh:91, 124`). Exits are detected on a **closed** bar, so the paper close is an idealised fill at the planned level.

**The collapse +648 → −34 happens in the emergency layer — by zeroing:**
```
Risk/FalconRiskLifecycleProcessor.mqh:1358-1364
if(m_tle_emergency_active) {
   record.falcon_emergency_status = "BLOCKED";
   ...
   record.falcon_emergency_after_net_points = 0.0;
   record.falcon_emergency_after_net_usd    = 0.0;   // ← the zeroing
   return;
}
```
Once any trade fires a layer (`TRIGGERED`, `:1448-1451` sets `m_tle_emergency_active = true`), **every subsequent trade until reset is BLOCKED and its working net is set to 0.0.** That is why the 589 BLOCKED trades (whose raw P&L was net-positive) contribute 0, leaving only ~21 SAFE trades that happen to net −34.23.

---

## 2. How `BrokerActualUSD` is computed, and from where

Straight from the MT5 deal history (profit + swap + commission):
```
Execution/FalconBrokerEntryBridge.mqh:2213-2216
double profit     = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
double swap       = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
double actual_delta = profit + swap + commission;
```
Stored on the link (`broker_actual_balance_delta`) and written to the Reconciliation row at `FalconReportWriter.mqh:976`. The broker close price is the **actual market price at execution**: `HistoryDealGetDouble(trans.deal, DEAL_PRICE)` (`FalconBrokerEntryBridge.mqh:2217`).

**Commission and swap ARE included** (explicit sum at `:2216`). Therefore the Reconciliation(+243) ↔ MT5(+329) gap is **not** commission/swap — those are inside both numbers. It is most likely **unobserved closes** (end-of-test auto-close, or deals `OnTradeTransaction` never mapped to a link); see the recovery path `RecoverBrokerOnlyExitFromHistory` (`FalconBrokerEntryBridge.mqh:2283`). Secondary thread — confirm from run data.

---

## 3. The `MANAGED_CLOSE_PRICE_POINTS_GAP` category — corrected reading

The classifier (an `else if` chain inside the `managed_close_observed` branch) compares:
```
Reporting/FalconReportWriter.mqh:804   broker_actual_points_minus_paper_final = broker_actual_points - paper_final_points;
...
:909   else if(MathAbs(broker_actual_points_minus_paper_final) > 2.0)
:911       lock_gap_category = "MANAGED_CLOSE_PRICE_POINTS_GAP_ON_MATCHED_CLOSE";
```
And the paper side of that subtraction is the **post-zeroing** working points:
```
Reporting/FalconReportWriter.mqh:319-321
double FalconTimelineFinalWorkingTradePoints(...) { return record.falcon_emergency_after_net_points; }
```
For a BLOCKED trade `paper_final_points = 0`, so `|broker_actual_points − 0| > 2.0` is true for essentially any real broker outcome → the trade **falls into this category by construction.**

➡️ **The 540-trade category is an artifact of emergency zeroing, not a price-path difference.** The category name and its `primary_cause` string (`BROKER_..._CLOSE_PRICE_PATH_DIFFERS_FROM_LOCK_FINAL_POINTS`) are **misleading**. `ON_MATCHED_CLOSE` only means the broker close was *observed* (`:793`), not that prices matched.

> Secondary (genuine) thread: a separate column `close_price_delta = broker_close_price − paper_exit_price` (`FalconReportWriter.mqh:798-800`, written `:968`) captures the real planned-vs-actual price slip for non-blocked trades — but it is **not** what the 540-trade category keys on.

---

## 4. The managed-close path for S01

S01 fires its own close (it does not rely only on the legacy Virtual Trailing Bridge):
```
Strategies/S01_Harness/S01_EntryLogic.mqh:131-134
BuildLifecycleRecordFromS01Trade(lifecycle_record);
g_report_writer.RegisterClosedTrade(lifecycle_record);                            // paper side + Apply chain
g_broker_entry_bridge.TryManagedCloseFromLifecycleRecord(lifecycle_record, ...);  // broker reverse deal
```
The reverse close order is sent **at the current market tick** — `tick.bid` for a long, `tick.ask` for a short (`FalconBrokerEntryBridge.mqh:1539 / 1544`) — one bar after the planned level was touched (S01 evaluates exits on closed bars). The header comment notes the legacy Virtual Trailing Bridge (no `strategy_id` filter — Backlog #1/#64) may close it first. Either way the broker fill is at a different price/moment than S01's planned level — a real but **secondary** slip versus the zeroing.

**The branch point:** broker entry happens at signal time with **no emergency gate**:
```
Strategies/S01_Harness/S01_EntryLogic.mqh:246-247
m_active_trade.real_entry_accepted = g_broker_entry_bridge.TryOpenFromShadowRecord(s01_record, ...);
```
The `BLOCKED` status is computed later, at close, inside the Apply chain. So the emergency system is a **paper-only post-hoc overlay with zero effect on broker execution.**

---

## 5. Judgement

**Which number is the truth?**
- `PaperRawUSD` (+648.71): idealised paper P&L if every trade closed exactly at its planned SL/TP.
- `PaperFinalWorkingUSD` (−34.23): a **risk-gated counterfactual** — it zeroes trades that occurred while a paper emergency was active. It describes an account the emergency system *would* have produced *if* it gated entries. It did not.
- `BrokerActualUSD` (+243.21): the **observed truth** of what closed on the broker (profit+swap+commission).
- MT5 net (+328.59): the **full** account truth (incl. ~85 unobserved closes).

**Classification: (B) semantic divergence — not a calc bug.** Both numbers are arithmetically correct for what they measure. But the dominant cause is **not** slippage (as the category name implies); it is the **paper-only emergency zeroing** of trades the broker executed for real (and which were net-profitable in raw terms).

**Why paper is not a valid truth-meter:** the three-layer emergency gate never prevents broker entry; whenever it is active, the paper and broker numbers diverge systematically. Plus the paper side assumes an idealised fill at a planned level while the broker fills at a later market tick.

**Metric Phase 2 should adopt:** the **broker side** — `BrokerActualUSD` (observed) reconciled toward the MT5 account net — **not** `PaperFinalWorkingUSD`.

---

## Secondary threads / open items

1. **Reconciliation ↔ MT5 ~85 USD gap:** likely closes not observed by `OnTradeTransaction` (end-of-test / unmatched link). Recovery path at `FalconBrokerEntryBridge.mqh:2283`. Confirm from run data.
2. **Gap categoriser keys on zeroed points:** because it compares against `paper_final_points` (post-zeroing), it cannot distinguish "price path differs" from "paper was zeroed by emergency." Trusting the category name would send Phase 2 chasing a phantom slippage fix instead of the real issue.
3. **Open structural decision for the Phase-2 spec (NOT decided here):** should the emergency gate actually block broker *entries* (making paper and broker agree), or remain a diagnostic-only overlay? This is the lever that closes the semantic gap.
4. **Legacy coupling:** Virtual Trailing Bridge iterates all links with no `strategy_id` filter (Backlog #1/#64) and can close S01 positions.

*No fix proposed — diagnosis only. The Phase-2 spec is written on this foundation.*
