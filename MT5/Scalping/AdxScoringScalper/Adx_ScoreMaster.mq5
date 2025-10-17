//+------------------------------------------------------------------+
//|                                        Adx_ScoreMaster.mq5       |
//|                   ADX Score Master v2.3 - Patch Final            |
//|                   Utilise ChartManager et TradingTimeManager     |
//|                                                                  |
//| AMÉLIORATIONS v2.3:                                              |
//| ✅ Bug CTrailingTP unique corrigé (objet par position)           |
//| ✅ Performance OnTick() optimisée (throttling intelligent)       |
//| ✅ Gestion d'erreurs robuste avec retry logic                    |
//| ✅ Architecture sécurisée pour plusieurs positions simultanées   |
//| ✅ Nettoyage automatique des objets Trailing TP                  |
//| ✅ Code simplifié (suppression objet global inutilisé)           |
//| ✅ Affichage multi-positions amélioré avec résumé global         |
//| ✅ Patch final: logique trailing corrigée, DisplayGlobalStatus() nettoyée |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.3"
#property strict

//| Configuration par défaut : OPTIMISÉE POUR M5/M15                |
//| Pour timeframes plus longs, ajuster ADX_PERIOD, RSI_PERIOD, MA  |

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
input int SCORE_MIN_ENTRY = 7;               // Score minimum pour entrer en position (optimisé M5/M15)
input int SCORE_HIGH_CONFIDENCE = 11;        // Score haute confiance (lot plus important) (optimisé M5/M15)

input group "=== Risk Management ==="
input ENUM_RISK_MODE RISK_MODE = RISK_PERCENTAGE;  // Mode de gestion du risque
input double RISK_PERCENT_NORMAL = 0.8;      // Risque normal
input double RISK_PERCENT_HIGH = 1.2;        // Risque si haute confiance
input int SL_POINTS = 150;                   // Stop Loss en points (optimisé M5/M15)
input int TP_MULTIPLIER = 3;                 // Multiplicateur TP (SL * TP_MULTIPLIER) (optimisé M5/M15)
input int MAX_POSITIONS = 1;                 // Nombre max de positions simultanées
input bool USE_DYNAMIC_LOTS = true;          // Activer calcul lots dynamique
input bool LOG_LOT_CALCULATION = true;       // Logger les détails de calcul

input group "=== Dynamic Exit System ==="
input bool USE_DYNAMIC_EXIT = true;         // Activer sortie dynamique par renversement
input int EXIT_SCORE_THRESHOLD = 3;         // Écart de score pour déclencher sortie
input int MIN_PROFIT_POINTS_EXIT = 10;      // Profit minimum (points) pour sortie dynamique

input group "=== Indicator Parameters ==="
input int ADX_PERIOD = 8;                    // Période ADX (optimisé M5/M15)
input int RSI_PERIOD = 10;                   // Période RSI (optimisé M5/M15)
input int MA_PERIOD = 34;                    // Période MA (optimisé M5/M15 - Fibonacci)
input ENUM_MA_METHOD MA_METHOD = MODE_SMA;   // Méthode MA

input group "=== ADX Thresholds ==="
input int ADX_THRESHOLD_WEAK = 15;           // Seuil ADX faible (optimisé M5/M15)
input int ADX_THRESHOLD_MODERATE = 18;       // Seuil ADX modéré (optimisé M5/M15)
input int ADX_THRESHOLD_STRONG = 25;         // Seuil ADX fort
input int ADX_THRESHOLD_VERY_STRONG = 32;    // Seuil ADX très fort (optimisé M5/M15)

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
input int SHInput = 8;                       // Start Hour (8 = 8am, 0 = disabled)
input int EHInput = 17;                      // End Hour (17 = 5pm, 0 = disabled)

input group "=== End of Session Management ==="
input bool CLOSE_ALL_AT_SESSION_END = true;           // Fermer positions en fin de session
input int MINUTES_BEFORE_SESSION_END = 5;             // Minutes avant fin pour fermer (0 = à la fin exacte)
input bool WAIT_FOR_PROFITABLE_CLOSE = false;         // Attendre profit positif avant fermeture
input int MAX_WAIT_TIME_SECONDS = 300;                // Temps max d'attente (secondes) si WAIT_FOR_PROFITABLE_CLOSE
input bool LOG_SESSION_CLOSE_DETAILS = true;          // Logger détails fermetures session

