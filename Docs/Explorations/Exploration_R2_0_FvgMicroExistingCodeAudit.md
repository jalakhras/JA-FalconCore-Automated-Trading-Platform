# استكشاف R2.0 — Audit لكود FVG_MICRO_RETEST الموجود

> **النوع:** استكشاف قراءة-فقط (لا كود، لا تعديل، لا commit، لا بناء).
> **الإصدار:** قبل R2.1 — لا رفع `EA_VERSION_TAG` (يبقى `R1_7 / GateLeakFix`).
> **التاريخ:** 31 مايو 2026.
> **الفرع:** `refactor`.
> **آخر commit:** `4300425` (docs R1.7) فوق `6ced7c2` (R1.7 — إغلاق تسرّب الـ Gate).
> **المرجع:** `Spec_R2_0_Exploration_FvgMicroAudit.md`. القيود §٣ مُحترَمة: توصيفٌ
> للحالة فقط — لا اقتراح إصلاحٍ كوديّ، لا حكم نوعيّ، لا توسيع نطاق.

**تنبيه نطاق مهمّ:** يوجد منظومتان متمايزتان تحملان «FvgMicro» في الاسم:
1. **`FVG_MICRO_RETEST` / `SCALP.FVG_MICRO`** — الـ pipeline الظلّيّ القديم في
   `JA_FalconCore_Automated_Trading_Platform.mq5` (الفئات `CFalconFvgMicro*`) +
   `Reporting/FalconReportWriter.mqh`. **هذا هو موضوع هذا الاستكشاف.**
2. **`S00_ScalpFvgMicro/`** — استراتيجيّة S00 المستقلّة (`Enable_S00_FvgScalp`)،
   عملُ R1.1a–c. **ليست موضوع هذا الاستكشاف** (خارج `FVG_MICRO_RETEST`).

---

## المحور الأوّل — مسح المواضع

### ١. الملفّات التي تحوي ذِكرًا (FvgMicro / FVG_MICRO / fvg_micro) — عدد الأسطر ذات الصلة

| الملفّ | FvgMicro | FVG_MICRO | fvg_micro |
|---|---|---|---|
| `JA_FalconCore_Automated_Trading_Platform.mq5` | 85 | 47 | 43 |
| `Reporting/FalconReportWriter.mqh` | 48 | 1 | 53 |
| `Core/FalconDataStructures.mqh` | 10 | — | — |
| `Execution/FalconBrokerEntryBridge.mqh` | — | 15 | — |
| `Execution/FalconExecutionInputs.mqh` | — | 2 | — |
| `Router/FalconRouterInputs.mqh` | 2 | — | — |
| `Router/FalconStrategyRegistry.mqh` | 1 | 1 | — |
| `Router/FalconStrategyAdapterShell.mqh` | — | 2 | — |
| `Risk/FalconRiskInputs.mqh` | — | 1 | — |
| `TradeManagement/FalconTradeManagementCoordinator.mqh` | — | 2 | — |
| `Strategies/S00_ScalpFvgMicro/*` (6 ملفّات — منظومة S00 منفصلة) | 17 | 4 | — |
| `Strategies/S01_Harness/S01_EntryLogic.mqh` | — | 1 | — |

الثقل الأساسيّ لمنطق `FVG_MICRO_RETEST` في `JA_FalconCore...mq5` (الفئات الخمس
+ الـ pipeline) و`Core/FalconDataStructures.mqh` (الـ snapshots) و
`Execution/FalconBrokerEntryBridge.mqh` (مسار البروكر) و`Reporting/...` (التقارير).

### ٢. الـ struct الأساسيّ الذي يمثّل المنطقة

لا يوجد struct واحد باسم `FvgMicroZone`/`FvgMicroCandidate`. بدلًا منه **خمسة
snapshots** لكلّ مرحلة في `Core/FalconDataStructures.mqh` (أعضاؤها public):

