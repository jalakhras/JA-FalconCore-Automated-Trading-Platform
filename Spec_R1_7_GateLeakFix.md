# مواصفة R1.7 — إصلاح تسرّب الـ Gate في الطبقة الورقيّة

> **النوع:** إصلاح مرحلة (تغيير كود + بناء + تشغيلَا تحقّق).
> **الإصدار:** `EA_VERSION_TAG` يُرفَع: `R1_6a` ⇒ **`R1_7`**.
>           `Build` يصير: `GateLeakFix`.
> **يسبقها:** `Exploration_R1_7_GateLeakAudit.md` (٣ ملفّات، ~٥-١٥ سطرًا).
> **يُغلق:** Defect #4 و#6 من قائمة Problems.

---

## ١. الهدف

جعل المفاتيح المُعلَنة تطفئ ما تدّعي إطفاءه — فعلًا. وإنتاج **الـ baseline
العاري المرجعيّ الجديد**: تشغيلٌ بإعدادٍ كلُّ مفاتيحه OFF يُنتج
`ProtectionActivatedTrades = 0` و`RunnerActivatedTrades = 0` و
`ProtectionNetUSD == RawTradeUSD` لكلّ صفقة. هذا الـ baseline يُتقاعِد رقم
42.60 رسميًّا.

---

## ٢. القرارات التصميميّة المُعتمَدة

| القرار | المُعتمَد |
|---|---|
| دلالة OFF | **تجاوزٌ كامل** — لا يُستدعى Apply #5/#6 إطلاقًا. |
| التراتب | **متراتبان** — `Enable_TradeManagement` مظلّة، `Enable_S01_Protection` تخصيصيّ داخلها. |
| إصلاح #4 | **نعم** — يُدمج في R1.7 نطاقًا. |

---

## ٣. القيود الصارمة

- لا تغييرٌ خارج الملفّات الأربعة المُحدَّدة في §٤. أيّ ملفٍّ يُمسّ خارجها
  ⇒ خروجٌ عن النطاق ⇒ يُلغى.
- لا إضافة مفاتيحَ جديدة. العمل بالموجود.
- لا تغيير لمنطق Apply #5 أو Apply #6 الداخليّ — الإصلاح في موضع
  **الاستدعاء** فقط (call-site guarding)، أنظف للمراجعة.
