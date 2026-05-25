# JA FalconCore — مواصفة التصحيح R1.5a-fix: الوقف الهيكليّ في سياق المحرّك

> **نوع المستند:** مواصفة تصحيح — تُنفَّذ عبر Claude Code.
> **الأساس:** R1.5a (commit `ProofProtectionEngine`).
> **تصحّح:** خللًا مُشخَّصًا — محرّك الحماية لم يُسلّح ولا مرّة في
> R1.5a لأنه حسب `R` من وقف البروكر (مظروف الطوارئ الواسع) لا من
> الوقف الهيكليّ للاستراتيجيّة.

---

## السياق — لماذا هذا التصحيح

اختبار R1.5a أثبت أن محرّك الحماية موصولٌ ويُستدعى (5526 تقييمًا)،
لكنّه **لم يُسلّح ولا مرّة**: `BrokerModifySent = 0`، `CurrentSL`
ثابتٌ داخل كلّ صفقة، `BrokerActualNetUSD` مطابقٌ لتشغيل الحماية-
مُطفأة.

عمود `DecisionReason` كشف السبب حرفيًّا: `not armed: profit … pts
< 1.00R (2500–17784 pts)`. الـ `R` انتفخ 30–500 ضعفًا لأن السياسة
تحسب `R = |الدخول − current_sl|`، و`current_sl` على مركز البروكر
هو **مظروف الطوارئ الواسع** (`SERVER_SL_TP_ENVELOPE`، مُعاير على
خسارة ≤75$) — لا الوقف الهيكليّ الذي أخذته S01 (~30–90 نقطة).
فالصفقة تبلغ هدفها الهيكليّ دون أن تقترب من 1.0R-المظروف؛ المحرّك
عاجزٌ بنيويًّا عن التسليح.

**التشخيص المعماريّ:** سياق المحرّك يجب أن يكون **هجينًا** — حقيقةُ
البروكر للمُخرَجات (السعر، الربح غير المحقّق)، **ونيّةُ الاستراتيجيّة
للمخاطرة** (الوقف الهيكليّ الذي وضعته الاستراتيجيّة عند الدخول).
`FalconManagedPositionContext` من 2b حمل `current_sl` فقط (وقف
البروكر) — فلم تملك السياسةُ مصدرًا صحيحًا لحساب `R`.

## الهدف

جعل محرّك الحماية يحسب `R` من **الوقف الهيكليّ للاستراتيجيّة**، لا
من مظروف البروكر — بإضافة الوقف الهيكليّ إلى سياق المحرّك، وملئه من
الاستراتيجيّة لحظة الدخول. لا تغيير في منطق الحماية ولا في عتباتها —
تصحيحُ مصدرِ رقمٍ واحد.

## القيود الصارمة (ما يجب ألّا يحدث)

- **لا يتغيّر منطق التسليح ولا الوجهة.** قاعدة «التسليح عند
  `TriggerRMultiple × R`» و«الوقف عند الدخول ± الإزاحة» تبقى كما
  هي. التصحيح يبدّل **مصدر `R`** فقط.
- **لا يتغيّر عقد `CFalconTradeEngine` ولا `CFalconProtectionPolicy`**
  (التواقيع). يُضاف حقلٌ إلى بنية السياق فقط.
- **لا يُمسّ مظروف الطوارئ على البروكر.** المظروف يبقى كما هو —
  هو شبكة أمان خلف الحماية، لا تتعارض معها.
- **لا تُمسّ مدخلات R1.5a** (`Enable_S01_Protection`،
  `Protection_TriggerRMultiple`، `Protection_StopOffsetPoints`) —
  ولا تُضاف مدخلات جديدة. التصحيح لا يحتاج مدخلًا.
- **لا يُمسّ منطق الدخول/الخروج في S01 ولا في الـ bridge** — يُضاف
  فقط تسجيلُ الوقف الهيكليّ لحظة الدخول (قراءةُ قيمةٍ موجودة أصلًا،
  لا حسابٌ جديد).
