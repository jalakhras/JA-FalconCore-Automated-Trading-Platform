# مواصفة R1.7-amend — حارسٌ داخل الدالّة بعد التهيئة

> **النوع:** إصلاح مكمِّل لـ R1.7 (نفس الإصدار، نفس الـ Build، لا commit
> جديد بعد).
> **الإصدار:** يبقى `R1_7` / `GateLeakFix`. لا رفع.
> **يسبقه:** R1.7 الأصليّة (`Spec_R1_7_GateLeakFix.md`)، التشغيلات v2
> التي كشفت الخلل.
> **الـ working copy:** تغييرات R1.7 موجودة، لم تُنفَّذ commit بعد.

---

## ١. الهدف

تصحيح خطأ تصميميّ في R1.7: قرار «تجاوزٌ كامل» (Q1.أ) ترك حقول الطبقة
الورقيّة غير مُهيَّأة في Bare ⇒ تسرّب ذاكرة فاسدة ⇒ عدّادات وهميّة
و`FinalWorkingNetUSD` فلكيّ.

الحلّ: نقل الحارس من **موضع الاستدعاء** إلى **داخل الدالّة بعد التهيئة
الدفاعيّة** — التهيئة دائمًا تشتغل، المنطق محروس.

---

## ٢. السياق — ماذا أظهر تشغيل R1.7 الأوّل

| المقياس | Bare | ON |
|---|---|---|
| `ProtectionActivatedTrades` | **467** (يجب 0) | 2 |
| `RunnerActivatedTrades` | **467** (يجب 0) | 2 |
| `FinalWorkingNetUSD` | **5.38e+267** (ذاكرة فاسدة) | 17.53 ✓ |
| `BrokerActualNetUSD` | 275.97 | 275.97 |

السبب الجذريّ: `paper_protection_net_index_points` و`paper_runner_net_index_points`
يُهيَّآن في **أوّل Apply #5/#6** (`Risk:817, :892`). مع التجاوز، الحقول
تبقى ذاكرة عشوائيّة ⇒ `FalconRefreshUsdMetricsForActiveLot` يحسب منها
⇒ نواتج فاسدة. كذلك `paper_protection_activated` يُصفَّر في `Risk:812`
كأوّل عمل في Apply #5؛ مع التجاوز يبقى بقيمة ذاكرةٍ قد تُقرأ `true`.

---

## ٣. القرار التصميميّ المُصحَّح

**OFF يعني: التهيئة الدفاعيّة passthrough تشتغل، المنطق لا يشتغل.**

- مع TM=false أو Prot=false ⇒ Apply #5 يدخل، يُهيِّئ الحقول إلى قيم
  آمنة (نسخ من `paper_guard_*`)، ثمّ يخرج فورًا قبل المنطق.
- مع TM=true و Prot=true ⇒ Apply #5 يدخل، يُهيِّئ، **ويُكمل المنطق**.
- نفس الشيء لـ Apply #6 لكن تحت `TM` فقط (الـ runner لا يحتاج Prot
  منفصلًا — يعتمد على `paper_protection_activated` كوديًّا).

دلاليًّا أنظف من Q1.أ الأصليّة: «OFF = حياديّة كاملة passthrough»،
لا «OFF = تخطّي دالّة قد تترك حقولًا غير مُهيَّأة».

---

## ٤. القيود الصارمة

- لا تغيير على Apply #5 أو #6 **خارج إضافة سطر `if(!flag) return;`
  بعد كتلة التهيئة الدفاعيّة** مباشرةً.
- لا تعديل لمنطق الـ Apply الداخليّ.
- لا تغيير على `EA_VERSION_TAG` ولا `Build` — يبقيان `R1_7` /
  `GateLeakFix`. هذا تصحيحُ بناءٍ لا مرحلة جديدة.
- لا تغيير على Router/StrategyRegistry أو `mq5:5806` — كان صحيحًا.
- لا commit حتى نجاح التشغيلَين v3.

---

## ٥. التغييرات الكوديّة الدقيقة

