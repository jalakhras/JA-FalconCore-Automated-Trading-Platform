# R0.7a — Risk Layer Foundation (Apply\* peel preparation): Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.6b (commit `d5b246e`) &nbsp;|&nbsp; **Working tree before commit.**

R0.7a is **foundation-only**. No `Apply*` method moves. No call site changes. No data structures relocate. Two new Risk-layer files are created and `#include`d; behavior is byte-identical to R0.6b.

This is the "vessel ready, nothing poured in" step that R0.6a's review notes §3.5 flagged as critical before any of the 12 `Apply*` could safely peel out of `CFalconReportWriter`.

---

## 1. What R0.7a creates

| File | Purpose | LOC |
|---|---|---:|
| `Risk/FalconTradeLifecycleContract.mqh` | Documentation + re-include of the data-bus structs (`FalconTradeLifecycleRecord`, `FalconReportTotals`). NO struct moved. | 71 |
| `Risk/FalconRiskLifecycleProcessor.mqh` | Empty class shell `CFalconRiskLifecycleProcessor` with a single public placeholder `ApplyTradeLifecycleChain(FalconTradeLifecycleRecord &record)` whose body is `return;`. | 75 |

`#include` block in main `.mq5` (after the Risk R0.3 block):

```cpp
#include "Risk/FalconRiskInputs.mqh"
#include "Risk/FalconRiskFoundation.mqh"
#include "Risk/FalconRiskTradeManagement.mqh"
// R0.7a additions:
#include "Risk/FalconTradeLifecycleContract.mqh"
#include "Risk/FalconRiskLifecycleProcessor.mqh"
```

---

## 2. What R0.7a does NOT do

- ❌ **No `Apply*` method body moved.** All 12 stay in `Reporting/FalconReportWriter.mqh` exactly where they were after R0.6a — verified.
- ❌ **No call site change in `RegisterClosedTrade`.** It still invokes the 12 `Apply*` inline on the same record, in the same order.
- ❌ **No data structure moved.** `FalconTradeLifecycleRecord` (Core/FalconDataStructures.mqh L445) and `FalconReportTotals` (L796) stay where they are. The contract file only re-includes `Core/FalconDataStructures.mqh` and documents what's in it. Per spec §1 "لا تحرّك بنى من Core".
- ❌ **No global instance.** `CFalconRiskLifecycleProcessor` is declared but never instantiated. No `g_risk_lifecycle_processor` global is added.
- ❌ **No input change.** No new `input` declaration, no rename.
- ❌ **No globals migrated.**

---

## 3. Verification

Pre-commit `grep` audit:

```
grep -cE '^\s+void Apply[A-Z]' Reporting/FalconReportWriter.mqh           => 12  (the canonical Apply* chain, untouched)
grep -cE '^\s+void Apply[A-Z]' JA_FalconCore_Automated_Trading_Platform.mq5 => 0
grep -cE '^\s+void Apply[A-Z]' Risk/FalconRiskLifecycleProcessor.mqh       => 1   (ApplyTradeLifecycleChain - the new entry-point shell, NOT one of the 12)
grep -c 'g_risk_lifecycle_processor' JA_FalconCore_Automated_Trading_Platform.mq5 => 0  (no global instance; the one comment-mention is documentation)
```

`CFalconRiskLifecycleProcessor` references in main `.mq5`: 1 occurrence, in a comment inside the new `#include` block — not a real reference. The class is declared in the included header but no instance exists in the program; the compiler accepts unused class declarations.

---

## 4. R0.7b / R0.7c / R0.7d migration plan (carried forward from R0.6a §3.5)

