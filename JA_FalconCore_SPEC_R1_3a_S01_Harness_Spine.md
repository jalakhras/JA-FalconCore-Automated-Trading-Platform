# JA FalconCore — مواصفة المرحلة R1.3a: استراتيجيّة S01_Harness — العمود الفقريّ

> **نوع المستند:** مواصفة بناء — تُنفَّذ عبر Claude Code.
> **الأساس:** R1.2d (commit `5be1778`). مبنيّ على تقرير التحقّق
> من محرّكات إدارة الصفقة.

---

## موقع هذه المرحلة في خريطة البناء

المشروع: بناء طبقة إدارة الصفقة الحقيقيّة + استراتيجيّة harness
تُثبتها. أربع مراحل: (1) الـ harness + العمود الفقريّ، (2) نقطة
تنسيق إدارة الصفقة الحيّة، (3) المحرّكات واحدًا واحدًا، (4) الحوكمة
الحقيقيّة. **هذه المواصفة = المرحلة 1a فقط.**

## الهدف

بناء `S01_Harness`: استراتيجيّة حتميّة بسيطة وشفّافة، غرضها الوحيد
توليد صفقات متوقَّعة. المرحلة 1a تُثبت **العمود الفقريّ للتنفيذ**
فقط: دخول حتميّ ← أمر بروكر حقيقيّ عبر الـ Bridge يحمل SL/TP ←
خروج عبر server SL/TP ← الإبلاغ المزدوج. لا محرّكات إدارة صفقة بعد.

## القيود الصارمة (ما يجب ألّا يحدث)

- **لا `OrderSend` داخل كود الاستراتيجيّة.** الدخول حصرًا عبر
  `g_broker_entry_bridge.TryOpenFromShadowRecord(...)` — كنمط S00.
- لا تُمسّ ملفّات S00 ولا legacy ولا أيّ ملفّ آخر، عدا: مجلّد S01
  الجديد + سطرَي الوصل في الـ `.mq5` الرئيسيّ.
- لا يُمسّ ترتيب سلسلة الـ Apply*.
- المرحلة 1a = عمود فقريّ فقط: دخول + وقف هيكليّ + هدف. **لا حماية،
  لا runner، لا partial، لا managed-close خاصّ، لا timeout.** الخروج
  حصرًا عبر server SL/TP.
- `Enable_S01_Harness = false` و`S01_RealExecution = false`
  افتراضيًّا — عند الإطفاء لا تؤثّر الاستراتيجيّة على أيّ شيء
  (تكافؤ أساس تامّ).
- مركز S01 واحد في كلّ مرّة.
- لا تضخيم مدخلات: أربعة مدخلات S01 فقط.

## مواصفة الاستراتيجيّة

### المدخلات — `S01_HarnessInputs.mqh`

```mql5
input bool   Enable_S01_Harness = false;  // activates the deterministic harness strategy
input bool   S01_RealExecution  = false;  // routes harness entries to the broker bridge (tester only)
input double S01_TpRMultiple    = 1.5;    // take-profit distance as a multiple of stop distance
input double S01_StopBuffer     = 30.0;   // stop offset beyond the signal bar extreme, in points
```

### منطق الدخول — `S01_EntryLogic.mqh` (`class CS01EntryLogic`)

`EvaluateOnNewBar(CFalconMarketContext &market_context)` على كلّ
شمعة M5 مغلقة جديدة:

1. إن كان مركز S01 مفتوحًا ⇒ لا شيء (server SL/TP يُغلقه).
2. إن كان مسطّحًا:
   - الشمعة المرجعيّة = آخر شمعة مغلقة (`bar1`، shift=1).
   - الاتّجاه: `bar1.close > bar1.open` ⇒ BUY؛ `bar1.close <
     bar1.open` ⇒ SELL؛ متساويتان ⇒ تخطٍّ.
   - `entry_price = bar0.open` (الشمعة الحاليّة).
   - الوقف: BUY ⇒ `bar1.low − S01_StopBuffer×_Point`؛
     SELL ⇒ `bar1.high + S01_StopBuffer×_Point`.
   - `stop_distance = |entry_price − stop|`.
   - الهدف: `entry_price ± stop_distance × S01_TpRMultiple`.
3. بناء `FalconShadowTradeRecord`: `strategy_id = "S01_HARNESS"`،
   `engine_id` مناسب، `direction`, `entry_price`, `structural_sl
   = stop`, `tp1 = tp2 = tp3 = target`, `lot_size = FixedLotSize`,
   `status = FALCON_SHADOW_RECORD_STAGED`, `is_closed = false`.
4. إن `S01_RealExecution` ⇒ استدعاء
   `g_broker_entry_bridge.TryOpenFromShadowRecord(record,
   g_report_writer)`.

