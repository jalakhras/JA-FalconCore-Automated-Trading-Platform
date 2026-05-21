# JA FalconCore — R0.6b
## إعادة الهيكلة — مفاتيح إطفاء التقارير التشخيصية
### مواصفات للتسليم إلى Claude Code

> **الهدف:** جعل التقارير التشخيصية قابلة للتشغيل/الإطفاء، ومطفأة
> افتراضيًّا. النواة الدائمة: `TradeLifecycle` + `Summary` فقط.
> **الأساس:** فرع `refactor`، آخر commit `6c0e3f8` (R0.6a).

---

## 0. لماذا R0.6b — وكيف تختلف

R0.6a نقلت ReportWriter بنيويًّا (صفر تغيير سلوك، كل التقارير تعمل).
R0.6b **تغيّر السلوك عمدًا**: التقارير التشخيصية تتوقّف افتراضيًّا.

هذا أول تغيير سلوك مقصود في إعادة الهيكلة. لذلك معيار القبول مختلف:
- النواة (`TradeLifecycle` + `Summary`) → تبقى مطابقة بايت-ببايت.
- التشخيصية (~30) → تتوقّف افتراضيًّا. **هذا هو النجاح.**
- تشغيل أي مفتاح يدويًّا → يعيد تقريره للعمل.

---

## 1. مبدأ التصميم — مزيج ProfileMaster + مفاتيح المجموعات

`ReportProfile` (enum: MINIMAL/STANDARD/DEBUG/LOCKPARITY) موجود أصلًا
ويتحكّم بأيّ التقارير تُنتَج. R0.6b يبني عليه، لا يستبدله:

1. **النواة** (`TradeLifecycle` + `Summary`) — تُنتَج **دائمًا**، مستقلّة
   عن أي profile أو مفتاح. لا يمكن إطفاؤها.
2. **مفاتيح المجموعات** — `input bool` لكل مجموعة تقارير، **مطفأة
   افتراضيًّا** (`= false`). التقرير التشخيصي يُنتَج فقط إذا كان مفتاح
   مجموعته `true`.
3. **`ReportProfile`** — يبقى كتحكّم عام (للتوافق ولوضع DEBUG الشامل).

---

## 2. مفاتيح المجموعات الجديدة

أضِف في مجموعة inputs `"04 - Reporting"` (أو مجموعة فرعية جديدة
`"04a - Diagnostic Reports"`):

```cpp
input bool EnableBrokerReports         = false; // 5 تقارير البروكر
input bool EnableLockParityReports     = false; // LockParity Decomposition + Rollup
input bool EnableVirtualTrailingReport = false; // VirtualTrailingExitLifecycle
input bool EnableTierEmergencyReports  = false; // TierTransitions + EmergencyTriggers + PaperStateSnapshot
input bool EnableStrategyRegistryReport= false; // StrategyRegistryDiagnostics
input bool EnableDebugDiagnostics      = false; // 17 تقرير DEBUG-only + AutoPeriodManifest
```

الأسماء والتجميع إرشادية — Claude Code يطابقها مع التقارير الفعلية في
`Reporting/`. المبدأ الثابت: **كل تشخيصي خلف مفتاح، كل المفاتيح
`= false` افتراضيًّا.**

---

## 3. آلية التطبيق

لكل تقرير تشخيصي، نقطة الكتابة (إنشاء الـ CSV + كتابة الصفوف) تُغلَّف
بشرط مفتاح مجموعته:

```cpp
if(EnableBrokerReports)
{
   // ... كتابة تقارير البروكر كما هي ...
}
```

- **لا حذف** لأي كود تقرير — فقط تغليفه بشرط.
- **لا تعديل** لمنطق التقرير نفسه — فقط بوّابة تشغيل/إطفاء.
- النواة (`TradeLifecycle` + `Summary`) → بلا أي شرط، تُنتَج دائمًا.

> تنبيه: إن كان تقرير تشخيصي يُحسَب جزؤه داخل سلسلة الـ `Apply*` أو الـ
> Lock Parity Decomposer — **لا تلمس منطق الحساب**. أطفئ فقط *كتابة الملف*.
> الحساب الداخلي يبقى (قد تحتاجه النواة). نطفئ الإخراج، لا الحساب.