input group "=== Session Filter ==="
input bool UseSessionFilter = false;                               // Activer filtre par session
input ENUM_TRADING_SESSION AllowedSession = SESSION_OVERLAP;      // Session autorisée
input int AvoidOpeningMinutes = 30;                               // Minutes à éviter à l'ouverture

input group "=== Alert Messages ==="
input string HourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
input string DayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
input string BothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";

input group "=== Time Confirmation System ==="
input bool USE_TIME_CONFIRMATION = true;           // Activer confirmation temporelle
input int CONFIRMATION_BARS = 2;                   // Nombre de bougies de confirmation (2-5 recommandé)
input int MIN_SCORE_PERSISTENCE = 7; // Score minimum à maintenir
input bool REQUIRE_INCREASING_SCORE = false;       // Exiger score croissant
input bool USE_HIGHER_TF_CONFIRMATION = false;     // Confirmer sur timeframe supérieur
input ENUM_TIMEFRAMES HIGHER_TIMEFRAME = PERIOD_M15; // Timeframe de confirmation
input int HIGHER_TF_MIN_SCORE = 6;                 // Score min sur TF supérieur
input bool LOG_CONFIRMATION_DETAILS = true;        // Logger détails confirmation

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
ChartManager* chartManager = NULL;
TradingTimeManager* timeManager = NULL;
AdxScoreTrader* scoreTrader = NULL;

//+------------------------------------------------------------------+
//| Structure pour gérer un objet Trailing TP par position          |
//+------------------------------------------------------------------+
struct PositionTrailingManager
{
   ulong ticket;
   CTrailingTP* trailingTPObject;
   bool isInitialized;
   datetime lastUpdate;
   double lastSL;
   double lastTP;
};

// Array pour stocker les managers de toutes les positions
PositionTrailingManager g_trailingManagers[];

//+------------------------------------------------------------------+
//| Structure pour l'historique des scores                          |
//+------------------------------------------------------------------+
struct ScoreHistory
{
   datetime barTime;      // Heure de la bougie
   int buyScore;          // Score BUY
   int sellScore;         // Score SELL
   bool buySignal;        // Signal BUY actif
   bool sellSignal;       // Signal SELL actif
};

// Historique global des scores
ScoreHistory g_scoreHistory[];
int g_historySize = 10; // Garder les 10 dernières bougies