| الـ struct | `file:line` | أبرز الأعضاء |
|---|---|---|
| `FalconFvgMicroDetectorSnapshot` | `Core/FalconDataStructures.mqh:118` | `fvg_detected`, `fvg_direction`, `older/middle/newer_candle_high/low`, `fvg_lower`, `fvg_upper`, `fvg_size_price`, `fvg_size_points` |
| `FalconFvgMicroShadowCandidateSnapshot` | `:163` | `candidate_status`, `entry_zone_lower/upper`, `quality_*` (min size/spread/age/freshness), `quality_reject_reason` |
| `FalconFvgMicroRetestWatcherSnapshot` | `:215` | `retest_touched`, `planned_entry_price`, `planned_structural_sl`, `planned_tp1/tp2/tp3`, `planned_lot_size` |
| `FalconFvgMicroTradePlanStagingSnapshot` | `:275` | `entry_price`, `structural_sl`, `tp1/tp2/tp3`, `lot_size`, `validate_passed`, `staged_to_shadow_executor` |
| `FalconFvgMicroShadowLifecycleSnapshot` | `:314` | `simulated_exit_price`, `simulated_outcome`, `net_usd`, `close_reason` |

ملاحظة: لا حقل `midpoint` مخزَّن في أيّ snapshot — الـ midpoint يُحسب وقت الحاجة.

### ٣. الدوالّ/الفئات الرئيسة

| الفئة/الدالّة | `file:line` | التوقيع | ماذا تفعل حرفيًّا |
|---|---|---|---|
| `CFalconFvgMicroShadowDetectorStub` | `.mq5:4053` | `Initialize(registry, candle_cache, evidence, runtime_guard)` | يقرأ آخر شمعة M5 مغلقة، يستدعي `DetectThreeCandleM5Fvg`، يملأ snapshot الكشف، يضبط `detector_status`. |
| `…::DetectThreeCandleM5Fvg` | `.mq5:4219` | `bool DetectThreeCandleM5Fvg()` | `CopyRates` لثلاث شمعات M5 (shift, shift+1, shift+2)، يطبّق شرطَي bullish/bearish، يحسب `fvg_lower/upper/size`. |
| `CFalconFvgMicroShadowCandidateBuilder` | `.mq5:4343` | `Initialize(detector, registry, runtime_guard)` | يحوّل كشفًا صالحًا إلى candidate، يطبّق `EvaluateQualityFilters` (size/spread/age). |
| `CFalconFvgMicroRetestWatcher` | `.mq5:4575` | `Initialize(candidate_builder, market_context, runtime_guard)` | يفحص إن عاد السعر الحيّ للمنطقة، وإن لمس يبني هيكل خطّة (entry/SL/TP) عبر `BuildTradePlanSkeleton`. |
| `CFalconFvgMicroTradePlanStagingDryRun` | `.mq5:5003` | `Initialize(watcher, runtime_guard, shadow_executor)` | يبني `FalconTradePlan` حقيقيًّا من الهيكل، يتحقّق منه، يمرّره عبر FVG quality guard، يَستيج إلى ShadowExecutor مُنتِجًا `FalconShadowTradeRecord`. |
| `CFalconFvgMicroShadowLifecycleSimulation` | `.mq5:5293` | `Initialize(stager, market_context, shadow_executor)` / `Refresh(...)` | يراقب السجلّ المُستَيَج ويغلقه تشخيصيًّا عند SL/TP1/timeout(5400s). |
| `FalconRunFvgMicroRuntimeShadowPipeline` | `.mq5:5804` | `void (const string trigger)` | يربط الخمسة بالترتيب؛ عند الاستيج ينادي `g_broker_entry_bridge.TryOpenFromShadowRecord(...)`. |

---

## المحور الثاني — منطق الكشف

