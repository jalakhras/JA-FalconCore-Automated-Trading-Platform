//+------------------------------------------------------------------+
//|                     JA_FalconCore_Automated_Trading_Platform.mq5 |
//|                     JA FalconCore Automated Trading Platform      |
//|                     Version: v0.4.0 - Evidence Framework Foundation |
//+------------------------------------------------------------------+
#property copyright "JA FalconCore Automated Trading Platform"
#property version   "1.040"
#property strict

#define EA_NAME        "JA FalconCore Automated Trading Platform"
#define EA_VERSION_TAG "v0.4.0"
#define EA_BUILD_TAG   "EvidenceFrameworkFoundation_NoExecution"

#define FALCON_MTF_COUNT       6

// ==================================================================
// 01 - EA Safety & Risk / إعدادات المستخدم الأساسية
// ==================================================================
input group "01 - EA Safety & Risk / إعدادات المستخدم الأساسية";
input bool   EnableRealExecution             = false; // HARD SAFETY: remains false during shadow/candidate stages.
input bool   UseFixedLot                     = true;  // simple user mode: fixed lot first.
input double FixedLotSize                    = 0.01;
input bool   UseAutoCapitalDetection         = true;  // true = use account balance later; false = ManualCapital.
input double ManualCapital                   = 10000.0;
input bool   UseDailyLossLimit               = true;
input bool   UseFixedDailyLossAmount         = false;
input double FixedDailyLossAmount            = 100.0;
input double DailyLossPercentOfCapital       = 3.0;

// ==================================================================
// 02 - Execution Stage / مرحلة التنفيذ
// ==================================================================
input group "02 - Execution Stage / مرحلة التنفيذ";
input bool   EnableShadowMode                = true;  // Observe only. No real orders.
input bool   EnablePaperMode                 = false; // Internal simulated trades later.
input int    FalconMagicNumber               = 20260001;
input int    MaxTradesPerDay                 = 3;
input int    MaxOpenPositions                = 1;

// ==================================================================
// 03 - Strategy Switches / تفعيل وإيقاف الاستراتيجيات
// Keep this list small and explicit. All engines are OFF in v0.3.0.
// ==================================================================
input group "03 - Strategy Switches / تفعيل وإيقاف الاستراتيجيات";
input bool EnableStrategy_FvgMicroRetest             = false; // Legacy core winner candidate.
input bool EnableStrategy_TailSmartReturn            = false; // استراتيجية ذيل العودة الذكي.
input bool EnableStrategy_MomentumCross820           = false; // استراتيجية تقاطع الزخم 8/20.
input bool EnableStrategy_CheckMarkLiquiditySweep    = false; // استراتيجية علامة الصح بعد سحب السيولة.
input bool EnableStrategy_DoubleBoxWickConfirmation  = false; // استراتيجية الصندوقين والشمعة الحاسمة.
input bool EnableStrategy_TouchTurnOpeningRange      = false; // استراتيجية لمس نطاق الافتتاح والارتداد.
input bool EnableStrategy_MagicLiquidityPitchfork    = false; // استراتيجية خطوط السيولة الذكية وشمعة الشوكة.
input bool EnableStrategy_DailyLiquidityBox          = false; // استراتيجية صندوق السيولة اليومي وشمعة الشوكة.
input bool EnableStrategy_QuickFlipOpeningLiquidity  = false; // استراتيجية الانعكاس السريع بعد شمعة السيولة.
input bool EnableStrategy_FSEPatternFailureEntry     = false; // استراتيجية الدخول المبكر بعد فشل النموذج.
input bool EnableStrategy_TwoLiquidityLines15M       = false; // استراتيجية خطّي السيولة والارتداد المؤكد.
input bool EnableStrategy_GoldenLiquidity5MEntry     = false; // استراتيجية مناطق السيولة الذهبية ودخول الخمس دقائق.

// ==================================================================
// 04 - Reporting / التقارير
// v0.4.0 keeps the report contract and adds Evidence Framework diagnostics.
// Trade rows will be written later by Shadow/Paper/Demo engines.
// ==================================================================
input group "04 - Reporting / التقارير";
input bool EnableMainReport                 = true;
input bool EnableRejectedReport             = true;
input bool EnableEvidenceReport             = true;
input bool EnableVerboseExpertsLog          = true;

// ==================================================================
// 05 - Market Context / سياق السوق
// Keep simple. This is diagnostics only in v0.3.0.
// ==================================================================
input group "05 - Market Context / سياق السوق";
input bool            UseClosedCandlesOnly          = true;      // Core guard: use closed candles for analysis snapshots.
input bool            EnableMarketDiagnosticsReport = true;      // Writes one symbol/context snapshot at initialization.
input ENUM_TIMEFRAMES PrimaryContextTimeframe       = PERIOD_M5; // Diagnostic timeframe only. No strategy logic yet.
input bool            EnableCandleCacheDiagnosticsReport = true; // Writes M1/M5/M15/H1/H4/D1 closed-candle cache snapshot.
input bool            EnableEvidenceDiagnosticsReport    = true; // Writes the contract-only Evidence Framework snapshot.

// ==================================================================
// Core Data Contracts - v0.3.0
// ==================================================================
enum ENUM_FALCON_DIRECTION
{
   FALCON_DIRECTION_NONE = 0,
   FALCON_DIRECTION_BUY  = 1,
   FALCON_DIRECTION_SELL = -1
};

enum ENUM_FALCON_ENGINE_STATUS
{
   FALCON_ENGINE_DISABLED = 0,
   FALCON_ENGINE_SHADOW   = 1,
   FALCON_ENGINE_PAPER    = 2,
   FALCON_ENGINE_DEMO     = 3,
   FALCON_ENGINE_LIVE     = 4
};

enum ENUM_FALCON_GUARD_STATUS
{
   FALCON_GUARD_NOT_EVALUATED = 0,
   FALCON_GUARD_PASSED        = 1,
   FALCON_GUARD_REJECTED      = 2
};

enum ENUM_FALCON_TRADE_OUTCOME
{
   FALCON_TRADE_OUTCOME_OPEN      = 0,
   FALCON_TRADE_OUTCOME_WIN       = 1,
   FALCON_TRADE_OUTCOME_LOSS      = 2,
   FALCON_TRADE_OUTCOME_BREAKEVEN = 3,
   FALCON_TRADE_OUTCOME_UNKNOWN   = 4
};

