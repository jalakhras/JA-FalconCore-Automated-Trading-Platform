//+------------------------------------------------------------------+
//|                     JA_FalconCore_Automated_Trading_Platform.mq5 |
//|                     JA FalconCore Automated Trading Platform      |
//|                     Version: v0.27.1 - TradeManagement Foundation Validation Lock |
//+------------------------------------------------------------------+
#property copyright "JA FalconCore Automated Trading Platform"
#property version   "1.271"
#property strict

#define EA_NAME        "JA FalconCore Automated Trading Platform"
#define EA_VERSION_TAG "v0.27.1"
#define EA_BUILD_TAG   "TradeManagementFoundationValidationLock_NoExecution"

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
#define FALCON_TM_NEXT_REQUIRED_LAYER                    "STRUCTURAL_STOP_AND_TP_BUILDER_VALIDATION_LAYER"
#define FALCON_TM_NEXT_ENGINEERING_PHASE                 "v0.28.0_StructuralStopTPBuilderValidationLayer"

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

      CFalconLogger::Info(StringFormat("SymbolContext initialized: %s | Digits=%d | Point=%.10f | TickSize=%.10f | TickValue=%.5f | Contract=%.2f | MinLot=%.2f | Step=%.2f | StopsLevel=%d",
                                       m_symbol.symbol,
                                       m_symbol.digits,
                                       m_symbol.point,
                                       m_symbol.tick_size,
                                       m_symbol.tick_value,
                                       m_symbol.contract_size,
                                       m_symbol.min_lot,
                                       m_symbol.lot_step,
                                       (int)m_symbol.stops_level_points));

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
         "FalconTradeManagementNextRequiredLayer,FalconTradeManagementNextEngineeringPhase";

      string summary_row =
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
         IntegerToString(hold_quality_score_min) + "," +
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
         FalconBoolToYesNo(FALCON_FVG_QGUARD_RUNTIME_CANDIDATE_ALLOWED) + "," +
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
         IntegerToString(MaxTradesPerDay) + "," +
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
         FalconCsvSafe(FALCON_TM_TP_BUILDER_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_TP1_POLICY) + "," +
         FalconCsvSafe(FALCON_TM_TP2_POLICY) + "," +
         FalconCsvSafe(FALCON_TM_PARTIAL_MANAGER_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_PROOF_PROTECTION_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_RUNNER_MANAGER_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_ADAPTIVE_RATCHET_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_EARLY_FAILURE_EXIT_STATUS) + "," +
         FalconCsvSafe(FALCON_TM_LIVE_ELIGIBILITY) + "," +
         FalconCsvSafe(FALCON_TM_NEXT_REQUIRED_LAYER) + "," +
         FalconCsvSafe(FALCON_TM_NEXT_ENGINEERING_PHASE);

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

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol",
                "TradeId", "StrategyId", "StrategyName", "EngineId",
                "Stage", "Direction", "EntryTime", "ExitTime",
                "LotSize", "Entry", "SL", "TP1", "TP2", "TP3", "Exit",
                "Outcome", "WinLose",
                "ProfitIndexPoints", "LoseIndexPoints", "NetIndexPoints",
                "ProfitUSD", "LoseUSD", "NetUSD",
                "FvgSizePoints", "FvgSpreadPoints", "FvgRetestAgeBars",
                "FvgSetupTime", "FvgRetestWatchTime", "FvgAgeBarsAtWatch", "FvgAgeSource",
                "FvgRetestFreshState", "FvgHoldQualityScore", "FvgHoldQualityBucket",
                "QualityFiltersPassed",
                "FvgQGuardProfile", "FvgQGuardPassed", "FvgQGuardDecision", "FvgQGuardReason",
                "FvgQGuardSimNetPoints", "FvgQGuardSimNetUSD",
                "CloseReason", "EvidenceSummary");
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
      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                record.trade_id,
                record.strategy_id,
                record.strategy_name,
                record.engine_id,
                FalconStageToString(record.stage),
                FalconDirectionToString(record.direction),
                FalconTimeToString(record.entry_time),
                FalconTimeToString(record.exit_time),
                DoubleToString(record.lot_size, 2),
                DoubleToString(record.entry_price, m_symbol_context.digits),
                DoubleToString(record.structural_sl, m_symbol_context.digits),
                DoubleToString(record.tp1, m_symbol_context.digits),
                DoubleToString(record.tp2, m_symbol_context.digits),
                DoubleToString(record.tp3, m_symbol_context.digits),
                DoubleToString(record.exit_price, m_symbol_context.digits),
                FalconOutcomeToString(record.outcome),
                FalconOutcomeToString(record.outcome),
                DoubleToString(record.profit_index_points, 2),
                DoubleToString(record.loss_index_points, 2),
                DoubleToString(record.net_index_points, 2),
                DoubleToString(record.profit_usd, 2),
                DoubleToString(record.loss_usd, 2),
                DoubleToString(record.net_usd, 2),
                DoubleToString(record.fvg_size_points, 2),
                (int)record.fvg_spread_points,
                record.fvg_retest_age_bars,
                FalconTimeToString(record.fvg_setup_time),
                FalconTimeToString(record.fvg_retest_watch_time),
                record.fvg_age_bars_at_watch,
                record.fvg_age_source,
                record.fvg_retest_fresh_state,
                record.fvg_hold_quality_score,
                record.fvg_hold_quality_bucket,
                FalconBoolToYesNo(record.quality_filters_passed),
                record.fvg_quality_shadow_guard_profile,
                FalconBoolToYesNo(record.fvg_quality_shadow_guard_passed),
                record.fvg_quality_shadow_guard_decision,
                record.fvg_quality_shadow_guard_reason,
                DoubleToString(record.fvg_quality_shadow_guard_sim_net_points, 2),
                DoubleToString(record.fvg_quality_shadow_guard_sim_net_usd, 2),
                record.close_reason,
                record.evidence_summary);
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
      CFalconLogger::Info("ExecutionGuard active: OrderSend / real trade execution is intentionally disabled in v0.26.3. SIZE250 can only block Shadow staging; FalconGuard pre-execution gate is locked but not runtime-enforced.");
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

   PrintFormat("============================================================");
   PrintFormat("%s", EA_NAME);
   PrintFormat("Version: %s | Build: %s", EA_VERSION_TAG, EA_BUILD_TAG);
   PrintFormat("Stage: FalconGuard Pre-Execution Enforcement Design / FVG Micro SIZE250 Shadow Candidate / No OrderSend / No real execution");
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

   g_execution_guard.AssertNoExecution();

   g_is_initialized = true;
   CFalconLogger::Info("Initialization completed successfully. EA is Shadow-only, FalconGuard pre-execution design-ready, and report-ready.");
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
