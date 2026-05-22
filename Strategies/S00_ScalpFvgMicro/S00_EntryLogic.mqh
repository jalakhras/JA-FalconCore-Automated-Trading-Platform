//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh                  |
//| R1.1b - per-FVG state machine: revisit, confirm, entry-pending;  |
//| single open paper trade with SL / TP / timeout; trades CSV.      |
//|                                                                  |
//| State machine per active FVG (pulled from CS00FvgDetector):      |
//|   WAITING_REVISIT -> REVISITED -> ENTRY_PENDING -> DROPPED       |
//|                                                                  |
//|   - WAITING_REVISIT: gap is active, watching closed M5 bars for  |
//|     a bar whose range contains CE. Concurrent guards:            |
//|       * Invalidation: bar.close past the FAR edge -> DROPPED.    |
//|       * Expiry: S00_GapExpiry closed bars elapsed -> DROPPED.    |
//|   - REVISITED: CE has been touched. Watch the next closed bar    |
//|     for a confirmation candle (correct direction + body >=       |
//|     S00_MinConfirmBody points). Invalidation + expiry still      |
//|     apply.                                                       |
//|   - ENTRY_PENDING: confirmation found on bar T. On the NEXT      |
//|     closed bar T+1, build a plan via CS00TradePlanBuilder using  |
//|     T+1.open as entry; if the plan passes the 1:2 gate AND a     |
//|     swing target exists, open the paper trade; otherwise DROP.   |
//|   - DROPPED: terminal. Reason recorded in drop_reason.           |
//|                                                                  |
//| At most ONE open paper trade at a time (spec §8). While a trade  |
//| is open, FVGs sitting in REVISITED keep their state but won't be |
//| confirmed; FVGs that reach ENTRY_PENDING while busy are dropped. |
//|                                                                  |
//| ============ CRITICAL: ZERO LOOKAHEAD ============               |
//| Every candle read uses shift >= 1 (closed bar). The              |
//| confirmation check evaluates a CLOSED bar (shift=1); the entry   |
//| price is observed from the NEXT closed bar's open (still shift=1 |
//| on the subsequent OnTick call). No live forming bar is touched. |
//+------------------------------------------------------------------+
#ifndef FALCON_S00_ENTRY_LOGIC_MQH
#define FALCON_S00_ENTRY_LOGIC_MQH

enum ENUM_S00_TRACK_STATE
{
   S00_TRACK_WAITING_REVISIT = 0,
   S00_TRACK_REVISITED       = 1,
   S00_TRACK_ENTRY_PENDING   = 2,
   S00_TRACK_DROPPED         = 3
};

struct S00TrackedFvg
{
   S00FvgRecord          fvg;
   ENUM_S00_TRACK_STATE  state;
   string                drop_reason;            // "" | "INVALIDATED" | "EXPIRED" | "BUSY" | plan reject reason | "ENTERED"
   int                   bars_elapsed_since_formation;
   datetime              revisit_bar_time;
   // R1.1b-diag: entry-quality fields captured during the FVG's
   // pre-entry lifecycle. Read-only annotations - no influence on
   // entry / stop / target / invalidation decisions.
   double                confirm_body_points;        // set on REVISITED -> ENTRY_PENDING transition (bar1 = confirmation candle)
   double                confirm_range_points;       // ditto
   bool                  pre_confirm_extreme_set;    // sentinel for the running pre-confirmation extreme
   double                pre_confirm_extreme_price;  // BULLISH: lowest low seen pre-confirm; BEARISH: highest high
};

enum ENUM_S00_TRADE_EXIT_REASON
{
   S00_EXIT_NONE     = 0,
   S00_EXIT_TARGET   = 1,
   S00_EXIT_STOP     = 2,
   S00_EXIT_TIMEOUT  = 3
};

