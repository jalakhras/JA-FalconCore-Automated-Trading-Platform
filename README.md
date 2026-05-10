**JA FalconCore Automated Trading Platform**

**الخطة الشاملة الجديدة لبناء EA نظيف من الصفر — v0.0.0 Roadmap**

**نوع الوثيقة: خطة تأسيس رسمية جديدة. هذه الوثيقة لا تنقل المؤشر القديم كما هو، بل تستخرج منه النقاط المفيدة فقط لبناء EA جديد نظيف ومعزول معماريًا.**

المرجع السابق: خطط مؤشر Nasdaq / PitchforkPattern و JA FalconEdge Legacy Indicator. القرار الحالي: Legacy Indicator = Research Source فقط، و JA FalconCore = منصة تنفيذ آلي جديدة مستقلة.

# 1) الهدف النهائي للمشروع

الهدف هو بناء منصة تداول آلية احترافية للناسداك قابلة للتوسع، تبدأ كـ Shadow / Paper / Demo ثم تصل تدريجيًا إلى Controlled Live، مع بقاء التنفيذ الحقيقي مقفلاً افتراضيًا حتى تثبت كل طبقة نفسها.

• بناء EA نظيف معماريًا، وليس تحويل المؤشر القديم كما هو.

• فصل كل Strategy وكل Engine عن غيره بالكامل.

• استخدام Evidence وChart Pattern Evidence وObjective Indicator Evidence قبل أي قرار تنفيذ.

• إدارة صفقات احترافية: Structural SL، TP1 Partial، Proof Protection، Runner، Early Failure Exit.

• تقارير كاملة وخفيفة تعتمد على append-on-close بدل إعادة بناء التقرير في نهاية الاختبار.

• إبقاء Inputs بسيطة للمستخدم، مع نقل التعقيد إلى Profiles داخلية وملفات إعدادات لاحقة.

• إمكانية تفعيل أو إيقاف كل استراتيجية يدويًا، ولاحقًا تلقائيًا حسب الربحية وقوة الـ Engine.

# 2) اسم المشروع والهوية

|     |     |
| --- | --- |
| **العنصر** | **القيمة المعتمدة** |
| اسم المشروع | JA FalconCore Automated Trading Platform |
| اسم النواة | JAFalconCore |
| اسم الـ EA | JA FalconCore EA |
| اسم طبقة المخاطر | FalconGuard |
| اسم طبقة التنفيذ | FalconExecutor |
| اسم طبقة التقارير | FalconJournal |
| الشعار الداخلي | Evidence first. Execution last. |
| حالة المؤشر القديم | Legacy Research Source فقط |

# 3) مبادئ لا تُكسر

• لا OrderSend داخل أي Strategy Engine.

• لا Strategy جديدة تدخل Runtime مباشرة: Shadow → Paper → Demo → OOS → Candidate → Lock.

• لا استخدام high/low لنفس الشمعة لاتخاذ قرار يفترض ترتيبًا زمنيًا غير معروف.

• لا Break-Even مبكر.

• SL هيكلي فقط خلف swing / edge / wick / invalidation.

• الحماية فقط عندما تكتسبها الصفقة: Protect only when earned.

• التوسع فقط عند الدليل: Expand only on proof.

• Pattern is evidence, not permission.

• SMC is evidence, not permission.

• No random loosening, no LayoutValid bypass, no threshold reduction without proof.

• أي تعديل UI/Input يجب ألا يغير منطق التداول.

• أي إصدار يجب أن ينتج ملف ذاكرة مشروع محدث قبل الانتقال للإصدار التالي.

# 4) المعمارية الرسمية الجديدة

JA FalconCore Automated Trading Platform

│

├── Core

│ ├── MarketContext

│ ├── SessionContext

│ ├── SymbolContext

│ ├── CandleCache

│ └── TimeframeDataProvider

│

├── Narrative

│ ├── OpenTypeClassifier

│ ├── SessionNarrativeReader

│ ├── BoxMigrationReader

