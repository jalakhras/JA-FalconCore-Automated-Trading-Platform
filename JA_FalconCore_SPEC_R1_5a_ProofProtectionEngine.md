# JA FalconCore — مواصفة المرحلة R1.5a: محرّك الحماية الحقيقيّ (ProofProtectionEngine)

> **نوع المستند:** مواصفة بناء — تُنفَّذ عبر Claude Code.
> **الأساس:** R1.4b (commit طبقة التنسيق). مبنيّ على عقد الواجهة
> `CFalconTradeEngine` المُثبَت في 2b.
> **نوع المرحلة:** المرحلة 3a — أوّل محرّك حقيقيّ. يغيّر السلوك.

---

## موقع هذه المرحلة في خريطة البناء

المرحلة 2 اكتملت: مقياس الحقيقة (2a) + طبقة التنسيق والواجهة (2b).
**المرحلة 3 تبني المحرّكات، واحدًا لكلّ مرحلة فرعيّة.** 3a = أوّلها:
محرّك الحماية. هي **أوّل مرّة تغيّر فيها طبقةُ إدارة الصفقة سلوكًا
فعليًّا** — تُصدر `modify` للـ SL على البروكر. لذا تتطلّب أيضًا بناء
**مسار تطبيق القرار** المؤجَّل من 2b.

بعدها: 3b (runner)، 3c (partial)، إلخ.

## الدرس الحاكم — لا حماية مبكّرة

S00 ماتت لأنها سلّحت الحماية عند +8 نقاط على M5 — منطقة شمعة واحدة.
الحماية المبكّرة تقطع الرابحين قبل نضجهم. **هذا التصميم يحترم القاعدة
بنيويًّا:** التسليح بمضاعف R (متكيّف، متأخّر بطبيعته)، لا بعتبة نقاط
سحريّة؛ والوجهة دون الدخول قليلًا، لا breakeven حرفيًّا يخنقه الضجيج.

## الهدف

بناء أوّل محرّك إدارة صفقة حقيقيّ:
1. **مفصلة `ProtectionPolicy`** — واجهة سياسة حماية قابلة للتبديل.
   تجعل سياسات الحماية المستقبليّة (هيكليّة، تكيّفيّة) تنضمّ دون
   لمس المحرّك ولا المنسّق.
2. **سياسة واحدة فقط: `FixedRMultipleProtection`** — تُسلّح حين
   يبلغ الربح غير المحقّق مضاعفَ R مضبوطًا، وتنقل الـ SL إلى نقطة
   محسوبة من الدخول بإزاحة مضبوطة.
3. **`ProofProtectionEngine`** — محرّك يرث `CFalconTradeEngine`،
   يستشير السياسة، ويُرجِع قرار `FALCON_TM_MODIFY_SL` عند التسليح.
4. **مسار تطبيق القرار في المنسّق** — تنفيذ `FALCON_TM_MODIFY_SL`
   كأمر `modify` حقيقيّ على مركز البروكر.

المرحلة 3a تُثبت أن محرّكًا حقيقيًّا واحدًا يعدّل صفقة حيّة على
البروكر، مقيسًا بأثرٍ صادق على `BrokerActualNetUSD`.

## القيود الصارمة (ما يجب ألّا يحدث)

- **محرّك واحد فقط: الحماية.** لا runner، لا partial، لا ratchet،
  لا early-exit — مراحل لاحقة.
- **سياسة واحدة فقط: `FixedRMultipleProtection`.** لا سياسة ثانية،
  لا منطق دمج/اختيار — تُسجَّل للـ Backlog.
- **الحماية لا تُسلّح مبكّرًا.** التسليح بمضاعف R حصرًا، لا بعتبة
  نقاط ثابتة. الحدّ الأدنى المسموح لمدخل التسليح ≥ 1.0R.
- **التطبيق = `modify` فقط.** المحرّك يحرّك الـ SL؛ لا يُغلق مركزًا،
  لا يفتح، لا partial. `FALCON_TM_CLOSE`/`PARTIAL_CLOSE` تبقى في
  العقد لكن **لا مسار تطبيق لهما في 3a** (يُكتب صفّ تدقيق
  `UNSUPPORTED_DECISION_NO_APPLY_PATH` إن وردت — لا يحدث مع محرّك
  الحماية).
