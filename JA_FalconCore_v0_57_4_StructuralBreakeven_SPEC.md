# JA FalconCore — v0.57.4
## Breakeven الهيكلي — يتبع القيعان/القمم بدل رقم ثابت
### مواصفات هندسية للتسليم إلى Claude Code

> **الحالة المستهدفة:** v0.57.4 = استبدال الـ breakeven الثابت بـ breakeven
> هيكلي يتبع بنية السوق. Tester-only.
> لا LOCK، لا Demo، لا Live، لا BrokerModify، لا RuntimeSLChanged.
> **الملف المصدر:** `JA_FalconCore_Automated_Trading_Platform.mq5` على فرع `dev`
> (عليه v0.56.9b + v0.57.0 + v0.57.1 + v0.57.2 + v0.57.3).

---

## 0. لماذا هذا الإصدار — الدليل

تشغيلة Optimization على v0.57.3 (April، 27 تركيبة من العتبات الثابتة)
أثبتت بالأرقام:
- كل التركيبات الـ 27 خاسرة. أفضلها (8/6/4) = ‑38.65$.
- `Profit Factor` لكل التركيبات < 1.
- لا توجد قيمة ثابتة للـ breakeven تجعل الـ trailing رابحًا.

السبب الجذري: عتبة الـ breakeven الثابتة بالنقاط لا تلائم تقلّب السوق
المتغيّر. v0.57.4 يستبدلها بـ **breakeven هيكلي**: يقفل الحماية خلف آخر
قاع متأرجح (swing low) في صفقات الشراء، وخلف آخر قمة متأرجحة (swing high)
في صفقات البيع — مستوى يحدّده السوق نفسه، لا رقم ثابت.

---

## 1. القيود الصارمة (التزام حرفي)

- لا `BrokerModify`, `TRADE_ACTION_SLTP`, `RuntimeSLChanged`. الإغلاق يبقى
  عبر `ExecuteReverseClosePositionRequest` (المسار القائم من v0.57.2).
- لا تعديل أي دالة `Apply*`، ولا منطق الدخول، ولا الـ emergency server SL/TP.
- لا تعديل تقارير/منطق v0.57.0/v0.57.1 (الـ Decomposer/Rollup).
- لا تعديل منطق الـ trailing stop نفسه (`virtual_trailing_stop_price` — المسافة
  خلف القمة). v0.57.4 يغيّر **الـ breakeven floor فقط**.
- لا lookahead: كشف القيعان/القمم يستخدم الشموع المغلقة فقط (shift ≥ 1).
- العمل: استبدال حساب الـ breakeven floor + إضافة كشف هيكلي + أعمدة تقرير.
  لا OrderSend جديد.

---

## 2. المفهوم — Swing Low / Swing High

**Swing Low (قاع متأرجح):** شمعة `low` لها أدنى من `N` شموع قبلها و`N` شموع
بعدها. هي قاع محلي مؤكَّد.

**Swing High (قمة متأرجحة):** شمعة `high` لها أعلى من `N` شموع قبلها و`N`
شموع بعدها. قمة محلية مؤكَّدة.

`N` = نصف عرض النافذة. ابدأ بـ `N = 2` (نافذة 5 شموع: شمعتان قبل، شمعتان بعد).
اجعله `input` قابلًا للضبط.

> الـ breakeven الهيكلي في صفقة BUY = آخر swing low **تحت السعر الحالي وفوق
> سعر الدخول**. في SELL = آخر swing high **فوق السعر الحالي وتحت سعر الدخول**.
> المنطق: نقفل الحماية خلف آخر بنية سعرية حقيقية، لا خلف رقم.

---

## 3. الإصلاح — كشف هيكلي

أضف دالة مساعدة على `CFalconBrokerEntryBridge` (أو دالة حرة قريبة من
`UpdateVirtualTrailingForOpenLinks`):

