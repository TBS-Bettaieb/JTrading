//+------------------------------------------------------------------+
//|                                            TripleRSI_EA.mq5       |
//|                                    Expert Advisor Triple RSI      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Paramètres d'entrée utilisateur                                  |
//+------------------------------------------------------------------+
input group "=== SYMBOLES & TIMEFRAME ==="
input string InpSymbolsList = "EURUSD,GBPUSD"; // Liste symboles (virgule)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15; // Timeframe

input group "=== RSI PARAMETERS ==="
input int InpRSIPeriod1 = 7;    // RSI Période 1 (rapide)
input int InpRSIPeriod2 = 14;   // RSI Période 2 (moyen)
input int InpRSIPeriod3 = 21;   // RSI Période 3 (lent)
input int InpOversold = 30;     // Niveau survente
input int InpOverbought = 70;   // Niveau surachat

input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent = 1.0;  // Risque par trade (%)
input int InpSLPoints = 100;        // Stop Loss (points)
input double InpTPRatio = 2.0;      // Ratio Take Profit (x SL)

input group "=== TRAILING STOP ==="
input bool InpUseTrailing = true;   // Activer Trailing Stop
input int InpTSLTrigger = 50;       // Déclenchement (points)
input int InpTSLDistance = 30;      // Distance (points)

input group "=== ALERTES ==="
input bool InpUseAlerts = true;     // Activer alertes
input bool InpSendNotif = false;    // Envoyer notifications

input group "=== ADVANCED ==="
input int InpMagicNumber = 123456;  // Magic Number
input int InpLogLevel = 3; // Niveau de log (0=None, 1=Error, 2=Warning, 3=Info, 4=Debug)

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "../Shared/Logger.mqh"
#include "Core/TripleRSIBot.mqh"

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CTripleRSIBot* bot = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Empêcher réinitialisation si juste changement de timeframe
   static bool alreadyInitialized = false;
   static string lastSymbolsList = "";
   
   if(alreadyInitialized && lastSymbolsList == InpSymbolsList)
   {
      Logger::Info("⚠️ Chart timeframe changed - EA configuration unchanged");
      return(INIT_SUCCEEDED);
   }
   
   // Initialiser Logger
   Logger::Initialize((ENUM_LOG_LEVEL)InpLogLevel, "[TripleRSI] ");
   Logger::Info("=== TRIPLE RSI EA INITIALIZATION ===");
   
   // Créer configuration
   TripleRSIConfig config;
   config.strategyName = "Triple RSI Strategy";
   config.strategyComment = "TripleRSI";
   config.baseMagic = InpMagicNumber;
   config.symbolsList = InpSymbolsList;
   config.timeframe = InpTimeframe;
   config.riskPercent = InpRiskPercent;
   config.rsiPeriod1 = InpRSIPeriod1;
   config.rsiPeriod2 = InpRSIPeriod2;
   config.rsiPeriod3 = InpRSIPeriod3;
   config.rsiOversold = InpOversold;
   config.rsiOverbought = InpOverbought;
   config.slPoints = InpSLPoints;
   config.tpRatio = InpTPRatio;
   config.useTrailingStop = InpUseTrailing;
   config.tslTriggerPoints = InpTSLTrigger;
   config.tslPoints = InpTSLDistance;
   config.barsLookback = 5;
   config.useAlerts = InpUseAlerts;
   config.sendNotifications = InpSendNotif;
   config.logLevel = (ENUM_LOG_LEVEL)InpLogLevel;
   
   // Valider la configuration
   if(!config.Validate())
   {
      Logger::Error("Configuration validation failed");
      return INIT_FAILED;
   }
   
   // Créer et initialiser le bot
   bot = new CTripleRSIBot(config);
   if(bot == NULL)
   {
      Logger::Error("Failed to create TripleRSI Bot");
      return INIT_FAILED;
   }
   
   if(!bot.Initialize())
   {
      Logger::Error("Bot initialization failed");
      delete bot;
      bot = NULL;
      return INIT_FAILED;
   }
   
   // Afficher les informations de configuration
   DisplayConfigurationInfo(config);
   
   Logger::Success("✅ TRIPLE RSI EA READY");
   Logger::Info("Symbols: " + InpSymbolsList);
   Logger::Info("Strategy: " + config.strategyName);
   Logger::Info("Magic: " + IntegerToString(config.baseMagic));
   Logger::Info("Risk: " + DoubleToString(config.riskPercent, 1) + "%");
   
   // Marquer comme initialisé
   alreadyInitialized = true;
   lastSymbolsList = InpSymbolsList;
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(bot != NULL)
   {
      bot.Deinitialize(reason);
      delete bot;
      bot = NULL;
   }
   
   Logger::Info("=== TRIPLE RSI EA STOPPED ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(bot != NULL)
   {
      bot.OnTick();
   }
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(bot != NULL)
   {
      // Forward chart events to bot if needed
      // (Bot may implement OnChartEvent if required)
   }
}

