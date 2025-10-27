//+------------------------------------------------------------------+
//|                                          TripleRSITrader.mqh     |
//|                                    Trader Triple RSI par Symbole |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
#include "../../Shared/Logger.mqh"
#include "../../Shared/TradingUtils.mqh"
#include "../../Shared/DynamicTrailingStop.mqh"
#include "../../Shared/ForexCommissionManager.mqh"
#include "../Logic/RSI_Calculator.mqh"
#include "../Logic/RSI_AlignmentDetector.mqh"
#include "../Logic/EntryRulesValidator.mqh"
#include "../Logic/ConfluenceFilters.mqh"

//+------------------------------------------------------------------+
//| Triple RSI Trader Class                                          |
//+------------------------------------------------------------------+
class CTripleRSITrader
{
private:
   string m_symbol;
   int m_magic;
   ENUM_TIMEFRAMES m_timeframe;
   double m_riskPercent;
   int m_slPoints;
   double m_tpRatio;
   CTrade m_trade;
   
   CTripleRSICalculator* m_rsiCalc;
   CRSIAlignmentDetector* m_alignDetector;
   CEntryRulesValidator* m_entryValidator;
   
   // Trailing Stop Dynamique
   bool m_useTrailingStop;
   bool m_useDynamicTrailing;
   CDynamicTrailingStop* m_dynamicTSL;
   ForexCommissionManager* m_commissionManager;
   
   // Paramètres TSL classique (fallback)
   int m_tslTriggerPoints;
   int m_tslPoints;
   
   // Statistiques
   int m_totalTrades;
   int m_winningTrades;
   double m_totalProfit;
   datetime m_lastTradeTime;
   
   // Configuration des confluences
   bool m_enableConfluence;
   string m_confluenceMode;
   
   // Gestion des alertes
   bool m_useAlerts;
   bool m_sendNotifications;
   
   datetime m_lastBarTime;  // Temps de la dernière barre traitée

public:
   //--- Constructor
   CTripleRSITrader(string symbol, int magic, ENUM_TIMEFRAMES tf,
                    double risk, int slPoints, double tpRatio,
                    bool useTrailing, bool useDynamicTrailing,
                    int tslTrigger, int tslPoints,
                    int rsiP1, int rsiP2, int rsiP3,
                    int oversold, int overbought,
                    bool useAlerts = true, bool sendNotif = false,
                    // Nouveaux paramètres de confluence
                    bool enableConfluence = true, string confluenceMode = "AUTO")
   {
      m_symbol = symbol;
      m_magic = magic;
      m_timeframe = tf;
      m_riskPercent = risk;
      m_slPoints = slPoints;
      m_tpRatio = tpRatio;
      m_useTrailingStop = useTrailing;
      m_useDynamicTrailing = useDynamicTrailing;
      m_tslTriggerPoints = tslTrigger;
      m_tslPoints = tslPoints;
      m_useAlerts = useAlerts;
      m_sendNotifications = sendNotif;
      
      // Configuration des confluences
      m_enableConfluence = enableConfluence;
      m_confluenceMode = confluenceMode;
      
      // Initialiser statistiques
      m_totalTrades = 0;
      m_winningTrades = 0;
      m_totalProfit = 0.0;
      m_lastTradeTime = 0;
      
      // Initialiser le temps de la dernière barre
      m_lastBarTime = 0;
      
      // Configurer CTrade
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(10); // 1 pip de slippage
      
      // Initialiser composants
      m_rsiCalc = new CTripleRSICalculator();
      if(!m_rsiCalc.Initialize(symbol, tf, rsiP1, rsiP2, rsiP3))
      {
         Logger::Error("Failed to initialize RSI Calculator for " + symbol);
         delete m_rsiCalc;
         m_rsiCalc = NULL;
      }
      
      m_alignDetector = new CRSIAlignmentDetector(oversold, overbought);
      m_entryValidator = new CEntryRulesValidator();
      
      // Initialiser le TSL dynamique si activé
      if(m_useDynamicTrailing)
      {
         m_commissionManager = new ForexCommissionManager();
         m_dynamicTSL = new CDynamicTrailingStop(
            m_tslPoints,           // Distance TSL
            m_tslTriggerPoints,   // Trigger par défaut
            true,                  // Activer trigger dynamique
            1.5,                   // Multiplicateur coûts (1.5x)
            50,                    // Trigger minimum en points
            10                     // Slippage
         );
         m_dynamicTSL.SetCommissionManager(m_commissionManager);
         
         Logger::Info("Dynamic Trailing Stop initialized for " + symbol);
      }
      else
      {
         m_dynamicTSL = NULL;
         m_commissionManager = NULL;
      }
      
      // Configuration des confluences
      if(m_enableConfluence)
      {
         SetupConfluenceConfiguration(m_confluenceMode, symbol);
      }
      
      Logger::Info("TripleRSI Trader created for " + symbol + " (Magic: " + IntegerToString(magic) + 
                   ") | Dynamic TSL: " + (m_useDynamicTrailing ? "ON" : "OFF") +
                   " | Confluence: " + (m_enableConfluence ? m_confluenceMode : "OFF"));
   }
   
