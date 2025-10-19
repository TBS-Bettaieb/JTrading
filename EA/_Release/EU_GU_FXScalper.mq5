//+------------------------------------------------------------------+
//|                                    EU_GU_FXScalper.mq5           |
//|                         Forex scalper for EURUSd and GBPUSD      |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict


//-------------------------------------------------------------------
//   ¦¦¦¦¦¦¦¦+                  CONFIG BLOCK                ¦¦¦¦¦¦¦¦+
//-------------------------------------------------------------------

// ?? IDENTITÉ DE LA STRATÉGIE
#define STRATEGY_NAME          "EU_GU_FXScalper V1.0"
#define STRATEGY_COMMENT       "EU_GU_FXScalper"
#define BASE_MAGIC_NUMBER      298347  // ?? DOIT ÊTRE UNIQUE!

// ?? CONFIGURATION DES SYMBOLES
#define DEFAULT_SYMBOLS        "EURUSD,GBPUSD"
#define USE_ALL_MARKET_WATCH   false
#define TRADING_TIMEFRAME      PERIOD_M5

// ?? GESTION DU RISQUE
#define RISK_PERCENT           4.0

// ?? TAKE PROFIT / STOP LOSS (en points, 10 points = 1 pip)
#define TAKE_PROFIT_POINTS     200
#define STOP_LOSS_POINTS       180

// ?? TRAILING STOP LOSS
#define TSL_TRIGGER_POINTS     10
#define TSL_POINTS             10

// ? HEURES DE TRADING (0 = inactif, 1-23 = actif)
#define START_HOUR             7
#define END_HOUR               20

// ?? PARAMÈTRES DE STRATÉGIE
#define STRATEGY_TYPE          STRATEGY_BREAKOUT
#define BARS_ANALYSIS          5
#define EXPIRATION_BARS        50
#define ORDER_DISTANCE_POINTS  80

// ?? TRAILING TAKE PROFIT
#define USE_TRAILING_TP        true
#define TRAILING_TP_MODE       TRAILING_TP_CUSTOM
#define CUSTOM_TP_LEVELS       "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150"

// ?? MESSAGES D ALERTE
#define HOUR_BLOCK_MSG         "? TRADING PAUSED - Outside Trading Hours"
#define DAY_BLOCK_MSG          "?? TRADING PAUSED - Outside Trading Days"
#define BOTH_BLOCK_MSG         "?? TRADING PAUSED - Outside Trading Schedule"

//-------------------------------------------------------------------
//   ¦¦¦¦¦¦¦¦+        FIN DU CONFIG BLOCK                   ¦¦¦¦¦¦¦¦+
//-------------------------------------------------------------------


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
//    - Utiliser un nom descriptif: E_G_USDScalper.mq5
//    - Éviter les noms génériques: Scalper2.mq5
//
// 2. MAGIC NUMBER UNIQUE:
//    - Utiliser une plage: 298000-299999
//    - Documenter quelque part: quel magic = quel bot
//
// 3. OPTIMISATION PAR PAIRE:
//    - Backtester chaque combinaison de symboles
//    - Ajuster TP/SL selon la volatilité
//    - Tester différentes sessions horaires
//
// 4. STRATÉGIE BREAKOUT vs REVERSION:
//    - BREAKOUT: Marchés trending (forte volatilité)
//    - REVERSION: Marchés ranging (basse volatilité)
//
// 5. TRAILING TP RECOMMANDÉ:
//    - STEPPED: Simple et efficace (défaut)
//    - CUSTOM: Pour stratégies avancées
//
// 6. FICHIERS À DUPLIQUER POUR CRÉER VARIANTES:
//    - Ce template → renommer → modifier CONFIG
//    - core/ForexScalperBot.mqh reste inchangé!
//
//+------------------------------------------------------------------+