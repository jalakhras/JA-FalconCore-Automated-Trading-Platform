# مواصفة R2.1 — إكمال FvgMicroRetest وفق شرح الاستراتيجيّة

> **النوع:** إصلاح مرحلة (تغيير كود + بناء + تشغيل تحقّق).
> **الإصدار:** `EA_VERSION_TAG`: `R1_7` ⇒ **`R2_1`**.
>           `Build`: `GateLeakFix` ⇒ **`FvgMicroSpecAligned`**.
> **يسبقها:** إغلاق R1.7 + `Exploration_R2_0_FvgMicroExistingCodeAudit.md`.
> **مسار R2.1:** «إكمال» — تعديل الكود الموجود (~65% مكتمل) ليطابق
> شرح الاستراتيجيّة. لا إنشاء فئات جديدة، لا حذف، لا بناء موازٍ.

---

## ١. الهدف

سدّ ٧ فجوات محدّدة بين كود `FVG_MICRO_RETEST` الموجود وشرح الاستراتيجيّة
المُقدَّم من المستخدم، بأقلّ تغيير ممكن، ضمن نفس الفئات والـ snapshots
القائمة.

---

## ٢. النطاق

### داخل النطاق — التعديلات السبعة

| # | الفجوة | الفئة | الملفّ |
|---|---|---|---|
| 1 | مرتكز TP: حدّ FVG → الدخول (midpoint) | جوهريّة | `.mq5:4761-4763, 4768-4770` |
| 2 | إضافة `Invalidation guard` | جوهريّة | `.mq5` (داخل pipeline الكشف) |
| 3 | Spread guard: مطلق → نسبيّ (`spread/zoneSize`) | جوهريّة | `.mq5:4496-4503` |
| 4 | SL buffer: مشتقّ → قابل للضبط (input) | ثانويّة | `.mq5:4752-4753, 4760, 4767` + إدخال جديد |
| 5 | Age guard: تفعيله (حساب العمر فعليًّا) | ثانويّة | `.mq5:4473 + 4505-4512` |
| 6 | Retest confirmation: metrics-only → بوّابة اختياريّة | ثانويّة | `.mq5:4864-4905` + إدخال جديد |
| 7 | `MIN_SIZE_POINTS`: 1.00 → قيمة معقولة | ثانويّة | `.mq5:2001` |
| 8 | رفع `EA_VERSION_TAG` و`Build` | إجرائيّ | `Core/FalconConstants.mqh` |

### خارج النطاق

- **`FalconStrategySignal` struct** (مُعرَّف، غير مُستعمَل في `Core/FalconDataStructures.mqh:391`).
  المسار الحاليّ عبر `FalconShadowTradeRecord`/`FalconTradePlan` يعمل. ⇒ Backlog.
- **مظروف طوارئ البروكر** — يطابق نيّة الشرح §١٥ كما هي. ⇒ يبقى.
- **Protection/Runner على البروكر** — يحتاج مرحلة R3.x منفصلة. ⇒ ليس هنا.
- **ازدواج مسار الدخول** (`mq5:5926` OnInit و`:6022` OnTick) — يعتمد على
  `g_last_staged_fvg_candidate_id`. ⇒ Backlog — يُراجع لاحقًا.
- **منظومة `S00_ScalpFvgMicro/`** المنفصلة — لا تُمسّ.

---

## ٣. القيود الصارمة

- **لا إنشاء فئات أو ملفّات جديدة.** التعديلات داخل الكود القائم.
- **لا حذف فئات أو snapshots** — كلّها مُستعمَلة.
- **لا تغيير لسلسلة `Apply*`** ولا منطق Protection/Runner.
- **لا تغيير لمسار البروكر** (مظروف الطوارئ يبقى).
- **commit واحد فقط** بعد نجاح التشغيل التحقّقيّ.
- لا تشغيل قبل البناء، ولا commit قبل التشغيل التحقّقيّ.

---

## ٤. التغييرات التفصيليّة

### تغيير ١ — مرتكز TP من حدّ FVG إلى الدخول

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** `BuildTradePlanSkeleton` — السطور `4761-4763` (BUY) و`4768-4770` (SELL).

**قبل (BUY مثال):**
```mq5
m_snapshot.planned_tp1 = m_snapshot.fvg_upper + zone_size;
m_snapshot.planned_tp2 = m_snapshot.fvg_upper + zone_size * 2.0;
m_snapshot.planned_tp3 = m_snapshot.fvg_upper + zone_size * 3.0;
```

