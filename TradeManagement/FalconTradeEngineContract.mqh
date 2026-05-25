//+------------------------------------------------------------------+
//| TradeManagement/FalconTradeEngineContract.mqh                    |
//| R1.4b - Phase 2b: the trade-management engine contract.          |
//|                                                                  |
//| The shared interface every Phase-3 management engine (protection |
//| / runner / partial / ratchet / early-exit) and the 10+ strategy  |
//| engines will inherit. Broker-side ONLY (per the PaperBrokerGap   |
//| ruling): the context is built from real broker position state,   |
//| never from paper lifecycle fields.                               |
//|                                                                  |
//| No engine logic lives here - only the contract. Phase 2b emits   |
//| FALCON_TM_NO_ACTION exclusively; the rest of the action space is  |
//| declared now so the contract does not change when Phase-3 engines |
//| land.                                                            |
//+------------------------------------------------------------------+
#ifndef FALCON_TRADE_ENGINE_CONTRACT_MQH
#define FALCON_TRADE_ENGINE_CONTRACT_MQH

// Full decision space. Phase 2b uses NO_ACTION only; the rest are
// declared up front so adding Phase-3 engines never breaks the contract.
enum ENUM_FALCON_TM_ACTION
{
   FALCON_TM_NO_ACTION     = 0,
   FALCON_TM_MODIFY_SL     = 1,
   FALCON_TM_CLOSE         = 2,
   FALCON_TM_PARTIAL_CLOSE = 3
};

// Context for one open broker position, built from real broker state.
// No paper fields - the contract is broker-side by design.
struct FalconManagedPositionContext
{
   ulong                 position_ticket;
   string                strategy_id;
   ENUM_FALCON_DIRECTION direction;
   double                broker_entry_price;
   double                current_sl;
   double                current_tp;
   double                volume;
   double                current_bid;
   double                current_ask;
   double                broker_unrealized_usd;
   int                   bars_since_entry;
   datetime              closed_bar_time;
};

// One engine's decision for one position. Phase 2b fills NO_ACTION only.
struct FalconTradeDecision
{
   ENUM_FALCON_TM_ACTION action;
   double                new_sl;
   double                close_fraction;
   string                reason;
};

// Abstract engine interface. Every management engine implements it.
class CFalconTradeEngine
{
public:
   virtual string              EngineId() = 0;
   virtual FalconTradeDecision Evaluate(const FalconManagedPositionContext &ctx) = 0;
};

// Audit / human-readable form of a decision action.
string FalconTmActionToString(const ENUM_FALCON_TM_ACTION action)
{
   switch(action)
   {
      case FALCON_TM_NO_ACTION:     return "FALCON_TM_NO_ACTION";
      case FALCON_TM_MODIFY_SL:     return "FALCON_TM_MODIFY_SL";
      case FALCON_TM_CLOSE:         return "FALCON_TM_CLOSE";
      case FALCON_TM_PARTIAL_CLOSE: return "FALCON_TM_PARTIAL_CLOSE";
   }
   return "UNKNOWN";
}

#endif // FALCON_TRADE_ENGINE_CONTRACT_MQH
