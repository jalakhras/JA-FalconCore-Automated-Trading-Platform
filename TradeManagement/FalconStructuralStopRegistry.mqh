//+------------------------------------------------------------------+
//| TradeManagement/FalconStructuralStopRegistry.mqh                 |
//| R1.5a-fix: position_ticket -> structural_stop_price map.         |
//|                                                                  |
//| The hybrid-context fix. The broker SL on a Falcon position is    |
//| the wide LOCK-parity emergency envelope (calibrated to a bounded |
//| loss cap), NOT the strategy's structural stop. The protection    |
//| policy needs the strategy's intended risk to size R. The         |
//| strategy knows its structural stop at entry; this registry       |
//| carries that one value from the entry bridge (where it is known) |
//| to the trade-management coordinator (where the managed-position  |
//| context is built), keyed by broker position ticket. It is        |
//| recorded the moment the broker position opens and cleared when   |
//| the position closes. A ticket absent from the map => structural  |
//| stop 0.0 => the policy safely refuses to arm (no arming on a     |
//| missing input).                                                  |
//|                                                                  |
//| Dependency-free on purpose: it is #included BEFORE the entry     |
//| bridge so the bridge can record into the same global the         |
//| coordinator later reads.                                         |
//+------------------------------------------------------------------+
#ifndef FALCON_STRUCTURAL_STOP_REGISTRY_MQH
#define FALCON_STRUCTURAL_STOP_REGISTRY_MQH

class CFalconStructuralStopRegistry
{
private:
   ulong  m_tickets[];
   double m_structural_stops[];

   int IndexOf(const ulong ticket)
   {
      int n = ArraySize(m_tickets);
      for(int i = 0; i < n; i++)
         if(m_tickets[i] == ticket)
            return i;
      return -1;
   }

public:
   // Record (or overwrite) the structural stop for an open position.
   void Record(const ulong ticket, const double structural_stop_price)
   {
      if(ticket == 0)
         return;
      int idx = IndexOf(ticket);
      if(idx >= 0)
      {
         m_structural_stops[idx] = structural_stop_price;
         return;
      }
      int n = ArraySize(m_tickets);
      ArrayResize(m_tickets, n + 1);
      ArrayResize(m_structural_stops, n + 1);
      m_tickets[n]          = ticket;
      m_structural_stops[n] = structural_stop_price;
   }

   // Look up the structural stop for a ticket. Returns false (and leaves
   // structural_stop_price at 0.0) when the ticket is unknown.
   bool Get(const ulong ticket, double &structural_stop_price)
   {
      structural_stop_price = 0.0;
      int idx = IndexOf(ticket);
      if(idx < 0)
         return false;
      structural_stop_price = m_structural_stops[idx];
      return true;
   }

   // Drop a ticket's entry when its position closes.
   void Remove(const ulong ticket)
   {
      int idx = IndexOf(ticket);
      if(idx < 0)
         return;
      int n = ArraySize(m_tickets);
      for(int i = idx; i < n - 1; i++)
      {
         m_tickets[i]          = m_tickets[i + 1];
         m_structural_stops[i] = m_structural_stops[i + 1];
      }
      ArrayResize(m_tickets, n - 1);
      ArrayResize(m_structural_stops, n - 1);
   }
};

// One process-wide registry. Declared here so both the entry bridge
// (writer) and the trade-management coordinator (reader) bind to it.
CFalconStructuralStopRegistry g_structural_stop_registry;

#endif // FALCON_STRUCTURAL_STOP_REGISTRY_MQH
