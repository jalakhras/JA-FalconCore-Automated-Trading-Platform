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

## From R1.1b (entry logic + stop + target + 1:2 gate)

38. **Entry has a one-bar built-in delay vs. spec wording.** The spec §2.3 says "entry on the open of the next bar." We implement this by waiting until bar T+1 is itself a CLOSED bar (shift=1 on the subsequent OnTick), then using `bar1.open` as entry price. This adds 5 minutes (the M5 bar length) from confirmation-detected to entry-recorded. The alternative — entering at "current tick price" on the very next tick after T closes — would require live-bar reads that the zero-lookahead rule forbids. The delay is the explicit cost of staying lookahead-safe; same-bar SL/TP checks recover most of it.

39. **Same-bar SL+TP tie-break is conservative (assume SL fills first).** Without tick-level intra-bar order, we cannot know which side was hit first when both `bar.low <= SL` and `bar.high >= TP` happen on the same bar. R1.1b assumes SL — this systematically underweights winners on bars that close inside the gap-target window. Acceptable for R1.1b's primary goal (show S00 trades, get directional signal). R1.1c (runner) may revisit if it materially distorts results.

40. **Swing-target scan walks 3-bar swings starting at k=2** to keep both neighbors closed (k-1 = 1 is also a closed bar; k+1 stays well within history). k=1 is excluded by construction. Result: the *most recent* qualifying swing is at minimum shift=2 from the entry bar — i.e., at most 10 minutes before entry on M5. For very fresh structure (entry right after a swing forms), the target may be further back than what a chart-eyeballing trader would mark. Worth re-checking after the first April trade report.

41. **`m_active_trade` is a struct field, not a heap object** — keeping the single-trade-at-a-time rule statically enforced. If R1.1c wants to grow this into the multi-leg runner (initial leg + runner leg), one option is a small `m_legs[2]` array on the same class. Either way, no separate ledger / shadow-record store is needed for paper-only S00.

42. **`S00_GapExpiry` counts bars from formation, including the formation bar itself.** First call after a new FVG lands sees `bars_elapsed_since_formation` go from 0 to 1 in the same OnTick where the detector pushed the gap. So with default `S00_GapExpiry = 20`, a gap stays watched for up to ~19 closed bars beyond its formation bar. Worth a small note in the eventual operator-facing docs.

43. **The trade diagnostic CSV writes one row per CLOSED trade.** Open trades don't appear until they close (SL / TP / timeout). For a long backtest that ends mid-trade, the very last trade may be missing from the CSV. R1.1b does not implement a "force-close on OnDeinit" sweep; R1.1c can add one along with the runner/protect logic.

44. **The paper-trade isolation pattern is reusable for S01..** Each new strategy will want its own `Enable_S0X_*` switch, its own state class, its own diagnostic CSV, and zero calls into the legacy Risk/Reporting/Execution pipeline. R1.1b establishes the template: gate the per-tick hook on the strategy switch, maintain state inside the strategy class, write diagnostics through `FalconBuildReportFileName(...)` for consistent naming. Document this pattern in the architecture doc once R1.1c is in.

---

## From R1.1b-diag (entry-quality diagnostic columns)

45. **"Diagnose first, fix second" worked already.** The R1.1b April backtest's first-cut intuitions about *why* trades lost (tight stops? oversized FVGs?) were both wrong — the data showed wide-stop trades dying too, and large gaps performing worst, the opposite of guess. R1.1b-diag formalises the pattern: when a fix is tempting, add the diagnostic columns FIRST, run the data, then commit to a fix only with the data in hand. Worth re-asserting in the operational rules doc when we touch it.

46. **`PenetrationDepth` excludes the confirmation bar by construction.** The pre-confirmation extreme is updated AFTER the state transitions in the per-FVG loop, so on the bar that triggers `REVISITED → ENTRY_PENDING` the state has already moved to `ENTRY_PENDING` and the extreme update is skipped. Same logic protects the entry bar. This matches the spec wording ("قبل شمعة التأكيد") exactly, at the cost of a slightly more involved loop order — worth re-checking if anyone reorders the per-FVG block in R1.1c.

