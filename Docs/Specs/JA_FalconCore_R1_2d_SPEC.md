# JA FalconCore — R1.2d
## ربط تسجيل S00 في طبقة التقارير المركزية (TradeLifecycle)
### مواصفات للتسليم إلى Claude Code

> **الهدف:** جعل S00 تُسجّل كل صفقة مُغلَقة في طبقة `TradeLifecycle`
> المركزية — فتمتلئ `Summary` و`TradeLifecycle` و`Reconciliation`،
> ويكتمل أخيرًا التقرير المزدوج (ورقيّ مقابل حقيقيّ).
>
> **الأساس:** فرع `refactor`، بعد commit `ae42caa` (R1.2c).
> **مرجع الاستكشاف:** تقرير استكشاف R1.2d (المحاور الأربعة).

---

## 0. لماذا R1.2d — التشخيص

R1.2c ربط إغلاق S00 الحقيقيّ بنجاح: 25/25 صفقة أُغلقت بمنطق S00
(`EXPERT_CLOSE_EXIT`)، النتيجة الحقيقية +0.10$ مقابل −86.42$ في R1.2b.

**لكن** التقارير المركزية خرجت فارغة: `Summary` يقول `TotalTrades=0`،
وملفّات `TradeLifecycle` و`RebasedPaperComparison` و`TradeManagementEventTimeline`
فارغة تمامًا. والنظام نفسه رصد المشكلة في كل صفّ Reconciliation:
`BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE` — *لا سجلّ Paper
TradeLifecycle لهذه الصفقة؛ مخالفة LOCK parity*.

**السبب** (من تقرير الاستكشاف): S00 تُغلق في دفترها الورقيّ الخاصّ عبر
`CloseActiveTrade → AppendTradeRow`، ولا تبني `FalconTradeLifecycleRecord`
ولا تستدعي `RegisterClosedTrade`. وطبقة `TradeLifecycle/Summary` تُملأ
**فقط** من `RegisterClosedTrade`.

R1.2d يسدّ هذه الفجوة: S00 تبني السجلّ وتستدعي `RegisterClosedTrade`.

---

## 1. الهدف

عند كل إغلاق صفقة في S00 (الأسباب الثلاثة: TARGET، STOP، TIMEOUT)،
تبني S00 سجلّ `FalconTradeLifecycleRecord` من `m_active_trade` وتستدعي
`g_report_writer.RegisterClosedTrade(record)` — فتُسجَّل الصفقة في
طبقة التقارير المركزية.

**يؤجَّل للمرحلة التالية:** تشخيص ضعف S00 في التنفيذ الحقيقيّ (84%
من الصفقات تُغلق بالوقف). R1.2d يكمل الإبلاغ فقط؛ التشخيص يأتي بعده
على أساس التقرير المزدوج المكتمل.

---

## 2. القيود الصارمة (ما يجب ألا يحدث)

- **لا تغيير في منطق دخول S00 ولا منطق إغلاقها** (الذي بُني في R1.2c).
  R1.2d يضيف **تسجيلًا** فقط — لا يمسّ القرار التداوليّ.
- **لا لمس مسار الاستراتيجية القديمة.** كتلة `if(!S00_RealExecution)`
  في `OnTick` تبقى **حرفيًّا** كما هي. لا استدعاء `RegisterClosedTrade`
  جديد خارج بوّابة S00.
- **معيار التحقّق محفوظ:** اختبار FixedLot April بالبوّابات مغلقة
  (`S00_RealExecution=false`) يجب أن يبقى **بالضبط**
  `585.17 / 1104.89 / 157.49`. أي انحراف = شيء كُسِر.
- **لا حساب يدويّ لـ P&L.** لا تستدعِ `FalconFinalizeTradeMetrics`
  يدويًّا — `RegisterClosedTrade` يستدعيه. ولا تحسب USD أو نقاطًا أو
  WIN/LOSS داخل S00.
- **لا تعديل بنية `FalconTradeLifecycleRecord`** ولا سلسلة الـ Apply.
- **لا `OrderModify`/`BrokerModify`/`TRADE_ACTION_SLTP`** (قاعدة دائمة).
- **لا lookahead** — شموع مغلقة فقط (قاعدة دائمة).
- التسجيل خلف بوّابة S00 الثلاثية فقط — صفقات S00 لا تُسجَّل حين
  `S00_RealExecution=false`.

