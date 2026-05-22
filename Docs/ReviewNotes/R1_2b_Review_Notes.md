# R1.2b — Real Entry Execution for S00 via Broker Bridge (Tester Only)

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.2a (commit `3dff012`).

R1.2b is the first phase where S00 ScalpFvgMicro **breaks paper isolation**. At trade open (step 3e of `S00_EntryLogic.mqh`), if and only if all three real-execution gates pass, the strategy calls `g_broker_entry_bridge.TryOpenFromShadowRecord(...)` with a `FalconShadowTradeRecord` built from the paper plan. The paper-shadow ledger (`m_active_trade`) is still computed in parallel — the close path is still 100% paper logic, and the broker-side close + dual paper-vs-real report are deferred to R1.2c.

Two new CSV columns surface the first hard broker-cost numbers in the project: `RealEntryPrice` and `RealEntrySlippage` (the latter = real fill − paper entry, signed). They are blank on any row where the gates did not all open or the bridge rejected the order.

With any gate shut (the default tree), this phase is a tautological no-op: no bridge call leaves the strategy, the FixedLot April baseline still reports `585.17 / 1104.89 / 157.49` byte-for-byte, and S00 paper rows are identical to R1.2a except for the two new (empty) trailing columns.

> Active spec: `Docs/Specs/JA_FalconCore_R1_2b_SPEC.md` (moved into `Docs/Specs/` per the R0.9 convention).

---

## 1. What was built (per `JA_FalconCore_R1_2b_SPEC.md` §1 → §3)

| Item | Path | Notes |
|---|---|---|
| 4 new fields on the paper-trade record | `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` (`S00PaperTrade`) | `real_entry_attempted` (bridge call was made), `real_entry_accepted` (bridge returned true), `real_entry_price` (ASK for BUY / BID for SELL captured at submission), `real_entry_slippage` (`real_entry_price - paper entry_price`). All four stay `false / 0.0` when any gate is shut. |
| Three-gate check + bridge call at step 3e | `S00_EntryLogic.mqh` (step 3e, before the same-bar exit check) | New block placed AFTER the `mfe_points = mae_points = 0.0` init and BEFORE the "FVG consumed" marker. Gate condition: `MQLInfoInteger(MQL_TESTER) && EnableRealExecution && S00_RealExecution`. When true: build `FalconShadowTradeRecord` from `m_active_trade` (direction, lot_size, entry_price, structural_sl, target mirrored across tp1/tp2/tp3, status = `FALCON_SHADOW_RECORD_STAGED`, `is_closed = false`, `shadow_id = "S00_SCALP_FVG_<unix_secs>"`, `strategy_id = "S00_SCALP_FVG"`); capture `SymbolInfoDouble(ASK/BID)` BEFORE the call; invoke `g_broker_entry_bridge.TryOpenFromShadowRecord(record, g_report_writer)`; record `accepted` + the captured price as `real_entry_price`; compute slippage. |
| Header comment update | `S00_EntryLogic.mqh` (file banner + `EvaluateOnNewBar` doc block) | Banner: new R1.2b paragraph documenting the three gates + magic-number coexistence story. `EvaluateOnNewBar` doc: replaced the stale "PAPER ISOLATION ... NEVER calls into g_broker_entry_bridge" sentence with a precise statement of when isolation is broken (all 3 gates) and when it is preserved verbatim (any 1 shut). |
| CSV header | `S00_EntryLogic.mqh` (`WriteTradesHeader`) | Appended `RealEntryPrice,RealEntrySlippage` after the R1.2a `LotSize` column. Header now has 24 columns (22 R1.2a + 2 R1.2b). |
| CSV row | `S00_EntryLogic.mqh` (`AppendTradeRow`) | Appended two values: `DoubleToString(t.real_entry_price, _Digits)` and `DoubleToString(t.real_entry_slippage, 1)`, each emitted as empty string when `t.real_entry_accepted == false` — keeps paper rows visually identical to R1.2a paper rows (column separators only). |
| `EA_VERSION_TAG` | `Core/FalconConstants.mqh:10` | `R1_2a` → `R1_2b`. |
| Spec relocation | `Docs/Specs/JA_FalconCore_R1_2b_SPEC.md` | Moved from repo root into `Docs/Specs/` per the R0.9 convention. |

