# JA FalconCore — R0.4
## إعادة الهيكلة — المرحلة الرابعة: نقل Execution + عزل جسر البروكر
### مواصفات للتسليم إلى Claude Code

> **الهدف:** نقل كلاسات طبقة Execution إلى `Execution/*.mqh`، وأهمّها عزل
> `CFalconBrokerEntryBridge` (2,735 سطرًا) في ملف مستقل.
> **الأساس:** فرع `refactor`، آخر commit `c93b728` (R0.3).

---

## 0. لماذا R0.4 — وحساسيتها

R0.4 أثقل من R0.2/R0.3. تنقل أربعة كلاسات، أحدها `CFalconBrokerEntryBridge`
— ثاني أكبر كلاس في المشروع (2,735 سطرًا)، ويحوي **منطق التنفيذ الحسّاس**:
`OrderSend` (الدخول والإغلاق العكسي)، الـ emergency server SL/TP envelope،
`OnTradeTransaction`، الإغلاق المُدار، والـ Virtual Trailing (v0.57.2/3/4).

**لكن المبدأ نفسه:** R0.4 **نقل**، لا تعديل. ننقل الكلاس كما هو حرفيًا إلى
ملف `.mqh`. لا نلمس منطق `OrderSend`، لا الـ emergency SL/TP، لا الـ
trailing. صفر تغيير سلوك. مجرّد قصّ ولصق و`#include`.

---

## 1. القيود الصارمة

- **صفر تغيير سلوك.** الكود المنقول ينتج نفس النتيجة بالضبط.
- لا تعديل منطق `OrderSend`، لا الـ emergency server SL/TP، لا الـ Virtual
  Trailing، لا `TryManagedCloseFromLifecycleRecord`، لا
  `ExecuteReverseClosePositionRequest`.
- لا تعديل input، لا حذف وظيفة.
- النقل = قصّ من الملف الرئيسي + لصق في `.mqh` + `#include`. لا إعادة كتابة.
- **لا لمس سلسلة الـ 12 `Apply*`** — تبقى في ReportWriter (تُفصَل في R0.7).
- لا نقل globals (تُؤجَّل).
- البنى المشتركة (`FalconBrokerTradeLink`, `FalconBrokerTradeManagementEvent`)
  تبقى في `Core/FalconDataStructures.mqh` حاليًا — توزَّع في R0.7. لا تُنقَل
  في R0.4.

---

## 2. ما يُنقَل في R0.4

| الملف الهدف | المحتوى المنقول |
|---|---|
| `Execution/FalconExecutionGuard.mqh` | `CFalconExecutionGuard` (~29 سطر) |
| `Execution/FalconRuntimeSafetyGuard.mqh` | `CFalconRuntimeSafetyGuard` (~184 سطر) |
| `Execution/FalconShadowExecutor.mqh` | `CFalconShadowExecutor` (~248 سطر) |
| `Execution/FalconBrokerEntryBridge.mqh` | `CFalconBrokerEntryBridge` (~2,735 سطر) — جسر التنفيذ v0.56.x + Virtual Trailing v0.57.2/3/4 |

إن وُجدت inputs تخصّ Execution حصريًا ويحتاجها الكود المنقول قبل نقطة
تعريفها → تُنقَل إلى `Execution/FalconExecutionInputs.mqh` يُضمَّن قبل
الكلاسات. (نفس حلّ R0.2-fix.) لاحظ خاصةً مدخلات الـ Virtual Trailing
(`EnableVirtualTrailingBridge`, `VirtualTrailingStartPoints`,
`VirtualTrailingDistancePoints`, `VirtualBreakevenAtPoints`,
`EnableStructuralBreakeven`, `VirtualSwingLookbackBars`,
`VirtualSwingMaxLookback`) ومدخلات التنفيذ (`EnableRealExecution`,
`EnableShadowMode`, `EnablePaperMode`, `MaxTradesPerDay`, `MaxOpenPositions`).

> ملف placeholder في `Execution/` يُحذف بعد إنشاء الملفات الحقيقية.

---

## 3. ترتيب الـ `#include`

