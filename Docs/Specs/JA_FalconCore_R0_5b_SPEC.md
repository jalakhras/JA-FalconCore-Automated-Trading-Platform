# JA FalconCore — R0.5b
## إعادة الهيكلة — تنظيم هيكلية المشروع
### مواصفات للتسليم إلى Claude Code

> **الهدف:** تنظيم جذر المشروع — نقل الوثائق إلى مجلد `Docs/`، إعادة تسمية
> مجلدين، أرشفة مجلدين. **لا لمس أي كود.**
> **الأساس:** فرع `refactor`، بعد R0.5 + R0.5-fix.

---

## 0. لماذا R0.5b — ولماذا مرحلة منفصلة

بعد خمس مراحل نقل، جذر المشروع متناثر: ملفات وثائق، ملفات مراجعة، مجلدات
أرشيفية، أسماء مجلدات غير واضحة. R0.5b ترتّبه.

**مرحلة منفصلة عمدًا** — لا تُخلَط مع نقل كود. R0.5b تحرّك **وثائق فقط**.
لا تلمس: الملف `.mq5`، مجلدات الكود الثمانية، أي `#include`، رابط الـ
symbolic link. الكود يبقى ثابتًا تمامًا — فالترجمة لا يمكن أن تنكسر.

---

## 1. القيد الأهم — لا لمس الكود

- **لا تعديل** على `JA_FalconCore_Automated_Trading_Platform.mq5`.
- **لا تحريك** لمجلدات الكود الثمانية: `Core/`, `Evidence/`, `Risk/`,
  `TradeManagement/`, `Execution/`, `Router/`, `Strategies/`, `Reporting/`.
- **لا تعديل** أي سطر `#include`.
- **لا لمس** الـ `.ex5` ولا `.vscode`.
- R0.5b عملية `git mv` و`mkdir` للوثائق فقط.

> إن كان أي ملف يُنقَل مرجوعًا إليه من داخل الكود (مستبعد للوثائق) — لا
> يُنقَل. الوثائق المستهدفة هنا ليست مُضمَّنة في الكود.

---

## 2. الهيكل المستهدف

```
الجذر (يبقى كما هو):
  JA_FalconCore_Automated_Trading_Platform.mq5
  JA_FalconCore_Automated_Trading_Platform.ex5
  README.md
  .vscode/
  Core/  Evidence/  Risk/  TradeManagement/
  Execution/  Router/  Strategies/  Reporting/

Docs/                          ← جديد
  ├── ReviewNotes/             ← سجلّ دائم
  │     R0_2_Review_Notes.md
  │     R0_3_Review_Notes.md
  │     R0_4_Review_Notes.md
  │     R0_5_Review_Notes.md
  ├── Specs/                   ← مواصفة المرحلة الجارية فقط
  │     JA_FalconCore_R0_5_SPEC.md   (تُحذف عند بدء R0.6؛ تبقى الآن)
  ├── ProjectMemory/           ← مجلد "ذاكره المشروع" بعد النقل وإعادة التسمية
  │     (محتوياته كما هي)
  ├── Archive/                 ← أرشيف، لا يُحذف
  │     analysis/              (المجلد كاملًا)
  │     saved_patches/         (المجلد كاملًا)
  └── (مباشرة في Docs/):
        JA_FalconCore_Master_Build_Plan_v0_0_0.docx
        FalconCore_Feature_Inventory_v0_57_4.md
        falconcore_ea_operational_rules.md
        JA_FalconCore_Refactor_Plan_v0_57_4.md   (إن كان موجودًا في الجذر)

StrategyDocs/                  ← مجلد "Pro strategies" بعد إعادة التسمية
  (محتوياته كما هي)
```

---

## 3. الخطوات

استخدم `git mv` (لا `mv` العادي) — حتى يتتبّع git النقل كإعادة تسمية لا
حذف+إضافة.

### 3.1 إنشاء مجلد Docs وفروعه
```
mkdir Docs Docs\ReviewNotes Docs\Specs Docs\Archive
```

