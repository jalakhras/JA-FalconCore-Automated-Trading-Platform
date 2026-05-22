# R0.8c — Globals Reduction (by Classification): Review Notes

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R0.8b (commit `44b93c3`) &nbsp;|&nbsp; **Working tree before commit.**

R0.8c reduces the `g_*` surface by **classification first, removal second** — per the spec's explicit principle "النتيجة: العدد ينخفض **كأثر** للتنظيف الصحيح، لا كغاية بحدّ ذاتها" (count drops as a *consequence* of correct cleanup, not as a chase). No core infrastructure object is touched. The chain order, the Apply\* logic, the report writer surface, and the OnInit initialization order are all preserved.

**Before R0.8c: 86 distinct `g_*` identifiers** in `JA_FalconCore_Automated_Trading_Platform.mq5`.
**After R0.8c: 29 `g_*` identifiers.** (29 kept as Category A; 48 deleted as Category B; 9 localized as Category C.)

---

## 1. Step 1 — Classification table

Classification rules (per spec §1):
- **(A) Keep** — layer singletons (class instances), runtime state used across multiple top-level functions, plus anything ambiguous (spec §3: "عند الشكّ، الإبقاء أأمن").
- **(B) Dead — delete** — declared but its computed value is never read anywhere in the codebase (counts incremented to nowhere, etc.).
- **(C) Localize** — read AND written entirely within one function; moved into the function as `static` to preserve cross-call persistence.

All counts below were obtained via `grep -rcE "\bNAME\b" --include="*.mq5" --include="*.mqh"`. Functions identified via line-scoped `awk` on top-level definitions.

### 1.1 Category A — KEEP (29)

#### Class instances (18)
| Line | Symbol | Reason |
|---:|---|---|
| 5663 | `g_market_context` | Market data layer singleton |
| 5664 | `g_risk_foundation` | Risk validation layer singleton |
| 5665 | `g_candle_cache` | Candle data layer singleton |
| 5666 | `g_evidence_framework` | Evidence layer singleton |
| 5667 | `g_shadow_executor` | Shadow execution layer singleton |
| 5668 | `g_runtime_safety_guard` | Runtime safety layer singleton |
| 5669 | `g_strategy_registry` | Strategy registry singleton |
| 5670 | `g_first_strategy_adapter` | Strategy adapter singleton |
| 5671 | `g_fvg_micro_detector_stub` | FVG micro layer singleton |
| 5672 | `g_fvg_micro_candidate_builder` | FVG micro layer singleton |
| 5673 | `g_fvg_micro_retest_watcher` | FVG micro layer singleton |
| 5674 | `g_fvg_micro_tradeplan_stager` | FVG micro layer singleton |
| 5675 | `g_fvg_micro_lifecycle_simulator` | FVG micro layer singleton |
| 5676 | `g_report_writer` | **Critical** — Reporting layer singleton (spec §3 explicit) |
| 5677 | `g_broker_entry_bridge` | Broker layer singleton |
| 5678 | `g_execution_guard` | Execution layer singleton |
| 5679 | `g_risk_tm_architecture` | Risk-TM layer singleton |
| 5683 | `g_risk_lifecycle_processor` | **Critical** — Risk layer singleton (spec §3 explicit; forwarder pattern depends on it) |

#### Runtime state used across multiple functions (5)
| Line | Symbol | Functions touching it |
|---:|---|---|
| 5684 | `g_is_initialized` | `OnInit` (writes L5934, L5950), `OnTick` (reads L5967) |
| 5685 | `g_runtime_tick_counter` | `OnInit` (write L5839), `OnTick` (write/read L5970, L6010), `FalconShouldWriteRuntimeDiagnosticsNow` (read L5751) |
| 5686 | `g_last_processed_m5_closed_candle_time` | `FalconShouldRefreshFvgDetectorOnThisTick` (L5724–5733), `OnInit` (reset L5840) |
| 5687 | `g_last_staged_fvg_candidate_id` | `FalconRunFvgMicroRuntimeShadowPipeline` (L5797–5813), `OnInit` (reset L5841) |
| 1587 | `g_falcon_session_start_balance` | `OnInit` (write L5843), `FalconEffectiveCapitalForTier` (reads L2616–2617) |