   //--- Destructor
   ~CTripleRSITrader()
   {
      if(m_rsiCalc != NULL) 
      { 
         m_rsiCalc.Deinitialize(); 
         delete m_rsiCalc; 
         m_rsiCalc = NULL;
      }
      
      if(m_alignDetector != NULL) 
      { 
         delete m_alignDetector; 
         m_alignDetector = NULL;
      }
      
      if(m_entryValidator != NULL) 
      { 
         delete m_entryValidator; 
         m_entryValidator = NULL;
      }
      
      // Nettoyer le TSL dynamique
      if(m_dynamicTSL != NULL)
      {
         delete m_dynamicTSL;
         m_dynamicTSL = NULL;
      }
      
      if(m_commissionManager != NULL)
      {
         delete m_commissionManager;
         m_commissionManager = NULL;
      }
      
      Logger::Debug("TripleRSI Trader destroyed for " + m_symbol);
   }
   
   //--- Configuration des confluences
   void SetupConfluenceConfiguration(string confluenceMode, string symbol)
   {
      if(confluenceMode == "AUTO")
      {
         // Configuration automatique selon le symbole
         if(StringFind(symbol, "US100") >= 0 || StringFind(symbol, "US30") >= 0)
         {
            ConfluenceFilters::SetScalpingMode(symbol);
            Logger::Info("Auto-configured SCALPING mode for " + symbol);
         }
         else if(StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "GBPUSD") >= 0)
         {
            ConfluenceFilters::SetSwingMode(symbol);
            Logger::Info("Auto-configured SWING mode for " + symbol);
         }
         else
         {
            ConfluenceFilters::SetConservativeMode(symbol);
            Logger::Info("Auto-configured CONSERVATIVE mode for " + symbol);
         }
      }
      else if(confluenceMode == "SCALPING")
      {
         ConfluenceFilters::SetScalpingMode(symbol);
      }
      else if(confluenceMode == "SWING")
      {
         ConfluenceFilters::SetSwingMode(symbol);
      }
      else if(confluenceMode == "CONSERVATIVE")
      {
         ConfluenceFilters::SetConservativeMode(symbol);
      }
      else if(confluenceMode == "AGGRESSIVE")
      {
         ConfluenceFilters::SetAggressiveMode(symbol);
      }
      
