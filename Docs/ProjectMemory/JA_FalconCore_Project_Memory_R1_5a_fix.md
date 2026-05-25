# JA FalconCore — Project Memory — R1.5a-fix (Phase 3a CLOSED)

## Compiled 2026-05-26 (closing Phase 3a, protection engine)

Advances `JA_FalconCore_State_Summary_R1_2d.md` forward. Invariants not restated
here (LOCK baseline, Apply* order, hard prohibitions) remain as recorded there —
**this doc records only what changed and the forward plan.** Verbatim identifiers
preserved.

---

## 1. Where we are

| Field | Value |
|---|---|
| Branch | `refactor` |
| `EA_VERSION_TAG` | `R1_5a_fix` |
| `EA_BUILD_TAG` | `ProofProtectionEngineFix` |
| Compile | `0 errors, 0 warnings` (X64 Regular) |
| Phase 1 (strategy harness) | **Complete** — S01 deterministic harness (R1.3a) |
| Phase 2 (trade-management coordinator spine + apply path) | **COMPLETE** (R1.4b spine + R1.5a apply path) |
| Phase 3a (protection engine) | **CLOSED** (this commit) |
| Default safety | `Enable_S01_Protection = false` — protection layer inert at baseline |

---

## 2. What Phase 3a delivered (and its verdict)

The first real trade-management engine, contract → coordinator → policy → real
broker modify:

- `CFalconTradeEngine` contract + broker-truth `FalconManagedPositionContext`
  (now **hybrid**: broker outputs + strategy-intent `structural_stop_price`).
- Coordinator apply path: `FALCON_TM_MODIFY_SL` → real `TRADE_ACTION_SLTP`.
- `CFalconProofProtectionEngine` (thin) + swappable `CFalconProtectionPolicy` +
  `CFalconFixedRMultipleProtection` (arms at `Trigger × R`, stop to `entry ∓ offset`,
  one-direction guard).
- **R1.5a-fix:** `R` is sized from the strategy's structural stop carried via
  `g_structural_stop_registry` (`position_ticket → structural_stop_price`), NOT
  the wide emergency broker SL. Fixed the R1.5a defect where the engine never
  armed (inflated R, backlog #76).

**Verdict (recorded):**
- The engine is **mechanically proven** — arms, issues real broker modify
  (`SL_MODIFIED`), one-direction guard holds, R realistic (tens of points),
  deterministic.
- **Profitability is NOT judgeable on the S01 harness** (no real edge). 4-month
  sweep (`2026.02.01→2026.05.25`, `$1000`): `BrokerActualNetUSD` OFF `−145.07`,
  trig1.5 `−161.30`, trig2.0 `−223.61`; no value beats OFF, months contradict.
- Protection profitability is **deferred to a real, edge-having strategy.**
  `Enable_S01_Protection` stays `false` by default.

---

## 3. Known open defect (logged, not fixed — no cleanup this phase)

`Summary.csv` `BrokerModifySent` / `RuntimeSLChanged` stay `0` despite real
coordinator SL modifies (truth lives in `TradeManagementCoordinatorAudit.csv`).
Counters are blind to the coordinator apply path. Wire before 3b/3c engines.
Backlog item added this phase.

---

## 4. Next safe step

1. **Independent cleanup phase** — input surface + temporary diagnostic reports.
   Starts with **read-only death analysis** (what is genuinely unread/unwired),
   **never mixed with a build/feature commit** (backlog #36/#37 + the new
   consolidated item). Reviewable diff is the whole point.
2. **A real, edge-having strategy** — the only context in which protection's
   profitability can actually be judged (re-run the value sweep there).

Phase ordering rule unchanged: one logical change per commit, 0-errors compile →
test → single commit before the next.

---

## 5. Probe recovery anchors

- **"Is the protection engine done?"** → Phase 3a CLOSED; mechanically proven;
  profitability deferred to a real strategy; `Enable_S01_Protection=false` default.
- **"How is R computed now?"** → `R = |broker_entry_price − structural_stop_price|`,
  structural stop carried from entry via `g_structural_stop_registry`; disarms on `0.0`.
- **"What's the 4-month sweep result?"** → OFF `−145.07`, trig1.5 `−161.30`,
  trig2.0 `−223.61`; no value beats OFF.
- **"What's the next step?"** → independent cleanup phase, then a real strategy.
- **"What's the logged defect?"** → Summary `BrokerModifySent`/`RuntimeSLChanged`
  blind to the coordinator apply path; wire before 3b/3c.