│ └── DayStateClassifier

│

├── Evidence

│ ├── CandleEvidence

│ ├── ChartPatternEvidence

│ ├── ObjectiveIndicatorEvidence

│ ├── SMCEvidence

│ └── EvidenceScoreModel

│

├── Engines

│ ├── CampaignEngines

│ ├── ScalpEngines

│ ├── OpeningEngines

│ ├── LiquidityEngines

│ ├── SessionSwingEngines

│ └── ConfirmationEngines

│

├── Router

│ ├── StrategyRegistry

│ ├── EngineRouter

│ ├── ConflictResolver

│ └── TradePlanSelector

│

├── Risk

│ ├── RiskManager

│ ├── LotSizingManager

│ ├── DailyGovernance

│ ├── EngineRiskAllocation

│ └── KillSwitch

│

├── TradeManagement

│ ├── StructuralStopEngine

│ ├── TPBuilder

│ ├── PartialManager

│ ├── ProofProtectionEngine

│ ├── RunnerManager

│ ├── AdaptiveRatchetEngine

│ └── EarlyFailureExitEngine

│

├── Execution

│ ├── ShadowExecutor

│ ├── PaperExecutor

│ ├── DemoExecutor

│ └── LiveExecutor

│

└── Reporting

├── TradeLifecycleReport

├── EvidenceReport

├── RejectionReport

├── EngineSummaryReport

├── DailySummaryReport

└── ProjectMemoryWriter

# 5) التقنيات المستخدمة

|     |     |
| --- | --- |
| **المجال** | **التقنية / القرار** |
| منصة التداول | MetaTrader 5 |
| لغة البرمجة | MQL5 |
| نوع المنتج | Expert Advisor مع Shadow/Paper/Demo/Live modes |
| هيكلة الكود | .mq5 رئيسي صغير + ملفات .mqh مستقلة حسب الطبقات |
| التقارير | CSV / TXT / لاحقًا JSON state dump عند الحاجة |
| الاختبار | MT5 Strategy Tester + OOS + Walk-Forward لاحقًا |
| إدارة الرمز | SymbolInfo + broker stops level + spread + contract size |
| تحليل الأداء | RawPriceMovePoints + Estimated USD + Engine Summary |
| التنفيذ الحقيقي | مغلق افتراضيًا عبر EnableRealExecution=false |

# 6) Input Design — إعدادات بسيطة فقط

الهدف هو منع تضخم الـ Inputs. المستخدم يرى مجموعات قليلة فقط: الأمان والمخاطر، تفعيل الاستراتيجيات، التنفيذ/التقارير. أي thresholds تفصيلية تبقى داخل Profiles أو Constants لاحقًا.

input group "01 - EA Safety & Risk / إعدادات المستخدم الأساسية";

input bool EnableRealExecution = false; // HARD SAFETY: remains false during shadow/candidate stages.

input bool UseFixedLot = true; // simple user mode: fixed lot first.

input double FixedLotSize = 0.01;

input bool UseAutoCapitalDetection = true; // true = use account balance later; false = ManualCapital.

input double ManualCapital = 10000.0;

input bool UseDailyLossLimit = true;

input bool UseFixedDailyLossAmount = false;

input double FixedDailyLossAmount = 100.0;

input double DailyLossPercentOfCapital = 3.0;

input group "02 - Strategy Activation / تفعيل وإيقاف الاستراتيجيات";

input bool EnableS00_FvgMicroRetest = true;

input bool EnableS01_TailReturnSmart = false;

input bool EnableS02_MomentumCross_8_20 = false;

input bool EnableS03_CheckMarkLiquiditySweep = false;

input bool EnableS04_DoubleBoxWickConfirmation = false;

input bool EnableS05_TouchTurnOpeningRange = false;

input bool EnableS06_MagicLiquidityLines = false;

input bool EnableS07_DailyLiquidityBox = false;

input bool EnableS08_QuickFlipOpeningLiquidity = false;

input bool EnableS09_FseFailedPatternEntry = false;

