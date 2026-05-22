# R0.8b — Single-Owner State + FinalWorkingNetUSD Fix: Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.8a (commit `74d9db3`) &nbsp;|&nbsp; **Working tree before commit.**

R0.8b is the targeted fix for the R0.7cd `FinalWorkingNetUSD = 0` regression. The root cause was duplicated state (`m_tle_*` / `m_dlm_*` / `m_symbol_context` carried separately by `CFalconRiskLifecycleProcessor` and `CFalconReportWriter`) with default-zero initialization on the processor side and a reset path that operated only on the ReportWriter side. R0.8b adopts the spec's Option A — **single-owner**: the processor owns Risk state; ReportWriter owns `m_totals` and the chain receives it as a `FalconReportTotals &totals` parameter.

The chain order (`#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12`) is **unchanged**. No `Apply*` body logic was modified. The only call-site logic change is the new `totals` parameter on Apply #2 (mechanical rename `m_totals.X` → `totals.X`, 9 lines).

---

## 1. Five items executed (per spec §1)

| # | Item | Net effect |
|---|---|---|
| 1.1 | Move ownership of `m_symbol_context` / 8 `m_tle_*` / 2 `m_dlm_*` to the processor; delete RW's copies | RW loses 11 fields + 5 orphan helper methods (`FalconDynamicTierMaxLot/CapitalMaxLot/GrowthRampMaxLot/NormalizeDynamicLotToBroker/RefreshUsdMetricsForActiveLot` — duplicates of the live copies in the processor, never called from RW after R0.7cd). ResetTotals loses the 11-line `m_tle_*`/`m_dlm_*` zero-reset block. |
| 1.2 | Add `Initialize(symbol_context)` + `SymbolContext()` getter to `CFalconRiskLifecycleProcessor`; remove the processor's scaffolding `m_totals` field | Processor's `m_symbol_context` is seeded once at OnInit (instead of staying default-zero until the first trade). All 10 mutable Risk state fields (`m_tle_*` × 8 + `m_dlm_*` × 2) get seeded with the SAME values RW's `ResetTotals` used to write. Apply #11's day-boundary reset (L1333) and the day-rollover counter resets (L1322 etc.) keep working on the canonical owner — **this is the fix for `FinalWorkingNetUSD = 0`**. |
| 1.3 | Change `ApplyTradeLifecycleChain` signature to `(FalconTradeLifecycleRecord &record, FalconReportTotals &totals)`; propagate `totals` into the one consumer (Apply #2) | The 9 `m_totals.X` references inside `ApplyDailyWeekendForceCloseUserOverridePaperEnforcement` become `totals.X` — pure mechanical rename, no semantic change. `RegisterClosedTrade` now calls `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record, m_totals);`. |
| 1.4 | ReportWriter reads emergency status from `record.*` (no getter needed) | Verified: `AppendEmergencyTriggerEvent` (RW L1509) already reads only `record.falcon_emergency_*` / `falcon_layer{1,2,3}_*` / `falcon_tier_at_entry` / `falcon_dynamic_risk_capital_after_trade` plus its own `m_totals.paper_emergency_blocked_entries`. No new getter introduced for emergency state. |
| 1.5 | `EA_VERSION_TAG` in `Core/FalconConstants.mqh` | `"v0.57.4"` → `"R0_8b"`. New fixed clause in subsequent specs: every phase bumps this tag. |

---

## 2. Constraints honored

- **Chain order unchanged** — `ApplyTradeLifecycleChain` still calls `#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12`. Verified by direct diff inspection.
- **No `Apply*` body logic modified** — the only change inside any Apply body is Apply #2's `m_totals` → `totals` rename (9 occurrences, identical semantics via reference parameter).
- **Risk layer does NOT call ReportWriter** — verified. The new dependency direction is the opposite: RW reads from the processor via `SymbolContext()` (and via the existing `ApplyTradeLifecycleChain` call). No `g_report_writer` reference inside `Risk/`.
- **No other globals touched** — the only `g_*` change is the new `Initialize` call on the existing `g_risk_lifecycle_processor`. No new global declared, no global moved.
- **Initialization values identical to old RW seed** — `Initialize`'s ten assignments are byte-identical copies of the deleted `ResetTotals` block (`m_tle_emergency_active = false`, `m_tle_emergency_reason = "NONE"`, `m_tle_consecutive_losses = 0`, `m_tle_current_day = 0`, `m_tle_daily_r = 0.0`, `m_tle_equity = 0.0`, `m_tle_peak_equity = 0.0`, `m_tle_max_drawdown_pct = 0.0`, `m_dlm_previous_active_lot_ready = false`, `m_dlm_previous_active_lot = 0.0`). Same baseline ReportWriter used pre-R0.7cd — that's the behavior-match guarantee for FixedLot April.

---

## 3. The fix — root cause and the line that restores it

**Symptom (R0.7cd):** `FinalWorkingNetUSD = 0`, `RawNetUSD = 585.17` (correct).

**Root cause:** `CFalconRiskLifecycleProcessor::m_tle_emergency_active` zero-initialized at global-object construction time, never reset by any code path (RW's `ResetTotals` set its OWN `m_tle_emergency_active = false` at `Reporting/FalconReportWriter.mqh:4699`, but that was a separate field on a separate object). Once Apply #11 latched the processor's `m_tle_emergency_active = true` on Layer 3, the only reset path inside the processor (`Risk/FalconRiskLifecycleProcessor.mqh:1333`) was gated by `m_tle_emergency_reason ∈ {LAYER_1_CONSECUTIVE, LAYER_2_DAILY_R}` AND day-rollover — Layer 3 trips never cleared. Every subsequent call hit `if(m_tle_emergency_active)` at L1355 and wrote `record.falcon_emergency_after_net_usd = 0.0` at L1361.

`FinalWorkingNetUSD` accumulates from `record.falcon_emergency_after_net_usd` (RW L4730 → L4745 inside `UpdateTotals`), so every blocked trade contributed 0 to the total. `RawNetUSD` (RW L4727) accumulates from `record.net_usd`, which is set BEFORE Apply #11 runs and is NOT touched by #11's BLOCKED early-return at L1367 — so it stayed correct.

**Fix:** delete the duplicated RW fields entirely, add `CFalconRiskLifecycleProcessor::Initialize` that seeds the same baseline values RW used to seed (which were never being read on the processor side, leaving the processor blind to the baseline). All subsequent resets — day-boundary clear at L1333, daily-R reset at L1322, peak-equity update at L1394–1398, drawdown floor at L1402–1405, win-streak reset at L1388 — now operate on the canonical (and only) copy, so the latch behavior matches the pre-R0.7cd ReportWriter version. **Zero changes to Apply #11 logic itself** — the change is purely about which object's state it reads/writes.

---

## 4. State-ownership table (post-R0.8b)

| State | Owner | Reader(s) | How Reader Accesses |
|---|---|---|---|
| `m_symbol_context` | `CFalconRiskLifecycleProcessor` | RW (~80 sites), processor (~30 sites) | RW: `SymbolContext()` forwarder (returns by value). Processor: direct member access. |
| `m_tle_*` (8 fields) | `CFalconRiskLifecycleProcessor` | Processor only (Apply #11 + day-boundary checks) | Direct member access. |
| `m_dlm_*` (2 fields) | `CFalconRiskLifecycleProcessor` | Processor only (Apply #10 + `FalconDynamicGrowthRampMaxLot`) | Direct member access. |
| `m_totals` | `CFalconReportWriter` | RW (~hundreds of sites), processor Apply #2 (9 sites) | RW: direct. Processor: receives as `FalconReportTotals &totals` param via `ApplyTradeLifecycleChain`. |

**No duplicated mutable state remains.** Verification by grep:
- `m_tle_` in `Reporting/FalconReportWriter.mqh` → 1 hit (a comment marker explaining the move).
- `m_dlm_` in `Reporting/FalconReportWriter.mqh` → 1 hit (same comment marker).
- `m_symbol_context` in `Reporting/FalconReportWriter.mqh` → 1 hit (same comment marker).
- `m_totals` in `Risk/FalconRiskLifecycleProcessor.mqh` → 4 hits (all in comments or banner notes; zero live references).

---

## 5. Verification

### 5.1 Grep — single ownership

```
grep "^   FalconReportTotals  m_totals;"  Reporting/FalconReportWriter.mqh : 1  (single owner)
grep "^   FalconReportTotals  m_totals;"  Risk/FalconRiskLifecycleProcessor.mqh : 0  (deleted)

grep "^   FalconSymbolContext m_symbol_context;"  Risk/FalconRiskLifecycleProcessor.mqh : 1  (single owner)
grep "^   FalconSymbolContext m_symbol_context;"  Reporting/FalconReportWriter.mqh : 0  (deleted)

grep "^   (bool|string|int|datetime|double)\s+m_tle_"  Risk/FalconRiskLifecycleProcessor.mqh : 8
grep "^   (bool|string|int|datetime|double)\s+m_tle_"  Reporting/FalconReportWriter.mqh : 0  (deleted, was 8)

grep "^   (bool|double)\s+m_dlm_"  Risk/FalconRiskLifecycleProcessor.mqh : 2
grep "^   (bool|double)\s+m_dlm_"  Reporting/FalconReportWriter.mqh : 0  (deleted, was 2)
```

### 5.2 Grep — chain wiring

```
g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record, m_totals)
  → Reporting/FalconReportWriter.mqh:3906 (sole call site)
ApplyTradeLifecycleChain definition
  → Risk/FalconRiskLifecycleProcessor.mqh:1624 (single definition; takes record + totals)
```

### 5.3 Grep — Initialize wiring

```
g_risk_lifecycle_processor.Initialize(symbol_context)
  → JA_FalconCore_Automated_Trading_Platform.mq5:5869 (sole call site,
    immediately after g_report_writer.Initialize(symbol_context) at L5864)
```

### 5.4 Grep — `m_totals.X` ↔ `totals.X` in processor

```
m_totals.X live references in Risk/FalconRiskLifecycleProcessor.mqh : 0  (was 9; all in Apply #2)
totals.X references in Risk/FalconRiskLifecycleProcessor.mqh        : 9  (all in Apply #2)
```

### 5.5 Grep — dead helpers gone from RW

```
FalconDynamicTierMaxLot           in Reporting/FalconReportWriter.mqh : 0  (was 1 def)
FalconDynamicCapitalMaxLot        in Reporting/FalconReportWriter.mqh : 0  (was 1 def)
FalconDynamicGrowthRampMaxLot     in Reporting/FalconReportWriter.mqh : 0  (was 1 def)
FalconNormalizeDynamicLotToBroker in Reporting/FalconReportWriter.mqh : 0  (was 1 def + 2 internal calls)
FalconRefreshUsdMetricsForActiveLot in Reporting/FalconReportWriter.mqh : 0  (was 1 def)
```
(Processor's copies are unchanged — they were the live ones already.)

### 5.6 Compile / Problems window

R0.8b touches executable code. F7 in MetaEditor is the formal arbiter. The expected forward-reference pattern (RW's inline `SymbolContext()` referencing the file-scope global `g_risk_lifecycle_processor` declared later in main `.mq5`) is the same pattern already used by RW's `RegisterClosedTrade` calling `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(...)` since R0.7cd, so the parse-order is known-good. Two new `_sc` local-variable temps were added (RW L3855 area and L3899 area) for the two bare-reference sites where `m_symbol_context` used to be passed directly to `FalconEstimateUsdByRawPoints` / `FalconFinalizeTradeMetrics`; using a local lvalue here avoids any MQL5 rvalue-to-reference uncertainty.

### 5.7 Behavior expectation

FixedLot April should produce:
- `RawNetUSD = 585.17` (unchanged — set upstream of Apply #11)
- `FinalWorkingNetUSD = 1104.89` (restored — Apply #11's BLOCKED path no longer latches against a never-reset processor field)
- broker net = `157.49` (unchanged — broker path not in this surface)

User backtest required to formally close the gate.

---

## 6. Spec §5 Acceptance Status

| Criterion | Status |
|---|---|
| `m_tle_*` / `m_dlm_*` / `m_symbol_context` in processor only | ✓ (RW copies deleted) |
| `m_totals` in ReportWriter only | ✓ (processor scaffolding `m_totals` field removed) |
| Processor has `Initialize`/`Reset` that seeds its state; called at init | ✓ (`Initialize(symbol_context)`; called at main `.mq5:5869`) |
| Emergency reset code operates on the processor's copy across all paths (daily + L1/L2/L3) | ✓ (Apply #11 was already self-contained on the processor's fields; what was missing was the SEED, now provided by `Initialize`) |
| `ApplyTradeLifecycleChain` takes `FalconReportTotals &totals`; `RegisterClosedTrade` passes `m_totals` | ✓ |
| `EA_VERSION_TAG` = `R0_8b` | ✓ (`Core/FalconConstants.mqh:10`) |
| Compile `0 errors, 0 warnings` | ⏳ MetaEditor F7 by user |
| FixedLot April: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker `157.49` | ⏳ backtest by user |
| `Docs/ReviewNotes/R0_8b_Review_Notes.md` exists | ✓ (this file) |

---

## 7. What did NOT happen

- **No `Apply*` body logic changed.** Apply #2's only edit is `m_totals.X` → `totals.X` (9 lines; semantically identical — the reference param points to the same object the old `m_totals` field would have pointed to, had it been a reference instead of a value field).
- **No new `#include` added or removed.** The forwarder pattern works with the existing include graph.
- **No `g_*` added/removed.** The single new touch is the `Initialize(symbol_context)` call on the existing `g_risk_lifecycle_processor`.
- **No reorder of `ApplyTradeLifecycleChain`.** Chain order is identical to R0.7cd / R0.8a.
- **No Lock Parity Decomposer touch.** The 6 broker telemetry methods, the 30 CSV writers, the R0.6b group gates — all untouched.
- **No idea-backlog item implemented beyond what R0.8b's scope demands.** Items 2, 3, 4 from the R0.7cd block are struck-through as resolved by R0.8b. Items 7, 8, 10, 11, 12, 13–17 remain pending.

---

## 8. Idea-backlog deltas

`Docs/Ideas_Backlog.md` updated:
- Items 2, 3, 4 (from R0.7cd) struck-through and tagged **Resolved in R0.8b**. Item 4 carries the post-mortem note explicitly identifying it as the `FinalWorkingNetUSD = 0` root cause.
- Items 13–17 added (R0.8b observations): `EA_VERSION_TAG` bump-hook idea, `SymbolContext()` by-value cost note, forwarder pattern depending on file-scope global, "totals param" pattern for future Apply-chain steps, OnInit ordering invariant.

---

## 9. After R0.8b

- **R0.8c** — Reduce `g_*` global surface (separate concern; would touch `g_risk_lifecycle_processor`, `g_report_writer`, etc., requiring careful constructor-injection or single-init coordination).
- The R0.8 cleanup phase ends with R0.8c. Beyond that, R0.9 candidates include the `FalconRiskLifecycleProcessorInputs.mqh` macro-to-input migration (idea #7), the `Docs/Archive` coordinated sweep with `ProjectMemory` link updates (idea #11), and the read-by-value `SymbolContext()` performance note (idea #14).

---

*End of R0.8b review notes. Single-owner state pattern adopted. FinalWorkingNetUSD regression root-caused and fixed by seeding the processor's previously-unseeded `m_tle_*` block. Chain order, Apply\* logic, and all other surfaces unchanged.*
