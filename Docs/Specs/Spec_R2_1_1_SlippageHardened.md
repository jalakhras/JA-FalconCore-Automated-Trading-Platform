# مواصفة R2.1.1 — معالجة Slippage في FvgMicroRetest

> **النوع:** إصلاح فرعيّ (تغيير كود + بناء + تشغيل تحقّقيّ واحد).
> **الإصدار:** `EA_VERSION_TAG`: `R2_1` ⇒ **`R2_1_1`**.
>           `Build`: `FvgMicroSpecAligned` ⇒ **`SlippageHardened`**.
> **يسبقها:** R2.1 closeout + R2.2 الذي كشف الانهيار في يناير 2025.
> **سبب وجودها:** فحصٌ جنائيّ كشف أن paper متفائلٌ بنيويًّا 2x على الخسائر،
> بسبب slippage على entry يدفع السعر قرب SL في mikro-FVG.

---

## ١. الهدف

تطبيق تعديلَين دقيقَين على FvgMicroRetest لامتصاص أثر slippage على entry:

1. **Slippage entry guard** — رفض الصفقة إن تجاوز slippage عتبةً قابلةً للضبط.
2. **SL أوسع** — معامل قابل للضبط يضرب zone size لاستيعاب slippage.

التحقّق: تشغيلٌ واحدٌ على يناير 2025 (Test C config) — نقارن broker net
الحاليّ (−150.33) بالنتيجة الجديدة.

---

## ٢. السياق — الدليل الذي يقود التعديل

من Reconciliation Test C يناير 2025 (504 صفقة):

| المقياس | القيمة |
|---|---:|
| `EntryPriceDelta` abs sum | 2558 نقطة |
| `EntryPriceDelta` mean | −0.38 نقطة |
| أكبر slippage فرديّ | 32.71 نقطة |
| Slippage > 15 نقطة (عدد الصفقات) | ~30 صفقة |
| Broker − Paper Final | **−549.19$** |

**النمط:** كلّ صفقة خاسرة على broker = ~2x خسارة paper. السبب: entry slippage
يدفع السعر داخل zone قرب SL، فتُضاعف مسافة entry-to-SL الفعليّة.

S01 لا يعاني من هذا (SL ثابت 30 نقطة، slippage 5-10 نقاط لا يهمّ).
FvgMicro يعاني لأنّ zone size 30-100 نقطة، فـ slippage 15-30 نقطة كارثيّ.

---

## ٣. القيود الصارمة

- **تعديلان فقط** كما في §٤. لا توسيع نطاق.
- **لا تعديل لمنطق الكشف، الـ retest، أو الـ TP.** فقط معالجة slippage.
- **لا تعديل لـ S01 أو Apply chain أو Protection.** خارج النطاق.
- **القيم الافتراضيّة:** placeholder معقولة، تُعاير لاحقًا (Backlog).
- **لا commit حتى نجاح التشغيل التحقّقيّ.**
- **commit واحد فقط** بعد القبول.

---

## ٤. التغييرات الكوديّة الدقيقة

### تغيير ١ — Slippage Entry Guard

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`

**إدخال جديد** (يُضاف ضمن inputs FvgMicro، قرب `FvgMicroSlBufferPoints`):

```mq5
input double FvgMicroMaxEntrySlippagePoints = 15.0;  // reject entry if |broker_entry - paper_entry| exceeds this
```

**موضع الحارس:** داخل المسار الذي يُولّد broker order (قبل أو بعد ما يُعرف
بـ `BROKER_ENTRY_BLOCKED_*` checks). Claude Code يحدّد الموضع الدقيق من
القراءة.

**المنطق:**
```mq5
// R2.1.1 SlippageHardened: حارس slippage على entry.
// نحسب الفرق بين السعر المخطّط (midpoint) والسعر الفعليّ (Ask/Bid).
const double planned_entry = m_snapshot.fvg_midpoint;  // أو الحقل الفعليّ من الـ plan
const double actual_entry  = (direction == 1)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
const double slippage_points = MathAbs(actual_entry - planned_entry) / _Point;

