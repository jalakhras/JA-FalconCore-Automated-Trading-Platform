//+------------------------------------------------------------------+
//| Strategies/S01_Harness/S01_EntryLogic.mqh                        |
//| R1.3a - S01 Harness: deterministic single-trade entry engine.    |
//|                                                                  |
//| Mirrors the S00 integration contract (R1.2b..R1.2d) without any  |
//| of S00's FVG detection. One open trade at a time. Deterministic  |
//| entry off the last CLOSED M5 candle (see S01_HarnessInputs.mqh). |
//|                                                                  |
//| REAL EXECUTION CONTRACT (identical safety triad to S00):         |
//|   Entry: g_broker_entry_bridge.TryOpenFromShadowRecord(...)      |
//|   Close: g_report_writer.RegisterClosedTrade(...) then           |
//|          g_broker_entry_bridge.TryManagedCloseFromLifecycleRecord|
//|          (...) - the generic legacy "golden template" close that |
//|          takes a full FalconTradeLifecycleRecord, stores it in   |
//|          m_paper_final_records[] (so Reconciliation links the    |
//|          Paper-vs-Broker pair) and fires the broker reverse deal.|
//|   NO OrderSend / PositionClose / PositionModify in this file.    |
//|   All three gates - MQL_TESTER + EnableRealExecution +           |
//|   S01_RealExecution - must pass or the strategy stays paper-only |
//|   and never touches g_report_writer / g_broker_entry_bridge.     |
//|                                                                  |
//| ZERO LOOKAHEAD: the only candle read is shift 1 (last closed M5).|
//| The entry bar itself is NOT exit-evaluated (entry = its close,   |
//| so its high/low already happened); exits start on the next bar.  |
//|                                                                  |
//| stage = PAPER is descriptive only (the 12-step Apply chain does  |
//| not branch on stage). structural_sl is never mutated here (no    |
//| breakeven), so it is always the original stop - the R1.2d        |
//| breach (structural_sl == entry_price) cannot occur in S01.       |
//+------------------------------------------------------------------+
#ifndef FALCON_S01_HARNESS_ENTRY_LOGIC_MQH
#define FALCON_S01_HARNESS_ENTRY_LOGIC_MQH

// Exit reasons. Phase 1a: structural stop or R-multiple target only.
// No timeout, no breakeven, no runner.
enum ENUM_S01_TRADE_EXIT_REASON
{
   S01_EXIT_NONE   = 0,
   S01_EXIT_TARGET = 1,
   S01_EXIT_STOP   = 2
};

struct S01HarnessTrade
{
   bool                        open;
   datetime                    entry_time;
   ENUM_FALCON_DIRECTION       direction;        // BUY / SELL (resolved from the signal candle)
   double                      entry_price;
   double                      stop_loss;        // structural stop; never mutated (no breakeven in phase 1a)
   double                      target;
   double                      lot_size;
   datetime                    exit_time;
   double                      exit_price;
   ENUM_S01_TRADE_EXIT_REASON  exit_reason;
   double                      result_points;
   // trade_id captured at the real-entry attempt; mirrors the bridge
   // shadow_id so the close path can find the active broker link.
   // Empty when any real-execution gate is shut.
   string                      trade_id;
   bool                        real_entry_attempted;
   bool                        real_entry_accepted;
};

class CS01HarnessEntryLogic
{
private:
   S01HarnessTrade   m_active_trade;
   datetime          m_last_bar_time;
   int               m_trade_sequence;

   //--------------------- central lifecycle record -----------
   // Build a FalconTradeLifecycleRecord from the harness trade.
   // Populates only the mandatory identity / routing / timing /
   // price / size fields; RegisterClosedTrade -> FalconFinalizeTradeMetrics
   // derives the P&L. stage = PAPER (descriptive only).
   void BuildLifecycleRecordFromS01Trade(FalconTradeLifecycleRecord &record)
   {
      record.trade_id      = m_active_trade.trade_id;
      record.strategy_id   = "S01_HARNESS";
      record.strategy_name = "S01 Harness";
      record.engine_id     = "S01_HARNESS";

      record.direction = m_active_trade.direction;          // already ENUM_FALCON_DIRECTION
      record.stage     = FALCON_TRADE_STAGE_PAPER;
      record.outcome   = FALCON_TRADE_OUTCOME_OPEN;          // FalconFinalizeTradeMetrics recomputes

      record.entry_time = m_active_trade.entry_time;
      record.exit_time  = m_active_trade.exit_time;

      record.entry_price   = m_active_trade.entry_price;
      record.exit_price    = m_active_trade.exit_price;
      record.lot_size      = m_active_trade.lot_size;
      record.structural_sl = m_active_trade.stop_loss;       // never mutated in S01 -> always the original stop
      record.tp1           = m_active_trade.target;

      switch((int)m_active_trade.exit_reason)
      {
         case S01_EXIT_TARGET: record.close_reason = "TARGET"; break;
         case S01_EXIT_STOP:   record.close_reason = "STOP";   break;
         default:              record.close_reason = "NONE";   break;
      }
   }

