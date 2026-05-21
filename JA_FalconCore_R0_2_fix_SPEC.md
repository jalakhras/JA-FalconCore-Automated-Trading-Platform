# JA FalconCore — R0.2-fix
## إصلاح ترتيب inputs الـ Core + الترويسة
### مواصفات للتسليم إلى Claude Code

> **الهدف:** إصلاح 6 أخطاء ترجمة ظهرت بعد R0.2 + تصحيح ترويسة الملف
> و`#property version`.
> **الأساس:** فرع `refactor`، بعد تطبيق R0.2 (غير مُجمَّع بنجاح بعد).

---

## 0. المشكلة

بعد نقل طبقة Core في R0.2، ظهرت 6 أخطاء ترجمة:
```
undeclared identifier 'PrimaryContextTimeframe'  — FalconMarketContext.mqh
undeclared identifier 'UseClosedCandlesOnly'     — FalconMarketContext.mqh, FalconCandleCache.mqh
```

**السبب:** ملفات `Core/*.mqh` تُضمَّن في أعلى الملف الرئيسي — قبل كتلة
`input`. الكود المنقول إلى `FalconMarketContext.mqh` و`FalconCandleCache.mqh`
يستخدم متغيّرات `input` (مثل `PrimaryContextTimeframe`, `UseClosedCandlesOnly`)
لم تُعرَّف بعد عند نقطة التضمين.

هذه مشكلة **ترتيب**، لا منطق. الكود المنقول سليم.

---

## 1. الحل — نقل inputs الـ Core إلى ملف Core

### 1.1 إنشاء `Core/FalconCoreInputs.mqh`

أنشئ ملفًا جديدًا `Core/FalconCoreInputs.mqh` بحارس تضمين.

انقل إليه — من الملف الرئيسي — **كل `input` تستخدمه طبقة Core فقط**:
- `PrimaryContextTimeframe`
- `UseClosedCandlesOnly`
- أي `input` آخر تستخدمه `MarketContext` أو `CandleCache` أو `Logger`
  (افحص الملفين المنقولين واستخرج كل المعرّفات غير المعرَّفة).

> مهم: انقل **فقط** الـ inputs التي تخصّ Core. أي input تستخدمه طبقات أخرى
> (Risk, Strategy, Reporting...) يبقى في الملف الرئيسي — يُنقَل مع طبقته
> لاحقًا.
> إن كان input واحد مشتركًا بين Core وطبقة أخرى، انقله إلى
> `FalconCoreInputs.mqh` (لأن Core تُضمَّن أولًا) — والطبقات اللاحقة ستجده.

### 1.2 ترتيب الـ `#include`

`Core/FalconCoreInputs.mqh` يجب أن يُضمَّن **قبل** `FalconMarketContext.mqh`
و`FalconCandleCache.mqh`. الترتيب المقترح في الملف الرئيسي:
```cpp
#include "Core/FalconConstants.mqh"
#include "Core/FalconEnums.mqh"
#include "Core/FalconCoreInputs.mqh"     // ← جديد، قبل الكلاسات
#include "Core/FalconDataStructures.mqh"
#include "Core/FalconLogger.mqh"
#include "Core/FalconMarketContext.mqh"
#include "Core/FalconCandleCache.mqh"
```

> ملاحظة MQL5: `input` يجب أن تبقى في النطاق العام (global scope). وضعها
> في ملف `.mqh` مُضمَّن في النطاق العام سليم — MQL5 يقبل هذا.

---

## 2. تصحيح الترويسة و`#property version`

في الملف الرئيسي `JA_FalconCore_Automated_Trading_Platform.mq5`:

استبدل سطر الترويسة القديم:
```
//|                     Version: v0.56.9b - Emergency Server Stop Envelope LOCK Parity Probe CANDIDATE |
```
بـ:
```
//|                     Version: v0.57.4 - Refactor Branch (R0.2) |
```

واضبط:
```cpp
#property version   "0.57.4"
```

> هذا تصحيح يحدث **مرة واحدة** — يعكس أن الفرع هو refactor فوق v0.57.4.
> لا يتغيّر مع كل مرحلة R0.x لاحقة.

---

## 3. القيود

- صفر تغيير سلوك. نقل inputs لا يغيّر قيمها ولا منطقها.
- لا تعديل منطق أي كلاس.
- لا نقل أي شيء خارج نطاق Core inputs + الترويسة.

---

## 4. معايير القبول

- `Core/FalconCoreInputs.mqh` موجود، فيه inputs الـ Core، بحارس تضمين.
- الـ inputs المنقولة مُزالة من الملف الرئيسي (لا تكرار).
- ترتيب الـ `#include` صحيح (CoreInputs قبل الكلاسات).
- الترويسة و`#property version` تقولان `v0.57.4`.
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي `RawNetUSD = 585.17` و
  `FinalWorkingNetUSD = 1104.89` بالضبط.

---

## 5. ما يجب ألا يحدث

- لا نقل inputs لا تخصّ Core.
- لا تغيير قيمة أي input.
- لا تغيير سلوك. Summary يجب أن يطابق.
- لا تعديل منطق.

---

## 6. بعد R0.2-fix

عند نجاح الترجمة + تطابق Summary → commit:
```
git add -A
git commit -m "R0.2-fix - Core inputs file + include order + header/version correction"
```
ثم R0.3 (نقل Evidence + Risk).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_2_fix_SPEC.md` ونفّذه: أنشئ `Core/FalconCoreInputs.mqh`
> وانقل إليه كل input تستخدمه طبقة Core (PrimaryContextTimeframe،
> UseClosedCandlesOnly، وأي معرّف غير معرَّف في FalconMarketContext.mqh /
> FalconCandleCache.mqh)، رتّب الـ #include بحيث CoreInputs قبل الكلاسات،
> وصحّح ترويسة الملف الرئيسي و #property version إلى v0.57.4. لا تنقل inputs
> لا تخصّ Core. لا تغيّر أي قيمة أو منطق. بعد الانتهاء أكّد git diff --stat.
> اعرض لي ملخص التغيير.
