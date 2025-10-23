//+------------------------------------------------------------------+
//|                                              RSI_Divergence_EA.mq5 |
//|                         RSI Divergence Expert Advisor              |
//+------------------------------------------------------------------+
//| CHANGELOG - Version 1.0                                          |
//| ✅ [FEATURE] Lecture des signaux de l'indicateur RSI_Divergence_Indicator |
//| ✅ [FEATURE] Trading automatique sur Regular et Hidden Divergences |
//| ✅ [FEATURE] Money Management et Risk Management complets         |
//| ✅ [FEATURE] Trailing Stop automatique                           |
//| ✅ [FEATURE] Filtres de tendance optionnels                      |
//| ✅ [FEATURE] Gestion des positions multiples                     |
//| ✅ [FEATURE] Affichage des informations de trading               |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Enums
enum MA_TYPE_CUSTOM
{
   MA_NONE,           // None
   MA_SMA,            // SMA
   MA_SMA_BB,         // SMA + Bollinger Bands
   MA_EMA,            // EMA
   MA_SMMA,           // SMMA (RMA)
   MA_LWMA,           // LWMA
};

//--- Input parameters
input group "═══ Indicateur Settings ═══"
input string InpIndicatorName = "RSI_Divergence_Indicator"; // Nom de l'indicateur
input int    InpRSIPeriod = 3;                              // RSI Period (doit matcher l'indicateur)
input int    InpLookbackLeft = 5;                           // Lookback Left (doit matcher l'indicateur)
input int    InpLookbackRight = 5;                          // Lookback Right (doit matcher l'indicateur)
input int    InpRangeLower = 5;                             // Range Lower (doit matcher l'indicateur)
input int    InpRangeUpper = 60;                            // Range Upper (doit matcher l'indicateur)
input bool   InpShowHiddenDiv = true;                       // Show Hidden Divergences (doit matcher l'indicateur)

input group "═══ Trading Settings ═══"
input bool   InpTradeRegularDiv = true;   // Trade Regular Divergences
input bool   InpTradeHiddenDiv = false;   // Trade Hidden Divergences
input double InpLotSize = 0.01;           // Lot Size
input int    InpStopLoss = 50;            // Stop Loss (points)
input int    InpTakeProfit = 100;         // Take Profit (points)
input int    InpMagicNumber = 123456;     // Magic Number
input string InpTradeComment = "RSI_Div"; // Trade Comment

input group "═══ Risk Management ═══"
input bool   InpUseTrailingStop = true;   // Use Trailing Stop
input int    InpTrailingStop = 30;        // Trailing Stop (points)
input int    InpTrailingStep = 5;         // Trailing Step (points)
input int    InpMaxTrades = 1;            // Max Simultaneous Trades

input group "═══ Filters ═══"
input bool   InpCheckTrend = false;       // Check Trend Filter
input int    InpTrendMAPeriod = 50;       // Trend MA Period
input ENUM_MA_METHOD InpTrendMAMethod = MODE_EMA; // Trend MA Method

input group "═══ Display Settings ═══"
input bool   InpShowInfo = true;          // Show Trading Info
input color  InpInfoColor = clrWhite;     // Info Color

