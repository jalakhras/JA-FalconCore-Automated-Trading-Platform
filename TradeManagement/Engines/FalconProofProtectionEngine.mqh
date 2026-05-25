//+------------------------------------------------------------------+
//| TradeManagement/Engines/FalconProofProtectionEngine.mqh          |
//| R1.5a - Phase 3a: the first real trade-management engine.        |
//|                                                                  |
//| A thin engine: it owns no protection maths. It holds an injected |
//| CFalconProtectionPolicy and forwards Evaluate() to the policy's  |
//| EvaluateProtection(). Swapping the protection rule (FixedRMultiple|
//| -> StructuralSwing -> Adaptive, later) is a policy change only;   |
//| this engine and the coordinator stay put.                        |
//|                                                                  |
//| EngineId = "PROOF_PROTECTION". The decision it returns is applied |
//| for real by the coordinator's MODIFY_SL apply path.              |
//+------------------------------------------------------------------+
#ifndef FALCON_PROOF_PROTECTION_ENGINE_MQH
#define FALCON_PROOF_PROTECTION_ENGINE_MQH

#include "FalconProtectionPolicyContract.mqh"
#include "FalconFixedRMultipleProtection.mqh"

class CFalconProofProtectionEngine : public CFalconTradeEngine
{
private:
   CFalconProtectionPolicy *m_policy;

public:
   CFalconProofProtectionEngine(CFalconProtectionPolicy *policy) { m_policy = policy; }

   virtual string EngineId() { return "PROOF_PROTECTION"; }

   virtual FalconTradeDecision Evaluate(const FalconManagedPositionContext &ctx)
   {
      if(m_policy == NULL)
      {
         FalconTradeDecision d;
         d.action         = FALCON_TM_NO_ACTION;
         d.new_sl         = 0.0;
         d.close_fraction = 0.0;
         d.reason         = "no protection policy injected";
         return d;
      }
      return m_policy.EvaluateProtection(ctx);
   }
};

// One policy instance, and the engine instance bound to it. The policy is
// declared first so its address is valid when injected into the engine.
CFalconFixedRMultipleProtection g_fixed_r_multiple_protection_policy;
CFalconProofProtectionEngine    g_proof_protection_engine(GetPointer(g_fixed_r_multiple_protection_policy));

#endif // FALCON_PROOF_PROTECTION_ENGINE_MQH
