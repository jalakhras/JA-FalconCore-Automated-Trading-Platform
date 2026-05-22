# R1.1a — S00 ScalpFvgMicro: FVG Detection + Three Quality Filters

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.9 (commit `d0c880f`) &nbsp;|&nbsp; **Last updated:** R1.1a-labels.

R1.1a opens R1.x — the strategy work that the R0 refactor cleared the path for. Scope is tightly bounded per spec §0 ("R1.1a builds the eye — the part that *sees* valid gaps; no trades"). Detection + filtering + a diagnostic CSV. The strategy is not activated; the existing FixedLot April numbers stay locked.

> **R1.1a-fix update:** April diagnostics on R1.1a surfaced two issues — anomalous outlier gaps that passed the floor-only filters, and unwieldy input naming. R1.1a-fix addresses both inside this same phase before R1.1b lands the entry logic. See §11 for the fix details.
>
> **R1.1a-labels update:** R1.1a-fix produced clean variable names but the trailing display comments on the seven S00 inputs were still cluttered with phase tags and dev-notes (`R1.1a-fix: declared now; wired to the chain in R1.1b`, etc.) — and MT5 shows that comment text, not the variable name, in the parameter dialog. R1.1a-labels rewrites those seven comments only. Comment-only, no variable / value / logic / group changes. See §12.

---

## 1. What was built (per spec §1 + §2 + §3 + §4 + §5)

| Item | Path | Notes |
|---|---|---|
| Strategy inputs | `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | 6 inputs in a new group "07 - S00 Scalp FVG Micro / اكتشاف الفجوات (R1.1a)". Entry/runner/protect inputs deferred to R1.1b/c. |
| Three-candle FVG detector | `Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh` | `CS00FvgDetector` class + `S00FvgRecord` struct + `g_s00_fvg_detector` file-scope instance. |
| Three quality filters | `Strategies/S00_ScalpFvgMicro/S00_FvgQualityFilter.mqh` | `CS00FvgQualityFilter` — pure-function evaluator, no state, no file I/O. SIZE / ATR / TREND filters with explicit reject reasons. |
| Diagnostic CSV | `S00_FvgDetection_Diagnostics.csv` (written by the detector when on) | Gated by `EnableFvgDetectionDiagnostics` (default `false`, R0.6b pattern). 11-column header: `FormationTime, Direction, GapHigh, GapLow, CE, GapSizePoints, AtrM5, TrendMaM5, SpotPriceClose, Status, RejectReason`. |
| Single OnTick hook | `JA_FalconCore_Automated_Trading_Platform.mq5:~6017` | One line: `g_s00_fvg_detector.EvaluateOnNewBar(g_market_context);`. Self-gates internally on `EnableFvgDetectionDiagnostics` — default tree is a pure no-op. |
| `#include` chain | Main `.mq5` after Router includes (~L80) | Three lines, in dependency order: Inputs → Filter → Detector. |
| `EA_VERSION_TAG` | `Core/FalconConstants.mqh:10` | `R0_9` → `R1_1a`. |
| SPEC relocation | `Docs/Specs/JA_FalconCore_R1_1a_SPEC.md` + `Strategies/S00_ScalpFvgMicro/ScalpFvgMicro_SPEC.md` | R1.1a SPEC moved into `Docs/Specs/`; the strategy SPEC moved into the strategy folder where R1.1a's code can sit next to it. The shipped R0.9 SPEC was deleted per the R0.5b convention. |

**Net lines of new code:** ~310 LOC across the three `.mqh` files, plus 11 lines added to main `.mq5` (3-line include block + 1-line OnTick hook + 7 lines of explanatory comment).

---

## 2. Lookahead audit — PASSED

R1.1a's spec §6 reads: *"لا lookahead — كل القراءات على شموع مغلقة. C3 شمعة مغلقة."* This is the load-bearing safety property of the file, so it is audited end-to-end below.

### 2.1 Every read site in `Strategies/S00_ScalpFvgMicro/*.mqh`

