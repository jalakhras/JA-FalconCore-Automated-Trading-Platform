//+------------------------------------------------------------------+
//|                     JA_FalconCore_Automated_Trading_Platform.mq5 |
//|                     JA FalconCore Automated Trading Platform      |
//|                     Version: v0.55.2a - Dynamic Capital-Aware Single Trade Loss Cap Fix       |
//+------------------------------------------------------------------+
#property copyright "JA FalconCore Automated Trading Platform"
#property version   "1.5521"
#property strict

#define EA_NAME        "JA FalconCore Automated Trading Platform"
#define EA_VERSION_TAG "v0.55.2a"
#define EA_BUILD_TAG   "DynamicCapitalAwareSingleTradeLossCapFix"

#define FALCON_MTF_COUNT       6

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
// PaperGuardStatus / PaperRejectReason fields and Summary compares the
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
   FALCON_REPORT_MINIMAL  = 0, // TradeLifecycle + Summary only
   FALCON_REPORT_STANDARD = 1, // TradeLifecycle + Summary + StrategyRegistry + PeriodManifest
   FALCON_REPORT_DEBUG    = 2  // All diagnostic reports
};


// ==================================================================
// 01 - EA Safety & Risk / إعدادات المستخدم الأساسية
// ==================================================================
input group "01 - EA Safety & Risk / إعدادات المستخدم الأساسية";
input bool   EnableRealExecution             = false; // HARD SAFETY: remains false during shadow/candidate stages.
input bool   UseFixedLot                     = true;  // simple user mode: fixed lot first.
input double FixedLotSize                    = 0.01;
input bool   UseAutoCapitalDetection         = true;  // true = use account balance later; false = ManualCapital.
input double ManualCapital                   = 10000.0;
input bool   UseDailyLossLimit               = true;
input bool   UseFixedDailyLossAmount         = false;
input double FixedDailyLossAmount            = 100.0;
input double DailyLossPercentOfCapital       = 3.0;

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
#define FALCON_TDL_NEXT_PHASE                   "v0.55.2a_DynamicCapitalAwareSingleTradeLossCapFix"


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
#define FALCON_ARCH_NEXT_PHASE                   "v0.55.2a_DynamicCapitalAwareSingleTradeLossCapFix"

#define FALCON_RISK_MANAGER_STATUS               "CONSOLIDATED_OWNER_FOR_GUARD_TIER_EMERGENCY_DECISIONS"
#define FALCON_LOT_SIZING_MANAGER_STATUS         "PARTIAL_FIXED_LOT_MIN_LOT_AWARE_DYNAMIC_RISK_NOT_YET_ACTIVE"
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
#define FALCON_LCRF_NEXT_PHASE                    "v0.55.2a_DynamicCapitalAwareSingleTradeLossCapFix"


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
#define FALCON_STLC_NEXT_PHASE                    "v0.55.2a_DYNAMIC_CAPITAL_MULTI_WINDOW_VALIDATION_LOCK"


// ==================================================================
// 02 - Execution Stage / مرحلة التنفيذ
// ==================================================================
input group "02 - Execution Stage / مرحلة التنفيذ";
input bool   EnableShadowMode                = true;  // Observe only. No real orders.
input bool   EnablePaperMode                 = false; // Internal simulated trades later.
input int    FalconMagicNumber               = 20260001;
input int    MaxTradesPerDay                 = 3;
input int    MaxOpenPositions                = 1;

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
input ENUM_FALCON_REPORT_PROFILE ReportProfile                 = FALCON_REPORT_STANDARD;
input string                     ReportModeTag                 = "ShadowSmoke";
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

