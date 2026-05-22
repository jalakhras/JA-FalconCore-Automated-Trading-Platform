//+------------------------------------------------------------------+
//| Strategies/S00_ScalpFvgMicro/S00_FvgDetector.mqh                 |
//| R1.1a - three-candle FVG detection on CLOSED M5 bars + the three |
//| quality filters + the S00_FvgDetection_Diagnostics.csv writer.   |
//|                                                                  |
//| ============ CRITICAL: ZERO LOOKAHEAD ============               |
//|                                                                  |
//| Every candle read in this file uses CFalconMarketContext::       |
//| GetCandleSnapshot with shift >= 1, never 0. shift=0 in MQL5 is   |
//| the live forming bar, whose OHLC will keep changing until the    |
//| bar closes - reading it on backtest = future-leakage. ReadClosedM5|
//| asserts (shift < 1 -> return false) so a future maintainer can't |
//| accidentally widen this surface.                                 |
//|                                                                  |
//| ATR/MA buffers are read the same way: CopyBuffer(handle, 0, 1, 1)|
//| - start=1 means CLOSED bar, start=0 would expose the live bar.   |
//+------------------------------------------------------------------+
#ifndef FALCON_S00_FVG_DETECTOR_MQH
#define FALCON_S00_FVG_DETECTOR_MQH

// Per-gap status. R1.1a only ever sets ACTIVE or REJECTED. EXPIRED /
// INVALIDATED are reserved for R1.1b (gap expiry on S00_GapExpiry
// bars elapsed; invalidation on adverse close-through-far-edge).
enum ENUM_S00_FVG_STATUS
{
   S00_FVG_STATUS_ACTIVE      = 0,
   S00_FVG_STATUS_REJECTED    = 1,
   S00_FVG_STATUS_EXPIRED     = 2,
   S00_FVG_STATUS_INVALIDATED = 3
};

// Persistent record. The active list is the handoff surface for the
// R1.1b entry logic.
struct S00FvgRecord
{
   datetime              formation_time;        // close-time of C3 (most recent CLOSED M5 bar at detection)
   ENUM_S00_FVG_DIRECTION direction;
   double                gap_high;
   double                gap_low;
   double                gap_size_points;
   double                ce;                    // midpoint = (gap_high + gap_low) / 2
   double                atr_at_detection;      // ATR(M5, S00_ATR_PERIOD) read from CLOSED bar (price units)
   double                trend_ma_at_detection; // SMA(M5, S00_TrendMA, close) read from CLOSED bar
   ENUM_S00_FVG_STATUS   status;
   string                reject_reason;         // "" | "SIZE" | "ATR" | "TREND"
};

class CS00FvgDetector
{
private:
   int               m_atr_handle;
   int               m_ma_handle;
   datetime          m_last_evaluated_bar_time;     // dedupe key: only one detection per closed C3 bar
   bool              m_diag_header_written;
   string            m_diag_file_name;

   S00FvgRecord      m_active_fvgs[];
   int               m_active_fvg_count;

   //--------------- indicator handles (M5, closed-bar reads) ------------
   bool EnsureIndicatorHandles()
   {
      if(m_atr_handle == INVALID_HANDLE)
         m_atr_handle = iATR(_Symbol, PERIOD_M5, S00_ATR_PERIOD);
      if(m_ma_handle == INVALID_HANDLE)
         m_ma_handle  = iMA(_Symbol, PERIOD_M5, S00_TrendMA, 0, MODE_SMA, PRICE_CLOSE);
      return (m_atr_handle != INVALID_HANDLE && m_ma_handle != INVALID_HANDLE);
   }

   // start=1 in CopyBuffer = CLOSED bar. start=0 would be the live bar.
   double ReadClosedBarATR()
   {
      double buf[];
      if(CopyBuffer(m_atr_handle, 0, 1, 1, buf) <= 0)
         return 0.0;
      return buf[0];
   }

   double ReadClosedBarMA()
   {
      double buf[];
      if(CopyBuffer(m_ma_handle, 0, 1, 1, buf) <= 0)
         return 0.0;
      return buf[0];
   }

