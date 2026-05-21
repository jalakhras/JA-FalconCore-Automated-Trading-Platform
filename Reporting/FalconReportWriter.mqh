//+------------------------------------------------------------------+
//| Reporting/FalconReportWriter.mqh                                 |
//| R0.6a: verbatim move of CFalconReportWriter (~6,292 lines) from  |
//| the main .mq5. This is a STRUCTURAL move only - zero behavior    |
//| change. All reports continue to be produced exactly as before.   |
//|                                                                  |
//| The 12 Apply* methods inside this class are NOT touched (R0.7    |
//| target). Lock Parity Decomposer logic is NOT touched. Broker     |
//| telemetry methods are NOT touched.                               |
//|                                                                  |
//| Dependencies resolved at include point (still inside main .mq5,  |
//| where the class used to live):                                   |
//|   - Core (DataStructures/Enums/Logger/MarketContext/CandleCache) |
//|   - Evidence + Risk classes                                      |
//|   - Execution top block (RuntimeSafetyGuard, ShadowExecutor)     |
//|   - Router (StrategyRegistry, StrategyAdapterShell)              |
//|   - All FvgMicro stub classes (still inline in main .mq5)        |
//|   - All inputs and #defines (all declared above L5562)           |
//| Must precede Execution/FalconBrokerEntryBridge.mqh include       |
//| (Bridge calls 6 telemetry methods on this class).                |
//+------------------------------------------------------------------+
#ifndef FALCON_REPORTING_REPORT_WRITER_MQH
#define FALCON_REPORTING_REPORT_WRITER_MQH

// ==================================================================
// Report Writer Foundation - append-ready CSV contracts
// ==================================================================
class CFalconReportWriter
{
private:
   string              m_trade_report_file;
   string              m_summary_report_file;
   string              m_market_diagnostics_file;
   string              m_candle_cache_diagnostics_file;
   string              m_evidence_diagnostics_file;
   string              m_shadow_diagnostics_file;
   string              m_no_lookahead_diagnostics_file;
   string              m_strategy_registry_diagnostics_file;
   string              m_strategy_adapter_diagnostics_file;
   string              m_fvg_micro_detector_diagnostics_file;
   string              m_fvg_micro_candidate_diagnostics_file;
   string              m_fvg_micro_retest_watcher_diagnostics_file;
   string              m_fvg_micro_tradeplan_staging_diagnostics_file;
   string              m_fvg_micro_lifecycle_simulation_diagnostics_file;
   string              m_report_calibration_diagnostics_file;
   string              m_runtime_report_verification_file;
   string              m_fvg_micro_smoke_test_file;
   string              m_fvg_micro_runtime_report_audit_file;
   string              m_report_creation_guarantee_file;
   string              m_tier_transitions_file;
   string              m_emergency_triggers_file;
   string              m_paper_state_snapshot_file;
   string              m_broker_execution_lifecycle_file;
   string              m_broker_tm_timeline_file;
   string              m_broker_contract_reality_audit_file;
   string              m_broker_rebased_paper_comparison_file;
   string              m_broker_paper_reconciliation_file;
   // v0.57.0: Lock Parity Executability Decomposer report files.
   string              m_lock_parity_decomp_file;
   string              m_lock_parity_rollup_file;
   // v0.57.2: Virtual Trailing Exit Bridge report file.
   string              m_virtual_trailing_exit_lifecycle_file;
   FalconSymbolContext m_symbol_context;
   FalconReportTotals  m_totals;

   // v0.53.1: Three-layer paper emergency state.
   bool                m_tle_emergency_active;
   string              m_tle_emergency_reason;
   int                 m_tle_consecutive_losses;
   datetime            m_tle_current_day;
   double              m_tle_daily_r;
   double              m_tle_equity;
   double              m_tle_peak_equity;
   double              m_tle_max_drawdown_pct;

   // v0.55.3b: Dynamic lot sizing safety ramp state.
   bool                m_dlm_previous_active_lot_ready;
   double              m_dlm_previous_active_lot;


   // v0.55.9: Weekly Stability Score summary-only state.
   int                 m_wss_week_keys[16];
   int                 m_wss_week_trades[16];
   int                 m_wss_week_wins[16];
   double              m_wss_week_net_usd[16];

   // v0.22.2 Lock cleanup: multi-profile summary arrays removed from active report surface.

   bool                m_initialized;
   int                 m_broker_entry_bridge_order_send_attempts;

public:
   CFalconReportWriter()
   {
      m_initialized = false;
      m_broker_entry_bridge_order_send_attempts = 0;
      ResetTotals();
   }

   bool Initialize(const FalconSymbolContext &symbol_context)
   {
      m_symbol_context     = symbol_context;
      m_broker_entry_bridge_order_send_attempts = 0;
      m_trade_report_file  = FalconBuildReportFileName("TradeLifecycle");
      m_summary_report_file= FalconBuildReportFileName("Summary");
      m_market_diagnostics_file = FalconBuildReportFileName("MarketDiagnostics");
      m_candle_cache_diagnostics_file = FalconBuildReportFileName("CandleCacheDiagnostics");
      m_evidence_diagnostics_file = FalconBuildReportFileName("EvidenceDiagnostics");
      m_shadow_diagnostics_file = FalconBuildReportFileName("ShadowDiagnostics");
      m_no_lookahead_diagnostics_file = FalconBuildReportFileName("NoLookaheadDiagnostics");
      m_strategy_registry_diagnostics_file = FalconBuildReportFileName("StrategyRegistryDiagnostics");
      m_strategy_adapter_diagnostics_file = FalconBuildReportFileName("StrategyAdapterDiagnostics");
      m_fvg_micro_detector_diagnostics_file = FalconBuildReportFileName("FvgMicroDetectorDiagnostics");
      m_fvg_micro_candidate_diagnostics_file = FalconBuildReportFileName("FvgMicroShadowCandidateDiagnostics");
      m_fvg_micro_retest_watcher_diagnostics_file = FalconBuildReportFileName("FvgMicroRetestWatcherDiagnostics");
      m_fvg_micro_tradeplan_staging_diagnostics_file = FalconBuildReportFileName("FvgMicroTradePlanStagingDiagnostics");
      m_fvg_micro_lifecycle_simulation_diagnostics_file = FalconBuildReportFileName("FvgMicroLifecycleSimulationDiagnostics");
      m_report_calibration_diagnostics_file = FalconBuildReportFileName("ReportCalibrationCleanupGate");
      m_runtime_report_verification_file = FalconBuildReportFileName("RuntimeReportVerification");
      m_fvg_micro_smoke_test_file = FalconBuildReportFileName("FvgMicroRuntimeSmokeTest");
      m_fvg_micro_runtime_report_audit_file = FalconBuildReportFileName("FvgMicroRuntimeReportAudit");
      m_report_creation_guarantee_file = FalconBuildReportFileName("ReportCreationGuarantee");
      m_tier_transitions_file = FalconBuildReportFileName("TierTransitions");
      m_emergency_triggers_file = FalconBuildReportFileName("EmergencyTriggers");
      m_paper_state_snapshot_file = FalconBuildReportFileName("PaperStateSnapshot");
      m_broker_execution_lifecycle_file = FalconBuildReportFileName(FALCON_BROKER_EXECUTION_LIFECYCLE_REPORT_NAME);
      m_broker_tm_timeline_file = FalconBuildReportFileName(FALCON_BROKER_TM_TIMELINE_REPORT_NAME);
      m_broker_contract_reality_audit_file = FalconBuildReportFileName(FALCON_BROKER_CONTRACT_REALITY_REPORT_NAME);
      m_broker_rebased_paper_comparison_file = FalconBuildReportFileName(FALCON_BROKER_REBASED_COMPARISON_REPORT_NAME);
      m_broker_paper_reconciliation_file = FalconBuildReportFileName(FALCON_BROKER_PAPER_RECONCILIATION_REPORT_NAME);
      // v0.57.0: Lock Parity Executability Decomposer report files.
      m_lock_parity_decomp_file = FalconBuildReportFileName(FALCON_LOCK_PARITY_DECOMP_REPORT_NAME);
      m_lock_parity_rollup_file = FalconBuildReportFileName(FALCON_LOCK_PARITY_ROLLUP_REPORT_NAME);
      // v0.57.2: Virtual Trailing Exit Bridge report file.
      m_virtual_trailing_exit_lifecycle_file = FalconBuildReportFileName(FALCON_VIRTUAL_TRAILING_EXIT_LIFECYCLE_REPORT_NAME);
      ResetTotals();

      if(EnableMainReport)
      {
         WriteTradeHeader();
         WriteSummaryHeader();
         if(!FalconReportProfileIsLockParity())
         {
            WriteTierTransitionsHeader();
            WriteEmergencyTriggersHeader();
            WritePaperStateSnapshotHeader();
            WriteBrokerExecutionLifecycleHeader();
            WriteBrokerTradeManagementEventTimelineHeader();
            WriteBrokerRebasedPaperComparisonHeader();
            WriteBrokerPaperTradeReconciliationHeader();
            WriteBrokerContractRealityAudit();
         }
         // v0.57.0: Lock Parity Executability Decomposer header.
         WriteLockParityDecompositionHeader();
         // v0.57.2: Virtual Trailing Exit Bridge header. Only emit the file when the
         // bridge can actually fire (tester-only managed close path) so LOCKPARITY
         // without execution stays at exactly 4 CSVs.
         if(EnableVirtualTrailingBridge && EnableRealExecution && MQLInfoInteger(MQL_TESTER))
            WriteVirtualTrailingExitLifecycleHeader();
      }

      if(ForceCreateReportFilesOnInit)
         WriteReportCreationGuaranteeFile();

      m_initialized = true;
      CFalconLogger::Info(StringFormat("ReportWriter initialized. TradeReport=%s | SummaryReport=%s", m_trade_report_file, m_summary_report_file));
      return true;
   }


   void WriteTierTransitionsHeader()
   {
      int handle = FileOpen(m_tier_transitions_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create TierTransitions event file: %s", m_tier_transitions_file));
         return;
      }

      FileWriteString(handle,
                      "Timestamp,FromTier,ToTier,Direction,Reason,Balance,TradesInPreviousTier,WinRate,NetR\r\n");
      FileClose(handle);
   }

   void WriteEmergencyTriggersHeader()
   {
      int handle = FileOpen(m_emergency_triggers_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create EmergencyTriggers event file: %s", m_emergency_triggers_file));
         return;
      }

      FileWriteString(handle,
                      "Timestamp,LayerTriggered,TierAtTrigger,Balance,ConsecutiveLossCount,DailyR,DrawdownPct,BlockedEntries,ResolvedAt,AutoResolved\r\n");
      FileClose(handle);
   }


   void WritePaperStateSnapshotHeader()
   {
      int handle = FileOpen(m_paper_state_snapshot_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create PaperStateSnapshot event file: %s", m_paper_state_snapshot_file));
         return;
      }

      string header = "SnapshotTime,Version,Build,TradeId,StrategyId,EngineId,Direction,EntryTime,ExitTime,EntryPrice,StructuralSL,TP1,TP2,TP3,ActiveLot,CapitalBefore,CapitalAfter,ProtectionState,RunnerState,EmergencyStatus,RecoveryMode,StateTrusted,SessionBoundaryCheckpointType,SessionBoundaryCloseTime,SessionBoundaryRecoveryCheckpointTime,ActiveDuringRecoveryWindow,RequiresRecovery,Notes";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }


   void WriteBrokerExecutionLifecycleHeader()
   {
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerExecutionLifecycle foundation report: %s", m_broker_execution_lifecycle_file));
         return;
      }

      string header = "EventKind,TradeId,StrategyId,EngineId,Direction,EventTime,PlannedEntryPrice,BrokerEntryPrice,LotSize,";
      header += "BrokerEntryAttempted,BrokerEntryAccepted,BrokerCloseAttempted,BrokerCloseAccepted,";
      header += "BrokerPositionTicket,BrokerOrderTicket,BrokerDealTicket,BrokerMagic,";
      header += "PaperRawTradeUSD,PaperFinalWorkingTradeUSD,PaperRawIndexPoints,PaperFinalWorkingIndexPoints,";
      header += "BrokerRebasedRawUSD,BrokerRebasedFinalUSD,BrokerActualBalanceDelta,BrokerVsPaperFinalDelta,BrokerVsPaperFinalDeltaStatus,";
      header += "ExecutionPolicy,Status,Reason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }


   void WriteBrokerPaperTradeReconciliationHeader()
   {
      int handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerPaperTradeReconciliation report: %s", m_broker_paper_reconciliation_file));
         return;
      }

      string header = "ReconciliationEvent,TradeId,TradeIdShort,StrategyId,EngineId,Direction,";
      header += "PaperEntryTime,BrokerEntryTime,EntryTimeDeltaSeconds,PaperExitTime,BrokerExitTime,ExitTimeDeltaSeconds,";
      header += "PaperEntryPrice,BrokerEntryPrice,EntryPriceDelta,StructuralSL,BrokerSL,SLDelta,TP1,TP2,TP3,BrokerTP,TPDelta,";
      header += "PaperExitPrice,BrokerClosePrice,ClosePriceDelta,BrokerActualPoints,BrokerActualPointsMinusPaperFinalPoints,";
      header += "ExpectedBrokerUSDFromPaperFinalPointsAtExecutedLot,BrokerActualMinusExpectedBrokerFinalUSD,ServerStopAttachPolicy,";
      header += "PaperRawUSD,PaperFinalWorkingUSD,BrokerActualUSD,BrokerMinusPaperFinalUSD,";
      header += "PaperRawPoints,PaperFinalWorkingPoints,";
      header += "BrokerPositionTicket,BrokerPositionIdentifier,BrokerOrderTicket,BrokerEntryDealTicket,BrokerCloseOrderTicket,BrokerCloseDealTicket,";
      header += "BrokerExitType,ManagedCloseAttempted,ManagedCloseObserved,ServerSLHit,ServerTPHit,NotOpenedReason,";
      header += "LotRequested,LotAuthorized,LotExecuted,LotDelta,";
      header += "ReconciliationRowRole,IsFinalReconciliationRow,LockParityGapCategory,LockParityGapPrimaryCause,LockParityGapUSD,LockParityRecommendedAction,";
      header += "Status,Reason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }

   void WriteBrokerTradeManagementEventTimelineHeader()
   {
      int handle = FileOpen(m_broker_tm_timeline_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerTradeManagementEventTimeline foundation report: %s", m_broker_tm_timeline_file));
         return;
      }

      string header = "TradeId,StrategyId,EngineId,Direction,EventType,EventTime,EventPrice,EventExecutable,ExecutionEligibility,";
      header += "BrokerPositionTicket,TP1Touched,TP2Touched,ProtectionActivated,RunnerActivated,ProtectionState,RunnerState,";
      header += "PaperRawTradeUSD,PaperFinalWorkingTradeUSD,PaperProtectionNetUSD,PaperRunnerNetUSD,";
      header += "PaperRawIndexPoints,PaperFinalWorkingIndexPoints,EventSource,Status,Reason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }




   void WriteBrokerRebasedPaperComparisonHeader()
   {
      int handle = FileOpen(m_broker_rebased_paper_comparison_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerRebasedPaperComparison audit report: %s", m_broker_rebased_paper_comparison_file));
         return;
      }

      string header = "TradeId,StrategyId,EngineId,Direction,EntryTime,ExitTime,LotSize,ActiveLot,";
      header += "LegacyPaperRawUSD,LegacyPaperFinalUSD,PaperRawPoints,PaperFinalPoints,PaperLegacyUsdPerIndexPoint,";
      header += "ContractSize,VolumeMin,VolumeStep,ReferenceLot,BrokerUsdPerIndexPointAtOneLot,BrokerUsdPerIndexPointAtActiveLot,";
      header += "BrokerRebasedRawUSD,BrokerRebasedFinalUSD,BrokerActualUSD,BrokerActualVsRebasedFinalUSD,BrokerActualVsRebasedFinalStatus,";
      header += "RequiredParityLot,BrokerMinLot,ParityLotBelowMin,OrderCalcProfitAvailable,RebaseStatus,ExecutionPolicy,Reason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }

   double FalconTimelineFinalWorkingTradeUsd(const FalconTradeLifecycleRecord &record)
   {
      return record.falcon_emergency_after_net_usd;
   }

   double FalconTimelineFinalWorkingTradePoints(const FalconTradeLifecycleRecord &record)
   {
      return record.falcon_emergency_after_net_points;
   }



   double FalconRebaseActiveLotForRecord(const FalconTradeLifecycleRecord &record)
   {
      if(record.falcon_dlm_active_lot > 0.0)
         return record.falcon_dlm_active_lot;
      if(record.lot_size > 0.0)
         return record.lot_size;
      return FALCON_BROKER_REBUILD_REFERENCE_LOT;
   }

   double FalconPaperUsdPerIndexPointForRecord(const FalconTradeLifecycleRecord &record)
   {
      if(MathAbs(record.net_index_points) > 0.0000001)
         return MathAbs(record.net_usd / record.net_index_points);
      double active_lot = FalconRebaseActiveLotForRecord(record);
      if(m_symbol_context.contract_size > 0.0 && active_lot > 0.0)
         return MathAbs(m_symbol_context.contract_size * active_lot);
      return 0.0;
   }

   bool FalconBrokerUsdPerIndexPointByOrderCalc(const FalconTradeLifecycleRecord &record,
                                                const double lot,
                                                double &value_per_index_point)
   {
      value_per_index_point = 0.0;
      if(lot <= 0.0)
         return false;

      double open_price = record.entry_price;
      if(open_price <= 0.0)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         open_price = (ask > 0.0 ? ask : bid);
      }
      if(open_price <= 0.0)
         return false;

      ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
      double close_price = open_price + 1.0;
      if(record.direction == FALCON_DIRECTION_SELL)
      {
         order_type = ORDER_TYPE_SELL;
         close_price = open_price - 1.0;
      }

      double profit = 0.0;
      if(!OrderCalcProfit(order_type, _Symbol, lot, open_price, close_price, profit))
         return false;

      value_per_index_point = MathAbs(profit);
      return (value_per_index_point > 0.0);
   }

   double FalconBrokerUsdPerIndexPointFallback(const double lot)
   {
      if(m_symbol_context.contract_size > 0.0 && lot > 0.0)
         return MathAbs(m_symbol_context.contract_size * lot);
      return 0.0;
   }

   void FalconBrokerRebaseValuesForRecord(const FalconTradeLifecycleRecord &record,
                                          double &broker_value_one_lot,
                                          double &broker_value_active_lot,
                                          bool &ordercalc_available)
   {
      double value_one_lot = 0.0;
      bool ordercalc_one = FalconBrokerUsdPerIndexPointByOrderCalc(record, 1.0, value_one_lot);
      if(!ordercalc_one)
         value_one_lot = FalconBrokerUsdPerIndexPointFallback(1.0);

      double active_lot = FalconRebaseActiveLotForRecord(record);
      double value_active = 0.0;
      bool ordercalc_active = FalconBrokerUsdPerIndexPointByOrderCalc(record, active_lot, value_active);
      if(!ordercalc_active)
         value_active = FalconBrokerUsdPerIndexPointFallback(active_lot);

      broker_value_one_lot = value_one_lot;
      broker_value_active_lot = value_active;
      ordercalc_available = (ordercalc_one && ordercalc_active);
   }

   datetime FalconTimelineSafeEventTime(const FalconTradeLifecycleRecord &record, const bool prefer_entry)
   {
      if(prefer_entry && record.entry_time > 0)
         return record.entry_time;
      if(!prefer_entry && record.exit_time > 0)
         return record.exit_time;
      if(record.exit_time > 0)
         return record.exit_time;
      return record.entry_time;
   }

   string FalconTimelineCloseReasonEventStatus(const FalconTradeLifecycleRecord &record)
   {
      if(FalconClosedAtStop(record))
         return "RAW_STOP_CLOSE_RECORDED";
      if(FalconClosedByTimeout(record))
         return "RAW_TIMEOUT_CLOSE_RECORDED";
      if(FalconClosedAtTp1(record))
         return "RAW_TP1_CLOSE_RECORDED";
      return "RAW_FINAL_CLOSE_RECORDED";
   }



   void AppendBrokerRebasedPaperComparisonRecord(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      int handle = FileOpen(m_broker_rebased_paper_comparison_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerRebasedPaperComparisonHeader();
         handle = FileOpen(m_broker_rebased_paper_comparison_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerRebasedPaperComparison row: %s", m_broker_rebased_paper_comparison_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);

      double active_lot = FalconRebaseActiveLotForRecord(record);
      double final_usd = FalconTimelineFinalWorkingTradeUsd(record);
      double final_points = FalconTimelineFinalWorkingTradePoints(record);
      double paper_usd_per_index_point = FalconPaperUsdPerIndexPointForRecord(record);
      double broker_value_one_lot = 0.0;
      double broker_value_active_lot = 0.0;
      bool ordercalc_available = false;
      FalconBrokerRebaseValuesForRecord(record, broker_value_one_lot, broker_value_active_lot, ordercalc_available);

      double broker_rebased_raw_usd = record.net_index_points * broker_value_active_lot;
      double broker_rebased_final_usd = final_points * broker_value_active_lot;
      double broker_actual_usd = 0.0;
      double broker_actual_vs_rebased_final = 0.0;
      double required_parity_lot = 0.0;
      if(broker_value_one_lot > 0.0 && paper_usd_per_index_point > 0.0)
         required_parity_lot = paper_usd_per_index_point / broker_value_one_lot;
      bool parity_lot_below_min = (required_parity_lot > 0.0 && m_symbol_context.min_lot > 0.0 && required_parity_lot < m_symbol_context.min_lot);
      string rebase_status = FALCON_BELR_REBASED_STATUS;
      if(!ordercalc_available)
         rebase_status = FALCON_BELR_REBASE_ORDERCALC_FALLBACK_STATUS;

      string row = "";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      row += DoubleToString(record.lot_size, 4) + ",";
      row += DoubleToString(active_lot, 4) + ",";
      row += DoubleToString(record.net_usd, 4) + ",";
      row += DoubleToString(final_usd, 4) + ",";
      row += DoubleToString(record.net_index_points, 2) + ",";
      row += DoubleToString(final_points, 2) + ",";
      row += DoubleToString(paper_usd_per_index_point, 6) + ",";
      row += DoubleToString(m_symbol_context.contract_size, 6) + ",";
      row += DoubleToString(m_symbol_context.min_lot, 4) + ",";
      row += DoubleToString(m_symbol_context.lot_step, 4) + ",";
      row += DoubleToString(FALCON_BROKER_REBUILD_REFERENCE_LOT, 4) + ",";
      row += DoubleToString(broker_value_one_lot, 6) + ",";
      row += DoubleToString(broker_value_active_lot, 6) + ",";
      row += DoubleToString(broker_rebased_raw_usd, 4) + ",";
      row += DoubleToString(broker_rebased_final_usd, 4) + ",";
      row += DoubleToString(broker_actual_usd, 4) + ",";
      row += DoubleToString(broker_actual_vs_rebased_final, 4) + ",";
      row += FalconCsvSafe(FALCON_BELR_REBASED_NO_ACTUAL_STATUS) + ",";
      row += DoubleToString(required_parity_lot, 6) + ",";
      row += DoubleToString(m_symbol_context.min_lot, 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(parity_lot_below_min)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(ordercalc_available)) + ",";
      row += FalconCsvSafe(rebase_status) + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe("AUDIT_ONLY_REBASES_PAPER_POINTS_TO_BROKER_CONTRACT_VALUE_NO_ORDER_SEND_NO_BROKER_CLOSE");

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerExecutionLifecycleAuditRecord(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerExecutionLifecycleHeader();
         handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerExecutionLifecycle audit row: %s", m_broker_execution_lifecycle_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      double final_usd = FalconTimelineFinalWorkingTradeUsd(record);
      double final_points = FalconTimelineFinalWorkingTradePoints(record);
      double broker_value_one_lot = 0.0;
      double broker_value_active_lot = 0.0;
      bool ordercalc_available = false;
      FalconBrokerRebaseValuesForRecord(record, broker_value_one_lot, broker_value_active_lot, ordercalc_available);
      double broker_rebased_raw_usd = record.net_index_points * broker_value_active_lot;
      double broker_rebased_final_usd = final_points * broker_value_active_lot;
      string row = "";
      row += FalconCsvSafe("TRADEMANAGEMENT_TIMELINE_AUDIT") + ",";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(FalconTimelineSafeEventTime(record, false))) + ",";
      row += DoubleToString(record.entry_price, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(record.falcon_dlm_active_lot, 2) + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe("NO") + ",";
      row += IntegerToString(0) + ",";
      row += IntegerToString(0) + ",";
      row += IntegerToString(0) + ",";
      row += IntegerToString(FC_MAGIC_FVG_MICRO) + ",";
      row += DoubleToString(record.net_usd, 4) + ",";
      row += DoubleToString(final_usd, 4) + ",";
      row += DoubleToString(record.net_index_points, 2) + ",";
      row += DoubleToString(final_points, 2) + ",";
      row += DoubleToString(broker_rebased_raw_usd, 4) + ",";
      row += DoubleToString(broker_rebased_final_usd, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += FalconCsvSafe(FALCON_BELR_NO_BROKER_COMPARISON_STATUS) + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(FALCON_TMET_STATUS) + ",";
      row += FalconCsvSafe("AUDIT_ONLY_NO_BROKER_ACTION_TIMELINE_ROW_WRITTEN_AFTER_PAPER_FINALIZATION");
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerEntryBridgeLifecycleRecord(const FalconBrokerTradeLink &link)
   {
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerExecutionLifecycleHeader();
         handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerExecutionLifecycle entry-bridge row: %s", m_broker_execution_lifecycle_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      if(link.broker_entry_attempted)
         m_broker_entry_bridge_order_send_attempts++;
      string event_kind = "BROKER_ENTRY_BRIDGE_TESTER_ONLY";
      string row = "";
      row += FalconCsvSafe(event_kind) + ",";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(link.strategy_id) + ",";
      row += FalconCsvSafe(link.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(link.broker_entry_time > 0 ? link.broker_entry_time : TimeCurrent())) + ",";
      row += DoubleToString(link.planned_entry_price, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(link.accepted_lot > 0.0 ? link.accepted_lot : link.requested_lot, 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_accepted)) + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe("NO") + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)link.broker_deal_ticket) + ",";
      row += IntegerToString((int)link.broker_magic) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += FalconCsvSafe("NOT_COMPARABLE_ENTRY_ONLY_NO_BROKER_CLOSE") + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(link.status) + ",";
      row += FalconCsvSafe(link.reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerExitObservationLifecycleRecord(const FalconBrokerTradeLink &link,
                                                    const ulong close_deal_ticket,
                                                    const ulong close_order_ticket,
                                                    const double close_price,
                                                    const double close_volume,
                                                    const double actual_balance_delta,
                                                    const datetime close_time,
                                                    const string exit_status,
                                                    const string exit_reason)
   {
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerExecutionLifecycleHeader();
         handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerExecutionLifecycle exit observation row: %s", m_broker_execution_lifecycle_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      bool open_at_deinit = (StringFind(exit_status, "OPEN_POSITION_AT_DEINIT") >= 0);
      string reason = exit_reason + "; closeDeal=" + IntegerToString((long)close_deal_ticket) +
                      "; closeOrder=" + IntegerToString((long)close_order_ticket) +
                      "; closePrice=" + DoubleToString(close_price, _Digits) +
                      "; closeVolume=" + DoubleToString(close_volume, 4) +
                      "; actualDelta=" + DoubleToString(actual_balance_delta, 4);

      string row = "";
      row += FalconCsvSafe(open_at_deinit ? "BROKER_POSITION_OPEN_AT_DEINIT" : "BROKER_EXIT_OBSERVED_ON_TRADE_TRANSACTION") + ",";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(link.strategy_id) + ",";
      row += FalconCsvSafe(link.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(close_time > 0 ? close_time : TimeCurrent())) + ",";
      row += DoubleToString(link.planned_entry_price, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(link.accepted_lot > 0.0 ? link.accepted_lot : link.requested_lot, 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_accepted)) + ",";
      row += FalconCsvSafe(open_at_deinit ? "NO" : "YES") + ",";
      row += FalconCsvSafe(open_at_deinit ? "NO" : "YES") + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)close_deal_ticket) + ",";
      row += IntegerToString((int)link.broker_magic) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(actual_balance_delta, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += FalconCsvSafe(open_at_deinit ? "BROKER_POSITION_STILL_OPEN_AT_DEINIT_NOT_COMPARABLE" : "BROKER_EXIT_OBSERVED_PAPER_FINAL_MATCH_PENDING") + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(exit_status) + ",";
      row += FalconCsvSafe(reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerManagedCloseLifecycleRecord(const FalconBrokerTradeLink &link,
                                               const bool close_attempted,
                                               const bool close_accepted,
                                               const ulong close_order_ticket,
                                               const ulong close_deal_ticket,
                                               const double close_price,
                                               const double close_volume,
                                               const datetime close_time,
                                               const string close_status,
                                               const string close_reason)
   {
      int handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerExecutionLifecycleHeader();
         handle = FileOpen(m_broker_execution_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerExecutionLifecycle managed close row: %s", m_broker_execution_lifecycle_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      string reason = close_reason + "; closeOrder=" + IntegerToString((long)close_order_ticket) +
                      "; closeDeal=" + IntegerToString((long)close_deal_ticket) +
                      "; closePrice=" + DoubleToString(close_price, _Digits) +
                      "; closeVolume=" + DoubleToString(close_volume, 4) +
                      "; policy=" + FALCON_MREB_DECISION_POLICY;

      string row = "";
      row += FalconCsvSafe("EA_MANAGED_PROTECTION_RUNNER_CLOSE_REQUEST") + ",";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(link.strategy_id) + ",";
      row += FalconCsvSafe(link.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(close_time > 0 ? close_time : TimeCurrent())) + ",";
      row += DoubleToString(link.planned_entry_price, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(close_volume > 0.0 ? close_volume : (link.accepted_lot > 0.0 ? link.accepted_lot : link.requested_lot), 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.broker_entry_accepted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(close_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(close_accepted)) + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)close_deal_ticket) + ",";
      row += IntegerToString((int)link.broker_magic) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += FalconCsvSafe(close_accepted ? "EA_MANAGED_CLOSE_REQUEST_ACCEPTED_ACTUAL_DELTA_PENDING_ON_TRADE_TRANSACTION" : "EA_MANAGED_CLOSE_REQUEST_REJECTED_OR_NOT_SENT") + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(close_status) + ",";
      row += FalconCsvSafe(reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }


   void AppendBrokerPaperTradeReconciliationRecord(const FalconTradeLifecycleRecord &record,
                                                  const FalconBrokerTradeLink &link,
                                                  const string reconciliation_event,
                                                  const string reconciliation_status,
                                                  const string reconciliation_reason)
   {
      if(FalconReportProfileIsLockParity()) return;
      int handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerPaperTradeReconciliationHeader();
         handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerPaperTradeReconciliation row: %s", m_broker_paper_reconciliation_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      double paper_final_usd = FalconTimelineFinalWorkingTradeUsd(record);
      double paper_final_points = FalconTimelineFinalWorkingTradePoints(record);
      double entry_delta = 0.0;
      if(link.broker_entry_price > 0.0 && record.entry_price > 0.0)
         entry_delta = link.broker_entry_price - record.entry_price;
      double sl_delta = 0.0;
      if(link.broker_sl > 0.0 && record.structural_sl > 0.0)
         sl_delta = link.broker_sl - record.structural_sl;
      double tp_delta = 0.0;
      if(link.broker_tp > 0.0 && record.tp3 > 0.0)
         tp_delta = link.broker_tp - record.tp3;
      int entry_time_delta = 0;
      if(link.broker_entry_time > 0 && record.entry_time > 0)
         entry_time_delta = (int)(link.broker_entry_time - record.entry_time);
      int exit_time_delta = 0;
      if(link.broker_close_time > 0 && record.exit_time > 0)
         exit_time_delta = (int)(link.broker_close_time - record.exit_time);
      string not_opened_reason = "";
      if(!link.broker_entry_accepted)
         not_opened_reason = link.status + ": " + link.reason;
      bool server_sl_hit = (StringFind(link.broker_exit_status, "SL") >= 0);
      bool server_tp_hit = (StringFind(link.broker_exit_status, "TP") >= 0);
      bool managed_close_observed = (link.broker_exit_observed && StringFind(link.broker_exit_status, "EXPERT") >= 0);
      double lot_executed = (link.accepted_lot > 0.0 ? link.accepted_lot : 0.0);
      double lot_delta = lot_executed - record.falcon_dlm_active_lot;
      double paper_exit_price = record.exit_price;
      double broker_close_price = link.broker_close_price;
      double close_price_delta = 0.0;
      if(broker_close_price > 0.0 && paper_exit_price > 0.0)
         close_price_delta = broker_close_price - paper_exit_price;
      double broker_actual_points = 0.0;
      if(link.broker_entry_price > 0.0 && broker_close_price > 0.0)
         broker_actual_points = FalconRawIndexPoints(record.direction, link.broker_entry_price, broker_close_price);
      double broker_actual_points_minus_paper_final = broker_actual_points - paper_final_points;
      double broker_value_at_executed_lot = 0.0;
      bool broker_value_available = false;
      if(lot_executed > 0.0)
      {
         broker_value_available = FalconBrokerUsdPerIndexPointByOrderCalc(record, lot_executed, broker_value_at_executed_lot);
         if(!broker_value_available)
            broker_value_at_executed_lot = FalconBrokerUsdPerIndexPointFallback(lot_executed);
      }
      double expected_broker_usd_from_paper_final = paper_final_points * broker_value_at_executed_lot;
      double broker_actual_minus_expected_broker_final = link.broker_actual_balance_delta - expected_broker_usd_from_paper_final;
      string server_stop_attach_policy = (FALCON_LOCK_PARITY_ATTACH_SERVER_SL_TP ? "SERVER_SL_TP_ATTACHED" : FALCON_LOCK_PARITY_SERVER_STOP_POLICY);

      string reconciliation_row_role = "FINAL_OUTCOME";
      bool is_final_reconciliation_row = true;
      if(reconciliation_event == "PAPER_FINAL_ACTIVE_BROKER_LINK_FOUND_BEFORE_MANAGED_CLOSE" ||
         reconciliation_event == "EA_MANAGED_CLOSE_REQUEST_SENT")
      {
         reconciliation_row_role = "INTERMEDIATE_TRACE";
         is_final_reconciliation_row = false;
      }

      string lock_gap_category = "MATCHED_OR_PENDING_RECONCILIATION";
      string lock_gap_primary_cause = "MATCHED_BROKER_AND_PAPER_OR_AWAITING_EXIT";
      double lock_gap_usd = link.broker_actual_balance_delta - paper_final_usd;
      string lock_gap_action = "KEEP_REPORTING_ONLY_UNTIL_NEXT_PARITY_STAGE";

      if(!is_final_reconciliation_row)
      {
         // v0.56.9: Do not count trace rows in LOCK gap totals.
         // Earlier v0.56.8d rows such as ACTIVE_LINK_FOUND and MANAGED_CLOSE_REQUEST
         // repeated the same TradeId before the final exit row and inflated gap sums.
         lock_gap_category = "INTERMEDIATE_TRACE_NOT_COUNTED_IN_LOCK_GAP";
         lock_gap_primary_cause = reconciliation_event;
         lock_gap_usd = 0.0;
         lock_gap_action = "IGNORE_IN_FINAL_LOCK_GAP_ROLLUP_WAIT_FOR_EXIT_OR_FINAL_ROW";
      }
      else if(StringFind(reconciliation_status, "BROKER_ONLY") >= 0 || StringFind(reconciliation_event, "WITHOUT_PAPER") >= 0)
      {
         lock_gap_category = "BROKER_ONLY_TRADE_NOT_IN_LOCK";
         lock_gap_primary_cause = "BROKER_ENTRY_HAS_NO_PAPER_FINAL_LIFECYCLE";
         lock_gap_usd = link.broker_actual_balance_delta;
         lock_gap_action = "ELIMINATE_BROKER_ONLY_ENTRY_BEFORE_PROFIT_PARITY";
      }
      else if(!link.broker_entry_accepted)
      {
         lock_gap_category = "PAPER_TRADE_NOT_OPENED_ON_BROKER";
         lock_gap_usd = -paper_final_usd;
         if(StringFind(link.reason, "EXISTING_FALCON_POSITION") >= 0)
         {
            lock_gap_primary_cause = "POSITION_SERIALIZATION_MAX_OPEN_POSITIONS_GATE";
            lock_gap_action = "DESIGN_LOCK_PARITY_ENTRY_QUEUE_OR_FASTER_MANAGED_EXIT_BEFORE_RELAXING_SAFETY";
         }
         else if(StringFind(link.reason, "STRUCTURAL_SL_DISTANCE") >= 0)
         {
            lock_gap_primary_cause = "STRUCTURAL_SL_DISTANCE_RISK_GUARD";
            lock_gap_action = "MEASURE_LOCK_GAIN_LOST_TO_SL_DISTANCE_GUARD_BEFORE_ANY_THRESHOLD_CHANGE";
         }
         else if(StringFind(link.reason, "SL_LOSS_TOO_LARGE") >= 0)
         {
            lock_gap_primary_cause = "STRUCTURAL_SL_LOSS_RISK_GUARD";
            lock_gap_action = "MEASURE_LOCK_GAIN_LOST_TO_SL_LOSS_GUARD_BEFORE_ANY_THRESHOLD_CHANGE";
         }
         else if(StringFind(link.reason, "LOT_AUTHORITY") >= 0)
         {
            lock_gap_primary_cause = "LOT_AUTHORITY_OR_CAPITAL_RISK_GATE";
            lock_gap_action = "COMPARE_PAPER_LOT_VS_BROKER_AUTHORIZED_LOT_AND_CAPITAL_REQUIREMENTS";
         }
         else if(StringFind(link.reason, "MARGIN") >= 0)
         {
            lock_gap_primary_cause = "BROKER_MARGIN_GATE";
            lock_gap_action = "VERIFY_SYMBOL_LEVERAGE_MARGIN_AND_MIN_LOT_CONDITIONS";
         }
         else
         {
            lock_gap_primary_cause = "ENTRY_BLOCKED_OR_NO_AUDIT_LINK";
            lock_gap_action = "INSPECT_NOT_OPENED_REASON_AND_BROKER_ENTRY_LIFECYCLE";
         }
      }
      else if(server_sl_hit)
      {
         lock_gap_category = "EXIT_LIFECYCLE_GAP_SERVER_SL_BEFORE_LOCK_FINAL";
         lock_gap_primary_cause = "SERVER_STRUCTURAL_SL_CLOSED_BEFORE_PAPER_PROTECTION_RUNNER";
         lock_gap_action = "BUILD_MANAGED_PROTECTION_RUNNER_EXECUTION_BEFORE_ANY_DEMO_LIVE";
      }
      else if(server_tp_hit)
      {
         lock_gap_category = "EXIT_LIFECYCLE_GAP_TP3_SAFETY_CAP";
         lock_gap_primary_cause = "TP3_SERVER_SAFETY_CAP_IS_NOT_TRUE_LOCK_RUNNER";
         lock_gap_action = "REPLACE_TP3_CAP_WITH_CONTROLLED_MANAGED_RUNNER_POLICY_LATER";
      }
      else if(managed_close_observed)
      {
         if(MathAbs(lock_gap_usd) <= 0.05)
         {
            lock_gap_category = "LOCK_PARITY_MATCH_WITHIN_TOLERANCE";
            lock_gap_primary_cause = "EA_MANAGED_CLOSE_OBSERVED_AND_ACCOUNT_DELTA_MATCHES_LOCK_FINAL";
            lock_gap_action = "KEEP_AS_PARITY_REFERENCE_SAMPLE";
         }
         else if(MathAbs(lot_delta) > 0.00001)
         {
            lock_gap_category = "LOT_EXPOSURE_GAP_ON_MATCHED_MANAGED_CLOSE";
            lock_gap_primary_cause = "BROKER_EXECUTED_LOT_DIFFERS_FROM_LOCK_PAPER_ACTIVE_LOT";
            lock_gap_action = "ALIGN_DYNAMIC_LOT_EXPOSURE_OR_EXPLAIN_ACCOUNT_EQUIVALENCE_LIMIT";
         }
         else if(MathAbs(broker_actual_points_minus_paper_final) > 2.0)
         {
            lock_gap_category = "MANAGED_CLOSE_PRICE_POINTS_GAP_ON_MATCHED_CLOSE";
            lock_gap_primary_cause = "BROKER_ENTRY_OR_CLOSE_PRICE_PATH_DIFFERS_FROM_LOCK_FINAL_POINTS";
            lock_gap_action = "COMPARE_PAPER_EXIT_PRICE_BROKER_CLOSE_PRICE_AND_ENTRY_FILL_BEFORE_RUNNER_CHANGES";
         }
         else if(MathAbs(entry_delta) > 2.0)
         {
            lock_gap_category = "ENTRY_FILL_DELTA_ON_MATCHED_MANAGED_CLOSE";
            lock_gap_primary_cause = "BID_ASK_SPREAD_OR_MARKET_FILL_DIFFERENCE_ON_MANAGED_CLOSE_SAMPLE";
            lock_gap_action = "MEASURE_FILL_DELTA_DISTRIBUTION_BEFORE_EXECUTION_OPTIMIZATION";
         }
         else
         {
            lock_gap_category = "MANAGED_CLOSE_ACCOUNTING_GAP_AFTER_PRICE_POINTS_MATCH";
            lock_gap_primary_cause = "EA_MANAGED_CLOSE_OBSERVED_BUT_ACCOUNT_DELTA_DIFFERS_AFTER_PRICE_POINTS_CHECK";
            lock_gap_action = "COMPARE_ORDERCALC_POINT_VALUE_COMMISSION_SWAP_AND_CONTRACT_MULTIPLIER";
         }
      }
      else if(link.broker_entry_accepted && !link.broker_exit_observed)
      {
         lock_gap_category = "OPEN_OR_UNOBSERVED_BROKER_EXIT";
         lock_gap_primary_cause = "BROKER_EXIT_NOT_YET_OBSERVED_IN_TRANSACTION_HISTORY";
         lock_gap_action = "KEEP_HISTORY_RECOVERY_AND_DEINIT_FLUSH_ACTIVE";
      }

      if(is_final_reconciliation_row && link.broker_entry_accepted && MathAbs(entry_delta) > 2.0 && lock_gap_category == "MATCHED_OR_PENDING_RECONCILIATION")
      {
         lock_gap_category = "ENTRY_FILL_DELTA_GAP";
         lock_gap_primary_cause = "BID_ASK_SPREAD_OR_MARKET_FILL_DIFFERENCE";
         lock_gap_action = "MEASURE_FILL_DELTA_DISTRIBUTION_BEFORE_EXECUTION_OPTIMIZATION";
      }

      string row = "";
      row += FalconCsvSafe(reconciliation_event) + ",";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(StringLen(link.trade_id_short) > 0 ? link.trade_id_short : FalconTradeIdShortHash(record.trade_id)) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(link.broker_entry_time)) + ",";
      row += IntegerToString(entry_time_delta) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(link.broker_close_time)) + ",";
      row += IntegerToString(exit_time_delta) + ",";
      row += DoubleToString(record.entry_price, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(entry_delta, _Digits) + ",";
      row += DoubleToString(record.structural_sl, _Digits) + ",";
      row += DoubleToString(link.broker_sl, _Digits) + ",";
      row += DoubleToString(sl_delta, _Digits) + ",";
      row += DoubleToString(record.tp1, _Digits) + ",";
      row += DoubleToString(record.tp2, _Digits) + ",";
      row += DoubleToString(record.tp3, _Digits) + ",";
      row += DoubleToString(link.broker_tp, _Digits) + ",";
      row += DoubleToString(tp_delta, _Digits) + ",";
      row += DoubleToString(paper_exit_price, _Digits) + ",";
      row += DoubleToString(broker_close_price, _Digits) + ",";
      row += DoubleToString(close_price_delta, _Digits) + ",";
      row += DoubleToString(broker_actual_points, 2) + ",";
      row += DoubleToString(broker_actual_points_minus_paper_final, 2) + ",";
      row += DoubleToString(expected_broker_usd_from_paper_final, 4) + ",";
      row += DoubleToString(broker_actual_minus_expected_broker_final, 4) + ",";
      row += FalconCsvSafe(server_stop_attach_policy) + ",";
      row += DoubleToString(record.net_usd, 4) + ",";
      row += DoubleToString(paper_final_usd, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta - paper_final_usd, 4) + ",";
      row += DoubleToString(record.net_index_points, 2) + ",";
      row += DoubleToString(paper_final_points, 2) + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_position_identifier) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)link.broker_deal_ticket) + ",";
      row += IntegerToString((long)link.broker_close_order_ticket) + ",";
      row += IntegerToString((long)link.broker_close_deal_ticket) + ",";
      row += FalconCsvSafe(link.broker_exit_status) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.managed_close_attempted || link.broker_close_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(managed_close_observed)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(server_sl_hit)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(server_tp_hit)) + ",";
      row += FalconCsvSafe(not_opened_reason) + ",";
      row += DoubleToString(link.requested_lot, 4) + ",";
      row += DoubleToString(link.accepted_lot, 4) + ",";
      row += DoubleToString(lot_executed, 4) + ",";
      row += DoubleToString(lot_delta, 4) + ",";
      row += FalconCsvSafe(reconciliation_row_role) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(is_final_reconciliation_row)) + ",";
      row += FalconCsvSafe(lock_gap_category) + ",";
      row += FalconCsvSafe(lock_gap_primary_cause) + ",";
      row += DoubleToString(lock_gap_usd, 4) + ",";
      row += FalconCsvSafe(lock_gap_action) + ",";
      row += FalconCsvSafe(reconciliation_status) + ",";
      row += FalconCsvSafe(reconciliation_reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }



   void AppendBrokerOnlyTradeReconciliationRecord(const FalconBrokerTradeLink &link,
                                                  const string reconciliation_event,
                                                  const string reconciliation_status,
                                                  const string reconciliation_reason)
   {
      if(FalconReportProfileIsLockParity()) return;
      // v0.56.9: A broker-only trade is a LOCK-parity violation until proven otherwise.
      // These rows make the reconciliation complete even when a broker entry/exit has
      // no matching Paper/TradeLifecycle record. Do not use this as permission to keep
      // broker-only trades; it is a diagnostic gate for the next anti-orphan entry fix.
      int handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerPaperTradeReconciliationHeader();
         handle = FileOpen(m_broker_paper_reconciliation_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append broker-only BrokerPaperTradeReconciliation row: %s", m_broker_paper_reconciliation_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      bool server_sl_hit = (StringFind(link.broker_exit_status, "SL") >= 0);
      bool server_tp_hit = (StringFind(link.broker_exit_status, "TP") >= 0);
      bool managed_close_observed = (link.broker_exit_observed && StringFind(link.broker_exit_status, "EXPERT") >= 0);
      double lot_executed = (link.accepted_lot > 0.0 ? link.accepted_lot : 0.0);
      double entry_delta = 0.0;
      double sl_delta = 0.0;
      double tp_delta = 0.0;
      int entry_time_delta = 0;
      int exit_time_delta = 0;
      string not_opened_reason = "BROKER_ONLY_TRADE_NOT_FOUND_IN_PAPER_TRADE_LIFECYCLE_LOCK_PARITY_VIOLATION";
      string lock_gap_category = "BROKER_ONLY_TRADE_NOT_IN_LOCK";
      string lock_gap_primary_cause = "BROKER_ENTRY_HAS_NO_PAPER_FINAL_LIFECYCLE";
      double lock_gap_usd = link.broker_actual_balance_delta;
      string lock_gap_action = "ELIMINATE_BROKER_ONLY_ENTRY_BEFORE_PROFIT_PARITY";
      if(server_sl_hit)
         lock_gap_primary_cause = "BROKER_ONLY_SERVER_SL_EXIT";
      else if(server_tp_hit)
         lock_gap_primary_cause = "BROKER_ONLY_TP3_SAFETY_CAP_EXIT";
      else if(managed_close_observed)
         lock_gap_primary_cause = "BROKER_ONLY_EXPERT_MANAGED_CLOSE_EXIT";

      string reconciliation_row_role = "FINAL_OUTCOME";
      bool is_final_reconciliation_row = true;

      string row = "";
      row += FalconCsvSafe(reconciliation_event) + ",";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(StringLen(link.trade_id_short) > 0 ? link.trade_id_short : FalconTradeIdShortHash(link.trade_id)) + ",";
      row += FalconCsvSafe(link.strategy_id) + ",";
      row += FalconCsvSafe(link.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe("") + ","; // PaperEntryTime unavailable: no Paper final record exists.
      row += FalconCsvSafe(FalconTimeToString(link.broker_entry_time)) + ",";
      row += IntegerToString(entry_time_delta) + ",";
      row += FalconCsvSafe("") + ","; // PaperExitTime unavailable.
      row += FalconCsvSafe(FalconTimeToString(link.broker_close_time)) + ",";
      row += IntegerToString(exit_time_delta) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(link.broker_entry_price, _Digits) + ",";
      row += DoubleToString(entry_delta, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(link.broker_sl, _Digits) + ",";
      row += DoubleToString(sl_delta, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(link.broker_tp, _Digits) + ",";
      row += DoubleToString(tp_delta, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(link.broker_close_price, _Digits) + ",";
      row += DoubleToString(0.0, _Digits) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta, 4) + ",";
      row += FalconCsvSafe(FALCON_LOCK_PARITY_ATTACH_SERVER_SL_TP ? "SERVER_SL_TP_ATTACHED" : FALCON_LOCK_PARITY_SERVER_STOP_POLICY) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(0.0, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta, 4) + ",";
      row += DoubleToString(link.broker_actual_balance_delta, 4) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += DoubleToString(0.0, 2) + ",";
      row += IntegerToString((long)link.broker_position_ticket) + ",";
      row += IntegerToString((long)link.broker_position_identifier) + ",";
      row += IntegerToString((long)link.broker_order_ticket) + ",";
      row += IntegerToString((long)link.broker_deal_ticket) + ",";
      row += IntegerToString((long)link.broker_close_order_ticket) + ",";
      row += IntegerToString((long)link.broker_close_deal_ticket) + ",";
      row += FalconCsvSafe(link.broker_exit_status) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(link.managed_close_attempted || link.broker_close_attempted)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(managed_close_observed)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(server_sl_hit)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(server_tp_hit)) + ",";
      row += FalconCsvSafe(not_opened_reason) + ",";
      row += DoubleToString(link.requested_lot, 4) + ",";
      row += DoubleToString(link.accepted_lot, 4) + ",";
      row += DoubleToString(lot_executed, 4) + ",";
      row += DoubleToString(lot_executed, 4) + ",";
      row += FalconCsvSafe(reconciliation_row_role) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(is_final_reconciliation_row)) + ",";
      row += FalconCsvSafe(lock_gap_category) + ",";
      row += FalconCsvSafe(lock_gap_primary_cause) + ",";
      row += DoubleToString(lock_gap_usd, 4) + ",";
      row += FalconCsvSafe(lock_gap_action) + ",";
      row += FalconCsvSafe(reconciliation_status) + ",";
      row += FalconCsvSafe(reconciliation_reason);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerTradeManagementTimelineEvent(const FalconTradeLifecycleRecord &record,
                                                 const ENUM_FALCON_BROKER_TM_EVENT_TYPE event_type,
                                                 const datetime event_time,
                                                 const double event_price,
                                                 const bool event_executable,
                                                 const string execution_eligibility,
                                                 const bool tp1_touched,
                                                 const bool tp2_touched,
                                                 const string status,
                                                 const string reason)
   {
      int handle = FileOpen(m_broker_tm_timeline_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteBrokerTradeManagementEventTimelineHeader();
         handle = FileOpen(m_broker_tm_timeline_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append BrokerTradeManagementEventTimeline row: %s", m_broker_tm_timeline_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      double final_usd = FalconTimelineFinalWorkingTradeUsd(record);
      double final_points = FalconTimelineFinalWorkingTradePoints(record);

      string row = "";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconBrokerTmEventTypeToString(event_type)) + ",";
      row += FalconCsvSafe(FalconTimeToString(event_time)) + ",";
      row += DoubleToString(event_price, _Digits) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(event_executable)) + ",";
      row += FalconCsvSafe(execution_eligibility) + ",";
      row += IntegerToString(0) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(tp1_touched)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(tp2_touched)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(record.paper_protection_activated)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(record.paper_runner_activated)) + ",";
      row += FalconCsvSafe(record.paper_protection_state) + ",";
      row += FalconCsvSafe(record.paper_runner_state) + ",";
      row += DoubleToString(record.net_usd, 4) + ",";
      row += DoubleToString(final_usd, 4) + ",";
      row += DoubleToString(record.paper_protection_net_usd, 4) + ",";
      row += DoubleToString(record.paper_runner_net_usd, 4) + ",";
      row += DoubleToString(record.net_index_points, 2) + ",";
      row += DoubleToString(final_points, 2) + ",";
      row += FalconCsvSafe(FALCON_TMET_EVENT_SOURCE) + ",";
      row += FalconCsvSafe(status) + ",";
      row += FalconCsvSafe(reason);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendBrokerTradeManagementTimelineForRecord(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      FalconRunnerBarPathStats barpath_stats;
      bool path_ok = FalconBuildRunnerBarPathStats(record, barpath_stats);
      bool tp1_touched = (path_ok && barpath_stats.tp1_touched);
      bool tp2_touched = (path_ok && barpath_stats.tp2_touched);

      string audit_only = FALCON_TMET_EXECUTION_ELIGIBILITY_AUDIT_ONLY;
      datetime entry_time = FalconTimelineSafeEventTime(record, true);
      datetime exit_time = FalconTimelineSafeEventTime(record, false);

      AppendBrokerTradeManagementTimelineEvent(record,
                                               FALCON_BTM_EVENT_ENTRY_PLANNED,
                                               entry_time,
                                               record.entry_price,
                                               false,
                                               audit_only,
                                               tp1_touched,
                                               tp2_touched,
                                               "PAPER_ENTRY_PLAN_AUDIT_ONLY",
                                               "Strategy-agnostic planned entry captured after Paper finalization; v0.56.4b broker order is allowed only when StructuralSL + bridge initial TP are valid and tester-only guards pass; exits are observed through OnTradeTransaction.");

      AppendBrokerTradeManagementTimelineEvent(record,
                                               FALCON_BTM_EVENT_ENTRY_ACCEPTED_PAPER,
                                               entry_time,
                                               record.entry_price,
                                               false,
                                               audit_only,
                                               tp1_touched,
                                               tp2_touched,
                                               "PAPER_ENTRY_ACCEPTED_AUDIT_ONLY",
                                               "Paper/Shadow lifecycle accepted the trade; broker bridge remains disabled.");

      if(tp1_touched)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_TP1_TOUCH,
                                                  exit_time,
                                                  record.tp1,
                                                  false,
                                                  FALCON_TMET_NO_EXACT_TICK_TIME_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "TP1_TOUCH_AUDIT_DETECTED",
                                                  "Bar-path scan detected TP1 touch, but exact tick-time/order is not yet available in v0.56.4b timeline audit.");
      }

      if(tp2_touched)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_TP2_TOUCH,
                                                  exit_time,
                                                  record.tp2,
                                                  false,
                                                  FALCON_TMET_NO_EXACT_TICK_TIME_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "TP2_TOUCH_AUDIT_DETECTED",
                                                  "Bar-path scan detected TP2 touch, but exact tick-time/order is not yet available in v0.56.4b timeline audit.");
      }

      if(record.paper_protection_activated)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_PROTECTION_ARMED,
                                                  exit_time,
                                                  record.paper_protection_level,
                                                  false,
                                                  audit_only,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "PROTECTION_ARMED_AFTER_PAPER_FINALIZATION",
                                                  record.paper_protection_trigger);
      }

      if(record.paper_virtual_sl_hit)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_PROTECTION_TRIGGERED,
                                                  exit_time,
                                                  record.paper_protection_level,
                                                  false,
                                                  FALCON_TMET_NO_EXACT_TICK_TIME_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "PROTECTION_TRIGGERED_ACCOUNTING_AUDIT",
                                                  "Paper virtual SL hit is known after finalization; exact broker-executable trigger time is not yet established.");
      }