enum ENUM_FALCON_TRADE_STAGE
{
   FALCON_TRADE_STAGE_NONE     = 0,
   FALCON_TRADE_STAGE_SHADOW   = 1,
   FALCON_TRADE_STAGE_PAPER    = 2,
   FALCON_TRADE_STAGE_DEMO     = 3,
   FALCON_TRADE_STAGE_LIVE     = 4
};


enum ENUM_FALCON_EVIDENCE_TYPE
{
   FALCON_EVIDENCE_TYPE_NONE                = 0,
   FALCON_EVIDENCE_TYPE_CANDLE_PATTERN      = 1,
   FALCON_EVIDENCE_TYPE_CHART_PATTERN       = 2,
   FALCON_EVIDENCE_TYPE_OBJECTIVE_INDICATOR = 3,
   FALCON_EVIDENCE_TYPE_SMC_LIQUIDITY       = 4
};

enum ENUM_FALCON_EVIDENCE_STATE
{
   FALCON_EVIDENCE_STATE_NOT_EVALUATED = 0,
   FALCON_EVIDENCE_STATE_ABSENT        = 1,
   FALCON_EVIDENCE_STATE_PRESENT       = 2,
   FALCON_EVIDENCE_STATE_CONFLICTING   = 3
};

struct FalconSymbolContext
{
   string symbol;
   int    digits;
   double point;
   double tick_size;
   double tick_value;
   double contract_size;
   long   spread_points;
   long   stops_level_points;
   double min_lot;
   double max_lot;
   double lot_step;
   bool   is_valid;
};

struct FalconQuoteContext
{
   double   bid;
   double   ask;
   double   last;
   long     volume;
   double   volume_real;
   datetime tick_time;
   long     time_msc;
   long     spread_points;
   bool     is_valid;
};

struct FalconCandleSnapshot
{
   ENUM_TIMEFRAMES timeframe;
   datetime        time;
   double          open;
   double          high;
   double          low;
   double          close;
   long            tick_volume;
   long            real_volume;
   int             spread;
   int             source_shift;
   bool            is_closed;
   bool            is_valid;
};

struct FalconEvidenceRecord
{
   string                     evidence_id;
   string                     evidence_name;
   ENUM_FALCON_EVIDENCE_TYPE  evidence_type;
   ENUM_FALCON_EVIDENCE_STATE evidence_state;
   ENUM_FALCON_DIRECTION      direction_bias;
   ENUM_TIMEFRAMES            source_timeframe;
   double                     score;
   bool                       is_runtime_permission;
   string                     notes;
};

struct FalconEvidencePack
{
   bool   has_candle_evidence;
   bool   has_chart_pattern_evidence;
   bool   has_objective_indicator_evidence;
   bool   has_smc_evidence;
   double score;
   string summary;
};

struct FalconObjectivePlan
{
   double entry_price;
   double structural_sl;
   double tp1;
   double tp2;
   double tp3;
   bool   runner_allowed;
   string objective_reason;
};

struct FalconStrategySignal
{
   string                    strategy_id;
   string                    strategy_name;
   string                    engine_id;
   ENUM_FALCON_DIRECTION     direction;
   ENUM_FALCON_ENGINE_STATUS engine_status;
   ENUM_FALCON_GUARD_STATUS  guard_status;
   datetime                  setup_time;
   ENUM_TIMEFRAMES           setup_timeframe;
   double                    score;
   string                    rejection_reason;
   FalconEvidencePack        evidence;
   FalconObjectivePlan       objective;
};

struct FalconTradePlan
{
   string                plan_id;
   string                strategy_id;
   string                strategy_name;
   string                engine_id;
   ENUM_FALCON_DIRECTION direction;
   double                lot_size;
   double                entry_price;
   double                structural_sl;
   double                tp1;
   double                tp2;
   double                tp3;
   bool                  runner_allowed;
   string                risk_profile;
   string                management_profile;
};

struct FalconTradeLifecycleRecord
{
   string                    trade_id;
   string                    strategy_id;
   string                    strategy_name;
   string                    engine_id;
   ENUM_FALCON_DIRECTION     direction;
   ENUM_FALCON_TRADE_STAGE   stage;
   ENUM_FALCON_TRADE_OUTCOME outcome;
   datetime                  entry_time;
   datetime                  exit_time;
   double                    lot_size;
   double                    entry_price;
   double                    structural_sl;
   double                    tp1;
   double                    tp2;
   double                    tp3;
   double                    exit_price;
   double                    profit_index_points;
   double                    loss_index_points;
   double                    net_index_points;
   double                    profit_usd;
   double                    loss_usd;
   double                    net_usd;
   string                    close_reason;
   string                    evidence_summary;
};

struct FalconReportTotals
{
   int    total_trades;
   int    win_trades;
   int    loss_trades;
   int    breakeven_trades;
   double total_profit_index_points;
   double total_loss_index_points;
   double net_index_points;
   double total_profit_usd;
   double total_loss_usd;
   double net_usd;
   double win_rate;
   double loss_rate;
};

// ==================================================================
// Utility helpers
// ==================================================================
string FalconDirectionToString(const ENUM_FALCON_DIRECTION direction)
{
   if(direction == FALCON_DIRECTION_BUY)
      return "BUY";
   if(direction == FALCON_DIRECTION_SELL)
      return "SELL";
   return "NONE";
}

string FalconOutcomeToString(const ENUM_FALCON_TRADE_OUTCOME outcome)
{
   if(outcome == FALCON_TRADE_OUTCOME_WIN)
      return "WIN";
   if(outcome == FALCON_TRADE_OUTCOME_LOSS)
      return "LOSE";
   if(outcome == FALCON_TRADE_OUTCOME_BREAKEVEN)
      return "BREAKEVEN";
   if(outcome == FALCON_TRADE_OUTCOME_OPEN)
      return "OPEN";
   return "UNKNOWN";
}

