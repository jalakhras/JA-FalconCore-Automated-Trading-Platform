//+------------------------------------------------------------------+
//|                     JA_FalconCore_Automated_Trading_Platform.mq5 |
//|                     JA FalconCore Automated Trading Platform      |
//|  Version: v0.57.4 base — Refactor in progress (branch: refactor)  |
//+------------------------------------------------------------------+
#property copyright "JA FalconCore Automated Trading Platform"
#property version   "1.00"
#property strict

// ==================================================================
// R0.2: Core layer #include block (dependency order)
// Constants -> Enums -> DataStructures -> Logger -> MarketContext -> CandleCache
// Each .mqh is a verbatim move of code that previously lived inline below.
// ==================================================================
#include "Core/FalconConstants.mqh"
#include "Core/FalconEnums.mqh"
#include "Core/FalconCoreInputs.mqh"     // R0.2-fix: Core preprocessor constants, must precede the Core class .mqh files
#include "Core/FalconDataStructures.mqh"
#include "Core/FalconLogger.mqh"
#include "Core/FalconMarketContext.mqh"
#include "Core/FalconCandleCache.mqh"

// ==================================================================
// R0.3: Evidence + Risk layer #include block (after Core)
// Evidence depends on Core only. Risk depends on Core + RiskInputs.
// ==================================================================
#include "Evidence/FalconEvidenceFramework.mqh"
#include "Risk/FalconRiskInputs.mqh"     // R0.3: FALCON_ARCH_* and FALCON_*_STATUS macros used by Risk classes
#include "Risk/FalconRiskFoundation.mqh"
#include "Risk/FalconRiskTradeManagement.mqh"
// R0.7a: foundation for the Apply* peel. Two new Risk-layer files.
// FalconTradeLifecycleContract.mqh documents the data bus (the two
// structs FalconTradeLifecycleRecord + FalconReportTotals live in
// Core/ and are NOT moved in R0.7a). FalconRiskLifecycleProcessor.mqh
// hosts an empty CFalconRiskLifecycleProcessor with a single
// placeholder method ApplyTradeLifecycleChain(record). The class is
// declared but NOT instantiated nor called anywhere in R0.7a -
// behavior is byte-identical to R0.6b. R0.7b/c/d will gradually
// move the 12 Apply* method bodies into this class, and R0.7d will
// wire the call into RegisterClosedTrade.
#include "Risk/FalconTradeLifecycleContract.mqh"
#include "Risk/FalconRiskLifecycleProcessorInputs.mqh"   // R0.7b-fix: 11 macros needed by the processor
#include "Risk/FalconRiskLifecycleProcessor.mqh"

// ==================================================================
// R0.4: Execution layer #include block (after Risk)
// ExecutionInputs carries FALCON_BEEB_*, FALCON_MREB_*, FALCON_LOCK_PARITY_*,
// FALCON_VIRTUAL_TRAILING_*, FALCON_BLA_*, FALCON_BPR_*, FALCON_DLM_*,
// and FC_MAGIC_FVG_MICRO - referenced inside Bridge method bodies.
//
// The Bridge itself is NOT included here - it depends on
// CFalconReportWriter (still defined later in main .mq5). The Bridge
// .mqh is #included further down, AFTER CFalconReportWriter is parsed
// (at the point where the Bridge class used to live).
// ==================================================================
#include "Execution/FalconExecutionInputs.mqh"
#include "Execution/FalconExecutionGuard.mqh"
#include "Execution/FalconRuntimeSafetyGuard.mqh"
#include "Execution/FalconShadowExecutor.mqh"

