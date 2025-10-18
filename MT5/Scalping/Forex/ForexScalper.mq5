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
input string   SymbolsList        = "EURUSD,GBPUSD";  // - List of symbols (comma separated) ⚠️⚠️⚠️ NE PAS MODIFIER
input ENUM_TIMEFRAMES Timeframe   = PERIOD_M5; // Time frame to run ⚠️⚠️⚠️ NE PAS MODIFIER
input bool     UseAllSymbols      = false;                   // Use all symbols from Market Watch
input int      BaseMagic          = 298347;                  // Base magic number (incremented per symbol)

//--- Trading Inputs
input group "=== Trading Inputs ==="
input double   RiskPercent        = 2;     // Risk as % of Trading Capital (divided by symbol count)
input int      Tppoints           = 200;   // Take Profit (10 points = 1 pip)
input int      Slpoints           = 200;   // StopLoss Points (10 points = 1 pip)
input int      TslTriggerPoints   = 10;    // Points in profit before Trailing SL is activated (10 points = 1 pip)
input int      TslPoints          = 10;    // Trailing Stop Loss (10 points = 1 pip)
input bool     DisableTslInProfit = false; // Désactiver Trailing SL une fois en profit NET
input string   TradeComment       = "Scalping Robot";

//--- Time Filters
input group "=== Time Filter ==="
input int SHInput = 7;  // Start Hour (0 = Inactive, 1-23 = Active)
input int EHInput = 19; // End Hour (0 = Inactive, 1-23 = Active)

//--- Risk Multiplier Time Filter
input group "=== Risk Multiplier Time Filter ==="
input bool     UseRiskMultiplier    = false;           // Activer le multiplicateur de risque horaire
input int      RiskMultStartHour    = 13;              // Heure de début (0-23)
input int      RiskMultEndHour      = 18;              // Heure de fin (0-23) ⚠️⚠️⚠️ NE PAS MODIFIER
input double   RiskMultFactor       = 1.5;             // Facteur multiplicateur (ex: 1.5 = +50% de risque) ⚠️⚠️⚠️ NE PAS MODIFIER
input bool     UpdatePendingOrders  = true;            // Mettre à jour les ordres pending existants

//--- Alert Messages
input group "=== Alert Messages ==="
input string HourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
input string DayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
input string BothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";

//--- Bar management
input group "=== Strategy Parameters ==="
input ENUM_STRATEGY_MODE StrategyMode = STRATEGY_BREAKOUT; // Strategy Mode: Breakout or Reversion ⚠️⚠️⚠️ NE PAS MODIFIER
input int      BarsN = 5;
input int      ExpirationBars = 50;
input int      OrderDistPoints = 100;

//--- Trailing Take Profit
input group "=== Trailing Take Profit ==="
input bool UseTrailingTP = true;  // Activer Trailing TP
input ENUM_TRAILING_TP_MODE TrailingTPMode = TRAILING_TP_CUSTOM;  // Mode personnalisé avec niveaux définis ⚠️⚠️⚠️ NE PAS MODIFIER
input string CustomTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150";  //Custom TP Levels (profit:slMove:tpExtend) ⚠️⚠️⚠️ NE PAS MODIFIER

//--- Global variables
string symbols[];                    // Array of trading symbols
int totalSymbols = 0;               // Total number of symbols

//+------------------------------------------------------------------+
//| Vérifie si l'heure actuelle est dans la plage spécifiée         |
//+------------------------------------------------------------------+
bool IsCurrentHourInRange(int startHour, int endHour)
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   int currentHour = currentTime.hour;
   
   // Gérer le cas où la plage traverse minuit (ex: 22-02)
   if(startHour <= endHour)
   {
      return (currentHour >= startHour && currentHour < endHour);
   }
   else
   {
      return (currentHour >= startHour || currentHour < endHour);
   }
}

