//+------------------------------------------------------------------+
//|                                    RSI_Divergence_EA_Autonomous.mq5 |
//|                         RSI Divergence Expert Advisor (Autonomous)   |
//+------------------------------------------------------------------+
//| Version: 2.0 - Architecture modulaire avec classes MQH            |
//| Changelog:                                                       |
//| ✅ [ARCHITECTURE] Utilisation des classes MQH modulaires          |
//| ✅ [PERFORMANCE] Calcul RSI direct sans dépendance indicateur     |
//| ✅ [PERFORMANCE] Détection divergences intégrée dans l'EA         |
//| ✅ [FEATURE] Support Regular et Hidden Divergences                |
//| ✅ [FEATURE] Money Management et Risk Management complets         |
//| ✅ [FEATURE] Trailing Stop automatique                           |
//| ✅ [FEATURE] Filtres de tendance optionnels                      |
//| ✅ [FEATURE] Gestion des positions multiples                     |
//| ✅ [FEATURE] Affichage des informations de trading               |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <../Shared/TrailingTP_System.mqh>
#include <Shared\RSI_Calculator.mqh>
#include <Shared\Pivot_Detector.mqh>
#include <Shared\Divergence_Detector.mqh>

//--- Énumération pour la direction des trades
enum ENUM_TRADE_DIRECTION
{
   TRADE_BOTH = 0,    // Both Buy and Sell
   TRADE_BUY_ONLY,    // Buy Only
   TRADE_SELL_ONLY    // Sell Only
};

//--- Input parameters
input group "═══ Trading Settings ═══"
input bool   InpTradeRegularDiv = true;   // Trade Regular Divergences
input bool   InpTradeHiddenDiv = true;    // Trade Hidden Divergences
input ENUM_TRADE_DIRECTION InpTradeDirection = TRADE_BOTH; // Trade Direction

input group "═══ RSI Settings ═══"
input int    InpRSIPeriod = 3;            // RSI Period
input ENUM_APPLIED_PRICE InpRSIAppliedPrice = PRICE_CLOSE; // RSI Applied Price

input group "═══ Divergence Settings ═══"
input int    InpLookbackLeft = 3;         // Lookback Left
input int    InpLookbackRight = 1;        // Lookback Right
input int    InpRangeLower = 3;           // Range Lower
input int    InpRangeUpper = 100;         // Range Upper

input group "═══ Money Management ═══"
input double InpRiskPercent = 1.0;        // Risk per Trade (% of Balance)
input double InpStopLossPercent = 0.10;   // Stop Loss (% of Price)
input double InpRiskReward = 1.5;         // Risk:Reward Ratio
input int    InpMagicNumber = 123456;     // Magic Number
input int    InpMaxTrades = 1;            // Max Simultaneous Trades

input group "═══ Filters ═══"
input bool   InpCheckTrend = false;       // Check Trend Filter
input int    InpTrendMAPeriod = 50;       // Trend MA Period
input ENUM_MA_METHOD InpTrendMAMethod = MODE_EMA; // Trend MA Method

input group "═══ Trailing TP Settings ═══"
input bool   InpEnableTrailingTP = true;                    // Enable Trailing TP
input ENUM_TRAILING_TP_MODE InpTrailingMode = TRAILING_TP_STEPPED; // Trailing Mode
input string InpCustomLevels = "50:0:0,75:50:25,100:75:50"; // Custom Levels (si CUSTOM)

input group "═══ Display Settings ═══"
input bool   InpShowInfo = true;          // Show Trading Info
input color  InpInfoColor = clrWhite;     // Info Color

//--- Global variables
CTrade trade;
datetime lastBarTime = 0;
int totalTrades = 0;
int winningTrades = 0;
double totalProfit = 0.0;

//--- Instances des classes modulaires
CRSICalculator* rsiCalculator = NULL;
CPivotDetector* pivotDetector = NULL;
CDivergenceDetector* divergenceDetector = NULL;

//--- Trading statistics
struct TradingStats
{
   int totalTrades;
   int winningTrades;
   int losingTrades;
   double totalProfit;
   double winRate;
   double profitFactor;
   datetime lastTradeTime;
   string lastSignal;
};

