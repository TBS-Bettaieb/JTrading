//+------------------------------------------------------------------+
//|                                          TripleRSITrader.mqh     |
//|                                    Trader Triple RSI par Symbole |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
#include "../../Shared/Logger.mqh"
#include "../../Shared/TradingUtils.mqh"
#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/DynamicTrailingStop.mqh"
#include "../../Shared/ForexCommissionManager.mqh"
#include "../../Shared/TrailingTP_System.mqh"
#include "TripleRSIConfig.mqh"
#include "../Logic/RSI_Calculator.mqh"
#include "../Logic/RSI_AlignmentDetector.mqh"
#include "../Logic/EntryRulesValidator.mqh"

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
   double m_tpRatio;
   CTrade m_trade;
   
   CTripleRSICalculator* m_rsiCalc;
   CRSIAlignmentDetector* m_alignDetector;
   CEntryRulesValidator* m_entryValidator;
   
   // Trailing Stop Dynamique
   bool m_useDynamicTrailing;
   CDynamicTrailingStop* m_dynamicTSL;
   ForexCommissionManager* m_commissionManager;
   
   // Trailing Take Profit System
   bool m_useTrailingTP;
   CTrailingTP* m_trailingTP;
   ulong m_currentPositionTicket;
   
   // Configuration
   TripleRSIConfig m_config;
   
   // Statistiques
   int m_totalTrades;
   int m_winningTrades;
   double m_totalProfit;
   datetime m_lastTradeTime;
   
   
   // Gestion des alertes
   bool m_useAlerts;
   bool m_sendNotifications;
   
   datetime m_lastBarTime;  // Temps de la dernière barre traitée

