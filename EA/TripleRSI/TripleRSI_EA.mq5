//+------------------------------------------------------------------+
//|                                            TripleRSI_EA.mq5       |
//|                                    Expert Advisor Triple RSI      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "../Shared/TradingEnums.mqh"
#include "../Shared/Logger.mqh"
#include "../Shared/ChartManager.mqh"
#include "../Shared/DayTimesFilters/TradingTimeManager.mqh"
#include "Core/TripleRSIBot.mqh"

//+------------------------------------------------------------------+
//| Paramètres d'entrée utilisateur                                  |
//+------------------------------------------------------------------+
input group "=== SYMBOLES & TIMEFRAME ==="
input string InpSymbolsList = "EURUSD,GBPUSD"; // Liste symboles (virgule)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15; // Timeframe

input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent = 1.0;  // Risque par trade (%)
input double InpTPRatio = 2.0;      // Ratio Take Profit (x SL)
input ENUM_SL_MODE InpSLMode = SL_FIXED_POINTS;       // Mode SL
input int InpFixedSLPoints = 50;                      // SL fixe en points
input double InpPercentSLPrice = 0.5;                 // SL en % du prix

input group "=== RSI PARAMETERS ==="
input int InpRSIPeriod1 = 7;    // RSI Période 1 (rapide)
input int InpRSIPeriod2 = 14;   // RSI Période 2 (moyen)
input int InpRSIPeriod3 = 21;   // RSI Période 3 (lent)
input int InpOversold = 30;     // Niveau survente
input int InpOverbought = 70;   // Niveau surachat
input bool InpUseStrictAlignment = true; // Mode Strict (3/3) ou Flexible (2/3)
input bool InpUseEMAValidation = false;     // Validation EMA sur timeframe supérieur
input int InpEMAPeriod = 50;                // Période EMA pour validation (20-200)
input bool InpUseEMACrossFilter = false;    // Filtrer si trop de croisements EMA
input int InpEMACrossBarsCheck = 20;        // Barres à analyser pour croisements (10-50)
input int InpEMAMaxCrossings = 2;           // Max croisements tolérés (1-5)

input group "=== DIVERGENCE CONFIRMATION ==="
input bool InpUseDivergenceConfirm = false;  // Activer confirmation divergence
input int InpDivConfirmBars = 8;             // Barres max attente (7-10)
input int InpDivLookbackBars = 10;           // Barres recherche pivots (5-15)
input double InpDivMinStrength = 3.0;        // Force min % divergence

input group "=== TRAILING STOP ==="
input bool InpUseDynamicTrailing = true;    // Activer TSL Dynamique
input double InpTSLCostMultiplier = 1.5;    // Multiplicateur coûts TSL
input int InpTSLMinTriggerPoints = 50;      // Trigger minimum TSL (points)

input group "=== TRAILING TAKE PROFIT SYSTEM ==="
input bool InpUseTrailingTP = false;                        // Activer Trailing TP
input ENUM_TRAILING_TP_MODE InpTrailingTPMode = TRAILING_TP_STEPPED; // Mode Trailing TP
input string InpTrailingTPCustomLevels = "50:0:0,100:50:50"; // Niveaux Custom (si CUSTOM mode)

input group "=== TIME RANGE FILTER ==="
input bool InpUseTimeFilter = false;             // Activer filtre horaire
input string InpHourRanges = "8-10;16";          // Plages horaires

input group "=== DAY RANGE FILTER ==="
input bool InpUseDayFilter = false;              // Activer filtre par jour
input string InpDayRanges = "1-5";               // Jours autorisés

input group "=== ALERTES ==="
input bool InpUseAlerts = true;     // Activer alertes
input bool InpSendNotif = false;    // Envoyer notifications