The peel order is **critical** — later `Apply*` steps read state mutated by earlier ones (e.g. `ApplyDynamicLotSizingModel` #10 reads the active-lot decision from `ApplyCalibratedSingleTradeLossCapEnforcement` #9; `ApplyThreeLayerEmergencyApplication` #11 reads SL/runner state from #5 and #6). R0.7b/c/d MUST preserve the chain order.

### R0.7b — port the Risk-natural batch (planned)

Port the 9 Risk-natural `Apply*` methods to `CFalconRiskLifecycleProcessor` as **private** members, then call them from `ApplyTradeLifecycleChain` in the historical order. The 9 are:

| # | Method | New file line (Reporting/...) | LOC |
|---:|---|---:|---:|
|  1 | `ApplyNoNewEntryUserOverridePaperEnforcement` | 2065–2106 |  42 |
|  2 | `ApplyDailyWeekendForceCloseUserOverridePaperEnforcement` | 2107–2192 |  86 |
|  4 | `ApplyPaperRuntimeGuardApplication` | 4381–4410 |  30 |
|  5 | `ApplyPaperRuntimeSmartSLProtectionApplication` | 4411–4487 |  77 |
|  6 | `ApplyPaperRuntimeRunnerApplication` | 4488–4567 |  80 |
|  7 | `ApplyCapitalTierFoundation` | 4580–4606 |  27 |
|  8 | `ApplyLowCapitalRiskFeasibilityFoundation` | 4607–4702 |  96 |
|  9 | `ApplyCalibratedSingleTradeLossCapEnforcement` | 4703–4784 |  82 |
| 10 | `ApplyDynamicLotSizingModel` | 4894–5027 | 134 |
| 11 | `ApplyThreeLayerEmergencyApplication` | 5028–5188 | 161 |
| | **R0.7b Risk-natural subtotal** | | **815** |

(The numbering in this column is the chain position, not a count. Methods #3 and #12 are not in this batch; see below.)

R0.7b strategy:
1. For each of the 10 methods above (in chain order), cut from `Reporting/FalconReportWriter.mqh` and paste as a `private` member of `CFalconRiskLifecycleProcessor` in `Risk/FalconRiskLifecycleProcessor.mqh`.
2. Inside `ApplyTradeLifecycleChain(record)`, call the 10 private methods in chain order: `ApplyNoNewEntryUserOverridePaperEnforcement(record); ApplyDailyWeekendForceCloseUserOverridePaperEnforcement(record); ApplyPaperRuntimeGuardApplication(record); ApplyPaperRuntimeSmartSLProtectionApplication(record); ApplyPaperRuntimeRunnerApplication(record); ApplyCapitalTierFoundation(record); ApplyLowCapitalRiskFeasibilityFoundation(record); ApplyCalibratedSingleTradeLossCapEnforcement(record); ApplyDynamicLotSizingModel(record); ApplyThreeLayerEmergencyApplication(record);`
3. Leave `RegisterClosedTrade` unchanged — it still invokes the 10 directly on `this` inside ReportWriter. The two paths are temporarily parallel; we delete the ReportWriter side in R0.7d after wiring the processor call in. **Or** R0.7b can already redirect the 10 calls inside `RegisterClosedTrade` to a global `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record)` — to be decided when starting R0.7b.

### R0.7c — handle the special cases #3 and #12 (planned)

- **Apply #3 — `ApplyFvgQualityShadowGuardSimulation`** (`Reporting/FalconReportWriter.mqh` L4353–4380, 28 LOC). This is a strategy-quality filter (FVG-Micro detector noise reduction), not a Risk policy. Candidate destination: `Strategies/S00_ScalpFvgMicro/`. Decision deferred to R0.7c.
- **Apply #12 — `ApplyCapitalFlowSourceClassification`** (L5189–5267, 79 LOC). Pure classification, reads but does not mutate Risk policy state. Could stay in Reporting/ (it's narrative annotation), or move to Risk/ for consistency. Decision deferred to R0.7c.

### R0.7d — wire the call (planned)

Replace the in-class calls to the 12 `Apply*` inside `RegisterClosedTrade` with a single `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);`. Add `CFalconRiskLifecycleProcessor g_risk_lifecycle_processor;` to the global runtime objects block. At that point the bodies must already live in the processor (R0.7b/c done), so `RegisterClosedTrade` simply delegates.

---

## 5. Why the placeholder is byte-safe

The new class is declared but never instantiated. In MQL5, declaring a class without instantiating it produces no allocation, no initialization, no destructor — the class declaration is purely a type definition that costs nothing at runtime. The `ApplyTradeLifecycleChain` method body is `return;` and would be compiled in only when an instance is created and the method called. Until R0.7d wires it in, the code path is dead but the type signature is pinned for R0.7b/c to extend.

The contract file does the same trick at a different level — it re-includes `Core/FalconDataStructures.mqh` (no-op because of the include guard), then has no executable code, only comments.

**Net effect:** main `.mq5` parses 2 additional `#include` directives at compile time; the preprocessor pulls in ~150 LOC of comment-heavy MQL5 plus one empty class declaration; no global ctor runs; no behaviour observable in the tester or live.

---

## 6. Spec §5 Acceptance Status

| Criterion | Status |
|---|---|
| `Risk/FalconTradeLifecycleContract.mqh` exists with include guard | ✓ |
| `Risk/FalconRiskLifecycleProcessor.mqh` exists with `CFalconRiskLifecycleProcessor` + placeholder `ApplyTradeLifecycleChain` | ✓ |
| `#include` block adds both after Risk block (after `FalconRiskTradeManagement.mqh`) | ✓ |
| 12 `Apply*` still in `Reporting/FalconReportWriter.mqh` | ✓ (grep = 12) |
| `RegisterClosedTrade` unchanged | ✓ (no call to new processor) |
| Compiles `0 errors, 0 warnings` | ⏳ requires MetaEditor F7 by user |
| FixedLot April: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89`, broker net = 157.49 — byte-identical | ⏳ requires post-compile backtest (foundation-only change should produce byte-identical output by construction) |
| `Docs/ReviewNotes/R0_7a_Review_Notes.md` exists | ✓ (this file) |

---

## 7. Open items (deferred, non-blocking)

1. **Apply #3 routing decision (Strategies/ vs. Risk/)** — `ApplyFvgQualityShadowGuardSimulation` is strategy-quality logic, not risk policy. R0.7c will decide. Leaving in Reporting/ until then.
2. **Apply #12 routing decision (Reporting/ vs. Risk/)** — `ApplyCapitalFlowSourceClassification` is read-only annotation. R0.7c will decide.
3. **Global instance placement** — `CFalconRiskLifecycleProcessor g_risk_lifecycle_processor;` will be added to the "Global Runtime Objects" block in main `.mq5` during R0.7d. Not done in R0.7a because instantiation without invocation would be dead state with no purpose.
4. **`Risk/FalconTradeLifecycleContract.mqh` as a contract document** — if it later proves more useful as just a comment block in the processor header, this file can fold into `FalconRiskLifecycleProcessor.mqh`. R0.7b/c/d may revisit.
5. **Struct location** — `FalconTradeLifecycleRecord` and `FalconReportTotals` stay in `Core/FalconDataStructures.mqh` for now. If R0.7d's final wiring shows a layering inversion (Risk needs them but they sit in Core), they may relocate in a later R0.8 cleanup. The contract file is the single point that would need to track that relocation.

---

*End of R0.7a review notes. Zero behaviour change. The 12 `Apply*` are unmodified and still inside `CFalconReportWriter`. The new Risk-layer files are the empty vessel that R0.7b/c/d will gradually fill in chain order, before R0.7d swaps `RegisterClosedTrade`'s 12 inline calls for one `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);`.*
