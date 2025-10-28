//+------------------------------------------------------------------+
//|                                            SymbolStatus.mqh     |
//|                    Gestionnaire du statut pour un symbole       |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Classe SymbolStatus - Gestion du statut pour un symbole       |
//+------------------------------------------------------------------+
class SymbolStatus
{
private:
   // Données du symbole
   string            m_symbol;              // Nom du symbole
   int               m_magicNumber;         // Magic number unique
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe utilisé
   
   // Gestion des barres
   datetime          m_lastBarTime;         // Dernière barre traitée
   
   // Compteurs de positions/ordres
   int               m_underPriceTotal;     // Nombre positions/ordres sous le prix actuel
   int               m_overPriceTotal;      // Nombre positions/ordres au-dessus du prix actuel
   
   // Statistiques
   double            m_totalProfit;         // Profit total pour ce symbole
   
   // Objets de gestion
   CPositionInfo     m_position;            // Gestion des positions
   COrderInfo        m_order;               // Gestion des ordres
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   SymbolStatus(string symbol, int magicNumber, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      
      // Initialiser les variables
      m_lastBarTime = iTime(symbol, timeframe, 0);
      m_underPriceTotal = 0;
      m_overPriceTotal = 0;
      m_totalProfit = 0;
      
      Print("✓ SymbolStatus initialized for ", symbol, " | Magic: ", magicNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~SymbolStatus()
   {
      Print("✓ SymbolStatus destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut pour l'affichage             |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string status = m_symbol + ": ";
      
      if(m_underPriceTotal + m_overPriceTotal == 0)
         status += "IDLE";
      else
      {
         status += "ACTIVE | Pos: " + IntegerToString(m_underPriceTotal + m_overPriceTotal);
         status += " (Under:" + IntegerToString(m_underPriceTotal) + " Over:" + IntegerToString(m_overPriceTotal) + ")";
         
         if(m_totalProfit != 0)
         {
            status += " | P/L: " + DoubleToString(m_totalProfit, 2);
         }
      }
      
      return status;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le profit total pour ce symbole                         |
   //+------------------------------------------------------------------+
   double GetTotalProfit()
   {
      m_totalProfit = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() == m_magicNumber && m_position.Symbol() == m_symbol)
            {
               m_totalProfit += m_position.Profit() + m_position.Swap() + m_position.Commission();
            }
         }
      }
      
      return m_totalProfit;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total de positions                            |
   //+------------------------------------------------------------------+
   int GetTotalPositions()
   {
      return m_underPriceTotal + m_overPriceTotal;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de positions/ordres sous le prix              |
   //+------------------------------------------------------------------+
   int GetUnderPriceTotal()
   {
      return m_underPriceTotal;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de positions/ordres au-dessus du prix         |
   //+------------------------------------------------------------------+
   int GetOverPriceTotal()
   {
      return m_overPriceTotal;
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si c'est une nouvelle barre                            |
   //+------------------------------------------------------------------+
   bool IsNewBar()
   {
      datetime currentTime = iTime(m_symbol, m_timeframe, 0);
      
      if(m_lastBarTime != currentTime)
      {
         m_lastBarTime = currentTime;
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les compteurs de positions/ordres                |
   //+------------------------------------------------------------------+
   void UpdateCounters()
   {
      m_underPriceTotal = 0;
      m_overPriceTotal = 0;
      
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Compter les positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magicNumber)
            {
               double openPrice = m_position.PriceOpen();
               
               if(openPrice < currentPrice)
                  m_underPriceTotal++;
               else if(openPrice > currentPrice)
                  m_overPriceTotal++;
            }
         }
      }
      
      // Compter les ordres en attente
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetString(ORDER_SYMBOL) == m_symbol && OrderGetInteger(ORDER_MAGIC) == m_magicNumber)
            {
               double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               
               if(orderPrice < currentPrice)
                  m_underPriceTotal++;
               else if(orderPrice > currentPrice)
                  m_overPriceTotal++;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Définir manuellement les compteurs                              |
   //+------------------------------------------------------------------+
   void SetCounters(int underPriceTotal, int overPriceTotal)
   {
      m_underPriceTotal = underPriceTotal;
      m_overPriceTotal = overPriceTotal;
   }
   
   //+------------------------------------------------------------------+
   //| Réinitialiser les compteurs                                    |
   //+------------------------------------------------------------------+
   void ResetCounters()
   {
      m_underPriceTotal = 0;
      m_overPriceTotal = 0;
      m_totalProfit = 0;
   }
};