input group "=== ADVANCED ==="
input int InpMagicNumber = 123456;  // Magic Number
input int InpLogLevel = 3; // Niveau de log

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CTripleRSIBot* bot = NULL;
ChartManager* chartManager = NULL;
TradingTimeManager* timeManager = NULL;

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
   
   // Valider la configuration Trailing TP AVANT de créer le bot
   if(InpUseTrailingTP && InpTrailingTPMode == TRAILING_TP_CUSTOM)
   {
      string errorMsg;
      if(!CTrailingTPValidator::ValidateCustomLevelsString(InpTrailingTPCustomLevels, errorMsg))
      {
         Logger::Error("❌ Trailing TP validation failed:");
         Logger::Error(errorMsg);
         Alert("Configuration Trailing TP invalide!\n" + errorMsg);
         return INIT_FAILED;
      }
      
      Logger::Success("✅ Trailing TP configuration validated");
      CTrailingTPValidator::PrintParsedLevels(InpTrailingTPCustomLevels);
   }
   
   // Créer et initialiser ChartManager
   chartManager = new ChartManager(0, "TripleRSI");
   if(chartManager == NULL)
   {
      Logger::Error("Failed to create Chart Manager");
      return INIT_FAILED;
   }
   chartManager.SetupChart();
   chartManager.ShowStrategyName("Triple RSI Strategy");
   
   // Créer et initialiser TradingTimeManager
   timeManager = new TradingTimeManager(chartManager);
   if(timeManager == NULL)
   {
      Logger::Error("Failed to create Trading Time Manager");
      delete chartManager;
      chartManager = NULL;
      return INIT_FAILED;
   }
   
   // Initialiser les filtres si activés
   if(InpUseTimeFilter)
   {
      timeManager.InitTimeRangeFilter(true, InpHourRanges);
      Logger::Info("✅ Time Range Filter ENABLED: " + InpHourRanges);
   }
   
   if(InpUseDayFilter)
   {
      timeManager.InitDayRangeFilter(true, InpDayRanges);
      Logger::Info("✅ Day Range Filter ENABLED: " + InpDayRanges);
   }
   
   if(!InpUseTimeFilter && !InpUseDayFilter)
   {
      Logger::Info("ℹ️ No time/day filters enabled - trading allowed 24/7");
   }
   
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
   config.useStrictAlignment = InpUseStrictAlignment;
   config.useEMAValidation = InpUseEMAValidation;
   config.emaPeriodValidation = InpEMAPeriod;
   config.useEMACrossFilter = InpUseEMACrossFilter;
   config.emaCrossBarsCheck = InpEMACrossBarsCheck;
   config.emaMaxCrossings = InpEMAMaxCrossings;
   config.useDivergenceConfirm = InpUseDivergenceConfirm;
   config.divConfirmBars = InpDivConfirmBars;
   config.divLookbackBars = InpDivLookbackBars;
   config.divMinStrength = InpDivMinStrength;
   config.slPoints = 0; // SL géré via les nouveaux paramètres
   config.tpRatio = InpTPRatio;
   config.useDynamicTrailing = InpUseDynamicTrailing;
   config.tslCostMultiplier = InpTSLCostMultiplier;
   config.tslMinTriggerPoints = InpTSLMinTriggerPoints;
   config.slMode = InpSLMode;
   config.fixedSLPoints = InpFixedSLPoints;
   config.percentSLPrice = InpPercentSLPrice;
   config.useTrailingTP = InpUseTrailingTP;
   config.trailingTPMode = InpTrailingTPMode;
   config.trailingTPCustomLevels = InpTrailingTPCustomLevels;
   config.barsLookback = 5;
   config.useAlerts = InpUseAlerts;
   config.sendNotifications = InpSendNotif;
   config.logLevel = (ENUM_LOG_LEVEL)InpLogLevel;
   
   // Valider la configuration
   if(!config.Validate())
   {
      Logger::Error("Configuration validation failed");
      CleanupManagers();
      return INIT_FAILED;
   }
   
   // Créer et initialiser le bot
   bot = new CTripleRSIBot(config);
   if(bot == NULL)
   {
      Logger::Error("Failed to create TripleRSI Bot");
      CleanupManagers();
      return INIT_FAILED;
   }
   
   if(!bot.Initialize())
   {
      Logger::Error("Bot initialization failed");
      delete bot;
      bot = NULL;
      CleanupManagers();
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
   
   // Nettoyer les managers
   CleanupManagers();
   
   Logger::Info("=== TRIPLE RSI EA STOPPED ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier le filtre temporel AVANT de trader
   if(timeManager != NULL)
   {
      if(!timeManager.IsTradingAllowed())
      {
         // Le trading est bloqué - ne pas exécuter le bot
         return;
      }
   }
   
   // Le trading est autorisé - exécuter le bot normalement
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
//| Fonction de nettoyage des managers                              |
//+------------------------------------------------------------------+
void CleanupManagers()
{
   if(timeManager != NULL)
   {
      delete timeManager;
      timeManager = NULL;
      Logger::Success("✅ Trading Time Manager cleaned up");
   }
   
   if(chartManager != NULL)
   {
      delete chartManager;
      chartManager = NULL;
      Logger::Success("✅ Chart Manager cleaned up");
   }
}

//+------------------------------------------------------------------+
//| Display configuration information                                |
//+------------------------------------------------------------------+
void DisplayConfigurationInfo(TripleRSIConfig &config)
{
   string trailingStr = "Disabled";
   if(config.useDynamicTrailing)
   {
      trailingStr = "ON (Dynamic TSL)";
      trailingStr += " - Cost Multiplier: " + DoubleToString(config.tslCostMultiplier, 1);
   }
   
   string alertsStr = "Disabled";
   if(config.useAlerts)
   {
      alertsStr = "ON";
      if(config.sendNotifications)
         alertsStr += " + Notifications";
   }
   
   string alignmentMode = config.useStrictAlignment ? "Strict (3/3)" : "Flexible (2/3)";
   
   string info = StringFormat(
      "=== %s ===\n" +
      "Symbols: %s\n" +
      "Magic: %d\n" +
      "Timeframe: %s\n" +
      "Risk: %.1f%%\n" +
      "RSI Periods: %d/%d/%d\n" +
      "RSI Levels: %d/%d\n" +
      "RSI Alignment: %s\n" +
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
      alignmentMode,
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