```
grep -nE "iClose|iHigh|iLow|iOpen|iBars|CopyRates|CopyBuffer|CopyHigh|CopyLow|CopyOpen|CopyClose|CopyTime|SymbolInfoTick|GetCandleSnapshot"
   Strategies/S00_ScalpFvgMicro/*.mqh
```

Yields (excluding comment / header lines):

| File | Line | Call | Closed-bar guarantee |
|---|---:|---|---|
| `S00_FvgDetector.mqh` | 74 | `CopyBuffer(m_atr_handle, 0, 1, 1, buf)` | `start=1` → reads the CLOSED bar of the ATR(M5) handle. `start=0` (live bar) is never used. |
| `S00_FvgDetector.mqh` | 82 | `CopyBuffer(m_ma_handle, 0, 1, 1, buf)` | same — `start=1` only. |
| `S00_FvgDetector.mqh` | 94 | `market_context.GetCandleSnapshot(PERIOD_M5, shift, snap)` | called only from `ReadClosedM5`, which **enforces `shift >= 1`** with an early-return at L91. The three call sites at L171 / L172 / L173 pass `shift = 3, 2, 1` — the most aggressive read is `shift=1` (the most recent CLOSED M5 bar, never the live forming bar). |

Zero matches for `iClose / iHigh / iLow / iOpen / iBars / CopyRates / CopyHigh / CopyLow / CopyOpen / CopyClose / CopyTime / SymbolInfoTick` in the new files. The detector does not touch the live forming bar through any path.

### 2.2 Static guard against accidental widening

`ReadClosedM5` is the only candle reader in the detector. Its body:

```cpp
bool ReadClosedM5(const int shift,
                  CFalconMarketContext &market_context,
                  FalconCandleSnapshot &snap)
{
   if(shift < 1)
      return false;                  // ← ZERO-LOOKAHEAD assertion
   return market_context.GetCandleSnapshot(PERIOD_M5, shift, snap);
}
```

A future maintainer cannot accidentally widen the surface to the live bar without explicitly weakening this assertion. The CopyBuffer reads (lines 74 / 82) follow the same pattern by passing `start=1` literally.

### 2.3 C3 is closed

The spec calls out C3 specifically because past projects confused "most recent" with "current bar". In R1.1a's vocabulary:

- C3 = `shift = 1` = most recent CLOSED M5 bar.
- C2 = `shift = 2`.
- C1 = `shift = 3` (oldest of the three).

`FalconCandleSnapshot.is_closed` is set to `(shift > 0)` in `CFalconMarketContext::GetCandleSnapshot` (`Core/FalconMarketContext.mqh:131`). All three of our reads (`shift = 3, 2, 1`) satisfy `> 0`, so `is_closed == true` for each.

### 2.4 ATR / MA closed-bar reads

ATR(M5, period=AtrPeriod) and SMA(M5, period=TrendMaPeriod, close) are both indicator handles fed by historical bars. MQL5 indicators expose the live bar at buffer index 0 and the most recently closed bar at index 1. We pass `start=1, count=1` to `CopyBuffer` — strictly the closed bar.

### 2.5 Verdict

**SAFE. No lookahead surface introduced by R1.1a.** The detector reads four closed-bar values per detection attempt (three M5 candles + 2 indicator readings) and writes to a CSV. Nothing in this pipeline touches the live bar.

---

## 3. Behavior-preservation — default tree is a no-op

The R1.1a hook in OnTick (`JA_FalconCore_Automated_Trading_Platform.mq5:~6017`) is one line:

```cpp
g_s00_fvg_detector.EvaluateOnNewBar(g_market_context);
```

The method's first action is `if(!EnableFvgDetectionDiagnostics) return;` (`S00_FvgDetector.mqh:158`). The default input value is `false` (`S00_ScalpFvgMicroInputs.mqh:21`). So in the default tree:

- Zero candle reads.
- Zero indicator handle allocations (`EnsureIndicatorHandles` not reached).
- Zero file I/O.
- Zero array allocations.
- Zero observable side effects.

This is the same R0.6b pattern adopted by the diagnostic-report group switches — the diagnostic is a strictly additive surface gated at the outermost call.

