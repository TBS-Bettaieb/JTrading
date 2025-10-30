//+------------------------------------------------------------------+
//|                                        BreakoutScalperTrader.mqh     |
//|                    Classe de trading par symbole individuel BreakoutScalper|
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "../../../EA/Shared/TradingEnums.mqh"
#include "../../../EA/Shared/Logger.mqh"
#include "../../../EA/Shared/ForexCommissionManager.mqh"
#include "../common/analysis/SwingAnalyzer.mqh"
#include "../common/trading/TrendlineManager.mqh"
#include "../common/trading/OrderManager.mqh"
#include "../common/status/SymbolStatus.mqh"
#include "../common/trading/TrailingManager.mqh"
#include "../common/status/SymbolDisplay.mqh"
#include "../common/analysis/SignalDetectionManager.mqh"
#include "../common/trading/FVGTradeFilter.mqh"

//+------------------------------------------------------------------+
//| Classe BreakoutScalperTrader - Gestion d'un symbole spécifique       |
//+------------------------------------------------------------------+
class BreakoutScalperTrader
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
   
   // Filters
   bool              m_useFvgFilter;        // Utiliser le filtre FVG
   
   // Objets de trading (nécessaires pour certaines opérations)
   CTrade            m_trade;               // Objet de trading
   CPositionInfo     m_position;            // Gestion des positions
   COrderInfo        m_order;               // Gestion des ordres
   
   ForexCommissionManager m_commissionManager;  // Gestionnaire de commission
   SwingAnalyzer m_swingAnalyzer;      // Analyseur de swing points
   TrendlineManager* m_trendlineManager; // Gestionnaire des lignes TP/SL
   
   // 🆕 Trailing Manager (TP + TSL unifiés)
   TrailingManager* m_trailingManager;
   
   // 🆕 Risk Multiplier
   double            m_currentRiskMultiplier; // Multiplicateur de risque actuel
   
   // 🆕 Order Manager
   OrderManager* m_orderManager;
   
   // 🆕 Status Manager
   SymbolStatus* m_statusManager;
   
   // 🆕 Display Manager
   SymbolDisplay* m_displayManager;
   
   // 🆕 Signal Detection Manager
   SignalDetectionManager* m_signalManager;
   
   // 🆕 FVG Filter (initialized in constructor)
   FVGTradeFilter m_fvgFilter;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   BreakoutScalperTrader(string symbol, 
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
                     bool useTrailingTP = false,
                     ENUM_TRAILING_TP_MODE trailingTPMode = TRAILING_TP_STEPPED,
                     string customTPLevels = "",
                     bool useDynamicTSLTrigger = true,      // 🆕 AJOUTER
                     double tslCostMultiplier = 1.5,        // 🆕 AJOUTER
                     int tslMinTriggerPoints = 50,          // 🆕 AJOUTER
                     bool useFvgFilter = false)             // 🆕 FVG FILTER
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
      m_useFvgFilter = useFvgFilter;
      
      // Initialiser les variables
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_currentRiskMultiplier = 1.0;
      
      // Configurer l'objet de trading
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(m_slippagePoints);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
      
      // Initialiser l'analyseur de swing
      m_swingAnalyzer = SwingAnalyzer(symbol, timeframe, magicNumber, barsN);
      
      // Initialiser le gestionnaire des lignes TP/SL
      m_trendlineManager = new TrendlineManager(symbol, magicNumber);
      
      // Initialiser le gestionnaire des ordres
      m_orderManager = new OrderManager(
         symbol, magicNumber, timeframe,
         tpPoints, slPoints, expirationBars, orderDistPoints,
         entryOffsetPoints, slippagePoints, m_tradeComment,
         riskPercent, m_currentRiskMultiplier
      );
      
      // 🆕 Initialiser le Trailing Manager (TP + TSL)
      m_trailingManager = new TrailingManager(
         symbol,
         magicNumber,
         useTrailingTP,
         trailingTPMode,
         customTPLevels,
         tslPoints,
         tslTriggerPoints,
         useDynamicTSLTrigger,
         tslCostMultiplier,
         tslMinTriggerPoints,
         slippagePoints,
         &m_commissionManager,
         m_trendlineManager
      );
      
      // Initialiser le gestionnaire du statut
      m_statusManager = new SymbolStatus(symbol, magicNumber, timeframe);
      
      // 🆕 Initialiser le Display Manager
      m_displayManager = new SymbolDisplay(
         symbol,
         magicNumber,
         m_statusManager,
         GetPointer(m_swingAnalyzer),
         riskPercent,
         tpPoints,
         slPoints,
         timeframe
      );
      
      // 🆕 Initialiser le Signal Detection Manager
      m_signalManager = new SignalDetectionManager(
         symbol,
         timeframe,
         &m_swingAnalyzer,
         m_statusManager
      );
      
      // Initialiser le filtre FVG au niveau du trader
      m_fvgFilter.Init(m_symbol, m_timeframe, m_useFvgFilter);
      
      Print("✓ BreakoutScalperTrader initialized for ", symbol, " | Magic: ", magicNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~BreakoutScalperTrader()
   {
      // Cleanup Trailing Manager
      if(m_trailingManager != NULL) 
      {
         delete m_trailingManager;
         m_trailingManager = NULL;
      }
      
      // Cleanup Trendline Manager
      if(m_trendlineManager != NULL) 
      {
         delete m_trendlineManager;
         m_trendlineManager = NULL;
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
      
      // Cleanup Display Manager
      if(m_displayManager != NULL) 
      {
         delete m_displayManager;
         m_displayManager = NULL;
      }
      
      // Cleanup Signal Detection Manager
      if(m_signalManager != NULL) 
      {
         delete m_signalManager;
         m_signalManager = NULL;
      }
      
      Print("✓ BreakoutScalperTrader destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Traitement principal du tick pour ce symbole                    |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // Mettre à jour les compteurs
      m_statusManager.UpdateCounters();
      CheckFvgDisqualifier();
      // Vérifier si c'est une nouvelle barre
      if(!m_statusManager.IsNewBar()) return;
      
      // Note: Trading time control is now handled at the global level in the bot's OnTick()
      
      
      
      // Vérifier les nouvelles positions pour créer les lignes TP/SL
      CheckForNewPositions();
      
      // 🆕 Détection des signaux avec le nouveau manager
      SignalInfo signal;
      
      if(m_signalManager.CheckForBuySignal(signal))
      {
         m_orderManager.SendBuyOrder(signal.triggerPrice);
         Print("📈 ", m_signalManager.GetSignalDescription(signal));
      }
      
      if(m_signalManager.CheckForSellSignal(signal))
      {
         m_orderManager.SendSellOrder(signal.triggerPrice);
         Print("📉 ", m_signalManager.GetSignalDescription(signal));
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
   //| Vérifier et annuler les ordres disqualifiés par le filtre FVG    |
   //+------------------------------------------------------------------+
   bool CheckFvgDisqualifier()
   {
      if(!m_fvgFilter.GetEnabled())
         return false;


      // Utiliser OrderManager::FindTicketViolatingPriceTolerance pour trouver un ordre dépassant le priceTolerance
      ulong violatingTicket = 0;
      bool isBuy = false;
      double priceTolerance = SymbolInfoDouble(m_symbol, SYMBOL_BID) * 0.0001; // 0.01% tolerance
      double orderPrice = 0.0;
      double orderSL = 0.0;
      if(m_orderManager != NULL && m_orderManager.FindTicketViolatingPriceTolerance(priceTolerance, violatingTicket, isBuy, orderPrice, orderSL))
      {
         
            bool isAllowed = m_fvgFilter.IsTradeAllowedByFVG(orderPrice, orderSL, isBuy);

            if(!isAllowed)
            {
               if(m_orderManager.CancelOrderById(violatingTicket))
               {
               }
               else
               {
                  Logger::Error(StringFormat("❌ Erreur suppression ordre #%I64u | Erreur: %d", violatingTicket, GetLastError()));
               }

               m_orderManager.SendLimitOrder(!isBuy, orderPrice);
            }
            
         
      }
			return false;
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
   //| 🆕 Traiter le trailing à chaque tick (appelé depuis le bot)     |
   //+------------------------------------------------------------------+
   void ProcessTrailing()
   {
      // Appliquer le trailing (TP + TSL) - DOIT être appelé à chaque tick
      if(m_trailingManager != NULL)
      {
         m_trailingManager.ApplyTrailingTP();
         m_trailingManager.TrailStop();
      }
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
      if(m_displayManager != NULL)
      {
         m_displayManager.RefreshSwingDisplay();
      }
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
      
      // Créer les lignes TP/SL pour cette position
      if(m_trendlineManager != NULL)
      {
         double tpPrice = PositionGetDouble(POSITION_TP);
         double slPrice = PositionGetDouble(POSITION_SL);
         m_trendlineManager.CreatePositionLines(ticket, tpPrice, slPrice);
      }
      
      // 🆕 Déléguer la gestion du trailing au Trailing Manager
      if(m_trailingManager != NULL)
      {
         m_trailingManager.OnPositionOpened(ticket);
      }
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
      
      // 🆕 Déléguer le nettoyage du trailing au Trailing Manager
      if(m_trailingManager != NULL)
      {
         m_trailingManager.OnPositionClosed(ticket);
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
         
         // Vérifier si la position est déjà trackée
         if(m_trendlineManager != NULL && m_trendlineManager.HasPositionLines(ticket))
         {
            continue; // Déjà trackée
         }
         
         OnPositionOpened(ticket);
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
   
   //+------------------------------------------------------------------+
   //| Configuration du Signal Detection Manager                       |
   //+------------------------------------------------------------------+
   void EnableBuySignals(bool enable)
   {
      if(m_signalManager != NULL)
         m_signalManager.EnableBuySignals(enable);
   }
   
   void EnableSellSignals(bool enable)
   {
      if(m_signalManager != NULL)
         m_signalManager.EnableSellSignals(enable);
   }
   
   bool IsBuySignalsEnabled() const
   {
      return (m_signalManager != NULL) ? m_signalManager.IsBuySignalsEnabled() : false;
   }
   
   bool IsSellSignalsEnabled() const
   {
      return (m_signalManager != NULL) ? m_signalManager.IsSellSignalsEnabled() : false;
   }
   
   
};

