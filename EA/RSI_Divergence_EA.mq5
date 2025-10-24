//+------------------------------------------------------------------+
//|                                              RSI_Divergence_EA.mq5 |
//|                         RSI Divergence Expert Advisor              |
//+------------------------------------------------------------------+
//| CHANGELOG - Version 1.1                                          |
//| ✅ [FEATURE] Lecture des signaux de l'indicateur RSI_Divergence_Indicator |
//| ✅ [FEATURE] Trading automatique sur Regular et Hidden Divergences |
//| ✅ [FEATURE] Money Management et Risk Management complets         |
//| ✅ [FEATURE] Trailing Stop automatique                           |
//| ✅ [FEATURE] Filtres de tendance optionnels                      |
//| ✅ [FEATURE] Gestion des positions multiples                     |
//| ✅ [FEATURE] Affichage des informations de trading               |
//| ✅ [PERFORMANCE] Support indicateur optimisé NoGUI pour backtesting |
//| ✅ [PERFORMANCE] Optimisation lecture buffer (2 barres au lieu de 3) |
//| ✅ [PERFORMANCE] Vérifications statiques pour éviter recalculs    |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.10"

#include <Trade\Trade.mqh>
#include <../Shared/TrailingTP_System.mqh>

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
input bool   InpTradeHiddenDiv = true;    // Trade Hidden Divergences (activé pour test)
input ENUM_TRADE_DIRECTION InpTradeDirection = TRADE_BOTH; // Trade Direction

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

input group "═══ Performance Settings ═══"
input bool   InpUseOptimizedIndicator = true; // Use No-GUI Version (faster backtesting)

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
   
// Charger l'indicateur avec choix de version optimisée
string indicatorName = InpUseOptimizedIndicator ? 
                      "RSI_Divergence_Indicator_NoGUI" : 
                      "RSI_Divergence_Indicator";

indicatorHandle = iCustom(_Symbol, _Period, indicatorName,
                        3,                    // RSI Period
                        PRICE_CLOSE,          // Applied Price
                        // RSI Levels
                        90.0,                 // Upper Level
                        10.0,                 // Lower Level
                        // Divergence Settings (paramètres de test)
                        3,                    // Lookback Left (réduit)
                        1,                    // Lookback Right (délai réduit)
                        3,                    // Range Lower (réduit)
                        100);                 // Range Upper (augmenté)

