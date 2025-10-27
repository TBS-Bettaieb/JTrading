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
#include "VolumeFilters.mqh"
#include "SupportResistanceFilters.mqh"
#include "OscillatorFilters.mqh"
#include "PriceActionFilters.mqh"
#include "ConfluenceConfig.mqh"

//+------------------------------------------------------------------+
//| Classe manager unifiée pour tous les filtres de tendance        |
//+------------------------------------------------------------------+
class TrendFiltersManager
{
private:
   static ConfluenceConfig s_config;

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

//+------------------------------------------------------------------+
//| Méthodes de délégation pour les nouveaux filtres               |
//+------------------------------------------------------------------+

//--- Volume Filters
static bool CheckVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy, double minMultiplier = 1.2)
{
   return VolumeFilters::CheckVolumeConfluence(symbol, timeframe, isBuy, minMultiplier);
}

static bool CheckVolumeSpike(string symbol, ENUM_TIMEFRAMES timeframe, double multiplier = 1.5)
{
   return VolumeFilters::CheckVolumeSpike(symbol, timeframe, multiplier);
}

static bool CheckBuyVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, double minMultiplier = 1.2)
{
   return VolumeFilters::CheckBuyVolumeConfluence(symbol, timeframe, minMultiplier);
}

static bool CheckSellVolumeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, double minMultiplier = 1.2)
{
   return VolumeFilters::CheckSellVolumeConfluence(symbol, timeframe, minMultiplier);
}

//--- Support/Resistance Filters
static bool CheckEMAConfluence(string symbol, ENUM_TIMEFRAMES timeframe, int emaPeriod = 200, bool isBuy = true)
{
   return SupportResistanceFilters::CheckEMAConfluence(symbol, timeframe, emaPeriod, isBuy);
}

static bool CheckEMA200Confluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return SupportResistanceFilters::CheckEMA200Confluence(symbol, timeframe, isBuy);
}

static bool CheckDynamicLevels(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return SupportResistanceFilters::CheckDynamicLevels(symbol, timeframe, isBuy);
}

static bool CheckSupportResistanceConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return SupportResistanceFilters::CheckSupportResistanceConfluence(symbol, timeframe, isBuy);
}

//--- Oscillator Filters
static bool CheckStochasticConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return OscillatorFilters::CheckStochasticConfluence(symbol, timeframe, isBuy);
}

static bool CheckRSIDivergence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return OscillatorFilters::CheckRSIDivergence(symbol, timeframe, isBuy);
}

static bool CheckOscillatorsConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return OscillatorFilters::CheckOscillatorsConfluence(symbol, timeframe, isBuy);
}

//--- Price Action Filters
static bool CheckPsychologicalLevels(string symbol, double step, bool isBuy = true)
{
   return PriceActionFilters::CheckPsychologicalLevels(symbol, step, isBuy);
}

static bool CheckCandlestickPatterns(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return PriceActionFilters::CheckCandlestickPatterns(symbol, timeframe, isBuy);
}

static bool CheckMarketStructure(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true)
{
   return PriceActionFilters::CheckMarketStructure(symbol, timeframe, isBuy);
}

static bool CheckPriceActionConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy = true, double psychologicalStep = 100.0)
{
   return PriceActionFilters::CheckPriceActionConfluence(symbol, timeframe, isBuy, psychologicalStep);
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
   confluenceScore = 0;
   
   // 1. MACD confluence
   if(isBuy)
   {
      if(CheckMACDBullish(symbol, timeframe))
         confluenceScore++;
   }
   else
   {
      if(MACDFilters::CheckMACDBearish(symbol, timeframe))
         confluenceScore++;
   }
   
   // 2. Multi-timeframe trend
   if(CheckHigherTimeframeTrend(symbol, PERIOD_M15, isBuy))
      confluenceScore++;
   
   // 3. Volume confluence
   if(isBuy)
   {
      if(CheckBuyVolumeConfluence(symbol, timeframe))
         confluenceScore++;
   }
   else
   {
      if(CheckSellVolumeConfluence(symbol, timeframe))
         confluenceScore++;
   }
   
   // 4. EMA200 confluence
   if(CheckEMA200Confluence(symbol, timeframe, isBuy))
      confluenceScore++;
   
   // 5. Stochastique confluence
   if(CheckStochasticConfluence(symbol, timeframe, isBuy))
      confluenceScore++;
   
   // 6. Niveaux psychologiques (pour US100/US30)
   if(CheckPsychologicalLevels(symbol, 100.0, isBuy))
      confluenceScore++;
   
   // Minimum 3 confluences sur 6 pour validation
   bool confluenceOK = (confluenceScore >= 3);
   
   Print("TrendFiltersManager: Complete confluence for ", symbol, " - Score: ", 
         IntegerToString(confluenceScore), "/6, Valid: ", (confluenceOK ? "YES" : "NO"));
   
   return confluenceOK;
}