- **لا يُمسّ `Risk/FalconRiskLifecycleProcessor.mqh`** ولا سلسلة
  الـ Apply* ولا ترتيبها.
- **حارس الاتّجاه الواحد يبقى:** الـ SL يتحرّك نحو تقليل المخاطرة
  فقط، لا يُرجَع للخلف.
- مع `Enable_S01_Protection = false` تبقى الطبقة خاملة (تكافؤ أساس
  تامّ مع R1.4b — `BrokerActualNetUSD = 321.92`).
- الملفّات المسموح مسّها: ملفّات `TradeManagement/` المعنيّة بالسياق
  والمنسّق والسياسة + موضع تسجيل الوقف الهيكليّ عند دخول S01 +
  `EA_VERSION_TAG`. لا غيرها.

## مواصفة التصحيح

### ١ — حقل الوقف الهيكليّ في السياق

يُضاف إلى `FalconManagedPositionContext` (في
`FalconTradeEngineContract.mqh`) حقلٌ واحد:
`double structural_stop_price` — سعرُ الوقف الهيكليّ الذي حدّدته
الاستراتيجيّة عند الدخول (لا مظروف البروكر).

### ٢ — تسجيل الوقف الهيكليّ لحظة الدخول

S01 تعرف وقفها الهيكليّ (هي من حسبته ووضعته). لحظة فتح مركز S01
على البروكر، يُسجَّل وقفُه الهيكليّ في خريطة `position_ticket →
structural_stop_price` يقرؤها المنسّق. الخريطة تُملأ عند الدخول،
وتُنظَّف عند إغلاق المركز.

> هذه قراءةٌ لقيمةٍ موجودةٍ أصلًا في سجلّ صفقة S01 — لا حسابٌ
> جديد ولا تغييرٌ لمنطق الدخول.

### ٣ — المنسّق يملأ الحقل

عند بناء `FalconManagedPositionContext` لمركزٍ مفتوح، يقرأ المنسّق
`structural_stop_price` من الخريطة (المفتاح = رقم المركز) ويضعه في
السياق. إن لم يُوجَد المركز في الخريطة (مركزٌ غير معروف المصدر)،
يُترَك الحقل `0.0` والسياسةُ ترفض التسليح بأمان (انظر §٤).

### ٤ — السياسة تحسب R من الوقف الهيكليّ

في `CFalconFixedRMultipleProtection::EvaluateProtection`:
- `R = |broker_entry_price − ctx.structural_stop_price|` — بدل
  `current_sl`.
- **حارس السلامة:** إن كان `structural_stop_price == 0.0` أو
  `R` غير منطقيّ (صفر أو سالب) ⇒ `NO_ACTION` مع
  `DecisionReason = "no structural stop in context — protection
  disarmed"`. لا تسليحَ على مدخلٍ غائب.
- بقيّة المنطق (شرط التسليح، الوقف المحسوب، حارس الاتّجاه الواحد)
  كما هو في R1.5a دون تغيير.
- `DecisionReason` عند عدم التسليح يبقى مُفصِحًا: «الربح … <
  TriggerRMultiple×R» — وستظهر الآن قيمُ `R` واقعيّة (~30–90 نقطة)
  لا منتفخة.

## معايير القبول

- البناء: 0 أخطاء.
- **اختبار أ — تكافؤ الأساس (`Enable_S01_Protection = false`):**
  تشغيل S01، نافذة أبريل. `BrokerActualNetUSD = 321.92` حرفيًّا.
