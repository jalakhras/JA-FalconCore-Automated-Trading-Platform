# JA FalconCore — R0.7a
## إعادة الهيكلة — أساس فصل الـ Apply* (تجهيز الناقل المشترك)
### مواصفات للتسليم إلى Claude Code

> **الهدف:** تجهيز البنية التي ستستقبل الـ 12 `Apply*` لاحقًا — **دون نقل
> أي دالة بعد**. خطوة تأسيسية آمنة، صفر تغيير سلوك.
> **الأساس:** فرع `refactor`، آخر commit `a2a80ee` (R0.6b).

---

## 0. لماذا R0.7a — ولماذا لا ننقل شيئًا فيها

R0.7 (فصل الـ 12 `Apply*` من `CFalconReportWriter`) هي **أخطر مرحلة في
إعادة الهيكلة**. مراجعة R0.6a §3.5 حذّرت: ترتيب الـ `Apply*` ذو معنى —
دوال تقرأ نتائج دوال قبلها (#10 يحتاج #9، #11 يقرأ #5/#6)، وكلّها تتشارك
"ناقل بيانات": سجلّ الصفقة + `m_totals`.

لذلك R0.7 مقسّمة إلى 4 خطوات. **R0.7a (هذه) هي الأساس فقط:**
- تُنشئ هيكل طبقة Risk الجديدة (كلاس فارغ + ملف عقد).
- **لا تنقل أي دالة `Apply*`** — كلّها تبقى في ReportWriter.
- تثبت أن الهيكل الجديد يُترجَم ويُضمَّن نظيفًا.
- صفر تغيير سلوك تمامًا.

R0.7a كـ R0.1 — تأسيس قبل النقل. إن نجحت، يصبح لدينا "وعاء" جاهز
يستقبل الدوال في R0.7b/c/d.

---

## 1. القيود الصارمة

- **صفر تغيير سلوك.** لا دالة تُنقَل، لا منطق يُمَسّ.
- **لا لمس الـ 12 `Apply*`** — تبقى كاملةً في `Reporting/FalconReportWriter.mqh`.
- لا تعديل `RegisterClosedTrade`.
- لا تعديل input، لا حذف وظيفة.
- العمل كله: إنشاء ملفّين جديدين + `#include` + إثبات الترجمة.

---

## 2. ما يُنشَأ في R0.7a

### 2.1 `Risk/FalconTradeLifecycleContract.mqh` — عقد الناقل المشترك

ملف يوثّق **عقد البيانات** الذي ستتشاركه سلسلة الـ `Apply*` وطبقة Risk:
- تعريف/إعلان (typedef أو توثيق) لبنية سجلّ الصفقة (`lifecycle-record`)
  التي تمرّ عبر السلسلة.
- تعريف/إعلان لبنية `m_totals` (أو إشارة إليها) — العدّادات التراكمية.

> ملاحظة: إن كانت بنى `lifecycle-record` و`m_totals` معرَّفة حاليًا في
> `Core/FalconDataStructures.mqh` — **لا تنقلها**. اكتفِ في R0.7a بأن
> يحوي ملف العقد توثيقًا + `#include` لمصدرها الحالي + أي typedef لازم.
> النقل الفعلي للبنى يُؤجَّل (قد يكون R0.7b أو R0.8). R0.7a لا تحرّك بنى.

الغرض من الملف الآن: نقطة مرجعية واحدة معروفة لـ "ما هو الناقل" — تستند
إليها R0.7b/c/d.

### 2.2 `Risk/FalconRiskLifecycleProcessor.mqh` — الكلاس المستقبِل

ملف فيه كلاس `CFalconRiskLifecycleProcessor` بحارس تضمين. في R0.7a يكون
**هيكلًا شبه فارغ**:
- إعلان الكلاس.
- دالة عامة واحدة هي العقد: `ApplyTradeLifecycleChain(record)` —
  **في R0.7a جسمها فارغ أو placeholder** (لا تفعل شيئًا، أو تُرجع فورًا).
- لا تحوي أي دالة `Apply*` بعد — تُملأ في R0.7b/c/d.
- تعليق يوضّح: "الدوال الـ 12 تُنقَل هنا تدريجيًّا في R0.7b/c/d بالترتيب
  #1..#12 المحفوظ."

> الكلاس لا يُستدعى فعليًّا من `RegisterClosedTrade` في R0.7a — فقط
> يُعرَّف ويُضمَّن. ربط الاستدعاء يحدث في R0.7d (بعد نقل كل الدوال).
> هذا يضمن صفر تغيير سلوك في R0.7a.

---

## 3. ترتيب الـ `#include`

الملفّان الجديدان في طبقة Risk. يُضمَّنان ضمن/بعد كتلة Risk الحالية (R0.3):
```cpp
// ... Risk (R0.3): FalconRiskInputs, FalconRiskFoundation, FalconRiskTradeManagement ...
#include "Risk/FalconTradeLifecycleContract.mqh"
#include "Risk/FalconRiskLifecycleProcessor.mqh"
```
كل ملف بحارس تضمين. إن احتاج `CFalconRiskLifecycleProcessor` رؤية بنى من
`Core/` — فهي مُضمَّنة قبله أصلًا (Core أوّل كتلة).

---

## 4. بروتوكول المراجعة

R0.7a لا تنقل منطقًا، فالمراجعة خفيفة:
1. تأكّد أن الكلاس الجديد لا يكسر أي تبعية.
2. تأكّد أن الـ 12 `Apply*` ما زالت كاملةً في ReportWriter وغير ممسوسة.
3. سجّل في `Docs/ReviewNotes/R0_7a_Review_Notes.md`: تأكيد أن R0.7a
   تأسيس فقط، وخطة الخطوات R0.7b/c/d (من خريطة §3.5 لمراجعة R0.6a).

---

## 5. معايير القبول

- `Risk/FalconTradeLifecycleContract.mqh` موجود، بحارس تضمين.
- `Risk/FalconRiskLifecycleProcessor.mqh` موجود، فيه كلاس
  `CFalconRiskLifecycleProcessor` بدالة `ApplyTradeLifecycleChain` فارغة.
- كتلة `#include` تضمّ الملفّين بعد كتلة Risk.
- الـ 12 `Apply*` ما زالت في `Reporting/FalconReportWriter.mqh`
  (`grep -cE "void Apply[A-Z]"` يعطي 12).
- لا تغيير في `RegisterClosedTrade`.
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17`،
  `FinalWorkingNetUSD = 1104.89`، بروكر 157.49 — **مطابق تمامًا** (لأن لا
  منطق تغيّر — الكلاس الجديد غير مُستدعى بعد).
- `Docs/ReviewNotes/R0_7a_Review_Notes.md` موجود.

---

## 6. ما يجب ألا يحدث

- لا نقل أي دالة `Apply*` (ذلك R0.7b/c/d).
- لا استدعاء للكلاس الجديد من `RegisterClosedTrade` (ذلك R0.7d).
- لا تحريك بنى البيانات من `Core/`.
- لا تغيير سلوك — Summary يطابق بايت-ببايت.
- لا نقل globals.

---

## 7. بعد R0.7a

عند نجاح الترجمة + تطابق Summary → **commit واحد**:
```
git add -A
git commit -m "R0.7a - foundation: Risk lifecycle processor shell + trade lifecycle contract"
```
ثم R0.7b (نقل دوال Risk السبع #7-#12 إلى `CFalconRiskLifecycleProcessor`).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_7a_SPEC.md` ونفّذه: أنشئ ملفّين جديدين في `Risk/`
> — `FalconTradeLifecycleContract.mqh` (عقد توثيقي لبنية سجلّ الصفقة
> و`m_totals`، مع `#include` لمصدرها في Core، دون تحريك أي بنية) و
> `FalconRiskLifecycleProcessor.mqh` (كلاس `CFalconRiskLifecycleProcessor`
> بحارس تضمين، فيه دالة عامة واحدة `ApplyTradeLifecycleChain(record)`
> جسمها فارغ/placeholder). أضِف `#include` للملفّين بعد كتلة Risk. **لا
> تنقل أي دالة `Apply*`** — الـ 12 تبقى كاملةً في
> `Reporting/FalconReportWriter.mqh`. **لا تستدعِ الكلاس الجديد** من
> `RegisterClosedTrade` بعد. لا تحرّك بنى من Core. صفر تغيير سلوك. اكتب
> `Docs/ReviewNotes/R0_7a_Review_Notes.md`. اجعل R0.7a في commit واحد.
> بعد الانتهاء أكّد git diff --stat وأن الـ 12 `Apply*` ما زالت في
> ReportWriter.