// ==================================================================
// R0.5: Router layer #include block (after Execution top block)
// FalconRouterInputs carries preprocessor macros referenced by Router
// classes that were originally declared later in this file (must
// precede the class .mqh files - #define is resolved at preprocess
// time, before MQL5's two-pass class parse).
// Registry depends on Core (Enums + DataStructures + Logger) and on
// the `EnableStrategy_*` / `EnableShadowMode` inputs declared further
// down in this file - those are `input` variables, resolved by MQL5's
// two-pass parse, same pattern as CFalconShadowExecutor which already
// references EnableShadowMode.
// AdapterShell additionally depends on CFalconStrategyRegistry,
// CFalconRuntimeSafetyGuard, CFalconShadowExecutor (all available
// above). Registry must precede AdapterShell.
// ==================================================================
#include "Router/FalconRouterInputs.mqh"          // preprocessor: must come before the Router class .mqh files
#include "Router/FalconStrategyRegistry.mqh"
#include "Router/FalconStrategyAdapterShell.mqh"


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
// R0.7b-fix: FALCON_SESSION_BOUNDARY_DEFAULT_CHECKPOINT_MINUTES (3) and
// FALCON_SESSION_BOUNDARY_ACTION_TO_CHECKPOINT_GAP_MINUTES (2) moved to
// Risk/FalconRiskLifecycleProcessorInputs.mqh so they precede the
// processor's #include point.
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
// R0.7cd: FALCON_FVG_QGUARD_PROFILE_TAG ("P03_SIZE250_ONLY") moved to
// Risk/FalconRiskLifecycleProcessorInputs.mqh — needed by the processor's
// ported copy of Apply #3 (ApplyFvgQualityShadowGuardSimulation).
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
// FC_MAGIC_FVG_MICRO moved to Execution/FalconExecutionInputs.mqh (R0.4)
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
// R0.7b-fix: FALCON_SSBL_MAX_SPREAD_POINTS (120) moved to Risk/FalconRiskLifecycleProcessorInputs.mqh.
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
// R0.7b-fix: FALCON_LCRF_BORDERLINE_MULTIPLIER (1.20) moved to Risk/FalconRiskLifecycleProcessorInputs.mqh.
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
// R0.7b-fix: FALCON_STLC_RUNTIME_ENFORCED (true) moved to Risk/FalconRiskLifecycleProcessorInputs.mqh.
#define FALCON_STLC_SCOPE                         "LOTSIZINGMANAGER;DYNAMIC_CAPITAL;MIN_LOT;SINGLE_TRADE_CAP;PAPER_EQUITY_CURVE;NO_AUTO_PROMOTION"
#define FALCON_STLC_POLICY                        "DYNAMIC_CAPITAL_AWARE_ENFORCEMENT;STRICT_CAP_REMAINS_MEASUREMENT;RISK_FEASIBILITY_UPDATES_AFTER_EACH_TRADE;PROMOTION_STILL_EARNED;NO_ORDER_SEND"
#define FALCON_STLC_ORDER_SEND_POLICY             "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_STLC_DRAWDOWN_CAP_MULTIPLIER       2.0
#define FALCON_STLC_ABSOLUTE_MAX_R                50.0
#define FALCON_STLC_DYNAMIC_MAX_RISK_PCT          50.0
// R0.7b-fix: FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD (1.0) and
// FALCON_STLC_DYNAMIC_CAPITAL_MODE (string) moved to Risk/FalconRiskLifecycleProcessorInputs.mqh.
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
// R0.7b-fix: FALCON_DLM_STATUS (string) moved to Risk/FalconRiskLifecycleProcessorInputs.mqh.
#define FALCON_DLM_DECISION                       "APPLY_DYNAMIC_LOT_TO_PAPER_USD_WITH_TIER_CAP_CAPITAL_CAP_AND_GROWTH_RAMP"
// R0.7b-fix: FALCON_DLM_RUNTIME_ENFORCED (true) moved to Risk/FalconRiskLifecycleProcessorInputs.mqh.
#define FALCON_DLM_SCOPE                          "LOTSIZINGMANAGER;USEFIXEDLOT;DYNAMIC_CAPITAL;STRUCTURAL_RISK;BROKER_MIN_MAX_STEP;PAPER_RUNTIME_APPLICATION;TIER_MAX_LOT;CAPITAL_MAX_LOT;GROWTH_RAMP"
#define FALCON_DLM_POLICY                         "USE_FIXED_LOT_TRUE_PRESERVES_FIXEDLOT;USE_FIXED_LOT_FALSE_APPLIES_DYNAMIC_LOT_WITH_SAFETY_RAMP;CAPITAL_UPDATES_AFTER_EACH_TRADE;TIER_CAP;CAPITAL_CAP;MAX_GROWTH_CAP;NO_BROKER_EXECUTION"
#define FALCON_DLM_ORDER_SEND_POLICY              "ORDER_SEND_HARD_BLOCKED;PAPER_ONLY;NO_DEMO;NO_LIVE;NO_BROKER_MODIFY;NO_RUNTIME_SL_CHANGE"
#define FALCON_DLM_NEXT_PHASE                     "v0.55.3b_DYNAMIC_LOTSIZING_SAFETY_RAMP_MULTI_WINDOW_LOCK"


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
// v0.57.4: Structural Breakeven - anchor the BE floor on the last confirmed
// M5 swing low (BUY) / swing high (SELL) instead of a fixed offset from entry.
// When no qualifying swing exists, fall back to the v0.57.3 spread-aware floor.
input bool   EnableStructuralBreakeven       = true;   // v0.57.4 structural BE
input int    VirtualSwingLookbackBars        = 2;      // half-window N (5-bar swing when N=2)
input int    VirtualSwingMaxLookback         = 40;     // max closed bars to scan

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
// 04 - Reporting Core / تقارير النواة الدائمة
// Two reports are always produced when EnableMainReport=true: the
// per-trade TradeLifecycle.csv and the run-level Summary.csv. They
// carry the canonical numerical outcome (RawNetUSD, FinalWorkingNetUSD,
// broker net) and are NOT gated by any of the R0.6b diagnostic group
// switches.
//
// ReportProfile is preserved as a coarse preset (MINIMAL / STANDARD /
// DEBUG / LOCKPARITY) that further refines what is emitted WITHIN an
// enabled diagnostic group. See group "05 - Diagnostic Reports" below
// for the master ON/OFF switches added in R0.6b. Coordination rule:
// a diagnostic report runs iff (its group switch is true) AND (its
// existing ReportProfile-derived gate, if any, allows it).
// ==================================================================
input group "04 - Reporting Core / تقارير النواة الدائمة";
input bool                       EnableMainReport              = true;    // ON = produce TradeLifecycle.csv + Summary.csv (the always-on core).
input ENUM_FALCON_REPORT_PROFILE ReportProfile                 = FALCON_REPORT_MINIMAL;    // R0.6b: narrowest core mode. With all R0.6b diagnostic switches false, default run emits only TradeLifecycle.csv + Summary.csv.
input string                     ReportModeTag                 = "EmergencyServerStopEnvelopeLockParityProbe"; // Embedded in filenames + Summary header.
input bool                       UseCommonFilesFolderForReports = true;   // ON = write into MQL5/Files (Common) instead of per-terminal Files/.
input bool                       EnableVerboseExpertsLog       = true;    // ON = verbose CFalconLogger output to the Experts tab.
input bool                       EnableFastRuntimeSmokeMode    = true;    // ON = condense runtime smoke probes for faster ticks.
input int                        RuntimeDiagnosticsEveryNTicks = 1000;    // Sampling cadence for runtime diagnostic probes (tick units).