//+------------------------------------------------------------------+
//| Calcule le risque en tenant compte du multiplicateur horaire    |
//+------------------------------------------------------------------+
double GetAdjustedRiskPercent(double baseRisk, bool tradingAllowed)
{
   // Si le multiplicateur est désactivé, retourner le risque de base
   if(!UseRiskMultiplier)
      return baseRisk;
   
   // Si le trading n'est pas autorisé, pas de multiplicateur
   if(!tradingAllowed)
      return baseRisk;
   
   // Vérifier si on est dans la plage horaire du multiplicateur
   if(IsCurrentHourInRange(RiskMultStartHour, RiskMultEndHour))
   {
      double adjustedRisk = baseRisk * RiskMultFactor;
      
      // Log uniquement lors du premier tick dans la plage (pour éviter spam)
      static bool loggedEntry = false;
      if(!loggedEntry)
      {
         Print("🔥 RISK MULTIPLIER ACTIVE: ", DoubleToString(baseRisk, 2), "% × ", 
               DoubleToString(RiskMultFactor, 2), " = ", DoubleToString(adjustedRisk, 2), "%");
         loggedEntry = true;
      }
      
      return adjustedRisk;
   }
   else
   {
      // Reset du flag quand on sort de la plage
      static bool loggedEntry = false;
      loggedEntry = false;
      
      return baseRisk;
   }
}