input bool EnableS10_TwoLiquidityLines = false;

input bool EnableS11_GoldenLiquidityZones5M = false;

input group "03 - Engine Health / إيقاف الاستراتيجيات حسب الأداء";

input bool EnableManualStrategySwitches = true;

input bool EnableAutoDisableWeakEngines = false; // later stage only.

input double MinEngineHealthScore = 60.0;

input int EngineHealthLookbackTrades = 30;

input group "04 - Reporting / التقارير";

input bool EnableMainReport = true;

input bool EnableEvidenceReport = true;

input bool EnableRejectedReport = true;

input bool EnableProjectMemoryExport = true;

ملاحظة مهمة: كل الاستراتيجيات باستثناء S00 تبدأ disabled أو Shadow حسب الإصدار. لا يتم تفعيل أي Strategy في Real/Demo إلا بعد مرورها بمراحل Shadow وPaper وOOS.

# 7) العقد الرسمي لأي Strategy Engine

struct StrategySignal

{

string StrategyId;

string EngineId;

int Direction; // BUY / SELL / NONE

datetime SetupTime;

ENUM_TIMEFRAMES SetupTimeframe;

double EntryLow;

double EntryHigh;

double TriggerPrice;

double StructuralSL;

double TP1;

double TP2;

double TP3;

double Score;

bool LayoutValid;

bool GuardsPassed;

string EvidenceTags;

string RejectionReason;

string TradeManagementProfile;

};

• Detector يكتشف setup فقط ولا يتداول.

• EvidenceCollector يجمع الأدلة ولا يعطي إذن دخول وحده.

• ScoreModel يحول الأدلة إلى درجة قابلة للتقرير.

• Guard يمنع الصفقات غير القابلة للتنفيذ هندسيًا.

• ObjectiveBuilder يبني TP/SL/targets حسب السياق.

• TradePlanBuilder يرسل خطة موحدة للـ Router.

• Executor وحده يملك صلاحية التنفيذ، وليس الـ Strategy.

# 8) أسماء الاستراتيجيات المعتمدة التي أُعيدت كتابتها

|     |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- |
| **ID** | **الاسم العربي** | **English Name** | **الفكرة المختصرة** | **العائلة** | **الحالة الأولى** |
| S01 | استراتيجية ذيل العودة الذكي | Tail Retest Smart Reversal | H1 zone + lower TF confirmation | Liquidity / Reversal | Shadow لاحقًا |
| S02 | استراتيجية تقاطع الزخم 8/20 | Momentum Cross 8/20 | MA 8/20 cross | Confirmation / Momentum | Confirmation only أولًا |
| S03 | استراتيجية علامة الصح بعد سحب السيولة | Check Mark Liquidity Sweep Reversal | 15M OR + ATR + blowoff + retest | Opening / Liquidity | Shadow |
| S04 | استراتيجية الصندوقين والشمعة الحاسمة | Double Box + Wick Confirmation | Previous day box + pre/post box + wick | Box / Liquidity | Shadow |
| S05 | استراتيجية لمس نطاق الافتتاح والارتداد | Touch & Turn Opening Range Scalper | 15M opening range + ATR + fib targets | Opening Range | Shadow |
| S06 | استراتيجية خطوط السيولة الذكية وشمعة الشوكة | Magic Liquidity Lines + Pitchfork Candle | H1 levels + Pitchfork candle | Liquidity Lines | Shadow |
| S07 | استراتيجية صندوق السيولة اليومي وشمعة الشوكة | Daily Liquidity Box + Pitchfork Candle | Previous day high/low box | Daily Box | Shadow |
| S08 | استراتيجية الانعكاس السريع بعد شمعة السيولة | Quick Flip Opening Liquidity Scalper | 15M liquidity candle + outside-box reversal candle | Opening / Reversal | Shadow |
| S09 | استراتيجية الدخول المبكر بعد فشل النموذج | FSE / First Sign Execution | Failed pattern + level + first execution candle | Pattern Failure | Research ثم Shadow |
| S10 | استراتيجية خطّي السيولة والارتداد المؤكد | Two Liquidity Lines + 15M Confirmation | H1 swing high/low + M15 confirmation | Liquidity Lines | Shadow |
| S11 | استراتيجية مناطق السيولة الذهبية ودخول الخمس دقائق | Golden Liquidity Zones + 5M Pitchfork Entry | H1 liquidity zones + M5 entry only | 5M Precision Entry | Shadow |