struct S00PaperTrade
{
   bool                        open;
   datetime                    entry_time;
   ENUM_S00_FVG_DIRECTION      direction;
   double                      entry_price;
   double                      stop_loss;
   double                      target;
   datetime                    fvg_formation_time;
   double                      fvg_size_points;
   double                      planned_rr_ratio;
   ENUM_S00_TRADE_EXIT_REASON  exit_reason;
   datetime                    exit_time;
   double                      exit_price;
   double                      result_points;
   int                         elapsed_bars;
   // R1.1b-diag: entry-quality + execution-quality fields. Read-only
   // annotations for the trades CSV. None of these influence the
   // SL / TP / timeout decision; they are pure observability.
   double                      confirm_body_points;       // |confirm.close - confirm.open| / point
   double                      confirm_range_points;      // (confirm.high - confirm.low) / point
   double                      entry_vs_ce_points;        // signed: (entry - ce) / point (positive => entry above CE for both directions)
   double                      entry_vs_gap_mid_fraction; // 0.0 at near edge, 1.0 at far edge of the FVG; may go <0 or >1 if entry lies outside the gap
   double                      penetration_depth_points;  // how far past the near edge the price reached pre-confirmation (>=0)
   int                         bars_from_fvg_to_entry;    // (entry_time - formation_time) measured in M5 bars
   double                      mfe_points;                // running max favorable excursion in points (>=0)
   double                      mae_points;                // running max adverse excursion in points (>=0)
};

class CS00EntryLogic
{
private:
   S00TrackedFvg     m_tracked[];
   int               m_tracked_count;
   int               m_detector_polled_count;
   datetime          m_last_bar_time;

   S00PaperTrade     m_active_trade;

   bool              m_trades_header_written;
   string            m_trades_file_name;

   //--------------------- detector poll ---------------------
   void PollDetector()
   {
      const int n = g_s00_fvg_detector.ActiveFvgCount();
      for(int i = m_detector_polled_count; i < n; i++)
      {
         const int new_size = m_tracked_count + 1;
         ArrayResize(m_tracked, new_size);
         m_tracked[m_tracked_count].fvg                          = g_s00_fvg_detector.GetActiveFvg(i);
         m_tracked[m_tracked_count].state                        = S00_TRACK_WAITING_REVISIT;
         m_tracked[m_tracked_count].drop_reason                  = "";
         m_tracked[m_tracked_count].bars_elapsed_since_formation = 0;
         m_tracked[m_tracked_count].revisit_bar_time             = 0;
         // R1.1b-diag init.
         m_tracked[m_tracked_count].confirm_body_points          = 0.0;
         m_tracked[m_tracked_count].confirm_range_points         = 0.0;
         m_tracked[m_tracked_count].pre_confirm_extreme_set      = false;
         m_tracked[m_tracked_count].pre_confirm_extreme_price    = 0.0;
         m_tracked_count = new_size;
      }
      m_detector_polled_count = n;
   }

   //--------------------- gap-state predicates --------------
   // Invalidation: close past the FAR edge of the gap.
   bool IsInvalidatedByBar(const S00TrackedFvg &tf, const FalconCandleSnapshot &bar) const
   {
      if(tf.fvg.direction == S00_FVG_DIR_BULLISH) return (bar.close < tf.fvg.gap_low);
      if(tf.fvg.direction == S00_FVG_DIR_BEARISH) return (bar.close > tf.fvg.gap_high);
      return false;
   }

   // Revisit: bar's high/low range contains CE.
   bool BarTouchesCE(const S00TrackedFvg &tf, const FalconCandleSnapshot &bar) const
   {
      return (bar.low <= tf.fvg.ce && bar.high >= tf.fvg.ce);
   }