### 3.2 نقل ملفات المراجعة (سجلّ دائم)
```
git mv R0_2_Review_Notes.md Docs/ReviewNotes/
git mv R0_3_Review_Notes.md Docs/ReviewNotes/
git mv R0_4_Review_Notes.md Docs/ReviewNotes/
git mv R0_5_Review_Notes.md Docs/ReviewNotes/
```
(إن وُجد أيٌّ منها بمسار مختلف، عدّل تبعًا.)

### 3.3 نقل مواصفة المرحلة الجارية
```
git mv JA_FalconCore_R0_5_SPEC.md Docs/Specs/
```
(أي ملفات `_SPEC` أخرى من مراحل مكتملة: تُحذف، لا تُنقَل — القاعدة: SPEC
المرحلة المكتملة يُحذف.)

### 3.4 نقل وثائق المرجع إلى Docs/ مباشرة
```
git mv JA_FalconCore_Master_Build_Plan_v0_0_0.docx Docs/
git mv FalconCore_Feature_Inventory_v0_57_4.md Docs/
git mv falconcore_ea_operational_rules.md Docs/
```
(و`JA_FalconCore_Refactor_Plan_v0_57_4.md` إن كان في الجذر.)

### 3.5 نقل وإعادة تسمية مجلد ذاكرة المشروع
```
git mv "ذاكره المشروع" Docs/ProjectMemory
```

### 3.6 أرشفة المجلدات القديمة
```
git mv analysis Docs/Archive/analysis
git mv saved_patches Docs/Archive/saved_patches
```

### 3.7 إعادة تسمية مجلد شرح الاستراتيجيات
```
git mv "Pro strategies" StrategyDocs
```

---

## 4. ما يبقى في الجذر — تأكيد

بعد R0.5b، جذر المشروع يحوي **فقط**:
- الملف `.mq5` + `.ex5`
- `README.md`
- `.vscode/`
- 8 مجلدات كود
- `Docs/`
- `StrategyDocs/`

لا ملفات وثائق متناثرة في الجذر.

---

## 5. معايير القبول

- `Docs/` موجود بفروعه الأربعة + الوثائق المرجعية.
- `StrategyDocs/` موجود (كان `Pro strategies`).
- `Docs/ProjectMemory/` موجود (كان `ذاكره المشروع`).
- `analysis/` و`saved_patches/` داخل `Docs/Archive/`.
- الجذر نظيف — لا ملف وثائق خارج `Docs/`.
- **الكود لم يُمَسّ:** `git diff` على `.mq5` وكل مجلدات الكود = فارغ.
- يُترجَم: `0 errors, 0 warnings` (تأكيد أن لا شيء انكسر).
- تشغيل FixedLot April يعطي 585.17 / 1104.89 + بروكر 157.49 (تأكيد نهائي).

---

## 6. ما يجب ألا يحدث

- لا تعديل أي كود أو `#include`.
- لا تحريك مجلدات الكود الثمانية.
- لا حذف أي ملف عدا ملفات `_SPEC` لمراحل مكتملة.
- لا استخدام `mv` العادي — فقط `git mv`.

---

## 7. بعد R0.5b

عند نجاح الترجمة + تطابق Summary → **commit واحد**:
```
git add -A
git commit -m "R0.5b - reorganize project root: Docs/ structure, rename folders, archive"
```
ثم R0.6 (تفكيك `CFalconReportWriter`).

> من R0.6 فصاعدًا: كل `R0_X_Review_Notes.md` يُكتَب مباشرةً في
> `Docs/ReviewNotes/`، وكل `_SPEC` في `Docs/Specs/`.

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_5b_SPEC.md` ونفّذه: تنظيم جذر المشروع — أنشئ
> مجلد `Docs/` بفروعه (ReviewNotes, Specs, Archive)، وانقل إليه ملفات
> المراجعة ووثائق المرجع باستخدام `git mv`، وأعد تسمية "ذاكره المشروع" إلى
> `Docs/ProjectMemory` و"Pro strategies" إلى `StrategyDocs`، وانقل
> `analysis` و`saved_patches` إلى `Docs/Archive/`. **لا تلمس أي كود** —
> لا الملف `.mq5`، لا مجلدات الكود الثمانية، لا أي `#include`. استخدم
> `git mv` فقط. بعد الانتهاء أكّد أن `git diff` على الكود فارغ، واعرض
> هيكل الجذر الجديد.
