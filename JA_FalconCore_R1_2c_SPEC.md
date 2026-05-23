# JA FalconCore — R1.2c
## ربط الإغلاق الحقيقيّ — S00 تُغلق الصفقة بمنطقها عبر البروكر
### مواصفات للتسليم إلى Claude Code

> **الهدف:** ربط **إغلاق** S00 بطبقة التنفيذ الحقيقية. حين تقرّر S00 إغلاق
> صفقة (هدف، وقف، breakeven، timeout)، تُغلق الصفقة **فعليًّا على البروكر**
> عبر الـ Bridge — لا تتركها لوقف البروكر الطارئ. بعد R1.2c نعرف أخيرًا:
> هل أساس S00 الرابح ورقيًّا (+19,151 نقطة) يصمد أم لا.
>
> **الأساس:** فرع `refactor`، بعد R1.2b.
> **مرجع الاستكشاف:** تقرير استكشاف المحاور الستّة.

---

## 0. التشخيص والتصميم العاموّ

### المشكلة المُشخَّصة (من R1.2b):
- الدخول يعمل ✅ (23 من 29 وصلت).
- الإغلاق غير مربوط ❌ — البروكر يُغلق كل صفقة بـ `SERVER_SL_EXIT`/`SERVER_TP_EXIT`.
- الـ Bridge يضع "ظرف طوارئ" واسع (حتى 232 نقطة) كـ fallback.
- حماية S00 (`breakeven_armed`) لم تعمل أصلًا — البروكر أغلق الصفقة قبلها.
- النتيجة: −86.42$ حقيقيّ مقابل +19,151 ورقيّ.

### الحلّ في R1.2c:
1. **حفظ trade_id** — S00 تحتفظ بـ trade_id عند الفتح الحقيقيّ (R1.2b أضاف
   هذا) حتى تتمكّن من الإغلاق الحقيقيّ لاحقًا.
2. **ثلاث مسارات إغلاق** — حين تقرّر S00 الإغلاق (هدف / وقف / breakeven / timeout)،
   تُنادي الـ Bridge بـ `trade_id` + سعر الخروج + السبب.
3. **البريج يبحث ويُغلق** — يجد المركز في `m_active_links` عبر trade_id،
   يُغلق بـ reverse deal.
4. **Breakeven = إغلاق، لا تعديل** — حين السعر يعود للدخول بعد breakeven arm،
   S00 تُغلق الصفقة (لا تحرّك الوقف — هذا يخالف قاعدة). هذا متوافق مع Virtual
   Trailing Bridge النموذج.
5. **حلّ سقف المركز** — تلقائيًّا: حين الإغلاق الحقيقيّ يعمل، المراكز القديمة
   تُحرَّر، و 4 صفقات المرفوضة (EXISTING_FALCON_POSITION_COUNT_1) ستُقبَل.

---

## 1. القيود الصارمة (ما يجب ألا يحدث)

- **لا تعديل وقف البروكر.** لا `OrderModify`، لا `BrokerModify`، لا
  `TRADE_ACTION_SLTP`. الحماية عبر **إغلاق المركز، لا تحريك الوقف**.
- **لا تغيير منطق الدخول.** R1.2c يمسّ **الإغلاق فقط**.
- **لا تغيير في الـ Virtual Trailing Bridge.** هو يبقى كما هو (للاستراتيجية القديمة).
- **لا تغيير في معايير التحقّق الأرقاميّة** (585.17/1104.89/157.49).
- **الاستراتيجية القديمة تبقى سليمة** — S00 الحقيقية تعمل بالتوازي فقط.
- **لا commit بدون اختبار.** كل خطوة تُختبَر.

---

## 2. معايير القبول

✅ **المعيار الأوّل — الإغلاق الحقيقيّ:**
- S00 تقرّر إغلاق صفقة (أي من الأسباب الأربعة: هدف، وقف، breakeven، timeout).
- تُنادي الـ Bridge بـ `trade_id + exit_price + exit_reason`.
- الـ Bridge يجد المركز ويُغلقه بـ reverse deal (TRADE_ACTION_DEAL عكسيّ).
- المركز يُغلق فعليًّا على البروكر **قبل** أن ينتظر وقف البروكر الطارئ.

✅ **المعيار الثاني — Breakeven:**
- حين S00 تفعّل breakeven (السعر بلغ `S00_BreakevenTrigger` نقطة رابح)،
  تحرّك `m_active_trade.stop_loss = entry_price` (ورقيًّا).
