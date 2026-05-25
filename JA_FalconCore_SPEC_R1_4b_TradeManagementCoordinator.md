# JA FalconCore — مواصفة المرحلة R1.4b: منسّق إدارة الصفقة + واجهة المحرّكات

> **نوع المستند:** مواصفة بناء — تُنفَّذ عبر Claude Code.
> **الأساس:** R1.4a (commit مقياس الحقيقة التقريريّ). مبنيّ على
> تقرير استكشاف فجوة الورقيّ↔البروكر ومحضر تشخيص اختبار ب.
> **نوع المرحلة:** المرحلة 2b — هيكل تنسيق، بلا محرّك حقيقيّ.

---

## موقع هذه المرحلة في خريطة البناء

المشروع: بناء طبقة إدارة الصفقة الحقيقيّة. المرحلة 2 = نقطة التنسيق
+ واجهة المحرّكات، مُقسَّمة: 2a (مقياس الحقيقة التقريريّ — ✓ مكتملة)،
**2b (هذه المواصفة) = نقطة التنسيق + الواجهة.** بعدها المرحلة 3
تبني المحرّكات واحدًا واحدًا.

تحاكي 2b منطق 1a: 1a بنت العمود الفقريّ للتنفيذ (دخول↔بروكر↔خروج)
بلا محرّك إدارة صفقة؛ **2b تبني العمود الفقريّ لإدارة الصفقة** —
واجهة محرّك + منسّق يستدعيها — بلا محرّك حقيقيّ، يُثبَت بمحرّك no-op.

## الهدف

بناء طبقة `TradeManagement` حقيقيّة وقابلة لإعادة الاستخدام:
1. **واجهة محرّك مجرّدة** — عقد موحَّد ترثه كلّ محرّكات المرحلة 3
   (حماية/runner/partial/early-exit/ratchet) والاستراتيجيّات الـ10+.
2. **منسّق إدارة الصفقة الحيّة** — يُستدعى لكلّ شمعة M5 مغلقة، يمرّ
   على كلّ مركز بروكر مفتوح للـ EA، يبني سياقه من **حالة البروكر
   الحقيقيّة**، ويستدعي كلّ محرّك مُسجَّل.
3. **محرّك no-op للإثبات** — يُسجَّل في المنسّق، يُرجِع دائمًا «لا
   فعل». غرضه الوحيد: إثبات أن السلك يعمل end-to-end — التسجيل،
   الاستدعاء، بناء السياق، عودة القرار — **دون تغيير أيّ سلوك**.

المرحلة 2b تُثبت أن طبقة التنسيق موصولة وتعمل، باستراتيجيّة شفّافة
(S01) ومحرّك شفّاف (no-op)، قبل أن يُبنى محرّك حقيقيّ واحد.

## القيود الصارمة (ما يجب ألّا يحدث)

- **لا منطق محرّك حقيقيّ.** لا حماية، لا runner، لا partial، لا
  ratchet، لا early-exit — هذه المرحلة 3. المحرّك الوحيد = no-op.
- **المنسّق لا يُصدر أيّ أمر بروكر في 2b.** لا `OrderSend`، لا
  modify، لا close. المنسّق في 2b **مراقِبٌ فقط**: يبني سياقًا،
  يستدعي محرّكات، يجمع قرارات، يكتب صفّ تدقيق. مسار «تطبيق القرار»
  (إصدار modify/close فعليّ) = المرحلة 3، يُبنى مع أوّل محرّك حقيقيّ.
- **لا يُمسّ `Risk/FalconRiskLifecycleProcessor.mqh`** ولا سلسلة
  الـ Apply* ولا ترتيبها.
- **لا يُمسّ كود التنفيذ** (`Execution/FalconBrokerEntryBridge.mqh`)
  — لا منطقه ولا فلتر الـ magic.
- **لا تُمسّ ملفّات الاستراتيجيّات** (S00، S01، legacy) ولا منطقها.
- `Enable_TradeManagement = false` افتراضيًّا — عند الإطفاء الطبقة
  خاملة تمامًا (تكافؤ أساس تامّ، صفر تغيّر).
