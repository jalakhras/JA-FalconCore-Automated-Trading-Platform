//+------------------------------------------------------------------+
//| Risk/FalconRiskLifecycleProcessorInputs.mqh                      |
//| R0.7b-fix: 11 preprocessor constants relocated here so they are  |
//| visible at the point where CFalconRiskLifecycleProcessor is      |
//| #included (early in main .mq5, after the Risk R0.3 block, well   |
//| before the inline #define blocks at L111+, L1033, L1701..L1742). |
//|                                                                  |
//| Same pattern as Core/FalconCoreInputs.mqh, Risk/FalconRiskInputs |
//| .mqh, Router/FalconRouterInputs.mqh, Execution/FalconExecutionIn |
//| puts.mqh: a small header of preprocessor constants included      |
//| before the class headers that use them.                          |
//|                                                                  |
//| 9 of the 11 macros relocated FROM the main .mq5 body. 2 of the   |
//| 11 (the DLM constants) relocated FROM                            |
//| Execution/FalconExecutionInputs.mqh (they govern DLM logic which |
//| now lives in Risk — the constants travel with it).               |
//+------------------------------------------------------------------+
#ifndef FALCON_RISK_LIFECYCLE_PROCESSOR_INPUTS_MQH
#define FALCON_RISK_LIFECYCLE_PROCESSOR_INPUTS_MQH

// --- Session-boundary recovery (moved from main .mq5 L111-112) ---
#define FALCON_SESSION_BOUNDARY_DEFAULT_CHECKPOINT_MINUTES 3
#define FALCON_SESSION_BOUNDARY_ACTION_TO_CHECKPOINT_GAP_MINUTES 2

// --- Smart-SL blocker max spread (moved from main .mq5 L1033) ---
#define FALCON_SSBL_MAX_SPREAD_POINTS                 120

// --- Low-Capital-Risk-Feasibility (moved from main .mq5 L1701) ---
#define FALCON_LCRF_BORDERLINE_MULTIPLIER         1.20

// --- Single-Trade-Loss-Cap (moved from main .mq5 L1716, L1723-1724) ---
#define FALCON_STLC_RUNTIME_ENFORCED              true
#define FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD     1.0
#define FALCON_STLC_DYNAMIC_CAPITAL_MODE          "PAPER_RISK_CAPITAL_BEFORE_TRADE_UPDATES_AFTER_EACH_CLOSED_TRADE"

// --- Dynamic-Lot-Sizing Model (moved from main .mq5 L1740, L1742) ---
#define FALCON_DLM_STATUS                         "DYNAMIC_LOTSIZING_SAFETY_RAMP_MAX_GROWTH_CAP"
#define FALCON_DLM_RUNTIME_ENFORCED               true

// --- DLM capital/growth constants (moved from Execution/FalconExecutionInputs.mqh L70-71) ---
// They govern DLM lot ramp + per-001-lot capital requirement; DLM logic
// is now ported into CFalconRiskLifecycleProcessor (R0.7b), so the
// constants travel with it.
#define FALCON_DLM_CAPITAL_USD_PER_001_LOT        250.0
#define FALCON_DLM_MAX_LOT_GROWTH_MULTIPLIER      1.20

#endif // FALCON_RISK_LIFECYCLE_PROCESSOR_INPUTS_MQH