      // Afficher la configuration appliquée
      ConfluenceConfig config = ConfluenceFilters::GetConfluenceConfig();
      Logger::Info("Confluence configuration for " + symbol + ":");
      Logger::Info("  Mode: " + config.presetMode);
      Logger::Info("  Min Score: " + IntegerToString(config.minConfluenceScore) + "/" + IntegerToString(config.CalculateMaxScore()));
   }
   
   //--- Fonction OnTick principale
   void OnTick()
   {
      // Vérifier que tous les composants sont initialisés
      if(m_rsiCalc == NULL || m_alignDetector == NULL || m_entryValidator == NULL)
         return;
      
      // Vérifier si c'est une nouvelle barre
      datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
      if(currentBarTime == m_lastBarTime)
         return; // Même barre, pas de traitement
      
      // Nouvelle barre détectée
      m_lastBarTime = currentBarTime;
      
      // 1. Récupérer valeurs RSI
      double rsi1, rsi2, rsi3;
      if(!m_rsiCalc.GetCurrentValues(rsi1, rsi2, rsi3))
      {
         Logger::Error("Failed to get RSI values for " + m_symbol);
         return;
      }
      
      // 2. Détecter alignement
      ENUM_RSI_SIGNAL signal = m_alignDetector.GetSignal(rsi1, rsi2, rsi3, false);
      
      // 3. Si signal valide et pas de position, valider entrée ET confluences
      if(signal == RSI_SIGNAL_BUY && !HasPosition())
      {
         double slPrice;
         int confluenceScore = 0;  // Initialiser à 0
         
         // Valider règles d'entrée de base
         if(m_entryValidator.ValidateBuyEntry(m_symbol, m_timeframe, 5, slPrice))
         {
            // Valider confluences paramétrables si activé
            bool confluenceOK = true;
            if(m_enableConfluence)
            {
               confluenceOK = ConfluenceFilters::CheckParametricConfluence(m_symbol, m_timeframe, true, confluenceScore);
            }
            
            if(confluenceOK)
            {
               OpenBuyPosition(slPrice);
               
               // Afficher informations de confluence
               if(m_enableConfluence)
               {
                  ConfluenceConfig config = ConfluenceFilters::GetConfluenceConfig();
                  Logger::Signal(true, "✅ Position BUY ouverte - Score confluence: " + 
                                 IntegerToString(confluenceScore) + "/" + IntegerToString(config.CalculateMaxScore()) + 
                                 " (Mode: " + config.presetMode + ")");
               }
            }
            else
            {
               if(m_enableConfluence)
               {
                  ConfluenceConfig config = ConfluenceFilters::GetConfluenceConfig();
                  Logger::Warning("❌ Signal BUY rejeté - Score confluence: " + 
                                 IntegerToString(confluenceScore) + "/" + IntegerToString(config.CalculateMaxScore()));
               }
            }
         }
      }
      else if(signal == RSI_SIGNAL_SELL && !HasPosition())
      {
         double slPrice;
         int confluenceScore = 0;  // Initialiser à 0
         
         // Valider règles d'entrée de base
         if(m_entryValidator.ValidateSellEntry(m_symbol, m_timeframe, 5, slPrice))
         {
            // Valider confluences paramétrables si activé
            bool confluenceOK = true;
            if(m_enableConfluence)
            {
               confluenceOK = ConfluenceFilters::CheckParametricConfluence(m_symbol, m_timeframe, false, confluenceScore);
            }
            
            if(confluenceOK)
            {
               OpenSellPosition(slPrice);
               
               // Afficher informations de confluence
               if(m_enableConfluence)
               {
                  ConfluenceConfig config = ConfluenceFilters::GetConfluenceConfig();
                  Logger::Signal(true, "✅ Position SELL ouverte - Score confluence: " + 
                                 IntegerToString(confluenceScore) + "/" + IntegerToString(config.CalculateMaxScore()) + 
                                 " (Mode: " + config.presetMode + ")");
               }
            }
            else
            {
               if(m_enableConfluence)
               {
                  ConfluenceConfig config = ConfluenceFilters::GetConfluenceConfig();
                  Logger::Warning("❌ Signal SELL rejeté - Score confluence: " + 
                                 IntegerToString(confluenceScore) + "/" + IntegerToString(config.CalculateMaxScore()));
               }
            }
         }
      }
      
      // 4. Gérer trailing stop si activé et position ouverte
      if(m_useTrailingStop && HasPosition())
      {
         ProcessTrailingStop();
      }
      
      // 5. Mettre à jour les statistiques
      UpdateStatistics();
   }
   
   //--- Ouvrir position BUY
   bool OpenBuyPosition(double slPrice)
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double lotSize = CalculateLotSize(currentPrice, slPrice);
      
      if(lotSize <= 0)
      {
         Logger::Error("Invalid lot size calculated for BUY: " + DoubleToString(lotSize, 2));
         return false;
      }
      
      double tpPrice = currentPrice + (currentPrice - slPrice) * m_tpRatio;
      
      // Valider les prix
      if(slPrice >= currentPrice)
      {
         Logger::Error("Invalid SL price for BUY: SL=" + DoubleToString(slPrice, 5) + 
                       " >= Entry=" + DoubleToString(currentPrice, 5));
         return false;
      }
      
      if(tpPrice <= currentPrice)
      {
         Logger::Error("Invalid TP price for BUY: TP=" + DoubleToString(tpPrice, 5) + 
                       " <= Entry=" + DoubleToString(currentPrice, 5));
         return false;
      }
      
      bool result = m_trade.Buy(lotSize, m_symbol, currentPrice, slPrice, tpPrice, "TripleRSI Buy");
      
      if(result)
      {
         m_lastTradeTime = TimeCurrent();
         
         // Calculer les coûts pour le TSL dynamique
         if(m_useDynamicTrailing && m_dynamicTSL != NULL)
         {
            ulong ticket = m_trade.ResultOrder();
            if(ticket > 0)
            {
               m_dynamicTSL.CalculatePositionCosts(ticket, m_symbol);
            }
         }
         
         Logger::Signal(true, "BUY opened: " + m_symbol + 
                        " | Lot=" + DoubleToString(lotSize, 2) +
                        " | Entry=" + DoubleToString(currentPrice, 5) +
                        " | SL=" + DoubleToString(slPrice, 5) +
                        " | TP=" + DoubleToString(tpPrice, 5));
         
         // Envoyer alerte si activé
         if(m_useAlerts)
         {
            SendAlert("TripleRSI BUY Signal", m_symbol + " BUY position opened");
         }
      }
      else
      {
         Logger::Error("Failed to open BUY position for " + m_symbol + 
                       " | Error: " + IntegerToString(m_trade.ResultRetcode()));
      }
      
      return result;
   }
   
   //--- Ouvrir position SELL
   bool OpenSellPosition(double slPrice)
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double lotSize = CalculateLotSize(slPrice, currentPrice);
      
      if(lotSize <= 0)
      {
         Logger::Error("Invalid lot size calculated for SELL: " + DoubleToString(lotSize, 2));
         return false;
      }
      
      double tpPrice = currentPrice - (slPrice - currentPrice) * m_tpRatio;
      
      // Valider les prix
      if(slPrice <= currentPrice)
      {
         Logger::Error("Invalid SL price for SELL: SL=" + DoubleToString(slPrice, 5) + 
                       " <= Entry=" + DoubleToString(currentPrice, 5));
         return false;
      }
      
      if(tpPrice >= currentPrice)
      {
         Logger::Error("Invalid TP price for SELL: TP=" + DoubleToString(tpPrice, 5) + 
                       " >= Entry=" + DoubleToString(currentPrice, 5));
         return false;
      }
      
      bool result = m_trade.Sell(lotSize, m_symbol, currentPrice, slPrice, tpPrice, "TripleRSI Sell");
      
      if(result)
      {
         m_lastTradeTime = TimeCurrent();
         
         // Calculer les coûts pour le TSL dynamique
         if(m_useDynamicTrailing && m_dynamicTSL != NULL)
         {
            ulong ticket = m_trade.ResultOrder();
            if(ticket > 0)
            {
               m_dynamicTSL.CalculatePositionCosts(ticket, m_symbol);
            }
         }
         
         Logger::Signal(false, "SELL opened: " + m_symbol + 
                        " | Lot=" + DoubleToString(lotSize, 2) +
                        " | Entry=" + DoubleToString(currentPrice, 5) +
                        " | SL=" + DoubleToString(slPrice, 5) +
                        " | TP=" + DoubleToString(tpPrice, 5));
         
         // Envoyer alerte si activé
         if(m_useAlerts)
         {
            SendAlert("TripleRSI SELL Signal", m_symbol + " SELL position opened");
         }
      }
      else
      {
         Logger::Error("Failed to open SELL position for " + m_symbol + 
                       " | Error: " + IntegerToString(m_trade.ResultRetcode()));
      }
      
      return result;
   }
   
   //--- Calculer la taille de lot basée sur risque
   double CalculateLotSize(double entryPrice, double slPrice)
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * m_riskPercent / 100.0;
      double slDistance = MathAbs(entryPrice - slPrice);
      
      if(slDistance <= 0)
      {
         Logger::Error("Invalid SL distance for lot calculation");
         return 0.0;
      }
      
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickValue <= 0 || tickSize <= 0)
      {
         Logger::Error("Invalid tick value or size for " + m_symbol);
         return 0.0;
      }
      
      double lotSize = (riskAmount * tickSize) / (slDistance * tickValue);
      
      // Normaliser lot size selon les contraintes du symbole
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      lotSize = MathRound(lotSize / lotStep) * lotStep;
      
      Logger::Debug("Lot calculation: Risk=" + DoubleToString(riskAmount, 2) + 
                    " | SL Distance=" + DoubleToString(slDistance, 5) + 
                    " | Lot=" + DoubleToString(lotSize, 2));
      
      return lotSize;
   }
   
   //--- Vérifier si position ouverte existe
   bool HasPosition()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_magic)
            {
               return true;
            }
         }
      }
      return false;
   }
   
   //--- Obtenir la position actuelle
   bool GetCurrentPosition(double &entryPrice, double &slPrice, double &tpPrice, 
                          double &profit, ENUM_POSITION_TYPE &type)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_magic)
            {
               entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               slPrice = PositionGetDouble(POSITION_SL);
               tpPrice = PositionGetDouble(POSITION_TP);
               profit = PositionGetDouble(POSITION_PROFIT);
               type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               return true;
            }
         }
      }
      return false;
   }
   
   //--- Traiter trailing stop
   void ProcessTrailingStop()
   {
      if(!m_useTrailingStop) return;
      
      // Utiliser le TSL dynamique si activé
      if(m_useDynamicTrailing && m_dynamicTSL != NULL)
      {
         m_dynamicTSL.ApplyTrailing(m_symbol, m_magic);
         return;
      }
      
      // Fallback vers TSL classique
      double entryPrice, slPrice, tpPrice, profit;
      ENUM_POSITION_TYPE type;
      
      if(!GetCurrentPosition(entryPrice, slPrice, tpPrice, profit, type))
         return;
      
      double currentPrice;
      double newSL = slPrice;
      bool shouldModify = false;
      
      if(type == POSITION_TYPE_BUY)
      {
         currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double profitPoints = (currentPrice - entryPrice) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         
         if(profitPoints >= m_tslTriggerPoints)
         {
            newSL = currentPrice - (m_tslPoints * SymbolInfoDouble(m_symbol, SYMBOL_POINT));
            
            if(newSL > slPrice)
            {
               shouldModify = true;
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double profitPoints = (entryPrice - currentPrice) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         
         if(profitPoints >= m_tslTriggerPoints)
         {
            newSL = currentPrice + (m_tslPoints * SymbolInfoDouble(m_symbol, SYMBOL_POINT));
            
            if(newSL < slPrice)
            {
               shouldModify = true;
            }
         }
      }
      
      if(shouldModify)
      {
         ulong ticket = PositionGetTicket(0);
         if(m_trade.PositionModify(ticket, newSL, tpPrice))
         {
            Logger::Info("Classic TSL updated for " + m_symbol + 
                        " | New SL: " + DoubleToString(newSL, 5));
         }
         else
         {
            Logger::Error("Failed to update classic TSL for " + m_symbol + 
                         " | Error: " + IntegerToString(m_trade.ResultRetcode()));
         }
      }
   }
   
   //--- Mettre à jour les statistiques
   void UpdateStatistics()
   {
      // Cette fonction peut être étendue pour calculer des statistiques en temps réel
      // Pour l'instant, on se contente de logger les positions fermées
   }
   
   //--- Envoyer alerte
   void SendAlert(string subject, string message)
   {
      if(m_useAlerts)
      {
         Alert(subject + ": " + message);
      }
      
      if(m_sendNotifications)
      {
         SendNotification(subject + ": " + message);
      }
   }
   
   //--- Obtenir informations sur le trader
   string GetTraderInfo()
   {
      string info = "=== TRIPLE RSI TRADER INFO ===\n";
      info += "Symbol: " + m_symbol + "\n";
      info += "Magic: " + IntegerToString(m_magic) + "\n";
      info += "Timeframe: " + EnumToString(m_timeframe) + "\n";
      info += "Risk: " + DoubleToString(m_riskPercent, 1) + "%\n";
      info += "TP Ratio: " + DoubleToString(m_tpRatio, 1) + "x\n";
      info += "Trailing: " + (m_useTrailingStop ? "ON" : "OFF") + "\n";
      info += "Dynamic TSL: " + (m_useDynamicTrailing ? "ON" : "OFF") + "\n";
      
      // Infos TSL dynamique
      if(m_useDynamicTrailing && m_dynamicTSL != NULL)
      {
         info += "TSL Tracked Positions: " + IntegerToString(m_dynamicTSL.GetTrackedPositionsCount()) + "\n";
         info += "TSL Cost Multiplier: " + DoubleToString(m_dynamicTSL.GetCostMultiplier(), 1) + "\n";
      }
      
      if(HasPosition())
      {
         double entryPrice, slPrice, tpPrice, profit;
         ENUM_POSITION_TYPE type;
         if(GetCurrentPosition(entryPrice, slPrice, tpPrice, profit, type))
         {
            info += "Position: " + (type == POSITION_TYPE_BUY ? "BUY" : "SELL") + "\n";
            info += "Entry: " + DoubleToString(entryPrice, 5) + "\n";
            info += "SL: " + DoubleToString(slPrice, 5) + "\n";
            info += "TP: " + DoubleToString(tpPrice, 5) + "\n";
            info += "P&L: " + DoubleToString(profit, 2) + "\n";
         }
      }
      else
      {
         info += "Position: NONE\n";
      }
      
      info += "Total Trades: " + IntegerToString(m_totalTrades) + "\n";
      info += "Win Rate: " + DoubleToString(GetWinRate(), 1) + "%\n";
      info += "Total Profit: " + DoubleToString(m_totalProfit, 2) + "\n";
      info += "================================";
      
      return info;
   }
   
   //--- Obtenir le taux de réussite
   double GetWinRate()
   {
      if(m_totalTrades <= 0) return 0.0;
      return (double)m_winningTrades / (double)m_totalTrades * 100.0;
   }
   
   //--- Obtenir le profit total
   double GetTotalProfit() const { return m_totalProfit; }
   
   //--- Obtenir le nombre total de trades
   int GetTotalTrades() const { return m_totalTrades; }
   
   //--- Obtenir le symbole
   string GetSymbol() const { return m_symbol; }
   
   //--- Obtenir le magic number
   int GetMagic() const { return m_magic; }
};