- في الشمعة التالية، لو عاد السعر للدخول أو أقلّ، S00 تُغلق الصفقة بسبب
  `S00_EXIT_STOP` (أو breakeven-related stop).
- **النتيجة:** صفقة لا تعود لخسارة بعد ربح (حتى لو صغير).

✅ **المعيار الثالث — سقف المركز:**
- 6 صفقات تم رفضها في R1.2b لأن مركزًا سابقًا ما زال مفتوحًا.
- بعد R1.2c، حين الإغلاق الحقيقيّ يعمل، تلك الصفقات ستُقبَل
  (المركز القديم سيُغلق فعليًّا).

✅ **المعيار الرابع — التقرير:**
- ملفّ تقرير جديد يعرض: ورقيّ مقابل حقيقيّ **كاملًا** (ليس فقط الدخول).
- أعمدة: `PaperResult` vs `RealResult`، وأسباب الفجوة.

✅ **المعيار الخامس — الثبات:**
- الاختبار على 3 أشهر (مارس + أبريل + مايو 2026).
- كل شهر يجب أن يُظهر نفس السلوك الإغلاقيّ (لا overfitting على شهر واحد).

---

## 3. تحديث الإصدار

**قبل R1.2c:**
```
EA_VERSION_TAG = "R1_2b"
EA_BUILD_TAG = "StructuralBreakeven"
```

**بعد R1.2c:**
```
EA_VERSION_TAG = "R1_2c"
EA_BUILD_TAG = "RealisticCloseExecution"
```

ملفّ: `Core/FalconConstants.mqh:10-11`.

---

## 4. بروتوكول العمل — الخطوات المدقّقة

### المرحلة 4.1 — تحضير S00 لحفظ trade_id (تحديث بسيط)

**ما يحدث:**
- S00PaperTrade (ملفّ: `S00_EntryLogic.mqh:81-131`) — يجب أن يحفظ `trade_id`.
- R1.2b بالفعل يحسب `trade_id` من `entry_time` عند الفتح الحقيقيّ
  (سطر 658: `"S00_SCALP_FVG_" + IntegerToString((long)entry_time)`).
- R1.2c: نضيف حقل `trade_id` إلى S00PaperTrade، ويُعيَّن عند الفتح الحقيقيّ.

**الملف والسطور:**
- `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh`
- بنية `S00PaperTrade`: إضافة حقل `string trade_id;` (بعد `real_entry_price`).
- دالة `OpenTrade(...)`: عند فتح حقيقيّ (condition: `real_entry_attempted`
  becomes true)، احسب trade_id وخزّنه.

**مثال:**
```cpp
struct S00PaperTrade {
   // ... existing fields ...
   double real_entry_price;
   string trade_id;  // ← جديد: يُعيَّن عند الفتح الحقيقيّ
   // ... rest ...
};

void CS00EntryLogic::OpenTrade(...) {
   // ... existing logic ...
   if(real_entry_attempted) {
      m_active_trade.trade_id = "S00_SCALP_FVG_" + IntegerToString((long)entry_time);
   }
}
```

### المرحلة 4.2 — ربط CloseActiveTrade بالـ Bridge (التعديل الأساسيّ)

**ما يحدث:**
- دالة `CloseActiveTrade(...)` في `S00_EntryLogic.mqh:311-325` حاليًّا تُغلق
  الصفقة **ورقيًّا فقط** (تسجّل النتيجة في `m_active_trade`).
- R1.2c: نضيف سطر أو دالة استدعاء بعد الإغلاق الورقيّ: نُنادي الـ Bridge ليُغلق
  الصفقة **حقيقيًّا**.

**الملفّ والسطور:**
- `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh`
- دالة `CloseActiveTrade(...)`: بعد `AppendTradeRow(m_active_trade);`
  (سطر 321)، أضف استدعاء:

```cpp
void CloseActiveTrade(const datetime exit_time,
                      const double   exit_price,
                      const ENUM_S00_TRADE_EXIT_REASON reason)
{
   // ... existing logic ...
   m_active_trade.result_points = raw / point;
   AppendTradeRow(m_active_trade);
   
   // R1.2c: نادِ البريج ليُغلق الصفقة حقيقيًّا
   if(MQL_TESTER && EnableRealExecution && S00_RealExecution)
   {
      g_broker_entry_bridge.TryManagedCloseFromS00Trade(
         m_active_trade.trade_id,
         exit_price,
         reason,
         g_report_writer
      );
   }
   
   m_active_trade.open = false;
}
```

