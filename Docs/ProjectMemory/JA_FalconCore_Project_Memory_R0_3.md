# JA FalconCore — ذاكرة المشروع
## محدّثة بعد R0.3 — مايو 2026

> **بروتوكول الجلسة الجديدة:** ارفع هذا الملف أولًا، ثم
> `FalconCore_Refactor_Plan_v0_57_4.md` و`FalconCore_Feature_Inventory_v0_57_4.md`،
> ثم اطلب المهمة. لا تطلب الرجوع لمحادثات قديمة.

---

## 1. هدف المشروع

`JA FalconCore Automated Trading Platform` — Expert Advisor لـ MetaTrader 5،
يتداول الناسداك (US100). الشعار: "Evidence first. Execution last."
المراحل: Shadow → Paper → Demo → Live، والتنفيذ الحقيقي مقفل افتراضيًا.

**الهدف الحالي:** إعادة هيكلة المشروع من ملف واحد ضخم (~17,300 سطر) إلى
بنية ملفات `.mqh` منفصلة — تمهيدًا لإعادة بناء الاستراتيجية و إضافة 11
استراتيجية أخرى.

---

## 2. الحالة الحالية

- **الفرع:** `refactor` (متفرّع من `dev` عند v0.57.4).
- **آخر commit:** `c93b728` — R0.3 (نقل Evidence + Risk) + إصلاح `#property version`.
- **`dev`:** يبقى نقطة رجوع سليمة عند v0.57.4 (`5a7e961`).
- **المرحلة التالية:** R0.4 — نقل Execution + عزل جسر البروكر.
- الترجمة نظيفة: `0 errors, 0 warnings` (تحذير الـ version حُلّ بـ `"1.00"`).

---

## 3. الأرقام المرجعية — مقياس الحقيقة

بعد كل مرحلة إعادة هيكلة، تشغيلة **FixedLot April** يجب أن تعطي:
- `RawNetUSD = 585.17`
- `FinalWorkingNetUSD = 1104.89`
- حساب البروكر: 200 → 157.49 (‑42.51)

أي انحراف = إعادة الهيكلة كسرت شيئًا. هذا مبدأ "صفر تغيير سلوك".

---

## 4. القرارات الكبرى المعتمدة

