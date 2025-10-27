//+------------------------------------------------------------------+
//|                                             VolumeFilters.mqh    |
//|                   Filtres Volume et VSA pour trading             |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "VolumeFilters.mqh"             |
//|                                                                   |
//| 2. Utilisez les méthodes statiques :                             |
//|    - CheckVolumeConfluence() : confluence volume                 |
//|    - CheckVolumeSpike() : détection pic de volume                |
//|    - CheckVolumeTrend() : tendance du volume                     |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - VolumeFilters::CheckVolumeConfluence("EURUSD", PERIOD_H1, true) |
//| - VolumeFilters::CheckVolumeSpike("GBPUSD", PERIOD_M15, 1.5)   |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Classe statique pour les filtres de volume                      |
//+------------------------------------------------------------------+
class VolumeFilters
{
public:
//+------------------------------------------------------------------+
//| Vérifie la confluence de volume pour un signal donné.            |
//| Analyse le volume actuel par rapport à la moyenne historique.   |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @param minMultiplier Multiplicateur minimum (défaut: 1.2)       |
//| @param periods Périodes pour calculer moyenne (défaut: 20)      |
//| @return true si confluence volume validée                       |
//+------------------------------------------------------------------+
static bool CheckVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy,
                                 double minMultiplier = 1.2, int periods = 20)
{
   // Obtenir volume actuel
   long currentVolume = SymbolInfoInteger(symbol, SYMBOL_VOLUME);
   if(currentVolume <= 0)
   {
      Print("VolumeFilters: No volume data available for ", symbol);
      return true; // Pas de données, ne pas bloquer
   }
   
   // Calculer volume moyen des dernières périodes
   long volumes[];
   ArraySetAsSeries(volumes, true);
   
   if(CopyTickVolume(symbol, timeframe, 0, periods, volumes) <= 0)
   {
      Print("VolumeFilters: Failed to get volume history for ", symbol);
      return true; // Pas de données historiques, ne pas bloquer
   }
   
   long avgVolume = 0;
   for(int i = 0; i < ArraySize(volumes); i++)
   {
      avgVolume += volumes[i];
   }
   avgVolume /= ArraySize(volumes);
   
   double volumeRatio = (double)currentVolume / (double)avgVolume;
   
   bool volumeOK = (volumeRatio >= minMultiplier);
   
   Print("VolumeFilters: ", symbol, " - Volume ratio: ", DoubleToString(volumeRatio, 2), 
         "x average, Required: ", DoubleToString(minMultiplier, 2), "x, OK: ", (volumeOK ? "YES" : "NO"));
   
   return volumeOK;
}

//+------------------------------------------------------------------+
//| Détecte un pic de volume significatif.                          |
//| Compare le volume actuel avec les volumes récents.              |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param multiplier Multiplicateur pour pic (défaut: 1.5)         |
//| @param lookback Périodes à analyser (défaut: 10)                 |
//| @return true si pic de volume détecté                           |
//+------------------------------------------------------------------+
static bool CheckVolumeSpike(string symbol, ENUM_TIMEFRAMES timeframe, 
                            double multiplier = 1.5, int lookback = 10)
{
   // Obtenir volume actuel
   long currentVolume = SymbolInfoInteger(symbol, SYMBOL_VOLUME);
   if(currentVolume <= 0)
   {
      Print("VolumeFilters: No volume data available for ", symbol);
      return false;
   }
   
   // Obtenir volumes des périodes précédentes
   long volumes[];
   ArraySetAsSeries(volumes, true);
   
   if(CopyTickVolume(symbol, timeframe, 0, lookback + 1, volumes) <= 0)
   {
      Print("VolumeFilters: Failed to get volume history for ", symbol);
      return false;
   }
   
   // Calculer volume moyen des périodes précédentes (exclure la période actuelle)
   long avgVolume = 0;
   for(int i = 1; i < ArraySize(volumes); i++) // Commencer à 1 pour exclure période actuelle
   {
      avgVolume += volumes[i];
   }
   avgVolume /= (ArraySize(volumes) - 1);
   
   double volumeRatio = (double)currentVolume / (double)avgVolume;
   
   bool spikeDetected = (volumeRatio >= multiplier);
   
   Print("VolumeFilters: ", symbol, " - Volume spike ratio: ", DoubleToString(volumeRatio, 2), 
         "x average, Required: ", DoubleToString(multiplier, 2), "x, Spike: ", (spikeDetected ? "YES" : "NO"));
   
   return spikeDetected;
}

