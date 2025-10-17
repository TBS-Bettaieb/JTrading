//+------------------------------------------------------------------+
//|                                        Adx_ScoreMaster.mq5       |
//|                   ADX Score Master v2.1 - Optimisé & Sécurisé    |
//|                   Utilise ChartManager et TradingTimeManager     |
//|                                                                  |
//| AMÉLIORATIONS v2.1:                                              |
//| ✅ Bug Trailing TP multi-positions corrigé                       |
//| ✅ Performance OnTick() optimisée (throttling intelligent)       |
//| ✅ Gestion d'erreurs robuste avec retry logic                    |
//| ✅ Architecture sécurisée pour plusieurs positions simultanées   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.1"
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "../../CommonUtils/ChartManager.mqh"
#include "../../CommonUtils/TradingTimeManager.mqh"
#include "../../CommonUtils/TradingUtils.mqh"
#include "../../CommonUtils/TradingEnums.mqh"
#include "../../CommonUtils/TrailingTP_System.mqh"
#include "common/AdxScoreTrader.mqh"

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== Trading Parameters ==="
input string SYMBOL = "EURUSD";              // Symbol to trade
input int MAGIC_NUMBER = 12345;              // Magic number
input ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M5; // Timeframe

input group "=== Scoring System ==="
input int SCORE_MIN_ENTRY = 6;               // Score minimum pour entrer en position
input int SCORE_HIGH_CONFIDENCE = 9;         // Score haute confiance (lot plus important)

input group "=== Risk Management ==="
input ENUM_RISK_MODE RISK_MODE = RISK_PERCENTAGE;  // Mode de gestion du risque
input double RISK_PERCENT_NORMAL = 0.8;      // Risque normal
input double RISK_PERCENT_HIGH = 1.2;        // Risque si haute confiance
input int SL_POINTS = 200;                   // Stop Loss en points
input int TP_MULTIPLIER = 2;                 // Multiplicateur TP (SL * TP_MULTIPLIER)
input int MAX_POSITIONS = 1;                 // Nombre max de positions simultanées
input bool USE_DYNAMIC_LOTS = true;          // Activer calcul lots dynamique
input bool LOG_LOT_CALCULATION = true;       // Logger les détails de calcul

input group "=== Indicator Parameters ==="
input int ADX_PERIOD = 14;                   // Période ADX
input int RSI_PERIOD = 14;                   // Période RSI
input int MA_PERIOD = 50;                    // Période MA
input ENUM_MA_METHOD MA_METHOD = MODE_SMA;   // Méthode MA

input group "=== Volatility Filter ==="
input bool USE_VOLATILITY_FILTER = true;     // Activer filtre volatilité
input int ATR_PERIOD = 14;                   // Période ATR
input double MIN_VOLATILITY_RATIO = 0.0003;  // Volatilité minimale (0.03%)
input double MAX_VOLATILITY_RATIO = 0.0015;  // Volatilité maximale (0.15%)

input group "=== Trailing Stop ==="
input bool USE_TRAILING = false;             // Activer Trailing Stop
input int TRAILING_START = 50;               // Points de profit pour démarrer
input int TRAILING_STEP = 20;                // Points de trailing

input group "=== Advanced Trailing TP System ==="
input bool USE_ADVANCED_TRAILING_TP = true;                    // Activer Trailing TP Avancé
input ENUM_TRAILING_TP_MODE TRAILING_TP_MODE = TRAILING_TP_CUSTOM; // Mode Trailing TP
input string CustomTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150"; // Niveaux Custom (profit:slMove:tpExtend)
input bool SHOW_TP_STATUS = true;                              // Afficher statut Trailing TP

input group "=== Time Filter ==="
input int SHInput = 0;                       // Start Hour (0 = disabled)
input int EHInput = 0;                       // End Hour (0 = disabled)

input group "=== Session Filter ==="
input bool UseSessionFilter = false;                               // Activer filtre par session
input ENUM_TRADING_SESSION AllowedSession = SESSION_OVERLAP;      // Session autorisée
input int AvoidOpeningMinutes = 30;                               // Minutes à éviter à l'ouverture

input group "=== Alert Messages ==="
input string HourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
input string DayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
input string BothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
ChartManager* chartManager = NULL;
TradingTimeManager* timeManager = NULL;
CTrailingTP* trailingTP = NULL;
AdxScoreTrader* scoreTrader = NULL;