### تغيير ١ — رفع الحارس من موضع الاستدعاء

**ملفّ:** `Risk/FalconRiskLifecycleProcessor.mqh`
**موضع:** السطور 1635-1640 (داخل `ApplyTradeLifecycleChain`).

**قبل (R1.7 الأصلي):**
```mqh
      if(Enable_TradeManagement)
      {
         if(Enable_S01_Protection)
            ApplyPaperRuntimeSmartSLProtectionApplication(record);             // #5
         ApplyPaperRuntimeRunnerApplication(record);                          // #6
      }
```

**بعد:**
```mqh
      ApplyPaperRuntimeSmartSLProtectionApplication(record);                   // #5
      ApplyPaperRuntimeRunnerApplication(record);                              // #6
```

(تراجعٌ إلى الحالة الأصليّة قبل R1.7. الحارس ينتقل داخل الدالّتَين.)

### تغيير ٢ — حارس داخل Apply #5

**ملفّ:** `Risk/FalconRiskLifecycleProcessor.mqh`
**موضع:** بعد كتلة التهيئة الدفاعيّة في `ApplyPaperRuntimeSmartSLProtectionApplication`
(بعد السطر `:817` أو ما يحدّده Claude Code كنهاية كتلة الـ defensive
init). تحديدًا: **بعد كلّ إسناداتٍ تبدأ بـ `record.paper_protection_*` التي
تُهيِّئ القيم passthrough/false، وقبل أوّل سطرٍ يبدأ المنطق الفعليّ
(`if(record.paper_guard_status == "PASSED" ...)`).**

**يُضاف سطرٌ واحد:**
```mqh
      // R1.7-amend: gate paper protection logic by flags.
      // Defensive inits above always run (passthrough semantics);
      // logic below runs only when both flags are on.
      if(!Enable_TradeManagement || !Enable_S01_Protection)
         return;
```

### تغيير ٣ — حارس داخل Apply #6

**ملفّ:** `Risk/FalconRiskLifecycleProcessor.mqh`
**موضع:** بعد كتلة التهيئة الدفاعيّة في `ApplyPaperRuntimeRunnerApplication`
(بعد السطر `:892` أو ما يحدّده Claude Code). نفس المنطق: بعد التهيئة،
قبل المنطق.

**يُضاف:**
```mqh
      // R1.7-amend: gate paper runner logic by flag.
      // Defensive inits above always run; logic below runs only when TM on.
      // (Runner naturally no-ops if paper_protection_activated stayed false.)
      if(!Enable_TradeManagement)
         return;
```

---

## ٦. التشغيلَان التحقّقيّان (v3)

**نفس إعدادَي Bare و ON من R1.7 الأصليّة** (`R1_7_BareBaseline.set` و
`R1_7_SanityON.set` — لا تغييرٌ في المدخلات).

### معايير القبول الجديدة لـ Bare

| المقياس | المطلوب |
|---|---|
| `ProtectionActivatedTrades` | **= 0** بالضبط |
| `RunnerActivatedTrades` | **= 0** بالضبط |
| `FinalWorkingNetUSD` | رقم سليم في النطاق الطبيعيّ (لا nan، لا e+267) |
| `ProtectionNetUSD` لكلّ صفقة | يساوي `paper_guard_net_usd` (passthrough) — أو `0.0` |
| `RunnerNetUSD` لكلّ صفقة | يساوي `ProtectionNetUSD` (passthrough) |
| `BrokerActualNetUSD` | ≈ 275-321 (jitter tick) |
| `TotalTrades` | ≈ 610 |

### معايير القبول لـ Sanity ON (دون تغيير)

| المقياس | المطلوب |
|---|---|
| `ProtectionActivatedTrades` | > 0 (تأكيد عودة المحرّك للعمل) |
| `RunnerActivatedTrades` | ≥ 0 |
| `FinalWorkingNetUSD` | رقم سليم |

---

## ٧. بروتوكول العمل

