//+------------------------------------------------------------------+
//| Core/FalconDataStructures.mqh                                    |
//| R0.2: all 22 top-level structs moved verbatim from the main .mq5.|
//| Literal move only - no logic change, no field rename, no reorder |
//| of fields. Depends on FalconEnums.mqh - include in that order.   |
//+------------------------------------------------------------------+
#ifndef FALCON_DATASTRUCTURES_MQH
#define FALCON_DATASTRUCTURES_MQH

// --- FalconSymbolContext (main .mq5 lines 2142-2157) ---
struct FalconSymbolContext
{
   string symbol;
   int    digits;
   double point;
   double tick_size;
   double tick_value;
   double contract_size;
   long   spread_points;
   long   stops_level_points;
   long   freeze_level_points;
   double min_lot;
   double max_lot;
   double lot_step;
   bool   is_valid;
};

// --- FalconQuoteContext (main .mq5 lines 2159-2170) ---
struct FalconQuoteContext
{
   double   bid;
   double   ask;
   double   last;
   long     volume;
   double   volume_real;
   datetime tick_time;
   long     time_msc;
   long     spread_points;
   bool     is_valid;
};

// --- FalconCandleSnapshot (main .mq5 lines 2172-2186) ---
struct FalconCandleSnapshot
{
   ENUM_TIMEFRAMES timeframe;
   datetime        time;
   double          open;
   double          high;
   double          low;
   double          close;
   long            tick_volume;
   long            real_volume;
   int             spread;
   int             source_shift;
   bool            is_closed;
   bool            is_valid;
};

// --- FalconRuntimeSafetyCheck (main .mq5 lines 2188-2201) ---
struct FalconRuntimeSafetyCheck
{
   string                              check_id;
   string                              check_name;
   ENUM_FALCON_RUNTIME_SAFETY_STATUS   status;
   ENUM_FALCON_LOOKAHEAD_RISK          risk_type;
   ENUM_TIMEFRAMES                     timeframe;
   int                                 source_shift;
   bool                                used_closed_candle;
   bool                                current_candle_blocked;
   bool                                final_state_blocked;
   bool                                staging_allowed;
   string                              notes;
};

// --- FalconStrategyRegistryEntry (main .mq5 lines 2203-2217) ---
struct FalconStrategyRegistryEntry
{
   string                     strategy_id;
   string                     strategy_name;
   string                     engine_id;
   ENUM_FALCON_STRATEGY_GROUP strategy_group;
   bool                       input_enabled;
   ENUM_FALCON_ENGINE_HEALTH  health_status;
   ENUM_FALCON_ENGINE_STATUS  max_allowed_stage;
   bool                       shadow_allowed;
   bool                       paper_allowed;
   bool                       demo_allowed;
   bool                       live_allowed;
   string                     notes;
};

// --- FalconStrategyAdapterSnapshot (main .mq5 lines 2219-2241) ---
struct FalconStrategyAdapterSnapshot
{
   string                     adapter_id;
   string                     target_strategy_id;
   string                     strategy_name;
   string                     engine_id;
   ENUM_FALCON_STRATEGY_GROUP strategy_group;
   ENUM_FALCON_ENGINE_HEALTH  health_status;
   ENUM_FALCON_ENGINE_STATUS  max_allowed_stage;
   ENUM_FALCON_ADAPTER_STATUS adapter_status;
   bool                       registry_found;
   bool                       input_enabled;
   bool                       shadow_allowed;
   bool                       shadow_executor_ready;
   bool                       runtime_safety_ready;
   bool                       candidate_requested;
   bool                       candidate_staged;
   bool                       live_allowed;
   bool                       order_send_used;
   string                     no_trade_reason;
   string                     safety_reason;
   string                     notes;
};

// --- FalconFvgMicroDetectorSnapshot (main .mq5 lines 2244-2286) ---
struct FalconFvgMicroDetectorSnapshot
{
   string                       detector_id;
   string                       strategy_id;
   string                       strategy_name;
   string                       engine_id;
   ENUM_FALCON_DETECTOR_STATUS  detector_status;
   bool                         registry_found;
   bool                         input_enabled;
   bool                         candle_cache_ready;
   bool                         evidence_framework_ready;
   bool                         runtime_safety_ready;
   bool                         used_closed_candle;
   bool                         order_send_used;
   ENUM_TIMEFRAMES              analysis_timeframe;
   int                          analysis_shift;
   datetime                     candle_time;
   double                       candle_open;
   double                       candle_high;
   double                       candle_low;
   double                       candle_close;
   long                         candle_tick_volume;
   bool                         fvg_detected;
   ENUM_FALCON_DIRECTION        fvg_direction;
   datetime                     older_candle_time;
   datetime                     middle_candle_time;
   datetime                     newer_candle_time;
   double                       older_candle_high;
   double                       older_candle_low;
   double                       middle_candle_high;
   double                       middle_candle_low;
   double                       newer_candle_high;
   double                       newer_candle_low;
   double                       fvg_lower;
   double                       fvg_upper;
   double                       fvg_size_price;
   double                       fvg_size_points;
   double                       evidence_score;
   string                       evidence_summary;
   string                       no_trade_reason;
   string                       safety_reason;
   string                       notes;
};

