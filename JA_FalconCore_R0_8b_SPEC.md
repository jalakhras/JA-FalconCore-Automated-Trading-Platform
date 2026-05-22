# JA FalconCore — R0.8b
## إعادة الهيكلة — حلّ الحالة المكرّرة + إصلاح FinalWorkingNetUSD
### مواصفات للتسليم إلى Claude Code

> **الهدف:** حلّ الحالة المكرّرة بين `CFalconRiskLifecycleProcessor` و
> `CFalconReportWriter` (الخيار أ — ملكية واضحة)، وبهذا إصلاح خطأ
> `FinalWorkingNetUSD = 0`.
> **الأساس:** فرع `refactor`، بعد R0.8a.

---

## 0. المشكلة — تشخيص مؤكَّد

بعد R0.7cd، المعالج وReportWriter يحملان **نسختين منفصلتين** من حالة
مشتركة. الخطأ المؤكَّد:
- نسخة المعالج من `m_tle_emergency_active` تُعلَّق على `true` (طوارئ الطبقة
  3)، لكن **كود إعادة الضبط يعمل على نسخة ReportWriter** — فلا تُعاد
  نسخة المعالج أبدًا.
- النتيجة: كل صفقة بعد التعليق تأخذ المسار المحظور، وتكتب
  `record.falcon_emergency_after_net_usd = 0` → `FinalWorkingNetUSD = 0`.
- `RawNetUSD` يبقى سليمًا (585.17) لأنه يُحسَب قبل Apply #11.

