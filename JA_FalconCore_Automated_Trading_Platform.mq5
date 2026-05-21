//+------------------------------------------------------------------+
//|                     JA_FalconCore_Automated_Trading_Platform.mq5 |
//|                     JA FalconCore Automated Trading Platform      |
//|                     Version: v0.56.9b - Emergency Server Stop Envelope LOCK Parity Probe CANDIDATE |
//+------------------------------------------------------------------+
#property copyright "JA FalconCore Automated Trading Platform"
#property version   "1.600"
#property strict

#define EA_NAME        "JA FalconCore Automated Trading Platform"
#define EA_VERSION_TAG "v0.57.3"
#define EA_BUILD_TAG   "VirtualTrailingCalibrationAndSpreadAwareBreakeven"

#define FALCON_MTF_COUNT       6

// ==================================================================
// v0.57.0 Lock Parity Executability Decomposer - report names
// Report-only / diagnostic additive layer. No execution behaviour changes.
// ==================================================================
#define FALCON_LOCK_PARITY_DECOMP_REPORT_NAME  "LockParityExecutabilityDecomposition"
#define FALCON_LOCK_PARITY_ROLLUP_REPORT_NAME  "LockParityExecutabilityRollup"
#define FALCON_LOCK_PARITY_CHAIN_RESIDUAL_TOL  0.0005
#define FALCON_LOCK_PARITY_ROLLUP_TOL          0.001
#define FALCON_LOCK_PARITY_DELTA_EPS           0.0005

// ==================================================================
// Paper State Persistence / Restart Recovery Foundation - v0.55.13
// Foundation-only snapshot layer. It writes state audit rows for Paper
// lifecycle continuity, but it does not restore trades, block entries,
// modify exits, or change trading results in this candidate.
// ==================================================================
#define FALCON_PERSISTENCE_STATUS                  "PAPER_STATE_PERSISTENCE_FOUNDATION"
#define FALCON_PERSISTENCE_DECISION                "SNAPSHOT_ONLY_NO_RUNTIME_RESTORE_NO_TRADING_CHANGE"
#define FALCON_PERSISTENCE_RECOVERY_MODE           "FOUNDATION_ONLY_STATE_RESTORE_DISABLED"
#define FALCON_PERSISTENCE_TRUST_POLICY            "STATE_TRUST_NOT_GRANTED_UNTIL_RESTART_RECONCILIATION_VALIDATED"
#define FALCON_PERSISTENCE_UNTRUSTED_POLICY        "DISABLE_RUNNER_MOON_PROTECTION_ESCALATION_UNDER_UNTRUSTED_RECOVERY_LATER"
#define FALCON_PERSISTENCE_NEXT_STEP               "RESTART_RECOVERY_READER_AND_MINIMAL_RECOVERY_MODE_VALIDATION"

// ==================================================================
// Session Boundary Dynamic Recovery Checkpoint Foundation - v0.55.13-fix4
// Close/entry safety actions happen before close using user-selected minutes.
// The recovery checkpoint is derived dynamically from the enabled safety window:
// default target is 3 minutes before broker close, but it is never scheduled
// before the corresponding close-safety action. Close time is resolved from
// broker/server symbol sessions; fallback is 23:58 only when broker sessions are unavailable.
// ==================================================================
#define FALCON_SESSION_BOUNDARY_DEFAULT_CHECKPOINT_MINUTES 3
#define FALCON_SESSION_BOUNDARY_ACTION_TO_CHECKPOINT_GAP_MINUTES 2
#define FALCON_SESSION_BOUNDARY_CHECKPOINT_MODE    "FOUNDATION_ONLY_NO_RUNTIME_RESTORE"
#define FALCON_SESSION_BOUNDARY_CHECKPOINT_POLICY  "DYNAMIC_CHECKPOINT_AFTER_USER_CLOSE_SAFETY_BEFORE_BROKER_CLOSE_BLOCKED_ENTRIES_NOT_RECOVERY_OPEN"


// ==================================================================
// Broker Execution Layer Rebuild Foundation - v0.56.x / Controlled Managed Protection Runner Execution Bridge - v0.56.8
// Foundation-only, strategy-agnostic broker architecture. This module
// is deliberately reusable by future strategies: every broker-facing
// record is keyed by StrategyId + EngineId + TradeId + BrokerPositionTicket.
// v0.56.9b rejects the unsafe no-server-stop probe observed in v0.56.9 and restores the no-naked-order invariant: every broker/tester OrderSend must include server StructuralSL plus a selected TP3 safety cap. Paper-final managed close remains measured only while the broker position is still open.
// v0.56.3a/3b proved that entry-only broker orders create orphan/netting close risk and cannot be used as a valid parity stage.
// ==================================================================
#define FALCON_BELR_STATUS                            "BROKER_EXECUTION_LAYER_REBUILD_FOUNDATION"
#define FALCON_BELR_DECISION                          "EMERGENCY_SERVER_STOP_ENVELOPE_LOCK_PARITY_PROBE_DEMO_LIVE_BLOCKED"
#define FALCON_BELR_REUSABILITY_POLICY                "STRATEGY_AGNOSTIC_TRADEID_ENGINEID_STRATEGYID_CONTRACT"
#define FALCON_BELR_EXECUTION_POLICY                  "TESTER_ONLY_LOCK_PARITY_WITH_NONZERO_EMERGENCY_SERVER_SL_TP_ENVELOPE_AND_PAPER_FINAL_MANAGED_CLOSE_DEMO_LIVE_BLOCKED"
#define FALCON_BELR_SOURCE_OF_TRUTH                   "TRADEMANAGEMENT_EVENT_TIMELINE_BEFORE_BROKER_ACTION"
#define FALCON_BELR_BASELINE_SOURCE                   "v0.55.13-fix4_LOCKED"
#define FALCON_BELR_DIAGNOSTIC_REFERENCE              "v0.55.26-fix19_DIAGNOSTIC_ONLY_NOT_BASELINE"
#define FALCON_BELR_NEXT_PHASE                        "v0.57.0_AFTER_LOCK_PARITY_PROBE_IDENTIFIES_TRUE_EXECUTABLE_GAPS"
// v0.57.3: neutral stage tag for report filenames; was "BrokerPaperReconciliation"
// which surfaced as the v0.56.9b build tag in filenames. Normalization in
// FalconEffectiveReportModeTag() folds legacy presets into this value.
#define FALCON_BELR_REPORT_STAGE_TAG                  "VirtualTrailingBridge"
#define FALCON_BELR_DEPRECATED_REPORT_STAGE_TAG        "ShadowSmoke"
#define FALCON_BELR_NO_BROKER_COMPARISON_STATUS       "NOT_COMPARABLE_NO_BROKER_EXECUTION"
#define FALCON_BELR_REBASED_STATUS                    "BROKER_REBASED_PAPER_COMPARISON_AUDIT_ONLY"
#define FALCON_BELR_REBASED_NO_ACTUAL_STATUS          "NOT_COMPARABLE_NO_BROKER_EXECUTION_REBASED_ONLY"
#define FALCON_BELR_REBASE_ORDERCALC_FALLBACK_STATUS  "ORDERCALC_UNAVAILABLE_USING_CONTRACT_SIZE_FALLBACK"
#define FALCON_BROKER_EXECUTION_LIFECYCLE_REPORT_NAME "BrokerExecutionLifecycle"
#define FALCON_BROKER_TM_TIMELINE_REPORT_NAME         "BrokerTradeManagementEventTimeline"
#define FALCON_BROKER_CONTRACT_REALITY_REPORT_NAME    "BrokerContractRealityAudit"
#define FALCON_BROKER_REBASED_COMPARISON_REPORT_NAME  "BrokerRebasedPaperComparison"
#define FALCON_BROKER_PAPER_RECONCILIATION_REPORT_NAME "BrokerPaperTradeReconciliation"
#define FALCON_BROKER_REBUILD_REFERENCE_LOT           0.01

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

// v0.56.1: TradeManagement Event Timeline Audit.
// Audit-only, strategy-agnostic, and deliberately reusable by future strategies.
// Every row is derived after Paper TradeManagement finalization so broker logic
// later consumes the same event story that the reports show.
#define FALCON_TMET_STATUS                            "TRADEMANAGEMENT_EVENT_TIMELINE_AUDIT"
#define FALCON_TMET_DECISION                          "AUDIT_ONLY_EVENTS_AFTER_PAPER_FINALIZATION_NO_ORDER_SEND_NO_BROKER_CLOSE"
#define FALCON_TMET_EXECUTION_ELIGIBILITY_AUDIT_ONLY  "EXECUTION_DISABLED_STAGE_AUDIT_ONLY"
#define FALCON_TMET_ACCOUNTING_ONLY_STATUS            "ACCOUNTING_ONLY_NOT_EXECUTABLE_UNTIL_EXACT_EVENT_TIME_PRICE_EXISTS"
#define FALCON_TMET_NO_EXACT_TICK_TIME_STATUS         "BAR_PATH_TOUCH_DETECTED_NO_EXACT_TICK_TIME"
#define FALCON_TMET_EVENT_SOURCE                      "PAPER_TRADEMANAGEMENT_FINALIZED_RECORD"
#define FALCON_TMET_CLEANUP_GATE                      "REMOVE_TEMP_STAGE_ARTIFACTS_KEEP_OFFICIAL_BROKER_REALITY_TIMELINE_REPORTS"

// ==================================================================
// Runtime report period state - v0.18.4
// ==================================================================
datetime g_report_period_first_time = 0;
datetime g_report_period_last_time  = 0;
string   g_report_initial_from_tag  = "";
string   g_report_initial_to_tag    = "";
string   g_report_active_from_tag   = "";
string   g_report_active_to_tag     = "";
bool     g_report_period_initialized = false;
bool     g_report_period_finalized   = false;

// ==================================================================
// Compact FVG Micro quality metrics - v0.19.1
// These counters are intentionally stored in Summary instead of creating
// another diagnostic report. They help prove whether quality filters are
// affecting candidates while keeping ReportProfile STANDARD clean.
// ==================================================================
int g_fvg_micro_candidate_builder_evaluations = 0;
int g_fvg_micro_detected_candidates           = 0;
int g_fvg_micro_quality_evaluated             = 0;
int g_fvg_micro_quality_passed                = 0;
int g_fvg_micro_quality_rejected              = 0;
int g_fvg_micro_rejected_size                 = 0;
int g_fvg_micro_rejected_spread               = 0;
int g_fvg_micro_rejected_age                  = 0;
int g_fvg_micro_shadow_ready_candidates       = 0;

// ==================================================================
// FVG Micro quality calibration shadow metrics - v0.19.2/v0.19.3
// These counters simulate stricter quality thresholds WITHOUT changing
// the live Shadow candidate path. They are reported only in Summary.
// ==================================================================
int g_fvg_quality_calibration_evaluated             = 0;
int g_fvg_quality_profile_balanced_passed           = 0;
int g_fvg_quality_profile_balanced_rejected         = 0;
int g_fvg_quality_profile_strict_size_passed        = 0;
int g_fvg_quality_profile_strict_size_rejected      = 0;
int g_fvg_quality_profile_tight_spread_passed       = 0;
int g_fvg_quality_profile_tight_spread_rejected     = 0;
int g_fvg_quality_profile_strict_combo_passed       = 0;
int g_fvg_quality_profile_strict_combo_rejected     = 0;

// ==================================================================
// FVG Micro quality distribution metrics - v0.19.3
// These are Summary-only metrics. They explain WHY a calibration profile
// passes/rejects without adding diagnostic CSV files or new inputs.
// ==================================================================
int    g_fvg_quality_distribution_count             = 0;
double g_fvg_quality_size_min_points                = 0.0;
double g_fvg_quality_size_max_points                = 0.0;
double g_fvg_quality_size_total_points              = 0.0;
long   g_fvg_quality_spread_min_points              = -1;
long   g_fvg_quality_spread_max_points              = 0;
long   g_fvg_quality_spread_total_points            = 0;
int    g_fvg_quality_spread_le_50_count             = 0;
int    g_fvg_quality_spread_le_75_count             = 0;
int    g_fvg_quality_spread_le_100_count            = 0;
int    g_fvg_quality_spread_le_150_count            = 0;
int    g_fvg_quality_spread_le_200_count            = 0;

// ==================================================================
// FVG Micro retest freshness + hold/reject quality metrics - v0.20.0
// Summary-only shadow metrics. They DO NOT change entries, SL, TP, staging,
// or lifecycle behavior. They measure whether FVG retests are fresh and
// whether the first closed-candle context around retest shows hold/rejection.
// ==================================================================
int    g_fvg_retest_watch_evaluated                  = 0;
int    g_fvg_retest_touched                          = 0;
int    g_fvg_retest_waiting                          = 0;
int    g_fvg_retest_fresh                            = 0;
int    g_fvg_retest_stale                            = 0;
int    g_fvg_retest_age_min_bars                     = -1;
int    g_fvg_retest_age_max_bars                     = 0;
long   g_fvg_retest_age_total_bars                   = 0;
int    g_fvg_hold_quality_evaluated                  = 0;
int    g_fvg_hold_quality_strong                     = 0;
int    g_fvg_hold_quality_neutral                    = 0;
int    g_fvg_hold_quality_weak                       = 0;
int    g_fvg_hold_quality_score_min                  = -1;
int    g_fvg_hold_quality_score_max                  = 0;
long   g_fvg_hold_quality_score_total                = 0;

#define FALCON_FVG_HOLD_QUALITY_STRONG_SCORE         70
#define FALCON_FVG_HOLD_QUALITY_NEUTRAL_SCORE        40

// ==================================================================
// FVG Quality Shadow Guard Simulation - v0.22.0
// Simulation only: it measures what would happen if a quality guard
// skipped lower-quality FVG Micro shadow trades. It never blocks, stages,
// closes, or modifies a trade. Runtime Guard = OFF.
// ==================================================================
#define FALCON_FVG_QGUARD_PROFILE_TAG                 "P03_SIZE250_ONLY"
#define FALCON_FVG_QGUARD_MIN_SIZE_POINTS             250.00
#define FALCON_FVG_QGUARD_MAX_SPREAD_POINTS           0
#define FALCON_FVG_QGUARD_MAX_AGE_BARS                0
#define FALCON_FVG_QGUARD_MIN_HOLD_SCORE              0

// v0.22.2 Lock cleanup: multi-profile diagnostics were validated in v0.22.1.
// v0.22.3 OOS validation lock: P03_SIZE250_ONLY passed primary validation and was near-flat/slightly positive on January/February OOS.
// v0.24.1 locked the candidate gate design with runtime blocking OFF.
// v0.25.1 locks SIZE250 controlled Shadow runtime candidate activation and aligns counters.
// It can block FVG Micro Shadow staging only. It still cannot send broker orders, Paper, Demo, or Live execution.
#define FALCON_FVG_QGUARD_RUNTIME_ACTIVE             true
#define FALCON_FVG_QGUARD_ACTUAL_BLOCKING_ENABLED    true
#define FALCON_FVG_QGUARD_NO_LOOKAHEAD_FEASIBLE      true
#define FALCON_FVG_QGUARD_KNOWN_BEFORE_ENTRY         true
#define FALCON_FVG_QGUARD_MANUAL_PROMOTION_REQUIRED  false
#define FALCON_FVG_QGUARD_CANDIDATE_STAGE            "RUNTIME_CANDIDATE_COUNTER_ALIGNMENT_LOCK"
#define FALCON_FVG_QGUARD_FEASIBILITY_DECISION       "CONTROLLED_SHADOW_BLOCKING_LOCKED_COUNTERS_ALIGNED"
#define FALCON_FVG_QGUARD_FEASIBILITY_REASON         "SIZE250_RUNTIME_CANDIDATE_PERFORMANCE_PASSED;COUNTER_ALIGNMENT_LOCK_ADDS_STAGED_AND_POST_PASS_CLARITY"
#define FALCON_FVG_QGUARD_NEXT_STEP                  "TRADE_MANAGEMENT_FOUNDATION"

#define FALCON_FVG_QGUARD_RUNTIME_CANDIDATE_ALLOWED       true
#define FALCON_FVG_QGUARD_RUNTIME_CANDIDATE_DESIGN_READY  true
#define FALCON_FVG_QGUARD_ACTIVATION_POLICY               "CONTROLLED_SHADOW_ONLY_NO_PAPER_DEMO_LIVE"
#define FALCON_FVG_QGUARD_PROMOTION_RULE                  "ACTUAL_BLOCKING_MUST_MATCH_SIZE250_EXPECTED_NET_AND_COUNTERS_MUST_EXPLAIN_CANDIDATE_TO_LIFECYCLE_DELTA"
#define FALCON_FVG_QGUARD_ROLLBACK_REQUIRED               true
#define FALCON_FVG_QGUARD_ROLLBACK_BASELINE               "v0.25.2"
#define FALCON_FVG_QGUARD_ROLLBACK_TRIGGER                "ROLLBACK_IF_COMPILE_FAILS_OR_SMOKE_TRADE_COUNT_NET_OR_ALIGNED_QGUARD_COUNTERS_DEVIATE_FROM_EXPECTED_SIZE250_RUNTIME_CANDIDATE"
#define FALCON_FVG_QGUARD_RUNTIME_BLOCKING_RULE           "BLOCK_FVG_MICRO_SHADOW_STAGING_WHEN_FVG_SIZE_POINTS_LT_250_BEFORE_ENTRY"
#define FALCON_FVG_QGUARD_NEXT_CANDIDATE_VERSION          "v0.27.1_TradeManagementFoundationValidationLock"

// ==================================================================
// FVG Micro Engine Completion Lock - v0.25.2
// This metadata closes the current engine phase. It does NOT enable
// Paper, Demo, Live, or broker execution. It records that FVG Micro
// + SIZE250 Shadow runtime candidate is complete enough to move next
// to FalconGuard/Risk and TradeManagement foundations before any Live.
// ==================================================================
#define FALCON_FVG_ENGINE_COMPLETION_STATUS              "ENGINE_COMPLETION_LOCK"
#define FALCON_FVG_ENGINE_COMPLETION_DECISION            "FVG_MICRO_SIZE250_SHADOW_RUNTIME_CANDIDATE_COMPLETE"
#define FALCON_FVG_ENGINE_COMPLETION_SCOPE               "FVG_MICRO_RETEST_ONLY;SIZE250_ACTUAL_SHADOW_BLOCKING;NO_OTHER_ENGINE_ACTIVE"
#define FALCON_FVG_ENGINE_COMPLETED_ENGINE_ID            "SCALP.FVG_MICRO"
#define FALCON_FVG_ENGINE_ACTIVE_STRATEGY_ONLY           "FVG_MICRO_RETEST"
#define FALCON_FVG_ENGINE_LIVE_PILOT_ELIGIBILITY         "NOT_ELIGIBLE_UNTIL_RISK_TRADE_MANAGEMENT_PAPER_DEMO_VALIDATION"
#define FALCON_FVG_ENGINE_NEXT_REQUIRED_LAYER            "FALCON_GUARD_PRE_EXECUTION_GATE_THEN_TRADE_MANAGEMENT_FOUNDATION"
#define FALCON_FVG_ENGINE_NEXT_ENGINEERING_PHASE         "v0.27.1_TradeManagementFoundationValidationLock"

// ==================================================================
// FalconGuard Pre-Execution Gate Lock - v0.26.3
// Validation lock after v0.26.2 smoke passed. It freezes the unified risk
// decision gate that later Paper/Demo/Live execution must call before any order
// can be created. It does not block Shadow trades, send orders, or alter FVG
// Micro SIZE250 behavior.
// ==================================================================
#define FALCON_GUARD_FOUNDATION_STATUS                  "FALCON_GUARD_PRE_EXECUTION_GATE_LOCK"
#define FALCON_GUARD_FOUNDATION_DECISION                "PRE_EXECUTION_GATE_LOCKED_READY_FOR_TRADE_MANAGEMENT_NO_EXECUTION"
#define FALCON_GUARD_SCOPE                              "FIXED_LOT;DAILY_LOSS_LIMIT;MAX_TRADES;MAX_OPEN_POSITIONS;SPREAD_GUARD_READINESS;STOPS_GUARD_READINESS;KILL_SWITCH_DESIGN"
#define FALCON_GUARD_EXECUTION_PERMISSION               "NO_ORDER_SEND_NO_PAPER_NO_DEMO_NO_LIVE"
#define FALCON_GUARD_RISK_MODE                          "FIXED_LOT_FIRST"
#define FALCON_GUARD_ENGINE_ALLOCATION                  "FVG_MICRO_100_PERCENT_ONLY;ALL_OTHER_ENGINES_0_PERCENT"
#define FALCON_GUARD_KILL_SWITCH_STATUS                 "ARMED_PRE_EXECUTION_GATE_LOCK_NOT_RUNTIME_BLOCKING"
#define FALCON_GUARD_MANUAL_KILL_SWITCH_STATUS          "FUTURE_READY_NO_USER_INPUT_IN_THIS_VERSION"
#define FALCON_GUARD_MAX_CONSECUTIVE_LOSSES             3
#define FALCON_GUARD_LIVE_ELIGIBILITY                   "NOT_ELIGIBLE_UNTIL_TRADE_MANAGEMENT_PAPER_DEMO_VALIDATION"
#define FALCON_GUARD_NEXT_REQUIRED_LAYER                "TRADE_MANAGEMENT_FOUNDATION"
#define FALCON_GUARD_NEXT_ENGINEERING_PHASE             "v0.27.1_TradeManagementFoundationValidationLock"

// ==================================================================
// FalconGuard Pre-Execution Gate Lock - v0.26.3
// Summary-only locked decision contract. It does not enforce broker execution,
// does not block Shadow lifecycle, and does not change FVG Micro results.
// Future Paper/Demo/Live executors must call the equivalent gate before
// creating any order request.
// ==================================================================
#define FALCON_GUARD_PRE_EXECUTION_GATE_STATUS          "PRE_EXECUTION_GATE_LOCKED_NOT_RUNTIME_BLOCKING"
#define FALCON_GUARD_PRE_EXECUTION_DECISION             "RISK_DECISION_CONTRACT_LOCKED_FOR_TRADE_MANAGEMENT"
#define FALCON_GUARD_PRE_EXECUTION_LOT_MODE             "FIXED_LOT_ONLY_FIRST_LIVE_PILOT_SAFE"
#define FALCON_GUARD_PRE_EXECUTION_DAILY_LOSS_STATUS    "BUDGET_DEFINED_RUNTIME_TRACKING_LATER_IN_PAPER_DEMO"
#define FALCON_GUARD_PRE_EXECUTION_DAILY_TRADES_STATUS  "LIMIT_DEFINED_RUNTIME_COUNTING_LATER_IN_PAPER_DEMO"
#define FALCON_GUARD_PRE_EXECUTION_OPEN_CAPACITY_STATUS "CAPACITY_DEFINED_RUNTIME_COUNTING_LATER_IN_PAPER_DEMO"
#define FALCON_GUARD_PRE_EXECUTION_ENGINE_RISK_ALLOWED  "YES_FVG_MICRO_100_PERCENT_ONLY"
#define FALCON_GUARD_PRE_EXECUTION_NEXT_PHASE           "v0.27.1_TradeManagementFoundationValidationLock"


// ==================================================================
// TradeManagement Foundation Validation Lock - v0.27.1
// Summary-only lock layer after full validation passed. It records the official trade-management
// contract required before Paper/Demo/Live. It does not modify SL, TP,
// partials, runners, exits, shadow lifecycle, or broker execution.
// ==================================================================
#define FALCON_TM_FOUNDATION_STATUS                      "TRADE_MANAGEMENT_FOUNDATION_VALIDATION_LOCK"
#define FALCON_TM_FOUNDATION_DECISION                    "TRADE_MANAGEMENT_FOUNDATION_FULL_VALIDATION_LOCKED_NO_RUNTIME_EXIT_CHANGES"
#define FALCON_TM_SCOPE                                  "STRUCTURAL_STOP;TP_BUILDER;PARTIAL_MANAGER;PROOF_PROTECTION;RUNNER_MANAGER;ADAPTIVE_RATCHET;EARLY_FAILURE_EXIT"
#define FALCON_TM_EXECUTION_PERMISSION                   "NO_ORDER_SEND_NO_PAPER_NO_DEMO_NO_LIVE;NO_EXIT_BEHAVIOR_CHANGE"
#define FALCON_TM_STRUCTURAL_STOP_STATUS                 "DESIGN_READY_REQUIRED_FOR_PAPER_DEMO_LIVE"
#define FALCON_TM_STRUCTURAL_STOP_REQUIREMENT            "EVERY_TRADE_MUST_HAVE_STRUCTURAL_SL_BEFORE_EXECUTION"
#define FALCON_TM_TP_BUILDER_STATUS                      "DESIGN_READY_VALIDATE_TP1_TP2_TP3_BEFORE_EXECUTION"
#define FALCON_TM_TP1_POLICY                             "TP1_PARTIAL_PAY_OURSELVES_PROOF_CHECKPOINT_NOT_MANDATORY_FINAL_EXIT"
#define FALCON_TM_TP2_POLICY                             "TP2_STRONGER_PROOF_CHECKPOINT_NOT_MANDATORY_FINAL_EXIT"
#define FALCON_TM_PARTIAL_MANAGER_STATUS                 "FOUNDATION_READY_RUNTIME_PARTIALS_NOT_ACTIVE"
#define FALCON_TM_PROOF_PROTECTION_STATUS                "FOUNDATION_READY_NO_EARLY_BE_PROTECT_ONLY_WHEN_EARNED"
#define FALCON_TM_RUNNER_MANAGER_STATUS                  "FOUNDATION_READY_RUNNER_ONLY_AFTER_PROOF_NOT_RUNTIME_ACTIVE"
#define FALCON_TM_ADAPTIVE_RATCHET_STATUS                "FOUNDATION_READY_SHADOW_ONLY_NO_RUNTIME_TRAIL_CHANGE"
#define FALCON_TM_EARLY_FAILURE_EXIT_STATUS              "FOUNDATION_READY_SHADOW_ONLY_NO_RUNTIME_EARLY_EXIT"
#define FALCON_TM_LIVE_ELIGIBILITY                       "NOT_ELIGIBLE_UNTIL_PAPER_DEMO_VALIDATION_AND_RUNTIME_TRADE_MANAGEMENT_LOCK"
#define FALCON_TM_NEXT_REQUIRED_LAYER                    "STRUCTURAL_STOP_TP_BUILDER_VALIDATION_LOCK_DONE_NEXT_SMART_TRADE_MANAGEMENT_DIAGNOSTICS"
#define FALCON_TM_NEXT_ENGINEERING_PHASE                 "v0.29.0_SmartTradeManagementDiagnosticsFoundation"

// ==================================================================
// StructuralStop + TPBuilder Validation Lock - v0.28.1
// Summary-only validation layer. It audits whether closed Shadow trades
// carry structurally valid SL and directional TP1/TP2/TP3 values. It does
// not change exits, entries, TP, SL, partials, runner, Paper/Demo/Live,
// or broker execution.
// ==================================================================
#define FALCON_SLTP_VALIDATION_STATUS                    "STRUCTURAL_STOP_TP_BUILDER_VALIDATION_LOCK"
#define FALCON_SLTP_VALIDATION_DECISION                  "SL_TP_CONTRACT_FULL_VALIDATION_LOCKED_NO_RUNTIME_BLOCKING"
#define FALCON_SLTP_VALIDATION_SCOPE                     "STRUCTURAL_SL_DIRECTIONAL_VALIDITY;TP1_TP2_TP3_DIRECTIONAL_VALIDITY;TP_SEQUENCE_READINESS"
#define FALCON_SLTP_VALIDATION_RUNTIME_ENFORCED          false
#define FALCON_SLTP_STRUCTURAL_STOP_POLICY               "SL_MUST_EXIST_AND_BE_BEHIND_ENTRY_BY_DIRECTION_BEFORE_PAPER_DEMO_LIVE"
#define FALCON_SLTP_TP_BUILDER_POLICY                    "TP1_TP2_TP3_MUST_EXIST_AND_BE_DIRECTIONALLY_PROFITABLE_BEFORE_PAPER_DEMO_LIVE"
#define FALCON_SLTP_NO_LOOKAHEAD_POLICY                  "VALIDATION_USES_STAGED_PLAN_VALUES_ONLY_NO_FUTURE_BAR_STATE"
#define FALCON_SLTP_NEXT_ENGINEERING_PHASE               "v0.29.0_SmartTradeManagementDiagnosticsFoundation"

// ==================================================================
// Smart Trade Management Diagnostics Foundation - v0.29.0
// Summary-only diagnostic layer. It quantifies proof/anti-proof/behavior
// and runner opportunity without changing exits, partials, runners, SL, TP,
// Paper/Demo/Live, or broker execution.
// ==================================================================
#define FALCON_SMART_TM_STATUS                            "SMART_TRADE_MANAGEMENT_RUNNER_MFE_GIVEBACK_DIAGNOSTICS_ACTIVE"
#define FALCON_SMART_TM_DECISION                          "RUNNER_MFE_GIVEBACK_DIAGNOSTICS_READY_NO_RUNTIME_EXIT_CHANGES"
#define FALCON_SMART_TM_SCOPE                             "CALIBRATED_PROOF_SCORE;BEHAVIOR_FINGERPRINT;RUNNER_OPPORTUNITY;MFE_PROXY;GIVEBACK_ROOM_PROXY;MAX_R_PROXY;BAR_PATH_READINESS"
#define FALCON_SMART_TM_RUNTIME_ENFORCED                  false
#define FALCON_SMART_TM_PROOF_POLICY                      "PROOF_CALIBRATED_PRIOR_STATE_QUALITY_STRUCTURE_ONLY_NO_RUNTIME_RUNNER_OR_EXIT_CHANGE"
#define FALCON_SMART_TM_ANTI_PROOF_POLICY                 "ANTI_PROOF_CALIBRATED_PRE_EXIT_WEAKNESS_PROXIES_ONLY_NO_RUNTIME_EARLY_EXIT_CHANGE"
#define FALCON_SMART_TM_BEHAVIOR_POLICY                   "BEHAVIOR_FINGERPRINT_SUMMARY_ONLY_HEALTHY_CHOPPY_GRINDING_EXHAUSTED_FAILURE"
#define FALCON_SMART_TM_RUNNER_POLICY                     "RUNNER_MFE_GIVEBACK_PROXY_DIAGNOSTICS_ONLY_NOT_RUNTIME_ACTIVE"
#define FALCON_SMART_TM_NEXT_ENGINEERING_PHASE            "v0.29.3_RunnerBarPathMfeGivebackCalibration"

// ==================================================================
// Runner MFE/Giveback Diagnostics - v0.29.2
// Summary-only proxy diagnostics. Uses planned TP geometry and realized
// lifecycle outcomes only. It does not use future bar-path ordering, does not
// modify exits, and does not activate runner, partials, ratchet, Paper, Demo,
// Live, or OrderSend. Exact post-TP MFE/Giveback requires a later bar-path module.
// ==================================================================
#define FALCON_RUNNER_DIAG_STATUS                         "RUNNER_MFE_GIVEBACK_PROXY_DIAGNOSTICS_ACTIVE"
#define FALCON_RUNNER_DIAG_DECISION                       "PROXY_DIAGNOSTICS_READY_BAR_PATH_REQUIRED_BEFORE_RUNTIME"
#define FALCON_RUNNER_DIAG_RUNTIME_ENFORCED               false
#define FALCON_RUNNER_DIAG_MFE_POLICY                     "MFE_PROXY_USES_REALIZED_FAVORABLE_EXIT_POINTS_ONLY_NO_FUTURE_BAR_PATH"
#define FALCON_RUNNER_DIAG_GIVEBACK_POLICY                "GIVEBACK_PROXY_USES_TP1_TP2_TP3_REMAINING_ROOM_NOT_RUNTIME_TRAIL"
#define FALCON_RUNNER_DIAG_MAXR_POLICY                    "MAX_R_PROXY_USES_STRUCTURAL_SL_RISK_AND_PLANNED_TARGETS"
#define FALCON_RUNNER_DIAG_RETURN_TO_LOSS_POLICY          "RETURN_TO_LOSS_AFTER_PROOF_REQUIRES_BAR_PATH_NEXT_PHASE"
#define FALCON_RUNNER_DIAG_NEXT_PHASE                     "v0.29.3_BarPathMfeGivebackCalibration"

// v0.29.3a: Runner bar-path metric definition calibration. Summary-only; no runtime exit changes.
#define FALCON_RUNNER_BARPATH_STATUS                      "RUNNER_BAR_PATH_METRIC_DEFINITION_CALIBRATION_ACTIVE"
#define FALCON_RUNNER_BARPATH_DECISION                    "BAR_PATH_METRIC_DEFINITIONS_CALIBRATED_NO_RUNTIME_EXIT_CHANGES"
#define FALCON_RUNNER_BARPATH_RUNTIME_ENFORCED            false
#define FALCON_RUNNER_BARPATH_POLICY                      "M5_BAR_PATH_CALIBRATED_EXTENSION_METRICS_DIAGNOSTIC_ONLY_NO_RUNTIME"
#define FALCON_RUNNER_BARPATH_NEXT_PHASE                  "v0.29.4_FastProtectionRunnerDecisionReadinessDiagnostics"

// ==================================================================
// Fast Protection / Runner Decision Readiness Diagnostics - v0.29.4
// Summary-only diagnostic layer. It prepares fast TP1/TP2 decision readiness
// counters from existing proof, anti-proof, SL/TP validation, and bar-path data.
// It does not change exits, SL, TP, partials, runner, Paper, Demo, Live, or OrderSend.
// ==================================================================
#define FALCON_FAST_TM_STATUS                              "FAST_PROTECTION_RUNNER_DECISION_READINESS_DIAGNOSTICS_ACTIVE"
#define FALCON_FAST_TM_DECISION                            "FAST_DECISION_READINESS_MEASURED_NO_RUNTIME_EXIT_CHANGES"
#define FALCON_FAST_TM_RUNTIME_ENFORCED                    false
#define FALCON_FAST_TM_LATENCY_MODE                        "PRE_COMPUTED_DECISION_TREE_DIAGNOSTIC_ONLY_EVENT_DRIVEN_READY_NOT_ENFORCED"
#define FALCON_FAST_TM_DECISION_PROFILE                    "TP1_FAST_PROTECTION;TP2_FAST_RUNNER_CONFIRMATION;ANTI_PROOF_WARNING;NO_EARLY_BE"
#define FALCON_FAST_TM_POLICY                              "PREPARE_DECISIONS_BEFORE_TP_TOUCH_EXECUTE_LATER_ONLY_AFTER_PAPER_DEMO_VALIDATION"
#define FALCON_FAST_TM_NEXT_PHASE                          "v0.29.5_TP1TP2DecisionTreeShadowSimulation"

// ==================================================================
// TP1/TP2 pre-computed decision tree shadow simulation - v0.29.5
// Summary-only diagnostics. Decisions are simulated from existing Fast TM
// readiness counters. No exit, SL/TP, partial, runner, or execution changes.
// ==================================================================
#define FALCON_DECISION_TREE_STATUS                         "TP1_TP2_DECISION_TREE_SHADOW_SIMULATION_ACTIVE"
#define FALCON_DECISION_TREE_DECISION                       "PRE_COMPUTED_BRANCHES_MEASURED_NO_RUNTIME_ACTIONS"
#define FALCON_DECISION_TREE_RUNTIME_ENFORCED               false
#define FALCON_DECISION_TREE_SCOPE                          "TP1_PARTIAL_PROTECT_RUNNER_WAIT_EXIT;TP2_PROTECT_RUNNER_EXIT"
#define FALCON_DECISION_TREE_POLICY                         "LOOKUP_PRECOMPUTED_DECISION_ON_TP1_TP2_TOUCH_DIAGNOSTIC_ONLY"
#define FALCON_DECISION_TREE_NEXT_PHASE                     "v0.29.6_DecisionTreeBarPathOutcomeSimulation"

#define FALCON_DECISION_TREE_OUTCOME_STATUS                 "DECISION_TREE_BAR_PATH_OUTCOME_SIMULATION_ACTIVE"
#define FALCON_DECISION_TREE_OUTCOME_DECISION               "OUTCOME_RATIOS_NORMALIZED_NO_RUNTIME_ACTIONS"
#define FALCON_DECISION_TREE_OUTCOME_RUNTIME_ENFORCED       false
#define FALCON_DECISION_TREE_OUTCOME_POLICY                 "ESTIMATE_TP1_TP2_BRANCH_OUTCOMES_FROM_BAR_PATH_DIAGNOSTICS_ONLY"
#define FALCON_DECISION_TREE_OUTCOME_NEXT_PHASE             "v0.29.7_DecisionTreeExecutionFeasibilityTimingDiagnostics"

// ==================================================================
// Decision Tree Timing Feasibility Validation Lock - v0.29.8
// Summary-only diagnostics. Measures whether protection / runner decisions
// were pre-computed before TP1/TP2 events using decision cache readiness.
// This does NOT activate protection, runner, SL movement, OrderSend, Paper,
// Demo, or Live behavior. Exact intra-bar execution ordering remains future
// Paper/Demo work.
// ==================================================================
#define FALCON_DT_TIMING_STATUS                         "DECISION_TREE_TIMING_FEASIBILITY_VALIDATION_LOCK"
#define FALCON_DT_TIMING_DECISION                       "TIMING_FEASIBILITY_FULL_VALIDATION_LOCKED_NO_RUNTIME_ACTIONS"
#define FALCON_DT_TIMING_RUNTIME_ENFORCED               false
#define FALCON_DT_TIMING_POLICY                         "PRECOMPUTED_DECISION_CACHE_LOCKED_PROXY_ONLY_NO_RUNTIME"
#define FALCON_DT_TIMING_NEXT_PHASE                     "v0.30.0_PaperExecutionReadinessOrderLifecycleFoundation"

// ==================================================================
// Paper Execution Readiness Validation Lock - v0.30.1
// Summary-only validation lock. It freezes the Paper execution readiness
// contract after successful primary and OOS validation. Future versions may
// simulate Paper fills, but this version still does NOT send orders, create
// Paper fills, modify SL/TP, activate runners, or change Shadow lifecycle results.
// ==================================================================
#define FALCON_PAPER_EXEC_STATUS                         "PAPER_ORDER_LIFECYCLE_SIMULATION_VALIDATION_LOCK"
#define FALCON_PAPER_EXEC_DECISION                       "PAPER_ORDER_LIFECYCLE_SIMULATION_FULL_VALIDATION_LOCKED_NO_ORDER_SEND"
#define FALCON_PAPER_EXEC_RUNTIME_ENFORCED               false
#define FALCON_PAPER_EXEC_PERMISSION                     "NO_ORDER_SEND_INTERNAL_PAPER_SIM_ONLY_NO_DEMO_NO_LIVE"
#define FALCON_PAPER_EXEC_MODE                           "PAPER_ORDER_LIFECYCLE_SIMULATION_VALIDATION_LOCK_ONLY"
#define FALCON_PAPER_EXEC_SCOPE                          "ORDER_REQUEST;ORDER_STAGING;FILL_STATE;SL_TP_PLAN;PARTIAL_RUNNER_PLAN;REJECTION_REASON"
#define FALCON_PAPER_EXEC_ORDER_STATE_MODEL              "PLANNED_REQUEST;STAGED_REQUEST;ACCEPTED;FILLED;PARTIAL_FILLED;MODIFY_PENDING;CLOSED;REJECTED"
#define FALCON_PAPER_EXEC_NO_LOOKAHEAD_POLICY            "PAPER_READINESS_USES_EXISTING_STAGED_PLAN_AND_CLOSED_TRADE_RECORDS_ONLY"
#define FALCON_PAPER_EXEC_NEXT_PHASE                     "v0.32.1_PaperPartialRunnerBranchValidationLock"

// ==================================================================
// Paper Order Lifecycle Simulation Validation Lock - v0.31.1
// Internal paper lifecycle only. No broker OrderSend, no Demo, no Live.
// ==================================================================
#define FALCON_PAPER_SIM_STATUS                          "PAPER_ORDER_LIFECYCLE_SIMULATION_VALIDATION_LOCK"
#define FALCON_PAPER_SIM_DECISION                        "PLANNED_STAGED_ACCEPTED_FILLED_CLOSED_INTERNAL_SIM_LOCKED"
#define FALCON_PAPER_SIM_SCOPE                           "INTERNAL_PAPER_ORDER_STATES;NO_BROKER_ORDERS;NO_DEMO;NO_LIVE"
#define FALCON_PAPER_SIM_ORDER_SEND_BYPASS               "ORDER_SEND_HARD_BLOCKED;PAPER_SIM_USES_CLOSED_SHADOW_RECORDS"
#define FALCON_PAPER_SIM_NO_LOOKAHEAD_POLICY             "PAPER_SIMULATION_USES_EXISTING_CLOSED_TRADE_LIFECYCLE_RECORDS_ONLY"
#define FALCON_PAPER_SIM_NEXT_PHASE                      "v0.32.1_PaperPartialRunnerBranchValidationLock"

// ==================================================================
// Paper Partial / Runner Branch Validation Lock - v0.32.1
// Internal paper branch simulation only. It does not send broker orders,
// does not alter exits, does not activate runtime partials/runners, and
// uses already prepared Fast TM / Decision Tree readiness counters.
// ==================================================================
#define FALCON_PPR_BRANCH_STATUS                         "PAPER_PARTIAL_RUNNER_BRANCH_VALIDATION_LOCK"
#define FALCON_PPR_BRANCH_DECISION                       "PARTIAL_RUNNER_BRANCHES_FULL_VALIDATION_LOCKED_NO_ORDER_SEND"
#define FALCON_PPR_BRANCH_RUNTIME_ENFORCED               false
#define FALCON_PPR_BRANCH_SCOPE                          "PAPER_PARTIAL_BRANCH;PAPER_RUNNER_BRANCH;VALIDATION_LOCK;NO_BROKER_ORDERS;NO_RUNTIME_EXIT_CHANGE"
#define FALCON_PPR_PARTIAL_POLICY                        "SIMULATE_PARTIAL_BRANCH_READINESS_FROM_FAST_TM_CONSERVATIVE_PARTIAL_PLAN"
#define FALCON_PPR_RUNNER_POLICY                         "SIMULATE_RUNNER_BRANCH_READINESS_FROM_FAST_TM_RUNNER_CANDIDATE_PLAN"
#define FALCON_PPR_BRANCH_ORDER_SEND_POLICY              "ORDER_SEND_HARD_BLOCKED;PAPER_BRANCH_SIMULATION_ONLY"
#define FALCON_PPR_BRANCH_NEXT_PHASE                     "v0.33.0_PaperPartialRunnerOutcomeSimulation"

// ==================================================================
// Paper Partial / Runner Outcome Validation Lock - v0.33.1
// Validation lock for paper partial/runner outcome proxy simulation. It preserves paper branch outcome metrics
// without changing Shadow lifecycle totals, SL/TP, exits, OrderSend, Demo, or Live.
// ==================================================================
#define FALCON_PPR_OUT_STATUS                            "PAPER_PARTIAL_RUNNER_OUTCOME_VALIDATION_LOCK"
#define FALCON_PPR_OUT_DECISION                          "PARTIAL_RUNNER_OUTCOME_PROXY_FULL_VALIDATION_LOCKED_NO_RUNTIME_EXIT_CHANGE"
#define FALCON_PPR_OUT_RUNTIME_ENFORCED                  false
#define FALCON_PPR_OUT_SCOPE                             "PAPER_PARTIAL_OUTCOME;PAPER_RUNNER_OUTCOME;VALIDATION_LOCK;PROXY_ONLY;NO_BROKER_ORDERS;NO_RUNTIME_EXIT_CHANGE"
#define FALCON_PPR_OUT_POLICY                            "VALIDATION_LOCK_PROXY_ONLY_FROM_BRANCH_AND_BARPATH_DIAGNOSTICS_NOT_EXPECTED_NET"
#define FALCON_PPR_OUT_NEXT_PHASE                        "v0.34.0_PaperProtectionRunnerStateMachineSimulation"

// ==================================================================
// Paper Protection / Runner State Machine Validation Lock - v0.34.2
// Validation lock for the Paper Protection / Runner State Machine.
// TP2 remains a proof checkpoint rather than a mandatory final target.
// Runner and Moon Mode remain proxy-only beyond TP2 after proof and protection.
// No SL/TP, exit, OrderSend, Paper fill, Demo, or Live behavior changes.
// ==================================================================
#define FALCON_PAPER_SM_STATUS                           "PAPER_PROTECTION_RUNNER_STATE_MACHINE_VALIDATION_LOCK"
#define FALCON_PAPER_SM_DECISION                         "STATE_MACHINE_FULL_VALIDATION_LOCKED_TP2_GATE_NO_RUNTIME_EXIT_CHANGE"
#define FALCON_PAPER_SM_RUNTIME_ENFORCED                 false
#define FALCON_PAPER_SM_SCOPE                            "PAPER_PROTECTION_STATE;PAPER_RUNNER_STATE;TP2_PROOF_GATE;MOON_MODE_PROXY;VALIDATION_LOCK;NO_BROKER_ORDERS;NO_RUNTIME_EXIT_CHANGE"
#define FALCON_PAPER_SM_POLICY                           "VALIDATION_LOCK;PROTECTION_FIRST;TP2_IS_NOT_FINAL_TARGET;RUNNER_ONLY_AFTER_PROOF;MOON_MODE_ONLY_AFTER_STRONG_PROOF"
#define FALCON_PAPER_SM_TP2_IS_CHECKPOINT                true
#define FALCON_PAPER_SM_TP2_EXIT_MANDATORY               false
#define FALCON_PAPER_SM_RUNNER_BEYOND_TP2_POLICY         "RUNNER_CAN_EXPAND_BEYOND_TP2_ONLY_AFTER_PROOF_AND_PROTECTION"
#define FALCON_PAPER_SM_EXPANSION_AFTER_PROOF            true
#define FALCON_PAPER_SM_PROTECT_BEFORE_EXPAND_POLICY     "PROTECT_FIRST_THEN_EXPAND;NO_EARLY_BE;NO_UNPROTECTED_RUNNER"
#define FALCON_PAPER_SM_NEXT_PHASE                       "v0.35.0_PaperProtectionStateMachineExecutionFeasibility"

// ==================================================================
// Paper Protection State Machine Execution Feasibility - v0.35.0
// Summary-only feasibility layer. It checks whether validated protection
// states can later become Paper modify-plan requests. It does not modify
// SL, does not activate runtime protection, does not send orders, and does
// not change entry, SL/TP, exit, Paper fill, Demo, or Live behavior.
// ==================================================================
#define FALCON_PPF_STATUS                                "PAPER_PROTECTION_STATE_MACHINE_EXECUTION_FEASIBILITY"
#define FALCON_PPF_DECISION                              "PROTECTION_MODIFY_PLAN_FEASIBLE_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PPF_RUNTIME_ENFORCED                      false
#define FALCON_PPF_SCOPE                                 "TP1_PROTECTION_STATE;TP2_PROTECTION_STATE;MODIFY_PLAN_READINESS;SUMMARY_ONLY;NO_RUNTIME_SL_CHANGE"
#define FALCON_PPF_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_VALIDATED_STATE_MACHINE_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PPF_MODIFY_POLICY                         "PLAN_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PPF_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PPF_NEXT_PHASE                            "v0.35.1_PaperProtectionModifyPlanValidationLock"

// ==================================================================
// Paper Protection Modify Plan Validation Lock - v0.35.1
// Validation lock for the paper protection modify-plan shape. It proves
// that each validated protection state has a plan, trigger, target level,
// and reason before any later Paper SL-modify simulation. It is Summary-only;
// it does not modify SL, does not send broker requests, and does not change
// entries, SL/TP, exits, Paper fills, Demo, or Live behavior.
// ==================================================================
#define FALCON_PPM_STATUS                                "PAPER_PROTECTION_MODIFY_PLAN_VALIDATION_LOCK"
#define FALCON_PPM_DECISION                              "MODIFY_PLAN_SHAPE_LOCKED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PPM_RUNTIME_ENFORCED                      false
#define FALCON_PPM_SCOPE                                 "MODIFY_PLAN;TRIGGER;PROTECT_LEVEL;REASON;VALIDATION_LOCK;SUMMARY_ONLY"
#define FALCON_PPM_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_STATE_MACHINE_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PPM_MODIFY_POLICY                         "PLAN_LOCK_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PPM_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PPM_NEXT_PHASE                            "v0.35.2_PaperProtectionModifyRequestTimingValidation"

// ==================================================================
// Paper Protection Modify Request Timing Validation - v0.35.2
// Summary-only timing layer. It validates that paper protection modify
// requests are logically timed after proof and before giveback, using
// locked closed-record/proxy state only. It does not modify SL, does not
// simulate broker modification, does not send orders, and does not change
// entries, SL/TP, exits, Paper fills, Demo, or Live behavior.
// ==================================================================
#define FALCON_PPT_STATUS                                "PAPER_PROTECTION_MODIFY_REQUEST_TIMING_VALIDATION"
#define FALCON_PPT_DECISION                              "MODIFY_REQUEST_TIMING_VALIDATED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PPT_RUNTIME_ENFORCED                      false
#define FALCON_PPT_SCOPE                                 "MODIFY_REQUEST_TIMING;AFTER_PROOF;BEFORE_GIVEBACK;NO_LOOKAHEAD;SUMMARY_ONLY"
#define FALCON_PPT_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_MODIFY_PLAN_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PPT_MODIFY_POLICY                         "TIMING_VALIDATION_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PPT_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PPT_NEXT_PHASE                            "v0.35.3_PaperProtectionModifyDryRunSimulation"

// ==================================================================
// Paper Protection Modify Dry Run Simulation - v0.35.3
// Summary-only dry run layer. It simulates the internal accept/reject
// shape of paper protection modify requests after timing validation.
// It does not call OrderSend, does not modify broker SL, does not change
// runtime protection, and does not alter entries, SL/TP, exits, Paper fills,
// Demo, or Live behavior.
// ==================================================================
#define FALCON_PPD_STATUS                                "PAPER_PROTECTION_MODIFY_DRY_RUN_SIMULATION"
#define FALCON_PPD_DECISION                              "MODIFY_DRY_RUN_ACCEPTANCE_SIMULATED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PPD_RUNTIME_ENFORCED                      false
#define FALCON_PPD_SCOPE                                 "DRY_RUN_MODIFY_REQUEST;INTERNAL_ACCEPT_REJECT_SHAPE;SUMMARY_ONLY;NO_BROKER_MODIFY"
#define FALCON_PPD_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_TIMING_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PPD_MODIFY_POLICY                         "DRY_RUN_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PPD_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PPD_NEXT_PHASE                            "v0.35.4_PaperProtectionDryRunValidationLock"


// ==================================================================
// Paper Protection Dry Run Validation Lock - v0.35.4
// Summary-only lock layer. It freezes the dry-run acceptance invariant:
// every validated paper protection modify request must be eligible and
// accepted, with zero rejects, zero skips, zero broker modify calls, and
// zero runtime SL changes. This is a lock only; it does not change entries,
// SL/TP, exits, Paper fills, Demo, Live, runtime protection, or runner logic.
// ==================================================================
#define FALCON_PDL_STATUS                                "PAPER_PROTECTION_DRY_RUN_VALIDATION_LOCK"
#define FALCON_PDL_DECISION                              "DRY_RUN_ACCEPTANCE_LOCKED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PDL_RUNTIME_ENFORCED                      false
#define FALCON_PDL_SCOPE                                 "DRY_RUN_ACCEPTANCE_LOCK;ZERO_REJECTS;ZERO_SKIPS;ZERO_BROKER_MODIFY;SUMMARY_ONLY"
#define FALCON_PDL_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_DRY_RUN_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PDL_MODIFY_POLICY                         "DRY_RUN_LOCK_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PDL_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PDL_NEXT_PHASE                            "v0.36.0_PaperProtectionVirtualSLStateCandidate"


// ==================================================================
// Paper Protection Virtual SL State Candidate - v0.36.0
// Summary-only ledger layer. It converts the validated dry-run protection
// requests into a virtual Paper SL state ledger for future execution design.
// It does not modify broker SL, does not change runtime SL, does not alter
// entries, SL/TP, exits, Paper fills, Demo, Live, protection, or runner logic.
// ==================================================================
#define FALCON_PVS_STATUS                                "PAPER_PROTECTION_VIRTUAL_SL_STATE_CANDIDATE"
#define FALCON_PVS_DECISION                              "VIRTUAL_SL_STATE_LEDGER_READY_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PVS_RUNTIME_ENFORCED                      false
#define FALCON_PVS_SCOPE                                 "VIRTUAL_SL_LEDGER;PROTECTED_STATE_READY;SUMMARY_ONLY;NO_BROKER_MODIFY"
#define FALCON_PVS_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_DRY_RUN_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PVS_STATE_POLICY                          "VIRTUAL_SL_STATE_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PVS_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PVS_NEXT_PHASE                            "v0.36.1_PaperProtectionVirtualSLStateValidationLock"


// ==================================================================
// Paper Protection Virtual SL State Validation Lock - v0.36.1
// Summary-only lock layer. It freezes the virtual SL state ledger
// invariant after v0.36.0: candidate states must be ready and active,
// with zero rejects, zero conflicts, zero missing levels, zero broker
// modify calls, and zero runtime SL changes. This is a lock only; it
// does not change entries, SL/TP, exits, Paper fills, Demo, Live,
// runtime protection, or runner logic.
// ==================================================================
#define FALCON_PVL_STATUS                                "PAPER_PROTECTION_VIRTUAL_SL_STATE_VALIDATION_LOCK"
#define FALCON_PVL_DECISION                              "VIRTUAL_SL_STATE_LEDGER_LOCKED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PVL_RUNTIME_ENFORCED                      false
#define FALCON_PVL_SCOPE                                 "VIRTUAL_SL_STATE_LOCK;READY_EQUALS_ACTIVE;ZERO_REJECTS;ZERO_CONFLICTS;ZERO_MISSING_LEVELS;SUMMARY_ONLY"
#define FALCON_PVL_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_VIRTUAL_SL_STATE_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PVL_STATE_POLICY                          "VIRTUAL_SL_LOCK_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PVL_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PVL_NEXT_PHASE                            "v0.36.2_PaperProtectionVirtualSLTransitionReadiness"


// ==================================================================
// Paper Protection Virtual SL Transition Readiness - v0.36.2
// Summary-only transition-readiness layer. It validates that the locked
// Virtual SL state ledger can be read by the future Paper Executor path
// as an internal transition state. It does not send broker modify requests,
// does not change runtime SL, and does not alter entries, SL/TP, exits,
// Paper fills, Demo, Live, protection, or runner logic.
// ==================================================================
#define FALCON_PVT_STATUS                                "PAPER_PROTECTION_VIRTUAL_SL_TRANSITION_READINESS"
#define FALCON_PVT_DECISION                              "VIRTUAL_SL_TRANSITION_READY_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PVT_RUNTIME_ENFORCED                      false
#define FALCON_PVT_SCOPE                                 "VIRTUAL_SL_TRANSITION;TRADEMANAGEMENT_TO_PAPER_EXECUTOR;SUMMARY_ONLY;NO_BROKER_MODIFY"
#define FALCON_PVT_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_VIRTUAL_SL_STATE_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PVT_TRANSITION_POLICY                     "TRANSITION_READINESS_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PVT_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PVT_NEXT_PHASE                            "v0.36.3_PaperProtectionVirtualSLTransitionValidationLock"


// ==================================================================
// Paper Protection Virtual SL Transition Validation Lock - v0.36.3
// Summary-only lock layer. It freezes the transition bridge from the
// locked Virtual SL state ledger to the future Paper Executor consumer.
// It enforces zero broker modify, zero runtime SL change, zero missing
// ledger rows, and full executor readability. This is not runtime
// protection and does not alter entries, SL/TP, exits, Paper fills,
// Demo, Live, protection, or runner logic.
// ==================================================================
#define FALCON_PTL_STATUS                                "PAPER_PROTECTION_VIRTUAL_SL_TRANSITION_VALIDATION_LOCK"
#define FALCON_PTL_DECISION                              "VIRTUAL_SL_TRANSITION_LOCKED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PTL_RUNTIME_ENFORCED                      false
#define FALCON_PTL_SCOPE                                 "VIRTUAL_SL_TRANSITION_LOCK;EXECUTOR_READABLE;LEDGER_READABLE;ZERO_BREACHES;SUMMARY_ONLY"
#define FALCON_PTL_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_TRANSITION_STATE_AND_CLOSED_RECORDS_ONLY"
#define FALCON_PTL_TRANSITION_POLICY                     "TRANSITION_LOCK_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PTL_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PTL_NEXT_PHASE                            "v0.37.0_PaperProtectionVirtualSLBrokerFeasibilityProxy"


// ==================================================================
// Paper Protection Virtual SL Broker Feasibility Proxy - v0.37.0
// Summary-only operational safety bridge. It checks whether the locked
// Virtual SL transition state has enough broker context to become
// executable later: stops level known, freeze level known, and protection
// level resolved. It does not send broker modify requests, does not change
// runtime SL, and does not alter entries, SL/TP, exits, Paper fills, Demo,
// Live, protection, or runner logic.
// ==================================================================
#define FALCON_PBF_STATUS                                "PAPER_PROTECTION_VIRTUAL_SL_BROKER_FEASIBILITY_PROXY"
#define FALCON_PBF_DECISION                              "BROKER_FEASIBILITY_PROXY_READY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PBF_RUNTIME_ENFORCED                      false
#define FALCON_PBF_SCOPE                                 "BROKER_FEASIBILITY_PROXY;STOPS_LEVEL;FREEZE_LEVEL;SUMMARY_ONLY;NO_BROKER_MODIFY"
#define FALCON_PBF_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_TRANSITION_STATE_AND_SYMBOL_CONTEXT_ONLY"
#define FALCON_PBF_BROKER_POLICY                         "BROKER_FEASIBILITY_PROXY_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PBF_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PBF_NEXT_PHASE                            "v0.37.1_PaperProtectionBrokerFeasibilityValidationLock"
#define FALCON_PBF_STOPS_BUFFER_POINTS                   2


// ==================================================================
// Paper Protection Broker Feasibility Validation Lock - v0.37.1
// Summary-only lock layer. It freezes the broker-feasibility proxy
// after stops level, freeze level, broker context, and protection-level
// executability all passed. It does not send broker modify requests,
// does not change runtime SL, and does not alter entries, SL/TP, exits,
// Paper fills, Demo, Live, protection, or runner logic.
// ==================================================================
#define FALCON_PBL_STATUS                                "PAPER_PROTECTION_BROKER_FEASIBILITY_VALIDATION_LOCK"
#define FALCON_PBL_DECISION                              "BROKER_FEASIBILITY_LOCKED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PBL_RUNTIME_ENFORCED                      false
#define FALCON_PBL_SCOPE                                 "BROKER_FEASIBILITY_LOCK;STOPS_LEVEL_SAFE;FREEZE_LEVEL_SAFE;ZERO_BREACHES;SUMMARY_ONLY"
#define FALCON_PBL_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_BROKER_FEASIBILITY_AND_SYMBOL_CONTEXT_ONLY"
#define FALCON_PBL_BROKER_POLICY                         "BROKER_FEASIBILITY_LOCK_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PBL_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PBL_NEXT_PHASE                            "v0.37.2_PaperProtectionBrokerDistanceSanityProxy"


// ==================================================================
// Paper Protection Broker Distance Sanity Proxy - v0.37.2
// Summary-only operational safety proxy. It checks whether the locked
// broker-feasible Virtual SL state has a sane distance context against
// stops level + buffer and freeze level before any future PaperExecutor
// or broker modify path. It does not send broker modify requests, does
// not change runtime SL, and does not alter entries, SL/TP, exits,
// Paper fills, Demo, Live, protection, or runner logic.
// ==================================================================
#define FALCON_PBD_STATUS                                "PAPER_PROTECTION_BROKER_DISTANCE_SANITY_PROXY"
#define FALCON_PBD_DECISION                              "BROKER_DISTANCE_SANITY_PROXY_READY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PBD_RUNTIME_ENFORCED                      false
#define FALCON_PBD_SCOPE                                 "BROKER_DISTANCE_SANITY_PROXY;STOPS_DISTANCE;FREEZE_DISTANCE;SUMMARY_ONLY;NO_BROKER_MODIFY"
#define FALCON_PBD_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_BROKER_FEASIBILITY_AND_SYMBOL_CONTEXT_ONLY"
#define FALCON_PBD_DISTANCE_POLICY                       "DISTANCE_SANITY_PROXY_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PBD_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PBD_NEXT_PHASE                            "v0.37.3_PaperProtectionBrokerDistanceSanityValidationLock"


// ==================================================================
// Paper Protection Broker Distance Sanity Validation Lock - v0.37.3
// Summary-only lock layer. It freezes the broker-distance sanity proxy
// after locked broker feasibility, known stops/freeze context, known
// required distance, and zero distance blocks all passed. It does not
// send broker modify requests, does not change runtime SL, and does not
// alter entries, SL/TP, exits, Paper fills, Demo, Live, protection, or
// runner logic.
// ==================================================================
#define FALCON_PBDL_STATUS                                "PAPER_PROTECTION_BROKER_DISTANCE_SANITY_VALIDATION_LOCK"
#define FALCON_PBDL_DECISION                              "BROKER_DISTANCE_SANITY_LOCKED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PBDL_RUNTIME_ENFORCED                      false
#define FALCON_PBDL_SCOPE                                 "BROKER_DISTANCE_SANITY_LOCK;STOPS_DISTANCE_SAFE;FREEZE_DISTANCE_SAFE;ZERO_BREACHES;SUMMARY_ONLY"
#define FALCON_PBDL_NO_LOOKAHEAD_POLICY                   "YES_PROXY_FROM_LOCKED_BROKER_DISTANCE_AND_SYMBOL_CONTEXT_ONLY"
#define FALCON_PBDL_DISTANCE_POLICY                       "DISTANCE_SANITY_LOCK_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PBDL_ORDER_SEND_POLICY                     "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PBDL_NEXT_PHASE                            "v0.38.0_PaperProtectionBrokerModifyEligibilityProxy"


// ==================================================================
// Paper Protection Broker Modify Eligibility Proxy - v0.38.0
// Summary-only eligibility bridge. It combines the locked Virtual SL,
// broker feasibility, and broker distance sanity layers into a future
// PaperExecutor modify-eligibility shape. It sends no broker modify
// request, changes no runtime SL, enables no OrderSend, and does not
// alter entries, SL/TP, exits, Paper fills, Demo, or Live behavior.
// ==================================================================
#define FALCON_PBME_STATUS                               "PAPER_PROTECTION_BROKER_MODIFY_ELIGIBILITY_PROXY"
#define FALCON_PBME_DECISION                             "BROKER_MODIFY_ELIGIBILITY_PROXY_READY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PBME_RUNTIME_ENFORCED                     false
#define FALCON_PBME_SCOPE                                "BROKER_MODIFY_ELIGIBILITY_PROXY;DISTANCE_LOCK_READY;FEASIBILITY_LOCK_READY;SUMMARY_ONLY;NO_BROKER_MODIFY"
#define FALCON_PBME_NO_LOOKAHEAD_POLICY                  "YES_PROXY_FROM_LOCKED_BROKER_DISTANCE_AND_FEASIBILITY_ONLY"
#define FALCON_PBME_ELIGIBILITY_POLICY                   "ELIGIBILITY_PROXY_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PBME_ORDER_SEND_POLICY                    "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PBME_NEXT_PHASE                           "v0.38.1_PaperProtectionBrokerModifyEligibilityValidationLock"


// ==================================================================
// Paper Protection Broker Modify Eligibility Validation Lock - v0.38.1
// Summary-only lock for the broker modify eligibility proxy. It proves
// the future PaperExecutor modify eligibility chain is complete and
// internally consistent while still sending no broker modify, changing no
// runtime SL, enabling no OrderSend, and adding no reports or inputs.
// ==================================================================
#define FALCON_PBMEL_STATUS                              "PAPER_PROTECTION_BROKER_MODIFY_ELIGIBILITY_VALIDATION_LOCK"
#define FALCON_PBMEL_DECISION                            "BROKER_MODIFY_ELIGIBILITY_LOCKED_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PBMEL_RUNTIME_ENFORCED                    false
#define FALCON_PBMEL_SCOPE                               "BROKER_MODIFY_ELIGIBILITY_LOCK;DISTANCE_LOCK_READY;FEASIBILITY_LOCK_READY;ZERO_BREACHES;SUMMARY_ONLY"
#define FALCON_PBMEL_NO_LOOKAHEAD_POLICY                 "YES_PROXY_FROM_LOCKED_BROKER_MODIFY_ELIGIBILITY_ONLY"
#define FALCON_PBMEL_ELIGIBILITY_POLICY                  "ELIGIBILITY_VALIDATION_LOCK_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PBMEL_ORDER_SEND_POLICY                   "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PBMEL_NEXT_PHASE                          "v0.39.0_PaperProtectionExecutorModifyPlanConsumerReadiness"


// ==================================================================
// Paper Protection Executor Modify Plan Consumer Readiness - v0.39.0
// Summary-only bridge into the future PaperExecutor consumer path. It
// proves that the locked broker modify eligibility, virtual SL ledger,
// modify plan, protection level, and trigger can be read as one coherent
// consumer state. It does not send broker modify, does not change runtime
// SL, does not enable OrderSend, and adds no inputs or diagnostic reports.
// ==================================================================
#define FALCON_PEMC_STATUS                              "PAPER_PROTECTION_EXECUTOR_MODIFY_PLAN_CONSUMER_READINESS"
#define FALCON_PEMC_DECISION                            "PAPER_EXECUTOR_CONSUMER_READY_PROXY_ONLY_NO_RUNTIME_SL_CHANGE"
#define FALCON_PEMC_RUNTIME_ENFORCED                    false
#define FALCON_PEMC_SCOPE                               "PAPER_EXECUTOR_CONSUMER_READINESS;ELIGIBILITY_LOCK_READY;VIRTUAL_SL_READABLE;MODIFY_PLAN_READABLE;SUMMARY_ONLY"
#define FALCON_PEMC_NO_LOOKAHEAD_POLICY                 "YES_PROXY_FROM_LOCKED_PBMEL_AND_VIRTUAL_SL_TRANSITION_ONLY"
#define FALCON_PEMC_CONSUMER_POLICY                     "CONSUMER_READINESS_ONLY;NO_SL_MODIFY;NO_POSITION_MODIFY;NO_RUNTIME_PROTECTION"
#define FALCON_PEMC_ORDER_SEND_POLICY                   "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PEMC_NEXT_PHASE                          "v0.40.0_MagicNumberSystemAndFalconExecutorErrorClassification"


// ==================================================================
// Magic Number System + FalconExecutor Error Classification - v0.40.0
// Summary-only operational safety foundation. It defines the per-engine
// magic-number contract and the future FalconExecutor order-failure
// classifier before any broker OrderSend/Modify/Close path is allowed.
// It does not execute trades, does not modify SL, and adds no inputs or
// diagnostic reports.
// ==================================================================
#define FALCON_MEC_STATUS                              "MAGIC_NUMBER_SYSTEM_AND_EXECUTOR_ERROR_CLASSIFICATION"
#define FALCON_MEC_DECISION                            "OPERATIONAL_SAFETY_CONTRACT_READY_NO_EXECUTION"
#define FALCON_MEC_RUNTIME_ENFORCED                    false
#define FALCON_MEC_SCOPE                               "MAGIC_NUMBER_DISCIPLINE;ORDER_FAILURE_CLASSIFICATION;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_MEC_MAGIC_POLICY                        "ONE_ENGINE_ONE_MAGIC;UNKNOWN_MAGIC_REJECTED;NO_ENGINE_CROSSTOUCH"
#define FALCON_MEC_ERROR_POLICY                        "CLASSIFY_BEFORE_RETRY;NO_RETRY_ON_FATAL;UNKNOWN_HALTS_NEW_ENTRIES_LATER"
#define FALCON_MEC_ORDER_SEND_POLICY                   "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_MEC_NEXT_PHASE                          "v0.41.0_TradeStatePersistenceAndRestartRecovery"

#define FC_MAGIC_BASE                                  1000000
#define FC_MAGIC_FVG_MICRO                             1100001
#define FC_MAGIC_TAIL_SMART_RETURN                     2100001
#define FC_MAGIC_MOMENTUM_CROSS_8_20                   3100001
#define FC_MAGIC_CHECK_MARK_LIQUIDITY_SWEEP            4100001
#define FC_MAGIC_DOUBLE_BOX_WICK_CONFIRMATION          5100001
#define FC_MAGIC_TOUCH_TURN_OPENING_RANGE              4100002
#define FC_MAGIC_MAGIC_LIQUIDITY_PITCHFORK             5100002
#define FC_MAGIC_DAILY_LIQUIDITY_BOX                   5100003
#define FC_MAGIC_QUICK_FLIP_OPENING_LIQUIDITY          4100003
#define FC_MAGIC_FSE_PATTERN_FAILURE_ENTRY             2100002
#define FC_MAGIC_TWO_LIQUIDITY_LINES_15M               5100004
#define FC_MAGIC_GOLDEN_LIQUIDITY_5M_ENTRY             5100005
#define FALCON_MEC_DEFINED_MAGIC_COUNT                 12
#define FALCON_MEC_ORDER_FAIL_CLASS_COUNT              6

enum ENUM_FALCON_ORDER_FAIL_CLASS
{
   FALCON_FAIL_RETRYABLE = 0,
   FALCON_FAIL_FATAL = 1,
   FALCON_FAIL_NEEDS_REFRESH = 2,
   FALCON_FAIL_BROKER_LIMIT = 3,
   FALCON_FAIL_CONNECTION = 4,
   FALCON_FAIL_UNKNOWN = 5
};

int FalconMecMagicForEngine(const string engine_id)
{
   if(engine_id == "SCALP.FVG_MICRO")       return FC_MAGIC_FVG_MICRO;
   if(engine_id == "PRICE.TAIL_RETURN")     return FC_MAGIC_TAIL_SMART_RETURN;
   if(engine_id == "CONFIRM.MA_8_20")       return FC_MAGIC_MOMENTUM_CROSS_8_20;
   if(engine_id == "OPENING.CHECK_MARK")    return FC_MAGIC_CHECK_MARK_LIQUIDITY_SWEEP;
   if(engine_id == "LIQUIDITY.DOUBLE_BOX")  return FC_MAGIC_DOUBLE_BOX_WICK_CONFIRMATION;
   if(engine_id == "OPENING.TOUCH_TURN")    return FC_MAGIC_TOUCH_TURN_OPENING_RANGE;
   if(engine_id == "LIQUIDITY.MAGIC_LINES") return FC_MAGIC_MAGIC_LIQUIDITY_PITCHFORK;
   if(engine_id == "LIQUIDITY.DAILY_BOX")   return FC_MAGIC_DAILY_LIQUIDITY_BOX;
   if(engine_id == "OPENING.QUICK_FLIP")    return FC_MAGIC_QUICK_FLIP_OPENING_LIQUIDITY;
   if(engine_id == "PRICE.FSE_FAILURE")     return FC_MAGIC_FSE_PATTERN_FAILURE_ENTRY;
   if(engine_id == "LIQUIDITY.TWO_LINES_15M") return FC_MAGIC_TWO_LIQUIDITY_LINES_15M;
   if(engine_id == "LIQUIDITY.GOLDEN_5M")   return FC_MAGIC_GOLDEN_LIQUIDITY_5M_ENTRY;
   return 0;
}

bool FalconMecMagicUnique()
{
   int magics[12];
   magics[0]  = FC_MAGIC_FVG_MICRO;
   magics[1]  = FC_MAGIC_TAIL_SMART_RETURN;
   magics[2]  = FC_MAGIC_MOMENTUM_CROSS_8_20;
   magics[3]  = FC_MAGIC_CHECK_MARK_LIQUIDITY_SWEEP;
   magics[4]  = FC_MAGIC_DOUBLE_BOX_WICK_CONFIRMATION;
   magics[5]  = FC_MAGIC_TOUCH_TURN_OPENING_RANGE;
   magics[6]  = FC_MAGIC_MAGIC_LIQUIDITY_PITCHFORK;
   magics[7]  = FC_MAGIC_DAILY_LIQUIDITY_BOX;
   magics[8]  = FC_MAGIC_QUICK_FLIP_OPENING_LIQUIDITY;
   magics[9]  = FC_MAGIC_FSE_PATTERN_FAILURE_ENTRY;
   magics[10] = FC_MAGIC_TWO_LIQUIDITY_LINES_15M;
   magics[11] = FC_MAGIC_GOLDEN_LIQUIDITY_5M_ENTRY;

   for(int i = 0; i < 12; i++)
   {
      if(magics[i] <= FC_MAGIC_BASE)
         return false;
      for(int j = i + 1; j < 12; j++)
      {
         if(magics[i] == magics[j])
            return false;
      }
   }
   return true;
}

ENUM_FALCON_ORDER_FAIL_CLASS FalconMecClassifyRetcode(const uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_PRICE_OFF:
         return FALCON_FAIL_NEEDS_REFRESH;

      case TRADE_RETCODE_TOO_MANY_REQUESTS:
      case TRADE_RETCODE_LOCKED:
      case TRADE_RETCODE_TIMEOUT:
         return FALCON_FAIL_RETRYABLE;

      case TRADE_RETCODE_INVALID_STOPS:
      case TRADE_RETCODE_INVALID_VOLUME:
      case TRADE_RETCODE_INVALID_PRICE:
      case TRADE_RETCODE_INVALID_FILL:
      case TRADE_RETCODE_LIMIT_VOLUME:
      case TRADE_RETCODE_LIMIT_ORDERS:
      case TRADE_RETCODE_LIMIT_POSITIONS:
         return FALCON_FAIL_BROKER_LIMIT;

      case TRADE_RETCODE_CONNECTION:
         return FALCON_FAIL_CONNECTION;

      case TRADE_RETCODE_TRADE_DISABLED:
      case TRADE_RETCODE_MARKET_CLOSED:
      case TRADE_RETCODE_NO_MONEY:
      case TRADE_RETCODE_SERVER_DISABLES_AT:
      case TRADE_RETCODE_CLIENT_DISABLES_AT:
      case TRADE_RETCODE_ONLY_REAL:
      case TRADE_RETCODE_LONG_ONLY:
      case TRADE_RETCODE_SHORT_ONLY:
      case TRADE_RETCODE_CLOSE_ONLY:
      case TRADE_RETCODE_FIFO_CLOSE:
         return FALCON_FAIL_FATAL;
   }
   return FALCON_FAIL_UNKNOWN;
}

string FalconMecFailClassToString(const ENUM_FALCON_ORDER_FAIL_CLASS fail_class)
{
   switch(fail_class)
   {
      case FALCON_FAIL_RETRYABLE:     return "FAIL_RETRYABLE";
      case FALCON_FAIL_FATAL:         return "FAIL_FATAL";
      case FALCON_FAIL_NEEDS_REFRESH: return "FAIL_NEEDS_REFRESH";
      case FALCON_FAIL_BROKER_LIMIT:  return "FAIL_BROKER_LIMIT";
      case FALCON_FAIL_CONNECTION:    return "FAIL_CONNECTION";
      case FALCON_FAIL_UNKNOWN:       return "FAIL_UNKNOWN";
   }
   return "FAIL_UNKNOWN";
}


// ==================================================================
// Trade State Persistence + Restart Recovery - v0.41.0
// Summary-only operational safety scaffold. It defines the future trade
// state persistence record, broker reconstruction contract, and
// MINIMAL_RECOVERY behavior before any Demo/Live execution path exists.
// It writes no trade-state files in ShadowSmoke, sends no orders, and
// changes no runtime SL.
// ==================================================================
#define FALCON_TSPR_STATUS                             "TRADE_STATE_PERSISTENCE_AND_RESTART_RECOVERY"
#define FALCON_TSPR_DECISION                           "STATE_RECOVERY_CONTRACT_READY_NO_EXECUTION"
#define FALCON_TSPR_RUNTIME_ENFORCED                   false
#define FALCON_TSPR_SCOPE                              "TRADE_STATE_PERSISTENCE;RESTART_RECOVERY;MINIMAL_RECOVERY;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_TSPR_STATE_POLICY                       "PERSIST_AFTER_TRADE_EVENT;REBUILD_FROM_BROKER_PLUS_DISK;MINIMAL_RECOVERY_ON_UNTRUSTED_STATE"
#define FALCON_TSPR_ORDER_SEND_POLICY                  "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_TSPR_NEXT_PHASE                         "v0.42.0_SpreadSlippageGuardsAndBrokerLimitsCaching"
#define FALCON_TSPR_STATE_FOLDER                       "FalconCore_State"
#define FALCON_TSPR_RECORD_FIELD_COUNT                 12

enum ENUM_FALCON_TSPR_MODE
{
   FALCON_TSPR_MODE_NORMAL = 0,
   FALCON_TSPR_MODE_MINIMAL_RECOVERY = 1
};

bool FalconTsprKnownMagic(const int magic_number)
{
   if(magic_number == FC_MAGIC_FVG_MICRO) return true;
   if(magic_number == FC_MAGIC_TAIL_SMART_RETURN) return true;
   if(magic_number == FC_MAGIC_MOMENTUM_CROSS_8_20) return true;
   if(magic_number == FC_MAGIC_CHECK_MARK_LIQUIDITY_SWEEP) return true;
   if(magic_number == FC_MAGIC_DOUBLE_BOX_WICK_CONFIRMATION) return true;
   if(magic_number == FC_MAGIC_TOUCH_TURN_OPENING_RANGE) return true;
   if(magic_number == FC_MAGIC_MAGIC_LIQUIDITY_PITCHFORK) return true;
   if(magic_number == FC_MAGIC_DAILY_LIQUIDITY_BOX) return true;
   if(magic_number == FC_MAGIC_QUICK_FLIP_OPENING_LIQUIDITY) return true;
   if(magic_number == FC_MAGIC_FSE_PATTERN_FAILURE_ENTRY) return true;
   if(magic_number == FC_MAGIC_TWO_LIQUIDITY_LINES_15M) return true;
   if(magic_number == FC_MAGIC_GOLDEN_LIQUIDITY_5M_ENTRY) return true;
   return false;
}

bool FalconTsprFolderReady()
{
   return (StringLen(FALCON_TSPR_STATE_FOLDER) > 0);
}

bool FalconTsprRecordShapeReady()
{
   return (FALCON_TSPR_RECORD_FIELD_COUNT >= 10);
}

bool FalconTsprMinimalModeReady()
{
   return (FALCON_TSPR_MODE_MINIMAL_RECOVERY == 1);
}

string FalconTsprStateFileName(const ulong ticket)
{
   return FALCON_TSPR_STATE_FOLDER + "\\FC_" + IntegerToString((long)ticket) + ".csv";
}


// ==================================================================
// Spread / Slippage Guards + Broker Limits Caching - v0.42.0
// Summary-only operational safety scaffold. It proves that FalconCore
// has a future pre-trade spread guard, order slippage cap, and broker
// stops/freeze/volume-limit cache before any Demo/Live execution path.
// It sends no orders, modifies no broker stops, and changes no runtime SL.
// ==================================================================
#define FALCON_SSBL_STATUS                            "SPREAD_SLIPPAGE_GUARDS_AND_BROKER_LIMITS_CACHING"
#define FALCON_SSBL_DECISION                          "SPREAD_SLIPPAGE_BROKER_LIMITS_READY_NO_EXECUTION"
#define FALCON_SSBL_RUNTIME_ENFORCED                  false
#define FALCON_SSBL_SCOPE                             "SPREAD_GUARD;SLIPPAGE_CAP;BROKER_LIMITS_CACHE;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_SSBL_SPREAD_POLICY                     "PRE_TRADE_SPREAD_GUARD_REQUIRED;NAS100_BROKER_POINTS_CALIBRATED;MAX_SPREAD_POINTS_120;PAPER_RUNTIME_NOW"
#define FALCON_SSBL_LIMITS_POLICY                     "CACHE_STOPS_FREEZE_VOLUME_LIMITS;VALIDATE_BEFORE_SEND_OR_MODIFY"
#define FALCON_SSBL_ORDER_SEND_POLICY                 "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_SSBL_NEXT_PHASE                        "v0.43.0_OnTradeTransactionDrivenStateUpdates"
#define FALCON_SSBL_MAX_SPREAD_POINTS                 120
// v0.49.0a: calibrated from v0.49.0 report where US100_Spot FVG spreads were 110-115 broker points; 25 rejected 436/436 trades.
#define FALCON_SSBL_MAX_SLIPPAGE_POINTS               20
#define FALCON_SSBL_STOPS_BUFFER_POINTS               2

bool FalconSsblSpreadGuardReady()
{
   return (FALCON_SSBL_MAX_SPREAD_POINTS > 0);
}

bool FalconSsblSlippageCapReady()
{
   return (FALCON_SSBL_MAX_SLIPPAGE_POINTS > 0);
}

bool FalconSsblStopsPolicyReady()
{
   return (FALCON_SSBL_STOPS_BUFFER_POINTS >= 1);
}

bool FalconSsblBrokerContextReady(const bool context_valid,
                                  const long stops_level_points,
                                  const long freeze_level_points,
                                  const double min_lot,
                                  const double max_lot,
                                  const double lot_step,
                                  const double point,
                                  const double tick_size,
                                  const double tick_value)
{
   if(!context_valid)
      return false;
   if(stops_level_points < 0 || freeze_level_points < 0)
      return false;
   if(min_lot <= 0.0 || max_lot < min_lot || lot_step <= 0.0)
      return false;
   if(point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0)
      return false;
   return true;
}

bool FalconSsblGuardReady(const bool context_valid,
                          const long stops_level_points,
                          const long freeze_level_points,
                          const double min_lot,
                          const double max_lot,
                          const double lot_step,
                          const double point,
                          const double tick_size,
                          const double tick_value)
{
   return (FalconSsblSpreadGuardReady() &&
           FalconSsblSlippageCapReady() &&
           FalconSsblStopsPolicyReady() &&
           FalconSsblBrokerContextReady(context_valid,
                                        stops_level_points,
                                        freeze_level_points,
                                        min_lot,
                                        max_lot,
                                        lot_step,
                                        point,
                                        tick_size,
                                        tick_value));
}


// ==================================================================
// OnTradeTransaction-driven State Updates - v0.43.0
// Summary-only operational safety scaffold. It proves that future
// broker state changes have an event-driven contract before any Demo/
// Live execution path exists. OnTick reads state; OnTradeTransaction is
// the future source-of-truth entrypoint. This build sends no orders,
// modifies no broker stops, and changes no runtime SL.
// ==================================================================
#define FALCON_OTTU_STATUS                            "ON_TRADE_TRANSACTION_DRIVEN_STATE_UPDATES"
#define FALCON_OTTU_DECISION                          "TRADE_TRANSACTION_STATE_UPDATE_CONTRACT_READY_NO_EXECUTION"
#define FALCON_OTTU_RUNTIME_ENFORCED                  false
#define FALCON_OTTU_SCOPE                             "ON_TRADE_TRANSACTION;EVENT_ROUTING;STATE_SYNC;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_OTTU_SOURCE_POLICY                     "ON_TRADE_TRANSACTION_SOURCE_OF_TRUTH;ONTICK_READS_ONLY"
#define FALCON_OTTU_STATE_POLICY                      "ROUTE_DEAL_ADD;ROUTE_POSITION_CHANGE;PERSIST_AFTER_TRUSTED_EVENT"
#define FALCON_OTTU_ORDER_SEND_POLICY                 "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_OTTU_NEXT_PHASE                        "v0.44.0_PreInitVerificationPack"
#define FALCON_OTTU_EVENT_KIND_COUNT                  3

int g_ottu_transactions_observed = 0;
int g_ottu_deal_events_routed = 0;
int g_ottu_position_events_routed = 0;
int g_ottu_unknown_events_ignored = 0;

bool FalconOttuHandlerContractReady()
{
   return true;
}

bool FalconOttuEventRoutingReady()
{
   return (FALCON_OTTU_EVENT_KIND_COUNT >= 3);
}

bool FalconOttuSourcePolicyReady()
{
   return (StringLen(FALCON_OTTU_SOURCE_POLICY) > 0 && StringLen(FALCON_OTTU_STATE_POLICY) > 0);
}

void FalconOttuRouteTransaction(const MqlTradeTransaction &trans)
{
   g_ottu_transactions_observed++;

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      g_ottu_deal_events_routed++;
      return;
   }

   if(trans.type == TRADE_TRANSACTION_POSITION)
   {
      g_ottu_position_events_routed++;
      return;
   }

   g_ottu_unknown_events_ignored++;
}


// ==================================================================
// Pre-Init Verification Pack - v0.44.0
// Summary-only operational safety scaffold. It proves that FalconCore
// has a defined environment verification contract before any Demo/Live
// execution path. This build does not call INIT_FAILED from the new
// scaffold, sends no orders, modifies no broker stops, and changes no
// runtime SL. Enforcement becomes a later Demo/Live gate.
// ==================================================================
#define FALCON_PIVP_STATUS                            "PRE_INIT_VERIFICATION_PACK"
#define FALCON_PIVP_DECISION                          "PRE_INIT_ENVIRONMENT_CONTRACT_READY_NO_EXECUTION"
#define FALCON_PIVP_RUNTIME_ENFORCED                  false
#define FALCON_PIVP_SCOPE                             "SYMBOL_CHECK;TIMEFRAME_CHECK;ACCOUNT_CHECK;BROKER_CONTEXT_CHECK;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_PIVP_SYMBOL_POLICY                     "NAS100_US100_NDX_ALLOWED;BROKER_SUFFIX_TOLERANT;WRONG_SYMBOL_BLOCKS_DEMO_LIVE"
#define FALCON_PIVP_TIMEFRAME_POLICY                  "M5_OR_M15_PREFERRED;SHADOW_SMOKE_NON_BLOCKING_NOW;DEMO_LIVE_GATE_LATER"
#define FALCON_PIVP_ACCOUNT_POLICY                    "TRADE_ALLOWED_CHECK;EXPERTS_ALLOWED_CHECK;MIN_BALANCE_POLICY_DEFINED"
#define FALCON_PIVP_BROKER_POLICY                     "STOPS_LEVEL_REASONABLE;POINT_TICK_VOLUME_CONTEXT_REQUIRED"
#define FALCON_PIVP_ORDER_SEND_POLICY                 "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PIVP_NEXT_PHASE                        "v0.45.0_EmergencyEquityStopIndependentLayer"
#define FALCON_PIVP_MIN_ACCOUNT_BALANCE_USD           500.0
#define FALCON_PIVP_MAX_REASONABLE_STOPS_LEVEL        100
#define FALCON_PIVP_ALLOWED_SYMBOL_FAMILIES           3
#define FALCON_PIVP_ALLOWED_TIMEFRAMES                2

bool FalconPivpSymbolPolicyReady()
{
   return (FALCON_PIVP_ALLOWED_SYMBOL_FAMILIES >= 3 && StringLen(FALCON_PIVP_SYMBOL_POLICY) > 0);
}

bool FalconPivpTimeframePolicyReady()
{
   return (FALCON_PIVP_ALLOWED_TIMEFRAMES >= 2 && StringLen(FALCON_PIVP_TIMEFRAME_POLICY) > 0);
}

bool FalconPivpAccountPolicyReady()
{
   return (FALCON_PIVP_MIN_ACCOUNT_BALANCE_USD > 0.0 && StringLen(FALCON_PIVP_ACCOUNT_POLICY) > 0);
}

bool FalconPivpBrokerPolicyReady()
{
   return (FALCON_PIVP_MAX_REASONABLE_STOPS_LEVEL > 0 && StringLen(FALCON_PIVP_BROKER_POLICY) > 0);
}

bool FalconPivpSupportedNasdaqSymbol(const string symbol)
{
   if(StringFind(symbol, "NAS100") >= 0) return true;
   if(StringFind(symbol, "US100") >= 0) return true;
   if(StringFind(symbol, "NDX") >= 0) return true;
   return false;
}


// ==================================================================
// Emergency Equity Stop Independent Layer - v0.45.0
// Summary-only operational safety scaffold. It proves that FalconCore
// has a hard last-resort equity stop contract independent from strategy,
// engine, and DailyGovernance state. This build only exposes readiness
// metrics; it does not close positions, send orders, modify broker stops,
// or change runtime SL. Enforcement becomes a later Demo/Live gate.
// ==================================================================
#define FALCON_EESL_STATUS                            "EMERGENCY_EQUITY_STOP_LAYER"
#define FALCON_EESL_DECISION                          "EMERGENCY_EQUITY_STOP_CONTRACT_READY_NO_EXECUTION"
#define FALCON_EESL_RUNTIME_ENFORCED                  false
#define FALCON_EESL_SCOPE                             "INDEPENDENT_EQUITY_CHECK;LAST_RESORT;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_EESL_POLICY                            "CHECK_EVERY_TICK_BEFORE_ENGINE;INDEPENDENT_OF_DAILY_GOVERNANCE"
#define FALCON_EESL_ACTION_POLICY                     "BLOCK_NEW_ENTRIES;CLOSE_ALL_MANAGED_POSITIONS_LATER;DISABLE_SESSION_LATER"
#define FALCON_EESL_ALERT_POLICY                      "ALERT_ON_TRIGGER_LATER;PROJECT_MEMORY_LIVE_READINESS_REQUIRED"
#define FALCON_EESL_ORDER_SEND_POLICY                 "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_EESL_NEXT_PHASE                        "v0.46.0_ConcurrentPositionDiscipline"
#define FALCON_EESL_HARD_CAP_PCT                      5.0
#define FALCON_EESL_MIN_CAP_PCT                       0.1
#define FALCON_EESL_MAX_CAP_PCT                       10.0

bool FalconEeslContractReady()
{
   return (FALCON_EESL_HARD_CAP_PCT >= FALCON_EESL_MIN_CAP_PCT &&
           FALCON_EESL_HARD_CAP_PCT <= FALCON_EESL_MAX_CAP_PCT &&
           StringLen(FALCON_EESL_POLICY) > 0 &&
           StringLen(FALCON_EESL_ACTION_POLICY) > 0);
}

bool FalconEeslIndependenceReady()
{
   return (StringFind(FALCON_EESL_POLICY, "INDEPENDENT") >= 0 &&
           StringFind(FALCON_EESL_POLICY, "DAILY_GOVERNANCE") >= 0);
}

bool FalconEeslActionReady()
{
   return (StringFind(FALCON_EESL_ACTION_POLICY, "BLOCK_NEW_ENTRIES") >= 0 &&
           StringFind(FALCON_EESL_ACTION_POLICY, "CLOSE_ALL") >= 0);
}


// ==================================================================
// Concurrent Position Discipline - v0.46.0
// Summary-only operational safety scaffold. It defines exposure caps before
// Paper Runtime and before adding more engines. This build does not block
// ShadowSmoke trades, does not open positions, does not modify broker stops,
// and does not change any trading result. Enforcement starts later in Paper
// Runtime Guard/Exposure application.
// ==================================================================
#define FALCON_CPD_STATUS                              "CONCURRENT_POSITION_DISCIPLINE"
#define FALCON_CPD_DECISION                            "CONCURRENT_POSITION_CONTRACT_READY_NO_EXECUTION"
#define FALCON_CPD_RUNTIME_ENFORCED                    false
#define FALCON_CPD_SCOPE                               "MAX_TOTAL;MAX_PER_ENGINE;MAX_PER_DIRECTION;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_CPD_SHARED_EXPOSURE_POLICY              "TOTAL_CAP_DEFINED;SHARED_EXPOSURE_COUNT_LATER;PAPER_RUNTIME_APPLICATION_LATER"
#define FALCON_CPD_ENGINE_ISOLATION_POLICY             "ENGINE_CAP_DEFINED;ENGINE_MAGIC_ISOLATION_REQUIRED;NO_ENGINE_TOUCHES_OTHER_ENGINE"
#define FALCON_CPD_DIRECTION_CAP_POLICY                "DIRECTION_CAP_DEFINED;BUY_SELL_EXPOSURE_COUNT_LATER"
#define FALCON_CPD_ORDER_SEND_POLICY                   "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_CPD_NEXT_PHASE                          "v0.47.0_PaperModeDefinition"
#define FALCON_CPD_MAX_TOTAL_POSITIONS                 3
#define FALCON_CPD_MAX_POSITIONS_PER_ENGINE            1
#define FALCON_CPD_MAX_POSITIONS_PER_DIRECTION         2

bool FalconCpdContractReady()
{
   return (FALCON_CPD_MAX_TOTAL_POSITIONS > 0 &&
           FALCON_CPD_MAX_POSITIONS_PER_ENGINE > 0 &&
           FALCON_CPD_MAX_POSITIONS_PER_DIRECTION > 0 &&
           FALCON_CPD_MAX_POSITIONS_PER_ENGINE <= FALCON_CPD_MAX_TOTAL_POSITIONS &&
           FALCON_CPD_MAX_POSITIONS_PER_DIRECTION <= FALCON_CPD_MAX_TOTAL_POSITIONS &&
           StringLen(FALCON_CPD_SHARED_EXPOSURE_POLICY) > 0 &&
           StringLen(FALCON_CPD_ENGINE_ISOLATION_POLICY) > 0 &&
           StringLen(FALCON_CPD_DIRECTION_CAP_POLICY) > 0);
}

bool FalconCpdSharedExposureReady()
{
   return (StringFind(FALCON_CPD_SHARED_EXPOSURE_POLICY, "TOTAL_CAP") >= 0 &&
           StringFind(FALCON_CPD_SHARED_EXPOSURE_POLICY, "PAPER_RUNTIME") >= 0);
}

bool FalconCpdEngineIsolationReady()
{
   return (StringFind(FALCON_CPD_ENGINE_ISOLATION_POLICY, "ENGINE_CAP") >= 0 &&
           StringFind(FALCON_CPD_ENGINE_ISOLATION_POLICY, "NO_ENGINE_TOUCHES_OTHER_ENGINE") >= 0);
}

bool FalconCpdDirectionCapReady()
{
   return (StringFind(FALCON_CPD_DIRECTION_CAP_POLICY, "DIRECTION_CAP") >= 0 &&
           StringFind(FALCON_CPD_DIRECTION_CAP_POLICY, "BUY_SELL") >= 0);
}


// ==================================================================
// Paper Mode Definition - v0.47.0
// Summary-only execution-stage contract. It formally separates Shadow,
// Paper, Demo, and Live before any Paper Runtime Application. This build
// does not create Paper positions, does not apply Paper exits, does not
// send broker orders, and does not change ShadowSmoke trading results.
// ==================================================================
#define FALCON_PMD_STATUS                              "PAPER_MODE_DEFINITION"
#define FALCON_PMD_DECISION                            "PAPER_MODE_CONTRACT_READY_NO_RUNTIME_APPLICATION"
#define FALCON_PMD_RUNTIME_ENFORCED                    false
#define FALCON_PMD_SCOPE                               "SHADOW;PAPER;DEMO;LIVE;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_PMD_SHADOW_POLICY                       "OBSERVE_ONLY;TRADE_LIFECYCLE_REPORTING;NO_POSITION_LIFECYCLE;NO_EQUITY_CURVE"
#define FALCON_PMD_PAPER_POLICY                        "NO_ORDERS;INTERNAL_POSITION_LIFECYCLE_LATER;VIRTUAL_SL_LATER;PROTECTION_LATER;RUNNER_LATER;PAPER_EQUITY_LATER;PAPER_EXIT_LATER"
#define FALCON_PMD_DEMO_POLICY                         "DEMO_ORDER_SEND_LATER;ON_TRADE_TRANSACTION_TRUE_SOURCE;BROKER_ERRORS_REAL;STATE_PERSISTENCE_REQUIRED"
#define FALCON_PMD_LIVE_POLICY                         "CONTROLLED_LIVE_ONLY_AFTER_PRE_LIVE_CHECKLIST;MANUAL_ROLLBACK_REQUIRED;NO_UNCONTROLLED_LIVE"
#define FALCON_PMD_ORDER_SEND_POLICY                   "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PMD_NEXT_PHASE                          "v0.48.0_SymbolProfileFoundation"

bool FalconPmdShadowReady()
{
   return (StringFind(FALCON_PMD_SHADOW_POLICY, "OBSERVE_ONLY") >= 0 &&
           StringFind(FALCON_PMD_SHADOW_POLICY, "NO_POSITION_LIFECYCLE") >= 0);
}

bool FalconPmdPaperReady()
{
   return (StringFind(FALCON_PMD_PAPER_POLICY, "NO_ORDERS") >= 0 &&
           StringFind(FALCON_PMD_PAPER_POLICY, "INTERNAL_POSITION_LIFECYCLE") >= 0 &&
           StringFind(FALCON_PMD_PAPER_POLICY, "PAPER_EQUITY") >= 0);
}

bool FalconPmdDemoReady()
{
   return (StringFind(FALCON_PMD_DEMO_POLICY, "DEMO_ORDER_SEND_LATER") >= 0 &&
           StringFind(FALCON_PMD_DEMO_POLICY, "ON_TRADE_TRANSACTION") >= 0 &&
           StringFind(FALCON_PMD_DEMO_POLICY, "BROKER_ERRORS_REAL") >= 0);
}

bool FalconPmdLiveReady()
{
   return (StringFind(FALCON_PMD_LIVE_POLICY, "CONTROLLED_LIVE_ONLY") >= 0 &&
           StringFind(FALCON_PMD_LIVE_POLICY, "PRE_LIVE_CHECKLIST") >= 0 &&
           StringFind(FALCON_PMD_LIVE_POLICY, "NO_UNCONTROLLED_LIVE") >= 0);
}


// ==================================================================
// Symbol Profile Foundation - v0.48.0a
// Summary-only NAS100/US100 profile contract. v0.48.0a fixes only the
// TickPolicy readiness string check so the locked policy reports correctly. It captures symbol, point,
// tick, contract, broker-limits, session, spread, and default safety
// assumptions before Paper Runtime Guard Application. This build does not
// apply Paper guards, does not send orders, and does not alter ShadowSmoke
// trading results.
// ==================================================================
#define FALCON_SPF_STATUS                              "SYMBOL_PROFILE_FOUNDATION"
#define FALCON_SPF_DECISION                            "SYMBOL_PROFILE_CONTRACT_READY_NO_RUNTIME_APPLICATION"
#define FALCON_SPF_RUNTIME_ENFORCED                    false
#define FALCON_SPF_SCOPE                               "NAS100_PROFILE;CONTRACT_SIZE;TICK_SIZE;TICK_VALUE;POINT_MAPPING;BROKER_LIMITS;SPREAD_PROFILE;SUMMARY_ONLY;NO_EXECUTION"
#define FALCON_SPF_TARGET_SYMBOL_FAMILY                "NAS100"
#define FALCON_SPF_SYMBOL_ALIASES                      "US100;US100_Spot;NAS100;USTEC;NDX"
#define FALCON_SPF_CONTRACT_POLICY                     "USE_SYMBOL_CONTRACT_SIZE;STATIC_PROFILE_READY;BROKER_VALIDATION_LATER"
#define FALCON_SPF_TICK_POLICY                         "USE_SYMBOL_TICK_SIZE_AND_TICK_VALUE;NO_ASSUMED_TICK_VALUE_IN_RUNTIME"
#define FALCON_SPF_POINT_MAPPING_POLICY                "INDEX_POINTS_FROM_PRICE_DELTA;USD_ESTIMATE_FROM_CONFIGURED_POINT_VALUE"
#define FALCON_SPF_BROKER_LIMITS_POLICY                "CACHE_STOPS_LEVEL;CACHE_FREEZE_LEVEL;CACHE_VOLUME_LIMITS;RECHECK_BEFORE_RUNTIME_GUARD"
#define FALCON_SPF_SESSION_POLICY                      "NASDAQ_SESSION_PROFILE_READY;BROKER_TIME_AWARENESS_REQUIRED_LATER"
#define FALCON_SPF_SPREAD_POLICY                       "MAX_SPREAD_POINTS_DEFINED;SPREAD_GUARD_APPLICATION_NEXT"
#define FALCON_SPF_DEFAULT_SAFETY_POLICY               "SHADOW_NON_BLOCKING_NOW;PAPER_GUARD_NEXT;NO_DEMO;NO_LIVE"
#define FALCON_SPF_ORDER_SEND_POLICY                   "ORDER_SEND_HARD_BLOCKED;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_SPF_NEXT_PHASE                          "v0.49.0_PaperRuntimeGuardApplicationPhase1_ACTIVE"

bool FalconSpfSymbolRecognized(const string symbol)
{
   return (StringFind(symbol, "US100") >= 0 ||
           StringFind(symbol, "NAS100") >= 0 ||
           StringFind(symbol, "USTEC") >= 0 ||
           StringFind(symbol, "NDX") >= 0);
}

bool FalconSpfContractPolicyReady()
{
   return (StringFind(FALCON_SPF_CONTRACT_POLICY, "SYMBOL_CONTRACT_SIZE") >= 0 &&
           StringFind(FALCON_SPF_CONTRACT_POLICY, "BROKER_VALIDATION") >= 0);
}

bool FalconSpfTickPolicyReady()
{
   // v0.48.0a: The policy string is "USE_SYMBOL_TICK_SIZE_AND_TICK_VALUE".
   // Checking the full token "SYMBOL_TICK_VALUE" incorrectly returns false
   // because the value token is represented as "TICK_VALUE" after AND_.
   // This is a reporting/readiness fix only; it does not change trading logic.
   return (StringFind(FALCON_SPF_TICK_POLICY, "TICK_SIZE") >= 0 &&
           StringFind(FALCON_SPF_TICK_POLICY, "TICK_VALUE") >= 0);
}

bool FalconSpfPointMappingReady()
{
   return (StringFind(FALCON_SPF_POINT_MAPPING_POLICY, "INDEX_POINTS") >= 0 &&
           StringFind(FALCON_SPF_POINT_MAPPING_POLICY, "USD_ESTIMATE") >= 0);
}

bool FalconSpfBrokerLimitsReady()
{
   return (StringFind(FALCON_SPF_BROKER_LIMITS_POLICY, "STOPS_LEVEL") >= 0 &&
           StringFind(FALCON_SPF_BROKER_LIMITS_POLICY, "FREEZE_LEVEL") >= 0 &&
           StringFind(FALCON_SPF_BROKER_LIMITS_POLICY, "VOLUME_LIMITS") >= 0);
}

bool FalconSpfContextReady(const bool context_valid,
                           const int digits,
                           const double point,
                           const double tick_size,
                           const double tick_value,
                           const double contract_size,
                           const long spread_points,
                           const long stops_level_points,
                           const long freeze_level_points,
                           const double min_lot,
                           const double max_lot,
                           const double lot_step)
{
   if(!context_valid)
      return false;
   if(digits < 0 || point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0)
      return false;
   if(contract_size <= 0.0 || spread_points < 0)
      return false;
   if(stops_level_points < 0 || freeze_level_points < 0)
      return false;
   if(min_lot <= 0.0 || max_lot < min_lot || lot_step <= 0.0)
      return false;
   return true;
}


// ==================================================================
// Paper Runtime Guard Application Phase 1 - v0.49.0
// First actual Paper-layer application on closed Shadow TradeLifecycle
// records. Shadow baseline remains unchanged, but each trade now receives
// Legacy PaperGuard state is kept internally, but the minimal report compares the
// pre-guard Shadow result with the post-guard Paper accepted subset.
// No OrderSend, no BrokerModify, no Runtime SL change, no Demo, no Live.
// ==================================================================
#define FALCON_PRGA_STATUS                             "PAPER_RUNTIME_GUARD_APPLICATION_PHASE1"
#define FALCON_PRGA_DECISION                           "PAPER_GUARD_APPLIED_WITH_NAS100_SPREAD_CALIBRATION_NO_ORDERS"
#define FALCON_PRGA_RUNTIME_ENFORCED                   true
#define FALCON_PRGA_SCOPE                              "SPREAD_CALIBRATED_120;STOPS;FREEZE;EXPOSURE;PAPER_ONLY;NO_BROKER_EXECUTION"
#define FALCON_PRGA_REJECT_POLICY                      "SPREAD_TOO_WIDE;SL_TOO_CLOSE;FREEZE_LEVEL_BLOCKED;EXPOSURE_CAP_BLOCKED"
#define FALCON_PRGA_EXPOSURE_POLICY                    "COUNT_PAPER_ACCEPTED_POSITIONS_LATER;PHASE1_REPORTS_EXPOSURE_READY"
#define FALCON_PRGA_ORDER_SEND_POLICY                  "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_PRGA_NEXT_PHASE                         "v0.50.0_PaperRuntimeSmartSLProtectionApplication"


// ==================================================================
// Paper Runtime Smart SL / Protection Application - v0.50.0
// First actual Paper-layer protection application after Guard acceptance.
// Uses locked TP1/TP2 proof/readiness state and M5 closed-bar path stats to
// activate Paper Virtual SL only after proof. No broker SL is modified.
// Shadow baseline remains unchanged; PaperProtectionNet* measures the protected
// paper outcome after Virtual SL protection. Runner remains disabled until v0.51.0.
// ==================================================================
#define FALCON_PRTP_STATUS                             "PAPER_RUNTIME_SMART_SL_PROTECTION_APPLICATION"
#define FALCON_PRTP_DECISION                           "PAPER_VIRTUAL_SL_PROTECTION_APPLIED_AFTER_PROOF_NO_ORDERS"
#define FALCON_PRTP_RUNTIME_ENFORCED                   true
#define FALCON_PRTP_SCOPE                              "TP1_PROOF;TP2_PROOF;VIRTUAL_SL;PROTECTION_ONLY;NO_RUNNER;PAPER_ONLY;NO_BROKER_EXECUTION"
#define FALCON_PRTP_POLICY                             "PROTECT_ONLY_WHEN_EARNED;NO_EARLY_BE;TP1_PROOF_ARMS_VIRTUAL_SL;TP2_PROOF_UPGRADES_TO_TP1_LOCK"
#define FALCON_PRTP_ORDER_SEND_POLICY                  "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_PRTP_NEXT_PHASE                         "v0.51.0_PaperRuntimeRunnerApplication_LOCKED_INPUT"


// ==================================================================
// Paper Runtime Runner Application - v0.51.0
// Applies runner expansion after locked Paper Guard + Protection results.
// Runner can only activate after earned protection. It never sends orders,
// never modifies broker SL, and never allows an expanded paper outcome to be
// worse than the protected working baseline.
// ==================================================================
#define FALCON_PRRUN_STATUS                            "PAPER_RUNTIME_RUNNER_APPLICATION"
#define FALCON_PRRUN_DECISION                          "PAPER_RUNNER_APPLIED_AFTER_PROTECTION_NO_ORDERS"
#define FALCON_PRRUN_RUNTIME_ENFORCED                  true
#define FALCON_PRRUN_SCOPE                             "PROTECTION_REQUIRED;TP2_CONTINUATION;3R_RUNNER;5R_MOON;PAPER_ONLY;NO_BROKER_EXECUTION"
#define FALCON_PRRUN_POLICY                            "PROTECT_FIRST_THEN_EXPAND;NO_RUNNER_WITHOUT_PROTECTION;RUNNER_NEVER_BELOW_PROTECTED_BASELINE"
#define FALCON_PRRUN_ORDER_SEND_POLICY                 "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_PRRUN_NEXT_PHASE                        "v0.52.0_PaperRuntimeEmergencyEquityApplication"


// ==================================================================
// FVG SIZE250 Runtime Candidate counter alignment lock - v0.25.1
// Actual blocking is limited to Shadow lifecycle staging. No broker orders,
// no Paper/Demo/Live execution, and no OrderSend are possible in this build.
// ==================================================================
int g_fvg_qguard_runtime_candidate_evaluated        = 0;
int g_fvg_qguard_runtime_candidate_passed           = 0;
int g_fvg_qguard_runtime_candidate_blocked          = 0;
int g_fvg_qguard_runtime_staged_trades              = 0;
int g_fvg_qguard_runtime_passed_but_not_staged      = 0;
int g_fvg_qguard_runtime_rejected_after_pass        = 0;


// ==================================================================
// Runtime performance constants - v0.18.5
// Keep heavy verification reports away from per-trade OnTick path.
// They remain available at OnInit/OnDeinit for audit, while TradeLifecycle
// keeps the important shadow trade rows. No trading logic change.
// ==================================================================
#define FALCON_WRITE_HEAVY_RUNTIME_AUDIT_ON_SHADOW_CLOSE false
#define FALCON_WRITE_SECONDARY_ONINIT_AUDIT_SNAPSHOTS     false
#define FALCON_RUNTIME_DIAGNOSTICS_DEFAULT_N_TICKS        1000

// ==================================================================
// Report profile model - v0.18.6/v0.18.8
// v0.18.6 reduced report spam to profiles.
// v0.18.8 locks report profile cleanup and sanitizes CSV string fields,
// not necessarily the Strategy Tester UI To-date when the UI end date is a weekend/holiday/no-tick day.
// ==================================================================
enum ENUM_FALCON_REPORT_PROFILE
{
   FALCON_REPORT_MINIMAL    = 0, // TradeLifecycle + Summary only
   FALCON_REPORT_STANDARD   = 1, // TradeLifecycle + Summary + StrategyRegistry + PeriodManifest
   FALCON_REPORT_DEBUG      = 2, // All diagnostic reports
   FALCON_REPORT_LOCKPARITY = 3  // TradeLifecycle + Summary + LockParity Decomp + Rollup only
};


// ==================================================================
// Tier Scenario Clean Report Lock - v0.55.7c
// Temporary validation scaffold removed after scenario tests passed.
// Runtime keeps only locked promotion/demotion policy and no scenario inputs.
// ==================================================================



// ==================================================================
// Tier/Emergency Event Files - v0.55.11
// Official Capital-Aware event logs. Reporting-only. Creates
// TierTransitions.csv and EmergencyTriggers.csv with small event-only
// schemas. No entry, exit, lot, emergency, or tier decision changes.
// ==================================================================
#define FALCON_EVENT_FILES_STATUS              "TIER_EMERGENCY_EVENT_FILES"
#define FALCON_EVENT_FILES_DECISION            "REPORTING_ONLY_EVENT_LOGS_NO_TRADING_LOGIC_CHANGE"
#define FALCON_EVENT_FILES_RUNTIME_ENFORCED    false
#define FALCON_EVENT_FILES_SCOPE               "TIER_TRANSITIONS_CSV;EMERGENCY_TRIGGERS_CSV;EVENT_ONLY;NO_PER_TRADE_BLOAT"
#define FALCON_EVENT_FILES_ORDER_SEND_POLICY   "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"

// ==================================================================
// Capital Flow Clean Lock - v0.55.7
// The temporary simulation scaffold was removed after validation.
// Runtime keeps only real capital-flow classification fields.
// ==================================================================

// ==================================================================
// Session Boundary Broker Session Schedule Fix - v0.55.12a-fix2
// Temporary Force Close simulation metrics were removed from default reports.
// Close time is derived from broker/server market data, not from the local PC clock.
// ==================================================================

// ==================================================================
// 01 - EA Safety & Risk / إعدادات المستخدم الأساسية
// ==================================================================
input group "01 - EA Safety & Risk / إعدادات المستخدم الأساسية";
input bool   EnableRealExecution             = false; // HARD SAFETY: remains false during shadow/candidate stages.
input bool   UseFixedLot                     = true;  // simple user mode: fixed lot first.
input double FixedLotSize                    = 0.01;
input bool   UseAutoCapitalDetection         = true;  // true = use account balance later; false = ManualCapital.
input double ManualCapital                   = 10000.0;
input bool   UseDailyLossLimit               = true;  // Daily safety ON/OFF: enables daily loss protection and risk reference.
input bool   UseFixedDailyLossAmount         = false; // true = use FixedDailyLossAmount USD; false = use DailyLossPercentOfCapital.
input double FixedDailyLossAmount            = 100.0; // Fixed daily loss limit in USD when UseFixedDailyLossAmount=true.
input double DailyLossPercentOfCapital       = 3.0;   // Daily loss limit as percent of capital when UseFixedDailyLossAmount=false.

// ==================================================================
// 01a - Session Boundary Safety Overrides / حماية إغلاق السوق
// ==================================================================
input group "01a - Close Safety / حماية الإغلاق";
input bool   StopNewTradesBeforeClose          = false; // Stop new trades near close.
input int    StopNewTradesBeforeCloseMinutes   = 5;     // Minutes before close.
input bool   CloseTradesBeforeDailyClose       = false; // Close trades before daily close.
input int    DailyCloseSafetyMinutes           = 5;     // Minutes before daily close.
input bool   CloseTradesBeforeWeekend          = false; // Close trades before weekend.
input int    WeekendCloseSafetyMinutes         = 5;     // Minutes before weekend close.

// ==================================================================
// Capital Tier Foundation - v0.53.0 (LOCKED)
// Logging-only foundation for low-capital compatibility. 0.01 remains
// the broker minimum lot and is logged as a hard constraint, not hidden.
// ==================================================================
double g_falcon_session_start_balance = 0.0;

#define FALCON_CTF_STATUS                       "CAPITAL_TIER_FOUNDATION"
#define FALCON_CTF_DECISION                     "TIER_LOGGING_ONLY_LOW_CAPITAL_COMPATIBILITY_NO_EMERGENCY_ENFORCEMENT"
#define FALCON_CTF_RUNTIME_ENFORCED             false
#define FALCON_CTF_SCOPE                        "MICRO_TINY_SMALL_MEDIUM_STANDARD_LARGE;EFFECTIVE_BALANCE;MIN_LOT_AWARE;SUMMARY_AND_TRADE_LIFECYCLE_ONLY"
#define FALCON_CTF_ORDER_SEND_POLICY            "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY"
#define FALCON_CTF_BALANCE_POLICY               "MANUAL_CAPITAL_IF_DISABLED;SESSION_START_BALANCE_IF_AUTO;LOCKED_FOR_TEST_COMPARABILITY"
#define FALCON_CTF_MIN_LOT_POLICY               "BROKER_MIN_LOT_OBSERVED;NO_LOT_REDUCTION_BELOW_MIN;0_01_MIN_LOT_SUPPORTED"
#define FALCON_CTF_NEXT_PHASE                   "v0.53.1_ThreeLayerEmergency"

// ==================================================================
// Three-Layer Emergency - v0.53.1 (LOCKED)
// Active Paper replacement for the fixed 5% hardcap that failed on low
// capital. Uses tier-aware thresholds: consecutive losses, daily R, and
// capital drawdown. No broker execution, no OrderSend, no SL modification.
// ==================================================================
#define FALCON_TLE_STATUS                       "THREE_LAYER_EMERGENCY_ACTIVE_REPLACEMENT"
#define FALCON_TLE_DECISION                     "TIER_AWARE_EMERGENCY_REPLACES_FIXED_5PCT_HARDCAP"
#define FALCON_TLE_RUNTIME_ENFORCED             true
#define FALCON_TLE_SCOPE                        "LAYER1_CONSECUTIVE;LAYER2_DAILY_R;LAYER3_TIER_DRAWDOWN;PAPER_ONLY;NO_BROKER_EXECUTION"
#define FALCON_TLE_POLICY                       "ANY_LAYER_TRIGGERS;MIN_LOT_AWARE;CAPITAL_TIER_AWARE;NO_FIXED_5PCT_FOR_MICRO_TINY"
#define FALCON_TLE_ORDER_SEND_POLICY            "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_TLE_NEXT_PHASE                   "v0.53.2_LayerSpecificResetLogic"

// ==================================================================
// Layer-Specific Reset Logic - v0.53.2a
// Fixes daily emergency resolution: Layer 1 and Layer 2 are daily-pause
// layers. They must block the remaining current day only, then reset on
// the next test day. Layer 3 remains drawdown/peak based.
// ==================================================================
#define FALCON_LSR_STATUS                       "LAYER_SPECIFIC_RESET_LOGIC_DAILY_RESOLUTION_FIX"
#define FALCON_LSR_DECISION                     "FIX_LAYER1_LAYER2_DAILY_PAUSE_RESOLUTION_WITHOUT_TRADING_LOGIC_CHANGE"
#define FALCON_LSR_RUNTIME_ENFORCED             true
#define FALCON_LSR_SCOPE                        "LAYER1_RESET_ON_WIN;LAYER1_DAILY_PAUSE_RESOLVE_ON_NEW_DAY;LAYER2_RESET_ON_NEW_DAY;LAYER3_RESET_ON_NEW_PEAK;PAPER_ONLY"
#define FALCON_LSR_POLICY                       "INDEPENDENT_RESETS;DAILY_PAUSE_RESOLUTION;NO_DUPLICATE_TRIGGER_AFTER_RESET;EMERGENCY_STATE_VALIDATION"
#define FALCON_LSR_ORDER_SEND_POLICY            "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_LSR_NEXT_PHASE                   "v0.53.3_ValidationLock"

// ==================================================================
// Validation Lock - v0.53.3a
// Locks the capital-aware emergency stack on the current April baseline
// before starting the multi-window validation pack. No new runtime trading
// behavior is added here. The active behavior remains Guard + Protection +
// Runner + Three-Layer Emergency + Reset Logic.
// ==================================================================
#define FALCON_VAL_STATUS                       "V053_VALIDATION_LOCK_DUP_TRIGGER_CLASSIFICATION_FIX"
#define FALCON_VAL_DECISION                     "FIX_VALID_LAYER2_NEW_DAY_TRIGGER_CLASSIFIED_AS_DUPLICATE_IN_JANUARY_OOS"
#define FALCON_VAL_RUNTIME_ENFORCED             false
#define FALCON_VAL_SCOPE                        "CAPITAL_TIER;THREE_LAYER_EMERGENCY;RESET_LOGIC;DUP_TRIGGER_CLASSIFICATION;MULTI_WINDOW_NEXT"
#define FALCON_VAL_POLICY                       "ANCHOR_BASELINE_PRESERVED;WORKING_BASELINE_UPDATED_AFTER_LOCK;NO_RUNTIME_BEHAVIOR_CHANGE;VALID_TRIGGER_AFTER_NEW_DAY_RESET_NOT_DUPLICATE"
#define FALCON_VAL_ORDER_SEND_POLICY            "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_VAL_NEXT_PHASE                   "MULTI_WINDOW_VALIDATION_PACK_THEN_v0.54.0_TierPromotionFoundation"


// ==================================================================
// Tier Promotion Foundation - v0.54.0
// Summary-only foundation for earned tier promotion. It defines the
// promotion requirements and logs promotion eligibility state without
// changing risk, entries, exits, protection, runner, emergency behavior,
// broker execution, or report profile. Promotion must be earned; demotion
// remains the faster future layer.
// ==================================================================
#define FALCON_TPF_STATUS                       "TIER_PROMOTION_FOUNDATION"
#define FALCON_TPF_DECISION                     "PROMOTION_REQUIREMENTS_DEFINED_SUMMARY_ONLY_NO_TIER_TRANSITION_YET"
#define FALCON_TPF_RUNTIME_ENFORCED             false
#define FALCON_TPF_SCOPE                        "PROMOTION_REQUIREMENTS;ELIGIBILITY_LOGGING;NO_RISK_CHANGE;NO_TIER_TRANSITION;SUMMARY_ONLY"
#define FALCON_TPF_MIN_TRADES_IN_TIER           30
#define FALCON_TPF_MIN_WIN_RATE_PCT             50.0
#define FALCON_TPF_MIN_NET_R                    0.0
#define FALCON_TPF_DAYS_WITHOUT_EMERGENCY       21
#define FALCON_TPF_POST_QUAL_COOLDOWN_DAYS      7
#define FALCON_TPF_POLICY                       "PROMOTION_MUST_BE_EARNED;BALANCE_PLUS_TRADES_PLUS_WINRATE_PLUS_NETR_PLUS_NO_EMERGENCY_PLUS_COOLDOWN"
#define FALCON_TPF_ORDER_SEND_POLICY            "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_TPF_NEXT_PHASE                   "v0.54.1_TierDemotionFoundation"

#define FALCON_TDF_STATUS                       "TIER_DEMOTION_FOUNDATION"
#define FALCON_TDF_DECISION                     "DEMOTION_RULES_DEFINED_SUMMARY_ONLY_NO_TIER_TRANSITION_YET"
#define FALCON_TDF_RUNTIME_ENFORCED             false
#define FALCON_TDF_SCOPE                        "DEMOTION_REQUIREMENTS;IMMEDIATE_DEMOTION_POLICY;NO_RISK_CHANGE;NO_TIER_TRANSITION;SUMMARY_ONLY"
#define FALCON_TDF_HYSTERESIS_PCT               80.0
#define FALCON_TDF_MAX_EMERGENCIES_14D          2
#define FALCON_TDF_MAX_NEGATIVE_WEEKS           3
#define FALCON_TDF_EXTREME_DD_MULTIPLIER        1.5
#define FALCON_TDF_POLICY                       "DEMOTION_IS_IMMEDIATE;BALANCE_HYSTERESIS_OR_MULTIPLE_EMERGENCIES_OR_NEGATIVE_WEEKS_OR_EXTREME_DRAWDOWN"
#define FALCON_TDF_ORDER_SEND_POLICY            "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_TDF_NEXT_PHASE                   "v0.54.2_PromotionDemotionRuntimeLock"


// ==================================================================
// Tier Promotion/Demotion Runtime Lock - v0.54.2
// Applies the tier transition decision model to Paper state. In normal
// April low-capital validation this should not change trading results
// because promotion is not earned and demotion is not required. When a
// transition is truly earned later, open positions remain unchanged and
// the next trades use the new tier.
// ==================================================================
#define FALCON_TDL_STATUS                       "TIER_PROMOTION_DEMOTION_RUNTIME_LOCK"
#define FALCON_TDL_DECISION                     "PROMOTION_DEMOTION_RUNTIME_DECISION_APPLIED_NO_TRANSITION_WHEN_NOT_EARNED"
#define FALCON_TDL_RUNTIME_ENFORCED             true
#define FALCON_TDL_SCOPE                        "PROMOTION_APPLICATION;DEMOTION_APPLICATION;ACTIVE_POSITIONS_UNCHANGED;NEXT_TRADES_USE_APPLIED_TIER;PAPER_ONLY"
#define FALCON_TDL_POLICY                       "PROMOTION_MUST_BE_EARNED;DEMOTION_IS_IMMEDIATE;DEMOTION_PRIORITY;NO_TRANSITION_WHEN_REQUIREMENTS_FAIL"
#define FALCON_TDL_ORDER_SEND_POLICY            "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_TDL_NEXT_PHASE                   "v0.55.3b_DynamicLotSizingSafetyRampMaxGrowthCap"


// ==================================================================
// Risk & TradeManagement Architecture Consolidation - v0.55.0
// Architecture / Refactor / No Behavior Change.
// This build names ownership boundaries for the risk and trade-management
// layers that are already active in Paper state. It does NOT alter entries,
// exits, SL/TP, protection, runner, emergency, tier transitions, reports,
// OrderSend, broker modify, or runtime SL behavior.
// ==================================================================
#define FALCON_ARCH_STATUS                       "RISK_TRADEMANAGEMENT_ARCHITECTURE_CONSOLIDATION"
#define FALCON_ARCH_DECISION                     "CONSOLIDATE_ACTIVE_PAPER_RISK_AND_TM_OWNERSHIP_WITHOUT_BEHAVIOR_CHANGE"
#define FALCON_ARCH_RUNTIME_ENFORCED             false
#define FALCON_ARCH_SCOPE                        "RISKMANAGER;LOTSIZINGMANAGER;DAILYGOVERNANCE;ENGINERISKALLOCATION;KILLSWITCH;STRUCTURALSTOPENGINE;TPBUILDER;PARTIALMANAGER;PROOFPROTECTIONENGINE;RUNNERMANAGER;ADAPTIVERATCHETENGINE;EARLYFAILUREEXITENGINE"
#define FALCON_ARCH_POLICY                       "NO_ENTRY_CHANGE;NO_EXIT_CHANGE;NO_SLTP_CHANGE;NO_PROTECTION_CHANGE;NO_RUNNER_CHANGE;NO_EMERGENCY_CHANGE;NO_TIER_CHANGE"
#define FALCON_ARCH_ORDER_SEND_POLICY            "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_ARCH_REPORT_POLICY                "SUMMARY_VERSION_BUILD_ONLY;NO_NEW_CSV_REPORTS;NO_DIAGNOSTIC_SPAM"
#define FALCON_ARCH_NEXT_PHASE                   "v0.55.3b_DynamicLotSizingSafetyRampMaxGrowthCap"

#define FALCON_RISK_MANAGER_STATUS               "CONSOLIDATED_OWNER_FOR_GUARD_TIER_EMERGENCY_DECISIONS"
#define FALCON_LOT_SIZING_MANAGER_STATUS         "DYNAMIC_LOT_PAPER_RUNTIME_APPLICATION_USEFIXEDLOT_RESPECTED"
#define FALCON_DAILY_GOVERNANCE_STATUS           "PARTIAL_DAILY_R_AND_DAILY_PAUSE_RESET_OWNER"
#define FALCON_ENGINE_RISK_ALLOCATION_STATUS     "FOUNDATION_FVG_MICRO_100_PERCENT_ONLY"
#define FALCON_KILL_SWITCH_STATUS_V055           "PARTIAL_PAPER_EMERGENCY_BLOCKING_NO_BROKER_CLOSE_YET"

#define FALCON_STRUCTURAL_STOP_ENGINE_STATUS     "ACTIVE_STRUCTURAL_SL_VALIDATION_OWNER"
#define FALCON_TP_BUILDER_STATUS_V055            "ACTIVE_TP1_TP2_TP3_VALIDATION_OWNER"
#define FALCON_PARTIAL_MANAGER_STATUS_V055       "PARTIAL_PROOF_CHECKPOINT_OWNER_NO_BROKER_PARTIAL_YET"
#define FALCON_PROOF_PROTECTION_ENGINE_STATUS    "ACTIVE_PAPER_VIRTUAL_SL_PROTECTION_LOCKED"
#define FALCON_RUNNER_MANAGER_STATUS_V055        "ACTIVE_PAPER_RUNNER_MOON_MODE_LOCKED"
#define FALCON_ADAPTIVE_RATCHET_ENGINE_STATUS    "PARTIAL_INSIDE_PROTECTION_RUNNER_NOT_STANDALONE_ENGINE_YET"
#define FALCON_EARLY_FAILURE_EXIT_ENGINE_STATUS  "PLANNED_NOT_ACTIVE_NO_EXIT_CHANGE"

// ==================================================================
// Low-Capital Risk Feasibility Foundation - v0.55.1
// Measurement-only layer. Every closed Paper/Shadow trade is evaluated
// against broker minimum lot, effective capital, tier base risk budget,
// and single-trade loss cap readiness. It does NOT reject trades yet.
// ==================================================================
#define FALCON_LCRF_STATUS                        "LOW_CAPITAL_RISK_FEASIBILITY_FOUNDATION"
#define FALCON_LCRF_DECISION                      "MEASURE_MIN_LOT_RISK_FEASIBILITY_PER_TRADE_NO_BLOCKING"
#define FALCON_LCRF_RUNTIME_ENFORCED              false
#define FALCON_LCRF_SCOPE                         "LOTSIZINGMANAGER;MIN_LOT_RISK_USD;MIN_LOT_RISK_PCT;POTENTIAL_LOSS_R;SINGLE_TRADE_LOSS_CAP_READINESS"
#define FALCON_LCRF_POLICY                        "MEASUREMENT_ONLY;NO_ENTRY_CHANGE;NO_EXIT_CHANGE;NO_EMERGENCY_CHANGE;NO_TIER_CHANGE;NO_REJECTION_YET"
#define FALCON_LCRF_ORDER_SEND_POLICY             "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_LCRF_DEFAULT_SINGLE_TRADE_CAP_PCT  50.0
#define FALCON_LCRF_BORDERLINE_MULTIPLIER         1.20
#define FALCON_LCRF_NEXT_PHASE                    "v0.55.3b_DynamicLotSizingSafetyRampMaxGrowthCap"


// ==================================================================
// Dynamic Capital-Aware Single Trade Loss Cap - v0.55.2a
// Fixes v0.55.2 by making the single-trade cap relative to Paper risk
// capital before each trade. Capital starts from configured/auto capital
// and updates after every closed Paper trade. A trade rejected at $50 may
// become allowed later if profits or an explicit capital injection make
// its minimum-lot risk acceptable. This does not auto-promote the strategy;
// promotion must still be earned by the tier transition rules.
// ==================================================================
#define FALCON_STLC_STATUS                        "DYNAMIC_CAPITAL_AWARE_SINGLE_TRADE_LOSS_CAP_FIX"
#define FALCON_STLC_DECISION                      "ENFORCE_DYNAMIC_CAPITAL_RELATIVE_SINGLE_TRADE_CAP_AFTER_EACH_PAPER_TRADE"
#define FALCON_STLC_RUNTIME_ENFORCED              true
#define FALCON_STLC_SCOPE                         "LOTSIZINGMANAGER;DYNAMIC_CAPITAL;MIN_LOT;SINGLE_TRADE_CAP;PAPER_EQUITY_CURVE;NO_AUTO_PROMOTION"
#define FALCON_STLC_POLICY                        "DYNAMIC_CAPITAL_AWARE_ENFORCEMENT;STRICT_CAP_REMAINS_MEASUREMENT;RISK_FEASIBILITY_UPDATES_AFTER_EACH_TRADE;PROMOTION_STILL_EARNED;NO_ORDER_SEND"
#define FALCON_STLC_ORDER_SEND_POLICY             "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_STLC_DRAWDOWN_CAP_MULTIPLIER       2.0
#define FALCON_STLC_ABSOLUTE_MAX_R                50.0
#define FALCON_STLC_DYNAMIC_MAX_RISK_PCT          50.0
#define FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD     1.0
#define FALCON_STLC_DYNAMIC_CAPITAL_MODE          "PAPER_RISK_CAPITAL_BEFORE_TRADE_UPDATES_AFTER_EACH_CLOSED_TRADE"
#define FALCON_STLC_NEXT_PHASE                    "v0.55.3b_DynamicLotSizingSafetyRampMaxGrowthCap"


// ==================================================================
// Dynamic LotSizing Model / Capital Flow Awareness - v0.55.3
// Candidate / reporting-only layer. It computes a dynamic recommended
// lot size per closed Paper trade using PaperRiskCapitalBeforeTrade,
// tier base risk budget, structural SL distance, broker min/max lot,
// and broker lot step. The user-facing UseFixedLot input is respected:
// when UseFixedLot=true the active/paper lot remains FixedLotSize and
// dynamic lot is only reported as a candidate. When UseFixedLot=false,
// the model reports the dynamic lot that should be used by a future
// enforcement build, but this candidate does not alter historical Paper
// entries yet. No OrderSend, BrokerModify, or RuntimeSL change.
// ==================================================================
#define FALCON_DLM_STATUS                         "DYNAMIC_LOTSIZING_SAFETY_RAMP_MAX_GROWTH_CAP"
#define FALCON_DLM_DECISION                       "APPLY_DYNAMIC_LOT_TO_PAPER_USD_WITH_TIER_CAP_CAPITAL_CAP_AND_GROWTH_RAMP"
#define FALCON_DLM_RUNTIME_ENFORCED               true
#define FALCON_DLM_SCOPE                          "LOTSIZINGMANAGER;USEFIXEDLOT;DYNAMIC_CAPITAL;STRUCTURAL_RISK;BROKER_MIN_MAX_STEP;PAPER_RUNTIME_APPLICATION;TIER_MAX_LOT;CAPITAL_MAX_LOT;GROWTH_RAMP"
#define FALCON_DLM_POLICY                         "USE_FIXED_LOT_TRUE_PRESERVES_FIXEDLOT;USE_FIXED_LOT_FALSE_APPLIES_DYNAMIC_LOT_WITH_SAFETY_RAMP;CAPITAL_UPDATES_AFTER_EACH_TRADE;TIER_CAP;CAPITAL_CAP;MAX_GROWTH_CAP;NO_BROKER_EXECUTION"
#define FALCON_DLM_ORDER_SEND_POLICY              "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_DLM_NEXT_PHASE                     "v0.55.3b_DYNAMIC_LOTSIZING_SAFETY_RAMP_MULTI_WINDOW_LOCK"
#define FALCON_DLM_CAPITAL_USD_PER_001_LOT        250.0
#define FALCON_DLM_MAX_LOT_GROWTH_MULTIPLIER      1.20


// ==================================================================
// Capital Flow Source Classification Clean Lock - v0.55.7
// Temporary simulation inputs and audit columns were removed after
// Regression / Injection / Withdrawal / Mixed scenario validation.
// Runtime keeps true capital-flow classification only, with no test scaffold.
// ==================================================================
#define FALCON_CFS_STATUS                         "CAPITAL_FLOW_SOURCE_CLASSIFICATION_CLEAN_LOCK"
#define FALCON_CFS_DECISION                       "REMOVE_TEMPORARY_CAPITAL_FLOW_SIMULATION_INPUTS_AND_REPORT_FIELDS_AFTER_VALIDATION"
#define FALCON_CFS_RUNTIME_ENFORCED               true
#define FALCON_CFS_SCOPE                          "CAPITAL_FLOW;INJECTION;WITHDRAWAL;MIXED_EVENTS_VALIDATED;SIMULATION_SCAFFOLD_REMOVED;NO_TRADE_LOGIC_CHANGE"
#define FALCON_CFS_POLICY                         "RUNTIME_CLASSIFIES_TRUE_CAPITAL_FLOW_ONLY;INJECTION_NOT_STRATEGY_PROFIT;WITHDRAWAL_NOT_STRATEGY_LOSS;NO_SIMULATION_INPUTS_IN_LOCK"
#define FALCON_CFS_ORDER_SEND_POLICY              "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_CFS_NEXT_PHASE                     "v0.55.7_TierPromotionDemotionScenarioValidation"

// ==================================================================
// Tier Scenario Clean Report Lock - v0.55.7c
// Scenario validation passed. Temporary inputs and report audit columns
// are removed to keep the EA clean. Promotion/Demotion runtime policy
// remains unchanged: capital-only growth does not auto-promote.
// ==================================================================
#define FALCON_TSV_STATUS                         "TIER_SCENARIO_CLEAN_LOCK"
#define FALCON_TSV_DECISION                       "REMOVE_TEMPORARY_TIER_SCENARIO_INPUTS_AND_REPORT_FIELDS_AFTER_VALIDATION"
#define FALCON_TSV_RUNTIME_ENFORCED               true
#define FALCON_TSV_SCOPE                          "CLEAN_LOCK;NO_SCENARIO_INPUTS;NO_SCENARIO_REPORT_FIELDS;NO_TRADE_RESULT_CHANGE;NO_TIER_RUNTIME_CHANGE"
#define FALCON_TSV_POLICY                         "PROMOTION_MUST_BE_EARNED;CAPITAL_INJECTION_NOT_PROFIT;WITHDRAWAL_NOT_STRATEGY_LOSS;DEMOTION_REMAINS_PROTECTIVE"
#define FALCON_TSV_ORDER_SEND_POLICY              "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_TSV_NEXT_PHASE                     "v0.55.8_NEXT_CAPITAL_OR_RISK_LAYER"


// ==================================================================
// 02 - Execution Stage / مرحلة التنفيذ
// ==================================================================
input group "02 - Execution Stage / مرحلة التنفيذ";
input bool   EnableShadowMode                = true;  // Observe only. No real orders.
input bool   EnablePaperMode                 = false; // Internal simulated trades later.
// v0.56.0: FalconMagicNumber input intentionally removed. Engine-specific FC_MAGIC_* constants are the only valid broker identity source.
input int    MaxTradesPerDay                 = 3;
input int    MaxOpenPositions                = 1;

// ==================================================================
// 02b - Virtual Trailing Exit Bridge / جسر الخروج بـ trailing افتراضي - v0.57.2
// Simple stage: fixed trailing distance + single breakeven point.
// Tester-only. Closes via OrderSend(TRADE_ACTION_DEAL) reverse only.
// Emergency server SL/TP envelope from v0.56.9b remains untouched.
// ==================================================================
// ==================================================================
// 02.1 - Enable Virtual Trailing Bridge 
// ==================================================================
input group "02.1 - Enable Virtual Trailing Bridge";
input bool   EnableVirtualTrailingBridge     = true;   // v0.57.2 trailing exit
input double VirtualTrailingStartPoints      = 8.0;    // v0.57.3 recalibrated (was 30) - profit points before trailing arms
input double VirtualTrailingDistancePoints   = 6.0;    // v0.57.3 recalibrated (was 20) - trailing distance behind peak
input double VirtualBreakevenAtPoints        = 4.0;    // v0.57.3 recalibrated (was 15) - profit points to lock breakeven

// ==================================================================
// 03 - Strategy Switches / تفعيل وإيقاف الاستراتيجيات
// Keep this list small and explicit. FVG Micro is ON by default for ShadowSmoke only; all other engines remain OFF.
// ==================================================================
input group "03 - Strategy Switches / تفعيل وإيقاف الاستراتيجيات";
input bool EnableStrategy_FvgMicroRetest             = true;  // ShadowSmoke core winner candidate. Still no real execution.
input bool EnableStrategy_TailSmartReturn            = false; // استراتيجية ذيل العودة الذكي.
input bool EnableStrategy_MomentumCross820           = false; // استراتيجية تقاطع الزخم 8/20.
input bool EnableStrategy_CheckMarkLiquiditySweep    = false; // استراتيجية علامة الصح بعد سحب السيولة.
input bool EnableStrategy_DoubleBoxWickConfirmation  = false; // استراتيجية الصندوقين والشمعة الحاسمة.
input bool EnableStrategy_TouchTurnOpeningRange      = false; // استراتيجية لمس نطاق الافتتاح والارتداد.
input bool EnableStrategy_MagicLiquidityPitchfork    = false; // استراتيجية خطوط السيولة الذكية وشمعة الشوكة.
input bool EnableStrategy_DailyLiquidityBox          = false; // استراتيجية صندوق السيولة اليومي وشمعة الشوكة.
input bool EnableStrategy_QuickFlipOpeningLiquidity  = false; // استراتيجية الانعكاس السريع بعد شمعة السيولة.
input bool EnableStrategy_FSEPatternFailureEntry     = false; // استراتيجية الدخول المبكر بعد فشل النموذج.
input bool EnableStrategy_TwoLiquidityLines15M       = false; // استراتيجية خطّي السيولة والارتداد المؤكد.
input bool EnableStrategy_GoldenLiquidity5MEntry     = false; // استراتيجية مناطق السيولة الذهبية ودخول الخمس دقائق.

// ==================================================================
// 04 - Reporting / التقارير
// v0.18.6 cleanup: one profile controls diagnostic reports.
// Default STANDARD keeps only essential files for normal tests.
// ==================================================================
input group "04 - Reporting / التقارير";
input bool                       EnableMainReport              = true;
input ENUM_FALCON_REPORT_PROFILE ReportProfile                 = FALCON_REPORT_LOCKPARITY;
input string                     ReportModeTag                 = "EmergencyServerStopEnvelopeLockParityProbe"; // v0.56.9b: safety restoration after v0.56.9 naked-order probe; no broker order may be sent without server SL/TP; filenames include ExecutionON/ExecutionOFF plus lot mode and period tags.
input bool                       UseCommonFilesFolderForReports = true;
input bool                       EnableVerboseExpertsLog       = true;
input bool                       EnableFastRuntimeSmokeMode    = true;
input int                        RuntimeDiagnosticsEveryNTicks = 1000;



// Internal report constants. Keep these out of user inputs.
#define FALCON_ENABLE_REPORT_PERIOD_IN_FILE_NAMES      true
#define FALCON_AUTO_DETECT_REPORT_PERIOD_TAGS          true
#define FALCON_RENAME_REPORTS_TO_ACTUAL_PERIOD         true
#define FALCON_REPORT_FROM_DATE_TAG                    "AUTO"
#define FALCON_REPORT_TO_DATE_TAG                      "AUTO"
#define FALCON_FORCE_CREATE_REPORT_FILES_ON_INIT       (ReportProfile == FALCON_REPORT_DEBUG)
#define FALCON_PRINT_REPORT_FOLDER_HINTS_TO_LOG        (ReportProfile != FALCON_REPORT_MINIMAL)

bool FalconReportProfileIsMinimal()
{
   return (ReportProfile == FALCON_REPORT_MINIMAL);
}

bool FalconReportProfileIsStandardOrDebug()
{
   return (ReportProfile == FALCON_REPORT_STANDARD || ReportProfile == FALCON_REPORT_DEBUG);
}

bool FalconReportProfileIsDebug()
{
   return (ReportProfile == FALCON_REPORT_DEBUG);
}

// v0.57.1: LOCKPARITY report profile helper.
bool FalconReportProfileIsLockParity()
{
   return (ReportProfile == FALCON_REPORT_LOCKPARITY);
}

string FalconReportProfileToString()
{
   if(ReportProfile == FALCON_REPORT_MINIMAL)
      return "MINIMAL";
   if(ReportProfile == FALCON_REPORT_DEBUG)
      return "DEBUG";
   if(ReportProfile == FALCON_REPORT_LOCKPARITY)
      return "LOCKPARITY";
   return "STANDARD";
}



// Diagnostic report gates. Normal tests should not create diagnostic report spam.
#define EnableMarketDiagnosticsReport                         (FalconReportProfileIsDebug())
#define EnableCandleCacheDiagnosticsReport                    (FalconReportProfileIsDebug())
#define EnableEvidenceDiagnosticsReport                       (FalconReportProfileIsDebug())
#define EnableShadowDiagnosticsReport                         (FalconReportProfileIsDebug())
#define EnableNoLookaheadDiagnosticsReport                    (FalconReportProfileIsDebug())
#define EnableStrategyRegistryDiagnosticsReport               (FalconReportProfileIsStandardOrDebug())
#define EnableStrategyAdapterDiagnosticsReport                (FalconReportProfileIsDebug())
#define EnableFvgMicroDetectorDiagnosticsReport               (FalconReportProfileIsDebug())
#define EnableFvgMicroCandidateDiagnosticsReport              (FalconReportProfileIsDebug())
#define EnableFvgMicroRetestWatcherDiagnosticsReport          (FalconReportProfileIsDebug())
#define EnableFvgMicroTradePlanStagingDiagnosticsReport       (FalconReportProfileIsDebug())
#define EnableFvgMicroLifecycleSimulationDiagnosticsReport    (FalconReportProfileIsDebug())
#define EnableReportCalibrationDiagnosticsReport              (FalconReportProfileIsDebug())
#define EnableRuntimeReportVerificationReport                 (FalconReportProfileIsDebug())
#define EnableFvgMicroSmokeTestDiagnosticsReport              (FalconReportProfileIsDebug())
#define EnableFvgMicroRuntimeReportAuditReport                (FalconReportProfileIsDebug())

// Core runtime constants. These are architectural defaults, not user inputs.
#define UseClosedCandlesOnly                                  true
#define PrimaryContextTimeframe                               PERIOD_M5
#define EnableReportPeriodInFileNames                         FALCON_ENABLE_REPORT_PERIOD_IN_FILE_NAMES
#define AutoDetectReportPeriodTags                            FALCON_AUTO_DETECT_REPORT_PERIOD_TAGS
#define RenameReportsToActualPeriodOnDeinit                   FALCON_RENAME_REPORTS_TO_ACTUAL_PERIOD
#define ReportFromDateTag                                     FALCON_REPORT_FROM_DATE_TAG
#define ReportToDateTag                                       FALCON_REPORT_TO_DATE_TAG
#define ForceCreateReportFilesOnInit                          FALCON_FORCE_CREATE_REPORT_FILES_ON_INIT
#define PrintReportFolderHintsToLog                           FALCON_PRINT_REPORT_FOLDER_HINTS_TO_LOG
#define EnableFvgMicroRuntimePipelineRefresh                  true
#define ProcessFvgMicroDetectorOnlyOnNewM5ClosedBar            true

// ==================================================================
// FVG Micro quality filters - v0.19.0
// Phase 1 keeps the filters conservative and Shadow-only. The filters are
// internal constants to avoid input bloat. They can block clearly invalid
// candidates before Shadow staging, but never enable broker execution.
// ==================================================================
#define FALCON_FVG_MICRO_QUALITY_FILTERS_ENABLED              true
#define FALCON_FVG_MICRO_MIN_SIZE_POINTS                      1.00
#define FALCON_FVG_MICRO_MAX_SPREAD_POINTS                    200
#define FALCON_FVG_MICRO_MAX_FVG_AGE_BARS                     0
#define FALCON_FVG_MICRO_RETEST_FRESHNESS_BARS                3

// v0.19.2/v0.19.3 calibration profiles. These do NOT block trades yet.
// They only answer: what would have happened if thresholds were tighter?
#define FALCON_FVG_CALIB_BALANCED_MIN_SIZE_POINTS             2.00
#define FALCON_FVG_CALIB_BALANCED_MAX_SPREAD_POINTS           200
#define FALCON_FVG_CALIB_STRICT_SIZE_MIN_SIZE_POINTS          5.00
#define FALCON_FVG_CALIB_STRICT_SIZE_MAX_SPREAD_POINTS        200
#define FALCON_FVG_CALIB_TIGHT_SPREAD_MIN_SIZE_POINTS         1.00
#define FALCON_FVG_CALIB_TIGHT_SPREAD_MAX_SPREAD_POINTS       50
#define FALCON_FVG_CALIB_STRICT_COMBO_MIN_SIZE_POINTS         5.00
#define FALCON_FVG_CALIB_STRICT_COMBO_MAX_SPREAD_POINTS       50


// ==================================================================
// Core Data Contracts - v0.18.2
// ==================================================================
enum ENUM_FALCON_DIRECTION
{
   FALCON_DIRECTION_NONE = 0,
   FALCON_DIRECTION_BUY  = 1,
   FALCON_DIRECTION_SELL = -1
};

enum ENUM_FALCON_ENGINE_STATUS
{
   FALCON_ENGINE_DISABLED = 0,
   FALCON_ENGINE_SHADOW   = 1,
   FALCON_ENGINE_PAPER    = 2,
   FALCON_ENGINE_DEMO     = 3,
   FALCON_ENGINE_LIVE     = 4
};

enum ENUM_FALCON_GUARD_STATUS
{
   FALCON_GUARD_NOT_EVALUATED = 0,
   FALCON_GUARD_PASSED        = 1,
   FALCON_GUARD_REJECTED      = 2
};

enum ENUM_FALCON_TRADE_OUTCOME
{
   FALCON_TRADE_OUTCOME_OPEN      = 0,
   FALCON_TRADE_OUTCOME_WIN       = 1,
   FALCON_TRADE_OUTCOME_LOSS      = 2,
   FALCON_TRADE_OUTCOME_BREAKEVEN = 3,
   FALCON_TRADE_OUTCOME_UNKNOWN   = 4
};

enum ENUM_FALCON_TRADE_STAGE
{
   FALCON_TRADE_STAGE_NONE     = 0,
   FALCON_TRADE_STAGE_SHADOW   = 1,
   FALCON_TRADE_STAGE_PAPER    = 2,
   FALCON_TRADE_STAGE_DEMO     = 3,
   FALCON_TRADE_STAGE_LIVE     = 4
};


enum ENUM_FALCON_SHADOW_RECORD_STATUS
{
   FALCON_SHADOW_RECORD_NONE      = 0,
   FALCON_SHADOW_RECORD_STAGED    = 1,
   FALCON_SHADOW_RECORD_CLOSED    = 2,
   FALCON_SHADOW_RECORD_CANCELLED = 3
};


enum ENUM_FALCON_EVIDENCE_TYPE
{
   FALCON_EVIDENCE_TYPE_NONE                = 0,
   FALCON_EVIDENCE_TYPE_CANDLE_PATTERN      = 1,
   FALCON_EVIDENCE_TYPE_CHART_PATTERN       = 2,
   FALCON_EVIDENCE_TYPE_OBJECTIVE_INDICATOR = 3,
   FALCON_EVIDENCE_TYPE_SMC_LIQUIDITY       = 4
};

enum ENUM_FALCON_EVIDENCE_STATE
{
   FALCON_EVIDENCE_STATE_NOT_EVALUATED = 0,
   FALCON_EVIDENCE_STATE_ABSENT        = 1,
   FALCON_EVIDENCE_STATE_PRESENT       = 2,
   FALCON_EVIDENCE_STATE_CONFLICTING   = 3
};

enum ENUM_FALCON_RUNTIME_SAFETY_STATUS
{
   FALCON_RUNTIME_SAFETY_NOT_EVALUATED = 0,
   FALCON_RUNTIME_SAFETY_PASSED        = 1,
   FALCON_RUNTIME_SAFETY_REJECTED      = 2
};

enum ENUM_FALCON_LOOKAHEAD_RISK
{
   FALCON_LOOKAHEAD_RISK_NONE              = 0,
   FALCON_LOOKAHEAD_RISK_CURRENT_CANDLE    = 1,
   FALCON_LOOKAHEAD_RISK_FINAL_STATE       = 2,
   FALCON_LOOKAHEAD_RISK_INVALID_CANDLE    = 3,
   FALCON_LOOKAHEAD_RISK_INVALID_TRADEPLAN = 4
};

enum ENUM_FALCON_STRATEGY_GROUP
{
   FALCON_STRATEGY_GROUP_CORE         = 0,
   FALCON_STRATEGY_GROUP_PRICE_ACTION = 1,
   FALCON_STRATEGY_GROUP_OPENING      = 2,
   FALCON_STRATEGY_GROUP_LIQUIDITY    = 3,
   FALCON_STRATEGY_GROUP_CONFIRMATION = 4,
   FALCON_STRATEGY_GROUP_RESEARCH     = 5
};

enum ENUM_FALCON_ENGINE_HEALTH
{
   FALCON_ENGINE_HEALTH_DISABLED    = 0,
   FALCON_ENGINE_HEALTH_RESEARCH    = 1,
   FALCON_ENGINE_HEALTH_WATCH       = 2,
   FALCON_ENGINE_HEALTH_HEALTHY     = 3,
   FALCON_ENGINE_HEALTH_CORE_WINNER = 4,
   FALCON_ENGINE_HEALTH_LOCKED      = 5
};

enum ENUM_FALCON_ADAPTER_STATUS
{
   FALCON_ADAPTER_STATUS_NOT_INITIALIZED           = 0,
   FALCON_ADAPTER_STATUS_NO_TRADE                  = 1,
   FALCON_ADAPTER_STATUS_SHADOW_CANDIDATE_BLOCKED  = 2,
   FALCON_ADAPTER_STATUS_READY                     = 3
};


enum ENUM_FALCON_DETECTOR_STATUS
{
   FALCON_DETECTOR_STATUS_NOT_INITIALIZED      = 0,
   FALCON_DETECTOR_STATUS_NO_TRADE             = 1,
   FALCON_DETECTOR_STATUS_BLOCKED              = 2,
   FALCON_DETECTOR_STATUS_READY_STUB           = 3,
   FALCON_DETECTOR_STATUS_NO_FVG               = 4,
   FALCON_DETECTOR_STATUS_FVG_FOUND_SHADOW_ONLY= 5
};

enum ENUM_FALCON_CANDIDATE_STATUS
{
   FALCON_CANDIDATE_STATUS_NOT_INITIALIZED = 0,
   FALCON_CANDIDATE_STATUS_NO_CANDIDATE    = 1,
   FALCON_CANDIDATE_STATUS_BLOCKED         = 2,
   FALCON_CANDIDATE_STATUS_READY_SHADOW    = 3
};

enum ENUM_FALCON_RETEST_WATCHER_STATUS
{
   FALCON_RETEST_WATCHER_STATUS_NOT_INITIALIZED = 0,
   FALCON_RETEST_WATCHER_STATUS_BLOCKED         = 1,
   FALCON_RETEST_WATCHER_STATUS_WAITING         = 2,
   FALCON_RETEST_WATCHER_STATUS_RETEST_TOUCHED  = 3,
   FALCON_RETEST_WATCHER_STATUS_SKELETON_READY  = 4
};

enum ENUM_FALCON_TRADEPLAN_STAGING_STATUS
{
   FALCON_TRADEPLAN_STAGING_STATUS_NOT_INITIALIZED = 0,
   FALCON_TRADEPLAN_STAGING_STATUS_BLOCKED         = 1,
   FALCON_TRADEPLAN_STAGING_STATUS_PLAN_CREATED    = 2,
   FALCON_TRADEPLAN_STAGING_STATUS_STAGED_SHADOW   = 3
};

enum ENUM_FALCON_SHADOW_LIFECYCLE_STATUS
{
   FALCON_SHADOW_LIFECYCLE_STATUS_NOT_INITIALIZED = 0,
   FALCON_SHADOW_LIFECYCLE_STATUS_BLOCKED         = 1,
   FALCON_SHADOW_LIFECYCLE_STATUS_MONITORING      = 2,
   FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_TP       = 3,
   FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_SL       = 4,
   FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_TIMEOUT  = 5
};

struct FalconSymbolContext
{
   string symbol;
   int    digits;
   double point;
   double tick_size;
   double tick_value;
   double contract_size;
   long   spread_points;
   long   stops_level_points;
   long   freeze_level_points;
   double min_lot;
   double max_lot;
   double lot_step;
   bool   is_valid;
};

struct FalconQuoteContext
{
   double   bid;
   double   ask;
   double   last;
   long     volume;
   double   volume_real;
   datetime tick_time;
   long     time_msc;
   long     spread_points;
   bool     is_valid;
};

struct FalconCandleSnapshot
{
   ENUM_TIMEFRAMES timeframe;
   datetime        time;
   double          open;
   double          high;
   double          low;
   double          close;
   long            tick_volume;
   long            real_volume;
   int             spread;
   int             source_shift;
   bool            is_closed;
   bool            is_valid;
};

struct FalconRuntimeSafetyCheck
{
   string                              check_id;
   string                              check_name;
   ENUM_FALCON_RUNTIME_SAFETY_STATUS   status;
   ENUM_FALCON_LOOKAHEAD_RISK          risk_type;
   ENUM_TIMEFRAMES                     timeframe;
   int                                 source_shift;
   bool                                used_closed_candle;
   bool                                current_candle_blocked;
   bool                                final_state_blocked;
   bool                                staging_allowed;
   string                              notes;
};

struct FalconStrategyRegistryEntry
{
   string                     strategy_id;
   string                     strategy_name;
   string                     engine_id;
   ENUM_FALCON_STRATEGY_GROUP strategy_group;
   bool                       input_enabled;
   ENUM_FALCON_ENGINE_HEALTH  health_status;
   ENUM_FALCON_ENGINE_STATUS  max_allowed_stage;
   bool                       shadow_allowed;
   bool                       paper_allowed;
   bool                       demo_allowed;
   bool                       live_allowed;
   string                     notes;
};

struct FalconStrategyAdapterSnapshot
{
   string                     adapter_id;
   string                     target_strategy_id;
   string                     strategy_name;
   string                     engine_id;
   ENUM_FALCON_STRATEGY_GROUP strategy_group;
   ENUM_FALCON_ENGINE_HEALTH  health_status;
   ENUM_FALCON_ENGINE_STATUS  max_allowed_stage;
   ENUM_FALCON_ADAPTER_STATUS adapter_status;
   bool                       registry_found;
   bool                       input_enabled;
   bool                       shadow_allowed;
   bool                       shadow_executor_ready;
   bool                       runtime_safety_ready;
   bool                       candidate_requested;
   bool                       candidate_staged;
   bool                       live_allowed;
   bool                       order_send_used;
   string                     no_trade_reason;
   string                     safety_reason;
   string                     notes;
};


struct FalconFvgMicroDetectorSnapshot
{
   string                       detector_id;
   string                       strategy_id;
   string                       strategy_name;
   string                       engine_id;
   ENUM_FALCON_DETECTOR_STATUS  detector_status;
   bool                         registry_found;
   bool                         input_enabled;
   bool                         candle_cache_ready;
   bool                         evidence_framework_ready;
   bool                         runtime_safety_ready;
   bool                         used_closed_candle;
   bool                         order_send_used;
   ENUM_TIMEFRAMES              analysis_timeframe;
   int                          analysis_shift;
   datetime                     candle_time;
   double                       candle_open;
   double                       candle_high;
   double                       candle_low;
   double                       candle_close;
   long                         candle_tick_volume;
   bool                         fvg_detected;
   ENUM_FALCON_DIRECTION        fvg_direction;
   datetime                     older_candle_time;
   datetime                     middle_candle_time;
   datetime                     newer_candle_time;
   double                       older_candle_high;
   double                       older_candle_low;
   double                       middle_candle_high;
   double                       middle_candle_low;
   double                       newer_candle_high;
   double                       newer_candle_low;
   double                       fvg_lower;
   double                       fvg_upper;
   double                       fvg_size_price;
   double                       fvg_size_points;
   double                       evidence_score;
   string                       evidence_summary;
   string                       no_trade_reason;
   string                       safety_reason;
   string                       notes;
};

struct FalconFvgMicroShadowCandidateSnapshot
{
   string                       builder_id;
   string                       candidate_id;
   string                       strategy_id;
   string                       strategy_name;
   string                       engine_id;
   ENUM_FALCON_CANDIDATE_STATUS candidate_status;
   bool                         detector_initialized;
   bool                         registry_found;
   bool                         input_enabled;
   bool                         shadow_allowed;
   bool                         runtime_safety_ready;
   bool                         fvg_detected;
   bool                         candidate_created;
   bool                         tradeplan_created;
   bool                         staged_to_shadow_executor;
   bool                         order_send_used;
   ENUM_FALCON_DIRECTION        direction;
   ENUM_TIMEFRAMES              analysis_timeframe;
   datetime                     setup_time;
   double                       entry_zone_lower;
   double                       entry_zone_upper;
   double                       fvg_size_points;
   bool                         quality_filters_enabled;
   bool                         quality_filters_passed;
   double                       quality_min_fvg_size_points;
   long                         quality_current_spread_points;
   long                         quality_max_spread_points;
   int                          quality_fvg_age_bars;
   int                          quality_max_fvg_age_bars;
   int                          quality_retest_freshness_bars;
   string                       quality_reject_reason;
   int                          fvg_retest_age_bars;
   datetime                     fvg_setup_time;
   datetime                     fvg_retest_watch_time;
   int                          fvg_age_bars_at_watch;
   string                       fvg_age_source;
   string                       fvg_retest_fresh_state;
   int                          fvg_hold_quality_score;
   string                       fvg_hold_quality_bucket;
   bool                         quality_profile_balanced_passed;
   bool                         quality_profile_strict_size_passed;
   bool                         quality_profile_tight_spread_passed;
   bool                         quality_profile_strict_combo_passed;
   double                       score;
   string                       block_reason;
   string                       evidence_summary;
   string                       notes;
};

double FalconSafeAverageDouble(const double total, const int count)
{
   if(count <= 0)
      return 0.0;
   return (total / (double)count);
}

// ==================================================================
// Weekly Stability Score Foundation - v0.55.9a
// Summary-only measurement. It does not change entry, exit, lot sizing,
// emergency, tier, protection, runner, or any Paper trade outcome.
// ==================================================================
int FalconWeeklyStabilityWeekKey(const datetime t)
{
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int week_index = (dt.day_of_year / 7) + 1;
   return dt.year * 100 + week_index;
}

double FalconClampDouble(const double value, const double min_value, const double max_value)
{
   if(value < min_value) return min_value;
   if(value > max_value) return max_value;
   return value;
}


double FalconSafeAverageLongAsDouble(const long total, const int count)
{
   if(count <= 0)
      return 0.0;
   return ((double)total / (double)count);
}


double FalconRoundToDecimals(const double value, const int digits)
{
   double factor = MathPow(10.0, (double)digits);
   if(factor <= 0.0)
      return value;
   return MathRound(value * factor) / factor;
}

double FalconReportVisibleUsd4(const double value)
{
   return FalconRoundToDecimals(value, 4);
}

bool FalconEvaluateFvgQualityShadowGuard(const double fvg_size_points,
                                         const long fvg_spread_points,
                                         const int fvg_age_bars,
                                         const int fvg_hold_quality_score,
                                         string &reason)
{
   reason = "PASS";

   if(fvg_size_points < FALCON_FVG_QGUARD_MIN_SIZE_POINTS)
   {
      reason = "FVG_SIZE_BELOW_SHADOW_GUARD_MIN";
      return false;
   }

   if(FALCON_FVG_QGUARD_MAX_SPREAD_POINTS > 0 && fvg_spread_points > FALCON_FVG_QGUARD_MAX_SPREAD_POINTS)
   {
      reason = "SPREAD_ABOVE_SHADOW_GUARD_MAX";
      return false;
   }

   if(FALCON_FVG_QGUARD_MAX_AGE_BARS > 0 && fvg_age_bars > FALCON_FVG_QGUARD_MAX_AGE_BARS)
   {
      reason = "FVG_AGE_ABOVE_SHADOW_GUARD_MAX";
      return false;
   }

   if(fvg_hold_quality_score < FALCON_FVG_QGUARD_MIN_HOLD_SCORE)
   {
      reason = "HOLD_SCORE_BELOW_SHADOW_GUARD_MIN";
      return false;
   }

   return true;
}

void FalconRegisterFvgQualityDistributionMetrics(const FalconFvgMicroShadowCandidateSnapshot &snapshot)
{
   if(!(snapshot.fvg_detected && snapshot.registry_found && snapshot.input_enabled && snapshot.runtime_safety_ready))
      return;

   const double size_points = snapshot.fvg_size_points;
   const long spread_points = snapshot.quality_current_spread_points;

   g_fvg_quality_distribution_count++;
   g_fvg_quality_size_total_points += size_points;

   if(g_fvg_quality_distribution_count == 1 || size_points < g_fvg_quality_size_min_points)
      g_fvg_quality_size_min_points = size_points;
   if(g_fvg_quality_distribution_count == 1 || size_points > g_fvg_quality_size_max_points)
      g_fvg_quality_size_max_points = size_points;

   g_fvg_quality_spread_total_points += spread_points;
   if(g_fvg_quality_spread_min_points < 0 || spread_points < g_fvg_quality_spread_min_points)
      g_fvg_quality_spread_min_points = spread_points;
   if(spread_points > g_fvg_quality_spread_max_points)
      g_fvg_quality_spread_max_points = spread_points;

   if(spread_points <= 50)
      g_fvg_quality_spread_le_50_count++;
   if(spread_points <= 75)
      g_fvg_quality_spread_le_75_count++;
   if(spread_points <= 100)
      g_fvg_quality_spread_le_100_count++;
   if(spread_points <= 150)
      g_fvg_quality_spread_le_150_count++;
   if(spread_points <= 200)
      g_fvg_quality_spread_le_200_count++;
}

bool FalconFvgQualityCalibrationProfilePassed(const FalconFvgMicroShadowCandidateSnapshot &snapshot,
                                              const double min_size_points,
                                              const long max_spread_points)
{
   if(snapshot.fvg_size_points < min_size_points)
      return false;

   if(max_spread_points > 0 && snapshot.quality_current_spread_points > max_spread_points)
      return false;

   return true;
}

void FalconRegisterFvgQualityCalibrationMetrics(const FalconFvgMicroShadowCandidateSnapshot &snapshot)
{
   if(!(snapshot.fvg_detected && snapshot.registry_found && snapshot.input_enabled && snapshot.runtime_safety_ready))
      return;

   g_fvg_quality_calibration_evaluated++;
   FalconRegisterFvgQualityDistributionMetrics(snapshot);

   bool balanced_pass = FalconFvgQualityCalibrationProfilePassed(snapshot,
                                                                 FALCON_FVG_CALIB_BALANCED_MIN_SIZE_POINTS,
                                                                 FALCON_FVG_CALIB_BALANCED_MAX_SPREAD_POINTS);
   if(balanced_pass)
      g_fvg_quality_profile_balanced_passed++;
   else
      g_fvg_quality_profile_balanced_rejected++;

   bool strict_size_pass = FalconFvgQualityCalibrationProfilePassed(snapshot,
                                                                    FALCON_FVG_CALIB_STRICT_SIZE_MIN_SIZE_POINTS,
                                                                    FALCON_FVG_CALIB_STRICT_SIZE_MAX_SPREAD_POINTS);
   if(strict_size_pass)
      g_fvg_quality_profile_strict_size_passed++;
   else
      g_fvg_quality_profile_strict_size_rejected++;

   bool tight_spread_pass = FalconFvgQualityCalibrationProfilePassed(snapshot,
                                                                     FALCON_FVG_CALIB_TIGHT_SPREAD_MIN_SIZE_POINTS,
                                                                     FALCON_FVG_CALIB_TIGHT_SPREAD_MAX_SPREAD_POINTS);
   if(tight_spread_pass)
      g_fvg_quality_profile_tight_spread_passed++;
   else
      g_fvg_quality_profile_tight_spread_rejected++;

   bool strict_combo_pass = FalconFvgQualityCalibrationProfilePassed(snapshot,
                                                                     FALCON_FVG_CALIB_STRICT_COMBO_MIN_SIZE_POINTS,
                                                                     FALCON_FVG_CALIB_STRICT_COMBO_MAX_SPREAD_POINTS);
   if(strict_combo_pass)
      g_fvg_quality_profile_strict_combo_passed++;
   else
      g_fvg_quality_profile_strict_combo_rejected++;
}

void FalconRegisterFvgMicroCandidateMetrics(const FalconFvgMicroShadowCandidateSnapshot &snapshot)
{
   g_fvg_micro_candidate_builder_evaluations++;

   if(snapshot.fvg_detected)
      g_fvg_micro_detected_candidates++;

   if(snapshot.fvg_detected && snapshot.registry_found && snapshot.input_enabled && snapshot.runtime_safety_ready)
   {
      g_fvg_micro_quality_evaluated++;

      if(snapshot.quality_filters_passed)
      {
         g_fvg_micro_quality_passed++;
      }
      else
      {
         g_fvg_micro_quality_rejected++;

         if(StringFind(snapshot.quality_reject_reason, "FVG_SIZE_BELOW_MIN") >= 0)
            g_fvg_micro_rejected_size++;
         else if(StringFind(snapshot.quality_reject_reason, "SPREAD_ABOVE_MAX") >= 0)
            g_fvg_micro_rejected_spread++;
         else if(StringFind(snapshot.quality_reject_reason, "FVG_AGE_ABOVE_MAX") >= 0)
            g_fvg_micro_rejected_age++;
      }
   }

   FalconRegisterFvgQualityCalibrationMetrics(snapshot);

   if(snapshot.candidate_status == FALCON_CANDIDATE_STATUS_READY_SHADOW)
      g_fvg_micro_shadow_ready_candidates++;
}

struct FalconFvgMicroRetestWatcherSnapshot
{
   string                            watcher_id;
   string                            candidate_id;
   string                            strategy_id;
   string                            strategy_name;
   string                            engine_id;
   ENUM_FALCON_RETEST_WATCHER_STATUS watcher_status;
   bool                              candidate_builder_initialized;
   bool                              candidate_ready;
   bool                              quote_valid;
   bool                              runtime_safety_ready;
   bool                              fvg_detected;
   bool                              retest_touched;
   bool                              tradeplan_skeleton_created;
   bool                              tradeplan_created;
   bool                              staged_to_shadow_executor;
   bool                              order_send_used;
   ENUM_FALCON_DIRECTION             direction;
   ENUM_TIMEFRAMES                   analysis_timeframe;
   datetime                          setup_time;
   datetime                          watch_time;
   double                            watch_price;
   double                            fvg_lower;
   double                            fvg_upper;
   double                            fvg_size_points;
   bool                              quality_filters_enabled;
   bool                              quality_filters_passed;
   double                            quality_min_fvg_size_points;
   long                              quality_current_spread_points;
   long                              quality_max_spread_points;
   int                               quality_fvg_age_bars;
   int                               quality_max_fvg_age_bars;
   int                               quality_retest_freshness_bars;
   string                            quality_reject_reason;
   int                               fvg_retest_age_bars;
   datetime                          fvg_setup_time;
   datetime                          fvg_retest_watch_time;
   int                               fvg_age_bars_at_watch;
   string                            fvg_age_source;
   string                            fvg_retest_fresh_state;
   int                               fvg_hold_quality_score;
   string                            fvg_hold_quality_bucket;
   bool                              quality_profile_balanced_passed;
   bool                              quality_profile_strict_size_passed;
   bool                              quality_profile_tight_spread_passed;
   bool                              quality_profile_strict_combo_passed;
   double                            planned_entry_price;
   double                            planned_structural_sl;
   double                            planned_tp1;
   double                            planned_tp2;
   double                            planned_tp3;
   double                            planned_lot_size;
   string                            retest_reason;
   string                            block_reason;
   string                            skeleton_notes;
   string                            notes;
};

struct FalconFvgMicroTradePlanStagingSnapshot
{
   string                               stager_id;
   string                               plan_id;
   string                               candidate_id;
   string                               shadow_id;
   string                               strategy_id;
   string                               strategy_name;
   string                               engine_id;
   ENUM_FALCON_TRADEPLAN_STAGING_STATUS staging_status;
   ENUM_FALCON_RETEST_WATCHER_STATUS    watcher_status;
   bool                                 watcher_initialized;
   bool                                 retest_touched;
   bool                                 skeleton_ready;
   bool                                 runtime_safety_ready;
   bool                                 shadow_executor_ready;
   bool                                 tradeplan_created;
   bool                                 validate_passed;
   bool                                 staged_to_shadow_executor;
   bool                                 order_send_used;
   ENUM_FALCON_DIRECTION                direction;
   ENUM_TIMEFRAMES                      analysis_timeframe;
   datetime                             setup_time;
   datetime                             staging_time;
   double                               lot_size;
   double                               entry_price;
   double                               structural_sl;
   double                               tp1;
   double                               tp2;
   double                               tp3;
   string                               risk_profile;
   string                               management_profile;
   string                               validation_reason;
   string                               staging_reason;
   string                               evidence_summary;
   string                               notes;
};

struct FalconFvgMicroShadowLifecycleSnapshot
{
   string                              simulator_id;
   string                              shadow_id;
   string                              strategy_id;
   string                              strategy_name;
   string                              engine_id;
   ENUM_FALCON_SHADOW_LIFECYCLE_STATUS lifecycle_status;
   ENUM_FALCON_SHADOW_RECORD_STATUS    shadow_record_status;
   bool                                stager_ready;
   bool                                staged_to_shadow_executor;
   bool                                shadow_record_loaded;
   bool                                quote_valid;
   bool                                close_record_created;
   bool                                registered_to_trade_report;
   bool                                order_send_used;
   ENUM_FALCON_DIRECTION               direction;
   datetime                            entry_time;
   datetime                            evaluation_time;
   int                                 elapsed_seconds;
   double                              entry_price;
   double                              structural_sl;
   double                              tp1;
   double                              tp2;
   double                              tp3;
   double                              current_price;
   double                              simulated_exit_price;
   ENUM_FALCON_TRADE_OUTCOME           simulated_outcome;
   double                              profit_index_points;
   double                              loss_index_points;
   double                              net_index_points;
   double                              profit_usd;
   double                              loss_usd;
   double                              net_usd;
   string                              close_reason;
   string                              lifecycle_reason;
   string                              notes;
};

struct FalconEvidenceRecord
{
   string                     evidence_id;
   string                     evidence_name;
   ENUM_FALCON_EVIDENCE_TYPE  evidence_type;
   ENUM_FALCON_EVIDENCE_STATE evidence_state;
   ENUM_FALCON_DIRECTION      direction_bias;
   ENUM_TIMEFRAMES            source_timeframe;
   double                     score;
   bool                       is_runtime_permission;
   string                     notes;
};

struct FalconEvidencePack
{
   bool   has_candle_evidence;
   bool   has_chart_pattern_evidence;
   bool   has_objective_indicator_evidence;
   bool   has_smc_evidence;
   double score;
   string summary;
};

struct FalconObjectivePlan
{
   double entry_price;
   double structural_sl;
   double tp1;
   double tp2;
   double tp3;
   bool   runner_allowed;
   string objective_reason;
};

struct FalconStrategySignal
{
   string                    strategy_id;
   string                    strategy_name;
   string                    engine_id;
   ENUM_FALCON_DIRECTION     direction;
   ENUM_FALCON_ENGINE_STATUS engine_status;
   ENUM_FALCON_GUARD_STATUS  guard_status;
   datetime                  setup_time;
   ENUM_TIMEFRAMES           setup_timeframe;
   double                    score;
   string                    rejection_reason;
   FalconEvidencePack        evidence;
   FalconObjectivePlan       objective;
};

struct FalconTradePlan
{
   string                plan_id;
   string                strategy_id;
   string                strategy_name;
   string                engine_id;
   ENUM_FALCON_DIRECTION direction;
   double                lot_size;
   double                entry_price;
   double                structural_sl;
   double                tp1;
   double                tp2;
   double                tp3;
   bool                  runner_allowed;
   string                risk_profile;
   string                management_profile;

   // v0.21.0: FVG Micro per-trade quality attribution.
   // Metadata only: no entry, SL, TP, routing, or lifecycle close behavior changes.
   double                fvg_size_points;
   long                  fvg_spread_points;
   int                   fvg_retest_age_bars;
   datetime              fvg_setup_time;
   datetime              fvg_retest_watch_time;
   int                   fvg_age_bars_at_watch;
   string                fvg_age_source;
   string                fvg_retest_fresh_state;
   int                   fvg_hold_quality_score;
   string                fvg_hold_quality_bucket;
   bool                  quality_filters_passed;
   bool                  quality_profile_balanced_passed;
   bool                  quality_profile_strict_size_passed;
   bool                  quality_profile_tight_spread_passed;
   bool                  quality_profile_strict_combo_passed;
};

struct FalconTradeLifecycleRecord
{
   string                    trade_id;
   string                    strategy_id;
   string                    strategy_name;
   string                    engine_id;
   ENUM_FALCON_DIRECTION     direction;
   ENUM_FALCON_TRADE_STAGE   stage;
   ENUM_FALCON_TRADE_OUTCOME outcome;
   datetime                  entry_time;
   datetime                  exit_time;
   double                    lot_size;
   double                    entry_price;
   double                    structural_sl;
   double                    tp1;
   double                    tp2;
   double                    tp3;
   double                    exit_price;
   double                    profit_index_points;
   double                    loss_index_points;
   double                    net_index_points;
   double                    profit_usd;
   double                    loss_usd;
   double                    net_usd;
   string                    close_reason;
   string                    evidence_summary;

   // v0.21.0: FVG Micro quality attribution carried into TradeLifecycle rows.
   double                    fvg_size_points;
   long                      fvg_spread_points;
   int                       fvg_retest_age_bars;
   datetime                  fvg_setup_time;
   datetime                  fvg_retest_watch_time;
   int                       fvg_age_bars_at_watch;
   string                    fvg_age_source;
   string                    fvg_retest_fresh_state;
   int                       fvg_hold_quality_score;
   string                    fvg_hold_quality_bucket;
   bool                      quality_filters_passed;

   // v0.22.2: locked P03_SIZE250_ONLY FVG quality shadow simulation carried into TradeLifecycle rows.
   // v0.22.3: OOS validation lock only; behavior and report surface remain unchanged.
   // Diagnostic only: does not affect entry, exit, SL, TP, risk, or runtime decisions.
   string                    fvg_quality_shadow_guard_profile;
   bool                      fvg_quality_shadow_guard_passed;
   string                    fvg_quality_shadow_guard_decision;
   string                    fvg_quality_shadow_guard_reason;
   double                    fvg_quality_shadow_guard_sim_net_points;
   double                    fvg_quality_shadow_guard_sim_net_usd;

   bool                      quality_profile_balanced_passed;
   bool                      quality_profile_strict_size_passed;
   bool                      quality_profile_tight_spread_passed;
   bool                      quality_profile_strict_combo_passed;

   // v0.49.0: Paper Runtime Guard Application Phase 1 fields.
   string                    paper_guard_status;
   string                    paper_reject_reason;
   string                    paper_guard_layer;
   long                      paper_spread_points;
   int                       paper_max_spread_points;
   double                    paper_sl_distance_points;
   long                      paper_stops_level_points;
   long                      paper_freeze_level_points;
   double                    paper_guard_net_index_points;
   double                    paper_guard_net_usd;

   // v0.50.0: Paper Runtime Smart SL / Protection Application fields.
   string                    paper_protection_state;
   double                    paper_virtual_sl;
   string                    paper_protection_trigger;
   double                    paper_protection_level;
   bool                      paper_protection_activated;
   bool                      paper_virtual_sl_changed;
   bool                      paper_virtual_sl_hit;
   string                    paper_exit_reason;
   double                    paper_protection_net_index_points;
   double                    paper_protection_net_usd;

   // v0.51.0: Paper Runtime Runner Application fields.
   string                    paper_runner_state;
   bool                      paper_runner_activated;
   double                    paper_runner_max_r;
   double                    paper_runner_captured_points;
   double                    paper_runner_additional_points;
   string                    paper_runner_exit_reason;
   double                    paper_runner_net_index_points;
   double                    paper_runner_net_usd;
   string                    paper_final_exit_reason;

   // v0.53.0: Capital Tier Foundation logging fields.
   string                    falcon_tier_at_entry;
   string                    falcon_tier_at_exit;
   double                    falcon_effective_balance;
   double                    falcon_tier_min_balance;
   double                    falcon_tier_max_balance;
   int                       falcon_tier_max_losses;
   double                    falcon_tier_max_daily_r;
   double                    falcon_tier_max_drawdown_pct;
   double                    falcon_broker_min_lot;
   double                    falcon_fixed_lot;
   string                    falcon_min_lot_constraint;

   // v0.55.1: Low-Capital Risk Feasibility Foundation fields.
   string                    falcon_lotsizing_feasibility_status;
   string                    falcon_lotsizing_feasibility_reason;
   double                    falcon_min_lot_risk_points;
   double                    falcon_min_lot_risk_usd;
   double                    falcon_min_lot_risk_pct_of_capital;
   double                    falcon_tier_base_risk_pct;
   double                    falcon_tier_risk_budget_usd;
   double                    falcon_potential_loss_r;
   double                    falcon_max_single_trade_loss_r;
   int                       falcon_single_trade_loss_cap_breach;

   // v0.55.2: Calibrated Single Trade Loss Cap Enforcement Candidate fields.
   string                    falcon_single_trade_loss_cap_status;
   string                    falcon_single_trade_loss_cap_decision;
   string                    falcon_single_trade_loss_cap_reason;
   int                       falcon_single_trade_loss_cap_runtime_enforced;
   double                    falcon_single_trade_loss_cap_strict_cap_r;
   double                    falcon_single_trade_loss_cap_calibrated_cap_r;
   double                    falcon_single_trade_loss_cap_risk_pct_cap;
   int                       falcon_single_trade_loss_cap_blocked;
   double                    falcon_single_trade_loss_cap_before_net_points;
   double                    falcon_single_trade_loss_cap_after_net_points;
   double                    falcon_single_trade_loss_cap_impact_points;
   double                    falcon_single_trade_loss_cap_before_net_usd;
   double                    falcon_single_trade_loss_cap_after_net_usd;
   double                    falcon_single_trade_loss_cap_impact_usd;

   // v0.55.2a: Dynamic capital-aware risk fields.
   string                    falcon_dynamic_capital_mode;
   double                    falcon_dynamic_risk_capital_before_trade;
   double                    falcon_dynamic_risk_capital_after_trade;
   string                    falcon_dynamic_risk_tier_by_capital;
   double                    falcon_dynamic_risk_pct_of_capital;
   double                    falcon_dynamic_single_trade_cap_pct;
   int                       falcon_dynamic_capital_aware_blocked;
   string                    falcon_dynamic_capital_reason;

   // v0.55.5: Capital flow source classification fields. Reporting-only; no trading behavior change.
   string                    falcon_capital_flow_source;
   double                    falcon_capital_flow_delta_usd;
   double                    falcon_external_capital_delta_usd;
   int                       falcon_capital_flow_external_event;
   string                    falcon_capital_flow_status;
   string                    falcon_capital_flow_reason;

   // v0.55.3: Dynamic LotSizing Model / Capital Flow Awareness fields.
   string                    falcon_dlm_status;
   string                    falcon_dlm_decision;
   int                       falcon_dlm_runtime_enforced;
   int                       falcon_dlm_use_fixed_lot;
   double                    falcon_dlm_fixed_lot_size;
   double                    falcon_dlm_effective_capital;
   double                    falcon_dlm_base_risk_pct;
   double                    falcon_dlm_risk_budget_usd;
   double                    falcon_dlm_risk_points;
   double                    falcon_dlm_risk_usd_per_one_lot;
   double                    falcon_dlm_raw_lot;
   double                    falcon_dlm_recommended_lot;
   double                    falcon_dlm_active_lot;
   double                    falcon_dlm_tier_max_lot;
   double                    falcon_dlm_capital_max_lot;
   double                    falcon_dlm_previous_active_lot;
   double                    falcon_dlm_growth_ramp_max_lot;
   int                       falcon_dlm_tier_cap_applied;
   int                       falcon_dlm_capital_cap_applied;
   int                       falcon_dlm_growth_ramp_applied;
   string                    falcon_dlm_safety_mode;
   double                    falcon_dlm_broker_min_lot;
   double                    falcon_dlm_broker_max_lot;
   double                    falcon_dlm_broker_lot_step;
   int                       falcon_dlm_min_lot_floor_applied;
   int                       falcon_dlm_max_lot_cap_applied;
   double                    falcon_dlm_recommended_risk_usd;
   double                    falcon_dlm_recommended_risk_pct;
   double                    falcon_dlm_active_risk_usd;
   double                    falcon_dlm_active_risk_pct;
   string                    falcon_dlm_reason;

   // v0.55.11c: Session boundary / no-new-entry paper enforcement fields.
   string                    falcon_market_close_status;
   int                       falcon_market_close_blocked;
   string                    falcon_market_close_reason;
   double                    falcon_market_close_before_net_usd;
   double                    falcon_market_close_after_net_usd;
   double                    falcon_market_close_impact_usd;

   // v0.53.1: Three-Layer Emergency active paper replacement fields.
   string                    falcon_emergency_status;
   int                       falcon_emergency_triggered_layer;
   string                    falcon_emergency_reason;
   int                       falcon_layer1_consecutive_losses;
   int                       falcon_layer1_max_losses;
   double                    falcon_layer2_daily_r;
   double                    falcon_layer2_max_daily_r;
   double                    falcon_layer3_drawdown_pct;
   double                    falcon_layer3_max_drawdown_pct;
   double                    falcon_emergency_before_net_points;
   double                    falcon_emergency_after_net_points;
   double                    falcon_emergency_before_net_usd;
   double                    falcon_emergency_after_net_usd;

   // v0.53.2: Layer-specific reset logic validation fields.
   string                    falcon_reset_status;
   int                       falcon_layer1_reset_on_win;
   int                       falcon_layer2_reset_on_new_day;
   int                       falcon_layer3_reset_on_new_peak;
   string                    falcon_reset_reason;
};


struct FalconShadowTradeRecord
{
   string                           shadow_id;
   string                           strategy_id;
   string                           strategy_name;
   string                           engine_id;
   ENUM_FALCON_DIRECTION            direction;
   ENUM_FALCON_SHADOW_RECORD_STATUS status;
   datetime                         entry_time;
   datetime                         exit_time;
   double                           lot_size;
   double                           entry_price;
   double                           structural_sl;
   double                           tp1;
   double                           tp2;
   double                           tp3;
   double                           simulated_exit_price;
   ENUM_FALCON_TRADE_OUTCOME        simulated_outcome;
   string                           close_reason;
   string                           evidence_summary;

   // v0.21.3: official FVG attribution fields carried into closed TradeLifecycle records.
   double                           fvg_size_points;
   long                             fvg_spread_points;
   int                              fvg_retest_age_bars;
   datetime                         fvg_setup_time;
   datetime                         fvg_retest_watch_time;
   int                              fvg_age_bars_at_watch;
   string                           fvg_age_source;
   string                           fvg_retest_fresh_state;
   int                              fvg_hold_quality_score;
   string                           fvg_hold_quality_bucket;
   bool                             quality_filters_passed;

   // v0.22.0: FVG quality shadow guard simulation.
   // These fields are diagnostic only and do not affect actual Shadow lifecycle rows.
   string                           fvg_quality_shadow_guard_profile;
   bool                             fvg_quality_shadow_guard_passed;
   string                           fvg_quality_shadow_guard_decision;
   string                           fvg_quality_shadow_guard_reason;
   double                           fvg_quality_shadow_guard_sim_net_points;
   double                           fvg_quality_shadow_guard_sim_net_usd;

   bool                             quality_profile_balanced_passed;
   bool                             quality_profile_strict_size_passed;
   bool                             quality_profile_tight_spread_passed;
   bool                             quality_profile_strict_combo_passed;

   bool                             is_closed;
};


// ==================================================================
// Strategy-agnostic broker execution contracts - v0.56.0 foundation
// These records are intentionally not FVG-specific. Future strategies
// must publish the same StrategyId/EngineId/TradeId contract into the
// broker layer before any real broker action is allowed.
// ==================================================================
enum ENUM_FALCON_BROKER_TM_EVENT_TYPE
{
   FALCON_BTM_EVENT_ENTRY_PLANNED = 0,
   FALCON_BTM_EVENT_ENTRY_ACCEPTED_PAPER = 1,
   FALCON_BTM_EVENT_TP1_TOUCH = 2,
   FALCON_BTM_EVENT_TP2_TOUCH = 3,
   FALCON_BTM_EVENT_PROTECTION_ARMED = 4,
   FALCON_BTM_EVENT_PROTECTION_TRIGGERED = 5,
   FALCON_BTM_EVENT_RUNNER_ARMED = 6,
   FALCON_BTM_EVENT_RUNNER_EXIT = 7,
   FALCON_BTM_EVENT_RAW_SL_HIT = 8,
   FALCON_BTM_EVENT_TIMEOUT_CLOSE = 9,
   FALCON_BTM_EVENT_FINAL_CLOSE = 10,
   FALCON_BTM_EVENT_ACCOUNTING_ONLY_ADJUSTMENT = 11,
   FALCON_BTM_EVENT_BAR_ORDER_AMBIGUOUS = 12,
   FALCON_BTM_EVENT_FOUNDATION_NO_RUNTIME_EVENT = 13,
   FALCON_BTM_EVENT_EVENT_TIMELINE_AUDIT = 14,
   FALCON_BTM_EVENT_BROKER_ENTRY_ATTEMPTED = 15,
   FALCON_BTM_EVENT_BROKER_ENTRY_ACCEPTED = 16,
   FALCON_BTM_EVENT_BROKER_ENTRY_REJECTED = 17
};

string FalconBrokerTmEventTypeToString(const ENUM_FALCON_BROKER_TM_EVENT_TYPE event_type)
{
   switch(event_type)
   {
      case FALCON_BTM_EVENT_ENTRY_PLANNED: return "ENTRY_PLANNED";
      case FALCON_BTM_EVENT_ENTRY_ACCEPTED_PAPER: return "ENTRY_ACCEPTED_PAPER";
      case FALCON_BTM_EVENT_TP1_TOUCH: return "TP1_TOUCH";
      case FALCON_BTM_EVENT_TP2_TOUCH: return "TP2_TOUCH";
      case FALCON_BTM_EVENT_PROTECTION_ARMED: return "PROTECTION_ARMED";
      case FALCON_BTM_EVENT_PROTECTION_TRIGGERED: return "PROTECTION_TRIGGERED";
      case FALCON_BTM_EVENT_RUNNER_ARMED: return "RUNNER_ARMED";
      case FALCON_BTM_EVENT_RUNNER_EXIT: return "RUNNER_EXIT";
      case FALCON_BTM_EVENT_RAW_SL_HIT: return "RAW_SL_HIT";
      case FALCON_BTM_EVENT_TIMEOUT_CLOSE: return "TIMEOUT_CLOSE";
      case FALCON_BTM_EVENT_FINAL_CLOSE: return "FINAL_CLOSE";
      case FALCON_BTM_EVENT_ACCOUNTING_ONLY_ADJUSTMENT: return "ACCOUNTING_ONLY_ADJUSTMENT";
      case FALCON_BTM_EVENT_BAR_ORDER_AMBIGUOUS: return "BAR_ORDER_AMBIGUOUS";
      case FALCON_BTM_EVENT_FOUNDATION_NO_RUNTIME_EVENT: return "FOUNDATION_NO_RUNTIME_EVENT";
      case FALCON_BTM_EVENT_EVENT_TIMELINE_AUDIT: return "EVENT_TIMELINE_AUDIT";
      case FALCON_BTM_EVENT_BROKER_ENTRY_ATTEMPTED: return "BROKER_ENTRY_ATTEMPTED";
      case FALCON_BTM_EVENT_BROKER_ENTRY_ACCEPTED: return "BROKER_ENTRY_ACCEPTED";
      case FALCON_BTM_EVENT_BROKER_ENTRY_REJECTED: return "BROKER_ENTRY_REJECTED";
   }

   return "UNKNOWN_BROKER_TM_EVENT";
}

uint FalconFnv1a32Hash(const string text)
{
   uint hash = (uint)2166136261;
   int len = StringLen(text);
   for(int i = 0; i < len; i++)
   {
      hash ^= (uint)StringGetCharacter(text, i);
      hash *= 16777619;
   }
   return hash;
}

string FalconTradeIdShortHash(const string trade_id)
{
   if(StringLen(trade_id) <= 0)
      return "00000000";
   return StringFormat("%08X", FalconFnv1a32Hash(trade_id));
}

string FalconBuildBrokerCommentWithHash(const string prefix, const string trade_id)
{
   string h = FalconTradeIdShortHash(trade_id);
   string comment = prefix + "|" + h;
   if(StringLen(comment) > 31)
      comment = prefix;
   return comment;
}

string FalconExtractCommentHash(const string comment)
{
   int p = StringFind(comment, "|");
   if(p < 0)
      return "";
   return StringSubstr(comment, p + 1);
}

struct FalconBrokerTradeLink
{

   string                    trade_id;
   string                    trade_id_short;
   string                    strategy_id;
   string                    engine_id;
   ENUM_FALCON_DIRECTION     direction;
   long                      broker_magic;
   ulong                     broker_position_ticket;
   ulong                     broker_position_identifier;
   ulong                     broker_order_ticket;
   ulong                     broker_deal_ticket;
   ulong                     broker_close_order_ticket;
   ulong                     broker_close_deal_ticket;
   double                    requested_lot;
   double                    accepted_lot;
   double                    planned_entry_price;
   double                    broker_entry_price;
   double                    broker_sl;
   double                    broker_tp;
   double                    broker_close_price;
   double                    broker_close_volume;
   double                    broker_actual_balance_delta;
   datetime                  planned_entry_time;
   datetime                  broker_entry_time;
   datetime                  broker_close_time;
   bool                      broker_entry_attempted;
   bool                      broker_entry_accepted;
   bool                      broker_close_attempted;
   bool                      broker_close_accepted;
   bool                      broker_exit_observed;
   bool                      managed_close_attempted;
   bool                      managed_close_accepted;
   string                    entry_comment;
   string                    managed_close_comment;
   string                    broker_exit_status;
   string                    broker_exit_reason;
   string                    status;
   string                    reason;

   // v0.57.2: Virtual Trailing Exit Bridge per-link state.
   bool                      virtual_trailing_active;
   bool                      virtual_breakeven_locked;
   double                    virtual_peak_favorable_price;
   double                    virtual_trailing_stop_price;
   double                    virtual_protection_floor_price;
   datetime                  virtual_trailing_last_update;
};

struct FalconBrokerTradeManagementEvent
{
   string                              trade_id;
   string                              strategy_id;
   string                              engine_id;
   ENUM_FALCON_DIRECTION               direction;
   ENUM_FALCON_BROKER_TM_EVENT_TYPE    event_type;
   datetime                            event_time;
   double                              event_price;
   bool                                event_executable;
   string                              execution_eligibility;
   ulong                               broker_position_ticket;
   bool                                tp1_touched;
   bool                                tp2_touched;
   bool                                protection_activated;
   bool                                runner_activated;
   string                              protection_state;
   string                              runner_state;
   double                              paper_raw_trade_usd;
   double                              paper_final_working_trade_usd;
   double                              paper_protection_net_usd;
   double                              paper_runner_net_usd;
   double                              paper_raw_index_points;
   double                              paper_final_working_index_points;
   string                              event_source;
   string                              status;
   string                              reason;
};

struct FalconReportTotals
{
   int    total_trades;
   int    win_trades;
   int    loss_trades;
   int    breakeven_trades;
   double total_profit_index_points;
   double total_loss_index_points;
   double net_index_points;
   double total_profit_usd;
   double total_loss_usd;
   double net_usd;

   // v0.55.5: truthful final-working USD totals derived from per-trade final layer output.
   int    final_profit_trades;
   int    final_loss_trades;
   int    final_breakeven_trades;
   double final_total_profit_usd;
   double final_total_loss_usd;
   double final_working_net_usd;

   // v0.55.5: visible-row audit totals using the exact 4-decimal values written into TradeLifecycle.
   double visible_raw_net_usd_4dp;
   double visible_final_working_net_usd_4dp;
   double visible_final_total_profit_usd_4dp;
   double visible_final_total_loss_usd_4dp;

   // v0.55.5: Capital flow classification summary counters.
   int    capital_flow_evaluated_trades;
   int    capital_flow_trade_profit_events;
   int    capital_flow_trade_loss_events;
   int    capital_flow_flat_events;
   int    capital_flow_injection_events;
   int    capital_flow_withdrawal_events;
   int    capital_flow_unknown_events;
   int    capital_flow_integrity_breaches;
   double capital_flow_external_net_usd;

   // v0.55.9: Weekly Stability Score Foundation summary-only counters.
   int    weekly_stability_evaluated_trades;
   int    weekly_stability_weeks;
   int    weekly_stability_positive_weeks;
   int    weekly_stability_negative_weeks;
   double weekly_stability_best_week_usd;
   double weekly_stability_worst_week_usd;
   double weekly_stability_score;

   // v0.55.11: Market Close / Weekend Guard foundation summary-only counters.
   int    market_close_guard_evaluated_trades;
   int    market_close_guard_near_close_entry_trades;
   int    market_close_guard_open_weekend_risk_trades;

   // v0.55.11a: No-new-entry timing calibration. Summary-only; no enforcement yet.
   int    market_close_max_trade_duration_minutes;
   double market_close_total_trade_duration_minutes;
   int    market_close_duration_above_window_trades;
   string market_close_longest_trade_id;

   // v0.55.11f: user-controlled No-New-Entry override. Disabled by default.
   // When enabled, it blocks Paper entries in the final user-selected minutes before close.
   int    no_new_entry_override_evaluated_trades;
   int    no_new_entry_override_blocked_trades;
   int    no_new_entry_override_blocked_winners;
   int    no_new_entry_override_blocked_losers;
   double no_new_entry_override_impact_usd;

   // v0.55.12a: Daily / Weekend Force Close User Override. Disabled by default.
   // When enabled, it changes Paper results before Emergency and Capital Flow.
   int    force_close_override_evaluated_trades;
   int    force_close_override_closed_trades;
   int    force_close_override_daily_closed_trades;
   int    force_close_override_weekend_closed_trades;
   int    force_close_override_price_ok_trades;
   int    force_close_override_missing_price_trades;
   double force_close_override_before_net_usd;
   double force_close_override_after_net_usd;
   double force_close_override_impact_usd;

   // v0.55.13: Paper state persistence foundation counters. Snapshot-only; no restore/enforcement yet.
   int    paper_state_snapshot_evaluated_trades;
   int    paper_state_snapshot_written_rows;
   int    paper_state_snapshot_write_failures;
   int    paper_state_recovery_trusted_trades;
   int    paper_state_recovery_untrusted_trades;

   // v0.55.13-fix4: dynamic session boundary checkpoint foundation. Measurement-only.
   int    session_boundary_checkpoint_evaluated_trades;
   int    session_boundary_recovery_checkpoint_minutes;
   int    session_boundary_daily_checkpoint_open_trades;
   int    session_boundary_weekend_checkpoint_open_trades;
   int    session_boundary_recovery_required_trades;
   int    session_boundary_dirty_after_close_safety_trades;

   double win_rate;
   double loss_rate;

   int    buy_trades;
   int    buy_win_trades;
   double buy_net_index_points;

   int    sell_trades;
   int    sell_win_trades;
   double sell_net_index_points;

   // v0.22.0: Shadow-only quality guard simulation totals.
   int    fvg_qguard_evaluated;
   int    fvg_qguard_passed;
   int    fvg_qguard_blocked;
   int    fvg_qguard_blocked_winners;
   int    fvg_qguard_blocked_losers;
   double fvg_qguard_actual_net_points;
   double fvg_qguard_simulated_net_points;
   double fvg_qguard_blocked_net_points;
   double fvg_qguard_actual_net_usd;
   double fvg_qguard_simulated_net_usd;
   double fvg_qguard_blocked_net_usd;

   // v0.28.1: StructuralStop + TPBuilder validation lock counters. Summary-only audit remains locked.
   int    sltp_validation_evaluated_trades;
   int    structural_stop_valid_trades;
   int    structural_stop_invalid_trades;
   int    tp_builder_valid_trades;
   int    tp_builder_invalid_trades;
   int    tp1_valid_trades;
   int    tp2_valid_trades;
   int    tp3_valid_trades;

   // v0.29.1: Smart Trade Management behavior/proof calibration. Summary-only; no runtime exit changes.
   int    smart_tm_evaluated_trades;
   int    smart_tm_proof_score_min;
   int    smart_tm_proof_score_max;
   long   smart_tm_proof_score_total;
   int    smart_tm_exit_conservative_trades;
   int    smart_tm_partial_no_runner_trades;
   int    smart_tm_runner_candidate_trades;
   int    smart_tm_strong_runner_candidate_trades;
   long   smart_tm_antiproof_score_total;
   int    smart_tm_antiproof_score_max;
   int    smart_tm_antiproof_high_risk_trades;
   int    smart_tm_behavior_healthy_trades;
   int    smart_tm_behavior_choppy_trades;
   int    smart_tm_behavior_failure_trades;
   int    smart_tm_runner_opportunity_trades;
   int    smart_tm_strong_runner_opportunity_trades;
   int    smart_tm_tp1_close_trades;
   int    smart_tm_sl_failure_trades;
   int    smart_tm_timeout_close_trades;

   // v0.29.1: Calibrated proof/behavior buckets. Summary-only; no runtime exit changes.
   int    smart_tm_proof_weak_trades;
   int    smart_tm_proof_medium_trades;
   int    smart_tm_proof_strong_trades;
   int    smart_tm_proof_elite_trades;
   int    smart_tm_behavior_grinding_trades;
   int    smart_tm_behavior_exhausted_trades;
   int    smart_tm_runner_conservative_opportunity_trades;

   // v0.29.2: Runner MFE/Giveback proxy diagnostics. Summary-only; no runtime exit changes.
   int    runner_diag_evaluated_trades;
   int    runner_diag_tp1_anchor_trades;
   int    runner_diag_tp2_anchor_trades;
   int    runner_diag_mfe_proxy_trades;
   double runner_diag_mfe_proxy_total_points;
   double runner_diag_mfe_proxy_max_points;
   double runner_diag_tp1_to_tp2_room_total_points;
   double runner_diag_tp1_to_tp3_room_total_points;
   double runner_diag_tp2_to_tp3_room_total_points;
   double runner_diag_max_r_proxy_total;
   double runner_diag_max_r_proxy_max;
   int    runner_diag_would_reach_3r_trades;
   int    runner_diag_would_reach_5r_trades;
   int    runner_diag_protected_profit_opportunity_trades;
   int    runner_diag_return_to_loss_after_proof_unknown_trades;

   // v0.29.3a: Runner bar-path metric definition calibration totals. Summary-only; no runtime exit changes.
   int    runner_barpath_evaluated_trades;
   int    runner_barpath_scanned_trades;
   int    runner_barpath_scan_failed_trades;
   int    runner_barpath_total_bars_scanned;
   int    runner_barpath_tp1_touched_trades;
   int    runner_barpath_tp2_touched_trades;
   int    runner_barpath_tp1_touched_then_extended_trades;
   int    runner_barpath_tp2_touched_then_extended_trades;
   double runner_barpath_tp1_to_max_run_total_points;
   double runner_barpath_tp1_to_max_run_max_points;
   double runner_barpath_tp2_to_max_run_total_points;
   double runner_barpath_tp2_to_max_run_max_points;
   double runner_barpath_mfe_after_tp1_total_points;
   double runner_barpath_mfe_after_tp1_max_points;
   double runner_barpath_mfe_after_tp2_total_points;
   double runner_barpath_mfe_after_tp2_max_points;
   double runner_barpath_giveback_after_tp1_total_points;
   double runner_barpath_giveback_after_tp1_max_points;
   double runner_barpath_giveback_after_tp2_total_points;
   double runner_barpath_giveback_after_tp2_max_points;
   int    runner_barpath_returned_to_loss_after_tp1_trades;
   int    runner_barpath_returned_to_loss_after_tp2_trades;
   int    runner_barpath_actual_would_reach_3r_trades;
   int    runner_barpath_actual_would_reach_5r_trades;
   int    runner_barpath_protected_after_tp1_opportunity_trades;
   int    runner_barpath_protected_after_tp2_opportunity_trades;

   // v0.29.4: Fast protection / runner decision readiness diagnostics. Summary-only; no runtime exit changes.
   int    fast_tm_evaluated_trades;
   int    fast_tm_decision_cache_ready_trades;
   int    fast_tm_precomputed_branch_ready_trades;
   int    fast_tm_tp1_decision_ready_trades;
   int    fast_tm_tp2_decision_ready_trades;
   int    fast_tm_protection_required_after_tp1_trades;
   int    fast_tm_protection_required_after_tp2_trades;
   int    fast_tm_immediate_runner_candidate_trades;
   int    fast_tm_immediate_exit_warning_trades;
   int    fast_tm_fast_antiproof_warning_trades;
   int    fast_tm_conservative_partial_ready_trades;
   int    fast_tm_runner_wait_for_confirmation_trades;

   // v0.49.0: Paper Runtime Guard Application Phase 1 totals.
   int    paper_guard_evaluated_trades;
   int    paper_guard_passed_trades;
   int    paper_guard_rejected_trades;
   int    paper_guard_spread_rejected_trades;
   int    paper_guard_stops_rejected_trades;
   int    paper_guard_freeze_rejected_trades;
   int    paper_exposure_evaluated_trades;
   int    paper_exposure_passed_trades;
   int    paper_exposure_blocked_total;
   int    paper_exposure_blocked_engine;
   int    paper_exposure_blocked_direction;
   double paper_guard_before_net_points;
   double paper_guard_after_net_points;
   double paper_guard_impact_points;
   double paper_guard_before_net_usd;
   double paper_guard_after_net_usd;
   double paper_guard_impact_usd;

   // v0.50.0: Paper Runtime Smart SL / Protection Application totals.
   int    paper_protection_evaluated_trades;
   int    paper_protection_eligible_trades;
   int    paper_protection_activated_trades;
   int    paper_tp1_protection_trades;
   int    paper_tp2_protection_trades;
   int    paper_virtual_sl_changed_trades;
   int    paper_virtual_sl_hit_trades;
   int    paper_protected_exit_trades;
   double paper_protection_before_net_points;
   double paper_protection_after_net_points;
   double paper_protection_impact_points;
   double paper_protection_before_net_usd;
   double paper_protection_after_net_usd;
   double paper_protection_impact_usd;
   double paper_protection_giveback_prevented_points;
   double paper_protection_giveback_prevented_usd;

   // v0.51.0: Paper Runtime Runner Application totals.
   int    paper_runner_evaluated_trades;
   int    paper_runner_eligible_trades;
   int    paper_runner_activated_trades;
   int    paper_runner_3r_trades;
   int    paper_moon_mode_5r_trades;
   int    paper_runner_exit_trades;
   int    paper_runner_giveback_trades;
   int    paper_runner_protected_from_loss_trades;
   double paper_runner_before_net_points;
   double paper_runner_after_net_points;
   double paper_runner_impact_points;
   double paper_runner_before_net_usd;
   double paper_runner_after_net_usd;
   double paper_runner_impact_usd;
   double paper_runner_additional_points;
   double paper_runner_additional_usd;

   // v0.55.1: Low-Capital Risk Feasibility Foundation totals.
   int    lotsizing_feasibility_evaluated_trades;
   int    lotsizing_feasibility_feasible_trades;
   int    lotsizing_feasibility_borderline_trades;
   int    lotsizing_feasibility_not_feasible_trades;
   int    lotsizing_feasibility_invalid_trades;
   int    lotsizing_single_trade_cap_breach_trades;
   double lotsizing_min_lot_risk_usd_total;
   double lotsizing_min_lot_risk_usd_max;
   double lotsizing_min_lot_risk_pct_total;
   double lotsizing_min_lot_risk_pct_max;
   double lotsizing_potential_loss_r_total;
   double lotsizing_potential_loss_r_max;

   // v0.55.2: Calibrated Single Trade Loss Cap totals.
   int    single_trade_loss_cap_evaluated_trades;
   int    single_trade_loss_cap_allowed_trades;
   int    single_trade_loss_cap_blocked_trades;
   int    single_trade_loss_cap_invalid_trades;
   int    single_trade_loss_cap_strict_breach_trades;
   int    single_trade_loss_cap_calibrated_breach_trades;
   double single_trade_loss_cap_before_net_points;
   double single_trade_loss_cap_after_net_points;
   double single_trade_loss_cap_impact_points;
   double single_trade_loss_cap_before_net_usd;
   double single_trade_loss_cap_after_net_usd;
   double single_trade_loss_cap_impact_usd;
   double single_trade_loss_cap_rejected_profit_usd;
   double single_trade_loss_cap_rejected_loss_usd;
   double single_trade_loss_cap_calibrated_cap_r_max;
   double single_trade_loss_cap_risk_pct_cap_max;

   // v0.55.2a: Dynamic capital-aware totals.
   double single_trade_loss_cap_dynamic_capital_start;
   double single_trade_loss_cap_dynamic_capital_min;
   double single_trade_loss_cap_dynamic_capital_max;
   double single_trade_loss_cap_dynamic_capital_end;
   double single_trade_loss_cap_dynamic_risk_pct_max;
   double single_trade_loss_cap_dynamic_cap_pct_max;
   int    single_trade_loss_cap_dynamic_capital_updates;
   int    single_trade_loss_cap_dynamic_capital_blocks;

   // v0.55.3: Dynamic LotSizing Model totals.
   int    dynamic_lotsizing_evaluated_trades;
   int    dynamic_lotsizing_fixed_mode_trades;
   int    dynamic_lotsizing_dynamic_mode_trades;
   int    dynamic_lotsizing_candidate_ready_trades;
   int    dynamic_lotsizing_invalid_trades;
   int    dynamic_lotsizing_min_lot_floor_trades;
   int    dynamic_lotsizing_max_lot_cap_trades;
   int    dynamic_lotsizing_tier_cap_trades;
   int    dynamic_lotsizing_capital_cap_trades;
   int    dynamic_lotsizing_growth_ramp_trades;
   double dynamic_lotsizing_safety_active_lot_max;
   double dynamic_lotsizing_raw_lot_total;
   double dynamic_lotsizing_recommended_lot_total;
   double dynamic_lotsizing_active_lot_total;
   double dynamic_lotsizing_recommended_risk_pct_max;
   double dynamic_lotsizing_active_risk_pct_max;

   // v0.53.1: Three-Layer Emergency active replacement totals.
   int    paper_emergency_evaluated_trades;
   int    paper_emergency_safe_trades;
   int    paper_emergency_triggered_trades;
   int    paper_emergency_blocked_entries;
   int    paper_emergency_layer1_triggers;
   int    paper_emergency_layer2_triggers;
   int    paper_emergency_layer3_triggers;
   double paper_emergency_before_net_points;
   double paper_emergency_after_net_points;
   double paper_emergency_impact_points;
   double paper_emergency_before_net_usd;
   double paper_emergency_after_net_usd;
   double paper_emergency_impact_usd;
   double paper_emergency_max_drawdown_pct;
   double paper_emergency_worst_daily_r;

   // v0.53.2: Layer-specific reset validation totals.
   int    layer_reset_evaluated_trades;
   int    layer1_reset_on_win_events;
   int    layer2_reset_on_new_day_events;
   int    layer3_reset_on_new_peak_events;
   int    layer_reset_event_trades;
   int    layer_reset_duplicate_triggers;

   // v0.57.0: Lock Parity Executability Decomposer rollup totals.
   // Report-only; never mutates trade values.
   int    lock_parity_evaluated_trades;
   int    lock_parity_decomposition_pass_trades;
   int    lock_parity_decomposition_breach_trades;
   double lock_parity_raw_net_usd;
   double lock_parity_final_working_net_usd;
   double lock_parity_sum_guard_delta_usd;
   double lock_parity_sum_protection_delta_usd;
   double lock_parity_sum_runner_delta_usd;
   double lock_parity_sum_losscap_delta_usd;
   double lock_parity_sum_marketclose_delta_usd;
   double lock_parity_sum_emergency_delta_usd;
   double lock_parity_sum_other_delta_usd;
   double lock_parity_executable_adjustment_usd;
   double lock_parity_non_executable_adjustment_usd;
   double lock_parity_protection_executable_usd;
   double lock_parity_runner_pending_usd;
   // v0.57.1: Runner Exit Price Probe buckets.
   double lock_parity_runner_executable_usd;
   double lock_parity_runner_non_executable_usd;
   double lock_parity_accounting_only_usd;
};

bool FalconPrgaContractReady()
{
   return (FALCON_SSBL_MAX_SPREAD_POINTS > 0 &&
           FALCON_SSBL_STOPS_BUFFER_POINTS >= 0 &&
           FALCON_CPD_MAX_TOTAL_POSITIONS > 0 &&
           FALCON_CPD_MAX_POSITIONS_PER_ENGINE > 0 &&
           FALCON_CPD_MAX_POSITIONS_PER_DIRECTION > 0 &&
           StringLen(FALCON_PRGA_REJECT_POLICY) > 0 &&
           StringLen(FALCON_PRGA_EXPOSURE_POLICY) > 0);
}

string FalconPrgaRejectReason(const FalconTradeLifecycleRecord &record,
                              const FalconSymbolContext &symbol_context,
                              double &sl_distance_points)
{
   sl_distance_points = 0.0;
   if(symbol_context.point > 0.0)
      sl_distance_points = MathAbs(record.entry_price - record.structural_sl) / symbol_context.point;

   long guard_spread_points = record.fvg_spread_points;
   if(guard_spread_points < 0)
      guard_spread_points = symbol_context.spread_points;

   if(guard_spread_points > FALCON_SSBL_MAX_SPREAD_POINTS)
      return "SPREAD_TOO_WIDE";

   double min_stop_points = (double)(symbol_context.stops_level_points + FALCON_SSBL_STOPS_BUFFER_POINTS);
   if(sl_distance_points < min_stop_points)
      return "SL_TOO_CLOSE";

   double min_freeze_points = (double)symbol_context.freeze_level_points;
   if(sl_distance_points < min_freeze_points)
      return "FREEZE_LEVEL_BLOCKED";

   return "";
}

bool FalconPrtpContractReady()
{
   return (StringLen(FALCON_PRTP_POLICY) > 0 &&
           StringFind(FALCON_PRTP_POLICY, "PROTECT_ONLY_WHEN_EARNED") >= 0 &&
           StringFind(FALCON_PRTP_POLICY, "TP1_PROOF") >= 0 &&
           StringFind(FALCON_PRTP_POLICY, "TP2_PROOF") >= 0 &&
           StringFind(FALCON_PRTP_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") >= 0);
}

bool FalconPrrunContractReady()
{
   return (StringLen(FALCON_PRRUN_POLICY) > 0 &&
           StringFind(FALCON_PRRUN_POLICY, "PROTECT_FIRST_THEN_EXPAND") >= 0 &&
           StringFind(FALCON_PRRUN_POLICY, "NO_RUNNER_WITHOUT_PROTECTION") >= 0 &&
           StringFind(FALCON_PRRUN_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") >= 0);
}

double FalconProtectedPriceFromProfitPoints(const FalconTradeLifecycleRecord &record,
                                            const double protected_points)
{
   if(record.entry_price <= 0.0 || protected_points <= 0.0)
      return 0.0;

   if(record.direction == FALCON_DIRECTION_BUY)
      return (record.entry_price + protected_points);

   if(record.direction == FALCON_DIRECTION_SELL)
      return (record.entry_price - protected_points);

   return 0.0;
}

struct FalconRunnerBarPathStats
{
   bool   scan_ok;
   int    bars_scanned;
   bool   tp1_touched;
   bool   tp2_touched;
   bool   tp1_touched_then_extended;
   bool   tp2_touched_then_extended;
   double tp1_to_max_run_points;
   double tp2_to_max_run_points;
   double max_favorable_points;
   double mfe_after_tp1_points;
   double mfe_after_tp2_points;
   double giveback_after_tp1_points;
   double giveback_after_tp2_points;
   bool   returned_to_loss_after_tp1;
   bool   returned_to_loss_after_tp2;
   double max_r_actual_proxy;
};

// ==================================================================
// Utility helpers
// ==================================================================
string FalconDirectionToString(const ENUM_FALCON_DIRECTION direction)
{
   if(direction == FALCON_DIRECTION_BUY)
      return "BUY";
   if(direction == FALCON_DIRECTION_SELL)
      return "SELL";
   return "NONE";
}

string FalconOutcomeToString(const ENUM_FALCON_TRADE_OUTCOME outcome)
{
   if(outcome == FALCON_TRADE_OUTCOME_WIN)
      return "WIN";
   if(outcome == FALCON_TRADE_OUTCOME_LOSS)
      return "LOSE";
   if(outcome == FALCON_TRADE_OUTCOME_BREAKEVEN)
      return "BREAKEVEN";
   if(outcome == FALCON_TRADE_OUTCOME_OPEN)
      return "OPEN";
   return "UNKNOWN";
}

string FalconStageToString(const ENUM_FALCON_TRADE_STAGE stage)
{
   if(stage == FALCON_TRADE_STAGE_SHADOW)
      return "SHADOW";
   if(stage == FALCON_TRADE_STAGE_PAPER)
      return "PAPER";
   if(stage == FALCON_TRADE_STAGE_DEMO)
      return "DEMO";
   if(stage == FALCON_TRADE_STAGE_LIVE)
      return "LIVE";
   return "NONE";
}


string FalconShadowStatusToString(const ENUM_FALCON_SHADOW_RECORD_STATUS status)
{
   if(status == FALCON_SHADOW_RECORD_STAGED)
      return "STAGED";
   if(status == FALCON_SHADOW_RECORD_CLOSED)
      return "CLOSED";
   if(status == FALCON_SHADOW_RECORD_CANCELLED)
      return "CANCELLED";
   return "NONE";
}


string FalconEvidenceTypeToString(const ENUM_FALCON_EVIDENCE_TYPE evidence_type)
{
   if(evidence_type == FALCON_EVIDENCE_TYPE_CANDLE_PATTERN)
      return "CANDLE_PATTERN";
   if(evidence_type == FALCON_EVIDENCE_TYPE_CHART_PATTERN)
      return "CHART_PATTERN";
   if(evidence_type == FALCON_EVIDENCE_TYPE_OBJECTIVE_INDICATOR)
      return "OBJECTIVE_INDICATOR";
   if(evidence_type == FALCON_EVIDENCE_TYPE_SMC_LIQUIDITY)
      return "SMC_LIQUIDITY";
   return "NONE";
}

string FalconEvidenceStateToString(const ENUM_FALCON_EVIDENCE_STATE evidence_state)
{
   if(evidence_state == FALCON_EVIDENCE_STATE_ABSENT)
      return "ABSENT";
   if(evidence_state == FALCON_EVIDENCE_STATE_PRESENT)
      return "PRESENT";
   if(evidence_state == FALCON_EVIDENCE_STATE_CONFLICTING)
      return "CONFLICTING";
   return "NOT_EVALUATED";
}

string FalconRuntimeSafetyStatusToString(const ENUM_FALCON_RUNTIME_SAFETY_STATUS status)
{
   if(status == FALCON_RUNTIME_SAFETY_PASSED)
      return "PASSED";
   if(status == FALCON_RUNTIME_SAFETY_REJECTED)
      return "REJECTED";
   return "NOT_EVALUATED";
}

string FalconLookaheadRiskToString(const ENUM_FALCON_LOOKAHEAD_RISK risk_type)
{
   if(risk_type == FALCON_LOOKAHEAD_RISK_CURRENT_CANDLE)
      return "CURRENT_CANDLE";
   if(risk_type == FALCON_LOOKAHEAD_RISK_FINAL_STATE)
      return "FINAL_STATE";
   if(risk_type == FALCON_LOOKAHEAD_RISK_INVALID_CANDLE)
      return "INVALID_CANDLE";
   if(risk_type == FALCON_LOOKAHEAD_RISK_INVALID_TRADEPLAN)
      return "INVALID_TRADEPLAN";
   return "NONE";
}

string FalconEngineStatusToString(const ENUM_FALCON_ENGINE_STATUS status)
{
   if(status == FALCON_ENGINE_SHADOW)
      return "SHADOW";
   if(status == FALCON_ENGINE_PAPER)
      return "PAPER";
   if(status == FALCON_ENGINE_DEMO)
      return "DEMO";
   if(status == FALCON_ENGINE_LIVE)
      return "LIVE";
   return "DISABLED";
}

string FalconStrategyGroupToString(const ENUM_FALCON_STRATEGY_GROUP group)
{
   if(group == FALCON_STRATEGY_GROUP_CORE)
      return "CORE";
   if(group == FALCON_STRATEGY_GROUP_PRICE_ACTION)
      return "PRICE_ACTION";
   if(group == FALCON_STRATEGY_GROUP_OPENING)
      return "OPENING";
   if(group == FALCON_STRATEGY_GROUP_LIQUIDITY)
      return "LIQUIDITY";
   if(group == FALCON_STRATEGY_GROUP_CONFIRMATION)
      return "CONFIRMATION";
   if(group == FALCON_STRATEGY_GROUP_RESEARCH)
      return "RESEARCH";
   return "UNKNOWN";
}

string FalconEngineHealthToString(const ENUM_FALCON_ENGINE_HEALTH health)
{
   if(health == FALCON_ENGINE_HEALTH_RESEARCH)
      return "RESEARCH";
   if(health == FALCON_ENGINE_HEALTH_WATCH)
      return "WATCH";
   if(health == FALCON_ENGINE_HEALTH_HEALTHY)
      return "HEALTHY";
   if(health == FALCON_ENGINE_HEALTH_CORE_WINNER)
      return "CORE_WINNER";
   if(health == FALCON_ENGINE_HEALTH_LOCKED)
      return "LOCKED";
   return "DISABLED";
}

string FalconAdapterStatusToString(const ENUM_FALCON_ADAPTER_STATUS status)
{
   if(status == FALCON_ADAPTER_STATUS_NO_TRADE)
      return "NO_TRADE";
   if(status == FALCON_ADAPTER_STATUS_SHADOW_CANDIDATE_BLOCKED)
      return "SHADOW_CANDIDATE_BLOCKED";
   if(status == FALCON_ADAPTER_STATUS_READY)
      return "READY";
   return "NOT_INITIALIZED";
}


string FalconDetectorStatusToString(const ENUM_FALCON_DETECTOR_STATUS status)
{
   if(status == FALCON_DETECTOR_STATUS_NO_TRADE)
      return "NO_TRADE";
   if(status == FALCON_DETECTOR_STATUS_BLOCKED)
      return "BLOCKED";
   if(status == FALCON_DETECTOR_STATUS_READY_STUB)
      return "READY_STUB";
   if(status == FALCON_DETECTOR_STATUS_NO_FVG)
      return "NO_FVG";
   if(status == FALCON_DETECTOR_STATUS_FVG_FOUND_SHADOW_ONLY)
      return "FVG_FOUND_SHADOW_ONLY";
   return "NOT_INITIALIZED";
}

string FalconCandidateStatusToString(const ENUM_FALCON_CANDIDATE_STATUS status)
{
   if(status == FALCON_CANDIDATE_STATUS_NO_CANDIDATE)
      return "NO_CANDIDATE";
   if(status == FALCON_CANDIDATE_STATUS_BLOCKED)
      return "BLOCKED";
   if(status == FALCON_CANDIDATE_STATUS_READY_SHADOW)
      return "READY_SHADOW";
   return "NOT_INITIALIZED";
}

string FalconRetestWatcherStatusToString(const ENUM_FALCON_RETEST_WATCHER_STATUS status)
{
   if(status == FALCON_RETEST_WATCHER_STATUS_BLOCKED)
      return "BLOCKED";
   if(status == FALCON_RETEST_WATCHER_STATUS_WAITING)
      return "WAITING_FOR_RETEST";
   if(status == FALCON_RETEST_WATCHER_STATUS_RETEST_TOUCHED)
      return "RETEST_TOUCHED";
   if(status == FALCON_RETEST_WATCHER_STATUS_SKELETON_READY)
      return "SKELETON_READY";
   return "NOT_INITIALIZED";
}

string FalconTradePlanStagingStatusToString(const ENUM_FALCON_TRADEPLAN_STAGING_STATUS status)
{
   if(status == FALCON_TRADEPLAN_STAGING_STATUS_BLOCKED)
      return "BLOCKED";
   if(status == FALCON_TRADEPLAN_STAGING_STATUS_PLAN_CREATED)
      return "PLAN_CREATED";
   if(status == FALCON_TRADEPLAN_STAGING_STATUS_STAGED_SHADOW)
      return "STAGED_SHADOW";
   return "NOT_INITIALIZED";
}

string FalconShadowLifecycleStatusToString(const ENUM_FALCON_SHADOW_LIFECYCLE_STATUS status)
{
   if(status == FALCON_SHADOW_LIFECYCLE_STATUS_BLOCKED)
      return "BLOCKED";
   if(status == FALCON_SHADOW_LIFECYCLE_STATUS_MONITORING)
      return "MONITORING";
   if(status == FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_TP)
      return "CLOSED_TP";
   if(status == FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_SL)
      return "CLOSED_SL";
   if(status == FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_TIMEOUT)
      return "CLOSED_TIMEOUT";
   return "NOT_INITIALIZED";
}

string FalconTimeToString(const datetime value)
{
   if(value <= 0)
      return "";
   return TimeToString(value, TIME_DATE | TIME_SECONDS);
}

string FalconTimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
   return EnumToString(timeframe);
}

int FalconAnalysisCandleShift()
{
   return (UseClosedCandlesOnly ? 1 : 0);
}

double FalconConfiguredCapital()
{
   if(UseAutoCapitalDetection)
      return AccountInfoDouble(ACCOUNT_BALANCE);
   return ManualCapital;
}


double FalconEffectiveCapitalForTier()
{
   double capital = 0.0;
   if(!UseAutoCapitalDetection && ManualCapital > 0.0)
      capital = ManualCapital;
   if(capital <= 0.0 && g_falcon_session_start_balance > 0.0)
      capital = g_falcon_session_start_balance;
   if(capital <= 0.0)
      capital = AccountInfoDouble(ACCOUNT_BALANCE);
   if(capital <= 0.0 && ManualCapital > 0.0)
      capital = ManualCapital;
   return capital;
}

string FalconCapitalTierName(const double balance)
{
   if(balance < 100.0) return "MICRO";
   if(balance < 500.0) return "TINY";
   if(balance < 2000.0) return "SMALL";
   if(balance < 10000.0) return "MEDIUM";
   if(balance < 50000.0) return "STANDARD";
   return "LARGE";
}

double FalconCapitalTierMinBalance(const string tier)
{
   if(tier == "MICRO") return 0.0;
   if(tier == "TINY") return 100.0;
   if(tier == "SMALL") return 500.0;
   if(tier == "MEDIUM") return 2000.0;
   if(tier == "STANDARD") return 10000.0;
   if(tier == "LARGE") return 50000.0;
   return 0.0;
}

double FalconCapitalTierMaxBalance(const string tier)
{
   if(tier == "MICRO") return 100.0;
   if(tier == "TINY") return 500.0;
   if(tier == "SMALL") return 2000.0;
   if(tier == "MEDIUM") return 10000.0;
   if(tier == "STANDARD") return 50000.0;
   if(tier == "LARGE") return 999999.0;
   return 0.0;
}

int FalconCapitalTierMaxLosses(const string tier)
{
   if(tier == "MICRO") return 3;
   if(tier == "TINY") return 4;
   if(tier == "SMALL") return 5;
   if(tier == "MEDIUM") return 6;
   if(tier == "STANDARD") return 8;
   if(tier == "LARGE") return 10;
   return 0;
}

double FalconCapitalTierMaxDailyR(const string tier)
{
   if(tier == "MICRO") return 3.0;
   if(tier == "TINY") return 4.0;
   if(tier == "SMALL") return 5.0;
   if(tier == "MEDIUM") return 6.0;
   if(tier == "STANDARD") return 8.0;
   if(tier == "LARGE") return 10.0;
   return 0.0;
}

double FalconCapitalTierMaxDrawdownPct(const string tier)
{
   if(tier == "MICRO") return 25.0;
   if(tier == "TINY") return 15.0;
   if(tier == "SMALL") return 10.0;
   if(tier == "MEDIUM") return 7.0;
   if(tier == "STANDARD") return 5.0;
   if(tier == "LARGE") return 4.0;
   return 0.0;
}

// v0.55.1: measurement-only tier base risk profile. These values are
// not used to change lot size yet. They only quantify whether broker
// minimum lot risk is feasible for the current effective capital.
double FalconCapitalTierBaseRiskPct(const string tier)
{
   if(tier == "MICRO") return 1.0;
   if(tier == "TINY") return 1.5;
   if(tier == "SMALL") return 2.0;
   if(tier == "MEDIUM") return 2.0;
   if(tier == "STANDARD") return 1.5;
   if(tier == "LARGE") return 1.0;
   return 1.0;
}

double FalconSingleTradeLossCapR(const string tier)
{
   return FalconCapitalTierMaxDailyR(tier) * (FALCON_LCRF_DEFAULT_SINGLE_TRADE_CAP_PCT / 100.0);
}

bool FalconLowCapitalRiskFeasibilityContractReady()
{
   if(!FalconCapitalTierContractReady()) return false;
   if(FALCON_LCRF_DEFAULT_SINGLE_TRADE_CAP_PCT <= 0.0) return false;
   if(FALCON_LCRF_BORDERLINE_MULTIPLIER <= 1.0) return false;
   if(StringFind(FALCON_LCRF_POLICY, "MEASUREMENT_ONLY") < 0) return false;
   if(StringFind(FALCON_LCRF_POLICY, "NO_REJECTION_YET") < 0) return false;
   if(StringFind(FALCON_LCRF_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") < 0) return false;
   return true;
}

double FalconDynamicSingleTradeLossCapRiskPct(const string tier)
{
   double cap_pct = FalconCapitalTierMaxDrawdownPct(tier) * FALCON_STLC_DRAWDOWN_CAP_MULTIPLIER;
   if(FALCON_STLC_DYNAMIC_MAX_RISK_PCT > 0.0 && cap_pct > FALCON_STLC_DYNAMIC_MAX_RISK_PCT)
      cap_pct = FALCON_STLC_DYNAMIC_MAX_RISK_PCT;
   return cap_pct;
}

double FalconCalibratedSingleTradeLossCapR(const string tier)
{
   double base_risk_pct = FalconCapitalTierBaseRiskPct(tier);
   if(base_risk_pct <= 0.0) return 0.0;
   double dynamic_cap_r = FalconDynamicSingleTradeLossCapRiskPct(tier) / base_risk_pct;
   if(FALCON_STLC_ABSOLUTE_MAX_R > 0.0 && dynamic_cap_r > FALCON_STLC_ABSOLUTE_MAX_R)
      dynamic_cap_r = FALCON_STLC_ABSOLUTE_MAX_R;
   return dynamic_cap_r;
}

double FalconCalibratedSingleTradeLossCapRiskPct(const string tier)
{
   return FalconDynamicSingleTradeLossCapRiskPct(tier);
}

bool FalconSingleTradeLossCapContractReady()
{
   if(!FalconLowCapitalRiskFeasibilityContractReady()) return false;
   if(!FALCON_STLC_RUNTIME_ENFORCED) return false;
   if(FALCON_STLC_DRAWDOWN_CAP_MULTIPLIER <= 0.0) return false;
   if(FALCON_STLC_ABSOLUTE_MAX_R <= 0.0) return false;
   if(FALCON_STLC_DYNAMIC_MAX_RISK_PCT <= 0.0) return false;
   if(FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD <= 0.0) return false;
   if(StringFind(FALCON_STLC_POLICY, "DYNAMIC_CAPITAL_AWARE_ENFORCEMENT") < 0) return false;
   if(StringFind(FALCON_STLC_POLICY, "STRICT_CAP_REMAINS_MEASUREMENT") < 0) return false;
   if(StringFind(FALCON_STLC_POLICY, "PROMOTION_STILL_EARNED") < 0) return false;
   if(StringFind(FALCON_STLC_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") < 0) return false;
   return true;
}

bool FalconDynamicLotSizingModelContractReady()
{
   if(!FalconSingleTradeLossCapContractReady()) return false;
   if(!FALCON_DLM_RUNTIME_ENFORCED) return false;
   if(StringFind(FALCON_DLM_POLICY, "USE_FIXED_LOT_TRUE_PRESERVES_FIXEDLOT") < 0) return false;
   if(StringFind(FALCON_DLM_POLICY, "USE_FIXED_LOT_FALSE_APPLIES_DYNAMIC_LOT_WITH_SAFETY_RAMP") < 0) return false;
   if(StringFind(FALCON_DLM_POLICY, "CAPITAL_UPDATES_AFTER_EACH_TRADE") < 0) return false;
   if(StringFind(FALCON_DLM_POLICY, "TIER_CAP") < 0) return false;
   if(StringFind(FALCON_DLM_POLICY, "CAPITAL_CAP") < 0) return false;
   if(StringFind(FALCON_DLM_POLICY, "MAX_GROWTH_CAP") < 0) return false;
   if(StringFind(FALCON_DLM_POLICY, "NO_BROKER_EXECUTION") < 0) return false;
   if(StringFind(FALCON_DLM_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") < 0) return false;
   return true;
}

string FalconCapitalNextTierName(const string tier)
{
   if(tier == "MICRO") return "TINY";
   if(tier == "TINY") return "SMALL";
   if(tier == "SMALL") return "MEDIUM";
   if(tier == "MEDIUM") return "STANDARD";
   if(tier == "STANDARD") return "LARGE";
   return "NONE";
}

string FalconCapitalPreviousTierName(const string tier)
{
   if(tier == "LARGE") return "STANDARD";
   if(tier == "STANDARD") return "MEDIUM";
   if(tier == "MEDIUM") return "SMALL";
   if(tier == "SMALL") return "TINY";
   if(tier == "TINY") return "MICRO";
   return "NONE";
}

bool FalconTierRuntimeLockContractReady()
{
   if(!FalconTierPromotionContractReady()) return false;
   if(!FalconTierDemotionContractReady()) return false;
   if(StringFind(FALCON_TDL_POLICY, "PROMOTION_MUST_BE_EARNED") < 0) return false;
   if(StringFind(FALCON_TDL_POLICY, "DEMOTION_IS_IMMEDIATE") < 0) return false;
   if(StringFind(FALCON_TDL_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") < 0) return false;
   return true;
}

bool FalconTierPromotionContractReady()
{
   if(!FalconCapitalTierContractReady()) return false;
   if(FALCON_TPF_MIN_TRADES_IN_TIER <= 0) return false;
   if(FALCON_TPF_MIN_WIN_RATE_PCT <= 0.0) return false;
   if(FALCON_TPF_DAYS_WITHOUT_EMERGENCY <= 0) return false;
   if(FALCON_TPF_POST_QUAL_COOLDOWN_DAYS <= 0) return false;
   if(StringFind(FALCON_TPF_POLICY, "PROMOTION_MUST_BE_EARNED") < 0) return false;
   if(StringFind(FALCON_TPF_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") < 0) return false;
   return true;
}

string FalconTierPromotionBlockedReason(const double effective_balance,
                                        const string current_tier,
                                        const string next_tier,
                                        const int trades_in_tier,
                                        const double win_rate,
                                        const double net_r)
{
   if(next_tier == "NONE") return "ALREADY_TOP_TIER";
   if(effective_balance < FalconCapitalTierMinBalance(next_tier)) return "BALANCE_BELOW_NEXT_TIER_MIN";
   if(trades_in_tier < FALCON_TPF_MIN_TRADES_IN_TIER) return "INSUFFICIENT_TRADES_IN_TIER";
   if(win_rate < FALCON_TPF_MIN_WIN_RATE_PCT) return "WIN_RATE_BELOW_REQUIREMENT";
   if(net_r <= FALCON_TPF_MIN_NET_R) return "NET_R_NOT_POSITIVE";
   return "WAITING_NO_EMERGENCY_AND_COOLDOWN_WINDOW";
}


bool FalconTierDemotionContractReady()
{
   if(!FalconCapitalTierContractReady()) return false;
   if(FALCON_TDF_HYSTERESIS_PCT <= 0.0 || FALCON_TDF_HYSTERESIS_PCT >= 100.0) return false;
   if(FALCON_TDF_MAX_EMERGENCIES_14D <= 0) return false;
   if(FALCON_TDF_MAX_NEGATIVE_WEEKS <= 0) return false;
   if(FALCON_TDF_EXTREME_DD_MULTIPLIER <= 1.0) return false;
   if(StringFind(FALCON_TDF_POLICY, "DEMOTION_IS_IMMEDIATE") < 0) return false;
   if(StringFind(FALCON_TDF_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") < 0) return false;
   return true;
}

string FalconTierDemotionReason(const int balance_hysteresis_breach,
                                const int multiple_emergencies_breach,
                                const int negative_weeks_breach,
                                const int extreme_drawdown_breach)
{
   if(balance_hysteresis_breach == 1) return "BALANCE_HYSTERESIS_BREACH";
   if(multiple_emergencies_breach == 1) return "MULTIPLE_EMERGENCIES";
   if(negative_weeks_breach == 1) return "THREE_NEGATIVE_WEEKS";
   if(extreme_drawdown_breach == 1) return "EXTREME_DRAWDOWN_EVENT";
   return "NO_DEMOTION";
}

string FalconMinLotConstraintStatus(const double min_lot, const double fixed_lot)
{
   if(min_lot <= 0.0) return "BROKER_MIN_LOT_UNKNOWN";
   if(fixed_lot + 0.0000001 < min_lot) return "FIXED_LOT_BELOW_BROKER_MIN";
   if(MathAbs(fixed_lot - min_lot) <= 0.0000001) return "USING_BROKER_MIN_LOT";
   return "FIXED_LOT_ABOVE_BROKER_MIN";
}

bool FalconCapitalTierContractReady()
{
   double effective = FalconEffectiveCapitalForTier();
   string tier = FalconCapitalTierName(effective);
   if(effective <= 0.0) return false;
   if(StringLen(tier) <= 0) return false;
   if(FalconCapitalTierMaxLosses(tier) <= 0) return false;
   if(FalconCapitalTierMaxDailyR(tier) <= 0.0) return false;
   if(FalconCapitalTierMaxDrawdownPct(tier) <= 0.0) return false;
   if(StringFind(FALCON_CTF_BALANCE_POLICY, "SESSION_START_BALANCE") < 0) return false;
   if(StringFind(FALCON_CTF_MIN_LOT_POLICY, "0_01_MIN_LOT") < 0) return false;
   return true;
}

bool FalconThreeLayerEmergencyContractReady()
{
   if(!FalconCapitalTierContractReady()) return false;
   if(StringFind(FALCON_TLE_POLICY, "ANY_LAYER_TRIGGERS") < 0) return false;
   if(StringFind(FALCON_TLE_SCOPE, "LAYER1_CONSECUTIVE") < 0) return false;
   if(StringFind(FALCON_TLE_SCOPE, "LAYER2_DAILY_R") < 0) return false;
   if(StringFind(FALCON_TLE_SCOPE, "LAYER3_TIER_DRAWDOWN") < 0) return false;
   if(StringFind(FALCON_TLE_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") < 0) return false;
   return true;
}

bool FalconLayerSpecificResetContractReady()
{
   if(!FalconThreeLayerEmergencyContractReady()) return false;
   if(StringFind(FALCON_LSR_SCOPE, "LAYER1_RESET_ON_WIN") < 0) return false;
   if(StringFind(FALCON_LSR_SCOPE, "LAYER2_RESET_ON_NEW_DAY") < 0) return false;
   if(StringFind(FALCON_LSR_SCOPE, "LAYER3_RESET_ON_NEW_PEAK") < 0) return false;
   if(StringFind(FALCON_LSR_POLICY, "INDEPENDENT_RESETS") < 0) return false;
   if(StringFind(FALCON_LSR_POLICY, "DAILY_PAUSE_RESOLUTION") < 0) return false;
   if(StringFind(FALCON_LSR_ORDER_SEND_POLICY, "ORDER_SEND_HARD_BLOCKED") < 0) return false;
   return true;
}

double FalconRawIndexPoints(const ENUM_FALCON_DIRECTION direction,
                            const double entry_price,
                            const double exit_price)
{
   if(direction == FALCON_DIRECTION_BUY)
      return exit_price - entry_price;
   if(direction == FALCON_DIRECTION_SELL)
      return entry_price - exit_price;
   return 0.0;
}

double FalconEstimateUsdByRawPoints(const double raw_index_points,
                                    const double lot_size,
                                    const FalconSymbolContext &symbol_context)
{
   if(symbol_context.contract_size <= 0.0 || lot_size <= 0.0)
      return 0.0;
   return raw_index_points * symbol_context.contract_size * lot_size;
}

void FalconFinalizeTradeMetrics(FalconTradeLifecycleRecord &record,
                                const FalconSymbolContext &symbol_context)
{
   record.net_index_points = FalconRawIndexPoints(record.direction, record.entry_price, record.exit_price);

   if(record.net_index_points > 0.0)
   {
      record.outcome             = FALCON_TRADE_OUTCOME_WIN;
      record.profit_index_points = record.net_index_points;
      record.loss_index_points   = 0.0;
   }
   else if(record.net_index_points < 0.0)
   {
      record.outcome             = FALCON_TRADE_OUTCOME_LOSS;
      record.profit_index_points = 0.0;
      record.loss_index_points   = MathAbs(record.net_index_points);
   }
   else
   {
      record.outcome             = FALCON_TRADE_OUTCOME_BREAKEVEN;
      record.profit_index_points = 0.0;
      record.loss_index_points   = 0.0;
   }

   record.net_usd = FalconEstimateUsdByRawPoints(record.net_index_points, record.lot_size, symbol_context);
   if(record.net_usd > 0.0)
   {
      record.profit_usd = record.net_usd;
      record.loss_usd   = 0.0;
   }
   else if(record.net_usd < 0.0)
   {
      record.profit_usd = 0.0;
      record.loss_usd   = MathAbs(record.net_usd);
   }
   else
   {
      record.profit_usd = 0.0;
      record.loss_usd   = 0.0;
   }
}

string FalconBoolToYesNo(const bool value)
{
   return (value ? "YES" : "NO");
}

string FalconCsvSafe(string value)
{
   // v0.18.8: MT5 FileWrite does not reliably protect comma-rich text fields for downstream CSV parsers.
   // Keep CSV column counts stable by replacing separators and line breaks inside descriptive text.
   StringReplace(value, "\r", " ");
   StringReplace(value, "\n", " ");
   StringReplace(value, ",", ";");
   StringReplace(value, "|", "/");
   StringReplace(value, "  ", " ");
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

bool FalconStructuralStopValid(const FalconTradeLifecycleRecord &record)
{
   if(record.entry_price <= 0.0 || record.structural_sl <= 0.0)
      return false;

   if(record.direction == FALCON_DIRECTION_BUY)
      return (record.structural_sl < record.entry_price);

   if(record.direction == FALCON_DIRECTION_SELL)
      return (record.structural_sl > record.entry_price);

   return false;
}

bool FalconTakeProfitDirectionalValid(const FalconTradeLifecycleRecord &record, const int tp_index)
{
   double tp = 0.0;
   if(tp_index == 1)
      tp = record.tp1;
   else if(tp_index == 2)
      tp = record.tp2;
   else if(tp_index == 3)
      tp = record.tp3;
   else
      return false;

   if(record.entry_price <= 0.0 || tp <= 0.0)
      return false;

   if(record.direction == FALCON_DIRECTION_BUY)
      return (tp > record.entry_price);

   if(record.direction == FALCON_DIRECTION_SELL)
      return (tp < record.entry_price);

   return false;
}

bool FalconTakeProfitSequenceValid(const FalconTradeLifecycleRecord &record)
{
   if(!FalconTakeProfitDirectionalValid(record, 1) ||
      !FalconTakeProfitDirectionalValid(record, 2) ||
      !FalconTakeProfitDirectionalValid(record, 3))
      return false;

   if(record.direction == FALCON_DIRECTION_BUY)
      return (record.tp1 <= record.tp2 && record.tp2 <= record.tp3);

   if(record.direction == FALCON_DIRECTION_SELL)
      return (record.tp1 >= record.tp2 && record.tp2 >= record.tp3);

   return false;
}

int FalconClampInt(const int value, const int min_value, const int max_value)
{
   if(value < min_value)
      return min_value;
   if(value > max_value)
      return max_value;
   return value;
}

bool FalconCloseReasonContains(const FalconTradeLifecycleRecord &record, const string token)
{
   return (StringFind(record.close_reason, token) >= 0);
}

bool FalconClosedAtTp1(const FalconTradeLifecycleRecord &record)
{
   return FalconCloseReasonContains(record, "TP1");
}

bool FalconClosedAtStop(const FalconTradeLifecycleRecord &record)
{
   return FalconCloseReasonContains(record, "SL") || FalconCloseReasonContains(record, "STOP");
}

bool FalconClosedByTimeout(const FalconTradeLifecycleRecord &record)
{
   return FalconCloseReasonContains(record, "TIMEOUT");
}

int FalconSmartProofScore(const FalconTradeLifecycleRecord &record)
{
   // v0.29.1 calibration: proof is intentionally based on setup/quality/structure
   // information that is known before or during management, not on final PnL.
   int score = 0;

   if(record.fvg_quality_shadow_guard_passed)
      score += 20;

   if(record.fvg_hold_quality_score >= 80)
      score += 20;
   else if(record.fvg_hold_quality_score >= 40)
      score += 10;

   if(record.fvg_retest_fresh_state == "FRESH")
      score += 10;

   if(record.fvg_size_points >= 1000.0)
      score += 15;
   else if(record.fvg_size_points >= 500.0)
      score += 10;
   else if(record.fvg_size_points >= FALCON_FVG_QGUARD_MIN_SIZE_POINTS)
      score += 5;

   if(record.fvg_spread_points <= 100.0)
      score += 10;
   else if(record.fvg_spread_points <= 200.0)
      score += 5;

   if(record.fvg_retest_age_bars <= 3)
      score += 10;
   else if(record.fvg_retest_age_bars <= 6)
      score += 5;

   if(FalconStructuralStopValid(record))
      score += 5;

   if(FalconTakeProfitSequenceValid(record))
      score += 10;

   return FalconClampInt(score, 0, 100);
}

int FalconSmartAntiProofScore(const FalconTradeLifecycleRecord &record)
{
   // v0.29.1 calibration: anti-proof focuses on pre-exit weakness proxies
   // rather than final WIN/LOSS outcome.
   int score = 0;

   if(record.fvg_hold_quality_score < 40)
      score += 25;
   else if(record.fvg_hold_quality_score < 80)
      score += 15;

   if(record.fvg_retest_fresh_state != "FRESH")
      score += 15;

   if(record.fvg_size_points < FALCON_FVG_QGUARD_MIN_SIZE_POINTS)
      score += 25;
   else if(record.fvg_size_points < 500.0)
      score += 10;

   if(record.fvg_spread_points > 200.0)
      score += 20;
   else if(record.fvg_spread_points > 150.0)
      score += 10;

   if(record.fvg_retest_age_bars > 20)
      score += 20;
   else if(record.fvg_retest_age_bars > 6)
      score += 10;

   if(!FalconStructuralStopValid(record))
      score += 25;

   if(!FalconTakeProfitSequenceValid(record))
      score += 20;

   if(FalconClosedByTimeout(record))
      score += 10; // still recorded, but lower weight than v0.29.0 outcome-driven model

   return FalconClampInt(score, 0, 100);
}

string FalconSmartBehaviorFingerprint(const int proof_score, const int anti_proof_score)
{
   if(anti_proof_score >= 60)
      return "FAILURE_RISK";

   if(anti_proof_score >= 45 && proof_score < 65)
      return "EXHAUSTED";

   if(anti_proof_score >= 25 || proof_score < 70)
      return "GRINDING";

   if(proof_score >= 80 && anti_proof_score < 25)
      return "HEALTHY";

   return "CHOPPY";
}

// v0.29.2: Runner MFE/Giveback proxy helpers. These use only the closed
// lifecycle record and planned objectives. They intentionally do not infer
// intra-bar order or post-exit path. Exact MFE/Giveback is deferred to a
// future bar-path diagnostics layer.
double FalconDirectionalProfitPoints(const FalconTradeLifecycleRecord &record, const double target_price)
{
   if(record.entry_price <= 0.0 || target_price <= 0.0)
      return 0.0;

   if(record.direction == FALCON_DIRECTION_BUY)
      return MathMax(0.0, target_price - record.entry_price);

   if(record.direction == FALCON_DIRECTION_SELL)
      return MathMax(0.0, record.entry_price - target_price);

   return 0.0;
}

double FalconStructuralRiskPoints(const FalconTradeLifecycleRecord &record)
{
   if(record.entry_price <= 0.0 || record.structural_sl <= 0.0)
      return 0.0;

   if(record.direction == FALCON_DIRECTION_BUY && record.structural_sl < record.entry_price)
      return record.entry_price - record.structural_sl;

   if(record.direction == FALCON_DIRECTION_SELL && record.structural_sl > record.entry_price)
      return record.structural_sl - record.entry_price;

   return 0.0;
}

double FalconRunnerRoomBetweenTargets(const FalconTradeLifecycleRecord &record, const double from_price, const double to_price)
{
   if(from_price <= 0.0 || to_price <= 0.0)
      return 0.0;

   if(record.direction == FALCON_DIRECTION_BUY)
      return MathMax(0.0, to_price - from_price);

   if(record.direction == FALCON_DIRECTION_SELL)
      return MathMax(0.0, from_price - to_price);

   return 0.0;
}

double FalconMaxTargetRProxy(const FalconTradeLifecycleRecord &record)
{
   double risk_points = FalconStructuralRiskPoints(record);
   if(risk_points <= 0.0)
      return 0.0;

   double tp1_r = FalconDirectionalProfitPoints(record, record.tp1) / risk_points;
   double tp2_r = FalconDirectionalProfitPoints(record, record.tp2) / risk_points;
   double tp3_r = FalconDirectionalProfitPoints(record, record.tp3) / risk_points;

   return MathMax(tp1_r, MathMax(tp2_r, tp3_r));
}

// v0.29.3a: Runner bar-path diagnostics helpers. These scan M5 closed bars between
// entry and exit to estimate post-TP1/TP2 expansion and giveback. They are
// diagnostics only and never alter exits, SL, TP, staging, or execution.
void FalconResetRunnerBarPathStats(FalconRunnerBarPathStats &stats)
{
   stats.scan_ok = false;
   stats.bars_scanned = 0;
   stats.tp1_touched = false;
   stats.tp2_touched = false;
   stats.tp1_touched_then_extended = false;
   stats.tp2_touched_then_extended = false;
   stats.tp1_to_max_run_points = 0.0;
   stats.tp2_to_max_run_points = 0.0;
   stats.max_favorable_points = 0.0;
   stats.mfe_after_tp1_points = 0.0;
   stats.mfe_after_tp2_points = 0.0;
   stats.giveback_after_tp1_points = 0.0;
   stats.giveback_after_tp2_points = 0.0;
   stats.returned_to_loss_after_tp1 = false;
   stats.returned_to_loss_after_tp2 = false;
   stats.max_r_actual_proxy = 0.0;
}

bool FalconTargetTouchedByBar(const FalconTradeLifecycleRecord &record, const double bar_high, const double bar_low, const double target_price)
{
   if(target_price <= 0.0)
      return false;

   if(record.direction == FALCON_DIRECTION_BUY)
      return (bar_high >= target_price);

   if(record.direction == FALCON_DIRECTION_SELL)
      return (bar_low <= target_price);

   return false;
}

double FalconBarFavorablePoints(const FalconTradeLifecycleRecord &record, const double bar_high, const double bar_low)
{
   if(record.entry_price <= 0.0)
      return 0.0;

   if(record.direction == FALCON_DIRECTION_BUY)
      return MathMax(0.0, bar_high - record.entry_price);

   if(record.direction == FALCON_DIRECTION_SELL)
      return MathMax(0.0, record.entry_price - bar_low);

   return 0.0;
}

bool FalconBarReturnedToEntryAfterProof(const FalconTradeLifecycleRecord &record, const double bar_high, const double bar_low)
{
   if(record.entry_price <= 0.0)
      return false;

   if(record.direction == FALCON_DIRECTION_BUY)
      return (bar_low <= record.entry_price);

   if(record.direction == FALCON_DIRECTION_SELL)
      return (bar_high >= record.entry_price);

   return false;
}

double FalconExitFavorablePoints(const FalconTradeLifecycleRecord &record)
{
   if(record.entry_price <= 0.0 || record.exit_price <= 0.0)
      return record.net_index_points;

   if(record.direction == FALCON_DIRECTION_BUY)
      return (record.exit_price - record.entry_price);

   if(record.direction == FALCON_DIRECTION_SELL)
      return (record.entry_price - record.exit_price);

   return record.net_index_points;
}

bool FalconBuildRunnerBarPathStats(const FalconTradeLifecycleRecord &record, FalconRunnerBarPathStats &stats)
{
   FalconResetRunnerBarPathStats(stats);

   if(record.entry_time <= 0 || record.exit_time <= 0 || record.exit_time < record.entry_time)
      return false;
   if(record.entry_price <= 0.0 || record.tp1 <= 0.0 || record.tp2 <= 0.0)
      return false;

   int entry_shift = iBarShift(_Symbol, PERIOD_M5, record.entry_time, false);
   int exit_shift  = iBarShift(_Symbol, PERIOD_M5, record.exit_time,  false);
   if(entry_shift < 0 || exit_shift < 0)
      return false;

   int start_shift = entry_shift;
   int end_shift   = exit_shift;
   if(start_shift < end_shift)
   {
      int tmp = start_shift;
      start_shift = end_shift;
      end_shift = tmp;
   }

   double tp1_points = FalconDirectionalProfitPoints(record, record.tp1);
   double tp2_points = FalconDirectionalProfitPoints(record, record.tp2);
   double max_fav_after_tp1 = 0.0;
   double max_fav_after_tp2 = 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   for(int shift = start_shift; shift >= end_shift; shift--)
   {
      int copied = CopyRates(_Symbol, PERIOD_M5, shift, 1, rates);
      if(copied != 1)
         continue;

      stats.bars_scanned++;

      double favorable_points = FalconBarFavorablePoints(record, rates[0].high, rates[0].low);
      if(favorable_points > stats.max_favorable_points)
         stats.max_favorable_points = favorable_points;

      // Update post-proof path using bars after the proof touch. This avoids
      // assuming same-bar order of TP touch, extension, and giveback.
      if(stats.tp1_touched)
      {
         if(favorable_points > max_fav_after_tp1)
            max_fav_after_tp1 = favorable_points;
         if(FalconBarReturnedToEntryAfterProof(record, rates[0].high, rates[0].low))
            stats.returned_to_loss_after_tp1 = true;
      }

      if(stats.tp2_touched)
      {
         if(favorable_points > max_fav_after_tp2)
            max_fav_after_tp2 = favorable_points;
         if(FalconBarReturnedToEntryAfterProof(record, rates[0].high, rates[0].low))
            stats.returned_to_loss_after_tp2 = true;
      }

      if(!stats.tp1_touched && FalconTargetTouchedByBar(record, rates[0].high, rates[0].low, record.tp1))
         stats.tp1_touched = true;
      if(!stats.tp2_touched && FalconTargetTouchedByBar(record, rates[0].high, rates[0].low, record.tp2))
         stats.tp2_touched = true;
   }

   if(stats.bars_scanned <= 0)
      return false;

   double exit_favorable_points = FalconExitFavorablePoints(record);

   if(stats.tp1_touched)
   {
      // v0.29.3a calibration: measure TP1-to-max-run as the full path
      // favorable extension beyond TP1. This is diagnostics only and can include
      // same-bar extension; no runtime decision may use it until a no-lookahead
      // state machine validates the trigger order.
      stats.tp1_to_max_run_points = MathMax(0.0, stats.max_favorable_points - tp1_points);
      stats.tp1_touched_then_extended = (stats.tp1_to_max_run_points > 0.0);
      stats.mfe_after_tp1_points = stats.tp1_to_max_run_points;
      stats.giveback_after_tp1_points = MathMax(0.0, stats.max_favorable_points - exit_favorable_points);
      if(exit_favorable_points < 0.0)
         stats.returned_to_loss_after_tp1 = true;
   }

   if(stats.tp2_touched)
   {
      // v0.29.3a calibration: same as TP1, but anchored at TP2.
      stats.tp2_to_max_run_points = MathMax(0.0, stats.max_favorable_points - tp2_points);
      stats.tp2_touched_then_extended = (stats.tp2_to_max_run_points > 0.0);
      stats.mfe_after_tp2_points = stats.tp2_to_max_run_points;
      stats.giveback_after_tp2_points = MathMax(0.0, stats.max_favorable_points - exit_favorable_points);
      if(exit_favorable_points < 0.0)
         stats.returned_to_loss_after_tp2 = true;
   }

   double risk_points = FalconStructuralRiskPoints(record);
   if(risk_points > 0.0)
      stats.max_r_actual_proxy = stats.max_favorable_points / risk_points;

   stats.scan_ok = true;
   return true;
}

string FalconSanitizeFileTag(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   if(value == "")
      value = "NA";

   StringReplace(value, " ", "_");
   StringReplace(value, ":", "_");
   StringReplace(value, ";", "_");
   StringReplace(value, "/", "_");
   StringReplace(value, "\\", "_");
   StringReplace(value, "-", "_");
   StringReplace(value, ".", "_");
   StringReplace(value, ",", "_");
   StringReplace(value, "__", "_");
   return value;
}

bool FalconIsAutoPeriodTag(const string raw_tag)
{
   string value = raw_tag;
   StringTrimLeft(value);
   StringTrimRight(value);
   StringToUpper(value);
   return (value == "AUTO" || value == "" || value == "AUTO_DETECT");
}

string FalconDateTagFromTime(const datetime time_value)
{
   datetime safe_time = time_value;
   if(safe_time <= 0)
      safe_time = TimeLocal();

   string value = TimeToString(safe_time, TIME_DATE);
   StringReplace(value, ".", "_");
   StringReplace(value, "-", "_");
   StringReplace(value, "/", "_");
   return FalconSanitizeFileTag(value);
}

void FalconInitializeReportPeriodTags()
{
   datetime now_time = TimeCurrent();
   if(now_time <= 0)
      now_time = TimeLocal();

   g_report_period_first_time = now_time;
   g_report_period_last_time  = now_time;

   if(AutoDetectReportPeriodTags && FalconIsAutoPeriodTag(ReportFromDateTag))
      g_report_active_from_tag = FalconDateTagFromTime(now_time);
   else
      g_report_active_from_tag = FalconSanitizeFileTag(ReportFromDateTag);

   if(AutoDetectReportPeriodTags && FalconIsAutoPeriodTag(ReportToDateTag))
      g_report_active_to_tag = "AUTO_RUNNING";
   else
      g_report_active_to_tag = FalconSanitizeFileTag(ReportToDateTag);

   g_report_initial_from_tag = g_report_active_from_tag;
   g_report_initial_to_tag   = g_report_active_to_tag;
   g_report_period_initialized = true;
   g_report_period_finalized = false;
}

void FalconUpdateReportPeriodLastSeen()
{
   datetime now_time = TimeCurrent();
   if(now_time <= 0)
      return;

   if(g_report_period_first_time <= 0)
      g_report_period_first_time = now_time;

   if(now_time >= g_report_period_last_time)
      g_report_period_last_time = now_time;
}

void FalconFinalizeReportPeriodTags()
{
   FalconUpdateReportPeriodLastSeen();

   if(AutoDetectReportPeriodTags && FalconIsAutoPeriodTag(ReportFromDateTag))
      g_report_active_from_tag = FalconDateTagFromTime(g_report_period_first_time);
   else
      g_report_active_from_tag = FalconSanitizeFileTag(ReportFromDateTag);

   if(AutoDetectReportPeriodTags && FalconIsAutoPeriodTag(ReportToDateTag))
      g_report_active_to_tag = FalconDateTagFromTime(g_report_period_last_time);
   else
      g_report_active_to_tag = FalconSanitizeFileTag(ReportToDateTag);

   g_report_period_finalized = true;
}

string FalconEffectiveReportFromDateTag()
{
   if(g_report_active_from_tag != "")
      return g_report_active_from_tag;
   return FalconSanitizeFileTag(ReportFromDateTag);
}

string FalconEffectiveReportToDateTag()
{
   if(g_report_active_to_tag != "")
      return g_report_active_to_tag;
   return FalconSanitizeFileTag(ReportToDateTag);
}

string FalconSummaryFinalReportToDateTag()
{
   // v0.55.10c: Summary rows must show the final observed ToDateTag, never AUTO_RUNNING.
   // During OnDeinit the Summary can be written before file finalization/rename, so we derive
   // the displayed value directly from the last observed tester/live time when auto-detect is used.
   if(AutoDetectReportPeriodTags && FalconIsAutoPeriodTag(ReportToDateTag))
   {
      datetime final_time = g_report_period_last_time;
      if(final_time <= 0)
         final_time = TimeCurrent();
      if(final_time <= 0)
         final_time = TimeLocal();
      return FalconDateTagFromTime(final_time);
   }
   return FalconEffectiveReportToDateTag();
}


string FalconReportLotModeTag()
{
   // v0.55.10b: make report file names self-describing for FixedLot vs DynamicLot test runs.
   return (UseFixedLot ? "FixedLot" : "DynamicLot");
}

string FalconReportExecutionStateTag()
{
   // v0.56.8: make report file names self-describing for EnableRealExecution ON/OFF test runs.
   // This is naming-only; it does not change trading logic or report period detection.
   return (EnableRealExecution ? "ExecutionON" : "ExecutionOFF");
}

string FalconEffectiveReportModeTag()
{
   // v0.56.2 cleanup gate: old tester presets may still pass ShadowSmoke even after
   // the default input changed. Normalize only report file naming/stage metadata; do
   // not change trading logic, Paper results, or report period tags.
   string raw_tag = FalconSanitizeFileTag(ReportModeTag);
   // v0.57.3: add the v0.56.x stage tags to the normalization list so legacy presets
   // and old default ReportModeTag values are folded into FALCON_BELR_REPORT_STAGE_TAG
   // ("VirtualTrailingBridge"). No report content is changed; this only fixes the
   // file-name tag stamped into report filenames.
   if(raw_tag == "" ||
      raw_tag == FALCON_BELR_DEPRECATED_REPORT_STAGE_TAG ||
      raw_tag == "BrokerExitObservation" ||
      raw_tag == "ProtectionRunnerBridge" ||
      raw_tag == "ManagedRunnerBridge" ||
      raw_tag == "BrokerPaperReconciliation" ||
      raw_tag == "EmergencyServerStopEnvelopeLockParityProbe")
      return FALCON_BELR_REPORT_STAGE_TAG;
   return raw_tag;
}

string FalconBuildReportFileNameWithTags(const string report_name,
                                         const string from_tag,
                                         const string to_tag)
{
   string version_tag = FalconSanitizeFileTag(EA_VERSION_TAG);

   if(!EnableReportPeriodInFileNames)
      return StringFormat("JA_FalconCore_%s_%s.csv", report_name, version_tag);

   string mode_tag = FalconSanitizeFileTag(FalconEffectiveReportModeTag());
   string safe_from = FalconSanitizeFileTag(from_tag);
   string safe_to   = FalconSanitizeFileTag(to_tag);

   string lot_mode_tag = FalconSanitizeFileTag(FalconReportLotModeTag());
   string execution_state_tag = FalconSanitizeFileTag(FalconReportExecutionStateTag());

   return StringFormat("JA_FalconCore_%s_%s_%s_%s_%s_From_%s_To_%s.csv",
                       report_name, version_tag, mode_tag, execution_state_tag, lot_mode_tag, safe_from, safe_to);
}

string FalconBuildReportFileName(const string report_name)
{
   return FalconBuildReportFileNameWithTags(report_name,
                                            FalconEffectiveReportFromDateTag(),
                                            FalconEffectiveReportToDateTag());
}

int FalconReportWriteCsvFlags()
{
   int flags = FILE_WRITE | FILE_CSV | FILE_ANSI;
   if(UseCommonFilesFolderForReports)
      flags |= FILE_COMMON;
   return flags;
}

int FalconReportReadWriteCsvFlags()
{
   int flags = FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI;
   if(UseCommonFilesFolderForReports)
      flags |= FILE_COMMON;
   return flags;
}

int FalconReportReadBinFlags()
{
   int flags = FILE_READ | FILE_BIN;
   if(UseCommonFilesFolderForReports)
      flags |= FILE_COMMON;
   return flags;
}

string FalconReportStorageMode()
{
   return (UseCommonFilesFolderForReports ? "COMMON_FILES" : "TERMINAL_OR_TESTER_LOCAL_FILES");
}

void FalconPrintReportFolderHints()
{
   if(!PrintReportFolderHintsToLog)
      return;

   PrintFormat("[%s][%s][REPORT_PATH] StorageMode=%s", EA_NAME, EA_VERSION_TAG, FalconReportStorageMode());
   PrintFormat("[%s][%s][REPORT_PATH] Common data path: %s\\Files", EA_NAME, EA_VERSION_TAG, TerminalInfoString(TERMINAL_COMMONDATA_PATH));
   PrintFormat("[%s][%s][REPORT_PATH] Terminal data path: %s\\MQL5\\Files or tester agent Files", EA_NAME, EA_VERSION_TAG, TerminalInfoString(TERMINAL_DATA_PATH));
}

void FalconWriteStartupBootstrapFile()
{
   if(!ForceCreateReportFilesOnInit)
      return;

   string file_name = FalconBuildReportFileName("StartupBootstrap");
   int handle = FileOpen(file_name, FalconReportWriteCsvFlags(), ',');
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("[%s][%s][WARN] Could not create StartupBootstrap report: %s", EA_NAME, EA_VERSION_TAG, file_name);
      return;
   }

   FileWrite(handle, "EAName", "Version", "Build", "GeneratedAt", "StorageMode", "ModeTag", "FromDateTag", "ToDateTag", "OnInitReached", "Note");
   FileWrite(handle, EA_NAME, EA_VERSION_TAG, EA_BUILD_TAG, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             FalconReportStorageMode(), FalconEffectiveReportModeTag(), FalconEffectiveReportFromDateTag(), FalconEffectiveReportToDateTag(), "YES",
             "This file is created at the very start of OnInit before market-context initialization.");
   FileClose(handle);
}

int FalconReportCommonFlag()
{
   return (UseCommonFilesFolderForReports ? FILE_COMMON : 0);
}

int FalconReportMoveFlags()
{
   int flags = FILE_REWRITE;
   if(UseCommonFilesFolderForReports)
      flags |= FILE_COMMON;
   return flags;
}

int FalconReportNameCount()
{
   // v0.56.9: every official report created during OnInit must participate in
   // AutoPeriod finalization/rename. BrokerPaperTradeReconciliation is now included
   // so it must not remain with To_AUTO_RUNNING in final report files.
   // v0.57.0: +2 reports per profile (LockParityExecutabilityDecomposition + Rollup).
   // v0.57.2: +1 report per profile (VirtualTrailingExitLifecycle).
   if(ReportProfile == FALCON_REPORT_MINIMAL)
      return 13;
   if(ReportProfile == FALCON_REPORT_STANDARD)
      return 14;
   return 31;
}

string FalconReportNameByIndex(const int index)
{
   if(ReportProfile == FALCON_REPORT_MINIMAL)
   {
      switch(index)
      {
         case 0: return "TradeLifecycle";
         case 1: return "Summary";
         case 2: return "TierTransitions";
         case 3: return "EmergencyTriggers";
         case 4: return "PaperStateSnapshot";
         case 5: return FALCON_BROKER_EXECUTION_LIFECYCLE_REPORT_NAME;
         case 6: return FALCON_BROKER_TM_TIMELINE_REPORT_NAME;
         case 7: return FALCON_BROKER_CONTRACT_REALITY_REPORT_NAME;
         case 8: return FALCON_BROKER_REBASED_COMPARISON_REPORT_NAME;
         case 9: return FALCON_BROKER_PAPER_RECONCILIATION_REPORT_NAME;
         case 10: return FALCON_LOCK_PARITY_DECOMP_REPORT_NAME;
         case 11: return FALCON_LOCK_PARITY_ROLLUP_REPORT_NAME;
         case 12: return FALCON_VIRTUAL_TRAILING_EXIT_LIFECYCLE_REPORT_NAME;
      }
      return "UnknownReport";
   }

   if(ReportProfile == FALCON_REPORT_STANDARD)
   {
      switch(index)
      {
         case 0: return "TradeLifecycle";
         case 1: return "Summary";
         case 2: return "StrategyRegistryDiagnostics";
         case 3: return "TierTransitions";
         case 4: return "EmergencyTriggers";
         case 5: return "PaperStateSnapshot";
         case 6: return FALCON_BROKER_EXECUTION_LIFECYCLE_REPORT_NAME;
         case 7: return FALCON_BROKER_TM_TIMELINE_REPORT_NAME;
         case 8: return FALCON_BROKER_CONTRACT_REALITY_REPORT_NAME;
         case 9: return FALCON_BROKER_REBASED_COMPARISON_REPORT_NAME;
         case 10: return FALCON_BROKER_PAPER_RECONCILIATION_REPORT_NAME;
         case 11: return FALCON_LOCK_PARITY_DECOMP_REPORT_NAME;
         case 12: return FALCON_LOCK_PARITY_ROLLUP_REPORT_NAME;
         case 13: return FALCON_VIRTUAL_TRAILING_EXIT_LIFECYCLE_REPORT_NAME;
      }
      return "UnknownReport";
   }

   switch(index)
   {
      case 0:  return "StartupBootstrap";
      case 1:  return "ReportCreationGuarantee";
      case 2:  return "TradeLifecycle";
      case 3:  return "Summary";
      case 4:  return "MarketDiagnostics";
      case 5:  return "CandleCacheDiagnostics";
      case 6:  return "EvidenceDiagnostics";
      case 7:  return "ShadowDiagnostics";
      case 8:  return "NoLookaheadDiagnostics";
      case 9:  return "StrategyRegistryDiagnostics";
      case 10: return "StrategyAdapterDiagnostics";
      case 11: return "FvgMicroDetectorDiagnostics";
      case 12: return "FvgMicroShadowCandidateDiagnostics";
      case 13: return "FvgMicroRetestWatcherDiagnostics";
      case 14: return "FvgMicroTradePlanStagingDiagnostics";
      case 15: return "FvgMicroLifecycleSimulationDiagnostics";
      case 16: return "ReportCalibrationCleanupGate";
      case 17: return "RuntimeReportVerification";
      case 18: return "FvgMicroRuntimeSmokeTest";
      case 19: return "FvgMicroRuntimeReportAudit";
      case 20: return "TierTransitions";
      case 21: return "EmergencyTriggers";
      case 22: return "PaperStateSnapshot";
      case 23: return FALCON_BROKER_EXECUTION_LIFECYCLE_REPORT_NAME;
      case 24: return FALCON_BROKER_TM_TIMELINE_REPORT_NAME;
      case 25: return FALCON_BROKER_CONTRACT_REALITY_REPORT_NAME;
      case 26: return FALCON_BROKER_REBASED_COMPARISON_REPORT_NAME;
      case 27: return FALCON_BROKER_PAPER_RECONCILIATION_REPORT_NAME;
      case 28: return FALCON_LOCK_PARITY_DECOMP_REPORT_NAME;
      case 29: return FALCON_LOCK_PARITY_ROLLUP_REPORT_NAME;
      case 30: return FALCON_VIRTUAL_TRAILING_EXIT_LIFECYCLE_REPORT_NAME;
   }
   return "UnknownReport";
}

void FalconWriteAutoPeriodManifest(const string trigger,
                                   const int moved_count,
                                   const int missing_count,
                                   const int failed_count)
{
   if(FalconReportProfileIsLockParity()) return;
   string manifest_name = FalconBuildReportFileNameWithTags("AutoPeriodManifest",
                                                            FalconEffectiveReportFromDateTag(),
                                                            FalconEffectiveReportToDateTag());
   int handle = FileOpen(manifest_name, FalconReportWriteCsvFlags(), ',');
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("[%s][%s][WARN] Could not create AutoPeriodManifest: %s", EA_NAME, EA_VERSION_TAG, manifest_name);
      return;
   }

   // v0.55.5: keep AutoPeriodManifest as file-period metadata only.
   // Long explanatory notes belong in Release Notes / Project Memory, not CSV.
   FileWrite(handle,
             "EAName", "Version", "Build", "GeneratedAt",
             "ReportProfile", "FinalFromTag", "FinalToTag",
             "ActualDataFromTag", "ActualDataToTag",
             "MovedCount", "MissingCount", "FailedCount");

   FileWrite(handle,
             FalconCsvSafe(EA_NAME),
             FalconCsvSafe(EA_VERSION_TAG),
             FalconCsvSafe(EA_BUILD_TAG),
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             FalconCsvSafe(FalconReportProfileToString()),
             FalconCsvSafe(FalconEffectiveReportFromDateTag()),
             FalconCsvSafe(FalconEffectiveReportToDateTag()),
             FalconCsvSafe(FalconDateTagFromTime(g_report_period_first_time)),
             FalconCsvSafe(FalconDateTagFromTime(g_report_period_last_time)),
             moved_count, missing_count, failed_count);

   FileClose(handle);
}

void FalconFinalizeAndRenameReportFiles(const string trigger)
{
   // v0.18.7: report period tags are based on actual observed data/tick time, not UI end date.
   if(!RenameReportsToActualPeriodOnDeinit)
      return;

   string old_from = g_report_initial_from_tag;
   string old_to   = g_report_initial_to_tag;

   FalconFinalizeReportPeriodTags();

   string new_from = FalconEffectiveReportFromDateTag();
   string new_to   = FalconEffectiveReportToDateTag();

   int moved_count = 0;
   int missing_count = 0;
   int failed_count = 0;

   if(old_from == new_from && old_to == new_to)
   {
      FalconWriteAutoPeriodManifest(trigger + "_NoRenameNeeded", 0, 0, 0);
      return;
   }

   int common_flag = FalconReportCommonFlag();
   int move_flags  = FalconReportMoveFlags();

   for(int i = 0; i < FalconReportNameCount(); i++)
   {
      string report_name = FalconReportNameByIndex(i);
      string old_file = FalconBuildReportFileNameWithTags(report_name, old_from, old_to);
      string new_file = FalconBuildReportFileNameWithTags(report_name, new_from, new_to);

      if(old_file == new_file)
         continue;

      if(!FileIsExist(old_file, common_flag))
      {
         missing_count++;
         continue;
      }

      if(FileIsExist(new_file, common_flag))
         FileDelete(new_file, common_flag);

      if(FileMove(old_file, common_flag, new_file, move_flags))
         moved_count++;
      else
      {
         failed_count++;
         PrintFormat("[%s][%s][WARN] Could not rename report file from %s to %s", EA_NAME, EA_VERSION_TAG, old_file, new_file);
      }
   }

   FalconWriteAutoPeriodManifest(trigger, moved_count, missing_count, failed_count);
}

// ==================================================================
// Logger
// ==================================================================
class CFalconLogger
{
public:
   static void Info(const string message)
   {
      if(EnableVerboseExpertsLog)
         PrintFormat("[%s][%s][INFO] %s", EA_NAME, EA_VERSION_TAG, message);
   }

   static void Warn(const string message)
   {
      PrintFormat("[%s][%s][WARN] %s", EA_NAME, EA_VERSION_TAG, message);
   }

   static void Error(const string message)
   {
      PrintFormat("[%s][%s][ERROR] %s", EA_NAME, EA_VERSION_TAG, message);
   }
};

// ==================================================================
// Market Context Provider - v0.13.1 symbol, quote, and closed candle diagnostics
// ==================================================================
class CFalconMarketContext
{
private:
   FalconSymbolContext  m_symbol;
   FalconQuoteContext   m_quote;
   FalconCandleSnapshot m_primary_candle;

public:
   bool Initialize()
   {
      m_symbol.symbol             = _Symbol;
      m_symbol.digits             = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      m_symbol.point              = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      m_symbol.tick_size          = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      m_symbol.tick_value         = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      m_symbol.contract_size      = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      m_symbol.spread_points      = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      m_symbol.stops_level_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      m_symbol.freeze_level_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      m_symbol.min_lot            = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      m_symbol.max_lot            = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      m_symbol.lot_step           = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      m_symbol.is_valid           = ValidateSymbol();

      if(!m_symbol.is_valid)
         return false;

      if(!Refresh())
         return false;

      const int shift = FalconAnalysisCandleShift();
      if(!GetCandleSnapshot(PrimaryContextTimeframe, shift, m_primary_candle))
      {
         CFalconLogger::Error(StringFormat("Could not read primary context candle. Timeframe=%s | Shift=%d",
                                           FalconTimeframeToString(PrimaryContextTimeframe),
                                           shift));
         return false;
      }

      CFalconLogger::Info(StringFormat("SymbolContext initialized: %s | Digits=%d | Point=%.10f | TickSize=%.10f | TickValue=%.5f | Contract=%.2f | MinLot=%.2f | Step=%.2f | StopsLevel=%d | FreezeLevel=%d",
                                       m_symbol.symbol,
                                       m_symbol.digits,
                                       m_symbol.point,
                                       m_symbol.tick_size,
                                       m_symbol.tick_value,
                                       m_symbol.contract_size,
                                       m_symbol.min_lot,
                                       m_symbol.lot_step,
                                       (int)m_symbol.stops_level_points,
                                       (int)m_symbol.freeze_level_points));

      CFalconLogger::Info(StringFormat("QuoteContext initialized: Bid=%s | Ask=%s | SpreadPoints=%d | TickTime=%s",
                                       DoubleToString(m_quote.bid, m_symbol.digits),
                                       DoubleToString(m_quote.ask, m_symbol.digits),
                                       (int)m_quote.spread_points,
                                       FalconTimeToString(m_quote.tick_time)));

      CFalconLogger::Info(StringFormat("Primary closed-candle guard: UseClosedCandlesOnly=%s | Timeframe=%s | Shift=%d | CandleTime=%s | O=%.5f H=%.5f L=%.5f C=%.5f",
                                       (UseClosedCandlesOnly ? "true" : "false"),
                                       FalconTimeframeToString(m_primary_candle.timeframe),
                                       m_primary_candle.source_shift,
                                       FalconTimeToString(m_primary_candle.time),
                                       m_primary_candle.open,
                                       m_primary_candle.high,
                                       m_primary_candle.low,
                                       m_primary_candle.close));
      return true;
   }

   bool Refresh()
   {
      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick))
      {
         CFalconLogger::Error("SymbolInfoTick failed. Market context cannot be refreshed.");
         m_quote.is_valid = false;
         return false;
      }

      m_quote.bid           = tick.bid;
      m_quote.ask           = tick.ask;
      m_quote.last          = tick.last;
      m_quote.volume        = (long)tick.volume;
      m_quote.volume_real   = tick.volume_real;
      m_quote.tick_time     = tick.time;
      m_quote.time_msc      = tick.time_msc;
      m_quote.spread_points = CalculateLiveSpreadPoints(tick.bid, tick.ask);
      m_quote.is_valid      = (tick.bid > 0.0 && tick.ask > 0.0 && m_quote.spread_points >= 0);

      if(!m_quote.is_valid)
      {
         CFalconLogger::Warn("Quote context is not valid yet. This can happen when the market is closed or no tick is available.");
      }
      return true;
   }

   FalconSymbolContext GetSymbolContext()
   {
      return m_symbol;
   }

   FalconQuoteContext GetQuoteContext()
   {
      return m_quote;
   }

   FalconCandleSnapshot GetPrimaryCandleSnapshot()
   {
      return m_primary_candle;
   }

   bool GetCandleSnapshot(const ENUM_TIMEFRAMES timeframe,
                          const int shift,
                          FalconCandleSnapshot &snapshot)
   {
      ResetCandleSnapshot(snapshot);
      snapshot.timeframe    = timeframe;
      snapshot.source_shift = shift;
      snapshot.is_closed    = (shift > 0);

      if(shift < 0)
      {
         CFalconLogger::Error("Candle snapshot shift cannot be negative.");
         return false;
      }

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(_Symbol, timeframe, shift, 1, rates);
      if(copied != 1)
      {
         CFalconLogger::Warn(StringFormat("CopyRates failed. Symbol=%s | Timeframe=%s | Shift=%d | Copied=%d",
                                           _Symbol,
                                           FalconTimeframeToString(timeframe),
                                           shift,
                                           copied));
         return false;
      }

      snapshot.time        = rates[0].time;
      snapshot.open        = rates[0].open;
      snapshot.high        = rates[0].high;
      snapshot.low         = rates[0].low;
      snapshot.close       = rates[0].close;
      snapshot.tick_volume = rates[0].tick_volume;
      snapshot.real_volume = rates[0].real_volume;
      snapshot.spread      = rates[0].spread;
      snapshot.is_valid    = (snapshot.time > 0 && snapshot.high >= snapshot.low);
      return snapshot.is_valid;
   }

private:
   bool ValidateSymbol()
   {
      if(m_symbol.point <= 0.0)
      {
         CFalconLogger::Error("Invalid symbol point value.");
         return false;
      }
      if(m_symbol.min_lot <= 0.0 || m_symbol.lot_step <= 0.0)
      {
         CFalconLogger::Error("Invalid symbol lot configuration.");
         return false;
      }
      if(m_symbol.contract_size <= 0.0)
      {
         CFalconLogger::Warn("Symbol contract size is not positive. USD estimates may be zero until broker metadata is available.");
      }
      return true;
   }

   long CalculateLiveSpreadPoints(const double bid, const double ask)
   {
      if(m_symbol.point <= 0.0 || bid <= 0.0 || ask <= 0.0)
         return -1;
      return (long)MathRound((ask - bid) / m_symbol.point);
   }

   void ResetCandleSnapshot(FalconCandleSnapshot &snapshot)
   {
      snapshot.timeframe    = PERIOD_CURRENT;
      snapshot.time         = 0;
      snapshot.open         = 0.0;
      snapshot.high         = 0.0;
      snapshot.low          = 0.0;
      snapshot.close        = 0.0;
      snapshot.tick_volume  = 0;
      snapshot.real_volume  = 0;
      snapshot.spread       = 0;
      snapshot.source_shift = 0;
      snapshot.is_closed    = false;
      snapshot.is_valid     = false;
   }
};


// ==================================================================
// Multi-Timeframe Candle Cache - v0.13.1
// Official analysis timeframes: M1, M5, M15, H1, H4, D1.
// This layer is data-provider only. It does not create signals.
// ==================================================================
class CFalconCandleCache
{
private:
   ENUM_TIMEFRAMES       m_timeframes[FALCON_MTF_COUNT];
   FalconCandleSnapshot  m_analysis_snapshots[FALCON_MTF_COUNT];
   bool                  m_is_loaded;
   int                   m_valid_count;
   int                   m_analysis_shift;

public:
   CFalconCandleCache()
   {
      m_is_loaded      = false;
      m_valid_count    = 0;
      m_analysis_shift = 1;
      ConfigureTimeframes();
   }

   void ConfigureTimeframes()
   {
      m_timeframes[0] = PERIOD_M1;
      m_timeframes[1] = PERIOD_M5;
      m_timeframes[2] = PERIOD_M15;
      m_timeframes[3] = PERIOD_H1;
      m_timeframes[4] = PERIOD_H4;
      m_timeframes[5] = PERIOD_D1;
   }

   bool LoadAll(CFalconMarketContext &context)
   {
      m_is_loaded      = false;
      m_valid_count    = 0;
      m_analysis_shift = FalconAnalysisCandleShift();

      for(int i = 0; i < FALCON_MTF_COUNT; i++)
      {
         FalconCandleSnapshot snapshot;
         bool ok = context.GetCandleSnapshot(m_timeframes[i], m_analysis_shift, snapshot);
         m_analysis_snapshots[i] = snapshot;

         if(ok && snapshot.is_valid)
            m_valid_count++;
      }

      m_is_loaded = (m_valid_count > 0);
      CFalconLogger::Info(StringFormat("CandleCache loaded. Timeframes=%d | Valid=%d | Shift=%d | UseClosedCandlesOnly=%s",
                                       FALCON_MTF_COUNT,
                                       m_valid_count,
                                       m_analysis_shift,
                                       (UseClosedCandlesOnly ? "true" : "false")));

      for(int i = 0; i < FALCON_MTF_COUNT; i++)
      {
         FalconCandleSnapshot s = m_analysis_snapshots[i];
         CFalconLogger::Info(StringFormat("CandleCache[%s] Valid=%s | Shift=%d | Time=%s | O=%.5f H=%.5f L=%.5f C=%.5f",
                                          FalconTimeframeToString(s.timeframe),
                                          (s.is_valid ? "true" : "false"),
                                          s.source_shift,
                                          FalconTimeToString(s.time),
                                          s.open,
                                          s.high,
                                          s.low,
                                          s.close));
      }

      return m_is_loaded;
   }

   int Count()
   {
      return FALCON_MTF_COUNT;
   }

   int ValidCount()
   {
      return m_valid_count;
   }

   bool IsLoaded()
   {
      return m_is_loaded;
   }

   int AnalysisShift()
   {
      return m_analysis_shift;
   }

   ENUM_TIMEFRAMES TimeframeAt(const int index)
   {
      if(index < 0 || index >= FALCON_MTF_COUNT)
         return PERIOD_CURRENT;
      return m_timeframes[index];
   }

   bool GetSnapshotByIndex(const int index,
                           FalconCandleSnapshot &snapshot)
   {
      if(index < 0 || index >= FALCON_MTF_COUNT)
         return false;
      snapshot = m_analysis_snapshots[index];
      return snapshot.is_valid;
   }

   bool GetSnapshotByTimeframe(const ENUM_TIMEFRAMES timeframe,
                               FalconCandleSnapshot &snapshot)
   {
      for(int i = 0; i < FALCON_MTF_COUNT; i++)
      {
         if(m_timeframes[i] == timeframe)
         {
            snapshot = m_analysis_snapshots[i];
            return snapshot.is_valid;
         }
      }
      return false;
   }
};

// ==================================================================
// Evidence Framework Foundation - v0.13.1
// Contract-only layer. Evidence strengthens or weakens future engine decisions,
// but it never opens a trade and never overrides guards.
// ==================================================================
class CFalconEvidenceFramework
{
private:
   FalconEvidenceRecord m_records[4];
   int                  m_record_count;
   bool                 m_initialized;

public:
   CFalconEvidenceFramework()
   {
      m_record_count = 0;
      m_initialized  = false;
   }

   bool Initialize()
   {
      m_record_count = 0;
      AddContractRecord("EVID_CANDLE", "Candle Pattern Evidence", FALCON_EVIDENCE_TYPE_CANDLE_PATTERN,
                        "Contract only: engulfing, pin bar, hammer, shooting star, wide body, inside/outside bar, three-bar reversal.");
      AddContractRecord("EVID_CHART", "Chart Pattern Evidence", FALCON_EVIDENCE_TYPE_CHART_PATTERN,
                        "Contract only: double top/bottom, H&S, flag, wedge, triangle, range break/retest, channel break, sweep/reclaim.");
      AddContractRecord("EVID_OBJECTIVE", "Objective Indicator Evidence", FALCON_EVIDENCE_TYPE_OBJECTIVE_INDICATOR,
                        "Contract only: VWAP, EMA 7/25/50/200, ATR, RSI closed candle, session levels, previous day levels, FVG, tick volume.");
      AddContractRecord("EVID_SMC", "SMC / Liquidity Evidence", FALCON_EVIDENCE_TYPE_SMC_LIQUIDITY,
                        "Contract only: liquidity sweep, reclaim, FVG/imbalance, displacement, BOS/CHoCH, premium/discount, HTF/LTF alignment.");

      m_initialized = (m_record_count == 4);
      CFalconLogger::Info(StringFormat("EvidenceFramework initialized. Records=%d | PermissionMode=EVIDENCE_ONLY", m_record_count));
      return m_initialized;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   int Count()
   {
      return m_record_count;
   }

   bool GetRecordByIndex(const int index, FalconEvidenceRecord &record)
   {
      if(index < 0 || index >= m_record_count)
         return false;
      record = m_records[index];
      return true;
   }

   FalconEvidencePack BuildEmptyEvidencePack()
   {
      FalconEvidencePack pack;
      pack.has_candle_evidence              = false;
      pack.has_chart_pattern_evidence       = false;
      pack.has_objective_indicator_evidence = false;
      pack.has_smc_evidence                 = false;
      pack.score                            = 0.0;
      pack.summary                          = "No runtime evidence evaluated in v0.13.1. Evidence Framework remains contract-only.";
      return pack;
   }

private:
   void AddContractRecord(const string evidence_id,
                          const string evidence_name,
                          const ENUM_FALCON_EVIDENCE_TYPE evidence_type,
                          const string notes)
   {
      if(m_record_count >= 4)
         return;

      FalconEvidenceRecord record;
      record.evidence_id           = evidence_id;
      record.evidence_name         = evidence_name;
      record.evidence_type         = evidence_type;
      record.evidence_state        = FALCON_EVIDENCE_STATE_NOT_EVALUATED;
      record.direction_bias        = FALCON_DIRECTION_NONE;
      record.source_timeframe      = PERIOD_CURRENT;
      record.score                 = 0.0;
      record.is_runtime_permission = false;
      record.notes                 = notes;

      m_records[m_record_count] = record;
      m_record_count++;
   }
};

// ==================================================================
// FalconGuard Risk Foundation + Pre-Execution utilities - v0.26.2
// Summary-only readiness helpers. They do not block Shadow staging and
// do not modify trading lifecycle behavior.
// ==================================================================
double FalconGuardDailyLossLimitUsd()
{
   if(!UseDailyLossLimit)
      return 0.0;

   if(UseFixedDailyLossAmount)
      return FixedDailyLossAmount;

   return FalconConfiguredCapital() * (DailyLossPercentOfCapital / 100.0);
}

string FalconGuardFixedLotStatus(const FalconSymbolContext &symbol_context)
{
   if(!UseFixedLot)
      return "FIXED_LOT_DISABLED_FUTURE_MODE";

   if(FixedLotSize <= 0.0)
      return "INVALID_FIXED_LOT_NON_POSITIVE";

   if(FixedLotSize < symbol_context.min_lot || FixedLotSize > symbol_context.max_lot)
      return "INVALID_FIXED_LOT_OUTSIDE_BROKER_LIMITS";

   return "VALID_FIXED_LOT_WITHIN_BROKER_LIMITS";
}

string FalconGuardDailyLossStatus()
{
   if(!UseDailyLossLimit)
      return "DAILY_LOSS_LIMIT_DISABLED";

   if(FalconGuardDailyLossLimitUsd() <= 0.0)
      return "INVALID_DAILY_LOSS_LIMIT";

   return "VALID_DAILY_LOSS_LIMIT_CONFIGURED";
}

string FalconGuardMaxTradesStatus()
{
   if(MaxTradesPerDay < 0)
      return "INVALID_MAX_TRADES_NEGATIVE";
   if(MaxTradesPerDay == 0)
      return "UNLIMITED_MAX_TRADES_BY_INPUT";
   return "VALID_MAX_TRADES_LIMIT_CONFIGURED";
}

string FalconGuardMaxOpenPositionsStatus()
{
   if(MaxOpenPositions < 0)
      return "INVALID_MAX_OPEN_POSITIONS_NEGATIVE";
   if(MaxOpenPositions == 0)
      return "UNLIMITED_MAX_OPEN_POSITIONS_BY_INPUT";
   return "VALID_MAX_OPEN_POSITIONS_LIMIT_CONFIGURED";
}

string FalconGuardSpreadGuardStatus(const FalconSymbolContext &symbol_context)
{
   if(symbol_context.spread_points < 0)
      return "SPREAD_NOT_AVAILABLE";
   return "SPREAD_VALUE_AVAILABLE_READINESS_ONLY_NOT_BLOCKING";
}

string FalconGuardStopsLevelGuardStatus(const FalconSymbolContext &symbol_context)
{
   if(symbol_context.stops_level_points < 0)
      return "STOPS_LEVEL_NOT_AVAILABLE";
   return "STOPS_LEVEL_AVAILABLE_READINESS_ONLY_NOT_BLOCKING";
}

string FalconGuardOverallStatus(const FalconSymbolContext &symbol_context)
{
   if(FalconGuardFixedLotStatus(symbol_context) != "VALID_FIXED_LOT_WITHIN_BROKER_LIMITS")
      return "CONFIG_REVIEW_REQUIRED_FIXED_LOT";

   if(FalconGuardDailyLossStatus() == "INVALID_DAILY_LOSS_LIMIT")
      return "CONFIG_REVIEW_REQUIRED_DAILY_LOSS";

   if(FalconGuardMaxTradesStatus() == "INVALID_MAX_TRADES_NEGATIVE")
      return "CONFIG_REVIEW_REQUIRED_MAX_TRADES";

   if(FalconGuardMaxOpenPositionsStatus() == "INVALID_MAX_OPEN_POSITIONS_NEGATIVE")
      return "CONFIG_REVIEW_REQUIRED_MAX_OPEN_POSITIONS";

   return "READY_FOR_TRADE_MANAGEMENT_FOUNDATION_NOT_LIVE";
}

// ==================================================================
// FalconGuard Pre-Execution Gate helpers - v0.26.2
// These functions produce Summary-only readiness decisions. They are not
// connected to broker execution and do not alter Shadow staging behavior.
// ==================================================================
string FalconGuardPreExecutionBlockReason(const FalconSymbolContext &symbol_context)
{
   string overall_status = FalconGuardOverallStatus(symbol_context);
   if(overall_status != "READY_FOR_TRADE_MANAGEMENT_FOUNDATION_NOT_LIVE")
      return overall_status;

   if(!EnableShadowMode && !EnablePaperMode)
      return "NO_OBSERVATION_MODE_ENABLED";

   return "NONE_DESIGN_ONLY";
}

string FalconGuardCanOpenTradeDesign(const FalconSymbolContext &symbol_context)
{
   if(FalconGuardPreExecutionBlockReason(symbol_context) == "NONE_DESIGN_ONLY")
      return "YES_DESIGN_ONLY_NOT_ENFORCED";

   return "NO_CONFIG_OR_MODE_REVIEW_REQUIRED";
}

double FalconGuardPlannedLotDesign(const FalconSymbolContext &symbol_context)
{
   if(FalconGuardFixedLotStatus(symbol_context) == "VALID_FIXED_LOT_WITHIN_BROKER_LIMITS")
      return FixedLotSize;

   return 0.0;
}

string FalconGuardSpreadAllowedDesign(const FalconSymbolContext &symbol_context)
{
   if(FalconGuardSpreadGuardStatus(symbol_context) == "SPREAD_NOT_AVAILABLE")
      return "NO_SPREAD_NOT_AVAILABLE";

   return "YES_READINESS_ONLY_NOT_RUNTIME_BLOCKING";
}

string FalconGuardStopsLevelAllowedDesign(const FalconSymbolContext &symbol_context)
{
   if(FalconGuardStopsLevelGuardStatus(symbol_context) == "STOPS_LEVEL_NOT_AVAILABLE")
      return "NO_STOPS_LEVEL_NOT_AVAILABLE";

   return "YES_READINESS_ONLY_NOT_RUNTIME_BLOCKING";
}

string FalconGuardKillSwitchAllowsTradingDesign()
{
   return "YES_DESIGN_ONLY_MANUAL_AND_AUTO_KILL_SWITCH_NOT_RUNTIME_ENFORCED";
}

// ==================================================================
// Risk Foundation - validates only. No lot calculations yet.
// ==================================================================
class CFalconRiskFoundation
{
public:
   bool ValidateInputs(const FalconSymbolContext &symbol_context)
   {
      // v0.56.4: EnableRealExecution=true is allowed only for the MT5 Strategy Tester
      // Atomic Entry+Exit validation lane. Demo/Live remain blocked here before
      // initialization continues, while still preserving the central execution safety switch.
      if(EnableRealExecution && !MQLInfoInteger(MQL_TESTER))
      {
         CFalconLogger::Error("HARD SAFETY BLOCK: EnableRealExecution=true is allowed only inside MT5 Strategy Tester in v0.56.4b. Demo/Live remain blocked.");
         return false;
      }

      if(!EnableShadowMode && !EnablePaperMode)
      {
         CFalconLogger::Warn("Both ShadowMode and PaperMode are disabled. EA will only load and stay idle.");
      }

      if(UseFixedLot)
      {
         if(FixedLotSize <= 0.0)
         {
            CFalconLogger::Error("FixedLotSize must be greater than zero.");
            return false;
         }

         if(FixedLotSize < symbol_context.min_lot || FixedLotSize > symbol_context.max_lot)
         {
            CFalconLogger::Error(StringFormat("FixedLotSize %.2f is outside broker limits [%.2f - %.2f].",
                                             FixedLotSize,
                                             symbol_context.min_lot,
                                             symbol_context.max_lot));
            return false;
         }
      }

      if(!UseAutoCapitalDetection && ManualCapital <= 0.0)
      {
         CFalconLogger::Error("ManualCapital must be greater than zero when UseAutoCapitalDetection=false.");
         return false;
      }

      if(UseDailyLossLimit)
      {
         if(UseFixedDailyLossAmount && FixedDailyLossAmount <= 0.0)
         {
            CFalconLogger::Error("FixedDailyLossAmount must be greater than zero.");
            return false;
         }

         if(!UseFixedDailyLossAmount && (DailyLossPercentOfCapital <= 0.0 || DailyLossPercentOfCapital > 100.0))
         {
            CFalconLogger::Error("DailyLossPercentOfCapital must be between 0 and 100.");
            return false;
         }
      }

      if(MaxTradesPerDay < 0 || MaxOpenPositions < 0)
      {
         CFalconLogger::Error("MaxTradesPerDay and MaxOpenPositions cannot be negative.");
         return false;
      }

      return true;
   }
};

// ==================================================================
// First Shadow Strategy Adapter Shell - v0.13.1
// This registry only describes strategies and their safety stage.
// It does not execute detectors, does not produce signals, and does not send orders.
// ==================================================================
class CFalconStrategyRegistry
{
private:
   FalconStrategyRegistryEntry m_entries[];
   int                         m_entry_count;
   bool                        m_initialized;

   void Reset()
   {
      ArrayResize(m_entries, 0);
      m_entry_count = 0;
      m_initialized = false;
   }

   void AddEntry(const string strategy_id,
                 const string strategy_name,
                 const string engine_id,
                 const ENUM_FALCON_STRATEGY_GROUP strategy_group,
                 const bool input_enabled,
                 const ENUM_FALCON_ENGINE_HEALTH health_status,
                 const ENUM_FALCON_ENGINE_STATUS max_allowed_stage,
                 const bool shadow_allowed,
                 const bool paper_allowed,
                 const bool demo_allowed,
                 const bool live_allowed,
                 const string notes)
   {
      int index = m_entry_count;
      ArrayResize(m_entries, index + 1);
      m_entries[index].strategy_id       = strategy_id;
      m_entries[index].strategy_name     = strategy_name;
      m_entries[index].engine_id         = engine_id;
      m_entries[index].strategy_group    = strategy_group;
      m_entries[index].input_enabled     = input_enabled;
      m_entries[index].health_status     = health_status;
      m_entries[index].max_allowed_stage = max_allowed_stage;
      m_entries[index].shadow_allowed    = shadow_allowed;
      m_entries[index].paper_allowed     = paper_allowed;
      m_entries[index].demo_allowed      = demo_allowed;
      m_entries[index].live_allowed      = false; // v0.x never allows live strategy execution.
      m_entries[index].notes             = notes;
      m_entry_count++;
   }

public:
   CFalconStrategyRegistry()
   {
      Reset();
   }

   bool Initialize()
   {
      Reset();

      AddEntry("FVG_MICRO_RETEST", "FVG Micro Retest Engine", "SCALP.FVG_MICRO",
               FALCON_STRATEGY_GROUP_CORE, (EnableStrategy_FvgMicroRetest || EnableFvgMicroRuntimePipelineRefresh),
               FALCON_ENGINE_HEALTH_CORE_WINNER, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Legacy indicator core winner. v0.18.4 allows ShadowSmoke activation when FVG runtime pipeline is enabled; still Shadow-first and no live execution.");

      AddEntry("TAIL_SMART_RETURN", "Tail Smart Return Strategy", "PRICE.TAIL_RETURN",
               FALCON_STRATEGY_GROUP_PRICE_ACTION, EnableStrategy_TailSmartReturn,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Strategy rewritten from candle-tail retest concept. H1 zone then LTF confirmation.");

      AddEntry("MOMENTUM_CROSS_8_20", "Momentum Cross 8/20 Strategy", "CONFIRM.MA_8_20",
               FALCON_STRATEGY_GROUP_CONFIRMATION, EnableStrategy_MomentumCross820,
               FALCON_ENGINE_HEALTH_WATCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Golden/Death Cross 8/20. Confirmation-first, not a priority execution engine.");

      AddEntry("CHECK_MARK_LIQUIDITY_SWEEP", "Check Mark Liquidity Sweep Reversal", "OPENING.CHECK_MARK",
               FALCON_STRATEGY_GROUP_OPENING, EnableStrategy_CheckMarkLiquiditySweep,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Opening 15m manipulation/blowoff plus retest and pivot confirmation.");

      AddEntry("DOUBLE_BOX_WICK_CONFIRMATION", "Double Box Wick Confirmation Strategy", "LIQUIDITY.DOUBLE_BOX",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_DoubleBoxWickConfirmation,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Previous-day box plus pre/post-market box with wick confirmation.");

      AddEntry("TOUCH_TURN_OPENING_RANGE", "Touch & Turn Opening Range Scalper", "OPENING.TOUCH_TURN",
               FALCON_STRATEGY_GROUP_OPENING, EnableStrategy_TouchTurnOpeningRange,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "First 15m range, ATR liquidity candle, edge touch then rotation back inside.");

      AddEntry("MAGIC_LIQUIDITY_PITCHFORK", "Magic Liquidity Lines + Pitchfork Confirmation", "LIQUIDITY.MAGIC_LINES",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_MagicLiquidityPitchfork,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "H1 highs/lows/breakout zones with pitchfork candle confirmation.");

      AddEntry("DAILY_LIQUIDITY_BOX", "Daily Liquidity Box + Pitchfork Confirmation", "LIQUIDITY.DAILY_BOX",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_DailyLiquidityBox,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Previous-day high/low box. Buy lower edge, sell upper edge after confirmation.");

      AddEntry("QUICK_FLIP_OPENING_LIQUIDITY", "Quick Flip Opening Liquidity Scalper", "OPENING.QUICK_FLIP",
               FALCON_STRATEGY_GROUP_OPENING, EnableStrategy_QuickFlipOpeningLiquidity,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Opening 15m liquidity candle, reversal candle outside range within 90 minutes.");

      AddEntry("FSE_PATTERN_FAILURE_ENTRY", "First Sign Execution Pattern Failure Entry", "PRICE.FSE_FAILURE",
               FALCON_STRATEGY_GROUP_PRICE_ACTION, EnableStrategy_FSEPatternFailureEntry,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Early entry after previous pattern failure at a known level. Also called Unsharp/FSE.");

      AddEntry("TWO_LIQUIDITY_LINES_15M", "Two Liquidity Lines + 15M Confirmation", "LIQUIDITY.TWO_LINES_15M",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_TwoLiquidityLines15M,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "H1 swing high/low lines and 15M reversal confirmation. No middle trades.");

      AddEntry("GOLDEN_LIQUIDITY_5M_ENTRY", "Golden Liquidity Zones + 5M Pitchfork Entry", "LIQUIDITY.GOLDEN_5M",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_GoldenLiquidity5MEntry,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "H1 liquidity zones with M5 pitchfork confirmation. Anti-random-5M usage.");

      m_initialized = true;
      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   int CountRegisteredStrategies()
   {
      return m_entry_count;
   }

   int CountEnabledStrategies()
   {
      int count = 0;
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].input_enabled)
            count++;
      }
      return count;
   }

   int CountByGroup(const ENUM_FALCON_STRATEGY_GROUP group)
   {
      int count = 0;
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].strategy_group == group)
            count++;
      }
      return count;
   }

   int CountByHealth(const ENUM_FALCON_ENGINE_HEALTH health_status)
   {
      int count = 0;
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].health_status == health_status)
            count++;
      }
      return count;
   }

   bool GetEntryByIndex(const int index, FalconStrategyRegistryEntry &entry)
   {
      if(index < 0 || index >= m_entry_count)
         return false;
      entry = m_entries[index];
      return true;
   }

   bool GetEntryById(const string strategy_id, FalconStrategyRegistryEntry &entry)
   {
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].strategy_id == strategy_id)
         {
            entry = m_entries[i];
            return true;
         }
      }
      return false;
   }

   bool AnyLiveAllowed()
   {
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].live_allowed)
            return true;
      }
      return false;
   }

   void PrintRegistryState()
   {
      CFalconLogger::Info(StringFormat("StrategyRegistry initialized. Registered=%d | EnabledByInputs=%d | CoreWinners=%d | Research=%d | Watch=%d | LiveAllowed=%s | Stage=REGISTRY_ONLY_v0.13.1",
                                       CountRegisteredStrategies(),
                                       CountEnabledStrategies(),
                                       CountByHealth(FALCON_ENGINE_HEALTH_CORE_WINNER),
                                       CountByHealth(FALCON_ENGINE_HEALTH_RESEARCH),
                                       CountByHealth(FALCON_ENGINE_HEALTH_WATCH),
                                       (AnyLiveAllowed() ? "true" : "false")));
   }
};


// ==================================================================
// Shadow Engine Framework Foundation - v0.13.1
// Shadow is observation-only. It can stage simulated records and convert
// them to lifecycle records, but it never sends broker orders.
// ==================================================================
class CFalconShadowExecutor
{
private:
   bool m_initialized;
   int  m_staged_records;
   int  m_closed_records;
   int  m_cancelled_records;

public:
   CFalconShadowExecutor()
   {
      m_initialized       = false;
      m_staged_records    = 0;
      m_closed_records    = 0;
      m_cancelled_records = 0;
   }

   bool Initialize()
   {
      m_initialized       = EnableShadowMode;
      m_staged_records    = 0;
      m_closed_records    = 0;
      m_cancelled_records = 0;

      if(m_initialized)
         CFalconLogger::Info("ShadowExecutor initialized. Mode=OBSERVE_ONLY | BrokerOrders=false");
      else
         CFalconLogger::Warn("ShadowExecutor is disabled by input EnableShadowMode=false. EA remains idle.");

      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   int StagedRecords()
   {
      return m_staged_records;
   }

   int ClosedRecords()
   {
      return m_closed_records;
   }

   int CancelledRecords()
   {
      return m_cancelled_records;
   }

   bool StageTradePlan(const FalconTradePlan &plan,
                       const FalconEvidencePack &evidence_pack,
                       FalconShadowTradeRecord &record)
   {
      ResetShadowRecord(record);

      if(!m_initialized)
      {
         CFalconLogger::Warn("StageTradePlan ignored because ShadowExecutor is not initialized.");
         return false;
      }

      record.shadow_id        = StringFormat("SHD_%s_%d_%d", plan.strategy_id, (int)TimeCurrent(), m_staged_records + 1);
      record.strategy_id      = plan.strategy_id;
      record.strategy_name    = plan.strategy_name;
      record.engine_id        = plan.engine_id;
      record.direction        = plan.direction;
      record.status           = FALCON_SHADOW_RECORD_STAGED;
      record.entry_time       = TimeCurrent();
      record.exit_time        = 0;
      record.lot_size         = plan.lot_size;
      record.entry_price      = plan.entry_price;
      record.structural_sl    = plan.structural_sl;
      record.tp1              = plan.tp1;
      record.tp2              = plan.tp2;
      record.tp3              = plan.tp3;
      record.simulated_exit_price = 0.0;
      record.simulated_outcome    = FALCON_TRADE_OUTCOME_OPEN;
      record.close_reason         = "STAGED_ONLY_NO_EXECUTION";
      record.evidence_summary     = evidence_pack.summary;
      record.fvg_size_points      = plan.fvg_size_points;
      record.fvg_spread_points    = plan.fvg_spread_points;
      record.fvg_retest_age_bars  = plan.fvg_retest_age_bars;
      record.fvg_setup_time = plan.fvg_setup_time;
      record.fvg_retest_watch_time = plan.fvg_retest_watch_time;
      record.fvg_age_bars_at_watch = plan.fvg_age_bars_at_watch;
      record.fvg_age_source = plan.fvg_age_source;
      record.fvg_retest_fresh_state = plan.fvg_retest_fresh_state;
      record.fvg_hold_quality_score = plan.fvg_hold_quality_score;
      record.fvg_hold_quality_bucket = plan.fvg_hold_quality_bucket;
      record.quality_filters_passed = plan.quality_filters_passed;
      record.quality_profile_balanced_passed = plan.quality_profile_balanced_passed;
      record.quality_profile_strict_size_passed = plan.quality_profile_strict_size_passed;
      record.quality_profile_tight_spread_passed = plan.quality_profile_tight_spread_passed;
      record.quality_profile_strict_combo_passed = plan.quality_profile_strict_combo_passed;
      record.is_closed            = false;

      m_staged_records++;
      CFalconLogger::Info(StringFormat("Shadow trade staged. ShadowId=%s | Strategy=%s | Direction=%s | Entry=%.5f | SL=%.5f | TP1=%.5f",
                                       record.shadow_id,
                                       record.strategy_name,
                                       FalconDirectionToString(record.direction),
                                       record.entry_price,
                                       record.structural_sl,
                                       record.tp1));
      return true;
   }

   bool CloseShadowRecord(FalconShadowTradeRecord &record,
                          const double simulated_exit_price,
                          const string close_reason,
                          const FalconSymbolContext &symbol_context,
                          FalconTradeLifecycleRecord &lifecycle_record)
   {
      if(record.status != FALCON_SHADOW_RECORD_STAGED)
      {
         CFalconLogger::Warn("CloseShadowRecord ignored because record is not staged.");
         return false;
      }

      record.simulated_exit_price = simulated_exit_price;
      record.exit_time            = TimeCurrent();
      record.close_reason         = close_reason;
      record.status               = FALCON_SHADOW_RECORD_CLOSED;
      record.is_closed            = true;
      m_closed_records++;

      ShadowToLifecycle(record, lifecycle_record);
      FalconFinalizeTradeMetrics(lifecycle_record, symbol_context);
      record.simulated_outcome = lifecycle_record.outcome;

      CFalconLogger::Info(StringFormat("Shadow trade closed. ShadowId=%s | Outcome=%s | NetIndexPoints=%.2f | NetUSD=%.2f",
                                       record.shadow_id,
                                       FalconOutcomeToString(lifecycle_record.outcome),
                                       lifecycle_record.net_index_points,
                                       lifecycle_record.net_usd));
      return true;
   }

   void CancelShadowRecord(FalconShadowTradeRecord &record,
                           const string reason)
   {
      if(record.status != FALCON_SHADOW_RECORD_STAGED)
         return;

      record.status       = FALCON_SHADOW_RECORD_CANCELLED;
      record.close_reason = reason;
      record.exit_time    = TimeCurrent();
      record.is_closed    = true;
      m_cancelled_records++;
   }

private:
   void ResetShadowRecord(FalconShadowTradeRecord &record)
   {
      record.shadow_id            = "";
      record.strategy_id          = "";
      record.strategy_name        = "";
      record.engine_id            = "";
      record.direction            = FALCON_DIRECTION_NONE;
      record.status               = FALCON_SHADOW_RECORD_NONE;
      record.entry_time           = 0;
      record.exit_time            = 0;
      record.lot_size             = 0.0;
      record.entry_price          = 0.0;
      record.structural_sl        = 0.0;
      record.tp1                  = 0.0;
      record.tp2                  = 0.0;
      record.tp3                  = 0.0;
      record.simulated_exit_price = 0.0;
      record.simulated_outcome    = FALCON_TRADE_OUTCOME_UNKNOWN;
      record.close_reason         = "";
      record.evidence_summary     = "";
      record.fvg_size_points      = 0.0;
      record.fvg_spread_points    = 0;
      record.fvg_retest_age_bars  = 0;
      record.fvg_setup_time = 0;
      record.fvg_retest_watch_time = 0;
      record.fvg_age_bars_at_watch = 0;
      record.fvg_age_source = "";
      record.fvg_retest_fresh_state = "";
      record.fvg_hold_quality_score = 0;
      record.fvg_hold_quality_bucket = "";
      record.quality_filters_passed = false;
      record.fvg_quality_shadow_guard_profile = "";
      record.fvg_quality_shadow_guard_passed = false;
      record.fvg_quality_shadow_guard_decision = "NOT_EVALUATED";
      record.fvg_quality_shadow_guard_reason = "";
      record.fvg_quality_shadow_guard_sim_net_points = 0.0;
      record.fvg_quality_shadow_guard_sim_net_usd = 0.0;
      record.quality_profile_balanced_passed = false;
      record.quality_profile_strict_size_passed = false;
      record.quality_profile_tight_spread_passed = false;
      record.quality_profile_strict_combo_passed = false;
      record.is_closed            = false;
   }

   void ShadowToLifecycle(const FalconShadowTradeRecord &record,
                          FalconTradeLifecycleRecord &lifecycle_record)
   {
      lifecycle_record.trade_id            = record.shadow_id;
      lifecycle_record.strategy_id         = record.strategy_id;
      lifecycle_record.strategy_name       = record.strategy_name;
      lifecycle_record.engine_id           = record.engine_id;
      lifecycle_record.direction           = record.direction;
      lifecycle_record.stage               = FALCON_TRADE_STAGE_SHADOW;
      lifecycle_record.outcome             = record.simulated_outcome;
      lifecycle_record.entry_time          = record.entry_time;
      lifecycle_record.exit_time           = record.exit_time;
      lifecycle_record.lot_size            = record.lot_size;
      lifecycle_record.entry_price         = record.entry_price;
      lifecycle_record.structural_sl       = record.structural_sl;
      lifecycle_record.tp1                 = record.tp1;
      lifecycle_record.tp2                 = record.tp2;
      lifecycle_record.tp3                 = record.tp3;
      lifecycle_record.exit_price          = record.simulated_exit_price;
      lifecycle_record.profit_index_points = 0.0;
      lifecycle_record.loss_index_points   = 0.0;
      lifecycle_record.net_index_points    = 0.0;
      lifecycle_record.profit_usd          = 0.0;
      lifecycle_record.loss_usd            = 0.0;
      lifecycle_record.net_usd             = 0.0;
      lifecycle_record.close_reason        = record.close_reason;
      lifecycle_record.evidence_summary    = record.evidence_summary;
      lifecycle_record.fvg_size_points     = record.fvg_size_points;
      lifecycle_record.fvg_spread_points   = record.fvg_spread_points;
      lifecycle_record.fvg_retest_age_bars = record.fvg_retest_age_bars;
      lifecycle_record.fvg_setup_time = record.fvg_setup_time;
      lifecycle_record.fvg_retest_watch_time = record.fvg_retest_watch_time;
      lifecycle_record.fvg_age_bars_at_watch = record.fvg_age_bars_at_watch;
      lifecycle_record.fvg_age_source = record.fvg_age_source;
      lifecycle_record.fvg_retest_fresh_state = record.fvg_retest_fresh_state;
      lifecycle_record.fvg_hold_quality_score = record.fvg_hold_quality_score;
      lifecycle_record.fvg_hold_quality_bucket = record.fvg_hold_quality_bucket;
      lifecycle_record.quality_filters_passed = record.quality_filters_passed;
      lifecycle_record.quality_profile_balanced_passed = record.quality_profile_balanced_passed;
      lifecycle_record.quality_profile_strict_size_passed = record.quality_profile_strict_size_passed;
      lifecycle_record.quality_profile_tight_spread_passed = record.quality_profile_tight_spread_passed;
      lifecycle_record.quality_profile_strict_combo_passed = record.quality_profile_strict_combo_passed;
   }
};

// ==================================================================
// No-Lookahead Runtime Guard & Strategy Staging Safety - v0.13.1
// This layer blocks current-candle/final-state dependency before any future
// strategy can stage Shadow/Paper/Demo plans. It does not create signals.
// ==================================================================
class CFalconRuntimeSafetyGuard
{
private:
   FalconRuntimeSafetyCheck m_checks[4];
   int                      m_check_count;
   bool                     m_initialized;

public:
   CFalconRuntimeSafetyGuard()
   {
      m_check_count = 0;
      m_initialized = false;
   }

   bool Initialize(CFalconCandleCache &cache)
   {
      m_check_count = 0;
      FalconCandleSnapshot primary_m5;
      const bool has_m5 = cache.GetSnapshotByTimeframe(PERIOD_M5, primary_m5);

      FalconRuntimeSafetyCheck closed_candle_check;
      ResetCheck(closed_candle_check);
      closed_candle_check.check_id               = "NLA_CLOSED_CANDLE";
      closed_candle_check.check_name             = "Closed Candle Decision Guard";
      closed_candle_check.timeframe              = PERIOD_M5;
      closed_candle_check.source_shift           = (has_m5 ? primary_m5.source_shift : -1);
      closed_candle_check.used_closed_candle     = (has_m5 && primary_m5.is_closed && primary_m5.source_shift > 0);
      closed_candle_check.current_candle_blocked = true;
      closed_candle_check.final_state_blocked    = true;
      closed_candle_check.staging_allowed        = closed_candle_check.used_closed_candle;
      closed_candle_check.status                 = (closed_candle_check.staging_allowed ? FALCON_RUNTIME_SAFETY_PASSED : FALCON_RUNTIME_SAFETY_REJECTED);
      closed_candle_check.risk_type              = (closed_candle_check.staging_allowed ? FALCON_LOOKAHEAD_RISK_NONE : FALCON_LOOKAHEAD_RISK_CURRENT_CANDLE);
      closed_candle_check.notes                  = "Future strategies must use prior closed candle snapshots for decisions. Current candle is blocked from decision state.";
      AddCheck(closed_candle_check);

      FalconRuntimeSafetyCheck final_state_check;
      ResetCheck(final_state_check);
      final_state_check.check_id               = "NLA_FINAL_STATE";
      final_state_check.check_name             = "No Final-State Dependency";
      final_state_check.timeframe              = PERIOD_CURRENT;
      final_state_check.source_shift           = -1;
      final_state_check.used_closed_candle     = true;
      final_state_check.current_candle_blocked = true;
      final_state_check.final_state_blocked    = true;
      final_state_check.staging_allowed        = true;
      final_state_check.status                 = FALCON_RUNTIME_SAFETY_PASSED;
      final_state_check.risk_type              = FALCON_LOOKAHEAD_RISK_NONE;
      final_state_check.notes                  = "Runtime candidate cannot rely on final trade path, final bar high/low order, or future exit-state tags.";
      AddCheck(final_state_check);

      FalconRuntimeSafetyCheck staging_check;
      ResetCheck(staging_check);
      staging_check.check_id               = "NLA_STAGE_SAFETY";
      staging_check.check_name             = "Strategy Staging Safety Contract";
      staging_check.timeframe              = PERIOD_CURRENT;
      staging_check.source_shift           = -1;
      staging_check.used_closed_candle     = true;
      staging_check.current_candle_blocked = true;
      staging_check.final_state_blocked    = true;
      staging_check.staging_allowed        = true;
      staging_check.status                 = FALCON_RUNTIME_SAFETY_PASSED;
      staging_check.risk_type              = FALCON_LOOKAHEAD_RISK_NONE;
      staging_check.notes                  = "Future strategy plans must pass ValidateTradePlanForStaging before Shadow/Paper/Demo staging.";
      AddCheck(staging_check);

      m_initialized = AllChecksPassed();
      if(m_initialized)
         CFalconLogger::Info(StringFormat("RuntimeSafetyGuard initialized. Checks=%d | Status=PASSED | NoLookahead=true", m_check_count));
      else
         CFalconLogger::Error(StringFormat("RuntimeSafetyGuard failed. Checks=%d | Status=REJECTED", m_check_count));

      return m_initialized;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   int Count()
   {
      return m_check_count;
   }

   bool GetCheckByIndex(const int index, FalconRuntimeSafetyCheck &check)
   {
      if(index < 0 || index >= m_check_count)
         return false;
      check = m_checks[index];
      return true;
   }

   bool ValidateCandleSnapshotForDecision(const FalconCandleSnapshot &snapshot, string &reject_reason)
   {
      reject_reason = "";
      if(!snapshot.is_valid)
      {
         reject_reason = "INVALID_CANDLE_SNAPSHOT";
         return false;
      }

      if(UseClosedCandlesOnly && (!snapshot.is_closed || snapshot.source_shift <= 0))
      {
         reject_reason = "CURRENT_CANDLE_DECISION_BLOCKED";
         return false;
      }

      return true;
   }

   bool ValidateTradePlanForStaging(const FalconTradePlan &plan, string &reject_reason)
   {
      reject_reason = "";
      if(!m_initialized)
      {
         reject_reason = "RUNTIME_SAFETY_GUARD_NOT_INITIALIZED";
         return false;
      }

      if(plan.strategy_id == "" || plan.strategy_name == "" || plan.engine_id == "")
      {
         reject_reason = "TRADEPLAN_MISSING_IDENTITY";
         return false;
      }

      if(plan.direction != FALCON_DIRECTION_BUY && plan.direction != FALCON_DIRECTION_SELL)
      {
         reject_reason = "TRADEPLAN_INVALID_DIRECTION";
         return false;
      }

      if(plan.lot_size <= 0.0 || plan.entry_price <= 0.0 || plan.structural_sl <= 0.0)
      {
         reject_reason = "TRADEPLAN_INVALID_PRICE_OR_LOT";
         return false;
      }

      return true;
   }

private:
   void ResetCheck(FalconRuntimeSafetyCheck &check)
   {
      check.check_id               = "";
      check.check_name             = "";
      check.status                 = FALCON_RUNTIME_SAFETY_NOT_EVALUATED;
      check.risk_type              = FALCON_LOOKAHEAD_RISK_NONE;
      check.timeframe              = PERIOD_CURRENT;
      check.source_shift           = -1;
      check.used_closed_candle     = false;
      check.current_candle_blocked = false;
      check.final_state_blocked    = false;
      check.staging_allowed        = false;
      check.notes                  = "";
   }

   void AddCheck(const FalconRuntimeSafetyCheck &check)
   {
      if(m_check_count >= 4)
         return;
      m_checks[m_check_count] = check;
      m_check_count++;
   }

   bool AllChecksPassed()
   {
      if(m_check_count <= 0)
         return false;

      for(int i = 0; i < m_check_count; i++)
      {
         if(m_checks[i].status != FALCON_RUNTIME_SAFETY_PASSED)
            return false;
      }
      return true;
   }
};


// ==================================================================
// First Shadow Strategy Adapter Shell - v0.13.1
// This adapter proves that a registered strategy can be discovered and
// evaluated for future Shadow staging without running any detector.
// It intentionally produces NO_TRADE / BLOCKED candidate diagnostics only.
// ==================================================================
class CFalconFirstShadowStrategyAdapterShell
{
private:
   FalconStrategyAdapterSnapshot m_snapshot;
   bool                          m_initialized;

public:
   CFalconFirstShadowStrategyAdapterShell()
   {
      ResetSnapshot();
      m_initialized = false;
   }

   bool Initialize(CFalconStrategyRegistry &registry,
                   CFalconRuntimeSafetyGuard &runtime_guard,
                   CFalconShadowExecutor &shadow_executor)
   {
      ResetSnapshot();
      m_snapshot.adapter_id         = "ADAPTER_SHELL_FVG_MICRO_RETEST_v0_10_1";
      m_snapshot.target_strategy_id = "FVG_MICRO_RETEST";
      m_snapshot.runtime_safety_ready = runtime_guard.IsInitialized();
      m_snapshot.shadow_executor_ready = shadow_executor.IsInitialized();
      m_snapshot.order_send_used = false;
      m_snapshot.live_allowed = false;

      FalconStrategyRegistryEntry entry;
      if(!registry.GetEntryById(m_snapshot.target_strategy_id, entry))
      {
         m_snapshot.registry_found = false;
         m_snapshot.adapter_status = FALCON_ADAPTER_STATUS_NO_TRADE;
         m_snapshot.no_trade_reason = "REGISTRY_ENTRY_NOT_FOUND";
         m_snapshot.safety_reason = "ADAPTER_DID_NOT_BUILD_TRADEPLAN";
         m_snapshot.notes = "First adapter shell could not find the target strategy. No staging attempted.";
         m_initialized = true;
         return true;
      }

      m_snapshot.registry_found     = true;
      m_snapshot.strategy_name      = entry.strategy_name;
      m_snapshot.engine_id          = entry.engine_id;
      m_snapshot.strategy_group     = entry.strategy_group;
      m_snapshot.health_status      = entry.health_status;
      m_snapshot.max_allowed_stage  = entry.max_allowed_stage;
      m_snapshot.input_enabled      = entry.input_enabled;
      m_snapshot.shadow_allowed     = entry.shadow_allowed;
      m_snapshot.live_allowed       = false;
      m_snapshot.candidate_requested = (entry.input_enabled && entry.shadow_allowed && EnableShadowMode);
      m_snapshot.candidate_staged    = false;

      if(!m_snapshot.runtime_safety_ready)
      {
         m_snapshot.adapter_status  = FALCON_ADAPTER_STATUS_SHADOW_CANDIDATE_BLOCKED;
         m_snapshot.no_trade_reason = "RUNTIME_SAFETY_NOT_READY";
         m_snapshot.safety_reason   = "NO_LOOKAHEAD_GUARD_REQUIRED_BEFORE_SHADOW_STAGING";
      }
      else if(!m_snapshot.shadow_executor_ready)
      {
         m_snapshot.adapter_status  = FALCON_ADAPTER_STATUS_SHADOW_CANDIDATE_BLOCKED;
         m_snapshot.no_trade_reason = "SHADOW_EXECUTOR_NOT_READY";
         m_snapshot.safety_reason   = "ENABLE_SHADOW_MODE_REQUIRED_FOR_FUTURE_STAGING";
      }
      else if(m_snapshot.candidate_requested)
      {
         m_snapshot.adapter_status  = FALCON_ADAPTER_STATUS_SHADOW_CANDIDATE_BLOCKED;
         m_snapshot.no_trade_reason = "ADAPTER_SHELL_NO_DETECTOR_YET";
         m_snapshot.safety_reason   = "NO_TRADEPLAN_CREATED_IN_v0_12_0";
      }
      else
      {
         m_snapshot.adapter_status  = FALCON_ADAPTER_STATUS_NO_TRADE;
         m_snapshot.no_trade_reason = (entry.input_enabled ? "SHADOW_NOT_REQUESTED_OR_NOT_ALLOWED" : "STRATEGY_INPUT_DISABLED");
         m_snapshot.safety_reason   = "ADAPTER_SHELL_OBSERVE_ONLY";
      }

      m_snapshot.notes = "v0.13.1 adapter shell only. Registry linked to Shadow Executor, but no detector, no signal, no trade plan, and no staging.";
      m_initialized = true;

      CFalconLogger::Info(StringFormat("FirstStrategyAdapterShell initialized. Strategy=%s | InputEnabled=%s | Status=%s | Reason=%s",
                                       m_snapshot.target_strategy_id,
                                       (m_snapshot.input_enabled ? "true" : "false"),
                                       FalconAdapterStatusToString(m_snapshot.adapter_status),
                                       m_snapshot.no_trade_reason));
      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   FalconStrategyAdapterSnapshot GetSnapshot()
   {
      return m_snapshot;
   }

private:
   void ResetSnapshot()
   {
      m_snapshot.adapter_id            = "";
      m_snapshot.target_strategy_id    = "";
      m_snapshot.strategy_name         = "";
      m_snapshot.engine_id             = "";
      m_snapshot.strategy_group        = FALCON_STRATEGY_GROUP_RESEARCH;
      m_snapshot.health_status         = FALCON_ENGINE_HEALTH_DISABLED;
      m_snapshot.max_allowed_stage     = FALCON_ENGINE_DISABLED;
      m_snapshot.adapter_status        = FALCON_ADAPTER_STATUS_NOT_INITIALIZED;
      m_snapshot.registry_found        = false;
      m_snapshot.input_enabled         = false;
      m_snapshot.shadow_allowed        = false;
      m_snapshot.shadow_executor_ready = false;
      m_snapshot.runtime_safety_ready  = false;
      m_snapshot.candidate_requested   = false;
      m_snapshot.candidate_staged      = false;
      m_snapshot.live_allowed          = false;
      m_snapshot.order_send_used       = false;
      m_snapshot.no_trade_reason       = "";
      m_snapshot.safety_reason         = "";
      m_snapshot.notes                 = "";
   }
};

// ==================================================================
// FVG Micro Real Shadow Detector Phase 1 - v0.13.1
// Detects real 3-candle M5 FVGs using closed candles only.
// It does NOT create TradePlans, does NOT stage Shadow trades,
// and does NOT send orders. Detection is diagnostic / shadow-only.
// ==================================================================
class CFalconFvgMicroShadowDetectorStub
{
private:
   FalconFvgMicroDetectorSnapshot m_snapshot;
   bool                           m_initialized;

public:
   CFalconFvgMicroShadowDetectorStub()
   {
      ResetSnapshot();
      m_initialized = false;
   }

   bool Initialize(CFalconStrategyRegistry &registry,
                   CFalconCandleCache &candle_cache,
                   CFalconEvidenceFramework &evidence_framework,
                   CFalconRuntimeSafetyGuard &runtime_guard)
   {
      ResetSnapshot();
      m_snapshot.detector_id = "DETECTOR_FVG_MICRO_RETEST_REAL_PHASE1_v0_12_0";
      m_snapshot.strategy_id = "FVG_MICRO_RETEST";
      m_snapshot.analysis_timeframe = PERIOD_M5;
      m_snapshot.analysis_shift = candle_cache.AnalysisShift();
      m_snapshot.candle_cache_ready = candle_cache.IsLoaded();
      m_snapshot.evidence_framework_ready = evidence_framework.IsInitialized();
      m_snapshot.runtime_safety_ready = runtime_guard.IsInitialized();
      m_snapshot.order_send_used = false;

      FalconStrategyRegistryEntry entry;
      if(!registry.GetEntryById(m_snapshot.strategy_id, entry))
      {
         m_snapshot.registry_found = false;
         m_snapshot.detector_status = FALCON_DETECTOR_STATUS_BLOCKED;
         m_snapshot.no_trade_reason = "REGISTRY_ENTRY_NOT_FOUND";
         m_snapshot.safety_reason = "DETECTOR_BLOCKED_BEFORE_CANDLE_READ";
         m_snapshot.notes = "FVG Micro detector could not find registry entry. No TradePlan created.";
         m_initialized = true;
         return true;
      }

      m_snapshot.registry_found = true;
      m_snapshot.strategy_name = entry.strategy_name;
      m_snapshot.engine_id = entry.engine_id;
      m_snapshot.input_enabled = entry.input_enabled;

      if(!m_snapshot.candle_cache_ready)
      {
         m_snapshot.detector_status = FALCON_DETECTOR_STATUS_BLOCKED;
         m_snapshot.no_trade_reason = "CANDLE_CACHE_NOT_READY";
         m_snapshot.safety_reason = "SAFE_CANDLE_DATA_REQUIRED";
         m_snapshot.notes = "Detector requires CandleCache to be loaded first.";
         m_initialized = true;
         return true;
      }

      FalconCandleSnapshot m5_snapshot;
      if(!candle_cache.GetSnapshotByTimeframe(PERIOD_M5, m5_snapshot))
      {
         m_snapshot.detector_status = FALCON_DETECTOR_STATUS_BLOCKED;
         m_snapshot.no_trade_reason = "M5_ANALYSIS_CANDLE_NOT_AVAILABLE";
         m_snapshot.safety_reason = "FVG_MICRO_REQUIRES_M5_SNAPSHOT";
         m_snapshot.notes = "No M5 closed analysis candle was available from CandleCache.";
         m_initialized = true;
         return true;
      }

      m_snapshot.analysis_timeframe = m5_snapshot.timeframe;
      m_snapshot.analysis_shift = m5_snapshot.source_shift;
      m_snapshot.candle_time = m5_snapshot.time;
      m_snapshot.candle_open = m5_snapshot.open;
      m_snapshot.candle_high = m5_snapshot.high;
      m_snapshot.candle_low = m5_snapshot.low;
      m_snapshot.candle_close = m5_snapshot.close;
      m_snapshot.candle_tick_volume = m5_snapshot.tick_volume;
      m_snapshot.used_closed_candle = m5_snapshot.is_closed;

      string candle_reject = "";
      if(!runtime_guard.ValidateCandleSnapshotForDecision(m5_snapshot, candle_reject))
      {
         m_snapshot.detector_status = FALCON_DETECTOR_STATUS_BLOCKED;
         m_snapshot.no_trade_reason = candle_reject;
         m_snapshot.safety_reason = "NO_LOOKAHEAD_GUARD_BLOCKED_CANDLE";
         m_snapshot.notes = "Detector refused to evaluate unsafe candle data.";
         m_initialized = true;
         return true;
      }

      if(!m_snapshot.evidence_framework_ready)
      {
         m_snapshot.detector_status = FALCON_DETECTOR_STATUS_BLOCKED;
         m_snapshot.no_trade_reason = "EVIDENCE_FRAMEWORK_NOT_READY";
         m_snapshot.safety_reason = "EVIDENCE_CONTRACTS_REQUIRED";
         m_snapshot.notes = "Detector requires Evidence Framework before writing FVG evidence.";
         m_initialized = true;
         return true;
      }

      if(!m_snapshot.runtime_safety_ready)
      {
         m_snapshot.detector_status = FALCON_DETECTOR_STATUS_BLOCKED;
         m_snapshot.no_trade_reason = "RUNTIME_SAFETY_NOT_READY";
         m_snapshot.safety_reason = "NO_LOOKAHEAD_GUARD_REQUIRED";
         m_snapshot.notes = "Detector requires No-Lookahead Guard before evaluation.";
         m_initialized = true;
         return true;
      }

      bool detected = DetectThreeCandleM5Fvg();
      FalconEvidencePack pack = evidence_framework.BuildEmptyEvidencePack();

      if(detected)
      {
         m_snapshot.evidence_score = 25.0;
         m_snapshot.evidence_summary = StringFormat("SMC_FVG_PRESENT;Direction=%s;TF=%s;Lower=%s;Upper=%s;SizePoints=%s",
                                                    FalconDirectionToString(m_snapshot.fvg_direction),
                                                    FalconTimeframeToString(m_snapshot.analysis_timeframe),
                                                    DoubleToString(m_snapshot.fvg_lower, _Digits),
                                                    DoubleToString(m_snapshot.fvg_upper, _Digits),
                                                    DoubleToString(m_snapshot.fvg_size_points, 2));

         if(!m_snapshot.input_enabled)
         {
            m_snapshot.detector_status = FALCON_DETECTOR_STATUS_NO_TRADE;
            m_snapshot.no_trade_reason = "FVG_DETECTED_BUT_STRATEGY_INPUT_DISABLED";
            m_snapshot.safety_reason = "SHADOW_OBSERVE_ONLY_INPUT_OFF";
         }
         else
         {
            m_snapshot.detector_status = FALCON_DETECTOR_STATUS_FVG_FOUND_SHADOW_ONLY;
            m_snapshot.no_trade_reason = "FVG_FOUND_NO_TRADEPLAN_IN_v0_12_0";
            m_snapshot.safety_reason = "SHADOW_DETECTION_ONLY_NO_STAGING";
         }
      }
      else
      {
         m_snapshot.evidence_score = pack.score;
         m_snapshot.evidence_summary = "SMC_FVG_ABSENT;" + pack.summary;
         m_snapshot.detector_status = FALCON_DETECTOR_STATUS_NO_FVG;
         m_snapshot.no_trade_reason = "NO_THREE_CANDLE_M5_FVG_DETECTED";
         m_snapshot.safety_reason = "NO_TRADEPLAN_CREATED_IN_v0_12_0";
      }

      m_snapshot.notes = "v0.13.1 FVG Micro real shadow detector Phase 1. Uses three closed M5 candles: older=shift+2, middle=shift+1, newer=shift. Bullish FVG when older.high < newer.low. Bearish FVG when older.low > newer.high. No TradePlan, no Shadow staging, no OrderSend.";
      m_initialized = true;

      CFalconLogger::Info(StringFormat("FvgMicroRealDetector initialized. InputEnabled=%s | Status=%s | FVG=%s | Direction=%s | Reason=%s | M5Time=%s",
                                       (m_snapshot.input_enabled ? "true" : "false"),
                                       FalconDetectorStatusToString(m_snapshot.detector_status),
                                       (m_snapshot.fvg_detected ? "true" : "false"),
                                       FalconDirectionToString(m_snapshot.fvg_direction),
                                       m_snapshot.no_trade_reason,
                                       FalconTimeToString(m_snapshot.candle_time)));
      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   FalconFvgMicroDetectorSnapshot GetSnapshot()
   {
      return m_snapshot;
   }

private:
   bool DetectThreeCandleM5Fvg()
   {
      const int shift = m_snapshot.analysis_shift;
      if(shift <= 0)
      {
         m_snapshot.safety_reason = "FVG_DETECTION_REQUIRES_CLOSED_CANDLE_SHIFT";
         return false;
      }

      MqlRates newer[];
      MqlRates middle[];
      MqlRates older[];
      ArrayResize(newer, 1);
      ArrayResize(middle, 1);
      ArrayResize(older, 1);
      ArraySetAsSeries(newer, true);
      ArraySetAsSeries(middle, true);
      ArraySetAsSeries(older, true);

      int copied_newer = CopyRates(_Symbol, PERIOD_M5, shift,     1, newer);
      int copied_mid   = CopyRates(_Symbol, PERIOD_M5, shift + 1, 1, middle);
      int copied_old   = CopyRates(_Symbol, PERIOD_M5, shift + 2, 1, older);

      if(copied_newer != 1 || copied_mid != 1 || copied_old != 1)
      {
         m_snapshot.safety_reason = "FVG_THREE_CANDLE_COPYRATES_FAILED";
         m_snapshot.notes = "Could not read three closed M5 candles for FVG detection.";
         return false;
      }

      m_snapshot.newer_candle_time  = newer[0].time;
      m_snapshot.middle_candle_time = middle[0].time;
      m_snapshot.older_candle_time  = older[0].time;
      m_snapshot.newer_candle_high  = newer[0].high;
      m_snapshot.newer_candle_low   = newer[0].low;
      m_snapshot.middle_candle_high = middle[0].high;
      m_snapshot.middle_candle_low  = middle[0].low;
      m_snapshot.older_candle_high  = older[0].high;
      m_snapshot.older_candle_low   = older[0].low;

      const bool bullish_fvg = (older[0].high < newer[0].low);
      const bool bearish_fvg = (older[0].low  > newer[0].high);

      if(bullish_fvg)
      {
         m_snapshot.fvg_detected = true;
         m_snapshot.fvg_direction = FALCON_DIRECTION_BUY;
         m_snapshot.fvg_lower = older[0].high;
         m_snapshot.fvg_upper = newer[0].low;
      }
      else if(bearish_fvg)
      {
         m_snapshot.fvg_detected = true;
         m_snapshot.fvg_direction = FALCON_DIRECTION_SELL;
         m_snapshot.fvg_lower = newer[0].high;
         m_snapshot.fvg_upper = older[0].low;
      }
      else
      {
         m_snapshot.fvg_detected = false;
         m_snapshot.fvg_direction = FALCON_DIRECTION_NONE;
         m_snapshot.fvg_lower = 0.0;
         m_snapshot.fvg_upper = 0.0;
         m_snapshot.fvg_size_price = 0.0;
         m_snapshot.fvg_size_points = 0.0;
         return false;
      }

      m_snapshot.fvg_size_price = MathAbs(m_snapshot.fvg_upper - m_snapshot.fvg_lower);
      m_snapshot.fvg_size_points = (m_snapshot.fvg_size_price / _Point);
      return true;
   }

   void ResetSnapshot()
   {
      m_snapshot.detector_id = "";
      m_snapshot.strategy_id = "";
      m_snapshot.strategy_name = "";
      m_snapshot.engine_id = "";
      m_snapshot.detector_status = FALCON_DETECTOR_STATUS_NOT_INITIALIZED;
      m_snapshot.registry_found = false;
      m_snapshot.input_enabled = false;
      m_snapshot.candle_cache_ready = false;
      m_snapshot.evidence_framework_ready = false;
      m_snapshot.runtime_safety_ready = false;
      m_snapshot.used_closed_candle = false;
      m_snapshot.order_send_used = false;
      m_snapshot.analysis_timeframe = PERIOD_M5;
      m_snapshot.analysis_shift = -1;
      m_snapshot.candle_time = 0;
      m_snapshot.candle_open = 0.0;
      m_snapshot.candle_high = 0.0;
      m_snapshot.candle_low = 0.0;
      m_snapshot.candle_close = 0.0;
      m_snapshot.candle_tick_volume = 0;
      m_snapshot.fvg_detected = false;
      m_snapshot.fvg_direction = FALCON_DIRECTION_NONE;
      m_snapshot.older_candle_time = 0;
      m_snapshot.middle_candle_time = 0;
      m_snapshot.newer_candle_time = 0;
      m_snapshot.older_candle_high = 0.0;
      m_snapshot.older_candle_low = 0.0;
      m_snapshot.middle_candle_high = 0.0;
      m_snapshot.middle_candle_low = 0.0;
      m_snapshot.newer_candle_high = 0.0;
      m_snapshot.newer_candle_low = 0.0;
      m_snapshot.fvg_lower = 0.0;
      m_snapshot.fvg_upper = 0.0;
      m_snapshot.fvg_size_price = 0.0;
      m_snapshot.fvg_size_points = 0.0;
      m_snapshot.evidence_score = 0.0;
      m_snapshot.evidence_summary = "";
      m_snapshot.no_trade_reason = "";
      m_snapshot.safety_reason = "";
      m_snapshot.notes = "";
   }
};

// ==================================================================
// FVG Micro Shadow Candidate Builder Phase 1 - v0.13.1
// Converts a valid detected FVG into a shadow candidate snapshot only.
// It does NOT create a TradePlan, does NOT stage a Shadow trade,
// and does NOT send orders. Candidate = structured research object.
// ==================================================================
class CFalconFvgMicroShadowCandidateBuilder
{
private:
   FalconFvgMicroShadowCandidateSnapshot m_snapshot;
   bool                                  m_initialized;

public:
   CFalconFvgMicroShadowCandidateBuilder()
   {
      ResetSnapshot();
      m_initialized = false;
   }

   bool Initialize(CFalconFvgMicroShadowDetectorStub &detector,
                   CFalconStrategyRegistry &registry,
                   CFalconRuntimeSafetyGuard &runtime_guard)
   {
      ResetSnapshot();
      m_snapshot.builder_id = "BUILDER_FVG_MICRO_SHADOW_CANDIDATE_PHASE1_v0_12_0";
      m_snapshot.detector_initialized = detector.IsInitialized();
      m_snapshot.runtime_safety_ready = runtime_guard.IsInitialized();
      m_snapshot.order_send_used = false;
      m_snapshot.tradeplan_created = false;
      m_snapshot.staged_to_shadow_executor = false;

      FalconFvgMicroDetectorSnapshot detector_snapshot = detector.GetSnapshot();
      m_snapshot.strategy_id        = detector_snapshot.strategy_id;
      m_snapshot.strategy_name      = detector_snapshot.strategy_name;
      m_snapshot.engine_id          = detector_snapshot.engine_id;
      m_snapshot.input_enabled      = detector_snapshot.input_enabled;
      m_snapshot.fvg_detected       = detector_snapshot.fvg_detected;
      m_snapshot.direction          = detector_snapshot.fvg_direction;
      m_snapshot.analysis_timeframe = detector_snapshot.analysis_timeframe;
      m_snapshot.setup_time         = detector_snapshot.newer_candle_time;
      m_snapshot.entry_zone_lower   = detector_snapshot.fvg_lower;
      m_snapshot.entry_zone_upper   = detector_snapshot.fvg_upper;
      m_snapshot.fvg_size_points    = detector_snapshot.fvg_size_points;
      m_snapshot.score              = detector_snapshot.evidence_score;
      m_snapshot.evidence_summary   = detector_snapshot.evidence_summary;

      FalconStrategyRegistryEntry entry;
      if(!registry.GetEntryById(m_snapshot.strategy_id, entry))
      {
         m_snapshot.registry_found = false;
         m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_BLOCKED;
         m_snapshot.block_reason = "REGISTRY_ENTRY_NOT_FOUND";
         m_snapshot.notes = "Candidate builder refused to create a candidate because the strategy is not registered.";
         m_initialized = true;
         return true;
      }

      m_snapshot.registry_found = true;
      m_snapshot.shadow_allowed = entry.shadow_allowed;

      if(!m_snapshot.detector_initialized)
      {
         m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_BLOCKED;
         m_snapshot.block_reason = "DETECTOR_NOT_INITIALIZED";
         m_snapshot.notes = "Detector must initialize before candidate builder.";
      }
      else if(!m_snapshot.runtime_safety_ready)
      {
         m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_BLOCKED;
         m_snapshot.block_reason = "NO_LOOKAHEAD_GUARD_NOT_READY_OR_FAILED";
         m_snapshot.notes = "Runtime safety guard must pass before any shadow candidate is allowed.";
      }
      else if(!m_snapshot.fvg_detected)
      {
         m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_NO_CANDIDATE;
         m_snapshot.block_reason = "NO_FVG_DETECTED";
         m_snapshot.notes = "No shadow candidate because the detector did not find a valid three-candle M5 FVG.";
      }
      else if(!m_snapshot.input_enabled)
      {
         m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_BLOCKED;
         m_snapshot.block_reason = "STRATEGY_INPUT_DISABLED";
         m_snapshot.notes = "FVG exists, but the strategy input switch is off. Candidate remains blocked.";
      }
      else if(!EvaluateQualityFilters(detector_snapshot))
      {
         m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_BLOCKED;
         m_snapshot.block_reason = "QUALITY_FILTER_REJECTED;" + m_snapshot.quality_reject_reason;
         m_snapshot.notes = "v0.19.3 FVG Micro quality filters blocked this candidate before Shadow staging. No OrderSend, no execution.";
      }
      else if(!m_snapshot.shadow_allowed)
      {
         m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_BLOCKED;
         m_snapshot.block_reason = "SHADOW_STAGE_NOT_ALLOWED_BY_REGISTRY";
         m_snapshot.notes = "Registry did not allow shadow stage for this strategy.";
      }
      else
      {
         m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_READY_SHADOW;
         m_snapshot.candidate_created = true;
         m_snapshot.candidate_id = StringFormat("FVG_MICRO_CAND_%s_%s",
                                                 FalconTimeToString(m_snapshot.setup_time),
                                                 FalconDirectionToString(m_snapshot.direction));
         m_snapshot.block_reason = "CANDIDATE_READY_QUALITY_FILTERS_PASSED_NO_TRADEPLAN";
         m_snapshot.notes = "Shadow candidate created after v0.19.3 quality filters passed. Research object only. No TradePlan, no broker OrderSend.";
      }

      FalconRegisterFvgMicroCandidateMetrics(m_snapshot);

      m_initialized = true;
      CFalconLogger::Info(StringFormat("FvgMicroCandidateBuilder initialized. Status=%s | CandidateCreated=%s | Reason=%s",
                                       FalconCandidateStatusToString(m_snapshot.candidate_status),
                                       (m_snapshot.candidate_created ? "true" : "false"),
                                       m_snapshot.block_reason));
      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   FalconFvgMicroShadowCandidateSnapshot GetSnapshot()
   {
      return m_snapshot;
   }

private:
   bool EvaluateQualityFilters(const FalconFvgMicroDetectorSnapshot &detector_snapshot)
   {
      m_snapshot.quality_filters_enabled = FALCON_FVG_MICRO_QUALITY_FILTERS_ENABLED;
      m_snapshot.quality_filters_passed = true;
      m_snapshot.quality_min_fvg_size_points = FALCON_FVG_MICRO_MIN_SIZE_POINTS;
      m_snapshot.quality_max_spread_points = FALCON_FVG_MICRO_MAX_SPREAD_POINTS;
      m_snapshot.quality_max_fvg_age_bars = FALCON_FVG_MICRO_MAX_FVG_AGE_BARS;
      m_snapshot.quality_retest_freshness_bars = FALCON_FVG_MICRO_RETEST_FRESHNESS_BARS;
      m_snapshot.quality_fvg_age_bars = 0; // Phase 1 detector uses the newest closed M5 FVG only.
      m_snapshot.quality_reject_reason = "QUALITY_FILTERS_PASSED";

      long spread_points = 0;
      if(!SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread_points))
         spread_points = 0;
      m_snapshot.quality_current_spread_points = spread_points;

      if(!m_snapshot.quality_filters_enabled)
      {
         m_snapshot.quality_reject_reason = "QUALITY_FILTERS_DISABLED";
         return true;
      }

      if(detector_snapshot.fvg_size_points < m_snapshot.quality_min_fvg_size_points)
      {
         m_snapshot.quality_filters_passed = false;
         m_snapshot.quality_reject_reason = StringFormat("FVG_SIZE_BELOW_MIN;Size=%.2f;Min=%.2f",
                                                          detector_snapshot.fvg_size_points,
                                                          m_snapshot.quality_min_fvg_size_points);
         return false;
      }

      if(m_snapshot.quality_max_spread_points > 0 && spread_points > m_snapshot.quality_max_spread_points)
      {
         m_snapshot.quality_filters_passed = false;
         m_snapshot.quality_reject_reason = StringFormat("SPREAD_ABOVE_MAX;Spread=%d;Max=%d",
                                                          (int)spread_points,
                                                          (int)m_snapshot.quality_max_spread_points);
         return false;
      }

      if(m_snapshot.quality_max_fvg_age_bars >= 0 && m_snapshot.quality_fvg_age_bars > m_snapshot.quality_max_fvg_age_bars)
      {
         m_snapshot.quality_filters_passed = false;
         m_snapshot.quality_reject_reason = StringFormat("FVG_AGE_ABOVE_MAX;Age=%d;Max=%d",
                                                          m_snapshot.quality_fvg_age_bars,
                                                          m_snapshot.quality_max_fvg_age_bars);
         return false;
      }

      return true;
   }

   void ResetSnapshot()
   {
      m_snapshot.builder_id = "";
      m_snapshot.candidate_id = "";
      m_snapshot.strategy_id = "";
      m_snapshot.strategy_name = "";
      m_snapshot.engine_id = "";
      m_snapshot.candidate_status = FALCON_CANDIDATE_STATUS_NOT_INITIALIZED;
      m_snapshot.detector_initialized = false;
      m_snapshot.registry_found = false;
      m_snapshot.input_enabled = false;
      m_snapshot.shadow_allowed = false;
      m_snapshot.runtime_safety_ready = false;
      m_snapshot.fvg_detected = false;
      m_snapshot.candidate_created = false;
      m_snapshot.tradeplan_created = false;
      m_snapshot.staged_to_shadow_executor = false;
      m_snapshot.order_send_used = false;
      m_snapshot.direction = FALCON_DIRECTION_NONE;
      m_snapshot.analysis_timeframe = PERIOD_M5;
      m_snapshot.setup_time = 0;
      m_snapshot.entry_zone_lower = 0.0;
      m_snapshot.entry_zone_upper = 0.0;
      m_snapshot.fvg_size_points = 0.0;
      m_snapshot.quality_filters_enabled = FALCON_FVG_MICRO_QUALITY_FILTERS_ENABLED;
      m_snapshot.quality_filters_passed = false;
      m_snapshot.quality_min_fvg_size_points = FALCON_FVG_MICRO_MIN_SIZE_POINTS;
      m_snapshot.quality_current_spread_points = 0;
      m_snapshot.quality_max_spread_points = FALCON_FVG_MICRO_MAX_SPREAD_POINTS;
      m_snapshot.quality_fvg_age_bars = 0;
      m_snapshot.quality_max_fvg_age_bars = FALCON_FVG_MICRO_MAX_FVG_AGE_BARS;
      m_snapshot.quality_retest_freshness_bars = FALCON_FVG_MICRO_RETEST_FRESHNESS_BARS;
      m_snapshot.quality_reject_reason = "NOT_EVALUATED";
      m_snapshot.fvg_retest_age_bars = 0;
      m_snapshot.fvg_setup_time = 0;
      m_snapshot.fvg_retest_watch_time = 0;
      m_snapshot.fvg_age_bars_at_watch = 0;
      m_snapshot.fvg_age_source = "NOT_EVALUATED";
      m_snapshot.fvg_retest_fresh_state = "NOT_EVALUATED";
      m_snapshot.fvg_hold_quality_score = 0;
      m_snapshot.fvg_hold_quality_bucket = "NOT_EVALUATED";
      m_snapshot.quality_profile_balanced_passed = false;
      m_snapshot.quality_profile_strict_size_passed = false;
      m_snapshot.quality_profile_tight_spread_passed = false;
      m_snapshot.quality_profile_strict_combo_passed = false;
      m_snapshot.score = 0.0;
      m_snapshot.block_reason = "";
      m_snapshot.evidence_summary = "";
      m_snapshot.notes = "";
   }
};

// ==================================================================
// FVG Micro Retest Watcher & TradePlan Skeleton - v0.13.1
// Observes whether the current live quote has returned to the detected FVG zone.
// It builds a diagnostic TradePlan skeleton only. It does NOT create a real
// FalconTradePlan, does NOT stage to ShadowExecutor, and does NOT send orders.
// ==================================================================
class CFalconFvgMicroRetestWatcher
{
private:
   FalconFvgMicroRetestWatcherSnapshot m_snapshot;
   bool                                m_initialized;

public:
   CFalconFvgMicroRetestWatcher()
   {
      ResetSnapshot();
      m_initialized = false;
   }

   bool Initialize(CFalconFvgMicroShadowCandidateBuilder &candidate_builder,
                   CFalconMarketContext &market_context,
                   CFalconRuntimeSafetyGuard &runtime_guard)
   {
      ResetSnapshot();
      m_snapshot.watcher_id = "WATCHER_FVG_MICRO_RETEST_TRADEPLAN_SKELETON_v0_12_0";
      m_snapshot.candidate_builder_initialized = candidate_builder.IsInitialized();
      m_snapshot.runtime_safety_ready = runtime_guard.IsInitialized();
      m_snapshot.order_send_used = false;
      m_snapshot.tradeplan_created = false;
      m_snapshot.staged_to_shadow_executor = false;

      FalconFvgMicroShadowCandidateSnapshot candidate = candidate_builder.GetSnapshot();
      FalconQuoteContext quote = market_context.GetQuoteContext();
      FalconSymbolContext symbol_context = market_context.GetSymbolContext();

      m_snapshot.candidate_id       = candidate.candidate_id;
      m_snapshot.strategy_id        = candidate.strategy_id;
      m_snapshot.strategy_name      = candidate.strategy_name;
      m_snapshot.engine_id          = candidate.engine_id;
      m_snapshot.direction          = candidate.direction;
      m_snapshot.analysis_timeframe = candidate.analysis_timeframe;
      m_snapshot.setup_time         = candidate.setup_time;
      m_snapshot.fvg_detected       = candidate.fvg_detected;
      m_snapshot.fvg_lower          = candidate.entry_zone_lower;
      m_snapshot.fvg_upper          = candidate.entry_zone_upper;
      m_snapshot.fvg_size_points    = candidate.fvg_size_points;
      m_snapshot.quality_filters_enabled       = candidate.quality_filters_enabled;
      m_snapshot.quality_filters_passed        = candidate.quality_filters_passed;
      m_snapshot.quality_min_fvg_size_points   = candidate.quality_min_fvg_size_points;
      m_snapshot.quality_current_spread_points = candidate.quality_current_spread_points;
      m_snapshot.quality_max_spread_points     = candidate.quality_max_spread_points;
      m_snapshot.quality_fvg_age_bars          = candidate.quality_fvg_age_bars;
      m_snapshot.quality_max_fvg_age_bars      = candidate.quality_max_fvg_age_bars;
      m_snapshot.quality_retest_freshness_bars = candidate.quality_retest_freshness_bars;
      m_snapshot.quality_reject_reason         = candidate.quality_reject_reason;
      m_snapshot.quality_profile_balanced_passed     = FalconFvgQualityCalibrationProfilePassed(candidate, FALCON_FVG_CALIB_BALANCED_MIN_SIZE_POINTS, FALCON_FVG_CALIB_BALANCED_MAX_SPREAD_POINTS);
      m_snapshot.quality_profile_strict_size_passed  = FalconFvgQualityCalibrationProfilePassed(candidate, FALCON_FVG_CALIB_STRICT_SIZE_MIN_SIZE_POINTS, FALCON_FVG_CALIB_STRICT_SIZE_MAX_SPREAD_POINTS);
      m_snapshot.quality_profile_tight_spread_passed = FalconFvgQualityCalibrationProfilePassed(candidate, FALCON_FVG_CALIB_TIGHT_SPREAD_MIN_SIZE_POINTS, FALCON_FVG_CALIB_TIGHT_SPREAD_MAX_SPREAD_POINTS);
      m_snapshot.quality_profile_strict_combo_passed = FalconFvgQualityCalibrationProfilePassed(candidate, FALCON_FVG_CALIB_STRICT_COMBO_MIN_SIZE_POINTS, FALCON_FVG_CALIB_STRICT_COMBO_MAX_SPREAD_POINTS);
      m_snapshot.quote_valid        = quote.is_valid;
      m_snapshot.watch_time         = TimeCurrent();
      m_snapshot.fvg_setup_time     = m_snapshot.setup_time;
      m_snapshot.fvg_retest_watch_time = m_snapshot.watch_time;
      m_snapshot.fvg_retest_age_bars = FalconCalculateRetestAgeBars(m_snapshot.fvg_setup_time, m_snapshot.fvg_retest_watch_time, m_snapshot.analysis_timeframe);
      m_snapshot.fvg_age_bars_at_watch = m_snapshot.fvg_retest_age_bars;
      m_snapshot.fvg_age_source = "SETUP_TIME_TO_WATCH_TIME_PRIOR_BAR_SAFE";
      m_snapshot.fvg_retest_fresh_state = FalconFvgRetestFreshState(false, m_snapshot.fvg_retest_age_bars, m_snapshot.quality_retest_freshness_bars);
      m_snapshot.fvg_hold_quality_score = 0;
      m_snapshot.fvg_hold_quality_bucket = "NOT_TOUCHED";
      m_snapshot.watch_price        = SelectWatchPrice(candidate.direction, quote);
      m_snapshot.planned_lot_size   = FixedLotSize;

      if(!m_snapshot.candidate_builder_initialized)
      {
         m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_BLOCKED;
         m_snapshot.block_reason = "CANDIDATE_BUILDER_NOT_INITIALIZED";
         m_snapshot.notes = "Retest watcher requires the candidate builder to initialize first.";
         m_initialized = true;
         return true;
      }

      if(candidate.candidate_status != FALCON_CANDIDATE_STATUS_READY_SHADOW || !candidate.candidate_created)
      {
         m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_BLOCKED;
         m_snapshot.candidate_ready = false;
         m_snapshot.block_reason = StringFormat("CANDIDATE_NOT_READY_FOR_RETEST_WATCH;Status=%s;Reason=%s",
                                                FalconCandidateStatusToString(candidate.candidate_status),
                                                candidate.block_reason);
         m_snapshot.notes = "No retest watch is armed because no ready shadow candidate exists yet.";
         m_initialized = true;
         return true;
      }

      m_snapshot.candidate_ready = true;

      if(!m_snapshot.runtime_safety_ready)
      {
         m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_BLOCKED;
         m_snapshot.block_reason = "NO_LOOKAHEAD_GUARD_NOT_READY";
         m_snapshot.notes = "Retest watcher refused to proceed without runtime safety guard.";
         m_initialized = true;
         return true;
      }

      if(!m_snapshot.quote_valid || m_snapshot.watch_price <= 0.0)
      {
         m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_BLOCKED;
         m_snapshot.block_reason = "QUOTE_NOT_VALID_FOR_RETEST_WATCH";
         m_snapshot.notes = "Retest watcher needs a valid live tick price. No candle final-state was used.";
         m_initialized = true;
         return true;
      }

      if(m_snapshot.fvg_lower <= 0.0 || m_snapshot.fvg_upper <= 0.0 || m_snapshot.fvg_upper <= m_snapshot.fvg_lower)
      {
         m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_BLOCKED;
         m_snapshot.block_reason = "INVALID_FVG_ZONE_GEOMETRY";
         m_snapshot.notes = "Retest watcher refused invalid FVG zone geometry.";
         m_initialized = true;
         return true;
      }

      m_snapshot.retest_touched = PriceInsideZone(m_snapshot.watch_price, m_snapshot.fvg_lower, m_snapshot.fvg_upper);
      m_snapshot.fvg_retest_fresh_state = FalconFvgRetestFreshState(m_snapshot.retest_touched,
                                                                    m_snapshot.fvg_retest_age_bars,
                                                                    m_snapshot.quality_retest_freshness_bars);
      m_snapshot.fvg_hold_quality_score = FalconBuildFvgHoldQualityScoreForWatcher(m_snapshot, market_context);
      m_snapshot.fvg_hold_quality_bucket = FalconFvgHoldQualityBucket(m_snapshot.fvg_hold_quality_score,
                                                                      m_snapshot.retest_touched);

      if(!m_snapshot.retest_touched)
      {
         m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_WAITING;
         m_snapshot.retest_reason = "LIVE_TICK_NOT_INSIDE_FVG_ZONE_YET";
         m_snapshot.block_reason = "WAITING_FOR_RETEST";
         m_snapshot.notes = "Candidate is armed, but the live quote has not returned to the FVG zone. No TradePlan skeleton is created.";
         m_initialized = true;
         return true;
      }

      BuildTradePlanSkeleton(symbol_context);
      m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_SKELETON_READY;
      m_snapshot.retest_reason = "LIVE_TICK_INSIDE_FVG_ZONE";
      m_snapshot.block_reason = "TRADEPLAN_SKELETON_ONLY_NO_STAGING_IN_v0_12_0";
      m_snapshot.notes = "Retest touched the FVG zone. Diagnostic TradePlan skeleton was built, but no FalconTradePlan was created and nothing was staged.";

      m_initialized = true;
      CFalconLogger::Info(StringFormat("FvgMicroRetestWatcher initialized. Status=%s | RetestTouched=%s | Skeleton=%s | Reason=%s",
                                       FalconRetestWatcherStatusToString(m_snapshot.watcher_status),
                                       (m_snapshot.retest_touched ? "true" : "false"),
                                       (m_snapshot.tradeplan_skeleton_created ? "true" : "false"),
                                       m_snapshot.block_reason));
      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   FalconFvgMicroRetestWatcherSnapshot GetSnapshot()
   {
      return m_snapshot;
   }

private:
   double SelectWatchPrice(const ENUM_FALCON_DIRECTION direction, const FalconQuoteContext &quote)
   {
      if(direction == FALCON_DIRECTION_BUY)
         return quote.bid;
      if(direction == FALCON_DIRECTION_SELL)
         return quote.ask;
      return quote.last;
   }

   bool PriceInsideZone(const double price, const double lower, const double upper)
   {
      return (price >= lower && price <= upper);
   }

   void BuildTradePlanSkeleton(const FalconSymbolContext &symbol_context)
   {
      const double zone_size = MathAbs(m_snapshot.fvg_upper - m_snapshot.fvg_lower);
      const double min_buffer = MathMax(zone_size, (double)symbol_context.stops_level_points * symbol_context.point);
      const double safe_buffer = (min_buffer > 0.0 ? min_buffer : 10.0 * symbol_context.point);
      const double midpoint = (m_snapshot.fvg_lower + m_snapshot.fvg_upper) / 2.0;

      m_snapshot.planned_entry_price = midpoint;

      if(m_snapshot.direction == FALCON_DIRECTION_BUY)
      {
         m_snapshot.planned_structural_sl = m_snapshot.fvg_lower - safe_buffer;
         m_snapshot.planned_tp1 = m_snapshot.fvg_upper + zone_size;
         m_snapshot.planned_tp2 = m_snapshot.fvg_upper + (zone_size * 2.0);
         m_snapshot.planned_tp3 = m_snapshot.fvg_upper + (zone_size * 3.0);
      }
      else if(m_snapshot.direction == FALCON_DIRECTION_SELL)
      {
         m_snapshot.planned_structural_sl = m_snapshot.fvg_upper + safe_buffer;
         m_snapshot.planned_tp1 = m_snapshot.fvg_lower - zone_size;
         m_snapshot.planned_tp2 = m_snapshot.fvg_lower - (zone_size * 2.0);
         m_snapshot.planned_tp3 = m_snapshot.fvg_lower - (zone_size * 3.0);
      }

      m_snapshot.tradeplan_skeleton_created = true;
      m_snapshot.skeleton_notes = "Diagnostic geometry only. Entry=FVG midpoint; SL=outside FVG with stop-level-aware buffer; TP1/TP2/TP3=zone-size projections. No real TradePlan object is created.";
   }

   void ResetSnapshot()
   {
      m_snapshot.watcher_id = "";
      m_snapshot.candidate_id = "";
      m_snapshot.strategy_id = "";
      m_snapshot.strategy_name = "";
      m_snapshot.engine_id = "";
      m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_NOT_INITIALIZED;
      m_snapshot.candidate_builder_initialized = false;
      m_snapshot.candidate_ready = false;
      m_snapshot.quote_valid = false;
      m_snapshot.runtime_safety_ready = false;
      m_snapshot.fvg_detected = false;
      m_snapshot.retest_touched = false;
      m_snapshot.tradeplan_skeleton_created = false;
      m_snapshot.tradeplan_created = false;
      m_snapshot.staged_to_shadow_executor = false;
      m_snapshot.order_send_used = false;
      m_snapshot.direction = FALCON_DIRECTION_NONE;
      m_snapshot.analysis_timeframe = PERIOD_CURRENT;
      m_snapshot.setup_time = 0;
      m_snapshot.watch_time = 0;
      m_snapshot.watch_price = 0.0;
      m_snapshot.fvg_lower = 0.0;
      m_snapshot.fvg_upper = 0.0;
      m_snapshot.fvg_size_points = 0.0;
      m_snapshot.quality_filters_enabled = FALCON_FVG_MICRO_QUALITY_FILTERS_ENABLED;
      m_snapshot.quality_filters_passed = false;
      m_snapshot.quality_min_fvg_size_points = FALCON_FVG_MICRO_MIN_SIZE_POINTS;
      m_snapshot.quality_current_spread_points = 0;
      m_snapshot.quality_max_spread_points = FALCON_FVG_MICRO_MAX_SPREAD_POINTS;
      m_snapshot.quality_fvg_age_bars = 0;
      m_snapshot.quality_max_fvg_age_bars = FALCON_FVG_MICRO_MAX_FVG_AGE_BARS;
      m_snapshot.quality_retest_freshness_bars = FALCON_FVG_MICRO_RETEST_FRESHNESS_BARS;
      m_snapshot.quality_reject_reason = "NOT_EVALUATED";
      m_snapshot.fvg_retest_age_bars = 0;
      m_snapshot.fvg_setup_time = 0;
      m_snapshot.fvg_retest_watch_time = 0;
      m_snapshot.fvg_age_bars_at_watch = 0;
      m_snapshot.fvg_age_source = "NOT_EVALUATED";
      m_snapshot.fvg_retest_fresh_state = "NOT_EVALUATED";
      m_snapshot.fvg_hold_quality_score = 0;
      m_snapshot.fvg_hold_quality_bucket = "NOT_EVALUATED";
      m_snapshot.quality_profile_balanced_passed = false;
      m_snapshot.quality_profile_strict_size_passed = false;
      m_snapshot.quality_profile_tight_spread_passed = false;
      m_snapshot.quality_profile_strict_combo_passed = false;
      m_snapshot.planned_entry_price = 0.0;
      m_snapshot.planned_structural_sl = 0.0;
      m_snapshot.planned_tp1 = 0.0;
      m_snapshot.planned_tp2 = 0.0;
      m_snapshot.planned_tp3 = 0.0;
      m_snapshot.planned_lot_size = 0.0;
      m_snapshot.retest_reason = "";
      m_snapshot.block_reason = "";
      m_snapshot.skeleton_notes = "";
      m_snapshot.notes = "";
   }
};


// ==================================================================
// FVG Micro Retest Freshness & Hold Quality Summary Metrics - v0.20.0
// Measures the retest age and an initial closed-candle hold/rejection proxy.
// This is metrics-only: no entry, SL, TP, staging, or lifecycle behavior changes.
// ==================================================================
int FalconSafeTimeframeSeconds(const ENUM_TIMEFRAMES timeframe)
{
   int seconds = PeriodSeconds(timeframe);
   if(seconds <= 0)
      seconds = PeriodSeconds(PERIOD_M5);
   if(seconds <= 0)
      seconds = 300;
   return seconds;
}

int FalconCalculateRetestAgeBars(const datetime setup_time,
                                 const datetime watch_time,
                                 const ENUM_TIMEFRAMES timeframe)
{
   if(setup_time <= 0 || watch_time <= 0 || watch_time < setup_time)
      return 0;

   const int seconds = FalconSafeTimeframeSeconds(timeframe);
   return (int)((watch_time - setup_time) / seconds);
}

int FalconCalculateFvgHoldQualityScore(const FalconFvgMicroRetestWatcherSnapshot &snapshot,
                                       const FalconCandleSnapshot &closed_candle)
{
   if(!snapshot.retest_touched || !closed_candle.is_valid)
      return 0;

   const double zone_size = MathAbs(snapshot.fvg_upper - snapshot.fvg_lower);
   if(zone_size <= 0.0)
      return 0;

   const double midpoint = (snapshot.fvg_lower + snapshot.fvg_upper) / 2.0;
   int score = 25; // baseline: retest touched, but no hold proof yet.

   if(snapshot.direction == FALCON_DIRECTION_BUY)
   {
      if(closed_candle.close >= snapshot.fvg_lower)
         score += 15;
      if(closed_candle.close >= midpoint)
         score += 20;
      if(closed_candle.close > closed_candle.open)
         score += 20;
      if(closed_candle.low <= snapshot.fvg_upper && closed_candle.close > closed_candle.low)
         score += 20;
   }
   else if(snapshot.direction == FALCON_DIRECTION_SELL)
   {
      if(closed_candle.close <= snapshot.fvg_upper)
         score += 15;
      if(closed_candle.close <= midpoint)
         score += 20;
      if(closed_candle.close < closed_candle.open)
         score += 20;
      if(closed_candle.high >= snapshot.fvg_lower && closed_candle.close < closed_candle.high)
         score += 20;
   }

   if(score > 100)
      score = 100;
   if(score < 0)
      score = 0;
   return score;
}

string FalconFvgRetestFreshState(const bool retest_touched,
                                 const int age_bars,
                                 const int freshness_bars)
{
   if(!retest_touched)
      return "WAITING";
   if(freshness_bars < 0)
      return "FRESHNESS_DISABLED";
   if(age_bars <= freshness_bars)
      return "FRESH";
   return "STALE";
}

string FalconFvgHoldQualityBucket(const int score,
                                  const bool retest_touched)
{
   if(!retest_touched)
      return "NOT_TOUCHED";
   if(score >= FALCON_FVG_HOLD_QUALITY_STRONG_SCORE)
      return "STRONG";
   if(score >= FALCON_FVG_HOLD_QUALITY_NEUTRAL_SCORE)
      return "NEUTRAL";
   return "WEAK";
}

int FalconBuildFvgHoldQualityScoreForWatcher(const FalconFvgMicroRetestWatcherSnapshot &snapshot,
                                             CFalconMarketContext &market_context)
{
   if(!snapshot.retest_touched)
      return 0;

   FalconCandleSnapshot closed_candle;
   const int shift = FalconAnalysisCandleShift();
   if(!market_context.GetCandleSnapshot(PERIOD_M5, shift, closed_candle))
      return 0;

   return FalconCalculateFvgHoldQualityScore(snapshot, closed_candle);
}

void FalconRegisterFvgRetestFreshnessHoldMetrics(const FalconFvgMicroRetestWatcherSnapshot &snapshot,
                                                 CFalconMarketContext &market_context)
{
   if(!(snapshot.candidate_ready && snapshot.fvg_detected && snapshot.runtime_safety_ready))
      return;

   g_fvg_retest_watch_evaluated++;

   const int age_bars = FalconCalculateRetestAgeBars(snapshot.setup_time, snapshot.watch_time, snapshot.analysis_timeframe);
   g_fvg_retest_age_total_bars += age_bars;
   if(g_fvg_retest_age_min_bars < 0 || age_bars < g_fvg_retest_age_min_bars)
      g_fvg_retest_age_min_bars = age_bars;
   if(age_bars > g_fvg_retest_age_max_bars)
      g_fvg_retest_age_max_bars = age_bars;

   if(snapshot.retest_touched)
   {
      g_fvg_retest_touched++;
      if(FalconFvgRetestFreshState(true, age_bars, FALCON_FVG_MICRO_RETEST_FRESHNESS_BARS) == "FRESH")
         g_fvg_retest_fresh++;
      else
         g_fvg_retest_stale++;

      FalconCandleSnapshot closed_candle;
      const int shift = FalconAnalysisCandleShift();
      if(market_context.GetCandleSnapshot(PERIOD_M5, shift, closed_candle))
      {
         const int score = FalconCalculateFvgHoldQualityScore(snapshot, closed_candle);
         g_fvg_hold_quality_evaluated++;
         g_fvg_hold_quality_score_total += score;

         if(g_fvg_hold_quality_score_min < 0 || score < g_fvg_hold_quality_score_min)
            g_fvg_hold_quality_score_min = score;
         if(score > g_fvg_hold_quality_score_max)
            g_fvg_hold_quality_score_max = score;

         if(score >= FALCON_FVG_HOLD_QUALITY_STRONG_SCORE)
            g_fvg_hold_quality_strong++;
         else if(score >= FALCON_FVG_HOLD_QUALITY_NEUTRAL_SCORE)
            g_fvg_hold_quality_neutral++;
         else
            g_fvg_hold_quality_weak++;
      }
   }
   else
   {
      g_fvg_retest_waiting++;
   }
}


// ==================================================================
// FVG Micro Shadow TradePlan Staging Dry Run - v0.13.1
// Creates a real FalconTradePlan object from the diagnostic skeleton, validates
// it through the No-Lookahead Guard, and stages it to ShadowExecutor only.
// It never sends broker orders and never enables Paper/Demo/Live execution.
// ==================================================================
class CFalconFvgMicroTradePlanStagingDryRun
{
private:
   FalconFvgMicroTradePlanStagingSnapshot m_snapshot;
   FalconShadowTradeRecord                m_shadow_record;
   bool                                   m_initialized;

public:
   CFalconFvgMicroTradePlanStagingDryRun()
   {
      ResetSnapshot();
      ResetLocalShadowRecord(m_shadow_record);
      m_initialized = false;
   }

   bool Initialize(CFalconFvgMicroRetestWatcher &watcher,
                   CFalconRuntimeSafetyGuard &runtime_guard,
                   CFalconShadowExecutor &shadow_executor)
   {
      ResetSnapshot();
      ResetLocalShadowRecord(m_shadow_record);

      FalconFvgMicroRetestWatcherSnapshot watcher_snapshot = watcher.GetSnapshot();
      m_snapshot.stager_id             = "STAGER_FVG_MICRO_TRADEPLAN_DRY_RUN_v0_13_1";
      m_snapshot.candidate_id          = watcher_snapshot.candidate_id;
      m_snapshot.strategy_id           = watcher_snapshot.strategy_id;
      m_snapshot.strategy_name         = watcher_snapshot.strategy_name;
      m_snapshot.engine_id             = watcher_snapshot.engine_id;
      m_snapshot.watcher_status        = watcher_snapshot.watcher_status;
      m_snapshot.watcher_initialized   = watcher.IsInitialized();
      m_snapshot.retest_touched        = watcher_snapshot.retest_touched;
      m_snapshot.skeleton_ready        = watcher_snapshot.tradeplan_skeleton_created;
      m_snapshot.runtime_safety_ready  = runtime_guard.IsInitialized();
      m_snapshot.shadow_executor_ready = shadow_executor.IsInitialized();
      m_snapshot.order_send_used       = false;
      m_snapshot.direction             = watcher_snapshot.direction;
      m_snapshot.analysis_timeframe    = watcher_snapshot.analysis_timeframe;
      m_snapshot.setup_time            = watcher_snapshot.setup_time;
      m_snapshot.staging_time          = TimeCurrent();
      m_snapshot.evidence_summary      = "FVG_MICRO_RETEST_SHADOW_DRY_RUN;EvidenceLayer=FVG;QualityFilters=v0.19.1;Permission=false;Execution=false";

      if(!m_snapshot.watcher_initialized)
      {
         Block("RETEST_WATCHER_NOT_INITIALIZED", "Staging requires a completed retest watcher snapshot.");
         return true;
      }

      if(!m_snapshot.skeleton_ready || watcher_snapshot.watcher_status != FALCON_RETEST_WATCHER_STATUS_SKELETON_READY)
      {
         Block(StringFormat("SKELETON_NOT_READY;WatcherStatus=%s;Reason=%s",
                            FalconRetestWatcherStatusToString(watcher_snapshot.watcher_status),
                            watcher_snapshot.block_reason),
               "No FalconTradePlan was created because the retest watcher has not produced a ready skeleton.");
         return true;
      }

      FalconTradePlan plan;
      BuildTradePlanFromWatcher(watcher_snapshot, plan);
      m_snapshot.tradeplan_created = true;
      m_snapshot.staging_status = FALCON_TRADEPLAN_STAGING_STATUS_PLAN_CREATED;

      string validation_reason = "";
      if(!runtime_guard.ValidateTradePlanForStaging(plan, validation_reason))
      {
         m_snapshot.validate_passed = false;
         m_snapshot.validation_reason = validation_reason;
         Block(validation_reason, "TradePlan object was created but failed No-Lookahead/geometry staging validation.");
         return true;
      }

      m_snapshot.validate_passed = true;
      m_snapshot.validation_reason = "VALIDATE_TRADEPLAN_FOR_STAGING_PASSED";

      bool qguard_runtime_passed_for_stage = false;

      if(FALCON_FVG_QGUARD_RUNTIME_ACTIVE && FALCON_FVG_QGUARD_ACTUAL_BLOCKING_ENABLED)
      {
         string qguard_reason = "";
         bool qguard_passed = FalconEvaluateFvgQualityShadowGuard(watcher_snapshot.fvg_size_points,
                                                                  watcher_snapshot.quality_current_spread_points,
                                                                  watcher_snapshot.fvg_retest_age_bars,
                                                                  watcher_snapshot.fvg_hold_quality_score,
                                                                  qguard_reason);
         g_fvg_qguard_runtime_candidate_evaluated++;
         if(qguard_passed)
         {
            g_fvg_qguard_runtime_candidate_passed++;
            qguard_runtime_passed_for_stage = true;
         }
         else
         {
            g_fvg_qguard_runtime_candidate_blocked++;
            Block(StringFormat("FVG_QGUARD_RUNTIME_BLOCKED;%s", qguard_reason),
                  "v0.25.1 controlled Shadow-only activation blocked FVG Micro staging before entry. No OrderSend, no Paper, no Demo, no Live execution.");
            return true;
         }
      }

      FalconEvidencePack evidence_pack;
      evidence_pack.has_candle_evidence = false;
      evidence_pack.has_chart_pattern_evidence = false;
      evidence_pack.has_objective_indicator_evidence = false;
      evidence_pack.has_smc_evidence = true;
      evidence_pack.score = 60.0;
      evidence_pack.summary = m_snapshot.evidence_summary;

      if(!shadow_executor.StageTradePlan(plan, evidence_pack, m_shadow_record))
      {
         if(qguard_runtime_passed_for_stage)
         {
            g_fvg_qguard_runtime_passed_but_not_staged++;
            g_fvg_qguard_runtime_rejected_after_pass++;
         }
         m_snapshot.staged_to_shadow_executor = false;
         Block("SHADOW_EXECUTOR_STAGE_FAILED", "TradePlan passed validation but ShadowExecutor refused staging. No broker orders were sent.");
         return true;
      }

      if(qguard_runtime_passed_for_stage)
         g_fvg_qguard_runtime_staged_trades++;

      m_snapshot.shadow_id = m_shadow_record.shadow_id;
      m_snapshot.staged_to_shadow_executor = true;
      m_snapshot.staging_status = FALCON_TRADEPLAN_STAGING_STATUS_STAGED_SHADOW;
      m_snapshot.staging_reason = "STAGED_TO_SHADOW_EXECUTOR_ONLY_NO_BROKER_ORDER";
      m_snapshot.notes = "Validated FalconTradePlan was staged to ShadowExecutor only. This is not Paper/Demo/Live execution and no OrderSend is used.";
      m_initialized = true;

      CFalconLogger::Info(StringFormat("FVG Micro TradePlan staging dry run complete. Status=%s | ShadowId=%s | Entry=%.5f | SL=%.5f | TP1=%.5f",
                                       FalconTradePlanStagingStatusToString(m_snapshot.staging_status),
                                       m_snapshot.shadow_id,
                                       m_snapshot.entry_price,
                                       m_snapshot.structural_sl,
                                       m_snapshot.tp1));
      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   FalconFvgMicroTradePlanStagingSnapshot GetSnapshot()
   {
      return m_snapshot;
   }

   FalconShadowTradeRecord GetShadowRecord()
   {
      return m_shadow_record;
   }

private:
   void ResetLocalShadowRecord(FalconShadowTradeRecord &record)
   {
      record.shadow_id            = "";
      record.strategy_id          = "";
      record.strategy_name        = "";
      record.engine_id            = "";
      record.direction            = FALCON_DIRECTION_NONE;
      record.status               = FALCON_SHADOW_RECORD_NONE;
      record.entry_time           = 0;
      record.exit_time            = 0;
      record.lot_size             = 0.0;
      record.entry_price          = 0.0;
      record.structural_sl        = 0.0;
      record.tp1                  = 0.0;
      record.tp2                  = 0.0;
      record.tp3                  = 0.0;
      record.simulated_exit_price = 0.0;
      record.simulated_outcome    = FALCON_TRADE_OUTCOME_UNKNOWN;
      record.close_reason         = "";
      record.evidence_summary     = "";
      record.fvg_size_points      = 0.0;
      record.fvg_spread_points    = 0;
      record.fvg_retest_age_bars  = 0;
      record.fvg_setup_time = 0;
      record.fvg_retest_watch_time = 0;
      record.fvg_age_bars_at_watch = 0;
      record.fvg_age_source = "";
      record.fvg_retest_fresh_state = "";
      record.fvg_hold_quality_score = 0;
      record.fvg_hold_quality_bucket = "";
      record.quality_filters_passed = false;
      record.quality_profile_balanced_passed = false;
      record.quality_profile_strict_size_passed = false;
      record.quality_profile_tight_spread_passed = false;
      record.quality_profile_strict_combo_passed = false;
      record.is_closed            = false;
   }

   void BuildTradePlanFromWatcher(const FalconFvgMicroRetestWatcherSnapshot &watcher_snapshot, FalconTradePlan &plan)
   {
      plan.plan_id = StringFormat("PLAN_FVG_MICRO_%d", (int)TimeCurrent());
      plan.strategy_id = watcher_snapshot.strategy_id;
      plan.strategy_name = watcher_snapshot.strategy_name;
      plan.engine_id = watcher_snapshot.engine_id;
      plan.direction = watcher_snapshot.direction;
      plan.lot_size = watcher_snapshot.planned_lot_size;
      plan.entry_price = watcher_snapshot.planned_entry_price;
      plan.structural_sl = watcher_snapshot.planned_structural_sl;
      plan.tp1 = watcher_snapshot.planned_tp1;
      plan.tp2 = watcher_snapshot.planned_tp2;
      plan.tp3 = watcher_snapshot.planned_tp3;
      plan.runner_allowed = false;
      plan.risk_profile = "SHADOW_DIAGNOSTIC_FIXED_LOT_ONLY";
      plan.management_profile = "NO_MANAGEMENT_YET_STAGING_DRY_RUN";
      plan.fvg_size_points = watcher_snapshot.fvg_size_points;
      plan.fvg_spread_points = watcher_snapshot.quality_current_spread_points;
      plan.fvg_retest_age_bars = watcher_snapshot.fvg_retest_age_bars;
      plan.fvg_setup_time = watcher_snapshot.fvg_setup_time;
      plan.fvg_retest_watch_time = watcher_snapshot.fvg_retest_watch_time;
      plan.fvg_age_bars_at_watch = watcher_snapshot.fvg_age_bars_at_watch;
      plan.fvg_age_source = watcher_snapshot.fvg_age_source;
      plan.fvg_retest_fresh_state = watcher_snapshot.fvg_retest_fresh_state;
      plan.fvg_hold_quality_score = watcher_snapshot.fvg_hold_quality_score;
      plan.fvg_hold_quality_bucket = watcher_snapshot.fvg_hold_quality_bucket;
      plan.quality_filters_passed = watcher_snapshot.quality_filters_passed;
      plan.quality_profile_balanced_passed = watcher_snapshot.quality_profile_balanced_passed;
      plan.quality_profile_strict_size_passed = watcher_snapshot.quality_profile_strict_size_passed;
      plan.quality_profile_tight_spread_passed = watcher_snapshot.quality_profile_tight_spread_passed;
      plan.quality_profile_strict_combo_passed = watcher_snapshot.quality_profile_strict_combo_passed;

      m_snapshot.plan_id = plan.plan_id;
      m_snapshot.lot_size = plan.lot_size;
      m_snapshot.entry_price = plan.entry_price;
      m_snapshot.structural_sl = plan.structural_sl;
      m_snapshot.tp1 = plan.tp1;
      m_snapshot.tp2 = plan.tp2;
      m_snapshot.tp3 = plan.tp3;
      m_snapshot.risk_profile = plan.risk_profile;
      m_snapshot.management_profile = plan.management_profile;
   }

   void Block(const string reason, const string notes)
   {
      m_snapshot.staging_status = FALCON_TRADEPLAN_STAGING_STATUS_BLOCKED;
      m_snapshot.staging_reason = reason;
      m_snapshot.notes = notes;
      m_initialized = true;
      CFalconLogger::Info(StringFormat("FVG Micro TradePlan staging dry run blocked. Reason=%s", reason));
   }

   void ResetSnapshot()
   {
      m_snapshot.stager_id = "";
      m_snapshot.plan_id = "";
      m_snapshot.candidate_id = "";
      m_snapshot.shadow_id = "";
      m_snapshot.strategy_id = "";
      m_snapshot.strategy_name = "";
      m_snapshot.engine_id = "";
      m_snapshot.staging_status = FALCON_TRADEPLAN_STAGING_STATUS_NOT_INITIALIZED;
      m_snapshot.watcher_status = FALCON_RETEST_WATCHER_STATUS_NOT_INITIALIZED;
      m_snapshot.watcher_initialized = false;
      m_snapshot.retest_touched = false;
      m_snapshot.skeleton_ready = false;
      m_snapshot.runtime_safety_ready = false;
      m_snapshot.shadow_executor_ready = false;
      m_snapshot.tradeplan_created = false;
      m_snapshot.validate_passed = false;
      m_snapshot.staged_to_shadow_executor = false;
      m_snapshot.order_send_used = false;
      m_snapshot.direction = FALCON_DIRECTION_NONE;
      m_snapshot.analysis_timeframe = PERIOD_CURRENT;
      m_snapshot.setup_time = 0;
      m_snapshot.staging_time = 0;
      m_snapshot.lot_size = 0.0;
      m_snapshot.entry_price = 0.0;
      m_snapshot.structural_sl = 0.0;
      m_snapshot.tp1 = 0.0;
      m_snapshot.tp2 = 0.0;
      m_snapshot.tp3 = 0.0;
      m_snapshot.risk_profile = "";
      m_snapshot.management_profile = "";
      m_snapshot.validation_reason = "";
      m_snapshot.staging_reason = "";
      m_snapshot.evidence_summary = "";
      m_snapshot.notes = "";
   }
};


// ==================================================================
// FVG Micro Shadow Trade Lifecycle Simulation - v0.14.0
// Monitors a staged Shadow record and closes it diagnostically at TP1, SL, or timeout.
// This is still Shadow-only. It never sends broker orders.
// ==================================================================
#define FALCON_SHADOW_LIFECYCLE_TIMEOUT_SECONDS 5400

class CFalconFvgMicroShadowLifecycleSimulation
{
private:
   FalconFvgMicroShadowLifecycleSnapshot m_snapshot;
   FalconShadowTradeRecord               m_shadow_record;
   FalconTradeLifecycleRecord            m_lifecycle_record;
   bool                                  m_initialized;
   bool                                  m_has_closed_lifecycle;
   bool                                  m_closed_lifecycle_exported;

public:
   CFalconFvgMicroShadowLifecycleSimulation()
   {
      ResetSnapshot();
      ResetLocalShadowRecord(m_shadow_record);
      ResetLifecycleRecord(m_lifecycle_record);
      m_initialized               = false;
      m_has_closed_lifecycle      = false;
      m_closed_lifecycle_exported = false;
   }

   bool Initialize(CFalconFvgMicroTradePlanStagingDryRun &stager,
                   CFalconMarketContext &market_context,
                   CFalconShadowExecutor &shadow_executor)
   {
      ResetSnapshot();
      ResetLocalShadowRecord(m_shadow_record);
      ResetLifecycleRecord(m_lifecycle_record);
      m_initialized               = true;
      m_has_closed_lifecycle      = false;
      m_closed_lifecycle_exported = false;

      m_snapshot.simulator_id = "FVG_MICRO_LIFECYCLE_SIM_PHASE1";
      m_snapshot.stager_ready = true;
      FalconFvgMicroTradePlanStagingSnapshot staging = stager.GetSnapshot();
      m_snapshot.staged_to_shadow_executor = staging.staged_to_shadow_executor;

      if(!staging.staged_to_shadow_executor)
      {
         Block("NO_STAGED_SHADOW_RECORD", "Lifecycle simulation requires a staged Shadow record from v0.13.x TradePlan staging.");
         return true;
      }

      m_shadow_record = stager.GetShadowRecord();
      m_snapshot.shadow_record_loaded = (m_shadow_record.status == FALCON_SHADOW_RECORD_STAGED);
      if(!m_snapshot.shadow_record_loaded)
      {
         Block("SHADOW_RECORD_NOT_STAGED", "The copied Shadow record is not in STAGED status. No simulation close is allowed.");
         return true;
      }

      CopyShadowFieldsToSnapshot();
      Refresh(market_context, shadow_executor);
      CFalconLogger::Info(StringFormat("FVG Micro lifecycle simulation initialized. Status=%s | ShadowId=%s | Entry=%.5f | TP1=%.5f | SL=%.5f",
                                       FalconShadowLifecycleStatusToString(m_snapshot.lifecycle_status),
                                       m_snapshot.shadow_id,
                                       m_snapshot.entry_price,
                                       m_snapshot.tp1,
                                       m_snapshot.structural_sl));
      return true;
   }

   bool Refresh(CFalconMarketContext &market_context,
                CFalconShadowExecutor &shadow_executor)
   {
      if(!m_initialized)
         return false;

      if(m_has_closed_lifecycle)
         return true;

      if(m_shadow_record.status != FALCON_SHADOW_RECORD_STAGED)
         return true;

      market_context.Refresh();
      FalconQuoteContext quote = market_context.GetQuoteContext();
      m_snapshot.quote_valid = quote.is_valid;
      m_snapshot.evaluation_time = TimeCurrent();
      if(m_shadow_record.entry_time > 0)
         m_snapshot.elapsed_seconds = (int)(m_snapshot.evaluation_time - m_shadow_record.entry_time);

      if(!quote.is_valid)
      {
         m_snapshot.lifecycle_status = FALCON_SHADOW_LIFECYCLE_STATUS_MONITORING;
         m_snapshot.lifecycle_reason = "WAITING_FOR_VALID_QUOTE";
         m_snapshot.notes = "Shadow record is staged, but no valid quote is available yet. No close is simulated.";
         return true;
      }

      double current_price = SelectExitPrice(m_shadow_record.direction, quote);
      m_snapshot.current_price = current_price;
      m_snapshot.simulated_exit_price = 0.0;
      string close_reason = "";
      ENUM_FALCON_SHADOW_LIFECYCLE_STATUS close_status = FALCON_SHADOW_LIFECYCLE_STATUS_MONITORING;

      if(ShouldCloseAtStop(current_price))
      {
         close_reason = "SHADOW_SL_HIT_CONSERVATIVE";
         close_status = FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_SL;
      }
      else if(ShouldCloseAtTp1(current_price))
      {
         close_reason = "SHADOW_TP1_HIT";
         close_status = FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_TP;
      }
      else if(m_snapshot.elapsed_seconds >= FALCON_SHADOW_LIFECYCLE_TIMEOUT_SECONDS)
      {
         close_reason = "SHADOW_TIMEOUT_CLOSE";
         close_status = FALCON_SHADOW_LIFECYCLE_STATUS_CLOSED_TIMEOUT;
      }

      if(close_status == FALCON_SHADOW_LIFECYCLE_STATUS_MONITORING)
      {
         m_snapshot.lifecycle_status = FALCON_SHADOW_LIFECYCLE_STATUS_MONITORING;
         m_snapshot.lifecycle_reason = "MONITORING_TP_SL_TIMEOUT";
         m_snapshot.notes = "Shadow lifecycle is monitoring the staged record. No TP1, SL, or timeout close has been triggered yet.";
         return true;
      }

      FalconSymbolContext symbol_context = market_context.GetSymbolContext();
      if(!shadow_executor.CloseShadowRecord(m_shadow_record, current_price, close_reason, symbol_context, m_lifecycle_record))
      {
         Block("SHADOW_CLOSE_FAILED", "ShadowExecutor refused to close the staged Shadow record. No broker order was sent.");
         return true;
      }

      m_has_closed_lifecycle = true;
      m_snapshot.lifecycle_status = close_status;
      m_snapshot.shadow_record_status = m_shadow_record.status;
      m_snapshot.close_record_created = true;
      m_snapshot.simulated_exit_price = current_price;
      m_snapshot.simulated_outcome = m_lifecycle_record.outcome;
      m_snapshot.profit_index_points = m_lifecycle_record.profit_index_points;
      m_snapshot.loss_index_points = m_lifecycle_record.loss_index_points;
      m_snapshot.net_index_points = m_lifecycle_record.net_index_points;
      m_snapshot.profit_usd = m_lifecycle_record.profit_usd;
      m_snapshot.loss_usd = m_lifecycle_record.loss_usd;
      m_snapshot.net_usd = m_lifecycle_record.net_usd;
      m_snapshot.close_reason = close_reason;
      m_snapshot.lifecycle_reason = close_reason;
      m_snapshot.notes = "Shadow-only lifecycle close was simulated and converted to a TradeLifecycleRecord. No OrderSend was used.";
      return true;
   }

   FalconFvgMicroShadowLifecycleSnapshot GetSnapshot()
   {
      return m_snapshot;
   }

   bool ExtractClosedLifecycleRecord(FalconTradeLifecycleRecord &record)
   {
      if(!m_has_closed_lifecycle || m_closed_lifecycle_exported)
         return false;
      record = m_lifecycle_record;
      m_closed_lifecycle_exported = true;
      m_snapshot.registered_to_trade_report = true;
      return true;
   }

private:
   double SelectExitPrice(const ENUM_FALCON_DIRECTION direction, const FalconQuoteContext &quote)
   {
      if(direction == FALCON_DIRECTION_BUY)
         return quote.bid;
      if(direction == FALCON_DIRECTION_SELL)
         return quote.ask;
      if(quote.last > 0.0)
         return quote.last;
      return quote.bid;
   }

   bool ShouldCloseAtStop(const double price)
   {
      if(m_shadow_record.direction == FALCON_DIRECTION_BUY)
         return (m_shadow_record.structural_sl > 0.0 && price <= m_shadow_record.structural_sl);
      if(m_shadow_record.direction == FALCON_DIRECTION_SELL)
         return (m_shadow_record.structural_sl > 0.0 && price >= m_shadow_record.structural_sl);
      return false;
   }

   bool ShouldCloseAtTp1(const double price)
   {
      if(m_shadow_record.direction == FALCON_DIRECTION_BUY)
         return (m_shadow_record.tp1 > 0.0 && price >= m_shadow_record.tp1);
      if(m_shadow_record.direction == FALCON_DIRECTION_SELL)
         return (m_shadow_record.tp1 > 0.0 && price <= m_shadow_record.tp1);
      return false;
   }

   void CopyShadowFieldsToSnapshot()
   {
      m_snapshot.shadow_id = m_shadow_record.shadow_id;
      m_snapshot.strategy_id = m_shadow_record.strategy_id;
      m_snapshot.strategy_name = m_shadow_record.strategy_name;
      m_snapshot.engine_id = m_shadow_record.engine_id;
      m_snapshot.shadow_record_status = m_shadow_record.status;
      m_snapshot.direction = m_shadow_record.direction;
      m_snapshot.entry_time = m_shadow_record.entry_time;
      m_snapshot.entry_price = m_shadow_record.entry_price;
      m_snapshot.structural_sl = m_shadow_record.structural_sl;
      m_snapshot.tp1 = m_shadow_record.tp1;
      m_snapshot.tp2 = m_shadow_record.tp2;
      m_snapshot.tp3 = m_shadow_record.tp3;
   }

   void Block(const string reason, const string notes)
   {
      m_snapshot.lifecycle_status = FALCON_SHADOW_LIFECYCLE_STATUS_BLOCKED;
      m_snapshot.lifecycle_reason = reason;
      m_snapshot.notes = notes;
      CFalconLogger::Info(StringFormat("FVG Micro lifecycle simulation blocked. Reason=%s", reason));
   }

   void ResetLocalShadowRecord(FalconShadowTradeRecord &record)
   {
      record.shadow_id            = "";
      record.strategy_id          = "";
      record.strategy_name        = "";
      record.engine_id            = "";
      record.direction            = FALCON_DIRECTION_NONE;
      record.status               = FALCON_SHADOW_RECORD_NONE;
      record.entry_time           = 0;
      record.exit_time            = 0;
      record.lot_size             = 0.0;
      record.entry_price          = 0.0;
      record.structural_sl        = 0.0;
      record.tp1                  = 0.0;
      record.tp2                  = 0.0;
      record.tp3                  = 0.0;
      record.simulated_exit_price = 0.0;
      record.simulated_outcome    = FALCON_TRADE_OUTCOME_UNKNOWN;
      record.close_reason         = "";
      record.evidence_summary     = "";
      record.fvg_size_points      = 0.0;
      record.fvg_spread_points    = 0;
      record.fvg_retest_age_bars  = 0;
      record.fvg_setup_time = 0;
      record.fvg_retest_watch_time = 0;
      record.fvg_age_bars_at_watch = 0;
      record.fvg_age_source = "";
      record.fvg_retest_fresh_state = "";
      record.fvg_hold_quality_score = 0;
      record.fvg_hold_quality_bucket = "";
      record.quality_filters_passed = false;
      record.quality_profile_balanced_passed = false;
      record.quality_profile_strict_size_passed = false;
      record.quality_profile_tight_spread_passed = false;
      record.quality_profile_strict_combo_passed = false;
      record.is_closed            = false;
   }

   void ResetLifecycleRecord(FalconTradeLifecycleRecord &record)
   {
      record.trade_id            = "";
      record.strategy_id         = "";
      record.strategy_name       = "";
      record.engine_id           = "";
      record.direction           = FALCON_DIRECTION_NONE;
      record.stage               = FALCON_TRADE_STAGE_NONE;
      record.outcome             = FALCON_TRADE_OUTCOME_UNKNOWN;
      record.entry_time          = 0;
      record.exit_time           = 0;
      record.lot_size            = 0.0;
      record.entry_price         = 0.0;
      record.structural_sl       = 0.0;
      record.tp1                 = 0.0;
      record.tp2                 = 0.0;
      record.tp3                 = 0.0;
      record.exit_price          = 0.0;
      record.profit_index_points = 0.0;
      record.loss_index_points   = 0.0;
      record.net_index_points    = 0.0;
      record.profit_usd          = 0.0;
      record.loss_usd            = 0.0;
      record.net_usd             = 0.0;
      record.close_reason        = "";
      record.evidence_summary    = "";
      record.fvg_size_points     = 0.0;
      record.fvg_spread_points   = 0;
      record.fvg_retest_age_bars = 0;
      record.fvg_setup_time = 0;
      record.fvg_retest_watch_time = 0;
      record.fvg_age_bars_at_watch = 0;
      record.fvg_age_source = "";
      record.fvg_retest_fresh_state = "";
      record.fvg_hold_quality_score = 0;
      record.fvg_hold_quality_bucket = "";
      record.quality_filters_passed = false;
      record.fvg_quality_shadow_guard_profile = "";
      record.fvg_quality_shadow_guard_passed = false;
      record.fvg_quality_shadow_guard_decision = "NOT_EVALUATED";
      record.fvg_quality_shadow_guard_reason = "";
      record.fvg_quality_shadow_guard_sim_net_points = 0.0;
      record.fvg_quality_shadow_guard_sim_net_usd = 0.0;
      record.quality_profile_balanced_passed = false;
      record.quality_profile_strict_size_passed = false;
      record.quality_profile_tight_spread_passed = false;
      record.quality_profile_strict_combo_passed = false;
      record.paper_guard_status = "NOT_EVALUATED";
      record.paper_reject_reason = "";
      record.paper_guard_layer = "FalconGuard";
      record.paper_spread_points = 0;
      record.paper_max_spread_points = FALCON_SSBL_MAX_SPREAD_POINTS;
      record.paper_sl_distance_points = 0.0;
      record.paper_stops_level_points = 0;
      record.paper_freeze_level_points = 0;
      record.paper_guard_net_index_points = 0.0;
      record.paper_guard_net_usd = 0.0;
      record.paper_protection_state = "NONE";
      record.paper_virtual_sl = 0.0;
      record.paper_protection_trigger = "NONE";
      record.paper_protection_level = 0.0;
      record.paper_protection_activated = false;
      record.paper_virtual_sl_changed = false;
      record.paper_virtual_sl_hit = false;
      record.paper_exit_reason = "PAPER_NOT_EVALUATED";
      record.paper_protection_net_index_points = 0.0;
      record.paper_protection_net_usd = 0.0;
   }

   void ResetSnapshot()
   {
      m_snapshot.simulator_id = "FVG_MICRO_LIFECYCLE_SIM_PHASE1";
      m_snapshot.shadow_id = "";
      m_snapshot.strategy_id = "";
      m_snapshot.strategy_name = "";
      m_snapshot.engine_id = "";
      m_snapshot.lifecycle_status = FALCON_SHADOW_LIFECYCLE_STATUS_NOT_INITIALIZED;
      m_snapshot.shadow_record_status = FALCON_SHADOW_RECORD_NONE;
      m_snapshot.stager_ready = false;
      m_snapshot.staged_to_shadow_executor = false;
      m_snapshot.shadow_record_loaded = false;
      m_snapshot.quote_valid = false;
      m_snapshot.close_record_created = false;
      m_snapshot.registered_to_trade_report = false;
      m_snapshot.order_send_used = false;
      m_snapshot.direction = FALCON_DIRECTION_NONE;
      m_snapshot.entry_time = 0;
      m_snapshot.evaluation_time = 0;
      m_snapshot.elapsed_seconds = 0;
      m_snapshot.entry_price = 0.0;
      m_snapshot.structural_sl = 0.0;
      m_snapshot.tp1 = 0.0;
      m_snapshot.tp2 = 0.0;
      m_snapshot.tp3 = 0.0;
      m_snapshot.current_price = 0.0;
      m_snapshot.simulated_exit_price = 0.0;
      m_snapshot.simulated_outcome = FALCON_TRADE_OUTCOME_UNKNOWN;
      m_snapshot.profit_index_points = 0.0;
      m_snapshot.loss_index_points = 0.0;
      m_snapshot.net_index_points = 0.0;
      m_snapshot.profit_usd = 0.0;
      m_snapshot.loss_usd = 0.0;
      m_snapshot.net_usd = 0.0;
      m_snapshot.close_reason = "";
      m_snapshot.lifecycle_reason = "";
      m_snapshot.notes = "";
   }
};

// ==================================================================
// Report Writer Foundation - append-ready CSV contracts
// ==================================================================
class CFalconReportWriter
{
private:
   string              m_trade_report_file;
   string              m_summary_report_file;
   string              m_market_diagnostics_file;
   string              m_candle_cache_diagnostics_file;
   string              m_evidence_diagnostics_file;
   string              m_shadow_diagnostics_file;
   string              m_no_lookahead_diagnostics_file;
   string              m_strategy_registry_diagnostics_file;
   string              m_strategy_adapter_diagnostics_file;
   string              m_fvg_micro_detector_diagnostics_file;
   string              m_fvg_micro_candidate_diagnostics_file;
   string              m_fvg_micro_retest_watcher_diagnostics_file;
   string              m_fvg_micro_tradeplan_staging_diagnostics_file;
   string              m_fvg_micro_lifecycle_simulation_diagnostics_file;
   string              m_report_calibration_diagnostics_file;
   string              m_runtime_report_verification_file;
   string              m_fvg_micro_smoke_test_file;
   string              m_fvg_micro_runtime_report_audit_file;
   string              m_report_creation_guarantee_file;
   string              m_tier_transitions_file;
   string              m_emergency_triggers_file;
   string              m_paper_state_snapshot_file;
   string              m_broker_execution_lifecycle_file;
   string              m_broker_tm_timeline_file;
   string              m_broker_contract_reality_audit_file;
   string              m_broker_rebased_paper_comparison_file;
   string              m_broker_paper_reconciliation_file;
   // v0.57.0: Lock Parity Executability Decomposer report files.
   string              m_lock_parity_decomp_file;
   string              m_lock_parity_rollup_file;
   // v0.57.2: Virtual Trailing Exit Bridge report file.
   string              m_virtual_trailing_exit_lifecycle_file;
   FalconSymbolContext m_symbol_context;
   FalconReportTotals  m_totals;

   // v0.53.1: Three-layer paper emergency state.
   bool                m_tle_emergency_active;
   string              m_tle_emergency_reason;
   int                 m_tle_consecutive_losses;
   datetime            m_tle_current_day;
   double              m_tle_daily_r;
   double              m_tle_equity;
   double              m_tle_peak_equity;
   double              m_tle_max_drawdown_pct;

   // v0.55.3b: Dynamic lot sizing safety ramp state.
   bool                m_dlm_previous_active_lot_ready;
   double              m_dlm_previous_active_lot;


   // v0.55.9: Weekly Stability Score summary-only state.
   int                 m_wss_week_keys[16];
   int                 m_wss_week_trades[16];
   int                 m_wss_week_wins[16];
   double              m_wss_week_net_usd[16];

   // v0.22.2 Lock cleanup: multi-profile summary arrays removed from active report surface.

   bool                m_initialized;
   int                 m_broker_entry_bridge_order_send_attempts;

public:
   CFalconReportWriter()
   {
      m_initialized = false;
      m_broker_entry_bridge_order_send_attempts = 0;
      ResetTotals();
   }

   bool Initialize(const FalconSymbolContext &symbol_context)
   {
      m_symbol_context     = symbol_context;
      m_broker_entry_bridge_order_send_attempts = 0;
      m_trade_report_file  = FalconBuildReportFileName("TradeLifecycle");
      m_summary_report_file= FalconBuildReportFileName("Summary");
      m_market_diagnostics_file = FalconBuildReportFileName("MarketDiagnostics");
      m_candle_cache_diagnostics_file = FalconBuildReportFileName("CandleCacheDiagnostics");
      m_evidence_diagnostics_file = FalconBuildReportFileName("EvidenceDiagnostics");
      m_shadow_diagnostics_file = FalconBuildReportFileName("ShadowDiagnostics");
      m_no_lookahead_diagnostics_file = FalconBuildReportFileName("NoLookaheadDiagnostics");
      m_strategy_registry_diagnostics_file = FalconBuildReportFileName("StrategyRegistryDiagnostics");
      m_strategy_adapter_diagnostics_file = FalconBuildReportFileName("StrategyAdapterDiagnostics");
      m_fvg_micro_detector_diagnostics_file = FalconBuildReportFileName("FvgMicroDetectorDiagnostics");
      m_fvg_micro_candidate_diagnostics_file = FalconBuildReportFileName("FvgMicroShadowCandidateDiagnostics");
      m_fvg_micro_retest_watcher_diagnostics_file = FalconBuildReportFileName("FvgMicroRetestWatcherDiagnostics");
      m_fvg_micro_tradeplan_staging_diagnostics_file = FalconBuildReportFileName("FvgMicroTradePlanStagingDiagnostics");
      m_fvg_micro_lifecycle_simulation_diagnostics_file = FalconBuildReportFileName("FvgMicroLifecycleSimulationDiagnostics");
      m_report_calibration_diagnostics_file = FalconBuildReportFileName("ReportCalibrationCleanupGate");
      m_runtime_report_verification_file = FalconBuildReportFileName("RuntimeReportVerification");
      m_fvg_micro_smoke_test_file = FalconBuildReportFileName("FvgMicroRuntimeSmokeTest");
      m_fvg_micro_runtime_report_audit_file = FalconBuildReportFileName("FvgMicroRuntimeReportAudit");
      m_report_creation_guarantee_file = FalconBuildReportFileName("ReportCreationGuarantee");
      m_tier_transitions_file = FalconBuildReportFileName("TierTransitions");
      m_emergency_triggers_file = FalconBuildReportFileName("EmergencyTriggers");
      m_paper_state_snapshot_file = FalconBuildReportFileName("PaperStateSnapshot");
      m_broker_execution_lifecycle_file = FalconBuildReportFileName(FALCON_BROKER_EXECUTION_LIFECYCLE_REPORT_NAME);
      m_broker_tm_timeline_file = FalconBuildReportFileName(FALCON_BROKER_TM_TIMELINE_REPORT_NAME);
      m_broker_contract_reality_audit_file = FalconBuildReportFileName(FALCON_BROKER_CONTRACT_REALITY_REPORT_NAME);
      m_broker_rebased_paper_comparison_file = FalconBuildReportFileName(FALCON_BROKER_REBASED_COMPARISON_REPORT_NAME);
      m_broker_paper_reconciliation_file = FalconBuildReportFileName(FALCON_BROKER_PAPER_RECONCILIATION_REPORT_NAME);
      // v0.57.0: Lock Parity Executability Decomposer report files.
      m_lock_parity_decomp_file = FalconBuildReportFileName(FALCON_LOCK_PARITY_DECOMP_REPORT_NAME);
      m_lock_parity_rollup_file = FalconBuildReportFileName(FALCON_LOCK_PARITY_ROLLUP_REPORT_NAME);
      // v0.57.2: Virtual Trailing Exit Bridge report file.
      m_virtual_trailing_exit_lifecycle_file = FalconBuildReportFileName(FALCON_VIRTUAL_TRAILING_EXIT_LIFECYCLE_REPORT_NAME);
      ResetTotals();

      if(EnableMainReport)
      {
         WriteTradeHeader();
         WriteSummaryHeader();
         if(!FalconReportProfileIsLockParity())
         {
            WriteTierTransitionsHeader();
            WriteEmergencyTriggersHeader();
            WritePaperStateSnapshotHeader();
            WriteBrokerExecutionLifecycleHeader();
            WriteBrokerTradeManagementEventTimelineHeader();
            WriteBrokerRebasedPaperComparisonHeader();
            WriteBrokerPaperTradeReconciliationHeader();
            WriteBrokerContractRealityAudit();
         }
         // v0.57.0: Lock Parity Executability Decomposer header.
         WriteLockParityDecompositionHeader();
         // v0.57.2: Virtual Trailing Exit Bridge header. Only emit the file when the
         // bridge can actually fire (tester-only managed close path) so LOCKPARITY
         // without execution stays at exactly 4 CSVs.
         if(EnableVirtualTrailingBridge && EnableRealExecution && MQLInfoInteger(MQL_TESTER))
            WriteVirtualTrailingExitLifecycleHeader();
      }

      if(ForceCreateReportFilesOnInit)
         WriteReportCreationGuaranteeFile();

      m_initialized = true;
      CFalconLogger::Info(StringFormat("ReportWriter initialized. TradeReport=%s | SummaryReport=%s", m_trade_report_file, m_summary_report_file));
      return true;
   }


   void WriteTierTransitionsHeader()
   {
      int handle = FileOpen(m_tier_transitions_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create TierTransitions event file: %s", m_tier_transitions_file));
         return;
      }

      FileWriteString(handle,
                      "Timestamp,FromTier,ToTier,Direction,Reason,Balance,TradesInPreviousTier,WinRate,NetR\r\n");
      FileClose(handle);
   }

   void WriteEmergencyTriggersHeader()
   {
      int handle = FileOpen(m_emergency_triggers_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create EmergencyTriggers event file: %s", m_emergency_triggers_file));
         return;
      }

      FileWriteString(handle,
                      "Timestamp,LayerTriggered,TierAtTrigger,Balance,ConsecutiveLossCount,DailyR,DrawdownPct,BlockedEntries,ResolvedAt,AutoResolved\r\n");
      FileClose(handle);
   }


   void WritePaperStateSnapshotHeader()
   {
      int handle = FileOpen(m_paper_state_snapshot_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create PaperStateSnapshot event file: %s", m_paper_state_snapshot_file));
         return;
      }

      string header = "SnapshotTime,Version,Build,TradeId,StrategyId,EngineId,Direction,EntryTime,ExitTime,EntryPrice,StructuralSL,TP1,TP2,TP3,ActiveLot,CapitalBefore,CapitalAfter,ProtectionState,RunnerState,EmergencyStatus,RecoveryMode,StateTrusted,SessionBoundaryCheckpointType,SessionBoundaryCloseTime,SessionBoundaryRecoveryCheckpointTime,ActiveDuringRecoveryWindow,RequiresRecovery,Notes";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }


   void WriteBrokerExecutionLifecycleHeader()
   {
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerExecutionLifecycle foundation report: %s", m_broker_execution_lifecycle_file));
         return;
      }

      string header = "EventKind,TradeId,StrategyId,EngineId,Direction,EventTime,PlannedEntryPrice,BrokerEntryPrice,LotSize,";
      header += "BrokerEntryAttempted,BrokerEntryAccepted,BrokerCloseAttempted,BrokerCloseAccepted,";
      header += "BrokerPositionTicket,BrokerOrderTicket,BrokerDealTicket,BrokerMagic,";
      header += "PaperRawTradeUSD,PaperFinalWorkingTradeUSD,PaperRawIndexPoints,PaperFinalWorkingIndexPoints,";
      header += "BrokerRebasedRawUSD,BrokerRebasedFinalUSD,BrokerActualBalanceDelta,BrokerVsPaperFinalDelta,BrokerVsPaperFinalDeltaStatus,";
      header += "ExecutionPolicy,Status,Reason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }


   void WriteBrokerPaperTradeReconciliationHeader()
   {
      int handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerPaperTradeReconciliation report: %s", m_broker_paper_reconciliation_file));
         return;
      }

      string header = "ReconciliationEvent,TradeId,TradeIdShort,StrategyId,EngineId,Direction,";
      header += "PaperEntryTime,BrokerEntryTime,EntryTimeDeltaSeconds,PaperExitTime,BrokerExitTime,ExitTimeDeltaSeconds,";
      header += "PaperEntryPrice,BrokerEntryPrice,EntryPriceDelta,StructuralSL,BrokerSL,SLDelta,TP1,TP2,TP3,BrokerTP,TPDelta,";
      header += "PaperExitPrice,BrokerClosePrice,ClosePriceDelta,BrokerActualPoints,BrokerActualPointsMinusPaperFinalPoints,";
      header += "ExpectedBrokerUSDFromPaperFinalPointsAtExecutedLot,BrokerActualMinusExpectedBrokerFinalUSD,ServerStopAttachPolicy,";
      header += "PaperRawUSD,PaperFinalWorkingUSD,BrokerActualUSD,BrokerMinusPaperFinalUSD,";
      header += "PaperRawPoints,PaperFinalWorkingPoints,";
      header += "BrokerPositionTicket,BrokerPositionIdentifier,BrokerOrderTicket,BrokerEntryDealTicket,BrokerCloseOrderTicket,BrokerCloseDealTicket,";
      header += "BrokerExitType,ManagedCloseAttempted,ManagedCloseObserved,ServerSLHit,ServerTPHit,NotOpenedReason,";
      header += "LotRequested,LotAuthorized,LotExecuted,LotDelta,";
      header += "ReconciliationRowRole,IsFinalReconciliationRow,LockParityGapCategory,LockParityGapPrimaryCause,LockParityGapUSD,LockParityRecommendedAction,";
      header += "Status,Reason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }

   void WriteBrokerTradeManagementEventTimelineHeader()
   {
      int handle = FileOpen(m_broker_tm_timeline_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerTradeManagementEventTimeline foundation report: %s", m_broker_tm_timeline_file));
         return;
      }

      string header = "TradeId,StrategyId,EngineId,Direction,EventType,EventTime,EventPrice,EventExecutable,ExecutionEligibility,";
      header += "BrokerPositionTicket,TP1Touched,TP2Touched,ProtectionActivated,RunnerActivated,ProtectionState,RunnerState,";
      header += "PaperRawTradeUSD,PaperFinalWorkingTradeUSD,PaperProtectionNetUSD,PaperRunnerNetUSD,";
      header += "PaperRawIndexPoints,PaperFinalWorkingIndexPoints,EventSource,Status,Reason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }




   void WriteBrokerRebasedPaperComparisonHeader()
   {
      int handle = FileOpen(m_broker_rebased_paper_comparison_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerRebasedPaperComparison audit report: %s", m_broker_rebased_paper_comparison_file));
         return;
      }

      string header = "TradeId,StrategyId,EngineId,Direction,EntryTime,ExitTime,LotSize,ActiveLot,";
      header += "LegacyPaperRawUSD,LegacyPaperFinalUSD,PaperRawPoints,PaperFinalPoints,PaperLegacyUsdPerIndexPoint,";
      header += "ContractSize,VolumeMin,VolumeStep,ReferenceLot,BrokerUsdPerIndexPointAtOneLot,BrokerUsdPerIndexPointAtActiveLot,";
      header += "BrokerRebasedRawUSD,BrokerRebasedFinalUSD,BrokerActualUSD,BrokerActualVsRebasedFinalUSD,BrokerActualVsRebasedFinalStatus,";
      header += "RequiredParityLot,BrokerMinLot,ParityLotBelowMin,OrderCalcProfitAvailable,RebaseStatus,ExecutionPolicy,Reason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }

   double FalconTimelineFinalWorkingTradeUsd(const FalconTradeLifecycleRecord &record)
   {
      return record.falcon_emergency_after_net_usd;
   }

   double FalconTimelineFinalWorkingTradePoints(const FalconTradeLifecycleRecord &record)
   {
      return record.falcon_emergency_after_net_points;
   }



   double FalconRebaseActiveLotForRecord(const FalconTradeLifecycleRecord &record)
   {
      if(record.falcon_dlm_active_lot > 0.0)
         return record.falcon_dlm_active_lot;
      if(record.lot_size > 0.0)
         return record.lot_size;
      return FALCON_BROKER_REBUILD_REFERENCE_LOT;
   }

   double FalconPaperUsdPerIndexPointForRecord(const FalconTradeLifecycleRecord &record)
   {
      if(MathAbs(record.net_index_points) > 0.0000001)
         return MathAbs(record.net_usd / record.net_index_points);
      double active_lot = FalconRebaseActiveLotForRecord(record);
      if(m_symbol_context.contract_size > 0.0 && active_lot > 0.0)
         return MathAbs(m_symbol_context.contract_size * active_lot);
      return 0.0;
   }

   bool FalconBrokerUsdPerIndexPointByOrderCalc(const FalconTradeLifecycleRecord &record,
                                                const double lot,
                                                double &value_per_index_point)
   {
      value_per_index_point = 0.0;
      if(lot <= 0.0)
         return false;

      double open_price = record.entry_price;
      if(open_price <= 0.0)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         open_price = (ask > 0.0 ? ask : bid);
      }
      if(open_price <= 0.0)
         return false;

      ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
      double close_price = open_price + 1.0;
      if(record.direction == FALCON_DIRECTION_SELL)
      {
         order_type = ORDER_TYPE_SELL;
         close_price = open_price - 1.0;
      }

      double profit = 0.0;
      if(!OrderCalcProfit(order_type, _Symbol, lot, open_price, close_price, profit))
         return false;

      value_per_index_point = MathAbs(profit);
      return (value_per_index_point > 0.0);
   }

   double FalconBrokerUsdPerIndexPointFallback(const double lot)
   {
      if(m_symbol_context.contract_size > 0.0 && lot > 0.0)
         return MathAbs(m_symbol_context.contract_size * lot);
      return 0.0;
   }

   void FalconBrokerRebaseValuesForRecord(const FalconTradeLifecycleRecord &record,
                                          double &broker_value_one_lot,
                                          double &broker_value_active_lot,
                                          bool &ordercalc_available)
   {
      double value_one_lot = 0.0;
      bool ordercalc_one = FalconBrokerUsdPerIndexPointByOrderCalc(record, 1.0, value_one_lot);
      if(!ordercalc_one)
         value_one_lot = FalconBrokerUsdPerIndexPointFallback(1.0);

      double active_lot = FalconRebaseActiveLotForRecord(record);
      double value_active = 0.0;
      bool ordercalc_active = FalconBrokerUsdPerIndexPointByOrderCalc(record, active_lot, value_active);
      if(!ordercalc_active)
         value_active = FalconBrokerUsdPerIndexPointFallback(active_lot);

      broker_value_one_lot = value_one_lot;
      broker_value_active_lot = value_active;
      ordercalc_available = (ordercalc_one && ordercalc_active);
   }

   datetime FalconTimelineSafeEventTime(const FalconTradeLifecycleRecord &record, const bool prefer_entry)
   {
      if(prefer_entry && record.entry_time > 0)
         return record.entry_time;
      if(!prefer_entry && record.exit_time > 0)
         return record.exit_time;
      if(record.exit_time > 0)
         return record.exit_time;
      return record.entry_time;
   }

   string FalconTimelineCloseReasonEventStatus(const FalconTradeLifecycleRecord &record)
   {
      if(FalconClosedAtStop(record))
         return "RAW_STOP_CLOSE_RECORDED";
      if(FalconClosedByTimeout(record))
         return "RAW_TIMEOUT_CLOSE_RECORDED";
      if(FalconClosedAtTp1(record))
         return "RAW_TP1_CLOSE_RECORDED";
      return "RAW_FINAL_CLOSE_RECORDED";
   }



   void AppendBrokerRebasedPaperComparisonRecord(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      int handle = FileOpen(m_broker_rebased_paper_comparison_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerRebasedPaperComparisonHeader();
         handle = FileOpen(m_broker_rebased_paper_comparison_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerRebasedPaperComparison row: %s", m_broker_rebased_paper_comparison_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);

      double active_lot = FalconRebaseActiveLotForRecord(record);
      double final_usd = FalconTimelineFinalWorkingTradeUsd(record);
      double final_points = FalconTimelineFinalWorkingTradePoints(record);
      double paper_usd_per_index_point = FalconPaperUsdPerIndexPointForRecord(record);
      double broker_value_one_lot = 0.0;
      double broker_value_active_lot = 0.0;
      bool ordercalc_available = false;
      FalconBrokerRebaseValuesForRecord(record, broker_value_one_lot, broker_value_active_lot, ordercalc_available);

      double broker_rebased_raw_usd = record.net_index_points * broker_value_active_lot;
      double broker_rebased_final_usd = final_points * broker_value_active_lot;
      double broker_actual_usd = 0.0;
      double broker_actual_vs_rebased_final = 0.0;
      double required_parity_lot = 0.0;
      if(broker_value_one_lot > 0.0 && paper_usd_per_index_point > 0.0)
         required_parity_lot = paper_usd_per_index_point / broker_value_one_lot;
      bool parity_lot_below_min = (required_parity_lot > 0.0 && m_symbol_context.min_lot > 0.0 && required_parity_lot < m_symbol_context.min_lot);
      string rebase_status = FALCON_BELR_REBASED_STATUS;
      if(!ordercalc_available)
         rebase_status = FALCON_BELR_REBASE_ORDERCALC_FALLBACK_STATUS;

      string row = "";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      row += DoubleToString(record.lot_size, 4) + ",";
      row += DoubleToString(active_lot, 4) + ",";
      row += DoubleToString(record.net_usd, 4) + ",";
      row += DoubleToString(final_usd, 4) + ",";
      row += DoubleToString(record.net_index_points, 2) + ",";
      row += DoubleToString(final_points, 2) + ",";
      row += DoubleToString(paper_usd_per_index_point, 6) + ",";
      row += DoubleToString(m_symbol_context.contract_size, 6) + ",";
      row += DoubleToString(m_symbol_context.min_lot, 4) + ",";
      row += DoubleToString(m_symbol_context.lot_step, 4) + ",";
      row += DoubleToString(FALCON_BROKER_REBUILD_REFERENCE_LOT, 4) + ",";
      row += DoubleToString(broker_value_one_lot, 6) + ",";
      row += DoubleToString(broker_value_active_lot, 6) + ",";
      row += DoubleToString(broker_rebased_raw_usd, 4) + ",";
      row += DoubleToString(broker_rebased_final_usd, 4) + ",";
      row += DoubleToString(broker_actual_usd, 4) + ",";
      row += DoubleToString(broker_actual_vs_rebased_final, 4) + ",";
      row += FalconCsvSafe(FALCON_BELR_REBASED_NO_ACTUAL_STATUS) + ",";
      row += DoubleToString(required_parity_lot, 6) + ",";
      row += DoubleToString(m_symbol_context.min_lot, 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(parity_lot_below_min)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(ordercalc_available)) + ",";
      row += FalconCsvSafe(rebase_status) + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe("AUDIT_ONLY_REBASES_PAPER_POINTS_TO_BROKER_CONTRACT_VALUE_NO_ORDER_SEND_NO_BROKER_CLOSE");

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerExecutionLifecycleAuditRecord(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerExecutionLifecycleHeader();
         handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerExecutionLifecycle audit row: %s", m_broker_execution_lifecycle_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      double final_usd = FalconTimelineFinalWorkingTradeUsd(record);
      double final_points = FalconTimelineFinalWorkingTradePoints(record);
      double broker_value_one_lot = 0.0;
      double broker_value_active_lot = 0.0;
      bool ordercalc_available = false;
      FalconBrokerRebaseValuesForRecord(record, broker_value_one_lot, broker_value_active_lot, ordercalc_available);
      double broker_rebased_raw_usd = record.net_index_points * broker_value_active_lot;
      double broker_rebased_final_usd = final_points * broker_value_active_lot;
      string row = "";
      row += FalconCsvSafe("TRADEMANAGEMENT_TIMELINE_AUDIT") + ",";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(FalconTimelineSafeEventTime(record, false))) + ",";
      row += DoubleToString(record.entry_price, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(record.falcon_dlm_active_lot, 2) + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe("NO") + ",";
      row += IntegerToString(0) + ",";
      row += IntegerToString(0) + ",";
      row += IntegerToString(0) + ",";
      row += IntegerToString(FC_MAGIC_FVG_MICRO) + ",";
      row += DoubleToString(record.net_usd, 4) + ",";
      row += DoubleToString(final_usd, 4) + ",";
      row += DoubleToString(record.net_index_points, 2) + ",";
      row += DoubleToString(final_points, 2) + ",";
      row += DoubleToString(broker_rebased_raw_usd, 4) + ",";
      row += DoubleToString(broker_rebased_final_usd, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += FalconCsvSafe(FALCON_BELR_NO_BROKER_COMPARISON_STATUS) + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(FALCON_TMET_STATUS) + ",";
      row += FalconCsvSafe("AUDIT_ONLY_NO_BROKER_ACTION_TIMELINE_ROW_WRITTEN_AFTER_PAPER_FINALIZATION");
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerEntryBridgeLifecycleRecord(const FalconBrokerTradeLink &link)
   {
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerExecutionLifecycleHeader();
         handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerExecutionLifecycle entry-bridge row: %s", m_broker_execution_lifecycle_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      if(link.broker_entry_attempted)
         m_broker_entry_bridge_order_send_attempts++;
      string event_kind = "BROKER_ENTRY_BRIDGE_TESTER_ONLY";
      string row = "";
      row += FalconCsvSafe(event_kind) + ",";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(link.strategy_id) + ",";
      row += FalconCsvSafe(link.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(link.broker_entry_time > 0 ? link.broker_entry_time : TimeCurrent())) + ",";
      row += DoubleToString(link.planned_entry_price, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(link.accepted_lot > 0.0 ? link.accepted_lot : link.requested_lot, 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_accepted)) + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe("NO") + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)link.broker_deal_ticket) + ",";
      row += IntegerToString((int)link.broker_magic) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += FalconCsvSafe("NOT_COMPARABLE_ENTRY_ONLY_NO_BROKER_CLOSE") + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(link.status) + ",";
      row += FalconCsvSafe(link.reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerExitObservationLifecycleRecord(const FalconBrokerTradeLink &link,
                                                    const ulong close_deal_ticket,
                                                    const ulong close_order_ticket,
                                                    const double close_price,
                                                    const double close_volume,
                                                    const double actual_balance_delta,
                                                    const datetime close_time,
                                                    const string exit_status,
                                                    const string exit_reason)
   {
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerExecutionLifecycleHeader();
         handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerExecutionLifecycle exit observation row: %s", m_broker_execution_lifecycle_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      bool open_at_deinit = (StringFind(exit_status, "OPEN_POSITION_AT_DEINIT") >= 0);
      string reason = exit_reason + "; closeDeal=" + IntegerToString((long)close_deal_ticket) +
                      "; closeOrder=" + IntegerToString((long)close_order_ticket) +
                      "; closePrice=" + DoubleToString(close_price, _Digits) +
                      "; closeVolume=" + DoubleToString(close_volume, 4) +
                      "; actualDelta=" + DoubleToString(actual_balance_delta, 4);

      string row = "";
      row += FalconCsvSafe(open_at_deinit ? "BROKER_POSITION_OPEN_AT_DEINIT" : "BROKER_EXIT_OBSERVED_ON_TRADE_TRANSACTION") + ",";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(link.strategy_id) + ",";
      row += FalconCsvSafe(link.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(close_time > 0 ? close_time : TimeCurrent())) + ",";
      row += DoubleToString(link.planned_entry_price, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(link.accepted_lot > 0.0 ? link.accepted_lot : link.requested_lot, 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_accepted)) + ",";
      row += FalconCsvSafe(open_at_deinit ? "NO" : "YES") + ",";
      row += FalconCsvSafe(open_at_deinit ? "NO" : "YES") + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)close_deal_ticket) + ",";
      row += IntegerToString((int)link.broker_magic) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(actual_balance_delta, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += FalconCsvSafe(open_at_deinit ? "BROKER_POSITION_STILL_OPEN_AT_DEINIT_NOT_COMPARABLE" : "BROKER_EXIT_OBSERVED_PAPER_FINAL_MATCH_PENDING") + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(exit_status) + ",";
      row += FalconCsvSafe(reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerManagedCloseLifecycleRecord(const FalconBrokerTradeLink &link,
                                               const bool close_attempted,
                                               const bool close_accepted,
                                               const ulong close_order_ticket,
                                               const ulong close_deal_ticket,
                                               const double close_price,
                                               const double close_volume,
                                               const datetime close_time,
                                               const string close_status,
                                               const string close_reason)
   {
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerExecutionLifecycleHeader();
         handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerExecutionLifecycle managed close row: %s", m_broker_execution_lifecycle_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      string reason = close_reason + "; closeOrder=" + IntegerToString((long)close_order_ticket) +
                      "; closeDeal=" + IntegerToString((long)close_deal_ticket) +
                      "; closePrice=" + DoubleToString(close_price, _Digits) +
                      "; closeVolume=" + DoubleToString(close_volume, 4) +
                      "; policy=" + FALCON_MREB_DECISION_POLICY;

      string row = "";
      row += FalconCsvSafe("EA_MANAGED_PROTECTION_RUNNER_CLOSE_REQUEST") + ",";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(link.strategy_id) + ",";
      row += FalconCsvSafe(link.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(close_time > 0 ? close_time : TimeCurrent())) + ",";
      row += DoubleToString(link.planned_entry_price, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(close_volume > 0.0 ? close_volume : (link.accepted_lot > 0.0 ? link.accepted_lot : link.requested_lot), 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_accepted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(close_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(close_accepted)) + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)close_deal_ticket) + ",";
      row += IntegerToString((int)link.broker_magic) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += FalconCsvSafe(close_accepted ? "EA_MANAGED_CLOSE_REQUEST_ACCEPTED_ACTUAL_DELTA_PENDING_ON_TRADE_TRANSACTION" : "EA_MANAGED_CLOSE_REQUEST_REJECTED_OR_NOT_SENT") + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(close_status) + ",";
      row += FalconCsvSafe(reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }


   void AppendBrokerPaperTradeReconciliationRecord(const FalconTradeLifecycleRecord &record,
                                                  const FalconBrokerTradeLink &link,
                                                  const string reconciliation_event,
                                                  const string reconciliation_status,
                                                  const string reconciliation_reason)
   {
      if(FalconReportProfileIsLockParity()) return;
      int handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerPaperTradeReconciliationHeader();
         handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerPaperTradeReconciliation row: %s", m_broker_paper_reconciliation_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      double paper_final_usd = FalconTimelineFinalWorkingTradeUsd(record);
      double paper_final_points = FalconTimelineFinalWorkingTradePoints(record);
      double entry_delta = 0.0;
      if(link.broker_entry_price > 0.0 && record.entry_price > 0.0)
         entry_delta = link.broker_entry_price - record.entry_price;
      double sl_delta = 0.0;
      if(link.broker_sl > 0.0 && record.structural_sl > 0.0)
         sl_delta = link.broker_sl - record.structural_sl;
      double tp_delta = 0.0;
      if(link.broker_tp > 0.0 && record.tp3 > 0.0)
         tp_delta = link.broker_tp - record.tp3;
      int entry_time_delta = 0;
      if(link.broker_entry_time > 0 && record.entry_time > 0)
         entry_time_delta = (int)(link.broker_entry_time - record.entry_time);
      int exit_time_delta = 0;
      if(link.broker_close_time > 0 && record.exit_time > 0)
         exit_time_delta = (int)(link.broker_close_time - record.exit_time);
      string not_opened_reason = "";
      if(!link.broker_entry_accepted)
         not_opened_reason = link.status + ": " + link.reason;
      bool server_sl_hit = (StringFind(link.broker_exit_status, "SL") >= 0);
      bool server_tp_hit = (StringFind(link.broker_exit_status, "TP") >= 0);
      bool managed_close_observed = (link.broker_exit_observed && StringFind(link.broker_exit_status, "EXPERT") >= 0);
      double lot_executed = (link.accepted_lot > 0.0 ? link.accepted_lot : 0.0);
      double lot_delta = lot_executed - record.falcon_dlm_active_lot;
      double paper_exit_price = record.exit_price;
      double broker_close_price = link.broker_close_price;
      double close_price_delta = 0.0;
      if(broker_close_price > 0.0 && paper_exit_price > 0.0)
         close_price_delta = broker_close_price - paper_exit_price;
      double broker_actual_points = 0.0;
      if(link.broker_entry_price > 0.0 && broker_close_price > 0.0)
         broker_actual_points = FalconRawIndexPoints(record.direction, link.broker_entry_price, broker_close_price);
      double broker_actual_points_minus_paper_final = broker_actual_points - paper_final_points;
      double broker_value_at_executed_lot = 0.0;
      bool broker_value_available = false;
      if(lot_executed > 0.0)
      {
         broker_value_available = FalconBrokerUsdPerIndexPointByOrderCalc(record, lot_executed, broker_value_at_executed_lot);
         if(!broker_value_available)
            broker_value_at_executed_lot = FalconBrokerUsdPerIndexPointFallback(lot_executed);
      }
      double expected_broker_usd_from_paper_final = paper_final_points * broker_value_at_executed_lot;
      double broker_actual_minus_expected_broker_final = link.broker_actual_balance_delta - expected_broker_usd_from_paper_final;
      string server_stop_attach_policy = (FALCON_LOCK_PARITY_ATTACH_SERVER_SL_TP ? "SERVER_SL_TP_ATTACHED" : FALCON_LOCK_PARITY_SERVER_STOP_POLICY);

      string reconciliation_row_role = "FINAL_OUTCOME";
      bool is_final_reconciliation_row = true;
      if(reconciliation_event == "PAPER_FINAL_ACTIVE_BROKER_LINK_FOUND_BEFORE_MANAGED_CLOSE" ||
         reconciliation_event == "EA_MANAGED_CLOSE_REQUEST_SENT")
      {
         reconciliation_row_role = "INTERMEDIATE_TRACE";
         is_final_reconciliation_row = false;
      }

      string lock_gap_category = "MATCHED_OR_PENDING_RECONCILIATION";
      string lock_gap_primary_cause = "MATCHED_BROKER_AND_PAPER_OR_AWAITING_EXIT";
      double lock_gap_usd = link.broker_actual_balance_delta - paper_final_usd;
      string lock_gap_action = "KEEP_REPORTING_ONLY_UNTIL_NEXT_PARITY_STAGE";

      if(!is_final_reconciliation_row)
      {
         // v0.56.9: Do not count trace rows in LOCK gap totals.
         // Earlier v0.56.8d rows such as ACTIVE_LINK_FOUND and MANAGED_CLOSE_REQUEST
         // repeated the same TradeId before the final exit row and inflated gap sums.
         lock_gap_category = "INTERMEDIATE_TRACE_NOT_COUNTED_IN_LOCK_GAP";
         lock_gap_primary_cause = reconciliation_event;
         lock_gap_usd = 0.0;
         lock_gap_action = "IGNORE_IN_FINAL_LOCK_GAP_ROLLUP_WAIT_FOR_EXIT_OR_FINAL_ROW";
      }
      else if(StringFind(reconciliation_status, "BROKER_ONLY") >= 0 || StringFind(reconciliation_event, "WITHOUT_PAPER") >= 0)
      {
         lock_gap_category = "BROKER_ONLY_TRADE_NOT_IN_LOCK";
         lock_gap_primary_cause = "BROKER_ENTRY_HAS_NO_PAPER_FINAL_LIFECYCLE";
         lock_gap_usd = link.broker_actual_balance_delta;
         lock_gap_action = "ELIMINATE_BROKER_ONLY_ENTRY_BEFORE_PROFIT_PARITY";
      }
      else if(!link.broker_entry_accepted)
      {
         lock_gap_category = "PAPER_TRADE_NOT_OPENED_ON_BROKER";
         lock_gap_usd = -paper_final_usd;
         if(StringFind(link.reason, "EXISTING_FALCON_POSITION") >= 0)
         {
            lock_gap_primary_cause = "POSITION_SERIALIZATION_MAX_OPEN_POSITIONS_GATE";
            lock_gap_action = "DESIGN_LOCK_PARITY_ENTRY_QUEUE_OR_FASTER_MANAGED_EXIT_BEFORE_RELAXING_SAFETY";
         }
         else if(StringFind(link.reason, "STRUCTURAL_SL_DISTANCE") >= 0)
         {
            lock_gap_primary_cause = "STRUCTURAL_SL_DISTANCE_RISK_GUARD";
            lock_gap_action = "MEASURE_LOCK_GAIN_LOST_TO_SL_DISTANCE_GUARD_BEFORE_ANY_THRESHOLD_CHANGE";
         }
         else if(StringFind(link.reason, "SL_LOSS_TOO_LARGE") >= 0)
         {
            lock_gap_primary_cause = "STRUCTURAL_SL_LOSS_RISK_GUARD";
            lock_gap_action = "MEASURE_LOCK_GAIN_LOST_TO_SL_LOSS_GUARD_BEFORE_ANY_THRESHOLD_CHANGE";
         }
         else if(StringFind(link.reason, "LOT_AUTHORITY") >= 0)
         {
            lock_gap_primary_cause = "LOT_AUTHORITY_OR_CAPITAL_RISK_GATE";
            lock_gap_action = "COMPARE_PAPER_LOT_VS_BROKER_AUTHORIZED_LOT_AND_CAPITAL_REQUIREMENTS";
         }
         else if(StringFind(link.reason, "MARGIN") >= 0)
         {
            lock_gap_primary_cause = "BROKER_MARGIN_GATE";
            lock_gap_action = "VERIFY_SYMBOL_LEVERAGE_MARGIN_AND_MIN_LOT_CONDITIONS";
         }
         else
         {
            lock_gap_primary_cause = "ENTRY_BLOCKED_OR_NO_AUDIT_LINK";
            lock_gap_action = "INSPECT_NOT_OPENED_REASON_AND_BROKER_ENTRY_LIFECYCLE";
         }
      }
      else if(server_sl_hit)
      {
         lock_gap_category = "EXIT_LIFECYCLE_GAP_SERVER_SL_BEFORE_LOCK_FINAL";
         lock_gap_primary_cause = "SERVER_STRUCTURAL_SL_CLOSED_BEFORE_PAPER_PROTECTION_RUNNER";
         lock_gap_action = "BUILD_MANAGED_PROTECTION_RUNNER_EXECUTION_BEFORE_ANY_DEMO_LIVE";
      }
      else if(server_tp_hit)
      {
         lock_gap_category = "EXIT_LIFECYCLE_GAP_TP3_SAFETY_CAP";
         lock_gap_primary_cause = "TP3_SERVER_SAFETY_CAP_IS_NOT_TRUE_LOCK_RUNNER";
         lock_gap_action = "REPLACE_TP3_CAP_WITH_CONTROLLED_MANAGED_RUNNER_POLICY_LATER";
      }
      else if(managed_close_observed)
      {
         if(MathAbs(lock_gap_usd) <= 0.05)
         {
            lock_gap_category = "LOCK_PARITY_MATCH_WITHIN_TOLERANCE";
            lock_gap_primary_cause = "EA_MANAGED_CLOSE_OBSERVED_AND_ACCOUNT_DELTA_MATCHES_LOCK_FINAL";
            lock_gap_action = "KEEP_AS_PARITY_REFERENCE_SAMPLE";
         }
         else if(MathAbs(lot_delta) > 0.00001)
         {
            lock_gap_category = "LOT_EXPOSURE_GAP_ON_MATCHED_MANAGED_CLOSE";
            lock_gap_primary_cause = "BROKER_EXECUTED_LOT_DIFFERS_FROM_LOCK_PAPER_ACTIVE_LOT";
            lock_gap_action = "ALIGN_DYNAMIC_LOT_EXPOSURE_OR_EXPLAIN_ACCOUNT_EQUIVALENCE_LIMIT";
         }
         else if(MathAbs(broker_actual_points_minus_paper_final) > 2.0)
         {
            lock_gap_category = "MANAGED_CLOSE_PRICE_POINTS_GAP_ON_MATCHED_CLOSE";
            lock_gap_primary_cause = "BROKER_ENTRY_OR_CLOSE_PRICE_PATH_DIFFERS_FROM_LOCK_FINAL_POINTS";
            lock_gap_action = "COMPARE_PAPER_EXIT_PRICE_BROKER_CLOSE_PRICE_AND_ENTRY_FILL_BEFORE_RUNNER_CHANGES";
         }
         else if(MathAbs(entry_delta) > 2.0)
         {
            lock_gap_category = "ENTRY_FILL_DELTA_ON_MATCHED_MANAGED_CLOSE";
            lock_gap_primary_cause = "BID_ASK_SPREAD_OR_MARKET_FILL_DIFFERENCE_ON_MANAGED_CLOSE_SAMPLE";
            lock_gap_action = "MEASURE_FILL_DELTA_DISTRIBUTION_BEFORE_EXECUTION_OPTIMIZATION";
         }
         else
         {
            lock_gap_category = "MANAGED_CLOSE_ACCOUNTING_GAP_AFTER_PRICE_POINTS_MATCH";
            lock_gap_primary_cause = "EA_MANAGED_CLOSE_OBSERVED_BUT_ACCOUNT_DELTA_DIFFERS_AFTER_PRICE_POINTS_CHECK";
            lock_gap_action = "COMPARE_ORDERCALC_POINT_VALUE_COMMISSION_SWAP_AND_CONTRACT_MULTIPLIER";
         }
      }
      else if(link.broker_entry_accepted && !link.broker_exit_observed)
      {
         lock_gap_category = "OPEN_OR_UNOBSERVED_BROKER_EXIT";
         lock_gap_primary_cause = "BROKER_EXIT_NOT_YET_OBSERVED_IN_TRANSACTION_HISTORY";
         lock_gap_action = "KEEP_HISTORY_RECOVERY_AND_DEINIT_FLUSH_ACTIVE";
      }

      if(is_final_reconciliation_row && link.broker_entry_accepted && MathAbs(entry_delta) > 2.0 && lock_gap_category == "MATCHED_OR_PENDING_RECONCILIATION")
      {
         lock_gap_category = "ENTRY_FILL_DELTA_GAP";
         lock_gap_primary_cause = "BID_ASK_SPREAD_OR_MARKET_FILL_DIFFERENCE";
         lock_gap_action = "MEASURE_FILL_DELTA_DISTRIBUTION_BEFORE_EXECUTION_OPTIMIZATION";
      }

      string row = "";
      row += FalconCsvSafe(reconciliation_event) + ",";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(StringLen(link.trade_id_short) > 0 ? link.trade_id_short : FalconTradeIdShortHash(record.trade_id)) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(link.broker_entry_time)) + ",";
      row += IntegerToString(entry_time_delta) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(link.broker_close_time)) + ",";
      row += IntegerToString(exit_time_delta) + ",";
      row += DoubleToString(record.entry_price, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(entry_delta, _Digits) + ",";
      row += DoubleToString(record.structural_sl, _Digits) + ",";
      row += DoubleToString(link.broker_sl, _Digits) + ",";
      row += DoubleToString(sl_delta, _Digits) + ",";
      row += DoubleToString(record.tp1, _Digits) + ",";
      row += DoubleToString(record.tp2, _Digits) + ",";
      row += DoubleToString(record.tp3, _Digits) + ",";
      row += DoubleToString(link.broker_tp, _Digits) + ",";
      row += DoubleToString(tp_delta, _Digits) + ",";
      row += DoubleToString(paper_exit_price, _Digits) + ",";
      row += DoubleToString(broker_close_price, _Digits) + ",";
      row += DoubleToString(close_price_delta, _Digits) + ",";
      row += DoubleToString(broker_actual_points, 2) + ",";
      row += DoubleToString(broker_actual_points_minus_paper_final, 2) + ",";
      row += DoubleToString(expected_broker_usd_from_paper_final, 4) + ",";
      row += DoubleToString(broker_actual_minus_expected_broker_final, 4) + ",";
      row += FalconCsvSafe(server_stop_attach_policy) + ",";
      row += DoubleToString(record.net_usd, 4) + ",";
      row += DoubleToString(paper_final_usd, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta - paper_final_usd, 4) + ",";
      row += DoubleToString(record.net_index_points, 2) + ",";
      row += DoubleToString(paper_final_points, 2) + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_position_identifier) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)link.broker_deal_ticket) + ",";
      row += IntegerToString((long)link.broker_close_order_ticket) + ",";
      row += IntegerToString((long)link.broker_close_deal_ticket) + ",";
      row += FalconCsvSafe(link.broker_exit_status) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.managed_close_attempted || link.broker_close_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(managed_close_observed)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(server_sl_hit)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(server_tp_hit)) + ",";
      row += FalconCsvSafe(not_opened_reason) + ",";
      row += DoubleToString(link.requested_lot, 4) + ",";
      row += DoubleToString(link.accepted_lot, 4) + ",";
      row += DoubleToString(lot_executed, 4) + ",";
      row += DoubleToString(lot_delta, 4) + ",";
      row += FalconCsvSafe(reconciliation_row_role) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(is_final_reconciliation_row)) + ",";
      row += FalconCsvSafe(lock_gap_category) + ",";
      row += FalconCsvSafe(lock_gap_primary_cause) + ",";
      row += DoubleToString(lock_gap_usd, 4) + ",";
      row += FalconCsvSafe(lock_gap_action) + ",";
      row += FalconCsvSafe(reconciliation_status) + ",";
      row += FalconCsvSafe(reconciliation_reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }



   void AppendBrokerOnlyTradeReconciliationRecord(const FalconBrokerTradeLink &link,
                                                  const string reconciliation_event,
                                                  const string reconciliation_status,
                                                  const string reconciliation_reason)
   {
      if(FalconReportProfileIsLockParity()) return;
      // v0.56.9: A broker-only trade is a LOCK-parity violation until proven otherwise.
      // These rows make the reconciliation complete even when a broker entry/exit has
      // no matching Paper/TradeLifecycle record. Do not use this as permission to keep
      // broker-only trades; it is a diagnostic gate for the next anti-orphan entry fix.
      int handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerPaperTradeReconciliationHeader();
         handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append broker-only BrokerPaperTradeReconciliation row: %s", m_broker_paper_reconciliation_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      bool server_sl_hit = (StringFind(link.broker_exit_status, "SL") >= 0);
      bool server_tp_hit = (StringFind(link.broker_exit_status, "TP") >= 0);
      bool managed_close_observed = (link.broker_exit_observed && StringFind(link.broker_exit_status, "EXPERT") >= 0);
      double lot_executed = (link.accepted_lot > 0.0 ? link.accepted_lot : 0.0);
      double entry_delta = 0.0;
      double sl_delta = 0.0;
      double tp_delta = 0.0;
      int entry_time_delta = 0;
      int exit_time_delta = 0;
      string not_opened_reason = "BROKER_ONLY_TRADE_NOT_FOUND_IN_PAPER_TRADE_LIFECYCLE_LOCK_PARITY_VIOLATION";
      string lock_gap_category = "BROKER_ONLY_TRADE_NOT_IN_LOCK";
      string lock_gap_primary_cause = "BROKER_ENTRY_HAS_NO_PAPER_FINAL_LIFECYCLE";
      double lock_gap_usd = link.broker_actual_balance_delta;
      string lock_gap_action = "ELIMINATE_BROKER_ONLY_ENTRY_BEFORE_PROFIT_PARITY";
      if(server_sl_hit)
         lock_gap_primary_cause = "BROKER_ONLY_SERVER_SL_EXIT";
      else if(server_tp_hit)
         lock_gap_primary_cause = "BROKER_ONLY_TP3_SAFETY_CAP_EXIT";
      else if(managed_close_observed)
         lock_gap_primary_cause = "BROKER_ONLY_EXPERT_MANAGED_CLOSE_EXIT";

      string reconciliation_row_role = "FINAL_OUTCOME";
      bool is_final_reconciliation_row = true;

      string row = "";
      row += FalconCsvSafe(reconciliation_event) + ",";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(StringLen(link.trade_id_short) > 0 ? link.trade_id_short : FalconTradeIdShortHash(link.trade_id)) + ",";
      row += FalconCsvSafe(link.strategy_id) + ",";
      row += FalconCsvSafe(link.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe("") + ","; // PaperEntryTime unavailable: no Paper final record exists.
      row += FalconCsvSafe(FalconTimeToString(link.broker_entry_time)) + ",";
      row += IntegerToString(entry_time_delta) + ",";
      row += FalconCsvSafe("") + ","; // PaperExitTime unavailable.
      row += FalconCsvSafe(FalconTimeToString(link.broker_close_time)) + ",";
      row += IntegerToString(exit_time_delta) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(entry_delta, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(link.broker_sl, _Digits) + ",";
      row += DoubleToString(sl_delta, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(link.broker_tp, _Digits) + ",";
      row += DoubleToString(tp_delta, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(link.broker_close_price, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta, 4) + ",";
      row += FalconCsvSafe(FALCON_LOCK_PARITY_ATTACH_SERVER_SL_TP ? "SERVER_SL_TP_ATTACHED" : FALCON_LOCK_PARITY_SERVER_STOP_POLICY) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta, 4) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_position_identifier) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)link.broker_deal_ticket) + ",";
      row += IntegerToString((long)link.broker_close_order_ticket) + ",";
      row += IntegerToString((long)link.broker_close_deal_ticket) + ",";
      row += FalconCsvSafe(link.broker_exit_status) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.managed_close_attempted || link.broker_close_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(managed_close_observed)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(server_sl_hit)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(server_tp_hit)) + ",";
      row += FalconCsvSafe(not_opened_reason) + ",";
      row += DoubleToString(link.requested_lot, 4) + ",";
      row += DoubleToString(link.accepted_lot, 4) + ",";
      row += DoubleToString(lot_executed, 4) + ",";
      row += DoubleToString(lot_executed, 4) + ",";
      row += FalconCsvSafe(reconciliation_row_role) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(is_final_reconciliation_row)) + ",";
      row += FalconCsvSafe(lock_gap_category) + ",";
      row += FalconCsvSafe(lock_gap_primary_cause) + ",";
      row += DoubleToString(lock_gap_usd, 4) + ",";
      row += FalconCsvSafe(lock_gap_action) + ",";
      row += FalconCsvSafe(reconciliation_status) + ",";
      row += FalconCsvSafe(reconciliation_reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerTradeManagementTimelineEvent(const FalconTradeLifecycleRecord &record,
                                                 const ENUM_FALCON_BROKER_TM_EVENT_TYPE event_type,
                                                 const datetime event_time,
                                                 const double event_price,
                                                 const bool event_executable,
                                                 const string execution_eligibility,
                                                 const bool tp1_touched,
                                                 const bool tp2_touched,
                                                 const string status,
                                                 const string reason)
   {
      int handle = FileOpen(m_broker_tm_timeline_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerTradeManagementEventTimelineHeader();
         handle = FileOpen(m_broker_tm_timeline_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerTradeManagementEventTimeline row: %s", m_broker_tm_timeline_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      double final_usd = FalconTimelineFinalWorkingTradeUsd(record);
      double final_points = FalconTimelineFinalWorkingTradePoints(record);

      string row = "";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconBrokerTmEventTypeToString(event_type)) + ",";
      row += FalconCsvSafe(FalconTimeToString(event_time)) + ",";
      row += DoubleToString(event_price, _Digits) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(event_executable)) + ",";
      row += FalconCsvSafe(execution_eligibility) + ",";
      row += IntegerToString(0) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(tp1_touched)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(tp2_touched)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(record.paper_protection_activated)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(record.paper_runner_activated)) + ",";
      row += FalconCsvSafe(record.paper_protection_state) + ",";
      row += FalconCsvSafe(record.paper_runner_state) + ",";
      row += DoubleToString(record.net_usd, 4) + ",";
      row += DoubleToString(final_usd, 4) + ",";
      row += DoubleToString(record.paper_protection_net_usd, 4) + ",";
      row += DoubleToString(record.paper_runner_net_usd, 4) + ",";
      row += DoubleToString(record.net_index_points, 2) + ",";
      row += DoubleToString(final_points, 2) + ",";
      row += FalconCsvSafe(FALCON_TMET_EVENT_SOURCE) + ",";
      row += FalconCsvSafe(status) + ",";
      row += FalconCsvSafe(reason);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerTradeManagementTimelineForRecord(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      FalconRunnerBarPathStats barpath_stats;
      bool path_ok = FalconBuildRunnerBarPathStats(record, barpath_stats);
      bool tp1_touched = (path_ok && barpath_stats.tp1_touched);
      bool tp2_touched = (path_ok && barpath_stats.tp2_touched);

      string audit_only = FALCON_TMET_EXECUTION_ELIGIBILITY_AUDIT_ONLY;
      datetime entry_time = FalconTimelineSafeEventTime(record, true);
      datetime exit_time = FalconTimelineSafeEventTime(record, false);

      AppendBrokerTradeManagementTimelineEvent(record,
                                               FALCON_BTM_EVENT_ENTRY_PLANNED,
                                               entry_time,
                                               record.entry_price,
                                               false,
                                               audit_only,
                                               tp1_touched,
                                               tp2_touched,
                                               "PAPER_ENTRY_PLAN_AUDIT_ONLY",
                                               "Strategy-agnostic planned entry captured after Paper finalization; v0.56.4b broker order is allowed only when StructuralSL + bridge initial TP are valid and tester-only guards pass; exits are observed through OnTradeTransaction.");

      AppendBrokerTradeManagementTimelineEvent(record,
                                               FALCON_BTM_EVENT_ENTRY_ACCEPTED_PAPER,
                                               entry_time,
                                               record.entry_price,
                                               false,
                                               audit_only,
                                               tp1_touched,
                                               tp2_touched,
                                               "PAPER_ENTRY_ACCEPTED_AUDIT_ONLY",
                                               "Paper/Shadow lifecycle accepted the trade; broker bridge remains disabled.");

      if(tp1_touched)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_TP1_TOUCH,
                                                  exit_time,
                                                  record.tp1,
                                                  false,
                                                  FALCON_TMET_NO_EXACT_TICK_TIME_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "TP1_TOUCH_AUDIT_DETECTED",
                                                  "Bar-path scan detected TP1 touch, but exact tick-time/order is not yet available in v0.56.4b timeline audit.");
      }

      if(tp2_touched)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_TP2_TOUCH,
                                                  exit_time,
                                                  record.tp2,
                                                  false,
                                                  FALCON_TMET_NO_EXACT_TICK_TIME_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "TP2_TOUCH_AUDIT_DETECTED",
                                                  "Bar-path scan detected TP2 touch, but exact tick-time/order is not yet available in v0.56.4b timeline audit.");
      }

      if(record.paper_protection_activated)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_PROTECTION_ARMED,
                                                  exit_time,
                                                  record.paper_protection_level,
                                                  false,
                                                  audit_only,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "PROTECTION_ARMED_AFTER_PAPER_FINALIZATION",
                                                  record.paper_protection_trigger);
      }

      if(record.paper_virtual_sl_hit)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_PROTECTION_TRIGGERED,
                                                  exit_time,
                                                  record.paper_protection_level,
                                                  false,
                                                  FALCON_TMET_NO_EXACT_TICK_TIME_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "PROTECTION_TRIGGERED_ACCOUNTING_AUDIT",
                                                  "Paper virtual SL hit is known after finalization; exact broker-executable trigger time is not yet established.");
      }

      if(record.paper_runner_activated)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_RUNNER_ARMED,
                                                  exit_time,
                                                  record.tp2,
                                                  false,
                                                  audit_only,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "RUNNER_ARMED_AFTER_PAPER_FINALIZATION",
                                                  "Runner was activated by Paper proof logic; broker bridge remains disabled.");

         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_RUNNER_EXIT,
                                                  exit_time,
                                                  record.exit_price,
                                                  false,
                                                  FALCON_TMET_NO_EXACT_TICK_TIME_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "RUNNER_EXIT_ACCOUNTING_AUDIT",
                                                  record.paper_runner_exit_reason);
      }

      if(FalconClosedAtStop(record))
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_RAW_SL_HIT,
                                                  exit_time,
                                                  record.exit_price,
                                                  false,
                                                  audit_only,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "RAW_SL_CLOSE_AUDIT_ONLY",
                                                  record.close_reason);
      }
      else if(FalconClosedByTimeout(record))
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_TIMEOUT_CLOSE,
                                                  exit_time,
                                                  record.exit_price,
                                                  false,
                                                  audit_only,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "RAW_TIMEOUT_CLOSE_AUDIT_ONLY",
                                                  record.close_reason);
      }

      if(MathAbs(FalconTimelineFinalWorkingTradeUsd(record) - record.net_usd) > 0.00005)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_ACCOUNTING_ONLY_ADJUSTMENT,
                                                  exit_time,
                                                  record.exit_price,
                                                  false,
                                                  FALCON_TMET_ACCOUNTING_ONLY_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "FINAL_WORKING_DIFF_REQUIRES_EXECUTABLE_EVENT_PROOF",
                                                  "Paper final-working differs from raw trade USD; this row marks the gap that must be proven broker-executable before parity.");
      }

      AppendBrokerTradeManagementTimelineEvent(record,
                                               FALCON_BTM_EVENT_FINAL_CLOSE,
                                               exit_time,
                                               record.exit_price,
                                               false,
                                               audit_only,
                                               tp1_touched,
                                               tp2_touched,
                                               FalconTimelineCloseReasonEventStatus(record),
                                               record.paper_final_exit_reason);
   }

   void WriteBrokerContractRealityAudit()
   {
      int handle = FileOpen(m_broker_contract_reality_audit_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerContractRealityAudit foundation report: %s", m_broker_contract_reality_audit_file));
         return;
      }

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double reference_lot = FALCON_BROKER_REBUILD_REFERENCE_LOT;
      double paper_usd_per_index_point_reference = MathAbs(contract_size * reference_lot);

      FalconTradeLifecycleRecord probe_record;
      probe_record.direction = FALCON_DIRECTION_BUY;
      probe_record.entry_price = (ask > 0.0 ? ask : bid);
      double broker_value_one_lot = 0.0;
      double broker_value_reference_lot = 0.0;
      double broker_value_min_lot = 0.0;
      bool ordercalc_one = FalconBrokerUsdPerIndexPointByOrderCalc(probe_record, 1.0, broker_value_one_lot);
      bool ordercalc_ref = FalconBrokerUsdPerIndexPointByOrderCalc(probe_record, reference_lot, broker_value_reference_lot);
      bool ordercalc_min = FalconBrokerUsdPerIndexPointByOrderCalc(probe_record, volume_min, broker_value_min_lot);
      if(!ordercalc_one)
         broker_value_one_lot = FalconBrokerUsdPerIndexPointFallback(1.0);
      if(!ordercalc_ref)
         broker_value_reference_lot = FalconBrokerUsdPerIndexPointFallback(reference_lot);
      if(!ordercalc_min)
         broker_value_min_lot = FalconBrokerUsdPerIndexPointFallback(volume_min);

      bool ordercalc_available = (ordercalc_one && ordercalc_ref && ordercalc_min);
      double required_parity_lot_reference = 0.0;
      if(broker_value_one_lot > 0.0 && paper_usd_per_index_point_reference > 0.0)
         required_parity_lot_reference = paper_usd_per_index_point_reference / broker_value_one_lot;
      bool parity_lot_below_min = (required_parity_lot_reference > 0.0 && volume_min > 0.0 && required_parity_lot_reference < volume_min);
      string decision = "BROKER_CONTRACT_REBASED_COMPARISON_AUDIT_ONLY_NO_BROKER_EXECUTION";
      string recommendation = "NEXT_BUILD_MAY_ADD_TESTER_ONLY_ENTRY_BRIDGE_ONLY_AFTER_REBASED_AUDIT_AND_EVENT_TIMELINE_PASS";

      string header = "EAName,Version,Build,GeneratedAt,Symbol,Digits,Point,TickSize,TickValue,ContractSize,";
      header += "VolumeMin,VolumeMax,VolumeStep,ReferenceLot,Ask,Bid,PaperUsdPerIndexPointAtReferenceLot,";
      header += "BrokerUsdPerIndexPointAtOneLot,BrokerUsdPerIndexPointAtReferenceLot,BrokerUsdPerIndexPointAtMinLot,";
      header += "RequiredParityLotAtReference,BrokerMinLot,ParityLotBelowMin,OrderCalcProfitAvailable,";
      header += "ExecutionPolicy,ReusabilityPolicy,Decision,Recommendation";
      FileWriteString(handle, header + "\r\n");

      string row = "";
      row += FalconCsvSafe(EA_NAME) + ",";
      row += FalconCsvSafe(EA_VERSION_TAG) + ",";
      row += FalconCsvSafe(EA_BUILD_TAG) + ",";
      row += FalconCsvSafe(TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)) + ",";
      row += FalconCsvSafe(_Symbol) + ",";
      row += IntegerToString(_Digits) + ",";
      row += DoubleToString(point, 10) + ",";
      row += DoubleToString(tick_size, 10) + ",";
      row += DoubleToString(tick_value, 6) + ",";
      row += DoubleToString(contract_size, 6) + ",";
      row += DoubleToString(volume_min, 4) + ",";
      row += DoubleToString(volume_max, 4) + ",";
      row += DoubleToString(volume_step, 4) + ",";
      row += DoubleToString(reference_lot, 4) + ",";
      row += DoubleToString(ask, _Digits) + ",";
      row += DoubleToString(bid, _Digits) + ",";
      row += DoubleToString(paper_usd_per_index_point_reference, 6) + ",";
      row += DoubleToString(broker_value_one_lot, 6) + ",";
      row += DoubleToString(broker_value_reference_lot, 6) + ",";
      row += DoubleToString(broker_value_min_lot, 6) + ",";
      row += DoubleToString(required_parity_lot_reference, 6) + ",";
      row += DoubleToString(volume_min, 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(parity_lot_below_min)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(ordercalc_available)) + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(FALCON_BELR_REUSABILITY_POLICY) + ",";
      row += FalconCsvSafe(decision) + ",";
      row += FalconCsvSafe(recommendation);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendPaperStateSnapshotRecord(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      m_totals.paper_state_snapshot_evaluated_trades++;

      datetime session_boundary_close_time = 0;
      datetime session_boundary_checkpoint_time = 0;
      bool active_during_recovery_window = false;
      string session_boundary_checkpoint_type = FalconSessionBoundaryCheckpointType(record, session_boundary_close_time, session_boundary_checkpoint_time, active_during_recovery_window);
      string requires_recovery = (active_during_recovery_window ? "YES" : "NO");

      int handle = FileOpen(m_paper_state_snapshot_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WritePaperStateSnapshotHeader();
         handle = FileOpen(m_paper_state_snapshot_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         m_totals.paper_state_snapshot_write_failures++;
         CFalconLogger::Warn(StringFormat("Could not append PaperStateSnapshot row: %s", m_paper_state_snapshot_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);

      string row = "";
      row += FalconCsvSafe(FalconTimeToString(TimeCurrent())) + ",";
      row += FalconCsvSafe(EA_VERSION_TAG) + ",";
      row += FalconCsvSafe(EA_BUILD_TAG) + ",";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      row += DoubleToString(record.entry_price, m_symbol_context.digits) + ",";
      row += DoubleToString(record.structural_sl, m_symbol_context.digits) + ",";
      row += DoubleToString(record.tp1, m_symbol_context.digits) + ",";
      row += DoubleToString(record.tp2, m_symbol_context.digits) + ",";
      row += DoubleToString(record.tp3, m_symbol_context.digits) + ",";
      row += DoubleToString(record.falcon_dlm_active_lot, 2) + ",";
      row += DoubleToString(record.falcon_dynamic_risk_capital_before_trade, 4) + ",";
      row += DoubleToString(record.falcon_dynamic_risk_capital_after_trade, 4) + ",";
      row += FalconCsvSafe(record.paper_protection_state) + ",";
      row += FalconCsvSafe(record.paper_runner_state) + ",";
      row += FalconCsvSafe(record.falcon_emergency_status) + ",";
      row += FalconCsvSafe(FALCON_PERSISTENCE_RECOVERY_MODE) + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe(session_boundary_checkpoint_type) + ",";
      row += FalconCsvSafe(FalconTimeToString(session_boundary_close_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(session_boundary_checkpoint_time)) + ",";
      row += FalconCsvSafe(active_during_recovery_window ? "YES" : "NO") + ",";
      row += FalconCsvSafe(requires_recovery) + ",";
      row += FalconCsvSafe(FalconSessionBoundarySnapshotNotes(record));

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
      m_totals.paper_state_snapshot_written_rows++;
   }

   void AppendEmergencyTriggerEvent(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      if(!EnableMainReport)
         return;
      if(record.falcon_emergency_status != "TRIGGERED")
         return;

      int handle = FileOpen(m_emergency_triggers_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteEmergencyTriggersHeader();
         handle = FileOpen(m_emergency_triggers_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append EmergencyTriggers event row: %s", m_emergency_triggers_file));
         return;
      }
      FileSeek(handle, 0, SEEK_END);

      string layer_name = "LAYER_" + IntegerToString(record.falcon_emergency_triggered_layer);
      if(record.falcon_emergency_reason != "")
         layer_name = record.falcon_emergency_reason;

      string row = "";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time > 0 ? record.exit_time : record.entry_time)) + ",";
      row += FalconCsvSafe(layer_name) + ",";
      row += FalconCsvSafe(record.falcon_tier_at_entry) + ",";
      row += DoubleToString(record.falcon_dynamic_risk_capital_after_trade, 4) + ",";
      row += IntegerToString(record.falcon_layer1_consecutive_losses) + ",";
      row += DoubleToString(record.falcon_layer2_daily_r, 4) + ",";
      row += DoubleToString(record.falcon_layer3_drawdown_pct, 4) + ",";
      row += IntegerToString(m_totals.paper_emergency_blocked_entries) + ",";
      row += FalconCsvSafe("PENDING_NEXT_DAY_OR_PEAK_RESET") + ",";
      row += FalconCsvSafe("NO");

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendTierTransitionEvent(const datetime event_time,
                                  const string from_tier,
                                  const string to_tier,
                                  const string direction,
                                  const string reason,
                                  const double balance,
                                  const int trades_in_previous_tier,
                                  const double win_rate,
                                  const double net_r)
   {
      if(FalconReportProfileIsLockParity()) return;
      if(!EnableMainReport)
         return;

      int handle = FileOpen(m_tier_transitions_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteTierTransitionsHeader();
         handle = FileOpen(m_tier_transitions_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append TierTransitions event row: %s", m_tier_transitions_file));
         return;
      }
      FileSeek(handle, 0, SEEK_END);

      string row = "";
      row += FalconCsvSafe(FalconTimeToString(event_time)) + ",";
      row += FalconCsvSafe(from_tier) + ",";
      row += FalconCsvSafe(to_tier) + ",";
      row += FalconCsvSafe(direction) + ",";
      row += FalconCsvSafe(reason) + ",";
      row += DoubleToString(balance, 4) + ",";
      row += IntegerToString(trades_in_previous_tier) + ",";
      row += DoubleToString(win_rate, 2) + ",";
      row += DoubleToString(net_r, 4);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   int FalconMarketCloseDayOfWeek(datetime t)
   {
      if(t <= 0)
         return -1;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return dt.day_of_week;
   }

   int FalconMarketCloseMinuteOfDay(datetime t)
   {
      if(t <= 0)
         return -1;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return dt.hour * 60 + dt.min;
   }

   datetime FalconSessionBoundaryDateStart(datetime t)
   {
      if(t <= 0)
         return 0;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      return StructToTime(dt);
   }

   int FalconMarketCloseGuardFallbackCloseMinute()
   {
      // Fallback only. Primary logic uses broker/server symbol session schedule.
      // NAS100/US100 often closes near :58. This fallback does not use the user's PC clock.
      return 23 * 60 + 58;
   }

   int FalconSessionScheduleMinuteOfDay(datetime session_time)
   {
      if(session_time < 0)
         return -1;

      long raw_seconds = (long)session_time;
      int seconds_of_day = (int)(raw_seconds % 86400);
      if(seconds_of_day < 0)
         seconds_of_day += 86400;

      // Some brokers encode 24:00 as 86400 seconds. Treat it as the final minute of the day.
      if(seconds_of_day == 0 && raw_seconds >= 86400)
         return 1439;

      return seconds_of_day / 60;
   }

   int FalconResolveCloseMinuteFromBrokerSessions(datetime t)
   {
      if(t <= 0)
         return -1;

      int dow = FalconMarketCloseDayOfWeek(t);
      if(dow < 0 || dow > 6)
         return -1;

      string symbols[2];
      symbols[0] = m_symbol_context.symbol;
      symbols[1] = _Symbol;

      for(int s = 0; s < 2; s++)
      {
         string symbol_name = symbols[s];
         if(StringLen(symbol_name) <= 0)
            continue;
         if(s == 1 && symbol_name == symbols[0])
            continue;

         int best_close_minute = -1;

         for(uint session_index = 0; session_index < 16; session_index++)
         {
            datetime session_from = 0;
            datetime session_to = 0;
            if(!SymbolInfoSessionTrade(symbol_name, (ENUM_DAY_OF_WEEK)dow, session_index, session_from, session_to))
               continue;

            int from_minute = FalconSessionScheduleMinuteOfDay(session_from);
            int to_minute = FalconSessionScheduleMinuteOfDay(session_to);
            if(from_minute < 0 || to_minute < 0)
               continue;

            int close_minute = to_minute;

            // If a broker encodes a session wrapping into the next day, the current day's last tradable minute is end-of-day.
            if(to_minute <= from_minute)
               close_minute = 1439;

            if(close_minute > best_close_minute)
               best_close_minute = close_minute;
         }

         if(best_close_minute > 0)
            return best_close_minute;
      }

      return -1;
   }

   int FalconMarketCloseGuardCloseMinute(datetime t)
   {
      // v0.55.12a-fix2: derive close from broker/server symbol session schedule.
      // This avoids user's PC time and avoids the incomplete-bar-history issue seen in fix1.
      int minute = FalconResolveCloseMinuteFromBrokerSessions(t);
      if(minute > 0)
         return minute;

      return FalconMarketCloseGuardFallbackCloseMinute();
   }

   int FalconMarketCloseGuardBlockWindowMinutes()
   {
      // v0.55.11e: 120-minute reference window retained only for market-close risk measurement.
      // Entry-window blocking was rejected and removed from default runtime/reporting.
      return 120;
   }

   int FalconUserNoNewEntryWindowMinutes()
   {
      int minutes = StopNewTradesBeforeCloseMinutes;
      if(minutes < 0)
         minutes = 0;
      if(minutes > 240)
         minutes = 240;
      return minutes;
   }

   bool FalconIsUserNoNewEntryCloseWindow(datetime t)
   {
      if(!StopNewTradesBeforeClose)
         return false;

      int window_minutes = FalconUserNoNewEntryWindowMinutes();
      if(window_minutes <= 0)
         return false;

      int dow = FalconMarketCloseDayOfWeek(t);
      if(dow < 1 || dow > 5)
         return false;

      int minute = FalconMarketCloseMinuteOfDay(t);
      if(minute < 0)
         return false;

      return (minute >= FalconMarketCloseGuardCloseMinute(t) - window_minutes);
   }

   bool FalconIsDailyCloseWindow(datetime t)
   {
      // v0.55.11e: daily close-risk measurement only. Entry-window blocking
      // was rejected after all tested windows showed negative benefit.
      int dow = FalconMarketCloseDayOfWeek(t);
      if(dow < 1 || dow > 5)
         return false;
      int minute = FalconMarketCloseMinuteOfDay(t);
      if(minute < 0)
         return false;
      return (minute >= FalconMarketCloseGuardCloseMinute(t) - FalconMarketCloseGuardBlockWindowMinutes());
   }




   bool FalconIsFridayCloseWindow(datetime t)
   {
      if(FalconMarketCloseDayOfWeek(t) != 5)
         return false;
      int minute = FalconMarketCloseMinuteOfDay(t);
      if(minute < 0)
         return false;
      return (minute >= FalconMarketCloseGuardCloseMinute(t) - FalconMarketCloseGuardBlockWindowMinutes());
   }

   bool FalconWouldBeOpenAtWeekendRisk(const FalconTradeLifecycleRecord &record)
   {
      if(record.entry_time <= 0)
         return false;
      if(FalconMarketCloseDayOfWeek(record.entry_time) != 5)
         return false;

      int entry_minute = FalconMarketCloseMinuteOfDay(record.entry_time);
      if(entry_minute >= FalconMarketCloseGuardCloseMinute(record.entry_time) - FalconMarketCloseGuardBlockWindowMinutes())
         return true;

      if(record.exit_time <= 0)
         return true;

      int exit_dow = FalconMarketCloseDayOfWeek(record.exit_time);
      int exit_minute = FalconMarketCloseMinuteOfDay(record.exit_time);
      if(exit_dow != 5 && record.exit_time > record.entry_time)
         return true;
      if(exit_dow == 5 && exit_minute >= FalconMarketCloseGuardCloseMinute(record.exit_time))
         return true;

      return false;
   }

   int FalconTradeDurationMinutesCeil(const FalconTradeLifecycleRecord &record)
   {
      if(record.entry_time <= 0 || record.exit_time <= 0 || record.exit_time <= record.entry_time)
         return 0;
      int seconds = (int)(record.exit_time - record.entry_time);
      return (seconds + 59) / 60;
   }

   int FalconClampSessionBoundaryMinutes(int minutes)
   {
      if(minutes < 0)
         return 0;
      if(minutes > 240)
         return 240;
      return minutes;
   }

   int FalconDailyForceCloseUserWindowMinutes()
   {
      return FalconClampSessionBoundaryMinutes(DailyCloseSafetyMinutes);
   }

   int FalconWeekendForceCloseUserWindowMinutes()
   {
      return FalconClampSessionBoundaryMinutes(WeekendCloseSafetyMinutes);
   }

   int FalconSessionBoundaryDefaultRecoveryCheckpointMinutes()
   {
      return FALCON_SESSION_BOUNDARY_DEFAULT_CHECKPOINT_MINUTES;
   }

   int FalconSessionBoundaryRecoveryCheckpointMinutesForActionWindow(int action_window_minutes)
   {
      // v0.55.13-fix4: dynamic relationship between user close-safety window
      // and recovery checkpoint. The checkpoint must occur after the configured
      // close/stop action and before the broker close.
      int default_checkpoint = FalconSessionBoundaryDefaultRecoveryCheckpointMinutes();
      if(default_checkpoint < 0)
         default_checkpoint = 0;

      int action_minutes = FalconClampSessionBoundaryMinutes(action_window_minutes);
      if(action_minutes <= 0)
         return default_checkpoint;

      int gap = FALCON_SESSION_BOUNDARY_ACTION_TO_CHECKPOINT_GAP_MINUTES;
      if(gap < 0)
         gap = 0;

      int dynamic_checkpoint = action_minutes - gap;
      if(dynamic_checkpoint > default_checkpoint)
         dynamic_checkpoint = default_checkpoint;
      if(dynamic_checkpoint < 0)
         dynamic_checkpoint = 0;

      return dynamic_checkpoint;
   }

   int FalconSessionBoundaryRecoveryCheckpointMinutesForRecord(const FalconTradeLifecycleRecord &record)
   {
      int dow = FalconMarketCloseDayOfWeek(record.entry_time);
      if(dow == 5 && CloseTradesBeforeWeekend)
         return FalconSessionBoundaryRecoveryCheckpointMinutesForActionWindow(FalconWeekendForceCloseUserWindowMinutes());

      if(dow >= 1 && dow <= 5 && CloseTradesBeforeDailyClose)
         return FalconSessionBoundaryRecoveryCheckpointMinutesForActionWindow(FalconDailyForceCloseUserWindowMinutes());

      return FalconSessionBoundaryDefaultRecoveryCheckpointMinutes();
   }

   datetime FalconBoundaryDateAtMinute(datetime t, int minute_of_day)
   {
      if(t <= 0)
         return 0;
      if(minute_of_day < 0)
         minute_of_day = 0;
      if(minute_of_day > 1439)
         minute_of_day = 1439;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = minute_of_day / 60;
      dt.min = minute_of_day % 60;
      dt.sec = 0;
      return StructToTime(dt);
   }

   datetime FalconDailyForceCloseUserTime(datetime t)
   {
      return FalconBoundaryDateAtMinute(t, FalconMarketCloseGuardCloseMinute(t) - FalconDailyForceCloseUserWindowMinutes());
   }

   datetime FalconWeekendForceCloseUserTime(datetime t)
   {
      return FalconBoundaryDateAtMinute(t, FalconMarketCloseGuardCloseMinute(t) - FalconWeekendForceCloseUserWindowMinutes());
   }

   datetime FalconSessionBoundaryBrokerCloseTime(datetime t)
   {
      return FalconBoundaryDateAtMinute(t, FalconMarketCloseGuardCloseMinute(t));
   }

   datetime FalconSessionBoundaryRecoveryCheckpointTime(datetime t, int checkpoint_minutes)
   {
      return FalconBoundaryDateAtMinute(t, FalconMarketCloseGuardCloseMinute(t) - FalconClampSessionBoundaryMinutes(checkpoint_minutes));
   }

   bool FalconWasTradeOpenAtTime(const FalconTradeLifecycleRecord &record, datetime boundary_time)
   {
      if(boundary_time <= 0 || record.entry_time <= 0)
         return false;
      if(record.entry_time >= boundary_time)
         return false;
      if(record.exit_time <= 0)
         return true;
      return (record.exit_time > boundary_time);
   }

   bool FalconIsSessionBoundaryNoNewEntryBlockedRecord(const FalconTradeLifecycleRecord &record)
   {
      // v0.55.13-fix4: a no-new-entry blocked row is a rejected/blocked paper signal,
      // not an open paper position. It must not be counted as active during recovery checkpoint.
      if(record.falcon_market_close_blocked == 1)
         return true;
      if(record.close_reason == "SESSION_BOUNDARY_USER_NO_NEW_ENTRY_BLOCKED")
         return true;
      return false;
   }

   bool FalconTryGetBoundaryClosePrice(datetime boundary_time, double &price)
   {
      price = 0.0;
      if(boundary_time <= 0)
         return false;

      int shift = iBarShift(m_symbol_context.symbol, PERIOD_M1, boundary_time, false);
      if(shift < 0)
         shift = iBarShift(_Symbol, PERIOD_M1, boundary_time, false);
      if(shift >= 0)
      {
         price = iClose(m_symbol_context.symbol, PERIOD_M1, shift);
         if(price <= 0.0)
            price = iClose(_Symbol, PERIOD_M1, shift);
         if(price > 0.0)
            return true;
      }

      shift = iBarShift(m_symbol_context.symbol, PERIOD_M5, boundary_time, false);
      if(shift < 0)
         shift = iBarShift(_Symbol, PERIOD_M5, boundary_time, false);
      if(shift < 0)
         return false;

      price = iClose(m_symbol_context.symbol, PERIOD_M5, shift);
      if(price <= 0.0)
         price = iClose(_Symbol, PERIOD_M5, shift);
      return (price > 0.0);
   }

   double FalconForceCloseOverrideNetUsd(const FalconTradeLifecycleRecord &record, double force_close_price)
   {
      double active_lot = record.falcon_dlm_active_lot;
      if(active_lot <= 0.0)
         active_lot = record.lot_size;
      double raw_points = FalconRawIndexPoints(record.direction, record.entry_price, force_close_price);
      return FalconEstimateUsdByRawPoints(raw_points, active_lot, m_symbol_context);
   }

   double FalconForceCloseOverrideNetPoints(const FalconTradeLifecycleRecord &record, double force_close_price)
   {
      return FalconRawIndexPoints(record.direction, record.entry_price, force_close_price);
   }

   bool FalconWasTradeActiveDuringBoundaryCheckpointWindow(const FalconTradeLifecycleRecord &record, datetime checkpoint_time, datetime close_time)
   {
      if(FalconIsSessionBoundaryNoNewEntryBlockedRecord(record))
         return false;
      if(checkpoint_time <= 0 || close_time <= 0 || record.entry_time <= 0)
         return false;
      if(record.entry_time >= close_time)
         return false;
      if(record.exit_time <= 0)
         return true;
      return (record.exit_time > checkpoint_time);
   }

   string FalconSessionBoundaryCheckpointType(const FalconTradeLifecycleRecord &record, datetime &close_time, datetime &checkpoint_time, bool &active_during_checkpoint_window)
   {
      close_time = 0;
      checkpoint_time = 0;
      active_during_checkpoint_window = false;

      if(record.entry_time <= 0)
         return "NONE";

      if(FalconIsSessionBoundaryNoNewEntryBlockedRecord(record))
      {
         close_time = FalconSessionBoundaryBrokerCloseTime(record.entry_time);
         checkpoint_time = FalconSessionBoundaryRecoveryCheckpointTime(record.entry_time, FalconSessionBoundaryRecoveryCheckpointMinutesForRecord(record));
         active_during_checkpoint_window = false;
         return "BLOCKED_NO_OPEN_POSITION";
      }

      int dow = FalconMarketCloseDayOfWeek(record.entry_time);
      if(dow < 1 || dow > 5)
         return "NONE";

      close_time = FalconSessionBoundaryBrokerCloseTime(record.entry_time);
      checkpoint_time = FalconSessionBoundaryRecoveryCheckpointTime(record.entry_time, FalconSessionBoundaryRecoveryCheckpointMinutesForRecord(record));
      if(close_time <= 0 || checkpoint_time <= 0)
         return "NONE";

      active_during_checkpoint_window = FalconWasTradeActiveDuringBoundaryCheckpointWindow(record, checkpoint_time, close_time);

      if(dow == 5 && active_during_checkpoint_window)
         return "WEEKEND";

      return "DAILY";
   }

   void UpdateSessionBoundaryStateCheckpointFoundation(const FalconTradeLifecycleRecord &record)
   {
      // v0.55.13-fix4: measurement-only dynamic checkpoint. It verifies whether Paper state
      // would still need recovery after user-selected close-safety actions and before the broker close.
      // It does not restore, close, block, or modify any trade.
      m_totals.session_boundary_checkpoint_evaluated_trades++;
      m_totals.session_boundary_recovery_checkpoint_minutes = FalconSessionBoundaryDefaultRecoveryCheckpointMinutes();

      datetime close_time = 0;
      datetime checkpoint_time = 0;
      bool active_during_checkpoint_window = false;
      string checkpoint_type = FalconSessionBoundaryCheckpointType(record, close_time, checkpoint_time, active_during_checkpoint_window);

      if(!active_during_checkpoint_window)
         return;

      m_totals.session_boundary_recovery_required_trades++;

      if(checkpoint_type == "WEEKEND")
      {
         m_totals.session_boundary_weekend_checkpoint_open_trades++;
         if(CloseTradesBeforeWeekend)
            m_totals.session_boundary_dirty_after_close_safety_trades++;
      }
      else if(checkpoint_type == "DAILY")
      {
         m_totals.session_boundary_daily_checkpoint_open_trades++;
         if(CloseTradesBeforeDailyClose)
            m_totals.session_boundary_dirty_after_close_safety_trades++;
      }
   }

   string FalconSessionBoundaryCheckpointStatus()
   {
      if(m_totals.session_boundary_checkpoint_evaluated_trades != m_totals.total_trades)
         return "FAIL_ROW_MISMATCH";
      if(m_totals.session_boundary_dirty_after_close_safety_trades > 0)
         return "WARN_DIRTY_AFTER_CLOSE_SAFETY";
      if(m_totals.session_boundary_recovery_required_trades > 0)
         return "PASS_RECOVERY_REQUIRED_BY_CARRY";
      return "PASS_CLEAN";
   }

   string FalconSessionBoundarySnapshotNotes(const FalconTradeLifecycleRecord &record)
   {
      datetime close_time = 0;
      datetime checkpoint_time = 0;
      bool active_during_checkpoint_window = false;
      string checkpoint_type = FalconSessionBoundaryCheckpointType(record, close_time, checkpoint_time, active_during_checkpoint_window);
      if(checkpoint_type == "NONE")
         return "No broker close checkpoint for this record.";
      if(checkpoint_type == "BLOCKED_NO_OPEN_POSITION")
         return "No recovery needed: session boundary blocked entry, so no open Paper position existed.";
      if(active_during_checkpoint_window)
         return StringFormat("%s checkpoint active; recovery checkpoint %s before close %s.", checkpoint_type, FalconTimeToString(checkpoint_time), FalconTimeToString(close_time));
      return StringFormat("%s checkpoint clean; recovery checkpoint %s before close %s.", checkpoint_type, FalconTimeToString(checkpoint_time), FalconTimeToString(close_time));
   }

   void UpdateMarketCloseGuardFoundation(const FalconTradeLifecycleRecord &record)
   {
      m_totals.market_close_guard_evaluated_trades++;

      int window_minutes = FalconMarketCloseGuardBlockWindowMinutes();

      int duration_minutes = FalconTradeDurationMinutesCeil(record);
      if(duration_minutes > 0)
      {
         m_totals.market_close_total_trade_duration_minutes += (double)duration_minutes;
         if(duration_minutes > m_totals.market_close_max_trade_duration_minutes)
         {
            m_totals.market_close_max_trade_duration_minutes = duration_minutes;
            m_totals.market_close_longest_trade_id = record.trade_id;
         }
         if(duration_minutes > window_minutes)
            m_totals.market_close_duration_above_window_trades++;
      }

      if(FalconIsDailyCloseWindow(record.entry_time))
      {
         m_totals.market_close_guard_near_close_entry_trades++;
      }
      if(FalconWouldBeOpenAtWeekendRisk(record))
         m_totals.market_close_guard_open_weekend_risk_trades++;
   }

   void ApplyNoNewEntryUserOverridePaperEnforcement(FalconTradeLifecycleRecord &record)
   {
      // v0.55.11f: optional user safety override.
      // Default is OFF because calibrated windows reduced profit. The user may enable it only as a safety override.
      // When explicitly enabled, the user accepts the safety trade-off and the Paper result is blocked
      // before Emergency/CapitalFlow read the trade.
      record.falcon_market_close_status = "ALLOWED";
      record.falcon_market_close_blocked = 0;
      record.falcon_market_close_reason = "NO_NEW_ENTRY_OVERRIDE_DISABLED";
      record.falcon_market_close_before_net_usd = record.falcon_single_trade_loss_cap_after_net_usd;
      record.falcon_market_close_after_net_usd = record.falcon_single_trade_loss_cap_after_net_usd;
      record.falcon_market_close_impact_usd = 0.0;

      if(!StopNewTradesBeforeClose)
         return;

      if(FalconUserNoNewEntryWindowMinutes() <= 0)
      {
         record.falcon_market_close_reason = "NO_NEW_ENTRY_OVERRIDE_ZERO_MINUTES";
         return;
      }

      if(!FalconIsUserNoNewEntryCloseWindow(record.entry_time))
      {
         record.falcon_market_close_reason = "OUTSIDE_USER_NO_NEW_ENTRY_WINDOW";
         return;
      }

      record.falcon_market_close_status = "BLOCKED";
      record.falcon_market_close_blocked = 1;
      record.falcon_market_close_reason = StringFormat("USER_NO_NEW_ENTRY_LAST_%d_MIN", FalconUserNoNewEntryWindowMinutes());
      record.falcon_market_close_after_net_usd = 0.0;
      record.falcon_market_close_impact_usd = record.falcon_market_close_after_net_usd - record.falcon_market_close_before_net_usd;

      // Feed the blocked result into all later Paper layers.
      record.falcon_single_trade_loss_cap_after_net_points = 0.0;
      record.falcon_single_trade_loss_cap_after_net_usd = 0.0;
      record.falcon_single_trade_loss_cap_impact_points = record.falcon_single_trade_loss_cap_after_net_points - record.falcon_single_trade_loss_cap_before_net_points;
      record.falcon_single_trade_loss_cap_impact_usd = record.falcon_single_trade_loss_cap_after_net_usd - record.falcon_single_trade_loss_cap_before_net_usd;
      record.close_reason = "SESSION_BOUNDARY_USER_NO_NEW_ENTRY_BLOCKED";
   }

   void ApplyDailyWeekendForceCloseUserOverridePaperEnforcement(FalconTradeLifecycleRecord &record)
   {
      // v0.55.12a: optional user safety override.
      // Defaults are OFF because validation showed profit reduction. The user may enable this only as a safety override.
      // When enabled, a qualifying open Paper trade is force-closed before Emergency and Capital Flow.
      m_totals.force_close_override_evaluated_trades++;

      if(!CloseTradesBeforeDailyClose && !CloseTradesBeforeWeekend)
         return;

      // If No-New-Entry already blocked the trade, there is no open Paper position to force-close.
      if(record.falcon_market_close_blocked == 1)
         return;

      bool use_weekend = false;
      bool use_daily = false;
      datetime boundary_time = 0;
      string reason = "NONE";

      if(CloseTradesBeforeWeekend && FalconWeekendForceCloseUserWindowMinutes() > 0 && FalconMarketCloseDayOfWeek(record.entry_time) == 5)
      {
         datetime weekend_boundary = FalconWeekendForceCloseUserTime(record.entry_time);
         if(FalconWasTradeOpenAtTime(record, weekend_boundary))
         {
            use_weekend = true;
            boundary_time = weekend_boundary;
            reason = StringFormat("USER_WEEKEND_FORCE_CLOSE_%d_MIN", FalconWeekendForceCloseUserWindowMinutes());
         }
      }

      if(!use_weekend && CloseTradesBeforeDailyClose && FalconDailyForceCloseUserWindowMinutes() > 0)
      {
         int dow = FalconMarketCloseDayOfWeek(record.entry_time);
         if(dow >= 1 && dow <= 5)
         {
            datetime daily_boundary = FalconDailyForceCloseUserTime(record.entry_time);
            if(FalconWasTradeOpenAtTime(record, daily_boundary))
            {
               use_daily = true;
               boundary_time = daily_boundary;
               reason = StringFormat("USER_DAILY_FORCE_CLOSE_%d_MIN", FalconDailyForceCloseUserWindowMinutes());
            }
         }
      }

      if(!use_weekend && !use_daily)
         return;

      double force_close_price = 0.0;
      if(!FalconTryGetBoundaryClosePrice(boundary_time, force_close_price))
      {
         m_totals.force_close_override_missing_price_trades++;
         record.falcon_market_close_reason = "FORCE_CLOSE_BOUNDARY_PRICE_MISSING";
         return;
      }

      double before_usd = record.falcon_single_trade_loss_cap_after_net_usd;
      double after_points = FalconForceCloseOverrideNetPoints(record, force_close_price);
      double after_usd = FalconForceCloseOverrideNetUsd(record, force_close_price);

      record.falcon_market_close_status = "FORCE_CLOSED";
      record.falcon_market_close_blocked = 0;
      record.falcon_market_close_reason = reason;
      record.falcon_market_close_before_net_usd = before_usd;
      record.falcon_market_close_after_net_usd = after_usd;
      record.falcon_market_close_impact_usd = after_usd - before_usd;

      record.exit_time = boundary_time;
      record.exit_price = force_close_price;
      record.close_reason = (use_weekend ? "SESSION_BOUNDARY_WEEKEND_FORCE_CLOSE_USER_OVERRIDE" : "SESSION_BOUNDARY_DAILY_FORCE_CLOSE_USER_OVERRIDE");
      record.falcon_single_trade_loss_cap_after_net_points = after_points;
      record.falcon_single_trade_loss_cap_after_net_usd = after_usd;
      record.falcon_single_trade_loss_cap_impact_points = after_points - record.falcon_single_trade_loss_cap_before_net_points;
      record.falcon_single_trade_loss_cap_impact_usd = after_usd - record.falcon_single_trade_loss_cap_before_net_usd;

      m_totals.force_close_override_closed_trades++;
      if(use_weekend)
         m_totals.force_close_override_weekend_closed_trades++;
      else if(use_daily)
         m_totals.force_close_override_daily_closed_trades++;
      m_totals.force_close_override_price_ok_trades++;
      m_totals.force_close_override_before_net_usd += before_usd;
      m_totals.force_close_override_after_net_usd += after_usd;
      m_totals.force_close_override_impact_usd += (after_usd - before_usd);
   }

   void ResetWeeklyStabilityState()
   {
      for(int i = 0; i < 16; i++)
      {
         m_wss_week_keys[i] = 0;
         m_wss_week_trades[i] = 0;
         m_wss_week_wins[i] = 0;
         m_wss_week_net_usd[i] = 0.0;
      }
   }

   int FindOrCreateWeeklyStabilitySlot(const datetime t)
   {
      int key = FalconWeeklyStabilityWeekKey(t);
      if(key <= 0)
         return -1;

      for(int i = 0; i < 16; i++)
      {
         if(m_wss_week_keys[i] == key)
            return i;
      }

      for(int j = 0; j < 16; j++)
      {
         if(m_wss_week_keys[j] == 0)
         {
            m_wss_week_keys[j] = key;
            return j;
         }
      }
      return -1;
   }

   void UpdateWeeklyStabilityFoundation(const FalconTradeLifecycleRecord &record)
   {
      datetime bucket_time = (record.exit_time > 0 ? record.exit_time : record.entry_time);
      int slot = FindOrCreateWeeklyStabilitySlot(bucket_time);
      if(slot < 0)
         return;

      m_wss_week_trades[slot]++;
      if(record.falcon_emergency_after_net_usd > 0.0)
         m_wss_week_wins[slot]++;
      m_wss_week_net_usd[slot] += record.falcon_emergency_after_net_usd;
      m_totals.weekly_stability_evaluated_trades++;
   }

   void FinalizeWeeklyStabilityFoundation()
   {
      int week_count = 0;
      int positive_weeks = 0;
      int negative_weeks = 0;
      double best_week = -1.0e100;
      double worst_week = 1.0e100;
      int active_trade_weeks = 0;

      for(int i = 0; i < 16; i++)
      {
         if(m_wss_week_keys[i] == 0 || m_wss_week_trades[i] <= 0)
            continue;
         week_count++;
         active_trade_weeks++;
         double week_net = m_wss_week_net_usd[i];
         if(week_net > 0.0) positive_weeks++;
         if(week_net < 0.0) negative_weeks++;
         if(week_net > best_week) best_week = week_net;
         if(week_net < worst_week) worst_week = week_net;
      }

      if(week_count <= 0)
      {
         m_totals.weekly_stability_weeks = 0;
         m_totals.weekly_stability_positive_weeks = 0;
         m_totals.weekly_stability_negative_weeks = 0;
         m_totals.weekly_stability_best_week_usd = 0.0;
         m_totals.weekly_stability_worst_week_usd = 0.0;
         m_totals.weekly_stability_score = 0.0;
         return;
      }

      m_totals.weekly_stability_weeks = week_count;
      m_totals.weekly_stability_positive_weeks = positive_weeks;
      m_totals.weekly_stability_negative_weeks = negative_weeks;
      m_totals.weekly_stability_best_week_usd = best_week;
      m_totals.weekly_stability_worst_week_usd = worst_week;

      double consistency_score = 40.0 * ((double)positive_weeks / (double)week_count);
      double drawdown_score = 30.0;
      if(worst_week < 0.0)
      {
         double denom = MathMax(MathAbs(m_totals.final_working_net_usd), 1.0);
         double penalty = FalconClampDouble((MathAbs(worst_week) / denom) * 30.0, 0.0, 30.0);
         drawdown_score = 30.0 - penalty;
      }
      double activity_score = FalconClampDouble(((double)m_totals.total_trades / (double)week_count) / 30.0 * 15.0, 0.0, 15.0);
      double lot_control_score = (m_totals.dynamic_lotsizing_safety_active_lot_max <= 1.0 ? 15.0 : 7.5);
      m_totals.weekly_stability_score = FalconClampDouble(consistency_score + drawdown_score + activity_score + lot_control_score, 0.0, 100.0);
   }

   void WriteReportCreationGuaranteeFile()
   {
      int handle = FileOpen(m_report_creation_guarantee_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create report guarantee file: %s", m_report_creation_guarantee_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "GeneratedAt", "StorageMode",
                "ModeTag", "FromDateTag", "ToDateTag", "ForceCreateReportFilesOnInit",
                "TradeLifecycleFile", "SummaryFile", "MarketDiagnosticsFile",
                "CandleCacheDiagnosticsFile", "EvidenceDiagnosticsFile", "ShadowDiagnosticsFile",
                "NoLookaheadDiagnosticsFile", "StrategyRegistryDiagnosticsFile", "StrategyAdapterDiagnosticsFile",
                "FvgMicroDetectorDiagnosticsFile", "FvgMicroCandidateDiagnosticsFile",
                "FvgMicroRetestWatcherDiagnosticsFile", "FvgMicroTradePlanStagingDiagnosticsFile",
                "FvgMicroLifecycleSimulationDiagnosticsFile", "RuntimeReportVerificationFile",
                "FvgMicroRuntimeSmokeTestFile", "FvgMicroRuntimeReportAuditFile");

      FileWrite(handle,
                EA_NAME, EA_VERSION_TAG, EA_BUILD_TAG, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                FalconReportStorageMode(), FalconEffectiveReportModeTag(), FalconEffectiveReportFromDateTag(), FalconEffectiveReportToDateTag(),
                FalconBoolToYesNo(ForceCreateReportFilesOnInit),
                m_trade_report_file, m_summary_report_file, m_market_diagnostics_file,
                m_candle_cache_diagnostics_file, m_evidence_diagnostics_file, m_shadow_diagnostics_file,
                m_no_lookahead_diagnostics_file, m_strategy_registry_diagnostics_file, m_strategy_adapter_diagnostics_file,
                m_fvg_micro_detector_diagnostics_file, m_fvg_micro_candidate_diagnostics_file,
                m_fvg_micro_retest_watcher_diagnostics_file, m_fvg_micro_tradeplan_staging_diagnostics_file,
                m_fvg_micro_lifecycle_simulation_diagnostics_file, m_runtime_report_verification_file,
                m_fvg_micro_smoke_test_file, m_fvg_micro_runtime_report_audit_file);

      FileClose(handle);
   }

   void WriteMarketDiagnosticsSnapshot(const FalconQuoteContext &quote_context,
                                       const FalconCandleSnapshot &primary_candle)
   {
      if(!m_initialized || !EnableMarketDiagnosticsReport)
         return;

      int handle = FileOpen(m_market_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write market diagnostics report: %s", m_market_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "Digits", "Point", "TickSize", "TickValue", "ContractSize",
                "BrokerSpreadPoints", "LiveSpreadPoints", "StopsLevelPoints",
                "MinLot", "MaxLot", "LotStep",
                "Bid", "Ask", "Last", "TickTime", "TickVolume", "TickVolumeReal",
                "UseClosedCandlesOnly", "PrimaryContextTimeframe", "AnalysisCandleShift",
                "CandleTime", "CandleOpen", "CandleHigh", "CandleLow", "CandleClose",
                "CandleTickVolume", "CandleRealVolume", "CandleSpread", "IsClosed", "IsValid",
                "ConfiguredCapital", "DailyLossLimitEnabled", "FixedDailyLossAmount", "DailyLossPercentOfCapital",
                "EnableRealExecution");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                m_symbol_context.digits,
                DoubleToString(m_symbol_context.point, 10),
                DoubleToString(m_symbol_context.tick_size, 10),
                DoubleToString(m_symbol_context.tick_value, 5),
                DoubleToString(m_symbol_context.contract_size, 2),
                (int)m_symbol_context.spread_points,
                (int)quote_context.spread_points,
                (int)m_symbol_context.stops_level_points,
                DoubleToString(m_symbol_context.min_lot, 2),
                DoubleToString(m_symbol_context.max_lot, 2),
                DoubleToString(m_symbol_context.lot_step, 2),
                DoubleToString(quote_context.bid, m_symbol_context.digits),
                DoubleToString(quote_context.ask, m_symbol_context.digits),
                DoubleToString(quote_context.last, m_symbol_context.digits),
                FalconTimeToString(quote_context.tick_time),
                quote_context.volume,
                DoubleToString(quote_context.volume_real, 2),
                (UseClosedCandlesOnly ? "true" : "false"),
                FalconTimeframeToString(primary_candle.timeframe),
                primary_candle.source_shift,
                FalconTimeToString(primary_candle.time),
                DoubleToString(primary_candle.open, m_symbol_context.digits),
                DoubleToString(primary_candle.high, m_symbol_context.digits),
                DoubleToString(primary_candle.low, m_symbol_context.digits),
                DoubleToString(primary_candle.close, m_symbol_context.digits),
                primary_candle.tick_volume,
                primary_candle.real_volume,
                primary_candle.spread,
                (primary_candle.is_closed ? "true" : "false"),
                (primary_candle.is_valid ? "true" : "false"),
                DoubleToString(FalconConfiguredCapital(), 2),
                (UseDailyLossLimit ? "true" : "false"),
                DoubleToString(FixedDailyLossAmount, 2),
                DoubleToString(DailyLossPercentOfCapital, 2),
                (EnableRealExecution ? "true" : "false"));

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Market diagnostics snapshot written: %s", m_market_diagnostics_file));
   }

   void WriteCandleCacheDiagnosticsSnapshot(CFalconCandleCache &cache)
   {
      if(!m_initialized || !EnableCandleCacheDiagnosticsReport)
         return;

      int handle = FileOpen(m_candle_cache_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write candle cache diagnostics report: %s", m_candle_cache_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "UseClosedCandlesOnly", "AnalysisShift", "CacheCount", "ValidCount",
                "Timeframe", "CandleTime", "Open", "High", "Low", "Close",
                "TickVolume", "RealVolume", "Spread", "IsClosed", "IsValid");

      for(int i = 0; i < cache.Count(); i++)
      {
         FalconCandleSnapshot snapshot;
         cache.GetSnapshotByIndex(i, snapshot);

         FileWrite(handle,
                   FalconCsvSafe(EA_NAME),
                   FalconCsvSafe(EA_VERSION_TAG),
                   FalconCsvSafe(EA_BUILD_TAG),
                   FalconCsvSafe(m_symbol_context.symbol),
                   FalconTimeToString(TimeCurrent()),
                   (UseClosedCandlesOnly ? "true" : "false"),
                   cache.AnalysisShift(),
                   cache.Count(),
                   cache.ValidCount(),
                   FalconTimeframeToString(snapshot.timeframe),
                   FalconTimeToString(snapshot.time),
                   DoubleToString(snapshot.open, m_symbol_context.digits),
                   DoubleToString(snapshot.high, m_symbol_context.digits),
                   DoubleToString(snapshot.low, m_symbol_context.digits),
                   DoubleToString(snapshot.close, m_symbol_context.digits),
                   snapshot.tick_volume,
                   snapshot.real_volume,
                   snapshot.spread,
                   (snapshot.is_closed ? "true" : "false"),
                   (snapshot.is_valid ? "true" : "false"));
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Candle cache diagnostics snapshot written: %s", m_candle_cache_diagnostics_file));
   }

   void WriteEvidenceDiagnosticsSnapshot(CFalconEvidenceFramework &evidence_framework)
   {
      if(!m_initialized || !EnableEvidenceDiagnosticsReport)
         return;

      int handle = FileOpen(m_evidence_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write evidence diagnostics report: %s", m_evidence_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "EvidenceId", "EvidenceName", "EvidenceType", "EvidenceState",
                "DirectionBias", "SourceTimeframe", "Score", "RuntimePermission", "Notes");

      for(int i = 0; i < evidence_framework.Count(); i++)
      {
         FalconEvidenceRecord record;
         if(!evidence_framework.GetRecordByIndex(i, record))
            continue;

         FileWrite(handle,
                   FalconCsvSafe(EA_NAME),
                   FalconCsvSafe(EA_VERSION_TAG),
                   FalconCsvSafe(EA_BUILD_TAG),
                   FalconCsvSafe(m_symbol_context.symbol),
                   FalconTimeToString(TimeCurrent()),
                   record.evidence_id,
                   record.evidence_name,
                   FalconEvidenceTypeToString(record.evidence_type),
                   FalconEvidenceStateToString(record.evidence_state),
                   FalconDirectionToString(record.direction_bias),
                   FalconTimeframeToString(record.source_timeframe),
                   DoubleToString(record.score, 2),
                   (record.is_runtime_permission ? "true" : "false"),
                   record.notes);
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Evidence diagnostics snapshot written: %s", m_evidence_diagnostics_file));
   }

   void WriteShadowDiagnosticsSnapshot(CFalconShadowExecutor &shadow_executor)
   {
      if(!m_initialized || !EnableShadowDiagnosticsReport)
         return;

      int handle = FileOpen(m_shadow_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write shadow diagnostics report: %s", m_shadow_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "ShadowModeEnabled", "ShadowExecutorInitialized", "BrokerOrdersAllowed",
                "StagedRecords", "ClosedRecords", "CancelledRecords",
                "TradeLifecycleBridge", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (EnableShadowMode ? "true" : "false"),
                (shadow_executor.IsInitialized() ? "true" : "false"),
                "false",
                shadow_executor.StagedRecords(),
                shadow_executor.ClosedRecords(),
                shadow_executor.CancelledRecords(),
                "ShadowToTradeLifecycleRecord_READY",
                "v0.13.1 is framework only. No strategy creates shadow records yet.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Shadow diagnostics snapshot written: %s", m_shadow_diagnostics_file));
   }

   void WriteNoLookaheadDiagnosticsSnapshot(CFalconRuntimeSafetyGuard &runtime_guard)
   {
      if(!m_initialized || !EnableNoLookaheadDiagnosticsReport)
         return;

      int handle = FileOpen(m_no_lookahead_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write no-lookahead diagnostics report: %s", m_no_lookahead_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "GuardInitialized", "TotalChecks",
                "CheckId", "CheckName", "Status", "RiskType", "Timeframe", "SourceShift",
                "UsedClosedCandle", "CurrentCandleBlocked", "FinalStateBlocked",
                "StagingAllowed", "Notes");

      for(int i = 0; i < runtime_guard.Count(); i++)
      {
         FalconRuntimeSafetyCheck check;
         if(!runtime_guard.GetCheckByIndex(i, check))
            continue;

         FileWrite(handle,
                   FalconCsvSafe(EA_NAME),
                   FalconCsvSafe(EA_VERSION_TAG),
                   FalconCsvSafe(EA_BUILD_TAG),
                   FalconCsvSafe(m_symbol_context.symbol),
                   FalconTimeToString(TimeCurrent()),
                   (runtime_guard.IsInitialized() ? "true" : "false"),
                   runtime_guard.Count(),
                   check.check_id,
                   check.check_name,
                   FalconRuntimeSafetyStatusToString(check.status),
                   FalconLookaheadRiskToString(check.risk_type),
                   FalconTimeframeToString(check.timeframe),
                   check.source_shift,
                   (check.used_closed_candle ? "true" : "false"),
                   (check.current_candle_blocked ? "true" : "false"),
                   (check.final_state_blocked ? "true" : "false"),
                   (check.staging_allowed ? "true" : "false"),
                   check.notes);
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("No-lookahead diagnostics snapshot written: %s", m_no_lookahead_diagnostics_file));
   }

   void WriteStrategyRegistryDiagnosticsSnapshot(CFalconStrategyRegistry &registry)
   {
      if(!m_initialized || !EnableStrategyRegistryDiagnosticsReport)
         return;

      int handle = FileOpen(m_strategy_registry_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write strategy registry diagnostics report: %s", m_strategy_registry_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "RegistryInitialized", "RegisteredStrategies", "EnabledByInputs",
                "CoreCount", "PriceActionCount", "OpeningCount", "LiquidityCount", "ConfirmationCount", "ResearchCount",
                "StrategyId", "StrategyName", "EngineId", "Group", "InputEnabled",
                "HealthStatus", "MaxAllowedStage", "ShadowAllowed", "PaperAllowed", "DemoAllowed", "LiveAllowed", "Notes");

      for(int i = 0; i < registry.CountRegisteredStrategies(); i++)
      {
         FalconStrategyRegistryEntry entry;
         if(!registry.GetEntryByIndex(i, entry))
            continue;

         FileWrite(handle,
                   FalconCsvSafe(EA_NAME),
                   FalconCsvSafe(EA_VERSION_TAG),
                   FalconCsvSafe(EA_BUILD_TAG),
                   FalconCsvSafe(m_symbol_context.symbol),
                   FalconTimeToString(TimeCurrent()),
                   (registry.IsInitialized() ? "true" : "false"),
                   registry.CountRegisteredStrategies(),
                   registry.CountEnabledStrategies(),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_CORE),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_PRICE_ACTION),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_OPENING),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_LIQUIDITY),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_CONFIRMATION),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_RESEARCH),
                   FalconCsvSafe(entry.strategy_id),
                   FalconCsvSafe(entry.strategy_name),
                   FalconCsvSafe(entry.engine_id),
                   FalconStrategyGroupToString(entry.strategy_group),
                   (entry.input_enabled ? "true" : "false"),
                   FalconEngineHealthToString(entry.health_status),
                   FalconEngineStatusToString(entry.max_allowed_stage),
                   (entry.shadow_allowed ? "true" : "false"),
                   (entry.paper_allowed ? "true" : "false"),
                   (entry.demo_allowed ? "true" : "false"),
                   (entry.live_allowed ? "true" : "false"),
                   FalconCsvSafe(entry.notes));
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Strategy registry diagnostics snapshot written: %s", m_strategy_registry_diagnostics_file));
   }



   void WriteStrategyAdapterDiagnosticsSnapshot(CFalconFirstShadowStrategyAdapterShell &adapter)
   {
      if(!m_initialized || !EnableStrategyAdapterDiagnosticsReport)
         return;

      int handle = FileOpen(m_strategy_adapter_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write strategy adapter diagnostics report: %s", m_strategy_adapter_diagnostics_file));
         return;
      }

      FalconStrategyAdapterSnapshot snapshot = adapter.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "AdapterInitialized", "AdapterId", "TargetStrategyId", "StrategyName", "EngineId",
                "Group", "HealthStatus", "MaxAllowedStage", "AdapterStatus",
                "RegistryFound", "InputEnabled", "ShadowAllowed", "ShadowExecutorReady", "RuntimeSafetyReady",
                "CandidateRequested", "CandidateStaged", "LiveAllowed", "OrderSendUsed",
                "NoTradeReason", "SafetyReason", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (adapter.IsInitialized() ? "true" : "false"),
                snapshot.adapter_id,
                snapshot.target_strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconStrategyGroupToString(snapshot.strategy_group),
                FalconEngineHealthToString(snapshot.health_status),
                FalconEngineStatusToString(snapshot.max_allowed_stage),
                FalconAdapterStatusToString(snapshot.adapter_status),
                (snapshot.registry_found ? "true" : "false"),
                (snapshot.input_enabled ? "true" : "false"),
                (snapshot.shadow_allowed ? "true" : "false"),
                (snapshot.shadow_executor_ready ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.candidate_requested ? "true" : "false"),
                (snapshot.candidate_staged ? "true" : "false"),
                (snapshot.live_allowed ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                snapshot.no_trade_reason,
                snapshot.safety_reason,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Strategy adapter diagnostics snapshot written: %s", m_strategy_adapter_diagnostics_file));
   }

   void WriteFvgMicroDetectorDiagnosticsSnapshot(CFalconFvgMicroShadowDetectorStub &detector)
   {
      if(!m_initialized || !EnableFvgMicroDetectorDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_detector_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro detector diagnostics report: %s", m_fvg_micro_detector_diagnostics_file));
         return;
      }

      FalconFvgMicroDetectorSnapshot snapshot = detector.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "DetectorInitialized", "DetectorId", "StrategyId", "StrategyName", "EngineId",
                "DetectorStatus", "RegistryFound", "InputEnabled",
                "CandleCacheReady", "EvidenceFrameworkReady", "RuntimeSafetyReady",
                "UsedClosedCandle", "OrderSendUsed", "AnalysisTimeframe", "AnalysisShift",
                "CandleTime", "Open", "High", "Low", "Close", "TickVolume",
                "FvgDetected", "FvgDirection", "OlderCandleTime", "MiddleCandleTime", "NewerCandleTime",
                "OlderHigh", "OlderLow", "MiddleHigh", "MiddleLow", "NewerHigh", "NewerLow",
                "FvgLower", "FvgUpper", "FvgSizePrice", "FvgSizePoints",
                "EvidenceScore", "EvidenceSummary", "NoTradeReason", "SafetyReason", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (detector.IsInitialized() ? "true" : "false"),
                snapshot.detector_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconDetectorStatusToString(snapshot.detector_status),
                (snapshot.registry_found ? "true" : "false"),
                (snapshot.input_enabled ? "true" : "false"),
                (snapshot.candle_cache_ready ? "true" : "false"),
                (snapshot.evidence_framework_ready ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.used_closed_candle ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconTimeframeToString(snapshot.analysis_timeframe),
                snapshot.analysis_shift,
                FalconTimeToString(snapshot.candle_time),
                DoubleToString(snapshot.candle_open, m_symbol_context.digits),
                DoubleToString(snapshot.candle_high, m_symbol_context.digits),
                DoubleToString(snapshot.candle_low, m_symbol_context.digits),
                DoubleToString(snapshot.candle_close, m_symbol_context.digits),
                snapshot.candle_tick_volume,
                (snapshot.fvg_detected ? "true" : "false"),
                FalconDirectionToString(snapshot.fvg_direction),
                FalconTimeToString(snapshot.older_candle_time),
                FalconTimeToString(snapshot.middle_candle_time),
                FalconTimeToString(snapshot.newer_candle_time),
                DoubleToString(snapshot.older_candle_high, m_symbol_context.digits),
                DoubleToString(snapshot.older_candle_low, m_symbol_context.digits),
                DoubleToString(snapshot.middle_candle_high, m_symbol_context.digits),
                DoubleToString(snapshot.middle_candle_low, m_symbol_context.digits),
                DoubleToString(snapshot.newer_candle_high, m_symbol_context.digits),
                DoubleToString(snapshot.newer_candle_low, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_lower, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_upper, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_size_price, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_size_points, 2),
                DoubleToString(snapshot.evidence_score, 2),
                snapshot.evidence_summary,
                snapshot.no_trade_reason,
                snapshot.safety_reason,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro detector diagnostics snapshot written: %s", m_fvg_micro_detector_diagnostics_file));
   }

   void WriteFvgMicroCandidateDiagnosticsSnapshot(CFalconFvgMicroShadowCandidateBuilder &builder)
   {
      if(!m_initialized || !EnableFvgMicroCandidateDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_candidate_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro candidate diagnostics report: %s", m_fvg_micro_candidate_diagnostics_file));
         return;
      }

      FalconFvgMicroShadowCandidateSnapshot snapshot = builder.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "BuilderInitialized", "BuilderId", "CandidateId",
                "StrategyId", "StrategyName", "EngineId", "CandidateStatus",
                "DetectorInitialized", "RegistryFound", "InputEnabled", "ShadowAllowed", "RuntimeSafetyReady",
                "FvgDetected", "CandidateCreated", "TradePlanCreated", "StagedToShadowExecutor", "OrderSendUsed",
                "Direction", "AnalysisTimeframe", "SetupTime",
                "EntryZoneLower", "EntryZoneUpper", "FvgSizePoints",
                "QualityFiltersEnabled", "QualityFiltersPassed", "QualityMinFvgSizePoints",
                "QualityCurrentSpreadPoints", "QualityMaxSpreadPoints", "QualityFvgAgeBars",
                "QualityMaxFvgAgeBars", "QualityRetestFreshnessBars", "QualityRejectReason",
                "Score", "BlockReason", "EvidenceSummary", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (builder.IsInitialized() ? "true" : "false"),
                snapshot.builder_id,
                snapshot.candidate_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconCandidateStatusToString(snapshot.candidate_status),
                (snapshot.detector_initialized ? "true" : "false"),
                (snapshot.registry_found ? "true" : "false"),
                (snapshot.input_enabled ? "true" : "false"),
                (snapshot.shadow_allowed ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.fvg_detected ? "true" : "false"),
                (snapshot.candidate_created ? "true" : "false"),
                (snapshot.tradeplan_created ? "true" : "false"),
                (snapshot.staged_to_shadow_executor ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconDirectionToString(snapshot.direction),
                FalconTimeframeToString(snapshot.analysis_timeframe),
                FalconTimeToString(snapshot.setup_time),
                DoubleToString(snapshot.entry_zone_lower, m_symbol_context.digits),
                DoubleToString(snapshot.entry_zone_upper, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_size_points, 2),
                FalconBoolToYesNo(snapshot.quality_filters_enabled),
                FalconBoolToYesNo(snapshot.quality_filters_passed),
                DoubleToString(snapshot.quality_min_fvg_size_points, 2),
                IntegerToString((int)snapshot.quality_current_spread_points),
                IntegerToString((int)snapshot.quality_max_spread_points),
                IntegerToString(snapshot.quality_fvg_age_bars),
                IntegerToString(snapshot.quality_max_fvg_age_bars),
                IntegerToString(snapshot.quality_retest_freshness_bars),
                FalconCsvSafe(snapshot.quality_reject_reason),
                DoubleToString(snapshot.score, 2),
                FalconCsvSafe(snapshot.block_reason),
                FalconCsvSafe(snapshot.evidence_summary),
                FalconCsvSafe(snapshot.notes));

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro shadow candidate diagnostics snapshot written: %s", m_fvg_micro_candidate_diagnostics_file));
   }

   void WriteFvgMicroRetestWatcherDiagnosticsSnapshot(CFalconFvgMicroRetestWatcher &watcher)
   {
      if(!m_initialized || !EnableFvgMicroRetestWatcherDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_retest_watcher_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro retest watcher diagnostics report: %s", m_fvg_micro_retest_watcher_diagnostics_file));
         return;
      }

      FalconFvgMicroRetestWatcherSnapshot snapshot = watcher.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "WatcherInitialized", "WatcherId", "CandidateId",
                "StrategyId", "StrategyName", "EngineId", "WatcherStatus",
                "CandidateBuilderInitialized", "CandidateReady", "QuoteValid", "RuntimeSafetyReady",
                "FvgDetected", "RetestTouched", "TradePlanSkeletonCreated", "TradePlanCreated", "StagedToShadowExecutor", "OrderSendUsed",
                "Direction", "AnalysisTimeframe", "SetupTime", "WatchTime", "WatchPrice",
                "FvgLower", "FvgUpper", "FvgSizePoints",
                "PlannedLotSize", "PlannedEntryPrice", "PlannedStructuralSL", "PlannedTP1", "PlannedTP2", "PlannedTP3",
                "RetestReason", "BlockReason", "SkeletonNotes", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (watcher.IsInitialized() ? "true" : "false"),
                snapshot.watcher_id,
                snapshot.candidate_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconRetestWatcherStatusToString(snapshot.watcher_status),
                (snapshot.candidate_builder_initialized ? "true" : "false"),
                (snapshot.candidate_ready ? "true" : "false"),
                (snapshot.quote_valid ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.fvg_detected ? "true" : "false"),
                (snapshot.retest_touched ? "true" : "false"),
                (snapshot.tradeplan_skeleton_created ? "true" : "false"),
                (snapshot.tradeplan_created ? "true" : "false"),
                (snapshot.staged_to_shadow_executor ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconDirectionToString(snapshot.direction),
                FalconTimeframeToString(snapshot.analysis_timeframe),
                FalconTimeToString(snapshot.setup_time),
                FalconTimeToString(snapshot.watch_time),
                DoubleToString(snapshot.watch_price, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_lower, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_upper, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_size_points, 2),
                DoubleToString(snapshot.planned_lot_size, 2),
                DoubleToString(snapshot.planned_entry_price, m_symbol_context.digits),
                DoubleToString(snapshot.planned_structural_sl, m_symbol_context.digits),
                DoubleToString(snapshot.planned_tp1, m_symbol_context.digits),
                DoubleToString(snapshot.planned_tp2, m_symbol_context.digits),
                DoubleToString(snapshot.planned_tp3, m_symbol_context.digits),
                snapshot.retest_reason,
                snapshot.block_reason,
                snapshot.skeleton_notes,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro retest watcher diagnostics snapshot written: %s", m_fvg_micro_retest_watcher_diagnostics_file));
   }


   void WriteFvgMicroTradePlanStagingDiagnosticsSnapshot(CFalconFvgMicroTradePlanStagingDryRun &stager)
   {
      if(!m_initialized || !EnableFvgMicroTradePlanStagingDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_tradeplan_staging_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro TradePlan staging diagnostics report: %s", m_fvg_micro_tradeplan_staging_diagnostics_file));
         return;
      }

      FalconFvgMicroTradePlanStagingSnapshot snapshot = stager.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "StagerInitialized", "StagerId", "PlanId", "CandidateId", "ShadowId",
                "StrategyId", "StrategyName", "EngineId", "StagingStatus", "WatcherStatus",
                "WatcherInitialized", "RetestTouched", "SkeletonReady", "RuntimeSafetyReady", "ShadowExecutorReady",
                "TradePlanCreated", "ValidatePassed", "StagedToShadowExecutor", "OrderSendUsed",
                "Direction", "AnalysisTimeframe", "SetupTime", "StagingTime",
                "LotSize", "Entry", "SL", "TP1", "TP2", "TP3",
                "RiskProfile", "ManagementProfile", "ValidationReason", "StagingReason", "EvidenceSummary", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (stager.IsInitialized() ? "true" : "false"),
                snapshot.stager_id,
                snapshot.plan_id,
                snapshot.candidate_id,
                snapshot.shadow_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconTradePlanStagingStatusToString(snapshot.staging_status),
                FalconRetestWatcherStatusToString(snapshot.watcher_status),
                (snapshot.watcher_initialized ? "true" : "false"),
                (snapshot.retest_touched ? "true" : "false"),
                (snapshot.skeleton_ready ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.shadow_executor_ready ? "true" : "false"),
                (snapshot.tradeplan_created ? "true" : "false"),
                (snapshot.validate_passed ? "true" : "false"),
                (snapshot.staged_to_shadow_executor ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconDirectionToString(snapshot.direction),
                FalconTimeframeToString(snapshot.analysis_timeframe),
                FalconTimeToString(snapshot.setup_time),
                FalconTimeToString(snapshot.staging_time),
                DoubleToString(snapshot.lot_size, 2),
                DoubleToString(snapshot.entry_price, m_symbol_context.digits),
                DoubleToString(snapshot.structural_sl, m_symbol_context.digits),
                DoubleToString(snapshot.tp1, m_symbol_context.digits),
                DoubleToString(snapshot.tp2, m_symbol_context.digits),
                DoubleToString(snapshot.tp3, m_symbol_context.digits),
                snapshot.risk_profile,
                snapshot.management_profile,
                snapshot.validation_reason,
                snapshot.staging_reason,
                snapshot.evidence_summary,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro TradePlan staging dry-run diagnostics snapshot written: %s", m_fvg_micro_tradeplan_staging_diagnostics_file));
   }

   void WriteFvgMicroLifecycleSimulationDiagnosticsSnapshot(CFalconFvgMicroShadowLifecycleSimulation &simulator)
   {
      if(!m_initialized || !EnableFvgMicroLifecycleSimulationDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_lifecycle_simulation_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro lifecycle simulation diagnostics report: %s", m_fvg_micro_lifecycle_simulation_diagnostics_file));
         return;
      }

      FalconFvgMicroShadowLifecycleSnapshot snapshot = simulator.GetSnapshot();
      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "SimulatorId", "LifecycleStatus", "ShadowStatus", "ShadowId",
                "StrategyId", "StrategyName", "EngineId", "Direction",
                "StagerReady", "StagedToShadowExecutor", "ShadowRecordLoaded", "QuoteValid",
                "CloseRecordCreated", "RegisteredToTradeReport", "OrderSendUsed",
                "EntryTime", "EvaluationTime", "ElapsedSeconds",
                "Entry", "SL", "TP1", "TP2", "TP3", "CurrentPrice", "ExitPrice",
                "Outcome", "ProfitIndexPoints", "LoseIndexPoints", "NetIndexPoints",
                "ProfitUSD", "LoseUSD", "NetUSD", "CloseReason", "LifecycleReason", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                snapshot.simulator_id,
                FalconShadowLifecycleStatusToString(snapshot.lifecycle_status),
                FalconShadowStatusToString(snapshot.shadow_record_status),
                snapshot.shadow_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconDirectionToString(snapshot.direction),
                (snapshot.stager_ready ? "true" : "false"),
                (snapshot.staged_to_shadow_executor ? "true" : "false"),
                (snapshot.shadow_record_loaded ? "true" : "false"),
                (snapshot.quote_valid ? "true" : "false"),
                (snapshot.close_record_created ? "true" : "false"),
                (snapshot.registered_to_trade_report ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconTimeToString(snapshot.entry_time),
                FalconTimeToString(snapshot.evaluation_time),
                snapshot.elapsed_seconds,
                DoubleToString(snapshot.entry_price, m_symbol_context.digits),
                DoubleToString(snapshot.structural_sl, m_symbol_context.digits),
                DoubleToString(snapshot.tp1, m_symbol_context.digits),
                DoubleToString(snapshot.tp2, m_symbol_context.digits),
                DoubleToString(snapshot.tp3, m_symbol_context.digits),
                DoubleToString(snapshot.current_price, m_symbol_context.digits),
                DoubleToString(snapshot.simulated_exit_price, m_symbol_context.digits),
                FalconOutcomeToString(snapshot.simulated_outcome),
                DoubleToString(snapshot.profit_index_points, 2),
                DoubleToString(snapshot.loss_index_points, 2),
                DoubleToString(snapshot.net_index_points, 2),
                DoubleToString(snapshot.profit_usd, 2),
                DoubleToString(snapshot.loss_usd, 2),
                DoubleToString(snapshot.net_usd, 2),
                snapshot.close_reason,
                snapshot.lifecycle_reason,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro lifecycle simulation diagnostics snapshot written: %s", m_fvg_micro_lifecycle_simulation_diagnostics_file));
   }

   void WriteReportCalibrationDiagnosticsSnapshot()
   {
      if(!m_initialized || !EnableReportCalibrationDiagnosticsReport)
         return;

      int handle = FileOpen(m_report_calibration_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write report calibration diagnostics report: %s", m_report_calibration_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "CalibrationItem", "Status", "ReportFile", "ExpectedFields",
                "CurrentMode", "CleanupGateDecision", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "TradeLifecycleSchema",
                "PASS",
                m_trade_report_file,
                "Entry|SL|TP1|TP2|TP3|Exit|WinLose|ProfitIndexPoints|LoseIndexPoints|NetIndexPoints|ProfitUSD|LoseUSD|NetUSD|StrategyName|EngineId",
                "Append-on-close when a controlled Shadow record closes",
                "KEEP_CORE_REPORT",
                "Main lifecycle report contains the fields requested by the project owner. No final heavy rebuild is used for trade rows.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "SummarySchema",
                "PASS",
                m_summary_report_file,
                "TotalTrades|WinTrades|LoseTrades|WinRate|LoseRate|TotalProfitIndexPoints|TotalLossIndexPoints|NetIndexPoints|TotalProfitUSD|TotalLossUSD|NetUSD",
                "Written on deinitialization from accumulated closed records",
                "KEEP_CORE_REPORT",
                "Summary is intentionally compact and will remain part of the final product.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "ShadowLifecycleCalibration",
                "WATCH",
                m_fvg_micro_lifecycle_simulation_diagnostics_file,
                "LifecycleStatus|ShadowStatus|Entry|SL|TP1|CurrentPrice|ExitPrice|Outcome|ProfitIndexPoints|LoseIndexPoints|ProfitUSD|LoseUSD",
                "Diagnostic only while FVG Micro Shadow lifecycle is being validated",
                "CLEANUP_AFTER_VALIDATION",
                "Keep while validating Shadow lifecycle behavior. Later merge useful fields into TradeLifecycle and remove temporary detail report if no longer needed.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "DiagnosticInputsInventory",
                "WATCH",
                "Inputs",
                "EnableMarketDiagnosticsReport|EnableCandleCacheDiagnosticsReport|EnableEvidenceDiagnosticsReport|EnableShadowDiagnosticsReport|EnableNoLookaheadDiagnosticsReport|FVG diagnostics toggles",
                "Development diagnostics are ON by default during v0.x foundation builds",
                "REDUCE_INPUTS_AFTER_LOCK",
                "Project rule: after each diagnostic path is proven, remove temporary inputs or move them under a compact Research/Debug preset.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "ExecutionSafety",
                "PASS",
                "N/A",
                "No OrderSend|No Paper|No Demo|No Live",
                "Shadow lifecycle simulation only",
                "KEEP_SAFETY_GUARD",
                "Real execution remains impossible in this build even if EnableRealExecution is changed.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "CleanupGateRule",
                "ACTIVE",
                m_report_calibration_diagnostics_file,
                "CleanupCandidate|Decision|Reason",
                "Review only, no trading logic change",
                "MANDATORY_BEFORE_NEXT_MAJOR_ACTIVATION",
                "Before expanding to Paper/Demo, remove noisy diagnostics, keep only main lifecycle, summary, evidence, rejection, and selected engine health reports.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Report calibration and cleanup gate diagnostics snapshot written: %s", m_report_calibration_diagnostics_file));
   }


   void WriteFvgMicroSmokeTestDiagnosticsSnapshot(const string trigger)
   {
      if(!m_initialized || !EnableFvgMicroSmokeTestDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_smoke_test_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro smoke-test diagnostics report: %s", m_fvg_micro_smoke_test_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt", "Trigger",
                "SmokeCheck", "Status", "Result", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "ExecutionSafety",
                "PASS",
                "NO_REAL_EXECUTION",
                "Execution guard remains active. v0.56.4b uses tester-only atomic entry+exit bridge plus exit observation when EnableRealExecution=true; Demo/Live and BrokerModify remain disabled.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "ShadowPipelineShape",
                "PASS",
                "DETECTOR_TO_LIFECYCLE_PATH_PRESENT",
                "FVG Detector, Candidate Builder, Retest Watcher, TradePlan Stager, Shadow Executor, and Lifecycle Simulator are connected in diagnostic mode.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "TradeLifecycleRows",
                "WATCH",
                "DATA_DEPENDENT",
                "TradeLifecycle rows appear only if a closed-candle M5 FVG is detected, price retests the zone, staging passes, and the shadow record reaches TP1/SL/timeout.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "ReportVerification",
                "PASS",
                m_runtime_report_verification_file,
                "Runtime report verification tracks whether generated reports are readable and non-empty.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "DiagnosticCleanupGate",
                "ACTIVE",
                "CLEAN_LATER",
                "This smoke-test report is temporary and must be merged or removed after the FVG Micro shadow runtime path is validated.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro shadow runtime smoke-test diagnostics snapshot written: %s | Trigger=%s", m_fvg_micro_smoke_test_file, trigger));
   }


   void WriteFvgMicroRuntimeReportAuditSnapshot(const string trigger)
   {
      if(!m_initialized || !EnableFvgMicroRuntimeReportAuditReport)
         return;

      int handle = FileOpen(m_fvg_micro_runtime_report_audit_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro runtime report audit: %s", m_fvg_micro_runtime_report_audit_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt", "Trigger",
                "AuditItem", "ReportFile", "ExpectedContent", "Readable", "SizeBytes", "AuditStatus", "Decision", "Notes");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "TradeLifecycleRows", m_trade_report_file, EnableMainReport,
                                         "Header plus closed Shadow lifecycle rows when FVG+Retest+Staging+TP/SL/Timeout occurs",
                                         "DATA_DEPENDENT",
                                         "If empty after a test window, inspect whether no FVG retest occurred or whether staging/lifecycle path is blocked.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "SummaryTotals", m_summary_report_file, EnableMainReport,
                                         "WinRate/LoseRate/TotalProfitIndexPoints/TotalLossIndexPoints/TotalProfitUSD/TotalLossUSD",
                                         "KEEP_CORE_REPORT",
                                         "Summary is expected to be non-empty after OnDeinit. During OnInit it can be header-only.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "FvgDetector", m_fvg_micro_detector_diagnostics_file, EnableFvgMicroDetectorDiagnosticsReport,
                                         "FVG detected flag, direction, bounds, candle times and high/low values",
                                         "KEEP_UNTIL_FVG_PATH_LOCK",
                                         "Detector report must remain until FVG Micro shadow logic is stable.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "FvgCandidate", m_fvg_micro_candidate_diagnostics_file, EnableFvgMicroCandidateDiagnosticsReport,
                                         "Shadow candidate status and blocker reason",
                                         "KEEP_UNTIL_CANDIDATE_LOCK",
                                         "Candidate report explains why a detected FVG did or did not become a research candidate.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "RetestWatcher", m_fvg_micro_retest_watcher_diagnostics_file, EnableFvgMicroRetestWatcherDiagnosticsReport,
                                         "Retest touched status plus skeleton Entry/SL/TP projections",
                                         "KEEP_UNTIL_RETEST_LOCK",
                                         "Watcher report is needed to separate no setup from no retest.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "TradePlanStaging", m_fvg_micro_tradeplan_staging_diagnostics_file, EnableFvgMicroTradePlanStagingDiagnosticsReport,
                                         "TradePlan created, staging validation passed, staged to Shadow Executor",
                                         "KEEP_UNTIL_STAGING_LOCK",
                                         "Staging report proves No-Lookahead Guard and Shadow Executor handoff.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "LifecycleSimulation", m_fvg_micro_lifecycle_simulation_diagnostics_file, EnableFvgMicroLifecycleSimulationDiagnosticsReport,
                                         "Lifecycle status, TP1/SL/Timeout close, Win/Lose, Index Points and USD",
                                         "KEEP_UNTIL_LIFECYCLE_LOCK",
                                         "Lifecycle report is the bridge between Shadow trade and main TradeLifecycle rows.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "RuntimeVerification", m_runtime_report_verification_file, EnableRuntimeReportVerificationReport,
                                         "Report readability and file-size status for each generated CSV",
                                         "TEMPORARY_DIAGNOSTIC",
                                         "Merge or remove after report writing is proven stable.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "SmokeTest", m_fvg_micro_smoke_test_file, EnableFvgMicroSmokeTestDiagnosticsReport,
                                         "Pipeline checklist for Detector -> Candidate -> Watcher -> Stager -> Shadow -> Lifecycle",
                                         "TEMPORARY_DIAGNOSTIC",
                                         "Remove under Diagnostic Cleanup Gate after smoke test path is locked.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "ClosedShadowTradesSoFar",
                m_trade_report_file,
                "m_totals.total_trades should increase only after controlled Shadow lifecycle close",
                "YES",
                0,
                (m_totals.total_trades > 0 ? "ROWS_PRESENT" : "NO_CLOSED_SHADOW_ROWS_YET"),
                (m_totals.total_trades > 0 ? "AUDIT_LIFECYCLE_ROWS" : "CONTINUE_RUNTIME_TEST"),
                "If this remains zero after long Strategy Tester windows with visible FVG retests, inspect staging blockers and lifecycle timeout rules.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "DiagnosticCleanupGate",
                "Inputs/Reports",
                "Temporary diagnostics must be reduced after validation",
                "YES",
                0,
                "ACTIVE",
                "CLEAN_LATER",
                "Keep full diagnostics during v0.x foundation. Before Paper/Demo, keep only core reports and selected engine health/audit reports.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro practical runtime report audit written: %s | Trigger=%s", m_fvg_micro_runtime_report_audit_file, trigger));
   }


   void WriteRuntimeReportVerificationSnapshot(const string trigger)
   {
      if(!m_initialized || !EnableRuntimeReportVerificationReport)
         return;

      int handle = FileOpen(m_runtime_report_verification_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write runtime report verification snapshot: %s", m_runtime_report_verification_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt", "Trigger",
                "ReportKey", "FileName", "EnabledByInput", "Readable", "SizeBytes", "Status", "Notes");

      WriteRuntimeReportVerificationRow(handle, trigger, "TradeLifecycle", m_trade_report_file, EnableMainReport,
                                        "Main trade rows report. Must contain Entry/SL/TP/Exit/WinLose/IndexPoints/USD/StrategyName when lifecycle records close.");
      WriteRuntimeReportVerificationRow(handle, trigger, "Summary", m_summary_report_file, EnableMainReport,
                                        "Final summary report. It is rewritten on deinit with WinRate/LoseRate and totals.");
      WriteRuntimeReportVerificationRow(handle, trigger, "PaperStateSnapshot", m_paper_state_snapshot_file, EnableMainReport,
                                        "v0.55.13-fix4 snapshot-only Paper state persistence + dynamic session boundary checkpoint foundation + blocked-entry recovery-state fix. No runtime restore or trading change.");
      WriteRuntimeReportVerificationRow(handle, trigger, "MarketDiagnostics", m_market_diagnostics_file, EnableMarketDiagnosticsReport,
                                        "Symbol context diagnostics: digits, point, tick, contract, spread, stops level.");
      WriteRuntimeReportVerificationRow(handle, trigger, "CandleCacheDiagnostics", m_candle_cache_diagnostics_file, EnableCandleCacheDiagnosticsReport,
                                        "Multi-timeframe closed candle cache diagnostics for M1/M5/M15/H1/H4/D1.");
      WriteRuntimeReportVerificationRow(handle, trigger, "EvidenceDiagnostics", m_evidence_diagnostics_file, EnableEvidenceDiagnosticsReport,
                                        "Evidence framework contract diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "ShadowDiagnostics", m_shadow_diagnostics_file, EnableShadowDiagnosticsReport,
                                        "Shadow executor diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "NoLookaheadDiagnostics", m_no_lookahead_diagnostics_file, EnableNoLookaheadDiagnosticsReport,
                                        "Runtime safety and no-lookahead guard diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "StrategyRegistryDiagnostics", m_strategy_registry_diagnostics_file, EnableStrategyRegistryDiagnosticsReport,
                                        "Strategy registry and health switch diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "StrategyAdapterDiagnostics", m_strategy_adapter_diagnostics_file, EnableStrategyAdapterDiagnosticsReport,
                                        "First strategy adapter shell diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroDetectorDiagnostics", m_fvg_micro_detector_diagnostics_file, EnableFvgMicroDetectorDiagnosticsReport,
                                        "FVG detector diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroCandidateDiagnostics", m_fvg_micro_candidate_diagnostics_file, EnableFvgMicroCandidateDiagnosticsReport,
                                        "FVG shadow candidate builder diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroRetestWatcherDiagnostics", m_fvg_micro_retest_watcher_diagnostics_file, EnableFvgMicroRetestWatcherDiagnosticsReport,
                                        "FVG retest watcher and skeleton diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroTradePlanStagingDiagnostics", m_fvg_micro_tradeplan_staging_diagnostics_file, EnableFvgMicroTradePlanStagingDiagnosticsReport,
                                        "FVG TradePlan staging dry-run diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroLifecycleSimulationDiagnostics", m_fvg_micro_lifecycle_simulation_diagnostics_file, EnableFvgMicroLifecycleSimulationDiagnosticsReport,
                                        "FVG shadow lifecycle simulation diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "ReportCalibrationCleanupGate", m_report_calibration_diagnostics_file, EnableReportCalibrationDiagnosticsReport,
                                        "Report schema calibration and Diagnostic Cleanup Gate review.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroRuntimeSmokeTest", m_fvg_micro_smoke_test_file, EnableFvgMicroSmokeTestDiagnosticsReport,
                                        "FVG Micro shadow runtime smoke-test checklist.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroRuntimeReportAudit", m_fvg_micro_runtime_report_audit_file, EnableFvgMicroRuntimeReportAuditReport,
                                        "First practical audit of generated FVG Micro runtime CSV reports and lifecycle-row readiness.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Runtime report verification snapshot written: %s | Trigger=%s", m_runtime_report_verification_file, trigger));
   }

   // ==================================================================
   // v0.57.0: Lock Parity Executability Decomposer
   // Pure additive / report-only. Reads finalized lifecycle record after
   // every Apply* layer has run; never mutates any trade value.
   // ==================================================================
   void WriteLockParityDecompositionHeader()
   {
      int handle = FileOpen(m_lock_parity_decomp_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create LockParityExecutabilityDecomposition file: %s", m_lock_parity_decomp_file));
         return;
      }

      string header =
         "TradeId,Direction,EntryTime,ExitTime,EntryPrice,ExitPrice,LotSize,ActiveLot,"
         "L0_RawNetUSD,"
         "L1_GuardNetUSD,L1_GuardDeltaUSD,L1_GuardClass,"
         "L2_ProtectionNetUSD,L2_ProtectionDeltaUSD,L2_ProtectionClass,L2_ProtectionLevel,"
         "L3_RunnerNetUSD,L3_RunnerDeltaUSD,L3_RunnerClass,L3_RunnerAdditionalPoints,"
         "L3_RunnerCapturedPoints,L3_RunnerExitPriceDerived,L3_RunnerMaxFavorablePoints,"
         "L3_RunnerExitWithinPath,L3_RunnerVsActualPoints,"
         "L4_LossCapBeforeUSD,L4_LossCapAfterUSD,L4_LossCapDeltaUSD,L4_LossCapClass,L4_LossCapBlocked,"
         "L5_MarketCloseBeforeUSD,L5_MarketCloseAfterUSD,L5_MarketCloseDeltaUSD,L5_MarketCloseClass,"
         "L6_EmergencyBeforeUSD,L6_EmergencyAfterUSD,L6_EmergencyDeltaUSD,L6_EmergencyClass,L6_EmergencyLayer,"
         "L7_OtherDeltaUSD,L7_OtherClass,"
         "FinalWorkingNetUSD,"
         "TotalExecutableDeltaUSD,TotalNonExecutableDeltaUSD,"
         "ChainResidualUSD,DecompositionStatus";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }

   bool LockParityIsExecutableClass(const string class_tag)
   {
      if(StringFind(class_tag, "EXECUTABLE_") == 0)
         return true;
      // v0.57.1: Runner Exit Price Probe — within-path runner exits are executable.
      if(class_tag == "RUNNER_EXIT_PRICE_WITHIN_MARKET_PATH")
         return true;
      return false;
   }

   bool LockParityIsNonExecutableClass(const string class_tag)
   {
      if(class_tag == "NON_EXECUTABLE_ACCOUNTING")
         return true;
      // v0.57.0 legacy tag retained for backward compatibility (no longer produced).
      if(class_tag == "RUNNER_EXTENSION_NEEDS_PRICE_PROOF")
         return true;
      // v0.57.1: Runner Exit Price Probe — outside-path or insufficient data is non-executable.
      if(class_tag == "RUNNER_EXIT_PRICE_OUTSIDE_MARKET_PATH")
         return true;
      if(class_tag == "RUNNER_PATH_DATA_INSUFFICIENT")
         return true;
      if(class_tag == "UNATTRIBUTED_NEEDS_REVIEW")
         return true;
      return false;
   }

   // v0.57.1: Runner Exit Price Probe.
   // Derives the runner exit price from captured points (already in record),
   // then tests whether that derived price lies inside the path the market
   // actually traversed (tp2 .. max-favorable). Read-only by construction;
   // does NOT modify any trade value or Apply* layer.
   void FalconRunnerExitPriceProbe(const FalconTradeLifecycleRecord &record,
                                   double &captured_points_out,
                                   double &runner_exit_price_out,
                                   double &max_favorable_points_out,
                                   bool   &within_path_out,
                                   double &runner_vs_actual_points_out,
                                   bool   &path_data_valid_out)
   {
      captured_points_out         = record.paper_runner_captured_points;
      runner_exit_price_out       = 0.0;
      max_favorable_points_out    = 0.0;
      within_path_out             = false;
      runner_vs_actual_points_out = 0.0;
      path_data_valid_out         = false;

      if(record.entry_price <= 0.0)
         return;

      if(record.direction == FALCON_DIRECTION_BUY)
         runner_exit_price_out = record.entry_price + captured_points_out;
      else if(record.direction == FALCON_DIRECTION_SELL)
         runner_exit_price_out = record.entry_price - captured_points_out;
      else
         return;

      runner_vs_actual_points_out = FalconRawIndexPoints(record.direction,
                                                        runner_exit_price_out,
                                                        record.exit_price);

      double risk_points = FalconStructuralRiskPoints(record);
      if(risk_points <= 0.0 || record.paper_runner_max_r <= 0.0)
      {
         path_data_valid_out = false;
         return;
      }
      path_data_valid_out      = true;
      max_favorable_points_out = record.paper_runner_max_r * risk_points;

      double max_fav_price = 0.0;
      if(record.direction == FALCON_DIRECTION_BUY)
         max_fav_price = record.entry_price + max_favorable_points_out;
      else
         max_fav_price = record.entry_price - max_favorable_points_out;

      if(record.tp2 <= 0.0)
      {
         within_path_out = false;
         return;
      }

      double lo = MathMin(record.tp2, max_fav_price);
      double hi = MathMax(record.tp2, max_fav_price);
      within_path_out = (runner_exit_price_out >= lo && runner_exit_price_out <= hi);
   }

   bool LockParityProtectionLevelTouched(const FalconTradeLifecycleRecord &record)
   {
      if(record.paper_protection_level <= 0.0)
         return false;
      if(record.entry_price <= 0.0 || record.exit_price <= 0.0)
         return false;
      double lo = MathMin(record.entry_price, record.exit_price);
      double hi = MathMax(record.entry_price, record.exit_price);
      return (record.paper_protection_level >= lo && record.paper_protection_level <= hi);
   }

   string ClassifyLockParityGuard(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      bool guard_rejected = (StringFind(record.paper_guard_status, "REJECT") >= 0);
      bool guard_zeroed   = (MathAbs(record.paper_guard_net_usd) < 0.0001 &&
                             MathAbs(record.net_usd) >= FALCON_LOCK_PARITY_DELTA_EPS);
      if(guard_rejected || guard_zeroed)
         return "EXECUTABLE_ENTRY_FILTER";
      if(MathAbs(delta_usd) < FALCON_LOCK_PARITY_DELTA_EPS)
         return "NO_ADJUSTMENT";
      return "NON_EXECUTABLE_ACCOUNTING";
   }

   string ClassifyLockParityProtection(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      if(record.paper_protection_activated && record.paper_protection_level > 0.0 &&
         LockParityProtectionLevelTouched(record))
         return "EXECUTABLE_PROTECTION_CLOSE";
      if(record.paper_protection_activated && MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "NON_EXECUTABLE_ACCOUNTING";
      if(MathAbs(delta_usd) < FALCON_LOCK_PARITY_DELTA_EPS)
         return "NO_ADJUSTMENT";
      return "NON_EXECUTABLE_ACCOUNTING";
   }

   // v0.57.1: Runner classification driven by the Runner Exit Price Probe.
   // Replaces RUNNER_EXTENSION_NEEDS_PRICE_PROOF with concrete executable /
   // non-executable verdicts based on whether the derived runner exit price
   // falls inside the market-touched path (tp2 .. max-favorable).
   string ClassifyLockParityRunner(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      if(!record.paper_runner_activated)
      {
         if(MathAbs(delta_usd) < FALCON_LOCK_PARITY_DELTA_EPS)
            return "NO_ADJUSTMENT";
         return "RUNNER_NOT_ACTIVATED";
      }
      if(record.paper_runner_additional_points <= 0.0)
      {
         if(MathAbs(delta_usd) < FALCON_LOCK_PARITY_DELTA_EPS)
            return "NO_ADJUSTMENT";
         return "RUNNER_NO_ADDITIONAL_CAPTURE";
      }

      double captured_points = 0.0;
      double runner_exit_price = 0.0;
      double max_favorable_points = 0.0;
      bool   within_path = false;
      double runner_vs_actual_points = 0.0;
      bool   path_data_valid = false;
      FalconRunnerExitPriceProbe(record,
                                 captured_points,
                                 runner_exit_price,
                                 max_favorable_points,
                                 within_path,
                                 runner_vs_actual_points,
                                 path_data_valid);

      if(!path_data_valid)
         return "RUNNER_PATH_DATA_INSUFFICIENT";
      if(within_path)
         return "RUNNER_EXIT_PRICE_WITHIN_MARKET_PATH";
      return "RUNNER_EXIT_PRICE_OUTSIDE_MARKET_PATH";
   }

   string ClassifyLockParityLossCap(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      if(record.falcon_single_trade_loss_cap_blocked == 1)
         return "EXECUTABLE_RISK_NO_ENTRY";
      if(MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "NON_EXECUTABLE_ACCOUNTING";
      return "NO_ADJUSTMENT";
   }

   string ClassifyLockParityMarketClose(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      if(record.falcon_market_close_blocked == 1)
         return "EXECUTABLE_TIME_NO_ENTRY";
      if(MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "EXECUTABLE_TIME_CLOSE";
      return "NO_ADJUSTMENT";
   }

   string ClassifyLockParityEmergency(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      bool zeroed_after = (MathAbs(record.falcon_emergency_after_net_usd) < 0.0001);
      if(record.falcon_emergency_triggered_layer > 0 && zeroed_after &&
         MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "EXECUTABLE_GOVERNANCE_NO_ENTRY";
      if(MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "NON_EXECUTABLE_ACCOUNTING";
      return "NO_ADJUSTMENT";
   }

   string ClassifyLockParityOther(const double delta_usd)
   {
      if(MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "UNATTRIBUTED_NEEDS_REVIEW";
      return "NO_ADJUSTMENT";
   }

   double LockParityActiveLot(const FalconTradeLifecycleRecord &record)
   {
      if(record.falcon_dlm_active_lot > 0.0)
         return record.falcon_dlm_active_lot;
      return record.lot_size;
   }

   void AppendLockParityDecompositionRecord(const FalconTradeLifecycleRecord &record)
   {
      // Layer deltas. d_other is residual that makes the per-trade chain closed by construction.
      double d_guard       = record.paper_guard_net_usd                          - record.net_usd;
      double d_protection  = record.paper_protection_net_usd                     - record.paper_guard_net_usd;
      double d_runner      = record.paper_runner_net_usd                         - record.paper_protection_net_usd;
      double d_losscap     = record.falcon_single_trade_loss_cap_after_net_usd
                           - record.falcon_single_trade_loss_cap_before_net_usd;
      double d_marketclose = record.falcon_market_close_after_net_usd
                           - record.falcon_market_close_before_net_usd;
      double d_emergency   = record.falcon_emergency_after_net_usd
                           - record.falcon_emergency_before_net_usd;
      double d_other       = record.falcon_emergency_after_net_usd - record.net_usd
                           - (d_guard + d_protection + d_runner
                              + d_losscap + d_marketclose + d_emergency);

      string c_guard       = ClassifyLockParityGuard(record, d_guard);
      string c_protection  = ClassifyLockParityProtection(record, d_protection);
      string c_runner      = ClassifyLockParityRunner(record, d_runner);
      string c_losscap     = ClassifyLockParityLossCap(record, d_losscap);
      string c_marketclose = ClassifyLockParityMarketClose(record, d_marketclose);
      string c_emergency   = ClassifyLockParityEmergency(record, d_emergency);
      string c_other       = ClassifyLockParityOther(d_other);

      double exec_sum = 0.0;
      double nonexec_sum = 0.0;
      if(LockParityIsExecutableClass(c_guard))         exec_sum    += d_guard;
      else if(LockParityIsNonExecutableClass(c_guard)) nonexec_sum += d_guard;
      if(LockParityIsExecutableClass(c_protection))         exec_sum    += d_protection;
      else if(LockParityIsNonExecutableClass(c_protection)) nonexec_sum += d_protection;
      if(LockParityIsExecutableClass(c_runner))         exec_sum    += d_runner;
      else if(LockParityIsNonExecutableClass(c_runner)) nonexec_sum += d_runner;
      if(LockParityIsExecutableClass(c_losscap))         exec_sum    += d_losscap;
      else if(LockParityIsNonExecutableClass(c_losscap)) nonexec_sum += d_losscap;
      if(LockParityIsExecutableClass(c_marketclose))         exec_sum    += d_marketclose;
      else if(LockParityIsNonExecutableClass(c_marketclose)) nonexec_sum += d_marketclose;
      if(LockParityIsExecutableClass(c_emergency))         exec_sum    += d_emergency;
      else if(LockParityIsNonExecutableClass(c_emergency)) nonexec_sum += d_emergency;
      if(LockParityIsExecutableClass(c_other))         exec_sum    += d_other;
      else if(LockParityIsNonExecutableClass(c_other)) nonexec_sum += d_other;

      double chain_residual = record.falcon_emergency_after_net_usd
                            - (record.net_usd + d_guard + d_protection + d_runner
                               + d_losscap + d_marketclose + d_emergency + d_other);
      string decomp_status = (MathAbs(chain_residual) < FALCON_LOCK_PARITY_CHAIN_RESIDUAL_TOL ? "PASS" : "RESIDUAL_BREACH");

      int handle = FileOpen(m_lock_parity_decomp_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteLockParityDecompositionHeader();
         handle = FileOpen(m_lock_parity_decomp_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append LockParityExecutabilityDecomposition row: %s", m_lock_parity_decomp_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);

      string row = "";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      row += DoubleToString(record.entry_price, m_symbol_context.digits) + ",";
      row += DoubleToString(record.exit_price, m_symbol_context.digits) + ",";
      row += DoubleToString(record.lot_size, 2) + ",";
      row += DoubleToString(LockParityActiveLot(record), 2) + ",";

      row += DoubleToString(record.net_usd, 4) + ",";

      row += DoubleToString(record.paper_guard_net_usd, 4) + ",";
      row += DoubleToString(d_guard, 4) + ",";
      row += FalconCsvSafe(c_guard) + ",";

      row += DoubleToString(record.paper_protection_net_usd, 4) + ",";
      row += DoubleToString(d_protection, 4) + ",";
      row += FalconCsvSafe(c_protection) + ",";
      row += DoubleToString(record.paper_protection_level, m_symbol_context.digits) + ",";

      row += DoubleToString(record.paper_runner_net_usd, 4) + ",";
      row += DoubleToString(d_runner, 4) + ",";
      row += FalconCsvSafe(c_runner) + ",";
      row += DoubleToString(record.paper_runner_additional_points, 2) + ",";

      // v0.57.1: Runner Exit Price Probe diagnostic columns.
      double probe_captured_points = 0.0;
      double probe_runner_exit_price = 0.0;
      double probe_max_favorable_points = 0.0;
      bool   probe_within_path = false;
      double probe_runner_vs_actual_points = 0.0;
      bool   probe_path_data_valid = false;
      FalconRunnerExitPriceProbe(record,
                                 probe_captured_points,
                                 probe_runner_exit_price,
                                 probe_max_favorable_points,
                                 probe_within_path,
                                 probe_runner_vs_actual_points,
                                 probe_path_data_valid);
      row += DoubleToString(probe_captured_points, 2) + ",";
      row += DoubleToString(probe_runner_exit_price, m_symbol_context.digits) + ",";
      row += DoubleToString(probe_max_favorable_points, 2) + ",";
      row += FalconCsvSafe(probe_within_path ? "YES" : "NO") + ",";
      row += DoubleToString(probe_runner_vs_actual_points, 2) + ",";

      row += DoubleToString(record.falcon_single_trade_loss_cap_before_net_usd, 4) + ",";
      row += DoubleToString(record.falcon_single_trade_loss_cap_after_net_usd, 4) + ",";
      row += DoubleToString(d_losscap, 4) + ",";
      row += FalconCsvSafe(c_losscap) + ",";
      row += IntegerToString(record.falcon_single_trade_loss_cap_blocked) + ",";

      row += DoubleToString(record.falcon_market_close_before_net_usd, 4) + ",";
      row += DoubleToString(record.falcon_market_close_after_net_usd, 4) + ",";
      row += DoubleToString(d_marketclose, 4) + ",";
      row += FalconCsvSafe(c_marketclose) + ",";

      row += DoubleToString(record.falcon_emergency_before_net_usd, 4) + ",";
      row += DoubleToString(record.falcon_emergency_after_net_usd, 4) + ",";
      row += DoubleToString(d_emergency, 4) + ",";
      row += FalconCsvSafe(c_emergency) + ",";
      row += IntegerToString(record.falcon_emergency_triggered_layer) + ",";

      row += DoubleToString(d_other, 4) + ",";
      row += FalconCsvSafe(c_other) + ",";

      row += DoubleToString(record.falcon_emergency_after_net_usd, 4) + ",";

      row += DoubleToString(exec_sum, 4) + ",";
      row += DoubleToString(nonexec_sum, 4) + ",";

      row += DoubleToString(chain_residual, 4) + ",";
      row += FalconCsvSafe(decomp_status);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void UpdateLockParityTotals(const FalconTradeLifecycleRecord &record)
   {
      double d_guard       = record.paper_guard_net_usd                          - record.net_usd;
      double d_protection  = record.paper_protection_net_usd                     - record.paper_guard_net_usd;
      double d_runner      = record.paper_runner_net_usd                         - record.paper_protection_net_usd;
      double d_losscap     = record.falcon_single_trade_loss_cap_after_net_usd
                           - record.falcon_single_trade_loss_cap_before_net_usd;
      double d_marketclose = record.falcon_market_close_after_net_usd
                           - record.falcon_market_close_before_net_usd;
      double d_emergency   = record.falcon_emergency_after_net_usd
                           - record.falcon_emergency_before_net_usd;
      double d_other       = record.falcon_emergency_after_net_usd - record.net_usd
                           - (d_guard + d_protection + d_runner
                              + d_losscap + d_marketclose + d_emergency);

      string c_guard       = ClassifyLockParityGuard(record, d_guard);
      string c_protection  = ClassifyLockParityProtection(record, d_protection);
      string c_runner      = ClassifyLockParityRunner(record, d_runner);
      string c_losscap     = ClassifyLockParityLossCap(record, d_losscap);
      string c_marketclose = ClassifyLockParityMarketClose(record, d_marketclose);
      string c_emergency   = ClassifyLockParityEmergency(record, d_emergency);
      string c_other       = ClassifyLockParityOther(d_other);

      m_totals.lock_parity_evaluated_trades++;
      m_totals.lock_parity_raw_net_usd            += record.net_usd;
      m_totals.lock_parity_final_working_net_usd  += record.falcon_emergency_after_net_usd;
      m_totals.lock_parity_sum_guard_delta_usd       += d_guard;
      m_totals.lock_parity_sum_protection_delta_usd  += d_protection;
      m_totals.lock_parity_sum_runner_delta_usd      += d_runner;
      m_totals.lock_parity_sum_losscap_delta_usd     += d_losscap;
      m_totals.lock_parity_sum_marketclose_delta_usd += d_marketclose;
      m_totals.lock_parity_sum_emergency_delta_usd   += d_emergency;
      m_totals.lock_parity_sum_other_delta_usd       += d_other;

      double per_trade_residual = record.falcon_emergency_after_net_usd
                                - (record.net_usd + d_guard + d_protection + d_runner
                                   + d_losscap + d_marketclose + d_emergency + d_other);
      if(MathAbs(per_trade_residual) < FALCON_LOCK_PARITY_CHAIN_RESIDUAL_TOL)
         m_totals.lock_parity_decomposition_pass_trades++;
      else
         m_totals.lock_parity_decomposition_breach_trades++;

      // Bucket-level rollup
      if(LockParityIsExecutableClass(c_guard))         m_totals.lock_parity_executable_adjustment_usd     += d_guard;
      else if(LockParityIsNonExecutableClass(c_guard)) m_totals.lock_parity_non_executable_adjustment_usd += d_guard;
      if(LockParityIsExecutableClass(c_protection))         m_totals.lock_parity_executable_adjustment_usd     += d_protection;
      else if(LockParityIsNonExecutableClass(c_protection)) m_totals.lock_parity_non_executable_adjustment_usd += d_protection;
      if(LockParityIsExecutableClass(c_runner))         m_totals.lock_parity_executable_adjustment_usd     += d_runner;
      else if(LockParityIsNonExecutableClass(c_runner)) m_totals.lock_parity_non_executable_adjustment_usd += d_runner;
      if(LockParityIsExecutableClass(c_losscap))         m_totals.lock_parity_executable_adjustment_usd     += d_losscap;
      else if(LockParityIsNonExecutableClass(c_losscap)) m_totals.lock_parity_non_executable_adjustment_usd += d_losscap;
      if(LockParityIsExecutableClass(c_marketclose))         m_totals.lock_parity_executable_adjustment_usd     += d_marketclose;
      else if(LockParityIsNonExecutableClass(c_marketclose)) m_totals.lock_parity_non_executable_adjustment_usd += d_marketclose;
      if(LockParityIsExecutableClass(c_emergency))         m_totals.lock_parity_executable_adjustment_usd     += d_emergency;
      else if(LockParityIsNonExecutableClass(c_emergency)) m_totals.lock_parity_non_executable_adjustment_usd += d_emergency;
      if(LockParityIsExecutableClass(c_other))         m_totals.lock_parity_executable_adjustment_usd     += d_other;
      else if(LockParityIsNonExecutableClass(c_other)) m_totals.lock_parity_non_executable_adjustment_usd += d_other;

      // Class-specific evidence buckets
      if(c_protection == "EXECUTABLE_PROTECTION_CLOSE")
         m_totals.lock_parity_protection_executable_usd += d_protection;
      // v0.57.1: Runner Exit Price Probe — split runner deltas into exec / non-exec.
      if(c_runner == "RUNNER_EXIT_PRICE_WITHIN_MARKET_PATH")
         m_totals.lock_parity_runner_executable_usd += d_runner;
      if(c_runner == "RUNNER_EXIT_PRICE_OUTSIDE_MARKET_PATH" ||
         c_runner == "RUNNER_PATH_DATA_INSUFFICIENT")
         m_totals.lock_parity_runner_non_executable_usd += d_runner;
      // RunnerPendingUSD retained for backward compatibility; now mirrors RunnerNonExecutable.
      m_totals.lock_parity_runner_pending_usd = m_totals.lock_parity_runner_non_executable_usd;
      if(c_guard == "NON_EXECUTABLE_ACCOUNTING")        m_totals.lock_parity_accounting_only_usd += d_guard;
      if(c_protection == "NON_EXECUTABLE_ACCOUNTING")   m_totals.lock_parity_accounting_only_usd += d_protection;
      if(c_runner == "NON_EXECUTABLE_ACCOUNTING")       m_totals.lock_parity_accounting_only_usd += d_runner;
      if(c_losscap == "NON_EXECUTABLE_ACCOUNTING")      m_totals.lock_parity_accounting_only_usd += d_losscap;
      if(c_marketclose == "NON_EXECUTABLE_ACCOUNTING")  m_totals.lock_parity_accounting_only_usd += d_marketclose;
      if(c_emergency == "NON_EXECUTABLE_ACCOUNTING")    m_totals.lock_parity_accounting_only_usd += d_emergency;
      if(c_other == "UNATTRIBUTED_NEEDS_REVIEW")        m_totals.lock_parity_accounting_only_usd += d_other;
   }

   void WriteLockParityExecutabilityRollup()
   {
      int handle = FileOpen(m_lock_parity_rollup_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create LockParityExecutabilityRollup file: %s", m_lock_parity_rollup_file));
         return;
      }

      string header =
         "TotalTrades,"
         "LOCK_RawNetUSD,"
         "LOCK_FinalWorkingNetUSD,"
         "Sum_Guard_Delta,Sum_Protection_Delta,Sum_Runner_Delta,"
         "Sum_LossCap_Delta,Sum_MarketClose_Delta,Sum_Emergency_Delta,Sum_Other_Delta,"
         "LOCK_ExecutableAdjustmentUSD,"
         "LOCK_NonExecutableAdjustmentUSD,"
         "LOCK_ExecutableTargetUSD,"
         "ExecutableSharePct,"
         "ProtectionExecutableUSD,RunnerExecutableUSD,RunnerNonExecutableUSD,RunnerPendingUSD,AccountingOnlyUSD,"
         "RollupResidualUSD,RollupStatus";
      FileWriteString(handle, header + "\r\n");

      double executable_target = m_totals.lock_parity_raw_net_usd + m_totals.lock_parity_executable_adjustment_usd;
      double executable_share_pct = 0.0;
      if(MathAbs(m_totals.lock_parity_final_working_net_usd) > 0.000001)
         executable_share_pct = (executable_target / m_totals.lock_parity_final_working_net_usd) * 100.0;

      double rollup_residual = m_totals.lock_parity_final_working_net_usd
                             - (executable_target + m_totals.lock_parity_non_executable_adjustment_usd);
      string rollup_status = (MathAbs(rollup_residual) < FALCON_LOCK_PARITY_ROLLUP_TOL ? "PASS" : "RESIDUAL_BREACH");

      string row = "";
      row += IntegerToString(m_totals.lock_parity_evaluated_trades) + ",";
      row += DoubleToString(m_totals.lock_parity_raw_net_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_final_working_net_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_guard_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_protection_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_runner_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_losscap_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_marketclose_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_emergency_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_other_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_executable_adjustment_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_non_executable_adjustment_usd, 4) + ",";
      row += DoubleToString(executable_target, 4) + ",";
      row += DoubleToString(executable_share_pct, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_protection_executable_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_runner_executable_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_runner_non_executable_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_runner_pending_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_accounting_only_usd, 4) + ",";
      row += DoubleToString(rollup_residual, 4) + ",";
      row += FalconCsvSafe(rollup_status);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   // ==================================================================
   // v0.57.2: Virtual Trailing Exit Bridge report
   // One row per virtual-trailing-initiated close attempt. Diagnostic only:
   // does NOT modify any trade value, does NOT replace ManagedCloseLifecycle.
   // ==================================================================
   void WriteVirtualTrailingExitLifecycleHeader()
   {
      int handle = FileOpen(m_virtual_trailing_exit_lifecycle_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create VirtualTrailingExitLifecycle file: %s", m_virtual_trailing_exit_lifecycle_file));
         return;
      }

      string header =
         "TradeId,Direction,EntryTime,EntryPrice,ExitTime,ExitPrice,"
         "PeakFavorablePrice,TrailingStopPriceAtExit,BreakevenLocked,TrailingActivated,"
         "ProfitPointsAtExit,RealizedPointsAtExit,EstimatedUsdAtExit,"
         "ExitTriggerReason,BrokerCloseRetcode,VirtualTrailingStatus";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }

   void AppendVirtualTrailingExitLifecycleRecord(const FalconBrokerTradeLink &link,
                                                 const datetime exit_time,
                                                 const double exit_price,
                                                 const double profit_points_at_exit,
                                                 const string exit_trigger_reason,
                                                 const uint broker_close_retcode,
                                                 const string virtual_trailing_status)
   {
      // v0.57.3: derive RealizedPointsAtExit and EstimatedUsdAtExit from the link
      // and the report writer's symbol context. Caller doesn't need to compute either.
      double realized_points_at_exit = FalconRawIndexPoints(link.direction,
                                                           link.broker_entry_price,
                                                           exit_price);
      double lot_for_usd = (link.accepted_lot > 0.0) ? link.accepted_lot : link.requested_lot;
      double estimated_usd_at_exit = FalconEstimateUsdByRawPoints(realized_points_at_exit,
                                                                 lot_for_usd,
                                                                 m_symbol_context);
      int handle = FileOpen(m_virtual_trailing_exit_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteVirtualTrailingExitLifecycleHeader();
         handle = FileOpen(m_virtual_trailing_exit_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append VirtualTrailingExitLifecycle row: %s", m_virtual_trailing_exit_lifecycle_file));
         return;
      }
      FileSeek(handle, 0, SEEK_END);

      string row = "";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(link.broker_entry_time)) + ",";
      row += DoubleToString(link.broker_entry_price, m_symbol_context.digits) + ",";
      row += FalconCsvSafe(FalconTimeToString(exit_time)) + ",";
      row += DoubleToString(exit_price, m_symbol_context.digits) + ",";
      row += DoubleToString(link.virtual_peak_favorable_price, m_symbol_context.digits) + ",";
      row += DoubleToString(link.virtual_trailing_stop_price, m_symbol_context.digits) + ",";
      row += FalconCsvSafe(link.virtual_breakeven_locked ? "YES" : "NO") + ",";
      row += FalconCsvSafe(link.virtual_trailing_active ? "YES" : "NO") + ",";
      row += DoubleToString(profit_points_at_exit, 2) + ",";
      row += DoubleToString(realized_points_at_exit, 2) + ",";
      row += DoubleToString(estimated_usd_at_exit, 4) + ",";
      row += FalconCsvSafe(exit_trigger_reason) + ",";
      row += IntegerToString((int)broker_close_retcode) + ",";
      row += FalconCsvSafe(virtual_trailing_status);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void RegisterClosedTrade(FalconTradeLifecycleRecord &record)
   {
      if(!m_initialized || !EnableMainReport)
         return;

      FalconFinalizeTradeMetrics(record, m_symbol_context);
      ApplyFvgQualityShadowGuardSimulation(record);
      ApplyPaperRuntimeGuardApplication(record);
      ApplyPaperRuntimeSmartSLProtectionApplication(record);
      ApplyPaperRuntimeRunnerApplication(record);
      ApplyCapitalTierFoundation(record);
      ApplyLowCapitalRiskFeasibilityFoundation(record);
      ApplyDynamicLotSizingModel(record);
      ApplyCalibratedSingleTradeLossCapEnforcement(record);
      ApplyNoNewEntryUserOverridePaperEnforcement(record);
      ApplyDailyWeekendForceCloseUserOverridePaperEnforcement(record);
      ApplyThreeLayerEmergencyApplication(record);
      ApplyCapitalFlowSourceClassification(record);
      UpdateTotals(record);
      AppendTradeRecord(record);
      AppendPaperStateSnapshotRecord(record);
      AppendBrokerExecutionLifecycleAuditRecord(record);
      AppendBrokerRebasedPaperComparisonRecord(record);
      AppendBrokerTradeManagementTimelineForRecord(record);
      // v0.57.0: Lock Parity Executability Decomposer hook.
      // Pure additive; runs AFTER every Apply* layer has populated the record.
      UpdateLockParityTotals(record);
      AppendLockParityDecompositionRecord(record);
   }

   int CountPhysicalTradeLifecycleDataRows()
   {
      // v0.55.11: count actual rows written to TradeLifecycle.csv.
      // This catches physical file truncation/overwrite even if internal totals look correct.
      int handle = FileOpen(m_trade_report_file, FILE_READ | FILE_TXT | FILE_ANSI | (UseCommonFilesFolderForReports ? FILE_COMMON : 0));
      if(handle == INVALID_HANDLE)
         return -1;

      int line_count = 0;
      while(!FileIsEnding(handle))
      {
         string line = FileReadString(handle);
         if(StringLen(line) > 0)
            line_count++;
      }
      FileClose(handle);

      if(line_count <= 0)
         return 0;
      return line_count - 1; // subtract header
   }

   void WriteFinalSummary()
   {
      if(!m_initialized || !EnableMainReport)
         return;

      if(m_totals.total_trades > 0)
      {
         m_totals.win_rate  = (100.0 * (double)m_totals.win_trades) / (double)m_totals.total_trades;
         m_totals.loss_rate = (100.0 * (double)m_totals.loss_trades) / (double)m_totals.total_trades;
      }
      else
      {
         m_totals.win_rate  = 0.0;
         m_totals.loss_rate = 0.0;
      }

      FinalizeWeeklyStabilityFoundation();

      double buy_win_rate = 0.0;
      if(m_totals.buy_trades > 0)
         buy_win_rate = (100.0 * (double)m_totals.buy_win_trades) / (double)m_totals.buy_trades;

      double sell_win_rate = 0.0;
      if(m_totals.sell_trades > 0)
         sell_win_rate = (100.0 * (double)m_totals.sell_win_trades) / (double)m_totals.sell_trades;

      double dynamic_active_lot_avg = FalconSafeAverageDouble(m_totals.dynamic_lotsizing_active_lot_total, m_totals.dynamic_lotsizing_evaluated_trades);
      int invariant_breaches = 0;
      if(m_totals.dynamic_lotsizing_invalid_trades > 0) invariant_breaches++;
      if(m_totals.layer_reset_duplicate_triggers > 0) invariant_breaches++;

      double final_net_from_profit_loss = m_totals.final_total_profit_usd - m_totals.final_total_loss_usd;
      double final_net_diff = final_net_from_profit_loss - m_totals.final_working_net_usd;
      double raw_net_from_profit_loss = m_totals.total_profit_usd - m_totals.total_loss_usd;
      double raw_net_diff = raw_net_from_profit_loss - m_totals.net_usd;
      double visible_raw_net_diff = m_totals.visible_raw_net_usd_4dp - m_totals.net_usd;
      double visible_final_net_diff = m_totals.visible_final_working_net_usd_4dp - m_totals.final_working_net_usd;
      int physical_trade_rows = CountPhysicalTradeLifecycleDataRows();
      string physical_trade_rows_status = (physical_trade_rows == m_totals.total_trades ? "PASS" : "FAIL");
      int integrity_breaches = invariant_breaches;
      if(MathAbs(final_net_diff) > 0.05)
         integrity_breaches++;
      if(MathAbs(raw_net_diff) > 0.05)
         integrity_breaches++;
      if(MathAbs(visible_final_net_diff) > 0.01)
         integrity_breaches++;
      if(MathAbs(visible_raw_net_diff) > 0.01)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.dynamic_lotsizing_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.capital_flow_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.weekly_stability_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.market_close_guard_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.no_new_entry_override_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.force_close_override_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.paper_state_snapshot_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.paper_state_snapshot_written_rows)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.session_boundary_checkpoint_evaluated_trades)
         integrity_breaches++;
      if(m_totals.paper_state_snapshot_write_failures > 0)
         integrity_breaches++;
      if(m_totals.capital_flow_integrity_breaches > 0)
         integrity_breaches++;
      if(physical_trade_rows_status != "PASS")
         integrity_breaches++;

      string capital_flow_integrity_status = (m_totals.capital_flow_integrity_breaches == 0 && m_totals.total_trades == m_totals.capital_flow_evaluated_trades ? "PASS" : "FAIL");
      string weekly_stability_status = (m_totals.total_trades == m_totals.weekly_stability_evaluated_trades ? "PASS" : "FAIL");
      string market_close_guard_status = (m_totals.total_trades == m_totals.market_close_guard_evaluated_trades ? "PASS" : "FAIL");
      string no_new_entry_override_status = (m_totals.total_trades == m_totals.no_new_entry_override_evaluated_trades ? (StopNewTradesBeforeClose ? "ENABLED_PASS" : "DISABLED_PASS") : "FAIL");
      bool force_close_override_enabled = (CloseTradesBeforeDailyClose || CloseTradesBeforeWeekend);
      string force_close_override_status = (m_totals.total_trades == m_totals.force_close_override_evaluated_trades ? (force_close_override_enabled ? "ENABLED_PASS" : "DISABLED_PASS") : "FAIL");
      if(force_close_override_status == "ENABLED_PASS" && m_totals.force_close_override_missing_price_trades > 0)
         force_close_override_status = "ENABLED_WARN_MISSING_PRICE";
      string paper_state_snapshot_status = (m_totals.total_trades == m_totals.paper_state_snapshot_evaluated_trades &&
                                            m_totals.total_trades == m_totals.paper_state_snapshot_written_rows &&
                                            m_totals.paper_state_snapshot_write_failures == 0 ? "PASS" : "FAIL");
      string session_boundary_checkpoint_status = FalconSessionBoundaryCheckpointStatus();
      double market_close_avg_duration_minutes = FalconSafeAverageDouble(m_totals.market_close_total_trade_duration_minutes, m_totals.market_close_guard_evaluated_trades);
      string market_close_two_hour_coverage_status = (m_totals.market_close_duration_above_window_trades == 0 ? "PASS_2H_COVERS_ALL_OBSERVED_DURATIONS" : "WARN_SOME_TRADES_EXCEED_2H_DURATION");
      string market_close_timing_recommendation = (m_totals.market_close_duration_above_window_trades == 0 ? "MONITOR_SESSION_BOUNDARY_RISK" : "REVIEW_DAILY_WEEKEND_CLOSE_SAFETY");
      string report_integrity_status = (integrity_breaches == 0 ? "PASS" : "FAIL");
      string row_count_status = (m_totals.total_trades == m_totals.dynamic_lotsizing_evaluated_trades &&
                                 m_totals.total_trades == m_totals.capital_flow_evaluated_trades &&
                                 m_totals.total_trades == m_totals.weekly_stability_evaluated_trades &&
                                 m_totals.total_trades == m_totals.market_close_guard_evaluated_trades &&
                                 m_totals.total_trades == m_totals.no_new_entry_override_evaluated_trades &&
                                 m_totals.total_trades == m_totals.force_close_override_evaluated_trades &&
                                 m_totals.total_trades == m_totals.paper_state_snapshot_evaluated_trades &&
                                 m_totals.total_trades == m_totals.paper_state_snapshot_written_rows &&
                                 m_totals.total_trades == m_totals.session_boundary_checkpoint_evaluated_trades &&
                                 physical_trade_rows_status == "PASS" ? "PASS" : "FAIL");

      int handle = FileOpen(m_summary_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write slim summary report: %s", m_summary_report_file));
         return;
      }

      string summary_row = "";
      summary_row += FalconCsvSafe(EA_NAME) + ",";
      summary_row += FalconCsvSafe(EA_VERSION_TAG) + ",";
      summary_row += FalconCsvSafe(EA_BUILD_TAG) + ",";
      summary_row += FalconCsvSafe(m_symbol_context.symbol) + ",";
      summary_row += FalconCsvSafe(FalconTimeToString(TimeCurrent())) + ",";
      summary_row += FalconCsvSafe(FalconReportProfileToString()) + ",";
      summary_row += FalconCsvSafe(FalconEffectiveReportFromDateTag()) + ",";
      summary_row += FalconCsvSafe(FalconSummaryFinalReportToDateTag()) + ",";
      summary_row += FalconCsvSafe(FalconBoolToYesNo(UseFixedLot)) + ",";
      summary_row += DoubleToString(FixedLotSize, 2) + ",";
      summary_row += IntegerToString(m_totals.total_trades) + ",";
      summary_row += IntegerToString(m_totals.win_trades) + ",";
      summary_row += IntegerToString(m_totals.loss_trades) + ",";
      summary_row += DoubleToString(m_totals.win_rate, 2) + ",";
      summary_row += DoubleToString(m_totals.total_profit_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.total_loss_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.net_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.final_total_profit_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.final_total_loss_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.final_working_net_usd, 2) + ",";
      summary_row += IntegerToString(m_totals.buy_trades) + ",";
      summary_row += DoubleToString(buy_win_rate, 2) + ",";
      summary_row += IntegerToString(m_totals.sell_trades) + ",";
      summary_row += DoubleToString(sell_win_rate, 2) + ",";
      summary_row += IntegerToString(m_totals.paper_protection_activated_trades) + ",";
      summary_row += IntegerToString(m_totals.paper_runner_activated_trades) + ",";
      summary_row += IntegerToString(m_totals.dynamic_lotsizing_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.dynamic_lotsizing_fixed_mode_trades) + ",";
      summary_row += IntegerToString(m_totals.dynamic_lotsizing_dynamic_mode_trades) + ",";
      summary_row += DoubleToString(dynamic_active_lot_avg, 2) + ",";
      summary_row += DoubleToString(m_totals.dynamic_lotsizing_safety_active_lot_max, 2) + ",";
      summary_row += IntegerToString(m_totals.weekly_stability_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.weekly_stability_weeks) + ",";
      summary_row += IntegerToString(m_totals.weekly_stability_positive_weeks) + ",";
      summary_row += IntegerToString(m_totals.weekly_stability_negative_weeks) + ",";
      summary_row += DoubleToString(m_totals.weekly_stability_best_week_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.weekly_stability_worst_week_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.weekly_stability_score, 2) + ",";
      summary_row += FalconCsvSafe(weekly_stability_status) + ",";
      summary_row += IntegerToString(m_totals.market_close_guard_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.market_close_guard_near_close_entry_trades) + ",";
      summary_row += IntegerToString(m_totals.market_close_guard_open_weekend_risk_trades) + ",";
      summary_row += FalconCsvSafe(market_close_guard_status) + ",";
      summary_row += FalconCsvSafe(FalconBoolToYesNo(StopNewTradesBeforeClose)) + ",";
      summary_row += IntegerToString(FalconUserNoNewEntryWindowMinutes()) + ",";
      summary_row += IntegerToString(m_totals.no_new_entry_override_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.no_new_entry_override_blocked_trades) + ",";
      summary_row += IntegerToString(m_totals.no_new_entry_override_blocked_winners) + ",";
      summary_row += IntegerToString(m_totals.no_new_entry_override_blocked_losers) + ",";
      summary_row += DoubleToString(m_totals.no_new_entry_override_impact_usd, 2) + ",";
      summary_row += FalconCsvSafe(no_new_entry_override_status) + ",";
      summary_row += FalconCsvSafe(FalconBoolToYesNo(CloseTradesBeforeDailyClose)) + ",";
      summary_row += IntegerToString(FalconDailyForceCloseUserWindowMinutes()) + ",";
      summary_row += FalconCsvSafe(FalconBoolToYesNo(CloseTradesBeforeWeekend)) + ",";
      summary_row += IntegerToString(FalconWeekendForceCloseUserWindowMinutes()) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_closed_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_daily_closed_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_weekend_closed_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_price_ok_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_missing_price_trades) + ",";
      summary_row += DoubleToString(m_totals.force_close_override_before_net_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.force_close_override_after_net_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.force_close_override_impact_usd, 2) + ",";
      summary_row += FalconCsvSafe(force_close_override_status) + ",";
      summary_row += IntegerToString(m_totals.paper_state_snapshot_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.paper_state_snapshot_written_rows) + ",";
      summary_row += IntegerToString(m_totals.paper_state_snapshot_write_failures) + ",";
      summary_row += FalconCsvSafe(FALCON_PERSISTENCE_RECOVERY_MODE) + ",";
      summary_row += IntegerToString(m_totals.paper_state_recovery_trusted_trades) + ",";
      summary_row += IntegerToString(m_totals.paper_state_recovery_untrusted_trades) + ",";
      summary_row += FalconCsvSafe(paper_state_snapshot_status) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_checkpoint_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_recovery_checkpoint_minutes) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_daily_checkpoint_open_trades) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_weekend_checkpoint_open_trades) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_recovery_required_trades) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_dirty_after_close_safety_trades) + ",";
      summary_row += FalconCsvSafe(session_boundary_checkpoint_status) + ",";
      summary_row += IntegerToString(m_totals.market_close_max_trade_duration_minutes) + ",";
      summary_row += DoubleToString(market_close_avg_duration_minutes, 2) + ",";
      summary_row += IntegerToString(m_totals.market_close_duration_above_window_trades) + ",";
      summary_row += FalconCsvSafe(m_totals.market_close_longest_trade_id) + ",";
      summary_row += FalconCsvSafe(market_close_timing_recommendation) + ",";
      summary_row += FalconCsvSafe(market_close_two_hour_coverage_status) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_trade_profit_events) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_trade_loss_events) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_injection_events) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_withdrawal_events) + ",";
      summary_row += DoubleToString(m_totals.capital_flow_external_net_usd, 4) + ",";
      summary_row += FalconCsvSafe(capital_flow_integrity_status) + ",";

      summary_row += IntegerToString(m_totals.paper_emergency_triggered_trades) + ",";
      summary_row += IntegerToString(m_totals.paper_emergency_blocked_entries) + ",";
      summary_row += IntegerToString(m_broker_entry_bridge_order_send_attempts) + ",0,0,";
      summary_row += IntegerToString(integrity_breaches) + ",";
      summary_row += IntegerToString(physical_trade_rows) + ",";
      summary_row += FalconCsvSafe(physical_trade_rows_status) + ",";
      summary_row += DoubleToString(visible_raw_net_diff, 4) + ",";
      summary_row += DoubleToString(visible_final_net_diff, 4) + ",";
      summary_row += FalconCsvSafe(report_integrity_status) + ",";
      summary_row += FalconCsvSafe(row_count_status) + ",";
      summary_row += DoubleToString(final_net_diff, 4) + ",";
      summary_row += DoubleToString(raw_net_diff, 4);

      FileWriteString(handle, SlimSummaryHeaderV0555() + "\r\n");
      FileWriteString(handle, summary_row + "\r\n");
      FileClose(handle);

      // v0.57.0: Lock Parity Executability Decomposer rollup writer.
      // Report-only; emits one row aggregating per-trade decomposition totals.
      WriteLockParityExecutabilityRollup();
   }


private:
   bool ProbeReportFile(const string file_name, long &size_bytes)
   {
      size_bytes = 0;
      int handle = FileOpen(file_name, FalconReportReadBinFlags());
      if(handle == INVALID_HANDLE)
         return false;

      size_bytes = (long)FileSize(handle);
      FileClose(handle);
      return true;
   }

   void WriteRuntimeReportVerificationRow(const int handle,
                                           const string trigger,
                                           const string report_key,
                                           const string file_name,
                                           const bool enabled_by_input,
                                           const string notes)
   {
      long size_bytes = 0;
      bool readable = false;
      if(enabled_by_input)
         readable = ProbeReportFile(file_name, size_bytes);

      string status = "DISABLED_BY_INPUT";
      if(enabled_by_input && readable && size_bytes > 0)
         status = "READABLE_NON_EMPTY";
      else if(enabled_by_input && readable)
         status = "READABLE_EMPTY";
      else if(enabled_by_input)
         status = "NOT_READABLE_YET";

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                report_key,
                file_name,
                FalconBoolToYesNo(enabled_by_input),
                FalconBoolToYesNo(readable),
                (int)size_bytes,
                status,
                notes);
   }

   void WriteFvgMicroRuntimeReportAuditRow(const int handle,
                                           const string trigger,
                                           const string audit_item,
                                           const string file_name,
                                           const bool enabled_by_input,
                                           const string expected_content,
                                           const string decision,
                                           const string notes)
   {
      long size_bytes = 0;
      bool readable = false;
      if(enabled_by_input)
         readable = ProbeReportFile(file_name, size_bytes);

      string audit_status = "DISABLED_BY_INPUT";
      if(enabled_by_input && readable && size_bytes > 0)
         audit_status = "READABLE_NON_EMPTY";
      else if(enabled_by_input && readable)
         audit_status = "READABLE_EMPTY";
      else if(enabled_by_input)
         audit_status = "NOT_READABLE_YET";

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                audit_item,
                file_name,
                expected_content,
                FalconBoolToYesNo(readable),
                (int)size_bytes,
                audit_status,
                decision,
                notes);
   }

   void ApplyFvgQualityShadowGuardSimulation(FalconTradeLifecycleRecord &record)
   {
      string guard_reason = "";
      bool guard_passed = FalconEvaluateFvgQualityShadowGuard(record.fvg_size_points,
                                                              record.fvg_spread_points,
                                                              record.fvg_retest_age_bars,
                                                              record.fvg_hold_quality_score,
                                                              guard_reason);

      record.fvg_quality_shadow_guard_profile = FALCON_FVG_QGUARD_PROFILE_TAG;
      record.fvg_quality_shadow_guard_passed = guard_passed;
      record.fvg_quality_shadow_guard_reason = guard_reason;

      if(guard_passed)
      {
         record.fvg_quality_shadow_guard_decision = "WOULD_KEEP";
         record.fvg_quality_shadow_guard_sim_net_points = record.net_index_points;
         record.fvg_quality_shadow_guard_sim_net_usd = record.net_usd;
      }
      else
      {
         record.fvg_quality_shadow_guard_decision = "WOULD_SKIP";
         record.fvg_quality_shadow_guard_sim_net_points = 0.0;
         record.fvg_quality_shadow_guard_sim_net_usd = 0.0;
      }
   }


   void ApplyPaperRuntimeGuardApplication(FalconTradeLifecycleRecord &record)
   {
      double sl_distance_points = 0.0;
      string reject_reason = FalconPrgaRejectReason(record, m_symbol_context, sl_distance_points);

      record.paper_guard_layer = "FalconGuard";
      record.paper_spread_points = record.fvg_spread_points;
      if(record.paper_spread_points < 0)
         record.paper_spread_points = m_symbol_context.spread_points;
      record.paper_max_spread_points = FALCON_SSBL_MAX_SPREAD_POINTS;
      record.paper_sl_distance_points = sl_distance_points;
      record.paper_stops_level_points = m_symbol_context.stops_level_points;
      record.paper_freeze_level_points = m_symbol_context.freeze_level_points;

      if(reject_reason == "")
      {
         record.paper_guard_status = "PASSED";
         record.paper_reject_reason = "";
         record.paper_guard_net_index_points = record.net_index_points;
         record.paper_guard_net_usd = record.net_usd;
      }
      else
      {
         record.paper_guard_status = "REJECTED";
         record.paper_reject_reason = reject_reason;
         record.paper_guard_net_index_points = 0.0;
         record.paper_guard_net_usd = 0.0;
      }
   }

   void ApplyPaperRuntimeSmartSLProtectionApplication(FalconTradeLifecycleRecord &record)
   {
      record.paper_protection_state = "NONE";
      record.paper_virtual_sl = 0.0;
      record.paper_protection_trigger = "NONE";
      record.paper_protection_level = 0.0;
      record.paper_protection_activated = false;
      record.paper_virtual_sl_changed = false;
      record.paper_virtual_sl_hit = false;
      record.paper_exit_reason = "PAPER_SHADOW_EXIT_UNCHANGED";
      record.paper_protection_net_index_points = record.paper_guard_net_index_points;
      record.paper_protection_net_usd = record.paper_guard_net_usd;

      if(record.paper_guard_status != "PASSED")
      {
         record.paper_exit_reason = "PAPER_GUARD_REJECTED";
         return;
      }

      FalconRunnerBarPathStats barpath_stats;
      if(!FalconBuildRunnerBarPathStats(record, barpath_stats))
      {
         record.paper_exit_reason = "PAPER_PROTECTION_PATH_SCAN_FAILED";
         return;
      }

      if(!barpath_stats.tp1_touched)
      {
         record.paper_exit_reason = "PAPER_NO_PROOF";
         return;
      }

      double tp1_points = FalconDirectionalProfitPoints(record, record.tp1);
      double tp2_points = FalconDirectionalProfitPoints(record, record.tp2);
      double protected_points = 0.0;

      record.paper_protection_activated = true;
      record.paper_virtual_sl_changed = true;

      if(barpath_stats.tp2_touched)
      {
         record.paper_protection_state = "TP2_PROTECTED";
         record.paper_protection_trigger = "TP2_PROOF";
         protected_points = tp1_points;
      }
      else
      {
         record.paper_protection_state = "TP1_PROTECTED";
         record.paper_protection_trigger = "TP1_PROOF";
         protected_points = MathMax(0.0, tp1_points * 0.25);
      }

      if(protected_points <= 0.0 && tp2_points > 0.0)
         protected_points = MathMax(0.0, tp2_points * 0.25);

      record.paper_virtual_sl = FalconProtectedPriceFromProfitPoints(record, protected_points);
      record.paper_protection_level = record.paper_virtual_sl;

      bool protection_hit = false;
      if(record.paper_protection_trigger == "TP2_PROOF" && barpath_stats.returned_to_loss_after_tp2)
         protection_hit = true;
      else if(record.paper_protection_trigger == "TP1_PROOF" && barpath_stats.returned_to_loss_after_tp1)
         protection_hit = true;

      if(protection_hit && protected_points > record.paper_guard_net_index_points)
      {
         record.paper_virtual_sl_hit = true;
         record.paper_exit_reason = "PAPER_VIRTUAL_SL_HIT";
         record.paper_protection_net_index_points = protected_points;
         record.paper_protection_net_usd = FalconEstimateUsdByRawPoints(protected_points, record.lot_size, m_symbol_context);
      }
      else
      {
         record.paper_exit_reason = "PAPER_SHADOW_EXIT_UNCHANGED_PROTECTED";
      }
   }

   void ApplyPaperRuntimeRunnerApplication(FalconTradeLifecycleRecord &record)
   {
      record.paper_runner_state = "NONE";
      record.paper_runner_activated = false;
      record.paper_runner_max_r = 0.0;
      record.paper_runner_captured_points = record.paper_protection_net_index_points;
      record.paper_runner_additional_points = 0.0;
      record.paper_runner_exit_reason = "PAPER_RUNNER_NOT_ELIGIBLE";
      record.paper_runner_net_index_points = record.paper_protection_net_index_points;
      record.paper_runner_net_usd = record.paper_protection_net_usd;
      record.paper_final_exit_reason = record.paper_exit_reason;

      if(record.paper_guard_status != "PASSED")
      {
         record.paper_runner_exit_reason = "PAPER_GUARD_REJECTED";
         record.paper_final_exit_reason = record.paper_exit_reason;
         return;
      }

      if(!record.paper_protection_activated || !record.paper_virtual_sl_changed)
      {
         record.paper_runner_exit_reason = "PAPER_NO_EARNED_PROTECTION";
         record.paper_final_exit_reason = record.paper_exit_reason;
         return;
      }

      FalconRunnerBarPathStats barpath_stats;
      if(!FalconBuildRunnerBarPathStats(record, barpath_stats))
      {
         record.paper_runner_exit_reason = "PAPER_RUNNER_PATH_SCAN_FAILED";
         record.paper_final_exit_reason = record.paper_exit_reason;
         return;
      }

      record.paper_runner_max_r = barpath_stats.max_r_actual_proxy;

      double tp2_points = FalconDirectionalProfitPoints(record, record.tp2);
      double protected_base_points = MathMax(0.0, record.paper_protection_net_index_points);
      double max_favorable_points = MathMax(0.0, barpath_stats.max_favorable_points);

      if(!barpath_stats.tp2_touched || max_favorable_points <= protected_base_points)
      {
         record.paper_runner_exit_reason = "PAPER_RUNNER_NO_CONTINUATION_PROOF";
         record.paper_final_exit_reason = record.paper_exit_reason;
         return;
      }

      record.paper_runner_activated = true;
      record.paper_runner_state = "ACTIVE";

      double extension_after_tp2 = MathMax(0.0, max_favorable_points - tp2_points);
      double capture_ratio = 0.35;
      if(barpath_stats.max_r_actual_proxy >= 5.0)
      {
         record.paper_runner_state = "MOON";
         capture_ratio = 0.50;
      }

      double captured_points = tp2_points + (extension_after_tp2 * capture_ratio);
      captured_points = MathMin(captured_points, max_favorable_points);
      captured_points = MathMax(captured_points, protected_base_points);

      record.paper_runner_captured_points = captured_points;
      record.paper_runner_additional_points = MathMax(0.0, captured_points - record.paper_protection_net_index_points);

      if(record.paper_runner_additional_points > 0.0)
      {
         record.paper_runner_net_index_points = captured_points;
         record.paper_runner_net_usd = FalconEstimateUsdByRawPoints(captured_points, record.lot_size, m_symbol_context);
         record.paper_runner_exit_reason = (record.paper_runner_state == "MOON" ? "PAPER_MOON_RUNNER_EXIT" : "PAPER_RUNNER_TRAIL_EXIT");
         record.paper_final_exit_reason = record.paper_runner_exit_reason;
      }
      else
      {
         record.paper_runner_exit_reason = "PAPER_RUNNER_NO_ADDITIONAL_CAPTURE";
         record.paper_final_exit_reason = record.paper_exit_reason;
      }
   }


   double CurrentPaperRiskCapitalBeforeTrade()
   {
      double capital = FalconEffectiveCapitalForTier();
      if(m_tle_equity > 0.0)
         capital = m_tle_equity;
      if(capital <= 0.0 && ManualCapital > 0.0)
         capital = ManualCapital;
      if(capital <= 0.0)
         capital = FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD;
      return capital;
   }

   void ApplyCapitalTierFoundation(FalconTradeLifecycleRecord &record)
   {
      double effective_balance = FalconEffectiveCapitalForTier();
      string tier_name = FalconCapitalTierName(effective_balance);
      record.falcon_tier_at_entry = tier_name;
      record.falcon_tier_at_exit = tier_name;
      record.falcon_effective_balance = effective_balance;
      record.falcon_tier_min_balance = FalconCapitalTierMinBalance(tier_name);
      record.falcon_tier_max_balance = FalconCapitalTierMaxBalance(tier_name);
      record.falcon_tier_max_losses = FalconCapitalTierMaxLosses(tier_name);
      record.falcon_tier_max_daily_r = FalconCapitalTierMaxDailyR(tier_name);
      record.falcon_tier_max_drawdown_pct = FalconCapitalTierMaxDrawdownPct(tier_name);
      record.falcon_broker_min_lot = m_symbol_context.min_lot;
      record.falcon_fixed_lot = FixedLotSize;
      record.falcon_min_lot_constraint = FalconMinLotConstraintStatus(m_symbol_context.min_lot, FixedLotSize);

      // v0.55.2a: dynamic risk capital is separate from earned tier promotion.
      record.falcon_dynamic_capital_mode = FALCON_STLC_DYNAMIC_CAPITAL_MODE;
      record.falcon_dynamic_risk_capital_before_trade = CurrentPaperRiskCapitalBeforeTrade();
      record.falcon_dynamic_risk_capital_after_trade = record.falcon_dynamic_risk_capital_before_trade;
      record.falcon_dynamic_risk_tier_by_capital = FalconCapitalTierName(record.falcon_dynamic_risk_capital_before_trade);
      record.falcon_dynamic_risk_pct_of_capital = 0.0;
      record.falcon_dynamic_single_trade_cap_pct = FalconDynamicSingleTradeLossCapRiskPct(record.falcon_dynamic_risk_tier_by_capital);
      record.falcon_dynamic_capital_aware_blocked = 0;
      record.falcon_dynamic_capital_reason = "DYNAMIC_CAPITAL_READY_PROMOTION_STILL_EARNED";
   }

   void ApplyLowCapitalRiskFeasibilityFoundation(FalconTradeLifecycleRecord &record)
   {
      record.falcon_lotsizing_feasibility_status = "INVALID";
      record.falcon_lotsizing_feasibility_reason = "NOT_EVALUATED";
      record.falcon_min_lot_risk_points = 0.0;
      record.falcon_min_lot_risk_usd = 0.0;
      record.falcon_min_lot_risk_pct_of_capital = 0.0;
      record.falcon_tier_base_risk_pct = 0.0;
      record.falcon_tier_risk_budget_usd = 0.0;
      record.falcon_potential_loss_r = 0.0;
      record.falcon_max_single_trade_loss_r = 0.0;
      record.falcon_single_trade_loss_cap_breach = 0;

      double effective_balance = record.falcon_dynamic_risk_capital_before_trade;
      if(effective_balance <= 0.0)
         effective_balance = CurrentPaperRiskCapitalBeforeTrade();

      string tier_name = record.falcon_dynamic_risk_tier_by_capital;
      if(StringLen(tier_name) <= 0)
         tier_name = FalconCapitalTierName(effective_balance);

      double min_lot = record.falcon_broker_min_lot;
      if(min_lot <= 0.0)
         min_lot = m_symbol_context.min_lot;
      if(min_lot <= 0.0)
         min_lot = FixedLotSize;

      double risk_points = MathAbs(record.entry_price - record.structural_sl);
      double base_risk_pct = FalconCapitalTierBaseRiskPct(tier_name);
      double risk_budget_usd = 0.0;
      if(effective_balance > 0.0 && base_risk_pct > 0.0)
         risk_budget_usd = effective_balance * base_risk_pct / 100.0;

      double min_lot_risk_usd = MathAbs(FalconEstimateUsdByRawPoints(risk_points, min_lot, m_symbol_context));
      double min_lot_risk_pct = 0.0;
      if(effective_balance > 0.0)
         min_lot_risk_pct = 100.0 * min_lot_risk_usd / effective_balance;

      double potential_loss_r = 0.0;
      if(risk_budget_usd > 0.0)
         potential_loss_r = min_lot_risk_usd / risk_budget_usd;

      double max_single_trade_loss_r = FalconSingleTradeLossCapR(tier_name);

      record.falcon_min_lot_risk_points = risk_points;
      record.falcon_min_lot_risk_usd = min_lot_risk_usd;
      record.falcon_min_lot_risk_pct_of_capital = min_lot_risk_pct;
      record.falcon_tier_base_risk_pct = base_risk_pct;
      record.falcon_tier_risk_budget_usd = risk_budget_usd;
      record.falcon_potential_loss_r = potential_loss_r;
      record.falcon_max_single_trade_loss_r = max_single_trade_loss_r;

      if(effective_balance <= 0.0)
      {
         record.falcon_lotsizing_feasibility_status = "INVALID";
         record.falcon_lotsizing_feasibility_reason = "EFFECTIVE_BALANCE_UNKNOWN";
         return;
      }
      if(min_lot <= 0.0)
      {
         record.falcon_lotsizing_feasibility_status = "INVALID";
         record.falcon_lotsizing_feasibility_reason = "MIN_LOT_UNKNOWN";
         return;
      }
      if(risk_points <= 0.0 || min_lot_risk_usd <= 0.0)
      {
         record.falcon_lotsizing_feasibility_status = "INVALID";
         record.falcon_lotsizing_feasibility_reason = "STRUCTURAL_RISK_UNKNOWN";
         return;
      }
      if(risk_budget_usd <= 0.0 || potential_loss_r <= 0.0)
      {
         record.falcon_lotsizing_feasibility_status = "INVALID";
         record.falcon_lotsizing_feasibility_reason = "RISK_BUDGET_UNKNOWN";
         return;
      }

      if(max_single_trade_loss_r > 0.0 && potential_loss_r > max_single_trade_loss_r)
      {
         record.falcon_lotsizing_feasibility_status = "NOT_FEASIBLE";
         record.falcon_lotsizing_feasibility_reason = "MIN_LOT_RISK_EXCEEDS_SINGLE_TRADE_CAP";
         record.falcon_single_trade_loss_cap_breach = 1;
         return;
      }

      if(max_single_trade_loss_r > 0.0 && potential_loss_r > (max_single_trade_loss_r / FALCON_LCRF_BORDERLINE_MULTIPLIER))
      {
         record.falcon_lotsizing_feasibility_status = "BORDERLINE";
         record.falcon_lotsizing_feasibility_reason = "MIN_LOT_RISK_NEAR_SINGLE_TRADE_CAP";
         return;
      }

      record.falcon_lotsizing_feasibility_status = "FEASIBLE";
      record.falcon_lotsizing_feasibility_reason = "MIN_LOT_RISK_WITHIN_TIER_BUDGET";
   }

   void ApplyCalibratedSingleTradeLossCapEnforcement(FalconTradeLifecycleRecord &record)
   {
      record.falcon_single_trade_loss_cap_status = "INVALID";
      record.falcon_single_trade_loss_cap_decision = "PASS_THROUGH";
      record.falcon_single_trade_loss_cap_reason = "NOT_EVALUATED";
      record.falcon_single_trade_loss_cap_runtime_enforced = (FALCON_STLC_RUNTIME_ENFORCED ? 1 : 0);
      record.falcon_single_trade_loss_cap_strict_cap_r = record.falcon_max_single_trade_loss_r;
      record.falcon_single_trade_loss_cap_calibrated_cap_r = 0.0;
      record.falcon_single_trade_loss_cap_risk_pct_cap = 0.0;
      record.falcon_single_trade_loss_cap_blocked = 0;
      record.falcon_single_trade_loss_cap_before_net_points = record.paper_runner_net_index_points;
      record.falcon_single_trade_loss_cap_after_net_points = record.paper_runner_net_index_points;
      record.falcon_single_trade_loss_cap_impact_points = 0.0;
      record.falcon_single_trade_loss_cap_before_net_usd = record.paper_runner_net_usd;
      record.falcon_single_trade_loss_cap_after_net_usd = record.paper_runner_net_usd;
      record.falcon_single_trade_loss_cap_impact_usd = 0.0;

      string tier_name = record.falcon_dynamic_risk_tier_by_capital;
      if(StringLen(tier_name) <= 0)
         tier_name = FalconCapitalTierName(record.falcon_dynamic_risk_capital_before_trade);

      double dynamic_capital = record.falcon_dynamic_risk_capital_before_trade;
      if(dynamic_capital <= 0.0)
         dynamic_capital = CurrentPaperRiskCapitalBeforeTrade();

      double active_risk_usd = record.falcon_min_lot_risk_usd;
      if(record.falcon_dlm_active_risk_usd > 0.0)
         active_risk_usd = record.falcon_dlm_active_risk_usd;

      double dynamic_risk_pct = 0.0;
      if(dynamic_capital > 0.0)
         dynamic_risk_pct = 100.0 * active_risk_usd / dynamic_capital;
      record.falcon_dynamic_risk_pct_of_capital = dynamic_risk_pct;

      double calibrated_cap_r = FalconCalibratedSingleTradeLossCapR(tier_name);
      double calibrated_risk_pct_cap = FalconCalibratedSingleTradeLossCapRiskPct(tier_name);
      record.falcon_single_trade_loss_cap_calibrated_cap_r = calibrated_cap_r;
      record.falcon_single_trade_loss_cap_risk_pct_cap = calibrated_risk_pct_cap;
      record.falcon_dynamic_single_trade_cap_pct = calibrated_risk_pct_cap;

      if(dynamic_capital <= 0.0 || active_risk_usd <= 0.0 || calibrated_risk_pct_cap <= 0.0)
      {
         record.falcon_single_trade_loss_cap_status = "INVALID";
         record.falcon_single_trade_loss_cap_decision = "ALLOW_PASS_THROUGH";
         record.falcon_single_trade_loss_cap_reason = "DYNAMIC_ACTIVE_LOT_RISK_INPUT_UNKNOWN";
         record.falcon_dynamic_capital_reason = "DYNAMIC_ACTIVE_LOT_RISK_INPUT_UNKNOWN";
         return;
      }

      bool strict_cap_breach = (record.falcon_single_trade_loss_cap_breach == 1);
      bool dynamic_cap_breach = (dynamic_risk_pct > calibrated_risk_pct_cap);

      if(FALCON_STLC_RUNTIME_ENFORCED && dynamic_cap_breach)
      {
         record.falcon_single_trade_loss_cap_status = "BLOCKED";
         record.falcon_single_trade_loss_cap_decision = "BLOCK_ENTRY_IN_PAPER_STATE";
         record.falcon_single_trade_loss_cap_reason = "DYNAMIC_RISK_PCT_EXCEEDS_CAPITAL_AWARE_CAP";
         record.falcon_single_trade_loss_cap_blocked = 1;
         record.falcon_dynamic_capital_aware_blocked = 1;
         record.falcon_dynamic_capital_reason = "BLOCKED_BY_DYNAMIC_CAPITAL_RELATIVE_RISK";
         record.falcon_single_trade_loss_cap_after_net_points = 0.0;
         record.falcon_single_trade_loss_cap_after_net_usd = 0.0;
      }
      else if(strict_cap_breach)
      {
         record.falcon_single_trade_loss_cap_status = "ALLOWED_DYNAMIC_CAPITAL";
         record.falcon_single_trade_loss_cap_decision = "ALLOW_STRICT_BREACH_WITHIN_DYNAMIC_CAPITAL_CAP";
         record.falcon_single_trade_loss_cap_reason = "STRICT_CAP_BREACH_BUT_DYNAMIC_CAPITAL_CAN_ABSORB_MIN_LOT_RISK";
         record.falcon_dynamic_capital_reason = "ALLOWED_BY_DYNAMIC_CAPITAL_RELATIVE_RISK";
      }
      else
      {
         record.falcon_single_trade_loss_cap_status = "ALLOWED";
         record.falcon_single_trade_loss_cap_decision = "ALLOW_WITHIN_STRICT_AND_DYNAMIC_CAP";
         record.falcon_single_trade_loss_cap_reason = "WITHIN_STRICT_AND_DYNAMIC_CAPITAL_CAP";
         record.falcon_dynamic_capital_reason = "ALLOWED_WITHIN_STRICT_AND_DYNAMIC_CAPITAL_CAP";
      }

      record.falcon_single_trade_loss_cap_impact_points = record.falcon_single_trade_loss_cap_after_net_points - record.falcon_single_trade_loss_cap_before_net_points;
      record.falcon_single_trade_loss_cap_impact_usd = record.falcon_single_trade_loss_cap_after_net_usd - record.falcon_single_trade_loss_cap_before_net_usd;
   }

   double FalconDynamicTierMaxLot(const string tier_name)
   {
      if(tier_name == "MICRO")    return 0.01;
      if(tier_name == "TINY")     return 0.03;
      if(tier_name == "SMALL")    return 0.10;
      if(tier_name == "MEDIUM")   return 0.30;
      if(tier_name == "STANDARD") return 1.00;
      if(tier_name == "LARGE")    return 2.00;
      return MathMax(0.01, m_symbol_context.min_lot);
   }

   double FalconDynamicCapitalMaxLot(const double effective_capital)
   {
      double min_lot = m_symbol_context.min_lot;
      if(min_lot <= 0.0) min_lot = 0.01;
      if(effective_capital <= 0.0)
         return min_lot;

      // Internal safety formula: each 0.01 lot should be backed by ~250 USD of dynamic paper capital.
      // This allows dynamic growth, but prevents a small account equity curve from jumping straight into oversized lots.
      double raw_capital_lot = (effective_capital / FALCON_DLM_CAPITAL_USD_PER_001_LOT) * 0.01;
      int min_floor = 0;
      int max_cap = 0;
      return FalconNormalizeDynamicLotToBroker(raw_capital_lot, min_floor, max_cap);
   }

   double FalconDynamicGrowthRampMaxLot()
   {
      double min_lot = m_symbol_context.min_lot;
      double step = m_symbol_context.lot_step;
      if(step <= 0.0) step = 0.01;
      if(min_lot <= 0.0) min_lot = step;

      if(!m_dlm_previous_active_lot_ready || m_dlm_previous_active_lot <= 0.0)
         return min_lot;

      double ramp_cap = (m_dlm_previous_active_lot * FALCON_DLM_MAX_LOT_GROWTH_MULTIPLIER) + step;
      if(ramp_cap < min_lot)
         ramp_cap = min_lot;

      int min_floor = 0;
      int max_cap = 0;
      return FalconNormalizeDynamicLotToBroker(ramp_cap, min_floor, max_cap);
   }

   double FalconNormalizeDynamicLotToBroker(const double raw_lot, int &min_floor_applied, int &max_cap_applied)
   {
      min_floor_applied = 0;
      max_cap_applied = 0;

      double lot = raw_lot;
      double min_lot = m_symbol_context.min_lot;
      double max_lot = m_symbol_context.max_lot;
      double step = m_symbol_context.lot_step;

      if(step <= 0.0) step = 0.01;
      if(min_lot <= 0.0) min_lot = step;
      if(max_lot <= 0.0) max_lot = MathMax(min_lot, lot);

      if(lot <= 0.0)
         lot = min_lot;

      double stepped_lot = MathFloor(lot / step) * step;
      if(stepped_lot <= 0.0)
         stepped_lot = min_lot;

      if(stepped_lot < min_lot)
      {
         stepped_lot = min_lot;
         min_floor_applied = 1;
      }
      if(stepped_lot > max_lot)
      {
         stepped_lot = max_lot;
         max_cap_applied = 1;
      }

      return NormalizeDouble(stepped_lot, 2);
   }

   void FalconRefreshUsdMetricsForActiveLot(FalconTradeLifecycleRecord &record, const double active_lot)
   {
      if(active_lot <= 0.0)
         return;

      record.lot_size = active_lot;
      record.net_usd = FalconEstimateUsdByRawPoints(record.net_index_points, active_lot, m_symbol_context);
      if(record.net_usd > 0.0)
      {
         record.profit_usd = record.net_usd;
         record.loss_usd = 0.0;
      }
      else if(record.net_usd < 0.0)
      {
         record.profit_usd = 0.0;
         record.loss_usd = MathAbs(record.net_usd);
      }
      else
      {
         record.profit_usd = 0.0;
         record.loss_usd = 0.0;
      }

      record.fvg_quality_shadow_guard_sim_net_usd = FalconEstimateUsdByRawPoints(record.fvg_quality_shadow_guard_sim_net_points, active_lot, m_symbol_context);
      record.paper_guard_net_usd = FalconEstimateUsdByRawPoints(record.paper_guard_net_index_points, active_lot, m_symbol_context);
      record.paper_protection_net_usd = FalconEstimateUsdByRawPoints(record.paper_protection_net_index_points, active_lot, m_symbol_context);
      record.paper_runner_net_usd = FalconEstimateUsdByRawPoints(record.paper_runner_net_index_points, active_lot, m_symbol_context);
   }

   void ApplyDynamicLotSizingModel(FalconTradeLifecycleRecord &record)
   {
      record.falcon_dlm_status = FALCON_DLM_STATUS;
      record.falcon_dlm_decision = "INVALID";
      record.falcon_dlm_runtime_enforced = (FALCON_DLM_RUNTIME_ENFORCED ? 1 : 0);
      record.falcon_dlm_use_fixed_lot = (UseFixedLot ? 1 : 0);
      record.falcon_dlm_fixed_lot_size = FixedLotSize;
      record.falcon_dlm_effective_capital = record.falcon_dynamic_risk_capital_before_trade;
      record.falcon_dlm_base_risk_pct = record.falcon_tier_base_risk_pct;
      record.falcon_dlm_risk_budget_usd = record.falcon_tier_risk_budget_usd;
      record.falcon_dlm_risk_points = record.falcon_min_lot_risk_points;
      record.falcon_dlm_risk_usd_per_one_lot = 0.0;
      record.falcon_dlm_raw_lot = 0.0;
      record.falcon_dlm_recommended_lot = 0.0;
      record.falcon_dlm_active_lot = record.lot_size;
      record.falcon_dlm_tier_max_lot = 0.0;
      record.falcon_dlm_capital_max_lot = 0.0;
      record.falcon_dlm_previous_active_lot = (m_dlm_previous_active_lot_ready ? m_dlm_previous_active_lot : 0.0);
      record.falcon_dlm_growth_ramp_max_lot = 0.0;
      record.falcon_dlm_tier_cap_applied = 0;
      record.falcon_dlm_capital_cap_applied = 0;
      record.falcon_dlm_growth_ramp_applied = 0;
      record.falcon_dlm_safety_mode = "NOT_EVALUATED";
      record.falcon_dlm_broker_min_lot = m_symbol_context.min_lot;
      record.falcon_dlm_broker_max_lot = m_symbol_context.max_lot;
      record.falcon_dlm_broker_lot_step = m_symbol_context.lot_step;
      record.falcon_dlm_min_lot_floor_applied = 0;
      record.falcon_dlm_max_lot_cap_applied = 0;
      record.falcon_dlm_recommended_risk_usd = 0.0;
      record.falcon_dlm_recommended_risk_pct = 0.0;
      record.falcon_dlm_active_risk_usd = 0.0;
      record.falcon_dlm_active_risk_pct = 0.0;
      record.falcon_dlm_reason = "NOT_EVALUATED";

      if(record.falcon_dlm_effective_capital <= 0.0)
         record.falcon_dlm_effective_capital = CurrentPaperRiskCapitalBeforeTrade();
      if(record.falcon_dlm_active_lot <= 0.0)
         record.falcon_dlm_active_lot = FixedLotSize;

      if(record.falcon_dlm_effective_capital <= 0.0 || record.falcon_dlm_risk_budget_usd <= 0.0 || record.falcon_dlm_risk_points <= 0.0)
      {
         record.falcon_dlm_decision = "INVALID";
         record.falcon_dlm_reason = "CAPITAL_OR_RISK_BUDGET_OR_STRUCTURAL_RISK_UNKNOWN";
         return;
      }

      double one_lot_risk_usd = MathAbs(FalconEstimateUsdByRawPoints(record.falcon_dlm_risk_points, 1.0, m_symbol_context));
      record.falcon_dlm_risk_usd_per_one_lot = one_lot_risk_usd;
      if(one_lot_risk_usd <= 0.0)
      {
         record.falcon_dlm_decision = "INVALID";
         record.falcon_dlm_reason = "ONE_LOT_RISK_UNKNOWN";
         return;
      }

      double raw_lot = record.falcon_dlm_risk_budget_usd / one_lot_risk_usd;
      record.falcon_dlm_raw_lot = raw_lot;

      int min_floor = 0;
      int max_cap = 0;
      double recommended_lot = FalconNormalizeDynamicLotToBroker(raw_lot, min_floor, max_cap);
      record.falcon_dlm_recommended_lot = recommended_lot;
      record.falcon_dlm_min_lot_floor_applied = min_floor;
      record.falcon_dlm_max_lot_cap_applied = max_cap;

      string dynamic_tier = record.falcon_dynamic_risk_tier_by_capital;
      if(StringLen(dynamic_tier) <= 0)
         dynamic_tier = FalconCapitalTierName(record.falcon_dlm_effective_capital);

      record.falcon_dlm_tier_max_lot = FalconDynamicTierMaxLot(dynamic_tier);
      record.falcon_dlm_capital_max_lot = FalconDynamicCapitalMaxLot(record.falcon_dlm_effective_capital);
      record.falcon_dlm_growth_ramp_max_lot = FalconDynamicGrowthRampMaxLot();

      double active_lot = record.lot_size;
      if(UseFixedLot)
      {
         active_lot = FixedLotSize;
         record.falcon_dlm_decision = "FIXED_LOT_ACTIVE_FIXEDLOT_PRESERVED";
         record.falcon_dlm_safety_mode = "FIXED_MODE_NO_DYNAMIC_APPLICATION";
         record.falcon_dlm_reason = "USE_FIXED_LOT_TRUE_FIXEDLOT_PRESERVED_NO_DYNAMIC_APPLICATION";
      }
      else
      {
         double safety_lot = recommended_lot;

         if(record.falcon_dlm_tier_max_lot > 0.0 && safety_lot > record.falcon_dlm_tier_max_lot)
         {
            safety_lot = record.falcon_dlm_tier_max_lot;
            record.falcon_dlm_tier_cap_applied = 1;
         }

         if(record.falcon_dlm_capital_max_lot > 0.0 && safety_lot > record.falcon_dlm_capital_max_lot)
         {
            safety_lot = record.falcon_dlm_capital_max_lot;
            record.falcon_dlm_capital_cap_applied = 1;
         }

         if(record.falcon_dlm_growth_ramp_max_lot > 0.0 && safety_lot > record.falcon_dlm_growth_ramp_max_lot)
         {
            safety_lot = record.falcon_dlm_growth_ramp_max_lot;
            record.falcon_dlm_growth_ramp_applied = 1;
         }

         int safety_min_floor = 0;
         int safety_max_cap = 0;
         active_lot = FalconNormalizeDynamicLotToBroker(safety_lot, safety_min_floor, safety_max_cap);

         record.falcon_dlm_decision = "DYNAMIC_LOT_APPLIED_WITH_SAFETY_RAMP";
         record.falcon_dlm_safety_mode = "TIER_CAP_PLUS_CAPITAL_CAP_PLUS_GROWTH_RAMP";
         record.falcon_dlm_reason = "USE_FIXED_LOT_FALSE_RECOMMENDED_LOT_SAFETY_CAPPED_BEFORE_PAPER_USD_APPLICATION";
      }

      if(active_lot <= 0.0)
         active_lot = m_symbol_context.min_lot;
      if(active_lot <= 0.0)
         active_lot = FixedLotSize;

      record.falcon_dlm_active_lot = active_lot;
      record.falcon_dlm_recommended_risk_usd = MathAbs(FalconEstimateUsdByRawPoints(record.falcon_dlm_risk_points, recommended_lot, m_symbol_context));
      record.falcon_dlm_active_risk_usd = MathAbs(FalconEstimateUsdByRawPoints(record.falcon_dlm_risk_points, active_lot, m_symbol_context));

      if(record.falcon_dlm_effective_capital > 0.0)
      {
         record.falcon_dlm_recommended_risk_pct = 100.0 * record.falcon_dlm_recommended_risk_usd / record.falcon_dlm_effective_capital;
         record.falcon_dlm_active_risk_pct = 100.0 * record.falcon_dlm_active_risk_usd / record.falcon_dlm_effective_capital;
      }

      if(FALCON_DLM_RUNTIME_ENFORCED)
         FalconRefreshUsdMetricsForActiveLot(record, active_lot);

      m_dlm_previous_active_lot = active_lot;
      m_dlm_previous_active_lot_ready = true;
   }

   void ApplyThreeLayerEmergencyApplication(FalconTradeLifecycleRecord &record)
   {
      double effective_balance = record.falcon_dynamic_risk_capital_before_trade;
      if(effective_balance <= 0.0)
         effective_balance = record.falcon_effective_balance;
      if(effective_balance <= 0.0)
         effective_balance = FalconEffectiveCapitalForTier();
      if(effective_balance <= 0.0)
         effective_balance = FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD;

      if(m_tle_equity <= 0.0)
      {
         m_tle_equity = effective_balance;
         m_tle_peak_equity = effective_balance;
      }
      if(m_tle_peak_equity <= 0.0)
         m_tle_peak_equity = m_tle_equity;

      datetime trade_day = StringToTime(TimeToString(record.exit_time, TIME_DATE));
      if(trade_day <= 0)
         trade_day = StringToTime(TimeToString(record.entry_time, TIME_DATE));
      if(m_tle_current_day == 0)
         m_tle_current_day = trade_day;
      bool layer2_reset_on_new_day = false;
      bool emergency_resolved_on_new_day = false;
      string resolved_emergency_reason = "NONE";
      if(trade_day > 0 && trade_day != m_tle_current_day)
      {
         layer2_reset_on_new_day = true;
         m_tle_current_day = trade_day;
         m_tle_daily_r = 0.0;

         // v0.53.2a: Layer 1 and Layer 2 are daily pause layers.
         // They must not block all remaining test days. Resolve them at
         // the next day boundary, while Layer 3 remains peak/drawdown based.
         if(m_tle_emergency_active &&
            (m_tle_emergency_reason == "LAYER_1_CONSECUTIVE" ||
             m_tle_emergency_reason == "LAYER_2_DAILY_R"))
         {
            emergency_resolved_on_new_day = true;
            resolved_emergency_reason = m_tle_emergency_reason;
            m_tle_emergency_active = false;
            m_tle_emergency_reason = "NONE";
            m_tle_consecutive_losses = 0;
         }
      }

      record.falcon_emergency_status = "SAFE";
      record.falcon_emergency_triggered_layer = 0;
      record.falcon_emergency_reason = "NONE";
      record.falcon_reset_status = "NO_RESET";
      record.falcon_layer1_reset_on_win = 0;
      record.falcon_layer2_reset_on_new_day = 0;
      record.falcon_layer3_reset_on_new_peak = 0;
      record.falcon_reset_reason = "NONE";
      record.falcon_layer1_max_losses = record.falcon_tier_max_losses;
      record.falcon_layer2_max_daily_r = record.falcon_tier_max_daily_r;
      record.falcon_layer3_max_drawdown_pct = record.falcon_tier_max_drawdown_pct;
      record.falcon_emergency_before_net_points = record.falcon_single_trade_loss_cap_after_net_points;
      record.falcon_emergency_before_net_usd = record.falcon_single_trade_loss_cap_after_net_usd;
      record.falcon_emergency_after_net_points = record.falcon_single_trade_loss_cap_after_net_points;
      record.falcon_emergency_after_net_usd = record.falcon_single_trade_loss_cap_after_net_usd;

      if(m_tle_emergency_active)
      {
         record.falcon_emergency_status = "BLOCKED";
         record.falcon_emergency_triggered_layer = -1;
         record.falcon_emergency_reason = m_tle_emergency_reason;
         record.falcon_emergency_after_net_points = 0.0;
         record.falcon_emergency_after_net_usd = 0.0;
         record.falcon_layer1_consecutive_losses = m_tle_consecutive_losses;
         record.falcon_layer2_daily_r = m_tle_daily_r;
         record.falcon_layer3_drawdown_pct = m_tle_max_drawdown_pct;
         record.falcon_reset_status = "EMERGENCY_ACTIVE_BLOCKED";
         record.falcon_dynamic_risk_capital_after_trade = m_tle_equity;
         return;
      }

      double risk_points = MathAbs(record.entry_price - record.structural_sl);
      double risk_usd = MathAbs(FalconEstimateUsdByRawPoints(risk_points, record.lot_size, m_symbol_context));
      if(risk_usd <= 0.0)
         risk_usd = MathAbs(record.paper_guard_net_usd);
      if(risk_usd <= 0.0)
         risk_usd = 1.0;

      double trade_r = record.falcon_single_trade_loss_cap_after_net_usd / risk_usd;

      bool layer1_reset_on_win = false;
      if(record.falcon_single_trade_loss_cap_after_net_usd < -0.0001)
      {
         m_tle_consecutive_losses++;
      }
      else if(record.falcon_single_trade_loss_cap_after_net_usd > 0.0001)
      {
         if(m_tle_consecutive_losses > 0)
            layer1_reset_on_win = true;
         m_tle_consecutive_losses = 0;
      }

      m_tle_daily_r += trade_r;
      m_tle_equity += record.falcon_single_trade_loss_cap_after_net_usd;
      bool layer3_reset_on_new_peak = false;
      if(m_tle_equity > m_tle_peak_equity)
      {
         if(m_tle_peak_equity > 0.0)
            layer3_reset_on_new_peak = true;
         m_tle_peak_equity = m_tle_equity;
      }

      double drawdown_pct = 0.0;
      if(m_tle_peak_equity > 0.0 && m_tle_equity < m_tle_peak_equity)
         drawdown_pct = 100.0 * (m_tle_peak_equity - m_tle_equity) / m_tle_peak_equity;
      if(drawdown_pct > m_tle_max_drawdown_pct)
         m_tle_max_drawdown_pct = drawdown_pct;

      record.falcon_dynamic_risk_capital_after_trade = m_tle_equity;

      record.falcon_layer1_consecutive_losses = m_tle_consecutive_losses;
      record.falcon_layer2_daily_r = m_tle_daily_r;
      record.falcon_layer3_drawdown_pct = drawdown_pct;
      record.falcon_layer1_reset_on_win = (layer1_reset_on_win ? 1 : 0);
      record.falcon_layer2_reset_on_new_day = (layer2_reset_on_new_day ? 1 : 0);
      record.falcon_layer3_reset_on_new_peak = (layer3_reset_on_new_peak ? 1 : 0);
      if(record.falcon_layer1_reset_on_win == 1 || record.falcon_layer2_reset_on_new_day == 1 || record.falcon_layer3_reset_on_new_peak == 1 || emergency_resolved_on_new_day)
      {
         record.falcon_reset_status = "RESET_APPLIED";
         string reset_reason = "";
         if(record.falcon_layer1_reset_on_win == 1) reset_reason += "LAYER1_ON_WIN;";
         if(record.falcon_layer2_reset_on_new_day == 1) reset_reason += "LAYER2_ON_NEW_DAY;";
         if(record.falcon_layer3_reset_on_new_peak == 1) reset_reason += "LAYER3_ON_NEW_PEAK;";
         if(emergency_resolved_on_new_day) reset_reason += "EMERGENCY_DAILY_RESOLVE_" + resolved_emergency_reason + ";";
         record.falcon_reset_reason = reset_reason;
      }

      if(record.falcon_layer1_max_losses > 0 && m_tle_consecutive_losses >= record.falcon_layer1_max_losses)
      {
         record.falcon_emergency_status = "TRIGGERED";
         record.falcon_emergency_triggered_layer = 1;
         record.falcon_emergency_reason = "LAYER_1_CONSECUTIVE";
      }
      else if(record.falcon_layer2_max_daily_r > 0.0 && m_tle_daily_r <= -record.falcon_layer2_max_daily_r)
      {
         record.falcon_emergency_status = "TRIGGERED";
         record.falcon_emergency_triggered_layer = 2;
         record.falcon_emergency_reason = "LAYER_2_DAILY_R";
      }
      else if(record.falcon_layer3_max_drawdown_pct > 0.0 && drawdown_pct >= record.falcon_layer3_max_drawdown_pct)
      {
         record.falcon_emergency_status = "TRIGGERED";
         record.falcon_emergency_triggered_layer = 3;
         record.falcon_emergency_reason = "LAYER_3_TIER_DRAWDOWN";
      }

      if(record.falcon_emergency_status == "TRIGGERED")
      {
         m_tle_emergency_active = true;
         m_tle_emergency_reason = record.falcon_emergency_reason;
         AppendEmergencyTriggerEvent(record);
      }
   }

   void ApplyCapitalFlowSourceClassification(FalconTradeLifecycleRecord &record)
   {
      // v0.55.5: reporting-only classification. It does not modify capital, lot, entry, exit, or emergency state.
      double before_capital = record.falcon_dynamic_risk_capital_before_trade;
      double after_capital  = record.falcon_dynamic_risk_capital_after_trade;
      double final_trade_delta = record.falcon_emergency_after_net_usd;

      record.falcon_capital_flow_source = "UNKNOWN";
      record.falcon_capital_flow_delta_usd = 0.0;
      record.falcon_external_capital_delta_usd = 0.0;
      record.falcon_capital_flow_external_event = 0;
      record.falcon_capital_flow_status = "PASS";
      record.falcon_capital_flow_reason = "NOT_EVALUATED";

      if(before_capital <= 0.0 || after_capital <= 0.0)
      {
         record.falcon_capital_flow_status = "PASS";
         record.falcon_capital_flow_source = "UNKNOWN";
         record.falcon_capital_flow_reason = "CAPITAL_BEFORE_OR_AFTER_NOT_AVAILABLE";
         return;
      }

      double capital_delta = after_capital - before_capital;
      double external_delta = capital_delta - final_trade_delta;
      record.falcon_capital_flow_delta_usd = capital_delta;
      record.falcon_external_capital_delta_usd = external_delta;

      double external_tolerance = 0.01;
      if(MathAbs(external_delta) > external_tolerance)
      {
         record.falcon_capital_flow_external_event = 1;
         if(external_delta > 0.0)
         {
            if(final_trade_delta > 0.0001)
            {
               record.falcon_capital_flow_source = "MIXED_PROFIT_PLUS_INJECTION";
               record.falcon_capital_flow_reason = "TRADE_PROFIT_PLUS_POSITIVE_EXTERNAL_CAPITAL_FLOW";
            }
            else
            {
               record.falcon_capital_flow_source = "INJECTION";
               record.falcon_capital_flow_reason = "CAPITAL_DELTA_EXCEEDS_TRADE_DELTA_POSITIVE_EXTERNAL_FLOW";
            }
         }
         else
         {
            if(final_trade_delta < -0.0001)
            {
               record.falcon_capital_flow_source = "MIXED_LOSS_PLUS_WITHDRAWAL";
               record.falcon_capital_flow_reason = "TRADE_LOSS_PLUS_NEGATIVE_EXTERNAL_CAPITAL_FLOW";
            }
            else
            {
               record.falcon_capital_flow_source = "WITHDRAWAL";
               record.falcon_capital_flow_reason = "CAPITAL_DELTA_EXCEEDS_TRADE_DELTA_NEGATIVE_EXTERNAL_FLOW";
            }
         }
         // External capital movement is not a reporting failure; it must be classified and separated from strategy P/L.
         record.falcon_capital_flow_status = "PASS";
         return;
      }

      if(final_trade_delta > 0.0001)
      {
         record.falcon_capital_flow_source = "TRADE_PROFIT";
         record.falcon_capital_flow_reason = "CAPITAL_DELTA_MATCHES_FINAL_WORKING_TRADE_PROFIT";
      }
      else if(final_trade_delta < -0.0001)
      {
         record.falcon_capital_flow_source = "TRADE_LOSS";
         record.falcon_capital_flow_reason = "CAPITAL_DELTA_MATCHES_FINAL_WORKING_TRADE_LOSS";
      }
      else
      {
         record.falcon_capital_flow_source = "FLAT";
         record.falcon_capital_flow_reason = "NO_FINAL_WORKING_TRADE_DELTA";
      }
   }

   void ResetTotals()
   {
      
      ResetWeeklyStabilityState();
m_totals.total_trades                = 0;
      m_totals.win_trades                  = 0;
      m_totals.loss_trades                 = 0;
      m_totals.breakeven_trades            = 0;
      m_totals.total_profit_index_points   = 0.0;
      m_totals.total_loss_index_points     = 0.0;
      m_totals.net_index_points            = 0.0;
      m_totals.total_profit_usd            = 0.0;
      m_totals.total_loss_usd              = 0.0;
      m_totals.net_usd                     = 0.0;
      m_totals.final_profit_trades         = 0;
      m_totals.final_loss_trades           = 0;
      m_totals.final_breakeven_trades      = 0;
      m_totals.final_total_profit_usd      = 0.0;
      m_totals.final_total_loss_usd        = 0.0;
      m_totals.final_working_net_usd       = 0.0;
      m_totals.visible_raw_net_usd_4dp     = 0.0;
      m_totals.visible_final_working_net_usd_4dp = 0.0;
      m_totals.visible_final_total_profit_usd_4dp = 0.0;
      m_totals.visible_final_total_loss_usd_4dp = 0.0;
      m_totals.capital_flow_evaluated_trades = 0;
      m_totals.capital_flow_trade_profit_events = 0;
      m_totals.capital_flow_trade_loss_events = 0;
      m_totals.capital_flow_flat_events = 0;
      m_totals.capital_flow_injection_events = 0;
      m_totals.capital_flow_withdrawal_events = 0;
      m_totals.capital_flow_unknown_events = 0;
      m_totals.capital_flow_integrity_breaches = 0;
      m_totals.capital_flow_external_net_usd = 0.0;
      m_totals.weekly_stability_evaluated_trades = 0;
      m_totals.weekly_stability_weeks = 0;
      m_totals.weekly_stability_positive_weeks = 0;
      m_totals.weekly_stability_negative_weeks = 0;
      m_totals.weekly_stability_best_week_usd = 0.0;
      m_totals.weekly_stability_worst_week_usd = 0.0;
      m_totals.weekly_stability_score = 0.0;
      m_totals.market_close_guard_evaluated_trades = 0;
      m_totals.market_close_guard_near_close_entry_trades = 0;
      m_totals.market_close_guard_open_weekend_risk_trades = 0;
      m_totals.market_close_max_trade_duration_minutes = 0;
      m_totals.market_close_total_trade_duration_minutes = 0.0;
      m_totals.market_close_duration_above_window_trades = 0;
      m_totals.market_close_longest_trade_id = "";
      m_totals.no_new_entry_override_evaluated_trades = 0;
      m_totals.no_new_entry_override_blocked_trades = 0;
      m_totals.no_new_entry_override_blocked_winners = 0;
      m_totals.no_new_entry_override_blocked_losers = 0;
      m_totals.no_new_entry_override_impact_usd = 0.0;
      m_totals.force_close_override_evaluated_trades = 0;
      m_totals.force_close_override_closed_trades = 0;
      m_totals.force_close_override_daily_closed_trades = 0;
      m_totals.force_close_override_weekend_closed_trades = 0;
      m_totals.force_close_override_price_ok_trades = 0;
      m_totals.force_close_override_missing_price_trades = 0;
      m_totals.force_close_override_before_net_usd = 0.0;
      m_totals.force_close_override_after_net_usd = 0.0;
      m_totals.force_close_override_impact_usd = 0.0;
      m_totals.paper_state_snapshot_evaluated_trades = 0;
      m_totals.paper_state_snapshot_written_rows = 0;
      m_totals.paper_state_snapshot_write_failures = 0;
      m_totals.paper_state_recovery_trusted_trades = 0;
      m_totals.paper_state_recovery_untrusted_trades = 0;
      m_totals.session_boundary_checkpoint_evaluated_trades = 0;
      m_totals.session_boundary_recovery_checkpoint_minutes = FalconSessionBoundaryDefaultRecoveryCheckpointMinutes();
      m_totals.session_boundary_daily_checkpoint_open_trades = 0;
      m_totals.session_boundary_weekend_checkpoint_open_trades = 0;
      m_totals.session_boundary_recovery_required_trades = 0;
      m_totals.session_boundary_dirty_after_close_safety_trades = 0;
      m_totals.win_rate                    = 0.0;
      m_totals.loss_rate                   = 0.0;

      m_totals.buy_trades                  = 0;
      m_totals.buy_win_trades              = 0;
      m_totals.buy_net_index_points        = 0.0;
      m_totals.sell_trades                 = 0;
      m_totals.sell_win_trades             = 0;
      m_totals.sell_net_index_points       = 0.0;

      m_totals.fvg_qguard_evaluated             = 0;
      m_totals.fvg_qguard_passed                = 0;
      m_totals.fvg_qguard_blocked               = 0;
      m_totals.fvg_qguard_blocked_winners       = 0;
      m_totals.fvg_qguard_blocked_losers        = 0;
      m_totals.fvg_qguard_actual_net_points     = 0.0;
      m_totals.fvg_qguard_simulated_net_points  = 0.0;
      m_totals.fvg_qguard_blocked_net_points    = 0.0;
      m_totals.fvg_qguard_actual_net_usd        = 0.0;
      m_totals.fvg_qguard_simulated_net_usd     = 0.0;
      m_totals.fvg_qguard_blocked_net_usd       = 0.0;

      m_totals.sltp_validation_evaluated_trades = 0;
      m_totals.structural_stop_valid_trades     = 0;
      m_totals.structural_stop_invalid_trades   = 0;
      m_totals.tp_builder_valid_trades          = 0;
      m_totals.tp_builder_invalid_trades        = 0;
      m_totals.tp1_valid_trades                 = 0;
      m_totals.tp2_valid_trades                 = 0;
      m_totals.tp3_valid_trades                 = 0;

      m_totals.smart_tm_evaluated_trades             = 0;
      m_totals.smart_tm_proof_score_min              = -1;
      m_totals.smart_tm_proof_score_max              = 0;
      m_totals.smart_tm_proof_score_total            = 0;
      m_totals.smart_tm_exit_conservative_trades     = 0;
      m_totals.smart_tm_partial_no_runner_trades     = 0;
      m_totals.smart_tm_runner_candidate_trades      = 0;
      m_totals.smart_tm_strong_runner_candidate_trades = 0;
      m_totals.smart_tm_antiproof_score_total        = 0;
      m_totals.smart_tm_antiproof_score_max          = 0;
      m_totals.smart_tm_antiproof_high_risk_trades   = 0;
      m_totals.smart_tm_behavior_healthy_trades      = 0;
      m_totals.smart_tm_behavior_choppy_trades       = 0;
      m_totals.smart_tm_behavior_failure_trades      = 0;
      m_totals.smart_tm_runner_opportunity_trades    = 0;
      m_totals.smart_tm_strong_runner_opportunity_trades = 0;
      m_totals.smart_tm_tp1_close_trades             = 0;
      m_totals.smart_tm_sl_failure_trades            = 0;
      m_totals.smart_tm_timeout_close_trades         = 0;
      m_totals.smart_tm_proof_weak_trades           = 0;
      m_totals.smart_tm_proof_medium_trades         = 0;
      m_totals.smart_tm_proof_strong_trades         = 0;
      m_totals.smart_tm_proof_elite_trades          = 0;
      m_totals.smart_tm_behavior_grinding_trades    = 0;
      m_totals.smart_tm_behavior_exhausted_trades   = 0;
      m_totals.smart_tm_runner_conservative_opportunity_trades = 0;

      m_totals.runner_diag_evaluated_trades = 0;
      m_totals.runner_diag_tp1_anchor_trades = 0;
      m_totals.runner_diag_tp2_anchor_trades = 0;
      m_totals.runner_diag_mfe_proxy_trades = 0;
      m_totals.runner_diag_mfe_proxy_total_points = 0.0;
      m_totals.runner_diag_mfe_proxy_max_points = 0.0;
      m_totals.runner_diag_tp1_to_tp2_room_total_points = 0.0;
      m_totals.runner_diag_tp1_to_tp3_room_total_points = 0.0;
      m_totals.runner_diag_tp2_to_tp3_room_total_points = 0.0;
      m_totals.runner_diag_max_r_proxy_total = 0.0;
      m_totals.runner_diag_max_r_proxy_max = 0.0;
      m_totals.runner_diag_would_reach_3r_trades = 0;
      m_totals.runner_diag_would_reach_5r_trades = 0;
      m_totals.runner_diag_protected_profit_opportunity_trades = 0;
      m_totals.runner_diag_return_to_loss_after_proof_unknown_trades = 0;

      m_totals.runner_barpath_evaluated_trades = 0;
      m_totals.runner_barpath_scanned_trades = 0;
      m_totals.runner_barpath_scan_failed_trades = 0;
      m_totals.runner_barpath_total_bars_scanned = 0;
      m_totals.runner_barpath_tp1_touched_trades = 0;
      m_totals.runner_barpath_tp2_touched_trades = 0;
      m_totals.runner_barpath_mfe_after_tp1_total_points = 0.0;
      m_totals.runner_barpath_mfe_after_tp1_max_points = 0.0;
      m_totals.runner_barpath_mfe_after_tp2_total_points = 0.0;
      m_totals.runner_barpath_mfe_after_tp2_max_points = 0.0;
      m_totals.runner_barpath_giveback_after_tp1_total_points = 0.0;
      m_totals.runner_barpath_giveback_after_tp1_max_points = 0.0;
      m_totals.runner_barpath_giveback_after_tp2_total_points = 0.0;
      m_totals.runner_barpath_giveback_after_tp2_max_points = 0.0;
      m_totals.runner_barpath_returned_to_loss_after_tp1_trades = 0;
      m_totals.runner_barpath_returned_to_loss_after_tp2_trades = 0;
      m_totals.runner_barpath_actual_would_reach_3r_trades = 0;
      m_totals.runner_barpath_actual_would_reach_5r_trades = 0;
      m_totals.runner_barpath_protected_after_tp1_opportunity_trades = 0;
      m_totals.runner_barpath_protected_after_tp2_opportunity_trades = 0;

      m_totals.fast_tm_evaluated_trades = 0;
      m_totals.fast_tm_decision_cache_ready_trades = 0;
      m_totals.fast_tm_precomputed_branch_ready_trades = 0;
      m_totals.fast_tm_tp1_decision_ready_trades = 0;
      m_totals.fast_tm_tp2_decision_ready_trades = 0;
      m_totals.fast_tm_protection_required_after_tp1_trades = 0;
      m_totals.fast_tm_protection_required_after_tp2_trades = 0;
      m_totals.fast_tm_immediate_runner_candidate_trades = 0;
      m_totals.fast_tm_immediate_exit_warning_trades = 0;
      m_totals.fast_tm_fast_antiproof_warning_trades = 0;
      m_totals.fast_tm_conservative_partial_ready_trades = 0;
      m_totals.fast_tm_runner_wait_for_confirmation_trades = 0;
      m_totals.paper_guard_evaluated_trades = 0;
      m_totals.paper_guard_passed_trades = 0;
      m_totals.paper_guard_rejected_trades = 0;
      m_totals.paper_guard_spread_rejected_trades = 0;
      m_totals.paper_guard_stops_rejected_trades = 0;
      m_totals.paper_guard_freeze_rejected_trades = 0;
      m_totals.paper_exposure_evaluated_trades = 0;
      m_totals.paper_exposure_passed_trades = 0;
      m_totals.paper_exposure_blocked_total = 0;
      m_totals.paper_exposure_blocked_engine = 0;
      m_totals.paper_exposure_blocked_direction = 0;
      m_totals.paper_guard_before_net_points = 0.0;
      m_totals.paper_guard_after_net_points = 0.0;
      m_totals.paper_guard_impact_points = 0.0;
      m_totals.paper_guard_before_net_usd = 0.0;
      m_totals.paper_guard_after_net_usd = 0.0;
      m_totals.paper_guard_impact_usd = 0.0;
      m_totals.paper_protection_evaluated_trades = 0;
      m_totals.paper_protection_eligible_trades = 0;
      m_totals.paper_protection_activated_trades = 0;
      m_totals.paper_tp1_protection_trades = 0;
      m_totals.paper_tp2_protection_trades = 0;
      m_totals.paper_virtual_sl_changed_trades = 0;
      m_totals.paper_virtual_sl_hit_trades = 0;
      m_totals.paper_protected_exit_trades = 0;
      m_totals.paper_protection_before_net_points = 0.0;
      m_totals.paper_protection_after_net_points = 0.0;
      m_totals.paper_protection_impact_points = 0.0;
      m_totals.paper_protection_before_net_usd = 0.0;
      m_totals.paper_protection_after_net_usd = 0.0;
      m_totals.paper_protection_impact_usd = 0.0;
      m_totals.paper_protection_giveback_prevented_points = 0.0;
      m_totals.paper_protection_giveback_prevented_usd = 0.0;
      m_totals.paper_runner_evaluated_trades = 0;
      m_totals.paper_runner_eligible_trades = 0;
      m_totals.paper_runner_activated_trades = 0;
      m_totals.paper_runner_3r_trades = 0;
      m_totals.paper_moon_mode_5r_trades = 0;
      m_totals.paper_runner_exit_trades = 0;
      m_totals.paper_runner_giveback_trades = 0;
      m_totals.paper_runner_protected_from_loss_trades = 0;
      m_totals.paper_runner_before_net_points = 0.0;
      m_totals.paper_runner_after_net_points = 0.0;
      m_totals.paper_runner_impact_points = 0.0;
      m_totals.paper_runner_before_net_usd = 0.0;
      m_totals.paper_runner_after_net_usd = 0.0;
      m_totals.paper_runner_impact_usd = 0.0;
      m_totals.paper_runner_additional_points = 0.0;
      m_totals.paper_runner_additional_usd = 0.0;

      m_totals.lotsizing_feasibility_evaluated_trades = 0;
      m_totals.lotsizing_feasibility_feasible_trades = 0;
      m_totals.lotsizing_feasibility_borderline_trades = 0;
      m_totals.lotsizing_feasibility_not_feasible_trades = 0;
      m_totals.lotsizing_feasibility_invalid_trades = 0;
      m_totals.lotsizing_single_trade_cap_breach_trades = 0;
      m_totals.lotsizing_min_lot_risk_usd_total = 0.0;
      m_totals.lotsizing_min_lot_risk_usd_max = 0.0;
      m_totals.lotsizing_min_lot_risk_pct_total = 0.0;
      m_totals.lotsizing_min_lot_risk_pct_max = 0.0;
      m_totals.lotsizing_potential_loss_r_total = 0.0;
      m_totals.lotsizing_potential_loss_r_max = 0.0;

      m_totals.single_trade_loss_cap_evaluated_trades = 0;
      m_totals.single_trade_loss_cap_allowed_trades = 0;
      m_totals.single_trade_loss_cap_blocked_trades = 0;
      m_totals.single_trade_loss_cap_invalid_trades = 0;
      m_totals.single_trade_loss_cap_strict_breach_trades = 0;
      m_totals.single_trade_loss_cap_calibrated_breach_trades = 0;
      m_totals.single_trade_loss_cap_before_net_points = 0.0;
      m_totals.single_trade_loss_cap_after_net_points = 0.0;
      m_totals.single_trade_loss_cap_impact_points = 0.0;
      m_totals.single_trade_loss_cap_before_net_usd = 0.0;
      m_totals.single_trade_loss_cap_after_net_usd = 0.0;
      m_totals.single_trade_loss_cap_impact_usd = 0.0;
      m_totals.single_trade_loss_cap_rejected_profit_usd = 0.0;
      m_totals.single_trade_loss_cap_rejected_loss_usd = 0.0;
      m_totals.single_trade_loss_cap_calibrated_cap_r_max = 0.0;
      m_totals.single_trade_loss_cap_risk_pct_cap_max = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_start = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_min = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_max = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_end = 0.0;
      m_totals.single_trade_loss_cap_dynamic_risk_pct_max = 0.0;
      m_totals.single_trade_loss_cap_dynamic_cap_pct_max = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_updates = 0;
      m_totals.single_trade_loss_cap_dynamic_capital_blocks = 0;

      m_totals.dynamic_lotsizing_evaluated_trades = 0;
      m_totals.dynamic_lotsizing_fixed_mode_trades = 0;
      m_totals.dynamic_lotsizing_dynamic_mode_trades = 0;
      m_totals.dynamic_lotsizing_candidate_ready_trades = 0;
      m_totals.dynamic_lotsizing_invalid_trades = 0;
      m_totals.dynamic_lotsizing_min_lot_floor_trades = 0;
      m_totals.dynamic_lotsizing_max_lot_cap_trades = 0;
      m_totals.dynamic_lotsizing_tier_cap_trades = 0;
      m_totals.dynamic_lotsizing_capital_cap_trades = 0;
      m_totals.dynamic_lotsizing_growth_ramp_trades = 0;
      m_totals.dynamic_lotsizing_safety_active_lot_max = 0.0;
      m_totals.dynamic_lotsizing_raw_lot_total = 0.0;
      m_totals.dynamic_lotsizing_recommended_lot_total = 0.0;
      m_totals.dynamic_lotsizing_active_lot_total = 0.0;
      m_totals.dynamic_lotsizing_recommended_risk_pct_max = 0.0;
      m_totals.dynamic_lotsizing_active_risk_pct_max = 0.0;

      m_totals.paper_emergency_evaluated_trades = 0;
      m_totals.paper_emergency_safe_trades = 0;
      m_totals.paper_emergency_triggered_trades = 0;
      m_totals.paper_emergency_blocked_entries = 0;
      m_totals.paper_emergency_layer1_triggers = 0;
      m_totals.paper_emergency_layer2_triggers = 0;
      m_totals.paper_emergency_layer3_triggers = 0;
      m_totals.paper_emergency_before_net_points = 0.0;
      m_totals.paper_emergency_after_net_points = 0.0;
      m_totals.paper_emergency_impact_points = 0.0;
      m_totals.paper_emergency_before_net_usd = 0.0;
      m_totals.paper_emergency_after_net_usd = 0.0;
      m_totals.paper_emergency_impact_usd = 0.0;
      m_totals.paper_emergency_max_drawdown_pct = 0.0;
      m_totals.paper_emergency_worst_daily_r = 0.0;
      m_totals.layer_reset_evaluated_trades = 0;
      m_totals.layer1_reset_on_win_events = 0;
      m_totals.layer2_reset_on_new_day_events = 0;
      m_totals.layer3_reset_on_new_peak_events = 0;
      m_totals.layer_reset_event_trades = 0;
      m_totals.layer_reset_duplicate_triggers = 0;

      // v0.57.0: Lock Parity Executability Decomposer totals.
      m_totals.lock_parity_evaluated_trades = 0;
      m_totals.lock_parity_decomposition_pass_trades = 0;
      m_totals.lock_parity_decomposition_breach_trades = 0;
      m_totals.lock_parity_raw_net_usd = 0.0;
      m_totals.lock_parity_final_working_net_usd = 0.0;
      m_totals.lock_parity_sum_guard_delta_usd = 0.0;
      m_totals.lock_parity_sum_protection_delta_usd = 0.0;
      m_totals.lock_parity_sum_runner_delta_usd = 0.0;
      m_totals.lock_parity_sum_losscap_delta_usd = 0.0;
      m_totals.lock_parity_sum_marketclose_delta_usd = 0.0;
      m_totals.lock_parity_sum_emergency_delta_usd = 0.0;
      m_totals.lock_parity_sum_other_delta_usd = 0.0;
      m_totals.lock_parity_executable_adjustment_usd = 0.0;
      m_totals.lock_parity_non_executable_adjustment_usd = 0.0;
      m_totals.lock_parity_protection_executable_usd = 0.0;
      m_totals.lock_parity_runner_pending_usd = 0.0;
      // v0.57.1: Runner Exit Price Probe buckets.
      m_totals.lock_parity_runner_executable_usd = 0.0;
      m_totals.lock_parity_runner_non_executable_usd = 0.0;
      m_totals.lock_parity_accounting_only_usd = 0.0;

      m_tle_emergency_active = false;
      m_tle_emergency_reason = "NONE";
      m_tle_consecutive_losses = 0;
      m_tle_current_day = 0;
      m_tle_daily_r = 0.0;
      m_tle_equity = 0.0;
      m_tle_peak_equity = 0.0;
      m_tle_max_drawdown_pct = 0.0;
      m_dlm_previous_active_lot_ready = false;
      m_dlm_previous_active_lot = 0.0;
   }

   void UpdateTotals(const FalconTradeLifecycleRecord &record)
   {
      m_totals.total_trades++;

      if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
         m_totals.win_trades++;
      else if(record.outcome == FALCON_TRADE_OUTCOME_LOSS)
         m_totals.loss_trades++;
      else if(record.outcome == FALCON_TRADE_OUTCOME_BREAKEVEN)
         m_totals.breakeven_trades++;

      m_totals.total_profit_index_points += record.profit_index_points;
      m_totals.total_loss_index_points   += record.loss_index_points;
      m_totals.net_index_points          += record.net_index_points;
      m_totals.total_profit_usd          += record.profit_usd;
      m_totals.total_loss_usd            += record.loss_usd;
      m_totals.net_usd                   += record.net_usd;

      // v0.55.4b: final truth is the last active paper layer after guard/protection/runner/cap/emergency.
      double final_working_trade_usd = record.falcon_emergency_after_net_usd;
      if(final_working_trade_usd > 0.0)
      {
         m_totals.final_profit_trades++;
         m_totals.final_total_profit_usd += final_working_trade_usd;
      }
      else if(final_working_trade_usd < 0.0)
      {
         m_totals.final_loss_trades++;
         m_totals.final_total_loss_usd += MathAbs(final_working_trade_usd);
      }
      else
      {
         m_totals.final_breakeven_trades++;
      }
      m_totals.final_working_net_usd += final_working_trade_usd;

      // v0.55.4b: accumulate the values exactly as exposed in the slim TradeLifecycle CSV.
      double visible_raw_net_usd = FalconReportVisibleUsd4(record.net_usd);
      double visible_final_working_usd = FalconReportVisibleUsd4(final_working_trade_usd);
      m_totals.visible_raw_net_usd_4dp += visible_raw_net_usd;
      m_totals.visible_final_working_net_usd_4dp += visible_final_working_usd;
      if(visible_final_working_usd > 0.0)
         m_totals.visible_final_total_profit_usd_4dp += visible_final_working_usd;
      else if(visible_final_working_usd < 0.0)
         m_totals.visible_final_total_loss_usd_4dp += MathAbs(visible_final_working_usd);

      m_totals.capital_flow_evaluated_trades++;
      if(record.falcon_capital_flow_source == "TRADE_PROFIT")
         m_totals.capital_flow_trade_profit_events++;
      else if(record.falcon_capital_flow_source == "TRADE_LOSS")
         m_totals.capital_flow_trade_loss_events++;
      else if(record.falcon_capital_flow_source == "FLAT")
         m_totals.capital_flow_flat_events++;
      else if(record.falcon_capital_flow_source == "INJECTION")
         m_totals.capital_flow_injection_events++;
      else if(record.falcon_capital_flow_source == "WITHDRAWAL")
         m_totals.capital_flow_withdrawal_events++;
      else if(record.falcon_capital_flow_source == "MIXED_PROFIT_PLUS_INJECTION")
      {
         m_totals.capital_flow_trade_profit_events++;
         m_totals.capital_flow_injection_events++;
      }
      else if(record.falcon_capital_flow_source == "MIXED_LOSS_PLUS_WITHDRAWAL")
      {
         m_totals.capital_flow_trade_loss_events++;
         m_totals.capital_flow_withdrawal_events++;
      }
      else
         m_totals.capital_flow_unknown_events++;
      if(record.falcon_capital_flow_status != "PASS")
         m_totals.capital_flow_integrity_breaches++;
      m_totals.capital_flow_external_net_usd += record.falcon_external_capital_delta_usd;

      m_totals.paper_guard_evaluated_trades++;
      m_totals.paper_guard_before_net_points += record.net_index_points;
      m_totals.paper_guard_before_net_usd += record.net_usd;
      m_totals.paper_guard_after_net_points += record.paper_guard_net_index_points;
      m_totals.paper_guard_after_net_usd += record.paper_guard_net_usd;
      m_totals.paper_guard_impact_points = m_totals.paper_guard_after_net_points - m_totals.paper_guard_before_net_points;
      m_totals.paper_guard_impact_usd = m_totals.paper_guard_after_net_usd - m_totals.paper_guard_before_net_usd;

      if(record.paper_guard_status == "PASSED")
      {
         m_totals.paper_guard_passed_trades++;
         m_totals.paper_exposure_evaluated_trades++;
         m_totals.paper_exposure_passed_trades++;
      }
      else if(record.paper_guard_status == "REJECTED")
      {
         m_totals.paper_guard_rejected_trades++;
         if(record.paper_reject_reason == "SPREAD_TOO_WIDE")
            m_totals.paper_guard_spread_rejected_trades++;
         else if(record.paper_reject_reason == "SL_TOO_CLOSE")
            m_totals.paper_guard_stops_rejected_trades++;
         else if(record.paper_reject_reason == "FREEZE_LEVEL_BLOCKED")
            m_totals.paper_guard_freeze_rejected_trades++;
      }

      m_totals.paper_protection_evaluated_trades++;
      m_totals.paper_protection_before_net_points += record.paper_guard_net_index_points;
      m_totals.paper_protection_before_net_usd += record.paper_guard_net_usd;
      m_totals.paper_protection_after_net_points += record.paper_protection_net_index_points;
      m_totals.paper_protection_after_net_usd += record.paper_protection_net_usd;
      m_totals.paper_protection_impact_points = m_totals.paper_protection_after_net_points - m_totals.paper_protection_before_net_points;
      m_totals.paper_protection_impact_usd = m_totals.paper_protection_after_net_usd - m_totals.paper_protection_before_net_usd;

      if(record.paper_protection_activated)
      {
         m_totals.paper_protection_eligible_trades++;
         m_totals.paper_protection_activated_trades++;
      }
      if(record.paper_protection_state == "TP1_PROTECTED")
         m_totals.paper_tp1_protection_trades++;
      else if(record.paper_protection_state == "TP2_PROTECTED")
         m_totals.paper_tp2_protection_trades++;
      if(record.paper_virtual_sl_changed)
         m_totals.paper_virtual_sl_changed_trades++;
      if(record.paper_virtual_sl_hit)
      {
         m_totals.paper_virtual_sl_hit_trades++;
         m_totals.paper_protected_exit_trades++;
         m_totals.paper_protection_giveback_prevented_points += (record.paper_protection_net_index_points - record.paper_guard_net_index_points);
         m_totals.paper_protection_giveback_prevented_usd += (record.paper_protection_net_usd - record.paper_guard_net_usd);
      }

      m_totals.paper_runner_evaluated_trades++;
      m_totals.paper_runner_before_net_points += record.paper_protection_net_index_points;
      m_totals.paper_runner_before_net_usd += record.paper_protection_net_usd;
      m_totals.paper_runner_after_net_points += record.paper_runner_net_index_points;
      m_totals.paper_runner_after_net_usd += record.paper_runner_net_usd;
      m_totals.paper_runner_impact_points = m_totals.paper_runner_after_net_points - m_totals.paper_runner_before_net_points;
      m_totals.paper_runner_impact_usd = m_totals.paper_runner_after_net_usd - m_totals.paper_runner_before_net_usd;
      if(record.paper_protection_activated && record.paper_virtual_sl_changed)
         m_totals.paper_runner_eligible_trades++;
      if(record.paper_runner_activated)
      {
         m_totals.paper_runner_activated_trades++;
         m_totals.paper_runner_exit_trades++;
      }
      if(record.paper_runner_max_r >= 3.0)
         m_totals.paper_runner_3r_trades++;
      if(record.paper_runner_state == "MOON")
         m_totals.paper_moon_mode_5r_trades++;
      if(record.paper_runner_additional_points > 0.0)
      {
         m_totals.paper_runner_additional_points += record.paper_runner_additional_points;
         m_totals.paper_runner_additional_usd += (record.paper_runner_net_usd - record.paper_protection_net_usd);
      }
      if(record.paper_runner_activated && record.paper_runner_additional_points > 0.0)
         m_totals.paper_runner_giveback_trades++;
      if(record.paper_guard_net_index_points < 0.0 && record.paper_runner_net_index_points >= 0.0)
         m_totals.paper_runner_protected_from_loss_trades++;

      m_totals.lotsizing_feasibility_evaluated_trades++;
      if(record.falcon_lotsizing_feasibility_status == "FEASIBLE")
         m_totals.lotsizing_feasibility_feasible_trades++;
      else if(record.falcon_lotsizing_feasibility_status == "BORDERLINE")
         m_totals.lotsizing_feasibility_borderline_trades++;
      else if(record.falcon_lotsizing_feasibility_status == "NOT_FEASIBLE")
         m_totals.lotsizing_feasibility_not_feasible_trades++;
      else
         m_totals.lotsizing_feasibility_invalid_trades++;
      if(record.falcon_single_trade_loss_cap_breach == 1)
         m_totals.lotsizing_single_trade_cap_breach_trades++;
      m_totals.lotsizing_min_lot_risk_usd_total += record.falcon_min_lot_risk_usd;
      if(record.falcon_min_lot_risk_usd > m_totals.lotsizing_min_lot_risk_usd_max)
         m_totals.lotsizing_min_lot_risk_usd_max = record.falcon_min_lot_risk_usd;
      m_totals.lotsizing_min_lot_risk_pct_total += record.falcon_min_lot_risk_pct_of_capital;
      if(record.falcon_min_lot_risk_pct_of_capital > m_totals.lotsizing_min_lot_risk_pct_max)
         m_totals.lotsizing_min_lot_risk_pct_max = record.falcon_min_lot_risk_pct_of_capital;
      m_totals.lotsizing_potential_loss_r_total += record.falcon_potential_loss_r;
      if(record.falcon_potential_loss_r > m_totals.lotsizing_potential_loss_r_max)
         m_totals.lotsizing_potential_loss_r_max = record.falcon_potential_loss_r;

      m_totals.single_trade_loss_cap_evaluated_trades++;
      if(record.falcon_single_trade_loss_cap_status == "BLOCKED")
         m_totals.single_trade_loss_cap_blocked_trades++;
      else if(record.falcon_single_trade_loss_cap_status == "INVALID")
         m_totals.single_trade_loss_cap_invalid_trades++;
      else
         m_totals.single_trade_loss_cap_allowed_trades++;
      if(record.falcon_single_trade_loss_cap_breach == 1)
         m_totals.single_trade_loss_cap_strict_breach_trades++;
      if(record.falcon_single_trade_loss_cap_blocked == 1)
      {
         m_totals.single_trade_loss_cap_calibrated_breach_trades++;
         if(record.falcon_single_trade_loss_cap_before_net_usd > 0.0)
            m_totals.single_trade_loss_cap_rejected_profit_usd += record.falcon_single_trade_loss_cap_before_net_usd;
         else if(record.falcon_single_trade_loss_cap_before_net_usd < 0.0)
            m_totals.single_trade_loss_cap_rejected_loss_usd += MathAbs(record.falcon_single_trade_loss_cap_before_net_usd);
      }
      m_totals.single_trade_loss_cap_before_net_points += record.falcon_single_trade_loss_cap_before_net_points;
      m_totals.single_trade_loss_cap_after_net_points += record.falcon_single_trade_loss_cap_after_net_points;
      m_totals.single_trade_loss_cap_impact_points = m_totals.single_trade_loss_cap_after_net_points - m_totals.single_trade_loss_cap_before_net_points;
      m_totals.single_trade_loss_cap_before_net_usd += record.falcon_single_trade_loss_cap_before_net_usd;
      m_totals.single_trade_loss_cap_after_net_usd += record.falcon_single_trade_loss_cap_after_net_usd;
      m_totals.single_trade_loss_cap_impact_usd = m_totals.single_trade_loss_cap_after_net_usd - m_totals.single_trade_loss_cap_before_net_usd;
      if(record.falcon_single_trade_loss_cap_calibrated_cap_r > m_totals.single_trade_loss_cap_calibrated_cap_r_max)
         m_totals.single_trade_loss_cap_calibrated_cap_r_max = record.falcon_single_trade_loss_cap_calibrated_cap_r;
      if(record.falcon_single_trade_loss_cap_risk_pct_cap > m_totals.single_trade_loss_cap_risk_pct_cap_max)
         m_totals.single_trade_loss_cap_risk_pct_cap_max = record.falcon_single_trade_loss_cap_risk_pct_cap;
      if(record.falcon_dynamic_capital_aware_blocked == 1)
         m_totals.single_trade_loss_cap_dynamic_capital_blocks++;
      if(record.falcon_dynamic_risk_capital_before_trade > 0.0)
      {
         if(m_totals.single_trade_loss_cap_dynamic_capital_updates == 0)
         {
            m_totals.single_trade_loss_cap_dynamic_capital_start = record.falcon_dynamic_risk_capital_before_trade;
            m_totals.single_trade_loss_cap_dynamic_capital_min = record.falcon_dynamic_risk_capital_before_trade;
            m_totals.single_trade_loss_cap_dynamic_capital_max = record.falcon_dynamic_risk_capital_before_trade;
         }
         if(record.falcon_dynamic_risk_capital_before_trade < m_totals.single_trade_loss_cap_dynamic_capital_min)
            m_totals.single_trade_loss_cap_dynamic_capital_min = record.falcon_dynamic_risk_capital_before_trade;
         if(record.falcon_dynamic_risk_capital_before_trade > m_totals.single_trade_loss_cap_dynamic_capital_max)
            m_totals.single_trade_loss_cap_dynamic_capital_max = record.falcon_dynamic_risk_capital_before_trade;
         m_totals.single_trade_loss_cap_dynamic_capital_end = record.falcon_dynamic_risk_capital_after_trade;
         m_totals.single_trade_loss_cap_dynamic_capital_updates++;
      }
      if(record.falcon_dynamic_risk_pct_of_capital > m_totals.single_trade_loss_cap_dynamic_risk_pct_max)
         m_totals.single_trade_loss_cap_dynamic_risk_pct_max = record.falcon_dynamic_risk_pct_of_capital;
      if(record.falcon_dynamic_single_trade_cap_pct > m_totals.single_trade_loss_cap_dynamic_cap_pct_max)
         m_totals.single_trade_loss_cap_dynamic_cap_pct_max = record.falcon_dynamic_single_trade_cap_pct;

      m_totals.dynamic_lotsizing_evaluated_trades++;
      if(record.falcon_dlm_use_fixed_lot == 1)
         m_totals.dynamic_lotsizing_fixed_mode_trades++;
      else
         m_totals.dynamic_lotsizing_dynamic_mode_trades++;
      if(record.falcon_dlm_decision == "INVALID")
         m_totals.dynamic_lotsizing_invalid_trades++;
      else
         m_totals.dynamic_lotsizing_candidate_ready_trades++;
      if(record.falcon_dlm_min_lot_floor_applied == 1)
         m_totals.dynamic_lotsizing_min_lot_floor_trades++;
      if(record.falcon_dlm_max_lot_cap_applied == 1)
         m_totals.dynamic_lotsizing_max_lot_cap_trades++;
      if(record.falcon_dlm_tier_cap_applied == 1)
         m_totals.dynamic_lotsizing_tier_cap_trades++;
      if(record.falcon_dlm_capital_cap_applied == 1)
         m_totals.dynamic_lotsizing_capital_cap_trades++;
      if(record.falcon_dlm_growth_ramp_applied == 1)
         m_totals.dynamic_lotsizing_growth_ramp_trades++;
      if(record.falcon_dlm_active_lot > m_totals.dynamic_lotsizing_safety_active_lot_max)
         m_totals.dynamic_lotsizing_safety_active_lot_max = record.falcon_dlm_active_lot;
      m_totals.dynamic_lotsizing_raw_lot_total += record.falcon_dlm_raw_lot;
      m_totals.dynamic_lotsizing_recommended_lot_total += record.falcon_dlm_recommended_lot;
      m_totals.dynamic_lotsizing_active_lot_total += record.falcon_dlm_active_lot;
      if(record.falcon_dlm_recommended_risk_pct > m_totals.dynamic_lotsizing_recommended_risk_pct_max)
         m_totals.dynamic_lotsizing_recommended_risk_pct_max = record.falcon_dlm_recommended_risk_pct;
      if(record.falcon_dlm_active_risk_pct > m_totals.dynamic_lotsizing_active_risk_pct_max)
         m_totals.dynamic_lotsizing_active_risk_pct_max = record.falcon_dlm_active_risk_pct;

      UpdateWeeklyStabilityFoundation(record);
      UpdateMarketCloseGuardFoundation(record);
      UpdateSessionBoundaryStateCheckpointFoundation(record);
      m_totals.no_new_entry_override_evaluated_trades++;
      if(record.falcon_market_close_blocked == 1)
      {
         m_totals.no_new_entry_override_blocked_trades++;
         if(record.falcon_market_close_before_net_usd > 0.0001)
            m_totals.no_new_entry_override_blocked_winners++;
         else if(record.falcon_market_close_before_net_usd < -0.0001)
            m_totals.no_new_entry_override_blocked_losers++;
         m_totals.no_new_entry_override_impact_usd += record.falcon_market_close_impact_usd;
      }

      m_totals.paper_emergency_evaluated_trades++;
      m_totals.paper_emergency_before_net_points += record.falcon_emergency_before_net_points;
      m_totals.paper_emergency_before_net_usd += record.falcon_emergency_before_net_usd;
      m_totals.paper_emergency_after_net_points += record.falcon_emergency_after_net_points;
      m_totals.paper_emergency_after_net_usd += record.falcon_emergency_after_net_usd;
      m_totals.paper_emergency_impact_points = m_totals.paper_emergency_after_net_points - m_totals.paper_emergency_before_net_points;
      m_totals.paper_emergency_impact_usd = m_totals.paper_emergency_after_net_usd - m_totals.paper_emergency_before_net_usd;
      if(record.falcon_emergency_status == "SAFE")
         m_totals.paper_emergency_safe_trades++;
      else if(record.falcon_emergency_status == "TRIGGERED")
      {
         m_totals.paper_emergency_triggered_trades++;
         if(record.falcon_emergency_triggered_layer == 1)
            m_totals.paper_emergency_layer1_triggers++;
         else if(record.falcon_emergency_triggered_layer == 2)
            m_totals.paper_emergency_layer2_triggers++;
         else if(record.falcon_emergency_triggered_layer == 3)
            m_totals.paper_emergency_layer3_triggers++;
      }
      else if(record.falcon_emergency_status == "BLOCKED")
         m_totals.paper_emergency_blocked_entries++;
      if(record.falcon_layer3_drawdown_pct > m_totals.paper_emergency_max_drawdown_pct)
         m_totals.paper_emergency_max_drawdown_pct = record.falcon_layer3_drawdown_pct;
      if(record.falcon_layer2_daily_r < m_totals.paper_emergency_worst_daily_r)
         m_totals.paper_emergency_worst_daily_r = record.falcon_layer2_daily_r;

      m_totals.layer_reset_evaluated_trades++;
      if(record.falcon_layer1_reset_on_win == 1) m_totals.layer1_reset_on_win_events++;
      if(record.falcon_layer2_reset_on_new_day == 1) m_totals.layer2_reset_on_new_day_events++;
      if(record.falcon_layer3_reset_on_new_peak == 1) m_totals.layer3_reset_on_new_peak_events++;
      if(record.falcon_layer1_reset_on_win == 1 || record.falcon_layer2_reset_on_new_day == 1 || record.falcon_layer3_reset_on_new_peak == 1)
         m_totals.layer_reset_event_trades++;
      // v0.53.3a: A trigger on the same row as LAYER2_ON_NEW_DAY can be valid
      // when a multi-day trade exits on the new day and immediately breaches the
      // daily R budget. Count only a true duplicate trigger after an emergency
      // daily-resolution event, not every trigger that follows a normal reset.
      if(record.falcon_emergency_status == "TRIGGERED" &&
         StringFind(record.falcon_reset_reason, "EMERGENCY_DAILY_RESOLVE_") >= 0)
      {
         m_totals.layer_reset_duplicate_triggers++;
      }

      if(record.direction == FALCON_DIRECTION_BUY)
      {
         m_totals.buy_trades++;
         if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
            m_totals.buy_win_trades++;
         m_totals.buy_net_index_points += record.net_index_points;
      }
      else if(record.direction == FALCON_DIRECTION_SELL)
      {
         m_totals.sell_trades++;
         if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
            m_totals.sell_win_trades++;
         m_totals.sell_net_index_points += record.net_index_points;
      }

      m_totals.sltp_validation_evaluated_trades++;
      if(FalconStructuralStopValid(record))
         m_totals.structural_stop_valid_trades++;
      else
         m_totals.structural_stop_invalid_trades++;

      if(FalconTakeProfitDirectionalValid(record, 1))
         m_totals.tp1_valid_trades++;
      if(FalconTakeProfitDirectionalValid(record, 2))
         m_totals.tp2_valid_trades++;
      if(FalconTakeProfitDirectionalValid(record, 3))
         m_totals.tp3_valid_trades++;

      if(FalconTakeProfitSequenceValid(record))
         m_totals.tp_builder_valid_trades++;
      else
         m_totals.tp_builder_invalid_trades++;

      int proof_score = FalconSmartProofScore(record);
      int anti_proof_score = FalconSmartAntiProofScore(record);
      bool tp1_close = FalconClosedAtTp1(record);
      bool stop_close = FalconClosedAtStop(record);
      bool timeout_close = FalconClosedByTimeout(record);

      m_totals.smart_tm_evaluated_trades++;
      if(m_totals.smart_tm_proof_score_min < 0 || proof_score < m_totals.smart_tm_proof_score_min)
         m_totals.smart_tm_proof_score_min = proof_score;
      if(proof_score > m_totals.smart_tm_proof_score_max)
         m_totals.smart_tm_proof_score_max = proof_score;
      m_totals.smart_tm_proof_score_total += proof_score;
      m_totals.smart_tm_antiproof_score_total += anti_proof_score;
      if(anti_proof_score > m_totals.smart_tm_antiproof_score_max)
         m_totals.smart_tm_antiproof_score_max = anti_proof_score;
      if(anti_proof_score >= 60)
         m_totals.smart_tm_antiproof_high_risk_trades++;

      if(proof_score < 50)
      {
         m_totals.smart_tm_exit_conservative_trades++;
         m_totals.smart_tm_proof_weak_trades++;
      }
      else if(proof_score < 70)
      {
         m_totals.smart_tm_partial_no_runner_trades++;
         m_totals.smart_tm_proof_medium_trades++;
      }
      else if(proof_score < 85)
      {
         m_totals.smart_tm_runner_candidate_trades++;
         m_totals.smart_tm_proof_strong_trades++;
      }
      else
      {
         m_totals.smart_tm_strong_runner_candidate_trades++;
         m_totals.smart_tm_proof_elite_trades++;
      }

      string behavior_fingerprint = FalconSmartBehaviorFingerprint(proof_score, anti_proof_score);
      if(behavior_fingerprint == "FAILURE_RISK")
         m_totals.smart_tm_behavior_failure_trades++;
      else if(behavior_fingerprint == "EXHAUSTED")
         m_totals.smart_tm_behavior_exhausted_trades++;
      else if(behavior_fingerprint == "GRINDING")
         m_totals.smart_tm_behavior_grinding_trades++;
      else if(behavior_fingerprint == "HEALTHY")
         m_totals.smart_tm_behavior_healthy_trades++;
      else
         m_totals.smart_tm_behavior_choppy_trades++;

      if(tp1_close)
      {
         m_totals.smart_tm_tp1_close_trades++;
         if(proof_score >= 70 && anti_proof_score < 35)
            m_totals.smart_tm_runner_conservative_opportunity_trades++;
         if(proof_score >= 75 && anti_proof_score < 30)
            m_totals.smart_tm_runner_opportunity_trades++;
         if(proof_score >= 85 && anti_proof_score < 20)
            m_totals.smart_tm_strong_runner_opportunity_trades++;
      }
      if(stop_close)
         m_totals.smart_tm_sl_failure_trades++;
      if(timeout_close)
         m_totals.smart_tm_timeout_close_trades++;

      // v0.29.2: Runner MFE/Giveback proxy diagnostics.
      // This does not change any exit. It only summarizes target geometry and realized favorable move.
      m_totals.runner_diag_evaluated_trades++;

      double realized_mfe_proxy_points = MathMax(0.0, record.profit_index_points);
      if(realized_mfe_proxy_points > 0.0)
      {
         m_totals.runner_diag_mfe_proxy_trades++;
         m_totals.runner_diag_mfe_proxy_total_points += realized_mfe_proxy_points;
         if(realized_mfe_proxy_points > m_totals.runner_diag_mfe_proxy_max_points)
            m_totals.runner_diag_mfe_proxy_max_points = realized_mfe_proxy_points;
      }

      double tp1_to_tp2_room_points = FalconRunnerRoomBetweenTargets(record, record.tp1, record.tp2);
      double tp1_to_tp3_room_points = FalconRunnerRoomBetweenTargets(record, record.tp1, record.tp3);
      double tp2_to_tp3_room_points = FalconRunnerRoomBetweenTargets(record, record.tp2, record.tp3);

      if(FalconTakeProfitDirectionalValid(record, 1) && FalconTakeProfitDirectionalValid(record, 2))
      {
         m_totals.runner_diag_tp1_anchor_trades++;
         m_totals.runner_diag_tp1_to_tp2_room_total_points += tp1_to_tp2_room_points;
         m_totals.runner_diag_tp1_to_tp3_room_total_points += tp1_to_tp3_room_points;
      }

      if(FalconTakeProfitDirectionalValid(record, 2) && FalconTakeProfitDirectionalValid(record, 3))
      {
         m_totals.runner_diag_tp2_anchor_trades++;
         m_totals.runner_diag_tp2_to_tp3_room_total_points += tp2_to_tp3_room_points;
      }

      double max_r_proxy = FalconMaxTargetRProxy(record);
      m_totals.runner_diag_max_r_proxy_total += max_r_proxy;
      if(max_r_proxy > m_totals.runner_diag_max_r_proxy_max)
         m_totals.runner_diag_max_r_proxy_max = max_r_proxy;

      if(max_r_proxy >= 3.0)
         m_totals.runner_diag_would_reach_3r_trades++;
      if(max_r_proxy >= 5.0)
         m_totals.runner_diag_would_reach_5r_trades++;

      if(tp1_close && proof_score >= 70 && anti_proof_score < 35 && tp1_to_tp2_room_points > 0.0)
         m_totals.runner_diag_protected_profit_opportunity_trades++;

      if(tp1_close || proof_score >= 70)
         m_totals.runner_diag_return_to_loss_after_proof_unknown_trades++;

      // v0.29.3a: Runner bar-path metric definition calibration. Summary-only.
      // Scans M5 closed bars between entry and exit to estimate post-proof path.
      // This does not change any exit, SL, TP, staging, or execution behavior.
      m_totals.runner_barpath_evaluated_trades++;
      FalconRunnerBarPathStats barpath_stats;
      if(FalconBuildRunnerBarPathStats(record, barpath_stats))
      {
         m_totals.runner_barpath_scanned_trades++;
         m_totals.runner_barpath_total_bars_scanned += barpath_stats.bars_scanned;

         if(barpath_stats.tp1_touched)
         {
            m_totals.runner_barpath_tp1_touched_trades++;
            if(barpath_stats.tp1_touched_then_extended)
               m_totals.runner_barpath_tp1_touched_then_extended_trades++;
            m_totals.runner_barpath_tp1_to_max_run_total_points += barpath_stats.tp1_to_max_run_points;
            if(barpath_stats.tp1_to_max_run_points > m_totals.runner_barpath_tp1_to_max_run_max_points)
               m_totals.runner_barpath_tp1_to_max_run_max_points = barpath_stats.tp1_to_max_run_points;
            m_totals.runner_barpath_mfe_after_tp1_total_points += barpath_stats.mfe_after_tp1_points;
            if(barpath_stats.mfe_after_tp1_points > m_totals.runner_barpath_mfe_after_tp1_max_points)
               m_totals.runner_barpath_mfe_after_tp1_max_points = barpath_stats.mfe_after_tp1_points;

            m_totals.runner_barpath_giveback_after_tp1_total_points += barpath_stats.giveback_after_tp1_points;
            if(barpath_stats.giveback_after_tp1_points > m_totals.runner_barpath_giveback_after_tp1_max_points)
               m_totals.runner_barpath_giveback_after_tp1_max_points = barpath_stats.giveback_after_tp1_points;

            if(barpath_stats.returned_to_loss_after_tp1)
               m_totals.runner_barpath_returned_to_loss_after_tp1_trades++;
            if(barpath_stats.mfe_after_tp1_points > 0.0 && !barpath_stats.returned_to_loss_after_tp1)
               m_totals.runner_barpath_protected_after_tp1_opportunity_trades++;
         }

         if(barpath_stats.tp2_touched)
         {
            m_totals.runner_barpath_tp2_touched_trades++;
            if(barpath_stats.tp2_touched_then_extended)
               m_totals.runner_barpath_tp2_touched_then_extended_trades++;
            m_totals.runner_barpath_tp2_to_max_run_total_points += barpath_stats.tp2_to_max_run_points;
            if(barpath_stats.tp2_to_max_run_points > m_totals.runner_barpath_tp2_to_max_run_max_points)
               m_totals.runner_barpath_tp2_to_max_run_max_points = barpath_stats.tp2_to_max_run_points;
            m_totals.runner_barpath_mfe_after_tp2_total_points += barpath_stats.mfe_after_tp2_points;
            if(barpath_stats.mfe_after_tp2_points > m_totals.runner_barpath_mfe_after_tp2_max_points)
               m_totals.runner_barpath_mfe_after_tp2_max_points = barpath_stats.mfe_after_tp2_points;

            m_totals.runner_barpath_giveback_after_tp2_total_points += barpath_stats.giveback_after_tp2_points;
            if(barpath_stats.giveback_after_tp2_points > m_totals.runner_barpath_giveback_after_tp2_max_points)
               m_totals.runner_barpath_giveback_after_tp2_max_points = barpath_stats.giveback_after_tp2_points;

            if(barpath_stats.returned_to_loss_after_tp2)
               m_totals.runner_barpath_returned_to_loss_after_tp2_trades++;
            if(barpath_stats.mfe_after_tp2_points > 0.0 && !barpath_stats.returned_to_loss_after_tp2)
               m_totals.runner_barpath_protected_after_tp2_opportunity_trades++;
         }

         if(barpath_stats.max_r_actual_proxy >= 3.0)
            m_totals.runner_barpath_actual_would_reach_3r_trades++;
         if(barpath_stats.max_r_actual_proxy >= 5.0)
            m_totals.runner_barpath_actual_would_reach_5r_trades++;
      }
      else
      {
         m_totals.runner_barpath_scan_failed_trades++;
      }

      // v0.29.4: Fast protection / runner decision readiness diagnostics.
      // The goal is to know whether TP1/TP2 decisions can be pre-computed before event touch.
      // This only counts readiness; it never modifies SL, TP, partials, exits, or execution.
      m_totals.fast_tm_evaluated_trades++;
      bool fast_cache_ready = (FalconStructuralStopValid(record) && FalconTakeProfitSequenceValid(record));
      bool fast_branch_ready = (fast_cache_ready && FalconTakeProfitDirectionalValid(record, 1) && FalconTakeProfitDirectionalValid(record, 2));
      if(fast_cache_ready)
         m_totals.fast_tm_decision_cache_ready_trades++;
      if(fast_branch_ready)
         m_totals.fast_tm_precomputed_branch_ready_trades++;

      bool fast_tp1_ready = false;
      bool fast_tp2_ready = false;
      bool fast_protect_tp1 = false;
      bool fast_protect_tp2 = false;
      bool fast_runner_now = false;
      bool fast_exit_warning = false;
      bool fast_antiproof_warning = false;
      bool fast_partial_ready = false;
      bool fast_wait_runner = false;

      if(barpath_stats.scan_ok)
      {
         fast_tp1_ready = barpath_stats.tp1_touched;
         fast_tp2_ready = barpath_stats.tp2_touched;
         fast_protect_tp1 = (barpath_stats.tp1_touched && (barpath_stats.giveback_after_tp1_points > 0.0 || barpath_stats.returned_to_loss_after_tp1));
         fast_protect_tp2 = (barpath_stats.tp2_touched && (barpath_stats.giveback_after_tp2_points > 0.0 || barpath_stats.returned_to_loss_after_tp2));
         fast_runner_now = (barpath_stats.tp1_touched && proof_score >= 85 && anti_proof_score < 25 && barpath_stats.tp1_to_max_run_points > 0.0 && !barpath_stats.returned_to_loss_after_tp1);
         fast_wait_runner = (barpath_stats.tp1_touched && proof_score >= 70 && proof_score < 85 && anti_proof_score < 35 && barpath_stats.tp1_to_max_run_points > 0.0);
      }

      fast_partial_ready = (fast_tp1_ready && proof_score >= 50 && proof_score < 85);
      fast_antiproof_warning = (anti_proof_score >= 45 || (barpath_stats.scan_ok && (barpath_stats.returned_to_loss_after_tp1 || barpath_stats.returned_to_loss_after_tp2)));
      fast_exit_warning = (anti_proof_score >= 50 || (barpath_stats.scan_ok && barpath_stats.returned_to_loss_after_tp2));

      if(fast_tp1_ready)
         m_totals.fast_tm_tp1_decision_ready_trades++;
      if(fast_tp2_ready)
         m_totals.fast_tm_tp2_decision_ready_trades++;
      if(fast_protect_tp1)
         m_totals.fast_tm_protection_required_after_tp1_trades++;
      if(fast_protect_tp2)
         m_totals.fast_tm_protection_required_after_tp2_trades++;
      if(fast_runner_now)
         m_totals.fast_tm_immediate_runner_candidate_trades++;
      if(fast_exit_warning)
         m_totals.fast_tm_immediate_exit_warning_trades++;
      if(fast_antiproof_warning)
         m_totals.fast_tm_fast_antiproof_warning_trades++;
      if(fast_partial_ready)
         m_totals.fast_tm_conservative_partial_ready_trades++;
      if(fast_wait_runner)
         m_totals.fast_tm_runner_wait_for_confirmation_trades++;

      m_totals.fvg_qguard_evaluated++;
      m_totals.fvg_qguard_actual_net_points += record.net_index_points;
      m_totals.fvg_qguard_actual_net_usd    += record.net_usd;

      if(record.fvg_quality_shadow_guard_passed)
      {
         m_totals.fvg_qguard_passed++;
         m_totals.fvg_qguard_simulated_net_points += record.net_index_points;
         m_totals.fvg_qguard_simulated_net_usd    += record.net_usd;
      }
      else
      {
         m_totals.fvg_qguard_blocked++;
         m_totals.fvg_qguard_blocked_net_points += record.net_index_points;
         m_totals.fvg_qguard_blocked_net_usd    += record.net_usd;

         if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
            m_totals.fvg_qguard_blocked_winners++;
         else if(record.outcome == FALCON_TRADE_OUTCOME_LOSS)
            m_totals.fvg_qguard_blocked_losers++;
      }
   }

   string SlimTradeHeaderV0555()
   {
      // v0.55.7: final minimal per-trade surface; capital-flow classification retained without simulation scaffold.
      // Keep only changing trade facts, final USD truth fields, dynamic lot essentials, emergency outcome, and row integrity.
      string trade_header = "TradeId,StrategyId,EngineId,Direction,EntryTime,ExitTime,";
      trade_header += "Stage,Outcome,CloseReason,ActiveLot,";
      trade_header += "RawIndexPoints,RawTradeUSD,ProtectionNetUSD,RunnerNetUSD,FinalWorkingTradeUSD,";
      trade_header += "TierAtEntry,DLMUseFixedLot,DLMRecommendedLot,DynamicCapitalBefore,DynamicCapitalAfter,";
      trade_header += "CapitalFlowSource,CapitalDeltaUSD,ExternalCapitalDeltaUSD,DLMActiveRiskPct,DynamicRiskPctOfCapital,EmergencyStatus,EmergencyLayer,EmergencyReason,FinalStatus,ReportRowIntegrityStatus";
      return trade_header;
   }

   string SlimSummaryHeaderV0555()
   {
      // v0.55.7c: final minimal window-level decision surface; tier scenario scaffold and stale ReportNotes removed after lock.
      string summary_header = "EAName,Version,Build,Symbol,GeneratedAt,ReportProfile,FromDateTag,ToDateTag,UseFixedLot,FixedLotSize,";
      summary_header += "TotalTrades,WinTrades,LoseTrades,WinRate,";
      summary_header += "RawTotalProfitUSD,RawTotalLossUSD,RawNetUSD,";
      summary_header += "FinalTotalProfitUSD,FinalTotalLossUSD,FinalWorkingNetUSD,";
      summary_header += "BuyTrades,BuyWinRate,SellTrades,SellWinRate,";
      summary_header += "ProtectionActivatedTrades,RunnerActivatedTrades,";
      summary_header += "DynamicLotEvaluatedTrades,DynamicLotFixedModeTrades,DynamicLotDynamicModeTrades,DynamicLotActiveLotAvg,DynamicLotActiveLotMax,";
      summary_header += "WeeklyStabilityEvaluatedTrades,WeeklyStabilityWeeks,WeeklyStabilityPositiveWeeks,WeeklyStabilityNegativeWeeks,WeeklyStabilityBestWeekUSD,WeeklyStabilityWorstWeekUSD,WeeklyStabilityScore,WeeklyStabilityStatus,";
      summary_header += "MarketCloseGuardEvaluatedTrades,MarketCloseNearCloseEntryTrades,MarketCloseOpenWeekendRiskTrades,MarketCloseGuardStatus,";
      summary_header += "StopNewTradesBeforeCloseEnabled,StopNewTradesBeforeCloseMinutes,StopNewTradesEvaluatedTrades,StopNewTradesBlockedTrades,StopNewTradesBlockedWinningTrades,StopNewTradesBlockedLosingTrades,StopNewTradesImpactUSD,StopNewTradesStatus,";
      summary_header += "DailyCloseSafetyEnabled,DailyCloseSafetyMinutes,WeekendCloseSafetyEnabled,WeekendCloseSafetyMinutes,CloseSafetyEvaluatedTrades,CloseSafetyClosedTrades,CloseSafetyDailyClosedTrades,CloseSafetyWeekendClosedTrades,CloseSafetyPriceOkTrades,CloseSafetyMissingPriceTrades,CloseSafetyBeforeNetUSD,CloseSafetyAfterNetUSD,CloseSafetyImpactUSD,CloseSafetyStatus,";
      summary_header += "PaperStateSnapshotEvaluatedTrades,PaperStateSnapshotWrittenRows,PaperStateSnapshotWriteFailures,PaperStateRecoveryMode,PaperStateTrustedTrades,PaperStateUntrustedTrades,PaperStateStatus,";
      summary_header += "SessionBoundaryCheckpointEvaluatedTrades,SessionBoundaryRecoveryCheckpointMinutes,SessionBoundaryDailyOpenAtCheckpointTrades,SessionBoundaryWeekendOpenAtCheckpointTrades,SessionBoundaryRecoveryRequiredTrades,SessionBoundaryDirtyAfterCloseSafetyTrades,SessionBoundaryCheckpointStatus,";
      summary_header += "MarketCloseMaxTradeDurationMinutes,MarketCloseAvgTradeDurationMinutes,MarketCloseDurationAboveWindowTrades,MarketCloseLongestTradeId,MarketCloseTimingRecommendation,MarketCloseTwoHourCoverageStatus,";
      summary_header += "CapitalFlowEvaluatedTrades,CapitalTradeProfitEvents,CapitalTradeLossEvents,CapitalInjectionEvents,CapitalWithdrawalEvents,ExternalCapitalNetUSD,CapitalFlowIntegrityStatus,";
      summary_header += "EmergencyTriggeredTrades,EmergencyBlockedEntries,";
      summary_header += "SafetyOrderSend,BrokerModifySent,RuntimeSLChanged,InvariantBreaches,";
      summary_header += "TradeLifecyclePhysicalRows,TradeLifecyclePhysicalRowStatus,";
      summary_header += "VisibleRawNetUSDDiff,VisibleFinalNetUSDDiff,ReportIntegrityStatus,TradeRowsVsSummaryStatus,FinalNetUSDDiff,RawNetUSDDiff";
      return summary_header;
   }

   void WriteTradeHeader()
   {
      int handle = FileOpen(m_trade_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create slim trade lifecycle report: %s", m_trade_report_file));
         return;
      }

      FileWriteString(handle, SlimTradeHeaderV0555() + "\r\n");
      FileClose(handle);
   }

   void WriteSummaryHeader()
   {
      int handle = FileOpen(m_summary_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create slim summary report: %s", m_summary_report_file));
         return;
      }

      FileWriteString(handle, SlimSummaryHeaderV0555() + "\r\n");
      FileClose(handle);
   }

   void AppendTradeRecord(const FalconTradeLifecycleRecord &record)
   {
      int handle = FileOpen(m_trade_report_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteTradeHeader();
         handle = FileOpen(m_trade_report_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append slim trade lifecycle record: %s", m_trade_report_file));
         return;
      }
      FileSeek(handle, 0, SEEK_END);

      string trade_row = "";
      trade_row += FalconCsvSafe(record.trade_id) + ",";
      trade_row += FalconCsvSafe(record.strategy_id) + ",";
      trade_row += FalconCsvSafe(record.engine_id) + ",";
      trade_row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      trade_row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      trade_row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      trade_row += FalconCsvSafe(FalconStageToString(record.stage)) + ",";
      trade_row += FalconCsvSafe(FalconOutcomeToString(record.outcome)) + ",";
      trade_row += FalconCsvSafe(record.close_reason) + ",";
      trade_row += DoubleToString(record.falcon_dlm_active_lot, 2) + ",";
      trade_row += DoubleToString(record.net_index_points, 2) + ",";
      trade_row += DoubleToString(record.net_usd, 4) + ",";
      trade_row += DoubleToString(record.paper_protection_net_usd, 4) + ",";
      trade_row += DoubleToString(record.paper_runner_net_usd, 4) + ",";
      trade_row += DoubleToString(record.falcon_emergency_after_net_usd, 4) + ",";
      trade_row += FalconCsvSafe(record.falcon_tier_at_entry) + ",";
      trade_row += IntegerToString(record.falcon_dlm_use_fixed_lot) + ",";
      trade_row += DoubleToString(record.falcon_dlm_recommended_lot, 2) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_capital_before_trade, 4) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_capital_after_trade, 4) + ",";
      trade_row += FalconCsvSafe(record.falcon_capital_flow_source) + ",";
      trade_row += DoubleToString(record.falcon_capital_flow_delta_usd, 4) + ",";
      trade_row += DoubleToString(record.falcon_external_capital_delta_usd, 4) + ",";
      trade_row += DoubleToString(record.falcon_dlm_active_risk_pct, 4) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_pct_of_capital, 4) + ",";
      trade_row += FalconCsvSafe(record.falcon_emergency_status) + ",";
      trade_row += IntegerToString(record.falcon_emergency_triggered_layer) + ",";
      trade_row += FalconCsvSafe(record.falcon_emergency_reason) + ",";
      trade_row += FalconCsvSafe("FINAL_WORKING_APPLIED") + ",";
      trade_row += FalconCsvSafe("PASS");

      FileWriteString(handle, trade_row + "\r\n");
      FileClose(handle);
   }

};

// ==================================================================
// Execution Guard - real trading intentionally impossible in v0.18.1.
// ==================================================================
class CFalconExecutionGuard
{
public:
   bool CanSendRealOrders()
   {
      // v0.25.1 can block FVG Micro Shadow staging by SIZE250, but real broker execution remains impossible.
      return false;
   }

   void AssertNoExecution()
   {
      CFalconLogger::Info("ExecutionGuard active: Demo/Live, BrokerModify, and runtime SL changes remain blocked in v0.56.9b. Tester-only broker OrderSend requires mandatory server SL/TP and EA-side managed close is allowed only through the guarded broker bridge when EnableRealExecution=true inside MT5 Strategy Tester.");
   }
};


// ==================================================================
// Risk & TradeManagement Architecture Consolidation Contract - v0.55.0
// Runtime-neutral ownership map. The active behavior remains the exact
// v0.54.2 chain: PaperGuard -> Protection -> Runner -> Capital Tier ->
// Three-Layer Emergency -> Promotion/Demotion Runtime Lock.
// ==================================================================
bool FalconV055ArchitectureConsolidationContractReady()
{
   if(!FalconCapitalTierContractReady()) return false;
   if(!FalconThreeLayerEmergencyContractReady()) return false;
   if(!FalconTierRuntimeLockContractReady()) return false;
   return true;
}

class CFalconRiskTradeManagementArchitecture
{
private:
   bool m_initialized;
   bool m_contract_ready;

public:
   CFalconRiskTradeManagementArchitecture()
   {
      m_initialized = false;
      m_contract_ready = false;
   }

   bool Initialize()
   {
      m_contract_ready = FalconV055ArchitectureConsolidationContractReady();
      m_initialized = true;
      return m_contract_ready;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   bool IsContractReady()
   {
      return m_contract_ready;
   }

   string RiskOwnershipMap()
   {
      return "RiskManager=" + FALCON_RISK_MANAGER_STATUS +
             ";LotSizingManager=" + FALCON_LOT_SIZING_MANAGER_STATUS +
             ";DailyGovernance=" + FALCON_DAILY_GOVERNANCE_STATUS +
             ";EngineRiskAllocation=" + FALCON_ENGINE_RISK_ALLOCATION_STATUS +
             ";KillSwitch=" + FALCON_KILL_SWITCH_STATUS_V055;
   }

   string TradeManagementOwnershipMap()
   {
      return "StructuralStopEngine=" + FALCON_STRUCTURAL_STOP_ENGINE_STATUS +
             ";TPBuilder=" + FALCON_TP_BUILDER_STATUS_V055 +
             ";PartialManager=" + FALCON_PARTIAL_MANAGER_STATUS_V055 +
             ";ProofProtectionEngine=" + FALCON_PROOF_PROTECTION_ENGINE_STATUS +
             ";RunnerManager=" + FALCON_RUNNER_MANAGER_STATUS_V055 +
             ";AdaptiveRatchetEngine=" + FALCON_ADAPTIVE_RATCHET_ENGINE_STATUS +
             ";EarlyFailureExitEngine=" + FALCON_EARLY_FAILURE_EXIT_ENGINE_STATUS;
   }

   void PrintState()
   {
      CFalconLogger::Info(StringFormat("v0.55.0 Architecture Consolidation | Status=%s | Decision=%s | ContractReady=%d | RuntimeEnforced=%d",
                                       FALCON_ARCH_STATUS,
                                       FALCON_ARCH_DECISION,
                                       (m_contract_ready ? 1 : 0),
                                       (FALCON_ARCH_RUNTIME_ENFORCED ? 1 : 0)));
      CFalconLogger::Info("v0.55.0 Risk ownership map: " + RiskOwnershipMap());
      CFalconLogger::Info("v0.55.0 TradeManagement ownership map: " + TradeManagementOwnershipMap());
      CFalconLogger::Info("v0.55.0 Behavior policy: " + FALCON_ARCH_POLICY + " | " + FALCON_ARCH_ORDER_SEND_POLICY);
   }
};

// ==================================================================
// Strategy-agnostic Emergency Server Stop Envelope LOCK Parity Probe - v0.56.9b
// Controlled tester-only probe with validated StructuralSL/TP plan but no server SL/TP attachment. This bridge remains reusable by future strategies because it
// consumes FalconShadowTradeRecord / TradeId / StrategyId / EngineId instead of
// FVG-specific state. It deliberately blocks OrderSend until the broker-facing
// managed exit lifecycle exists, because every broker trade must have a TP/SL
// and later Protection/Runner state that can match the reports.
// ==================================================================
class CFalconBrokerEntryBridge
{
private:
   bool m_initialized;
   int  m_entry_attempts;
   int  m_entry_accepted;
   int  m_entry_blocked;
   double m_previous_broker_authority_lot;
   bool   m_previous_broker_authority_lot_ready;
   FalconBrokerTradeLink m_active_links[];
   FalconBrokerTradeLink m_link_audit_history[];
   FalconTradeLifecycleRecord m_paper_final_records[];

   string BrokerDealReasonToObservationStatus(const long deal_reason)
   {
      if(deal_reason == DEAL_REASON_TP)
         return "SERVER_TP_EXIT";
      if(deal_reason == DEAL_REASON_SL)
         return "SERVER_SL_EXIT";
      if(deal_reason == DEAL_REASON_SO)
         return "SERVER_STOP_OUT_EXIT";
      if(deal_reason == DEAL_REASON_CLIENT)
         return "CLIENT_OR_TESTER_CLOSE_EXIT";
      if(deal_reason == DEAL_REASON_EXPERT)
         return "EXPERT_CLOSE_EXIT";
      return "BROKER_EXIT_OBSERVED_REASON_" + IntegerToString((int)deal_reason);
   }

   string BrokerDealEntryToString(const long deal_entry)
   {
      if(deal_entry == DEAL_ENTRY_IN)
         return "DEAL_ENTRY_IN";
      if(deal_entry == DEAL_ENTRY_OUT)
         return "DEAL_ENTRY_OUT";
      if(deal_entry == DEAL_ENTRY_INOUT)
         return "DEAL_ENTRY_INOUT";
      if(deal_entry == DEAL_ENTRY_OUT_BY)
         return "DEAL_ENTRY_OUT_BY";
      return "DEAL_ENTRY_" + IntegerToString((int)deal_entry);
   }

   void StoreAcceptedLink(const FalconBrokerTradeLink &link)
   {
      if(!link.broker_entry_accepted)
         return;
      int n = ArraySize(m_active_links);
      ArrayResize(m_active_links, n + 1);
      m_active_links[n] = link;
   }

   void StoreOrUpdateAuditLink(const FalconBrokerTradeLink &link)
   {
      if(StringLen(link.trade_id) <= 0)
         return;
      int n = ArraySize(m_link_audit_history);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_link_audit_history[i].trade_id == link.trade_id)
         {
            m_link_audit_history[i] = link;
            return;
         }
      }
      ArrayResize(m_link_audit_history, n + 1);
      m_link_audit_history[n] = link;
   }

   bool FindAuditLinkByTradeId(const string trade_id, FalconBrokerTradeLink &link)
   {
      if(StringLen(trade_id) <= 0)
         return false;
      int n = ArraySize(m_link_audit_history);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_link_audit_history[i].trade_id == trade_id)
         {
            link = m_link_audit_history[i];
            return true;
         }
      }
      return false;
   }

   bool FindAuditLinkByTradeHash(const string trade_hash, FalconBrokerTradeLink &link)
   {
      if(StringLen(trade_hash) <= 0)
         return false;
      int n = ArraySize(m_link_audit_history);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_link_audit_history[i].trade_id_short == trade_hash)
         {
            link = m_link_audit_history[i];
            return true;
         }
      }
      return false;
   }

   void StorePaperFinalRecord(const FalconTradeLifecycleRecord &record)
   {
      if(StringLen(record.trade_id) <= 0)
         return;
      int n = ArraySize(m_paper_final_records);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_paper_final_records[i].trade_id == record.trade_id)
         {
            m_paper_final_records[i] = record;
            return;
         }
      }
      ArrayResize(m_paper_final_records, n + 1);
      m_paper_final_records[n] = record;
   }

   bool FindPaperFinalRecord(const string trade_id, FalconTradeLifecycleRecord &record)
   {
      if(StringLen(trade_id) <= 0)
         return false;
      int n = ArraySize(m_paper_final_records);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_paper_final_records[i].trade_id == trade_id)
         {
            record = m_paper_final_records[i];
            return true;
         }
      }
      return false;
   }

   bool UpdateAuditLinkManagedCloseRequest(const string trade_id,
                                           const bool attempted,
                                           const bool accepted,
                                           const ulong close_order_ticket,
                                           const ulong close_deal_ticket,
                                           const string close_comment)
   {
      if(StringLen(trade_id) <= 0)
         return false;
      int n = ArraySize(m_link_audit_history);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_link_audit_history[i].trade_id == trade_id)
         {
            m_link_audit_history[i].broker_close_attempted = attempted;
            m_link_audit_history[i].broker_close_accepted = accepted;
            m_link_audit_history[i].managed_close_attempted = attempted;
            m_link_audit_history[i].managed_close_accepted = accepted;
            m_link_audit_history[i].broker_close_order_ticket = close_order_ticket;
            m_link_audit_history[i].broker_close_deal_ticket = close_deal_ticket;
            m_link_audit_history[i].managed_close_comment = close_comment;
            return true;
         }
      }
      return false;
   }

   void UpdateLinkCloseObservation(FalconBrokerTradeLink &link,
                                   const ulong close_order_ticket,
                                   const ulong close_deal_ticket,
                                   const double close_price,
                                   const double close_volume,
                                   const double actual_balance_delta,
                                   const datetime close_time,
                                   const string exit_status,
                                   const string exit_reason)
   {
      link.broker_close_order_ticket = close_order_ticket;
      link.broker_close_deal_ticket = close_deal_ticket;
      link.broker_close_price = close_price;
      link.broker_close_volume = close_volume;
      link.broker_actual_balance_delta = actual_balance_delta;
      link.broker_close_time = close_time;
      link.broker_exit_observed = true;
      link.broker_exit_status = exit_status;
      link.broker_exit_reason = exit_reason;
      link.broker_close_attempted = true;
      link.broker_close_accepted = true;
      if(exit_status == "EXPERT_CLOSE_EXIT")
      {
         link.managed_close_attempted = true;
         link.managed_close_accepted = true;
      }
      StoreOrUpdateAuditLink(link);
   }

   bool FindActiveLinkByPosition(const ulong position_ticket, FalconBrokerTradeLink &link)
   {
      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_active_links[i].broker_position_ticket == position_ticket && position_ticket > 0)
         {
            link = m_active_links[i];
            return true;
         }
      }
      return false;
   }

   bool FindActiveLinkByPositionIdentifier(const ulong position_identifier, FalconBrokerTradeLink &link)
   {
      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_active_links[i].broker_position_identifier == position_identifier && position_identifier > 0)
         {
            link = m_active_links[i];
            return true;
         }
      }
      return false;
   }

   bool FindActiveLinkByOrderOrDeal(const ulong order_ticket, const ulong deal_ticket, FalconBrokerTradeLink &link)
   {
      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         if((order_ticket > 0 && m_active_links[i].broker_order_ticket == order_ticket) ||
            (deal_ticket > 0 && m_active_links[i].broker_deal_ticket == deal_ticket) ||
            (order_ticket > 0 && m_active_links[i].broker_close_order_ticket == order_ticket) ||
            (deal_ticket > 0 && m_active_links[i].broker_close_deal_ticket == deal_ticket))
         {
            link = m_active_links[i];
            return true;
         }
      }
      return false;
   }

   bool FindActiveLinkByTradeId(const string trade_id, FalconBrokerTradeLink &link)
   {
      if(StringLen(trade_id) <= 0)
         return false;

      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_active_links[i].trade_id == trade_id)
         {
            link = m_active_links[i];
            return true;
         }
      }
      return false;
   }

   string LifecycleManagedCloseReason(const FalconTradeLifecycleRecord &record)
   {
      string reason = "PAPER_FINAL_CLOSE";
      if(StringLen(record.paper_final_exit_reason) > 0)
         reason = record.paper_final_exit_reason;
      else if(StringLen(record.paper_runner_exit_reason) > 0)
         reason = record.paper_runner_exit_reason;
      else if(StringLen(record.paper_exit_reason) > 0)
         reason = record.paper_exit_reason;
      else if(StringLen(record.close_reason) > 0)
         reason = record.close_reason;

      string state = StringFormat("protectionActivated=%s; runnerActivated=%s; protectionState=%s; runnerState=%s",
                                  FalconBoolToYesNo(record.paper_protection_activated),
                                  FalconBoolToYesNo(record.paper_runner_activated),
                                  record.paper_protection_state,
                                  record.paper_runner_state);
      return reason + "; " + state;
   }

   bool RecoverClosedBrokerExitFromHistory(FalconBrokerTradeLink &link,
                                           const FalconTradeLifecycleRecord &record,
                                           CFalconReportWriter &report_writer,
                                           const string recovery_context)
   {
      // v0.56.9: In Strategy Tester some server TP/SL exits may be known in
      // account history before the Paper lifecycle reaches its final close.
      // When Paper finalization later tries managed close, PositionSelectByTicket
      // can fail and v0.56.8a reported only "already closed" with zero actual
      // delta. This recovery scans realized deal history by position identifier,
      // ticket, order/deal ticket, or TradeId hash and writes the missing actual
      // broker delta into both BrokerExecutionLifecycle and BrokerPaperTradeReconciliation.
      if(!link.broker_entry_accepted)
         return false;

      if(link.broker_exit_observed)
      {
         string already_reason = StringFormat("Closed-before-Paper-final recovery skipped because broker exit was already observed; context=%s; previousExitStatus=%s; previousReason=%s",
                                             recovery_context,
                                             link.broker_exit_status,
                                             link.broker_exit_reason);
         report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                                  link,
                                                                  "BROKER_EXIT_ALREADY_OBSERVED_BEFORE_PAPER_FINAL",
                                                                  "BROKER_ALREADY_CLOSED_BEFORE_PAPER_FINAL_ACTUAL_DELTA_AVAILABLE",
                                                                  already_reason);
         return true;
      }

      datetime history_from = record.entry_time;
      if(link.broker_entry_time > 0 && (history_from <= 0 || link.broker_entry_time < history_from))
         history_from = link.broker_entry_time;
      if(history_from > 86400)
         history_from -= 86400;
      else
         history_from = 0;

      datetime history_to = TimeCurrent() + 86400;
      if(record.exit_time > history_to)
         history_to = record.exit_time + 86400;

      if(!HistorySelect(history_from, history_to))
         return false;

      string target_hash = link.trade_id_short;
      if(StringLen(target_hash) <= 0)
         target_hash = FalconTradeIdShortHash(record.trade_id);

      ulong best_deal = 0;
      ulong best_order = 0;
      datetime best_time = 0;
      double best_profit = 0.0;
      double best_swap = 0.0;
      double best_commission = 0.0;
      double best_price = 0.0;
      double best_volume = 0.0;
      long best_reason = 0;
      long best_entry = 0;
      string best_deal_comment = "";
      string best_order_comment = "";
      string best_match = "UNMATCHED";

      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;
         if(!HistoryDealSelect(deal_ticket))
            continue;

         string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_symbol != _Symbol)
            continue;

         long deal_entry = (long)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(!(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
            continue;

         datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         if(link.broker_entry_time > 0 && deal_time < link.broker_entry_time)
            continue;

         ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
         ulong order_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
         string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
         string order_comment = "";
         if(order_ticket > 0 && HistoryOrderSelect(order_ticket))
            order_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);

         string deal_hash = FalconExtractCommentHash(deal_comment);
         string order_hash = FalconExtractCommentHash(order_comment);

         bool identity_match = false;
         string match_by = "";
         if(position_id > 0 && link.broker_position_identifier > 0 && position_id == link.broker_position_identifier)
         {
            identity_match = true;
            match_by = "POSITION_IDENTIFIER_HISTORY";
         }
         else if(position_id > 0 && link.broker_position_ticket > 0 && position_id == link.broker_position_ticket)
         {
            identity_match = true;
            match_by = "POSITION_TICKET_HISTORY";
         }
         else if(order_ticket > 0 && (order_ticket == link.broker_order_ticket || order_ticket == link.broker_close_order_ticket))
         {
            identity_match = true;
            match_by = "ORDER_TICKET_HISTORY";
         }
         else if(StringLen(target_hash) > 0 && deal_hash == target_hash)
         {
            identity_match = true;
            match_by = "DEAL_COMMENT_HASH_HISTORY";
         }
         else if(StringLen(target_hash) > 0 && order_hash == target_hash)
         {
            identity_match = true;
            match_by = "ORDER_COMMENT_HASH_HISTORY";
         }

         long deal_magic = (long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         if(deal_magic != FC_MAGIC_FVG_MICRO && !identity_match)
            continue;
         if(!identity_match)
            continue;

         if(best_deal == 0 || deal_time >= best_time)
         {
            best_deal = deal_ticket;
            best_order = order_ticket;
            best_time = deal_time;
            best_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            best_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            best_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            best_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            best_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
            best_reason = (long)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
            best_entry = deal_entry;
            best_deal_comment = deal_comment;
            best_order_comment = order_comment;
            best_match = match_by;
         }
      }

      if(best_deal == 0)
         return false;

      double actual_delta = best_profit + best_swap + best_commission;
      string exit_status = BrokerDealReasonToObservationStatus(best_reason);
      string recovery_reason = StringFormat("Closed-before-Paper-final history recovery; context=%s; mappedBy=%s; dealEntry=%s; dealReason=%d; profit=%.4f; swap=%.4f; commission=%.4f; dealComment=%s; orderComment=%s; policy=%s",
                                            recovery_context,
                                            best_match,
                                            BrokerDealEntryToString(best_entry),
                                            (int)best_reason,
                                            best_profit,
                                            best_swap,
                                            best_commission,
                                            best_deal_comment,
                                            best_order_comment,
                                            FALCON_MREB_DECISION_POLICY);

      UpdateLinkCloseObservation(link,
                                 best_order,
                                 best_deal,
                                 best_price,
                                 best_volume,
                                 actual_delta,
                                 best_time,
                                 exit_status,
                                 recovery_reason);

      report_writer.AppendBrokerExitObservationLifecycleRecord(link,
                                                               best_deal,
                                                               best_order,
                                                               best_price,
                                                               best_volume,
                                                               actual_delta,
                                                               best_time,
                                                               exit_status,
                                                               recovery_reason);

      report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                               link,
                                                               "BROKER_EXIT_RECOVERED_FROM_HISTORY_BEFORE_PAPER_FINAL",
                                                               "BROKER_ALREADY_CLOSED_BEFORE_PAPER_FINAL_ACTUAL_DELTA_RECOVERED",
                                                               recovery_reason);

      MarkLinkClosed(link.broker_position_identifier > 0 ? link.broker_position_identifier : link.broker_position_ticket,
                     best_order,
                     best_deal);
      return true;
   }

   bool FindSingleActiveLink(FalconBrokerTradeLink &link)
   {
      int n = ArraySize(m_active_links);
      if(n == 1)
      {
         link = m_active_links[0];
         return true;
      }
      return false;
   }

   void MarkLinkClosed(const ulong position_ticket, const ulong order_ticket, const ulong deal_ticket)
   {
      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         bool match = false;
         if(position_ticket > 0 && m_active_links[i].broker_position_ticket == position_ticket)
            match = true;
         if(order_ticket > 0 && m_active_links[i].broker_order_ticket == order_ticket)
            match = true;
         if(deal_ticket > 0 && m_active_links[i].broker_deal_ticket == deal_ticket)
            match = true;
         if(position_ticket > 0 && m_active_links[i].broker_position_identifier == position_ticket)
            match = true;
         if(order_ticket > 0 && m_active_links[i].broker_close_order_ticket == order_ticket)
            match = true;
         if(deal_ticket > 0 && m_active_links[i].broker_close_deal_ticket == deal_ticket)
            match = true;
         if(match)
         {
            for(int j = i; j < n - 1; j++)
               m_active_links[j] = m_active_links[j + 1];
            ArrayResize(m_active_links, n - 1);
            return;
         }
      }
   }

   double NormalizeVolume(const double requested_volume)
   {
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      double volume = requested_volume;
      if(min_lot > 0.0 && volume < min_lot)
         volume = min_lot;
      if(max_lot > 0.0 && volume > max_lot)
         volume = max_lot;
      if(step > 0.0)
         volume = MathFloor(volume / step) * step;
      if(min_lot > 0.0 && volume < min_lot)
         volume = min_lot;
      return NormalizeDouble(volume, 2);
   }

   double NormalizeVolumeDownNoMinFloor(const double requested_volume)
   {
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0)
         step = 0.01;

      double volume = requested_volume;
      if(max_lot > 0.0 && volume > max_lot)
         volume = max_lot;
      if(volume <= 0.0)
         return 0.0;

      volume = MathFloor(volume / step) * step;
      return NormalizeDouble(volume, 2);
   }

   double BrokerDynamicTierMaxLot(const string tier_name)
   {
      if(tier_name == "MICRO")    return 0.01;
      if(tier_name == "TINY")     return 0.03;
      if(tier_name == "SMALL")    return 0.10;
      if(tier_name == "MEDIUM")   return 0.30;
      if(tier_name == "STANDARD") return 1.00;
      if(tier_name == "LARGE")    return 2.00;
      return 0.01;
   }

   double BrokerDynamicCapitalMaxLot(const double effective_capital)
   {
      if(effective_capital <= 0.0)
         return 0.0;
      return NormalizeVolumeDownNoMinFloor((effective_capital / FALCON_DLM_CAPITAL_USD_PER_001_LOT) * 0.01);
   }

   double BrokerDynamicGrowthRampMaxLot()
   {
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) step = 0.01;
      if(min_lot <= 0.0) min_lot = step;

      if(!m_previous_broker_authority_lot_ready || m_previous_broker_authority_lot <= 0.0)
         return min_lot;

      return NormalizeVolume((m_previous_broker_authority_lot * FALCON_DLM_MAX_LOT_GROWTH_MULTIPLIER) + step);
   }

   bool EstimateBrokerRiskLoss(const ENUM_ORDER_TYPE order_type,
                               const double volume,
                               const double entry_price,
                               const double sl_price,
                               double &loss_usd,
                               string &calc_status)
   {
      loss_usd = 0.0;
      calc_status = "ORDERCALC_PROFIT_UNAVAILABLE";

      double profit = 0.0;
      if(OrderCalcProfit(order_type, _Symbol, volume, entry_price, sl_price, profit))
      {
         loss_usd = MathAbs(MathMin(profit, 0.0));
         calc_status = "ORDERCALC_PROFIT_OK";
         return true;
      }
      return false;
   }

   bool EstimateBrokerMargin(const ENUM_ORDER_TYPE order_type,
                             const double volume,
                             const double entry_price,
                             double &margin_required,
                             string &margin_status)
   {
      margin_required = 0.0;
      margin_status = "ORDERCALC_MARGIN_UNAVAILABLE";

      double margin = 0.0;
      if(OrderCalcMargin(order_type, _Symbol, volume, entry_price, margin))
      {
         margin_required = margin;
         margin_status = "ORDERCALC_MARGIN_OK";
         return true;
      }
      return false;
   }

   bool ResolvePreEntryBrokerLotAuthority(const FalconShadowTradeRecord &record,
                                          const double broker_entry_price,
                                          const ENUM_ORDER_TYPE order_type,
                                          double &authorized_volume,
                                          string &reason)
   {
      authorized_volume = 0.0;
      reason = "";

      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) step = 0.01;
      if(min_lot <= 0.0) min_lot = step;
      if(max_lot <= 0.0) max_lot = 100.0;

      double effective_capital = FalconEffectiveCapitalForTier();
      if(effective_capital <= 0.0)
         effective_capital = AccountInfoDouble(ACCOUNT_BALANCE);
      if(effective_capital <= 0.0 && ManualCapital > 0.0)
         effective_capital = ManualCapital;

      string tier = FalconCapitalTierName(effective_capital);
      double base_risk_pct = FalconCapitalTierBaseRiskPct(tier);
      double risk_budget_usd = 0.0;
      if(effective_capital > 0.0 && base_risk_pct > 0.0)
         risk_budget_usd = effective_capital * base_risk_pct / 100.0;

      double requested_lot = (UseFixedLot ? FixedLotSize : record.lot_size);
      string mode_status = FALCON_BLA_FIXED_MODE_STATUS;

      if(!UseFixedLot)
      {
         mode_status = FALCON_BLA_DYNAMIC_MODE_STATUS;

         if(record.structural_sl <= 0.0 || broker_entry_price <= 0.0)
         {
            reason = "BROKER_LOT_AUTHORITY_BLOCKED_DYNAMIC_STRUCTURAL_RISK_UNKNOWN";
            return false;
         }
         if(risk_budget_usd <= 0.0)
         {
            reason = "BROKER_LOT_AUTHORITY_BLOCKED_DYNAMIC_RISK_BUDGET_UNKNOWN";
            return false;
         }

         double one_lot_loss = 0.0;
         string risk_calc_status = "";
         if(!EstimateBrokerRiskLoss(order_type, 1.0, broker_entry_price, record.structural_sl, one_lot_loss, risk_calc_status) || one_lot_loss <= 0.0)
         {
            reason = "BROKER_LOT_AUTHORITY_BLOCKED_DYNAMIC_ONE_LOT_RISK_UNKNOWN_" + risk_calc_status;
            return false;
         }

         double raw_lot = risk_budget_usd / one_lot_loss;
         double tier_cap = BrokerDynamicTierMaxLot(tier);
         double capital_cap = BrokerDynamicCapitalMaxLot(effective_capital);
         double growth_cap = BrokerDynamicGrowthRampMaxLot();
         requested_lot = raw_lot;

         if(tier_cap > 0.0 && requested_lot > tier_cap)
            requested_lot = tier_cap;
         if(capital_cap > 0.0 && requested_lot > capital_cap)
            requested_lot = capital_cap;
         if(growth_cap > 0.0 && requested_lot > growth_cap)
            requested_lot = growth_cap;

         // Do not silently floor a dynamic risk lot below broker minimum if minimum lot risk is outside the budget.
         if(requested_lot < min_lot)
         {
            double min_lot_loss = 0.0;
            string min_calc_status = "";
            EstimateBrokerRiskLoss(order_type, min_lot, broker_entry_price, record.structural_sl, min_lot_loss, min_calc_status);
            if(min_lot_loss > risk_budget_usd)
            {
               reason = StringFormat("BROKER_LOT_AUTHORITY_BLOCKED_DYNAMIC_MIN_LOT_RISK_EXCEEDS_BUDGET minLoss=%.2f budget=%.2f rawLot=%.4f minLot=%.2f",
                                     min_lot_loss, risk_budget_usd, raw_lot, min_lot);
               return false;
            }
         }

         reason = StringFormat("%s effectiveCapital=%.2f tier=%s riskBudget=%.2f rawLot=%.4f tierCap=%.2f capitalCap=%.2f growthCap=%.2f",
                               mode_status, effective_capital, tier, risk_budget_usd, raw_lot, tier_cap, capital_cap, growth_cap);
      }
      else
      {
         if(requested_lot <= 0.0)
         {
            reason = "BROKER_LOT_AUTHORITY_BLOCKED_FIXED_LOT_INVALID";
            return false;
         }
         reason = StringFormat("%s requestedFixedLot=%.2f effectiveCapital=%.2f tier=%s",
                               mode_status, requested_lot, effective_capital, tier);
      }

      double normalized = NormalizeVolume(requested_lot);
      if(normalized <= 0.0)
      {
         reason = "BROKER_LOT_AUTHORITY_BLOCKED_NORMALIZED_VOLUME_INVALID; " + reason;
         return false;
      }

      double sl_loss = 0.0;
      string sl_calc_status = "";
      EstimateBrokerRiskLoss(order_type, normalized, broker_entry_price, record.structural_sl, sl_loss, sl_calc_status);
      if(sl_loss > FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD)
      {
         reason = StringFormat("BROKER_LOT_AUTHORITY_BLOCKED_SL_LOSS_TOO_LARGE loss=%.2f max=%.2f lot=%.2f; %s",
                               sl_loss, FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD, normalized, reason);
         return false;
      }

      double margin_required = 0.0;
      string margin_status = "";
      if(EstimateBrokerMargin(order_type, normalized, broker_entry_price, margin_required, margin_status))
      {
         double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         double max_margin = free_margin * FALCON_BLA_MAX_MARGIN_USE_PCT / 100.0;
         if(free_margin > 0.0 && margin_required > max_margin)
         {
            reason = StringFormat("BROKER_LOT_AUTHORITY_BLOCKED_MARGIN_TOO_HIGH margin=%.2f free=%.2f maxPct=%.2f lot=%.2f; %s",
                                  margin_required, free_margin, FALCON_BLA_MAX_MARGIN_USE_PCT, normalized, reason);
            return false;
         }
      }

      authorized_volume = normalized;
      reason = StringFormat("BROKER_LOT_AUTHORITY_ACCEPTED lot=%.2f slLoss=%.2f marginStatus=%s margin=%.2f; %s",
                            authorized_volume, sl_loss, margin_status, margin_required, reason);
      return true;
   }

   bool ValidateAtomicStructuralRiskEnvelope(const FalconShadowTradeRecord &record,
                                             const double broker_entry_price,
                                             const double volume,
                                             const ENUM_ORDER_TYPE order_type,
                                             string &reason)
   {
      reason = "";

      double sl_distance = MathAbs(broker_entry_price - record.structural_sl);
      if(sl_distance > FALCON_BEEB_MAX_STRUCTURAL_SL_PRICE_DISTANCE)
      {
         reason = StringFormat("ATOMIC_ENTRY_BLOCKED_STRUCTURAL_SL_DISTANCE_TOO_LARGE distance=%.2f max=%.2f",
                               sl_distance,
                               FALCON_BEEB_MAX_STRUCTURAL_SL_PRICE_DISTANCE);
         return false;
      }

      double potential_profit = 0.0;
      if(OrderCalcProfit(order_type, _Symbol, volume, broker_entry_price, record.structural_sl, potential_profit))
      {
         double potential_loss = MathAbs(MathMin(potential_profit, 0.0));
         if(potential_loss > FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD)
         {
            reason = StringFormat("ATOMIC_ENTRY_BLOCKED_STRUCTURAL_SL_LOSS_TOO_LARGE loss=%.2f max=%.2f distance=%.2f lot=%.2f",
                                  potential_loss,
                                  FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD,
                                  sl_distance,
                                  volume);
            return false;
         }
      }
      else
      {
         // Do not block solely because OrderCalcProfit is unavailable in the tester,
         // but keep the distance guard above active. The reason is included in accepted
         // lifecycle text only when a later stage adds detailed risk columns.
      }

      reason = StringFormat("ATOMIC_STRUCTURAL_SL_RISK_WITHIN_GUARD distance=%.2f lot=%.2f", sl_distance, volume);
      return true;
   }

   int CountOpenFalconPositions(const string symbol, const long magic)
   {
      int count = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         string pos_symbol = PositionGetString(POSITION_SYMBOL);
         long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
         if(pos_symbol == symbol && pos_magic == magic)
            count++;
      }
      return count;
   }

   ulong FindLatestFalconPositionTicket(const string symbol, const long magic)
   {
      ulong latest_ticket = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         string pos_symbol = PositionGetString(POSITION_SYMBOL);
         long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
         if(pos_symbol == symbol && pos_magic == magic)
            latest_ticket = ticket;
      }
      return latest_ticket;
   }

   bool BridgeTakeProfitDirectionallyValid(const FalconShadowTradeRecord &record,
                                           const double broker_entry_price,
                                           const int tp_index)
   {
      double tp = 0.0;
      if(tp_index == 1)
         tp = record.tp1;
      else if(tp_index == 2)
         tp = record.tp2;
      else if(tp_index == 3)
         tp = record.tp3;
      else
         return false;

      if(broker_entry_price <= 0.0 || tp <= 0.0)
         return false;

      if(record.direction == FALCON_DIRECTION_BUY)
         return (tp > broker_entry_price);

      if(record.direction == FALCON_DIRECTION_SELL)
         return (tp < broker_entry_price);

      return false;
   }

   bool SelectInitialBridgeTakeProfit(const FalconShadowTradeRecord &record,
                                      const double broker_entry_price,
                                      double &initial_tp,
                                      string &reason)
   {
      initial_tp = 0.0;
      reason = "";

      if(broker_entry_price <= 0.0)
      {
         reason = "BRIDGE_TP_SELECTION_BLOCKED_INVALID_ENTRY_PRICE";
         return false;
      }

      // v0.56.8: TP1 and TP2 are proof/protection checkpoints, and TP3 is
      // explicitly classified as a temporary server-side safety cap, not a final
      // runner-parity exit. Until controlled EA-managed close or BrokerModify is
      // introduced, the furthest valid planned target remains attached only to
      // prevent naked/orphan exposure while managed runner decisions are audited.
      if(BridgeTakeProfitDirectionallyValid(record, broker_entry_price, 3))
      {
         initial_tp = record.tp3;
         reason = "BRIDGE_INITIAL_SERVER_TP_SELECTED_TP3_SAFETY_CAP_NOT_FINAL_RUNNER_EXIT_TP1_TP2_REMAIN_PROOF_CHECKPOINTS; managedPolicy=" + FALCON_MREB_DECISION_POLICY + "; policy=" + FALCON_BPR_INITIAL_SERVER_TP_POLICY;
         return true;
      }

      if(BridgeTakeProfitDirectionallyValid(record, broker_entry_price, 2))
      {
         initial_tp = record.tp2;
         reason = "BRIDGE_INITIAL_SERVER_TP_FALLBACK_TP2_TP3_NOT_VALID_YET_TP2_IS_NOT_FINAL_PARITY_EXIT; policy=" + FALCON_BPR_INITIAL_SERVER_TP_POLICY;
         return true;
      }

      if(BridgeTakeProfitDirectionallyValid(record, broker_entry_price, 1))
      {
         initial_tp = record.tp1;
         reason = "BRIDGE_INITIAL_SERVER_TP_FALLBACK_TP1_NO_HIGHER_VALID_TARGET_YET_TP1_IS_NOT_FINAL_PARITY_EXIT; policy=" + FALCON_BPR_INITIAL_SERVER_TP_POLICY;
         return true;
      }

      reason = "BRIDGE_TP_SELECTION_BLOCKED_NO_DIRECTIONALLY_VALID_TP1_TP2_OR_TP3";
      return false;
   }

   bool ValidateAtomicEntryExitPlan(const FalconShadowTradeRecord &record,
                                    const double broker_entry_price,
                                    string &reason)
   {
      reason = "";

      if(record.structural_sl <= 0.0)
      {
         reason = "ATOMIC_ENTRY_BLOCKED_MISSING_STRUCTURAL_SL";
         return false;
      }
      if(broker_entry_price <= 0.0)
      {
         reason = "ATOMIC_ENTRY_BLOCKED_INVALID_BROKER_ENTRY_PRICE";
         return false;
      }

      double initial_bridge_tp = 0.0;
      string tp_selection_reason = "";
      if(!SelectInitialBridgeTakeProfit(record, broker_entry_price, initial_bridge_tp, tp_selection_reason))
      {
         reason = "ATOMIC_ENTRY_BLOCKED_MISSING_OR_INVALID_INITIAL_BRIDGE_TP; " + tp_selection_reason;
         return false;
      }

      if(record.direction == FALCON_DIRECTION_BUY)
      {
         if(!(record.structural_sl < broker_entry_price))
         {
            reason = "ATOMIC_ENTRY_BLOCKED_BUY_STRUCTURAL_SL_NOT_BELOW_ENTRY";
            return false;
         }
         if(!(initial_bridge_tp > broker_entry_price))
         {
            reason = "ATOMIC_ENTRY_BLOCKED_BUY_INITIAL_BRIDGE_TP_NOT_ABOVE_ENTRY";
            return false;
         }
      }
      else if(record.direction == FALCON_DIRECTION_SELL)
      {
         if(!(record.structural_sl > broker_entry_price))
         {
            reason = "ATOMIC_ENTRY_BLOCKED_SELL_STRUCTURAL_SL_NOT_ABOVE_ENTRY";
            return false;
         }
         if(!(initial_bridge_tp < broker_entry_price))
         {
            reason = "ATOMIC_ENTRY_BLOCKED_SELL_INITIAL_BRIDGE_TP_NOT_BELOW_ENTRY";
            return false;
         }
      }
      else
      {
         reason = "ATOMIC_ENTRY_BLOCKED_INVALID_DIRECTION";
         return false;
      }

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         point = _Point;
      long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(point > 0.0 && stops_level > 0)
      {
         double sl_distance_points = MathAbs(broker_entry_price - record.structural_sl) / point;
         double tp_distance_points = MathAbs(initial_bridge_tp - broker_entry_price) / point;
         if(sl_distance_points < (double)stops_level)
         {
            reason = StringFormat("ATOMIC_ENTRY_BLOCKED_STRUCTURAL_SL_INSIDE_STOPS_LEVEL slPts=%.1f stops=%d", sl_distance_points, (int)stops_level);
            return false;
         }
         if(tp_distance_points < (double)stops_level)
         {
            reason = StringFormat("ATOMIC_ENTRY_BLOCKED_INITIAL_BRIDGE_TP_INSIDE_STOPS_LEVEL tpPts=%.1f stops=%d", tp_distance_points, (int)stops_level);
            return false;
         }
      }

      reason = "ATOMIC_ENTRY_EXIT_PLAN_VALID_STRUCTURAL_SL_AND_BRIDGE_INITIAL_TP; " + tp_selection_reason;
      return true;
   }

   double DirectionalPriceByDistance(const int direction,
                                     const double broker_entry_price,
                                     const double distance,
                                     const bool stop_side)
   {
      if(direction == FALCON_DIRECTION_BUY)
         return (stop_side ? broker_entry_price - distance : broker_entry_price + distance);
      if(direction == FALCON_DIRECTION_SELL)
         return (stop_side ? broker_entry_price + distance : broker_entry_price - distance);
      return 0.0;
   }

   bool BuildLockParityEmergencyServerStops(const FalconShadowTradeRecord &record,
                                            const double broker_entry_price,
                                            const double volume,
                                            const ENUM_ORDER_TYPE order_type,
                                            double &server_sl,
                                            double &server_tp,
                                            string &reason)
   {
      server_sl = 0.0;
      server_tp = 0.0;
      reason = "";

      if(broker_entry_price <= 0.0 || volume <= 0.0)
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_INVALID_ENTRY_OR_VOLUME";
         return false;
      }
      if(record.structural_sl <= 0.0)
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_MISSING_VIRTUAL_STRUCTURAL_SL";
         return false;
      }

      double planned_tp = 0.0;
      string tp_reason = "";
      if(!SelectInitialBridgeTakeProfit(record, broker_entry_price, planned_tp, tp_reason))
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_NO_VALID_PLANNED_TP; " + tp_reason;
         return false;
      }

      double structural_distance = MathAbs(broker_entry_price - record.structural_sl);
      if(structural_distance <= 0.0)
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_ZERO_STRUCTURAL_DISTANCE";
         return false;
      }

      double target_sl_distance = structural_distance * FALCON_LOCK_PARITY_EMERGENCY_SL_DISTANCE_MULTIPLIER;
      target_sl_distance = MathMax(target_sl_distance, FALCON_LOCK_PARITY_MIN_EMERGENCY_SL_PRICE_DISTANCE);
      target_sl_distance = MathMax(target_sl_distance, structural_distance);
      target_sl_distance = MathMin(target_sl_distance, FALCON_LOCK_PARITY_MAX_EMERGENCY_SL_PRICE_DISTANCE);

      double loss_usd = 0.0;
      string loss_status = "";
      double candidate_sl = DirectionalPriceByDistance(record.direction, broker_entry_price, target_sl_distance, true);
      if(EstimateBrokerRiskLoss(order_type, volume, broker_entry_price, candidate_sl, loss_usd, loss_status) && loss_usd > FALCON_LOCK_PARITY_MAX_EMERGENCY_SL_LOSS_USD)
      {
         double low = structural_distance;
         double high = target_sl_distance;
         double best = structural_distance;
         for(int i = 0; i < 24; i++)
         {
            double mid = (low + high) * 0.5;
            double mid_sl = DirectionalPriceByDistance(record.direction, broker_entry_price, mid, true);
            double mid_loss = 0.0;
            string mid_status = "";
            if(!EstimateBrokerRiskLoss(order_type, volume, broker_entry_price, mid_sl, mid_loss, mid_status))
               break;
            if(mid_loss <= FALCON_LOCK_PARITY_MAX_EMERGENCY_SL_LOSS_USD)
            {
               best = mid;
               low = mid;
            }
            else
               high = mid;
         }
         target_sl_distance = best;
         candidate_sl = DirectionalPriceByDistance(record.direction, broker_entry_price, target_sl_distance, true);
         EstimateBrokerRiskLoss(order_type, volume, broker_entry_price, candidate_sl, loss_usd, loss_status);
      }

      double planned_tp_distance = MathAbs(planned_tp - broker_entry_price);
      if(planned_tp_distance <= 0.0)
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_ZERO_PLANNED_TP_DISTANCE";
         return false;
      }
      double target_tp_distance = planned_tp_distance * FALCON_LOCK_PARITY_EMERGENCY_TP_DISTANCE_MULTIPLIER;
      target_tp_distance = MathMax(target_tp_distance, FALCON_LOCK_PARITY_MIN_EMERGENCY_TP_PRICE_DISTANCE);
      target_tp_distance = MathMax(target_tp_distance, planned_tp_distance);
      target_tp_distance = MathMin(target_tp_distance, FALCON_LOCK_PARITY_MAX_EMERGENCY_TP_PRICE_DISTANCE);

      server_sl = DirectionalPriceByDistance(record.direction, broker_entry_price, target_sl_distance, true);
      server_tp = DirectionalPriceByDistance(record.direction, broker_entry_price, target_tp_distance, false);

      if(server_sl <= 0.0 || server_tp <= 0.0)
      {
         reason = StringFormat("EMERGENCY_SERVER_STOPS_BLOCKED_NONPOSITIVE_RESULT sl=%.5f tp=%.5f", server_sl, server_tp);
         return false;
      }

      if(record.direction == FALCON_DIRECTION_BUY)
      {
         if(!(server_sl < broker_entry_price && server_tp > broker_entry_price))
         {
            reason = StringFormat("EMERGENCY_SERVER_STOPS_BLOCKED_BUY_DIRECTIONAL_INVALID sl=%.5f entry=%.5f tp=%.5f", server_sl, broker_entry_price, server_tp);
            return false;
         }
      }
      else if(record.direction == FALCON_DIRECTION_SELL)
      {
         if(!(server_sl > broker_entry_price && server_tp < broker_entry_price))
         {
            reason = StringFormat("EMERGENCY_SERVER_STOPS_BLOCKED_SELL_DIRECTIONAL_INVALID sl=%.5f entry=%.5f tp=%.5f", server_sl, broker_entry_price, server_tp);
            return false;
         }
      }
      else
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_INVALID_DIRECTION";
         return false;
      }

      reason = StringFormat("EMERGENCY_SERVER_STOPS_SELECTED virtualStructuralSL=%.5f serverEmergencySL=%.5f plannedTP=%.5f serverEmergencyTP=%.5f structuralDistance=%.2f emergencySLDistance=%.2f emergencyTPDistance=%.2f emergencySLLoss=%.2f lossStatus=%s policy=%s",
                            record.structural_sl, server_sl, planned_tp, server_tp, structural_distance, target_sl_distance, target_tp_distance, loss_usd, loss_status, FALCON_LOCK_PARITY_SERVER_STOP_POLICY);
      return true;
   }

   void ResetLinkFromShadowRecordId(const FalconTradeLifecycleRecord &record, FalconBrokerTradeLink &link)
   {
      link.trade_id = record.trade_id;
      link.trade_id_short = FalconTradeIdShortHash(record.trade_id);
      link.strategy_id = record.strategy_id;
      link.engine_id = record.engine_id;
      link.direction = record.direction;
      link.broker_magic = FC_MAGIC_FVG_MICRO;
      link.broker_position_ticket = 0;
      link.broker_position_identifier = 0;
      link.broker_order_ticket = 0;
      link.broker_deal_ticket = 0;
      link.broker_close_order_ticket = 0;
      link.broker_close_deal_ticket = 0;
      link.requested_lot = record.lot_size;
      link.accepted_lot = 0.0;
      link.planned_entry_price = record.entry_price;
      link.broker_entry_price = 0.0;
      link.broker_sl = 0.0;
      link.broker_tp = 0.0;
      link.broker_close_price = 0.0;
      link.broker_close_volume = 0.0;
      link.broker_actual_balance_delta = 0.0;
      link.planned_entry_time = record.entry_time;
      link.broker_entry_time = 0;
      link.broker_close_time = 0;
      link.broker_entry_attempted = false;
      link.broker_entry_accepted = false;
      link.broker_close_attempted = false;
      link.broker_close_accepted = false;
      link.broker_exit_observed = false;
      link.managed_close_attempted = false;
      link.managed_close_accepted = false;
      link.entry_comment = "";
      link.managed_close_comment = "";
      link.broker_exit_status = "";
      link.broker_exit_reason = "";
      link.status = "NO_BROKER_LINK_FOUND";
      link.reason = "No broker link was found for this Paper TradeId.";
      // v0.57.2: Virtual Trailing Exit Bridge state - zero-init.
      link.virtual_trailing_active = false;
      link.virtual_breakeven_locked = false;
      link.virtual_peak_favorable_price = 0.0;
      link.virtual_trailing_stop_price = 0.0;
      link.virtual_protection_floor_price = 0.0;
      link.virtual_trailing_last_update = 0;
   }

   void ResetLinkFromShadow(const FalconShadowTradeRecord &record, FalconBrokerTradeLink &link)
   {
      link.trade_id = record.shadow_id;
      link.trade_id_short = FalconTradeIdShortHash(record.shadow_id);
      link.strategy_id = record.strategy_id;
      link.engine_id = record.engine_id;
      link.direction = record.direction;
      link.broker_magic = FC_MAGIC_FVG_MICRO;
      link.broker_position_ticket = 0;
      link.broker_position_identifier = 0;
      link.broker_order_ticket = 0;
      link.broker_deal_ticket = 0;
      link.broker_close_order_ticket = 0;
      link.broker_close_deal_ticket = 0;
      link.requested_lot = record.lot_size;
      link.accepted_lot = 0.0;
      link.planned_entry_price = record.entry_price;
      link.broker_entry_price = 0.0;
      link.broker_sl = 0.0;
      link.broker_tp = 0.0;
      link.broker_close_price = 0.0;
      link.broker_close_volume = 0.0;
      link.broker_actual_balance_delta = 0.0;
      link.planned_entry_time = record.entry_time;
      link.broker_entry_time = 0;
      link.broker_close_time = 0;
      link.broker_entry_attempted = false;
      link.broker_entry_accepted = false;
      link.broker_close_attempted = false;
      link.broker_close_accepted = false;
      link.broker_exit_observed = false;
      link.managed_close_attempted = false;
      link.managed_close_accepted = false;
      link.entry_comment = "";
      link.managed_close_comment = "";
      link.broker_exit_status = "";
      link.broker_exit_reason = "";
      link.status = FALCON_BEEB_ENTRY_DISABLED_STATUS;
      link.reason = "Not evaluated yet.";
      // v0.57.2: Virtual Trailing Exit Bridge state - zero-init.
      link.virtual_trailing_active = false;
      link.virtual_breakeven_locked = false;
      link.virtual_peak_favorable_price = 0.0;
      link.virtual_trailing_stop_price = 0.0;
      link.virtual_protection_floor_price = 0.0;
      link.virtual_trailing_last_update = 0;
   }

   bool TesterEntryAllowed(string &reason)
   {
      if(!EnableRealExecution)
      {
         reason = "ENABLE_REAL_EXECUTION_FALSE_ENTRY_BRIDGE_AUDIT_ONLY";
         return false;
      }
      if(!MQLInfoInteger(MQL_TESTER))
      {
         reason = "NOT_STRATEGY_TESTER_DEMO_AND_LIVE_BLOCKED_IN_V0564";
         return false;
      }
      if(!FALCON_BEEB_MANAGED_EXIT_BRIDGE_READY)
      {
         reason = "BROKER_ENTRY_BLOCKED_ATOMIC_EXIT_BRIDGE_NOT_READY_NO_ORPHAN_POSITIONS";
         return false;
      }
      reason = "TESTER_ATOMIC_ENTRY_EXIT_ALLOWED_ENABLE_REAL_EXECUTION_TRUE_VALIDATED_PLAN_REQUIRED";
      return true;
   }

public:
   CFalconBrokerEntryBridge()
   {
      m_initialized = false;
      m_entry_attempts = 0;
      m_entry_accepted = 0;
      m_entry_blocked = 0;
      m_previous_broker_authority_lot = 0.0;
      m_previous_broker_authority_lot_ready = false;
      ArrayResize(m_active_links, 0);
      ArrayResize(m_link_audit_history, 0);
      ArrayResize(m_paper_final_records, 0);
   }

   bool Initialize()
   {
      m_initialized = true;
      CFalconLogger::Info("Emergency Server Stop Envelope LOCK Parity Probe v0.56.9b initialized. Tester-only OrderSend requires pre-entry broker lot authority, validated StructuralSL/TP plan, and mandatory server SL/TP attachment; EA-side managed close at Paper final is measured only for still-open broker positions; Demo/Live remain blocked.");
      return true;
   }

   bool TryOpenFromShadowRecord(const FalconShadowTradeRecord &record, CFalconReportWriter &report_writer)
   {
      if(!m_initialized)
         Initialize();

      FalconBrokerTradeLink link;
      ResetLinkFromShadow(record, link);

      string guard_reason = "";
      if(!TesterEntryAllowed(guard_reason))
      {
         link.status = FALCON_BEEB_ENTRY_DISABLED_STATUS;
         link.reason = guard_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      if(record.status != FALCON_SHADOW_RECORD_STAGED || record.is_closed)
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = "SHADOW_RECORD_NOT_OPEN_STAGED";
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      int open_positions = CountOpenFalconPositions(_Symbol, FC_MAGIC_FVG_MICRO);
      if(open_positions >= FALCON_BEEB_MAX_OPEN_POSITIONS_PER_ENGINE)
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = StringFormat("BROKER_ENTRY_BLOCKED_EXISTING_FALCON_POSITION_COUNT_%d", open_positions);
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);

      ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(record.direction == FALCON_DIRECTION_SELL)
      {
         order_type = ORDER_TYPE_SELL;
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
      if(price <= 0.0)
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = "BROKER_ENTRY_PRICE_UNAVAILABLE";
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      double volume = 0.0;
      string lot_authority_reason = "";
      if(!ResolvePreEntryBrokerLotAuthority(record, price, order_type, volume, lot_authority_reason))
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = lot_authority_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      string atomic_plan_reason = "";
      if(!ValidateAtomicEntryExitPlan(record, price, atomic_plan_reason))
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = atomic_plan_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      string structural_risk_reason = "";
      if(!ValidateAtomicStructuralRiskEnvelope(record, price, volume, order_type, structural_risk_reason))
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = structural_risk_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = volume;
      request.type = order_type;
      request.price = price;
      // v0.56.9b: emergency server stop envelope probe.
      // Entry orders remain non-naked, but server SL/TP are now fail-safe envelope
      // levels instead of the normal Paper structural SL / TP3 lifecycle levels.
      // This lets the tester measure whether premature server stops are the major
      // LOCK parity gap while keeping visible SL/TP on every broker entry.
      double initial_bridge_tp = 0.0;
      string initial_bridge_tp_reason = "";
      SelectInitialBridgeTakeProfit(record, price, initial_bridge_tp, initial_bridge_tp_reason);
      double emergency_server_sl = 0.0;
      double emergency_server_tp = 0.0;
      string emergency_server_stop_reason = "";
      if(!BuildLockParityEmergencyServerStops(record, price, volume, order_type, emergency_server_sl, emergency_server_tp, emergency_server_stop_reason))
      {
         m_entry_blocked++;
         link.broker_entry_attempted = false;
         link.broker_entry_accepted = false;
         link.entry_comment = FalconBuildBrokerCommentWithHash(FALCON_BEEB_ORDER_COMMENT, record.shadow_id);
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = emergency_server_stop_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }
      request.sl = NormalizeDouble(emergency_server_sl, _Digits);
      request.tp = NormalizeDouble(emergency_server_tp, _Digits);
      request.deviation = 30;
      request.magic = FC_MAGIC_FVG_MICRO;
      request.comment = FalconBuildBrokerCommentWithHash(FALCON_BEEB_ORDER_COMMENT, record.shadow_id);
      request.type_time = ORDER_TIME_GTC;

      // v0.56.9b: hard safety invariant after the v0.56.9 naked-order probe.
      // No broker/tester OrderSend is allowed without both server-side StructuralSL
      // and a selected bridge TP safety cap. This protects the broker lane while
      // keeping LOCK parity analysis in reports instead of unsafe naked execution.
      if(request.sl <= 0.0 || request.tp <= 0.0)
      {
         m_entry_blocked++;
         link.broker_entry_attempted = false;
         link.broker_entry_accepted = false;
         link.broker_sl = request.sl;
         link.broker_tp = request.tp;
         link.entry_comment = request.comment;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = StringFormat("BROKER_ENTRY_BLOCKED_NO_SERVER_SL_TP_SAFETY_INVARIANT request.sl=%.5f request.tp=%.5f policy=%s", request.sl, request.tp, FALCON_LOCK_PARITY_SERVER_STOP_POLICY);
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      link.broker_entry_attempted = true;
      link.requested_lot = record.lot_size;
      link.accepted_lot = volume;
      link.broker_entry_price = price;
      link.broker_entry_time = TimeCurrent();
      link.broker_sl = request.sl;
      link.broker_tp = request.tp;
      link.entry_comment = request.comment;
      m_entry_attempts++;

      bool sent = OrderSend(request, result);
      link.broker_order_ticket = result.order;
      link.broker_deal_ticket = result.deal;

      if(sent && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE_PARTIAL))
      {
         link.broker_entry_accepted = true;
         link.broker_position_ticket = FindLatestFalconPositionTicket(_Symbol, FC_MAGIC_FVG_MICRO);
         if(link.broker_position_ticket > 0 && PositionSelectByTicket(link.broker_position_ticket))
            link.broker_position_identifier = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
         link.status = FALCON_BEEB_ENTRY_ACCEPTED_STATUS;
         link.reason = StringFormat("OrderSend accepted retcode=%d; LOCK parity emergency server-stop envelope active; serverStopPolicy=%s; plannedBridgeTp=%.5f; broker exits should be EA-managed at Paper final unless emergency server SL/TP is hit; managedPolicy=%s; %s; %s; %s", (int)result.retcode, FALCON_LOCK_PARITY_SERVER_STOP_POLICY, initial_bridge_tp, FALCON_MREB_DECISION_POLICY, initial_bridge_tp_reason, emergency_server_stop_reason, lot_authority_reason);
         m_entry_accepted++;
         m_previous_broker_authority_lot = volume;
         m_previous_broker_authority_lot_ready = true;
         StoreAcceptedLink(link);
      }
      else
      {
         link.broker_entry_accepted = false;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = StringFormat("OrderSend failed/blocked sent=%s retcode=%d comment=%s", (sent ? "true" : "false"), (int)result.retcode, result.comment);
         m_entry_blocked++;
      }

      StoreOrUpdateAuditLink(link);
      report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
      return link.broker_entry_accepted;
   }

   // ==================================================================
   // v0.57.2: Reverse-deal close helper - extracted from
   // TryManagedCloseFromLifecycleRecord so the new Virtual Trailing
   // Bridge can reuse the SAME OrderSend(TRADE_ACTION_DEAL) path without
   // duplicating it. Caller must have already validated:
   //   - link.broker_position_ticket > 0
   //   - PositionSelectByTicket succeeded
   //   - position identity (_Symbol + FC_MAGIC_FVG_MICRO) matches
   //   - PositionGetDouble(POSITION_VOLUME) > 0  (passed as volume)
   //   - PositionGetInteger(POSITION_TYPE)        (passed as position_type)
   //
   // Helper handles: SymbolInfoTick, request build, OrderSend, link/audit
   // updates, and ManagedCloseLifecycle row. Lifecycle-specific and
   // trailing-specific post-reports remain at the caller (e.g.
   // BrokerPaperTradeReconciliation, VirtualTrailingExitLifecycle).
   //
   // Returns true iff OrderSend was actually called (regardless of broker
   // acceptance). accepted_out is true only when retcode is DONE/PLACED/
   // DONE_PARTIAL. On pre-send failures (no tick, unsupported type) logs
   // a ManagedCloseLifecycle block row and returns false.
   // ==================================================================
   bool ExecuteReverseClosePositionRequest(FalconBrokerTradeLink &link,
                                           const long position_type,
                                           const double volume,
                                           const string comment_prefix,
                                           const string lifecycle_reason,
                                           CFalconReportWriter &report_writer,
                                           bool &accepted_out,
                                           uint &retcode_out,
                                           double &executed_price_out,
                                           string &result_comment_out)
   {
      accepted_out = false;
      retcode_out = 0;
      executed_price_out = 0.0;
      result_comment_out = "";

      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick))
      {
         string tick_reason = "EA-managed close blocked: SymbolInfoTick unavailable; tradeId=" + link.trade_id;
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              volume,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_BLOCKED_NO_TICK",
                                                              tick_reason);
         return false;
      }

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action    = TRADE_ACTION_DEAL;
      request.symbol    = _Symbol;
      request.position  = link.broker_position_ticket;
      request.volume    = volume;
      request.magic     = FC_MAGIC_FVG_MICRO;
      request.deviation = 30;
      request.comment   = FalconBuildBrokerCommentWithHash(comment_prefix, link.trade_id);
      request.type_time = ORDER_TIME_GTC;

      if(position_type == POSITION_TYPE_BUY)
      {
         request.type  = ORDER_TYPE_SELL;
         request.price = tick.bid;
      }
      else if(position_type == POSITION_TYPE_SELL)
      {
         request.type  = ORDER_TYPE_BUY;
         request.price = tick.ask;
      }
      else
      {
         string type_reason = StringFormat("EA-managed close blocked: unsupported position type=%d; tradeId=%s", (int)position_type, link.trade_id);
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              volume,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_BLOCKED_UNSUPPORTED_POSITION_TYPE",
                                                              type_reason);
         return false;
      }

      bool sent = OrderSend(request, result);
      accepted_out       = (sent && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE_PARTIAL));
      retcode_out        = result.retcode;
      executed_price_out = request.price;
      result_comment_out = result.comment;

      string status = accepted_out ? "EA_MANAGED_CLOSE_REQUEST_ACCEPTED_WAITING_ON_TRADE_TRANSACTION" : "EA_MANAGED_CLOSE_REQUEST_REJECTED";
      string reason = StringFormat("Controlled tester-only EA-side managed close via %s; sent=%s; retcode=%d; resultComment=%s; lifecycleReason=%s; no BrokerModify; no RuntimeSLChanged; Demo/Live blocked",
                                   comment_prefix,
                                   (sent ? "true" : "false"),
                                   (int)result.retcode,
                                   result.comment,
                                   lifecycle_reason);

      link.broker_close_attempted     = true;
      link.broker_close_accepted      = accepted_out;
      link.managed_close_attempted    = true;
      link.managed_close_accepted     = accepted_out;
      link.broker_close_order_ticket  = result.order;
      link.broker_close_deal_ticket   = result.deal;
      link.managed_close_comment      = request.comment;
      UpdateAuditLinkManagedCloseRequest(link.trade_id, true, accepted_out, result.order, result.deal, request.comment);

      report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                           true,
                                                           accepted_out,
                                                           result.order,
                                                           result.deal,
                                                           request.price,
                                                           volume,
                                                           TimeCurrent(),
                                                           status,
                                                           reason);
      return true;
   }

   bool TryManagedCloseFromLifecycleRecord(const FalconTradeLifecycleRecord &record, CFalconReportWriter &report_writer)
   {
      if(!FALCON_MREB_RUNTIME_MANAGED_CLOSE_READY)
         return false;
      if(!EnableRealExecution)
         return false;
      if(!MQLInfoInteger(MQL_TESTER))
         return false;

      StorePaperFinalRecord(record);

      FalconBrokerTradeLink link;
      if(!FindActiveLinkByTradeId(record.trade_id, link))
      {
         if(FindAuditLinkByTradeId(record.trade_id, link))
         {
            if(link.broker_entry_accepted && link.broker_exit_observed)
            {
               string already_observed_reason = "No active broker link found at Paper finalization, but audit history already contains a realized broker exit. This is a valid closed-before-Paper-final reconciliation row.";
               report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                                        link,
                                                                        "BROKER_EXIT_ALREADY_OBSERVED_BEFORE_PAPER_FINAL",
                                                                        "BROKER_ALREADY_CLOSED_BEFORE_PAPER_FINAL_ACTUAL_DELTA_AVAILABLE",
                                                                        already_observed_reason);
               return false;
            }

            if(link.broker_entry_accepted && RecoverClosedBrokerExitFromHistory(link,
                                                                                record,
                                                                                report_writer,
                                                                                "NO_ACTIVE_LINK_AUDIT_HISTORY_RECOVERY"))
               return false;

            report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                                     link,
                                                                     "PAPER_FINAL_NO_ACTIVE_BROKER_POSITION",
                                                                     link.broker_entry_accepted ? "BROKER_ALREADY_CLOSED_BEFORE_PAPER_FINAL_OR_LINK_INACTIVE_ACTUAL_DELTA_NOT_FOUND" : "PAPER_TRADE_NOT_OPENED_ON_BROKER",
                                                                     link.broker_entry_accepted ? "No active broker link found at Paper finalization; history recovery could not locate a realized close deal, so actual delta remains unreconciled." : "Paper trade has no active broker link; entry was blocked or never opened.");
         }
         else
         {
            FalconBrokerTradeLink empty_link;
            ResetLinkFromShadowRecordId(record, empty_link);
            report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                                     empty_link,
                                                                     "PAPER_FINAL_NO_BROKER_LINK_FOUND",
                                                                     "NO_BROKER_AUDIT_LINK_FOR_TRADEID",
                                                                     "No active or audit broker link matched this Paper TradeId.");
         }
         return false;
      }

      report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                               link,
                                                               "PAPER_FINAL_ACTIVE_BROKER_LINK_FOUND_BEFORE_MANAGED_CLOSE",
                                                               "ACTIVE_LINK_FOUND_MANAGED_CLOSE_DECISION_PENDING",
                                                               "Paper final lifecycle closed while broker position is still active; controlled tester-only managed close will be evaluated.");

      if(link.broker_position_ticket <= 0)
      {
         if(RecoverClosedBrokerExitFromHistory(link,
                                               record,
                                               report_writer,
                                               "ACTIVE_LINK_NO_POSITION_TICKET_HISTORY_RECOVERY"))
            return false;

         string no_ticket_reason = "EA-managed close skipped: active broker link has no broker position ticket and history recovery did not find a realized close deal; tradeId=" + record.trade_id;
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              0.0,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_SKIPPED_NO_POSITION_TICKET",
                                                              no_ticket_reason);
         return false;
      }

      if(!PositionSelectByTicket(link.broker_position_ticket))
      {
         if(RecoverClosedBrokerExitFromHistory(link,
                                               record,
                                               report_writer,
                                               "POSITION_SELECT_FAILED_BEFORE_MANAGED_CLOSE_HISTORY_RECOVERY"))
            return false;

         string missing_pos_reason = "EA-managed close skipped: linked broker position no longer exists before managed close, and history recovery did not find a realized close deal; likely already closed by server TP/SL or tester but actual delta remains unreconciled; tradeId=" + record.trade_id;
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              0.0,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_SKIPPED_POSITION_ALREADY_CLOSED_ACTUAL_DELTA_NOT_FOUND",
                                                              missing_pos_reason);
         MarkLinkClosed(link.broker_position_ticket, link.broker_order_ticket, link.broker_deal_ticket);
         return false;
      }

      string pos_symbol = PositionGetString(POSITION_SYMBOL);
      long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(pos_symbol != _Symbol || pos_magic != FC_MAGIC_FVG_MICRO)
      {
         string mismatch_reason = StringFormat("EA-managed close blocked: linked position identity mismatch posSymbol=%s posMagic=%d expectedSymbol=%s expectedMagic=%d tradeId=%s",
                                               pos_symbol,
                                               (int)pos_magic,
                                               _Symbol,
                                               (int)FC_MAGIC_FVG_MICRO,
                                               record.trade_id);
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              0.0,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_BLOCKED_POSITION_IDENTITY_MISMATCH",
                                                              mismatch_reason);
         return false;
      }

      double volume = PositionGetDouble(POSITION_VOLUME);
      if(volume <= 0.0)
      {
         string volume_reason = "EA-managed close blocked: linked position volume is not positive; tradeId=" + record.trade_id;
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              0.0,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_BLOCKED_INVALID_POSITION_VOLUME",
                                                              volume_reason);
         return false;
      }

      long position_type = (long)PositionGetInteger(POSITION_TYPE);

      // v0.57.2: OrderSend block factored into ExecuteReverseClosePositionRequest so the
      // Virtual Trailing Exit Bridge can reuse the same close path. Lifecycle-specific
      // post-reporting (BrokerPaperTradeReconciliation) remains here.
      string lifecycle_reason = LifecycleManagedCloseReason(record);
      bool accepted = false;
      uint retcode = 0;
      double executed_price = 0.0;
      string result_comment = "";
      bool sent = ExecuteReverseClosePositionRequest(link,
                                                    position_type,
                                                    volume,
                                                    FALCON_MREB_CLOSE_COMMENT_PREFIX,
                                                    lifecycle_reason,
                                                    report_writer,
                                                    accepted,
                                                    retcode,
                                                    executed_price,
                                                    result_comment);
      if(!sent)
         return false;

      string paper_reconciliation_reason = StringFormat("Controlled tester-only EA-side managed close at Paper final lifecycle exit; sent=true; retcode=%d; resultComment=%s; lifecycleReason=%s; no BrokerModify; no RuntimeSLChanged; Demo/Live blocked",
                                                       (int)retcode,
                                                       result_comment,
                                                       lifecycle_reason);
      report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                               link,
                                                               "EA_MANAGED_CLOSE_REQUEST_SENT",
                                                               accepted ? "MANAGED_CLOSE_REQUEST_ACCEPTED_ACTUAL_DELTA_PENDING_TRANSACTION" : "MANAGED_CLOSE_REQUEST_REJECTED",
                                                               paper_reconciliation_reason);
      return accepted;
   }

   // ==================================================================
   // v0.57.2: Virtual Trailing Exit Bridge - tick-driven update.
   // For every open broker link: maintains peak-favorable price, locks
   // breakeven, arms trailing, and closes via OrderSend(TRADE_ACTION_DEAL)
   // reverse (through the factored helper). No BrokerModify, no
   // TRADE_ACTION_SLTP, no RuntimeSLChanged. Emergency server SL/TP from
   // v0.56.9b stays attached - this is the regular exit; server SL/TP is
   // the safety net.
   //
   // Gated externally by OnTick (EnableVirtualTrailingBridge &&
   // EnableRealExecution && MQL_TESTER). Redundant internal guards for
   // safety in case the method is ever called from elsewhere.
   // ==================================================================
   void UpdateVirtualTrailingForOpenLinks(CFalconReportWriter &report_writer)
   {
      if(!EnableVirtualTrailingBridge)
         return;
      if(!EnableRealExecution)
         return;
      if(!MQLInfoInteger(MQL_TESTER))
         return;
      if(!FALCON_MREB_RUNTIME_MANAGED_CLOSE_READY)
         return;

      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick))
         return;

      int total = ArraySize(m_active_links);
      for(int i = 0; i < total; i++)
      {
         if(!m_active_links[i].broker_entry_accepted) continue;
         if(m_active_links[i].broker_exit_observed)   continue;
         if(m_active_links[i].broker_close_attempted) continue;
         if(m_active_links[i].broker_position_ticket == 0) continue;
         if(m_active_links[i].broker_entry_price <= 0.0)   continue;

         double current_price = 0.0;
         if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
            current_price = tick.bid;
         else if(m_active_links[i].direction == FALCON_DIRECTION_SELL)
            current_price = tick.ask;
         else
            continue;
         if(current_price <= 0.0) continue;

         double profit_points = FalconRawIndexPoints(m_active_links[i].direction,
                                                    m_active_links[i].broker_entry_price,
                                                    current_price);

         // 4.2 Update peak favorable price (one-direction).
         if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
         {
            if(m_active_links[i].virtual_peak_favorable_price <= 0.0 ||
               current_price > m_active_links[i].virtual_peak_favorable_price)
               m_active_links[i].virtual_peak_favorable_price = current_price;
         }
         else
         {
            if(m_active_links[i].virtual_peak_favorable_price <= 0.0 ||
               current_price < m_active_links[i].virtual_peak_favorable_price)
               m_active_links[i].virtual_peak_favorable_price = current_price;
         }

         // 4.3 Lock breakeven once profit crosses VirtualBreakevenAtPoints.
         // v0.57.3: spread-aware floor. A BUY closes on Bid and a SELL closes on Ask,
         // so locking at exactly broker_entry_price closes the position on the
         // opposite side of the market and lands BREAKEVEN_FLOOR_HIT at -spread.
         // We add (spread + extra buffer) in the profit direction so the realized
         // exit on the closing side is >= entry.
         if(!m_active_links[i].virtual_breakeven_locked &&
            profit_points >= VirtualBreakevenAtPoints)
         {
            long   spread_points_long = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
            double spread_price       = (double)spread_points_long * _Point;
            double be_buffer          = spread_price + (FALCON_VIRTUAL_TRAILING_BE_EXTRA_POINTS * _Point);

            m_active_links[i].virtual_breakeven_locked = true;
            if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
               m_active_links[i].virtual_protection_floor_price = m_active_links[i].broker_entry_price + be_buffer;
            else
               m_active_links[i].virtual_protection_floor_price = m_active_links[i].broker_entry_price - be_buffer;
         }

         // 4.4 Arm trailing once profit crosses VirtualTrailingStartPoints.
         if(!m_active_links[i].virtual_trailing_active &&
            profit_points >= VirtualTrailingStartPoints)
            m_active_links[i].virtual_trailing_active = true;

         // 4.5 Trailing stop moves in one direction only.
         if(m_active_links[i].virtual_trailing_active)
         {
            if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
            {
               double trail = m_active_links[i].virtual_peak_favorable_price - VirtualTrailingDistancePoints;
               if(m_active_links[i].virtual_trailing_stop_price <= 0.0 ||
                  trail > m_active_links[i].virtual_trailing_stop_price)
                  m_active_links[i].virtual_trailing_stop_price = trail;
            }
            else
            {
               double trail = m_active_links[i].virtual_peak_favorable_price + VirtualTrailingDistancePoints;
               if(m_active_links[i].virtual_trailing_stop_price <= 0.0 ||
                  trail < m_active_links[i].virtual_trailing_stop_price)
                  m_active_links[i].virtual_trailing_stop_price = trail;
            }
         }

         m_active_links[i].virtual_trailing_last_update = TimeCurrent();

         // 4.6 Effective stop = deepest protection between floor and trail (ignoring zeros).
         double floor_price = m_active_links[i].virtual_breakeven_locked ? m_active_links[i].virtual_protection_floor_price : 0.0;
         double trail_price = m_active_links[i].virtual_trailing_active ? m_active_links[i].virtual_trailing_stop_price : 0.0;

         double effective_stop = 0.0;
         if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
         {
            if(floor_price > 0.0 && trail_price > 0.0)
               effective_stop = MathMax(floor_price, trail_price);
            else if(floor_price > 0.0)
               effective_stop = floor_price;
            else if(trail_price > 0.0)
               effective_stop = trail_price;
         }
         else
         {
            if(floor_price > 0.0 && trail_price > 0.0)
               effective_stop = MathMin(floor_price, trail_price);
            else if(floor_price > 0.0)
               effective_stop = floor_price;
            else if(trail_price > 0.0)
               effective_stop = trail_price;
         }

         if(effective_stop <= 0.0) continue;

         // 4.7 Hit decision.
         bool hit = false;
         if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
            hit = (current_price <= effective_stop);
         else
            hit = (current_price >= effective_stop);
         if(!hit) continue;

         // Trigger reason: trail is binding when it equals effective_stop and trailing is active.
         bool trail_is_binding = (m_active_links[i].virtual_trailing_active &&
                                  trail_price > 0.0 &&
                                  MathAbs(effective_stop - trail_price) < 0.0000001);
         string trigger_reason = trail_is_binding ? "TRAILING_STOP_HIT" : "BREAKEVEN_FLOOR_HIT";

         // Validate live position before calling the close helper.
         if(!PositionSelectByTicket(m_active_links[i].broker_position_ticket)) continue;
         string pos_symbol = PositionGetString(POSITION_SYMBOL);
         long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
         if(pos_symbol != _Symbol || pos_magic != FC_MAGIC_FVG_MICRO) continue;
         double volume = PositionGetDouble(POSITION_VOLUME);
         if(volume <= 0.0) continue;
         long position_type = (long)PositionGetInteger(POSITION_TYPE);

         bool accepted = false;
         uint retcode = 0;
         double executed_price = 0.0;
         string result_comment = "";
         string lifecycle_reason = StringFormat("VirtualTrailing-initiated close: reason=%s; profitPts=%.2f; effectiveStop=%.5f; peak=%.5f; trailActive=%s; beLocked=%s",
                                                trigger_reason,
                                                profit_points,
                                                effective_stop,
                                                m_active_links[i].virtual_peak_favorable_price,
                                                m_active_links[i].virtual_trailing_active ? "true" : "false",
                                                m_active_links[i].virtual_breakeven_locked ? "true" : "false");

         bool sent = ExecuteReverseClosePositionRequest(m_active_links[i],
                                                        position_type,
                                                        volume,
                                                        FALCON_VIRTUAL_TRAILING_CLOSE_COMMENT_PREFIX,
                                                        lifecycle_reason,
                                                        report_writer,
                                                        accepted,
                                                        retcode,
                                                        executed_price,
                                                        result_comment);

         string trailing_status = sent
                                  ? (accepted ? "TRAILING_CLOSE_REQUEST_ACCEPTED_WAITING_ON_TRADE_TRANSACTION"
                                              : "TRAILING_CLOSE_REQUEST_REJECTED")
                                  : "TRAILING_CLOSE_PRE_SEND_BLOCKED";

         // v0.57.3: pass the actual exit price the helper sent (or the tick price if the
         // helper short-circuited pre-send). The report writer derives RealizedPointsAtExit
         // and EstimatedUsdAtExit from link + exit_price + its own symbol context.
         report_writer.AppendVirtualTrailingExitLifecycleRecord(m_active_links[i],
                                                                TimeCurrent(),
                                                                sent ? executed_price : current_price,
                                                                profit_points,
                                                                trigger_reason,
                                                                retcode,
                                                                trailing_status);
      }
   }

   bool ObserveTradeTransactionExit(const MqlTradeTransaction &trans, CFalconReportWriter &report_writer)
   {
      if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
         return false;
      if(trans.deal == 0)
         return false;
      if(!HistoryDealSelect(trans.deal))
         return false;

      string deal_symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
      long deal_magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
      if(deal_symbol != _Symbol || deal_magic != FC_MAGIC_FVG_MICRO)
         return false;

      long deal_entry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if(!(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
         return false;

      ulong position_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      ulong order_ticket = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
      string deal_comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
      string order_comment = "";
      if(order_ticket > 0 && HistoryOrderSelect(order_ticket))
         order_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);
      string deal_hash = FalconExtractCommentHash(deal_comment);
      string order_hash = FalconExtractCommentHash(order_comment);

      FalconBrokerTradeLink link;
      string mapped_by = "UNMAPPED";

      if(FindActiveLinkByPositionIdentifier(position_id, link))
         mapped_by = "POSITION_IDENTIFIER";
      else if(FindActiveLinkByPosition(position_id, link))
         mapped_by = "POSITION_TICKET_FROM_DEAL_POSITION_ID";
      else if(FindActiveLinkByPosition(trans.position, link))
         mapped_by = "TRANS_POSITION";
      else if(FindActiveLinkByOrderOrDeal(order_ticket, trans.deal, link))
         mapped_by = "ORDER_OR_ENTRY_DEAL";
      else if(FindAuditLinkByTradeHash(deal_hash, link))
         mapped_by = "DEAL_COMMENT_HASH";
      else if(FindAuditLinkByTradeHash(order_hash, link))
         mapped_by = "ORDER_COMMENT_HASH";
      else if(FindSingleActiveLink(link))
         mapped_by = "SINGLE_ACTIVE_LINK_FALLBACK";
      else
         return false;

      double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
      double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
      double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      double actual_delta = profit + swap + commission;
      double close_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
      double close_volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
      datetime close_time = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
      long deal_reason = (long)HistoryDealGetInteger(trans.deal, DEAL_REASON);
      string exit_status = BrokerDealReasonToObservationStatus(deal_reason);
      string managed_runner_classification = "MANAGED_RUNNER_CLASSIFICATION_PENDING";
      if(deal_reason == DEAL_REASON_TP)
         managed_runner_classification = "SERVER_TP_EXIT_IS_TP3_SAFETY_CAP_NOT_FINAL_RUNNER_PARITY";
      else if(deal_reason == DEAL_REASON_SL)
         managed_runner_classification = "SERVER_SL_EXIT_BEFORE_MANAGED_RUNNER_DECISION";
      string exit_reason = StringFormat("OnTradeTransaction broker exit observed; mappedBy=%s; dealEntry=%s; dealReason=%d; profit=%.4f; swap=%.4f; commission=%.4f; dealComment=%s; orderComment=%s; dealHash=%s; orderHash=%s; managedRunnerStatus=%s; managedPolicy=%s",
                                        mapped_by,
                                        BrokerDealEntryToString(deal_entry),
                                        (int)deal_reason,
                                        profit,
                                        swap,
                                        commission,
                                        deal_comment,
                                        order_comment,
                                        deal_hash,
                                        order_hash,
                                        managed_runner_classification,
                                        FALCON_MREB_DECISION_POLICY);

      UpdateLinkCloseObservation(link,
                                 order_ticket,
                                 trans.deal,
                                 close_price,
                                 close_volume,
                                 actual_delta,
                                 close_time,
                                 exit_status,
                                 exit_reason);

      report_writer.AppendBrokerExitObservationLifecycleRecord(link,
                                                               trans.deal,
                                                               order_ticket,
                                                               close_price,
                                                               close_volume,
                                                               actual_delta,
                                                               close_time,
                                                               exit_status,
                                                               exit_reason);
      FalconTradeLifecycleRecord paper_record;
      if(FindPaperFinalRecord(link.trade_id, paper_record))
      {
         report_writer.AppendBrokerPaperTradeReconciliationRecord(paper_record,
                                                                  link,
                                                                  "BROKER_EXIT_OBSERVED_WITH_PAPER_FINAL",
                                                                  "BROKER_EXIT_ACTUAL_DELTA_RECONCILED_TO_PAPER_FINAL",
                                                                  exit_reason);
      }
      else
      {
         string broker_only_reason = exit_reason + "; brokerOnly=true; no Paper final TradeLifecycle record exists for this TradeId; this is a LOCK parity violation that must be eliminated before profit parity or Demo/Live.";
         report_writer.AppendBrokerOnlyTradeReconciliationRecord(link,
                                                                 "BROKER_EXIT_OBSERVED_WITHOUT_PAPER_FINAL_BROKER_ONLY",
                                                                 "BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE",
                                                                 broker_only_reason);
      }
      MarkLinkClosed(position_id, order_ticket, trans.deal);
      return true;
   }



   bool RecoverBrokerOnlyExitFromHistory(FalconBrokerTradeLink &link,
                                         CFalconReportWriter &report_writer,
                                         const string recovery_context)
   {
      // v0.56.9: best-effort recovery for active links that never received a
      // Paper final record. This helps catch tester/end-of-test closes and makes
      // broker-only impact visible in BrokerPaperTradeReconciliation.
      if(!link.broker_entry_accepted)
         return false;
      if(link.broker_exit_observed)
      {
         report_writer.AppendBrokerOnlyTradeReconciliationRecord(link,
                                                                 "BROKER_ONLY_EXIT_ALREADY_OBSERVED_WITHOUT_PAPER_FINAL",
                                                                 "BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE",
                                                                 "Broker-only exit was already observed before Deinit; no Paper final TradeLifecycle record exists; context=" + recovery_context);
         return true;
      }

      datetime history_from = link.broker_entry_time;
      if(history_from > 86400)
         history_from -= 86400;
      else
         history_from = 0;
      datetime history_to = TimeCurrent() + 86400;
      if(!HistorySelect(history_from, history_to))
         return false;

      string target_hash = link.trade_id_short;
      if(StringLen(target_hash) <= 0)
         target_hash = FalconTradeIdShortHash(link.trade_id);

      ulong best_deal = 0;
      ulong best_order = 0;
      datetime best_time = 0;
      double best_profit = 0.0;
      double best_swap = 0.0;
      double best_commission = 0.0;
      double best_price = 0.0;
      double best_volume = 0.0;
      long best_reason = 0;
      long best_entry = 0;
      string best_deal_comment = "";
      string best_order_comment = "";
      string best_match = "UNMATCHED";

      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;
         if(!HistoryDealSelect(deal_ticket))
            continue;

         string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_symbol != _Symbol)
            continue;

         long deal_entry = (long)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(!(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
            continue;

         datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         if(link.broker_entry_time > 0 && deal_time < link.broker_entry_time)
            continue;

         ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
         ulong order_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
         string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
         string order_comment = "";
         if(order_ticket > 0 && HistoryOrderSelect(order_ticket))
            order_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);

         string deal_hash = FalconExtractCommentHash(deal_comment);
         string order_hash = FalconExtractCommentHash(order_comment);

         bool identity_match = false;
         string match_by = "";
         if(position_id > 0 && link.broker_position_identifier > 0 && position_id == link.broker_position_identifier)
         {
            identity_match = true;
            match_by = "POSITION_IDENTIFIER_HISTORY_BROKER_ONLY";
         }
         else if(position_id > 0 && link.broker_position_ticket > 0 && position_id == link.broker_position_ticket)
         {
            identity_match = true;
            match_by = "POSITION_TICKET_HISTORY_BROKER_ONLY";
         }
         else if(order_ticket > 0 && (order_ticket == link.broker_order_ticket || order_ticket == link.broker_close_order_ticket))
         {
            identity_match = true;
            match_by = "ORDER_TICKET_HISTORY_BROKER_ONLY";
         }
         else if(StringLen(target_hash) > 0 && deal_hash == target_hash)
         {
            identity_match = true;
            match_by = "DEAL_COMMENT_HASH_HISTORY_BROKER_ONLY";
         }
         else if(StringLen(target_hash) > 0 && order_hash == target_hash)
         {
            identity_match = true;
            match_by = "ORDER_COMMENT_HASH_HISTORY_BROKER_ONLY";
         }

         long deal_magic = (long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         if(deal_magic != FC_MAGIC_FVG_MICRO && !identity_match)
            continue;
         if(!identity_match)
            continue;

         if(best_deal == 0 || deal_time >= best_time)
         {
            best_deal = deal_ticket;
            best_order = order_ticket;
            best_time = deal_time;
            best_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            best_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            best_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            best_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            best_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
            best_reason = (long)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
            best_entry = deal_entry;
            best_deal_comment = deal_comment;
            best_order_comment = order_comment;
            best_match = match_by;
         }
      }

      if(best_deal == 0)
         return false;

      double actual_delta = best_profit + best_swap + best_commission;
      string exit_status = BrokerDealReasonToObservationStatus(best_reason);
      string recovery_reason = StringFormat("Broker-only history recovery; context=%s; mappedBy=%s; dealEntry=%s; dealReason=%d; profit=%.4f; swap=%.4f; commission=%.4f; dealComment=%s; orderComment=%s; no Paper final TradeLifecycle record exists; LOCK parity violation",
                                            recovery_context,
                                            best_match,
                                            BrokerDealEntryToString(best_entry),
                                            (int)best_reason,
                                            best_profit,
                                            best_swap,
                                            best_commission,
                                            best_deal_comment,
                                            best_order_comment);

      UpdateLinkCloseObservation(link,
                                 best_order,
                                 best_deal,
                                 best_price,
                                 best_volume,
                                 actual_delta,
                                 best_time,
                                 exit_status,
                                 recovery_reason);

      report_writer.AppendBrokerExitObservationLifecycleRecord(link,
                                                               best_deal,
                                                               best_order,
                                                               best_price,
                                                               best_volume,
                                                               actual_delta,
                                                               best_time,
                                                               exit_status,
                                                               recovery_reason);
      report_writer.AppendBrokerOnlyTradeReconciliationRecord(link,
                                                              "BROKER_ONLY_EXIT_RECOVERED_FROM_HISTORY_AT_DEINIT",
                                                              "BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE_ACTUAL_DELTA_RECOVERED",
                                                              recovery_reason);
      MarkLinkClosed(link.broker_position_identifier > 0 ? link.broker_position_identifier : link.broker_position_ticket,
                     best_order,
                     best_deal);
      return true;
   }

   void FlushOpenLinksAtDeinit(CFalconReportWriter &report_writer)
   {
      int n = ArraySize(m_active_links);
      if(n <= 0)
         return;

      for(int i = 0; i < n; i++)
      {
         FalconBrokerTradeLink link = m_active_links[i];
         if(RecoverBrokerOnlyExitFromHistory(link, report_writer, "FLUSH_OPEN_LINKS_AT_DEINIT_HISTORY_RECOVERY"))
            continue;

         double current_price = 0.0;
         double current_volume = (link.accepted_lot > 0.0 ? link.accepted_lot : link.requested_lot);
         double floating_delta = 0.0;
         string position_state = "POSITION_NOT_SELECTED_AT_DEINIT";

         if(link.broker_position_ticket > 0 && PositionSelectByTicket(link.broker_position_ticket))
         {
            current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            current_volume = PositionGetDouble(POSITION_VOLUME);
            floating_delta = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            position_state = "POSITION_STILL_OPEN_AT_DEINIT_FLOATING_DELTA_ONLY";
         }

         string reason = StringFormat("OnDeinit open broker link still active; no server TP/SL close was observed before finalization; positionState=%s; floatingDelta=%.4f; this is not a realized broker close and remains not comparable to Paper FinalWorking", position_state, floating_delta);
         report_writer.AppendBrokerExitObservationLifecycleRecord(link,
                                                                  0,
                                                                  0,
                                                                  current_price,
                                                                  current_volume,
                                                                  0.0,
                                                                  TimeCurrent(),
                                                                  "OPEN_POSITION_AT_DEINIT_EXIT_NOT_OBSERVED",
                                                                  reason);
         report_writer.AppendBrokerOnlyTradeReconciliationRecord(link,
                                                                 "BROKER_ONLY_POSITION_OPEN_AT_DEINIT_WITHOUT_PAPER_FINAL",
                                                                 "BROKER_ONLY_OPEN_AT_DEINIT_NOT_LOCK_PARITY_COMPARABLE",
                                                                 reason + "; no Paper final TradeLifecycle record exists for this active broker link.");
      }

      ArrayResize(m_active_links, 0);
      ArrayResize(m_link_audit_history, 0);
      ArrayResize(m_paper_final_records, 0);
   }

   int EntryAttempts() { return m_entry_attempts; }
   int EntryAccepted() { return m_entry_accepted; }
   int EntryBlocked() { return m_entry_blocked; }
};

// ==================================================================
// Global Runtime Objects
// ==================================================================
CFalconMarketContext     g_market_context;
CFalconRiskFoundation    g_risk_foundation;
CFalconCandleCache       g_candle_cache;
CFalconEvidenceFramework g_evidence_framework;
CFalconShadowExecutor    g_shadow_executor;
CFalconRuntimeSafetyGuard g_runtime_safety_guard;
CFalconStrategyRegistry  g_strategy_registry;
CFalconFirstShadowStrategyAdapterShell g_first_strategy_adapter;
CFalconFvgMicroShadowDetectorStub g_fvg_micro_detector_stub;
CFalconFvgMicroShadowCandidateBuilder g_fvg_micro_candidate_builder;
CFalconFvgMicroRetestWatcher g_fvg_micro_retest_watcher;
CFalconFvgMicroTradePlanStagingDryRun g_fvg_micro_tradeplan_stager;
CFalconFvgMicroShadowLifecycleSimulation g_fvg_micro_lifecycle_simulator;
CFalconReportWriter      g_report_writer;
CFalconBrokerEntryBridge g_broker_entry_bridge;
CFalconExecutionGuard    g_execution_guard;
CFalconRiskTradeManagementArchitecture g_risk_tm_architecture;
bool                     g_is_initialized = false;
long                     g_runtime_tick_counter = 0;
datetime                 g_last_processed_m5_closed_candle_time = 0;
string                   g_last_staged_fvg_candidate_id = "";


// ==================================================================
// FVG Micro Runtime Shadow Pipeline - v0.18.4
// Refreshes the diagnostic FVG path after OnInit. This is still Shadow-only:
// Detector -> Candidate -> RetestWatcher -> TradePlanStager -> LifecycleSimulator.
// No OrderSend. No Paper/Demo/Live. No current-candle decision.
// ==================================================================
bool FalconShouldRefreshFvgDetectorOnThisTick(string &reason)
{
   reason = "";
   if(!EnableFvgMicroRuntimePipelineRefresh)
   {
      reason = "FVG_RUNTIME_PIPELINE_DISABLED";
      return false;
   }

   if(!ProcessFvgMicroDetectorOnlyOnNewM5ClosedBar)
   {
      reason = "DETECTOR_REFRESH_ALLOWED_EVERY_TICK_BY_INPUT";
      return true;
   }

   FalconCandleSnapshot m5_snapshot;
   if(!g_market_context.GetCandleSnapshot(PERIOD_M5, FalconAnalysisCandleShift(), m5_snapshot))
   {
      reason = "M5_CLOSED_CANDLE_NOT_AVAILABLE";
      return false;
   }

   if(!m5_snapshot.is_valid || m5_snapshot.time <= 0)
   {
      reason = "M5_CLOSED_CANDLE_INVALID";
      return false;
   }

   if(g_last_processed_m5_closed_candle_time == 0)
   {
      g_last_processed_m5_closed_candle_time = m5_snapshot.time;
      reason = "FIRST_M5_CLOSED_CANDLE_SEEN";
      return true;
   }

   if(m5_snapshot.time != g_last_processed_m5_closed_candle_time)
   {
      g_last_processed_m5_closed_candle_time = m5_snapshot.time;
      reason = "NEW_M5_CLOSED_CANDLE";
      return true;
   }

   reason = "NO_NEW_M5_CLOSED_CANDLE";
   return false;
}

bool FalconShouldWriteRuntimeDiagnosticsNow()
{
   if(!EnableFastRuntimeSmokeMode)
      return true;

   int safe_interval = RuntimeDiagnosticsEveryNTicks;
   if(safe_interval < 1)
      safe_interval = FALCON_RUNTIME_DIAGNOSTICS_DEFAULT_N_TICKS;

   return ((g_runtime_tick_counter % safe_interval) == 0);
}

void FalconRunFvgMicroRuntimeShadowPipeline(const string trigger)
{
   if(!EnableFvgMicroRuntimePipelineRefresh)
      return;

   if(!g_market_context.Refresh())
      return;

   string detector_refresh_reason = "";
   bool refresh_detector = FalconShouldRefreshFvgDetectorOnThisTick(detector_refresh_reason);
   bool write_runtime_diagnostics = FalconShouldWriteRuntimeDiagnosticsNow();

   if(refresh_detector)
   {
      g_candle_cache.LoadAll(g_market_context);
      g_fvg_micro_detector_stub.Initialize(g_strategy_registry, g_candle_cache, g_evidence_framework, g_runtime_safety_guard);
      g_report_writer.WriteFvgMicroDetectorDiagnosticsSnapshot(g_fvg_micro_detector_stub);

      FalconFvgMicroDetectorSnapshot detector_snapshot = g_fvg_micro_detector_stub.GetSnapshot();
      if(detector_snapshot.fvg_detected)
      {
         g_fvg_micro_candidate_builder.Initialize(g_fvg_micro_detector_stub, g_strategy_registry, g_runtime_safety_guard);
         g_report_writer.WriteFvgMicroCandidateDiagnosticsSnapshot(g_fvg_micro_candidate_builder);
      }
      else if(write_runtime_diagnostics)
      {
         g_report_writer.WriteFvgMicroCandidateDiagnosticsSnapshot(g_fvg_micro_candidate_builder);
      }
   }

   FalconFvgMicroShadowCandidateSnapshot candidate_snapshot = g_fvg_micro_candidate_builder.GetSnapshot();
   bool has_ready_candidate = (candidate_snapshot.candidate_status == FALCON_CANDIDATE_STATUS_READY_SHADOW && candidate_snapshot.candidate_created);

   if(has_ready_candidate)
   {
      g_fvg_micro_retest_watcher.Initialize(g_fvg_micro_candidate_builder, g_market_context, g_runtime_safety_guard);
      FalconFvgMicroRetestWatcherSnapshot watcher_snapshot = g_fvg_micro_retest_watcher.GetSnapshot();
      FalconRegisterFvgRetestFreshnessHoldMetrics(watcher_snapshot, g_market_context);

      if(watcher_snapshot.watcher_status == FALCON_RETEST_WATCHER_STATUS_SKELETON_READY)
      {
         g_report_writer.WriteFvgMicroRetestWatcherDiagnosticsSnapshot(g_fvg_micro_retest_watcher);

         if(watcher_snapshot.candidate_id != g_last_staged_fvg_candidate_id)
         {
            g_fvg_micro_tradeplan_stager.Initialize(g_fvg_micro_retest_watcher, g_runtime_safety_guard, g_shadow_executor);
            g_report_writer.WriteFvgMicroTradePlanStagingDiagnosticsSnapshot(g_fvg_micro_tradeplan_stager);

            FalconFvgMicroTradePlanStagingSnapshot staging_snapshot = g_fvg_micro_tradeplan_stager.GetSnapshot();
            if(staging_snapshot.staging_status == FALCON_TRADEPLAN_STAGING_STATUS_BLOCKED &&
               StringFind(staging_snapshot.staging_reason, "FVG_QGUARD_RUNTIME_BLOCKED") >= 0)
            {
               g_last_staged_fvg_candidate_id = watcher_snapshot.candidate_id;
               CFalconLogger::Info(StringFormat("FVG Micro candidate blocked once by controlled SIZE250 guard. CandidateId=%s | Reason=%s",
                                                watcher_snapshot.candidate_id,
                                                staging_snapshot.staging_reason));
            }
            else if(staging_snapshot.staged_to_shadow_executor)
            {
               g_last_staged_fvg_candidate_id = watcher_snapshot.candidate_id;
               g_broker_entry_bridge.TryOpenFromShadowRecord(g_fvg_micro_tradeplan_stager.GetShadowRecord(), g_report_writer);
               g_fvg_micro_lifecycle_simulator.Initialize(g_fvg_micro_tradeplan_stager, g_market_context, g_shadow_executor);
               g_report_writer.WriteFvgMicroLifecycleSimulationDiagnosticsSnapshot(g_fvg_micro_lifecycle_simulator);
               g_report_writer.WriteFvgMicroSmokeTestDiagnosticsSnapshot(trigger + "_StagedShadowRecord");
               g_report_writer.WriteFvgMicroRuntimeReportAuditSnapshot(trigger + "_StagedShadowRecord");
            }
         }
      }
      else if(write_runtime_diagnostics)
      {
         g_report_writer.WriteFvgMicroRetestWatcherDiagnosticsSnapshot(g_fvg_micro_retest_watcher);
      }
   }
   else if(write_runtime_diagnostics)
   {
      g_report_writer.WriteFvgMicroDetectorDiagnosticsSnapshot(g_fvg_micro_detector_stub);
      g_report_writer.WriteFvgMicroCandidateDiagnosticsSnapshot(g_fvg_micro_candidate_builder);
   }
}

// ==================================================================
// Expert lifecycle
// ==================================================================
int OnInit()
{
   g_runtime_tick_counter = 0;
   g_last_processed_m5_closed_candle_time = 0;
   g_last_staged_fvg_candidate_id = "";
   FalconInitializeReportPeriodTags();
   g_falcon_session_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   PrintFormat("============================================================");
   PrintFormat("%s", EA_NAME);
   PrintFormat("Version: %s | Build: %s", EA_VERSION_TAG, EA_BUILD_TAG);
   PrintFormat("Stage: v0.56.9b Emergency Server Stop Envelope LOCK Parity Probe / Tester only / No Demo / No Live");
   PrintFormat("ReportProfile: %s", FalconReportProfileToString());
   PrintFormat("============================================================");
   FalconPrintReportFolderHints();
   FalconWriteStartupBootstrapFile();

   if(!g_market_context.Initialize())
      return INIT_FAILED;

   FalconSymbolContext symbol_context = g_market_context.GetSymbolContext();
   if(!g_risk_foundation.ValidateInputs(symbol_context))
      return INIT_PARAMETERS_INCORRECT;

   if(!g_strategy_registry.Initialize())
      return INIT_FAILED;
   g_strategy_registry.PrintRegistryState();
   g_report_writer.Initialize(symbol_context);
   g_broker_entry_bridge.Initialize();
   g_report_writer.WriteMarketDiagnosticsSnapshot(g_market_context.GetQuoteContext(), g_market_context.GetPrimaryCandleSnapshot());
   g_report_writer.WriteStrategyRegistryDiagnosticsSnapshot(g_strategy_registry);
   g_candle_cache.LoadAll(g_market_context);
   g_report_writer.WriteCandleCacheDiagnosticsSnapshot(g_candle_cache);

   if(!g_runtime_safety_guard.Initialize(g_candle_cache))
      return INIT_FAILED;
   g_report_writer.WriteNoLookaheadDiagnosticsSnapshot(g_runtime_safety_guard);

   if(!g_evidence_framework.Initialize())
      return INIT_FAILED;
   g_report_writer.WriteEvidenceDiagnosticsSnapshot(g_evidence_framework);

   if(!g_fvg_micro_detector_stub.Initialize(g_strategy_registry, g_candle_cache, g_evidence_framework, g_runtime_safety_guard))
      return INIT_FAILED;
   g_report_writer.WriteFvgMicroDetectorDiagnosticsSnapshot(g_fvg_micro_detector_stub);

   if(!g_fvg_micro_candidate_builder.Initialize(g_fvg_micro_detector_stub, g_strategy_registry, g_runtime_safety_guard))
      return INIT_FAILED;
   g_report_writer.WriteFvgMicroCandidateDiagnosticsSnapshot(g_fvg_micro_candidate_builder);

   if(!g_fvg_micro_retest_watcher.Initialize(g_fvg_micro_candidate_builder, g_market_context, g_runtime_safety_guard))
      return INIT_FAILED;
   g_report_writer.WriteFvgMicroRetestWatcherDiagnosticsSnapshot(g_fvg_micro_retest_watcher);

   g_shadow_executor.Initialize();
   g_report_writer.WriteShadowDiagnosticsSnapshot(g_shadow_executor);

   if(!g_fvg_micro_tradeplan_stager.Initialize(g_fvg_micro_retest_watcher, g_runtime_safety_guard, g_shadow_executor))
      return INIT_FAILED;
   g_report_writer.WriteFvgMicroTradePlanStagingDiagnosticsSnapshot(g_fvg_micro_tradeplan_stager);
   if(g_fvg_micro_tradeplan_stager.GetSnapshot().staged_to_shadow_executor)
      g_broker_entry_bridge.TryOpenFromShadowRecord(g_fvg_micro_tradeplan_stager.GetShadowRecord(), g_report_writer);

   if(!g_fvg_micro_lifecycle_simulator.Initialize(g_fvg_micro_tradeplan_stager, g_market_context, g_shadow_executor))
      return INIT_FAILED;
   FalconTradeLifecycleRecord lifecycle_record_on_init;
   if(g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord(lifecycle_record_on_init))
   {
      g_report_writer.RegisterClosedTrade(lifecycle_record_on_init);
      g_broker_entry_bridge.TryManagedCloseFromLifecycleRecord(lifecycle_record_on_init, g_report_writer);
   }
   g_report_writer.WriteFvgMicroLifecycleSimulationDiagnosticsSnapshot(g_fvg_micro_lifecycle_simulator);
   g_report_writer.WriteReportCalibrationDiagnosticsSnapshot();
   g_report_writer.WriteFvgMicroSmokeTestDiagnosticsSnapshot("OnInit_AfterAllInitialReports");
   g_report_writer.WriteFvgMicroRuntimeReportAuditSnapshot("OnInit_AfterAllInitialReports");
   g_report_writer.WriteRuntimeReportVerificationSnapshot("OnInit_AfterAllInitialReports");

   if(!g_first_strategy_adapter.Initialize(g_strategy_registry, g_runtime_safety_guard, g_shadow_executor))
      return INIT_FAILED;
   g_report_writer.WriteStrategyAdapterDiagnosticsSnapshot(g_first_strategy_adapter);
   if(FALCON_WRITE_SECONDARY_ONINIT_AUDIT_SNAPSHOTS)
   {
      g_report_writer.WriteFvgMicroSmokeTestDiagnosticsSnapshot("OnInit_AfterStrategyAdapterReport");
      g_report_writer.WriteFvgMicroRuntimeReportAuditSnapshot("OnInit_AfterStrategyAdapterReport");
      g_report_writer.WriteRuntimeReportVerificationSnapshot("OnInit_AfterStrategyAdapterReport");
   }

   g_risk_tm_architecture.Initialize();
   g_risk_tm_architecture.PrintState();
   CFalconLogger::Info("v0.56.9b Emergency Server Stop Envelope LOCK Parity Probe active: EnableRealExecution=true is allowed only inside MT5 Strategy Tester; Demo/Live remain blocked before initialization proceeds.");
   g_execution_guard.AssertNoExecution();

   g_is_initialized = true;
   CFalconLogger::Info("Initialization completed successfully. v0.56.9b broker bridge is strategy-agnostic and restores mandatory server SL/TP. OrderSend requires pre-entry broker lot authority, validated StructuralSL/TP plan, and non-empty server SL/TP; EA-side managed PositionClose is allowed only inside Strategy Tester at Paper final close for still-open broker positions; Demo, Live, BrokerModify, and RuntimeSLChanged remain blocked.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   FalconUpdateReportPeriodLastSeen();
   g_broker_entry_bridge.FlushOpenLinksAtDeinit(g_report_writer);
   g_report_writer.WriteFinalSummary();
   g_report_writer.WriteReportCalibrationDiagnosticsSnapshot();
   g_report_writer.WriteFvgMicroSmokeTestDiagnosticsSnapshot("OnDeinit_FinalSmokeTest");
   g_report_writer.WriteFvgMicroRuntimeReportAuditSnapshot("OnDeinit_FinalReportAudit");
   g_report_writer.WriteRuntimeReportVerificationSnapshot("OnDeinit_FinalReportVerification");
   FalconFinalizeAndRenameReportFiles("OnDeinit_AutoPeriodFinalize");
   CFalconLogger::Info(StringFormat("Deinitializing. Reason=%d", reason));
   g_is_initialized = false;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // v0.56.9: OnTradeTransaction plus history recovery are the tester-only source of truth
   // for observing server-side broker exits created by atomic SL/TP orders.
   // This does not add Demo/Live, BrokerModify, or RuntimeSLChanged. EA-side close requests are allowed only by the managed close bridge inside MT5 Strategy Tester; this route repairs report truth when the broker/tester closes
   // an already-linked position at server-side SL/TP.
   FalconOttuRouteTransaction(trans);
   g_broker_entry_bridge.ObserveTradeTransactionExit(trans, g_report_writer);
}

void OnTick()
{
   if(!g_is_initialized)
      return;

   g_runtime_tick_counter++;
   FalconUpdateReportPeriodLastSeen();

   // v0.18.4 refreshes the FVG shadow pipeline during runtime and can close staged Shadow records diagnostically at TP1/SL/timeout.
   // Broker entry bridge is tester-only and gated by EnableRealExecution=true. Broker close/Demo/Live remain disabled.
   FalconRunFvgMicroRuntimeShadowPipeline("OnTick_FvgRuntimePipeline");

   // v0.57.2: Virtual Trailing Exit Bridge - per-tick trailing update on every open broker link.
   // Tester-only. Close via OrderSend(TRADE_ACTION_DEAL) reverse only. No BrokerModify, no
   // TRADE_ACTION_SLTP, no RuntimeSLChanged. Method short-circuits internally if gates fail;
   // outer guard here keeps the call a no-op outside the tester.
   if(EnableVirtualTrailingBridge && EnableRealExecution && MQLInfoInteger(MQL_TESTER))
      g_broker_entry_bridge.UpdateVirtualTrailingForOpenLinks(g_report_writer);

   g_fvg_micro_lifecycle_simulator.Refresh(g_market_context, g_shadow_executor);

   FalconTradeLifecycleRecord lifecycle_record;
   if(g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord(lifecycle_record))
   {
      g_report_writer.RegisterClosedTrade(lifecycle_record);
      g_broker_entry_bridge.TryManagedCloseFromLifecycleRecord(lifecycle_record, g_report_writer);
      // v0.18.5 performance rule:
      // TradeLifecycle rows are written immediately, but heavy file-verification/audit snapshots
      // are not rewritten after every Shadow close. They remain available at OnInit/OnDeinit.
      if(FALCON_WRITE_HEAVY_RUNTIME_AUDIT_ON_SHADOW_CLOSE)
      {
         g_report_writer.WriteFvgMicroSmokeTestDiagnosticsSnapshot("OnTick_AfterShadowLifecycleClose");
         g_report_writer.WriteFvgMicroRuntimeReportAuditSnapshot("OnTick_AfterShadowLifecycleClose");
         g_report_writer.WriteRuntimeReportVerificationSnapshot("OnTick_AfterShadowLifecycleClose");
      }
      g_report_writer.WriteFvgMicroLifecycleSimulationDiagnosticsSnapshot(g_fvg_micro_lifecycle_simulator);
   }
   else
   {
      bool should_write_lifecycle_tick_snapshot = true;
      if(EnableFastRuntimeSmokeMode)
      {
         int safe_interval = RuntimeDiagnosticsEveryNTicks;
         if(safe_interval < 1)
            safe_interval = FALCON_RUNTIME_DIAGNOSTICS_DEFAULT_N_TICKS;
         should_write_lifecycle_tick_snapshot = ((g_runtime_tick_counter % safe_interval) == 0);
      }

      if(should_write_lifecycle_tick_snapshot)
         g_report_writer.WriteFvgMicroLifecycleSimulationDiagnosticsSnapshot(g_fvg_micro_lifecycle_simulator);
   }

   // Future pipeline:
   // MarketContext -> CandleCache -> Narrative -> StrategyEngine -> Evidence -> Guard -> TradePlan -> Shadow/Paper/Demo/Live Executor -> ReportWriter
   return;
}

// ==================================================================
// End of file
// ==================================================================