**بعد:**
```mq5
m_snapshot.planned_tp1 = midpoint + zone_size;
m_snapshot.planned_tp2 = midpoint + zone_size * 2.0;
m_snapshot.planned_tp3 = midpoint + zone_size * 3.0;
```

**للـ SELL (`:4768-4770`):** نفس النمط — استبدال `fvg_lower` بـ `midpoint`،
وعلامة الطرح كما هي.

**مبرّر:** شرح §١٢ صريح — `tp = entry + zoneSize × N`. المرتكز الدخول.

---

### تغيير ٢ — إضافة `Invalidation guard`

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** داخل `CFalconFvgMicroShadowCandidateBuilder::EvaluateQualityFilters`
(بعد الفلاتر الموجودة، قبل `return true` النهائيّ — Claude Code يحدّد
السطر بدقّة عند القراءة، توقعًّا قرب `:4512`).

**يُضاف منطق:**
```mq5
// R2.1: Invalidation guard — closed candle beyond zone breaks the FVG.
const double last_closed_close = m_candle_cache.ReadLastClosedClose(PERIOD_M5);
const bool bullish_invalidated = (detector_snapshot.fvg_direction == 1
                                   && last_closed_close < detector_snapshot.fvg_lower);
const bool bearish_invalidated = (detector_snapshot.fvg_direction == -1
                                   && last_closed_close > detector_snapshot.fvg_upper);
if(bullish_invalidated || bearish_invalidated)
{
   m_snapshot.candidate_status = "REJECTED_INVALIDATED";
   m_snapshot.quality_reject_reason = "FVG_MICRO_REJECTED_ZONE_INVALIDATED";
   return false;
}
```

**ملاحظة لمنفّذ Claude Code:** إن لم تكن `ReadLastClosedClose(PERIOD_M5)` متوفّرة
بهذا الاسم، استعمل أقرب دالّة مكافئة من `m_candle_cache`؛ إن لم توجد، اقرأ
`rates[1]` عبر `CopyRates` مع `shift=1, count=1` (شمعة مغلقة واحدة).
**يجب أن يكون `last_closed_close` من شمعة مغلقة قطعًا** (لا shift=0).

---

### تغيير ٣ — Spread guard نسبيّ

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** `:4496-4503`.

**قبل:**
```mq5
if(spread_points > m_snapshot.quality_max_spread_points)
{
   m_snapshot.candidate_status = "REJECTED_SPREAD";
   m_snapshot.quality_reject_reason = "SPREAD_ABOVE_MAX";
   return false;
}
```

**بعد:**
```mq5
const double spread_to_fvg_ratio = (detector_snapshot.fvg_size_points > 0.0)
   ? (spread_points / detector_snapshot.fvg_size_points)
   : 999.0;
if(spread_to_fvg_ratio > FALCON_FVG_MICRO_MAX_SPREAD_TO_FVG_RATIO)
{
   m_snapshot.candidate_status = "REJECTED_SPREAD";
   m_snapshot.quality_reject_reason = "FVG_MICRO_REJECTED_SPREAD_TOO_LARGE";
   return false;
}
```

**ثابتٌ جديد** في `.mq5:2002` (يحلّ محلّ `FALCON_FVG_MICRO_MAX_SPREAD_POINTS = 200`):

```mq5
#define FALCON_FVG_MICRO_MAX_SPREAD_TO_FVG_RATIO 0.50  // spread ≤ 50% of FVG size
```

(القيمة 0.50 قابلة لإعادة الضبط لاحقًا بعد رؤية بيانات R2.2.)

**حقل snapshot:** `quality_max_spread_points` يبقى مُعرَّفًا للاتّساق مع التقارير،
لكنّ شرط الرفض الجديد لا يستعمله. (يمكن إفراغه أو إعادة استعماله لاحقًا.)

---

### تغيير ٤ — SL buffer قابل للضبط

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** `BuildTradePlanSkeleton`، `:4752-4753`.

**إدخال جديد** (يُضاف ضمن inputs FVG في `.mq5` — Claude Code يحدّد المكان
المناسب بين بقيّة `FALCON_FVG_MICRO_*` inputs، تقريبًا `:2000s`):

```mq5
input double FvgMicroSlBufferPoints = 30.0;  // structural SL buffer below/above FVG zone
```

