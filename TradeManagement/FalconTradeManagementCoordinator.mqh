//+------------------------------------------------------------------+
//| TradeManagement/FalconTradeManagementCoordinator.mqh             |
//| R1.4b - Phase 2b: the live trade-management coordinator.         |
//|                                                                  |
//| Per closed M5 bar, walks the EA's open broker positions (matched |
//| by the shared Falcon magic), builds a broker-side context for    |
//| each, calls every registered engine, and writes one audit row    |
//| per engine-evaluation. Phase 2b is OBSERVER-ONLY: it issues no   |
//| OrderSend / modify / close. The "apply decision" path is Phase 3 |
//| (built with the first real engine). Strategy-aware engine routing|
//| is also Phase 3+ (Backlog #57); here every Falcon-magic position |
//| is evaluated by every registered engine.                         |
//|                                                                  |
//| Depends on the report helpers (FalconBuildReportFileName /       |
//| FalconReportWriteCsvFlags / FalconCsvSafe / FalconTimeToString)  |
//| and FC_MAGIC_FVG_MICRO, so this file is #included in the main    |
//| .mq5 AFTER those are defined (not next to S01).                  |
//+------------------------------------------------------------------+
#ifndef FALCON_TRADE_MANAGEMENT_COORDINATOR_MQH
#define FALCON_TRADE_MANAGEMENT_COORDINATOR_MQH

#include "FalconTradeEngineContract.mqh"

class CFalconTradeManagementCoordinator
{
private:
   CFalconTradeEngine *m_engines[];
   datetime            m_last_bar_time;
   string              m_audit_file;
   bool                m_audit_header_written;

   void EnsureAuditHeader()
   {
      if(m_audit_header_written)
         return;
      if(StringLen(m_audit_file) == 0)
         m_audit_file = FalconBuildReportFileName("TradeManagementCoordinatorAudit");
      int handle = FileOpen(m_audit_file, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create TradeManagementCoordinatorAudit report: %s", m_audit_file));
         return;
      }
      string header = "ClosedBarTime,PositionTicket,StrategyId,EngineId,BarsSinceEntry,";
      header += "BrokerUnrealizedUSD,CurrentSL,DecisionAction,DecisionReason,AppliedAction";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
      m_audit_header_written = true;
   }

   void AppendAuditRow(const FalconManagedPositionContext &ctx,
                       const string engine_id,
                       const FalconTradeDecision &decision,
                       const string applied_action)
   {
      if(!TradeManagement_DiagReport)
         return;
      EnsureAuditHeader();
      int handle = FileOpen(m_audit_file, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
         return;
      FileSeek(handle, 0, SEEK_END);
      string row = "";
      row += FalconCsvSafe(FalconTimeToString(ctx.closed_bar_time)) + ",";
      row += IntegerToString((long)ctx.position_ticket) + ",";
      row += FalconCsvSafe(ctx.strategy_id) + ",";
      row += FalconCsvSafe(engine_id) + ",";
      row += IntegerToString(ctx.bars_since_entry) + ",";
      row += DoubleToString(ctx.broker_unrealized_usd, 2) + ",";
      row += DoubleToString(ctx.current_sl, _Digits) + ",";
      row += FalconCsvSafe(FalconTmActionToString(decision.action)) + ",";
      row += FalconCsvSafe(decision.reason) + ",";
      row += FalconCsvSafe(applied_action);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void BuildContext(FalconManagedPositionContext &ctx,
                     const ulong ticket,
                     const datetime closed_bar_time)
   {
      ctx.position_ticket       = ticket;
      ctx.strategy_id           = PositionGetString(POSITION_COMMENT); // broker-side origin hint; strategy routing is Phase 3+
      long ptype                = PositionGetInteger(POSITION_TYPE);
      ctx.direction             = (ptype == POSITION_TYPE_BUY ? FALCON_DIRECTION_BUY : FALCON_DIRECTION_SELL);
      ctx.broker_entry_price    = PositionGetDouble(POSITION_PRICE_OPEN);
      ctx.current_sl            = PositionGetDouble(POSITION_SL);
      ctx.current_tp            = PositionGetDouble(POSITION_TP);
      ctx.volume                = PositionGetDouble(POSITION_VOLUME);
      ctx.current_bid           = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ctx.current_ask           = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      ctx.broker_unrealized_usd = PositionGetDouble(POSITION_PROFIT);
      datetime entry_time       = (datetime)PositionGetInteger(POSITION_TIME);
      int psec                  = PeriodSeconds(PERIOD_M5);
      int bars                  = 0;
      if(entry_time > 0 && closed_bar_time > entry_time && psec > 0)
         bars = (int)((closed_bar_time - entry_time) / psec);
      ctx.bars_since_entry      = bars;
      ctx.closed_bar_time       = closed_bar_time;
   }

public:
   CFalconTradeManagementCoordinator()
   {
      m_last_bar_time        = 0;
      m_audit_file           = "";
      m_audit_header_written = false;
   }

   void RegisterEngine(CFalconTradeEngine *engine)
   {
      if(engine == NULL)
         return;
      int n = ArraySize(m_engines);
      ArrayResize(m_engines, n + 1);
      m_engines[n] = engine;
   }

   // Called once per closed M5 bar from OnTick (gated by Enable_TradeManagement).
   void EvaluateOnNewBar(CFalconMarketContext &market_context)
   {
      // Dedupe per closed M5 bar (mirrors the S01 harness pattern).
      FalconCandleSnapshot bar1;
      if(!market_context.GetCandleSnapshot(PERIOD_M5, 1, bar1))
         return;
      if(bar1.time == m_last_bar_time)
         return;
      m_last_bar_time = bar1.time;

      datetime closed_bar_time = bar1.time;
      string   symbol          = _Symbol;
      int      engine_count    = ArraySize(m_engines);

      int total = PositionsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != FC_MAGIC_FVG_MICRO)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;

         FalconManagedPositionContext ctx;
         BuildContext(ctx, ticket, closed_bar_time);

         for(int e = 0; e < engine_count; e++)
         {
            if(m_engines[e] == NULL)
               continue;
            FalconTradeDecision decision = m_engines[e].Evaluate(ctx);
            // Phase 2b applies NOTHING - observer only. A non-NO_ACTION
            // decision has no apply path yet (built in Phase 3); it is
            // recorded explicitly so the contract stays honest.
            string applied_action = (decision.action == FALCON_TM_NO_ACTION
                                      ? "NONE_PHASE2B_OBSERVATIONAL"
                                      : "UNSUPPORTED_DECISION_NO_APPLY_PATH");
            AppendAuditRow(ctx, m_engines[e].EngineId(), decision, applied_action);
         }
      }
   }
};

CFalconTradeManagementCoordinator g_trade_management_coordinator;

#endif // FALCON_TRADE_MANAGEMENT_COORDINATOR_MQH
