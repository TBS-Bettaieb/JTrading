//+------------------------------------------------------------------+
//|                                        ForexSymbolTrader.mqh     |
//|                    Classe de trading par symbole individuel Forex|
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "../../../CommonUtils/TradingEnums.mqh"
#include "ForexCommissionManager.mqh"
#include "ForexSwingAnalyzer.mqh"
#include "ForexTrendlineManager.mqh"
#include "../../../CommonUtils/TrailingTP_System.mqh"

//+------------------------------------------------------------------+
//| Classe ForexSymbolTrader - Gestion d'un symbole spécifique       |
//+------------------------------------------------------------------+
class ForexSymbolTrader
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
   bool              m_disableTslInProfit;  // Désactiver TSL en profit NET
   int               m_barsN;               // Nombre de barres pour l'analyse
   int               m_expirationBars;      // Expiration des ordres
   int               m_orderDistPoints;     // Distance des ordres
   string            m_tradeComment;        // Commentaire des trades
   ENUM_STRATEGY_MODE m_strategyMode; // Mode de stratégie (Breakout/Reversion)
   
   // Objets de trading
   CTrade            m_trade;               // Objet de trading
   CPositionInfo     m_position;            // Gestion des positions
   COrderInfo        m_order;               // Gestion des ordres
   ForexCommissionManager m_commissionManager;  // Gestionnaire de commission
   ForexSwingAnalyzer m_swingAnalyzer;      // Analyseur de swing points
   ForexTrendlineManager* m_trendlineManager; // Gestionnaire des lignes TP/SL
   
   // Trailing TP
   CTrailingTP*      m_trailingTP;
   bool              m_useTrailingTP;
   string            m_customTPLevels;  // Custom TP levels string
   struct PositionTrailing {
      ulong ticket;
      CTrailingTP* trailing;
   };
   PositionTrailing  m_positionTrailings[];
   
   // Statistiques
   double            m_totalProfit;         // Profit total pour ce symbole
   
   // 🆕 Risk Multiplier
   double            m_currentRiskMultiplier; // Multiplicateur de risque actuel
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   ForexSymbolTrader(string symbol, 
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
                     string tradeComment,
                     ENUM_STRATEGY_MODE strategyMode,
                     bool useTrailingTP = false,
                     ENUM_TRAILING_TP_MODE trailingTPMode = TRAILING_TP_STEPPED,
                     string customTPLevels = "",
                     bool disableTslInProfit = false)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      m_riskPercent = riskPercent;
      m_tpPoints = tpPoints;
      m_slPoints = slPoints;
      m_tslTriggerPoints = tslTriggerPoints;
      m_tslPoints = tslPoints;
      m_disableTslInProfit = disableTslInProfit;
      m_barsN = barsN;
      m_expirationBars = expirationBars;
      m_orderDistPoints = orderDistPoints;
      m_tradeComment = tradeComment + "_" + symbol;
      m_strategyMode = strategyMode;
      
      // Initialiser les variables
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_lastBarTime = 0;
      m_buyTotal = 0;
      m_sellTotal = 0;
      m_totalProfit = 0;
      m_currentRiskMultiplier = 1.0;
      // Configurer l'objet de trading
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(10);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
      
      // Initialiser l'analyseur de swing
      m_swingAnalyzer = ForexSwingAnalyzer(symbol, timeframe, magicNumber, barsN);
      
      m_customTPLevels = customTPLevels;
      
      // Initialiser le Trailing TP
      m_useTrailingTP = useTrailingTP;
      if(m_useTrailingTP) {
         m_trailingTP = new CTrailingTP(trailingTPMode, customTPLevels);
         
         if(!m_trailingTP.ValidateConfiguration()) {
            Print("⚠️ Config Trailing TP invalide pour ", symbol);
            delete m_trailingTP;
            m_trailingTP = NULL;
            m_useTrailingTP = false;
         }
      } else {
         m_trailingTP = NULL;
      }
      ArrayResize(m_positionTrailings, 0);
      
      // Initialiser le gestionnaire des lignes TP/SL
      m_trendlineManager = new ForexTrendlineManager(symbol, magicNumber);
      
      Print("✓ ForexSymbolTrader initialized for ", symbol, " | Magic: ", magicNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~ForexSymbolTrader()
   {
      // Cleanup Trailing TP
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].trailing != NULL) {
            delete m_positionTrailings[i].trailing;
         }
      }
      if(m_trailingTP != NULL) delete m_trailingTP;
      
      // Cleanup Trendline Manager
      if(m_trendlineManager != NULL) 
      {
         delete m_trendlineManager;
         m_trendlineManager = NULL;
      }
      
      Print("✓ ForexSymbolTrader destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Traitement principal du tick pour ce symbole                    |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // Vérifier si c'est une nouvelle barre
      if(!IsNewBar()) return;
      
      // Note: Trading time control is now handled at the global level in the bot's OnTick()
      
      // Mettre à jour les compteurs
      UpdateCounters();
      
      // Vérifier les nouvelles positions pour créer les lignes TP/SL
      CheckForNewPositions();
      
      // Chercher des signaux de trading seulement si pas de positions/ordres existants
      if(m_buyTotal <= 0)
      {
         if(m_strategyMode == STRATEGY_BREAKOUT)
         {
            // Mode BREAKOUT : acheter quand le prix CASSE un swing high (suivre la tendance)
            double high = m_swingAnalyzer.FindHigh();
            if(high > 0)
            {
               SendBuyOrder(high);
            }
         }
         else if(m_strategyMode == STRATEGY_REVERSION)
         {
            // Mode REVERSION : acheter quand le prix TOUCHE un swing low et rebondit (contre-tendance)
            double low = m_swingAnalyzer.FindLow();
            if(low > 0)
            {
               SendBuyOrder(low);
            }
         }
      }
      
      if(m_sellTotal <= 0)
      {
         if(m_strategyMode == STRATEGY_BREAKOUT)
         {
            // Mode BREAKOUT : vendre quand le prix CASSE un swing low (suivre la tendance)
            double low = m_swingAnalyzer.FindLow();
            if(low > 0)
            {
               SendSellOrder(low);
            }
         }
         else if(m_strategyMode == STRATEGY_REVERSION)
         {
            // Mode REVERSION : vendre quand le prix TOUCHE un swing high et redescend (contre-tendance)
            double high = m_swingAnalyzer.FindHigh();
            if(high > 0)
            {
               SendSellOrder(high);
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Trailing Stop pour ce symbole                                   |
   //+------------------------------------------------------------------+
   //+------------------------------------------------------------------+
   //| Trailing Stop Loss avec option de désactivation en profit NET   |
   //+------------------------------------------------------------------+
   void TrailStop()
   {
      // Parcourir toutes les positions de ce symbole
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;
         
         // Vérifier que c'est notre position
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
         
         // 🆕 VÉRIFICATION PROFIT NET AVEC COMMISSIONS ET SWAP
         if(m_disableTslInProfit)
         {
            // Calculer le profit NET (CRITIQUE: inclure commissions + swap)
            double profitGross = PositionGetDouble(POSITION_PROFIT);
            double commission = m_commissionManager.GetCommission(m_position);
            double commissionPoints = m_commissionManager.CalculateCommissionInPoints(m_position.Symbol(), commission, m_position.Volume());
           
           
            
            // Profit NET = Profit brut + Commissions (négatives) + Swap
            double profitNet = profitGross + commission ;
            
            // Si position en profit NET, on désactive le trailing stop
            if(profitNet > 0)
            {
               // Log optionnel pour debug (seulement la première fois)
               static datetime lastLogTime = 0;
               if(TimeCurrent() - lastLogTime > 300)  // Log toutes les 5 minutes max
               {
                  Print("🔒 TSL désactivé #", ticket, " [", m_symbol, "] - Profit NET: $", 
                        DoubleToString(profitNet, 2), 
                        " (Brut: $", DoubleToString(profitGross, 2),
                        " | Com: $", DoubleToString(commission, 2),
                         ")");
                  lastLogTime = TimeCurrent();
               }
               
               continue;  // Skip le trailing stop pour cette position
            }
            
            // Si profitNet <= 0, on continue normalement avec le trailing stop
         }
         
         // ═══ LOGIQUE DE TRAILING STOP NORMALE ═══
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         double profitPoints = 0;
         
         if(posType == POSITION_TYPE_BUY)
         {
            profitPoints = (currentPrice - openPrice) / point;
            
            // Vérifier si trigger atteint
            if(profitPoints >= m_tslTriggerPoints)
            {
               double newSL = currentPrice - (m_tslPoints * point);
               
               // Ne bouger que si amélioration du SL
               if(newSL > currentSL)
               {
                  if(m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
                  {
                     Print("📈 TSL appliqué #", ticket, " [", m_symbol, "] BUY: SL ", 
                           DoubleToString(currentSL, 5), " → ", DoubleToString(newSL, 5));
                     
                     // Mettre à jour les lignes TP/SL
                     if(m_trendlineManager != NULL)
                     {
                        m_trendlineManager.UpdatePositionLines(ticket, 
                                                            PositionGetDouble(POSITION_TP), 
                                                            newSL);
                     }
                  }
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            profitPoints = (openPrice - currentPrice) / point;
            
            if(profitPoints >= m_tslTriggerPoints)
            {
               double newSL = currentPrice + (m_tslPoints * point);
               
               // Ne bouger que si amélioration (ou SL non défini)
               if(newSL < currentSL || currentSL == 0)
               {
                  if(m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
                  {
                     Print("📉 TSL appliqué #", ticket, " [", m_symbol, "] SELL: SL ", 
                           DoubleToString(currentSL, 5), " → ", DoubleToString(newSL, 5));
                     
                     // Mettre à jour les lignes TP/SL
                     if(m_trendlineManager != NULL)
                     {
                        m_trendlineManager.UpdatePositionLines(ticket, 
                                                            PositionGetDouble(POSITION_TP), 
                                                            newSL);
                     }
                  }
               }
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Fermer toutes les positions et ordres pour ce symbole          |
   //+------------------------------------------------------------------+
   void CloseAllOrders()
   {
      // Supprimer toutes les lignes TP/SL avant de fermer les positions
      if(m_trendlineManager != NULL)
      {
         m_trendlineManager.DeleteAllLines();
      }
      
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
   //| Annuler tous les ordres pending sans fermer les positions       |
   //+------------------------------------------------------------------+
   void CancelAllPendingOrders()
   {
      int cancelledCount = 0;
      
      // Supprimer uniquement les ordres en attente (ne pas toucher aux positions ouvertes)
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber && OrderGetString(ORDER_SYMBOL) == m_symbol)
            {
               if(m_trade.OrderDelete(ticket))
               {
                  cancelledCount++;
               }
            }
         }
      }
      
      // Log seulement si des ordres ont été annulés
      if(cancelledCount > 0)
      {
         Print("🚫 ", m_symbol, ": ", cancelledCount, " pending order(s) cancelled (trading paused)");
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
   //| Rafraîchir l'affichage des lignes swing                          |
   //+------------------------------------------------------------------+
   void RefreshSwingDisplay()
   {
      m_swingAnalyzer.RefreshSwingDisplay();
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Définir le multiplicateur actuel                              |
   //+------------------------------------------------------------------+
   void SetRiskMultiplier(double multiplier)
   {
      m_currentRiskMultiplier = MathMax(0.1, MathMin(10.0, multiplier));
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Obtenir le multiplicateur actuel                              |
   //+------------------------------------------------------------------+
   double GetRiskMultiplier()
   {
      return m_currentRiskMultiplier;
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Ajuster toutes les positions existantes                       |
   //+------------------------------------------------------------------+
   int AdjustPositionSizes(double newMultiplier)
   {
      int adjustedCount = 0;
      CTrade trade;
      trade.SetExpertMagicNumber(m_magicNumber);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Magic() != m_magicNumber) continue;
         if(m_position.Symbol() != m_symbol) continue;
         
         ulong ticket = m_position.Ticket();
         double currentVolume = m_position.Volume();
         double currentTP = m_position.TakeProfit();
         double currentSL = m_position.StopLoss();
         ENUM_POSITION_TYPE posType = m_position.PositionType();
         
         // Calculer nouveau volume
         double baseVolume = currentVolume / m_currentRiskMultiplier;
         double newVolume = baseVolume * newMultiplier;
         
         // Normaliser
         double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
         double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
         double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         newVolume = MathMax(minLot, MathMin(maxLot, newVolume));
         newVolume = MathFloor(newVolume / lotStep) * lotStep;
         newVolume = NormalizeDouble(newVolume, 2);
         
         if(MathAbs(newVolume - currentVolume) < lotStep) continue;
         
         // Ajuster
         if(newVolume > currentVolume)
         {
            // Augmenter
            double additionalVolume = newVolume - currentVolume;
            if(posType == POSITION_TYPE_BUY)
            {
               if(trade.Buy(additionalVolume, m_symbol, 0, currentSL, currentTP, m_tradeComment + "_Boost"))
               {
                  Print("📈 Position #", ticket, " [", m_symbol, "] augmentée: ", 
                        DoubleToString(currentVolume, 2), " → ", DoubleToString(newVolume, 2), " lots");
                  adjustedCount++;
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               if(trade.Sell(additionalVolume, m_symbol, 0, currentSL, currentTP, m_tradeComment + "_Boost"))
               {
                  Print("📉 Position #", ticket, " [", m_symbol, "] augmentée: ", 
                        DoubleToString(currentVolume, 2), " → ", DoubleToString(newVolume, 2), " lots");
                  adjustedCount++;
               }
            }
         }
         else if(newVolume < currentVolume)
         {
            // Réduire
            double volumeToClose = currentVolume - newVolume;
            if(trade.PositionClosePartial(ticket, volumeToClose))
            {
               Print("📉 Position #", ticket, " [", m_symbol, "] réduite: ", 
                     DoubleToString(currentVolume, 2), " → ", DoubleToString(newVolume, 2), " lots");
               adjustedCount++;
            }
         }
      }
      
      return adjustedCount;
   }
   
   //+------------------------------------------------------------------+
   //| Appelé quand une position est ouverte                           |
   //+------------------------------------------------------------------+
   void OnPositionOpened(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return;
      
      // Créer les lignes TP/SL pour cette position
      if(m_trendlineManager != NULL)
      {
         double tpPrice = PositionGetDouble(POSITION_TP);
         double slPrice = PositionGetDouble(POSITION_SL);
         m_trendlineManager.CreatePositionLines(ticket, tpPrice, slPrice);
      }
      
      // Gestion du trailing TP (logique existante)
      if(!m_useTrailingTP || m_trailingTP == NULL) return;
      
      // Vérifier que ce n'est pas déjà tracké
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].ticket == ticket) return;
      }
      
      // MODIFIER: Passer customLevels
      CTrailingTP* newTrailing = new CTrailingTP(
         m_trailingTP.GetMode(),
         m_trailingTP.GetCustomLevelsString()  // <-- AJOUTER
      );
      
      newTrailing.Initialize(
         PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_SL),
         PositionGetDouble(POSITION_TP),
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY
      );
      
      int size = ArraySize(m_positionTrailings);
      ArrayResize(m_positionTrailings, size + 1);
      m_positionTrailings[size].ticket = ticket;
      m_positionTrailings[size].trailing = newTrailing;
      
      Print("🎯 Trailing TP #", ticket, " | Mode: ", EnumToString(m_trailingTP.GetMode()),
            " | Niveaux: ", newTrailing.GetLevelCount());
   }
   
   //+------------------------------------------------------------------+
   //| Appelé quand une position est fermée                            |
   //+------------------------------------------------------------------+
   void OnPositionClosed(ulong ticket)
   {
      // Supprimer les lignes TP/SL pour cette position
      if(m_trendlineManager != NULL)
      {
         m_trendlineManager.DeletePositionLines(ticket);
      }
      
      // Gestion du trailing TP (logique existante)
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].ticket == ticket) {
            if(m_positionTrailings[i].trailing != NULL) {
               delete m_positionTrailings[i].trailing;
            }
            for(int j = i; j < ArraySize(m_positionTrailings) - 1; j++) {
               m_positionTrailings[j] = m_positionTrailings[j + 1];
            }
            ArrayResize(m_positionTrailings, ArraySize(m_positionTrailings) - 1);
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Détecter les nouvelles positions                                 |
   //+------------------------------------------------------------------+
   void CheckForNewPositions()
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Magic() != m_magicNumber) continue;
         if(m_position.Symbol() != m_symbol) continue;
         
         ulong ticket = m_position.Ticket();
         
         bool alreadyTracked = false;
         for(int j = 0; j < ArraySize(m_positionTrailings); j++)
         {
            if(m_positionTrailings[j].ticket == ticket)
            {
               alreadyTracked = true;
               break;
            }
         }
         
         if(!alreadyTracked) OnPositionOpened(ticket);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Appliquer le Trailing TP à toutes les positions                 |
   //+------------------------------------------------------------------+
   void ApplyTrailingTP()
   {
      if(!m_useTrailingTP) return;
      
      CheckForNewPositions();
      
      for(int i = ArraySize(m_positionTrailings) - 1; i >= 0; i--) {
         ulong ticket = m_positionTrailings[i].ticket;
         
         if(!PositionSelectByTicket(ticket)) {
            OnPositionClosed(ticket);
            continue;
         }
         
         double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
            ? SymbolInfoDouble(m_symbol, SYMBOL_BID)
            : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         
         double newSL, newTP;
         if(m_positionTrailings[i].trailing.Update(currentPrice, newSL, newTP)) {
            if(newSL > 0 && newTP > 0) {
               if(m_trade.PositionModify(ticket, newSL, newTP))
               {
                  // Mettre à jour les lignes TP/SL après modification du Trailing TP
                  if(m_trendlineManager != NULL)
                  {
                     m_trendlineManager.UpdatePositionLines(ticket, newTP, newSL);
                  }
               }
            }
         }
      }
   }
   
private:
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
   //| Calculer la taille du lot basée sur le risque                   |
   //+------------------------------------------------------------------+
   double CalcLots(double slPoints)
   {
      double effectiveRisk = m_riskPercent * m_currentRiskMultiplier; // 🆕
      double risk = AccountInfoDouble(ACCOUNT_BALANCE) * effectiveRisk / 100;
      
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
   //| Envoyer un ordre Buy (Stop ou Limit selon la stratégie)         |
   //+------------------------------------------------------------------+
   void SendBuyOrder(double entry)
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      double tp = entry + m_tpPoints * m_point;
      double sl = entry - m_slPoints * m_point;
      
      double lots = 0.01;
      if(m_riskPercent > 0) lots = CalcLots(entry - sl);
      
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      if(m_strategyMode == STRATEGY_BREAKOUT)
      {
         // Mode BREAKOUT : utiliser BuyStop (attendre que le prix casse le niveau)
         if(ask > entry - m_orderDistPoints * m_point) return;
         
         if(m_trade.BuyStop(lots, entry, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_tradeComment))
         {
            Print("✓ Buy Stop order sent for ", m_symbol, " at ", entry, " | Lots: ", lots);
         }
         else
         {
            Print("✗ Failed to send Buy Stop order for ", m_symbol, " | Error: ", GetLastError());
         }
      }
      else if(m_strategyMode == STRATEGY_REVERSION)
      {
         // Mode REVERSION : utiliser BuyLimit (attendre que le prix touche le niveau)
         if(ask < entry + m_orderDistPoints * m_point) return;
         
         if(m_trade.BuyLimit(lots, entry, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_tradeComment))
         {
            Print("✓ Buy Limit order sent for ", m_symbol, " at ", entry, " | Lots: ", lots);
         }
         else
         {
            Print("✗ Failed to send Buy Limit order for ", m_symbol, " | Error: ", GetLastError());
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Envoyer un ordre Sell (Stop ou Limit selon la stratégie)         |
   //+------------------------------------------------------------------+
   void SendSellOrder(double entry)
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      double tp = entry - m_tpPoints * m_point;
      double sl = entry + m_slPoints * m_point;
      
      double lots = 0.01;
      if(m_riskPercent > 0) lots = CalcLots(sl - entry);
      
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      if(m_strategyMode == STRATEGY_BREAKOUT)
      {
         // Mode BREAKOUT : utiliser SellStop (attendre que le prix casse le niveau)
         if(bid < entry + m_orderDistPoints * m_point) return;
         
         if(m_trade.SellStop(lots, entry, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_tradeComment))
         {
            Print("✓ Sell Stop order sent for ", m_symbol, " at ", entry, " | Lots: ", lots);
         }
         else
         {
            Print("✗ Failed to send Sell Stop order for ", m_symbol, " | Error: ", GetLastError());
         }
      }
      else if(m_strategyMode == STRATEGY_REVERSION)
      {
         // Mode REVERSION : utiliser SellLimit (attendre que le prix touche le niveau)
         if(bid > entry - m_orderDistPoints * m_point) return;
         
         if(m_trade.SellLimit(lots, entry, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_tradeComment))
         {
            Print("✓ Sell Limit order sent for ", m_symbol, " at ", entry, " | Lots: ", lots);
         }
         else
         {
            Print("✗ Failed to send Sell Limit order for ", m_symbol, " | Error: ", GetLastError());
         }
      }
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
   
};