- **الـ SL يتحرّك في اتّجاه واحد فقط** — نحو تقليل المخاطرة. لا
  يُرجَع الـ SL للخلف أبدًا (لا توسيع خسارة). إن حسبت السياسة وقفًا
  أسوأ من الحاليّ، القرار = `NO_ACTION`.
- **لا يُمسّ `Risk/FalconRiskLifecycleProcessor.mqh`** ولا سلسلة
  الـ Apply* ولا ترتيبها.
- **لا تُمسّ ملفّات الاستراتيجيّات** (S00، S01، legacy) ولا منطقها.
- **لا يُمسّ منطق الدخول في `FalconBrokerEntryBridge.mqh`** — يُضاف
  إليه مسار `modify` فقط إن لزم، أو يُستدعى عبر دالّة `modify`
  قائمة؛ لا تغيير لمنطق الدخول/الخروج.
- `Enable_S01_Protection = false` افتراضيًّا — عند الإطفاء المحرّك
  غير مُسجَّل، والطبقة خاملة (تكافؤ أساس تامّ مع R1.4b).
- لا تضخيم مدخلات: ثلاثة مدخلات فقط (انظر «المدخلات»).
- الملفّات المسموح إنشاؤها/مسّها: مجلّد `TradeManagement/Engines/`
  الجديد (ملفّات المحرّك/السياسة أدناه) + إضافة مسار التطبيق إلى
  `FalconTradeManagementCoordinator.mqh` + سطر تسجيل المحرّك +
  المدخلات + `EA_VERSION_TAG`. لا غيرها.

## مواصفة المحرّك

### ١ — مفصلة السياسة — `FalconProtectionPolicyContract.mqh`

`class CFalconProtectionPolicy` — واجهة مجرّدة:
```
virtual string             PolicyId() = 0;
virtual FalconTradeDecision EvaluateProtection(const FalconManagedPositionContext &ctx) = 0;
```
السياسة تتلقّى سياق المركز (من عقد 2b) وتُرجِع `FALCON_TM_MODIFY_SL`
مع `new_sl` محسوب، أو `FALCON_TM_NO_ACTION`.

### ٢ — السياسة البسيطة — `FalconFixedRMultipleProtection.mqh`

`class CFalconFixedRMultipleProtection : public CFalconProtectionPolicy`:
- `PolicyId()` يُرجِع `"FIXED_R_MULTIPLE"`.
- `EvaluateProtection(ctx)`:
  1. مسافة الوقف الأصليّة `R = |broker_entry_price − original_sl|`
     (مقيسة من سياق المركز).
  2. الربح غير المحقّق بالنقاط = المسافة من الدخول للسعر الحاليّ في
     اتّجاه الصفقة.
  3. **شرط التسليح:** الربح غير المحقّق ≥ `Protection_TriggerRMultiple
     × R`. إن لم يتحقّق ⇒ `NO_ACTION`.
  4. **الوقف المحسوب:** `new_sl = broker_entry_price ∓
     Protection_StopOffsetPoints` (دون الدخول قليلًا — للشراء أقلّ
     من الدخول، للبيع أعلى). `StopOffsetPoints` موجب = خسارة صغيرة
     مقفولة؛ سالب = ربح صغير مقفول. القيمة من الدليل (المسح).
  5. **حارس الاتّجاه الواحد:** إن كان `new_sl` لا يُحسّن الوقف
     الحاليّ (`ctx.current_sl`) ⇒ `NO_ACTION`. الحماية تُسلَّح مرّة،
     ولا تُراجَع للخلف.

### ٣ — المحرّك — `FalconProofProtectionEngine.mqh`

`class CFalconProofProtectionEngine : public CFalconTradeEngine`:
- يحمل مؤشّر `CFalconProtectionPolicy*` (تُحقَن السياسة عند الإنشاء).
- `EngineId()` يُرجِع `"PROOF_PROTECTION"`.
- `Evaluate(ctx)` يفوّض إلى `policy.EvaluateProtection(ctx)`
  ويُرجِع قراره.
