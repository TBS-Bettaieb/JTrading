//+------------------------------------------------------------------+
//|                                         ForexScalper_Tester.mq5  |
//|                                    Forex Scalper - Test Version   |
//|                                                     Version 3.00  |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "3.00"
#property strict

// Include required enums and types BEFORE input declarations
#include <Trade\Trade.mqh>
#include "../../CommonUtils/TradingEnums.mqh"
#include "../../CommonUtils/TrailingTP_System.mqh"
#include "../../CommonUtils/TradingUtils.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS FOR TESTING                                     |
//+------------------------------------------------------------------+

input group "🎯 STRATEGY IDENTITY"
input string   InpStrategyName = "Forex Scalper V1.1";        // Strategy Name
input string   InpStrategyComment = "Scalping Robot";         // Strategy Comment
input int      InpBaseMagicNumber = 298347;                  // Base Magic Number

input group "📊 SYMBOLS CONFIGURATION"  
input string   InpDefaultSymbols = "EURUSD,GBPUSD";  // Symbols List (comma separated)
input bool     InpUseAllMarketWatch = false;                 // Use All Market Watch Symbols
input ENUM_TIMEFRAMES InpTradingTimeframe = PERIOD_M5;       // Trading Timeframe

input group "💰 RISK MANAGEMENT"
input double   InpRiskPercent = 4.0;                        // Risk Percent (% of capital divided by symbol count)
input int      InpTpPoints = 200;                           // Take Profit Points (10 points = 1 pip)
input int      InpSlPoints = 180;                           // Stop Loss Points (10 points = 1 pip)

input group "🎯 TRAILING STOP CONFIGURATION"
input int      InpTslTriggerPoints = 10;                    // TSL Trigger Points (profit before TSL activates)
input int      InpTslPoints = 10;                           // TSL Points (trailing stop distance)

input group "⏰ TRADING HOURS (0 = Inactive)"
input int      InpStartHour = 7;                            // Start Hour
input int      InpEndHour = 20;                             // End Hour

input group "📈 STRATEGY PARAMETERS"
input ENUM_STRATEGY_MODE InpStrategyType = STRATEGY_BREAKOUT; // Strategy Type: BREAKOUT or REVERSION
input int      InpBarsAnalysis = 5;                         // Bars Analysis
input int      InpExpirationBars = 50;                      // Expiration Bars
input int      InpOrderDistancePoints = 80;                // Order Distance (Points)

input group "🎯 TRAILING TAKE PROFIT"
input bool     InpUseTrailingTP = true;                     // Use Trailing TP
input ENUM_TRAILING_TP_MODE InpTrailingTPMode = TRAILING_TP_STEPPED; // Trailing TP Mode
input string   InpCustomTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150"; // Custom TP Levels

input group "🚀 RISK MULTIPLIER (BOOST PERIOD)"
input bool     InpUseRiskMultiplier = false;                 // Use Risk Multiplier
input int      InpRiskMultStartHour = 13;                   // Risk Multiplier Start Hour
input int      InpRiskMultStartMinute = 0;                  // Risk Multiplier Start Minute
input int      InpRiskMultEndHour = 17;                     // Risk Multiplier End Hour
input int      InpRiskMultEndMinute = 0;                    // Risk Multiplier End Minute
input double   InpRiskMultiplier = 1.5;                     // Risk Multiplier Value
input string   InpRiskMultDescription = "London-NY Overlap"; // Risk Multiplier Description

input group "📰 NEWS FILTER"
input bool     InpUseNewsFilter = false;                        // Use News Filter
input string   InpNewsCurrencies = "USD,EUR,GBP";               // Affected Currencies (comma separated)
input string   InpKeyNewsEvents = "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP"; // High Impact Events
input int      InpStopBeforeNewsMin = 30;                       // Minutes Before News to Stop Trading
input int      InpStartAfterNewsMin = 10;                       // Minutes After News to Resume Trading
input int      InpNewsLookupDays = 7;                           // Days Ahead to Check News
input ENUM_SEPARATOR InpNewsSeparator = COMMA;                  // List Separator (COMMA or SEMICOLON)
input string   InpNewsBlockMsg = "📰 TRADING PAUSED - High Impact News Event"; // News Block Message