١. **كشف «3 شمعات»؟ نعم.** `.mq5:4219-4290` (`DetectThreeCandleM5Fvg`).
٢. **أيّ shift؟** newer=`shift`، middle=`shift+1`، older=`shift+2`، عبر `CopyRates`:
```mq5
int copied_newer = CopyRates(_Symbol, PERIOD_M5, shift,     1, newer);
int copied_mid   = CopyRates(_Symbol, PERIOD_M5, shift + 1, 1, middle);
int copied_old   = CopyRates(_Symbol, PERIOD_M5, shift + 2, 1, older);
```
(`.mq5:4238-4240`). و`shift` يأتي من `candle_cache.AnalysisShift()`.
٣. **شرط Bullish/Bearish:**
```mq5
const bool bullish_fvg = (older[0].high < newer[0].low);
const bool bearish_fvg = (older[0].low  > newer[0].high);
```
(`.mq5:4259-4260`) — **مطابق حرفيًّا لشرط الشرح.**
٤. **ماذا يحفظ؟** الاتّجاه، أوقات/قمم/قيعان الشمعات الثلاث، و:
```mq5
m_snapshot.fvg_lower = older[0].high;   // bullish
m_snapshot.fvg_upper = newer[0].low;
m_snapshot.fvg_size_price  = MathAbs(m_snapshot.fvg_upper - m_snapshot.fvg_lower);
m_snapshot.fvg_size_points = (m_snapshot.fvg_size_price / _Point);
```
(`.mq5:4266-4267,4287-4288`). للـ bearish: `fvg_lower=newer.high`, `fvg_upper=older.low` (`.mq5:4273-4274`). **لا midpoint يُخزَّن هنا.**
٥. **شمعات مغلقة فقط؟ نعم.** `if(shift <= 0) return false;` (`.mq5:4222-4226`)، والكاشف يأخذ snapshot M5 المغلق مع `runtime_guard.ValidateCandleSnapshotForDecision` (`.mq5:4130`).

---

## المحور الثالث — Guards / الفلاتر

| الفلتر | الحالة | `file:line` | العتبة الافتراضيّة |
|---|---|---|---|
| ١. Minimum FVG size | موجود | `.mq5:4487-4494` | `FALCON_FVG_MICRO_MIN_SIZE_POINTS = 1.00` (`.mq5:2001`) |
| ٢. Spread guard | جزئيّ (سقف مطلق، لا نسبة سبريد/FVG) | `.mq5:4496-4503` | `FALCON_FVG_MICRO_MAX_SPREAD_POINTS = 200` (`.mq5:2002`) |
| ٣. Age guard (max bars) | جزئيّ (الفلتر موجود لكنّ `quality_fvg_age_bars` ثابتٌ = 0) | `.mq5:4505-4512` + `:4473` | `FALCON_FVG_MICRO_MAX_FVG_AGE_BARS = 0` (`.mq5:2003`) |
| ٤. Invalidation (close متجاوز) | **غير موجود** | — | — (الكاشف يستعمل أحدث FVG مغلق فقط؛ لا تتبّع إبطال) |
| ٥. SL geometry | موجود | `.mq5:4752-4753,4760,4767` | buffer = `max(zone_size, stops_level·point)` — مشتقّ، لا إدخال |
| ٦. TP geometry | موجود (مرتكز حدّ FVG) | `.mq5:4761-4763,4768-4770` | `zone_size × {1,2,3}` من الحدّ |
| ٧. Risk percentage | **غير موجود** (Fixed lot فقط) | `.mq5:4639` (`planned_lot_size = FixedLotSize`) | — |
| ٨. MaxOpenPositions | موجود (في البروكر) | `Execution/FalconBrokerEntryBridge.mqh:1311-1312` | `FALCON_BEEB_MAX_OPEN_POSITIONS_PER_ENGINE` (لكلّ magic) |
| ٩. Margin/lot authority | موجود (في البروكر) | `Execution/FalconBrokerEntryBridge.mqh:1346` (`ResolvePreEntryBrokerLotAuthority`) | يُحسب وقت الدخول |

كتلة فلاتر الجودة (size/spread/age):
```mq5
if(detector_snapshot.fvg_size_points < m_snapshot.quality_min_fvg_size_points) { ... "FVG_SIZE_BELOW_MIN" ... }
if(spread_points > m_snapshot.quality_max_spread_points)                       { ... "SPREAD_ABOVE_MAX"  ... }
if(m_snapshot.quality_fvg_age_bars > m_snapshot.quality_max_fvg_age_bars)      { ... "FVG_AGE_ABOVE_MAX" ... }
```
(`.mq5:4487-4512`).

---

## المحور الرابع — منطق Retest

