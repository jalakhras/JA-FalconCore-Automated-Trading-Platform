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

#endif // FALCON_TRADE_MANAGEMENT_INPUTS_MQH