   // Confirmation candle: correct direction + minimum body size +
   // minimum purity (R1.1b-purity).
   //
   // R1.1b-purity adds a second gate alongside the body-size gate:
   //   purity = |close - open| / (high - low)
   //   purity must be >= S00_MinConfirmPurity for the candle to qualify.
   //
   // Rationale: the R1.1b-diag April CSV showed that many failed
   // entries had large bodies that nonetheless lived inside larger
   // wicks - a candle that prints body=80pt but range=300pt is mostly
   // wick, indicating indecision rather than commitment. The purity
   // ratio filters those out without changing the body floor.
   //
   // No lookahead: `bar` here is the closed M5 bar at shift=1 passed
   // in by the caller (step 3d). The new computation reads only the
   // bar's already-closed open / close / high / low.
   bool IsConfirmationCandle(const ENUM_S00_FVG_DIRECTION dir,
                             const FalconCandleSnapshot &bar) const
   {
      const double point      = (_Point > 0.0 ? _Point : 1.0);
      const double body_abs   = MathAbs(bar.close - bar.open);
      const double body_points = body_abs / point;
      if(body_points < S00_MinConfirmBody) return false;

      // R1.1b-purity gate.
      const double range = bar.high - bar.low;
      if(range <= 0.0) return false;     // degenerate / dotted bar; reject
      const double purity = body_abs / range;
      if(purity < S00_MinConfirmPurity) return false;

      if(dir == S00_FVG_DIR_BULLISH) return (bar.close > bar.open);
      if(dir == S00_FVG_DIR_BEARISH) return (bar.open > bar.close);
      return false;
   }

   //--------------------- trades diagnostic CSV --------------
   void WriteTradesHeader()
   {
      if(m_trades_file_name == "")
         m_trades_file_name = FalconBuildReportFileName("S00_Trades_Diagnostics");
      int handle = FileOpen(m_trades_file_name, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE) return;
      const string header =
            "EntryTime,Direction,EntryPrice,StopLoss,Target,"
            "PlannedRR,FvgFormationTime,FvgSizePoints,"
            "ExitTime,ExitReason,ResultPoints,ElapsedBars,"
            // R1.1b-diag columns - entry quality + execution tracking
            "ConfirmBodyPoints,ConfirmRangePoints,EntryVsCE,"
            "EntryVsGapMid,PenetrationDepth,BarsFromFvgToEntry,"
            "MfePoints,MaePoints";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
      m_trades_header_written = true;
   }

