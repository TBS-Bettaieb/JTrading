//+------------------------------------------------------------------+
//|                                          PriceActionFilters.mqh   |
//|                   Filtres Price Action pour trading               |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "PriceActionFilters.mqh"        |
//|                                                                   |
//| 2. Utilisez les méthodes statiques :                             |
//|    - CheckPsychologicalLevels() : niveaux psychologiques        |
//|    - CheckCandlestickPatterns() : patterns de chandeliers       |
//|    - CheckMarketStructure() : structure de marché                |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - PriceActionFilters::CheckPsychologicalLevels("EURUSD", 0.01, true) |
//| - PriceActionFilters::CheckCandlestickPatterns("GBPUSD", PERIOD_M15, true) |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Classe statique pour les filtres de Price Action               |
//+------------------------------------------------------------------+
class PriceActionFilters
{
public:
//+------------------------------------------------------------------+
//| Vérifie la confluence avec les niveaux psychologiques.          |
//| Analyse la proximité avec des niveaux ronds (100, 50, etc.).    |
//| @param symbol Symbole à analyser                                  |
//| @param step Pas des niveaux psychologiques (ex: 100 pour US100)  |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @param tolerance Tolérance en pourcentage (défaut: 5%)          |
//| @return true si confluence niveaux psychologiques validée       |
//+------------------------------------------------------------------+
static bool CheckPsychologicalLevels(string symbol, double step, bool isBuy = true, double tolerance = 5.0)
{
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Calculer distance au niveau psychologique le plus proche
   double remainder = MathMod(currentPrice, step);
   double distanceToLevel = MathMin(remainder, step - remainder);
   
   // Tolérance en pourcentage du pas psychologique
   double tolerancePrice = step * (tolerance / 100.0);
   
   bool nearLevel = (distanceToLevel <= tolerancePrice);
   
   // Pour les signaux d'achat, vérifier si on est proche d'un support psychologique
   // Pour les signaux de vente, vérifier si on est proche d'une résistance psychologique
   bool confluenceOK = nearLevel;
   
   Print("PriceActionFilters: ", symbol, " - Psychological levels analysis: ",
         "Price: ", DoubleToString(currentPrice, 2), ", Step: ", DoubleToString(step, 2),
         ", Distance: ", DoubleToString(distanceToLevel, 2), ", Tolerance: ", DoubleToString(tolerancePrice, 2),
         ", Near level: ", (nearLevel ? "YES" : "NO"), ", Signal: ", (isBuy ? "BUY" : "SELL"));
   
   return confluenceOK;
}

//+------------------------------------------------------------------+
//| Vérifie les patterns de chandeliers de retournement.            |
//| Détecte les patterns haussiers ou baissiers.                    |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour patterns haussiers, false pour baissiers  |
//| @param lookback Périodes à analyser (défaut: 3)                 |
//| @return true si pattern de retournement détecté                 |
//+------------------------------------------------------------------+
static bool CheckCandlestickPatterns(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true, int lookback = 3)
{
   // Obtenir données OHLC
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyOpen(symbol, timeframe, 0, lookback, open) <= 0 ||
      CopyHigh(symbol, timeframe, 0, lookback, high) <= 0 ||
      CopyLow(symbol, timeframe, 0, lookback, low) <= 0 ||
      CopyClose(symbol, timeframe, 0, lookback, close) <= 0)
   {
      Print("PriceActionFilters: Failed to get OHLC data for ", symbol);
      return false;
   }
   
   bool patternDetected = false;
   
   if(isBuy)
   {
      // Patterns haussiers de retournement
      patternDetected = CheckBullishPatterns(open, high, low, close, lookback);
   }
   else
   {
      // Patterns baissiers de retournement
      patternDetected = CheckBearishPatterns(open, high, low, close, lookback);
   }
   
   Print("PriceActionFilters: ", symbol, " - Candlestick patterns analysis: ",
         "Signal: ", (isBuy ? "BUY" : "SELL"), ", Pattern detected: ", (patternDetected ? "YES" : "NO"));
   
   return patternDetected;
}

