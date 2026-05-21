# JA FalconCore — R0.7b
## إعادة الهيكلة — نقل دوال Risk العشر إلى المعالج
### مواصفات للتسليم إلى Claude Code

> **الهدف:** نقل أجسام الـ 10 دوال `Apply*` "Risk-natural" من
> `CFalconReportWriter` إلى `CFalconRiskLifecycleProcessor` — **نقل أجسام
> فقط، دون تحويل الاستدعاء بعد**.
> **الأساس:** فرع `refactor`، آخر commit = R0.7a.

---

## 0. لماذا R0.7b — والاستراتيجية

R0.7a جهّزت الوعاء (`CFalconRiskLifecycleProcessor` + دالة
`ApplyTradeLifecycleChain` الفارغة). R0.7b أول نقل فعلي للدوال.

**استراتيجية "خيار 1" — نقل أجسام فقط:**
- نقل أجسام الـ 10 دوال إلى المعالج كأعضاء `private`.
- ملؤها داخل `ApplyTradeLifecycleChain` بالترتيب الصحيح.
- **`RegisterClosedTrade` يبقى دون تغيير** — يستدعي نسخته الخاصّة من
  الدوال كما الآن.
- تحويل الاستدعاء إلى `ApplyTradeLifecycleChain` يؤجَّل إلى **R0.7d**.

**لماذا:** فصل النقل عن التحويل يجعل التشخيص واضحًا. R0.7b: المسار القديم
ما زال يعمل ← الأرقام تطابق ← يثبت أن النقل سليم. R0.7d: تحويل النداء ←
الأرقام تطابق ← يثبت أن التحويل سليم. لو دُمجا وانكسر رقم، لا نعرف السبب.

---

## 1. الازدواج المؤقّت — مقصود، لا تحذفه

بعد R0.7b، الـ 10 دوال ستوجد **نسختين**:
- نسخة في `Reporting/FalconReportWriter.mqh` — **تعمل** (يستدعيها
  `RegisterClosedTrade`).
- نسخة في `Risk/FalconRiskLifecycleProcessor.mqh` — **لا تُستدعى بعد**.

**هذا ازدواج مؤقّت مقصود.** لا تحذف نسخة ReportWriter في R0.7b — حذفها
يحدث في R0.7d بعد تحويل النداء. R0.7b يضيف، لا يحذف.

> النتيجة: `grep "void Apply"` سيعطي عددًا أكبر مؤقّتًا. هذا متوقّع
> وصحيح في R0.7b.

---

## 2. الدوال العشر — بالترتيب الحرج

من خريطة `Docs/ReviewNotes/R0_6a_Review_Notes.md §3.5` (مواقعها في
`Reporting/FalconReportWriter.mqh`):

| ترتيب السلسلة | الدالة | LOC |
|---:|---|---:|
| #1 | `ApplyNoNewEntryUserOverridePaperEnforcement` | 42 |
| #2 | `ApplyDailyWeekendForceCloseUserOverridePaperEnforcement` | 86 |
| #4 | `ApplyPaperRuntimeGuardApplication` | 30 |
| #5 | `ApplyPaperRuntimeSmartSLProtectionApplication` | 77 |
| #6 | `ApplyPaperRuntimeRunnerApplication` | 80 |
| #7 | `ApplyCapitalTierFoundation` | 27 |
| #8 | `ApplyLowCapitalRiskFeasibilityFoundation` | 96 |
| #9 | `ApplyCalibratedSingleTradeLossCapEnforcement` | 82 |
| #10 | `ApplyDynamicLotSizingModel` | 134 |
| #11 | `ApplyThreeLayerEmergencyApplication` | 161 |