public:
   //--- Constructor par défaut
   CTripleRSITrader()
   {
      // Constructeur par défaut pour éviter les erreurs de compilation
      m_symbol = "";
      m_magic = 0;
      m_timeframe = PERIOD_M15;
      m_riskPercent = 1.0;
      m_tpRatio = 2.0;
      m_useDynamicTrailing = false;
      m_useAlerts = true;
      m_sendNotifications = false;
      
      // Initialiser statistiques
      m_totalTrades = 0;
      m_winningTrades = 0;
      m_totalProfit = 0.0;
      m_lastTradeTime = 0;
      m_lastBarTime = 0;
      
      // Initialiser les pointeurs
      m_rsiCalc = NULL;
      m_alignDetector = NULL;
      m_entryValidator = NULL;
      m_dynamicTSL = NULL;
      m_commissionManager = NULL;
      
      // Trailing TP
      m_useTrailingTP = false;
      m_trailingTP = NULL;
      m_currentPositionTicket = 0;
   }
   
   //--- Constructor principal
   CTripleRSITrader(string symbol, int magic, ENUM_TIMEFRAMES tf,
                    double risk, double tpRatio,
                    bool useDynamicTrailing,
                    int rsiP1, int rsiP2, int rsiP3,
                    int oversold, int overbought,
                    bool strictAlignment = true,
                    bool useAlerts = true, bool sendNotif = false)
   {
      m_symbol = symbol;
      m_magic = magic;
      m_timeframe = tf;
      m_riskPercent = risk;
      m_tpRatio = tpRatio;
      m_useDynamicTrailing = useDynamicTrailing;
      m_useAlerts = useAlerts;
      m_sendNotifications = sendNotif;
      
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
      
      m_alignDetector = new CRSIAlignmentDetector(oversold, overbought, strictAlignment);
      m_entryValidator = new CEntryRulesValidator();
      
      // Initialiser le TSL dynamique si activé
      if(m_useDynamicTrailing)
      {
         m_commissionManager = new ForexCommissionManager();
         m_dynamicTSL = new CDynamicTrailingStop(
            30,                    // Distance TSL par défaut (points)
            50,                    // Trigger par défaut (points)
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
      
      Logger::Info("TripleRSI Trader created for " + symbol + " (Magic: " + IntegerToString(magic) + 
                   ") | Dynamic TSL: " + (m_useDynamicTrailing ? "ON" : "OFF"));
   }
   
   //--- Méthode d'initialisation pour configurer le trader
   void Initialize(TripleRSIConfig& config)
   {
      m_config = config;
      
      // Réinitialiser m_alignDetector avec les nouveaux paramètres de divergence
      if(m_alignDetector != NULL)
        {
         delete m_alignDetector;
         m_alignDetector = NULL;
        }
      
      m_alignDetector = new CRSIAlignmentDetector(
         config.rsiOversold, 
         config.rsiOverbought, 
         config.useStrictAlignment,
         config.useDivergenceConfirm,
         config.divConfirmBars,
         config.divLookbackBars,
         config.divMinStrength
      );
      
      // Enregistrer les handles RSI pour la détection de divergence
      if(config.useDivergenceConfirm && m_rsiCalc != NULL && m_alignDetector != NULL)
        {
         int handle1, handle2, handle3;
         m_rsiCalc.GetHandles(handle1, handle2, handle3);
         m_alignDetector.SetRSIHandles(handle1, handle2, handle3);
         Logger::Info("Divergence confirmation enabled for " + m_symbol);
        }
      
      // Initialiser Trailing TP si activé
      if(config.useTrailingTP)
      {
         m_useTrailingTP = true;
         m_trailingTP = new CTrailingTP(config.trailingTPMode, config.trailingTPCustomLevels);
         
         if(m_trailingTP == NULL)
         {
            Logger::Error("Failed to create Trailing TP for " + m_symbol);
            m_useTrailingTP = false;
         }
         else
         {
            Logger::Success("✅ Trailing TP System initialized for " + m_symbol + 
                           " (Mode: " + EnumToString(config.trailingTPMode) + ")");
         }
      }
      
      Logger::Info("Configuration applied to trader for " + m_symbol);
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
      
      // Nettoyer le Trailing TP
      if(m_trailingTP != NULL)
      {
         delete m_trailingTP;
         m_trailingTP = NULL;
      }
      
      Logger::Debug("TripleRSI Trader destroyed for " + m_symbol);
   }
   
   
   //--- Fonction OnTick principale
   void OnTick()
   {
      // Vérifier que tous les composants sont initialisés
      if(m_rsiCalc == NULL || m_alignDetector == NULL || m_entryValidator == NULL)
         return;
      
      // Gérer les positions ouvertes (trailing stop, trailing TP, etc.)
      ManageOpenPositions();
      
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
      
      // 2. Détecter alignement avec validation EMA optionnelle et divergence
      ENUM_RSI_SIGNAL signal;
      
      if(m_config.useDivergenceConfirm)
        {
         // Utiliser GetSignalWithDivergence si la divergence est activée
         int currentBar = Bars(m_symbol, m_timeframe);
         signal = m_alignDetector.GetSignalWithDivergence(
            rsi1, rsi2, rsi3,
            m_symbol,                           // symbol
            m_timeframe,                        // tf
            currentBar,                         // currentBar
            false,                              // allowRepeat
            m_config.useEMAValidation,          // validateWithEMA
            m_config.emaPeriodValidation,       // emaPeriod
            m_config.useEMACrossFilter,         // useCrossFilter
            m_config.emaCrossBarsCheck,         // crossBarsCheck
            m_config.emaMaxCrossings            // maxCrossings
         );
        }
      else
        {
         // Utiliser GetSignal classique
         signal = m_alignDetector.GetSignal(
            rsi1, rsi2, rsi3, 
            false,                              // allowRepeat
            m_config.useEMAValidation,          // validateWithEMA
            m_symbol,                           // symbol
            m_timeframe,                        // currentTF
            m_config.emaPeriodValidation,       // emaPeriod
            m_config.useEMACrossFilter,         // useCrossFilter
            m_config.emaCrossBarsCheck,         // crossBarsCheck
            m_config.emaMaxCrossings            // maxCrossings
         );
        }
      
      // 3. Si signal valide et pas de position, valider entrée
      if(signal == RSI_SIGNAL_BUY)
      {
         // Valider règles d'entrée de base uniquement
         if(m_entryValidator.ValidateBuyEntry(m_symbol, m_timeframe, 5))
         {
            OpenBuyPosition();
            Logger::Signal(true, "✅ Position BUY ouverte");
         }
      }
      else if(signal == RSI_SIGNAL_SELL)
      {
         // Valider règles d'entrée de base uniquement
         if(m_entryValidator.ValidateSellEntry(m_symbol, m_timeframe, 5))
         {
            OpenSellPosition();
            Logger::Signal(false, "✅ Position SELL ouverte");
         }
      }
      
      // 4. Mettre à jour les statistiques
      UpdateStatistics();
   }
   
   
   //--- Calculer le Stop-Loss selon le mode choisi
   double CalculateStopLoss(bool isBuy, double entryPrice)
   {
      if(m_config.slMode == SL_FIXED_POINTS)
      {
         // Mode SL fixe en points
         double pointValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         double slDistance = m_config.fixedSLPoints * pointValue;
         
         if(isBuy)
            return entryPrice - slDistance;  // SL en dessous du prix d'achat
         else
            return entryPrice + slDistance;  // SL au-dessus du prix de vente
      }
      else if(m_config.slMode == SL_PERCENT_PRICE)
      {
         // Mode SL en pourcentage du prix
         double slPercent = m_config.percentSLPrice / 100.0;
         double slDistance = entryPrice * slPercent;
         
         if(isBuy)
            return entryPrice - slDistance;  // SL en dessous du prix d'achat
         else
            return entryPrice + slDistance;  // SL au-dessus du prix de vente
      }
      
      Logger::Error("❌ Invalid SL mode");
      return -1;
   }
   
   //--- Ouvrir position BUY
   bool OpenBuyPosition()
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      // Calculer le SL selon le mode choisi
      double slPrice = CalculateStopLoss(true, currentPrice);
      
      // Vérifier que le SL est valide
      if(slPrice <= 0 || slPrice >= currentPrice)
      {
         Logger::Error("❌ Invalid or missing SL for BUY - cannot open trade");
         return false;
      }
      
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
         ulong ticket = m_trade.ResultOrder();
         
         // Stocker le ticket pour le trailing TP
         if(ticket > 0)
         {
            m_currentPositionTicket = ticket;
            
            // Calculer les coûts pour le TSL dynamique
            if(m_useDynamicTrailing && m_dynamicTSL != NULL)
            {
               m_dynamicTSL.CalculatePositionCosts(ticket, m_symbol);
            }
            
            // Initialiser le Trailing TP
            if(m_useTrailingTP && m_trailingTP != NULL)
            {
               if(m_trailingTP.Initialize(currentPrice, slPrice, tpPrice, true))
               {
                  Logger::Info("✅ Trailing TP initialized for BUY position #" + 
                             IntegerToString(ticket));
               }
               else
               {
                  Logger::Warning("Failed to initialize Trailing TP for BUY position");
               }
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
   bool OpenSellPosition()
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Calculer le SL selon le mode choisi
      double slPrice = CalculateStopLoss(false, currentPrice);
      
      // Vérifier que le SL est valide
      if(slPrice <= 0 || slPrice <= currentPrice)
      {
         Logger::Error("❌ Invalid or missing SL for SELL - cannot open trade");
         return false;
      }
      
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
         ulong ticket = m_trade.ResultOrder();
         
         // Stocker le ticket pour le trailing TP
         if(ticket > 0)
         {
            m_currentPositionTicket = ticket;
            
            // Calculer les coûts pour le TSL dynamique
            if(m_useDynamicTrailing && m_dynamicTSL != NULL)
            {
               m_dynamicTSL.CalculatePositionCosts(ticket, m_symbol);
            }
            
            // Initialiser le Trailing TP
            if(m_useTrailingTP && m_trailingTP != NULL)
            {
               if(m_trailingTP.Initialize(currentPrice, slPrice, tpPrice, false))
               {
                  Logger::Info("✅ Trailing TP initialized for SELL position #" + 
                             IntegerToString(ticket));
               }
               else
               {
                  Logger::Warning("Failed to initialize Trailing TP for SELL position");
               }
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
   
   //--- Traiter trailing stop (UNIQUEMENT dynamique)
   void ProcessTrailingStop()
   {
      // Utiliser UNIQUEMENT le TSL dynamique
      if(m_useDynamicTrailing && m_dynamicTSL != NULL)
      {
         m_dynamicTSL.ApplyTrailing(m_symbol, m_magic);
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
      info += "Dynamic TSL: " + (m_useDynamicTrailing ? "ON" : "OFF") + "\n";
      
      // Infos TSL dynamique
      if(m_useDynamicTrailing && m_dynamicTSL != NULL)
      {
         info += "TSL Tracked Positions: " + IntegerToString(m_dynamicTSL.GetTrackedPositionsCount()) + "\n";
         info += "TSL Cost Multiplier: " + DoubleToString(m_dynamicTSL.GetCostMultiplier(), 1) + "\n";
      }
      
      // Infos Trailing TP
      if(m_useTrailingTP && m_trailingTP != NULL)
      {
         info += "Trailing TP: " + EnumToString(m_trailingTP.GetMode()) + "\n";
         if(m_currentPositionTicket > 0)
         {
            info += "Trailing TP Status: " + m_trailingTP.GetStatusInfo() + "\n";
         }
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
   
   //--- Gérer les positions ouvertes (Trailing Stop, Trailing TP, etc.)
   void ManageOpenPositions()
   {
      // Vérifier s'il y a une position ouverte pour ce symbole
      if(!HasPosition())
      {
         m_currentPositionTicket = 0;  // Pas de position
         return;
      }
      
      // Appliquer le Trailing Stop dynamique si activé
      if(m_useDynamicTrailing && m_dynamicTSL != NULL)
      {
         m_dynamicTSL.ApplyTrailing(m_symbol, m_magic);
      }
      
      // Appliquer le Trailing TP si activé
      if(m_useTrailingTP && m_trailingTP != NULL && m_currentPositionTicket > 0)
      {
         ApplyTrailingTP();
      }
   }
   
   //--- Appliquer le Trailing Take Profit
   void ApplyTrailingTP()
   {
      if(!PositionSelectByTicket(m_currentPositionTicket))
      {
         m_currentPositionTicket = 0;  // Position fermée
         return;
      }
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isBuy = (posType == POSITION_TYPE_BUY);
      
      double currentPrice = isBuy ? 
         SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
         SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      double newSL = 0, newTP = 0;
      
      // Mettre à jour le trailing TP
      if(m_trailingTP.Update(currentPrice, newSL, newTP))
      {
         // Le système suggère de modifier SL/TP
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         
         // Vérifier si les valeurs ont changé (avec tolérance d'un point)
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         bool slChanged = (MathAbs(newSL - currentSL) > point);
         bool tpChanged = (MathAbs(newTP - currentTP) > point);
         
         if(slChanged || tpChanged)
         {
            if(m_trade.PositionModify(m_currentPositionTicket, newSL, newTP))
            {
               Logger::Info(StringFormat(
                  "✅ Trailing TP applied on %s | New SL: %.5f | New TP: %.5f | %s",
                  m_symbol, newSL, newTP, m_trailingTP.GetStatusInfo()
               ));
            }
            else
            {
               Logger::Warning("Failed to modify position with Trailing TP: " + 
                             IntegerToString(GetLastError()));
            }
         }
      }
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