   //--------------------- trade close ------------------------
   // Single-leg close. Mirrors the S00 R1.2d ordering, but uses the
   // generic legacy close (full record) instead of the S00-specific
   // TryManagedCloseFromS00Trade - so S01 stays decoupled from S00.
   //   1. RegisterClosedTrade  -> central Paper TradeLifecycle row +
   //      Apply chain (this is what exercises the management engines).
   //   2. TryManagedCloseFromLifecycleRecord -> stores the paper final
   //      record (Reconciliation linkage) and fires the broker reverse
   //      deal. No-op if the position was already closed (e.g. by the
   //      Virtual Trailing Bridge or the server SL/TP envelope).
   void CloseActiveTrade(const datetime exit_time,
                         const double   exit_price,
                         const ENUM_S01_TRADE_EXIT_REASON reason)
   {
      const double point = (_Point > 0.0 ? _Point : 1.0);
      const double raw   = (m_active_trade.direction == FALCON_DIRECTION_BUY
                             ? exit_price - m_active_trade.entry_price
                             : m_active_trade.entry_price - exit_price);
      m_active_trade.exit_reason   = reason;
      m_active_trade.exit_time     = exit_time;
      m_active_trade.exit_price    = exit_price;
      m_active_trade.result_points = raw / point;

      if(MQLInfoInteger(MQL_TESTER)
         && EnableRealExecution
         && S01_RealExecution)
      {
         FalconTradeLifecycleRecord lifecycle_record;
         BuildLifecycleRecordFromS01Trade(lifecycle_record);
         g_report_writer.RegisterClosedTrade(lifecycle_record);
         g_broker_entry_bridge.TryManagedCloseFromLifecycleRecord(lifecycle_record, g_report_writer);
      }

      m_active_trade.open = false;
   }

   //--------------------- exit evaluation --------------------
   // Pessimistic structural-stop-vs-target check on a CLOSED bar.
   // Stop wins on ties. No breakeven, no timeout (phase 1a).
   void RunExitEvaluation(const FalconCandleSnapshot &bar)
   {
      if(!m_active_trade.open) return;
      const bool   bull = (m_active_trade.direction == FALCON_DIRECTION_BUY);
      const double sl   = m_active_trade.stop_loss;
      const double tp   = m_active_trade.target;

      const bool hit_stop   = (bull ? (bar.low  <= sl) : (bar.high >= sl));
      const bool hit_target = (bull ? (bar.high >= tp) : (bar.low  <= tp));

      if(hit_stop)
      {
         CloseActiveTrade(bar.time, sl, S01_EXIT_STOP);
         return;
      }
      if(hit_target)
      {
         CloseActiveTrade(bar.time, tp, S01_EXIT_TARGET);
         return;
      }
   }