- المحرّك no-op يضمن أن كلّ قرار = «لا فعل»؛ فنتيجة البروكر مع
  المنسّق مُشغَّلًا = نتيجته مع المنسّق مُطفأً، حرفيًّا.
- لا تضخيم مدخلات: مدخلان فقط (انظر «المدخلات»).
- الملفّات المسموح إنشاؤها/مسّها: مجلّد `TradeManagement/` الجديد
  (الملفّات أدناه) + سطرا الوصل في الـ `.mq5` الرئيسيّ + المدخلان +
  `EA_VERSION_TAG` في `Core/FalconConstants.mqh`. لا غيرها. ملفّ
  `TradeManagement/FalconTradeManagement_Placeholder.mqh` القائم
  يُترَك مكانه (مسّ أدنى).

## مواصفة الطبقة

مجلّد جديد `TradeManagement/` يحوي أربعة ملفّات.

### ١ — عقد الواجهة — `FalconTradeEngineContract.mqh`

يعرّف ثلاثة أنواع:

- `enum ENUM_FALCON_TM_ACTION` — فضاء القرارات الكامل:
  `FALCON_TM_NO_ACTION`، `FALCON_TM_MODIFY_SL`، `FALCON_TM_CLOSE`،
  `FALCON_TM_PARTIAL_CLOSE`. (تُعرَّف كاملةً الآن حتى لا يتغيّر
  العقد حين تُضاف محرّكات المرحلة 3؛ 2b يستعمل `NO_ACTION` فقط.)

- `struct FalconManagedPositionContext` — سياق مبنيّ من **حالة
  البروكر الحقيقيّة** لمركز مفتوح: `position_ticket`,
  `strategy_id`, `direction`, `broker_entry_price`, `current_sl`,
  `current_tp`, `volume`, `current_bid`, `current_ask`,
  `broker_unrealized_usd`, `bars_since_entry`, `closed_bar_time`.
  (لا حقول ورقيّة — العقد broker-side، تطبيقًا لحكم الاستكشاف.)

- `struct FalconTradeDecision` — قرار محرّك: `action`
  (`ENUM_FALCON_TM_ACTION`), `new_sl`, `close_fraction`, `reason`
  (نصّ). في 2b يُملأ بـ`FALCON_TM_NO_ACTION` فقط.

- `class CFalconTradeEngine` — الواجهة المجرّدة:
  ```
  virtual string            EngineId() = 0;
  virtual FalconTradeDecision Evaluate(const FalconManagedPositionContext &ctx) = 0;
  ```

### ٢ — محرّك الإثبات — `FalconNoOpProbeEngine.mqh`

`class CFalconNoOpProbeEngine : public CFalconTradeEngine` —
`EngineId()` يُرجِع `"NOOP_PROBE"`؛ `Evaluate()` يُرجِع دائمًا
قرارًا `action = FALCON_TM_NO_ACTION`, `reason = "noop probe — no
management logic"`. لا حالة داخليّة. في نهاية الملفّ:
`CFalconNoOpProbeEngine g_noop_probe_engine;`.

### ٣ — المنسّق — `FalconTradeManagementCoordinator.mqh`

`class CFalconTradeManagementCoordinator`:

- سجلّ محرّكات (مصفوفة مؤشّرات `CFalconTradeEngine*`) +
  `RegisterEngine(CFalconTradeEngine *engine)`.
- `EvaluateOnNewBar(CFalconMarketContext &market_context)`:
  1. يُلغي التكرار لكلّ شمعة M5 مغلقة (نمط `EvaluateOnNewBar`
     في S01 — استدعاء واحد لكلّ شمعة مغلقة).
  2. يمرّ على `PositionsTotal()`، يُرشّح مراكز الـ EA بالـ magic
     الفالكونيّ. لكلّ مركز:
     - يبني `FalconManagedPositionContext` من حالة البروكر.
     - يستدعي `Evaluate(ctx)` لكلّ محرّك مُسجَّل، يجمع القرارات.
     - يكتب صفّ تدقيق (انظر §٤).
  3. **2b لا يطبّق أيّ قرار.** لأيّ قرار ≠ `NO_ACTION` يكتب صفّ
     تدقيق `UNSUPPORTED_DECISION_NO_APPLY_PATH` (لا يحدث مع
     no-op، لكن العقد يبقى صريحًا للمرحلة 3).
