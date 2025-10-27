//+------------------------------------------------------------------+
//|                                        TrendFiltersManager.mqh   |
//|                   Interface unifiée pour tous les filtres de tendance |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "TrendFiltersManager.mqh"      |
//|                                                                   |
//| 2. Utilisez les méthodes statiques :                             |
//|    - MACD Filters : CheckMACDBullishCrossover(), CheckMACDBullish() |
//|    - Trend Analysis : CheckHigherTimeframeTrendAdvanced(), CheckHigherTimeframeTrend() |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - TrendFiltersManager::CheckMACDBullishCrossover("EURUSD", PERIOD_H1) |
//| - TrendFiltersManager::CheckHigherTimeframeTrend("GBPUSD", PERIOD_H4, true) |
//+------------------------------------------------------------------+
#property strict

// Inclusion des modules spécialisés
#include "MACDFilters.mqh"
#include "TrendAnalysis.mqh"

//+------------------------------------------------------------------+
//| Classe manager unifiée pour tous les filtres de tendance        |
//+------------------------------------------------------------------+
class TrendFiltersManager
{
public:
//+------------------------------------------------------------------+
//| Détecte le croisement haussier du MACD sur un timeframe donné.   |
//| Délègue à MACDFilters::CheckMACDBullishCrossover()               |
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
   return MACDFilters::CheckMACDBullishCrossover(symbol, timeframe, fast_period, slow_period, signal_period);
}

//+------------------------------------------------------------------+
//| Retourne true si le MACD est actuellement haussier, simple.      |
//| Délègue à MACDFilters::CheckMACDBullish()                       |
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
   return MACDFilters::CheckMACDBullish(symbol, timeframe, fast_period, slow_period, signal_period);
}

//+------------------------------------------------------------------+
//| Détecte une tendance avancée sur un timeframe supérieur.         |
//| Délègue à TrendAnalysis::CheckHigherTimeframeTrendAdvanced()   |
//| @param symbol Symbole à analyser                                  |
//| @param higher_tf Timeframe supérieur à analyser                 |
//| @param bullish true pour tendance haussière, false pour baissière |
//| @return true si tendance confirmée par plusieurs indicateurs     |
//+------------------------------------------------------------------+
static bool CheckHigherTimeframeTrendAdvanced(string symbol, ENUM_TIMEFRAMES higher_tf, bool bullish)
{
   return TrendAnalysis::CheckHigherTimeframeTrendAdvanced(symbol, higher_tf, bullish);
}

//+------------------------------------------------------------------+
//| Vérifie la tendance haussière ou baissière sur timeframe supérieur.|
//| Délègue à TrendAnalysis::CheckHigherTimeframeTrend()             |
//| @param symbol Symbole à analyser                                  |
//| @param higher_tf Timeframe supérieur à analyser                 |
//| @param bullish true pour tendance haussière, false pour baissière |
//| @return true si tendance détectée par MA                         |
//+------------------------------------------------------------------+
static bool CheckHigherTimeframeTrend(string symbol, ENUM_TIMEFRAMES higher_tf, bool bullish)
{
   return TrendAnalysis::CheckHigherTimeframeTrend(symbol, higher_tf, bullish);
}

//+------------------------------------------------------------------+
//| Méthode de convenance pour vérifier la confluence MACD + Trend   |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe pour MACD                             |
//| @param higher_tf Timeframe supérieur pour tendance               |
//| @param bullish true pour confluence haussière                   |
//| @return true si MACD et tendance sont alignés                    |
//+------------------------------------------------------------------+
static bool CheckMACDTrendConfluence(string symbol, ENUM_TIMEFRAMES timeframe, 
                                     ENUM_TIMEFRAMES higher_tf, bool bullish)
{
   bool macdBullish = CheckMACDBullish(symbol, timeframe);
   bool trendBullish = CheckHigherTimeframeTrend(symbol, higher_tf, bullish);
   
   return (macdBullish == trendBullish);
}

//+------------------------------------------------------------------+
//| Méthode de convenance pour vérifier la confluence avancée        |
//| MACD Crossover + Trend Advanced                                  |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe pour MACD                             |
//| @param higher_tf Timeframe supérieur pour tendance               |
//| @param bullish true pour confluence haussière                   |
//| @return true si croisement MACD et tendance avancée alignés     |
//+------------------------------------------------------------------+
static bool CheckAdvancedConfluence(string symbol, ENUM_TIMEFRAMES timeframe, 
                                    ENUM_TIMEFRAMES higher_tf, bool bullish)
{
   bool macdCrossover = CheckMACDBullishCrossover(symbol, timeframe);
   bool advancedTrend = CheckHigherTimeframeTrendAdvanced(symbol, higher_tf, bullish);
   
   return (macdCrossover && advancedTrend);
}
};
