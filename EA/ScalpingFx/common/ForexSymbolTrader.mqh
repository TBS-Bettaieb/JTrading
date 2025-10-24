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
#include "../../../EA/Shared/Strategy/SymbolTraderBase.mqh"
#include "ForexSwingAnalyzer.mqh"
#include "ForexTrendlineManager.mqh"
#include "../../../EA/Shared/TrailingTP_System.mqh"
#include "../../../EA/Shared/DynamicTrailingStop.mqh"

//+------------------------------------------------------------------+
//| Classe ForexSymbolTrader - Gestion d'un symbole spécifique       |
//+------------------------------------------------------------------+
class ForexSymbolTrader : public SymbolTraderBase
{
private:
   // Paramètres spécifiques
   int               m_tslTriggerPoints;    // Points en profit avant TSL
   int               m_tslPoints;           // Trailing Stop Loss
   int               m_barsN;               // Nombre de barres pour l'analyse
   int               m_expirationBars;      // Expiration des ordres
   int               m_orderDistPoints;     // Distance des ordres
   int               m_slippagePoints;      // Slippage tolerance
   int               m_entryOffsetPoints;   // Entry offset for Stop orders
   ENUM_STRATEGY_MODE m_strategyMode;       // Mode de stratégie
   
   // Objets spécifiques
   ForexCommissionManager m_commissionManager;  // Gestionnaire de commission
   ForexSwingAnalyzer m_swingAnalyzer;      // Analyseur de swing points
   ForexTrendlineManager* m_trendlineManager; // Gestionnaire des lignes TP/SL
   
   // Trailing TP
   CTrailingTP*      m_trailingTP;
   bool              m_useTrailingTP;
   string            m_customTPLevels;
   struct PositionTrailing {
      ulong ticket;
      CTrailingTP* trailing;
   };
   PositionTrailing  m_positionTrailings[];
   
   // Dynamic Trailing Stop Loss
   CDynamicTrailingStop* m_dynamicTSL;
   
