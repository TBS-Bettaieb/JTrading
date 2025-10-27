//+------------------------------------------------------------------+
//|                                            TripleRSIConfig.mqh   |
//|                                    Configuration Triple RSI      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"
#include "../../Shared/TradingEnums.mqh"

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
   
   //=== STOP-LOSS CONFIGURATION ===
   ENUM_SL_MODE      slMode;                // Mode SL (FIXED_POINTS ou PERCENT_PRICE)
   int               fixedSLPoints;         // SL fixe en points
   double            percentSLPrice;        // SL en % du prix
   
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
      useDynamicTrailing = true;
      tslTriggerPoints = 50;
      tslPoints = 30;
      tslCostMultiplier = 1.5;
      tslMinTriggerPoints = 50;
      
      barsLookback = 5;
      
      useAlerts = true;
      sendNotifications = false;
      
      logLevel = LOG_INFO;
      
      // Configuration Stop-Loss par défaut
      slMode = SL_FIXED_POINTS;
      fixedSLPoints = 50;
      percentSLPrice = 0.5;
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
      Logger::Info("Dynamic TSL: " + (useDynamicTrailing ? "ON" : "OFF"));
      if(useDynamicTrailing)
      {
         Logger::Info("TSL Cost Multiplier: " + DoubleToString(tslCostMultiplier, 1));
         Logger::Info("TSL Min Trigger: " + IntegerToString(tslMinTriggerPoints) + " pts");
      }
      
      Logger::Info("================================");
   }
};
