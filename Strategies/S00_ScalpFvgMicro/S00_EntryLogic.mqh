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

// Exit reasons. R1.1c adds TRAIL + BREAKEVEN for the runner-half
// post-trigger exit; STOP is still used for pre-trigger structural-stop
// exits (full trade out); TARGET / TIMEOUT cover both pre- and
// post-trigger exits.
enum ENUM_S00_TRADE_EXIT_REASON
{
   S00_EXIT_NONE      = 0,
   S00_EXIT_TARGET    = 1,
   S00_EXIT_STOP      = 2,   // pre-trigger structural stop (full trade)
   S00_EXIT_TIMEOUT   = 3,
   S00_EXIT_TRAIL     = 4,   // R1.1c: runner virtual stop above breakeven
   S00_EXIT_BREAKEVEN = 5    // R1.1c: runner virtual stop at breakeven
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
   // R1.1c: two-half trade model (Runner + Protection).
   //   Before trigger: both halves share the structural stop.
   //   At trigger: insurance half closes at trigger level; runner
   //               half's virtual stop is moved to breakeven.
   //   After trigger: runner trails on ATR; exits at TARGET / TRAIL /
   //                  BREAKEVEN / TIMEOUT.
   double                      r_price;                   // |entry - structural stop| in price (== "1R")
   double                      protect_trigger_level;     // entry + R (bull) / entry - R (bear)
   bool                        trigger_fired;             // has the trigger event run?
   datetime                    trigger_bar_time;          // bar.time at which trigger fired (used to skip runner eval on the trigger bar)
   // Insurance half
   datetime                    insurance_exit_time;
   double                      insurance_exit_price;
   double                      insurance_result_points;   // (exit - entry)/point for bull, signed
   // Runner half
   double                      runner_virtual_stop;       // current virtual stop for the runner; ratchets up (or down for bear)
   bool                        runner_open;               // true while the runner is still in the market
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

