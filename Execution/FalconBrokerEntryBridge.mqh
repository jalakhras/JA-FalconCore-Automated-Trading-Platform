//+------------------------------------------------------------------+
//| Execution/FalconBrokerEntryBridge.mqh                            |
//| R0.4: CFalconBrokerEntryBridge moved verbatim from main .mq5     |
//| (L12679-15065).                                                  |
//|                                                                  |
//| OWNS the only OrderSend call sites in the EA:                    |
//|   1. Entry OrderSend (atomic with server SL/TP envelope)         |
//|   2. ExecuteReverseClosePositionRequest (managed close + trailing)|
//| ALL gated by EnableRealExecution && MQLInfoInteger(MQL_TESTER).  |
//|                                                                  |
//| DEPENDS on CFalconReportWriter - so this file must be #included  |
//| AFTER class CFalconReportWriter is defined. It is therefore the  |
//| ONLY Execution .mqh that does NOT live in the top include block. |
//+------------------------------------------------------------------+
#ifndef FALCON_BROKER_ENTRY_BRIDGE_MQH
#define FALCON_BROKER_ENTRY_BRIDGE_MQH

// ==================================================================
// Strategy-agnostic Emergency Server Stop Envelope LOCK Parity Probe - v0.56.9b
// Controlled tester-only probe with validated StructuralSL/TP plan but no server SL/TP attachment. This bridge remains reusable by future strategies because it
// consumes FalconShadowTradeRecord / TradeId / StrategyId / EngineId instead of
// FVG-specific state. It deliberately blocks OrderSend until the broker-facing
// managed exit lifecycle exists, because every broker trade must have a TP/SL
// and later Protection/Runner state that can match the reports.
// ==================================================================
class CFalconBrokerEntryBridge
{
private:
   bool m_initialized;
   int  m_entry_attempts;
   int  m_entry_accepted;
   int  m_entry_blocked;
   double m_previous_broker_authority_lot;
   bool   m_previous_broker_authority_lot_ready;
   FalconBrokerTradeLink m_active_links[];
   FalconBrokerTradeLink m_link_audit_history[];
   FalconTradeLifecycleRecord m_paper_final_records[];

   string BrokerDealReasonToObservationStatus(const long deal_reason)
   {
      if(deal_reason == DEAL_REASON_TP)
         return "SERVER_TP_EXIT";
      if(deal_reason == DEAL_REASON_SL)
         return "SERVER_SL_EXIT";
      if(deal_reason == DEAL_REASON_SO)
         return "SERVER_STOP_OUT_EXIT";
      if(deal_reason == DEAL_REASON_CLIENT)
         return "CLIENT_OR_TESTER_CLOSE_EXIT";
      if(deal_reason == DEAL_REASON_EXPERT)
         return "EXPERT_CLOSE_EXIT";
      return "BROKER_EXIT_OBSERVED_REASON_" + IntegerToString((int)deal_reason);
   }

   string BrokerDealEntryToString(const long deal_entry)
   {
      if(deal_entry == DEAL_ENTRY_IN)
         return "DEAL_ENTRY_IN";
      if(deal_entry == DEAL_ENTRY_OUT)
         return "DEAL_ENTRY_OUT";
      if(deal_entry == DEAL_ENTRY_INOUT)
         return "DEAL_ENTRY_INOUT";
      if(deal_entry == DEAL_ENTRY_OUT_BY)
         return "DEAL_ENTRY_OUT_BY";
      return "DEAL_ENTRY_" + IntegerToString((int)deal_entry);
   }

   void StoreAcceptedLink(const FalconBrokerTradeLink &link)
   {
      if(!link.broker_entry_accepted)
         return;
      int n = ArraySize(m_active_links);
      ArrayResize(m_active_links, n + 1);
      m_active_links[n] = link;
   }

   void StoreOrUpdateAuditLink(const FalconBrokerTradeLink &link)
   {
      if(StringLen(link.trade_id) <= 0)
         return;
      int n = ArraySize(m_link_audit_history);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_link_audit_history[i].trade_id == link.trade_id)
         {
            m_link_audit_history[i] = link;
            return;
         }
      }
      ArrayResize(m_link_audit_history, n + 1);
      m_link_audit_history[n] = link;
   }

   bool FindAuditLinkByTradeId(const string trade_id, FalconBrokerTradeLink &link)
   {
      if(StringLen(trade_id) <= 0)
         return false;
      int n = ArraySize(m_link_audit_history);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_link_audit_history[i].trade_id == trade_id)
         {
            link = m_link_audit_history[i];
            return true;
         }
      }
      return false;
   }

   bool FindAuditLinkByTradeHash(const string trade_hash, FalconBrokerTradeLink &link)
   {
      if(StringLen(trade_hash) <= 0)
         return false;
      int n = ArraySize(m_link_audit_history);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_link_audit_history[i].trade_id_short == trade_hash)
         {
            link = m_link_audit_history[i];
            return true;
         }
      }
      return false;
   }

public:
   // R1.2d completion: promoted from private to public so the S00
   // CloseActiveTrade path can register the Paper TradeLifecycle
   // record in m_paper_final_records[] before the broker reverse-close
   // deal fires. Without this, OnTradeTransaction's later call to
   // FindPaperFinalRecord finds nothing for S00 trades and the
   // reconciliation row is flagged BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE.
   // Access change ONLY - body is verbatim from the private original.
   void StorePaperFinalRecord(const FalconTradeLifecycleRecord &record)
   {
      if(StringLen(record.trade_id) <= 0)
         return;
      int n = ArraySize(m_paper_final_records);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_paper_final_records[i].trade_id == record.trade_id)
         {
            m_paper_final_records[i] = record;
            return;
         }
      }
      ArrayResize(m_paper_final_records, n + 1);
      m_paper_final_records[n] = record;
   }

