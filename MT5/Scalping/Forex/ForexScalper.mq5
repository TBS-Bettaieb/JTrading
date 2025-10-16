//+------------------------------------------------------------------+
//|                                              Scalping Robot.mq5 |
//|                                                                  |
//|                                                     Version 2.00 |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict



#include <Trade\Trade.mqh>
#include "../../CommonUtils/TradingEnums.mqh"
#include "../../CommonUtils/TradingUtils.mqh"
#include "../../CommonUtils/TradingTimeManager.mqh"
#include "../../CommonUtils/ChartManager.mqh"
#include "common/ForexSymbolTrader.mqh"
#include "common/ForexSymbolManager.mqh"

//--- Constantes
const string STRATEGY_NAME = "Forex Scalper V1.1";

// Objets globaux
ChartManager* chartManager = NULL;
TradingTimeManager* timeManager = NULL;
ForexSymbolTrader* symbolTraders[];

//--- Multi-Symbol Trading Inputs
input group "=== Multi-Symbol Configuration ==="
/// EURUSD,GBPUSD,USDCHF,USDJPY,USDCAD,AUDUSD,AUDNZD,AUDCAD,AUDCHF,AUDJPY,CHFJPY,EURGBP,EURAUD,EURCHF,EURJPY,EURNZD,EURCAD,GBPCHF,GBPJPY,CADCHF,CADJPY,GBPAUD,GBPCAD,GBPNZD,NZDCAD,NZDCHF,NZDJPY,NZDUSD
input string   SymbolsList        = "EURUSD,GBPUSD,USDJPY,USDCAD";  // List of symbols (comma separated)
input ENUM_TIMEFRAMES Timeframe   = PERIOD_M5; //Time frame to run
input bool     UseAllSymbols      = false;                   // Use all symbols from Market Watch
input int      BaseMagic          = 298347;                  // Base magic number (incremented per symbol)

//--- Trading Inputs
input group "=== Trading Inputs ==="
input double   RiskPercent        = 4;     // Risk as % of Trading Capital (divided by symbol count)
input int      Tppoints           = 200;   // Take Profit (10 points = 1 pip)
input int      Slpoints           = 200;   // StopLoss Points (10 points = 1 pip)
input int      TslTriggerPoints   = 10;    // Points in profit before Trailing SL is activated (10 points = 1 pip)
input int      TslPoints          = 10;    // Trailing Stop Loss (10 points = 1 pip)
input string   TradeComment       = "Scalping Robot";

//--- Time Filters
input group "=== Time Filter ==="
input int SHInput = 7;  // Start Hour (0 = Inactive, 1-23 = Active)
input int EHInput = 19; // End Hour (0 = Inactive, 1-23 = Active)

//--- Alert Messages
input group "=== Alert Messages ==="
input string HourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
input string DayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
input string BothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";

//--- Bar management
input group "=== Strategy Parameters ==="
input ENUM_STRATEGY_MODE StrategyMode = STRATEGY_BREAKOUT; // Strategy Mode: Breakout or Reversion
input int      BarsN = 5;
input int      ExpirationBars = 50;
input int      OrderDistPoints = 100;

//--- Trailing Take Profit
input group "=== Trailing Take Profit ==="
input bool UseTrailingTP = true;  // Activer Trailing TP
input ENUM_TRAILING_TP_MODE TrailingTPMode = TRAILING_TP_STEPPED;  // Mode Trailing TP