string FalconStageToString(const ENUM_FALCON_TRADE_STAGE stage)
{
   if(stage == FALCON_TRADE_STAGE_SHADOW)
      return "SHADOW";
   if(stage == FALCON_TRADE_STAGE_PAPER)
      return "PAPER";
   if(stage == FALCON_TRADE_STAGE_DEMO)
      return "DEMO";
   if(stage == FALCON_TRADE_STAGE_LIVE)
      return "LIVE";
   return "NONE";
}


string FalconEvidenceTypeToString(const ENUM_FALCON_EVIDENCE_TYPE evidence_type)
{
   if(evidence_type == FALCON_EVIDENCE_TYPE_CANDLE_PATTERN)
      return "CANDLE_PATTERN";
   if(evidence_type == FALCON_EVIDENCE_TYPE_CHART_PATTERN)
      return "CHART_PATTERN";
   if(evidence_type == FALCON_EVIDENCE_TYPE_OBJECTIVE_INDICATOR)
      return "OBJECTIVE_INDICATOR";
   if(evidence_type == FALCON_EVIDENCE_TYPE_SMC_LIQUIDITY)
      return "SMC_LIQUIDITY";
   return "NONE";
}

string FalconEvidenceStateToString(const ENUM_FALCON_EVIDENCE_STATE evidence_state)
{
   if(evidence_state == FALCON_EVIDENCE_STATE_ABSENT)
      return "ABSENT";
   if(evidence_state == FALCON_EVIDENCE_STATE_PRESENT)
      return "PRESENT";
   if(evidence_state == FALCON_EVIDENCE_STATE_CONFLICTING)
      return "CONFLICTING";
   return "NOT_EVALUATED";
}

string FalconTimeToString(const datetime value)
{
   if(value <= 0)
      return "";
   return TimeToString(value, TIME_DATE | TIME_SECONDS);
}

string FalconTimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
   return EnumToString(timeframe);
}

int FalconAnalysisCandleShift()
{
   return (UseClosedCandlesOnly ? 1 : 0);
}

double FalconConfiguredCapital()
{
   if(UseAutoCapitalDetection)
      return AccountInfoDouble(ACCOUNT_BALANCE);
   return ManualCapital;
}

double FalconRawIndexPoints(const ENUM_FALCON_DIRECTION direction,
                            const double entry_price,
                            const double exit_price)
{
   if(direction == FALCON_DIRECTION_BUY)
      return exit_price - entry_price;
   if(direction == FALCON_DIRECTION_SELL)
      return entry_price - exit_price;
   return 0.0;
}

double FalconEstimateUsdByRawPoints(const double raw_index_points,
                                    const double lot_size,
                                    const FalconSymbolContext &symbol_context)
{
   if(symbol_context.contract_size <= 0.0 || lot_size <= 0.0)
      return 0.0;
   return raw_index_points * symbol_context.contract_size * lot_size;
}

void FalconFinalizeTradeMetrics(FalconTradeLifecycleRecord &record,
                                const FalconSymbolContext &symbol_context)
{
   record.net_index_points = FalconRawIndexPoints(record.direction, record.entry_price, record.exit_price);

   if(record.net_index_points > 0.0)
   {
      record.outcome             = FALCON_TRADE_OUTCOME_WIN;
      record.profit_index_points = record.net_index_points;
      record.loss_index_points   = 0.0;
   }
   else if(record.net_index_points < 0.0)
   {
      record.outcome             = FALCON_TRADE_OUTCOME_LOSS;
      record.profit_index_points = 0.0;
      record.loss_index_points   = MathAbs(record.net_index_points);
   }
   else
   {
      record.outcome             = FALCON_TRADE_OUTCOME_BREAKEVEN;
      record.profit_index_points = 0.0;
      record.loss_index_points   = 0.0;
   }

   record.net_usd = FalconEstimateUsdByRawPoints(record.net_index_points, record.lot_size, symbol_context);
   if(record.net_usd > 0.0)
   {
      record.profit_usd = record.net_usd;
      record.loss_usd   = 0.0;
   }
   else if(record.net_usd < 0.0)
   {
      record.profit_usd = 0.0;
      record.loss_usd   = MathAbs(record.net_usd);
   }
   else
   {
      record.profit_usd = 0.0;
      record.loss_usd   = 0.0;
   }
}

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

// ==================================================================
// Market Context Provider - v0.3.0 symbol, quote, and closed candle diagnostics
// ==================================================================
class CFalconMarketContext
{
private:
   FalconSymbolContext  m_symbol;
   FalconQuoteContext   m_quote;
   FalconCandleSnapshot m_primary_candle;

public:
   bool Initialize()
   {
      m_symbol.symbol             = _Symbol;
      m_symbol.digits             = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      m_symbol.point              = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      m_symbol.tick_size          = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      m_symbol.tick_value         = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      m_symbol.contract_size      = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      m_symbol.spread_points      = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      m_symbol.stops_level_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      m_symbol.min_lot            = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      m_symbol.max_lot            = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      m_symbol.lot_step           = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      m_symbol.is_valid           = ValidateSymbol();

      if(!m_symbol.is_valid)
         return false;

      if(!Refresh())
         return false;

      const int shift = FalconAnalysisCandleShift();
      if(!GetCandleSnapshot(PrimaryContextTimeframe, shift, m_primary_candle))
      {
         CFalconLogger::Error(StringFormat("Could not read primary context candle. Timeframe=%s | Shift=%d",
                                           FalconTimeframeToString(PrimaryContextTimeframe),
                                           shift));
         return false;
      }

      CFalconLogger::Info(StringFormat("SymbolContext initialized: %s | Digits=%d | Point=%.10f | TickSize=%.10f | TickValue=%.5f | Contract=%.2f | MinLot=%.2f | Step=%.2f | StopsLevel=%d",
                                       m_symbol.symbol,
                                       m_symbol.digits,
                                       m_symbol.point,
                                       m_symbol.tick_size,
                                       m_symbol.tick_value,
                                       m_symbol.contract_size,
                                       m_symbol.min_lot,
                                       m_symbol.lot_step,
                                       (int)m_symbol.stops_level_points));

      CFalconLogger::Info(StringFormat("QuoteContext initialized: Bid=%s | Ask=%s | SpreadPoints=%d | TickTime=%s",
                                       DoubleToString(m_quote.bid, m_symbol.digits),
                                       DoubleToString(m_quote.ask, m_symbol.digits),
                                       (int)m_quote.spread_points,
                                       FalconTimeToString(m_quote.tick_time)));

      CFalconLogger::Info(StringFormat("Primary closed-candle guard: UseClosedCandlesOnly=%s | Timeframe=%s | Shift=%d | CandleTime=%s | O=%.5f H=%.5f L=%.5f C=%.5f",
                                       (UseClosedCandlesOnly ? "true" : "false"),
                                       FalconTimeframeToString(m_primary_candle.timeframe),
                                       m_primary_candle.source_shift,
                                       FalconTimeToString(m_primary_candle.time),
                                       m_primary_candle.open,
                                       m_primary_candle.high,
                                       m_primary_candle.low,
                                       m_primary_candle.close));
      return true;
   }

