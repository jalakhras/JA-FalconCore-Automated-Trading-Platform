//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_ScalpFvgMicroInputs.mqh         |
//| R1.1a-fix - S00 ScalpFvgMicro strategy inputs (per                |
//| JA_FalconCore_R1_1a_fix_SPEC §3).                                |
//|                                                                  |
//| R1.1a-fix scope:                                                 |
//|   - AtrPeriod (was an input) demoted to #define S00_ATR_PERIOD;  |
//|     it is a settled standard (14) that we do not tune.           |
//|   - Six S00 inputs renamed to short S00_-prefixed names.         |
//|   - Inputs reorganized into two groups: a top-level STRATEGIES   |
//|     group with the on/off switch, and a per-strategy sub-group.  |
//|   - New S00_MaxGap filter (default 6000) added to reject the     |
//|     anomalous outlier gaps that April diagnostics surfaced.      |
//|                                                                  |
//| OUT OF SCOPE: project-wide inputs (EnableMainReport, etc.) are   |
//| not renamed - cleanup is a separate deferred item (Backlog R0.6b |
//| §6).                                                             |
//+------------------------------------------------------------------+
#ifndef FALCON_S00_SCALPFVGMICRO_INPUTS_MQH
#define FALCON_S00_SCALPFVGMICRO_INPUTS_MQH

//------------------------------------------------------------------
// Settled standards - not user-tunable (per the "input needs a reason"
// rule logged in Docs/Ideas_Backlog.md).
//------------------------------------------------------------------
#define S00_ATR_PERIOD                14

//------------------------------------------------------------------
// Strategy on/off switches. One group for the whole project; S01..
// switches will land here as they come online.
//------------------------------------------------------------------
input group "═══ STRATEGIES ═══";
input bool   Enable_S00_FvgScalp   = true;    // Enable the S00 FVG Scalp strategy

//------------------------------------------------------------------
// S00 FVG Scalp parameters. Six inputs - tuned by test, not by guess.
//------------------------------------------------------------------
input group "── S00 FVG Scalp ──";
input double S00_MinGap            = 30.0;    // Minimum FVG size to trade (points)
input double S00_MaxGap            = 6000.0;  // Maximum FVG size - rejects abnormal gaps (points)
input double S00_GapAtrMult        = 0.5;     // FVG strength filter: gap >= ATR x this value
input int    S00_TrendMA           = 50;      // Trend filter SMA period (M5)
input int    S00_GapExpiry         = 20;      // Bars before an untouched FVG expires
input double S00_MinConfirmBody    = 50.0;    // Minimum confirmation candle body (points)
input double S00_MinConfirmPurity  = 0.35;    // Minimum confirmation candle purity (body / range)
input double S00_StopBuffer        = 30.0;    // Stop distance beyond FVG edge (points)
input int    S00_SwingLookback     = 30;      // Bars scanned for nearest swing (target)
input int    S00_MaxTradeBars      = 24;      // Bars before an open trade is force-closed
input bool   S00_DiagReport        = false;   // S00 FVG detection diagnostic report (on/off)

#endif // FALCON_S00_SCALPFVGMICRO_INPUTS_MQH