//+------------------------------------------------------------------+
//| Vérifie la structure de marché (Market Structure).              |
//| Analyse les Break of Structure (BOS) et Change of Character (CHoCH). |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour structure haussière, false pour baissière |
//| @param lookback Périodes à analyser (défaut: 10)                |
//| @return true si structure de marché confirmée                   |
//+------------------------------------------------------------------+
static bool CheckMarketStructure(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true, int lookback = 10)
{
   // Obtenir données OHLC
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(symbol, timeframe, 0, lookback, high) <= 0 ||
      CopyLow(symbol, timeframe, 0, lookback, low) <= 0)
   {
      Print("PriceActionFilters: Failed to get OHLC data for ", symbol);
      return false;
   }
   
   bool structureOK = false;
   
   if(isBuy)
   {
      // Structure haussière : Break of Structure vers le haut
      // Chercher un plus haut plus haut (HH) après un plus bas plus haut (HL)
      structureOK = CheckBullishMarketStructure(high, low, lookback);
   }
   else
   {
      // Structure baissière : Break of Structure vers le bas
      // Chercher un plus bas plus bas (LL) après un plus haut plus bas (LH)
      structureOK = CheckBearishMarketStructure(high, low, lookback);
   }
   
   Print("PriceActionFilters: ", symbol, " - Market structure analysis: ",
         "Signal: ", (isBuy ? "BUY" : "SELL"), ", Structure confirmed: ", (structureOK ? "YES" : "NO"));
   
   return structureOK;
}

//+------------------------------------------------------------------+
//| Vérifie la confluence complète Price Action.                    |
//| Combine niveaux psychologiques, patterns et structure de marché. |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @param psychologicalStep Pas des niveaux psychologiques         |
//| @return true si confluence Price Action validée                |
//+------------------------------------------------------------------+
static bool CheckPriceActionConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true, double psychologicalStep = 100.0)
{
   bool psychologicalOK = CheckPsychologicalLevels(symbol, psychologicalStep, isBuy);
   bool patternsOK = CheckCandlestickPatterns(symbol, timeframe, isBuy);
   bool structureOK = CheckMarketStructure(symbol, timeframe, isBuy);
   
   // Au moins 2 éléments sur 3 doivent être en confluence
   int confluenceCount = 0;
   if(psychologicalOK) confluenceCount++;
   if(patternsOK) confluenceCount++;
   if(structureOK) confluenceCount++;
   
   bool confluenceOK = (confluenceCount >= 2);
   
   Print("PriceActionFilters: ", symbol, " - Complete price action confluence: ",
         "Psychological: ", (psychologicalOK ? "YES" : "NO"), ", Patterns: ", (patternsOK ? "YES" : "NO"),
         ", Structure: ", (structureOK ? "YES" : "NO"), ", Count: ", IntegerToString(confluenceCount),
         ", Final: ", (confluenceOK ? "YES" : "NO"));
   
   return confluenceOK;
}