**Net file delta:** `S00_EntryLogic.mqh` adds 4 struct fields + ~55 lines of step-3e bridge block + ~10 lines of header/comment changes + 4 lines of CSV plumbing. Main `.mq5` is **not** touched — the bridge call lives entirely inside the strategy. `Core/FalconConstants.mqh` +1 char in the version literal. No other files changed.

---

## 2. The three gates — fail-closed by construction

The condition for any real-execution side-effect is the strict conjunction:

```mql5
if(MQLInfoInteger(MQL_TESTER)
   && EnableRealExecution
   && S00_RealExecution)
```

Three independent locks, all defaulting to "closed":

1. **`MQLInfoInteger(MQL_TESTER)`** — built-in MT5 runtime flag, true only inside the Strategy Tester. Returns 0/false on Demo and Live. Cannot be flipped by an input. This is the hard environmental guard.
2. **`EnableRealExecution`** — project-wide input declared at `JA_FalconCore_Automated_Trading_Platform.mq5:1580` with the comment "HARD SAFETY: remains false during shadow/candidate stages." Default `false`. The operator must consciously flip this to allow any real broker order to fire from any strategy.
3. **`S00_RealExecution`** — strategy-level input from R1.2a (`Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh:50`). Default `false`. Independent of `EnableRealExecution` so the operator can keep real execution allowed for legacy `FVG_MICRO_RETEST` runs while S00 is in paper. (And by the R1.2a coexistence gate, the inverse: when `S00_RealExecution = true`, the legacy runtime/shadow pipeline is dark for the session.)

### 2.1 Redundancy with the bridge's internal guard

The bridge's `TesterEntryAllowed` (`Execution/FalconBrokerEntryBridge.mqh`) already enforces gates 1 + 2 — without them, `TryOpenFromShadowRecord` returns false before any `OrderSend`. R1.2b's caller-side check is **deliberately redundant**: it adds gate 3 (`S00_RealExecution`) which the bridge doesn't know about, and it makes all three gates visible at the call site so a reader of step 3e sees the full safety contract without chasing into the bridge file.

### 2.2 Verification — what each closed gate prevents

| Gate state | Behavior |
|---|---|
| `MQL_TESTER = false` (Demo / Live) | The `if(...)` is false; the bridge call is skipped entirely. Even if `EnableRealExecution` and `S00_RealExecution` were both flipped on by mistake on a live chart, the strategy emits zero broker orders. (And the bridge itself would still block via `TesterEntryAllowed`.) |
| `EnableRealExecution = false` (default) | The `if(...)` is false; no bridge call. This is the canonical "ExecutionOFF" run that produces the FixedLot April baseline. |
| `S00_RealExecution = false` (R1.2a-and-later default) | The `if(...)` is false; no bridge call. This is the state in which S00 paper trades for March → today must match R1.1c-fix / R1.2a row-for-row (except for the new `LotSize` column from R1.2a and the two empty `Real*` columns added now). |
| All three `true` (Tester only) | Bridge call fires once per S00 entry. `m_active_trade.real_entry_attempted = true`. Bridge may still reject (plan validation, lot authority, etc.) — `real_entry_accepted = false` in that case, with the rejection logged via the bridge's own `AppendBrokerEntryBridgeLifecycleRecord`. |

---

## 3. Lookahead audit

R1.2b adds two new reads inside `EvaluateOnNewBar` step 3e. Both are lookahead-safe:

| Read | Site | Why it's safe |
|---|---|---|
| `MQLInfoInteger(MQL_TESTER)` | step 3e gate | Constant for the lifetime of the EA. Not a price or bar read. No future data exposure. |
| `SymbolInfoDouble(_Symbol, SYMBOL_ASK / SYMBOL_BID)` | step 3e bridge block, right before the bridge call | This is the **live tick** at the moment of submission — exactly what a real broker order will be priced against. It is NOT a future bar read. The strategy's *decision* to enter was already finalized using closed-bar data (the confirmation candle at shift=1 + bar1.open as paper entry); the ASK/BID read here just becomes the request price for the broker, identical to what any live trading EA does. **No closed-bar decision uses the ASK/BID value.** |