**قبل:**
```mq5
const double zone_size  = MathAbs(m_snapshot.fvg_upper - m_snapshot.fvg_lower);
const double min_buffer = MathMax(zone_size, (double)symbol_context.stops_level_points * symbol_context.point);
const double safe_buffer= (min_buffer > 0.0 ? min_buffer : 10.0 * symbol_context.point);
```

**بعد:**
```mq5
const double zone_size      = MathAbs(m_snapshot.fvg_upper - m_snapshot.fvg_lower);
const double user_buffer    = FvgMicroSlBufferPoints * symbol_context.point;
const double stops_buffer   = (double)symbol_context.stops_level_points * symbol_context.point;
const double safe_buffer    = MathMax(user_buffer, stops_buffer);  // honor broker stops_level minimum
```

**مبرّر:** السماح للمستخدم بضبط الـ buffer (شرح §١١.١-١١.٢)، مع ضمان احترام
حدّ البروكر الأدنى (`stops_level`).

---

### تغيير ٥ — تفعيل Age guard

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** `:4473` (حقل `quality_fvg_age_bars`) و`:4505-4512` (الفلتر).

**حاليًّا:** `m_snapshot.quality_fvg_age_bars = 0;` ثابتًا ⇒ الفلتر لا يحجب.

**بعد:** حساب العمر فعليًّا. Claude Code يحدّد:
- وقت اكتشاف FVG: `detector_snapshot.fvg_newer_candle_time` (موجود).
- الوقت الحاليّ (M5 المغلق): `TimeCurrent()` أو وقت آخر شمعة مغلقة.
- الفرق بالشموع: `(now - fvg_time) / (5 * 60)` للـ M5.

```mq5
const datetime now_closed = iTime(_Symbol, PERIOD_M5, 1);  // last closed M5 bar time
const datetime fvg_time   = detector_snapshot.fvg_newer_candle_time;
m_snapshot.quality_fvg_age_bars = (fvg_time > 0 && now_closed > fvg_time)
   ? (int)((now_closed - fvg_time) / (5 * 60))
   : 0;
```

**العتبة الافتراضيّة** (`FALCON_FVG_MICRO_MAX_FVG_AGE_BARS`) في `.mq5:2003`:

```mq5
#define FALCON_FVG_MICRO_MAX_FVG_AGE_BARS 12  // 1 hour on M5
```

(يحلّ محلّ القيمة الحاليّة `0`. القيمة 12 = ساعةٌ تقريبًا، قابلة للضبط بعد R2.2.)

---

### تغيير ٦ — Retest confirmation كبوّابة اختياريّة

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** `CFalconFvgMicroRetestWatcher` — حول `BuildTradePlanSkeleton`،
بعد فحص `retest_touched`.

**إدخال جديد:**
```mq5
input bool FvgMicroRequireRetestConfirmation = false;  // require close-above-mid or rejection wick before entry
```

**منطق:** بعد `retest_touched = true`، إن كان `FvgMicroRequireRetestConfirmation`
فعّالًا، استعمل المقاييس المحسوبة فعلًا في `FalconCalculateFvgHoldQualityScore`
(`.mq5:4864-4905`) كبوّابة:

```mq5
if(FvgMicroRequireRetestConfirmation)
{
   const bool bullish_confirmed = (m_snapshot.fvg_direction == 1)
      && m_snapshot.retest_close_above_midpoint
      && m_snapshot.retest_bullish_candle_after_touch;
   const bool bearish_confirmed = (m_snapshot.fvg_direction == -1)
      && m_snapshot.retest_close_below_midpoint
      && m_snapshot.retest_bearish_candle_after_touch;
   if(!(bullish_confirmed || bearish_confirmed))
   {
      m_snapshot.no_trade_reason = "FVG_MICRO_REJECTED_RETEST_NOT_CONFIRMED";
      return;  // skip BuildTradePlanSkeleton this tick
   }
}
```

**ملاحظة:** أسماء الحقول (`retest_close_above_midpoint`، `retest_bullish_candle_after_touch`)
يحدّدها Claude Code من القراءة الفعليّة لـ `FalconCalculateFvgHoldQualityScore` —
استعمل الأسماء المطابقة الموجودة فعلًا في الـ snapshot.

