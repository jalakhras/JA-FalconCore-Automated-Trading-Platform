//+------------------------------------------------------------------+
//| TradeManagement/FalconTradeManagementInputs.mqh                  |
//| R1.4b - Phase 2b: trade-management coordinator inputs.           |
//+------------------------------------------------------------------+
#ifndef FALCON_TRADE_MANAGEMENT_INPUTS_MQH
#define FALCON_TRADE_MANAGEMENT_INPUTS_MQH
// ==================================================================
// ==================================================================
// R1.4b -  Trade-management coordinator
// ==================================================================
input group "R1.4b -  Trade-management coordinator";
input bool Enable_TradeManagement     = false;  // activates the live trade-management coordinator
input bool TradeManagement_DiagReport = false;  // writes the coordinator audit CSV

// ==================================================================
// Protection engine
// ==================================================================
input group "Protection engine";
input bool   Enable_S01_Protection       = false;  // activates the protection engine for the harness
input double Protection_TriggerRMultiple = 1.0;    // arms the stop move once unrealised profit reaches this multiple of risk
input int    Protection_StopOffsetPoints = 0;      // stop placement relative to entry; positive locks a small loss, negative locks a small profit

#endif // FALCON_TRADE_MANAGEMENT_INPUTS_MQH
