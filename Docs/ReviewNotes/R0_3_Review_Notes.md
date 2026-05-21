# R0.3 — Evidence + Risk Layer Migration: Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.2 (commit `a5b5911`) &nbsp;|&nbsp; **Working tree before commit.**

This document captures the spec §4 "review-as-you-move" findings for the Evidence + Risk migration. Critical finding (§3.5): **the heavy risk logic is NOT in these classes — it lives in the 12 `Apply*` functions inside `CFalconReportWriter`**. R0.3 confirms this by inspection; the actual separation is deferred to R0.7.

---

## 1. Migration Summary

| Target file | Source range in main .mq5 (pre-migration) | Symbols moved | New file LOC |
|---|---|---|---|
| `Evidence/FalconEvidenceFramework.mqh` | L3840–3929 (incl. section header) | `CFalconEvidenceFramework` | 101 |
| `Risk/FalconRiskInputs.mqh` | L1680–1710 (incl. section header) | 20 `FALCON_ARCH_*` and `FALCON_*_STATUS` macros + comment block | 45 |
| `Risk/FalconRiskFoundation.mqh` | L4075–4144 (incl. section header) | `CFalconRiskFoundation` | 82 |
| `Risk/FalconRiskTradeManagement.mqh` | L12860–12921 | `CFalconRiskTradeManagementArchitecture` | 75 |
| **Total** | **253 source lines** | **3 classes + 20 macros** | **303** |

Net `.mq5` change for R0.3: **−253 / +12** (deletions from migration, +12 lines for the new include block and its comment header).

Duplication audit: every migrated symbol now appears **exactly once** (`mq5=0, mqh=1`) — verified for the 3 classes and 4 sampled macros.

---

## 2. `#include` order in the main `.mq5`

```cpp
// Core block (R0.2 / R0.2-fix)
#include "Core/FalconConstants.mqh"
#include "Core/FalconEnums.mqh"
#include "Core/FalconCoreInputs.mqh"
#include "Core/FalconDataStructures.mqh"
#include "Core/FalconLogger.mqh"
#include "Core/FalconMarketContext.mqh"
#include "Core/FalconCandleCache.mqh"

// Evidence + Risk block (R0.3)
#include "Evidence/FalconEvidenceFramework.mqh"
#include "Risk/FalconRiskInputs.mqh"           // must precede Risk classes (preprocessor-order)
#include "Risk/FalconRiskFoundation.mqh"
#include "Risk/FalconRiskTradeManagement.mqh"
```

Topology:
- `CFalconEvidenceFramework` → depends on Core (enums + structs + Logger). ✓
- `CFalconRiskFoundation` → depends on Core (Logger + FalconSymbolContext) + inputs declared later in main `.mq5` (link-resolved). ✓
- `CFalconRiskTradeManagementArchitecture` → depends on Core (Logger) + 17 macros in `Risk/FalconRiskInputs.mqh`. Calls `FalconV055ArchitectureConsolidationContractReady()` (link-resolved). ✓

---

## 3. Spec §4 — Review Protocol Findings

### 3.1 Lookahead check

**Zero `CopyRates` / `iClose` / `iHigh` / `iLow` / `iOpen` / `shift` references** in any of the three moved classes. None of them touches candle data directly.

- `CFalconEvidenceFramework` is a contract-only scaffold; it returns empty evidence packs.
- `CFalconRiskFoundation` only reads input variables (`FixedLotSize`, `MaxTradesPerDay`, etc.) and `FalconSymbolContext` fields.
- `CFalconRiskTradeManagementArchitecture` only reads `FALCON_*_STATUS` macros and calls a contract-ready helper.

**Verdict: SAFE.** No lookahead surface in this layer.

### 3.2 Globals (`g_*`) used by moved code

**Zero `g_*` references** in any of the three moved classes (verified by `grep -nE "\bg_[a-z_]"` against each class body). Per spec §1, globals are not migrated in R0.3 — they stay declared near EOF in main `.mq5` until their owning layer moves. **Evidence and Risk are both global-free**, so nothing deferred.

### 3.3 Dead logic