- لا مسٌّ لسلسلة الـ `Apply*` ولا ترتيبها (#3,#4,#5,#6,#7,#8,#10,#9,#1,#2,#11,#12).
- لا مسٌّ لمنطق البروكر أو Risk/emergency.
- لا commit حتى تنجح التشغيلات التحقّقيّة في §٦.

---

## ٤. التغييرات الكوديّة الدقيقة

### تغيير ١ — حارس Apply #5 و#6 (الجذر الرئيس)

**ملفّ:** `Risk/FalconRiskLifecycleProcessor.mqh`
**موضع:** السطران `1629-1630` داخل `ApplyTradeLifecycleChain`.

**قبل:**
```mqh
   ApplyPaperRuntimeSmartSLProtectionApplication(record);
   ApplyPaperRuntimeRunnerApplication(record);
```

**بعد:**
```mqh
   if(Enable_TradeManagement)
   {
      if(Enable_S01_Protection)
         ApplyPaperRuntimeSmartSLProtectionApplication(record);
      ApplyPaperRuntimeRunnerApplication(record);
   }
```

**ملاحظات:**
- `ApplyPaperRuntimeRunnerApplication` تُستدعى تحت `TM` حتى عند
  `Protection=false`: ستخرج فورًا داخليًّا (شرطها `record.paper_protection_activated`
  يبقى `false` عند تجاوز Apply #5). هذا أرخص ميكانيكيًّا وأنظف معماريًّا.
- المفاتيح تُقرأ من نطاق `input` العامّ — لا تمرير عبر معامل.
- إن لم يكن `Enable_TradeManagement` و`Enable_S01_Protection` متاحَين
  في scope الدالّة، تأكَّد من `#include` المناسب أعلى الملفّ (الإعلانات في
  `TradeManagement/FalconTradeManagementInputs.mqh`).

### تغيير ٢ — إنهاء عقم `EnableStrategy_FvgMicroRetest` في الـ Registry

**ملفّ:** `Router/FalconStrategyRegistry.mqh`
**موضع:** السطر 72.

**قبل:**
```mqh
   AddEntry("FVG_MICRO_RETEST", "FVG Micro Retest Engine", "SCALP.FVG_MICRO",
            FALCON_STRATEGY_GROUP_CORE, (EnableStrategy_FvgMicroRetest || EnableFvgMicroRuntimePipelineRefresh),
            FALCON_ENGINE_HEALTH_CORE_WINNER, FALCON_ENGINE_SHADOW,
```

**بعد:**
```mqh
   AddEntry("FVG_MICRO_RETEST", "FVG Micro Retest Engine", "SCALP.FVG_MICRO",
            FALCON_STRATEGY_GROUP_CORE, EnableStrategy_FvgMicroRetest,
            FALCON_ENGINE_HEALTH_CORE_WINNER, FALCON_ENGINE_SHADOW,
```

### تغيير ٣ — حارس Legacy Shadow Pipeline

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** السطر 5806 داخل `FalconRunFvgMicroRuntimeShadowPipeline`.

**قبل:**
```mq5
   if(!EnableFvgMicroRuntimePipelineRefresh)
      return;
```

**بعد:**
```mq5
   if(!EnableStrategy_FvgMicroRetest)
      return;
```

### تغيير ٤ — رفع الإصدار

**ملفّ:** الملفّ الذي يحوي `EA_VERSION_TAG` (راجِع `Constants` أو `mq5`).

- `EA_VERSION_TAG`: `R1_6a` ⇒ `R1_7`
- `Build`: `DiagnosticReportCleanup` ⇒ `GateLeakFix`

### `EnableFvgMicroRuntimePipelineRefresh` (الـ #define)

**لا يُحذف**. يبقى كثابتٍ بنيويّ في `Router/FalconRouterInputs.mqh:16` (سببه
التاريخيّ في R0.5 محفوظ). لم يَعُد يُستعمل بعد التغييرَين ٢ و٣ — يصير
خاملًا. حذفه يُؤجَّل لمرحلة تنظيفٍ لاحقة (Backlog).

---

## ٥. بروتوكول العمل

1. اقرأ المواصفة كاملةً (هذا الملفّ).
2. طبّق التغييرات الأربعة في §٤ بالضبط — لا توسيع، لا اقتراحات إضافيّة.
3. إعادة بناءٍ صريحة (F7). تأكَّد من إصدار التقارير = `R1_7 / GateLeakFix`.
4. **شغّل التشغيل التحقّقيّ الأوّل (Bare Baseline)** — §٦-أ.
5. **شغّل التشغيل التحقّقيّ الثاني (Sanity ON)** — §٦-ب.
6. ارفع الـ Summaries للمراجعة. **لا commit حتى التحقّق.**
7. بعد قبول النتائج: نفّذ commit واحدًا بنصٍّ من §٧.

---

## ٦. التشغيلات التحقّقيّة

### أ. Bare Baseline (الجوهر)

**الإعداد:** نفس إعداد إعادة اختبار R1.6a (الذي أعطى 1609.36)، لكن
بإضافة `EnableStrategy_FvgMicroRetest = false` فعلًا مُحترَمًا الآن:

| المدخل | القيمة |
|---|---|
| الرمز / الإطار / النافذة | US100_Spot / M5 / 2026.04.01→2026.04.30 |
| Initial Deposit / Leverage | 200 / 1:100 |
| `Enable_S01_Harness` | true |
| `S01_RealExecution` / `EnableRealExecution` | true / true |
| `S01_StopBuffer` / `S01_TargetRMultiple` | 30 / 2.0 |
| **`Enable_TradeManagement`** | **false** |
| **`Enable_S01_Protection`** | **false** |
| **`EnableStrategy_FvgMicroRetest`** | **false** |
| `Enable_S00_FvgScalp` / `S00_RealExecution` | false / false |
| `EnableVirtualTrailingBridge` | false |
| `UseFixedLot` / `FixedLotSize` | true / 0.01 |
| `UseDailyLossLimit` | false |

**معايير القبول (يجب أن تتحقّق كلّها):**

| المقياس | المطلوب |
|---|---|
| `ProtectionActivatedTrades` | **= 0** بالضبط |
| `RunnerActivatedTrades` | **= 0** بالضبط |
| `ProtectionNetUSD == RawTradeUSD` لكلّ صفقة في `TradeLifecycle` | **= صفر اختلاف** |
| `RunnerNetUSD == RawTradeUSD` لكلّ صفقة | **= صفر اختلاف** |
| `BrokerActualNetUSD` | يقترب من 321.92 (jitter tick ضمن ~1%) — لم يكن إلّا S01 على البروكر أصلًا |

**ملاحظة مُتوقَّعة — وليست عيبًا:**
- **`TotalTrades` ستنخفض كثيرًا** عن 1146. السبب: legacy shadow توقّفت
  عن توليد صفقاتٍ ظلّيّة كانت تُسجَّل ضمن العدّ. الباقي = صفقات S01
  الحقيقيّة فقط.
- **`RawNetUSD` و`FinalWorkingNetUSD` ستختلف** عن 1233.88 — لنفس السبب.
  العدد الجديد هو **الـ baseline العاري المرجعيّ** للمشروع من الآن.
- احفظ هذا الـ Summary وملفّ `.set` المناظر — هما المرجع.

### ب. Sanity ON (تأكيد عدم كسر المحرّكات)

**الإعداد:** كما في (أ)، إلّا أن:
- `Enable_TradeManagement` = **true**
- `Enable_S01_Protection` = **true**
- `EnableStrategy_FvgMicroRetest` يبقى false.

**معايير القبول:**

| المقياس | المطلوب |
|---|---|
| `ProtectionActivatedTrades` | **> 0** (يثبت أن Apply #5 يشتغل عند ON) |
| `RunnerActivatedTrades` | **> 0** أو ≥ 0 (Runner يحتاج تحقّق شروطٍ أخرى) |
| `BrokerActualNetUSD` | ≈ نفس قيمة (أ) — تعديل البروكر لم يكن يحدث في الـ harness أصلًا |
| `TotalTrades` | ≈ نفس قيمة (أ) — نفس الصفقات، تختلف الطبقة الورقيّة فقط |

**فشل أيّ معيار** ⇒ R1.7 غير مكتمل. توقّف، أرسل النتائج، نُشخّص.

---

## ٧. الـ commit (بعد التحقّق فقط)

- الفرع: `refactor`.
- المحتوى: التغييرات الأربعة في §٤ فقط.
- النصّ المقترح:

  ```
  R1.7 — إصلاح تسرّب الـ Gate في الطبقة الورقيّة

  - حارس Apply #5/#6 في ApplyTradeLifecycleChain:
    Enable_TradeManagement (مظلّة) + Enable_S01_Protection.
  - EnableStrategy_FvgMicroRetest يحرس فعليًّا الـ Registry
    والـ Legacy Shadow Pipeline.
  - يُغلق Defect #4 و#6.
  - الـ baseline العاري المرجعيّ الجديد مُنتَج ومحفوظ —
    يتقاعد رقم 42.60.

  EA_VERSION_TAG: R1_6a → R1_7
  Build: DiagnosticReportCleanup → GateLeakFix
  ```

- **commit واحد فقط. توقّف بعده. لا commit ثانٍ لـ logs أو غيره.**

---

## ٨. بروتوكول الإغلاق

- **Problems:** يُغلق Defect #4 و#6 (وضعهما ⇒ مُحلَّل بـ R1.7).
- **Review Notes:** ينشأ `Docs/ReviewNotes/R1_7_Review_Notes.md` يحوي
  الـ Summaries المرجعيّة، ملفّات `.set`، وتاريخ الإصلاح.
- **Ideas Backlog:** أُضِف:
  - حذف الـ `#define EnableFvgMicroRuntimePipelineRefresh` بعد التأكّد من
    عدم استعماله في أيّ موضعٍ آخر (تنظيف لاحق).
  - إعادة قراءة الـ ReviewNotes في R0.5 لفهم السبب التاريخيّ للـ `#define`.
- **ملفّ ذاكرة المشروع:** إصدار جديد `R1_7_closed`:
  - §٣: آخر commit مستقرّ = R1.7. الخطوة التالية = R1.8 (أمانة العدّادات)
    أو R2.0 (استراتيجيّة) بحسب المخطّط الشامل.
  - §٤: R1.7 ⇒ ✓ مُغلقة.
  - §٦: الأرقام المرجعيّة — يُضاف الـ baseline العاري الجديد. الـ 42.60
    يُنقل لقسم «أرقام تاريخيّة متقاعدة».
  - §٧: Problems — #4 و#6 يُنقلان لقسم «مُغلقة».

---

## ٩. ملحق — Prompt لـ Claude Code

```
السياق: نحن على فرع `refactor`، آخر commit R1.6a (24b19ed). يجب
أن يكون هذا تنفيذ R1.7 — تغييراتٌ كوديّةٌ صغيرةٌ ودقيقة + بناء +
ثمّ توقّف للتشغيل التحقّقيّ.

التعليمات بهذا الترتيب الحرفيّ:

١. اقرأ كاملًا الملفّ المرفق `Spec_R1_7_GateLeakFix.md`. هو المرجع
   الوحيد لهذا العمل. كلّ ما يلي هنا تشغيليّ، ليس بديلًا عن قراءته.

٢. التزم بـ §٣ القيود الصارمة و§٤ التغييرات الكوديّة الدقيقة. لا
   تتجاوز ولا تضيف.

٣. طبّق التغييرات الأربعة في §٤ بالضبط — file:line و before/after
   كما هو موصوف. تحقّق من `#include` المناسب لاستيراد إعلانات
   المفاتيح في `Risk/FalconRiskLifecycleProcessor.mqh` إن لزم.

٤. ارفع `EA_VERSION_TAG` و`Build` كما في §٤ تغيير ٤.

٥. أعد البناء (F7). إن فشل البناء: أوقف، أظهر الخطأ، لا تحاول
   إصلاحًا جانبيًّا — أرسل الخطأ.

٦. **توقّف عند هذه النقطة.** لا commit. لا تشغيلات. أظهر:
   - git status
   - git diff --stat
   - تأكيد نجاح البناء + إصدار التقارير الجديد.

سيُجري المشغّل التشغيلَين التحقّقيَّين (§٦-أ و٦-ب) في الـ Strategy
Tester يدويًّا، ويرسل النتائج. **لا تتقدّم خطوةً واحدةً بعد البناء.**

عند أيّ تعارضٍ بين تعليماتي والمواصفة: المواصفة تحكم.
عند أيّ غموض: ارفعه واسأل، لا تتصرّف من تلقاء نفسك.
```