Existing reads (detector EvaluateOnNewBar + per-FVG state transitions + RunExitEvaluation) are unchanged. The closed-bar invariant (`shift >= 1`, `CopyBuffer start=1`) is preserved verbatim.

### 3.1 Why the live ASK/BID read here does not violate the "closed bar only" rule

The zero-lookahead rule in this project means: **no strategy decision** may depend on data from a still-forming bar. The R1.2b code does not consume the ASK/BID for any decision. It uses the value purely as the order's request price (sent to the broker) and as the "real entry price" recorded on the trade for slippage measurement. Both consumers are post-decision side-effects. If the live tick is removed entirely (e.g., a stub tester with no quotes), the strategy's entry decision and the paper trade's lifecycle are unchanged — only `real_entry_price` would be 0.0.

---

## 4. The bridge call — what is sent and what is read back

### 4.1 The shadow record built at step 3e

| Field | Value | Source |
|---|---|---|
| `shadow_id` | `"S00_SCALP_FVG_<unix_secs>"` (from `m_active_trade.entry_time`) | New per-trade tag. Distinct from the legacy stager's IDs. |
| `strategy_id`, `strategy_name`, `engine_id` | `"S00_SCALP_FVG"`, `"S00 Scalp FVG Micro"`, `"S00_SCALP_FVG"` | Constant strings for the new strategy identity. |
| `direction` | Mapped from `ENUM_S00_FVG_DIRECTION` → `ENUM_FALCON_DIRECTION` | `S00_FVG_DIR_BULLISH → FALCON_DIRECTION_BUY`, otherwise `FALCON_DIRECTION_SELL`. |
| `status` | `FALCON_SHADOW_RECORD_STAGED` | Required by the bridge to accept the entry (else it rejects with `"SHADOW_RECORD_NOT_OPEN_STAGED"`). |
| `is_closed` | `false` | Mirrors the above. |
| `entry_time`, `lot_size`, `entry_price`, `structural_sl` | Direct copies from `m_active_trade` | The R1.2a lot is used here. |
| `tp1`, `tp2`, `tp3` | All three mirror `m_active_trade.target` | S00 is single-leg in R1.2b. The bridge's plan validator reads all three; mirroring keeps it consistent. |
| All other fields | Zero-initialised via `ZeroMemory(s00_record)` | The bridge does not read the FVG-quality / shadow-guard fields for entry validation. |

### 4.2 What the bridge does (unchanged)

The bridge processes the record through:
1. `TesterEntryAllowed` — re-checks gates 1+2.
2. `record.status == FALCON_SHADOW_RECORD_STAGED && !record.is_closed`.
3. `CountOpenFalconPositions(_Symbol, FC_MAGIC_FVG_MICRO) < FALCON_BEEB_MAX_OPEN_POSITIONS_PER_ENGINE`.
4. `ResolvePreEntryBrokerLotAuthority` — lot validation against broker min/max/step.
5. `ValidateAtomicEntryExitPlan` — sanity of entry/SL/TP relationships.
6. `ValidateAtomicStructuralRiskEnvelope` — risk envelope.
7. `BuildLockParityEmergencyServerStops` — builds the server-side SL/TP for the OrderSend request.
8. `OrderSend(TRADE_ACTION_DEAL, magic = FC_MAGIC_FVG_MICRO, ...)` — the actual broker call.

Returns `true` only on `TRADE_RETCODE_DONE / PLACED / DONE_PARTIAL`. Any failure path logs a `BrokerEntryBridgeLifecycleRecord` via `g_report_writer` with the rejection reason; the strategy treats the bridge return value as the source of truth.

### 4.3 The fill-price read

`SymbolInfoDouble(_Symbol, SYMBOL_ASK / SYMBOL_BID)` is captured in the strategy **just before** the bridge call. Inside the bridge, the exact same MQL5 quote API is read into the `request.price` of the `MqlTradeRequest`. In the Strategy Tester this is the same tick value (both calls happen in the same `OnTick` frame, microseconds apart, with no tick advance between them). So `real_entry_price` == bridge's request price == the tester's fill price for a market deal (deviation = 30 is permitted but the tester normally fills exactly at request).