private:
   bool FindPaperFinalRecord(const string trade_id, FalconTradeLifecycleRecord &record)
   {
      if(StringLen(trade_id) <= 0)
         return false;
      int n = ArraySize(m_paper_final_records);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_paper_final_records[i].trade_id == trade_id)
         {
            record = m_paper_final_records[i];
            return true;
         }
      }
      return false;
   }

   bool UpdateAuditLinkManagedCloseRequest(const string trade_id,
                                           const bool attempted,
                                           const bool accepted,
                                           const ulong close_order_ticket,
                                           const ulong close_deal_ticket,
                                           const string close_comment)
   {
      if(StringLen(trade_id) <= 0)
         return false;
      int n = ArraySize(m_link_audit_history);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_link_audit_history[i].trade_id == trade_id)
         {
            m_link_audit_history[i].broker_close_attempted = attempted;
            m_link_audit_history[i].broker_close_accepted = accepted;
            m_link_audit_history[i].managed_close_attempted = attempted;
            m_link_audit_history[i].managed_close_accepted = accepted;
            m_link_audit_history[i].broker_close_order_ticket = close_order_ticket;
            m_link_audit_history[i].broker_close_deal_ticket = close_deal_ticket;
            m_link_audit_history[i].managed_close_comment = close_comment;
            return true;
         }
      }
      return false;
   }

   void UpdateLinkCloseObservation(FalconBrokerTradeLink &link,
                                   const ulong close_order_ticket,
                                   const ulong close_deal_ticket,
                                   const double close_price,
                                   const double close_volume,
                                   const double actual_balance_delta,
                                   const datetime close_time,
                                   const string exit_status,
                                   const string exit_reason)
   {
      link.broker_close_order_ticket = close_order_ticket;
      link.broker_close_deal_ticket = close_deal_ticket;
      link.broker_close_price = close_price;
      link.broker_close_volume = close_volume;
      link.broker_actual_balance_delta = actual_balance_delta;
      link.broker_close_time = close_time;
      link.broker_exit_observed = true;
      link.broker_exit_status = exit_status;
      link.broker_exit_reason = exit_reason;
      link.broker_close_attempted = true;
      link.broker_close_accepted = true;
      if(exit_status == "EXPERT_CLOSE_EXIT")
      {
         link.managed_close_attempted = true;
         link.managed_close_accepted = true;
      }
      StoreOrUpdateAuditLink(link);
   }

   bool FindActiveLinkByPosition(const ulong position_ticket, FalconBrokerTradeLink &link)
   {
      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_active_links[i].broker_position_ticket == position_ticket && position_ticket > 0)
         {
            link = m_active_links[i];
            return true;
         }
      }
      return false;
   }

   bool FindActiveLinkByPositionIdentifier(const ulong position_identifier, FalconBrokerTradeLink &link)
   {
      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_active_links[i].broker_position_identifier == position_identifier && position_identifier > 0)
         {
            link = m_active_links[i];
            return true;
         }
      }
      return false;
   }

   bool FindActiveLinkByOrderOrDeal(const ulong order_ticket, const ulong deal_ticket, FalconBrokerTradeLink &link)
   {
      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         if((order_ticket > 0 && m_active_links[i].broker_order_ticket == order_ticket) ||
            (deal_ticket > 0 && m_active_links[i].broker_deal_ticket == deal_ticket) ||
            (order_ticket > 0 && m_active_links[i].broker_close_order_ticket == order_ticket) ||
            (deal_ticket > 0 && m_active_links[i].broker_close_deal_ticket == deal_ticket))
         {
            link = m_active_links[i];
            return true;
         }
      }
      return false;
   }

   bool FindActiveLinkByTradeId(const string trade_id, FalconBrokerTradeLink &link)
   {
      if(StringLen(trade_id) <= 0)
         return false;

      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         if(m_active_links[i].trade_id == trade_id)
         {
            link = m_active_links[i];
            return true;
         }
      }
      return false;
   }

   string LifecycleManagedCloseReason(const FalconTradeLifecycleRecord &record)
   {
      string reason = "PAPER_FINAL_CLOSE";
      if(StringLen(record.paper_final_exit_reason) > 0)
         reason = record.paper_final_exit_reason;
      else if(StringLen(record.paper_runner_exit_reason) > 0)
         reason = record.paper_runner_exit_reason;
      else if(StringLen(record.paper_exit_reason) > 0)
         reason = record.paper_exit_reason;
      else if(StringLen(record.close_reason) > 0)
         reason = record.close_reason;

      string state = StringFormat("protectionActivated=%s; runnerActivated=%s; protectionState=%s; runnerState=%s",
                                  FalconBoolToYesNo(record.paper_protection_activated),
                                  FalconBoolToYesNo(record.paper_runner_activated),
                                  record.paper_protection_state,
                                  record.paper_runner_state);
      return reason + "; " + state;
   }

   bool RecoverClosedBrokerExitFromHistory(FalconBrokerTradeLink &link,
                                           const FalconTradeLifecycleRecord &record,
                                           CFalconReportWriter &report_writer,
                                           const string recovery_context)
   {
      // v0.56.9: In Strategy Tester some server TP/SL exits may be known in
      // account history before the Paper lifecycle reaches its final close.
      // When Paper finalization later tries managed close, PositionSelectByTicket
      // can fail and v0.56.8a reported only "already closed" with zero actual
      // delta. This recovery scans realized deal history by position identifier,
      // ticket, order/deal ticket, or TradeId hash and writes the missing actual
      // broker delta into both BrokerExecutionLifecycle and BrokerPaperTradeReconciliation.
      if(!link.broker_entry_accepted)
         return false;

      if(link.broker_exit_observed)
      {
         string already_reason = StringFormat("Closed-before-Paper-final recovery skipped because broker exit was already observed; context=%s; previousExitStatus=%s; previousReason=%s",
                                             recovery_context,
                                             link.broker_exit_status,
                                             link.broker_exit_reason);
         report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                                  link,
                                                                  "BROKER_EXIT_ALREADY_OBSERVED_BEFORE_PAPER_FINAL",
                                                                  "BROKER_ALREADY_CLOSED_BEFORE_PAPER_FINAL_ACTUAL_DELTA_AVAILABLE",
                                                                  already_reason);
         return true;
      }

      datetime history_from = record.entry_time;
      if(link.broker_entry_time > 0 && (history_from <= 0 || link.broker_entry_time < history_from))
         history_from = link.broker_entry_time;
      if(history_from > 86400)
         history_from -= 86400;
      else
         history_from = 0;

      datetime history_to = TimeCurrent() + 86400;
      if(record.exit_time > history_to)
         history_to = record.exit_time + 86400;

      if(!HistorySelect(history_from, history_to))
         return false;

      string target_hash = link.trade_id_short;
      if(StringLen(target_hash) <= 0)
         target_hash = FalconTradeIdShortHash(record.trade_id);

      ulong best_deal = 0;
      ulong best_order = 0;
      datetime best_time = 0;
      double best_profit = 0.0;
      double best_swap = 0.0;
      double best_commission = 0.0;
      double best_price = 0.0;
      double best_volume = 0.0;
      long best_reason = 0;
      long best_entry = 0;
      string best_deal_comment = "";
      string best_order_comment = "";
      string best_match = "UNMATCHED";

      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;
         if(!HistoryDealSelect(deal_ticket))
            continue;

         string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_symbol != _Symbol)
            continue;

         long deal_entry = (long)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(!(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
            continue;

         datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         if(link.broker_entry_time > 0 && deal_time < link.broker_entry_time)
            continue;

         ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
         ulong order_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
         string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
         string order_comment = "";
         if(order_ticket > 0 && HistoryOrderSelect(order_ticket))
            order_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);

         string deal_hash = FalconExtractCommentHash(deal_comment);
         string order_hash = FalconExtractCommentHash(order_comment);

         bool identity_match = false;
         string match_by = "";
         if(position_id > 0 && link.broker_position_identifier > 0 && position_id == link.broker_position_identifier)
         {
            identity_match = true;
            match_by = "POSITION_IDENTIFIER_HISTORY";
         }
         else if(position_id > 0 && link.broker_position_ticket > 0 && position_id == link.broker_position_ticket)
         {
            identity_match = true;
            match_by = "POSITION_TICKET_HISTORY";
         }
         else if(order_ticket > 0 && (order_ticket == link.broker_order_ticket || order_ticket == link.broker_close_order_ticket))
         {
            identity_match = true;
            match_by = "ORDER_TICKET_HISTORY";
         }
         else if(StringLen(target_hash) > 0 && deal_hash == target_hash)
         {
            identity_match = true;
            match_by = "DEAL_COMMENT_HASH_HISTORY";
         }
         else if(StringLen(target_hash) > 0 && order_hash == target_hash)
         {
            identity_match = true;
            match_by = "ORDER_COMMENT_HASH_HISTORY";
         }

         long deal_magic = (long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         if(deal_magic != FC_MAGIC_FVG_MICRO && !identity_match)
            continue;
         if(!identity_match)
            continue;

         if(best_deal == 0 || deal_time >= best_time)
         {
            best_deal = deal_ticket;
            best_order = order_ticket;
            best_time = deal_time;
            best_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            best_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            best_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            best_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            best_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
            best_reason = (long)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
            best_entry = deal_entry;
            best_deal_comment = deal_comment;
            best_order_comment = order_comment;
            best_match = match_by;
         }
      }

      if(best_deal == 0)
         return false;

      double actual_delta = best_profit + best_swap + best_commission;
      string exit_status = BrokerDealReasonToObservationStatus(best_reason);
      string recovery_reason = StringFormat("Closed-before-Paper-final history recovery; context=%s; mappedBy=%s; dealEntry=%s; dealReason=%d; profit=%.4f; swap=%.4f; commission=%.4f; dealComment=%s; orderComment=%s; policy=%s",
                                            recovery_context,
                                            best_match,
                                            BrokerDealEntryToString(best_entry),
                                            (int)best_reason,
                                            best_profit,
                                            best_swap,
                                            best_commission,
                                            best_deal_comment,
                                            best_order_comment,
                                            FALCON_MREB_DECISION_POLICY);

      UpdateLinkCloseObservation(link,
                                 best_order,
                                 best_deal,
                                 best_price,
                                 best_volume,
                                 actual_delta,
                                 best_time,
                                 exit_status,
                                 recovery_reason);

      report_writer.AppendBrokerExitObservationLifecycleRecord(link,
                                                               best_deal,
                                                               best_order,
                                                               best_price,
                                                               best_volume,
                                                               actual_delta,
                                                               best_time,
                                                               exit_status,
                                                               recovery_reason);

      report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                               link,
                                                               "BROKER_EXIT_RECOVERED_FROM_HISTORY_BEFORE_PAPER_FINAL",
                                                               "BROKER_ALREADY_CLOSED_BEFORE_PAPER_FINAL_ACTUAL_DELTA_RECOVERED",
                                                               recovery_reason);

      MarkLinkClosed(link.broker_position_identifier > 0 ? link.broker_position_identifier : link.broker_position_ticket,
                     best_order,
                     best_deal);
      return true;
   }

   bool FindSingleActiveLink(FalconBrokerTradeLink &link)
   {
      int n = ArraySize(m_active_links);
      if(n == 1)
      {
         link = m_active_links[0];
         return true;
      }
      return false;
   }

   void MarkLinkClosed(const ulong position_ticket, const ulong order_ticket, const ulong deal_ticket)
   {
      int n = ArraySize(m_active_links);
      for(int i = n - 1; i >= 0; i--)
      {
         bool match = false;
         if(position_ticket > 0 && m_active_links[i].broker_position_ticket == position_ticket)
            match = true;
         if(order_ticket > 0 && m_active_links[i].broker_order_ticket == order_ticket)
            match = true;
         if(deal_ticket > 0 && m_active_links[i].broker_deal_ticket == deal_ticket)
            match = true;
         if(position_ticket > 0 && m_active_links[i].broker_position_identifier == position_ticket)
            match = true;
         if(order_ticket > 0 && m_active_links[i].broker_close_order_ticket == order_ticket)
            match = true;
         if(deal_ticket > 0 && m_active_links[i].broker_close_deal_ticket == deal_ticket)
            match = true;
         if(match)
         {
            for(int j = i; j < n - 1; j++)
               m_active_links[j] = m_active_links[j + 1];
            ArrayResize(m_active_links, n - 1);
            return;
         }
      }
   }

   double NormalizeVolume(const double requested_volume)
   {
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      double volume = requested_volume;
      if(min_lot > 0.0 && volume < min_lot)
         volume = min_lot;
      if(max_lot > 0.0 && volume > max_lot)
         volume = max_lot;
      if(step > 0.0)
         volume = MathFloor(volume / step) * step;
      if(min_lot > 0.0 && volume < min_lot)
         volume = min_lot;
      return NormalizeDouble(volume, 2);
   }

   double NormalizeVolumeDownNoMinFloor(const double requested_volume)
   {
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0)
         step = 0.01;

      double volume = requested_volume;
      if(max_lot > 0.0 && volume > max_lot)
         volume = max_lot;
      if(volume <= 0.0)
         return 0.0;

      volume = MathFloor(volume / step) * step;
      return NormalizeDouble(volume, 2);
   }

   double BrokerDynamicTierMaxLot(const string tier_name)
   {
      if(tier_name == "MICRO")    return 0.01;
      if(tier_name == "TINY")     return 0.03;
      if(tier_name == "SMALL")    return 0.10;
      if(tier_name == "MEDIUM")   return 0.30;
      if(tier_name == "STANDARD") return 1.00;
      if(tier_name == "LARGE")    return 2.00;
      return 0.01;
   }

   double BrokerDynamicCapitalMaxLot(const double effective_capital)
   {
      if(effective_capital <= 0.0)
         return 0.0;
      return NormalizeVolumeDownNoMinFloor((effective_capital / FALCON_DLM_CAPITAL_USD_PER_001_LOT) * 0.01);
   }

   double BrokerDynamicGrowthRampMaxLot()
   {
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) step = 0.01;
      if(min_lot <= 0.0) min_lot = step;

      if(!m_previous_broker_authority_lot_ready || m_previous_broker_authority_lot <= 0.0)
         return min_lot;

      return NormalizeVolume((m_previous_broker_authority_lot * FALCON_DLM_MAX_LOT_GROWTH_MULTIPLIER) + step);
   }

   bool EstimateBrokerRiskLoss(const ENUM_ORDER_TYPE order_type,
                               const double volume,
                               const double entry_price,
                               const double sl_price,
                               double &loss_usd,
                               string &calc_status)
   {
      loss_usd = 0.0;
      calc_status = "ORDERCALC_PROFIT_UNAVAILABLE";

      double profit = 0.0;
      if(OrderCalcProfit(order_type, _Symbol, volume, entry_price, sl_price, profit))
      {
         loss_usd = MathAbs(MathMin(profit, 0.0));
         calc_status = "ORDERCALC_PROFIT_OK";
         return true;
      }
      return false;
   }

   bool EstimateBrokerMargin(const ENUM_ORDER_TYPE order_type,
                             const double volume,
                             const double entry_price,
                             double &margin_required,
                             string &margin_status)
   {
      margin_required = 0.0;
      margin_status = "ORDERCALC_MARGIN_UNAVAILABLE";

      double margin = 0.0;
      if(OrderCalcMargin(order_type, _Symbol, volume, entry_price, margin))
      {
         margin_required = margin;
         margin_status = "ORDERCALC_MARGIN_OK";
         return true;
      }
      return false;
   }

   bool ResolvePreEntryBrokerLotAuthority(const FalconShadowTradeRecord &record,
                                          const double broker_entry_price,
                                          const ENUM_ORDER_TYPE order_type,
                                          double &authorized_volume,
                                          string &reason)
   {
      authorized_volume = 0.0;
      reason = "";

      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) step = 0.01;
      if(min_lot <= 0.0) min_lot = step;
      if(max_lot <= 0.0) max_lot = 100.0;

      double effective_capital = FalconEffectiveCapitalForTier();
      if(effective_capital <= 0.0)
         effective_capital = AccountInfoDouble(ACCOUNT_BALANCE);
      if(effective_capital <= 0.0 && ManualCapital > 0.0)
         effective_capital = ManualCapital;

      string tier = FalconCapitalTierName(effective_capital);
      double base_risk_pct = FalconCapitalTierBaseRiskPct(tier);
      double risk_budget_usd = 0.0;
      if(effective_capital > 0.0 && base_risk_pct > 0.0)
         risk_budget_usd = effective_capital * base_risk_pct / 100.0;

      double requested_lot = (UseFixedLot ? FixedLotSize : record.lot_size);
      string mode_status = FALCON_BLA_FIXED_MODE_STATUS;

      if(!UseFixedLot)
      {
         mode_status = FALCON_BLA_DYNAMIC_MODE_STATUS;

         if(record.structural_sl <= 0.0 || broker_entry_price <= 0.0)
         {
            reason = "BROKER_LOT_AUTHORITY_BLOCKED_DYNAMIC_STRUCTURAL_RISK_UNKNOWN";
            return false;
         }
         if(risk_budget_usd <= 0.0)
         {
            reason = "BROKER_LOT_AUTHORITY_BLOCKED_DYNAMIC_RISK_BUDGET_UNKNOWN";
            return false;
         }

         double one_lot_loss = 0.0;
         string risk_calc_status = "";
         if(!EstimateBrokerRiskLoss(order_type, 1.0, broker_entry_price, record.structural_sl, one_lot_loss, risk_calc_status) || one_lot_loss <= 0.0)
         {
            reason = "BROKER_LOT_AUTHORITY_BLOCKED_DYNAMIC_ONE_LOT_RISK_UNKNOWN_" + risk_calc_status;
            return false;
         }

         double raw_lot = risk_budget_usd / one_lot_loss;
         double tier_cap = BrokerDynamicTierMaxLot(tier);
         double capital_cap = BrokerDynamicCapitalMaxLot(effective_capital);
         double growth_cap = BrokerDynamicGrowthRampMaxLot();
         requested_lot = raw_lot;

         if(tier_cap > 0.0 && requested_lot > tier_cap)
            requested_lot = tier_cap;
         if(capital_cap > 0.0 && requested_lot > capital_cap)
            requested_lot = capital_cap;
         if(growth_cap > 0.0 && requested_lot > growth_cap)
            requested_lot = growth_cap;

         // Do not silently floor a dynamic risk lot below broker minimum if minimum lot risk is outside the budget.
         if(requested_lot < min_lot)
         {
            double min_lot_loss = 0.0;
            string min_calc_status = "";
            EstimateBrokerRiskLoss(order_type, min_lot, broker_entry_price, record.structural_sl, min_lot_loss, min_calc_status);
            if(min_lot_loss > risk_budget_usd)
            {
               reason = StringFormat("BROKER_LOT_AUTHORITY_BLOCKED_DYNAMIC_MIN_LOT_RISK_EXCEEDS_BUDGET minLoss=%.2f budget=%.2f rawLot=%.4f minLot=%.2f",
                                     min_lot_loss, risk_budget_usd, raw_lot, min_lot);
               return false;
            }
         }

         reason = StringFormat("%s effectiveCapital=%.2f tier=%s riskBudget=%.2f rawLot=%.4f tierCap=%.2f capitalCap=%.2f growthCap=%.2f",
                               mode_status, effective_capital, tier, risk_budget_usd, raw_lot, tier_cap, capital_cap, growth_cap);
      }
      else
      {
         if(requested_lot <= 0.0)
         {
            reason = "BROKER_LOT_AUTHORITY_BLOCKED_FIXED_LOT_INVALID";
            return false;
         }
         reason = StringFormat("%s requestedFixedLot=%.2f effectiveCapital=%.2f tier=%s",
                               mode_status, requested_lot, effective_capital, tier);
      }

      double normalized = NormalizeVolume(requested_lot);
      if(normalized <= 0.0)
      {
         reason = "BROKER_LOT_AUTHORITY_BLOCKED_NORMALIZED_VOLUME_INVALID; " + reason;
         return false;
      }

      double sl_loss = 0.0;
      string sl_calc_status = "";
      EstimateBrokerRiskLoss(order_type, normalized, broker_entry_price, record.structural_sl, sl_loss, sl_calc_status);
      if(sl_loss > FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD)
      {
         reason = StringFormat("BROKER_LOT_AUTHORITY_BLOCKED_SL_LOSS_TOO_LARGE loss=%.2f max=%.2f lot=%.2f; %s",
                               sl_loss, FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD, normalized, reason);
         return false;
      }

      double margin_required = 0.0;
      string margin_status = "";
      if(EstimateBrokerMargin(order_type, normalized, broker_entry_price, margin_required, margin_status))
      {
         double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         double max_margin = free_margin * FALCON_BLA_MAX_MARGIN_USE_PCT / 100.0;
         if(free_margin > 0.0 && margin_required > max_margin)
         {
            reason = StringFormat("BROKER_LOT_AUTHORITY_BLOCKED_MARGIN_TOO_HIGH margin=%.2f free=%.2f maxPct=%.2f lot=%.2f; %s",
                                  margin_required, free_margin, FALCON_BLA_MAX_MARGIN_USE_PCT, normalized, reason);
            return false;
         }
      }

      authorized_volume = normalized;
      reason = StringFormat("BROKER_LOT_AUTHORITY_ACCEPTED lot=%.2f slLoss=%.2f marginStatus=%s margin=%.2f; %s",
                            authorized_volume, sl_loss, margin_status, margin_required, reason);
      return true;
   }

   bool ValidateAtomicStructuralRiskEnvelope(const FalconShadowTradeRecord &record,
                                             const double broker_entry_price,
                                             const double volume,
                                             const ENUM_ORDER_TYPE order_type,
                                             string &reason)
   {
      reason = "";

      double sl_distance = MathAbs(broker_entry_price - record.structural_sl);
      if(sl_distance > FALCON_BEEB_MAX_STRUCTURAL_SL_PRICE_DISTANCE)
      {
         reason = StringFormat("ATOMIC_ENTRY_BLOCKED_STRUCTURAL_SL_DISTANCE_TOO_LARGE distance=%.2f max=%.2f",
                               sl_distance,
                               FALCON_BEEB_MAX_STRUCTURAL_SL_PRICE_DISTANCE);
         return false;
      }

      double potential_profit = 0.0;
      if(OrderCalcProfit(order_type, _Symbol, volume, broker_entry_price, record.structural_sl, potential_profit))
      {
         double potential_loss = MathAbs(MathMin(potential_profit, 0.0));
         if(potential_loss > FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD)
         {
            reason = StringFormat("ATOMIC_ENTRY_BLOCKED_STRUCTURAL_SL_LOSS_TOO_LARGE loss=%.2f max=%.2f distance=%.2f lot=%.2f",
                                  potential_loss,
                                  FALCON_BEEB_MAX_STRUCTURAL_SL_LOSS_USD,
                                  sl_distance,
                                  volume);
            return false;
         }
      }
      else
      {
         // Do not block solely because OrderCalcProfit is unavailable in the tester,
         // but keep the distance guard above active. The reason is included in accepted
         // lifecycle text only when a later stage adds detailed risk columns.
      }

      reason = StringFormat("ATOMIC_STRUCTURAL_SL_RISK_WITHIN_GUARD distance=%.2f lot=%.2f", sl_distance, volume);
      return true;
   }

   int CountOpenFalconPositions(const string symbol, const long magic)
   {
      int count = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         string pos_symbol = PositionGetString(POSITION_SYMBOL);
         long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
         if(pos_symbol == symbol && pos_magic == magic)
            count++;
      }
      return count;
   }

   ulong FindLatestFalconPositionTicket(const string symbol, const long magic)
   {
      ulong latest_ticket = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         string pos_symbol = PositionGetString(POSITION_SYMBOL);
         long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
         if(pos_symbol == symbol && pos_magic == magic)
            latest_ticket = ticket;
      }
      return latest_ticket;
   }

   bool BridgeTakeProfitDirectionallyValid(const FalconShadowTradeRecord &record,
                                           const double broker_entry_price,
                                           const int tp_index)
   {
      double tp = 0.0;
      if(tp_index == 1)
         tp = record.tp1;
      else if(tp_index == 2)
         tp = record.tp2;
      else if(tp_index == 3)
         tp = record.tp3;
      else
         return false;

      if(broker_entry_price <= 0.0 || tp <= 0.0)
         return false;

      if(record.direction == FALCON_DIRECTION_BUY)
         return (tp > broker_entry_price);

      if(record.direction == FALCON_DIRECTION_SELL)
         return (tp < broker_entry_price);

      return false;
   }

   bool SelectInitialBridgeTakeProfit(const FalconShadowTradeRecord &record,
                                      const double broker_entry_price,
                                      double &initial_tp,
                                      string &reason)
   {
      initial_tp = 0.0;
      reason = "";

      if(broker_entry_price <= 0.0)
      {
         reason = "BRIDGE_TP_SELECTION_BLOCKED_INVALID_ENTRY_PRICE";
         return false;
      }

      // v0.56.8: TP1 and TP2 are proof/protection checkpoints, and TP3 is
      // explicitly classified as a temporary server-side safety cap, not a final
      // runner-parity exit. Until controlled EA-managed close or BrokerModify is
      // introduced, the furthest valid planned target remains attached only to
      // prevent naked/orphan exposure while managed runner decisions are audited.
      if(BridgeTakeProfitDirectionallyValid(record, broker_entry_price, 3))
      {
         initial_tp = record.tp3;
         reason = "BRIDGE_INITIAL_SERVER_TP_SELECTED_TP3_SAFETY_CAP_NOT_FINAL_RUNNER_EXIT_TP1_TP2_REMAIN_PROOF_CHECKPOINTS; managedPolicy=" + FALCON_MREB_DECISION_POLICY + "; policy=" + FALCON_BPR_INITIAL_SERVER_TP_POLICY;
         return true;
      }

      if(BridgeTakeProfitDirectionallyValid(record, broker_entry_price, 2))
      {
         initial_tp = record.tp2;
         reason = "BRIDGE_INITIAL_SERVER_TP_FALLBACK_TP2_TP3_NOT_VALID_YET_TP2_IS_NOT_FINAL_PARITY_EXIT; policy=" + FALCON_BPR_INITIAL_SERVER_TP_POLICY;
         return true;
      }

      if(BridgeTakeProfitDirectionallyValid(record, broker_entry_price, 1))
      {
         initial_tp = record.tp1;
         reason = "BRIDGE_INITIAL_SERVER_TP_FALLBACK_TP1_NO_HIGHER_VALID_TARGET_YET_TP1_IS_NOT_FINAL_PARITY_EXIT; policy=" + FALCON_BPR_INITIAL_SERVER_TP_POLICY;
         return true;
      }

      reason = "BRIDGE_TP_SELECTION_BLOCKED_NO_DIRECTIONALLY_VALID_TP1_TP2_OR_TP3";
      return false;
   }

   bool ValidateAtomicEntryExitPlan(const FalconShadowTradeRecord &record,
                                    const double broker_entry_price,
                                    string &reason)
   {
      reason = "";

      if(record.structural_sl <= 0.0)
      {
         reason = "ATOMIC_ENTRY_BLOCKED_MISSING_STRUCTURAL_SL";
         return false;
      }
      if(broker_entry_price <= 0.0)
      {
         reason = "ATOMIC_ENTRY_BLOCKED_INVALID_BROKER_ENTRY_PRICE";
         return false;
      }

      double initial_bridge_tp = 0.0;
      string tp_selection_reason = "";
      if(!SelectInitialBridgeTakeProfit(record, broker_entry_price, initial_bridge_tp, tp_selection_reason))
      {
         reason = "ATOMIC_ENTRY_BLOCKED_MISSING_OR_INVALID_INITIAL_BRIDGE_TP; " + tp_selection_reason;
         return false;
      }

      if(record.direction == FALCON_DIRECTION_BUY)
      {
         if(!(record.structural_sl < broker_entry_price))
         {
            reason = "ATOMIC_ENTRY_BLOCKED_BUY_STRUCTURAL_SL_NOT_BELOW_ENTRY";
            return false;
         }
         if(!(initial_bridge_tp > broker_entry_price))
         {
            reason = "ATOMIC_ENTRY_BLOCKED_BUY_INITIAL_BRIDGE_TP_NOT_ABOVE_ENTRY";
            return false;
         }
      }
      else if(record.direction == FALCON_DIRECTION_SELL)
      {
         if(!(record.structural_sl > broker_entry_price))
         {
            reason = "ATOMIC_ENTRY_BLOCKED_SELL_STRUCTURAL_SL_NOT_ABOVE_ENTRY";
            return false;
         }
         if(!(initial_bridge_tp < broker_entry_price))
         {
            reason = "ATOMIC_ENTRY_BLOCKED_SELL_INITIAL_BRIDGE_TP_NOT_BELOW_ENTRY";
            return false;
         }
      }
      else
      {
         reason = "ATOMIC_ENTRY_BLOCKED_INVALID_DIRECTION";
         return false;
      }

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         point = _Point;
      long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(point > 0.0 && stops_level > 0)
      {
         double sl_distance_points = MathAbs(broker_entry_price - record.structural_sl) / point;
         double tp_distance_points = MathAbs(initial_bridge_tp - broker_entry_price) / point;
         if(sl_distance_points < (double)stops_level)
         {
            reason = StringFormat("ATOMIC_ENTRY_BLOCKED_STRUCTURAL_SL_INSIDE_STOPS_LEVEL slPts=%.1f stops=%d", sl_distance_points, (int)stops_level);
            return false;
         }
         if(tp_distance_points < (double)stops_level)
         {
            reason = StringFormat("ATOMIC_ENTRY_BLOCKED_INITIAL_BRIDGE_TP_INSIDE_STOPS_LEVEL tpPts=%.1f stops=%d", tp_distance_points, (int)stops_level);
            return false;
         }
      }

      reason = "ATOMIC_ENTRY_EXIT_PLAN_VALID_STRUCTURAL_SL_AND_BRIDGE_INITIAL_TP; " + tp_selection_reason;
      return true;
   }

   double DirectionalPriceByDistance(const int direction,
                                     const double broker_entry_price,
                                     const double distance,
                                     const bool stop_side)
   {
      if(direction == FALCON_DIRECTION_BUY)
         return (stop_side ? broker_entry_price - distance : broker_entry_price + distance);
      if(direction == FALCON_DIRECTION_SELL)
         return (stop_side ? broker_entry_price + distance : broker_entry_price - distance);
      return 0.0;
   }

   bool BuildLockParityEmergencyServerStops(const FalconShadowTradeRecord &record,
                                            const double broker_entry_price,
                                            const double volume,
                                            const ENUM_ORDER_TYPE order_type,
                                            double &server_sl,
                                            double &server_tp,
                                            string &reason)
   {
      server_sl = 0.0;
      server_tp = 0.0;
      reason = "";

      if(broker_entry_price <= 0.0 || volume <= 0.0)
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_INVALID_ENTRY_OR_VOLUME";
         return false;
      }
      if(record.structural_sl <= 0.0)
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_MISSING_VIRTUAL_STRUCTURAL_SL";
         return false;
      }

      double planned_tp = 0.0;
      string tp_reason = "";
      if(!SelectInitialBridgeTakeProfit(record, broker_entry_price, planned_tp, tp_reason))
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_NO_VALID_PLANNED_TP; " + tp_reason;
         return false;
      }

      double structural_distance = MathAbs(broker_entry_price - record.structural_sl);
      if(structural_distance <= 0.0)
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_ZERO_STRUCTURAL_DISTANCE";
         return false;
      }

      double target_sl_distance = structural_distance * FALCON_LOCK_PARITY_EMERGENCY_SL_DISTANCE_MULTIPLIER;
      target_sl_distance = MathMax(target_sl_distance, FALCON_LOCK_PARITY_MIN_EMERGENCY_SL_PRICE_DISTANCE);
      target_sl_distance = MathMax(target_sl_distance, structural_distance);
      target_sl_distance = MathMin(target_sl_distance, FALCON_LOCK_PARITY_MAX_EMERGENCY_SL_PRICE_DISTANCE);

      double loss_usd = 0.0;
      string loss_status = "";
      double candidate_sl = DirectionalPriceByDistance(record.direction, broker_entry_price, target_sl_distance, true);
      if(EstimateBrokerRiskLoss(order_type, volume, broker_entry_price, candidate_sl, loss_usd, loss_status) && loss_usd > FALCON_LOCK_PARITY_MAX_EMERGENCY_SL_LOSS_USD)
      {
         double low = structural_distance;
         double high = target_sl_distance;
         double best = structural_distance;
         for(int i = 0; i < 24; i++)
         {
            double mid = (low + high) * 0.5;
            double mid_sl = DirectionalPriceByDistance(record.direction, broker_entry_price, mid, true);
            double mid_loss = 0.0;
            string mid_status = "";
            if(!EstimateBrokerRiskLoss(order_type, volume, broker_entry_price, mid_sl, mid_loss, mid_status))
               break;
            if(mid_loss <= FALCON_LOCK_PARITY_MAX_EMERGENCY_SL_LOSS_USD)
            {
               best = mid;
               low = mid;
            }
            else
               high = mid;
         }
         target_sl_distance = best;
         candidate_sl = DirectionalPriceByDistance(record.direction, broker_entry_price, target_sl_distance, true);
         EstimateBrokerRiskLoss(order_type, volume, broker_entry_price, candidate_sl, loss_usd, loss_status);
      }

      double planned_tp_distance = MathAbs(planned_tp - broker_entry_price);
      if(planned_tp_distance <= 0.0)
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_ZERO_PLANNED_TP_DISTANCE";
         return false;
      }
      double target_tp_distance = planned_tp_distance * FALCON_LOCK_PARITY_EMERGENCY_TP_DISTANCE_MULTIPLIER;
      target_tp_distance = MathMax(target_tp_distance, FALCON_LOCK_PARITY_MIN_EMERGENCY_TP_PRICE_DISTANCE);
      target_tp_distance = MathMax(target_tp_distance, planned_tp_distance);
      target_tp_distance = MathMin(target_tp_distance, FALCON_LOCK_PARITY_MAX_EMERGENCY_TP_PRICE_DISTANCE);

      server_sl = DirectionalPriceByDistance(record.direction, broker_entry_price, target_sl_distance, true);
      server_tp = DirectionalPriceByDistance(record.direction, broker_entry_price, target_tp_distance, false);

      if(server_sl <= 0.0 || server_tp <= 0.0)
      {
         reason = StringFormat("EMERGENCY_SERVER_STOPS_BLOCKED_NONPOSITIVE_RESULT sl=%.5f tp=%.5f", server_sl, server_tp);
         return false;
      }

      if(record.direction == FALCON_DIRECTION_BUY)
      {
         if(!(server_sl < broker_entry_price && server_tp > broker_entry_price))
         {
            reason = StringFormat("EMERGENCY_SERVER_STOPS_BLOCKED_BUY_DIRECTIONAL_INVALID sl=%.5f entry=%.5f tp=%.5f", server_sl, broker_entry_price, server_tp);
            return false;
         }
      }
      else if(record.direction == FALCON_DIRECTION_SELL)
      {
         if(!(server_sl > broker_entry_price && server_tp < broker_entry_price))
         {
            reason = StringFormat("EMERGENCY_SERVER_STOPS_BLOCKED_SELL_DIRECTIONAL_INVALID sl=%.5f entry=%.5f tp=%.5f", server_sl, broker_entry_price, server_tp);
            return false;
         }
      }
      else
      {
         reason = "EMERGENCY_SERVER_STOPS_BLOCKED_INVALID_DIRECTION";
         return false;
      }

      reason = StringFormat("EMERGENCY_SERVER_STOPS_SELECTED virtualStructuralSL=%.5f serverEmergencySL=%.5f plannedTP=%.5f serverEmergencyTP=%.5f structuralDistance=%.2f emergencySLDistance=%.2f emergencyTPDistance=%.2f emergencySLLoss=%.2f lossStatus=%s policy=%s",
                            record.structural_sl, server_sl, planned_tp, server_tp, structural_distance, target_sl_distance, target_tp_distance, loss_usd, loss_status, FALCON_LOCK_PARITY_SERVER_STOP_POLICY);
      return true;
   }

   void ResetLinkFromShadowRecordId(const FalconTradeLifecycleRecord &record, FalconBrokerTradeLink &link)
   {
      link.trade_id = record.trade_id;
      link.trade_id_short = FalconTradeIdShortHash(record.trade_id);
      link.strategy_id = record.strategy_id;
      link.engine_id = record.engine_id;
      link.direction = record.direction;
      link.broker_magic = FC_MAGIC_FVG_MICRO;
      link.broker_position_ticket = 0;
      link.broker_position_identifier = 0;
      link.broker_order_ticket = 0;
      link.broker_deal_ticket = 0;
      link.broker_close_order_ticket = 0;
      link.broker_close_deal_ticket = 0;
      link.requested_lot = record.lot_size;
      link.accepted_lot = 0.0;
      link.planned_entry_price = record.entry_price;
      link.broker_entry_price = 0.0;
      link.broker_sl = 0.0;
      link.broker_tp = 0.0;
      link.broker_close_price = 0.0;
      link.broker_close_volume = 0.0;
      link.broker_actual_balance_delta = 0.0;
      link.planned_entry_time = record.entry_time;
      link.broker_entry_time = 0;
      link.broker_close_time = 0;
      link.broker_entry_attempted = false;
      link.broker_entry_accepted = false;
      link.broker_close_attempted = false;
      link.broker_close_accepted = false;
      link.broker_exit_observed = false;
      link.managed_close_attempted = false;
      link.managed_close_accepted = false;
      link.entry_comment = "";
      link.managed_close_comment = "";
      link.broker_exit_status = "";
      link.broker_exit_reason = "";
      link.status = "NO_BROKER_LINK_FOUND";
      link.reason = "No broker link was found for this Paper TradeId.";
      // v0.57.2: Virtual Trailing Exit Bridge state - zero-init.
      link.virtual_trailing_active = false;
      link.virtual_breakeven_locked = false;
      link.virtual_peak_favorable_price = 0.0;
      link.virtual_trailing_stop_price = 0.0;
      link.virtual_protection_floor_price = 0.0;
      link.virtual_trailing_last_update = 0;
      // v0.57.4: structural BE mode tag.
      link.virtual_breakeven_mode = "";
   }

   void ResetLinkFromShadow(const FalconShadowTradeRecord &record, FalconBrokerTradeLink &link)
   {
      link.trade_id = record.shadow_id;
      link.trade_id_short = FalconTradeIdShortHash(record.shadow_id);
      link.strategy_id = record.strategy_id;
      link.engine_id = record.engine_id;
      link.direction = record.direction;
      link.broker_magic = FC_MAGIC_FVG_MICRO;
      link.broker_position_ticket = 0;
      link.broker_position_identifier = 0;
      link.broker_order_ticket = 0;
      link.broker_deal_ticket = 0;
      link.broker_close_order_ticket = 0;
      link.broker_close_deal_ticket = 0;
      link.requested_lot = record.lot_size;
      link.accepted_lot = 0.0;
      link.planned_entry_price = record.entry_price;
      link.broker_entry_price = 0.0;
      link.broker_sl = 0.0;
      link.broker_tp = 0.0;
      link.broker_close_price = 0.0;
      link.broker_close_volume = 0.0;
      link.broker_actual_balance_delta = 0.0;
      link.planned_entry_time = record.entry_time;
      link.broker_entry_time = 0;
      link.broker_close_time = 0;
      link.broker_entry_attempted = false;
      link.broker_entry_accepted = false;
      link.broker_close_attempted = false;
      link.broker_close_accepted = false;
      link.broker_exit_observed = false;
      link.managed_close_attempted = false;
      link.managed_close_accepted = false;
      link.entry_comment = "";
      link.managed_close_comment = "";
      link.broker_exit_status = "";
      link.broker_exit_reason = "";
      link.status = FALCON_BEEB_ENTRY_DISABLED_STATUS;
      link.reason = "Not evaluated yet.";
      // v0.57.2: Virtual Trailing Exit Bridge state - zero-init.
      link.virtual_trailing_active = false;
      link.virtual_breakeven_locked = false;
      link.virtual_peak_favorable_price = 0.0;
      link.virtual_trailing_stop_price = 0.0;
      link.virtual_protection_floor_price = 0.0;
      link.virtual_trailing_last_update = 0;
      // v0.57.4: structural BE mode tag.
      link.virtual_breakeven_mode = "";
   }

   bool TesterEntryAllowed(string &reason)
   {
      if(!EnableRealExecution)
      {
         reason = "ENABLE_REAL_EXECUTION_FALSE_ENTRY_BRIDGE_AUDIT_ONLY";
         return false;
      }
      if(!MQLInfoInteger(MQL_TESTER))
      {
         reason = "NOT_STRATEGY_TESTER_DEMO_AND_LIVE_BLOCKED_IN_V0564";
         return false;
      }
      if(!FALCON_BEEB_MANAGED_EXIT_BRIDGE_READY)
      {
         reason = "BROKER_ENTRY_BLOCKED_ATOMIC_EXIT_BRIDGE_NOT_READY_NO_ORPHAN_POSITIONS";
         return false;
      }
      reason = "TESTER_ATOMIC_ENTRY_EXIT_ALLOWED_ENABLE_REAL_EXECUTION_TRUE_VALIDATED_PLAN_REQUIRED";
      return true;
   }