input group "🚨 ALERT MESSAGES"
input string   InpHourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";     // Hour Block Message
input string   InpDayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";      // Day Block Message
input string   InpBothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule"; // Both Block Message

//+------------------------------------------------------------------+

// Include the bot engine (all logic is here)
#include "core/ForexScalperBot.mqh"

// Global bot instance
ForexScalperBot* bot = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create bot configuration from input parameters
   BotConfig config;
   config.strategyName = InpStrategyName;
   config.strategyComment = InpStrategyComment;
   config.baseMagic = InpBaseMagicNumber;
   config.symbolsList = InpDefaultSymbols;
   config.useAllSymbols = InpUseAllMarketWatch;
   config.timeframe = InpTradingTimeframe;
   config.riskPercent = InpRiskPercent;
   config.tpPoints = InpTpPoints;
   config.slPoints = InpSlPoints;
   config.tslTriggerPoints = InpTslTriggerPoints;
   config.tslPoints = InpTslPoints;
   config.startHour = InpStartHour;
   config.endHour = InpEndHour;
   config.strategyMode = InpStrategyType;
   config.barsN = InpBarsAnalysis;
   config.expirationBars = InpExpirationBars;
   config.orderDistPoints = InpOrderDistancePoints;
   config.useTrailingTP = InpUseTrailingTP;
   config.trailingTPMode = InpTrailingTPMode;
   config.customTPLevels = InpCustomTPLevels;
   config.hourBlockMsg = InpHourBlockMsg;
   config.dayBlockMsg = InpDayBlockMsg;
   config.bothBlockMsg = InpBothBlockMsg;
   
   // Risk Multiplier Configuration
   config.useRiskMultiplier = InpUseRiskMultiplier;
   config.riskMultStartHour = InpRiskMultStartHour;
   config.riskMultStartMinute = InpRiskMultStartMinute;
   config.riskMultEndHour = InpRiskMultEndHour;
   config.riskMultEndMinute = InpRiskMultEndMinute;
   config.riskMultiplier = InpRiskMultiplier;
   config.riskMultDescription = InpRiskMultDescription;
   
   // News Filter Configuration
   config.useNewsFilter = InpUseNewsFilter;
   config.newsCurrencies = InpNewsCurrencies;
   config.keyNewsEvents = InpKeyNewsEvents;
   config.stopBeforeNewsMin = InpStopBeforeNewsMin;
   config.startAfterNewsMin = InpStartAfterNewsMin;
   config.newsLookupDays = InpNewsLookupDays;
   config.newsSeparator = InpNewsSeparator;
   config.newsBlockMsg = InpNewsBlockMsg;
   
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
   
   // Display input parameters on chart
   DisplayInputParameters();
   
   // Save current configuration as header template
   SaveConfigurationTemplate();
   
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
//| Display input parameters on chart                                |
//+------------------------------------------------------------------+
void DisplayInputParameters()
{
   string strategyTypeStr = (InpStrategyType == STRATEGY_BREAKOUT) ? "BREAKOUT" : "REVERSION";
   string trailingTPStr = "Disabled";
   
   if(InpUseTrailingTP)
   {
      int modeValue = (int)InpTrailingTPMode;
      switch(modeValue)
      {
         case TRAILING_TP_LINEAR: trailingTPStr = "LINEAR"; break;
         case TRAILING_TP_STEPPED: trailingTPStr = "STEPPED"; break;
         case TRAILING_TP_EXPONENTIAL: trailingTPStr = "EXPONENTIAL"; break;
         case TRAILING_TP_CUSTOM: trailingTPStr = "CUSTOM"; break;
         default: trailingTPStr = "UNKNOWN"; break;
      }
   }
   
   string riskMultStr = "OFF";
   if(InpUseRiskMultiplier) {
      riskMultStr = StringFormat("x%.1f (%02d:%02d-%02d:%02d)", 
                                InpRiskMultiplier,
                                InpRiskMultStartHour, InpRiskMultStartMinute,
                                InpRiskMultEndHour, InpRiskMultEndMinute);
   }
   
   string newsFilterStr = "OFF";
   if(InpUseNewsFilter) {
      newsFilterStr = StringFormat("ON (%dmin/%dmin) - %s", 
                                  InpStopBeforeNewsMin, InpStartAfterNewsMin, InpNewsCurrencies);
   }
   
   string inputs = StringFormat(
      "=== %s TESTER ===\n" +
      "Magic: %d\n" +
      "Symbols: %s\n" +
      "Timeframe: %s\n" +
      "Risk: %.1f%%\n" +
      "TP/SL: %d/%d points\n" +
      "Strategy: %s\n" +
      "Bars Analysis: %d\n" +
      "Trading Hours: %02d:00-%02d:00\n" +
      "Trailing TP: %s\n" +
      "Risk Multiplier: %s\n" +
      "News Filter: %s",
      InpStrategyName,
      InpBaseMagicNumber,
      InpUseAllMarketWatch ? "All Market Watch" : InpDefaultSymbols,
      EnumToString(InpTradingTimeframe),
      InpRiskPercent,
      InpTpPoints, InpSlPoints,
      strategyTypeStr,
      InpBarsAnalysis,
      InpStartHour, InpEndHour,
      trailingTPStr,
      riskMultStr,
      newsFilterStr
   );
   
   Comment(inputs);
   Print("=== TESTER INPUT PARAMETERS ===");
   Print(inputs);
   Print("================================");
}