# 9) محركات Legacy التي نحتفظ بها من المؤشر

|     |     |     |
| --- | --- | --- |
| **ID** | **المحرك** | **سبب الاحتفاظ به** |
| L00 | FVG Micro Retest Engine | الفائز الحالي في خطط المؤشر، يبدأ أولًا لأنه أثبت نفسه تاريخيًا. |
| L01 | Edge Memory Engine | يدعم جودة مناطق الحافة وتكرار اللمس وfreshness. |
| L02 | Micro Range Edge Engine | محرك سكالب تاريخي، لكن لا يفعّل قبل isolation. |
| L03 | Breakout Retest Engine | Campaign family رئيسية. |
| L04 | Trend Pullback Engine | Continuation family للاتجاه القوي. |
| L05 | Reversal Pitchfork Engine | المنطق الأصلي للمشروع، يستخدم بحذر بعد عزله. |
| L06 | Opening Liquidity Flip Engine | يفرق بين overshoot خارج الصندوق والعودة. |
| L07 | Opening Touch & Turn Engine | لمس حافة opening range ثم rotation. |
| L08 | Sell-Side Mirror Engine | لمعالجة ضعف البيع وعدم التماثل. |
| L09 | Protected Runner Engine | إدارة صفقة بعد proof؛ لا يعود runner إلى خسارة. |

# 10) Evidence Architecture

|     |     |     |
| --- | --- | --- |
| **الطبقة** | **الأمثلة** | **قرار الاستخدام** |
| Candle Evidence | Engulfing, Pin Bar, Hammer, Shooting Star, Wide Body, Inside/Outside Bar, Three-Bar Reversal | Evidence فقط، لا تفتح صفقة وحدها |
| Chart Pattern Evidence | Double Top/Bottom, H&S, Flags, Wedges, Range Break + Retest, Liquidity Sweep + Reclaim | يرفع/يخفض score |
| Objective Indicator Evidence | VWAP, EMA 7/25/50/200, ATR, RSI closed candle, Opening Range, FVG, Tick Volume | No repainting وClosed candle فقط |
| SMC Evidence | Liquidity, FVG, Displacement, Sweep, Reclaim, BOS/CHoCH, Premium/Discount | يقوي أو يضعف قرار المحرك ولا يستبدله |
| Objective Engine | PDH/PDL, Session H/L, opposite box side, FVG target, ATR projection, structure target | يبني الأهداف والـ invalidation |

# 11) إدارة الصفقة الرسمية

• كل صفقة تبدأ بـ Structural SL وليس وقفًا عشوائيًا.

• TP1 = partial / pay ourselves / proof checkpoint.

• TP2 = proof stronger checkpoint، وليس خروجًا إجباريًا دائمًا.

• Runner فقط إذا ظهر proof: acceptance، continuation، FVG hold، migration accepted، no opposite rejection.

• Early Failure Exit عند ضعف follow-through أو فقدان المستوى أو rejection عكسي.

• Adaptive Ratchet يحمي الربح المكتسب تدريجيًا دون خنق الصفقة.

• أي صفقة يمكن أن تتوسع إذا أثبتت نفسها، حتى لو بدأت كـ scalp.

# 12) نظام تفعيل/إيقاف الاستراتيجيات حسب الأداء

في البداية يكون التفعيل يدويًا عبر Inputs. لاحقًا، بعد وجود بيانات كافية، نضيف Engine Health System بحيث يوقف المحركات الضعيفة تلقائيًا أو يحولها إلى Shadow.

