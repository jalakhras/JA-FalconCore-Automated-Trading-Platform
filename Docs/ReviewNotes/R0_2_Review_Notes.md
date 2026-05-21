# R0.2 — Core Layer Migration: Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** v0.57.4 + R0.1 &nbsp;|&nbsp; **Working tree before commit.**

This document captures the spec §4 "review-as-you-move" findings for the Core layer migration.

---

## 1. Migration Summary

| Target file | Source range(s) in main .mq5 (pre-migration) | Symbols moved | New file LOC |
|---|---|---|---|
| `Core/FalconConstants.mqh` | L11–13, L15 | `EA_NAME`, `EA_VERSION_TAG`, `EA_BUILD_TAG`, `FALCON_MTF_COUNT` | 15 |
| `Core/FalconEnums.mqh` | L844–852, L974–978, L1518–1524, L1984–2140, L3041–3061 | 22 enums | 218 |
| `Core/FalconDataStructures.mqh` | 22 ranges between L2142 and L3676 | 22 structs | 1,197 |
| `Core/FalconLogger.mqh` | L5172–5193 | `CFalconLogger` (+ its section header comment) | 33 |
| `Core/FalconMarketContext.mqh` | L5195–5391 | `CFalconMarketContext` (+ its section header comment) | 208 |
| `Core/FalconCandleCache.mqh` | L5393–5516 | `CFalconCandleCache` (+ its section header comment) | 136 |
| **Total** | **1,690 source lines** | **4 #defines + 22 enums + 22 structs + 3 classes** | **1,807** |

Net `.mq5` change: **−1,690 / +11** (deletions from migration, +11 lines for the new include block and its comment header).

The 1,807 LOC in the new `.mqh` files exceeds the 1,690 lines removed because each `.mqh` adds its own file header comment + `#ifndef…#define…#endif` include guard + section separators (≈12 extra lines per file).

Duplication audit: every migrated symbol now appears **exactly once** (`mq5=0, mqh=1`) — verified for a representative subset of enums, structs, classes, and `#define`s. No copy-paste leakage.

---

## 2. `#include` order in the main `.mq5`

```cpp
#include "Core/FalconConstants.mqh"      // EA_NAME, EA_VERSION_TAG, EA_BUILD_TAG, FALCON_MTF_COUNT
#include "Core/FalconEnums.mqh"          // 22 enums — depends on nothing
#include "Core/FalconDataStructures.mqh" // 22 structs — depends on FalconEnums (FalconTradeLifecycleRecord.direction etc.)
#include "Core/FalconLogger.mqh"         // CFalconLogger — depends on FalconConstants (EA_NAME, EA_VERSION_TAG) + input EnableVerboseExpertsLog (resolved at link time)
#include "Core/FalconMarketContext.mqh"  // CFalconMarketContext — depends on FalconEnums, FalconDataStructures (FalconSymbolContext, FalconQuoteContext, FalconCandleSnapshot), FalconLogger
#include "Core/FalconCandleCache.mqh"    // CFalconCandleCache — depends on FalconConstants (FALCON_MTF_COUNT), FalconEnums (ENUM_TIMEFRAMES via MQL builtin), FalconDataStructures (FalconCandleSnapshot), FalconLogger
```

Strict topological order: each file only references symbols from earlier-included files (or from later-declared globals / inputs in the main `.mq5`, which MQL5 resolves at link time).

---

## 3. Spec §4 — Review Protocol Findings

### 3.1 Lookahead check

**One CopyRates call** in the moved Core code:

```cpp
// Core/FalconMarketContext.mqh, GetCandleSnapshot (was main .mq5 L141 of MarketContext)
snapshot.is_closed = (shift > 0);
if(shift < 0) { CFalconLogger::Error("Candle snapshot shift cannot be negative."); return false; }
int copied = CopyRates(_Symbol, timeframe, shift, 1, rates);
```

- **Verdict: SAFE.** The function accepts a caller-supplied `shift`. When `shift == 0`, the forming bar is copied but `snapshot.is_closed = false` is flagged so consumers can opt out. Negative shifts are rejected with a Logger error.
- **No lookahead introduced by Core itself.** Callers can request `shift = 0` (open bar) but the `is_closed` flag exposes the risk to the consumer; whether they respect it is a property of the *caller*, not of Core.
- **No change recommended.** This is existing v0.57.4 behavior preserved verbatim.

`CFalconCandleCache` uses `m_analysis_shift = FalconAnalysisCandleShift()` (defaults to `1` in the constructor) and only forwards to `MarketContext::GetCandleSnapshot`. The cache itself is read-only and never reaches for `shift < m_analysis_shift`.

### 3.2 Globals (`g_*`) used by moved Core code

**Zero `g_*` references in the moved files.** `grep -nE "\bg_[a-z_]" Core/Falcon{Logger,MarketContext,CandleCache}.mqh` returns empty.

Per spec §1, globals are not migrated in R0.2 — they stay declared near EOF in the main `.mq5` until their owning layer is moved. R0.2 confirms Core is global-free, so no globals deferred from Core.

### 3.3 Dead logic

Spot audit of the three moved classes:

| Class | Dead members / branches found? |
|---|---|
| `CFalconLogger` (22 lines) | None. Three methods (Info/Warn/Error) all called externally. |
| `CFalconMarketContext` (~197 lines) | None spotted. Every field is read or written in at least one method body. |
| `CFalconCandleCache` (~123 lines) | None spotted. `m_is_loaded`, `m_valid_count`, `m_analysis_shift`, the analysis snapshot array — all referenced. |

