//+------------------------------------------------------------------+
//| TradeManagement/FalconTradeManagementCoordinator.mqh             |
//| R1.5a - Phase 3a: the live trade-management coordinator.         |
//|                                                                  |
//| Per closed M5 bar, walks the EA's open broker positions (matched |
//| by the shared Falcon magic), builds a broker-side context for    |
//| each, calls every registered engine, applies the decision, and   |
//| writes one audit row per engine-evaluation. R1.5a adds the apply |
//| path deferred from 2b: a MODIFY_SL decision now issues a real    |
//| TRADE_ACTION_SLTP modify on the broker position (CLOSE /         |
//| PARTIAL_CLOSE still have no apply path - 3b/3c). A NO_ACTION      |
//| decision still touches nothing. Strategy-aware engine routing is |
//| Phase 3+ (Backlog #57); here every Falcon-magic position is      |
//| evaluated by every registered engine.                            |
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

   // R1.5a - Phase 3a apply path. Turns one engine decision into a real
   // broker action and returns the AppliedAction string for the audit.
   // MODIFY_SL is the only path with teeth in 3a; CLOSE / PARTIAL_CLOSE
   // are declared in the contract but have no apply path yet (3b/3c), so
   // they record UNSUPPORTED_DECISION_NO_APPLY_PATH and change nothing.
   string ApplyDecision(const FalconManagedPositionContext &ctx,
                        const FalconTradeDecision &decision)
   {
      if(decision.action == FALCON_TM_NO_ACTION)
         return "NONE";
      if(decision.action == FALCON_TM_MODIFY_SL)
         return ApplyModifyStopLoss(ctx, decision);
      return "UNSUPPORTED_DECISION_NO_APPLY_PATH";
   }

   // Real SL modify on the broker position. TP is preserved. This is the
   // only broker write the trade-management layer issues in 3a. Direct
   // TRADE_ACTION_SLTP OrderSend (mirrors the manual-request style the
   // entry bridge uses); the bridge's entry/exit logic is untouched.
   string ApplyModifyStopLoss(const FalconManagedPositionContext &ctx,
                             const FalconTradeDecision &decision)
   {
      if(!PositionSelectByTicket(ctx.position_ticket))
         return "SL_MODIFY_REJECTED:POSITION_NOT_SELECTED";

      double new_sl = NormalizeDouble(decision.new_sl, _Digits);

      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action   = TRADE_ACTION_SLTP;
      request.position = ctx.position_ticket;
      request.symbol   = _Symbol;
      request.sl       = new_sl;
      request.tp       = ctx.current_tp; // keep TP exactly as is

      bool sent = OrderSend(request, result);
      if(sent && (result.retcode == TRADE_RETCODE_DONE ||
                  result.retcode == TRADE_RETCODE_PLACED ||
                  result.retcode == TRADE_RETCODE_DONE_PARTIAL))
         return "SL_MODIFIED";

      return StringFormat("SL_MODIFY_REJECTED:retcode=%d:%s",
                          (int)result.retcode, result.comment);
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
      // R1.5a-fix: the strategy's structural stop, carried from entry via the
      // registry (keyed by position ticket). The broker SL above is the wide
      // emergency envelope, not the intended risk - the protection policy
      // sizes R off this field. Unknown position => left 0.0 => policy disarms.
      double structural_stop = 0.0;
      g_structural_stop_registry.Get(ticket, structural_stop);
      ctx.structural_stop_price = structural_stop;
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
            // R1.5a - Phase 3a: decisions now have teeth. Apply the
            // decision against the broker and record what was applied.
            // A NO_ACTION decision still touches nothing (so a registered
            // engine that returns NO_ACTION stays behaviourally inert).
            string applied_action = ApplyDecision(ctx, decision);
            // Refresh the context's current SL after a successful modify so
            // the audit row reflects what the engine actually moved it to.
            if(applied_action == "SL_MODIFIED")
               ctx.current_sl = NormalizeDouble(decision.new_sl, _Digits);
            AppendAuditRow(ctx, m_engines[e].EngineId(), decision, applied_action);
         }
      }
   }
};

CFalconTradeManagementCoordinator g_trade_management_coordinator;

#endif // FALCON_TRADE_MANAGEMENT_COORDINATOR_MQH