private:
//+------------------------------------------------------------------+
//| Vérifie les patterns haussiers de retournement                |
//| @param open Array des prix d'ouverture                          |
//| @param high Array des prix hauts                                |
//| @param low Array des prix bas                                   |
//| @param close Array des prix de clôture                          |
//| @param lookback Nombre de périodes à analyser                  |
//| @return true si pattern haussier détecté                       |
//+------------------------------------------------------------------+
static bool CheckBullishPatterns(double &open[], double &high[], double &low[], double &close[], int lookback)
{
   // Pattern 1: Hammer (Marteau)
   if(lookback >= 1)
   {
      double bodySize = MathAbs(close[0] - open[0]);
      double lowerShadow = MathMin(open[0], close[0]) - low[0];
      double upperShadow = high[0] - MathMax(open[0], close[0]);
      
      // Hammer: petite ombre haute, longue ombre basse, corps petit
      if(upperShadow < bodySize && lowerShadow > bodySize * 2 && bodySize < (high[0] - low[0]) * 0.3)
         return true;
   }
   
   // Pattern 2: Doji après tendance baissière
   if(lookback >= 2)
   {
      double bodySize = MathAbs(close[0] - open[0]);
      double totalRange = high[0] - low[0];
      
      // Doji: corps très petit par rapport à la range
      if(bodySize < totalRange * 0.1)
      {
         // Vérifier que la période précédente était baissière
         if(close[1] < open[1])
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie les patterns baissiers de retournement                 |
//| @param open Array des prix d'ouverture                          |
//| @param high Array des prix hauts                                |
//| @param low Array des prix bas                                   |
//| @param close Array des prix de clôture                          |
//| @param lookback Nombre de périodes à analyser                  |
//| @return true si pattern baissier détecté                       |
//+------------------------------------------------------------------+
static bool CheckBearishPatterns(double &open[], double &high[], double &low[], double &close[], int lookback)
{
   // Pattern 1: Shooting Star (Étoile filante)
   if(lookback >= 1)
   {
      double bodySize = MathAbs(close[0] - open[0]);
      double lowerShadow = MathMin(open[0], close[0]) - low[0];
      double upperShadow = high[0] - MathMax(open[0], close[0]);
      
      // Shooting Star: petite ombre basse, longue ombre haute, corps petit
      if(lowerShadow < bodySize && upperShadow > bodySize * 2 && bodySize < (high[0] - low[0]) * 0.3)
         return true;
   }
   
   // Pattern 2: Doji après tendance haussière
   if(lookback >= 2)
   {
      double bodySize = MathAbs(close[0] - open[0]);
      double totalRange = high[0] - low[0];
      
      // Doji: corps très petit par rapport à la range
      if(bodySize < totalRange * 0.1)
      {
         // Vérifier que la période précédente était haussière
         if(close[1] > open[1])
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie la structure de marché haussière                       |
//| @param high Array des prix hauts                                |
//| @param low Array des prix bas                                    |
//| @param lookback Nombre de périodes à analyser                  |
//| @return true si structure haussière confirmée                 |
//+------------------------------------------------------------------+
static bool CheckBullishMarketStructure(double &high[], double &low[], int lookback)
{
   if(lookback < 4) return false;
   
   // Chercher un plus haut plus haut (HH) récent
   int highestIndex = ArrayMaximum(high);
   if(highestIndex < 2) return false;
   
   // Chercher un plus bas plus haut (HL) avant le HH
   for(int i = highestIndex + 1; i < lookback - 1; i++)
   {
      if(low[i] > low[i + 1]) // HL détecté
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie la structure de marché baissière                        |
//| @param high Array des prix hauts                                |
//| @param low Array des prix bas                                    |
//| @param lookback Nombre de périodes à analyser                  |
//| @return true si structure baissière confirmée                  |
//+------------------------------------------------------------------+
static bool CheckBearishMarketStructure(double &high[], double &low[], int lookback)
{
   if(lookback < 4) return false;
   
   // Chercher un plus bas plus bas (LL) récent
   int lowestIndex = ArrayMinimum(low);
   if(lowestIndex < 2) return false;
   
   // Chercher un plus haut plus bas (LH) avant le LL
   for(int i = lowestIndex + 1; i < lookback - 1; i++)
   {
      if(high[i] < high[i + 1]) // LH détecté
      {
         return true;
      }
   }
   
   return false;
}

public:
//+------------------------------------------------------------------+
//| Obtenir informations détaillées sur Price Action                 |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param psychologicalStep Pas des niveaux psychologiques         |
//| @return String avec informations Price Action                   |
//+------------------------------------------------------------------+
static string GetPriceActionInfo(string symbol, ENUM_TIMEFRAMES timeframe, double psychologicalStep = 100.0)
{
   string info = "=== PRICE ACTION ANALYSIS ===\n";
   info += "Symbol: " + symbol + "\n";
   info += "Timeframe: " + EnumToString(timeframe) + "\n";
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   info += "Current Price: " + DoubleToString(currentPrice, 5) + "\n";
   
   // Niveaux psychologiques
   double remainder = MathMod(currentPrice, psychologicalStep);
   double distanceToLevel = MathMin(remainder, psychologicalStep - remainder);
   info += "Distance to psychological level: " + DoubleToString(distanceToLevel, 2) + "\n";
   info += "Near psychological level: " + (distanceToLevel <= psychologicalStep * 0.05 ? "YES" : "NO") + "\n";
   
   // Patterns de chandeliers
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyOpen(symbol, timeframe, 0, 3, open) > 0 &&
      CopyHigh(symbol, timeframe, 0, 3, high) > 0 &&
      CopyLow(symbol, timeframe, 0, 3, low) > 0 &&
      CopyClose(symbol, timeframe, 0, 3, close) > 0)
   {
      double bodySize = MathAbs(close[0] - open[0]);
      double totalRange = high[0] - low[0];
      double bodyRatio = (totalRange > 0) ? bodySize / totalRange : 0;
      
      info += "Current candle body ratio: " + DoubleToString(bodyRatio, 2) + "\n";
      info += "Candle type: " + (bodyRatio < 0.1 ? "DOJI" : 
                                close[0] > open[0] ? "BULLISH" : "BEARISH") + "\n";
   }
   
   info += "================================";
   return info;
}
};
