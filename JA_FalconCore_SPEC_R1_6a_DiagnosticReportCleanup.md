# JA FalconCore — مواصفة المرحلة R1.6a: تنظيف التقارير التشخيصيّة المنتهية

> **نوع المستند:** مواصفة بناء — تُنفَّذ عبر Claude Code.
> **الأساس:** الشجرة الحاليّة بعد إغلاق 3a (commit محرّك الحماية).
> **مبنيّ على:** تقرير استكشاف `DeadSurfaceAudit` — الجرد المُثبَت بالكود.
> **نوع المرحلة:** تنظيف — إزالة سقالات، لا سلوك جديد.

---

## موقع هذه المرحلة في خريطة البناء

المرحلتان 1 و2 و3a اكتملت. قبل بناء الاستراتيجيّة الحقيقيّة، نُنظّف
السطح المتراكم — كي تدخل الاستراتيجيّة الجديدة بيئةً نظيفة لا فوضى.
هذه المرحلة تُنفّذ **جزءًا واحدًا فقط** ممّا حصره الجرد: التقارير
التشخيصيّة المنتهية. تنظيف المدخلات (إعادة تسمية / `#define`)
**مؤجَّل** — الجرد أثبت صفر مدخلات ميّتة، وإعادة التسمية تخاطر
بملفّات `.set` غير المرئيّة (خطر R3).

## السياق — ماذا يُنظَّف ولماذا

أثبت الجرد أن المشروع يكتب نحو 24 تقريرًا تشخيصيًّا منتهي الغرض
مقابل 6 جوهريّة. هذه التقارير خدمت تحقيقاتٍ في مراحل مُغلقة، ولم
يعد لها قارئ. تركها يضخّم المخرجات. الجرد أثبت — وهذا حاسم — أن
**لا فحص نزاهة يقرأ أيًّا منها**: `ReportIntegrityStatus` يقرأ
`TradeLifecycle` فقط، وقائمة فحص `RuntimeReportVerification` لا
تشمل أيًّا من المنتهية. فإزالتها آمنة من ناحية القرّاء.

## الهدف

إزالة كتابة التقارير التشخيصيّة المنتهية — بحذف نداءات الكتابة
لها — مع إبقاء كلّ التقارير الجوهريّة وكلّ المفاتيح وكلّ المدخلات
سليمةً. تنظيفٌ للمخرجات، لا تغييرٌ لسلوك.

## القيود الصارمة (ما يجب ألّا يحدث)

- **لا يُحذف ولا يُعاد تسمية أيّ مدخل `input`.** الجرد أثبت صفر
  مدخلات ميّتة. تنظيف المدخلات مرحلةٌ لاحقة، بعد إرسال المشغّل
  ملفّاتِ `.set`.
- **لا يُحذف أيّ مفتاح حاجز** — حتى مفاتيح المجموعة 05. تبقى
  معرّفةً (قد تظهر في `.set` محفوظ — خطر R3). يُحذف ما تحكمه من
  **كتابة**، لا المفتاح نفسه.
- **التقارير الستّة الجوهريّة لا تُمسّ:** `TradeLifecycle`،
  `Summary`، `BrokerExecutionLifecycle`، `BrokerPaperTradeReconciliation`،
  `TradeManagementCoordinatorAudit` — وكذلك
  `BrokerTradeManagementEventTimeline` (يبقى كما هو، لا يُحذف).
- **خطر R1 — الاقتران:** `EnableBrokerReports` يحكم في كتلة `if`
  واحدة 3 تقارير جوهريّة + 2 منتهيين. **لا يُحذف المفتاح، ولا
  تُمسّ الكتلة كحاجز.** يُحذف **نداءا الكتابة** للتقريرين المنتهيَين
  فقط (`BrokerRebasedPaperComparison` و`BrokerContractRealityAudit`)
  من داخل الكتلة — جراحةٌ في سطرَي النداء، لا في الـ `if`.
- **خطر R2 — التسمية:** `TradeManagement_DiagReport` رغم اسمه
  يحكم تقريرًا **جوهريًّا** (`TradeManagementCoordinatorAudit`).
  **لا يُمسّ.** بخلاف `S00_DiagReport` المنتهي. لا حذف بالاسم —
  بالوظيفة المُثبَتة في الجرد فقط.
- **لا يُمسّ `Risk/FalconRiskLifecycleProcessor.mqh`** ولا سلسلة
  الـ Apply* ولا ترتيبها.
- **لا يُمسّ منطقٌ غير تقريريّ.** حذف كتابة التقرير لا يلمس الحساب
  الذي يغذّيه. مؤكَّد بالجرد: عدّادات `m_totals.*` تواصل الحساب
  بعد إطفاء تقاريرها (خطر R5، مطمئن).
- **معيار النجاح سلوكيٌّ صفر:** بعد التنظيف، نتيجة أيّ تشغيل
  مطابقةٌ حرفيًّا لما قبله — التقارير المحذوفة فقط تختفي.

## مواصفة التغيير

