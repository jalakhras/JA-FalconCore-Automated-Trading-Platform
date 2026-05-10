//+------------------------------------------------------------------+
//|                     JA_FalconCore_Automated_Trading_Platform.mq5 |
//|                     JA FalconCore Automated Trading Platform      |
//|                     Version: v0.1.1 - RefreshRates Compile Hotfix |
//+------------------------------------------------------------------+
#property copyright "JA FalconCore Automated Trading Platform"
#property version   "1.011"
#property strict

#define EA_NAME        "JA FalconCore Automated Trading Platform"
#define EA_VERSION_TAG "v0.1.1"
#define EA_BUILD_TAG   "RefreshRatesCompileHotfix_NoExecution"

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
// Keep this list small and explicit. All engines are OFF in v0.1.1.
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
// v0.1.1 keeps the report contract and fixes MQL5 compile compatibility.
// Trade rows will be written later by Shadow/Paper/Demo engines.
// ==================================================================
input group "04 - Reporting / التقارير";
input bool EnableMainReport                 = true;
input bool EnableRejectedReport             = true;
input bool EnableEvidenceReport             = true;
input bool EnableVerboseExpertsLog          = true;

// ==================================================================
// Core Data Contracts - v0.1.1
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

string FalconTimeToString(const datetime value)
{
   if(value <= 0)
      return "";
   return TimeToString(value, TIME_DATE | TIME_SECONDS);
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
// Market Context Provider - v0.1.0 minimal symbol metadata only
// ==================================================================
class CFalconMarketContext
{
private:
   FalconSymbolContext m_symbol;

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

      CFalconLogger::Info(StringFormat("SymbolContext initialized: %s | Digits=%d | Point=%.10f | Contract=%.2f | MinLot=%.2f | Step=%.2f | StopsLevel=%d",
                                       m_symbol.symbol,
                                       m_symbol.digits,
                                       m_symbol.point,
                                       m_symbol.contract_size,
                                       m_symbol.min_lot,
                                       m_symbol.lot_step,
                                       (int)m_symbol.stops_level_points));
      return true;
   }

   FalconSymbolContext GetSymbolContext()
   {
      return m_symbol;
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
      return true;
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
         CFalconLogger::Error("HARD SAFETY BLOCK: EnableRealExecution must remain false in v0.1.0.");
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
// Strategy Registry - switches only. No engine logic in v0.1.0.
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
      CFalconLogger::Info(StringFormat("StrategyRegistry initialized. EnabledStrategies=%d. All enabled strategies remain observe-only in v0.1.0.", CountEnabledStrategies()));
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
      m_trade_report_file  = "JA_FalconCore_TradeLifecycle_v0_1_1.csv";
      m_summary_report_file= "JA_FalconCore_Summary_v0_1_1.csv";
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
// Execution Guard - real trading intentionally impossible in v0.1.0.
// ==================================================================
class CFalconExecutionGuard
{
public:
   bool CanSendRealOrders()
   {
      // v0.1.0 is a contracts/reporting foundation build. Real execution is not allowed even if the input is changed.
      return false;
   }

   void AssertNoExecution()
   {
      CFalconLogger::Info("ExecutionGuard active: OrderSend / trade execution is intentionally disabled in v0.1.0.");
   }
};

// ==================================================================
// Global Runtime Objects
// ==================================================================
CFalconMarketContext     g_market_context;
CFalconRiskFoundation    g_risk_foundation;
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
   PrintFormat("Stage: Core contracts + report writer foundation hotfix / No strategies / No real execution");
   PrintFormat("============================================================");

   if(!g_market_context.Initialize())
      return INIT_FAILED;

   FalconSymbolContext symbol_context = g_market_context.GetSymbolContext();
   if(!g_risk_foundation.ValidateInputs(symbol_context))
      return INIT_PARAMETERS_INCORRECT;

   g_strategy_registry.PrintRegistryState();
   g_report_writer.Initialize(symbol_context);
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

   // v0.1.1 intentionally does not detect strategies and does not send orders.
   // Future pipeline:
   // MarketContext -> Narrative -> StrategyEngine -> Evidence -> Guard -> TradePlan -> Shadow/Paper/Demo/Live Executor -> ReportWriter
   return;
}

// ==================================================================
// End of file
// ==================================================================