//+------------------------------------------------------------------+
//| Save configuration as header template                             |
//+------------------------------------------------------------------+
void SaveConfigurationTemplate()
{
   // Generate timestamp and filename
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   string timestamp = StringFormat("%04d%02d%02d_%02d%02d", 
                                  dt.year, 
                                  dt.mon, 
                                  dt.day,
                                  dt.hour, 
                                  dt.min);
   
   // Use COMMON_FILES directory with ForexScalperConfigs folder
   string filename = "ForexScalperConfigs\\ForexScalperConfig_" + timestamp + ".mqh";
   
   // Create header file content
   string headerContent = CreateHeaderTemplate();
   
   // Check if file already exists (like JT_TradeTracker)
   int fileHandle = FileOpen(filename, FILE_READ|FILE_COMMON|FILE_TXT);
   bool fileExists = (fileHandle != INVALID_HANDLE);
   
   if(fileExists) {
      FileClose(fileHandle);
      Print("⚠️ Configuration file already exists in Common Files: ", filename, " - Overwriting...");
   }
   
   // Write to COMMON_FILES directory with UTF-8 encoding for proper icon display
   fileHandle = FileOpen(filename, FILE_WRITE|FILE_COMMON|FILE_TXT);
   if(fileHandle == INVALID_HANDLE)
   {
      Print("❌ ERROR: Impossible de créer le fichier de config dans Common Files: ", filename);
      return;
   }
   
   FileWriteString(fileHandle, headerContent);
   FileClose(fileHandle);
   
   Print("✅ Configuration saved to Common Files: ", filename);
   Print("📁 Location: MetaTrader 5 Common Files directory");
}

