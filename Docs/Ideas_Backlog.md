# Ideas Backlog

Improvement ideas observed during the refactor. **None of these are implemented.** They are recorded here so the refactor stays scoped to *moves only*, while still capturing things that would be worth doing later.

---

## From R0.7cd (Apply\* peel completion)

1. ~~**R0.6a §3.5 caller-graph correction** — that file still claims the chain runs in ascending `#1..#12` order. The actual order (now codified in `Risk/FalconRiskLifecycleProcessor.mqh::ApplyTradeLifecycleChain`) is `#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12`. R0.6a notes should be amended in a chore commit. The R0.7b and R0.7cd specs both inherited this error.~~ **Implemented in R0.8a** (R0_6a_Review_Notes.md §3.5 corrected).

2. ~~**R0.7b scaffolding state cleanup** — `CFalconRiskLifecycleProcessor` still carries scaffolding copies of `m_totals`, `m_symbol_context`, 8 `m_tle_*`, 2 `m_dlm_*` fields that were added in R0.7b when the processor was dormant. With R0.7cd making the processor live, these are now the canonical state for the chain. But `CFalconReportWriter` still has its own copies of the same `m_tle_*` / `m_dlm_*` / `m_symbol_context` / `m_totals` fields, written by code paths outside the chain (Initialize, Update*Foundation helpers, Lock Parity decomposer, etc.). The two copies are not aliased. Investigate which fields need to be *the same* live instance vs. which are write-only-from-one-side. Likely candidates for a `Bind(ReportWriter&)` refactor in R0.8.~~ **Resolved in R0.8b** — single-owner pattern adopted. Processor owns `m_symbol_context` / `m_tle_*` / `m_dlm_*` (RW reads symbol context via `SymbolContext()` forwarder); RW owns `m_totals` (chain receives it as `FalconReportTotals &totals` parameter).

3. ~~**`CurrentPaperRiskCapitalBeforeTrade` reads `m_tle_equity`** — that field is updated by Three-Layer-Emergency state machinery inside the processor (via `m_tle_equity = ...` in Apply #11). With the processor now live, the processor's own `m_tle_equity` is the canonical one. But ReportWriter still has its own `m_tle_equity` (unused by anything now since #11 moved). Candidate for removal in R0.8.~~ **Resolved in R0.8b** — RW's `m_tle_equity` (and the rest of the `m_tle_*` block) deleted along with the dead RW helpers that used to read them.

4. ~~**`CFalconReportWriter::Initialize` writes nothing to the new processor** — the processor's symbol context, tle state, dlm state are all zero-initialized at program start. Apply #11 / #10 / #9 read them; default-zero may produce different "no previous trade" behavior than ReportWriter's `Initialize(symbol_context)` did. This is the structural reason a `Bind` or `Initialize` step on the processor will eventually be needed. The current R0.7cd commit relies on this being silently OK because the first closed trade also sets m_symbol_context (via `FalconFinalizeTradeMetrics`'s downstream effects) and m_tle_equity (via Three-Layer-Emergency's "no previous emergency" path). Validate on first backtest.~~ **Resolved in R0.8b — and confirmed as the root cause of the R0.7cd `FinalWorkingNetUSD = 0` regression.** The processor's `m_tle_*` zero-init meant `m_tle_peak_equity = 0`, so Apply #11's drawdown-pct check (`m_tle_peak_equity > 0.0 && m_tle_equity < m_tle_peak_equity`) was effectively a no-op for the first trade, but once `m_tle_emergency_active` latched on Layer 3 with no reset path on the processor side, every subsequent trade hit the BLOCKED branch and wrote `record.falcon_emergency_after_net_usd = 0.0`. The new `CFalconRiskLifecycleProcessor::Initialize` seeds these fields with the same values RW's `ResetTotals` used to set, restoring the pre-R0.7cd baseline behavior.

5. ~~**Risk/FalconTradeLifecycleContract.mqh is now stale documentation** — it talks about the data bus but doesn't reflect the R0.7cd "processor owns the chain, Reporting reads record fields" pattern. Consider rewriting in R0.8 (or simply deleting if R0.8's cleanup removes the need).~~ **Rewritten in R0.8a** — file now reflects the R0.7cd flow (RegisterClosedTrade → `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record)` → ReportWriter reads `record.*`), documents the actual chain order, and notes the byte-for-byte FixedLot April reference values as the ordering invariant. `#include`s preserved.

