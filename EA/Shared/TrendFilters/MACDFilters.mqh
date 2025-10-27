//+------------------------------------------------------------------+
//|                                             MACDFilters.mqh      |
//|                   Filtres MACD spécialisés pour trading          |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "MACDFilters.mqh"               |
//|                                                                   |
//| 2. Utilisez les méthodes statiques :                             |
//|    - CheckMACDBullishCrossover() : détecte croisement MACD       |
//|    - CheckMACDBullish() : vérifie état MACD haussier             |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - MACDFilters::CheckMACDBullishCrossover("EURUSD", PERIOD_H1)     |
//| - MACDFilters::CheckMACDBullish("GBPUSD", PERIOD_M15, 8, 21, 5)  |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Classe statique pour les filtres MACD                           |
//+------------------------------------------------------------------+
class MACDFilters
{
public:
//+------------------------------------------------------------------+
//| Détecte le croisement haussier du MACD sur un timeframe donné.   |
//| Retourne true si le MACD vient de faire un croisement haussier   |
//| (histogramme ou ligne de signal).                                |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param fast_period Période rapide MACD (défaut: 12)             |
//| @param slow_period Période lente MACD (défaut: 26)               |
//| @param signal_period Période signal MACD (défaut: 9)             |
//| @return true si croisement haussier détecté                      |
//+------------------------------------------------------------------+
static bool CheckMACDBullishCrossover(string symbol, ENUM_TIMEFRAMES timeframe, 
                                      int fast_period = 12, int slow_period = 26, int signal_period = 9)
{
   // Paramètres MACD standards
   int fastEMA = fast_period;
   int slowEMA = slow_period;
   int signalPeriod = signal_period;
   
   // Créer le handle MACD
   int macdHandle = iMACD(symbol, timeframe, fastEMA, slowEMA, signalPeriod, PRICE_CLOSE);
   
   if(macdHandle == INVALID_HANDLE)
   {
      Print("Erreur: Impossible de créer le handle MACD pour ", symbol);
      return false;
   }
   
   // Déclarer les arrays
   double macdMain[];
   double macdSignal[];
   
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   
   // Copier 3 valeurs pour détecter le croisement
   if(CopyBuffer(macdHandle, 0, 0, 3, macdMain) <= 0 ||
      CopyBuffer(macdHandle, 1, 0, 3, macdSignal) <= 0)
   {
      Print("Erreur lors de la copie des buffers MACD pour ", symbol);
      IndicatorRelease(macdHandle);
      return false;
   }
   
   IndicatorRelease(macdHandle);
   
   // Valeurs actuelles et précédentes
   double macdCurrent = macdMain[0];
   double signalCurrent = macdSignal[0];
   double macdPrevious = macdMain[1];
   double signalPrevious = macdSignal[1];
   
   // Détection du croisement haussier:
   // Avant: MACD était en dessous ou égal à Signal
   // Maintenant: MACD est au-dessus de Signal
   bool crossoverOccurred = (macdPrevious <= signalPrevious) && 
                            (macdCurrent > signalCurrent);
   
   return crossoverOccurred;
}

//+------------------------------------------------------------------+
//| Retourne true si le MACD est actuellement haussier, simple.      |
//| Vérifie l'état actuel du MACD sans analyser les croisements.     |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param fast_period Période rapide MACD (défaut: 12)             |
//| @param slow_period Période lente MACD (défaut: 26)               |
//| @param signal_period Période signal MACD (défaut: 9)             |
//| @return true si MACD haussier                                     |
//+------------------------------------------------------------------+
static bool CheckMACDBullish(string symbol, ENUM_TIMEFRAMES timeframe,
                             int fast_period = 12, int slow_period = 26, int signal_period = 9)
{
   // Créer les arrays pour stocker les valeurs MACD
   double macdMain[];
   double macdSignal[];
   
   // Configurer les arrays en série chronologique
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   
   // Créer le handle MACD avec les paramètres spécifiés
   int macdHandle = iMACD(symbol, timeframe, fast_period, slow_period, signal_period, PRICE_CLOSE);
   
   // Vérifier si le handle est valide
   if(macdHandle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du handle MACD pour ", symbol);
      return false;
   }
   
   // Copier les valeurs du buffer MACD
   // Buffer 0 = MACD Main Line
   // Buffer 1 = MACD Signal Line
   if(CopyBuffer(macdHandle, 0, 0, 3, macdMain) <= 0 ||
      CopyBuffer(macdHandle, 1, 0, 3, macdSignal) <= 0)
   {
      Print("Erreur lors de la copie des buffers MACD pour ", symbol);
      IndicatorRelease(macdHandle);
      return false;
   }
   
   // Obtenir les valeurs actuelles et précédentes
   double macdMainCurrent = macdMain[0];
   double macdSignalCurrent = macdSignal[0];
   
   // Libérer le handle
   IndicatorRelease(macdHandle);
   
   // Condition haussière: MACD Main Line au-dessus de Signal Line
   bool isBullish = macdMainCurrent > macdSignalCurrent;
   
   return isBullish;
}
};