   void AppendTradeRow(const S00PaperTrade &t)
   {
      if(!S00_DiagReport) return;
      if(!m_trades_header_written) WriteTradesHeader();
      if(m_trades_file_name == "") return;
      int handle = FileOpen(m_trades_file_name, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE) return;
      FileSeek(handle, 0, SEEK_END);
      const string dir_label =
            (t.direction == S00_FVG_DIR_BULLISH ? "BULLISH"
             : (t.direction == S00_FVG_DIR_BEARISH ? "BEARISH" : "NONE"));
      string reason_label;
      switch((int)t.exit_reason)
      {
         case S00_EXIT_TARGET:  reason_label = "TARGET";  break;
         case S00_EXIT_STOP:    reason_label = "STOP";    break;
         case S00_EXIT_TIMEOUT: reason_label = "TIMEOUT"; break;
         default:               reason_label = "NONE";    break;
      }
      const string row =
            FalconTimeToString(t.entry_time)               + "," +
            dir_label                                      + "," +
            DoubleToString(t.entry_price,        _Digits)  + "," +
            DoubleToString(t.stop_loss,          _Digits)  + "," +
            DoubleToString(t.target,             _Digits)  + "," +
            DoubleToString(t.planned_rr_ratio,   4)        + "," +
            FalconTimeToString(t.fvg_formation_time)       + "," +
            DoubleToString(t.fvg_size_points,    1)        + "," +
            FalconTimeToString(t.exit_time)                + "," +
            reason_label                                   + "," +
            DoubleToString(t.result_points,      1)        + "," +
            IntegerToString(t.elapsed_bars)                + "," +
            // R1.1b-diag columns
            DoubleToString(t.confirm_body_points,       1) + "," +
            DoubleToString(t.confirm_range_points,      1) + "," +
            DoubleToString(t.entry_vs_ce_points,        1) + "," +
            DoubleToString(t.entry_vs_gap_mid_fraction, 4) + "," +
            DoubleToString(t.penetration_depth_points,  1) + "," +
            IntegerToString(t.bars_from_fvg_to_entry)      + "," +
            DoubleToString(t.mfe_points,                1) + "," +
            DoubleToString(t.mae_points,                1);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   //--------------------- trade close ------------------------
   void CloseActiveTrade()
   {
      const double point = (_Point > 0.0 ? _Point : 1.0);
      const double raw   = (m_active_trade.direction == S00_FVG_DIR_BULLISH
                             ? m_active_trade.exit_price - m_active_trade.entry_price
                             : m_active_trade.entry_price - m_active_trade.exit_price);
      m_active_trade.result_points = raw / point;
      AppendTradeRow(m_active_trade);
      m_active_trade.open = false;
   }

   // R1.1b-diag: update running MFE / MAE on the active trade against
   // a closed bar's high / low. Pure observability - never gates the
   // SL / TP / timeout decision.
   void UpdateMfeMaeOnBar(const FalconCandleSnapshot &bar)
   {
      if(!m_active_trade.open) return;
      const double point = (_Point > 0.0 ? _Point : 1.0);
      double favorable = 0.0;
      double adverse   = 0.0;
      if(m_active_trade.direction == S00_FVG_DIR_BULLISH)
      {
         favorable = (bar.high - m_active_trade.entry_price) / point;
         adverse   = (m_active_trade.entry_price - bar.low)  / point;
      }
      else if(m_active_trade.direction == S00_FVG_DIR_BEARISH)
      {
         favorable = (m_active_trade.entry_price - bar.low)  / point;
         adverse   = (bar.high - m_active_trade.entry_price) / point;
      }
      if(favorable < 0.0) favorable = 0.0;
      if(adverse   < 0.0) adverse   = 0.0;
      if(favorable > m_active_trade.mfe_points) m_active_trade.mfe_points = favorable;
      if(adverse   > m_active_trade.mae_points) m_active_trade.mae_points = adverse;
   }

   // SL / TP / timeout check for an open trade against bar1.
   void UpdateOpenTradeOnBar(const FalconCandleSnapshot &bar)
   {
      // R1.1b-diag: refresh MFE / MAE before checking exits. The
      // bar's high / low fully define this bar's excursion regardless
      // of where SL / TP would land, so observability stays accurate
      // even for bars that trigger an exit.
      UpdateMfeMaeOnBar(bar);

      m_active_trade.elapsed_bars++;
      const double sl = m_active_trade.stop_loss;
      const double tp = m_active_trade.target;
      bool hit_stop   = false;
      bool hit_target = false;
      if(m_active_trade.direction == S00_FVG_DIR_BULLISH)
      {
         hit_stop   = (bar.low  <= sl);
         hit_target = (bar.high >= tp);
      }
      else
      {
         hit_stop   = (bar.high >= sl);
         hit_target = (bar.low  <= tp);
      }
      // Conservative tie-break: assume SL fills first when both are
      // reachable inside the same bar. (We cannot read intra-bar
      // order without a tick-level read, and "live ticks" would be a
      // lookahead surface.)
      if(hit_stop)
      {
         m_active_trade.exit_reason = S00_EXIT_STOP;
         m_active_trade.exit_time   = bar.time;
         m_active_trade.exit_price  = sl;
         CloseActiveTrade();
         return;
      }
      if(hit_target)
      {
         m_active_trade.exit_reason = S00_EXIT_TARGET;
         m_active_trade.exit_time   = bar.time;
         m_active_trade.exit_price  = tp;
         CloseActiveTrade();
         return;
      }
      if(m_active_trade.elapsed_bars >= S00_MaxTradeBars)
      {
         m_active_trade.exit_reason = S00_EXIT_TIMEOUT;
         m_active_trade.exit_time   = bar.time;
         m_active_trade.exit_price  = bar.close;
         CloseActiveTrade();
      }
   }

public:
   CS00EntryLogic()
   {
      m_tracked_count          = 0;
      ArrayResize(m_tracked, 0);
      m_detector_polled_count  = 0;
      m_last_bar_time          = 0;
      m_active_trade.open      = false;
      m_trades_header_written  = false;
      m_trades_file_name       = "";
   }

   //----------------------------------------------------------------
   // R1.1b entry point. Called from OnTick after the detector hook.
   //
   // Gates:
   //   - Enable_S00_FvgScalp == false  -> pure no-op.
   //   - Once per new closed M5 bar    -> dedupe via m_last_bar_time.
   //
   // PAPER ISOLATION (spec §6): this method NEVER calls into the
   // legacy g_report_writer / g_broker_entry_bridge / g_shadow_executor
   // pipeline. S00's trades are kept in m_active_trade and (optionally)
   // written to S00_Trades_Diagnostics.csv only. The legacy FixedLot
   // April numbers therefore remain locked.
   //----------------------------------------------------------------
   void EvaluateOnNewBar(CFalconMarketContext &market_context)
   {
      if(!Enable_S00_FvgScalp) return;

      FalconCandleSnapshot bar1;
      if(!market_context.GetCandleSnapshot(PERIOD_M5, 1, bar1)) return;
      if(bar1.time == m_last_bar_time) return;
      m_last_bar_time = bar1.time;

      // 1. Pull any new ACTIVE FVGs from the detector (R1.1a output).
      PollDetector();

      // 2. Update the open paper trade against this closed bar.
      if(m_active_trade.open)
         UpdateOpenTradeOnBar(bar1);

      // 3. Advance each tracked FVG.
      for(int i = 0; i < m_tracked_count; i++)
      {
         if(m_tracked[i].state == S00_TRACK_DROPPED) continue;

         m_tracked[i].bars_elapsed_since_formation++;

         // 3a. Expiry (independent of state).
         if(m_tracked[i].bars_elapsed_since_formation > S00_GapExpiry)
         {
            m_tracked[i].state       = S00_TRACK_DROPPED;
            m_tracked[i].drop_reason = "EXPIRED";
            continue;
         }

         // 3b. Invalidation (only meaningful pre-confirmation).
         if(m_tracked[i].state == S00_TRACK_WAITING_REVISIT
            || m_tracked[i].state == S00_TRACK_REVISITED)
         {
            if(IsInvalidatedByBar(m_tracked[i], bar1))
            {
               m_tracked[i].state       = S00_TRACK_DROPPED;
               m_tracked[i].drop_reason = "INVALIDATED";
               continue;
            }
         }

         // 3c. Revisit transition.
         if(m_tracked[i].state == S00_TRACK_WAITING_REVISIT)
         {
            if(BarTouchesCE(m_tracked[i], bar1))
            {
               m_tracked[i].state            = S00_TRACK_REVISITED;
               m_tracked[i].revisit_bar_time = bar1.time;
            }
            continue;
         }

         // 3d. Confirmation transition (REVISITED -> ENTRY_PENDING).
         if(m_tracked[i].state == S00_TRACK_REVISITED)
         {
            // One trade at a time. If busy, keep the FVG in REVISITED;
            // a later bar may still confirm if invalidation / expiry
            // don't kill it first.
            if(m_active_trade.open) continue;

            if(IsConfirmationCandle(m_tracked[i].fvg.direction, bar1))
            {
               m_tracked[i].state = S00_TRACK_ENTRY_PENDING;
               // R1.1b-diag: snapshot the confirmation candle's body
               // + range now (bar1 IS the confirmation candle at this
               // point). Read-only - logic above used the candle as
               // a gate but did not consume these values.
               const double pt = (_Point > 0.0 ? _Point : 1.0);
               m_tracked[i].confirm_body_points  = MathAbs(bar1.close - bar1.open) / pt;
               m_tracked[i].confirm_range_points = (bar1.high - bar1.low) / pt;
            }
            continue;
         }

         // 3e. Entry on the NEXT bar (bar1 here = T+1 when
         //     confirmation was on T). The plan is built using
         //     bar1.open as entry, then SL / TP are checked against
         //     bar1's high / low / close for same-bar fills.
         if(m_tracked[i].state == S00_TRACK_ENTRY_PENDING)
         {
            if(m_active_trade.open)
            {
               m_tracked[i].state       = S00_TRACK_DROPPED;
               m_tracked[i].drop_reason = "BUSY";
               continue;
            }

            S00TradePlan plan;
            if(!CS00TradePlanBuilder::Build(m_tracked[i].fvg,
                                            bar1.open,
                                            market_context,
                                            plan))
            {
               m_tracked[i].state       = S00_TRACK_DROPPED;
               m_tracked[i].drop_reason = plan.reject_reason;
               continue;
            }

            // Open the paper trade.
            m_active_trade.open                = true;
            m_active_trade.entry_time          = bar1.time;
            m_active_trade.direction           = m_tracked[i].fvg.direction;
            m_active_trade.entry_price         = plan.entry_price;
            m_active_trade.stop_loss           = plan.stop_loss;
            m_active_trade.target              = plan.target;
            m_active_trade.fvg_formation_time  = m_tracked[i].fvg.formation_time;
            m_active_trade.fvg_size_points     = m_tracked[i].fvg.gap_size_points;
            m_active_trade.planned_rr_ratio    = plan.target_to_stop_ratio;
            m_active_trade.exit_reason         = S00_EXIT_NONE;
            m_active_trade.exit_time           = 0;
            m_active_trade.exit_price          = 0.0;
            m_active_trade.result_points       = 0.0;
            m_active_trade.elapsed_bars        = 0;

            // R1.1b-diag: capture the entry-quality + execution
            // tracking fields. All derived from already-closed-bar
            // data + the FVG record + the confirmation snapshot taken
            // in step 3d. No new lookahead surface.
            const double dpt = (_Point > 0.0 ? _Point : 1.0);
            const double gap_range_price = m_tracked[i].fvg.gap_high - m_tracked[i].fvg.gap_low;
            m_active_trade.confirm_body_points  = m_tracked[i].confirm_body_points;
            m_active_trade.confirm_range_points = m_tracked[i].confirm_range_points;
            m_active_trade.entry_vs_ce_points   = (plan.entry_price - m_tracked[i].fvg.ce) / dpt;
            if(m_tracked[i].fvg.direction == S00_FVG_DIR_BULLISH)
               m_active_trade.entry_vs_gap_mid_fraction = (gap_range_price > 0.0
                                                          ? (m_tracked[i].fvg.gap_high - plan.entry_price) / gap_range_price
                                                          : 0.0);
            else
               m_active_trade.entry_vs_gap_mid_fraction = (gap_range_price > 0.0
                                                          ? (plan.entry_price - m_tracked[i].fvg.gap_low) / gap_range_price
                                                          : 0.0);
            // Penetration depth: how far past the NEAR edge the
            // pre-confirmation extreme reached. >=0; can exceed the
            // gap size if a wick poked past the far edge before the
            // confirmation candle (but no CLOSE past the far edge -
            // that would have triggered invalidation upstream).
            double penetration = 0.0;
            if(m_tracked[i].pre_confirm_extreme_set)
            {
               if(m_tracked[i].fvg.direction == S00_FVG_DIR_BULLISH)
                  penetration = (m_tracked[i].fvg.gap_high - m_tracked[i].pre_confirm_extreme_price) / dpt;
               else
                  penetration = (m_tracked[i].pre_confirm_extreme_price - m_tracked[i].fvg.gap_low) / dpt;
            }
            m_active_trade.penetration_depth_points = (penetration > 0.0 ? penetration : 0.0);
            m_active_trade.bars_from_fvg_to_entry   = (int)((m_active_trade.entry_time - m_tracked[i].fvg.formation_time) / 300);
            m_active_trade.mfe_points = 0.0;
            m_active_trade.mae_points = 0.0;

            // FVG consumed.
            m_tracked[i].state       = S00_TRACK_DROPPED;
            m_tracked[i].drop_reason = "ENTERED";

            // R1.1b-diag: refresh MFE / MAE on the entry bar itself
            // before the same-bar SL / TP check. The bar's high / low
            // represent the trade's first-bar excursion regardless
            // of whether SL / TP fills inside the bar.
            UpdateMfeMaeOnBar(bar1);

            // Same-bar fill check on the entry bar (bar1 = T+1).
            // elapsed_bars stays 0 here; UpdateOpenTradeOnBar would
            // increment it. We DO want this same-bar check (the
            // bar's high / low has already happened), but the
            // "elapsed" count should not advance for the entry bar
            // itself - so we compute the check inline.
            const double sl = m_active_trade.stop_loss;
            const double tp = m_active_trade.target;
            bool hit_stop   = false;
            bool hit_target = false;
            if(m_active_trade.direction == S00_FVG_DIR_BULLISH)
            {
               hit_stop   = (bar1.low  <= sl);
               hit_target = (bar1.high >= tp);
            }
            else
            {
               hit_stop   = (bar1.high >= sl);
               hit_target = (bar1.low  <= tp);
            }
            if(hit_stop)
            {
               m_active_trade.exit_reason = S00_EXIT_STOP;
               m_active_trade.exit_time   = bar1.time;
               m_active_trade.exit_price  = sl;
               CloseActiveTrade();
            }
            else if(hit_target)
            {
               m_active_trade.exit_reason = S00_EXIT_TARGET;
               m_active_trade.exit_time   = bar1.time;
               m_active_trade.exit_price  = tp;
               CloseActiveTrade();
            }
         }

         // R1.1b-diag: maintain the running pre-confirmation extreme
         // for the FVG (BULLISH: lowest low; BEARISH: highest high).
         // Runs AFTER the state transitions so the confirmation bar
         // itself (which moves state -> ENTRY_PENDING in 3d) and the
         // entry bar (which moves state -> DROPPED/ENTERED in 3e)
         // are not counted in "pre-confirmation" excursion.
         if(m_tracked[i].state == S00_TRACK_WAITING_REVISIT
            || m_tracked[i].state == S00_TRACK_REVISITED)
         {
            if(!m_tracked[i].pre_confirm_extreme_set)
            {
               m_tracked[i].pre_confirm_extreme_price =
                  (m_tracked[i].fvg.direction == S00_FVG_DIR_BULLISH
                   ? bar1.low : bar1.high);
               m_tracked[i].pre_confirm_extreme_set = true;
            }
            else if(m_tracked[i].fvg.direction == S00_FVG_DIR_BULLISH)
            {
               if(bar1.low < m_tracked[i].pre_confirm_extreme_price)
                  m_tracked[i].pre_confirm_extreme_price = bar1.low;
            }
            else
            {
               if(bar1.high > m_tracked[i].pre_confirm_extreme_price)
                  m_tracked[i].pre_confirm_extreme_price = bar1.high;
            }
         }
      }
   }
};

// R1.1b: file-scope instance. Single call site is the new OnTick
// hook below the detector hook. The class self-gates on
// Enable_S00_FvgScalp - paper-isolated, never touches the legacy
// Risk / Reporting / Execution pipeline.
CS00EntryLogic g_s00_entry_logic;

#endif // FALCON_S00_ENTRY_LOGIC_MQH