//+------------------------------------------------------------------+
//| Display configuration information                                |
//+------------------------------------------------------------------+
void DisplayConfigurationInfo(TripleRSIConfig &config)
{
   string trailingStr = "Disabled";
   if(config.useTrailingStop)
   {
      trailingStr = "ON (" + IntegerToString(config.tslTriggerPoints) + "/" + 
                    IntegerToString(config.tslPoints) + " pts)";
   }
   
   string alertsStr = "Disabled";
   if(config.useAlerts)
   {
      alertsStr = "ON";
      if(config.sendNotifications)
         alertsStr += " + Notifications";
   }
   
   string info = StringFormat(
      "=== %s ===\n" +
      "Symbols: %s\n" +
      "Magic: %d\n" +
      "Timeframe: %s\n" +
      "Risk: %.1f%%\n" +
      "RSI Periods: %d/%d/%d\n" +
      "RSI Levels: %d/%d\n" +
      "TP Ratio: %.1fx\n" +
      "Trailing Stop: %s\n" +
      "Alerts: %s\n" +
      "Log Level: %s",
      config.strategyName,
      config.symbolsList,
      config.baseMagic,
      EnumToString(config.timeframe),
      config.riskPercent,
      config.rsiPeriod1, config.rsiPeriod2, config.rsiPeriod3,
      config.rsiOversold, config.rsiOverbought,
      config.tpRatio,
      trailingStr,
      alertsStr,
      EnumToString(config.logLevel)
   );
   
   Comment(info);
   Logger::Info("=== CONFIGURATION INFO ===");
   Logger::Info(info);
   Logger::Info("==========================");
}

//+------------------------------------------------------------------+
//| Timer function (si nécessaire)                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Cette fonction peut être utilisée pour des tâches périodiques
   // comme la mise à jour des statistiques, l'envoi de rapports, etc.
}

//+------------------------------------------------------------------+
//| Trade transaction event handler                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Cette fonction peut être utilisée pour traquer les transactions
   // et mettre à jour les statistiques en temps réel
   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Une nouvelle transaction a été ajoutée
      Logger::Debug("New deal added: " + IntegerToString(trans.deal));
   }
}

//+------------------------------------------------------------------+
//| Fonction utilitaire pour obtenir les statistiques               |
//+------------------------------------------------------------------+
string GetEAStatistics()
{
   if(bot == NULL)
      return "Bot not initialized";
   
   return bot.GetGlobalStatistics();
}

//+------------------------------------------------------------------+
//| Fonction utilitaire pour obtenir les informations des traders  |
//+------------------------------------------------------------------+
string GetTradersInfo()
{
   if(bot == NULL)
      return "Bot not initialized";
   
   string info = "=== TRADERS INFO ===\n";
   int totalSymbols = bot.GetTotalSymbols();
   
   for(int i = 0; i < totalSymbols; i++)
   {
      CTripleRSITrader* trader = bot.GetTrader(i);
      if(trader != NULL)
      {
         info += trader.GetTraderInfo() + "\n\n";
      }
   }
   
   info += "======================";
   return info;
}

//+------------------------------------------------------------------+
//| Fonction utilitaire pour afficher les informations sur le graphique |
//+------------------------------------------------------------------+
void ShowDetailedInfo()
{
   if(bot == NULL)
      return;
   
   string stats = GetEAStatistics();
   string traders = GetTradersInfo();
   
   Comment(stats + "\n\n" + traders);
}
