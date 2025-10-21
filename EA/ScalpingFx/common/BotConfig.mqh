//+------------------------------------------------------------------+
//|                                                BotConfig.mqh      |
//|                                    Bot Configuration Structure     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/TrailingTP_System.mqh"
#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Configuration structure                                          |
//+------------------------------------------------------------------+
struct BotConfig
{
   string            strategyName;
   string            strategyComment;
   int               baseMagic;
   string            symbolsList;
   bool              useAllSymbols;
   ENUM_TIMEFRAMES   timeframe;
   double            riskPercent;
   int               tpPoints;
   int               slPoints;
   int               tslTriggerPoints;
   int               tslPoints;
   int               startHour;
   int               endHour;
   ENUM_STRATEGY_MODE strategyMode;
   int               barsN;
   int               expirationBars;
   int               orderDistPoints;
   int               slippagePoints;        // NEW: Slippage tolerance in points
   int               entryOffsetPoints;     // NEW: Entry price offset for Stop orders
   bool              useTrailingTP;
   ENUM_TRAILING_TP_MODE trailingTPMode;
   string            customTPLevels;
   string            hourBlockMsg;
   string            dayBlockMsg;
   string            bothBlockMsg;
   
   // RISK MULTIPLIER
   bool              useRiskMultiplier;
   int               riskMultStartHour;
   int               riskMultStartMinute;
   int               riskMultEndHour;
   int               riskMultEndMinute;
   double            riskMultiplier;
   string            riskMultDescription;
   
   // NEWS FILTER
   bool              useNewsFilter;
   string            newsCurrencies;
   string            keyNewsEvents;
   int               stopBeforeNewsMin;
   int               startAfterNewsMin;
   int               newsLookupDays;
   ENUM_SEPARATOR    newsSeparator;
   string            newsBlockMsg;
   
   // LOGGING
   ENUM_LOG_LEVEL    logLevel;
};