// --- FalconFvgMicroShadowCandidateSnapshot (main .mq5 lines 2288-2337) ---
struct FalconFvgMicroShadowCandidateSnapshot
{
   string                       builder_id;
   string                       candidate_id;
   string                       strategy_id;
   string                       strategy_name;
   string                       engine_id;
   ENUM_FALCON_CANDIDATE_STATUS candidate_status;
   bool                         detector_initialized;
   bool                         registry_found;
   bool                         input_enabled;
   bool                         shadow_allowed;
   bool                         runtime_safety_ready;
   bool                         fvg_detected;
   bool                         candidate_created;
   bool                         tradeplan_created;
   bool                         staged_to_shadow_executor;
   bool                         order_send_used;
   ENUM_FALCON_DIRECTION        direction;
   ENUM_TIMEFRAMES              analysis_timeframe;
   datetime                     setup_time;
   double                       entry_zone_lower;
   double                       entry_zone_upper;
   double                       fvg_size_points;
   bool                         quality_filters_enabled;
   bool                         quality_filters_passed;
   double                       quality_min_fvg_size_points;
   long                         quality_current_spread_points;
   long                         quality_max_spread_points;
   int                          quality_fvg_age_bars;
   int                          quality_max_fvg_age_bars;
   int                          quality_retest_freshness_bars;
   string                       quality_reject_reason;
   int                          fvg_retest_age_bars;
   datetime                     fvg_setup_time;
   datetime                     fvg_retest_watch_time;
   int                          fvg_age_bars_at_watch;
   string                       fvg_age_source;
   string                       fvg_retest_fresh_state;
   int                          fvg_hold_quality_score;
   string                       fvg_hold_quality_bucket;
   bool                         quality_profile_balanced_passed;
   bool                         quality_profile_strict_size_passed;
   bool                         quality_profile_tight_spread_passed;
   bool                         quality_profile_strict_combo_passed;
   double                       score;
   string                       block_reason;
   string                       evidence_summary;
   string                       notes;
};

// --- FalconFvgMicroRetestWatcherSnapshot (main .mq5 lines 2547-2604) ---
struct FalconFvgMicroRetestWatcherSnapshot
{
   string                            watcher_id;
   string                            candidate_id;
   string                            strategy_id;
   string                            strategy_name;
   string                            engine_id;
   ENUM_FALCON_RETEST_WATCHER_STATUS watcher_status;
   bool                              candidate_builder_initialized;
   bool                              candidate_ready;
   bool                              quote_valid;
   bool                              runtime_safety_ready;
   bool                              fvg_detected;
   bool                              retest_touched;
   bool                              tradeplan_skeleton_created;
   bool                              tradeplan_created;
   bool                              staged_to_shadow_executor;
   bool                              order_send_used;
   ENUM_FALCON_DIRECTION             direction;
   ENUM_TIMEFRAMES                   analysis_timeframe;
   datetime                          setup_time;
   datetime                          watch_time;
   double                            watch_price;
   double                            fvg_lower;
   double                            fvg_upper;
   double                            fvg_size_points;
   bool                              quality_filters_enabled;
   bool                              quality_filters_passed;
   double                            quality_min_fvg_size_points;
   long                              quality_current_spread_points;
   long                              quality_max_spread_points;
   int                               quality_fvg_age_bars;
   int                               quality_max_fvg_age_bars;
   int                               quality_retest_freshness_bars;
   string                            quality_reject_reason;
   int                               fvg_retest_age_bars;
   datetime                          fvg_setup_time;
   datetime                          fvg_retest_watch_time;
   int                               fvg_age_bars_at_watch;
   string                            fvg_age_source;
   string                            fvg_retest_fresh_state;
   int                               fvg_hold_quality_score;
   string                            fvg_hold_quality_bucket;
   bool                              quality_profile_balanced_passed;
   bool                              quality_profile_strict_size_passed;
   bool                              quality_profile_tight_spread_passed;
   bool                              quality_profile_strict_combo_passed;
   double                            planned_entry_price;
   double                            planned_structural_sl;
   double                            planned_tp1;
   double                            planned_tp2;
   double                            planned_tp3;
   double                            planned_lot_size;
   string                            retest_reason;
   string                            block_reason;
   string                            skeleton_notes;
   string                            notes;
};

// --- FalconFvgMicroTradePlanStagingSnapshot (main .mq5 lines 2606-2642) ---
struct FalconFvgMicroTradePlanStagingSnapshot
{
   string                               stager_id;
   string                               plan_id;
   string                               candidate_id;
   string                               shadow_id;
   string                               strategy_id;
   string                               strategy_name;
   string                               engine_id;
   ENUM_FALCON_TRADEPLAN_STAGING_STATUS staging_status;
   ENUM_FALCON_RETEST_WATCHER_STATUS    watcher_status;
   bool                                 watcher_initialized;
   bool                                 retest_touched;
   bool                                 skeleton_ready;
   bool                                 runtime_safety_ready;
   bool                                 shadow_executor_ready;
   bool                                 tradeplan_created;
   bool                                 validate_passed;
   bool                                 staged_to_shadow_executor;
   bool                                 order_send_used;
   ENUM_FALCON_DIRECTION                direction;
   ENUM_TIMEFRAMES                      analysis_timeframe;
   datetime                             setup_time;
   datetime                             staging_time;
   double                               lot_size;
   double                               entry_price;
   double                               structural_sl;
   double                               tp1;
   double                               tp2;
   double                               tp3;
   string                               risk_profile;
   string                               management_profile;
   string                               validation_reason;
   string                               staging_reason;
   string                               evidence_summary;
   string                               notes;
};

// --- FalconFvgMicroShadowLifecycleSnapshot (main .mq5 lines 2644-2681) ---
struct FalconFvgMicroShadowLifecycleSnapshot
{
   string                              simulator_id;
   string                              shadow_id;
   string                              strategy_id;
   string                              strategy_name;
   string                              engine_id;
   ENUM_FALCON_SHADOW_LIFECYCLE_STATUS lifecycle_status;
   ENUM_FALCON_SHADOW_RECORD_STATUS    shadow_record_status;
   bool                                stager_ready;
   bool                                staged_to_shadow_executor;
   bool                                shadow_record_loaded;
   bool                                quote_valid;
   bool                                close_record_created;
   bool                                registered_to_trade_report;
   bool                                order_send_used;
   ENUM_FALCON_DIRECTION               direction;
   datetime                            entry_time;
   datetime                            evaluation_time;
   int                                 elapsed_seconds;
   double                              entry_price;
   double                              structural_sl;
   double                              tp1;
   double                              tp2;
   double                              tp3;
   double                              current_price;
   double                              simulated_exit_price;
   ENUM_FALCON_TRADE_OUTCOME           simulated_outcome;
   double                              profit_index_points;
   double                              loss_index_points;
   double                              net_index_points;
   double                              profit_usd;
   double                              loss_usd;
   double                              net_usd;
   string                              close_reason;
   string                              lifecycle_reason;
   string                              notes;
};