**مثال Signature للـ Bridge (سيُضاف في الخطوة 4.3):**
```cpp
bool TryManagedCloseFromS00Trade(
   const string &trade_id,          // تعريف الصفقة
   const double exit_price,         // سعر الخروج
   const ENUM_S00_TRADE_EXIT_REASON reason,  // السبب
   CFalconReportWriter &report_writer
);
```

### المرحلة 4.3 — إضافة دالة الإغلاق في الـ Bridge (إضافة جديدة)

**ما يحدث:**
- ملفّ `Execution/FalconBrokerEntryBridge.mqh` سيحتوي دالة جديدة:
  `TryManagedCloseFromS00Trade(...)`.
- هذه الدالة تعمل بـ 3 خطوات:
  1. ابحث عن المركز في `m_active_links[]` باستخدام `trade_id`.
  2. احسب سعر الإغلاق من `exit_price` المُعطَى (أو اقرأه من السوق).
  3. نادِ `ExecuteReverseClosePositionRequest(...)` (موجود بالفعل).

**الملفّ والسطور:**
- `Execution/FalconBrokerEntryBridge.mqh`
- يُضاف بعد دالة `TryOpenFromShadowRecord(...)` أو `TryManagedCloseFromLifecycleRecord(...)`.

**الكود المتوقّع (مخطّط):**
```cpp
bool CFalconBrokerEntryBridge::TryManagedCloseFromS00Trade(
   const string &trade_id,
   const double exit_price,
   const ENUM_S00_TRADE_EXIT_REASON reason,
   CFalconReportWriter &report_writer)
{
   // البوّابات الثلاث من R1.2b
   if(!MQL_TESTER || !EnableRealExecution || !S00_RealExecution)
      return false;
   
   // ابحث عن link بـ trade_id
   int link_idx = -1;
   for(int i = 0; i < ArraySize(m_active_links); i++)
   {
      if(m_active_links[i].trade_id == trade_id)
      {
         link_idx = i;
         break;
      }
   }
   
   if(link_idx < 0) {
      // لم نجد مركزًا — قد يكون أُغلق بالفعل أو لم يكن فتح حقيقيًّا
      return false;
   }
   
   FalconBrokerTradeLink &link = m_active_links[link_idx];
   
   // نادِ ExecuteReverseClosePositionRequest (الموجود)
   bool accepted = false;
   uint retcode = 0;
   double executed_price = 0;
   string result_comment = "";
   
   const bool success = ExecuteReverseClosePositionRequest(
      link,
      link.direction == FALCON_DIRECTION_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL,
      link.volume,
      "S00_CLOSE",
      "S00_TRADE_EXIT_" + EnumToString(reason),
      report_writer,
      accepted,
      retcode,
      executed_price,
      result_comment
   );
   
   return success && accepted;
}
```

**ملاحظات مهمّة:**
- البحث عن `link` يتمّ بـ `trade_id` (حقل جديد في `FalconBrokerTradeLink` في R1.2b).
- نستخدم `ExecuteReverseClosePositionRequest` الموجود — لا نكتب logic إغلاق جديد.
- السبب يُحوَّل من enum S00 إلى سلسلة نصيّة للتقرير.

### المرحلة 4.4 — إضافة حقل trade_id إلى FalconBrokerTradeLink (إن لم يكن موجودًا)

**التحقّق من وجوده:**
- من تقرير الاستكشاف: `FalconBrokerTradeLink` في
  `Core/FalconDataStructures.mqh:711-763`.
- يحتوي `trade_id` بالفعل (أضيف في R1.2b).
- **لا عمل هنا** — الحقل موجود.

### المرحلة 4.5 — اختبار على Tester (3 أشهر)

**الإعدادات:**
- `S00_RealExecution = true` (لتفعيل الإغلاق الحقيقيّ).
- الفترة: مارس + أبريل + مايو 2026 (نفس الفترة السابقة).
- التقرير الجديد يجب أن يعرض:
  - `PaperResult` (كما كان في R1.2a).
  - `RealResult` (جديد — مع الإغلاق الحقيقيّ).
  - `Gap` (الفارق).

**المتوقّع:**
- الإغلاق الحقيقيّ **يجب** أن يحسّن النتيجة (من −86$ لشيء أقلّ سوءًا أو ربح).
- **يجب أن لا** تزداد الخسارة — لو حصلت، هناك خطأ في التنفيذ.

---

## 5. الملفّات التي ستتغيّر

