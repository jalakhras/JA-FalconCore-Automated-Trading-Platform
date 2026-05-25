# R1.5a-fix Review Notes — Phase 3a close (Protection engine)

> **Phase 3a (the protection engine) is CLOSED.** This commit carries the
> protection-engine stack and its structural-stop fix only — documentation +
> code. No cleanup of any kind (deferred to its own phase, see backlog).
>
> **Base:** R1.4b (`6194f8e`). **`EA_VERSION_TAG = R1_5a_fix`**,
> **`EA_BUILD_TAG = ProofProtectionEngineFix`**.

---

## 0. Build

`metaeditor64.exe /compile:JA_FalconCore_Automated_Trading_Platform.mq5`
→ **`Result: 0 errors, 0 warnings`** (X64 Regular). Re-verified at phase close.

---

## 1. What was built (Phase 3a, end-to-end)

The first real trade-management engine, fully wired from contract to broker:

| Layer | File | Role |
|---|---|---|
| Engine contract | `TradeManagement/FalconTradeEngineContract.mqh` | `CFalconTradeEngine` interface + `FalconManagedPositionContext` (broker-truth context, **+ `structural_stop_price`** from R1.5a-fix) + decision struct |
| Coordinator + apply path | `TradeManagement/FalconTradeManagementCoordinator.mqh` | Per closed M5 bar: walks Falcon-magic positions, builds context, calls each engine, **applies** the decision. `FALCON_TM_MODIFY_SL` issues a real `TRADE_ACTION_SLTP` modify; `NO_ACTION` touches nothing; CLOSE / PARTIAL_CLOSE = `UNSUPPORTED_DECISION_NO_APPLY_PATH` (3b/3c) |
| Engine | `TradeManagement/Engines/FalconProofProtectionEngine.mqh` | Thin engine; owns no maths; forwards to an injected `CFalconProtectionPolicy` |
| Policy contract | `TradeManagement/Engines/FalconProtectionPolicyContract.mqh` | Swappable protection-policy interface |
| Policy | `TradeManagement/Engines/FalconFixedRMultipleProtection.mqh` | FixedRMultiple: arms once at `Trigger × R`, moves stop to `entry ∓ offset`, one-direction guard |
| **R1.5a-fix** | `TradeManagement/FalconStructuralStopRegistry.mqh` | `position_ticket → structural_stop_price` registry — carries the strategy's structural stop from the entry bridge to the coordinator |

### The R1.5a-fix correction (why the engine never armed in R1.5a)

