//+------------------------------------------------------------------+
//|                                            TripleRSIConfig.mqh   |
//|                                    Configuration Triple RSI      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Configuration structure for Triple RSI Strategy                  |
//+------------------------------------------------------------------+
struct TripleRSIConfig
{
   // Base configuration
   string            strategyName;
   string            strategyComment;
   int               baseMagic;
   string            symbolsList;
   ENUM_TIMEFRAMES   timeframe;
   double            riskPercent;
   
   // Triple RSI Specific parameters
   int               rsiPeriod1;        // RSI période rapide (7)
   int               rsiPeriod2;        // RSI période moyenne (14)
   int               rsiPeriod3;        // RSI période lente (21)
   int               rsiOversold;       // Niveau survente (30)
   int               rsiOverbought;     // Niveau surachat (70)
   
   // Stop Loss / Take Profit
   int               slPoints;          // SL en points
   double            tpRatio;          // Ratio TP/SL (ex: 2.0 = 1:2)
   bool              useTrailingStop;  // Activer trailing stop
   bool              useDynamicTrailing; // Activer TSL dynamique
   int               tslTriggerPoints; // Déclenchement trailing
   int               tslPoints;        // Distance trailing
   double            tslCostMultiplier; // Multiplicateur coûts TSL
   int               tslMinTriggerPoints; // Trigger minimum TSL
   
   // Entry validation
   int               barsLookback;     // Barres pour calcul SL (5)
   
   // Alertes
   bool              useAlerts;
   bool              sendNotifications;
   
   // Logging
   ENUM_LOG_LEVEL    logLevel;
   
   //=== CONFLUENCE CONFIGURATION ===
   bool              enableConfluence;        // Activer le système de confluences
   string            confluenceMode;         // Mode de confluence ("AUTO", "SCALPING", "SWING", "CONSERVATIVE", "AGGRESSIVE")
   int               minConfluenceScore;     // Score minimum requis (ex: 3)
   bool              useStrictMode;         // Mode strict (tous les filtres requis)
   
   // Volume Filters
   bool              enableVolumeFilter;     // Activer filtre volume
   double            minVolumeMultiplier;    // Multiplicateur volume minimum (ex: 1.2)
   
   // Support/Resistance Filters  
   bool              enableEMA200Filter;     // Activer filtre EMA200
   double            ema200Tolerance;       // Tolérance EMA200 en points (ex: 5.0)
   
   // MACD Filters
   bool              enableMACDFilter;       // Activer filtre MACD
   bool              useMACDCrossover;      // Utiliser croisement MACD
   bool              useMACDState;          // Utiliser état MACD simple
   
   // Oscillator Filters
   bool              enableStochasticFilter; // Activer filtre Stochastique
   
   // Price Action Filters
   bool              enablePsychologicalLevels; // Activer niveaux psychologiques
   
   // Multi-timeframe
   bool              enableMultiTimeframe; // Activer multi-timeframe
   ENUM_TIMEFRAMES   higherTimeframe;      // Timeframe supérieur (ex: PERIOD_M15)
   
   //=== DYNAMIC STOP-LOSS CONFIGURATION ===
   bool              useDynamicStopLoss;     // Activer SL dynamique
   int               dynamicSL_SwingLookback; // Périodes pour détecter swings (20)
   int               dynamicSL_SwingMinDistance; // Distance minimale swing points (30)
   double            dynamicSL_SwingVolumeThreshold; // Seuil volume swing (1.2)
   int               dynamicSL_SwingBuffer; // Buffer sécurité swing (5)
   int               dynamicSL_ATRPeriod; // Période ATR standard (14)
   double            dynamicSL_ATRMultiplier; // Multiplicateur ATR (1.5)
   int               dynamicSL_ATRLongPeriod; // Période ATR longue (28)
   double            dynamicSL_ATRLongMultiplier; // Multiplicateur ATR longue (1.2)
   double            dynamicSL_ATRVolatilityThreshold; // Seuil volatilité (1.7)
   double            dynamicSL_DefaultPercent; // SL par défaut en % (0.5)
   
