# JA FalconCore — ذاكرة المشروع
## محدّثة بعد R1.2d — مايو 2026

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
- **آخر commit:** R1.2d — دمج S00 الكامل في الإبلاغ (التسجيل المركزيّ +
  الـ Reconciliation + trade_id الفريد + structural_sl الصحيح).
- **`dev`:** يبقى نقطة رجوع سليمة عند v0.57.4 (`5a7e961`).
- **`EA_VERSION_TAG`:** `R1_2d` (`EA_BUILD_TAG = CentralLifecycleRegistration`).
- **المرحلة التالية:** تشخيص ضعف S00 في التنفيذ الحقيقيّ (مرحلة كبيرة).
- الترجمة نظيفة: `0 errors, 0 warnings`؛ الأرقام 585.17/1104.89/157.49.
- **إعادة الهيكلة (R0) اكتملت:** R0.1→R0.9، 15 مرحلة فعلية.
- `EA_VERSION_TAG` الآن `R0_9`؛ يُحدَّث كل مرحلة (بند ثابت).
- globals: 86 → 29. الملف الرئيسي تقلّص جذريًّا.
- البنية النهائية: طبقات منفصلة (Core/Evidence/Risk/TradeManagement/
  Execution/Router/Strategies/Reporting)؛ منطق التداول في
  `CFalconRiskLifecycleProcessor`؛ التقارير في `CFalconReportWriter`
  (كاتب تقارير فقط)؛ الاتجاه بينهما واحد. توثيق:
  `Docs/Architecture_PostRefactor.md`.
- الجذر منظَّم: `Docs/` (ReviewNotes/Specs/ProjectMemory/Archive) + `StrategyDocs/`.
- مديول التقارير: نواة (TradeLifecycle + Summary) دائمة + تشخيصية خلف 6 مفاتيح.
- **R0.7 اكتمل:** `CFalconReportWriter` كاتب تقارير فقط (6,343→5,447 سطرًا)؛
  الـ 12 `Apply*` في `CFalconRiskLifecycleProcessor`؛ `RegisterClosedTrade`
  ينادي `ApplyTradeLifecycleChain` بنداء واحد؛ طبقة Risk لا تستدعي Reporting.

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
- **R0.4** ✓ نقل Execution (4 كلاسات) + عزل جسر البروكر (2,406 سطر).
- **R0.5** ✓ نقل Router (+ R0.5b تنظيم الجذر).
- **R0.6a** ✓ تفكيك ReportWriter بنيويًّا (نقله إلى Reporting/، صفر تغيير سلوك).
- **R0.6b** ✓ مفاتيح إطفاء التقارير التشخيصية (نواة = TradeLifecycle + Summary).
- **R0.7** ✓ فصل الـ 12 `Apply*` (a: أساس، b: نقل 10، cd: إكمال + تحويل).
- **R0.8a** ✓ تنظيف آمن (توثيق + ملفات + تعليقات).
- **R0.8b** ✓ حلّ الحالة المكرّرة (مالك واحد) + إصلاح خطأ FinalWorkingNetUSD.
- **R0.8c** ✓ تقليل الـ globals (86 → 29، بالتصنيف).
- **R0.9** ✓ تثبيت وإغلاق — إعادة الهيكلة مكتملة.
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
تحريك runtime)، Dynamic recovery checkpoint (foundation فقط)، **تقارير
تليجرام** (غير موجودة — انظر القسم 12).

## 12. ميزة تقارير تليجرام — بند تطوير مستقبلي

ميزة مطلوبة، **غير موجودة في v0.57.4**. تُبنى في مرحلة الـ Demo (بعد إعادة
الهيكلة) — لأن `WebRequest` (الذي يحتاجه تليجرام) **لا يعمل في Strategy
Tester إطلاقًا**، فلا يمكن اختبارها في البيئة الحالية.

**المحتوى:** تقرير يومي + أسبوعي + شهري يُرسَل عبر تليجرام، يوضّح:
- الربح/الخسارة بالدولار، والربح النهائي.
- اسم الرمز، رقم الحساب (`ACCOUNT_LOGIN`)، اسم صاحب الحساب (`ACCOUNT_NAME`).
- (تحسينات مقترحة) عدد الصفقات رابحة/خاسرة + نسبة الفوز، أفضل/أسوأ صفقة،
  الفترة الزمنية المغطّاة، ختم وقت الإرسال.

**متطلّبات تقنية:** bot token + chat id من المستخدم؛ إضافة
`api.telegram.org` لقائمة عناوين WebRequest المسموح بها في إعدادات MT5؛
الإرسال عبر `WebRequest`. تُختبَر على Demo فقط.

---

## 8. القواعد التي لا تُكسر

- لا `OrderSend` داخل أي Strategy Engine.
- لا lookahead — شموع مغلقة فقط.
- لا Break-Even مبكر؛ SL هيكلي.
- لا `BrokerModify` / `TRADE_ACTION_SLTP` / `RuntimeSLChanged`.
- `EnableRealExecution` مقفل افتراضيًا؛ التنفيذ tester-only عبر `MQL_TESTER`.
- كل إصدار يُترجَم بصفر errors، ويُختبَر، ويُحفَظ في **commit واحد** قبل التالي.
- لا أوامر git تعيد كتابة التاريخ (reset/rebase) إلا لضرورة قصوى.
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

