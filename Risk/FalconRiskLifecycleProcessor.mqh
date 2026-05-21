//+------------------------------------------------------------------+
//| Risk/FalconRiskLifecycleProcessor.mqh                            |
//| R0.7a: empty class shell. The 12 Apply* methods will migrate     |
//| here gradually in R0.7b / R0.7c / R0.7d.                         |
//|                                                                  |
//| Why a shell now? R0.7a is foundation-only - it pins the future   |
//| target class so R0.7b/c/d can each be a clean "move N methods    |
//| over" commit with no plumbing surprises. The class is NOT called |
//| from CFalconReportWriter::RegisterClosedTrade in R0.7a; wiring   |
//| up that call site happens in R0.7d after every Apply* body has   |
//| been ported. Until then, the 12 Apply* still execute from inside |
//| ReportWriter exactly as today, with byte-identical output.       |
//|                                                                  |
//| Planned migration order (from Docs/ReviewNotes/R0_6a_Review_     |
//| Notes.md §3.5 - the order MUST match the existing chain in       |
//| RegisterClosedTrade because later Apply* steps consume state     |
//| written by earlier ones):                                        |
//|                                                                  |
//|   R0.7b - 7 Risk-natural methods, in chain order:                |
//|       Apply #1  ApplyNoNewEntryUserOverridePaperEnforcement      |
//|       Apply #2  ApplyDailyWeekendForceCloseUserOverride...       |
//|       Apply #4  ApplyPaperRuntimeGuardApplication                |
//|       Apply #5  ApplyPaperRuntimeSmartSLProtectionApplication    |
//|       Apply #6  ApplyPaperRuntimeRunnerApplication               |
//|       Apply #7  ApplyCapitalTierFoundation                       |
//|       Apply #8  ApplyLowCapitalRiskFeasibilityFoundation         |
//|       Apply #9  ApplyCalibratedSingleTradeLossCapEnforcement     |
//|       Apply #10 ApplyDynamicLotSizingModel                       |
//|       Apply #11 ApplyThreeLayerEmergencyApplication              |
//|       (count: 9 Apply* total in the Risk-natural batch)          |
//|                                                                  |
//|   R0.7c - the 1 classification-only method:                      |
//|       Apply #12 ApplyCapitalFlowSourceClassification             |
//|                                                                  |
//|   R0.7d - wire up: replace the 11 inline Apply* calls in         |
//|       RegisterClosedTrade with a single                          |
//|       g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);|
//|       call. Apply #3 (ApplyFvgQualityShadowGuardSimulation) is   |
//|       a strategy-quality filter and may move to                  |
//|       Strategies/S00_ScalpFvgMicro/ in a separate phase rather   |
//|       than into Risk; R0.7d decides.                             |
//|                                                                  |
//| The contract file (FalconTradeLifecycleContract.mqh) documents   |
//| the data bus shared with the Apply* chain.                       |
//+------------------------------------------------------------------+
#ifndef FALCON_RISK_LIFECYCLE_PROCESSOR_MQH
#define FALCON_RISK_LIFECYCLE_PROCESSOR_MQH

#include "FalconTradeLifecycleContract.mqh"

class CFalconRiskLifecycleProcessor
{
public:
   //
   // Single public entry-point for the Apply* chain. R0.7a:
   // placeholder body - does nothing, returns immediately. Not
   // invoked from anywhere in R0.7a (RegisterClosedTrade still
   // calls the 12 Apply* methods inline inside CFalconReportWriter,
   // unchanged). R0.7b/c will populate this body by adding private
   // method members ported verbatim from ReportWriter, then calling
   // them in the historical order. R0.7d wires this entry-point in
   // as the single replacement for the 12 inline Apply* calls.
   //
   // The record is passed by reference because every step in the
   // chain mutates it in place; see FalconTradeLifecycleContract.mqh
   // for the field-level contract.
   //
   void ApplyTradeLifecycleChain(FalconTradeLifecycleRecord &record)
   {
      // R0.7a placeholder - intentionally empty.
      // R0.7b/c/d will add private method calls here in the order
      // documented in Docs/ReviewNotes/R0_7a_Review_Notes.md.
      // MQL5 does not warn on unused parameters; the empty body
      // is the simplest form.
      return;
   }
};

#endif // FALCON_RISK_LIFECYCLE_PROCESSOR_MQH
