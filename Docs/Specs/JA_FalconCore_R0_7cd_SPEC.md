# JA FalconCore — R0.7c+d (موحّدة)
## إكمال فصل الـ Apply* — التحويل النهائي
### مواصفات للتسليم إلى Claude Code

> **الهدف:** إكمال نقل الـ 12 `Apply*` إلى `CFalconRiskLifecycleProcessor`،
> حذف نسخ ReportWriter المؤقّتة، وتحويل `RegisterClosedTrade` لاستدعاء
> المعالج. هذا يُخرج المشروع من الحالة المكسورة إلى حالة نظيفة مُترجَمة.
> **الأساس:** فرع `refactor`، بعد R0.7b-fix (لا يُترجَم — 18 خطأ).

---

## 0. السياق — لماذا دُمجت R0.7c وR0.7d

R0.7b نقل 10 دوال (ازدواج مؤقّت). R0.7b-fix نقل 3 دوال نقية — لكن تبيّن
أن ReportWriter يستدعيها من نسخه المؤقّتة من Apply\*، فظهرت 18 خطأ. الجرد
أثبت: الـ 18 خطأ كلّها في كود **مؤقّت محكوم بالحذف** (نسخ ReportWriter من
Apply\*).

لذلك الطريق النظيف للأمام = إكمال التحويل: حذف نسخ ReportWriter، وتحويل
`RegisterClosedTrade` للمعالج. عندها تختفي الـ 18 خطأ **سببيًّا**.
R0.7c (#3،#12) وR0.7d (التحويل) تُنفَّذان معًا لأن فصلهما لم يعد ممكنًا.

---

## 1. قرار موضع #3 و#12

- **#3 `ApplyFvgQualityShadowGuardSimulation`** و
  **#12 `ApplyCapitalFlowSourceClassification`** → **تُنقَلان إلى المعالج**
  ككامل بقيّة السلسلة.
- المبدأ: `CFalconRiskLifecycleProcessor` يملك السلسلة الكاملة (12 خطوة).
  مالك واحد، `ApplyTradeLifecycleChain` واحدة.
- #3 يخصّ S00 — لكن S00 ستُعاد كتابتها في R1.x؛ نقله لمجلد سيُعاد بناؤه
  عبث. يبقى في المعالج، ويُعاد تقييمه عند R1.x.

النتيجة: المعالج يملك الـ 12 دالة، `ApplyTradeLifecycleChain` تستدعيها
كلّها بالترتيب #1..#12.

---

## 2. الخطوات

### 2.1 نقل #3 و#12 إلى المعالج
انسخ جسمَي `ApplyFvgQualityShadowGuardSimulation` (#3) و
`ApplyCapitalFlowSourceClassification` (#12) من
`Reporting/FalconReportWriter.mqh` إلى `CFalconRiskLifecycleProcessor`
كعضوين `private`. عالِج أي تبعية (ماكرو/دالة) كما في R0.7b-fix — ماكرو
ناقص → `FalconRiskLifecycleProcessorInputs.mqh`؛ دالة نقية → تُنقَل.

### 2.2 إكمال `ApplyTradeLifecycleChain`
السلسلة الكاملة بالترتيب الحرج #1..#12:
```cpp
void ApplyTradeLifecycleChain(FalconTradeLifecycleRecord &record)
{
   ApplyNoNewEntryUserOverridePaperEnforcement(record);              // #1
   ApplyDailyWeekendForceCloseUserOverridePaperEnforcement(record);  // #2
   ApplyFvgQualityShadowGuardSimulation(record);                     // #3
   ApplyPaperRuntimeGuardApplication(record);                        // #4
   ApplyPaperRuntimeSmartSLProtectionApplication(record);            // #5
   ApplyPaperRuntimeRunnerApplication(record);                       // #6
   ApplyCapitalTierFoundation(record);                               // #7
   ApplyLowCapitalRiskFeasibilityFoundation(record);                 // #8
   ApplyCalibratedSingleTradeLossCapEnforcement(record);             // #9
   ApplyDynamicLotSizingModel(record);                               // #10
   ApplyThreeLayerEmergencyApplication(record);                      // #11
   ApplyCapitalFlowSourceClassification(record);                     // #12
}
```
**الترتيب ملزم** — #10 يقرأ #9، #11 يقرأ #5/#6.

### 2.3 إضافة نسخة المعالج العامة
في الملف الرئيسي، ضمن كتلة "Global Runtime Objects"، أضِف:
```cpp
CFalconRiskLifecycleProcessor g_risk_lifecycle_processor;
```

### 2.4 تحويل `RegisterClosedTrade`
في `RegisterClosedTrade` (داخل ReportWriter): استبدل الاستدعاءات الـ 12
المباشرة للـ Apply\* بنداء واحد:
```cpp
g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record);
```
في الموضع نفسه الذي كانت السلسلة تُستدعى فيه (نفس النقطة في تسلسل
`RegisterClosedTrade`).

### 2.5 حذف نسخ ReportWriter من الـ 12 Apply\*
بعد التحويل، احذف من `Reporting/FalconReportWriter.mqh` نُسخ الـ 12
`Apply*` كلّها (لم تعد مُستدعاة — `RegisterClosedTrade` صار ينادي
المعالج). **الآن** يصبح ReportWriter كاتب تقارير فقط.

> هذا الحذف يُزيل أيضًا مستدعيات الدوال النقية الثلاث (التي كانت داخل نسخ
> Apply\*) — فتختفي الـ 18 خطأ سببيًّا.

### 2.6 تفعيل خطّاف الطوارئ عبر record
الآن (بعد التحويل) يُفعَّل ما جُهِّز في R0.7b-fix:
- نسخة المعالج من `ApplyThreeLayerEmergency` تكتب نتيجة الطوارئ في حقول
  `record.emergency_*` (جاهز من R0.7b-fix).
- في `RegisterClosedTrade`، **بعد** نداء `ApplyTradeLifecycleChain`،
  يقرأ ReportWriter حقول `record.emergency_*` ويستدعي
  `AppendEmergencyTriggerEvent` إن تدخّلت الطوارئ.
- **كتابة واحدة فقط:** بما أن نسخ ReportWriter من Apply\* حُذفت (2.5)، لم
  يعد هناك من يستدعي `AppendEmergencyTriggerEvent` غير هذا المسار الواحد.
  لا كتابة مزدوجة.

---

## 3. القيود الصارمة

- **صفر تغيير سلوك.** بعد التحويل، النتيجة المالية تطابق تمامًا.
- الترتيب الحرج #1..#12 داخل `ApplyTradeLifecycleChain` ملزم.
- `AppendEmergencyTriggerEvent` تبقى في ReportWriter (لا تُنقَل للمعالج).
- طبقة Risk (المعالج) **لا تستدعي ReportWriter** — الاتجاه: المعالج يكتب
  في record، ReportWriter يقرأ record.
- `EmergencyTriggers.csv` يُكتَب **مرّة واحدة** لكل حدث — تأكّد لا ازدواج.
- لا تعديل منطق أي دالة `Apply*` — نقل حرفي.
- لا نقل globals أخرى، لا تحريك بنى Core غير حقول `emergency_*`.

---

## 4. بروتوكول العمل (بنود ثابتة من الآن)

1. **نافذة Problems في VS Code:** راجعها قبل التسليم، عالِج ما تستطيع،
   أبلِغ عمّا لا تستطيع. (تبقى ترجمة MetaEditor F7 هي الحَكَم النهائي.)
2. **أفكار التحسين:** إن لاحظت فكرة تحسين، سجّلها في `Docs/Ideas_Backlog.md`
   (أنشئه إن لم يوجد) — **لا تنفّذها**. إعادة الهيكلة = نقل فقط.
3. اكتب `Docs/ReviewNotes/R0_7cd_Review_Notes.md`.

---

## 5. معايير القبول

- المعالج يملك الـ 12 `Apply*` كأعضاء `private`؛
  `ApplyTradeLifecycleChain` تستدعيها بالترتيب #1..#12.
- `g_risk_lifecycle_processor` مُعرَّف في الملف الرئيسي.
- `RegisterClosedTrade` ينادي `ApplyTradeLifecycleChain` (نداء واحد) بدل
  الـ 12 استدعاءً.
- نسخ ReportWriter من الـ 12 `Apply*` محذوفة —
  `grep -cE "void Apply[A-Z]" Reporting/FalconReportWriter.mqh` يعطي **0**
  (عدا أي دالة ليست من السلسلة)؛ والمعالج يعطي 12 (+ `ApplyTradeLifecycleChain`).
- `EmergencyTriggers.csv` يُكتَب مرّة واحدة لكل حدث.
- يُترجَم: `0 errors, 0 warnings` — الـ 18 خطأ اختفت.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17`،
  `FinalWorkingNetUSD = 1104.89`، بروكر 157.49 — **مطابق تمامًا عبر
  المسار الجديد**.
- تشغيل `EnableTierEmergencyReports = true`: `EmergencyTriggers.csv`
  يُكتَب بنفس المحتوى السابق، بلا ازدواج.
- `Docs/ReviewNotes/R0_7cd_Review_Notes.md` موجود.

---

## 6. ما يجب ألا يحدث

- لا تغيير سلوك. Summary + البروكر يطابقان.
- لا كتابة مزدوجة لأي تقرير.
- لا منطق `Apply*` يُعدَّل — نقل حرفي.
- لا طبقة Risk تستدعي ReportWriter.
- لا إعادة ترتيب لسلسلة الـ 12.
- لا تنفيذ لأفكار تحسين — تُسجَّل فقط.

---

## 7. بعد R0.7c+d

عند نجاح الترجمة + تطابق Summary والبروكر → **commit واحد**:
```
git add -A
git commit -m "R0.7cd - complete Apply* peel: processor owns the 12-step chain, ReportWriter is report-only"
```
بهذا يكتمل R0.7 — التصحيح المعماري الأكبر. ثم R0.8 (تنظيف globals + ملفات).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_7cd_SPEC.md` ونفّذه: (1) انقل #3
> `ApplyFvgQualityShadowGuardSimulation` و#12
> `ApplyCapitalFlowSourceClassification` من ReportWriter إلى المعالج
> كأعضاء private، عالِج تبعياتهما. (2) أكمل `ApplyTradeLifecycleChain`
> بالـ 12 بالترتيب #1..#12. (3) أضِف `g_risk_lifecycle_processor` في كتلة
> Global Runtime Objects. (4) في `RegisterClosedTrade` استبدل الـ 12
> استدعاءً المباشرة بنداء واحد
> `g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record)`. (5) احذف
> نسخ ReportWriter من الـ 12 `Apply*`. (6) فعّل خطّاف الطوارئ:
> ReportWriter يقرأ `record.emergency_*` بعد نداء السلسلة ويستدعي
> `AppendEmergencyTriggerEvent` مرّة واحدة — تأكّد لا كتابة مزدوجة.
> **صفر تغيير سلوك، الترتيب #1..#12 ملزم، طبقة Risk لا تستدعي ReportWriter،
> لا تعدّل منطق أي Apply\*.** راجع نافذة Problems قبل التسليم. سجّل أي
> فكرة تحسين في `Docs/Ideas_Backlog.md` دون تنفيذها. اكتب
> `Docs/ReviewNotes/R0_7cd_Review_Notes.md`. commit واحد. بعد الانتهاء
> أكّد git diff --stat و`grep` عدد الـ Apply\* في الملفّين.