١. **ينتظر عودة السعر؟ نعم.** كشف اللمس بفحص وقوع السعر داخل المنطقة:
```mq5
m_snapshot.retest_touched = PriceInsideZone(m_snapshot.watch_price, m_snapshot.fvg_lower, m_snapshot.fvg_upper);
// bool PriceInsideZone(price, lower, upper){ return (price >= lower && price <= upper); }
```
(`.mq5:4691` + `:4744-4747`).
٢. **يميّز Bullish/Bearish؟ نعم، عبر سعر المراقبة (Bid/Ask):**
```mq5
double SelectWatchPrice(direction, quote){ if(BUY) return quote.bid; if(SELL) return quote.ask; return quote.last; }
```
(`.mq5:4735-4742`) — **مطابق لاستعمال Bid/Ask في الشرح.**
٣. **retest confirmation (شمعة تأكيد/إغلاق فوق midpoint)؟ جزئيّ.** يوجد
`FalconCalculateFvgHoldQualityScore` يفحص `close ≥ midpoint`، `close > open`،
لمس الحدّ ثمّ ارتداد (`.mq5:4864-4905`) — لكنّه **metrics-only** (تعليق `.mq5:4841`:
«no entry, SL, TP, staging, or lifecycle behavior changes»)، وكذلك حالة
الـ freshness FRESH/STALE (`.mq5:4907-4918`) **لا تحجب** بناء الهيكل.
٤. **اختياريّ أم مُلزِم؟** ليس اختياريًّا بعَلَم ولا مُلزِمًا: مجرّد لمسٍ للمنطقة
(`retest_touched`) يكفي لتسليح الهيكل (`.mq5:4699-4713`)؛ التأكيد مقياسٌ فقط.

---

## المحور الخامس — Entry/SL/TP

كتلة الهيكل الكاملة (`BuildTradePlanSkeleton`, `.mq5:4749-4774`):
```mq5
const double zone_size  = MathAbs(m_snapshot.fvg_upper - m_snapshot.fvg_lower);
const double min_buffer = MathMax(zone_size, (double)symbol_context.stops_level_points * symbol_context.point);
const double safe_buffer= (min_buffer > 0.0 ? min_buffer : 10.0 * symbol_context.point);
const double midpoint   = (m_snapshot.fvg_lower + m_snapshot.fvg_upper) / 2.0;
m_snapshot.planned_entry_price = midpoint;          // BUY مثال:
m_snapshot.planned_structural_sl = m_snapshot.fvg_lower - safe_buffer;
m_snapshot.planned_tp1 = m_snapshot.fvg_upper + zone_size; // tp2 ×2 ، tp3 ×3
```
١. **الدخول:** `midpoint = (lower+upper)/2` — **مطابق للشرح** (`.mq5:4754-4756`).
٢. **SL الهيكليّ:** الحدّ (lower للـ BUY / upper للـ SELL) ∓ `safe_buffer`. الـ buffer
   **ليس إدخالًا قابلًا للضبط**؛ مشتقٌّ من `max(zone_size, stops_level·point)` (`.mq5:4752-4753,4760,4767`).
٣. **TP1/TP2/TP3:** نعم، بصيغة `الحدّ ± zone_size × {1,2,3}` (`.mq5:4761-4763` للـ BUY،
   `:4768-4770` للـ SELL). المُضاعِف ×1/×2/×3 يطابق الشرح، لكنّ **المرتكز هو حدّ
   الـ FVG (upper/lower) لا نقطة الدخول (midpoint)** — اختلافٌ هندسيّ.
٤. **rejection reasons صريحة؟ نعم، كثيرة** (سلاسل في `block_reason`/`no_trade_reason`/
   `staging_reason`). أمثلة: `NO_THREE_CANDLE_M5_FVG_DETECTED` (`.mq5:4191`)،
   `FVG_DETECTED_BUT_STRATEGY_INPUT_DISABLED` (`:4176`)، `QUALITY_FILTER_REJECTED;…`
   (`:4424`)، `INVALID_FVG_ZONE_GEOMETRY` (`:4685`)، `WAITING_FOR_RETEST` (`:4703`)،
   `SKELETON_NOT_READY` (`:5052`)، `FVG_QGUARD_RUNTIME_BLOCKED` (`:5095`)،
   `SHADOW_EXECUTOR_STAGE_FAILED` (`:5117`)، وعلى مستوى البروكر
   `SHADOW_RECORD_NOT_OPEN_STAGED` / `BROKER_ENTRY_BLOCKED_EXISTING…` (`Bridge:1305,1316`).

