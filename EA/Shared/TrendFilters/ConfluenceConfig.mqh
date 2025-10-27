//+------------------------------------------------------------------+
//|                                        ConfluenceConfig.mqh      |
//|                   Configuration paramétrable des Confluences     |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "ConfluenceConfig.mqh"         |
//| 2. Créez une instance : ConfluenceConfig config;                |
//| 3. Configurez les paramètres selon vos besoins                   |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - ConfluenceConfig config; config.SetScalpingMode("US100");      |
//| - ConfluenceConfig config; config.SetConservativeMode("EURUSD"); |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Structure de configuration des confluences                      |
//+------------------------------------------------------------------+
struct ConfluenceConfig
{
   //=== CONFIGURATION GÉNÉRALE ===
   bool              enableConfluence;        // Activer le système de confluences
   int               minConfluenceScore;      // Score minimum requis (ex: 3)
   int               maxConfluenceScore;      // Score maximum possible (ex: 6)
   bool              useStrictMode;          // Mode strict (tous les filtres requis)
   
   //=== VOLUME FILTERS ===
   bool              enableVolumeFilter;     // Activer filtre volume
   double            minVolumeMultiplier;    // Multiplicateur volume minimum (ex: 1.2)
   int               volumePeriods;         // Périodes pour moyenne volume (ex: 20)
   double            volumeSpikeMultiplier;  // Multiplicateur pour pic volume (ex: 1.5)
   int               volumeTrendPeriods;     // Périodes pour tendance volume (ex: 5)
   
   //=== SUPPORT/RESISTANCE FILTERS ===
   bool              enableEMA200Filter;     // Activer filtre EMA200
   int               ema200Period;           // Période EMA200 (ex: 200)
   double            ema200Tolerance;       // Tolérance EMA200 en points (ex: 5.0)
   bool              enableDynamicLevels;   // Activer niveaux dynamiques multiples
   int               ema50Period;           // Période EMA50 (ex: 50)
   int               ema100Period;          // Période EMA100 (ex: 100)
   bool              enableStaticLevels;    // Activer niveaux statiques
   int               staticLevelsLookback;  // Périodes pour niveaux statiques (ex: 20)
   double            staticLevelsTolerance; // Tolérance niveaux statiques (ex: 20.0)
   
   //=== MACD FILTERS ===
   bool              enableMACDFilter;       // Activer filtre MACD
   int               macdFastPeriod;        // Période rapide MACD (ex: 12)
   int               macdSlowPeriod;        // Période lente MACD (ex: 26)
   int               macdSignalPeriod;      // Période signal MACD (ex: 9)
   bool              useMACDCrossover;      // Utiliser croisement MACD
   bool              useMACDState;          // Utiliser état MACD simple
   
   //=== OSCILLATOR FILTERS ===
   bool              enableStochasticFilter; // Activer filtre Stochastique
   int               stochKPeriod;         // Période K Stochastique (ex: 14)
   int               stochDPeriod;          // Période D Stochastique (ex: 3)
   int               stochSlowing;         // Slowing Stochastique (ex: 3)
   int               stochOversoldLevel;   // Niveau survente Stochastique (ex: 20)
   int               stochOverboughtLevel; // Niveau surachat Stochastique (ex: 80)
   
   bool              enableRSIDivergence;  // Activer divergence RSI
   int               rsiDivergencePeriod;  // Période RSI pour divergence (ex: 14)
   int               rsiDivergenceLookback; // Périodes pour divergence (ex: 10)
   
   bool              enableWilliamsR;      // Activer Williams %R
   int               williamsRPeriod;      // Période Williams %R (ex: 14)
   double            williamsROversold;    // Niveau survente Williams %R (ex: -80)
   double            williamsROverbought;  // Niveau surachat Williams %R (ex: -20)
   
   //=== PRICE ACTION FILTERS ===
   bool              enablePsychologicalLevels; // Activer niveaux psychologiques
   double            psychologicalStep;    // Pas niveaux psychologiques (ex: 100.0)
   double            psychologicalTolerance; // Tolérance niveaux psychologiques (ex: 5.0)
   
   bool              enableCandlestickPatterns; // Activer patterns chandeliers
   int               candlestickLookback;   // Périodes pour patterns (ex: 3)
   
   bool              enableMarketStructure; // Activer structure de marché
   int               marketStructureLookback; // Périodes pour structure (ex: 10)
   