   //--------------------- deterministic entry ----------------
   // Open one trade off the last closed M5 candle. The entry bar is
   // NOT exit-evaluated this tick (zero lookahead - its high/low
   // already formed before the close we enter at). Exits begin next bar.
   void OpenDeterministicTrade(const FalconCandleSnapshot &bar1)
   {
      if(bar1.close == bar1.open) return;   // doji -> no direction, skip

      const ENUM_FALCON_DIRECTION dir = (bar1.close > bar1.open
                                          ? FALCON_DIRECTION_BUY
                                          : FALCON_DIRECTION_SELL);
      const double point  = (_Point > 0.0 ? _Point : 1.0);
      const double buffer = S01_StopBuffer * point;
      const double entry  = bar1.close;

      double stop = 0.0;
      double target = 0.0;
      if(dir == FALCON_DIRECTION_BUY)
      {
         stop = bar1.low - buffer;
         const double risk = entry - stop;
         if(risk <= 0.0) return;
         target = entry + S01_TargetRMultiple * risk;
      }
      else
      {
         stop = bar1.high + buffer;
         const double risk = stop - entry;
         if(risk <= 0.0) return;
         target = entry - S01_TargetRMultiple * risk;
      }

      m_active_trade.open                 = true;
      m_active_trade.entry_time           = bar1.time;
      m_active_trade.direction            = dir;
      m_active_trade.entry_price          = entry;
      m_active_trade.stop_loss            = stop;
      m_active_trade.target               = target;
      m_active_trade.lot_size             = FixedLotSize;     // project-wide sizing knob
      m_active_trade.exit_reason          = S01_EXIT_NONE;
      m_active_trade.exit_time            = 0;
      m_active_trade.exit_price           = 0.0;
      m_active_trade.result_points        = 0.0;
      m_active_trade.trade_id             = "";
      m_active_trade.real_entry_attempted = false;
      m_active_trade.real_entry_accepted  = false;

      // Real broker entry. Three gates - MQL_TESTER + EnableRealExecution
      // + S01_RealExecution - all must pass. Magic is assigned by the
      // bridge (FC_MAGIC_FVG_MICRO); run the harness in isolation from
      // S00 / legacy so the shared magic does not collide.
      if(MQLInfoInteger(MQL_TESTER)
         && EnableRealExecution
         && S01_RealExecution)
      {
         m_trade_sequence++;
         const string s01_unique_id = "S01_HARNESS_"
                                    + IntegerToString((long)bar1.time)
                                    + "_"
                                    + IntegerToString(m_trade_sequence);
         FalconShadowTradeRecord s01_record;
         ZeroMemory(s01_record);
         s01_record.shadow_id     = s01_unique_id;
         s01_record.strategy_id   = "S01_HARNESS";
         s01_record.strategy_name = "S01 Harness";
         s01_record.engine_id     = "S01_HARNESS";
         s01_record.direction     = dir;
         s01_record.status        = FALCON_SHADOW_RECORD_STAGED;
         s01_record.entry_time    = bar1.time;
         s01_record.lot_size      = m_active_trade.lot_size;
         s01_record.entry_price   = entry;
         s01_record.structural_sl = stop;
         // Single TP mirrored across tp1/tp2/tp3 so the bridge's plan
         // validator (which reads all three) sees a consistent target.
         s01_record.tp1           = target;
         s01_record.tp2           = target;
         s01_record.tp3           = target;
         s01_record.is_closed     = false;

         m_active_trade.trade_id             = s01_unique_id;
         m_active_trade.real_entry_attempted = true;
         m_active_trade.real_entry_accepted  =
            g_broker_entry_bridge.TryOpenFromShadowRecord(s01_record, g_report_writer);
      }
   }

public:
   CS01HarnessEntryLogic()
   {
      m_active_trade.open = false;
      m_last_bar_time     = 0;
      m_trade_sequence    = 0;
   }

   //----------------------------------------------------------------
   // OnTick entry point. Self-gates on Enable_S01_Harness. Dedupes
   // per new closed M5 bar. Manage the open trade first (exits on
   // THIS closed bar), then open a fresh deterministic trade if flat.
   //----------------------------------------------------------------
   void EvaluateOnNewBar(CFalconMarketContext &market_context)
   {
      if(!Enable_S01_Harness) return;

      FalconCandleSnapshot bar1;
      if(!market_context.GetCandleSnapshot(PERIOD_M5, 1, bar1)) return;
      if(bar1.time == m_last_bar_time) return;
      m_last_bar_time = bar1.time;

      // 1. Manage the open trade against this closed bar.
      if(m_active_trade.open)
         RunExitEvaluation(bar1);

      // 2. If flat, open a fresh deterministic trade. The entry bar is
      //    intentionally not exit-evaluated this tick (see header).
      if(!m_active_trade.open)
         OpenDeterministicTrade(bar1);
   }
};

CS01HarnessEntryLogic g_s01_harness_entry_logic;

#endif // FALCON_S01_HARNESS_ENTRY_LOGIC_MQH