**default = `false`** ⇒ السلوك الافتراضيّ يطابق الحاليّ (لا تأكيد إلزاميّ)؛
نختبر الـ ON/OFF لاحقًا في R2.2.

---

### تغيير ٧ — قيمة `MIN_SIZE_POINTS` معقولة

**ملفّ:** `JA_FalconCore_Automated_Trading_Platform.mq5`
**موضع:** `:2001`.

**قبل:**
```mq5
#define FALCON_FVG_MICRO_MIN_SIZE_POINTS 1.00
```

**بعد:**
```mq5
#define FALCON_FVG_MICRO_MIN_SIZE_POINTS 30.0  // ~3 points NQ scale, filters micro-noise
```

(القيمة 30.0 placeholder معقول لـ US100 M5. تُعاد المعايرة بعد رؤية توزيع
أحجام FVG في تشغيل R2.2.)

---

### تغيير ٨ — رفع الإصدار

**ملفّ:** `Core/FalconConstants.mqh`

```mq5
#define EA_VERSION_TAG "R2_1"
#define EA_BUILD_TAG   "FvgMicroSpecAligned"
```

---

## ٥. التشغيلات التحقّقيّة

### تشغيل ١ — Shadow Compile + Smoke

**هدف:** التأكّد من البناء بلا أخطاء، والـ pipeline يعمل بلا انهيار.

**إعداد:**
- نفس US100_Spot M5 من R1.7.
- نافذة قصيرة: `2026.04.01 → 2026.04.03` (3 أيّام كافية للـ smoke).
- إيداع 200.
- `Enable_S01_Harness = false`.
- **`EnableStrategy_FvgMicroRetest = true`**.
- `S00_RealExecution = false`.
- `Enable_TradeManagement = false`.
- `Enable_S01_Protection = false`.
- `EnableRealExecution = false` (Shadow فقط).
- المدخلات الجديدة على افتراضيّاتها (`FvgMicroSlBufferPoints=30`،
  `FvgMicroRequireRetestConfirmation=false`).

**معايير القبول:**
- البناء بلا أخطاء.
- إصدار التقرير = `R2_1 / FvgMicroSpecAligned`.
- `TotalTrades` > 0 (لا انهيار صامت).
- لا `nan` ولا قيم فلكيّة في `FinalWorkingNetUSD`.
- لا أعمدة `Inf` في `TradeLifecycle`.

**احفظ `.set` باسم `R2_1_Smoke_Shadow.set`.**

### تشغيل ٢ — Full April Shadow Run

**هدف:** قياس عدد الإشارات وتوزيعها على شهر كامل.

**إعداد:** نفس تشغيل 1 لكن النافذة `2026.04.01 → 2026.04.30`.

**ما نقرأ:**
- `TotalTrades` (عدد إشارات FvgMicro المُولَّدة).
- توزيع `rejection reasons`.
- `BrokerActualNetUSD` (المقياس الموثوق).
- نطاق `RawNetUSD` و`FinalWorkingNetUSD`.

**لا معيار قبول رقميّ هنا** — هذا قياسٌ استكشافيّ، يُكوِّن أوّل صورة للحافة
الورقيّة. القرار الفعليّ في R2.3 (بوّابة الحافة على ٣ أشهر).

**احفظ `.set` باسم `R2_1_April_Shadow.set`.**

---

## ٦. بروتوكول العمل

1. تطبيق التغييرات ١-٧ في الـ working copy.
2. رفع الإصدار (تغيير ٨).
3. حذف الـ `.ex5` يدويًّا:
   ```powershell
   Remove-Item "JA_FalconCore_Automated_Trading_Platform.ex5" -Force
   ```
4. إغلاق MT5. فتح MetaEditor. `Ctrl+F7` لإعادة بناءٍ صريحة.
5. تأكيد `.ex5` الجديد + التقارير تحمل `R2_1 / FvgMicroSpecAligned`.
6. تشغيل (١) Smoke. إن نجح ⇒ تشغيل (٢) April.
7. رفع الـ Summaries + `.set`ين. **لا commit قبل المراجعة.**

---

## ٧. بروتوكول الإغلاق (بعد قبول النتائج)