- **اختبار ب — الحماية تُسلّح فعلًا (`Enable_S01_Protection =
  true`):** نافذة 3 أشهر `2026.03.01 → 2026.05.31`،
  `TriggerRMultiple = 1.0`, `StopOffsetPoints = 0`. المتوقَّع:
  - `DecisionReason` في `TradeManagementCoordinatorAudit` يُظهر
    قيمَ `R` واقعيّة (عشرات النقاط، لا آلاف).
  - قرارات `FALCON_TM_MODIFY_SL` تظهر على الصفقات التي بلغت
    1.0R، و`AppliedAction = SL_MODIFIED`، و`BrokerModifySent > 0`.
  - عمود `CurrentSL` يتحرّك **داخل** الصفقات المُسلَّحة (نحو
    الدخول)، ولا يُرجَع للخلف في أيّ صفّ.
  - `BrokerActualNetUSD` يختلف عن تشغيل الحماية-مُطفأة — أثرٌ
    حقيقيّ، يُقطَّع شهريًّا في التحليل.
- **الحتميّة:** إعادة اختبار ب ⇒ نتيجة متطابقة.
- التقارير تحمل `EA_VERSION_TAG = R1_5a_fix`.

> بعد إثبات أن الحماية تُسلّح، يُجرى مسحُ القيم (شبكة
> `TriggerRMultiple × StopOffsetPoints`) المنصوص عليه في مواصفة
> R1.5a الأصليّة — نختار المستقرّ عبر الأشهر الثلاثة. المسح خطوة
> تالية بعد قبول هذا التصحيح، لا جزء منه.

## تحديث الإصدار

`EA_VERSION_TAG → R1_5a_fix`، وسم البناء `ProofProtectionEngineFix`.

## بروتوكول العمل

> **موقع تقارير الـ Strategy Tester على جهاز المستخدم:**
> `C:\Users\jalak\AppData\Roaming\MetaQuotes\Terminal\Common\Files`
> — التقارير المخصّصة تُكتب هنا؛ `ReportTester.xlsx` يُصدَّر حيث
> يحدّده المشغّل. حين تحتاج المواصفةُ تقاريرَ، ابحث هنا أوّلًا.

إعدادات S01 المشتركة كما في R1.5a: `Enable_S01_Harness = true`,
`S01_RealExecution = true`, `EnableRealExecution = true`,
`EnableVirtualTrailingBridge = false`, `Enable_S00_FvgScalp = false`,
`S00_RealExecution = false`, `EnableStrategy_FvgMicroRetest = false`,
`Enable_TradeManagement = true`, `TradeManagement_DiagReport = true`,
`UseFixedLot = true`, `FixedLotSize = 0.01`, `S01_StopBuffer = 30`,
`S01_TargetRMultiple = 2.0`. الإطار M5، الرمز `US100_Spot`.
- اختبار أ: نافذة `2026.04.01 → 2026.04.30`.
- اختبار ب: نافذة `2026.03.01 → 2026.05.31` (تشغيل ممتدّ واحد).

1. إعادة بناء صريحة (F7) — 0 أخطاء.
2. شغّل اختبار أ، تحقّق من `BrokerActualNetUSD = 321.92`.
3. شغّل اختبار ب، تحقّق من معايير القبول — خاصّةً ظهور قيم `R`
   الواقعيّة وقرارات `SL_MODIFIED` وتحرّك `CurrentSL`.
4. إن نجح ⇒ commit واحد لهذا التصحيح. لا إعادة كتابة تاريخ git.
5. ارفع: من اختبار أ `Summary`؛ ومن اختبار ب الستّةَ —
   `Summary`, `TradeLifecycle`, `BrokerExecutionLifecycle`,
   `BrokerPaperTradeReconciliation`, `TradeManagementCoordinatorAudit`,
   `ReportTester.xlsx`.

## خاتمة المواصفة

- **مراجعة Problems:** بعد البناء راجع لوحة Problems — 0 أخطاء؛
  سجّل أيّ تحذيرات.
