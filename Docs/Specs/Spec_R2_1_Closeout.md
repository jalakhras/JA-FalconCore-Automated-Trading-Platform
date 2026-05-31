# مواصفة إغلاق R2.1

> **النوع:** إغلاق مرحلة — commit واحد + تحديث وثائق.
> **الإصدار:** R2.1 / FvgMicroSpecAligned (هذا commit الإغلاق).
> **يسبقه:** R1.7 closeout + `Spec_R2_1_FvgMicroComplete.md` + 4 تشغيلاتٍ تحقّقيّة.

---

## ١. الهدف

إغلاق R2.1 بـ commit واحد على فرع `refactor` يحوي:
- التغييرات السبعة (FvgMicroRetest spec-aligned).
- اكتشاف Q3 retest confirmation اللاحق (الخيار الثالث — حساب محليّ
  داخل Watcher بدون تعديل snapshot).

مع تحديثٍ كاملٍ لـ Review Notes والذاكرة وقائمة Problems، وتسجيل
**الـ baseline الإنتاجيّ المرجعيّ الجديد** (Test A: 614.45 على أبريل).

---

## ٢. السياق — ما أُنجز

| التشغيل | النافذة | الإعداد | Final Balance | Broker Actual |
|---|---|---|---:|---:|
| Smoke Shadow | 04-01→04-03 | FvgMicro only | 253.17 | 53.17 |
| April Shadow | 04-01→04-30 | FvgMicro only (≡ Test C) | 263.66 | 63.66 |
| Test A | 04-01→04-30 | S01 + FvgMicro + TM/Prot ON | **614.45** | 417.37 |
| Test B | 04-01→04-30 | S01 + TM/Prot ON (≡ R1.7 SanityON) | 482.64 | 275.97 |
| Test C | 04-01→04-30 | FvgMicro only | 263.66 | 63.66 |

**الاكتشافات الرئيسة:**
- التراجع المُتوهَّم (528.59 → 263.66) كان «مقارنة برتقال بتفّاح». R2.1
  الحاليّ على إعدادات pre-R1.7 = **614.45** (أعلى بـ 86 دولارًا).
- B الحاليّ يطابق 482.64 تاريخيًّا — نقطة لمسٍ مرجعيّة.
- **التركيب يضيف قيمة:** A − (B+C) = +77.74. Protection/Runner يتدخّل
  515/225 مرّة في A. شرح §١٦ صحيحٌ ميكانيكيًّا.
- شاشة Tester ≈ EA report ضمن عمولة/سواب.

---

## ٣. القيود الصارمة

- **لا تغيير كود في هذا الـ commit.** التغييرات في الـ working copy (R2.1)
  هي ما يُلتزَم.
- **commit واحد فقط.**
- **لا تنظيف، لا تحسينات، لا إعادة تنسيق.** أيّ فكرة → Backlog.
- بعد commit: لا تشغيلات إضافيّة في هذه المرحلة.

---

## ٤. التحديثات المطلوبة قبل الـ commit

### أ. Review Notes — `Docs/ReviewNotes/R2_1_Review_Notes.md` (جديد)

- ملخّص التنفيذ: 7 تعديلات spec-aligned + Q3 fix داخل Watcher.
- ملخّص التشغيلات الـ 5 (الجدول أعلاه).
- تأكيد invariants: ProtectionActivated=0 و Runner=0 في Test C (الحارس
  يعمل)، شاشة Tester ≈ EA report.
- **الـ baseline الإنتاجيّ المرجعيّ الجديد** (Test A، أبريل).
- درس مُسجَّل: «حدسٌ بتراجع يستحقّ تحقّقًا قبل أيّ إصلاح. التحقّق =
  3 تشغيلاتٍ بإعداداتٍ متطابقة، ليس نقاشًا نظريًّا.»

### ب. Problems — لا تغيير في هذا الـ commit

الـ defects #2 (BrokerModifySent counter)، #3 (ReportIntegrityStatus false
positive)، #5 (TP2 column) تبقى مفتوحة كما هي. غير حاجبة لـ R2.2.

### ج. Ideas Backlog — يُضاف