// --- FalconEvidenceRecord (main .mq5 lines 2683-2694) ---
struct FalconEvidenceRecord
{
   string                     evidence_id;
   string                     evidence_name;
   ENUM_FALCON_EVIDENCE_TYPE  evidence_type;
   ENUM_FALCON_EVIDENCE_STATE evidence_state;
   ENUM_FALCON_DIRECTION      direction_bias;
   ENUM_TIMEFRAMES            source_timeframe;
   double                     score;
   bool                       is_runtime_permission;
   string                     notes;
};

// --- FalconEvidencePack (main .mq5 lines 2696-2704) ---
struct FalconEvidencePack
{
   bool   has_candle_evidence;
   bool   has_chart_pattern_evidence;
   bool   has_objective_indicator_evidence;
   bool   has_smc_evidence;
   double score;
   string summary;
};

// --- FalconObjectivePlan (main .mq5 lines 2706-2715) ---
struct FalconObjectivePlan
{
   double entry_price;
   double structural_sl;
   double tp1;
   double tp2;
   double tp3;
   bool   runner_allowed;
   string objective_reason;
};

// --- FalconStrategySignal (main .mq5 lines 2717-2731) ---
struct FalconStrategySignal
{
   string                    strategy_id;
   string                    strategy_name;
   string                    engine_id;
   ENUM_FALCON_DIRECTION     direction;
   ENUM_FALCON_ENGINE_STATUS engine_status;
   ENUM_FALCON_GUARD_STATUS  guard_status;
   datetime                  setup_time;
   ENUM_TIMEFRAMES           setup_timeframe;
   double                    score;
   string                    rejection_reason;
   FalconEvidencePack        evidence;
   FalconObjectivePlan       objective;
};

// --- FalconTradePlan (main .mq5 lines 2733-2767) ---
struct FalconTradePlan
{
   string                plan_id;
   string                strategy_id;
   string                strategy_name;
   string                engine_id;
   ENUM_FALCON_DIRECTION direction;
   double                lot_size;
   double                entry_price;
   double                structural_sl;
   double                tp1;
   double                tp2;
   double                tp3;
   bool                  runner_allowed;
   string                risk_profile;
   string                management_profile;

   // v0.21.0: FVG Micro per-trade quality attribution.
   // Metadata only: no entry, SL, TP, routing, or lifecycle close behavior changes.
   double                fvg_size_points;
   long                  fvg_spread_points;
   int                   fvg_retest_age_bars;
   datetime              fvg_setup_time;
   datetime              fvg_retest_watch_time;
   int                   fvg_age_bars_at_watch;
   string                fvg_age_source;
   string                fvg_retest_fresh_state;
   int                   fvg_hold_quality_score;
   string                fvg_hold_quality_bucket;
   bool                  quality_filters_passed;
   bool                  quality_profile_balanced_passed;
   bool                  quality_profile_strict_size_passed;
   bool                  quality_profile_tight_spread_passed;
   bool                  quality_profile_strict_combo_passed;
};

// --- FalconTradeLifecycleRecord (main .mq5 lines 2769-2980) ---
struct FalconTradeLifecycleRecord
{
   string                    trade_id;
   string                    strategy_id;
   string                    strategy_name;
   string                    engine_id;
   ENUM_FALCON_DIRECTION     direction;
   ENUM_FALCON_TRADE_STAGE   stage;
   ENUM_FALCON_TRADE_OUTCOME outcome;
   datetime                  entry_time;
   datetime                  exit_time;
   double                    lot_size;
   double                    entry_price;
   double                    structural_sl;
   double                    tp1;
   double                    tp2;
   double                    tp3;
   double                    exit_price;
   double                    profit_index_points;
   double                    loss_index_points;
   double                    net_index_points;
   double                    profit_usd;
   double                    loss_usd;
   double                    net_usd;
   string                    close_reason;
   string                    evidence_summary;

   // v0.21.0: FVG Micro quality attribution carried into TradeLifecycle rows.
   double                    fvg_size_points;
   long                      fvg_spread_points;
   int                       fvg_retest_age_bars;
   datetime                  fvg_setup_time;
   datetime                  fvg_retest_watch_time;
   int                       fvg_age_bars_at_watch;
   string                    fvg_age_source;
   string                    fvg_retest_fresh_state;
   int                       fvg_hold_quality_score;
   string                    fvg_hold_quality_bucket;
   bool                      quality_filters_passed;

   // v0.22.2: locked P03_SIZE250_ONLY FVG quality shadow simulation carried into TradeLifecycle rows.
   // v0.22.3: OOS validation lock only; behavior and report surface remain unchanged.
   // Diagnostic only: does not affect entry, exit, SL, TP, risk, or runtime decisions.
   string                    fvg_quality_shadow_guard_profile;
   bool                      fvg_quality_shadow_guard_passed;
   string                    fvg_quality_shadow_guard_decision;
   string                    fvg_quality_shadow_guard_reason;
   double                    fvg_quality_shadow_guard_sim_net_points;
   double                    fvg_quality_shadow_guard_sim_net_usd;

   bool                      quality_profile_balanced_passed;
   bool                      quality_profile_strict_size_passed;
   bool                      quality_profile_tight_spread_passed;
   bool                      quality_profile_strict_combo_passed;

   // v0.49.0: Paper Runtime Guard Application Phase 1 fields.
   string                    paper_guard_status;
   string                    paper_reject_reason;
   string                    paper_guard_layer;
   long                      paper_spread_points;
   int                       paper_max_spread_points;
   double                    paper_sl_distance_points;
   long                      paper_stops_level_points;
   long                      paper_freeze_level_points;
   double                    paper_guard_net_index_points;
   double                    paper_guard_net_usd;

   // v0.50.0: Paper Runtime Smart SL / Protection Application fields.
   string                    paper_protection_state;
   double                    paper_virtual_sl;
   string                    paper_protection_trigger;
   double                    paper_protection_level;
   bool                      paper_protection_activated;
   bool                      paper_virtual_sl_changed;
   bool                      paper_virtual_sl_hit;
   string                    paper_exit_reason;
   double                    paper_protection_net_index_points;
   double                    paper_protection_net_usd;

