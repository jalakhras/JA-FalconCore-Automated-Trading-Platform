//+------------------------------------------------------------------+
//| Risk/FalconRiskInputs.mqh                                        |
//| R0.3: 20 FALCON_ARCH_* / FALCON_*_STATUS macros moved verbatim   |
//| from main .mq5 (lines 1680-1710). The Risk & TradeManagement     |
//| architecture consolidation block, used by                        |
//| CFalconRiskTradeManagementArchitecture inside method bodies.     |
//| The preprocessor expands these textually, so they MUST be        |
//| visible BEFORE Risk/FalconRiskTradeManagement.mqh is included.   |
//+------------------------------------------------------------------+
#ifndef FALCON_RISK_INPUTS_MQH
#define FALCON_RISK_INPUTS_MQH


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

#endif // FALCON_RISK_INPUTS_MQH
