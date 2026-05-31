//+------------------------------------------------------------------+
//| Router/FalconStrategyRegistry.mqh                                |
//| R0.5: verbatim move of CFalconStrategyRegistry from main .mq5.   |
//| Depends on: Core (Enums, DataStructures, Logger) and the         |
//| Strategy-switch / Shadow-mode `input` block declared further     |
//| down in the main .mq5 (MQL5 two-pass parse resolves them at      |
//| method-body compile time).                                       |
//+------------------------------------------------------------------+
#ifndef FALCON_ROUTER_STRATEGY_REGISTRY_MQH
#define FALCON_ROUTER_STRATEGY_REGISTRY_MQH

// ==================================================================
// First Shadow Strategy Adapter Shell - v0.13.1
// This registry only describes strategies and their safety stage.
// It does not execute detectors, does not produce signals, and does not send orders.
// ==================================================================
class CFalconStrategyRegistry
{
private:
   FalconStrategyRegistryEntry m_entries[];
   int                         m_entry_count;
   bool                        m_initialized;

   void Reset()
   {
      ArrayResize(m_entries, 0);
      m_entry_count = 0;
      m_initialized = false;
   }

   void AddEntry(const string strategy_id,
                 const string strategy_name,
                 const string engine_id,
                 const ENUM_FALCON_STRATEGY_GROUP strategy_group,
                 const bool input_enabled,
                 const ENUM_FALCON_ENGINE_HEALTH health_status,
                 const ENUM_FALCON_ENGINE_STATUS max_allowed_stage,
                 const bool shadow_allowed,
                 const bool paper_allowed,
                 const bool demo_allowed,
                 const bool live_allowed,
                 const string notes)
   {
      int index = m_entry_count;
      ArrayResize(m_entries, index + 1);
      m_entries[index].strategy_id       = strategy_id;
      m_entries[index].strategy_name     = strategy_name;
      m_entries[index].engine_id         = engine_id;
      m_entries[index].strategy_group    = strategy_group;
      m_entries[index].input_enabled     = input_enabled;
      m_entries[index].health_status     = health_status;
      m_entries[index].max_allowed_stage = max_allowed_stage;
      m_entries[index].shadow_allowed    = shadow_allowed;
      m_entries[index].paper_allowed     = paper_allowed;
      m_entries[index].demo_allowed      = demo_allowed;
      m_entries[index].live_allowed      = false; // v0.x never allows live strategy execution.
      m_entries[index].notes             = notes;
      m_entry_count++;
   }

public:
   CFalconStrategyRegistry()
   {
      Reset();
   }

