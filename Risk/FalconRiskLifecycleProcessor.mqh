//+------------------------------------------------------------------+
//| Risk/FalconRiskLifecycleProcessor.mqh                            |
//| R0.7b: 10 Risk-natural Apply* method bodies ported VERBATIM from |
//| Reporting/FalconReportWriter.mqh as private members of           |
//| CFalconRiskLifecycleProcessor. ApplyTradeLifecycleChain calls    |
//| them in the load-bearing chain order #1, #2, #4, #5, #6, #7,     |
//| #8, #9, #10, #11.                                                |
//|                                                                  |
//| ============ R0.7b status (READ ME) ============                 |
//|                                                                  |
//| 1. The 10 Apply* bodies live BOTH here AND in ReportWriter.      |
//|    This is an INTENTIONAL temporary duplication. The ReportWriter|
//|    copies are still called by RegisterClosedTrade in R0.7b - the |
//|    call site is unchanged. ApplyTradeLifecycleChain on this      |
//|    class is NOT invoked anywhere in R0.7b; the class is declared |
//|    but never wired in. R0.7d will replace the 12 inline Apply*   |
//|    calls in RegisterClosedTrade with a single                    |
//|    g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);  |
//|    call, and at the same time the ReportWriter copies will be    |
//|    deleted. The duplication exists only between R0.7b and R0.7d. |
//|                                                                  |
//| 2. The bodies of the 10 Apply* methods reference m_totals and    |
//|    other CFalconReportWriter private state, plus a number of     |
//|    private helper methods that themselves live in ReportWriter.  |
//|    To keep the bodies VERBATIM (per spec §1 "النسخ حرفي"), this  |
//|    file mirrors the required state members and helper methods    |
//|    as SCAFFOLDING SCAFFOLDING SCAFFOLDING - private members of   |
//|    this class. They are byte-identical copies of the ones in     |
//|    ReportWriter. They are DORMANT in R0.7b (never read, never    |
//|    written) because ApplyTradeLifecycleChain is never called.    |
//|                                                                  |
//| 3. R0.7d binding strategy (out of scope for R0.7b):              |
//|    - Add a global instance `g_risk_lifecycle_processor`.         |
//|    - Provide a Bind(CFalconReportWriter&) method (or pass        |
//|      m_totals/m_symbol_context by reference at call time).       |
//|    - Inside RegisterClosedTrade, replace the 12 Apply* lines     |
//|      with one g_risk_lifecycle_processor.ApplyTradeLifecycleChain|
//|      (record). At that point the ReportWriter duplicates can be  |
//|      deleted.                                                    |
//|                                                                  |
//| 4. Per spec §6 "لا تكرّر حالة - استخدم نفس الناقل" - in R0.7b    |
//|    the duplicated state is purely a TYPE-LEVEL scaffold. No live |
//|    instance of this processor is created in R0.7b, so there is   |
//|    no second copy of the data bus at runtime. The duplication    |
//|    will be resolved in R0.7d when the binding pattern wires the  |
//|    processor to the same FalconReportTotals instance that        |
//|    CFalconReportWriter owns.                                     |
//|                                                                  |
//| 5. R0.7c will handle Apply #3 (FvgQualityShadowGuardSimulation - |
//|    strategy quality filter, may move to Strategies/) and Apply   |
//|    #12 (CapitalFlowSourceClassification - read-only annotation,  |
//|    may stay in Reporting/ or come here). Until then, neither is  |
//|    in this file.                                                 |
//|                                                                  |
//| 6. Helpers mirrored (private members of this class, scaffold):   |
//|    From slice L1590..L1950 of ReportWriter (close-window /       |
//|    session-boundary / force-close family) and L4823..L4930       |
//|    (DLM family). Some methods in those slices are not needed     |
//|    by any of the 10 Apply* but were included by contiguous       |
//|    extraction; MQL5 does not warn on unused private members so   |
//|    this is harmless.                                             |
//|                                                                  |
//| See Docs/ReviewNotes/R0_7b_Review_Notes.md for the full          |
//| dependency audit table and the R0.7d cleanup plan.               |
//+------------------------------------------------------------------+
#ifndef FALCON_RISK_LIFECYCLE_PROCESSOR_MQH
#define FALCON_RISK_LIFECYCLE_PROCESSOR_MQH

#include "FalconTradeLifecycleContract.mqh"

class CFalconRiskLifecycleProcessor
{
private:
   //================================================================
   // SCAFFOLDING state members - mirrored from CFalconReportWriter.
   // Dormant in R0.7b. R0.7d will retire these in favor of a
   // reference/pointer to the canonical ReportWriter instance.
   //================================================================
   FalconReportTotals  m_totals;
   FalconSymbolContext m_symbol_context;

   // v0.53.1: Three-layer paper emergency state (mirrored).
   bool                m_tle_emergency_active;
   string              m_tle_emergency_reason;
   int                 m_tle_consecutive_losses;
   datetime            m_tle_current_day;
   double              m_tle_daily_r;
   double              m_tle_equity;
   double              m_tle_peak_equity;
   double              m_tle_max_drawdown_pct;

