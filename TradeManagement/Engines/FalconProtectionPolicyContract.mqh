//+------------------------------------------------------------------+
//| TradeManagement/Engines/FalconProtectionPolicyContract.mqh       |
//| R1.5a - Phase 3a: the protection-policy contract.                |
//|                                                                  |
//| Abstract, swappable protection-policy interface. A policy reads  |
//| one broker-side managed-position context (the same broker-truth  |
//| context the 2b coordinator builds) and returns either a          |
//| FALCON_TM_MODIFY_SL decision with a computed new_sl, or          |
//| FALCON_TM_NO_ACTION. Future protection policies (structural,     |
//| adaptive) join HERE - they implement this interface and the      |
//| ProofProtectionEngine takes them via injection, without the      |
//| engine or the coordinator changing.                              |
//|                                                                  |
//| Only the contract lives here - no policy logic.                  |
//+------------------------------------------------------------------+
#ifndef FALCON_PROTECTION_POLICY_CONTRACT_MQH
#define FALCON_PROTECTION_POLICY_CONTRACT_MQH

#include "../FalconTradeEngineContract.mqh"

// Abstract protection policy. Every concrete protection rule
// (FixedRMultiple now; StructuralSwing / Adaptive later) implements it.
class CFalconProtectionPolicy
{
public:
   virtual string              PolicyId() = 0;
   virtual FalconTradeDecision EvaluateProtection(const FalconManagedPositionContext &ctx) = 0;
};

#endif // FALCON_PROTECTION_POLICY_CONTRACT_MQH
