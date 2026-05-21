# JA FalconCore — R0.2
## إعادة الهيكلة — المرحلة الثانية: نقل طبقة Core
### مواصفات للتسليم إلى Claude Code

> **الهدف:** نقل طبقة Core (Logger, MarketContext, CandleCache + الثوابت
> والأنواع والـ structs المشتركة) من الملف الرئيسي إلى ملفات `Core/*.mqh`،
> مع **مراجعة منطق كل قطعة أثناء النقل**.
> **الأساس:** فرع `refactor`، آخر commit `655564b` (R0.1).

---

## 0. لماذا R0.2

R0.1 أنشأت الهيكل الفارغ وأثبتت أن `#include` يعمل. R0.2 أول **نقل فعلي**:
ننقل أبسط طبقة وأقلّها تشابكًا — Core — لنثبت أن آلية النقل سليمة قبل
الطبقات الأصعب.

Core مختارة أولًا لأنها **قاعدة التبعية**: كل الطبقات الأخرى تعتمد عليها،
وهي لا تعتمد على شيء. نقلها أولًا يعني أن باقي المراحل تبني فوق أساس منقول.

---

## 1. القيود الصارمة

- **صفر تغيير سلوك.** الكود المنقول ينتج نفس النتيجة بالضبط. الاستثناء
  الوحيد: خطأ يُكتشَف أثناء المراجعة — يُصلَح فقط إن كان آمنًا (لا يغيّر
  `Summary`)، ويُوثَّق صراحةً. أي إصلاح يغيّر السلوك → يُؤجَّل ويُسجَّل، لا
  يُطبَّق.
- لا تعديل منطق، لا تعديل input، لا حذف وظيفة.
- النقل = قصّ من الملف الرئيسي + لصق في ملف `.mqh` + `#include`. لا إعادة
  كتابة.
- لا `OrderSend`، لا لمس تنفيذ.

---

## 2. ما يُنقَل في R0.2

طبقة Core — بالترتيب التالي (ترتيب التبعية):

| الملف الهدف | المحتوى المنقول |
|---|---|
| `Core/FalconConstants.mqh` | الـ `#define` المشتركة (الثوابت العامة فقط — لا الخاصة بطبقة واحدة) |
| `Core/FalconEnums.mqh` | الـ 22 enum |
| `Core/FalconDataStructures.mqh` | الـ 22 struct المشتركة |
| `Core/FalconLogger.mqh` | `CFalconLogger` (22 سطر) |
| `Core/FalconMarketContext.mqh` | `CFalconMarketContext` (200 سطر) |
| `Core/FalconCandleCache.mqh` | `CFalconCandleCache` (123 سطر) |

> ملاحظة: ملف `Core/FalconCore_Placeholder.mqh` يُحذف بعد إنشاء الملفات
> الحقيقية (لم يعد له داعٍ)، ويُحدَّث سطر الـ `#include` في الملف الرئيسي.

**ما لا يُنقَل في R0.2:** أي `#define` خاص بطبقة غير Core يبقى مكانه مؤقتًا
(يُنقَل مع طبقته لاحقًا). الهدف: نقل ما يخصّ Core فقط.

---

## 3. ترتيب الـ `#include` في الملف الرئيسي

بعد النقل، الملف الرئيسي يبدأ بكتلة `#include` بترتيب التبعية:
```cpp
#include "Core/FalconConstants.mqh"
#include "Core/FalconEnums.mqh"
#include "Core/FalconDataStructures.mqh"
#include "Core/FalconLogger.mqh"
#include "Core/FalconMarketContext.mqh"
#include "Core/FalconCandleCache.mqh"
```
كل ملف `.mqh` له حارس تضمين (`#ifndef ... #define ... #endif`).

---

## 4. بروتوكول "راجع وأصلح أثناء النقل" — إلزامي

عند نقل كل كلاس/قطعة، قبل اعتمادها، افحص:

1. **lookahead:** هل تستخدم `high/low` لشمعة غير مغلقة؟ هل تقرأ بيانات
   المستقبل؟ (مهم خاصةً في `CandleCache` و`MarketContext`.)
2. **globals:** أي `g_` تستخدمه — هل يلزم أن يكون عامًّا؟ (لا تنقل الـ
   globals الآن — فقط سجّل أيها يخصّ Core لنقلها لاحقًا.)
3. **منطق ميت:** متغيّرات تُحسَب ولا تُستخدم، شروط لا تتحقّق أبدًا.
4. **أخطاء صامتة:** قيمة مهملة، حساب خاطئ لا يظهر أثره.

كل ما يُكتشَف → يُسجَّل في تقرير مرافق `R0_2_Review_Notes.md`. الإصلاح
الآمن يُطبَّق ويُوثَّق؛ غير الآمن يُؤجَّل ويُسجَّل.

---

## 5. معايير القبول

- 6 ملفات `Core/*.mqh` موجودة، كل واحد بحارس تضمين.
- `Core/FalconCore_Placeholder.mqh` محذوف.
- الملف الرئيسي يبدأ بكتلة `#include` الستّة بترتيب التبعية.
- الكود المنقول مُزال من الملف الرئيسي (لا تكرار — مرة واحدة فقط، في `.mqh`).
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17` و
  `FinalWorkingNetUSD = 1104.89` بالضبط.
- تقرير `R0_2_Review_Notes.md` موجود — حتى لو لم يُكتشَف شيء (يُكتب "لا
  ملاحظات").

---

## 6. ما يجب ألا يحدث

- لا تغيير سلوك. Summary يجب أن يطابق.
- لا نقل أي شيء خارج طبقة Core.
- لا نقل globals (تُؤجَّل لمرحلة لاحقة).
- لا إعادة كتابة منطق — نقل حرفي فقط.
- لا حذف أي وظيفة.

---

## 7. بعد R0.2

عند نجاح الترجمة + تطابق Summary → commit:
```
git add -A
git commit -m "R0.2 - migrate Core layer (Logger, MarketContext, CandleCache, Constants, Enums, Structs)"
```
ثم R0.3 (نقل Evidence + Risk).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_2_SPEC.md` بالكامل ونفّذه: نقل طبقة Core (Constants,
> Enums, DataStructures, Logger, MarketContext, CandleCache) من
> `JA_FalconCore_Automated_Trading_Platform.mq5` إلى ملفات `Core/*.mqh`،
> مع حارس تضمين لكل ملف، وكتلة `#include` بترتيب التبعية في الملف الرئيسي.
> النقل حرفي — لا إعادة كتابة، لا تغيير سلوك. طبّق بروتوكول "راجع وأصلح
> أثناء النقل" (قسم 4) واكتب ملاحظاتك في `R0_2_Review_Notes.md`. لا تنقل
> globals ولا أي شيء خارج Core. بعد الانتهاء شغّل git diff --stat وأكّد أن
> الكود نُقل (أُزيل من الرئيسي، أُضيف في .mqh) ولم يُكرَّر. اعرض لي ملخص
> النقل + ملاحظات المراجعة.