//+------------------------------------------------------------------+
//| Create header template content                                    |
//+------------------------------------------------------------------+
string CreateHeaderTemplate()
{
   string strategyTypeStr = "";
   switch(InpStrategyType)
   {
      case STRATEGY_BREAKOUT: strategyTypeStr = "STRATEGY_BREAKOUT"; break;
      case STRATEGY_REVERSION: strategyTypeStr = "STRATEGY_REVERSION"; break;
      default: strategyTypeStr = "STRATEGY_BREAKOUT"; break;
   }
   
   string trailingTPModeStr = "";
   switch((int)InpTrailingTPMode)
   {
      case TRAILING_TP_LINEAR: trailingTPModeStr = "TRAILING_TP_LINEAR"; break;
      case TRAILING_TP_STEPPED: trailingTPModeStr = "TRAILING_TP_STEPPED"; break;
      case TRAILING_TP_EXPONENTIAL: trailingTPModeStr = "TRAILING_TP_EXPONENTIAL"; break;
      case TRAILING_TP_CUSTOM: trailingTPModeStr = "TRAILING_TP_CUSTOM"; break;
      default: trailingTPModeStr = "TRAILING_TP_STEPPED"; break;
   }
   
   string timeframeStr = "";
   switch(InpTradingTimeframe)
   {
      case PERIOD_M1: timeframeStr = "PERIOD_M1"; break;
      case PERIOD_M5: timeframeStr = "PERIOD_M5"; break;
      case PERIOD_M15: timeframeStr = "PERIOD_M15"; break;
      case PERIOD_M30: timeframeStr = "PERIOD_M30"; break;
      case PERIOD_H1: timeframeStr = "PERIOD_H1"; break;
      case PERIOD_H4: timeframeStr = "PERIOD_H4"; break;
      case PERIOD_D1: timeframeStr = "PERIOD_D1"; break;
      default: timeframeStr = "PERIOD_M5"; break;
   }
   
   string newsSeparatorStr = "";
   switch((int)InpNewsSeparator)
   {
      case COMMA: newsSeparatorStr = "COMMA"; break;
      case SEMICOLON: newsSeparatorStr = "SEMICOLON"; break;
      default: newsSeparatorStr = "COMMA"; break;
   }
   
   
   string content = "//+------------------------------------------------------------------+\n";
   content += "//|                                    ForexScalperConfig.mqh\n";
   content += "//|                                    Configuration Template\n";
   content += "//|                                                     Version 3.00\n";
   content += "//+------------------------------------------------------------------+\n";
   content += "\n";
   content += "//═══════════════════════════════════════════════════════════════════\n";
   content += "//   CONFIG BLOCK - PERSONNALISEZ ICI\n";
   content += "//═══════════════════════════════════════════════════════════════════\n";
   content += "\n";
   content += "// IDENTITE DE LA STRATEGIE\n";
   content += "#define STRATEGY_NAME          \"" + InpStrategyName + "\"\n";
   content += "#define STRATEGY_COMMENT       \"" + InpStrategyComment + "\"\n";
   content += "#define BASE_MAGIC_NUMBER      " + IntegerToString(InpBaseMagicNumber) + "\n";
   content += "\n";
   content += "// CONFIGURATION DES SYMBOLES\n";
   content += "#define DEFAULT_SYMBOLS        \"" + InpDefaultSymbols + "\"\n";
   content += "#define USE_ALL_MARKET_WATCH   " + (InpUseAllMarketWatch ? "true" : "false") + "\n";
   content += "#define TRADING_TIMEFRAME      " + timeframeStr + "\n";
   content += "\n";
   content += "// GESTION DU RISQUE\n";
   content += "#define RISK_PERCENT           " + DoubleToString(InpRiskPercent, 1) + "\n";
   content += "\n";
   content += "// TAKE PROFIT / STOP LOSS (en points, 10 points = 1 pip)\n";
   content += "#define TAKE_PROFIT_POINTS     " + IntegerToString(InpTpPoints) + "\n";
   content += "#define STOP_LOSS_POINTS       " + IntegerToString(InpSlPoints) + "\n";
   content += "\n";
   content += "// TRAILING STOP LOSS\n";
   content += "#define TSL_TRIGGER_POINTS     " + IntegerToString(InpTslTriggerPoints) + "\n";
   content += "#define TSL_POINTS             " + IntegerToString(InpTslPoints) + "\n";
   content += "\n";
   content += "// HEURES DE TRADING (0 = inactif, 1-23 = actif)\n";
   content += "#define START_HOUR             " + IntegerToString(InpStartHour) + "\n";
   content += "#define END_HOUR               " + IntegerToString(InpEndHour) + "\n";
   content += "\n";
   content += "// PARAMETRES DE STRATEGIE\n";
   content += "#define STRATEGY_TYPE          " + strategyTypeStr + "\n";
   content += "#define BARS_ANALYSIS          " + IntegerToString(InpBarsAnalysis) + "\n";
   content += "#define EXPIRATION_BARS        " + IntegerToString(InpExpirationBars) + "\n";
   content += "#define ORDER_DISTANCE_POINTS  " + IntegerToString(InpOrderDistancePoints) + "\n";
   content += "\n";
   content += "// TRAILING TAKE PROFIT\n";
   content += "#define USE_TRAILING_TP        " + (InpUseTrailingTP ? "true" : "false") + "\n";
   content += "#define TRAILING_TP_MODE       " + trailingTPModeStr + "\n";
   content += "#define CUSTOM_TP_LEVELS       \"" + InpCustomTPLevels + "\"\n";
   content += "\n";
   content += "// RISK MULTIPLIER (BOOST PERIOD)\n";
   content += "#define USE_RISK_MULTIPLIER    " + (InpUseRiskMultiplier ? "true" : "false") + "\n";
   content += "#define RISK_MULT_START_HOUR   " + IntegerToString(InpRiskMultStartHour) + "\n";
   content += "#define RISK_MULT_START_MINUTE " + IntegerToString(InpRiskMultStartMinute) + "\n";
   content += "#define RISK_MULT_END_HOUR     " + IntegerToString(InpRiskMultEndHour) + "\n";
   content += "#define RISK_MULT_END_MINUTE   " + IntegerToString(InpRiskMultEndMinute) + "\n";
   content += "#define RISK_MULTIPLIER        " + DoubleToString(InpRiskMultiplier, 1) + "\n";
   content += "#define RISK_MULT_DESCRIPTION  \"" + InpRiskMultDescription + "\"\n";
   content += "\n";
   content += "// NEWS FILTER\n";
   content += "#define USE_NEWS_FILTER        " + (InpUseNewsFilter ? "true" : "false") + "\n";
   content += "#define NEWS_CURRENCIES        \"" + InpNewsCurrencies + "\"\n";
   content += "#define KEY_NEWS_EVENTS        \"" + InpKeyNewsEvents + "\"\n";
   content += "#define STOP_BEFORE_NEWS_MIN   " + IntegerToString(InpStopBeforeNewsMin) + "\n";
   content += "#define START_AFTER_NEWS_MIN   " + IntegerToString(InpStartAfterNewsMin) + "\n";
   content += "#define NEWS_LOOKUP_DAYS       " + IntegerToString(InpNewsLookupDays) + "\n";
   content += "#define NEWS_SEPARATOR         " + newsSeparatorStr + "\n";
   content += "#define NEWS_BLOCK_MSG         \"" + InpNewsBlockMsg + "\"\n";
   content += "\n";
   content += "// MESSAGES D'ALERTE\n";
   content += "#define HOUR_BLOCK_MSG         \"" + InpHourBlockMsg + "\"\n";
   content += "#define DAY_BLOCK_MSG          \"" + InpDayBlockMsg + "\"\n";
   content += "#define BOTH_BLOCK_MSG         \"" + InpBothBlockMsg + "\"\n";
   content += "\n";
   content += "//═══════════════════════════════════════════════════════════════════\n";
   content += "//   FIN DU CONFIG BLOCK - NE PAS MODIFIER CI-DESSOUS\n";
   content += "//═══════════════════════════════════════════════════════════════════\n";
   
   return content;
}
//+------------------------------------------------------------------+