R1.5a sized risk as `R = |entry − current_sl|`, but `current_sl` on a Falcon
position is the **wide LOCK-parity emergency envelope** (`emergency_server_sl`
in `Execution/FalconBrokerEntryBridge.mqh`, ~3× structural distance / USD-capped),
**not** the strategy's `S01_StopBuffer = 30`-point structural stop. That inflated
`R` 30–500×, so `Trigger × R` was essentially never reached before the structural
TP closed the trade — the engine was structurally unable to arm (`BrokerModifySent = 0`,
`CurrentSL` flat, broker net identical to protection-OFF). This was the headline
R1.5a finding (backlog #76).

The fix makes the engine context **hybrid** — broker-truth for outputs, strategy
intent for risk:

1. Added `double structural_stop_price` to `FalconManagedPositionContext`.
2. The entry bridge records the S01 structural stop (`record.structural_sl`,
   already known at entry — read only, **not** recomputed) into
   `g_structural_stop_registry` the moment the broker position opens; cleared in
   `MarkLinkClosed` when it closes. (Additive bookkeeping — no entry/exit logic
   changed.)
3. The coordinator fills `ctx.structural_stop_price` from the registry by ticket;
   an unknown position is left `0.0`.
4. `CFalconFixedRMultipleProtection::EvaluateProtection` now sizes
   `R = |broker_entry_price − ctx.structural_stop_price|`. Safety guard: with
   `structural_stop_price == 0.0` or a non-sensical `R`, the policy returns
   `NO_ACTION` with reason `"no structural stop in context - protection disarmed"` —
   it never arms off a missing input.

**Unchanged (strict spec constraints honoured):** arming rule (`Trigger × R`, min
clamped to 1.0R), stop destination (`entry ∓ offset`), thresholds, one-direction
guard, `CFalconTradeEngine` / `CFalconProtectionPolicy` signatures, the inputs
(`Enable_S01_Protection`, `Protection_TriggerRMultiple`, `Protection_StopOffsetPoints` —
none added), the emergency envelope, and the S01 / bridge entry-exit logic,
`Risk/FalconRiskLifecycleProcessor.mqh`, and the Apply* chain.

---

## 2. The engine is automatically PROVEN

With R sized from the structural stop, the mechanism works exactly as specified
and was verified on broker numbers:

- **It arms.** `FALCON_TM_MODIFY_SL` decisions appear once a position reaches
  `Trigger × R`, with realistic `R` (tens of points, not thousands).
- **It issues a real broker modify.** `AppliedAction = SL_MODIFIED`,
  `BrokerModifySent > 0` (see §4 caveat on the *Summary* counter).
- **The one-direction guard holds.** `CurrentSL` moves toward entry inside an
  armed trade and never walks back; the policy fires once per position
  (idempotent thereafter).
- **R is computed from `structural_stop_price`**, not the emergency envelope.
- **Fully deterministic** — re-running reproduces the same decisions.

---

## 3. Profitability verdict (value sweep)

Value sweep over **4 months** (`2026.02.01 → 2026.05.25`, deposit `$1000`),
S01 harness, US100_Spot M5:

| Config | Total `BrokerActualNetUSD` |
|---|---|
| Protection **OFF** | **−145.07** |
| trigger 1.5R | −161.30 |
| trigger 2.0R | −223.61 |

No value among 1.0 / 1.5 / 2.0R beats OFF; tighter/looser arming only gives back
more. The months **contradict each other** — no setting is stable across the
window.

**Judgment:** the engine is *mechanically* proven (it arms, modifies the broker
stop for real, the one-direction guard is intact, R is sized correctly). Its
*profitability* value is **not judgeable on this harness** — S01 is a deterministic
harness with no real edge, so there is no profit signal for protection to protect.
The profitability question is **deferred to re-evaluation on a real, edge-having
strategy** (backlog). **`Enable_S01_Protection` remains `false` by default**, so
the layer is inert at the baseline and `BrokerActualNetUSD` for a protection-OFF
run is unchanged.

---

## 4. Known limitation surfaced this phase (logged, not fixed here)

`Summary.csv`'s `BrokerModifySent` and `RuntimeSLChanged` counters stay `0` even
though the coordinator issues **real** `TRADE_ACTION_SLTP` modifies (visible as
`SL_MODIFIED` in `TradeManagementCoordinatorAudit.csv`). The Summary counters are
blind to the coordinator's apply path — they were instrumented for the legacy
bridge, not the 2b/3a coordinator. The audit CSV is the truth for "did the engine
modify a stop." This must be wired before the 3b/3c engines land. Logged as a
backlog defect — **not fixed in this commit** (no cleanup this phase).

---

## 5. Deviation note

The spec's disarm reason uses an em-dash (`—`). The MQL sources are pure ASCII
(no BOM); writing a non-ASCII byte into them would render as garbage in the CSV
under MetaEditor's codepage. I used an ASCII hyphen instead:
`"no structural stop in context - protection disarmed"`. One-glyph cosmetic
deviation in a debug reason string; all words and meaning preserved. No
acceptance criterion keys on the literal.

---

## 6. Files in this commit

**Code (R1.5a + R1.5a-fix):**
- `Core/FalconConstants.mqh` — `EA_VERSION_TAG → R1_5a_fix`, `EA_BUILD_TAG → ProofProtectionEngineFix`
- `JA_FalconCore_Automated_Trading_Platform.mq5` — include the registry before the bridge; engine registration (protection registered only when `Enable_S01_Protection` is on)
- `Execution/FalconBrokerEntryBridge.mqh` — record structural stop at S01 entry-accept; clear in `MarkLinkClosed` (additive only)
- `TradeManagement/FalconTradeEngineContract.mqh` — `+ structural_stop_price`
- `TradeManagement/FalconTradeManagementCoordinator.mqh` — fill context from registry; MODIFY_SL apply path
- `TradeManagement/FalconTradeManagementInputs.mqh` — protection inputs (R1.5a)
- `TradeManagement/FalconStructuralStopRegistry.mqh` — **new**
- `TradeManagement/Engines/FalconProtectionPolicyContract.mqh`, `FalconFixedRMultipleProtection.mqh`, `FalconProofProtectionEngine.mqh` — **new**

**Docs:**
- `Docs/ReviewNotes/R1_5a_fix_Review_Notes.md` (this file)
- `Docs/ProjectMemory/JA_FalconCore_Project_Memory_R1_5a_fix.md`
- `Docs/Ideas_Backlog.md` (#76 marked implemented; #77, #78 added in the fix; #79–#81 added at phase close)
- `JA_FalconCore_SPEC_R1_5a_fix_StructuralStopInContext.md` (phase artifact)

---

## 7. Problems panel

Compile log: `0 errors, 0 warnings`. No new diagnostics introduced by this phase.
The pre-existing accepted debts (`ReportIntegrityStatus = FAIL`,
`paper_state_snapshot` invariant — backlog #68/#69) are unchanged and out of scope.

---

## 8. Status

- **Phase 3a (protection engine): CLOSED** — mechanically proven, profitability
  deferred to a real strategy.
- **Phase 2 (trade-management coordinator spine + apply path): COMPLETE.**
- **Next step:** an independent input-surface + temporary-diagnostic-report
  **cleanup phase** (read-only death-analysis first, never mixed with a build),
  then a **real, edge-having strategy** on which protection profitability can
  actually be judged.