//+------------------------------------------------------------------+
//| Variables pour l'optimisation des performances                  |
//+------------------------------------------------------------------+
datetime g_lastVisualUpdate = 0;        // Dernière mise à jour visuelle
datetime g_lastStatusUpdate = 0;        // Dernière mise à jour du statut
datetime g_lastCleanup = 0;             // Dernier nettoyage des labels
datetime g_lastTrailingUpdate = 0;        // NOUVEAU: Pour throttler Trailing TP
const int VISUAL_UPDATE_INTERVAL = 3;   // 3 secondes au lieu de 1
const int STATUS_UPDATE_INTERVAL = 5;   // 5 secondes au lieu de 2
const int CLEANUP_INTERVAL = 60;        // 60 secondes au lieu de 30
const int TRAILING_CLEANUP_INTERVAL = 15; // 15 secondes au lieu de 10
const int TRAILING_UPDATE_INTERVAL = 1;   // NOUVEAU: Throttling pour Trailing TP

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
   
   // ═══ Step 2.5: Valider la configuration Trailing TP ═══
   if(USE_ADVANCED_TRAILING_TP)
   {
      Print("🔍 Validation configuration Trailing TP...");
      
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
      CTrailingTPValidator::PrintParsedLevels(CustomTPLevels);
      Print("✅ Système Trailing TP prêt (objets créés dynamiquement par position)");
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
      USE_DYNAMIC_LOTS,
      LOG_LOT_CALCULATION,
      ADX_THRESHOLD_WEAK,           // NOUVEAU
      ADX_THRESHOLD_MODERATE,       // NOUVEAU
      ADX_THRESHOLD_STRONG,         // NOUVEAU
      ADX_THRESHOLD_VERY_STRONG,    // NOUVEAU
      USE_DYNAMIC_EXIT,             // NOUVEAU
      EXIT_SCORE_THRESHOLD,         // NOUVEAU
      MIN_PROFIT_POINTS_EXIT        // NOUVEAU
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
   
   // AJOUTER ICI :
   if(USE_DYNAMIC_EXIT)
   {
      Print("🔄 Sortie Dynamique: ACTIVÉE");
      Print("  Seuil renversement: ", EXIT_SCORE_THRESHOLD, " points");
      Print("  Profit min sortie: ", MIN_PROFIT_POINTS_EXIT, " points");
   }
   else
   {
      Print("🔄 Sortie Dynamique: DÉSACTIVÉE");
   }
   
   // Configuration End of Session Management
   if(CLOSE_ALL_AT_SESSION_END)
   {
      Print("🔚 Fermeture Fin de Session: ACTIVÉE");
      Print("  Minutes avant fin: ", MINUTES_BEFORE_SESSION_END);
      Print("  Attendre profit: ", (WAIT_FOR_PROFITABLE_CLOSE ? "OUI" : "NON"));
      if(WAIT_FOR_PROFITABLE_CLOSE)
         Print("  Temps max attente: ", MAX_WAIT_TIME_SECONDS, " secondes");
   }
   else
   {
      Print("🔚 Fermeture Fin de Session: DÉSACTIVÉE");
   }
   
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
   
   // CRITIQUE: Nettoyer tous les objets Trailing TP individuels
   for(int i = 0; i < ArraySize(g_trailingManagers); i++)
   {
      if(g_trailingManagers[i].trailingTPObject != NULL)
      {
         delete g_trailingManagers[i].trailingTPObject;
         Print("🧹 Trailing TP supprimé pour ticket #", g_trailingManagers[i].ticket);
      }
   }
   ArrayResize(g_trailingManagers, 0);
   Print("✅ Tous les objets Trailing TP nettoyés");
   
   // Nettoyer l'historique des scores
   ArrayResize(g_scoreHistory, 0);
   Print("✅ Historique des scores nettoyé");
   
   
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
//| Helper function: Get session end hour                           |
//+------------------------------------------------------------------+
int GetSessionEndHour(ENUM_TRADING_SESSION session)
{
   switch(session)
   {
      case SESSION_LONDON:    return 12;  // 8:00-12:00
      case SESSION_US:        return 17;  // 13:00-17:00  
      case SESSION_OVERLAP:   return 16;  // 13:00-16:00
      case SESSION_ASIA:      return 6;   // 22:00-6:00 (retourne 6 pour le lendemain)
      case SESSION_ALL:       return 0;   // 24/7 - pas de fin
      default:                return 0;   // Session inconnue
   }
}

//+------------------------------------------------------------------+
//| Ajouter un score à l'historique                                 |
//+------------------------------------------------------------------+
void AddScoreToHistory(int buyScore, int sellScore)
{
   datetime currentBarTime = iTime(SYMBOL, TIMEFRAME, 0);
   
   // Vérifier si c'est une nouvelle barre
   if(ArraySize(g_scoreHistory) > 0 && g_scoreHistory[ArraySize(g_scoreHistory)-1].barTime == currentBarTime)
   {
      // Mettre à jour la dernière entrée (même bougie)
      g_scoreHistory[ArraySize(g_scoreHistory)-1].buyScore = buyScore;
      g_scoreHistory[ArraySize(g_scoreHistory)-1].sellScore = sellScore;
      g_scoreHistory[ArraySize(g_scoreHistory)-1].buySignal = (buyScore >= MIN_SCORE_PERSISTENCE);
      g_scoreHistory[ArraySize(g_scoreHistory)-1].sellSignal = (sellScore >= MIN_SCORE_PERSISTENCE);
      return;
   }
   
   // Ajouter nouvelle entrée (nouvelle bougie)
   int newSize = ArraySize(g_scoreHistory) + 1;
   ArrayResize(g_scoreHistory, newSize);
   
   g_scoreHistory[newSize-1].barTime = currentBarTime;
   g_scoreHistory[newSize-1].buyScore = buyScore;
   g_scoreHistory[newSize-1].sellScore = sellScore;
   g_scoreHistory[newSize-1].buySignal = (buyScore >= MIN_SCORE_PERSISTENCE);
   g_scoreHistory[newSize-1].sellSignal = (sellScore >= MIN_SCORE_PERSISTENCE);
   
   // Limiter la taille de l'historique
   if(ArraySize(g_scoreHistory) > g_historySize)
   {
      ArrayRemove(g_scoreHistory, 0, 1);
   }
}

//+------------------------------------------------------------------+
//| Vérifier la confirmation temporelle BUY                         |
//+------------------------------------------------------------------+
bool CheckBuyTimeConfirmation(int currentBuyScore)
{
   if(!USE_TIME_CONFIRMATION) return true;
   
   int historySize = ArraySize(g_scoreHistory);
   if(historySize < CONFIRMATION_BARS)
   {
      if(LOG_CONFIRMATION_DETAILS)
         Print("⏳ Confirmation BUY: Historique insuffisant (", historySize, "/", CONFIRMATION_BARS, ")");
      return false;
   }
   
   int consecutiveBars = 0;
   int lastScore = currentBuyScore;
   
   // Parcourir l'historique du plus récent au plus ancien
   for(int i = historySize - 1; i >= 0 && consecutiveBars < CONFIRMATION_BARS; i--)
   {
      if(g_scoreHistory[i].buySignal && g_scoreHistory[i].buyScore >= MIN_SCORE_PERSISTENCE)
      {
         // Si on exige un score croissant
         if(REQUIRE_INCREASING_SCORE && i < historySize - 1)
         {
            if(g_scoreHistory[i].buyScore >= lastScore)
            {
               consecutiveBars++;
               lastScore = g_scoreHistory[i].buyScore;
            }
            else
            {
               break; // Score décroissant, arrêter
            }
         }
         else
         {
            consecutiveBars++;
            lastScore = g_scoreHistory[i].buyScore;
         }
      }
      else
      {
         break; // Signal interrompu
      }
   }
   
   bool confirmed = (consecutiveBars >= CONFIRMATION_BARS);
   
   if(LOG_CONFIRMATION_DETAILS)
   {
      Print(StringFormat(
         "🔍 Confirmation BUY: %d/%d bougies | Score actuel: %d | %s",
         consecutiveBars, CONFIRMATION_BARS, currentBuyScore,
         confirmed ? "✅ CONFIRMÉ" : "❌ EN ATTENTE"
      ));
   }
   
   return confirmed;
}

//+------------------------------------------------------------------+
//| Vérifier la confirmation temporelle SELL                        |
//+------------------------------------------------------------------+
bool CheckSellTimeConfirmation(int currentSellScore)
{
   if(!USE_TIME_CONFIRMATION) return true;
   
   int historySize = ArraySize(g_scoreHistory);
   if(historySize < CONFIRMATION_BARS)
   {
      if(LOG_CONFIRMATION_DETAILS)
         Print("⏳ Confirmation SELL: Historique insuffisant (", historySize, "/", CONFIRMATION_BARS, ")");
      return false;
   }
   
   int consecutiveBars = 0;
   int lastScore = currentSellScore;
   
   for(int i = historySize - 1; i >= 0 && consecutiveBars < CONFIRMATION_BARS; i--)
   {
      if(g_scoreHistory[i].sellSignal && g_scoreHistory[i].sellScore >= MIN_SCORE_PERSISTENCE)
      {
         if(REQUIRE_INCREASING_SCORE && i < historySize - 1)
         {
            if(g_scoreHistory[i].sellScore >= lastScore)
            {
               consecutiveBars++;
               lastScore = g_scoreHistory[i].sellScore;
            }
            else
            {
               break;
            }
         }
         else
         {
            consecutiveBars++;
            lastScore = g_scoreHistory[i].sellScore;
         }
      }
      else
      {
         break;
      }
   }
   
   bool confirmed = (consecutiveBars >= CONFIRMATION_BARS);
   
   if(LOG_CONFIRMATION_DETAILS)
   {
      Print(StringFormat(
         "🔍 Confirmation SELL: %d/%d bougies | Score actuel: %d | %s",
         consecutiveBars, CONFIRMATION_BARS, currentSellScore,
         confirmed ? "✅ CONFIRMÉ" : "❌ EN ATTENTE"
      ));
   }
   
   return confirmed;
}

//+------------------------------------------------------------------+
//| Confirmer sur timeframe supérieur                               |
//+------------------------------------------------------------------+
bool CheckHigherTimeframeConfirmation(bool isBuySignal)
{
   if(!USE_HIGHER_TF_CONFIRMATION) return true;
   
   // Créer un trader temporaire sur le TF supérieur
   AdxScoreTrader* higherTFTrader = new AdxScoreTrader(
      SYMBOL,
      MAGIC_NUMBER,
      HIGHER_TIMEFRAME,
      HIGHER_TF_MIN_SCORE,
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
      false, // USE_TRAILING
      0,     // TRAILING_START
      0,     // TRAILING_STEP
      USE_VOLATILITY_FILTER,
      ATR_PERIOD,
      MIN_VOLATILITY_RATIO,
      MAX_VOLATILITY_RATIO,
      false, // USE_DYNAMIC_LOTS
      false, // LOG_LOT_CALCULATION
      ADX_THRESHOLD_WEAK,
      ADX_THRESHOLD_MODERATE,
      ADX_THRESHOLD_STRONG,
      ADX_THRESHOLD_VERY_STRONG,
      false, // USE_DYNAMIC_EXIT
      0,     // EXIT_SCORE_THRESHOLD
      0      // MIN_PROFIT_POINTS_EXIT
   );
   
   if(!higherTFTrader.Initialize())
   {
      Print("❌ Erreur initialisation trader TF supérieur");
      delete higherTFTrader;
      return false;
   }
   
   higherTFTrader.UpdateScoresOnly();
   
   bool confirmed = false;
   if(isBuySignal)
      confirmed = (higherTFTrader.GetBuyScore() >= HIGHER_TF_MIN_SCORE);
   else
      confirmed = (higherTFTrader.GetSellScore() >= HIGHER_TF_MIN_SCORE);
   
   if(LOG_CONFIRMATION_DETAILS)
   {
      Print(StringFormat(
         "📊 TF Supérieur (%s): %s Score=%d | %s",
         EnumToString(HIGHER_TIMEFRAME),
         isBuySignal ? "BUY" : "SELL",
         isBuySignal ? higherTFTrader.GetBuyScore() : higherTFTrader.GetSellScore(),
         confirmed ? "✅ CONFIRMÉ" : "❌ REJETÉ"
      ));
   }
   
   delete higherTFTrader;
   return confirmed;
}

//+------------------------------------------------------------------+
//| Obtenir le statut de confirmation pour l'affichage              |
//+------------------------------------------------------------------+
string GetConfirmationStatus()
{
   if(!USE_TIME_CONFIRMATION) return "";
   
   int historySize = ArraySize(g_scoreHistory);
   if(historySize == 0) return "⏳ En attente...";
   
   // Compter les bougies de confirmation actuelles
   int buyBars = 0, sellBars = 0;
   
   for(int i = historySize - 1; i >= 0 && (buyBars < CONFIRMATION_BARS || sellBars < CONFIRMATION_BARS); i--)
   {
      if(g_scoreHistory[i].buySignal && buyBars < CONFIRMATION_BARS)
         buyBars++;
      else if(buyBars > 0)
         break;
         
      if(g_scoreHistory[i].sellSignal && sellBars < CONFIRMATION_BARS)
         sellBars++;
      else if(sellBars > 0)
         break;
   }
   
   string status = "";
   if(buyBars > 0)
      status += StringFormat("🟢 %d/%d ", buyBars, CONFIRMATION_BARS);
   if(sellBars > 0)
      status += StringFormat("🔴 %d/%d", sellBars, CONFIRMATION_BARS);
   
   return status != "" ? status : "⚪ Aucun";
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
      
      // ✨ NOUVEAU: Ajouter les scores à l'historique pour confirmation temporelle
      if(USE_TIME_CONFIRMATION)
      {
         AddScoreToHistory(scoreTrader.GetBuyScore(), scoreTrader.GetSellScore());
      }
   }
   
   // SÉPARÉ: Update visuels selon throttling (indépendant des nouvelles barres)
   if(currentTime - g_lastVisualUpdate >= VISUAL_UPDATE_INTERVAL)
   {
      UpdateAllVisuals();
      g_lastVisualUpdate = currentTime;
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

   // Si trading autorisé ET nouvelle barre : vérifier les signaux AVEC confirmation
   if(tradingAllowed && isNewBar)
   {
      if(USE_TIME_CONFIRMATION)
      {
         // ✨ Vérifier avec confirmation temporelle
         int buyScore = scoreTrader.GetBuyScore();
         int sellScore = scoreTrader.GetSellScore();
         
         bool buyConfirmed = false;
         bool sellConfirmed = false;
         
         // Étape 1 : Vérifier confirmation sur plusieurs bougies
         if(buyScore >= SCORE_MIN_ENTRY)
            buyConfirmed = CheckBuyTimeConfirmation(buyScore);
         
         if(sellScore >= SCORE_MIN_ENTRY)
            sellConfirmed = CheckSellTimeConfirmation(sellScore);
         
         // Étape 2 : Vérifier timeframe supérieur si activé
         if(buyConfirmed && USE_HIGHER_TF_CONFIRMATION)
            buyConfirmed = CheckHigherTimeframeConfirmation(true);
         
         if(sellConfirmed && USE_HIGHER_TF_CONFIRMATION)
            sellConfirmed = CheckHigherTimeframeConfirmation(false);
         
         // Étape 3 : Exécuter uniquement si confirmé
         if(buyConfirmed || sellConfirmed)
         {
            scoreTrader.CheckTradingSignals();
         }
         else if(LOG_CONFIRMATION_DETAILS)
         {
            Print("⏸️ Signal en attente de confirmation temporelle");
         }
      }
      else
      {
         // Sans confirmation : exécution directe (comportement original)
         scoreTrader.CheckTradingSignals();
      }
   }

   // ✨ NOUVEAU : Vérifier sortie dynamique à CHAQUE tick (même sans nouvelle barre)
   if(USE_DYNAMIC_EXIT && scoreTrader != NULL)
   {
      scoreTrader.CheckDynamicExit();
   }

   // ✨ NOUVEAU : Gestion fermeture fin de session
   if(CLOSE_ALL_AT_SESSION_END && scoreTrader != NULL && timeManager != NULL)
   {
      // Vérifier si on approche de la fin de session
      bool isEndingSession = false;
      
      // MÉTHODE 1: Time filter classique (SHInput/EHInput)
      if(SHInput != 0 && EHInput != 0) // Time filter actif
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         
         int currentMinutes = dt.hour * 60 + dt.min;
         int endMinutes = EHInput * 60;
         int minutesUntilEnd = endMinutes - currentMinutes;
         
         // Si on est dans la période de fermeture
         if(minutesUntilEnd >= 0 && minutesUntilEnd <= MINUTES_BEFORE_SESSION_END)
         {
            isEndingSession = true;
            if(LOG_SESSION_CLOSE_DETAILS)
               Print("🕐 Time Filter: Fermeture dans ", minutesUntilEnd, " minutes (fin à ", EHInput, ":00)");
         }
      }
      
      // MÉTHODE 2: Session filter (basé sur les sessions de trading)
      if(!isEndingSession && UseSessionFilter && timeManager != NULL)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         int currentMinutes = dt.hour * 60 + dt.min;
         
         // Obtenir l'heure de fin de la session actuelle
         int sessionEndHour = GetSessionEndHour(AllowedSession);
         if(sessionEndHour > 0)
         {
            int sessionEndMinutes = sessionEndHour * 60;
            int minutesUntilSessionEnd = sessionEndMinutes - currentMinutes;
            
            // Si on est dans la période de fermeture de session
            if(minutesUntilSessionEnd >= 0 && minutesUntilSessionEnd <= MINUTES_BEFORE_SESSION_END)
            {
               isEndingSession = true;
               if(LOG_SESSION_CLOSE_DETAILS)
                  Print("🕐 Session Filter: Fermeture dans ", minutesUntilSessionEnd, " minutes (fin session à ", sessionEndHour, ":00)");
            }
         }
      }
      
      // Déclencher la fermeture si nécessaire
      if(isEndingSession)
      {
         int closedPositions = scoreTrader.CloseAllPositions(
            WAIT_FOR_PROFITABLE_CLOSE,
            MAX_WAIT_TIME_SECONDS,
            LOG_SESSION_CLOSE_DETAILS
         );
         
         if(closedPositions > 0)
         {
            Print("🔚 Fin de session: ", closedPositions, " position(s) fermée(s)");
         }
      }
   }

   // Gérer le Trailing TP Avancé ou Standard avec throttling
   if(USE_ADVANCED_TRAILING_TP && (currentTime - g_lastTrailingUpdate >= TRAILING_UPDATE_INTERVAL))
   {
      ManageAdvancedTrailingTP();
      g_lastTrailingUpdate = currentTime;
   }
   else if(USE_TRAILING && scoreTrader != NULL && (currentTime - g_lastTrailingUpdate >= TRAILING_UPDATE_INTERVAL))
   {
      scoreTrader.TrailingStop();
      g_lastTrailingUpdate = currentTime;
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
   
   // DisplayGlobalStatus() SUPPRIMÉ pour performance
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage du graphique                          |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   if(chartManager == NULL || scoreTrader == NULL) return;
   
   // Note: Cette fonction est appelée selon le throttling défini par VISUAL_UPDATE_INTERVAL
   // pour optimiser les performances tout en gardant un affichage fluide
   
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
   
   // ✨ NOUVEAU: Afficher statut de confirmation temporelle
   if(USE_TIME_CONFIRMATION)
   {
      string confirmStatus = GetConfirmationStatus();
      if(confirmStatus != "")
      {
         int currentSize = ArraySize(indicators);
         ArrayResize(indicators, currentSize + 1);
         indicators[currentSize] = "Confirm: " + confirmStatus;
      }
   }
   
   // Couleur dynamique selon signal
   color indColor = clrWhite;
   if(buyScore >= SCORE_MIN_ENTRY) indColor = clrLimeGreen;
   else if(sellScore >= SCORE_MIN_ENTRY) indColor = clrOrangeRed;
   
   // Police agrandie de 9 à 11 - Centré en bas
   chartManager.ShowMultiLineInfo(indicators, CORNER_LEFT_LOWER, 150, 30, 20, indColor, 11, "Indicators");
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
//| Afficher le statut global - DÉSACTIVÉ POUR PERFORMANCE         |
//+------------------------------------------------------------------+
// FONCTION SUPPRIMÉE: Affichage temps/balance inutile et coûteux
// Si nécessaire, réactiver avec throttling plus important (10+ secondes)
void DisplayGlobalStatus()
{
   // FONCTION DÉSACTIVÉE POUR OPTIMISATION PERFORMANCE
   return;
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
//| Fonctions utilitaires pour gérer les managers Trailing TP       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trouver l'index d'un manager dans l'array                       |
//+------------------------------------------------------------------+
int FindTrailingManagerIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_trailingManagers); i++)
   {
      if(g_trailingManagers[i].ticket == ticket)
         return i;
   }
   return -1; // Non trouvé
}

