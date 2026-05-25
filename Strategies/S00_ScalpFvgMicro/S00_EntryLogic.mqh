//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh                  |
//| R1.1b - per-FVG state machine: revisit, confirm, entry-pending;  |
//| single open paper trade with SL / TP / timeout; trades CSV.      |
//|                                                                  |
//| R1.2b - the strategy is no longer strictly paper-isolated. At    |
//| trade open (step 3e), if all three gates pass (MQL_TESTER +      |
//| EnableRealExecution + S00_RealExecution), a single               |
//| TryOpenFromShadowRecord call is made via g_broker_entry_bridge   |
//| using FC_MAGIC_FVG_MICRO. With any gate shut (default), the file |
//| stays paper-only verbatim - no bridge call, no broker order.     |
//| The close path is still paper-only in R1.2b (R1.2c will wire     |
//| real close + dual reporting).                                    |
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

// Exit reasons. R1.1c-fix: trade is a single unit (no split, no
// runner). STOP covers both structural and breakeven exits - the
// `breakeven_armed` flag on the trade record distinguishes them
// for analysis.
enum ENUM_S00_TRADE_EXIT_REASON
{
   S00_EXIT_NONE    = 0,
   S00_EXIT_TARGET  = 1,
   S00_EXIT_STOP    = 2,
   S00_EXIT_TIMEOUT = 3
};

struct S00PaperTrade
{
   bool                        open;
   datetime                    entry_time;
   ENUM_S00_FVG_DIRECTION      direction;
   double                      entry_price;
   double                      stop_loss;                 // mutated in place by breakeven arming (set to entry_price)
   // R1.2d breach-fix: stop_loss above is moved to entry_price when
   // breakeven arms (see L465 in RunExitEvaluation), which is correct
   // for the exit decision but wrong for the reported structural risk.
   // BuildLifecycleRecordFromS00Trade reads THIS field for record.structural_sl
   // so Apply #8's risk_points = |entry_price - structural_sl| reflects
   // the ORIGINAL stop distance, not the post-BE zero. Set once at trade
   // open from plan.stop_loss; never mutated thereafter.
   double                      original_structural_sl;
   double                      target;
   double                      lot_size;                  // R1.2a: computed at open, recorded in CSV. Paper-only - no broker order is sent.
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
   // R1.1c-fix: single-trade breakeven protection.
   //   When unrealised profit reaches S00_BreakevenTrigger points,
   //   stop_loss is moved to entry_price (paper-only - the trade is
   //   isolated, no broker SL ever existed). The trade then runs to
   //   target, hits the entry-level stop (flat result), or times out.
   //   No partial close, no trailing - one knob, one effect.
   bool                        breakeven_armed;         // has the BE protection fired?
   datetime                    breakeven_arm_bar_time;  // bar.time at which BE armed
   // R1.2b: real broker execution result. Populated at trade open
   // when all three gates pass (MQL_TESTER + EnableRealExecution +
   // S00_RealExecution); stays false / 0.0 when any gate is shut.
   //   real_entry_attempted = the bridge.TryOpenFromShadowRecord
   //                          call was issued at open.
   //   real_entry_accepted  = bridge returned true (OrderSend done).
   //   real_entry_price     = ASK (BUY) or BID (SELL) captured at
   //                          submission; matches the bridge's own
   //                          price read in the tester frame.
   //   real_entry_slippage  = real_entry_price - paper entry_price.
   bool                        real_entry_attempted;
   bool                        real_entry_accepted;
   double                      real_entry_price;
   // R1.2c: trade_id captured at real-entry attempt. Mirrors the
   // shadow_id format used by the bridge (R1.2d completion:
   // "S00_SCALP_FVG_<entry_time>_<sequence>"), so CloseActiveTrade
   // can hand it back to the bridge to look up the active broker
   // link and close the position by reverse deal. Empty string when
   // any of the three real-execution gates is shut.
   string                      trade_id;
   double                      real_entry_slippage;
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

