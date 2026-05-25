//+------------------------------------------------------------------+
//| Strategies/S01_Harness/S01_HarnessInputs.mqh                     |
//| R1.3a - S01 Harness strategy inputs.                             |
//|                                                                  |
//| PURPOSE: a deliberately trivial, DETERMINISTIC-entry strategy    |
//| whose only job is to generate predictable trades that exercise   |
//| the platform's trade-management / governance engines so each can |
//| be verified with evidence in the central reports. It is NOT a    |
//| profit strategy.                                                 |
//|                                                                  |
//| ENTRY RULE (phase 1a, deterministic, zero lookahead):            |
//|   - Direction = sign of the last CLOSED M5 candle (shift 1):     |
//|       close > open -> BUY ; close < open -> SELL ; doji -> skip. |
//|   - Entry    = that candle's close.                              |
//|   - Stop     = beyond the candle's far edge by S01_StopBuffer:   |
//|       BUY  -> bar.low  - buffer ; SELL -> bar.high + buffer.     |
//|   - Target   = S01_TargetRMultiple * stop-distance from entry.   |
//|                                                                  |
//| SCOPE (phase 1a): entry + structural stop + R-multiple target    |
//| ONLY. No breakeven/protection, no runner, no partial close.      |
//|                                                                  |
//| Lot size is taken from the project-wide FixedLotSize input (the  |
//| harness does not introduce its own sizing knob).                 |
//+------------------------------------------------------------------+
#ifndef FALCON_S01_HARNESS_INPUTS_MQH
#define FALCON_S01_HARNESS_INPUTS_MQH

input group "── S01 Harness ──";
input bool   Enable_S01_Harness    = false;   // Enable the S01 deterministic-entry harness strategy
input bool   S01_RealExecution     = false;   // Enable real broker execution for S01 (Tester only)
input double S01_StopBuffer        = 30.0;    // Stop distance beyond the signal candle edge (points)
input double S01_TargetRMultiple   = 2.0;     // Target distance as a multiple of stop distance (R)

#endif // FALCON_S01_HARNESS_INPUTS_MQH
