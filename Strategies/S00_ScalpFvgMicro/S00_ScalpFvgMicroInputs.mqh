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
input bool   Enable_S00_FvgScalp   = true;    // R1.1a-fix: declared now; wired to the chain in R1.1b. R1.1a-fix is still detection-only.

//------------------------------------------------------------------
// S00 FVG Scalp parameters. Six inputs - tuned by test, not by guess.
//------------------------------------------------------------------
input group "── S00 FVG Scalp ──";
input double S00_MinGap            = 30.0;    // SIZE filter floor (points).
input double S00_MaxGap            = 6000.0;  // R1.1a-fix: MAXSIZE filter ceiling (points). Rejects holiday/data outliers; April keeps ~92% of accepted gaps, sits above the 90th pct.
input double S00_GapAtrMult        = 0.5;     // ATR filter: gap >= ATR(M5) x multiplier.
input int    S00_TrendMA           = 50;      // TREND filter: SMA(M5, close) period.
input int    S00_GapExpiry         = 20;      // Reserved for R1.1b (gap expiry, bars).
input bool   S00_DiagReport        = false;   // R0.6b-style gate: off by default. When true, R1.1a writes S00_FvgDetection_Diagnostics.csv.

#endif // FALCON_S00_SCALPFVGMICRO_INPUTS_MQH
