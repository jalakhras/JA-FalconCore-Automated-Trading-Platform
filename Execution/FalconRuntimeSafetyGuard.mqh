//+------------------------------------------------------------------+
//| Execution/FalconRuntimeSafetyGuard.mqh                           |
//| R0.4: CFalconRuntimeSafetyGuard moved verbatim from main .mq5    |
//| (L4435-4616). No-lookahead enforcement layer; uses Core enums    |
//| only (FALCON_DIRECTION_*, FALCON_LOOKAHEAD_RISK_*,               |
//| FALCON_RUNTIME_SAFETY_*).                                        |
//+------------------------------------------------------------------+
#ifndef FALCON_RUNTIME_SAFETY_GUARD_MQH
#define FALCON_RUNTIME_SAFETY_GUARD_MQH

// ==================================================================
// No-Lookahead Runtime Guard & Strategy Staging Safety - v0.13.1
// This layer blocks current-candle/final-state dependency before any future
// strategy can stage Shadow/Paper/Demo plans. It does not create signals.
// ==================================================================
class CFalconRuntimeSafetyGuard
{
private:
   FalconRuntimeSafetyCheck m_checks[4];
   int                      m_check_count;
   bool                     m_initialized;

public:
   CFalconRuntimeSafetyGuard()
   {
      m_check_count = 0;
      m_initialized = false;
   }

