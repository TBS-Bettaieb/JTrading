//+------------------------------------------------------------------+
//|                                            TripleRSIConfig.mqh   |
//|                                    Configuration Triple RSI      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"
#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/TrailingTP_System.mqh"

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
   bool              useStrictAlignment; // Mode Strict (3/3) ou Flexible (2/3)
   bool              useEMAValidation;      // Validation avec EMA sur timeframe supérieur
   int               emaPeriodValidation;   // Période EMA pour validation (20-200)
   bool              useEMACrossFilter;     // Filtrer si trop de croisements EMA
   int               emaCrossBarsCheck;     // Nombre de barres à analyser (10-50)
   int               emaMaxCrossings;       // Nombre max de croisements tolérés (1-5)
   
   // Divergence Confirmation System
   bool              useDivergenceConfirm;  // Activer confirmation par divergence
   int               divConfirmBars;        // Barres max d'attente (7-10)
   int               divLookbackBars;       // Barres recherche pivots (5-15)
   double            divMinStrength;        // Force min % (optionnel)
   int               divergenceRsiIndex;    // RSI pour divergence (1=rapide, 2=moyen, 3=lent)
   
   // ATR Volatility Filter
   bool              useATRVolatilityFilter;   // Activer filtre ATR volatilité
   int               atrShortPeriod;           // ATR court terme (14 par défaut)
   int               atrLongPeriod;            // ATR long terme (50 par défaut)
   double            atrExpansionMultiplier;   // Multiplicateur expansion (1.2-1.5)
   
   // Stop Loss / Take Profit
   int               slPoints;          // SL en points
   double            tpRatio;          // Ratio TP/SL (ex: 2.0 = 1:2)
   bool              useDynamicTrailing; // Activer TSL dynamique
   int               tslTriggerPoints; // Déclenchement trailing
   int               tslPoints;        // Distance trailing
   double            tslCostMultiplier; // Multiplicateur coûts TSL
   int               tslMinTriggerPoints; // Trigger minimum TSL
   
   // Trailing Take Profit System
   bool                    useTrailingTP;         // Activer Trailing TP
   ENUM_TRAILING_TP_MODE   trailingTPMode;        // Mode (LINEAR/STEPPED/EXPONENTIAL/CUSTOM)
   string                  trailingTPCustomLevels; // Niveaux custom
   
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
      useStrictAlignment = true;
      useEMAValidation = false;       // Désactivé par défaut
      emaPeriodValidation = 50;       // EMA-50 par défaut
      useEMACrossFilter = false;      // Filtre croisements désactivé par défaut
      emaCrossBarsCheck = 20;         // Analyser 20 dernières barres
      emaMaxCrossings = 2;            // Max 2 croisements tolérés
      
      // Divergence System - Valeurs par défaut
      useDivergenceConfirm = false;   // Désactivé par défaut
      divConfirmBars = 8;             // 8 barres max d'attente
      divLookbackBars = 10;           // 10 barres pour pivots
      divMinStrength = 3.0;           // 3% minimum
      divergenceRsiIndex = 3;         // RSI lent par défaut (plus stable)
      
      // ATR Volatility Filter - Valeurs par défaut
      useATRVolatilityFilter = false; // Désactivé par défaut
      atrShortPeriod = 14;            // ATR court terme : 14 périodes
      atrLongPeriod = 50;             // ATR long terme : 50 périodes
      atrExpansionMultiplier = 1.3;   // Multiplicateur : 1.3x (équilibré)
      
      slPoints = 100;
      tpRatio = 2.0;
      useDynamicTrailing = true;
      tslTriggerPoints = 50;
      tslPoints = 30;
      tslCostMultiplier = 1.5;
      tslMinTriggerPoints = 50;
      
      // Trailing Take Profit System - Valeurs par défaut
      useTrailingTP = false;
      trailingTPMode = TRAILING_TP_STEPPED;
      trailingTPCustomLevels = "50:0:0,100:50:50";  // 50% → BE, 100% → SL+50%, TP+50%
      
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
      
      if(divergenceRsiIndex < 1 || divergenceRsiIndex > 3)
      {
         Logger::Error("Divergence RSI index must be 1, 2, or 3 (current: " + 
                      IntegerToString(divergenceRsiIndex) + ")");
         return false;
      }
      
      // Validation ATR Volatility Filter
      if(useATRVolatilityFilter)
      {
         if(atrShortPeriod <= 0 || atrLongPeriod <= 0)
         {
            Logger::Error("ATR periods must be positive");
            return false;
         }
         
         if(atrShortPeriod >= atrLongPeriod)
         {
            Logger::Error("ATR short period must be < ATR long period (current: " + 
                         IntegerToString(atrShortPeriod) + " vs " + IntegerToString(atrLongPeriod) + ")");
            return false;
         }
         
         if(atrExpansionMultiplier < 1.0 || atrExpansionMultiplier > 3.0)
         {
            Logger::Error("ATR expansion multiplier must be between 1.0 and 3.0 (current: " + 
                         DoubleToString(atrExpansionMultiplier, 2) + ")");
            return false;
         }
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
      
      // Validation Trailing TP
      if(useTrailingTP && trailingTPMode == TRAILING_TP_CUSTOM)
      {
         string errorMsg;
         if(!CTrailingTPValidator::ValidateCustomLevelsString(trailingTPCustomLevels, errorMsg))
         {
            Logger::Error("Trailing TP Custom Levels validation failed: " + errorMsg);
            return false;
         }
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
      
      // Affichage Trailing TP
      if(useTrailingTP)
      {
         Logger::Info("Trailing TP: ENABLED (" + EnumToString(trailingTPMode) + ")");
         if(trailingTPMode == TRAILING_TP_CUSTOM)
         {
            Logger::Info("Custom Levels: " + trailingTPCustomLevels);
         }
      }
      else
      {
         Logger::Info("Trailing TP: DISABLED");
      }
      
      Logger::Info("================================");
   }
};
