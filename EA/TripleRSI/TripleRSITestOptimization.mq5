//+------------------------------------------------------------------+
//|                                      TripleRSITestOptimization.mq5    |
//|                                    Expert Advisor Triple RSI Test      |
//|                                      (c) 2025 - Public Domain        |
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
input string InpSymbolsList = ""; // Liste symboles (virgule) - vide = symbole courant
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
input bool InpUseEMAValidation = false;  // Validation EMA sur timeframe supérieur
input int InpEMAPeriod = 50;    // Période EMA pour validation (20-200)
input bool InpUseEMACrossFilter = false;    // Filtrer si trop de croisements EMA
input int InpEMACrossBarsCheck = 20;        // Barres à analyser pour croisements (10-50)
input int InpEMAMaxCrossings = 2;           // Max croisements tolérés (1-5)

input group "=== TRAILING STOP ==="
input bool InpUseDynamicTrailing = true;    // Activer TSL Dynamique
input double InpTSLCostMultiplier = 1.5;    // Multiplicateur coûts TSL
input int InpTSLMinTriggerPoints = 50;      // Trigger minimum TSL (points)

input group "=== TRAILING TAKE PROFIT SYSTEM ==="
input bool InpUseTrailingTP = false;                        // Activer Trailing TP
input ENUM_TRAILING_TP_MODE InpTrailingTPMode = TRAILING_TP_STEPPED; // Mode Trailing TP
input string InpTrailingTPCustomLevels = "50:0:0,100:50:50"; // Niveaux Custom (si CUSTOM mode)

input group "=== SESSION FILTERS ==="
input int Session1_Start = 8;       // Session 1 - Début
input int Session1_End = 12;        // Session 1 - Fin
input int Session2_Start = 14;      // Session 2 - Début
input int Session2_End = 18;        // Session 2 - Fin

