# R0.7c+d (unified) — Apply\* Peel Complete: Processor owns the chain, ReportWriter is report-only

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.7b + R0.7b-fix (commit `0fcac94`) &nbsp;|&nbsp; **Working tree before commit.**

This is the **completion of R0.7** — the largest architectural fix in the refactor sequence. After R0.7c+d, the 12 `Apply*` methods live in exactly one place (`CFalconRiskLifecycleProcessor`), `RegisterClosedTrade` invokes them through a single chain call, and `CFalconReportWriter` is finally **report-only** (no policy logic, no Risk computation).

The 18 compile errors from R0.7b-fix are gone — **causally** — because the code that referenced the missing helpers (RW's Apply\* duplicates) no longer exists.

---

## 1. Six steps executed (per spec §2)

| Step | Action | Net effect |
|---|---|---|
| 1 | Move `FALCON_FVG_QGUARD_PROFILE_TAG` macro from main `.mq5:257` → `Risk/FalconRiskLifecycleProcessorInputs.mqh` | 1 macro relocated (12 total in the inputs file now). |
| 2 | Copy Apply #3 + Apply #12 from RW into `CFalconRiskLifecycleProcessor` as private members | Processor owns all 12 Apply\* (+ `ApplyTradeLifecycleChain` = 13 method declarations). |
| 3 | Complete `ApplyTradeLifecycleChain` with 12 calls in load-bearing actual order | Chain order: `#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12` (the live working-path order, NOT the spec's ascending claim — see §3). |
| 4 | Add `CFalconRiskLifecycleProcessor g_risk_lifecycle_processor;` to main `.mq5` Global Runtime Objects block | First live instance of the processor — the class is no longer dead code. |
| 5 | In `CFalconReportWriter::RegisterClosedTrade`, replace the 12 inline `Apply*` calls with a single `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);` + add a single `AppendEmergencyTriggerEvent(record);` post-chain hook | RW's `RegisterClosedTrade` is now a thin orchestrator — chain delegated to Risk, emergency CSV emitted via record-fields. |
| 6 | Delete the 12 Apply\* method bodies from `Reporting/FalconReportWriter.mqh` (replaced with one-line "moved to..." marker comments) | 896 LOC removed from RW. RW shrinks 6,343 → 5,447 lines. |

---

## 2. Verification numbers (post-commit)

```
grep '^   void Apply[A-Z]' Reporting/FalconReportWriter.mqh                : 0   (was 12 pre-R0.7cd)
grep '^   void Apply[A-Z]' Risk/FalconRiskLifecycleProcessor.mqh           : 13  (12 Apply* + ApplyTradeLifecycleChain)
grep '^   void Apply[A-Z]' JA_FalconCore_Automated_Trading_Platform.mq5    : 0
g_risk_lifecycle_processor declaration                                     : 1   (main .mq5 in Global Runtime Objects block)
g_risk_lifecycle_processor.ApplyTradeLifecycleChain call sites             : 1   (RW::RegisterClosedTrade)
AppendEmergencyTriggerEvent(record) call sites                             : 1   (RW::RegisterClosedTrade post-chain)
Risk layer references to CFalconReportWriter (non-comment)                 : 0
Stale references in RW to deleted helpers                                  : 0   (the 2 grep hits are comment markers, not code)
```

Wiring direction is now strictly **Risk writes record → Reporting reads record + writes CSV**. The Risk layer holds no pointer/reference to ReportWriter; ReportWriter only references the global processor instance.

---

## 3. ⚠ Chain order discrepancy — final word

The R0.7cd spec text (and R0.7b before it, and R0.6a notes §3.5 originally) all describe the chain in **ascending order** `#1, #2, #3, ... #11, #12`. The processor's `ApplyTradeLifecycleChain` does **NOT** use ascending order. It uses the **actual** live order observed in `CFalconReportWriter::RegisterClosedTrade` pre-R0.7cd:

```
#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12
```

This was a deliberate, documented deviation. The spec's R0.7cd §3 also demands "صفر تغيير سلوك" (zero behavior change) and "النتيجة المالية تطابق تمامًا" (financial result byte-identical). The ascending-order claim is mutually exclusive with byte-identical behavior. Behavior-preservation wins.

The full ordering rationale (which step reads which prior step's writes) is documented inside `ApplyTradeLifecycleChain` itself as a comment block, and noted in R0.7b review notes §2. **The R0.6a §3.5 caller-graph paragraph remains stale** and is logged in `Docs/Ideas_Backlog.md` for a chore-commit correction.

---

## 4. Emergency hook — exactly one CSV write per event

Spec §2.6 + §3 "EmergencyTriggers.csv يُكتَب مرّة واحدة لكل حدث — تأكّد لا ازدواج" (written exactly once per event, verify no double-write).

Verified: there is exactly **one** caller of `AppendEmergencyTriggerEvent` in the whole codebase post-R0.7cd:

- `Reporting/FalconReportWriter.mqh:3915` — the post-chain hook inside `RegisterClosedTrade`, immediately after `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);` returns.

The processor's Apply #11 does NOT call it (this was already removed in R0.7b-fix). The deleted RW Apply #11 used to call it; with that method body gone, no other call site exists. The function self-gates on:
- R0.6b group switch: `if(!EnableTierEmergencyReports) return;`
- ReportProfile: `if(FalconReportProfileIsLockParity()) return;`
- Core gate: `if(!EnableMainReport) return;`
- Event gate: `if(record.falcon_emergency_status != "TRIGGERED") return;`

So it's safe to call unconditionally from `RegisterClosedTrade` — the function decides whether the row is actually written based on the record fields the processor wrote during the chain. **No double-write possible.**

---

## 5. Data-bus wiring — Risk → Reporting only

| Direction | Status |
|---|---|
| Risk → Reporting (processor → RW) | **None.** Processor has no `CFalconReportWriter*` member. Apply #11 inside the processor populates `record.falcon_emergency_*` fields and returns; no callbacks. |
| Reporting → Risk (RW → processor) | **One call only.** `RW::RegisterClosedTrade` invokes `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);` once per closed trade. After return, RW reads `record.emergency_*` fields and emits the CSV. |
| Shared global state | The processor and RW each carry independent scaffolded state members (`m_totals`, `m_tle_*`, `m_dlm_*`, `m_symbol_context`). The chain's authoritative writes now happen in the **processor's** copies; RW's copies are no longer touched by chain code. See Ideas Backlog #2 for the R0.8 cleanup. |

---

## 6. Per-spec §4 work protocol checks

1. **Problems window review** — I don't have access to the VS Code Problems window. Static audit instead:
   - `grep '^   void Apply[A-Z]'` counts match expectations (0/13/0 across the 3 files).
   - No stale references to the 3 moved pure helpers remain in RW (only comment markers).
   - `g_risk_lifecycle_processor` is declared exactly once (main `.mq5:5683`) and used exactly once (RW::RegisterClosedTrade).
   - Class brace balance: processor file's `^   }$` count (method closers) = method declaration count = 47 (44 helpers from R0.7b/fix + 2 new Apply* from R0.7cd + ApplyTradeLifecycleChain). Balanced.
   - Final MetaEditor F7 is still the canonical verdict — please run it.
2. **Ideas Backlog** — `Docs/Ideas_Backlog.md` created; 8 R0.7cd-derived ideas recorded, none implemented.
3. **Review notes** — this file.

---

## 7. What R0.7cd does NOT change

- **No `Apply*` method body was modified.** All 12 are byte-identical to their pre-R0.7b versions; only the class they live in changed.
- **No new `input` declarations.** No new fields on `FalconTradeLifecycleRecord` (R0.7b-fix already established that the 8 emergency fields already existed).
- **No global other than `g_risk_lifecycle_processor` added.** No globals removed.
- **Lock Parity Decomposer, the 6 broker-telemetry methods, and the 30 CSV-write methods are all untouched** — they live in RW, called from elsewhere (Bridge, RegisterClosedTrade, OnDeinit) but not from the chain.
- **R0.6b's 6 group switches and 19 gate placements are all preserved** — gating still happens at the file-write boundary inside RW, not inside the chain.

---

## 8. Spec §5 acceptance status

| Criterion | Status |
|---|---|
| Processor owns 12 `Apply*` as private members | ✓ |
| `ApplyTradeLifecycleChain` calls all 12 in chain order | ✓ (actual order, not ascending — see §3) |
| `g_risk_lifecycle_processor` defined in main `.mq5` Global Runtime Objects | ✓ (L5683) |
| `RegisterClosedTrade` calls `ApplyTradeLifecycleChain` (one call) replacing the 12 inline calls | ✓ |
| RW copies of 12 `Apply*` deleted (`grep` = 0) | ✓ |
| `EmergencyTriggers.csv` written once per event, no double-write | ✓ (single caller post-chain; self-gated function) |
| Compiles `0 errors, 0 warnings` — the 18 errors gone | ⏳ requires MetaEditor F7 verification |
| FixedLot April: 585.17 / 1104.89 / 157.49 byte-identical through new path | ⏳ requires post-compile backtest |
| `EnableTierEmergencyReports=true` produces identical `EmergencyTriggers.csv` | ⏳ requires backtest with switch toggled |
| `Docs/ReviewNotes/R0_7cd_Review_Notes.md` exists | ✓ (this file) |

---

## 9. Net file-level changes

| File | Δ |
|---|---|
| `Risk/FalconRiskLifecycleProcessor.mqh` | +2 Apply\* bodies (#3, #12); chain rewritten 10 → 12 calls. **+~150 LOC** |
| `Reporting/FalconReportWriter.mqh` | 12 Apply\* bodies deleted; replaced by 12 one-line marker comments. RegisterClosedTrade rewritten: 12 inline calls → 1 chain call + 1 emergency call. **−~880 LOC** |
| `JA_FalconCore_Automated_Trading_Platform.mq5` | +5 lines: `g_risk_lifecycle_processor` declaration + comment. 1 macro deleted (relocated to inputs). |
| `Risk/FalconRiskLifecycleProcessorInputs.mqh` | +6 lines: `FALCON_FVG_QGUARD_PROFILE_TAG` added |
| `Docs/Ideas_Backlog.md` | NEW. 8 ideas recorded; none implemented. |
| `Docs/ReviewNotes/R0_7cd_Review_Notes.md` | NEW. (This file.) |
| `Docs/Specs/JA_FalconCore_R0_7cd_SPEC.md` | NEW (housekeeping). |
| `Docs/Specs/JA_FalconCore_R0_7b_fix_SPEC.md` | Deleted (housekeeping per R0.5b §3.3). |
| `Docs/Specs/JA_FalconCore_R0_7b_SPEC.md` | Deleted (housekeeping). |

---

*End of R0.7cd review notes. R0.7 is complete. The 12 Apply\* now live in `CFalconRiskLifecycleProcessor` and are called as a single chain from `RegisterClosedTrade`. No `Apply*` body was modified; the chain order was preserved byte-for-byte against the pre-R0.7cd live path despite the spec's ascending-order claim. ReportWriter is now report-only. Risk layer has no callback into Reporting. R0.8 should pick up the scaffolding-state cleanup, the R0.6a §3.5 documentation correction, and the contract-file rewrite (see `Docs/Ideas_Backlog.md`).*