|     |     |
| --- | --- |
| **المقياس** | **الاستخدام** |
| EngineHealthScore | درجة عامة من 0 إلى 100 تجمع الربحية، win rate، drawdown، average raw points، وOOS stability. |
| MovingExpectancy | متوسط توقع آخر N صفقات للمحرك. |
| DecaySlope | هل أداء المحرك يتحسن أم يتآكل؟ |
| AutoShadowMode | إذا تدهور الأداء، يتحول المحرك إلى Shadow بدل Runtime. |
| ManualOverride | المستخدم يستطيع تعطيل أي Strategy يدويًا دائمًا. |

# 13) خطة الإصدارات الجديدة من الصفر

|     |     |     |
| --- | --- | --- |
| **الإصدار** | **الاسم** | **الهدف** |
| v0.0.0 | Clean EA Skeleton | ملف EA نظيف + compile + لا استراتيجيات + لا تنفيذ. |
| v0.1.0 | Core Contracts | StrategySignal, EvidencePack, TradePlan, ObjectivePlan, RejectionReason. |
| v0.2.0 | Market Context Layer | Candle cache, symbol context, session time, spread/stops/digits. |
| v0.3.0 | Reporting Foundation | Append-on-close report writer + ProjectMemory export. |
| v0.4.0 | Evidence Framework | Candle/Chart/Objective/SMC evidence structures. |
| v0.5.0 | Shadow Engine Framework | Shadow فقط لكل الاستراتيجيات بدون OrderSend. |
| v0.6.0 | No-Lookahead Guard | prior-bar state validation + current-bar safety. |
| v1.0.0 | FVG Micro Shadow | أول engine فعلي، Shadow فقط. |
| v1.1.0 | FVG Paper Execution | Paper executor داخلي بدون تداول حقيقي. |
| v1.2.0 | FVG Demo Candidate | Demo execution محروس. |
| v1.3.0 | FVG Protected Runner | TP1/TP2 proof + runner + adaptive ratchet. |
| v2.0.x | Core Legacy Engines | Micro Range Edge, Breakout Retest, Trend Pullback, Reversal Pitchfork. |
| v3.0.x | Liquidity & Opening Strategies | Daily Box, Two Lines, Double Box, Check Mark, Touch & Turn, Quick Flip. |
| v4.0.x | Sell-Side Repair | Sell diagnostics ثم Sell Mirror Shadow/Paper/Demo. |
| v5.0.x | Daily Governance | Participation floor, L1-L5, engine health, daily kill switch. |
| v6.0.x | Validation & Pilot | Backtest pack, Walk-forward, Engine-by-engine, Demo, Controlled Live. |

# 14) تعريف القبول لكل إصدار

• Compile = 0 errors / 0 warnings قدر الإمكان.

• No real execution unless EnableRealExecution=true and version stage allows it.

• Trading Logic Change يجب أن يكون مذكورًا بوضوح.

• كل إصدار يكتب Release Summary وProject Memory.

• كل Strategy جديدة تبدأ Shadow وتحصل على Rejected + Evidence reports.

• أي Runtime candidate يجب أن يثبت no-lookahead feasibility.

• أي improvement يجب أن يمر على أكثر من نافذة اختبار، وليس نافذة واحدة فقط.

• إذا فشل الإصدار، لا نصلحه عشوائيًا؛ نكتب سبب الفشل ونحدد rollback baseline.

# 15) أسلوب كتابة الكود