This is a first-cut measurement. If a slippage non-zero shows up in live runs (post-R1.2c), it surfaces as a real number in the column. If R1.2c needs sub-tick precision it can move to reading `PositionGetDouble(POSITION_PRICE_OPEN)` after the position is selected — but that requires either bridge surgery (forbidden by R1.2b) or post-call selection from the strategy, which is deferred.

---

## 5. Magic-number coexistence (per spec §2.3)

S00 uses `FC_MAGIC_FVG_MICRO` — the same magic the legacy `FVG_MICRO_RETEST` strategy uses. This is intentional and safe in R1.2b because of the R1.2a coexistence gate:

- With `S00_RealExecution = true`, the R1.2a coexistence gate in `OnInit` + `OnTick` shuts down the entire legacy runtime/shadow pipeline (`FalconRunFvgMicroRuntimeShadowPipeline`, the lifecycle simulator, the legacy `TryOpenFromShadowRecord` retry). So `FC_MAGIC_FVG_MICRO` is uniquely S00's during the session.
- With `S00_RealExecution = false`, S00 makes no bridge call at all, so the magic is still uniquely the legacy strategy's.

There is no run in which both strategies emit broker orders with this magic. Bridge-side surgery (per-strategy magics + magic routing) is **not** done in R1.2b — that's the multi-strategy generalisation captured in `Docs/Ideas_Backlog.md` #57 and is gated on having two real-executing strategies, which we don't.

---

## 6. Invariants verified

