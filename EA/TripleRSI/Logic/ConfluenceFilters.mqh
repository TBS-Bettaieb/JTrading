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

//+------------------------------------------------------------------+
//| Méthodes de délégation pour les nouveaux filtres               |
//+------------------------------------------------------------------+

//--- Volume Filters
static bool CheckVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy, double minMultiplier = 1.2)
{
   return TrendFiltersManager::CheckVolumeConfluence(symbol, timeframe, isBuy, minMultiplier);
}

static bool CheckBuyVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, double minMultiplier = 1.2)
{
   return TrendFiltersManager::CheckBuyVolumeConfluence(symbol, timeframe, minMultiplier);
}

static bool CheckSellVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, double minMultiplier = 1.2)
{
   return TrendFiltersManager::CheckSellVolumeConfluence(symbol, timeframe, minMultiplier);
}

//--- Support/Resistance Filters
static bool CheckEMA200Confluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return TrendFiltersManager::CheckEMA200Confluence(symbol, timeframe, isBuy);
}

static bool CheckSupportResistanceConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return TrendFiltersManager::CheckSupportResistanceConfluence(symbol, timeframe, isBuy);
}

//--- Oscillator Filters
static bool CheckStochasticConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return TrendFiltersManager::CheckStochasticConfluence(symbol, timeframe, isBuy);
}

static bool CheckOscillatorsConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return TrendFiltersManager::CheckOscillatorsConfluence(symbol, timeframe, isBuy);
}

//--- Price Action Filters
static bool CheckPsychologicalLevels(string symbol, double step, bool isBuy = true)
{
   return TrendFiltersManager::CheckPsychologicalLevels(symbol, step, isBuy);
}

static bool CheckPriceActionConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true, double psychologicalStep = 100.0)
{
   return TrendFiltersManager::CheckPriceActionConfluence(symbol, timeframe, isBuy, psychologicalStep);
}

//+------------------------------------------------------------------+
//| Méthode de confluence complète pour Triple RSI                 |
//| Combine tous les filtres disponibles pour une validation robuste |
//| @param symbol Symbole à analyser                                  |
//| @param timeframe Timeframe d'analyse                             |
//| @param isBuy true pour signal d'achat, false pour vente         |
//| @param confluenceScore Score de confluence (sortie)             |
//| @return true si confluence complète validée                     |
//+------------------------------------------------------------------+
static bool CheckCompleteConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy, int &confluenceScore)
{
   return TrendFiltersManager::CheckCompleteConfluence(symbol, timeframe, isBuy, confluenceScore);
}

//+------------------------------------------------------------------+
//| Méthodes de configuration des confluences                      |
//+------------------------------------------------------------------+

//--- Configuration des confluences
static void SetConfluenceConfig(ConfluenceConfig &config)
{
   TrendFiltersManager::SetConfluenceConfig(config);
}

static ConfluenceConfig GetConfluenceConfig()
{
   return TrendFiltersManager::GetConfluenceConfig();
}

//--- Méthode de confluence paramétrable
static bool CheckParametricConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy, int &confluenceScore)
{
   return TrendFiltersManager::CheckParametricConfluence(symbol, timeframe, isBuy, confluenceScore);
}

//--- Méthodes de configuration rapide
static void SetScalpingMode(string symbol = "")
{
   ConfluenceConfig config;
   config.SetScalpingMode(symbol);
   SetConfluenceConfig(config);
}

static void SetSwingMode(string symbol = "")
{
   ConfluenceConfig config;
   config.SetSwingMode(symbol);
   SetConfluenceConfig(config);
}

static void SetConservativeMode(string symbol = "")
{
   ConfluenceConfig config;
   config.SetConservativeMode(symbol);
   SetConfluenceConfig(config);
}

static void SetAggressiveMode(string symbol = "")
{
   ConfluenceConfig config;
   config.SetAggressiveMode(symbol);
   SetConfluenceConfig(config);
}

//--- Méthode de configuration personnalisée
static void SetCustomConfig(bool enableVolume = true, bool enableEMA200 = true, bool enableMACD = true,
                           bool enableStochastic = true, bool enableMultiTimeframe = true, 
                           bool enablePsychological = true, int minScore = 3)
{
   ConfluenceConfig config;
   
   config.enableVolumeFilter = enableVolume;
   config.enableEMA200Filter = enableEMA200;
   config.enableMACDFilter = enableMACD;
   config.enableStochasticFilter = enableStochastic;
   config.enableMultiTimeframe = enableMultiTimeframe;
   config.enablePsychologicalLevels = enablePsychological;
   config.minConfluenceScore = minScore;
   
   config.presetMode = "CUSTOM";
   
   SetConfluenceConfig(config);
}

//--- Méthode pour obtenir les informations de configuration
static string GetConfigInfo()
{
   ConfluenceConfig config = GetConfluenceConfig();
   string info = "=== CONFLUENCE CONFIGURATION INFO ===\n";
   info += "Mode: " + config.presetMode + "\n";
   info += "Symbol Type: " + config.symbolType + "\n";
   info += "Min Score: " + IntegerToString(config.minConfluenceScore) + "/" + IntegerToString(config.CalculateMaxScore()) + "\n";
   info += "Strict Mode: " + (config.useStrictMode ? "ON" : "OFF") + "\n";
   info += "Volume Filter: " + (config.enableVolumeFilter ? "ON" : "OFF") + "\n";
   info += "EMA200 Filter: " + (config.enableEMA200Filter ? "ON" : "OFF") + "\n";
   info += "MACD Filter: " + (config.enableMACDFilter ? "ON" : "OFF") + "\n";
   info += "Stochastic Filter: " + (config.enableStochasticFilter ? "ON" : "OFF") + "\n";
   info += "Multi-timeframe: " + (config.enableMultiTimeframe ? "ON" : "OFF") + "\n";
   info += "Psychological Levels: " + (config.enablePsychologicalLevels ? "ON" : "OFF") + "\n";
   info += "=====================================";
   
   return info;
}
};