   bool Initialize(CFalconCandleCache &cache)
   {
      m_check_count = 0;
      FalconCandleSnapshot primary_m5;
      const bool has_m5 = cache.GetSnapshotByTimeframe(PERIOD_M5, primary_m5);

      FalconRuntimeSafetyCheck closed_candle_check;
      ResetCheck(closed_candle_check);
      closed_candle_check.check_id               = "NLA_CLOSED_CANDLE";
      closed_candle_check.check_name             = "Closed Candle Decision Guard";
      closed_candle_check.timeframe              = PERIOD_M5;
      closed_candle_check.source_shift           = (has_m5 ? primary_m5.source_shift : -1);
      closed_candle_check.used_closed_candle     = (has_m5 && primary_m5.is_closed && primary_m5.source_shift > 0);
      closed_candle_check.current_candle_blocked = true;
      closed_candle_check.final_state_blocked    = true;
      closed_candle_check.staging_allowed        = closed_candle_check.used_closed_candle;
      closed_candle_check.status                 = (closed_candle_check.staging_allowed ? FALCON_RUNTIME_SAFETY_PASSED : FALCON_RUNTIME_SAFETY_REJECTED);
      closed_candle_check.risk_type              = (closed_candle_check.staging_allowed ? FALCON_LOOKAHEAD_RISK_NONE : FALCON_LOOKAHEAD_RISK_CURRENT_CANDLE);
      closed_candle_check.notes                  = "Future strategies must use prior closed candle snapshots for decisions. Current candle is blocked from decision state.";
      AddCheck(closed_candle_check);

      FalconRuntimeSafetyCheck final_state_check;
      ResetCheck(final_state_check);
      final_state_check.check_id               = "NLA_FINAL_STATE";
      final_state_check.check_name             = "No Final-State Dependency";
      final_state_check.timeframe              = PERIOD_CURRENT;
      final_state_check.source_shift           = -1;
      final_state_check.used_closed_candle     = true;
      final_state_check.current_candle_blocked = true;
      final_state_check.final_state_blocked    = true;
      final_state_check.staging_allowed        = true;
      final_state_check.status                 = FALCON_RUNTIME_SAFETY_PASSED;
      final_state_check.risk_type              = FALCON_LOOKAHEAD_RISK_NONE;
      final_state_check.notes                  = "Runtime candidate cannot rely on final trade path, final bar high/low order, or future exit-state tags.";
      AddCheck(final_state_check);

      FalconRuntimeSafetyCheck staging_check;
      ResetCheck(staging_check);
      staging_check.check_id               = "NLA_STAGE_SAFETY";
      staging_check.check_name             = "Strategy Staging Safety Contract";
      staging_check.timeframe              = PERIOD_CURRENT;
      staging_check.source_shift           = -1;
      staging_check.used_closed_candle     = true;
      staging_check.current_candle_blocked = true;
      staging_check.final_state_blocked    = true;
      staging_check.staging_allowed        = true;
      staging_check.status                 = FALCON_RUNTIME_SAFETY_PASSED;
      staging_check.risk_type              = FALCON_LOOKAHEAD_RISK_NONE;
      staging_check.notes                  = "Future strategy plans must pass ValidateTradePlanForStaging before Shadow/Paper/Demo staging.";
      AddCheck(staging_check);

      m_initialized = AllChecksPassed();
      if(m_initialized)
         CFalconLogger::Info(StringFormat("RuntimeSafetyGuard initialized. Checks=%d | Status=PASSED | NoLookahead=true", m_check_count));
      else
         CFalconLogger::Error(StringFormat("RuntimeSafetyGuard failed. Checks=%d | Status=REJECTED", m_check_count));

      return m_initialized;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   int Count()
   {
      return m_check_count;
   }

   bool GetCheckByIndex(const int index, FalconRuntimeSafetyCheck &check)
   {
      if(index < 0 || index >= m_check_count)
         return false;
      check = m_checks[index];
      return true;
   }

   bool ValidateCandleSnapshotForDecision(const FalconCandleSnapshot &snapshot, string &reject_reason)
   {
      reject_reason = "";
      if(!snapshot.is_valid)
      {
         reject_reason = "INVALID_CANDLE_SNAPSHOT";
         return false;
      }

      if(UseClosedCandlesOnly && (!snapshot.is_closed || snapshot.source_shift <= 0))
      {
         reject_reason = "CURRENT_CANDLE_DECISION_BLOCKED";
         return false;
      }

      return true;
   }

   bool ValidateTradePlanForStaging(const FalconTradePlan &plan, string &reject_reason)
   {
      reject_reason = "";
      if(!m_initialized)
      {
         reject_reason = "RUNTIME_SAFETY_GUARD_NOT_INITIALIZED";
         return false;
      }

      if(plan.strategy_id == "" || plan.strategy_name == "" || plan.engine_id == "")
      {
         reject_reason = "TRADEPLAN_MISSING_IDENTITY";
         return false;
      }

      if(plan.direction != FALCON_DIRECTION_BUY && plan.direction != FALCON_DIRECTION_SELL)
      {
         reject_reason = "TRADEPLAN_INVALID_DIRECTION";
         return false;
      }

      if(plan.lot_size <= 0.0 || plan.entry_price <= 0.0 || plan.structural_sl <= 0.0)
      {
         reject_reason = "TRADEPLAN_INVALID_PRICE_OR_LOT";
         return false;
      }

      return true;
   }

private:
   void ResetCheck(FalconRuntimeSafetyCheck &check)
   {
      check.check_id               = "";
      check.check_name             = "";
      check.status                 = FALCON_RUNTIME_SAFETY_NOT_EVALUATED;
      check.risk_type              = FALCON_LOOKAHEAD_RISK_NONE;
      check.timeframe              = PERIOD_CURRENT;
      check.source_shift           = -1;
      check.used_closed_candle     = false;
      check.current_candle_blocked = false;
      check.final_state_blocked    = false;
      check.staging_allowed        = false;
      check.notes                  = "";
   }

   void AddCheck(const FalconRuntimeSafetyCheck &check)
   {
      if(m_check_count >= 4)
         return;
      m_checks[m_check_count] = check;
      m_check_count++;
   }

   bool AllChecksPassed()
   {
      if(m_check_count <= 0)
         return false;

      for(int i = 0; i < m_check_count; i++)
      {
         if(m_checks[i].status != FALCON_RUNTIME_SAFETY_PASSED)
            return false;
      }
      return true;
   }
};

#endif // FALCON_RUNTIME_SAFETY_GUARD_MQH