---

## 3. المدخلات الجديدة

**لا مدخلات جديدة في R1.2d.** المرحلة كلّها ربط داخليّ — لا قيمة
يضبطها المستخدم ولا مفتاح جديد.

---

## 4. تحديث الإصدار

**قبل R1.2d:**
```
EA_VERSION_TAG = "R1_2c"
EA_BUILD_TAG   = "RealisticCloseExecution"
```

**بعد R1.2d:**
```
EA_VERSION_TAG = "R1_2d"
EA_BUILD_TAG   = "CentralLifecycleRegistration"
```

ملفّ: `Core/FalconConstants.mqh:10-11`.

---

## 5. بروتوكول العمل — الخطوات المدقّقة

### 5.1 — دالة بناء السجلّ في S00

في `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh`، أضِف دالة
خاصّة جديدة تبني `FalconTradeLifecycleRecord` من `m_active_trade`:

```cpp
void BuildLifecycleRecordFromS00Trade(FalconTradeLifecycleRecord &record)
{
   // متغيّر struct محليّ في MQL5 مُصفّر تلقائيًّا — لا حاجة لـ Reset.
   // نملأ فقط الحقول الإلزامية الـ ~18؛ الباقي يكتبه RegisterClosedTrade.

   // — الهوية —
   record.trade_id      = m_active_trade.trade_id;       // من R1.2c
   record.strategy_id   = "S00_SCALP_FVG";
   record.strategy_name = "S00 ScalpFvgMicro";
   record.engine_id     = "S00_SCALP_FVG";               // طابِق BrokerExecutionLifecycle

   // — التوجيه —
   record.direction = (m_active_trade.direction == S00_FVG_DIR_BULLISH
                         ? FALCON_DIRECTION_BUY
                         : FALCON_DIRECTION_SELL);
   record.stage   = FALCON_TRADE_STAGE_PAPER;            // انظر القيد التصميميّ أدناه
   record.outcome = FALCON_TRADE_OUTCOME_OPEN;           // مؤقّت — Finalize يعيد حسابه

   // — التوقيت —
   record.entry_time = m_active_trade.entry_time;
   record.exit_time  = m_active_trade.exit_time;

   // — الأسعار والحجم —
   record.entry_price   = m_active_trade.entry_price;
   record.exit_price    = m_active_trade.exit_price;
   record.lot_size      = m_active_trade.lot_size;
   record.structural_sl = m_active_trade.stop_loss;
   record.tp1           = m_active_trade.target;

   // P&L تبقى صفرًا (التصفير التلقائيّ) — FalconFinalizeTradeMetrics
   // يحسبها من direction/entry_price/exit_price/lot_size.
}
```

> **قيد تصميميّ — stage:** المواصفة تختار `FALCON_TRADE_STAGE_PAPER`
> لأن S00 في R1.2c/d تُنفّذ فعليًّا على الـ Bridge (ليست محاكاة
> shadow بحتة). **لكن — تحقّق أوّلًا:** افحص `ApplyTradeLifecycleChain`
> وسلسلة الـ Apply الـ 12؛ إن وُجد أيّ تفرّع سلوكيّ حسب `stage`،
> استخدم `FALCON_TRADE_STAGE_SHADOW` (نفس legacy) وأبلغ المستخدم بأن
> القرار غُيِّر. إن كان `stage` حقلًا وصفيًّا فقط — أبقِ `PAPER`.

### 5.2 — استدعاء التسجيل في CloseActiveTrade

في نفس الملفّ، دالة `CloseActiveTrade(...)`. في R1.2c أضفنا استدعاء
`TryManagedCloseFromS00Trade` داخل بوّابة ثلاثية بعد `AppendTradeRow`.
R1.2d يضيف التسجيل **في نفس البوّابة، قبل استدعاء البريج**:

