# JA FalconCore — R0.5
## إعادة الهيكلة — المرحلة الخامسة: نقل طبقة Router
### مواصفات للتسليم إلى Claude Code

> **الهدف:** نقل كلاسات طبقة Router إلى `Router/*.mqh`.
> **الأساس:** فرع `refactor`، آخر commit `c3acba4` (R0.4).

---

## 0. لماذا R0.5

مرحلة خفيفة بعد ثِقَل R0.4. تنقل كلاسين فقط:
- `CFalconStrategyRegistry` (~221 سطر) — سجلّ الاستراتيجيات + تصنيف الصحّة.
- `CFalconFirstShadowStrategyAdapterShell` (~126 سطر) — غلاف محوّل
  الاستراتيجية الأولى.

إجمالي ~347 سطرًا. النقل المعتاد: قصّ، لصق، `#include`.

---

## 1. القيود الصارمة

- **صفر تغيير سلوك.** الكود المنقول ينتج نفس النتيجة بالضبط.
- لا تعديل منطق، لا تعديل input، لا حذف وظيفة.
- النقل = قصّ + لصق + `#include`. لا إعادة كتابة.
- **لا لمس سلسلة الـ 12 `Apply*`** — تبقى في ReportWriter.
- لا نقل globals (تُؤجَّل).
- لا نقل البنى المشتركة من Core (تُوزَّع في R0.7).
- لا `OrderSend`، لا لمس تنفيذ.

---

## 2. ما يُنقَل في R0.5

| الملف الهدف | المحتوى المنقول |
|---|---|
| `Router/FalconStrategyRegistry.mqh` | `CFalconStrategyRegistry` (~221 سطر) |
| `Router/FalconStrategyAdapterShell.mqh` | `CFalconFirstShadowStrategyAdapterShell` (~126 سطر) |

إن وُجدت inputs أو macros تخصّ Router حصريًا ويحتاجها الكود المنقول قبل
نقطة تعريفها → تُنقَل إلى `Router/FalconRouterInputs.mqh` يُضمَّن قبل
الكلاسات. (نفس حلّ R0.2-fix.)

> ملف placeholder في `Router/` يُحذف بعد إنشاء الملفات الحقيقية.

---

## 3. ترتيب الـ `#include`

Router يعتمد على Core (وربما Strategies/Evidence). يُضمَّن **بعد** كتلة
Execution العليا:
```cpp
// ... Core (R0.2) ...
// ... Evidence + Risk (R0.3) ...
// ... Execution العليا (R0.4) ...
#include "Router/FalconRouterInputs.mqh"        // إن لزم — قبل الكلاسات
#include "Router/FalconStrategyRegistry.mqh"
#include "Router/FalconStrategyAdapterShell.mqh"
```

> تنبيه: إن كان أيٌّ من كلاسَي Router يعتمد على `CFalconReportWriter` أو
> على كلاسات استراتيجية S00 المعرَّفة لاحقًا في الملف الرئيسي، فقد يلزم
> تضمين ذلك الملف بعد تعريف التبعية — كما حدث مع جسر البروكر في R0.4.
> افحص التبعيات وضع الـ `#include` في الموضع الصحيح.

كل ملف `.mqh` بحارس تضمين.

---

## 4. بروتوكول "راجع وأصلح أثناء النقل" — إلزامي

عند نقل كل كلاس، افحص:

1. **lookahead:** هل يقرأ شمعة غير مغلقة؟
2. **globals:** أي `g_` يستخدمه — سجّله (لا تنقله).
3. **منطق ميت:** فروع/متغيّرات لا تُستخدَم.
4. **أخطاء صامتة:** فشل لا يُبلَّغ عنه.
5. **تشابك:** سجّل أي استدعاء بين Router وReportWriter أو كلاسات
   الاستراتيجية — مهم لـ R0.6/R0.7.

كل ما يُكتشَف → `R0_5_Review_Notes.md`. الإصلاح الآمن يُطبَّق ويُوثَّق؛ غير
الآمن يُؤجَّل ويُسجَّل.

---

## 5. معايير القبول

- 2 ملفّا Router موجودان، كل واحد بحارس تضمين.
- ملف placeholder الخاص بـ Router محذوف.
- كتلة `#include` صحيحة الترتيب.
- الكود المنقول مُزال من الملف الرئيسي (لا تكرار).
- سلسلة الـ 12 `Apply*` ما زالت في ReportWriter (`grep` يعطي 12).
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17`،
  `FinalWorkingNetUSD = 1104.89`، وحساب البروكر 157.49 بالضبط.
- `R0_5_Review_Notes.md` موجود.

---

## 6. ما يجب ألا يحدث

- لا تغيير سلوك. Summary + نتيجة البروكر تطابق.
- لا لمس الـ 12 `Apply*`.
- لا نقل أي شيء خارج طبقة Router.
- لا نقل globals أو البنى المشتركة.
- لا إعادة كتابة منطق.

---

## 7. بعد R0.5

عند نجاح الترجمة + تطابق Summary ونتيجة البروكر → **commit واحد**:
```
git add -A
git commit -m "R0.5 - migrate Router layer (StrategyRegistry, StrategyAdapterShell)"
```
ثم R0.6 (تفكيك `CFalconReportWriter` كمديول تقارير قابل للتشغيل/الإطفاء).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_5_SPEC.md` ونفّذه: نقل `CFalconStrategyRegistry`
> و`CFalconFirstShadowStrategyAdapterShell` إلى `Router/*.mqh`، مع حارس
> تضمين وكتلة `#include` في الموضع الصحيح حسب التبعيات. النقل حرفي — لا
> إعادة كتابة، لا تغيير سلوك. لا تلمس الـ 12 `Apply*`. لا تنقل globals ولا
> البنى المشتركة. طبّق بروتوكول "راجع وأصلح أثناء النقل" واكتب
> `R0_5_Review_Notes.md`. اجعل R0.5 في **commit واحد**. بعد الانتهاء أكّد
> git diff --stat واعرض ملخص النقل + ملاحظات المراجعة.
