//+------------------------------------------------------------------+
//|                                           OscillatorFilters.mqh   |
//|                   Filtres Oscillateurs pour trading               |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "OscillatorFilters.mqh"        |
//|                                                                   |
//| 2. Utilisez les méthodes statiques :                             |
//|    - CheckStochasticConfluence() : confluence Stochastique        |
//|    - CheckRSIDivergence() : divergence RSI                       |
//|    - CheckWilliamsRConfluence() : confluence Williams %R        |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - OscillatorFilters::CheckStochasticConfluence("EURUSD", PERIOD_H1, true) |
//| - OscillatorFilters::CheckRSIDivergence("GBPUSD", PERIOD_M15, true) |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Classe statique pour les filtres d'oscillateurs                 |
//+------------------------------------------------------------------+
class OscillatorFilters
{
public:
//+------------------------------------------------------------------+
//| Vérifie la confluence avec le Stochastique.                     |
//| Analyse les zones de surachat/survente du Stochastique.        |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @param kPeriod Période K du Stochastique (défaut: 14)           |
//| @param dPeriod Période D du Stochastique (défaut: 3)            |
//| @param slowing Slowing du Stochastique (défaut: 3)              |
//| @param oversoldLevel Niveau survente (défaut: 20)               |
//| @param overboughtLevel Niveau surachat (défaut: 80)             |
//| @return true si confluence Stochastique validée                |
//+------------------------------------------------------------------+
static bool CheckStochasticConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true,
                                     int kPeriod = 14, int dPeriod = 3, int slowing = 3,
                                     int oversoldLevel = 20, int overboughtLevel = 80)
{
   // Créer handle Stochastique
   int stochHandle = iStochastic(symbol, timeframe, kPeriod, dPeriod, slowing, MODE_SMA, STO_LOWHIGH);
   
   if(stochHandle == INVALID_HANDLE)
   {
      Print("OscillatorFilters: Failed to create Stochastic handle for ", symbol);
      return false;
   }
   
   // Obtenir valeurs Stochastique
   double stochMain[];
   ArraySetAsSeries(stochMain, true);
   
   if(CopyBuffer(stochHandle, 0, 0, 1, stochMain) <= 0)
   {
      Print("OscillatorFilters: Failed to get Stochastic value for ", symbol);
      IndicatorRelease(stochHandle);
      return false;
   }
   
   double stochValue = stochMain[0];
   
   bool stochOK;
   if(isBuy)
   {
      // Pour achat : Stochastique en zone de survente ou sortant de survente
      stochOK = (stochValue < oversoldLevel);
   }
   else
   {
      // Pour vente : Stochastique en zone de surachat ou sortant de surachat
      stochOK = (stochValue > overboughtLevel);
   }
   
   Print("OscillatorFilters: ", symbol, " - Stochastic value: ", DoubleToString(stochValue, 1),
         ", Signal: ", (isBuy ? "BUY" : "SELL"), ", OK: ", (stochOK ? "YES" : "NO"));
   
   IndicatorRelease(stochHandle);
   return stochOK;
}