   bool Refresh()
   {
      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick))
      {
         CFalconLogger::Error("SymbolInfoTick failed. Market context cannot be refreshed.");
         m_quote.is_valid = false;
         return false;
      }

      m_quote.bid           = tick.bid;
      m_quote.ask           = tick.ask;
      m_quote.last          = tick.last;
      m_quote.volume        = (long)tick.volume;
      m_quote.volume_real   = tick.volume_real;
      m_quote.tick_time     = tick.time;
      m_quote.time_msc      = tick.time_msc;
      m_quote.spread_points = CalculateLiveSpreadPoints(tick.bid, tick.ask);
      m_quote.is_valid      = (tick.bid > 0.0 && tick.ask > 0.0 && m_quote.spread_points >= 0);

      if(!m_quote.is_valid)
      {
         CFalconLogger::Warn("Quote context is not valid yet. This can happen when the market is closed or no tick is available.");
      }
      return true;
   }

   FalconSymbolContext GetSymbolContext()
   {
      return m_symbol;
   }

   FalconQuoteContext GetQuoteContext()
   {
      return m_quote;
   }

   FalconCandleSnapshot GetPrimaryCandleSnapshot()
   {
      return m_primary_candle;
   }

   bool GetCandleSnapshot(const ENUM_TIMEFRAMES timeframe,
                          const int shift,
                          FalconCandleSnapshot &snapshot)
   {
      ResetCandleSnapshot(snapshot);
      snapshot.timeframe    = timeframe;
      snapshot.source_shift = shift;
      snapshot.is_closed    = (shift > 0);

      if(shift < 0)
      {
         CFalconLogger::Error("Candle snapshot shift cannot be negative.");
         return false;
      }

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(_Symbol, timeframe, shift, 1, rates);
      if(copied != 1)
      {
         CFalconLogger::Warn(StringFormat("CopyRates failed. Symbol=%s | Timeframe=%s | Shift=%d | Copied=%d",
                                           _Symbol,
                                           FalconTimeframeToString(timeframe),
                                           shift,
                                           copied));
         return false;
      }

      snapshot.time        = rates[0].time;
      snapshot.open        = rates[0].open;
      snapshot.high        = rates[0].high;
      snapshot.low         = rates[0].low;
      snapshot.close       = rates[0].close;
      snapshot.tick_volume = rates[0].tick_volume;
      snapshot.real_volume = rates[0].real_volume;
      snapshot.spread      = rates[0].spread;
      snapshot.is_valid    = (snapshot.time > 0 && snapshot.high >= snapshot.low);
      return snapshot.is_valid;
   }

private:
   bool ValidateSymbol()
   {
      if(m_symbol.point <= 0.0)
      {
         CFalconLogger::Error("Invalid symbol point value.");
         return false;
      }
      if(m_symbol.min_lot <= 0.0 || m_symbol.lot_step <= 0.0)
      {
         CFalconLogger::Error("Invalid symbol lot configuration.");
         return false;
      }
      if(m_symbol.contract_size <= 0.0)
      {
         CFalconLogger::Warn("Symbol contract size is not positive. USD estimates may be zero until broker metadata is available.");
      }
      return true;
   }

   long CalculateLiveSpreadPoints(const double bid, const double ask)
   {
      if(m_symbol.point <= 0.0 || bid <= 0.0 || ask <= 0.0)
         return -1;
      return (long)MathRound((ask - bid) / m_symbol.point);
   }

   void ResetCandleSnapshot(FalconCandleSnapshot &snapshot)
   {
      snapshot.timeframe    = PERIOD_CURRENT;
      snapshot.time         = 0;
      snapshot.open         = 0.0;
      snapshot.high         = 0.0;
      snapshot.low          = 0.0;
      snapshot.close        = 0.0;
      snapshot.tick_volume  = 0;
      snapshot.real_volume  = 0;
      snapshot.spread       = 0;
      snapshot.source_shift = 0;
      snapshot.is_closed    = false;
      snapshot.is_valid     = false;
   }
};


// ==================================================================
// Multi-Timeframe Candle Cache - v0.4.0
// Official analysis timeframes: M1, M5, M15, H1, H4, D1.
// This layer is data-provider only. It does not create signals.
// ==================================================================
class CFalconCandleCache
{
private:
   ENUM_TIMEFRAMES       m_timeframes[FALCON_MTF_COUNT];
   FalconCandleSnapshot  m_analysis_snapshots[FALCON_MTF_COUNT];
   bool                  m_is_loaded;
   int                   m_valid_count;
   int                   m_analysis_shift;

public:
   CFalconCandleCache()
   {
      m_is_loaded      = false;
      m_valid_count    = 0;
      m_analysis_shift = 1;
      ConfigureTimeframes();
   }

   void ConfigureTimeframes()
   {
      m_timeframes[0] = PERIOD_M1;
      m_timeframes[1] = PERIOD_M5;
      m_timeframes[2] = PERIOD_M15;
      m_timeframes[3] = PERIOD_H1;
      m_timeframes[4] = PERIOD_H4;
      m_timeframes[5] = PERIOD_D1;
   }

