# JA FalconCore — مواصفة المرحلة R1.4a: مقياس الحقيقة التقريريّ (broker-truth)

> **نوع المستند:** مواصفة بناء — تُنفَّذ عبر Claude Code.
> **الأساس:** R1.3a (commit `9b5e9bc`). مبنيّ على تقرير استكشاف
> فجوة الورقيّ↔البروكر ومحضر تشخيص اختبار ب.
> **نوع المرحلة:** المرحلة 2a — تغيير تقريريّ بحت. لا منطق، لا تنفيذ.

---

## موقع هذه المرحلة في خريطة البناء

المشروع: بناء طبقة إدارة الصفقة الحقيقيّة. المرحلة 2 = نقطة تنسيق
إدارة الصفقة الحيّة + واجهة المحرّكات. وهي مُقسَّمة:

- **2a (هذه المواصفة):** مقياس الحقيقة التقريريّ — يتصدّر التقريرُ
  برقم البروكر بدل الرقم الورقيّ المسموم، ويوسم الفئة الشبحيّة.
- **2b (لاحقًا):** نقطة التنسيق + واجهة المحرّكات.

2a شرطٌ مسبق لـ2b: اختبار قبول 2b يُقرأ من تقرير، فيجب أن يكون
التقرير نظيفًا أوّلًا.

## السياق — لماذا 2a

أثبت استكشاف `PaperBrokerGap` أن `FinalWorkingNetUSD` الورقيّ **ليس
الحقيقة**: نظام الـ emergency طبقةٌ ورقيّةٌ لاحقة تُصفّر ربح 589 صفقة
نفّذها البروكر فعلًا، فينهار المجموع من +648$ إلى −34$. الحقيقة هي
جانب البروكر (`BrokerActualUSD` ≈ +243$). والـ Summary اليوم **لا
يحوي أصلًا رقمًا إجماليًّا لصافي البروكر** — التحليل يُجبَر على جمعه
يدويًّا من الـ Reconciliation. وفئة `MANAGED_CLOSE_PRICE_POINTS_GAP`
(540 صفقة) شبحٌ: تنشأ بالبناء من التصفير، لا من فرق سعر.

إصلاح التصفير نفسه حوكمةٌ — يُؤجَّل للمرحلة 4. 2a **تقريريّة بحتة**:
لا تلمس سلسلة Apply ولا الـ emergency ولا التنفيذ — تُظهر الحقيقة
الموجودة، لا تغيّر سلوكًا.

## الهدف

جعل تقارير المشروع تتصدّر بمقياس الحقيقة المُعتمَد (صافي البروكر
الفعليّ) وتوسم الفئة المضلِّلة — بإضافة أعمدة جديدة فقط، دون مسّ أيّ
حساب قائم. الناتج: كلّ تحليل من الآن (وكلّ اختبار محرّك في المرحلة 3)
يقرأ الحقيقة مباشرةً بلا طرح ضوضاء ذهنيًّا.

## القيود الصارمة (ما يجب ألّا يحدث)

- **لا يُمسّ `Risk/FalconRiskLifecycleProcessor.mqh` إطلاقًا** — لا
  سلسلة Apply، لا Apply #11، لا منطق الـ emergency.
- **لا يُمسّ ترتيب سلسلة الـ Apply*.**
- **لا يتغيّر حسابُ أيّ قيمة قائمة.** `PaperRawUSD`،
  `PaperFinalWorkingUSD`/`FinalWorkingNetUSD`، `RawNetUSD`،
  `BrokerActualUSD` — تُقرأ كما هي. 2a تُضيف عرضًا، لا تعيد حسابًا.
- **لا يُحذَف ولا يُعاد ترتيب أيّ عمود قائم.** أساس الـ regression
  `585.17 / 1104.89` يتحقّق من `RawNetUSD` و`FinalWorkingNetUSD`
  بموضعيهما؛ حذفهما أو إزاحتهما يكسر كلّ فحص regression منذ R0.
  الأعمدة الجديدة **تُلحَق في آخر صفّ ترويسة كلّ تقرير**.
- **لا يُمسّ كود التنفيذ** (`Execution/FalconBrokerEntryBridge.mqh`)
  ولا أيّ ملفّ استراتيجيّة (S00، S01، legacy).
- **لا تُعاد تسمية** فئة `MANAGED_CLOSE_PRICE_POINTS_GAP` ولا أيّ
  سلسلة فئة قائمة — قد يعتمد عليها فحصٌ نصّيّ. التوضيح يكون بعمود
  جديد، لا بإعادة تسمية.