   // R1.2d completion: monotonic per-instance counter appended to
   // shadow_id / trade_id so two S00 entries that share the same
   // bar.time (e.g. a same-bar exit immediately followed by a second
   // FVG's entry on the same OnTick) get distinct ids. Format remains
   // backward-compatible: "S00_SCALP_FVG_<unix>_<seq>". No bearing on
   // trading logic - this is an identifier-uniqueness fix only.
   int               m_trade_sequence;

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
            "MfePoints,MaePoints,"
            // R1.1c-fix - single new column: did the BE protection arm?
            //   StopLoss in the row above reflects the structural stop
            //   the trade entered with. If BreakevenArmed = YES, the
            //   effective stop after arming was entry_price - look at
            //   ResultPoints to see whether the trade exited at flat
            //   (BE-stop hit) or ran to target.
            "BreakevenArmed,"
            // R1.2a - fixed-lot size captured at trade open. Paper
            // trades carry this for the eventual real-execution
            // ticket; no broker order is sent in R1.2a.
            "LotSize,"
            // R1.2b - real broker fill price + slippage. Populated
            // only when the three real-execution gates passed AND
            // the bridge accepted the order; empty otherwise. The
            // slippage column is the first hard signal of broker
            // cost (the R1.2b purpose: see first real numbers
            // before committing R1.2c to the dual-report).
            "RealEntryPrice,RealEntrySlippage";
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
            FalconTimeToString(t.entry_time)                  + "," +
            dir_label                                         + "," +
            DoubleToString(t.entry_price,           _Digits)  + "," +
            DoubleToString(t.stop_loss,             _Digits)  + "," +
            DoubleToString(t.target,                _Digits)  + "," +
            DoubleToString(t.planned_rr_ratio,      4)        + "," +
            FalconTimeToString(t.fvg_formation_time)          + "," +
            DoubleToString(t.fvg_size_points,       1)        + "," +
            FalconTimeToString(t.exit_time)                   + "," +
            reason_label                                      + "," +
            DoubleToString(t.result_points,         1)        + "," +
            IntegerToString(t.elapsed_bars)                   + "," +
            // R1.1b-diag columns
            DoubleToString(t.confirm_body_points,          1) + "," +
            DoubleToString(t.confirm_range_points,         1) + "," +
            DoubleToString(t.entry_vs_ce_points,           1) + "," +
            DoubleToString(t.entry_vs_gap_mid_fraction,    4) + "," +
            DoubleToString(t.penetration_depth_points,     1) + "," +
            IntegerToString(t.bars_from_fvg_to_entry)         + "," +
            DoubleToString(t.mfe_points,                   1) + "," +
            DoubleToString(t.mae_points,                   1) + "," +
            // R1.1c-fix column
            (t.breakeven_armed ? "YES" : "NO")                + "," +
            // R1.2a column
            DoubleToString(t.lot_size,                     2) + "," +
            // R1.2b columns - empty unless the bridge accepted
            (t.real_entry_accepted ? DoubleToString(t.real_entry_price, _Digits) : "") + "," +
            (t.real_entry_accepted ? DoubleToString(t.real_entry_slippage, 1)    : "");
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   // R1.2d: build a central FalconTradeLifecycleRecord from the S00
   // paper trade. Populates only the ~18 mandatory identity / timing /
   // price / size fields; everything else stays zero-initialised by
   // MQL5's automatic struct zeroing. P&L (profit/loss/net_usd, points
   // indices) are intentionally left at 0.0 - RegisterClosedTrade calls
   // FalconFinalizeTradeMetrics which derives them from direction /
   // entry_price / exit_price / lot_size. No manual P&L math here.
   //
   // stage = PAPER is descriptive only: the 12-step Apply chain in
   // FalconRiskLifecycleProcessor.mqh has zero behavioural branching
   // on `stage` (verified R1.2d). The field is consumed by
   // FalconStageToString for CSV output only.
   void BuildLifecycleRecordFromS00Trade(FalconTradeLifecycleRecord &record)
   {
      // -- identity --
      record.trade_id      = m_active_trade.trade_id;       // captured at real-entry attempt in R1.2c
      record.strategy_id   = "S00_SCALP_FVG";
      record.strategy_name = "S00 ScalpFvgMicro";
      record.engine_id     = "S00_SCALP_FVG";               // matches BrokerExecutionLifecycle engine_id

      // -- routing --
      record.direction = (m_active_trade.direction == S00_FVG_DIR_BULLISH
                            ? FALCON_DIRECTION_BUY
                            : FALCON_DIRECTION_SELL);
      record.stage   = FALCON_TRADE_STAGE_PAPER;
      record.outcome = FALCON_TRADE_OUTCOME_OPEN;           // FalconFinalizeTradeMetrics recomputes

      // -- timing --
      record.entry_time = m_active_trade.entry_time;
      record.exit_time  = m_active_trade.exit_time;

      // -- prices + size --
      record.entry_price   = m_active_trade.entry_price;
      record.exit_price    = m_active_trade.exit_price;
      record.lot_size      = m_active_trade.lot_size;
      // R1.2d breach-fix: read original_structural_sl (frozen at open),
      // NOT stop_loss (mutated to entry_price by BE arming). Without
      // this, a BE-stopped trade gets structural_sl == entry_price,
      // Apply #8 computes risk_points = 0, Apply #10 flags decision
      // INVALID, and m_totals.dynamic_lotsizing_invalid_trades fires
      // the invariant_breaches counter.
      record.structural_sl = m_active_trade.original_structural_sl;
      record.tp1           = m_active_trade.target;

      // Diagnostic-only: surface S00 exit reason in the central TradeLifecycle
      // CloseReason column (previously empty for every S00 row). The same
      // enum-to-string mapping AppendTradeRow uses on the S00 diagnostic CSV.
      // record.close_reason is consumed by FalconReportWriter for the CSV
      // column and by FalconIsSessionBoundaryNoNewEntryBlockedRecord which
      // only matches "SESSION_BOUNDARY_USER_NO_NEW_ENTRY_BLOCKED" — the
      // values written here cannot collide. No Apply* step branches on it.
      switch((int)m_active_trade.exit_reason)
      {
         case S00_EXIT_TARGET:  record.close_reason = "TARGET";  break;
         case S00_EXIT_STOP:    record.close_reason = "STOP";    break;
         case S00_EXIT_TIMEOUT: record.close_reason = "TIMEOUT"; break;
         default:               record.close_reason = "NONE";    break;
      }
   }