في نهاية الملفّ: `CS01EntryLogic g_s01_entry_logic;`.

### الوصل بالمنصّة

- مجلّد جديد `Strategies/S01_Harness/` يحوي الملفّين أعلاه.
- `#include` في الـ `.mq5` الرئيسيّ بجوار `#include` الخاصّ بـ S00.
- استدعاء في `OnTick()` بعد سطر `g_s01_entry_logic`؟ — بعد
  استدعاء S00 مباشرةً: `g_s01_entry_logic.EvaluateOnNewBar(
  g_market_context);`.

## معايير القبول

- البناء: 0 أخطاء.
- **اختبار أ — تكافؤ الأساس:** `Enable_S01_Harness = false` ⇒
  التشغيل مطابق لتشغيل R1.2d قبل S01 (S00/legacy بلا أيّ تغيّر).
- **اختبار ب — العمود الفقريّ:** `Enable_S01_Harness = true`،
  `S01_RealExecution = true`، `EnableRealExecution = true`،
  `EnableVirtualTrailingBridge = false`، وS00 وlegacy مُعطَّلتان،
  نافذة 3 أشهر. المتوقَّع:
  - صفقات `S01_HARNESS` تظهر في `TradeLifecycle`.
  - كلّ صفقة لها أمر بروكر دخول يحمل SL وTP.
  - كلّ صفقة تُغلق عبر server SL أو server TP.
  - `BrokerExecutionLifecycle` و`Reconciliation` يمتلئان لـ S01.
- **الحتميّة:** إعادة اختبار ب على نفس النافذة ⇒ صفقات متطابقة.
- التقارير تحمل `EA_VERSION_TAG = R1_3a`.

## تحديث الإصدار

`EA_VERSION_TAG → R1_3a`، وسم البناء `S01HarnessSpine`. (إن أردت
مخطّط ترقيم آخر، عدّله — المهمّ أن تحمله التقارير.)

## بروتوكول العمل

1. إعادة بناء صريحة (F7) — 0 أخطاء.
2. شغّل اختبار أ، تحقّق من تكافؤ الأساس.
3. شغّل اختبار ب، تحقّق من معايير القبول.
4. إن نجحا ⇒ commit واحد لهذه المرحلة. لا إعادة كتابة تاريخ git.
5. ارفع تقارير اختبار ب: `Summary`, `TradeLifecycle`,
   `BrokerExecutionLifecycle`, `BrokerPaperTradeReconciliation`,
   `ReportTester.xlsx`.

## خاتمة المواصفة

- **مراجعة Problems:** بعد البناء، راجع لوحة Problems — الهدف 0
  أخطاء؛ سجّل أيّ تحذيرات.
- **تسجيل الأفكار (Ideas_Backlog):** ملاحظة معروفة مسبقًا — الـ
  Virtual Trailing Bridge بلا فلتر `strategy_id`، فهو **سيدير
  مراكز S01** عند تشغيله. لاختبارات المحرّكات اللاحقة النظيفة:
  إمّا إضافة فلتر `strategy_id`، أو إبقاء الـ Bridge off. يُسجَّل
  للمرحلة 3، لا يُنفَّذ الآن.
- **ملفّ مراجعة:** عند اكتمال المرحلة، حدِّث ملفّ ذاكرة المشروع
  بنتيجة 1a وحالة العمود الفقريّ.

---

## ملحق — Prompt جاهز لـ Claude Code

> أنشئ استراتيجيّة `S01_Harness` وفق المواصفة أعلاه. مجلّد جديد
> `Strategies/S01_Harness/` فيه `S01_HarnessInputs.mqh`
> (أربعة مدخلات) و`S01_EntryLogic.mqh` (`class CS01EntryLogic`
> + instance عامّ). قاعدة الدخول حتميّة كما هو موصوف: اتّجاه حسب
> آخر شمعة M5 مغلقة، وقف هيكليّ خلف طرفها + buffer، هدف بمضاعف R.
> الدخول الحقيقيّ حصرًا عبر `g_broker_entry_bridge.
> TryOpenFromShadowRecord(...)` — لا `OrderSend` في كود
> الاستراتيجيّة. صِل الملفّ عبر `#include` واستدعاء `OnTick`
> بجوار S00. حدِّث `EA_VERSION_TAG` إلى `R1_3a`. لا تمسّ S00 ولا
> legacy ولا ترتيب سلسلة Apply*. ابنِ (F7، 0 أخطاء)، ثم نفّذ
> اختبارَي القبول أ وب، وأبلِغ بالنتائج والتقارير. هذه مهمّة
> بناء — لا تتجاوز نطاق المرحلة 1a (لا حماية/runner/partial).