- لا تضخيم: الأعمدة الجديدة هي المذكورة في «مواصفة التغيير» فقط.
- الملفّات المسموح مسّها: `Reporting/FalconReportWriter.mqh` +
  `Core/FalconConstants.mqh` (وسم الإصدار). لا غيرهما.

## مواصفة التغيير

### أ — كتلة صافي البروكر في الـ Summary

في كاتب الـ Summary (`WriteFinalSummary` في `FalconReportWriter.mqh`)،
تُلحَق ثلاثة أعمدة في آخر الترويسة:

- `BrokerActualNetUSD` — مجموع `link.broker_actual_balance_delta`
  عبر كلّ صفقة مغلقة نُفّذت فعلًا على البروكر (نفس الحقل المكتوب في
  صفّ الـ Reconciliation اليوم). هذا هو رقم الحقيقة الإجماليّ
  المفقود حاليًّا.
- `BrokerActualWinTrades` — عدد الصفقات التي `broker_actual_balance_
  delta > 0`.
- `BrokerActualLoseTrades` — عدد الصفقات التي `< 0`.

تُجمَع من نفس الـ links/records التي يكتب منها الكاتبُ صفوفَ الـ
Reconciliation — لا مصدر بيانات جديد.

### ب — وسم مقياس الحقيقة

عمود جديد في الـ Summary: `PrimaryResultMetric` — قيمة ثابتة
نصّيّة `BROKER_ACTUAL_NET_USD`. إعلانٌ صريح، يقرؤه الإنسان والآلة،
بأن صافي البروكر هو مقياس الحقيقة المُعتمَد — لا `FinalWorkingNetUSD`.

### ج — وسم الفئة الشبحيّة في الـ Reconciliation

عمود جديد في صفّ الـ Reconciliation: `LockParityGapIsEmergencyZeroing
Artifact` — `YES` إذا كانت نقاطُ الصفقة الورقيّة النهائيّة = 0
**و**`EmergencyStatus = BLOCKED` (أي الفجوة ناتجة عن تصفير الـ
emergency، لا عن فرق مسار سعر)؛ `NO` خلاف ذلك. يميّز الـ540 صفقة
الشبحيّة عن أيّ انزلاق سعريّ حقيقيّ — فلا يطارد أحدٌ إصلاحًا وهميًّا.

## معايير القبول

- البناء: 0 أخطاء.
- **اختبار أ — regression:** التشغيل على أساس أبريل legacy المعروف
  (نفس وضع تشغيل أساس R0). يجب:
  - `RawNetUSD = 585.17`، `FinalWorkingNetUSD = 1104.89`،
    `TotalTrades = 536` — حرفيًّا، بمواضعها.
  - `TradeLifecycle` متطابق بايتيًّا مع تشغيل ما قبل 2a.
  - الأعمدة الأربعة الجديدة تظهر مملوءة؛ `BrokerActualNetUSD` يساوي
    مجموع عمود `BrokerActualUSD` في Reconciliation نفس التشغيل
    (فحص اتّساق داخليّ).
  - `PrimaryResultMetric = BROKER_ACTUAL_NET_USD`.
- **اختبار ب — إظهار حقيقة البروكر:** تشغيل S01 بإعدادات اختبار ب
  R1.3a نفسها. يجب:
  - `BrokerActualNetUSD` ≈ مجموع `BrokerActualUSD` في الـ
    Reconciliation (~+243$) — لا `−34.23$`.
  - `LockParityGapIsEmergencyZeroingArtifact = YES` للصفقات
    المُصفَّرة بالـ emergency، `NO` لغيرها.
- التقارير تحمل `EA_VERSION_TAG = R1_4a`.

## تحديث الإصدار

`EA_VERSION_TAG → R1_4a`، وسم البناء `BrokerTruthMeterReporting`.
(إن فضّلت ترقيمًا آخر — مثلًا `R1_3b` — عدّله؛ المهمّ أن تحمله
التقارير وأن يختلف عن `R1_3a`.)

## بروتوكول العمل

> **موقع تقارير الـ Strategy Tester على جهاز المستخدم:**
> `C:\Users\jalak\AppData\Roaming\MetaQuotes\Terminal\Common\Files`
> — التقارير الخمسة المخصّصة (`Summary` / `TradeLifecycle` /
> `BrokerExecutionLifecycle` / `BrokerPaperTradeReconciliation`
> وما يرتبط بها) تُكتب هنا. أمّا `ReportTester.xlsx` فيُصدَّر إلى
> حيث يحدّده المشغّل عند التصدير — إن لم يكن بجوار الخمسة، اطلبه.
> حين تحتاج المواصفةُ تقاريرَ، ابحث في هذا المسار أوّلًا.