---

## 4. الوضع الافتراضي بعد R0.6b

- `ReportProfile` الافتراضي → اضبطه على أضيق وضع نواة (MINIMAL أو ما
  يكافئه)، بحيث الافتراضي = `TradeLifecycle` + `Summary` فقط.
- كل مفاتيح المجموعات → `false`.
- النتيجة: تشغيل افتراضي ينتج **ملفّي CSV فقط**.

---

## 5. بروتوكول المراجعة

عند التطبيق، افحص وسجّل:
1. **النواة محمية:** تأكّد أن `TradeLifecycle` + `Summary` لا يمكن أن
   يُطفآ بأي تركيبة مفاتيح.
2. **لا منطق حساب أُطفئ:** تأكّد أن الإطفاء يخصّ *كتابة الملفات* فقط، لا
   حسابات `Apply*` أو Lock Parity أو الـ totals.
3. **تشابك:** إن كان جسر البروكر يعتمد على وجود ملف تقرير معيّن — سجّله.
4. أي تقرير لم يندرج تحت مجموعة واضحة — سجّله للنقاش.

كل ذلك → `Docs/ReviewNotes/R0_6b_Review_Notes.md`.

---

## 6. معايير القبول

- مفاتيح المجموعات الستّة مضافة، كلّها `= false` افتراضيًّا.
- كل تقرير تشخيصي مُغلَّف بشرط مفتاح مجموعته.
- النواة (`TradeLifecycle` + `Summary`) تُنتَج دائمًا، بلا شرط.
- يُترجَم: `0 errors, 0 warnings`.
- **تشغيل افتراضي** (كل المفاتيح false): FixedLot April يعطي
  `RawNetUSD = 585.17`، `FinalWorkingNetUSD = 1104.89`، بروكر 157.49 —
  والمخرجات = `TradeLifecycle.csv` + `Summary.csv` فقط، لا غير.
- **اختبار تشغيل مفتاح:** عند ضبط `EnableLockParityReports = true` وإعادة
  التشغيل → ملفّا LockParity يظهران، والأرقام تبقى مطابقة.
- `Docs/ReviewNotes/R0_6b_Review_Notes.md` موجود.

---

## 7. ما يجب ألا يحدث

- لا حذف أي كود تقرير — فقط تغليفه بشرط.
- لا تعديل منطق أي تقرير، ولا منطق `Apply*` / Lock Parity / totals.
- لا إمكان لإطفاء النواة.
- لا لمس الـ 12 `Apply*`.
- لا نقل globals.

---

## 8. بعد R0.6b

عند نجاح القبول → **commit واحد**:
```
git add -A
git commit -m "R0.6b - diagnostic reports on/off switches, core-only by default"
```
ثم R0.7 (فصل الـ 12 `Apply*` من ReportWriter — التصحيح المعماري).

---

## مُلحَق — Prompt لبدء العمل في Claude Code

> فعّل وضع accept edits / auto mode أولًا.
> اقرأ `JA_FalconCore_R0_6b_SPEC.md` ونفّذه: أضِف 6 مفاتيح `input bool`
> لمجموعات التقارير التشخيصية (Broker، LockParity، VirtualTrailing،
> TierEmergency، StrategyRegistry، DebugDiagnostics)، كلّها `= false`
> افتراضيًّا. غلّف نقطة كتابة كل تقرير تشخيصي بشرط مفتاح مجموعته. النواة
> `TradeLifecycle` + `Summary` تبقى بلا شرط — تُنتَج دائمًا. **لا تحذف أي
> كود تقرير، لا تعدّل منطق أي تقرير، ولا تلمس حسابات Apply* أو Lock Parity
> — أطفئ كتابة الملفات فقط لا الحسابات.** اضبط ReportProfile الافتراضي على
> أضيق وضع نواة. لا تلمس الـ 12 `Apply*`. طبّق بروتوكول المراجعة واكتب
> `Docs/ReviewNotes/R0_6b_Review_Notes.md`. اجعل R0.6b في commit واحد. بعد
> الانتهاء أكّد git diff --stat واعرض الملخص.
