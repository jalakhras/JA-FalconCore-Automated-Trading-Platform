//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh         |
//| R1.1c - S00 ScalpFvgMicro strategy inputs.                       |
//|                                                                  |
//| Group layout: top-level "STRATEGIES" group with the on/off       |
//| switch + a per-strategy "S00 FVG Scalp" group with parameters.   |
//|                                                                  |
//| OUT OF SCOPE: project-wide pre-refactor inputs (EnableMainReport,|
//| ReportProfile, etc.) are NOT renamed - cleanup is a separate     |
//| deferred item (Ideas_Backlog #36).                               |
//+------------------------------------------------------------------+
#ifndef FALCON_S00_SCALPFVGMICRO_INPUTS_MQH
#define FALCON_S00_SCALPFVGMICRO_INPUTS_MQH

//------------------------------------------------------------------
// Strategy on/off switches. One group for the whole project;
// S01.. switches will land here as they come online.
//------------------------------------------------------------------
input group "═══ STRATEGIES ═══";
input bool   Enable_S00_FvgScalp     = true;    // Enable the S00 FVG Scalp strategy

//------------------------------------------------------------------
// S00 FVG Scalp parameters - tuned by test, not by guess.
//
// R1.1c promoted S00_AtrPeriod back to an input (was a #define in
// R1.1a-fix). The single ATR period now serves two consumers:
//   (a) the R1.1a-fix gap-strength filter (gap >= ATR x mult).
//   (b) the R1.1c runner trailing-stop (close - mult x ATR).
// One source of truth - the operator tunes one knob.
//
// R1.1c renamed S00_MaxTradeBars -> S00_MaxTradeDurationBars to
// align with the R1.1c SPEC wording.
//------------------------------------------------------------------
input group "── S00 FVG Scalp ──";
input double S00_MinGap                = 30.0;    // Minimum FVG size to trade (points)
input double S00_MaxGap                = 6000.0;  // Maximum FVG size - rejects abnormal gaps (points)
input double S00_GapAtrMult            = 0.5;     // FVG strength filter: gap >= ATR x this value
input int    S00_AtrPeriod             = 14;      // ATR period (M5) - feeds the strength filter and the runner trail
input int    S00_TrendMA               = 50;      // Trend filter SMA period (M5)
input int    S00_GapExpiry             = 20;      // Bars before an untouched FVG expires
input double S00_MinConfirmBody        = 50.0;    // Minimum confirmation candle body (points)
input double S00_MinConfirmPurity      = 0.35;    // Minimum confirmation candle purity (body / range)
input double S00_StopBuffer            = 30.0;    // Stop distance beyond FVG edge (points)
input int    S00_SwingLookback         = 30;      // Bars scanned for nearest swing (target)
input int    S00_MaxTradeDurationBars  = 24;      // Bars before an open trade is force-closed
input double S00_RunnerSplitPct        = 50.0;    // Insurance-half size, % of position volume
input double S00_ProtectTriggerR       = 1.0;     // Profit in R that fires split + breakeven
input double S00_RunnerTrailAtrMult    = 2.0;     // Runner trailing-stop distance, ATR multiples
input bool   S00_DiagReport            = false;   // S00 FVG detection diagnostic report (on/off)

#endif // FALCON_S00_SCALPFVGMICRO_INPUTS_MQH
