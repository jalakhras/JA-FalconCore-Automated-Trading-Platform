//+------------------------------------------------------------------+
//| Risk/FalconRiskFoundation.mqh                                    |
//| R0.3: CFalconRiskFoundation moved verbatim from main .mq5        |
//| (lines 4075-4144). Validates inputs (EnableRealExecution,        |
//| FixedLotSize, MaxTradesPerDay, etc.) - input refs link-resolve   |
//| at compile time.                                                 |
//+------------------------------------------------------------------+
#ifndef FALCON_RISK_FOUNDATION_MQH
#define FALCON_RISK_FOUNDATION_MQH

// ==================================================================
// Risk Foundation - validates only. No lot calculations yet.
// ==================================================================
class CFalconRiskFoundation
{
public:
   bool ValidateInputs(const FalconSymbolContext &symbol_context)
   {
      // v0.56.4: EnableRealExecution=true is allowed only for the MT5 Strategy Tester
      // Atomic Entry+Exit validation lane. Demo/Live remain blocked here before
      // initialization continues, while still preserving the central execution safety switch.
      if(EnableRealExecution && !MQLInfoInteger(MQL_TESTER))
      {
         CFalconLogger::Error("HARD SAFETY BLOCK: EnableRealExecution=true is allowed only inside MT5 Strategy Tester in v0.56.4b. Demo/Live remain blocked.");
         return false;
      }

      if(!EnableShadowMode && !EnablePaperMode)
      {
         CFalconLogger::Warn("Both ShadowMode and PaperMode are disabled. EA will only load and stay idle.");
      }

      if(UseFixedLot)
      {
         if(FixedLotSize <= 0.0)
         {
            CFalconLogger::Error("FixedLotSize must be greater than zero.");
            return false;
         }

         if(FixedLotSize < symbol_context.min_lot || FixedLotSize > symbol_context.max_lot)
         {
            CFalconLogger::Error(StringFormat("FixedLotSize %.2f is outside broker limits [%.2f - %.2f].",
                                             FixedLotSize,
                                             symbol_context.min_lot,
                                             symbol_context.max_lot));
            return false;
         }
      }

      if(!UseAutoCapitalDetection && ManualCapital <= 0.0)
      {
         CFalconLogger::Error("ManualCapital must be greater than zero when UseAutoCapitalDetection=false.");
         return false;
      }

      if(UseDailyLossLimit)
      {
         if(UseFixedDailyLossAmount && FixedDailyLossAmount <= 0.0)
         {
            CFalconLogger::Error("FixedDailyLossAmount must be greater than zero.");
            return false;
         }

         if(!UseFixedDailyLossAmount && (DailyLossPercentOfCapital <= 0.0 || DailyLossPercentOfCapital > 100.0))
         {
            CFalconLogger::Error("DailyLossPercentOfCapital must be between 0 and 100.");
            return false;
         }
      }

      if(MaxTradesPerDay < 0 || MaxOpenPositions < 0)
      {
         CFalconLogger::Error("MaxTradesPerDay and MaxOpenPositions cannot be negative.");
         return false;
      }

      return true;
   }
};

#endif // FALCON_RISK_FOUNDATION_MQH