// ==================================================================
// 05 - Diagnostic Reports / التقارير التشخيصية
// R0.6b: master ON/OFF switches for the ~28 non-core diagnostic CSVs,
// grouped into 6 coherent buckets. ALL DEFAULT FALSE - a stock run
// produces only the core (TradeLifecycle + Summary). Turn a switch ON
// to revive its bucket. The new switches ARE COMPOSED with the pre-
// existing ReportProfile presets: the existing per-report gates inside
// the writer remain in place, and a group is silenced if EITHER its
// new switch is FALSE or its existing ReportProfile gate already says
// no. See Docs/ReviewNotes/R0_6b_Review_Notes.md for the bucket-to-
// report classification table.
// ==================================================================
input group "05 - Diagnostic Reports / التقارير التشخيصية";
input bool   EnableBrokerReports          = false;  // تقارير البروكر (5): ExecutionLifecycle، TradeManagementEventTimeline، ContractRealityAudit، RebasedPaperComparison، PaperTradeReconciliation.
input bool   EnableLockParityReports      = false;  // تحليل Lock Parity (2): ExecutabilityDecomposition، ExecutabilityRollup. منطق Lock Parity الداخلي يبقى يعمل بلا تغيير.
input bool   EnableVirtualTrailingReport  = false;  // الـ Virtual Trailing (1): VirtualTrailingExitLifecycle. (يبقى مشروطًا أيضًا بـ EnableVirtualTrailingBridge + tester-only.)
input bool   EnableTierEmergencyReports   = false;  // حالة الصفقة (3): TierTransitions، EmergencyTriggers، PaperStateSnapshot. عدّادات m_totals.* تبقى تعمل (R0.6b: نطفئ كتابة الملف، لا الحساب).
input bool   EnableStrategyRegistryReport = false;  // سجل الاستراتيجيات (1): StrategyRegistryDiagnostics فقط — جرد الاستراتيجيات وحالة كل واحدة.
input bool   EnableDebugDiagnostics       = false;  // التشخيص العميق (~17): StrategyAdapter، 5 FVG-Micro debug، Market/CandleCache/Evidence/Shadow/NoLookahead، ReportCalibration، RuntimeReportVerification، FvgMicroSmokeTest، FvgMicroRuntimeReportAudit، ReportCreationGuarantee.



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
// R0.6b: each gate now ANDs with its R0.6b group switch from input
// group "05 - Diagnostic Reports". With all 6 group switches default
// FALSE and ReportProfile default MINIMAL, a stock run emits only
// the core (TradeLifecycle + Summary). ReportProfile is preserved as
// a coarse preset that further refines emission WITHIN an enabled
// group (e.g. DEBUG-only Market/Cache/etc. still requires DEBUG even
// when its DebugDiagnostics group is on).
//
// Group mapping (R0.6b):
//   - EnableStrategyRegistryReport gates ONLY the StrategyRegistry CSV.
//   - EnableDebugDiagnostics       gates StrategyAdapter + the 5 FVG-Micro
//                                  debug CSVs + 5 deep-debug diagnostics
//                                  + ReportCalibration / RuntimeVerification
//                                  / SmokeTest / RuntimeReportAudit /
//                                  ReportCreationGuarantee.
#define EnableMarketDiagnosticsReport                         (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableCandleCacheDiagnosticsReport                    (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableEvidenceDiagnosticsReport                       (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableShadowDiagnosticsReport                         (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableNoLookaheadDiagnosticsReport                    (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableStrategyRegistryDiagnosticsReport               (EnableStrategyRegistryReport && FalconReportProfileIsStandardOrDebug())
#define EnableStrategyAdapterDiagnosticsReport                (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableFvgMicroDetectorDiagnosticsReport               (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableFvgMicroCandidateDiagnosticsReport              (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableFvgMicroRetestWatcherDiagnosticsReport          (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableFvgMicroTradePlanStagingDiagnosticsReport       (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableFvgMicroLifecycleSimulationDiagnosticsReport    (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableReportCalibrationDiagnosticsReport              (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableRuntimeReportVerificationReport                 (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableFvgMicroSmokeTestDiagnosticsReport              (EnableDebugDiagnostics       && FalconReportProfileIsDebug())
#define EnableFvgMicroRuntimeReportAuditReport                (EnableDebugDiagnostics       && FalconReportProfileIsDebug())

