//+------------------------------------------------------------------+
//|                                            JT_SymbolTrader.mqh   |
//|                    Classe de trading par symbole individuel      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "CCommissionManager.mqh"
#include "filters/TimesàDaysFilters/JT_TimeFilter.mqh"
//+------------------------------------------------------------------+
//| Classe CSymbolTrader - Gestion d'un symbole spécifique          |
//+------------------------------------------------------------------+
class CSymbolTrader
{
private:
   // Données du symbole
   string            m_symbol;              // Nom du symbole
   double            m_point;               // Point du symbole
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe utilisé
   
   // Magic number unique pour ce symbole
   int               m_magicNumber;
   
   // Gestion des barres
   datetime          m_lastBarTime;         // Dernière barre traitée
   
   // Compteurs de positions/ordres
   int               m_buyTotal;            // Nombre positions/ordres BUY
   int               m_sellTotal;           // Nombre positions/ordres SELL
   
   // Paramètres de trading
   double            m_riskPercent;         // Risque par symbole
   int               m_tpPoints;            // Take Profit en points
   int               m_slPoints;            // Stop Loss en points
   int               m_tslTriggerPoints;    // Points en profit avant TSL
   int               m_tslPoints;           // Trailing Stop Loss
   int               m_barsN;               // Nombre de barres pour l'analyse
   int               m_expirationBars;      // Expiration des ordres
   int               m_orderDistPoints;     // Distance des ordres
   string            m_tradeComment;        // Commentaire des trades
   
   // Objets de trading
   CTrade            m_trade;               // Objet de trading
   CPositionInfo     m_position;            // Gestion des positions
   COrderInfo        m_order;               // Gestion des ordres
   CCommissionManager m_commissionManager;  // Gestionnaire de commission
   
   // Statistiques
   double            m_totalProfit;         // Profit total pour ce symbole
   int               m_tradesCount;         // Nombre de trades
   
   // Historique des points détectés
   double            m_lastHighPoints[3];   // 3 derniers high points
   double            m_lastLowPoints[3];    // 3 derniers low points
   datetime          m_lastHighTimes[3];    // Times des high points
   datetime          m_lastLowTimes[3];     // Times des low points

   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CSymbolTrader(string symbol, 
                 int magicNumber,
                 ENUM_TIMEFRAMES timeframe,
                 double riskPercent,
                 int tpPoints,
                 int slPoints,
                 int tslTriggerPoints,
                 int tslPoints,
                 int barsN,
                 int expirationBars,
                 int orderDistPoints,
                 string tradeComment)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      m_riskPercent = riskPercent;
      m_tpPoints = tpPoints;
      m_slPoints = slPoints;
      m_tslTriggerPoints = tslTriggerPoints;
      m_tslPoints = tslPoints;
      m_barsN = barsN;
      m_expirationBars = expirationBars;
      m_orderDistPoints = orderDistPoints;
      m_tradeComment = tradeComment + "_" + symbol;
      
      // Initialiser les variables
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_lastBarTime = 0;
      m_buyTotal = 0;
      m_sellTotal = 0;
      m_totalProfit = 0;
      m_tradesCount = 0;
      
      // Initialiser les arrays de points
      ArrayInitialize(m_lastHighPoints, 0);
      ArrayInitialize(m_lastLowPoints, 0);
      ArrayInitialize(m_lastHighTimes, 0);
      ArrayInitialize(m_lastLowTimes, 0);
      
      // Configurer l'objet de trading
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(10);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
      