- **تسجيل الأفكار (`Docs/Ideas_Backlog.md`):** أضِف —
  (١) **درس بنيويّ:** سياق المحرّك هجين — حقيقةُ البروكر للمُخرَجات،
  ونيّةُ الاستراتيجيّة للمخاطرة. أيّ محرّك مستقبليّ يحتاج «مخاطرة
  الاستراتيجيّة» يقرؤها من `structural_*` في السياق، لا من حالة
  البروكر. وقفُ البروكر قد يكون مظروفَ أمانٍ واسعًا ≠ المخاطرة
  المقصودة.
  (٢) خريطة `position_ticket → structural_stop_price` يملؤها مصدرٌ
  واحد الآن (S01)؛ حين تنفّذ استراتيجيّةٌ ثانية للبروكر، يجب أن
  تُغذّي الخريطةَ هي أيضًا — وإلّا رفض المنسّقُ حمايتَها بأمان.
- **ملفّ مراجعة:** عند الاكتمال اكتب
  `Docs/ReviewNotes/R1_5a_fix_Review_Notes.md` بنتيجة التصحيح،
  وحدِّث ملفّ ذاكرة المشروع.

---

## ملحق — Prompt جاهز لـ Claude Code

> فعّل وضع accept edits / auto mode أوّلًا.
> اقرأ `JA_FalconCore_SPEC_R1_5a_fix_StructuralStopInContext.md`
> ونفّذ التصحيح R1.5a-fix. الخلل المُشخَّص: محرّك الحماية يحسب
> `R = |الدخول − current_sl|`، و`current_sl` هو مظروف الطوارئ
> الواسع على البروكر لا الوقف الهيكليّ — فينتفخ `R` 30–500 ضعفًا
> ولا يُسلّح المحرّك أبدًا. الإصلاح: (١) أضِف إلى البنية
> `FalconManagedPositionContext` حقلًا `double structural_stop_price`؛
> (٢) لحظة فتح مركز S01 على البروكر سجّل وقفَه الهيكليّ (قيمةٌ
> موجودة في سجلّ صفقة S01) في خريطة `position_ticket →
> structural_stop_price`، ونظّفها عند الإغلاق؛ (٣) المنسّق يقرأ
> الخريطة ويملأ `structural_stop_price` في السياق عند بنائه —
> وإن لم يُوجَد المركز يُترَك `0.0`؛ (٤) في
> `CFalconFixedRMultipleProtection::EvaluateProtection` احسب
> `R = |broker_entry_price − ctx.structural_stop_price|` بدل
> `current_sl`، ومع `structural_stop_price == 0.0` أو `R` غير
> منطقيّ ⇒ `NO_ACTION` بسبب `"no structural stop in context —
> protection disarmed"`. حدّث `EA_VERSION_TAG` إلى `R1_5a_fix`،
> وسم `ProofProtectionEngineFix`.
> **لا تغيّر منطق التسليح ولا الوجهة ولا العتبات — تصحيحُ مصدرِ
> `R` فقط. لا تغيّر تواقيع `CFalconTradeEngine` /
> `CFalconProtectionPolicy`. لا تضف مدخلات. لا تمسّ مظروف الطوارئ
> ولا منطق الدخول/الخروج في S01 أو الـ bridge ولا
> Risk/FalconRiskLifecycleProcessor.mqh ولا سلسلة Apply*. حارس
> الاتّجاه الواحد يبقى. مع Enable_S01_Protection=false يبقى
> BrokerActualNetUSD = 321.92.**
> ابنِ (F7، 0 أخطاء)، نفّذ اختبار أ (الحماية مُطفأة، أبريل — يجب
> أن يبقى `BrokerActualNetUSD = 321.92`) واختبار ب (الحماية
> مُشغَّلة، 3 أشهر `2026.03.01→2026.05.31` — يجب أن تظهر قيمُ `R`
> واقعيّة بعشرات النقاط، وقراراتُ `SL_MODIFIED`، و`BrokerModifySent
> > 0`، وتحرّكُ `CurrentSL` داخل الصفقات المُسلَّحة دون رجوعٍ
> للخلف). أبلِغ بالنتائج والتقارير. سجّل الفكرتين في
> `Docs/Ideas_Backlog.md`، راجع لوحة Problems، اكتب
> `Docs/ReviewNotes/R1_5a_fix_Review_Notes.md`. commit واحد. بعد
> الانتهاء أكّد `git diff --stat`.