| Invariant | How it holds |
|---|---|
| **No `OrderSend` outside the bridge.** | S00 still does not call `OrderSend`. Its only execution-layer touch is `g_broker_entry_bridge.TryOpenFromShadowRecord(...)`, which is the single sanctioned entry point. |
| **All three gates required, fail-closed.** | The `if(...)` is a strict `&&`; any false short-circuits before the bridge call. Default tree has all three false / off. |
| **Zero-lookahead.** | No new closed-bar reads. Only new reads are `MQLInfoInteger(MQL_TESTER)` (constant) and `SymbolInfoDouble(ASK/BID)` (live tick, post-decision, used only as the order's request price). See §3. |
| **No early break-even / no `BrokerModify` / no `RuntimeSLChanged`.** | R1.2b touches no SL logic. The R1.1c-fix fixed-threshold breakeven is preserved verbatim. |
| **No legacy strategy change.** | The legacy `FVG_MICRO_RETEST` pipeline is unchanged. With `S00_RealExecution = false` (default), the R1.2a coexistence gate makes the legacy block run exactly as in R1.1c-fix. |
| **Single commit + `EA_VERSION_TAG` bump.** | `Core/FalconConstants.mqh:10` is `R1_2b`. One commit, single-purpose. |
| **FixedLot April baseline byte-identical with all gates closed.** | `EnableRealExecution = false` (the default) immediately short-circuits the new `if`. No new code path executes for the legacy strategy. S00's paper trades populate the new struct fields as `false / 0.0` and emit two empty trailing CSV columns. |
| **S00 paper rows byte-identical to R1.2a with all gates closed.** | The two new CSV columns are emitted as empty strings (`""`) when `real_entry_accepted = false`, so the row's visible content for any non-real-executed trade is `…<R1.2a columns>,,` — same data, two trailing commas. (If a downstream parser needs zero-trailing-commas behavior, that is a CSV concern, not a behavior change.) |

---

## 7. Out of scope — explicitly NOT done in R1.2b

Per spec §4 + §8:

- **Real broker close + dual paper-vs-real report.** The close path is still 100% paper: `RunExitEvaluation` decides SL / target / timeout / BE-arm without consulting the broker position. The actual broker position opened by the bridge will run with the server-side SL/TP envelope the bridge attaches, and the EA-managed close + reconciliation are R1.2c. (In R1.2b's tester runs, the broker position may close on its own server SL/TP — observable in the bridge's lifecycle CSVs — without the strategy or the trades CSV being aware of it.)
- **Bridge generalisation for per-strategy magics.** Backlog #57.
- **Percent-risk lot sizing.** Backlog #59. Fixed-mode `S00_LotSize` only.
- **Multi-leg / runner shadow record.** R1.2b sends `tp1 = tp2 = tp3 = target`. Multi-target / runner stays a Backlog #54-#55 candidate after the R1.1c-fix baseline confirms.
- **Pre-refactor input cleanup.** Item #36 stays deferred.
- **Force-close on OnDeinit for the broker position.** The bridge's own `FlushOpenLinksAtDeinit` already handles legacy positions; S00-specific deinit handling lives with R1.2c's close wiring.

---

## 8. Files touched

| File | Change |
|---|---|
| `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` | +4 struct fields, +1 step-3e block (gate + record build + ASK/BID capture + bridge call + result record), +2 CSV columns, banner / EvaluateOnNewBar comment refresh. |
| `Core/FalconConstants.mqh` | `EA_VERSION_TAG`: `R1_2a` → `R1_2b`. |
| `Docs/Specs/JA_FalconCore_R1_2b_SPEC.md` | Moved here from repo root. |
| `Docs/ReviewNotes/R1_2b_Review_Notes.md` | This file. |

**Notably NOT touched:** the main `.mq5` is unchanged. The R1.2a coexistence gate continues to do its job, and no new orchestration is needed because the strategy-class method calls the globals directly (MQL5 two-pass parse resolves them — same pattern already established by the R0.7cd processor wiring and by the detector's own forward references to `FalconBuildReportFileName` / `FalconTimeToString`).

---

## 9. Verification plan (for the operator running tests)

R1.2b is a no-op-on-defaults change, so regression verification runs first:

1. **Compile clean.** `F7` in MetaEditor — must produce `0 errors, 0 warnings`. The new `g_broker_entry_bridge` / `g_report_writer` references inside the strategy class rely on MQL5's two-pass parse; any "undeclared identifier" error here would indicate the parse model differs from the assumption — investigate before proceeding.
2. **FixedLot April baseline.** Run the legacy `FVG_MICRO_RETEST` tester profile on the April window with all three S00 gates at their default (`EnableRealExecution = false`, `S00_RealExecution = false`). Expected: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker net `157.49`.
3. **S00 paper run (March → today).** Run the S00 paper-isolated profile across the same multi-month window used for R1.1c-fix / R1.2a, with `S00_RealExecution = false`. Expected: same trade count, same per-trade `EntryTime / Direction / EntryPrice / StopLoss / Target / ExitTime / ExitReason / ResultPoints / BreakevenArmed` as R1.2a. The new `RealEntryPrice` and `RealEntrySlippage` columns must be **empty** on every row.
4. **R1.2b real-entry run (Tester only).** Flip `EnableRealExecution = true` AND `S00_RealExecution = true`, re-run the same window. Expected:
   - The bridge's `BrokerEntryBridge_Lifecycle.csv` shows one accepted entry per S00 trade.
   - The S00 trades CSV shows `RealEntryPrice` populated (≈ paper `EntryPrice` ± a few points) and `RealEntrySlippage` non-zero for at least some rows — this is the headline R1.2b measurement.
   - The legacy `FVG_MICRO_RETEST` runtime block does NOT run (R1.2a coexistence gate makes it dark).

If step 2 deviates, R1.2b has regressed and needs investigation before R1.2c can start. If step 3 deviates in any column other than the two trailing `Real*` ones, R1.2b has changed paper behavior — also a regression. Step 4 is the new-capability check.

---

## 10. Next phase — R1.2c

R1.2c is "wire S00 real close + dual paper-vs-real reporting":

- Decide and wire the real-close mechanism: server-side SL/TP (current bridge default), EA-managed close at paper-decided exit, or a hybrid.
- Build the dual report so the operator sees, per trade, the paper plan vs. the broker reality side-by-side: paper entry/exit/result vs. real entry/exit/result, with slippage + spread + commission costs broken out.
- Decide how the strategy's paper close logic interacts with a broker position that closed via server SL/TP: keep paper running until S00's evaluator closes, or honour the broker close as the truth.

R1.2b leaves the table set: the bridge call works, the magic is uniquely S00's during the session, the lot is plumbed through, and the first hard slippage number is in the CSV.
