# JA FalconCore v0.21.3 — FVG Quality Attribution Cleanup Lock

## Version Status
- Current Version: v0.21.3
- Build Tag: FvgQualityAttributionCleanupLock_NoExecution
- Baseline Source: v0.21.2
- Stage: Shadow only
- Execution: No OrderSend / No real execution

## Why this version exists
v0.21.2 passed parity and locked the FVG per-trade attribution fields, but the Lock rule requires cleanup after diagnostics. This version cleans the report surface by removing temporary calibration/profile simulation columns from Lock reports while keeping the official FVG attribution fields in TradeLifecycle.

## What was cleaned
- Removed temporary per-trade report columns:
  - QualityBalancedPassed
  - QualityStrictSizePassed
  - QualityTightSpreadPassed
  - QualityStrictComboPassed
- Removed temporary Summary report calibration/profile/distribution columns:
  - FvgQualityCalibrationEvaluated
  - FvgQualityDistributionCount
  - FvgSizeMin/Avg/Max
  - SpreadMin/Avg/Max
  - SpreadLE buckets
  - QualityProfile* thresholds/pass/reject columns

## What remains official
TradeLifecycle keeps the accepted FVG quality attribution fields:
- FvgSizePoints
- FvgSpreadPoints
- FvgRetestAgeBars
- FvgSetupTime
- FvgRetestWatchTime
- FvgAgeBarsAtWatch
- FvgAgeSource
- FvgRetestFreshState
- FvgHoldQualityScore
- FvgHoldQualityBucket
- QualityFiltersPassed

## Guardrails
- Trading Logic Change = NO
- Entry Change = NO
- SL/TP Change = NO
- Lifecycle Close Change = NO
- Risk Change = NO
- Execution Change = NO
- New Inputs = NO
- OrderSend = NO

## Expected Smoke Validation
Use the same smoke period as v0.21.2:
- From: 2026-04-01
- To: 2026-04-03

Expected metrics:
- TotalTrades = 81
- WinRate = 60.49%
- NetIndexPoints = +447.58
- NetUSD = +89.52

Expected report cleanup:
- TradeLifecycle should have 40 columns instead of 44.
- Summary should have the compact stable baseline + official FVG counters only.
- ReportProfile STANDARD remains 4 files only.

## Next Step
After v0.21.3 passes smoke validation, proceed to v0.22.0 — FVG Quality Shadow Guard Simulation, without activating any Guard yet.