- commit واحد بنصّ:
  ```
  R2.1 — إكمال FvgMicroRetest وفق شرح الاستراتيجيّة

  - مرتكز TP: حدّ FVG → midpoint (الدخول).
  - Invalidation guard: إضافة فحص إغلاق متجاوز.
  - Spread guard: نسبيّ (spread/zoneSize) بدل المطلق.
  - SL buffer: قابل للضبط عبر FvgMicroSlBufferPoints.
  - Age guard: تفعيله بحساب فعليّ بدل ثابت 0.
  - Retest confirmation: بوّابة اختياريّة عبر input.
  - Min size: 1.00 → 30.0 (placeholder، يُعاد ضبطه بعد البيانات).

  مكتمل: 65% → 100% مطابق للشرح في طبقة توليد الإشارة.
  مظروف طوارئ البروكر يبقى (يطابق نيّة الشرح §١٥).
  إدارة Protection/Runner على البروكر مُؤجَّلة لـ R3.x.

  EA_VERSION_TAG: R1_7 → R2_1
  Build: GateLeakFix → FvgMicroSpecAligned
  ```
- إنشاء `Docs/ReviewNotes/R2_1_Review_Notes.md` بنتائج تشغيلَي smoke و April.
- Ideas Backlog:
  - `FalconStrategySignal` refactor: استبدال المسار الورقيّ
    (`FalconShadowTradeRecord`/`FalconTradePlan`) بـ `FalconStrategySignal` لاتّساق
    معماريّ. غير حاجب.
  - ازدواج مسار الدخول OnInit/OnTick: مراجعة سلوك `g_last_staged_fvg_candidate_id`.
  - معايرة `MIN_SIZE_POINTS`، `MAX_SPREAD_TO_FVG_RATIO`، `MAX_AGE_BARS`،
    `FvgMicroSlBufferPoints` بعد بيانات R2.2.
  - Protection/Runner على البروكر = R3.x (لا تُلمس قبل بوّابة R2.3).

---

## ٨. ملحق — Prompt لـ Claude Code

```
السياق: نحن على فرع `refactor`. آخر commit = R1.7 closeout. نريد تطبيق
R2.1 — تعديلات على كود FvgMicroRetest الموجود ليطابق شرح الاستراتيجيّة.

التعليمات بهذا الترتيب الحرفيّ:

١. اقرأ كاملًا الملفّ المرفق `Spec_R2_1_FvgMicroComplete.md`. هو المرجع
   الوحيد. كلّ ما يلي تعليمات تشغيليّة لا بديلة.

٢. اقرأ التقرير المرافق `Docs/Explorations/Exploration_R2_0_FvgMicroExistingCodeAudit.md`
   ليكون لديك خريطة المواضع.

٣. التزم بـ §٣ القيود الصارمة.

٤. طبّق التغييرات ١-٨ في §٤ بالضبط. لكلّ تغيير:
   - اقرأ السياق الكامل حول `file:line` المذكور (~10 أسطر قبل وبعد).
   - تأكّد من اسم الحقول الفعليّ في الـ snapshots (مثل
     `retest_close_above_midpoint`) قبل الاستعمال — استبدل الأسماء
     المقترحة في المواصفة بالأسماء الفعليّة من القراءة.
   - إن لم تجد دالّة أو حقلًا بالاسم المذكور في المواصفة، ارفع
     السؤال — لا تخترع.

٥. تغيير ٢ (Invalidation guard) يحتاج وصولًا لشمعة مغلقة. استعمل
   `m_candle_cache` إن متوفّر، وإلّا `iTime`/`iClose`/`CopyRates` مع shift>=1.
   **ممنوع shift=0**.

٦. تغيير ٥ (Age guard): تأكّد من أن `detector_snapshot.fvg_newer_candle_time`
   حقلٌ موجود في `FalconFvgMicroDetectorSnapshot`. إن كان اسمه مختلفًا،
   استعمل الفعليّ.

٧. حذف الـ .ex5 ثمّ إعادة بناء صريحة. تحقّق من إصدار التقارير
   = `R2_1 / FvgMicroSpecAligned`.

٨. **توقّف عند هذه النقطة.** لا commit. لا تشغيلات. أظهر:
   - git diff --stat
   - تأكيد البناء بلا أخطاء.
   - LastWriteTime للـ .ex5 الجديد.
   - الأسماء الفعليّة للحقول التي استعملتها (مقابل المقترح في المواصفة).

سيُجري المشغّل التشغيلَين (smoke + April) يدويًّا.

عند أيّ تعارض: المواصفة تحكم. عند أيّ غموض في أسماء الحقول/الدوالّ:
اسأل، لا تخترع.
```