```cpp
// v0.57.4: يبحث عن آخر swing low مؤكَّد ضمن آخر max_lookback شمعة M5 مغلقة.
// يُرجع 0.0 إذا لم يوجد. lookback يبدأ من shift=1 (شمعة مغلقة) — لا lookahead.
double FindLastSwingLow(const int swing_n, const int max_lookback)
{
   MqlRates r[];
   int need = max_lookback + swing_n + 1;
   if(CopyRates(_Symbol, PERIOD_M5, 1, need, r) < need)
      return 0.0;
   // r[] مرتبة زمنيًا تصاعديًا؛ نمشي من الأحدث للأقدم بحثًا عن swing low
   for(int i = swing_n; i < ArraySize(r) - swing_n; i++)
   {
      bool is_low = true;
      for(int k = 1; k <= swing_n; k++)
         if(r[i].low >= r[i-k].low || r[i].low >= r[i+k].low)
            { is_low = false; break; }
      if(is_low)
         return r[i].low;
   }
   return 0.0;
}
// FindLastSwingHigh مماثلة بعكس المقارنات (high، و<=).
```

> ملاحظة: تحقّق من ترتيب مصفوفة `CopyRates` في هذا المشروع (تصاعدي/تنازلي)
> واضبط اتجاه المرور بما يضمن إرجاع **أحدث** swing مطابق. الـ candle cache
> ودوال `CopyRates` مستخدمة أصلًا في الملف — اتبع نفس النمط.

---

## 4. دمج الـ breakeven الهيكلي في الـ trailing

في `UpdateVirtualTrailingForOpenLinks`، عند لحظة قفل الـ breakeven
(`profit_points >= VirtualBreakevenAtPoints && !virtual_breakeven_locked`):

بدل: `virtual_protection_floor_price = broker_entry_price ± be_buffer;`

استخدم المنطق الهيكلي:

```cpp
double structural_floor = 0.0;
if(direction == BUY)
{
   double sl = FindLastSwingLow(VirtualSwingLookbackBars, VirtualSwingMaxLookback);
   // اقبل فقط swing low فوق الدخول وتحت السعر الحالي
   if(sl > broker_entry_price && sl < current_bid)
      structural_floor = sl;
}
else // SELL
{
   double sh = FindLastSwingHigh(VirtualSwingLookbackBars, VirtualSwingMaxLookback);
   if(sh < broker_entry_price && sh > current_ask)
      structural_floor = sh;
}

if(structural_floor > 0.0)
{
   virtual_protection_floor_price = structural_floor;
   virtual_breakeven_mode = "STRUCTURAL";
}
else
{
   // fallback: الـ breakeven الواعي بالـ spread من v0.57.3
   double be_buffer = spread_price + FALCON_VIRTUAL_TRAILING_BE_EXTRA_POINTS*_Point;
   virtual_protection_floor_price = (direction==BUY)
        ? broker_entry_price + be_buffer
        : broker_entry_price - be_buffer;
   virtual_breakeven_mode = "FIXED_FALLBACK";
}
virtual_breakeven_locked = true;
```

> **مهم:** الـ fallback ضروري — في بداية الصفقة قد لا يوجد swing مؤكَّد بعد.
> عندها نستخدم منطق v0.57.3. هذا يضمن عدم وجود صفقة بلا حماية.

أضف حقلًا على `FalconBrokerTradeLink`:
```cpp
string virtual_breakeven_mode;   // "STRUCTURAL" | "FIXED_FALLBACK" | ""
```
صفّره في دالتَي الـ reset (`virtual_breakeven_mode = "";`).

---

## 5. المدخلات الجديدة

في كتلة inputs 02.1 (مجموعة Virtual Trailing Bridge):
```cpp
input bool   EnableStructuralBreakeven   = true;   // v0.57.4 breakeven هيكلي
input int    VirtualSwingLookbackBars    = 2;      // نصف نافذة الـ swing (N)
input int    VirtualSwingMaxLookback     = 40;     // أقصى عدد شموع للبحث
```