//+------------------------------------------------------------------+
//| Vérifie la divergence RSI avec le prix.                        |
//| Détecte les divergences haussières ou baissières.              |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour divergence haussière, false pour baissière |
//| @param rsiPeriod Période RSI (défaut: 14)                       |
//| @param lookback Périodes à analyser (défaut: 10)                 |
//| @return true si divergence RSI détectée                          |
//+------------------------------------------------------------------+
static bool CheckRSIDivergence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true,
                              int rsiPeriod = 14, int lookback = 10)
{
   // Créer handle RSI
   int rsiHandle = iRSI(symbol, timeframe, rsiPeriod, PRICE_CLOSE);
   
   if(rsiHandle == INVALID_HANDLE)
   {
      Print("OscillatorFilters: Failed to create RSI handle for ", symbol);
      return false;
   }
   
   // Obtenir valeurs RSI et prix
   double rsiValues[], closePrices[];
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(closePrices, true);
   
   if(CopyBuffer(rsiHandle, 0, 0, lookback, rsiValues) <= 0 ||
      CopyClose(symbol, timeframe, 0, lookback, closePrices) <= 0)
   {
      Print("OscillatorFilters: Failed to get RSI or price data for ", symbol);
      IndicatorRelease(rsiHandle);
      return false;
   }
   
   IndicatorRelease(rsiHandle);
   
   // Analyser divergence
   bool divergenceDetected = false;
   
   if(isBuy)
   {
      // Divergence haussière : prix fait un plus bas plus bas, RSI fait un plus bas plus haut
      double lowestPrice = closePrices[ArrayMinimum(closePrices)];
      double highestPrice = closePrices[ArrayMaximum(closePrices)];
      
      int lowestPriceIndex = ArrayMinimum(closePrices);
      int highestPriceIndex = ArrayMaximum(closePrices);
      
      if(lowestPriceIndex < highestPriceIndex) // Plus bas récent après plus haut
      {
         // Vérifier si RSI montre divergence haussière
         double rsiAtLowest = rsiValues[lowestPriceIndex];
         double rsiAtHighest = rsiValues[highestPriceIndex];
         
         // RSI doit être plus haut au plus bas récent qu'au plus haut précédent
         divergenceDetected = (rsiAtLowest > rsiAtHighest);
      }
   }
   else
   {
      // Divergence baissière : prix fait un plus haut plus haut, RSI fait un plus haut plus bas
      double lowestPrice = closePrices[ArrayMinimum(closePrices)];
      double highestPrice = closePrices[ArrayMaximum(closePrices)];
      
      int lowestPriceIndex = ArrayMinimum(closePrices);
      int highestPriceIndex = ArrayMaximum(closePrices);
      
      if(highestPriceIndex < lowestPriceIndex) // Plus haut récent après plus bas
      {
         // Vérifier si RSI montre divergence baissière
         double rsiAtLowest = rsiValues[lowestPriceIndex];
         double rsiAtHighest = rsiValues[highestPriceIndex];
         
         // RSI doit être plus bas au plus haut récent qu'au plus bas précédent
         divergenceDetected = (rsiAtHighest < rsiAtLowest);
      }
   }
   
   Print("OscillatorFilters: ", symbol, " - RSI divergence analysis: ",
         "Signal: ", (isBuy ? "BUY" : "SELL"), ", Detected: ", (divergenceDetected ? "YES" : "NO"));
   
   return divergenceDetected;
}

//+------------------------------------------------------------------+
//| Vérifie la confluence avec Williams %R.                          |
//| Analyse les zones de surachat/survente de Williams %R.           |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @param period Période Williams %R (défaut: 14)                   |
//| @param oversoldLevel Niveau survente (défaut: -80)               |
//| @param overboughtLevel Niveau surachat (défaut: -20)             |
//| @return true si confluence Williams %R validée                   |
//+------------------------------------------------------------------+
static bool CheckWilliamsRConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true,
                                    int period = 14, double oversoldLevel = -80.0, double overboughtLevel = -20.0)
{
   // Créer handle Williams %R
   int williamsHandle = iWPR(symbol, timeframe, period);
   
   if(williamsHandle == INVALID_HANDLE)
   {
      Print("OscillatorFilters: Failed to create Williams %R handle for ", symbol);
      return false;
   }
   
   // Obtenir valeurs Williams %R
   double williamsValues[];
   ArraySetAsSeries(williamsValues, true);
   
   if(CopyBuffer(williamsHandle, 0, 0, 1, williamsValues) <= 0)
   {
      Print("OscillatorFilters: Failed to get Williams %R value for ", symbol);
      IndicatorRelease(williamsHandle);
      return false;
   }
   
   double williamsValue = williamsValues[0];
   
   bool williamsOK;
   if(isBuy)
   {
      // Pour achat : Williams %R en zone de survente
      williamsOK = (williamsValue < oversoldLevel);
   }
   else
   {
      // Pour vente : Williams %R en zone de surachat
      williamsOK = (williamsValue > overboughtLevel);
   }
   
   Print("OscillatorFilters: ", symbol, " - Williams %R value: ", DoubleToString(williamsValue, 1),
         ", Signal: ", (isBuy ? "BUY" : "SELL"), ", OK: ", (williamsOK ? "YES" : "NO"));
   
   IndicatorRelease(williamsHandle);
   return williamsOK;
}

