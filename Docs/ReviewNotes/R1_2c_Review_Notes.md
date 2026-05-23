# R1.2c — Realistic Close Execution (S00 closes its own trade, not the broker stop)

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.2b (commit `997cf73`).

R1.2c is the symmetric counterpart to R1.2b. R1.2b broke paper isolation on the **entry** side; R1.2c does the same on the **exit** side. When `CS00EntryLogic::RunExitEvaluation` decides to close a trade — `S00_EXIT_TARGET`, `S00_EXIT_STOP` (structural pre-arm or breakeven post-arm), or `S00_EXIT_TIMEOUT` — the strategy now hands the same decision off to the broker bridge, which issues a reverse-deal close against the live position. The broker stop is still attached (the v0.56.9b emergency envelope from `BuildLockParityEmergencyServerStops`), but it is now a *safety net behind* S00's own logic rather than the primary close mechanism.

The diagnosed failure mode in R1.2b was: every S00 broker entry got attached to a server SL/TP envelope (~3 × structural distance, capped at 25–300 price points with USD-loss binary search). With no close path wired from S00, the broker's emergency envelope hit before S00's own target / breakeven / timeout had a chance — every trade exited via `SERVER_SL_EXIT` or `SERVER_TP_EXIT`. R1.2b shipped a paper-side +19,151-point baseline against a broker-side −86.42 USD result. R1.2c closes that gap by routing S00's exit decision into the same `ExecuteReverseClosePositionRequest` helper that the Virtual Trailing Bridge uses for the legacy strategy.

> Active spec: `JA_FalconCore_R1_2c_SPEC.md` (repo root; will be moved into `Docs/Specs/` per the R0.9 convention in a follow-up chore commit if R1.2c ships green).

---

## 1. What was built