   // Constructor par défaut
   TripleRSIConfig()
   {
      strategyName = "Triple RSI Strategy";
      strategyComment = "TripleRSI";
      baseMagic = 123456;
      symbolsList = "EURUSD,GBPUSD";
      timeframe = PERIOD_M15;
      riskPercent = 1.0;
      
      rsiPeriod1 = 7;
      rsiPeriod2 = 14;
      rsiPeriod3 = 21;
      rsiOversold = 30;
      rsiOverbought = 70;
      
      slPoints = 100;
      tpRatio = 2.0;
      useTrailingStop = true;
      useDynamicTrailing = true;
      tslTriggerPoints = 50;
      tslPoints = 30;
      tslCostMultiplier = 1.5;
      tslMinTriggerPoints = 50;
      
      barsLookback = 5;
      
      useAlerts = true;
      sendNotifications = false;
      
      logLevel = LOG_INFO;
      
      // Configuration des confluences par défaut
      enableConfluence = true;
      confluenceMode = "AUTO";
      minConfluenceScore = 3;
      useStrictMode = false;
      
      enableVolumeFilter = true;
      minVolumeMultiplier = 1.2;
      
      enableEMA200Filter = true;
      ema200Tolerance = 5.0;
      
      enableMACDFilter = true;
      useMACDCrossover = false;
      useMACDState = true;
      
      enableStochasticFilter = true;
      enablePsychologicalLevels = true;
      enableMultiTimeframe = true;
      higherTimeframe = PERIOD_M15;
      
      // Configuration Dynamic Stop-Loss par défaut
      useDynamicStopLoss = true;
      dynamicSL_SwingLookback = 20;
      dynamicSL_SwingMinDistance = 30;
      dynamicSL_SwingVolumeThreshold = 1.2;
      dynamicSL_SwingBuffer = 5;
      dynamicSL_ATRPeriod = 14;
      dynamicSL_ATRMultiplier = 1.5;
      dynamicSL_ATRLongPeriod = 28;
      dynamicSL_ATRLongMultiplier = 1.2;
      dynamicSL_ATRVolatilityThreshold = 1.7;
      dynamicSL_DefaultPercent = 0.5;
   }
   
   // Validation de la configuration
   bool Validate()
   {
      if(rsiPeriod1 <= 0 || rsiPeriod2 <= 0 || rsiPeriod3 <= 0)
      {
         Logger::Error("RSI periods must be positive");
         return false;
      }
      
      // Validation des niveaux RSI - filtrage des périodes trop proches
      if(rsiPeriod2 - rsiPeriod1 <= 2)
      {
         Logger::Error("RSI Period2 - Period1 must be > 2 (current: " + 
                      IntegerToString(rsiPeriod2 - rsiPeriod1) + ")");
         return false;
      }
      
      if(rsiPeriod3 - rsiPeriod2 <= 2)
      {
         Logger::Error("RSI Period3 - Period2 must be > 2 (current: " + 
                      IntegerToString(rsiPeriod3 - rsiPeriod2) + ")");
         return false;
      }
      
      if(rsiOversold >= rsiOverbought)
      {
         Logger::Error("Oversold level must be less than overbought level");
         return false;
      }
      
      if(tpRatio <= 0)
      {
         Logger::Error("TP ratio must be positive");
         return false;
      }
      
      if(riskPercent <= 0 || riskPercent > 10)
      {
         Logger::Error("Risk percent must be between 0 and 10");
         return false;
      }
      
      return true;
   }
   
   // Affichage de la configuration
   void PrintConfig()
   {
      Logger::Info("=== TRIPLE RSI CONFIGURATION ===");
      Logger::Info("Strategy: " + strategyName);
      Logger::Info("Magic: " + IntegerToString(baseMagic));
      Logger::Info("Symbols: " + symbolsList);
      Logger::Info("Timeframe: " + EnumToString(timeframe));
      Logger::Info("Risk: " + DoubleToString(riskPercent, 1) + "%");
      Logger::Info("RSI Periods: " + IntegerToString(rsiPeriod1) + "/" + 
                   IntegerToString(rsiPeriod2) + "/" + IntegerToString(rsiPeriod3));
      Logger::Info("RSI Levels: " + IntegerToString(rsiOversold) + "/" + 
                   IntegerToString(rsiOverbought));
      Logger::Info("SL/TP: " + IntegerToString(slPoints) + "pts / " + 
                   DoubleToString(tpRatio, 1) + "x");
      Logger::Info("Trailing: " + (useTrailingStop ? "ON" : "OFF"));
      if(useTrailingStop)
      {
         Logger::Info("TSL: " + IntegerToString(tslTriggerPoints) + "/" + 
                      IntegerToString(tslPoints) + " pts");
         Logger::Info("Dynamic TSL: " + (useDynamicTrailing ? "ON" : "OFF"));
         if(useDynamicTrailing)
         {
            Logger::Info("TSL Cost Multiplier: " + DoubleToString(tslCostMultiplier, 1));
            Logger::Info("TSL Min Trigger: " + IntegerToString(tslMinTriggerPoints) + " pts");
         }
      }
      
      // Affichage configuration confluences
      Logger::Info("Confluence System: " + (enableConfluence ? "ENABLED" : "DISABLED"));
      if(enableConfluence)
      {
         Logger::Info("Confluence Mode: " + confluenceMode);
         Logger::Info("Min Score: " + IntegerToString(minConfluenceScore));
         Logger::Info("Strict Mode: " + (useStrictMode ? "ON" : "OFF"));
         Logger::Info("Active Filters:");
         Logger::Info("  Volume: " + (enableVolumeFilter ? "ON" : "OFF"));
         Logger::Info("  EMA200: " + (enableEMA200Filter ? "ON" : "OFF"));
         Logger::Info("  MACD: " + (enableMACDFilter ? "ON" : "OFF"));
         Logger::Info("  Stochastic: " + (enableStochasticFilter ? "ON" : "OFF"));
         Logger::Info("  Psychological: " + (enablePsychologicalLevels ? "ON" : "OFF"));
         Logger::Info("  Multi-timeframe: " + (enableMultiTimeframe ? "ON" : "OFF"));
      }
      Logger::Info("================================");
   }
};