   // Compteurs spécifiques
   int               m_buyTotal;            // Nombre positions/ordres BUY
   int               m_sellTotal;           // Nombre positions/ordres SELL
   
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
                     bool useDynamicTSLTrigger = true,
                     double tslCostMultiplier = 1.5,
                     int tslMinTriggerPoints = 50)
   : SymbolTraderBase(symbol, magicNumber, timeframe, riskPercent, tpPoints, slPoints, tradeComment)
   {
      // Initialiser les paramètres spécifiques
      m_tslTriggerPoints = tslTriggerPoints;
      m_tslPoints = tslPoints;
      m_barsN = barsN;
      m_expirationBars = expirationBars;
      m_orderDistPoints = orderDistPoints;
      m_slippagePoints = slippagePoints;
      m_entryOffsetPoints = entryOffsetPoints;
      m_strategyMode = strategyMode;
      
      // Initialiser les compteurs
      m_buyTotal = 0;
      m_sellTotal = 0;
      
      // Initialiser l'analyseur de swing
      m_swingAnalyzer = ForexSwingAnalyzer(symbol, timeframe, magicNumber, barsN);
      
      // Initialiser le Dynamic Trailing Stop
      m_dynamicTSL = new CDynamicTrailingStop(
         tslPoints,
         tslTriggerPoints,
         useDynamicTSLTrigger,
         tslCostMultiplier,
         tslMinTriggerPoints,
         m_slippagePoints
      );
      m_dynamicTSL.SetCommissionManager(&m_commissionManager);
      
      // Initialiser le Trailing TP
      m_useTrailingTP = useTrailingTP;
      m_customTPLevels = customTPLevels;
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
      
      // Cleanup Dynamic TSL
      if(m_dynamicTSL != NULL) 
      {
         delete m_dynamicTSL;
         m_dynamicTSL = NULL;
      }
      
      Print("✓ ForexSymbolTrader destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Implémentation des méthodes virtuelles pures                     |
   //+------------------------------------------------------------------+
   
   //+------------------------------------------------------------------+
   //| Traitement principal du tick - VERSION AVEC LOGS DE DEBUG       |
   //+------------------------------------------------------------------+
   virtual void OnTick() override
   {
      // 🔍 LOG 1: Vérifier si c'est une nouvelle barre
      bool isNewBar = IsNewBar();
      
      if(isNewBar)
      {
         OnNewBar();
      }
      
      // Trailing Stop Loss dynamique
      TrailStop();
      
      // Trailing TP
      ApplyTrailingTP();
   }
   
   //+------------------------------------------------------------------+
   //| Traitement d'une nouvelle barre - VERSION AVEC LOGS DE DEBUG    |
   //+------------------------------------------------------------------+
   virtual void OnNewBar() override
   {
      // Mettre à jour les compteurs
      UpdateCounters();
      
      // Vérifier les nouvelles positions pour créer les lignes TP/SL
      CheckForNewPositions();
      
      // Chercher des signaux de trading
      bool hasSignal = HasTradingSignal();
      
      if(hasSignal)
      {
         ProcessTradingSignal();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier s'il y a un signal de trading                          |
   //+------------------------------------------------------------------+
   virtual bool HasTradingSignal() override
   {
      // ✅ DOUBLE VÉRIFICATION : Recompter avant de chercher un signal
      UpdateCounters();
      
      // Vérifier les positions/ordres existants
      if(m_buyTotal > 0 && m_sellTotal > 0)
      {
         return false;
      }
      
      if(m_strategyMode == STRATEGY_BREAKOUT)
      {
         // Mode BREAKOUT : chercher des cassures
         double high = m_swingAnalyzer.FindHigh();
         double low = m_swingAnalyzer.FindLow();
         
         if(m_buyTotal <= 0 && high > 0)
         {
            Logger::Debug("✅ SIGNAL DÉTECTÉ: BUY BREAKOUT - High point found at " + DoubleToString(high, _Digits));
            return true;
         }
         if(m_sellTotal <= 0 && low > 0)
         {
            Logger::Debug("✅ SIGNAL DÉTECTÉ: SELL BREAKOUT - Low point found at " + DoubleToString(low, _Digits));
            return true;
         }
      }
      else if(m_strategyMode == STRATEGY_REVERSION)
      {
         // Mode REVERSION : chercher des rebonds
         double high = m_swingAnalyzer.FindHigh();
         double low = m_swingAnalyzer.FindLow();
         
         if(m_buyTotal <= 0 && low > 0)
         {
            Logger::Debug("✅ SIGNAL DÉTECTÉ: BUY REVERSION - Low point found at " + DoubleToString(low, _Digits));
            return true;
         }
         if(m_sellTotal <= 0 && high > 0)
         {
            Logger::Debug("✅ SIGNAL DÉTECTÉ: SELL REVERSION - High point found at " + DoubleToString(high, _Digits));
            return true;
         }
      }
      else
      {
         Logger::Warning("⚠️ HasTradingSignal: Unknown strategy mode: " + EnumToString(m_strategyMode));
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Traiter le signal de trading                                    |
   //+------------------------------------------------------------------+
   virtual void ProcessTradingSignal() override
   {
      // 🛡️ LOG DE SÉCURITÉ : Vérifier l'état avant de créer des ordres
      Logger::Debug("🔍 ProcessTradingSignal [" + m_symbol + "] - BuyTotal: " + 
                    IntegerToString(m_buyTotal) + " | SellTotal: " + IntegerToString(m_sellTotal));
      
      // Vérification redondante pour éviter les ordres multiples
      if(m_buyTotal > 0 && m_sellTotal > 0)
      {
         Logger::Warning("⚠️ Positions/ordres déjà existants des deux côtés, skip signal");
         return;
      }
      
      if(m_strategyMode == STRATEGY_BREAKOUT)
      {
         
         // Mode BREAKOUT : acheter quand le prix CASSE un swing high
         if(m_buyTotal <= 0)
         {
            double high = m_swingAnalyzer.FindHigh();
            if(high > 0)
            {
               double adjustedEntry = high - (m_entryOffsetPoints * m_point);
               double adjustedTP = adjustedEntry + m_tpPoints * m_point;
               double adjustedSL = adjustedEntry - m_slPoints * m_point;
               
               // 🔍 LOGS DE DEBUG DÉTAILLÉS POUR BUY STOP
               Logger::Debug("🔍 BUY STOP DEBUG - Mode BREAKOUT:");
               Logger::Debug("  - Swing High détecté: " + DoubleToString(high, _Digits));
               Logger::Debug("  - Entry Offset: " + IntegerToString(m_entryOffsetPoints) + " pts (" + DoubleToString(m_entryOffsetPoints * m_point, _Digits) + ")");
               Logger::Debug("  - Prix d'entrée calculé: " + DoubleToString(adjustedEntry, _Digits));
               Logger::Debug("  - Stop Loss: " + DoubleToString(adjustedSL, _Digits) + " (-" + IntegerToString(m_slPoints) + " pts)");
               Logger::Debug("  - Take Profit: " + DoubleToString(adjustedTP, _Digits) + " (+" + IntegerToString(m_tpPoints) + " pts)");
               Logger::Debug("  - Prix actuel BID: " + DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_BID), _Digits));
               Logger::Debug("  - Prix actuel ASK: " + DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_ASK), _Digits));
               Logger::Debug("  - Distance Entry-ASK: " + DoubleToString((adjustedEntry - SymbolInfoDouble(m_symbol, SYMBOL_ASK))/m_point, 1) + " pts");
               
               ulong ticket = CreateBuyStop(adjustedEntry, adjustedSL, adjustedTP);
               if(ticket > 0)
               {
                  Logger::Success("✅ Buy Stop order sent for " + m_symbol + " at " + DoubleToString(adjustedEntry, _Digits) + 
                                 " (offset: " + IntegerToString(m_entryOffsetPoints) + " pts) | Ticket: " + IntegerToString(ticket));
               }
               else
               {
                  Logger::Error("❌ Failed to send Buy Stop order for " + m_symbol + " - Check order parameters and market conditions");
                  Logger::Error("❌ BUY STOP FAILED - Paramètres utilisés:");
                  Logger::Error("    Entry: " + DoubleToString(adjustedEntry, _Digits));
                  Logger::Error("    SL: " + DoubleToString(adjustedSL, _Digits));
                  Logger::Error("    TP: " + DoubleToString(adjustedTP, _Digits));
                  Logger::Error("    Volume calculé: " + DoubleToString(CalculateRiskBasedLots(adjustedEntry - adjustedSL), 2));
               }
            }
         }
         
         // Mode BREAKOUT : vendre quand le prix CASSE un swing low
         if(m_sellTotal <= 0)
         {
            double low = m_swingAnalyzer.FindLow();
            if(low > 0)
            {
               double adjustedEntry = low + (m_entryOffsetPoints * m_point);
               double adjustedTP = adjustedEntry - m_tpPoints * m_point;
               double adjustedSL = adjustedEntry + m_slPoints * m_point;
               
               // 🔍 LOGS DE DEBUG DÉTAILLÉS POUR SELL STOP
               Logger::Debug("🔍 SELL STOP DEBUG - Mode BREAKOUT:");
               Logger::Debug("  - Swing Low détecté: " + DoubleToString(low, _Digits));
               Logger::Debug("  - Entry Offset: " + IntegerToString(m_entryOffsetPoints) + " pts (" + DoubleToString(m_entryOffsetPoints * m_point, _Digits) + ")");
               Logger::Debug("  - Prix d'entrée calculé: " + DoubleToString(adjustedEntry, _Digits));
               Logger::Debug("  - Stop Loss: " + DoubleToString(adjustedSL, _Digits) + " (+" + IntegerToString(m_slPoints) + " pts)");
               Logger::Debug("  - Take Profit: " + DoubleToString(adjustedTP, _Digits) + " (-" + IntegerToString(m_tpPoints) + " pts)");
               Logger::Debug("  - Prix actuel BID: " + DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_BID), _Digits));
               Logger::Debug("  - Prix actuel ASK: " + DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_ASK), _Digits));
               Logger::Debug("  - Distance BID-Entry: " + DoubleToString((SymbolInfoDouble(m_symbol, SYMBOL_BID) - adjustedEntry)/m_point, 1) + " pts");
               Logger::Debug("  - Stops Level broker: " + IntegerToString((int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL)) + " pts");
               Logger::Debug("  - Tick Size: " + DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE), 5));
               
               // Validation préalable des paramètres
               if(!ValidateSellStopParameters(adjustedEntry, adjustedSL, adjustedTP))
               {
                  Logger::Error("❌ SELL STOP: Validation préalable échouée - Ordre annulé");
                  return;
               }
               
               ulong ticket = CreateSellStop(adjustedEntry, adjustedSL, adjustedTP);
               if(ticket > 0)
               {
                  Logger::Success("✅ Sell Stop order sent for " + m_symbol + " at " + DoubleToString(adjustedEntry, _Digits) +
                                 " (offset: " + IntegerToString(m_entryOffsetPoints) + " pts) | Ticket: " + IntegerToString(ticket));
               }
               else
               {
                  Logger::Error("❌ Failed to send Sell Stop order for " + m_symbol + " - Check order parameters and market conditions");
                  Logger::Error("❌ SELL STOP FAILED - Paramètres utilisés:");
                  Logger::Error("    Entry: " + DoubleToString(adjustedEntry, _Digits));
                  Logger::Error("    SL: " + DoubleToString(adjustedSL, _Digits));
                  Logger::Error("    TP: " + DoubleToString(adjustedTP, _Digits));
                  Logger::Error("    Volume calculé: " + DoubleToString(CalculateRiskBasedLots(adjustedSL - adjustedEntry), 2));
               }
            }
         }
      }
      else if(m_strategyMode == STRATEGY_REVERSION)
      {
         // Mode REVERSION : acheter quand le prix TOUCHE un swing low
         if(m_buyTotal <= 0)
         {
            double low = m_swingAnalyzer.FindLow();
            if(low > 0)
            {
               double tp = low + m_tpPoints * m_point;
               double sl = low - m_slPoints * m_point;
               
               ulong ticket = CreateBuyLimit(low, sl, tp);
               if(ticket > 0)
               {
                  Logger::Success("✅ Buy Limit order sent for " + m_symbol + " at " + DoubleToString(low, _Digits) + 
                                 " | Ticket: " + IntegerToString(ticket));
               }
               else
               {
                  Logger::Error("❌ Failed to send Buy Limit order for " + m_symbol + " - Check order parameters and market conditions");
               }
            }
         }
         
         // Mode REVERSION : vendre quand le prix TOUCHE un swing high
         if(m_sellTotal <= 0)
         {
            double high = m_swingAnalyzer.FindHigh();
            if(high > 0)
            {
               double tp = high - m_tpPoints * m_point;
               double sl = high + m_slPoints * m_point;
               
               ulong ticket = CreateSellLimit(high, sl, tp);
               if(ticket > 0)
               {
                  Logger::Success("✅ Sell Limit order sent for " + m_symbol + " at " + DoubleToString(high, _Digits) + 
                                 " | Ticket: " + IntegerToString(ticket));
               }
               else
               {
                  Logger::Error("❌ Failed to send Sell Limit order for " + m_symbol + " - Check order parameters and market conditions");
               }
            }
         }
      }
      else
      {
         Logger::Warning("⚠️ ProcessTradingSignal: Unknown strategy mode: " + EnumToString(m_strategyMode));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Méthodes spécifiques à cette implémentation                     |
   //+------------------------------------------------------------------+
   
   //+------------------------------------------------------------------+
   //| Trailing Stop Loss DYNAMIQUE basé sur les coûts réels          |
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
               if(m_positionManager != NULL && m_positionManager.ModifyPosition(ticket, newSL, newTP))
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
   
   //+------------------------------------------------------------------+
   //| Rafraîchir l'affichage des lignes swing                         |
   //+------------------------------------------------------------------+
   void RefreshSwingDisplay()
   {
      m_swingAnalyzer.RefreshSwingDisplay();
   }
   
   //+------------------------------------------------------------------+
   //| Méthodes pour accéder au Dynamic TSL                            |
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
   //| Validation préalable des paramètres Sell Stop                   |
   //+------------------------------------------------------------------+
   bool ValidateSellStopParameters(double entryPrice, double slPrice, double tpPrice)
   {
      double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double minDistance = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      
      Logger::Debug("🔍 VALIDATION SELL STOP:");
      Logger::Debug("  - Prix d'entrée: " + DoubleToString(entryPrice, _Digits));
      Logger::Debug("  - Prix actuel BID: " + DoubleToString(currentBid, _Digits));
      Logger::Debug("  - Distance minimum: " + DoubleToString(minDistance/m_point, 1) + " pts");
      
      // 1. Vérifier que l'ordre est bien un SELL STOP (prix d'entrée < prix actuel)
      if(entryPrice >= currentBid)
      {
         Logger::Error("❌ SELL STOP: Entry price " + DoubleToString(entryPrice, _Digits) + 
                      " must be below current bid " + DoubleToString(currentBid, _Digits));
         return false;
      }
      
      // 2. Vérifier la distance minimum
      double distance = currentBid - entryPrice;
      if(distance < minDistance)
      {
         Logger::Error("❌ SELL STOP: Distance " + DoubleToString(distance/m_point, 1) + 
                      " pts is below minimum " + DoubleToString(minDistance/m_point, 1) + " pts");
         return false;
      }
      
      // 3. Vérifier l'alignement avec le tick size
      if(tickSize > 0)
      {
         double remainder = MathMod(entryPrice, tickSize);
         if(remainder > 0.0001)
         {
            Logger::Error("❌ SELL STOP: Entry price " + DoubleToString(entryPrice, _Digits) + 
                         " is not aligned with tick size " + DoubleToString(tickSize, 5));
            return false;
         }
      }
      
      // 4. Vérifier que le SL est au-dessus du prix d'entrée
      if(slPrice <= entryPrice)
      {
         Logger::Error("❌ SELL STOP: Stop Loss " + DoubleToString(slPrice, _Digits) + 
                      " must be above entry price " + DoubleToString(entryPrice, _Digits));
         return false;
      }
      
      // 5. Vérifier que le TP est en dessous du prix d'entrée
      if(tpPrice >= entryPrice)
      {
         Logger::Error("❌ SELL STOP: Take Profit " + DoubleToString(tpPrice, _Digits) + 
                      " must be below entry price " + DoubleToString(entryPrice, _Digits));
         return false;
      }
      
      Logger::Debug("✅ SELL STOP: Validation préalable réussie");
      return true;
   }
   
private:
   //+------------------------------------------------------------------+
   //| Mettre à jour les compteurs de positions/ordres                 |
   //+------------------------------------------------------------------+
   void UpdateCounters()
   {
      m_buyTotal = 0;
      m_sellTotal = 0;
      
      bool usedManagers = false;
      
      // Essayer d'utiliser les managers injectés
      if(m_positionManager != NULL)
      {
         m_positionManager.UpdateCounters();
         int buyPositions = m_positionManager.GetBuyPositions();
         int sellPositions = m_positionManager.GetSellPositions();
         m_buyTotal += buyPositions;
         m_sellTotal += sellPositions;
         usedManagers = true;
      }
      
      if(m_orderManager != NULL)
      {
         m_orderManager.UpdateCounters();
         int buyOrders = m_orderManager.GetBuyOrders();
         int sellOrders = m_orderManager.GetSellOrders();
         m_buyTotal += buyOrders;
         m_sellTotal += sellOrders;
         usedManagers = true;
      }
      
      // 🆕 FALLBACK : Si les managers sont NULL, compter directement
      if(!usedManagers)
      {
         Logger::Warning("⚠️ UpdateCounters: Managers NULL - Using fallback counting for " + m_symbol);
         
         // Compter directement les positions
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(posType == POSITION_TYPE_BUY) m_buyTotal++;
            if(posType == POSITION_TYPE_SELL) m_sellTotal++;
         }
         
         // Compter directement les ordres pending
         for(int i = OrdersTotal() - 1; i >= 0; i--)
         {
            ulong ticket = OrderGetTicket(i);
            if(ticket <= 0) continue;
            if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
            if(OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
            
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT) 
               m_buyTotal++;
            if(orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_LIMIT) 
               m_sellTotal++;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Détecter les nouvelles positions                                 |
   //+------------------------------------------------------------------+
   void CheckForNewPositions()
   {
      if(m_positionManager == NULL) return;
      
      ulong tickets[];
      int count = m_positionManager.GetPositionTickets(tickets);
      
      for(int i = 0; i < count; i++)
      {
         ulong ticket = tickets[i];
         
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
   //| Appelé quand une position est ouverte                           |
   //+------------------------------------------------------------------+
   void OnPositionOpened(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return;
      
      // Calculer les coûts de position pour le TSL dynamique
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
      
      // Gestion du trailing TP
      if(!m_useTrailingTP || m_trailingTP == NULL) return;
      
      // Vérifier que ce n'est pas déjà tracké
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].ticket == ticket) return;
      }
      
      // Créer un nouveau trailing TP pour cette position
      CTrailingTP* newTrailing = new CTrailingTP(
         m_trailingTP.GetMode(),
         m_trailingTP.GetCustomLevelsString()
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
      // Nettoyer les coûts de position pour le TSL dynamique
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.RemovePositionCosts(ticket);
      }
      
      // Supprimer les lignes TP/SL pour cette position
      if(m_trendlineManager != NULL)
      {
         m_trendlineManager.DeletePositionLines(ticket);
      }
      
      // Gestion du trailing TP
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
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation avec injection de dépendances              |
//+------------------------------------------------------------------+
/*
// Création des managers
CTrade* trade = new CTrade();
VolumeManager* volumeMgr = new VolumeManager("EURUSD");
TradingValidator* validator = new TradingValidator("EURUSD");
PositionManager* posMgr = new PositionManager("EURUSD", 12345, trade);
PendingOrderManager* orderMgr = new PendingOrderManager("EURUSD", 12345, trade, volumeMgr, validator, 10, PERIOD_M15, 3, "MyEA");
DynamicAdjustmentManager* adjMgr = new DynamicAdjustmentManager("EURUSD", 12345, posMgr, orderMgr, volumeMgr);

// Création du trader refactorisé
ForexSymbolTrader* trader = new ForexSymbolTrader(
   "EURUSD", 12345, PERIOD_M15, 2.0, 100, 50, 25, 20, 20, 10, 5, 3, 2, "MyEA", STRATEGY_BREAKOUT
);

// Injection des dépendances
trader.SetVolumeManager(volumeMgr);
trader.SetValidator(validator);
trader.SetPositionManager(posMgr);
trader.SetOrderManager(orderMgr);
trader.SetAdjustmentManager(adjMgr);

// Utilisation
trader.OnTick();
string status = trader.GetStatusInfo();

// Ajustement dynamique
int adjusted = trader.AdjustPositionSizes(2.0);

// Nettoyage
delete trader;
delete adjMgr;
delete orderMgr;
delete posMgr;
delete validator;
delete volumeMgr;
delete trade;
*/