(#3 و#12 ليسا في هذه الدفعة — يُعالَجان في R0.7c.)

**قيد حرج — الترتيب:** الدوال ليست مستقلّة. #10 يقرأ نتيجة #9؛ #11 يقرأ
حالة SL/runner من #5/#6. داخل `ApplyTradeLifecycleChain` **يجب** أن
تُستدعى بهذا الترتيب الدقيق: #1، #2، #4، #5، #6، #7، #8، #9، #10، #11.

---

## 3. الخطوات

### 3.1 نقل الأجسام
لكل دالة من العشر، **انسخ** جسمها من `Reporting/FalconReportWriter.mqh`
إلى `Risk/FalconRiskLifecycleProcessor.mqh` كعضو `private` في الكلاس
`CFalconRiskLifecycleProcessor`. **النسخ حرفي** — لا تعديل منطق، لا إعادة
كتابة.

> النسخة في ReportWriter تبقى كما هي (الازدواج المؤقّت — قسم 1).

### 3.2 ملء `ApplyTradeLifecycleChain`
داخل `ApplyTradeLifecycleChain(FalconTradeLifecycleRecord &record)`،
استبدل `return;` الفارغة باستدعاء الدوال العشر بالترتيب الحرج:
```cpp
void ApplyTradeLifecycleChain(FalconTradeLifecycleRecord &record)
{
   ApplyNoNewEntryUserOverridePaperEnforcement(record);
   ApplyDailyWeekendForceCloseUserOverridePaperEnforcement(record);
   ApplyPaperRuntimeGuardApplication(record);
   ApplyPaperRuntimeSmartSLProtectionApplication(record);
   ApplyPaperRuntimeRunnerApplication(record);
   ApplyCapitalTierFoundation(record);
   ApplyLowCapitalRiskFeasibilityFoundation(record);
   ApplyCalibratedSingleTradeLossCapEnforcement(record);
   ApplyDynamicLotSizingModel(record);
   ApplyThreeLayerEmergencyApplication(record);
   // #3 و#12 يُضافان في R0.7c
}
```

### 3.3 معالجة التبعيات
إن كانت الدوال المنقولة تستخدم:
- حقولًا/دوالًا من `m_totals` أو حالة داخلية لـ ReportWriter →
  يجب أن يصل المعالج إليها. مرّرها كمعامل، أو وفّر للمعالج مرجعًا للناقل
  المشترك. **لا تكرّر حالة** — استخدم نفس الناقل.
- `CFalconLogger` أو بنى Core → مُضمَّنة أصلًا، متاحة.
سجّل كل تبعية وكيف حُلّت في ملف المراجعة.

> إن تبيّن أن دالة تعتمد بعمق على حالة خاصّة بـ ReportWriter يصعب
> فصلها — **توقّف، لا تُجبر الحلّ**، سجّل ذلك في ملف المراجعة وأبلغ، حتى
> نقرّر معًا.

---

## 4. القيود الصارمة

- **صفر تغيير سلوك.** المسار القديم (`RegisterClosedTrade`) ما زال يعمل.
- نسخ حرفي للأجسام — لا إعادة كتابة منطق.
- **لا تحذف** نسخة ReportWriter (الازدواج مؤقّت — R0.7d يحذفها).
- **لا تعدّل `RegisterClosedTrade`** — لا تحويل نداء في R0.7b.
- لا تلمس #3 و#12.
- لا نقل globals، لا تحريك بنى Core.
- الترتيب الحرج للدوال العشر داخل `ApplyTradeLifecycleChain` ملزم.

---

## 5. معايير القبول

- الـ 10 دوال موجودة كأعضاء `private` في `CFalconRiskLifecycleProcessor`.
- `ApplyTradeLifecycleChain` تستدعيها بالترتيب الحرج.
- نسخة ReportWriter من الـ 10 ما زالت موجودة (الازدواج المؤقّت).
- `RegisterClosedTrade` لم يتغيّر.
- #3 و#12 لم تُمَسّا.
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17`،
  `FinalWorkingNetUSD = 1104.89`، بروكر 157.49 — **مطابق تمامًا** (المسار
  القديم ما زال هو العامل؛ نسخة المعالج غير مُستدعاة).
- `Docs/ReviewNotes/R0_7b_Review_Notes.md` موجود — يوثّق كل تبعية وكيف
  حُلّت.

---

## 6. ما يجب ألا يحدث

- لا حذف نسخة ReportWriter من الدوال.
- لا تعديل `RegisterClosedTrade`.
- لا تغيير سلوك. Summary يطابق.
- لا إعادة كتابة منطق — نسخ حرفي.
- لا لمس #3 و#12.
- لا إجبار حلّ لتبعية معقّدة — أبلِغ بدل ذلك.

---

## 7. بعد R0.7b

عند نجاح الترجمة + تطابق Summary → **commit واحد**:
```
git add -A
git commit -m "R0.7b - port 10 Risk-natural Apply* methods to CFalconRiskLifecycleProcessor"
```
ثم R0.7c (معالجة #3 و#12 — قرار وجهتيهما).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_7b_SPEC.md` ونفّذه: انسخ أجسام الـ 10 دوال
> `Apply*` المذكورة في القسم 2 من `Reporting/FalconReportWriter.mqh` إلى
> `Risk/FalconRiskLifecycleProcessor.mqh` كأعضاء `private` في
> `CFalconRiskLifecycleProcessor`، واملأ `ApplyTradeLifecycleChain`
> باستدعائها بالترتيب الحرج (#1،#2،#4،#5،#6،#7،#8،#9،#10،#11). **النسخ
> حرفي — لا تعديل منطق.** **لا تحذف** نسخة ReportWriter (ازدواج مؤقّت
> مقصود، يُحذف في R0.7d). **لا تعدّل `RegisterClosedTrade`.** لا تلمس
> الدالتين #3 و#12. عالِج تبعيات الناقل المشترك (m_totals/الحالة) دون
> تكرار حالة؛ إن صعب فصل تبعية أبلِغ بدل إجبار الحلّ. اكتب
> `Docs/ReviewNotes/R0_7b_Review_Notes.md` موثّقًا كل تبعية. اجعل R0.7b
> في commit واحد. بعد الانتهاء أكّد git diff --stat واعرض الملخص.
