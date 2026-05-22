# Ideas Backlog

Improvement ideas observed during the refactor. **None of these are implemented.** They are recorded here so the refactor stays scoped to *moves only*, while still capturing things that would be worth doing later.

---

## From R0.7cd (Apply\* peel completion)

1. ~~**R0.6a §3.5 caller-graph correction** — that file still claims the chain runs in ascending `#1..#12` order. The actual order (now codified in `Risk/FalconRiskLifecycleProcessor.mqh::ApplyTradeLifecycleChain`) is `#3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12`. R0.6a notes should be amended in a chore commit. The R0.7b and R0.7cd specs both inherited this error.~~ **Implemented in R0.8a** (R0_6a_Review_Notes.md §3.5 corrected).

2. **R0.7b scaffolding state cleanup** — `CFalconRiskLifecycleProcessor` still carries scaffolding copies of `m_totals`, `m_symbol_context`, 8 `m_tle_*`, 2 `m_dlm_*` fields that were added in R0.7b when the processor was dormant. With R0.7cd making the processor live, these are now the canonical state for the chain. But `CFalconReportWriter` still has its own copies of the same `m_tle_*` / `m_dlm_*` / `m_symbol_context` / `m_totals` fields, written by code paths outside the chain (Initialize, Update*Foundation helpers, Lock Parity decomposer, etc.). The two copies are not aliased. Investigate which fields need to be *the same* live instance vs. which are write-only-from-one-side. Likely candidates for a `Bind(ReportWriter&)` refactor in R0.8. *(Out of scope for R0.8a — slated for R0.8b.)*

3. **`CurrentPaperRiskCapitalBeforeTrade` reads `m_tle_equity`** — that field is updated by Three-Layer-Emergency state machinery inside the processor (via `m_tle_equity = ...` in Apply #11). With the processor now live, the processor's own `m_tle_equity` is the canonical one. But ReportWriter still has its own `m_tle_equity` (unused by anything now since #11 moved). Candidate for removal in R0.8. *(Out of scope for R0.8a — slated for R0.8b.)*

4. **`CFalconReportWriter::Initialize` writes nothing to the new processor** — the processor's symbol context, tle state, dlm state are all zero-initialized at program start. Apply #11 / #10 / #9 read them; default-zero may produce different "no previous trade" behavior than ReportWriter's `Initialize(symbol_context)` did. This is the structural reason a `Bind` or `Initialize` step on the processor will eventually be needed. The current R0.7cd commit relies on this being silently OK because the first closed trade also sets m_symbol_context (via `FalconFinalizeTradeMetrics`'s downstream effects) and m_tle_equity (via Three-Layer-Emergency's "no previous emergency" path). Validate on first backtest. *(Out of scope for R0.8a — slated for R0.8b.)*

5. ~~**Risk/FalconTradeLifecycleContract.mqh is now stale documentation** — it talks about the data bus but doesn't reflect the R0.7cd "processor owns the chain, Reporting reads record fields" pattern. Consider rewriting in R0.8 (or simply deleting if R0.8's cleanup removes the need).~~ **Rewritten in R0.8a** — file now reflects the R0.7cd flow (RegisterClosedTrade → `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record)` → ReportWriter reads `record.*`), documents the actual chain order, and notes the byte-for-byte FixedLot April reference values as the ordering invariant. `#include`s preserved.

6. ~~**Reporting/FalconReportWriter.mqh still has the 12 marker comments** ("R0.7cd: Apply\* method body moved to ..."). Cosmetic — they could be cleaned up in R0.8 once the move is settled.~~ **Implemented in R0.8a** — all 12 markers removed; replaced by one header note on the class banner pointing at `CFalconRiskLifecycleProcessor`. (The unrelated R0.7b-fix `CurrentPaperRiskCapitalBeforeTrade` marker was also removed since it documented the same migration story.)

7. **`Risk/FalconRiskLifecycleProcessorInputs.mqh` has grown to 12 macros** across 3 spec rounds (R0.7b-fix, R0.7cd). Worth reviewing whether any of these constants should be `input` declarations instead of `#define`s — some look like P-profile selectors (e.g. `FALCON_FVG_QGUARD_PROFILE_TAG = "P03_SIZE250_ONLY"`) that a user might want to switch without rebuilding.

8. **The 3 "pure helper" callers inside RW (now deleted with the Apply\*) confirmed they were only used by the chain.** Good news: no R0.8 surprise for these specific helpers.

---

## From R0.8a (safe cleanup observations)

9. **`Docs/Specs/` is now empty.** R0.8a deleted the last completed SPEC (`JA_FalconCore_R0_7cd_SPEC.md`). The directory is preserved on disk but not tracked by git (empty dirs don't track). Future SPECs land here; no action needed unless we want a placeholder `.gitkeep` to keep the dir visible.

10. **Root-level `JA_FalconCore_R0_8a_SPEC.md` lives outside `Docs/Specs/`.** All other recent specs lived in `Docs/Specs/`; this one is at the repo root. Minor inconsistency — a future spec could choose one location and stick with it.

11. **Docs/Archive scope.** R0.8a archived nothing because the two stale-looking root docs (`Docs/FalconCore_Feature_Inventory_v0_57_4.md`, `Docs/JA_FalconCore_Master_Build_Plan_v0_0_0.docx`) are still referenced from every `Docs/ProjectMemory/JA_FalconCore_Project_Memory_R0_*.md` file. Archiving them would silently break links. If they are intentionally archived later, sweep `Docs/ProjectMemory/` for the references in the same change.

12. **The "removed code" comment on `FalconReportWriter` class banner** now reads as a navigation aid rather than a transient marker. If R0.8b/c folds the processor into a different boundary, this banner line will need a follow-up touch — not a now-thing.

---

## Conventions for adding to this file

- One bullet per idea. Keep it terse.
- Link to file + line where helpful.
- Date-stamp if the idea ages.
- **Do not delete bullets** when implemented — strike them and add an implemented-in-R0.X note.
