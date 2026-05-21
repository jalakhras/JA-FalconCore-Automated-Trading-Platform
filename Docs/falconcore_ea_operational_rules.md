# JA FalconCore EA — Operational Safety Rules

## قواعد التشغيل الحقيقي — ما لا يستطيع المؤشر تعليمه

**Scope:** EA-specific execution rules (not architectural)  
**Complements:** Anti-Complexity Charter + Master Build Plan v0.0.0  
**Reality:** EA يلعب بمال حقيقي. كل قاعدة هنا تمنع خسارة فعلية.

---

## 📑 المحتويات

- [Part A — مراجعة الـ Charter من منظور EA](#part-a)
- [Part B — القواعد التشغيلية الحرجة (10 قواعد)](#part-b)
- [Part C — الثغرات في خطتك v0.0.0](#part-c)
- [Part D — الإضافات المطلوبة على Inputs](#part-d)
- [Part E — Pre-Live Checklist](#part-e)

---

<a name="part-a"></a>
## Part A — مراجعة الـ Charter من منظور EA

### ما يبقى صحيحاً 100%

```
✓ One-in-one-out rule         → ينطبق على EA modules
✓ Hard budgets (15 modules)   → ينطبق
✓ Module retirement system    → ينطبق
✓ Refactor versions إجبارية   → ينطبق
✓ No shared state             → أهم في EA من المؤشر
✓ No lookahead                → ينطبق
✓ Symmetry audit              → ينطبق
```

### ما يحتاج تعديل لـ EA

```
⚠ Budget: 500 lines/file
   في EA، بعض الملفات منطقياً أطول:
   - RiskManager: يستحق 600-700 (مخاطر متعددة)
   - FalconExecutor: يستحق 600-800 (order lifecycle معقد)
   - الباقي يبقى 500
   
⚠ Budget: 20 globals
   في EA لازم globals إضافية مبررة:
   - g_lastSync (server time)
   - g_brokerStopsLevel (cached)
   - g_accountInfo (cached)
   - g_killSwitchActive
   - g_emergencyMode
   عدّل البودجت لـ 30 globals، لكن كل واحد موثق ومبرر.

⚠ Budget: 100+ trades قبل تقييم module
   في EA على Demo: 100 صفقة ممكن تأخذ شهرين+
   في حين أن problems ظاهرة بعد 20-30 صفقة
   التعديل: تقييم مبدئي بعد 30 صفقة، تقييم نهائي بعد 100
```

### ما كان ناقص في الـ Charter

```
✗ ما تحدث عن order lifecycle
✗ ما تحدث عن state consistency مع البروكر
✗ ما تحدث عن restart safety
✗ ما تحدث عن magic number discipline
✗ ما تحدث عن spread/slippage في NAS100
```

هذي محور Part B.

---

<a name="part-b"></a>
## Part B — القواعد التشغيلية الحرجة (10 قواعد)

### قاعدة 1 — Magic Number Discipline

**المشكلة:** EA متعدد الـ engines لازم يميّز صفقاته. بدون هذا:
- Engine A ممكن يقفل صفقة Engine B بالغلط
- Reports تخلط النتائج
- Manual close vs EA close ما تفرّق

**القاعدة:**

```cpp
// كل engine له magic number فريد
#define FC_MAGIC_BASE 1000000

// Format: 1XXSSSS where:
//   XX  = engine family (10-99)
//   SSSS = sub-strategy id (0001-9999)
//
// Examples:
#define FC_MAGIC_FVG_MICRO          1100001
#define FC_MAGIC_BREAKOUT_RETEST    1200001
#define FC_MAGIC_TREND_PULLBACK     1300001
#define FC_MAGIC_REVERSAL_PITCHFORK 1400001
#define FC_MAGIC_OPENING_FLIP       1500001

// أي عملية على position:
bool IsMyPosition(ulong ticket, int expectedMagic)
{
   if(!PositionSelectByTicket(ticket)) return false;
   long magic = PositionGetInteger(POSITION_MAGIC);
   return (magic == expectedMagic);
}

// كل engine يرى صفقاته فقط:
void EnumerateMyPositions(int magicNumber)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(IsMyPosition(ticket, magicNumber))
      {
         // safe to manage
      }
   }
}
```

**الحماية:** ما في engine يقدر يلمس صفقة engine ثاني، حتى لو حصل bug.

### قاعدة 2 — Order Failure Classification

**المشكلة:** OrderSend/Modify/Close يمكن تفشل لعشرات الأسباب. بدون تصنيف، الـ EA يعيد المحاولة بشكل غبي أو يستسلم بشكل غبي.

**القاعدة:**

```cpp
enum ENUM_ORDER_FAIL_CLASS
{
   FAIL_RETRYABLE,        // requote, off quotes, busy
   FAIL_FATAL,            // invalid stops, no money, market closed
   FAIL_NEEDS_REFRESH,    // prices changed, refresh and retry once
   FAIL_BROKER_LIMIT,     // stops level, freeze level, max lots
   FAIL_CONNECTION,       // network issue
   FAIL_UNKNOWN           // log loudly, do not retry
};

ENUM_ORDER_FAIL_CLASS ClassifyError(int errorCode)
{
   switch(errorCode)
   {
      case TRADE_RETCODE_REQUOTE:           
      case TRADE_RETCODE_PRICE_OFF:         return FAIL_NEEDS_REFRESH;
      
      case TRADE_RETCODE_INVALID_STOPS:     
      case TRADE_RETCODE_TRADE_DISABLED:    
      case TRADE_RETCODE_MARKET_CLOSED:     
      case TRADE_RETCODE_NO_MONEY:          return FAIL_FATAL;
      
      case TRADE_RETCODE_INVALID_VOLUME:    return FAIL_BROKER_LIMIT;
      
      case TRADE_RETCODE_CONNECTION:        return FAIL_CONNECTION;
      
      case TRADE_RETCODE_DONE_PARTIAL:      // success-ish, handle separately
      default:                              return FAIL_UNKNOWN;
   }
}

// Per-class response policy:
//   FAIL_NEEDS_REFRESH → refresh prices, retry once
//   FAIL_RETRYABLE     → retry up to 3 times with 100ms gap
//   FAIL_FATAL         → log, do NOT retry, alert
//   FAIL_BROKER_LIMIT  → recompute (e.g. adjust lot/SL distance), retry once
//   FAIL_CONNECTION    → wait 1s, retry up to 5 times
//   FAIL_UNKNOWN       → log loudly, halt new entries, alert
```

**القاعدة الذهبية:** لا تعيد المحاولة على FAIL_FATAL. لا تستسلم على FAIL_RETRYABLE.

### قاعدة 3 — State Recovery on Restart

**المشكلة:** EA يتوقف (crash, restart, terminal reload). كل state في الذاكرة يضيع.
- ما يدري عن partials اللي حدثت
- ما يدري عن الـ state machine state لكل position
- ما يدري إذا runner كان active

**القاعدة:**

```cpp
// عند OnInit، إعادة بناء state من البروكر + ملف state على القرص

void OnInit()
{
   // ... standard init ...
   
   ReconstructStateFromBroker();
}

void ReconstructStateFromBroker()
{
   // 1. Enumerate all positions with our magic numbers
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      long magic = PositionGetInteger(POSITION_MAGIC);
      
      if(!IsOurMagic(magic)) continue;
      
      // 2. Try to load state from persistence file
      if(FileExists(StateFileName(ticket)))
      {
         LoadStateFromDisk(ticket);
      }
      else
      {
         // 3. State file missing — reconstruct minimum from broker
         InferStateFromPositionData(ticket);
         LogWarning("State file missing for ticket " + 
                    IntegerToString(ticket) + 
                    " — entering MINIMAL_RECOVERY mode");
         SetTradeMode(ticket, TRADE_MODE_MINIMAL_RECOVERY);
      }
   }
   
   // 4. In MINIMAL_RECOVERY: only manage SL, do not modify, do not add
   //    Wait for natural exit (SL/TP), then resume normal operation
}

void OnTrade()  // or OnTradeTransaction
{
   // After every trade event, persist state to disk
   PersistAllManagedTradesState();
}
```

**القاعدة الذهبية:** بعد أي restart، EA يدخل **MINIMAL_RECOVERY mode** للصفقات اللي ما يقدر يطمئن على state اللي يخصها. لا يحاول يكمل من النقطة المفقودة.

### قاعدة 4 — Spread & Slippage Guards (خاص NAS100)

**المشكلة:** NAS100 عند NY open spread يقفز من 1-2 نقطة إلى 10-20 نقطة. صفقة تُفتح في هذي النافذة تبدأ خسرانة 15 pips. على لوت 0.01 هذا 15 دولار، لكن على لوت أكبر... كارثة.

**القاعدة:**

```cpp
// Pre-trade spread guard
bool IsSpreadAcceptable(string symbol, double maxSpreadPoints)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double spreadPoints = (ask - bid) / point;
   
   if(spreadPoints > maxSpreadPoints)
   {
      LogRejection("SPREAD_TOO_WIDE", 
                   "Current: " + DoubleToString(spreadPoints, 1) + 
                   " Max: " + DoubleToString(maxSpreadPoints, 1));
      return false;
   }
   return true;
}

// Context-aware thresholds (different per session/time)
double MaxSpreadForCurrentContext()
{
   if(IsNyOpenWindow())              return 25.0;  // tolerate wider
   if(IsHighImpactNewsWindow())      return 50.0;  // very wide
   if(IsAsiaSession())               return 8.0;
   return 15.0;  // default
}

// Slippage policy on order
// Always use deviation/slippage parameter, never 0
trade.SetDeviationInPoints(20);  // not 0! 0 means "fail on any slippage"
// MUST also reject the trade if filled at > X points slippage
```

**القاعدة الذهبية:** spread guard قبل كل entry. slippage cap على كل order. لا تثق بـ default values.

### قاعدة 5 — Broker Stops Level Awareness

**المشكلة:** كل بروكر له **stops level** و **freeze level**. إذا حاولت تضع SL أقرب من stops level من السعر، الـ Modify يفشل بـ INVALID_STOPS صامت.

**القاعدة:**

```cpp
struct BrokerLimits
{
   int    stopsLevel;       // min distance for SL/TP in points
   int    freezeLevel;      // can't modify within this from price
   double minLot;
   double maxLot;
   double lotStep;
   double contractSize;
   double tickSize;
   double tickValue;
};

BrokerLimits g_brokerLimits;  // cached at OnInit

void RefreshBrokerLimits(string symbol)
{
   g_brokerLimits.stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   g_brokerLimits.freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   g_brokerLimits.minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   g_brokerLimits.maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   g_brokerLimits.lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   // ...
}

// Validate SL distance BEFORE sending
bool IsValidSlDistance(string symbol, double price, double sl, int direction)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double distance = MathAbs(price - sl) / point;
   double minDistance = g_brokerLimits.stopsLevel + 2;  // buffer
   
   if(distance < minDistance)
   {
      LogRejection("SL_TOO_CLOSE", 
                   "Required: " + IntegerToString((int)minDistance) + 
                   " Got: " + DoubleToString(distance, 1));
      return false;
   }
   return true;
}

// On modify, also check freeze level — can't modify if too close
bool CanModifyPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   double price = PositionGetDouble(POSITION_PRICE_CURRENT);
   double sl = PositionGetDouble(POSITION_SL);
   double point = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_POINT);
   
   double distance = MathAbs(price - sl) / point;
   if(distance < g_brokerLimits.freezeLevel)
   {
      LogInfo("Position frozen — too close to SL");
      return false;
   }
   return true;
}
```

**القاعدة الذهبية:** validate SL distance قبل OrderSend، وقبل كل OrderModify.

### قاعدة 6 — OnTradeTransaction as Source of Truth

**المشكلة:** قراءة position state يدوياً قد تكون متأخرة. السوق سريع. الـ EA يحسب على state قديم.

**القاعدة:**

```cpp
void OnTradeTransaction(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      // Was it our deal?
      if(!IsOurDeal(dealTicket)) return;
      
      // Distinguish: entry, partial close, full close, SL hit, TP hit
      DEAL_ENTRY entry = (DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      
      switch(entry)
      {
         case DEAL_ENTRY_IN:     
            OnTradeOpened(dealTicket);   
            break;
         case DEAL_ENTRY_OUT:    
            OnTradeClosed(dealTicket);   
            break;
         case DEAL_ENTRY_OUT_BY: 
            OnTradeClosedByOpposite(dealTicket); 
            break;
      }
      
      // Persist state immediately
      PersistState();
   }
   
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
   {
      // New pending order — track it
   }
   
   if(trans.type == TRADE_TRANSACTION_POSITION)
   {
      // Position state changed (modify, partial) — recompute
      OnPositionStateChanged(trans.position);
   }
}
```

**القاعدة الذهبية:** State changes react في OnTradeTransaction. OnTick يقرأ، ما يفترض. هذا يحل race conditions كثيرة.

### قاعدة 7 — Pre-Init Verification

**المشكلة:** EA يتم تركيبه على wrong symbol، wrong timeframe، account ما يكفي margin، إلخ. الحالات هذي ما تكتشف إلا بعد ما EA يحاول يتداول ويفشل.

**القاعدة:**

```cpp
int OnInit()
{
   // ALL verifications BEFORE any logic init
   
   // 1. Symbol verification
   if(_Symbol != "NAS100" && _Symbol != "US100" && _Symbol != "NDX")
   {
      Alert("FalconCore: Wrong symbol. Expected NAS100/US100. Got: " + _Symbol);
      return INIT_FAILED;
   }
   
   // 2. Timeframe verification (typically attached to M15 or M5)
   if(_Period != PERIOD_M5 && _Period != PERIOD_M15)
   {
      Alert("FalconCore: Wrong timeframe. Expected M5 or M15.");
      return INIT_FAILED;
   }
   
   // 3. Account checks
   if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0)
   {
      Alert("FalconCore: Trading not allowed on this account.");
      return INIT_FAILED;
   }
   
   if(AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == 0)
   {
      Alert("FalconCore: EA trading not allowed (AutoTrading button OFF).");
      return INIT_FAILED;
   }
   
   // 4. Minimum balance for risk
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance < MIN_ACCOUNT_FOR_LIVE)
   {
      Alert("FalconCore: Account balance below minimum.");
      return INIT_FAILED;
   }
   
   // 5. Broker stops level reasonable?
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel > 100)  // very unusual
   {
      Alert("FalconCore: Broker stops level too high (" + IntegerToString(stopsLevel) + ")");
      return INIT_FAILED;
   }
   
   // 6. Tester vs Live distinction logged
   if(MQLInfoInteger(MQL_TESTER))
      Print("FalconCore: Running in TESTER mode");
   else if(MQLInfoInteger(MQL_DEMO))
      Print("FalconCore: Running on DEMO account");
   else
      Print("FalconCore: Running on LIVE account — caution");
   
   // 7. EnableRealExecution sanity check
   if(EnableRealExecution && !MQLInfoInteger(MQL_TESTER))
   {
      Print("FalconCore: REAL EXECUTION ENABLED on live/demo. Confirm intent.");
   }
   
   // ... proceed with normal init
   return INIT_SUCCEEDED;
}
```

**القاعدة الذهبية:** ما يبدأ EA إذا فيه شي مش طبيعي في البيئة. يعطّل نفسه بـ INIT_FAILED.

### قاعدة 8 — Equity Emergency Stop (Last Resort)

**المشكلة:** Daily loss limit موجود في خطتك (DailyLossPercentOfCapital). لكن:
- إذا حصل bug في الـ DailyGovernance نفسه؟
- إذا فشل في تحديث الـ counter؟
- إذا حصل crash وreload لم يطّلع على loss اليوم؟

تحتاج كقاعدة ثانية مستقلة، بدائية، لا يقدر شي يتجاوزها:

**القاعدة:**

```cpp
// Independent of all engines/state machines/governance.
// Checked every tick. Cannot be disabled by any input.

void CheckEmergencyEquityStop()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Detect drawdown from initial balance of the session
   double drawdownPct = (balance - equity) / balance * 100.0;
   
   // Hard cap: 5% intraday drawdown = HARD STOP
   // This is LOWER than any user-configurable limit on purpose
   if(drawdownPct > 5.0)
   {
      g_emergencyMode = true;
      CloseAllPositions("EMERGENCY_EQUITY_STOP");
      Alert("FalconCore: EMERGENCY STOP at " + DoubleToString(drawdownPct, 2) + "% drawdown");
      
      // Disable for the rest of the session
      DisableUntilNextSession();
   }
}

void OnTick()
{
   CheckEmergencyEquityStop();  // BEFORE any other logic
   
   if(g_emergencyMode) return;
   
   // ... normal logic
}
```

**القاعدة الذهبية:** هذي القاعدة لا تستخدم أي state من الـ EA. فقط broker reality. لو كل شي ثاني فشل، هذي تنقذ الحساب.

### قاعدة 9 — Concurrent Position Discipline

**المشكلة:** EA متعدد engines يمكن يفتح صفقات متعددة. بدون قواعد:
- engine A فتح BUY على FVG
- engine B فتح BUY ثاني على Breakout
- engine C فتح BUY ثالث
الآن exposure = 3x متوقع، risk أكبر بكثير.

**القاعدة:**

```cpp
struct ExposureLimits
{
   int maxConcurrentTotal       = 3;   // كل الـ engines مجتمعة
   int maxConcurrentPerEngine   = 1;   // engine واحد ما يفتح أكثر من صفقة
   int maxConcurrentSameDirection = 2; // نفس الاتجاه
};

bool CanOpenNewPosition(int engineId, int direction)
{
   int totalOpen = CountOurPositions();
   if(totalOpen >= EXPOSURE_LIMITS.maxConcurrentTotal)
   {
      LogRejection("EXPOSURE_TOTAL_CAP", "Max concurrent reached");
      return false;
   }
   
   int sameEngine = CountOurPositions(engineId);
   if(sameEngine >= EXPOSURE_LIMITS.maxConcurrentPerEngine)
   {
      LogRejection("EXPOSURE_ENGINE_CAP", "Engine already has position");
      return false;
   }
   
   int sameDirection = CountOurPositionsByDirection(direction);
   if(sameDirection >= EXPOSURE_LIMITS.maxConcurrentSameDirection)
   {
      LogRejection("EXPOSURE_DIRECTION_CAP", "Direction cap reached");
      return false;
   }
   
   return true;
}
```

**القاعدة الذهبية:** كل engine يعرف limits المشتركة. النظام ككل ما يتجاوز الـ planned risk.

### قاعدة 10 — Tester vs Live Reality Gap

**المشكلة:** نتائج Tester ممتازة، Live تختلف. الأسباب:
- Tester ما يحاكي slippage بدقة
- Tester ما يحاكي requotes
- Tester يفترض perfect fills
- Tester يستخدم data منظفة، Live data فيها spikes

**القاعدة:**

```cpp
// كل قياس performance يفرّق بين Tester و Live
struct PerformanceReport
{
   string mode;  // "TESTER", "DEMO", "LIVE"
   double netProfit;
   double avgSlippageEntry;     // 0 in tester
   double avgSlippageExit;
   int    requoteCount;          // 0 in tester
   int    failedOrders;
   double executionLatencyMs;    // 0 in tester
};

// Acceptance criteria differs:
// Tester result: needed for design validation
// Demo result: must reach 70% of tester profit factor
// Live result: must reach 70% of demo result

// If Demo < 50% of Tester:
//   → review slippage model in tester
//   → review entry timing
//   → DO NOT increase live size
```

**القاعدة الذهبية:** Tester is a DESIGN tool. Demo is the validation. Live is the verdict. ما تثق بـ Tester وحده.

---

<a name="part-c"></a>
## Part C — الثغرات في خطتك v0.0.0 (من منظور EA)

### ثغرة 1 — ما في تعريف لـ Magic Number Strategy

خطتك تذكر "كل Strategy وكل Engine معزول". لكن **كيف** يميّز Engine صفقاته من غيره؟ هذا غير موضّح. Magic number scheme لازم يكون في v0.1.0 أو v0.2.0.

### ثغرة 2 — FalconExecutor underspecified

```
في خطتك:
"Executor وحده يملك صلاحية التنفيذ"

لكن ما في:
- تصنيف أخطاء الـ OrderSend
- retry policy
- partial fill handling
- requote handling
- timeout policy
```

هذي تفاصيل **تنفيذية** أساسية. اقترح إصدار `v0.7.x` مخصص لـ FalconExecutor operational specs.

### ثغرة 3 — ما في خطة لـ State Persistence

```
Trade State (المرحلة الحالية، partials taken, runner active...)
أين يُحفظ؟
ماذا يحدث عند restart؟
```

ProjectMemoryWriter موجود لكن للـ release-level memory، مش للـ trade-level state.

اقترح: `Reporting/TradeStatePersistenceWriter.mqh` — يكتب JSON-like state file لكل trade مفتوحة. عند OnInit يقرأ ويعيد بناء.

### ثغرة 4 — ما في Spread/Slippage Policy في Inputs

```
خطتك inputs:
- EnableRealExecution
- UseFixedLot / FixedLotSize
- UseDailyLossLimit
...

ما في:
- MaxSpreadPoints
- MaxSlippagePoints
- MinAccountBalance
- EnableEmergencyEquityStop
```

هذي EA-specific. اقترح إضافتها في group "EA Safety".

### ثغرة 5 — Shadow → Paper → Demo → Live، لكن ما في تعريف لـ Paper

```
Shadow:  لا OrderSend، فقط logging
Live:    OrderSend حقيقي
Demo:    OrderSend على demo account
Paper:   ???
```

**Paper** غير معرّف بدقة. أقترح:

```
Paper = OrderSend NOT called, لكن EA يحاكي fill/SL/TP/partial 
        داخلياً بناءً على tick data، ويسجل result كأنه حصل.
        هذا يختلف عن Shadow (الذي لا يحاكي أصلاً).
        
الفائدة: نختبر state machine بدون broker latency/slippage.
        Tester يعمل هذا تلقائياً، لكن نحتاج "Paper Mode"
        يشتغل على Live data بدون Live execution.
```

### ثغرة 6 — Engine Health System غير محدد

```
خطتك تذكر:
"AutoShadowMode: إذا تدهور الأداء، يتحول المحرك إلى Shadow"

لكن ما في:
- ما هو threshold التدهور بالضبط؟
- على كم صفقة يقاس؟
- كيف يرجع المحرك إلى Active بعد ما يتحسن؟
- ماذا لو محرك يتدهور بسبب regime change وليس bug؟
```

اقترح Engine Health Spec كـ separate document لاحقاً.

### ثغرة 7 — ما في Concurrent Position Limits

```
خطتك ما تحدد كم صفقة يقدر EA يفتح في وقت واحد.
في multi-engine setup هذا critical.
```

(See قاعدة 9 أعلاه.)

### ثغرة 8 — ما في خطة لـ Symbol-Specific Profiles

```
خطتك تستهدف NAS100. ممتاز.
لكن لو في المستقبل أضفت ES100 أو GOLD:
- contract size يختلف
- pip value يختلف
- spread behavior يختلف
- session times يختلف
```

اقترح `Core/SymbolProfiles.mqh` لكل symbol مدعوم. حتى لو حالياً NAS100 فقط، البنية تكون جاهزة.

---

<a name="part-d"></a>
## Part D — الإضافات المطلوبة على Inputs

### أضف إلى group "01 - EA Safety & Risk"

```cpp
input group "01a - EA Operational Safety";
input int    MaxSpreadPoints                = 25;      // pre-trade spread cap
input int    MaxSlippagePoints              = 20;      // order deviation
input bool   EnableEmergencyEquityStop      = true;    // hardcoded 5% DD
input double EmergencyEquityStopPct         = 5.0;     // independent of daily limit
input int    MaxConcurrentPositionsTotal    = 3;
input int    MaxConcurrentPositionsPerEngine = 1;
input int    MaxConcurrentPositionsPerDirection = 2;
input double MinAccountBalanceUsd           = 500.0;   // EA refuses to run below
```

### أضف group جديد "EA Operational"

```cpp
input group "05 - EA Operational Behavior";
input bool   EnableOrderRetryOnRetryable    = true;
input int    OrderRetryMaxAttempts          = 3;
input int    OrderRetryDelayMs              = 100;
input bool   EnableStateRecoveryOnRestart   = true;
input bool   EnableTradeStatePersistence    = true;
input string TradeStateFolder               = "FalconCore_State";
input bool   AlertOnFatalErrors             = true;
input bool   AlertOnEmergencyStop           = true;
```

### أضف group "Symbol Profile"

```cpp
input group "06 - Symbol Profile (NAS100 defaults)";
input int    BrokerStopsLevelBuffer         = 2;       // points beyond min
input double SymbolContractSize             = 0.0;     // 0 = auto from broker
input int    NyOpenWidenedSpreadWindowMin   = 30;      // wider spread tolerance
input int    NewsBlockWindowMinutes         = 30;
```

---

<a name="part-e"></a>
## Part E — Pre-Live Checklist

قبل تشغيل EA على Live account لأول مرة، يجب الإجابة بـ "نعم" على كل واحد:

```
□ Magic numbers معرّفة بشكل فريد لكل engine
□ FalconExecutor يصنّف order errors ويتعامل معها
□ Trade state persistence يعمل (test by restart EA mid-trade)
□ ReconstructStateFromBroker يعمل (test by restart)
□ Spread guard تم اختباره (try forcing wide spread)
□ Broker stops level handling مختبر (try SL too close)
□ OnTradeTransaction يلتقط كل event types
□ Pre-init verification يمنع wrong symbol/TF/account
□ Emergency equity stop مختبر بـ simulated 5% drawdown
□ Concurrent position limits محترمة (test multi-engine)
□ Tester vs Demo gap < 30% performance difference
□ Demo run > 90 days with > 100 trades
□ Demo win rate within 15% of Tester win rate
□ No fatal errors في Demo log آخر 30 يوم
□ EmergencyMode tested manually
□ All Hard Rejections من الـ Charter محترمة
□ Project Memory محدث لـ "live readiness" entry
□ Rollback path موثق (كيف نرجع لـ Demo فوراً)
□ Account balance >= MinAccountBalanceUsd × 5 (safety margin)
□ Manual intervention plan موثق (كيف نوقف EA يدوياً)
```

**أي بند غير محقق = ما تشغّل Live.**

---

## 🎯 خلاصة وتوصية

### الترتيب المقترح للإضافات

```
الإصدار القريب (بعد ما تكمل v0.36.x):
   v0.40.0 — Magic Number System + FalconExecutor Error Classification
   v0.41.0 — Trade State Persistence + Restart Recovery
   v0.42.0 — Spread/Slippage Guards + Broker Limits Caching
   v0.43.0 — OnTradeTransaction-driven State Updates
   v0.44.0 — Pre-Init Verification Pack
   v0.45.0 — Emergency Equity Stop (independent layer)
   v0.46.0 — Concurrent Position Discipline
   v0.47.0 — Paper Mode Definition (vs Shadow vs Demo)
   v0.48.0 — Symbol Profile Foundation
```

كل واحد إصدار مستقل. **لا تجمّع.** هذي قواعد تشغيلية، كل واحدة تحتاج اختبار منفصل قبل القادم.

### القاعدة الفلسفية الأخيرة

```
المؤشر:  المشكلة كانت "كيف نحلل بدقة؟"
EA:      المشكلة هي "كيف ننفذ بأمان عندما الواقع يخالف التوقع؟"

كل قاعدة في هذي الوثيقة جاءت من سيناريو حقيقي يحصل:
- broker قال "no" غير متوقع
- اتصال انقطع
- صفقة تُركت بعد crash
- spread قفز ممسوس
- engine لمس صفقة engine ثاني

EA الناضج = EA يعرف الفشل قبل ما يحصل، ويعرف يرد عليه.
```

---

تبيني أعمق في أي واحدة من القواعد العشر؟ خاصة إذا تبي MQL5 كود حقيقي قابل للـ compile لأي منها (مثلاً FalconExecutor error handling أو State Persistence).
