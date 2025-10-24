//+------------------------------------------------------------------+
//|                                          PositionManager.mqh     |
//|                    Gestionnaire de positions et comptage         |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "../Logger.mqh"

//+------------------------------------------------------------------+
//| Classe PositionManager - Gestion des positions                   |
//+------------------------------------------------------------------+
class PositionManager
{
private:
   string            m_symbol;              // Symbole géré
   int               m_magicNumber;         // Magic number pour filtrer
   CTrade*           m_trade;               // Objet de trading (injecté)
   CPositionInfo     m_position;            // Gestionnaire de positions
   
   // Compteurs
   int               m_buyPositions;        // Nombre de positions BUY
   int               m_sellPositions;       // Nombre de positions SELL
   int               m_totalPositions;      // Total des positions
   
   // Statistiques
   double            m_totalProfit;         // Profit total
   double            m_totalSwap;           // Swap total
   double            m_totalCommission;     // Commission totale
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   PositionManager(string symbol, int magicNumber, CTrade* trade)
   {
      // FIXED: Vérification NULL des dépendances critiques
      if(trade == NULL)
      {
         Logger::Error("CRITICAL: NULL dependency in PositionManager constructor");
         Logger::Error("  - CTrade: NULL");
         
         // Initialiser avec des valeurs sûres par défaut
         m_symbol = symbol;
         m_magicNumber = magicNumber;
         m_trade = trade;
         m_buyPositions = 0;
         m_sellPositions = 0;
         m_totalPositions = 0;
         m_totalProfit = 0;
         m_totalSwap = 0;
         m_totalCommission = 0;
         return;
      }
      
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_trade = trade;
      
      // Initialiser les compteurs
      m_buyPositions = 0;
      m_sellPositions = 0;
      m_totalPositions = 0;
      m_totalProfit = 0;
      m_totalSwap = 0;
      m_totalCommission = 0;
      
      Logger::Debug("PositionManager initialized for " + symbol + " | Magic: " + IntegerToString(magicNumber));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~PositionManager()
   {
      Logger::Debug("PositionManager destroyed for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les compteurs de positions                        |
   //+------------------------------------------------------------------+
   void UpdateCounters()
   {
      m_buyPositions = 0;
      m_sellPositions = 0;
      m_totalPositions = 0;
      m_totalProfit = 0;
      m_totalSwap = 0;
      m_totalCommission = 0;
      
      // Compter les positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magicNumber)
            {
               m_totalPositions++;
               
               if(m_position.PositionType() == POSITION_TYPE_BUY)
                  m_buyPositions++;
               else if(m_position.PositionType() == POSITION_TYPE_SELL)
                  m_sellPositions++;
               
               // Accumuler les statistiques
               m_totalProfit += m_position.Profit();
               m_totalSwap += m_position.Swap();
               m_totalCommission += m_position.Commission();
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Fermer toutes les positions pour ce symbole                     |
   //| @return Nombre de positions fermées                             |
   //+------------------------------------------------------------------+
   int CloseAllPositions()
   {
      int closedCount = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magicNumber)
            {
               ulong ticket = m_position.Ticket();
               // FIXED: Vérifier NULL et utiliser -> pour les pointeurs
               if(m_trade != NULL && m_trade.PositionClose(ticket))
               {
                  closedCount++;
                  Logger::Info("Position #" + IntegerToString(ticket) + " closed for " + m_symbol);
               }
               else
               {
                  Logger::Error("Failed to close position #" + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
               }
            }
         }
      }
      
      if(closedCount > 0)
      {
         Logger::Info("Closed " + IntegerToString(closedCount) + " position(s) for " + m_symbol);
         UpdateCounters(); // Mettre à jour les compteurs après fermeture
      }
      
      return closedCount;
   }
   
   //+------------------------------------------------------------------+
   //| Fermer les positions d'un type spécifique                       |
   //| @return Nombre de positions fermées                             |
   //+------------------------------------------------------------------+
   int ClosePositionsByType(ENUM_POSITION_TYPE positionType)
   {
      int closedCount = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol && 
               m_position.Magic() == m_magicNumber && 
               m_position.PositionType() == positionType)
            {
               ulong ticket = m_position.Ticket();
               // FIXED: Vérifier NULL et utiliser -> pour les pointeurs
               if(m_trade != NULL && m_trade.PositionClose(ticket))
               {
                  closedCount++;
                  Logger::Info("Position #" + IntegerToString(ticket) + " (" + EnumToString(positionType) + ") closed for " + m_symbol);
               }
               else
               {
                  Logger::Error("Failed to close position #" + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
               }
            }
         }
      }
      
      if(closedCount > 0)
      {
         Logger::Info("Closed " + IntegerToString(closedCount) + " " + EnumToString(positionType) + " position(s) for " + m_symbol);
         UpdateCounters(); // Mettre à jour les compteurs après fermeture
      }
      
      return closedCount;
   }
   
   //+------------------------------------------------------------------+
   //| Fermer une position spécifique par ticket                       |
   //| @return true si fermée avec succès, false sinon                 |
   //+------------------------------------------------------------------+
   bool ClosePosition(ulong ticket)
   {
      if(!m_position.SelectByTicket(ticket))
      {
         Logger::Error("Position #" + IntegerToString(ticket) + " not found");
         return false;
      }
      
      if(m_position.Symbol() != m_symbol || m_position.Magic() != m_magicNumber)
      {
         Logger::Error("Position #" + IntegerToString(ticket) + " does not belong to this manager");
         return false;
      }
      
      // FIXED: Vérifier NULL et utiliser -> pour les pointeurs
      if(m_trade != NULL && m_trade.PositionClose(ticket))
      {
         Logger::Info("Position #" + IntegerToString(ticket) + " closed for " + m_symbol);
         UpdateCounters(); // Mettre à jour les compteurs après fermeture
         return true;
      }
      else
      {
         Logger::Error("Failed to close position #" + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Modifier une position (SL/TP)                                   |
   //| @return true si modifiée avec succès, false sinon               |
   //+------------------------------------------------------------------+
   bool ModifyPosition(ulong ticket, double newSL, double newTP)
   {
      if(!m_position.SelectByTicket(ticket))
      {
         Logger::Error("Position #" + IntegerToString(ticket) + " not found");
         return false;
      }
      
      if(m_position.Symbol() != m_symbol || m_position.Magic() != m_magicNumber)
      {
         Logger::Error("Position #" + IntegerToString(ticket) + " does not belong to this manager");
         return false;
      }
      
      // FIXED: Vérifier NULL et utiliser -> pour les pointeurs
      if(m_trade != NULL && m_trade.PositionModify(ticket, newSL, newTP))
      {
         Logger::Debug("Position #" + IntegerToString(ticket) + " modified | SL: " + DoubleToString(newSL, 5) + " | TP: " + DoubleToString(newTP, 5));
         return true;
      }
      else
      {
         Logger::Error("Failed to modify position #" + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations d'une position par ticket              |
   //| @return true si position trouvée, false sinon                   |
   //+------------------------------------------------------------------+
   bool GetPositionInfo(ulong ticket, double &openPrice, double &currentPrice, double &profit, 
                       double &swap, double &commission, ENUM_POSITION_TYPE &positionType)
   {
      if(!m_position.SelectByTicket(ticket))
         return false;
      
      if(m_position.Symbol() != m_symbol || m_position.Magic() != m_magicNumber)
         return false;
      
      openPrice = m_position.PriceOpen();
      currentPrice = m_position.PriceCurrent();
      profit = m_position.Profit();
      swap = m_position.Swap();
      commission = m_position.Commission();
      positionType = m_position.PositionType();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la liste des tickets de positions                       |
   //| @return Nombre de positions trouvées                            |
   //+------------------------------------------------------------------+
   int GetPositionTickets(ulong &tickets[])
   {
      ArrayResize(tickets, 0);
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol && m_position.Magic() == m_magicNumber)
            {
               int size = ArraySize(tickets);
               ArrayResize(tickets, size + 1);
               tickets[size] = m_position.Ticket();
            }
         }
      }
      
      return ArraySize(tickets);
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si une position existe                                 |
   //| @return true si la position existe pour ce manager, false sinon |
   //+------------------------------------------------------------------+
   bool HasPosition(ulong ticket)
   {
      if(!m_position.SelectByTicket(ticket))
         return false;
      
      return (m_position.Symbol() == m_symbol && m_position.Magic() == m_magicNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de positions BUY                              |
   //+------------------------------------------------------------------+
   int GetBuyPositions() const { return m_buyPositions; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de positions SELL                             |
   //+------------------------------------------------------------------+
   int GetSellPositions() const { return m_sellPositions; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total de positions                            |
   //+------------------------------------------------------------------+
   int GetTotalPositions() const { return m_totalPositions; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le profit total                                         |
   //+------------------------------------------------------------------+
   double GetTotalProfit() const { return m_totalProfit; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le swap total                                           |
   //+------------------------------------------------------------------+
   double GetTotalSwap() const { return m_totalSwap; }
   
   //+------------------------------------------------------------------+
   //| Obtenir la commission totale                                    |
   //+------------------------------------------------------------------+
   double GetTotalCommission() const { return m_totalCommission; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le P&L total (profit + swap + commission)              |
   //+------------------------------------------------------------------+
   double GetTotalPnL() const { return m_totalProfit + m_totalSwap + m_totalCommission; }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut                              |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string status = m_symbol + ": ";
      
      if(m_totalPositions == 0)
         status += "NO POSITIONS";
      else
      {
         status += "Positions: " + IntegerToString(m_totalPositions);
         status += " (B:" + IntegerToString(m_buyPositions) + " S:" + IntegerToString(m_sellPositions) + ")";
         
         double totalPnL = GetTotalPnL();
         if(totalPnL != 0)
         {
            status += " | P/L: " + DoubleToString(totalPnL, 2);
         }
      }
      
      return status;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo()
   {
      string info = "PositionManager for " + m_symbol + ":\n";
      info += "  Total Positions: " + IntegerToString(m_totalPositions) + "\n";
      info += "  Buy Positions: " + IntegerToString(m_buyPositions) + "\n";
      info += "  Sell Positions: " + IntegerToString(m_sellPositions) + "\n";
      info += "  Total Profit: " + DoubleToString(m_totalProfit, 2) + "\n";
      info += "  Total Swap: " + DoubleToString(m_totalSwap, 2) + "\n";
      info += "  Total Commission: " + DoubleToString(m_totalCommission, 2) + "\n";
      info += "  Total P&L: " + DoubleToString(GetTotalPnL(), 2);
      
      return info;
   }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation                                             |
//+------------------------------------------------------------------+
/*
// Création du gestionnaire de positions
CTrade* trade = new CTrade();
PositionManager* posMgr = new PositionManager("EURUSD", 12345, trade);

// Mettre à jour les compteurs
posMgr.UpdateCounters();

// Obtenir les statistiques
int totalPos = posMgr.GetTotalPositions();
double profit = posMgr.GetTotalProfit();

// Fermer toutes les positions
int closed = posMgr.CloseAllPositions();

// Fermer seulement les positions BUY
int buyClosed = posMgr.ClosePositionsByType(POSITION_TYPE_BUY);

// Fermer une position spécifique
bool success = posMgr.ClosePosition(123456);

// Modifier une position
bool modified = posMgr.ModifyPosition(123456, 1.0950, 1.1100);

// Obtenir les tickets de toutes les positions
ulong tickets[];
int count = posMgr.GetPositionTickets(tickets);

// Nettoyage
delete posMgr;
delete trade;
*/