1. تنفيذ تغييرات §٥ في الـ working copy (تغييرات R1.7 السابقة تبقى).
2. **حذف الـ `.ex5` يدويًّا** قبل البناء (لتأكيد إعادة البناء الكاملة):
   ```powershell
   Remove-Item "JA_FalconCore_Automated_Trading_Platform.ex5" -Force
   ```
3. أغلق MT5 (الـ Terminal). افتح MetaEditor. `Ctrl+F7` لإعادة بناءٍ صريحة.
4. تحقّق من `LastWriteTime` للـ `.ex5` الجديد.
5. شغّل MT5، أجرِ تشغيل Bare و ON بنفس الـ `.set`ين السابقَين.
6. ارفع الـ Summaries. **لا commit حتى الموافقة.**

---

## ٨. ملحق — Prompt لـ Claude Code

```
السياق: تغييرات R1.7 موجودة في الـ working copy (غير مُنفَّذة كـ commit).
تشغيل تحقّقيّ أظهر خللًا: العدّادات الورقيّة تشتغل في Bare وقيم
الـ FinalWorking فاسدة (ذاكرة غير مُهيَّأة). نريد تصحيحًا داخليًّا.

١. اقرأ كاملًا الملفّ المرفق `Spec_R1_7_Amend_DefensiveInit.md`. هو
   المرجع الوحيد لهذا العمل.

٢. التزم بـ §٤ القيود و§٥ التغييرات بالضبط.

٣. طبّق التغييرات الثلاثة:
   - تغيير ١: ارجع موضع الاستدعاء (Risk:1635-1640) إلى نسختَي
     R1.6a (نداءات مباشرة بدون if).
   - تغيير ٢: في `ApplyPaperRuntimeSmartSLProtectionApplication`،
     أضف بعد كتلة التهيئة الدفاعيّة (التي تُسنِّد القيم passthrough
     وتصفّر `paper_protection_activated`) — وقبل أوّل سطرٍ منطقيّ
     يبدأ بشرط على `paper_guard_status` أو `barpath_stats`:
       if(!Enable_TradeManagement || !Enable_S01_Protection)
          return;
   - تغيير ٣: في `ApplyPaperRuntimeRunnerApplication`، نفس النمط
     لكن الحارس على `!Enable_TradeManagement` فقط.

٤. تحقّق من أن تهيئة الحقول التالية تشتغل **قبل** الحارس في كلٍّ من
   الدالّتَين:
   - Apply #5: `paper_protection_activated = false`,
     `paper_protection_net_index_points`, `paper_protection_net_usd`.
   - Apply #6: `paper_runner_activated = false`,
     `paper_runner_net_index_points`, `paper_runner_net_usd`.

٥. لا تغيير لأيّ ملفٍّ آخر. لا رفع إصدار. لا commit.

٦. احذف الـ .ex5 الحاليّ ثمّ أعد البناء (Ctrl+F7).

٧. توقّف. أظهر:
   - git diff (التغييرات الثلاثة فقط)
   - LastWriteTime للـ .ex5 الجديد
   - تأكيد البناء بدون أخطاء

سيُجري المشغّل التشغيلَين v3 يدويًّا. **لا تتقدّم خطوة بعد البناء.**

عند أيّ تعارض: المواصفة تحكم. عند أيّ غموض: اسأل.
```

---

## ٩. بروتوكول الإغلاق (بعد نجاح v3)

سيُجمَع commit واحد يحوي **R1.7 الأصليّة + هذه المُكمِّلة معًا** — مرحلة
R1.7 واحدة تنغلق بمحاولتها الثانية الصحيحة. النصّ يُعدَّل ليعكس الدرس
المُكتسَب.

تحديثات Ideas Backlog:
- **درس عمليّ:** «حارس على دالّة init-aware يجب أن يكون **داخلها** بعد
  التهيئة، لا حولها». تُضاف كقاعدة عمل.
- مراجعة بقيّة سلسلة Apply* لاحقًا (Backlog، ليس الآن): هل بقيّة الـ
  Apply تعتمد على نفس النمط init-then-logic بحيث يُمكن تطبيق نفس
  استراتيجيّة الحراسة عند الحاجة؟