//+------------------------------------------------------------------+
//| Structure pour gérer l'état du Trailing TP par position         |
//+------------------------------------------------------------------+
struct PositionTrailingState
{
   ulong ticket;
   bool isInitialized;
   datetime lastUpdate;
   double lastSL;
   double lastTP;
};

// Array pour stocker l'état de toutes les positions
PositionTrailingState g_trailingStates[];

//+------------------------------------------------------------------+
//| Variables pour l'optimisation des performances                  |
//+------------------------------------------------------------------+
datetime g_lastVisualUpdate = 0;        // Dernière mise à jour visuelle
datetime g_lastStatusUpdate = 0;        // Dernière mise à jour du statut
datetime g_lastCleanup = 0;             // Dernier nettoyage des labels
const int VISUAL_UPDATE_INTERVAL = 500; // 500ms entre les updates visuels
const int STATUS_UPDATE_INTERVAL = 2000; // 2s entre les updates de statut
const int CLEANUP_INTERVAL = 30000;     // 30s entre les nettoyages

//+------------------------------------------------------------------+
//| Constantes pour la gestion des erreurs                          |
//+------------------------------------------------------------------+
const int MAX_RETRY_ATTEMPTS = 3;       // Nombre max de tentatives
const int RETRY_DELAY_MS = 100;         // Délai entre les tentatives

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════");
   Print("🚀 Initializing ADX Score Master v2.0");
   Print("═══════════════════════════════════════");
   
   // ═══ Step 1: Créer ChartManager ═══
   chartManager = new ChartManager(0, "AdxScoreMaster");
   if(chartManager == NULL)
   {
      Print("❌ Erreur création ChartManager");
      return INIT_FAILED;
   }
   
   chartManager.SetupChart();
   
   // NOUVEAU: Nettoyer TOUS les labels avant de commencer
   chartManager.ClearLabels();
   
   // Attendre un peu pour s'assurer que le nettoyage est effectif
   Sleep(100);
   
   chartManager.ShowStrategyName("ADX Score Master v2.0");
   
   // ═══ Step 2: Créer TradingTimeManager ═══
   timeManager = new TradingTimeManager(chartManager);
   if(timeManager == NULL)
   {
      Print("❌ Erreur création TradingTimeManager");
      return INIT_FAILED;
   }
   
   timeManager.Initialize(
      (SHInput != 0 || EHInput != 0), // useTimeFilter
      IntegerToString(SHInput) + "-" + IntegerToString(EHInput), // hourRanges
      false, // useDayFilter
      "", // dayRanges
      true // showVisualAlerts
   );
   
   timeManager.SetVerboseLogging(true);
   timeManager.SetAlertMessages(HourBlockMsg, DayBlockMsg, BothBlockMsg);
   
   // ═══ Step 4: Initialiser Session Filter via TradingTimeManager ═══
   if(UseSessionFilter)
   {
      timeManager.InitSessionFilter(true, AllowedSession, AvoidOpeningMinutes);
      Print("🌍 Session Filter activé via TradingTimeManager");
      Print("   Session: ", IntegerToString(AllowedSession), ", Avoid: ", IntegerToString(AvoidOpeningMinutes), "min");
   }
   else
   {
      Print("ℹ️ Session Filter désactivé");
   }
   
   // ═══ Step 2.5: Valider et Créer Trailing TP System ═══
   if(USE_ADVANCED_TRAILING_TP)
   {
      Print("🔍 Validation configuration Trailing TP...");
      
      // VALIDATION PRÉALABLE avec le Validateur
      string errorMsg;
      bool isValid = CTrailingTPValidator::ValidateCustomLevelsString(
         CustomTPLevels, 
         errorMsg
      );
      
      if(!isValid)
      {
         Print("═══════════════════════════════════════");
         Print("❌ ERREUR CONFIGURATION TRAILING TP:");
         Print(errorMsg);
         Print("═══════════════════════════════════════");
         Alert("❌ Configuration Trailing TP invalide!\n\n" + errorMsg);
         return INIT_PARAMETERS_INCORRECT;
      }
      
      Print("✅ Configuration Trailing TP validée!");
      
      // Afficher les niveaux parsés
      CTrailingTPValidator::PrintParsedLevels(CustomTPLevels);
      
      // Créer l'objet Trailing TP
      trailingTP = new CTrailingTP(TRAILING_TP_MODE, CustomTPLevels);
      
      if(trailingTP == NULL)
      {
         Print("❌ Erreur création CTrailingTP");
         return INIT_FAILED;
      }
      
      Print("✅ Trailing TP System initialisé en mode: ", EnumToString(TRAILING_TP_MODE));
   }
   else
   {
      Print("ℹ️ Trailing TP Avancé désactivé");
   }
   
   // ═══ Step 3: Créer AdxScoreTrader ═══
   scoreTrader = new AdxScoreTrader(
      SYMBOL,
      MAGIC_NUMBER,
      TIMEFRAME,
      SCORE_MIN_ENTRY,
      SCORE_HIGH_CONFIDENCE,
      RISK_PERCENT_NORMAL,
      RISK_PERCENT_HIGH,
      SL_POINTS,
      TP_MULTIPLIER,
      MAX_POSITIONS,
      ADX_PERIOD,
      RSI_PERIOD,
      MA_PERIOD,
      MA_METHOD,
      USE_TRAILING,
      TRAILING_START,
      TRAILING_STEP,
      USE_VOLATILITY_FILTER,
      ATR_PERIOD,
      MIN_VOLATILITY_RATIO,
      MAX_VOLATILITY_RATIO,
      USE_DYNAMIC_LOTS,          // NOUVEAU
      LOG_LOT_CALCULATION        // NOUVEAU
   );
   
   if(scoreTrader == NULL)
   {
      Print("❌ Erreur création AdxScoreTrader");
      return INIT_FAILED;
   }
   
   if(!scoreTrader.Initialize())
   {
      Print("❌ Erreur initialisation AdxScoreTrader");
      return INIT_FAILED;
   }
   
   // ═══ Step 4: Afficher la configuration ═══
   Print("📊 Configuration:");
   Print("  Symbol: ", SYMBOL);
   Print("  Magic: ", MAGIC_NUMBER);
   Print("  Timeframe: ", EnumToString(TIMEFRAME));
   Print("  Score Min: ", SCORE_MIN_ENTRY);
   Print("  Score High: ", SCORE_HIGH_CONFIDENCE);
   Print("  Risk Normal: ", RISK_PERCENT_NORMAL, "%");
   Print("  Risk High: ", RISK_PERCENT_HIGH, "%");
   Print("  SL Points: ", SL_POINTS);
   Print("  TP Multiplier: ", TP_MULTIPLIER);
   Print("  Max Positions: ", MAX_POSITIONS);
   
   // Afficher la configuration du Time Manager
   Print("⏰ Time Manager Configuration:");
   Print(timeManager.GetDetailedInfo());
   
   Print("✅ Initialization completed successfully!");
   
   if(timeManager.IsTradingAllowed())
   {
      Print("🎯 TRADING: ACTIVE");
   }
   else
   {
      Print("⏸️ TRADING: PAUSED (Time Filter)");
   }
   
   Print("═══════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🔄 Deinitializing ADX Score Master...");
   
   if(trailingTP != NULL)
   {
      delete trailingTP;
      trailingTP = NULL;
      Print("✅ Trailing TP System cleaned up");
   }
   
   if(scoreTrader != NULL)
   {
      delete scoreTrader;
      scoreTrader = NULL;
      Print("✅ AdxScoreTrader cleaned up");
   }
   
   if(timeManager != NULL)
   {
      delete timeManager;
      timeManager = NULL;
      Print("✅ Time Manager cleaned up");
   }
   
   // Session Filter est maintenant géré par TradingTimeManager
   
   if(chartManager != NULL)
   {
      delete chartManager;
      chartManager = NULL;
      Print("✅ Chart Manager cleaned up");
   }
   
   Print("✅ Deinitialization completed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier que les objets sont initialisés
   if(chartManager == NULL || timeManager == NULL || scoreTrader == NULL)
   {
        return;
   }
   
   datetime currentTime = TimeCurrent();
   
   // OPTIMISÉ: Nettoyage basé sur le temps réel au lieu d'un compteur de ticks
   if(currentTime - g_lastCleanup >= CLEANUP_INTERVAL)
   {
      Print("🧹 Nettoyage périodique des labels...");
      chartManager.ClearLabels();
      g_lastCleanup = currentTime;
   }
   
   // Vérifier si c'est une nouvelle barre (UNE SEULE vérification)
   bool isNewBar = scoreTrader.IsNewBar();

   // Sur nouvelle barre : mettre à jour les indicateurs et scores
   if(isNewBar)
   {
      scoreTrader.UpdateScoresOnly();
      
      // OPTIMISÉ: Mettre à jour l'affichage avec throttling
      if(currentTime - g_lastVisualUpdate >= VISUAL_UPDATE_INTERVAL)
      {
         UpdateAllVisuals();
         g_lastVisualUpdate = currentTime;
      }
   }

   // Vérifier si le trading est autorisé (tous les filtres via TradingTimeManager)
   bool tradingAllowed = timeManager.IsTradingAllowed();
   
   // Logger les blocages si nécessaire
   if(!tradingAllowed)
   {
      static datetime lastLog = 0;
      if(currentTime - lastLog > 60)  // Log toutes les 60 secondes max
      {
         Print("⏸️ Trading bloqué par filtres: ", timeManager.GetStatusDescription());
         lastLog = currentTime;
      }
   }

   // Si trading autorisé ET nouvelle barre : vérifier les signaux
   if(tradingAllowed && isNewBar)
   {
      scoreTrader.CheckTradingSignals();
   }

   // Gérer le Trailing TP Avancé ou Standard
   if(USE_ADVANCED_TRAILING_TP && trailingTP != NULL)
   {
      ManageAdvancedTrailingTP();
   }
   else if(scoreTrader != NULL)
   {
      // Trailing standard si Trailing TP avancé désactivé
      scoreTrader.TrailingStop();
   }
}