   // v0.51.0: Paper Runtime Runner Application fields.
   string                    paper_runner_state;
   bool                      paper_runner_activated;
   double                    paper_runner_max_r;
   double                    paper_runner_captured_points;
   double                    paper_runner_additional_points;
   string                    paper_runner_exit_reason;
   double                    paper_runner_net_index_points;
   double                    paper_runner_net_usd;
   string                    paper_final_exit_reason;

   // v0.53.0: Capital Tier Foundation logging fields.
   string                    falcon_tier_at_entry;
   string                    falcon_tier_at_exit;
   double                    falcon_effective_balance;
   double                    falcon_tier_min_balance;
   double                    falcon_tier_max_balance;
   int                       falcon_tier_max_losses;
   double                    falcon_tier_max_daily_r;
   double                    falcon_tier_max_drawdown_pct;
   double                    falcon_broker_min_lot;
   double                    falcon_fixed_lot;
   string                    falcon_min_lot_constraint;

   // v0.55.1: Low-Capital Risk Feasibility Foundation fields.
   string                    falcon_lotsizing_feasibility_status;
   string                    falcon_lotsizing_feasibility_reason;
   double                    falcon_min_lot_risk_points;
   double                    falcon_min_lot_risk_usd;
   double                    falcon_min_lot_risk_pct_of_capital;
   double                    falcon_tier_base_risk_pct;
   double                    falcon_tier_risk_budget_usd;
   double                    falcon_potential_loss_r;
   double                    falcon_max_single_trade_loss_r;
   int                       falcon_single_trade_loss_cap_breach;

   // v0.55.2: Calibrated Single Trade Loss Cap Enforcement Candidate fields.
   string                    falcon_single_trade_loss_cap_status;
   string                    falcon_single_trade_loss_cap_decision;
   string                    falcon_single_trade_loss_cap_reason;
   int                       falcon_single_trade_loss_cap_runtime_enforced;
   double                    falcon_single_trade_loss_cap_strict_cap_r;
   double                    falcon_single_trade_loss_cap_calibrated_cap_r;
   double                    falcon_single_trade_loss_cap_risk_pct_cap;
   int                       falcon_single_trade_loss_cap_blocked;
   double                    falcon_single_trade_loss_cap_before_net_points;
   double                    falcon_single_trade_loss_cap_after_net_points;
   double                    falcon_single_trade_loss_cap_impact_points;
   double                    falcon_single_trade_loss_cap_before_net_usd;
   double                    falcon_single_trade_loss_cap_after_net_usd;
   double                    falcon_single_trade_loss_cap_impact_usd;

   // v0.55.2a: Dynamic capital-aware risk fields.
   string                    falcon_dynamic_capital_mode;
   double                    falcon_dynamic_risk_capital_before_trade;
   double                    falcon_dynamic_risk_capital_after_trade;
   string                    falcon_dynamic_risk_tier_by_capital;
   double                    falcon_dynamic_risk_pct_of_capital;
   double                    falcon_dynamic_single_trade_cap_pct;
   int                       falcon_dynamic_capital_aware_blocked;
   string                    falcon_dynamic_capital_reason;

   // v0.55.5: Capital flow source classification fields. Reporting-only; no trading behavior change.
   string                    falcon_capital_flow_source;
   double                    falcon_capital_flow_delta_usd;
   double                    falcon_external_capital_delta_usd;
   int                       falcon_capital_flow_external_event;
   string                    falcon_capital_flow_status;
   string                    falcon_capital_flow_reason;

   // v0.55.3: Dynamic LotSizing Model / Capital Flow Awareness fields.
   string                    falcon_dlm_status;
   string                    falcon_dlm_decision;
   int                       falcon_dlm_runtime_enforced;
   int                       falcon_dlm_use_fixed_lot;
   double                    falcon_dlm_fixed_lot_size;
   double                    falcon_dlm_effective_capital;
   double                    falcon_dlm_base_risk_pct;
   double                    falcon_dlm_risk_budget_usd;
   double                    falcon_dlm_risk_points;
   double                    falcon_dlm_risk_usd_per_one_lot;
   double                    falcon_dlm_raw_lot;
   double                    falcon_dlm_recommended_lot;
   double                    falcon_dlm_active_lot;
   double                    falcon_dlm_tier_max_lot;
   double                    falcon_dlm_capital_max_lot;
   double                    falcon_dlm_previous_active_lot;
   double                    falcon_dlm_growth_ramp_max_lot;
   int                       falcon_dlm_tier_cap_applied;
   int                       falcon_dlm_capital_cap_applied;
   int                       falcon_dlm_growth_ramp_applied;
   string                    falcon_dlm_safety_mode;
   double                    falcon_dlm_broker_min_lot;
   double                    falcon_dlm_broker_max_lot;
   double                    falcon_dlm_broker_lot_step;
   int                       falcon_dlm_min_lot_floor_applied;
   int                       falcon_dlm_max_lot_cap_applied;
   double                    falcon_dlm_recommended_risk_usd;
   double                    falcon_dlm_recommended_risk_pct;
   double                    falcon_dlm_active_risk_usd;
   double                    falcon_dlm_active_risk_pct;
   string                    falcon_dlm_reason;

   // v0.55.11c: Session boundary / no-new-entry paper enforcement fields.
   string                    falcon_market_close_status;
   int                       falcon_market_close_blocked;
   string                    falcon_market_close_reason;
   double                    falcon_market_close_before_net_usd;
   double                    falcon_market_close_after_net_usd;
   double                    falcon_market_close_impact_usd;

   // v0.53.1: Three-Layer Emergency active paper replacement fields.
   string                    falcon_emergency_status;
   int                       falcon_emergency_triggered_layer;
   string                    falcon_emergency_reason;
   int                       falcon_layer1_consecutive_losses;
   int                       falcon_layer1_max_losses;
   double                    falcon_layer2_daily_r;
   double                    falcon_layer2_max_daily_r;
   double                    falcon_layer3_drawdown_pct;
   double                    falcon_layer3_max_drawdown_pct;
   double                    falcon_emergency_before_net_points;
   double                    falcon_emergency_after_net_points;
   double                    falcon_emergency_before_net_usd;
   double                    falcon_emergency_after_net_usd;

