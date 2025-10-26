//+------------------------------------------------------------------+
//|                                        ForexSymbolStatus.mqh     |
//|                    Gestionnaire du statut pour un symbole       |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Classe ForexSymbolStatus - Gestion du statut pour un symbole    |
//+------------------------------------------------------------------+
class ForexSymbolStatus
{
private:
   // Données du symbole
   string            m_symbol;              // Nom du symbole
   int               m_magicNumber;         // Magic number unique
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe utilisé
   
   // Gestion des barres
   datetime          m_lastBarTime;         // Dernière barre traitée
   
   // Compteurs de positions/ordres
   int               m_buyTotal;            // Nombre positions/ordres BUY
   int               m_sellTotal;           // Nombre positions/ordres SELL
   
   // Statistiques
   double            m_totalProfit;         // Profit total pour ce symbole
   
   // Objets de gestion
   CPositionInfo     m_position;            // Gestion des positions
   COrderInfo        m_order;               // Gestion des ordres
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   ForexSymbolStatus(string symbol, int magicNumber, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      
      // Initialiser les variables
      m_lastBarTime = iTime(symbol, timeframe, 0);
      m_buyTotal = 0;
      m_sellTotal = 0;
      m_totalProfit = 0;
      
      Print("✓ ForexSymbolStatus initialized for ", symbol, " | Magic: ", magicNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~ForexSymbolStatus()
   {
      Print("✓ ForexSymbolStatus destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut pour l'affichage             |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string status = m_symbol + ": ";
      
      if(m_buyTotal + m_sellTotal == 0)
         status += "IDLE";
      else
      {
         status += "ACTIVE | Pos: " + IntegerToString(m_buyTotal + m_sellTotal);
         status += " (B:" + IntegerToString(m_buyTotal) + " S:" + IntegerToString(m_sellTotal) + ")";
         
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
      return m_buyTotal + m_sellTotal;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de positions BUY                              |
   //+------------------------------------------------------------------+
   int GetBuyTotal()
   {
      return m_buyTotal;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de positions SELL                             |
   //+------------------------------------------------------------------+
   int GetSellTotal()
   {
      return m_sellTotal;
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
      m_buyTotal = 0;
      m_sellTotal = 0;
      
      // Compter les positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magicNumber)
            {
               if(m_position.PositionType() == POSITION_TYPE_BUY) m_buyTotal++;
               if(m_position.PositionType() == POSITION_TYPE_SELL) m_sellTotal++;
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
               if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) m_buyTotal++;
               if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP) m_sellTotal++;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Définir manuellement les compteurs                              |
   //+------------------------------------------------------------------+
   void SetCounters(int buyTotal, int sellTotal)
   {
      m_buyTotal = buyTotal;
      m_sellTotal = sellTotal;
   }
   
   //+------------------------------------------------------------------+
   //| Réinitialiser les compteurs                                    |
   //+------------------------------------------------------------------+
   void ResetCounters()
   {
      m_buyTotal = 0;
      m_sellTotal = 0;
      m_totalProfit = 0;
   }
};