      Print("✓ CSymbolTrader initialized for ", symbol, " | Magic: ", magicNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CSymbolTrader()
   {
      // Supprimer les lignes du graphique
      DeleteSwingLines();
      Print("✓ CSymbolTrader destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Traitement principal du tick pour ce symbole                    |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // Vérifier si c'est une nouvelle barre
      if(!IsNewBar()) return;
      
      // Vérifier les heures de trading
      if(!IsTradingTimeAllowed())
      {
         CloseAllOrders();
         return;
      }
      
      // Mettre à jour les compteurs
      UpdateCounters();
      
      // Chercher des signaux de trading seulement si pas de positions/ordres existants
      if(m_buyTotal <= 0)
      {
         double high = FindHigh();
         if(high > 0)
         {
            SendBuyOrder(high);
         }
      }
      
      if(m_sellTotal <= 0)
      {
         double low = FindLow();
         if(low > 0)
         {
            SendSellOrder(low);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Trailing Stop pour ce symbole                                   |
   //+------------------------------------------------------------------+
   void TrailStop()
   {
      double sl = 0;
      double tp = 0;
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            ulong ticket = m_position.Ticket();
            
            double commission = m_commissionManager.GetCommission(m_position);
            double commissionPoints = CalculateCommissionInPoints(m_position.Symbol(), commission, m_position.Volume());
            
            if(m_position.Magic() == m_magicNumber && m_position.Symbol() == m_symbol)
            {
               if(m_position.PositionType() == POSITION_TYPE_BUY)
               {
                     // Profit actuel en points
                    double profitPoints = (bid - m_position.PriceOpen()) / m_point;
                    
                    // Activer le TSL seulement si profit > trigger + commission
                    if(profitPoints > ((m_tslTriggerPoints+commissionPoints) + commissionPoints)){
                    
                     tp = m_position.TakeProfit();
                     sl = bid - (m_tslPoints * m_point);
                     
                     if(sl > m_position.StopLoss() && sl != 0)
                     {
                        m_trade.PositionModify(ticket, sl, tp);
                     }
                  }
               }
               else if(m_position.PositionType() == POSITION_TYPE_SELL)
               {
                  // Profit actuel en points
                    double profitPoints = (m_position.PriceOpen() - ask) / m_point;
                    
                    // Activer le TSL seulement si profit > trigger + commission
                    if(profitPoints > (m_tslTriggerPoints + commissionPoints))
                  {
                     tp = m_position.TakeProfit();
                     sl = ask + ((m_tslPoints+commissionPoints) * m_point);
                     
                     if(sl < m_position.StopLoss() && sl != 0)
                     {
                        m_trade.PositionModify(ticket, sl, tp);
                     }
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
//| Calcule les points équivalents à une commission                  |
//+------------------------------------------------------------------+
double CalculateCommissionInPoints(string symbol, double commission, double lots)
{
    // Vérifications
    if(lots <= 0) return 0;
    if(commission == 0) return 0;
    
    // Informations du symbole
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(tickValue == 0 || tickSize == 0) 
    {
        Print("Erreur: impossible de récupérer les infos du symbole ", symbol);
        return 0;
    }
    
    // Valeur monétaire d'un point
    double pointValue = (tickValue / tickSize) * point;
    
    // Commission en points = Commission totale / (Valeur d'un point × Volume)
    double commissionPoints = MathAbs(commission) / (pointValue * lots);
    
    return 2*commissionPoints;
}
   
   //+------------------------------------------------------------------+
   //| Fermer toutes les positions et ordres pour ce symbole          |
   //+------------------------------------------------------------------+
   void CloseAllOrders()
   {
      // Fermer toutes les positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() == m_magicNumber && m_position.Symbol() == m_symbol)
            {
               m_trade.PositionClose(m_position.Ticket());
            }
         }
      }
      
      // Supprimer tous les ordres en attente
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber && OrderGetString(ORDER_SYMBOL) == m_symbol)
            {
               m_trade.OrderDelete(ticket);
            }
         }
      }
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
   //| Obtenir le symbole                                              |
   //+------------------------------------------------------------------+
   string GetSymbol() const { return m_symbol; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le magic number                                         |
   //+------------------------------------------------------------------+
   int GetMagicNumber() const { return m_magicNumber; }
   
   //+------------------------------------------------------------------+
   //| Rafraîchir l'affichage des lignes swing                          |
   //+------------------------------------------------------------------+
   void RefreshSwingDisplay()
   {
      DrawSwingPoints();
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si c'est une nouvelle barre                            |
   //+------------------------------------------------------------------+
   bool CSymbolTrader::IsNewBar()
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
   //| Trouver le plus haut dans la période de lookback               |
   //+------------------------------------------------------------------+
   double CSymbolTrader::FindHigh()
   {
      double highestHigh = 0;
      
      for(int i = 0; i < 200; i++)
      {
         double high = iHigh(m_symbol, m_timeframe, i);
         
         if(i > m_barsN && iHighest(m_symbol, m_timeframe, MODE_HIGH, m_barsN*2+1, i-m_barsN) == i)
         {
            if(high > highestHigh)
            {
               // Stocker le point détecté
               datetime barTime = iTime(m_symbol, m_timeframe, i);
               AddHighPoint(high, barTime);
               
               return high;
            }
         }
         
         highestHigh = MathMax(high, highestHigh);
      }
      
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Trouver le plus bas dans la période de lookback                |
   //+------------------------------------------------------------------+
   double CSymbolTrader::FindLow()
   {
      double lowestLow = DBL_MAX;
      
      for(int i = 0; i < 200; i++)
      {
         double low = iLow(m_symbol, m_timeframe, i);
         
         if(i > m_barsN && iLowest(m_symbol, m_timeframe, MODE_LOW, m_barsN*2+1, i-m_barsN) == i)
         {
            if(low < lowestLow)
            {
               // Stocker le point détecté
               datetime barTime = iTime(m_symbol, m_timeframe, i);
               AddLowPoint(low, barTime);
               
               return low;
            }
         }
         
         lowestLow = MathMin(low, lowestLow);
      }
      
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Calculer la taille du lot basée sur le risque                   |
   //+------------------------------------------------------------------+
   double CSymbolTrader::CalcLots(double slPoints)
   {
      double risk = AccountInfoDouble(ACCOUNT_EQUITY) * m_riskPercent / 100;
      
      double ticksize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickvalue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double lotstep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      double maxvolume = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double minvolume = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double volumelimit = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_LIMIT);
      
      double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
      double lots = MathFloor(risk / moneyPerLotstep) * lotstep;
      
      if(volumelimit != 0) lots = MathMin(lots, volumelimit);
      if(maxvolume != 0) lots = MathMin(lots, SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX));
      if(minvolume != 0) lots = MathMax(lots, SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN));
      lots = NormalizeDouble(lots, 2);
      
      return lots;
   }
   
   //+------------------------------------------------------------------+
   //| Envoyer un ordre Buy Stop                                       |
   //+------------------------------------------------------------------+
   void CSymbolTrader::SendBuyOrder(double entry)
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      if(ask > entry - m_orderDistPoints * m_point) return;
      
      double tp = entry + m_tpPoints * m_point;
      double sl = entry - m_slPoints * m_point;
      
      double lots = 0.01;
      if(m_riskPercent > 0) lots = CalcLots(entry - sl);
      
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      if(m_trade.BuyStop(lots, entry, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_tradeComment))
      {
         Print("✓ Buy Stop order sent for ", m_symbol, " at ", entry, " | Lots: ", lots);
      }
      else
      {
         Print("✗ Failed to send Buy Stop order for ", m_symbol, " | Error: ", GetLastError());
      }
   }
   
   //+------------------------------------------------------------------+
   //| Envoyer un ordre Sell Stop                                      |
   //+------------------------------------------------------------------+
   void CSymbolTrader::SendSellOrder(double entry)
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      if(bid < entry + m_orderDistPoints * m_point) return;
      
      double tp = entry - m_tpPoints * m_point;
      double sl = entry + m_slPoints * m_point;
      
      double lots = 0.01;
      if(m_riskPercent > 0) lots = CalcLots(sl - entry);
      
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      if(m_trade.SellStop(lots, entry, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_tradeComment))
      {
         Print("✓ Sell Stop order sent for ", m_symbol, " at ", entry, " | Lots: ", lots);
      }
      else
      {
         Print("✗ Failed to send Sell Stop order for ", m_symbol, " | Error: ", GetLastError());
      }
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les compteurs de positions/ordres                |
   //+------------------------------------------------------------------+
   void CSymbolTrader::UpdateCounters()
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
   //| Vérifier si le trading est autorisé selon les heures            |
   //+------------------------------------------------------------------+
   bool CSymbolTrader::IsTradingTimeAllowed()
   {
      // Utiliser la fonction globale TF_IsTradingAllowed() du TimeFilter
      return TF_IsTradingAllowed();
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer un point d'un array                                   |
   //+------------------------------------------------------------------+
   void CSymbolTrader::RemovePointFromArray(double price, double &pointsArray[], datetime &timesArray[], string prefix)
   {
      for(int i = 0; i < 3; i++)
      {
         if(MathAbs(pointsArray[i] - price) < m_point * 10)
         {
            // Supprimer la ligne graphique correspondante
            string objName = prefix + "_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
            ObjectDelete(0, objName);
            
            // Réinitialiser les valeurs
            pointsArray[i] = 0;
            timesArray[i] = 0;
            return;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Ajouter un high point à l'historique                             |
   //+------------------------------------------------------------------+
   void CSymbolTrader::AddHighPoint(double price, datetime time)
   {
      // Vérifier d'abord si ce point existe dans les low points et le supprimer
      RemovePointFromArray(price, m_lastLowPoints, m_lastLowTimes, "SwingLow");
      
      // Vérifier si ce point n'est pas déjà dans l'historique des highs
      for(int i = 0; i < 3; i++)
      {
         if(MathAbs(m_lastHighPoints[i] - price) < m_point * 10) // Tolérance de 10 points
            return;
      }
      
      // Décaler les anciens points
      for(int i = 2; i > 0; i--)
      {
         m_lastHighPoints[i] = m_lastHighPoints[i-1];
         m_lastHighTimes[i] = m_lastHighTimes[i-1];
      }
      
      // Ajouter le nouveau point
      m_lastHighPoints[0] = price;
      m_lastHighTimes[0] = time;
      
      // Redessiner les lignes
      DrawSwingPoints();
   }
   
   //+------------------------------------------------------------------+
   //| Ajouter un low point à l'historique                              |
   //+------------------------------------------------------------------+
   void CSymbolTrader::AddLowPoint(double price, datetime time)
   {
      // Vérifier d'abord si ce point existe dans les high points et le supprimer
      RemovePointFromArray(price, m_lastHighPoints, m_lastHighTimes, "SwingHigh");
      
      // Vérifier si ce point n'est pas déjà dans l'historique des lows
      for(int i = 0; i < 3; i++)
      {
         if(MathAbs(m_lastLowPoints[i] - price) < m_point * 10) // Tolérance de 10 points
            return;
      }
      
      // Décaler les anciens points
      for(int i = 2; i > 0; i--)
      {
         m_lastLowPoints[i] = m_lastLowPoints[i-1];
         m_lastLowTimes[i] = m_lastLowTimes[i-1];
      }
      
      // Ajouter le nouveau point
      m_lastLowPoints[0] = price;
      m_lastLowTimes[0] = time;
      
      // Redessiner les lignes
      DrawSwingPoints();
   }
   
   //+------------------------------------------------------------------+
   //| Dessiner les points swing sur le graphique                       |
   //+------------------------------------------------------------------+
   void CSymbolTrader::DrawSwingPoints()
   {
      // Supprimer les anciennes lignes
      DeleteSwingLines();
      
      // Dessiner les high points (lignes vertes)
      for(int i = 0; i < 3; i++)
      {
         if(m_lastHighPoints[i] > 0)
         {
            string name = "SwingHigh_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
            
            // Créer une ligne avec début et fin définis (50 barres de longueur)
            datetime start_time = m_lastHighTimes[i];
            datetime end_time = start_time + PeriodSeconds(m_timeframe) * 50;
            
            ObjectCreate(0, name, OBJ_TREND, 0, start_time, m_lastHighPoints[i], end_time, m_lastHighPoints[i]);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLimeGreen);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false); // Ne pas étendre à l'infini
            ObjectSetString(0, name, OBJPROP_TOOLTIP, m_symbol + " High: " + DoubleToString(m_lastHighPoints[i], _Digits));
         }
      }
      
      // Dessiner les low points (lignes rouges)
      for(int i = 0; i < 3; i++)
      {
         if(m_lastLowPoints[i] > 0)
         {
            string name = "SwingLow_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
            
            // Créer une ligne avec début et fin définis (50 barres de longueur)
            datetime start_time = m_lastLowTimes[i];
            datetime end_time = start_time + PeriodSeconds(m_timeframe) * 50;
            
            ObjectCreate(0, name, OBJ_TREND, 0, start_time, m_lastLowPoints[i], end_time, m_lastLowPoints[i]);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false); // Ne pas étendre à l'infini
            ObjectSetString(0, name, OBJPROP_TOOLTIP, m_symbol + " Low: " + DoubleToString(m_lastLowPoints[i], _Digits));
         }
      }
      
      // Rafraîchir le graphique
      ChartRedraw(0);
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer toutes les lignes swing                                |
   //+------------------------------------------------------------------+
   void CSymbolTrader::DeleteSwingLines()
   {
      // Supprimer les high lines
      for(int i = 0; i < 3; i++)
      {
         string nameHigh = "SwingHigh_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
         ObjectDelete(0, nameHigh);
         
         string nameLow = "SwingLow_" + m_symbol + "_" + IntegerToString(m_magicNumber) + "_" + IntegerToString(i);
         ObjectDelete(0, nameLow);
      }
      
      ChartRedraw(0);
   }
};