| Class | Findings |
|---|---|
| `CFalconEvidenceFramework` | All 7 methods used externally (Initialize, IsInitialized, Count, GetRecordByIndex, BuildEmptyEvidencePack, AddContractRecord, plus the ctor). No dead branches. |
| `CFalconRiskFoundation` | `ValidateInputs` is the only public method; its branches all map to actual input combinations. No dead validation. |
| `CFalconRiskTradeManagementArchitecture` | `Initialize/IsInitialized/IsContractReady/RiskOwnershipMap/TradeManagementOwnershipMap/PrintState` — all called from EA `OnInit` lifecycle. No dead. |
| `Risk/FalconRiskInputs.mqh` (20 macros) | **3 macros not referenced by the moved class**: `FALCON_ARCH_SCOPE`, `FALCON_ARCH_REPORT_POLICY`, `FALCON_ARCH_NEXT_PHASE`. They're documentation strings — kept in the file because they belong to the same cohesive "v0.55.0 Architecture Consolidation" comment block. Moving the block partially would orphan the section header. **No code change recommended.** |

### 3.4 Silent errors

`CFalconRiskFoundation::ValidateInputs` calls `CFalconLogger::Error` on every failure path and returns false. Caller (in `OnInit`) checks the return — not silent.

`CFalconEvidenceFramework::Initialize` returns false if `m_record_count != 4`, but does NOT emit an Error log on failure — only an Info log on success (line 3872). **Mildly silent**, but the function's contract is "return false on failure", and the call site presumably checks the return value. **Recommendation: deferred to R0.4+** (not a behavior change; just a polish item).

### 3.5 Apply* entanglement — **PRIORITY FINDING for R0.7**

> Per spec §4 item 5: "إن وجدت أن كلاس Risk يستدعي أو يتداخل مع دوال `Apply*` — سجّل ذلك بدقة. هذا مهم لتخطيط R0.7."

**Result of the audit on the three moved classes:**

| Class | `Apply*` calls inside class body | `Apply*` data structures referenced |
|---|---|---|
| `CFalconEvidenceFramework` | **0** | 0 |
| `CFalconRiskFoundation` | **0** | 0 |
| `CFalconRiskTradeManagementArchitecture` | **0** | 0 — only **describes** the `Apply*` chain via the `TradeManagementOwnershipMap()` and `RiskOwnershipMap()` string-builder methods. |

**Interpretation:** The classes named `CFalconRisk*` are scaffolds / metadata holders. The actual runtime risk logic — `ApplyCalibratedSingleTradeLossCapEnforcement`, `ApplyDynamicLotSizingModel`, `ApplyThreeLayerEmergencyApplication`, `ApplyCapitalTierFoundation`, `ApplyLowCapitalRiskFeasibilityFoundation`, `ApplyNoNewEntryUserOverridePaperEnforcement`, `ApplyDailyWeekendForceCloseUserOverridePaperEnforcement` — all live inside `CFalconReportWriter`. They are NOT methods of any `Risk*` class.

**This is exactly what the spec warned about (§0).** The Risk *naming* in v0.57.4 is purely conceptual. The actual code structure has reporting + risk + tier + emergency + force-close all sharing a single 6,292-line `CFalconReportWriter` class because that class owns the per-trade lifecycle record finalization.

**Confirmation for R0.7 (the architectural-correction stage):**

The 7 risk-logic `Apply*` functions inside `CFalconReportWriter` must be peeled out and relocated under `Risk/` in R0.7. Two of the other 5 `Apply*` functions are also misplaced relative to a clean layering:

- `ApplyCapitalFlowSourceClassification` → likely belongs under `Reporting/` (it classifies capital flow for reports).
- `ApplyFvgQualityShadowGuardSimulation` → belongs under `Strategies/S00_ScalpFvgMicro/` (FVG-specific).
- `ApplyPaperRuntimeGuardApplication` / `...SmartSLProtectionApplication` / `...RunnerApplication` → belong under `TradeManagement/` or a new `Paper/` layer.

That breakdown is **not yet acted on in R0.3** per spec §1 ("لا تعديل منطق، لا حذف وظيفة... لا لمس سلسلة الـ 12 `Apply*`").

### 3.6 The 17 macros now in `Risk/FalconRiskInputs.mqh`

