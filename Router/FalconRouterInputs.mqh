//+------------------------------------------------------------------+
//| Router/FalconRouterInputs.mqh                                    |
//| R0.5-fix: preprocessor macros referenced by Router classes that  |
//| were originally declared later in the main .mq5. These must be   |
//| visible BEFORE the Router class .mqh files are included, because |
//| #define substitution happens during preprocessing (before MQL5's |
//| two-pass class parse). Same pattern as Core/FalconCoreInputs.mqh |
//| and Execution/FalconExecutionInputs.mqh.                         |
//+------------------------------------------------------------------+
#ifndef FALCON_ROUTER_INPUTS_MQH
#define FALCON_ROUTER_INPUTS_MQH

// Used by CFalconStrategyRegistry::Initialize() to enable the FVG Micro
// runtime pipeline refresh path alongside the EnableStrategy_FvgMicroRetest
// input. Verbatim move from main .mq5 (pre-R0.5 line 1896).
#define EnableFvgMicroRuntimePipelineRefresh                  true

#endif // FALCON_ROUTER_INPUTS_MQH