   // v0.53.2: Layer-specific reset logic validation fields.
   string                    falcon_reset_status;
   int                       falcon_layer1_reset_on_win;
   int                       falcon_layer2_reset_on_new_day;
   int                       falcon_layer3_reset_on_new_peak;
   string                    falcon_reset_reason;
};

// --- FalconShadowTradeRecord (main .mq5 lines 2983-3032) ---
struct FalconShadowTradeRecord
{
   string                           shadow_id;
   string                           strategy_id;
   string                           strategy_name;
   string                           engine_id;
   ENUM_FALCON_DIRECTION            direction;
   ENUM_FALCON_SHADOW_RECORD_STATUS status;
   datetime                         entry_time;
   datetime                         exit_time;
   double                           lot_size;
   double                           entry_price;
   double                           structural_sl;
   double                           tp1;
   double                           tp2;
   double                           tp3;
   double                           simulated_exit_price;
   ENUM_FALCON_TRADE_OUTCOME        simulated_outcome;
   string                           close_reason;
   string                           evidence_summary;

   // v0.21.3: official FVG attribution fields carried into closed TradeLifecycle records.
   double                           fvg_size_points;
   long                             fvg_spread_points;
   int                              fvg_retest_age_bars;
   datetime                         fvg_setup_time;
   datetime                         fvg_retest_watch_time;
   int                              fvg_age_bars_at_watch;
   string                           fvg_age_source;
   string                           fvg_retest_fresh_state;
   int                              fvg_hold_quality_score;
   string                           fvg_hold_quality_bucket;
   bool                             quality_filters_passed;

   // v0.22.0: FVG quality shadow guard simulation.
   // These fields are diagnostic only and do not affect actual Shadow lifecycle rows.
   string                           fvg_quality_shadow_guard_profile;
   bool                             fvg_quality_shadow_guard_passed;
   string                           fvg_quality_shadow_guard_decision;
   string                           fvg_quality_shadow_guard_reason;
   double                           fvg_quality_shadow_guard_sim_net_points;
   double                           fvg_quality_shadow_guard_sim_net_usd;

   bool                             quality_profile_balanced_passed;
   bool                             quality_profile_strict_size_passed;
   bool                             quality_profile_tight_spread_passed;
   bool                             quality_profile_strict_combo_passed;

   bool                             is_closed;
};

// --- FalconBrokerTradeLink (main .mq5 lines 3126-3178) ---
struct FalconBrokerTradeLink
{

   string                    trade_id;
   string                    trade_id_short;
   string                    strategy_id;
   string                    engine_id;
   ENUM_FALCON_DIRECTION     direction;
   long                      broker_magic;
   ulong                     broker_position_ticket;
   ulong                     broker_position_identifier;
   ulong                     broker_order_ticket;
   ulong                     broker_deal_ticket;
   ulong                     broker_close_order_ticket;
   ulong                     broker_close_deal_ticket;
   double                    requested_lot;
   double                    accepted_lot;
   double                    planned_entry_price;
   double                    broker_entry_price;
   double                    broker_sl;
   double                    broker_tp;
   double                    broker_close_price;
   double                    broker_close_volume;
   double                    broker_actual_balance_delta;
   datetime                  planned_entry_time;
   datetime                  broker_entry_time;
   datetime                  broker_close_time;
   bool                      broker_entry_attempted;
   bool                      broker_entry_accepted;
   bool                      broker_close_attempted;
   bool                      broker_close_accepted;
   bool                      broker_exit_observed;
   bool                      managed_close_attempted;
   bool                      managed_close_accepted;
   string                    entry_comment;
   string                    managed_close_comment;
   string                    broker_exit_status;
   string                    broker_exit_reason;
   string                    status;
   string                    reason;

   // v0.57.2: Virtual Trailing Exit Bridge per-link state.
   bool                      virtual_trailing_active;
   bool                      virtual_breakeven_locked;
   double                    virtual_peak_favorable_price;
   double                    virtual_trailing_stop_price;
   double                    virtual_protection_floor_price;
   datetime                  virtual_trailing_last_update;
   // v0.57.4: BE mode tag set at BE-lock time. "STRUCTURAL" when anchored on a
   // confirmed swing; "FIXED_FALLBACK" when no qualifying swing was found and
   // the v0.57.3 spread-aware floor was used. Empty before BE locks.
   string                    virtual_breakeven_mode;
};

// --- FalconBrokerTradeManagementEvent (main .mq5 lines 3180-3207) ---
struct FalconBrokerTradeManagementEvent
{
   string                              trade_id;
   string                              strategy_id;
   string                              engine_id;
   ENUM_FALCON_DIRECTION               direction;
   ENUM_FALCON_BROKER_TM_EVENT_TYPE    event_type;
   datetime                            event_time;
   double                              event_price;
   bool                                event_executable;
   string                              execution_eligibility;
   ulong                               broker_position_ticket;
   bool                                tp1_touched;
   bool                                tp2_touched;
   bool                                protection_activated;
   bool                                runner_activated;
   string                              protection_state;
   string                              runner_state;
   double                              paper_raw_trade_usd;
   double                              paper_final_working_trade_usd;
   double                              paper_protection_net_usd;
   double                              paper_runner_net_usd;
   double                              paper_raw_index_points;
   double                              paper_final_working_index_points;
   string                              event_source;
   string                              status;
   string                              reason;
};

// --- FalconReportTotals (main .mq5 lines 3209-3587) ---
struct FalconReportTotals
{
   int    total_trades;
   int    win_trades;
   int    loss_trades;
   int    breakeven_trades;
   double total_profit_index_points;
   double total_loss_index_points;
   double net_index_points;
   double total_profit_usd;
   double total_loss_usd;
   double net_usd;

