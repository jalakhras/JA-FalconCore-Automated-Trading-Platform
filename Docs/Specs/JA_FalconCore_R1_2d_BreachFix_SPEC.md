# JA FalconCore — R1.2d BreachFix SPEC
## تصحيح القيمة المكتوبة في `record.structural_sl` لمسار S00

**Branch:** `refactor` &nbsp;|&nbsp; **Base:** R1.2d Completion (commit `9656168`) &nbsp;|&nbsp; **Tag:** `EA_VERSION_TAG = R1_2d` (دون تغيير)

---

## السياق

تشغيل R1.2d (الـ 3 أشهر، S00 ExecutionON) أظهر `InvariantBreaches = 2` بينما baseline الـ legacy أظهر `1`. الـ breach المشترك هو `paper_state_snapshot_written_rows != total_trades` (دَيْن قديم، يسبق R1.2d). الـ breach الإضافيّ الواحد هو الذي يحدثه مسار S00 — حدّده تقرير الاستكشاف بدقّة.

**التشخيص (مفصَّل في `C:\Users\jalak\.claude\plans\ja-falconcore-valiant-hellman.md`):**

S00 يحرّك `m_active_trade.stop_loss = entry_price` عند تسلّح breakeven (`S00_EntryLogic.mqh:465`). عند إغلاق صفقة على نقطة BE، `m_active_trade.stop_loss == m_active_trade.entry_price`. الدالّة `BuildLifecycleRecordFromS00Trade` كانت تكتب هذا الـ stop المُحرَّك في `record.structural_sl`. السلسلة الناتجة:

```
record.structural_sl == record.entry_price
  → Apply #8 (FalconRiskLifecycleProcessor.mqh:1010):
       risk_points = MathAbs(entry_price - structural_sl) = 0
       record.falcon_min_lot_risk_points = 0  [L1027]
  → Apply #10 (L1171, L1200-1204):
       falcon_dlm_risk_points = 0 → falcon_dlm_decision = "INVALID"
       reason = "CAPITAL_OR_RISK_BUDGET_OR_STRUCTURAL_RISK_UNKNOWN"
  → FalconReportWriter.mqh:4831:
       dynamic_lotsizing_invalid_trades++
  → FalconReportWriter.mqh:3978:
       invariant_breaches++   →  InvariantBreaches +1
```

legacy آمن لأنّ `ShadowToLifecycle` يقرأ `structural_sl` من `FalconShadowTradeRecord` المُعبَّأ عند **الفتح** في `StageTradePlan` — لا يتعرّض لأيّ mutation.

**الهدف:** ملف واحد، حقل واحد جديد، ثلاث تعديلات سطرية — يحفظ الـ structural SL الأصليّ في حقل منفصل وقت الفتح، ويقرأ منه عند بناء سجلّ الـ lifecycle.

---

## نطاق التغيير — ملفّ واحد فقط

`Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh`

### 1. حقل جديد في بنية `S00PaperTrade`
مجاورًا لـ `stop_loss`:
```mql5
double  stop_loss;                 // (موجود) mutated by BE arming
double  original_structural_sl;    // جديد — frozen at open from plan.stop_loss
```

### 2. تهيئة الحقل عند فتح الصفقة
في step 3e، مباشرة بعد `m_active_trade.stop_loss = plan.stop_loss;`:
```mql5
m_active_trade.original_structural_sl = plan.stop_loss;
```
يُكتَب **مرّة واحدة** عند الفتح من `plan.stop_loss` (لا من `m_active_trade.stop_loss`، حتى لو كانتا متطابقتين في تلك اللحظة — لتجنّب أيّ ارتباط مع المسار المتغيّر).

### 3. القراءة في `BuildLifecycleRecordFromS00Trade`
استبدال:
```mql5
record.structural_sl = m_active_trade.stop_loss;          // كان (يقرأ القيمة المُحرَّكة)
```
بـ:
```mql5
record.structural_sl = m_active_trade.original_structural_sl;   // جديد (يقرأ الأصليّ)
```

---

## القيود الصارمة (لا تُخترق)

