//+------------------------------------------------------------------+
//|                                        Adx_ScoreMaster.mq5       |
//|                   ADX Score Master v2.0 - Refactorisé            |
//|                   Utilise ChartManager et TradingTimeManager     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.0"
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "../../CommonUtils/ChartManager.mqh"
#include "../../CommonUtils/TradingTimeManager.mqh"
#include "../../CommonUtils/TradingUtils.mqh"
#include "../../CommonUtils/TradingEnums.mqh"
#include "common/AdxScoreTrader.mqh"

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== Trading Parameters ==="
input string SYMBOL = "EURUSD";              // Symbol to trade
input int MAGIC_NUMBER = 12345;              // Magic number
input ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M5; // Timeframe

input group "=== Scoring System ==="
input int SCORE_MIN_ENTRY = 7;               // Score minimum pour entrer en position (augmenté pour plus de sélectivité)
input int SCORE_HIGH_CONFIDENCE = 9;         // Score haute confiance (lot plus important)

input group "=== Risk Management ==="
input ENUM_RISK_MODE RISK_MODE = RISK_PERCENTAGE;  // Mode de gestion du risque
input double RISK_PERCENT_NORMAL = 0.8;      // Risque normal
input double RISK_PERCENT_HIGH = 1.2;        // Risque si haute confiance
input int SL_POINTS = 200;                   // Stop Loss en points
input int TP_MULTIPLIER = 2;                 // Multiplicateur TP (SL * TP_MULTIPLIER)
input int MAX_POSITIONS = 1;                 // Nombre max de positions simultanées

input group "=== Indicator Parameters ==="
input int ADX_PERIOD = 14;                   // Période ADX
input int RSI_PERIOD = 14;                   // Période RSI
input int MA_PERIOD = 50;                    // Période MA
input ENUM_MA_METHOD MA_METHOD = MODE_SMA;   // Méthode MA

input group "=== Trailing Stop ==="
input bool USE_TRAILING = false;             // Activer Trailing Stop
input int TRAILING_START = 50;               // Points de profit pour démarrer
input int TRAILING_STEP = 20;                // Points de trailing

input group "=== Time Filter ==="
input int SHInput = 0;                       // Start Hour (0 = disabled)
input int EHInput = 0;                       // End Hour (0 = disabled)