   bool LoadAll(CFalconMarketContext &context)
   {
      m_is_loaded      = false;
      m_valid_count    = 0;
      m_analysis_shift = FalconAnalysisCandleShift();

      for(int i = 0; i < FALCON_MTF_COUNT; i++)
      {
         FalconCandleSnapshot snapshot;
         bool ok = context.GetCandleSnapshot(m_timeframes[i], m_analysis_shift, snapshot);
         m_analysis_snapshots[i] = snapshot;

         if(ok && snapshot.is_valid)
            m_valid_count++;
      }

      m_is_loaded = (m_valid_count > 0);
      CFalconLogger::Info(StringFormat("CandleCache loaded. Timeframes=%d | Valid=%d | Shift=%d | UseClosedCandlesOnly=%s",
                                       FALCON_MTF_COUNT,
                                       m_valid_count,
                                       m_analysis_shift,
                                       (UseClosedCandlesOnly ? "true" : "false")));

      for(int i = 0; i < FALCON_MTF_COUNT; i++)
      {
         FalconCandleSnapshot s = m_analysis_snapshots[i];
         CFalconLogger::Info(StringFormat("CandleCache[%s] Valid=%s | Shift=%d | Time=%s | O=%.5f H=%.5f L=%.5f C=%.5f",
                                          FalconTimeframeToString(s.timeframe),
                                          (s.is_valid ? "true" : "false"),
                                          s.source_shift,
                                          FalconTimeToString(s.time),
                                          s.open,
                                          s.high,
                                          s.low,
                                          s.close));
      }

      return m_is_loaded;
   }

   int Count()
   {
      return FALCON_MTF_COUNT;
   }

   int ValidCount()
   {
      return m_valid_count;
   }

   bool IsLoaded()
   {
      return m_is_loaded;
   }

   int AnalysisShift()
   {
      return m_analysis_shift;
   }

   ENUM_TIMEFRAMES TimeframeAt(const int index)
   {
      if(index < 0 || index >= FALCON_MTF_COUNT)
         return PERIOD_CURRENT;
      return m_timeframes[index];
   }

   bool GetSnapshotByIndex(const int index,
                           FalconCandleSnapshot &snapshot)
   {
      if(index < 0 || index >= FALCON_MTF_COUNT)
         return false;
      snapshot = m_analysis_snapshots[index];
      return snapshot.is_valid;
   }

   bool GetSnapshotByTimeframe(const ENUM_TIMEFRAMES timeframe,
                               FalconCandleSnapshot &snapshot)
   {
      for(int i = 0; i < FALCON_MTF_COUNT; i++)
      {
         if(m_timeframes[i] == timeframe)
         {
            snapshot = m_analysis_snapshots[i];
            return snapshot.is_valid;
         }
      }
      return false;
   }
};

// ==================================================================
// Evidence Framework Foundation - v0.4.0
// Contract-only layer. Evidence strengthens or weakens future engine decisions,
// but it never opens a trade and never overrides guards.
// ==================================================================
class CFalconEvidenceFramework
{
private:
   FalconEvidenceRecord m_records[4];
   int                  m_record_count;
   bool                 m_initialized;

public:
   CFalconEvidenceFramework()
   {
      m_record_count = 0;
      m_initialized  = false;
   }

