//+------------------------------------------------------------------+
//|                                           JTStrategy_Test.mq5    |
//|                      EA de test pour valider l'architecture v3   |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property description "EA de test pour valider les stratégies v3"
#property strict

#include <Trade/Trade.mqh>
#include "common/JT_StrategyFactory.mqh"
#include "common/JT_Utils.mqh"

//--- Inputs
input group "═══ Sélection de Stratégie ═══"
input ENUM_STRATEGY_TYPE Strategy_Type = STRATEGY_FREE_CANDLE;  // Type de stratégie à tester

input group "═══ Configuration Basique ═══"
input string   InpSymbol     = "";                  // Symbole (vide = _Symbol)
input ENUM_TIMEFRAMES InpTF  = PERIOD_CURRENT;      // Timeframe
input double   Risk_Percent  = 0.1;                 // % risque par trade
input double   Min_RR        = 2.0;                 // Ratio RR minimum

//--- Global
JTBaseStrategy* strategy = NULL;
ulong Magic = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   string s = (InpSymbol == "" ? _Symbol : InpSymbol);
   ENUM_TIMEFRAMES tf = (InpTF == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF);
   
   // Générer magic unique
   Magic = GenerateMagicNumber(s, tf);
   
   Print("═══════════════════════════════════════════════════");
   Print("  JTStrategy Test - Validation Architecture v3");
   Print("═══════════════════════════════════════════════════");
   Print("Symbol: ", s);
   Print("Timeframe: ", EnumToString(tf));
   Print("Magic: ", Magic);
   Print("Strategy Type: ", JTStrategyFactory::GetStrategyName(Strategy_Type));
   Print("Description: ", JTStrategyFactory::GetStrategyDescription(Strategy_Type));
   
   // Créer la stratégie
   strategy = JTStrategyFactory::CreateStrategy(Strategy_Type, s, tf, Magic);
   
   if(strategy == NULL) {
      Print("❌ ERREUR: Impossible de créer la stratégie");
      return INIT_FAILED;
   }
   
   // Configuration basique
   strategy.SetRiskPercent(Risk_Percent);
   strategy.SetMinRR(Min_RR);
   
   // Configuration spécifique selon le type
   if(Strategy_Type == STRATEGY_FREE_CANDLE) {
      JTFreeCandleStrategy* fcStrategy = dynamic_cast<JTFreeCandleStrategy*>(strategy);
      if(fcStrategy != NULL) {
         fcStrategy.SetBBParameters(20, 2.0, 5, true);
         fcStrategy.SetRSIParameters(14, 30, 70);
         fcStrategy.EnableRSIFilter(true);
         Print("✓ Stratégie FreeCandle configurée");
      }
   }
   else if(Strategy_Type == STRATEGY_BREAKOUT) {
      JTBreakoutStrategy* breakoutStrategy = dynamic_cast<JTBreakoutStrategy*>(strategy);
      if(breakoutStrategy != NULL) {
         breakoutStrategy.SetBBParameters(20, 2.0, 5, false);
         breakoutStrategy.SetConfirmationBars(2);
         Print("✓ Stratégie Breakout configurée");
      }
   }
   else if(Strategy_Type == STRATEGY_MEAN_REVERSION) {
      JTMeanReversionStrategy* mrStrategy = dynamic_cast<JTMeanReversionStrategy*>(strategy);
      if(mrStrategy != NULL) {
         mrStrategy.SetBBParameters(20, 2.0);
         mrStrategy.SetMeanReversionParameters(20.0, 0.8);
         mrStrategy.SetRSIParameters(14, 30, 70);
         mrStrategy.EnableRSIFilter(true);
         Print("✓ Stratégie MeanReversion configurée");
      }
   }
   
   // Initialiser
   if(!strategy.Init()) {
      Print("❌ ERREUR: Échec de l'initialisation de la stratégie");
      delete strategy;
      strategy = NULL;
      return INIT_FAILED;
   }
   
   Print("═══════════════════════════════════════════════════");
   Print("✅ Stratégie '", strategy.GetStrategyName(), "' initialisée avec succès");
   Print("✅ EA prêt au trading");
   Print("═══════════════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("═══════════════════════════════════════════════════");
   Print("  Déinitialisation de l'EA de test");
   Print("  Raison: ", reason);
   Print("═══════════════════════════════════════════════════");
   
   if(strategy != NULL) {
      Print("Stratégie active: ", strategy.GetStrategyName());
      strategy.Deinit();
      delete strategy;
      strategy = NULL;
   }
   
   Print("✅ EA de test déinitialisé avec succès");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(strategy != NULL) {
      strategy.OnTick();
   }
}

//+------------------------------------------------------------------+
//| Expert comment function - Afficher les infos                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(strategy != NULL) {
      string info = "═══ JTStrategy Test v3.0 ═══\n";
      info += "Stratégie: " + strategy.GetStrategyName() + "\n";
      info += "Symbole: " + strategy.GetSymbol() + "\n";
      info += "Timeframe: " + EnumToString(strategy.GetTimeframe()) + "\n";
      info += "Magic: " + IntegerToString(strategy.GetMagic()) + "\n";
      info += "\nPositions: " + IntegerToString(PositionsTotal()) + "\n";
      
      Comment(info);
   }
}

//+------------------------------------------------------------------+

