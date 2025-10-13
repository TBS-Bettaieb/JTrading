//+------------------------------------------------------------------+
//|                                       JT_StrategyFactory.mqh     |
//|                      Factory pour créer des stratégies           |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"

#include "JT_Enums.mqh"
#include "../strategies/JT_FreeCandleStrategy.mqh"
#include "../strategies/JT_BreakoutStrategy.mqh"
#include "../strategies/JT_MeanReversionStrategy.mqh"

//+------------------------------------------------------------------+
//| Types de stratégies disponibles                                  |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_TYPE
{
   STRATEGY_FREE_CANDLE,      // Stratégie Free Candle (bougies hors BB)
   STRATEGY_BREAKOUT,         // Stratégie Breakout
   STRATEGY_MEAN_REVERSION,   // Stratégie Mean Reversion
   STRATEGY_CUSTOM            // Stratégie personnalisée
};

//+------------------------------------------------------------------+
//| Factory pour créer des instances de stratégies                   |
//+------------------------------------------------------------------+
class JTStrategyFactory
{
public:
   //+------------------------------------------------------------------+
   //| Créer une stratégie selon le type spécifié                       |
   //+------------------------------------------------------------------+
   static JTBaseStrategy* CreateStrategy(
      ENUM_STRATEGY_TYPE type,
      string symbol,
      ENUM_TIMEFRAMES tf,
      ulong magic
   )
   {
      JTBaseStrategy* created = NULL;
      
      switch(type)
      {
         case STRATEGY_FREE_CANDLE:
            created = new JTFreeCandleStrategy(symbol, tf, magic);
            LogMessage("Factory: Stratégie FreeCandle créée pour " + symbol);
            break;
            
         case STRATEGY_BREAKOUT:
            created = new JTBreakoutStrategy(symbol, tf, magic);
            LogMessage("Factory: Stratégie Breakout créée pour " + symbol);
            break;
            
         case STRATEGY_MEAN_REVERSION:
            created = new JTMeanReversionStrategy(symbol, tf, magic);
            LogMessage("Factory: Stratégie MeanReversion créée pour " + symbol);
            break;
            
         case STRATEGY_CUSTOM:
            // À implémenter : Stratégie personnalisée
            LogError("Stratégie CUSTOM non encore implémentée");
            break;
            
         default:
            LogError("Type de stratégie inconnu: " + IntegerToString(type));
            break;
      }
      
      return created;
   }
   