إذا `EnableStructuralBreakeven == false` → استخدم منطق v0.57.3 كما هو
(تراجع كامل، لا كشف هيكلي). هذا يتيح المقارنة المباشرة.

---

## 6. التقرير

في `VirtualTrailingExitLifecycle`، أضف عمودًا واحدًا بعد `BreakevenLocked`:
```
BreakevenMode
```
يكتب قيمة `link.virtual_breakeven_mode` ("STRUCTURAL" / "FIXED_FALLBACK").

> هذا يتيح قياس: كم صفقة استخدمت الـ breakeven الهيكلي فعلًا، وهل الهيكلي
> يعطي نتيجة أفضل من الـ fallback. لا rollup جديد — عمود يكفي.

---

## 7. وسوم الإصدار

```cpp
#define EA_VERSION_TAG "v0.57.4"
#define EA_BUILD_TAG   "StructuralBreakeven"
```

## 8. معايير القبول

- يُترجَم بصفر errors وصفر warnings جديدة.
- `diff` لا يلمس أي دالة `Apply*`، ولا منطق الدخول، ولا الـ emergency
  server SL/TP، ولا منطق الـ trailing stop، ولا v0.57.0/v0.57.1.
- لا `BrokerModify` / `TRADE_ACTION_SLTP` جديد.
- كشف الـ swing يستخدم شموعًا مغلقة فقط (shift ≥ 1) — لا lookahead.
- تقرير `VirtualTrailingExitLifecycle` فيه عمود `BreakevenMode`.
- مع `EnableStructuralBreakeven = false` → النتيجة تطابق v0.57.3 تمامًا.
- مع `EnableStructuralBreakeven = true` → جزء من الصفقات يظهر
  `BreakevenMode = STRUCTURAL`.
- v0.57.0/v0.57.1: `DecompositionStatus=PASS`, `RollupStatus=PASS` بلا تغيير.
- التشغيل: FixedLot April، `EnableRealExecution = true`, `ReportProfile = LOCKPARITY`.

## 9. ما يجب ألا يُلمَس

دوال `Apply*`، منطق الدخول، الـ emergency server SL/TP، منطق الـ trailing
stop نفسه، الـ Decomposer/Rollup، بنية الـ bridge، منطق الـ entry. هذا
الإصدار **يستبدل حساب الـ breakeven floor فقط**، ويضيف كشفًا هيكليًا وعمود
تقرير.

## 10. ماذا بعد v0.57.4

نقارن في تقرير `VirtualTrailingExitLifecycle`:
- مجموع `EstimatedUsdAtExit` للصفقات `STRUCTURAL` مقابل `FIXED_FALLBACK`.
- صافي الحساب الكامل (Net Profit من Strategy Tester) مقابل ‑38.65$ (v0.57.3).
على ضوء النتيجة:
- إن تحسّن بوضوح → نعمّم على بقية السيناريوهات (Dynamic / May).
- إن بقي خاسرًا → الفجوة أعمق من الـ breakeven؛ الـ Decomposer يبيّن أين
  (مسافة الـ trailing؟ entry fill؟ توقيت الدخول؟).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_v0_57_4_StructuralBreakeven_SPEC.md` بالكامل وطبّقه على
> `JA_FalconCore_Automated_Trading_Platform.mq5` (فرع dev): كشف swing low/high
> هيكلي + استبدال الـ breakeven floor + fallback لمنطق v0.57.3 + عمود
> BreakevenMode في التقرير. التزم حرفيًا بقسمَي القيود (1) وما لا يُلمَس (9).
> لا تعدّل دوال Apply* ولا منطق الدخول ولا منطق الـ trailing stop نفسه. لا
> lookahead — كشف الـ swing من شموع مغلقة فقط. بعد الانتهاء شغّل
> git diff --stat بنفسك وأكّد أن الملف تغيّر فعليًا على القرص؛ إن لم يتغيّر
> توقّف وأخبرني. ثم اعرض diff ملخصًا وأكّد معايير القبول (8).
