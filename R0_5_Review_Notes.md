# R0.5 — Router Layer Migration: Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.4 (commit `c3acba4`) &nbsp;|&nbsp; **Working tree before commit.**

This document captures the spec §4 "review-as-you-move" findings for the Router layer migration — a light pass after the heavy R0.4 (347 lines vs 2,886 lines in R0.4).

---

## 1. Migration Summary

| Target file | Source range in main .mq5 (pre-migration) | Symbols moved | New file LOC |
|---|---|---|---|
| `Router/FalconStrategyRegistry.mqh` | L3929–4148 | `CFalconStrategyRegistry` (215 LOC class + 5-line header) | 233 |
| `Router/FalconStrategyAdapterShell.mqh` | L4154–4279 | `CFalconFirstShadowStrategyAdapterShell` (120 LOC class + 6-line header) | 143 |
| `Router/FalconRouterInputs.mqh` *(R0.5-fix, added post-compile)* | L1896 | `#define EnableFvgMicroRuntimePipelineRefresh` (1 macro) | 19 |
| **Total** | **352 source lines** | **2 classes + 1 macro** | **395** |

`Router/FalconRouter_Placeholder.mqh` deleted (8 LOC).

Main `.mq5` change at the deletion sites: the two class bodies are replaced by short marker comments. Plus a new 11-line `#include` block at the top.

Main `.mq5` size: **12,559 → 12,229 lines** (−330 net).

Duplication audit: both class definitions appear **exactly once**, in their respective `.mqh` files (verified via grep `^class CFalcon{StrategyRegistry|FirstShadowStrategyAdapterShell}\b` — 1 hit each, both under `Router/`).

---

## 2. `#include` order in the main `.mq5`

```cpp
// === TOP block ===
// Core (R0.2)
#include "Core/FalconConstants.mqh"
#include "Core/FalconEnums.mqh"
#include "Core/FalconCoreInputs.mqh"
#include "Core/FalconDataStructures.mqh"
#include "Core/FalconLogger.mqh"
#include "Core/FalconMarketContext.mqh"
#include "Core/FalconCandleCache.mqh"

// Evidence + Risk (R0.3)
#include "Evidence/FalconEvidenceFramework.mqh"
#include "Risk/FalconRiskInputs.mqh"
#include "Risk/FalconRiskFoundation.mqh"
#include "Risk/FalconRiskTradeManagement.mqh"

// Execution top block (R0.4) - 4 of 5 files
#include "Execution/FalconExecutionInputs.mqh"
#include "Execution/FalconExecutionGuard.mqh"
#include "Execution/FalconRuntimeSafetyGuard.mqh"
#include "Execution/FalconShadowExecutor.mqh"

// Router (R0.5 + R0.5-fix)
#include "Router/FalconRouterInputs.mqh"            // R0.5-fix: preprocessor macros referenced by Registry
#include "Router/FalconStrategyRegistry.mqh"        // depends on Core + RouterInputs
#include "Router/FalconStrategyAdapterShell.mqh"    // depends on Registry + Runtime + Shadow

// === MIDDLE block ===
// ... main .mq5 inputs (incl. EnableShadowMode and the 12 EnableStrategy_* switches) ...
// ... main .mq5 helpers (incl. FalconAdapterStatusToString) ...
// ... class CFalconReportWriter (~ line 5876, unchanged) ...

// Execution Bridge (R0.4) - included where the class used to live (~ line 12202)
#include "Execution/FalconBrokerEntryBridge.mqh"
```

**Why both Router files at the top:**
1. `CFalconStrategyRegistry` only depends on Core (`FalconStrategyRegistryEntry` struct, enums, `CFalconLogger`). All Core is already in scope.
2. `CFalconFirstShadowStrategyAdapterShell` depends on `CFalconStrategyRegistry` (above), plus `CFalconRuntimeSafetyGuard` and `CFalconShadowExecutor` — both already in the Execution top block.
3. The 13 `EnableStrategy_*` references plus `EnableShadowMode` are MQL5 `input` declarations at L1751–L1794. `input`s are globals, and MQL5's two-pass parse resolves them at method-body compile time — the same pattern that already works for `CFalconShadowExecutor` (it references `EnableShadowMode` from a top-included `.mqh`).
4. `FalconAdapterStatusToString` (defined at L2428 in main `.mq5`) is called from inside `CFalconFirstShadowStrategyAdapterShell::Initialize()` — same two-pass resolution.
5. **`EnableFvgMicroRuntimePipelineRefresh` is NOT an `input` — it is a `#define` at L1896.** Preprocessor macros are resolved during preprocessing, BEFORE the two-pass class parse, so this one identifier could NOT be forward-referenced from the top-included Registry. R0.5-fix introduces `Router/FalconRouterInputs.mqh` and includes it BEFORE the Registry class file — same pattern already established by `Core/FalconCoreInputs.mqh` and `Execution/FalconExecutionInputs.mqh`.

