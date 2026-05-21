# Ideas Backlog

Improvement ideas observed during the refactor. **None of these are implemented.** They are recorded here so the refactor stays scoped to *moves only*, while still capturing things that would be worth doing later.

---

## From R0.7cd (Apply\* peel completion)

1. **R0.6a §3.5 caller-graph correction** — that file still claims the chain runs in ascending `#1..#12` order. The actual order (now codified in `Risk/FalconRiskLifecycleProcessor.mqh::ApplyTradeLifecycleChain`) is `#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12`. R0.6a notes should be amended in a chore commit. The R0.7b and R0.7cd specs both inherited this error.

2. **R0.7b scaffolding state cleanup** — `CFalconRiskLifecycleProcessor` still carries scaffolding copies of `m_totals`, `m_symbol_context`, 8 `m_tle_*`, 2 `m_dlm_*` fields that were added in R0.7b when the processor was dormant. With R0.7cd making the processor live, these are now the canonical state for the chain. But `CFalconReportWriter` still has its own copies of the same `m_tle_*` / `m_dlm_*` / `m_symbol_context` / `m_totals` fields, written by code paths outside the chain (Initialize, Update*Foundation helpers, Lock Parity decomposer, etc.). The two copies are not aliased. Investigate which fields need to be *the same* live instance vs. which are write-only-from-one-side. Likely candidates for a `Bind(ReportWriter&)` refactor in R0.8.

3. **`CurrentPaperRiskCapitalBeforeTrade` reads `m_tle_equity`** — that field is updated by Three-Layer-Emergency state machinery inside the processor (via `m_tle_equity = ...` in Apply #11). With the processor now live, the processor's own `m_tle_equity` is the canonical one. But ReportWriter still has its own `m_tle_equity` (unused by anything now since #11 moved). Candidate for removal in R0.8.

4. **`CFalconReportWriter::Initialize` writes nothing to the new processor** — the processor's symbol context, tle state, dlm state are all zero-initialized at program start. Apply #11 / #10 / #9 read them; default-zero may produce different "no previous trade" behavior than ReportWriter's `Initialize(symbol_context)` did. This is the structural reason a `Bind` or `Initialize` step on the processor will eventually be needed. The current R0.7cd commit relies on this being silently OK because the first closed trade also sets m_symbol_context (via `FalconFinalizeTradeMetrics`'s downstream effects) and m_tle_equity (via Three-Layer-Emergency's "no previous emergency" path). Validate on first backtest.

5. **Risk/FalconTradeLifecycleContract.mqh is now stale documentation** — it talks about the data bus but doesn't reflect the R0.7cd "processor owns the chain, Reporting reads record fields" pattern. Consider rewriting in R0.8 (or simply deleting if R0.8's cleanup removes the need).

6. **Reporting/FalconReportWriter.mqh still has the 12 marker comments** ("R0.7cd: Apply\* method body moved to ..."). Cosmetic — they could be cleaned up in R0.8 once the move is settled.

7. **`Risk/FalconRiskLifecycleProcessorInputs.mqh` has grown to 12 macros** across 3 spec rounds (R0.7b-fix, R0.7cd). Worth reviewing whether any of these constants should be `input` declarations instead of `#define`s — some look like P-profile selectors (e.g. `FALCON_FVG_QGUARD_PROFILE_TAG = "P03_SIZE250_ONLY"`) that a user might want to switch without rebuilding.

8. **The 3 "pure helper" callers inside RW (now deleted with the Apply\*) confirmed they were only used by the chain.** Good news: no R0.8 surprise for these specific helpers.

---

## Conventions for adding to this file

- One bullet per idea. Keep it terse.
- Link to file + line where helpful.
- Date-stamp if the idea ages.
- **Do not delete bullets** when implemented — strike them and add an implemented-in-R0.X note.
