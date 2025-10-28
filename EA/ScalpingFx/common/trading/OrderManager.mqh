//+------------------------------------------------------------------+
//|                                            OrderManager.mqh     |
//|                    Gestionnaire des ordres pour un symbole      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include "../../../Shared/TradingEnums.mqh"
#include "../../../Shared/FVGDetector.mqh"

//+------------------------------------------------------------------+
//| Classe OrderManager - Gestion des ordres pour un symbole   |
//+------------------------------------------------------------------+
class OrderManager
{
private:
   // Données du symbole
   string            m_symbol;              // Nom du symbole
   int               m_magicNumber;         // Magic number unique
   double            m_point;               // Point du symbole
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe utilisé
   
   // Paramètres de trading
   double            m_tpPoints;            // Take Profit en points
   double            m_slPoints;            // Stop Loss en points
   int               m_expirationBars;      // Expiration des ordres
   int               m_orderDistPoints;     // Distance des ordres
   int               m_entryOffsetPoints;   // Entry offset pour Stop orders
   int               m_slippagePoints;     // Slippage tolerance
   string            m_tradeComment;       // Commentaire des trades
   
   // Risk management
   double            m_riskPercent;         // Risque par symbole
   double            m_currentRiskMultiplier; // Multiplicateur de risque actuel
   
   // Filters
   bool              m_useFvgFilter;        // Utiliser le filtre FVG
   FVGDetector*      m_fvgDetector;         // Détecteur FVG
   double            m_fvgCheckRadius;      // Rayon de recherche en points (défaut: 500)
   
   // Objet de trading
   CTrade            m_trade;               // Objet de trading
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   OrderManager(string symbol, 
                     int magicNumber,
                     ENUM_TIMEFRAMES timeframe,
                     double tpPoints,
                     double slPoints,
                     int expirationBars,
                     int orderDistPoints,
                     int entryOffsetPoints,
                     int slippagePoints,
                     string tradeComment,
                     double riskPercent = 0.0,
                     double riskMultiplier = 1.0,
                     bool useFvgFilter = false)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      m_tpPoints = tpPoints;
      m_slPoints = slPoints;
      m_expirationBars = expirationBars;
      m_orderDistPoints = orderDistPoints;
      m_entryOffsetPoints = entryOffsetPoints;
      m_slippagePoints = slippagePoints;
      m_tradeComment = tradeComment;
      m_riskPercent = riskPercent;
      m_currentRiskMultiplier = riskMultiplier;
      m_useFvgFilter = useFvgFilter;
      m_fvgDetector = NULL;
      m_fvgCheckRadius = 500.0;  // Par défaut 500 points
      
      // Initialiser les variables
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // Configurer l'objet de trading
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(m_slippagePoints);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
      
      // Initialiser le FVG Detector si le filtre est activé
      if(m_useFvgFilter)
      {
         InitializeFvgDetector();
      }
      
      Print("✓ OrderManager initialized for ", symbol, " | Magic: ", magicNumber, 
            " | FVG Filter: ", (m_useFvgFilter ? "ON" : "OFF"));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~OrderManager()
   {
      // Cleanup FVG Detector
      if(m_fvgDetector != NULL)
      {
         delete m_fvgDetector;
         m_fvgDetector = NULL;
      }
      
      Print("✓ OrderManager destroyed for ", m_symbol);
   }