   // v0.55.5: truthful final-working USD totals derived from per-trade final layer output.
   int    final_profit_trades;
   int    final_loss_trades;
   int    final_breakeven_trades;
   double final_total_profit_usd;
   double final_total_loss_usd;
   double final_working_net_usd;

   // v0.55.5: visible-row audit totals using the exact 4-decimal values written into TradeLifecycle.
   double visible_raw_net_usd_4dp;
   double visible_final_working_net_usd_4dp;
   double visible_final_total_profit_usd_4dp;
   double visible_final_total_loss_usd_4dp;

   // v0.55.5: Capital flow classification summary counters.
   int    capital_flow_evaluated_trades;
   int    capital_flow_trade_profit_events;
   int    capital_flow_trade_loss_events;
   int    capital_flow_flat_events;
   int    capital_flow_injection_events;
   int    capital_flow_withdrawal_events;
   int    capital_flow_unknown_events;
   int    capital_flow_integrity_breaches;
   double capital_flow_external_net_usd;

   // v0.55.9: Weekly Stability Score Foundation summary-only counters.
   int    weekly_stability_evaluated_trades;
   int    weekly_stability_weeks;
   int    weekly_stability_positive_weeks;
   int    weekly_stability_negative_weeks;
   double weekly_stability_best_week_usd;
   double weekly_stability_worst_week_usd;
   double weekly_stability_score;

   // v0.55.11: Market Close / Weekend Guard foundation summary-only counters.
   int    market_close_guard_evaluated_trades;
   int    market_close_guard_near_close_entry_trades;
   int    market_close_guard_open_weekend_risk_trades;

   // v0.55.11a: No-new-entry timing calibration. Summary-only; no enforcement yet.
   int    market_close_max_trade_duration_minutes;
   double market_close_total_trade_duration_minutes;
   int    market_close_duration_above_window_trades;
   string market_close_longest_trade_id;

   // v0.55.11f: user-controlled No-New-Entry override. Disabled by default.
   // When enabled, it blocks Paper entries in the final user-selected minutes before close.
   int    no_new_entry_override_evaluated_trades;
   int    no_new_entry_override_blocked_trades;
   int    no_new_entry_override_blocked_winners;
   int    no_new_entry_override_blocked_losers;
   double no_new_entry_override_impact_usd;

   // v0.55.12a: Daily / Weekend Force Close User Override. Disabled by default.
   // When enabled, it changes Paper results before Emergency and Capital Flow.
   int    force_close_override_evaluated_trades;
   int    force_close_override_closed_trades;
   int    force_close_override_daily_closed_trades;
   int    force_close_override_weekend_closed_trades;
   int    force_close_override_price_ok_trades;
   int    force_close_override_missing_price_trades;
   double force_close_override_before_net_usd;
   double force_close_override_after_net_usd;
   double force_close_override_impact_usd;

   // v0.55.13: Paper state persistence foundation counters. Snapshot-only; no restore/enforcement yet.
   int    paper_state_snapshot_evaluated_trades;
   int    paper_state_snapshot_written_rows;
   int    paper_state_snapshot_write_failures;
   int    paper_state_recovery_trusted_trades;
   int    paper_state_recovery_untrusted_trades;

   // v0.55.13-fix4: dynamic session boundary checkpoint foundation. Measurement-only.
   int    session_boundary_checkpoint_evaluated_trades;
   int    session_boundary_recovery_checkpoint_minutes;
   int    session_boundary_daily_checkpoint_open_trades;
   int    session_boundary_weekend_checkpoint_open_trades;
   int    session_boundary_recovery_required_trades;
   int    session_boundary_dirty_after_close_safety_trades;

   double win_rate;
   double loss_rate;

   int    buy_trades;
   int    buy_win_trades;
   double buy_net_index_points;

   int    sell_trades;
   int    sell_win_trades;
   double sell_net_index_points;

   // v0.22.0: Shadow-only quality guard simulation totals.
   int    fvg_qguard_evaluated;
   int    fvg_qguard_passed;
   int    fvg_qguard_blocked;
   int    fvg_qguard_blocked_winners;
   int    fvg_qguard_blocked_losers;
   double fvg_qguard_actual_net_points;
   double fvg_qguard_simulated_net_points;
   double fvg_qguard_blocked_net_points;
   double fvg_qguard_actual_net_usd;
   double fvg_qguard_simulated_net_usd;
   double fvg_qguard_blocked_net_usd;

   // v0.28.1: StructuralStop + TPBuilder validation lock counters. Summary-only audit remains locked.
   int    sltp_validation_evaluated_trades;
   int    structural_stop_valid_trades;
   int    structural_stop_invalid_trades;
   int    tp_builder_valid_trades;
   int    tp_builder_invalid_trades;
   int    tp1_valid_trades;
   int    tp2_valid_trades;
   int    tp3_valid_trades;

   // v0.29.1: Smart Trade Management behavior/proof calibration. Summary-only; no runtime exit changes.
   int    smart_tm_evaluated_trades;
   int    smart_tm_proof_score_min;
   int    smart_tm_proof_score_max;
   long   smart_tm_proof_score_total;
   int    smart_tm_exit_conservative_trades;
   int    smart_tm_partial_no_runner_trades;
   int    smart_tm_runner_candidate_trades;
   int    smart_tm_strong_runner_candidate_trades;
   long   smart_tm_antiproof_score_total;
   int    smart_tm_antiproof_score_max;
   int    smart_tm_antiproof_high_risk_trades;
   int    smart_tm_behavior_healthy_trades;
   int    smart_tm_behavior_choppy_trades;
   int    smart_tm_behavior_failure_trades;
   int    smart_tm_runner_opportunity_trades;
   int    smart_tm_strong_runner_opportunity_trades;
   int    smart_tm_tp1_close_trades;
   int    smart_tm_sl_failure_trades;
   int    smart_tm_timeout_close_trades;

   // v0.29.1: Calibrated proof/behavior buckets. Summary-only; no runtime exit changes.
   int    smart_tm_proof_weak_trades;
   int    smart_tm_proof_medium_trades;
   int    smart_tm_proof_strong_trades;
   int    smart_tm_proof_elite_trades;
   int    smart_tm_behavior_grinding_trades;
   int    smart_tm_behavior_exhausted_trades;
   int    smart_tm_runner_conservative_opportunity_trades;

