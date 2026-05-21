# JA FalconCore — R0.7b-fix
## إصلاح الـ 33 خطأ — استكمال نقل دوال Risk
### مواصفات للتسليم إلى Claude Code

> **الهدف:** حلّ الـ 33 خطأ في `FalconRiskLifecycleProcessor.mqh` بالطريقة
> المعمارية الصحيحة — دون نسخ منطق تقارير إلى طبقة Risk.
> **الأساس:** فرع `refactor`، بعد R0.7b (لا يُترجَم — 33 خطأ).

---

## 0. تشخيص الـ 33 خطأ

الجرد صنّفها إلى ثلاثة أسباب:
1. **11 خطأ** — 11 ماكرو `#define` معرَّفة بعد نقطة تضمين المعالج.
2. **~18 خطأ** — 4 دوال من `CFalconReportWriter` تستدعيها الـ Apply\*
   المنقولة (+ الأخطاء النحوية التابعة).
3. **4 تحذيرات** — تابعة للماكرو النصّية.

الحلّ يعالج كلًّا بطريقته الصحيحة. **مبدأ حاكم: لا نسخ منطق تقارير إلى
طبقة Risk.**

---

## 1. الجزء الأول — 11 ماكرو

أنشئ `Risk/FalconRiskLifecycleProcessorInputs.mqh` بحارس تضمين.

انقل إليه — من الملف الرئيسي — الـ 9 ماكرو المعرَّفة فيه:
`FALCON_SESSION_BOUNDARY_DEFAULT_CHECKPOINT_MINUTES` (L111)،
`FALCON_SESSION_BOUNDARY_ACTION_TO_CHECKPOINT_GAP_MINUTES` (L112)،
`FALCON_SSBL_MAX_SPREAD_POINTS` (L1033)،
`FALCON_LCRF_BORDERLINE_MULTIPLIER` (L1701)،
`FALCON_STLC_RUNTIME_ENFORCED` (L1716)،
`FALCON_STLC_DYNAMIC_CAPITAL_FLOOR_USD` (L1723)،
`FALCON_STLC_DYNAMIC_CAPITAL_MODE` (L1724)،
`FALCON_DLM_STATUS` (L1740)،
`FALCON_DLM_RUNTIME_ENFORCED` (L1742).

الماكروان `FALCON_DLM_CAPITAL_USD_PER_001_LOT` و
`FALCON_DLM_MAX_LOT_GROWTH_MULTIPLIER` معرَّفان في
`Execution/FalconExecutionInputs.mqh` (L70-71) — الذي يُضمَّن **بعد**
المعالج. الحلّ: انقل هذين أيضًا إلى `FalconRiskLifecycleProcessorInputs.mqh`
(لأنهما يخصّان منطق DLM وهو الآن في Risk)، واحذفهما من ExecutionInputs.

> إن كان أيٌّ من الـ 11 ماكرو يُستخدَم أيضًا في الملف الرئيسي أو طبقة
> أخرى — لا مشكلة: `FalconRiskLifecycleProcessorInputs.mqh` يُضمَّن مبكرًا،
> فيراه الجميع.

أضِف `#include "Risk/FalconRiskLifecycleProcessorInputs.mqh"` **قبل**
`#include "Risk/FalconRiskLifecycleProcessor.mqh"`.

---

## 2. الجزء الثاني — 3 دوال نقية تُنقَل إلى المعالج

الجرد أثبت أن 3 من الـ 4 callbacks **دوال نقية** (تقرأ وتُرجع رقمًا، لا
كتابة، لا I/O)، موجودة في ReportWriter "لأسباب تاريخية" فقط — وظيفيًّا
تخصّ منطق Risk:
- `FalconForceCloseOverrideNetPoints` (ReportWriter L1961)
- `FalconForceCloseOverrideNetUsd` (ReportWriter L1952)
- `CurrentPaperRiskCapitalBeforeTrade` (ReportWriter L4606)

**انقل** هذه الثلاث من `Reporting/FalconReportWriter.mqh` إلى
`CFalconRiskLifecycleProcessor` كأعضاء `private`.

