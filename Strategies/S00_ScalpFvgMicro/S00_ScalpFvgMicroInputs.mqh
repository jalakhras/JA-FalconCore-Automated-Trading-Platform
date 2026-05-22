//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh         |
//| R1.1c-fix - S00 ScalpFvgMicro strategy inputs.                   |
//|                                                                  |
//| Group layout: top-level "STRATEGIES" group with the on/off       |
//| switch + a per-strategy "S00 FVG Scalp" group with parameters.   |
//|                                                                  |
//| R1.1c-fix replaces the failed R1.1c runner mechanism (half-cut
//| at +1R + breakeven tied to 1R) with a single simple protection:
//| once unrealised profit reaches S00_BreakevenTrigger points, move
//| the stop to entry. No split, no trailing, no partial close.
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
input bool   Enable_S00_FvgScalp        = true;    // Enable the S00 FVG Scalp strategy

//------------------------------------------------------------------
// S00 FVG Scalp parameters - tuned by test, not by guess.
//
// S00_AtrPeriod feeds the R1.1a gap-strength filter (gap >= ATR x
// mult). Kept as an input since the operator may tune ATR period.
//
// S00_BreakevenTrigger (R1.1c-fix) is the single protection knob:
// when unrealised profit reaches this many points, the stop moves
// to entry. No half-cut, no trailing.
//------------------------------------------------------------------
input group "── S00 FVG Scalp ──";
input double S00_MinGap                = 30.0;    // Minimum FVG size to trade (points)
input double S00_MaxGap                = 6000.0;  // Maximum FVG size - rejects abnormal gaps (points)
input double S00_GapAtrMult            = 0.5;     // FVG strength filter: gap >= ATR x this value
input int    S00_AtrPeriod             = 14;      // ATR period (M5) for the strength filter
input int    S00_TrendMA               = 50;      // Trend filter SMA period (M5)
input int    S00_GapExpiry             = 20;      // Bars before an untouched FVG expires
input double S00_MinConfirmBody        = 50.0;    // Minimum confirmation candle body (points)
input double S00_MinConfirmPurity      = 0.35;    // Minimum confirmation candle purity (body / range)
input double S00_StopBuffer            = 30.0;    // Stop distance beyond FVG edge (points)
input int    S00_SwingLookback         = 30;      // Bars scanned for nearest swing (target)
input int    S00_MaxTradeDurationBars  = 24;      // Bars before an open trade is force-closed
input double S00_BreakevenTrigger      = 800.0;   // Profit in points that moves stop to entry
input bool   S00_RealExecution         = false;   // Enable real broker execution for S00 (Tester only)
input double S00_LotSize               = 0.01;    // Fixed lot size for S00 trades
input bool   S00_DiagReport            = false;   // S00 FVG detection diagnostic report (on/off)

#endif // FALCON_S00_SCALPFVGMICRO_INPUTS_MQH