Execution يعتمد على Core + Risk. يُضمَّن **بعد** كتلتَي Core وEvidence/Risk:
```cpp
// ... كتلة Core (R0.2) ...
// ... كتلة Evidence + Risk (R0.3) ...
#include "Execution/FalconExecutionInputs.mqh"   // إن لزم — قبل الكلاسات
#include "Execution/FalconExecutionGuard.mqh"
#include "Execution/FalconRuntimeSafetyGuard.mqh"
#include "Execution/FalconShadowExecutor.mqh"
#include "Execution/FalconBrokerEntryBridge.mqh"
```
رتّب الكلاسات الأربعة حسب تبعيّتها لبعضها (إن وُجدت). كل ملف بحارس تضمين.

---

## 4. بروتوكول "راجع وأصلح أثناء النقل" — إلزامي

عند نقل كل كلاس، افحص قبل اعتماده:

1. **lookahead:** فحص دقيق — `CopyRates`, `iHigh/iLow`, الوصول للشموع.
   خاصةً `FindLastSwingLow/High` في الـ Virtual Trailing: تأكّد أنها تقرأ
   شموعًا مغلقة فقط (`shift ≥ 1`) كما تنصّ مواصفة v0.57.4.
2. **globals:** أي `g_` يستخدمه — سجّله (لا تنقله الآن). لاحظ
   `g_broker_entry_bridge` وغيره من singletons.
3. **منطق ميت:** فروع/متغيّرات لا تُستخدَم.
4. **أخطاء صامتة:** فشل `OrderSend` لا يُبلَّغ عنه، قيمة retcode مهملة.
5. **بوّابات الأمان:** تأكّد أن كل مسار `OrderSend` ما زال محكومًا بـ
   `EnableRealExecution && MQLInfoInteger(MQL_TESTER)` — لم تنكسر بوّابة
   أمان أثناء النقل.
6. **تشابك مع ReportWriter:** سجّل أي استدعاء من الـ bridge إلى
   `CFalconReportWriter` أو العكس — مهم لـ R0.6/R0.7.

كل ما يُكتشَف → `R0_4_Review_Notes.md`. الإصلاح الآمن يُطبَّق ويُوثَّق؛ غير
الآمن يُؤجَّل ويُسجَّل.

---

## 5. معايير القبول

- 4 ملفات `Execution/*.mqh` موجودة، كل واحد بحارس تضمين.
- ملف placeholder الخاص بـ Execution محذوف.
- كتلة `#include` صحيحة الترتيب (Execution بعد Core وRisk).
- الكود المنقول مُزال من الملف الرئيسي (لا تكرار).
- سلسلة الـ 12 `Apply*` ما زالت في ReportWriter (`grep` يعطي 12).
- كل مسارات `OrderSend` ما زالت محكومة ببوّابة الأمان.
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17`،
  `FinalWorkingNetUSD = 1104.89`، وحساب البروكر ينتهي عند 157.49 بالضبط.
- `R0_4_Review_Notes.md` موجود.

---

## 6. ما يجب ألا يحدث

- لا تغيير سلوك. Summary + نتيجة البروكر يجب أن تطابق.
- لا تعديل منطق `OrderSend` / emergency SL/TP / Virtual Trailing.
- لا لمس الـ 12 `Apply*`.
- لا نقل أي شيء خارج طبقة Execution.
- لا نقل globals أو البنى المشتركة.
- لا إعادة كتابة منطق.

---

## 7. بعد R0.4

عند نجاح الترجمة + تطابق Summary ونتيجة البروكر → commit واحد:
```
git add -A
git commit -m "R0.4 - migrate Execution layer + isolate broker entry bridge"
```
ثم R0.5 (نقل Router).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_4_SPEC.md` ونفّذه: نقل الكلاسات الأربعة لطبقة
> Execution (ExecutionGuard، RuntimeSafetyGuard، ShadowExecutor،
> BrokerEntryBridge) إلى `Execution/*.mqh`، مع حارس تضمين وكتلة `#include`
> بعد Core وRisk، وملف inputs للتنفيذ إن لزم ترتيب المعالج. النقل حرفي —
> لا إعادة كتابة، لا تغيير سلوك. لا تلمس منطق OrderSend أو الـ emergency
> server SL/TP أو الـ Virtual Trailing أو الـ 12 `Apply*`. تأكّد أن كل
> مسار OrderSend يبقى محكومًا بـ EnableRealExecution && MQL_TESTER. لا تنقل
> globals ولا البنى المشتركة. طبّق بروتوكول "راجع وأصلح أثناء النقل"
> (قسم 4) واكتب `R0_4_Review_Notes.md`. اجعل R0.4 في commit واحد. بعد
> الانتهاء أكّد git diff --stat واعرض ملخص النقل + ملاحظات المراجعة.
