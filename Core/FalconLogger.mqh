//+------------------------------------------------------------------+
//| Core/FalconLogger.mqh                                            |
//| R0.2: CFalconLogger moved verbatim from the main .mq5            |
//| (lines 5172-5193). Uses EA_NAME and EA_VERSION_TAG from          |
//| FalconConstants.mqh.                                             |
//+------------------------------------------------------------------+
#ifndef FALCON_LOGGER_MQH
#define FALCON_LOGGER_MQH

// ==================================================================
// Logger
// ==================================================================
class CFalconLogger
{
public:
   static void Info(const string message)
   {
      if(EnableVerboseExpertsLog)
         PrintFormat("[%s][%s][INFO] %s", EA_NAME, EA_VERSION_TAG, message);
   }

   static void Warn(const string message)
   {
      PrintFormat("[%s][%s][WARN] %s", EA_NAME, EA_VERSION_TAG, message);
   }

   static void Error(const string message)
   {
      PrintFormat("[%s][%s][ERROR] %s", EA_NAME, EA_VERSION_TAG, message);
   }
};

#endif // FALCON_LOGGER_MQH