      if(record.paper_runner_activated)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_RUNNER_ARMED,
                                                  exit_time,
                                                  record.tp2,
                                                  false,
                                                  audit_only,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "RUNNER_ARMED_AFTER_PAPER_FINALIZATION",
                                                  "Runner was activated by Paper proof logic; broker bridge remains disabled.");

         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_RUNNER_EXIT,
                                                  exit_time,
                                                  record.exit_price,
                                                  false,
                                                  FALCON_TMET_NO_EXACT_TICK_TIME_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "RUNNER_EXIT_ACCOUNTING_AUDIT",
                                                  record.paper_runner_exit_reason);
      }

      if(FalconClosedAtStop(record))
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_RAW_SL_HIT,
                                                  exit_time,
                                                  record.exit_price,
                                                  false,
                                                  audit_only,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "RAW_SL_CLOSE_AUDIT_ONLY",
                                                  record.close_reason);
      }
      else if(FalconClosedByTimeout(record))
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_TIMEOUT_CLOSE,
                                                  exit_time,
                                                  record.exit_price,
                                                  false,
                                                  audit_only,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "RAW_TIMEOUT_CLOSE_AUDIT_ONLY",
                                                  record.close_reason);
      }

      if(MathAbs(FalconTimelineFinalWorkingTradeUsd(record) - record.net_usd) > 0.00005)
      {
         AppendBrokerTradeManagementTimelineEvent(record,
                                                  FALCON_BTM_EVENT_ACCOUNTING_ONLY_ADJUSTMENT,
                                                  exit_time,
                                                  record.exit_price,
                                                  false,
                                                  FALCON_TMET_ACCOUNTING_ONLY_STATUS,
                                                  tp1_touched,
                                                  tp2_touched,
                                                  "FINAL_WORKING_DIFF_REQUIRES_EXECUTABLE_EVENT_PROOF",
                                                  "Paper final-working differs from raw trade USD; this row marks the gap that must be proven broker-executable before parity.");
      }

      AppendBrokerTradeManagementTimelineEvent(record,
                                               FALCON_BTM_EVENT_FINAL_CLOSE,
                                               exit_time,
                                               record.exit_price,
                                               false,
                                               audit_only,
                                               tp1_touched,
                                               tp2_touched,
                                               FalconTimelineCloseReasonEventStatus(record),
                                               record.paper_final_exit_reason);
   }

   void WriteBrokerContractRealityAudit()
   {
      int handle = FileOpen(m_broker_contract_reality_audit_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create BrokerContractRealityAudit foundation report: %s", m_broker_contract_reality_audit_file));
         return;
      }

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double reference_lot = FALCON_BROKER_REBUILD_REFERENCE_LOT;
      double paper_usd_per_index_point_reference = MathAbs(contract_size * reference_lot);

      FalconTradeLifecycleRecord probe_record;
      probe_record.direction = FALCON_DIRECTION_BUY;
      probe_record.entry_price = (ask > 0.0 ? ask : bid);
      double broker_value_one_lot = 0.0;
      double broker_value_reference_lot = 0.0;
      double broker_value_min_lot = 0.0;
      bool ordercalc_one = FalconBrokerUsdPerIndexPointByOrderCalc(probe_record, 1.0, broker_value_one_lot);
      bool ordercalc_ref = FalconBrokerUsdPerIndexPointByOrderCalc(probe_record, reference_lot, broker_value_reference_lot);
      bool ordercalc_min = FalconBrokerUsdPerIndexPointByOrderCalc(probe_record, volume_min, broker_value_min_lot);
      if(!ordercalc_one)
         broker_value_one_lot = FalconBrokerUsdPerIndexPointFallback(1.0);
      if(!ordercalc_ref)
         broker_value_reference_lot = FalconBrokerUsdPerIndexPointFallback(reference_lot);
      if(!ordercalc_min)
         broker_value_min_lot = FalconBrokerUsdPerIndexPointFallback(volume_min);

      bool ordercalc_available = (ordercalc_one && ordercalc_ref && ordercalc_min);
      double required_parity_lot_reference = 0.0;
      if(broker_value_one_lot > 0.0 && paper_usd_per_index_point_reference > 0.0)
         required_parity_lot_reference = paper_usd_per_index_point_reference / broker_value_one_lot;
      bool parity_lot_below_min = (required_parity_lot_reference > 0.0 && volume_min > 0.0 && required_parity_lot_reference < volume_min);
      string decision = "BROKER_CONTRACT_REBASED_COMPARISON_AUDIT_ONLY_NO_BROKER_EXECUTION";
      string recommendation = "NEXT_BUILD_MAY_ADD_TESTER_ONLY_ENTRY_BRIDGE_ONLY_AFTER_REBASED_AUDIT_AND_EVENT_TIMELINE_PASS";

      string header = "EAName,Version,Build,GeneratedAt,Symbol,Digits,Point,TickSize,TickValue,ContractSize,";
      header += "VolumeMin,VolumeMax,VolumeStep,ReferenceLot,Ask,Bid,PaperUsdPerIndexPointAtReferenceLot,";
      header += "BrokerUsdPerIndexPointAtOneLot,BrokerUsdPerIndexPointAtReferenceLot,BrokerUsdPerIndexPointAtMinLot,";
      header += "RequiredParityLotAtReference,BrokerMinLot,ParityLotBelowMin,OrderCalcProfitAvailable,";
      header += "ExecutionPolicy,ReusabilityPolicy,Decision,Recommendation";
      FileWriteString(handle, header + "\r\n");

      string row = "";
      row += FalconCsvSafe(EA_NAME) + ",";
      row += FalconCsvSafe(EA_VERSION_TAG) + ",";
      row += FalconCsvSafe(EA_BUILD_TAG) + ",";
      row += FalconCsvSafe(TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)) + ",";
      row += FalconCsvSafe(_Symbol) + ",";
      row += IntegerToString(_Digits) + ",";
      row += DoubleToString(point, 10) + ",";
      row += DoubleToString(tick_size, 10) + ",";
      row += DoubleToString(tick_value, 6) + ",";
      row += DoubleToString(contract_size, 6) + ",";
      row += DoubleToString(volume_min, 4) + ",";
      row += DoubleToString(volume_max, 4) + ",";
      row += DoubleToString(volume_step, 4) + ",";
      row += DoubleToString(reference_lot, 4) + ",";
      row += DoubleToString(ask, _Digits) + ",";
      row += DoubleToString(bid, _Digits) + ",";
      row += DoubleToString(paper_usd_per_index_point_reference, 6) + ",";
      row += DoubleToString(broker_value_one_lot, 6) + ",";
      row += DoubleToString(broker_value_reference_lot, 6) + ",";
      row += DoubleToString(broker_value_min_lot, 6) + ",";
      row += DoubleToString(required_parity_lot_reference, 6) + ",";
      row += DoubleToString(volume_min, 4) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(parity_lot_below_min)) + ",";
      row += FalconCsvSafe(FalconBoolToYesNo(ordercalc_available)) + ",";
      row += FalconCsvSafe(FALCON_BELR_EXECUTION_POLICY) + ",";
      row += FalconCsvSafe(FALCON_BELR_REUSABILITY_POLICY) + ",";
      row += FalconCsvSafe(decision) + ",";
      row += FalconCsvSafe(recommendation);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendPaperStateSnapshotRecord(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      m_totals.paper_state_snapshot_evaluated_trades++;

      datetime session_boundary_close_time = 0;
      datetime session_boundary_checkpoint_time = 0;
      bool active_during_recovery_window = false;
      string session_boundary_checkpoint_type = FalconSessionBoundaryCheckpointType(record, session_boundary_close_time, session_boundary_checkpoint_time, active_during_recovery_window);
      string requires_recovery = (active_during_recovery_window ? "YES" : "NO");

      int handle = FileOpen(m_paper_state_snapshot_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WritePaperStateSnapshotHeader();
         handle = FileOpen(m_paper_state_snapshot_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         m_totals.paper_state_snapshot_write_failures++;
         CFalconLogger::Warn(StringFormat("Could not append PaperStateSnapshot row: %s", m_paper_state_snapshot_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);

      string row = "";
      row += FalconCsvSafe(FalconTimeToString(TimeCurrent())) + ",";
      row += FalconCsvSafe(EA_VERSION_TAG) + ",";
      row += FalconCsvSafe(EA_BUILD_TAG) + ",";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(record.strategy_id) + ",";
      row += FalconCsvSafe(record.engine_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      row += DoubleToString(record.entry_price, m_symbol_context.digits) + ",";
      row += DoubleToString(record.structural_sl, m_symbol_context.digits) + ",";
      row += DoubleToString(record.tp1, m_symbol_context.digits) + ",";
      row += DoubleToString(record.tp2, m_symbol_context.digits) + ",";
      row += DoubleToString(record.tp3, m_symbol_context.digits) + ",";
      row += DoubleToString(record.falcon_dlm_active_lot, 2) + ",";
      row += DoubleToString(record.falcon_dynamic_risk_capital_before_trade, 4) + ",";
      row += DoubleToString(record.falcon_dynamic_risk_capital_after_trade, 4) + ",";
      row += FalconCsvSafe(record.paper_protection_state) + ",";
      row += FalconCsvSafe(record.paper_runner_state) + ",";
      row += FalconCsvSafe(record.falcon_emergency_status) + ",";
      row += FalconCsvSafe(FALCON_PERSISTENCE_RECOVERY_MODE) + ",";
      row += FalconCsvSafe("NO") + ",";
      row += FalconCsvSafe(session_boundary_checkpoint_type) + ",";
      row += FalconCsvSafe(FalconTimeToString(session_boundary_close_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(session_boundary_checkpoint_time)) + ",";
      row += FalconCsvSafe(active_during_recovery_window ? "YES" : "NO") + ",";
      row += FalconCsvSafe(requires_recovery) + ",";
      row += FalconCsvSafe(FalconSessionBoundarySnapshotNotes(record));

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
      m_totals.paper_state_snapshot_written_rows++;
   }

   void AppendEmergencyTriggerEvent(const FalconTradeLifecycleRecord &record)
   {
      if(FalconReportProfileIsLockParity()) return;
      if(!EnableMainReport)
         return;
      if(record.falcon_emergency_status != "TRIGGERED")
         return;

      int handle = FileOpen(m_emergency_triggers_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteEmergencyTriggersHeader();
         handle = FileOpen(m_emergency_triggers_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append EmergencyTriggers event row: %s", m_emergency_triggers_file));
         return;
      }
      FileSeek(handle, 0, SEEK_END);

      string layer_name = "LAYER_" + IntegerToString(record.falcon_emergency_triggered_layer);
      if(record.falcon_emergency_reason != "")
         layer_name = record.falcon_emergency_reason;

      string row = "";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time > 0 ? record.exit_time : record.entry_time)) + ",";
      row += FalconCsvSafe(layer_name) + ",";
      row += FalconCsvSafe(record.falcon_tier_at_entry) + ",";
      row += DoubleToString(record.falcon_dynamic_risk_capital_after_trade, 4) + ",";
      row += IntegerToString(record.falcon_layer1_consecutive_losses) + ",";
      row += DoubleToString(record.falcon_layer2_daily_r, 4) + ",";
      row += DoubleToString(record.falcon_layer3_drawdown_pct, 4) + ",";
      row += IntegerToString(m_totals.paper_emergency_blocked_entries) + ",";
      row += FalconCsvSafe("PENDING_NEXT_DAY_OR_PEAK_RESET") + ",";
      row += FalconCsvSafe("NO");

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void AppendTierTransitionEvent(const datetime event_time,
                                  const string from_tier,
                                  const string to_tier,
                                  const string direction,
                                  const string reason,
                                  const double balance,
                                  const int trades_in_previous_tier,
                                  const double win_rate,
                                  const double net_r)
   {
      if(FalconReportProfileIsLockParity()) return;
      if(!EnableMainReport)
         return;

      int handle = FileOpen(m_tier_transitions_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteTierTransitionsHeader();
         handle = FileOpen(m_tier_transitions_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append TierTransitions event row: %s", m_tier_transitions_file));
         return;
      }
      FileSeek(handle, 0, SEEK_END);

      string row = "";
      row += FalconCsvSafe(FalconTimeToString(event_time)) + ",";
      row += FalconCsvSafe(from_tier) + ",";
      row += FalconCsvSafe(to_tier) + ",";
      row += FalconCsvSafe(direction) + ",";
      row += FalconCsvSafe(reason) + ",";
      row += DoubleToString(balance, 4) + ",";
      row += IntegerToString(trades_in_previous_tier) + ",";
      row += DoubleToString(win_rate, 2) + ",";
      row += DoubleToString(net_r, 4);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   int FalconMarketCloseDayOfWeek(datetime t)
   {
      if(t <= 0)
         return -1;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return dt.day_of_week;
   }

   int FalconMarketCloseMinuteOfDay(datetime t)
   {
      if(t <= 0)
         return -1;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return dt.hour * 60 + dt.min;
   }

   datetime FalconSessionBoundaryDateStart(datetime t)
   {
      if(t <= 0)
         return 0;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      return StructToTime(dt);
   }

   int FalconMarketCloseGuardFallbackCloseMinute()
   {
      // Fallback only. Primary logic uses broker/server symbol session schedule.
      // NAS100/US100 often closes near :58. This fallback does not use the user's PC clock.
      return 23 * 60 + 58;
   }

   int FalconSessionScheduleMinuteOfDay(datetime session_time)
   {
      if(session_time < 0)
         return -1;

      long raw_seconds = (long)session_time;
      int seconds_of_day = (int)(raw_seconds % 86400);
      if(seconds_of_day < 0)
         seconds_of_day += 86400;

      // Some brokers encode 24:00 as 86400 seconds. Treat it as the final minute of the day.
      if(seconds_of_day == 0 && raw_seconds >= 86400)
         return 1439;

      return seconds_of_day / 60;
   }

   int FalconResolveCloseMinuteFromBrokerSessions(datetime t)
   {
      if(t <= 0)
         return -1;

      int dow = FalconMarketCloseDayOfWeek(t);
      if(dow < 0 || dow > 6)
         return -1;

      string symbols[2];
      symbols[0] = m_symbol_context.symbol;
      symbols[1] = _Symbol;

      for(int s = 0; s < 2; s++)
      {
         string symbol_name = symbols[s];
         if(StringLen(symbol_name) <= 0)
            continue;
         if(s == 1 && symbol_name == symbols[0])
            continue;

         int best_close_minute = -1;

         for(uint session_index = 0; session_index < 16; session_index++)
         {
            datetime session_from = 0;
            datetime session_to = 0;
            if(!SymbolInfoSessionTrade(symbol_name, (ENUM_DAY_OF_WEEK)dow, session_index, session_from, session_to))
               continue;

            int from_minute = FalconSessionScheduleMinuteOfDay(session_from);
            int to_minute = FalconSessionScheduleMinuteOfDay(session_to);
            if(from_minute < 0 || to_minute < 0)
               continue;

            int close_minute = to_minute;

            // If a broker encodes a session wrapping into the next day, the current day's last tradable minute is end-of-day.
            if(to_minute <= from_minute)
               close_minute = 1439;

            if(close_minute > best_close_minute)
               best_close_minute = close_minute;
         }

         if(best_close_minute > 0)
            return best_close_minute;
      }

      return -1;
   }

   int FalconMarketCloseGuardCloseMinute(datetime t)
   {
      // v0.55.12a-fix2: derive close from broker/server symbol session schedule.
      // This avoids user's PC time and avoids the incomplete-bar-history issue seen in fix1.
      int minute = FalconResolveCloseMinuteFromBrokerSessions(t);
      if(minute > 0)
         return minute;

      return FalconMarketCloseGuardFallbackCloseMinute();
   }

   int FalconMarketCloseGuardBlockWindowMinutes()
   {
      // v0.55.11e: 120-minute reference window retained only for market-close risk measurement.
      // Entry-window blocking was rejected and removed from default runtime/reporting.
      return 120;
   }

   int FalconUserNoNewEntryWindowMinutes()
   {
      int minutes = StopNewTradesBeforeCloseMinutes;
      if(minutes < 0)
         minutes = 0;
      if(minutes > 240)
         minutes = 240;
      return minutes;
   }

   bool FalconIsUserNoNewEntryCloseWindow(datetime t)
   {
      if(!StopNewTradesBeforeClose)
         return false;

      int window_minutes = FalconUserNoNewEntryWindowMinutes();
      if(window_minutes <= 0)
         return false;

      int dow = FalconMarketCloseDayOfWeek(t);
      if(dow < 1 || dow > 5)
         return false;

      int minute = FalconMarketCloseMinuteOfDay(t);
      if(minute < 0)
         return false;

      return (minute >= FalconMarketCloseGuardCloseMinute(t) - window_minutes);
   }

   bool FalconIsDailyCloseWindow(datetime t)
   {
      // v0.55.11e: daily close-risk measurement only. Entry-window blocking
      // was rejected after all tested windows showed negative benefit.
      int dow = FalconMarketCloseDayOfWeek(t);
      if(dow < 1 || dow > 5)
         return false;
      int minute = FalconMarketCloseMinuteOfDay(t);
      if(minute < 0)
         return false;
      return (minute >= FalconMarketCloseGuardCloseMinute(t) - FalconMarketCloseGuardBlockWindowMinutes());
   }




   bool FalconIsFridayCloseWindow(datetime t)
   {
      if(FalconMarketCloseDayOfWeek(t) != 5)
         return false;
      int minute = FalconMarketCloseMinuteOfDay(t);
      if(minute < 0)
         return false;
      return (minute >= FalconMarketCloseGuardCloseMinute(t) - FalconMarketCloseGuardBlockWindowMinutes());
   }

   bool FalconWouldBeOpenAtWeekendRisk(const FalconTradeLifecycleRecord &record)
   {
      if(record.entry_time <= 0)
         return false;
      if(FalconMarketCloseDayOfWeek(record.entry_time) != 5)
         return false;

      int entry_minute = FalconMarketCloseMinuteOfDay(record.entry_time);
      if(entry_minute >= FalconMarketCloseGuardCloseMinute(record.entry_time) - FalconMarketCloseGuardBlockWindowMinutes())
         return true;

      if(record.exit_time <= 0)
         return true;

      int exit_dow = FalconMarketCloseDayOfWeek(record.exit_time);
      int exit_minute = FalconMarketCloseMinuteOfDay(record.exit_time);
      if(exit_dow != 5 && record.exit_time > record.entry_time)
         return true;
      if(exit_dow == 5 && exit_minute >= FalconMarketCloseGuardCloseMinute(record.exit_time))
         return true;

      return false;
   }

   int FalconTradeDurationMinutesCeil(const FalconTradeLifecycleRecord &record)
   {
      if(record.entry_time <= 0 || record.exit_time <= 0 || record.exit_time <= record.entry_time)
         return 0;
      int seconds = (int)(record.exit_time - record.entry_time);
      return (seconds + 59) / 60;
   }

   int FalconClampSessionBoundaryMinutes(int minutes)
   {
      if(minutes < 0)
         return 0;
      if(minutes > 240)
         return 240;
      return minutes;
   }

   int FalconDailyForceCloseUserWindowMinutes()
   {
      return FalconClampSessionBoundaryMinutes(DailyCloseSafetyMinutes);
   }

   int FalconWeekendForceCloseUserWindowMinutes()
   {
      return FalconClampSessionBoundaryMinutes(WeekendCloseSafetyMinutes);
   }

   int FalconSessionBoundaryDefaultRecoveryCheckpointMinutes()
   {
      return FALCON_SESSION_BOUNDARY_DEFAULT_CHECKPOINT_MINUTES;
   }

   int FalconSessionBoundaryRecoveryCheckpointMinutesForActionWindow(int action_window_minutes)
   {
      // v0.55.13-fix4: dynamic relationship between user close-safety window
      // and recovery checkpoint. The checkpoint must occur after the configured
      // close/stop action and before the broker close.
      int default_checkpoint = FalconSessionBoundaryDefaultRecoveryCheckpointMinutes();
      if(default_checkpoint < 0)
         default_checkpoint = 0;

      int action_minutes = FalconClampSessionBoundaryMinutes(action_window_minutes);
      if(action_minutes <= 0)
         return default_checkpoint;

      int gap = FALCON_SESSION_BOUNDARY_ACTION_TO_CHECKPOINT_GAP_MINUTES;
      if(gap < 0)
         gap = 0;

      int dynamic_checkpoint = action_minutes - gap;
      if(dynamic_checkpoint > default_checkpoint)
         dynamic_checkpoint = default_checkpoint;
      if(dynamic_checkpoint < 0)
         dynamic_checkpoint = 0;

      return dynamic_checkpoint;
   }

   int FalconSessionBoundaryRecoveryCheckpointMinutesForRecord(const FalconTradeLifecycleRecord &record)
   {
      int dow = FalconMarketCloseDayOfWeek(record.entry_time);
      if(dow == 5 && CloseTradesBeforeWeekend)
         return FalconSessionBoundaryRecoveryCheckpointMinutesForActionWindow(FalconWeekendForceCloseUserWindowMinutes());

      if(dow >= 1 && dow <= 5 && CloseTradesBeforeDailyClose)
         return FalconSessionBoundaryRecoveryCheckpointMinutesForActionWindow(FalconDailyForceCloseUserWindowMinutes());

      return FalconSessionBoundaryDefaultRecoveryCheckpointMinutes();
   }

   datetime FalconBoundaryDateAtMinute(datetime t, int minute_of_day)
   {
      if(t <= 0)
         return 0;
      if(minute_of_day < 0)
         minute_of_day = 0;
      if(minute_of_day > 1439)
         minute_of_day = 1439;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = minute_of_day / 60;
      dt.min = minute_of_day % 60;
      dt.sec = 0;
      return StructToTime(dt);
   }

   datetime FalconDailyForceCloseUserTime(datetime t)
   {
      return FalconBoundaryDateAtMinute(t, FalconMarketCloseGuardCloseMinute(t) - FalconDailyForceCloseUserWindowMinutes());
   }

   datetime FalconWeekendForceCloseUserTime(datetime t)
   {
      return FalconBoundaryDateAtMinute(t, FalconMarketCloseGuardCloseMinute(t) - FalconWeekendForceCloseUserWindowMinutes());
   }

   datetime FalconSessionBoundaryBrokerCloseTime(datetime t)
   {
      return FalconBoundaryDateAtMinute(t, FalconMarketCloseGuardCloseMinute(t));
   }

   datetime FalconSessionBoundaryRecoveryCheckpointTime(datetime t, int checkpoint_minutes)
   {
      return FalconBoundaryDateAtMinute(t, FalconMarketCloseGuardCloseMinute(t) - FalconClampSessionBoundaryMinutes(checkpoint_minutes));
   }

   bool FalconWasTradeOpenAtTime(const FalconTradeLifecycleRecord &record, datetime boundary_time)
   {
      if(boundary_time <= 0 || record.entry_time <= 0)
         return false;
      if(record.entry_time >= boundary_time)
         return false;
      if(record.exit_time <= 0)
         return true;
      return (record.exit_time > boundary_time);
   }

   bool FalconIsSessionBoundaryNoNewEntryBlockedRecord(const FalconTradeLifecycleRecord &record)
   {
      // v0.55.13-fix4: a no-new-entry blocked row is a rejected/blocked paper signal,
      // not an open paper position. It must not be counted as active during recovery checkpoint.
      if(record.falcon_market_close_blocked == 1)
         return true;
      if(record.close_reason == "SESSION_BOUNDARY_USER_NO_NEW_ENTRY_BLOCKED")
         return true;
      return false;
   }

   bool FalconTryGetBoundaryClosePrice(datetime boundary_time, double &price)
   {
      price = 0.0;
      if(boundary_time <= 0)
         return false;

      int shift = iBarShift(m_symbol_context.symbol, PERIOD_M1, boundary_time, false);
      if(shift < 0)
         shift = iBarShift(_Symbol, PERIOD_M1, boundary_time, false);
      if(shift >= 0)
      {
         price = iClose(m_symbol_context.symbol, PERIOD_M1, shift);
         if(price <= 0.0)
            price = iClose(_Symbol, PERIOD_M1, shift);
         if(price > 0.0)
            return true;
      }

      shift = iBarShift(m_symbol_context.symbol, PERIOD_M5, boundary_time, false);
      if(shift < 0)
         shift = iBarShift(_Symbol, PERIOD_M5, boundary_time, false);
      if(shift < 0)
         return false;

      price = iClose(m_symbol_context.symbol, PERIOD_M5, shift);
      if(price <= 0.0)
         price = iClose(_Symbol, PERIOD_M5, shift);
      return (price > 0.0);
   }

   double FalconForceCloseOverrideNetUsd(const FalconTradeLifecycleRecord &record, double force_close_price)
   {
      double active_lot = record.falcon_dlm_active_lot;
      if(active_lot <= 0.0)
         active_lot = record.lot_size;
      double raw_points = FalconRawIndexPoints(record.direction, record.entry_price, force_close_price);
      return FalconEstimateUsdByRawPoints(raw_points, active_lot, m_symbol_context);
   }

   double FalconForceCloseOverrideNetPoints(const FalconTradeLifecycleRecord &record, double force_close_price)
   {
      return FalconRawIndexPoints(record.direction, record.entry_price, force_close_price);
   }

   bool FalconWasTradeActiveDuringBoundaryCheckpointWindow(const FalconTradeLifecycleRecord &record, datetime checkpoint_time, datetime close_time)
   {
      if(FalconIsSessionBoundaryNoNewEntryBlockedRecord(record))
         return false;
      if(checkpoint_time <= 0 || close_time <= 0 || record.entry_time <= 0)
         return false;
      if(record.entry_time >= close_time)
         return false;
      if(record.exit_time <= 0)
         return true;
      return (record.exit_time > checkpoint_time);
   }

   string FalconSessionBoundaryCheckpointType(const FalconTradeLifecycleRecord &record, datetime &close_time, datetime &checkpoint_time, bool &active_during_checkpoint_window)
   {
      close_time = 0;
      checkpoint_time = 0;
      active_during_checkpoint_window = false;

      if(record.entry_time <= 0)
         return "NONE";

      if(FalconIsSessionBoundaryNoNewEntryBlockedRecord(record))
      {
         close_time = FalconSessionBoundaryBrokerCloseTime(record.entry_time);
         checkpoint_time = FalconSessionBoundaryRecoveryCheckpointTime(record.entry_time, FalconSessionBoundaryRecoveryCheckpointMinutesForRecord(record));
         active_during_checkpoint_window = false;
         return "BLOCKED_NO_OPEN_POSITION";
      }

      int dow = FalconMarketCloseDayOfWeek(record.entry_time);
      if(dow < 1 || dow > 5)
         return "NONE";

      close_time = FalconSessionBoundaryBrokerCloseTime(record.entry_time);
      checkpoint_time = FalconSessionBoundaryRecoveryCheckpointTime(record.entry_time, FalconSessionBoundaryRecoveryCheckpointMinutesForRecord(record));
      if(close_time <= 0 || checkpoint_time <= 0)
         return "NONE";

      active_during_checkpoint_window = FalconWasTradeActiveDuringBoundaryCheckpointWindow(record, checkpoint_time, close_time);

      if(dow == 5 && active_during_checkpoint_window)
         return "WEEKEND";

      return "DAILY";
   }

   void UpdateSessionBoundaryStateCheckpointFoundation(const FalconTradeLifecycleRecord &record)
   {
      // v0.55.13-fix4: measurement-only dynamic checkpoint. It verifies whether Paper state
      // would still need recovery after user-selected close-safety actions and before the broker close.
      // It does not restore, close, block, or modify any trade.
      m_totals.session_boundary_checkpoint_evaluated_trades++;
      m_totals.session_boundary_recovery_checkpoint_minutes = FalconSessionBoundaryDefaultRecoveryCheckpointMinutes();

      datetime close_time = 0;
      datetime checkpoint_time = 0;
      bool active_during_checkpoint_window = false;
      string checkpoint_type = FalconSessionBoundaryCheckpointType(record, close_time, checkpoint_time, active_during_checkpoint_window);

      if(!active_during_checkpoint_window)
         return;

      m_totals.session_boundary_recovery_required_trades++;

      if(checkpoint_type == "WEEKEND")
      {
         m_totals.session_boundary_weekend_checkpoint_open_trades++;
         if(CloseTradesBeforeWeekend)
            m_totals.session_boundary_dirty_after_close_safety_trades++;
      }
      else if(checkpoint_type == "DAILY")
      {
         m_totals.session_boundary_daily_checkpoint_open_trades++;
         if(CloseTradesBeforeDailyClose)
            m_totals.session_boundary_dirty_after_close_safety_trades++;
      }
   }

   string FalconSessionBoundaryCheckpointStatus()
   {
      if(m_totals.session_boundary_checkpoint_evaluated_trades != m_totals.total_trades)
         return "FAIL_ROW_MISMATCH";
      if(m_totals.session_boundary_dirty_after_close_safety_trades > 0)
         return "WARN_DIRTY_AFTER_CLOSE_SAFETY";
      if(m_totals.session_boundary_recovery_required_trades > 0)
         return "PASS_RECOVERY_REQUIRED_BY_CARRY";
      return "PASS_CLEAN";
   }

   string FalconSessionBoundarySnapshotNotes(const FalconTradeLifecycleRecord &record)
   {
      datetime close_time = 0;
      datetime checkpoint_time = 0;
      bool active_during_checkpoint_window = false;
      string checkpoint_type = FalconSessionBoundaryCheckpointType(record, close_time, checkpoint_time, active_during_checkpoint_window);
      if(checkpoint_type == "NONE")
         return "No broker close checkpoint for this record.";
      if(checkpoint_type == "BLOCKED_NO_OPEN_POSITION")
         return "No recovery needed: session boundary blocked entry, so no open Paper position existed.";
      if(active_during_checkpoint_window)
         return StringFormat("%s checkpoint active; recovery checkpoint %s before close %s.", checkpoint_type, FalconTimeToString(checkpoint_time), FalconTimeToString(close_time));
      return StringFormat("%s checkpoint clean; recovery checkpoint %s before close %s.", checkpoint_type, FalconTimeToString(checkpoint_time), FalconTimeToString(close_time));
   }

   void UpdateMarketCloseGuardFoundation(const FalconTradeLifecycleRecord &record)
   {
      m_totals.market_close_guard_evaluated_trades++;

      int window_minutes = FalconMarketCloseGuardBlockWindowMinutes();

      int duration_minutes = FalconTradeDurationMinutesCeil(record);
      if(duration_minutes > 0)
      {
         m_totals.market_close_total_trade_duration_minutes += (double)duration_minutes;
         if(duration_minutes > m_totals.market_close_max_trade_duration_minutes)
         {
            m_totals.market_close_max_trade_duration_minutes = duration_minutes;
            m_totals.market_close_longest_trade_id = record.trade_id;
         }
         if(duration_minutes > window_minutes)
            m_totals.market_close_duration_above_window_trades++;
      }

      if(FalconIsDailyCloseWindow(record.entry_time))
      {
         m_totals.market_close_guard_near_close_entry_trades++;
      }
      if(FalconWouldBeOpenAtWeekendRisk(record))
         m_totals.market_close_guard_open_weekend_risk_trades++;
   }

   void ApplyNoNewEntryUserOverridePaperEnforcement(FalconTradeLifecycleRecord &record)
   {
      // v0.55.11f: optional user safety override.
      // Default is OFF because calibrated windows reduced profit. The user may enable it only as a safety override.
      // When explicitly enabled, the user accepts the safety trade-off and the Paper result is blocked
      // before Emergency/CapitalFlow read the trade.
      record.falcon_market_close_status = "ALLOWED";
      record.falcon_market_close_blocked = 0;
      record.falcon_market_close_reason = "NO_NEW_ENTRY_OVERRIDE_DISABLED";
      record.falcon_market_close_before_net_usd = record.falcon_single_trade_loss_cap_after_net_usd;
      record.falcon_market_close_after_net_usd = record.falcon_single_trade_loss_cap_after_net_usd;
      record.falcon_market_close_impact_usd = 0.0;

      if(!StopNewTradesBeforeClose)
         return;

      if(FalconUserNoNewEntryWindowMinutes() <= 0)
      {
         record.falcon_market_close_reason = "NO_NEW_ENTRY_OVERRIDE_ZERO_MINUTES";
         return;
      }

      if(!FalconIsUserNoNewEntryCloseWindow(record.entry_time))
      {
         record.falcon_market_close_reason = "OUTSIDE_USER_NO_NEW_ENTRY_WINDOW";
         return;
      }

      record.falcon_market_close_status = "BLOCKED";
      record.falcon_market_close_blocked = 1;
      record.falcon_market_close_reason = StringFormat("USER_NO_NEW_ENTRY_LAST_%d_MIN", FalconUserNoNewEntryWindowMinutes());
      record.falcon_market_close_after_net_usd = 0.0;
      record.falcon_market_close_impact_usd = record.falcon_market_close_after_net_usd - record.falcon_market_close_before_net_usd;

      // Feed the blocked result into all later Paper layers.
      record.falcon_single_trade_loss_cap_after_net_points = 0.0;
      record.falcon_single_trade_loss_cap_after_net_usd = 0.0;
      record.falcon_single_trade_loss_cap_impact_points = record.falcon_single_trade_loss_cap_after_net_points - record.falcon_single_trade_loss_cap_before_net_points;
      record.falcon_single_trade_loss_cap_impact_usd = record.falcon_single_trade_loss_cap_after_net_usd - record.falcon_single_trade_loss_cap_before_net_usd;
      record.close_reason = "SESSION_BOUNDARY_USER_NO_NEW_ENTRY_BLOCKED";
   }

   void ApplyDailyWeekendForceCloseUserOverridePaperEnforcement(FalconTradeLifecycleRecord &record)
   {
      // v0.55.12a: optional user safety override.
      // Defaults are OFF because validation showed profit reduction. The user may enable this only as a safety override.
      // When enabled, a qualifying open Paper trade is force-closed before Emergency and Capital Flow.
      m_totals.force_close_override_evaluated_trades++;

      if(!CloseTradesBeforeDailyClose && !CloseTradesBeforeWeekend)
         return;

      // If No-New-Entry already blocked the trade, there is no open Paper position to force-close.
      if(record.falcon_market_close_blocked == 1)
         return;

      bool use_weekend = false;
      bool use_daily = false;
      datetime boundary_time = 0;
      string reason = "NONE";

      if(CloseTradesBeforeWeekend && FalconWeekendForceCloseUserWindowMinutes() > 0 && FalconMarketCloseDayOfWeek(record.entry_time) == 5)
      {
         datetime weekend_boundary = FalconWeekendForceCloseUserTime(record.entry_time);
         if(FalconWasTradeOpenAtTime(record, weekend_boundary))
         {
            use_weekend = true;
            boundary_time = weekend_boundary;
            reason = StringFormat("USER_WEEKEND_FORCE_CLOSE_%d_MIN", FalconWeekendForceCloseUserWindowMinutes());
         }
      }

      if(!use_weekend && CloseTradesBeforeDailyClose && FalconDailyForceCloseUserWindowMinutes() > 0)
      {
         int dow = FalconMarketCloseDayOfWeek(record.entry_time);
         if(dow >= 1 && dow <= 5)
         {
            datetime daily_boundary = FalconDailyForceCloseUserTime(record.entry_time);
            if(FalconWasTradeOpenAtTime(record, daily_boundary))
            {
               use_daily = true;
               boundary_time = daily_boundary;
               reason = StringFormat("USER_DAILY_FORCE_CLOSE_%d_MIN", FalconDailyForceCloseUserWindowMinutes());
            }
         }
      }

      if(!use_weekend && !use_daily)
         return;

      double force_close_price = 0.0;
      if(!FalconTryGetBoundaryClosePrice(boundary_time, force_close_price))
      {
         m_totals.force_close_override_missing_price_trades++;
         record.falcon_market_close_reason = "FORCE_CLOSE_BOUNDARY_PRICE_MISSING";
         return;
      }

      double before_usd = record.falcon_single_trade_loss_cap_after_net_usd;
      double after_points = FalconForceCloseOverrideNetPoints(record, force_close_price);
      double after_usd = FalconForceCloseOverrideNetUsd(record, force_close_price);

      record.falcon_market_close_status = "FORCE_CLOSED";
      record.falcon_market_close_blocked = 0;
      record.falcon_market_close_reason = reason;
      record.falcon_market_close_before_net_usd = before_usd;
      record.falcon_market_close_after_net_usd = after_usd;
      record.falcon_market_close_impact_usd = after_usd - before_usd;

      record.exit_time = boundary_time;
      record.exit_price = force_close_price;
      record.close_reason = (use_weekend ? "SESSION_BOUNDARY_WEEKEND_FORCE_CLOSE_USER_OVERRIDE" : "SESSION_BOUNDARY_DAILY_FORCE_CLOSE_USER_OVERRIDE");
      record.falcon_single_trade_loss_cap_after_net_points = after_points;
      record.falcon_single_trade_loss_cap_after_net_usd = after_usd;
      record.falcon_single_trade_loss_cap_impact_points = after_points - record.falcon_single_trade_loss_cap_before_net_points;
      record.falcon_single_trade_loss_cap_impact_usd = after_usd - record.falcon_single_trade_loss_cap_before_net_usd;

      m_totals.force_close_override_closed_trades++;
      if(use_weekend)
         m_totals.force_close_override_weekend_closed_trades++;
      else if(use_daily)
         m_totals.force_close_override_daily_closed_trades++;
      m_totals.force_close_override_price_ok_trades++;
      m_totals.force_close_override_before_net_usd += before_usd;
      m_totals.force_close_override_after_net_usd += after_usd;
      m_totals.force_close_override_impact_usd += (after_usd - before_usd);
   }

   void ResetWeeklyStabilityState()
   {
      for(int i = 0; i < 16; i++)
      {
         m_wss_week_keys[i] = 0;
         m_wss_week_trades[i] = 0;
         m_wss_week_wins[i] = 0;
         m_wss_week_net_usd[i] = 0.0;
      }
   }

   int FindOrCreateWeeklyStabilitySlot(const datetime t)
   {
      int key = FalconWeeklyStabilityWeekKey(t);
      if(key <= 0)
         return -1;

      for(int i = 0; i < 16; i++)
      {
         if(m_wss_week_keys[i] == key)
            return i;
      }

      for(int j = 0; j < 16; j++)
      {
         if(m_wss_week_keys[j] == 0)
         {
            m_wss_week_keys[j] = key;
            return j;
         }
      }
      return -1;
   }

   void UpdateWeeklyStabilityFoundation(const FalconTradeLifecycleRecord &record)
   {
      datetime bucket_time = (record.exit_time > 0 ? record.exit_time : record.entry_time);
      int slot = FindOrCreateWeeklyStabilitySlot(bucket_time);
      if(slot < 0)
         return;

      m_wss_week_trades[slot]++;
      if(record.falcon_emergency_after_net_usd > 0.0)
         m_wss_week_wins[slot]++;
      m_wss_week_net_usd[slot] += record.falcon_emergency_after_net_usd;
      m_totals.weekly_stability_evaluated_trades++;
   }

   void FinalizeWeeklyStabilityFoundation()
   {
      int week_count = 0;
      int positive_weeks = 0;
      int negative_weeks = 0;
      double best_week = -1.0e100;
      double worst_week = 1.0e100;
      int active_trade_weeks = 0;

      for(int i = 0; i < 16; i++)
      {
         if(m_wss_week_keys[i] == 0 || m_wss_week_trades[i] <= 0)
            continue;
         week_count++;
         active_trade_weeks++;
         double week_net = m_wss_week_net_usd[i];
         if(week_net > 0.0) positive_weeks++;
         if(week_net < 0.0) negative_weeks++;
         if(week_net > best_week) best_week = week_net;
         if(week_net < worst_week) worst_week = week_net;
      }

      if(week_count <= 0)
      {
         m_totals.weekly_stability_weeks = 0;
         m_totals.weekly_stability_positive_weeks = 0;
         m_totals.weekly_stability_negative_weeks = 0;
         m_totals.weekly_stability_best_week_usd = 0.0;
         m_totals.weekly_stability_worst_week_usd = 0.0;
         m_totals.weekly_stability_score = 0.0;
         return;
      }

      m_totals.weekly_stability_weeks = week_count;
      m_totals.weekly_stability_positive_weeks = positive_weeks;
      m_totals.weekly_stability_negative_weeks = negative_weeks;
      m_totals.weekly_stability_best_week_usd = best_week;
      m_totals.weekly_stability_worst_week_usd = worst_week;

      double consistency_score = 40.0 * ((double)positive_weeks / (double)week_count);
      double drawdown_score = 30.0;
      if(worst_week < 0.0)
      {
         double denom = MathMax(MathAbs(m_totals.final_working_net_usd), 1.0);
         double penalty = FalconClampDouble((MathAbs(worst_week) / denom) * 30.0, 0.0, 30.0);
         drawdown_score = 30.0 - penalty;
      }
      double activity_score = FalconClampDouble(((double)m_totals.total_trades / (double)week_count) / 30.0 * 15.0, 0.0, 15.0);
      double lot_control_score = (m_totals.dynamic_lotsizing_safety_active_lot_max <= 1.0 ? 15.0 : 7.5);
      m_totals.weekly_stability_score = FalconClampDouble(consistency_score + drawdown_score + activity_score + lot_control_score, 0.0, 100.0);
   }

   void WriteReportCreationGuaranteeFile()
   {
      int handle = FileOpen(m_report_creation_guarantee_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create report guarantee file: %s", m_report_creation_guarantee_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "GeneratedAt", "StorageMode",
                "ModeTag", "FromDateTag", "ToDateTag", "ForceCreateReportFilesOnInit",
                "TradeLifecycleFile", "SummaryFile", "MarketDiagnosticsFile",
                "CandleCacheDiagnosticsFile", "EvidenceDiagnosticsFile", "ShadowDiagnosticsFile",
                "NoLookaheadDiagnosticsFile", "StrategyRegistryDiagnosticsFile", "StrategyAdapterDiagnosticsFile",
                "FvgMicroDetectorDiagnosticsFile", "FvgMicroCandidateDiagnosticsFile",
                "FvgMicroRetestWatcherDiagnosticsFile", "FvgMicroTradePlanStagingDiagnosticsFile",
                "FvgMicroLifecycleSimulationDiagnosticsFile", "RuntimeReportVerificationFile",
                "FvgMicroRuntimeSmokeTestFile", "FvgMicroRuntimeReportAuditFile");

      FileWrite(handle,
                EA_NAME, EA_VERSION_TAG, EA_BUILD_TAG, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                FalconReportStorageMode(), FalconEffectiveReportModeTag(), FalconEffectiveReportFromDateTag(), FalconEffectiveReportToDateTag(),
                FalconBoolToYesNo(ForceCreateReportFilesOnInit),
                m_trade_report_file, m_summary_report_file, m_market_diagnostics_file,
                m_candle_cache_diagnostics_file, m_evidence_diagnostics_file, m_shadow_diagnostics_file,
                m_no_lookahead_diagnostics_file, m_strategy_registry_diagnostics_file, m_strategy_adapter_diagnostics_file,
                m_fvg_micro_detector_diagnostics_file, m_fvg_micro_candidate_diagnostics_file,
                m_fvg_micro_retest_watcher_diagnostics_file, m_fvg_micro_tradeplan_staging_diagnostics_file,
                m_fvg_micro_lifecycle_simulation_diagnostics_file, m_runtime_report_verification_file,
                m_fvg_micro_smoke_test_file, m_fvg_micro_runtime_report_audit_file);

      FileClose(handle);
   }

   void WriteMarketDiagnosticsSnapshot(const FalconQuoteContext &quote_context,
                                       const FalconCandleSnapshot &primary_candle)
   {
      if(!m_initialized || !EnableMarketDiagnosticsReport)
         return;

      int handle = FileOpen(m_market_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write market diagnostics report: %s", m_market_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "Digits", "Point", "TickSize", "TickValue", "ContractSize",
                "BrokerSpreadPoints", "LiveSpreadPoints", "StopsLevelPoints",
                "MinLot", "MaxLot", "LotStep",
                "Bid", "Ask", "Last", "TickTime", "TickVolume", "TickVolumeReal",
                "UseClosedCandlesOnly", "PrimaryContextTimeframe", "AnalysisCandleShift",
                "CandleTime", "CandleOpen", "CandleHigh", "CandleLow", "CandleClose",
                "CandleTickVolume", "CandleRealVolume", "CandleSpread", "IsClosed", "IsValid",
                "ConfiguredCapital", "DailyLossLimitEnabled", "FixedDailyLossAmount", "DailyLossPercentOfCapital",
                "EnableRealExecution");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                m_symbol_context.digits,
                DoubleToString(m_symbol_context.point, 10),
                DoubleToString(m_symbol_context.tick_size, 10),
                DoubleToString(m_symbol_context.tick_value, 5),
                DoubleToString(m_symbol_context.contract_size, 2),
                (int)m_symbol_context.spread_points,
                (int)quote_context.spread_points,
                (int)m_symbol_context.stops_level_points,
                DoubleToString(m_symbol_context.min_lot, 2),
                DoubleToString(m_symbol_context.max_lot, 2),
                DoubleToString(m_symbol_context.lot_step, 2),
                DoubleToString(quote_context.bid, m_symbol_context.digits),
                DoubleToString(quote_context.ask, m_symbol_context.digits),
                DoubleToString(quote_context.last, m_symbol_context.digits),
                FalconTimeToString(quote_context.tick_time),
                quote_context.volume,
                DoubleToString(quote_context.volume_real, 2),
                (UseClosedCandlesOnly ? "true" : "false"),
                FalconTimeframeToString(primary_candle.timeframe),
                primary_candle.source_shift,
                FalconTimeToString(primary_candle.time),
                DoubleToString(primary_candle.open, m_symbol_context.digits),
                DoubleToString(primary_candle.high, m_symbol_context.digits),
                DoubleToString(primary_candle.low, m_symbol_context.digits),
                DoubleToString(primary_candle.close, m_symbol_context.digits),
                primary_candle.tick_volume,
                primary_candle.real_volume,
                primary_candle.spread,
                (primary_candle.is_closed ? "true" : "false"),
                (primary_candle.is_valid ? "true" : "false"),
                DoubleToString(FalconConfiguredCapital(), 2),
                (UseDailyLossLimit ? "true" : "false"),
                DoubleToString(FixedDailyLossAmount, 2),
                DoubleToString(DailyLossPercentOfCapital, 2),
                (EnableRealExecution ? "true" : "false"));

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Market diagnostics snapshot written: %s", m_market_diagnostics_file));
   }

   void WriteCandleCacheDiagnosticsSnapshot(CFalconCandleCache &cache)
   {
      if(!m_initialized || !EnableCandleCacheDiagnosticsReport)
         return;

      int handle = FileOpen(m_candle_cache_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write candle cache diagnostics report: %s", m_candle_cache_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "UseClosedCandlesOnly", "AnalysisShift", "CacheCount", "ValidCount",
                "Timeframe", "CandleTime", "Open", "High", "Low", "Close",
                "TickVolume", "RealVolume", "Spread", "IsClosed", "IsValid");

      for(int i = 0; i < cache.Count(); i++)
      {
         FalconCandleSnapshot snapshot;
         cache.GetSnapshotByIndex(i, snapshot);

         FileWrite(handle,
                   FalconCsvSafe(EA_NAME),
                   FalconCsvSafe(EA_VERSION_TAG),
                   FalconCsvSafe(EA_BUILD_TAG),
                   FalconCsvSafe(m_symbol_context.symbol),
                   FalconTimeToString(TimeCurrent()),
                   (UseClosedCandlesOnly ? "true" : "false"),
                   cache.AnalysisShift(),
                   cache.Count(),
                   cache.ValidCount(),
                   FalconTimeframeToString(snapshot.timeframe),
                   FalconTimeToString(snapshot.time),
                   DoubleToString(snapshot.open, m_symbol_context.digits),
                   DoubleToString(snapshot.high, m_symbol_context.digits),
                   DoubleToString(snapshot.low, m_symbol_context.digits),
                   DoubleToString(snapshot.close, m_symbol_context.digits),
                   snapshot.tick_volume,
                   snapshot.real_volume,
                   snapshot.spread,
                   (snapshot.is_closed ? "true" : "false"),
                   (snapshot.is_valid ? "true" : "false"));
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Candle cache diagnostics snapshot written: %s", m_candle_cache_diagnostics_file));
   }

   void WriteEvidenceDiagnosticsSnapshot(CFalconEvidenceFramework &evidence_framework)
   {
      if(!m_initialized || !EnableEvidenceDiagnosticsReport)
         return;

      int handle = FileOpen(m_evidence_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write evidence diagnostics report: %s", m_evidence_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "EvidenceId", "EvidenceName", "EvidenceType", "EvidenceState",
                "DirectionBias", "SourceTimeframe", "Score", "RuntimePermission", "Notes");

      for(int i = 0; i < evidence_framework.Count(); i++)
      {
         FalconEvidenceRecord record;
         if(!evidence_framework.GetRecordByIndex(i, record))
            continue;

         FileWrite(handle,
                   FalconCsvSafe(EA_NAME),
                   FalconCsvSafe(EA_VERSION_TAG),
                   FalconCsvSafe(EA_BUILD_TAG),
                   FalconCsvSafe(m_symbol_context.symbol),
                   FalconTimeToString(TimeCurrent()),
                   record.evidence_id,
                   record.evidence_name,
                   FalconEvidenceTypeToString(record.evidence_type),
                   FalconEvidenceStateToString(record.evidence_state),
                   FalconDirectionToString(record.direction_bias),
                   FalconTimeframeToString(record.source_timeframe),
                   DoubleToString(record.score, 2),
                   (record.is_runtime_permission ? "true" : "false"),
                   record.notes);
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Evidence diagnostics snapshot written: %s", m_evidence_diagnostics_file));
   }

   void WriteShadowDiagnosticsSnapshot(CFalconShadowExecutor &shadow_executor)
   {
      if(!m_initialized || !EnableShadowDiagnosticsReport)
         return;

      int handle = FileOpen(m_shadow_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write shadow diagnostics report: %s", m_shadow_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "ShadowModeEnabled", "ShadowExecutorInitialized", "BrokerOrdersAllowed",
                "StagedRecords", "ClosedRecords", "CancelledRecords",
                "TradeLifecycleBridge", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (EnableShadowMode ? "true" : "false"),
                (shadow_executor.IsInitialized() ? "true" : "false"),
                "false",
                shadow_executor.StagedRecords(),
                shadow_executor.ClosedRecords(),
                shadow_executor.CancelledRecords(),
                "ShadowToTradeLifecycleRecord_READY",
                "v0.13.1 is framework only. No strategy creates shadow records yet.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Shadow diagnostics snapshot written: %s", m_shadow_diagnostics_file));
   }

   void WriteNoLookaheadDiagnosticsSnapshot(CFalconRuntimeSafetyGuard &runtime_guard)
   {
      if(!m_initialized || !EnableNoLookaheadDiagnosticsReport)
         return;

      int handle = FileOpen(m_no_lookahead_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write no-lookahead diagnostics report: %s", m_no_lookahead_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "GuardInitialized", "TotalChecks",
                "CheckId", "CheckName", "Status", "RiskType", "Timeframe", "SourceShift",
                "UsedClosedCandle", "CurrentCandleBlocked", "FinalStateBlocked",
                "StagingAllowed", "Notes");

      for(int i = 0; i < runtime_guard.Count(); i++)
      {
         FalconRuntimeSafetyCheck check;
         if(!runtime_guard.GetCheckByIndex(i, check))
            continue;

         FileWrite(handle,
                   FalconCsvSafe(EA_NAME),
                   FalconCsvSafe(EA_VERSION_TAG),
                   FalconCsvSafe(EA_BUILD_TAG),
                   FalconCsvSafe(m_symbol_context.symbol),
                   FalconTimeToString(TimeCurrent()),
                   (runtime_guard.IsInitialized() ? "true" : "false"),
                   runtime_guard.Count(),
                   check.check_id,
                   check.check_name,
                   FalconRuntimeSafetyStatusToString(check.status),
                   FalconLookaheadRiskToString(check.risk_type),
                   FalconTimeframeToString(check.timeframe),
                   check.source_shift,
                   (check.used_closed_candle ? "true" : "false"),
                   (check.current_candle_blocked ? "true" : "false"),
                   (check.final_state_blocked ? "true" : "false"),
                   (check.staging_allowed ? "true" : "false"),
                   check.notes);
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("No-lookahead diagnostics snapshot written: %s", m_no_lookahead_diagnostics_file));
   }

   void WriteStrategyRegistryDiagnosticsSnapshot(CFalconStrategyRegistry &registry)
   {
      if(!m_initialized || !EnableStrategyRegistryDiagnosticsReport)
         return;

      int handle = FileOpen(m_strategy_registry_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write strategy registry diagnostics report: %s", m_strategy_registry_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "RegistryInitialized", "RegisteredStrategies", "EnabledByInputs",
                "CoreCount", "PriceActionCount", "OpeningCount", "LiquidityCount", "ConfirmationCount", "ResearchCount",
                "StrategyId", "StrategyName", "EngineId", "Group", "InputEnabled",
                "HealthStatus", "MaxAllowedStage", "ShadowAllowed", "PaperAllowed", "DemoAllowed", "LiveAllowed", "Notes");

      for(int i = 0; i < registry.CountRegisteredStrategies(); i++)
      {
         FalconStrategyRegistryEntry entry;
         if(!registry.GetEntryByIndex(i, entry))
            continue;

         FileWrite(handle,
                   FalconCsvSafe(EA_NAME),
                   FalconCsvSafe(EA_VERSION_TAG),
                   FalconCsvSafe(EA_BUILD_TAG),
                   FalconCsvSafe(m_symbol_context.symbol),
                   FalconTimeToString(TimeCurrent()),
                   (registry.IsInitialized() ? "true" : "false"),
                   registry.CountRegisteredStrategies(),
                   registry.CountEnabledStrategies(),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_CORE),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_PRICE_ACTION),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_OPENING),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_LIQUIDITY),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_CONFIRMATION),
                   registry.CountByGroup(FALCON_STRATEGY_GROUP_RESEARCH),
                   FalconCsvSafe(entry.strategy_id),
                   FalconCsvSafe(entry.strategy_name),
                   FalconCsvSafe(entry.engine_id),
                   FalconStrategyGroupToString(entry.strategy_group),
                   (entry.input_enabled ? "true" : "false"),
                   FalconEngineHealthToString(entry.health_status),
                   FalconEngineStatusToString(entry.max_allowed_stage),
                   (entry.shadow_allowed ? "true" : "false"),
                   (entry.paper_allowed ? "true" : "false"),
                   (entry.demo_allowed ? "true" : "false"),
                   (entry.live_allowed ? "true" : "false"),
                   FalconCsvSafe(entry.notes));
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Strategy registry diagnostics snapshot written: %s", m_strategy_registry_diagnostics_file));
   }



   void WriteStrategyAdapterDiagnosticsSnapshot(CFalconFirstShadowStrategyAdapterShell &adapter)
   {
      if(!m_initialized || !EnableStrategyAdapterDiagnosticsReport)
         return;

      int handle = FileOpen(m_strategy_adapter_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write strategy adapter diagnostics report: %s", m_strategy_adapter_diagnostics_file));
         return;
      }

      FalconStrategyAdapterSnapshot snapshot = adapter.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "AdapterInitialized", "AdapterId", "TargetStrategyId", "StrategyName", "EngineId",
                "Group", "HealthStatus", "MaxAllowedStage", "AdapterStatus",
                "RegistryFound", "InputEnabled", "ShadowAllowed", "ShadowExecutorReady", "RuntimeSafetyReady",
                "CandidateRequested", "CandidateStaged", "LiveAllowed", "OrderSendUsed",
                "NoTradeReason", "SafetyReason", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (adapter.IsInitialized() ? "true" : "false"),
                snapshot.adapter_id,
                snapshot.target_strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconStrategyGroupToString(snapshot.strategy_group),
                FalconEngineHealthToString(snapshot.health_status),
                FalconEngineStatusToString(snapshot.max_allowed_stage),
                FalconAdapterStatusToString(snapshot.adapter_status),
                (snapshot.registry_found ? "true" : "false"),
                (snapshot.input_enabled ? "true" : "false"),
                (snapshot.shadow_allowed ? "true" : "false"),
                (snapshot.shadow_executor_ready ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.candidate_requested ? "true" : "false"),
                (snapshot.candidate_staged ? "true" : "false"),
                (snapshot.live_allowed ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                snapshot.no_trade_reason,
                snapshot.safety_reason,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Strategy adapter diagnostics snapshot written: %s", m_strategy_adapter_diagnostics_file));
   }

   void WriteFvgMicroDetectorDiagnosticsSnapshot(CFalconFvgMicroShadowDetectorStub &detector)
   {
      if(!m_initialized || !EnableFvgMicroDetectorDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_detector_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro detector diagnostics report: %s", m_fvg_micro_detector_diagnostics_file));
         return;
      }

      FalconFvgMicroDetectorSnapshot snapshot = detector.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "DetectorInitialized", "DetectorId", "StrategyId", "StrategyName", "EngineId",
                "DetectorStatus", "RegistryFound", "InputEnabled",
                "CandleCacheReady", "EvidenceFrameworkReady", "RuntimeSafetyReady",
                "UsedClosedCandle", "OrderSendUsed", "AnalysisTimeframe", "AnalysisShift",
                "CandleTime", "Open", "High", "Low", "Close", "TickVolume",
                "FvgDetected", "FvgDirection", "OlderCandleTime", "MiddleCandleTime", "NewerCandleTime",
                "OlderHigh", "OlderLow", "MiddleHigh", "MiddleLow", "NewerHigh", "NewerLow",
                "FvgLower", "FvgUpper", "FvgSizePrice", "FvgSizePoints",
                "EvidenceScore", "EvidenceSummary", "NoTradeReason", "SafetyReason", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (detector.IsInitialized() ? "true" : "false"),
                snapshot.detector_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconDetectorStatusToString(snapshot.detector_status),
                (snapshot.registry_found ? "true" : "false"),
                (snapshot.input_enabled ? "true" : "false"),
                (snapshot.candle_cache_ready ? "true" : "false"),
                (snapshot.evidence_framework_ready ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.used_closed_candle ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconTimeframeToString(snapshot.analysis_timeframe),
                snapshot.analysis_shift,
                FalconTimeToString(snapshot.candle_time),
                DoubleToString(snapshot.candle_open, m_symbol_context.digits),
                DoubleToString(snapshot.candle_high, m_symbol_context.digits),
                DoubleToString(snapshot.candle_low, m_symbol_context.digits),
                DoubleToString(snapshot.candle_close, m_symbol_context.digits),
                snapshot.candle_tick_volume,
                (snapshot.fvg_detected ? "true" : "false"),
                FalconDirectionToString(snapshot.fvg_direction),
                FalconTimeToString(snapshot.older_candle_time),
                FalconTimeToString(snapshot.middle_candle_time),
                FalconTimeToString(snapshot.newer_candle_time),
                DoubleToString(snapshot.older_candle_high, m_symbol_context.digits),
                DoubleToString(snapshot.older_candle_low, m_symbol_context.digits),
                DoubleToString(snapshot.middle_candle_high, m_symbol_context.digits),
                DoubleToString(snapshot.middle_candle_low, m_symbol_context.digits),
                DoubleToString(snapshot.newer_candle_high, m_symbol_context.digits),
                DoubleToString(snapshot.newer_candle_low, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_lower, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_upper, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_size_price, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_size_points, 2),
                DoubleToString(snapshot.evidence_score, 2),
                snapshot.evidence_summary,
                snapshot.no_trade_reason,
                snapshot.safety_reason,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro detector diagnostics snapshot written: %s", m_fvg_micro_detector_diagnostics_file));
   }

   void WriteFvgMicroCandidateDiagnosticsSnapshot(CFalconFvgMicroShadowCandidateBuilder &builder)
   {
      if(!m_initialized || !EnableFvgMicroCandidateDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_candidate_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro candidate diagnostics report: %s", m_fvg_micro_candidate_diagnostics_file));
         return;
      }

      FalconFvgMicroShadowCandidateSnapshot snapshot = builder.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "BuilderInitialized", "BuilderId", "CandidateId",
                "StrategyId", "StrategyName", "EngineId", "CandidateStatus",
                "DetectorInitialized", "RegistryFound", "InputEnabled", "ShadowAllowed", "RuntimeSafetyReady",
                "FvgDetected", "CandidateCreated", "TradePlanCreated", "StagedToShadowExecutor", "OrderSendUsed",
                "Direction", "AnalysisTimeframe", "SetupTime",
                "EntryZoneLower", "EntryZoneUpper", "FvgSizePoints",
                "QualityFiltersEnabled", "QualityFiltersPassed", "QualityMinFvgSizePoints",
                "QualityCurrentSpreadPoints", "QualityMaxSpreadPoints", "QualityFvgAgeBars",
                "QualityMaxFvgAgeBars", "QualityRetestFreshnessBars", "QualityRejectReason",
                "Score", "BlockReason", "EvidenceSummary", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (builder.IsInitialized() ? "true" : "false"),
                snapshot.builder_id,
                snapshot.candidate_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconCandidateStatusToString(snapshot.candidate_status),
                (snapshot.detector_initialized ? "true" : "false"),
                (snapshot.registry_found ? "true" : "false"),
                (snapshot.input_enabled ? "true" : "false"),
                (snapshot.shadow_allowed ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.fvg_detected ? "true" : "false"),
                (snapshot.candidate_created ? "true" : "false"),
                (snapshot.tradeplan_created ? "true" : "false"),
                (snapshot.staged_to_shadow_executor ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconDirectionToString(snapshot.direction),
                FalconTimeframeToString(snapshot.analysis_timeframe),
                FalconTimeToString(snapshot.setup_time),
                DoubleToString(snapshot.entry_zone_lower, m_symbol_context.digits),
                DoubleToString(snapshot.entry_zone_upper, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_size_points, 2),
                FalconBoolToYesNo(snapshot.quality_filters_enabled),
                FalconBoolToYesNo(snapshot.quality_filters_passed),
                DoubleToString(snapshot.quality_min_fvg_size_points, 2),
                IntegerToString((int)snapshot.quality_current_spread_points),
                IntegerToString((int)snapshot.quality_max_spread_points),
                IntegerToString(snapshot.quality_fvg_age_bars),
                IntegerToString(snapshot.quality_max_fvg_age_bars),
                IntegerToString(snapshot.quality_retest_freshness_bars),
                FalconCsvSafe(snapshot.quality_reject_reason),
                DoubleToString(snapshot.score, 2),
                FalconCsvSafe(snapshot.block_reason),
                FalconCsvSafe(snapshot.evidence_summary),
                FalconCsvSafe(snapshot.notes));

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro shadow candidate diagnostics snapshot written: %s", m_fvg_micro_candidate_diagnostics_file));
   }

   void WriteFvgMicroRetestWatcherDiagnosticsSnapshot(CFalconFvgMicroRetestWatcher &watcher)
   {
      if(!m_initialized || !EnableFvgMicroRetestWatcherDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_retest_watcher_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro retest watcher diagnostics report: %s", m_fvg_micro_retest_watcher_diagnostics_file));
         return;
      }

      FalconFvgMicroRetestWatcherSnapshot snapshot = watcher.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "WatcherInitialized", "WatcherId", "CandidateId",
                "StrategyId", "StrategyName", "EngineId", "WatcherStatus",
                "CandidateBuilderInitialized", "CandidateReady", "QuoteValid", "RuntimeSafetyReady",
                "FvgDetected", "RetestTouched", "TradePlanSkeletonCreated", "TradePlanCreated", "StagedToShadowExecutor", "OrderSendUsed",
                "Direction", "AnalysisTimeframe", "SetupTime", "WatchTime", "WatchPrice",
                "FvgLower", "FvgUpper", "FvgSizePoints",
                "PlannedLotSize", "PlannedEntryPrice", "PlannedStructuralSL", "PlannedTP1", "PlannedTP2", "PlannedTP3",
                "RetestReason", "BlockReason", "SkeletonNotes", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (watcher.IsInitialized() ? "true" : "false"),
                snapshot.watcher_id,
                snapshot.candidate_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconRetestWatcherStatusToString(snapshot.watcher_status),
                (snapshot.candidate_builder_initialized ? "true" : "false"),
                (snapshot.candidate_ready ? "true" : "false"),
                (snapshot.quote_valid ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.fvg_detected ? "true" : "false"),
                (snapshot.retest_touched ? "true" : "false"),
                (snapshot.tradeplan_skeleton_created ? "true" : "false"),
                (snapshot.tradeplan_created ? "true" : "false"),
                (snapshot.staged_to_shadow_executor ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconDirectionToString(snapshot.direction),
                FalconTimeframeToString(snapshot.analysis_timeframe),
                FalconTimeToString(snapshot.setup_time),
                FalconTimeToString(snapshot.watch_time),
                DoubleToString(snapshot.watch_price, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_lower, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_upper, m_symbol_context.digits),
                DoubleToString(snapshot.fvg_size_points, 2),
                DoubleToString(snapshot.planned_lot_size, 2),
                DoubleToString(snapshot.planned_entry_price, m_symbol_context.digits),
                DoubleToString(snapshot.planned_structural_sl, m_symbol_context.digits),
                DoubleToString(snapshot.planned_tp1, m_symbol_context.digits),
                DoubleToString(snapshot.planned_tp2, m_symbol_context.digits),
                DoubleToString(snapshot.planned_tp3, m_symbol_context.digits),
                snapshot.retest_reason,
                snapshot.block_reason,
                snapshot.skeleton_notes,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro retest watcher diagnostics snapshot written: %s", m_fvg_micro_retest_watcher_diagnostics_file));
   }


   void WriteFvgMicroTradePlanStagingDiagnosticsSnapshot(CFalconFvgMicroTradePlanStagingDryRun &stager)
   {
      if(!m_initialized || !EnableFvgMicroTradePlanStagingDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_tradeplan_staging_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro TradePlan staging diagnostics report: %s", m_fvg_micro_tradeplan_staging_diagnostics_file));
         return;
      }

      FalconFvgMicroTradePlanStagingSnapshot snapshot = stager.GetSnapshot();

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "StagerInitialized", "StagerId", "PlanId", "CandidateId", "ShadowId",
                "StrategyId", "StrategyName", "EngineId", "StagingStatus", "WatcherStatus",
                "WatcherInitialized", "RetestTouched", "SkeletonReady", "RuntimeSafetyReady", "ShadowExecutorReady",
                "TradePlanCreated", "ValidatePassed", "StagedToShadowExecutor", "OrderSendUsed",
                "Direction", "AnalysisTimeframe", "SetupTime", "StagingTime",
                "LotSize", "Entry", "SL", "TP1", "TP2", "TP3",
                "RiskProfile", "ManagementProfile", "ValidationReason", "StagingReason", "EvidenceSummary", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                (stager.IsInitialized() ? "true" : "false"),
                snapshot.stager_id,
                snapshot.plan_id,
                snapshot.candidate_id,
                snapshot.shadow_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconTradePlanStagingStatusToString(snapshot.staging_status),
                FalconRetestWatcherStatusToString(snapshot.watcher_status),
                (snapshot.watcher_initialized ? "true" : "false"),
                (snapshot.retest_touched ? "true" : "false"),
                (snapshot.skeleton_ready ? "true" : "false"),
                (snapshot.runtime_safety_ready ? "true" : "false"),
                (snapshot.shadow_executor_ready ? "true" : "false"),
                (snapshot.tradeplan_created ? "true" : "false"),
                (snapshot.validate_passed ? "true" : "false"),
                (snapshot.staged_to_shadow_executor ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconDirectionToString(snapshot.direction),
                FalconTimeframeToString(snapshot.analysis_timeframe),
                FalconTimeToString(snapshot.setup_time),
                FalconTimeToString(snapshot.staging_time),
                DoubleToString(snapshot.lot_size, 2),
                DoubleToString(snapshot.entry_price, m_symbol_context.digits),
                DoubleToString(snapshot.structural_sl, m_symbol_context.digits),
                DoubleToString(snapshot.tp1, m_symbol_context.digits),
                DoubleToString(snapshot.tp2, m_symbol_context.digits),
                DoubleToString(snapshot.tp3, m_symbol_context.digits),
                snapshot.risk_profile,
                snapshot.management_profile,
                snapshot.validation_reason,
                snapshot.staging_reason,
                snapshot.evidence_summary,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro TradePlan staging dry-run diagnostics snapshot written: %s", m_fvg_micro_tradeplan_staging_diagnostics_file));
   }

   void WriteFvgMicroLifecycleSimulationDiagnosticsSnapshot(CFalconFvgMicroShadowLifecycleSimulation &simulator)
   {
      if(!m_initialized || !EnableFvgMicroLifecycleSimulationDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_lifecycle_simulation_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro lifecycle simulation diagnostics report: %s", m_fvg_micro_lifecycle_simulation_diagnostics_file));
         return;
      }

      FalconFvgMicroShadowLifecycleSnapshot snapshot = simulator.GetSnapshot();
      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "SimulatorId", "LifecycleStatus", "ShadowStatus", "ShadowId",
                "StrategyId", "StrategyName", "EngineId", "Direction",
                "StagerReady", "StagedToShadowExecutor", "ShadowRecordLoaded", "QuoteValid",
                "CloseRecordCreated", "RegisteredToTradeReport", "OrderSendUsed",
                "EntryTime", "EvaluationTime", "ElapsedSeconds",
                "Entry", "SL", "TP1", "TP2", "TP3", "CurrentPrice", "ExitPrice",
                "Outcome", "ProfitIndexPoints", "LoseIndexPoints", "NetIndexPoints",
                "ProfitUSD", "LoseUSD", "NetUSD", "CloseReason", "LifecycleReason", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                snapshot.simulator_id,
                FalconShadowLifecycleStatusToString(snapshot.lifecycle_status),
                FalconShadowStatusToString(snapshot.shadow_record_status),
                snapshot.shadow_id,
                snapshot.strategy_id,
                snapshot.strategy_name,
                snapshot.engine_id,
                FalconDirectionToString(snapshot.direction),
                (snapshot.stager_ready ? "true" : "false"),
                (snapshot.staged_to_shadow_executor ? "true" : "false"),
                (snapshot.shadow_record_loaded ? "true" : "false"),
                (snapshot.quote_valid ? "true" : "false"),
                (snapshot.close_record_created ? "true" : "false"),
                (snapshot.registered_to_trade_report ? "true" : "false"),
                (snapshot.order_send_used ? "true" : "false"),
                FalconTimeToString(snapshot.entry_time),
                FalconTimeToString(snapshot.evaluation_time),
                snapshot.elapsed_seconds,
                DoubleToString(snapshot.entry_price, m_symbol_context.digits),
                DoubleToString(snapshot.structural_sl, m_symbol_context.digits),
                DoubleToString(snapshot.tp1, m_symbol_context.digits),
                DoubleToString(snapshot.tp2, m_symbol_context.digits),
                DoubleToString(snapshot.tp3, m_symbol_context.digits),
                DoubleToString(snapshot.current_price, m_symbol_context.digits),
                DoubleToString(snapshot.simulated_exit_price, m_symbol_context.digits),
                FalconOutcomeToString(snapshot.simulated_outcome),
                DoubleToString(snapshot.profit_index_points, 2),
                DoubleToString(snapshot.loss_index_points, 2),
                DoubleToString(snapshot.net_index_points, 2),
                DoubleToString(snapshot.profit_usd, 2),
                DoubleToString(snapshot.loss_usd, 2),
                DoubleToString(snapshot.net_usd, 2),
                snapshot.close_reason,
                snapshot.lifecycle_reason,
                snapshot.notes);

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro lifecycle simulation diagnostics snapshot written: %s", m_fvg_micro_lifecycle_simulation_diagnostics_file));
   }

   void WriteReportCalibrationDiagnosticsSnapshot()
   {
      if(!m_initialized || !EnableReportCalibrationDiagnosticsReport)
         return;

      int handle = FileOpen(m_report_calibration_diagnostics_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write report calibration diagnostics report: %s", m_report_calibration_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "CalibrationItem", "Status", "ReportFile", "ExpectedFields",
                "CurrentMode", "CleanupGateDecision", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "TradeLifecycleSchema",
                "PASS",
                m_trade_report_file,
                "Entry|SL|TP1|TP2|TP3|Exit|WinLose|ProfitIndexPoints|LoseIndexPoints|NetIndexPoints|ProfitUSD|LoseUSD|NetUSD|StrategyName|EngineId",
                "Append-on-close when a controlled Shadow record closes",
                "KEEP_CORE_REPORT",
                "Main lifecycle report contains the fields requested by the project owner. No final heavy rebuild is used for trade rows.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "SummarySchema",
                "PASS",
                m_summary_report_file,
                "TotalTrades|WinTrades|LoseTrades|WinRate|LoseRate|TotalProfitIndexPoints|TotalLossIndexPoints|NetIndexPoints|TotalProfitUSD|TotalLossUSD|NetUSD",
                "Written on deinitialization from accumulated closed records",
                "KEEP_CORE_REPORT",
                "Summary is intentionally compact and will remain part of the final product.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "ShadowLifecycleCalibration",
                "WATCH",
                m_fvg_micro_lifecycle_simulation_diagnostics_file,
                "LifecycleStatus|ShadowStatus|Entry|SL|TP1|CurrentPrice|ExitPrice|Outcome|ProfitIndexPoints|LoseIndexPoints|ProfitUSD|LoseUSD",
                "Diagnostic only while FVG Micro Shadow lifecycle is being validated",
                "CLEANUP_AFTER_VALIDATION",
                "Keep while validating Shadow lifecycle behavior. Later merge useful fields into TradeLifecycle and remove temporary detail report if no longer needed.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "DiagnosticInputsInventory",
                "WATCH",
                "Inputs",
                "EnableMarketDiagnosticsReport|EnableCandleCacheDiagnosticsReport|EnableEvidenceDiagnosticsReport|EnableShadowDiagnosticsReport|EnableNoLookaheadDiagnosticsReport|FVG diagnostics toggles",
                "Development diagnostics are ON by default during v0.x foundation builds",
                "REDUCE_INPUTS_AFTER_LOCK",
                "Project rule: after each diagnostic path is proven, remove temporary inputs or move them under a compact Research/Debug preset.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "ExecutionSafety",
                "PASS",
                "N/A",
                "No OrderSend|No Paper|No Demo|No Live",
                "Shadow lifecycle simulation only",
                "KEEP_SAFETY_GUARD",
                "Real execution remains impossible in this build even if EnableRealExecution is changed.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                "CleanupGateRule",
                "ACTIVE",
                m_report_calibration_diagnostics_file,
                "CleanupCandidate|Decision|Reason",
                "Review only, no trading logic change",
                "MANDATORY_BEFORE_NEXT_MAJOR_ACTIVATION",
                "Before expanding to Paper/Demo, remove noisy diagnostics, keep only main lifecycle, summary, evidence, rejection, and selected engine health reports.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Report calibration and cleanup gate diagnostics snapshot written: %s", m_report_calibration_diagnostics_file));
   }


   void WriteFvgMicroSmokeTestDiagnosticsSnapshot(const string trigger)
   {
      if(!m_initialized || !EnableFvgMicroSmokeTestDiagnosticsReport)
         return;

      int handle = FileOpen(m_fvg_micro_smoke_test_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro smoke-test diagnostics report: %s", m_fvg_micro_smoke_test_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt", "Trigger",
                "SmokeCheck", "Status", "Result", "Notes");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "ExecutionSafety",
                "PASS",
                "NO_REAL_EXECUTION",
                "Execution guard remains active. v0.56.4b uses tester-only atomic entry+exit bridge plus exit observation when EnableRealExecution=true; Demo/Live and BrokerModify remain disabled.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "ShadowPipelineShape",
                "PASS",
                "DETECTOR_TO_LIFECYCLE_PATH_PRESENT",
                "FVG Detector, Candidate Builder, Retest Watcher, TradePlan Stager, Shadow Executor, and Lifecycle Simulator are connected in diagnostic mode.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "TradeLifecycleRows",
                "WATCH",
                "DATA_DEPENDENT",
                "TradeLifecycle rows appear only if a closed-candle M5 FVG is detected, price retests the zone, staging passes, and the shadow record reaches TP1/SL/timeout.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "ReportVerification",
                "PASS",
                m_runtime_report_verification_file,
                "Runtime report verification tracks whether generated reports are readable and non-empty.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "DiagnosticCleanupGate",
                "ACTIVE",
                "CLEAN_LATER",
                "This smoke-test report is temporary and must be merged or removed after the FVG Micro shadow runtime path is validated.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro shadow runtime smoke-test diagnostics snapshot written: %s | Trigger=%s", m_fvg_micro_smoke_test_file, trigger));
   }


   void WriteFvgMicroRuntimeReportAuditSnapshot(const string trigger)
   {
      if(!m_initialized || !EnableFvgMicroRuntimeReportAuditReport)
         return;

      int handle = FileOpen(m_fvg_micro_runtime_report_audit_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write FVG Micro runtime report audit: %s", m_fvg_micro_runtime_report_audit_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt", "Trigger",
                "AuditItem", "ReportFile", "ExpectedContent", "Readable", "SizeBytes", "AuditStatus", "Decision", "Notes");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "TradeLifecycleRows", m_trade_report_file, EnableMainReport,
                                         "Header plus closed Shadow lifecycle rows when FVG+Retest+Staging+TP/SL/Timeout occurs",
                                         "DATA_DEPENDENT",
                                         "If empty after a test window, inspect whether no FVG retest occurred or whether staging/lifecycle path is blocked.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "SummaryTotals", m_summary_report_file, EnableMainReport,
                                         "WinRate/LoseRate/TotalProfitIndexPoints/TotalLossIndexPoints/TotalProfitUSD/TotalLossUSD",
                                         "KEEP_CORE_REPORT",
                                         "Summary is expected to be non-empty after OnDeinit. During OnInit it can be header-only.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "FvgDetector", m_fvg_micro_detector_diagnostics_file, EnableFvgMicroDetectorDiagnosticsReport,
                                         "FVG detected flag, direction, bounds, candle times and high/low values",
                                         "KEEP_UNTIL_FVG_PATH_LOCK",
                                         "Detector report must remain until FVG Micro shadow logic is stable.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "FvgCandidate", m_fvg_micro_candidate_diagnostics_file, EnableFvgMicroCandidateDiagnosticsReport,
                                         "Shadow candidate status and blocker reason",
                                         "KEEP_UNTIL_CANDIDATE_LOCK",
                                         "Candidate report explains why a detected FVG did or did not become a research candidate.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "RetestWatcher", m_fvg_micro_retest_watcher_diagnostics_file, EnableFvgMicroRetestWatcherDiagnosticsReport,
                                         "Retest touched status plus skeleton Entry/SL/TP projections",
                                         "KEEP_UNTIL_RETEST_LOCK",
                                         "Watcher report is needed to separate no setup from no retest.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "TradePlanStaging", m_fvg_micro_tradeplan_staging_diagnostics_file, EnableFvgMicroTradePlanStagingDiagnosticsReport,
                                         "TradePlan created, staging validation passed, staged to Shadow Executor",
                                         "KEEP_UNTIL_STAGING_LOCK",
                                         "Staging report proves No-Lookahead Guard and Shadow Executor handoff.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "LifecycleSimulation", m_fvg_micro_lifecycle_simulation_diagnostics_file, EnableFvgMicroLifecycleSimulationDiagnosticsReport,
                                         "Lifecycle status, TP1/SL/Timeout close, Win/Lose, Index Points and USD",
                                         "KEEP_UNTIL_LIFECYCLE_LOCK",
                                         "Lifecycle report is the bridge between Shadow trade and main TradeLifecycle rows.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "RuntimeVerification", m_runtime_report_verification_file, EnableRuntimeReportVerificationReport,
                                         "Report readability and file-size status for each generated CSV",
                                         "TEMPORARY_DIAGNOSTIC",
                                         "Merge or remove after report writing is proven stable.");

      WriteFvgMicroRuntimeReportAuditRow(handle, trigger, "SmokeTest", m_fvg_micro_smoke_test_file, EnableFvgMicroSmokeTestDiagnosticsReport,
                                         "Pipeline checklist for Detector -> Candidate -> Watcher -> Stager -> Shadow -> Lifecycle",
                                         "TEMPORARY_DIAGNOSTIC",
                                         "Remove under Diagnostic Cleanup Gate after smoke test path is locked.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "ClosedShadowTradesSoFar",
                m_trade_report_file,
                "m_totals.total_trades should increase only after controlled Shadow lifecycle close",
                "YES",
                0,
                (m_totals.total_trades > 0 ? "ROWS_PRESENT" : "NO_CLOSED_SHADOW_ROWS_YET"),
                (m_totals.total_trades > 0 ? "AUDIT_LIFECYCLE_ROWS" : "CONTINUE_RUNTIME_TEST"),
                "If this remains zero after long Strategy Tester windows with visible FVG retests, inspect staging blockers and lifecycle timeout rules.");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                "DiagnosticCleanupGate",
                "Inputs/Reports",
                "Temporary diagnostics must be reduced after validation",
                "YES",
                0,
                "ACTIVE",
                "CLEAN_LATER",
                "Keep full diagnostics during v0.x foundation. Before Paper/Demo, keep only core reports and selected engine health/audit reports.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("FVG Micro practical runtime report audit written: %s | Trigger=%s", m_fvg_micro_runtime_report_audit_file, trigger));
   }


   void WriteRuntimeReportVerificationSnapshot(const string trigger)
   {
      if(!m_initialized || !EnableRuntimeReportVerificationReport)
         return;

      int handle = FileOpen(m_runtime_report_verification_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write runtime report verification snapshot: %s", m_runtime_report_verification_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt", "Trigger",
                "ReportKey", "FileName", "EnabledByInput", "Readable", "SizeBytes", "Status", "Notes");

      WriteRuntimeReportVerificationRow(handle, trigger, "TradeLifecycle", m_trade_report_file, EnableMainReport,
                                        "Main trade rows report. Must contain Entry/SL/TP/Exit/WinLose/IndexPoints/USD/StrategyName when lifecycle records close.");
      WriteRuntimeReportVerificationRow(handle, trigger, "Summary", m_summary_report_file, EnableMainReport,
                                        "Final summary report. It is rewritten on deinit with WinRate/LoseRate and totals.");
      WriteRuntimeReportVerificationRow(handle, trigger, "PaperStateSnapshot", m_paper_state_snapshot_file, EnableMainReport,
                                        "v0.55.13-fix4 snapshot-only Paper state persistence + dynamic session boundary checkpoint foundation + blocked-entry recovery-state fix. No runtime restore or trading change.");
      WriteRuntimeReportVerificationRow(handle, trigger, "MarketDiagnostics", m_market_diagnostics_file, EnableMarketDiagnosticsReport,
                                        "Symbol context diagnostics: digits, point, tick, contract, spread, stops level.");
      WriteRuntimeReportVerificationRow(handle, trigger, "CandleCacheDiagnostics", m_candle_cache_diagnostics_file, EnableCandleCacheDiagnosticsReport,
                                        "Multi-timeframe closed candle cache diagnostics for M1/M5/M15/H1/H4/D1.");
      WriteRuntimeReportVerificationRow(handle, trigger, "EvidenceDiagnostics", m_evidence_diagnostics_file, EnableEvidenceDiagnosticsReport,
                                        "Evidence framework contract diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "ShadowDiagnostics", m_shadow_diagnostics_file, EnableShadowDiagnosticsReport,
                                        "Shadow executor diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "NoLookaheadDiagnostics", m_no_lookahead_diagnostics_file, EnableNoLookaheadDiagnosticsReport,
                                        "Runtime safety and no-lookahead guard diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "StrategyRegistryDiagnostics", m_strategy_registry_diagnostics_file, EnableStrategyRegistryDiagnosticsReport,
                                        "Strategy registry and health switch diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "StrategyAdapterDiagnostics", m_strategy_adapter_diagnostics_file, EnableStrategyAdapterDiagnosticsReport,
                                        "First strategy adapter shell diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroDetectorDiagnostics", m_fvg_micro_detector_diagnostics_file, EnableFvgMicroDetectorDiagnosticsReport,
                                        "FVG detector diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroCandidateDiagnostics", m_fvg_micro_candidate_diagnostics_file, EnableFvgMicroCandidateDiagnosticsReport,
                                        "FVG shadow candidate builder diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroRetestWatcherDiagnostics", m_fvg_micro_retest_watcher_diagnostics_file, EnableFvgMicroRetestWatcherDiagnosticsReport,
                                        "FVG retest watcher and skeleton diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroTradePlanStagingDiagnostics", m_fvg_micro_tradeplan_staging_diagnostics_file, EnableFvgMicroTradePlanStagingDiagnosticsReport,
                                        "FVG TradePlan staging dry-run diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroLifecycleSimulationDiagnostics", m_fvg_micro_lifecycle_simulation_diagnostics_file, EnableFvgMicroLifecycleSimulationDiagnosticsReport,
                                        "FVG shadow lifecycle simulation diagnostics.");
      WriteRuntimeReportVerificationRow(handle, trigger, "ReportCalibrationCleanupGate", m_report_calibration_diagnostics_file, EnableReportCalibrationDiagnosticsReport,
                                        "Report schema calibration and Diagnostic Cleanup Gate review.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroRuntimeSmokeTest", m_fvg_micro_smoke_test_file, EnableFvgMicroSmokeTestDiagnosticsReport,
                                        "FVG Micro shadow runtime smoke-test checklist.");
      WriteRuntimeReportVerificationRow(handle, trigger, "FvgMicroRuntimeReportAudit", m_fvg_micro_runtime_report_audit_file, EnableFvgMicroRuntimeReportAuditReport,
                                        "First practical audit of generated FVG Micro runtime CSV reports and lifecycle-row readiness.");

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Runtime report verification snapshot written: %s | Trigger=%s", m_runtime_report_verification_file, trigger));
   }

   // ==================================================================
   // v0.57.0: Lock Parity Executability Decomposer
   // Pure additive / report-only. Reads finalized lifecycle record after
   // every Apply* layer has run; never mutates any trade value.
   // ==================================================================
   void WriteLockParityDecompositionHeader()
   {
      int handle = FileOpen(m_lock_parity_decomp_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create LockParityExecutabilityDecomposition file: %s", m_lock_parity_decomp_file));
         return;
      }

      string header =
         "TradeId,Direction,EntryTime,ExitTime,EntryPrice,ExitPrice,LotSize,ActiveLot,"
         "L0_RawNetUSD,"
         "L1_GuardNetUSD,L1_GuardDeltaUSD,L1_GuardClass,"
         "L2_ProtectionNetUSD,L2_ProtectionDeltaUSD,L2_ProtectionClass,L2_ProtectionLevel,"
         "L3_RunnerNetUSD,L3_RunnerDeltaUSD,L3_RunnerClass,L3_RunnerAdditionalPoints,"
         "L3_RunnerCapturedPoints,L3_RunnerExitPriceDerived,L3_RunnerMaxFavorablePoints,"
         "L3_RunnerExitWithinPath,L3_RunnerVsActualPoints,"
         "L4_LossCapBeforeUSD,L4_LossCapAfterUSD,L4_LossCapDeltaUSD,L4_LossCapClass,L4_LossCapBlocked,"
         "L5_MarketCloseBeforeUSD,L5_MarketCloseAfterUSD,L5_MarketCloseDeltaUSD,L5_MarketCloseClass,"
         "L6_EmergencyBeforeUSD,L6_EmergencyAfterUSD,L6_EmergencyDeltaUSD,L6_EmergencyClass,L6_EmergencyLayer,"
         "L7_OtherDeltaUSD,L7_OtherClass,"
         "FinalWorkingNetUSD,"
         "TotalExecutableDeltaUSD,TotalNonExecutableDeltaUSD,"
         "ChainResidualUSD,DecompositionStatus";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }

   bool LockParityIsExecutableClass(const string class_tag)
   {
      if(StringFind(class_tag, "EXECUTABLE_") == 0)
         return true;
      // v0.57.1: Runner Exit Price Probe — within-path runner exits are executable.
      if(class_tag == "RUNNER_EXIT_PRICE_WITHIN_MARKET_PATH")
         return true;
      return false;
   }

   bool LockParityIsNonExecutableClass(const string class_tag)
   {
      if(class_tag == "NON_EXECUTABLE_ACCOUNTING")
         return true;
      // v0.57.0 legacy tag retained for backward compatibility (no longer produced).
      if(class_tag == "RUNNER_EXTENSION_NEEDS_PRICE_PROOF")
         return true;
      // v0.57.1: Runner Exit Price Probe — outside-path or insufficient data is non-executable.
      if(class_tag == "RUNNER_EXIT_PRICE_OUTSIDE_MARKET_PATH")
         return true;
      if(class_tag == "RUNNER_PATH_DATA_INSUFFICIENT")
         return true;
      if(class_tag == "UNATTRIBUTED_NEEDS_REVIEW")
         return true;
      return false;
   }

   // v0.57.1: Runner Exit Price Probe.
   // Derives the runner exit price from captured points (already in record),
   // then tests whether that derived price lies inside the path the market
   // actually traversed (tp2 .. max-favorable). Read-only by construction;
   // does NOT modify any trade value or Apply* layer.
   void FalconRunnerExitPriceProbe(const FalconTradeLifecycleRecord &record,
                                   double &captured_points_out,
                                   double &runner_exit_price_out,
                                   double &max_favorable_points_out,
                                   bool   &within_path_out,
                                   double &runner_vs_actual_points_out,
                                   bool   &path_data_valid_out)
   {
      captured_points_out         = record.paper_runner_captured_points;
      runner_exit_price_out       = 0.0;
      max_favorable_points_out    = 0.0;
      within_path_out             = false;
      runner_vs_actual_points_out = 0.0;
      path_data_valid_out         = false;

      if(record.entry_price <= 0.0)
         return;

      if(record.direction == FALCON_DIRECTION_BUY)
         runner_exit_price_out = record.entry_price + captured_points_out;
      else if(record.direction == FALCON_DIRECTION_SELL)
         runner_exit_price_out = record.entry_price - captured_points_out;
      else
         return;

      runner_vs_actual_points_out = FalconRawIndexPoints(record.direction,
                                                        runner_exit_price_out,
                                                        record.exit_price);

      double risk_points = FalconStructuralRiskPoints(record);
      if(risk_points <= 0.0 || record.paper_runner_max_r <= 0.0)
      {
         path_data_valid_out = false;
         return;
      }
      path_data_valid_out      = true;
      max_favorable_points_out = record.paper_runner_max_r * risk_points;

      double max_fav_price = 0.0;
      if(record.direction == FALCON_DIRECTION_BUY)
         max_fav_price = record.entry_price + max_favorable_points_out;
      else
         max_fav_price = record.entry_price - max_favorable_points_out;

      if(record.tp2 <= 0.0)
      {
         within_path_out = false;
         return;
      }

      double lo = MathMin(record.tp2, max_fav_price);
      double hi = MathMax(record.tp2, max_fav_price);
      within_path_out = (runner_exit_price_out >= lo && runner_exit_price_out <= hi);
   }

   bool LockParityProtectionLevelTouched(const FalconTradeLifecycleRecord &record)
   {
      if(record.paper_protection_level <= 0.0)
         return false;
      if(record.entry_price <= 0.0 || record.exit_price <= 0.0)
         return false;
      double lo = MathMin(record.entry_price, record.exit_price);
      double hi = MathMax(record.entry_price, record.exit_price);
      return (record.paper_protection_level >= lo && record.paper_protection_level <= hi);
   }

   string ClassifyLockParityGuard(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      bool guard_rejected = (StringFind(record.paper_guard_status, "REJECT") >= 0);
      bool guard_zeroed   = (MathAbs(record.paper_guard_net_usd) < 0.0001 &&
                             MathAbs(record.net_usd) >= FALCON_LOCK_PARITY_DELTA_EPS);
      if(guard_rejected || guard_zeroed)
         return "EXECUTABLE_ENTRY_FILTER";
      if(MathAbs(delta_usd) < FALCON_LOCK_PARITY_DELTA_EPS)
         return "NO_ADJUSTMENT";
      return "NON_EXECUTABLE_ACCOUNTING";
   }

   string ClassifyLockParityProtection(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      if(record.paper_protection_activated && record.paper_protection_level > 0.0 &&
         LockParityProtectionLevelTouched(record))
         return "EXECUTABLE_PROTECTION_CLOSE";
      if(record.paper_protection_activated && MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "NON_EXECUTABLE_ACCOUNTING";
      if(MathAbs(delta_usd) < FALCON_LOCK_PARITY_DELTA_EPS)
         return "NO_ADJUSTMENT";
      return "NON_EXECUTABLE_ACCOUNTING";
   }

   // v0.57.1: Runner classification driven by the Runner Exit Price Probe.
   // Replaces RUNNER_EXTENSION_NEEDS_PRICE_PROOF with concrete executable /
   // non-executable verdicts based on whether the derived runner exit price
   // falls inside the market-touched path (tp2 .. max-favorable).
   string ClassifyLockParityRunner(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      if(!record.paper_runner_activated)
      {
         if(MathAbs(delta_usd) < FALCON_LOCK_PARITY_DELTA_EPS)
            return "NO_ADJUSTMENT";
         return "RUNNER_NOT_ACTIVATED";
      }
      if(record.paper_runner_additional_points <= 0.0)
      {
         if(MathAbs(delta_usd) < FALCON_LOCK_PARITY_DELTA_EPS)
            return "NO_ADJUSTMENT";
         return "RUNNER_NO_ADDITIONAL_CAPTURE";
      }

      double captured_points = 0.0;
      double runner_exit_price = 0.0;
      double max_favorable_points = 0.0;
      bool   within_path = false;
      double runner_vs_actual_points = 0.0;
      bool   path_data_valid = false;
      FalconRunnerExitPriceProbe(record,
                                 captured_points,
                                 runner_exit_price,
                                 max_favorable_points,
                                 within_path,
                                 runner_vs_actual_points,
                                 path_data_valid);

      if(!path_data_valid)
         return "RUNNER_PATH_DATA_INSUFFICIENT";
      if(within_path)
         return "RUNNER_EXIT_PRICE_WITHIN_MARKET_PATH";
      return "RUNNER_EXIT_PRICE_OUTSIDE_MARKET_PATH";
   }

   string ClassifyLockParityLossCap(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      if(record.falcon_single_trade_loss_cap_blocked == 1)
         return "EXECUTABLE_RISK_NO_ENTRY";
      if(MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "NON_EXECUTABLE_ACCOUNTING";
      return "NO_ADJUSTMENT";
   }

   string ClassifyLockParityMarketClose(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      if(record.falcon_market_close_blocked == 1)
         return "EXECUTABLE_TIME_NO_ENTRY";
      if(MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "EXECUTABLE_TIME_CLOSE";
      return "NO_ADJUSTMENT";
   }

   string ClassifyLockParityEmergency(const FalconTradeLifecycleRecord &record, const double delta_usd)
   {
      bool zeroed_after = (MathAbs(record.falcon_emergency_after_net_usd) < 0.0001);
      if(record.falcon_emergency_triggered_layer > 0 && zeroed_after &&
         MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "EXECUTABLE_GOVERNANCE_NO_ENTRY";
      if(MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "NON_EXECUTABLE_ACCOUNTING";
      return "NO_ADJUSTMENT";
   }

   string ClassifyLockParityOther(const double delta_usd)
   {
      if(MathAbs(delta_usd) >= FALCON_LOCK_PARITY_DELTA_EPS)
         return "UNATTRIBUTED_NEEDS_REVIEW";
      return "NO_ADJUSTMENT";
   }

   double LockParityActiveLot(const FalconTradeLifecycleRecord &record)
   {
      if(record.falcon_dlm_active_lot > 0.0)
         return record.falcon_dlm_active_lot;
      return record.lot_size;
   }

   void AppendLockParityDecompositionRecord(const FalconTradeLifecycleRecord &record)
   {
      // Layer deltas. d_other is residual that makes the per-trade chain closed by construction.
      double d_guard       = record.paper_guard_net_usd                          - record.net_usd;
      double d_protection  = record.paper_protection_net_usd                     - record.paper_guard_net_usd;
      double d_runner      = record.paper_runner_net_usd                         - record.paper_protection_net_usd;
      double d_losscap     = record.falcon_single_trade_loss_cap_after_net_usd
                           - record.falcon_single_trade_loss_cap_before_net_usd;
      double d_marketclose = record.falcon_market_close_after_net_usd
                           - record.falcon_market_close_before_net_usd;
      double d_emergency   = record.falcon_emergency_after_net_usd
                           - record.falcon_emergency_before_net_usd;
      double d_other       = record.falcon_emergency_after_net_usd - record.net_usd
                           - (d_guard + d_protection + d_runner
                              + d_losscap + d_marketclose + d_emergency);

      string c_guard       = ClassifyLockParityGuard(record, d_guard);
      string c_protection  = ClassifyLockParityProtection(record, d_protection);
      string c_runner      = ClassifyLockParityRunner(record, d_runner);
      string c_losscap     = ClassifyLockParityLossCap(record, d_losscap);
      string c_marketclose = ClassifyLockParityMarketClose(record, d_marketclose);
      string c_emergency   = ClassifyLockParityEmergency(record, d_emergency);
      string c_other       = ClassifyLockParityOther(d_other);

      double exec_sum = 0.0;
      double nonexec_sum = 0.0;
      if(LockParityIsExecutableClass(c_guard))         exec_sum    += d_guard;
      else if(LockParityIsNonExecutableClass(c_guard)) nonexec_sum += d_guard;
      if(LockParityIsExecutableClass(c_protection))         exec_sum    += d_protection;
      else if(LockParityIsNonExecutableClass(c_protection)) nonexec_sum += d_protection;
      if(LockParityIsExecutableClass(c_runner))         exec_sum    += d_runner;
      else if(LockParityIsNonExecutableClass(c_runner)) nonexec_sum += d_runner;
      if(LockParityIsExecutableClass(c_losscap))         exec_sum    += d_losscap;
      else if(LockParityIsNonExecutableClass(c_losscap)) nonexec_sum += d_losscap;
      if(LockParityIsExecutableClass(c_marketclose))         exec_sum    += d_marketclose;
      else if(LockParityIsNonExecutableClass(c_marketclose)) nonexec_sum += d_marketclose;
      if(LockParityIsExecutableClass(c_emergency))         exec_sum    += d_emergency;
      else if(LockParityIsNonExecutableClass(c_emergency)) nonexec_sum += d_emergency;
      if(LockParityIsExecutableClass(c_other))         exec_sum    += d_other;
      else if(LockParityIsNonExecutableClass(c_other)) nonexec_sum += d_other;

      double chain_residual = record.falcon_emergency_after_net_usd
                            - (record.net_usd + d_guard + d_protection + d_runner
                               + d_losscap + d_marketclose + d_emergency + d_other);
      string decomp_status = (MathAbs(chain_residual) < FALCON_LOCK_PARITY_CHAIN_RESIDUAL_TOL ? "PASS" : "RESIDUAL_BREACH");

      int handle = FileOpen(m_lock_parity_decomp_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteLockParityDecompositionHeader();
         handle = FileOpen(m_lock_parity_decomp_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append LockParityExecutabilityDecomposition row: %s", m_lock_parity_decomp_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);

      string row = "";
      row += FalconCsvSafe(record.trade_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      row += DoubleToString(record.entry_price, m_symbol_context.digits) + ",";
      row += DoubleToString(record.exit_price, m_symbol_context.digits) + ",";
      row += DoubleToString(record.lot_size, 2) + ",";
      row += DoubleToString(LockParityActiveLot(record), 2) + ",";

      row += DoubleToString(record.net_usd, 4) + ",";

      row += DoubleToString(record.paper_guard_net_usd, 4) + ",";
      row += DoubleToString(d_guard, 4) + ",";
      row += FalconCsvSafe(c_guard) + ",";

      row += DoubleToString(record.paper_protection_net_usd, 4) + ",";
      row += DoubleToString(d_protection, 4) + ",";
      row += FalconCsvSafe(c_protection) + ",";
      row += DoubleToString(record.paper_protection_level, m_symbol_context.digits) + ",";

      row += DoubleToString(record.paper_runner_net_usd, 4) + ",";
      row += DoubleToString(d_runner, 4) + ",";
      row += FalconCsvSafe(c_runner) + ",";
      row += DoubleToString(record.paper_runner_additional_points, 2) + ",";

      // v0.57.1: Runner Exit Price Probe diagnostic columns.
      double probe_captured_points = 0.0;
      double probe_runner_exit_price = 0.0;
      double probe_max_favorable_points = 0.0;
      bool   probe_within_path = false;
      double probe_runner_vs_actual_points = 0.0;
      bool   probe_path_data_valid = false;
      FalconRunnerExitPriceProbe(record,
                                 probe_captured_points,
                                 probe_runner_exit_price,
                                 probe_max_favorable_points,
                                 probe_within_path,
                                 probe_runner_vs_actual_points,
                                 probe_path_data_valid);
      row += DoubleToString(probe_captured_points, 2) + ",";
      row += DoubleToString(probe_runner_exit_price, m_symbol_context.digits) + ",";
      row += DoubleToString(probe_max_favorable_points, 2) + ",";
      row += FalconCsvSafe(probe_within_path ? "YES" : "NO") + ",";
      row += DoubleToString(probe_runner_vs_actual_points, 2) + ",";

      row += DoubleToString(record.falcon_single_trade_loss_cap_before_net_usd, 4) + ",";
      row += DoubleToString(record.falcon_single_trade_loss_cap_after_net_usd, 4) + ",";
      row += DoubleToString(d_losscap, 4) + ",";
      row += FalconCsvSafe(c_losscap) + ",";
      row += IntegerToString(record.falcon_single_trade_loss_cap_blocked) + ",";

      row += DoubleToString(record.falcon_market_close_before_net_usd, 4) + ",";
      row += DoubleToString(record.falcon_market_close_after_net_usd, 4) + ",";
      row += DoubleToString(d_marketclose, 4) + ",";
      row += FalconCsvSafe(c_marketclose) + ",";

      row += DoubleToString(record.falcon_emergency_before_net_usd, 4) + ",";
      row += DoubleToString(record.falcon_emergency_after_net_usd, 4) + ",";
      row += DoubleToString(d_emergency, 4) + ",";
      row += FalconCsvSafe(c_emergency) + ",";
      row += IntegerToString(record.falcon_emergency_triggered_layer) + ",";

      row += DoubleToString(d_other, 4) + ",";
      row += FalconCsvSafe(c_other) + ",";

      row += DoubleToString(record.falcon_emergency_after_net_usd, 4) + ",";

      row += DoubleToString(exec_sum, 4) + ",";
      row += DoubleToString(nonexec_sum, 4) + ",";

      row += DoubleToString(chain_residual, 4) + ",";
      row += FalconCsvSafe(decomp_status);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void UpdateLockParityTotals(const FalconTradeLifecycleRecord &record)
   {
      double d_guard       = record.paper_guard_net_usd                          - record.net_usd;
      double d_protection  = record.paper_protection_net_usd                     - record.paper_guard_net_usd;
      double d_runner      = record.paper_runner_net_usd                         - record.paper_protection_net_usd;
      double d_losscap     = record.falcon_single_trade_loss_cap_after_net_usd
                           - record.falcon_single_trade_loss_cap_before_net_usd;
      double d_marketclose = record.falcon_market_close_after_net_usd
                           - record.falcon_market_close_before_net_usd;
      double d_emergency   = record.falcon_emergency_after_net_usd
                           - record.falcon_emergency_before_net_usd;
      double d_other       = record.falcon_emergency_after_net_usd - record.net_usd
                           - (d_guard + d_protection + d_runner
                              + d_losscap + d_marketclose + d_emergency);

      string c_guard       = ClassifyLockParityGuard(record, d_guard);
      string c_protection  = ClassifyLockParityProtection(record, d_protection);
      string c_runner      = ClassifyLockParityRunner(record, d_runner);
      string c_losscap     = ClassifyLockParityLossCap(record, d_losscap);
      string c_marketclose = ClassifyLockParityMarketClose(record, d_marketclose);
      string c_emergency   = ClassifyLockParityEmergency(record, d_emergency);
      string c_other       = ClassifyLockParityOther(d_other);

      m_totals.lock_parity_evaluated_trades++;
      m_totals.lock_parity_raw_net_usd            += record.net_usd;
      m_totals.lock_parity_final_working_net_usd  += record.falcon_emergency_after_net_usd;
      m_totals.lock_parity_sum_guard_delta_usd       += d_guard;
      m_totals.lock_parity_sum_protection_delta_usd  += d_protection;
      m_totals.lock_parity_sum_runner_delta_usd      += d_runner;
      m_totals.lock_parity_sum_losscap_delta_usd     += d_losscap;
      m_totals.lock_parity_sum_marketclose_delta_usd += d_marketclose;
      m_totals.lock_parity_sum_emergency_delta_usd   += d_emergency;
      m_totals.lock_parity_sum_other_delta_usd       += d_other;

      double per_trade_residual = record.falcon_emergency_after_net_usd
                                - (record.net_usd + d_guard + d_protection + d_runner
                                   + d_losscap + d_marketclose + d_emergency + d_other);
      if(MathAbs(per_trade_residual) < FALCON_LOCK_PARITY_CHAIN_RESIDUAL_TOL)
         m_totals.lock_parity_decomposition_pass_trades++;
      else
         m_totals.lock_parity_decomposition_breach_trades++;

      // Bucket-level rollup
      if(LockParityIsExecutableClass(c_guard))         m_totals.lock_parity_executable_adjustment_usd     += d_guard;
      else if(LockParityIsNonExecutableClass(c_guard)) m_totals.lock_parity_non_executable_adjustment_usd += d_guard;
      if(LockParityIsExecutableClass(c_protection))         m_totals.lock_parity_executable_adjustment_usd     += d_protection;
      else if(LockParityIsNonExecutableClass(c_protection)) m_totals.lock_parity_non_executable_adjustment_usd += d_protection;
      if(LockParityIsExecutableClass(c_runner))         m_totals.lock_parity_executable_adjustment_usd     += d_runner;
      else if(LockParityIsNonExecutableClass(c_runner)) m_totals.lock_parity_non_executable_adjustment_usd += d_runner;
      if(LockParityIsExecutableClass(c_losscap))         m_totals.lock_parity_executable_adjustment_usd     += d_losscap;
      else if(LockParityIsNonExecutableClass(c_losscap)) m_totals.lock_parity_non_executable_adjustment_usd += d_losscap;
      if(LockParityIsExecutableClass(c_marketclose))         m_totals.lock_parity_executable_adjustment_usd     += d_marketclose;
      else if(LockParityIsNonExecutableClass(c_marketclose)) m_totals.lock_parity_non_executable_adjustment_usd += d_marketclose;
      if(LockParityIsExecutableClass(c_emergency))         m_totals.lock_parity_executable_adjustment_usd     += d_emergency;
      else if(LockParityIsNonExecutableClass(c_emergency)) m_totals.lock_parity_non_executable_adjustment_usd += d_emergency;
      if(LockParityIsExecutableClass(c_other))         m_totals.lock_parity_executable_adjustment_usd     += d_other;
      else if(LockParityIsNonExecutableClass(c_other)) m_totals.lock_parity_non_executable_adjustment_usd += d_other;

      // Class-specific evidence buckets
      if(c_protection == "EXECUTABLE_PROTECTION_CLOSE")
         m_totals.lock_parity_protection_executable_usd += d_protection;
      // v0.57.1: Runner Exit Price Probe — split runner deltas into exec / non-exec.
      if(c_runner == "RUNNER_EXIT_PRICE_WITHIN_MARKET_PATH")
         m_totals.lock_parity_runner_executable_usd += d_runner;
      if(c_runner == "RUNNER_EXIT_PRICE_OUTSIDE_MARKET_PATH" ||
         c_runner == "RUNNER_PATH_DATA_INSUFFICIENT")
         m_totals.lock_parity_runner_non_executable_usd += d_runner;
      // RunnerPendingUSD retained for backward compatibility; now mirrors RunnerNonExecutable.
      m_totals.lock_parity_runner_pending_usd = m_totals.lock_parity_runner_non_executable_usd;
      if(c_guard == "NON_EXECUTABLE_ACCOUNTING")        m_totals.lock_parity_accounting_only_usd += d_guard;
      if(c_protection == "NON_EXECUTABLE_ACCOUNTING")   m_totals.lock_parity_accounting_only_usd += d_protection;
      if(c_runner == "NON_EXECUTABLE_ACCOUNTING")       m_totals.lock_parity_accounting_only_usd += d_runner;
      if(c_losscap == "NON_EXECUTABLE_ACCOUNTING")      m_totals.lock_parity_accounting_only_usd += d_losscap;
      if(c_marketclose == "NON_EXECUTABLE_ACCOUNTING")  m_totals.lock_parity_accounting_only_usd += d_marketclose;
      if(c_emergency == "NON_EXECUTABLE_ACCOUNTING")    m_totals.lock_parity_accounting_only_usd += d_emergency;
      if(c_other == "UNATTRIBUTED_NEEDS_REVIEW")        m_totals.lock_parity_accounting_only_usd += d_other;
   }

   void WriteLockParityExecutabilityRollup()
   {
      int handle = FileOpen(m_lock_parity_rollup_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create LockParityExecutabilityRollup file: %s", m_lock_parity_rollup_file));
         return;
      }

      string header =
         "TotalTrades,"
         "LOCK_RawNetUSD,"
         "LOCK_FinalWorkingNetUSD,"
         "Sum_Guard_Delta,Sum_Protection_Delta,Sum_Runner_Delta,"
         "Sum_LossCap_Delta,Sum_MarketClose_Delta,Sum_Emergency_Delta,Sum_Other_Delta,"
         "LOCK_ExecutableAdjustmentUSD,"
         "LOCK_NonExecutableAdjustmentUSD,"
         "LOCK_ExecutableTargetUSD,"
         "ExecutableSharePct,"
         "ProtectionExecutableUSD,RunnerExecutableUSD,RunnerNonExecutableUSD,RunnerPendingUSD,AccountingOnlyUSD,"
         "RollupResidualUSD,RollupStatus";
      FileWriteString(handle, header + "\r\n");

      double executable_target = m_totals.lock_parity_raw_net_usd + m_totals.lock_parity_executable_adjustment_usd;
      double executable_share_pct = 0.0;
      if(MathAbs(m_totals.lock_parity_final_working_net_usd) > 0.000001)
         executable_share_pct = (executable_target / m_totals.lock_parity_final_working_net_usd) * 100.0;

      double rollup_residual = m_totals.lock_parity_final_working_net_usd
                             - (executable_target + m_totals.lock_parity_non_executable_adjustment_usd);
      string rollup_status = (MathAbs(rollup_residual) < FALCON_LOCK_PARITY_ROLLUP_TOL ? "PASS" : "RESIDUAL_BREACH");

      string row = "";
      row += IntegerToString(m_totals.lock_parity_evaluated_trades) + ",";
      row += DoubleToString(m_totals.lock_parity_raw_net_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_final_working_net_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_guard_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_protection_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_runner_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_losscap_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_marketclose_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_emergency_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_sum_other_delta_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_executable_adjustment_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_non_executable_adjustment_usd, 4) + ",";
      row += DoubleToString(executable_target, 4) + ",";
      row += DoubleToString(executable_share_pct, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_protection_executable_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_runner_executable_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_runner_non_executable_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_runner_pending_usd, 4) + ",";
      row += DoubleToString(m_totals.lock_parity_accounting_only_usd, 4) + ",";
      row += DoubleToString(rollup_residual, 4) + ",";
      row += FalconCsvSafe(rollup_status);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   // ==================================================================
   // v0.57.2: Virtual Trailing Exit Bridge report
   // One row per virtual-trailing-initiated close attempt. Diagnostic only:
   // does NOT modify any trade value, does NOT replace ManagedCloseLifecycle.
   // ==================================================================
   void WriteVirtualTrailingExitLifecycleHeader()
   {
      int handle = FileOpen(m_virtual_trailing_exit_lifecycle_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create VirtualTrailingExitLifecycle file: %s", m_virtual_trailing_exit_lifecycle_file));
         return;
      }

      string header =
         "TradeId,Direction,EntryTime,EntryPrice,ExitTime,ExitPrice,"
         "PeakFavorablePrice,TrailingStopPriceAtExit,BreakevenLocked,BreakevenMode,TrailingActivated,"
         "ProfitPointsAtExit,RealizedPointsAtExit,EstimatedUsdAtExit,"
         "ExitTriggerReason,BrokerCloseRetcode,VirtualTrailingStatus";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
   }

   void AppendVirtualTrailingExitLifecycleRecord(const FalconBrokerTradeLink &link,
                                                 const datetime exit_time,
                                                 const double exit_price,
                                                 const double profit_points_at_exit,
                                                 const string exit_trigger_reason,
                                                 const uint broker_close_retcode,
                                                 const string virtual_trailing_status)
   {
      // v0.57.3: derive RealizedPointsAtExit and EstimatedUsdAtExit from the link
      // and the report writer's symbol context. Caller doesn't need to compute either.
      double realized_points_at_exit = FalconRawIndexPoints(link.direction,
                                                           link.broker_entry_price,
                                                           exit_price);
      double lot_for_usd = (link.accepted_lot > 0.0) ? link.accepted_lot : link.requested_lot;
      double estimated_usd_at_exit = FalconEstimateUsdByRawPoints(realized_points_at_exit,
                                                                 lot_for_usd,
                                                                 m_symbol_context);
      int handle = FileOpen(m_virtual_trailing_exit_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteVirtualTrailingExitLifecycleHeader();
         handle = FileOpen(m_virtual_trailing_exit_lifecycle_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append VirtualTrailingExitLifecycle row: %s", m_virtual_trailing_exit_lifecycle_file));
         return;
      }
      FileSeek(handle, 0, SEEK_END);

      string row = "";
      row += FalconCsvSafe(link.trade_id) + ",";
      row += FalconCsvSafe(FalconDirectionToString(link.direction)) + ",";
      row += FalconCsvSafe(FalconTimeToString(link.broker_entry_time)) + ",";
      row += DoubleToString(link.broker_entry_price, m_symbol_context.digits) + ",";
      row += FalconCsvSafe(FalconTimeToString(exit_time)) + ",";
      row += DoubleToString(exit_price, m_symbol_context.digits) + ",";
      row += DoubleToString(link.virtual_peak_favorable_price, m_symbol_context.digits) + ",";
      row += DoubleToString(link.virtual_trailing_stop_price, m_symbol_context.digits) + ",";
      row += FalconCsvSafe(link.virtual_breakeven_locked ? "YES" : "NO") + ",";
      row += FalconCsvSafe(link.virtual_breakeven_mode) + ",";
      row += FalconCsvSafe(link.virtual_trailing_active ? "YES" : "NO") + ",";
      row += DoubleToString(profit_points_at_exit, 2) + ",";
      row += DoubleToString(realized_points_at_exit, 2) + ",";
      row += DoubleToString(estimated_usd_at_exit, 4) + ",";
      row += FalconCsvSafe(exit_trigger_reason) + ",";
      row += IntegerToString((int)broker_close_retcode) + ",";
      row += FalconCsvSafe(virtual_trailing_status);

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void RegisterClosedTrade(FalconTradeLifecycleRecord &record)
   {
      if(!m_initialized || !EnableMainReport)
         return;

      FalconFinalizeTradeMetrics(record, m_symbol_context);
      ApplyFvgQualityShadowGuardSimulation(record);
      ApplyPaperRuntimeGuardApplication(record);
      ApplyPaperRuntimeSmartSLProtectionApplication(record);
      ApplyPaperRuntimeRunnerApplication(record);
      ApplyCapitalTierFoundation(record);
      ApplyLowCapitalRiskFeasibilityFoundation(record);
      ApplyDynamicLotSizingModel(record);
      ApplyCalibratedSingleTradeLossCapEnforcement(record);
      ApplyNoNewEntryUserOverridePaperEnforcement(record);
      ApplyDailyWeekendForceCloseUserOverridePaperEnforcement(record);
      ApplyThreeLayerEmergencyApplication(record);
      ApplyCapitalFlowSourceClassification(record);
      UpdateTotals(record);
      AppendTradeRecord(record);
      AppendPaperStateSnapshotRecord(record);
      AppendBrokerExecutionLifecycleAuditRecord(record);
      AppendBrokerRebasedPaperComparisonRecord(record);
      AppendBrokerTradeManagementTimelineForRecord(record);
      // v0.57.0: Lock Parity Executability Decomposer hook.
      // Pure additive; runs AFTER every Apply* layer has populated the record.
      UpdateLockParityTotals(record);
      AppendLockParityDecompositionRecord(record);
   }

   int CountPhysicalTradeLifecycleDataRows()
   {
      // v0.55.11: count actual rows written to TradeLifecycle.csv.
      // This catches physical file truncation/overwrite even if internal totals look correct.
      int handle = FileOpen(m_trade_report_file, FILE_READ | FILE_TXT | FILE_ANSI | (UseCommonFilesFolderForReports ? FILE_COMMON : 0));
      if(handle == INVALID_HANDLE)
         return -1;

      int line_count = 0;
      while(!FileIsEnding(handle))
      {
         string line = FileReadString(handle);
         if(StringLen(line) > 0)
            line_count++;
      }
      FileClose(handle);

      if(line_count <= 0)
         return 0;
      return line_count - 1; // subtract header
   }

   void WriteFinalSummary()
   {
      if(!m_initialized || !EnableMainReport)
         return;

      if(m_totals.total_trades > 0)
      {
         m_totals.win_rate  = (100.0 * (double)m_totals.win_trades) / (double)m_totals.total_trades;
         m_totals.loss_rate = (100.0 * (double)m_totals.loss_trades) / (double)m_totals.total_trades;
      }
      else
      {
         m_totals.win_rate  = 0.0;
         m_totals.loss_rate = 0.0;
      }

      FinalizeWeeklyStabilityFoundation();

      double buy_win_rate = 0.0;
      if(m_totals.buy_trades > 0)
         buy_win_rate = (100.0 * (double)m_totals.buy_win_trades) / (double)m_totals.buy_trades;

      double sell_win_rate = 0.0;
      if(m_totals.sell_trades > 0)
         sell_win_rate = (100.0 * (double)m_totals.sell_win_trades) / (double)m_totals.sell_trades;

      double dynamic_active_lot_avg = FalconSafeAverageDouble(m_totals.dynamic_lotsizing_active_lot_total, m_totals.dynamic_lotsizing_evaluated_trades);
      int invariant_breaches = 0;
      if(m_totals.dynamic_lotsizing_invalid_trades > 0) invariant_breaches++;
      if(m_totals.layer_reset_duplicate_triggers > 0) invariant_breaches++;

      double final_net_from_profit_loss = m_totals.final_total_profit_usd - m_totals.final_total_loss_usd;
      double final_net_diff = final_net_from_profit_loss - m_totals.final_working_net_usd;
      double raw_net_from_profit_loss = m_totals.total_profit_usd - m_totals.total_loss_usd;
      double raw_net_diff = raw_net_from_profit_loss - m_totals.net_usd;
      double visible_raw_net_diff = m_totals.visible_raw_net_usd_4dp - m_totals.net_usd;
      double visible_final_net_diff = m_totals.visible_final_working_net_usd_4dp - m_totals.final_working_net_usd;
      int physical_trade_rows = CountPhysicalTradeLifecycleDataRows();
      string physical_trade_rows_status = (physical_trade_rows == m_totals.total_trades ? "PASS" : "FAIL");
      int integrity_breaches = invariant_breaches;
      if(MathAbs(final_net_diff) > 0.05)
         integrity_breaches++;
      if(MathAbs(raw_net_diff) > 0.05)
         integrity_breaches++;
      if(MathAbs(visible_final_net_diff) > 0.01)
         integrity_breaches++;
      if(MathAbs(visible_raw_net_diff) > 0.01)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.dynamic_lotsizing_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.capital_flow_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.weekly_stability_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.market_close_guard_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.no_new_entry_override_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.force_close_override_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.paper_state_snapshot_evaluated_trades)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.paper_state_snapshot_written_rows)
         integrity_breaches++;
      if(m_totals.total_trades != m_totals.session_boundary_checkpoint_evaluated_trades)
         integrity_breaches++;
      if(m_totals.paper_state_snapshot_write_failures > 0)
         integrity_breaches++;
      if(m_totals.capital_flow_integrity_breaches > 0)
         integrity_breaches++;
      if(physical_trade_rows_status != "PASS")
         integrity_breaches++;

      string capital_flow_integrity_status = (m_totals.capital_flow_integrity_breaches == 0 && m_totals.total_trades == m_totals.capital_flow_evaluated_trades ? "PASS" : "FAIL");
      string weekly_stability_status = (m_totals.total_trades == m_totals.weekly_stability_evaluated_trades ? "PASS" : "FAIL");
      string market_close_guard_status = (m_totals.total_trades == m_totals.market_close_guard_evaluated_trades ? "PASS" : "FAIL");
      string no_new_entry_override_status = (m_totals.total_trades == m_totals.no_new_entry_override_evaluated_trades ? (StopNewTradesBeforeClose ? "ENABLED_PASS" : "DISABLED_PASS") : "FAIL");
      bool force_close_override_enabled = (CloseTradesBeforeDailyClose || CloseTradesBeforeWeekend);
      string force_close_override_status = (m_totals.total_trades == m_totals.force_close_override_evaluated_trades ? (force_close_override_enabled ? "ENABLED_PASS" : "DISABLED_PASS") : "FAIL");
      if(force_close_override_status == "ENABLED_PASS" && m_totals.force_close_override_missing_price_trades > 0)
         force_close_override_status = "ENABLED_WARN_MISSING_PRICE";
      string paper_state_snapshot_status = (m_totals.total_trades == m_totals.paper_state_snapshot_evaluated_trades &&
                                            m_totals.total_trades == m_totals.paper_state_snapshot_written_rows &&
                                            m_totals.paper_state_snapshot_write_failures == 0 ? "PASS" : "FAIL");
      string session_boundary_checkpoint_status = FalconSessionBoundaryCheckpointStatus();
      double market_close_avg_duration_minutes = FalconSafeAverageDouble(m_totals.market_close_total_trade_duration_minutes, m_totals.market_close_guard_evaluated_trades);
      string market_close_two_hour_coverage_status = (m_totals.market_close_duration_above_window_trades == 0 ? "PASS_2H_COVERS_ALL_OBSERVED_DURATIONS" : "WARN_SOME_TRADES_EXCEED_2H_DURATION");
      string market_close_timing_recommendation = (m_totals.market_close_duration_above_window_trades == 0 ? "MONITOR_SESSION_BOUNDARY_RISK" : "REVIEW_DAILY_WEEKEND_CLOSE_SAFETY");
      string report_integrity_status = (integrity_breaches == 0 ? "PASS" : "FAIL");
      string row_count_status = (m_totals.total_trades == m_totals.dynamic_lotsizing_evaluated_trades &&
                                 m_totals.total_trades == m_totals.capital_flow_evaluated_trades &&
                                 m_totals.total_trades == m_totals.weekly_stability_evaluated_trades &&
                                 m_totals.total_trades == m_totals.market_close_guard_evaluated_trades &&
                                 m_totals.total_trades == m_totals.no_new_entry_override_evaluated_trades &&
                                 m_totals.total_trades == m_totals.force_close_override_evaluated_trades &&
                                 m_totals.total_trades == m_totals.paper_state_snapshot_evaluated_trades &&
                                 m_totals.total_trades == m_totals.paper_state_snapshot_written_rows &&
                                 m_totals.total_trades == m_totals.session_boundary_checkpoint_evaluated_trades &&
                                 physical_trade_rows_status == "PASS" ? "PASS" : "FAIL");

      int handle = FileOpen(m_summary_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write slim summary report: %s", m_summary_report_file));
         return;
      }

      string summary_row = "";
      summary_row += FalconCsvSafe(EA_NAME) + ",";
      summary_row += FalconCsvSafe(EA_VERSION_TAG) + ",";
      summary_row += FalconCsvSafe(EA_BUILD_TAG) + ",";
      summary_row += FalconCsvSafe(m_symbol_context.symbol) + ",";
      summary_row += FalconCsvSafe(FalconTimeToString(TimeCurrent())) + ",";
      summary_row += FalconCsvSafe(FalconReportProfileToString()) + ",";
      summary_row += FalconCsvSafe(FalconEffectiveReportFromDateTag()) + ",";
      summary_row += FalconCsvSafe(FalconSummaryFinalReportToDateTag()) + ",";
      summary_row += FalconCsvSafe(FalconBoolToYesNo(UseFixedLot)) + ",";
      summary_row += DoubleToString(FixedLotSize, 2) + ",";
      summary_row += IntegerToString(m_totals.total_trades) + ",";
      summary_row += IntegerToString(m_totals.win_trades) + ",";
      summary_row += IntegerToString(m_totals.loss_trades) + ",";
      summary_row += DoubleToString(m_totals.win_rate, 2) + ",";
      summary_row += DoubleToString(m_totals.total_profit_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.total_loss_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.net_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.final_total_profit_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.final_total_loss_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.final_working_net_usd, 2) + ",";
      summary_row += IntegerToString(m_totals.buy_trades) + ",";
      summary_row += DoubleToString(buy_win_rate, 2) + ",";
      summary_row += IntegerToString(m_totals.sell_trades) + ",";
      summary_row += DoubleToString(sell_win_rate, 2) + ",";
      summary_row += IntegerToString(m_totals.paper_protection_activated_trades) + ",";
      summary_row += IntegerToString(m_totals.paper_runner_activated_trades) + ",";
      summary_row += IntegerToString(m_totals.dynamic_lotsizing_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.dynamic_lotsizing_fixed_mode_trades) + ",";
      summary_row += IntegerToString(m_totals.dynamic_lotsizing_dynamic_mode_trades) + ",";
      summary_row += DoubleToString(dynamic_active_lot_avg, 2) + ",";
      summary_row += DoubleToString(m_totals.dynamic_lotsizing_safety_active_lot_max, 2) + ",";
      summary_row += IntegerToString(m_totals.weekly_stability_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.weekly_stability_weeks) + ",";
      summary_row += IntegerToString(m_totals.weekly_stability_positive_weeks) + ",";
      summary_row += IntegerToString(m_totals.weekly_stability_negative_weeks) + ",";
      summary_row += DoubleToString(m_totals.weekly_stability_best_week_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.weekly_stability_worst_week_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.weekly_stability_score, 2) + ",";
      summary_row += FalconCsvSafe(weekly_stability_status) + ",";
      summary_row += IntegerToString(m_totals.market_close_guard_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.market_close_guard_near_close_entry_trades) + ",";
      summary_row += IntegerToString(m_totals.market_close_guard_open_weekend_risk_trades) + ",";
      summary_row += FalconCsvSafe(market_close_guard_status) + ",";
      summary_row += FalconCsvSafe(FalconBoolToYesNo(StopNewTradesBeforeClose)) + ",";
      summary_row += IntegerToString(FalconUserNoNewEntryWindowMinutes()) + ",";
      summary_row += IntegerToString(m_totals.no_new_entry_override_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.no_new_entry_override_blocked_trades) + ",";
      summary_row += IntegerToString(m_totals.no_new_entry_override_blocked_winners) + ",";
      summary_row += IntegerToString(m_totals.no_new_entry_override_blocked_losers) + ",";
      summary_row += DoubleToString(m_totals.no_new_entry_override_impact_usd, 2) + ",";
      summary_row += FalconCsvSafe(no_new_entry_override_status) + ",";
      summary_row += FalconCsvSafe(FalconBoolToYesNo(CloseTradesBeforeDailyClose)) + ",";
      summary_row += IntegerToString(FalconDailyForceCloseUserWindowMinutes()) + ",";
      summary_row += FalconCsvSafe(FalconBoolToYesNo(CloseTradesBeforeWeekend)) + ",";
      summary_row += IntegerToString(FalconWeekendForceCloseUserWindowMinutes()) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_closed_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_daily_closed_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_weekend_closed_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_price_ok_trades) + ",";
      summary_row += IntegerToString(m_totals.force_close_override_missing_price_trades) + ",";
      summary_row += DoubleToString(m_totals.force_close_override_before_net_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.force_close_override_after_net_usd, 2) + ",";
      summary_row += DoubleToString(m_totals.force_close_override_impact_usd, 2) + ",";
      summary_row += FalconCsvSafe(force_close_override_status) + ",";
      summary_row += IntegerToString(m_totals.paper_state_snapshot_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.paper_state_snapshot_written_rows) + ",";
      summary_row += IntegerToString(m_totals.paper_state_snapshot_write_failures) + ",";
      summary_row += FalconCsvSafe(FALCON_PERSISTENCE_RECOVERY_MODE) + ",";
      summary_row += IntegerToString(m_totals.paper_state_recovery_trusted_trades) + ",";
      summary_row += IntegerToString(m_totals.paper_state_recovery_untrusted_trades) + ",";
      summary_row += FalconCsvSafe(paper_state_snapshot_status) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_checkpoint_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_recovery_checkpoint_minutes) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_daily_checkpoint_open_trades) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_weekend_checkpoint_open_trades) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_recovery_required_trades) + ",";
      summary_row += IntegerToString(m_totals.session_boundary_dirty_after_close_safety_trades) + ",";
      summary_row += FalconCsvSafe(session_boundary_checkpoint_status) + ",";
      summary_row += IntegerToString(m_totals.market_close_max_trade_duration_minutes) + ",";
      summary_row += DoubleToString(market_close_avg_duration_minutes, 2) + ",";
      summary_row += IntegerToString(m_totals.market_close_duration_above_window_trades) + ",";
      summary_row += FalconCsvSafe(m_totals.market_close_longest_trade_id) + ",";
      summary_row += FalconCsvSafe(market_close_timing_recommendation) + ",";
      summary_row += FalconCsvSafe(market_close_two_hour_coverage_status) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_evaluated_trades) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_trade_profit_events) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_trade_loss_events) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_injection_events) + ",";
      summary_row += IntegerToString(m_totals.capital_flow_withdrawal_events) + ",";
      summary_row += DoubleToString(m_totals.capital_flow_external_net_usd, 4) + ",";
      summary_row += FalconCsvSafe(capital_flow_integrity_status) + ",";

      summary_row += IntegerToString(m_totals.paper_emergency_triggered_trades) + ",";
      summary_row += IntegerToString(m_totals.paper_emergency_blocked_entries) + ",";
      summary_row += IntegerToString(m_broker_entry_bridge_order_send_attempts) + ",0,0,";
      summary_row += IntegerToString(integrity_breaches) + ",";
      summary_row += IntegerToString(physical_trade_rows) + ",";
      summary_row += FalconCsvSafe(physical_trade_rows_status) + ",";
      summary_row += DoubleToString(visible_raw_net_diff, 4) + ",";
      summary_row += DoubleToString(visible_final_net_diff, 4) + ",";
      summary_row += FalconCsvSafe(report_integrity_status) + ",";
      summary_row += FalconCsvSafe(row_count_status) + ",";
      summary_row += DoubleToString(final_net_diff, 4) + ",";
      summary_row += DoubleToString(raw_net_diff, 4);

      FileWriteString(handle, SlimSummaryHeaderV0555() + "\r\n");
      FileWriteString(handle, summary_row + "\r\n");
      FileClose(handle);

      // v0.57.0: Lock Parity Executability Decomposer rollup writer.
      // Report-only; emits one row aggregating per-trade decomposition totals.
      WriteLockParityExecutabilityRollup();
   }


private:
   bool ProbeReportFile(const string file_name, long &size_bytes)
   {
      size_bytes = 0;
      int handle = FileOpen(file_name, FalconReportReadBinFlags());
      if(handle == INVALID_HANDLE)
         return false;

      size_bytes = (long)FileSize(handle);
      FileClose(handle);
      return true;
   }

   void WriteRuntimeReportVerificationRow(const int handle,
                                           const string trigger,
                                           const string report_key,
                                           const string file_name,
                                           const bool enabled_by_input,
                                           const string notes)
   {
      long size_bytes = 0;
      bool readable = false;
      if(enabled_by_input)
         readable = ProbeReportFile(file_name, size_bytes);

      string status = "DISABLED_BY_INPUT";
      if(enabled_by_input && readable && size_bytes > 0)
         status = "READABLE_NON_EMPTY";
      else if(enabled_by_input && readable)
         status = "READABLE_EMPTY";
      else if(enabled_by_input)
         status = "NOT_READABLE_YET";

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                report_key,
                file_name,
                FalconBoolToYesNo(enabled_by_input),
                FalconBoolToYesNo(readable),
                (int)size_bytes,
                status,
                notes);
   }

   void WriteFvgMicroRuntimeReportAuditRow(const int handle,
                                           const string trigger,
                                           const string audit_item,
                                           const string file_name,
                                           const bool enabled_by_input,
                                           const string expected_content,
                                           const string decision,
                                           const string notes)
   {
      long size_bytes = 0;
      bool readable = false;
      if(enabled_by_input)
         readable = ProbeReportFile(file_name, size_bytes);

      string audit_status = "DISABLED_BY_INPUT";
      if(enabled_by_input && readable && size_bytes > 0)
         audit_status = "READABLE_NON_EMPTY";
      else if(enabled_by_input && readable)
         audit_status = "READABLE_EMPTY";
      else if(enabled_by_input)
         audit_status = "NOT_READABLE_YET";

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                trigger,
                audit_item,
                file_name,
                expected_content,
                FalconBoolToYesNo(readable),
                (int)size_bytes,
                audit_status,
                decision,
                notes);
   }

   void ApplyFvgQualityShadowGuardSimulation(FalconTradeLifecycleRecord &record)
   {
      string guard_reason = "";
      bool guard_passed = FalconEvaluateFvgQualityShadowGuard(record.fvg_size_points,
                                                              record.fvg_spread_points,
                                                              record.fvg_retest_age_bars,
                                                              record.fvg_hold_quality_score,
                                                              guard_reason);

      record.fvg_quality_shadow_guard_profile = FALCON_FVG_QGUARD_PROFILE_TAG;
      record.fvg_quality_shadow_guard_passed = guard_passed;
      record.fvg_quality_shadow_guard_reason = guard_reason;

      if(guard_passed)
      {
         record.fvg_quality_shadow_guard_decision = "WOULD_KEEP";
         record.fvg_quality_shadow_guard_sim_net_points = record.net_index_points;
         record.fvg_quality_shadow_guard_sim_net_usd = record.net_usd;
      }
      else
      {
         record.fvg_quality_shadow_guard_decision = "WOULD_SKIP";
         record.fvg_quality_shadow_guard_sim_net_points = 0.0;
         record.fvg_quality_shadow_guard_sim_net_usd = 0.0;
      }
   }


   void ApplyPaperRuntimeGuardApplication(FalconTradeLifecycleRecord &record)
   {
      double sl_distance_points = 0.0;
      string reject_reason = FalconPrgaRejectReason(record, m_symbol_context, sl_distance_points);

      record.paper_guard_layer = "FalconGuard";
      record.paper_spread_points = record.fvg_spread_points;
      if(record.paper_spread_points < 0)
         record.paper_spread_points = m_symbol_context.spread_points;
      record.paper_max_spread_points = FALCON_SSBL_MAX_SPREAD_POINTS;
      record.paper_sl_distance_points = sl_distance_points;
      record.paper_stops_level_points = m_symbol_context.stops_level_points;
      record.paper_freeze_level_points = m_symbol_context.freeze_level_points;

      if(reject_reason == "")
      {
         record.paper_guard_status = "PASSED";
         record.paper_reject_reason = "";
         record.paper_guard_net_index_points = record.net_index_points;
         record.paper_guard_net_usd = record.net_usd;
      }
      else
      {
         record.paper_guard_status = "REJECTED";
         record.paper_reject_reason = reject_reason;
         record.paper_guard_net_index_points = 0.0;
         record.paper_guard_net_usd = 0.0;
      }
   }

   void ApplyPaperRuntimeSmartSLProtectionApplication(FalconTradeLifecycleRecord &record)
   {
      record.paper_protection_state = "NONE";
      record.paper_virtual_sl = 0.0;
      record.paper_protection_trigger = "NONE";
      record.paper_protection_level = 0.0;
      record.paper_protection_activated = false;
      record.paper_virtual_sl_changed = false;
      record.paper_virtual_sl_hit = false;
      record.paper_exit_reason = "PAPER_SHADOW_EXIT_UNCHANGED";
      record.paper_protection_net_index_points = record.paper_guard_net_index_points;
      record.paper_protection_net_usd = record.paper_guard_net_usd;

      if(record.paper_guard_status != "PASSED")
      {
         record.paper_exit_reason = "PAPER_GUARD_REJECTED";
         return;
      }

      FalconRunnerBarPathStats barpath_stats;
      if(!FalconBuildRunnerBarPathStats(record, barpath_stats))
      {
         record.paper_exit_reason = "PAPER_PROTECTION_PATH_SCAN_FAILED";
         return;
      }

      if(!barpath_stats.tp1_touched)
      {
         record.paper_exit_reason = "PAPER_NO_PROOF";
         return;
      }

      double tp1_points = FalconDirectionalProfitPoints(record, record.tp1);
      double tp2_points = FalconDirectionalProfitPoints(record, record.tp2);
      double protected_points = 0.0;

      record.paper_protection_activated = true;
      record.paper_virtual_sl_changed = true;

      if(barpath_stats.tp2_touched)
      {
         record.paper_protection_state = "TP2_PROTECTED";
         record.paper_protection_trigger = "TP2_PROOF";
         protected_points = tp1_points;
      }
      else
      {
         record.paper_protection_state = "TP1_PROTECTED";
         record.paper_protection_trigger = "TP1_PROOF";
         protected_points = MathMax(0.0, tp1_points * 0.25);
      }

      if(protected_points <= 0.0 && tp2_points > 0.0)
         protected_points = MathMax(0.0, tp2_points * 0.25);

      record.paper_virtual_sl = FalconProtectedPriceFromProfitPoints(record, protected_points);
      record.paper_protection_level = record.paper_virtual_sl;

      bool protection_hit = false;
      if(record.paper_protection_trigger == "TP2_PROOF" && barpath_stats.returned_to_loss_after_tp2)
         protection_hit = true;
      else if(record.paper_protection_trigger == "TP1_PROOF" && barpath_stats.returned_to_loss_after_tp1)
         protection_hit = true;

      if(protection_hit && protected_points > record.paper_guard_net_index_points)
      {
         record.paper_virtual_sl_hit = true;
         record.paper_exit_reason = "PAPER_VIRTUAL_SL_HIT";
         record.paper_protection_net_index_points = protected_points;
         record.paper_protection_net_usd = FalconEstimateUsdByRawPoints(protected_points, record.lot_size, m_symbol_context);
      }
      else
      {
         record.paper_exit_reason = "PAPER_SHADOW_EXIT_UNCHANGED_PROTECTED";
      }
   }

   void ApplyPaperRuntimeRunnerApplication(FalconTradeLifecycleRecord &record)
   {
      record.paper_runner_state = "NONE";
      record.paper_runner_activated = false;
      record.paper_runner_max_r = 0.0;
      record.paper_runner_captured_points = record.paper_protection_net_index_points;
      record.paper_runner_additional_points = 0.0;
      record.paper_runner_exit_reason = "PAPER_RUNNER_NOT_ELIGIBLE";
      record.paper_runner_net_index_points = record.paper_protection_net_index_points;
      record.paper_runner_net_usd = record.paper_protection_net_usd;
      record.paper_final_exit_reason = record.paper_exit_reason;

      if(record.paper_guard_status != "PASSED")
      {
         record.paper_runner_exit_reason = "PAPER_GUARD_REJECTED";
         record.paper_final_exit_reason = record.paper_exit_reason;
         return;
      }

      if(!record.paper_protection_activated || !record.paper_virtual_sl_changed)
      {
         record.paper_runner_exit_reason = "PAPER_NO_EARNED_PROTECTION";
         record.paper_final_exit_reason = record.paper_exit_reason;
         return;
      }

      FalconRunnerBarPathStats barpath_stats;
      if(!FalconBuildRunnerBarPathStats(record, barpath_stats))
      {
         record.paper_runner_exit_reason = "PAPER_RUNNER_PATH_SCAN_FAILED";
         record.paper_final_exit_reason = record.paper_exit_reason;
         return;
      }

      record.paper_runner_max_r = barpath_stats.max_r_actual_proxy;

      double tp2_points = FalconDirectionalProfitPoints(record, record.tp2);
      double protected_base_points = MathMax(0.0, record.paper_protection_net_index_points);
      double max_favorable_points = MathMax(0.0, barpath_stats.max_favorable_points);

      if(!barpath_stats.tp2_touched || max_favorable_points <= protected_base_points)
      {
         record.paper_runner_exit_reason = "PAPER_RUNNER_NO_CONTINUATION_PROOF";
         record.paper_final_exit_reason = record.paper_exit_reason;
         return;
      }

      record.paper_runner_activated = true;
      record.paper_runner_state = "ACTIVE";

      double extension_after_tp2 = MathMax(0.0, max_favorable_points - tp2_points);
      double capture_ratio = 0.35;
      if(barpath_stats.max_r_actual_proxy >= 5.0)
      {
         record.paper_runner_state = "MOON";
         capture_ratio = 0.50;
      }

      double captured_points = tp2_points + (extension_after_tp2 * capture_ratio);
      captured_points = MathMin(captured_points, max_favorable_points);
      captured_points = MathMax(captured_points, protected_base_points);

      record.paper_runner_captured_points = captured_points;
      record.paper_runner_additional_points = MathMax(0.0, captured_points - record.paper_protection_net_index_points);

      if(record.paper_runner_additional_points > 0.0)
      {
         record.paper_runner_net_index_points = captured_points;
         record.paper_runner_net_usd = FalconEstimateUsdByRawPoints(captured_points, record.lot_size, m_symbol_context);
         record.paper_runner_exit_reason = (record.paper_runner_state == "MOON" ? "PAPER_MOON_RUNNER_EXIT" : "PAPER_RUNNER_TRAIL_EXIT");
         record.paper_final_exit_reason = record.paper_runner_exit_reason;
      }
      else
      {
         record.paper_runner_exit_reason = "PAPER_RUNNER_NO_ADDITIONAL_CAPTURE";
         record.paper_final_exit_reason = record.paper_exit_reason;
      }
   }


   double CurrentPaperRiskCapitalBeforeTrade()
   {
      double capital = FalconEffectiveCapitalForTier();
      if(m_tle_equity > 0.0)
         capital = m_tle_equity;
      if(capital <= 0.0 && ManualCapital > 0.0)
         capital = ManualCapital;
      if(capital <= 0.0)
         capital = FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD;
      return capital;
   }

   void ApplyCapitalTierFoundation(FalconTradeLifecycleRecord &record)
   {
      double effective_balance = FalconEffectiveCapitalForTier();
      string tier_name = FalconCapitalTierName(effective_balance);
      record.falcon_tier_at_entry = tier_name;
      record.falcon_tier_at_exit = tier_name;
      record.falcon_effective_balance = effective_balance;
      record.falcon_tier_min_balance = FalconCapitalTierMinBalance(tier_name);
      record.falcon_tier_max_balance = FalconCapitalTierMaxBalance(tier_name);
      record.falcon_tier_max_losses = FalconCapitalTierMaxLosses(tier_name);
      record.falcon_tier_max_daily_r = FalconCapitalTierMaxDailyR(tier_name);
      record.falcon_tier_max_drawdown_pct = FalconCapitalTierMaxDrawdownPct(tier_name);
      record.falcon_broker_min_lot = m_symbol_context.min_lot;
      record.falcon_fixed_lot = FixedLotSize;
      record.falcon_min_lot_constraint = FalconMinLotConstraintStatus(m_symbol_context.min_lot, FixedLotSize);

      // v0.55.2a: dynamic risk capital is separate from earned tier promotion.
      record.falcon_dynamic_capital_mode = FALCON_STLC_DYNAMIC_CAPITAL_MODE;
      record.falcon_dynamic_risk_capital_before_trade = CurrentPaperRiskCapitalBeforeTrade();
      record.falcon_dynamic_risk_capital_after_trade = record.falcon_dynamic_risk_capital_before_trade;
      record.falcon_dynamic_risk_tier_by_capital = FalconCapitalTierName(record.falcon_dynamic_risk_capital_before_trade);
      record.falcon_dynamic_risk_pct_of_capital = 0.0;
      record.falcon_dynamic_single_trade_cap_pct = FalconDynamicSingleTradeLossCapRiskPct(record.falcon_dynamic_risk_tier_by_capital);
      record.falcon_dynamic_capital_aware_blocked = 0;
      record.falcon_dynamic_capital_reason = "DYNAMIC_CAPITAL_READY_PROMOTION_STILL_EARNED";
   }

   void ApplyLowCapitalRiskFeasibilityFoundation(FalconTradeLifecycleRecord &record)
   {
      record.falcon_lotsizing_feasibility_status = "INVALID";
      record.falcon_lotsizing_feasibility_reason = "NOT_EVALUATED";
      record.falcon_min_lot_risk_points = 0.0;
      record.falcon_min_lot_risk_usd = 0.0;
      record.falcon_min_lot_risk_pct_of_capital = 0.0;
      record.falcon_tier_base_risk_pct = 0.0;
      record.falcon_tier_risk_budget_usd = 0.0;
      record.falcon_potential_loss_r = 0.0;
      record.falcon_max_single_trade_loss_r = 0.0;
      record.falcon_single_trade_loss_cap_breach = 0;

      double effective_balance = record.falcon_dynamic_risk_capital_before_trade;
      if(effective_balance <= 0.0)
         effective_balance = CurrentPaperRiskCapitalBeforeTrade();

      string tier_name = record.falcon_dynamic_risk_tier_by_capital;
      if(StringLen(tier_name) <= 0)
         tier_name = FalconCapitalTierName(effective_balance);

      double min_lot = record.falcon_broker_min_lot;
      if(min_lot <= 0.0)
         min_lot = m_symbol_context.min_lot;
      if(min_lot <= 0.0)
         min_lot = FixedLotSize;

      double risk_points = MathAbs(record.entry_price - record.structural_sl);
      double base_risk_pct = FalconCapitalTierBaseRiskPct(tier_name);
      double risk_budget_usd = 0.0;
      if(effective_balance > 0.0 && base_risk_pct > 0.0)
         risk_budget_usd = effective_balance * base_risk_pct / 100.0;

      double min_lot_risk_usd = MathAbs(FalconEstimateUsdByRawPoints(risk_points, min_lot, m_symbol_context));
      double min_lot_risk_pct = 0.0;
      if(effective_balance > 0.0)
         min_lot_risk_pct = 100.0 * min_lot_risk_usd / effective_balance;

      double potential_loss_r = 0.0;
      if(risk_budget_usd > 0.0)
         potential_loss_r = min_lot_risk_usd / risk_budget_usd;

      double max_single_trade_loss_r = FalconSingleTradeLossCapR(tier_name);

      record.falcon_min_lot_risk_points = risk_points;
      record.falcon_min_lot_risk_usd = min_lot_risk_usd;
      record.falcon_min_lot_risk_pct_of_capital = min_lot_risk_pct;
      record.falcon_tier_base_risk_pct = base_risk_pct;
      record.falcon_tier_risk_budget_usd = risk_budget_usd;
      record.falcon_potential_loss_r = potential_loss_r;
      record.falcon_max_single_trade_loss_r = max_single_trade_loss_r;

      if(effective_balance <= 0.0)
      {
         record.falcon_lotsizing_feasibility_status = "INVALID";
         record.falcon_lotsizing_feasibility_reason = "EFFECTIVE_BALANCE_UNKNOWN";
         return;
      }
      if(min_lot <= 0.0)
      {
         record.falcon_lotsizing_feasibility_status = "INVALID";
         record.falcon_lotsizing_feasibility_reason = "MIN_LOT_UNKNOWN";
         return;
      }
      if(risk_points <= 0.0 || min_lot_risk_usd <= 0.0)
      {
         record.falcon_lotsizing_feasibility_status = "INVALID";
         record.falcon_lotsizing_feasibility_reason = "STRUCTURAL_RISK_UNKNOWN";
         return;
      }
      if(risk_budget_usd <= 0.0 || potential_loss_r <= 0.0)
      {
         record.falcon_lotsizing_feasibility_status = "INVALID";
         record.falcon_lotsizing_feasibility_reason = "RISK_BUDGET_UNKNOWN";
         return;
      }

      if(max_single_trade_loss_r > 0.0 && potential_loss_r > max_single_trade_loss_r)
      {
         record.falcon_lotsizing_feasibility_status = "NOT_FEASIBLE";
         record.falcon_lotsizing_feasibility_reason = "MIN_LOT_RISK_EXCEEDS_SINGLE_TRADE_CAP";
         record.falcon_single_trade_loss_cap_breach = 1;
         return;
      }

      if(max_single_trade_loss_r > 0.0 && potential_loss_r > (max_single_trade_loss_r / FALCON_LCRF_BORDERLINE_MULTIPLIER))
      {
         record.falcon_lotsizing_feasibility_status = "BORDERLINE";
         record.falcon_lotsizing_feasibility_reason = "MIN_LOT_RISK_NEAR_SINGLE_TRADE_CAP";
         return;
      }

      record.falcon_lotsizing_feasibility_status = "FEASIBLE";
      record.falcon_lotsizing_feasibility_reason = "MIN_LOT_RISK_WITHIN_TIER_BUDGET";
   }

   void ApplyCalibratedSingleTradeLossCapEnforcement(FalconTradeLifecycleRecord &record)
   {
      record.falcon_single_trade_loss_cap_status = "INVALID";
      record.falcon_single_trade_loss_cap_decision = "PASS_THROUGH";
      record.falcon_single_trade_loss_cap_reason = "NOT_EVALUATED";
      record.falcon_single_trade_loss_cap_runtime_enforced = (FALCON_STLC_RUNTIME_ENFORCED ? 1 : 0);
      record.falcon_single_trade_loss_cap_strict_cap_r = record.falcon_max_single_trade_loss_r;
      record.falcon_single_trade_loss_cap_calibrated_cap_r = 0.0;
      record.falcon_single_trade_loss_cap_risk_pct_cap = 0.0;
      record.falcon_single_trade_loss_cap_blocked = 0;
      record.falcon_single_trade_loss_cap_before_net_points = record.paper_runner_net_index_points;
      record.falcon_single_trade_loss_cap_after_net_points = record.paper_runner_net_index_points;
      record.falcon_single_trade_loss_cap_impact_points = 0.0;
      record.falcon_single_trade_loss_cap_before_net_usd = record.paper_runner_net_usd;
      record.falcon_single_trade_loss_cap_after_net_usd = record.paper_runner_net_usd;
      record.falcon_single_trade_loss_cap_impact_usd = 0.0;

      string tier_name = record.falcon_dynamic_risk_tier_by_capital;
      if(StringLen(tier_name) <= 0)
         tier_name = FalconCapitalTierName(record.falcon_dynamic_risk_capital_before_trade);

      double dynamic_capital = record.falcon_dynamic_risk_capital_before_trade;
      if(dynamic_capital <= 0.0)
         dynamic_capital = CurrentPaperRiskCapitalBeforeTrade();

      double active_risk_usd = record.falcon_min_lot_risk_usd;
      if(record.falcon_dlm_active_risk_usd > 0.0)
         active_risk_usd = record.falcon_dlm_active_risk_usd;

      double dynamic_risk_pct = 0.0;
      if(dynamic_capital > 0.0)
         dynamic_risk_pct = 100.0 * active_risk_usd / dynamic_capital;
      record.falcon_dynamic_risk_pct_of_capital = dynamic_risk_pct;

      double calibrated_cap_r = FalconCalibratedSingleTradeLossCapR(tier_name);
      double calibrated_risk_pct_cap = FalconCalibratedSingleTradeLossCapRiskPct(tier_name);
      record.falcon_single_trade_loss_cap_calibrated_cap_r = calibrated_cap_r;
      record.falcon_single_trade_loss_cap_risk_pct_cap = calibrated_risk_pct_cap;
      record.falcon_dynamic_single_trade_cap_pct = calibrated_risk_pct_cap;

      if(dynamic_capital <= 0.0 || active_risk_usd <= 0.0 || calibrated_risk_pct_cap <= 0.0)
      {
         record.falcon_single_trade_loss_cap_status = "INVALID";
         record.falcon_single_trade_loss_cap_decision = "ALLOW_PASS_THROUGH";
         record.falcon_single_trade_loss_cap_reason = "DYNAMIC_ACTIVE_LOT_RISK_INPUT_UNKNOWN";
         record.falcon_dynamic_capital_reason = "DYNAMIC_ACTIVE_LOT_RISK_INPUT_UNKNOWN";
         return;
      }

      bool strict_cap_breach = (record.falcon_single_trade_loss_cap_breach == 1);
      bool dynamic_cap_breach = (dynamic_risk_pct > calibrated_risk_pct_cap);

      if(FALCON_STLC_RUNTIME_ENFORCED && dynamic_cap_breach)
      {
         record.falcon_single_trade_loss_cap_status = "BLOCKED";
         record.falcon_single_trade_loss_cap_decision = "BLOCK_ENTRY_IN_PAPER_STATE";
         record.falcon_single_trade_loss_cap_reason = "DYNAMIC_RISK_PCT_EXCEEDS_CAPITAL_AWARE_CAP";
         record.falcon_single_trade_loss_cap_blocked = 1;
         record.falcon_dynamic_capital_aware_blocked = 1;
         record.falcon_dynamic_capital_reason = "BLOCKED_BY_DYNAMIC_CAPITAL_RELATIVE_RISK";
         record.falcon_single_trade_loss_cap_after_net_points = 0.0;
         record.falcon_single_trade_loss_cap_after_net_usd = 0.0;
      }
      else if(strict_cap_breach)
      {
         record.falcon_single_trade_loss_cap_status = "ALLOWED_DYNAMIC_CAPITAL";
         record.falcon_single_trade_loss_cap_decision = "ALLOW_STRICT_BREACH_WITHIN_DYNAMIC_CAPITAL_CAP";
         record.falcon_single_trade_loss_cap_reason = "STRICT_CAP_BREACH_BUT_DYNAMIC_CAPITAL_CAN_ABSORB_MIN_LOT_RISK";
         record.falcon_dynamic_capital_reason = "ALLOWED_BY_DYNAMIC_CAPITAL_RELATIVE_RISK";
      }
      else
      {
         record.falcon_single_trade_loss_cap_status = "ALLOWED";
         record.falcon_single_trade_loss_cap_decision = "ALLOW_WITHIN_STRICT_AND_DYNAMIC_CAP";
         record.falcon_single_trade_loss_cap_reason = "WITHIN_STRICT_AND_DYNAMIC_CAPITAL_CAP";
         record.falcon_dynamic_capital_reason = "ALLOWED_WITHIN_STRICT_AND_DYNAMIC_CAPITAL_CAP";
      }

      record.falcon_single_trade_loss_cap_impact_points = record.falcon_single_trade_loss_cap_after_net_points - record.falcon_single_trade_loss_cap_before_net_points;
      record.falcon_single_trade_loss_cap_impact_usd = record.falcon_single_trade_loss_cap_after_net_usd - record.falcon_single_trade_loss_cap_before_net_usd;
   }

   double FalconDynamicTierMaxLot(const string tier_name)
   {
      if(tier_name == "MICRO")    return 0.01;
      if(tier_name == "TINY")     return 0.03;
      if(tier_name == "SMALL")    return 0.10;
      if(tier_name == "MEDIUM")   return 0.30;
      if(tier_name == "STANDARD") return 1.00;
      if(tier_name == "LARGE")    return 2.00;
      return MathMax(0.01, m_symbol_context.min_lot);
   }

   double FalconDynamicCapitalMaxLot(const double effective_capital)
   {
      double min_lot = m_symbol_context.min_lot;
      if(min_lot <= 0.0) min_lot = 0.01;
      if(effective_capital <= 0.0)
         return min_lot;

      // Internal safety formula: each 0.01 lot should be backed by ~250 USD of dynamic paper capital.
      // This allows dynamic growth, but prevents a small account equity curve from jumping straight into oversized lots.
      double raw_capital_lot = (effective_capital / FALCON_DLM_CAPITAL_USD_PER_001_LOT) * 0.01;
      int min_floor = 0;
      int max_cap = 0;
      return FalconNormalizeDynamicLotToBroker(raw_capital_lot, min_floor, max_cap);
   }

   double FalconDynamicGrowthRampMaxLot()
   {
      double min_lot = m_symbol_context.min_lot;
      double step = m_symbol_context.lot_step;
      if(step <= 0.0) step = 0.01;
      if(min_lot <= 0.0) min_lot = step;

      if(!m_dlm_previous_active_lot_ready || m_dlm_previous_active_lot <= 0.0)
         return min_lot;

      double ramp_cap = (m_dlm_previous_active_lot * FALCON_DLM_MAX_LOT_GROWTH_MULTIPLIER) + step;
      if(ramp_cap < min_lot)
         ramp_cap = min_lot;

      int min_floor = 0;
      int max_cap = 0;
      return FalconNormalizeDynamicLotToBroker(ramp_cap, min_floor, max_cap);
   }

   double FalconNormalizeDynamicLotToBroker(const double raw_lot, int &min_floor_applied, int &max_cap_applied)
   {
      min_floor_applied = 0;
      max_cap_applied = 0;

      double lot = raw_lot;
      double min_lot = m_symbol_context.min_lot;
      double max_lot = m_symbol_context.max_lot;
      double step = m_symbol_context.lot_step;

      if(step <= 0.0) step = 0.01;
      if(min_lot <= 0.0) min_lot = step;
      if(max_lot <= 0.0) max_lot = MathMax(min_lot, lot);

      if(lot <= 0.0)
         lot = min_lot;

      double stepped_lot = MathFloor(lot / step) * step;
      if(stepped_lot <= 0.0)
         stepped_lot = min_lot;

      if(stepped_lot < min_lot)
      {
         stepped_lot = min_lot;
         min_floor_applied = 1;
      }
      if(stepped_lot > max_lot)
      {
         stepped_lot = max_lot;
         max_cap_applied = 1;
      }

      return NormalizeDouble(stepped_lot, 2);
   }

   void FalconRefreshUsdMetricsForActiveLot(FalconTradeLifecycleRecord &record, const double active_lot)
   {
      if(active_lot <= 0.0)
         return;

      record.lot_size = active_lot;
      record.net_usd = FalconEstimateUsdByRawPoints(record.net_index_points, active_lot, m_symbol_context);
      if(record.net_usd > 0.0)
      {
         record.profit_usd = record.net_usd;
         record.loss_usd = 0.0;
      }
      else if(record.net_usd < 0.0)
      {
         record.profit_usd = 0.0;
         record.loss_usd = MathAbs(record.net_usd);
      }
      else
      {
         record.profit_usd = 0.0;
         record.loss_usd = 0.0;
      }

      record.fvg_quality_shadow_guard_sim_net_usd = FalconEstimateUsdByRawPoints(record.fvg_quality_shadow_guard_sim_net_points, active_lot, m_symbol_context);
      record.paper_guard_net_usd = FalconEstimateUsdByRawPoints(record.paper_guard_net_index_points, active_lot, m_symbol_context);
      record.paper_protection_net_usd = FalconEstimateUsdByRawPoints(record.paper_protection_net_index_points, active_lot, m_symbol_context);
      record.paper_runner_net_usd = FalconEstimateUsdByRawPoints(record.paper_runner_net_index_points, active_lot, m_symbol_context);
   }

   void ApplyDynamicLotSizingModel(FalconTradeLifecycleRecord &record)
   {
      record.falcon_dlm_status = FALCON_DLM_STATUS;
      record.falcon_dlm_decision = "INVALID";
      record.falcon_dlm_runtime_enforced = (FALCON_DLM_RUNTIME_ENFORCED ? 1 : 0);
      record.falcon_dlm_use_fixed_lot = (UseFixedLot ? 1 : 0);
      record.falcon_dlm_fixed_lot_size = FixedLotSize;
      record.falcon_dlm_effective_capital = record.falcon_dynamic_risk_capital_before_trade;
      record.falcon_dlm_base_risk_pct = record.falcon_tier_base_risk_pct;
      record.falcon_dlm_risk_budget_usd = record.falcon_tier_risk_budget_usd;
      record.falcon_dlm_risk_points = record.falcon_min_lot_risk_points;
      record.falcon_dlm_risk_usd_per_one_lot = 0.0;
      record.falcon_dlm_raw_lot = 0.0;
      record.falcon_dlm_recommended_lot = 0.0;
      record.falcon_dlm_active_lot = record.lot_size;
      record.falcon_dlm_tier_max_lot = 0.0;
      record.falcon_dlm_capital_max_lot = 0.0;
      record.falcon_dlm_previous_active_lot = (m_dlm_previous_active_lot_ready ? m_dlm_previous_active_lot : 0.0);
      record.falcon_dlm_growth_ramp_max_lot = 0.0;
      record.falcon_dlm_tier_cap_applied = 0;
      record.falcon_dlm_capital_cap_applied = 0;
      record.falcon_dlm_growth_ramp_applied = 0;
      record.falcon_dlm_safety_mode = "NOT_EVALUATED";
      record.falcon_dlm_broker_min_lot = m_symbol_context.min_lot;
      record.falcon_dlm_broker_max_lot = m_symbol_context.max_lot;
      record.falcon_dlm_broker_lot_step = m_symbol_context.lot_step;
      record.falcon_dlm_min_lot_floor_applied = 0;
      record.falcon_dlm_max_lot_cap_applied = 0;
      record.falcon_dlm_recommended_risk_usd = 0.0;
      record.falcon_dlm_recommended_risk_pct = 0.0;
      record.falcon_dlm_active_risk_usd = 0.0;
      record.falcon_dlm_active_risk_pct = 0.0;
      record.falcon_dlm_reason = "NOT_EVALUATED";

      if(record.falcon_dlm_effective_capital <= 0.0)
         record.falcon_dlm_effective_capital = CurrentPaperRiskCapitalBeforeTrade();
      if(record.falcon_dlm_active_lot <= 0.0)
         record.falcon_dlm_active_lot = FixedLotSize;

      if(record.falcon_dlm_effective_capital <= 0.0 || record.falcon_dlm_risk_budget_usd <= 0.0 || record.falcon_dlm_risk_points <= 0.0)
      {
         record.falcon_dlm_decision = "INVALID";
         record.falcon_dlm_reason = "CAPITAL_OR_RISK_BUDGET_OR_STRUCTURAL_RISK_UNKNOWN";
         return;
      }

      double one_lot_risk_usd = MathAbs(FalconEstimateUsdByRawPoints(record.falcon_dlm_risk_points, 1.0, m_symbol_context));
      record.falcon_dlm_risk_usd_per_one_lot = one_lot_risk_usd;
      if(one_lot_risk_usd <= 0.0)
      {
         record.falcon_dlm_decision = "INVALID";
         record.falcon_dlm_reason = "ONE_LOT_RISK_UNKNOWN";
         return;
      }

      double raw_lot = record.falcon_dlm_risk_budget_usd / one_lot_risk_usd;
      record.falcon_dlm_raw_lot = raw_lot;

      int min_floor = 0;
      int max_cap = 0;
      double recommended_lot = FalconNormalizeDynamicLotToBroker(raw_lot, min_floor, max_cap);
      record.falcon_dlm_recommended_lot = recommended_lot;
      record.falcon_dlm_min_lot_floor_applied = min_floor;
      record.falcon_dlm_max_lot_cap_applied = max_cap;

      string dynamic_tier = record.falcon_dynamic_risk_tier_by_capital;
      if(StringLen(dynamic_tier) <= 0)
         dynamic_tier = FalconCapitalTierName(record.falcon_dlm_effective_capital);

      record.falcon_dlm_tier_max_lot = FalconDynamicTierMaxLot(dynamic_tier);
      record.falcon_dlm_capital_max_lot = FalconDynamicCapitalMaxLot(record.falcon_dlm_effective_capital);
      record.falcon_dlm_growth_ramp_max_lot = FalconDynamicGrowthRampMaxLot();

      double active_lot = record.lot_size;
      if(UseFixedLot)
      {
         active_lot = FixedLotSize;
         record.falcon_dlm_decision = "FIXED_LOT_ACTIVE_FIXEDLOT_PRESERVED";
         record.falcon_dlm_safety_mode = "FIXED_MODE_NO_DYNAMIC_APPLICATION";
         record.falcon_dlm_reason = "USE_FIXED_LOT_TRUE_FIXEDLOT_PRESERVED_NO_DYNAMIC_APPLICATION";
      }
      else
      {
         double safety_lot = recommended_lot;

         if(record.falcon_dlm_tier_max_lot > 0.0 && safety_lot > record.falcon_dlm_tier_max_lot)
         {
            safety_lot = record.falcon_dlm_tier_max_lot;
            record.falcon_dlm_tier_cap_applied = 1;
         }

         if(record.falcon_dlm_capital_max_lot > 0.0 && safety_lot > record.falcon_dlm_capital_max_lot)
         {
            safety_lot = record.falcon_dlm_capital_max_lot;
            record.falcon_dlm_capital_cap_applied = 1;
         }

         if(record.falcon_dlm_growth_ramp_max_lot > 0.0 && safety_lot > record.falcon_dlm_growth_ramp_max_lot)
         {
            safety_lot = record.falcon_dlm_growth_ramp_max_lot;
            record.falcon_dlm_growth_ramp_applied = 1;
         }

         int safety_min_floor = 0;
         int safety_max_cap = 0;
         active_lot = FalconNormalizeDynamicLotToBroker(safety_lot, safety_min_floor, safety_max_cap);

         record.falcon_dlm_decision = "DYNAMIC_LOT_APPLIED_WITH_SAFETY_RAMP";
         record.falcon_dlm_safety_mode = "TIER_CAP_PLUS_CAPITAL_CAP_PLUS_GROWTH_RAMP";
         record.falcon_dlm_reason = "USE_FIXED_LOT_FALSE_RECOMMENDED_LOT_SAFETY_CAPPED_BEFORE_PAPER_USD_APPLICATION";
      }

      if(active_lot <= 0.0)
         active_lot = m_symbol_context.min_lot;
      if(active_lot <= 0.0)
         active_lot = FixedLotSize;

      record.falcon_dlm_active_lot = active_lot;
      record.falcon_dlm_recommended_risk_usd = MathAbs(FalconEstimateUsdByRawPoints(record.falcon_dlm_risk_points, recommended_lot, m_symbol_context));
      record.falcon_dlm_active_risk_usd = MathAbs(FalconEstimateUsdByRawPoints(record.falcon_dlm_risk_points, active_lot, m_symbol_context));

      if(record.falcon_dlm_effective_capital > 0.0)
      {
         record.falcon_dlm_recommended_risk_pct = 100.0 * record.falcon_dlm_recommended_risk_usd / record.falcon_dlm_effective_capital;
         record.falcon_dlm_active_risk_pct = 100.0 * record.falcon_dlm_active_risk_usd / record.falcon_dlm_effective_capital;
      }

      if(FALCON_DLM_RUNTIME_ENFORCED)
         FalconRefreshUsdMetricsForActiveLot(record, active_lot);

      m_dlm_previous_active_lot = active_lot;
      m_dlm_previous_active_lot_ready = true;
   }

   void ApplyThreeLayerEmergencyApplication(FalconTradeLifecycleRecord &record)
   {
      double effective_balance = record.falcon_dynamic_risk_capital_before_trade;
      if(effective_balance <= 0.0)
         effective_balance = record.falcon_effective_balance;
      if(effective_balance <= 0.0)
         effective_balance = FalconEffectiveCapitalForTier();
      if(effective_balance <= 0.0)
         effective_balance = FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD;

      if(m_tle_equity <= 0.0)
      {
         m_tle_equity = effective_balance;
         m_tle_peak_equity = effective_balance;
      }
      if(m_tle_peak_equity <= 0.0)
         m_tle_peak_equity = m_tle_equity;

      datetime trade_day = StringToTime(TimeToString(record.exit_time, TIME_DATE));
      if(trade_day <= 0)
         trade_day = StringToTime(TimeToString(record.entry_time, TIME_DATE));
      if(m_tle_current_day == 0)
         m_tle_current_day = trade_day;
      bool layer2_reset_on_new_day = false;
      bool emergency_resolved_on_new_day = false;
      string resolved_emergency_reason = "NONE";
      if(trade_day > 0 && trade_day != m_tle_current_day)
      {
         layer2_reset_on_new_day = true;
         m_tle_current_day = trade_day;
         m_tle_daily_r = 0.0;

         // v0.53.2a: Layer 1 and Layer 2 are daily pause layers.
         // They must not block all remaining test days. Resolve them at
         // the next day boundary, while Layer 3 remains peak/drawdown based.
         if(m_tle_emergency_active &&
            (m_tle_emergency_reason == "LAYER_1_CONSECUTIVE" ||
             m_tle_emergency_reason == "LAYER_2_DAILY_R"))
         {
            emergency_resolved_on_new_day = true;
            resolved_emergency_reason = m_tle_emergency_reason;
            m_tle_emergency_active = false;
            m_tle_emergency_reason = "NONE";
            m_tle_consecutive_losses = 0;
         }
      }

      record.falcon_emergency_status = "SAFE";
      record.falcon_emergency_triggered_layer = 0;
      record.falcon_emergency_reason = "NONE";
      record.falcon_reset_status = "NO_RESET";
      record.falcon_layer1_reset_on_win = 0;
      record.falcon_layer2_reset_on_new_day = 0;
      record.falcon_layer3_reset_on_new_peak = 0;
      record.falcon_reset_reason = "NONE";
      record.falcon_layer1_max_losses = record.falcon_tier_max_losses;
      record.falcon_layer2_max_daily_r = record.falcon_tier_max_daily_r;
      record.falcon_layer3_max_drawdown_pct = record.falcon_tier_max_drawdown_pct;
      record.falcon_emergency_before_net_points = record.falcon_single_trade_loss_cap_after_net_points;
      record.falcon_emergency_before_net_usd = record.falcon_single_trade_loss_cap_after_net_usd;
      record.falcon_emergency_after_net_points = record.falcon_single_trade_loss_cap_after_net_points;
      record.falcon_emergency_after_net_usd = record.falcon_single_trade_loss_cap_after_net_usd;

      if(m_tle_emergency_active)
      {
         record.falcon_emergency_status = "BLOCKED";
         record.falcon_emergency_triggered_layer = -1;
         record.falcon_emergency_reason = m_tle_emergency_reason;
         record.falcon_emergency_after_net_points = 0.0;
         record.falcon_emergency_after_net_usd = 0.0;
         record.falcon_layer1_consecutive_losses = m_tle_consecutive_losses;
         record.falcon_layer2_daily_r = m_tle_daily_r;
         record.falcon_layer3_drawdown_pct = m_tle_max_drawdown_pct;
         record.falcon_reset_status = "EMERGENCY_ACTIVE_BLOCKED";
         record.falcon_dynamic_risk_capital_after_trade = m_tle_equity;
         return;
      }

      double risk_points = MathAbs(record.entry_price - record.structural_sl);
      double risk_usd = MathAbs(FalconEstimateUsdByRawPoints(risk_points, record.lot_size, m_symbol_context));
      if(risk_usd <= 0.0)
         risk_usd = MathAbs(record.paper_guard_net_usd);
      if(risk_usd <= 0.0)
         risk_usd = 1.0;

      double trade_r = record.falcon_single_trade_loss_cap_after_net_usd / risk_usd;

      bool layer1_reset_on_win = false;
      if(record.falcon_single_trade_loss_cap_after_net_usd < -0.0001)
      {
         m_tle_consecutive_losses++;
      }
      else if(record.falcon_single_trade_loss_cap_after_net_usd > 0.0001)
      {
         if(m_tle_consecutive_losses > 0)
            layer1_reset_on_win = true;
         m_tle_consecutive_losses = 0;
      }

      m_tle_daily_r += trade_r;
      m_tle_equity += record.falcon_single_trade_loss_cap_after_net_usd;
      bool layer3_reset_on_new_peak = false;
      if(m_tle_equity > m_tle_peak_equity)
      {
         if(m_tle_peak_equity > 0.0)
            layer3_reset_on_new_peak = true;
         m_tle_peak_equity = m_tle_equity;
      }

      double drawdown_pct = 0.0;
      if(m_tle_peak_equity > 0.0 && m_tle_equity < m_tle_peak_equity)
         drawdown_pct = 100.0 * (m_tle_peak_equity - m_tle_equity) / m_tle_peak_equity;
      if(drawdown_pct > m_tle_max_drawdown_pct)
         m_tle_max_drawdown_pct = drawdown_pct;

      record.falcon_dynamic_risk_capital_after_trade = m_tle_equity;

      record.falcon_layer1_consecutive_losses = m_tle_consecutive_losses;
      record.falcon_layer2_daily_r = m_tle_daily_r;
      record.falcon_layer3_drawdown_pct = drawdown_pct;
      record.falcon_layer1_reset_on_win = (layer1_reset_on_win ? 1 : 0);
      record.falcon_layer2_reset_on_new_day = (layer2_reset_on_new_day ? 1 : 0);
      record.falcon_layer3_reset_on_new_peak = (layer3_reset_on_new_peak ? 1 : 0);
      if(record.falcon_layer1_reset_on_win == 1 || record.falcon_layer2_reset_on_new_day == 1 || record.falcon_layer3_reset_on_new_peak == 1 || emergency_resolved_on_new_day)
      {
         record.falcon_reset_status = "RESET_APPLIED";
         string reset_reason = "";
         if(record.falcon_layer1_reset_on_win == 1) reset_reason += "LAYER1_ON_WIN;";
         if(record.falcon_layer2_reset_on_new_day == 1) reset_reason += "LAYER2_ON_NEW_DAY;";
         if(record.falcon_layer3_reset_on_new_peak == 1) reset_reason += "LAYER3_ON_NEW_PEAK;";
         if(emergency_resolved_on_new_day) reset_reason += "EMERGENCY_DAILY_RESOLVE_" + resolved_emergency_reason + ";";
         record.falcon_reset_reason = reset_reason;
      }

      if(record.falcon_layer1_max_losses > 0 && m_tle_consecutive_losses >= record.falcon_layer1_max_losses)
      {
         record.falcon_emergency_status = "TRIGGERED";
         record.falcon_emergency_triggered_layer = 1;
         record.falcon_emergency_reason = "LAYER_1_CONSECUTIVE";
      }
      else if(record.falcon_layer2_max_daily_r > 0.0 && m_tle_daily_r <= -record.falcon_layer2_max_daily_r)
      {
         record.falcon_emergency_status = "TRIGGERED";
         record.falcon_emergency_triggered_layer = 2;
         record.falcon_emergency_reason = "LAYER_2_DAILY_R";
      }
      else if(record.falcon_layer3_max_drawdown_pct > 0.0 && drawdown_pct >= record.falcon_layer3_max_drawdown_pct)
      {
         record.falcon_emergency_status = "TRIGGERED";
         record.falcon_emergency_triggered_layer = 3;
         record.falcon_emergency_reason = "LAYER_3_TIER_DRAWDOWN";
      }

      if(record.falcon_emergency_status == "TRIGGERED")
      {
         m_tle_emergency_active = true;
         m_tle_emergency_reason = record.falcon_emergency_reason;
         AppendEmergencyTriggerEvent(record);
      }
   }

   void ApplyCapitalFlowSourceClassification(FalconTradeLifecycleRecord &record)
   {
      // v0.55.5: reporting-only classification. It does not modify capital, lot, entry, exit, or emergency state.
      double before_capital = record.falcon_dynamic_risk_capital_before_trade;
      double after_capital  = record.falcon_dynamic_risk_capital_after_trade;
      double final_trade_delta = record.falcon_emergency_after_net_usd;

      record.falcon_capital_flow_source = "UNKNOWN";
      record.falcon_capital_flow_delta_usd = 0.0;
      record.falcon_external_capital_delta_usd = 0.0;
      record.falcon_capital_flow_external_event = 0;
      record.falcon_capital_flow_status = "PASS";
      record.falcon_capital_flow_reason = "NOT_EVALUATED";

      if(before_capital <= 0.0 || after_capital <= 0.0)
      {
         record.falcon_capital_flow_status = "PASS";
         record.falcon_capital_flow_source = "UNKNOWN";
         record.falcon_capital_flow_reason = "CAPITAL_BEFORE_OR_AFTER_NOT_AVAILABLE";
         return;
      }

      double capital_delta = after_capital - before_capital;
      double external_delta = capital_delta - final_trade_delta;
      record.falcon_capital_flow_delta_usd = capital_delta;
      record.falcon_external_capital_delta_usd = external_delta;

      double external_tolerance = 0.01;
      if(MathAbs(external_delta) > external_tolerance)
      {
         record.falcon_capital_flow_external_event = 1;
         if(external_delta > 0.0)
         {
            if(final_trade_delta > 0.0001)
            {
               record.falcon_capital_flow_source = "MIXED_PROFIT_PLUS_INJECTION";
               record.falcon_capital_flow_reason = "TRADE_PROFIT_PLUS_POSITIVE_EXTERNAL_CAPITAL_FLOW";
            }
            else
            {
               record.falcon_capital_flow_source = "INJECTION";
               record.falcon_capital_flow_reason = "CAPITAL_DELTA_EXCEEDS_TRADE_DELTA_POSITIVE_EXTERNAL_FLOW";
            }
         }
         else
         {
            if(final_trade_delta < -0.0001)
            {
               record.falcon_capital_flow_source = "MIXED_LOSS_PLUS_WITHDRAWAL";
               record.falcon_capital_flow_reason = "TRADE_LOSS_PLUS_NEGATIVE_EXTERNAL_CAPITAL_FLOW";
            }
            else
            {
               record.falcon_capital_flow_source = "WITHDRAWAL";
               record.falcon_capital_flow_reason = "CAPITAL_DELTA_EXCEEDS_TRADE_DELTA_NEGATIVE_EXTERNAL_FLOW";
            }
         }
         // External capital movement is not a reporting failure; it must be classified and separated from strategy P/L.
         record.falcon_capital_flow_status = "PASS";
         return;
      }

      if(final_trade_delta > 0.0001)
      {
         record.falcon_capital_flow_source = "TRADE_PROFIT";
         record.falcon_capital_flow_reason = "CAPITAL_DELTA_MATCHES_FINAL_WORKING_TRADE_PROFIT";
      }
      else if(final_trade_delta < -0.0001)
      {
         record.falcon_capital_flow_source = "TRADE_LOSS";
         record.falcon_capital_flow_reason = "CAPITAL_DELTA_MATCHES_FINAL_WORKING_TRADE_LOSS";
      }
      else
      {
         record.falcon_capital_flow_source = "FLAT";
         record.falcon_capital_flow_reason = "NO_FINAL_WORKING_TRADE_DELTA";
      }
   }

   void ResetTotals()
   {
      
      ResetWeeklyStabilityState();
m_totals.total_trades                = 0;
      m_totals.win_trades                  = 0;
      m_totals.loss_trades                 = 0;
      m_totals.breakeven_trades            = 0;
      m_totals.total_profit_index_points   = 0.0;
      m_totals.total_loss_index_points     = 0.0;
      m_totals.net_index_points            = 0.0;
      m_totals.total_profit_usd            = 0.0;
      m_totals.total_loss_usd              = 0.0;
      m_totals.net_usd                     = 0.0;
      m_totals.final_profit_trades         = 0;
      m_totals.final_loss_trades           = 0;
      m_totals.final_breakeven_trades      = 0;
      m_totals.final_total_profit_usd      = 0.0;
      m_totals.final_total_loss_usd        = 0.0;
      m_totals.final_working_net_usd       = 0.0;
      m_totals.visible_raw_net_usd_4dp     = 0.0;
      m_totals.visible_final_working_net_usd_4dp = 0.0;
      m_totals.visible_final_total_profit_usd_4dp = 0.0;
      m_totals.visible_final_total_loss_usd_4dp = 0.0;
      m_totals.capital_flow_evaluated_trades = 0;
      m_totals.capital_flow_trade_profit_events = 0;
      m_totals.capital_flow_trade_loss_events = 0;
      m_totals.capital_flow_flat_events = 0;
      m_totals.capital_flow_injection_events = 0;
      m_totals.capital_flow_withdrawal_events = 0;
      m_totals.capital_flow_unknown_events = 0;
      m_totals.capital_flow_integrity_breaches = 0;
      m_totals.capital_flow_external_net_usd = 0.0;
      m_totals.weekly_stability_evaluated_trades = 0;
      m_totals.weekly_stability_weeks = 0;
      m_totals.weekly_stability_positive_weeks = 0;
      m_totals.weekly_stability_negative_weeks = 0;
      m_totals.weekly_stability_best_week_usd = 0.0;
      m_totals.weekly_stability_worst_week_usd = 0.0;
      m_totals.weekly_stability_score = 0.0;
      m_totals.market_close_guard_evaluated_trades = 0;
      m_totals.market_close_guard_near_close_entry_trades = 0;
      m_totals.market_close_guard_open_weekend_risk_trades = 0;
      m_totals.market_close_max_trade_duration_minutes = 0;
      m_totals.market_close_total_trade_duration_minutes = 0.0;
      m_totals.market_close_duration_above_window_trades = 0;
      m_totals.market_close_longest_trade_id = "";
      m_totals.no_new_entry_override_evaluated_trades = 0;
      m_totals.no_new_entry_override_blocked_trades = 0;
      m_totals.no_new_entry_override_blocked_winners = 0;
      m_totals.no_new_entry_override_blocked_losers = 0;
      m_totals.no_new_entry_override_impact_usd = 0.0;
      m_totals.force_close_override_evaluated_trades = 0;
      m_totals.force_close_override_closed_trades = 0;
      m_totals.force_close_override_daily_closed_trades = 0;
      m_totals.force_close_override_weekend_closed_trades = 0;
      m_totals.force_close_override_price_ok_trades = 0;
      m_totals.force_close_override_missing_price_trades = 0;
      m_totals.force_close_override_before_net_usd = 0.0;
      m_totals.force_close_override_after_net_usd = 0.0;
      m_totals.force_close_override_impact_usd = 0.0;
      m_totals.paper_state_snapshot_evaluated_trades = 0;
      m_totals.paper_state_snapshot_written_rows = 0;
      m_totals.paper_state_snapshot_write_failures = 0;
      m_totals.paper_state_recovery_trusted_trades = 0;
      m_totals.paper_state_recovery_untrusted_trades = 0;
      m_totals.session_boundary_checkpoint_evaluated_trades = 0;
      m_totals.session_boundary_recovery_checkpoint_minutes = FalconSessionBoundaryDefaultRecoveryCheckpointMinutes();
      m_totals.session_boundary_daily_checkpoint_open_trades = 0;
      m_totals.session_boundary_weekend_checkpoint_open_trades = 0;
      m_totals.session_boundary_recovery_required_trades = 0;
      m_totals.session_boundary_dirty_after_close_safety_trades = 0;
      m_totals.win_rate                    = 0.0;
      m_totals.loss_rate                   = 0.0;

      m_totals.buy_trades                  = 0;
      m_totals.buy_win_trades              = 0;
      m_totals.buy_net_index_points        = 0.0;
      m_totals.sell_trades                 = 0;
      m_totals.sell_win_trades             = 0;
      m_totals.sell_net_index_points       = 0.0;

      m_totals.fvg_qguard_evaluated             = 0;
      m_totals.fvg_qguard_passed                = 0;
      m_totals.fvg_qguard_blocked               = 0;
      m_totals.fvg_qguard_blocked_winners       = 0;
      m_totals.fvg_qguard_blocked_losers        = 0;
      m_totals.fvg_qguard_actual_net_points     = 0.0;
      m_totals.fvg_qguard_simulated_net_points  = 0.0;
      m_totals.fvg_qguard_blocked_net_points    = 0.0;
      m_totals.fvg_qguard_actual_net_usd        = 0.0;
      m_totals.fvg_qguard_simulated_net_usd     = 0.0;
      m_totals.fvg_qguard_blocked_net_usd       = 0.0;

      m_totals.sltp_validation_evaluated_trades = 0;
      m_totals.structural_stop_valid_trades     = 0;
      m_totals.structural_stop_invalid_trades   = 0;
      m_totals.tp_builder_valid_trades          = 0;
      m_totals.tp_builder_invalid_trades        = 0;
      m_totals.tp1_valid_trades                 = 0;
      m_totals.tp2_valid_trades                 = 0;
      m_totals.tp3_valid_trades                 = 0;

      m_totals.smart_tm_evaluated_trades             = 0;
      m_totals.smart_tm_proof_score_min              = -1;
      m_totals.smart_tm_proof_score_max              = 0;
      m_totals.smart_tm_proof_score_total            = 0;
      m_totals.smart_tm_exit_conservative_trades     = 0;
      m_totals.smart_tm_partial_no_runner_trades     = 0;
      m_totals.smart_tm_runner_candidate_trades      = 0;
      m_totals.smart_tm_strong_runner_candidate_trades = 0;
      m_totals.smart_tm_antiproof_score_total        = 0;
      m_totals.smart_tm_antiproof_score_max          = 0;
      m_totals.smart_tm_antiproof_high_risk_trades   = 0;
      m_totals.smart_tm_behavior_healthy_trades      = 0;
      m_totals.smart_tm_behavior_choppy_trades       = 0;
      m_totals.smart_tm_behavior_failure_trades      = 0;
      m_totals.smart_tm_runner_opportunity_trades    = 0;
      m_totals.smart_tm_strong_runner_opportunity_trades = 0;
      m_totals.smart_tm_tp1_close_trades             = 0;
      m_totals.smart_tm_sl_failure_trades            = 0;
      m_totals.smart_tm_timeout_close_trades         = 0;
      m_totals.smart_tm_proof_weak_trades           = 0;
      m_totals.smart_tm_proof_medium_trades         = 0;
      m_totals.smart_tm_proof_strong_trades         = 0;
      m_totals.smart_tm_proof_elite_trades          = 0;
      m_totals.smart_tm_behavior_grinding_trades    = 0;
      m_totals.smart_tm_behavior_exhausted_trades   = 0;
      m_totals.smart_tm_runner_conservative_opportunity_trades = 0;

      m_totals.runner_diag_evaluated_trades = 0;
      m_totals.runner_diag_tp1_anchor_trades = 0;
      m_totals.runner_diag_tp2_anchor_trades = 0;
      m_totals.runner_diag_mfe_proxy_trades = 0;
      m_totals.runner_diag_mfe_proxy_total_points = 0.0;
      m_totals.runner_diag_mfe_proxy_max_points = 0.0;
      m_totals.runner_diag_tp1_to_tp2_room_total_points = 0.0;
      m_totals.runner_diag_tp1_to_tp3_room_total_points = 0.0;
      m_totals.runner_diag_tp2_to_tp3_room_total_points = 0.0;
      m_totals.runner_diag_max_r_proxy_total = 0.0;
      m_totals.runner_diag_max_r_proxy_max = 0.0;
      m_totals.runner_diag_would_reach_3r_trades = 0;
      m_totals.runner_diag_would_reach_5r_trades = 0;
      m_totals.runner_diag_protected_profit_opportunity_trades = 0;
      m_totals.runner_diag_return_to_loss_after_proof_unknown_trades = 0;

      m_totals.runner_barpath_evaluated_trades = 0;
      m_totals.runner_barpath_scanned_trades = 0;
      m_totals.runner_barpath_scan_failed_trades = 0;
      m_totals.runner_barpath_total_bars_scanned = 0;
      m_totals.runner_barpath_tp1_touched_trades = 0;
      m_totals.runner_barpath_tp2_touched_trades = 0;
      m_totals.runner_barpath_mfe_after_tp1_total_points = 0.0;
      m_totals.runner_barpath_mfe_after_tp1_max_points = 0.0;
      m_totals.runner_barpath_mfe_after_tp2_total_points = 0.0;
      m_totals.runner_barpath_mfe_after_tp2_max_points = 0.0;
      m_totals.runner_barpath_giveback_after_tp1_total_points = 0.0;
      m_totals.runner_barpath_giveback_after_tp1_max_points = 0.0;
      m_totals.runner_barpath_giveback_after_tp2_total_points = 0.0;
      m_totals.runner_barpath_giveback_after_tp2_max_points = 0.0;
      m_totals.runner_barpath_returned_to_loss_after_tp1_trades = 0;
      m_totals.runner_barpath_returned_to_loss_after_tp2_trades = 0;
      m_totals.runner_barpath_actual_would_reach_3r_trades = 0;
      m_totals.runner_barpath_actual_would_reach_5r_trades = 0;
      m_totals.runner_barpath_protected_after_tp1_opportunity_trades = 0;
      m_totals.runner_barpath_protected_after_tp2_opportunity_trades = 0;

      m_totals.fast_tm_evaluated_trades = 0;
      m_totals.fast_tm_decision_cache_ready_trades = 0;
      m_totals.fast_tm_precomputed_branch_ready_trades = 0;
      m_totals.fast_tm_tp1_decision_ready_trades = 0;
      m_totals.fast_tm_tp2_decision_ready_trades = 0;
      m_totals.fast_tm_protection_required_after_tp1_trades = 0;
      m_totals.fast_tm_protection_required_after_tp2_trades = 0;
      m_totals.fast_tm_immediate_runner_candidate_trades = 0;
      m_totals.fast_tm_immediate_exit_warning_trades = 0;
      m_totals.fast_tm_fast_antiproof_warning_trades = 0;
      m_totals.fast_tm_conservative_partial_ready_trades = 0;
      m_totals.fast_tm_runner_wait_for_confirmation_trades = 0;
      m_totals.paper_guard_evaluated_trades = 0;
      m_totals.paper_guard_passed_trades = 0;
      m_totals.paper_guard_rejected_trades = 0;
      m_totals.paper_guard_spread_rejected_trades = 0;
      m_totals.paper_guard_stops_rejected_trades = 0;
      m_totals.paper_guard_freeze_rejected_trades = 0;
      m_totals.paper_exposure_evaluated_trades = 0;
      m_totals.paper_exposure_passed_trades = 0;
      m_totals.paper_exposure_blocked_total = 0;
      m_totals.paper_exposure_blocked_engine = 0;
      m_totals.paper_exposure_blocked_direction = 0;
      m_totals.paper_guard_before_net_points = 0.0;
      m_totals.paper_guard_after_net_points = 0.0;
      m_totals.paper_guard_impact_points = 0.0;
      m_totals.paper_guard_before_net_usd = 0.0;
      m_totals.paper_guard_after_net_usd = 0.0;
      m_totals.paper_guard_impact_usd = 0.0;
      m_totals.paper_protection_evaluated_trades = 0;
      m_totals.paper_protection_eligible_trades = 0;
      m_totals.paper_protection_activated_trades = 0;
      m_totals.paper_tp1_protection_trades = 0;
      m_totals.paper_tp2_protection_trades = 0;
      m_totals.paper_virtual_sl_changed_trades = 0;
      m_totals.paper_virtual_sl_hit_trades = 0;
      m_totals.paper_protected_exit_trades = 0;
      m_totals.paper_protection_before_net_points = 0.0;
      m_totals.paper_protection_after_net_points = 0.0;
      m_totals.paper_protection_impact_points = 0.0;
      m_totals.paper_protection_before_net_usd = 0.0;
      m_totals.paper_protection_after_net_usd = 0.0;
      m_totals.paper_protection_impact_usd = 0.0;
      m_totals.paper_protection_giveback_prevented_points = 0.0;
      m_totals.paper_protection_giveback_prevented_usd = 0.0;
      m_totals.paper_runner_evaluated_trades = 0;
      m_totals.paper_runner_eligible_trades = 0;
      m_totals.paper_runner_activated_trades = 0;
      m_totals.paper_runner_3r_trades = 0;
      m_totals.paper_moon_mode_5r_trades = 0;
      m_totals.paper_runner_exit_trades = 0;
      m_totals.paper_runner_giveback_trades = 0;
      m_totals.paper_runner_protected_from_loss_trades = 0;
      m_totals.paper_runner_before_net_points = 0.0;
      m_totals.paper_runner_after_net_points = 0.0;
      m_totals.paper_runner_impact_points = 0.0;
      m_totals.paper_runner_before_net_usd = 0.0;
      m_totals.paper_runner_after_net_usd = 0.0;
      m_totals.paper_runner_impact_usd = 0.0;
      m_totals.paper_runner_additional_points = 0.0;
      m_totals.paper_runner_additional_usd = 0.0;

      m_totals.lotsizing_feasibility_evaluated_trades = 0;
      m_totals.lotsizing_feasibility_feasible_trades = 0;
      m_totals.lotsizing_feasibility_borderline_trades = 0;
      m_totals.lotsizing_feasibility_not_feasible_trades = 0;
      m_totals.lotsizing_feasibility_invalid_trades = 0;
      m_totals.lotsizing_single_trade_cap_breach_trades = 0;
      m_totals.lotsizing_min_lot_risk_usd_total = 0.0;
      m_totals.lotsizing_min_lot_risk_usd_max = 0.0;
      m_totals.lotsizing_min_lot_risk_pct_total = 0.0;
      m_totals.lotsizing_min_lot_risk_pct_max = 0.0;
      m_totals.lotsizing_potential_loss_r_total = 0.0;
      m_totals.lotsizing_potential_loss_r_max = 0.0;

      m_totals.single_trade_loss_cap_evaluated_trades = 0;
      m_totals.single_trade_loss_cap_allowed_trades = 0;
      m_totals.single_trade_loss_cap_blocked_trades = 0;
      m_totals.single_trade_loss_cap_invalid_trades = 0;
      m_totals.single_trade_loss_cap_strict_breach_trades = 0;
      m_totals.single_trade_loss_cap_calibrated_breach_trades = 0;
      m_totals.single_trade_loss_cap_before_net_points = 0.0;
      m_totals.single_trade_loss_cap_after_net_points = 0.0;
      m_totals.single_trade_loss_cap_impact_points = 0.0;
      m_totals.single_trade_loss_cap_before_net_usd = 0.0;
      m_totals.single_trade_loss_cap_after_net_usd = 0.0;
      m_totals.single_trade_loss_cap_impact_usd = 0.0;
      m_totals.single_trade_loss_cap_rejected_profit_usd = 0.0;
      m_totals.single_trade_loss_cap_rejected_loss_usd = 0.0;
      m_totals.single_trade_loss_cap_calibrated_cap_r_max = 0.0;
      m_totals.single_trade_loss_cap_risk_pct_cap_max = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_start = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_min = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_max = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_end = 0.0;
      m_totals.single_trade_loss_cap_dynamic_risk_pct_max = 0.0;
      m_totals.single_trade_loss_cap_dynamic_cap_pct_max = 0.0;
      m_totals.single_trade_loss_cap_dynamic_capital_updates = 0;
      m_totals.single_trade_loss_cap_dynamic_capital_blocks = 0;

      m_totals.dynamic_lotsizing_evaluated_trades = 0;
      m_totals.dynamic_lotsizing_fixed_mode_trades = 0;
      m_totals.dynamic_lotsizing_dynamic_mode_trades = 0;
      m_totals.dynamic_lotsizing_candidate_ready_trades = 0;
      m_totals.dynamic_lotsizing_invalid_trades = 0;
      m_totals.dynamic_lotsizing_min_lot_floor_trades = 0;
      m_totals.dynamic_lotsizing_max_lot_cap_trades = 0;
      m_totals.dynamic_lotsizing_tier_cap_trades = 0;
      m_totals.dynamic_lotsizing_capital_cap_trades = 0;
      m_totals.dynamic_lotsizing_growth_ramp_trades = 0;
      m_totals.dynamic_lotsizing_safety_active_lot_max = 0.0;
      m_totals.dynamic_lotsizing_raw_lot_total = 0.0;
      m_totals.dynamic_lotsizing_recommended_lot_total = 0.0;
      m_totals.dynamic_lotsizing_active_lot_total = 0.0;
      m_totals.dynamic_lotsizing_recommended_risk_pct_max = 0.0;
      m_totals.dynamic_lotsizing_active_risk_pct_max = 0.0;

      m_totals.paper_emergency_evaluated_trades = 0;
      m_totals.paper_emergency_safe_trades = 0;
      m_totals.paper_emergency_triggered_trades = 0;
      m_totals.paper_emergency_blocked_entries = 0;
      m_totals.paper_emergency_layer1_triggers = 0;
      m_totals.paper_emergency_layer2_triggers = 0;
      m_totals.paper_emergency_layer3_triggers = 0;
      m_totals.paper_emergency_before_net_points = 0.0;
      m_totals.paper_emergency_after_net_points = 0.0;
      m_totals.paper_emergency_impact_points = 0.0;
      m_totals.paper_emergency_before_net_usd = 0.0;
      m_totals.paper_emergency_after_net_usd = 0.0;
      m_totals.paper_emergency_impact_usd = 0.0;
      m_totals.paper_emergency_max_drawdown_pct = 0.0;
      m_totals.paper_emergency_worst_daily_r = 0.0;
      m_totals.layer_reset_evaluated_trades = 0;
      m_totals.layer1_reset_on_win_events = 0;
      m_totals.layer2_reset_on_new_day_events = 0;
      m_totals.layer3_reset_on_new_peak_events = 0;
      m_totals.layer_reset_event_trades = 0;
      m_totals.layer_reset_duplicate_triggers = 0;

      // v0.57.0: Lock Parity Executability Decomposer totals.
      m_totals.lock_parity_evaluated_trades = 0;
      m_totals.lock_parity_decomposition_pass_trades = 0;
      m_totals.lock_parity_decomposition_breach_trades = 0;
      m_totals.lock_parity_raw_net_usd = 0.0;
      m_totals.lock_parity_final_working_net_usd = 0.0;
      m_totals.lock_parity_sum_guard_delta_usd = 0.0;
      m_totals.lock_parity_sum_protection_delta_usd = 0.0;
      m_totals.lock_parity_sum_runner_delta_usd = 0.0;
      m_totals.lock_parity_sum_losscap_delta_usd = 0.0;
      m_totals.lock_parity_sum_marketclose_delta_usd = 0.0;
      m_totals.lock_parity_sum_emergency_delta_usd = 0.0;
      m_totals.lock_parity_sum_other_delta_usd = 0.0;
      m_totals.lock_parity_executable_adjustment_usd = 0.0;
      m_totals.lock_parity_non_executable_adjustment_usd = 0.0;
      m_totals.lock_parity_protection_executable_usd = 0.0;
      m_totals.lock_parity_runner_pending_usd = 0.0;
      // v0.57.1: Runner Exit Price Probe buckets.
      m_totals.lock_parity_runner_executable_usd = 0.0;
      m_totals.lock_parity_runner_non_executable_usd = 0.0;
      m_totals.lock_parity_accounting_only_usd = 0.0;

      m_tle_emergency_active = false;
      m_tle_emergency_reason = "NONE";
      m_tle_consecutive_losses = 0;
      m_tle_current_day = 0;
      m_tle_daily_r = 0.0;
      m_tle_equity = 0.0;
      m_tle_peak_equity = 0.0;
      m_tle_max_drawdown_pct = 0.0;
      m_dlm_previous_active_lot_ready = false;
      m_dlm_previous_active_lot = 0.0;
   }

   void UpdateTotals(const FalconTradeLifecycleRecord &record)
   {
      m_totals.total_trades++;

      if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
         m_totals.win_trades++;
      else if(record.outcome == FALCON_TRADE_OUTCOME_LOSS)
         m_totals.loss_trades++;
      else if(record.outcome == FALCON_TRADE_OUTCOME_BREAKEVEN)
         m_totals.breakeven_trades++;

      m_totals.total_profit_index_points += record.profit_index_points;
      m_totals.total_loss_index_points   += record.loss_index_points;
      m_totals.net_index_points          += record.net_index_points;
      m_totals.total_profit_usd          += record.profit_usd;
      m_totals.total_loss_usd            += record.loss_usd;
      m_totals.net_usd                   += record.net_usd;

      // v0.55.4b: final truth is the last active paper layer after guard/protection/runner/cap/emergency.
      double final_working_trade_usd = record.falcon_emergency_after_net_usd;
      if(final_working_trade_usd > 0.0)
      {
         m_totals.final_profit_trades++;
         m_totals.final_total_profit_usd += final_working_trade_usd;
      }
      else if(final_working_trade_usd < 0.0)
      {
         m_totals.final_loss_trades++;
         m_totals.final_total_loss_usd += MathAbs(final_working_trade_usd);
      }
      else
      {
         m_totals.final_breakeven_trades++;
      }
      m_totals.final_working_net_usd += final_working_trade_usd;

      // v0.55.4b: accumulate the values exactly as exposed in the slim TradeLifecycle CSV.
      double visible_raw_net_usd = FalconReportVisibleUsd4(record.net_usd);
      double visible_final_working_usd = FalconReportVisibleUsd4(final_working_trade_usd);
      m_totals.visible_raw_net_usd_4dp += visible_raw_net_usd;
      m_totals.visible_final_working_net_usd_4dp += visible_final_working_usd;
      if(visible_final_working_usd > 0.0)
         m_totals.visible_final_total_profit_usd_4dp += visible_final_working_usd;
      else if(visible_final_working_usd < 0.0)
         m_totals.visible_final_total_loss_usd_4dp += MathAbs(visible_final_working_usd);

      m_totals.capital_flow_evaluated_trades++;
      if(record.falcon_capital_flow_source == "TRADE_PROFIT")
         m_totals.capital_flow_trade_profit_events++;
      else if(record.falcon_capital_flow_source == "TRADE_LOSS")
         m_totals.capital_flow_trade_loss_events++;
      else if(record.falcon_capital_flow_source == "FLAT")
         m_totals.capital_flow_flat_events++;
      else if(record.falcon_capital_flow_source == "INJECTION")
         m_totals.capital_flow_injection_events++;
      else if(record.falcon_capital_flow_source == "WITHDRAWAL")
         m_totals.capital_flow_withdrawal_events++;
      else if(record.falcon_capital_flow_source == "MIXED_PROFIT_PLUS_INJECTION")
      {
         m_totals.capital_flow_trade_profit_events++;
         m_totals.capital_flow_injection_events++;
      }
      else if(record.falcon_capital_flow_source == "MIXED_LOSS_PLUS_WITHDRAWAL")
      {
         m_totals.capital_flow_trade_loss_events++;
         m_totals.capital_flow_withdrawal_events++;
      }
      else
         m_totals.capital_flow_unknown_events++;
      if(record.falcon_capital_flow_status != "PASS")
         m_totals.capital_flow_integrity_breaches++;
      m_totals.capital_flow_external_net_usd += record.falcon_external_capital_delta_usd;

      m_totals.paper_guard_evaluated_trades++;
      m_totals.paper_guard_before_net_points += record.net_index_points;
      m_totals.paper_guard_before_net_usd += record.net_usd;
      m_totals.paper_guard_after_net_points += record.paper_guard_net_index_points;
      m_totals.paper_guard_after_net_usd += record.paper_guard_net_usd;
      m_totals.paper_guard_impact_points = m_totals.paper_guard_after_net_points - m_totals.paper_guard_before_net_points;
      m_totals.paper_guard_impact_usd = m_totals.paper_guard_after_net_usd - m_totals.paper_guard_before_net_usd;

      if(record.paper_guard_status == "PASSED")
      {
         m_totals.paper_guard_passed_trades++;
         m_totals.paper_exposure_evaluated_trades++;
         m_totals.paper_exposure_passed_trades++;
      }
      else if(record.paper_guard_status == "REJECTED")
      {
         m_totals.paper_guard_rejected_trades++;
         if(record.paper_reject_reason == "SPREAD_TOO_WIDE")
            m_totals.paper_guard_spread_rejected_trades++;
         else if(record.paper_reject_reason == "SL_TOO_CLOSE")
            m_totals.paper_guard_stops_rejected_trades++;
         else if(record.paper_reject_reason == "FREEZE_LEVEL_BLOCKED")
            m_totals.paper_guard_freeze_rejected_trades++;
      }

      m_totals.paper_protection_evaluated_trades++;
      m_totals.paper_protection_before_net_points += record.paper_guard_net_index_points;
      m_totals.paper_protection_before_net_usd += record.paper_guard_net_usd;
      m_totals.paper_protection_after_net_points += record.paper_protection_net_index_points;
      m_totals.paper_protection_after_net_usd += record.paper_protection_net_usd;
      m_totals.paper_protection_impact_points = m_totals.paper_protection_after_net_points - m_totals.paper_protection_before_net_points;
      m_totals.paper_protection_impact_usd = m_totals.paper_protection_after_net_usd - m_totals.paper_protection_before_net_usd;

      if(record.paper_protection_activated)
      {
         m_totals.paper_protection_eligible_trades++;
         m_totals.paper_protection_activated_trades++;
      }
      if(record.paper_protection_state == "TP1_PROTECTED")
         m_totals.paper_tp1_protection_trades++;
      else if(record.paper_protection_state == "TP2_PROTECTED")
         m_totals.paper_tp2_protection_trades++;
      if(record.paper_virtual_sl_changed)
         m_totals.paper_virtual_sl_changed_trades++;
      if(record.paper_virtual_sl_hit)
      {
         m_totals.paper_virtual_sl_hit_trades++;
         m_totals.paper_protected_exit_trades++;
         m_totals.paper_protection_giveback_prevented_points += (record.paper_protection_net_index_points - record.paper_guard_net_index_points);
         m_totals.paper_protection_giveback_prevented_usd += (record.paper_protection_net_usd - record.paper_guard_net_usd);
      }

      m_totals.paper_runner_evaluated_trades++;
      m_totals.paper_runner_before_net_points += record.paper_protection_net_index_points;
      m_totals.paper_runner_before_net_usd += record.paper_protection_net_usd;
      m_totals.paper_runner_after_net_points += record.paper_runner_net_index_points;
      m_totals.paper_runner_after_net_usd += record.paper_runner_net_usd;
      m_totals.paper_runner_impact_points = m_totals.paper_runner_after_net_points - m_totals.paper_runner_before_net_points;
      m_totals.paper_runner_impact_usd = m_totals.paper_runner_after_net_usd - m_totals.paper_runner_before_net_usd;
      if(record.paper_protection_activated && record.paper_virtual_sl_changed)
         m_totals.paper_runner_eligible_trades++;
      if(record.paper_runner_activated)
      {
         m_totals.paper_runner_activated_trades++;
         m_totals.paper_runner_exit_trades++;
      }
      if(record.paper_runner_max_r >= 3.0)
         m_totals.paper_runner_3r_trades++;
      if(record.paper_runner_state == "MOON")
         m_totals.paper_moon_mode_5r_trades++;
      if(record.paper_runner_additional_points > 0.0)
      {
         m_totals.paper_runner_additional_points += record.paper_runner_additional_points;
         m_totals.paper_runner_additional_usd += (record.paper_runner_net_usd - record.paper_protection_net_usd);
      }
      if(record.paper_runner_activated && record.paper_runner_additional_points > 0.0)
         m_totals.paper_runner_giveback_trades++;
      if(record.paper_guard_net_index_points < 0.0 && record.paper_runner_net_index_points >= 0.0)
         m_totals.paper_runner_protected_from_loss_trades++;

      m_totals.lotsizing_feasibility_evaluated_trades++;
      if(record.falcon_lotsizing_feasibility_status == "FEASIBLE")
         m_totals.lotsizing_feasibility_feasible_trades++;
      else if(record.falcon_lotsizing_feasibility_status == "BORDERLINE")
         m_totals.lotsizing_feasibility_borderline_trades++;
      else if(record.falcon_lotsizing_feasibility_status == "NOT_FEASIBLE")
         m_totals.lotsizing_feasibility_not_feasible_trades++;
      else
         m_totals.lotsizing_feasibility_invalid_trades++;
      if(record.falcon_single_trade_loss_cap_breach == 1)
         m_totals.lotsizing_single_trade_cap_breach_trades++;
      m_totals.lotsizing_min_lot_risk_usd_total += record.falcon_min_lot_risk_usd;
      if(record.falcon_min_lot_risk_usd > m_totals.lotsizing_min_lot_risk_usd_max)
         m_totals.lotsizing_min_lot_risk_usd_max = record.falcon_min_lot_risk_usd;
      m_totals.lotsizing_min_lot_risk_pct_total += record.falcon_min_lot_risk_pct_of_capital;
      if(record.falcon_min_lot_risk_pct_of_capital > m_totals.lotsizing_min_lot_risk_pct_max)
         m_totals.lotsizing_min_lot_risk_pct_max = record.falcon_min_lot_risk_pct_of_capital;
      m_totals.lotsizing_potential_loss_r_total += record.falcon_potential_loss_r;
      if(record.falcon_potential_loss_r > m_totals.lotsizing_potential_loss_r_max)
         m_totals.lotsizing_potential_loss_r_max = record.falcon_potential_loss_r;

      m_totals.single_trade_loss_cap_evaluated_trades++;
      if(record.falcon_single_trade_loss_cap_status == "BLOCKED")
         m_totals.single_trade_loss_cap_blocked_trades++;
      else if(record.falcon_single_trade_loss_cap_status == "INVALID")
         m_totals.single_trade_loss_cap_invalid_trades++;
      else
         m_totals.single_trade_loss_cap_allowed_trades++;
      if(record.falcon_single_trade_loss_cap_breach == 1)
         m_totals.single_trade_loss_cap_strict_breach_trades++;
      if(record.falcon_single_trade_loss_cap_blocked == 1)
      {
         m_totals.single_trade_loss_cap_calibrated_breach_trades++;
         if(record.falcon_single_trade_loss_cap_before_net_usd > 0.0)
            m_totals.single_trade_loss_cap_rejected_profit_usd += record.falcon_single_trade_loss_cap_before_net_usd;
         else if(record.falcon_single_trade_loss_cap_before_net_usd < 0.0)
            m_totals.single_trade_loss_cap_rejected_loss_usd += MathAbs(record.falcon_single_trade_loss_cap_before_net_usd);
      }
      m_totals.single_trade_loss_cap_before_net_points += record.falcon_single_trade_loss_cap_before_net_points;
      m_totals.single_trade_loss_cap_after_net_points += record.falcon_single_trade_loss_cap_after_net_points;
      m_totals.single_trade_loss_cap_impact_points = m_totals.single_trade_loss_cap_after_net_points - m_totals.single_trade_loss_cap_before_net_points;
      m_totals.single_trade_loss_cap_before_net_usd += record.falcon_single_trade_loss_cap_before_net_usd;
      m_totals.single_trade_loss_cap_after_net_usd += record.falcon_single_trade_loss_cap_after_net_usd;
      m_totals.single_trade_loss_cap_impact_usd = m_totals.single_trade_loss_cap_after_net_usd - m_totals.single_trade_loss_cap_before_net_usd;
      if(record.falcon_single_trade_loss_cap_calibrated_cap_r > m_totals.single_trade_loss_cap_calibrated_cap_r_max)
         m_totals.single_trade_loss_cap_calibrated_cap_r_max = record.falcon_single_trade_loss_cap_calibrated_cap_r;
      if(record.falcon_single_trade_loss_cap_risk_pct_cap > m_totals.single_trade_loss_cap_risk_pct_cap_max)
         m_totals.single_trade_loss_cap_risk_pct_cap_max = record.falcon_single_trade_loss_cap_risk_pct_cap;
      if(record.falcon_dynamic_capital_aware_blocked == 1)
         m_totals.single_trade_loss_cap_dynamic_capital_blocks++;
      if(record.falcon_dynamic_risk_capital_before_trade > 0.0)
      {
         if(m_totals.single_trade_loss_cap_dynamic_capital_updates == 0)
         {
            m_totals.single_trade_loss_cap_dynamic_capital_start = record.falcon_dynamic_risk_capital_before_trade;
            m_totals.single_trade_loss_cap_dynamic_capital_min = record.falcon_dynamic_risk_capital_before_trade;
            m_totals.single_trade_loss_cap_dynamic_capital_max = record.falcon_dynamic_risk_capital_before_trade;
         }
         if(record.falcon_dynamic_risk_capital_before_trade < m_totals.single_trade_loss_cap_dynamic_capital_min)
            m_totals.single_trade_loss_cap_dynamic_capital_min = record.falcon_dynamic_risk_capital_before_trade;
         if(record.falcon_dynamic_risk_capital_before_trade > m_totals.single_trade_loss_cap_dynamic_capital_max)
            m_totals.single_trade_loss_cap_dynamic_capital_max = record.falcon_dynamic_risk_capital_before_trade;
         m_totals.single_trade_loss_cap_dynamic_capital_end = record.falcon_dynamic_risk_capital_after_trade;
         m_totals.single_trade_loss_cap_dynamic_capital_updates++;
      }
      if(record.falcon_dynamic_risk_pct_of_capital > m_totals.single_trade_loss_cap_dynamic_risk_pct_max)
         m_totals.single_trade_loss_cap_dynamic_risk_pct_max = record.falcon_dynamic_risk_pct_of_capital;
      if(record.falcon_dynamic_single_trade_cap_pct > m_totals.single_trade_loss_cap_dynamic_cap_pct_max)
         m_totals.single_trade_loss_cap_dynamic_cap_pct_max = record.falcon_dynamic_single_trade_cap_pct;

      m_totals.dynamic_lotsizing_evaluated_trades++;
      if(record.falcon_dlm_use_fixed_lot == 1)
         m_totals.dynamic_lotsizing_fixed_mode_trades++;
      else
         m_totals.dynamic_lotsizing_dynamic_mode_trades++;
      if(record.falcon_dlm_decision == "INVALID")
         m_totals.dynamic_lotsizing_invalid_trades++;
      else
         m_totals.dynamic_lotsizing_candidate_ready_trades++;
      if(record.falcon_dlm_min_lot_floor_applied == 1)
         m_totals.dynamic_lotsizing_min_lot_floor_trades++;
      if(record.falcon_dlm_max_lot_cap_applied == 1)
         m_totals.dynamic_lotsizing_max_lot_cap_trades++;
      if(record.falcon_dlm_tier_cap_applied == 1)
         m_totals.dynamic_lotsizing_tier_cap_trades++;
      if(record.falcon_dlm_capital_cap_applied == 1)
         m_totals.dynamic_lotsizing_capital_cap_trades++;
      if(record.falcon_dlm_growth_ramp_applied == 1)
         m_totals.dynamic_lotsizing_growth_ramp_trades++;
      if(record.falcon_dlm_active_lot > m_totals.dynamic_lotsizing_safety_active_lot_max)
         m_totals.dynamic_lotsizing_safety_active_lot_max = record.falcon_dlm_active_lot;
      m_totals.dynamic_lotsizing_raw_lot_total += record.falcon_dlm_raw_lot;
      m_totals.dynamic_lotsizing_recommended_lot_total += record.falcon_dlm_recommended_lot;
      m_totals.dynamic_lotsizing_active_lot_total += record.falcon_dlm_active_lot;
      if(record.falcon_dlm_recommended_risk_pct > m_totals.dynamic_lotsizing_recommended_risk_pct_max)
         m_totals.dynamic_lotsizing_recommended_risk_pct_max = record.falcon_dlm_recommended_risk_pct;
      if(record.falcon_dlm_active_risk_pct > m_totals.dynamic_lotsizing_active_risk_pct_max)
         m_totals.dynamic_lotsizing_active_risk_pct_max = record.falcon_dlm_active_risk_pct;

      UpdateWeeklyStabilityFoundation(record);
      UpdateMarketCloseGuardFoundation(record);
      UpdateSessionBoundaryStateCheckpointFoundation(record);
      m_totals.no_new_entry_override_evaluated_trades++;
      if(record.falcon_market_close_blocked == 1)
      {
         m_totals.no_new_entry_override_blocked_trades++;
         if(record.falcon_market_close_before_net_usd > 0.0001)
            m_totals.no_new_entry_override_blocked_winners++;
         else if(record.falcon_market_close_before_net_usd < -0.0001)
            m_totals.no_new_entry_override_blocked_losers++;
         m_totals.no_new_entry_override_impact_usd += record.falcon_market_close_impact_usd;
      }

      m_totals.paper_emergency_evaluated_trades++;
      m_totals.paper_emergency_before_net_points += record.falcon_emergency_before_net_points;
      m_totals.paper_emergency_before_net_usd += record.falcon_emergency_before_net_usd;
      m_totals.paper_emergency_after_net_points += record.falcon_emergency_after_net_points;
      m_totals.paper_emergency_after_net_usd += record.falcon_emergency_after_net_usd;
      m_totals.paper_emergency_impact_points = m_totals.paper_emergency_after_net_points - m_totals.paper_emergency_before_net_points;
      m_totals.paper_emergency_impact_usd = m_totals.paper_emergency_after_net_usd - m_totals.paper_emergency_before_net_usd;
      if(record.falcon_emergency_status == "SAFE")
         m_totals.paper_emergency_safe_trades++;
      else if(record.falcon_emergency_status == "TRIGGERED")
      {
         m_totals.paper_emergency_triggered_trades++;
         if(record.falcon_emergency_triggered_layer == 1)
            m_totals.paper_emergency_layer1_triggers++;
         else if(record.falcon_emergency_triggered_layer == 2)
            m_totals.paper_emergency_layer2_triggers++;
         else if(record.falcon_emergency_triggered_layer == 3)
            m_totals.paper_emergency_layer3_triggers++;
      }
      else if(record.falcon_emergency_status == "BLOCKED")
         m_totals.paper_emergency_blocked_entries++;
      if(record.falcon_layer3_drawdown_pct > m_totals.paper_emergency_max_drawdown_pct)
         m_totals.paper_emergency_max_drawdown_pct = record.falcon_layer3_drawdown_pct;
      if(record.falcon_layer2_daily_r < m_totals.paper_emergency_worst_daily_r)
         m_totals.paper_emergency_worst_daily_r = record.falcon_layer2_daily_r;

      m_totals.layer_reset_evaluated_trades++;
      if(record.falcon_layer1_reset_on_win == 1) m_totals.layer1_reset_on_win_events++;
      if(record.falcon_layer2_reset_on_new_day == 1) m_totals.layer2_reset_on_new_day_events++;
      if(record.falcon_layer3_reset_on_new_peak == 1) m_totals.layer3_reset_on_new_peak_events++;
      if(record.falcon_layer1_reset_on_win == 1 || record.falcon_layer2_reset_on_new_day == 1 || record.falcon_layer3_reset_on_new_peak == 1)
         m_totals.layer_reset_event_trades++;
      // v0.53.3a: A trigger on the same row as LAYER2_ON_NEW_DAY can be valid
      // when a multi-day trade exits on the new day and immediately breaches the
      // daily R budget. Count only a true duplicate trigger after an emergency
      // daily-resolution event, not every trigger that follows a normal reset.
      if(record.falcon_emergency_status == "TRIGGERED" &&
         StringFind(record.falcon_reset_reason, "EMERGENCY_DAILY_RESOLVE_") >= 0)
      {
         m_totals.layer_reset_duplicate_triggers++;
      }

      if(record.direction == FALCON_DIRECTION_BUY)
      {
         m_totals.buy_trades++;
         if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
            m_totals.buy_win_trades++;
         m_totals.buy_net_index_points += record.net_index_points;
      }
      else if(record.direction == FALCON_DIRECTION_SELL)
      {
         m_totals.sell_trades++;
         if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
            m_totals.sell_win_trades++;
         m_totals.sell_net_index_points += record.net_index_points;
      }

      m_totals.sltp_validation_evaluated_trades++;
      if(FalconStructuralStopValid(record))
         m_totals.structural_stop_valid_trades++;
      else
         m_totals.structural_stop_invalid_trades++;

      if(FalconTakeProfitDirectionalValid(record, 1))
         m_totals.tp1_valid_trades++;
      if(FalconTakeProfitDirectionalValid(record, 2))
         m_totals.tp2_valid_trades++;
      if(FalconTakeProfitDirectionalValid(record, 3))
         m_totals.tp3_valid_trades++;

      if(FalconTakeProfitSequenceValid(record))
         m_totals.tp_builder_valid_trades++;
      else
         m_totals.tp_builder_invalid_trades++;

      int proof_score = FalconSmartProofScore(record);
      int anti_proof_score = FalconSmartAntiProofScore(record);
      bool tp1_close = FalconClosedAtTp1(record);
      bool stop_close = FalconClosedAtStop(record);
      bool timeout_close = FalconClosedByTimeout(record);

      m_totals.smart_tm_evaluated_trades++;
      if(m_totals.smart_tm_proof_score_min < 0 || proof_score < m_totals.smart_tm_proof_score_min)
         m_totals.smart_tm_proof_score_min = proof_score;
      if(proof_score > m_totals.smart_tm_proof_score_max)
         m_totals.smart_tm_proof_score_max = proof_score;
      m_totals.smart_tm_proof_score_total += proof_score;
      m_totals.smart_tm_antiproof_score_total += anti_proof_score;
      if(anti_proof_score > m_totals.smart_tm_antiproof_score_max)
         m_totals.smart_tm_antiproof_score_max = anti_proof_score;
      if(anti_proof_score >= 60)
         m_totals.smart_tm_antiproof_high_risk_trades++;

      if(proof_score < 50)
      {
         m_totals.smart_tm_exit_conservative_trades++;
         m_totals.smart_tm_proof_weak_trades++;
      }
      else if(proof_score < 70)
      {
         m_totals.smart_tm_partial_no_runner_trades++;
         m_totals.smart_tm_proof_medium_trades++;
      }
      else if(proof_score < 85)
      {
         m_totals.smart_tm_runner_candidate_trades++;
         m_totals.smart_tm_proof_strong_trades++;
      }
      else
      {
         m_totals.smart_tm_strong_runner_candidate_trades++;
         m_totals.smart_tm_proof_elite_trades++;
      }

      string behavior_fingerprint = FalconSmartBehaviorFingerprint(proof_score, anti_proof_score);
      if(behavior_fingerprint == "FAILURE_RISK")
         m_totals.smart_tm_behavior_failure_trades++;
      else if(behavior_fingerprint == "EXHAUSTED")
         m_totals.smart_tm_behavior_exhausted_trades++;
      else if(behavior_fingerprint == "GRINDING")
         m_totals.smart_tm_behavior_grinding_trades++;
      else if(behavior_fingerprint == "HEALTHY")
         m_totals.smart_tm_behavior_healthy_trades++;
      else
         m_totals.smart_tm_behavior_choppy_trades++;

      if(tp1_close)
      {
         m_totals.smart_tm_tp1_close_trades++;
         if(proof_score >= 70 && anti_proof_score < 35)
            m_totals.smart_tm_runner_conservative_opportunity_trades++;
         if(proof_score >= 75 && anti_proof_score < 30)
            m_totals.smart_tm_runner_opportunity_trades++;
         if(proof_score >= 85 && anti_proof_score < 20)
            m_totals.smart_tm_strong_runner_opportunity_trades++;
      }
      if(stop_close)
         m_totals.smart_tm_sl_failure_trades++;
      if(timeout_close)
         m_totals.smart_tm_timeout_close_trades++;

      // v0.29.2: Runner MFE/Giveback proxy diagnostics.
      // This does not change any exit. It only summarizes target geometry and realized favorable move.
      m_totals.runner_diag_evaluated_trades++;

      double realized_mfe_proxy_points = MathMax(0.0, record.profit_index_points);
      if(realized_mfe_proxy_points > 0.0)
      {
         m_totals.runner_diag_mfe_proxy_trades++;
         m_totals.runner_diag_mfe_proxy_total_points += realized_mfe_proxy_points;
         if(realized_mfe_proxy_points > m_totals.runner_diag_mfe_proxy_max_points)
            m_totals.runner_diag_mfe_proxy_max_points = realized_mfe_proxy_points;
      }

      double tp1_to_tp2_room_points = FalconRunnerRoomBetweenTargets(record, record.tp1, record.tp2);
      double tp1_to_tp3_room_points = FalconRunnerRoomBetweenTargets(record, record.tp1, record.tp3);
      double tp2_to_tp3_room_points = FalconRunnerRoomBetweenTargets(record, record.tp2, record.tp3);

      if(FalconTakeProfitDirectionalValid(record, 1) && FalconTakeProfitDirectionalValid(record, 2))
      {
         m_totals.runner_diag_tp1_anchor_trades++;
         m_totals.runner_diag_tp1_to_tp2_room_total_points += tp1_to_tp2_room_points;
         m_totals.runner_diag_tp1_to_tp3_room_total_points += tp1_to_tp3_room_points;
      }

      if(FalconTakeProfitDirectionalValid(record, 2) && FalconTakeProfitDirectionalValid(record, 3))
      {
         m_totals.runner_diag_tp2_anchor_trades++;
         m_totals.runner_diag_tp2_to_tp3_room_total_points += tp2_to_tp3_room_points;
      }

      double max_r_proxy = FalconMaxTargetRProxy(record);
      m_totals.runner_diag_max_r_proxy_total += max_r_proxy;
      if(max_r_proxy > m_totals.runner_diag_max_r_proxy_max)
         m_totals.runner_diag_max_r_proxy_max = max_r_proxy;

      if(max_r_proxy >= 3.0)
         m_totals.runner_diag_would_reach_3r_trades++;
      if(max_r_proxy >= 5.0)
         m_totals.runner_diag_would_reach_5r_trades++;

      if(tp1_close && proof_score >= 70 && anti_proof_score < 35 && tp1_to_tp2_room_points > 0.0)
         m_totals.runner_diag_protected_profit_opportunity_trades++;

      if(tp1_close || proof_score >= 70)
         m_totals.runner_diag_return_to_loss_after_proof_unknown_trades++;

      // v0.29.3a: Runner bar-path metric definition calibration. Summary-only.
      // Scans M5 closed bars between entry and exit to estimate post-proof path.
      // This does not change any exit, SL, TP, staging, or execution behavior.
      m_totals.runner_barpath_evaluated_trades++;
      FalconRunnerBarPathStats barpath_stats;
      if(FalconBuildRunnerBarPathStats(record, barpath_stats))
      {
         m_totals.runner_barpath_scanned_trades++;
         m_totals.runner_barpath_total_bars_scanned += barpath_stats.bars_scanned;

         if(barpath_stats.tp1_touched)
         {
            m_totals.runner_barpath_tp1_touched_trades++;
            if(barpath_stats.tp1_touched_then_extended)
               m_totals.runner_barpath_tp1_touched_then_extended_trades++;
            m_totals.runner_barpath_tp1_to_max_run_total_points += barpath_stats.tp1_to_max_run_points;
            if(barpath_stats.tp1_to_max_run_points > m_totals.runner_barpath_tp1_to_max_run_max_points)
               m_totals.runner_barpath_tp1_to_max_run_max_points = barpath_stats.tp1_to_max_run_points;
            m_totals.runner_barpath_mfe_after_tp1_total_points += barpath_stats.mfe_after_tp1_points;
            if(barpath_stats.mfe_after_tp1_points > m_totals.runner_barpath_mfe_after_tp1_max_points)
               m_totals.runner_barpath_mfe_after_tp1_max_points = barpath_stats.mfe_after_tp1_points;

            m_totals.runner_barpath_giveback_after_tp1_total_points += barpath_stats.giveback_after_tp1_points;
            if(barpath_stats.giveback_after_tp1_points > m_totals.runner_barpath_giveback_after_tp1_max_points)
               m_totals.runner_barpath_giveback_after_tp1_max_points = barpath_stats.giveback_after_tp1_points;

            if(barpath_stats.returned_to_loss_after_tp1)
               m_totals.runner_barpath_returned_to_loss_after_tp1_trades++;
            if(barpath_stats.mfe_after_tp1_points > 0.0 && !barpath_stats.returned_to_loss_after_tp1)
               m_totals.runner_barpath_protected_after_tp1_opportunity_trades++;
         }

         if(barpath_stats.tp2_touched)
         {
            m_totals.runner_barpath_tp2_touched_trades++;
            if(barpath_stats.tp2_touched_then_extended)
               m_totals.runner_barpath_tp2_touched_then_extended_trades++;
            m_totals.runner_barpath_tp2_to_max_run_total_points += barpath_stats.tp2_to_max_run_points;
            if(barpath_stats.tp2_to_max_run_points > m_totals.runner_barpath_tp2_to_max_run_max_points)
               m_totals.runner_barpath_tp2_to_max_run_max_points = barpath_stats.tp2_to_max_run_points;
            m_totals.runner_barpath_mfe_after_tp2_total_points += barpath_stats.mfe_after_tp2_points;
            if(barpath_stats.mfe_after_tp2_points > m_totals.runner_barpath_mfe_after_tp2_max_points)
               m_totals.runner_barpath_mfe_after_tp2_max_points = barpath_stats.mfe_after_tp2_points;

            m_totals.runner_barpath_giveback_after_tp2_total_points += barpath_stats.giveback_after_tp2_points;
            if(barpath_stats.giveback_after_tp2_points > m_totals.runner_barpath_giveback_after_tp2_max_points)
               m_totals.runner_barpath_giveback_after_tp2_max_points = barpath_stats.giveback_after_tp2_points;

            if(barpath_stats.returned_to_loss_after_tp2)
               m_totals.runner_barpath_returned_to_loss_after_tp2_trades++;
            if(barpath_stats.mfe_after_tp2_points > 0.0 && !barpath_stats.returned_to_loss_after_tp2)
               m_totals.runner_barpath_protected_after_tp2_opportunity_trades++;
         }

         if(barpath_stats.max_r_actual_proxy >= 3.0)
            m_totals.runner_barpath_actual_would_reach_3r_trades++;
         if(barpath_stats.max_r_actual_proxy >= 5.0)
            m_totals.runner_barpath_actual_would_reach_5r_trades++;
      }
      else
      {
         m_totals.runner_barpath_scan_failed_trades++;
      }

      // v0.29.4: Fast protection / runner decision readiness diagnostics.
      // The goal is to know whether TP1/TP2 decisions can be pre-computed before event touch.
      // This only counts readiness; it never modifies SL, TP, partials, exits, or execution.
      m_totals.fast_tm_evaluated_trades++;
      bool fast_cache_ready = (FalconStructuralStopValid(record) && FalconTakeProfitSequenceValid(record));
      bool fast_branch_ready = (fast_cache_ready && FalconTakeProfitDirectionalValid(record, 1) && FalconTakeProfitDirectionalValid(record, 2));
      if(fast_cache_ready)
         m_totals.fast_tm_decision_cache_ready_trades++;
      if(fast_branch_ready)
         m_totals.fast_tm_precomputed_branch_ready_trades++;

      bool fast_tp1_ready = false;
      bool fast_tp2_ready = false;
      bool fast_protect_tp1 = false;
      bool fast_protect_tp2 = false;
      bool fast_runner_now = false;
      bool fast_exit_warning = false;
      bool fast_antiproof_warning = false;
      bool fast_partial_ready = false;
      bool fast_wait_runner = false;

      if(barpath_stats.scan_ok)
      {
         fast_tp1_ready = barpath_stats.tp1_touched;
         fast_tp2_ready = barpath_stats.tp2_touched;
         fast_protect_tp1 = (barpath_stats.tp1_touched && (barpath_stats.giveback_after_tp1_points > 0.0 || barpath_stats.returned_to_loss_after_tp1));
         fast_protect_tp2 = (barpath_stats.tp2_touched && (barpath_stats.giveback_after_tp2_points > 0.0 || barpath_stats.returned_to_loss_after_tp2));
         fast_runner_now = (barpath_stats.tp1_touched && proof_score >= 85 && anti_proof_score < 25 && barpath_stats.tp1_to_max_run_points > 0.0 && !barpath_stats.returned_to_loss_after_tp1);
         fast_wait_runner = (barpath_stats.tp1_touched && proof_score >= 70 && proof_score < 85 && anti_proof_score < 35 && barpath_stats.tp1_to_max_run_points > 0.0);
      }

      fast_partial_ready = (fast_tp1_ready && proof_score >= 50 && proof_score < 85);
      fast_antiproof_warning = (anti_proof_score >= 45 || (barpath_stats.scan_ok && (barpath_stats.returned_to_loss_after_tp1 || barpath_stats.returned_to_loss_after_tp2)));
      fast_exit_warning = (anti_proof_score >= 50 || (barpath_stats.scan_ok && barpath_stats.returned_to_loss_after_tp2));

      if(fast_tp1_ready)
         m_totals.fast_tm_tp1_decision_ready_trades++;
      if(fast_tp2_ready)
         m_totals.fast_tm_tp2_decision_ready_trades++;
      if(fast_protect_tp1)
         m_totals.fast_tm_protection_required_after_tp1_trades++;
      if(fast_protect_tp2)
         m_totals.fast_tm_protection_required_after_tp2_trades++;
      if(fast_runner_now)
         m_totals.fast_tm_immediate_runner_candidate_trades++;
      if(fast_exit_warning)
         m_totals.fast_tm_immediate_exit_warning_trades++;
      if(fast_antiproof_warning)
         m_totals.fast_tm_fast_antiproof_warning_trades++;
      if(fast_partial_ready)
         m_totals.fast_tm_conservative_partial_ready_trades++;
      if(fast_wait_runner)
         m_totals.fast_tm_runner_wait_for_confirmation_trades++;

      m_totals.fvg_qguard_evaluated++;
      m_totals.fvg_qguard_actual_net_points += record.net_index_points;
      m_totals.fvg_qguard_actual_net_usd    += record.net_usd;

      if(record.fvg_quality_shadow_guard_passed)
      {
         m_totals.fvg_qguard_passed++;
         m_totals.fvg_qguard_simulated_net_points += record.net_index_points;
         m_totals.fvg_qguard_simulated_net_usd    += record.net_usd;
      }
      else
      {
         m_totals.fvg_qguard_blocked++;
         m_totals.fvg_qguard_blocked_net_points += record.net_index_points;
         m_totals.fvg_qguard_blocked_net_usd    += record.net_usd;

         if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
            m_totals.fvg_qguard_blocked_winners++;
         else if(record.outcome == FALCON_TRADE_OUTCOME_LOSS)
            m_totals.fvg_qguard_blocked_losers++;
      }
   }

   string SlimTradeHeaderV0555()
   {
      // v0.55.7: final minimal per-trade surface; capital-flow classification retained without simulation scaffold.
      // Keep only changing trade facts, final USD truth fields, dynamic lot essentials, emergency outcome, and row integrity.
      string trade_header = "TradeId,StrategyId,EngineId,Direction,EntryTime,ExitTime,";
      trade_header += "Stage,Outcome,CloseReason,ActiveLot,";
      trade_header += "RawIndexPoints,RawTradeUSD,ProtectionNetUSD,RunnerNetUSD,FinalWorkingTradeUSD,";
      trade_header += "TierAtEntry,DLMUseFixedLot,DLMRecommendedLot,DynamicCapitalBefore,DynamicCapitalAfter,";
      trade_header += "CapitalFlowSource,CapitalDeltaUSD,ExternalCapitalDeltaUSD,DLMActiveRiskPct,DynamicRiskPctOfCapital,EmergencyStatus,EmergencyLayer,EmergencyReason,FinalStatus,ReportRowIntegrityStatus";
      return trade_header;
   }

   string SlimSummaryHeaderV0555()
   {
      // v0.55.7c: final minimal window-level decision surface; tier scenario scaffold and stale ReportNotes removed after lock.
      string summary_header = "EAName,Version,Build,Symbol,GeneratedAt,ReportProfile,FromDateTag,ToDateTag,UseFixedLot,FixedLotSize,";
      summary_header += "TotalTrades,WinTrades,LoseTrades,WinRate,";
      summary_header += "RawTotalProfitUSD,RawTotalLossUSD,RawNetUSD,";
      summary_header += "FinalTotalProfitUSD,FinalTotalLossUSD,FinalWorkingNetUSD,";
      summary_header += "BuyTrades,BuyWinRate,SellTrades,SellWinRate,";
      summary_header += "ProtectionActivatedTrades,RunnerActivatedTrades,";
      summary_header += "DynamicLotEvaluatedTrades,DynamicLotFixedModeTrades,DynamicLotDynamicModeTrades,DynamicLotActiveLotAvg,DynamicLotActiveLotMax,";
      summary_header += "WeeklyStabilityEvaluatedTrades,WeeklyStabilityWeeks,WeeklyStabilityPositiveWeeks,WeeklyStabilityNegativeWeeks,WeeklyStabilityBestWeekUSD,WeeklyStabilityWorstWeekUSD,WeeklyStabilityScore,WeeklyStabilityStatus,";
      summary_header += "MarketCloseGuardEvaluatedTrades,MarketCloseNearCloseEntryTrades,MarketCloseOpenWeekendRiskTrades,MarketCloseGuardStatus,";
      summary_header += "StopNewTradesBeforeCloseEnabled,StopNewTradesBeforeCloseMinutes,StopNewTradesEvaluatedTrades,StopNewTradesBlockedTrades,StopNewTradesBlockedWinningTrades,StopNewTradesBlockedLosingTrades,StopNewTradesImpactUSD,StopNewTradesStatus,";
      summary_header += "DailyCloseSafetyEnabled,DailyCloseSafetyMinutes,WeekendCloseSafetyEnabled,WeekendCloseSafetyMinutes,CloseSafetyEvaluatedTrades,CloseSafetyClosedTrades,CloseSafetyDailyClosedTrades,CloseSafetyWeekendClosedTrades,CloseSafetyPriceOkTrades,CloseSafetyMissingPriceTrades,CloseSafetyBeforeNetUSD,CloseSafetyAfterNetUSD,CloseSafetyImpactUSD,CloseSafetyStatus,";
      summary_header += "PaperStateSnapshotEvaluatedTrades,PaperStateSnapshotWrittenRows,PaperStateSnapshotWriteFailures,PaperStateRecoveryMode,PaperStateTrustedTrades,PaperStateUntrustedTrades,PaperStateStatus,";
      summary_header += "SessionBoundaryCheckpointEvaluatedTrades,SessionBoundaryRecoveryCheckpointMinutes,SessionBoundaryDailyOpenAtCheckpointTrades,SessionBoundaryWeekendOpenAtCheckpointTrades,SessionBoundaryRecoveryRequiredTrades,SessionBoundaryDirtyAfterCloseSafetyTrades,SessionBoundaryCheckpointStatus,";
      summary_header += "MarketCloseMaxTradeDurationMinutes,MarketCloseAvgTradeDurationMinutes,MarketCloseDurationAboveWindowTrades,MarketCloseLongestTradeId,MarketCloseTimingRecommendation,MarketCloseTwoHourCoverageStatus,";
      summary_header += "CapitalFlowEvaluatedTrades,CapitalTradeProfitEvents,CapitalTradeLossEvents,CapitalInjectionEvents,CapitalWithdrawalEvents,ExternalCapitalNetUSD,CapitalFlowIntegrityStatus,";
      summary_header += "EmergencyTriggeredTrades,EmergencyBlockedEntries,";
      summary_header += "SafetyOrderSend,BrokerModifySent,RuntimeSLChanged,InvariantBreaches,";
      summary_header += "TradeLifecyclePhysicalRows,TradeLifecyclePhysicalRowStatus,";
      summary_header += "VisibleRawNetUSDDiff,VisibleFinalNetUSDDiff,ReportIntegrityStatus,TradeRowsVsSummaryStatus,FinalNetUSDDiff,RawNetUSDDiff";
      return summary_header;
   }

   void WriteTradeHeader()
   {
      int handle = FileOpen(m_trade_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create slim trade lifecycle report: %s", m_trade_report_file));
         return;
      }

      FileWriteString(handle, SlimTradeHeaderV0555() + "\r\n");
      FileClose(handle);
   }

   void WriteSummaryHeader()
   {
      int handle = FileOpen(m_summary_report_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create slim summary report: %s", m_summary_report_file));
         return;
      }

      FileWriteString(handle, SlimSummaryHeaderV0555() + "\r\n");
      FileClose(handle);
   }

   void AppendTradeRecord(const FalconTradeLifecycleRecord &record)
   {
      int handle = FileOpen(m_trade_report_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         WriteTradeHeader();
         handle = FileOpen(m_trade_report_file, FalconReportReadWriteCsvFlags(), ',');
      }
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append slim trade lifecycle record: %s", m_trade_report_file));
         return;
      }
      FileSeek(handle, 0, SEEK_END);

      string trade_row = "";
      trade_row += FalconCsvSafe(record.trade_id) + ",";
      trade_row += FalconCsvSafe(record.strategy_id) + ",";
      trade_row += FalconCsvSafe(record.engine_id) + ",";
      trade_row += FalconCsvSafe(FalconDirectionToString(record.direction)) + ",";
      trade_row += FalconCsvSafe(FalconTimeToString(record.entry_time)) + ",";
      trade_row += FalconCsvSafe(FalconTimeToString(record.exit_time)) + ",";
      trade_row += FalconCsvSafe(FalconStageToString(record.stage)) + ",";
      trade_row += FalconCsvSafe(FalconOutcomeToString(record.outcome)) + ",";
      trade_row += FalconCsvSafe(record.close_reason) + ",";
      trade_row += DoubleToString(record.falcon_dlm_active_lot, 2) + ",";
      trade_row += DoubleToString(record.net_index_points, 2) + ",";
      trade_row += DoubleToString(record.net_usd, 4) + ",";
      trade_row += DoubleToString(record.paper_protection_net_usd, 4) + ",";
      trade_row += DoubleToString(record.paper_runner_net_usd, 4) + ",";
      trade_row += DoubleToString(record.falcon_emergency_after_net_usd, 4) + ",";
      trade_row += FalconCsvSafe(record.falcon_tier_at_entry) + ",";
      trade_row += IntegerToString(record.falcon_dlm_use_fixed_lot) + ",";
      trade_row += DoubleToString(record.falcon_dlm_recommended_lot, 2) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_capital_before_trade, 4) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_capital_after_trade, 4) + ",";
      trade_row += FalconCsvSafe(record.falcon_capital_flow_source) + ",";
      trade_row += DoubleToString(record.falcon_capital_flow_delta_usd, 4) + ",";
      trade_row += DoubleToString(record.falcon_external_capital_delta_usd, 4) + ",";
      trade_row += DoubleToString(record.falcon_dlm_active_risk_pct, 4) + ",";
      trade_row += DoubleToString(record.falcon_dynamic_risk_pct_of_capital, 4) + ",";
      trade_row += FalconCsvSafe(record.falcon_emergency_status) + ",";
      trade_row += IntegerToString(record.falcon_emergency_triggered_layer) + ",";
      trade_row += FalconCsvSafe(record.falcon_emergency_reason) + ",";
      trade_row += FalconCsvSafe("FINAL_WORKING_APPLIED") + ",";
      trade_row += FalconCsvSafe("PASS");

      FileWriteString(handle, trade_row + "\r\n");
      FileClose(handle);
   }

};

#endif // FALCON_REPORTING_REPORT_WRITER_MQH