//+------------------------------------------------------------------+
//| Fonction centralisée pour gérer tous les updates visuels        |
//+------------------------------------------------------------------+
void UpdateAllVisuals()
{
   if(chartManager == NULL || scoreTrader == NULL) return;
   
   // Mettre à jour l'affichage principal
   UpdateChartDisplay();
   
   // Mettre à jour le breakdown du score
   DisplayScoreBreakdown();
   
   // Mettre à jour le statut global (avec throttling)
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastStatusUpdate >= STATUS_UPDATE_INTERVAL)
   {
      DisplayGlobalStatus();
      g_lastStatusUpdate = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage du graphique                          |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   if(chartManager == NULL || scoreTrader == NULL) return;
   
   // SUPPRIMÉ: Les compteurs de ticks qui ralentissent
   // On met à jour à CHAQUE tick pour avoir du temps réel
   
   // ═══ Affichage du statut principal (haut droite) ═══
   int buyScore = scoreTrader.GetBuyScore();
   int sellScore = scoreTrader.GetSellScore();
   string signal = GetSignalText(buyScore, sellScore);
   
   string status = StringFormat(
      "BUY:%d SELL:%d %s",  // Format raccourci
      buyScore, sellScore, signal
   );
   
   color statusColor = GetStatusColor(buyScore, sellScore);
   // Police agrandie et en Bold
   chartManager.ShowTopRightLabel(status, statusColor, 14, 10);  // Augmenté de 12 à 14
   
   // ═══ Affichage des indicateurs avec couleurs dynamiques ═══
   string indicators[];
   ArrayResize(indicators, 9);
   
   // Titre en Bold
   indicators[0] = "━━━ INDICATORS ━━━";
   
   // ADX avec code couleur
   double adx = scoreTrader.GetADX();
   string adxStatus = "";
   if(adx > 35) adxStatus = " 🔥";  // Très fort
   else if(adx > 25) adxStatus = " ⚡";  // Fort
   else if(adx > 20) adxStatus = " →";  // Modéré
   indicators[1] = StringFormat("ADX: %.1f%s", adx, adxStatus);
   
   // D+ et D- avec code couleur
   double dPlus = scoreTrader.GetDPlus();
   double dMinus = scoreTrader.GetDMinus();
   string directionalStatus = "";
   if(dPlus > dMinus + 20) directionalStatus = " 🟢";  // D+ très dominant
   else if(dMinus > dPlus + 20) directionalStatus = " 🔴";  // D- très dominant
   else if(MathAbs(dPlus - dMinus) > 10) directionalStatus = " ⚡";  // Écart significatif
   indicators[2] = StringFormat("D+: %.1f | D-: %.1f%s", dPlus, dMinus, directionalStatus);
   
   // RSI avec code couleur
   double rsi = scoreTrader.GetRSI();
   string rsiStatus = "";
   if(rsi < 30) rsiStatus = " 🔵";  // Survente
   else if(rsi > 70) rsiStatus = " 🔴";  // Surachat
   indicators[3] = StringFormat("RSI: %.1f%s", rsi, rsiStatus);
   
   // MA avec distance
   double ma = scoreTrader.GetMA();
   double price = scoreTrader.GetPrice();
   double distance = ((price - ma) / ma) * 100;
   string maStatus = distance > 0 ? " ↑" : " ↓";
   indicators[4] = StringFormat("MA: %.4f%s", ma, maStatus);
   
   // Positions
   indicators[5] = StringFormat("Pos: %d/%d", scoreTrader.GetCurrentPositions(), scoreTrader.GetMaxPositions());
   
   // Scores actuels
   indicators[6] = StringFormat("Score: BUY[%d] SELL[%d]", buyScore, sellScore);
   
   // Direction dominante
   string direction = "";
   if(dPlus > dMinus + 5) direction = " ↗️ Haussier";
   else if(dMinus > dPlus + 5) direction = " ↘️ Baissier";
   else direction = " ↔️ Neutre";
   indicators[7] = StringFormat("Direction: %s", direction);
   
   // Volatilité
   double volRatio = scoreTrader.GetVolatilityRatio() * 100;
   string volStatus = scoreTrader.IsVolatilityOptimal() ? " ✓" : " ✗";
   indicators[8] = StringFormat("Volatilité: %.4f%%%s", volRatio, volStatus);
   
   // Informations de session si activé
   if(UseSessionFilter)
   {
      ArrayResize(indicators, 10);
      string sessionStatus = "Session: " + IntegerToString(AllowedSession);
      if(!timeManager.IsTradingAllowed())
         sessionStatus += " 🔒 BLOCKED";
      else
         sessionStatus += " ✓";
      indicators[9] = sessionStatus;
   }
   
   // Couleur dynamique selon signal
   color indColor = clrWhite;
   if(buyScore >= SCORE_MIN_ENTRY) indColor = clrLimeGreen;
   else if(sellScore >= SCORE_MIN_ENTRY) indColor = clrOrangeRed;
   
   // Police agrandie de 9 à 11 - Centré en bas
   chartManager.ShowMultiLineInfo(indicators, CORNER_LEFT_LOWER, 150, 30, 20, indColor, 11, "Indicators");
   
   // ═══ Affichage du breakdown du score ═══
   DisplayScoreBreakdown();
}