//+------------------------------------------------------------------+
//| Trouver ou créer un objet Trailing TP pour un ticket            |
//+------------------------------------------------------------------+
CTrailingTP* GetOrCreateTrailingTP(ulong ticket)
{
   int index = FindTrailingManagerIndex(ticket);
   if(index >= 0) 
   {
      return g_trailingManagers[index].trailingTPObject;
   }
   
   // Créer un nouvel objet Trailing TP
   CTrailingTP* newTrailing = new CTrailingTP(TRAILING_TP_MODE, CustomTPLevels);
   if(newTrailing == NULL)
   {
      Print("❌ Erreur création CTrailingTP pour ticket #", ticket);
      return NULL;
   }
   
   // Ajouter au manager
   int newSize = ArraySize(g_trailingManagers) + 1;
   ArrayResize(g_trailingManagers, newSize);
   
   g_trailingManagers[newSize-1].ticket = ticket;
   g_trailingManagers[newSize-1].trailingTPObject = newTrailing;
   g_trailingManagers[newSize-1].isInitialized = false;
   g_trailingManagers[newSize-1].lastUpdate = 0;
   g_trailingManagers[newSize-1].lastSL = 0;
   g_trailingManagers[newSize-1].lastTP = 0;
   
   Print("✅ Nouveau Trailing TP créé pour ticket #", ticket);
   return newTrailing;
}