//+------------------------------------------------------------------+
//| Vérifie la confluence complète des oscillateurs.               |
//| Combine Stochastique, RSI et Williams %R pour validation robuste. |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @return true si confluence oscillateurs validée                 |
//+------------------------------------------------------------------+
static bool CheckOscillatorsConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   bool stochOK = CheckStochasticConfluence(symbol, timeframe, isBuy);
   bool rsiOK = CheckRSIDivergence(symbol, timeframe, isBuy);
   bool williamsOK = CheckWilliamsRConfluence(symbol, timeframe, isBuy);
   
   // Au moins 2 oscillateurs sur 3 doivent être en confluence
   int confluenceCount = 0;
   if(stochOK) confluenceCount++;
   if(rsiOK) confluenceCount++;
   if(williamsOK) confluenceCount++;
   
   bool confluenceOK = (confluenceCount >= 2);
   
   Print("OscillatorFilters: ", symbol, " - Complete oscillators confluence: ",
         "Stochastic: ", (stochOK ? "YES" : "NO"), ", RSI: ", (rsiOK ? "YES" : "NO"),
         ", Williams: ", (williamsOK ? "YES" : "NO"), ", Count: ", IntegerToString(confluenceCount),
         ", Final: ", (confluenceOK ? "YES" : "NO"));
   
   return confluenceOK;
}

//+------------------------------------------------------------------+
//| Obtenir informations détaillées sur les oscillateurs            |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @return String avec informations oscillateurs                     |
//+------------------------------------------------------------------+
static string GetOscillatorsInfo(string symbol, ENUM_TIMEFRAMES timeframe)
{
   string info = "=== OSCILLATORS ANALYSIS ===\n";
   info += "Symbol: " + symbol + "\n";
   info += "Timeframe: " + EnumToString(timeframe) + "\n";
   
   // Stochastique
   int stochHandle = iStochastic(symbol, timeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   if(stochHandle != INVALID_HANDLE)
   {
      double stochValues[];
      ArraySetAsSeries(stochValues, true);
      if(CopyBuffer(stochHandle, 0, 0, 1, stochValues) > 0)
      {
         info += "Stochastic: " + DoubleToString(stochValues[0], 1) + "\n";
         info += "Stochastic Status: " + (stochValues[0] < 20 ? "OVERSOLD" : 
                                         stochValues[0] > 80 ? "OVERBOUGHT" : "NEUTRAL") + "\n";
      }
      IndicatorRelease(stochHandle);
   }
   
   // RSI
   int rsiHandle = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
   if(rsiHandle != INVALID_HANDLE)
   {
      double rsiValues[];
      ArraySetAsSeries(rsiValues, true);
      if(CopyBuffer(rsiHandle, 0, 0, 1, rsiValues) > 0)
      {
         info += "RSI: " + DoubleToString(rsiValues[0], 1) + "\n";
         info += "RSI Status: " + (rsiValues[0] < 30 ? "OVERSOLD" : 
                                  rsiValues[0] > 70 ? "OVERBOUGHT" : "NEUTRAL") + "\n";
      }
      IndicatorRelease(rsiHandle);
   }
   
   // Williams %R
   int williamsHandle = iWPR(symbol, timeframe, 14);
   if(williamsHandle != INVALID_HANDLE)
   {
      double williamsValues[];
      ArraySetAsSeries(williamsValues, true);
      if(CopyBuffer(williamsHandle, 0, 0, 1, williamsValues) > 0)
      {
         info += "Williams %R: " + DoubleToString(williamsValues[0], 1) + "\n";
         info += "Williams Status: " + (williamsValues[0] < -80 ? "OVERSOLD" : 
                                       williamsValues[0] > -20 ? "OVERBOUGHT" : "NEUTRAL") + "\n";
      }
      IndicatorRelease(williamsHandle);
   }
   
   info += "===============================";
   return info;
}
};