- **معايرة العتبات الأربعة** (`MIN_SIZE_POINTS=30`، `MAX_SPREAD_TO_FVG_RATIO=0.50`،
  `MAX_FVG_AGE_BARS=12`، `FvgMicroSlBufferPoints=30`) — تُعاد بعد بيانات
  R2.2 (3 أشهر). أيّ معايرة قبل ذلك = data mining.
- **R2.2-StrategyOnly** (FvgMicroRetest وحدها على 3 أشهر) — مُؤجَّل. سؤالٌ
  علميٌّ مفيد لكن ليس على المسار الإنتاجيّ. يُنفَّذ إن احتاج تشخيصٌ لاحق.
- **Protection/Runner على البروكر** = R3.x (مظروف الطوارئ يبقى حتى ذلك).
- **`FalconStrategySignal` refactor** — لاتّساق معماريّ، غير حاجب.
- **ازدواج مسار الدخول** OnInit/OnTick — مراجعة `g_last_staged_fvg_candidate_id`.

### د. ملفّ ذاكرة المشروع — إصدار جديد `R2_1_closed`

- **§٢:** يُضاف فقرة عن إغلاق R2.1 (التنفيذ + التحقّق + الاكتشاف عن
  التركيب).
- **§٣ (الحالة):** آخر commit مستقرّ = R2.1. الفرع `refactor`. الخطوة
  التالية = R2.3 (بوّابة الحافة) ثمّ R2.2 (تشغيل 3 أشهر).
- **§٤:** R2.1 ⇒ **✓ مُغلقة**.
- **§٥ (المعارف):** يُضاف:
  > **#11 — حدسٌ بالتراجع يستحقّ تحقّقًا.** ليس نقاشًا. التحقّق
  > = 3 تشغيلاتٍ بإعداداتٍ متطابقة على نفس النافذة. مقارنة الإعدادات
  > السابقة بالحاليّة دون توحيد الإعدادات = برتقال بتفّاح.

  > **#12 — التركيب يضيف قيمة.** Trade Management (Apply #5/#6) يفعّل
  > 515/225 مرّة في الإعداد الكامل (Test A) مقابل 0 في FvgMicroRetest
  > وحدها (Test C). الفائض +77.74 USD. الإدارة ليست زخرفًا.
- **§٦ (الأرقام المرجعيّة):**

  > **الـ baseline الإنتاجيّ المرجعيّ على R2.1 (April 2026, US100_Spot M5):**
  >
  > | المقياس | Test A (الكامل) |
  > |---|---:|
  > | TotalTrades | 1168 |
  > | RawNetUSD | 1194.23 |
  > | FinalWorkingNetUSD | 1264.42 |
  > | **BrokerActualNetUSD** | **417.37** |
  > | Tester Net Profit | 414.45 |
  > | Final Balance (200 ابتدائيّ) | **614.45** |
  > | ProtectionActivated | 515 |
  > | RunnerActivated | 225 |
  > | WinRate | 50.00% |
  > | Balance DD Absolute | 5.03 |
  > | Equity DD Absolute | 6.25 |
  >
  > **الـ baseline العاري لـ FvgMicroRetest وحدها (Test C، نفس النافذة):**
  > 558 صفقة، Broker 63.66، Final Balance 263.66، WR 63.44%،
  > Equity DD 97.51 (كبير — بدون TM).
  >
  > رقم 42.60 يبقى متقاعدًا. R1.7 baseline (610/648.71/-2.43/275.97)
  > يُحفظ كمرجعٍ لـ R1.7 نفسها لا لـ R2.1.
- **§٧ (Problems):** بلا تغيير.

---

## ٥. الـ commit

- الفرع: `refactor`.
- المحتوى: تغييرات R2.1 الحاليّة في الـ working copy.
- النصّ:

  ```
  R2.1 — إكمال FvgMicroRetest وفق شرح الاستراتيجيّة

  - مرتكز TP: حدّ FVG → midpoint (الدخول).
  - Invalidation guard: إغلاق متجاوز يبطل المنطقة.
  - Spread guard: نسبيّ (spread/zoneSize ≤ 0.50).
  - SL buffer: قابل للضبط عبر FvgMicroSlBufferPoints (افتراضي 30).
  - Age guard: فعّال (max 12 bars على M5).
  - Retest confirmation: بوّابة اختياريّة، حساب محليّ داخل Watcher
    بدون تعديل snapshot.
  - Min size: 1.00 → 30.0 (placeholder للمعايرة بعد R2.2).

  Test A (الإعداد الكامل، أبريل): 614.45 (تحسّن 86 USD عن
  pre-R1.7 التاريخيّ). Test B يطابق R1.7 SanityON بالضبط.
  Test C (FvgMicro وحدها): 263.66.

  معارف مُسجَّلة: #11 (التحقّق قبل التشخيص) + #12 (التركيب يضيف قيمة).

  EA_VERSION_TAG: R1_7 → R2_1
  Build: GateLeakFix → FvgMicroSpecAligned
  ```