   bool Initialize()
   {
      m_record_count = 0;
      AddContractRecord("EVID_CANDLE", "Candle Pattern Evidence", FALCON_EVIDENCE_TYPE_CANDLE_PATTERN,
                        "Contract only: engulfing, pin bar, hammer, shooting star, wide body, inside/outside bar, three-bar reversal.");
      AddContractRecord("EVID_CHART", "Chart Pattern Evidence", FALCON_EVIDENCE_TYPE_CHART_PATTERN,
                        "Contract only: double top/bottom, H&S, flag, wedge, triangle, range break/retest, channel break, sweep/reclaim.");
      AddContractRecord("EVID_OBJECTIVE", "Objective Indicator Evidence", FALCON_EVIDENCE_TYPE_OBJECTIVE_INDICATOR,
                        "Contract only: VWAP, EMA 7/25/50/200, ATR, RSI closed candle, session levels, previous day levels, FVG, tick volume.");
      AddContractRecord("EVID_SMC", "SMC / Liquidity Evidence", FALCON_EVIDENCE_TYPE_SMC_LIQUIDITY,
                        "Contract only: liquidity sweep, reclaim, FVG/imbalance, displacement, BOS/CHoCH, premium/discount, HTF/LTF alignment.");

      m_initialized = (m_record_count == 4);
      CFalconLogger::Info(StringFormat("EvidenceFramework initialized. Records=%d | PermissionMode=EVIDENCE_ONLY", m_record_count));
      return m_initialized;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   int Count()
   {
      return m_record_count;
   }

   bool GetRecordByIndex(const int index, FalconEvidenceRecord &record)
   {
      if(index < 0 || index >= m_record_count)
         return false;
      record = m_records[index];
      return true;
   }

   FalconEvidencePack BuildEmptyEvidencePack()
   {
      FalconEvidencePack pack;
      pack.has_candle_evidence              = false;
      pack.has_chart_pattern_evidence       = false;
      pack.has_objective_indicator_evidence = false;
      pack.has_smc_evidence                 = false;
      pack.score                            = 0.0;
      pack.summary                          = "No runtime evidence evaluated in v0.4.0. Evidence Framework is contract-only.";
      return pack;
   }

private:
   void AddContractRecord(const string evidence_id,
                          const string evidence_name,
                          const ENUM_FALCON_EVIDENCE_TYPE evidence_type,
                          const string notes)
   {
      if(m_record_count >= 4)
         return;

      FalconEvidenceRecord record;
      record.evidence_id           = evidence_id;
      record.evidence_name         = evidence_name;
      record.evidence_type         = evidence_type;
      record.evidence_state        = FALCON_EVIDENCE_STATE_NOT_EVALUATED;
      record.direction_bias        = FALCON_DIRECTION_NONE;
      record.source_timeframe      = PERIOD_CURRENT;
      record.score                 = 0.0;
      record.is_runtime_permission = false;
      record.notes                 = notes;

      m_records[m_record_count] = record;
      m_record_count++;
   }
};

// ==================================================================
// Risk Foundation - validates only. No lot calculations yet.
// ==================================================================
class CFalconRiskFoundation
{
public:
   bool ValidateInputs(const FalconSymbolContext &symbol_context)
   {
      if(EnableRealExecution)
      {
         CFalconLogger::Error("HARD SAFETY BLOCK: EnableRealExecution must remain false in v0.4.0.");
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

// ==================================================================
// Strategy Registry - switches only. No engine logic in v0.4.0.
// ==================================================================
class CFalconStrategyRegistry
{
public:
   int CountEnabledStrategies()
   {
      int count = 0;
      if(EnableStrategy_FvgMicroRetest)            count++;
      if(EnableStrategy_TailSmartReturn)           count++;
      if(EnableStrategy_MomentumCross820)          count++;
      if(EnableStrategy_CheckMarkLiquiditySweep)   count++;
      if(EnableStrategy_DoubleBoxWickConfirmation) count++;
      if(EnableStrategy_TouchTurnOpeningRange)     count++;
      if(EnableStrategy_MagicLiquidityPitchfork)   count++;
      if(EnableStrategy_DailyLiquidityBox)         count++;
      if(EnableStrategy_QuickFlipOpeningLiquidity) count++;
      if(EnableStrategy_FSEPatternFailureEntry)    count++;
      if(EnableStrategy_TwoLiquidityLines15M)      count++;
      if(EnableStrategy_GoldenLiquidity5MEntry)    count++;
      return count;
   }

   void PrintRegistryState()
   {
      CFalconLogger::Info(StringFormat("StrategyRegistry initialized. EnabledStrategies=%d. All enabled strategies remain observe-only in v0.4.0.", CountEnabledStrategies()));
   }
};

// ==================================================================
// Report Writer Foundation - append-ready CSV contracts
// ==================================================================
class CFalconReportWriter
{
private:
   string              m_trade_report_file;
   string              m_summary_report_file;
   string              m_market_diagnostics_file;
   string              m_candle_cache_diagnostics_file;
   string              m_evidence_diagnostics_file;
   FalconSymbolContext m_symbol_context;
   FalconReportTotals  m_totals;
   bool                m_initialized;

public:
   CFalconReportWriter()
   {
      m_initialized = false;
      ResetTotals();
   }

   bool Initialize(const FalconSymbolContext &symbol_context)
   {
      m_symbol_context     = symbol_context;
      m_trade_report_file  = "JA_FalconCore_TradeLifecycle_v0_4_0.csv";
      m_summary_report_file= "JA_FalconCore_Summary_v0_4_0.csv";
      m_market_diagnostics_file = "JA_FalconCore_MarketDiagnostics_v0_4_0.csv";
      m_candle_cache_diagnostics_file = "JA_FalconCore_CandleCacheDiagnostics_v0_4_0.csv";
      m_evidence_diagnostics_file = "JA_FalconCore_EvidenceDiagnostics_v0_4_0.csv";
      ResetTotals();

      if(EnableMainReport)
      {
         WriteTradeHeader();
         WriteSummaryHeader();
      }

      m_initialized = true;
      CFalconLogger::Info(StringFormat("ReportWriter initialized. TradeReport=%s | SummaryReport=%s", m_trade_report_file, m_summary_report_file));
      return true;
   }

   void WriteMarketDiagnosticsSnapshot(const FalconQuoteContext &quote_context,
                                       const FalconCandleSnapshot &primary_candle)
   {
      if(!m_initialized || !EnableMarketDiagnosticsReport)
         return;

      int handle = FileOpen(m_market_diagnostics_file, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write market diagnostics report: %s", m_market_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "Digits", "Point", "TickSize", "TickValue", "ContractSize",
                "BrokerSpreadPoints", "LiveSpreadPoints", "StopsLevelPoints",
                "MinLot", "MaxLot", "LotStep",
                "Bid", "Ask", "Last", "TickTime", "TickVolume", "TickVolumeReal",
                "UseClosedCandlesOnly", "PrimaryContextTimeframe", "AnalysisCandleShift",
                "CandleTime", "CandleOpen", "CandleHigh", "CandleLow", "CandleClose",
                "CandleTickVolume", "CandleRealVolume", "CandleSpread", "IsClosed", "IsValid",
                "ConfiguredCapital", "DailyLossLimitEnabled", "FixedDailyLossAmount", "DailyLossPercentOfCapital",
                "EnableRealExecution");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                m_symbol_context.digits,
                DoubleToString(m_symbol_context.point, 10),
                DoubleToString(m_symbol_context.tick_size, 10),
                DoubleToString(m_symbol_context.tick_value, 5),
                DoubleToString(m_symbol_context.contract_size, 2),
                (int)m_symbol_context.spread_points,
                (int)quote_context.spread_points,
                (int)m_symbol_context.stops_level_points,
                DoubleToString(m_symbol_context.min_lot, 2),
                DoubleToString(m_symbol_context.max_lot, 2),
                DoubleToString(m_symbol_context.lot_step, 2),
                DoubleToString(quote_context.bid, m_symbol_context.digits),
                DoubleToString(quote_context.ask, m_symbol_context.digits),
                DoubleToString(quote_context.last, m_symbol_context.digits),
                FalconTimeToString(quote_context.tick_time),
                quote_context.volume,
                DoubleToString(quote_context.volume_real, 2),
                (UseClosedCandlesOnly ? "true" : "false"),
                FalconTimeframeToString(primary_candle.timeframe),
                primary_candle.source_shift,
                FalconTimeToString(primary_candle.time),
                DoubleToString(primary_candle.open, m_symbol_context.digits),
                DoubleToString(primary_candle.high, m_symbol_context.digits),
                DoubleToString(primary_candle.low, m_symbol_context.digits),
                DoubleToString(primary_candle.close, m_symbol_context.digits),
                primary_candle.tick_volume,
                primary_candle.real_volume,
                primary_candle.spread,
                (primary_candle.is_closed ? "true" : "false"),
                (primary_candle.is_valid ? "true" : "false"),
                DoubleToString(FalconConfiguredCapital(), 2),
                (UseDailyLossLimit ? "true" : "false"),
                DoubleToString(FixedDailyLossAmount, 2),
                DoubleToString(DailyLossPercentOfCapital, 2),
                (EnableRealExecution ? "true" : "false"));

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Market diagnostics snapshot written: %s", m_market_diagnostics_file));
   }

   void WriteCandleCacheDiagnosticsSnapshot(CFalconCandleCache &cache)
   {
      if(!m_initialized || !EnableCandleCacheDiagnosticsReport)
         return;

      int handle = FileOpen(m_candle_cache_diagnostics_file, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write candle cache diagnostics report: %s", m_candle_cache_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "UseClosedCandlesOnly", "AnalysisShift", "CacheCount", "ValidCount",
                "Timeframe", "CandleTime", "Open", "High", "Low", "Close",
                "TickVolume", "RealVolume", "Spread", "IsClosed", "IsValid");

      for(int i = 0; i < cache.Count(); i++)
      {
         FalconCandleSnapshot snapshot;
         cache.GetSnapshotByIndex(i, snapshot);

         FileWrite(handle,
                   EA_NAME,
                   EA_VERSION_TAG,
                   EA_BUILD_TAG,
                   m_symbol_context.symbol,
                   FalconTimeToString(TimeCurrent()),
                   (UseClosedCandlesOnly ? "true" : "false"),
                   cache.AnalysisShift(),
                   cache.Count(),
                   cache.ValidCount(),
                   FalconTimeframeToString(snapshot.timeframe),
                   FalconTimeToString(snapshot.time),
                   DoubleToString(snapshot.open, m_symbol_context.digits),
                   DoubleToString(snapshot.high, m_symbol_context.digits),
                   DoubleToString(snapshot.low, m_symbol_context.digits),
                   DoubleToString(snapshot.close, m_symbol_context.digits),
                   snapshot.tick_volume,
                   snapshot.real_volume,
                   snapshot.spread,
                   (snapshot.is_closed ? "true" : "false"),
                   (snapshot.is_valid ? "true" : "false"));
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Candle cache diagnostics snapshot written: %s", m_candle_cache_diagnostics_file));
   }

   void WriteEvidenceDiagnosticsSnapshot(CFalconEvidenceFramework &evidence_framework)
   {
      if(!m_initialized || !EnableEvidenceDiagnosticsReport)
         return;

      int handle = FileOpen(m_evidence_diagnostics_file, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write evidence diagnostics report: %s", m_evidence_diagnostics_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "EvidenceId", "EvidenceName", "EvidenceType", "EvidenceState",
                "DirectionBias", "SourceTimeframe", "Score", "RuntimePermission", "Notes");

      for(int i = 0; i < evidence_framework.Count(); i++)
      {
         FalconEvidenceRecord record;
         if(!evidence_framework.GetRecordByIndex(i, record))
            continue;

         FileWrite(handle,
                   EA_NAME,
                   EA_VERSION_TAG,
                   EA_BUILD_TAG,
                   m_symbol_context.symbol,
                   FalconTimeToString(TimeCurrent()),
                   record.evidence_id,
                   record.evidence_name,
                   FalconEvidenceTypeToString(record.evidence_type),
                   FalconEvidenceStateToString(record.evidence_state),
                   FalconDirectionToString(record.direction_bias),
                   FalconTimeframeToString(record.source_timeframe),
                   DoubleToString(record.score, 2),
                   (record.is_runtime_permission ? "true" : "false"),
                   record.notes);
      }

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Evidence diagnostics snapshot written: %s", m_evidence_diagnostics_file));
   }

   void RegisterClosedTrade(FalconTradeLifecycleRecord &record)
   {
      if(!m_initialized || !EnableMainReport)
         return;

      FalconFinalizeTradeMetrics(record, m_symbol_context);
      UpdateTotals(record);
      AppendTradeRecord(record);
   }

   void WriteFinalSummary()
   {
      if(!m_initialized || !EnableMainReport)
         return;

      // MQL5 compatibility: RefreshRates() is not used. Summary uses accumulated closed-trade records.
      if(m_totals.total_trades > 0)
      {
         m_totals.win_rate  = (100.0 * (double)m_totals.win_trades) / (double)m_totals.total_trades;
         m_totals.loss_rate = (100.0 * (double)m_totals.loss_trades) / (double)m_totals.total_trades;
      }
      else
      {
         m_totals.win_rate  = 0.0;
         m_totals.loss_rate = 0.0;
      }

      int handle = FileOpen(m_summary_report_file, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not write summary report: %s", m_summary_report_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "TotalTrades", "WinTrades", "LoseTrades", "BreakevenTrades",
                "WinRate", "LoseRate",
                "TotalProfitIndexPoints", "TotalLossIndexPoints", "NetIndexPoints",
                "TotalProfitUSD", "TotalLossUSD", "NetUSD");

      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                FalconTimeToString(TimeCurrent()),
                m_totals.total_trades,
                m_totals.win_trades,
                m_totals.loss_trades,
                m_totals.breakeven_trades,
                DoubleToString(m_totals.win_rate, 2),
                DoubleToString(m_totals.loss_rate, 2),
                DoubleToString(m_totals.total_profit_index_points, 2),
                DoubleToString(m_totals.total_loss_index_points, 2),
                DoubleToString(m_totals.net_index_points, 2),
                DoubleToString(m_totals.total_profit_usd, 2),
                DoubleToString(m_totals.total_loss_usd, 2),
                DoubleToString(m_totals.net_usd, 2));

      FileClose(handle);
      CFalconLogger::Info(StringFormat("Final summary written. Trades=%d | WinRate=%.2f | NetIndexPoints=%.2f | NetUSD=%.2f",
                                       m_totals.total_trades,
                                       m_totals.win_rate,
                                       m_totals.net_index_points,
                                       m_totals.net_usd));
   }

private:
   void ResetTotals()
   {
      m_totals.total_trades                = 0;
      m_totals.win_trades                  = 0;
      m_totals.loss_trades                 = 0;
      m_totals.breakeven_trades            = 0;
      m_totals.total_profit_index_points   = 0.0;
      m_totals.total_loss_index_points     = 0.0;
      m_totals.net_index_points            = 0.0;
      m_totals.total_profit_usd            = 0.0;
      m_totals.total_loss_usd              = 0.0;
      m_totals.net_usd                     = 0.0;
      m_totals.win_rate                    = 0.0;
      m_totals.loss_rate                   = 0.0;
   }

   void UpdateTotals(const FalconTradeLifecycleRecord &record)
   {
      m_totals.total_trades++;

      if(record.outcome == FALCON_TRADE_OUTCOME_WIN)
         m_totals.win_trades++;
      else if(record.outcome == FALCON_TRADE_OUTCOME_LOSS)
         m_totals.loss_trades++;
      else if(record.outcome == FALCON_TRADE_OUTCOME_BREAKEVEN)
         m_totals.breakeven_trades++;

      m_totals.total_profit_index_points += record.profit_index_points;
      m_totals.total_loss_index_points   += record.loss_index_points;
      m_totals.net_index_points          += record.net_index_points;
      m_totals.total_profit_usd          += record.profit_usd;
      m_totals.total_loss_usd            += record.loss_usd;
      m_totals.net_usd                   += record.net_usd;
   }

   void WriteTradeHeader()
   {
      int handle = FileOpen(m_trade_report_file, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create trade lifecycle report: %s", m_trade_report_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol",
                "TradeId", "StrategyId", "StrategyName", "EngineId",
                "Stage", "Direction", "EntryTime", "ExitTime",
                "LotSize", "Entry", "SL", "TP1", "TP2", "TP3", "Exit",
                "Outcome", "WinLose",
                "ProfitIndexPoints", "LoseIndexPoints", "NetIndexPoints",
                "ProfitUSD", "LoseUSD", "NetUSD",
                "CloseReason", "EvidenceSummary");
      FileClose(handle);
   }

   void WriteSummaryHeader()
   {
      int handle = FileOpen(m_summary_report_file, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not create summary report: %s", m_summary_report_file));
         return;
      }

      FileWrite(handle,
                "EAName", "Version", "Build", "Symbol", "GeneratedAt",
                "TotalTrades", "WinTrades", "LoseTrades", "BreakevenTrades",
                "WinRate", "LoseRate",
                "TotalProfitIndexPoints", "TotalLossIndexPoints", "NetIndexPoints",
                "TotalProfitUSD", "TotalLossUSD", "NetUSD");
      FileClose(handle);
   }

   void AppendTradeRecord(const FalconTradeLifecycleRecord &record)
   {
      int handle = FileOpen(m_trade_report_file, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         CFalconLogger::Warn(StringFormat("Could not append trade lifecycle record: %s", m_trade_report_file));
         return;
      }

      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle,
                EA_NAME,
                EA_VERSION_TAG,
                EA_BUILD_TAG,
                m_symbol_context.symbol,
                record.trade_id,
                record.strategy_id,
                record.strategy_name,
                record.engine_id,
                FalconStageToString(record.stage),
                FalconDirectionToString(record.direction),
                FalconTimeToString(record.entry_time),
                FalconTimeToString(record.exit_time),
                DoubleToString(record.lot_size, 2),
                DoubleToString(record.entry_price, m_symbol_context.digits),
                DoubleToString(record.structural_sl, m_symbol_context.digits),
                DoubleToString(record.tp1, m_symbol_context.digits),
                DoubleToString(record.tp2, m_symbol_context.digits),
                DoubleToString(record.tp3, m_symbol_context.digits),
                DoubleToString(record.exit_price, m_symbol_context.digits),
                FalconOutcomeToString(record.outcome),
                FalconOutcomeToString(record.outcome),
                DoubleToString(record.profit_index_points, 2),
                DoubleToString(record.loss_index_points, 2),
                DoubleToString(record.net_index_points, 2),
                DoubleToString(record.profit_usd, 2),
                DoubleToString(record.loss_usd, 2),
                DoubleToString(record.net_usd, 2),
                record.close_reason,
                record.evidence_summary);
      FileClose(handle);
   }
};

// ==================================================================
// Execution Guard - real trading intentionally impossible in v0.3.0.
// ==================================================================
class CFalconExecutionGuard
{
public:
   bool CanSendRealOrders()
   {
      // v0.4.0 is an Evidence Framework foundation build. Real execution is not allowed even if the input is changed.
      return false;
   }