سبب جذري إضافي: حالة المعالج (`m_tle_peak_equity`، `m_tle_equity`...) تبدأ
من **صفر MQL5 الافتراضي** — لا يوجد `Initialize`/`Reset` يبذرها. (دَيْن
موثّق في `Ideas_Backlog.md` #4.)

---

## 1. الحلّ — الخيار أ: ملكية واضحة

كل قطعة حالة لها **مالك واحد، نسخة واحدة**:

| الحالة | المالك | السبب |
|---|---|---|
| `m_tle_*` (8 حقول طوارئ) | `CFalconRiskLifecycleProcessor` | حالة منطق مخاطر |
| `m_dlm_*` (2 حقل حجم عقد) | `CFalconRiskLifecycleProcessor` | حالة منطق مخاطر |
| `m_symbol_context` | `CFalconRiskLifecycleProcessor` | يحتاجه منطق المخاطر |
| `m_totals` | `CFalconReportWriter` | عدّادات تقارير |

**النتيجة:** لا نسخ مكرّرة. كل حالة موجودة مرّة واحدة، عند مالكها.

### 1.1 المعالج يملك حالة المخاطر — وله `Initialize`/`Reset`
- احذف نسخ `m_tle_*`/`m_dlm_*`/`m_symbol_context` من **ReportWriter**
  (تبقى في المعالج فقط).
- أضِف للمعالج دالة `Initialize(...)` (أو `Reset()`) تبذر هذه الحقول
  بقيمها الصحيحة عند بدء التشغيل — لا تتركها صفر MQL5 الافتراضي.
- تُستدعى من `OnInit` في الملف الرئيسي، أو من حيث يُهيَّأ ReportWriter
  حاليًّا (بنفس توقيت تهيئة `m_tle_*` القديمة في ReportWriter — حتى
  يتطابق السلوك).
- **مهمّ:** ابحث عن كود إعادة ضبط الطوارئ (reset of `m_tle_emergency_active`
  وأخواتها) الذي كان يعمل على نسخة ReportWriter — تأكّد أنه الآن يعمل على
  نسخة المعالج الوحيدة، عبر كل المسارات (يومي + الطبقات 1/2/3).

### 1.2 ReportWriter يملك `m_totals` — المعالج يصل إليه بمعامل
- `m_totals` يبقى في ReportWriter (نسخة واحدة).
- المعالج يحتاج الكتابة في `m_totals` (سلسلة Apply\* تحدّث عدّادات).
  الحلّ: `ApplyTradeLifecycleChain` يأخذ معاملًا:
  ```cpp
  void ApplyTradeLifecycleChain(FalconTradeLifecycleRecord &record,
                                FalconReportTotals &totals)
  ```
  وأجسام الـ Apply\* تستخدم `totals.X` بدل `m_totals.X`.
- في `RegisterClosedTrade`، النداء يصبح:
  ```cpp
  g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record, m_totals);
  ```
  (`m_totals` هنا نسخة ReportWriter — تُمرَّر بالمرجع.)

### 1.3 ReportWriter يقرأ حالة الطوارئ من المعالج
ReportWriter يحتاج `m_tle_*` لكتابة `EmergencyTriggers.csv`. بما أن
`m_tle_*` صارت في المعالج فقط:
- المعالج يوفّر **getter عامًّا** لقراءة نتيجة الطوارئ، أو (أفضل) Apply
  #11 يكتب النتيجة كاملةً في حقول `record` (كما رُتّب في R0.7b-fix).
- إن كانت حقول `record.falcon_emergency_*` تكفي لإعادة بناء صفّ
  `EmergencyTriggers.csv` — فلا حاجة لـ getter؛ ReportWriter يقرأ
  `record` فقط. تحقّق من ذلك أولًا.

---

## 2. تحديث `EA_VERSION_TAG`

في `Core/FalconConstants.mqh`، حدّث `EA_VERSION_TAG` إلى `R0_8b`.

> السبب: أسماء ملفات التقارير تتضمّن `EA_VERSION_TAG`. إبقاؤه ثابتًا يجعل
> كل المراحل تنتج تقارير بنفس الاسم — تتداخل وتُربك. تحديثه كل مرحلة يجعل
> اسم التقرير يحمل رقم المرحلة.
>
> **بند ثابت من الآن:** كل مواصفة مرحلة قادمة تطلب تحديث `EA_VERSION_TAG`
> لرقم مرحلتها.

---

## 3. القيود الصارمة

- **صفر تغيير سلوك** — عدا إصلاح الخطأ. بعد R0.8b، FixedLot April يجب أن
  يعطي `FinalWorkingNetUSD = 1104.89` (القيمة الصحيحة المستعادة).
- لا تعديل منطق أي دالة `Apply*` — فقط `m_totals.X` → `totals.X` (تغيير
  وصول، لا منطق).
- الترتيب الحرج للسلسلة يبقى:
  `#3,#4,#5,#6,#7,#8,#10,#9,#1,#2,#11,#12`.
- طبقة Risk لا تستدعي ReportWriter.
- لا تمسّ globals الأخرى (ذلك R0.8c).
- `Initialize`/`Reset` للمعالج يجب أن يبذر الحالة **بنفس قيم** تهيئة
  ReportWriter القديمة — حتى يتطابق السلوك.

---

## 4. بروتوكول العمل (بنود ثابتة)

1. راجع نافذة Problems في VS Code قبل التسليم؛ ترجمة F7 الحَكَم.
2. أفكار التحسين → `Docs/Ideas_Backlog.md`، لا تُنفَّذ.
3. اكتب `Docs/ReviewNotes/R0_8b_Review_Notes.md`.

---

## 5. معايير القبول

- لا نسخ مكرّرة: `m_tle_*`/`m_dlm_*`/`m_symbol_context` في المعالج فقط؛
  `m_totals` في ReportWriter فقط.
- المعالج له `Initialize`/`Reset` يبذر حالته؛ مُستدعى عند التهيئة.
- كود إعادة ضبط الطوارئ يعمل على نسخة المعالج الوحيدة، عبر كل المسارات.
- `ApplyTradeLifecycleChain` يأخذ `FalconReportTotals &totals`؛
  `RegisterClosedTrade` يمرّر `m_totals`.
- `EA_VERSION_TAG` = `R0_8b`؛ أسماء التقارير تعكسه.
- يُترجَم: `0 errors, 0 warnings`.
- **تشغيل FixedLot April يعطي `RawNetUSD = 585.17` و
  `FinalWorkingNetUSD = 1104.89` — القيمة الصحيحة مُستعادة.** وحساب
  البروكر 157.49.
- `Docs/ReviewNotes/R0_8b_Review_Notes.md` موجود.

---

## 6. ما يجب ألا يحدث

- لا إبقاء لأي نسخة مكرّرة من الحالة.
- لا تعديل منطق `Apply*` (فقط وصول `totals`).
- لا إعادة ترتيب السلسلة.
- لا طبقة Risk تستدعي ReportWriter.
- لا تنفيذ أفكار تحسين.

---

## 7. بعد R0.8b

عند نجاح الترجمة + `FinalWorkingNetUSD = 1104.89` → **commit واحد**:
```
git add -A
git commit -m "R0.8b - resolve duplicated state ownership; fix FinalWorkingNetUSD regression"
```
ثم R0.8c (تقليل الـ globals).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_8b_SPEC.md` ونفّذه: حلّ الحالة المكرّرة بالخيار أ.
> (1) اجعل `m_tle_*` (8) و`m_dlm_*` (2) و`m_symbol_context` مملوكةً
> للمعالج فقط — احذف نسخها من ReportWriter. (2) أضِف للمعالج
> `Initialize`/`Reset` يبذر هذه الحقول بنفس قيم تهيئة ReportWriter
> القديمة، واستدعِه عند التهيئة؛ وتأكّد أن كود إعادة ضبط الطوارئ يعمل على
> نسخة المعالج عبر كل المسارات (يومي + الطبقات 1/2/3). (3) `m_totals`
> يبقى في ReportWriter؛ `ApplyTradeLifecycleChain` يأخذ
> `FalconReportTotals &totals`، وأجسام Apply\* تستخدم `totals.X`؛
> `RegisterClosedTrade` يمرّر `m_totals`. (4) ReportWriter يقرأ نتيجة
> الطوارئ من حقول `record` (أو getter عامّ بالمعالج إن لزم). (5) حدّث
> `EA_VERSION_TAG` في `Core/FalconConstants.mqh` إلى `R0_8b`. **صفر تغيير
> سلوك عدا إصلاح FinalWorkingNetUSD؛ لا تعدّل منطق أي Apply\*؛ حافِظ على
> ترتيب السلسلة.** راجع نافذة Problems. سجّل أفكار التحسين في
> `Docs/Ideas_Backlog.md`. اكتب `Docs/ReviewNotes/R0_8b_Review_Notes.md`.
> commit واحد. بعد الانتهاء أكّد git diff --stat.