---

## المحور السادس — إخراج `StrategySignal`

١. **هل ينتج `StrategySignal`؟ لا (للـ FVG_MICRO).** يوجد struct `FalconStrategySignal`
   (`Core/FalconDataStructures.mqh:391`، بحقول `direction`, `score`, `rejection_reason`,
   `evidence`, `objective`) **لكنّه غير مُستعمَل في أيّ موضع** (لا مرجع في `*.mq5/*.mqh`
   سوى تعريفه). الـ pipeline يُخرِج بدلًا منه: `…Snapshot` → `FalconTradePlan` →
   `FalconShadowTradeRecord` → `FalconTradeLifecycleRecord`.
٢. **الحقول المملوءة فعلًا:** عبر `BuildTradePlanFromWatcher` (`.mq5:5194-5224`) تُملأ
   `entry_price`, `structural_sl`, `tp1/tp2/tp3`, `lot_size`, `direction`,
   `fvg_size_points`, `fvg_*` التشخيصيّة. `runner_allowed=false` (`:5207`)،
   `management_profile="NO_MANAGEMENT_YET_STAGING_DRY_RUN"` (`:5209`).
٣. **يصل لـ Router/Coordinator؟** لا يمرّ عبر `FalconStrategySignal`/Router. المسار:
   `g_fvg_micro_tradeplan_stager.GetShadowRecord()` →
   `g_broker_entry_bridge.TryOpenFromShadowRecord(record, g_report_writer)` (`.mq5:5857`).
٤. **في وضع `EnableRealExecution=true`، يصل للبروكر؟ نعم.** المترجِم إلى `OrderSend`:
   `Execution/FalconBrokerEntryBridge.mqh:1283` (`TryOpenFromShadowRecord`)، مع
   `request.action=TRADE_ACTION_DEAL` (`:1378`)، `request.magic=FC_MAGIC_FVG_MICRO` (`:1409`).
   البوّابة: `TesterEntryAllowed` → `if(!EnableRealExecution){...}` (`:1241-1243`)؛
   و`EnableRealExecution=false` افتراضيًّا (`.mq5:1588`). **مهمّ:** الـ SL/TP المُرسَلان
   للبروكر هما **مظروف الطوارئ** (`BuildLockParityEmergencyServerStops`, `.mq5...Bridge:1394-1407`)،
   **لا** `structural_sl`/`tp1-3` من الخطّة (تعليق `Bridge:1383-1387`)؛ مع إلزام عدم
   التعرية (`if(request.sl<=0 || request.tp<=0) block`, `Bridge:1417`).

---

## المحور السابع — التسجيل في التقارير

١. **`TradeLifecycle.csv`؟ نعم.** السجلّ المُغلَق من المحاكي →
   `g_report_writer.RegisterClosedTrade(lifecycle_record)` (`.mq5:6036`؛ ونظيره في
   OnInit `.mq5:5955`) بعد `ExtractClosedLifecycleRecord` (`.mq5:5442-5446`, `:6034`).
٢. **`BrokerExecutionLifecycle.csv`؟ نعم.** `TryOpenFromShadowRecord` يكتب
   `report_writer.AppendBrokerEntryBridgeLifecycleRecord(link)` في كلّ فرعٍ
   (`Bridge:1297,1307,1318,1340,…`).
٣. **`BrokerPaperTradeReconciliation.csv`؟ نعم (غير مباشر).** عبر مسار الإغلاق
   المُدار `g_broker_entry_bridge.TryManagedCloseFromLifecycleRecord(lifecycle_record, g_report_writer)`
   (`.mq5:6037`, `:5956`) الذي يغذّي مصالحة البروكر مقابل الورقيّ (نفس مسار S01).
