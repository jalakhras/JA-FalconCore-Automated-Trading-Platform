//+------------------------------------------------------------------+
//| Risk/FalconTradeLifecycleContract.mqh                            |
//| R0.7cd: data-bus contract for the Apply* chain (post-peel).      |
//|                                                                  |
//| Purpose - single point of reference for the two data types that  |
//| the Apply* chain reads from and writes to:                       |
//|                                                                  |
//|   1. FalconTradeLifecycleRecord (the per-trade record passed by  |
//|      reference through the chain; mutated in-place by each Apply |
//|      step to record what the layer decided).                     |
//|                                                                  |
//|   2. FalconReportTotals (the cumulative `m_totals` aggregate;    |
//|      updated by Apply* steps + Update*Foundation helpers;        |
//|      consumed by WriteFinalSummary).                             |
//|                                                                  |
//| Both structs are defined in Core/FalconDataStructures.mqh; this  |
//| file does NOT redefine them, it only re-asserts the include and  |
//| documents the contract so the processor and the report writer    |
//| both have a single header to point at.                           |
//|                                                                  |
//| ============ The Apply* data flow (post-R0.7cd) ============     |
//|                                                                  |
//|   CFalconReportWriter::RegisterClosedTrade                       |
//|       |                                                          |
//|       v                                                          |
//|   g_risk_lifecycle_processor                                     |
//|       .ApplyTradeLifecycleChain(record)                          |
//|       |                                                          |
//|       v                                                          |
//|   12 Apply* steps run in load-bearing actual order:              |
//|       #3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12          |
//|       (FVG-quality guard -> paper-runtime trio -> capital-tier   |
//|        -> low-capital feasibility -> DLM -> single-trade loss    |
//|        cap -> user-override pair -> three-layer emergency ->     |
//|        capital-flow classification.)                             |
//|       Each step mutates `record` in place.                       |
//|       |                                                          |
//|       v                                                          |
//|   Control returns to RegisterClosedTrade. ReportWriter then      |
//|   reads record.emergency_* / classification / DLM / paper-*      |
//|   fields and writes CSV rows. Direction is strictly:             |
//|        Risk writes record  ->  Reporting reads record.           |
//|   Risk layer does NOT call back into ReportWriter.               |
//|                                                                  |
//| Step ordering is load-bearing - later steps read state that      |
//| earlier steps wrote (e.g. DLM #10 reads decisions from #5/#6;    |
//| Three-Layer Emergency #11 reads runner/SL state set by #5/#6).   |
//| The source of truth for the order is                             |
//|   Risk/FalconRiskLifecycleProcessor.mqh::ApplyTradeLifecycleChain|
//| Any future re-ordering MUST be validated against the byte-for-   |
//| byte financial outcome on the FixedLot April reference run       |
//| (RawNetUSD=585.17 / FinalWorkingNetUSD=1104.89 / broker=157.49). |
//|                                                                  |
//| R0.7cd STATUS: processor owns the chain; ReportWriter is report- |
//| only; the 12 Apply* bodies live ONLY in                          |
//| Risk/FalconRiskLifecycleProcessor.mqh as private members of      |
//| CFalconRiskLifecycleProcessor.                                   |
//+------------------------------------------------------------------+
#ifndef FALCON_RISK_TRADE_LIFECYCLE_CONTRACT_MQH
#define FALCON_RISK_TRADE_LIFECYCLE_CONTRACT_MQH

// Source-of-truth re-include. Core/FalconDataStructures.mqh has its
// own include guard, so this is a no-op at preprocess time when the
// main .mq5 has already included Core/ (which it does at the top).
// Re-stated so this contract file is self-describing: readers do not
// have to trace back to main .mq5 to discover where
// FalconTradeLifecycleRecord and FalconReportTotals are defined.
#include "../Core/FalconDataStructures.mqh"

// Reference - the two contract types (full definitions in
// Core/FalconDataStructures.mqh):
//
//   struct FalconTradeLifecycleRecord
//       Per-trade fields populated through the lifecycle: trade_id,
//       direction, entry_*, exit_*, net_usd, net_index_points,
//       paper_guard_*, paper_protection_*, paper_runner_*,
//       falcon_single_trade_loss_cap_* (before/after),
//       falcon_market_close_*, falcon_dlm_active_lot,
//       three-layer-emergency fields (emergency_*),
//       capital-flow classification fields, session-boundary fields,
//       close-reason flags, falcon_market_close_blocked, etc.
//
//   struct FalconReportTotals
//       Cumulative counters and aggregates used by Summary writer
//       and integrity-status section: total_trades, win_trades,
//       win_rate, weekly_stability_*, market_close_guard_*,
//       no_new_entry_override_evaluated_trades,
//       force_close_override_*, capital_flow_*,
//       paper_state_snapshot_*, session_boundary_*,
//       dynamic_lotsizing_*, lock_parity_* (file-write gated by
//       R0.6b switches), etc.

#endif // FALCON_RISK_TRADE_LIFECYCLE_CONTRACT_MQH