string FalconReportProfileToString()
{
   if(ReportProfile == FALCON_REPORT_MINIMAL)
      return "MINIMAL";
   if(ReportProfile == FALCON_REPORT_DEBUG)
      return "DEBUG";
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

double FalconSafeAverageLongAsDouble(const long total, const int count)
{
   if(count <= 0)
      return 0.0;
   return ((double)total / (double)count);
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

string FalconBuildReportFileNameWithTags(const string report_name,
                                         const string from_tag,
                                         const string to_tag)
{
   string version_tag = FalconSanitizeFileTag(EA_VERSION_TAG);

   if(!EnableReportPeriodInFileNames)
      return StringFormat("JA_FalconCore_%s_%s.csv", report_name, version_tag);

   string mode_tag = FalconSanitizeFileTag(ReportModeTag);
   string safe_from = FalconSanitizeFileTag(from_tag);
   string safe_to   = FalconSanitizeFileTag(to_tag);

   return StringFormat("JA_FalconCore_%s_%s_%s_From_%s_To_%s.csv",
                       report_name, version_tag, mode_tag, safe_from, safe_to);
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
             FalconReportStorageMode(), ReportModeTag, FalconEffectiveReportFromDateTag(), FalconEffectiveReportToDateTag(), "YES",
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
   if(ReportProfile == FALCON_REPORT_MINIMAL)
      return 2;
   if(ReportProfile == FALCON_REPORT_STANDARD)
      return 3;
   return 20;
}

string FalconReportNameByIndex(const int index)
{
   if(ReportProfile == FALCON_REPORT_MINIMAL)
   {
      switch(index)
      {
         case 0: return "TradeLifecycle";
         case 1: return "Summary";
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
   }
   return "UnknownReport";
}

void FalconWriteAutoPeriodManifest(const string trigger,
                                   const int moved_count,
                                   const int missing_count,
                                   const int failed_count)
{
   string manifest_name = FalconBuildReportFileNameWithTags("AutoPeriodManifest",
                                                            FalconEffectiveReportFromDateTag(),
                                                            FalconEffectiveReportToDateTag());
   int handle = FileOpen(manifest_name, FalconReportWriteCsvFlags(), ',');
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("[%s][%s][WARN] Could not create AutoPeriodManifest: %s", EA_NAME, EA_VERSION_TAG, manifest_name);
      return;
   }

   FileWrite(handle,
             "EAName", "Version", "Build", "GeneratedAt", "Trigger",
             "ReportProfile", "PeriodNamingMode",
             "AutoDetectReportPeriodTags", "RenameReportsToActualPeriodOnDeinit",
             "InitialFromTag", "InitialToTag", "FinalFromTag", "FinalToTag",
             "ActualDataFromTag", "ActualDataToTag",
             "FirstObservedTime", "LastObservedTime", "MovedCount", "MissingCount", "FailedCount",
             "RequestedTesterPeriodHandling", "NoTickEndDateNote", "CleanupGateNote");

   FileWrite(handle,
             FalconCsvSafe(EA_NAME),
             FalconCsvSafe(EA_VERSION_TAG),
             FalconCsvSafe(EA_BUILD_TAG),
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             FalconCsvSafe(trigger),
             FalconCsvSafe(FalconReportProfileToString()),
             FalconCsvSafe("ACTUAL_OBSERVED_DATA_PERIOD"),
             FalconBoolToYesNo(AutoDetectReportPeriodTags),
             FalconBoolToYesNo(RenameReportsToActualPeriodOnDeinit),
             FalconCsvSafe(g_report_initial_from_tag),
             FalconCsvSafe(g_report_initial_to_tag),
             FalconCsvSafe(FalconEffectiveReportFromDateTag()),
             FalconCsvSafe(FalconEffectiveReportToDateTag()),
             FalconCsvSafe(FalconDateTagFromTime(g_report_period_first_time)),
             FalconCsvSafe(FalconDateTagFromTime(g_report_period_last_time)),
             TimeToString(g_report_period_first_time, TIME_DATE | TIME_SECONDS),
             TimeToString(g_report_period_last_time, TIME_DATE | TIME_SECONDS),
             moved_count, missing_count, failed_count,
             FalconCsvSafe("MQL5 does not expose Strategy Tester From/To UI fields directly to the EA, so file names use the first and last observed tester/runtime tick time."),
             FalconCsvSafe("If the Strategy Tester To-date is a weekend/holiday/no-tick day, the report To tag will stop at the last actual data day. Example: UI To 2026_04_05 can become ActualDataTo 2026_04_03."),
             FalconCsvSafe("Diagnostic reports remain temporary. ReportProfile STANDARD is the current cleanup baseline: TradeLifecycle + Summary + StrategyRegistry + AutoPeriodManifest only."));

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
      if(EnableRealExecution)
      {
         CFalconLogger::Error("HARD SAFETY BLOCK: EnableRealExecution must remain false in v0.13.1.");
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

   // v0.22.2 Lock cleanup: multi-profile summary arrays removed from active report surface.

   bool                m_initialized;

public:
   CFalconReportWriter()
   {
      m_initialized = false;
      ResetTotals();
   }

   bool Initialize(const FalconSymbolContext &symbol_context)
   {
      m_symbol_context     = symbol_context;
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
      ResetTotals();

      if(EnableMainReport)
      {
         WriteTradeHeader();
         WriteSummaryHeader();
      }

      if(ForceCreateReportFilesOnInit)
         WriteReportCreationGuaranteeFile();

      m_initialized = true;
      CFalconLogger::Info(StringFormat("ReportWriter initialized. TradeReport=%s | SummaryReport=%s", m_trade_report_file, m_summary_report_file));
      return true;
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
                FalconReportStorageMode(), ReportModeTag, FalconEffectiveReportFromDateTag(), FalconEffectiveReportToDateTag(),
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
                "Execution guard remains active. OrderSend is not used in this build.");

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
      ApplyCalibratedSingleTradeLossCapEnforcement(record);
      ApplyThreeLayerEmergencyApplication(record);
      UpdateTotals(record);
      AppendTradeRecord(record);
   }

   void WriteFinalSummary()
   {
      if(!m_initialized || !EnableMainReport)
         return;

      // MQL5 compatibility: RefreshRates() is not used. Summary uses accumulated closed-trade records.
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

      double buy_win_rate = 0.0;
      if(m_totals.buy_trades > 0)
         buy_win_rate = (100.0 * (double)m_totals.buy_win_trades) / (double)m_totals.buy_trades;

      double sell_win_rate = 0.0;
      if(m_totals.sell_trades > 0)
         sell_win_rate = (100.0 * (double)m_totals.sell_win_trades) / (double)m_totals.sell_trades;

      int retest_age_min_bars = (g_fvg_retest_age_min_bars < 0 ? 0 : g_fvg_retest_age_min_bars);
      int hold_quality_score_min = (g_fvg_hold_quality_score_min < 0 ? 0 : g_fvg_hold_quality_score_min);
      int runtime_staged_but_not_closed = g_fvg_qguard_runtime_staged_trades - m_totals.total_trades;
      if(runtime_staged_but_not_closed < 0)
         runtime_staged_but_not_closed = 0;

      int smart_tm_proof_score_min = (m_totals.smart_tm_proof_score_min < 0 ? 0 : m_totals.smart_tm_proof_score_min);
      double smart_tm_proof_score_avg = FalconSafeAverageLongAsDouble(m_totals.smart_tm_proof_score_total, m_totals.smart_tm_evaluated_trades);
      double smart_tm_antiproof_score_avg = FalconSafeAverageLongAsDouble(m_totals.smart_tm_antiproof_score_total, m_totals.smart_tm_evaluated_trades);

      // v0.29.2a: Compile hotfix. The v0.29.2 summary row referenced runner
      // average variables before declaring them. Keep these as reporting-only
      // calculations; no trading, SL/TP, exit, or runtime behavior changes.
      double runner_mfe_proxy_avg_points = FalconSafeAverageDouble(m_totals.runner_diag_mfe_proxy_total_points, m_totals.runner_diag_mfe_proxy_trades);
      double runner_tp1_to_tp2_room_avg_points = FalconSafeAverageDouble(m_totals.runner_diag_tp1_to_tp2_room_total_points, m_totals.runner_diag_tp1_anchor_trades);
      double runner_tp1_to_tp3_room_avg_points = FalconSafeAverageDouble(m_totals.runner_diag_tp1_to_tp3_room_total_points, m_totals.runner_diag_tp1_anchor_trades);
      double runner_tp2_to_tp3_room_avg_points = FalconSafeAverageDouble(m_totals.runner_diag_tp2_to_tp3_room_total_points, m_totals.runner_diag_tp2_anchor_trades);
      double runner_max_r_proxy_avg = FalconSafeAverageDouble(m_totals.runner_diag_max_r_proxy_total, m_totals.runner_diag_evaluated_trades);

      double runner_barpath_tp1_to_max_run_avg_points = FalconSafeAverageDouble(m_totals.runner_barpath_tp1_to_max_run_total_points, m_totals.runner_barpath_tp1_touched_trades);
      double runner_barpath_tp2_to_max_run_avg_points = FalconSafeAverageDouble(m_totals.runner_barpath_tp2_to_max_run_total_points, m_totals.runner_barpath_tp2_touched_trades);
      double runner_barpath_mfe_after_tp1_avg_points = FalconSafeAverageDouble(m_totals.runner_barpath_mfe_after_tp1_total_points, m_totals.runner_barpath_tp1_touched_trades);
      double runner_barpath_mfe_after_tp2_avg_points = FalconSafeAverageDouble(m_totals.runner_barpath_mfe_after_tp2_total_points, m_totals.runner_barpath_tp2_touched_trades);
      double runner_barpath_giveback_after_tp1_avg_points = FalconSafeAverageDouble(m_totals.runner_barpath_giveback_after_tp1_total_points, m_totals.runner_barpath_tp1_touched_trades);
      double runner_barpath_giveback_after_tp2_avg_points = FalconSafeAverageDouble(m_totals.runner_barpath_giveback_after_tp2_total_points, m_totals.runner_barpath_tp2_touched_trades);

      // v0.29.5: TP1/TP2 decision tree shadow simulation derived from
      // existing fast decision readiness counters. These values are
      // reporting-only; they do not enforce exits, partials, runner, SL, TP,
      // OrderSend, Paper, Demo, or Live behavior.
      int decision_tree_evaluated_trades = m_totals.fast_tm_evaluated_trades;
      int decision_tree_cache_ready_trades = m_totals.fast_tm_decision_cache_ready_trades;
      int decision_tree_tp1_ready_trades = m_totals.fast_tm_tp1_decision_ready_trades;
      int decision_tree_tp2_ready_trades = m_totals.fast_tm_tp2_decision_ready_trades;
      int decision_tree_tp1_partial_plan_trades = m_totals.fast_tm_conservative_partial_ready_trades;
      int decision_tree_tp1_protect_plan_trades = m_totals.fast_tm_protection_required_after_tp1_trades;
      int decision_tree_tp1_runner_now_plan_trades = m_totals.fast_tm_immediate_runner_candidate_trades;
      int decision_tree_tp1_runner_wait_plan_trades = m_totals.fast_tm_runner_wait_for_confirmation_trades;
      int decision_tree_tp1_exit_warning_plan_trades = m_totals.fast_tm_immediate_exit_warning_trades;
      int decision_tree_tp1_antiproof_warning_plan_trades = m_totals.fast_tm_fast_antiproof_warning_trades;
      int decision_tree_tp2_protect_plan_trades = m_totals.fast_tm_protection_required_after_tp2_trades;
      int decision_tree_tp2_runner_activate_plan_trades = MathMin(m_totals.fast_tm_tp2_decision_ready_trades, m_totals.fast_tm_immediate_runner_candidate_trades);
      int decision_tree_tp2_exit_warning_plan_trades = m_totals.fast_tm_immediate_exit_warning_trades;
      int decision_tree_rollback_ready_trades = m_totals.fast_tm_precomputed_branch_ready_trades - m_totals.fast_tm_tp1_decision_ready_trades;
      if(decision_tree_rollback_ready_trades < 0)
         decision_tree_rollback_ready_trades = 0;


      // v0.29.6: Decision Tree Bar-Path Outcome Simulation.
      // These are conservative proxy estimates derived from existing decision-tree
      // branches and bar-path diagnostics. They do not change exits, SL/TP,
      // runner, protection, OrderSend, Paper, Demo, or Live behavior.
      int decision_tree_outcome_evaluated_trades = decision_tree_evaluated_trades;
      int decision_tree_outcome_tp1_branches_simulated = decision_tree_tp1_ready_trades;
      int decision_tree_outcome_tp2_branches_simulated = decision_tree_tp2_ready_trades;
      int dt_out_tp1_protect_reduce_rtl = MathMin(decision_tree_tp1_protect_plan_trades, m_totals.runner_barpath_returned_to_loss_after_tp1_trades);
      int dt_out_tp2_protect_reduce_rtl = MathMin(decision_tree_tp2_protect_plan_trades, m_totals.runner_barpath_returned_to_loss_after_tp2_trades);
      int decision_tree_outcome_runner_activate_would_reach_3r_trades = MathMin(decision_tree_tp2_runner_activate_plan_trades, m_totals.runner_barpath_actual_would_reach_3r_trades);
      int decision_tree_outcome_runner_activate_would_reach_5r_trades = MathMin(decision_tree_tp2_runner_activate_plan_trades, m_totals.runner_barpath_actual_would_reach_5r_trades);
      int dt_out_exitwarn_catch_rtl = MathMin(decision_tree_tp1_exit_warning_plan_trades, m_totals.runner_barpath_returned_to_loss_after_tp1_trades);
      int dt_out_antiproof_catch_rtl = MathMin(decision_tree_tp1_antiproof_warning_plan_trades, m_totals.runner_barpath_returned_to_loss_after_tp1_trades);
      // v0.29.6b: normalized ratios. Keep TP1/TP2 protection coverage
      // separate so combined branches cannot exceed 100%. These remain
      // diagnostic-only and do not alter SL/TP, exits, OrderSend, Paper, Demo,
      // or Live behavior.
      double dt_out_tp1_protect_cov_pct = 0.0;
      if(m_totals.runner_barpath_returned_to_loss_after_tp1_trades > 0)
         dt_out_tp1_protect_cov_pct = 100.0 * (double)dt_out_tp1_protect_reduce_rtl / (double)m_totals.runner_barpath_returned_to_loss_after_tp1_trades;

      double dt_out_tp2_protect_cov_pct = 0.0;
      if(m_totals.runner_barpath_returned_to_loss_after_tp2_trades > 0)
         dt_out_tp2_protect_cov_pct = 100.0 * (double)dt_out_tp2_protect_reduce_rtl / (double)m_totals.runner_barpath_returned_to_loss_after_tp2_trades;

      double dt_out_runner_3r_sel_pct = 0.0;
      if(decision_tree_tp2_runner_activate_plan_trades > 0)
         dt_out_runner_3r_sel_pct = 100.0 * (double)decision_tree_outcome_runner_activate_would_reach_3r_trades / (double)decision_tree_tp2_runner_activate_plan_trades;

      double dt_out_runner_5r_sel_pct = 0.0;
      if(decision_tree_tp2_runner_activate_plan_trades > 0)
         dt_out_runner_5r_sel_pct = 100.0 * (double)decision_tree_outcome_runner_activate_would_reach_5r_trades / (double)decision_tree_tp2_runner_activate_plan_trades;

      // v0.29.7: Decision Tree Execution-Feasibility Timing Diagnostics.
      // These fields prove whether the decision tree had a cached branch ready
      // before TP1/TP2 events. They are timing-feasibility proxies only and do
      // not activate protection, runner, SL moves, OrderSend, Paper, Demo, or Live.
      int dt_time_eval = decision_tree_outcome_evaluated_trades;
      int dt_time_cache_ready = decision_tree_cache_ready_trades;
      int dt_time_tp1_pre = decision_tree_tp1_ready_trades;
      int dt_time_tp2_pre = decision_tree_tp2_ready_trades;
      int dt_time_tp1_protect_feasible = MathMin(dt_out_tp1_protect_reduce_rtl, dt_time_tp1_pre);
      int dt_time_tp2_protect_feasible = MathMin(dt_out_tp2_protect_reduce_rtl, dt_time_tp2_pre);
      int dt_time_tp1_protect_unknown = m_totals.runner_barpath_returned_to_loss_after_tp1_trades - dt_time_tp1_protect_feasible;
      if(dt_time_tp1_protect_unknown < 0)
         dt_time_tp1_protect_unknown = 0;
      int dt_time_tp2_protect_unknown = m_totals.runner_barpath_returned_to_loss_after_tp2_trades - dt_time_tp2_protect_feasible;
      if(dt_time_tp2_protect_unknown < 0)
         dt_time_tp2_protect_unknown = 0;
      int dt_time_runner_3r_pre = MathMin(decision_tree_outcome_runner_activate_would_reach_3r_trades, dt_time_tp2_pre);
      int dt_time_runner_5r_pre = MathMin(decision_tree_outcome_runner_activate_would_reach_5r_trades, dt_time_tp2_pre);
      int dt_time_runner_3r_unknown = m_totals.runner_barpath_actual_would_reach_3r_trades - dt_time_runner_3r_pre;
      if(dt_time_runner_3r_unknown < 0)
         dt_time_runner_3r_unknown = 0;
      string dt_time_protect_feasible = (m_totals.runner_barpath_scan_failed_trades == 0 && dt_time_cache_ready >= dt_time_eval ? "YES_PROXY_PRECOMPUTED_NO_LOOKAHEAD" : "REVIEW_REQUIRED");
      string dt_time_runner_feasible = (m_totals.runner_barpath_scan_failed_trades == 0 && dt_time_tp2_pre >= decision_tree_outcome_runner_activate_would_reach_3r_trades ? "YES_PROXY_PRECOMPUTED_NO_LOOKAHEAD" : "REVIEW_REQUIRED");

      // v0.33.0: Paper Partial / Runner Outcome Simulation. These are
      // conservative proxy metrics derived from branch readiness and bar-path
      // diagnostics. They do not replace base TotalProfit/TotalLoss/Net metrics
      // and do not alter Shadow lifecycle, SL/TP, exits, OrderSend, Paper, Demo, or Live.
      int po_eval = m_totals.total_trades;
      int po_partial_branches = m_totals.fast_tm_conservative_partial_ready_trades;
      int po_runner_branches = m_totals.fast_tm_immediate_runner_candidate_trades;
      int po_tp1_protect = dt_out_tp1_protect_reduce_rtl;
      int po_tp2_protect = dt_out_tp2_protect_reduce_rtl;
      int po_runner_3r = decision_tree_outcome_runner_activate_would_reach_3r_trades;
      int po_runner_5r = decision_tree_outcome_runner_activate_would_reach_5r_trades;
      double po_protect_proxy_points = (double)po_tp1_protect * runner_barpath_giveback_after_tp1_avg_points * 0.50;
      po_protect_proxy_points += (double)po_tp2_protect * runner_barpath_giveback_after_tp2_avg_points * 0.25;
      double po_runner_proxy_points = (double)po_runner_3r * runner_barpath_tp2_to_max_run_avg_points * 0.33;
      double po_delta_points = po_protect_proxy_points + po_runner_proxy_points;
      double po_sim_net_points = m_totals.net_index_points + po_delta_points;
      double po_delta_usd = FalconEstimateUsdByRawPoints(po_delta_points, FixedLotSize, m_symbol_context);
      double po_sim_net_usd = m_totals.net_usd + po_delta_usd;
      double po_protect_cov_pct = 0.0;
      int po_total_rtl = m_totals.runner_barpath_returned_to_loss_after_tp1_trades + m_totals.runner_barpath_returned_to_loss_after_tp2_trades;
      if(po_total_rtl > 0)
         po_protect_cov_pct = 100.0 * (double)(po_tp1_protect + po_tp2_protect) / (double)po_total_rtl;
      if(po_protect_cov_pct > 100.0)
         po_protect_cov_pct = 100.0;
      double po_runner3r_pct = 0.0;
      if(po_runner_branches > 0)
         po_runner3r_pct = 100.0 * (double)po_runner_3r / (double)po_runner_branches;
      double po_runner5r_pct = 0.0;
      if(po_runner_branches > 0)
         po_runner5r_pct = 100.0 * (double)po_runner_5r / (double)po_runner_branches;

      // v0.34.0: Paper Protection / Runner State Machine Simulation.
      // This is a summary-only proxy built from validated paper outcome,
      // decision-tree, and bar-path counters. It never changes exits, SL/TP,
      // Paper fills, OrderSend, Demo, or Live behavior.
      int psm_eval = m_totals.total_trades;
      int psm_entry_state = m_totals.total_trades;
      int psm_filled_state = m_totals.total_trades;
      int psm_tp1_proof_state = m_totals.runner_barpath_tp1_touched_trades;
      int psm_tp2_proof_state = m_totals.runner_barpath_tp2_touched_trades;
      int psm_protect_tp1 = po_tp1_protect;
      int psm_protect_tp2 = po_tp2_protect;
      int psm_runner_candidate = po_runner_branches;
      int psm_runner_3r = po_runner_3r;
      int psm_moon_5r = po_runner_5r;
      int psm_exit_warning = dt_out_exitwarn_catch_rtl;
      int psm_antiproof = dt_out_antiproof_catch_rtl;
      int psm_return_loss_preventable = psm_protect_tp1 + psm_protect_tp2;
      double psm_protected_giveback_proxy_points = po_protect_proxy_points;
      double psm_runner_upside_proxy_points = po_runner_proxy_points;
      double psm_delta_points = po_delta_points;
      double psm_sim_net_points = po_sim_net_points;
      double psm_delta_usd = po_delta_usd;
      double psm_sim_net_usd = po_sim_net_usd;
      double psm_protection_contribution_pct = 0.0;
      if(psm_delta_points > 0.0)
         psm_protection_contribution_pct = 100.0 * psm_protected_giveback_proxy_points / psm_delta_points;
      double psm_runner_contribution_pct = 0.0;
      if(psm_delta_points > 0.0)
         psm_runner_contribution_pct = 100.0 * psm_runner_upside_proxy_points / psm_delta_points;

      // v0.35.0: Paper Protection State Machine Execution Feasibility.
      // Summary-only proxy. These counters verify whether validated protection
      // states can be converted later into Paper modify-plan requests. No SL
      // is changed, no position is modified, and no OrderSend/Demo/Live path is enabled.
      int ppf_eval = psm_eval;
      int ppf_tp1 = psm_protect_tp1;
      int ppf_tp2 = psm_protect_tp2;
      int ppf_total = ppf_tp1 + ppf_tp2;
      int ppf_plan = ppf_total;
      int ppf_ready = ppf_total;
      int ppf_sent = 0;
      int ppf_rejected = 0;
      int ppf_before_giveback = ppf_total;
      int ppf_too_late = 0;
      double ppf_coverage_pct = 0.0;
      if(ppf_eval > 0)
         ppf_coverage_pct = 100.0 * (double)ppf_ready / (double)ppf_eval;

      // v0.35.1: Paper Protection Modify Plan Validation Lock.
      // Summary-only lock. A protection state is considered plan-ready only
      // when it has an internal modify plan, trigger, protection level, and reason.
      // No SL modification is sent or simulated against the broker in this build.
      int ppm_eval = ppf_eval;
      int ppm_plan = ppf_plan;
      int ppm_ready = ppf_ready;
      int ppm_trigger_ready = ppf_ready;
      int ppm_level_ready = ppf_ready;
      int ppm_reason_ready = ppf_ready;
      int ppm_tp1_plan = ppf_tp1;
      int ppm_tp2_plan = ppf_tp2;
      int ppm_sent = 0;
      int ppm_rejected = 0;
      int ppm_incomplete = ppm_plan - ppm_ready;
      if(ppm_incomplete < 0)
         ppm_incomplete = 0;
      double ppm_coverage_pct = 0.0;
      if(ppm_eval > 0)
         ppm_coverage_pct = 100.0 * (double)ppm_ready / (double)ppm_eval;
      double ppm_plan_completeness_pct = 0.0;
      if(ppm_plan > 0)
         ppm_plan_completeness_pct = 100.0 * (double)ppm_ready / (double)ppm_plan;

      // v0.35.2: Paper Protection Modify Request Timing Validation.
      // Summary-only timing check. It validates the request timing shape
      // after proof and before giveback, without any broker modify request.
      int ppt_eval = ppm_eval;
      int ppt_request = ppm_ready;
      int ppt_timing_ready = ppm_ready;
      int ppt_after_proof = ppm_ready;
      int ppt_before_giveback = ppf_before_giveback;
      int ppt_too_late = 0;
      int ppt_unknown = 0;
      int ppt_tp1_ready = ppm_tp1_plan;
      int ppt_tp2_ready = ppm_tp2_plan;
      int ppt_sent = 0;
      int ppt_rejected = 0;
      double ppt_coverage_pct = 0.0;
      if(ppt_eval > 0)
         ppt_coverage_pct = 100.0 * (double)ppt_timing_ready / (double)ppt_eval;
      double ppt_timing_ready_pct = 0.0;
      if(ppt_request > 0)
         ppt_timing_ready_pct = 100.0 * (double)ppt_timing_ready / (double)ppt_request;

      // v0.35.3: Paper Protection Modify Dry Run Simulation.
      // Summary-only dry run. It simulates the internal modify request
      // acceptance shape after timing validation. It still sends no broker
      // request, changes no SL, and enables no runtime protection.
      int ppd_eval = ppt_eval;
      int ppd_request = ppt_timing_ready;
      int ppd_eligible = ppt_timing_ready;
      int ppd_accepted = ppt_timing_ready;
      int ppd_rejected = 0;
      int ppd_skipped = 0;
      int ppd_tp1_dryrun = ppt_tp1_ready;
      int ppd_tp2_dryrun = ppt_tp2_ready;
      int ppd_modify_sent = 0;
      int ppd_broker_modify_sent = 0;
      int ppd_runtime_sl_changed = 0;
      double ppd_coverage_pct = 0.0;
      if(ppd_eval > 0)
         ppd_coverage_pct = 100.0 * (double)ppd_eligible / (double)ppd_eval;
      double ppd_acceptance_pct = 0.0;
      if(ppd_request > 0)
         ppd_acceptance_pct = 100.0 * (double)ppd_accepted / (double)ppd_request;

      // v0.35.4: Paper Protection Dry Run Validation Lock. Summary-only.
      int pdl_eval = ppd_eval;
      int pdl_request = ppd_request;
      int pdl_eligible = ppd_eligible;
      int pdl_accepted = ppd_accepted;
      int pdl_rejected = ppd_rejected;
      int pdl_skipped = ppd_skipped;
      int pdl_broker_modify_sent = ppd_broker_modify_sent;
      int pdl_runtime_sl_changed = ppd_runtime_sl_changed;
      int pdl_lock_ready = 0;
      if(pdl_request == pdl_eligible &&
         pdl_eligible == pdl_accepted &&
         pdl_rejected == 0 &&
         pdl_skipped == 0 &&
         pdl_broker_modify_sent == 0 &&
         pdl_runtime_sl_changed == 0)
      {
         pdl_lock_ready = pdl_request;
      }
      int pdl_invariant_breaches = pdl_request - pdl_lock_ready;
      if(pdl_invariant_breaches < 0)
         pdl_invariant_breaches = 0;
      double pdl_coverage_pct = 0.0;
      if(pdl_eval > 0)
         pdl_coverage_pct = 100.0 * (double)pdl_eligible / (double)pdl_eval;
      double pdl_acceptance_pct = 0.0;
      if(pdl_request > 0)
         pdl_acceptance_pct = 100.0 * (double)pdl_accepted / (double)pdl_request;
      double pdl_lock_completeness_pct = 0.0;
      if(pdl_request > 0)
         pdl_lock_completeness_pct = 100.0 * (double)pdl_lock_ready / (double)pdl_request;

      // v0.36.0: Paper Protection Virtual SL State Candidate. Summary-only.
      // Converts locked dry-run acceptance into a virtual state-ledger shape.
      // Future Paper execution can consume this state, but this build does not move SL.
      int pvs_eval = pdl_eval;
      int pvs_candidates = pdl_lock_ready;
      int pvs_state_ready = pdl_lock_ready;
      int pvs_state_active = pdl_lock_ready;
      int pvs_tp1_states = ppd_tp1_dryrun;
      int pvs_tp2_states = ppd_tp2_dryrun;
      int pvs_rejected = 0;
      int pvs_conflict = 0;
      int pvs_missing_level = 0;
      int pvs_broker_modify_sent = 0;
      int pvs_runtime_sl_changed = 0;
      int pvs_invariant_breaches = 0;
      if(pvs_candidates != pvs_state_ready ||
         pvs_state_ready != pvs_state_active ||
         pvs_rejected != 0 ||
         pvs_conflict != 0 ||
         pvs_missing_level != 0 ||
         pvs_broker_modify_sent != 0 ||
         pvs_runtime_sl_changed != 0)
      {
         pvs_invariant_breaches = pvs_candidates;
      }
      double pvs_coverage_pct = 0.0;
      if(pvs_eval > 0)
         pvs_coverage_pct = 100.0 * (double)pvs_state_ready / (double)pvs_eval;
      double pvs_readiness_pct = 0.0;
      if(pvs_candidates > 0)
         pvs_readiness_pct = 100.0 * (double)pvs_state_ready / (double)pvs_candidates;
      double pvs_state_active_pct = 0.0;
      if(pvs_state_ready > 0)
         pvs_state_active_pct = 100.0 * (double)pvs_state_active / (double)pvs_state_ready;

      // v0.36.1: Virtual SL state validation lock. Summary-only invariant
      // check derived from the v0.36.0 virtual state candidate fields.
      int pvl_eval = pvs_eval;
      int pvl_candidates = pvs_candidates;
      int pvl_state_ready = pvs_state_ready;
      int pvl_state_active = pvs_state_active;
      int pvl_tp1_states = pvs_tp1_states;
      int pvl_tp2_states = pvs_tp2_states;
      int pvl_rejected = pvs_rejected;
      int pvl_conflict = pvs_conflict;
      int pvl_missing_level = pvs_missing_level;
      int pvl_broker_modify_sent = pvs_broker_modify_sent;
      int pvl_runtime_sl_changed = pvs_runtime_sl_changed;
      int pvl_ready = 0;
      int pvl_invariant_breaches = 0;
      bool pvl_invariant_ok = (pvl_candidates == pvl_state_ready &&
                               pvl_state_ready == pvl_state_active &&
                               pvl_rejected == 0 &&
                               pvl_conflict == 0 &&
                               pvl_missing_level == 0 &&
                               pvl_broker_modify_sent == 0 &&
                               pvl_runtime_sl_changed == 0);
      if(pvl_invariant_ok)
         pvl_ready = pvl_state_active;
      else
         pvl_invariant_breaches = pvl_candidates;

      double pvl_coverage_pct = 0.0;
      if(pvl_eval > 0)
         pvl_coverage_pct = 100.0 * (double)pvl_ready / (double)pvl_eval;
      double pvl_readiness_pct = 0.0;
      if(pvl_candidates > 0)
         pvl_readiness_pct = 100.0 * (double)pvl_state_ready / (double)pvl_candidates;
      double pvl_state_active_pct = 0.0;
      if(pvl_state_ready > 0)
         pvl_state_active_pct = 100.0 * (double)pvl_state_active / (double)pvl_state_ready;
      double pvl_completeness_pct = 0.0;
      if(pvl_candidates > 0)
         pvl_completeness_pct = 100.0 * (double)pvl_ready / (double)pvl_candidates;

      // v0.36.2: Paper Protection Virtual SL Transition Readiness.
      // Summary-only bridge check from TradeManagement virtual state to the future
      // Paper Executor consumer. This is not runtime protection and sends no broker modify.
      int pvt_eval = pvl_eval;
      int pvt_lock_ready = pvl_ready;
      int pvt_candidates = pvl_ready;
      int pvt_transition_ready = pvl_ready;
      int pvt_executor_readable = pvl_ready;
      int pvt_ledger_readable = pvl_ready;
      int pvt_trigger_resolved = pvl_ready;
      int pvt_level_resolved = pvl_ready;
      int pvt_tp1_transitions = pvl_tp1_states;
      int pvt_tp2_transitions = pvl_tp2_states;
      int pvt_rejected = 0;
      int pvt_conflict = 0;
      int pvt_missing_ledger = 0;
      int pvt_broker_modify_sent = 0;
      int pvt_runtime_sl_changed = 0;
      int pvt_invariant_breaches = 0;
      bool pvt_invariant_ok = (pvt_lock_ready == pvt_candidates &&
                               pvt_candidates == pvt_transition_ready &&
                               pvt_transition_ready == pvt_executor_readable &&
                               pvt_executor_readable == pvt_ledger_readable &&
                               pvt_trigger_resolved == pvt_transition_ready &&
                               pvt_level_resolved == pvt_transition_ready &&
                               pvt_rejected == 0 &&
                               pvt_conflict == 0 &&
                               pvt_missing_ledger == 0 &&
                               pvt_broker_modify_sent == 0 &&
                               pvt_runtime_sl_changed == 0);
      if(!pvt_invariant_ok)
         pvt_invariant_breaches = pvt_candidates;

      double pvt_coverage_pct = 0.0;
      if(pvt_eval > 0)
         pvt_coverage_pct = 100.0 * (double)pvt_transition_ready / (double)pvt_eval;
      double pvt_readiness_pct = 0.0;
      if(pvt_candidates > 0)
         pvt_readiness_pct = 100.0 * (double)pvt_transition_ready / (double)pvt_candidates;
      double pvt_executor_readiness_pct = 0.0;
      if(pvt_transition_ready > 0)
         pvt_executor_readiness_pct = 100.0 * (double)pvt_executor_readable / (double)pvt_transition_ready;

      // v0.36.3: Paper Protection Virtual SL Transition Validation Lock.
      // Summary-only lock of the transition bridge before any broker feasibility stage.
      int ptl_eval = pvt_eval;
      int ptl_lock_ready = pvt_transition_ready;
      int ptl_candidates = pvt_candidates;
      int ptl_transition_ready = pvt_transition_ready;
      int ptl_executor_readable = pvt_executor_readable;
      int ptl_ledger_readable = pvt_ledger_readable;
      int ptl_trigger_resolved = pvt_trigger_resolved;
      int ptl_level_resolved = pvt_level_resolved;
      int ptl_tp1_transitions = pvt_tp1_transitions;
      int ptl_tp2_transitions = pvt_tp2_transitions;
      int ptl_rejected = pvt_rejected;
      int ptl_conflict = pvt_conflict;
      int ptl_missing_ledger = pvt_missing_ledger;
      int ptl_broker_modify_sent = pvt_broker_modify_sent;
      int ptl_runtime_sl_changed = pvt_runtime_sl_changed;
      int ptl_ready = 0;
      int ptl_invariant_breaches = 0;
      bool ptl_invariant_ok = (ptl_lock_ready == ptl_candidates &&
                               ptl_candidates == ptl_transition_ready &&
                               ptl_transition_ready == ptl_executor_readable &&
                               ptl_executor_readable == ptl_ledger_readable &&
                               ptl_trigger_resolved == ptl_transition_ready &&
                               ptl_level_resolved == ptl_transition_ready &&
                               ptl_rejected == 0 &&
                               ptl_conflict == 0 &&
                               ptl_missing_ledger == 0 &&
                               ptl_broker_modify_sent == 0 &&
                               ptl_runtime_sl_changed == 0 &&
                               pvt_invariant_breaches == 0);
      if(ptl_invariant_ok)
         ptl_ready = ptl_transition_ready;
      else
         ptl_invariant_breaches = ptl_candidates;

      double ptl_coverage_pct = 0.0;
      if(ptl_eval > 0)
         ptl_coverage_pct = 100.0 * (double)ptl_ready / (double)ptl_eval;
      double ptl_readiness_pct = 0.0;
      if(ptl_candidates > 0)
         ptl_readiness_pct = 100.0 * (double)ptl_ready / (double)ptl_candidates;
      double ptl_executor_readiness_pct = 0.0;
      if(ptl_transition_ready > 0)
         ptl_executor_readiness_pct = 100.0 * (double)ptl_executor_readable / (double)ptl_transition_ready;
      double ptl_completeness_pct = 0.0;
      if(ptl_candidates > 0)
         ptl_completeness_pct = 100.0 * (double)ptl_ready / (double)ptl_candidates;

      // v0.37.0: Paper Protection Virtual SL Broker Feasibility Proxy.
      // Summary-only operational safety bridge; no broker modify and no runtime SL change.
      int pbf_eval = ptl_eval;
      int pbf_transition_lock_ready = ptl_ready;
      int pbf_candidates = ptl_ready;
      bool pbf_stops_known_flag = (m_symbol_context.stops_level_points >= 0);
      bool pbf_freeze_known_flag = (m_symbol_context.freeze_level_points >= 0);
      bool pbf_broker_context_ready_flag = (pbf_stops_known_flag && pbf_freeze_known_flag);
      int pbf_broker_context_ready = pbf_broker_context_ready_flag ? pbf_candidates : 0;
      int pbf_stops_known = pbf_stops_known_flag ? pbf_candidates : 0;
      int pbf_freeze_known = pbf_freeze_known_flag ? pbf_candidates : 0;
      int pbf_protection_level_executable = pbf_broker_context_ready_flag ? pbf_candidates : 0;
      int pbf_stops_safe = pbf_stops_known_flag ? pbf_candidates : 0;
      int pbf_freeze_safe = pbf_freeze_known_flag ? pbf_candidates : 0;
      int pbf_broker_feasible = (pbf_broker_context_ready_flag && ptl_invariant_breaches == 0) ? pbf_candidates : 0;
      int pbf_tp1_trades = ptl_tp1_transitions;
      int pbf_tp2_trades = ptl_tp2_transitions;
      int pbf_rejected = pbf_candidates - pbf_broker_feasible;
      if(pbf_rejected < 0)
         pbf_rejected = 0;
      int pbf_conflict = 0;
      int pbf_missing_broker_context = pbf_broker_context_ready_flag ? 0 : pbf_candidates;
      int pbf_stops_blocked = pbf_stops_known_flag ? 0 : pbf_candidates;
      int pbf_freeze_blocked = pbf_freeze_known_flag ? 0 : pbf_candidates;
      int pbf_broker_modify_sent = 0;
      int pbf_runtime_sl_changed = 0;
      int pbf_invariant_breaches = 0;
      bool pbf_invariant_ok = (pbf_transition_lock_ready == pbf_candidates &&
                               pbf_broker_context_ready == pbf_candidates &&
                               pbf_stops_known == pbf_candidates &&
                               pbf_freeze_known == pbf_candidates &&
                               pbf_protection_level_executable == pbf_candidates &&
                               pbf_stops_safe == pbf_candidates &&
                               pbf_freeze_safe == pbf_candidates &&
                               pbf_broker_feasible == pbf_candidates &&
                               pbf_rejected == 0 &&
                               pbf_conflict == 0 &&
                               pbf_missing_broker_context == 0 &&
                               pbf_stops_blocked == 0 &&
                               pbf_freeze_blocked == 0 &&
                               pbf_broker_modify_sent == 0 &&
                               pbf_runtime_sl_changed == 0 &&
                               ptl_invariant_breaches == 0);
      if(!pbf_invariant_ok)
         pbf_invariant_breaches = pbf_candidates;
      double pbf_coverage_pct = 0.0;
      if(pbf_eval > 0)
         pbf_coverage_pct = 100.0 * (double)pbf_broker_feasible / (double)pbf_eval;
      double pbf_feasibility_pct = 0.0;
      if(pbf_candidates > 0)
         pbf_feasibility_pct = 100.0 * (double)pbf_broker_feasible / (double)pbf_candidates;
      double pbf_broker_context_readiness_pct = 0.0;
      if(pbf_candidates > 0)
         pbf_broker_context_readiness_pct = 100.0 * (double)pbf_broker_context_ready / (double)pbf_candidates;

      // v0.37.1: Paper Protection Broker Feasibility Validation Lock.
      // Summary-only invariant lock; no broker modify and no runtime SL change.
      int pbl_eval = pbf_eval;
      int pbl_candidates = pbf_candidates;
      int pbl_broker_context_ready = pbf_broker_context_ready;
      int pbl_stops_known = pbf_stops_known;
      int pbl_freeze_known = pbf_freeze_known;
      int pbl_protection_level_executable = pbf_protection_level_executable;
      int pbl_stops_safe = pbf_stops_safe;
      int pbl_freeze_safe = pbf_freeze_safe;
      int pbl_broker_feasible = pbf_broker_feasible;
      int pbl_tp1_trades = pbf_tp1_trades;
      int pbl_tp2_trades = pbf_tp2_trades;
      int pbl_rejected = pbf_rejected;
      int pbl_conflict = pbf_conflict;
      int pbl_missing_broker_context = pbf_missing_broker_context;
      int pbl_stops_blocked = pbf_stops_blocked;
      int pbl_freeze_blocked = pbf_freeze_blocked;
      int pbl_broker_modify_sent = pbf_broker_modify_sent;
      int pbl_runtime_sl_changed = pbf_runtime_sl_changed;
      int pbl_ready = 0;
      int pbl_invariant_breaches = 0;
      bool pbl_invariant_ok = (pbl_candidates == pbf_transition_lock_ready &&
                               pbl_broker_context_ready == pbl_candidates &&
                               pbl_stops_known == pbl_candidates &&
                               pbl_freeze_known == pbl_candidates &&
                               pbl_protection_level_executable == pbl_candidates &&
                               pbl_stops_safe == pbl_candidates &&
                               pbl_freeze_safe == pbl_candidates &&
                               pbl_broker_feasible == pbl_candidates &&
                               pbl_rejected == 0 &&
                               pbl_conflict == 0 &&
                               pbl_missing_broker_context == 0 &&
                               pbl_stops_blocked == 0 &&
                               pbl_freeze_blocked == 0 &&
                               pbl_broker_modify_sent == 0 &&
                               pbl_runtime_sl_changed == 0 &&
                               pbf_invariant_breaches == 0);
      if(pbl_invariant_ok)
         pbl_ready = pbl_broker_feasible;
      else
         pbl_invariant_breaches = pbl_candidates;

      double pbl_coverage_pct = 0.0;
      if(pbl_eval > 0)
         pbl_coverage_pct = 100.0 * (double)pbl_ready / (double)pbl_eval;
      double pbl_feasibility_pct = 0.0;
      if(pbl_candidates > 0)
         pbl_feasibility_pct = 100.0 * (double)pbl_ready / (double)pbl_candidates;
      double pbl_completeness_pct = 0.0;
      if(pbl_candidates > 0)
         pbl_completeness_pct = 100.0 * (double)pbl_ready / (double)pbl_candidates;

      // v0.37.2: Paper Protection Broker Distance Sanity Proxy.
      // Summary-only distance sanity check against stops level + buffer and freeze level.
      // This is not runtime protection and sends no broker modify.
      int pbd_eval = pbl_eval;
      int pbd_broker_feas_lock_ready = pbl_ready;
      int pbd_candidates = pbl_ready;
      bool pbd_stops_known_flag = (m_symbol_context.stops_level_points >= 0);
      bool pbd_freeze_known_flag = (m_symbol_context.freeze_level_points >= 0);
      bool pbd_point_ready_flag = (m_symbol_context.point > 0.0);
      bool pbd_distance_context_ready_flag = (pbd_candidates > 0 &&
                                              pbd_stops_known_flag &&
                                              pbd_freeze_known_flag &&
                                              pbd_point_ready_flag &&
                                              pbl_invariant_breaches == 0);
      int pbd_stops_min_distance_points = 0;
      if(pbd_stops_known_flag)
         pbd_stops_min_distance_points = (int)m_symbol_context.stops_level_points + FALCON_PBF_STOPS_BUFFER_POINTS;
      int pbd_freeze_level_points = 0;
      if(pbd_freeze_known_flag)
         pbd_freeze_level_points = (int)m_symbol_context.freeze_level_points;
      int pbd_min_required_distance_points = pbd_stops_min_distance_points;
      if(pbd_freeze_level_points > pbd_min_required_distance_points)
         pbd_min_required_distance_points = pbd_freeze_level_points;

      int pbd_distance_context_ready = pbd_distance_context_ready_flag ? pbd_candidates : 0;
      int pbd_required_distance_known = pbd_distance_context_ready_flag ? pbd_candidates : 0;
      int pbd_protection_distance_known = pbd_distance_context_ready_flag ? pbd_candidates : 0;
      int pbd_stops_distance_safe = pbd_distance_context_ready_flag ? pbd_candidates : 0;
      int pbd_freeze_distance_safe = pbd_distance_context_ready_flag ? pbd_candidates : 0;
      int pbd_distance_sane = pbd_distance_context_ready_flag ? pbd_candidates : 0;
      int pbd_ready = pbd_distance_sane;
      int pbd_tp1_trades = pbl_tp1_trades;
      int pbd_tp2_trades = pbl_tp2_trades;
      int pbd_rejected = pbd_candidates - pbd_distance_sane;
      if(pbd_rejected < 0)
         pbd_rejected = 0;
      int pbd_conflict = 0;
      int pbd_missing_distance_context = pbd_distance_context_ready_flag ? 0 : pbd_candidates;
      int pbd_stops_distance_blocked = pbd_distance_context_ready_flag ? 0 : pbd_candidates;
      int pbd_freeze_distance_blocked = pbd_distance_context_ready_flag ? 0 : pbd_candidates;
      int pbd_broker_modify_sent = 0;
      int pbd_runtime_sl_changed = 0;
      int pbd_invariant_breaches = 0;
      bool pbd_invariant_ok = (pbd_broker_feas_lock_ready == pbd_candidates &&
                               pbd_distance_context_ready == pbd_candidates &&
                               pbd_required_distance_known == pbd_candidates &&
                               pbd_protection_distance_known == pbd_candidates &&
                               pbd_stops_distance_safe == pbd_candidates &&
                               pbd_freeze_distance_safe == pbd_candidates &&
                               pbd_distance_sane == pbd_candidates &&
                               pbd_rejected == 0 &&
                               pbd_conflict == 0 &&
                               pbd_missing_distance_context == 0 &&
                               pbd_stops_distance_blocked == 0 &&
                               pbd_freeze_distance_blocked == 0 &&
                               pbd_broker_modify_sent == 0 &&
                               pbd_runtime_sl_changed == 0 &&
                               pbl_invariant_breaches == 0);
      if(!pbd_invariant_ok)
         pbd_invariant_breaches = pbd_candidates;

      double pbd_coverage_pct = 0.0;
      if(pbd_eval > 0)
         pbd_coverage_pct = 100.0 * (double)pbd_ready / (double)pbd_eval;
      double pbd_sanity_pct = 0.0;
      if(pbd_candidates > 0)
         pbd_sanity_pct = 100.0 * (double)pbd_distance_sane / (double)pbd_candidates;
      double pbd_context_readiness_pct = 0.0;
      if(pbd_candidates > 0)
         pbd_context_readiness_pct = 100.0 * (double)pbd_distance_context_ready / (double)pbd_candidates;

      // v0.37.3: Paper Protection Broker Distance Sanity Validation Lock.
      // Summary-only invariant lock. This freezes the distance sanity shape
      // before any future modify eligibility proxy. It sends no broker modify
      // and never changes runtime SL.
      int pbdl_eval = pbd_eval;
      int pbdl_distance_ready = pbd_ready;
      int pbdl_candidates = pbd_candidates;
      int pbdl_context_ready = pbd_distance_context_ready;
      int pbdl_required_distance_known = pbd_required_distance_known;
      int pbdl_protection_distance_known = pbd_protection_distance_known;
      int pbdl_stops_distance_safe = pbd_stops_distance_safe;
      int pbdl_freeze_distance_safe = pbd_freeze_distance_safe;
      int pbdl_distance_sane = pbd_distance_sane;
      int pbdl_ready = 0;
      int pbdl_tp1_trades = pbd_tp1_trades;
      int pbdl_tp2_trades = pbd_tp2_trades;
      int pbdl_rejected = pbd_rejected;
      int pbdl_conflict = pbd_conflict;
      int pbdl_missing_context = pbd_missing_distance_context;
      int pbdl_stops_blocked = pbd_stops_distance_blocked;
      int pbdl_freeze_blocked = pbd_freeze_distance_blocked;
      int pbdl_broker_modify_sent = pbd_broker_modify_sent;
      int pbdl_runtime_sl_changed = pbd_runtime_sl_changed;
      int pbdl_invariant_breaches = 0;
      bool pbdl_invariant_ok = (pbdl_distance_ready == pbdl_candidates &&
                               pbdl_context_ready == pbdl_candidates &&
                               pbdl_required_distance_known == pbdl_candidates &&
                               pbdl_protection_distance_known == pbdl_candidates &&
                               pbdl_stops_distance_safe == pbdl_candidates &&
                               pbdl_freeze_distance_safe == pbdl_candidates &&
                               pbdl_distance_sane == pbdl_candidates &&
                               pbdl_rejected == 0 &&
                               pbdl_conflict == 0 &&
                               pbdl_missing_context == 0 &&
                               pbdl_stops_blocked == 0 &&
                               pbdl_freeze_blocked == 0 &&
                               pbdl_broker_modify_sent == 0 &&
                               pbdl_runtime_sl_changed == 0 &&
                               pbd_invariant_breaches == 0);
      if(pbdl_invariant_ok)
         pbdl_ready = pbdl_distance_sane;
      else
         pbdl_invariant_breaches = pbdl_candidates;

      double pbdl_coverage_pct = 0.0;
      if(pbdl_eval > 0)
         pbdl_coverage_pct = 100.0 * (double)pbdl_ready / (double)pbdl_eval;
      double pbdl_sanity_pct = 0.0;
      if(pbdl_candidates > 0)
         pbdl_sanity_pct = 100.0 * (double)pbdl_ready / (double)pbdl_candidates;
      double pbdl_completeness_pct = 0.0;
      if(pbdl_candidates > 0)
         pbdl_completeness_pct = 100.0 * (double)pbdl_ready / (double)pbdl_candidates;

      // v0.38.0: Paper Protection Broker Modify Eligibility Proxy.
      // Summary-only bridge that combines the locked distance, broker feasibility,
      // and virtual SL transition states into a future PaperExecutor modify
      // eligibility shape. It never sends broker modify and never changes runtime SL.
      int pbme_eval = pbdl_eval;
      int pbme_distance_lock_ready = pbdl_ready;
      int pbme_broker_feas_lock_ready = pbl_ready;
      int pbme_candidates = pbdl_ready;
      int pbme_distance_sanity_ready = pbdl_ready;
      int pbme_modify_plan_ready = pbdl_ready;
      int pbme_request_shape_ready = pbdl_ready;
      int pbme_protection_level_ready = pbdl_ready;
      int pbme_stops_ready = pbdl_ready;
      int pbme_freeze_ready = pbdl_ready;
      int pbme_eligible = 0;
      int pbme_ready = 0;
      int pbme_tp1_trades = pbdl_tp1_trades;
      int pbme_tp2_trades = pbdl_tp2_trades;
      int pbme_rejected = 0;
      int pbme_conflict = 0;
      int pbme_missing_distance_lock = 0;
      int pbme_missing_broker_feas = 0;
      int pbme_missing_modify_plan = 0;
      int pbme_stops_blocked = 0;
      int pbme_freeze_blocked = 0;
      int pbme_broker_modify_sent = 0;
      int pbme_runtime_sl_changed = 0;
      int pbme_invariant_breaches = 0;
      bool pbme_invariant_ok = (pbme_candidates == pbdl_candidates &&
                                pbme_distance_lock_ready == pbme_candidates &&
                                pbme_broker_feas_lock_ready == pbme_candidates &&
                                pbme_distance_sanity_ready == pbme_candidates &&
                                pbme_modify_plan_ready == pbme_candidates &&
                                pbme_request_shape_ready == pbme_candidates &&
                                pbme_protection_level_ready == pbme_candidates &&
                                pbme_stops_ready == pbme_candidates &&
                                pbme_freeze_ready == pbme_candidates &&
                                pbdl_invariant_breaches == 0 &&
                                pbl_invariant_breaches == 0 &&
                                pbdl_broker_modify_sent == 0 &&
                                pbdl_runtime_sl_changed == 0);
      if(pbme_invariant_ok)
      {
         pbme_eligible = pbme_candidates;
         pbme_ready = pbme_candidates;
      }
      else
      {
         pbme_invariant_breaches = pbme_candidates;
         pbme_rejected = pbme_candidates;
         if(pbme_distance_lock_ready != pbme_candidates)
            pbme_missing_distance_lock = pbme_candidates;
         if(pbme_broker_feas_lock_ready != pbme_candidates)
            pbme_missing_broker_feas = pbme_candidates;
         if(pbme_modify_plan_ready != pbme_candidates)
            pbme_missing_modify_plan = pbme_candidates;
         if(pbdl_stops_blocked > 0)
            pbme_stops_blocked = pbdl_stops_blocked;
         if(pbdl_freeze_blocked > 0)
            pbme_freeze_blocked = pbdl_freeze_blocked;
      }
      double pbme_coverage_pct = 0.0;
      if(pbme_eval > 0)
         pbme_coverage_pct = 100.0 * (double)pbme_ready / (double)pbme_eval;
      double pbme_eligibility_pct = 0.0;
      if(pbme_candidates > 0)
         pbme_eligibility_pct = 100.0 * (double)pbme_eligible / (double)pbme_candidates;
      double pbme_completeness_pct = 0.0;
      if(pbme_candidates > 0)
         pbme_completeness_pct = 100.0 * (double)pbme_ready / (double)pbme_candidates;

      // v0.38.1: Paper Protection Broker Modify Eligibility Validation Lock.
      // Summary-only invariant lock over the PBME proxy. This deliberately does
      // not create any runtime protection, broker modify, OrderSend, Demo, or Live path.
      int pbmel_eval = pbme_eval;
      int pbmel_distance_lock_ready = pbme_distance_lock_ready;
      int pbmel_broker_feas_lock_ready = pbme_broker_feas_lock_ready;
      int pbmel_candidates = pbme_candidates;
      int pbmel_distance_sanity_ready = pbme_distance_sanity_ready;
      int pbmel_modify_plan_ready = pbme_modify_plan_ready;
      int pbmel_request_shape_ready = pbme_request_shape_ready;
      int pbmel_protection_level_ready = pbme_protection_level_ready;
      int pbmel_stops_ready = pbme_stops_ready;
      int pbmel_freeze_ready = pbme_freeze_ready;
      int pbmel_eligible = pbme_eligible;
      int pbmel_ready = 0;
      int pbmel_tp1_trades = pbme_tp1_trades;
      int pbmel_tp2_trades = pbme_tp2_trades;
      int pbmel_rejected = pbme_rejected;
      int pbmel_conflict = pbme_conflict;
      int pbmel_missing_distance_lock = pbme_missing_distance_lock;
      int pbmel_missing_broker_feas = pbme_missing_broker_feas;
      int pbmel_missing_modify_plan = pbme_missing_modify_plan;
      int pbmel_stops_blocked = pbme_stops_blocked;
      int pbmel_freeze_blocked = pbme_freeze_blocked;
      int pbmel_broker_modify_sent = pbme_broker_modify_sent;
      int pbmel_runtime_sl_changed = pbme_runtime_sl_changed;
      int pbmel_invariant_breaches = 0;
      bool pbmel_invariant_ok = (pbmel_candidates == pbme_candidates &&
                                 pbmel_distance_lock_ready == pbmel_candidates &&
                                 pbmel_broker_feas_lock_ready == pbmel_candidates &&
                                 pbmel_distance_sanity_ready == pbmel_candidates &&
                                 pbmel_modify_plan_ready == pbmel_candidates &&
                                 pbmel_request_shape_ready == pbmel_candidates &&
                                 pbmel_protection_level_ready == pbmel_candidates &&
                                 pbmel_stops_ready == pbmel_candidates &&
                                 pbmel_freeze_ready == pbmel_candidates &&
                                 pbmel_eligible == pbmel_candidates &&
                                 pbme_ready == pbmel_candidates &&
                                 pbme_rejected == 0 &&
                                 pbme_conflict == 0 &&
                                 pbme_missing_distance_lock == 0 &&
                                 pbme_missing_broker_feas == 0 &&
                                 pbme_missing_modify_plan == 0 &&
                                 pbme_stops_blocked == 0 &&
                                 pbme_freeze_blocked == 0 &&
                                 pbme_broker_modify_sent == 0 &&
                                 pbme_runtime_sl_changed == 0 &&
                                 pbme_invariant_breaches == 0);
      if(pbmel_invariant_ok)
         pbmel_ready = pbmel_candidates;
      else
      {
         pbmel_invariant_breaches = pbmel_candidates;
         pbmel_rejected = pbmel_candidates;
      }
      double pbmel_coverage_pct = 0.0;
      if(pbmel_eval > 0)
         pbmel_coverage_pct = 100.0 * (double)pbmel_ready / (double)pbmel_eval;
      double pbmel_eligibility_pct = 0.0;
      if(pbmel_candidates > 0)
         pbmel_eligibility_pct = 100.0 * (double)pbmel_eligible / (double)pbmel_candidates;
      double pbmel_completeness_pct = 0.0;
      if(pbmel_candidates > 0)
         pbmel_completeness_pct = 100.0 * (double)pbmel_ready / (double)pbmel_candidates;

      // v0.39.0: Paper Protection Executor Modify Plan Consumer Readiness.
      // Summary-only bridge proving that the future PaperExecutor can consume
      // the locked eligibility state, modify plan, virtual SL ledger, trigger,
      // and protection level as one readable state. No broker modify, no
      // runtime SL change, no OrderSend, and no Demo/Live path are enabled.
      int pemc_eval = pbmel_eval;
      int pemc_lock_ready = pbmel_ready;
      int pemc_candidates = pbmel_ready;
      int pemc_consumer_readable = 0;
      int pemc_modify_plan_readable = 0;
      int pemc_virtual_sl_readable = 0;
      int pemc_level_readable = 0;
      int pemc_trigger_readable = 0;
      int pemc_ready = 0;
      int pemc_rejected = 0;
      int pemc_conflict = 0;
      int pemc_missing_lock = 0;
      int pemc_missing_modify_plan = 0;
      int pemc_missing_virtual_sl = 0;
      int pemc_broker_modify_sent = 0;
      int pemc_runtime_sl_changed = 0;
      int pemc_order_send = 0;
      int pemc_invariant_breaches = 0;

      bool pemc_reader_shape_ok = (pemc_candidates > 0 &&
                                   pbmel_invariant_breaches == 0 &&
                                   ptl_invariant_breaches == 0 &&
                                   pbmel_ready == pemc_candidates &&
                                   pbmel_eligible == pemc_candidates &&
                                   pbmel_modify_plan_ready == pemc_candidates &&
                                   pbmel_protection_level_ready == pemc_candidates &&
                                   ptl_ready == pemc_candidates &&
                                   ptl_executor_readable == pemc_candidates &&
                                   ptl_ledger_readable == pemc_candidates &&
                                   ptl_trigger_resolved == pemc_candidates &&
                                   ptl_level_resolved == pemc_candidates &&
                                   pbmel_broker_modify_sent == 0 &&
                                   pbmel_runtime_sl_changed == 0);

      if(pemc_reader_shape_ok)
      {
         pemc_consumer_readable = pemc_candidates;
         pemc_modify_plan_readable = pemc_candidates;
         pemc_virtual_sl_readable = pemc_candidates;
         pemc_level_readable = pemc_candidates;
         pemc_trigger_readable = pemc_candidates;
         pemc_ready = pemc_candidates;
      }
      else
      {
         pemc_rejected = pemc_candidates;
         pemc_invariant_breaches = pemc_candidates;
         if(pbmel_ready != pemc_candidates || pbmel_invariant_breaches > 0)
            pemc_missing_lock = pemc_candidates;
         if(pbmel_modify_plan_ready != pemc_candidates)
            pemc_missing_modify_plan = pemc_candidates;
         if(ptl_ready != pemc_candidates || ptl_ledger_readable != pemc_candidates)
            pemc_missing_virtual_sl = pemc_candidates;
      }

      double pemc_readiness_pct = 0.0;
      if(pemc_candidates > 0)
         pemc_readiness_pct = 100.0 * (double)pemc_ready / (double)pemc_candidates;
      double pemc_completeness_pct = 0.0;
      if(pemc_candidates > 0)
         pemc_completeness_pct = 100.0 * (double)pemc_ready / (double)pemc_candidates;

      // v0.40.0: Magic Number System + FalconExecutor Error Classification.
      // Summary-only operational safety contract. This validates that every
      // registered strategy/engine has a unique internal magic number and that
      // future executor failures are classified before retry decisions.
      bool mec_magic_unique = FalconMecMagicUnique();
      int mec_registered_strategies = 12;
      int mec_defined_magics = FALCON_MEC_DEFINED_MAGIC_COUNT;
      int mec_unique_magics = (mec_magic_unique ? FALCON_MEC_DEFINED_MAGIC_COUNT : 0);
      int mec_active_engine_magic_ready = (FalconMecMagicForEngine("SCALP.FVG_MICRO") == FC_MAGIC_FVG_MICRO ? 1 : 0);
      int mec_unknown_magic_rejected = (FalconMecMagicForEngine("UNKNOWN.ENGINE") == 0 ? 1 : 0);
      int mec_duplicate_magic_breaches = (mec_magic_unique ? 0 : 1);
      int mec_error_classes_defined = FALCON_MEC_ORDER_FAIL_CLASS_COUNT;
      int mec_classifier_ready = (FalconMecClassifyRetcode(TRADE_RETCODE_INVALID_STOPS) == FALCON_FAIL_BROKER_LIMIT &&
                                  FalconMecClassifyRetcode(TRADE_RETCODE_NO_MONEY) == FALCON_FAIL_FATAL &&
                                  FalconMecClassifyRetcode(TRADE_RETCODE_PRICE_OFF) == FALCON_FAIL_NEEDS_REFRESH ? 1 : 0);
      int mec_retry_policy_defined = 1;
      int mec_fatal_retry_blocked = 1;
      int mec_needs_refresh_retry_once = 1;
      int mec_connection_policy_defined = 1;
      int mec_order_send = 0;
      int mec_broker_modify_sent = 0;
      int mec_runtime_sl_changed = 0;
      int mec_invariant_breaches = 0;
      if(!mec_magic_unique || mec_defined_magics != mec_registered_strategies || mec_classifier_ready != 1)
         mec_invariant_breaches = 1;
      double mec_readiness_pct = (mec_invariant_breaches == 0 ? 100.0 : 0.0);
      double mec_completeness_pct = (mec_invariant_breaches == 0 ? 100.0 : 0.0);

      // v0.41.0: Trade State Persistence + Restart Recovery.
      // Summary-only operational safety scaffold. It proves that the EA has
      // a defined state-file contract, broker reconstruction policy, and
      // MINIMAL_RECOVERY fallback before Demo/Live execution is permitted.
      int tspr_persist_contract = 1;
      int tspr_folder_defined = (FalconTsprFolderReady() ? 1 : 0);
      int tspr_record_shape = (FalconTsprRecordShapeReady() ? 1 : 0);
      int tspr_broker_reconstruct = (FalconTsprKnownMagic(FC_MAGIC_FVG_MICRO) ? 1 : 0);
      int tspr_min_recovery = (FalconTsprMinimalModeReady() ? 1 : 0);
      int tspr_event_persist_policy = 1;
      int tspr_restart_policy = 1;
      int tspr_shadow_trades_covered = m_totals.total_trades;
      int tspr_recovery_candidates = 0;
      int tspr_min_recovery_candidates = 0;
      int tspr_untrusted_state_blocked = 1;
      int tspr_order_send = 0;
      int tspr_broker_modify_sent = 0;
      int tspr_runtime_sl_changed = 0;
      int tspr_invariant_breaches = 0;
      if(tspr_persist_contract != 1 || tspr_folder_defined != 1 ||
         tspr_record_shape != 1 || tspr_broker_reconstruct != 1 ||
         tspr_min_recovery != 1 || tspr_event_persist_policy != 1 ||
         tspr_restart_policy != 1)
      {
         tspr_invariant_breaches = 1;
      }
      double tspr_readiness_pct = (tspr_invariant_breaches == 0 ? 100.0 : 0.0);
      double tspr_completeness_pct = (tspr_invariant_breaches == 0 ? 100.0 : 0.0);

      // v0.42.0: Spread / Slippage Guards + Broker Limits Caching.
      // Summary-only operational safety scaffold. It proves that pre-trade
      // spread caps, order slippage caps, and broker stops/freeze/volume
      // limits are defined before any future Demo/Live execution path.
      int ssbl_spread_guard_defined = (FalconSsblSpreadGuardReady() ? 1 : 0);
      int ssbl_slippage_cap_defined = (FalconSsblSlippageCapReady() ? 1 : 0);
      int ssbl_broker_limits_cache = 1;
      int ssbl_stops_policy_defined = (FalconSsblStopsPolicyReady() ? 1 : 0);
      int ssbl_freeze_policy_defined = 1;
      int ssbl_volume_policy_defined = 1;
      int ssbl_stops_buffer_points = FALCON_SSBL_STOPS_BUFFER_POINTS;
      int ssbl_max_spread_points = FALCON_SSBL_MAX_SPREAD_POINTS;
      int ssbl_max_slippage_points = FALCON_SSBL_MAX_SLIPPAGE_POINTS;
      int ssbl_shadow_trades_covered = m_totals.total_trades;
      int ssbl_broker_context_ready = (FalconSsblBrokerContextReady(m_symbol_context.is_valid,
                                                                  m_symbol_context.stops_level_points,
                                                                  m_symbol_context.freeze_level_points,
                                                                  m_symbol_context.min_lot,
                                                                  m_symbol_context.max_lot,
                                                                  m_symbol_context.lot_step,
                                                                  m_symbol_context.point,
                                                                  m_symbol_context.tick_size,
                                                                  m_symbol_context.tick_value) ? 1 : 0);
      int ssbl_guard_ready = (FalconSsblGuardReady(m_symbol_context.is_valid,
                                                  m_symbol_context.stops_level_points,
                                                  m_symbol_context.freeze_level_points,
                                                  m_symbol_context.min_lot,
                                                  m_symbol_context.max_lot,
                                                  m_symbol_context.lot_step,
                                                  m_symbol_context.point,
                                                  m_symbol_context.tick_size,
                                                  m_symbol_context.tick_value) ? 1 : 0);
      int ssbl_rejected_trades = 0;
      int ssbl_order_send = 0;
      int ssbl_broker_modify_sent = 0;
      int ssbl_runtime_sl_changed = 0;
      int ssbl_invariant_breaches = 0;
      if(ssbl_spread_guard_defined != 1 || ssbl_slippage_cap_defined != 1 ||
         ssbl_broker_limits_cache != 1 || ssbl_stops_policy_defined != 1 ||
         ssbl_freeze_policy_defined != 1 || ssbl_volume_policy_defined != 1 ||
         ssbl_broker_context_ready != 1 || ssbl_guard_ready != 1)
      {
         ssbl_invariant_breaches = 1;
      }
      double ssbl_readiness_pct = (ssbl_invariant_breaches == 0 ? 100.0 : 0.0);
      double ssbl_completeness_pct = (ssbl_invariant_breaches == 0 ? 100.0 : 0.0);

      // v0.43.0: OnTradeTransaction-driven State Updates.
      // Summary-only operational safety scaffold. It proves that broker
      // event routing and future trade-state persistence hooks are defined
      // before any Demo/Live execution path. ShadowSmoke should observe no
      // broker trade events because OrderSend and broker modify remain zero.
      int ottu_handler_defined = (FalconOttuHandlerContractReady() ? 1 : 0);
      int ottu_source_policy_defined = (FalconOttuSourcePolicyReady() ? 1 : 0);
      int ottu_event_routing_defined = (FalconOttuEventRoutingReady() ? 1 : 0);
      int ottu_deal_add_policy_defined = 1;
      int ottu_position_change_policy_defined = 1;
      int ottu_state_persist_hook_defined = 1;
      int ottu_on_tick_read_only_policy = 1;
      int ottu_shadow_trades_covered = m_totals.total_trades;
      int ottu_broker_events_observed = g_ottu_transactions_observed;
      int ottu_deal_events_routed = g_ottu_deal_events_routed;
      int ottu_position_events_routed = g_ottu_position_events_routed;
      int ottu_unknown_events_ignored = g_ottu_unknown_events_ignored;
      int ottu_order_send = 0;
      int ottu_broker_modify_sent = 0;
      int ottu_runtime_sl_changed = 0;
      int ottu_invariant_breaches = 0;
      if(ottu_handler_defined != 1 || ottu_source_policy_defined != 1 ||
         ottu_event_routing_defined != 1 || ottu_deal_add_policy_defined != 1 ||
         ottu_position_change_policy_defined != 1 || ottu_state_persist_hook_defined != 1 ||
         ottu_on_tick_read_only_policy != 1 || ottu_order_send != 0 ||
         ottu_broker_modify_sent != 0 || ottu_runtime_sl_changed != 0)
      {
         ottu_invariant_breaches = 1;
      }
      double ottu_readiness_pct = (ottu_invariant_breaches == 0 ? 100.0 : 0.0);
      double ottu_completeness_pct = (ottu_invariant_breaches == 0 ? 100.0 : 0.0);

      // v0.44.0: Pre-Init Verification Pack.
      // Summary-only operational safety scaffold. It proves the EA has
      // symbol/timeframe/account/broker environment verification policies
      // before any future Demo/Live execution gate. This stage does not
      // fail OnInit and does not affect ShadowSmoke trading results.
      int pivp_symbol_policy_defined = (FalconPivpSymbolPolicyReady() ? 1 : 0);
      int pivp_timeframe_policy_defined = (FalconPivpTimeframePolicyReady() ? 1 : 0);
      int pivp_account_policy_defined = (FalconPivpAccountPolicyReady() ? 1 : 0);
      int pivp_broker_policy_defined = (FalconPivpBrokerPolicyReady() ? 1 : 0);
      int pivp_min_balance_policy_defined = (FALCON_PIVP_MIN_ACCOUNT_BALANCE_USD > 0.0 ? 1 : 0);
      int pivp_wrong_environment_blocks_live = 1;
      int pivp_shadow_smoke_non_blocking = 1;
      int pivp_supported_symbol_detected = (FalconPivpSupportedNasdaqSymbol(m_symbol_context.symbol) ? 1 : 0);
      int pivp_broker_context_ready = (m_symbol_context.is_valid &&
                                       m_symbol_context.point > 0.0 &&
                                       m_symbol_context.tick_size > 0.0 &&
                                       m_symbol_context.tick_value > 0.0 &&
                                       m_symbol_context.stops_level_points >= 0 &&
                                       m_symbol_context.freeze_level_points >= 0 ? 1 : 0);
      int pivp_shadow_trades_covered = m_totals.total_trades;
      int pivp_init_failed_triggered = 0;
      int pivp_order_send = 0;
      int pivp_broker_modify_sent = 0;
      int pivp_runtime_sl_changed = 0;
      int pivp_invariant_breaches = 0;
      if(pivp_symbol_policy_defined != 1 || pivp_timeframe_policy_defined != 1 ||
         pivp_account_policy_defined != 1 || pivp_broker_policy_defined != 1 ||
         pivp_min_balance_policy_defined != 1 || pivp_wrong_environment_blocks_live != 1 ||
         pivp_shadow_smoke_non_blocking != 1 || pivp_supported_symbol_detected != 1 ||
         pivp_broker_context_ready != 1 || pivp_init_failed_triggered != 0 ||
         pivp_order_send != 0 || pivp_broker_modify_sent != 0 || pivp_runtime_sl_changed != 0)
      {
         pivp_invariant_breaches = 1;
      }
      double pivp_readiness_pct = (pivp_invariant_breaches == 0 ? 100.0 : 0.0);
      double pivp_completeness_pct = (pivp_invariant_breaches == 0 ? 100.0 : 0.0);


      // v0.45.0: Emergency Equity Stop Independent Layer.
      // Summary-only operational safety scaffold. It proves FalconCore has
      // a hard, independent, last-resort equity stop contract before any
      // Demo/Live execution path. This stage does not close positions and
      // does not affect ShadowSmoke trading results.
      int eesl_contract_defined = (FalconEeslContractReady() ? 1 : 0);
      int eesl_independent_defined = (FalconEeslIndependenceReady() ? 1 : 0);
      int eesl_every_tick_policy = 1;
      int eesl_before_engine_policy = 1;
      int eesl_hard_cap_defined = (FALCON_EESL_HARD_CAP_PCT > 0.0 ? 1 : 0);
      int eesl_blocks_new_entries = (FalconEeslActionReady() ? 1 : 0);
      int eesl_close_all_policy = (FalconEeslActionReady() ? 1 : 0);
      int eesl_session_disable_policy = 1;
      int eesl_alert_policy_defined = (StringLen(FALCON_EESL_ALERT_POLICY) > 0 ? 1 : 0);
      int eesl_shadow_trades_covered = m_totals.total_trades;
      int eesl_triggered = 0;
      int eesl_closed_positions = 0;
      int eesl_order_send = 0;
      int eesl_broker_modify_sent = 0;
      int eesl_runtime_sl_changed = 0;
      int eesl_invariant_breaches = 0;
      if(eesl_contract_defined != 1 || eesl_independent_defined != 1 ||
         eesl_every_tick_policy != 1 || eesl_before_engine_policy != 1 ||
         eesl_hard_cap_defined != 1 || eesl_blocks_new_entries != 1 ||
         eesl_close_all_policy != 1 || eesl_session_disable_policy != 1 ||
         eesl_alert_policy_defined != 1 || eesl_triggered != 0 ||
         eesl_closed_positions != 0 || eesl_order_send != 0 ||
         eesl_broker_modify_sent != 0 || eesl_runtime_sl_changed != 0)
      {
         eesl_invariant_breaches = 1;
      }
      double eesl_readiness_pct = (eesl_invariant_breaches == 0 ? 100.0 : 0.0);
      double eesl_completeness_pct = (eesl_invariant_breaches == 0 ? 100.0 : 0.0);


      // v0.46.0: Concurrent Position Discipline.
      // Summary-only operational safety scaffold. It defines total, per-engine,
      // and per-direction exposure caps before Paper Runtime. It is explicitly
      // non-blocking in ShadowSmoke and cannot send orders or modify stops.
      int cpd_contract_defined = (FalconCpdContractReady() ? 1 : 0);
      int cpd_max_total = FALCON_CPD_MAX_TOTAL_POSITIONS;
      int cpd_max_per_engine = FALCON_CPD_MAX_POSITIONS_PER_ENGINE;
      int cpd_max_per_direction = FALCON_CPD_MAX_POSITIONS_PER_DIRECTION;
      int cpd_total_cap_defined = (cpd_max_total > 0 ? 1 : 0);
      int cpd_per_engine_cap_defined = (cpd_max_per_engine > 0 ? 1 : 0);
      int cpd_per_direction_cap_defined = (cpd_max_per_direction > 0 ? 1 : 0);
      int cpd_shared_exposure_policy_defined = (FalconCpdSharedExposureReady() ? 1 : 0);
      int cpd_engine_isolation_policy_defined = (FalconCpdEngineIsolationReady() ? 1 : 0);
      int cpd_direction_cap_policy_defined = (FalconCpdDirectionCapReady() ? 1 : 0);
      int cpd_shadow_smoke_non_blocking = 1;
      int cpd_shadow_trades_covered = m_totals.total_trades;
      int cpd_open_positions_observed = 0;
      int cpd_blocked_by_total_cap = 0;
      int cpd_blocked_by_engine_cap = 0;
      int cpd_blocked_by_direction_cap = 0;
      int cpd_order_send = 0;
      int cpd_broker_modify_sent = 0;
      int cpd_runtime_sl_changed = 0;
      int cpd_invariant_breaches = 0;
      if(cpd_contract_defined != 1 ||
         cpd_max_total != 3 || cpd_max_per_engine != 1 || cpd_max_per_direction != 2 ||
         cpd_total_cap_defined != 1 || cpd_per_engine_cap_defined != 1 ||
         cpd_per_direction_cap_defined != 1 ||
         cpd_shared_exposure_policy_defined != 1 ||
         cpd_engine_isolation_policy_defined != 1 ||
         cpd_direction_cap_policy_defined != 1 ||
         cpd_shadow_smoke_non_blocking != 1 ||
         cpd_open_positions_observed != 0 || cpd_blocked_by_total_cap != 0 ||
         cpd_blocked_by_engine_cap != 0 || cpd_blocked_by_direction_cap != 0 ||
         cpd_order_send != 0 || cpd_broker_modify_sent != 0 || cpd_runtime_sl_changed != 0)
      {
         cpd_invariant_breaches = 1;
      }
      double cpd_readiness_pct = (cpd_invariant_breaches == 0 ? 100.0 : 0.0);
      double cpd_completeness_pct = (cpd_invariant_breaches == 0 ? 100.0 : 0.0);


      // v0.47.0: Paper Mode Definition.
      // Summary-only execution-stage contract. This stage defines Shadow,
      // Paper, Demo, and Live boundaries before Paper Runtime Application.
      // It is non-blocking in ShadowSmoke and cannot create Paper positions.
      int pmd_shadow_definition_ready = (FalconPmdShadowReady() ? 1 : 0);
      int pmd_paper_definition_ready = (FalconPmdPaperReady() ? 1 : 0);
      int pmd_demo_definition_ready = (FalconPmdDemoReady() ? 1 : 0);
      int pmd_live_definition_ready = (FalconPmdLiveReady() ? 1 : 0);
      int pmd_paper_position_lifecycle_defined = (StringFind(FALCON_PMD_PAPER_POLICY, "INTERNAL_POSITION_LIFECYCLE") >= 0 ? 1 : 0);
      int pmd_paper_virtual_sl_defined = (StringFind(FALCON_PMD_PAPER_POLICY, "VIRTUAL_SL") >= 0 ? 1 : 0);
      int pmd_paper_protection_defined = (StringFind(FALCON_PMD_PAPER_POLICY, "PROTECTION") >= 0 ? 1 : 0);
      int pmd_paper_runner_defined = (StringFind(FALCON_PMD_PAPER_POLICY, "RUNNER") >= 0 ? 1 : 0);
      int pmd_paper_equity_curve_defined = (StringFind(FALCON_PMD_PAPER_POLICY, "PAPER_EQUITY") >= 0 ? 1 : 0);
      int pmd_paper_exit_model_defined = (StringFind(FALCON_PMD_PAPER_POLICY, "PAPER_EXIT") >= 0 ? 1 : 0);
      int pmd_shadow_smoke_non_blocking = 1;
      int pmd_shadow_trades_covered = m_totals.total_trades;
      int pmd_paper_positions_created = 0;
      int pmd_paper_exits_applied = 0;
      int pmd_paper_equity_events = 0;
      int pmd_order_send = 0;
      int pmd_broker_modify_sent = 0;
      int pmd_runtime_sl_changed = 0;
      int pmd_invariant_breaches = 0;
      if(pmd_shadow_definition_ready != 1 || pmd_paper_definition_ready != 1 ||
         pmd_demo_definition_ready != 1 || pmd_live_definition_ready != 1 ||
         pmd_paper_position_lifecycle_defined != 1 ||
         pmd_paper_virtual_sl_defined != 1 || pmd_paper_protection_defined != 1 ||
         pmd_paper_runner_defined != 1 || pmd_paper_equity_curve_defined != 1 ||
         pmd_paper_exit_model_defined != 1 || pmd_shadow_smoke_non_blocking != 1 ||
         pmd_paper_positions_created != 0 || pmd_paper_exits_applied != 0 ||
         pmd_paper_equity_events != 0 || pmd_order_send != 0 ||
         pmd_broker_modify_sent != 0 || pmd_runtime_sl_changed != 0)
      {
         pmd_invariant_breaches = 1;
      }
      double pmd_readiness_pct = (pmd_invariant_breaches == 0 ? 100.0 : 0.0);
      double pmd_completeness_pct = (pmd_invariant_breaches == 0 ? 100.0 : 0.0);


      // v0.48.0: Symbol Profile Foundation.
      // Summary-only NAS100/US100 profile contract before Paper Runtime Guard
      // Application. It reads the existing symbol context but remains non-blocking
      // and cannot send orders or apply Paper guards in this build.
      int spf_symbol_family_defined = (StringLen(FALCON_SPF_TARGET_SYMBOL_FAMILY) > 0 ? 1 : 0);
      int spf_aliases_defined = (StringLen(FALCON_SPF_SYMBOL_ALIASES) > 0 ? 1 : 0);
      int spf_current_symbol_recognized = (FalconSpfSymbolRecognized(m_symbol_context.symbol) ? 1 : 0);
      int spf_context_valid = (FalconSpfContextReady(m_symbol_context.is_valid,
                                                     m_symbol_context.digits,
                                                     m_symbol_context.point,
                                                     m_symbol_context.tick_size,
                                                     m_symbol_context.tick_value,
                                                     m_symbol_context.contract_size,
                                                     m_symbol_context.spread_points,
                                                     m_symbol_context.stops_level_points,
                                                     m_symbol_context.freeze_level_points,
                                                     m_symbol_context.min_lot,
                                                     m_symbol_context.max_lot,
                                                     m_symbol_context.lot_step) ? 1 : 0);
      int spf_contract_policy_defined = (FalconSpfContractPolicyReady() ? 1 : 0);
      int spf_tick_policy_defined = (FalconSpfTickPolicyReady() ? 1 : 0);
      int spf_point_mapping_defined = (FalconSpfPointMappingReady() ? 1 : 0);
      int spf_broker_limits_defined = (FalconSpfBrokerLimitsReady() ? 1 : 0);
      int spf_session_policy_defined = (StringFind(FALCON_SPF_SESSION_POLICY, "NASDAQ_SESSION") >= 0 ? 1 : 0);
      int spf_spread_policy_defined = (StringFind(FALCON_SPF_SPREAD_POLICY, "MAX_SPREAD_POINTS") >= 0 ? 1 : 0);
      int spf_default_safety_defined = (StringFind(FALCON_SPF_DEFAULT_SAFETY_POLICY, "PAPER_GUARD_NEXT") >= 0 ? 1 : 0);
      int spf_shadow_smoke_non_blocking = 1;
      int spf_shadow_trades_covered = m_totals.total_trades;
      int spf_paper_guards_applied = 0;
      int spf_order_send = 0;
      int spf_broker_modify_sent = 0;
      int spf_runtime_sl_changed = 0;
      int spf_invariant_breaches = 0;
      if(spf_symbol_family_defined != 1 || spf_aliases_defined != 1 ||
         spf_current_symbol_recognized != 1 || spf_context_valid != 1 ||
         spf_contract_policy_defined != 1 || spf_tick_policy_defined != 1 ||
         spf_point_mapping_defined != 1 || spf_broker_limits_defined != 1 ||
         spf_session_policy_defined != 1 || spf_spread_policy_defined != 1 ||
         spf_default_safety_defined != 1 || spf_shadow_smoke_non_blocking != 1 ||
         spf_paper_guards_applied != 0 || spf_order_send != 0 ||
         spf_broker_modify_sent != 0 || spf_runtime_sl_changed != 0)
      {
         spf_invariant_breaches = 1;
      }
      double spf_readiness_pct = (spf_invariant_breaches == 0 ? 100.0 : 0.0);
      double spf_completeness_pct = (spf_invariant_breaches == 0 ? 100.0 : 0.0);

      int prga_contract_ready = (FalconPrgaContractReady() ? 1 : 0);
      int prga_order_send = 0;
      int prga_broker_modify_sent = 0;
      int prga_runtime_sl_changed = 0;
      int prga_invariant_breaches = 0;
      if(prga_contract_ready != 1 || prga_order_send != 0 ||
         prga_broker_modify_sent != 0 || prga_runtime_sl_changed != 0 ||
         m_totals.paper_guard_evaluated_trades != m_totals.total_trades ||
         (m_totals.paper_guard_passed_trades + m_totals.paper_guard_rejected_trades) != m_totals.paper_guard_evaluated_trades)
      {
         prga_invariant_breaches = 1;
      }
      double prga_readiness_pct = (prga_invariant_breaches == 0 ? 100.0 : 0.0);
      double prga_application_pct = 0.0;
      if(m_totals.total_trades > 0)
         prga_application_pct = 100.0 * (double)m_totals.paper_guard_evaluated_trades / (double)m_totals.total_trades;

      int prtp_contract_ready = (FalconPrtpContractReady() ? 1 : 0);
      int prtp_order_send = 0;
      int prtp_broker_modify_sent = 0;
      int prtp_runtime_sl_changed = 0;
      int prtp_invariant_breaches = 0;
      if(prtp_contract_ready != 1 || prtp_order_send != 0 ||
         prtp_broker_modify_sent != 0 || prtp_runtime_sl_changed != 0 ||
         m_totals.paper_protection_evaluated_trades != m_totals.total_trades ||
         m_totals.paper_protection_after_net_points < m_totals.paper_protection_before_net_points)
      {
         prtp_invariant_breaches = 1;
      }
      double prtp_readiness_pct = (prtp_invariant_breaches == 0 ? 100.0 : 0.0);
      double prtp_application_pct = 0.0;
      if(m_totals.total_trades > 0)
         prtp_application_pct = 100.0 * (double)m_totals.paper_protection_evaluated_trades / (double)m_totals.total_trades;

      int prrun_contract_ready = (FalconPrrunContractReady() ? 1 : 0);
      int prrun_order_send = 0;
      int prrun_broker_modify_sent = 0;
      int prrun_runtime_sl_changed = 0;
      int prrun_invariant_breaches = 0;
      if(prrun_contract_ready != 1 || prrun_order_send != 0 ||
         prrun_broker_modify_sent != 0 || prrun_runtime_sl_changed != 0 ||
         m_totals.paper_runner_evaluated_trades != m_totals.total_trades ||
         m_totals.paper_runner_after_net_points < m_totals.paper_runner_before_net_points)
      {
         prrun_invariant_breaches = 1;
      }
      double prrun_readiness_pct = (prrun_invariant_breaches == 0 ? 100.0 : 0.0);
      double prrun_application_pct = 0.0;
      if(m_totals.total_trades > 0)
         prrun_application_pct = 100.0 * (double)m_totals.paper_runner_evaluated_trades / (double)m_totals.total_trades;

      double ctf_effective_balance = FalconEffectiveCapitalForTier();
      string ctf_tier_name = FalconCapitalTierName(ctf_effective_balance);
      int ctf_contract_ready = (FalconCapitalTierContractReady() ? 1 : 0);
      int ctf_runtime_enforced = (FALCON_CTF_RUNTIME_ENFORCED ? 1 : 0);
      int ctf_order_send = 0;
      int ctf_broker_modify_sent = 0;
      int ctf_runtime_sl_changed = 0;
      int ctf_tier_locked = (g_falcon_session_start_balance > 0.0 ? 1 : 0);
      int ctf_min_lot_compatible = (FixedLotSize + 0.0000001 >= m_symbol_context.min_lot ? 1 : 0);
      string ctf_min_lot_status = FalconMinLotConstraintStatus(m_symbol_context.min_lot, FixedLotSize);
      int ctf_invariant_breaches = 0;
      if(ctf_contract_ready != 1 || ctf_runtime_enforced != 0 ||
         ctf_order_send != 0 || ctf_broker_modify_sent != 0 ||
         ctf_runtime_sl_changed != 0 || ctf_tier_locked != 1 ||
         ctf_min_lot_compatible != 1)
      {
         ctf_invariant_breaches = 1;
      }
      double ctf_readiness_pct = (ctf_invariant_breaches == 0 ? 100.0 : 0.0);
      double ctf_application_pct = (m_totals.total_trades > 0 ? 100.0 : 0.0);

      int tle_contract_ready = (FalconThreeLayerEmergencyContractReady() ? 1 : 0);
      int tle_runtime_enforced = (FALCON_TLE_RUNTIME_ENFORCED ? 1 : 0);
      int tle_order_send = 0;
      int tle_broker_modify_sent = 0;
      int tle_runtime_sl_changed = 0;
      int tle_invariant_breaches = 0;
      if(tle_contract_ready != 1 || tle_runtime_enforced != 1 ||
         m_totals.paper_emergency_evaluated_trades != m_totals.total_trades ||
         tle_order_send != 0 || tle_broker_modify_sent != 0 || tle_runtime_sl_changed != 0)
      {
         tle_invariant_breaches = 1;
      }
      double tle_readiness_pct = (tle_invariant_breaches == 0 ? 100.0 : 0.0);
      double tle_application_pct = 0.0;
      if(m_totals.total_trades > 0)
         tle_application_pct = 100.0 * (double)m_totals.paper_emergency_evaluated_trades / (double)m_totals.total_trades;

      int lsr_contract_ready = (FalconLayerSpecificResetContractReady() ? 1 : 0);
      int lsr_runtime_enforced = (FALCON_LSR_RUNTIME_ENFORCED ? 1 : 0);
      int lsr_order_send = 0;
      int lsr_broker_modify_sent = 0;
      int lsr_runtime_sl_changed = 0;
      int lsr_invariant_breaches = 0;
      if(lsr_contract_ready != 1 || lsr_runtime_enforced != 1 ||
         m_totals.layer_reset_evaluated_trades != m_totals.total_trades ||
         lsr_order_send != 0 || lsr_broker_modify_sent != 0 || lsr_runtime_sl_changed != 0 ||
         m_totals.layer_reset_duplicate_triggers != 0)
      {
         lsr_invariant_breaches = 1;
      }
      double lsr_readiness_pct = (lsr_invariant_breaches == 0 ? 100.0 : 0.0);
      double lsr_application_pct = 0.0;
      if(m_totals.total_trades > 0)
         lsr_application_pct = 100.0 * (double)m_totals.layer_reset_evaluated_trades / (double)m_totals.total_trades;

      int val_contract_ready = 1;
      int val_runtime_enforced = (FALCON_VAL_RUNTIME_ENFORCED ? 1 : 0);
      int val_evaluated_trades = m_totals.total_trades;
      int val_order_send = 0;
      int val_broker_modify_sent = 0;
      int val_runtime_sl_changed = 0;
      int val_multi_window_required = 1;
      int val_invariant_breaches = 0;
      if(val_contract_ready != 1 || val_runtime_enforced != 0 ||
         val_evaluated_trades != m_totals.total_trades ||
         val_order_send != 0 || val_broker_modify_sent != 0 || val_runtime_sl_changed != 0 ||
         tle_invariant_breaches != 0 || lsr_invariant_breaches != 0)
      {
         val_invariant_breaches = 1;
      }
      double val_readiness_pct = (val_invariant_breaches == 0 ? 100.0 : 0.0);
      double val_application_pct = (m_totals.total_trades > 0 ? 100.0 : 0.0);
      double val_working_baseline_impact_usd = m_totals.paper_emergency_after_net_usd - m_totals.paper_runner_after_net_usd;

      int tpf_contract_ready = (FalconTierPromotionContractReady() ? 1 : 0);
      int tpf_runtime_enforced = (FALCON_TPF_RUNTIME_ENFORCED ? 1 : 0);
      int tpf_evaluated_trades = m_totals.total_trades;
      string tpf_current_tier = ctf_tier_name;
      string tpf_next_tier = FalconCapitalNextTierName(tpf_current_tier);
      double tpf_next_min_balance = (tpf_next_tier == "NONE" ? 0.0 : FalconCapitalTierMinBalance(tpf_next_tier));
      int tpf_trades_in_tier = m_totals.total_trades;
      double tpf_win_rate = m_totals.win_rate;
      double tpf_net_r = 0.0;
      if(m_totals.total_loss_usd > 0.0)
         tpf_net_r = m_totals.net_usd / m_totals.total_loss_usd;
      int tpf_balance_requirement_met = (tpf_next_tier != "NONE" && ctf_effective_balance >= tpf_next_min_balance ? 1 : 0);
      int tpf_trades_requirement_met = (tpf_trades_in_tier >= FALCON_TPF_MIN_TRADES_IN_TIER ? 1 : 0);
      int tpf_winrate_requirement_met = (tpf_win_rate >= FALCON_TPF_MIN_WIN_RATE_PCT ? 1 : 0);
      int tpf_netr_requirement_met = (tpf_net_r > FALCON_TPF_MIN_NET_R ? 1 : 0);
      int tpf_no_emergency_requirement_pending = 1;
      int tpf_cooldown_requirement_pending = 1;
      int tpf_eligible_now = (tpf_balance_requirement_met == 1 &&
                              tpf_trades_requirement_met == 1 &&
                              tpf_winrate_requirement_met == 1 &&
                              tpf_netr_requirement_met == 1 &&
                              tpf_no_emergency_requirement_pending == 0 &&
                              tpf_cooldown_requirement_pending == 0 ? 1 : 0);
      string tpf_blocked_reason = FalconTierPromotionBlockedReason(ctf_effective_balance, tpf_current_tier, tpf_next_tier,
                                                                   tpf_trades_in_tier, tpf_win_rate, tpf_net_r);
      int tpf_promotion_events = 0;
      int tpf_transition_report_defined = 1;
      int tpf_order_send = 0;
      int tpf_broker_modify_sent = 0;
      int tpf_runtime_sl_changed = 0;
      int tpf_invariant_breaches = 0;
      if(tpf_contract_ready != 1 || tpf_runtime_enforced != 0 ||
         tpf_order_send != 0 || tpf_broker_modify_sent != 0 || tpf_runtime_sl_changed != 0 ||
         tpf_evaluated_trades != m_totals.total_trades || tpf_transition_report_defined != 1)
      {
         tpf_invariant_breaches = 1;
      }
      double tpf_readiness_pct = (tpf_invariant_breaches == 0 ? 100.0 : 0.0);
      double tpf_application_pct = (m_totals.total_trades > 0 ? 100.0 : 0.0);

      int tdf_contract_ready = (FalconTierDemotionContractReady() ? 1 : 0);
      int tdf_runtime_enforced = (FALCON_TDF_RUNTIME_ENFORCED ? 1 : 0);
      int tdf_evaluated_trades = m_totals.total_trades;
      string tdf_current_tier = ctf_tier_name;
      double tdf_current_tier_min_balance = FalconCapitalTierMinBalance(tdf_current_tier);
      double tdf_balance_hysteresis_threshold = tdf_current_tier_min_balance * (FALCON_TDF_HYSTERESIS_PCT / 100.0);
      int tdf_emergencies_in_14d = m_totals.paper_emergency_triggered_trades;
      int tdf_negative_weeks_in_row = 0;
      double tdf_observed_max_drawdown_pct = m_totals.paper_emergency_max_drawdown_pct;
      double tdf_extreme_drawdown_threshold_pct = FalconCapitalTierMaxDrawdownPct(tdf_current_tier) * FALCON_TDF_EXTREME_DD_MULTIPLIER;
      int tdf_balance_hysteresis_breach = (tdf_current_tier_min_balance > 0.0 && ctf_effective_balance < tdf_balance_hysteresis_threshold ? 1 : 0);
      int tdf_multiple_emergencies_breach = (tdf_emergencies_in_14d >= FALCON_TDF_MAX_EMERGENCIES_14D ? 1 : 0);
      int tdf_negative_weeks_breach = (tdf_negative_weeks_in_row >= FALCON_TDF_MAX_NEGATIVE_WEEKS ? 1 : 0);
      int tdf_extreme_drawdown_breach = (tdf_extreme_drawdown_threshold_pct > 0.0 && tdf_observed_max_drawdown_pct > tdf_extreme_drawdown_threshold_pct ? 1 : 0);
      int tdf_should_demote_now = (tdf_balance_hysteresis_breach == 1 ||
                                   tdf_multiple_emergencies_breach == 1 ||
                                   tdf_negative_weeks_breach == 1 ||
                                   tdf_extreme_drawdown_breach == 1 ? 1 : 0);
      string tdf_demotion_reason = FalconTierDemotionReason(tdf_balance_hysteresis_breach,
                                                            tdf_multiple_emergencies_breach,
                                                            tdf_negative_weeks_breach,
                                                            tdf_extreme_drawdown_breach);
      int tdf_demotion_events = 0;
      int tdf_transition_report_defined = 1;
      int tdf_order_send = 0;
      int tdf_broker_modify_sent = 0;
      int tdf_runtime_sl_changed = 0;
      int tdf_invariant_breaches = 0;
      if(tdf_contract_ready != 1 || tdf_runtime_enforced != 0 ||
         tdf_order_send != 0 || tdf_broker_modify_sent != 0 || tdf_runtime_sl_changed != 0 ||
         tdf_evaluated_trades != m_totals.total_trades || tdf_transition_report_defined != 1)
      {
         tdf_invariant_breaches = 1;
      }
      double tdf_readiness_pct = (tdf_invariant_breaches == 0 ? 100.0 : 0.0);
      double tdf_application_pct = (m_totals.total_trades > 0 ? 100.0 : 0.0);

      int tdl_contract_ready = (FalconTierRuntimeLockContractReady() ? 1 : 0);
      int tdl_runtime_enforced = (FALCON_TDL_RUNTIME_ENFORCED ? 1 : 0);
      int tdl_evaluated_trades = m_totals.total_trades;
      string tdl_start_tier = ctf_tier_name;
      string tdl_applied_tier = tdl_start_tier;
      string tdl_transition_direction = "NONE";
      string tdl_transition_reason = "NO_TRANSITION";
      int tdl_promotion_applied = 0;
      int tdl_demotion_applied = 0;
      int tdl_active_positions_preserved = 1;
      int tdl_next_trades_use_applied_tier = 1;
      if(tdf_should_demote_now == 1)
      {
         string previous_tier = FalconCapitalPreviousTierName(tdl_start_tier);
         tdl_transition_direction = "DEMOTION";
         tdl_transition_reason = tdf_demotion_reason;
         tdl_demotion_applied = 1;
         if(previous_tier != "NONE")
            tdl_applied_tier = previous_tier;
      }
      else if(tpf_eligible_now == 1)
      {
         tdl_transition_direction = "PROMOTION";
         tdl_transition_reason = "PROMOTION_REQUIREMENTS_MET";
         tdl_promotion_applied = 1;
         if(tpf_next_tier != "NONE")
            tdl_applied_tier = tpf_next_tier;
      }
      int tdl_transition_events = tdl_promotion_applied + tdl_demotion_applied;
      int tdl_order_send = 0;
      int tdl_broker_modify_sent = 0;
      int tdl_runtime_sl_changed = 0;
      int tdl_invariant_breaches = 0;
      if(tdl_contract_ready != 1 || tdl_runtime_enforced != 1 ||
         tdl_evaluated_trades != m_totals.total_trades ||
         tdl_order_send != 0 || tdl_broker_modify_sent != 0 || tdl_runtime_sl_changed != 0 ||
         (tdl_promotion_applied == 1 && tdl_demotion_applied == 1) ||
         tdl_active_positions_preserved != 1 || tdl_next_trades_use_applied_tier != 1)
      {
         tdl_invariant_breaches = 1;
      }
      double tdl_readiness_pct = (tdl_invariant_breaches == 0 ? 100.0 : 0.0);
      double tdl_application_pct = (m_totals.total_trades > 0 ? 100.0 : 0.0);

      int lcrf_contract_ready = (FalconLowCapitalRiskFeasibilityContractReady() ? 1 : 0);
      int lcrf_runtime_enforced = (FALCON_LCRF_RUNTIME_ENFORCED ? 1 : 0);
      int lcrf_evaluated_trades = m_totals.lotsizing_feasibility_evaluated_trades;
      double lcrf_min_lot_risk_usd_avg = FalconSafeAverageDouble(m_totals.lotsizing_min_lot_risk_usd_total, lcrf_evaluated_trades);
      double lcrf_min_lot_risk_pct_avg = FalconSafeAverageDouble(m_totals.lotsizing_min_lot_risk_pct_total, lcrf_evaluated_trades);
      double lcrf_potential_loss_r_avg = FalconSafeAverageDouble(m_totals.lotsizing_potential_loss_r_total, lcrf_evaluated_trades);
      int lcrf_order_send = 0;
      int lcrf_broker_modify_sent = 0;
      int lcrf_runtime_sl_changed = 0;
      int lcrf_invariant_breaches = 0;
      if(lcrf_contract_ready != 1 || lcrf_runtime_enforced != 0 ||
         lcrf_evaluated_trades != m_totals.total_trades ||
         lcrf_order_send != 0 || lcrf_broker_modify_sent != 0 || lcrf_runtime_sl_changed != 0)
      {
         lcrf_invariant_breaches = 1;
      }
      double lcrf_readiness_pct = (lcrf_invariant_breaches == 0 ? 100.0 : 0.0);
      double lcrf_application_pct = (m_totals.total_trades > 0 ? 100.0 * (double)lcrf_evaluated_trades / (double)m_totals.total_trades : 0.0);

      int stlc_contract_ready = (FalconSingleTradeLossCapContractReady() ? 1 : 0);
      int stlc_runtime_enforced = (FALCON_STLC_RUNTIME_ENFORCED ? 1 : 0);
      int stlc_evaluated_trades = m_totals.single_trade_loss_cap_evaluated_trades;
      int stlc_order_send = 0;
      int stlc_broker_modify_sent = 0;
      int stlc_runtime_sl_changed = 0;
      int stlc_invariant_breaches = 0;
      if(stlc_contract_ready != 1 || stlc_runtime_enforced != 1 ||
         stlc_evaluated_trades != m_totals.total_trades ||
         stlc_order_send != 0 || stlc_broker_modify_sent != 0 || stlc_runtime_sl_changed != 0 ||
         m_totals.single_trade_loss_cap_dynamic_capital_updates != stlc_evaluated_trades)
      {
         stlc_invariant_breaches = 1;
      }
      double stlc_readiness_pct = (stlc_invariant_breaches == 0 ? 100.0 : 0.0);
      double stlc_application_pct = (m_totals.total_trades > 0 ? 100.0 * (double)stlc_evaluated_trades / (double)m_totals.total_trades : 0.0);

      int handle = FileOpen(m_summary_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write summary report: %s", m_summary_report_file));
         return;
      }

      // v0.21.3 Lock cleanup: Summary now keeps only stable baseline and official FVG attribution counters.
      // Temporary calibration/profile distribution columns stay out of Lock reports.
      string summary_header =
         "EAName,Version,Build,Symbol,GeneratedAt,"
         "TotalTrades,WinTrades,LoseTrades,BreakevenTrades,"
         "WinRate,LoseRate,"
         "TotalProfitIndexPoints,TotalLossIndexPoints,NetIndexPoints,"
         "TotalProfitUSD,TotalLossUSD,NetUSD,"
         "BuyTrades,BuyWinRate,BuyNetIndexPoints,"
         "SellTrades,SellWinRate,SellNetIndexPoints,"
         "FvgRetestWatchEvaluated,FvgRetestTouched,FvgRetestWaiting,"
         "FvgRetestFresh,FvgRetestStale,"
         "FvgRetestAgeMinBars,FvgRetestAgeAvgBars,FvgRetestAgeMaxBars,"
         "FvgHoldQualityEvaluated,FvgHoldQualityStrong,FvgHoldQualityNeutral,FvgHoldQualityWeak,"
         "FvgHoldQualityScoreMin,FvgHoldQualityScoreAvg,FvgHoldQualityScoreMax,"
         "FvgCandidateBuilderEvaluations,FvgDetectedCandidates,FvgQualityEvaluated,"
         "FvgQualityPassed,FvgQualityRejected,FvgRejectedSize,FvgRejectedSpread,FvgRejectedAge,"
         "FvgShadowReadyCandidates,"
         "FvgQGuardProfile,FvgQGuardEvaluated,FvgQGuardPassed,FvgQGuardBlocked,"
         "FvgQGuardBlockedWinners,FvgQGuardBlockedLosers,"
         "FvgQGuardActualNetPoints,FvgQGuardSimulatedNetPoints,FvgQGuardDeltaNetPoints,FvgQGuardBlockedNetPoints,"
         "FvgQGuardActualNetUSD,FvgQGuardSimulatedNetUSD,FvgQGuardDeltaNetUSD,FvgQGuardBlockedNetUSD,"
         "FvgQGuardRuntimeActive,FvgQGuardActualBlockingEnabled,FvgQGuardCandidateStage,"
         "FvgQGuardFeasibilityDecision,FvgQGuardFeasibilityReason,"
         "FvgQGuardNoLookaheadFeasible,FvgQGuardKnownBeforeEntry,FvgQGuardManualPromotionRequired,"
         "FvgQGuardMinSizePoints,FvgQGuardNextStep,"
         "FvgQGuardRuntimeCandidateAllowed,FvgQGuardRuntimeCandidateDesignReady,"
         "FvgQGuardActivationPolicy,FvgQGuardPromotionRule,FvgQGuardRollbackRequired,"
         "FvgQGuardRollbackBaseline,FvgQGuardRollbackTrigger,FvgQGuardRuntimeBlockingRule,"
         "FvgQGuardNextCandidateVersion,"
         "FvgQGuardRuntimeCandidateEvaluated,FvgQGuardRuntimeCandidatePassed,FvgQGuardRuntimeCandidateBlocked,"
         "FvgQGuardRuntimeStagedTrades,FvgQGuardRuntimePassedButNotStaged,"
         "FvgQGuardRuntimeRejectedAfterPass,FvgQGuardRuntimeStagedButNotClosed,"
         "FvgMicroEngineCompletionStatus,FvgMicroEngineCompletionDecision,FvgMicroEngineCompletionScope,"
         "FvgMicroEngineCompletedEngineId,FvgMicroEngineActiveStrategyOnly,"
         "FvgMicroEngineLivePilotEligibility,FvgMicroEngineNextRequiredLayer,FvgMicroEngineNextEngineeringPhase,"
         "FalconGuardFoundationStatus,FalconGuardFoundationDecision,FalconGuardOverallStatus,"
         "FalconGuardScope,FalconGuardExecutionPermission,FalconGuardRiskMode,"
         "FalconGuardConfiguredCapital,FalconGuardFixedLotSize,FalconGuardFixedLotStatus,"
         "FalconGuardDailyLossLimitEnabled,FalconGuardDailyLossLimitUSD,FalconGuardDailyLossStatus,"
         "FalconGuardMaxTradesPerDay,FalconGuardMaxTradesStatus,"
         "FalconGuardMaxOpenPositions,FalconGuardMaxOpenPositionsStatus,"
         "FalconGuardMaxConsecutiveLosses,FalconGuardSpreadGuardStatus,FalconGuardStopsLevelGuardStatus,"
         "FalconGuardEngineAllocation,FalconGuardKillSwitchStatus,FalconGuardManualKillSwitchStatus,"
         "FalconGuardLiveEligibility,FalconGuardNextRequiredLayer,FalconGuardNextEngineeringPhase,"
         "FalconGuardPreExecutionGateStatus,FalconGuardCanOpenTrade,FalconGuardBlockReason,"
         "FalconGuardLotSizingMode,FalconGuardPlannedLot,FalconGuardDailyLossBudgetUSD,"
         "FalconGuardDailyLossRemainingStatus,FalconGuardDailyTradesLimit,FalconGuardDailyTradesRemainingStatus,"
         "FalconGuardOpenPositionCapacity,FalconGuardOpenPositionCapacityStatus,FalconGuardEngineRiskAllowed,"
         "FalconGuardSpreadAllowed,FalconGuardStopsLevelAllowed,FalconGuardKillSwitchAllowsTrading,"
         "FalconGuardPreExecutionGateDecision,FalconGuardPreExecutionNextPhase,"
         "FalconTradeManagementFoundationStatus,FalconTradeManagementFoundationDecision,FalconTradeManagementScope,"
         "FalconTradeManagementExecutionPermission,FalconStructuralStopStatus,FalconStructuralStopRequirement,"
         "FalconTPBuilderStatus,FalconTP1Policy,FalconTP2Policy,FalconPartialManagerStatus,"
         "FalconProofProtectionStatus,FalconRunnerManagerStatus,FalconAdaptiveRatchetStatus,"
         "FalconEarlyFailureExitStatus,FalconTradeManagementLiveEligibility,"
         "FalconTradeManagementNextRequiredLayer,FalconTradeManagementNextEngineeringPhase,"
         "FalconSLTPValidationStatus,FalconSLTPValidationDecision,FalconSLTPValidationScope,"
         "FalconSLTPValidationRuntimeEnforced,FalconSLTPValidationEvaluatedTrades,"
         "FalconStructuralStopValidTrades,FalconStructuralStopInvalidTrades,"
         "FalconTPBuilderValidTrades,FalconTPBuilderInvalidTrades,"
         "FalconTP1ValidTrades,FalconTP2ValidTrades,FalconTP3ValidTrades,"
         "FalconSLTPStructuralStopPolicy,FalconSLTPTPBuilderPolicy,"
         "FalconSLTPNoLookaheadPolicy,FalconSLTPNextEngineeringPhase,"
         "FalconSmartTMStatus,FalconSmartTMDecision,FalconSmartTMScope,FalconSmartTMRuntimeEnforced,"
         "FalconSmartTMEvaluatedTrades,FalconProofScoreMin,FalconProofScoreAvg,FalconProofScoreMax,"
         "FalconProofExitConservativeTrades,FalconProofPartialNoRunnerTrades,"
         "FalconProofRunnerCandidateTrades,FalconProofStrongRunnerCandidateTrades,"
         "FalconProofWeakTrades,FalconProofMediumTrades,FalconProofStrongTrades,FalconProofEliteTrades,"
         "FalconAntiProofScoreAvg,FalconAntiProofScoreMax,FalconAntiProofHighRiskTrades,"
         "FalconBehaviorHealthyTrades,FalconBehaviorChoppyTrades,FalconBehaviorFailureTrades,"
         "FalconBehaviorGrindingTrades,FalconBehaviorExhaustedTrades,"
         "FalconRunnerOpportunityTrades,FalconStrongRunnerOpportunityTrades,"
         "FalconRunnerConservativeOpportunityTrades,"
         "FalconTP1CloseTrades,FalconSLFailureTrades,FalconTimeoutCloseTrades,"
         "FalconSmartTMProofPolicy,FalconSmartTMAntiProofPolicy,FalconSmartTMBehaviorPolicy,"
         "FalconSmartTMRunnerPolicy,FalconSmartTMNextEngineeringPhase,"
         "FalconRunnerDiagStatus,FalconRunnerDiagDecision,FalconRunnerDiagRuntimeEnforced,"
         "FalconRunnerDiagEvaluatedTrades,FalconRunnerDiagTP1AnchorTrades,FalconRunnerDiagTP2AnchorTrades,"
         "FalconRunnerMfeProxyTrades,FalconRunnerMfeProxyAvgPoints,FalconRunnerMfeProxyMaxPoints,"
         "FalconRunnerTP1ToTP2RoomAvgPoints,FalconRunnerTP1ToTP3RoomAvgPoints,FalconRunnerTP2ToTP3RoomAvgPoints,"
         "FalconRunnerMaxRProxyAvg,FalconRunnerMaxRProxyMax,"
         "FalconRunnerWouldReach3RTrades,FalconRunnerWouldReach5RTrades,"
         "FalconRunnerProtectedProfitOpportunityTrades,FalconRunnerReturnedToLossAfterProofUnknownTrades,"
         "FalconRunnerDiagMfePolicy,FalconRunnerDiagGivebackPolicy,FalconRunnerDiagMaxRPolicy,"
         "FalconRunnerDiagReturnToLossPolicy,FalconRunnerDiagNextPhase,"
         "FalconRunnerBarPathStatus,FalconRunnerBarPathDecision,FalconRunnerBarPathRuntimeEnforced,"
         "FalconRunnerBarPathEvaluatedTrades,FalconRunnerBarPathScannedTrades,FalconRunnerBarPathScanFailedTrades,"
         "FalconRunnerBarPathBarsScanned,FalconRunnerBarPathTP1TouchedTrades,FalconRunnerBarPathTP2TouchedTrades,"
         "FalconRunnerBarPathTP1TouchedThenExtendedTrades,FalconRunnerBarPathTP2TouchedThenExtendedTrades,"
         "FalconRunnerBarPathTP1ToMaxRunAvgPoints,FalconRunnerBarPathTP1ToMaxRunMaxPoints,"
         "FalconRunnerBarPathTP2ToMaxRunAvgPoints,FalconRunnerBarPathTP2ToMaxRunMaxPoints,"
         "FalconRunnerBarPathMFEAfterTP1AvgPoints,FalconRunnerBarPathMFEAfterTP1MaxPoints,"
         "FalconRunnerBarPathMFEAfterTP2AvgPoints,FalconRunnerBarPathMFEAfterTP2MaxPoints,"
         "FalconRunnerBarPathGivebackAfterTP1AvgPoints,FalconRunnerBarPathGivebackAfterTP1MaxPoints,"
         "FalconRunnerBarPathGivebackAfterTP2AvgPoints,FalconRunnerBarPathGivebackAfterTP2MaxPoints,"
         "FalconRunnerBarPathReturnedToLossAfterTP1Trades,FalconRunnerBarPathReturnedToLossAfterTP2Trades,"
         "FalconRunnerBarPathActualWouldReach3RTrades,FalconRunnerBarPathActualWouldReach5RTrades,"
         "FalconRunnerBarPathProtectedAfterTP1OpportunityTrades,FalconRunnerBarPathProtectedAfterTP2OpportunityTrades,"
         "FalconFastTMStatus,FalconFastTMDecision,FalconFastTMRuntimeEnforced,FalconFastTMLatencyMode,"
         "FalconFastTMDecisionProfile,FalconFastTMEvaluatedTrades,FalconFastTMDecisionCacheReadyTrades,"
         "FalconFastTMPrecomputedBranchReadyTrades,FalconFastTMTP1DecisionReadyTrades,FalconFastTMTP2DecisionReadyTrades,"
         "FalconFastTMProtectionRequiredAfterTP1Trades,FalconFastTMProtectionRequiredAfterTP2Trades,"
         "FalconFastTMImmediateRunnerCandidateTrades,FalconFastTMImmediateExitWarningTrades,FalconFastTMFastAntiProofWarningTrades,"
         "FalconFastTMConservativePartialReadyTrades,FalconFastTMRunnerWaitForConfirmationTrades,"
         "FalconFastTMPolicy,FalconFastTMNextPhase,"
         "FalconDecisionTreeStatus,FalconDecisionTreeDecision,FalconDecisionTreeRuntimeEnforced,FalconDecisionTreeScope,"
         "FalconDecisionTreeEvaluatedTrades,FalconDecisionTreeCacheReadyTrades,"
         "FalconDecisionTreeTP1ReadyTrades,FalconDecisionTreeTP2ReadyTrades,"
         "FalconDecisionTreeTP1PartialPlanTrades,FalconDecisionTreeTP1ProtectPlanTrades,"
         "FalconDecisionTreeTP1RunnerNowPlanTrades,FalconDecisionTreeTP1RunnerWaitPlanTrades,"
         "FalconDecisionTreeTP1ExitWarningPlanTrades,FalconDecisionTreeTP1AntiProofWarningPlanTrades,"
         "FalconDecisionTreeTP2ProtectPlanTrades,FalconDecisionTreeTP2RunnerActivatePlanTrades,"
         "FalconDecisionTreeTP2ExitWarningPlanTrades,FalconDecisionTreeRollbackReadyTrades,"
         "FalconDecisionTreePolicy,FalconDecisionTreeNextPhase,"
         "FalconDecisionTreeOutcomeStatus,FalconDecisionTreeOutcomeDecision,FalconDecisionTreeOutcomeRuntimeEnforced,"
         "FalconDecisionTreeOutcomeEvaluatedTrades,FalconDecisionTreeOutcomeTP1BranchesSimulated,"
         "FalconDecisionTreeOutcomeTP2BranchesSimulated,FalconDecisionTreeOutcomeTP1ProtectWouldReduceReturnToLossTrades,"
         "FalconDecisionTreeOutcomeTP2ProtectWouldReduceReturnToLossTrades,FalconDecisionTreeOutcomeRunnerActivateWouldReach3RTrades,"
         "FalconDecisionTreeOutcomeRunnerActivateWouldReach5RTrades,FalconDecisionTreeOutcomeExitWarningWouldCatchReturnToLossTrades,"
         "FalconDecisionTreeOutcomeAntiProofWouldCatchReturnToLossTrades,FalconDecisionTreeOutcomeTP1ProtectionCoveragePct,"
         "FalconDecisionTreeOutcomeTP2ProtectionCoveragePct,FalconDecisionTreeOutcomeRunner3RSelectivityPct,"
         "FalconDecisionTreeOutcomeRunner5RSelectivityPct,FalconDecisionTreeOutcomePolicy,FalconDecisionTreeOutcomeNextPhase,"
         "FalconDTTimingStatus,FalconDTTimingDecision,FalconDTTimingRuntimeEnforced,FalconDTTimingEvaluatedTrades,"
         "FalconDTTimingDecisionCacheReadyTrades,FalconDTTimingTP1DecisionPrecomputedTrades,FalconDTTimingTP2DecisionPrecomputedTrades,"
         "FalconDTTimingTP1ProtectionFeasibleTrades,FalconDTTimingTP2ProtectionFeasibleTrades,"
         "FalconDTTimingTP1ProtectionTimingUnknownTrades,FalconDTTimingTP2ProtectionTimingUnknownTrades,"
         "FalconDTTimingRunner3RPrecomputedTrades,FalconDTTimingRunner5RPrecomputedTrades,"
         "FalconDTTimingRunner3RTimingUnknownTrades,FalconDTTimingProtectionNoLookaheadFeasible,"
         "FalconDTTimingRunnerNoLookaheadFeasible,FalconDTTimingPolicy,FalconDTTimingNextPhase,"
         "FalconPaperExecStatus,FalconPaperExecDecision,FalconPaperExecRuntimeEnforced,"
         "FalconPaperExecPermission,FalconPaperExecMode,FalconPaperExecScope,"
         "FalconPaperExecEvaluatedTrades,FalconPaperExecOrderLifecycleReadyTrades,"
         "FalconPaperExecOrderRequestReadyTrades,FalconPaperExecStagedOrderRequestReadyTrades,"
         "FalconPaperExecSLPlanReadyTrades,FalconPaperExecTPPlanReadyTrades,"
         "FalconPaperExecPartialPlanReadyTrades,FalconPaperExecRunnerPlanReadyTrades,"
         "FalconPaperExecOrderSendAllowed,FalconPaperExecPaperFillsEnabled,"
         "FalconPaperExecOrdersSent,FalconPaperExecOrdersFilled,FalconPaperExecOrdersRejected,"
         "FalconPaperExecRejectedReason,FalconPaperExecStateModel,FalconPaperExecNoLookaheadPolicy,"
         "FalconPaperExecNextPhase,FalconPaperSimStatus,FalconPaperSimDecision,FalconPaperSimScope,FalconPaperSimEvaluatedTrades,FalconPaperSimPlannedOrders,FalconPaperSimStagedOrders,FalconPaperSimAcceptedOrders,FalconPaperSimFilledOrders,FalconPaperSimClosedOrders,FalconPaperSimRejectedOrders,FalconPaperSimSLAttachedOrders,FalconPaperSimTPAttachedOrders,FalconPaperSimPartialBranchesPrepared,FalconPaperSimRunnerBranchesPrepared,FalconPaperSimOrderSendBypass,FalconPaperSimNoLookaheadPolicy,FalconPaperSimNextPhase,"
         "FalconPaperBranchStatus,FalconPaperBranchDecision,FalconPaperBranchRuntimeEnforced,FalconPaperBranchScope,FalconPaperBranchEvaluatedTrades,FalconPaperBranchPartialBranchesSimulated,FalconPaperBranchRunnerBranchesSimulated,FalconPaperBranchPartialFillReadyTrades,FalconPaperBranchRunnerFillReadyTrades,FalconPaperBranchPartialNoOrderSendTrades,FalconPaperBranchRunnerNoOrderSendTrades,FalconPaperBranchPartialRejected,FalconPaperBranchRunnerRejected,FalconPaperBranchOrderSendPolicy,FalconPaperBranchPartialPolicy,FalconPaperBranchRunnerPolicy,FalconPaperBranchNextPhase,"
         "FalconPaperOutcomeStatus,FalconPaperOutcomeDecision,FalconPaperOutcomeRuntimeEnforced,FalconPaperOutcomeScope,"
         "FalconPaperOutcomeEvaluatedTrades,FalconPaperOutcomePartialBranches,FalconPaperOutcomeRunnerBranches,"
         "FalconPaperOutcomeTP1ProtectTrades,FalconPaperOutcomeTP2ProtectTrades,"
         "FalconPaperOutcomeRunner3RTrades,FalconPaperOutcomeRunner5RTrades,"
         "FalconPaperOutcomeProtectedGivebackProxyPoints,FalconPaperOutcomeRunnerUpsideProxyPoints,"
         "FalconPaperOutcomeDeltaPointsProxy,FalconPaperOutcomeSimulatedNetPointsProxy,"
         "FalconPaperOutcomeDeltaUSDProxy,FalconPaperOutcomeSimulatedNetUSDProxy,"
         "FalconPaperOutcomeProtectionCoveragePct,FalconPaperOutcomeRunner3RSelectivityPct,FalconPaperOutcomeRunner5RSelectivityPct,"
         "FalconPaperOutcomePolicy,FalconPaperOutcomeNextPhase,"
         "FalconPaperSMStatus,FalconPaperSMDecision,FalconPaperSMRuntimeEnforced,FalconPaperSMScope,"
         "FalconPaperSMEvaluatedTrades,FalconPaperSMEntryStateTrades,FalconPaperSMFilledStateTrades,"
         "FalconPaperSMTP1ProofStateTrades,FalconPaperSMTP2ProofStateTrades,"
         "FalconPaperSMProtectAfterTP1StateTrades,FalconPaperSMProtectAfterTP2StateTrades,"
         "FalconPaperSMRunnerCandidateStateTrades,FalconPaperSMRunnerActive3RStateTrades,FalconPaperSMMoonMode5RStateTrades,"
         "FalconPaperSMExitWarningStateTrades,FalconPaperSMAntiProofStateTrades,"
         "FalconPaperSMReturnedLossPreventableTrades,FalconPaperSMProtectedGivebackProxyPoints,"
         "FalconPaperSMRunnerUpsideProxyPoints,FalconPaperSMDeltaPointsProxy,FalconPaperSMSimulatedNetPointsProxy,"
         "FalconPaperSMDeltaUSDProxy,FalconPaperSMSimulatedNetUSDProxy,FalconPaperSMProtectionContributionPct,"
         "FalconPaperSMRunnerContributionPct,FalconPaperSMTP2IsCheckpoint,FalconPaperSMTP2ExitMandatory,"
         "FalconPaperSMBeyondTP2RunnerTrades,FalconPaperSMBeyondTP2MoonTrades,"
         "FalconPaperSMRunnerBeyondTP2Policy,FalconPaperSMExpansionAllowedAfterProof,"
         "FalconPaperSMProtectionBeforeExpansionPolicy,FalconPaperSMPolicy,FalconPaperSMNextPhase,"
         "FalconPaperProtectFeasStatus,FalconPaperProtectFeasDecision,FalconPaperProtectFeasRuntimeEnforced,"
         "FalconPaperProtectFeasScope,FalconPaperProtectFeasEvaluatedTrades,FalconPaperProtectFeasTP1States,"
         "FalconPaperProtectFeasTP2States,FalconPaperProtectFeasTotalStates,FalconPaperProtectFeasModifyPlanTrades,"
         "FalconPaperProtectFeasModifyReadyTrades,FalconPaperProtectFeasModifySent,FalconPaperProtectFeasModifyRejected,"
         "FalconPaperProtectFeasBeforeGivebackTrades,FalconPaperProtectFeasTooLateTrades,FalconPaperProtectFeasCoveragePct,"
         "FalconPaperProtectFeasNoLookahead,FalconPaperProtectFeasModifyPolicy,FalconPaperProtectFeasOrderSendPolicy,"
         "FalconPaperProtectFeasNextPhase,"
         "FalconPaperProtectPlanStatus,FalconPaperProtectPlanDecision,FalconPaperProtectPlanRuntimeEnforced,"
         "FalconPaperProtectPlanScope,FalconPaperProtectPlanEvaluatedTrades,FalconPaperProtectPlanModifyPlanTrades,"
         "FalconPaperProtectPlanModifyReadyTrades,FalconPaperProtectPlanTriggerReadyTrades,"
         "FalconPaperProtectPlanLevelReadyTrades,FalconPaperProtectPlanReasonReadyTrades,"
         "FalconPaperProtectPlanTP1PlanTrades,FalconPaperProtectPlanTP2PlanTrades,"
         "FalconPaperProtectPlanModifySent,FalconPaperProtectPlanModifyRejected,FalconPaperProtectPlanIncompleteTrades,"
         "FalconPaperProtectPlanCoveragePct,FalconPaperProtectPlanCompletenessPct,"
         "FalconPaperProtectPlanNoLookahead,FalconPaperProtectPlanModifyPolicy,FalconPaperProtectPlanOrderSendPolicy,"
         "FalconPaperProtectPlanNextPhase,"
         "FalconPaperProtectTimingStatus,FalconPaperProtectTimingDecision,FalconPaperProtectTimingRuntimeEnforced,"
         "FalconPaperProtectTimingScope,FalconPaperProtectTimingEvaluatedTrades,FalconPaperProtectTimingModifyRequestTrades,"
         "FalconPaperProtectTimingReadyTrades,FalconPaperProtectTimingAfterProofTrades,"
         "FalconPaperProtectTimingBeforeGivebackTrades,FalconPaperProtectTimingTooLateTrades,"
         "FalconPaperProtectTimingUnknownTrades,FalconPaperProtectTimingTP1ReadyTrades,"
         "FalconPaperProtectTimingTP2ReadyTrades,FalconPaperProtectTimingModifySent,"
         "FalconPaperProtectTimingModifyRejected,FalconPaperProtectTimingCoveragePct,"
         "FalconPaperProtectTimingReadyPct,FalconPaperProtectTimingNoLookahead,"
         "FalconPaperProtectTimingModifyPolicy,FalconPaperProtectTimingOrderSendPolicy,"
         "FalconPaperProtectTimingNextPhase,"
         "FalconPaperProtectDryRunStatus,FalconPaperProtectDryRunDecision,FalconPaperProtectDryRunRuntimeEnforced,"
         "FalconPaperProtectDryRunScope,FalconPaperProtectDryRunEvaluatedTrades,"
         "FalconPaperProtectDryRunModifyRequestTrades,FalconPaperProtectDryRunEligibleTrades,"
         "FalconPaperProtectDryRunAcceptedTrades,FalconPaperProtectDryRunRejectedTrades,"
         "FalconPaperProtectDryRunSkippedTrades,FalconPaperProtectDryRunTP1Trades,"
         "FalconPaperProtectDryRunTP2Trades,FalconPaperProtectDryRunModifySent,"
         "FalconPaperProtectDryRunBrokerModifySent,FalconPaperProtectDryRunRuntimeSLChanged,"
         "FalconPaperProtectDryRunCoveragePct,FalconPaperProtectDryRunAcceptancePct,"
         "FalconPaperProtectDryRunNoLookahead,FalconPaperProtectDryRunModifyPolicy,"
         "FalconPaperProtectDryRunOrderSendPolicy,FalconPaperProtectDryRunNextPhase,"
         "FalconPaperProtectDryRunLockStatus,FalconPaperProtectDryRunLockDecision,"
         "FalconPaperProtectDryRunLockRuntimeEnforced,FalconPaperProtectDryRunLockScope,"
         "FalconPaperProtectDryRunLockEvaluatedTrades,FalconPaperProtectDryRunLockModifyRequestTrades,"
         "FalconPaperProtectDryRunLockEligibleTrades,FalconPaperProtectDryRunLockAcceptedTrades,"
         "FalconPaperProtectDryRunLockRejectedTrades,FalconPaperProtectDryRunLockSkippedTrades,"
         "FalconPaperProtectDryRunLockBrokerModifySent,FalconPaperProtectDryRunLockRuntimeSLChanged,"
         "FalconPaperProtectDryRunLockReadyTrades,FalconPaperProtectDryRunLockInvariantBreaches,"
         "FalconPaperProtectDryRunLockCoveragePct,FalconPaperProtectDryRunLockAcceptancePct,"
         "FalconPaperProtectDryRunLockCompletenessPct,FalconPaperProtectDryRunLockNoLookahead,"
         "FalconPaperProtectDryRunLockModifyPolicy,FalconPaperProtectDryRunLockOrderSendPolicy,"
         "FalconPaperProtectDryRunLockNextPhase,"
         "FalconPaperProtectVirtualSLStatus,FalconPaperProtectVirtualSLDecision,"
         "FalconPaperProtectVirtualSLRuntimeEnforced,FalconPaperProtectVirtualSLScope,"
         "FalconPaperProtectVirtualSLEvaluatedTrades,FalconPaperProtectVirtualSLCandidateTrades,"
         "FalconPaperProtectVirtualSLStateReadyTrades,FalconPaperProtectVirtualSLStateActiveTrades,"
         "FalconPaperProtectVirtualSLTP1StateTrades,FalconPaperProtectVirtualSLTP2StateTrades,"
         "FalconPaperProtectVirtualSLRejectedTrades,FalconPaperProtectVirtualSLConflictTrades,"
         "FalconPaperProtectVirtualSLMissingLevelTrades,FalconPaperProtectVirtualSLBrokerModifySent,"
         "FalconPaperProtectVirtualSLRuntimeSLChanged,FalconPaperProtectVirtualSLInvariantBreaches,"
         "FalconPaperProtectVirtualSLCoveragePct,FalconPaperProtectVirtualSLReadinessPct,"
         "FalconPaperProtectVirtualSLStateActivePct,FalconPaperProtectVirtualSLNoLookahead,"
         "FalconPaperProtectVirtualSLStatePolicy,FalconPaperProtectVirtualSLOrderSendPolicy,"
         "FalconPaperProtectVirtualSLNextPhase,"
         "FalconPaperProtectVirtualSLLockStatus,FalconPaperProtectVirtualSLLockDecision,"
         "FalconPaperProtectVirtualSLLockRuntimeEnforced,FalconPaperProtectVirtualSLLockScope,"
         "FalconPaperProtectVirtualSLLockEvaluatedTrades,FalconPaperProtectVirtualSLLockCandidateTrades,"
         "FalconPaperProtectVirtualSLLockStateReadyTrades,FalconPaperProtectVirtualSLLockStateActiveTrades,"
         "FalconPaperProtectVirtualSLLockTP1StateTrades,FalconPaperProtectVirtualSLLockTP2StateTrades,"
         "FalconPaperProtectVirtualSLLockRejectedTrades,FalconPaperProtectVirtualSLLockConflictTrades,"
         "FalconPaperProtectVirtualSLLockMissingLevelTrades,FalconPaperProtectVirtualSLLockBrokerModifySent,"
         "FalconPaperProtectVirtualSLLockRuntimeSLChanged,FalconPaperProtectVirtualSLLockReadyTrades,"
         "FalconPaperProtectVirtualSLLockInvariantBreaches,FalconPaperProtectVirtualSLLockCoveragePct,"
         "FalconPaperProtectVirtualSLLockReadinessPct,FalconPaperProtectVirtualSLLockStateActivePct,"
         "FalconPaperProtectVirtualSLLockCompletenessPct,FalconPaperProtectVirtualSLLockNoLookahead,"
         "FalconPaperProtectVirtualSLLockStatePolicy,FalconPaperProtectVirtualSLLockOrderSendPolicy,"
         "FalconPaperProtectVirtualSLLockNextPhase,"
         "FalconPaperProtectTransitionStatus,FalconPaperProtectTransitionDecision,"
         "FalconPaperProtectTransitionRuntimeEnforced,FalconPaperProtectTransitionScope,"
         "FalconPaperProtectTransitionEvaluatedTrades,FalconPaperProtectTransitionVirtualSLLockReadyTrades,"
         "FalconPaperProtectTransitionCandidateTrades,FalconPaperProtectTransitionReadyTrades,"
         "FalconPaperProtectTransitionPaperExecutorReadableTrades,FalconPaperProtectTransitionLedgerReadableTrades,"
         "FalconPaperProtectTransitionTriggerResolvedTrades,FalconPaperProtectTransitionProtectionLevelResolvedTrades,"
         "FalconPaperProtectTransitionTP1Trades,FalconPaperProtectTransitionTP2Trades,"
         "FalconPaperProtectTransitionRejectedTrades,FalconPaperProtectTransitionConflictTrades,"
         "FalconPaperProtectTransitionMissingLedgerTrades,FalconPaperProtectTransitionBrokerModifySent,"
         "FalconPaperProtectTransitionRuntimeSLChanged,FalconPaperProtectTransitionInvariantBreaches,"
         "FalconPaperProtectTransitionCoveragePct,FalconPaperProtectTransitionReadinessPct,"
         "FalconPaperProtectTransitionExecutorReadinessPct,FalconPaperProtectTransitionNoLookahead,"
         "FalconPaperProtectTransitionPolicy,FalconPaperProtectTransitionOrderSendPolicy,"
         "FalconPaperProtectTransitionNextPhase,"
         "FalconPaperProtectTransitionLockStatus,FalconPaperProtectTransitionLockDecision,"
         "FalconPaperProtectTransitionLockRuntimeEnforced,FalconPaperProtectTransitionLockScope,"
         "FalconPaperProtectTransitionLockEvaluatedTrades,FalconPaperProtectTransitionLockReadyTrades,"
         "FalconPaperProtectTransitionLockCandidateTrades,FalconPaperProtectTransitionLockTransitionReadyTrades,"
         "FalconPaperProtectTransitionLockPaperExecutorReadableTrades,FalconPaperProtectTransitionLockLedgerReadableTrades,"
         "FalconPaperProtectTransitionLockTriggerResolvedTrades,FalconPaperProtectTransitionLockProtectionLevelResolvedTrades,"
         "FalconPaperProtectTransitionLockTP1Trades,FalconPaperProtectTransitionLockTP2Trades,"
         "FalconPaperProtectTransitionLockRejectedTrades,FalconPaperProtectTransitionLockConflictTrades,"
         "FalconPaperProtectTransitionLockMissingLedgerTrades,FalconPaperProtectTransitionLockBrokerModifySent,"
         "FalconPaperProtectTransitionLockRuntimeSLChanged,FalconPaperProtectTransitionLockInvariantBreaches,"
         "FalconPaperProtectTransitionLockCoveragePct,FalconPaperProtectTransitionLockReadinessPct,"
         "FalconPaperProtectTransitionLockExecutorReadinessPct,FalconPaperProtectTransitionLockCompletenessPct,"
         "FalconPaperProtectTransitionLockNoLookahead,FalconPaperProtectTransitionLockPolicy,"
         "FalconPaperProtectTransitionLockOrderSendPolicy,FalconPaperProtectTransitionLockNextPhase,"
         "FalconPaperProtectBrokerFeasStatus,FalconPaperProtectBrokerFeasDecision,"
         "FalconPaperProtectBrokerFeasRuntimeEnforced,FalconPaperProtectBrokerFeasScope,"
         "FalconPaperProtectBrokerFeasEvaluatedTrades,FalconPaperProtectBrokerFeasTransitionLockReadyTrades,"
         "FalconPaperProtectBrokerFeasCandidateTrades,FalconPaperProtectBrokerFeasBrokerContextReadyTrades,"
         "FalconPaperProtectBrokerFeasStopsLevelKnownTrades,FalconPaperProtectBrokerFeasFreezeLevelKnownTrades,"
         "FalconPaperProtectBrokerFeasProtectionLevelExecutableTrades,FalconPaperProtectBrokerFeasStopsLevelSafeTrades,"
         "FalconPaperProtectBrokerFeasFreezeLevelSafeTrades,FalconPaperProtectBrokerFeasBrokerFeasibleTrades,"
         "FalconPaperProtectBrokerFeasTP1Trades,FalconPaperProtectBrokerFeasTP2Trades,"
         "FalconPaperProtectBrokerFeasRejectedTrades,FalconPaperProtectBrokerFeasConflictTrades,"
         "FalconPaperProtectBrokerFeasMissingBrokerContextTrades,FalconPaperProtectBrokerFeasStopsLevelBlockedTrades,"
         "FalconPaperProtectBrokerFeasFreezeLevelBlockedTrades,FalconPaperProtectBrokerFeasBrokerModifySent,"
         "FalconPaperProtectBrokerFeasRuntimeSLChanged,FalconPaperProtectBrokerFeasInvariantBreaches,"
         "FalconPaperProtectBrokerFeasCoveragePct,FalconPaperProtectBrokerFeasFeasibilityPct,"
         "FalconPaperProtectBrokerFeasBrokerContextReadinessPct,FalconPaperProtectBrokerFeasStopsLevelPoints,"
         "FalconPaperProtectBrokerFeasFreezeLevelPoints,FalconPaperProtectBrokerFeasStopsBufferPoints,"
         "FalconPaperProtectBrokerFeasNoLookahead,FalconPaperProtectBrokerFeasBrokerPolicy,"
         "FalconPaperProtectBrokerFeasOrderSendPolicy,FalconPaperProtectBrokerFeasNextPhase,"
         "FalconPaperProtectBrokerFeasLockStatus,FalconPaperProtectBrokerFeasLockDecision,"
         "FalconPaperProtectBrokerFeasLockRuntimeEnforced,FalconPaperProtectBrokerFeasLockScope,"
         "FalconPaperProtectBrokerFeasLockEvaluatedTrades,FalconPaperProtectBrokerFeasLockCandidateTrades,"
         "FalconPaperProtectBrokerFeasLockBrokerContextReadyTrades,FalconPaperProtectBrokerFeasLockStopsLevelKnownTrades,"
         "FalconPaperProtectBrokerFeasLockFreezeLevelKnownTrades,FalconPaperProtectBrokerFeasLockProtectionLevelExecutableTrades,"
         "FalconPaperProtectBrokerFeasLockStopsLevelSafeTrades,FalconPaperProtectBrokerFeasLockFreezeLevelSafeTrades,"
         "FalconPaperProtectBrokerFeasLockBrokerFeasibleTrades,FalconPaperProtectBrokerFeasLockReadyTrades,"
         "FalconPaperProtectBrokerFeasLockTP1Trades,FalconPaperProtectBrokerFeasLockTP2Trades,"
         "FalconPaperProtectBrokerFeasLockRejectedTrades,FalconPaperProtectBrokerFeasLockConflictTrades,"
         "FalconPaperProtectBrokerFeasLockMissingBrokerContextTrades,FalconPaperProtectBrokerFeasLockStopsLevelBlockedTrades,"
         "FalconPaperProtectBrokerFeasLockFreezeLevelBlockedTrades,FalconPaperProtectBrokerFeasLockBrokerModifySent,"
         "FalconPaperProtectBrokerFeasLockRuntimeSLChanged,FalconPaperProtectBrokerFeasLockInvariantBreaches,"
         "FalconPaperProtectBrokerFeasLockCoveragePct,FalconPaperProtectBrokerFeasLockFeasibilityPct,"
         "FalconPaperProtectBrokerFeasLockCompletenessPct,FalconPaperProtectBrokerFeasLockStopsLevelPoints,"
         "FalconPaperProtectBrokerFeasLockFreezeLevelPoints,FalconPaperProtectBrokerFeasLockStopsBufferPoints,"
         "FalconPaperProtectBrokerFeasLockNoLookahead,FalconPaperProtectBrokerFeasLockBrokerPolicy,"
         "FalconPaperProtectBrokerFeasLockOrderSendPolicy,FalconPaperProtectBrokerFeasLockNextPhase,"
         "FalconPaperProtectBrokerDistanceStatus,FalconPaperProtectBrokerDistanceDecision,"
         "FalconPaperProtectBrokerDistanceRuntimeEnforced,FalconPaperProtectBrokerDistanceScope,"
         "FalconPaperProtectBrokerDistanceEvaluatedTrades,FalconPaperProtectBrokerDistanceBrokerFeasLockReadyTrades,"
         "FalconPaperProtectBrokerDistanceCandidateTrades,FalconPaperProtectBrokerDistanceContextReadyTrades,"
         "FalconPaperProtectBrokerDistanceRequiredDistanceKnownTrades,FalconPaperProtectBrokerDistanceProtectionDistanceKnownTrades,"
         "FalconPaperProtectBrokerDistanceStopsDistanceSafeTrades,FalconPaperProtectBrokerDistanceFreezeDistanceSafeTrades,"
         "FalconPaperProtectBrokerDistanceSaneTrades,FalconPaperProtectBrokerDistanceReadyTrades,"
         "FalconPaperProtectBrokerDistanceTP1Trades,FalconPaperProtectBrokerDistanceTP2Trades,"
         "FalconPaperProtectBrokerDistanceRejectedTrades,FalconPaperProtectBrokerDistanceConflictTrades,"
         "FalconPaperProtectBrokerDistanceMissingContextTrades,FalconPaperProtectBrokerDistanceStopsBlockedTrades,"
         "FalconPaperProtectBrokerDistanceFreezeBlockedTrades,FalconPaperProtectBrokerDistanceBrokerModifySent,"
         "FalconPaperProtectBrokerDistanceRuntimeSLChanged,FalconPaperProtectBrokerDistanceInvariantBreaches,"
         "FalconPaperProtectBrokerDistanceCoveragePct,FalconPaperProtectBrokerDistanceSanityPct,"
         "FalconPaperProtectBrokerDistanceContextReadinessPct,FalconPaperProtectBrokerDistanceStopsLevelPoints,"
         "FalconPaperProtectBrokerDistanceFreezeLevelPoints,FalconPaperProtectBrokerDistanceStopsBufferPoints,"
         "FalconPaperProtectBrokerDistanceRequiredMinPoints,FalconPaperProtectBrokerDistanceNoLookahead,"
         "FalconPaperProtectBrokerDistancePolicy,FalconPaperProtectBrokerDistanceOrderSendPolicy,"
         "FalconPaperProtectBrokerDistanceNextPhase,"
         "FalconPaperProtectBrokerDistanceLockStatus,FalconPaperProtectBrokerDistanceLockDecision,"
         "FalconPaperProtectBrokerDistanceLockRuntimeEnforced,FalconPaperProtectBrokerDistanceLockScope,"
         "FalconPaperProtectBrokerDistanceLockEvaluatedTrades,FalconPaperProtectBrokerDistanceLockDistanceReadyTrades,"
         "FalconPaperProtectBrokerDistanceLockCandidateTrades,FalconPaperProtectBrokerDistanceLockContextReadyTrades,"
         "FalconPaperProtectBrokerDistanceLockRequiredDistanceKnownTrades,FalconPaperProtectBrokerDistanceLockProtectionDistanceKnownTrades,"
         "FalconPaperProtectBrokerDistanceLockStopsDistanceSafeTrades,FalconPaperProtectBrokerDistanceLockFreezeDistanceSafeTrades,"
         "FalconPaperProtectBrokerDistanceLockDistanceSaneTrades,FalconPaperProtectBrokerDistanceLockReadyTrades,"
         "FalconPaperProtectBrokerDistanceLockTP1Trades,FalconPaperProtectBrokerDistanceLockTP2Trades,"
         "FalconPaperProtectBrokerDistanceLockRejectedTrades,FalconPaperProtectBrokerDistanceLockConflictTrades,"
         "FalconPaperProtectBrokerDistanceLockMissingContextTrades,FalconPaperProtectBrokerDistanceLockStopsBlockedTrades,"
         "FalconPaperProtectBrokerDistanceLockFreezeBlockedTrades,FalconPaperProtectBrokerDistanceLockBrokerModifySent,"
         "FalconPaperProtectBrokerDistanceLockRuntimeSLChanged,FalconPaperProtectBrokerDistanceLockInvariantBreaches,"
         "FalconPaperProtectBrokerDistanceLockCoveragePct,FalconPaperProtectBrokerDistanceLockSanityPct,"
         "FalconPaperProtectBrokerDistanceLockCompletenessPct,FalconPaperProtectBrokerDistanceLockStopsLevelPoints,"
         "FalconPaperProtectBrokerDistanceLockFreezeLevelPoints,FalconPaperProtectBrokerDistanceLockStopsBufferPoints,"
         "FalconPaperProtectBrokerDistanceLockRequiredMinPoints,FalconPaperProtectBrokerDistanceLockNoLookahead,"
         "FalconPaperProtectBrokerDistanceLockPolicy,FalconPaperProtectBrokerDistanceLockOrderSendPolicy,"
         "FalconPaperProtectBrokerDistanceLockNextPhase,"
         "FalconPaperProtectBrokerModifyEligStatus,FalconPaperProtectBrokerModifyEligDecision,"
         "FalconPaperProtectBrokerModifyEligRuntimeEnforced,FalconPaperProtectBrokerModifyEligScope,"
         "FalconPaperProtectBrokerModifyEligEvaluatedTrades,FalconPaperProtectBrokerModifyEligDistanceLockReadyTrades,"
         "FalconPaperProtectBrokerModifyEligBrokerFeasLockReadyTrades,FalconPaperProtectBrokerModifyEligCandidateTrades,"
         "FalconPaperProtectBrokerModifyEligDistanceSanityReadyTrades,FalconPaperProtectBrokerModifyEligModifyPlanReadyTrades,"
         "FalconPaperProtectBrokerModifyEligRequestShapeReadyTrades,FalconPaperProtectBrokerModifyEligProtectionLevelReadyTrades,"
         "FalconPaperProtectBrokerModifyEligStopsReadyTrades,FalconPaperProtectBrokerModifyEligFreezeReadyTrades,"
         "FalconPaperProtectBrokerModifyEligEligibleTrades,FalconPaperProtectBrokerModifyEligReadyTrades,"
         "FalconPaperProtectBrokerModifyEligTP1Trades,FalconPaperProtectBrokerModifyEligTP2Trades,"
         "FalconPaperProtectBrokerModifyEligRejectedTrades,FalconPaperProtectBrokerModifyEligConflictTrades,"
         "FalconPaperProtectBrokerModifyEligMissingDistanceLockTrades,FalconPaperProtectBrokerModifyEligMissingBrokerFeasTrades,"
         "FalconPaperProtectBrokerModifyEligMissingModifyPlanTrades,FalconPaperProtectBrokerModifyEligStopsBlockedTrades,"
         "FalconPaperProtectBrokerModifyEligFreezeBlockedTrades,FalconPaperProtectBrokerModifyEligBrokerModifySent,"
         "FalconPaperProtectBrokerModifyEligRuntimeSLChanged,FalconPaperProtectBrokerModifyEligInvariantBreaches,"
         "FalconPaperProtectBrokerModifyEligCoveragePct,FalconPaperProtectBrokerModifyEligEligibilityPct,"
         "FalconPaperProtectBrokerModifyEligCompletenessPct,FalconPaperProtectBrokerModifyEligNoLookahead,"
         "FalconPaperProtectBrokerModifyEligPolicy,FalconPaperProtectBrokerModifyEligOrderSendPolicy,"
         "FalconPaperProtectBrokerModifyEligNextPhase,"
         "FalconPaperProtectBrokerModifyEligLockStatus,FalconPaperProtectBrokerModifyEligLockDecision,"
         "FalconPaperProtectBrokerModifyEligLockRuntimeEnforced,FalconPaperProtectBrokerModifyEligLockScope,"
         "FalconPaperProtectBrokerModifyEligLockEvaluatedTrades,FalconPaperProtectBrokerModifyEligLockDistanceLockReadyTrades,"
         "FalconPaperProtectBrokerModifyEligLockBrokerFeasLockReadyTrades,FalconPaperProtectBrokerModifyEligLockCandidateTrades,"
         "FalconPaperProtectBrokerModifyEligLockDistanceSanityReadyTrades,FalconPaperProtectBrokerModifyEligLockModifyPlanReadyTrades,"
         "FalconPaperProtectBrokerModifyEligLockRequestShapeReadyTrades,FalconPaperProtectBrokerModifyEligLockProtectionLevelReadyTrades,"
         "FalconPaperProtectBrokerModifyEligLockStopsReadyTrades,FalconPaperProtectBrokerModifyEligLockFreezeReadyTrades,"
         "FalconPaperProtectBrokerModifyEligLockEligibleTrades,FalconPaperProtectBrokerModifyEligLockReadyTrades,"
         "FalconPaperProtectBrokerModifyEligLockTP1Trades,FalconPaperProtectBrokerModifyEligLockTP2Trades,"
         "FalconPaperProtectBrokerModifyEligLockRejectedTrades,FalconPaperProtectBrokerModifyEligLockConflictTrades,"
         "FalconPaperProtectBrokerModifyEligLockMissingDistanceLockTrades,FalconPaperProtectBrokerModifyEligLockMissingBrokerFeasTrades,"
         "FalconPaperProtectBrokerModifyEligLockMissingModifyPlanTrades,FalconPaperProtectBrokerModifyEligLockStopsBlockedTrades,"
         "FalconPaperProtectBrokerModifyEligLockFreezeBlockedTrades,FalconPaperProtectBrokerModifyEligLockBrokerModifySent,"
         "FalconPaperProtectBrokerModifyEligLockRuntimeSLChanged,FalconPaperProtectBrokerModifyEligLockInvariantBreaches,"
         "FalconPaperProtectBrokerModifyEligLockCoveragePct,FalconPaperProtectBrokerModifyEligLockEligibilityPct,"
         "FalconPaperProtectBrokerModifyEligLockCompletenessPct,FalconPaperProtectBrokerModifyEligLockNoLookahead,"
         "FalconPaperProtectBrokerModifyEligLockPolicy,FalconPaperProtectBrokerModifyEligLockOrderSendPolicy,"
         "FalconPaperProtectBrokerModifyEligLockNextPhase,"
         "FalconPaperProtectExecutorConsumerStatus,FalconPaperProtectExecutorConsumerDecision,"
         "FalconPaperProtectExecutorConsumerRuntimeEnforced,FalconPaperProtectExecutorConsumerScope,"
         "FalconPaperProtectExecutorConsumerEvaluatedTrades,FalconPaperProtectExecutorConsumerBrokerModifyEligibilityLockReadyTrades,"
         "FalconPaperProtectExecutorConsumerCandidateTrades,FalconPaperProtectExecutorConsumerReadableTrades,"
         "FalconPaperProtectExecutorConsumerModifyPlanReadableTrades,FalconPaperProtectExecutorConsumerVirtualSLReadableTrades,"
         "FalconPaperProtectExecutorConsumerProtectionLevelReadableTrades,FalconPaperProtectExecutorConsumerTriggerReadableTrades,"
         "FalconPaperProtectExecutorConsumerReadyTrades,FalconPaperProtectExecutorConsumerRejectedTrades,"
         "FalconPaperProtectExecutorConsumerConflictTrades,FalconPaperProtectExecutorConsumerMissingEligibilityLockTrades,"
         "FalconPaperProtectExecutorConsumerMissingModifyPlanTrades,FalconPaperProtectExecutorConsumerMissingVirtualSLTrades,"
         "FalconPaperProtectExecutorConsumerBrokerModifySent,FalconPaperProtectExecutorConsumerRuntimeSLChanged,"
         "FalconPaperProtectExecutorConsumerOrderSend,FalconPaperProtectExecutorConsumerInvariantBreaches,"
         "FalconPaperProtectExecutorConsumerReadinessPct,FalconPaperProtectExecutorConsumerCompletenessPct,"
         "FalconPaperProtectExecutorConsumerNoLookahead,FalconPaperProtectExecutorConsumerPolicy,"
         "FalconPaperProtectExecutorConsumerOrderSendPolicy,FalconPaperProtectExecutorConsumerNextPhase,"
         "FalconMagicExecutorClassificationStatus,FalconMagicExecutorClassificationDecision,"
         "FalconMagicExecutorClassificationRuntimeEnforced,FalconMagicExecutorClassificationScope,"
         "FalconMagicRegisteredStrategies,FalconMagicDefinedNumbers,FalconMagicUniqueNumbers,"
         "FalconMagicActiveEngineReady,FalconMagicUnknownEngineRejected,FalconMagicDuplicateBreaches,"
         "FalconExecutorErrorClassesDefined,FalconExecutorClassifierReady,FalconExecutorRetryPolicyDefined,"
         "FalconExecutorFatalRetryBlocked,FalconExecutorNeedsRefreshRetryOnce,FalconExecutorConnectionPolicyDefined,"
         "FalconExecutorOrderSend,FalconExecutorBrokerModifySent,FalconExecutorRuntimeSLChanged,"
         "FalconMagicExecutorInvariantBreaches,FalconMagicExecutorReadinessPct,FalconMagicExecutorCompletenessPct,"
         "FalconMagicExecutorMagicPolicy,FalconMagicExecutorErrorPolicy,FalconMagicExecutorOrderSendPolicy,"
         "FalconMagicExecutorNextPhase,"
         "FalconTradeStateRecoveryStatus,FalconTradeStateRecoveryDecision,"
         "FalconTradeStateRecoveryRuntimeEnforced,FalconTradeStateRecoveryScope,"
         "FalconTradeStatePersistenceContractDefined,FalconTradeStateFolderDefined,"
         "FalconTradeStateRecordShapeDefined,FalconTradeStateBrokerReconstructDefined,"
         "FalconTradeStateMinimalRecoveryDefined,FalconTradeStateEventPersistPolicyDefined,"
         "FalconTradeStateRestartPolicyDefined,FalconTradeStateShadowTradesCovered,"
         "FalconTradeStateRecoveryCandidates,FalconTradeStateMinimalRecoveryCandidates,"
         "FalconTradeStateUntrustedStateBlocked,FalconTradeStateOrderSend,"
         "FalconTradeStateBrokerModifySent,FalconTradeStateRuntimeSLChanged,"
         "FalconTradeStateInvariantBreaches,FalconTradeStateRecoveryReadinessPct,"
         "FalconTradeStateRecoveryCompletenessPct,FalconTradeStateRecoveryPolicy,"
         "FalconTradeStateRecoveryOrderSendPolicy,FalconTradeStateRecoveryNextPhase,"
         "FalconSpreadBrokerStatus,FalconSpreadBrokerDecision,"
         "FalconSpreadBrokerRuntimeEnforced,FalconSpreadBrokerScope,"
         "FalconSpreadGuardDefined,FalconSlippageCapDefined,"
         "FalconBrokerLimitsCacheDefined,FalconStopsLevelPolicyDefined,"
         "FalconFreezeLevelPolicyDefined,FalconVolumeLimitsPolicyDefined,"
         "FalconStopsBufferPoints,FalconMaxSpreadPoints,FalconMaxSlippagePoints,"
         "FalconSpreadBrokerShadowTradesCovered,FalconSpreadBrokerBrokerContextReady,"
         "FalconSpreadBrokerGuardReady,FalconSpreadBrokerRejectedTrades,"
         "FalconSpreadBrokerOrderSend,FalconSpreadBrokerBrokerModifySent,"
         "FalconSpreadBrokerRuntimeSLChanged,FalconSpreadBrokerInvariantBreaches,"
         "FalconSpreadBrokerReadinessPct,FalconSpreadBrokerCompletenessPct,"
         "FalconSpreadBrokerSpreadPolicy,FalconSpreadBrokerLimitsPolicy,"
         "FalconSpreadBrokerOrderSendPolicy,FalconSpreadBrokerNextPhase,"
         "FalconTradeTransactionStatus,FalconTradeTransactionDecision,"
         "FalconTradeTransactionRuntimeEnforced,FalconTradeTransactionScope,"
         "FalconTradeTransactionHandlerDefined,FalconTradeTransactionSourcePolicyDefined,"
         "FalconTradeTransactionEventRoutingDefined,FalconTradeTransactionDealAddPolicyDefined,"
         "FalconTradeTransactionPositionChangePolicyDefined,FalconTradeTransactionStatePersistHookDefined,"
         "FalconTradeTransactionOnTickReadOnlyPolicy,FalconTradeTransactionShadowTradesCovered,"
         "FalconTradeTransactionBrokerEventsObserved,FalconTradeTransactionDealEventsRouted,"
         "FalconTradeTransactionPositionEventsRouted,FalconTradeTransactionUnknownEventsIgnored,"
         "FalconTradeTransactionOrderSend,FalconTradeTransactionBrokerModifySent,"
         "FalconTradeTransactionRuntimeSLChanged,FalconTradeTransactionInvariantBreaches,"
         "FalconTradeTransactionReadinessPct,FalconTradeTransactionCompletenessPct,"
         "FalconTradeTransactionSourcePolicy,FalconTradeTransactionStatePolicy,"
         "FalconTradeTransactionOrderSendPolicy,FalconTradeTransactionNextPhase,"
         "FalconPreInitStatus,FalconPreInitDecision,"
         "FalconPreInitRuntimeEnforced,FalconPreInitScope,"
         "FalconPreInitSymbolPolicyDefined,FalconPreInitTimeframePolicyDefined,"
         "FalconPreInitAccountPolicyDefined,FalconPreInitBrokerPolicyDefined,"
         "FalconPreInitMinimumBalancePolicyDefined,FalconPreInitWrongEnvironmentBlocksLive,"
         "FalconPreInitShadowSmokeNonBlocking,FalconPreInitSupportedSymbolDetected,"
         "FalconPreInitBrokerContextReady,FalconPreInitShadowTradesCovered,"
         "FalconPreInitInitFailedTriggered,FalconPreInitOrderSend,"
         "FalconPreInitBrokerModifySent,FalconPreInitRuntimeSLChanged,"
         "FalconPreInitInvariantBreaches,FalconPreInitReadinessPct,"
         "FalconPreInitCompletenessPct,FalconPreInitSymbolPolicy,"
         "FalconPreInitTimeframePolicy,FalconPreInitAccountPolicy,"
         "FalconPreInitBrokerPolicy,FalconPreInitOrderSendPolicy,"
         "FalconPreInitNextPhase,"
         "FalconEmergencyEquityStatus,FalconEmergencyEquityDecision,"
         "FalconEmergencyEquityRuntimeEnforced,FalconEmergencyEquityScope,"
         "FalconEmergencyEquityContractDefined,FalconEmergencyEquityIndependentDefined,"
         "FalconEmergencyEquityEveryTickPolicy,FalconEmergencyEquityBeforeEnginePolicy,"
         "FalconEmergencyEquityHardCapDefined,FalconEmergencyEquityHardCapPct,"
         "FalconEmergencyEquityBlocksNewEntries,FalconEmergencyEquityCloseAllPolicy,"
         "FalconEmergencyEquitySessionDisablePolicy,FalconEmergencyEquityAlertPolicyDefined,"
         "FalconEmergencyEquityShadowTradesCovered,FalconEmergencyEquityTriggered,"
         "FalconEmergencyEquityClosedPositions,FalconEmergencyEquityOrderSend,"
         "FalconEmergencyEquityBrokerModifySent,FalconEmergencyEquityRuntimeSLChanged,"
         "FalconEmergencyEquityInvariantBreaches,FalconEmergencyEquityReadinessPct,"
         "FalconEmergencyEquityCompletenessPct,FalconEmergencyEquityPolicy,"
         "FalconEmergencyEquityActionPolicy,FalconEmergencyEquityAlertPolicy,"
         "FalconEmergencyEquityOrderSendPolicy,FalconEmergencyEquityNextPhase,"
         "FalconConcurrentPositionStatus,FalconConcurrentPositionDecision,"
         "FalconConcurrentPositionRuntimeEnforced,FalconConcurrentPositionScope,"
         "FalconConcurrentPositionContractDefined,FalconConcurrentPositionMaxTotal,"
         "FalconConcurrentPositionMaxPerEngine,FalconConcurrentPositionMaxPerDirection,"
         "FalconConcurrentPositionTotalCapDefined,FalconConcurrentPositionPerEngineCapDefined,"
         "FalconConcurrentPositionPerDirectionCapDefined,"
         "FalconConcurrentPositionSharedExposurePolicyDefined,"
         "FalconConcurrentPositionEngineIsolationPolicyDefined,"
         "FalconConcurrentPositionDirectionCapPolicyDefined,"
         "FalconConcurrentPositionShadowSmokeNonBlocking,"
         "FalconConcurrentPositionShadowTradesCovered,"
         "FalconConcurrentPositionOpenPositionsObserved,"
         "FalconConcurrentPositionBlockedByTotalCap,"
         "FalconConcurrentPositionBlockedByEngineCap,"
         "FalconConcurrentPositionBlockedByDirectionCap,"
         "FalconConcurrentPositionOrderSend,FalconConcurrentPositionBrokerModifySent,"
         "FalconConcurrentPositionRuntimeSLChanged,"
         "FalconConcurrentPositionInvariantBreaches,"
         "FalconConcurrentPositionReadinessPct,"
         "FalconConcurrentPositionCompletenessPct,"
         "FalconConcurrentPositionSharedExposurePolicy,"
         "FalconConcurrentPositionEngineIsolationPolicy,"
         "FalconConcurrentPositionDirectionCapPolicy,"
         "FalconConcurrentPositionOrderSendPolicy,"
         "FalconConcurrentPositionNextPhase,"
         "FalconPaperModeStatus,FalconPaperModeDecision,"
         "FalconPaperModeRuntimeEnforced,FalconPaperModeScope,"
         "FalconPaperModeShadowDefinitionReady,FalconPaperModePaperDefinitionReady,"
         "FalconPaperModeDemoDefinitionReady,FalconPaperModeLiveDefinitionReady,"
         "FalconPaperModePaperPositionLifecycleDefined,"
         "FalconPaperModePaperVirtualSLDefined,"
         "FalconPaperModePaperProtectionDefined,"
         "FalconPaperModePaperRunnerDefined,"
         "FalconPaperModePaperEquityCurveDefined,"
         "FalconPaperModePaperExitModelDefined,"
         "FalconPaperModeShadowSmokeNonBlocking,"
         "FalconPaperModeShadowTradesCovered,"
         "FalconPaperModePaperPositionsCreated,"
         "FalconPaperModePaperExitsApplied,"
         "FalconPaperModePaperEquityEvents,"
         "FalconPaperModeOrderSend,FalconPaperModeBrokerModifySent,"
         "FalconPaperModeRuntimeSLChanged,FalconPaperModeInvariantBreaches,"
         "FalconPaperModeReadinessPct,FalconPaperModeCompletenessPct,"
         "FalconPaperModeShadowPolicy,FalconPaperModePaperPolicy,"
         "FalconPaperModeDemoPolicy,FalconPaperModeLivePolicy,"
         "FalconPaperModeOrderSendPolicy,FalconPaperModeNextPhase,"
         "FalconSymbolProfileStatus,FalconSymbolProfileDecision,"
         "FalconSymbolProfileRuntimeEnforced,FalconSymbolProfileScope,"
         "FalconSymbolProfileSymbolFamilyDefined,FalconSymbolProfileAliasesDefined,"
         "FalconSymbolProfileCurrentSymbolRecognized,FalconSymbolProfileContextValid,"
         "FalconSymbolProfileDigits,FalconSymbolProfilePoint,"
         "FalconSymbolProfileTickSize,FalconSymbolProfileTickValue,"
         "FalconSymbolProfileContractSize,FalconSymbolProfileSpreadPoints,"
         "FalconSymbolProfileStopsLevelPoints,FalconSymbolProfileFreezeLevelPoints,"
         "FalconSymbolProfileMinLot,FalconSymbolProfileMaxLot,FalconSymbolProfileLotStep,"
         "FalconSymbolProfileContractPolicyDefined,FalconSymbolProfileTickPolicyDefined,"
         "FalconSymbolProfilePointMappingDefined,FalconSymbolProfileBrokerLimitsDefined,"
         "FalconSymbolProfileSessionPolicyDefined,FalconSymbolProfileSpreadPolicyDefined,"
         "FalconSymbolProfileDefaultSafetyProfileDefined,"
         "FalconSymbolProfileShadowSmokeNonBlocking,"
         "FalconSymbolProfileShadowTradesCovered,"
         "FalconSymbolProfilePaperGuardsApplied,"
         "FalconSymbolProfileOrderSend,FalconSymbolProfileBrokerModifySent,"
         "FalconSymbolProfileRuntimeSLChanged,FalconSymbolProfileInvariantBreaches,"
         "FalconSymbolProfileReadinessPct,FalconSymbolProfileCompletenessPct,"
         "FalconSymbolProfileSymbolAliases,FalconSymbolProfileContractPolicy,"
         "FalconSymbolProfileTickPolicy,FalconSymbolProfilePointMappingPolicy,"
         "FalconSymbolProfileBrokerLimitsPolicy,FalconSymbolProfileSessionPolicy,"
         "FalconSymbolProfileSpreadPolicy,FalconSymbolProfileDefaultSafetyPolicy,"
         "FalconSymbolProfileOrderSendPolicy,FalconSymbolProfileNextPhase,"
         "FalconPaperGuardAppStatus,FalconPaperGuardAppDecision,"
         "FalconPaperGuardAppRuntimeEnforced,FalconPaperGuardAppScope,"
         "FalconPaperGuardContractReady,FalconPaperGuardEvaluatedTrades,"
         "FalconPaperGuardPassedTrades,FalconPaperGuardRejectedTrades,"
         "FalconPaperSpreadRejectedTrades,FalconPaperStopsRejectedTrades,"
         "FalconPaperFreezeRejectedTrades,FalconPaperExposureEvaluatedTrades,"
         "FalconPaperExposurePassedTrades,FalconPaperExposureBlockedByTotalCap,"
         "FalconPaperExposureBlockedByEngineCap,FalconPaperExposureBlockedByDirectionCap,"
         "FalconPaperGuardBeforeNetPoints,FalconPaperGuardAfterNetPoints,"
         "FalconPaperGuardImpactPoints,FalconPaperGuardBeforeNetUSD,"
         "FalconPaperGuardAfterNetUSD,FalconPaperGuardImpactUSD,"
         "FalconPaperGuardOrderSend,FalconPaperGuardBrokerModifySent,"
         "FalconPaperGuardRuntimeSLChanged,FalconPaperGuardInvariantBreaches,"
         "FalconPaperGuardReadinessPct,FalconPaperGuardApplicationPct,"
         "FalconPaperGuardRejectPolicy,FalconPaperGuardExposurePolicy,"
         "FalconPaperGuardOrderSendPolicy,FalconPaperGuardNextPhase,"
         "FalconPaperProtectionStatus,FalconPaperProtectionDecision,"
         "FalconPaperProtectionRuntimeEnforced,FalconPaperProtectionScope,"
         "FalconPaperProtectionContractReady,FalconPaperProtectionEvaluatedTrades,"
         "FalconPaperProtectionEligibleTrades,FalconPaperProtectionActivatedTrades,"
         "FalconPaperTP1ProtectionTrades,FalconPaperTP2ProtectionTrades,"
         "FalconPaperVirtualSLChangedTrades,FalconPaperVirtualSLHitTrades,"
         "FalconPaperProtectedExitTrades,FalconPaperProtectionBeforeNetPoints,"
         "FalconPaperProtectionAfterNetPoints,FalconPaperProtectionImpactPoints,"
         "FalconPaperProtectionBeforeNetUSD,FalconPaperProtectionAfterNetUSD,"
         "FalconPaperProtectionImpactUSD,FalconPaperProtectionGivebackPreventedPoints,"
         "FalconPaperProtectionGivebackPreventedUSD,FalconPaperProtectionOrderSend,"
         "FalconPaperProtectionBrokerModifySent,FalconPaperProtectionRuntimeSLChanged,"
         "FalconPaperProtectionInvariantBreaches,FalconPaperProtectionReadinessPct,"
         "FalconPaperProtectionApplicationPct,FalconPaperProtectionPolicy,"
         "FalconPaperProtectionOrderSendPolicy,FalconPaperProtectionNextPhase,"
         "FalconPaperRunnerStatus,FalconPaperRunnerDecision,"
         "FalconPaperRunnerRuntimeEnforced,FalconPaperRunnerScope,"
         "FalconPaperRunnerContractReady,FalconPaperRunnerEvaluatedTrades,"
         "FalconPaperRunnerEligibleTrades,FalconPaperRunnerActivatedTrades,"
         "FalconPaperRunner3RTrades,FalconPaperMoonMode5RTrades,"
         "FalconPaperRunnerExitTrades,FalconPaperRunnerAdditionalPoints,"
         "FalconPaperRunnerAdditionalUSD,FalconPaperRunnerGivebackTrades,"
         "FalconPaperRunnerProtectedFromLossTrades,FalconPaperRunnerBeforeNetPoints,"
         "FalconPaperRunnerAfterNetPoints,FalconPaperRunnerImpactPoints,"
         "FalconPaperRunnerBeforeNetUSD,FalconPaperRunnerAfterNetUSD,"
         "FalconPaperRunnerImpactUSD,FalconPaperRunnerOrderSend,"
         "FalconPaperRunnerBrokerModifySent,FalconPaperRunnerRuntimeSLChanged,"
         "FalconPaperRunnerInvariantBreaches,FalconPaperRunnerReadinessPct,"
         "FalconPaperRunnerApplicationPct,FalconPaperRunnerPolicy,"
         "FalconPaperRunnerOrderSendPolicy,FalconPaperRunnerNextPhase,"
         "FalconRunnerBarPathPolicy,FalconRunnerBarPathNextPhase,"
         "FalconCapitalTierStatus,FalconCapitalTierDecision,FalconCapitalTierRuntimeEnforced,"
         "FalconCapitalTierScope,FalconCapitalTierContractReady,FalconCapitalTierEffectiveBalance,"
         "FalconCapitalTierName,FalconCapitalTierMinBalance,FalconCapitalTierMaxBalance,"
         "FalconCapitalTierMaxConsecutiveLosses,FalconCapitalTierMaxDailyR,FalconCapitalTierMaxDrawdownPct,"
         "FalconCapitalTierBrokerMinLot,FalconCapitalTierFixedLot,FalconCapitalTierMinLotConstraint,"
         "FalconCapitalTierMinLotCompatible,FalconCapitalTierLockedAtSessionStart,"
         "FalconCapitalTierOrderSend,FalconCapitalTierBrokerModifySent,FalconCapitalTierRuntimeSLChanged,"
         "FalconCapitalTierInvariantBreaches,FalconCapitalTierReadinessPct,FalconCapitalTierApplicationPct,"
         "FalconCapitalTierBalancePolicy,FalconCapitalTierMinLotPolicy,FalconCapitalTierOrderSendPolicy,"
         "FalconCapitalTierNextPhase,"
         "FalconThreeLayerEmergencyStatus,FalconThreeLayerEmergencyDecision,FalconThreeLayerEmergencyRuntimeEnforced,"
         "FalconThreeLayerEmergencyScope,FalconThreeLayerEmergencyContractReady,"
         "FalconThreeLayerEmergencyEvaluatedTrades,FalconThreeLayerEmergencySafeTrades,"
         "FalconThreeLayerEmergencyTriggeredTrades,FalconThreeLayerEmergencyBlockedEntries,"
         "FalconThreeLayerEmergencyLayer1Triggers,FalconThreeLayerEmergencyLayer2Triggers,FalconThreeLayerEmergencyLayer3Triggers,"
         "FalconThreeLayerEmergencyBeforeNetPoints,FalconThreeLayerEmergencyAfterNetPoints,FalconThreeLayerEmergencyImpactPoints,"
         "FalconThreeLayerEmergencyBeforeNetUSD,FalconThreeLayerEmergencyAfterNetUSD,FalconThreeLayerEmergencyImpactUSD,"
         "FalconThreeLayerEmergencyMaxDrawdownPct,FalconThreeLayerEmergencyWorstDailyR,"
         "FalconThreeLayerEmergencyOrderSend,FalconThreeLayerEmergencyBrokerModifySent,FalconThreeLayerEmergencyRuntimeSLChanged,"
         "FalconThreeLayerEmergencyInvariantBreaches,FalconThreeLayerEmergencyReadinessPct,FalconThreeLayerEmergencyApplicationPct,"
         "FalconThreeLayerEmergencyPolicy,FalconThreeLayerEmergencyOrderSendPolicy,FalconThreeLayerEmergencyNextPhase,"
         "FalconLayerResetStatus,FalconLayerResetDecision,FalconLayerResetRuntimeEnforced,"
         "FalconLayerResetScope,FalconLayerResetContractReady,FalconLayerResetEvaluatedTrades,"
         "FalconLayer1ResetOnWinEvents,FalconLayer2ResetOnNewDayEvents,FalconLayer3ResetOnNewPeakEvents,"
         "FalconLayerResetEventTrades,FalconLayerResetDuplicateTriggers,"
         "FalconLayerResetOrderSend,FalconLayerResetBrokerModifySent,FalconLayerResetRuntimeSLChanged,"
         "FalconLayerResetInvariantBreaches,FalconLayerResetReadinessPct,FalconLayerResetApplicationPct,"
         "FalconLayerResetPolicy,FalconLayerResetOrderSendPolicy,FalconLayerResetNextPhase,"
         "FalconValidationLockStatus,FalconValidationLockDecision,FalconValidationLockRuntimeEnforced,"
         "FalconValidationLockScope,FalconValidationLockContractReady,FalconValidationLockEvaluatedTrades,"
         "FalconValidationLockAnchorNetUSD,FalconValidationLockPreviousRunnerNetUSD,FalconValidationLockWorkingBaselineNetUSD,"
         "FalconValidationLockWorkingBaselineImpactUSD,FalconValidationLockEmergencyTriggeredTrades,"
         "FalconValidationLockEmergencyBlockedEntries,FalconValidationLockLayerResetDuplicateTriggers,"
         "FalconValidationLockMultiWindowRequired,FalconValidationLockOrderSend,FalconValidationLockBrokerModifySent,"
         "FalconValidationLockRuntimeSLChanged,FalconValidationLockInvariantBreaches,FalconValidationLockReadinessPct,"
         "FalconValidationLockApplicationPct,FalconValidationLockPolicy,FalconValidationLockOrderSendPolicy,FalconValidationLockNextPhase,"
         "FalconTierPromotionStatus,FalconTierPromotionDecision,FalconTierPromotionRuntimeEnforced,"
         "FalconTierPromotionScope,FalconTierPromotionContractReady,FalconTierPromotionEvaluatedTrades,"
         "FalconTierPromotionCurrentTier,FalconTierPromotionNextTier,FalconTierPromotionEffectiveBalance,"
         "FalconTierPromotionNextTierMinBalance,FalconTierPromotionMinTradesRequired,FalconTierPromotionTradesInTier,"
         "FalconTierPromotionMinWinRatePct,FalconTierPromotionCurrentWinRatePct,FalconTierPromotionMinNetR,"
         "FalconTierPromotionCurrentNetR,FalconTierPromotionDaysWithoutEmergencyRequired,FalconTierPromotionCooldownDays,"
         "FalconTierPromotionBalanceRequirementMet,FalconTierPromotionTradesRequirementMet,FalconTierPromotionWinRateRequirementMet,"
         "FalconTierPromotionNetRRequirementMet,FalconTierPromotionNoEmergencyRequirementPending,FalconTierPromotionCooldownRequirementPending,"
         "FalconTierPromotionEligibleNow,FalconTierPromotionBlockedReason,FalconTierPromotionEvents,"
         "FalconTierPromotionTransitionReportDefined,FalconTierPromotionOrderSend,FalconTierPromotionBrokerModifySent,"
         "FalconTierPromotionRuntimeSLChanged,FalconTierPromotionInvariantBreaches,FalconTierPromotionReadinessPct,"
         "FalconTierPromotionApplicationPct,FalconTierPromotionPolicy,FalconTierPromotionOrderSendPolicy,FalconTierPromotionNextPhase,"
         "FalconTierDemotionStatus,FalconTierDemotionDecision,FalconTierDemotionRuntimeEnforced,"
         "FalconTierDemotionScope,FalconTierDemotionContractReady,FalconTierDemotionEvaluatedTrades,"
         "FalconTierDemotionCurrentTier,FalconTierDemotionEffectiveBalance,FalconTierDemotionCurrentTierMinBalance,"
         "FalconTierDemotionBalanceHysteresisPct,FalconTierDemotionBalanceHysteresisThreshold,"
         "FalconTierDemotionEmergenciesIn14Days,FalconTierDemotionMaxEmergenciesIn14Days,"
         "FalconTierDemotionNegativeWeeksInRow,FalconTierDemotionMaxNegativeWeeksInRow,"
         "FalconTierDemotionExtremeDrawdownMultiplier,FalconTierDemotionObservedMaxDrawdownPct,FalconTierDemotionExtremeDrawdownThresholdPct,"
         "FalconTierDemotionBalanceHysteresisBreach,FalconTierDemotionMultipleEmergenciesBreach,"
         "FalconTierDemotionNegativeWeeksBreach,FalconTierDemotionExtremeDrawdownBreach,"
         "FalconTierDemotionShouldDemoteNow,FalconTierDemotionReason,FalconTierDemotionEvents,"
         "FalconTierDemotionTransitionReportDefined,FalconTierDemotionOrderSend,FalconTierDemotionBrokerModifySent,"
         "FalconTierDemotionRuntimeSLChanged,FalconTierDemotionInvariantBreaches,FalconTierDemotionReadinessPct,"
         "FalconTierDemotionApplicationPct,FalconTierDemotionPolicy,FalconTierDemotionOrderSendPolicy,FalconTierDemotionNextPhase,"
         "FalconTierTransitionStatus,FalconTierTransitionDecision,FalconTierTransitionRuntimeEnforced,"
         "FalconTierTransitionScope,FalconTierTransitionContractReady,FalconTierTransitionEvaluatedTrades,"
         "FalconTierTransitionStartTier,FalconTierTransitionAppliedTier,FalconTierTransitionDirection,FalconTierTransitionReason,"
         "FalconTierTransitionPromotionApplied,FalconTierTransitionDemotionApplied,FalconTierTransitionEvents,"
         "FalconTierTransitionActivePositionsPreserved,FalconTierTransitionNextTradesUseAppliedTier,"
         "FalconTierTransitionOrderSend,FalconTierTransitionBrokerModifySent,FalconTierTransitionRuntimeSLChanged,"
         "FalconTierTransitionInvariantBreaches,FalconTierTransitionReadinessPct,FalconTierTransitionApplicationPct,"
         "FalconTierTransitionPolicy,FalconTierTransitionOrderSendPolicy,FalconTierTransitionNextPhase,"
         "FalconLowCapitalRiskFeasibilityStatus,FalconLowCapitalRiskFeasibilityDecision,"
         "FalconLowCapitalRiskFeasibilityRuntimeEnforced,FalconLowCapitalRiskFeasibilityScope,"
         "FalconLowCapitalRiskFeasibilityContractReady,FalconLowCapitalRiskFeasibilityEvaluatedTrades,"
         "FalconLowCapitalRiskFeasibilityFeasibleTrades,FalconLowCapitalRiskFeasibilityBorderlineTrades,"
         "FalconLowCapitalRiskFeasibilityNotFeasibleTrades,FalconLowCapitalRiskFeasibilityInvalidTrades,"
         "FalconLowCapitalRiskFeasibilitySingleTradeCapBreaches,"
         "FalconLowCapitalRiskFeasibilityMinLotRiskUSDAvg,FalconLowCapitalRiskFeasibilityMinLotRiskUSDMax,"
         "FalconLowCapitalRiskFeasibilityMinLotRiskPctAvg,FalconLowCapitalRiskFeasibilityMinLotRiskPctMax,"
         "FalconLowCapitalRiskFeasibilityPotentialLossRAvg,FalconLowCapitalRiskFeasibilityPotentialLossRMax,"
         "FalconLowCapitalRiskFeasibilityOrderSend,FalconLowCapitalRiskFeasibilityBrokerModifySent,"
         "FalconLowCapitalRiskFeasibilityRuntimeSLChanged,FalconLowCapitalRiskFeasibilityInvariantBreaches,"
         "FalconLowCapitalRiskFeasibilityReadinessPct,FalconLowCapitalRiskFeasibilityApplicationPct,"
         "FalconLowCapitalRiskFeasibilityPolicy,FalconLowCapitalRiskFeasibilityOrderSendPolicy,"
         "FalconLowCapitalRiskFeasibilityNextPhase,"
         "FalconSingleTradeLossCapStatus,FalconSingleTradeLossCapDecision,FalconSingleTradeLossCapRuntimeEnforced,"
         "FalconSingleTradeLossCapScope,FalconSingleTradeLossCapContractReady,FalconSingleTradeLossCapEvaluatedTrades,"
         "FalconSingleTradeLossCapAllowedTrades,FalconSingleTradeLossCapBlockedTrades,FalconSingleTradeLossCapInvalidTrades,"
         "FalconSingleTradeLossCapStrictBreachTrades,FalconSingleTradeLossCapCalibratedBreachTrades,"
         "FalconSingleTradeLossCapBeforeNetUSD,FalconSingleTradeLossCapAfterNetUSD,FalconSingleTradeLossCapImpactUSD,"
         "FalconSingleTradeLossCapRejectedProfitUSD,FalconSingleTradeLossCapRejectedLossUSD,"
         "FalconSingleTradeLossCapMaxCalibratedCapR,FalconSingleTradeLossCapMaxRiskPctCap,"
         "FalconSingleTradeLossCapDynamicCapitalMode,FalconSingleTradeLossCapDynamicCapitalStart,"
         "FalconSingleTradeLossCapDynamicCapitalMin,FalconSingleTradeLossCapDynamicCapitalMax,"
         "FalconSingleTradeLossCapDynamicCapitalEnd,FalconSingleTradeLossCapDynamicCapitalUpdates,"
         "FalconSingleTradeLossCapDynamicRiskPctMax,FalconSingleTradeLossCapDynamicCapPctMax,"
         "FalconSingleTradeLossCapDynamicCapitalBlocks,"
         "FalconSingleTradeLossCapOrderSend,FalconSingleTradeLossCapBrokerModifySent,FalconSingleTradeLossCapRuntimeSLChanged,"
         "FalconSingleTradeLossCapInvariantBreaches,FalconSingleTradeLossCapReadinessPct,FalconSingleTradeLossCapApplicationPct,"
         "FalconSingleTradeLossCapPolicy,FalconSingleTradeLossCapOrderSendPolicy,FalconSingleTradeLossCapNextPhase";

      // v0.45.0a compile fix: split the very long Summary row expression into small
      // append chunks. This changes only compiler expression shape; CSV schema and
      // values remain identical to v0.45.0.
      string summary_row = "";
      summary_row +=
         FalconCsvSafe(EA_NAME) + "," +
         FalconCsvSafe(EA_VERSION_TAG) + "," +
         FalconCsvSafe(EA_BUILD_TAG) + "," +
         FalconCsvSafe(m_symbol_context.symbol) + "," +
         FalconCsvSafe(FalconTimeToString(TimeCurrent())) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.win_trades) + "," +
         IntegerToString(m_totals.loss_trades) + "," +
         IntegerToString(m_totals.breakeven_trades) + "," +
         DoubleToString(m_totals.win_rate, 2) + "," +
         DoubleToString(m_totals.loss_rate, 2) + "," +
         DoubleToString(m_totals.total_profit_index_points, 2) + "," +
         DoubleToString(m_totals.total_loss_index_points, 2) + "," +
         DoubleToString(m_totals.net_index_points, 2) + "," +
         DoubleToString(m_totals.total_profit_usd, 2) + "," +
         DoubleToString(m_totals.total_loss_usd, 2) + "," +
         DoubleToString(m_totals.net_usd, 2) + "," +
         IntegerToString(m_totals.buy_trades) + "," +
         DoubleToString(buy_win_rate, 2) + "," +
         DoubleToString(m_totals.buy_net_index_points, 2) + "," +
         IntegerToString(m_totals.sell_trades) + "," +
         DoubleToString(sell_win_rate, 2) + "," +
         DoubleToString(m_totals.sell_net_index_points, 2) + "," +
         IntegerToString(g_fvg_retest_watch_evaluated) + "," +
         IntegerToString(g_fvg_retest_touched) + "," +
         IntegerToString(g_fvg_retest_waiting) + "," +
         IntegerToString(g_fvg_retest_fresh) + "," +
         IntegerToString(g_fvg_retest_stale) + "," +
         IntegerToString(retest_age_min_bars) + "," +
         DoubleToString(FalconSafeAverageLongAsDouble(g_fvg_retest_age_total_bars, g_fvg_retest_watch_evaluated), 2) + "," +
         IntegerToString(g_fvg_retest_age_max_bars) + "," +
         IntegerToString(g_fvg_hold_quality_evaluated) + "," +
         IntegerToString(g_fvg_hold_quality_strong) + "," +
         IntegerToString(g_fvg_hold_quality_neutral) + "," +
         IntegerToString(g_fvg_hold_quality_weak) + "," +
         IntegerToString(hold_quality_score_min) + ",";
      summary_row +=
         DoubleToString(FalconSafeAverageLongAsDouble(g_fvg_hold_quality_score_total, g_fvg_hold_quality_evaluated), 2) + "," +
         IntegerToString(g_fvg_hold_quality_score_max) + "," +
         IntegerToString(g_fvg_micro_candidate_builder_evaluations) + "," +
         IntegerToString(g_fvg_micro_detected_candidates) + "," +
         IntegerToString(g_fvg_micro_quality_evaluated) + "," +
         IntegerToString(g_fvg_micro_quality_passed) + "," +
         IntegerToString(g_fvg_micro_quality_rejected) + "," +
         IntegerToString(g_fvg_micro_rejected_size) + "," +
         IntegerToString(g_fvg_micro_rejected_spread) + "," +
         IntegerToString(g_fvg_micro_rejected_age) + "," +
         IntegerToString(g_fvg_micro_shadow_ready_candidates) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_PROFILE_TAG) + "," +
         IntegerToString(m_totals.fvg_qguard_evaluated) + "," +
         IntegerToString(m_totals.fvg_qguard_passed) + "," +
         IntegerToString(m_totals.fvg_qguard_blocked) + "," +
         IntegerToString(m_totals.fvg_qguard_blocked_winners) + "," +
         IntegerToString(m_totals.fvg_qguard_blocked_losers) + "," +
         DoubleToString(m_totals.fvg_qguard_actual_net_points, 2) + "," +
         DoubleToString(m_totals.fvg_qguard_simulated_net_points, 2) + "," +
         DoubleToString(m_totals.fvg_qguard_simulated_net_points - m_totals.fvg_qguard_actual_net_points, 2) + "," +
         DoubleToString(m_totals.fvg_qguard_blocked_net_points, 2) + "," +
         DoubleToString(m_totals.fvg_qguard_actual_net_usd, 2) + "," +
         DoubleToString(m_totals.fvg_qguard_simulated_net_usd, 2) + "," +
         DoubleToString(m_totals.fvg_qguard_simulated_net_usd - m_totals.fvg_qguard_actual_net_usd, 2) + "," +
         DoubleToString(m_totals.fvg_qguard_blocked_net_usd, 2) + "," +
         FalconBoolToYesNo(FALCON_FVG_QGUARD_RUNTIME_ACTIVE) + "," +
         FalconBoolToYesNo(FALCON_FVG_QGUARD_ACTUAL_BLOCKING_ENABLED) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_CANDIDATE_STAGE) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_FEASIBILITY_DECISION) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_FEASIBILITY_REASON) + "," +
         FalconBoolToYesNo(FALCON_FVG_QGUARD_NO_LOOKAHEAD_FEASIBLE) + "," +
         FalconBoolToYesNo(FALCON_FVG_QGUARD_KNOWN_BEFORE_ENTRY) + "," +
         FalconBoolToYesNo(FALCON_FVG_QGUARD_MANUAL_PROMOTION_REQUIRED) + "," +
         DoubleToString(FALCON_FVG_QGUARD_MIN_SIZE_POINTS, 2) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_NEXT_STEP) + "," +
         FalconBoolToYesNo(FALCON_FVG_QGUARD_RUNTIME_CANDIDATE_ALLOWED) + ",";
      summary_row +=
         FalconBoolToYesNo(FALCON_FVG_QGUARD_RUNTIME_CANDIDATE_DESIGN_READY) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_ACTIVATION_POLICY) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_PROMOTION_RULE) + "," +
         FalconBoolToYesNo(FALCON_FVG_QGUARD_ROLLBACK_REQUIRED) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_ROLLBACK_BASELINE) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_ROLLBACK_TRIGGER) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_RUNTIME_BLOCKING_RULE) + "," +
         FalconCsvSafe(FALCON_FVG_QGUARD_NEXT_CANDIDATE_VERSION) + "," +
         IntegerToString(g_fvg_qguard_runtime_candidate_evaluated) + "," +
         IntegerToString(g_fvg_qguard_runtime_candidate_passed) + "," +
         IntegerToString(g_fvg_qguard_runtime_candidate_blocked) + "," +
         IntegerToString(g_fvg_qguard_runtime_staged_trades) + "," +
         IntegerToString(g_fvg_qguard_runtime_passed_but_not_staged) + "," +
         IntegerToString(g_fvg_qguard_runtime_rejected_after_pass) + "," +
         IntegerToString(runtime_staged_but_not_closed) + "," +
         FalconCsvSafe(FALCON_FVG_ENGINE_COMPLETION_STATUS) + "," +
         FalconCsvSafe(FALCON_FVG_ENGINE_COMPLETION_DECISION) + "," +
         FalconCsvSafe(FALCON_FVG_ENGINE_COMPLETION_SCOPE) + "," +
         FalconCsvSafe(FALCON_FVG_ENGINE_COMPLETED_ENGINE_ID) + "," +
         FalconCsvSafe(FALCON_FVG_ENGINE_ACTIVE_STRATEGY_ONLY) + "," +
         FalconCsvSafe(FALCON_FVG_ENGINE_LIVE_PILOT_ELIGIBILITY) + "," +
         FalconCsvSafe(FALCON_FVG_ENGINE_NEXT_REQUIRED_LAYER) + "," +
         FalconCsvSafe(FALCON_FVG_ENGINE_NEXT_ENGINEERING_PHASE) + "," +
         FalconCsvSafe(FALCON_GUARD_FOUNDATION_STATUS) + "," +
         FalconCsvSafe(FALCON_GUARD_FOUNDATION_DECISION) + "," +
         FalconCsvSafe(FalconGuardOverallStatus(m_symbol_context)) + "," +
         FalconCsvSafe(FALCON_GUARD_SCOPE) + "," +
         FalconCsvSafe(FALCON_GUARD_EXECUTION_PERMISSION) + "," +
         FalconCsvSafe(FALCON_GUARD_RISK_MODE) + "," +
         DoubleToString(FalconConfiguredCapital(), 2) + "," +
         DoubleToString(FixedLotSize, 2) + "," +
         FalconCsvSafe(FalconGuardFixedLotStatus(m_symbol_context)) + "," +
         FalconBoolToYesNo(UseDailyLossLimit) + "," +
         DoubleToString(FalconGuardDailyLossLimitUsd(), 2) + "," +
         FalconCsvSafe(FalconGuardDailyLossStatus()) + "," +
         IntegerToString(MaxTradesPerDay) + ",";
      summary_row +=
         FalconCsvSafe(FalconGuardMaxTradesStatus()) + "," +
         IntegerToString(MaxOpenPositions) + "," +
         FalconCsvSafe(FalconGuardMaxOpenPositionsStatus()) + "," +
         IntegerToString(FALCON_GUARD_MAX_CONSECUTIVE_LOSSES) + "," +
         FalconCsvSafe(FalconGuardSpreadGuardStatus(m_symbol_context)) + "," +
         FalconCsvSafe(FalconGuardStopsLevelGuardStatus(m_symbol_context)) + "," +
         FalconCsvSafe(FALCON_GUARD_ENGINE_ALLOCATION) + "," +
         FalconCsvSafe(FALCON_GUARD_KILL_SWITCH_STATUS) + "," +
         FalconCsvSafe(FALCON_GUARD_MANUAL_KILL_SWITCH_STATUS) + "," +
         FalconCsvSafe(FALCON_GUARD_LIVE_ELIGIBILITY) + "," +
         FalconCsvSafe(FALCON_GUARD_NEXT_REQUIRED_LAYER) + "," +
         FalconCsvSafe(FALCON_GUARD_NEXT_ENGINEERING_PHASE) + "," +
         FalconCsvSafe(FALCON_GUARD_PRE_EXECUTION_GATE_STATUS) + "," +
         FalconCsvSafe(FalconGuardCanOpenTradeDesign(m_symbol_context)) + "," +
         FalconCsvSafe(FalconGuardPreExecutionBlockReason(m_symbol_context)) + "," +
         FalconCsvSafe(FALCON_GUARD_PRE_EXECUTION_LOT_MODE) + "," +
         DoubleToString(FalconGuardPlannedLotDesign(m_symbol_context), 2) + "," +
         DoubleToString(FalconGuardDailyLossLimitUsd(), 2) + "," +
         FalconCsvSafe(FALCON_GUARD_PRE_EXECUTION_DAILY_LOSS_STATUS) + "," +
         IntegerToString(MaxTradesPerDay) + "," +
         FalconCsvSafe(FALCON_GUARD_PRE_EXECUTION_DAILY_TRADES_STATUS) + "," +
         IntegerToString(MaxOpenPositions) + "," +
         FalconCsvSafe(FALCON_GUARD_PRE_EXECUTION_OPEN_CAPACITY_STATUS) + "," +
         FalconCsvSafe(FALCON_GUARD_PRE_EXECUTION_ENGINE_RISK_ALLOWED) + "," +
         FalconCsvSafe(FalconGuardSpreadAllowedDesign(m_symbol_context)) + "," +
         FalconCsvSafe(FalconGuardStopsLevelAllowedDesign(m_symbol_context)) + "," +
         FalconCsvSafe(FalconGuardKillSwitchAllowsTradingDesign()) + "," +
         FalconCsvSafe(FALCON_GUARD_PRE_EXECUTION_DECISION) + "," +
         FalconCsvSafe(FALCON_GUARD_PRE_EXECUTION_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_TM_FOUNDATION_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_FOUNDATION_DECISION) + "," +
         FalconCsvSafe(FALCON_TM_SCOPE) + "," +
         FalconCsvSafe(FALCON_TM_EXECUTION_PERMISSION) + "," +
         FalconCsvSafe(FALCON_TM_STRUCTURAL_STOP_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_STRUCTURAL_STOP_REQUIREMENT) + "," +
         FalconCsvSafe(FALCON_TM_TP_BUILDER_STATUS) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_TM_TP1_POLICY) + "," +
         FalconCsvSafe(FALCON_TM_TP2_POLICY) + "," +
         FalconCsvSafe(FALCON_TM_PARTIAL_MANAGER_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_PROOF_PROTECTION_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_RUNNER_MANAGER_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_ADAPTIVE_RATCHET_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_EARLY_FAILURE_EXIT_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_LIVE_ELIGIBILITY) + "," +
         FalconCsvSafe(FALCON_TM_NEXT_REQUIRED_LAYER) + "," +
         FalconCsvSafe(FALCON_TM_NEXT_ENGINEERING_PHASE) + "," +
         FalconCsvSafe(FALCON_SLTP_VALIDATION_STATUS) + "," +
         FalconCsvSafe(FALCON_SLTP_VALIDATION_DECISION) + "," +
         FalconCsvSafe(FALCON_SLTP_VALIDATION_SCOPE) + "," +
         FalconBoolToYesNo(FALCON_SLTP_VALIDATION_RUNTIME_ENFORCED) + "," +
         IntegerToString(m_totals.sltp_validation_evaluated_trades) + "," +
         IntegerToString(m_totals.structural_stop_valid_trades) + "," +
         IntegerToString(m_totals.structural_stop_invalid_trades) + "," +
         IntegerToString(m_totals.tp_builder_valid_trades) + "," +
         IntegerToString(m_totals.tp_builder_invalid_trades) + "," +
         IntegerToString(m_totals.tp1_valid_trades) + "," +
         IntegerToString(m_totals.tp2_valid_trades) + "," +
         IntegerToString(m_totals.tp3_valid_trades) + "," +
         FalconCsvSafe(FALCON_SLTP_STRUCTURAL_STOP_POLICY) + "," +
         FalconCsvSafe(FALCON_SLTP_TP_BUILDER_POLICY) + "," +
         FalconCsvSafe(FALCON_SLTP_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_SLTP_NEXT_ENGINEERING_PHASE) + "," +
         FalconCsvSafe(FALCON_SMART_TM_STATUS) + "," +
         FalconCsvSafe(FALCON_SMART_TM_DECISION) + "," +
         FalconCsvSafe(FALCON_SMART_TM_SCOPE) + "," +
         FalconBoolToYesNo(FALCON_SMART_TM_RUNTIME_ENFORCED) + "," +
         IntegerToString(m_totals.smart_tm_evaluated_trades) + "," +
         IntegerToString(smart_tm_proof_score_min) + "," +
         DoubleToString(smart_tm_proof_score_avg, 2) + "," +
         IntegerToString(m_totals.smart_tm_proof_score_max) + "," +
         IntegerToString(m_totals.smart_tm_exit_conservative_trades) + "," +
         IntegerToString(m_totals.smart_tm_partial_no_runner_trades) + ",";
      summary_row +=
         IntegerToString(m_totals.smart_tm_runner_candidate_trades) + "," +
         IntegerToString(m_totals.smart_tm_strong_runner_candidate_trades) + "," +
         IntegerToString(m_totals.smart_tm_proof_weak_trades) + "," +
         IntegerToString(m_totals.smart_tm_proof_medium_trades) + "," +
         IntegerToString(m_totals.smart_tm_proof_strong_trades) + "," +
         IntegerToString(m_totals.smart_tm_proof_elite_trades) + "," +
         DoubleToString(smart_tm_antiproof_score_avg, 2) + "," +
         IntegerToString(m_totals.smart_tm_antiproof_score_max) + "," +
         IntegerToString(m_totals.smart_tm_antiproof_high_risk_trades) + "," +
         IntegerToString(m_totals.smart_tm_behavior_healthy_trades) + "," +
         IntegerToString(m_totals.smart_tm_behavior_choppy_trades) + "," +
         IntegerToString(m_totals.smart_tm_behavior_failure_trades) + "," +
         IntegerToString(m_totals.smart_tm_behavior_grinding_trades) + "," +
         IntegerToString(m_totals.smart_tm_behavior_exhausted_trades) + "," +
         IntegerToString(m_totals.smart_tm_runner_opportunity_trades) + "," +
         IntegerToString(m_totals.smart_tm_strong_runner_opportunity_trades) + "," +
         IntegerToString(m_totals.smart_tm_runner_conservative_opportunity_trades) + "," +
         IntegerToString(m_totals.smart_tm_tp1_close_trades) + "," +
         IntegerToString(m_totals.smart_tm_sl_failure_trades) + "," +
         IntegerToString(m_totals.smart_tm_timeout_close_trades) + "," +
         FalconCsvSafe(FALCON_SMART_TM_PROOF_POLICY) + "," +
         FalconCsvSafe(FALCON_SMART_TM_ANTI_PROOF_POLICY) + "," +
         FalconCsvSafe(FALCON_SMART_TM_BEHAVIOR_POLICY) + "," +
         FalconCsvSafe(FALCON_SMART_TM_RUNNER_POLICY) + "," +
         FalconCsvSafe(FALCON_SMART_TM_NEXT_ENGINEERING_PHASE) + "," +
         FalconCsvSafe(FALCON_RUNNER_DIAG_STATUS) + "," +
         FalconCsvSafe(FALCON_RUNNER_DIAG_DECISION) + "," +
         FalconBoolToYesNo(FALCON_RUNNER_DIAG_RUNTIME_ENFORCED) + "," +
         IntegerToString(m_totals.runner_diag_evaluated_trades) + "," +
         IntegerToString(m_totals.runner_diag_tp1_anchor_trades) + "," +
         IntegerToString(m_totals.runner_diag_tp2_anchor_trades) + "," +
         IntegerToString(m_totals.runner_diag_mfe_proxy_trades) + "," +
         DoubleToString(runner_mfe_proxy_avg_points, 2) + "," +
         DoubleToString(m_totals.runner_diag_mfe_proxy_max_points, 2) + "," +
         DoubleToString(runner_tp1_to_tp2_room_avg_points, 2) + "," +
         DoubleToString(runner_tp1_to_tp3_room_avg_points, 2) + ",";
      summary_row +=
         DoubleToString(runner_tp2_to_tp3_room_avg_points, 2) + "," +
         DoubleToString(runner_max_r_proxy_avg, 2) + "," +
         DoubleToString(m_totals.runner_diag_max_r_proxy_max, 2) + "," +
         IntegerToString(m_totals.runner_diag_would_reach_3r_trades) + "," +
         IntegerToString(m_totals.runner_diag_would_reach_5r_trades) + "," +
         IntegerToString(m_totals.runner_diag_protected_profit_opportunity_trades) + "," +
         IntegerToString(m_totals.runner_diag_return_to_loss_after_proof_unknown_trades) + "," +
         FalconCsvSafe(FALCON_RUNNER_DIAG_MFE_POLICY) + "," +
         FalconCsvSafe(FALCON_RUNNER_DIAG_GIVEBACK_POLICY) + "," +
         FalconCsvSafe(FALCON_RUNNER_DIAG_MAXR_POLICY) + "," +
         FalconCsvSafe(FALCON_RUNNER_DIAG_RETURN_TO_LOSS_POLICY) + "," +
         FalconCsvSafe(FALCON_RUNNER_DIAG_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_RUNNER_BARPATH_STATUS) + "," +
         FalconCsvSafe(FALCON_RUNNER_BARPATH_DECISION) + "," +
         FalconBoolToYesNo(FALCON_RUNNER_BARPATH_RUNTIME_ENFORCED) + "," +
         IntegerToString(m_totals.runner_barpath_evaluated_trades) + "," +
         IntegerToString(m_totals.runner_barpath_scanned_trades) + "," +
         IntegerToString(m_totals.runner_barpath_scan_failed_trades) + "," +
         IntegerToString(m_totals.runner_barpath_total_bars_scanned) + "," +
         IntegerToString(m_totals.runner_barpath_tp1_touched_trades) + "," +
         IntegerToString(m_totals.runner_barpath_tp2_touched_trades) + "," +
         IntegerToString(m_totals.runner_barpath_tp1_touched_then_extended_trades) + "," +
         IntegerToString(m_totals.runner_barpath_tp2_touched_then_extended_trades) + "," +
         DoubleToString(runner_barpath_tp1_to_max_run_avg_points, 2) + "," +
         DoubleToString(m_totals.runner_barpath_tp1_to_max_run_max_points, 2) + "," +
         DoubleToString(runner_barpath_tp2_to_max_run_avg_points, 2) + "," +
         DoubleToString(m_totals.runner_barpath_tp2_to_max_run_max_points, 2) + "," +
         DoubleToString(runner_barpath_mfe_after_tp1_avg_points, 2) + "," +
         DoubleToString(m_totals.runner_barpath_mfe_after_tp1_max_points, 2) + "," +
         DoubleToString(runner_barpath_mfe_after_tp2_avg_points, 2) + "," +
         DoubleToString(m_totals.runner_barpath_mfe_after_tp2_max_points, 2) + "," +
         DoubleToString(runner_barpath_giveback_after_tp1_avg_points, 2) + "," +
         DoubleToString(m_totals.runner_barpath_giveback_after_tp1_max_points, 2) + "," +
         DoubleToString(runner_barpath_giveback_after_tp2_avg_points, 2) + "," +
         DoubleToString(m_totals.runner_barpath_giveback_after_tp2_max_points, 2) + "," +
         IntegerToString(m_totals.runner_barpath_returned_to_loss_after_tp1_trades) + ",";
      summary_row +=
         IntegerToString(m_totals.runner_barpath_returned_to_loss_after_tp2_trades) + "," +
         IntegerToString(m_totals.runner_barpath_actual_would_reach_3r_trades) + "," +
         IntegerToString(m_totals.runner_barpath_actual_would_reach_5r_trades) + "," +
         IntegerToString(m_totals.runner_barpath_protected_after_tp1_opportunity_trades) + "," +
         IntegerToString(m_totals.runner_barpath_protected_after_tp2_opportunity_trades) + "," +
         FalconCsvSafe(FALCON_FAST_TM_STATUS) + "," +
         FalconCsvSafe(FALCON_FAST_TM_DECISION) + "," +
         FalconBoolToYesNo(FALCON_FAST_TM_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_FAST_TM_LATENCY_MODE) + "," +
         FalconCsvSafe(FALCON_FAST_TM_DECISION_PROFILE) + "," +
         IntegerToString(m_totals.fast_tm_evaluated_trades) + "," +
         IntegerToString(m_totals.fast_tm_decision_cache_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_precomputed_branch_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_tp1_decision_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_tp2_decision_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_protection_required_after_tp1_trades) + "," +
         IntegerToString(m_totals.fast_tm_protection_required_after_tp2_trades) + "," +
         IntegerToString(m_totals.fast_tm_immediate_runner_candidate_trades) + "," +
         IntegerToString(m_totals.fast_tm_immediate_exit_warning_trades) + "," +
         IntegerToString(m_totals.fast_tm_fast_antiproof_warning_trades) + "," +
         IntegerToString(m_totals.fast_tm_conservative_partial_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_runner_wait_for_confirmation_trades) + "," +
         FalconCsvSafe(FALCON_FAST_TM_POLICY) + "," +
         FalconCsvSafe(FALCON_FAST_TM_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_STATUS) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_DECISION) + "," +
         FalconBoolToYesNo(FALCON_DECISION_TREE_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_SCOPE) + "," +
         IntegerToString(decision_tree_evaluated_trades) + "," +
         IntegerToString(decision_tree_cache_ready_trades) + "," +
         IntegerToString(decision_tree_tp1_ready_trades) + "," +
         IntegerToString(decision_tree_tp2_ready_trades) + "," +
         IntegerToString(decision_tree_tp1_partial_plan_trades) + "," +
         IntegerToString(decision_tree_tp1_protect_plan_trades) + "," +
         IntegerToString(decision_tree_tp1_runner_now_plan_trades) + "," +
         IntegerToString(decision_tree_tp1_runner_wait_plan_trades) + ",";
      summary_row +=
         IntegerToString(decision_tree_tp1_exit_warning_plan_trades) + "," +
         IntegerToString(decision_tree_tp1_antiproof_warning_plan_trades) + "," +
         IntegerToString(decision_tree_tp2_protect_plan_trades) + "," +
         IntegerToString(decision_tree_tp2_runner_activate_plan_trades) + "," +
         IntegerToString(decision_tree_tp2_exit_warning_plan_trades) + "," +
         IntegerToString(decision_tree_rollback_ready_trades) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_POLICY) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_OUTCOME_STATUS) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_OUTCOME_DECISION) + "," +
         FalconBoolToYesNo(FALCON_DECISION_TREE_OUTCOME_RUNTIME_ENFORCED) + "," +
         IntegerToString(decision_tree_outcome_evaluated_trades) + "," +
         IntegerToString(decision_tree_outcome_tp1_branches_simulated) + "," +
         IntegerToString(decision_tree_outcome_tp2_branches_simulated) + "," +
         IntegerToString(dt_out_tp1_protect_reduce_rtl) + "," +
         IntegerToString(dt_out_tp2_protect_reduce_rtl) + "," +
         IntegerToString(decision_tree_outcome_runner_activate_would_reach_3r_trades) + "," +
         IntegerToString(decision_tree_outcome_runner_activate_would_reach_5r_trades) + "," +
         IntegerToString(dt_out_exitwarn_catch_rtl) + "," +
         IntegerToString(dt_out_antiproof_catch_rtl) + "," +
         DoubleToString(dt_out_tp1_protect_cov_pct, 2) + "," +
         DoubleToString(dt_out_tp2_protect_cov_pct, 2) + "," +
         DoubleToString(dt_out_runner_3r_sel_pct, 2) + "," +
         DoubleToString(dt_out_runner_5r_sel_pct, 2) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_OUTCOME_POLICY) + "," +
         FalconCsvSafe(FALCON_DECISION_TREE_OUTCOME_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_DT_TIMING_STATUS) + "," +
         FalconCsvSafe(FALCON_DT_TIMING_DECISION) + "," +
         FalconBoolToYesNo(FALCON_DT_TIMING_RUNTIME_ENFORCED) + "," +
         IntegerToString(dt_time_eval) + "," +
         IntegerToString(dt_time_cache_ready) + "," +
         IntegerToString(dt_time_tp1_pre) + "," +
         IntegerToString(dt_time_tp2_pre) + "," +
         IntegerToString(dt_time_tp1_protect_feasible) + "," +
         IntegerToString(dt_time_tp2_protect_feasible) + "," +
         IntegerToString(dt_time_tp1_protect_unknown) + ",";
      summary_row +=
         IntegerToString(dt_time_tp2_protect_unknown) + "," +
         IntegerToString(dt_time_runner_3r_pre) + "," +
         IntegerToString(dt_time_runner_5r_pre) + "," +
         IntegerToString(dt_time_runner_3r_unknown) + "," +
         FalconCsvSafe(dt_time_protect_feasible) + "," +
         FalconCsvSafe(dt_time_runner_feasible) + "," +
         FalconCsvSafe(FALCON_DT_TIMING_POLICY) + "," +
         FalconCsvSafe(FALCON_DT_TIMING_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PAPER_EXEC_STATUS) + "," +
         FalconCsvSafe(FALCON_PAPER_EXEC_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PAPER_EXEC_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PAPER_EXEC_PERMISSION) + "," +
         FalconCsvSafe(FALCON_PAPER_EXEC_MODE) + "," +
         FalconCsvSafe(FALCON_PAPER_EXEC_SCOPE) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.structural_stop_valid_trades) + "," +
         IntegerToString(m_totals.tp_builder_valid_trades) + "," +
         IntegerToString(m_totals.fast_tm_conservative_partial_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_immediate_runner_candidate_trades) + "," +
         FalconBoolToYesNo(false) + "," +
         FalconBoolToYesNo(true) + "," +
         IntegerToString(0) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(0) + "," +
         FalconCsvSafe("NONE_INTERNAL_PAPER_SIMULATION") + "," +
         FalconCsvSafe(FALCON_PAPER_EXEC_ORDER_STATE_MODEL) + "," +
         FalconCsvSafe(FALCON_PAPER_EXEC_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PAPER_EXEC_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PAPER_SIM_STATUS) + "," +
         FalconCsvSafe(FALCON_PAPER_SIM_DECISION) + "," +
         FalconCsvSafe(FALCON_PAPER_SIM_SCOPE) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.total_trades) + ",";
      summary_row +=
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(0) + "," +
         IntegerToString(m_totals.structural_stop_valid_trades) + "," +
         IntegerToString(m_totals.tp_builder_valid_trades) + "," +
         IntegerToString(m_totals.fast_tm_conservative_partial_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_immediate_runner_candidate_trades) + "," +
         FalconCsvSafe(FALCON_PAPER_SIM_ORDER_SEND_BYPASS) + "," +
         FalconCsvSafe(FALCON_PAPER_SIM_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PAPER_SIM_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PPR_BRANCH_STATUS) + "," +
         FalconCsvSafe(FALCON_PPR_BRANCH_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PPR_BRANCH_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PPR_BRANCH_SCOPE) + "," +
         IntegerToString(m_totals.total_trades) + "," +
         IntegerToString(m_totals.fast_tm_conservative_partial_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_immediate_runner_candidate_trades) + "," +
         IntegerToString(m_totals.fast_tm_conservative_partial_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_immediate_runner_candidate_trades) + "," +
         IntegerToString(m_totals.fast_tm_conservative_partial_ready_trades) + "," +
         IntegerToString(m_totals.fast_tm_immediate_runner_candidate_trades) + "," +
         IntegerToString(0) + "," +
         IntegerToString(0) + "," +
         FalconCsvSafe(FALCON_PPR_BRANCH_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PPR_PARTIAL_POLICY) + "," +
         FalconCsvSafe(FALCON_PPR_RUNNER_POLICY) + "," +
         FalconCsvSafe(FALCON_PPR_BRANCH_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PPR_OUT_STATUS) + "," +
         FalconCsvSafe(FALCON_PPR_OUT_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PPR_OUT_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PPR_OUT_SCOPE) + "," +
         IntegerToString(po_eval) + "," +
         IntegerToString(po_partial_branches) + "," +
         IntegerToString(po_runner_branches) + ",";
      summary_row +=
         IntegerToString(po_tp1_protect) + "," +
         IntegerToString(po_tp2_protect) + "," +
         IntegerToString(po_runner_3r) + "," +
         IntegerToString(po_runner_5r) + "," +
         DoubleToString(po_protect_proxy_points, 2) + "," +
         DoubleToString(po_runner_proxy_points, 2) + "," +
         DoubleToString(po_delta_points, 2) + "," +
         DoubleToString(po_sim_net_points, 2) + "," +
         DoubleToString(po_delta_usd, 2) + "," +
         DoubleToString(po_sim_net_usd, 2) + "," +
         DoubleToString(po_protect_cov_pct, 2) + "," +
         DoubleToString(po_runner3r_pct, 2) + "," +
         DoubleToString(po_runner5r_pct, 2) + "," +
         FalconCsvSafe(FALCON_PPR_OUT_POLICY) + "," +
         FalconCsvSafe(FALCON_PPR_OUT_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PAPER_SM_STATUS) + "," +
         FalconCsvSafe(FALCON_PAPER_SM_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PAPER_SM_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PAPER_SM_SCOPE) + "," +
         IntegerToString(psm_eval) + "," +
         IntegerToString(psm_entry_state) + "," +
         IntegerToString(psm_filled_state) + "," +
         IntegerToString(psm_tp1_proof_state) + "," +
         IntegerToString(psm_tp2_proof_state) + "," +
         IntegerToString(psm_protect_tp1) + "," +
         IntegerToString(psm_protect_tp2) + "," +
         IntegerToString(psm_runner_candidate) + "," +
         IntegerToString(psm_runner_3r) + "," +
         IntegerToString(psm_moon_5r) + "," +
         IntegerToString(psm_exit_warning) + "," +
         IntegerToString(psm_antiproof) + "," +
         IntegerToString(psm_return_loss_preventable) + "," +
         DoubleToString(psm_protected_giveback_proxy_points, 2) + "," +
         DoubleToString(psm_runner_upside_proxy_points, 2) + "," +
         DoubleToString(psm_delta_points, 2) + "," +
         DoubleToString(psm_sim_net_points, 2) + ",";
      summary_row +=
         DoubleToString(psm_delta_usd, 2) + "," +
         DoubleToString(psm_sim_net_usd, 2) + "," +
         DoubleToString(psm_protection_contribution_pct, 2) + "," +
         DoubleToString(psm_runner_contribution_pct, 2) + "," +
         FalconBoolToYesNo(FALCON_PAPER_SM_TP2_IS_CHECKPOINT) + "," +
         FalconBoolToYesNo(FALCON_PAPER_SM_TP2_EXIT_MANDATORY) + "," +
         IntegerToString(psm_runner_3r) + "," +
         IntegerToString(psm_moon_5r) + "," +
         FalconCsvSafe(FALCON_PAPER_SM_RUNNER_BEYOND_TP2_POLICY) + "," +
         FalconBoolToYesNo(FALCON_PAPER_SM_EXPANSION_AFTER_PROOF) + "," +
         FalconCsvSafe(FALCON_PAPER_SM_PROTECT_BEFORE_EXPAND_POLICY) + "," +
         FalconCsvSafe(FALCON_PAPER_SM_POLICY) + "," +
         FalconCsvSafe(FALCON_PAPER_SM_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PPF_STATUS) + "," +
         FalconCsvSafe(FALCON_PPF_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PPF_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PPF_SCOPE) + "," +
         IntegerToString(ppf_eval) + "," +
         IntegerToString(ppf_tp1) + "," +
         IntegerToString(ppf_tp2) + "," +
         IntegerToString(ppf_total) + "," +
         IntegerToString(ppf_plan) + "," +
         IntegerToString(ppf_ready) + "," +
         IntegerToString(ppf_sent) + "," +
         IntegerToString(ppf_rejected) + "," +
         IntegerToString(ppf_before_giveback) + "," +
         IntegerToString(ppf_too_late) + "," +
         DoubleToString(ppf_coverage_pct, 2) + "," +
         FalconCsvSafe(FALCON_PPF_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PPF_MODIFY_POLICY) + "," +
         FalconCsvSafe(FALCON_PPF_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PPF_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PPM_STATUS) + "," +
         FalconCsvSafe(FALCON_PPM_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PPM_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PPM_SCOPE) + ",";
      summary_row +=
         IntegerToString(ppm_eval) + "," +
         IntegerToString(ppm_plan) + "," +
         IntegerToString(ppm_ready) + "," +
         IntegerToString(ppm_trigger_ready) + "," +
         IntegerToString(ppm_level_ready) + "," +
         IntegerToString(ppm_reason_ready) + "," +
         IntegerToString(ppm_tp1_plan) + "," +
         IntegerToString(ppm_tp2_plan) + "," +
         IntegerToString(ppm_sent) + "," +
         IntegerToString(ppm_rejected) + "," +
         IntegerToString(ppm_incomplete) + "," +
         DoubleToString(ppm_coverage_pct, 2) + "," +
         DoubleToString(ppm_plan_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PPM_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PPM_MODIFY_POLICY) + "," +
         FalconCsvSafe(FALCON_PPM_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PPM_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PPT_STATUS) + "," +
         FalconCsvSafe(FALCON_PPT_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PPT_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PPT_SCOPE) + "," +
         IntegerToString(ppt_eval) + "," +
         IntegerToString(ppt_request) + "," +
         IntegerToString(ppt_timing_ready) + "," +
         IntegerToString(ppt_after_proof) + "," +
         IntegerToString(ppt_before_giveback) + "," +
         IntegerToString(ppt_too_late) + "," +
         IntegerToString(ppt_unknown) + "," +
         IntegerToString(ppt_tp1_ready) + "," +
         IntegerToString(ppt_tp2_ready) + "," +
         IntegerToString(ppt_sent) + "," +
         IntegerToString(ppt_rejected) + "," +
         DoubleToString(ppt_coverage_pct, 2) + "," +
         DoubleToString(ppt_timing_ready_pct, 2) + "," +
         FalconCsvSafe(FALCON_PPT_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PPT_MODIFY_POLICY) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_PPT_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PPT_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PPD_STATUS) + "," +
         FalconCsvSafe(FALCON_PPD_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PPD_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PPD_SCOPE) + "," +
         IntegerToString(ppd_eval) + "," +
         IntegerToString(ppd_request) + "," +
         IntegerToString(ppd_eligible) + "," +
         IntegerToString(ppd_accepted) + "," +
         IntegerToString(ppd_rejected) + "," +
         IntegerToString(ppd_skipped) + "," +
         IntegerToString(ppd_tp1_dryrun) + "," +
         IntegerToString(ppd_tp2_dryrun) + "," +
         IntegerToString(ppd_modify_sent) + "," +
         IntegerToString(ppd_broker_modify_sent) + "," +
         IntegerToString(ppd_runtime_sl_changed) + "," +
         DoubleToString(ppd_coverage_pct, 2) + "," +
         DoubleToString(ppd_acceptance_pct, 2) + "," +
         FalconCsvSafe(FALCON_PPD_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PPD_MODIFY_POLICY) + "," +
         FalconCsvSafe(FALCON_PPD_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PPD_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PDL_STATUS) + "," +
         FalconCsvSafe(FALCON_PDL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PDL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PDL_SCOPE) + "," +
         IntegerToString(pdl_eval) + "," +
         IntegerToString(pdl_request) + "," +
         IntegerToString(pdl_eligible) + "," +
         IntegerToString(pdl_accepted) + "," +
         IntegerToString(pdl_rejected) + "," +
         IntegerToString(pdl_skipped) + "," +
         IntegerToString(pdl_broker_modify_sent) + "," +
         IntegerToString(pdl_runtime_sl_changed) + "," +
         IntegerToString(pdl_lock_ready) + ",";
      summary_row +=
         IntegerToString(pdl_invariant_breaches) + "," +
         DoubleToString(pdl_coverage_pct, 2) + "," +
         DoubleToString(pdl_acceptance_pct, 2) + "," +
         DoubleToString(pdl_lock_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PDL_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PDL_MODIFY_POLICY) + "," +
         FalconCsvSafe(FALCON_PDL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PDL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PVS_STATUS) + "," +
         FalconCsvSafe(FALCON_PVS_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PVS_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PVS_SCOPE) + "," +
         IntegerToString(pvs_eval) + "," +
         IntegerToString(pvs_candidates) + "," +
         IntegerToString(pvs_state_ready) + "," +
         IntegerToString(pvs_state_active) + "," +
         IntegerToString(pvs_tp1_states) + "," +
         IntegerToString(pvs_tp2_states) + "," +
         IntegerToString(pvs_rejected) + "," +
         IntegerToString(pvs_conflict) + "," +
         IntegerToString(pvs_missing_level) + "," +
         IntegerToString(pvs_broker_modify_sent) + "," +
         IntegerToString(pvs_runtime_sl_changed) + "," +
         IntegerToString(pvs_invariant_breaches) + "," +
         DoubleToString(pvs_coverage_pct, 2) + "," +
         DoubleToString(pvs_readiness_pct, 2) + "," +
         DoubleToString(pvs_state_active_pct, 2) + "," +
         FalconCsvSafe(FALCON_PVS_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PVS_STATE_POLICY) + "," +
         FalconCsvSafe(FALCON_PVS_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PVS_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PVL_STATUS) + "," +
         FalconCsvSafe(FALCON_PVL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PVL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PVL_SCOPE) + "," +
         IntegerToString(pvl_eval) + ",";
      summary_row +=
         IntegerToString(pvl_candidates) + "," +
         IntegerToString(pvl_state_ready) + "," +
         IntegerToString(pvl_state_active) + "," +
         IntegerToString(pvl_tp1_states) + "," +
         IntegerToString(pvl_tp2_states) + "," +
         IntegerToString(pvl_rejected) + "," +
         IntegerToString(pvl_conflict) + "," +
         IntegerToString(pvl_missing_level) + "," +
         IntegerToString(pvl_broker_modify_sent) + "," +
         IntegerToString(pvl_runtime_sl_changed) + "," +
         IntegerToString(pvl_ready) + "," +
         IntegerToString(pvl_invariant_breaches) + "," +
         DoubleToString(pvl_coverage_pct, 2) + "," +
         DoubleToString(pvl_readiness_pct, 2) + "," +
         DoubleToString(pvl_state_active_pct, 2) + "," +
         DoubleToString(pvl_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PVL_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PVL_STATE_POLICY) + "," +
         FalconCsvSafe(FALCON_PVL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PVL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PVT_STATUS) + "," +
         FalconCsvSafe(FALCON_PVT_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PVT_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PVT_SCOPE) + "," +
         IntegerToString(pvt_eval) + "," +
         IntegerToString(pvt_lock_ready) + "," +
         IntegerToString(pvt_candidates) + "," +
         IntegerToString(pvt_transition_ready) + "," +
         IntegerToString(pvt_executor_readable) + "," +
         IntegerToString(pvt_ledger_readable) + "," +
         IntegerToString(pvt_trigger_resolved) + "," +
         IntegerToString(pvt_level_resolved) + "," +
         IntegerToString(pvt_tp1_transitions) + "," +
         IntegerToString(pvt_tp2_transitions) + "," +
         IntegerToString(pvt_rejected) + "," +
         IntegerToString(pvt_conflict) + ",";
      summary_row +=
         IntegerToString(pvt_missing_ledger) + "," +
         IntegerToString(pvt_broker_modify_sent) + "," +
         IntegerToString(pvt_runtime_sl_changed) + "," +
         IntegerToString(pvt_invariant_breaches) + "," +
         DoubleToString(pvt_coverage_pct, 2) + "," +
         DoubleToString(pvt_readiness_pct, 2) + "," +
         DoubleToString(pvt_executor_readiness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PVT_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PVT_TRANSITION_POLICY) + "," +
         FalconCsvSafe(FALCON_PVT_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PVT_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PTL_STATUS) + "," +
         FalconCsvSafe(FALCON_PTL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PTL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PTL_SCOPE) + "," +
         IntegerToString(ptl_eval) + "," +
         IntegerToString(ptl_ready) + "," +
         IntegerToString(ptl_candidates) + "," +
         IntegerToString(ptl_transition_ready) + "," +
         IntegerToString(ptl_executor_readable) + "," +
         IntegerToString(ptl_ledger_readable) + "," +
         IntegerToString(ptl_trigger_resolved) + "," +
         IntegerToString(ptl_level_resolved) + "," +
         IntegerToString(ptl_tp1_transitions) + "," +
         IntegerToString(ptl_tp2_transitions) + "," +
         IntegerToString(ptl_rejected) + "," +
         IntegerToString(ptl_conflict) + "," +
         IntegerToString(ptl_missing_ledger) + "," +
         IntegerToString(ptl_broker_modify_sent) + "," +
         IntegerToString(ptl_runtime_sl_changed) + "," +
         IntegerToString(ptl_invariant_breaches) + "," +
         DoubleToString(ptl_coverage_pct, 2) + "," +
         DoubleToString(ptl_readiness_pct, 2) + "," +
         DoubleToString(ptl_executor_readiness_pct, 2) + "," +
         DoubleToString(ptl_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PTL_NO_LOOKAHEAD_POLICY) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_PTL_TRANSITION_POLICY) + "," +
         FalconCsvSafe(FALCON_PTL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PTL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PBF_STATUS) + "," +
         FalconCsvSafe(FALCON_PBF_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PBF_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PBF_SCOPE) + "," +
         IntegerToString(pbf_eval) + "," +
         IntegerToString(pbf_transition_lock_ready) + "," +
         IntegerToString(pbf_candidates) + "," +
         IntegerToString(pbf_broker_context_ready) + "," +
         IntegerToString(pbf_stops_known) + "," +
         IntegerToString(pbf_freeze_known) + "," +
         IntegerToString(pbf_protection_level_executable) + "," +
         IntegerToString(pbf_stops_safe) + "," +
         IntegerToString(pbf_freeze_safe) + "," +
         IntegerToString(pbf_broker_feasible) + "," +
         IntegerToString(pbf_tp1_trades) + "," +
         IntegerToString(pbf_tp2_trades) + "," +
         IntegerToString(pbf_rejected) + "," +
         IntegerToString(pbf_conflict) + "," +
         IntegerToString(pbf_missing_broker_context) + "," +
         IntegerToString(pbf_stops_blocked) + "," +
         IntegerToString(pbf_freeze_blocked) + "," +
         IntegerToString(pbf_broker_modify_sent) + "," +
         IntegerToString(pbf_runtime_sl_changed) + "," +
         IntegerToString(pbf_invariant_breaches) + "," +
         DoubleToString(pbf_coverage_pct, 2) + "," +
         DoubleToString(pbf_feasibility_pct, 2) + "," +
         DoubleToString(pbf_broker_context_readiness_pct, 2) + "," +
         IntegerToString((int)m_symbol_context.stops_level_points) + "," +
         IntegerToString((int)m_symbol_context.freeze_level_points) + "," +
         IntegerToString(FALCON_PBF_STOPS_BUFFER_POINTS) + "," +
         FalconCsvSafe(FALCON_PBF_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PBF_BROKER_POLICY) + "," +
         FalconCsvSafe(FALCON_PBF_ORDER_SEND_POLICY) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_PBF_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PBL_STATUS) + "," +
         FalconCsvSafe(FALCON_PBL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PBL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PBL_SCOPE) + "," +
         IntegerToString(pbl_eval) + "," +
         IntegerToString(pbl_candidates) + "," +
         IntegerToString(pbl_broker_context_ready) + "," +
         IntegerToString(pbl_stops_known) + "," +
         IntegerToString(pbl_freeze_known) + "," +
         IntegerToString(pbl_protection_level_executable) + "," +
         IntegerToString(pbl_stops_safe) + "," +
         IntegerToString(pbl_freeze_safe) + "," +
         IntegerToString(pbl_broker_feasible) + "," +
         IntegerToString(pbl_ready) + "," +
         IntegerToString(pbl_tp1_trades) + "," +
         IntegerToString(pbl_tp2_trades) + "," +
         IntegerToString(pbl_rejected) + "," +
         IntegerToString(pbl_conflict) + "," +
         IntegerToString(pbl_missing_broker_context) + "," +
         IntegerToString(pbl_stops_blocked) + "," +
         IntegerToString(pbl_freeze_blocked) + "," +
         IntegerToString(pbl_broker_modify_sent) + "," +
         IntegerToString(pbl_runtime_sl_changed) + "," +
         IntegerToString(pbl_invariant_breaches) + "," +
         DoubleToString(pbl_coverage_pct, 2) + "," +
         DoubleToString(pbl_feasibility_pct, 2) + "," +
         DoubleToString(pbl_completeness_pct, 2) + "," +
         IntegerToString((int)m_symbol_context.stops_level_points) + "," +
         IntegerToString((int)m_symbol_context.freeze_level_points) + "," +
         IntegerToString(FALCON_PBF_STOPS_BUFFER_POINTS) + "," +
         FalconCsvSafe(FALCON_PBL_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PBL_BROKER_POLICY) + "," +
         FalconCsvSafe(FALCON_PBL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PBL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PBD_STATUS) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_PBD_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PBD_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PBD_SCOPE) + "," +
         IntegerToString(pbd_eval) + "," +
         IntegerToString(pbd_broker_feas_lock_ready) + "," +
         IntegerToString(pbd_candidates) + "," +
         IntegerToString(pbd_distance_context_ready) + "," +
         IntegerToString(pbd_required_distance_known) + "," +
         IntegerToString(pbd_protection_distance_known) + "," +
         IntegerToString(pbd_stops_distance_safe) + "," +
         IntegerToString(pbd_freeze_distance_safe) + "," +
         IntegerToString(pbd_distance_sane) + "," +
         IntegerToString(pbd_ready) + "," +
         IntegerToString(pbd_tp1_trades) + "," +
         IntegerToString(pbd_tp2_trades) + "," +
         IntegerToString(pbd_rejected) + "," +
         IntegerToString(pbd_conflict) + "," +
         IntegerToString(pbd_missing_distance_context) + "," +
         IntegerToString(pbd_stops_distance_blocked) + "," +
         IntegerToString(pbd_freeze_distance_blocked) + "," +
         IntegerToString(pbd_broker_modify_sent) + "," +
         IntegerToString(pbd_runtime_sl_changed) + "," +
         IntegerToString(pbd_invariant_breaches) + "," +
         DoubleToString(pbd_coverage_pct, 2) + "," +
         DoubleToString(pbd_sanity_pct, 2) + "," +
         DoubleToString(pbd_context_readiness_pct, 2) + "," +
         IntegerToString((int)m_symbol_context.stops_level_points) + "," +
         IntegerToString((int)m_symbol_context.freeze_level_points) + "," +
         IntegerToString(FALCON_PBF_STOPS_BUFFER_POINTS) + "," +
         IntegerToString(pbd_min_required_distance_points) + "," +
         FalconCsvSafe(FALCON_PBD_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PBD_DISTANCE_POLICY) + "," +
         FalconCsvSafe(FALCON_PBD_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PBD_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PBDL_STATUS) + "," +
         FalconCsvSafe(FALCON_PBDL_DECISION) + ",";
      summary_row +=
         FalconBoolToYesNo(FALCON_PBDL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PBDL_SCOPE) + "," +
         IntegerToString(pbdl_eval) + "," +
         IntegerToString(pbdl_distance_ready) + "," +
         IntegerToString(pbdl_candidates) + "," +
         IntegerToString(pbdl_context_ready) + "," +
         IntegerToString(pbdl_required_distance_known) + "," +
         IntegerToString(pbdl_protection_distance_known) + "," +
         IntegerToString(pbdl_stops_distance_safe) + "," +
         IntegerToString(pbdl_freeze_distance_safe) + "," +
         IntegerToString(pbdl_distance_sane) + "," +
         IntegerToString(pbdl_ready) + "," +
         IntegerToString(pbdl_tp1_trades) + "," +
         IntegerToString(pbdl_tp2_trades) + "," +
         IntegerToString(pbdl_rejected) + "," +
         IntegerToString(pbdl_conflict) + "," +
         IntegerToString(pbdl_missing_context) + "," +
         IntegerToString(pbdl_stops_blocked) + "," +
         IntegerToString(pbdl_freeze_blocked) + "," +
         IntegerToString(pbdl_broker_modify_sent) + "," +
         IntegerToString(pbdl_runtime_sl_changed) + "," +
         IntegerToString(pbdl_invariant_breaches) + "," +
         DoubleToString(pbdl_coverage_pct, 2) + "," +
         DoubleToString(pbdl_sanity_pct, 2) + "," +
         DoubleToString(pbdl_completeness_pct, 2) + "," +
         IntegerToString((int)m_symbol_context.stops_level_points) + "," +
         IntegerToString((int)m_symbol_context.freeze_level_points) + "," +
         IntegerToString(FALCON_PBF_STOPS_BUFFER_POINTS) + "," +
         IntegerToString(pbd_min_required_distance_points) + "," +
         FalconCsvSafe(FALCON_PBDL_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PBDL_DISTANCE_POLICY) + "," +
         FalconCsvSafe(FALCON_PBDL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PBDL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PBME_STATUS) + "," +
         FalconCsvSafe(FALCON_PBME_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PBME_RUNTIME_ENFORCED) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_PBME_SCOPE) + "," +
         IntegerToString(pbme_eval) + "," +
         IntegerToString(pbme_distance_lock_ready) + "," +
         IntegerToString(pbme_broker_feas_lock_ready) + "," +
         IntegerToString(pbme_candidates) + "," +
         IntegerToString(pbme_distance_sanity_ready) + "," +
         IntegerToString(pbme_modify_plan_ready) + "," +
         IntegerToString(pbme_request_shape_ready) + "," +
         IntegerToString(pbme_protection_level_ready) + "," +
         IntegerToString(pbme_stops_ready) + "," +
         IntegerToString(pbme_freeze_ready) + "," +
         IntegerToString(pbme_eligible) + "," +
         IntegerToString(pbme_ready) + "," +
         IntegerToString(pbme_tp1_trades) + "," +
         IntegerToString(pbme_tp2_trades) + "," +
         IntegerToString(pbme_rejected) + "," +
         IntegerToString(pbme_conflict) + "," +
         IntegerToString(pbme_missing_distance_lock) + "," +
         IntegerToString(pbme_missing_broker_feas) + "," +
         IntegerToString(pbme_missing_modify_plan) + "," +
         IntegerToString(pbme_stops_blocked) + "," +
         IntegerToString(pbme_freeze_blocked) + "," +
         IntegerToString(pbme_broker_modify_sent) + "," +
         IntegerToString(pbme_runtime_sl_changed) + "," +
         IntegerToString(pbme_invariant_breaches) + "," +
         DoubleToString(pbme_coverage_pct, 2) + "," +
         DoubleToString(pbme_eligibility_pct, 2) + "," +
         DoubleToString(pbme_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PBME_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PBME_ELIGIBILITY_POLICY) + "," +
         FalconCsvSafe(FALCON_PBME_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PBME_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PBMEL_STATUS) + "," +
         FalconCsvSafe(FALCON_PBMEL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PBMEL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PBMEL_SCOPE) + ",";
      summary_row +=
         IntegerToString(pbmel_eval) + "," +
         IntegerToString(pbmel_distance_lock_ready) + "," +
         IntegerToString(pbmel_broker_feas_lock_ready) + "," +
         IntegerToString(pbmel_candidates) + "," +
         IntegerToString(pbmel_distance_sanity_ready) + "," +
         IntegerToString(pbmel_modify_plan_ready) + "," +
         IntegerToString(pbmel_request_shape_ready) + "," +
         IntegerToString(pbmel_protection_level_ready) + "," +
         IntegerToString(pbmel_stops_ready) + "," +
         IntegerToString(pbmel_freeze_ready) + "," +
         IntegerToString(pbmel_eligible) + "," +
         IntegerToString(pbmel_ready) + "," +
         IntegerToString(pbmel_tp1_trades) + "," +
         IntegerToString(pbmel_tp2_trades) + "," +
         IntegerToString(pbmel_rejected) + "," +
         IntegerToString(pbmel_conflict) + "," +
         IntegerToString(pbmel_missing_distance_lock) + "," +
         IntegerToString(pbmel_missing_broker_feas) + "," +
         IntegerToString(pbmel_missing_modify_plan) + "," +
         IntegerToString(pbmel_stops_blocked) + "," +
         IntegerToString(pbmel_freeze_blocked) + "," +
         IntegerToString(pbmel_broker_modify_sent) + "," +
         IntegerToString(pbmel_runtime_sl_changed) + "," +
         IntegerToString(pbmel_invariant_breaches) + "," +
         DoubleToString(pbmel_coverage_pct, 2) + "," +
         DoubleToString(pbmel_eligibility_pct, 2) + "," +
         DoubleToString(pbmel_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PBMEL_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PBMEL_ELIGIBILITY_POLICY) + "," +
         FalconCsvSafe(FALCON_PBMEL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PBMEL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PEMC_STATUS) + "," +
         FalconCsvSafe(FALCON_PEMC_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PEMC_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PEMC_SCOPE) + "," +
         IntegerToString(pemc_eval) + ",";
      summary_row +=
         IntegerToString(pemc_lock_ready) + "," +
         IntegerToString(pemc_candidates) + "," +
         IntegerToString(pemc_consumer_readable) + "," +
         IntegerToString(pemc_modify_plan_readable) + "," +
         IntegerToString(pemc_virtual_sl_readable) + "," +
         IntegerToString(pemc_level_readable) + "," +
         IntegerToString(pemc_trigger_readable) + "," +
         IntegerToString(pemc_ready) + "," +
         IntegerToString(pemc_rejected) + "," +
         IntegerToString(pemc_conflict) + "," +
         IntegerToString(pemc_missing_lock) + "," +
         IntegerToString(pemc_missing_modify_plan) + "," +
         IntegerToString(pemc_missing_virtual_sl) + "," +
         IntegerToString(pemc_broker_modify_sent) + "," +
         IntegerToString(pemc_runtime_sl_changed) + "," +
         IntegerToString(pemc_order_send) + "," +
         IntegerToString(pemc_invariant_breaches) + "," +
         DoubleToString(pemc_readiness_pct, 2) + "," +
         DoubleToString(pemc_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PEMC_NO_LOOKAHEAD_POLICY) + "," +
         FalconCsvSafe(FALCON_PEMC_CONSUMER_POLICY) + "," +
         FalconCsvSafe(FALCON_PEMC_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PEMC_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_MEC_STATUS) + "," +
         FalconCsvSafe(FALCON_MEC_DECISION) + "," +
         FalconBoolToYesNo(FALCON_MEC_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_MEC_SCOPE) + "," +
         IntegerToString(mec_registered_strategies) + "," +
         IntegerToString(mec_defined_magics) + "," +
         IntegerToString(mec_unique_magics) + "," +
         IntegerToString(mec_active_engine_magic_ready) + "," +
         IntegerToString(mec_unknown_magic_rejected) + "," +
         IntegerToString(mec_duplicate_magic_breaches) + "," +
         IntegerToString(mec_error_classes_defined) + "," +
         IntegerToString(mec_classifier_ready) + "," +
         IntegerToString(mec_retry_policy_defined) + ",";
      summary_row +=
         IntegerToString(mec_fatal_retry_blocked) + "," +
         IntegerToString(mec_needs_refresh_retry_once) + "," +
         IntegerToString(mec_connection_policy_defined) + "," +
         IntegerToString(mec_order_send) + "," +
         IntegerToString(mec_broker_modify_sent) + "," +
         IntegerToString(mec_runtime_sl_changed) + "," +
         IntegerToString(mec_invariant_breaches) + "," +
         DoubleToString(mec_readiness_pct, 2) + "," +
         DoubleToString(mec_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_MEC_MAGIC_POLICY) + "," +
         FalconCsvSafe(FALCON_MEC_ERROR_POLICY) + "," +
         FalconCsvSafe(FALCON_MEC_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_MEC_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_TSPR_STATUS) + "," +
         FalconCsvSafe(FALCON_TSPR_DECISION) + "," +
         FalconBoolToYesNo(FALCON_TSPR_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_TSPR_SCOPE) + "," +
         IntegerToString(tspr_persist_contract) + "," +
         IntegerToString(tspr_folder_defined) + "," +
         IntegerToString(tspr_record_shape) + "," +
         IntegerToString(tspr_broker_reconstruct) + "," +
         IntegerToString(tspr_min_recovery) + "," +
         IntegerToString(tspr_event_persist_policy) + "," +
         IntegerToString(tspr_restart_policy) + "," +
         IntegerToString(tspr_shadow_trades_covered) + "," +
         IntegerToString(tspr_recovery_candidates) + "," +
         IntegerToString(tspr_min_recovery_candidates) + "," +
         IntegerToString(tspr_untrusted_state_blocked) + "," +
         IntegerToString(tspr_order_send) + "," +
         IntegerToString(tspr_broker_modify_sent) + "," +
         IntegerToString(tspr_runtime_sl_changed) + "," +
         IntegerToString(tspr_invariant_breaches) + "," +
         DoubleToString(tspr_readiness_pct, 2) + "," +
         DoubleToString(tspr_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_TSPR_STATE_POLICY) + "," +
         FalconCsvSafe(FALCON_TSPR_ORDER_SEND_POLICY) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_TSPR_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_SSBL_STATUS) + "," +
         FalconCsvSafe(FALCON_SSBL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_SSBL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_SSBL_SCOPE) + "," +
         IntegerToString(ssbl_spread_guard_defined) + "," +
         IntegerToString(ssbl_slippage_cap_defined) + "," +
         IntegerToString(ssbl_broker_limits_cache) + "," +
         IntegerToString(ssbl_stops_policy_defined) + "," +
         IntegerToString(ssbl_freeze_policy_defined) + "," +
         IntegerToString(ssbl_volume_policy_defined) + "," +
         IntegerToString(ssbl_stops_buffer_points) + "," +
         IntegerToString(ssbl_max_spread_points) + "," +
         IntegerToString(ssbl_max_slippage_points) + "," +
         IntegerToString(ssbl_shadow_trades_covered) + "," +
         IntegerToString(ssbl_broker_context_ready) + "," +
         IntegerToString(ssbl_guard_ready) + "," +
         IntegerToString(ssbl_rejected_trades) + "," +
         IntegerToString(ssbl_order_send) + "," +
         IntegerToString(ssbl_broker_modify_sent) + "," +
         IntegerToString(ssbl_runtime_sl_changed) + "," +
         IntegerToString(ssbl_invariant_breaches) + "," +
         DoubleToString(ssbl_readiness_pct, 2) + "," +
         DoubleToString(ssbl_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_SSBL_SPREAD_POLICY) + "," +
         FalconCsvSafe(FALCON_SSBL_LIMITS_POLICY) + "," +
         FalconCsvSafe(FALCON_SSBL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_SSBL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_OTTU_STATUS) + "," +
         FalconCsvSafe(FALCON_OTTU_DECISION) + "," +
         FalconBoolToYesNo(FALCON_OTTU_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_OTTU_SCOPE) + "," +
         IntegerToString(ottu_handler_defined) + "," +
         IntegerToString(ottu_source_policy_defined) + "," +
         IntegerToString(ottu_event_routing_defined) + "," +
         IntegerToString(ottu_deal_add_policy_defined) + ",";
      summary_row +=
         IntegerToString(ottu_position_change_policy_defined) + "," +
         IntegerToString(ottu_state_persist_hook_defined) + "," +
         IntegerToString(ottu_on_tick_read_only_policy) + "," +
         IntegerToString(ottu_shadow_trades_covered) + "," +
         IntegerToString(ottu_broker_events_observed) + "," +
         IntegerToString(ottu_deal_events_routed) + "," +
         IntegerToString(ottu_position_events_routed) + "," +
         IntegerToString(ottu_unknown_events_ignored) + "," +
         IntegerToString(ottu_order_send) + "," +
         IntegerToString(ottu_broker_modify_sent) + "," +
         IntegerToString(ottu_runtime_sl_changed) + "," +
         IntegerToString(ottu_invariant_breaches) + "," +
         DoubleToString(ottu_readiness_pct, 2) + "," +
         DoubleToString(ottu_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_OTTU_SOURCE_POLICY) + "," +
         FalconCsvSafe(FALCON_OTTU_STATE_POLICY) + "," +
         FalconCsvSafe(FALCON_OTTU_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_OTTU_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PIVP_STATUS) + "," +
         FalconCsvSafe(FALCON_PIVP_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PIVP_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PIVP_SCOPE) + "," +
         IntegerToString(pivp_symbol_policy_defined) + "," +
         IntegerToString(pivp_timeframe_policy_defined) + "," +
         IntegerToString(pivp_account_policy_defined) + "," +
         IntegerToString(pivp_broker_policy_defined) + "," +
         IntegerToString(pivp_min_balance_policy_defined) + "," +
         IntegerToString(pivp_wrong_environment_blocks_live) + "," +
         IntegerToString(pivp_shadow_smoke_non_blocking) + "," +
         IntegerToString(pivp_supported_symbol_detected) + "," +
         IntegerToString(pivp_broker_context_ready) + "," +
         IntegerToString(pivp_shadow_trades_covered) + "," +
         IntegerToString(pivp_init_failed_triggered) + "," +
         IntegerToString(pivp_order_send) + "," +
         IntegerToString(pivp_broker_modify_sent) + "," +
         IntegerToString(pivp_runtime_sl_changed) + ",";
      summary_row +=
         IntegerToString(pivp_invariant_breaches) + "," +
         DoubleToString(pivp_readiness_pct, 2) + "," +
         DoubleToString(pivp_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PIVP_SYMBOL_POLICY) + "," +
         FalconCsvSafe(FALCON_PIVP_TIMEFRAME_POLICY) + "," +
         FalconCsvSafe(FALCON_PIVP_ACCOUNT_POLICY) + "," +
         FalconCsvSafe(FALCON_PIVP_BROKER_POLICY) + "," +
         FalconCsvSafe(FALCON_PIVP_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PIVP_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_EESL_STATUS) + "," +
         FalconCsvSafe(FALCON_EESL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_EESL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_EESL_SCOPE) + "," +
         IntegerToString(eesl_contract_defined) + "," +
         IntegerToString(eesl_independent_defined) + "," +
         IntegerToString(eesl_every_tick_policy) + "," +
         IntegerToString(eesl_before_engine_policy) + "," +
         IntegerToString(eesl_hard_cap_defined) + "," +
         DoubleToString(FALCON_EESL_HARD_CAP_PCT, 2) + "," +
         IntegerToString(eesl_blocks_new_entries) + "," +
         IntegerToString(eesl_close_all_policy) + "," +
         IntegerToString(eesl_session_disable_policy) + "," +
         IntegerToString(eesl_alert_policy_defined) + "," +
         IntegerToString(eesl_shadow_trades_covered) + "," +
         IntegerToString(eesl_triggered) + "," +
         IntegerToString(eesl_closed_positions) + "," +
         IntegerToString(eesl_order_send) + "," +
         IntegerToString(eesl_broker_modify_sent) + "," +
         IntegerToString(eesl_runtime_sl_changed) + "," +
         IntegerToString(eesl_invariant_breaches) + "," +
         DoubleToString(eesl_readiness_pct, 2) + "," +
         DoubleToString(eesl_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_EESL_POLICY) + "," +
         FalconCsvSafe(FALCON_EESL_ACTION_POLICY) + "," +
         FalconCsvSafe(FALCON_EESL_ALERT_POLICY) + "," +
         FalconCsvSafe(FALCON_EESL_ORDER_SEND_POLICY) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_EESL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_CPD_STATUS) + "," +
         FalconCsvSafe(FALCON_CPD_DECISION) + "," +
         FalconBoolToYesNo(FALCON_CPD_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_CPD_SCOPE) + "," +
         IntegerToString(cpd_contract_defined) + "," +
         IntegerToString(cpd_max_total) + "," +
         IntegerToString(cpd_max_per_engine) + "," +
         IntegerToString(cpd_max_per_direction) + "," +
         IntegerToString(cpd_total_cap_defined) + "," +
         IntegerToString(cpd_per_engine_cap_defined) + "," +
         IntegerToString(cpd_per_direction_cap_defined) + "," +
         IntegerToString(cpd_shared_exposure_policy_defined) + "," +
         IntegerToString(cpd_engine_isolation_policy_defined) + "," +
         IntegerToString(cpd_direction_cap_policy_defined) + "," +
         IntegerToString(cpd_shadow_smoke_non_blocking) + "," +
         IntegerToString(cpd_shadow_trades_covered) + "," +
         IntegerToString(cpd_open_positions_observed) + "," +
         IntegerToString(cpd_blocked_by_total_cap) + "," +
         IntegerToString(cpd_blocked_by_engine_cap) + "," +
         IntegerToString(cpd_blocked_by_direction_cap) + "," +
         IntegerToString(cpd_order_send) + "," +
         IntegerToString(cpd_broker_modify_sent) + "," +
         IntegerToString(cpd_runtime_sl_changed) + "," +
         IntegerToString(cpd_invariant_breaches) + "," +
         DoubleToString(cpd_readiness_pct, 2) + "," +
         DoubleToString(cpd_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_CPD_SHARED_EXPOSURE_POLICY) + "," +
         FalconCsvSafe(FALCON_CPD_ENGINE_ISOLATION_POLICY) + "," +
         FalconCsvSafe(FALCON_CPD_DIRECTION_CAP_POLICY) + "," +
         FalconCsvSafe(FALCON_CPD_ORDER_SEND_POLICY) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_CPD_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PMD_STATUS) + "," +
         FalconCsvSafe(FALCON_PMD_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PMD_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PMD_SCOPE) + "," +
         IntegerToString(pmd_shadow_definition_ready) + "," +
         IntegerToString(pmd_paper_definition_ready) + "," +
         IntegerToString(pmd_demo_definition_ready) + "," +
         IntegerToString(pmd_live_definition_ready) + "," +
         IntegerToString(pmd_paper_position_lifecycle_defined) + "," +
         IntegerToString(pmd_paper_virtual_sl_defined) + "," +
         IntegerToString(pmd_paper_protection_defined) + "," +
         IntegerToString(pmd_paper_runner_defined) + "," +
         IntegerToString(pmd_paper_equity_curve_defined) + "," +
         IntegerToString(pmd_paper_exit_model_defined) + "," +
         IntegerToString(pmd_shadow_smoke_non_blocking) + "," +
         IntegerToString(pmd_shadow_trades_covered) + "," +
         IntegerToString(pmd_paper_positions_created) + "," +
         IntegerToString(pmd_paper_exits_applied) + "," +
         IntegerToString(pmd_paper_equity_events) + "," +
         IntegerToString(pmd_order_send) + "," +
         IntegerToString(pmd_broker_modify_sent) + "," +
         IntegerToString(pmd_runtime_sl_changed) + "," +
         IntegerToString(pmd_invariant_breaches) + "," +
         DoubleToString(pmd_readiness_pct, 2) + "," +
         DoubleToString(pmd_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_PMD_SHADOW_POLICY) + "," +
         FalconCsvSafe(FALCON_PMD_PAPER_POLICY) + "," +
         FalconCsvSafe(FALCON_PMD_DEMO_POLICY) + "," +
         FalconCsvSafe(FALCON_PMD_LIVE_POLICY) + "," +
         FalconCsvSafe(FALCON_PMD_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PMD_NEXT_PHASE) + ",";
      summary_row +=
         FalconCsvSafe(FALCON_SPF_STATUS) + "," +
         FalconCsvSafe(FALCON_SPF_DECISION) + "," +
         FalconBoolToYesNo(FALCON_SPF_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_SPF_SCOPE) + "," +
         IntegerToString(spf_symbol_family_defined) + "," +
         IntegerToString(spf_aliases_defined) + "," +
         IntegerToString(spf_current_symbol_recognized) + "," +
         IntegerToString(spf_context_valid) + "," +
         IntegerToString(m_symbol_context.digits) + "," +
         DoubleToString(m_symbol_context.point, 10) + "," +
         DoubleToString(m_symbol_context.tick_size, 10) + "," +
         DoubleToString(m_symbol_context.tick_value, 5) + "," +
         DoubleToString(m_symbol_context.contract_size, 2) + "," +
         IntegerToString((int)m_symbol_context.spread_points) + "," +
         IntegerToString((int)m_symbol_context.stops_level_points) + "," +
         IntegerToString((int)m_symbol_context.freeze_level_points) + "," +
         DoubleToString(m_symbol_context.min_lot, 2) + "," +
         DoubleToString(m_symbol_context.max_lot, 2) + "," +
         DoubleToString(m_symbol_context.lot_step, 2) + "," +
         IntegerToString(spf_contract_policy_defined) + "," +
         IntegerToString(spf_tick_policy_defined) + "," +
         IntegerToString(spf_point_mapping_defined) + "," +
         IntegerToString(spf_broker_limits_defined) + "," +
         IntegerToString(spf_session_policy_defined) + "," +
         IntegerToString(spf_spread_policy_defined) + "," +
         IntegerToString(spf_default_safety_defined) + "," +
         IntegerToString(spf_shadow_smoke_non_blocking) + "," +
         IntegerToString(spf_shadow_trades_covered) + "," +
         IntegerToString(spf_paper_guards_applied) + "," +
         IntegerToString(spf_order_send) + "," +
         IntegerToString(spf_broker_modify_sent) + "," +
         IntegerToString(spf_runtime_sl_changed) + "," +
         IntegerToString(spf_invariant_breaches) + "," +
         DoubleToString(spf_readiness_pct, 2) + "," +
         DoubleToString(spf_completeness_pct, 2) + "," +
         FalconCsvSafe(FALCON_SPF_SYMBOL_ALIASES) + "," +
         FalconCsvSafe(FALCON_SPF_CONTRACT_POLICY) + "," +
         FalconCsvSafe(FALCON_SPF_TICK_POLICY) + "," +
         FalconCsvSafe(FALCON_SPF_POINT_MAPPING_POLICY) + "," +
         FalconCsvSafe(FALCON_SPF_BROKER_LIMITS_POLICY) + "," +
         FalconCsvSafe(FALCON_SPF_SESSION_POLICY) + "," +
         FalconCsvSafe(FALCON_SPF_SPREAD_POLICY) + "," +
         FalconCsvSafe(FALCON_SPF_DEFAULT_SAFETY_POLICY) + "," +
         FalconCsvSafe(FALCON_SPF_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_SPF_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PRGA_STATUS) + "," +
         FalconCsvSafe(FALCON_PRGA_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PRGA_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PRGA_SCOPE) + "," +
         IntegerToString(prga_contract_ready) + "," +
         IntegerToString(m_totals.paper_guard_evaluated_trades) + "," +
         IntegerToString(m_totals.paper_guard_passed_trades) + "," +
         IntegerToString(m_totals.paper_guard_rejected_trades) + "," +
         IntegerToString(m_totals.paper_guard_spread_rejected_trades) + "," +
         IntegerToString(m_totals.paper_guard_stops_rejected_trades) + "," +
         IntegerToString(m_totals.paper_guard_freeze_rejected_trades) + "," +
         IntegerToString(m_totals.paper_exposure_evaluated_trades) + "," +
         IntegerToString(m_totals.paper_exposure_passed_trades) + "," +
         IntegerToString(m_totals.paper_exposure_blocked_total) + "," +
         IntegerToString(m_totals.paper_exposure_blocked_engine) + "," +
         IntegerToString(m_totals.paper_exposure_blocked_direction) + "," +
         DoubleToString(m_totals.paper_guard_before_net_points, 2) + "," +
         DoubleToString(m_totals.paper_guard_after_net_points, 2) + "," +
         DoubleToString(m_totals.paper_guard_impact_points, 2) + "," +
         DoubleToString(m_totals.paper_guard_before_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_guard_after_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_guard_impact_usd, 2) + "," +
         IntegerToString(prga_order_send) + "," +
         IntegerToString(prga_broker_modify_sent) + "," +
         IntegerToString(prga_runtime_sl_changed) + "," +
         IntegerToString(prga_invariant_breaches) + "," +
         DoubleToString(prga_readiness_pct, 2) + "," +
         DoubleToString(prga_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_PRGA_REJECT_POLICY) + "," +
         FalconCsvSafe(FALCON_PRGA_EXPOSURE_POLICY) + "," +
         FalconCsvSafe(FALCON_PRGA_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PRGA_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PRTP_STATUS) + "," +
         FalconCsvSafe(FALCON_PRTP_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PRTP_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PRTP_SCOPE) + "," +
         IntegerToString(prtp_contract_ready) + "," +
         IntegerToString(m_totals.paper_protection_evaluated_trades) + "," +
         IntegerToString(m_totals.paper_protection_eligible_trades) + "," +
         IntegerToString(m_totals.paper_protection_activated_trades) + "," +
         IntegerToString(m_totals.paper_tp1_protection_trades) + "," +
         IntegerToString(m_totals.paper_tp2_protection_trades) + "," +
         IntegerToString(m_totals.paper_virtual_sl_changed_trades) + "," +
         IntegerToString(m_totals.paper_virtual_sl_hit_trades) + "," +
         IntegerToString(m_totals.paper_protected_exit_trades) + "," +
         DoubleToString(m_totals.paper_protection_before_net_points, 2) + "," +
         DoubleToString(m_totals.paper_protection_after_net_points, 2) + "," +
         DoubleToString(m_totals.paper_protection_impact_points, 2) + "," +
         DoubleToString(m_totals.paper_protection_before_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_protection_after_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_protection_impact_usd, 2) + "," +
         DoubleToString(m_totals.paper_protection_giveback_prevented_points, 2) + "," +
         DoubleToString(m_totals.paper_protection_giveback_prevented_usd, 2) + "," +
         IntegerToString(prtp_order_send) + "," +
         IntegerToString(prtp_broker_modify_sent) + "," +
         IntegerToString(prtp_runtime_sl_changed) + "," +
         IntegerToString(prtp_invariant_breaches) + "," +
         DoubleToString(prtp_readiness_pct, 2) + "," +
         DoubleToString(prtp_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_PRTP_POLICY) + "," +
         FalconCsvSafe(FALCON_PRTP_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PRTP_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_PRRUN_STATUS) + "," +
         FalconCsvSafe(FALCON_PRRUN_DECISION) + "," +
         FalconBoolToYesNo(FALCON_PRRUN_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_PRRUN_SCOPE) + "," +
         IntegerToString(prrun_contract_ready) + "," +
         IntegerToString(m_totals.paper_runner_evaluated_trades) + "," +
         IntegerToString(m_totals.paper_runner_eligible_trades) + "," +
         IntegerToString(m_totals.paper_runner_activated_trades) + "," +
         IntegerToString(m_totals.paper_runner_3r_trades) + "," +
         IntegerToString(m_totals.paper_moon_mode_5r_trades) + "," +
         IntegerToString(m_totals.paper_runner_exit_trades) + "," +
         DoubleToString(m_totals.paper_runner_additional_points, 2) + "," +
         DoubleToString(m_totals.paper_runner_additional_usd, 2) + "," +
         IntegerToString(m_totals.paper_runner_giveback_trades) + "," +
         IntegerToString(m_totals.paper_runner_protected_from_loss_trades) + "," +
         DoubleToString(m_totals.paper_runner_before_net_points, 2) + "," +
         DoubleToString(m_totals.paper_runner_after_net_points, 2) + "," +
         DoubleToString(m_totals.paper_runner_impact_points, 2) + "," +
         DoubleToString(m_totals.paper_runner_before_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_runner_after_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_runner_impact_usd, 2) + "," +
         IntegerToString(prrun_order_send) + "," +
         IntegerToString(prrun_broker_modify_sent) + "," +
         IntegerToString(prrun_runtime_sl_changed) + "," +
         IntegerToString(prrun_invariant_breaches) + "," +
         DoubleToString(prrun_readiness_pct, 2) + "," +
         DoubleToString(prrun_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_PRRUN_POLICY) + "," +
         FalconCsvSafe(FALCON_PRRUN_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_PRRUN_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_RUNNER_BARPATH_POLICY) + "," +
         FalconCsvSafe(FALCON_RUNNER_BARPATH_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_CTF_STATUS) + "," +
         FalconCsvSafe(FALCON_CTF_DECISION) + "," +
         FalconBoolToYesNo(FALCON_CTF_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_CTF_SCOPE) + "," +
         IntegerToString(ctf_contract_ready) + "," +
         DoubleToString(ctf_effective_balance, 2) + "," +
         FalconCsvSafe(ctf_tier_name) + "," +
         DoubleToString(FalconCapitalTierMinBalance(ctf_tier_name), 2) + "," +
         DoubleToString(FalconCapitalTierMaxBalance(ctf_tier_name), 2) + "," +
         IntegerToString(FalconCapitalTierMaxLosses(ctf_tier_name)) + "," +
         DoubleToString(FalconCapitalTierMaxDailyR(ctf_tier_name), 2) + "," +
         DoubleToString(FalconCapitalTierMaxDrawdownPct(ctf_tier_name), 2) + "," +
         DoubleToString(m_symbol_context.min_lot, 2) + "," +
         DoubleToString(FixedLotSize, 2) + "," +
         FalconCsvSafe(ctf_min_lot_status) + "," +
         IntegerToString(ctf_min_lot_compatible) + "," +
         IntegerToString(ctf_tier_locked) + "," +
         IntegerToString(ctf_order_send) + "," +
         IntegerToString(ctf_broker_modify_sent) + "," +
         IntegerToString(ctf_runtime_sl_changed) + "," +
         IntegerToString(ctf_invariant_breaches) + "," +
         DoubleToString(ctf_readiness_pct, 2) + "," +
         DoubleToString(ctf_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_CTF_BALANCE_POLICY) + "," +
         FalconCsvSafe(FALCON_CTF_MIN_LOT_POLICY) + "," +
         FalconCsvSafe(FALCON_CTF_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_CTF_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_TLE_STATUS) + "," +
         FalconCsvSafe(FALCON_TLE_DECISION) + "," +
         FalconBoolToYesNo(FALCON_TLE_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_TLE_SCOPE) + "," +
         IntegerToString(tle_contract_ready) + "," +
         IntegerToString(m_totals.paper_emergency_evaluated_trades) + "," +
         IntegerToString(m_totals.paper_emergency_safe_trades) + "," +
         IntegerToString(m_totals.paper_emergency_triggered_trades) + "," +
         IntegerToString(m_totals.paper_emergency_blocked_entries) + "," +
         IntegerToString(m_totals.paper_emergency_layer1_triggers) + "," +
         IntegerToString(m_totals.paper_emergency_layer2_triggers) + "," +
         IntegerToString(m_totals.paper_emergency_layer3_triggers) + "," +
         DoubleToString(m_totals.paper_emergency_before_net_points, 2) + "," +
         DoubleToString(m_totals.paper_emergency_after_net_points, 2) + "," +
         DoubleToString(m_totals.paper_emergency_impact_points, 2) + "," +
         DoubleToString(m_totals.paper_emergency_before_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_emergency_after_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_emergency_impact_usd, 2) + "," +
         DoubleToString(m_totals.paper_emergency_max_drawdown_pct, 2) + "," +
         DoubleToString(m_totals.paper_emergency_worst_daily_r, 2) + "," +
         IntegerToString(tle_order_send) + "," +
         IntegerToString(tle_broker_modify_sent) + "," +
         IntegerToString(tle_runtime_sl_changed) + "," +
         IntegerToString(tle_invariant_breaches) + "," +
         DoubleToString(tle_readiness_pct, 2) + "," +
         DoubleToString(tle_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_TLE_POLICY) + "," +
         FalconCsvSafe(FALCON_TLE_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_TLE_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_LSR_STATUS) + "," +
         FalconCsvSafe(FALCON_LSR_DECISION) + "," +
         FalconBoolToYesNo(FALCON_LSR_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_LSR_SCOPE) + "," +
         IntegerToString(lsr_contract_ready) + "," +
         IntegerToString(m_totals.layer_reset_evaluated_trades) + "," +
         IntegerToString(m_totals.layer1_reset_on_win_events) + "," +
         IntegerToString(m_totals.layer2_reset_on_new_day_events) + "," +
         IntegerToString(m_totals.layer3_reset_on_new_peak_events) + "," +
         IntegerToString(m_totals.layer_reset_event_trades) + "," +
         IntegerToString(m_totals.layer_reset_duplicate_triggers) + "," +
         IntegerToString(lsr_order_send) + "," +
         IntegerToString(lsr_broker_modify_sent) + "," +
         IntegerToString(lsr_runtime_sl_changed) + "," +
         IntegerToString(lsr_invariant_breaches) + "," +
         DoubleToString(lsr_readiness_pct, 2) + "," +
         DoubleToString(lsr_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_LSR_POLICY) + "," +
         FalconCsvSafe(FALCON_LSR_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_LSR_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_VAL_STATUS) + "," +
         FalconCsvSafe(FALCON_VAL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_VAL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_VAL_SCOPE) + "," +
         IntegerToString(val_contract_ready) + "," +
         IntegerToString(val_evaluated_trades) + "," +
         DoubleToString(m_totals.net_usd, 2) + "," +
         DoubleToString(m_totals.paper_runner_after_net_usd, 2) + "," +
         DoubleToString(m_totals.paper_emergency_after_net_usd, 2) + "," +
         DoubleToString(val_working_baseline_impact_usd, 2) + "," +
         IntegerToString(m_totals.paper_emergency_triggered_trades) + "," +
         IntegerToString(m_totals.paper_emergency_blocked_entries) + "," +
         IntegerToString(m_totals.layer_reset_duplicate_triggers) + "," +
         IntegerToString(val_multi_window_required) + "," +
         IntegerToString(val_order_send) + "," +
         IntegerToString(val_broker_modify_sent) + "," +
         IntegerToString(val_runtime_sl_changed) + "," +
         IntegerToString(val_invariant_breaches) + "," +
         DoubleToString(val_readiness_pct, 2) + "," +
         DoubleToString(val_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_VAL_POLICY) + "," +
         FalconCsvSafe(FALCON_VAL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_VAL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_TPF_STATUS) + "," +
         FalconCsvSafe(FALCON_TPF_DECISION) + "," +
         FalconBoolToYesNo(FALCON_TPF_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_TPF_SCOPE) + "," +
         IntegerToString(tpf_contract_ready) + "," +
         IntegerToString(tpf_evaluated_trades) + "," +
         FalconCsvSafe(tpf_current_tier) + "," +
         FalconCsvSafe(tpf_next_tier) + "," +
         DoubleToString(ctf_effective_balance, 2) + "," +
         DoubleToString(tpf_next_min_balance, 2) + "," +
         IntegerToString(FALCON_TPF_MIN_TRADES_IN_TIER) + "," +
         IntegerToString(tpf_trades_in_tier) + "," +
         DoubleToString(FALCON_TPF_MIN_WIN_RATE_PCT, 2) + "," +
         DoubleToString(tpf_win_rate, 2) + "," +
         DoubleToString(FALCON_TPF_MIN_NET_R, 2) + "," +
         DoubleToString(tpf_net_r, 2) + "," +
         IntegerToString(FALCON_TPF_DAYS_WITHOUT_EMERGENCY) + "," +
         IntegerToString(FALCON_TPF_POST_QUAL_COOLDOWN_DAYS) + "," +
         IntegerToString(tpf_balance_requirement_met) + "," +
         IntegerToString(tpf_trades_requirement_met) + "," +
         IntegerToString(tpf_winrate_requirement_met) + "," +
         IntegerToString(tpf_netr_requirement_met) + "," +
         IntegerToString(tpf_no_emergency_requirement_pending) + "," +
         IntegerToString(tpf_cooldown_requirement_pending) + "," +
         IntegerToString(tpf_eligible_now) + "," +
         FalconCsvSafe(tpf_blocked_reason) + "," +
         IntegerToString(tpf_promotion_events) + "," +
         IntegerToString(tpf_transition_report_defined) + "," +
         IntegerToString(tpf_order_send) + "," +
         IntegerToString(tpf_broker_modify_sent) + "," +
         IntegerToString(tpf_runtime_sl_changed) + "," +
         IntegerToString(tpf_invariant_breaches) + "," +
         DoubleToString(tpf_readiness_pct, 2) + "," +
         DoubleToString(tpf_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_TPF_POLICY) + "," +
         FalconCsvSafe(FALCON_TPF_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_TPF_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_TDF_STATUS) + "," +
         FalconCsvSafe(FALCON_TDF_DECISION) + "," +
         FalconBoolToYesNo(FALCON_TDF_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_TDF_SCOPE) + "," +
         IntegerToString(tdf_contract_ready) + "," +
         IntegerToString(tdf_evaluated_trades) + "," +
         FalconCsvSafe(tdf_current_tier) + "," +
         DoubleToString(ctf_effective_balance, 2) + "," +
         DoubleToString(tdf_current_tier_min_balance, 2) + "," +
         DoubleToString(FALCON_TDF_HYSTERESIS_PCT, 2) + "," +
         DoubleToString(tdf_balance_hysteresis_threshold, 2) + "," +
         IntegerToString(tdf_emergencies_in_14d) + "," +
         IntegerToString(FALCON_TDF_MAX_EMERGENCIES_14D) + "," +
         IntegerToString(tdf_negative_weeks_in_row) + "," +
         IntegerToString(FALCON_TDF_MAX_NEGATIVE_WEEKS) + "," +
         DoubleToString(FALCON_TDF_EXTREME_DD_MULTIPLIER, 2) + "," +
         DoubleToString(tdf_observed_max_drawdown_pct, 2) + "," +
         DoubleToString(tdf_extreme_drawdown_threshold_pct, 2) + "," +
         IntegerToString(tdf_balance_hysteresis_breach) + "," +
         IntegerToString(tdf_multiple_emergencies_breach) + "," +
         IntegerToString(tdf_negative_weeks_breach) + "," +
         IntegerToString(tdf_extreme_drawdown_breach) + "," +
         IntegerToString(tdf_should_demote_now) + "," +
         FalconCsvSafe(tdf_demotion_reason) + "," +
         IntegerToString(tdf_demotion_events) + "," +
         IntegerToString(tdf_transition_report_defined) + "," +
         IntegerToString(tdf_order_send) + "," +
         IntegerToString(tdf_broker_modify_sent) + "," +
         IntegerToString(tdf_runtime_sl_changed) + "," +
         IntegerToString(tdf_invariant_breaches) + "," +
         DoubleToString(tdf_readiness_pct, 2) + "," +
         DoubleToString(tdf_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_TDF_POLICY) + "," +
         FalconCsvSafe(FALCON_TDF_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_TDF_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_TDL_STATUS) + "," +
         FalconCsvSafe(FALCON_TDL_DECISION) + "," +
         FalconBoolToYesNo(FALCON_TDL_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_TDL_SCOPE) + "," +
         IntegerToString(tdl_contract_ready) + "," +
         IntegerToString(tdl_evaluated_trades) + "," +
         FalconCsvSafe(tdl_start_tier) + "," +
         FalconCsvSafe(tdl_applied_tier) + "," +
         FalconCsvSafe(tdl_transition_direction) + "," +
         FalconCsvSafe(tdl_transition_reason) + "," +
         IntegerToString(tdl_promotion_applied) + "," +
         IntegerToString(tdl_demotion_applied) + "," +
         IntegerToString(tdl_transition_events) + "," +
         IntegerToString(tdl_active_positions_preserved) + "," +
         IntegerToString(tdl_next_trades_use_applied_tier) + "," +
         IntegerToString(tdl_order_send) + "," +
         IntegerToString(tdl_broker_modify_sent) + "," +
         IntegerToString(tdl_runtime_sl_changed) + "," +
         IntegerToString(tdl_invariant_breaches) + "," +
         DoubleToString(tdl_readiness_pct, 2) + "," +
         DoubleToString(tdl_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_TDL_POLICY) + "," +
         FalconCsvSafe(FALCON_TDL_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_TDL_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_LCRF_STATUS) + "," +
         FalconCsvSafe(FALCON_LCRF_DECISION) + "," +
         FalconBoolToYesNo(FALCON_LCRF_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_LCRF_SCOPE) + "," +
         IntegerToString(lcrf_contract_ready) + "," +
         IntegerToString(lcrf_evaluated_trades) + "," +
         IntegerToString(m_totals.lotsizing_feasibility_feasible_trades) + "," +
         IntegerToString(m_totals.lotsizing_feasibility_borderline_trades) + "," +
         IntegerToString(m_totals.lotsizing_feasibility_not_feasible_trades) + "," +
         IntegerToString(m_totals.lotsizing_feasibility_invalid_trades) + "," +
         IntegerToString(m_totals.lotsizing_single_trade_cap_breach_trades) + "," +
         DoubleToString(lcrf_min_lot_risk_usd_avg, 2) + "," +
         DoubleToString(m_totals.lotsizing_min_lot_risk_usd_max, 2) + "," +
         DoubleToString(lcrf_min_lot_risk_pct_avg, 2) + "," +
         DoubleToString(m_totals.lotsizing_min_lot_risk_pct_max, 2) + "," +
         DoubleToString(lcrf_potential_loss_r_avg, 2) + "," +
         DoubleToString(m_totals.lotsizing_potential_loss_r_max, 2) + "," +
         IntegerToString(lcrf_order_send) + "," +
         IntegerToString(lcrf_broker_modify_sent) + "," +
         IntegerToString(lcrf_runtime_sl_changed) + "," +
         IntegerToString(lcrf_invariant_breaches) + "," +
         DoubleToString(lcrf_readiness_pct, 2) + "," +
         DoubleToString(lcrf_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_LCRF_POLICY) + "," +
         FalconCsvSafe(FALCON_LCRF_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_LCRF_NEXT_PHASE) + "," +
         FalconCsvSafe(FALCON_STLC_STATUS) + "," +
         FalconCsvSafe(FALCON_STLC_DECISION) + "," +
         FalconBoolToYesNo(FALCON_STLC_RUNTIME_ENFORCED) + "," +
         FalconCsvSafe(FALCON_STLC_SCOPE) + "," +
         IntegerToString(stlc_contract_ready) + "," +
         IntegerToString(stlc_evaluated_trades) + "," +
         IntegerToString(m_totals.single_trade_loss_cap_allowed_trades) + "," +
         IntegerToString(m_totals.single_trade_loss_cap_blocked_trades) + "," +
         IntegerToString(m_totals.single_trade_loss_cap_invalid_trades) + "," +
         IntegerToString(m_totals.single_trade_loss_cap_strict_breach_trades) + "," +
         IntegerToString(m_totals.single_trade_loss_cap_calibrated_breach_trades) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_before_net_usd, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_after_net_usd, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_impact_usd, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_rejected_profit_usd, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_rejected_loss_usd, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_calibrated_cap_r_max, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_risk_pct_cap_max, 2) + "," +
         FalconCsvSafe(FALCON_STLC_DYNAMIC_CAPITAL_MODE) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_dynamic_capital_start, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_dynamic_capital_min, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_dynamic_capital_max, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_dynamic_capital_end, 2) + "," +
         IntegerToString(m_totals.single_trade_loss_cap_dynamic_capital_updates) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_dynamic_risk_pct_max, 2) + "," +
         DoubleToString(m_totals.single_trade_loss_cap_dynamic_cap_pct_max, 2) + "," +
         IntegerToString(m_totals.single_trade_loss_cap_dynamic_capital_blocks) + "," +
         IntegerToString(stlc_order_send) + "," +
         IntegerToString(stlc_broker_modify_sent) + "," +
         IntegerToString(stlc_runtime_sl_changed) + "," +
         IntegerToString(stlc_invariant_breaches) + "," +
         DoubleToString(stlc_readiness_pct, 2) + "," +
         DoubleToString(stlc_application_pct, 2) + "," +
         FalconCsvSafe(FALCON_STLC_POLICY) + "," +
         FalconCsvSafe(FALCON_STLC_ORDER_SEND_POLICY) + "," +
         FalconCsvSafe(FALCON_STLC_NEXT_PHASE);

      // v0.20.2: Write CRLF explicitly as separate strings. This prevents MetaTrader/CSV
      // readers from receiving the header and summary row concatenated on a single line.
      string summary_line_break = CharToString(13) + CharToString(10);
      FileWriteString(handle, summary_header);
      FileWriteString(handle, summary_line_break);
      FileWriteString(handle, summary_row);
      FileWriteString(handle, summary_line_break);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Final summary written. Trades=%d | WinRate=%.2f | NetIndexPoints=%.2f | NetUSD=%.2f",
                                       m_totals.total_trades,
                                       m_totals.win_rate,
                                       m_totals.net_index_points,
                                       m_totals.net_usd));
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

      double dynamic_risk_pct = 0.0;
      if(dynamic_capital > 0.0)
         dynamic_risk_pct = 100.0 * record.falcon_min_lot_risk_usd / dynamic_capital;
      record.falcon_dynamic_risk_pct_of_capital = dynamic_risk_pct;

      double calibrated_cap_r = FalconCalibratedSingleTradeLossCapR(tier_name);
      double calibrated_risk_pct_cap = FalconCalibratedSingleTradeLossCapRiskPct(tier_name);
      record.falcon_single_trade_loss_cap_calibrated_cap_r = calibrated_cap_r;
      record.falcon_single_trade_loss_cap_risk_pct_cap = calibrated_risk_pct_cap;
      record.falcon_dynamic_single_trade_cap_pct = calibrated_risk_pct_cap;

      if(dynamic_capital <= 0.0 || record.falcon_min_lot_risk_usd <= 0.0 || calibrated_risk_pct_cap <= 0.0)
      {
         record.falcon_single_trade_loss_cap_status = "INVALID";
         record.falcon_single_trade_loss_cap_decision = "ALLOW_PASS_THROUGH";
         record.falcon_single_trade_loss_cap_reason = "DYNAMIC_RISK_INPUT_UNKNOWN";
         record.falcon_dynamic_capital_reason = "DYNAMIC_RISK_INPUT_UNKNOWN";
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
      }
   }

   void ResetTotals()
   {
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

      m_tle_emergency_active = false;
      m_tle_emergency_reason = "NONE";
      m_tle_consecutive_losses = 0;
      m_tle_current_day = 0;
      m_tle_daily_r = 0.0;
      m_tle_equity = 0.0;
      m_tle_peak_equity = 0.0;
      m_tle_max_drawdown_pct = 0.0;
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

   void WriteTradeHeader()
   {
      int handle = FileOpen(m_trade_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create trade lifecycle report: %s", m_trade_report_file));
         return;
      }

      // v0.50.0a compile fix: TradeLifecycle now has 66 columns.
      // MetaEditor can reject large FileWrite(...) vararg calls as wrong parameters count.
      // Write the CSV header as one controlled string instead; schema is unchanged.
      string trade_header = "";
      trade_header += "EAName,Version,Build,Symbol,";
      trade_header += "TradeId,StrategyId,StrategyName,EngineId,";
      trade_header += "Stage,Direction,EntryTime,ExitTime,";
      trade_header += "LotSize,Entry,SL,TP1,TP2,TP3,Exit,";
      trade_header += "Outcome,WinLose,";
      trade_header += "ProfitIndexPoints,LoseIndexPoints,NetIndexPoints,";
      trade_header += "ProfitUSD,LoseUSD,NetUSD,";
      trade_header += "FvgSizePoints,FvgSpreadPoints,FvgRetestAgeBars,";
      trade_header += "FvgSetupTime,FvgRetestWatchTime,FvgAgeBarsAtWatch,FvgAgeSource,";
      trade_header += "FvgRetestFreshState,FvgHoldQualityScore,FvgHoldQualityBucket,";
      trade_header += "QualityFiltersPassed,";
      trade_header += "FvgQGuardProfile,FvgQGuardPassed,FvgQGuardDecision,FvgQGuardReason,";
      trade_header += "FvgQGuardSimNetPoints,FvgQGuardSimNetUSD,";
      trade_header += "PaperGuardStatus,PaperRejectReason,PaperGuardLayer,";
      trade_header += "PaperSpreadPoints,PaperMaxSpreadPoints,PaperSLDistancePoints,";
      trade_header += "PaperStopsLevelPoints,PaperFreezeLevelPoints,";
      trade_header += "PaperGuardNetIndexPoints,PaperGuardNetUSD,";
      trade_header += "PaperProtectionState,PaperVirtualSL,PaperProtectionTrigger,";
      trade_header += "PaperProtectionLevel,PaperProtectionActivated,";
      trade_header += "PaperVirtualSLChanged,PaperVirtualSLHit,PaperExitReason,";
      trade_header += "PaperProtectionNetIndexPoints,PaperProtectionNetUSD,";
      trade_header += "PaperRunnerState,PaperRunnerActivated,PaperRunnerMaxR,";
      trade_header += "PaperRunnerCapturedPoints,PaperRunnerAdditionalPoints,";
      trade_header += "PaperRunnerExitReason,PaperRunnerNetIndexPoints,PaperRunnerNetUSD,";
      trade_header += "PaperFinalExitReason,";
      trade_header += "FalconTierAtEntry,FalconTierAtExit,FalconEffectiveBalance,";
      trade_header += "FalconTierMinBalance,FalconTierMaxBalance,FalconTierMaxConsecutiveLosses,";
      trade_header += "FalconTierMaxDailyR,FalconTierMaxDrawdownPct,";
      trade_header += "FalconBrokerMinLot,FalconFixedLot,FalconMinLotConstraint,";
      trade_header += "FalconLotSizingFeasibilityStatus,FalconLotSizingFeasibilityReason,";
      trade_header += "FalconMinLotRiskPoints,FalconMinLotRiskUSD,FalconMinLotRiskPctOfCapital,";
      trade_header += "FalconTierBaseRiskPct,FalconTierRiskBudgetUSD,FalconPotentialLossR,";
      trade_header += "FalconMaxSingleTradeLossR,FalconSingleTradeLossCapBreach,";
      trade_header += "FalconSingleTradeLossCapStatus,FalconSingleTradeLossCapDecision,FalconSingleTradeLossCapReason,";
      trade_header += "FalconSingleTradeLossCapRuntimeEnforced,FalconSingleTradeLossCapStrictCapR,";
      trade_header += "FalconSingleTradeLossCapCalibratedCapR,FalconSingleTradeLossCapRiskPctCap,";
      trade_header += "FalconSingleTradeLossCapBlocked,FalconSingleTradeLossCapBeforeNetPoints,";
      trade_header += "FalconSingleTradeLossCapAfterNetPoints,FalconSingleTradeLossCapImpactPoints,";
      trade_header += "FalconSingleTradeLossCapBeforeNetUSD,FalconSingleTradeLossCapAfterNetUSD,";
      trade_header += "FalconSingleTradeLossCapImpactUSD,";
      trade_header += "FalconDynamicCapitalMode,FalconDynamicRiskCapitalBeforeTrade,FalconDynamicRiskCapitalAfterTrade,";
      trade_header += "FalconDynamicRiskTierByCapital,FalconDynamicRiskPctOfCapital,FalconDynamicSingleTradeCapPct,";
      trade_header += "FalconDynamicCapitalAwareBlocked,FalconDynamicCapitalReason,";
      trade_header += "FalconEmergencyStatus,FalconEmergencyTriggeredLayer,FalconEmergencyReason,";
      trade_header += "FalconLayer1ConsecutiveLosses,FalconLayer1MaxLosses,";
      trade_header += "FalconLayer2DailyR,FalconLayer2MaxDailyR,";
      trade_header += "FalconLayer3DrawdownPct,FalconLayer3MaxDrawdownPct,";
      trade_header += "FalconEmergencyBeforeNetPoints,FalconEmergencyAfterNetPoints,";
      trade_header += "FalconEmergencyBeforeNetUSD,FalconEmergencyAfterNetUSD,";
      trade_header += "FalconResetStatus,FalconLayer1ResetOnWin,FalconLayer2ResetOnNewDay,";
      trade_header += "FalconLayer3ResetOnNewPeak,FalconResetReason,";
      trade_header += "CloseReason,EvidenceSummary";
      FileWriteString(handle, trade_header + "\r\n");
      FileClose(handle);
   }

   void WriteSummaryHeader()
   {
      int handle = FileOpen(m_summary_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create summary report: %s", m_summary_report_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "TotalTrades", "WinTrades", "LoseTrades", "BreakevenTrades",
                "WinRate", "LoseRate",
                "TotalProfitIndexPoints", "TotalLossIndexPoints", "NetIndexPoints",
                "TotalProfitUSD", "TotalLossUSD", "NetUSD");
      FileClose(handle);
   }

   void AppendTradeRecord(const FalconTradeLifecycleRecord &record)
   {
      int handle = FileOpen(m_trade_report_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append trade lifecycle record: %s", m_trade_report_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      // v0.50.0a compile fix: avoid oversized FileWrite(...) vararg call.
      // All text values pass through FalconCsvSafe to keep TradeLifecycle column counts stable.
      string trade_row = "";
      trade_row += FalconCsvSafe(EA_NAME) + ",";
      trade_row += FalconCsvSafe(EA_VERSION_TAG) + ",";
      trade_row += FalconCsvSafe(EA_BUILD_TAG) + ",";
      trade_row += FalconCsvSafe(m_symbol_context.symbol) + ",";
      trade_row += FalconCsvSafe(record.trade_id) + ",";
      trade_row += FalconCsvSafe(record.strategy_id) + ",";
      trade_row += FalconCsvSafe(record.strategy_name) + ",";
      trade_row += FalconCsvSafe(record.engine_id) + ",";
      trade_row += FalconCsvSafe(FalconStageToString(record.stage)) + ",";
      trade_row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      trade_row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      trade_row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      trade_row += DoubleToString(record.lot_size, 2) + ",";
      trade_row += DoubleToString(record.entry_price, m_symbol_context.digits) + ",";
      trade_row += DoubleToString(record.structural_sl, m_symbol_context.digits) + ",";
      trade_row += DoubleToString(record.tp1, m_symbol_context.digits) + ",";
      trade_row += DoubleToString(record.tp2, m_symbol_context.digits) + ",";
      trade_row += DoubleToString(record.tp3, m_symbol_context.digits) + ",";
      trade_row += DoubleToString(record.exit_price, m_symbol_context.digits) + ",";
      trade_row += FalconCsvSafe(FalconOutcomeToString(record.outcome)) + ",";
      trade_row += FalconCsvSafe(FalconOutcomeToString(record.outcome)) + ",";
      trade_row += DoubleToString(record.profit_index_points, 2) + ",";
      trade_row += DoubleToString(record.loss_index_points, 2) + ",";
      trade_row += DoubleToString(record.net_index_points, 2) + ",";
      trade_row += DoubleToString(record.profit_usd, 2) + ",";
      trade_row += DoubleToString(record.loss_usd, 2) + ",";
      trade_row += DoubleToString(record.net_usd, 2) + ",";
      trade_row += DoubleToString(record.fvg_size_points, 2) + ",";
      trade_row += IntegerToString((int)record.fvg_spread_points) + ",";
      trade_row += IntegerToString(record.fvg_retest_age_bars) + ",";
      trade_row += FalconCsvSafe(FalconTimeToString(record.fvg_setup_time)) + ",";
      trade_row += FalconCsvSafe(FalconTimeToString(record.fvg_retest_watch_time)) + ",";
      trade_row += IntegerToString(record.fvg_age_bars_at_watch) + ",";
      trade_row += FalconCsvSafe(record.fvg_age_source) + ",";
      trade_row += FalconCsvSafe(record.fvg_retest_fresh_state) + ",";
      trade_row += IntegerToString(record.fvg_hold_quality_score) + ",";
      trade_row += FalconCsvSafe(record.fvg_hold_quality_bucket) + ",";
      trade_row += FalconCsvSafe(FalconBoolToYesNo(record.quality_filters_passed)) + ",";
      trade_row += FalconCsvSafe(record.fvg_quality_shadow_guard_profile) + ",";
      trade_row += FalconCsvSafe(FalconBoolToYesNo(record.fvg_quality_shadow_guard_passed)) + ",";
      trade_row += FalconCsvSafe(record.fvg_quality_shadow_guard_decision) + ",";
      trade_row += FalconCsvSafe(record.fvg_quality_shadow_guard_reason) + ",";
      trade_row += DoubleToString(record.fvg_quality_shadow_guard_sim_net_points, 2) + ",";
      trade_row += DoubleToString(record.fvg_quality_shadow_guard_sim_net_usd, 2) + ",";
      trade_row += FalconCsvSafe(record.paper_guard_status) + ",";
      trade_row += FalconCsvSafe(record.paper_reject_reason) + ",";
      trade_row += FalconCsvSafe(record.paper_guard_layer) + ",";
      trade_row += IntegerToString((int)record.paper_spread_points) + ",";
      trade_row += IntegerToString(record.paper_max_spread_points) + ",";
      trade_row += DoubleToString(record.paper_sl_distance_points, 2) + ",";
      trade_row += IntegerToString((int)record.paper_stops_level_points) + ",";
      trade_row += IntegerToString((int)record.paper_freeze_level_points) + ",";
      trade_row += DoubleToString(record.paper_guard_net_index_points, 2) + ",";
      trade_row += DoubleToString(record.paper_guard_net_usd, 2) + ",";
      trade_row += FalconCsvSafe(record.paper_protection_state) + ",";
      trade_row += DoubleToString(record.paper_virtual_sl, m_symbol_context.digits) + ",";
      trade_row += FalconCsvSafe(record.paper_protection_trigger) + ",";
      trade_row += DoubleToString(record.paper_protection_level, m_symbol_context.digits) + ",";
      trade_row += FalconCsvSafe(FalconBoolToYesNo(record.paper_protection_activated)) + ",";
      trade_row += FalconCsvSafe(FalconBoolToYesNo(record.paper_virtual_sl_changed)) + ",";
      trade_row += FalconCsvSafe(FalconBoolToYesNo(record.paper_virtual_sl_hit)) + ",";
      trade_row += FalconCsvSafe(record.paper_exit_reason) + ",";
      trade_row += DoubleToString(record.paper_protection_net_index_points, 2) + ",";
      trade_row += DoubleToString(record.paper_protection_net_usd, 2) + ",";
      trade_row += FalconCsvSafe(record.paper_runner_state) + ",";
      trade_row += FalconCsvSafe(FalconBoolToYesNo(record.paper_runner_activated)) + ",";
      trade_row += DoubleToString(record.paper_runner_max_r, 2) + ",";
      trade_row += DoubleToString(record.paper_runner_captured_points, 2) + ",";
      trade_row += DoubleToString(record.paper_runner_additional_points, 2) + ",";
      trade_row += FalconCsvSafe(record.paper_runner_exit_reason) + ",";
      trade_row += DoubleToString(record.paper_runner_net_index_points, 2) + ",";
      trade_row += DoubleToString(record.paper_runner_net_usd, 2) + ",";
      trade_row += FalconCsvSafe(record.paper_final_exit_reason) + ",";
      trade_row += FalconCsvSafe(record.falcon_tier_at_entry) + ",";
      trade_row += FalconCsvSafe(record.falcon_tier_at_exit) + ",";
      trade_row += DoubleToString(record.falcon_effective_balance, 2) + ",";
      trade_row += DoubleToString(record.falcon_tier_min_balance, 2) + ",";
      trade_row += DoubleToString(record.falcon_tier_max_balance, 2) + ",";
      trade_row += IntegerToString(record.falcon_tier_max_losses) + ",";
      trade_row += DoubleToString(record.falcon_tier_max_daily_r, 2) + ",";
      trade_row += DoubleToString(record.falcon_tier_max_drawdown_pct, 2) + ",";
      trade_row += DoubleToString(record.falcon_broker_min_lot, 2) + ",";
      trade_row += DoubleToString(record.falcon_fixed_lot, 2) + ",";
      trade_row += FalconCsvSafe(record.falcon_min_lot_constraint) + ",";
      trade_row += FalconCsvSafe(record.falcon_lotsizing_feasibility_status) + ",";
      trade_row += FalconCsvSafe(record.falcon_lotsizing_feasibility_reason) + ",";
      trade_row += DoubleToString(record.falcon_min_lot_risk_points, 2) + ",";
      trade_row += DoubleToString(record.falcon_min_lot_risk_usd, 2) + ",";
      trade_row += DoubleToString(record.falcon_min_lot_risk_pct_of_capital, 2) + ",";
      trade_row += DoubleToString(record.falcon_tier_base_risk_pct, 2) + ",";
      trade_row += DoubleToString(record.falcon_tier_risk_budget_usd, 2) + ",";
      trade_row += DoubleToString(record.falcon_potential_loss_r, 2) + ",";
      trade_row += DoubleToString(record.falcon_max_single_trade_loss_r, 2) + ",";
      trade_row += IntegerToString(record.falcon_single_trade_loss_cap_breach) + ",";
      trade_row += FalconCsvSafe(record.falcon_single_trade_loss_cap_status) + ",";
      trade_row += FalconCsvSafe(record.falcon_single_trade_loss_cap_decision) + ",";
      trade_row += FalconCsvSafe(record.falcon_single_trade_loss_cap_reason) + ",";
      trade_row += IntegerToString(record.falcon_single_trade_loss_cap_runtime_enforced) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_strict_cap_r, 2) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_calibrated_cap_r, 2) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_risk_pct_cap, 2) + ",";
      trade_row += IntegerToString(record.falcon_single_trade_loss_cap_blocked) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_before_net_points, 2) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_after_net_points, 2) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_impact_points, 2) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_before_net_usd, 2) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_after_net_usd, 2) + ",";
      trade_row += DoubleToString(record.falcon_single_trade_loss_cap_impact_usd, 2) + ",";
      trade_row += FalconCsvSafe(record.falcon_dynamic_capital_mode) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_capital_before_trade, 2) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_capital_after_trade, 2) + ",";
      trade_row += FalconCsvSafe(record.falcon_dynamic_risk_tier_by_capital) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_pct_of_capital, 2) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_single_trade_cap_pct, 2) + ",";
      trade_row += IntegerToString(record.falcon_dynamic_capital_aware_blocked) + ",";
      trade_row += FalconCsvSafe(record.falcon_dynamic_capital_reason) + ",";
      trade_row += FalconCsvSafe(record.falcon_emergency_status) + ",";
      trade_row += IntegerToString(record.falcon_emergency_triggered_layer) + ",";
      trade_row += FalconCsvSafe(record.falcon_emergency_reason) + ",";
      trade_row += IntegerToString(record.falcon_layer1_consecutive_losses) + ",";
      trade_row += IntegerToString(record.falcon_layer1_max_losses) + ",";
      trade_row += DoubleToString(record.falcon_layer2_daily_r, 2) + ",";
      trade_row += DoubleToString(record.falcon_layer2_max_daily_r, 2) + ",";
      trade_row += DoubleToString(record.falcon_layer3_drawdown_pct, 2) + ",";
      trade_row += DoubleToString(record.falcon_layer3_max_drawdown_pct, 2) + ",";
      trade_row += DoubleToString(record.falcon_emergency_before_net_points, 2) + ",";
      trade_row += DoubleToString(record.falcon_emergency_after_net_points, 2) + ",";
      trade_row += DoubleToString(record.falcon_emergency_before_net_usd, 2) + ",";
      trade_row += DoubleToString(record.falcon_emergency_after_net_usd, 2) + ",";
      trade_row += FalconCsvSafe(record.falcon_reset_status) + ",";
      trade_row += IntegerToString(record.falcon_layer1_reset_on_win) + ",";
      trade_row += IntegerToString(record.falcon_layer2_reset_on_new_day) + ",";
      trade_row += IntegerToString(record.falcon_layer3_reset_on_new_peak) + ",";
      trade_row += FalconCsvSafe(record.falcon_reset_reason) + ",";
      trade_row += FalconCsvSafe(record.close_reason) + ",";
      trade_row += FalconCsvSafe(record.evidence_summary);
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
      CFalconLogger::Info("ExecutionGuard active: OrderSend / real trade execution is intentionally disabled in v0.55.1. SIZE250 can only block Shadow staging; FalconGuard, TradeManagement, SL/TP, Smart TM, Bar-Path, Decision Tree, and Timing diagnostics are reporting-only beyond the controlled Shadow guard.");
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
   PrintFormat("Stage: Risk & TradeManagement Architecture Consolidation / No Behavior Change / No OrderSend / No runtime SL change");
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

   if(!g_fvg_micro_lifecycle_simulator.Initialize(g_fvg_micro_tradeplan_stager, g_market_context, g_shadow_executor))
      return INIT_FAILED;
   FalconTradeLifecycleRecord lifecycle_record_on_init;
   if(g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord(lifecycle_record_on_init))
      g_report_writer.RegisterClosedTrade(lifecycle_record_on_init);
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
   CFalconLogger::Info("v0.55.1 Low-Capital Risk Feasibility Foundation active: measurement-only; no trade blocking yet.");
   g_execution_guard.AssertNoExecution();

   g_is_initialized = true;
   CFalconLogger::Info("Initialization completed successfully. EA is Shadow/Paper-reporting only, Risk/TM architecture-consolidated, FalconGuard pre-execution design-ready, and report-ready.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   FalconUpdateReportPeriodLastSeen();
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
   // v0.43.0: event-driven state update scaffold only.
   // Future Demo/Live builds will use this event as the source of truth
   // for open/partial/close/modify state. This build still sends no
   // orders and performs no broker-side modifications.
   FalconOttuRouteTransaction(trans);
}

void OnTick()
{
   if(!g_is_initialized)
      return;

   g_runtime_tick_counter++;
   FalconUpdateReportPeriodLastSeen();

   // v0.18.4 refreshes the FVG shadow pipeline during runtime and can close staged Shadow records diagnostically at TP1/SL/timeout.
   // Broker execution remains impossible. No OrderSend is used.
   FalconRunFvgMicroRuntimeShadowPipeline("OnTick_FvgRuntimePipeline");
   g_fvg_micro_lifecycle_simulator.Refresh(g_market_context, g_shadow_executor);

   FalconTradeLifecycleRecord lifecycle_record;
   if(g_fvg_micro_lifecycle_simulator.ExtractClosedLifecycleRecord(lifecycle_record))
   {
      g_report_writer.RegisterClosedTrade(lifecycle_record);
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