   void AssertNoExecution()
   {
      CFalconLogger::Info("ExecutionGuard active: OrderSend / trade execution is intentionally disabled in v0.4.0.");
   }
};

// ==================================================================
// Global Runtime Objects
// ==================================================================
CFalconMarketContext     g_market_context;
CFalconRiskFoundation    g_risk_foundation;
CFalconCandleCache       g_candle_cache;
CFalconEvidenceFramework g_evidence_framework;
CFalconStrategyRegistry  g_strategy_registry;
CFalconReportWriter      g_report_writer;
CFalconExecutionGuard    g_execution_guard;
bool                     g_is_initialized = false;

// ==================================================================
// Expert lifecycle
// ==================================================================
int OnInit()
{
   PrintFormat("============================================================");
   PrintFormat("%s", EA_NAME);
   PrintFormat("Version: %s | Build: %s", EA_VERSION_TAG, EA_BUILD_TAG);
   PrintFormat("Stage: Evidence Framework Foundation / No strategies / No real execution");
   PrintFormat("============================================================");

   if(!g_market_context.Initialize())
      return INIT_FAILED;

   FalconSymbolContext symbol_context = g_market_context.GetSymbolContext();
   if(!g_risk_foundation.ValidateInputs(symbol_context))
      return INIT_PARAMETERS_INCORRECT;

   g_strategy_registry.PrintRegistryState();
   g_report_writer.Initialize(symbol_context);
   g_report_writer.WriteMarketDiagnosticsSnapshot(g_market_context.GetQuoteContext(), g_market_context.GetPrimaryCandleSnapshot());
   g_candle_cache.LoadAll(g_market_context);
   g_report_writer.WriteCandleCacheDiagnosticsSnapshot(g_candle_cache);

   if(!g_evidence_framework.Initialize())
      return INIT_FAILED;
   g_report_writer.WriteEvidenceDiagnosticsSnapshot(g_evidence_framework);

   g_execution_guard.AssertNoExecution();

   g_is_initialized = true;
   CFalconLogger::Info("Initialization completed successfully. EA is idle, safe, and report-ready.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_report_writer.WriteFinalSummary();
   CFalconLogger::Info(StringFormat("Deinitializing. Reason=%d", reason));
   g_is_initialized = false;
}

void OnTick()
{
   if(!g_is_initialized)
      return;

   // v0.4.0 intentionally does not detect strategies and does not send orders.
   // Future pipeline:
   // MarketContext -> CandleCache -> Narrative -> StrategyEngine -> Evidence -> Guard -> TradePlan -> Shadow/Paper/Demo/Live Executor -> ReportWriter
   return;
}

// ==================================================================
// End of file
// ==================================================================