   // R1.1c: ATR handle for the runner trailing stop. Same indicator
   // params the detector uses (M5, S00_AtrPeriod), but kept locally
   // to avoid cross-class coupling. MQL5 caches indicator handles by
   // (symbol, timeframe, params) so this does not double the cost.
   int               m_runner_atr_handle;
   datetime          m_runner_atr_last_bar_time;
   double            m_runner_atr_last_value;

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
            // R1.1c columns - two-half trade model (runner + protection)
            //   ResultPoints + ExitReason continue to describe the
            //   RUNNER half (or the full trade if no trigger fired).
            //   Insurance fields are zero when no trigger fired.
            //   NetResultPoints is the size-weighted combination using
            //   S00_RunnerSplitPct.
            "RPoints,TriggerFired,RunnerExitPrice,"
            "InsuranceExitTime,InsuranceExitPrice,InsuranceResultPoints,"
            "NetResultPoints";
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
         case S00_EXIT_TARGET:    reason_label = "TARGET";    break;
         case S00_EXIT_STOP:      reason_label = "STOP";      break;
         case S00_EXIT_TIMEOUT:   reason_label = "TIMEOUT";   break;
         case S00_EXIT_TRAIL:     reason_label = "TRAIL";     break;
         case S00_EXIT_BREAKEVEN: reason_label = "BREAKEVEN"; break;
         default:                 reason_label = "NONE";      break;
      }
      // R1.1c: size-weighted net (in points). When the trigger fires:
      //   net = split * insurance_points + (1-split) * runner_points.
      // When the trigger does NOT fire, insurance mirrors the runner so
      // the formula still produces the correct single-leg result.
      const double split = S00_RunnerSplitPct / 100.0;
      const double net_points =
            split * t.insurance_result_points + (1.0 - split) * t.result_points;
      const double pt_for_r = (_Point > 0.0 ? _Point : 1.0);
      const double r_points = t.r_price / pt_for_r;
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
            // R1.1c columns
            DoubleToString(r_points,                       1) + "," +
            (t.trigger_fired ? "YES" : "NO")                  + "," +
            DoubleToString(t.exit_price,            _Digits)  + "," +
            FalconTimeToString(t.insurance_exit_time)         + "," +
            DoubleToString(t.insurance_exit_price,  _Digits)  + "," +
            DoubleToString(t.insurance_result_points,      1) + "," +
            DoubleToString(net_points,                     1);
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   //--------------------- R1.1c ATR for runner trailing ------
   bool EnsureRunnerAtrHandle()
   {
      if(m_runner_atr_handle == INVALID_HANDLE)
         m_runner_atr_handle = iATR(_Symbol, PERIOD_M5, S00_AtrPeriod);
      return (m_runner_atr_handle != INVALID_HANDLE);
   }

   // Returns ATR value (price units) from the CLOSED bar at shift=1.
   // start=1 in CopyBuffer = closed bar (start=0 would be the live bar).
   // Caches the value per bar to avoid redundant CopyBuffer calls in a
   // single OnTick pass.
   double ReadRunnerAtr(const datetime bar_time)
   {
      if(m_runner_atr_last_bar_time == bar_time)
         return m_runner_atr_last_value;
      if(!EnsureRunnerAtrHandle())
         return 0.0;
      double buf[];
      if(CopyBuffer(m_runner_atr_handle, 0, 1, 1, buf) <= 0)
         return 0.0;
      m_runner_atr_last_bar_time = bar_time;
      m_runner_atr_last_value    = buf[0];
      return buf[0];
   }

   //--------------------- trade close ------------------------
   // CloseFullTrade: both halves exit at the same price (pre-trigger
   // close - structural stop / target / timeout). insurance_* fields
   // mirror the runner's exit so the analyst sees one consistent row.
   void CloseFullTrade(const datetime exit_time,
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
      // Insurance half mirrors the runner since the trigger never fired.
      m_active_trade.insurance_exit_time     = exit_time;
      m_active_trade.insurance_exit_price    = exit_price;
      m_active_trade.insurance_result_points = m_active_trade.result_points;
      m_active_trade.runner_open             = false;
      AppendTradeRow(m_active_trade);
      m_active_trade.open = false;
   }

   // CloseRunnerOnly: runner half exits after the trigger already
   // closed the insurance half. The insurance_* fields are already
   // populated from the trigger event.
   void CloseRunnerOnly(const datetime exit_time,
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
      m_active_trade.runner_open   = false;
      AppendTradeRow(m_active_trade);
      m_active_trade.open = false;
   }

   //--------------------- R1.1c trigger event ----------------
   // Fire the unified +1R trigger: close insurance at trigger level,
   // move runner's virtual stop to breakeven. Runner exit eval is
   // deliberately skipped for the rest of THIS bar (spec §1.8 / §9 -
   // "runner exit evaluation starts from the bar AFTER the trigger").
   void FireTriggerEvent(const FalconCandleSnapshot &bar)
   {
      const double point = (_Point > 0.0 ? _Point : 1.0);
      const double trig_level = m_active_trade.protect_trigger_level;
      const double raw   = (m_active_trade.direction == S00_FVG_DIR_BULLISH
                             ? trig_level - m_active_trade.entry_price
                             : m_active_trade.entry_price - trig_level);
      m_active_trade.trigger_fired             = true;
      m_active_trade.trigger_bar_time          = bar.time;
      m_active_trade.insurance_exit_time       = bar.time;
      m_active_trade.insurance_exit_price      = trig_level;
      m_active_trade.insurance_result_points   = raw / point;
      m_active_trade.runner_virtual_stop       = m_active_trade.entry_price; // breakeven
   }

   // Recompute the runner virtual stop after the trigger has fired.
   // Stop = max(current, close - mult*ATR, breakeven) for BULLISH.
   // Stop = min(current, close + mult*ATR, breakeven) for BEARISH.
   // Ratchets monotonically toward the favorable direction; never
   // moves back toward (or beyond) the unfavorable direction.
   void UpdateRunnerVirtualStop(const FalconCandleSnapshot &bar)
   {
      if(!m_active_trade.trigger_fired) return;
      const double atr = ReadRunnerAtr(bar.time);
      if(atr <= 0.0) return;     // ATR not warm; leave stop where it is
      const double trail_offset = S00_RunnerTrailAtrMult * atr;
      if(m_active_trade.direction == S00_FVG_DIR_BULLISH)
      {
         const double trail_level = bar.close - trail_offset;
         double candidate = trail_level;
         if(m_active_trade.entry_price > candidate)        candidate = m_active_trade.entry_price; // floor at BE
         if(m_active_trade.runner_virtual_stop > candidate) candidate = m_active_trade.runner_virtual_stop;
         m_active_trade.runner_virtual_stop = candidate;
      }
      else if(m_active_trade.direction == S00_FVG_DIR_BEARISH)
      {
         const double trail_level = bar.close + trail_offset;
         double candidate = trail_level;
         if(m_active_trade.entry_price < candidate)        candidate = m_active_trade.entry_price; // ceiling at BE
         if(m_active_trade.runner_virtual_stop < candidate) candidate = m_active_trade.runner_virtual_stop;
         m_active_trade.runner_virtual_stop = candidate;
      }
   }

   //--------------------- R1.1c unified exit eval ------------
   // Single per-bar exit evaluator. Handles pre-trigger + post-trigger
   // phases in one place. Returns true if the trade was fully closed.
   //
   // Pre-trigger pessimistic ordering (spec §9):
   //   structural stop > trigger > target.
   //   - struct + trigger on same bar -> full loss (struct first).
   //   - trigger fires alone -> insurance closes, runner waits, runner
   //                            exit eval is SKIPPED for this bar.
   //   - target alone (no trigger) -> full trade exits at target.
   //
   // Post-trigger pessimistic ordering (spec §9.4):
   //   virtual stop > target.
   //   - first eligible bar is the one AFTER the trigger bar.
   //
   // Timeout uses elapsed_bars from entry; checked last after no exit.
   bool RunExitEvaluation(const FalconCandleSnapshot &bar)
   {
      if(!m_active_trade.open) return true;
      const bool bull = (m_active_trade.direction == S00_FVG_DIR_BULLISH);

      if(!m_active_trade.trigger_fired)
      {
         // ============ Pre-trigger ============
         const double struct_sl   = m_active_trade.stop_loss;
         const double tp          = m_active_trade.target;
         const double trig_level  = m_active_trade.protect_trigger_level;

         const bool hit_struct = (bull ? (bar.low  <= struct_sl)
                                       : (bar.high >= struct_sl));
         const bool hit_trig   = (bull ? (bar.high >= trig_level)
                                       : (bar.low  <= trig_level));
         const bool hit_target = (bull ? (bar.high >= tp)
                                       : (bar.low  <= tp));

         // Pessimistic: structural stop has priority over everything.
         if(hit_struct)
         {
            CloseFullTrade(bar.time, struct_sl, S00_EXIT_STOP);
            return true;
         }
         // Trigger has priority over target (runner exit eval deferred
         // to the next bar, so the target check is suppressed for the
         // runner on the trigger bar itself).
         if(hit_trig)
         {
            FireTriggerEvent(bar);
            return false;   // runner stays open
         }
         // Target alone before any trigger - full trade exits at target.
         if(hit_target)
         {
            CloseFullTrade(bar.time, tp, S00_EXIT_TARGET);
            return true;
         }
         // Timeout (counts from entry).
         if(m_active_trade.elapsed_bars >= S00_MaxTradeDurationBars)
         {
            CloseFullTrade(bar.time, bar.close, S00_EXIT_TIMEOUT);
            return true;
         }
         return false;
      }
      else
      {
         // ============ Post-trigger (runner phase) ============
         // Skip the trigger bar itself.
         if(bar.time == m_active_trade.trigger_bar_time) return false;

         // Refresh the trailing stop using this bar's close + ATR.
         UpdateRunnerVirtualStop(bar);

         const double vs = m_active_trade.runner_virtual_stop;
         const double tp = m_active_trade.target;

         const bool hit_vstop  = (bull ? (bar.low  <= vs)
                                       : (bar.high >= vs));
         const bool hit_target = (bull ? (bar.high >= tp)
                                       : (bar.low  <= tp));

         // Pessimistic: virtual stop has priority over target.
         if(hit_vstop)
         {
            // BREAKEVEN reason if the stop is still at entry; TRAIL
            // if it has ratcheted above (bull) / below (bear) entry.
            const double eps = (_Point > 0.0 ? _Point : 1e-8);
            const bool above_be = (bull ? (vs > m_active_trade.entry_price + eps)
                                         : (vs < m_active_trade.entry_price - eps));
            CloseRunnerOnly(bar.time, vs, above_be ? S00_EXIT_TRAIL
                                                   : S00_EXIT_BREAKEVEN);
            return true;
         }
         if(hit_target)
         {
            CloseRunnerOnly(bar.time, tp, S00_EXIT_TARGET);
            return true;
         }
         if(m_active_trade.elapsed_bars >= S00_MaxTradeDurationBars)
         {
            CloseRunnerOnly(bar.time, bar.close, S00_EXIT_TIMEOUT);
            return true;
         }
         return false;
      }
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
      // R1.1c
      m_runner_atr_handle          = INVALID_HANDLE;
      m_runner_atr_last_bar_time   = 0;
      m_runner_atr_last_value      = 0.0;
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
            // R1.1c: two-half trade model initialisation.
            //   R = |entry - structural stop| (price units).
            //   Trigger level = entry +/- ProtectTriggerR * R.
            //   Insurance / runner exits left empty until they fire.
            m_active_trade.r_price                 = MathAbs(plan.entry_price - plan.stop_loss);
            m_active_trade.protect_trigger_level   =
               (m_tracked[i].fvg.direction == S00_FVG_DIR_BULLISH
                ? plan.entry_price + S00_ProtectTriggerR * m_active_trade.r_price
                : plan.entry_price - S00_ProtectTriggerR * m_active_trade.r_price);
            m_active_trade.trigger_fired           = false;
            m_active_trade.trigger_bar_time        = 0;
            m_active_trade.insurance_exit_time     = 0;
            m_active_trade.insurance_exit_price    = 0.0;
            m_active_trade.insurance_result_points = 0.0;
            m_active_trade.runner_virtual_stop     = plan.stop_loss;  // pre-trigger == structural stop
            m_active_trade.runner_open             = true;

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
