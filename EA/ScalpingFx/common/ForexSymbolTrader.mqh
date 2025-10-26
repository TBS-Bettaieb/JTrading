//+------------------------------------------------------------------+
//|                                        ForexSymbolTrader.mqh     |
//|                    Classe de trading par symbole individuel Forex|
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "../../../EA/Shared/TradingEnums.mqh"
#include "../../../EA/Shared/ForexCommissionManager.mqh"
#include "ForexSwingAnalyzer.mqh"
#include "ForexTrendlineManager.mqh"
#include "../../../EA/Shared/TrailingTP_System.mqh"
#include "../../../EA/Shared/DynamicTrailingStop.mqh"
#include "ForexOrderManager.mqh"
#include "ForexSymbolStatus.mqh"

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
   
   
   // Paramètres de trading
   double            m_riskPercent;         // Risque par symbole
   int               m_tpPoints;            // Take Profit en points
   int               m_slPoints;            // Stop Loss en points
   int               m_tslTriggerPoints;    // Points en profit avant TSL
   int               m_tslPoints;           // Trailing Stop Loss
   int               m_barsN;               // Nombre de barres pour l'analyse
   int               m_expirationBars;      // Expiration des ordres
   int               m_orderDistPoints;     // Distance des ordres
   int               m_slippagePoints;      // NEW: Slippage tolerance
   int               m_entryOffsetPoints;   // NEW: Entry offset for Stop orders
   string            m_tradeComment;        // Commentaire des trades
   ENUM_STRATEGY_MODE m_strategyMode; // Mode de stratégie (Breakout/Reversion)
   
   // Objets de trading (nécessaires pour certaines opérations)
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
   
   
   // 🆕 Risk Multiplier
   double            m_currentRiskMultiplier; // Multiplicateur de risque actuel
   
   // 🆕 Dynamic Trailing Stop Loss
   CDynamicTrailingStop* m_dynamicTSL;
   
   // 🆕 Order Manager
   ForexOrderManager* m_orderManager;
   
   // 🆕 Status Manager
   ForexSymbolStatus* m_statusManager;
   
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
                     int slippagePoints,
                     int entryOffsetPoints,
                     string tradeComment,
                     ENUM_STRATEGY_MODE strategyMode,
                     bool useTrailingTP = false,
                     ENUM_TRAILING_TP_MODE trailingTPMode = TRAILING_TP_STEPPED,
                     string customTPLevels = "",
                     bool useDynamicTSLTrigger = true,      // 🆕 AJOUTER
                     double tslCostMultiplier = 1.5,        // 🆕 AJOUTER
                     int tslMinTriggerPoints = 50)          // 🆕 AJOUTER
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
      m_slippagePoints = slippagePoints;
      m_entryOffsetPoints = entryOffsetPoints;
      m_tradeComment = "BreakoutScalper_" + TimeframeToString(m_timeframe);
      m_strategyMode = strategyMode;
      
      // Initialiser les variables
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_currentRiskMultiplier = 1.0;
      
      // 🆕 Initialiser le Dynamic Trailing Stop
      m_dynamicTSL = new CDynamicTrailingStop(
         tslPoints,
         tslTriggerPoints,
         useDynamicTSLTrigger,
         tslCostMultiplier,
         tslMinTriggerPoints,
         m_slippagePoints
      );
      m_dynamicTSL.SetCommissionManager(&m_commissionManager);
      
      // Configurer l'objet de trading
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(m_slippagePoints);
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
      
      // Initialiser le gestionnaire des ordres
      m_orderManager = new ForexOrderManager(
         symbol, magicNumber, timeframe, strategyMode,
         tpPoints, slPoints, expirationBars, orderDistPoints,
         entryOffsetPoints, slippagePoints, m_tradeComment,
         riskPercent, m_currentRiskMultiplier
      );
      
      // Initialiser le gestionnaire du statut
      m_statusManager = new ForexSymbolStatus(symbol, magicNumber, timeframe);
      
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
      
      // Cleanup Dynamic TSL
      if(m_dynamicTSL != NULL) 
      {
         delete m_dynamicTSL;
         m_dynamicTSL = NULL;
      }
      
      // Cleanup Order Manager
      if(m_orderManager != NULL) 
      {
         delete m_orderManager;
         m_orderManager = NULL;
      }
      
      // Cleanup Status Manager
      if(m_statusManager != NULL) 
      {
         delete m_statusManager;
         m_statusManager = NULL;
      }
      
      Print("✓ ForexSymbolTrader destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Traitement principal du tick pour ce symbole                    |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // Vérifier si c'est une nouvelle barre
      if(!m_statusManager.IsNewBar()) return;
      
      // Note: Trading time control is now handled at the global level in the bot's OnTick()
      
      // Mettre à jour les compteurs
      m_statusManager.UpdateCounters();
      
      // Vérifier les nouvelles positions pour créer les lignes TP/SL
      CheckForNewPositions();
      
      // Chercher des signaux de trading seulement si pas de positions/ordres existants
      if(m_statusManager.GetBuyTotal() <= 0)
      {
         if(m_strategyMode == STRATEGY_BREAKOUT)
         {
            // Mode BREAKOUT : acheter quand le prix CASSE un swing high (suivre la tendance)
            double high = m_swingAnalyzer.FindHigh();
            if(high > 0)
            {
               m_orderManager.SendBuyOrder(high);
            }
         }
         else if(m_strategyMode == STRATEGY_REVERSION)
         {
            // Mode REVERSION : acheter quand le prix TOUCHE un swing low et rebondit (contre-tendance)
            double low = m_swingAnalyzer.FindLow();
            if(low > 0)
            {
               m_orderManager.SendBuyOrder(low);
            }
         }
      }
      
      if(m_statusManager.GetSellTotal() <= 0)
      {
         if(m_strategyMode == STRATEGY_BREAKOUT)
         {
            // Mode BREAKOUT : vendre quand le prix CASSE un swing low (suivre la tendance)
            double low = m_swingAnalyzer.FindLow();
            if(low > 0)
            {
               m_orderManager.SendSellOrder(low);
            }
         }
         else if(m_strategyMode == STRATEGY_REVERSION)
         {
            // Mode REVERSION : vendre quand le prix TOUCHE un swing high et redescend (contre-tendance)
            double high = m_swingAnalyzer.FindHigh();
            if(high > 0)
            {
               m_orderManager.SendSellOrder(high);
            }
         }
      }
   }
   //+------------------------------------------------------------------+
   //| 🆕 Trailing Stop Loss DYNAMIQUE basé sur les coûts réels        |
   //+------------------------------------------------------------------+
   void TrailStop()
   {
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.ApplyTrailing(m_symbol, m_magicNumber);
         
         // Mettre à jour les lignes TP/SL après modification du TSL
         if(m_trendlineManager != NULL)
         {
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               ulong ticket = PositionGetTicket(i);
               if(ticket <= 0) continue;
               
               if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
               if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
               
               m_trendlineManager.UpdatePositionLines(ticket, 
                                                   PositionGetDouble(POSITION_TP), 
                                                   PositionGetDouble(POSITION_SL));
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
   //| Annuler tous les ordres pending sans fermer les positions      |
   //+------------------------------------------------------------------+
   void CancelAllPendingOrders()
   {
      if(m_orderManager != NULL)
      {
         m_orderManager.CancelAllPendingOrders();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut pour l'affichage             |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      if(m_statusManager != NULL)
      {
         return m_statusManager.GetStatusInfo();
      }
      return m_symbol + ": ERROR";
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le profit total pour ce symbole                         |
   //+------------------------------------------------------------------+
   double GetTotalProfit()
   {
      if(m_statusManager != NULL)
      {
         return m_statusManager.GetTotalProfit();
      }
      return 0.0;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total de positions                            |
   //+------------------------------------------------------------------+
   int GetTotalPositions()
   {
      if(m_statusManager != NULL)
      {
         return m_statusManager.GetTotalPositions();
      }
      return 0;
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
   //| 🆕 Méthodes pour accéder au Dynamic TSL                          |
   //+------------------------------------------------------------------+
   void SetDynamicTSLTrigger(bool enable)
   {
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.SetDynamicTrigger(enable);
      }
   }
   
   void SetDynamicTSLCostMultiplier(double multiplier)
   {
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.SetCostMultiplier(multiplier);
      }
   }
   
   void SetDynamicTSLMinTriggerPoints(int points)
   {
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.SetMinTriggerPoints(points);
      }
   }
   
   string GetDynamicTSLDebugInfo()
   {
      if(m_dynamicTSL != NULL)
      {
         return m_dynamicTSL.GetDebugInfo();
      }
      return "Dynamic TSL not initialized";
   }
   
   
   //+------------------------------------------------------------------+
   //| 🆕 Ajuster le multiplicateur + ordres pending                    |
   //+------------------------------------------------------------------+
   int AdjustPositionSizes(double newMultiplier)
   {
      if(m_orderManager != NULL)
      {
         return m_orderManager.AdjustPositionSizes(newMultiplier);
      }
      return 0;
   }
   
   //+------------------------------------------------------------------+
   //| Appelé quand une position est ouverte                           |
   //+------------------------------------------------------------------+
   void OnPositionOpened(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return;
      
      // 🆕 Calculer les coûts de position pour le TSL dynamique
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.CalculatePositionCosts(ticket, m_symbol);
      }
      
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
      // 🆕 Nettoyer les coûts de position pour le TSL dynamique
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.RemovePositionCosts(ticket);
      }
      
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
   //| Convertir un timeframe en string                                |
   //+------------------------------------------------------------------+
   string TimeframeToString(ENUM_TIMEFRAMES tf)
   {
      switch(tf)
      {
         case PERIOD_M1:  return "M1";
         case PERIOD_M5:  return "M5";
         case PERIOD_M15: return "M15";
         case PERIOD_M30: return "M30";
         case PERIOD_H1:  return "H1";
         case PERIOD_H4:  return "H4";
         case PERIOD_D1:  return "D1";
         case PERIOD_W1:  return "W1";
         case PERIOD_MN1: return "MN1";
         default:         return "UNKNOWN";
      }
   }
   
};