input group "=== DAY FILTERS ==="
input bool MondayTrade = true;      // Trading Lundi
input bool TuesdayTrade = true;     // Trading Mardi
input bool WednesdayTrade = true;   // Trading Mercredi
input bool ThursdayTrade = true;    // Trading Jeudi
input bool FridayTrade = true;      // Trading Vendredi
input bool SaturdayTrade = false;   // Trading Samedi
input bool SundayTrade = false;     // Trading Dimanche

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
   
     if(InpTimeframe == PERIOD_M2 ||InpTimeframe == PERIOD_M4 ||InpTimeframe == PERIOD_M6 ||InpTimeframe == PERIOD_M12 ||InpTimeframe == PERIOD_M20 )
   {
      Logger::Error("Time Frame Ignored");
      return INIT_FAILED;
   }
   
   if(alreadyInitialized && lastSymbolsList == InpSymbolsList)
   {
      Logger::Info("⚠️ Chart timeframe changed - EA configuration unchanged");
      return(INIT_SUCCEEDED);
   }
   
   // Initialiser Logger
   Logger::Initialize((ENUM_LOG_LEVEL)InpLogLevel, "[TripleRSI-Test] ");
   Logger::Info("=== TRIPLE RSI TEST EA INITIALIZATION ===");
   
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
   chartManager = new ChartManager(0, "TripleRSI-Test");
   if(chartManager == NULL)
   {
      Logger::Error("Failed to create Chart Manager");
      return INIT_FAILED;
   }
   chartManager.SetupChart();
   chartManager.ShowStrategyName("Triple RSI Test Strategy");
   
   // Créer et initialiser TradingTimeManager
   timeManager = new TradingTimeManager(chartManager);
   if(timeManager == NULL)
   {
      Logger::Error("Failed to create Trading Time Manager");
      delete chartManager;
      chartManager = NULL;
      return INIT_FAILED;
   }
   
   
   // Construire les plages horaires à partir des sessions
   string hourRanges = BuildHourRanges();
   if(hourRanges != "")
   {
      timeManager.InitTimeRangeFilter(true, hourRanges);
      Logger::Info("✅ Time Range Filter ENABLED: " + hourRanges);
   }else{
      return INIT_FAILED;
   }
   
   // Construire les jours autorisés à partir des booléens
   string dayRanges = BuildDayRanges();
   if(dayRanges != "")
   {
      timeManager.InitDayRangeFilter(true, dayRanges);
      Logger::Info("✅ Day Range Filter ENABLED: " + dayRanges);
   }
   
   if(hourRanges == "" && dayRanges == "")
   {
      Logger::Info("ℹ️ No time/day filters enabled - trading allowed 24/7");
   }
   
   // Créer configuration
   TripleRSIConfig config;
   config.strategyName = "Triple RSI Test Strategy";
   config.strategyComment = "TripleRSI-Test";
   config.baseMagic = InpMagicNumber;
   config.symbolsList = (InpSymbolsList == "") ? Symbol() : InpSymbolsList;
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
   
   Logger::Success("✅ TRIPLE RSI TEST EA READY");
   Logger::Info("Symbols: " + InpSymbolsList);
   Logger::Info("Strategy: " + config.strategyName);
   Logger::Info("Magic: " + IntegerToString(config.baseMagic));
   Logger::Info("Risk: " + DoubleToString(config.riskPercent, 1) + "%");
   Logger::Info("Sessions: " + hourRanges);
   Logger::Info("Days: " + dayRanges);
   
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
   
   Logger::Info("=== TRIPLE RSI TEST EA STOPPED ===");
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
//| Construire les plages horaires à partir des sessions            |
//+------------------------------------------------------------------+
string BuildHourRanges()
{
   string ranges = "";
    if ( (Session1_Start > Session1_End) ||(Session2_Start > Session2_End ))
    {return ranges;}

   // Session 1
   if(Session1_Start >= 0 && Session1_End >= 0 && Session1_Start != Session1_End)
   {
      
      ranges += IntegerToString(Session1_Start) + "-" + IntegerToString(Session1_End);
   }
   
   // Session 2
   if(Session2_Start >= 0 && Session2_End >= 0 && Session2_Start != Session2_End)
   {
      if(ranges != "") ranges += ";";
      ranges += IntegerToString(Session2_Start) + "-" + IntegerToString(Session2_End);
   }
   
   return ranges;
}

//+------------------------------------------------------------------+
//| Construire les jours autorisés à partir des booléens            |
//+------------------------------------------------------------------+
string BuildDayRanges()
{
   string ranges = "";
   
   // Construire la liste des jours autorisés
   // 0=Dimanche, 1=Lundi, 2=Mardi, 3=Mercredi, 4=Jeudi, 5=Vendredi, 6=Samedi
   if(SundayTrade)    { if(ranges != "") ranges += ";"; ranges += "0"; }
   if(MondayTrade)    { if(ranges != "") ranges += ";"; ranges += "1"; }
   if(TuesdayTrade)   { if(ranges != "") ranges += ";"; ranges += "2"; }
   if(WednesdayTrade) { if(ranges != "") ranges += ";"; ranges += "3"; }
   if(ThursdayTrade)  { if(ranges != "") ranges += ";"; ranges += "4"; }
   if(FridayTrade)    { if(ranges != "") ranges += ";"; ranges += "5"; }
   if(SaturdayTrade)  { if(ranges != "") ranges += ";"; ranges += "6"; }
   
   return ranges;
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
   
   string sessionsStr = BuildHourRanges();
   string daysStr = BuildDayRanges();
   
   string slStr = "Fixed Points (" + IntegerToString(config.fixedSLPoints) + " pts)";
   if(config.slMode == SL_PERCENT_PRICE)
   {
      slStr = "Percent Price (" + DoubleToString(config.percentSLPrice, 1) + "%)";
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
      "Stop-Loss: %s\n" +
      "TP Ratio: %.1fx\n" +
      "Trailing Stop: %s\n" +
      "Sessions: %s\n" +
      "Days: %s\n" +
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
      slStr,
      config.tpRatio,
      trailingStr,
      sessionsStr,
      daysStr,
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