   bool Initialize()
   {
      Reset();

      AddEntry("FVG_MICRO_RETEST", "FVG Micro Retest Engine", "SCALP.FVG_MICRO",
               FALCON_STRATEGY_GROUP_CORE, EnableStrategy_FvgMicroRetest,
               FALCON_ENGINE_HEALTH_CORE_WINNER, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Legacy indicator core winner. v0.18.4 allows ShadowSmoke activation when FVG runtime pipeline is enabled; still Shadow-first and no live execution.");

      AddEntry("TAIL_SMART_RETURN", "Tail Smart Return Strategy", "PRICE.TAIL_RETURN",
               FALCON_STRATEGY_GROUP_PRICE_ACTION, EnableStrategy_TailSmartReturn,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Strategy rewritten from candle-tail retest concept. H1 zone then LTF confirmation.");

      AddEntry("MOMENTUM_CROSS_8_20", "Momentum Cross 8/20 Strategy", "CONFIRM.MA_8_20",
               FALCON_STRATEGY_GROUP_CONFIRMATION, EnableStrategy_MomentumCross820,
               FALCON_ENGINE_HEALTH_WATCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Golden/Death Cross 8/20. Confirmation-first, not a priority execution engine.");

      AddEntry("CHECK_MARK_LIQUIDITY_SWEEP", "Check Mark Liquidity Sweep Reversal", "OPENING.CHECK_MARK",
               FALCON_STRATEGY_GROUP_OPENING, EnableStrategy_CheckMarkLiquiditySweep,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Opening 15m manipulation/blowoff plus retest and pivot confirmation.");

      AddEntry("DOUBLE_BOX_WICK_CONFIRMATION", "Double Box Wick Confirmation Strategy", "LIQUIDITY.DOUBLE_BOX",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_DoubleBoxWickConfirmation,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Previous-day box plus pre/post-market box with wick confirmation.");

      AddEntry("TOUCH_TURN_OPENING_RANGE", "Touch & Turn Opening Range Scalper", "OPENING.TOUCH_TURN",
               FALCON_STRATEGY_GROUP_OPENING, EnableStrategy_TouchTurnOpeningRange,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "First 15m range, ATR liquidity candle, edge touch then rotation back inside.");

      AddEntry("MAGIC_LIQUIDITY_PITCHFORK", "Magic Liquidity Lines + Pitchfork Confirmation", "LIQUIDITY.MAGIC_LINES",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_MagicLiquidityPitchfork,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "H1 highs/lows/breakout zones with pitchfork candle confirmation.");

      AddEntry("DAILY_LIQUIDITY_BOX", "Daily Liquidity Box + Pitchfork Confirmation", "LIQUIDITY.DAILY_BOX",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_DailyLiquidityBox,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Previous-day high/low box. Buy lower edge, sell upper edge after confirmation.");

      AddEntry("QUICK_FLIP_OPENING_LIQUIDITY", "Quick Flip Opening Liquidity Scalper", "OPENING.QUICK_FLIP",
               FALCON_STRATEGY_GROUP_OPENING, EnableStrategy_QuickFlipOpeningLiquidity,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Opening 15m liquidity candle, reversal candle outside range within 90 minutes.");

      AddEntry("FSE_PATTERN_FAILURE_ENTRY", "First Sign Execution Pattern Failure Entry", "PRICE.FSE_FAILURE",
               FALCON_STRATEGY_GROUP_PRICE_ACTION, EnableStrategy_FSEPatternFailureEntry,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "Early entry after previous pattern failure at a known level. Also called Unsharp/FSE.");

      AddEntry("TWO_LIQUIDITY_LINES_15M", "Two Liquidity Lines + 15M Confirmation", "LIQUIDITY.TWO_LINES_15M",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_TwoLiquidityLines15M,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "H1 swing high/low lines and 15M reversal confirmation. No middle trades.");

      AddEntry("GOLDEN_LIQUIDITY_5M_ENTRY", "Golden Liquidity Zones + 5M Pitchfork Entry", "LIQUIDITY.GOLDEN_5M",
               FALCON_STRATEGY_GROUP_LIQUIDITY, EnableStrategy_GoldenLiquidity5MEntry,
               FALCON_ENGINE_HEALTH_RESEARCH, FALCON_ENGINE_SHADOW,
               true, false, false, false,
               "H1 liquidity zones with M5 pitchfork confirmation. Anti-random-5M usage.");

      m_initialized = true;
      return true;
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

   int CountRegisteredStrategies()
   {
      return m_entry_count;
   }

   int CountEnabledStrategies()
   {
      int count = 0;
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].input_enabled)
            count++;
      }
      return count;
   }

   int CountByGroup(const ENUM_FALCON_STRATEGY_GROUP group)
   {
      int count = 0;
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].strategy_group == group)
            count++;
      }
      return count;
   }

   int CountByHealth(const ENUM_FALCON_ENGINE_HEALTH health_status)
   {
      int count = 0;
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].health_status == health_status)
            count++;
      }
      return count;
   }

   bool GetEntryByIndex(const int index, FalconStrategyRegistryEntry &entry)
   {
      if(index < 0 || index >= m_entry_count)
         return false;
      entry = m_entries[index];
      return true;
   }

   bool GetEntryById(const string strategy_id, FalconStrategyRegistryEntry &entry)
   {
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].strategy_id == strategy_id)
         {
            entry = m_entries[i];
            return true;
         }
      }
      return false;
   }

   bool AnyLiveAllowed()
   {
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].live_allowed)
            return true;
      }
      return false;
   }

   void PrintRegistryState()
   {
      CFalconLogger::Info(StringFormat("StrategyRegistry initialized. Registered=%d | EnabledByInputs=%d | CoreWinners=%d | Research=%d | Watch=%d | LiveAllowed=%s | Stage=REGISTRY_ONLY_v0.13.1",
                                       CountRegisteredStrategies(),
                                       CountEnabledStrategies(),
                                       CountByHealth(FALCON_ENGINE_HEALTH_CORE_WINNER),
                                       CountByHealth(FALCON_ENGINE_HEALTH_RESEARCH),
                                       CountByHealth(FALCON_ENGINE_HEALTH_WATCH),
                                       (AnyLiveAllowed() ? "true" : "false")));
   }
};

#endif // FALCON_ROUTER_STRATEGY_REGISTRY_MQH
