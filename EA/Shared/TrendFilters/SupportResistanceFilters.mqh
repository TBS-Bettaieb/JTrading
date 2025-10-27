//+------------------------------------------------------------------+
//|                                    SupportResistanceFilters.mqh  |
//|                   Filtres Support/Résistance pour trading         |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "SupportResistanceFilters.mqh" |
//|                                                                   |
//| 2. Utilisez les méthodes statiques :                             |
//|    - CheckEMAConfluence() : confluence EMA                       |
//|    - CheckDynamicLevels() : niveaux dynamiques                   |
//|    - CheckStaticLevels() : niveaux statiques                     |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - SupportResistanceFilters::CheckEMAConfluence("EURUSD", PERIOD_H1, 200, true) |
//| - SupportResistanceFilters::CheckDynamicLevels("GBPUSD", PERIOD_M15, true) |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Classe statique pour les filtres Support/Résistance             |
//+------------------------------------------------------------------+
class SupportResistanceFilters
{
public:
//+------------------------------------------------------------------+
//| Vérifie la confluence avec une EMA donnée.                       |
//| Analyse la position du prix par rapport à l'EMA.                |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param emaPeriod Période de l'EMA (défaut: 200)                 |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @param tolerance Tolérance en points (défaut: 5)                |
//| @return true si confluence EMA validée                          |
//+------------------------------------------------------------------+
static bool CheckEMAConfluence(string symbol, ENUM_TIMEFRAMES timeframe, int emaPeriod = 200,
                               bool isBuy = true, double tolerance = 5.0)
{
   // Créer handle EMA
   int emaHandle = iMA(symbol, timeframe, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(emaHandle == INVALID_HANDLE)
   {
      Print("SupportResistanceFilters: Failed to create EMA handle for ", symbol);
      return false;
   }
   
   // Obtenir valeur EMA actuelle
   double ema[];
   ArraySetAsSeries(ema, true);
   
   if(CopyBuffer(emaHandle, 0, 0, 1, ema) <= 0)
   {
      Print("SupportResistanceFilters: Failed to get EMA value for ", symbol);
      IndicatorRelease(emaHandle);
      return false;
   }
   
   double currentPrice = isBuy ? SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                                SymbolInfoDouble(symbol, SYMBOL_BID);
   double emaValue = ema[0];
   
   // Vérifier confluence avec tolérance
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tolerancePrice = tolerance * point;
   
   bool emaOK;
   if(isBuy)
   {
      // Pour achat : prix au-dessus ou proche de l'EMA (support dynamique)
      emaOK = (currentPrice > emaValue - tolerancePrice);
   }
   else
   {
      // Pour vente : prix en dessous ou proche de l'EMA (résistance dynamique)
      emaOK = (currentPrice < emaValue + tolerancePrice);
   }
   
   Print("SupportResistanceFilters: ", symbol, " - Price: ", DoubleToString(currentPrice, 5),
         ", EMA", IntegerToString(emaPeriod), ": ", DoubleToString(emaValue, 5),
         ", Tolerance: ", DoubleToString(tolerancePrice, 5), ", OK: ", (emaOK ? "YES" : "NO"));
   
   IndicatorRelease(emaHandle);
   return emaOK;
}

//+------------------------------------------------------------------+
//| Vérifie les niveaux dynamiques (EMA multiples).                 |
//| Analyse la confluence avec plusieurs EMA pour support/résistance. |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @return true si confluence niveaux dynamiques validée           |
//+------------------------------------------------------------------+
static bool CheckDynamicLevels(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   // Analyser confluence avec EMA50, EMA100, EMA200
   bool ema50OK = CheckEMAConfluence(symbol, timeframe, 50, isBuy, 10.0);
   bool ema100OK = CheckEMAConfluence(symbol, timeframe, 100, isBuy, 15.0);
   bool ema200OK = CheckEMAConfluence(symbol, timeframe, 200, isBuy, 20.0);
   
   // Au moins 2 EMA sur 3 doivent être en confluence
   int confluenceCount = 0;
   if(ema50OK) confluenceCount++;
   if(ema100OK) confluenceCount++;
   if(ema200OK) confluenceCount++;
   
   bool dynamicOK = (confluenceCount >= 2);
   
   Print("SupportResistanceFilters: ", symbol, " - Dynamic levels confluence: ",
         "EMA50: ", (ema50OK ? "YES" : "NO"), ", EMA100: ", (ema100OK ? "YES" : "NO"),
         ", EMA200: ", (ema200OK ? "YES" : "NO"), ", Count: ", IntegerToString(confluenceCount),
         ", Final: ", (dynamicOK ? "YES" : "NO"));
   
   return dynamicOK;
}

//+------------------------------------------------------------------+
//| Vérifie les niveaux statiques (pivots, highs/lows).            |
//| Analyse la proximité avec des niveaux de support/résistance clés. |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @param lookback Périodes à analyser pour trouver niveaux (défaut: 20) |
//| @param tolerance Tolérance en points (défaut: 20)                |
//| @return true si confluence niveaux statiques validée            |
//+------------------------------------------------------------------+
static bool CheckStaticLevels(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true,
                             int lookback = 20, double tolerance = 20.0)
{
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tolerancePrice = tolerance * point;
   
   // Obtenir données OHLC
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyHigh(symbol, timeframe, 0, lookback, high) <= 0 ||
      CopyLow(symbol, timeframe, 0, lookback, low) <= 0 ||
      CopyClose(symbol, timeframe, 0, lookback, close) <= 0)
   {
      Print("SupportResistanceFilters: Failed to get OHLC data for ", symbol);
      return false;
   }
   
   // Trouver niveaux de support/résistance
   double resistanceLevel = 0;
   double supportLevel = 0;
   
   // Trouver résistance (plus haut récent)
   int maxIndex = ArrayMaximum(high);
   if(maxIndex >= 0)
      resistanceLevel = high[maxIndex];
   
   // Trouver support (plus bas récent)
   int minIndex = ArrayMinimum(low);
   if(minIndex >= 0)
      supportLevel = low[minIndex];
   
   bool staticOK = false;
   
   if(isBuy)
   {
      // Pour achat : vérifier proximité du support
      staticOK = (MathAbs(currentPrice - supportLevel) <= tolerancePrice);
   }
   else
   {
      // Pour vente : vérifier proximité de la résistance
      staticOK = (MathAbs(currentPrice - resistanceLevel) <= tolerancePrice);
   }
   
   Print("SupportResistanceFilters: ", symbol, " - Static levels analysis: ",
         "Current: ", DoubleToString(currentPrice, 5),
         ", Support: ", DoubleToString(supportLevel, 5),
         ", Resistance: ", DoubleToString(resistanceLevel, 5),
         ", Tolerance: ", DoubleToString(tolerancePrice, 5),
         ", OK: ", (staticOK ? "YES" : "NO"));
   
   return staticOK;
}

//+------------------------------------------------------------------+
//| Vérifie la confluence complète Support/Résistance.              |
//| Combine niveaux dynamiques et statiques pour une validation robuste. |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @return true si confluence complète validée                     |
//+------------------------------------------------------------------+
static bool CheckSupportResistanceConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   bool dynamicOK = CheckDynamicLevels(symbol, timeframe, isBuy);
   bool staticOK = CheckStaticLevels(symbol, timeframe, isBuy);
   
