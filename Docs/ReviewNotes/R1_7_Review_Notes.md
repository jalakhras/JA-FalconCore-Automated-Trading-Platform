# R1.7 Review Notes — Gate-Leak Fix in the Paper Layer

**Phase type:** defect fix (gate enforcement) shipped in two attempts — original + defensive-init amend.
**Version:** `EA_VERSION_TAG = R1_7`, `EA_BUILD_TAG = GateLeakFix` (`Core/FalconConstants.mqh:10-11`).
**Branch:** `refactor`.
**Closes:** Defect #4 and #6 from the Problems list.

**Source documents (the only references for this work):**
- Exploration (line-by-line gate audit): `Docs/Explorations/Exploration_R1_7_GateLeakAudit.md`.
- Original spec: `Spec_R1_7_GateLeakFix.md`.
- Amend spec (defensive-init guard): `Spec_R1_7_Amend_DefensiveInit.md`.
- Closeout spec: `Spec_R1_7_Closeout.md`.

---

## 1. What the defect was

Two named kill-switches did not turn off what their names claimed:

- **Defect #4** — `EnableStrategy_FvgMicroRetest = false` did **not** stop the legacy FVG-micro
  shadow simulation. The Registry entry OR-ed the strategy switch with
  `EnableFvgMicroRuntimePipelineRefresh` (a structural `#define = true`), and the legacy shadow
  pipeline guarded on that same `#define` — so the strategy switch was inert.
- **Defect #6** — `Enable_TradeManagement = false` / `Enable_S01_Protection = false` did **not**
  turn off the paper protection / runner layer. Apply #5 and Apply #6 ran unconditionally inside
  `ApplyTradeLifecycleChain`, so paper counters fired and paper net values were rewritten even with
  both switches OFF.

---

## 2. Two-phase implementation

### Attempt 1 — original R1.7 (`Spec_R1_7_GateLeakFix.md`) — four call-site changes

1. **Apply #5/#6 call-site guard** in `Risk/FalconRiskLifecycleProcessor.mqh::ApplyTradeLifecycleChain`:
   wrapped the two calls in `if(Enable_TradeManagement){ if(Enable_S01_Protection) Apply#5; Apply#6; }`.
2. **Registry gate** in `Router/FalconStrategyRegistry.mqh:72`: dropped the
   `|| EnableFvgMicroRuntimePipelineRefresh` term so the entry reads `EnableStrategy_FvgMicroRetest` alone.
3. **Legacy shadow pipeline guard** in `JA_FalconCore_Automated_Trading_Platform.mq5:5806`:
   changed `if(!EnableFvgMicroRuntimePipelineRefresh) return;` to `if(!EnableStrategy_FvgMicroRetest) return;`.
4. **Version bump** `R1_6a / DiagnosticReportCleanup` → `R1_7 / GateLeakFix`.

A supporting `#include "../TradeManagement/FalconTradeManagementInputs.mqh"` was added at the top of
the processor file, because `Enable_TradeManagement` / `Enable_S01_Protection` are declared later in
the main `.mq5` include chain (line 105) than the processor itself (line 43) and were not in scope at
the method's parse point. The include is guarded, so the later include is a no-op.

### Why attempt 1 was wrong — v1/v2 runs