   //=== MULTI-TIMEFRAME ===
   bool              enableMultiTimeframe; // Activer multi-timeframe
   ENUM_TIMEFRAMES   higherTimeframe;      // Timeframe supérieur (ex: PERIOD_M15)
   bool              useAdvancedTrend;    // Utiliser tendance avancée
   
   //=== CONFIGURATIONS PRÉDÉFINIES ===
   string            presetMode;          // Mode prédéfini ("SCALPING", "SWING", "CUSTOM")
   string            symbolType;          // Type de symbole ("FOREX", "INDICES", "CRYPTO")
   
   // Constructor par défaut
   ConfluenceConfig()
   {
      // Configuration par défaut
      enableConfluence = true;
      minConfluenceScore = 3;
      maxConfluenceScore = 6;
      useStrictMode = false;
      
      // Volume Filters
      enableVolumeFilter = true;
      minVolumeMultiplier = 1.2;
      volumePeriods = 20;
      volumeSpikeMultiplier = 1.5;
      volumeTrendPeriods = 5;
      
      // Support/Resistance Filters
      enableEMA200Filter = true;
      ema200Period = 200;
      ema200Tolerance = 5.0;
      enableDynamicLevels = false;
      ema50Period = 50;
      ema100Period = 100;
      enableStaticLevels = false;
      staticLevelsLookback = 20;
      staticLevelsTolerance = 20.0;
      
      // MACD Filters
      enableMACDFilter = true;
      macdFastPeriod = 12;
      macdSlowPeriod = 26;
      macdSignalPeriod = 9;
      useMACDCrossover = false;
      useMACDState = true;
      
      // Oscillator Filters
      enableStochasticFilter = true;
      stochKPeriod = 14;
      stochDPeriod = 3;
      stochSlowing = 3;
      stochOversoldLevel = 20;
      stochOverboughtLevel = 80;
      
      enableRSIDivergence = false;
      rsiDivergencePeriod = 14;
      rsiDivergenceLookback = 10;
      
      enableWilliamsR = false;
      williamsRPeriod = 14;
      williamsROversold = -80.0;
      williamsROverbought = -20.0;
      
      // Price Action Filters
      enablePsychologicalLevels = true;
      psychologicalStep = 100.0;
      psychologicalTolerance = 5.0;
      
      enableCandlestickPatterns = false;
      candlestickLookback = 3;
      
      enableMarketStructure = false;
      marketStructureLookback = 10;
      
      // Multi-timeframe
      enableMultiTimeframe = true;
      higherTimeframe = PERIOD_M15;
      useAdvancedTrend = false;
      
      // Configuration prédéfinie
      presetMode = "CUSTOM";
      symbolType = "INDICES";
   }
   
   //=== MÉTHODES DE CONFIGURATION PRÉDÉFINIES ===
   
   // Configuration pour scalping (US100, US30, etc.)
   void SetScalpingMode(string symbol = "")
   {
      presetMode = "SCALPING";
      
      // Score plus strict pour scalping
      minConfluenceScore = 4;
      maxConfluenceScore = 6;
      
      // Volume critique pour scalping
      enableVolumeFilter = true;
      minVolumeMultiplier = 1.3;
      volumePeriods = 15;
      volumeSpikeMultiplier = 1.8;
      
      // EMA200 essentiel pour scalping
      enableEMA200Filter = true;
      ema200Tolerance = 3.0; // Plus strict
      
      // MACD rapide pour scalping
      enableMACDFilter = true;
      macdFastPeriod = 8;
      macdSlowPeriod = 21;
      macdSignalPeriod = 5;
      useMACDState = true;
      
      // Stochastique rapide
      enableStochasticFilter = true;
      stochKPeriod = 10;
      stochDPeriod = 3;
      stochSlowing = 2;
      
      // Niveaux psychologiques selon le symbole
      enablePsychologicalLevels = true;
      if(StringFind(symbol, "US100") >= 0 || StringFind(symbol, "US30") >= 0)
      {
         psychologicalStep = 100.0;
         symbolType = "INDICES";
      }
      else if(StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "GBPUSD") >= 0)
      {
         psychologicalStep = 0.01;
         symbolType = "FOREX";
      }
      
      // Multi-timeframe pour confirmation
      enableMultiTimeframe = true;
      higherTimeframe = PERIOD_M15;
      useAdvancedTrend = false;
      