تُحذف **نداءات الكتابة** للتقارير التالية (المصنّفة DIAG-EXP في
الجرد). المفاتيح الحاجزة تبقى معرّفةً.

### المجموعة أ — تقريران داخل كتلة `EnableBrokerReports` (جراحة R1)
في `Reporting/FalconReportWriter.mqh`، داخل كتلة كتابة تقارير
البروكر:
- يُحذف نداء كتابة `BrokerRebasedPaperComparison` (نحو `FRW:170`).
- يُحذف نداء كتابة `BrokerContractRealityAudit` (نحو `FRW:172`).
- **الكتلة وشرط `if(EnableBrokerReports)` يبقيان** — يواصلان حكم
  التقارير الثلاثة الجوهريّة (`BrokerExecutionLifecycle`،
  `BrokerPaperTradeReconciliation`، `BrokerTradeManagementEventTimeline`).

### المجموعة ب — تقارير محكومة بمفاتيح المجموعة 05
تُحذف نداءات كتابة هذه التقارير؛ مفاتيحها تبقى معرّفةً (بلا قارئ
كتابةٍ بعد الآن — مقبول، أبسط من حذف مدخلٍ قد يكون في `.set`):
- محكومة بـ`EnableTierEmergencyReports`: `TierTransitions`،
  `EmergencyTriggers`، `PaperStateSnapshot`.
- محكومة بـ`EnableLockParityReports`: `LockParityExecutabilityDecomposition`،
  `LockParityExecutabilityRollup`.
- محكومة بـ`EnableVirtualTrailingReport`: `VirtualTrailingExitLifecycle`.
- محكومة بـ`EnableStrategyRegistryReport`: `StrategyRegistryDiagnostics`.
- محكومة بـ`EnableDebugDiagnostics`: نحو 16 تقرير تشخيص عميق +
  `RuntimeReportVerification` + `ReportCreationGuarantee` +
  `AutoPeriodManifest`.

### المجموعة ج — تقريرا S00 التشخيصيّان
محكومان بـ`S00_DiagReport`: `S00_FvgDetection_Diagnostics` و
`S00_Trades_Diagnostics` — تُحذف نداءات كتابتهما. مفتاح
`S00_DiagReport` يبقى معرّفًا.

### المجموعة د — تقرير بلا حاجز
`StartupBootstrap` (`.mq5:3668`) يُكتب بلا مفتاح — يُحذف نداء
كتابته.

### ما لا يُحذف صراحةً
`BrokerTradeManagementEventTimeline` — يبقى كما هو (قرار المشغّل:
لا يُحذف، لا يُرفع ضمن الستّة).

> ملاحظة تنفيذ: إن كان حذف نداء الكتابة يترك دالّةً كاتبةً بلا
> مُستدعٍ، يجوز حذف جسم الدالّة أيضًا — لكن **لا يُحذف أيّ منطق
> حساب يغذّي عدّادًا يُقرأ في تقريرٍ جوهريّ.** الشكّ ⇒ احذف النداء
> فقط واترك الدالّة.

## معايير القبول

- البناء: 0 أخطاء، 0 تحذيرات جديدة.
- **اختبار تكافؤ سلوكيّ:** تشغيل S01 بإعدادات معروفة (أبريل،
  الحماية مُطفأة). المتوقَّع: `BrokerActualNetUSD` و`RawNetUSD`
  و`FinalWorkingNetUSD` و`TotalTrades` **مطابقة حرفيًّا** لتشغيلٍ
  ما قبل التنظيف. `TradeLifecycle` متطابق بايتيًّا. التنظيف لم
  يغيّر سلوكًا.
- **اختبار اختفاء التقارير:** في مجلّد التقارير بعد التشغيل، التقارير
  المذكورة في المجموعات أ–د **لم تعد تُكتَب**؛ التقارير الستّة
  الجوهريّة تُكتَب كالمعتاد.
- **اختبار بقاء العدّادات:** قيم الـ Summary المشتقّة من عدّادات
  التقارير المُطفأة (مثل عدّادات `PaperStateSnapshot`/`TierEmergency`
  إن ظهرت في الـ Summary) **لم تتغيّر** — الحساب باقٍ، الكتابة فقط
  أُزيلت.
- التقارير تحمل `EA_VERSION_TAG = R1_6a`.

## تحديث الإصدار

`EA_VERSION_TAG → R1_6a`، وسم البناء `DiagnosticReportCleanup`.

## بروتوكول العمل

> **موقع تقارير الـ Strategy Tester على جهاز المستخدم:**
> `C:\Users\jalak\AppData\Roaming\MetaQuotes\Terminal\Common\Files`
> — حين تحتاج المواصفةُ تقاريرَ، ابحث هنا أوّلًا.

1. إعادة بناء صريحة (F7) — 0 أخطاء.
2. شغّل اختبار التكافؤ السلوكيّ (تشغيل S01، أبريل، الحماية مُطفأة).
3. تحقّق من معايير القبول: الأرقام مطابقة، التقارير المنتهية
   اختفت، الستّة الجوهريّة باقية.