|     |     |
| --- | --- |
| **القاعدة** | **التطبيق** |
| تقسيم الملفات | كل طبقة في .mqh مستقل. الملف الرئيسي يستدعي فقط OnInit/OnTick/OnDeinit orchestration. |
| أسماء الملفات | Core/FalconMarketContext.mqh، Engines/FvgMicroEngine.mqh، Risk/FalconGuard.mqh... |
| أسماء الدوال | PascalCase للأفعال الأساسية: BuildSignal, CollectEvidence, EvaluateGuards. |
| أسماء المتغيرات | camelCase للمتغيرات المحلية، وg_ فقط للـ global state الضروري جدًا. |
| التنفيذ | لا OrderSend في أي Engine؛ التنفيذ فقط داخل FalconExecutor. |
| التقارير | Append عند الحدث، وليس rebuild في النهاية. |
| الأخطاء | كل rejection له reason واضح وفريد قدر الإمكان. |
| الاختبار | كل Engine له Shadow metrics قبل أي تفعيل. |
| Inputs | لا thresholds كثيرة للمستخدم؛ نستخدم Profiles. |
| التعليقات | تعليقات قصيرة توضح السبب لا تكرر الكود. |

# 16) ملف ذاكرة المشروع بعد كل إصدار

بعد كل إصدار يجب إنشاء أو تحديث ملف ذاكرة المشروع، ثم في أي جلسة جديدة يتم إرسال ملف الذاكرة أولًا وبعده يتم طلب المهمة. هذا يمنع فقدان السياق ويجعل أي محادثة جديدة تكمل بنفس الهدف والمعايير.

|     |     |
| --- | --- |
| **القسم الإجباري** | **المحتوى المطلوب** |
| هدف المشروع | لماذا نبني JA FalconCore وما الهدف من الإصدار الحالي. |
| المعمارية | الطبقات، الملفات، المحركات المفعلة، والمحركات Shadow. |
| التقنيات المستخدمة | MQL5, MT5, CSV reports, tester settings, symbol assumptions. |
| القواعد المهمة | No lookahead, Shadow first, no early BE, structural SL... |
| القرارات النهائية | ما تم اعتماده وما تم رفضه. |
| أسلوب كتابة الكود | naming, file split, inputs, reporting, comments. |
| ما تم إنجازه | قائمة مختصرة لكل ما أنجز حتى آخر إصدار. |
| المشاكل المعروفة | bugs, risks, compile issues, performance bottlenecks. |
| المهمة التالية | الإصدار التالي والخطوة المحددة فقط. |

# 17) البروتوكول الرسمي لكل جلسة جديدة

1) أرسل ملف ذاكرة المشروع أولًا.

2) بعدها اكتب المهمة المطلوبة فقط.

3) لا تطلب من المساعد الرجوع للمحادثات القديمة.

4) إذا كان المطلوب تعديل كود: أرفق آخر ملف EA رسمي + آخر تقرير + ملف الذاكرة.

5) إذا كان المطلوب استراتيجية جديدة: أرفق نص الاستراتيجية ثم اطلب تحويلها إلى ملف مستقل وخطة Engine.

6) لا تبدأ تطويرًا جديدًا قبل تثبيت نتيجة الإصدار السابق.

# 18) المشاكل المعروفة من Legacy ويجب تجنبها

• تضخم الملف الواحد إلى عشرات الآلاف من الأسطر.

• كثرة المتغيرات العامة وتداخلها بين المحركات.

• Shared acceptance pipe يقتل الاستقلالية ويصعب التشخيص.

• Final report rebuild يسبب بطء شديد في نهاية الاختبار.

• Buy/Sell asymmetry بسبب شروط بيع أصرم من الشراء.

• احتمالات lookahead بسبب high/low داخل نفس الشمعة.

• استراتيجيات كثيرة تظهر كأسماء لكنها لا تتجسد كـ accepted engines.

• Inputs كثيرة تربك المستخدم وتزيد احتمال الخطأ.

• تفعيل features قبل انتهاء Shadow/OOS.

# 19) القرار النهائي لهذه الخطة

**نبدأ JA FalconCore Automated Trading Platform من v0.0.0. المؤشر القديم يبقى مصدر بحث فقط. كل Strategy وكل Engine يجب أن يكون مستقلًا. التنفيذ الحقيقي مغلق حتى تنضج طبقات Shadow/Paper/Demo. ملف ذاكرة المشروع يصبح إلزاميًا بعد كل إصدار وقبل كل جلسة جديدة.**
