//+------------------------------------------------------------------+
//| TradeManagement/FalconNoOpProbeEngine.mqh                        |
//| R1.4b - Phase 2b: the no-op probe engine.                        |
//|                                                                  |
//| Registered in the coordinator to prove the wiring works end to   |
//| end (register -> call -> build context -> return decision)       |
//| WITHOUT changing any behaviour. Always returns NO_ACTION, so the |
//| broker result with the coordinator ON equals the result with it  |
//| OFF, literally. No internal state.                               |
//+------------------------------------------------------------------+
#ifndef FALCON_NOOP_PROBE_ENGINE_MQH
#define FALCON_NOOP_PROBE_ENGINE_MQH

#include "FalconTradeEngineContract.mqh"

class CFalconNoOpProbeEngine : public CFalconTradeEngine
{
public:
   virtual string EngineId() { return "NOOP_PROBE"; }

   virtual FalconTradeDecision Evaluate(const FalconManagedPositionContext &ctx)
   {
      FalconTradeDecision decision;
      decision.action         = FALCON_TM_NO_ACTION;
      decision.new_sl         = 0.0;
      decision.close_fraction = 0.0;
      decision.reason         = "noop probe - no management logic";
      return decision;
   }
};

CFalconNoOpProbeEngine g_noop_probe_engine;

#endif // FALCON_NOOP_PROBE_ENGINE_MQH