TradingStats stats;

//--- Structure de suivi des positions avec trailing
struct PositionTrailing
{
   ulong ticket;
   CTrailingTP* trailingSystem;
   bool isActive;
};

PositionTrailing trailingPositions[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validation des paramètres
   if(InpRiskPercent <= 0 || InpRiskPercent > 10)
   {
      Print("❌ Erreur: Risk Percent doit être entre 0.1 et 10%");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpStopLossPercent <= 0 || InpStopLossPercent > 5)
   {
      Print("❌ Erreur: Stop Loss Percent doit être entre 0.01 et 5%");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpRiskReward <= 0 || InpRiskReward > 10)
   {
      Print("❌ Erreur: Risk Reward doit être entre 0.5 et 10");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpMaxTrades <= 0)
   {
      Print("❌ Erreur: Max Trades doit être > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Valider les custom levels si mode CUSTOM
   if(InpEnableTrailingTP && InpTrailingMode == TRAILING_TP_CUSTOM)
   {
      string errorMsg;
      if(!CTrailingTPValidator::ValidateCustomLevelsString(InpCustomLevels, errorMsg))
      {
         Print("❌ Configuration Trailing TP invalide:");
         Print(errorMsg);
         return INIT_PARAMETERS_INCORRECT;
      }
      
      Print("✅ Configuration Trailing TP validée:");
      CTrailingTPValidator::PrintParsedLevels(InpCustomLevels);
   }
   
   // Afficher la configuration de direction
   Print("═══ CONFIGURATION DIRECTION ═══");
   switch(InpTradeDirection)
   {
      case TRADE_BOTH:
         Print("✅ Trading autorisé: BUY et SELL");
         break;
      case TRADE_BUY_ONLY:
         Print("⬆️ Trading autorisé: BUY UNIQUEMENT");
         break;
      case TRADE_SELL_ONLY:
         Print("⬇️ Trading autorisé: SELL UNIQUEMENT");
         break;
   }
   Print("═══════════════════════════════");
   
   // Configuration du trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialiser les classes modulaires
   Print("🔧 Initialisation des classes modulaires...");
   
   // 1. Calculateur RSI
   rsiCalculator = new CRSICalculator(InpRSIPeriod, InpRSIAppliedPrice);
   if(rsiCalculator == NULL)
   {
      Print("❌ Erreur: Impossible de créer CRSICalculator");
      return INIT_FAILED;
   }
   Print("✅ CRSICalculator initialisé - Période: ", InpRSIPeriod);
   
   // 2. Détecteur de pivots
   pivotDetector = new CPivotDetector(InpLookbackLeft, InpLookbackRight);
   if(pivotDetector == NULL)
   {
      Print("❌ Erreur: Impossible de créer CPivotDetector");
      return INIT_FAILED;
   }
   Print("✅ CPivotDetector initialisé - Lookback: ", InpLookbackLeft, "/", InpLookbackRight);
   
   // 3. Détecteur de divergences
   divergenceDetector = new CDivergenceDetector(InpRangeLower, InpRangeUpper, pivotDetector);
   if(divergenceDetector == NULL)
   {
      Print("❌ Erreur: Impossible de créer CDivergenceDetector");
      return INIT_FAILED;
   }
   Print("✅ CDivergenceDetector initialisé - Range: ", InpRangeLower, "-", InpRangeUpper);
   
   // Initialiser les statistiques
   stats.totalTrades = 0;
   stats.winningTrades = 0;
   stats.losingTrades = 0;
   stats.totalProfit = 0.0;
   stats.winRate = 0.0;
   stats.profitFactor = 0.0;
   stats.lastTradeTime = 0;
   stats.lastSignal = "None";
   
   Print("✅ RSI Divergence EA Autonomous Initialized!");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Magic Number: ", InpMagicNumber);
   Print("Architecture: Modulaire avec classes MQH");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libérer les instances des classes
   if(rsiCalculator != NULL)
   {
      delete rsiCalculator;
      rsiCalculator = NULL;
   }
   
   if(pivotDetector != NULL)
   {
      delete pivotDetector;
      pivotDetector = NULL;
   }
   
   if(divergenceDetector != NULL)
   {
      delete divergenceDetector;
      divergenceDetector = NULL;
   }
   
   // Libérer les objets trailing
   for(int i = 0; i < ArraySize(trailingPositions); i++)
   {
      if(trailingPositions[i].trailingSystem != NULL)
         delete trailingPositions[i].trailingSystem;
   }
   ArrayFree(trailingPositions);
   
   Print("RSI Divergence EA Autonomous stopped. Reason: ", reason);
   Print("Total Trades: ", stats.totalTrades);
   Print("Win Rate: ", DoubleToString(stats.winRate, 2), "%");
   Print("Total Profit: ", DoubleToString(stats.totalProfit, 2));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Appeler à chaque tick pour détection immédiate des signaux
   CheckForSignals();
   
   // Ajouter la mise à jour du trailing
   if(InpEnableTrailingTP)
      UpdateAllTrailingPositions();
   
   // Afficher les informations
   if(InpShowInfo)
      DisplayTradingInfo();
}

//+------------------------------------------------------------------+
//| Check if new bar formed                                         |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for trading signals using modular classes                 |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // Vérifier qu'on n'a pas déjà le maximum de trades
   if(CountOpenPositions() >= InpMaxTrades)
      return;
   
   // Vérifier qu'on a une nouvelle barre
   if(!IsNewBar())
      return;
   
   // Vérifier qu'on a assez de barres
   int availableBars = Bars(_Symbol, _Period);
   if(availableBars < InpRSIPeriod + InpRangeUpper + 20)
      return;
   
   // Copier les données de prix
   double close[], high[], low[];
   datetime time[];
   
   ArrayResize(close, availableBars);
   ArrayResize(high, availableBars);
   ArrayResize(low, availableBars);
   ArrayResize(time, availableBars);
   
   if(CopyClose(_Symbol, _Period, 0, availableBars, close) <= 0 ||
      CopyHigh(_Symbol, _Period, 0, availableBars, high) <= 0 ||
      CopyLow(_Symbol, _Period, 0, availableBars, low) <= 0 ||
      CopyTime(_Symbol, _Period, 0, availableBars, time) <= 0)
   {
      Print("❌ Erreur: Impossible de copier les données de prix");
      return;
   }
   
   // Calculer le RSI
   if(!rsiCalculator.Calculate(availableBars, 0, close))
   {
      Print("❌ Erreur: Échec du calcul RSI");
      return;
   }
   
   // Obtenir le buffer RSI
   double rsiBuffer[];
   if(!rsiCalculator.GetBuffer(rsiBuffer, 0, availableBars))
   {
      Print("❌ Erreur: Impossible d'obtenir le buffer RSI");
      return;
   }
   
   // Définir la zone de recherche des divergences
   int startPos = InpLookbackRight + 1;
   int endPos = MathMin(50, availableBars - InpRangeUpper - InpLookbackLeft - 1);
   
   if(startPos > endPos)
      return;
   
   // Scanner les divergences
   SDivergenceResult results[];
   int found = divergenceDetector.ScanDivergences(startPos, endPos, rsiBuffer, high, low, time, results);
   
   if(found > 0)
   {
      Print("🎯 ", found, " divergence(s) trouvée(s)");
      
      // Traiter chaque divergence trouvée
      for(int i = 0; i < found; i++)
      {
         if(!results[i].found || !results[i].isValid)
            continue;
         
         // Vérifier si on doit trader ce type de divergence
         bool shouldTrade = false;
         string signalType = "";
         bool isBuySignal = false;
         
         switch(results[i].type)
         {
            case DIVERGENCE_REGULAR_BULL:
               if(InpTradeRegularDiv)
               {
                  shouldTrade = true;
                  signalType = "Regular Bullish Divergence";
                  isBuySignal = true;
               }
               break;
               
            case DIVERGENCE_REGULAR_BEAR:
               if(InpTradeRegularDiv)
               {
                  shouldTrade = true;
                  signalType = "Regular Bearish Divergence";
                  isBuySignal = false;
               }
               break;
               
            case DIVERGENCE_HIDDEN_BULL:
               if(InpTradeHiddenDiv)
               {
                  shouldTrade = true;
                  signalType = "Hidden Bullish Divergence";
                  isBuySignal = true;
               }
               break;
               
            case DIVERGENCE_HIDDEN_BEAR:
               if(InpTradeHiddenDiv)
               {
                  shouldTrade = true;
                  signalType = "Hidden Bearish Divergence";
                  isBuySignal = false;
               }
               break;
         }
         
         if(!shouldTrade)
            continue;
         
         // Vérifier la direction du trade
         if(!IsTradeDirectionAllowed(isBuySignal))
         {
            Print("⚠️ Signal ", signalType, " ignoré - Direction non autorisée");
            continue;
         }
         
         // Vérifier les filtres et positions existantes
         ENUM_POSITION_TYPE posType = isBuySignal ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         
         if(!CheckTrendFilter(isBuySignal) || HasOpenPosition(posType))
            continue;
         
         // Ouvrir le trade
         ENUM_ORDER_TYPE orderType = isBuySignal ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         OpenTrade(orderType, signalType);
         stats.lastSignal = signalType;
         
         Print("✅ Trade ouvert: ", signalType);
         Print("   RSI: ", DoubleToString(results[i].currentRSI, 2));
         Print("   Prix: ", DoubleToString(results[i].currentPrice, _Digits));
         break; // Traiter seulement la première divergence trouvée
      }
   }
}

//+------------------------------------------------------------------+
//| Check trend filter                                               |
//+------------------------------------------------------------------+
bool CheckTrendFilter(bool isBuySignal)
{
   if(!InpCheckTrend)
      return true;
   
   int maHandle = iMA(_Symbol, _Period, InpTrendMAPeriod, 0, InpTrendMAMethod, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE)
      return true; // Si erreur, autoriser le trade
   
   double maValues[];
   ArraySetAsSeries(maValues, true);
   
   if(CopyBuffer(maHandle, 0, 0, 2, maValues) <= 0)
   {
      IndicatorRelease(maHandle);
      return true;
   }
   
   double currentPrice = (isBuySignal) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentMA = maValues[0];
   
   IndicatorRelease(maHandle);
   
   // Pour un signal d'achat, le prix doit être au-dessus de la MA
   // Pour un signal de vente, le prix doit être en-dessous de la MA
   if(isBuySignal)
      return currentPrice > currentMA;
   else
      return currentPrice < currentMA;
}

//+------------------------------------------------------------------+
//| Check if trade direction is allowed                             |
//+------------------------------------------------------------------+
bool IsTradeDirectionAllowed(bool isBuySignal)
{
   // Si Both, toujours autoriser
   if(InpTradeDirection == TRADE_BOTH)
      return true;
   
   // Si Buy Only, autoriser uniquement les signaux d'achat
   if(InpTradeDirection == TRADE_BUY_ONLY)
      return isBuySignal;
   
   // Si Sell Only, autoriser uniquement les signaux de vente
   if(InpTradeDirection == TRADE_SELL_ONLY)
      return !isBuySignal;
   
   return false;
}

//+------------------------------------------------------------------+
//| Open a trade                                                     |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType, string signalType)
{
   double price, sl, tp;
   string symbol = _Symbol;
   string comment = "RSI_Div_Modular";
   
   // Modifier le commentaire pour Hidden Divergences
   if(StringFind(signalType, "Hidden") >= 0)
      comment = "RSI_Div_H_Modular";
   
   // Obtenir le prix d'entrée
   if(orderType == ORDER_TYPE_BUY)
      price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   else
      price = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Calculer le Stop Loss en % du prix
   double slDistance = price * InpStopLossPercent / 100.0;
   
   if(orderType == ORDER_TYPE_BUY)
      sl = price - slDistance;
   else
      sl = price + slDistance;
   
   // Calculer le Take Profit basé sur le Risk:Reward ratio
   double tpDistance = slDistance * InpRiskReward;
   
   if(orderType == ORDER_TYPE_BUY)
      tp = price + tpDistance;
   else
      tp = price - tpDistance;
   
   // Normaliser les prix
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Calculer la taille du lot basée sur le risque en %
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * InpRiskPercent / 100.0;
   
   // Calculer la valeur d'un point
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = tickValue / tickSize * _Point;
   
   // Calculer le lot size
   double slPoints = MathAbs(price - sl) / _Point;
   double lotSize = riskAmount / (slPoints * pointValue);
   
   // Normaliser le lot size
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Vérifier les limites de prix
   if(!CheckPriceLimits(price, sl, tp))
   {
      Print("⚠️ Trade rejeté: Limites de prix non respectées");
      return;
   }
   
   // Ouvrir la position
   if(trade.PositionOpen(symbol, orderType, lotSize, price, sl, tp, comment))
   {
      stats.totalTrades++;
      stats.lastTradeTime = TimeCurrent();
      
      Print("✅ Trade ouvert: ", signalType);
      Print("Direction: ", (orderType == ORDER_TYPE_BUY ? "⬆️ BUY" : "⬇️ SELL"));
      Print("Type: ", EnumToString(orderType));
      Print("Lot: ", DoubleToString(lotSize, 2), " (", DoubleToString(InpRiskPercent, 2), "% risque)");
      Print("Price: ", DoubleToString(price, _Digits));
      Print("SL: ", DoubleToString(sl, _Digits), " (", DoubleToString(InpStopLossPercent, 2), "%)");
      Print("TP: ", DoubleToString(tp, _Digits), " (RR 1:", DoubleToString(InpRiskReward, 1), ")");
      Print("Risk: ", DoubleToString(riskAmount, 2), " ", AccountInfoString(ACCOUNT_CURRENCY));
      
      // Initialiser le trailing TP
      if(InpEnableTrailingTP)
      {
         ulong ticket = trade.ResultOrder();
         InitializeTrailingForPosition(ticket, price, sl, tp, orderType == ORDER_TYPE_BUY);
      }
   }
   else
   {
      Print("❌ Erreur ouverture trade: ", trade.ResultRetcode());
      Print("Description: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Check price limits                                               |
//+------------------------------------------------------------------+
bool CheckPriceLimits(double price, double sl, double tp)
{
   double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   
   if(sl > 0)
   {
      if(MathAbs(price - sl) < minDistance)
         return false;
   }
   
   if(tp > 0)
   {
      if(MathAbs(price - tp) < minDistance)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Count open positions                                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if position of specific type is open                      |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_POSITION_TYPE posType)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetInteger(POSITION_TYPE) == posType)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Display trading information                                      |
//+------------------------------------------------------------------+
void DisplayTradingInfo()
{
   // Mettre à jour les statistiques
   UpdateTradingStats();
   
   // Informations sur le trailing TP
   string trailingInfo = "";
   if(InpEnableTrailingTP)
   {
      int activeTrailing = 0;
      for(int i = 0; i < ArraySize(trailingPositions); i++)
      {
         if(trailingPositions[i].isActive)
            activeTrailing++;
      }
      
      trailingInfo = StringFormat(
         "═══ TRAILING TP ═══\n" +
         "Mode: %s\n" +
         "Active: %d position(s)\n",
         EnumToString(InpTrailingMode),
         activeTrailing
      );
   }
   
   string info = StringFormat(
      "=== RSI DIVERGENCE EA AUTONOMOUS ===\n" +
      "Symbol: %s | TF: %s\n" +
      "Direction: %s\n" +
      "Open Positions: %d/%d\n" +
      "Total Trades: %d | Win Rate: %.1f%%\n" +
      "Total Profit: %.2f %s\n" +
      "Last Signal: %s\n" +
      "═══ MONEY MANAGEMENT ═══\n" +
      "Risk per Trade: %.2f%% (%.2f %s)\n" +
      "Stop Loss: %.2f%% of Price\n" +
      "Risk:Reward: 1:%.1f\n" +
      "Magic: %d\n" +
      "%s" +
      "Time: %s",
      _Symbol,
      EnumToString(_Period),
      EnumToString(InpTradeDirection),
      CountOpenPositions(),
      InpMaxTrades,
      stats.totalTrades,
      stats.winRate,
      stats.totalProfit,
      AccountInfoString(ACCOUNT_CURRENCY),
      stats.lastSignal,
      InpRiskPercent,
      AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0,
      AccountInfoString(ACCOUNT_CURRENCY),
      InpStopLossPercent,
      InpRiskReward,
      InpMagicNumber,
      trailingInfo,
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
   );
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| Update trading statistics                                        |
//+------------------------------------------------------------------+
void UpdateTradingStats()
{
   // Calculer le profit total des positions fermées
   double totalProfit = 0.0;
   int winningTrades = 0;
   int losingTrades = 0;
   
   // Parcourir l'historique des trades
   HistorySelect(0, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket <= 0) continue;
      
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT) continue; // Seulement les sorties
      
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      totalProfit += profit;
      
      if(profit > 0)
         winningTrades++;
      else if(profit < 0)
         losingTrades++;
   }
   
   stats.totalProfit = totalProfit;
   stats.winningTrades = winningTrades;
   stats.losingTrades = losingTrades;
   
   int totalClosedTrades = winningTrades + losingTrades;
   if(totalClosedTrades > 0)
   {
      stats.winRate = (double)winningTrades / totalClosedTrades * 100.0;
      
      double totalLoss = 0.0;
      // Recalculer les pertes pour le profit factor
      for(int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket <= 0) continue;
         
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
         
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(dealEntry != DEAL_ENTRY_OUT) continue;
         
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(profit < 0)
            totalLoss += MathAbs(profit);
      }
      
      if(totalLoss > 0)
         stats.profitFactor = totalProfit / totalLoss;
      else
         stats.profitFactor = (totalProfit > 0) ? 999.0 : 0.0;
   }
}

//+------------------------------------------------------------------+
//| Initialize trailing for a position                              |
//+------------------------------------------------------------------+
void InitializeTrailingForPosition(ulong ticket, double entryPrice, double sl, double tp, bool isBuy)
{
   // Créer une nouvelle instance
   CTrailingTP* trailing = new CTrailingTP(InpTrailingMode, InpCustomLevels);
   
   // Initialiser avec les données de la position
   if(!trailing.Initialize(entryPrice, sl, tp, isBuy))
   {
      Print("❌ Échec initialisation Trailing TP pour ticket #", ticket);
      delete trailing;
      return;
   }
   
   // Ajouter à la liste de suivi
   int size = ArraySize(trailingPositions);
   ArrayResize(trailingPositions, size + 1);
   
   trailingPositions[size].ticket = ticket;
   trailingPositions[size].trailingSystem = trailing;
   trailingPositions[size].isActive = true;
   
   Print("✅ Trailing TP activé pour position #", ticket, " - Mode: ", EnumToString(InpTrailingMode));
}

//+------------------------------------------------------------------+
//| Update all trailing positions                                    |
//+------------------------------------------------------------------+
void UpdateAllTrailingPositions()
{
   for(int i = ArraySize(trailingPositions) - 1; i >= 0; i--)
   {
      if(!trailingPositions[i].isActive)
         continue;
      
      ulong ticket = trailingPositions[i].ticket;
      
      // Vérifier si la position existe toujours
      if(!PositionSelectByTicket(ticket))
      {
         // Position fermée - nettoyer
         delete trailingPositions[i].trailingSystem;
         trailingPositions[i].isActive = false;
         continue;
      }
      
      // Récupérer le prix actuel
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      // Mettre à jour le trailing
      double newSL, newTP;
      if(trailingPositions[i].trailingSystem.Update(currentPrice, newSL, newTP))
      {
         // Modifier la position
         if(trade.PositionModify(ticket, newSL, newTP))
         {
            Print("✅ Position #", ticket, " modifiée - Nouveau SL: ", newSL, " | TP: ", newTP);
         }
         else
         {
            Print("⚠️ Échec modification position #", ticket, " - Erreur: ", trade.ResultRetcode());
         }
      }
   }
}

//+------------------------------------------------------------------+