٤. **تقرير `Rejection`؟ جزئيّ.** لا تقرير مستقلّ باسم «Rejection»؛ أسباب الرفض
   تُحمَل ضمن `link.reason`/`block_reason` في سجلّات الـ BrokerEntryBridge والـ
   snapshots (وكانت تُكتب سابقًا في تقارير تشخيصيّة أُزيلت في R1.6a — انظر الغموض).

---

## المحور الثامن — مقارنة بنديّة بالشرح

| العنصر من الشرح | موجود؟ | `file:line` | مطابق/مختلف/جزئيّ |
|---|---|---|---|
| كشف 3 شمعات مغلقة | نعم | `.mq5:4219-4290` (shift>0: `:4222`) | مطابق |
| Bullish FVG: `older.high < newer.low` | نعم | `.mq5:4259,4262-4268` | مطابق |
| Bearish FVG: `older.low > newer.high` | نعم | `.mq5:4260,4269-4275` | مطابق |
| حساب Midpoint | نعم | `.mq5:4754` (و`:4874`) | مطابق |
| Min size filter | نعم | `.mq5:4487-4494` (`MIN=1.00`) | مطابق (آليّة)؛ القيمة 1.00 منخفضة |
| Spread guard | جزئيّ | `.mq5:4496-4503` (`MAX=200`) | مختلف (سقف سبريد مطلق، لا نسبة سبريد/FVG) |
| Age guard | جزئيّ | `.mq5:4505-4512` (`MAX=0`, `age≡0` `:4473`) | جزئيّ (الفلتر قائم لكنّه غير فعّال عمليًّا) |
| Invalidation guard | لا | — | مختلف (لا تتبّع إبطال بإغلاق متجاوز) |
| Retest bullish/bearish | نعم | `.mq5:4691,4735-4747` | مطابق (Bid للـ BUY، Ask للـ SELL) |
| Retest confirmation (اختياريّ) | جزئيّ | `.mq5:4864-4905` (metrics-only `:4841`) | جزئيّ (مقياس غير حاجب، لا عَلَم اختياريّ) |
| Entry at midpoint | نعم | `.mq5:4754-4756` | مطابق |
| Structural SL buffer | جزئيّ | `.mq5:4752-4753,4760,4767` | مختلف (buffer مشتقّ من stops_level/zone، ليس إدخالًا) |
| TP1 = entry ± zoneSize × 1 | جزئيّ | `.mq5:4761,4768` | جزئيّ (×1 مطابق؛ المرتكز = حدّ FVG لا الدخول) |
| TP2 = entry ± zoneSize × 2 | جزئيّ | `.mq5:4762,4769` | جزئيّ (نفس ملاحظة المرتكز) |
| TP3 = entry ± zoneSize × 3 | جزئيّ | `.mq5:4763,4770` | جزئيّ (نفس ملاحظة المرتكز) |
| `StrategySignal` struct بإخراج كامل | لا | `Core/FalconDataStructures.mqh:391` (مُعرَّف، غير مُستعمَل) | مختلف (الإخراج الفعليّ `FalconShadowTradeRecord`) |
| Magic = `FC_MAGIC_FVG_MICRO = 1100001` | نعم | `Execution/FalconExecutionInputs.mqh:67` + `Bridge:1409` | مطابق |
| Rejection reasons (الـ 14 المذكورة) | جزئيّ | `.mq5:4191,4176,4424,4685,4703,5095,5117` + `Bridge:1305,1316` | جزئيّ (أسبابٌ كثيرة موجودة؛ تطابق الـ14 غير مؤكَّد — انظر الغموض) |
| مسار broker execution مع SL/TP إلزاميَّين | جزئيّ | `Bridge:1283,1394-1407,1409,1417` | جزئيّ (إلزاميّان لكنّهما مظروف الطوارئ لا SL/TP الخطّة) |
| `Protect only when earned` (لا حماية مبكّرة) | لا | — (في كود FvgMicro) | غير موجود هنا (الحماية في محرّك R1.5a المنفصل، خارج النطاق §٣) |
| `EnableStrategy_FvgMicroRetest` حارسٌ فعليّ (بعد R1.7) | نعم | `.mq5:5806` + `Router/FalconStrategyRegistry.mqh:72` | مطابق |