Preprocessor-order constraint applied (same pattern as R0.2-fix). These macros are textually expanded inside the moved class's method bodies (`RiskOwnershipMap`, `TradeManagementOwnershipMap`, `PrintState`), so they must be `#define`d **before** the `Risk/FalconRiskTradeManagement.mqh` `#include` line in main `.mq5`.

Full list of 17 *used-by-class* macros:

| Macro | Used by |
|---|---|
| `FALCON_ARCH_STATUS`, `FALCON_ARCH_DECISION`, `FALCON_ARCH_RUNTIME_ENFORCED`, `FALCON_ARCH_POLICY`, `FALCON_ARCH_ORDER_SEND_POLICY` | `PrintState()` |
| `FALCON_RISK_MANAGER_STATUS`, `FALCON_LOT_SIZING_MANAGER_STATUS`, `FALCON_DAILY_GOVERNANCE_STATUS`, `FALCON_ENGINE_RISK_ALLOCATION_STATUS`, `FALCON_KILL_SWITCH_STATUS_V055` | `RiskOwnershipMap()` |
| `FALCON_STRUCTURAL_STOP_ENGINE_STATUS`, `FALCON_TP_BUILDER_STATUS_V055`, `FALCON_PARTIAL_MANAGER_STATUS_V055`, `FALCON_PROOF_PROTECTION_ENGINE_STATUS`, `FALCON_RUNNER_MANAGER_STATUS_V055`, `FALCON_ADAPTIVE_RATCHET_ENGINE_STATUS`, `FALCON_EARLY_FAILURE_EXIT_ENGINE_STATUS` | `TradeManagementOwnershipMap()` |

3 macros (`FALCON_ARCH_SCOPE`, `FALCON_ARCH_REPORT_POLICY`, `FALCON_ARCH_NEXT_PHASE`) are also in the same file — unused by code but kept with their cohesive comment block per §3.3 above.

---

## 4. Spec §5 Acceptance Status

| Criterion | Status |
|---|---|
| 3 Evidence/Risk class files exist with include guards | ✓ |
| `Risk/FalconRiskInputs.mqh` exists (required by preprocessor order) | ✓ |
| `Evidence/FalconEvidence_Placeholder.mqh` and `Risk/FalconRisk_Placeholder.mqh` deleted | ✓ |
| `#include` block has Evidence + Risk after Core | ✓ |
| Migrated code removed from main `.mq5` (no duplication) | ✓ (3 classes + 4 macros sampled, all `mq5=0 mqh=1`) |
| 12 `Apply*` functions still in `CFalconReportWriter` | ✓ (`grep -cE "^\s+void Apply[A-Z]"` returns 12, unchanged) |
| Compiles `0 errors, 0 warnings` | ⏳ requires MetaEditor F7 by user |
| FixedLot April: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89` exactly | ⏳ requires post-compile backtest by user |
| `R0_3_Review_Notes.md` exists | ✓ (this file) |

---

## 5. Critical follow-up for R0.7

R0.3 confirmed the spec's §0 prediction empirically: **the three `Risk/Evidence` classes carry zero risk logic and zero `Apply*` calls**. The actual risk + paper-lifecycle logic is locked inside `CFalconReportWriter`'s 12 `Apply*` methods.

**R0.7 scope (already implied by the spec, restated here for clarity):** decompose `CFalconReportWriter::Apply*` into layer-owned methods on classes that will live under `Risk/`, `TradeManagement/`, `Strategies/S00_ScalpFvgMicro/`, and `Reporting/`. Until R0.7, the `Risk/` folder remains a near-empty scaffold that owns naming + status metadata but not enforcement.

---

## 6. Open Items (deferred, non-blocking)

1. **Mildly-silent failure** in `CFalconEvidenceFramework::Initialize` (no Error log on `m_record_count != 4`). Polish item — fix when Evidence gets a real implementation.
2. **3 unused-by-class macros** in `Risk/FalconRiskInputs.mqh` (`FALCON_ARCH_SCOPE`, `FALCON_ARCH_REPORT_POLICY`, `FALCON_ARCH_NEXT_PHASE`). Either trim or leave — keeping them for now to preserve the original comment-block cohesion.

---

*End of R0.3 review notes. No `Apply*`, entry, emergency SL/TP, trailing-stop, or v0.57.0 LockParity logic was touched. The 12 `Apply*` functions remain inside `CFalconReportWriter` per spec.*
