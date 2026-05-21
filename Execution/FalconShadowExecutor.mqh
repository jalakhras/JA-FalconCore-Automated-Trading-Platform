//+------------------------------------------------------------------+
//| Execution/FalconShadowExecutor.mqh                               |
//| R0.4: CFalconShadowExecutor moved verbatim from main .mq5        |
//| (L4186-4433). Observation-only Shadow trade lifecycle; never     |
//| sends broker orders. No ReportWriter dependency.                 |
//+------------------------------------------------------------------+
#ifndef FALCON_SHADOW_EXECUTOR_MQH
#define FALCON_SHADOW_EXECUTOR_MQH

// ==================================================================
// Shadow Engine Framework Foundation - v0.13.1
// Shadow is observation-only. It can stage simulated records and convert
// them to lifecycle records, but it never sends broker orders.
// ==================================================================
class CFalconShadowExecutor
{
private:
   bool m_initialized;
   int  m_staged_records;
   int  m_closed_records;
   int  m_cancelled_records;

public:
   CFalconShadowExecutor()
   {
      m_initialized       = false;
      m_staged_records    = 0;
      m_closed_records    = 0;
      m_cancelled_records = 0;
   }

   bool Initialize()
   {
      m_initialized       = EnableShadowMode;
      m_staged_records    = 0;
      m_closed_records    = 0;
      m_cancelled_records = 0;

      if(m_initialized)
         CFalconLogger::Info("ShadowExecutor initialized. Mode=OBSERVE_ONLY | BrokerOrders=false");
      else
         CFalconLogger::Warn("ShadowExecutor is disabled by input EnableShadowMode=false. EA remains idle.");

      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   int StagedRecords()
   {
      return m_staged_records;
   }

   int ClosedRecords()
   {
      return m_closed_records;
   }

   int CancelledRecords()
   {
      return m_cancelled_records;
   }

   bool StageTradePlan(const FalconTradePlan &plan,
                       const FalconEvidencePack &evidence_pack,
                       FalconShadowTradeRecord &record)
   {
      ResetShadowRecord(record);

      if(!m_initialized)
      {
         CFalconLogger::Warn("StageTradePlan ignored because ShadowExecutor is not initialized.");
         return false;
      }

      record.shadow_id        = StringFormat("SHD_%s_%d_%d", plan.strategy_id, (int)TimeCurrent(), m_staged_records + 1);
      record.strategy_id      = plan.strategy_id;
      record.strategy_name    = plan.strategy_name;
      record.engine_id        = plan.engine_id;
      record.direction        = plan.direction;
      record.status           = FALCON_SHADOW_RECORD_STAGED;
      record.entry_time       = TimeCurrent();
      record.exit_time        = 0;
      record.lot_size         = plan.lot_size;
      record.entry_price      = plan.entry_price;
      record.structural_sl    = plan.structural_sl;
      record.tp1              = plan.tp1;
      record.tp2              = plan.tp2;
      record.tp3              = plan.tp3;
      record.simulated_exit_price = 0.0;
      record.simulated_outcome    = FALCON_TRADE_OUTCOME_OPEN;
      record.close_reason         = "STAGED_ONLY_NO_EXECUTION";
      record.evidence_summary     = evidence_pack.summary;
      record.fvg_size_points      = plan.fvg_size_points;
      record.fvg_spread_points    = plan.fvg_spread_points;
      record.fvg_retest_age_bars  = plan.fvg_retest_age_bars;
      record.fvg_setup_time = plan.fvg_setup_time;
      record.fvg_retest_watch_time = plan.fvg_retest_watch_time;
      record.fvg_age_bars_at_watch = plan.fvg_age_bars_at_watch;
      record.fvg_age_source = plan.fvg_age_source;
      record.fvg_retest_fresh_state = plan.fvg_retest_fresh_state;
      record.fvg_hold_quality_score = plan.fvg_hold_quality_score;
      record.fvg_hold_quality_bucket = plan.fvg_hold_quality_bucket;
      record.quality_filters_passed = plan.quality_filters_passed;
      record.quality_profile_balanced_passed = plan.quality_profile_balanced_passed;
      record.quality_profile_strict_size_passed = plan.quality_profile_strict_size_passed;
      record.quality_profile_tight_spread_passed = plan.quality_profile_tight_spread_passed;
      record.quality_profile_strict_combo_passed = plan.quality_profile_strict_combo_passed;
      record.is_closed            = false;

      m_staged_records++;
      CFalconLogger::Info(StringFormat("Shadow trade staged. ShadowId=%s | Strategy=%s | Direction=%s | Entry=%.5f | SL=%.5f | TP1=%.5f",
                                       record.shadow_id,
                                       record.strategy_name,
                                       FalconDirectionToString(record.direction),
                                       record.entry_price,
                                       record.structural_sl,
                                       record.tp1));
      return true;
   }

   bool CloseShadowRecord(FalconShadowTradeRecord &record,
                          const double simulated_exit_price,
                          const string close_reason,
                          const FalconSymbolContext &symbol_context,
                          FalconTradeLifecycleRecord &lifecycle_record)
   {
      if(record.status != FALCON_SHADOW_RECORD_STAGED)
      {
         CFalconLogger::Warn("CloseShadowRecord ignored because record is not staged.");
         return false;
      }

      record.simulated_exit_price = simulated_exit_price;
      record.exit_time            = TimeCurrent();
      record.close_reason         = close_reason;
      record.status               = FALCON_SHADOW_RECORD_CLOSED;
      record.is_closed            = true;
      m_closed_records++;

      ShadowToLifecycle(record, lifecycle_record);
      FalconFinalizeTradeMetrics(lifecycle_record, symbol_context);
      record.simulated_outcome = lifecycle_record.outcome;

      CFalconLogger::Info(StringFormat("Shadow trade closed. ShadowId=%s | Outcome=%s | NetIndexPoints=%.2f | NetUSD=%.2f",
                                       record.shadow_id,
                                       FalconOutcomeToString(lifecycle_record.outcome),
                                       lifecycle_record.net_index_points,
                                       lifecycle_record.net_usd));
      return true;
   }

   void CancelShadowRecord(FalconShadowTradeRecord &record,
                           const string reason)
   {
      if(record.status != FALCON_SHADOW_RECORD_STAGED)
         return;

      record.status       = FALCON_SHADOW_RECORD_CANCELLED;
      record.close_reason = reason;
      record.exit_time    = TimeCurrent();
      record.is_closed    = true;
      m_cancelled_records++;
   }

private:
   void ResetShadowRecord(FalconShadowTradeRecord &record)
   {
      record.shadow_id            = "";
      record.strategy_id          = "";
      record.strategy_name        = "";
      record.engine_id            = "";
      record.direction            = FALCON_DIRECTION_NONE;
      record.status               = FALCON_SHADOW_RECORD_NONE;
      record.entry_time           = 0;
      record.exit_time            = 0;
      record.lot_size             = 0.0;
      record.entry_price          = 0.0;
      record.structural_sl        = 0.0;
      record.tp1                  = 0.0;
      record.tp2                  = 0.0;
      record.tp3                  = 0.0;
      record.simulated_exit_price = 0.0;
      record.simulated_outcome    = FALCON_TRADE_OUTCOME_UNKNOWN;
      record.close_reason         = "";
      record.evidence_summary     = "";
      record.fvg_size_points      = 0.0;
      record.fvg_spread_points    = 0;
      record.fvg_retest_age_bars  = 0;
      record.fvg_setup_time = 0;
      record.fvg_retest_watch_time = 0;
      record.fvg_age_bars_at_watch = 0;
      record.fvg_age_source = "";
      record.fvg_retest_fresh_state = "";
      record.fvg_hold_quality_score = 0;
      record.fvg_hold_quality_bucket = "";
      record.quality_filters_passed = false;
      record.fvg_quality_shadow_guard_profile = "";
      record.fvg_quality_shadow_guard_passed = false;
      record.fvg_quality_shadow_guard_decision = "NOT_EVALUATED";
      record.fvg_quality_shadow_guard_reason = "";
      record.fvg_quality_shadow_guard_sim_net_points = 0.0;
      record.fvg_quality_shadow_guard_sim_net_usd = 0.0;
      record.quality_profile_balanced_passed = false;
      record.quality_profile_strict_size_passed = false;
      record.quality_profile_tight_spread_passed = false;
      record.quality_profile_strict_combo_passed = false;
      record.is_closed            = false;
   }

   void ShadowToLifecycle(const FalconShadowTradeRecord &record,
                          FalconTradeLifecycleRecord &lifecycle_record)
   {
      lifecycle_record.trade_id            = record.shadow_id;
      lifecycle_record.strategy_id         = record.strategy_id;
      lifecycle_record.strategy_name       = record.strategy_name;
      lifecycle_record.engine_id           = record.engine_id;
      lifecycle_record.direction           = record.direction;
      lifecycle_record.stage               = FALCON_TRADE_STAGE_SHADOW;
      lifecycle_record.outcome             = record.simulated_outcome;
      lifecycle_record.entry_time          = record.entry_time;
      lifecycle_record.exit_time           = record.exit_time;
      lifecycle_record.lot_size            = record.lot_size;
      lifecycle_record.entry_price         = record.entry_price;
      lifecycle_record.structural_sl       = record.structural_sl;
      lifecycle_record.tp1                 = record.tp1;
      lifecycle_record.tp2                 = record.tp2;
      lifecycle_record.tp3                 = record.tp3;
      lifecycle_record.exit_price          = record.simulated_exit_price;
      lifecycle_record.profit_index_points = 0.0;
      lifecycle_record.loss_index_points   = 0.0;
      lifecycle_record.net_index_points    = 0.0;
      lifecycle_record.profit_usd          = 0.0;
      lifecycle_record.loss_usd            = 0.0;
      lifecycle_record.net_usd             = 0.0;
      lifecycle_record.close_reason        = record.close_reason;
      lifecycle_record.evidence_summary    = record.evidence_summary;
      lifecycle_record.fvg_size_points     = record.fvg_size_points;
      lifecycle_record.fvg_spread_points   = record.fvg_spread_points;
      lifecycle_record.fvg_retest_age_bars = record.fvg_retest_age_bars;
      lifecycle_record.fvg_setup_time = record.fvg_setup_time;
      lifecycle_record.fvg_retest_watch_time = record.fvg_retest_watch_time;
      lifecycle_record.fvg_age_bars_at_watch = record.fvg_age_bars_at_watch;
      lifecycle_record.fvg_age_source = record.fvg_age_source;
      lifecycle_record.fvg_retest_fresh_state = record.fvg_retest_fresh_state;
      lifecycle_record.fvg_hold_quality_score = record.fvg_hold_quality_score;
      lifecycle_record.fvg_hold_quality_bucket = record.fvg_hold_quality_bucket;
      lifecycle_record.quality_filters_passed = record.quality_filters_passed;
      lifecycle_record.quality_profile_balanced_passed = record.quality_profile_balanced_passed;
      lifecycle_record.quality_profile_strict_size_passed = record.quality_profile_strict_size_passed;
      lifecycle_record.quality_profile_tight_spread_passed = record.quality_profile_tight_spread_passed;
      lifecycle_record.quality_profile_strict_combo_passed = record.quality_profile_strict_combo_passed;
   }
};

#endif // FALCON_SHADOW_EXECUTOR_MQH
