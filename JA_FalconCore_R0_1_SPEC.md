# JA FalconCore — R0.1
## إعادة الهيكلة — المرحلة الأولى: الهيكل والفرع
### مواصفات للتسليم إلى Claude Code

> **الهدف:** إنشاء فرع `refactor` + هيكل مجلدات `.mqh` فارغ + التأكد أن
> المشروع ما زال يُترجَم. **لا نقل منطق إطلاقًا في هذه المرحلة.**
> **الأساس:** فرع `dev`، آخر commit `5a7e961` (v0.57.4)، شجرة نظيفة.

---

## 0. لماذا R0.1

هذه أول مرحلة في خطة إعادة الهيكلة (راجع
`JA_FalconCore_Refactor_Plan_v0_57_4.md`). مرحلة تأسيسية بحتة:
- لا تنقل كودًا.
- لا تغيّر سلوكًا.
- هدفها الوحيد: إثبات أن الفرع الجديد والهيكل الجديد يُترجَمان قبل أي نقل.

إن نجحت R0.1 (الملف يُترجَم، Summary يطابق)، يصبح لدينا أرضية آمنة لكل
المراحل التالية.

---

## 1. القيود الصارمة

- **لا نقل أي كود.** الملف `JA_FalconCore_Automated_Trading_Platform.mq5`
  يبقى كما هو حرفيًا في نهاية R0.1 — صفر تغيير في محتواه.
- لا تعديل أي منطق، أي input، أي دالة.
- العمل كله: إنشاء فرع + إنشاء مجلدات + إنشاء ملفات `.mqh` فارغة (placeholder).
- لا `OrderSend`، لا تعديل تنفيذ.

---

## 2. الخطوات

### 2.1 إنشاء فرع إعادة الهيكلة

```
git checkout dev
git branch refactor
git checkout refactor
```

كل عمل إعادة الهيكلة من الآن على فرع `refactor`. فرع `dev` يبقى نقطة رجوع
سليمة عند v0.57.4.

### 2.2 إنشاء هيكل المجلدات

داخل مجلد المشروع، أنشئ هذه المجلدات (فارغة حاليًا):

```
Core/
Evidence/
Risk/
TradeManagement/
Execution/
Router/
Strategies/
Strategies/S00_ScalpFvgMicro/
Reporting/
Reporting/core/
Reporting/diagnostic/
```

### 2.3 إنشاء ملفات placeholder

في كل مجلد، أنشئ ملف `.mqh` واحدًا فارغًا (placeholder)، يحوي فقط حارس
تضمين وتعليقًا. مثال لـ `Core/FalconCore_Placeholder.mqh`:

```cpp
//+------------------------------------------------------------------+
//| Core/FalconCore_Placeholder.mqh                                  |
//| R0.1 placeholder — no logic yet. Layers move here in later stages.|
//+------------------------------------------------------------------+
#ifndef FALCON_CORE_PLACEHOLDER_MQH
#define FALCON_CORE_PLACEHOLDER_MQH
// Intentionally empty. R0.2+ will populate this layer.
#endif
```

ملف placeholder واحد لكل مجلد رئيسي يكفي. الغرض إثبات أن `#include` يعمل.

### 2.4 إثبات أن `#include` يعمل — دون لمس المنطق

**لا تنقل أي كود إلى ملفات placeholder.** بدلًا من ذلك، لإثبات أن آلية
الـ include سليمة:

أضِف في أعلى `JA_FalconCore_Automated_Trading_Platform.mq5` — بعد
`#property` مباشرةً وقبل أي كود — سطر تضمين واحدًا تجريبيًا:

```cpp
#include "Core/FalconCore_Placeholder.mqh"
```

بما أن ملف الـ placeholder فارغ منطقيًا، هذا السطر **لا يغيّر أي سلوك** —
لكنه يثبت أن المترجم يجد الملفات في الهيكل الجديد.

> ملاحظة: هذا السطر الوحيد هو التغيير الوحيد المسموح في الملف الرئيسي في
> R0.1. كل شيء آخر فيه يبقى حرفيًا كما هو.

### 2.5 الترجمة

المستخدم يترجم في MetaEditor (F7). يجب أن تكون النتيجة:
`0 errors, 0 warnings`.

---

## 3. معايير القبول

- فرع `refactor` موجود، متفرّع من `5a7e961`.
- المجلدات الـ 11 موجودة، كل واحد فيه ملف placeholder.
- الملف الرئيسي فيه سطر `#include` واحد فقط جديد — لا تغيير آخر.
- يُترجَم: `0 errors, 0 warnings`.
- تشغيل FixedLot April يعطي نفس `RawNetUSD` و`FinalWorkingNetUSD`
  (585.17 / 1104.89) — لأن لا منطق تغيّر.

---

## 4. ما يجب ألا يحدث

- لا نقل كود من الملف الرئيسي إلى أي `.mqh`.
- لا تعديل أي منطق أو input أو دالة.
- لا حذف أي شيء.
- لا أكثر من سطر `#include` واحد في الملف الرئيسي.

---

## 5. بعد R0.1

عند نجاح الترجمة وتطابق Summary → commit:
```
git add -A
git commit -m "R0.1 - refactor branch + folder skeleton + include proof"
```
ثم ننتقل إلى R0.2 (نقل طبقة Core فعليًا).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_1_SPEC.md` بالكامل ونفّذه: إنشاء فرع `refactor` من
> dev، إنشاء هيكل المجلدات الـ 11، ملف placeholder فارغ في كل مجلد، وسطر
> `#include` واحد تجريبي في الملف الرئيسي. لا تنقل أي كود. لا تعدّل أي منطق
> أو input أو دالة. التغيير الوحيد المسموح في الملف الرئيسي هو سطر
> `#include` واحد. بعد الانتهاء شغّل git status و git diff --stat وأكّد أن
> الملف الرئيسي لم يتغيّر إلا بسطر واحد. اعرض لي ملخص ما أنشأته.
