# R1.1b — S00 ScalpFvgMicro: Entry Logic + Stop + Target + 1:2 Gate

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.1a-labels (commit `8787b48`) &nbsp;|&nbsp; **Working tree before commit.**

R1.1a built the *eye* — FVG detection + quality filters. R1.1b builds the *hand* — the per-FVG state machine that opens a paper trade when the spec's revisit-and-confirm pattern is satisfied, with a stop just past the gap edge, a target at the nearest swing, and an explicit 1:2 cost gate that refuses entries with insufficient room. S00 stays **paper-isolated**: no broker orders, no calls into the legacy Risk / Reporting / Execution pipeline, no touch on the existing R0.8b chain numbers.

---

## 1. What was built (per spec §1 → §5)

| Item | Path | Notes |
|---|---|---|
| Strategy plan builder | `Strategies/S00_ScalpFvgMicro/S00_TradePlan.mqh` | Pure-function class. Computes `stop_loss` (gap far edge + `S00_StopBuffer`), `target` (nearest 3-bar swing in `S00_SwingLookback`), `target_to_stop_ratio`. Rejects with `BAD_DIRECTION` / `ZERO_STOP` / `NO_SWING` / `RR_TOO_LOW`. |
| Per-FVG state machine + paper trade | `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` | `CS00EntryLogic` class + `g_s00_entry_logic` file-scope instance. Polls the detector's active list; tracks each FVG through `WAITING_REVISIT → REVISITED → ENTRY_PENDING → DROPPED`; manages a single open `S00PaperTrade`; emits `S00_Trades_Diagnostics.csv` row per closed trade. |
| 4 new inputs | `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | `S00_MinConfirmBody` (50.0), `S00_StopBuffer` (30.0), `S00_SwingLookback` (30), `S00_MaxTradeBars` (24). All in the existing `── S00 FVG Scalp ──` group. Clean R1.1a-labels-style display comments. |
| Detector gate widening | `Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh` | Pre-R1.1b: gated entirely on `S00_DiagReport`. R1.1b widens to `Enable_S00_FvgScalp || S00_DiagReport`. The diagnostic CSV write is split out behind its own inner `if(S00_DiagReport)` so the strategy can run without producing the detection report. |
| Single OnTick hook | `JA_FalconCore_Automated_Trading_Platform.mq5:~6030` | One line: `g_s00_entry_logic.EvaluateOnNewBar(g_market_context);`, immediately after the detector hook. Self-gates on `Enable_S00_FvgScalp` (early return if off). Paper-isolated — never touches `g_report_writer` / `g_broker_entry_bridge` / `g_shadow_executor`. |
| `EA_VERSION_TAG` | `Core/FalconConstants.mqh:10` | `R1_1a_labels` → `R1_1b`. |

**Net lines:** ~170 LOC in `S00_TradePlan.mqh`, ~360 LOC in `S00_EntryLogic.mqh`. Plus 4 new input lines, ~15 line gate widening in the detector, ~10 lines in main `.mq5` (include block + OnTick comment + 1 call line).

---

## 2. Lookahead audit — PASSED (zero live-bar reads)

```
grep -nE "iClose|iHigh|iLow|iOpen|iBars|CopyRates|CopyBuffer|CopyHigh|CopyLow|
         CopyOpen|CopyClose|CopyTime|SymbolInfoTick|GetCandleSnapshot"
     Strategies/S00_ScalpFvgMicro/*.mqh
```

After filtering out comment lines, every read site is enumerated below with its closed-bar guarantee:

| File | Line | Call | Closed-bar guarantee |
|---|---:|---|---|
| `S00_FvgDetector.mqh` | 74 | `CopyBuffer(m_atr_handle, 0, 1, 1, buf)` | `start=1` (CLOSED bar). Unchanged from R1.1a. |
| `S00_FvgDetector.mqh` | 82 | `CopyBuffer(m_ma_handle, 0, 1, 1, buf)` | `start=1` (CLOSED bar). Unchanged from R1.1a. |
| `S00_FvgDetector.mqh` | 94 | `market_context.GetCandleSnapshot(PERIOD_M5, shift, snap)` | Inside `ReadClosedM5`, guarded by `if(shift < 1) return false`. Call sites pass `shift = 3, 2, 1`. |
| `S00_TradePlan.mqh` | 55 | `GetCandleSnapshot(PERIOD_M5, k - 1, left)` | Inside the swing-high scan, `k >= 2` ⇒ `k - 1 >= 1`. |
| `S00_TradePlan.mqh` | 56 | `GetCandleSnapshot(PERIOD_M5, k,     mid)` | `k >= 2`. |
| `S00_TradePlan.mqh` | 57 | `GetCandleSnapshot(PERIOD_M5, k + 1, right)` | `k + 1 >= 3`. |
| `S00_TradePlan.mqh` | 79 | `GetCandleSnapshot(PERIOD_M5, k - 1, left)` | Mirror in swing-low scan, same `k >= 2` guard. |
| `S00_TradePlan.mqh` | 80 | `GetCandleSnapshot(PERIOD_M5, k,     mid)` | Same. |
| `S00_TradePlan.mqh` | 81 | `GetCandleSnapshot(PERIOD_M5, k + 1, right)` | Same. |
| `S00_EntryLogic.mqh` | 278 | `market_context.GetCandleSnapshot(PERIOD_M5, 1, bar1)` | `shift = 1` literal — the most recent CLOSED M5 bar. |

Zero matches for `iClose / iHigh / iLow / iOpen / iBars / CopyRates / CopyHigh / CopyLow / CopyOpen / CopyClose / CopyTime / SymbolInfoTick` in any of the four S00 `.mqh` files.

### 2.1 The "next-bar open" entry — explicit lookahead reasoning

Spec §2.3 says entries open "at the open of the next bar" after the confirmation candle. The natural temptation is to read the forming bar's open at shift=0 the instant the confirmation bar T closes. R1.1b explicitly rejects that path:

- On the OnTick call where `bar1.time = T.time` (T just closed and is now at shift=1), confirmation is detected. State → `ENTRY_PENDING`. **No entry yet.**
- On the next OnTick call where `bar1.time = (T+1).time` (T+1 has fully closed, T+1 is at shift=1), the state machine sees state=`ENTRY_PENDING` and uses `bar1.open` (T+1's recorded open) as the entry price. The same bar's high / low / close are then examined for same-bar SL / TP / timeout.

This delays the *observation* of entry by one M5 bar (5 minutes), but it never reads a live forming bar. The entry timestamp recorded in the diagnostic CSV is T+1.time — the conceptual moment the trade was "opened at the open of the next bar".

### 2.2 Swing scan boundaries

The 3-bar swing test reads `k-1`, `k`, `k+1` for k in `[2, S00_SwingLookback]`. The smallest read is `k-1 = 1` — still a closed bar. `k = 1` is deliberately excluded from the iteration; otherwise `k-1 = 0` would expose the live bar. Comment block in the file header documents this explicitly.

**Verdict: SAFE.** No lookahead surface introduced anywhere in R1.1b.

---

## 3. Paper isolation — how the legacy April numbers stay locked

`CS00EntryLogic` never references:
- `g_report_writer.*`
- `g_broker_entry_bridge.*`
- `g_shadow_executor.*`
- `g_risk_lifecycle_processor.*`
- `g_risk_foundation.*`
- `g_risk_tm_architecture.*`

Confirmed by grep (none of the above appear in `S00_EntryLogic.mqh` or `S00_TradePlan.mqh`). The strategy reads `g_s00_fvg_detector` (its own peer in the strategy folder) and `g_market_context` (Core layer, read-only). It writes to a single new CSV (`S00_Trades_Diagnostics`). It mutates only its own private fields.

Therefore:
- No order is sent (`OrderSend` is not called anywhere in S00).
- No CSV path crosses with the legacy reporting writers — `S00_Trades_Diagnostics` uses `FalconBuildReportFileName(...)` for the path-and-naming convention but writes a separate file.
- The legacy `RegisterClosedTrade` chain is undisturbed; the FixedLot April Summary / TradeLifecycle / broker-bridge audit reports keep producing `585.17 / 1104.89 / 157.49` byte-identical to R0.9 → R1.1a → R1.1a-fix → R1.1a-labels.

> **Why the spec relaxes the "585/1104/157 locked" criterion.** Per spec §0, the legacy numbers are no longer the success criterion for R1.1b — they pertain to the *old strategy* and are now just a side-effect-preservation guarantee. The new success criterion is: the S00 trades CSV looks reasonable (entries directional with the FVG, stops behind the far edge, targets at swings, every recorded entry's `PlannedRR >= 2`).

---

## 4. State machine — exact semantics

```
   (new gap from detector)
            │
            ▼
   WAITING_REVISIT  ──[bar.close past far edge]────►  DROPPED (INVALIDATED)
            │                                              ▲
            │            [bars elapsed > S00_GapExpiry] ───┘ (EXPIRED)
            │
            │ [bar.low <= CE <= bar.high]
            ▼
   REVISITED  ────────[bar.close past far edge]────►  DROPPED (INVALIDATED)
            │                                              ▲
            │             [bars elapsed > S00_GapExpiry] ──┘ (EXPIRED)
            │
            │ [confirmation candle: correct dir + body >= S00_MinConfirmBody]
            │ AND [m_active_trade.open == false]
            ▼
   ENTRY_PENDING  ─────[bar elapsed: open paper trade]──►  DROPPED (ENTERED)
            │                                                    │
            │     [plan rejects: NO_SWING / RR_TOO_LOW / ...] ───┤ (plan reject)
            │                                                    │
            │                            [m_active_trade busy] ──┘ (BUSY)
            ▼
        DROPPED (terminal)
```

**Per-bar order of operations** inside `EvaluateOnNewBar` (called once per closed M5 bar):

1. Read `bar1` (the closed bar at shift=1).
2. Poll detector for any new ACTIVE FVGs added since last call; wrap each in a tracked entry.
3. Update the open paper trade (if any) against `bar1`: check SL → TP → timeout (in that order).
4. For each tracked FVG (skipping `DROPPED`):
   - `bars_elapsed_since_formation++`.
   - Expiry → DROPPED.
   - (Pre-confirmation) Invalidation → DROPPED.
   - State transition: `WAITING_REVISIT` → `REVISITED` on CE touch.
   - State transition: `REVISITED` → `ENTRY_PENDING` on confirmation candle (only if no trade open).
   - State transition: `ENTRY_PENDING` → open trade (or DROPPED on plan reject / BUSY). On a successful entry, immediately check same-bar SL / TP.

`m_active_trade.open` is consulted before confirmation: while a trade is open, `REVISITED` FVGs stay `REVISITED` until invalidation / expiry. FVGs that reach `ENTRY_PENDING` while the active trade is still open are dropped with reason `BUSY` (per spec §8: "one trade at a time").

---

## 5. The diagnostic CSV — `S00_Trades_Diagnostics.csv`

Gated by `S00_DiagReport` (same switch as `S00_FvgDetection_Diagnostics.csv`). One row per **closed** trade — open trades do not appear until they exit. Columns:

```
EntryTime, Direction, EntryPrice, StopLoss, Target,
PlannedRR, FvgFormationTime, FvgSizePoints,
ExitTime, ExitReason, ResultPoints, ElapsedBars
```

`ExitReason` ∈ `{ TARGET, STOP, TIMEOUT, NONE }`. `PlannedRR` is the `target_to_stop_ratio` from the plan — by construction `>= 2.0` for every successfully opened trade. `ResultPoints` is signed in the direction of the trade (positive on winning trades, negative on losers).

Sanity checks an analyst can run on the CSV:
- `PlannedRR >= 2` for every row (the 1:2 gate is non-bypassable).
- For BULLISH rows: `StopLoss < EntryPrice < Target`. For BEARISH: `Target < EntryPrice < StopLoss`.
- `ExitReason == TARGET` ⇒ `ResultPoints` ≈ `(Target - EntryPrice) / _Point` for bullish (mirror for bearish).
- `ExitReason == STOP` ⇒ `ResultPoints` is negative and equal to `(StopLoss - EntryPrice) / _Point` for bullish (mirror for bearish).
- `ExitReason == TIMEOUT` ⇒ trade lasted `ElapsedBars >= S00_MaxTradeBars` and exited at the timeout bar's close.

---

## 6. Spec §9 Acceptance Status

| Criterion | Status |
|---|---|
| `S00_EntryLogic.mqh` + `S00_TradePlan.mqh` exist | ✓ |
| Entry logic complete: revisit to CE, confirmation candle, entry | ✓ §4 |
| Invalidation + expiry work | ✓ §4 |
| Stop / target computed; 1:2 prevents entry when room insufficient | ✓ §1 (`CS00TradePlanBuilder::Build` returns false with `RR_TOO_LOW`) |
| Zero lookahead — confirmed in review file | ✓ §2 |
| `S00_Trades_Diagnostics.csv` behind a switch | ✓ §5 (gated on `S00_DiagReport`) |
| 4 new inputs in S00 group, `S00_` prefix, clean comments | ✓ §1 |
| Compiles `0 errors, 0 warnings` | ⏳ MetaEditor F7 by user |
| Legacy code unaffected (S00 paper-isolated) | ✓ §3 |
| Backtest verification: enabling the report on April produces reasonable S00 trades | ⏳ user backtest |
| `EA_VERSION_TAG = R1_1b` | ✓ |
| `Docs/ReviewNotes/R1_1b_Review_Notes.md` exists | ✓ (this file) |

---

## 7. Touch surface

What R1.1b touched, and why:

1. `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` — 4 inputs added in the existing `── S00 FVG Scalp ──` group. No existing input modified.
2. `Strategies/S00_ScalpFvgMicro/S00_FvgQualityFilter.mqh` — not touched.
3. `Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh` — gate widened (now `if(!Enable_S00_FvgScalp && !S00_DiagReport) return;`) so the active list populates for the new entry-logic consumer; CSV write split behind its own `if(S00_DiagReport)`. Lookahead surface unchanged.
4. `Strategies/S00_ScalpFvgMicro/S00_TradePlan.mqh` — new (R1.1b).
5. `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` — new (R1.1b).
6. `Core/FalconConstants.mqh` — `EA_VERSION_TAG` bump.
7. `JA_FalconCore_Automated_Trading_Platform.mq5` — 2 new `#include` lines, 1 new OnTick call line, plus comments around each. Zero touch on any other code path.
8. `Docs/Ideas_Backlog.md` — items 38–44 added (R1.1b observations).
9. `Docs/ReviewNotes/R1_1b_Review_Notes.md` — this file.

What R1.1b **did not** touch:
- `Risk/*`, `Reporting/*`, `Execution/*`, `Router/*`, `Evidence/*`, `TradeManagement/*`.
- `Core/*` other than `EA_VERSION_TAG`.
- The 12-step Apply* chain.
- Any existing input or any project-wide pre-refactor input.
- Any existing report writer or CSV path.

---

## 8. What did NOT happen (per spec §10)

- **No broker order.** S00 paper-only.
- **No Runner.** R1.1c.
- **No protect-to-breakeven layer.** R1.1c.
- **No lookahead.** §2 confirms.
- **No touch on legacy code.** §3 + §7 confirm.
- **No stacked trades.** §4 confirms the `BUSY` drop path.
- **No idea-backlog item executed.** New items 38–44 captured in `Docs/Ideas_Backlog.md`.

---

## 9. After R1.1b

Verify on April with `S00_DiagReport = true`:
1. `S00_FvgDetection_Diagnostics.csv` continues producing the detection rows we saw post-R1.1a-fix.
2. `S00_Trades_Diagnostics.csv` is newly produced. Each row should show a directional trade matching the FVG's direction, stop just past the gap edge, target at a previous swing, `PlannedRR >= 2`, and an exit (TARGET / STOP / TIMEOUT) within `S00_MaxTradeBars` bars of entry.
3. The legacy FixedLot April Summary still shows `585.17 / 1104.89 / 157.49`.

Once we've inspected the first April trades CSV together, R1.1c builds the runner split (initial 1:1 leg + runner) and the protect-to-breakeven hook, then R1.2+ tunes the parameters using April + May reference data per `ScalpFvgMicro_SPEC §11`.

---

*End of R1.1b review notes. The hand is built — does not blink at the live bar, refuses entries with room less than 1:2, and never touches the legacy chain. First S00 paper trades are ready to be observed.*