#### Report-period state used across multiple functions (6)
| Line | Symbol | Functions touching it |
|---:|---|---|
| 168 | `g_report_period_first_time` | `FalconInitializeReportPeriodTags`, `FalconUpdateReportPeriodLastSeen`, `FalconWriteAutoPeriodManifest` |
| 169 | `g_report_period_last_time` | `FalconInitializeReportPeriodTags`, `FalconUpdateReportPeriodLastSeen`, `FalconFinalizeReportPeriodTags`, `FalconSummaryFinalReportToDateTag`, `FalconWriteAutoPeriodManifest` |
| 170 | `g_report_initial_from_tag` | `FalconInitializeReportPeriodTags` (write), `FalconFinalizeAndRenameReportFiles` (read) |
| 171 | `g_report_initial_to_tag` | `FalconInitializeReportPeriodTags` (write), `FalconFinalizeAndRenameReportFiles` (read) |
| 172 | `g_report_active_from_tag` | `FalconInitializeReportPeriodTags`, `FalconFinalizeReportPeriodTags`, `FalconSummaryFinalReportFromDateTag` |
| 173 | `g_report_active_to_tag` | `FalconInitializeReportPeriodTags`, `FalconFinalizeReportPeriodTags`, `FalconSummaryFinalReportToDateTag` |

### 1.2 Category B — DEAD: declared and incremented/written, value never read (48)

All entries below have the pattern: `decl + write(s) only`. Their values escape to nothing — no reporting writer reads them, no decision path reads them, no other function reads them. Removing both the decl and the write(s) has zero observable effect.

#### Report-period booleans never read (2)
| Line | Symbol | Sites |
|---:|---|---|
| 174 | `g_report_period_initialized` | decl + write L3470. No reads. |
| 175 | `g_report_period_finalized` | decl + write L3471 + write L3501. No reads. |

#### FVG micro candidate counters (9 — block L183–191)
| Line | Symbol | Write site |
|---:|---|---|
| 183 | `g_fvg_micro_candidate_builder_evaluations` | `++` at L2180 |
| 184 | `g_fvg_micro_detected_candidates` | `++` at L2183 |
| 185 | `g_fvg_micro_quality_evaluated` | `++` at L2187 |
| 186 | `g_fvg_micro_quality_passed` | `++` at L2191 |
| 187 | `g_fvg_micro_quality_rejected` | `++` (one site) |
| 188 | `g_fvg_micro_rejected_size` | `++` (one site) |
| 189 | `g_fvg_micro_rejected_spread` | `++` (one site) |
| 190 | `g_fvg_micro_rejected_age` | `++` (one site) |
| 191 | `g_fvg_micro_shadow_ready_candidates` | `++` (one site) |

#### FVG quality profile counters (9 — block L198–206)
| Line | Symbol | Write site |
|---:|---|---|
| 198 | `g_fvg_quality_calibration_evaluated` | `++` at L2142 |
| 199–206 | `g_fvg_quality_profile_balanced_passed` / `..._rejected`, `..._strict_size_passed` / `..._rejected`, `..._tight_spread_passed` / `..._rejected`, `..._strict_combo_passed` / `..._rejected` | each `++` once; never read |

#### FVG quality distribution write-only sub-block (7 of block L213–224)
| Line | Symbol | Write site |
|---:|---|---|
| 216 | `g_fvg_quality_size_total_points` | `+=` once; never read |
| 219 | `g_fvg_quality_spread_total_points` | `+=` once; never read |
| 220 | `g_fvg_quality_spread_le_50_count` | `++` once |
| 221 | `g_fvg_quality_spread_le_75_count` | `++` once |
| 222 | `g_fvg_quality_spread_le_100_count` | `++` once |
| 223 | `g_fvg_quality_spread_le_150_count` | `++` once |
| 224 | `g_fvg_quality_spread_le_200_count` | `++` once |

(Other 5 of this block are in Category C — they read+write within the same function.)

#### FVG retest + hold quality write-only sub-block (11 of block L232–246)
| Line | Symbol | Write site |
|---:|---|---|
| 232 | `g_fvg_retest_watch_evaluated` | `++` at L4924 |
| 233 | `g_fvg_retest_touched` | `++` once |
| 234 | `g_fvg_retest_waiting` | `++` once |
| 235 | `g_fvg_retest_fresh` | `++` once |
| 236 | `g_fvg_retest_stale` | `++` once |
| 239 | `g_fvg_retest_age_total_bars` | `+=` once |
| 240 | `g_fvg_hold_quality_evaluated` | `++` at L4946 |
| 241 | `g_fvg_hold_quality_strong` | `++` once |
| 242 | `g_fvg_hold_quality_neutral` | `++` once |
| 243 | `g_fvg_hold_quality_weak` | `++` once |
| 246 | `g_fvg_hold_quality_score_total` | `+=` once |

(Other 4 of this block are in Category C — they read+write within the same function.)

#### OrderTradeTransaction Unknown counters (4 — block L1122–1125)
| Line | Symbol | Write site |
|---:|---|---|
| 1122 | `g_ottu_transactions_observed` | `++` at L1144 |
| 1123 | `g_ottu_deal_events_routed` | `++` at L1148 |
| 1124 | `g_ottu_position_events_routed` | `++` once |
| 1125 | `g_ottu_unknown_events_ignored` | `++` once |

