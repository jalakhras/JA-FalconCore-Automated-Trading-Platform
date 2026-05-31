# Exploration R1.7 — Gate Leak Audit (Paper Layer)

> **النوع:** استكشاف قراءة-فقط — لا اقتراحات إصلاح في الكود.
> **الإصدار:** قبل R1.7 (لا رفع `EA_VERSION_TAG`).
> **التاريخ:** 2026-05-31.
> **الفرع:** `refactor`.
> **آخر commit:** `24b19ed` (R1.6a — تنظيف نداءات التقارير التشخيصيّة المنتهية).
> **مرجع المواصفة:** `Spec_R1_7_Exploration_GateLeakAudit.md`.

---

## ملخّص تنفيذيّ (سطر واحد لكلّ محور)

| المحور | المرصود |
|---|---|
| ١. عدّاد `protection_activated_trades` | يُزاد في `Reporting/FalconReportWriter.mqh:4678` بشرط `record.paper_protection_activated` فقط — **لا قراءة لأيّ مفتاح**. |
| ٢. عدّاد `runner_activated_trades` | يُزاد في `Reporting/FalconReportWriter.mqh:4705` بشرط `record.paper_runner_activated` فقط — **لا قراءة لأيّ مفتاح**. |
| ٣. حقل `paper_protection_net_usd` | يُسنَّد داخل `Risk/FalconRiskLifecycleProcessor.mqh::ApplyPaperRuntimeSmartSLProtectionApplication` (Apply #5) — تُستدعى **بلا حارس** في سلسلة `ApplyTradeLifecycleChain` `:1629`. |
| ٤. حقل `paper_runner_net_usd` | يُسنَّد داخل `Risk/FalconRiskLifecycleProcessor.mqh::ApplyPaperRuntimeRunnerApplication` (Apply #6) — تُستدعى **بلا حارس** في `:1630`. |
| ٥. المفاتيح الثلاثة | `Enable_S01_Protection` يحرس **تسجيلَ المحرّك الحيّ فقط** (`mq5:5911`). `Enable_TradeManagement` يحرس **مسار المنسّق الحيّ فقط** (`mq5:6075`). `EnableStrategy_FvgMicroRetest` يُقرأ في موضعٍ واحدٍ مع OR على `#define ...=true` — قراءته **عقيمة فعليًّا**. **لا أحدٌ منهم يحرس الطبقة الورقيّة في Apply #5/#6.** |
| ٦. محاكاة Legacy الظلّيّة | تجري داخل `FalconRunFvgMicroRuntimeShadowPipeline` بحارس داخليّ على `EnableFvgMicroRuntimePipelineRefresh` (وهو `#define = true` ثابت). `EnableStrategy_FvgMicroRetest` غير مقروء هنا أصلًا. |

**الكتلة الواحدة المسؤولة عن نمط #6 (تشغيل الطبقة الورقيّة بصرف
النظر عن المفتاحين):** سطرَا `:1629` و`:1630` في
`Risk/FalconRiskLifecycleProcessor.mqh` — استدعاء غير محروس داخل
سلسلة `ApplyTradeLifecycleChain`. هذه السلسلة تُستدعى لكلّ صفقة
مغلقة عبر `Reporting/FalconReportWriter.mqh:3864`، فتشتغل لكلّ
صفقة من كلّ مسار (Legacy + S00 + S01).

---

## المحور الأوّل — عدّاد `paper_protection_activated_trades`

### ١. موضع الزيادة

`Reporting/FalconReportWriter.mqh:4675-4679`:

```mqh
      if(record.paper_protection_activated)
      {
         m_totals.paper_protection_eligible_trades++;
         m_totals.paper_protection_activated_trades++;
      }
```

### ٢. الشرط الذي يسبق الزيادة

`if(record.paper_protection_activated)` — قراءةُ حقلٍ على السجلّ،
**لا قراءة لأيّ `input`**.

### ٣. هل الشرط يقرأ المفاتيح؟

**لا.** السطر `:4675` يقرأ `record.paper_protection_activated` فقط.
الكتلة المحيطة (`:4667-4720`) داخل دالّة `RegisterClosedTrade` —
لا تختبر أيّ من المفاتيح الثلاثة.

### ٤. ما الذي يسبق هذه النقطة في سلسلة الاستدعاء؟

`record.paper_protection_activated` يُسنَّد داخل
`Risk/FalconRiskLifecycleProcessor.mqh::ApplyPaperRuntimeSmartSLProtectionApplication`
(Apply #5) — يصير `true` عند تحقّق شرطين فقط: (أ) المرّر يجتاز
guard (`record.paper_guard_status == "PASSED"`)، (ب)
`barpath_stats.tp1_touched`. لا قراءة لـ `input` داخل الدالّة (تأكَّدتُ
بقراءة `Risk/FalconRiskLifecycleProcessor.mqh:800-875`).

سلسلة الاستدعاء:
`mq5:6036` ⇒ `g_report_writer.RegisterClosedTrade(record)` ⇒
`Reporting/FalconReportWriter.mqh:3864` ⇒
`g_risk_lifecycle_processor.ApplyTradeLifecycleChain(record, m_totals)` ⇒
`Risk/FalconRiskLifecycleProcessor.mqh:1629` ⇒
`ApplyPaperRuntimeSmartSLProtectionApplication(record)` — **بلا حارس
في أيّ حلقة**.

**خلاصة:** العدّاد يُزاد لكلّ صفقة مغلقة جاءت من أيّ مسار (Legacy /
S00 / S01) متى انطبق الشرط الورقيّ، دون قراءة أيّ مفتاح إطفاء.

---

## المحور الثاني — عدّاد `paper_runner_activated_trades`

### ١. موضع الزيادة

`Reporting/FalconReportWriter.mqh:4703-4707`:

```mqh
      if(record.paper_runner_activated)
      {
         m_totals.paper_runner_activated_trades++;
         m_totals.paper_runner_exit_trades++;
      }
```

### ٢. الشرط الذي يسبق الزيادة

`if(record.paper_runner_activated)` — قراءةُ حقلٍ على السجلّ، **لا قراءة
لأيّ `input`**.

### ٣. هل الشرط يقرأ المفاتيح؟

**لا.** نفس الكتلة (`:4694-4720`) لا تختبر أيّ من المفاتيح الثلاثة.

### ٤. ما الذي يسبق هذه النقطة؟

`record.paper_runner_activated` يُسنَّد داخل
`Risk/FalconRiskLifecycleProcessor.mqh::ApplyPaperRuntimeRunnerApplication`
(Apply #6) `:924` — يصير `true` عند: (أ) `paper_protection_activated`،
(ب) `paper_virtual_sl_changed`، (ج) `tp2_touched` مع
`max_favorable_points > protected_base_points`. لا قراءة لـ `input`
داخل الدالّة (`:877-953`).

سلسلة الاستدعاء — نفس مسار المحور الأوّل، ينتهي عند:
`Risk/FalconRiskLifecycleProcessor.mqh:1630` ⇒
`ApplyPaperRuntimeRunnerApplication(record)` — **بلا حارس**.

---

## المحور الثالث — حقل `record.paper_protection_net_usd`

### ١. مواضع الإسناد

ثلاثة مواضع للإسناد، كلّها في `Risk/FalconRiskLifecycleProcessor.mqh`،
وكلّها داخل دوال Apply* تُستدعى بلا حارس:

`Risk/FalconRiskLifecycleProcessor.mqh:570` (داخل
`FalconRefreshUsdMetricsForActiveLot`، حساب USD من النقاط):

```mqh
      record.paper_protection_net_usd = FalconEstimateUsdByRawPoints(record.paper_protection_net_index_points, active_lot, m_symbol_context);
```

`Risk/FalconRiskLifecycleProcessor.mqh:811` (تهيئة في بداية
Apply #5 — نسخة من `paper_guard_net_usd`):

```mqh
      record.paper_protection_net_index_points = record.paper_guard_net_index_points;
      record.paper_protection_net_usd = record.paper_guard_net_usd;
```

`Risk/FalconRiskLifecycleProcessor.mqh:869` (إسنادٌ فعليّ حين تضرب
الحماية الورقيّة):

```mqh
         record.paper_virtual_sl_hit = true;
         record.paper_exit_reason = "PAPER_VIRTUAL_SL_HIT";
         record.paper_protection_net_index_points = protected_points;
         record.paper_protection_net_usd = FalconEstimateUsdByRawPoints(protected_points, record.lot_size, m_symbol_context);
```

كذلك تهيئة دفاعيّة في `mq5:5610` (إعداد سجلّ ابتدائيّ — قيمة 0.0
عند تهيئة `lifecycle_record_on_init`).

### ٢. ما الذي يحسبه

ليس مجرّد نسخٍ من `raw_trade_usd`. الحساب يبدأ من نسخةٍ من
`paper_guard_net_usd` (`:811`)، ثمّ تُكتب فوقها قيمةٌ جديدة في حال
ضرب الـ virtual SL الورقيّ (`:869`) — مأخوذة من
`protected_points = MathMax(0.0, tp1_points * 0.25)` (أو
`tp1_points` نفسها لـ TP2_PROOF). أي: **منطق حماية ورقيّ فعليّ**
(تحديد نقطة حماية، فحص هل ضربها مسار البار، تعديل الصافي).

### ٣. هل هناك حارسٌ على مفتاح يسبق الإسناد؟

**لا.** الدالّة `ApplyPaperRuntimeSmartSLProtectionApplication` تُستدعى
في `:1629` بلا حارس. الشروط الداخليّة (`:813`، `:826`) تقرأ حقول
السجلّ فقط (`paper_guard_status`, `barpath_stats.tp1_touched`)، لا
المفاتيح.

### ٤. سمة الـ 115 صفقة المُعدَّلة (Prot OFF)

من سياق الكود (`:864-870`): الإسناد الفعليّ يحدث متى:
- `protection_hit == true` (أي إمّا `TP2_PROOF + returned_to_loss_after_tp2`
  أو `TP1_PROOF + returned_to_loss_after_tp1`)،
- **و** `protected_points > record.paper_guard_net_index_points`.

أي السمة المشتركة هي: «صفقات اجتازت guard، لمست TP1، ثمّ عادت إلى
الخسارة بعد TP1/TP2، وكان مستوى الحماية المُحتسَب أعلى من ربح الـ guard».
هذا تفسيرٌ منطقيٌّ من الكود — العدد الدقيق (115) سمتُه هو الحقل
`paper_virtual_sl_hit = true` في `TradeLifecycle.csv`.

---

## المحور الرابع — حقل `record.paper_runner_net_usd`

### ١. مواضع الإسناد

ثلاثة، كلّها في `Risk/FalconRiskLifecycleProcessor.mqh`:

`:571` (داخل `FalconRefreshUsdMetricsForActiveLot`):

```mqh
      record.paper_runner_net_usd = FalconEstimateUsdByRawPoints(record.paper_runner_net_index_points, active_lot, m_symbol_context);
```

`:886` (تهيئة Apply #6 — نسخة من `paper_protection_net_usd`):

```mqh
      record.paper_runner_net_index_points = record.paper_protection_net_index_points;
      record.paper_runner_net_usd = record.paper_protection_net_usd;
```

`:944-946` (إسناد فعليّ حين يلتقط الـ runner امتدادًا بعد TP2):

```mqh
         record.paper_runner_net_index_points = captured_points;
         record.paper_runner_net_usd = FalconEstimateUsdByRawPoints(captured_points, record.lot_size, m_symbol_context);
         record.paper_runner_exit_reason = (record.paper_runner_state == "MOON" ? "PAPER_MOON_RUNNER_EXIT" : "PAPER_RUNNER_TRAIL_EXIT");
```

### ٢. ما الذي يحسبه

ليس نسخًا. هو حسابُ ربحٍ مُحتسَبٍ من امتداد ما بعد TP2:
`captured_points = tp2_points + (extension_after_tp2 * capture_ratio)`
حيث `capture_ratio = 0.50` لـ MOON و`0.35` خلاف ذلك (`:928-933`).
بعدها يُحسب الـ USD عبر `FalconEstimateUsdByRawPoints`. **منطق runner
ورقيّ فعليّ.**

### ٣. هل هناك حارسٌ على مفتاح؟

**لا.** الدالّة تُستدعى من `:1630` بلا حارس. الشروط الداخليّة
(`:889-896`، `:917`) تقرأ حقول السجلّ فقط
(`paper_guard_status`, `paper_protection_activated`,
`paper_virtual_sl_changed`, `barpath_stats.tp2_touched`).

### ٤. سمة الـ 214 صفقة المُعدَّلة (Prot OFF)

من الكود (`:917-942`): الإسناد الفعليّ يحدث متى:
- guard مُجتاز،
- `paper_protection_activated && paper_virtual_sl_changed` (شرطُ
  «حماية مكتسَبة»)،
- `barpath_stats.tp2_touched`،
- `max_favorable_points > protected_base_points`،
- **و** `captured_points > paper_protection_net_index_points`
  (`record.paper_runner_additional_points > 0.0` عند `:942`).

السمة المشتركة: «صفقات لمست TP2 وامتدّت بعدها، فالتقط الـ runner
الورقيّ امتدادًا فوق مستوى الحماية». الحقل المُميِّز في
`TradeLifecycle.csv`: `paper_runner_activated = true` مع
`paper_runner_additional_points > 0.0`.

---

## المحور الخامس — قراءة المفاتيح الثلاثة في الكود

### `Enable_S01_Protection`

١. **عدد قراءات الكود** (استبعاد التعليقات والوثائق):
   **١ موضع** + إعلانٌ واحد.
   - الإعلان: `TradeManagement/FalconTradeManagementInputs.mqh:19`
     (`input bool Enable_S01_Protection = false`).
   - القراءة: `JA_FalconCore_Automated_Trading_Platform.mq5:5911`:

     ```mq5
        if(Enable_S01_Protection)
           g_trade_management_coordinator.RegisterEngine(GetPointer(g_proof_protection_engine));
     ```

٢. **ما يحرسه فعلًا:** تسجيل محرّك الحماية الحيّ
(`g_proof_protection_engine`) في منسّق إدارة الصفقات. حين OFF،
المحرّك لا يُسجَّل، فلا يُصدر أيّ `TRADE_ACTION_SLTP` حقيقيّ على
البروكر. وهذا متوافق مع المرصود في الجدول: `BrokerActualNetUSD` لا
يتغيّر بين Prot ON/OFF (≈0.24$ فرق ضئيل).

٣. **ما يدّعي حراسته ولا يحرسه:** اسم المفتاح يوحي بأنّه يطفئ «طبقة
الحماية» ككلّ. عمليًّا — **لا يلمس الطبقة الورقيّة** في Apply #5
(`Risk/FalconRiskLifecycleProcessor.mqh:1629`). لذا
`ProtectionActivated = 662` ثابت بين التشغيلَين.

### `Enable_TradeManagement`

١. **عدد قراءات الكود:** **١ موضع** + إعلانٌ واحد.
   - الإعلان: `TradeManagement/FalconTradeManagementInputs.mqh:12`
     (`input bool Enable_TradeManagement = false`).
   - القراءة: `JA_FalconCore_Automated_Trading_Platform.mq5:6075`:

     ```mq5
        if(Enable_TradeManagement)
           g_trade_management_coordinator.EvaluateOnNewBar(g_market_context);
     ```

٢. **ما يحرسه فعلًا:** نداء `EvaluateOnNewBar` على منسّق إدارة
الصفقات في كلّ تك (يُترجَم إلى تنفيذ المحرّكات المسجَّلة بلا
broker writes حين OFF). كذلك هذا متوافق مع استقرار البروكر بين
التشغيلَين.

٣. **ما يدّعي حراسته ولا يحرسه:** اسمُه يوحي بأنّه «يفعّل/يُطفئ
إدارة الصفقات». عمليًّا — **لا يحرس** الطبقة الورقيّة في
`ApplyTradeLifecycleChain` (Apply #5 و#6). لذلك تشغيلَا أبريل Prot
ON/OFF أعطيا نفس الـ `ProtectionActivatedTrades = 662`
وعددي Runner متقاربَين (188/196).

### `EnableStrategy_FvgMicroRetest`

١. **عدد قراءات الكود:** **١ موضع** + إعلانٌ واحد.
   - الإعلان: `JA_FalconCore_Automated_Trading_Platform.mq5:1846`
     (`input bool EnableStrategy_FvgMicroRetest = true`).
   - القراءة: `Router/FalconStrategyRegistry.mqh:72`:

     ```mqh
        AddEntry("FVG_MICRO_RETEST", "FVG Micro Retest Engine", "SCALP.FVG_MICRO",
                 FALCON_STRATEGY_GROUP_CORE, (EnableStrategy_FvgMicroRetest || EnableFvgMicroRuntimePipelineRefresh),
                 FALCON_ENGINE_HEALTH_CORE_WINNER, FALCON_ENGINE_SHADOW,
     ```

   حيث `EnableFvgMicroRuntimePipelineRefresh` ثابتٌ مُعرَّفٌ:
   `Router/FalconRouterInputs.mqh:16`:

     ```mqh
        #define EnableFvgMicroRuntimePipelineRefresh                  true
     ```

٢. **ما يحرسه فعلًا:** **لا شيء.** قيمة الـ OR محسوبة وقت
المعالجة المسبقة (`true || X = true`)، فبصرف النظر عن المفتاح
الاستراتيجيّة مسجَّلة بـ `enabled = true`.

٣. **ما يدّعي حراسته ولا يحرسه:** اسمُه يوحي بأنّه يُفعّل/يُطفئ
استراتيجيّة `FVG_MICRO_RETEST`. عمليًّا — **عقيمٌ كليًّا**: التسجيل
يحدث بسبب الـ `#define` الثابت، ومسارُ المحاكاة الظلّيّة
(`FalconRunFvgMicroRuntimeShadowPipeline`) لا يقرأ هذا المفتاح
أصلًا (يقرأ الـ `#define` نفسه — انظر المحور السادس). هذا تطابقٌ
حرفيّ مع Problem #4 المسجَّل سابقًا.

---

## المحور السادس — محاكاة Legacy الظلّيّة

### ١. أين تشتغل؟

`JA_FalconCore_Automated_Trading_Platform.mq5:5804`:

```mq5
   void FalconRunFvgMicroRuntimeShadowPipeline(const string trigger)
   {
      if(!EnableFvgMicroRuntimePipelineRefresh)
         return;
      ...
```

الدالّة تُحدّث `g_fvg_micro_detector_stub` ثمّ `g_fvg_micro_candidate_builder`
(`:5820-5828`)؛ التشغيل الأطول يستمرّ في الأسطر التالية (لم أعرضها
كلّها — أكثر من 5 أسطر).

### ٢. من أين تُستدعى؟

من `OnTick` مباشرة عند `JA_FalconCore_Automated_Trading_Platform.mq5:6018-6022`:

```mq5
   if(!S00_RealExecution)
   {
      FalconRunFvgMicroRuntimeShadowPipeline("OnTick_FvgRuntimePipeline");
      ...
```

**ليست من المنسّق**؛ من OnTick مباشرة. حارسها الخارجيّ الوحيد هو
`!S00_RealExecution` (افتراضيًّا `false`، فالكتلة تنفّذ).

### ٣. ما يحرسها (إن وُجد)؟

داخليًّا: `EnableFvgMicroRuntimePipelineRefresh` (`mq5:5806`). كما
تبيّن في المحور الخامس، هذا **`#define = true` ثابت** لا متغيّرًا
يقرؤه المشغّل. لذا الحارس **شكليّ** — لا يطفئ المحاكاة فعليًّا في
أيّ تشغيل حقيقيّ.

نتيجة: محاكاة Legacy الظلّيّة تشتغل لكلّ تك حتى لو ضبط المشغّل
`EnableStrategy_FvgMicroRetest = false`. الصفقات الظلّيّة التي
تنغلق تمرّ عبر `RegisterClosedTrade` (`mq5:6036`) ⇒
`ApplyTradeLifecycleChain` ⇒ تُعدِّل `ProtectionActivated`/`Runner*`
الورقيّين. هذا الجزء الثاني من نمط #6 (إلى جانب أنّ S01 نفسها
تُغذّي السلسلة ذاتها عند `Strategies/S01_Harness/S01_EntryLogic.mqh:133`).

---

## جدول الخلاصة

| الموضع | المعرّف | أين | يحرسه الآن | يجب أن يحرسه (موضوعيًّا، بحسب اسمه/نيّته الورقيّة) | الحارس المفقود |
|---|---|---|---|---|---|
| #1 | عدّاد `paper_protection_activated_trades` | `Reporting/FalconReportWriter.mqh:4675-4678` | حقل سجلّ فقط (`record.paper_protection_activated`) | المفتاح الذي يُفترض أن يطفئ الطبقة الورقيّة | لا حارس على مفتاحٍ يطفئ الطبقة الورقيّة (الأطر الموجودة `Enable_TradeManagement`/`Enable_S01_Protection` تحرس مسارَ الحيّ فقط) |
| #2 | عدّاد `paper_runner_activated_trades` | `Reporting/FalconReportWriter.mqh:4703-4706` | حقل سجلّ فقط (`record.paper_runner_activated`) | نفس ما سبق | نفس ما سبق |
| #3 | حقل `record.paper_protection_net_usd` | إسناد `Risk/FalconRiskLifecycleProcessor.mqh:570, 811, 869` ضمن Apply #5 | شروط داخليّة حقولَ سجلّ فقط | مفتاح كي يطفئ Apply #5 كاملةً | لا حارس على نداء `ApplyPaperRuntimeSmartSLProtectionApplication` في `:1629` |
| #4 | حقل `record.paper_runner_net_usd` | إسناد `Risk/FalconRiskLifecycleProcessor.mqh:571, 886, 944-945` ضمن Apply #6 | شروط داخليّة حقولَ سجلّ فقط | مفتاح كي يطفئ Apply #6 كاملةً | لا حارس على نداء `ApplyPaperRuntimeRunnerApplication` في `:1630` |
| #5 | `Enable_S01_Protection` | إعلانٌ في `TradeManagement/FalconTradeManagementInputs.mqh:19`، قراءةٌ واحدةٌ في `mq5:5911` | تسجيلَ محرّك الحماية الحيّ (broker writes) | الطبقة الورقيّة كذلك (بحسب اسمه ودلالته) | قراءةٌ ثانيةٌ تحرس استدعاء Apply #5 |
| #6 | `Enable_TradeManagement` | إعلانٌ في `TradeManagement/FalconTradeManagementInputs.mqh:12`، قراءةٌ واحدةٌ في `mq5:6075` | نداء `EvaluateOnNewBar` على المنسّق الحيّ | الطبقة الورقيّة كذلك | قراءةٌ ثانيةٌ تحرس استدعاءَي Apply #5 و#6 |
| #7 | `EnableStrategy_FvgMicroRetest` | إعلانٌ في `mq5:1846`، قراءةٌ واحدةٌ في `Router/FalconStrategyRegistry.mqh:72` | **لا شيء** (OR مع `#define = true` ثابت يجعل النتيجة `true` دائمًا) | تسجيل الاستراتيجيّة + مسار الـ runtime shadow pipeline | إزالة العقم: قراءةٌ غير عقيمة في الـ Registry + قراءةٌ في `mq5:5806` بدل الـ `#define` |
| #8 | محاكاة Legacy الظلّيّة `FalconRunFvgMicroRuntimeShadowPipeline` | تعريف `mq5:5804`، استدعاء `mq5:6022` | `!S00_RealExecution` خارجيًّا + `EnableFvgMicroRuntimePipelineRefresh` داخليًّا (ثابتٌ `true`) | مفتاحُ مشغّلٍ حقيقيّ يطفئ المحاكاة | تحويل الـ `#define` إلى `input` (أو حارس على `EnableStrategy_FvgMicroRetest`) |

---

## تقدير حجم الإصلاح

> **تنبيه نطاق:** التقدير وصفيٌّ فقط — لا يقترح إصلاحًا. التقدير
> أدناه يُجيب عن «كم موضعًا يحتاج حارسًا، وأين». كيفيّة الإصلاح
> (مفتاحٌ جديد؟ ربط بالمفاتيح القائمة؟ إعادة معنى الـ `#define`؟)
> قرارٌ يخصّ مواصفة R1.7، لا هذا الاستكشاف.

| الجبهة | عدد المواضع | الملفّات | التشتّت | تقدير الأسطر |
|---|---|---|---|---|
| طبقة Apply الورقيّة (#3, #4) | موضعا استدعاء (`:1629`, `:1630`) | `Risk/FalconRiskLifecycleProcessor.mqh` فقط | **مركَّز جدًّا** | حارسٌ واحدٌ فوق الاستدعاءَين (~٢-٤ أسطر) إن قُرّر استخدام مفتاحٍ واحدٍ موجود؛ أو ٢-٤ أسطر × مفتاحَين منفصلَين |
| `EnableStrategy_FvgMicroRetest` العقيم (#7) | قراءةٌ واحدة عقيمة | `Router/FalconStrategyRegistry.mqh:72` + سلوك `#define = true` في `Router/FalconRouterInputs.mqh:16` | **مركَّز** | إصلاح تعريف الـ OR + إعادة معنى الـ `#define` (~٢-٥ أسطر إجمالًا) |
| محاكاة Legacy الظلّيّة (#8) | حارسٌ شكليّ على `#define` | `JA_FalconCore_Automated_Trading_Platform.mq5:5749, 5806` | **مركَّز** | تغيير الحارس ليقرأ مفتاح المشغّل بدل الـ `#define` (~٢ سطر) |
| **الإجمالي** | **~٤ مواقع نداء/قراءة** | **٣ ملفّات** | **مركَّزٌ بدرجة عالية** | **تقديرٌ مبدئيّ: ٥-١٥ سطر إجماليّ** (بحسب القرار التصميميّ) |

**الاستنتاج العمليّ:** الإصلاح **ليس منتشرًا** — كلّ التسرّب يتمركز في
ثلاثة ملفّات (`Risk/FalconRiskLifecycleProcessor.mqh`،
`Router/FalconStrategyRegistry.mqh`،
`Router/FalconRouterInputs.mqh`، مع مَسٍّ خفيفٍ في
`JA_FalconCore_Automated_Trading_Platform.mq5`). كثافة المواضع
الفعليّة قليلة: استدعاءا Apply داخل سطرَين متجاورَين في السلسلة،
وقراءة OR واحدة في Registry، وحارس داخليّ واحد في pipeline.

---

## الغموض

١. **هل المقصود من «إطفاء الطبقة الورقيّة» إيقاف الحساب أم
   تصفير الحقول؟** اسم المفتاح `Enable_S01_Protection = false`
   اليوم لا يلمس الطبقة الورقيّة إطلاقًا (لا تصفير، لا تخطّي).
   هل ينوي المشغّل: (أ) عدم استدعاء Apply #5/#6 بتاتًا؟ أم
   (ب) استدعاؤها لكن إجبار `record.paper_protection_activated = false`
   على المخرج (تصفير الأثر مع إبقاء الحساب)؟ التفسيران يكتبان
   كودًا مختلفًا — تُحسم في مواصفة R1.7.

٢. **هل `Enable_TradeManagement` و`Enable_S01_Protection` ينبغي
   أن يكونا مفتاحَين مستقلَّين أم متراتبَين؟** `Enable_TradeManagement`
   يوحي بأنّه «المفتاح الأعمّ»، و`Enable_S01_Protection` تخصيصيّ.
   اليوم هما متعامدان وكلاهما يحرس مسارًا حيًّا مختلفًا. أيٌّ
   منهما (أو كليهما) ينبغي أن يحرس Apply الورقيّ؟ قرارٌ تصميميّ
   لا يُحسم بقراءة الكود.

٣. **هل `EnableStrategy_FvgMicroRetest` يجب أن يطفئ محاكاة Legacy
   الظلّيّة، أم أنّ الـ `#define = true` متعمَّد**؟ الحاصل تاريخيًّا
   (من ReviewNotes في R0.5): الـ `#define` كان لحاجة preprocessor
   ordering. لكنّ المعنى الدلاليّ غير واضح: هل المشغّل ينتظر
   مفتاحًا للإطفاء الفعليّ، أم أنّ المحاكاة الظلّيّة «دائمًا
   مُشغَّلة» قرارٌ سابق؟ تُحسم باستفسارٍ من المشغّل.

٤. **العدد الدقيق للصفقات المتأثّرة (115/214 في Prot OFF)**: لم
   أتحقّق من ذلك في الـ CSVs (تتطلّب قراءة تقارير في
   `C:\Users\jalak\AppData\Roaming\MetaQuotes\Terminal\Common\Files`،
   لم أصلها في هذا الاستكشاف). تفسير السمة المشتركة في المحاور
   ٣/٤ مأخوذٌ من الكود لا من البيانات — إن أراد المشغّل دليلًا
   من البيانات، يلزم مرحلة قراءة CSV منفصلة.

---

## بروتوكول الإغلاق (تذكير)

- العيبان #4 و#6 في ملفّ الذاكرة (`Project_Memory_R1_6a_closed.md`)
  ما زالا مفتوحَين — هذا الاستكشاف يُؤكّدهما بـ `file:line` ولا
  يُغلقهما.
- لا اقتراح إصلاح في الكود (التزامًا بـ §٣ و§٦ من المواصفة).
- لا تغيير على Risk/emergency أو سلسلة Apply* خارج توصيف حالة
  استدعاء #5 و#6 (التزامًا بقيد عدم توسيع النطاق).

— نهاية تقرير الاستكشاف —