1. إعادة بناء صريحة (F7) — 0 أخطاء.
2. شغّل اختبار أ، تحقّق من تطابق أساس الـ regression حرفيًّا.
3. شغّل اختبار ب، تحقّق من معايير القبول.
4. إن نجحا ⇒ commit واحد لهذه المرحلة. لا إعادة كتابة تاريخ git.
5. ارفع تقارير اختبار ب: `Summary`, `TradeLifecycle`,
   `BrokerExecutionLifecycle`, `BrokerPaperTradeReconciliation`,
   `ReportTester.xlsx`.

## خاتمة المواصفة

- **مراجعة Problems:** بعد البناء راجع لوحة Problems — الهدف 0
  أخطاء؛ سجّل أيّ تحذيرات.
- **تسجيل الأفكار (`Docs/Ideas_Backlog.md`):** أضِف ثلاثة بنود —
  (١) إصلاح تصفير الـ emergency ليصير حوكمةً حقيقيّة تَحجب دخول
  البروكر فعلًا (لا طبقة ورقيّة لاحقة) — **عمل المرحلة 4**؛ (٢) اسم
  فئة `MANAGED_CLOSE_PRICE_POINTS_GAP_ON_MATCHED_CLOSE` مضلِّل —
  يصف فرق مسار سعر بينما يُطلَق بالبناء من التصفير؛ مرشَّح لإعادة
  تسمية في مرحلة تنظيف تقريريّ؛ (٣) أساس الـ regression الورقيّ
  `1104.89` يتقادم — اعتماد جانب البروكر مقياسًا يستلزم تثبيت أساس
  جديد broker-side (مرتبط بـ Backlog #58).
- **ملفّ مراجعة:** عند اكتمال المرحلة، اكتب
  `Docs/ReviewNotes/R1_4a_Review_Notes.md` بنتيجة 2a، وحدِّث ملفّ
  ذاكرة المشروع بإغلاق 2a وحالة المرحلة 2.

---

## ملحق — Prompt جاهز لـ Claude Code

> فعّل وضع accept edits / auto mode أوّلًا.
> اقرأ `JA_FalconCore_SPEC_R1_4a_BrokerTruthMeter.md` ونفّذ المرحلة
> R1.4a — تغيير تقريريّ بحت. في `Reporting/FalconReportWriter.mqh`:
> (١) ألحِق بآخر ترويسة الـ Summary أربعة أعمدة — `BrokerActualNetUSD`
> (مجموع `broker_actual_balance_delta` عبر الصفقات المنفَّذة على
> البروكر)، `BrokerActualWinTrades`، `BrokerActualLoseTrades`،
> و`PrimaryResultMetric` (ثابت `BROKER_ACTUAL_NET_USD`)؛ (٢) ألحِق
> بآخر ترويسة الـ Reconciliation عمود `LockParityGapIsEmergencyZeroing
> Artifact` (`YES` إذا نقاط الورقيّ النهائيّ = 0 و`EmergencyStatus
> = BLOCKED`، وإلّا `NO`). حدّث `EA_VERSION_TAG` إلى `R1_4a` في
> `Core/FalconConstants.mqh`، ووسم البناء `BrokerTruthMeterReporting`.
> **لا تمسّ `Risk/FalconRiskLifecycleProcessor.mqh` ولا سلسلة Apply*
> ولا منطق الـ emergency. لا تحذف ولا تُعِد ترتيب أيّ عمود قائم —
> الأعمدة الجديدة تُلحَق في الآخر فقط. لا تغيّر حساب أيّ قيمة قائمة.
> لا تمسّ كود التنفيذ ولا أيّ استراتيجيّة. لا تُعِد تسمية أيّ فئة
> قائمة.** الملفّان المسموحان فقط: `FalconReportWriter.mqh` و
> `FalconConstants.mqh`. ابنِ (F7، 0 أخطاء)، ثمّ نفّذ اختبار أ
> (regression — يجب أن يبقى `RawNetUSD=585.17` و`FinalWorkingNetUSD
> =1104.89` و`TradeLifecycle` متطابقًا بايتيًّا) واختبار ب (تشغيل
> S01)، وأبلِغ بالنتائج والتقارير. سجّل الأفكار الثلاثة في
> `Docs/Ideas_Backlog.md`، راجع لوحة Problems، اكتب
> `Docs/ReviewNotes/R1_4a_Review_Notes.md`. commit واحد. بعد
> الانتهاء أكّد `git diff --stat`.
