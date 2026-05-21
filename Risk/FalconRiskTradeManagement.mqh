//+------------------------------------------------------------------+
//| Risk/FalconRiskTradeManagement.mqh                               |
//| R0.3: CFalconRiskTradeManagementArchitecture moved verbatim      |
//| from main .mq5 (lines 12860-12921). Uses 17 FALCON_*_STATUS      |
//| macros from FalconRiskInputs.mqh - include AFTER that file.      |
//| Also calls FalconV055ArchitectureConsolidationContractReady()    |
//| which is link-resolved (function stays in main .mq5).            |
//+------------------------------------------------------------------+
#ifndef FALCON_RISK_TRADEMANAGEMENT_MQH
#define FALCON_RISK_TRADEMANAGEMENT_MQH

class CFalconRiskTradeManagementArchitecture
{
private:
   bool m_initialized;
   bool m_contract_ready;

public:
   CFalconRiskTradeManagementArchitecture()
   {
      m_initialized = false;
      m_contract_ready = false;
   }

   bool Initialize()
   {
      m_contract_ready = FalconV055ArchitectureConsolidationContractReady();
      m_initialized = true;
      return m_contract_ready;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   bool IsContractReady()
   {
      return m_contract_ready;
   }

   string RiskOwnershipMap()
   {
      return "RiskManager=" + FALCON_RISK_MANAGER_STATUS +
             ";LotSizingManager=" + FALCON_LOT_SIZING_MANAGER_STATUS +
             ";DailyGovernance=" + FALCON_DAILY_GOVERNANCE_STATUS +
             ";EngineRiskAllocation=" + FALCON_ENGINE_RISK_ALLOCATION_STATUS +
             ";KillSwitch=" + FALCON_KILL_SWITCH_STATUS_V055;
   }

   string TradeManagementOwnershipMap()
   {
      return "StructuralStopEngine=" + FALCON_STRUCTURAL_STOP_ENGINE_STATUS +
             ";TPBuilder=" + FALCON_TP_BUILDER_STATUS_V055 +
             ";PartialManager=" + FALCON_PARTIAL_MANAGER_STATUS_V055 +
             ";ProofProtectionEngine=" + FALCON_PROOF_PROTECTION_ENGINE_STATUS +
             ";RunnerManager=" + FALCON_RUNNER_MANAGER_STATUS_V055 +
             ";AdaptiveRatchetEngine=" + FALCON_ADAPTIVE_RATCHET_ENGINE_STATUS +
             ";EarlyFailureExitEngine=" + FALCON_EARLY_FAILURE_EXIT_ENGINE_STATUS;
   }

   void PrintState()
   {
      CFalconLogger::Info(StringFormat("v0.55.0 Architecture Consolidation | Status=%s | Decision=%s | ContractReady=%d | RuntimeEnforced=%d",
                                       FALCON_ARCH_STATUS,
                                       FALCON_ARCH_DECISION,
                                       (m_contract_ready ? 1 : 0),
                                       (FALCON_ARCH_RUNTIME_ENFORCED ? 1 : 0)));
      CFalconLogger::Info("v0.55.0 Risk ownership map: " + RiskOwnershipMap());
      CFalconLogger::Info("v0.55.0 TradeManagement ownership map: " + TradeManagementOwnershipMap());
      CFalconLogger::Info("v0.55.0 Behavior policy: " + FALCON_ARCH_POLICY + " | " + FALCON_ARCH_ORDER_SEND_POLICY);
   }
};

#endif // FALCON_RISK_TRADEMANAGEMENT_MQH
