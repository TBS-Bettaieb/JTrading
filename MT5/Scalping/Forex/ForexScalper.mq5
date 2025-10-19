//+------------------------------------------------------------------+
//|                                              ForexScalper.mq5    |
//|                                    Scalping Bot - Modular Design |
//|                                                     Version 3.00 |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "3.00"
#property strict

//═══════════════════════════════════════════════════════════════════
//   ████████╗ CONFIG BLOCK - MODIFY THIS FOR EACH CLONE ████████╗
//═══════════════════════════════════════════════════════════════════

// 🎯 STRATEGY IDENTITY
#define STRATEGY_NAME          "Forex Scalper V1.1"
#define STRATEGY_COMMENT       "Scalping Robot"
#define BASE_MAGIC_NUMBER      298347

// 📊 SYMBOLS CONFIGURATION
#define DEFAULT_SYMBOLS        "EURUSD,GBPUSD,USDJPY,USDCAD"
#define USE_ALL_MARKET_WATCH   false
#define TRADING_TIMEFRAME      PERIOD_M5

// 💰 RISK MANAGEMENT
#define RISK_PERCENT           4.0      // % of capital (divided by symbol count)
#define TAKE_PROFIT_POINTS     200      // 10 points = 1 pip
#define STOP_LOSS_POINTS       200      // 10 points = 1 pip

// 🎯 TRAILING STOP CONFIGURATION
#define TSL_TRIGGER_POINTS     10       // Profit before TSL activates
#define TSL_POINTS             10       // Trailing stop distance

// ⏰ TRADING HOURS (0 = Inactive)
#define START_HOUR             7
#define END_HOUR               19

// 📈 STRATEGY PARAMETERS
#define STRATEGY_TYPE          STRATEGY_BREAKOUT  // STRATEGY_BREAKOUT or STRATEGY_REVERSION
#define BARS_ANALYSIS          5
#define EXPIRATION_BARS        50
#define ORDER_DISTANCE_POINTS  100

// 🎯 TRAILING TAKE PROFIT
#define USE_TRAILING_TP        true
#define TRAILING_TP_MODE       TRAILING_TP_STEPPED  // TRAILING_TP_STEPPED or TRAILING_TP_CUSTOM
#define CUSTOM_TP_LEVELS       "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150"

// 🚀 RISK MULTIPLIER (BOOST PERIOD)
#define USE_RISK_MULTIPLIER    true
#define RISK_MULT_START_HOUR   13
#define RISK_MULT_START_MINUTE 0
#define RISK_MULT_END_HOUR     17
#define RISK_MULT_END_MINUTE   0
#define RISK_MULTIPLIER        2.0
#define RISK_MULT_DESCRIPTION  "London-NY Overlap Boost"

// 🚨 ALERT MESSAGES
#define HOUR_BLOCK_MSG         "⏰ TRADING PAUSED - Outside Trading Hours"
#define DAY_BLOCK_MSG          "📅 TRADING PAUSED - Outside Trading Days"
#define BOTH_BLOCK_MSG         "🚫 TRADING PAUSED - Outside Trading Schedule"

//═══════════════════════════════════════════════════════════════════
//   ████████╗ END OF CONFIG BLOCK ████████╗
//═══════════════════════════════════════════════════════════════════

// Include the bot engine (all logic is here)
#include "core/ForexScalperBot.mqh"

// Global bot instance
ForexScalperBot* bot = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create bot configuration from defines
   BotConfig config;
   config.strategyName = STRATEGY_NAME;
   config.strategyComment = STRATEGY_COMMENT;
   config.baseMagic = BASE_MAGIC_NUMBER;
   config.symbolsList = DEFAULT_SYMBOLS;
   config.useAllSymbols = USE_ALL_MARKET_WATCH;
   config.timeframe = TRADING_TIMEFRAME;
   config.riskPercent = RISK_PERCENT;
   config.tpPoints = TAKE_PROFIT_POINTS;
   config.slPoints = STOP_LOSS_POINTS;
   config.tslTriggerPoints = TSL_TRIGGER_POINTS;
   config.tslPoints = TSL_POINTS;
   config.startHour = START_HOUR;
   config.endHour = END_HOUR;
   config.strategyMode = STRATEGY_TYPE;
   config.barsN = BARS_ANALYSIS;
   config.expirationBars = EXPIRATION_BARS;
   config.orderDistPoints = ORDER_DISTANCE_POINTS;
   config.useTrailingTP = USE_TRAILING_TP;
   config.trailingTPMode = TRAILING_TP_MODE;
   config.customTPLevels = CUSTOM_TP_LEVELS;
   config.hourBlockMsg = HOUR_BLOCK_MSG;
   config.dayBlockMsg = DAY_BLOCK_MSG;
   config.bothBlockMsg = BOTH_BLOCK_MSG;
   
   // Risk Multiplier Configuration
   config.useRiskMultiplier = USE_RISK_MULTIPLIER;
   config.riskMultStartHour = RISK_MULT_START_HOUR;
   config.riskMultStartMinute = RISK_MULT_START_MINUTE;
   config.riskMultEndHour = RISK_MULT_END_HOUR;
   config.riskMultEndMinute = RISK_MULT_END_MINUTE;
   config.riskMultiplier = RISK_MULTIPLIER;
   config.riskMultDescription = RISK_MULT_DESCRIPTION;
   
   // Initialize bot
   bot = new ForexScalperBot(config);
   
   if(bot == NULL)
   {
      Print("❌ ERROR: Failed to create bot instance");
      return(INIT_FAILED);
   }
   
   // Initialize and validate
   if(!bot.Initialize())
   {
      Print("❌ ERROR: Bot initialization failed");
      delete bot;
      bot = NULL;
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(bot != NULL)
   {
      bot.Deinitialize(reason);
      delete bot;
      bot = NULL;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(bot != NULL)
   {
      bot.OnTick();
   }
}
//+------------------------------------------------------------------+