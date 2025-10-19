//+------------------------------------------------------------------+
//|                                    XAUUSD_Gold_Scalper.mq5        |
//|                         Gold scalper for XAUUSD                   |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict

// User Input Parameters
input double InpRiskPercent = 0.5;  // Risk per trade (%)

//═══════════════════════════════════════════════════════════════════
//   CONFIG BLOCK - PERSONNALISEZ ICI
//═══════════════════════════════════════════════════════════════════

// IDENTITE DE LA STRATEGIE
#define STRATEGY_NAME          "XAUUSD Gold Scalper V1.0"
#define STRATEGY_COMMENT       "XAUUSD_Gold_Scalper"
#define BASE_MAGIC_NUMBER      29479999

// CONFIGURATION DES SYMBOLES
#define DEFAULT_SYMBOLS        "XAUUSD"
#define USE_ALL_MARKET_WATCH   false
#define TRADING_TIMEFRAME      PERIOD_M5

// GESTION DU RISQUE

// TAKE PROFIT / STOP LOSS (en points, 10 points = 1 pip)
#define TAKE_PROFIT_POINTS     1500
#define STOP_LOSS_POINTS       1500

// TRAILING STOP LOSS
#define TSL_TRIGGER_POINTS     20
#define TSL_POINTS             15

// HEURES DE TRADING (0 = inactif, 1-23 = actif)
#define START_HOUR             10
#define END_HOUR               17

// PARAMETRES DE STRATEGIE
#define STRATEGY_TYPE          STRATEGY_BREAKOUT
#define BARS_ANALYSIS          6
#define EXPIRATION_BARS        60
#define ORDER_DISTANCE_POINTS  120

// TRAILING TAKE PROFIT
#define USE_TRAILING_TP        true
#define TRAILING_TP_MODE       TRAILING_TP_STEPPED
#define CUSTOM_TP_LEVELS       "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150"

// RISK MULTIPLIER (BOOST PERIOD)
#define USE_RISK_MULTIPLIER    true
#define RISK_MULT_START_HOUR   13
#define RISK_MULT_START_MINUTE 0
#define RISK_MULT_END_HOUR     18
#define RISK_MULT_END_MINUTE   0
#define RISK_MULTIPLIER        2.0
#define RISK_MULT_DESCRIPTION  "London-NY Overlap"

// NEWS FILTER
#define USE_NEWS_FILTER        true
#define NEWS_CURRENCIES        "USD,EUR,GBP"
#define KEY_NEWS_EVENTS        "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP"
#define STOP_BEFORE_NEWS_MIN   30
#define START_AFTER_NEWS_MIN   10
#define NEWS_LOOKUP_DAYS       7
#define NEWS_SEPARATOR         COMMA
#define NEWS_BLOCK_MSG         "📰 TRADING PAUSED - High Impact News Event"

// MESSAGES D'ALERTE
#define HOUR_BLOCK_MSG         "⏰ TRADING PAUSED - Outside Trading Hours"
#define DAY_BLOCK_MSG          "📅 TRADING PAUSED - Outside Trading Days"
#define BOTH_BLOCK_MSG         "🚫 TRADING PAUSED - Outside Trading Schedule"

//═══════════════════════════════════════════════════════════════════
//   FIN DU CONFIG BLOCK - NE PAS MODIFIER CI-DESSOUS
//═══════════════════════════════════════════════════════════════════


// Include bot engine
#include "../ScalpingFx/Core/ForexScalperBot.mqh"

// Global bot instance
ForexScalperBot* bot = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create configuration from defines
   BotConfig config;
   config.strategyName = STRATEGY_NAME;
   config.strategyComment = STRATEGY_COMMENT;
   config.baseMagic = BASE_MAGIC_NUMBER;
   config.symbolsList = DEFAULT_SYMBOLS;
   config.useAllSymbols = USE_ALL_MARKET_WATCH;
   config.timeframe = TRADING_TIMEFRAME;
   config.riskPercent = InpRiskPercent;
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
   config.useRiskMultiplier = USE_RISK_MULTIPLIER;
   config.riskMultStartHour = RISK_MULT_START_HOUR;
   config.riskMultStartMinute = RISK_MULT_START_MINUTE;
   config.riskMultEndHour = RISK_MULT_END_HOUR;
   config.riskMultEndMinute = RISK_MULT_END_MINUTE;
   config.riskMultiplier = RISK_MULTIPLIER;
   config.riskMultDescription = RISK_MULT_DESCRIPTION;
   config.useNewsFilter = USE_NEWS_FILTER;
   config.newsCurrencies = NEWS_CURRENCIES;
   config.keyNewsEvents = KEY_NEWS_EVENTS;
   config.stopBeforeNewsMin = STOP_BEFORE_NEWS_MIN;
   config.startAfterNewsMin = START_AFTER_NEWS_MIN;
   config.newsLookupDays = NEWS_LOOKUP_DAYS;
   config.newsSeparator = NEWS_SEPARATOR;
   config.newsBlockMsg = NEWS_BLOCK_MSG;
   config.hourBlockMsg = HOUR_BLOCK_MSG;
   config.dayBlockMsg = DAY_BLOCK_MSG;
   config.bothBlockMsg = BOTH_BLOCK_MSG;
   
   // Initialize bot
   bot = new ForexScalperBot(config);
   if(bot == NULL)
   {
      Print("❌ ERROR: Failed to create bot instance");
      return(INIT_FAILED);
   }
   
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
// 📝 NOTES RAPIDES POUR PERSONNALISATION:
//
// 1. CHANGER LE NOM DU FICHIER:
//    - Utiliser un nom descriptif: XAUUSD_Gold_Scalper.mq5
//    - Éviter les noms génériques: Scalper2.mq5
//
// 2. MAGIC NUMBER UNIQUE:
//    - Utiliser une plage: 298000-299999
//    - Documenter quelque part: quel magic = quel bot
//
// 3. OPTIMISATION PAR SYMBOLE:
//    - Backtester XAUUSD spécifiquement
//    - Ajuster TP/SL selon la volatilité de l'or
//    - Tester différentes sessions horaires (10-17h configuré)
//
// 4. STRATÉGIE BREAKOUT vs REVERSION:
//    - BREAKOUT: Marchés trending (forte volatilité)
//    - REVERSION: Marchés ranging (basse volatilité)
//
// 5. TRAILING TP RECOMMANDÉ:
//    - STEPPED: Simple et efficace (configuré)
//    - CUSTOM: Pour stratégies avancées
//
// 6. FICHIERS À DUPLIQUER POUR CRÉER VARIANTES:
//    - Ce template → renommer → modifier CONFIG
//    - core/ForexScalperBot.mqh reste inchangé!
//
//+------------------------------------------------------------------+