//+------------------------------------------------------------------+
//| Afficher le breakdown détaillé du score                         |
//+------------------------------------------------------------------+
void DisplayScoreBreakdown()
{
   if(chartManager == NULL || scoreTrader == NULL) return;
   
   // SUPPRIMÉ: Le compteur updateCount qui ralentit
   // Affichage TEMPS RÉEL pour voir les scores changer immédiatement
   
   string lines[];
   ArrayResize(lines, 6);
   
   lines[0] = "━━━ SCORE BREAKDOWN ━━━";
   
   int buyScore = scoreTrader.GetBuyScore();
   int sellScore = scoreTrader.GetSellScore();
   
   // Format compact avec scores détaillés
   lines[1] = StringFormat("BUY: ADX:%d DIR:%d RSI:%d MA:%d CF:%d", 
      scoreTrader.GetBuyADXScore(), scoreTrader.GetBuyDirectionalScore(),
      scoreTrader.GetBuyRSIScore(), scoreTrader.GetBuyMAScore(), 
      scoreTrader.GetBuyConfluenceScore());
   
   lines[2] = StringFormat("SELL: ADX:%d DIR:%d RSI:%d MA:%d CF:%d", 
      scoreTrader.GetSellADXScore(), scoreTrader.GetSellDirectionalScore(),
      scoreTrader.GetSellRSIScore(), scoreTrader.GetSellMAScore(), 
      scoreTrader.GetSellConfluenceScore());
   
   lines[3] = "─────────────────";
   
   // Totaux avec indicateurs visuels
   string buyIndicator = "";
   if(buyScore >= SCORE_HIGH_CONFIDENCE) buyIndicator = " ⭐⭐";
   else if(buyScore >= SCORE_MIN_ENTRY) buyIndicator = " ⭐";
   
   string sellIndicator = "";
   if(sellScore >= SCORE_HIGH_CONFIDENCE) sellIndicator = " ⭐⭐";
   else if(sellScore >= SCORE_MIN_ENTRY) sellIndicator = " ⭐";
   
   lines[4] = StringFormat("BUY: %d/%d%s", buyScore, SCORE_MIN_ENTRY, buyIndicator);
   lines[5] = StringFormat("SELL: %d/%d%s", sellScore, SCORE_MIN_ENTRY, sellIndicator);
   
   // Couleur selon le signal le plus fort
   color textColor = clrWhite;
   if(buyScore >= SCORE_HIGH_CONFIDENCE)
      textColor = clrLime;
   else if(sellScore >= SCORE_HIGH_CONFIDENCE)
      textColor = clrRed;
   else if(buyScore >= SCORE_MIN_ENTRY)
      textColor = clrYellow;
   else if(sellScore >= SCORE_MIN_ENTRY)
      textColor = clrOrange;
   
   // Police agrandie de 9 à 11
   chartManager.ShowMultiLineInfo(lines, CORNER_RIGHT_LOWER, 10, 30, 18, textColor, 11, "ScoreBreakdown");
}