No dead-code excision applied. Any deeper scan is deferred to R0.3+ when the surrounding helper functions move and a wider call-graph check becomes natural.

### 3.4 Silent errors

| Location | Behavior | Verdict |
|---|---|---|
| `MarketContext::GetCandleSnapshot` | `CopyRates` failure → Logger Warn + return false. Caller sees the false return. | Not silent — propagates. |
| `MarketContext::GetCandleSnapshot` | Negative shift → Logger Error + return false. | Not silent. |
| `CFalconLogger::Info` | Guarded by `EnableVerboseExpertsLog`; silent when disabled. | By design — this is a user-controllable verbosity gate, not an error path. |

No silent-error patches applied. No findings worth deferring.

---

## 4. Open Issues / Notes for Future Refactor Stages

These are observations recorded for later passes; **none are blockers for R0.2 acceptance**.

### 4.1 Layer-specific symbols currently parked in Core

The spec said "all 22 enums → `FalconEnums.mqh`" and "all 22 structs → `FalconDataStructures.mqh`", which is what we did. But some of those symbols are clearly layer-specific and will ideally migrate *out of* Core in later stages:

| Symbol | Current location (R0.2) | Natural owner (eventual) |
|---|---|---|
| `ENUM_FALCON_ORDER_FAIL_CLASS` | `Core/FalconEnums.mqh` | `Execution/` |
| `ENUM_FALCON_TSPR_MODE` | `Core/FalconEnums.mqh` | `Core/Persistence/` or `Risk/` |
| `ENUM_FALCON_REPORT_PROFILE` | `Core/FalconEnums.mqh` | `Reporting/` |
| `ENUM_FALCON_BROKER_TM_EVENT_TYPE` | `Core/FalconEnums.mqh` | `Execution/` |
| `FalconStrategyRegistryEntry`, `FalconStrategyAdapterSnapshot` | `Core/FalconDataStructures.mqh` | `Strategies/` |
| `FalconFvgMicro*Snapshot` (×5) | `Core/FalconDataStructures.mqh` | `Strategies/S00_ScalpFvgMicro/` |
| `FalconBrokerTradeLink`, `FalconBrokerTradeManagementEvent` | `Core/FalconDataStructures.mqh` | `Execution/` |
| `FalconReportTotals` (379 lines!) | `Core/FalconDataStructures.mqh` | `Reporting/` |
| `FalconRunnerBarPathStats` | `Core/FalconDataStructures.mqh` | `TradeManagement/` or `Reporting/` |
| `FalconShadowTradeRecord` | `Core/FalconDataStructures.mqh` | `Strategies/` or `Execution/Shadow/` |

**Recommendation:** keep these in Core for R0.2/R0.3 as a stable common dependency base; revisit splitting in a later pass (R0.7 or R0.8) once each owning layer has its own `.mqh`. Splitting now would force premature dependency decisions.

### 4.2 Project-metadata constants

`EA_NAME`, `EA_VERSION_TAG`, `EA_BUILD_TAG` are now in `Core/FalconConstants.mqh`. Future version bumps (next R0.x or v0.57.x release) will edit `FalconConstants.mqh` instead of the main `.mq5`. Document this in the next spec so contributors look in the right place.

### 4.3 `EnableVerboseExpertsLog` forward reference

`CFalconLogger::Info` references the input variable `EnableVerboseExpertsLog`, which is declared *after* the `#include` block in the main `.mq5`. MQL5 resolves this at link time without issue (function-body symbol references are deferred). No action needed, but documented here in case a future contributor wonders why a `.mqh` references an input declared later.

### 4.4 Comments not moved

We moved **classes with their immediately-preceding section header comments** (3-6 lines each), but **left enum/struct descriptive comments in the main `.mq5`** (e.g., `// Report profile model - v0.18.6/v0.18.8` above the enum). Those comments now orphan-reference a structure that lives in `.mqh`. Worth a sweep in a documentation pass — not a blocker.

### 4.5 `Apply*` chain intact

Verified `grep -cE "^\s+void Apply[A-Z]" main.mq5` returns **12** — same as v0.57.4 baseline. The per-trade Apply layer chain is untouched; only its inputs (structs/enums it consumes) moved.

---

## 5. Spec §5 Acceptance Status

| Criterion | Status |
|---|---|
| 6 `Core/*.mqh` files exist, each with include guard | ✓ |
| `Core/FalconCore_Placeholder.mqh` deleted | ✓ |
| Main `.mq5` starts with the 6-line `#include` block in dependency order | ✓ |
| Migrated code removed from main `.mq5` (no duplication) | ✓ (verified 17 symbols, all `mq5=0 mqh=1`) |
| Compiles `0 errors, 0 warnings` | ⏳ requires MetaEditor F7 by user |
| FixedLot April: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89` exactly | ⏳ requires post-compile backtest by user |
| `R0_2_Review_Notes.md` exists | ✓ (this file) |

**Outstanding:** MetaEditor compile + April backtest are the only remaining steps. Recommend not committing R0.2 until both pass.

---

*End of R0.2 review notes. No `Apply*`, entry, emergency SL/TP, trailing-stop, v0.57.0 LockParity, or v0.57.1 logic was touched.*