      // Désactiver les filtres lents
      enableRSIDivergence = false;
      enableWilliamsR = false;
      enableCandlestickPatterns = false;
      enableMarketStructure = false;
      enableDynamicLevels = false;
      enableStaticLevels = false;
   }
   
   // Configuration pour swing trading
   void SetSwingMode(string symbol = "")
   {
      presetMode = "SWING";
      
      // Score plus flexible pour swing
      minConfluenceScore = 2;
      maxConfluenceScore = 6;
      
      // Volume moins critique pour swing
      enableVolumeFilter = true;
      minVolumeMultiplier = 1.1;
      volumePeriods = 30;
      
      // EMA200 avec plus de tolérance
      enableEMA200Filter = true;
      ema200Tolerance = 10.0;
      enableDynamicLevels = true;
      
      // MACD standard
      enableMACDFilter = true;
      macdFastPeriod = 12;
      macdSlowPeriod = 26;
      macdSignalPeriod = 9;
      useMACDCrossover = true;
      
      // Stochastique standard
      enableStochasticFilter = true;
      stochKPeriod = 14;
      stochDPeriod = 3;
      stochSlowing = 3;
      
      // Activer tous les filtres pour swing
      enableRSIDivergence = true;
      enableWilliamsR = true;
      enableCandlestickPatterns = true;
      enableMarketStructure = true;
      
      // Multi-timeframe avec tendance avancée
      enableMultiTimeframe = true;
      higherTimeframe = PERIOD_H1;
      useAdvancedTrend = true;
      
      // Niveaux psychologiques selon le symbole
      enablePsychologicalLevels = true;
      if(StringFind(symbol, "US100") >= 0 || StringFind(symbol, "US30") >= 0)
      {
         psychologicalStep = 100.0;
         symbolType = "INDICES";
      }
      else if(StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "GBPUSD") >= 0)
      {
         psychologicalStep = 0.01;
         symbolType = "FOREX";
      }
   }
   
   // Configuration conservative (moins de signaux, plus de qualité)
   void SetConservativeMode(string symbol = "")
   {
      presetMode = "CONSERVATIVE";
      
      // Score très strict
      minConfluenceScore = 5;
      maxConfluenceScore = 6;
      useStrictMode = true;
      
      // Volume élevé requis
      enableVolumeFilter = true;
      minVolumeMultiplier = 1.5;
      volumeSpikeMultiplier = 2.0;
      
      // EMA200 très strict
      enableEMA200Filter = true;
      ema200Tolerance = 2.0;
      enableDynamicLevels = true;
      
      // MACD avec croisement
      enableMACDFilter = true;
      useMACDCrossover = true;
      useMACDState = false;
      
      // Tous les oscillateurs
      enableStochasticFilter = true;
      enableRSIDivergence = true;
      enableWilliamsR = true;
      
      // Tous les filtres Price Action
      enablePsychologicalLevels = true;
      enableCandlestickPatterns = true;
      enableMarketStructure = true;
      
      // Multi-timeframe avec tendance avancée
      enableMultiTimeframe = true;
      higherTimeframe = PERIOD_H4;
      useAdvancedTrend = true;
      
      // Configuration selon le symbole
      if(StringFind(symbol, "US100") >= 0 || StringFind(symbol, "US30") >= 0)
      {
         psychologicalStep = 100.0;
         symbolType = "INDICES";
      }
      else if(StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "GBPUSD") >= 0)
      {
         psychologicalStep = 0.01;
         symbolType = "FOREX";
      }
   }
   
   // Configuration agressive (plus de signaux, moins de filtres)
   void SetAggressiveMode(string symbol = "")
   {
      presetMode = "AGGRESSIVE";
      
      // Score très flexible
      minConfluenceScore = 2;
      maxConfluenceScore = 6;
      
      // Volume moins strict
      enableVolumeFilter = true;
      minVolumeMultiplier = 1.1;
      
      // EMA200 avec tolérance large
      enableEMA200Filter = true;
      ema200Tolerance = 15.0;
      
      // MACD simple
      enableMACDFilter = true;
      useMACDState = true;
      useMACDCrossover = false;
      
      // Stochastique seulement
      enableStochasticFilter = true;
      enableRSIDivergence = false;
      enableWilliamsR = false;
      
      // Niveaux psychologiques seulement
      enablePsychologicalLevels = true;
      enableCandlestickPatterns = false;
      enableMarketStructure = false;
      
      // Multi-timeframe simple
      enableMultiTimeframe = true;
      higherTimeframe = PERIOD_M15;
      useAdvancedTrend = false;
      
      // Configuration selon le symbole
      if(StringFind(symbol, "US100") >= 0 || StringFind(symbol, "US30") >= 0)
      {
         psychologicalStep = 100.0;
         symbolType = "INDICES";
      }
      else if(StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "GBPUSD") >= 0)
      {
         psychologicalStep = 0.01;
         symbolType = "FOREX";
      }
   }
   
   //=== MÉTHODES UTILITAIRES ===
   
   // Calculer le score maximum possible
   int CalculateMaxScore()
   {
      int maxScore = 0;
      
      if(enableVolumeFilter) maxScore++;
      if(enableEMA200Filter) maxScore++;
      if(enableMACDFilter) maxScore++;
      if(enableStochasticFilter) maxScore++;
      if(enableMultiTimeframe) maxScore++;
      if(enablePsychologicalLevels) maxScore++;
      
      return maxScore;
   }
   
   // Valider la configuration
   bool Validate()
   {
      if(minConfluenceScore < 1)
      {
         Print("ConfluenceConfig: minConfluenceScore must be >= 1");
         return false;
      }
      
      if(minConfluenceScore > maxConfluenceScore)
      {
         Print("ConfluenceConfig: minConfluenceScore cannot be > maxConfluenceScore");
         return false;
      }
      
      if(minVolumeMultiplier < 0.5)
      {
         Print("ConfluenceConfig: minVolumeMultiplier must be >= 0.5");
         return false;
      }
      
      if(ema200Tolerance < 0)
      {
         Print("ConfluenceConfig: ema200Tolerance must be >= 0");
         return false;
      }
      
      return true;
   }
   
   // Afficher la configuration
   void PrintConfig()
   {
      Print("=== CONFLUENCE CONFIGURATION ===");
      Print("Mode: ", presetMode);
      Print("Symbol Type: ", symbolType);
      Print("Confluence Score: ", IntegerToString(minConfluenceScore), "/", IntegerToString(maxConfluenceScore));
      Print("Strict Mode: ", (useStrictMode ? "ON" : "OFF"));
      Print("");
      Print("Volume Filter: ", (enableVolumeFilter ? "ON" : "OFF"));
      if(enableVolumeFilter)
      {
         Print("  - Min Multiplier: ", DoubleToString(minVolumeMultiplier, 2));
         Print("  - Periods: ", IntegerToString(volumePeriods));
      }
      Print("");
      Print("EMA200 Filter: ", (enableEMA200Filter ? "ON" : "OFF"));
      if(enableEMA200Filter)
      {
         Print("  - Period: ", IntegerToString(ema200Period));
         Print("  - Tolerance: ", DoubleToString(ema200Tolerance, 1), " points");
      }
      Print("");
      Print("MACD Filter: ", (enableMACDFilter ? "ON" : "OFF"));
      if(enableMACDFilter)
      {
         Print("  - Fast/Slow/Signal: ", IntegerToString(macdFastPeriod), "/", 
               IntegerToString(macdSlowPeriod), "/", IntegerToString(macdSignalPeriod));
         Print("  - Crossover: ", (useMACDCrossover ? "ON" : "OFF"));
         Print("  - State: ", (useMACDState ? "ON" : "OFF"));
      }
      Print("");
      Print("Stochastic Filter: ", (enableStochasticFilter ? "ON" : "OFF"));
      if(enableStochasticFilter)
      {
         Print("  - K/D/Slowing: ", IntegerToString(stochKPeriod), "/", 
               IntegerToString(stochDPeriod), "/", IntegerToString(stochSlowing));
      }
      Print("");
      Print("Multi-timeframe: ", (enableMultiTimeframe ? "ON" : "OFF"));
      if(enableMultiTimeframe)
      {
         Print("  - Higher TF: ", EnumToString(higherTimeframe));
         Print("  - Advanced Trend: ", (useAdvancedTrend ? "ON" : "OFF"));
      }
      Print("");
      Print("Psychological Levels: ", (enablePsychologicalLevels ? "ON" : "OFF"));
      if(enablePsychologicalLevels)
      {
         Print("  - Step: ", DoubleToString(psychologicalStep, 2));
         Print("  - Tolerance: ", DoubleToString(psychologicalTolerance, 1), "%");
      }
      Print("================================");
   }
};