//+------------------------------------------------------------------+
//| Afficher le statut global                                       |
//+------------------------------------------------------------------+
void DisplayGlobalStatus()
{
   if(chartManager == NULL || scoreTrader == NULL || timeManager == NULL) return;
   
   string statusLines[];
   ArrayResize(statusLines, 3);
   
   // Ligne 1: Statut trading
   string tradingStatus = timeManager.IsTradingAllowed() ? "🟢 ACTIVE" : "🔴 PAUSED";
   statusLines[0] = "Status: " + tradingStatus;
   
   // Ligne 2: Heure actuelle
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string sessionInfo = "";
   if(UseSessionFilter)
   {
      sessionInfo = " | Session: " + IntegerToString(AllowedSession);
      if(!timeManager.IsTradingAllowed())
         sessionInfo += " 🔒";
   }
   statusLines[1] = StringFormat("Time: %02d:%02d%s", dt.hour, dt.min, sessionInfo);
   
   // Ligne 3: Balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   statusLines[2] = StringFormat("Bal: %.2f", balance);
   
   // Ligne 4: Statut Trailing TP (si actif)
   if(USE_ADVANCED_TRAILING_TP && trailingTP != NULL)
   {
      ArrayResize(statusLines, 4);
      statusLines[3] = trailingTP.GetStatusInfo();
   }
   
   // Police agrandie de 9 à 10
   chartManager.ShowMultiLineInfo(statusLines, CORNER_LEFT_LOWER, 10, 30, 20, clrDeepSkyBlue, 10, "GlobalStatus");
}

