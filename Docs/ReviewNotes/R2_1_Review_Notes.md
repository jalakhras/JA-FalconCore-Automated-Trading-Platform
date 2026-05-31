# R2.1 — Review Notes

## FvgMicroRetest spec-aligned + Q3 retest-confirmation fix داخل Watcher

> **النوع:** إغلاق مرحلة — commit واحد + تحديث وثائق.
> **الفرع:** `refactor`. **يسبقه:** R1.7 closeout +
> `Spec_R2_1_FvgMicroComplete.md` + التشغيلات التحقّقيّة.
> **المرجع الحاكم:** `Spec_R2_1_Closeout.md`.

---

## ١. ملخّص التنفيذ — 7 تعديلات spec-aligned + Q3 fix

التغييرات في الـ working copy (`Core/FalconConstants.mqh` +
`JA_FalconCore_Automated_Trading_Platform.mq5`) تُحاذي شرح استراتيجيّة
FvgMicroRetest مع شرحها الأصليّ:

1. **مرتكز TP:** حدّ FVG → midpoint (نقطة الدخول).
2. **Invalidation guard:** إغلاق متجاوز يُبطل المنطقة.
3. **Spread guard:** نسبيّ — `spread / zoneSize ≤ 0.50`.
4. **SL buffer:** قابل للضبط عبر `FvgMicroSlBufferPoints` (افتراضي 30).
5. **Age guard:** فعّال — حدّ أقصى 12 شمعة على M5.
6. **Retest confirmation (Q3 fix):** بوّابة اختياريّة — **حساب محليّ
   داخل Watcher بدون تعديل snapshot** (الخيار الثالث؛ لا يلمس بنية
   الـ snapshot المشتركة).
7. **Min size:** `1.00 → 30.0` (placeholder للمعايرة بعد R2.2).

اكتشاف Q3 retest-confirmation اللاحق تمّ احتواؤه داخل Watcher محليًّا،
وتحقّق بنجاح في 5 تشغيلاتٍ تحقّقيّة.

---

## ٢. التشغيلات التحقّقيّة الخمسة

| التشغيل | النافذة | الإعداد | Final Balance | Broker Actual |
|---|---|---|---:|---:|
| Smoke Shadow | 04-01→04-03 | FvgMicro only | 253.17 | 53.17 |
| April Shadow | 04-01→04-30 | FvgMicro only (≡ Test C) | 263.66 | 63.66 |
| **Test A** | 04-01→04-30 | S01 + FvgMicro + TM/Prot ON | **614.45** | **417.37** |
| Test B | 04-01→04-30 | S01 + TM/Prot ON (≡ R1.7 SanityON) | 482.64 | 275.97 |
| Test C | 04-01→04-30 | FvgMicro only | 263.66 | 63.66 |

ملفّات الـ `.set` المرافقة محفوظة في `Docs/SetFiles/R2_1/`:
`R2_1_TestA_PreR17_Reproduce.set` (الـ baseline الإنتاجيّ)،
`R2_1_TestC_FvgMicroOnly_Baseline.set` (الـ baseline العلميّ)،
`R2_1_TestB_R17_SanityON_Reproduce.set` (نقطة لمسٍ مرجعيّة).

---

## ٣. تأكيد الـ invariants

- **الحارس يعمل:** في Test C (FvgMicro وحدها، TM/Protection OFF):
  `ProtectionActivated = 0` و `RunnerActivated = 0`. لا تسرّب gate،
  لا ذاكرة فاسدة — اتّساقًا مع قاعدة R1.7 (الحارس داخل Apply بعد
  التهيئة الدفاعيّة).
- **شاشة Tester ≈ EA report:** صافي شاشة الـ Strategy Tester يطابق
  تقرير الـ EA ضمن فروق العمولة/السواب — لا انحراف بنيويّ.
- **Test B يطابق R1.7 SanityON بالضبط** (482.64 / Broker 275.97) —
  نقطة لمسٍ مرجعيّة تثبت أنّ تغييرات R2.1 لم تُحدِث انحدارًا في مسار
  S01 + TM/Protection.

---

## ٤. الـ baseline الإنتاجيّ المرجعيّ الجديد (Test A، أبريل 2026)

**US100_Spot M5 — الإعداد الكامل (S01 + FvgMicro + TM/Prot ON):**

| المقياس | Test A |
|---|---:|
| TotalTrades | 1168 |
| RawNetUSD | 1194.23 |
| FinalWorkingNetUSD | 1264.42 |
| **BrokerActualNetUSD** | **417.37** |
| Tester Net Profit | 414.45 |
| Final Balance (200 ابتدائيّ) | **614.45** |
| ProtectionActivated | 515 |
| RunnerActivated | 225 |
| WinRate | 50.00% |
| Balance DD Absolute | 5.03 |
| Equity DD Absolute | 6.25 |

**الـ baseline العاري لـ FvgMicroRetest وحدها (Test C، نفس النافذة):**
558 صفقة، Broker 63.66، Final Balance 263.66، WR 63.44%،
Equity DD 97.51 (كبير — بدون TM).

**الاكتشاف المركزيّ — التركيب يضيف قيمة:** A − (B+C) = **+77.74 USD**.
Trade Management (Apply #5/#6) يتدخّل 515/225 مرّة في الإعداد الكامل
(Test A) مقابل 0 في FvgMicroRetest وحدها (Test C). الإدارة ليست زخرفًا.

**التراجع المُتوهَّم (528.59 → 263.66) كان «مقارنة برتقال بتفّاح»:**
R2.1 الحاليّ على إعداداتٍ pre-R1.7 موحَّدة = **614.45** — أعلى بـ 86
دولارًا من المرجع التاريخيّ، لا أدنى منه.

---

## ٥. درسٌ مُسجَّل

> **حدسٌ بتراجع يستحقّ تحقّقًا قبل أيّ إصلاح.** التحقّق = 3 تشغيلاتٍ
> بإعداداتٍ متطابقة على نفس النافذة، لا نقاشًا نظريًّا. مقارنة الإعدادات
> السابقة بالحاليّة دون توحيد الإعدادات = برتقال بتفّاح. الحدس بأنّ R2.1
> «تراجَع» كان خطأ مقارنة؛ البيانات الموحَّدة أثبتت تحسّنًا بـ 86 دولارًا.

(مُدوَّن أيضًا كمعرفة #11 + #12 في ملفّ ذاكرة المشروع `R2_1_closed`.)

---

## ٦. Problems — بلا تغيير في هذا الـ commit

الـ defects المتبقّية تبقى مفتوحة كما هي، **غير حاجبة لـ R2.2**:
- **#2 —** `BrokerModifySent` / `RuntimeSLChanged` counter أعمى عن مسار المنسّق.
- **#3 —** `ReportIntegrityStatus = FAIL` إيجابيّة كاذبة (بوّابة `EnableTierEmergencyReports`).
- **#5 —** عمود `TP2` في الـ Reconciliation غير مُهيَّأ.

---

## ٧. القيود المُلتزَمة (من §٣ المواصفة)

- لا تغيير كود في هذا الـ commit — تغييرات R2.1 في الـ working copy هي
  ما يُلتزَم كما هي.
- commit واحد فقط على `refactor`.
- لا تنظيف، لا تحسينات، لا إعادة تنسيق — أيّ فكرة → Backlog (§٤-ج).
- لا تشغيلات إضافيّة بعد الـ commit في هذه المرحلة.