   // ZERO-LOOKAHEAD assertion lives here. Refuse shift < 1.
   bool ReadClosedM5(const int shift,
                     CFalconMarketContext &market_context,
                     FalconCandleSnapshot &snap)
   {
      if(shift < 1)
         return false;
      return market_context.GetCandleSnapshot(PERIOD_M5, shift, snap);
   }

   //--------------- diagnostic CSV ------------
   void WriteDiagnosticsHeader()
   {
      int handle = FileOpen(m_diag_file_name, FalconReportWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
         return;
      const string header =
            "FormationTime,Direction,GapHigh,GapLow,CE,GapSizePoints,"
            "AtrM5,TrendMaM5,SpotPriceClose,Status,RejectReason";
      FileWriteString(handle, header + "\r\n");
      FileClose(handle);
      m_diag_header_written = true;
   }

   void AppendDiagnosticsRow(const S00FvgRecord &rec, const double spot_close)
   {
      if(!m_diag_header_written)
         WriteDiagnosticsHeader();
      int handle = FileOpen(m_diag_file_name, FalconReportReadWriteCsvFlags(), ',');
      if(handle == INVALID_HANDLE)
         return;
      FileSeek(handle, 0, SEEK_END);
      const string dir_label =
            (rec.direction == S00_FVG_DIR_BULLISH ? "BULLISH"
             : rec.direction == S00_FVG_DIR_BEARISH ? "BEARISH" : "NONE");
      const string status_label =
            (rec.status == S00_FVG_STATUS_ACTIVE ? "ACCEPTED" : "REJECTED");
      const string row =
            FalconTimeToString(rec.formation_time) + "," +
            dir_label + "," +
            DoubleToString(rec.gap_high,            _Digits) + "," +
            DoubleToString(rec.gap_low,             _Digits) + "," +
            DoubleToString(rec.ce,                  _Digits) + "," +
            DoubleToString(rec.gap_size_points,     1) + "," +
            DoubleToString(rec.atr_at_detection,    _Digits) + "," +
            DoubleToString(rec.trend_ma_at_detection,_Digits) + "," +
            DoubleToString(spot_close,              _Digits) + "," +
            status_label + "," +
            rec.reject_reason;
      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
   }

   void PushActive(const S00FvgRecord &rec)
   {
      const int new_size = m_active_fvg_count + 1;
      ArrayResize(m_active_fvgs, new_size);
      m_active_fvgs[m_active_fvg_count] = rec;
      m_active_fvg_count = new_size;
   }

public:
   CS00FvgDetector()
   {
      m_atr_handle               = INVALID_HANDLE;
      m_ma_handle                = INVALID_HANDLE;
      m_last_evaluated_bar_time  = 0;
      m_diag_header_written      = false;
      m_diag_file_name           = "";
      m_active_fvg_count         = 0;
      ArrayResize(m_active_fvgs, 0);
   }

   //----------------------------------------------------------------
   // R1.1a entry point. Called from OnTick.
   //
   // Gate widened in R1.1b: detection runs whenever either consumer
   // is on -
   //   - Enable_S00_FvgScalp == true  : the entry logic in
   //                                    CS00EntryLogic needs the
   //                                    active FVG list.
   //   - S00_DiagReport == true       : the diagnostic CSV needs
   //                                    every accepted / rejected
   //                                    FVG row.
   // When both are off, the method is a pure no-op - zero candle
   // reads, zero allocations, zero side effects.
   //
   // The diagnostic CSV write is gated separately on S00_DiagReport
   // (further below) so the strategy can run without producing the
   // detection report.
   //
   // Runs at most once per closed M5 bar (dedupe via
   // m_last_evaluated_bar_time).
   //----------------------------------------------------------------
   void EvaluateOnNewBar(CFalconMarketContext &market_context)
   {
      if(!Enable_S00_FvgScalp && !S00_DiagReport) return;
      if(!EnsureIndicatorHandles())               return;
      if(S00_DiagReport && m_diag_file_name == "")
         m_diag_file_name = FalconBuildReportFileName("S00_FvgDetection_Diagnostics");

      // CLOSED M5 bars: shift=3 (C1, oldest), shift=2 (C2, impulse),
      // shift=1 (C3, most recent CLOSED bar - the "right-edge" bar of
      // the three-candle window). shift=0 is forbidden by ReadClosedM5.
      FalconCandleSnapshot c1, c2, c3;
      if(!ReadClosedM5(3, market_context, c1)) return;
      if(!ReadClosedM5(2, market_context, c2)) return;
      if(!ReadClosedM5(1, market_context, c3)) return;

      // One detection per closed C3 bar.
      if(c3.time == m_last_evaluated_bar_time) return;
      m_last_evaluated_bar_time = c3.time;

      S00FvgRecord rec;
      rec.formation_time           = c3.time;
      rec.direction                = S00_FVG_DIR_NONE;
      rec.gap_high                 = 0.0;
      rec.gap_low                  = 0.0;
      rec.gap_size_points          = 0.0;
      rec.ce                       = 0.0;
      rec.atr_at_detection         = 0.0;
      rec.trend_ma_at_detection    = 0.0;
      rec.status                   = S00_FVG_STATUS_REJECTED;
      rec.reject_reason            = "";

      // Three-candle pattern (per ScalpFvgMicro_SPEC §2).
      if(c3.low > c1.high)
      {
         rec.direction = S00_FVG_DIR_BULLISH;
         rec.gap_high  = c3.low;
         rec.gap_low   = c1.high;
      }
      else if(c3.high < c1.low)
      {
         rec.direction = S00_FVG_DIR_BEARISH;
         rec.gap_high  = c1.low;
         rec.gap_low   = c3.high;
      }
      else
      {
         // No FVG window on this triple: skip without writing a row.
         // The diagnostic only records detected patterns (accepted or
         // rejected by the filters), not every closed bar.
         return;
      }

      const double point = (_Point > 0.0 ? _Point : 1.0);
      rec.gap_size_points       = (rec.gap_high - rec.gap_low) / point;
      rec.ce                    = (rec.gap_high + rec.gap_low) * 0.5;
      rec.atr_at_detection      = ReadClosedBarATR();
      rec.trend_ma_at_detection = ReadClosedBarMA();

      // Apply the three quality filters.
      string reject_reason = "";
      const bool passed = CS00FvgQualityFilter::Evaluate(rec.gap_size_points,
                                                         rec.direction,
                                                         rec.atr_at_detection,
                                                         rec.trend_ma_at_detection,
                                                         c3.close,
                                                         reject_reason);
      if(passed)
      {
         rec.status        = S00_FVG_STATUS_ACTIVE;
         rec.reject_reason = "";
         PushActive(rec);
      }
      else
      {
         rec.status        = S00_FVG_STATUS_REJECTED;
         rec.reject_reason = reject_reason;
      }

      // R1.1b: CSV write gated separately - the strategy can run without
      // producing the detection diagnostic report.
      if(S00_DiagReport)
         AppendDiagnosticsRow(rec, c3.close);
   }

   //----------------------------------------------------------------
   // R1.1b/c hand-off surface. Not consumed in R1.1a.
   //----------------------------------------------------------------
   int ActiveFvgCount() const
   {
      return m_active_fvg_count;
   }

   S00FvgRecord GetActiveFvg(const int idx) const
   {
      S00FvgRecord empty;
      empty.formation_time           = 0;
      empty.direction                = S00_FVG_DIR_NONE;
      empty.gap_high                 = 0.0;
      empty.gap_low                  = 0.0;
      empty.gap_size_points          = 0.0;
      empty.ce                       = 0.0;
      empty.atr_at_detection         = 0.0;
      empty.trend_ma_at_detection    = 0.0;
      empty.status                   = S00_FVG_STATUS_REJECTED;
      empty.reject_reason            = "";
      if(idx < 0 || idx >= m_active_fvg_count) return empty;
      return m_active_fvgs[idx];
   }
};

// R1.1a: file-scope instance. The single OnTick call site invokes
// EvaluateOnNewBar(g_market_context) which self-gates on the
// diagnostic switch - no other caller exists in R1.1a.
CS00FvgDetector g_s00_fvg_detector;

#endif // FALCON_S00_FVG_DETECTOR_MQH