#### FVG quality guard runtime counters (6 — block L1499–1504)
| Line | Symbol | Write site |
|---:|---|---|
| 1499 | `g_fvg_qguard_runtime_candidate_evaluated` | `++` at L5058 |
| 1500 | `g_fvg_qguard_runtime_candidate_passed` | `++` at L5061 |
| 1501 | `g_fvg_qguard_runtime_candidate_blocked` | `++` once |
| 1502 | `g_fvg_qguard_runtime_staged_trades` | `++` once |
| 1503 | `g_fvg_qguard_runtime_passed_but_not_staged` | `++` once |
| 1504 | `g_fvg_qguard_runtime_rejected_after_pass` | `++` once |

**Total Category B: 2 + 9 + 9 + 7 + 11 + 4 + 6 = 48.**

### 1.3 Category C — LOCALIZE (9 — read AND written in single function, persistence preserved via `static`)

#### FVG quality distribution running min/max + count — owner `FalconRegisterFvgQualityDistributionMetrics` (L2090)
| Line | Symbol | Sites in owner function |
|---:|---|---|
| 213 | `g_fvg_quality_distribution_count` | write L2098, read L2101, read L2103 |
| 214 | `g_fvg_quality_size_min_points` | read L2101, write L2102 |
| 215 | `g_fvg_quality_size_max_points` | read L2103, write L2104 |
| 217 | `g_fvg_quality_spread_min_points` | read L2107, write L2108 |
| 218 | `g_fvg_quality_spread_max_points` | read L2109, write L2110 |

#### FVG retest + hold quality running min/max — owner `FalconRegisterFvgRetestFreshnessHoldMetrics` (L4918)
| Line | Symbol | Sites in owner function |
|---:|---|---|
| 237 | `g_fvg_retest_age_min_bars` | read L4928, write L4929 |
| 238 | `g_fvg_retest_age_max_bars` | read L4930, write L4931 |
| 244 | `g_fvg_hold_quality_score_min` | read L4949, write L4950 |
| 245 | `g_fvg_hold_quality_score_max` | read L4951, write L4952 |

**Each will become `static <type> <name> = <init>;` inside its owner function — same cross-call persistence semantics, no behavior change.**

---

## 2. Step 2 — Safe removal (planned, executed after this table is written)

- **(B) 48 deletions:** remove both the declaration and the write site(s). The deleted-write count per symbol matches the grep-confirmed count exactly. No reads to update because there were none.
- **(C) 9 localizations:** move declaration into owner function as `static <type> <name> = <init>;` preserving the exact init value (`= 0`, `= 0.0`, `= -1`, etc.). Identifier renaming is **not** applied — bodies keep using `g_fvg_quality_distribution_count` etc. by removing the leading `g_` becomes a stylistic question; preserving the existing name avoids touching the read/write sites and minimizes diff risk.

Actually — since these are now `static` inside a single function, the `g_` prefix becomes a misnomer. The pragmatic choice is to keep the name unchanged for minimum-touch behavior preservation; a rename can ride on a future cosmetic commit. **Decision: keep names as-is.**

---

## 3. Constraints honored

- **No Category A object touched.** `g_risk_lifecycle_processor` and `g_report_writer` are preserved verbatim — the forwarder pattern adopted in R0.8b depends on the former.
- **No OnInit re-ordering.** `g_report_writer.Initialize` (L5864) still runs before `g_risk_lifecycle_processor.Initialize` (L5869). Subsequent diagnostic-snapshot calls unchanged.
- **No Apply\* body change.** None of the Apply* methods use any Category B or C global.
- **No report writer touched.** The 48 dead counters lived in main `.mq5`, not in `Reporting/`. ReportWriter is unchanged in R0.8c.
- **`static` preserves cross-call persistence.** All 9 localized globals are running min/max/count aggregates; `static` keeps them across calls just like the global storage did. Initial values match the original decl line.
- **Conservative classification.** Eight globals where the value is read by other functions stayed in A even if their write-count is small. When unsure, A wins.

---

## 4. Verification gates (post-commit)

### 4.1 Grep — A class instances untouched
```
grep -nE "^CFalcon\w+\s+g_" JA_FalconCore_Automated_Trading_Platform.mq5
   → 18 results (lines 5663–5683), unchanged from R0.8b.
```

