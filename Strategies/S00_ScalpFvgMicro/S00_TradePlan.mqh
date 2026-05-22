//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_TradePlan.mqh                   |
//| R1.1b - builds the per-trade plan: entry, stop, target, 1:2.     |
//|                                                                  |
//| Per ScalpFvgMicro_SPEC §5 + JA_FalconCore_R1_1b_SPEC §3:         |
//|   Stop   = beyond the FAR edge of the FVG, offset by S00_StopBuffer
//|             (bullish: gap_low - buffer; bearish: gap_high + buf).|
//|   Target = nearest 3-bar swing high (bullish) or swing low       |
//|             (bearish) found in the most recent S00_SwingLookback |
//|             closed M5 bars.                                      |
//|   Gate   = target_distance / stop_distance must be >= 2.0,       |
//|             otherwise the plan is rejected (no entry).           |
//|                                                                  |
//| ZERO LOOKAHEAD: every candle read uses                           |
//| CFalconMarketContext::GetCandleSnapshot(PERIOD_M5, k, ...) with  |
//| k >= 1. The 3-bar swing test uses neighbors at k-1 and k+1 so    |
//| the scan range is k in [2, S00_SwingLookback]; k=1 is excluded   |
//| (its left neighbor would be the live bar at shift 0).            |
//+------------------------------------------------------------------+
#ifndef FALCON_S00_TRADEPLAN_MQH
#define FALCON_S00_TRADEPLAN_MQH

struct S00TradePlan
{
   bool                   valid;
   ENUM_S00_FVG_DIRECTION direction;
   double                 entry_price;
   double                 stop_loss;
   double                 target;
   double                 stop_distance_points;
   double                 target_distance_points;
   double                 target_to_stop_ratio;
   string                 reject_reason;        // "" | "BAD_DIRECTION" | "ZERO_STOP" | "NO_SWING" | "RR_TOO_LOW"
};

class CS00TradePlanBuilder
{
private:
   //----------------------------------------------------------------
   // Find the nearest 3-bar swing HIGH whose high > entry_price.
   // "Nearest" = lowest shift k (closest to now in time). Scan
   // k = 2 .. S00_SwingLookback (k=1 excluded - its left neighbor
   // would be shift 0 = live bar). Returns false if the lookback
   // window contains no qualifying swing high above entry.
   //----------------------------------------------------------------
   static bool FindSwingHighAbove(CFalconMarketContext &market_context,
                                  const double entry_price,
                                  double &swing_price)
   {
      swing_price = 0.0;
      if(S00_SwingLookback < 3) return false;
      for(int k = 2; k <= S00_SwingLookback; k++)
      {
         FalconCandleSnapshot left, mid, right;
         if(!market_context.GetCandleSnapshot(PERIOD_M5, k - 1, left))  continue;
         if(!market_context.GetCandleSnapshot(PERIOD_M5, k,     mid))   continue;
         if(!market_context.GetCandleSnapshot(PERIOD_M5, k + 1, right)) continue;
         if(mid.high > left.high && mid.high > right.high && mid.high > entry_price)
         {
            swing_price = mid.high;
            return true;
         }
      }
      return false;
   }

   //----------------------------------------------------------------
   // Mirror: nearest 3-bar swing LOW whose low < entry_price.
   //----------------------------------------------------------------
   static bool FindSwingLowBelow(CFalconMarketContext &market_context,
                                 const double entry_price,
                                 double &swing_price)
   {
      swing_price = 0.0;
      if(S00_SwingLookback < 3) return false;
      for(int k = 2; k <= S00_SwingLookback; k++)
      {
         FalconCandleSnapshot left, mid, right;
         if(!market_context.GetCandleSnapshot(PERIOD_M5, k - 1, left))  continue;
         if(!market_context.GetCandleSnapshot(PERIOD_M5, k,     mid))   continue;
         if(!market_context.GetCandleSnapshot(PERIOD_M5, k + 1, right)) continue;
         if(mid.low < left.low && mid.low < right.low && mid.low < entry_price)
         {
            swing_price = mid.low;
            return true;
         }
      }
      return false;
   }

public:
   //----------------------------------------------------------------
   // Build a complete trade plan for a confirmed FVG.
   //
   // `fvg`         - the FVG record produced by CS00FvgDetector.
   // `entry_price` - the next bar's OPEN price (caller passes a
   //                 closed-bar field; see CS00EntryLogic).
   // `market_context` - used to scan closed bars for the swing target.
   //
   // Sets plan_out.valid = true only when all gates pass. On failure,
   // plan_out.valid = false and plan_out.reject_reason is one of:
   //   "BAD_DIRECTION" | "ZERO_STOP" | "NO_SWING" | "RR_TOO_LOW".
   //----------------------------------------------------------------
   static bool Build(const S00FvgRecord &fvg,
                     const double entry_price,
                     CFalconMarketContext &market_context,
                     S00TradePlan &plan_out)
   {
      plan_out.valid                  = false;
      plan_out.direction              = fvg.direction;
      plan_out.entry_price            = entry_price;
      plan_out.stop_loss              = 0.0;
      plan_out.target                 = 0.0;
      plan_out.stop_distance_points   = 0.0;
      plan_out.target_distance_points = 0.0;
      plan_out.target_to_stop_ratio   = 0.0;
      plan_out.reject_reason          = "";

      const double point = (_Point > 0.0 ? _Point : 1.0);
      const double buffer_price = S00_StopBuffer * point;

      // Stop: beyond the far edge of the FVG.
      if(fvg.direction == S00_FVG_DIR_BULLISH)
         plan_out.stop_loss = fvg.gap_low  - buffer_price;
      else if(fvg.direction == S00_FVG_DIR_BEARISH)
         plan_out.stop_loss = fvg.gap_high + buffer_price;
      else
      {
         plan_out.reject_reason = "BAD_DIRECTION";
         return false;
      }

      const double stop_distance = MathAbs(entry_price - plan_out.stop_loss);
      if(stop_distance <= 0.0)
      {
         plan_out.reject_reason = "ZERO_STOP";
         return false;
      }

      // Target: nearest swing in the scan window.
      double swing       = 0.0;
      bool   swing_found = false;
      if(fvg.direction == S00_FVG_DIR_BULLISH)
         swing_found = FindSwingHighAbove(market_context, entry_price, swing);
      else
         swing_found = FindSwingLowBelow(market_context, entry_price, swing);

      if(!swing_found)
      {
         plan_out.reject_reason = "NO_SWING";
         return false;
      }
      plan_out.target = swing;

      const double target_distance = MathAbs(plan_out.target - entry_price);

      plan_out.stop_distance_points   = stop_distance   / point;
      plan_out.target_distance_points = target_distance / point;
      plan_out.target_to_stop_ratio   = (stop_distance > 0.0
                                          ? target_distance / stop_distance
                                          : 0.0);

      // 1:2 minimum ratio gate (per spec §3.2: explicit cost filter).
      if(plan_out.target_to_stop_ratio < 2.0)
      {
         plan_out.reject_reason = "RR_TOO_LOW";
         return false;
      }

      plan_out.valid = true;
      return true;
   }
};

#endif // FALCON_S00_TRADEPLAN_MQH