input group "=== Alert Messages ==="
input string HourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
input string DayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
input string BothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
ChartManager* chartManager = NULL;
TradingTimeManager* timeManager = NULL;
AdxScoreTrader* scoreTrader = NULL;

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
      TRAILING_STEP
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
   
   // MODIFIÉ: Nettoyage moins fréquent pour éviter les saccades
   static int cleanupTick = 0;
   cleanupTick++;
   if(cleanupTick % 50000 == 0)  // De 10000 à 50000
   {
      Print("🧹 Nettoyage périodique des labels...");
      chartManager.ClearLabels();
      Sleep(50);  // Réduit de 100 à 50ms
   }
   
   // Vérifier si le trading est autorisé selon le filtre temps
   bool tradingAllowed = timeManager.IsTradingAllowed();
   
   if(tradingAllowed)
   {
      // Trading autorisé: traiter les signaux
      scoreTrader.OnTick();
   }
   
   // Appliquer le trailing stop (toujours actif)
   if(scoreTrader != NULL)
      scoreTrader.TrailingStop();
   
   // Mettre à jour l'affichage PRINCIPAL à chaque tick (temps réel)
   UpdateChartDisplay();
   
   // Mettre à jour le statut global moins souvent
   DisplayGlobalStatus();
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage du graphique                          |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   if(chartManager == NULL || scoreTrader == NULL) return;
   
   // ═══ Affichage ENRICHI des indicateurs ═══
   string indicators[];
   ArrayResize(indicators, 10); // Augmenté de 5 à 10 lignes
   
   int line = 0;
   
   // Titre
   indicators[line++] = "━━━ INDICATORS ━━━";
   
   // ADX avec code couleur et niveau
   double adx = scoreTrader.GetADX();
   string adxLevel = "";
   if(adx > 35) adxLevel = " (TRÈS FORT)";
   else if(adx > 25) adxLevel = " (FORT)";
   else if(adx > 20) adxLevel = " (MODÉRÉ)";
   else adxLevel = " (FAIBLE)";
   
   string adxStatus = "";
   if(adx > 35) adxStatus = " 🔥";
   else if(adx > 25) adxStatus = " ⚡";
   else if(adx > 20) adxStatus = " →";
   indicators[line++] = StringFormat("ADX: %.1f%s%s", adx, adxStatus, adxLevel);
   
   // RSI avec code couleur et zone
   double rsi = scoreTrader.GetRSI();
   string rsiZone = "";
   if(rsi < 30) rsiZone = " (SURVENTE)";
   else if(rsi > 70) rsiZone = " (SURACHAT)";
   else if(rsi >= 45 && rsi <= 55) rsiZone = " (NEUTRE)";
   else if(rsi < 45) rsiZone = " (BAS)";
   else rsiZone = " (HAUT)";
   
   string rsiStatus = "";
   if(rsi < 30) rsiStatus = " 🔵";
   else if(rsi > 70) rsiStatus = " 🔴";
   else if(rsi >= 45 && rsi <= 55) rsiStatus = " ⚪";
   indicators[line++] = StringFormat("RSI: %.1f%s%s", rsi, rsiStatus, rsiZone);
   
   // MA avec distance en %
   double ma = scoreTrader.GetMA();
   double price = scoreTrader.GetPrice();
   double distancePct = ((price - ma) / ma) * 100;
   string maStatus = distancePct > 0 ? " ↑" : " ↓";
   indicators[line++] = StringFormat("MA: %.4f%s", ma, maStatus);
   indicators[line++] = StringFormat("Distance: %.2f%%%s", MathAbs(distancePct), distancePct > 0 ? " AU-DESSUS" : " EN-DESSOUS");
   
   // Prix actuel
   indicators[line++] = StringFormat("Prix: %.4f", price);
   
   // Ligne vide
   indicators[line++] = "";
   
   // ═══ SCORES EN TEMPS RÉEL ═══
   int buyScore = scoreTrader.GetBuyScore();
   int sellScore = scoreTrader.GetSellScore();
   
   // Score BUY avec détail
   string buyStatus = "";
   if(buyScore >= SCORE_HIGH_CONFIDENCE) buyStatus = " ⭐⭐ HIGH";
   else if(buyScore >= SCORE_MIN_ENTRY) buyStatus = " ⭐ SIGNAL";
   else buyStatus = StringFormat(" (%d pts manquants)", SCORE_MIN_ENTRY - buyScore);
   indicators[line++] = StringFormat("BUY: %d/%d%s", buyScore, SCORE_MIN_ENTRY, buyStatus);
   
   // Score SELL avec détail
   string sellStatus = "";
   if(sellScore >= SCORE_HIGH_CONFIDENCE) sellStatus = " ⭐⭐ HIGH";
   else if(sellScore >= SCORE_MIN_ENTRY) sellStatus = " ⭐ SIGNAL";
   else sellStatus = StringFormat(" (%d pts manquants)", SCORE_MIN_ENTRY - sellScore);
   indicators[line++] = StringFormat("SELL: %d/%d%s", sellScore, SCORE_MIN_ENTRY, sellStatus);
   
   // Positions
   indicators[line++] = StringFormat("Pos: %d/%d", scoreTrader.GetCurrentPositions(), scoreTrader.GetMaxPositions());
   
   // Couleur dynamique selon signal
   color indColor = clrWhite;
   if(buyScore >= SCORE_MIN_ENTRY) indColor = clrLimeGreen;
   else if(sellScore >= SCORE_MIN_ENTRY) indColor = clrOrangeRed;
   
   // Affichage à DROITE (CORNER_RIGHT_UPPER au lieu de LEFT)
   chartManager.ShowMultiLineInfo(indicators, CORNER_RIGHT_UPPER, 10, 80, 20, indColor, 11, "Indicators");
   
   // ═══ Affichage du breakdown détaillé ═══
   DisplayScoreBreakdown();
   
   // ═══ Affichage du SIGNAL PRINCIPAL (haut centre) ═══
   string mainSignal = "";
   color signalColor = clrWhite;

   if(buyScore >= SCORE_HIGH_CONFIDENCE)
   {
      mainSignal = StringFormat("🟢 BUY SIGNAL HIGH (%d/%d) ⭐⭐", buyScore, SCORE_MIN_ENTRY);
      signalColor = clrLime;
   }
   else if(sellScore >= SCORE_HIGH_CONFIDENCE)
   {
      mainSignal = StringFormat("🔴 SELL SIGNAL HIGH (%d/%d) ⭐⭐", sellScore, SCORE_MIN_ENTRY);
      signalColor = clrRed;
   }
   else if(buyScore >= SCORE_MIN_ENTRY)
   {
      mainSignal = StringFormat("🟡 BUY SIGNAL (%d/%d) ⭐", buyScore, SCORE_MIN_ENTRY);
      signalColor = clrYellow;
   }
   else if(sellScore >= SCORE_MIN_ENTRY)
   {
      mainSignal = StringFormat("🟠 SELL SIGNAL (%d/%d) ⭐", sellScore, SCORE_MIN_ENTRY);
      signalColor = clrOrange;
   }
   else
   {
      int buyRemaining = SCORE_MIN_ENTRY - buyScore;
      int sellRemaining = SCORE_MIN_ENTRY - sellScore;
      mainSignal = StringFormat("⚪ NO SIGNAL | BUY: %d/%d (-%d) | SELL: %d/%d (-%d)", 
         buyScore, SCORE_MIN_ENTRY, buyRemaining,
         sellScore, SCORE_MIN_ENTRY, sellRemaining);
      signalColor = clrWhite;
   }

   // Afficher en très GROS en haut
   chartManager.ShowTopRightLabel(mainSignal, signalColor, 16, 10);
}

