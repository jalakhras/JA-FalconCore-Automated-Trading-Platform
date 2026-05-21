//+------------------------------------------------------------------+
//| Execution/FalconExecutionGuard.mqh                               |
//| R0.4: CFalconExecutionGuard moved verbatim from main .mq5        |
//| (L12645-12661). Zero dependencies on ReportWriter or other       |
//| Execution classes.                                               |
//+------------------------------------------------------------------+
#ifndef FALCON_EXECUTION_GUARD_MQH
#define FALCON_EXECUTION_GUARD_MQH

// ==================================================================
// Execution Guard - real trading intentionally impossible in v0.18.1.
// ==================================================================
class CFalconExecutionGuard
{
public:
   bool CanSendRealOrders()
   {
      // v0.25.1 can block FVG Micro Shadow staging by SIZE250, but real broker execution remains impossible.
      return false;
   }

   void AssertNoExecution()
   {
      CFalconLogger::Info("ExecutionGuard active: Demo/Live, BrokerModify, and runtime SL changes remain blocked in v0.56.9b. Tester-only broker OrderSend requires mandatory server SL/TP and EA-side managed close is allowed only through the guarded broker bridge when EnableRealExecution=true inside MT5 Strategy Tester.");
   }
};

#endif // FALCON_EXECUTION_GUARD_MQH