//+------------------------------------------------------------------+
//| Méthodes de configuration des confluences                      |
//+------------------------------------------------------------------+

//--- Configuration des confluences
static void SetConfluenceConfig(ConfluenceConfig &config)
{
   s_config = config;
   Print("TrendFiltersManager: Confluence configuration updated - Mode: ", config.presetMode);
}

static ConfluenceConfig GetConfluenceConfig()
{
   return s_config;
}

//--- Méthode de confluence paramétrable
static bool CheckParametricConfluence(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy, int &confluenceScore)
{
   confluenceScore = 0;
   
   // 1. MACD confluence (si activé)
   if(s_config.enableMACDFilter)
   {
      bool macdOK = false;
      if(s_config.useMACDCrossover)
      {
         macdOK = isBuy ? CheckMACDBullishCrossover(symbol, timeframe, 
                                                   s_config.macdFastPeriod,
                                                   s_config.macdSlowPeriod,
                                                   s_config.macdSignalPeriod) :
                          MACDFilters::CheckMACDBearishCrossover(symbol, timeframe,
                                                                s_config.macdFastPeriod,
                                                                s_config.macdSlowPeriod,
                                                                s_config.macdSignalPeriod);
      }
      else if(s_config.useMACDState)
      {
         macdOK = isBuy ? CheckMACDBullish(symbol, timeframe,
                                           s_config.macdFastPeriod,
                                           s_config.macdSlowPeriod,
                                           s_config.macdSignalPeriod) :
                          MACDFilters::CheckMACDBearish(symbol, timeframe,
                                                        s_config.macdFastPeriod,
                                                        s_config.macdSlowPeriod,
                                                        s_config.macdSignalPeriod);
      }
      
      if(macdOK) confluenceScore++;
   }
   
   // 2. Multi-timeframe confluence (si activé)
   if(s_config.enableMultiTimeframe)
   {
      bool trendOK = false;
      if(s_config.useAdvancedTrend)
      {
         trendOK = CheckHigherTimeframeTrendAdvanced(symbol, s_config.higherTimeframe, isBuy);
      }
      else
      {
         trendOK = CheckHigherTimeframeTrend(symbol, s_config.higherTimeframe, isBuy);
      }
      
      if(trendOK) confluenceScore++;
   }
   
   // 3. Volume confluence (si activé)
   if(s_config.enableVolumeFilter)
   {
      bool volumeOK = isBuy ? CheckBuyVolumeConfluence(symbol, timeframe, s_config.minVolumeMultiplier) :
                              CheckSellVolumeConfluence(symbol, timeframe, s_config.minVolumeMultiplier);
      
      if(volumeOK) confluenceScore++;
   }
   
   // 4. EMA200 confluence (si activé)
   if(s_config.enableEMA200Filter)
   {
      bool ema200OK = CheckEMA200Confluence(symbol, timeframe, isBuy);
      
      if(ema200OK) confluenceScore++;
   }
   
   // 5. Stochastique confluence (si activé)
   if(s_config.enableStochasticFilter)
   {
      bool stochOK = CheckStochasticConfluence(symbol, timeframe, isBuy);
      
      if(stochOK) confluenceScore++;
   }
   
   // 6. Niveaux psychologiques confluence (si activé)
   if(s_config.enablePsychologicalLevels)
   {
      bool psychologicalOK = CheckPsychologicalLevels(symbol, s_config.psychologicalStep, isBuy);
      
      if(psychologicalOK) confluenceScore++;
   }
   
   // Validation selon le mode
   bool confluenceOK = false;
   if(s_config.useStrictMode)
   {
      // Mode strict : tous les filtres activés doivent être validés
      int maxPossibleScore = s_config.CalculateMaxScore();
      confluenceOK = (confluenceScore == maxPossibleScore);
   }
   else
   {
      // Mode normal : score minimum requis
      confluenceOK = (confluenceScore >= s_config.minConfluenceScore);
   }
   
   Print("TrendFiltersManager: Parametric confluence for ", symbol, " - Score: ", 
         IntegerToString(confluenceScore), "/", IntegerToString(s_config.CalculateMaxScore()), 
         ", Valid: ", (confluenceOK ? "YES" : "NO"));
   
   return confluenceOK;
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
};

//+------------------------------------------------------------------+
//| Définition de la variable statique en dehors de la classe      |
//+------------------------------------------------------------------+
ConfluenceConfig TrendFiltersManager::s_config;