```cpp
   AppendTradeRow(m_active_trade);

   // R1.2d: تسجيل مركزيّ في طبقة TradeLifecycle
   if(MQL_TESTER && EnableRealExecution && S00_RealExecution)
   {
      FalconTradeLifecycleRecord lifecycle_record;
      BuildLifecycleRecordFromS00Trade(lifecycle_record);
      g_report_writer.RegisterClosedTrade(lifecycle_record);
   }

   // R1.2c: ربط الإغلاق الحقيقيّ (موجود)
   if(MQL_TESTER && EnableRealExecution && S00_RealExecution)
   {
      g_broker_entry_bridge.TryManagedCloseFromS00Trade(
         m_active_trade.trade_id, exit_price, reason, g_report_writer);
   }
```

> **ترتيب مقصود:** التسجيل (`RegisterClosedTrade`) **قبل** الإغلاق
> الحقيقيّ (`TryManagedCloseFromS00Trade`) — كي يوجد سجلّ Paper
> TradeLifecycle حين يرصد الـ Bridge الإغلاق، فيجد الـ Reconciliation
> التطابق. (يمكن دمج البوّابتين في واحدة إن كان أنظف — قرار تنفيذيّ.)

### 5.3 — التحقّق من إتاحة البنية لـ S00

تأكّد أن `S00_EntryLogic.mqh` يرى تعريف `FalconTradeLifecycleRecord`
وenum الاتجاه والمرحلة (عبر سلسلة `#include` القائمة). إن لم يرَها،
**أبلغ المستخدم** — لا تُعِد ترتيب الـ includes دون مراجعة.

### 5.4 — تنظيف ملفّات SPEC

- احذف `JA_FalconCore_R1_2c_SPEC.md` من **جذر المشروع** (مرحلتها
  اكتملت ومحفوظة في commit `ae42caa`).
- ضع `JA_FalconCore_R1_2d_SPEC.md` (هذا الملفّ) في `Docs/Specs/`.

### 5.5 — البنود الثابتة

