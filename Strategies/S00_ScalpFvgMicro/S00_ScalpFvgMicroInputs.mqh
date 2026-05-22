//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh         |
//| R1.1a - S00 ScalpFvgMicro strategy inputs (per ScalpFvgMicro_SPEC|
//| §3 + §4 and JA_FalconCore_R1_1a_SPEC §4).                        |
//|                                                                  |
//| R1.1a scope: FVG detection + the three quality filters only.     |
//| Entry/runner/protection inputs (MinConfirmBodyPoints,            |
//| StopBufferPoints, RunnerSplitPct, ProtectTriggerR, RiskPercent,  |
//| MaxTradeDurationBars) are deferred to R1.1b/c.                   |
//+------------------------------------------------------------------+
#ifndef FALCON_S00_SCALPFVGMICRO_INPUTS_MQH
#define FALCON_S00_SCALPFVGMICRO_INPUTS_MQH

input group "07 - S00 Scalp FVG Micro / اكتشاف الفجوات (R1.1a)";
input double MinGapPoints                       = 30.0;   // 3.1 Size filter floor (points). Tuned by test.
input int    AtrPeriod                          = 14;     // ATR(M5) period for the 3.2 thrust filter.
input double GapAtrMultiplier                   = 0.5;    // 3.2 gap >= ATR x multiplier.
input int    TrendMaPeriod                      = 50;     // SMA(M5, close) period for the 3.3 trend filter.
input int    GapExpiryBars                      = 20;     // Reserved for R1.1b (gap expiry).
input bool   EnableFvgDetectionDiagnostics      = false;  // R0.6b-style gate: off by default. When true, R1.1a writes S00_FvgDetection_Diagnostics.csv.

#endif // FALCON_S00_SCALPFVGMICRO_INPUTS_MQH