| الملفّ | التغيير | النوع |
|-------|---------|-------|
| `Core/FalconConstants.mqh` | EA_VERSION_TAG = "R1_2c" | تحديث |
| `S00_EntryLogic.mqh` | إضافة `trade_id` لـ S00PaperTrade | إضافة حقل |
| `S00_EntryLogic.mqh` | تحديث `OpenTrade()` لحساب trade_id | تحديث |
| `S00_EntryLogic.mqh` | تحديث `CloseActiveTrade()` لاستدعاء البريج | تحديث |
| `FalconBrokerEntryBridge.mqh` | إضافة `TryManagedCloseFromS00Trade(...)` | إضافة دالة |
| `FalconReportWriter.mqh` (اختياريّ) | إضافة عمود `RealResult` vs `PaperResult` | تحسين التقرير |

---


**فعّل وضع accept edits / auto mode أولًا.** اقرأ `JA_FalconCore_R1_2c_SPEC.md` ونفّذ R1.2c — ربط إغلاق S00 بالبروكر الحقيقيّ كاملًا: في `S00_EntryLogic.mqh` أضِف حقل `string trade_id;` إلى بنية `S00PaperTrade` (بعد `real_entry_price`). في دالة `OpenTrade()`، عند `real_entry_attempted = true`، احسب واحفظ trade_id: `m_active_trade.trade_id = "S00_SCALP_FVG_" + IntegerToString((long)entry_time);` في دالة `CloseActiveTrade()`، بعد `AppendTradeRow(m_active_trade);` مباشرةً، أضِف استدعاء البريج: `if(MQL_TESTER && EnableRealExecution && S00_RealExecution) { g_broker_entry_bridge.TryManagedCloseFromS00Trade(m_active_trade.trade_id, exit_price, reason, g_report_writer); }` في `FalconBrokerEntryBridge.mqh` أنشئ دالة جديدة `TryManagedCloseFromS00Trade(const string &trade_id, const double exit_price, const ENUM_S00_TRADE_EXIT_REASON reason, CFalconReportWriter &report_writer)` — تبحث عن المركز بـ trade_id في `m_active_links`، تستدعي `ExecuteReverseClosePositionRequest` الموجود. في `Core/FalconConstants.mqh` غيّر `EA_VERSION_TAG` من `"R1_2b"` إلى `"R1_2c"` و `EA_BUILD_TAG` إلى `"RealisticCloseExecution"`. ترجمة نهائية: F7 — يجب صفر errors.

**القيود الصارمة — لا تُخترق:** لا تغيّر منطق دخول S00، لا lookahead، لا تعديل Virtual Trailing Bridge. الاستراتيجية القديمة (g_fvg_micro_lifecycle_simulator) تبقى سليمة. البوّابات الثلاث (MQL_TESTER && EnableRealExecution && S00_RealExecution) موجودة في كل استدعاء للبريج. لا `OrderModify` أو `BrokerModify` أو `TRADE_ACTION_SLTP` — الحماية عبر إغلاق المركز فقط. اختبار FixedLot April يبقى 585.17/1104.89/157.49 مع البوّابات مغلقة.

راجع نافذة Problems في VS Code — صفر مشاكل. اكتب ملفّ مراجعة: `Docs/ReviewNotes/R1_2c_Review_Notes.md` (ملخّص القرارات والملاحظات). سجّل أفكار جديدة في `Docs/Ideas_Backlog.md`. حفظ واحد فقط: `git add -A && git commit -m "R1.2c - real close execution wired; S00 closes trades by logic, not broker stops"`. بعد الانتهاء أكّد: `git diff --stat` — يجب أن تُظهر تغييرات في 3-4 ملفّات فقط (S00_EntryLogic.mqh، FalconBrokerEntryBridge.mqh، FalconConstants.mqh). أخبرني بنتائج الترجمة (عدد الأخطاء) وناتج git diff --stat والملاحظات.

---

## معايير النجاح

✅ **R1.2c نجح إذا:**
1. الترجمة نظيفة (صفر أخطاء / warnings).
2. الاختبار على 3 أشهر أكمل بدون أخطاء runtime.
3. التقرير يعرض إغلاقات حقيقية (ليس SERVER_SL فقط).
4. النتيجة الحقيقية **أفضل من −86.42$** (المستهدف: قريب من الصفر أو موجب).
5. لا رسائل خطأ عن عدم العثور على trade_id أو link.
6. الـ 6 صفقات المرفوضة في R1.2b **ستُقبَل الآن**.
