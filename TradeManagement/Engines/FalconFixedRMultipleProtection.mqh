//+------------------------------------------------------------------+
//| TradeManagement/Engines/FalconFixedRMultipleProtection.mqh       |
//| R1.5a - Phase 3a: the one and only protection policy.            |
//|                                                                  |
//| FixedRMultiple protection. It arms ONCE, when unrealised profit  |
//| reaches a tuned multiple of the original risk R, and moves the   |
//| stop to a point computed from the broker entry with a tuned      |
//| offset. It never arms early (the governing lesson that killed    |
//| S00): arming is by R-multiple - adaptive, late by nature - not   |
//| by a fixed magic point threshold, and the minimum trigger is     |
//| structurally clamped to 1.0R.                                    |
//|                                                                  |
//| One-direction only: if the computed stop does not improve the    |
//| current stop (does not reduce risk), the decision is NO_ACTION.  |
//| The stop is never walked back.                                   |
//|                                                                  |
//| On R (R1.5a-fix): R is sized off ctx.structural_stop_price - the |
//| strategy's structural stop, carried from entry via the registry  |
//| - NOT off the broker SL. The broker SL is the wide LOCK-parity    |
//| emergency envelope (a bounded-loss safety net behind protection), |
//| which is 30-500x the structural risk; sizing R off it kept the    |
//| engine from ever arming. With the structural stop absent (0.0)    |
//| the policy disarms safely. After arming, the one-direction guard  |
//| makes every later evaluation idempotent (the recomputed new_sl    |
//| equals the now-current stop, so it does not improve and returns   |
//| NO_ACTION) - so the policy fires exactly once per position.       |
//+------------------------------------------------------------------+
#ifndef FALCON_FIXED_R_MULTIPLE_PROTECTION_MQH
#define FALCON_FIXED_R_MULTIPLE_PROTECTION_MQH

#include "FalconProtectionPolicyContract.mqh"

class CFalconFixedRMultipleProtection : public CFalconProtectionPolicy
{
private:
   FalconTradeDecision NoAction(const string reason)
   {
      FalconTradeDecision d;
      d.action         = FALCON_TM_NO_ACTION;
      d.new_sl         = 0.0;
      d.close_fraction = 0.0;
      d.reason         = reason;
      return d;
   }

public:
   virtual string PolicyId() { return "FIXED_R_MULTIPLE"; }

   virtual FalconTradeDecision EvaluateProtection(const FalconManagedPositionContext &ctx)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return NoAction("invalid symbol point");

      // 1) Original risk R, measured from the STRATEGY's structural stop
      //    carried in the context (R1.5a-fix), NOT the broker SL. The broker
      //    SL is the wide emergency envelope (calibrated to a bounded loss
      //    cap), which inflated R 30-500x and kept the engine from ever
      //    arming. Safety guard: no structural stop in context (0.0) or a
      //    non-sensical R => disarm; never arm off a missing input.
      if(ctx.structural_stop_price <= 0.0)
         return NoAction("no structural stop in context - protection disarmed");
      double r_price = MathAbs(ctx.broker_entry_price - ctx.structural_stop_price);
      if(r_price <= 0.0)
         return NoAction("no structural stop in context - protection disarmed");

      // 2) Unrealised profit in the trade direction, priced at the side
      //    the position would exit on (bid for buys, ask for sells).
      double profit_price = (ctx.direction == FALCON_DIRECTION_BUY)
                              ? (ctx.current_bid - ctx.broker_entry_price)
                              : (ctx.broker_entry_price - ctx.current_ask);

      // 3) Arming threshold. The minimum trigger is clamped to 1.0R: this
      //    is the structural guard against early protection (reject < 1.0).
      double trigger = MathMax(1.0, Protection_TriggerRMultiple);
      if(profit_price < trigger * r_price)
         return NoAction(StringFormat("not armed: profit %.1f pts < %.2fR (%.1f pts)",
                                      profit_price / point, trigger, (trigger * r_price) / point));

      // 4) Computed stop: offset from entry. Positive offset locks a small
      //    loss (stop just under entry for buys / over for sells); negative
      //    locks a small profit. Offset is in points.
      double offset_price = (double)Protection_StopOffsetPoints * point;
      double new_sl = (ctx.direction == FALCON_DIRECTION_BUY)
                        ? (ctx.broker_entry_price - offset_price)
                        : (ctx.broker_entry_price + offset_price);
      new_sl = NormalizeDouble(new_sl, _Digits);

      // 5) One-direction guard: only accept a stop that improves (reduces
      //    risk vs) the current stop. Never walk the stop back.
      bool improves = (ctx.direction == FALCON_DIRECTION_BUY)
                        ? (new_sl > ctx.current_sl)
                        : (new_sl < ctx.current_sl);
      if(!improves)
         return NoAction(StringFormat("armed but new_sl %s does not improve current %s",
                                      DoubleToString(new_sl, _Digits),
                                      DoubleToString(ctx.current_sl, _Digits)));

      FalconTradeDecision d;
      d.action         = FALCON_TM_MODIFY_SL;
      d.new_sl         = new_sl;
      d.close_fraction = 0.0;
      d.reason         = StringFormat("armed at %.2fR (profit %.1f pts >= %.1f pts); move SL to entry%+d pts",
                                      trigger, profit_price / point, (trigger * r_price) / point,
                                      -Protection_StopOffsetPoints);
      return d;
   }
};

#endif // FALCON_FIXED_R_MULTIPLE_PROTECTION_MQH