   // Au moins un des deux types de niveaux doit être en confluence
   bool confluenceOK = (dynamicOK || staticOK);
   
   Print("SupportResistanceFilters: ", symbol, " - Complete confluence: ",
         "Dynamic: ", (dynamicOK ? "YES" : "NO"), ", Static: ", (staticOK ? "YES" : "NO"),
         ", Final: ", (confluenceOK ? "YES" : "NO"));
   
   return confluenceOK;
}

//+------------------------------------------------------------------+
//| Vérifie la confluence EMA200 spécifique pour scalping.         |
//| EMA200 comme support/résistance dynamique principal.            |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @return true si confluence EMA200 validée                       |
//+------------------------------------------------------------------+
static bool CheckEMA200Confluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return CheckEMAConfluence(symbol, timeframe, 200, isBuy, 5.0);
}

//+------------------------------------------------------------------+
//| Obtenir informations détaillées sur les niveaux                 |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param lookback Périodes à analyser (défaut: 20)                 |
//| @return String avec informations niveaux                        |
//+------------------------------------------------------------------+
static string GetLevelsInfo(string symbol, ENUM_TIMEFRAMES timeframe, int lookback = 20)
{
   string info = "=== SUPPORT/RESISTANCE ANALYSIS ===\n";
   info += "Symbol: " + symbol + "\n";
   info += "Timeframe: " + EnumToString(timeframe) + "\n";
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   info += "Current Price: " + DoubleToString(currentPrice, 5) + "\n";
   
   // EMA200
   int ema200Handle = iMA(symbol, timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema200Handle != INVALID_HANDLE)
   {
      double ema200[];
      ArraySetAsSeries(ema200, true);
      if(CopyBuffer(ema200Handle, 0, 0, 1, ema200) > 0)
      {
         info += "EMA200: " + DoubleToString(ema200[0], 5) + "\n";
         info += "Price vs EMA200: " + (currentPrice > ema200[0] ? "ABOVE" : "BELOW") + "\n";
      }
      IndicatorRelease(ema200Handle);
   }
   
   // Niveaux statiques
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(symbol, timeframe, 0, lookback, high) > 0 &&
      CopyLow(symbol, timeframe, 0, lookback, low) > 0)
   {
      int maxIndex = ArrayMaximum(high);
      int minIndex = ArrayMinimum(low);
      
      if(maxIndex >= 0 && minIndex >= 0)
      {
         info += "Resistance Level: " + DoubleToString(high[maxIndex], 5) + "\n";
         info += "Support Level: " + DoubleToString(low[minIndex], 5) + "\n";
      }
   }
   
   info += "=====================================";
   return info;
}
};