## 10. المهمة التالية — تشخيص ضعف S00 في التنفيذ الحقيقيّ

**حالة R1.2d (مكتملة، commit يحمل رسالة R1.2d):** S00 مدمجة بالكامل
في طبقة الإبلاغ. أُنجِز عبر ثلاث دفعات (commit واحد جامع):
- **R1.2c (`ae42caa`):** ربط الإغلاق الحقيقيّ — S00 تُغلق بمنطقها.
- **R1.2d الأساسيّ:** S00 تستدعي `RegisterClosedTrade` — `TradeLifecycle`
  و`Summary` يمتلئان.
- **إكمال R1.2d:** `StorePaperFinalRecord` يربط الـ Reconciliation؛
  عدّاد تسلسليّ يجعل `trade_id` فريدًا (`S00_SCALP_FVG_<unix>_<seq>`).
- **إصلاح breach R1.2d:** حقل `original_structural_sl` يحفظ الوقف
  الهيكليّ الأصليّ قبل تحريك breakeven — صحّح `structural_sl` في
  السجلّ، فاختفى breach `dynamic_lotsizing_invalid` وصحّ حساب
  `FinalWorkingNetUSD`.

**التقرير المزدوج يعمل الآن** (ورقيّ من `TradeLifecycle`، حقيقيّ من
`BrokerExecutionLifecycle`، مقارنة في `BrokerPaperTradeReconciliation`).

**الأرقام — اختبار 3 أشهر (مارس–مايو 2026، `S00_RealExecution=true`):**
- 29 صفقة ورقية: 6 رابحة (21%)، 13 تعادل (45%)، 10 خاسرة (34%).
- الورقيّ: `RawNetUSD=+38.30$`، `FinalWorkingNetUSD=+40.22$`.
- الحقيقيّ (broker): **+0.10$** — تعادل تقريبًا. 25 صفقة نُفّذت،
  4 رُفضت (سقف المركز الواحد).
- التقطيع الشهريّ الحقيقيّ: مارس −5.20$، أبريل +17.43$، مايو −12.13$.

**السؤال الكبير للمرحلة القادمة:** S00 تُظهر تاريخيًّا (سجلّ ورقيّ،
R1.2a) +19,151 نقطة رابحة — لكن التنفيذ الحقيقيّ يعطي تعادلًا. لماذا
الفجوة؟ القاعدة العاشرة: لا نخمّن — نبدأ باستكشاف/تحليل البيانات.
محاور محتملة للتحقيق (لا قرار بعد): هل سجلّ +19,151 كان على فترة/إعداد
مختلف؟ كم يأكل السبريد/الانزلاق/تكاليف البروكر من الحافة؟ هل حماية
الـ breakeven تُفعَّل في التوقيت الصحيح؟ لماذا 84% من الصفقات تُغلق
بوقف أو breakeven؟

**التقارير الأساسية لرفعها بعد كل اختبار تنفيذ حقيقيّ:** `Summary`،
`TradeLifecycle`، `BrokerExecutionLifecycle`، `BrokerPaperTradeReconciliation`.

**دَيْن قائم موثَّق (في `Ideas_Backlog`):** ميزة `paper_state_snapshot`
معطّلة على مستوى المشروع (`FOUNDATION_ONLY_STATE_RESTORE_DISABLED`) —
تُبقي `ReportIntegrityStatus` و`TradeRowsVsSummaryStatus` و`PaperStateStatus`
على `FAIL` **حتى في baseline legacy**. ليست من صنع S00؛ تستحقّ مرحلة
مستقلّة. (`InvariantBreaches=1` في baseline وR1.2d بسببها — مقبول.)

**قاعدة ثابتة:** أيّ مرحلة تنفيذ حقيقيّ تُختبَر بمعيار مزدوج —
البوّابات مغلقة (`S00_RealExecution=false`) → FixedLot April يبقى
585.17/1104.89/157.49 بالضبط؛ البوّابات مفتوحة → اختبار 3 أشهر.

**قيد حرج معروف:** ترتيب سلسلة الـ Apply* / `ApplyTradeLifecycleChain`:
`#3،#4،#5،#6،#7،#8،#10،#9،#1،#2،#11،#12` — ليس تصاعديًّا.

**بنود مؤجَّلة في `Docs/Ideas_Backlog.md`:** تفعيل `paper_state_snapshot`؛
منع الدخول المتعدّد لـ S00 على نفس الشمعة (قرار استراتيجيّ)؛ نظام
تعدّد الاستراتيجيات (أرقام سحرية مستقلّة + تعميم الـ Bridge)؛ مراجعة
دلالة `stage`؛ إزالة الاستراتيجية القديمة؛ تنظيم مدخلات المشروع
القديمة؛ استراتيجية التحليل الموجيّ (S0x)؛ تطوير الـ Runner/الوقف
المتحرّك فوق الأساس الرابح؛ إصلاح عمود `PenetrationDepth`؛ فلتر
الوقت لـ S00.