The "full bypass" decision (never call Apply #5/#6 when OFF) left the paper fields **uninitialised**.
Apply #5 initialises `paper_protection_net_index_points` / `_net_usd` and zeroes
`paper_protection_activated` as its first work; Apply #6 does the same for the runner fields. With the
calls skipped entirely, those fields held random memory that downstream readers
(`FalconRefreshUsdMetricsForActiveLot`) then computed from:

| Metric | Bare (v2) | Required |
|---|---|---|
| `ProtectionActivatedTrades` | **467** | 0 |
| `RunnerActivatedTrades` | **467** | 0 |
| `FinalWorkingNetUSD` | **5.38e+267** (corrupt memory) | sane number |
| `BrokerActualNetUSD` | 275.97 | 275.97 (broker was never affected) |

### Attempt 2 — amend (`Spec_R1_7_Amend_DefensiveInit.md`) — move the guard inside

Corrected design: **OFF means the passthrough defensive init runs, the logic does not.** The guard
moved from the call site into each function, **after** the defensive init and **before** the first
logical line:

- Reverted the call site (Risk:1635-1640) back to the R1.6a direct calls (no `if`).
- **Apply #5** (`ApplyPaperRuntimeSmartSLProtectionApplication`): after the defensive-init block
  (through `paper_protection_net_usd`, before `if(record.paper_guard_status != "PASSED")`):
  ```mqh
  if(!Enable_TradeManagement || !Enable_S01_Protection)
     return;
  ```
- **Apply #6** (`ApplyPaperRuntimeRunnerApplication`): same pattern, guarded on `!Enable_TradeManagement`
  only (the runner naturally no-ops when `paper_protection_activated` stayed false):
  ```mqh
  if(!Enable_TradeManagement)
     return;
  ```

The `#include` from attempt 1 stays — the flags are now read inside the functions (lines 806-900),
still before the line-105 include in the main `.mq5`.

**Defensive-init verification (runs before the guard in both functions):**
- Apply #5: `paper_protection_activated = false` (812), `paper_protection_net_index_points` (816),
  `paper_protection_net_usd` (817).
- Apply #6: `paper_runner_activated = false` (886), `paper_runner_net_index_points` (891),
  `paper_runner_net_usd` (892).

---

## 3. Acceptance criteria + achieved values (v3 runs) — **PASS**

Build: MetaEditor CLI compile, `Result: 0 errors, 0 warnings`. Operator ran both tester runs (GUI,
single-instance) on the same `.set` files as the original R1.7 spec (`R1_7_BareBaseline.set`,
`R1_7_SanityON.set`), US100_Spot / M5 / 2026.04.01→2026.04.30.

### Bare Baseline (all gates OFF)

| Metric | Required | Achieved |
|---|---|---|
| `ProtectionActivatedTrades` | = 0 | **0** ✓ |
| `RunnerActivatedTrades` | = 0 | **0** ✓ |
| `FinalWorkingNetUSD` | sane (no nan / e+267) | **−2.43** ✓ |
| `BrokerActualNetUSD` | ≈ 275–321 | **275.97** ✓ |
| `TotalTrades` | ≈ 610 | **610** ✓ |

### Sanity ON (`Enable_TradeManagement = true`, `Enable_S01_Protection = true`, FVG-micro still false)

| Metric | Required | Achieved |
|---|---|---|
| `ProtectionActivatedTrades` | > 0 | **2** ✓ |
| `RunnerActivatedTrades` | ≥ 0 | **2** ✓ |
| `FinalWorkingNetUSD` | sane | **17.53** ✓ |

The engine returns to work when both switches are ON, and is genuinely silent when they are OFF.

---

## 4. The reference bare baseline (retires 42.60)

**Bare Baseline on the R1.7 build (April 2026, US100_Spot M5):**

| Field | Value |
|---|---|
| `TotalTrades` | 610 |
| `RawNetUSD` | 648.71 |
| `BrokerActualNetUSD` | 275.97 |
| `FinalWorkingNetUSD` | −2.43 |
| `ProtectionActivatedTrades` | 0 |
| `RunnerActivatedTrades` | 0 |

`FinalWorkingNetUSD = −2.43` is an artifact of **Apply #4 (the guard step)** acting on the paper layer
alone — the broker side is stable at 275.97. This is the project's new reference bare baseline; the old
paper number **42.60 is officially retired** (it belongs to the pre-R1.5a era — see Backlog #87).

---

## 5. Lesson learned (knowledge #10)

**A guard on an init-aware function belongs *inside* it, after the defensive init — not around it.**
Skipping the whole function (call-site bypass) leaves its output fields uninitialised, and that
uninitialised memory leaks to downstream readers. The cleaner semantics: OFF = full passthrough
neutrality (init always runs), the logic is what's gated. Recorded as project knowledge #10 and as a
work rule in the Ideas Backlog. Any future gating spec follows this rule.