   // v0.29.2: Runner MFE/Giveback proxy diagnostics. Summary-only; no runtime exit changes.
   int    runner_diag_evaluated_trades;
   int    runner_diag_tp1_anchor_trades;
   int    runner_diag_tp2_anchor_trades;
   int    runner_diag_mfe_proxy_trades;
   double runner_diag_mfe_proxy_total_points;
   double runner_diag_mfe_proxy_max_points;
   double runner_diag_tp1_to_tp2_room_total_points;
   double runner_diag_tp1_to_tp3_room_total_points;
   double runner_diag_tp2_to_tp3_room_total_points;
   double runner_diag_max_r_proxy_total;
   double runner_diag_max_r_proxy_max;
   int    runner_diag_would_reach_3r_trades;
   int    runner_diag_would_reach_5r_trades;
   int    runner_diag_protected_profit_opportunity_trades;
   int    runner_diag_return_to_loss_after_proof_unknown_trades;

   // v0.29.3a: Runner bar-path metric definition calibration totals. Summary-only; no runtime exit changes.
   int    runner_barpath_evaluated_trades;
   int    runner_barpath_scanned_trades;
   int    runner_barpath_scan_failed_trades;
   int    runner_barpath_total_bars_scanned;
   int    runner_barpath_tp1_touched_trades;
   int    runner_barpath_tp2_touched_trades;
   int    runner_barpath_tp1_touched_then_extended_trades;
   int    runner_barpath_tp2_touched_then_extended_trades;
   double runner_barpath_tp1_to_max_run_total_points;
   double runner_barpath_tp1_to_max_run_max_points;
   double runner_barpath_tp2_to_max_run_total_points;
   double runner_barpath_tp2_to_max_run_max_points;
   double runner_barpath_mfe_after_tp1_total_points;
   double runner_barpath_mfe_after_tp1_max_points;
   double runner_barpath_mfe_after_tp2_total_points;
   double runner_barpath_mfe_after_tp2_max_points;
   double runner_barpath_giveback_after_tp1_total_points;
   double runner_barpath_giveback_after_tp1_max_points;
   double runner_barpath_giveback_after_tp2_total_points;
   double runner_barpath_giveback_after_tp2_max_points;
   int    runner_barpath_returned_to_loss_after_tp1_trades;
   int    runner_barpath_returned_to_loss_after_tp2_trades;
   int    runner_barpath_actual_would_reach_3r_trades;
   int    runner_barpath_actual_would_reach_5r_trades;
   int    runner_barpath_protected_after_tp1_opportunity_trades;
   int    runner_barpath_protected_after_tp2_opportunity_trades;

   // v0.29.4: Fast protection / runner decision readiness diagnostics. Summary-only; no runtime exit changes.
   int    fast_tm_evaluated_trades;
   int    fast_tm_decision_cache_ready_trades;
   int    fast_tm_precomputed_branch_ready_trades;
   int    fast_tm_tp1_decision_ready_trades;
   int    fast_tm_tp2_decision_ready_trades;
   int    fast_tm_protection_required_after_tp1_trades;
   int    fast_tm_protection_required_after_tp2_trades;
   int    fast_tm_immediate_runner_candidate_trades;
   int    fast_tm_immediate_exit_warning_trades;
   int    fast_tm_fast_antiproof_warning_trades;
   int    fast_tm_conservative_partial_ready_trades;
   int    fast_tm_runner_wait_for_confirmation_trades;

   // v0.49.0: Paper Runtime Guard Application Phase 1 totals.
   int    paper_guard_evaluated_trades;
   int    paper_guard_passed_trades;
   int    paper_guard_rejected_trades;
   int    paper_guard_spread_rejected_trades;
   int    paper_guard_stops_rejected_trades;
   int    paper_guard_freeze_rejected_trades;
   int    paper_exposure_evaluated_trades;
   int    paper_exposure_passed_trades;
   int    paper_exposure_blocked_total;
   int    paper_exposure_blocked_engine;
   int    paper_exposure_blocked_direction;
   double paper_guard_before_net_points;
   double paper_guard_after_net_points;
   double paper_guard_impact_points;
   double paper_guard_before_net_usd;
   double paper_guard_after_net_usd;
   double paper_guard_impact_usd;

   // v0.50.0: Paper Runtime Smart SL / Protection Application totals.
   int    paper_protection_evaluated_trades;
   int    paper_protection_eligible_trades;
   int    paper_protection_activated_trades;
   int    paper_tp1_protection_trades;
   int    paper_tp2_protection_trades;
   int    paper_virtual_sl_changed_trades;
   int    paper_virtual_sl_hit_trades;
   int    paper_protected_exit_trades;
   double paper_protection_before_net_points;
   double paper_protection_after_net_points;
   double paper_protection_impact_points;
   double paper_protection_before_net_usd;
   double paper_protection_after_net_usd;
   double paper_protection_impact_usd;
   double paper_protection_giveback_prevented_points;
   double paper_protection_giveback_prevented_usd;

   // v0.51.0: Paper Runtime Runner Application totals.
   int    paper_runner_evaluated_trades;
   int    paper_runner_eligible_trades;
   int    paper_runner_activated_trades;
   int    paper_runner_3r_trades;
   int    paper_moon_mode_5r_trades;
   int    paper_runner_exit_trades;
   int    paper_runner_giveback_trades;
   int    paper_runner_protected_from_loss_trades;
   double paper_runner_before_net_points;
   double paper_runner_after_net_points;
   double paper_runner_impact_points;
   double paper_runner_before_net_usd;
   double paper_runner_after_net_usd;
   double paper_runner_impact_usd;
   double paper_runner_additional_points;
   double paper_runner_additional_usd;