- في نهاية الملفّ: instance للسياسة + instance للمحرّك مربوطًا بها.

### ٤ — مسار تطبيق القرار في المنسّق

يُضاف إلى `CFalconTradeManagementCoordinator` (المبنيّ في 2b)
معالجةُ القرار:
- لقرار `FALCON_TM_MODIFY_SL`: يُصدر المنسّق `modify` حقيقيًّا على
  مركز البروكر (`PositionModify` أو دالّة الـ bridge القائمة)
  بالـ `new_sl`، مع إبقاء الـ TP كما هو.
- يُسجَّل في `TradeManagementCoordinatorAudit`: `AppliedAction =
  SL_MODIFIED` (أو `SL_MODIFY_REJECTED` + سبب البروكر عند الفشل).
- لقرار `NO_ACTION`: `AppliedAction = NONE`.
- لأيّ قرار آخر: `AppliedAction = UNSUPPORTED_DECISION_NO_APPLY_PATH`.

### المدخلات — في `FalconTradeManagementInputs.mqh`

```mql5
input bool   Enable_S01_Protection       = false;  // activates the protection engine for the harness
input double Protection_TriggerRMultiple = 1.0;    // arms the stop move once unrealised profit reaches this multiple of risk
input int    Protection_StopOffsetPoints = 0;      // stop placement relative to entry; positive locks a small loss, negative locks a small profit
```
الحدّ الأدنى لـ `Protection_TriggerRMultiple` = 1.0 (يُرفض أقلّ —
حارس ضدّ الحماية المبكّرة). التعليق بعد `//` وصفيّ نظيف بلا أرقام
مراحل (قاعدة المدخلات #4).

### الوصل

- `#include` لملفّات `Engines/` بجوار ملفّات `TradeManagement/`.
- في التهيئة: `if(Enable_S01_Protection) g_trade_management_
  coordinator.RegisterEngine(GetPointer(g_proof_protection_engine));`
  — المحرّك يُسجَّل فقط حين يكون مُفعَّلًا.
- لا تغيير لاستدعاء `EvaluateOnNewBar` في `OnTick` (موجود من 2b).

## معايير القبول

- البناء: 0 أخطاء.
- **اختبار أ — تكافؤ الأساس (`Enable_S01_Protection = false`):**
  تشغيل S01 بإعدادات اختبار R1.4b، المحرّك غير مُسجَّل. المتوقَّع:
  `BrokerActualNetUSD = 321.92` حرفيًّا، `TradeLifecycle` متطابق.
  أي إضافة محرّك الحماية وهو مُطفأ لم تكسر شيئًا.
- **اختبار ب — الحماية تعمل (`Enable_S01_Protection = true`):**
  تشغيل S01 على **3 أشهر — مارس + أبريل + مايو 2026، تشغيل واحد
  ممتدّ** (قاعدة #5). المتوقَّع:
  - `TradeManagementCoordinatorAudit` يُظهر قرارات
    `FALCON_TM_MODIFY_SL` و`AppliedAction = SL_MODIFIED` على
    صفقات بلغت عتبة التسليح.
  - الصفقات المُسلَّحة التي ضُرب وقفها لاحقًا تُغلق عند الـ SL
    المُحرَّك، لا الأصليّ — مرئيٌّ في `BrokerExecutionLifecycle`.
  - `BrokerActualNetUSD` **يختلف** عن تشغيل الحماية-مُطفأة (المحرّك
    غيّر السلوك فعلًا) — التحليل يقطّع شهريًّا.
  - حارس الاتّجاه الواحد: لا صفّ `modify` يُرجِع الـ SL للخلف.
- **مسح القيم (في اختبار ب):** كرّر اختبار ب عبر شبكة قيم
  `Protection_TriggerRMultiple ∈ {1.0, 1.5, 2.0}` ×
  `Protection_StopOffsetPoints ∈ {−20, 0, +20}` — كلٌّ تشغيل 3
  أشهر ممتدّ. النتيجة تُقطَّع شهريًّا. **لا تُختار القيمة الأعلى في
  شهر؛ تُختار المستقرّة عبر الأشهر الثلاثة** (قاعدتا #5 و#6).
- **الحتميّة:** إعادة تشغيل أيّ تركيبة ⇒ نتيجة متطابقة.
- التقارير تحمل `EA_VERSION_TAG = R1_5a`.

> ملاحظة: المسح 9 تشغيلات × 3 أشهر. إن كان ثقيلًا، نفّذ الزوايا
> الأربع + المركز (5 تشغيلات) أوّلًا وأبلِغ — نقرّر بقيّة الشبكة
> على ضوء النتائج.

## تحديث الإصدار

`EA_VERSION_TAG → R1_5a`، وسم البناء `ProofProtectionEngine`.

## بروتوكول العمل

> **موقع تقارير الـ Strategy Tester على جهاز المستخدم:**
> `C:\Users\jalak\AppData\Roaming\MetaQuotes\Terminal\Common\Files`
> — التقارير المخصّصة تُكتب هنا؛ `ReportTester.xlsx` يُصدَّر حيث
> يحدّده المشغّل. حين تحتاج المواصفةُ تقاريرَ، ابحث هنا أوّلًا.

إعدادات S01 المشتركة: `Enable_S01_Harness = true`,
`S01_RealExecution = true`, `EnableRealExecution = true`,
`EnableVirtualTrailingBridge = false`, `Enable_S00_FvgScalp = false`,
`S00_RealExecution = false`, `EnableStrategy_FvgMicroRetest = false`,
`Enable_TradeManagement = true`, `TradeManagement_DiagReport = true`,
`UseFixedLot = true`, `FixedLotSize = 0.01`, `S01_StopBuffer = 30`,
`S01_TargetRMultiple = 2.0`. الإطار M5، الرمز `US100_Spot`.
- اختبار أ: النافذة `2026.04.01 → 2026.04.30` (مقارنة بأساس
  R1.4b المعروف 321.92).
- اختبار ب والمسح: النافذة `2026.03.01 → 2026.05.31` (3 أشهر،
  تشغيل واحد ممتدّ لكلّ تركيبة).

1. إعادة بناء صريحة (F7) — 0 أخطاء.
2. شغّل اختبار أ، تحقّق من تكافؤ الأساس (321.92).
3. شغّل اختبار ب + مسح القيم على 3 أشهر.
4. إن نجح ⇒ commit واحد لهذه المرحلة. لا إعادة كتابة تاريخ git.
5. ارفع: من اختبار أ `Summary`؛ ومن كلّ تركيبة مسح الخمسةَ +
   `TradeManagementCoordinatorAudit` + `ReportTester.xlsx`، مسمّاةً
   بوضوح بقيم التركيبة.

## خاتمة المواصفة

- **مراجعة Problems:** بعد البناء راجع لوحة Problems — 0 أخطاء؛
  سجّل أيّ تحذيرات.
- **تسجيل الأفكار (`Docs/Ideas_Backlog.md`):** أضِف —
  (١) **حماية تكيّفيّة تدمج السياسات حسب حالة الصفقة** — الهدف بعيد
  المدى: محرّك الحماية يختار سياسةً حسب حالة الصفقة. **لا يُبنى قبل
  توفّر سياستين مُختبَرتين على الأقلّ** (`FixedRMultiple` +
  `StructuralSwing` مثلًا) **وجدول مقارنة** يحدّد، بأرقام البروكر،
  أيّ حالة لأيّ سياسة. يُبنى حينها كسياسة `AdaptiveProtection` تنضمّ
  للمفصلة — مُختبَرةً وحدها.
  (٢) **سياسة حماية هيكليّة** (`StructuralSwingProtection`) — تنقل
  الـ SL لقاع/قمّة مؤكّدة؛ مرشَّحة كسياسة ثانية بعد إثبات الأساس.
  (٣) مسار تطبيق `FALCON_TM_CLOSE` / `PARTIAL_CLOSE` في المنسّق —
  يُبنى مع محرّكات 3b/3c.
- **ملفّ مراجعة:** عند الاكتمال اكتب
  `Docs/ReviewNotes/R1_5a_Review_Notes.md` بنتيجة 3a وجدول المسح
  والقيمة المستقرّة المختارة، وحدِّث ملفّ ذاكرة المشروع.

---

## ملحق — Prompt جاهز لـ Claude Code

> فعّل وضع accept edits / auto mode أوّلًا.
> اقرأ `JA_FalconCore_SPEC_R1_5a_ProofProtectionEngine.md` ونفّذ
> المرحلة R1.5a — أوّل محرّك إدارة صفقة حقيقيّ. أنشئ
> `TradeManagement/Engines/` فيه: `FalconProtectionPolicyContract.mqh`
> (الواجهة المجرّدة `CFalconProtectionPolicy` بدالّتَي `PolicyId`
> و`EvaluateProtection`)؛ `FalconFixedRMultipleProtection.mqh`
> (`CFalconFixedRMultipleProtection`: تُسلّح حين الربح غير المحقّق ≥
> `Protection_TriggerRMultiple × R` حيث `R` مسافة الوقف الأصليّة،
> تحسب `new_sl` من الدخول بإزاحة `Protection_StopOffsetPoints`،
> وتُرجِع `NO_ACTION` إن لم يتحقّق التسليح أو إن كان الوقف الجديد لا
> يُحسّن الحاليّ)؛ `FalconProofProtectionEngine.mqh`
> (`CFalconProofProtectionEngine` يرث `CFalconTradeEngine`، يفوّض
> إلى السياسة، `EngineId = "PROOF_PROTECTION"`، + instances). أضِف
> إلى `FalconTradeManagementCoordinator.mqh` مسار تطبيق القرار:
> `FALCON_TM_MODIFY_SL` ⇒ `modify` حقيقيّ على مركز البروكر +
> `AppliedAction = SL_MODIFIED` في تقرير التدقيق. أضِف ثلاثة مدخلات
> (`Enable_S01_Protection`, `Protection_TriggerRMultiple`,
> `Protection_StopOffsetPoints`)، وسجّل المحرّك فقط عند
> `Enable_S01_Protection`. حدّث `EA_VERSION_TAG` إلى `R1_5a`، وسم
> `ProofProtectionEngine`.
> **محرّك واحد فقط (الحماية)، سياسة واحدة فقط (FixedRMultiple)، لا
> منطق دمج/اختيار. التطبيق modify فقط — لا close/partial. الـ SL
> يتحرّك باتّجاه تقليل المخاطرة فقط، لا يُرجَع للخلف أبدًا. الحدّ
> الأدنى لـ TriggerRMultiple = 1.0 (ارفض أقلّ — حارس ضدّ الحماية
> المبكّرة). لا تمسّ Risk/FalconRiskLifecycleProcessor.mqh ولا
> سلسلة Apply* ولا أيّ ملفّ استراتيجيّة ولا منطق الدخول/الخروج في
> الـ bridge. مع Enable_S01_Protection=false صفر تغيير —
> BrokerActualNetUSD يبقى 321.92.**
> ابنِ (F7، 0 أخطاء)، نفّذ اختبار أ (الحماية مُطفأة، نافذة أبريل —
> يجب أن يبقى `BrokerActualNetUSD = 321.92`) واختبار ب (الحماية
> مُشغَّلة، نافذة 3 أشهر `2026.03.01→2026.05.31`)، ثمّ مسح القيم:
> `TriggerRMultiple ∈ {1.0,1.5,2.0}` × `StopOffsetPoints ∈
> {−20,0,+20}` — إن ثقُل، نفّذ الزوايا الأربع + المركز (5
> تشغيلات) وأبلِغ. لكلّ تشغيل تحقّق من الحتميّة وحارس الاتّجاه
> الواحد. أبلِغ بالنتائج والتقارير مسمّاةً بقيم كلّ تركيبة. سجّل
> الأفكار الثلاثة في `Docs/Ideas_Backlog.md`، راجع لوحة Problems،
> اكتب `Docs/ReviewNotes/R1_5a_Review_Notes.md`. commit واحد. بعد
> الانتهاء أكّد `git diff --stat`.
