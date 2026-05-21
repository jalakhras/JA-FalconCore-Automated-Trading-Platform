//+------------------------------------------------------------------+
//| Core/FalconCoreInputs.mqh                                        |
//| R0.2-fix: configuration constants the Core layer depends on at   |
//| preprocessor time. Moved verbatim from main .mq5 lines 1929-1931 |
//| so they are visible BEFORE FalconMarketContext.mqh /             |
//| FalconCandleCache.mqh are included. No value or logic change.    |
//|                                                                  |
//| Note: these are #define constants (not input variables). They    |
//| are kept in this file - alongside other Core configuration -     |
//| because Core classes use them in expressions that the            |
//| preprocessor expands BEFORE link-time resolution of real input   |
//| variables (which the compiler still resolves correctly via       |
//| link-time symbol lookup even when declared later).               |
//+------------------------------------------------------------------+
#ifndef FALCON_COREINPUTS_MQH
#define FALCON_COREINPUTS_MQH

// Core runtime constants. These are architectural defaults, not user inputs.
#define UseClosedCandlesOnly                                  true
#define PrimaryContextTimeframe                               PERIOD_M5

#endif // FALCON_COREINPUTS_MQH
