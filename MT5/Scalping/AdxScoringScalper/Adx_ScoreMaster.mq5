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
input int SCORE_MIN_ENTRY = 6;               // Score minimum pour entrer en position
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
   
   // Toujours mettre à jour les indicateurs et scores (pour l'affichage)
   if(scoreTrader != NULL && scoreTrader.IsNewBar())
   {
      scoreTrader.UpdateScoresOnly();
   }

   // Vérifier si le trading est autorisé selon le filtre temps
   bool tradingAllowed = timeManager.IsTradingAllowed();

   if(tradingAllowed)
   {
      // Trading autorisé: vérifier les signaux SEULEMENT
      if(scoreTrader != NULL && scoreTrader.IsNewBar())
      {
         scoreTrader.CheckTradingSignals();
      }
   }
   
   // Appliquer le trailing stop (toujours actif)
   if(scoreTrader != NULL)
      scoreTrader.TrailingStop();
   
   // Mettre à jour l'affichage PRINCIPAL uniquement à chaque nouvelle barre
   if(scoreTrader != NULL && scoreTrader.IsNewBar())
   {
      UpdateChartDisplay();
   }
   
   // Mettre à jour le statut global moins souvent
   DisplayGlobalStatus();
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
   ArrayResize(indicators, 6);
   
   // Titre en Bold
   indicators[0] = "━━━ INDICATORS ━━━";
   
   // ADX avec code couleur
   double adx = scoreTrader.GetADX();
   string adxStatus = "";
   if(adx > 35) adxStatus = " 🔥";  // Très fort
   else if(adx > 25) adxStatus = " ⚡";  // Fort
   else if(adx > 20) adxStatus = " →";  // Modéré
   indicators[1] = StringFormat("ADX: %.1f%s", adx, adxStatus);
   
   // RSI avec code couleur
   double rsi = scoreTrader.GetRSI();
   string rsiStatus = "";
   if(rsi < 30) rsiStatus = " 🔵";  // Survente
   else if(rsi > 70) rsiStatus = " 🔴";  // Surachat
   indicators[2] = StringFormat("RSI: %.1f%s", rsi, rsiStatus);
   
   // MA avec distance
   double ma = scoreTrader.GetMA();
   double price = scoreTrader.GetPrice();
   double distance = ((price - ma) / ma) * 100;
   string maStatus = distance > 0 ? " ↑" : " ↓";
   indicators[3] = StringFormat("MA: %.4f%s", ma, maStatus);
   
   // Positions
   indicators[4] = StringFormat("Pos: %d/%d", scoreTrader.GetCurrentPositions(), scoreTrader.GetMaxPositions());
   
   // Scores actuels
   indicators[5] = StringFormat("Score: BUY[%d] SELL[%d]", buyScore, sellScore);
   
   // Couleur dynamique selon signal
   color indColor = clrWhite;
   if(buyScore >= SCORE_MIN_ENTRY) indColor = clrLimeGreen;
   else if(sellScore >= SCORE_MIN_ENTRY) indColor = clrOrangeRed;
   
   // Police agrandie de 9 à 11 - Centré en bas
   chartManager.ShowMultiLineInfo(indicators, CORNER_LEFT_LOWER, 200, 30, 20, indColor, 11, "Indicators");
   
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
   lines[1] = StringFormat("BUY: ADX:%d RSI:%d MA:%d CF:%d", 
      scoreTrader.GetBuyADXScore(), scoreTrader.GetBuyRSIScore(), 
      scoreTrader.GetBuyMAScore(), scoreTrader.GetBuyConfluenceScore());
   
   lines[2] = StringFormat("SELL: ADX:%d RSI:%d MA:%d CF:%d", 
      scoreTrader.GetSellADXScore(), scoreTrader.GetSellRSIScore(), 
      scoreTrader.GetSellMAScore(), scoreTrader.GetSellConfluenceScore());
   
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
   
   static int statusTick = 0;
   statusTick++;
   
   // Garder une fréquence réduite pour balance/time (toutes les 100 ticks au lieu de 300)
   if(statusTick % 100 != 0) return;
   
   string statusLines[];
   ArrayResize(statusLines, 3);
   
   // Ligne 1: Statut trading
   string tradingStatus = timeManager.IsTradingAllowed() ? "🟢 ACTIVE" : "🔴 PAUSED";
   statusLines[0] = "Status: " + tradingStatus;
   
   // Ligne 2: Heure actuelle
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   statusLines[1] = StringFormat("Time: %02d:%02d", dt.hour, dt.min);
   
   // Ligne 3: Balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   statusLines[2] = StringFormat("Bal: %.2f", balance);
   
   // Police agrandie de 9 à 10
   chartManager.ShowMultiLineInfo(statusLines, CORNER_LEFT_LOWER, 10, 30, 20, clrDeepSkyBlue, 10, "GlobalStatus");
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