//--- Global variables
string symbols[];                    // Array of trading symbols
int totalSymbols = 0;               // Total number of symbols

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════");
   Print("🚀 Initializing Scalping Robot v2.0");
   Print("═══════════════════════════════════════");
   
   // ═══ Step 1: Parse and validate symbols ═══
   if(UseAllSymbols)
   {
      totalSymbols = GetSymbolsFromMarketWatch(symbols);
      Print("📊 Using all symbols from Market Watch: ", totalSymbols, " symbols");
   }
   else
   {
      totalSymbols = ParseSymbolsList(SymbolsList, symbols);
      Print("📊 Using custom symbols list: ", totalSymbols, " symbols");
   }
   
   if(totalSymbols <= 0)
   {
      Print("❌ ERROR: No valid symbols found. Please check your configuration.");
      return(INIT_FAILED);
   }
   
   // ═══ Step 2: Validate historical data ═══
   for(int i = 0; i < totalSymbols; i++)
   {
      if(!CheckHistoricalData(symbols[i], Timeframe))
      {
         Print("⚠️ Warning: Limited historical data for ", symbols[i]);
      }
   }
   
   // ═══ Step 3: Calculate risk per symbol ═══
   double riskPerSymbol = CalculateRiskPerSymbol(RiskPercent, totalSymbols);
   Print("💰 Risk per symbol: ", DoubleToString(riskPerSymbol, 2), "% (Total: ", DoubleToString(RiskPercent, 2), "%)");
   
   // ═══ Step 4: Create ForexSymbolTrader objects ═══
   ArrayResize(symbolTraders, totalSymbols);
   
   for(int i = 0; i < totalSymbols; i++)
   {
      int magicNumber = GenerateMagicNumber(BaseMagic, i, Timeframe, "ScalpingRobot");
      
      symbolTraders[i] = new ForexSymbolTrader(
         symbols[i],                    // symbol
         magicNumber,                   // magic number
         Timeframe,                     // timeframe
         riskPerSymbol,                 // risk percent
         Tppoints,                      // take profit points
         Slpoints,                      // stop loss points
         TslTriggerPoints,              // trailing SL trigger points
         TslPoints,                     // trailing SL points
         BarsN,                         // bars for analysis
         ExpirationBars,                // expiration bars
         OrderDistPoints,               // order distance points
         TradeComment,                  // trade comment
         StrategyMode,                  // strategy mode
         UseTrailingTP,                 // use trailing TP
         TrailingTPMode                 // trailing TP mode
      );
      
      if(symbolTraders[i] == NULL)
      {
         Print("❌ ERROR: Failed to create ForexSymbolTrader for ", symbols[i]);
         return(INIT_FAILED);
      }
   }
   
   // ═══ Step 5: Initialize Chart Manager ═══
   chartManager = new ChartManager(0, "ForexScalpBot");
   
   if(chartManager != NULL)
   {
      // Appliquer le style du graphique
      chartManager.SetupChart();
      
      // Afficher le nom de la stratégie
      chartManager.ShowStrategyName(STRATEGY_NAME);
      
      // Afficher les informations des symboles
      PrintSymbolsInfo(symbols, BaseMagic, Timeframe, "ScalpingRobot");
      
   }
   else
   {
      Print("⚠️ Warning: Chart Manager initialization failed");
   }
   
   // ═══ Step 6: Initialize Time Manager ═══
   timeManager = new TradingTimeManager(chartManager);
   timeManager.Initialize(
      (SHInput != 0 || EHInput != 0),  // useTimeFilter
      IntegerToString(SHInput) + "-" + IntegerToString(EHInput),  // hourRanges
      false,  // useDayFilter (pas utilisé pour l'instant)
      "",     // dayRanges
      true    // showVisualAlerts
   );
   timeManager.SetVerboseLogging(true);
   
   // Configurer les messages d'alerte personnalisés
   timeManager.SetAlertMessages(HourBlockMsg, DayBlockMsg, BothBlockMsg);
   
   // Afficher la configuration du Time Manager
   Print("⏰ Time Manager Configuration:");
   Print(timeManager.GetDetailedInfo());
   
   Print("✅ Initialization completed successfully!");
   Print("📈 Trading ", totalSymbols, " symbols simultaneously");
   Print("🕒 Timeframe: ", EnumToString(Timeframe));
   Print("═══════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("═══════════════════════════════════════");
   Print("🛑 Scalping Robot v2.0 stopping...");
   Print("Reason: ", reason);
   Print("═══════════════════════════════════════");
   
   // ═══ Cleanup ForexSymbolTrader objects ═══
   if(ArraySize(symbolTraders) > 0)
   {
      for(int i = 0; i < ArraySize(symbolTraders); i++)
      {
         if(symbolTraders[i] != NULL)
         {
            delete symbolTraders[i];
            symbolTraders[i] = NULL;
         }
      }
      ArrayFree(symbolTraders);
      Print("✅ Symbol Traders cleaned up");
   }
   
   // ═══ Cleanup Time Manager ═══
   if(timeManager != NULL)
   {
      delete timeManager;
      timeManager = NULL;
      Print("✅ Time Manager cleaned up");
   }
   
   // ═══ Cleanup Chart Manager ═══
   if(chartManager != NULL)
   {
      delete chartManager;
      chartManager = NULL;
      Print("✅ Chart Manager cleaned up");
   }
   
   // ═══ Cleanup symbols array ═══
   ArrayFree(symbols);
   
   Print("✅ All resources cleaned up successfully");
   Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier que les objets sont initialisés
   if(chartManager == NULL || timeManager == NULL || ArraySize(symbolTraders) == 0)
   {
      return;
   }
   
   // Vérifier si le trading est autorisé selon le filtre temps
   bool tradingAllowed = timeManager.IsTradingAllowed();
   
   // Parcourir tous les symboles et traiter leurs ticks
   for(int i = 0; i < totalSymbols; i++)
   {
      if(symbolTraders[i] != NULL)
      {
         if(tradingAllowed)
         {
            // Trading autorisé: traiter les signaux
            symbolTraders[i].OnTick();
         }
         else
         {
            // Trading bloqué: annuler tous les ordres pending
            symbolTraders[i].CancelAllPendingOrders();
         }
         
         // Appliquer le trailing stop pour ce symbole (toujours actif)
         symbolTraders[i].TrailStop();
         
         // Appliquer le trailing TP
         symbolTraders[i].ApplyTrailingTP();
      }
   }
   
   // Mettre à jour les informations sur le graphique (une fois par tick)
   UpdateChartInfo();
}