//+------------------------------------------------------------------+
//| Mettre à jour l'état d'un manager                               |
//+------------------------------------------------------------------+
void UpdateTrailingManager(ulong ticket, bool isInitialized, double lastSL = 0, double lastTP = 0)
{
   int index = FindTrailingManagerIndex(ticket);
   if(index >= 0)
   {
      g_trailingManagers[index].isInitialized = isInitialized;
      g_trailingManagers[index].lastUpdate = TimeCurrent();
      g_trailingManagers[index].lastSL = lastSL;
      g_trailingManagers[index].lastTP = lastTP;
   }
}

//+------------------------------------------------------------------+
//| Nettoyer les managers des positions fermées                     |
//+------------------------------------------------------------------+
void CleanTrailingManagers()
{
   for(int i = ArraySize(g_trailingManagers) - 1; i >= 0; i--)
   {
      bool positionExists = false;
      
      // Vérifier si la position existe encore
      for(int j = 0; j < PositionsTotal(); j++)
      {
         ulong ticket = SafeGetPositionTicket(j);
         if(ticket == g_trailingManagers[i].ticket)
         {
            // Vérifier si c'est notre position
            if(PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER && 
               PositionGetString(POSITION_SYMBOL) == SYMBOL)
            {
               positionExists = true;
               break;
            }
         }
      }
      
      if(!positionExists)
      {
         // Supprimer l'objet Trailing TP
         if(g_trailingManagers[i].trailingTPObject != NULL)
         {
            delete g_trailingManagers[i].trailingTPObject;
            Print("🧹 Trailing TP supprimé pour ticket #", g_trailingManagers[i].ticket);
         }
         
         // Supprimer l'élément de l'array
         ArrayRemove(g_trailingManagers, i, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Gérer le Trailing TP Avancé sur toutes les positions           |
//+------------------------------------------------------------------+
void ManageAdvancedTrailingTP()
{
   // Nettoyage périodique des managers (toutes les 10 secondes)
   datetime currentTime = TimeCurrent();
   static datetime lastClean = 0;
   if(currentTime - lastClean >= TRAILING_CLEANUP_INTERVAL)
   {
      CleanTrailingManagers();
      lastClean = currentTime;
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
      
      // CRITIQUE: Obtenir l'objet Trailing TP SPÉCIFIQUE à cette position
      CTrailingTP* positionTrailingTP = GetOrCreateTrailingTP(ticket);
      if(positionTrailingTP == NULL)
      {
         Print("❌ Impossible de créer Trailing TP pour ticket #", ticket);
         continue;
      }
      
      int managerIndex = FindTrailingManagerIndex(ticket);
      if(managerIndex < 0) continue;
      
      // Initialiser si nécessaire
      if(!g_trailingManagers[managerIndex].isInitialized)
      {
         if(positionTrailingTP.Initialize(entryPrice, currentSL, currentTP, isBuy))
         {
            g_trailingManagers[managerIndex].isInitialized = true;
            Print(StringFormat(
               "🎯 Trailing TP initialisé pour ticket #%I64u | Entry: %.5f | SL: %.5f | TP: %.5f",
               ticket, entryPrice, currentSL, currentTP
            ));
         }
         else
         {
            Print("❌ Échec initialisation Trailing TP pour ticket #", ticket);
            continue;
         }
      }
      
      // Mettre à jour le Trailing TP avec l'objet spécifique à cette position
      double newSL = 0, newTP = 0;
      if(positionTrailingTP.Update(currentPrice, newSL, newTP))
      {
         // Vérifier si les valeurs ont vraiment changé pour éviter les modifications inutiles
         if(MathAbs(newSL - g_trailingManagers[managerIndex].lastSL) < _Point * 0.1 &&
            MathAbs(newTP - g_trailingManagers[managerIndex].lastTP) < _Point * 0.1)
         {
            continue; // Pas de changement significatif
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
            UpdateTrailingManager(ticket, true, newSL, newTP);
         }
      }
   }
   
   // NOUVEAU: Afficher un résumé global APRÈS la boucle
   // Display Trailing TP status BELOW the main status (different Y offset)
   if(SHOW_TP_STATUS && chartManager != NULL && ArraySize(g_trailingManagers) > 0)
   {
      string statusSummary = StringFormat(
         "🎯 Trailing: %d pos",
         ArraySize(g_trailingManagers)
      );
      
      // Ajouter le statut de la première position active
      if(g_trailingManagers[0].trailingTPObject != NULL && 
         g_trailingManagers[0].isInitialized)
      {
         statusSummary += " | " + g_trailingManagers[0].trailingTPObject.GetStatusInfo();
      }
      
      // Use Y offset of 50 instead of 10/30 to avoid conflict with main status
      chartManager.ShowTopRightLabel(statusSummary, clrGold, 11, 50);
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