| Item | Path | Notes |
|---|---|---|
| `trade_id` field on the paper-trade record | `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` (`S00PaperTrade`) | New `string` field inserted between `real_entry_price` and `real_entry_slippage` (literal spec placement). Stores the same id the bridge keys on (`"S00_SCALP_FVG_<unix_secs>"`). Empty when any real-execution gate was shut at open. |
| `trade_id` reset at entry | `S00_EntryLogic.mqh` (entry step, alongside the four `real_entry_*` resets) | Cleared to `""` before the gate check so paper-only trades carry no stale id. |
| `trade_id` capture at the bridge open call | `S00_EntryLogic.mqh` (entry step, immediately after `real_entry_attempted = true`) | Computed via the same `"S00_SCALP_FVG_" + IntegerToString((long)entry_time)` formula the bridge uses for `shadow_id`. Set BEFORE the bridge call so it is present even if the bridge later rejects the order — this is intentional: the close path checks `FindActiveLinkByTradeId` which itself returns `false` on no-link-found and is a clean no-op. |
| Bridge close call at `CloseActiveTrade` | `S00_EntryLogic.mqh` (`CloseActiveTrade`, after `AppendTradeRow(m_active_trade)`) | Three-gate `if` block (mirrors R1.2b's entry gate) calling `g_broker_entry_bridge.TryManagedCloseFromS00Trade(trade_id, exit_price, reason, g_report_writer)`. Placed AFTER `AppendTradeRow` so the paper CSV row is written regardless of bridge outcome, and BEFORE `m_active_trade.open = false` so the trade state is still "open" for any reentrant assertion the bridge might perform. |
| New bridge function | `Execution/FalconBrokerEntryBridge.mqh` (after `TryManagedCloseFromLifecycleRecord`) | `bool TryManagedCloseFromS00Trade(const string &trade_id, const double exit_price, const ENUM_S00_TRADE_EXIT_REASON reason, CFalconReportWriter &report_writer)`. ~75 lines. Re-enforces the three gates, validates trade_id non-empty, looks up the active link via the existing `FindActiveLinkByTradeId`, validates the broker position is still alive and identity-matches (`_Symbol + FC_MAGIC_FVG_MICRO`), then delegates to the existing `ExecuteReverseClosePositionRequest` helper. **No new OrderSend logic.** |
| `EA_VERSION_TAG` + `EA_BUILD_TAG` | `Core/FalconConstants.mqh:10-11` | `R1_2b` → `R1_2c`; `StructuralBreakeven` → `RealisticCloseExecution`. |

**Net file delta (3 files):**
- `Core/FalconConstants.mqh`: 2 lines changed (version + build tag).
- `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh`: ~30 lines added (1 struct field with header comment, 1 reset line, 6 lines at the entry block, ~20 lines at `CloseActiveTrade` with header comment).
- `Execution/FalconBrokerEntryBridge.mqh`: ~95 lines added (1 new member function with header comment).

Main `.mq5` is **not** touched — the close call lives entirely inside the strategy, same as the entry call in R1.2b. `FalconReportWriter.mqh` is **not** touched in this phase — the dual paper-vs-real report column work from SPEC §5 is deferred (see Backlog).

---

## 2. The three gates — fail-closed by construction, repeated on both ends

The close-side condition is the strict conjunction of the same three flags R1.2b used at entry:

```mql5
if(MQLInfoInteger(MQL_TESTER)
   && EnableRealExecution
   && S00_RealExecution)
{
   g_broker_entry_bridge.TryManagedCloseFromS00Trade(...);
}
```

…and the bridge function re-enforces them at its top:

```mql5
if(!MQLInfoInteger(MQL_TESTER)) return false;
if(!EnableRealExecution)        return false;
if(!S00_RealExecution)          return false;
```

This is **defense-in-depth** — either layer alone is sufficient to keep the legacy FixedLot April baseline (`585.17 / 1104.89 / 157.49`) byte-for-byte safe when gates are shut. The redundancy matches the R1.2b pattern at the entry side: the call site documents the safety contract; the bridge enforces it independently so a future caller can't bypass it.

### 2.1 Verification — what each closed gate prevents on the close side

| Gate state | Behavior |
|---|---|
| `MQL_TESTER = false` (Demo / Live) | `if(...)` is false; no bridge close call. Bridge function itself would also return false on the first gate. |
| `EnableRealExecution = false` (default) | `if(...)` is false; no bridge close call. CSV paper rows identical to R1.2b. |
| `S00_RealExecution = false` (default) | `if(...)` is false; no bridge close call. The strategy is paper-only on both sides — the legacy `FVG_MICRO_RETEST` runtime/shadow pipeline owns the broker lane (R1.2a coexistence gate). |
| All three `true` (Tester only) | Bridge call fires on every S00 close. Returns `false` cleanly when there's nothing to close (paper-only trade, position already closed by server envelope, identity mismatch). |

---

## 3. Lookahead audit

R1.2c adds **zero new bar/price reads**. The only inputs to the new close path are:
- `m_active_trade.trade_id` (set at entry, not read from the chart).
- `exit_price` and `reason` (already computed by `RunExitEvaluation` from closed-bar data).
- Live position state (`PositionSelectByTicket` + `PositionGetDouble(POSITION_VOLUME)` + `PositionGetInteger(POSITION_TYPE)`) — broker-side metadata about an existing position, not a chart read.
- The reverse-deal tick price (`SymbolInfoTick(_Symbol, tick).bid` / `.ask`) — same live-tick read R1.2b documented at the entry side, and identical to what any live broker EA would use to price a reverse deal. **No closed-bar decision uses these values.**

Closed-bar invariants (`shift >= 1`, `CopyBuffer start=1`) are unchanged. The strategy's decision to close was already finalized using closed-bar data inside `RunExitEvaluation` (steps 1–4 of the pessimistic short-circuit ordering). The bridge call is a post-decision side-effect, same as the entry-side R1.2b pattern.

---

## 4. The no-modify-SL rule — how breakeven is realised at the broker

**Project memory rule:** no `OrderModify`, no `BrokerModify`, no `TRADE_ACTION_SLTP`, no `RuntimeSLChanged`. The R1.2c exploration report (six-axis read of the R1.2b state) confirmed this rule is currently absolute — zero call sites in the codebase. R1.2c **does not break this rule.**

S00's breakeven protection mechanism is unchanged from R1.1c-fix:
1. On the bar where favourable excursion reaches `S00_BreakevenTrigger` points, `m_active_trade.breakeven_armed = true` and `m_active_trade.stop_loss = entry_price` (paper-side mutation only — the *broker* stop is untouched).
2. On any subsequent bar, the pessimistic-ordered evaluator (`RunExitEvaluation` step 1) tests `bar.low ≤ stop_loss` (BUY) or `bar.high ≥ stop_loss` (SELL) against the new `stop_loss == entry_price`. If hit, it calls `CloseActiveTrade(bar.time, sl, S00_EXIT_STOP)`.
3. `CloseActiveTrade` writes the paper row, then (with gates open) calls the bridge close. **The broker position is closed by reverse deal, not by moving the server stop.**

This is exactly the pattern the Virtual Trailing Bridge already uses for the legacy strategy: virtual stop moves are tracked in `link.virtual_trailing_stop_price`, and when the live price crosses the virtual stop, the bridge issues a reverse-deal close via the same `ExecuteReverseClosePositionRequest` helper R1.2c now reuses. R1.2c is structurally aligned with that design — no new mechanism, no new policy.

---

## 5. Edge cases handled at the bridge

The new function rejects cleanly (returns `false`) for these states:

| Condition | Why it's a no-op rather than an error |
|---|---|
| `trade_id == ""` | Paper-only trade (any gate was shut at open). There is no broker position to close. |
| `FindActiveLinkByTradeId` returns false | Link already consumed (bridge close ran in a prior tick, or another path already marked it closed). |
| `link.broker_position_ticket <= 0` | Entry was attempted but the bridge rejected it (lot authority, plan validation, etc.). |
| `PositionSelectByTicket` fails | The server's emergency SL/TP envelope already closed the position before S00 reached its decision. The link is marked closed via `MarkLinkClosed(...)` so it doesn't stay stale and block the next entry. |
| Symbol or magic mismatch | A stale link or a position that's not Falcon's. Should never happen with the magic filter on `CountOpenFalconPositions`, but checked defensively (same pattern as `TryManagedCloseFromLifecycleRecord` line 1694). |
| `volume <= 0` | Degenerate position state. Same defensive pattern as the lifecycle path (line 1716). |

In all six cases, the paper-side CSV row has already been written (by `AppendTradeRow` upstream), so S00's diagnostic output stays consistent with the paper baseline. Only the broker side declines.

---

## 6. Why the lifecycle close path was not reused for S00

The existing `TryManagedCloseFromLifecycleRecord(...)` takes a `FalconTradeLifecycleRecord &record` — a >200-line struct built by the legacy strategy's `g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord(...)`. S00 doesn't produce that record (it has its own much smaller `S00PaperTrade` struct). Adapting `FalconTradeLifecycleRecord` to S00 would mean either:
- Building a synthetic lifecycle record at every S00 close (huge data-shape impedance mismatch), or
- Refactoring `TryManagedCloseFromLifecycleRecord` to take the minimal subset it actually needs.

The exploration report confirmed that `TryManagedCloseFromLifecycleRecord` only reads three things from the record — `record.trade_id` (for the link lookup) and `record.paper_*_exit_reason` fields (for the log line). The rest of the struct is decorative for that path. So R1.2c creates a parallel slim function (`TryManagedCloseFromS00Trade`) that takes exactly those inputs from S00's smaller surface, and reuses `ExecuteReverseClosePositionRequest` — the OrderSend block the lifecycle path also delegates to. **Zero duplication of broker-touching code.**

A future generalization (decouple `ENUM_S00_TRADE_EXIT_REASON` from the bridge file, hoist to a strategy-agnostic `ENUM_FALCON_STRATEGY_EXIT_REASON`) is on the backlog as item #62. Today the enum is visible inside the bridge because the include order is: `S00_EntryLogic.mqh` (line 97) precedes `FalconBrokerEntryBridge.mqh` (line 5676) in the main `.mq5`. This is fragile if includes ever get reordered, but flagged-not-fixed — same shape as the `g_broker_entry_bridge` / `g_report_writer` forward references the entry side already relies on.

---

## 7. Compile result

Built with MetaEditor `metaeditor64.exe /compile:JA_FalconCore_Automated_Trading_Platform.mq5`:

```
Result: 0 errors, 0 warnings, 14332 ms elapsed, cpu='X64 Regular'
```

All R1.2c includes resolve, no signature mismatches, no unresolved identifiers (`MarkLinkClosed`, `FindActiveLinkByTradeId`, `ExecuteReverseClosePositionRequest`, `EnumToString(reason)`, `S00_RealExecution` all resolve correctly through the existing two-pass parse pattern).

---

## 8. What is NOT in R1.2c

The SPEC §4.5 + §2 acceptance criterion 4 calls for a new dual paper-vs-real report (`PaperResult`, `RealResult`, `Gap` columns). **R1.2c does not ship that report.** The bridge already emits `BrokerManagedCloseLifecycleRecord` rows for every close it issues (via `ExecuteReverseClosePositionRequest` line 1576), and the strategy already emits paper rows. The two streams can be cross-joined externally on `trade_id` for analysis. A first-class joined report is on the backlog as item #60 — wired only after the three-month tester run validates that real closes are firing as designed.

Also not in R1.2c:
- **No three-month verification run.** That requires the operator to flip `S00_RealExecution = true` and run the tester across March + April + May 2026. The build is green; the run is the next step but out of the scope of this code change.
- **No slippage capture on close.** `ExecuteReverseClosePositionRequest` returns `executed_price` and `result_comment`, but the new function discards them after the call. Item #61 in the backlog.
- **No removal of the v0.56.9b emergency envelope SL/TP at open.** The server stop is still attached as a safety net behind S00's own close logic. Removing it (and going to a "naked" broker order with only EA-managed close) is a separate decision after R1.2c validates that S00's close fires consistently. Item #63.

---

## 9. Files changed

```
Core/FalconConstants.mqh                          | 2 ± lines (version + build)
Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh   | ~30 + lines (field + reset + capture + close call)
Execution/FalconBrokerEntryBridge.mqh             | ~95 + lines (new TryManagedCloseFromS00Trade member)
Docs/ReviewNotes/R1_2c_Review_Notes.md            | new (this file)
Docs/Ideas_Backlog.md                             | items #60..#65 appended
```

No other files modified. Main `.mq5` untouched. `FalconReportWriter.mqh` untouched.

---

## 10. Sanity checks before commit

- ☑ Compile: `0 errors, 0 warnings`.
- ☑ FixedLot April baseline guarantee: with `S00_RealExecution = false` (default), no R1.2c code path executes — the bridge close `if` is false at the call site, and even if a stale `trade_id` were somehow set, the bridge function's first gate fails. The legacy `FVG_MICRO_RETEST` close path (`g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord → TryManagedCloseFromLifecycleRecord`) is untouched, including its `m_active_links[]` data and its Virtual Trailing Bridge.
- ☑ No `OrderModify` / `BrokerModify` / `TRADE_ACTION_SLTP` calls introduced (grepped; still zero in the repo).
- ☑ Three gates present at both call-site and bridge function.
- ☑ Lookahead invariant preserved.
- ☑ Magic-number isolation preserved (`FC_MAGIC_FVG_MICRO` is the only magic the bridge close-path operates on; the coexistence gate keeps the legacy strategy dark when `S00_RealExecution = true`).