6. ~~**Reporting/FalconReportWriter.mqh still has the 12 marker comments** ("R0.7cd: Apply\* method body moved to ..."). Cosmetic — they could be cleaned up in R0.8 once the move is settled.~~ **Implemented in R0.8a** — all 12 markers removed; replaced by one header note on the class banner pointing at `CFalconRiskLifecycleProcessor`. (The unrelated R0.7b-fix `CurrentPaperRiskCapitalBeforeTrade` marker was also removed since it documented the same migration story.)

7. **`Risk/FalconRiskLifecycleProcessorInputs.mqh` has grown to 12 macros** across 3 spec rounds (R0.7b-fix, R0.7cd). Worth reviewing whether any of these constants should be `input` declarations instead of `#define`s — some look like P-profile selectors (e.g. `FALCON_FVG_QGUARD_PROFILE_TAG = "P03_SIZE250_ONLY"`) that a user might want to switch without rebuilding. **Deferred — post-R0** (R0.9 scope is verification + closure, not new behavior).

8. **The 3 "pure helper" callers inside RW (now deleted with the Apply\*) confirmed they were only used by the chain.** Good news: no R0.8 surprise for these specific helpers.

---

## From R0.8a (safe cleanup observations)

9. ~~**`Docs/Specs/` is now empty.** R0.8a deleted the last completed SPEC (`JA_FalconCore_R0_7cd_SPEC.md`). The directory is preserved on disk but not tracked by git (empty dirs don't track). Future SPECs land here; no action needed unless we want a placeholder `.gitkeep` to keep the dir visible.~~ **Closed in R0.9** — `.gitkeep` added so the directory stays tracked between phases.

10. ~~**Root-level `JA_FalconCore_R0_8a_SPEC.md` lives outside `Docs/Specs/`.** All other recent specs lived in `Docs/Specs/`; this one is at the repo root. Minor inconsistency — a future spec could choose one location and stick with it.~~ **Closed in R0.9** — `Docs/Specs/` is now the canonical SPEC location. The in-progress R0.9 SPEC was moved into `Docs/Specs/`; the shipped R0.8c SPEC was deleted per the R0.5b "delete completed-phase SPEC" convention.

11. **Docs/Archive scope.** R0.8a archived nothing because the two stale-looking root docs (`Docs/FalconCore_Feature_Inventory_v0_57_4.md`, `Docs/JA_FalconCore_Master_Build_Plan_v0_0_0.docx`) are still referenced from every `Docs/ProjectMemory/JA_FalconCore_Project_Memory_R0_*.md` file. Archiving them would silently break links. If they are intentionally archived later, sweep `Docs/ProjectMemory/` for the references in the same change. **Deferred — post-R0.**

12. **The "removed code" comment on `FalconReportWriter` class banner** now reads as a navigation aid rather than a transient marker. If R0.8b/c folds the processor into a different boundary, this banner line will need a follow-up touch — not a now-thing.

---

## From R0.8b (state ownership + FinalWorkingNetUSD fix)

13. **`EA_VERSION_TAG` is now a string literal manipulated by hand each spec round.** R0.8b moved it from `v0.57.4` → `R0_8b` per the new fixed-clause rule. Worth a tiny helper / script so the next phase doesn't forget; even simpler, a `.git/hooks/pre-commit` reminder if a phase file is renamed but the tag isn't bumped. Not a now-thing — flag for R0.9 or whenever release plumbing is revisited.

14. **`FalconSymbolContext SymbolContext()` returns by value on both classes.** The struct is small so this is cheap, but the MQL5 idiom is awkward (every read makes a stack copy). If MQL5 ever gains return-by-reference for class methods, switch to it. Until then, keep an eye on hot-path readers — none today, but Lock Parity Decomposer is the highest read-density caller and a worthy benchmark target.

15. **Forwarder pattern in RW reaches a file-scope global (`g_risk_lifecycle_processor`).** Works because MQL5 resolves the global at body-compile time and the global IS declared in the translation unit. If R0.8c moves RW into its own translation unit (or compiles it standalone), this forwarder will need to take a pointer/reference via a setter. Flag for R0.8c.

16. **The single Apply #2 with `FalconReportTotals &totals` is the only chain step that mutates totals.** If a future Apply step needs to mutate totals, follow the same param pattern (`Apply...(record, totals)`); the chain entry already passes both. Don't reintroduce a `m_totals` field on the processor.

17. **Initialization order in `OnInit` matters** — `g_risk_lifecycle_processor.Initialize(symbol_context)` MUST be called before any RW reporting call that internally uses `SymbolContext()`. Today RW's own `Initialize` body does not call `SymbolContext()` (only file naming), so the two Initialize calls can technically happen in either order; the current OnInit sequence runs them adjacently and that's fine. But any future RW method added inside `Initialize` that reads symbol context would silently see zero values if the processor is not yet seeded. Consider an `m_initialized` guard or a setup-state enum to make the invariant explicit.

---

## From R0.8c (globals reduction by classification)

> **R0.9 note:** R0.8c's main `.mq5` deletions were rolled back in commit
> `ae556ea` (the user reverted the 48-counter removal + 9-static-localization
> while keeping the R0.8c review notes and `EA_VERSION_TAG = R0_8c`). The
> file-scope `g_*` count therefore returned from 29 back to 86. Items 18,
> 19, 20, 22, 23 below describe the brief R0.8c-shipped shape; the bodies
> they refer to were restored. The observations themselves remain valid as
> a record of dead telemetry that *could* be retired in a future cleanup —
> they are simply no longer applied to the live tree. See
> `Docs/ReviewNotes/R0_9_Review_Notes.md` §1 for the verified post-rollback
> inventory.

18. **Localized statics still carry the `g_` prefix.** R0.8c moved 9 file-scope globals into their owner functions as `static int g_fvg_quality_distribution_count = 0;` etc. — preserving the legacy name avoided touching the read/write sites and minimized diff. A future cosmetic commit could rename them to drop the misleading prefix. Not load-bearing; do it when you'd also be touching those functions for unrelated reasons. *(Moot in the rolled-back tree — the statics are globals again; the rename only matters if R0.8c is re-attempted.)*

19. **The 48 deleted telemetry counters were a recurring pattern: instrument-first, hook-up-later, never-finished.** Each counter block was added with a comment promising it would land in the Summary report — and never did. Consider a rule for future telemetry: don't add the counter until you have the reporting consumer (or a tracked TODO with a deadline). Removing instrumentation later is cheaper than auditing dead state forever. *(Observation stands; the counters are back in the live tree post-rollback. A future post-R0 cleanup could re-attempt the removal with a clearer success criterion.)*

20. **`g_report_period_initialized` / `_finalized` booleans were orphan state.** They look like the residue of an aborted state-machine: `Initialize` sets initialized=true, finalized=false; `Finalize` sets finalized=true. But nothing ever reads either — the calling code uses null-string checks on the tags instead. Suggests the state-machine version was never wired up and the field checks were rewritten the simple way without removing the booleans. Future similar patterns are worth grepping for. *(Restored post-rollback; same observation.)*

21. **The surviving 4 runtime singletons (`g_is_initialized`, `g_runtime_tick_counter`, `g_last_processed_m5_closed_candle_time`, `g_last_staged_fvg_candidate_id`) plus `g_falcon_session_start_balance`) could all be fields on a small `CFalconRuntimeState` class.** That would drop the file-scope global count to ~25 (mostly layer singletons + report period state). Out of scope for R0.8c (the spec is explicit: A class is untouched), but a clean R0.9 candidate when there's appetite for a small structural change. **Deferred — post-R0.**

