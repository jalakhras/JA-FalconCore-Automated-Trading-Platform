# JA FalconCore — R1.2d Completion SPEC
## ربط S00 الكامل بـ Reconciliation + تفريد `trade_id`

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.2d (commit `757aade`) &nbsp;|&nbsp; **Tag:** `EA_VERSION_TAG = R1_2d` (unchanged)

---

## السياق

R1.2d (commit `757aade`) أوصل S00 إلى `CFalconReportWriter::RegisterClosedTrade` — فظهرت صفقات S00 في `TradeLifecycle.csv` و `Summary.csv` (TotalTrades=536 في baseline أبريل-مايو 2026). لكن استكشاف ما بعد التطبيق كشف ثلاث فجوات إبلاغيّة باقية لم تُخصِّصها مواصفة R1.2d الأصليّة:

1. **`BrokerPaperTradeReconciliation.csv` لا يربط صفقات S00 بسجلّ Paper.** كل صفّ S00 يحمل `BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE` رغم وجود سجلّ Paper مطابق في `m_paper_final_records[]` — لأنّ `TryManagedCloseFromS00Trade` (المسار البديل الذي بنته R1.2c بمعاملات ثلاثة) لا يستدعي `StorePaperFinalRecord`، بينما المسار legacy `TryManagedCloseFromLifecycleRecord` يفعل ذلك سطرًا أوّل (`FalconBrokerEntryBridge.mqh:1598`).
2. **`trade_id` مكرّر.** في الـ baseline ظهر مثال `S00_SCALP_FVG_1777946400` مرّتين — لأنّ صيغة الـ id بسيطة `"S00_SCALP_FVG_" + IntegerToString((long)entry_time)` بدون عدّاد تسلسليّ، وبعد same-bar close تستطيع FVG تالية على نفس `bar1` الدخول بنفس `entry_time` فينتج id متطابق.
3. **`shadow_id` و `trade_id` يُبنيان مرّتين** بالصيغة نفسها في موقعين منفصلين (`S00_EntryLogic.mqh:754` و `787`) — مصدر فجوة محتملة إن تغيّر أحدهما يومًا.

> القالب الذهبيّ legacy ينجح في كلّ هذا لأنّه يمرّر `FalconTradeLifecycleRecord` كاملًا للـ Bridge، الذي يخزّنه في `m_paper_final_records[]` ثمّ يستعمله الـ Reconciliation عند رصد إغلاق البروكر. التقرير الكامل: `C:\Users\jalak\.claude\plans\ja-falconcore-valiant-hellman.md`.

**الهدف:** سدّ الفجوات الثلاث **بتعديلات إبلاغيّة بحتة** — دون لمس قرار S00 التداوليّ ولا منطق الـ Bridge ولا المسار legacy ولا بنية `FalconTradeLifecycleRecord`.

---

## نطاق التغيير — ملفّان فقط

### إصلاح 1 — `Execution/FalconBrokerEntryBridge.mqh`

**التغيير:** نقل `StorePaperFinalRecord(const FalconTradeLifecycleRecord &record)` من `private:` إلى `public:`.
- **النطاق:** تغيير وصول فقط. **جسم الدالّة يبقى verbatim** — نفس 16 سطر الموجودة حاليًّا (L125-140 قبل التغيير).
- **التقنية:** إدخال مُحدِّدَي `public:` قبلها و `private:` بعدها لعزل تغيير الوصول داخل القسم الخاصّ الكبير (الذي يمتدّ من L28 إلى L1248).
- **لماذا public:** كي تستطيع `CS00EntryLogic::CloseActiveTrade` استدعاؤها من خارج الكلاس عبر `g_broker_entry_bridge`.

### إصلاح 2 — `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` — `CloseActiveTrade`

**التغيير:** إدراج سطر **بين** `RegisterClosedTrade` و `TryManagedCloseFromS00Trade`:

```mql5
g_report_writer.RegisterClosedTrade(lifecycle_record);
g_broker_entry_bridge.StorePaperFinalRecord(lifecycle_record);   // ← R1.2d completion
g_broker_entry_bridge.TryManagedCloseFromS00Trade(m_active_trade.trade_id, exit_price, reason, g_report_writer);
```

- **الترتيب الصارم:** Register → Store → Close. الـ Bridge يحتاج السجلّ في `m_paper_final_records[]` **قبل** أن يُرسل deal العكسيّ، لأنّ `OnTradeTransaction → ObserveTradeTransactionExit → FindPaperFinalRecord(link.trade_id, …)` يجري بعد ميلي‑ثانية من قبول الـ deal.
- **لا تغيير سلوكيّ في القرار:** السطر إبلاغيّ بحت — يُسجِّل نسخة من نفس `lifecycle_record` التي يستعملها `RegisterClosedTrade`.
- **يُحدَّث تعليق الـ ordering** أعلى الـ gate ليصبح ثلاث مراحل (Register → Store → Close) بدل اثنتين.

### إصلاح 3 — `Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh` — تفريد `trade_id`

**ثلاث تعديلات:**

1. **عضو جديد خاصّ** في `CS00EntryLogic` (تجاور `m_trades_file_name`):
   ```mql5
   int m_trade_sequence;
   ```
2. **تهيئة في الـ constructor** (تجاور باقي init):
   ```mql5
   m_trade_sequence = 0;
   ```