//+------------------------------------------------------------------+
//| Update chart information display                                 |
//+------------------------------------------------------------------+
void UpdateChartInfo()
{
   if(chartManager == NULL || ArraySize(symbolTraders) == 0) return;
   
   static int tickCount = 0;
   tickCount++;
   
   // Mettre à jour toutes les 100 ticks pour éviter trop de rafraîchissements
   if(tickCount % 100 != 0) return;
   
   // Construire le texte de statut global
   string globalStatus = GetGlobalSymbolsStatus(symbols, symbolTraders);
   
   // Obtenir le statut du TimeManager pour affichage
   string timeStatus = timeManager.GetStatusDescription();
   globalStatus = timeStatus + " | " + globalStatus;
   
   // Couleur basée sur le statut trading et P/L
   color statusColor = clrGreen;
   ENUM_TRADING_STATUS status = timeManager.GetCurrentStatus();
   
   if(status != TRADING_ACTIVE)
      statusColor = clrOrange;  // Trading bloqué
   else if(StringFind(globalStatus, "P/L: -") >= 0)
      statusColor = clrRed;     // Trading actif mais en perte
   else if(StringFind(globalStatus, "P/L: ") >= 0)
      statusColor = clrLime;    // Trading actif en profit
   
   // Mettre à jour le label principal
   chartManager.UpdateLabelText("TopRight", globalStatus);
   chartManager.UpdateLabelColor("TopRight", statusColor);
   
   // Afficher les détails par symbole (optionnel, pour debug)
   static int detailUpdateCount = 0;
   detailUpdateCount++;
   
   // Mettre à jour les détails toutes les 500 ticks
   if(detailUpdateCount % 500 == 0)
   {
      string detailLines[];
      ArrayResize(detailLines, totalSymbols + 1);
      
      detailLines[0] = "━━━ SYMBOL DETAILS ━━━";
      
      for(int i = 0; i < totalSymbols; i++)
      {
         if(symbolTraders[i] != NULL)
         {
            detailLines[i + 1] = symbolTraders[i].GetStatusInfo();
         }
      }
      
      // Afficher les détails dans le coin inférieur gauche
      chartManager.ShowMultiLineInfo(detailLines, CORNER_LEFT_LOWER, 10, 30, 14, clrDarkBlue, 8);
      
      // Rafraîchir l'affichage des swing points
      for(int i = 0; i < totalSymbols; i++)
      {
         if(symbolTraders[i] != NULL)
         {
            symbolTraders[i].RefreshSwingDisplay();
         }
      }
   }
}
//+------------------------------------------------------------------+