// R0.2-fix: UseClosedCandlesOnly and PrimaryContextTimeframe moved to
// Core/FalconCoreInputs.mqh so they are defined BEFORE the Core class
// .mqh files (which use them in expressions evaluated at preprocess time).
#define EnableReportPeriodInFileNames                         FALCON_ENABLE_REPORT_PERIOD_IN_FILE_NAMES
#define AutoDetectReportPeriodTags                            FALCON_AUTO_DETECT_REPORT_PERIOD_TAGS
#define RenameReportsToActualPeriodOnDeinit                   FALCON_RENAME_REPORTS_TO_ACTUAL_PERIOD
#define ReportFromDateTag                                     FALCON_REPORT_FROM_DATE_TAG
#define ReportToDateTag                                       FALCON_REPORT_TO_DATE_TAG
#define ForceCreateReportFilesOnInit                          FALCON_FORCE_CREATE_REPORT_FILES_ON_INIT
#define PrintReportFolderHintsToLog                           FALCON_PRINT_REPORT_FOLDER_HINTS_TO_LOG
// EnableFvgMicroRuntimePipelineRefresh moved to Router/FalconRouterInputs.mqh (R0.5-fix)
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













// ==================================================================
// Strategy-agnostic broker execution contracts - v0.56.0 foundation
// These records are intentionally not FVG-specific. Future strategies
// must publish the same StrategyId/EngineId/TradeId contract into the
// broker layer before any real broker action is allowed.
// ==================================================================

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
   if(!EnableDebugDiagnostics) return; // R0.6b group gate - manifest is debug-grade metadata
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


// R0.5: CFalconStrategyRegistry moved to Router/FalconStrategyRegistry.mqh
//       (included at the top of this file in the Router #include block).


// R0.5: CFalconFirstShadowStrategyAdapterShell moved to
//       Router/FalconStrategyAdapterShell.mqh (included at the top of
//       this file in the Router #include block).

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
// R0.6a: CFalconReportWriter moved to Reporting/FalconReportWriter.mqh
// Include placed exactly where the class used to live - mid-file,
// AFTER all dependencies are parsed (Core/Evidence/Risk/Execution top/
// Router classes; all FvgMicro stub classes; all inputs and #defines),
// and BEFORE Execution/FalconBrokerEntryBridge.mqh (Bridge calls 6
// telemetry methods on this class - see the Bridge #include below).
// ==================================================================
#include "Reporting/FalconReportWriter.mqh"



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

// ==================================================================
// R0.4: BrokerEntryBridge #include — at the spot where the class used
// to live. Placed here because it depends on CFalconReportWriter
// (which is defined earlier in this file). All other Execution-layer
// .mqh files are included at the top of main .mq5.
// ==================================================================
#include "Execution/FalconBrokerEntryBridge.mqh"


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
// R0.7cd: the 12-step Apply* chain owner. Invoked from
// CFalconReportWriter::RegisterClosedTrade as a single call replacing
// the 12 inline Apply* calls that used to live there.
CFalconRiskLifecycleProcessor g_risk_lifecycle_processor;
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
   // R0.8b: seed the canonical Risk state owner. Same symbol_context,
   // same call site, immediately after g_report_writer.Initialize so
   // ReportWriter's SymbolContext() forwarder resolves correctly on
   // every subsequent call.
   g_risk_lifecycle_processor.Initialize(symbol_context);
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