**Expected FixedLot April backtest:** `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker net `157.49`. Identical to R0.9. R1.1a has zero touch points inside the Risk chain or the Reporting writers.

---

## 4. How to verify the detector (per spec §9 acceptance)

1. Set `EnableFvgDetectionDiagnostics = true` in inputs.
2. Run FixedLot April backtest.
3. Find `JA_FalconCore_S00_FvgDetection_Diagnostics_R1_1a_*.csv` in the reports folder (path matches the rest of the diagnostic CSVs — `FalconReportStorageMode()` decides Common vs. local Files).
4. Expected: one row per 3-candle FVG window detected on a CLOSED M5 bar during April, with the status column showing `ACCEPTED` for gaps that passed all three filters and `REJECTED` for the rest. Rejected rows carry the reason: `SIZE`, `ATR`, or `TREND`.
5. Sanity checks an analyst should run on the resulting CSV:
   - `Direction` should be `BULLISH` or `BEARISH` only (never `NONE` — the detector only writes rows when a pattern is found).
   - `GapHigh > GapLow` always.
   - `CE == (GapHigh + GapLow) / 2` (within 1-digit rounding).
   - `GapSizePoints` matches the difference in points.
   - For accepted rows: `GapSizePoints >= MinGapPoints` AND `GapSizePoints >= AtrM5 / _Point × GapAtrMultiplier` AND (bullish ⇒ `SpotPriceClose > TrendMaM5`; bearish ⇒ `SpotPriceClose < TrendMaM5`).
   - For rejected rows: the corresponding filter should be the binding constraint per the reason column.

The default-input values from R1.1a (`MinGapPoints = 30.0`, `GapAtrMultiplier = 0.5`, `TrendMaPeriod = 50`) are explicitly placeholders per spec §4 ("القيم المبدئية تقديرية للبدء — تُضبَط بالاختبار"). R1.1b/c will tune them against the April + May reference data once entries are wired.

---

## 5. The three filters — exact semantics

Per `ScalpFvgMicro_SPEC.md §3` and `JA_FalconCore_R1_1a_SPEC §3`. The filter is short-circuit (first failure wins):

| # | Filter | Condition for ACCEPT | Reject reason |
|---:|---|---|---|
| 3.1 | SIZE | `gap_size_points >= MinGapPoints` | `"SIZE"` |
| 3.2 | ATR | (`atr_m5 > 0` AND `_Point > 0`) ⇒ `gap_size_points >= (atr_m5 / _Point) × GapAtrMultiplier`. **Skipped** if ATR not ready (handle warm-up). | `"ATR"` |
| 3.3 | TREND | (`trend_ma_m5 > 0` AND `spot_price > 0`) ⇒ direction matches: bullish ⇒ `spot_price > trend_ma_m5`; bearish ⇒ `spot_price < trend_ma_m5`. **Skipped** if MA not ready. | `"TREND"` |

**The "skipped if not ready" behavior** for filters 3.2 / 3.3 is a deliberate warm-up safety: during the first `max(AtrPeriod, TrendMaPeriod)` closed bars after Init, the SIZE filter remains the gatekeeper rather than silently passing every gap against an unknown ATR / MA. Documented in `Docs/Ideas_Backlog.md` #31 for review when the entry logic lands.

`spot_price` in filter 3.3 is `c3.close` — the close of the most recent CLOSED M5 bar (`shift = 1`). The detector passes it to `Evaluate` directly; no separate live-quote read.

---

## 6. State + lifecycle

`CS00FvgDetector` holds:

- `m_atr_handle`, `m_ma_handle` — lazy-allocated MQL5 indicator handles, both for M5.
- `m_last_evaluated_bar_time` — dedupe key: ensures `EvaluateOnNewBar` runs at most once per closed C3 bar.
- `m_diag_header_written`, `m_diag_file_name` — diagnostic CSV state.
- `m_active_fvgs[]`, `m_active_fvg_count` — the FVG list. R1.1a only appends; R1.1b will sweep expired/invalidated entries (per `GapExpiryBars` + close-through invalidation per `ScalpFvgMicro_SPEC §4.1 / §4.2`).

No `Deinit()` method is provided in R1.1a — MQL5 cleans up indicator handles on EA unload, and the active-FVG array goes out of scope with the global. `Docs/Ideas_Backlog.md` #28 + #29 capture the proper-hygiene follow-ups for R1.1b.

---

## 7. Touch surface summary

What R1.1a touched, and why each touch is in scope:

1. `Core/FalconConstants.mqh` — `EA_VERSION_TAG` bump (per spec §7, fixed clause).
2. `JA_FalconCore_Automated_Trading_Platform.mq5` — 3-line `#include` block (the only way to wire the new files into the translation unit) + 1-line OnTick hook (the only way to make `EnableFvgDetectionDiagnostics=true` produce the CSV that §9 acceptance requires). All other code is untouched.
3. `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` — new.
4. `Strategies/S00_ScalpFvgMicro/S00_FvgQualityFilter.mqh` — new.
5. `Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh` — new.
6. `Strategies/S00_ScalpFvgMicro/ScalpFvgMicro_SPEC.md` — moved here from the repo root (the user's prompt expects the SPEC at this path).
7. `Docs/Specs/JA_FalconCore_R1_1a_SPEC.md` — moved here from the repo root, per the R0.9 SPEC-location convention.
8. `Docs/Specs/JA_FalconCore_R0_9_SPEC.md` — deleted (R0.9 shipped at commit `d0c880f`, per R0.5b's "delete completed-phase SPEC" convention).
9. `Docs/Ideas_Backlog.md` — items 27–32 added.
10. `Docs/ReviewNotes/R1_1a_Review_Notes.md` — this file.

What R1.1a **did not** touch:
- `Risk/*`, `Reporting/*`, `Execution/*`, `Router/*`, `Evidence/*`, `TradeManagement/*`.
- `Core/*` other than the `EA_VERSION_TAG` literal.
- The existing FVG-Micro inline classes in main `.mq5` (the v0.18.4 shadow pipeline).
- Any input default value outside R1.1a's new 6 inputs.

---

## 8. Spec §9 Acceptance Status

| Criterion | Status |
|---|---|
| `S00_FvgDetector.mqh`, `S00_FvgQualityFilter.mqh`, `S00_ScalpFvgMicroInputs.mqh` exist in `Strategies/S00_ScalpFvgMicro/` | ✓ |
| FVG detection on CLOSED bars only — confirmed in review file | ✓ §2 above |
| Three filters work, each rejection carries reason | ✓ §5 |
| `S00_FvgDetection_Diagnostics.csv` behind default-off switch | ✓ |
| Compiles `0 errors, 0 warnings` | ⏳ MetaEditor F7 by user |
| FixedLot April stays `585.17 / 1104.89 / 157.49` (strategy not activated) | ⏳ backtest by user (zero-touch design — §3 explains why this must hold) |
| Detection verification: April with `EnableFvgDetectionDiagnostics=true` produces a sane CSV | ⏳ user opt-in run |
| `EA_VERSION_TAG = R1_1a` | ✓ |
| `Docs/ReviewNotes/R1_1a_Review_Notes.md` exists | ✓ (this file) |

---

## 9. What did NOT happen

- **No entry logic.** R1.1a is detection + classification only. `ScalpFvgMicro_SPEC §4-§8` (entry, runner, protect, risk management) lands in R1.1b/c.
- **No trades.** The strategy is not activated. Default tree is a pure no-op.
- **No touch on existing Risk / Reporting / Execution code.** Strict additive build.
- **No new global mutable state outside `Strategies/S00_ScalpFvgMicro/`.** The detector instance is declared in the new header; main `.mq5` got 4 added lines total (3 includes + 1 OnTick call) plus comments.
- **No backlog item executed beyond what R1.1a's scope required.** New items 27-32 captured in `Ideas_Backlog.md` as R1.1b/c hooks.

---

## 10. After R1.1a

Next: **R1.1b** — entry logic + invalidation + stop/target (per `ScalpFvgMicro_SPEC §4, §5`). The R1.1a active-FVG list becomes the consumer surface: R1.1b reads `g_s00_fvg_detector.GetActiveFvg(i)`, waits for price to revisit each gap's CE with a confirmation candle, and produces a `FalconTradePlan` that the existing Risk/Execution chain can stage.

R1.1c will add the runner split + protection logic.

R1.2+ is parameter tuning on the April + May reference data per `ScalpFvgMicro_SPEC §11`.

---

## 11. R1.1a-fix (calibration + naming hygiene)

The R1.1a `S00_DiagReport=true` April run produced a sane diagnostic CSV but exposed two issues that needed handling **before** R1.1b lands the entry logic — fixing them in R1.1b would mix calibration changes with new behavior, making bug bisection harder.

### 11.1 Issue A — anomalous outlier gaps passed the floor-only filters

Some rows in `S00_FvgDetection_Diagnostics.csv` showed `GapSizePoints` up to ~31,437 — holiday session gaps and data-feed artifacts, not tradable patterns. The R1.1a filters were all floor-only (SIZE has a min, ATR has a min, TREND is direction-only). A gap of 31k points trivially passes a `SIZE >= 30` floor and an `ATR x 0.5` thrust ratio.

**Fix:** added a fourth filter — **MAXSIZE** — with input `S00_MaxGap` defaulted to `6000.0`. The threshold sits above the 90th percentile of April-accepted gaps (~92% of legitimate detections survive) and below the outlier tail. Reject reason: `"MAXSIZE"`. New filter chain order: **SIZE → MAXSIZE → ATR → TREND** (short-circuit, first failure wins).

Implementation: 8 new lines in `S00_FvgQualityFilter.mqh` between the SIZE and ATR blocks. Zero new state. Zero new code surfaces on the detector side — the filter signature `Evaluate(gap_size_points, …, &reject_reason)` did not change; only the implementation added one more branch.

### 11.2 Issue B — input naming + ungrouped

R1.1a used spec-mandated unprefixed names (`MinGapPoints`, `AtrPeriod`, etc.) that read fine in a header file but clutter the MT5 parameter dialog and don't scale: when S01 lands, its `MinGapPoints` would collide with S00's. Plus `AtrPeriod` is a settled standard (`14`) — not something a user should be invited to "tune."

**Fix:** three changes:

1. **`AtrPeriod` input → `#define S00_ATR_PERIOD 14`** (in `S00_ScalpFvgMicroInputs.mqh`). The detector's `iATR(_Symbol, PERIOD_M5, S00_ATR_PERIOD)` call substitutes the constant at compile time.
2. **Six S00 inputs renamed to short S00_-prefixed names:**
   | Old (R1.1a) | New (R1.1a-fix) |
   |---|---|
   | `MinGapPoints` | `S00_MinGap` |
   | *(new)* | `S00_MaxGap` |
   | `GapAtrMultiplier` | `S00_GapAtrMult` |
   | `TrendMaPeriod` | `S00_TrendMA` |
   | `GapExpiryBars` | `S00_GapExpiry` |
   | `EnableFvgDetectionDiagnostics` | `S00_DiagReport` |
3. **Inputs reorganized into two groups:**
   - `═══ STRATEGIES ═══` — the new top-level group, currently holding the single switch `Enable_S00_FvgScalp = true` (declared now per spec §3.2; not wired to logic until R1.1b). Future strategies (S01, S02, …) will add their on/off switches here.
   - `── S00 FVG Scalp ──` — the per-strategy parameter sub-group, containing the six S00 inputs. The Unicode separator characters emulate a hierarchy that MQL5 doesn't natively support.

### 11.3 Project-wide pre-refactor inputs — NOT touched

The R1.1a-fix spec is explicit that the rename applies only to the six new S00 inputs (and the new `Enable_S00_FvgScalp` switch). Pre-refactor inputs (`EnableMainReport`, `ReportProfile`, the R0.6b group switches, `EnableVirtualTrailingReport`, etc.) are untouched. Cleaning their names is a separate deferred sweep — flagged in the R0.6b backlog and re-flagged in `Docs/Ideas_Backlog.md`'s permanent "Input design rules" section.

### 11.4 Re-audited: zero lookahead, zero behavior change

- The detector's only candle / indicator reads after R1.1a-fix are still the same three sites: `CopyBuffer(handle, 0, 1, 1)` × 2 and `GetCandleSnapshot(PERIOD_M5, shift, ...)` × 3 (with `shift ∈ {3, 2, 1}`). `ReadClosedM5`'s `if(shift < 1) return false` guard is intact.
- The filter signature is unchanged; the new MAXSIZE branch reads only its parameter `gap_size_points` against the input `S00_MaxGap`.
- The OnTick hook still self-gates on `S00_DiagReport` (the renamed flag). Default `false` ⇒ default tree is still a pure no-op.
- `Enable_S00_FvgScalp` is declared with default `true`, but R1.1a-fix code paths do NOT read it yet. So enabling/disabling it has no observable effect today; behavior is unchanged either way. R1.1b will wire it.

**Expected FixedLot April backtest:** `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker net `157.49` — locked. R1.1a-fix did not touch Risk/Reporting/Execution.

### 11.5 Touch surface (R1.1a-fix only)

| File | Change |
|---|---|
| `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | Rewritten: removed `AtrPeriod` input, added `#define S00_ATR_PERIOD 14`, regrouped inputs under `STRATEGIES` + `── S00 FVG Scalp ──`, added `S00_MaxGap`, renamed the six S00 inputs. |
| `Strategies/S00_ScalpFvgMicro/S00_FvgQualityFilter.mqh` | Renamed input refs (`MinGapPoints → S00_MinGap`, `GapAtrMultiplier → S00_GapAtrMult`); added MAXSIZE branch between SIZE and ATR; updated header comment to document the new filter chain order. |
| `Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh` | Renamed input/macro refs (`AtrPeriod → S00_ATR_PERIOD`, `TrendMaPeriod → S00_TrendMA`, `EnableFvgDetectionDiagnostics → S00_DiagReport`); refreshed two comment lines for naming consistency. |
| `Core/FalconConstants.mqh` | `EA_VERSION_TAG`: `R1_1a` → `R1_1a_fix`. |
| `JA_FalconCore_Automated_Trading_Platform.mq5` | Single comment update in the OnTick hook (referenced renamed `S00_DiagReport`). Zero logic change. |
| `Docs/Ideas_Backlog.md` | Item 32 struck-through and tagged "Closed in R1.1a-fix"; new "Input design rules" section recording the three permanent principles (input needs a reason; group hierarchy; short prefixed names) + items 33-35 for R1.1a-fix observations. |
| `Docs/ReviewNotes/R1_1a_Review_Notes.md` | This §11 added; header note + ToC updated. |

---

## 12. R1.1a-labels (display-comment cleanup for the seven S00 inputs)

### 12.1 Why this pass exists

The R1.1a-fix commit produced clean **variable names** but the trailing display comments (the text after `// …` on each `input` line) still carried R1.1a-fix-internal phrasing:

```
input bool Enable_S00_FvgScalp = true;   // R1.1a-fix: declared now; wired to the chain in R1.1b. R1.1a-fix is still detection-only.
input bool S00_DiagReport      = false;  // R0.6b-style gate: off by default. When true, R1.1a writes S00_FvgDetection_Diagnostics.csv.
```

These are **the strings MetaTrader 5 displays in the parameter dialog** — the variable name itself is invisible there. So `Enable_S00_FvgScalp` shows up to the operator as the literal sentence above, which mixes phase tags, internal dev notes (`declared now`, `wired in …`), and incomplete thoughts. An operator opening the inputs dialog cannot tell what `S00_DiagReport` actually controls without reading the source.

### 12.2 Scope — comment text only

R1.1a-labels rewrites the seven trailing comments to clean functional descriptions per the spec §1 table:

| Variable (unchanged) | Old display comment | New display comment |
|---|---|---|
| `Enable_S00_FvgScalp` | `R1.1a-fix: declared now; wired to the chain in R1.1b. R1.1a-fix is still detection-only.` | `Enable the S00 FVG Scalp strategy` |
| `S00_MinGap` | `SIZE filter floor (points).` | `Minimum FVG size to trade (points)` |
| `S00_MaxGap` | `R1.1a-fix: MAXSIZE filter ceiling (points). Rejects holiday/data outliers; April keeps ~92% of accepted gaps, sits above the 90th pct.` | `Maximum FVG size - rejects abnormal gaps (points)` |
| `S00_GapAtrMult` | `ATR filter: gap >= ATR(M5) x multiplier.` | `FVG strength filter: gap >= ATR x this value` |
| `S00_TrendMA` | `TREND filter: SMA(M5, close) period.` | `Trend filter SMA period (M5)` |
| `S00_GapExpiry` | `Reserved for R1.1b (gap expiry, bars).` | `Bars before an untouched FVG expires` |
| `S00_DiagReport` | `R0.6b-style gate: off by default. When true, R1.1a writes S00_FvgDetection_Diagnostics.csv.` | `S00 FVG detection diagnostic report (on/off)` |

### 12.3 What did NOT change

- **No variable name** modified. `Enable_S00_FvgScalp`, `S00_MinGap`, `S00_MaxGap`, `S00_GapAtrMult`, `S00_TrendMA`, `S00_GapExpiry`, `S00_DiagReport` — all identical to R1.1a-fix.
- **No default value** modified.
- **No input group** moved or renamed. `═══ STRATEGIES ═══` still sits above `── S00 FVG Scalp ──`, exactly the order R1.1a-fix established.
- **No `#define`** changed.
- **No project-wide pre-refactor input** touched. The 46+ legacy inputs (`EnableMainReport`, `ReportProfile`, R0.6b group switches, …) keep their existing comments — cleaning them is a separate dedicated R1.x phase per `Docs/Ideas_Backlog.md` #36.
- **No code in `S00_FvgDetector.mqh` or `S00_FvgQualityFilter.mqh`** touched. They reference the variables by name, and names are unchanged, so they are spared this pass entirely.
- **Lookahead surface** — re-checked, identical to R1.1a-fix. No new read sites. Same `start=1` CopyBuffer reads and `shift >= 1` candle reads.

### 12.4 Behavior expectation

R1.1a-labels is a **pure cosmetic display change** — the MQL5 compiler treats trailing `// …` comments as discardable text. The compiled `.ex5` differs from R1.1a-fix only in the embedded `EA_VERSION_TAG` literal (`R1_1a_fix` → `R1_1a_labels`, which only affects report filenames).

**FixedLot April backtest:** `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker net `157.49` — locked, unchanged from R0.8b → R0.9 → R1.1a → R1.1a-fix → R1.1a-labels.

### 12.5 Touch surface (R1.1a-labels only)

| File | Change |
|---|---|
| `Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh` | Seven trailing-comment edits per §12.2 table. Zero structural change. |
| `Core/FalconConstants.mqh` | `EA_VERSION_TAG`: `R1_1a_fix` → `R1_1a_labels`. |
| `Docs/Ideas_Backlog.md` | "Input design rules" extended with rule 4 (display comments are part of the operator-visible name); new items 36-37 (dedicated R1.x phase for pre-refactor input cleanup; optional CI grep gate for phase tags in comments). |
| `Docs/ReviewNotes/R1_1a_Review_Notes.md` | This §12 added; header note updated. |
| `Docs/Specs/JA_FalconCore_R1_1a_labels_SPEC.md` | Added (moved from root per convention). |

---

*End of R1.1a review notes (now including R1.1a-fix calibration + naming pass, plus R1.1a-labels display-comment cleanup). Eye built — does not blink at the live bar; rejects outliers above 6000 points; seven inputs in two groups with clean operator-facing labels; settled-standard ATR period demoted to `#define`. Numbers stay locked at the R0.8b baseline. R1.1b is next.*
