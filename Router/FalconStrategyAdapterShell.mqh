//+------------------------------------------------------------------+
//| Router/FalconStrategyAdapterShell.mqh                            |
//| R0.5: verbatim move of CFalconFirstShadowStrategyAdapterShell    |
//| from main .mq5. Depends on:                                      |
//|   - Core (DataStructures, Enums, Logger)                         |
//|   - Router/FalconStrategyRegistry.mqh (must be included first)   |
//|   - Execution/FalconRuntimeSafetyGuard.mqh                       |
//|   - Execution/FalconShadowExecutor.mqh                           |
//|   - input EnableShadowMode + helper FalconAdapterStatusToString  |
//|     (declared further down in main .mq5; MQL5 two-pass parse     |
//|     resolves them at method-body compile time).                  |
//+------------------------------------------------------------------+
#ifndef FALCON_ROUTER_STRATEGY_ADAPTER_SHELL_MQH
#define FALCON_ROUTER_STRATEGY_ADAPTER_SHELL_MQH

// ==================================================================
// First Shadow Strategy Adapter Shell - v0.13.1
// This adapter proves that a registered strategy can be discovered and
// evaluated for future Shadow staging without running any detector.
// It intentionally produces NO_TRADE / BLOCKED candidate diagnostics only.
// ==================================================================
class CFalconFirstShadowStrategyAdapterShell
{
private:
   FalconStrategyAdapterSnapshot m_snapshot;
   bool                          m_initialized;

public:
   CFalconFirstShadowStrategyAdapterShell()
   {
      ResetSnapshot();
      m_initialized = false;
   }

   bool Initialize(CFalconStrategyRegistry &registry,
                   CFalconRuntimeSafetyGuard &runtime_guard,
                   CFalconShadowExecutor &shadow_executor)
   {
      ResetSnapshot();
      m_snapshot.adapter_id         = "ADAPTER_SHELL_FVG_MICRO_RETEST_v0_10_1";
      m_snapshot.target_strategy_id = "FVG_MICRO_RETEST";
      m_snapshot.runtime_safety_ready = runtime_guard.IsInitialized();
      m_snapshot.shadow_executor_ready = shadow_executor.IsInitialized();
      m_snapshot.order_send_used = false;
      m_snapshot.live_allowed = false;

      FalconStrategyRegistryEntry entry;
      if(!registry.GetEntryById(m_snapshot.target_strategy_id, entry))
      {
         m_snapshot.registry_found = false;
         m_snapshot.adapter_status = FALCON_ADAPTER_STATUS_NO_TRADE;
         m_snapshot.no_trade_reason = "REGISTRY_ENTRY_NOT_FOUND";
         m_snapshot.safety_reason = "ADAPTER_DID_NOT_BUILD_TRADEPLAN";
         m_snapshot.notes = "First adapter shell could not find the target strategy. No staging attempted.";
         m_initialized = true;
         return true;
      }

      m_snapshot.registry_found     = true;
      m_snapshot.strategy_name      = entry.strategy_name;
      m_snapshot.engine_id          = entry.engine_id;
      m_snapshot.strategy_group     = entry.strategy_group;
      m_snapshot.health_status      = entry.health_status;
      m_snapshot.max_allowed_stage  = entry.max_allowed_stage;
      m_snapshot.input_enabled      = entry.input_enabled;
      m_snapshot.shadow_allowed     = entry.shadow_allowed;
      m_snapshot.live_allowed       = false;
      m_snapshot.candidate_requested = (entry.input_enabled && entry.shadow_allowed && EnableShadowMode);
      m_snapshot.candidate_staged    = false;

      if(!m_snapshot.runtime_safety_ready)
      {
         m_snapshot.adapter_status  = FALCON_ADAPTER_STATUS_SHADOW_CANDIDATE_BLOCKED;
         m_snapshot.no_trade_reason = "RUNTIME_SAFETY_NOT_READY";
         m_snapshot.safety_reason   = "NO_LOOKAHEAD_GUARD_REQUIRED_BEFORE_SHADOW_STAGING";
      }
      else if(!m_snapshot.shadow_executor_ready)
      {
         m_snapshot.adapter_status  = FALCON_ADAPTER_STATUS_SHADOW_CANDIDATE_BLOCKED;
         m_snapshot.no_trade_reason = "SHADOW_EXECUTOR_NOT_READY";
         m_snapshot.safety_reason   = "ENABLE_SHADOW_MODE_REQUIRED_FOR_FUTURE_STAGING";
      }
      else if(m_snapshot.candidate_requested)
      {
         m_snapshot.adapter_status  = FALCON_ADAPTER_STATUS_SHADOW_CANDIDATE_BLOCKED;
         m_snapshot.no_trade_reason = "ADAPTER_SHELL_NO_DETECTOR_YET";
         m_snapshot.safety_reason   = "NO_TRADEPLAN_CREATED_IN_v0_12_0";
      }
      else
      {
         m_snapshot.adapter_status  = FALCON_ADAPTER_STATUS_NO_TRADE;
         m_snapshot.no_trade_reason = (entry.input_enabled ? "SHADOW_NOT_REQUESTED_OR_NOT_ALLOWED" : "STRATEGY_INPUT_DISABLED");
         m_snapshot.safety_reason   = "ADAPTER_SHELL_OBSERVE_ONLY";
      }

      m_snapshot.notes = "v0.13.1 adapter shell only. Registry linked to Shadow Executor, but no detector, no signal, no trade plan, and no staging.";
      m_initialized = true;

      CFalconLogger::Info(StringFormat("FirstStrategyAdapterShell initialized. Strategy=%s | InputEnabled=%s | Status=%s | Reason=%s",
                                       m_snapshot.target_strategy_id,
                                       (m_snapshot.input_enabled ? "true" : "false"),
                                       FalconAdapterStatusToString(m_snapshot.adapter_status),
                                       m_snapshot.no_trade_reason));
      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   FalconStrategyAdapterSnapshot GetSnapshot()
   {
      return m_snapshot;
   }

private:
   void ResetSnapshot()
   {
      m_snapshot.adapter_id            = "";
      m_snapshot.target_strategy_id    = "";
      m_snapshot.strategy_name         = "";
      m_snapshot.engine_id             = "";
      m_snapshot.strategy_group        = FALCON_STRATEGY_GROUP_RESEARCH;
      m_snapshot.health_status         = FALCON_ENGINE_HEALTH_DISABLED;
      m_snapshot.max_allowed_stage     = FALCON_ENGINE_DISABLED;
      m_snapshot.adapter_status        = FALCON_ADAPTER_STATUS_NOT_INITIALIZED;
      m_snapshot.registry_found        = false;
      m_snapshot.input_enabled         = false;
      m_snapshot.shadow_allowed        = false;
      m_snapshot.shadow_executor_ready = false;
      m_snapshot.runtime_safety_ready  = false;
      m_snapshot.candidate_requested   = false;
      m_snapshot.candidate_staged      = false;
      m_snapshot.live_allowed          = false;
      m_snapshot.order_send_used       = false;
      m_snapshot.no_trade_reason       = "";
      m_snapshot.safety_reason         = "";
      m_snapshot.notes                 = "";
   }
};

#endif // FALCON_ROUTER_STRATEGY_ADAPTER_SHELL_MQH