//--- Global variables
CTrade trade;
int indicatorHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
int totalTrades = 0;
int winningTrades = 0;
double totalProfit = 0.0;

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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validation des paramètres
   if(InpLotSize <= 0)
   {
      Print("❌ Erreur: Lot Size doit être > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpStopLoss <= 0 || InpTakeProfit <= 0)
   {
      Print("❌ Erreur: Stop Loss et Take Profit doivent être > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpMaxTrades <= 0)
   {
      Print("❌ Erreur: Max Trades doit être > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Configuration du trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Charger l'indicateur
   indicatorHandle = iCustom(_Symbol, _Period, InpIndicatorName,
                            InpRSIPeriod,           // RSI Period
                            PRICE_CLOSE,           // Applied Price
                            true,                  // Show Levels
                            90.0,                  // Upper Level
                            50.0,                  // Middle Level
                            10.0,                  // Lower Level
                            clrSilver,             // Level Color
                            MA_NONE,               // MA Type
                            14,                    // MA Length
                            2.0,                   // BB StdDev
                            InpLookbackLeft,       // Lookback Left
                            InpLookbackRight,      // Lookback Right
                            InpRangeLower,         // Range Lower
                            InpRangeUpper,         // Range Upper
                            true,                  // Show Trendlines
                            clrLimeGreen,          // Bullish Color
                            clrRed,                // Bearish Color
                            2,                     // Trendline Width
                            InpShowHiddenDiv,      // Show Hidden Div
                            clrDodgerBlue,         // Hidden Bull Color
                            clrOrange,             // Hidden Bear Color
                            2,                     // Hidden Trend Width
                            STYLE_DASH,            // Hidden Line Style
                            50,                    // Max Trendlines
                            100);                  // Max Bars Check
   
   if(indicatorHandle == INVALID_HANDLE)
   {
      Print("❌ Erreur: Impossible de charger l'indicateur ", InpIndicatorName);
      Print("Vérifiez que l'indicateur est compilé et dans le bon dossier");
      return INIT_FAILED;
   }
   
   // Initialiser les statistiques
   stats.totalTrades = 0;
   stats.winningTrades = 0;
   stats.losingTrades = 0;
   stats.totalProfit = 0.0;
   stats.winRate = 0.0;
   stats.profitFactor = 0.0;
   stats.lastTradeTime = 0;
   stats.lastSignal = "None";
   
   Print("✅ RSI Divergence EA Initialized!");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Indicator Handle: ", indicatorHandle);
   Print("Magic Number: ", InpMagicNumber);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);
   
   Print("RSI Divergence EA stopped. Reason: ", reason);
   Print("Total Trades: ", stats.totalTrades);
   Print("Win Rate: ", DoubleToString(stats.winRate, 2), "%");
   Print("Total Profit: ", DoubleToString(stats.totalProfit, 2));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier nouvelle barre
   if(!IsNewBar())
      return;
   
   // Gérer les positions ouvertes
   ManageOpenPositions();
   
   // Vérifier les signaux
   CheckForSignals();
   
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
//| Check for trading signals from indicator                        |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // Vérifier qu'on n'a pas déjà le maximum de trades
   if(CountOpenPositions() >= InpMaxTrades)
      return;
   
   // Lire les buffers de signaux de l'indicateur
   double bullSignal[], bearSignal[], hiddenBullSignal[], hiddenBearSignal[];
   ArraySetAsSeries(bullSignal, true);
   ArraySetAsSeries(bearSignal, true);
   ArraySetAsSeries(hiddenBullSignal, true);
   ArraySetAsSeries(hiddenBearSignal, true);
   
   // Copier les buffers 10-13 de l'indicateur
   if(CopyBuffer(indicatorHandle, 10, 0, 3, bullSignal) <= 0 ||
      CopyBuffer(indicatorHandle, 11, 0, 3, bearSignal) <= 0 ||
      CopyBuffer(indicatorHandle, 12, 0, 3, hiddenBullSignal) <= 0 ||
      CopyBuffer(indicatorHandle, 13, 0, 3, hiddenBearSignal) <= 0)
   {
      Print("⚠️ Erreur: Impossible de lire les buffers de l'indicateur");
      return;
   }
   
   // Vérifier les signaux Regular Bullish (nouveau signal)
   if(InpTradeRegularDiv && bullSignal[1] == 1.0 && bullSignal[2] == 0.0)
   {
      if(CheckTrendFilter(true) && !HasOpenPosition(POSITION_TYPE_BUY))
      {
         OpenTrade(ORDER_TYPE_BUY, "Regular Bullish Divergence");
         stats.lastSignal = "Regular Bullish";
      }
   }
   
   // Vérifier les signaux Regular Bearish (nouveau signal)
   if(InpTradeRegularDiv && bearSignal[1] == 1.0 && bearSignal[2] == 0.0)
   {
      if(CheckTrendFilter(false) && !HasOpenPosition(POSITION_TYPE_SELL))
      {
         OpenTrade(ORDER_TYPE_SELL, "Regular Bearish Divergence");
         stats.lastSignal = "Regular Bearish";
      }
   }
   
   // Vérifier les signaux Hidden Bullish (nouveau signal)
   if(InpTradeHiddenDiv && hiddenBullSignal[1] == 1.0 && hiddenBullSignal[2] == 0.0)
   {
      if(CheckTrendFilter(true) && !HasOpenPosition(POSITION_TYPE_BUY))
      {
         OpenTrade(ORDER_TYPE_BUY, "Hidden Bullish Divergence");
         stats.lastSignal = "Hidden Bullish";
      }
   }
   
   // Vérifier les signaux Hidden Bearish (nouveau signal)
   if(InpTradeHiddenDiv && hiddenBearSignal[1] == 1.0 && hiddenBearSignal[2] == 0.0)
   {
      if(CheckTrendFilter(false) && !HasOpenPosition(POSITION_TYPE_SELL))
      {
         OpenTrade(ORDER_TYPE_SELL, "Hidden Bearish Divergence");
         stats.lastSignal = "Hidden Bearish";
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
//| Open a trade                                                     |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType, string signalType)
{
   double price, sl, tp;
   string symbol = _Symbol;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      sl = (InpStopLoss > 0) ? price - InpStopLoss * _Point : 0;
      tp = (InpTakeProfit > 0) ? price + InpTakeProfit * _Point : 0;
   }
   else
   {
      price = SymbolInfoDouble(symbol, SYMBOL_BID);
      sl = (InpStopLoss > 0) ? price + InpStopLoss * _Point : 0;
      tp = (InpTakeProfit > 0) ? price - InpTakeProfit * _Point : 0;
   }
   
   // Normaliser les prix
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Vérifier les limites de prix
   if(!CheckPriceLimits(price, sl, tp))
   {
      Print("⚠️ Trade rejeté: Limites de prix non respectées");
      return;
   }
   
   // Ouvrir la position
   if(trade.PositionOpen(symbol, orderType, InpLotSize, price, sl, tp, InpTradeComment))
   {
      stats.totalTrades++;
      stats.lastTradeTime = TimeCurrent();
      
      Print("✅ Trade ouvert: ", signalType);
      Print("Type: ", EnumToString(orderType));
      Print("Lot: ", InpLotSize);
      Print("Price: ", DoubleToString(price, _Digits));
      if(sl > 0) Print("SL: ", DoubleToString(sl, _Digits));
      if(tp > 0) Print("TP: ", DoubleToString(tp, _Digits));
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
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   if(!InpUseTrailingStop)
      return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol)
         continue;
         
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double newSL = 0;
      bool shouldModify = false;
      
      if(posType == POSITION_TYPE_BUY)
      {
         double trailPrice = currentPrice - InpTrailingStop * _Point;
         if(trailPrice > openPrice && trailPrice > PositionGetDouble(POSITION_SL))
         {
            newSL = NormalizeDouble(trailPrice, _Digits);
            shouldModify = true;
         }
      }
      else
      {
         double trailPrice = currentPrice + InpTrailingStop * _Point;
         if(trailPrice < openPrice && (PositionGetDouble(POSITION_SL) == 0 || trailPrice < PositionGetDouble(POSITION_SL)))
         {
            newSL = NormalizeDouble(trailPrice, _Digits);
            shouldModify = true;
         }
      }
      
      if(shouldModify)
      {
         if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
         {
            Print("✅ Trailing Stop modifié - Ticket: ", ticket, " New SL: ", DoubleToString(newSL, _Digits));
         }
      }
   }
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
   
   string info = StringFormat(
      "=== RSI DIVERGENCE EA ===\n" +
      "Symbol: %s | TF: %s\n" +
      "Open Positions: %d/%d\n" +
      "Total Trades: %d | Win Rate: %.1f%%\n" +
      "Total Profit: %.2f %s\n" +
      "Last Signal: %s\n" +
      "Magic: %d | Lot: %.2f\n" +
      "SL: %d pts | TP: %d pts\n" +
      "Trailing: %s (%d pts)\n" +
      "Time: %s",
      _Symbol,
      EnumToString(_Period),
      CountOpenPositions(),
      InpMaxTrades,
      stats.totalTrades,
      stats.winRate,
      stats.totalProfit,
      AccountInfoString(ACCOUNT_CURRENCY),
      stats.lastSignal,
      InpMagicNumber,
      InpLotSize,
      InpStopLoss,
      InpTakeProfit,
      (InpUseTrailingStop) ? "ON" : "OFF",
      InpTrailingStop,
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
