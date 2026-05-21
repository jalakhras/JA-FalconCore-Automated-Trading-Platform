# JA FalconCore — R0.3
## إعادة الهيكلة — المرحلة الثالثة: نقل Evidence + Risk
### مواصفات للتسليم إلى Claude Code

> **الهدف:** نقل كلاسات طبقتَي Evidence وRisk إلى `Evidence/*.mqh`
> و`Risk/*.mqh`، مع مراجعة منطق كل كلاس أثناء النقل.
> **الأساس:** فرع `refactor`، آخر commit `a5b5911` (R0.2).

---

## 0. لماذا R0.3 — ونطاقها المحدود

R0.2 نقلت طبقة Core. R0.3 تنقل طبقتين صغيرتين نسبيًا: Evidence وRisk.

**تنبيه مهم على نطاق Risk:** الجرد كشف أن منطق المخاطر **الثقيل** ليس في
كلاسات Risk — بل في سلسلة الـ 12 `Apply*` المحشورة داخل
`CFalconReportWriter`. كلاسات Risk النقية صغيرة:
- `CFalconRiskFoundation` (~72 سطر) — بوّابة التحقق من المدخلات.
- `CFalconRiskTradeManagementArchitecture` (~70 سطر) — هيكل (scaffold).

R0.3 تنقل **هذين الكلاسين فقط** من طبقة Risk. الـ 12 `Apply*` **لا تُمَسّ
في R0.3** — تبقى داخل ReportWriter، وتُفصَل في R0.7 (التصحيح المعماري في
خطة إعادة الهيكلة، قسم 2-C).

---

## 1. القيود الصارمة

- **صفر تغيير سلوك.** الكود المنقول ينتج نفس النتيجة. الاستثناء الوحيد:
  خطأ يُكتشَف أثناء المراجعة ويُصلَح فقط إن كان آمنًا (لا يغيّر Summary)،
  ويُوثَّق.
- لا تعديل منطق، لا تعديل input، لا حذف وظيفة.
- النقل = قصّ من الملف الرئيسي + لصق في `.mqh` + `#include`. لا إعادة كتابة.
- **لا لمس سلسلة الـ 12 `Apply*`** — تبقى في ReportWriter.
- لا نقل globals (تُؤجَّل لمرحلة لاحقة).
- لا `OrderSend`، لا لمس تنفيذ.

---

## 2. ما يُنقَل في R0.3

| الملف الهدف | المحتوى المنقول |
|---|---|
| `Evidence/FalconEvidenceFramework.mqh` | `CFalconEvidenceFramework` (~232 سطر) |
| `Risk/FalconRiskFoundation.mqh` | `CFalconRiskFoundation` (~72 سطر) |
| `Risk/FalconRiskTradeManagement.mqh` | `CFalconRiskTradeManagementArchitecture` (~70 سطر) |

إن وُجدت inputs تخصّ Evidence أو Risk حصريًا ويحتاجها الكود المنقول قبل
نقطة تعريفها — تُنقَل إلى ملف inputs مناسب (`Evidence/FalconEvidenceInputs.mqh`
أو `Risk/FalconRiskInputs.mqh`) يُضمَّن قبل الكلاس. (نفس حلّ R0.2-fix.)

> ملفات placeholder في `Evidence/` و`Risk/` تُحذف بعد إنشاء الملفات
> الحقيقية، ويُحدَّث الـ `#include`.

---

## 3. ترتيب الـ `#include`

Evidence وRisk يعتمدان على Core. يُضمَّنان **بعد** كتلة Core:
```cpp
// ... كتلة Core (من R0.2) ...
#include "Evidence/FalconEvidenceFramework.mqh"
#include "Risk/FalconRiskFoundation.mqh"
#include "Risk/FalconRiskTradeManagement.mqh"
```
(مع أي ملف inputs لازم، يُضمَّن قبل الكلاس الذي يحتاجه.)
كل ملف `.mqh` له حارس تضمين.

---

## 4. بروتوكول "راجع وأصلح أثناء النقل" — إلزامي

عند نقل كل كلاس، افحص قبل اعتماده:

1. **lookahead:** هل يقرأ شمعة غير مغلقة؟ بيانات مستقبلية؟
2. **globals:** أي `g_` يستخدمه — سجّله (لا تنقله الآن).
3. **منطق ميت:** متغيّرات/فروع لا تُستخدَم.
4. **أخطاء صامتة:** قيمة مهملة، فشل لا يُبلَّغ عنه.
5. **تشابك مع `Apply*`:** إن وجدت أن كلاس Risk يستدعي أو يتداخل مع دوال
   `Apply*` — سجّل ذلك بدقة. هذا مهم لتخطيط R0.7.

كل ما يُكتشَف → `R0_3_Review_Notes.md`. الإصلاح الآمن يُطبَّق ويُوثَّق؛ غير
الآمن يُؤجَّل ويُسجَّل.

---

## 5. معايير القبول

- 3 ملفات (Evidence + Risk) موجودة، كل واحد بحارس تضمين.
- ملفات placeholder الخاصة بـ Evidence وRisk محذوفة.
- كتلة `#include` صحيحة الترتيب (Evidence/Risk بعد Core).
- الكود المنقول مُزال من الملف الرئيسي (لا تكرار).
- سلسلة الـ 12 `Apply*` ما زالت في ReportWriter، غير ممسوسة
  (`grep` يعطي 12).
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17` و
  `FinalWorkingNetUSD = 1104.89` بالضبط.
- `R0_3_Review_Notes.md` موجود.

---

## 6. ما يجب ألا يحدث

- لا تغيير سلوك. Summary يطابق.
- لا لمس الـ 12 `Apply*`.
- لا نقل أي شيء خارج Evidence + Risk (الكلاسان المحدّدان).
- لا نقل globals.
- لا إعادة كتابة منطق.

---

## 7. بعد R0.3

عند نجاح الترجمة + تطابق Summary → commit (يدمج حذف ملفات SPEC المعلّقة):
```
git add -A
git commit -m "R0.3 - migrate Evidence + Risk layer classes"
```
ثم R0.4 (نقل Execution + عزل جسر البروكر).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_3_SPEC.md` ونفّذه: نقل `CFalconEvidenceFramework`
> إلى `Evidence/FalconEvidenceFramework.mqh`، و`CFalconRiskFoundation` +
> `CFalconRiskTradeManagementArchitecture` إلى `Risk/*.mqh`، مع حارس تضمين
> وكتلة `#include` بعد Core. النقل حرفي — لا إعادة كتابة، لا تغيير سلوك.
> لا تلمس سلسلة الـ 12 `Apply*` (تبقى في ReportWriter). لا تنقل globals.
> طبّق بروتوكول "راجع وأصلح أثناء النقل" (قسم 4) واكتب `R0_3_Review_Notes.md`
> — وسجّل بدقة أي تشابك بين كلاسات Risk والـ `Apply*`. الـ commit يدمج حذف
> ملفات SPEC الثلاثة المعلّقة من R0.1/R0.2. بعد الانتهاء أكّد git diff --stat
> واعرض ملخص النقل + ملاحظات المراجعة.