22. ~~**`FalconOttuRouteTransaction` now has an empty body.** Its caller (`OnTradeTransaction` L5961) still invokes it. If the OnTradeTransaction surface ever gets a real broker-event router, this is the natural home; otherwise it can be deleted along with its call site in a follow-up. Left in place per R0.8c's minimum-touch rule.~~ **Closed in R0.9** — the R0.8c rollback restored the 4 `g_ottu_*` counter increments inside the function. R0.9 chose "document, do not delete": a header comment above the function declares it as the intentional OnTradeTransaction router and explains that the `g_ottu_*` counters are currently un-consumed but kept as the future natural home for broker-event reporting. The function and its call site are preserved.

23. **`FalconRegisterFvgMicroCandidateMetrics` and `FalconRegisterFvgQualityCalibrationMetrics` became one-line wrappers** that just forward to the next layer. They could collapse into the call chain — but that's a function-signature change spread across multiple call sites. Defer until the FVG telemetry path is being touched for a real reason. *(Restored to multi-line bodies post-rollback; the observation only re-applies if R0.8c is re-attempted.)*

---

## From R0.9 (closure + verification)

24. **`Reporting/FalconReportWriter.mqh` is the project's largest file** at ~5,313 lines — substantially above any "≤600 lines per file" target that was floated in the original refactor plan. Per the R0.9 SPEC §0, that target was officially **cancelled** ("هدف 'أكبر ملف <600 سطر' من الخطة الأصلية غير واقعي ويُلغى — ملف كبير منظَّم داخليًّا ليس مشكلة وظيفية"). Internal splitting into Summary / TradeLifecycle / Diagnostic / LockParity / BrokerTelemetry sub-headers is a candidate for an R1.x or beyond effort if/when the FVG-micro / S00 strategy work touches the writer surface. **Deferred — post-R0 / post-strategy.**