4. إن نجح ⇒ commit واحد لهذه المرحلة. لا إعادة كتابة تاريخ git.
5. ارفع: `Summary` + `TradeLifecycle` (يكفيان لتأكيد التكافؤ)،
   وقائمةً بأسماء ملفّات التقارير التي ظهرت في مجلّد الإخراج
   (لتأكيد اختفاء المنتهية وبقاء الستّة).

## خاتمة المواصفة

- **مراجعة Problems:** بعد البناء راجع لوحة Problems — 0 أخطاء؛
  سجّل أيّ تحذيرات.
- **تسجيل الأفكار (`Docs/Ideas_Backlog.md`):** أضِف —
  (١) **تنظيف سطح المدخلات** ما زال مؤجَّلًا — يتطلّب: تجميد
  مدخلات S00 (المرشّحات الـ5 لـ`#define`) بعد انتهاء ضبطها،
  **وإرسال المشغّل ملفّاتِ `.set`** للمقارنة قبل أيّ إعادة تسمية
  (خطر R3). لا إعادة تسمية مدخلٍ قبل ذلك.
  (٢) مفاتيح المجموعة 05 (`EnableTierEmergencyReports` وأخواتها)
  صارت بلا تقريرٍ تكتبه — مرشّحة للحذف الكامل في مرحلة تنظيف
  المدخلات، بعد فحص `.set`.
  (٣) غموض Amb-3 من الجرد: 11 مفتاح استراتيجيّة في المجموعة 03
  تحكم استراتيجيّاتٍ غير مبنيّة (placeholders) — تُحسَم عند إقرار
  خارطة الاستراتيجيّات.
- **ملفّ مراجعة:** عند الاكتمال اكتب
  `Docs/ReviewNotes/R1_6a_Review_Notes.md` بقائمة التقارير
  المُزالة ونتيجة اختبار التكافؤ، وحدِّث ملفّ ذاكرة المشروع.

---

## ملحق — Prompt جاهز لـ Claude Code

> فعّل وضع accept edits / auto mode أوّلًا.
> اقرأ `JA_FalconCore_SPEC_R1_6a_DiagnosticReportCleanup.md` ونفّذ
> المرحلة R1.6a — تنظيف التقارير التشخيصيّة المنتهية. استنادًا إلى
> جرد `DeadSurfaceAudit`، احذف **نداءات الكتابة** للتقارير
> المصنّفة DIAG-EXP: (أ) من داخل كتلة `EnableBrokerReports` في
> `Reporting/FalconReportWriter.mqh` احذف نداءَي
> `BrokerRebasedPaperComparison` و`BrokerContractRealityAudit`
> فقط — **أبقِ الكتلة وشرط `if` والتقارير الثلاثة الجوهريّة فيها**؛
> (ب) احذف نداءات كتابة التقارير المحكومة بـ`EnableTierEmergencyReports`
> و`EnableLockParityReports` و`EnableVirtualTrailingReport` و
> `EnableStrategyRegistryReport` و`EnableDebugDiagnostics` (نحو 16
> تقرير تشخيص + RuntimeReportVerification + ReportCreationGuarantee
> + AutoPeriodManifest)؛ (ج) احذف نداءَي `S00_FvgDetection_Diagnostics`
> و`S00_Trades_Diagnostics`؛ (د) احذف نداء `StartupBootstrap`.
> حدّث `EA_VERSION_TAG` إلى `R1_6a`، وسم `DiagnosticReportCleanup`.
> **لا تحذف ولا تُعِد تسمية أيّ مدخل `input` — صفر مدخلات ميّتة
> بالجرد. لا تحذف أيّ مفتاح حاجز (بما فيها مفاتيح المجموعة 05 و
> `S00_DiagReport`) — تبقى معرّفةً. لا تمسّ `TradeManagement_DiagReport`
> ولا تقريره الجوهريّ. لا تمسّ التقارير الستّة الجوهريّة ولا
> `BrokerTradeManagementEventTimeline`. لا تحذف أيّ منطق حساب يغذّي
> عدّادًا يُقرأ في تقريرٍ جوهريّ — الشكّ يعني احذف النداء فقط. لا
> تمسّ Risk/FalconRiskLifecycleProcessor.mqh ولا سلسلة Apply*.**
> ابنِ (F7، 0 أخطاء)، نفّذ اختبار التكافؤ السلوكيّ (تشغيل S01،
> أبريل، الحماية مُطفأة — يجب أن تبقى `BrokerActualNetUSD` و
> `RawNetUSD` و`FinalWorkingNetUSD` و`TotalTrades` مطابقةً
> حرفيًّا، و`TradeLifecycle` متطابقًا بايتيًّا)، وأكّد اختفاء
> التقارير المنتهية وبقاء الستّة. سجّل الأفكار الثلاثة في
> `Docs/Ideas_Backlog.md`، راجع لوحة Problems، اكتب
> `Docs/ReviewNotes/R1_6a_Review_Notes.md`. commit واحد. بعد
> الانتهاء أكّد `git diff --stat`.