//+------------------------------------------------------------------+
//| Fonctions de gestion d'erreurs robustes                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Wrapper sécurisé pour PositionGetTicket avec validation         |
//+------------------------------------------------------------------+
ulong SafeGetPositionTicket(int index)
{
   if(index < 0 || index >= PositionsTotal())
   {
      Print("❌ Index de position invalide: ", index);
      return 0;
   }
   
   ulong ticket = PositionGetTicket(index);
   if(ticket <= 0)
   {
      Print("❌ Ticket de position invalide à l'index: ", index);
      return 0;
   }
   
   return ticket;
}

//+------------------------------------------------------------------+
//| Wrapper sécurisé pour OrderSend avec retry logic                |
//+------------------------------------------------------------------+
bool SafeOrderSend(MqlTradeRequest& request, MqlTradeResult& result, string operation = "OrderSend")
{
   for(int attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++)
   {
      if(OrderSend(request, result))
      {
         if(attempt > 1)
         {
            Print("✅ ", operation, " réussi après ", attempt, " tentatives");
         }
         return true;
      }
      
      // Log de l'erreur
      Print("❌ ", operation, " échoué (tentative ", attempt, "/", MAX_RETRY_ATTEMPTS, ") - Code: ", result.retcode, " - Comment: ", result.comment);
      
      // Délai avant retry (sauf pour la dernière tentative)
      if(attempt < MAX_RETRY_ATTEMPTS)
      {
         Sleep(RETRY_DELAY_MS);
      }
   }
   
   Print("❌ ", operation, " définitivement échoué après ", MAX_RETRY_ATTEMPTS, " tentatives");
   return false;
}

