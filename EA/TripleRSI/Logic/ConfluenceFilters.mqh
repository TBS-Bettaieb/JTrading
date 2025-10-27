//+------------------------------------------------------------------+
//|                                        ConfluenceFilters.mqh     |
//|                   Filtres statiques de confluence pour trading   |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "../Logic/ConfluenceFilters.mqh" |
//|                                                                   |
//| 2. Utilisez les méthodes statiques :                             |
//|    - CheckMACDBullishCrossover() : détecte croisement MACD       |
//|    - CheckMACDBullish() : vérifie état MACD haussier             |
//|    - CheckHigherTimeframeTrendAdvanced() : tendance avancée      |
//|    - CheckHigherTimeframeTrend() : tendance simple               |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - ConfluenceFilters::CheckMACDBullishCrossover("EURUSD", PERIOD_H1, 12, 26, 9) |
//| - ConfluenceFilters::CheckHigherTimeframeTrend("GBPUSD", PERIOD_H4, true)     |
//|                                                                   |
//| NOTE : Cette classe délègue maintenant aux modules spécialisés   |
//| dans le dossier TrendFilters/ pour une meilleure organisation.   |
//+------------------------------------------------------------------+
#property strict

// Inclusion du manager unifié des filtres de tendance
#include "../../Shared/TrendFilters/TrendFiltersManager.mqh"

//+------------------------------------------------------------------+
//| Classe statique pour les filtres de confluence                  |
//| Délègue aux modules spécialisés pour une meilleure organisation |
//+------------------------------------------------------------------+
class ConfluenceFilters
{
public:
//+------------------------------------------------------------------+
//| Détecte le croisement haussier du MACD sur un timeframe donné.   |
//| Délègue à TrendFiltersManager::CheckMACDBullishCrossover()       |
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
   return TrendFiltersManager::CheckMACDBullishCrossover(symbol, timeframe, fast_period, slow_period, signal_period);
}

//+------------------------------------------------------------------+
//| Retourne true si le MACD est actuellement haussier, simple.      |
//| Délègue à TrendFiltersManager::CheckMACDBullish()                |
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
   return TrendFiltersManager::CheckMACDBullish(symbol, timeframe, fast_period, slow_period, signal_period);
}

//+------------------------------------------------------------------+
//| Détecte une tendance avancée sur un timeframe supérieur.         |
//| Délègue à TrendFiltersManager::CheckHigherTimeframeTrendAdvanced() |
//| @param symbol Symbole à analyser                                  |
//| @param higher_tf Timeframe supérieur à analyser                 |
//| @param bullish true pour tendance haussière, false pour baissière |
//| @return true si tendance confirmée par plusieurs indicateurs     |
//+------------------------------------------------------------------+
static bool CheckHigherTimeframeTrendAdvanced(string symbol, ENUM_TIMEFRAMES higher_tf, bool bullish)
{
   return TrendFiltersManager::CheckHigherTimeframeTrendAdvanced(symbol, higher_tf, bullish);
}

//+------------------------------------------------------------------+
//| Vérifie la tendance haussière ou baissière sur timeframe supérieur.|
//| Délègue à TrendFiltersManager::CheckHigherTimeframeTrend()        |
//| @param symbol Symbole à analyser                                  |
//| @param higher_tf Timeframe supérieur à analyser                 |
//| @param bullish true pour tendance haussière, false pour baissière |
//| @return true si tendance détectée par MA                         |
//+------------------------------------------------------------------+
static bool CheckHigherTimeframeTrend(string symbol, ENUM_TIMEFRAMES higher_tf, bool bullish)
{
   return TrendFiltersManager::CheckHigherTimeframeTrend(symbol, higher_tf, bullish);
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
   return TrendFiltersManager::CheckMACDTrendConfluence(symbol, timeframe, higher_tf, bullish);
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
   return TrendFiltersManager::CheckAdvancedConfluence(symbol, timeframe, higher_tf, bullish);
}
};