if(slippage_points > FvgMicroMaxEntrySlippagePoints)
{
   m_snapshot.no_trade_reason = "FVG_MICRO_REJECTED_ENTRY_SLIPPAGE";
   // سجّل في rejection log
   return;  // skip this entry
}
```

**ملاحظات لـ Claude Code:**
- اسم حقل `fvg_midpoint` قد يكون مختلفًا في الـ snapshot — استعمل الفعليّ.
- موضع الحارس: **قبل** `OrderSend`، **بعد** كلّ guards أخرى مرّت. هدفه
  أن يكون آخر check قبل التنفيذ.
- إن وُجد سلفًا rejection log مع `FVG_MICRO_REJECTED_*` reasons، استعمل
  نفس الميكانيزم.

### تغيير ٢ — SL أوسع (معامل قابل للضبط)

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** `BuildBullishStructuralSL` و `BuildBearishStructuralSL` (أو
ما يقابلهما داخل `BuildTradePlanSkeleton` — Claude Code يحدّد).

**إدخال جديد:**
```mq5
input double FvgMicroSlZoneSizeMultiplier = 1.5;  // SL distance = zoneSize × multiplier + buffer
```

**التغيير في صيغة SL:**

**قبل (مفترض):**
```mq5
const double sl_distance = zone_size + safe_buffer;
sl = (direction == 1) ? (entry - sl_distance) : (entry + sl_distance);
```

**بعد:**
```mq5
const double sl_distance = zone_size * FvgMicroSlZoneSizeMultiplier + safe_buffer;
sl = (direction == 1) ? (entry - sl_distance) : (entry + sl_distance);
```

**ملاحظات:**
- إن الصيغة الحاليّة مختلفة (مثلًا `SL = fvg_lower - buffer` لا `entry − zoneSize`)،
  راجعها وعدّلها بحيث `SL` يبتعد عن entry بـ `zone_size × multiplier + buffer`.
- TP يبقى كما هو (مرتكزه entry، صيغة `entry ± zoneSize × {1,2,3}` من R2.1).
  هذا **يقلّل R-multiple** (من 2.0 إلى ~1.33)، لكنّه يقلّل خسارة broker
  بقدرٍ أكبر.

### تغيير ٣ — رفع الإصدار

**ملفّ:** `Core/FalconConstants.mqh`
```mq5
#define EA_VERSION_TAG "R2_1_1"
#define EA_BUILD_TAG   "SlippageHardened"
```

---

## ٥. التشغيل التحقّقيّ — يناير 2025 فقط

### الإعداد

| المدخل | القيمة |
|---|---|
| Symbol | US100_Spot |
| Timeframe | M5 |
| **From** | **2025.01.01** |
| **To** | **2025.01.31** |
| Initial Deposit | 200 |
| Leverage | 1:100 |
| Modelling | Every tick based on real ticks |
| `.set` ملفّ | `R2_1_TestC_FvgMicroOnly_Baseline.set` (FvgMicro وحدها) |
| المدخلات الجديدة | `FvgMicroMaxEntrySlippagePoints = 15.0`, `FvgMicroSlZoneSizeMultiplier = 1.5` |

احفظ `.set` باسم: `R2_1_1_TestC_Jan2025_SlippageHardened.set`.

### معايير القبول

نُقارن مع Test C الأصليّ على يناير (`-150.33` broker):

| سيناريو النتيجة | broker net المتوقَّع | القرار |
|---|---|---|
| موجب صريح (> +20$) | تحسّن جوهريّ | ⇒ نوسّع للسنة كاملة (R2.2 معدّل) |
| ~0 ± 30$ | تحسّن جزئيّ، الـ slippage ساهم لكن ليس وحده | ⇒ نضيف فلتر الترند (R2.1.2) |
| ما زال سالبًا (< −30$) | المعالجة لم تكفِ، خلل أعمق | ⇒ تشخيص ثانٍ، احتمال تراجع لـ R2.0 |

**معايير ثانويّة:**
- `Rejection rate` للـ slippage guard: كم صفقة من ~500 رُفضت؟ متوقَّع 5-15%.
- `Max single loss`: متوقَّع أن ينقص (من −13.00 إلى ~−7) بسبب SL الأوسع.
- `Avg loss`: متوقَّع أن يبقى مماثلًا (R-multiple أصغر = خسارة أصغر لكنّ أكثر).
- `WinRate`: قد ينقص قليلًا (SL أبعد = صفقاتٌ كانت ستضرب SL سابقًا الآن قد تعود).

---

## ٦. بروتوكول العمل

1. تطبيق التعديلين في الكود + رفع الإصدار.
2. حذف `.ex5` يدويًّا:
   ```powershell
   Remove-Item "JA_FalconCore_Automated_Trading_Platform.ex5" -Force
   ```
3. إغلاق MT5. فتح MetaEditor. `Ctrl+F7` لإعادة بناءٍ صريحة.
4. تأكيد `.ex5` الجديد + التقارير `R2_1_1 / SlippageHardened`.
5. تشغيل Strategy Tester بالإعدادات أعلاه.
6. رفع: Summary + TradeLifecycle + BrokerPaperTradeReconciliation +
   `.set` المحفوظ + لقطة Results.
7. **لا commit قبل المراجعة.**

---

## ٧. بروتوكول الإغلاق (إن نجح التشغيل)

- commit واحد بنصّ:
  ```
  R2.1.1 — معالجة Slippage في FvgMicroRetest

  - Slippage entry guard: |EntryPriceDelta| > 15 points يرفض.
  - SL أوسع: zoneSize × 1.5 + buffer (بدل zoneSize + buffer).
  - placeholder defaults، تُعاير لاحقًا.

  السبب: paper متفائلٌ 2x على خسائر FvgMicro بسبب entry slippage
  يدفع السعر قرب SL في micro-zones. هذا التعديل يمتصّ الـ slippage
  بمستويين (يرفض الأسوأ، يوسّع SL ليبتعد عن المتبقّي).

  EA_VERSION_TAG: R2_1 → R2_1_1
  Build: FvgMicroSpecAligned → SlippageHardened
  ```

- إنشاء `Docs/ReviewNotes/R2_1_1_Review_Notes.md` بنتائج التشغيل.
- Ideas Backlog: «معايرة `FvgMicroMaxEntrySlippagePoints` و
  `FvgMicroSlZoneSizeMultiplier` بعد تشغيلات أوسع».

---

## ٨. ما لا تقرّره هذه المواصفة

- **فلتر الترند:** مُؤجَّل لـ R2.1.2 إن احتاج (شرط: نتيجة R2.1.1 «تحسّن جزئيّ»).
- **سنة كاملة 2025:** مُؤجَّل لـ R2.2 المعدّل بعد نجاح R2.1.1.
- **R2.4 (تنفيذ حيّ):** بعيد. أوّلًا نمرّ بـ R2.2 + R2.3.

---

## ٩. ملحق — Prompt لـ Claude Code

```
السياق: نحن على فرع `refactor`، آخر commit R2.2 (المواصفة، لا التشغيل).
بعد تشغيل R2.2 يدويًّا، انكشف انهيارٌ في يناير 2025. فحصٌ جنائيٌّ كشف
أن paper متفائلٌ بنيويًّا 2x على خسائر FvgMicro بسبب entry slippage.
نريد R2.1.1 — تعديلَين كوديَّين صغيرَين + بناء + توقّف للتشغيل اليدويّ.