   //+------------------------------------------------------------------+
   //| Créer une stratégie FreeCandle avec configuration complète       |
   //+------------------------------------------------------------------+
   static JTFreeCandleStrategy* CreateFreeCandleStrategy(
      string symbol,
      ENUM_TIMEFRAMES tf,
      ulong magic,
      // Paramètres BB
      int bbPeriod,
      double bbDeviation,
      int outsidePadding,
      bool bodyMustBeOutside,
      // Paramètres RSI
      bool useRSI,
      int rsiPeriod,
      double rsiOversold,
      double rsiOverbought,
      // Paramètres EMA
      bool useEMA,
      int emaFast,
      int emaSlow,
      ENUM_EMA_FILTER_MODE emaMode,
      double emaZoneDistance,
      // Mode d'entrée
      ENUM_ENTRY_MODE entryMode,
      // Divergence
      bool useDivergence,
      double divRsiBuy,
      double divRsiSell,
      int divSwingLength,
      // Risk Management
      ENUM_RISK_BASE riskBase,
      double riskPercent,
      double minRR,
      bool onePositionPerConfig,
      // SL/TP
      int slPeriod,
      int tpPeriod,
      double atrMultiplier,
      int atrPeriod,
      // Filtres temporels
      bool useTimeFilter,
      string hourRanges,
      bool useDayFilter,
      string dayRanges,
      // Daily Drawdown
      bool useDailyDD,
      ENUM_DD_MODE ddMode,
      double ddPercent,
      double ddFixedAmount,
      bool ddCloseAll,
      bool ddUseEquity,
      // Gestion de position
      bool beOnOppositeBand,
      int beOffsetPoints,
      bool useFlatTime,
      int flatHour,
      int flatMinute,
      int touchPadPoints,
      // Direction
      ENUM_TRADE_DIRECTION tradeDirection,
      // Marqueurs
      bool markFreeCandles,
      bool markVLine,
      bool markArrow,
      bool markBox,
      bool markText
   )
   {
      // Créer l'instance
      JTFreeCandleStrategy* instance = new JTFreeCandleStrategy(symbol, tf, magic);
      
      if(instance == NULL) {
         LogError("Échec de création de la stratégie FreeCandle");
         return NULL;
      }
      
      // Configurer les paramètres BB
      instance.SetBBParameters(bbPeriod, bbDeviation, outsidePadding, bodyMustBeOutside);
      
      // Configurer RSI
      instance.SetRSIParameters(rsiPeriod, rsiOversold, rsiOverbought);
      instance.EnableRSIFilter(useRSI);
      
      // Configurer EMA
      instance.SetEMAParameters(emaFast, emaSlow, emaMode, emaZoneDistance);
      instance.EnableEMAFilter(useEMA);
      
      // Configurer Divergence
      instance.SetDivergenceParameters(divRsiBuy, divRsiSell, divSwingLength);
      instance.EnableDivergence(useDivergence);
      
      // Mode d'entrée
      instance.SetEntryMode(entryMode);
      
      // Risk Management
      instance.SetRiskBase(riskBase);
      instance.SetRiskPercent(riskPercent);
      instance.SetMinRR(minRR);
      instance.SetOnePositionPerConfig(onePositionPerConfig);
      
      // SL/TP
      instance.SetSLTPParameters(slPeriod, tpPeriod, atrMultiplier, atrPeriod);
      
      // Filtres temporels
      instance.SetTimeFilter(useTimeFilter, hourRanges);
      instance.SetDayFilter(useDayFilter, dayRanges);
      
      // Daily Drawdown
      instance.SetDailyDD(useDailyDD, ddMode, ddPercent, ddFixedAmount, ddCloseAll, ddUseEquity);
      
      // Gestion de position
      instance.SetPositionManagement(beOnOppositeBand, beOffsetPoints, 
                                     useFlatTime, flatHour, flatMinute, touchPadPoints);
      
      // Direction
      instance.SetTradeDirection(tradeDirection);
      
      // Marqueurs visuels
      instance.SetVisualMarkers(markFreeCandles, markVLine, markArrow, markBox, markText);
      
      LogMessage("Stratégie FreeCandle configurée avec succès");
      
      return instance;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nom d'une stratégie                                   |
   //+------------------------------------------------------------------+
   static string GetStrategyName(ENUM_STRATEGY_TYPE type)
   {
      switch(type)
      {
         case STRATEGY_FREE_CANDLE:    return "FreeCandle";
         case STRATEGY_BREAKOUT:       return "Breakout";
         case STRATEGY_MEAN_REVERSION: return "MeanReversion";
         case STRATEGY_CUSTOM:         return "Custom";
         default:                      return "Unknown";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la description d'une stratégie                           |
   //+------------------------------------------------------------------+
   static string GetStrategyDescription(ENUM_STRATEGY_TYPE type)
   {
      switch(type)
      {
         case STRATEGY_FREE_CANDLE:
            return "Détecte les bougies hors bandes de Bollinger (Free Candles) et trade en reversion ou breakout";
            
         case STRATEGY_BREAKOUT:
            return "Stratégie de breakout sur niveaux clés (à implémenter)";
            
         case STRATEGY_MEAN_REVERSION:
            return "Stratégie de retour à la moyenne (à implémenter)";
            
         case STRATEGY_CUSTOM:
            return "Stratégie personnalisée (à implémenter)";
            
         default:
            return "Stratégie inconnue";
      }
   }
};

