//+------------------------------------------------------------------+
//|                                              Scalping Robot.mq5 |
//|                                                                  |
//|                                                     Version 2.00 |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict



#include <Trade\Trade.mqh>
#include "common/JT_ChartManager.mqh"
#include "common/filters/TimesàDaysFilters/JT_TimeFilter.mqh"
#include "common/JT_SymbolTrader.mqh"
#include "common/JT_SymbolManager.mqh"

// Objets globaux
CChartManager* chartManager = NULL;
CSymbolTrader* symbolTraders[];

//--- Multi-Symbol Trading Inputs
input group "=== Multi-Symbol Configuration ==="
/// EURUSD,GBPUSD,USDCHF,USDJPY,USDCAD,AUDUSD,AUDNZD,AUDCAD,AUDCHF,AUDJPY,CHFJPY,EURGBP,EURAUD,EURCHF,EURJPY,EURNZD,EURCAD,GBPCHF,GBPJPY,CADCHF,CADJPY,GBPAUD,GBPCAD,GBPNZD,NZDCAD,NZDCHF,NZDJPY,NZDUSD
input string   SymbolsList        = "EURUSD,GBPUSD,USDJPY";  // List of symbols (comma separated)
input ENUM_TIMEFRAMES Timeframe   = PERIOD_M5; //Time frame to run
input bool     UseAllSymbols      = false;                   // Use all symbols from Market Watch
input int      BaseMagic          = 298347;                  // Base magic number (incremented per symbol)

//--- Trading Inputs
input group "=== Trading Inputs ==="
input double   RiskPercent        = 2;     // Risk as % of Trading Capital (divided by symbol count)
input int      Tppoints           = 200;   // Take Profit (10 points = 1 pip)
input int      Slpoints           = 200;   // StopLoss Points (10 points = 1 pip)
input int      TslTriggerPoints   = 20;    // Points in profit before Trailing SL is activated (10 points = 1 pip)
input int      TslPoints          = 10;    // Trailing Stop Loss (10 points = 1 pip)
input string   TradeComment       = "Scalping Robot";

//--- Time Filters (moved to JT_TimeFilter.mqh)

//--- Bar management
input group "=== Strategy Parameters ==="
input ENUM_STRATEGY_MODE StrategyMode = STRATEGY_BREAKOUT; // Strategy Mode: Breakout or Reversion
input int      BarsN = 5;
input int      ExpirationBars = 50;
input int      OrderDistPoints = 100;

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
   
   // ═══ Step 4: Create CSymbolTrader objects ═══
   ArrayResize(symbolTraders, totalSymbols);
   
   for(int i = 0; i < totalSymbols; i++)
   {
      int magicNumber = GenerateMagicNumber(BaseMagic, i, Timeframe, "ScalpingRobot");
      
      symbolTraders[i] = new CSymbolTrader(
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
         StrategyMode                   // strategy mode
      );
      
      if(symbolTraders[i] == NULL)
      {
         Print("❌ ERROR: Failed to create CSymbolTrader for ", symbols[i]);
         return(INIT_FAILED);
      }
   }
   
   // ═══ Step 5: Initialize Chart Manager ═══
   chartManager = new CChartManager(0, "ScalpBot");
   
   if(chartManager != NULL)
   {
      // Appliquer le style du graphique
      chartManager.SetupChart();
      
      // Afficher le nom de la stratégie
      chartManager.ShowTopLeftLabel("Scalping Robot v2.0 - Multi-Symbol", clrDarkBlue, 14);
      
      // Afficher les informations des symboles
      PrintSymbolsInfo(symbols, BaseMagic, Timeframe, "ScalpingRobot");
      
   }
   else
   {
      Print("⚠️ Warning: Chart Manager initialization failed");
   }
   
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
   
   // ═══ Cleanup CSymbolTrader objects ═══
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
   if(chartManager == NULL || ArraySize(symbolTraders) == 0)
   {
      return;
   }
   
   // Parcourir tous les symboles et traiter leurs ticks
   for(int i = 0; i < totalSymbols; i++)
   {
      if(symbolTraders[i] != NULL)
      {
         // Traiter le tick pour ce symbole
         symbolTraders[i].OnTick();
         
         // Appliquer le trailing stop pour ce symbole
         symbolTraders[i].TrailStop();
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
   
   // Vérifier si on est dans les heures de trading
   bool tradingAllowed = TF_IsTradingAllowed();
   
   if(tradingAllowed)
      globalStatus = "Status: ACTIVE | " + globalStatus;
   else
      globalStatus = "Status: OUTSIDE HOURS | " + globalStatus;
   
   // Mettre à jour la couleur selon le statut
   color statusColor = clrGreen;
   if(!tradingAllowed) 
      statusColor = clrOrange;
   else if(StringFind(globalStatus, "P/L: -") >= 0) 
      statusColor = clrRed;
   else if(StringFind(globalStatus, "P/L: ") >= 0)
      statusColor = clrGreen;
   
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