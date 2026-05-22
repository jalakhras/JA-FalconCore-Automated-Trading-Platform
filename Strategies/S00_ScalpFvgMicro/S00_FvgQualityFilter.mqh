//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_FvgQualityFilter.mqh            |
//| R1.1a - the three quality filters: SIZE, ATR, TREND.             |
//| Pure-function evaluator. No state. No file I/O. No lookahead     |
//| surface here - all inputs (gap_size_points, atr_m5, trend_ma_m5, |
//| spot_price) are already sourced from CLOSED bars by the detector.|
//+------------------------------------------------------------------+
#ifndef FALCON_S00_FVG_QUALITY_FILTER_MQH
#define FALCON_S00_FVG_QUALITY_FILTER_MQH

// Direction enum shared across S00 strategy files. Defined here so the
// filter is independent of the detector header (clean dependency
// direction: Detector includes Filter, not vice versa).
enum ENUM_S00_FVG_DIRECTION
{
   S00_FVG_DIR_NONE     = 0,
   S00_FVG_DIR_BULLISH  = 1,
   S00_FVG_DIR_BEARISH  = 2
};

class CS00FvgQualityFilter
{
public:
   //----------------------------------------------------------------
   // Evaluate: returns true iff the gap passes all three filters.
   // On failure, sets reject_reason to one of: "SIZE", "ATR", "TREND".
   //
   // Per ScalpFvgMicro_SPEC §3:
   //   3.1 SIZE   - gap_size_points >= MinGapPoints
   //   3.2 ATR    - gap_size_points >= ATR(M5, AtrPeriod) [in points]
   //                                  * GapAtrMultiplier
   //   3.3 TREND  - bullish FVG accepted only if spot > trend MA;
   //                bearish FVG accepted only if spot < trend MA.
   //
   // Order is short-circuit: first failure wins. The diagnostic CSV
   // sees one reason per rejected gap (the cheapest one to evaluate),
   // which keeps later analysis simple.
   //----------------------------------------------------------------
   static bool Evaluate(const double gap_size_points,
                        const ENUM_S00_FVG_DIRECTION direction,
                        const double atr_m5,
                        const double trend_ma_m5,
                        const double spot_price,
                        string &reject_reason)
   {
      reject_reason = "";

      // 3.1 Size filter.
      if(gap_size_points < MinGapPoints)
      {
         reject_reason = "SIZE";
         return false;
      }

      // 3.2 ATR thrust filter. Convert ATR (price units) -> points for
      // an apples-to-apples comparison with gap_size_points. Skip the
      // check if ATR is unavailable (handle not warm, history short)
      // so the SIZE filter remains the sole reason for rejection.
      if(atr_m5 > 0.0 && _Point > 0.0)
      {
         const double atr_points           = atr_m5 / _Point;
         const double atr_threshold_points = atr_points * GapAtrMultiplier;
         if(gap_size_points < atr_threshold_points)
         {
            reject_reason = "ATR";
            return false;
         }
      }

      // 3.3 Trend filter. Skip if trend MA is unavailable so the
      // remaining filters keep their meaning instead of silently
      // accepting against an unknown trend.
      if(trend_ma_m5 > 0.0 && spot_price > 0.0)
      {
         if(direction == S00_FVG_DIR_BULLISH && spot_price <= trend_ma_m5)
         {
            reject_reason = "TREND";
            return false;
         }
         if(direction == S00_FVG_DIR_BEARISH && spot_price >= trend_ma_m5)
         {
            reject_reason = "TREND";
            return false;
         }
      }

      return true;
   }
};

#endif // FALCON_S00_FVG_QUALITY_FILTER_MQH