   //--------------------- trade close ------------------------
   // Single-leg close. Writes one CSV row, clears m_active_trade.open.
   void CloseActiveTrade(const datetime exit_time,
                         const double   exit_price,
                         const ENUM_S00_TRADE_EXIT_REASON reason)
   {
      const double point = (_Point > 0.0 ? _Point : 1.0);
      const double raw   = (m_active_trade.direction == S00_FVG_DIR_BULLISH
                             ? exit_price - m_active_trade.entry_price
                             : m_active_trade.entry_price - exit_price);
      m_active_trade.exit_reason   = reason;
      m_active_trade.exit_time     = exit_time;
      m_active_trade.exit_price    = exit_price;
      m_active_trade.result_points = raw / point;
      AppendTradeRow(m_active_trade);

      // R1.2c/d: real close execution + central TradeLifecycle
      // registration. Three gates - MQL_TESTER + EnableRealExecution +
      // S00_RealExecution - mirror the entry contract; ALL must pass.
      // With any gate shut, the close stays paper-only and the legacy
      // FixedLot April baseline (585.17 / 1104.89 / 157.49) is
      // untouched.
      //
      // Ordering inside the gate (R1.2d):
      //   1. RegisterClosedTrade FIRST - the Bridge's close hook below
      //      writes a BrokerExecutionLifecycle row; having the Paper
      //      TradeLifecycle row already registered lets Reconciliation
      //      find the Paper-vs-Broker match instead of flagging
      //      BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE.
      //   2. StorePaperFinalRecord MIDDLE (R1.2d completion). The
      //      reconciliation lookup keyed in OnTradeTransaction reads
      //      m_paper_final_records[]; the legacy path fills it inside
      //      TryManagedCloseFromLifecycleRecord, but the S00 close
      //      function only takes trade_id+exit_price+reason and never
      //      touches that array. Storing the full lifecycle_record here
      //      bridges the gap before the broker deal fires.
      //   3. TryManagedCloseFromS00Trade LAST. trade_id is non-empty
      //      only when a real entry was attempted; on paper-only trades
      //      the bridge call returns false from FindActiveLinkByTradeId
      //      and is a no-op.
      if(MQLInfoInteger(MQL_TESTER)
         && EnableRealExecution
         && S00_RealExecution)
      {
         FalconTradeLifecycleRecord lifecycle_record;
         BuildLifecycleRecordFromS00Trade(lifecycle_record);
         g_report_writer.RegisterClosedTrade(lifecycle_record);

         g_broker_entry_bridge.StorePaperFinalRecord(lifecycle_record);

         g_broker_entry_bridge.TryManagedCloseFromS00Trade(m_active_trade.trade_id,
                                                          exit_price,
                                                          reason,
                                                          g_report_writer);
      }

      m_active_trade.open = false;
   }