25. **R0.8c re-attempt opportunity.** The classification + cleanup approach (48 dead, 9 localize) was correct; the rollback was a tooling/process decision, not a logic disagreement (the review notes survived, the EA_VERSION_TAG stayed bumped). If a future maintenance window opens with bandwidth for re-verification, the same diff is reapplyable from the R0.8c review-notes table. **Deferred — post-R0.**

26. **Two `Strategies/` files are placeholders** (`FalconStrategies_Placeholder.mqh`, `Strategies/S00_ScalpFvgMicro/FalconScalpFvgMicro_Placeholder.mqh`). Same for `TradeManagement/FalconTradeManagement_Placeholder.mqh`. These exist as folder-shape markers so the layout matches the spec. R1.x will populate the S00 scalp strategy; the placeholder file pattern can be retired then. *Observational, no action needed.* **R1.1a partial:** `Strategies/S00_ScalpFvgMicro/` now contains real R1.1a files (`S00_*.mqh` + `ScalpFvgMicro_SPEC.md`). The `FalconScalpFvgMicro_Placeholder.mqh` shell can be retired in R1.1b/c when the strategy class formally lands.

---

## From R1.1a (FVG detection + three quality filters)

27. **R1.1a entry point is a self-gated one-line OnTick hook.** `g_s00_fvg_detector.EvaluateOnNewBar(g_market_context)` self-checks `EnableFvgDetectionDiagnostics` and dedupes per closed M5 bar. This is the minimum-touch wiring that satisfies both "the strategy is not activated by default" and "running with the diagnostic on must produce the CSV". When R1.1b lands the entry logic, this hook will become the strategy's main per-tick driver — at which point the self-gate moves to a higher-level `EnableScalpFvgMicroStrategy` switch.

28. **ATR/MA handles are lazy-initialized inside the detector.** First call to `EvaluateOnNewBar` allocates them via `iATR` / `iMA`. There is no `OnDeinit`-side `IndicatorRelease(handle)`. MQL5 cleans up indicator handles on EA unload, but for the strategy's long-term hygiene, an explicit `Deinit()` method on `CS00FvgDetector` that releases the handles is a small win. **Deferred — R1.1b.**

29. **The active-FVG list (`m_active_fvgs`) is an unbounded array.** R1.1a only ever appends. R1.1b will need a sweep on each new bar that retires gaps past `GapExpiryBars` or invalidated by close-through. Until R1.1b lands, the array grows over a backtest run — measure memory if a full-year backtest is attempted with the diagnostic on.

30. **The diagnostic CSV writes one row per detected gap pattern, not one row per bar.** Bars with no 3-candle gap produce nothing. This matches the spec's intent ("صفّ لكل فجوة مكتشَفة") but means analysts comparing "FVG/bar density" must compute the bar count separately from MT5's tester report. Worth a one-line note in the eventual analysis tooling.

31. **The trend filter (3.3) treats `trend_ma_m5 == 0` as "skip filter".** Same for ATR (3.2). This keeps the SIZE filter (3.1) as the meaningful gatekeeper during indicator warm-up bars (first `max(AtrPeriod, TrendMaPeriod)` closed bars after Init), which is the safest default. Worth re-evaluating once R1.1b's entry logic depends on these filters being authoritative — a "warm-up complete" flag may be useful.

32. ~~**MQL5 input naming.** R1.1a uses unprefixed names (`MinGapPoints`, `AtrPeriod`, etc.) because the spec listed them unprefixed. Future strategies (S01, S02) will need their own filter parameters — at that point a `S00_` prefix sweep is the natural ergonomics fix. **Deferred — R1.x as strategies multiply.**~~ **Closed in R1.1a-fix** for the S00 inputs (six renames + the new `Enable_S00_FvgScalp` switch + `AtrPeriod` demoted to `#define S00_ATR_PERIOD`). Project-wide pre-refactor inputs (R0.6b §6 cleanup) remain deferred.

---

## Input design rules (R1.1a-fix permanent principles)

Three permanent rules for MQL5 inputs. They apply to all new strategies (S00, S01, …) and to any future cleanup of the project-wide pre-refactor input surface.