- **لا تمسّ منطق الـ exit** — `RunExitEvaluation` يبقى يقرأ `m_active_trade.stop_loss` المُحرَّك (هذا صحيح لمنطق التداول).
- **لا تمسّ منطق تسلّح breakeven** — السطر `m_active_trade.stop_loss = m_active_trade.entry_price;` في `RunExitEvaluation` (L465) يبقى كما هو.
- **لا تمسّ `exit_price` ولا `result_points`** ولا أيّ حساب نتيجة.
- **لا تمسّ مسار legacy** ولا `FalconShadowTradeRecord` (السطر 787 الذي يكتب `s00_record.structural_sl = m_active_trade.stop_loss` يبقى كما هو — يُنفَّذ عند الفتح حيث `stop_loss == original_structural_sl` بالضبط).
- **لا تعديل لبنية `FalconTradeLifecycleRecord`** ولا أيّ خطوة من سلسلة الـ Apply.
- **لا `OrderModify` / `BrokerModify` / `TRADE_ACTION_SLTP`** ولا lookahead.
- **`EA_VERSION_TAG = R1_2d`** يبقى كما هو.
- **`original_structural_sl`** يُهيَّأ من `plan.stop_loss` عند الفتح **فقط** — لا يُقرأ من `m_active_trade.stop_loss` لاحقًا أبدًا.

---

## التحقّق

### A. ترجمة
```
metaeditor64.exe /compile:JA_FalconCore_Automated_Trading_Platform.mq5
→ Result: 0 errors, 0 warnings, 12918 ms elapsed, cpu='X64 Regular'
```
Problems window: 0 issues.

### B. باكتيست بعد التطبيق (يُجريه المشغّل)
1. تشغيل tester بنفس profile الـ 3 أشهر (R1.2d, S00 ExecutionON).
2. التحقّقات المتوقَّعة:
   - `Summary.csv`: `InvariantBreaches = 1` (المشترك paper_state_snapshot فقط).
   - عمود `DynamicLotEvaluatedTrades = TotalTrades = FixedModeTrades + DynamicModeTrades` (صفر INVALID).
   - الـ baseline legacy `585.17 / 1104.89 / 157.49` (مع `S00_RealExecution = false`) يبقى byte-for-byte (لأنّ الـ gate المغلقة تمنع تنفيذ `BuildLifecycleRecordFromS00Trade` أصلًا).

### C. اختبار العقل (sanity)
- صفقة S00 تُسلَّح BE ثمّ تُغلَق على BE:
  - `m_active_trade.stop_loss = entry_price` (بعد L465)
  - `m_active_trade.original_structural_sl = plan.stop_loss` (محفوظ من L668)
  - `record.structural_sl = plan.stop_loss` → `risk_points > 0` → `decision != "INVALID"` ✓
- صفقة S00 تُغلَق على structural stop (دون تسلّح BE):
  - `m_active_trade.stop_loss == plan.stop_loss` (لم يتغيّر)
  - `m_active_trade.original_structural_sl == plan.stop_loss` (مساوٍ تمامًا)
  - السلوك المُبلَّغ نفسه قبل وبعد الإصلاح ✓
- صفقة S00 تُغلَق على TP أو timeout:
  - `m_active_trade.stop_loss` لا يهمّ — `record.structural_sl` يأتي من `original_structural_sl` المحفوظ ✓

---

## الملفّات المتأثّرة

```
Strategies/S00_ScalpFvgMicro/S00_EntryLogic.mqh             (~12 سطر: حقل + تهيئة + قراءة + تعليقات)
Docs/Specs/JA_FalconCore_R1_2d_BreachFix_SPEC.md            (جديد — هذا الملفّ)
Docs/ReviewNotes/R1_2d_Review_Notes.md                      (إضافة قسم §12 BreachFix)
Docs/Ideas_Backlog.md                                       (إضافة #69)
```

**لا تُلامس:** أيّ ملفّ آخر. `FalconReportWriter.mqh`، `FalconRiskLifecycleProcessor.mqh`، `FalconBrokerEntryBridge.mqh`، `FalconShadowExecutor.mqh`، `JA_FalconCore_Automated_Trading_Platform.mq5` — كلّها دون تغيير.