> هذا **نقل**، لا نسخ — تُحذف من ReportWriter. (تختلف عن دوال الـ Apply\*
> التي بقيت مزدوجة مؤقّتًا؛ هذه الثلاث دوال مساعدة نقية، نقلها النهائي
> الآن صحيح ولا يترك ازدواجًا.)
>
> تحقّق: إن كانت أيٌّ من الثلاث ما زالت مُستدعاة من داخل ReportWriter
> نفسه (من دوال غير الـ Apply\*) — **لا تحذفها، أبلِغ**. الجرد يشير أنها
> تخصّ Tier/LossCap/DLM (وكلّها Apply\*)، لكن تأكّد قبل الحذف.

---

## 3. الجزء الثالث — `AppendEmergencyTriggerEvent` عبر سجلّ الصفقة

الـ callback الرابع مختلف: `AppendEmergencyTriggerEvent` (ReportWriter
L1505) **يكتب صفًّا في `EmergencyTriggers.csv`** — دالة كتابة تقرير. لا
يجوز نقلها إلى Risk (يُعيد التشابك). الحلّ المعماري:

### 3.1 افحص ما يكتبه
افحص `AppendEmergencyTriggerEvent` وحدّد بالضبط البيانات التي يكتبها في
الصفّ (أي طبقة طوارئ تدخّلت، القيم، إلخ).

### 3.2 أضِف حقول النتيجة إلى سجلّ الصفقة
في `FalconTradeLifecycleRecord` (في `Core/FalconDataStructures.mqh`)،
أضِف **بالضبط** الحقول اللازمة لإعادة بناء صفّ `EmergencyTriggers.csv` —
لا أكثر. (مثلًا: `emergency_triggered` bool، `emergency_layer` int،
وأي قيمة يكتبها الصفّ.) سمِّها بوضوح واتساق مع بقيّة حقول الـ record.

### 3.3 المعالج يكتب في record، لا يستدعي ReportWriter
في نسخة `ApplyThreeLayerEmergencyApplication` داخل المعالج: بدل استدعاء
`AppendEmergencyTriggerEvent`، اكتب النتيجة في حقول `record` الجديدة.
**طبقة Risk لا تستدعي ReportWriter إطلاقًا.**

### 3.4 ReportWriter يقرأ record ويكتب التقرير
في `RegisterClosedTrade` (الذي ما زال يعمل في R0.7b — المسار القديم لم
يُحوَّل): بعد أن تنتهي سلسلة الـ Apply\* (نسخة ReportWriter)، يقرأ
ReportWriter حقول `record.emergency_*` ويستدعي `AppendEmergencyTriggerEvent`
بنفسه إن كانت الطوارئ قد تدخّلت.

> هكذا `EmergencyTriggers.csv` ما زال يُكتَب تمامًا كما قبل — لكن الاتجاه
> صار: Risk تكتب في record ← ReportWriter يقرأ record ويُخرج التقرير.
> اتجاه واحد. لا استدعاء من Risk إلى Reporting.

> ملاحظة: في R0.7b المسار العامل هو نسخة ReportWriter من الـ Apply\*.
> نسخة ReportWriter من `ApplyThreeLayerEmergency` تبقى تستدعي
> `AppendEmergencyTriggerEvent` مباشرةً كما الآن (لا تغيّرها). فقط نسخة
> **المعالج** تكتب في record. عند R0.7d (تحويل المسار) سيُفعَّل منطق
> "ReportWriter يقرأ record" — جهّزه الآن لكن المسار القديم يبقى الفاعل.

---

## 4. القيود الصارمة

- **صفر تغيير سلوك.** المسار العامل يبقى نسخة ReportWriter من الـ Apply\*.
- لا نسخ منطق كتابة تقارير إلى طبقة Risk.
- الـ 3 دوال النقية: نقل (حذف من ReportWriter)؛ تحقّق قبل الحذف.
- `AppendEmergencyTriggerEvent`: تبقى في ReportWriter، لا تُنقَل.
- حقول `record` الجديدة: فقط ما يلزم لإعادة بناء صفّ التقرير.
- لا تعديل `RegisterClosedTrade` عدا الجزء 3.4 (قراءة record) — وهذا
  لا يغيّر سلوكه لأن نسخة ReportWriter من Apply\* ما زالت تستدعي
  `AppendEmergencyTriggerEvent` مباشرةً.