   //--------------------- R1.1c-fix exit evaluator -----------
   // Per-bar exit evaluator. Pessimistic short-circuit ordering:
   //
   //   1. Stop hit.    stop_loss starts at the structural stop and is
   //                   mutated in place to entry_price when breakeven
   //                   arms; the same check therefore handles both the
   //                   pre-arm structural stop AND the post-arm BE stop.
   //                   (breakeven_armed = YES on the CSV row tells the
   //                   analyst which form fired.)
   //                   Pessimistic same-bar rule: if a bar contains
   //                   BOTH the structural stop AND the trigger level,
   //                   the stop wins -> full loss, BE does NOT arm.
   //   2. Target hit.  Standard close at target.
   //   3. BE arming.   If !armed and bar's favorable extreme reaches
   //                   entry +/- S00_BreakevenTrigger * point, arm and
   //                   move stop_loss to entry_price. No exit on this
   //                   bar - the new BE stop takes effect on subsequent
   //                   bars only (the bar that arms is "given a pass",
   //                   matching spec: "بعدها: إن انعكس السعر، تُغلَق
   //                   عند نقطة الدخول" - "afterwards", not same-bar).
   //   4. Timeout.     elapsed_bars >= S00_MaxTradeDurationBars.
   //
   // Returns true if the trade was fully closed.
   bool RunExitEvaluation(const FalconCandleSnapshot &bar)
   {
      if(!m_active_trade.open) return true;
      const bool   bull  = (m_active_trade.direction == S00_FVG_DIR_BULLISH);
      const double point = (_Point > 0.0 ? _Point : 1.0);
      const double sl    = m_active_trade.stop_loss;       // structural pre-arm, entry post-arm
      const double tp    = m_active_trade.target;

      const bool hit_stop   = (bull ? (bar.low  <= sl) : (bar.high >= sl));
      const bool hit_target = (bull ? (bar.high >= tp) : (bar.low  <= tp));

      // 1. Stop wins on ties (pessimistic).
      if(hit_stop)
      {
         CloseActiveTrade(bar.time, sl, S00_EXIT_STOP);
         return true;
      }
      // 2. Target.
      if(hit_target)
      {
         CloseActiveTrade(bar.time, tp, S00_EXIT_TARGET);
         return true;
      }
      // 3. Arm BE protection if the bar's favorable excursion reaches
      //    the trigger threshold. No exit this bar; the new stop
      //    applies on subsequent bars only.
      if(!m_active_trade.breakeven_armed && S00_BreakevenTrigger > 0.0)
      {
         const double trig_offset = S00_BreakevenTrigger * point;
         const double trig_price  = (bull
            ? m_active_trade.entry_price + trig_offset
            : m_active_trade.entry_price - trig_offset);
         const bool hit_trigger = (bull ? (bar.high >= trig_price)
                                        : (bar.low  <= trig_price));
         if(hit_trigger)
         {
            m_active_trade.breakeven_armed        = true;
            m_active_trade.breakeven_arm_bar_time = bar.time;
            m_active_trade.stop_loss              = m_active_trade.entry_price;
         }
      }
      // 4. Timeout (counts from entry).
      if(m_active_trade.elapsed_bars >= S00_MaxTradeDurationBars)
      {
         CloseActiveTrade(bar.time, bar.close, S00_EXIT_TIMEOUT);
         return true;
      }
      return false;
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

   // R1.1c entry to the per-bar exit cycle: refresh observability,
   // bump elapsed_bars, then delegate to the unified evaluator.
   void UpdateOpenTradeOnBar(const FalconCandleSnapshot &bar)
   {
      // Observability first - the bar's range is fixed regardless
      // of what the exit eval does next.
      UpdateMfeMaeOnBar(bar);
      m_active_trade.elapsed_bars++;
      RunExitEvaluation(bar);
   }

public:
   CS00EntryLogic()
   {
      m_tracked_count              = 0;
      ArrayResize(m_tracked, 0);
      m_detector_polled_count      = 0;
      m_last_bar_time              = 0;
      m_active_trade.open          = false;
      m_trades_header_written      = false;
      m_trades_file_name           = "";
      m_trade_sequence             = 0;
   }

   //----------------------------------------------------------------
   // R1.1b entry point. Called from OnTick after the detector hook.
   //
   // Gates:
   //   - Enable_S00_FvgScalp == false  -> pure no-op.
   //   - Once per new closed M5 bar    -> dedupe via m_last_bar_time.
   //
   // PAPER ISOLATION (spec §6) - and where R1.2b breaks it: when ALL
   // three real-execution gates pass (MQL_TESTER + EnableRealExecution
   // + S00_RealExecution), step 3e issues a single
   // g_broker_entry_bridge.TryOpenFromShadowRecord(...) call and
   // captures the real fill price / slippage onto m_active_trade.
   // With ANY gate shut (the default), this method is paper-isolated
   // verbatim - no bridge call, no broker order - so the legacy
   // FixedLot April numbers stay locked at 585.17 / 1104.89 / 157.49.
   // The close path is still paper-only in R1.2b (R1.2c will wire
   // real close + dual paper-vs-real reporting).
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
            // R1.2d breach-fix: snapshot the structural SL BEFORE any
            // breakeven mutation can touch m_active_trade.stop_loss.
            // Read by BuildLifecycleRecordFromS00Trade only.
            m_active_trade.original_structural_sl = plan.stop_loss;
            m_active_trade.target              = plan.target;
            // R1.2a: fixed-lot sizing. Recorded for the CSV + reserved
            // for R1.2b's real-execution order ticket. Paper-only here;
            // no broker order is built or sent.
            m_active_trade.lot_size            = S00_LotSize;
            m_active_trade.fvg_formation_time  = m_tracked[i].fvg.formation_time;
            m_active_trade.fvg_size_points     = m_tracked[i].fvg.gap_size_points;
            m_active_trade.planned_rr_ratio    = plan.target_to_stop_ratio;
            m_active_trade.exit_reason         = S00_EXIT_NONE;
            m_active_trade.exit_time           = 0;
            m_active_trade.exit_price          = 0.0;
            m_active_trade.result_points       = 0.0;
            m_active_trade.elapsed_bars        = 0;
            // R1.1c-fix: single breakeven-protection field. The stop
            // starts at the structural stop and gets mutated to
            // entry_price by RunExitEvaluation when the +N-points
            // trigger fires; the flag below records which trades the
            // protection armed for (for analysis of the CSV).
            m_active_trade.breakeven_armed         = false;
            m_active_trade.breakeven_arm_bar_time  = 0;

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

            // R1.2b: real broker execution wiring. Three gates -
            // MQL_TESTER + EnableRealExecution + S00_RealExecution -
            // ALL must pass for an order to leave the strategy.
            //   Gates 1 + 2 are also enforced inside the bridge
            //   (TesterEntryAllowed); we check all three here so the
            //   call site itself documents the safety contract.
            // The bridge call sits BEFORE the same-bar SL/TP check
            // below: a same-bar fill still gets its real-entry data
            // into the CSV row written by CloseActiveTrade.
            // Magic number: FC_MAGIC_FVG_MICRO (the same magic used
            //   by the legacy FVG_MICRO_RETEST strategy). With
            //   S00_RealExecution = true the legacy strategy is
            //   forced dark by R1.2a's coexistence gate, so the magic
            //   is uniquely S00's during the run - no collision.
            // R1.2c will wire the real close + dual paper-vs-real
            //   report; R1.2b ships entry only.
            // MQL5 two-pass parse resolves g_broker_entry_bridge /
            //   g_report_writer (declared further down in main .mq5)
            //   inside this class method body, same pattern the
            //   detector uses for FalconBuildReportFileName.
            m_active_trade.real_entry_attempted = false;
            m_active_trade.real_entry_accepted  = false;
            m_active_trade.real_entry_price     = 0.0;
            m_active_trade.real_entry_slippage  = 0.0;
            m_active_trade.trade_id             = "";
            if(MQLInfoInteger(MQL_TESTER)
               && EnableRealExecution
               && S00_RealExecution)
            {
               // R1.2d completion: build the unique id ONCE per real
               // entry so shadow_id (bridge link key) and trade_id
               // (S00 close-path key) are identical strings. The
               // sequence suffix disambiguates two entries that share
               // the same bar.time within one OnTick frame.
               m_trade_sequence++;
               const string s00_unique_id = "S00_SCALP_FVG_"
                                          + IntegerToString((long)m_active_trade.entry_time)
                                          + "_"
                                          + IntegerToString(m_trade_sequence);
               FalconShadowTradeRecord s00_record;
               ZeroMemory(s00_record);
               s00_record.shadow_id     = s00_unique_id;
               s00_record.strategy_id   = "S00_SCALP_FVG";
               s00_record.strategy_name = "S00 Scalp FVG Micro";
               s00_record.engine_id     = "S00_SCALP_FVG";
               s00_record.direction     = (m_active_trade.direction == S00_FVG_DIR_BULLISH
                                            ? FALCON_DIRECTION_BUY : FALCON_DIRECTION_SELL);
               s00_record.status        = FALCON_SHADOW_RECORD_STAGED;
               s00_record.entry_time    = m_active_trade.entry_time;
               s00_record.lot_size      = m_active_trade.lot_size;
               s00_record.entry_price   = m_active_trade.entry_price;
               s00_record.structural_sl = m_active_trade.stop_loss;
               // S00 trades a single TP. Mirror it across tp1/tp2/tp3
               // so the bridge's plan validator (which reads all
               // three) sees a consistent target. Multi-leg / runner
               // is out of scope for R1.2b.
               s00_record.tp1           = m_active_trade.target;
               s00_record.tp2           = m_active_trade.target;
               s00_record.tp3           = m_active_trade.target;
               s00_record.is_closed     = false;

               // Capture ASK/BID NOW so the value matches what the
               // bridge reads a few statements later (same OnTick,
               // same tick frame). In the tester this is the
               // canonical fill price for a market deal.
               const double request_price = (s00_record.direction == FALCON_DIRECTION_BUY
                                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_BID));

               m_active_trade.real_entry_attempted = true;
               // R1.2c: capture trade_id at the same moment the bridge
               // call is issued. R1.2d completion: reuse the same
               // s00_unique_id built above so shadow_id (entry side)
               // and trade_id (close side) are guaranteed identical.
               m_active_trade.trade_id = s00_unique_id;
               const bool accepted = g_broker_entry_bridge.TryOpenFromShadowRecord(s00_record, g_report_writer);
               m_active_trade.real_entry_accepted = accepted;
               if(accepted && request_price > 0.0)
               {
                  m_active_trade.real_entry_price    = request_price;
                  m_active_trade.real_entry_slippage = request_price - m_active_trade.entry_price;
               }
            }

            // FVG consumed.
            m_tracked[i].state       = S00_TRACK_DROPPED;
            m_tracked[i].drop_reason = "ENTERED";

            // R1.1b-diag: refresh MFE / MAE on the entry bar itself
            // before the same-bar exit check. The bar's high / low
            // represent the trade's first-bar excursion regardless
            // of whether SL / TP / trigger fills inside the bar.
            UpdateMfeMaeOnBar(bar1);

            // R1.1c: same-bar fill check on the entry bar (bar1=T+1)
            // is delegated to the unified evaluator. elapsed_bars
            // intentionally stays at 0 here (UpdateOpenTradeOnBar
            // would increment it); the entry bar itself doesn't count
            // toward S00_MaxTradeDurationBars. The evaluator handles
            // the full pre-trigger ordering (struct stop > trigger >
            // target > timeout) and the pessimistic edge cases.
            RunExitEvaluation(bar1);
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