   //+------------------------------------------------------------------+
   //| Vérifier le filtre FVG (à implémenter)                          |
   //+------------------------------------------------------------------+
   bool CheckFvgDisqualifier()
   {
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Envoyer un ordre Buy (Stop ou Limit selon la stratégie)         |
   //+------------------------------------------------------------------+
   bool SendBuyOrder(double entry)
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      double tp = entry + m_tpPoints * m_point;
      double sl = entry - m_slPoints * m_point;
      
      double lots = 0.01;
      if(m_riskPercent > 0) lots = CalcLots(entry - sl);
      
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      // Mode BREAKOUT : utiliser BuyStop (attendre que le prix casse le niveau)
      double adjustedEntry = entry - (m_entryOffsetPoints * m_point);
      double adjustedTP = adjustedEntry + m_tpPoints * m_point;
      double adjustedSL = adjustedEntry - m_slPoints * m_point;
      
      // Recalculate lots with adjusted SL for proper risk calculation
      if(m_riskPercent > 0) lots = CalcLots(adjustedEntry - adjustedSL);
      
      if(ask > adjustedEntry - m_orderDistPoints * m_point) return false;
      
      if(m_trade.BuyStop(lots, adjustedEntry, m_symbol, adjustedSL, adjustedTP, ORDER_TIME_SPECIFIED, expiration, m_tradeComment))
      {
         Print("✓ Buy Stop order sent for ", m_symbol, " at ", adjustedEntry, 
               " (offset: ", m_entryOffsetPoints, " pts) | Lots: ", lots);
         return true;
      }
      else
      {
         Print("✗ Failed to send Buy Stop order for ", m_symbol, " | Error: ", GetLastError());
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Envoyer un ordre Sell (Stop ou Limit selon la stratégie)        |
   //+------------------------------------------------------------------+
   bool SendSellOrder(double entry)
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      double tp = entry - m_tpPoints * m_point;
      double sl = entry + m_slPoints * m_point;
      
      double lots = 0.01;
      if(m_riskPercent > 0) lots = CalcLots(sl - entry);
      
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      // Mode BREAKOUT : utiliser SellStop (attendre que le prix casse le niveau)
      double adjustedEntry = entry + (m_entryOffsetPoints * m_point);
      double adjustedTP = adjustedEntry - m_tpPoints * m_point;
      double adjustedSL = adjustedEntry + m_slPoints * m_point;
      
      // Recalculate lots with adjusted SL for proper risk calculation
      if(m_riskPercent > 0) lots = CalcLots(adjustedSL - adjustedEntry);
      
      if(bid < adjustedEntry + m_orderDistPoints * m_point) return false;
      
      if(m_trade.SellStop(lots, adjustedEntry, m_symbol, adjustedSL, adjustedTP, ORDER_TIME_SPECIFIED, expiration, m_tradeComment))
      {
         Print("✓ Sell Stop order sent for ", m_symbol, " at ", adjustedEntry,
               " (offset: ", m_entryOffsetPoints, " pts) | Lots: ", lots);
         return true;
      }
      else
      {
         Print("✗ Failed to send Sell Stop order for ", m_symbol, " | Error: ", GetLastError());
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Annuler tous les ordres pending sans fermer les positions      |
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
   //| Ajuster les tailles des ordres pending selon le multiplicateur |
   //+------------------------------------------------------------------+
   int AdjustPositionSizes(double newMultiplier)
   {
      // Valider le multiplicateur (0.1 à 10.0)
      double validMultiplier = MathMax(0.1, MathMin(10.0, newMultiplier));
      
      // Sauvegarder l'ancien multiplicateur pour le calcul
      double oldMultiplier = m_currentRiskMultiplier;
      
      // Mettre à jour le multiplicateur actuel
      m_currentRiskMultiplier = validMultiplier;
      
      int adjustedOrders = 0;
      
      // Ajuster les ordres pending existants
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(!OrderSelect(ticket)) continue;
         
         // Vérifier que c'est notre ordre
         if(OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
         if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
         
         // Récupérer les infos de l'ordre
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         double orderSL = OrderGetDouble(ORDER_SL);
         double orderTP = OrderGetDouble(ORDER_TP);
         double currentVolume = OrderGetDouble(ORDER_VOLUME_CURRENT);
         datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         
         // Calculer le nouveau volume
         double baseVolume = (oldMultiplier > 0) ? (currentVolume / oldMultiplier) : currentVolume;
         double newVolume = baseVolume * validMultiplier;
         
         // Normaliser selon les contraintes du broker
         double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
         double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
         double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         newVolume = MathFloor(newVolume / lotStep) * lotStep;
         newVolume = MathMax(minLot, MathMin(maxLot, newVolume));
         newVolume = NormalizeDouble(newVolume, 2);
         
         // Si le volume n'a pas changé significativement, passer
         if(MathAbs(newVolume - currentVolume) < lotStep) continue;
         
         // Supprimer l'ancien ordre
         if(!m_trade.OrderDelete(ticket))
         {
            Print("❌ [", m_symbol, "] Impossible de supprimer ordre #", ticket, " | Erreur: ", GetLastError());
            continue;
         }
         
         // Recréer l'ordre avec le nouveau volume
         bool success = false;
         ulong newTicket = 0;
         
         switch(orderType)
         {
            case ORDER_TYPE_BUY_STOP:
               success = m_trade.BuyStop(newVolume, orderPrice, m_symbol, orderSL, orderTP, 
                                        ORDER_TIME_SPECIFIED, expiration, m_tradeComment);
               newTicket = m_trade.ResultOrder();
               break;
               
            case ORDER_TYPE_SELL_STOP:
               success = m_trade.SellStop(newVolume, orderPrice, m_symbol, orderSL, orderTP,
                                         ORDER_TIME_SPECIFIED, expiration, m_tradeComment);
               newTicket = m_trade.ResultOrder();
               break;
               
            case ORDER_TYPE_BUY_LIMIT:
               success = m_trade.BuyLimit(newVolume, orderPrice, m_symbol, orderSL, orderTP,
                                         ORDER_TIME_SPECIFIED, expiration, m_tradeComment);
               newTicket = m_trade.ResultOrder();
               break;
               
            case ORDER_TYPE_SELL_LIMIT:
               success = m_trade.SellLimit(newVolume, orderPrice, m_symbol, orderSL, orderTP,
                                          ORDER_TIME_SPECIFIED, expiration, m_tradeComment);
               newTicket = m_trade.ResultOrder();
               break;
               
            default:
               // Ignorer les autres types (Market orders ne devraient pas être ici)
               continue;
         }
         
         if(success)
         {
            Print("📝 [", m_symbol, "] Ordre #", ticket, " → #", newTicket, " | Volume: ", 
                  DoubleToString(currentVolume, 2), " → ", DoubleToString(newVolume, 2), " lots");
            adjustedOrders++;
         }
         else
         {
            Print("❌ [", m_symbol, "] Échec recréation ordre (", EnumToString(orderType), ") | ",
                  "Prix: ", DoubleToString(orderPrice, _Digits), " | Volume: ", DoubleToString(newVolume, 2), " | ",
                  "Erreur: ", GetLastError());
         }
      }
      
      // Log du résultat final
      if(adjustedOrders > 0)
      {
         Print("📊 [", m_symbol, "] Multiplicateur: ", DoubleToString(oldMultiplier, 2), 
               " → ", DoubleToString(validMultiplier, 2), " | ", adjustedOrders, " ordre(s) ajusté(s)");
      }
      else
      {
         Print("📊 [", m_symbol, "] Multiplicateur: ", DoubleToString(oldMultiplier, 2),
               " → ", DoubleToString(validMultiplier, 2), " | Aucun ordre pending à ajuster");
      }
      
      return adjustedOrders;
   }
   
   //+------------------------------------------------------------------+
   //| Définir le multiplicateur de risque                             |
   //+------------------------------------------------------------------+
   void SetRiskMultiplier(double multiplier)
   {
      m_currentRiskMultiplier = MathMax(0.1, MathMin(10.0, multiplier));
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le multiplicateur de risque                             |
   //+------------------------------------------------------------------+
   double GetRiskMultiplier()
   {
      return m_currentRiskMultiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir l'état du filtre FVG                                     |
   //+------------------------------------------------------------------+
   bool GetUseFvgFilter()
   {
      return m_useFvgFilter;
   }
   
   //+------------------------------------------------------------------+
   //| Définir l'état du filtre FVG                                     |
   //+------------------------------------------------------------------+
   void SetUseFvgFilter(bool enabled)
   {
      m_useFvgFilter = enabled;
   }
   
   //+------------------------------------------------------------------+
   //| Définir le rayon de recherche FVG (en points)                   |
   //+------------------------------------------------------------------+
   void SetFvgCheckRadius(double radiusPoints)
   {
      m_fvgCheckRadius = MathMax(50.0, radiusPoints);  // Minimum 50 points
   }
   
   
   
private:
   //+------------------------------------------------------------------+
   //| Initialiser le détecteur FVG                                     |
   //+------------------------------------------------------------------+
   void InitializeFvgDetector()
   {
      if(m_fvgDetector != NULL)
      {
         delete m_fvgDetector;
         m_fvgDetector = NULL;
      }
      
      m_fvgDetector = new FVGDetector();
      
      // Configuration FVG
      FVGConfig config;
      config.atrPeriod = 14;
      config.minGapATRPercent = 5.0;
      config.epsilonPts = 0.1;
      config.invalidatePct = 30.0;
      config.mode = WICK_TOUCH;
      config.lookbackBars = 300;
      config.debugMode = false;
      
      // Initialiser avec le timeframe actuel
      if(!m_fvgDetector.Init(m_symbol, m_timeframe, config))
      {
         Print("❌ [", m_symbol, "] Failed to initialize FVG Detector");
         delete m_fvgDetector;
         m_fvgDetector = NULL;
         m_useFvgFilter = false;  // Désactiver le filtre
      }
      else
      {
         // Traiter le timeframe pour détecter les FVG
         m_fvgDetector.ProcessTimeframe(m_timeframe);
         m_fvgDetector.UpdateInvalidation(m_timeframe);
         
         int total, bullish, bearish, valid;
         m_fvgDetector.GetStats(total, bullish, bearish, valid);
         Print("📊 [", m_symbol, "] FVG Detector initialized | Total: ", total, 
               " | Valid: ", valid, " | Bullish: ", bullish, " | Bearish: ", bearish);
      }
   }

   
   
   //+------------------------------------------------------------------+
   //| Filtre breakout : vérifie si FVG opposé entre Entry et SL       |
   //| @param entryPrice - Prix d'entrée proposé                        |
   //| @param stopLoss - Prix du stop loss                              |
   //| @param isBuy - true pour Buy, false pour Sell                    |
   //| @return true si le trade est autorisé, false si bloqué          |
   //+------------------------------------------------------------------+
   bool AllowBreakoutTrade(double entryPrice, double stopLoss, bool isBuy)
   {
      // Si le filtre est désactivé ou le détecteur non initialisé
      if(!m_useFvgFilter || m_fvgDetector == NULL)
         return true;  // Autoriser le trade
      
      // Mettre à jour les FVG (détection + invalidation)
      m_fvgDetector.ProcessTimeframe(m_timeframe);
      m_fvgDetector.UpdateInvalidation(m_timeframe);
      
      // Récupérer TOUS les FVG valides
      FVGInfo allFvgs[];
      m_fvgDetector.GetFVGList(allFvgs, true);
      
      for(int i = 0; i < ArraySize(allFvgs); i++)
      {
         if(!allFvgs[i].IsValid)
            continue;
         
         // Zone du FVG
         double fvgHigh = allFvgs[i].top;
         double fvgLow = allFvgs[i].bottom;
         
         // Normaliser si inversé
         if(fvgHigh < fvgLow)
         {
            double tmp = fvgHigh;
            fvgHigh = fvgLow;
            fvgLow = tmp;
         }
         
         // Vérifie si la zone FVG est entre Entry et SL
         bool fvgInsideTradeZone = false;
         
         if(isBuy)
         {
            // Pour un Buy : entry > SL, donc vérifier si FVG est entre SL et entry
            fvgInsideTradeZone = (fvgHigh <= entryPrice && fvgLow >= stopLoss);
         }
         else
         {
            // Pour un Sell : entry < SL, donc vérifier si FVG est entre entry et SL
            fvgInsideTradeZone = (fvgHigh <= stopLoss && fvgLow >= entryPrice);
         }
         
         // Vérifie si le FVG est d'une direction OPPOSÉE au signal
         bool isOpposite = (isBuy && !allFvgs[i].isBullish)   // Buy mais FVG bearish
                        || (!isBuy && allFvgs[i].isBullish);   // Sell mais FVG bullish
         
         if(fvgInsideTradeZone && isOpposite)
         {
            Print("⚠️ [", m_symbol, "] FVG opposé détecté entre Entry et SL - Trade annulé");
            Print("   ", (isBuy ? "BUY" : "SELL"), " @ ", DoubleToString(entryPrice, _Digits),
                  " | SL: ", DoubleToString(stopLoss, _Digits),
                  " | FVG ", (allFvgs[i].isBullish ? "BULLISH" : "BEARISH"),
                  " [", DoubleToString(fvgLow, _Digits), " - ", DoubleToString(fvgHigh, _Digits), "]");
            return false;  // Bloquer le trade
         }
      }
      
      return true;  // Aucun risque détecté, autoriser le trade
   }
   
   //+------------------------------------------------------------------+
   //| Calculer la taille du lot basée sur le risque                   |
   //+------------------------------------------------------------------+
   double CalcLots(double slPoints)
   {
      double effectiveRisk = m_riskPercent * m_currentRiskMultiplier;
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
};