1. **An input needs a reason.** Either it is *tuned* (a value the operator changes in tests / production) or it is a *real switch* (on/off behavior with a documented effect). Constants that no one tunes — a settled standard (`ATR period = 14`, `MaxBrokerEntryRetries = 3`, etc.) — belong in `#define`. The S00 cleanup that demoted `AtrPeriod` is the model: a single `#define S00_ATR_PERIOD 14` in `S00_ScalpFvgMicroInputs.mqh` next to the other strategy parameters, not an input clogging the parameter dialog.

2. **Inputs are organized: one top-level `STRATEGIES` group + one sub-group per strategy.** MQL5 doesn't support real nested groups; we emulate the hierarchy via separator characters (`═══ STRATEGIES ═══` for the parent, `── S00 FVG Scalp ──` for the child). All strategy on/off switches (`Enable_S00_*`, `Enable_S01_*`, …) sit together in the top group so an operator can flip strategies on/off in one place; per-strategy parameters live in the child group.

3. **New names are short, clear, and carry the strategy prefix (`S00_`, `S01_`, …).** Six chars of meaningful content (`S00_MinGap`) beats fifteen of repetition (`MinGapPoints`). Cleaning up confusing **pre-refactor** input names (e.g. the project-wide ones from `Enable*Reports` blocks) is a separate deferred sweep — do not mix it with strategy-level renames.

4. **The trailing display comment on an input is part of its name.** In MQL5, the text after `// …` on an `input` line is what the operator sees in the parameter dialog — the variable name is invisible there. So the display comment must be a **clean functional description**: short English, present tense, what the operator decides with this knob. **Forbidden:** phase tags (`R1.1a`, `v0.57…`), development notes (`declared now`, `wired in R1.1b`, `Reserved for …`), incomplete sentences, references to internal symbols only the implementer would recognize. Discovered the hard way in R1.1a-labels — `S00_DiagReport`'s comment was so noisy the operator couldn't tell what the switch did.

## From R1.1a-fix (MaxGap filter + input cleanup)

33. **April diagnostics surfaced anomalous gaps up to ~31,437 points** that passed all three R1.1a filters because the filters are floor-only (SIZE / ATR thrust / TREND). These are holiday session gaps and data-feed errors, not tradable patterns. The R1.1a-fix `S00_MaxGap = 6000` ceiling is calibrated to keep ~92% of accepted gaps (sits above the 90th percentile and below the outlier tail). The 6000 number is a starting point — re-tune once a wider data window (April + May + June) is available. Rejected gaps carry the `MAXSIZE` reason in the diagnostic CSV.

34. **`Enable_S00_FvgScalp` is declared but not wired yet.** R1.1a-fix puts it in its correct group (`STRATEGIES`) so the operator's view of the parameter dialog matches the eventual reality. R1.1b is the phase that wires it — at which point detector + entry logic will gate on the switch instead of on `S00_DiagReport`.

35. **Filter chain order is now SIZE → MAXSIZE → ATR → TREND** (short-circuit, first failure wins). SIZE and MAXSIZE come first because they are pure-data checks with no indicator warm-up dependency — they always fire when relevant. ATR/TREND retain the warm-up skip pattern from R1.1a (zero ATR or zero MA ⇒ skip the filter so SIZE/MAXSIZE remain the gatekeepers).

---

## From R1.1a-labels (display-comment cleanup for S00 inputs)

36. **A dedicated R1.x phase will rename, regroup, and re-comment the entire pre-refactor input surface.** Today there are still ~46 project-wide inputs from before R0 (`EnableMainReport`, `ReportProfile`, `EnableVirtualTrailingReport`, the R0.6b group switches, `MaxTradesPerDay`, etc.). Their names mix verbosity with TLA acronyms, their groups are sequence-numbered (`"01 - …"`, `"02 - …"`) rather than purpose-grouped, and several of their trailing comments carry version tags that have aged out of meaning. **High priority — independent phase. Must not be mixed with strategy build work** (R1.1b/c) so the diff stays reviewable. Naming will follow the three "Input design rules" + the R1.1a-labels rule 4 (clean functional display comments).

37. **MQL5 has no compile-time check that the display comment matches reality.** Phase tags and stale TODOs in comments will accumulate again unless caught at code review. Consider a lightweight grep gate in CI / pre-commit that scans `Strategies/**/*.mqh` for `input.*//.*R1\.|input.*//.*v0\.` and similar phase / version markers — fails the commit if any input line carries a phase tag in its trailing comment. *Low priority — observation only.*

---

## Conventions for adding to this file

- One bullet per idea. Keep it terse.
- Link to file + line where helpful.
- Date-stamp if the idea ages.
- **Do not delete bullets** when implemented — strike them and add an implemented-in-R0.X note.