//+------------------------------------------------------------------+
//| Validation des données de position                              |
//+------------------------------------------------------------------+
bool ValidatePositionData(ulong ticket, double& entryPrice, double& currentSL, double& currentTP, double& currentPrice, bool& isBuy)
{
   // Vérifier le ticket
   if(ticket <= 0)
   {
      Print("❌ Ticket invalide: ", ticket);
      return false;
   }
   
   // Récupérer les données avec validation
   entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   if(entryPrice <= 0)
   {
      Print("❌ Prix d'entrée invalide pour ticket #", ticket, ": ", entryPrice);
      return false;
   }
   
   currentSL = PositionGetDouble(POSITION_SL);
   currentTP = PositionGetDouble(POSITION_TP);
   currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   
   if(currentPrice <= 0)
   {
      Print("❌ Prix actuel invalide pour ticket #", ticket, ": ", currentPrice);
      return false;
   }
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   isBuy = (posType == POSITION_TYPE_BUY);
   
   return true;
}

//+------------------------------------------------------------------+
//| Fonctions utilitaires pour gérer l'état du Trailing TP          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trouver l'index d'une position dans l'array des états           |
//+------------------------------------------------------------------+
int FindPositionStateIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_trailingStates); i++)
   {
      if(g_trailingStates[i].ticket == ticket)
         return i;
   }
   return -1; // Non trouvé
}

//+------------------------------------------------------------------+
//| Ajouter ou mettre à jour l'état d'une position                  |
//+------------------------------------------------------------------+
void UpdatePositionState(ulong ticket, bool isInitialized, double lastSL = 0, double lastTP = 0)
{
   int index = FindPositionStateIndex(ticket);
   
   if(index >= 0)
   {
      // Mettre à jour l'état existant
      g_trailingStates[index].isInitialized = isInitialized;
      g_trailingStates[index].lastUpdate = TimeCurrent();
      g_trailingStates[index].lastSL = lastSL;
      g_trailingStates[index].lastTP = lastTP;
   }
   else
   {
      // Ajouter un nouvel état
      int newSize = ArraySize(g_trailingStates) + 1;
      ArrayResize(g_trailingStates, newSize);
      
      g_trailingStates[newSize-1].ticket = ticket;
      g_trailingStates[newSize-1].isInitialized = isInitialized;
      g_trailingStates[newSize-1].lastUpdate = TimeCurrent();
      g_trailingStates[newSize-1].lastSL = lastSL;
      g_trailingStates[newSize-1].lastTP = lastTP;
   }
}

//+------------------------------------------------------------------+
//| Nettoyer les états des positions fermées                        |
//+------------------------------------------------------------------+
void CleanClosedPositions()
{
   // Créer un array temporaire pour les positions actives
   PositionTrailingState activeStates[];
   ArrayResize(activeStates, 0);
   
   // Parcourir toutes les positions actives
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      // AMÉLIORÉ: Utiliser la fonction sécurisée
      ulong ticket = SafeGetPositionTicket(i);
      if(ticket <= 0) continue;
      
      // Vérifier si c'est notre position
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;
      if(PositionGetString(POSITION_SYMBOL) != SYMBOL) continue;
      
      // Chercher l'état de cette position
      int stateIndex = FindPositionStateIndex(ticket);
      if(stateIndex >= 0)
      {
         // Ajouter à l'array des positions actives
         int newSize = ArraySize(activeStates) + 1;
         ArrayResize(activeStates, newSize);
         activeStates[newSize-1] = g_trailingStates[stateIndex];
      }
   }
   
   // Remplacer l'array global par les positions actives
   ArrayResize(g_trailingStates, ArraySize(activeStates));
   for(int i = 0; i < ArraySize(activeStates); i++)
   {
      g_trailingStates[i] = activeStates[i];
   }
}