1. **إعادة الهيكلة قبل تحسين الاستراتيجية.** لا نلمس منطق التداول حتى R1.1.
2. **البنية التحتية تُنقَل مع مراجعة وتدقيق** (بروتوكول "راجع وأصلح أثناء
   النقل") — لا نقل أعمى.
3. **الاستراتيجية (FVG_MICRO / scalp) تُعاد كتابتها من الصفر** — لأن الـ
   Decomposer أثبت أن مشكلتها في صميم منطقها (هامش خام رقيق: متوسط ربح
   2.97 مقابل متوسط خسارة 2.96 — لا ينجو من تكاليف التنفيذ).
4. **مبدأ Paper المحافِظة:** Paper الجديدة تحسب فقط ما يُنفَّذ على بروكر
   فعلًا — لا ربح محاسبي. (Paper الحالية تعطي صورة أفضل من الواقع: ~47% من
   "ربحها" محاسبي لا تنفيذي.)
5. **فصل الـ 12 `Apply*` من `CFalconReportWriter`:** منطق التداول محشور في
   كاتب التقارير — يُفصَل إلى طبقات Risk/TradeManagement في R0.7.
6. **مديول التقارير قابل للتشغيل/الإطفاء:** نواة دائمة (`Summary` +
   `TradeLifecycle`) + تقارير تشخيصية اختيارية خلف مفاتيح مطفأة افتراضيًا.
7. **ملفات SPEC مؤقتة** — تُحذف بعد اكتمال مرحلتها وحفظها في commit. تُستثنى
   خطة إعادة الهيكلة والجرد (مرجعان دائمان).
8. **قرار الاستراتيجية مؤجَّل إلى R1.0** — استراتيجيتنا أو منهج معروف
   للناسداك، يُحسَم حينها بمواصفة واختبار على شهرين.

---

## 5. خطة إعادة الهيكلة — ملخص

11 مرحلة (التفصيل في `FalconCore_Refactor_Plan_v0_57_4.md`):
- **R0.1** ✓ فرع + هيكل مجلدات + إثبات `#include`.
- **R0.2** ✓ نقل طبقة Core (Logger, MarketContext, CandleCache, Constants,
  Enums, DataStructures, CoreInputs).
- **R0.3** ✓ نقل Evidence + Risk (3 كلاسات صغيرة).
- **R0.4** ⏳ نقل Execution + عزل جسر البروكر.
- R0.5 نقل Router.
- R0.6 تفكيك `CFalconReportWriter` (6,292 سطر) كمديول تقارير قابل
  للتشغيل/الإطفاء.
- R0.7 نقل TradeManagement + **فصل الـ 12 `Apply*`** + توزيع البنى المشتركة
  من Core على طبقاتها (دَيْن مسجَّل من R0.2).
- R0.8 تنظيف globals (85 → <20) + حذف الملفات/الكود المؤقت.
- R0.9 تثبيت — أكبر ملف <600 سطر، فحص شامل.
- R1.0 حسم خيار الاستراتيجية + كتابة مواصفة الـ scalp.
- R1.1+ إعادة بناء الاستراتيجية من الصفر.

---

## 6. أرقام v0.57.4 (من الجرد)

- ~17,343 سطرًا، 18 class، 22 struct، 22 enum، 693 `#define`، 85 global،
  46 input، 12 دالة `Apply*`.
- أكبر كلاسين: `CFalconReportWriter` (6,292) + `CFalconBrokerEntryBridge`
  (2,735) = نصف المشروع.
- 5 كلاسات تخصّ استراتيجية S00 (~1,600 سطر) — تُعاد كتابتها لا تُنقَل.

---

## 7. المميزات — مصنّفة (من الجرد)

**موجودة وكاملة، تُنقَل وتُحفَظ:** EnableRealExecution، FixedLot/DynamicLot،
Dynamic Lot Sizing، حدود الخسارة اليومية، Single Trade Loss Cap،
Three-Layer Emergency، Capital Tier، Runner/Protected Runner، Paper
Protection، Session Boundary Guard (الإغلاق اليومي/الأسبوعي + منع الدخول
قبل الإغلاق)، Broker Execution Bridge، Virtual Trailing Bridge، Lock Parity
Decomposer، Capital Flow Classification، أوضاع Shadow/Paper.

**غير موجودة أو ناقصة، تُطوَّر لاحقًا:** EarlyFailureExit (غير موجود)،
حماية الأعياد (غير موجودة)، StructuralStop/TPBuilder (validation فقط — لا
تحريك runtime)، Dynamic recovery checkpoint (foundation فقط).

---

## 8. القواعد التي لا تُكسر

- لا `OrderSend` داخل أي Strategy Engine.
- لا lookahead — شموع مغلقة فقط.
- لا Break-Even مبكر؛ SL هيكلي.
- لا `BrokerModify` / `TRADE_ACTION_SLTP` / `RuntimeSLChanged`.
- `EnableRealExecution` مقفل افتراضيًا؛ التنفيذ tester-only عبر `MQL_TESTER`.
- كل إصدار يُترجَم بصفر errors، ويُختبَر، ويُحفَظ في commit قبل التالي.
- لا تعديل دوال `Apply*` أو منطق الدخول أثناء إعادة الهيكلة.

---

## 9. بيئة العمل

- المشروع: `D:\Projects\JA-FalconCore-Automated-Trading-Platform`، git فرع
  `refactor`.
- الملف الرسمي: `JA_FalconCore_Automated_Trading_Platform.mq5`.
- **Symbolic link (مجلد):** مجلد المشروع كله مرتبط بـ
  `...\MQL5\Experts\JassarBot` — أي ملف `.mqh` جديد يظهر للمترجم تلقائيًا.
- سير العمل: Claude (تخطيط/تحليل/كتابة SPEC) → المستخدم يعطي SPEC لـ Claude
  Code (CLI، وضع accept edits) → Claude Code يعدّل الكود → المستخدم يترجم
  في MetaEditor (F7) ويشغّل Strategy Tester → يرفع التقارير لـ Claude.
- السوق: US100_Spot، M5. الاستراتيجية النشطة: FVG_MICRO_RETEST (S00).

---

## 10. المهمة التالية

**R0.4** — نقل طبقة Execution إلى `Execution/*.mqh`، وأهمّها عزل
`CFalconBrokerEntryBridge` (2,735 سطرًا — جسر التنفيذ v0.56.x + Virtual
Trailing v0.57.2/3/4) في ملف مستقل. مرحلة ثقيلة وحسّاسة — تحوي منطق
`OrderSend` والـ emergency SL/TP. القبول: يُترجَم بصفر errors/warnings،
وSummary يطابق 585.17 / 1104.89، وحساب البروكر 157.49.

## 11. ملاحظات مهمة من المراجعات

- **خريطة R0.7 (من مراجعة R0.3):** الكلاسات `CFalconRisk*` هياكل/أسماء فقط
  — صفر منطق. منطق المخاطر الحقيقي في الـ 12 `Apply*` داخل ReportWriter.
  توزيعها المستهدف في R0.7: 7 دوال منطق مخاطر → `Risk/`؛ `ApplyPaperRuntime*`
  (3) → `TradeManagement/`؛ `ApplyFvgQualityShadowGuard` → `Strategies/S00`؛
  `ApplyCapitalFlowSourceClassification` → `Reporting/`.
- بنى مشتركة كثيرة (FalconBrokerTradeLink، FalconReportTotals، إلخ) مؤقتًا
  في `Core/FalconDataStructures.mqh` — تُوزَّع على طبقاتها في R0.7.