public:
   CFalconBrokerEntryBridge()
   {
      m_initialized = false;
      m_entry_attempts = 0;
      m_entry_accepted = 0;
      m_entry_blocked = 0;
      m_previous_broker_authority_lot = 0.0;
      m_previous_broker_authority_lot_ready = false;
      ArrayResize(m_active_links, 0);
      ArrayResize(m_link_audit_history, 0);
      ArrayResize(m_paper_final_records, 0);
   }

   bool Initialize()
   {
      m_initialized = true;
      CFalconLogger::Info("Emergency Server Stop Envelope LOCK Parity Probe v0.56.9b initialized. Tester-only OrderSend requires pre-entry broker lot authority, validated StructuralSL/TP plan, and mandatory server SL/TP attachment; EA-side managed close at Paper final is measured only for still-open broker positions; Demo/Live remain blocked.");
      return true;
   }

   bool TryOpenFromShadowRecord(const FalconShadowTradeRecord &record, CFalconReportWriter &report_writer)
   {
      if(!m_initialized)
         Initialize();

      FalconBrokerTradeLink link;
      ResetLinkFromShadow(record, link);

      string guard_reason = "";
      if(!TesterEntryAllowed(guard_reason))
      {
         link.status = FALCON_BEEB_ENTRY_DISABLED_STATUS;
         link.reason = guard_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      if(record.status != FALCON_SHADOW_RECORD_STAGED || record.is_closed)
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = "SHADOW_RECORD_NOT_OPEN_STAGED";
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      int open_positions = CountOpenFalconPositions(_Symbol, FC_MAGIC_FVG_MICRO);
      if(open_positions >= FALCON_BEEB_MAX_OPEN_POSITIONS_PER_ENGINE)
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = StringFormat("BROKER_ENTRY_BLOCKED_EXISTING_FALCON_POSITION_COUNT_%d", open_positions);
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);

      ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(record.direction == FALCON_DIRECTION_SELL)
      {
         order_type = ORDER_TYPE_SELL;
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
      if(price <= 0.0)
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = "BROKER_ENTRY_PRICE_UNAVAILABLE";
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      double volume = 0.0;
      string lot_authority_reason = "";
      if(!ResolvePreEntryBrokerLotAuthority(record, price, order_type, volume, lot_authority_reason))
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = lot_authority_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      string atomic_plan_reason = "";
      if(!ValidateAtomicEntryExitPlan(record, price, atomic_plan_reason))
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = atomic_plan_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      string structural_risk_reason = "";
      if(!ValidateAtomicStructuralRiskEnvelope(record, price, volume, order_type, structural_risk_reason))
      {
         m_entry_blocked++;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = structural_risk_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = volume;
      request.type = order_type;
      request.price = price;
      // v0.56.9b: emergency server stop envelope probe.
      // Entry orders remain non-naked, but server SL/TP are now fail-safe envelope
      // levels instead of the normal Paper structural SL / TP3 lifecycle levels.
      // This lets the tester measure whether premature server stops are the major
      // LOCK parity gap while keeping visible SL/TP on every broker entry.
      double initial_bridge_tp = 0.0;
      string initial_bridge_tp_reason = "";
      SelectInitialBridgeTakeProfit(record, price, initial_bridge_tp, initial_bridge_tp_reason);
      double emergency_server_sl = 0.0;
      double emergency_server_tp = 0.0;
      string emergency_server_stop_reason = "";
      if(!BuildLockParityEmergencyServerStops(record, price, volume, order_type, emergency_server_sl, emergency_server_tp, emergency_server_stop_reason))
      {
         m_entry_blocked++;
         link.broker_entry_attempted = false;
         link.broker_entry_accepted = false;
         link.entry_comment = FalconBuildBrokerCommentWithHash(FALCON_BEEB_ORDER_COMMENT, record.shadow_id);
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = emergency_server_stop_reason;
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }
      request.sl = NormalizeDouble(emergency_server_sl, _Digits);
      request.tp = NormalizeDouble(emergency_server_tp, _Digits);
      request.deviation = 30;
      request.magic = FC_MAGIC_FVG_MICRO;
      request.comment = FalconBuildBrokerCommentWithHash(FALCON_BEEB_ORDER_COMMENT, record.shadow_id);
      request.type_time = ORDER_TIME_GTC;

      // v0.56.9b: hard safety invariant after the v0.56.9 naked-order probe.
      // No broker/tester OrderSend is allowed without both server-side StructuralSL
      // and a selected bridge TP safety cap. This protects the broker lane while
      // keeping LOCK parity analysis in reports instead of unsafe naked execution.
      if(request.sl <= 0.0 || request.tp <= 0.0)
      {
         m_entry_blocked++;
         link.broker_entry_attempted = false;
         link.broker_entry_accepted = false;
         link.broker_sl = request.sl;
         link.broker_tp = request.tp;
         link.entry_comment = request.comment;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = StringFormat("BROKER_ENTRY_BLOCKED_NO_SERVER_SL_TP_SAFETY_INVARIANT request.sl=%.5f request.tp=%.5f policy=%s", request.sl, request.tp, FALCON_LOCK_PARITY_SERVER_STOP_POLICY);
         StoreOrUpdateAuditLink(link);
         report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
         return false;
      }

      link.broker_entry_attempted = true;
      link.requested_lot = record.lot_size;
      link.accepted_lot = volume;
      link.broker_entry_price = price;
      link.broker_entry_time = TimeCurrent();
      link.broker_sl = request.sl;
      link.broker_tp = request.tp;
      link.entry_comment = request.comment;
      m_entry_attempts++;

      bool sent = OrderSend(request, result);
      link.broker_order_ticket = result.order;
      link.broker_deal_ticket = result.deal;

      if(sent && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE_PARTIAL))
      {
         link.broker_entry_accepted = true;
         link.broker_position_ticket = FindLatestFalconPositionTicket(_Symbol, FC_MAGIC_FVG_MICRO);
         if(link.broker_position_ticket > 0 && PositionSelectByTicket(link.broker_position_ticket))
            link.broker_position_identifier = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
         link.status = FALCON_BEEB_ENTRY_ACCEPTED_STATUS;
         link.reason = StringFormat("OrderSend accepted retcode=%d; LOCK parity emergency server-stop envelope active; serverStopPolicy=%s; plannedBridgeTp=%.5f; broker exits should be EA-managed at Paper final unless emergency server SL/TP is hit; managedPolicy=%s; %s; %s; %s", (int)result.retcode, FALCON_LOCK_PARITY_SERVER_STOP_POLICY, initial_bridge_tp, FALCON_MREB_DECISION_POLICY, initial_bridge_tp_reason, emergency_server_stop_reason, lot_authority_reason);
         m_entry_accepted++;
         m_previous_broker_authority_lot = volume;
         m_previous_broker_authority_lot_ready = true;
         StoreAcceptedLink(link);
      }
      else
      {
         link.broker_entry_accepted = false;
         link.status = FALCON_BEEB_ENTRY_BLOCKED_STATUS;
         link.reason = StringFormat("OrderSend failed/blocked sent=%s retcode=%d comment=%s", (sent ? "true" : "false"), (int)result.retcode, result.comment);
         m_entry_blocked++;
      }

      StoreOrUpdateAuditLink(link);
      report_writer.AppendBrokerEntryBridgeLifecycleRecord(link);
      return link.broker_entry_accepted;
   }

   // ==================================================================
   // v0.57.2: Reverse-deal close helper - extracted from
   // TryManagedCloseFromLifecycleRecord so the new Virtual Trailing
   // Bridge can reuse the SAME OrderSend(TRADE_ACTION_DEAL) path without
   // duplicating it. Caller must have already validated:
   //   - link.broker_position_ticket > 0
   //   - PositionSelectByTicket succeeded
   //   - position identity (_Symbol + FC_MAGIC_FVG_MICRO) matches
   //   - PositionGetDouble(POSITION_VOLUME) > 0  (passed as volume)
   //   - PositionGetInteger(POSITION_TYPE)        (passed as position_type)
   //
   // Helper handles: SymbolInfoTick, request build, OrderSend, link/audit
   // updates, and ManagedCloseLifecycle row. Lifecycle-specific and
   // trailing-specific post-reports remain at the caller (e.g.
   // BrokerPaperTradeReconciliation, VirtualTrailingExitLifecycle).
   //
   // Returns true iff OrderSend was actually called (regardless of broker
   // acceptance). accepted_out is true only when retcode is DONE/PLACED/
   // DONE_PARTIAL. On pre-send failures (no tick, unsupported type) logs
   // a ManagedCloseLifecycle block row and returns false.
   // ==================================================================
   bool ExecuteReverseClosePositionRequest(FalconBrokerTradeLink &link,
                                           const long position_type,
                                           const double volume,
                                           const string comment_prefix,
                                           const string lifecycle_reason,
                                           CFalconReportWriter &report_writer,
                                           bool &accepted_out,
                                           uint &retcode_out,
                                           double &executed_price_out,
                                           string &result_comment_out)
   {
      accepted_out = false;
      retcode_out = 0;
      executed_price_out = 0.0;
      result_comment_out = "";

      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick))
      {
         string tick_reason = "EA-managed close blocked: SymbolInfoTick unavailable; tradeId=" + link.trade_id;
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              volume,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_BLOCKED_NO_TICK",
                                                              tick_reason);
         return false;
      }

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action    = TRADE_ACTION_DEAL;
      request.symbol    = _Symbol;
      request.position  = link.broker_position_ticket;
      request.volume    = volume;
      request.magic     = FC_MAGIC_FVG_MICRO;
      request.deviation = 30;
      request.comment   = FalconBuildBrokerCommentWithHash(comment_prefix, link.trade_id);
      request.type_time = ORDER_TIME_GTC;

      if(position_type == POSITION_TYPE_BUY)
      {
         request.type  = ORDER_TYPE_SELL;
         request.price = tick.bid;
      }
      else if(position_type == POSITION_TYPE_SELL)
      {
         request.type  = ORDER_TYPE_BUY;
         request.price = tick.ask;
      }
      else
      {
         string type_reason = StringFormat("EA-managed close blocked: unsupported position type=%d; tradeId=%s", (int)position_type, link.trade_id);
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              volume,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_BLOCKED_UNSUPPORTED_POSITION_TYPE",
                                                              type_reason);
         return false;
      }

      bool sent = OrderSend(request, result);
      accepted_out       = (sent && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE_PARTIAL));
      retcode_out        = result.retcode;
      executed_price_out = request.price;
      result_comment_out = result.comment;

      string status = accepted_out ? "EA_MANAGED_CLOSE_REQUEST_ACCEPTED_WAITING_ON_TRADE_TRANSACTION" : "EA_MANAGED_CLOSE_REQUEST_REJECTED";
      string reason = StringFormat("Controlled tester-only EA-side managed close via %s; sent=%s; retcode=%d; resultComment=%s; lifecycleReason=%s; no BrokerModify; no RuntimeSLChanged; Demo/Live blocked",
                                   comment_prefix,
                                   (sent ? "true" : "false"),
                                   (int)result.retcode,
                                   result.comment,
                                   lifecycle_reason);

      link.broker_close_attempted     = true;
      link.broker_close_accepted      = accepted_out;
      link.managed_close_attempted    = true;
      link.managed_close_accepted     = accepted_out;
      link.broker_close_order_ticket  = result.order;
      link.broker_close_deal_ticket   = result.deal;
      link.managed_close_comment      = request.comment;
      UpdateAuditLinkManagedCloseRequest(link.trade_id, true, accepted_out, result.order, result.deal, request.comment);

      report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                           true,
                                                           accepted_out,
                                                           result.order,
                                                           result.deal,
                                                           request.price,
                                                           volume,
                                                           TimeCurrent(),
                                                           status,
                                                           reason);
      return true;
   }

   bool TryManagedCloseFromLifecycleRecord(const FalconTradeLifecycleRecord &record, CFalconReportWriter &report_writer)
   {
      if(!FALCON_MREB_RUNTIME_MANAGED_CLOSE_READY)
         return false;
      if(!EnableRealExecution)
         return false;
      if(!MQLInfoInteger(MQL_TESTER))
         return false;

      StorePaperFinalRecord(record);

      FalconBrokerTradeLink link;
      if(!FindActiveLinkByTradeId(record.trade_id, link))
      {
         if(FindAuditLinkByTradeId(record.trade_id, link))
         {
            if(link.broker_entry_accepted && link.broker_exit_observed)
            {
               string already_observed_reason = "No active broker link found at Paper finalization, but audit history already contains a realized broker exit. This is a valid closed-before-Paper-final reconciliation row.";
               report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                                        link,
                                                                        "BROKER_EXIT_ALREADY_OBSERVED_BEFORE_PAPER_FINAL",
                                                                        "BROKER_ALREADY_CLOSED_BEFORE_PAPER_FINAL_ACTUAL_DELTA_AVAILABLE",
                                                                        already_observed_reason);
               return false;
            }

            if(link.broker_entry_accepted && RecoverClosedBrokerExitFromHistory(link,
                                                                                record,
                                                                                report_writer,
                                                                                "NO_ACTIVE_LINK_AUDIT_HISTORY_RECOVERY"))
               return false;

            report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                                     link,
                                                                     "PAPER_FINAL_NO_ACTIVE_BROKER_POSITION",
                                                                     link.broker_entry_accepted ? "BROKER_ALREADY_CLOSED_BEFORE_PAPER_FINAL_OR_LINK_INACTIVE_ACTUAL_DELTA_NOT_FOUND" : "PAPER_TRADE_NOT_OPENED_ON_BROKER",
                                                                     link.broker_entry_accepted ? "No active broker link found at Paper finalization; history recovery could not locate a realized close deal, so actual delta remains unreconciled." : "Paper trade has no active broker link; entry was blocked or never opened.");
         }
         else
         {
            FalconBrokerTradeLink empty_link;
            ResetLinkFromShadowRecordId(record, empty_link);
            report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                                     empty_link,
                                                                     "PAPER_FINAL_NO_BROKER_LINK_FOUND",
                                                                     "NO_BROKER_AUDIT_LINK_FOR_TRADEID",
                                                                     "No active or audit broker link matched this Paper TradeId.");
         }
         return false;
      }

      report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                               link,
                                                               "PAPER_FINAL_ACTIVE_BROKER_LINK_FOUND_BEFORE_MANAGED_CLOSE",
                                                               "ACTIVE_LINK_FOUND_MANAGED_CLOSE_DECISION_PENDING",
                                                               "Paper final lifecycle closed while broker position is still active; controlled tester-only managed close will be evaluated.");

      if(link.broker_position_ticket <= 0)
      {
         if(RecoverClosedBrokerExitFromHistory(link,
                                               record,
                                               report_writer,
                                               "ACTIVE_LINK_NO_POSITION_TICKET_HISTORY_RECOVERY"))
            return false;

         string no_ticket_reason = "EA-managed close skipped: active broker link has no broker position ticket and history recovery did not find a realized close deal; tradeId=" + record.trade_id;
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              0.0,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_SKIPPED_NO_POSITION_TICKET",
                                                              no_ticket_reason);
         return false;
      }

      if(!PositionSelectByTicket(link.broker_position_ticket))
      {
         if(RecoverClosedBrokerExitFromHistory(link,
                                               record,
                                               report_writer,
                                               "POSITION_SELECT_FAILED_BEFORE_MANAGED_CLOSE_HISTORY_RECOVERY"))
            return false;

         string missing_pos_reason = "EA-managed close skipped: linked broker position no longer exists before managed close, and history recovery did not find a realized close deal; likely already closed by server TP/SL or tester but actual delta remains unreconciled; tradeId=" + record.trade_id;
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              0.0,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_SKIPPED_POSITION_ALREADY_CLOSED_ACTUAL_DELTA_NOT_FOUND",
                                                              missing_pos_reason);
         MarkLinkClosed(link.broker_position_ticket, link.broker_order_ticket, link.broker_deal_ticket);
         return false;
      }

      string pos_symbol = PositionGetString(POSITION_SYMBOL);
      long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(pos_symbol != _Symbol || pos_magic != FC_MAGIC_FVG_MICRO)
      {
         string mismatch_reason = StringFormat("EA-managed close blocked: linked position identity mismatch posSymbol=%s posMagic=%d expectedSymbol=%s expectedMagic=%d tradeId=%s",
                                               pos_symbol,
                                               (int)pos_magic,
                                               _Symbol,
                                               (int)FC_MAGIC_FVG_MICRO,
                                               record.trade_id);
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              0.0,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_BLOCKED_POSITION_IDENTITY_MISMATCH",
                                                              mismatch_reason);
         return false;
      }

      double volume = PositionGetDouble(POSITION_VOLUME);
      if(volume <= 0.0)
      {
         string volume_reason = "EA-managed close blocked: linked position volume is not positive; tradeId=" + record.trade_id;
         report_writer.AppendBrokerManagedCloseLifecycleRecord(link,
                                                              false,
                                                              false,
                                                              0,
                                                              0,
                                                              0.0,
                                                              0.0,
                                                              TimeCurrent(),
                                                              "EA_MANAGED_CLOSE_BLOCKED_INVALID_POSITION_VOLUME",
                                                              volume_reason);
         return false;
      }

      long position_type = (long)PositionGetInteger(POSITION_TYPE);

      // v0.57.2: OrderSend block factored into ExecuteReverseClosePositionRequest so the
      // Virtual Trailing Exit Bridge can reuse the same close path. Lifecycle-specific
      // post-reporting (BrokerPaperTradeReconciliation) remains here.
      string lifecycle_reason = LifecycleManagedCloseReason(record);
      bool accepted = false;
      uint retcode = 0;
      double executed_price = 0.0;
      string result_comment = "";
      bool sent = ExecuteReverseClosePositionRequest(link,
                                                    position_type,
                                                    volume,
                                                    FALCON_MREB_CLOSE_COMMENT_PREFIX,
                                                    lifecycle_reason,
                                                    report_writer,
                                                    accepted,
                                                    retcode,
                                                    executed_price,
                                                    result_comment);
      if(!sent)
         return false;

      string paper_reconciliation_reason = StringFormat("Controlled tester-only EA-side managed close at Paper final lifecycle exit; sent=true; retcode=%d; resultComment=%s; lifecycleReason=%s; no BrokerModify; no RuntimeSLChanged; Demo/Live blocked",
                                                       (int)retcode,
                                                       result_comment,
                                                       lifecycle_reason);
      report_writer.AppendBrokerPaperTradeReconciliationRecord(record,
                                                               link,
                                                               "EA_MANAGED_CLOSE_REQUEST_SENT",
                                                               accepted ? "MANAGED_CLOSE_REQUEST_ACCEPTED_ACTUAL_DELTA_PENDING_TRANSACTION" : "MANAGED_CLOSE_REQUEST_REJECTED",
                                                               paper_reconciliation_reason);
      return accepted;
   }

   // ==================================================================
   // R1.2c: S00-specific real close.
   //
   // Called from CS00EntryLogic::CloseActiveTrade when the strategy
   // decides to exit (target, structural/BE stop, timeout). Looks up
   // the active broker link by trade_id (captured at real entry),
   // validates position identity (symbol + FC_MAGIC_FVG_MICRO), and
   // issues a reverse-deal close via ExecuteReverseClosePositionRequest
   // - the same helper the Virtual Trailing Bridge uses for the legacy
   // strategy. No new OrderSend logic.
   //
   // The three real-execution gates (MQL_TESTER + EnableRealExecution +
   // S00_RealExecution) are enforced at the call site AND re-checked
   // here as a defense-in-depth contract; either layer alone keeps the
   // legacy FixedLot April baseline (585.17 / 1104.89 / 157.49) safe
   // when gates are shut.
   //
   // No BrokerModify, no TRADE_ACTION_SLTP, no RuntimeSLChanged. S00
   // breakeven protection at the broker is realized by closing the
   // position when the paper SL (moved to entry) is touched - never
   // by moving the server stop. Demo/Live blocked via MQL_TESTER and
   // EnableRealExecution. Returns true iff the reverse-deal OrderSend
   // was accepted by the tester.
   // ==================================================================
   bool TryManagedCloseFromS00Trade(const string &trade_id,
                                    const double exit_price,
                                    const ENUM_S00_TRADE_EXIT_REASON reason,
                                    CFalconReportWriter &report_writer)
   {
      if(!MQLInfoInteger(MQL_TESTER))
         return false;
      if(!EnableRealExecution)
         return false;
      if(!S00_RealExecution)
         return false;

      // Empty trade_id means the paper trade was opened without a real
      // entry (gates were shut at open, or the bridge rejected the
      // entry). Nothing to close on the broker side.
      if(StringLen(trade_id) <= 0)
         return false;

      FalconBrokerTradeLink link;
      if(!FindActiveLinkByTradeId(trade_id, link))
         return false;

      if(link.broker_position_ticket <= 0)
         return false;

      if(!PositionSelectByTicket(link.broker_position_ticket))
      {
         // Position no longer exists - likely already closed by the
         // server emergency SL/TP envelope before S00 reached its exit
         // decision. Mark link closed so audit stays consistent and
         // the next entry attempt is not blocked by a stale link.
         MarkLinkClosed(link.broker_position_ticket, link.broker_order_ticket, link.broker_deal_ticket);
         return false;
      }

      string pos_symbol = PositionGetString(POSITION_SYMBOL);
      long   pos_magic  = (long)PositionGetInteger(POSITION_MAGIC);
      if(pos_symbol != _Symbol || pos_magic != FC_MAGIC_FVG_MICRO)
         return false;

      double volume = PositionGetDouble(POSITION_VOLUME);
      if(volume <= 0.0)
         return false;

      long position_type = (long)PositionGetInteger(POSITION_TYPE);

      string lifecycle_reason = StringFormat("S00_CLOSE reason=%s exitPrice=%.5f tradeId=%s",
                                             EnumToString(reason),
                                             exit_price,
                                             trade_id);

      bool   accepted       = false;
      uint   retcode        = 0;
      double executed_price = 0.0;
      string result_comment = "";
      bool sent = ExecuteReverseClosePositionRequest(link,
                                                     position_type,
                                                     volume,
                                                     FALCON_MREB_CLOSE_COMMENT_PREFIX,
                                                     lifecycle_reason,
                                                     report_writer,
                                                     accepted,
                                                     retcode,
                                                     executed_price,
                                                     result_comment);
      return sent && accepted;
   }

   // ==================================================================
   // v0.57.4: Structural Breakeven swing detection.
   // Scans the last `max_lookback` CLOSED M5 bars (shift >= 1, no lookahead)
   // for the most recent confirmed swing low / high. A swing low at bar i
   // requires strictly lower `low` than the `swing_n` bars immediately before
   // it (older) and the `swing_n` bars immediately after it (newer). Returns
   // 0.0 when no qualifying swing exists in the window.
   //
   // CopyRates is requested with ArraySetAsSeries(true) so r[0] is the most
   // recent CLOSED bar and r[count-1] is the oldest bar in the window.
   // Walking i from swing_n upward then yields swings in newest-first order;
   // the first hit is the most recent confirmed swing.
   // ==================================================================
   double FindLastSwingLow(const int swing_n, const int max_lookback)
   {
      if(swing_n < 1 || max_lookback < 1)
         return 0.0;
      int need = max_lookback + swing_n;
      MqlRates r[];
      ArraySetAsSeries(r, true);
      int copied = CopyRates(_Symbol, PERIOD_M5, 1, need, r);
      if(copied < (2 * swing_n + 1))
         return 0.0;
      int last_index = ArraySize(r) - swing_n - 1;
      for(int i = swing_n; i <= last_index; i++)
      {
         bool is_low = true;
         for(int k = 1; k <= swing_n; k++)
         {
            if(r[i].low >= r[i - k].low || r[i].low >= r[i + k].low)
            {
               is_low = false;
               break;
            }
         }
         if(is_low)
            return r[i].low;
      }
      return 0.0;
   }

   double FindLastSwingHigh(const int swing_n, const int max_lookback)
   {
      if(swing_n < 1 || max_lookback < 1)
         return 0.0;
      int need = max_lookback + swing_n;
      MqlRates r[];
      ArraySetAsSeries(r, true);
      int copied = CopyRates(_Symbol, PERIOD_M5, 1, need, r);
      if(copied < (2 * swing_n + 1))
         return 0.0;
      int last_index = ArraySize(r) - swing_n - 1;
      for(int i = swing_n; i <= last_index; i++)
      {
         bool is_high = true;
         for(int k = 1; k <= swing_n; k++)
         {
            if(r[i].high <= r[i - k].high || r[i].high <= r[i + k].high)
            {
               is_high = false;
               break;
            }
         }
         if(is_high)
            return r[i].high;
      }
      return 0.0;
   }

   // ==================================================================
   // v0.57.2: Virtual Trailing Exit Bridge - tick-driven update.
   // For every open broker link: maintains peak-favorable price, locks
   // breakeven, arms trailing, and closes via OrderSend(TRADE_ACTION_DEAL)
   // reverse (through the factored helper). No BrokerModify, no
   // TRADE_ACTION_SLTP, no RuntimeSLChanged. Emergency server SL/TP from
   // v0.56.9b stays attached - this is the regular exit; server SL/TP is
   // the safety net.
   //
   // Gated externally by OnTick (EnableVirtualTrailingBridge &&
   // EnableRealExecution && MQL_TESTER). Redundant internal guards for
   // safety in case the method is ever called from elsewhere.
   // ==================================================================
   void UpdateVirtualTrailingForOpenLinks(CFalconReportWriter &report_writer)
   {
      if(!EnableVirtualTrailingBridge)
         return;
      if(!EnableRealExecution)
         return;
      if(!MQLInfoInteger(MQL_TESTER))
         return;
      if(!FALCON_MREB_RUNTIME_MANAGED_CLOSE_READY)
         return;

      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick))
         return;

      int total = ArraySize(m_active_links);
      for(int i = 0; i < total; i++)
      {
         if(!m_active_links[i].broker_entry_accepted) continue;
         if(m_active_links[i].broker_exit_observed)   continue;
         if(m_active_links[i].broker_close_attempted) continue;
         if(m_active_links[i].broker_position_ticket == 0) continue;
         if(m_active_links[i].broker_entry_price <= 0.0)   continue;

         double current_price = 0.0;
         if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
            current_price = tick.bid;
         else if(m_active_links[i].direction == FALCON_DIRECTION_SELL)
            current_price = tick.ask;
         else
            continue;
         if(current_price <= 0.0) continue;

         double profit_points = FalconRawIndexPoints(m_active_links[i].direction,
                                                    m_active_links[i].broker_entry_price,
                                                    current_price);

         // 4.2 Update peak favorable price (one-direction).
         if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
         {
            if(m_active_links[i].virtual_peak_favorable_price <= 0.0 ||
               current_price > m_active_links[i].virtual_peak_favorable_price)
               m_active_links[i].virtual_peak_favorable_price = current_price;
         }
         else
         {
            if(m_active_links[i].virtual_peak_favorable_price <= 0.0 ||
               current_price < m_active_links[i].virtual_peak_favorable_price)
               m_active_links[i].virtual_peak_favorable_price = current_price;
         }

         // 4.3 Lock breakeven once profit crosses VirtualBreakevenAtPoints.
         // v0.57.3: spread-aware floor anchored on entry.
         // v0.57.4: when EnableStructuralBreakeven is on, anchor the floor on the
         // most recent confirmed M5 swing low (BUY) / swing high (SELL) that lies
         // BETWEEN broker_entry_price and current_price. If no qualifying swing
         // exists yet (early in the trade), fall back to the v0.57.3 spread-aware
         // floor so the position is never left unprotected.
         if(!m_active_links[i].virtual_breakeven_locked &&
            profit_points >= VirtualBreakevenAtPoints)
         {
            long   spread_points_long = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
            double spread_price       = (double)spread_points_long * _Point;
            double be_buffer          = spread_price + (FALCON_VIRTUAL_TRAILING_BE_EXTRA_POINTS * _Point);

            double structural_floor = 0.0;
            if(EnableStructuralBreakeven)
            {
               if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
               {
                  double sl = FindLastSwingLow(VirtualSwingLookbackBars, VirtualSwingMaxLookback);
                  // Accept only a swing low ABOVE entry and BELOW current bid.
                  if(sl > m_active_links[i].broker_entry_price && sl < current_price)
                     structural_floor = sl;
               }
               else
               {
                  double sh = FindLastSwingHigh(VirtualSwingLookbackBars, VirtualSwingMaxLookback);
                  // Accept only a swing high BELOW entry and ABOVE current ask.
                  if(sh > 0.0 && sh < m_active_links[i].broker_entry_price && sh > current_price)
                     structural_floor = sh;
               }
            }

            m_active_links[i].virtual_breakeven_locked = true;
            if(structural_floor > 0.0)
            {
               m_active_links[i].virtual_protection_floor_price = structural_floor;
               m_active_links[i].virtual_breakeven_mode = "STRUCTURAL";
            }
            else
            {
               if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
                  m_active_links[i].virtual_protection_floor_price = m_active_links[i].broker_entry_price + be_buffer;
               else
                  m_active_links[i].virtual_protection_floor_price = m_active_links[i].broker_entry_price - be_buffer;
               m_active_links[i].virtual_breakeven_mode = "FIXED_FALLBACK";
            }
         }

         // 4.4 Arm trailing once profit crosses VirtualTrailingStartPoints.
         if(!m_active_links[i].virtual_trailing_active &&
            profit_points >= VirtualTrailingStartPoints)
            m_active_links[i].virtual_trailing_active = true;

         // 4.5 Trailing stop moves in one direction only.
         if(m_active_links[i].virtual_trailing_active)
         {
            if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
            {
               double trail = m_active_links[i].virtual_peak_favorable_price - VirtualTrailingDistancePoints;
               if(m_active_links[i].virtual_trailing_stop_price <= 0.0 ||
                  trail > m_active_links[i].virtual_trailing_stop_price)
                  m_active_links[i].virtual_trailing_stop_price = trail;
            }
            else
            {
               double trail = m_active_links[i].virtual_peak_favorable_price + VirtualTrailingDistancePoints;
               if(m_active_links[i].virtual_trailing_stop_price <= 0.0 ||
                  trail < m_active_links[i].virtual_trailing_stop_price)
                  m_active_links[i].virtual_trailing_stop_price = trail;
            }
         }

         m_active_links[i].virtual_trailing_last_update = TimeCurrent();

         // 4.6 Effective stop = deepest protection between floor and trail (ignoring zeros).
         double floor_price = m_active_links[i].virtual_breakeven_locked ? m_active_links[i].virtual_protection_floor_price : 0.0;
         double trail_price = m_active_links[i].virtual_trailing_active ? m_active_links[i].virtual_trailing_stop_price : 0.0;

         double effective_stop = 0.0;
         if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
         {
            if(floor_price > 0.0 && trail_price > 0.0)
               effective_stop = MathMax(floor_price, trail_price);
            else if(floor_price > 0.0)
               effective_stop = floor_price;
            else if(trail_price > 0.0)
               effective_stop = trail_price;
         }
         else
         {
            if(floor_price > 0.0 && trail_price > 0.0)
               effective_stop = MathMin(floor_price, trail_price);
            else if(floor_price > 0.0)
               effective_stop = floor_price;
            else if(trail_price > 0.0)
               effective_stop = trail_price;
         }

         if(effective_stop <= 0.0) continue;

         // 4.7 Hit decision.
         bool hit = false;
         if(m_active_links[i].direction == FALCON_DIRECTION_BUY)
            hit = (current_price <= effective_stop);
         else
            hit = (current_price >= effective_stop);
         if(!hit) continue;

         // Trigger reason: trail is binding when it equals effective_stop and trailing is active.
         bool trail_is_binding = (m_active_links[i].virtual_trailing_active &&
                                  trail_price > 0.0 &&
                                  MathAbs(effective_stop - trail_price) < 0.0000001);
         string trigger_reason = trail_is_binding ? "TRAILING_STOP_HIT" : "BREAKEVEN_FLOOR_HIT";

         // Validate live position before calling the close helper.
         if(!PositionSelectByTicket(m_active_links[i].broker_position_ticket)) continue;
         string pos_symbol = PositionGetString(POSITION_SYMBOL);
         long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
         if(pos_symbol != _Symbol || pos_magic != FC_MAGIC_FVG_MICRO) continue;
         double volume = PositionGetDouble(POSITION_VOLUME);
         if(volume <= 0.0) continue;
         long position_type = (long)PositionGetInteger(POSITION_TYPE);

         bool accepted = false;
         uint retcode = 0;
         double executed_price = 0.0;
         string result_comment = "";
         string lifecycle_reason = StringFormat("VirtualTrailing-initiated close: reason=%s; profitPts=%.2f; effectiveStop=%.5f; peak=%.5f; trailActive=%s; beLocked=%s",
                                                trigger_reason,
                                                profit_points,
                                                effective_stop,
                                                m_active_links[i].virtual_peak_favorable_price,
                                                m_active_links[i].virtual_trailing_active ? "true" : "false",
                                                m_active_links[i].virtual_breakeven_locked ? "true" : "false");

         bool sent = ExecuteReverseClosePositionRequest(m_active_links[i],
                                                        position_type,
                                                        volume,
                                                        FALCON_VIRTUAL_TRAILING_CLOSE_COMMENT_PREFIX,
                                                        lifecycle_reason,
                                                        report_writer,
                                                        accepted,
                                                        retcode,
                                                        executed_price,
                                                        result_comment);

         string trailing_status = sent
                                  ? (accepted ? "TRAILING_CLOSE_REQUEST_ACCEPTED_WAITING_ON_TRADE_TRANSACTION"
                                              : "TRAILING_CLOSE_REQUEST_REJECTED")
                                  : "TRAILING_CLOSE_PRE_SEND_BLOCKED";

         // v0.57.3: pass the actual exit price the helper sent (or the tick price if the
         // helper short-circuited pre-send). The report writer derives RealizedPointsAtExit
         // and EstimatedUsdAtExit from link + exit_price + its own symbol context.
         report_writer.AppendVirtualTrailingExitLifecycleRecord(m_active_links[i],
                                                                TimeCurrent(),
                                                                sent ? executed_price : current_price,
                                                                profit_points,
                                                                trigger_reason,
                                                                retcode,
                                                                trailing_status);
      }
   }

   bool ObserveTradeTransactionExit(const MqlTradeTransaction &trans, CFalconReportWriter &report_writer)
   {
      if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
         return false;
      if(trans.deal == 0)
         return false;
      if(!HistoryDealSelect(trans.deal))
         return false;

      string deal_symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
      long deal_magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
      if(deal_symbol != _Symbol || deal_magic != FC_MAGIC_FVG_MICRO)
         return false;

      long deal_entry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if(!(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
         return false;

      ulong position_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      ulong order_ticket = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
      string deal_comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
      string order_comment = "";
      if(order_ticket > 0 && HistoryOrderSelect(order_ticket))
         order_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);
      string deal_hash = FalconExtractCommentHash(deal_comment);
      string order_hash = FalconExtractCommentHash(order_comment);

      FalconBrokerTradeLink link;
      string mapped_by = "UNMAPPED";

      if(FindActiveLinkByPositionIdentifier(position_id, link))
         mapped_by = "POSITION_IDENTIFIER";
      else if(FindActiveLinkByPosition(position_id, link))
         mapped_by = "POSITION_TICKET_FROM_DEAL_POSITION_ID";
      else if(FindActiveLinkByPosition(trans.position, link))
         mapped_by = "TRANS_POSITION";
      else if(FindActiveLinkByOrderOrDeal(order_ticket, trans.deal, link))
         mapped_by = "ORDER_OR_ENTRY_DEAL";
      else if(FindAuditLinkByTradeHash(deal_hash, link))
         mapped_by = "DEAL_COMMENT_HASH";
      else if(FindAuditLinkByTradeHash(order_hash, link))
         mapped_by = "ORDER_COMMENT_HASH";
      else if(FindSingleActiveLink(link))
         mapped_by = "SINGLE_ACTIVE_LINK_FALLBACK";
      else
         return false;

      double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
      double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
      double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      double actual_delta = profit + swap + commission;
      double close_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
      double close_volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
      datetime close_time = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
      long deal_reason = (long)HistoryDealGetInteger(trans.deal, DEAL_REASON);
      string exit_status = BrokerDealReasonToObservationStatus(deal_reason);
      string managed_runner_classification = "MANAGED_RUNNER_CLASSIFICATION_PENDING";
      if(deal_reason == DEAL_REASON_TP)
         managed_runner_classification = "SERVER_TP_EXIT_IS_TP3_SAFETY_CAP_NOT_FINAL_RUNNER_PARITY";
      else if(deal_reason == DEAL_REASON_SL)
         managed_runner_classification = "SERVER_SL_EXIT_BEFORE_MANAGED_RUNNER_DECISION";
      string exit_reason = StringFormat("OnTradeTransaction broker exit observed; mappedBy=%s; dealEntry=%s; dealReason=%d; profit=%.4f; swap=%.4f; commission=%.4f; dealComment=%s; orderComment=%s; dealHash=%s; orderHash=%s; managedRunnerStatus=%s; managedPolicy=%s",
                                        mapped_by,
                                        BrokerDealEntryToString(deal_entry),
                                        (int)deal_reason,
                                        profit,
                                        swap,
                                        commission,
                                        deal_comment,
                                        order_comment,
                                        deal_hash,
                                        order_hash,
                                        managed_runner_classification,
                                        FALCON_MREB_DECISION_POLICY);

      UpdateLinkCloseObservation(link,
                                 order_ticket,
                                 trans.deal,
                                 close_price,
                                 close_volume,
                                 actual_delta,
                                 close_time,
                                 exit_status,
                                 exit_reason);

      report_writer.AppendBrokerExitObservationLifecycleRecord(link,
                                                               trans.deal,
                                                               order_ticket,
                                                               close_price,
                                                               close_volume,
                                                               actual_delta,
                                                               close_time,
                                                               exit_status,
                                                               exit_reason);
      FalconTradeLifecycleRecord paper_record;
      if(FindPaperFinalRecord(link.trade_id, paper_record))
      {
         report_writer.AppendBrokerPaperTradeReconciliationRecord(paper_record,
                                                                  link,
                                                                  "BROKER_EXIT_OBSERVED_WITH_PAPER_FINAL",
                                                                  "BROKER_EXIT_ACTUAL_DELTA_RECONCILED_TO_PAPER_FINAL",
                                                                  exit_reason);
      }
      else
      {
         string broker_only_reason = exit_reason + "; brokerOnly=true; no Paper final TradeLifecycle record exists for this TradeId; this is a LOCK parity violation that must be eliminated before profit parity or Demo/Live.";
         report_writer.AppendBrokerOnlyTradeReconciliationRecord(link,
                                                                 "BROKER_EXIT_OBSERVED_WITHOUT_PAPER_FINAL_BROKER_ONLY",
                                                                 "BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE",
                                                                 broker_only_reason);
      }
      MarkLinkClosed(position_id, order_ticket, trans.deal);
      return true;
   }



   bool RecoverBrokerOnlyExitFromHistory(FalconBrokerTradeLink &link,
                                         CFalconReportWriter &report_writer,
                                         const string recovery_context)
   {
      // v0.56.9: best-effort recovery for active links that never received a
      // Paper final record. This helps catch tester/end-of-test closes and makes
      // broker-only impact visible in BrokerPaperTradeReconciliation.
      if(!link.broker_entry_accepted)
         return false;
      if(link.broker_exit_observed)
      {
         report_writer.AppendBrokerOnlyTradeReconciliationRecord(link,
                                                                 "BROKER_ONLY_EXIT_ALREADY_OBSERVED_WITHOUT_PAPER_FINAL",
                                                                 "BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE",
                                                                 "Broker-only exit was already observed before Deinit; no Paper final TradeLifecycle record exists; context=" + recovery_context);
         return true;
      }

      datetime history_from = link.broker_entry_time;
      if(history_from > 86400)
         history_from -= 86400;
      else
         history_from = 0;
      datetime history_to = TimeCurrent() + 86400;
      if(!HistorySelect(history_from, history_to))
         return false;

      string target_hash = link.trade_id_short;
      if(StringLen(target_hash) <= 0)
         target_hash = FalconTradeIdShortHash(link.trade_id);

      ulong best_deal = 0;
      ulong best_order = 0;
      datetime best_time = 0;
      double best_profit = 0.0;
      double best_swap = 0.0;
      double best_commission = 0.0;
      double best_price = 0.0;
      double best_volume = 0.0;
      long best_reason = 0;
      long best_entry = 0;
      string best_deal_comment = "";
      string best_order_comment = "";
      string best_match = "UNMATCHED";

      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;
         if(!HistoryDealSelect(deal_ticket))
            continue;

         string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_symbol != _Symbol)
            continue;

         long deal_entry = (long)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(!(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
            continue;

         datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         if(link.broker_entry_time > 0 && deal_time < link.broker_entry_time)
            continue;

         ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
         ulong order_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
         string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
         string order_comment = "";
         if(order_ticket > 0 && HistoryOrderSelect(order_ticket))
            order_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);

         string deal_hash = FalconExtractCommentHash(deal_comment);
         string order_hash = FalconExtractCommentHash(order_comment);

         bool identity_match = false;
         string match_by = "";
         if(position_id > 0 && link.broker_position_identifier > 0 && position_id == link.broker_position_identifier)
         {
            identity_match = true;
            match_by = "POSITION_IDENTIFIER_HISTORY_BROKER_ONLY";
         }
         else if(position_id > 0 && link.broker_position_ticket > 0 && position_id == link.broker_position_ticket)
         {
            identity_match = true;
            match_by = "POSITION_TICKET_HISTORY_BROKER_ONLY";
         }
         else if(order_ticket > 0 && (order_ticket == link.broker_order_ticket || order_ticket == link.broker_close_order_ticket))
         {
            identity_match = true;
            match_by = "ORDER_TICKET_HISTORY_BROKER_ONLY";
         }
         else if(StringLen(target_hash) > 0 && deal_hash == target_hash)
         {
            identity_match = true;
            match_by = "DEAL_COMMENT_HASH_HISTORY_BROKER_ONLY";
         }
         else if(StringLen(target_hash) > 0 && order_hash == target_hash)
         {
            identity_match = true;
            match_by = "ORDER_COMMENT_HASH_HISTORY_BROKER_ONLY";
         }

         long deal_magic = (long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         if(deal_magic != FC_MAGIC_FVG_MICRO && !identity_match)
            continue;
         if(!identity_match)
            continue;

         if(best_deal == 0 || deal_time >= best_time)
         {
            best_deal = deal_ticket;
            best_order = order_ticket;
            best_time = deal_time;
            best_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            best_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            best_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            best_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            best_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
            best_reason = (long)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
            best_entry = deal_entry;
            best_deal_comment = deal_comment;
            best_order_comment = order_comment;
            best_match = match_by;
         }
      }

      if(best_deal == 0)
         return false;

      double actual_delta = best_profit + best_swap + best_commission;
      string exit_status = BrokerDealReasonToObservationStatus(best_reason);
      string recovery_reason = StringFormat("Broker-only history recovery; context=%s; mappedBy=%s; dealEntry=%s; dealReason=%d; profit=%.4f; swap=%.4f; commission=%.4f; dealComment=%s; orderComment=%s; no Paper final TradeLifecycle record exists; LOCK parity violation",
                                            recovery_context,
                                            best_match,
                                            BrokerDealEntryToString(best_entry),
                                            (int)best_reason,
                                            best_profit,
                                            best_swap,
                                            best_commission,
                                            best_deal_comment,
                                            best_order_comment);

      UpdateLinkCloseObservation(link,
                                 best_order,
                                 best_deal,
                                 best_price,
                                 best_volume,
                                 actual_delta,
                                 best_time,
                                 exit_status,
                                 recovery_reason);

      report_writer.AppendBrokerExitObservationLifecycleRecord(link,
                                                               best_deal,
                                                               best_order,
                                                               best_price,
                                                               best_volume,
                                                               actual_delta,
                                                               best_time,
                                                               exit_status,
                                                               recovery_reason);
      report_writer.AppendBrokerOnlyTradeReconciliationRecord(link,
                                                              "BROKER_ONLY_EXIT_RECOVERED_FROM_HISTORY_AT_DEINIT",
                                                              "BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE_ACTUAL_DELTA_RECOVERED",
                                                              recovery_reason);
      MarkLinkClosed(link.broker_position_identifier > 0 ? link.broker_position_identifier : link.broker_position_ticket,
                     best_order,
                     best_deal);
      return true;
   }

   void FlushOpenLinksAtDeinit(CFalconReportWriter &report_writer)
   {
      int n = ArraySize(m_active_links);
      if(n <= 0)
         return;

      for(int i = 0; i < n; i++)
      {
         FalconBrokerTradeLink link = m_active_links[i];
         if(RecoverBrokerOnlyExitFromHistory(link, report_writer, "FLUSH_OPEN_LINKS_AT_DEINIT_HISTORY_RECOVERY"))
            continue;

         double current_price = 0.0;
         double current_volume = (link.accepted_lot > 0.0 ? link.accepted_lot : link.requested_lot);
         double floating_delta = 0.0;
         string position_state = "POSITION_NOT_SELECTED_AT_DEINIT";

         if(link.broker_position_ticket > 0 && PositionSelectByTicket(link.broker_position_ticket))
         {
            current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            current_volume = PositionGetDouble(POSITION_VOLUME);
            floating_delta = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            position_state = "POSITION_STILL_OPEN_AT_DEINIT_FLOATING_DELTA_ONLY";
         }

         string reason = StringFormat("OnDeinit open broker link still active; no server TP/SL close was observed before finalization; positionState=%s; floatingDelta=%.4f; this is not a realized broker close and remains not comparable to Paper FinalWorking", position_state, floating_delta);
         report_writer.AppendBrokerExitObservationLifecycleRecord(link,
                                                                  0,
                                                                  0,
                                                                  current_price,
                                                                  current_volume,
                                                                  0.0,
                                                                  TimeCurrent(),
                                                                  "OPEN_POSITION_AT_DEINIT_EXIT_NOT_OBSERVED",
                                                                  reason);
         report_writer.AppendBrokerOnlyTradeReconciliationRecord(link,
                                                                 "BROKER_ONLY_POSITION_OPEN_AT_DEINIT_WITHOUT_PAPER_FINAL",
                                                                 "BROKER_ONLY_OPEN_AT_DEINIT_NOT_LOCK_PARITY_COMPARABLE",
                                                                 reason + "; no Paper final TradeLifecycle record exists for this active broker link.");
      }

      ArrayResize(m_active_links, 0);
      ArrayResize(m_link_audit_history, 0);
      ArrayResize(m_paper_final_records, 0);
   }

   int EntryAttempts() { return m_entry_attempts; }
   int EntryAccepted() { return m_entry_accepted; }
   int EntryBlocked() { return m_entry_blocked; }
};

#endif // FALCON_BROKER_ENTRY_BRIDGE_MQH
