//+------------------------------------------------------------------+
//| Risk/FalconTradeLifecycleContract.mqh                            |
//| R0.7a: data-bus contract for the Apply* chain.                   |
//|                                                                  |
//| Purpose - documentation + single point of reference for the      |
//| two data types that the Apply* chain reads from and writes to:   |
//|                                                                  |
//|   1. FalconTradeLifecycleRecord (the per-trade record passed by  |
//|      reference through the chain; mutated in-place by each Apply |
//|      step to record what the layer decided).                     |
//|                                                                  |
//|   2. FalconReportTotals (the cumulative `m_totals` member on the |
//|      ReportWriter; updated by Apply* steps + Update*Foundation   |
//|      helpers; consumed by WriteFinalSummary).                    |
//|                                                                  |
//| Both structs are defined in Core/FalconDataStructures.mqh and    |
//| are NOT moved in R0.7a (per spec §1: "لا تحرّك بنى من Core").  |
//| This file only documents the contract and re-asserts the include |
//| of the source-of-truth header. When R0.7b/c/d gradually populate |
//| CFalconRiskLifecycleProcessor with the 12 Apply* method bodies,  |
//| every step in the chain reads/writes through these two types -   |
//| this contract pins the names and the source location so the      |
//| extraction work has a fixed reference.                           |
//|                                                                  |
//| ============ The Apply* data flow ============                   |
//|                                                                  |
//|   FalconTradeLifecycleRecord record   (caller's stack record)    |
//|       |                                                          |
//|       v                                                          |
//|   Apply #1  ApplyNoNewEntryUserOverridePaperEnforcement          |
//|   Apply #2  ApplyDailyWeekendForceCloseUserOverridePaperEnforce  |
//|   Apply #3  ApplyFvgQualityShadowGuardSimulation                 |
//|   Apply #4  ApplyPaperRuntimeGuardApplication                    |
//|   Apply #5  ApplyPaperRuntimeSmartSLProtectionApplication        |
//|   Apply #6  ApplyPaperRuntimeRunnerApplication                   |
//|   Apply #7  ApplyCapitalTierFoundation                           |
//|   Apply #8  ApplyLowCapitalRiskFeasibilityFoundation             |
//|   Apply #9  ApplyCalibratedSingleTradeLossCapEnforcement         |
//|   Apply #10 ApplyDynamicLotSizingModel                           |
//|   Apply #11 ApplyThreeLayerEmergencyApplication                  |
//|   Apply #12 ApplyCapitalFlowSourceClassification                 |
//|       |                                                          |
//|       v                                                          |
//|   m_totals updated; record handed back to RegisterClosedTrade    |
//|                                                                  |
//| Step ordering is load-bearing (see Docs/ReviewNotes/             |
//| R0_6a_Review_Notes.md §3.5 / "caller graph"): later steps read   |
//| state that earlier steps wrote. R0.7b/c/d must preserve order.   |
//|                                                                  |
//| R0.7a STATUS: contract pinned, no code moved. The 12 Apply*      |
//| bodies still live in Reporting/FalconReportWriter.mqh.           |
//+------------------------------------------------------------------+
#ifndef FALCON_RISK_TRADE_LIFECYCLE_CONTRACT_MQH
#define FALCON_RISK_TRADE_LIFECYCLE_CONTRACT_MQH

// Source-of-truth re-include. Core/FalconDataStructures.mqh has its
// own include guard, so this is a no-op at preprocess time when the
// main .mq5 has already included Core/ (which it does at the top).
// We re-state the include so the contract file is self-describing:
// readers don't have to trace back to main .mq5 to discover where
// FalconTradeLifecycleRecord and FalconReportTotals are defined.
#include "../Core/FalconDataStructures.mqh"

// R0.7a leaves the two contract types in Core/. If a later phase
// (R0.7b/R0.8) decides to relocate them to Risk/, only this file's
// #include needs to change; the rest of the codebase already refers
// to the type names FalconTradeLifecycleRecord and FalconReportTotals
// directly and would be unaffected.
//
// Reference - the two contract types (their full definitions live in
// Core/FalconDataStructures.mqh):
//
//   struct FalconTradeLifecycleRecord  (declared at L445 pre-R0.7a)
//       Holds per-trade fields populated through the lifecycle:
//       trade_id, direction, entry_*, exit_*, net_usd, net_index_points,
//       paper_guard_net_usd, paper_protection_net_usd, paper_runner_net_usd,
//       falcon_single_trade_loss_cap_* (before/after), falcon_market_close_*,
//       falcon_dlm_active_lot, three-layer-emergency fields, capital-flow
//       classification fields, session-boundary fields, close-reason flags,
//       falcon_market_close_blocked, etc.
//
//   struct FalconReportTotals         (declared at L796 pre-R0.7a)
//       Cumulative counters and aggregates used by the Summary writer
//       and the integrity-status section: total_trades, win_trades,
//       win_rate, weekly_stability_*, market_close_guard_*,
//       no_new_entry_override_evaluated_trades, force_close_override_*,
//       capital_flow_*, paper_state_snapshot_*, session_boundary_*,
//       dynamic_lotsizing_*, lock_parity_* (computed but file-write
//       gated by R0.6b), etc.

#endif // FALCON_RISK_TRADE_LIFECYCLE_CONTRACT_MQH