---

## ٦. معايير القبول

- `git log -1 --oneline` على `refactor` يُظهر سطر R2.1.
- `Docs/ReviewNotes/R2_1_Review_Notes.md` موجود ومُكتمل.
- Ideas Backlog محدّث بـ 5 بنود.
- ملفّ الذاكرة `R2_1_closed` موجود.
- لا تغيير كود غير ما هو سلفًا في الـ working copy.
- لا commit ثانٍ.

---

## ٧. بروتوكول الإغلاق

- **Problems:** بلا تغيير. الـ defects المتبقّية غير حاجبة.
- **تسجيل الأفكار:** §٤-ج.
- **ملفّ المراجعة:** `R2_1_Review_Notes.md` (جديد).
- **حفظ الـ .set ملفّات:** `R2_1_TestA_PreR17_Reproduce.set` (الـ baseline
  الإنتاجيّ)، `R2_1_TestC_FvgMicroOnly_Baseline.set` (الـ baseline العلميّ)،
  `R2_1_TestB_R17_SanityON_Reproduce.set` (نقطة لمسٍ مرجعيّة) — كلّها
  تُحفظ في `Docs/SetFiles/R2_1/`.

---

## ٨. ملحق — Prompt لـ Claude Code

```
السياق: نحن على فرع `refactor`، آخر commit R1.7 closeout. الـ working
copy يحوي تغييرات R2.1 + Q3 retest confirmation fix داخل Watcher
(مُحقّقة بنجاح في 5 تشغيلاتٍ تحقّقيّة). نريد إغلاق R2.1 الآن بـ commit
واحد + تحديثات وثائق.

التعليمات بهذا الترتيب الحرفيّ:

١. اقرأ كاملًا الملفّ المرفق `Spec_R2_1_Closeout.md`. هو المرجع
   الوحيد. كلّ ما يلي تعليمات تشغيليّة لا بديلة.

٢. التزم بـ §٣ القيود (لا تغيير كود، commit واحد، لا تنظيف، لا تشغيلات).

٣. لا تلمس أيّ ملفّ .mq5/.mqh. تغييرات R2.1 تبقى كما هي.

٤. أنشئ `Docs/ReviewNotes/R2_1_Review_Notes.md` وفق §٤-أ.

٥. أنشئ مجلّد `Docs/SetFiles/R2_1/` وانقل إليه الثلاثة .set ملفّات
   المُرفقة (TestA, TestB, TestC). إن كانت موجودة في موقعٍ آخر، انسخها.

٦. أضف إلى Ideas Backlog البنود الخمسة في §٤-ج.

٧. أنشئ نسخة جديدة من ملفّ ذاكرة المشروع باسم
   `JA_FalconCore_Project_Memory_R2_1_closed.md` بالتحديثات في §٤-د.

٨. نفّذ `git add` لـ:
   - تغييرات الكود في الـ working copy
   - Docs/ReviewNotes/R2_1_Review_Notes.md
   - Docs/SetFiles/R2_1/*.set
   - JA_FalconCore_Project_Memory_R2_1_closed.md
   - أيّ ملفّ Backlog/Problems تحدّث

٩. نفّذ commit واحدًا على `refactor` بالنصّ الكامل من §٥ (انسخه كما هو).

١٠. توقّف. أظهر: git status، git log -1 --oneline، git diff HEAD~1 --stat.

ممنوع: أيّ تغيير كود، أيّ commit ثانٍ، أيّ تنظيف، أيّ بناء، أيّ تشغيل،
أيّ rebase/reset. ما لم يُذكر هنا — لا تفعله.

عند أيّ تعارض: المواصفة تحكم. عند أيّ غموض: اسأل قبل التصرّف.
```