   // v0.55.1: Low-Capital Risk Feasibility Foundation totals.
   int    lotsizing_feasibility_evaluated_trades;
   int    lotsizing_feasibility_feasible_trades;
   int    lotsizing_feasibility_borderline_trades;
   int    lotsizing_feasibility_not_feasible_trades;
   int    lotsizing_feasibility_invalid_trades;
   int    lotsizing_single_trade_cap_breach_trades;
   double lotsizing_min_lot_risk_usd_total;
   double lotsizing_min_lot_risk_usd_max;
   double lotsizing_min_lot_risk_pct_total;
   double lotsizing_min_lot_risk_pct_max;
   double lotsizing_potential_loss_r_total;
   double lotsizing_potential_loss_r_max;

   // v0.55.2: Calibrated Single Trade Loss Cap totals.
   int    single_trade_loss_cap_evaluated_trades;
   int    single_trade_loss_cap_allowed_trades;
   int    single_trade_loss_cap_blocked_trades;
   int    single_trade_loss_cap_invalid_trades;
   int    single_trade_loss_cap_strict_breach_trades;
   int    single_trade_loss_cap_calibrated_breach_trades;
   double single_trade_loss_cap_before_net_points;
   double single_trade_loss_cap_after_net_points;
   double single_trade_loss_cap_impact_points;
   double single_trade_loss_cap_before_net_usd;
   double single_trade_loss_cap_after_net_usd;
   double single_trade_loss_cap_impact_usd;
   double single_trade_loss_cap_rejected_profit_usd;
   double single_trade_loss_cap_rejected_loss_usd;
   double single_trade_loss_cap_calibrated_cap_r_max;
   double single_trade_loss_cap_risk_pct_cap_max;

   // v0.55.2a: Dynamic capital-aware totals.
   double single_trade_loss_cap_dynamic_capital_start;
   double single_trade_loss_cap_dynamic_capital_min;
   double single_trade_loss_cap_dynamic_capital_max;
   double single_trade_loss_cap_dynamic_capital_end;
   double single_trade_loss_cap_dynamic_risk_pct_max;
   double single_trade_loss_cap_dynamic_cap_pct_max;
   int    single_trade_loss_cap_dynamic_capital_updates;
   int    single_trade_loss_cap_dynamic_capital_blocks;

   // v0.55.3: Dynamic LotSizing Model totals.
   int    dynamic_lotsizing_evaluated_trades;
   int    dynamic_lotsizing_fixed_mode_trades;
   int    dynamic_lotsizing_dynamic_mode_trades;
   int    dynamic_lotsizing_candidate_ready_trades;
   int    dynamic_lotsizing_invalid_trades;
   int    dynamic_lotsizing_min_lot_floor_trades;
   int    dynamic_lotsizing_max_lot_cap_trades;
   int    dynamic_lotsizing_tier_cap_trades;
   int    dynamic_lotsizing_capital_cap_trades;
   int    dynamic_lotsizing_growth_ramp_trades;
   double dynamic_lotsizing_safety_active_lot_max;
   double dynamic_lotsizing_raw_lot_total;
   double dynamic_lotsizing_recommended_lot_total;
   double dynamic_lotsizing_active_lot_total;
   double dynamic_lotsizing_recommended_risk_pct_max;
   double dynamic_lotsizing_active_risk_pct_max;

   // v0.53.1: Three-Layer Emergency active replacement totals.
   int    paper_emergency_evaluated_trades;
   int    paper_emergency_safe_trades;
   int    paper_emergency_triggered_trades;
   int    paper_emergency_blocked_entries;
   int    paper_emergency_layer1_triggers;
   int    paper_emergency_layer2_triggers;
   int    paper_emergency_layer3_triggers;
   double paper_emergency_before_net_points;
   double paper_emergency_after_net_points;
   double paper_emergency_impact_points;
   double paper_emergency_before_net_usd;
   double paper_emergency_after_net_usd;
   double paper_emergency_impact_usd;
   double paper_emergency_max_drawdown_pct;
   double paper_emergency_worst_daily_r;

   // v0.53.2: Layer-specific reset validation totals.
   int    layer_reset_evaluated_trades;
   int    layer1_reset_on_win_events;
   int    layer2_reset_on_new_day_events;
   int    layer3_reset_on_new_peak_events;
   int    layer_reset_event_trades;
   int    layer_reset_duplicate_triggers;

   // v0.57.0: Lock Parity Executability Decomposer rollup totals.
   // Report-only; never mutates trade values.
   int    lock_parity_evaluated_trades;
   int    lock_parity_decomposition_pass_trades;
   int    lock_parity_decomposition_breach_trades;
   double lock_parity_raw_net_usd;
   double lock_parity_final_working_net_usd;
   double lock_parity_sum_guard_delta_usd;
   double lock_parity_sum_protection_delta_usd;
   double lock_parity_sum_runner_delta_usd;
   double lock_parity_sum_losscap_delta_usd;
   double lock_parity_sum_marketclose_delta_usd;
   double lock_parity_sum_emergency_delta_usd;
   double lock_parity_sum_other_delta_usd;
   double lock_parity_executable_adjustment_usd;
   double lock_parity_non_executable_adjustment_usd;
   double lock_parity_protection_executable_usd;
   double lock_parity_runner_pending_usd;
   // v0.57.1: Runner Exit Price Probe buckets.
   double lock_parity_runner_executable_usd;
   double lock_parity_runner_non_executable_usd;
   double lock_parity_accounting_only_usd;
};

// --- FalconRunnerBarPathStats (main .mq5 lines 3658-3676) ---
struct FalconRunnerBarPathStats
{
   bool   scan_ok;
   int    bars_scanned;
   bool   tp1_touched;
   bool   tp2_touched;
   bool   tp1_touched_then_extended;
   bool   tp2_touched_then_extended;
   double tp1_to_max_run_points;
   double tp2_to_max_run_points;
   double max_favorable_points;
   double mfe_after_tp1_points;
   double mfe_after_tp2_points;
   double giveback_after_tp1_points;
   double giveback_after_tp2_points;
   bool   returned_to_loss_after_tp1;
   bool   returned_to_loss_after_tp2;
   double max_r_actual_proxy;
};

#endif // FALCON_DATASTRUCTURES_MQH
