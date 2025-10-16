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
   
   // Nettoyer les labels existants
   chartManager.ClearLabels();
   
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
   
   // Mettre à jour l'affichage (toujours actif)
   UpdateChartDisplay();
   DisplayGlobalStatus();  // NOUVEAU
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage du graphique                          |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   if(chartManager == NULL || scoreTrader == NULL) return;
   
   static int tickCount = 0;
   tickCount++;
   
   // Mettre à jour toutes les 50 ticks au lieu de 100
   if(tickCount % 50 != 0) return;
   
   // ═══ Affichage du statut principal (haut droite) ═══
   int buyScore = scoreTrader.GetBuyScore();
   int sellScore = scoreTrader.GetSellScore();
   string signal = GetSignalText(buyScore, sellScore);
   
   string status = StringFormat(
      "BUY:%d SELL:%d %s",  // Format raccourci
      buyScore, sellScore, signal
   );
   
   color statusColor = GetStatusColor(buyScore, sellScore);
   chartManager.ShowTopRightLabel(status, statusColor, 12, 10);  // Taille réduite à 12
   
   // ═══ Affichage des indicateurs avec couleurs dynamiques ═══
   string indicators[];
   ArrayResize(indicators, 5);
   
   // Titre
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
   
   // Couleur dynamique selon signal
   color indColor = clrWhite;
   if(buyScore >= SCORE_MIN_ENTRY) indColor = clrLimeGreen;
   else if(sellScore >= SCORE_MIN_ENTRY) indColor = clrOrangeRed;
   
   // Position déplacée: YDISTANCE de 80 → 100
   chartManager.ShowMultiLineInfo(indicators, CORNER_LEFT_UPPER, 10, 100, 18, indColor, 9);
   
   // ═══ Affichage du breakdown du score ═══
   DisplayScoreBreakdown();
}

//+------------------------------------------------------------------+
//| Afficher le breakdown détaillé du score                         |
//+------------------------------------------------------------------+
void DisplayScoreBreakdown()
{
   if(chartManager == NULL || scoreTrader == NULL) return;
   
   static int updateCount = 0;
   updateCount++;
   
   // Mettre à jour toutes les 200 ticks au lieu de 500
   if(updateCount % 200 != 0) return;
   
   string lines[];
   ArrayResize(lines, 8);  // Réduit de 10 à 8 lignes
   
   lines[0] = "━━━ SCORE BREAKDOWN ━━━";
   
   // Format compact avec séparateur
   lines[1] = StringFormat("BUY: ADX:%d RSI:%d MA:%d CF:%d", 
      scoreTrader.GetBuyADXScore(), scoreTrader.GetBuyRSIScore(), 
      scoreTrader.GetBuyMAScore(), scoreTrader.GetBuyConfluenceScore());
   
   lines[2] = StringFormat("SELL: ADX:%d RSI:%d MA:%d CF:%d", 
      scoreTrader.GetSellADXScore(), scoreTrader.GetSellRSIScore(), 
      scoreTrader.GetSellMAScore(), scoreTrader.GetSellConfluenceScore());
   
   lines[3] = "─────────────────";
   
   // Affichage des totaux avec indicateur visuel
   int buyScore = scoreTrader.GetBuyScore();
   int sellScore = scoreTrader.GetSellScore();
   
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
   
   // Afficher dans le coin inférieur droit
   chartManager.ShowMultiLineInfo(lines, CORNER_RIGHT_LOWER, 10, 30, 16, textColor, 9);
}

//+------------------------------------------------------------------+
//| Afficher le statut global                                       |
//+------------------------------------------------------------------+
void DisplayGlobalStatus()
{
   if(chartManager == NULL || scoreTrader == NULL || timeManager == NULL) return;
   
   static int statusTick = 0;
   statusTick++;
   
   // Mettre à jour toutes les 300 ticks
   if(statusTick % 300 != 0) return;
   
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
   
   // Afficher dans le coin inférieur gauche
   chartManager.ShowMultiLineInfo(statusLines, CORNER_LEFT_LOWER, 10, 30, 18, clrDeepSkyBlue, 9);
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