**No Bridge-style split:** Neither Router class touches `CFalconReportWriter`, so the R0.4 trick of including a class after the ReportWriter definition is not needed here.

---

## 3. Spec §4 — Review Protocol Findings

### 3.1 Lookahead check

**Verified clean.** Neither Router file contains any candle-data read primitive:
- 0 `CopyRates` calls
- 0 `iHigh` / `iLow` / `iOpen` / `iClose` / `iTime` calls
- 0 `SymbolInfoTick` calls

The Registry only describes strategies (string IDs, enum tags, input gates). The AdapterShell only inspects registry state plus the `IsInitialized()` flags of `CFalconRuntimeSafetyGuard` and `CFalconShadowExecutor`. Neither class observes bars.

**Verdict: SAFE.** No lookahead surface introduced or broken.

### 3.2 Globals (`g_*`) used by moved code

**Zero `g_*` references** across both moved files (verified via grep `\bg_[a-z_]` against `Router/`).

The Router globals — `g_strategy_registry` and `g_first_strategy_adapter` — remain **declared** in main `.mq5` at L11883–L11884, and the 8 callsites that use them (`OnInit` initialization, ReportWriter snapshot writes, and the FVG Micro detector / candidate-builder wiring at L11979–L12126) are also untouched.

**Per spec §1, no globals were migrated.**

### 3.3 Dead logic

| Class | Findings |
|---|---|
| `CFalconStrategyRegistry` (215 LOC) | Every method is called. `Initialize`, `IsInitialized`, `CountRegisteredStrategies`, `CountEnabledStrategies`, `CountByGroup`, `CountByHealth`, `GetEntryByIndex`, `GetEntryById`, `AnyLiveAllowed`, `PrintRegistryState` — all referenced from `g_strategy_registry.X()` callsites in main `.mq5` (`OnInit`, ReportWriter diagnostics, FVG detector wiring). **One latent dead-parameter:** `AddEntry`'s `live_allowed` argument is overridden to `false` on the next line (`m_entries[index].live_allowed = false;`). All 12 call-site values are already `false`, so the override is a defensive safeguard — intentional per v0.x policy "never allows live strategy execution." Likewise `AnyLiveAllowed()` can never return `true` for the same reason; it's a defensive read-side check. Documented but NOT modified (would change a public method signature). |
| `CFalconFirstShadowStrategyAdapterShell` (120 LOC) | `Initialize`, `IsInitialized`, `GetSnapshot`, `ResetSnapshot` — all used by `OnInit` and by `g_report_writer.WriteStrategyAdapterDiagnosticsSnapshot`. No dead branches. |

### 3.4 Silent errors

**Both classes return success unconditionally from `Initialize()`.**

- `CFalconStrategyRegistry::Initialize()` always returns `true`. The only possible silent failure would be an `ArrayResize` allocation error during `AddEntry`, but in MQL5 that raises a critical runtime error rather than returning a flag — the function cannot quietly leave the registry partially populated. Spec §1 forbids any logic change, so this is left as-is.
- `CFalconFirstShadowStrategyAdapterShell::Initialize()` always returns `true`, **including** the early-return path when the target strategy is not found in the registry (`REGISTRY_ENTRY_NOT_FOUND`). This is intentional: the adapter reports the missing-registry condition via `m_snapshot.adapter_status` / `m_snapshot.no_trade_reason` rather than via a bool return. `WriteStrategyAdapterDiagnosticsSnapshot` reads the snapshot, so the condition is surfaced — not silent. The pattern is consistent with v0.13.1 "diagnostic-only adapter shell."

**Verdict: SAFE.** No silent failures introduced or pre-existing.

### 3.5 Router ↔ ReportWriter / Strategy-detector coupling (R0.6/R0.7 signal)

The Router classes are read by — but do NOT read from — three downstream consumers:

```
CFalconReportWriter::WriteStrategyRegistryDiagnosticsSnapshot(CFalconStrategyRegistry&)
CFalconReportWriter::WriteStrategyAdapterDiagnosticsSnapshot (CFalconFirstShadowStrategyAdapterShell&)
CFalconFvgMicroShadowDetectorStub::Initialize(..., CFalconStrategyRegistry&, ...)
CFalconFvgMicroShadowCandidateBuilder::Initialize(..., CFalconStrategyRegistry&, ...)   // confirmed at L11985
```

All four are **strict read-only consumers** of the Router state — they call `GetEntryById` / `GetSnapshot` / counts. None of them is called from inside the Router classes; the coupling is strictly one-way (consumer → Router).

**Implication for R0.6 (Reporting peel):** The two `WriteStrategy*DiagnosticsSnapshot` methods will travel with `CFalconReportWriter` when it moves to `Reporting/*.mqh`. Their parameter types reference the Router classes, so `Reporting/*.mqh` must `#include "Router/FalconStrategy{Registry,AdapterShell}.mqh"` (already at the top of main `.mq5`, so no order change required).

**Implication for the Strategies migration (S00):** When `CFalconFvgMicroShadowDetectorStub` and the candidate-builder move to `Strategies/S00_ScalpFvgMicro/*.mqh`, those `.mqh` files will need the Router include — again already at the top.