//+------------------------------------------------------------------+
//| Vérifie la tendance du volume sur plusieurs périodes.           |
//| Analyse si le volume augmente ou diminue progressivement.       |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param periods Périodes à analyser (défaut: 5)                  |
//| @param isIncreasing true pour tendance croissante               |
//| @return true si tendance volume confirmée                        |
//+------------------------------------------------------------------+
static bool CheckVolumeTrend(string symbol, ENUM_TIMEFRAMES timeframe, 
                            int periods = 5, bool isIncreasing = true)
{
   // Obtenir volumes des dernières périodes
   long volumes[];
   ArraySetAsSeries(volumes, true);
   
   if(CopyTickVolume(symbol, timeframe, 0, periods, volumes) <= 0)
   {
      Print("VolumeFilters: Failed to get volume history for ", symbol);
      return false;
   }
   
   // Analyser la tendance du volume
   int increasingCount = 0;
   int decreasingCount = 0;
   
   for(int i = 0; i < ArraySize(volumes) - 1; i++)
   {
      if(volumes[i] > volumes[i + 1])
         increasingCount++;
      else if(volumes[i] < volumes[i + 1])
         decreasingCount++;
   }
   
   bool trendConfirmed;
   if(isIncreasing)
   {
      // Tendance croissante : au moins 60% des périodes en hausse
      trendConfirmed = (increasingCount >= (ArraySize(volumes) - 1) * 0.6);
   }
   else
   {
      // Tendance décroissante : au moins 60% des périodes en baisse
      trendConfirmed = (decreasingCount >= (ArraySize(volumes) - 1) * 0.6);
   }
   
   Print("VolumeFilters: ", symbol, " - Volume trend analysis: ", 
         "Increasing: ", IntegerToString(increasingCount), 
         ", Decreasing: ", IntegerToString(decreasingCount),
         ", Trend confirmed: ", (trendConfirmed ? "YES" : "NO"));
   
   return trendConfirmed;
}

//+------------------------------------------------------------------+
//| Vérifie la confluence volume pour signal d'achat.               |
//| Volume croissant + pic de volume pour confirmer l'intérêt acheteur. |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param minMultiplier Multiplicateur minimum (défaut: 1.2)       |
//| @return true si confluence volume achat validée                 |
//+------------------------------------------------------------------+
static bool CheckBuyVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, 
                                    double minMultiplier = 1.2)
{
   bool volumeConfluence = CheckVolumeConfluence(symbol, timeframe, true, minMultiplier);
   bool volumeSpike = CheckVolumeSpike(symbol, timeframe, minMultiplier);
   bool volumeTrend = CheckVolumeTrend(symbol, timeframe, 3, true); // Tendance croissante sur 3 périodes
   
   bool confluenceOK = volumeConfluence && (volumeSpike || volumeTrend);
   
   Print("VolumeFilters: BUY confluence for ", symbol, " - Confluence: ", (volumeConfluence ? "YES" : "NO"),
         ", Spike: ", (volumeSpike ? "YES" : "NO"), ", Trend: ", (volumeTrend ? "YES" : "NO"),
         ", Final: ", (confluenceOK ? "YES" : "NO"));
   
   return confluenceOK;
}

//+------------------------------------------------------------------+
//| Vérifie la confluence volume pour signal de vente.              |
//| Volume croissant + pic de volume pour confirmer l'intérêt vendeur. |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param minMultiplier Multiplicateur minimum (défaut: 1.2)       |
//| @return true si confluence volume vente validée                 |
//+------------------------------------------------------------------+
static bool CheckSellVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, 
                                     double minMultiplier = 1.2)
{
   bool volumeConfluence = CheckVolumeConfluence(symbol, timeframe, false, minMultiplier);
   bool volumeSpike = CheckVolumeSpike(symbol, timeframe, minMultiplier);
   bool volumeTrend = CheckVolumeTrend(symbol, timeframe, 3, true); // Volume croissant pour vente aussi
   
   bool confluenceOK = volumeConfluence && (volumeSpike || volumeTrend);
   
   Print("VolumeFilters: SELL confluence for ", symbol, " - Confluence: ", (volumeConfluence ? "YES" : "NO"),
         ", Spike: ", (volumeSpike ? "YES" : "NO"), ", Trend: ", (volumeTrend ? "YES" : "NO"),
         ", Final: ", (confluenceOK ? "YES" : "NO"));
   
   return confluenceOK;
}

//+------------------------------------------------------------------+
//| Obtenir informations détaillées sur le volume                   |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param periods Périodes à analyser (défaut: 20)                  |
//| @return String avec informations volume                          |
//+------------------------------------------------------------------+
static string GetVolumeInfo(string symbol, ENUM_TIMEFRAMES timeframe, int periods = 20)
{
   string info = "=== VOLUME ANALYSIS ===\n";
   info += "Symbol: " + symbol + "\n";
   info += "Timeframe: " + EnumToString(timeframe) + "\n";
   
   long currentVolume = SymbolInfoInteger(symbol, SYMBOL_VOLUME);
   info += "Current Volume: " + IntegerToString(currentVolume) + "\n";
   
   if(currentVolume > 0)
   {
      long volumes[];
      ArraySetAsSeries(volumes, true);
      
      if(CopyTickVolume(symbol, timeframe, 0, periods, volumes) > 0)
      {
         long avgVolume = 0;
         for(int i = 0; i < ArraySize(volumes); i++)
         {
            avgVolume += volumes[i];
         }
         avgVolume /= ArraySize(volumes);
         
         double volumeRatio = (double)currentVolume / (double)avgVolume;
         info += "Average Volume (" + IntegerToString(periods) + " periods): " + IntegerToString(avgVolume) + "\n";
         info += "Volume Ratio: " + DoubleToString(volumeRatio, 2) + "x\n";
         info += "Status: " + (volumeRatio >= 1.2 ? "HIGH VOLUME" : "NORMAL VOLUME") + "\n";
      }
   }
   
   info += "=========================";
   return info;
}
};