- في نهاية الملفّ: `CFalconTradeManagementCoordinator
  g_trade_management_coordinator;`.
- المنسّق يحدّد مراكز الـ EA بالـ magic الفالكونيّ المشترك؛ توجيه
  المحرّكات حسب `strategy_id` شأن المرحلة 3+ (Backlog #57).

### ٤ — تقرير تدقيق المنسّق

عند `TradeManagement_DiagReport = true`، يكتب المنسّق ملفًّا
`TradeManagementCoordinatorAudit` (تسمية عبر `FalconBuildReportFileName`
كبقيّة التقارير). صفّ لكلّ تقييم محرّك لكلّ مركز لكلّ شمعة مغلقة،
بالأعمدة: `ClosedBarTime`, `PositionTicket`, `StrategyId`,
`EngineId`, `BarsSinceEntry`, `BrokerUnrealizedUSD`, `CurrentSL`,
`DecisionAction`, `DecisionReason`, `AppliedAction` (في 2b ثابت
`NONE_PHASE2B_OBSERVATIONAL`). هذا التقرير هو **دليل أن السلك
اشتغل**.

### المدخلات — `FalconTradeManagementInputs.mqh`

```mql5
input bool Enable_TradeManagement     = false;  // activates the live trade-management coordinator
input bool TradeManagement_DiagReport = false;  // writes the coordinator audit CSV
```

التعليق بعد `//` وصفيّ نظيف، بلا أرقام مراحل (قاعدة المدخلات #4).

### الوصل بالمنصّة

- `#include` للملفّات الأربعة في الـ `.mq5` الرئيسيّ، بجوار
  `#include` الخاصّ بـ S01.
- في `OnInit()` (أو عند تهيئة الطبقة): تسجيل المحرّك —
  `g_trade_management_coordinator.RegisterEngine(GetPointer(
  g_noop_probe_engine));`.
- في `OnTick()`، بعد استدعاءات الاستراتيجيّات مباشرةً، مَبوَّبًا:
  `if(Enable_TradeManagement) g_trade_management_coordinator.
  EvaluateOnNewBar(g_market_context);`.

## معايير القبول

- البناء: 0 أخطاء.
- **اختبار أ — تكافؤ الأساس (`Enable_TradeManagement = false`):**
  تشغيل S01 بإعدادات اختبار ب نفسها، المنسّق مُطفأ. المتوقَّع:
  نتيجة البروكر مطابقة لتشغيل R1.4a — **`BrokerActualNetUSD =
  321.92`** حرفيًّا، `TradeLifecycle` لصفقات S01 متطابق. أي إضافة
  طبقة `TradeManagement` وهي مُطفأة لم تكسر شيئًا. (والأساس الورقيّ
  legacy `585.17 / 1104.89` يبقى — 2b لا يلمس الطبقة الورقيّة.)
- **اختبار ب — العمود الفقريّ للتنسيق (`Enable_TradeManagement =
  true`, `TradeManagement_DiagReport = true`):** نفس تشغيل S01.
  المتوقَّع:
  - `TradeManagementCoordinatorAudit` يُكتَب، وفيه صفوف تُظهر أن
    المنسّق استُدعِي لكلّ شمعة M5 مغلقة لكلّ مركز S01 مفتوح.
  - المحرّك `NOOP_PROBE` يظهر مُقيَّمًا، وكلّ `DecisionAction =
    FALCON_TM_NO_ACTION`، وكلّ `AppliedAction =
    NONE_PHASE2B_OBSERVATIONAL`.
  - **`BrokerActualNetUSD = 321.92` حرفيًّا — مطابق لاختبار أ.**
    هذا هو الإثبات الجوهريّ: طبقة التنسيق موصولة وتعمل، لكنّها
    خاملة سلوكيًّا (محرّك no-op لا يغيّر شيئًا).
- **الحتميّة:** إعادة اختبار ب على نفس النافذة ⇒ صفقات وصفوف تدقيق
  متطابقة.
- التقارير تحمل `EA_VERSION_TAG = R1_4b`.

## تحديث الإصدار

`EA_VERSION_TAG → R1_4b`، وسم البناء `TradeManagementCoordinatorSpine`.

## بروتوكول العمل

> **موقع تقارير الـ Strategy Tester على جهاز المستخدم:**
> `C:\Users\jalak\AppData\Roaming\MetaQuotes\Terminal\Common\Files`
> — التقارير المخصّصة تُكتب هنا؛ `ReportTester.xlsx` يُصدَّر حيث
> يحدّده المشغّل. حين تحتاج المواصفةُ تقاريرَ، ابحث هنا أوّلًا.

إعدادات اختبار أ وب (مشتركة، عدا مفتاحَي المنسّق):
`Enable_S01_Harness = true`, `S01_RealExecution = true`,
`EnableRealExecution = true`, `EnableVirtualTrailingBridge = false`,
`Enable_S00_FvgScalp = false`, `S00_RealExecution = false`,
`EnableStrategy_FvgMicroRetest = false`, `UseFixedLot = true`,
`FixedLotSize = 0.01`, `S01_StopBuffer = 30`,
`S01_TargetRMultiple = 2.0`. النافذة `2026.04.01 → 2026.04.30`،
M5، `US100_Spot` — نفس نافذة R1.4a لمقارنة `BrokerActualNetUSD`
بأساس معروف. (لا حاجة لاختبار 3 أشهر هنا — 2b لا تغيّر سلوكًا
استراتيجيًّا؛ اختبار الـ3 أشهر شأن محرّكات المرحلة 3.)

1. إعادة بناء صريحة (F7) — 0 أخطاء.
2. شغّل اختبار أ (`Enable_TradeManagement = false`)، تحقّق من
   تكافؤ الأساس.
3. شغّل اختبار ب (`Enable_TradeManagement = true`,
   `TradeManagement_DiagReport = true`) **مرّتين**، تحقّق من
   معايير القبول والحتميّة.
4. إن نجحا ⇒ commit واحد لهذه المرحلة. لا إعادة كتابة تاريخ git.
5. ارفع من اختبار ب: `Summary`, `TradeLifecycle`,
   `BrokerExecutionLifecycle`, `BrokerPaperTradeReconciliation`,
   `TradeManagementCoordinatorAudit`, `ReportTester.xlsx`. ومن
   اختبار أ: `Summary` (يكفي لتأكيد `BrokerActualNetUSD = 321.92`).

## خاتمة المواصفة

- **مراجعة Problems:** بعد البناء راجع لوحة Problems — الهدف 0
  أخطاء؛ سجّل أيّ تحذيرات.
- **تسجيل الأفكار (`Docs/Ideas_Backlog.md`):** أضِف —
  (١) **مرحلة تنظيف سطح المدخلات** — بعد اكتمال طبقة إدارة الصفقة
  (المرحلة 4)، تبدأ باستكشاف موت قراءة-فقط (grep لكلّ موضع قراءة
  كلّ مدخل)؛ المدخل الثابت غير المضبوط → `#define` بقيمته (يختفي
  من شاشة الإعدادات، يبقى سلوكه)؛ المدخل الميت (لا قارئ) → يُحذف؛
  لا حذف بلا إثبات موت. تنضمّ للبند #36.
  (٢) **مسار تطبيق القرار في المنسّق** — إصدار modify/close فعليّ
  من `FalconTradeDecision`؛ يُبنى مع أوّل محرّك حقيقيّ في المرحلة 3.
  (٣) ملفّ `FalconTradeManagement_Placeholder.mqh` صار بلا وظيفة
  بعد ملء مجلّد `TradeManagement/` — مرشّح للحذف في تنظيف لاحق.
- **ملفّ مراجعة:** عند اكتمال المرحلة، اكتب
  `Docs/ReviewNotes/R1_4b_Review_Notes.md` بنتيجة 2b، وحدِّث ملفّ
  ذاكرة المشروع بإغلاق المرحلة 2 وحالة طبقة التنسيق.

---

## ملحق — Prompt جاهز لـ Claude Code

> فعّل وضع accept edits / auto mode أوّلًا.
> اقرأ `JA_FalconCore_SPEC_R1_4b_TradeManagementCoordinator.md`
> ونفّذ المرحلة R1.4b — بناء طبقة `TradeManagement`. أنشئ مجلّدًا
> جديدًا `TradeManagement/` فيه أربعة ملفّات:
> `FalconTradeEngineContract.mqh` (الـ enum `ENUM_FALCON_TM_ACTION`،
> البُنى `FalconManagedPositionContext` و`FalconTradeDecision`،
> الواجهة المجرّدة `CFalconTradeEngine` بدالّتَي `EngineId` و
> `Evaluate`)؛ `FalconNoOpProbeEngine.mqh` (`CFalconNoOpProbeEngine`
> يُرجِع دائمًا `FALCON_TM_NO_ACTION` + instance عامّ)؛
> `FalconTradeManagementCoordinator.mqh` (`CFalconTradeManagement
> Coordinator`: سجلّ محرّكات، `RegisterEngine`، `EvaluateOnNewBar`
> الذي يمرّ على مراكز البروكر للـ EA لكلّ شمعة M5 مغلقة ويبني
> السياق من حالة البروكر ويستدعي المحرّكات ويكتب تقرير التدقيق +
> instance عامّ)؛ `FalconTradeManagementInputs.mqh` (مدخلان:
> `Enable_TradeManagement`، `TradeManagement_DiagReport`). صِل
> الملفّات عبر `#include` بجوار S01، سجّل محرّك no-op في `OnInit`،
> واستدعِ `EvaluateOnNewBar` في `OnTick` مَبوَّبًا بـ
> `Enable_TradeManagement`. عند `TradeManagement_DiagReport` اكتب
> `TradeManagementCoordinatorAudit` (صفّ لكلّ تقييم محرّك لكلّ
> مركز لكلّ شمعة مغلقة). حدّث `EA_VERSION_TAG` إلى `R1_4b`، وسم
> البناء `TradeManagementCoordinatorSpine`.
> **لا تبنِ أيّ منطق محرّك (لا حماية/runner/partial/ratchet/
> early-exit) — المحرّك الوحيد no-op. المنسّق لا يُصدر أيّ
> OrderSend/modify/close في 2b — مراقِبٌ فقط. لا تمسّ
> `Risk/FalconRiskLifecycleProcessor.mqh` ولا سلسلة Apply* ولا
> كود التنفيذ ولا أيّ ملفّ استراتيجيّة. مع `Enable_TradeManagement
> = false` صفر تغيير سلوك — `BrokerActualNetUSD` يبقى 321.92.**
> ابنِ (F7، 0 أخطاء)، نفّذ اختبار أ (المنسّق مُطفأ — يجب أن يبقى
> `BrokerActualNetUSD = 321.92`) واختبار ب (المنسّق مُشغَّل،
> مرّتين للحتميّة — يجب أن يبقى `BrokerActualNetUSD = 321.92` وأن
> يظهر تقرير التدقيق بكلّ القرارات `NO_ACTION`)، وأبلِغ بالنتائج
> والتقارير. سجّل الأفكار الثلاثة في `Docs/Ideas_Backlog.md`، راجع
> لوحة Problems، اكتب `Docs/ReviewNotes/R1_4b_Review_Notes.md`.
> commit واحد. بعد الانتهاء أكّد `git diff --stat`.