47. **`EntryVsCE` is signed; `EntryVsGapMid` is direction-normalised.** The two fields look similar but answer different questions. `EntryVsCE = (entry - ce) / point` is a raw signed distance with the same sign convention for both directions — useful for "how far on each side of CE did the entry happen across the population." `EntryVsGapMid = 0..1` is normalised against the gap range AND oriented so `0 = near edge / 1 = far edge` regardless of direction — useful for "what fraction of the gap had price penetrated when we entered." Keep both during the analysis phase; collapse to one if the correlation tells us which one matters.

48. **`MfePoints` / `MaePoints` use bar.high / bar.low even on the bar that fires an exit.** A trade that exits at SL on the same bar still has an MFE = (bar.high - entry) / point if the bar made any favorable excursion before reversing into the stop. This is correct for "what was the maximum unrealised P&L during the trade's life" but can produce confusing-looking rows: MFE > 0 alongside `ExitReason = STOP`. Document on the analysis side; not a code issue.

49. **MFE/MAE include the entry bar.** First call is inside step 3e (entry bar same-bar fill). Subsequent calls are at the top of `UpdateOpenTradeOnBar` for every later bar. Without the entry-bar update, MFE/MAE on a same-bar-stopped trade would be 0, hiding the favorable excursion the trade did make before reversing.

50. **The 8 new columns add ~30% to the trade CSV row length.** Not a real problem (text files compress and Excel handles 20 columns trivially) but it does push the total to 20 columns. If the analysis converges on a small subset, R1.1c can collapse - or move some fields to a separate "trade observability" CSV that joins on trade ID. For now, one wide row keeps the joins simple.

---

## From R1.1b-purity (confirmation candle purity gate)

51. **Wave-analysis strategy vision.** The current S00 reads each FVG as a single revisit-and-continue pattern. The R1.1b April diagnostic CSV — especially the new `PenetrationDepth` and `ConfirmRangePoints` columns — hints that the same gap can sit inside very different multi-bar wave structures (sharp impulse + shallow pullback vs. messy choppy approach + reversal candle inside the gap). A future strategy could classify gaps by the *wave context* before deciding to trade them: e.g., reject a long when the approach to CE came down in three clean impulse legs (likely continuation of the down-move, not a reversal). Out of scope for R1.1b/c — but worth keeping in view as the analysis tooling matures. The pattern would be: aggregate the diagnostic CSV across many runs → cluster trade outcomes by wave-structure features → propose explicit wave classifications as inputs.

52. **`PenetrationDepth` observation.** R1.1b-purity introduces a body-vs-range filter on the confirmation candle, which addresses the "weak signal" failure mode surfaced by the R1.1b diagnostic. It does NOT yet address the orthogonal "bad entry location" failure mode that `PenetrationDepth` and `EntryVsGapMid` expose. The natural follow-up is a `S00_MaxPenetrationFraction` gate (rejecting setups where price already penetrated >X% of the gap before confirmation) — but only after the April + May data shows that deep-penetration setups underperform shallow-penetration setups by a margin worth the added complexity. **Defer until the data is in.** Keep `PenetrationDepth` in the CSV regardless; it's the input to that decision.

---

## From R1.1c (runner + protection unified exit)