---

## خلاصة تنفيذيّة (سطرٌ واحد)

**الاكتمال التقديريّ ≈ 65–70%** — الـ pipeline ليس `stub` (رغم اسم الفئة): الكشف
(3 شمعات، شرطا bullish/bearish)، الـ midpoint، فحص الـ retest (Bid/Ask)، هندسة
SL/TP، بناء `FalconTradePlan`، الاستيج، مسار البروكر (magic 1100001)، والتسجيل في
التقارير — كلّها **موجودة ومطابقة لمفاهيم الشرح** في طبقة توليد الإشارة؛
**المسار المُقترَح لـ R2.1 = «إكمال» (تعديل + تحقّق)** مع تحفّظات تنفيذيّة موصوفة
أدناه (لا اقتراح حلٍّ — توصيف فقط): التباينات المرصودة هي مرتكز TP (حدّ FVG لا
الدخول)، SL buffer مشتقّ لا قابل للضبط، spread سقفٌ مطلق لا نسبة، age معطَّل عمليًّا،
غياب invalidation guard، وكون SL/TP البروكر مظروفَ طوارئٍ لا SL/TP الخطّة، وغياب
إخراج `StrategySignal`.

---

## قسم «الغموض» — ما لم يُحسَم بقراءة الكود

1. **وثيقتا الشرح (التقنيّة + المبسَّطة) لم تُمرَّرا في هذه الجلسة.** اعتمدت المقارنة
   على عناصر الشرح المُعدَّدة صراحةً في جدول §٤ من المواصفة. لذلك **تطابق «الـ 14
   rejection reason»** لم يُتحقَّق منه 1:1 — الكود يحوي أسبابًا كثيرة لكنّ كونها
   نفس الـ14 المذكورة غير مؤكَّد.
2. **قيم بعض الإدخالات الافتراضيّة:** `FixedLotSize` (يُسنَد لـ `planned_lot_size`,
   `.mq5:4639`) لم تُقرأ قيمته هنا. و`FALCON_FVG_MICRO_MIN_SIZE_POINTS = 1.00` تبدو
   منخفضةً جدًّا لمؤشّر — قد تكون قيمة placeholder، لم يُحسم.
3. **أعلام الـ Registry الأربعة** (`Router/FalconStrategyRegistry.mqh:74`:
   `true,false,false,false`): الأوّل `shadow_allowed=true` مؤكَّد (يُقرأ في
   `entry.shadow_allowed`, `.mq5:4395,4427`)؛ الثلاثة الباقية (paper/demo/live)
   مُستنتَجة `false` لكنّ ربطها الحقليّ الدقيق لم يُتتبَّع في توقيع `AddEntry`.
4. **داخليّات مظروف الطوارئ** (`BuildLockParityEmergencyServerStops` /
   `SelectInitialBridgeTakeProfit`) لم تُقرأ (خارج كود FvgMicro) — أُكِّد فقط أنّها
   تُحلّ محلّ SL/TP الخطّة على البروكر.
5. **تقارير الرفض:** كانت ثمّة تقارير تشخيصيّة لـ FvgMicro أُزيلت كتابتها في R1.6a
   (`DiagnosticReportCleanup`, تعليق `.mq5:5814-5818`)؛ لم يُحسم أيّ «تقرير Rejection»
   مستقلّ ما زال يُكتب اليوم مقابل ما بقي ضمن سجلّات الـ BrokerEntryBridge فقط.
6. **ازدواج مسار الدخول:** يوجد مسار دخولٍ في OnInit (`.mq5:5926-5956`) ونظيرٌ في
   OnTick عبر الـ pipeline (`.mq5:6022`)؛ منعُ الازدواج يعتمد على
   `g_last_staged_fvg_candidate_id` (`.mq5:5841,5849,5856`) — لم يُتتبَّع سلوكه الكامل.
7. **منظومة `S00_ScalpFvgMicro/`** المنفصلة (`Enable_S00_FvgScalp`) تتقاطع في الاسم
   و في استعمال نفس الـ magic/البروكر — لم تُحلَّل (خارج نطاق `FVG_MICRO_RETEST`).