راجع نافذة Problems في VS Code — صفر مشاكل. اكتب ملفّ مراجعة
`Docs/ReviewNotes/R1_2d_Review_Notes.md`. سجّل أيّ أفكار في
`Docs/Ideas_Backlog.md` (مرشّح: "مراجعة دلالة stage لاستراتيجيات
التنفيذ الحقيقيّ"). commit واحد.

---

## 6. معايير القبول

✅ **الترجمة:** F7 — صفر errors، صفر warnings.

✅ **معيار التحقّق الحرج:** اختبار FixedLot April بـ
`S00_RealExecution=false` → `RawNetUSD=585.17`،
`FinalWorkingNetUSD=1104.89`، حساب البروكر `200 → 157.49`. **بالضبط.**
هذا يثبت أن مسار legacy لم يُمَسّ.

✅ **التقارير تمتلئ:** اختبار 3 أشهر بـ `S00_RealExecution=true`:
- `Summary`: `TotalTrades > 0` (متوقّع ≈25).
- `TradeLifecycle.csv`: صفّ لكل صفقة S00 مُغلَقة.
- `BrokerPaperTradeReconciliation`: لم يعد يقول
  `BROKER_ONLY_TRADE_NOT_IN_LOCK` — بل يجد تطابق Paper مقابل Broker.

✅ **التقرير المزدوج يعمل:** لكل صفقة يظهر الورقيّ (TradeLifecycle)
مقابل الحقيقيّ (BrokerExecutionLifecycle) في Reconciliation.

✅ **حرّاس السلامة:** `BrokerModifySent=0`، `RuntimeSLChanged=0`،
`InvariantBreaches=0`.

❌ **علامات الفشل:** خطأ ترجمة؛ انحراف رقم التحقّق 585/1104/157؛
`TotalTrades` ما زال 0؛ Reconciliation ما زال يقول broker-only؛
runtime error.

---

## 7. بعد المرحلة

**رسالة commit المقترحة:**
```
R1.2d - S00 closed trades registered in central TradeLifecycle; dual report complete
```

**الخطوة التالية:** تشخيص ضعف S00 في التنفيذ الحقيقيّ — لماذا 84%
من الصفقات تُغلق بالوقف، وهل حماية الـ breakeven تُفعَّل أصلًا. يُبنى
على التقرير المزدوج المكتمل من R1.2d.

---

## ملحق — Prompt لبدء العمل في Claude Code

**فعّل وضع accept edits / auto mode أولًا.** اقرأ `Docs/Specs/JA_FalconCore_R1_2d_SPEC.md` ونفّذ R1.2d — ربط تسجيل S00 في طبقة TradeLifecycle المركزية: في `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` أضِف دالة خاصّة `BuildLifecycleRecordFromS00Trade(FalconTradeLifecycleRecord &record)` تبني السجلّ من `m_active_trade` — تملأ **فقط** الحقول الإلزامية الـ ~18: `trade_id` (من R1.2c)، `strategy_id="S00_SCALP_FVG"`، `strategy_name="S00 ScalpFvgMicro"`، `engine_id="S00_SCALP_FVG"`، `direction` (حوّل `S00_FVG_DIR_BULLISH→FALCON_DIRECTION_BUY` وإلا `FALCON_DIRECTION_SELL`)، `stage=FALCON_TRADE_STAGE_PAPER`، `outcome=FALCON_TRADE_OUTCOME_OPEN`، `entry_time`، `exit_time`، `entry_price`، `exit_price`، `lot_size`، `structural_sl=m_active_trade.stop_loss`، `tp1=m_active_trade.target`. اترك حقول الـ P&L صفرًا (التصفير التلقائيّ للـ struct المحليّ). في دالة `CloseActiveTrade()`، بعد `AppendTradeRow(m_active_trade);` وقبل استدعاء `TryManagedCloseFromS00Trade`، أضِف داخل بوّابة `if(MQL_TESTER && EnableRealExecution && S00_RealExecution)`: بناء `FalconTradeLifecycleRecord lifecycle_record;` ثم `BuildLifecycleRecordFromS00Trade(lifecycle_record);` ثم `g_report_writer.RegisterClosedTrade(lifecycle_record);`. في `Core/FalconConstants.mqh` غيّر `EA_VERSION_TAG` إلى `"R1_2d"` و`EA_BUILD_TAG` إلى `"CentralLifecycleRegistration"`. ترجمة نهائية: F7 — يجب صفر errors.

**تحقّق قبل الالتزام:** افحص `ApplyTradeLifecycleChain` وسلسلة الـ 12 Apply — إن وُجد تفرّع سلوكيّ حسب `stage`، استخدم `FALCON_TRADE_STAGE_SHADOW` بدل `PAPER` وأبلغني. إن لم يرَ `S00_EntryLogic.mqh` تعريف `FalconTradeLifecycleRecord`، أبلغني — لا تُعِد ترتيب الـ includes دون مراجعة.

**القيود الصارمة — لا تُخترق:** لا تغيّر منطق دخول S00 ولا منطق إغلاقها (R1.2c). كتلة `if(!S00_RealExecution)` في `OnTick` تبقى حرفيًّا كما هي — لا استدعاء `RegisterClosedTrade` جديد خارج بوّابة S00. لا تستدعِ `FalconFinalizeTradeMetrics` يدويًّا — `RegisterClosedTrade` يستدعيه. لا تعديل بنية `FalconTradeLifecycleRecord` ولا سلسلة الـ Apply. لا `OrderModify`/`BrokerModify`/`TRADE_ACTION_SLTP`. لا lookahead. **اختبار FixedLot April بـ `S00_RealExecution=false` يجب أن يبقى بالضبط 585.17 / 1104.89 / 157.49.**

احذف `JA_FalconCore_R1_2c_SPEC.md` من جذر المشروع (مرحلتها اكتملت ومحفوظة في commit ae42caa). ضع مواصفة R1.2d في `Docs/Specs/`. راجع نافذة Problems — صفر مشاكل. اكتب `Docs/ReviewNotes/R1_2d_Review_Notes.md`. سجّل في `Docs/Ideas_Backlog.md` فكرة «مراجعة دلالة stage لاستراتيجيات التنفيذ الحقيقيّ». حفظ واحد فقط: `git add -A && git commit -m "R1.2d - S00 closed trades registered in central TradeLifecycle; dual report complete"`. بعد الانتهاء أكّد `git diff --stat` (متوقّع: تغييرات في ملفّين كود — `S00_EntryLogic.mqh`، `FalconConstants.mqh` — + ملفّات التوثيق). أخبرني بنتائج الترجمة وناتج git diff --stat وقرار stage والملاحظات.