No back-pointers in either direction. No state shared via globals. **Clean one-way coupling.**

### 3.6 OrderSend / execution surface

**Verified zero.** Neither moved file contains `OrderSend`, `PositionOpen`, `TRADE_ACTION_DEAL`, or any equivalent. The adapter shell explicitly hard-codes `m_snapshot.order_send_used = false` and `m_snapshot.live_allowed = false` on every code path. There is no execution surface in the Router layer — by design, and unchanged by R0.5.

---

## 4. Spec §5 Acceptance Status

| Criterion | Status |
|---|---|
| 2 Router class files with include guards | ✓ |
| `Router/FalconRouter_Placeholder.mqh` deleted | ✓ |
| Include block has Router after Execution top block, Registry before AdapterShell | ✓ |
| `Router/FalconRouterInputs.mqh` exists (R0.5-fix) and is included BEFORE the Router class files | ✓ (carries `EnableFvgMicroRuntimePipelineRefresh` `#define`, the only macro-typed Router dependency declared after the original include point) |
| Migrated code removed from main `.mq5` (no duplication) | ✓ (both classes: 1 hit under `Router/`, 0 in `.mq5`) |
| 12 `Apply*` functions still in `CFalconReportWriter` | ✓ (`grep -cE "^\s+void Apply[A-Z]"` returns 12, unchanged) |
| Compiles `0 errors, 0 warnings` | ⏳ requires MetaEditor F7 by user |
| FixedLot April: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker net = 157.49 exactly | ⏳ requires post-compile backtest by user |
| `R0_5_Review_Notes.md` exists | ✓ (this file) |

---

## 5. Critical follow-up — R0.6 / R0.7

**R0.6 (Reporting peel):** When `CFalconReportWriter` is split into `Reporting/*.mqh`, the two `WriteStrategy*DiagnosticsSnapshot` methods will move with it. They reference the Router classes by `&` parameter, so the Reporting `.mqh` will `#include "Router/FalconStrategy{Registry,AdapterShell}.mqh"`. Since both Router files are already at the **top** of main `.mq5`, the include order will remain coherent (Router before Reporting).

**R0.7 (`Apply*` peel):** Per R0.3 review notes §3.5 and R0.4 review notes §6, the `Apply*` chain inside `CFalconReportWriter` (12 functions, unchanged) still needs decomposition. R0.5 has not changed this.

**Future Strategies migration:** `CFalconFvgMicroShadowDetectorStub` and `CFalconFvgMicroShadowCandidateBuilder` are the natural next move into `Strategies/S00_ScalpFvgMicro/*.mqh`. They both take `CFalconStrategyRegistry&` — the Router header in the include block already resolves that.

---

## 6. Open items (deferred, non-blocking)

1. **Dead `live_allowed` parameter in `AddEntry`** — every call passes `false` and the body overrides to `false` regardless. Removing the parameter would change the public signature and violate spec §1 ("صفر تغيير سلوك, لا إعادة كتابة"). Left as a documented v0.x defense-in-depth pattern; revisit when live-execution surface is intentionally added.
2. **Misleading section-header comment above the Registry class:** the original block at L3929–3933 was titled "First Shadow Strategy Adapter Shell - v0.13.1" but described the Registry. This pre-existing typo was migrated verbatim into `Router/FalconStrategyRegistry.mqh`. The proper "First Shadow Strategy Adapter Shell" header lives above the AdapterShell class in its own file. Not corrected in R0.5 (spec §1 — verbatim move).
3. **`CFalconFirstShadowStrategyAdapterShell::Initialize` always returns `true`** — including on `REGISTRY_ENTRY_NOT_FOUND`. The caller in `OnInit` does check the return and treats it as success, then relies on the snapshot. This is consistent v0.13.1 behavior; flagged here as a candidate for a future "stricter init" pass when adapters become non-shells.

---

---

## 7. Post-compile fix log

**R0.5-fix:** Initial compile against R0.5 raised `undeclared identifier 'EnableFvgMicroRuntimePipelineRefresh'` at line 72 of `Router/FalconStrategyRegistry.mqh`. Root cause: that identifier is a `#define` at L1896 of main `.mq5`, not an MQL5 `input`. Two-pass class-body parse does NOT cover `#define`s — those are resolved at preprocess time. The fix adds `Router/FalconRouterInputs.mqh` (verbatim move of the single `#define`) and includes it BEFORE the Registry class file, mirroring `Core/FalconCoreInputs.mqh` and `Execution/FalconExecutionInputs.mqh`. Full audit of both Router `.mqh` files against all 625 `#define` names in main `.mq5` confirmed `EnableFvgMicroRuntimePipelineRefresh` is the **only** such collision — no second-round error expected.

---

*End of R0.5 review notes. No `Apply*`, no `OrderSend` logic, no globals, no shared structures were modified. The 2 Router classes plus 1 supporting `#define` were moved verbatim.*