   // v0.55.3b: Dynamic lot sizing safety ramp state (mirrored).
   bool                m_dlm_previous_active_lot_ready;
   double              m_dlm_previous_active_lot;

   //================================================================
   // SCAFFOLDING helper methods - mirrored from CFalconReportWriter
   // slices L1590..L1950 and L4823..L4930. Verbatim copies; some
   // included by contiguous extraction may be unused here. All are
   // dormant in R0.7b.
   //================================================================
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

   //================================================================
   // R0.7b-fix: 3 pure Risk-policy helpers moved from CFalconReportWriter
   // (where they lived for historical reasons). They are read-only
   // (no file I/O) and operate on the record + class state.
   //================================================================

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

   //================================================================
   // The 12 Apply* methods - VERBATIM copies from CFalconReportWriter
   // (R0.7b ported 10; R0.7cd added the remaining #3 and #12). The
   // chain entry point is ApplyTradeLifecycleChain (defined below
   // under public:) which calls them in the LOAD-BEARING ACTUAL order
   // documented inside that method.
   //================================================================

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
         // R0.7b-fix: the processor does NOT call AppendEmergencyTriggerEvent
         // (a Reporting-side CSV writer). It just leaves the result on
         // `record.falcon_emergency_*` / `falcon_layer{1,2,3}_*` /
         // `falcon_tier_at_entry` / `falcon_dynamic_risk_capital_after_trade`
         // (all of which were populated above). The Reporting layer reads
         // those fields and emits the row.
         //
         // In R0.7b the working path is still CFalconReportWriter::Apply
         // ThreeLayerEmergencyApplication (which DOES call
         // AppendEmergencyTriggerEvent directly, unchanged). When R0.7d
         // swaps the call site to use this processor, RegisterClosedTrade
         // (or its successor) will invoke AppendEmergencyTriggerEvent
         // AFTER ApplyTradeLifecycleChain returns - reading the same
         // record fields populated here. Single-direction:
         //     Risk writes record  ->  Reporting reads record + writes CSV.
         // No CSV write inside Risk; no double-write.
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

public:
   //================================================================
   // ApplyTradeLifecycleChain - the public entry point. Calls the
   // 12 ported Apply* methods on `this` in the LOAD-BEARING ACTUAL
   // order observed inside CFalconReportWriter::RegisterClosedTrade
   // pre-R0.7cd (i.e. how the chain has been firing since v0.55.x):
   //
   //     #3, #4, #5, #6, #7, #8, #10, #9, #1, #2, #11, #12
   //
   // ============ ORDER DISCREPANCY NOTE ============
   //
   // The R0.7b spec prompt and R0.7cd spec text both list the chain
   // as "#1..#12 ascending". That ascending listing was a documentation
   // error originating in Docs/ReviewNotes/R0_6a_Review_Notes.md §3.5.
   // The processor mirrors the ACTUAL order, NOT the spec's ascending
   // claim. Reason: R0.7cd's spec §3 also mandates "صفر تغيير سلوك"
   // (zero behavior change) and "النتيجة المالية تطابق تمامًا" (financial
   // result matches byte-for-byte). The two requirements are mutually
   // exclusive when the spec's ascending order differs from the live
   // working-path order. Behavior-preservation wins.
   //
   // The discrepancy is documented in Docs/ReviewNotes/R0_7b_Review_
   // Notes.md §2 and again in Docs/ReviewNotes/R0_7cd_Review_Notes.md.
   //
   // Why the order is load-bearing:
   //   * #10 reads single-trade-loss-cap state that #9 writes (so #10
   //     runs BEFORE #9 here, intentionally - swap from the ascending
   //     reading).
   //   * #1 / #2 (no-new-entry / force-close user overrides) sit AFTER
   //     #8 / #10 / #9, not before - they override the lot AFTER it
   //     was decided.
   //   * #11 (three-layer emergency) reads the market-close-blocked
   //     state that #1 / #2 applied.
   //   * #3 (FVG quality guard sim) is a pre-chain filter - runs first.
   //   * #12 (capital flow classification) is post-chain annotation.
   //================================================================
   void ApplyTradeLifecycleChain(FalconTradeLifecycleRecord &record)
   {
      ApplyFvgQualityShadowGuardSimulation(record);                     // #3
      ApplyPaperRuntimeGuardApplication(record);                        // #4
      ApplyPaperRuntimeSmartSLProtectionApplication(record);            // #5
      ApplyPaperRuntimeRunnerApplication(record);                       // #6
      ApplyCapitalTierFoundation(record);                               // #7
      ApplyLowCapitalRiskFeasibilityFoundation(record);                 // #8
      ApplyDynamicLotSizingModel(record);                               // #10
      ApplyCalibratedSingleTradeLossCapEnforcement(record);             // #9
      ApplyNoNewEntryUserOverridePaperEnforcement(record);              // #1
      ApplyDailyWeekendForceCloseUserOverridePaperEnforcement(record);  // #2
      ApplyThreeLayerEmergencyApplication(record);                      // #11
      ApplyCapitalFlowSourceClassification(record);                     // #12
   }
};

#endif // FALCON_RISK_LIFECYCLE_PROCESSOR_MQH