if(indicatorHandle == INVALID_HANDLE)
{
   Print("❌ Erreur: Impossible de charger l'indicateur ", indicatorName);
   Print("   Vérifiez que l'indicateur est compilé et dans le dossier Indicators/");
   Print("   Chemin utilisé: ", indicatorName);
   Print("   Version optimisée: ", (InpUseOptimizedIndicator ? "OUI" : "NON"));
   Print("   Erreur code: ", GetLastError());
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
   Print("Version optimisée: ", (InpUseOptimizedIndicator ? "OUI (NoGUI)" : "NON (Standard)"));
   
   Print("✅ Indicateur chargé, handle: ", indicatorHandle);
   Print("⏳ Test de lecture du buffer 7 de signaux...");
   
   // Attendre un peu pour la synchronisation
   Sleep(500);
   
   // Tester la lecture
   double testSignal[];
   ArraySetAsSeries(testSignal, true);
   int testCopy = CopyBuffer(indicatorHandle, 7, 0, 1, testSignal);
   
   if(testCopy > 0)
   {
      Print("✅ Buffer 7 de signaux accessible, valeur actuelle: ", testSignal[0]);
   }
   else
   {
      Print("⚠️ Buffer pas encore prêt (normal au démarrage), code erreur: ", GetLastError());
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);
   
   // Libérer les objets trailing
   for(int i = 0; i < ArraySize(trailingPositions); i++)
   {
      if(trailingPositions[i].trailingSystem != NULL)
         delete trailingPositions[i].trailingSystem;
   }
   ArrayFree(trailingPositions);
   
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
//| Check for trading signals from indicator                        |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // Vérifier qu'on n'a pas déjà le maximum de trades
   if(CountOpenPositions() >= InpMaxTrades)
      return;
   
   // ═══ PHASE 1 : VÉRIFICATIONS PRÉLIMINAIRES ═══
   
   // Vérifier que l'indicateur a terminé ses calculs
   int barsCalculated = BarsCalculated(indicatorHandle);
   if(barsCalculated <= 0)
      return;
   
   // Vérifier qu'on a assez de barres
   int availableBars = Bars(_Symbol, _Period);
   if(barsCalculated < availableBars - 5)
      return;
   
   // ═══ PHASE 2 : LECTURE DU BUFFER ═══
   
   // ✅ ATTENDRE que l'indicateur ait calculé TOUTES les barres
   int maxWait = 10;  // Maximum 10 tentatives
   while(barsCalculated < availableBars - 2 && maxWait > 0)
   {
      Sleep(100);  // Attendre 100ms
      barsCalculated = BarsCalculated(indicatorHandle);
      maxWait--;
   }

   if(barsCalculated < availableBars - 5)
   {
      Print("⚠️ Indicateur pas prêt - Attente...");
      return;
   }
   
   double signalBuffer[];
   ArraySetAsSeries(signalBuffer, true);
   ArrayResize(signalBuffer, 10);  // ✅ DEBUG: Lire 10 barres pour couvrir toutes les positions
   ArrayInitialize(signalBuffer, 0.0);  // Initialiser à zéro
   
   // Lecture du buffer
   ResetLastError();
   int copied = CopyBuffer(indicatorHandle, 7, 0, 10, signalBuffer);  // ✅ DEBUG: Lire 10 barres
   int lastError = GetLastError();
   
   if(copied <= 0)
   {
      Print("❌ Échec lecture buffer - Code erreur: ", lastError);
      return;
   }
   
   // ═══ PHASE 3 : DÉTECTION IMMÉDIATE DU SIGNAL ═══
   
   // ✅ DEBUG: Afficher l'état du buffer lu par l'EA
   Print("═══ DEBUG EA - Lecture Buffer ═══");
   Print("Bars calculated: ", barsCalculated);
   Print("Available bars: ", availableBars);
   Print("Copied: ", copied, " barres");

   // Afficher TOUTES les valeurs lues
   for(int debug_i = 0; debug_i < ArraySize(signalBuffer); debug_i++)
   {
      Print("EA Buffer[", debug_i, "] = ", signalBuffer[debug_i], 
            " Time: ", TimeToString(iTime(_Symbol, _Period, debug_i)));
   }

   // Vérifier si l'indicateur a fini ses calculs
   Print("Indicateur terminé? ", (barsCalculated >= availableBars - 5 ? "OUI" : "NON"));
   Print("═════════════════════════════════");
   
   // ✅ OPTIMISATION : Lire les positions [0] ET [1] pour capturer tous les signaux
   static datetime lastTradedBarTime = 0;
   static int lastCheckedBar = 0;  // ✅ OPTIMISATION: Éviter les vérifications répétées
   
   int currentBar = Bars(_Symbol, _Period);
   if(currentBar == lastCheckedBar) return;  // ✅ OPTIMISATION: Pas de nouvelle barre
   lastCheckedBar = currentBar;
   
   if(copied > 0)
   {
      Print("Last Traded Time: ", TimeToString(lastTradedBarTime));
      Print("═══════════════════════════");
      
      int signalPosition = -1;
      double foundSignal = 0.0;
      datetime barTime = 0;
      
      // ✅ DEBUG : PARCOURIR TOUTES LES POSITIONS POUR TROUVER LES SIGNAUX
      for(int i = 0; i < ArraySize(signalBuffer); i++)
      {
         if(signalBuffer[i] != 0.0 && signalBuffer[i] != EMPTY_VALUE)
         {
            datetime currentBarTime = iTime(_Symbol, _Period, i);
            
            // Vérifier qu'on n'a pas déjà tradé cette barre
            if(currentBarTime <= lastTradedBarTime)
            {
               Print("⚠️ Signal en position [", i, "] déjà traité - Time: ", TimeToString(currentBarTime));
               continue;
            }
            
            Print("🎯 SIGNAL TROUVÉ EN POSITION [", i, "] - Valeur: ", signalBuffer[i]);
            Print("   Time: ", TimeToString(currentBarTime));
            Print("   Last Traded: ", TimeToString(lastTradedBarTime));
            
            signalPosition = i;
            foundSignal = signalBuffer[i];
            barTime = currentBarTime;
            break;  // Prendre le premier signal trouvé
         }
      }
      
      // Si aucun signal trouvé
      if(signalPosition == -1)
      {
         Print("ℹ️ Aucun nouveau signal ou signal déjà traité");
         return;
      }
      
      // Signal trouvé !
      lastTradedBarTime = barTime;
      
      Print("✅ NOUVEAU SIGNAL DÉTECTÉ - Barre[", signalPosition, "] - Valeur: ", foundSignal, " Time: ", TimeToString(barTime));
      
      // Identifier le type de signal et trader en conséquence
      string signalType = "";
      bool isBuySignal = false;
      
      if(foundSignal == 1.0)  // Regular Bullish
      {
         if(!InpTradeRegularDiv) return;
         signalType = "Regular Bullish Divergence";
         isBuySignal = true;
      }
      else if(foundSignal == 2.0)  // Regular Bearish
      {
         if(!InpTradeRegularDiv) return;
         signalType = "Regular Bearish Divergence";
         isBuySignal = false;
      }
      else if(foundSignal == 3.0)  // Hidden Bullish
      {
         if(!InpTradeHiddenDiv) return;
         signalType = "Hidden Bullish Divergence";
         isBuySignal = true;
      }
      else if(foundSignal == 4.0)  // Hidden Bearish
      {
         if(!InpTradeHiddenDiv) return;
         signalType = "Hidden Bearish Divergence";
         isBuySignal = false;
      }
      else if(foundSignal == 9.9)  // Valeur de test
      {
         Print("🔧 Signal de TEST détecté (9.9) - Communication EA↔Indicateur OK ! (Buffer 7)");
         return;
      }
      else
      {
         Print("⚠️ Signal inconnu: ", foundSignal);
         return;
      }
      
      // Vérifier la direction du trade
      if(!IsTradeDirectionAllowed(isBuySignal))
      {
         Print("⚠️ Signal ", signalType, " ignoré - Direction non autorisée (Config: ", 
               EnumToString(InpTradeDirection), ")");
         return;
      }

      // Vérifier les filtres et positions existantes
      ENUM_POSITION_TYPE posType = isBuySignal ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      
      if(!CheckTrendFilter(isBuySignal) || HasOpenPosition(posType))
         return;
      
      // Ouvrir le trade
      ENUM_ORDER_TYPE orderType = isBuySignal ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      OpenTrade(orderType, signalType);
      stats.lastSignal = signalType;
      return;
   }
   
   return;
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
   string comment = "RSI_Div";
   
   // Modifier le commentaire pour Hidden Divergences
   if(StringFind(signalType, "Hidden") >= 0)
      comment = "RSI_Div_H";
   
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
      "=== RSI DIVERGENCE EA ===\n" +
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