التعليمات بالترتيب:

١. اقرأ كاملًا `Spec_R2_1_1_SlippageHardened.md`. المرجع الوحيد.

٢. التزم بـ §٣ القيود.

٣. طبّق التغييرَين في §٤:
   - تغيير ١: Slippage entry guard. اقرأ المسار حول OrderSend الفعليّ
     في FvgMicro entry path. أضف الحارس **قبل** OrderSend، **بعد** كلّ
     guards أخرى.
   - تغيير ٢: SL أوسع. اقرأ صيغة SL الحاليّة في BuildBullishStructuralSL
     و BuildBearishStructuralSL. عدّلها لتشمل `FvgMicroSlZoneSizeMultiplier`.
   - تغيير ٣: رفع الإصدار في FalconConstants.mqh.

٤. أسماء الحقول/الدوالّ: استعمل الفعليّ من القراءة، لا المقترح في
   المواصفة (المقترح placeholder).

٥. احذف `.ex5` ثمّ أعد البناء (Ctrl+F7).

٦. توقّف. أظهر:
   - git diff --stat
   - تأكيد البناء بلا أخطاء
   - LastWriteTime للـ .ex5
   - الأسماء الفعليّة للحقول/الدوالّ التي استعملتها

المشغّل يُجري التشغيل اليدويّ في MT5. لا تتقدّم خطوة بعد البناء.

عند أيّ تعارض: المواصفة تحكم. عند أيّ غموض: اسأل.
```