> تنبيه دقيق على الجزء 3.4: لتجنّب كتابة مزدوجة لـ EmergencyTriggers،
> تأكّد أن `AppendEmergencyTriggerEvent` تُستدعى **مرّة واحدة** لكل حدث.
> في R0.7b: نسخة ReportWriter من Apply\* تستدعيها (كما الآن). لا تضِف
> استدعاءً ثانيًا من قراءة record. الجزء 3.2/3.3 (حقول record + كتابة
> المعالج فيها) جهازٌ لـ R0.7d، لا يُفعَّل كمسار كتابة ثانٍ الآن.
> أي: في R0.7b، أضِف الحقول واملأها من المعالج، لكن **لا** تجعل
> ReportWriter يقرأها ويكتب — ذلك يُفعَّل في R0.7d. هذا يضمن صفر تغيير
> سلوك ولا كتابة مزدوجة.

---

## 5. معايير القبول

- `Risk/FalconRiskLifecycleProcessorInputs.mqh` موجود، فيه 11 ماكرو،
  مُضمَّن قبل المعالج.
- الـ 11 ماكرو محذوفة من مواضعها القديمة (الملف الرئيسي + ExecutionInputs).
- الـ 3 دوال النقية مُنقَلة إلى المعالج، محذوفة من ReportWriter.
- `AppendEmergencyTriggerEvent` ما زالت في ReportWriter (لم تُنقَل).
- حقول `record.emergency_*` مضافة؛ نسخة المعالج من
  `ApplyThreeLayerEmergency` تملؤها (ولا تستدعي ReportWriter).
- نسخة ReportWriter من الـ Apply\* لم تتغيّر — ما زالت المسار العامل.
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17`،
  `FinalWorkingNetUSD = 1104.89`، بروكر 157.49 — **مطابق تمامًا**.
- `EmergencyTriggers.csv` (عند تشغيل `EnableTierEmergencyReports`) يُكتَب
  كما قبل، بنفس المحتوى.
- `Docs/ReviewNotes/R0_7b_Review_Notes.md` محدَّث بكل ما سبق.

---

## 6. ما يجب ألا يحدث

- لا نسخ `AppendEmergencyTriggerEvent` أو أي منطق كتابة تقرير إلى Risk.
- لا كتابة مزدوجة لـ `EmergencyTriggers.csv`.
- لا تغيير سلوك. Summary يطابق.
- لا تعديل نسخة ReportWriter من الـ Apply\* (المسار العامل).
- لا حذف الدوال النقية الثلاث قبل التحقّق أنها غير مُستدعاة من ReportWriter.

---

## 7. بعد R0.7b-fix

عند نجاح الترجمة + تطابق Summary → **commit واحد** (يُكمل R0.7b):
```
git add -A
git commit -m "R0.7b - port Risk Apply* methods + processor inputs + record-based emergency hook"
```
ثم R0.7c (#3 و#12).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_7b_fix_SPEC.md` ونفّذه بأجزائه الثلاثة: (1) أنشئ
> `Risk/FalconRiskLifecycleProcessorInputs.mqh` وانقل إليه الـ 11 ماكرو
> (9 من الملف الرئيسي + 2 من ExecutionInputs)، ضمّنه قبل المعالج. (2)
> انقل الدوال النقية الثلاث (`FalconForceCloseOverrideNetPoints`،
> `FalconForceCloseOverrideNetUsd`، `CurrentPaperRiskCapitalBeforeTrade`)
> من ReportWriter إلى المعالج كأعضاء private — تحقّق أنها غير مُستدعاة من
> ReportWriter قبل الحذف، وإلا أبلِغ. (3) لـ `AppendEmergencyTriggerEvent`:
> لا تنقلها؛ أضِف حقول `emergency_*` إلى `FalconTradeLifecycleRecord`،
> واجعل نسخة المعالج من `ApplyThreeLayerEmergency` تكتب فيها بدل استدعاء
> ReportWriter. **لا تجعل ReportWriter يقرأ تلك الحقول ويكتب** — ذلك
> لـ R0.7d؛ نسخة ReportWriter من Apply\* تبقى تستدعي
> `AppendEmergencyTriggerEvent` مباشرةً (المسار العامل، صفر تغيير سلوك،
> لا كتابة مزدوجة). حدّث `Docs/ReviewNotes/R0_7b_Review_Notes.md`. اجعله
> في commit واحد. بعد الانتهاء أكّد git diff --stat.