//+------------------------------------------------------------------+
//| Afficher le breakdown détaillé du score                         |
//+------------------------------------------------------------------+
void DisplayScoreBreakdown()
{
   if(chartManager == NULL || scoreTrader == NULL) return;
   
   string lines[];
   ArrayResize(lines, 12); // Augmenté pour plus de détails
   
   int line = 0;
   
   lines[line++] = "━━━ SCORE BREAKDOWN ━━━";
   lines[line++] = "";
   
   int buyScore = scoreTrader.GetBuyScore();
   int sellScore = scoreTrader.GetSellScore();
   
   // === DÉTAIL SCORE BUY ===
   lines[line++] = "🟢 BUY SCORING:";
   lines[line++] = StringFormat("  ADX: %+d pts", scoreTrader.GetBuyADXScore());
   lines[line++] = StringFormat("  RSI: %+d pts", scoreTrader.GetBuyRSIScore());
   lines[line++] = StringFormat("  MA:  %+d pts", scoreTrader.GetBuyMAScore());
   lines[line++] = StringFormat("  CF:  %+d pts", scoreTrader.GetBuyConfluenceScore());
   
   string buyIndicator = "";
   if(buyScore >= SCORE_HIGH_CONFIDENCE) buyIndicator = " ⭐⭐";
   else if(buyScore >= SCORE_MIN_ENTRY) buyIndicator = " ⭐";
   lines[line++] = StringFormat("  TOTAL: %d/%d%s", buyScore, SCORE_MIN_ENTRY, buyIndicator);
   
   lines[line++] = "";
   
   // === DÉTAIL SCORE SELL ===
   lines[line++] = "🔴 SELL SCORING:";
   lines[line++] = StringFormat("  ADX: %+d pts", scoreTrader.GetSellADXScore());
   lines[line++] = StringFormat("  RSI: %+d pts", scoreTrader.GetSellRSIScore());
   lines[line++] = StringFormat("  MA:  %+d pts", scoreTrader.GetSellMAScore());
   lines[line++] = StringFormat("  CF:  %+d pts", scoreTrader.GetSellConfluenceScore());
   
   string sellIndicator = "";
   if(sellScore >= SCORE_HIGH_CONFIDENCE) sellIndicator = " ⭐⭐";
   else if(sellScore >= SCORE_MIN_ENTRY) sellIndicator = " ⭐";
   lines[line++] = StringFormat("  TOTAL: %d/%d%s", sellScore, SCORE_MIN_ENTRY, sellIndicator);
   
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
   
   // Afficher à GAUCHE en BAS
   chartManager.ShowMultiLineInfo(lines, CORNER_LEFT_LOWER, 10, 30, 18, textColor, 10, "ScoreBreakdown");
}

//+------------------------------------------------------------------+
//| Afficher le statut global                                       |
//+------------------------------------------------------------------+
void DisplayGlobalStatus()
{
   if(chartManager == NULL || scoreTrader == NULL || timeManager == NULL) return;
   
   static int statusTick = 0;
   statusTick++;
   
   if(statusTick % 100 != 0) return;
   
   string statusLines[];
   ArrayResize(statusLines, 5); // Augmenté à 5 lignes
   
   int line = 0;
   
   // Titre
   statusLines[line++] = "━━━ STATUS ━━━";
   
   // Statut trading
   string tradingStatus = timeManager.IsTradingAllowed() ? "🟢 ACTIVE" : "🔴 PAUSED";
   statusLines[line++] = tradingStatus;
   
   // Heure actuelle
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   statusLines[line++] = StringFormat("Time: %02d:%02d", dt.hour, dt.min);
   
   // Balance + Equity
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   statusLines[line++] = StringFormat("Bal: %.2f", balance);
   statusLines[line++] = StringFormat("Eqt: %.2f (%.2f%%)", equity, (equity/balance - 1) * 100);
   
   // Afficher en haut à gauche (pour garder visible)
   chartManager.ShowMultiLineInfo(statusLines, CORNER_LEFT_UPPER, 10, 10, 18, clrDeepSkyBlue, 10, "GlobalStatus");
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