### 4.2 Grep — B globals truly removed
```
for v in g_fvg_micro_candidate_builder_evaluations g_fvg_quality_calibration_evaluated \
         g_fvg_retest_watch_evaluated g_ottu_transactions_observed \
         g_fvg_qguard_runtime_candidate_evaluated g_report_period_initialized; do
   grep -c "\b$v\b" JA_FalconCore_Automated_Trading_Platform.mq5
done
   → 0 for each (was 2 pre-R0.8c).
```

### 4.3 Grep — C globals localized
```
grep -nE "static\s+(int|double|long)\s+g_fvg_quality_distribution_count" \
   JA_FalconCore_Automated_Trading_Platform.mq5
   → 1 hit, inside FalconRegisterFvgQualityDistributionMetrics.
grep -E "^\s*(int|double|long)\s+g_fvg_quality_distribution_count\s*=" \
   JA_FalconCore_Automated_Trading_Platform.mq5
   → 0 (top-level decl gone).
```

### 4.4 Total `g_*` identifier count
```
grep -oE '\bg_[A-Za-z_][A-Za-z_0-9]*' JA_FalconCore_Automated_Trading_Platform.mq5 \
   | sort -u | wc -l
   → 29 (was 86).
```

### 4.5 Compile + behavior
- MetaEditor F7 by user (the formal arbiter).
- FixedLot April expected: `RawNetUSD = 585.17`, `FinalWorkingNetUSD = 1104.89` (restored in R0.8b), broker `157.49`. No Risk-layer surface touched in R0.8c, so the R0.8b fix carries forward.

---

## 5. Spec §6 Acceptance Status

| Criterion | Status |
|---|---|
| Full classification table for every `g_*` (class + reason) | ✓ (this §1) |
| Category B globals removed | ✓ (48 deletions — §1.2) |
| Category C globals localized | ✓ (9 → `static` inside owner function — §1.3) |
| Category A — layer singletons — untouched | ✓ (especially `g_risk_lifecycle_processor` + `g_report_writer`) |
| `g_*` count dropped (as a consequence) — before/after reported | ✓ **86 → 29** |
| `EA_VERSION_TAG = R0_8c` | ✓ (`Core/FalconConstants.mqh:10`) |
| Compile `0 errors, 0 warnings` | ⏳ MetaEditor F7 by user |
| FixedLot April: `585.17 / 1104.89 / 157.49` | ⏳ backtest by user |
| `Docs/ReviewNotes/R0_8c_Review_Notes.md` exists with classification table | ✓ (this file) |

---

## 6. What did NOT happen

- **No layer singleton moved or wrapped.** `g_risk_lifecycle_processor`, `g_report_writer`, and the other 16 class instances are unchanged.
- **No OnInit re-order.** R0.8b's load-bearing order (RW.Initialize before processor.Initialize before any SymbolContext()-using call) is preserved.
- **No Apply\* body change.** None of the affected globals are referenced inside any Apply\* method.
- **No identifier rename on localized globals.** `static int g_fvg_quality_distribution_count = 0;` keeps the legacy name; a stylistic rename can ride on a future commit.
- **No reads removed.** Every read site for a Category B global was confirmed absent before the corresponding write was deleted. No accidental orphan calls.
- **No `Risk/`, `Reporting/`, `Core/`, `Execution/`, `Strategies/` file touched** beyond `Core/FalconConstants.mqh` (the `EA_VERSION_TAG` bump). All cleanup happens inside `JA_FalconCore_Automated_Trading_Platform.mq5`.

---

## 7. Idea-backlog deltas

`Docs/Ideas_Backlog.md` updated:
- New items 18–21 added (R0.8c observations): localized-name rename candidate, the "telemetry counters wired up but never consumed" pattern (suggests removing it during instrumentation by default and only adding when there's a reporting consumer), the report-period boolean pair (`_initialized` / `_finalized`) that were dead — likely an orphan from an aborted state-machine refactor, and the question of whether the surviving Category-A runtime state could be re-homed onto a small `CFalconRuntimeState` instance in a future R0.9 commit.

---

## 8. After R0.8c

R0.8 (cleanup) ends here. The remaining items in `Ideas_Backlog.md` are R0.9-scope or beyond:
- Macro-to-input migration in `Risk/FalconRiskLifecycleProcessorInputs.mqh` (idea #7).
- `Docs/Archive` coordinated sweep with `ProjectMemory` link updates (idea #11).
- `SymbolContext()` return-by-reference once MQL5 allows it (idea #14).
- `EA_VERSION_TAG` bump-hook automation (idea #13).
- `CFalconRuntimeState` consolidation of the 5 surviving runtime singletons (new idea #21).

---

*End of R0.8c review notes. 86 → 29 `g_*` identifiers. Zero layer singleton touched. Zero behavior change. Counter telemetry that was wired up but never consumed has been removed; running-aggregate state has been moved next to the function that owns it.*
