//+------------------------------------------------------------------+
//| Execution/FalconExecutionInputs.mqh                              |
//| R0.4: preprocessor constants the Execution layer (especially     |
//| CFalconBrokerEntryBridge) depends on. Moved verbatim from main   |
//| .mq5 so they are visible BEFORE the Execution class .mqh files   |
//| are included.                                                    |
//|                                                                  |
//| Section 1: v0.56.8 broker execution layer (main .mq5 L102-150)   |
//| Section 2: FC_MAGIC_FVG_MICRO (main .mq5 L846)                   |
//| Section 3: DLM Bridge constants  (main .mq5 L1749-1750)          |
//+------------------------------------------------------------------+
#ifndef FALCON_EXECUTION_INPUTS_MQH
#define FALCON_EXECUTION_INPUTS_MQH

// --- Section 1: Broker execution layer constants (main .mq5 L102-150) ---
// v0.56.8: Controlled Tester-Only Managed Protection/Runner Execution Bridge + Pre-Entry Broker Lot Authority + Structural SL Risk Guard.
// v0.56.3a and v0.56.3b proved that entry-only broker orders are unsafe:
// server-side SL contaminated Paper/DynamicLot in 3a; no-server-stops created
// orphan positions and netting/opposite-order close risk in 3b. v0.56.4a/b proved
// exit observation, but reports showed DynamicLot broker orders still used fixed
// shadow lots and some StructuralSL distances were too large for safe atomic use.
// Therefore broker lot authority is evaluated before OrderSend for FixedLot and DynamicLot. v0.56.9b restores the no-naked-order safety invariant: broker/tester orders must attach server StructuralSL and selected TP3 safety cap. Paper final lifecycle close remains observed/managed when the broker position is still open, but no OrderSend is allowed with empty SL/TP. This is not Demo/Live permission.
#define FALCON_BEEB_STATUS                            "LOCK_PARITY_MANAGED_LIFECYCLE_BRIDGE"
#define FALCON_BEEB_DECISION                          "TESTER_ONLY_ORDER_REQUIRES_NONZERO_EMERGENCY_SERVER_SL_TP_ENVELOPE_NO_NAKED_ORDER_GUARD"
#define FALCON_BEEB_TESTER_ONLY_POLICY                "MQL_TESTER_REQUIRED_ENABLE_REAL_EXECUTION_REQUIRED_LIVE_BLOCKED_DEMO_BLOCKED"
#define FALCON_BEEB_ENTRY_DISABLED_STATUS             "ATOMIC_ENTRY_EXIT_BRIDGE_DISABLED_OR_PLAN_INVALID"
#define FALCON_BEEB_ENTRY_ACCEPTED_STATUS             "ATOMIC_ENTRY_EXIT_ACCEPTED_LINKED_POSITION_TESTER_ONLY"
#define FALCON_BEEB_ENTRY_BLOCKED_STATUS              "ATOMIC_ENTRY_EXIT_BLOCKED_BY_GUARD_POSITION_DISCIPLINE_OR_INVALID_PLAN"
#define FALCON_BEEB_NO_BROKER_CLOSE_STATUS            "EMERGENCY_SERVER_SL_TP_ENVELOPE_ATTACHED_WAIT_FOR_PAPER_FINAL_MANAGED_CLOSE_OR_FAILSAFE_EXIT"
#define FALCON_BEEB_ORDER_COMMENT                     "JAFC569B"
#define FALCON_BEEB_MAX_OPEN_POSITIONS_PER_ENGINE     1
#define FALCON_BEEB_MANAGED_EXIT_BRIDGE_READY          true
#define FALCON_BEEB_DYNAMIC_BROKER_LOT_ALLOWED          true
#define FALCON_BEEB_MAX_STRUCTURAL_SL_PRICE_DISTANCE    100.0
#define FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD          25.0
#define FALCON_BLA_STATUS                               "PRE_ENTRY_BROKER_LOT_AUTHORITY"
#define FALCON_BLA_DECISION                             "BROKER_LOT_COMPUTED_BEFORE_ORDERSEND_FIXED_AND_DYNAMIC"
#define FALCON_BLA_FIXED_MODE_STATUS                    "FIXED_LOT_REQUEST_VALIDATED_PREENTRY"
#define FALCON_BLA_DYNAMIC_MODE_STATUS                  "DYNAMIC_LOT_COMPUTED_PREENTRY_FROM_CAPITAL_RISK_SL_AND_BROKER_CONSTRAINTS"
#define FALCON_BLA_MAX_MARGIN_USE_PCT                   85.0
#define FALCON_BPR_STATUS                               "PROTECTION_RUNNER_BROKER_EVENT_BRIDGE_FOUNDATION"
#define FALCON_BPR_DECISION                             "TP1_AND_TP2_ARE_PROOF_CHECKPOINTS_NOT_DEFAULT_FULL_BROKER_CLOSE"
#define FALCON_BPR_INITIAL_SERVER_TP_POLICY              "EMERGENCY_TP_ENVELOPE_ONLY_MANAGED_RUNNER_EXIT_BRIDGE_FOUNDATION_NO_BROKERMODIFY_YET"
#define FALCON_MREB_STATUS                            "EA_MANAGED_PROTECTION_RUNNER_DECISION_BRIDGE_FOUNDATION"
#define FALCON_MREB_DECISION_POLICY                   "CONTROLLED_TESTER_ONLY_PAPER_FINAL_MANAGED_CLOSE_WITH_EMERGENCY_SERVER_SL_TP_ENVELOPE_NO_NAKED_ORDER"
#define FALCON_MREB_RUNTIME_MANAGED_CLOSE_READY        true
#define FALCON_BPR_PROTECTION_RUNNER_RUNTIME_POLICY      "TESTER_ONLY_EA_MANAGED_POSITIONCLOSE_AT_PAPER_FINAL_WITH_EMERGENCY_SERVER_SL_TP_ENVELOPE_NO_RUNTIME_SL_CHANGE_NO_BROKERMODIFY"
#define FALCON_MREB_CLOSE_COMMENT_PREFIX              "JAFC569BMC"
// v0.57.2: Virtual Trailing Exit Bridge - tester-only reverse-deal close tag.
#define FALCON_VIRTUAL_TRAILING_CLOSE_COMMENT_PREFIX  "JAFC572VT"
#define FALCON_VIRTUAL_TRAILING_EXIT_LIFECYCLE_REPORT_NAME "VirtualTrailingExitLifecycle"
// v0.57.3: extra safety margin above the spread when locking breakeven so a
// BUY closes on Bid (or SELL on Ask) at >= entry rather than at -spread.
#define FALCON_VIRTUAL_TRAILING_BE_EXTRA_POINTS       2.0
#define FALCON_LOCK_PARITY_TESTER_MANAGED_LIFECYCLE_PROBE true
#define FALCON_LOCK_PARITY_ATTACH_SERVER_SL_TP           true
#define FALCON_LOCK_PARITY_SERVER_STOP_POLICY            "SERVER_EMERGENCY_ENVELOPE_SL_TP_ATTACHED_VIRTUAL_STRUCTURAL_MANAGED_CLOSE_PROBE_NO_NAKED_ORDER_GUARD"
#define FALCON_LOCK_PARITY_EMERGENCY_SL_DISTANCE_MULTIPLIER 3.0
#define FALCON_LOCK_PARITY_EMERGENCY_TP_DISTANCE_MULTIPLIER 2.0
#define FALCON_LOCK_PARITY_MIN_EMERGENCY_SL_PRICE_DISTANCE 25.0
#define FALCON_LOCK_PARITY_MAX_EMERGENCY_SL_PRICE_DISTANCE 300.0
#define FALCON_LOCK_PARITY_MIN_EMERGENCY_TP_PRICE_DISTANCE 25.0
#define FALCON_LOCK_PARITY_MAX_EMERGENCY_TP_PRICE_DISTANCE 500.0
#define FALCON_LOCK_PARITY_MAX_EMERGENCY_SL_LOSS_USD       75.0

// --- Section 2: FVG Micro engine magic number (main .mq5 L845) ---
#define FC_MAGIC_FVG_MICRO                             1100001

// --- Section 3: Dynamic Lot Sizing Bridge constants (main .mq5 L1749-1750) ---
#define FALCON_DLM_CAPITAL_USD_PER_001_LOT        250.0
#define FALCON_DLM_MAX_LOT_GROWTH_MULTIPLIER      1.20

#endif // FALCON_EXECUTION_INPUTS_MQH