//+------------------------------------------------------------------+
//| Met à jour le volume des ordres pending selon le nouveau risque |
//+------------------------------------------------------------------+
void UpdatePendingOrdersVolume(double newRiskPercent)
{
   if(!UpdatePendingOrders) return;
   
   CTrade trade;
   int modifiedCount = 0;
   int failedCount = 0;
   
   // Parcourir tous les ordres pending
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      // Vérifier que c'est un ordre pending du robot
      long magic = OrderGetInteger(ORDER_MAGIC);
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      
      // Ne traiter que les ordres pending de ce robot
      bool isRobotOrder = false;
      for(int j = 0; j < totalSymbols; j++)
      {
         if(symbolTraders[j] != NULL && symbolTraders[j].GetMagicNumber() == magic)
         {
            isRobotOrder = true;
            break;
         }
      }
      
      if(!isRobotOrder) continue;
      
      // Ne traiter que BUY_LIMIT et SELL_LIMIT
      if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
         continue;
      
      // Récupérer les informations de l'ordre
      string symbol = OrderGetString(ORDER_SYMBOL);
      double currentVolume = OrderGetDouble(ORDER_VOLUME_INITIAL);
      double entryPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double sl = OrderGetDouble(ORDER_SL);
      double tp = OrderGetDouble(ORDER_TP);
      
      // Trouver le trader correspondant à ce symbole
      ForexSymbolTrader* trader = NULL;
      for(int j = 0; j < totalSymbols; j++)
      {
         if(symbolTraders[j] != NULL && 
            symbolTraders[j].GetSymbol() == symbol && 
            symbolTraders[j].GetMagicNumber() == magic)
         {
            trader = symbolTraders[j];
            break;
         }
      }
      
      if(trader == NULL) continue;
      
      // Calculer le nouveau volume avec le risque ajusté
      double newVolume = trader.CalculateVolume(entryPrice, sl, newRiskPercent);
      
      // Normaliser le volume
      double minVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      newVolume = MathMax(minVol, MathMin(maxVol, MathRound(newVolume / stepVol) * stepVol));
      
      // Vérifier si le volume a changé significativement (> 1%)
      if(MathAbs(newVolume - currentVolume) / currentVolume > 0.01)
      {
         // Modifier l'ordre
         if(trade.OrderModify(ticket, entryPrice, sl, tp, ORDER_TIME_GTC, 0, newVolume))
         {
            Print("📊 Ordre #", ticket, " [", symbol, "] modifié: ", 
                  DoubleToString(currentVolume, 2), " → ", DoubleToString(newVolume, 2), " lots");
            modifiedCount++;
         }
         else
         {
            Print("❌ Échec modification ordre #", ticket, " [", symbol, "]: ", 
                  trade.ResultRetcodeDescription());
            failedCount++;
         }
      }
   }
   
   if(modifiedCount > 0 || failedCount > 0)
   {
      Print("✅ Ordres pending mis à jour: ", modifiedCount, " modifiés, ", failedCount, " échecs");
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════");
   Print("🚀 Initializing Scalping Robot v2.0");
   Print("═══════════════════════════════════════");
   
   // Validation Trailing TP CUSTOM
   if(UseTrailingTP && TrailingTPMode == TRAILING_TP_CUSTOM)
   {
      Print("🔍 Validation Custom Trailing TP...");
      string errorMessage;
      bool isValid = CTrailingTPValidator::ValidateCustomLevelsString(CustomTPLevels, errorMessage);
      
      if(!isValid)
      {
         Print("❌ ERREUR: ", errorMessage);
         Print("💡 Exemple: \"50:0:0, 75:25:50, 100:50:100\"");
         return(INIT_PARAMETERS_INCORRECT);
      }
      
      CTrailingTPValidator::PrintParsedLevels(CustomTPLevels);
      Print(errorMessage);
   }
   
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
   
   // ═══ Step 3.5: Validation des paramètres du multiplicateur ═══
   if(UseRiskMultiplier)
   {
      if(RiskMultFactor < 0.1 || RiskMultFactor > 10.0)
      {
         Print("⚠️ WARNING: RiskMultFactor = ", RiskMultFactor, " est hors limites recommandées [0.1 - 10.0]");
      }
      
      Print("🔥 Risk Multiplier Configuration:");
      Print("   Actif: ", UseRiskMultiplier ? "OUI" : "NON");
      Print("   Plage horaire: ", IntegerToString(RiskMultStartHour), "h - ", IntegerToString(RiskMultEndHour), "h");
      Print("   Multiplicateur: ", DoubleToString(RiskMultFactor, 2), "x");
      Print("   Risque normal: ", DoubleToString(riskPerSymbol, 2), "%");
      Print("   Risque boosté: ", DoubleToString(riskPerSymbol * RiskMultFactor, 2), "%");
      Print("   Mise à jour ordres pending: ", UpdatePendingOrders ? "OUI" : "NON");
   }
   
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
         TrailingTPMode,                // trailing TP mode
         CustomTPLevels,                // custom TP levels
         DisableTslInProfit             // disable TSL in profit NET
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
   
   if(UseTrailingTP)
   {
      Print("🎯 TRAILING TP: ", EnumToString(TrailingTPMode));
      if(TrailingTPMode == TRAILING_TP_CUSTOM)
         Print("   Niveaux: ", CustomTPLevels);
   }
   
   if(DisableTslInProfit)
   {
      Print("🔒 Trailing SL sera DÉSACTIVÉ pour les positions en profit NET");
      Print("   (Profit NET = Profit brut + Commissions + Swap)");
   }
   
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
   
   // Calculer le risque ajusté en fonction de l'heure
   double baseRiskPerSymbol = CalculateRiskPerSymbol(RiskPercent, totalSymbols);
   double adjustedRisk = GetAdjustedRiskPercent(baseRiskPerSymbol, tradingAllowed);
   
   // Détecter si le risque a changé et mettre à jour les ordres pending
   static double previousRisk = 0;
   if(UseRiskMultiplier && UpdatePendingOrders)
   {
      if(MathAbs(adjustedRisk - previousRisk) > 0.0001) // Changement significatif
      {
         Print("🔄 Changement de risque détecté: ", DoubleToString(previousRisk, 2), 
               "% → ", DoubleToString(adjustedRisk, 2), "%");
         UpdatePendingOrdersVolume(adjustedRisk);
         previousRisk = adjustedRisk;
      }
   }
   else
   {
      previousRisk = adjustedRisk;
   }
   
   // Parcourir tous les symboles et traiter leurs ticks
   for(int i = 0; i < totalSymbols; i++)
   {
      if(symbolTraders[i] != NULL)
      {
         // Mettre à jour le risque pour ce symbole
         symbolTraders[i].SetRiskPercent(adjustedRisk);
         
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
   
   // Ajouter l'indicateur du multiplicateur de risque si actif
   if(UseRiskMultiplier && IsCurrentHourInRange(RiskMultStartHour, RiskMultEndHour))
   {
      globalStatus += " | 🔥 RISK ×" + DoubleToString(RiskMultFactor, 1);
   }
   
   // Ajouter indicateur visuel si DisableTslInProfit est actif
   if(DisableTslInProfit)
   {
      globalStatus += " | 🔒 TSL-OFF";
   }
   
   // Couleur basée sur le statut trading et P/L
   color statusColor = clrGreen;
   ENUM_TRADING_STATUS status = timeManager.GetCurrentStatus();
   
   if(status != TRADING_ACTIVE)
      statusColor = clrOrange;  // Trading bloqué
   else if(UseRiskMultiplier && IsCurrentHourInRange(RiskMultStartHour, RiskMultEndHour))
      statusColor = clrGold;    // Multiplicateur de risque actif
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