3. **بناء id واحد فريد** عند الفتح (موقع `s00_record.shadow_id`):
   ```mql5
   m_trade_sequence++;
   const string s00_unique_id = "S00_SCALP_FVG_"
                              + IntegerToString((long)m_active_trade.entry_time)
                              + "_"
                              + IntegerToString(m_trade_sequence);
   FalconShadowTradeRecord s00_record;
   ZeroMemory(s00_record);
   s00_record.shadow_id = s00_unique_id;
   …
   ```
   ثمّ في موقع `m_active_trade.trade_id`:
   ```mql5
   m_active_trade.trade_id = s00_unique_id;   // يعيد استعمال نفس النصّ — لا يُعاد البناء
   ```

- **الصيغة الجديدة:** `S00_SCALP_FVG_<unix_entry_bar_time>_<sequence>` — متوافقة prefix-wise مع القديمة.
- **مصدر `entry_time`:** كما هو — `bar1.time` (وقت شمعة M5 المغلقة).
- **التسلسل:** عدّاد instance-monotonic — يصمد عبر same-bar entries المتعدّدة داخل نفس الـ OnTick.

---

## القيود الصارمة (لا تُخترق)

- **لا تغيير في منطق دخول S00 أو قراره التداوليّ.** الإصلاحات إبلاغيّة بحتة. تفريد `trade_id` يغيّر صيغة المعرّف فقط.
- **لا منع للدخول المتعدّد على نفس الشمعة.** السلوك يبقى كما هو — صفقة same-bar exit ثمّ FVG تالية يدخل على نفس bar صحيح وظيفيًّا، فقط معرّفهما الآن مختلف. (قرار منع الدخول المتعدّد مؤجَّل إلى backlog item #67.)
- **لا لمس للمسار legacy** — `TryManagedCloseFromLifecycleRecord` لا تتغيّر سطرًا واحدًا.
- **لا لمس لجسم `StorePaperFinalRecord`** — تغيير الوصول فقط.
- **لا تعديل بنية `FalconTradeLifecycleRecord`** ولا أيّ خطوة من سلسلة الـ 12 Apply.
- **لا `OrderModify` / `BrokerModify` / `TRADE_ACTION_SLTP`.**
- **لا lookahead** — لا قراءات شموع جديدة، لا أسعار live.
- **`EA_VERSION_TAG` يبقى `R1_2d`** — هذا إكمال داخل نفس النسخة، لا قفزة.
- **لا مطاردة breach `paper_state_snapshot`** قبل تأكيد ما إذا كان موجودًا في baseline أيضًا (مؤجَّل إلى backlog item #68).

---

## التحقّق

### A. ترجمة
```
metaeditor64.exe /compile:JA_FalconCore_Automated_Trading_Platform.mq5
→ Result: 0 errors, 0 warnings
→ Problems window: 0 issues
```

### B. الـ Summary الموجود (baseline أبريل 2026، قبل الإصلاحات)
- `TotalTrades = 536`
- التسعة `*EvaluatedTrades = 536` كلّها (DynamicLot, WeeklyStability, MarketCloseGuard, StopNewTrades, CloseSafety, PaperStateSnapshot, SessionBoundaryCheckpoint, CapitalFlow + Force/NoEntry)
- `TradeLifecyclePhysicalRows = 536`, `TradeLifecyclePhysicalRowStatus = PASS`
- `PaperStateSnapshotWrittenRows = 0` → **هذا الفحص الوحيد المُطلَق** `total_trades != paper_state_snapshot_written_rows` (FalconReportWriter.mqh:4012-4013) — `InvariantBreaches = 1`
- المسار `PaperStateRecoveryMode = FOUNDATION_ONLY_STATE_RESTORE_DISABLED` يدلّ على أنّ snapshot معطَّل تصميمًا — وهذا موجود في baseline قبل R1.2d أيضًا، فلا يُلامس في هذه المرحلة.

### C. اختبار باكتيست بعد التطبيق (يُجريه المشغّل)
1. تشغيل tester بنفس profile (R1.2d, VirtualTrailingBridge, ExecutionON, FixedLot, April 2026).
2. التحقّقات المتوقَّعة:
   - `BrokerPaperTradeReconciliation.csv`: **صفر صفوف** بـ `BROKER_ONLY_TRADE_NOT_IN_LOCK_PAPER_LIFECYCLE` لصفقات S00.
   - `TradeLifecycle.csv`: لا `trade_id` مكرّر (افحص بـ `awk -F, '{print $X}' | sort | uniq -d`).
   - `Summary.csv`: `TotalTrades` ثابت أو متناقص بمقدار صغير (إن كانت الـ 4 صفقات الإضافيّة تنتج عن تكرار).
   - الـ baseline legacy `585.17 / 1104.89 / 157.49` يبقى byte-for-byte (لأنّ S00_RealExecution = false → لا أحد من الإصلاحات الثلاثة يُفعَّل).

---

## الملفّات المتأثّرة

```
Execution/FalconBrokerEntryBridge.mqh                      (~10 سطور إضافيّة: public:/private: + تعليق)
Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh             (~25 سطر تعديل: عضو + init + بناء id + تعليق)
Docs/Specs/JA_FalconCore_R1_2d_Completion_SPEC.md           (جديد — هذا الملفّ)
Docs/ReviewNotes/R1_2d_Review_Notes.md                      (إضافة قسم §11 Completion)
Docs/Ideas_Backlog.md                                       (إضافة #67 و #68)
```

**لا تُلامس:** `JA_FalconCore_Automated_Trading_Platform.mq5`، `FalconReportWriter.mqh`، `FalconRiskLifecycleProcessor.mqh`، `FalconTradeLifecycleRecord`، أيّ ملفّ legacy.