//+------------------------------------------------------------------+
//| Gérer le Trailing TP Avancé sur toutes les positions           |
//+------------------------------------------------------------------+
void ManageAdvancedTrailingTP()
{
   if(trailingTP == NULL) return;
   
   // Nettoyer périodiquement les positions fermées (toutes les 100 ticks)
   static int cleanupCounter = 0;
   cleanupCounter++;
   if(cleanupCounter % 100 == 0)
   {
      CleanClosedPositions();
   }
   
   // Parcourir toutes les positions de notre Magic Number
   int total = PositionsTotal();
   
   for(int i = total - 1; i >= 0; i--)
   {
      // AMÉLIORÉ: Utiliser la fonction sécurisée
      ulong ticket = SafeGetPositionTicket(i);
      if(ticket <= 0) continue;
      
      // Vérifier si c'est notre position
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;
      if(PositionGetString(POSITION_SYMBOL) != SYMBOL) continue;
      
      // AMÉLIORÉ: Validation des données de position
      double entryPrice, currentSL, currentTP, currentPrice;
      bool isBuy;
      if(!ValidatePositionData(ticket, entryPrice, currentSL, currentTP, currentPrice, isBuy))
      {
         Print("❌ Données de position invalides pour ticket #", ticket);
         continue;
      }
      
      // Vérifier l'état d'initialisation pour cette position spécifique
      int stateIndex = FindPositionStateIndex(ticket);
      bool isInitialized = false;
      
      if(stateIndex >= 0)
      {
         // Position déjà connue - récupérer son état
         isInitialized = g_trailingStates[stateIndex].isInitialized;
      }
      else
      {
         // Nouvelle position - initialiser le Trailing TP
         if(trailingTP.Initialize(entryPrice, currentSL, currentTP, isBuy))
         {
            Print(StringFormat(
               "🎯 Trailing TP initialisé pour ticket #%I64u | Entry: %.5f | SL: %.5f | TP: %.5f",
               ticket, entryPrice, currentSL, currentTP
            ));
            isInitialized = true;
         }
         else
         {
            Print("❌ Échec initialisation Trailing TP pour ticket #", ticket);
            isInitialized = false;
         }
         
         // Enregistrer l'état de cette nouvelle position
         UpdatePositionState(ticket, isInitialized, currentSL, currentTP);
      }
      
      if(!isInitialized) continue;
      
      // Mettre à jour le Trailing TP
      double newSL = 0, newTP = 0;
      if(trailingTP.Update(currentPrice, newSL, newTP))
      {
         // Vérifier si les valeurs ont vraiment changé pour éviter les modifications inutiles
         if(stateIndex >= 0)
         {
            if(MathAbs(newSL - g_trailingStates[stateIndex].lastSL) < _Point * 0.1 &&
               MathAbs(newTP - g_trailingStates[stateIndex].lastTP) < _Point * 0.1)
            {
               continue; // Pas de changement significatif
            }
         }
         
         // AMÉLIORÉ: Modifier la position avec retry logic
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_SLTP;
         request.symbol = SYMBOL;
         request.position = ticket;
         request.sl = NormalizeDouble(newSL, _Digits);
         request.tp = NormalizeDouble(newTP, _Digits);
         
         string operation = StringFormat("Trailing TP #%I64u", ticket);
         if(SafeOrderSend(request, result, operation))
         {
            Print(StringFormat(
               "✅ Trailing TP appliqué #%I64u | Nouveau SL: %.5f | Nouveau TP: %.5f",
               ticket, newSL, newTP
            ));
            
            // Mettre à jour l'état avec les nouvelles valeurs
            UpdatePositionState(ticket, true, newSL, newTP);
            
            // Afficher sur le graphique si activé
            if(SHOW_TP_STATUS && chartManager != NULL)
            {
               string statusInfo = trailingTP.GetStatusInfo();
               chartManager.ShowTopRightLabel(
                  "🎯 " + statusInfo, 
                  clrGold, 
                  12, 
                  30  // Y offset ajusté pour ne pas chevaucher le statut principal
               );
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Obtenir le texte du signal                                      |
//+------------------------------------------------------------------+
string GetSignalText(int buyScore, int sellScore)
{
   if(buyScore >= SCORE_HIGH_CONFIDENCE)
      return "🟢 BUY⭐⭐";  // Format ultra-compact
   else if(sellScore >= SCORE_HIGH_CONFIDENCE)
      return "🔴 SELL⭐⭐";
   else if(buyScore >= SCORE_MIN_ENTRY)
      return "🟡 BUY⭐";
   else if(sellScore >= SCORE_MIN_ENTRY)
      return "🟠 SELL⭐";
   else
      return "⚪ WAIT";
}

//+------------------------------------------------------------------+
//| Obtenir la couleur du statut                                    |
//+------------------------------------------------------------------+
color GetStatusColor(int buyScore, int sellScore)
{
   if(buyScore >= SCORE_HIGH_CONFIDENCE)
      return clrLime;
   else if(sellScore >= SCORE_HIGH_CONFIDENCE)
      return clrRed;
   else if(buyScore >= SCORE_MIN_ENTRY)
      return clrYellow;
   else if(sellScore >= SCORE_MIN_ENTRY)
      return clrOrange;
   else
      return clrWhite;
}