53. ~~**Structural trailing as an alternative to ATR trailing.** R1.1c ships ATR-based runner trailing (`max(virtual_stop, close − S00_RunnerTrailAtrMult × ATR, breakeven)`) — chosen as the v1 candidate because it is the simplest, the most diagnosable, and reuses the ATR period already in the strategy. A structural alternative — moving the virtual stop to the last confirmed swing low (bull) / swing high (bear) within a small lookback — is a candidate upgrade if/when the three-month diagnostic (March + April + May) shows the ATR trail either (a) gets stopped too early on healthy pullbacks (lots of `BREAKEVEN` exits with positive MFE shortly after), or (b) gives back too much on choppy reversals (`TRAIL` exits well below the runner's MFE). The decision rule: pick whichever mechanism produces the larger average winner / loser margin on the three-month run, after the headline numbers stabilise. **Deferred — data-driven decision after the first R1.1c three-month backtest.**~~ **Superseded in R1.1c-fix.** The R1.1c half-cut-at-1R + runner-ATR-trail mechanism was rolled back after the three-month test showed two opposing failures: the half-cut clipped large winners (S00 lives on the rare large winner), and the 1R protection trigger was tied to a stop distance that was often too large to fire on real reversals. R1.1c-fix replaces it with a single fixed-points breakeven trigger. Items #54 + #55 capture what may still be worth testing *on top of* the new baseline.

---

## From R1.1c-fix (fixed-points breakeven baseline)

54. **Trailing stop AFTER breakeven arms.** R1.1c-fix moves the stop to entry once unrealised profit reaches `S00_BreakevenTrigger` points; the stop then sits there for the rest of the trade's life. A natural upgrade — *only after the fixed-threshold baseline is confirmed profitable across March + April + May* — is to start ratcheting the stop forward from the breakeven point: e.g. `max(entry, close − k × ATR)`. The difference vs. R1.1c is that the trail only starts AFTER the trade has already paid for itself (BE armed), so the worst-case outcome remains "exit at flat" rather than "exit at the original structural stop." **Test alone, on top of the R1.1c-fix baseline.** Keep or drop based on whether it improves the three-month total without regressing any single month.

55. **Partial cut at a HIGH threshold.** Different from R1.1c's half-cut-at-1R (which clipped winners early). The candidate: keep the full trade until breakeven arms, then trim a SMALL fraction (10–25%) at a substantially higher threshold (e.g. 2–3 × `S00_BreakevenTrigger`) — capturing some realised profit on the rare large winners without sacrificing the bulk of the upside. **Test alone on top of R1.1c-fix.** The "small fraction at a high threshold" parameterisation is deliberately distinct from R1.1c's failed "half at low threshold" so the test isn't predetermined to fail in the same way.

56. **Decision discipline for #54 + #55.** Add each enhancement *one at a time* on top of the R1.1c-fix baseline. Keep only if the three-month total improves AND no single month gets worse. This is the same "test → analyse → improve" rule that surfaced both the R1.1c failure and the R1.1c-fix design. Don't stack enhancements untested.

---

## From R1.2a (real-execution prep: coexistence gate + S00 lot sizing)

57. **Multi-strategy execution system + bridge generalization.** Today `CFalconBrokerEntryBridge` carries a hard-coded `FC_MAGIC_FVG_MICRO = 1100001` magic in ~12 places — every retry path, every ticket-resolve, every modify call. With only one strategy executing for real (the legacy `FVG_MICRO_RETEST`, soon S00), this is fine. The moment a second strategy goes live, the bridge needs: (a) an independent magic per strategy (e.g. `FC_MAGIC_SCALP_FVG_MICRO`, `FC_MAGIC_<S0X>`), and (b) magic-routing inside the bridge so each strategy's tickets are tracked independently. **Build only when two real-executing strategies actually exist** — premature generalization here would balloon the diff without a customer. R1.2a's `S00_RealExecution` gate is deliberately mutually-exclusive (only one strategy at a time) precisely to defer this work.

58. **Removal of the legacy `FVG_MICRO_RETEST` strategy.** Today it is the only source of the `585.17 / 1104.89 / 157.49` FixedLot April verification baseline that every refactor commit checks against. Deleting it before (a) S00 is proven profitable in real execution AND (b) an alternative verification baseline exists would remove the safety net used for every regression check since R0. **Do not delete in R1.2x.** Sequence: prove S00 → establish a new baseline run (e.g. S00 on a fixed historical window producing a checksummed report) → then retire the legacy strategy in a dedicated phase.

59. **Percent-risk lot-sizing mode for S00.** R1.2a ships only fixed-lot sizing (`S00_LotSize`) because it is the simplest and the only one needed to validate the lot-size plumbing before R1.2b's real OrderSend lands. A percent-of-equity (or percent-of-paper-equity) mode is the natural next sizing option once R1.2b is stable. Build it only when there is a concrete reason to size dynamically — fixed-lot is sufficient for the initial demo / live ramp-up. The struct field `S00PaperTrade::lot_size` and the `LotSize` CSV column are already neutral to the sizing mode, so the addition is a pure-input + pure-compute change with no downstream churn.

---

## From R1.2c (realistic close execution)

60. **First-class dual paper-vs-real report (joined on `trade_id`).** Today, S00's paper rows live in `S00_Trades_Diagnostics.csv` and the bridge's reverse-deal close lifecycle lives in `BrokerManagedCloseLifecycle*.csv`. Cross-join on `trade_id` is possible externally but tedious. A first-class report — one row per S00 trade with `PaperEntryPrice`, `RealEntryPrice`, `PaperExitPrice`, `RealExitPrice`, `PaperResult_points`, `RealResult_points`, `PaperResult_USD`, `RealResult_USD`, `Gap_USD`, `ExitReason`, `ExitFiredBy` (`S00_LOGIC` vs `SERVER_ENVELOPE`) — would make the R1.2b→R1.2c improvement immediately readable. **Build after the first three-month tester run with `S00_RealExecution = true` validates that the close path fires as designed.** Premature wiring before the data exists risks designing the wrong columns.

61. **Slippage capture on close.** `ExecuteReverseClosePositionRequest` already computes `executed_price` (the bid/ask at submission) and `result_comment`. `TryManagedCloseFromS00Trade` discards both after the call. Capturing `close_slippage = executed_price - exit_price` and writing it back into `S00PaperTrade` (parallel to R1.2b's `real_entry_slippage`) would make the close side observable. **Build only after #60** — a column without a destination report is just bookkeeping.

62. **Hoist `ENUM_S00_TRADE_EXIT_REASON` to a strategy-agnostic `ENUM_FALCON_STRATEGY_EXIT_REASON`.** Today `TryManagedCloseFromS00Trade` takes `const ENUM_S00_TRADE_EXIT_REASON reason`, which resolves only because the include order in the main `.mq5` puts `S00_EntryLogic.mqh` (line 97) before `FalconBrokerEntryBridge.mqh` (line 5676). This is fragile: any reorder of includes breaks the bridge build. A clean fix is a strategy-agnostic enum in `Core/FalconEnums.mqh` (`FALCON_EXIT_TARGET`, `FALCON_EXIT_STOP`, `FALCON_EXIT_TIMEOUT`, `FALCON_EXIT_INVALIDATED`) with each strategy mapping its own enum to the shared one at the call site. **Defer until a second real-executing strategy actually needs the bridge** — same trigger as item #57. Today the include order is stable and the coupling is documented.

63. **Decide whether to keep the v0.56.9b emergency server SL/TP envelope at open.** With R1.2c closing positions via S00's own logic, the broker-side stop is now a *safety net behind* S00 — relevant only when (a) S00's close path itself fails (rare), or (b) the EA crashes / disconnects mid-trade leaving a naked position. The envelope is wide (~3 × structural distance, USD-cap binary-searched to ≤ $75 loss), so it shouldn't fire in normal operation now. But it still costs the slippage of *whichever stop hits first* in an edge case. After three months of R1.2c data, ask: did the server envelope ever fire on an S00 trade? If never, consider going naked-but-EA-managed (`request.sl = 0.0`, `request.tp = 0.0`) which is what `FALCON_LOCK_PARITY_SERVER_STOP_POLICY` would call `NO_NAKED_ORDER_GUARD` if it were relaxed. **Data-driven decision.**

64. **Double-close defense between `TryManagedCloseFromS00Trade` and the Virtual Trailing Bridge.** The Virtual Trailing Bridge (`UpdateVirtualTrailingForOpenLinks`) runs on every tick and issues its own `ExecuteReverseClosePositionRequest` when its virtual stop is touched. With `S00_RealExecution = true` the legacy strategy is forced dark by R1.2a's coexistence gate, so the Virtual Trailing Bridge has no legacy trades to manage. But the bridge code itself is **not** gated on `S00_RealExecution` — it iterates `m_active_links[]` indiscriminately. If a future change makes the trailing bridge applicable to S00 entries, both paths could try to close the same position on the same tick. Today the second `ExecuteReverseClosePositionRequest` would fail cleanly (position already closed), but it's a sharp edge worth either gating off explicitly or testing under stress. **Investigate after #60 surfaces real close data.**

65. ~~**Move `JA_FalconCore_R1_2c_SPEC.md` to `Docs/Specs/`.** Per the R0.9 convention (item #10 in this backlog), all specs land in `Docs/Specs/`. R1.2c's SPEC currently sits at the repo root because the operator pasted it there for handoff. A follow-up chore commit can move it and delete it on phase completion (the R0.5b "delete completed-phase SPEC" rule). **Defer to next chore commit** — out of scope for the R1.2c code change.~~ **Closed in R1.2d** — R1.2c SPEC deleted from root (phase shipped in commit `ae42caa`); R1.2d SPEC placed in `Docs/Specs/` per the convention.

---

## From R1.2d (central TradeLifecycle registration for S00)

66. **Revisit `stage` semantics for strategies that really execute on the broker.** R1.2d sets `record.stage = FALCON_TRADE_STAGE_PAPER` for S00 closed trades because the 12-step `ApplyTradeLifecycleChain` in `Risk/FalconRiskLifecycleProcessor.mqh` has **zero behavioural branching on `stage`** (verified by grep — the field is consumed only by `FalconStageToString` for the `TradeLifecycle.csv` `Stage` column). So the choice today is purely cosmetic. But S00 with `S00_RealExecution = true` actually issues `OrderSend` on the bridge — it is closer to `DEMO`/`LIVE` (tester-time `DEMO`) than to `PAPER` (which historically meant *no broker order at all*). Once a second real-executing strategy exists, the enum semantics should be revisited and possibly split into a paper-or-real boolean alongside a deployment-stage enum (`TESTER` / `DEMO` / `LIVE`). **Trigger:** the introduction of a second real-executing strategy, or the first downstream report or filter that wants to distinguish "paper-only shadow simulation" from "tester-time real broker fill". Until then, the field's value is descriptive only.

---

## From R1.2d completion (S00 reconciliation linkage + unique trade_id)

67. **منع الدخول المتعدّد لـ S00 على نفس الشمعة — قرار استراتيجيّ.** Today, after a same-bar exit (`CloseActiveTrade` → `m_active_trade.open = false`) inside `RunExitEvaluation(bar1)` from step 3e, the `for(int i = 0; i < m_tracked_count; i++)` loop continues and a SECOND tracked FVG can enter on the SAME `bar1` in the same `OnTick` frame. The R1.2d-completion `trade_id` uniqueness fix (monotonic sequence suffix) ensures both entries are distinguishable in the reports, but does NOT block the second entry — it intentionally leaves the existing behaviour alone. **Open question:** is multi-entry-on-same-bar a feature (more opportunities) or a hazard (over-trading on a single signal candle)? Decision wants three-month diagnostic data: across same-bar pairs, does the second entry's expectancy match the first, or is it systematically worse (correlated outcome from the same bar's micro-structure)? Build a `last_entry_bar_time` sentinel and a `S00_BlockMultiEntryOnSameBar` toggle only after the data answers the question. **Defer until same-bar pair rate + outcome split is measured.**

68. **تفعيل paper-state snapshot لمسار S00.** `Summary.csv` reads `PaperStateSnapshotEvaluatedTrades = total_trades` but `PaperStateSnapshotWrittenRows = 0` — the only `InvariantBreaches` contributor in the post-R1.2d baseline (`total_trades != paper_state_snapshot_written_rows` at `FalconReportWriter.mqh:4012-4013`). The state is `PaperStateRecoveryMode = FOUNDATION_ONLY_STATE_RESTORE_DISABLED` — i.e. the snapshot path is disabled by design AT THE BASELINE, predating R1.2d. Wiring `AppendPaperStateSnapshotRecord` for S00 (and possibly toggling the recovery mode for the S00 path) would clear the last `InvariantBreach` and let `ReportIntegrityStatus = PASS`. **Defer** — needs a separate scoping pass to confirm the snapshot path is meaningful for a paper-isolated single-trade-at-a-time strategy like S00 (legacy `FVG_MICRO_RETEST` may also write zero rows for the same reason). Check the legacy baseline before wiring; if it's also zero there, the breach is structural, not S00-specific. **Superseded by #69** — the legacy-baseline check is now confirmed: this breach exists in both lanes.

69. **ميزة paper_state_snapshot معطّلة على مستوى المشروع — تكسر تكامل التقرير حتى في baseline legacy؛ دَيْن قائم.** Confirmed in the R1.2d BreachFix verification: the legacy April baseline Summary shows the same `paper_state_snapshot_written_rows = 0` against `paper_state_snapshot_evaluated_trades = 536`, which fires invariant check #14 at `FalconReportWriter.mqh:4012-4013` and prevents `ReportIntegrityStatus = PASS` for every run since the snapshot path was disabled. The runtime mode `FOUNDATION_ONLY_STATE_RESTORE_DISABLED` (`PaperStateRecoveryMode` column) shows the disablement is intentional / project-wide, not a per-strategy gap. **Two-part decision needed:** (a) if state-snapshot restore is genuinely out of scope for the foreseeable future, change check #14 to be conditional on `PaperStateRecoveryMode != "..._DISABLED"` so the perpetual breach doesn't drown future real signals; (b) if state-restore is on the roadmap, scope and wire `AppendPaperStateSnapshotRecord` for ALL writer paths (legacy + S00). **Defer** until the operator decides which of (a) or (b) reflects intent — both are structural and out of scope for any single phase commit. **Re-confirmed in R1.3a** (`S01HarnessDeterministicEntry`, commit `9b5e9bc`): a read-only code diagnosis traced the identical breach — `evaluated_trades == total_trades` but `written_rows = 0` via the `EnableTierEmergencyReports=false` gate at `FalconReportWriter.mqh:1448` (write counter at `:1504` never reached). `FalconReportWriter.mqh` is byte-identical R1.2d↔R1.3a, so this is not an S01/R1.3a regression. The breach now stands verified across all three lanes (legacy + S00 + R1.3a S01 harness); accepted as known debt for the Phase 1a close — see `Docs/ReviewNotes/R1_3a_Review_Notes.md`. Item stays **open**.

---

## From R1.4a (broker-truth meter reporting)

70. **Make the emergency three-layer system real governance that blocks broker *entry* — not a paper-only post-hoc overlay.** Today `ApplyThreeLayerEmergencyApplication` (`Risk/FalconRiskLifecycleProcessor.mqh:1358-1364`) runs at *close* time and only zeroes the paper `falcon_emergency_after_net_*` of a BLOCKED trade; the broker entry already fired at signal time with no emergency gate (`Strategies/S01_Harness/S01_EntryLogic.mqh:246-247`). So `FinalWorkingNetUSD` is a counterfactual (−34$) while the broker really executed those trades (+243$). R1.4a only *reports* the truth; the real fix is to gate `TryOpenFromShadowRecord` on the live emergency state so paper and broker agree. **Phase 4 work (governance), not reporting.** Out of scope for any single reporting commit.

71. **Rename the `MANAGED_CLOSE_PRICE_POINTS_GAP_ON_MATCHED_CLOSE` category — the name is misleading.** It is assigned (`FalconReportWriter.mqh:909-911`) by comparing `broker_actual_points` against `paper_final_points` (= `falcon_emergency_after_net_points`, `:319-321`), which is **zeroed** for BLOCKED trades — so the category fires *by construction* from emergency zeroing, not from a broker-vs-paper price-path difference as the name implies. R1.4a adds the `LockParityGapIsEmergencyZeroingArtifact` column to disambiguate without renaming (a text check may depend on the string). **Candidate for a dedicated reporting-cleanup phase** to rename to something like `MANAGED_CLOSE_PAPER_FINAL_POINTS_GAP` once no downstream check keys on the literal. Do not rename inside a non-cleanup commit.

72. **The paper `1104.89` regression baseline is going stale — pin a broker-side baseline.** With `PrimaryResultMetric = BROKER_ACTUAL_NET_USD` declared in R1.4a, `FinalWorkingNetUSD` is no longer the truth metric, yet the regression gate still verifies the paper `RawNetUSD = 585.17` / `FinalWorkingNetUSD = 1104.89` baseline. Once engine work lands, adopting the broker side as the success metric requires pinning a new broker-side regression baseline (`BrokerActualNetUSD` for a fixed known run). **Linked to Backlog #58.** Defer until a deterministic broker-side reference run exists.

---

## Conventions for adding to this file

- One bullet per idea. Keep it terse.
- Link to file + line where helpful.
- Date-stamp if the idea ages.
- **Do not delete bullets** when implemented — strike them and add an implemented-in-R0.X note.
