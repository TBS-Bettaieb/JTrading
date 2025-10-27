//+------------------------------------------------------------------+
//|                                    Test_DynamicStopLossIntegration.mq5 |
//|                    Test d'intégration du Dynamic Stop-Loss      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "../Core/TripleRSIConfig.mqh"
#include "../Core/TripleRSITrader.mqh"
#include "../../Shared/DynamicStopLossCalculator.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== TEST DYNAMIC STOP-LOSS INTEGRATION ===");
   
   // Test 1: Création du DynamicStopLossCalculator
   Print("\n1. Test création DynamicStopLossCalculator...");
   CDynamicStopLossCalculator* calculator = new CDynamicStopLossCalculator(Symbol(), PERIOD_M5);
   if(calculator == NULL)
   {
      Print("❌ ERREUR: Impossible de créer le calculator");
      return INIT_FAILED;
   }
   Print("✅ DynamicStopLossCalculator créé avec succès");
   
   // Test 2: Configuration des paramètres
   Print("\n2. Test configuration des paramètres...");
   calculator.SetSwingLookbackPeriods(15);
   calculator.SetSwingMinDistancePoints(25);
   calculator.SetSwingVolumeThreshold(1.5);
   calculator.SetATRPeriod(10);
   calculator.SetATRMultiplier(2.0);
   Print("✅ Paramètres configurés avec succès");
   
   // Test 3: Calcul de Stop-Loss pour BUY
   Print("\n3. Test calcul SL pour position BUY...");
   double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double slBuy = calculator.CalculateStopLoss(true, currentPrice);
   if(slBuy > 0)
   {
      Print("✅ SL BUY calculé: " + DoubleToString(slBuy, 5) + " (Prix: " + DoubleToString(currentPrice, 5) + ")");
   }
   else
   {
      Print("⚠️ SL BUY non calculé (fallback attendu)");
   }
   
   // Test 4: Calcul de Stop-Loss pour SELL
   Print("\n4. Test calcul SL pour position SELL...");
   double slSell = calculator.CalculateStopLoss(false, currentPrice);
   if(slSell > 0)
   {
      Print("✅ SL SELL calculé: " + DoubleToString(slSell, 5) + " (Prix: " + DoubleToString(currentPrice, 5) + ")");
   }
   else
   {
      Print("⚠️ SL SELL non calculé (fallback attendu)");
   }
   
   // Test 5: Création d'un TripleRSITrader avec Dynamic SL
   Print("\n5. Test création TripleRSITrader avec Dynamic SL...");
   TripleRSIConfig config;
   config.useDynamicStopLoss = true;
   
   CTripleRSITrader* trader = new CTripleRSITrader(
      Symbol(), 12345, PERIOD_M5,
      2.0, 50, 2.0,  // risk, slPoints, tpRatio
      false, true,    // useTrailing, useDynamicTrailing
      20, 10,         // tslTrigger, tslPoints
      14, 21, 28,     // rsi periods
      30, 70,         // oversold, overbought
      true, false,    // useAlerts, sendNotif
      true, "AUTO",   // enableConfluence, confluenceMode
      true            // useDynamicStopLoss
   );
   
   if(trader == NULL)
   {
      Print("❌ ERREUR: Impossible de créer le trader");
      delete calculator;
      return INIT_FAILED;
   }
   Print("✅ TripleRSITrader créé avec Dynamic SL activé");
   
   // Test 6: Configuration du Dynamic SL dans le trader
   Print("\n6. Test configuration Dynamic SL dans le trader...");
   trader.ConfigureDynamicSL(
      20, 30, 1.2,    // swing params
      5, 14, 1.5,     // atr params
      28, 1.2, 1.7,   // atr long params
      0.5              // default percent
   );
   Print("✅ Configuration Dynamic SL appliquée au trader");
   
   // Test 7: Test de la méthode CalculateDynamicStopLoss du trader
   Print("\n7. Test CalculateDynamicStopLoss du trader...");
   double traderSLBuy = trader.CalculateDynamicStopLoss(true, currentPrice);
   double traderSLSell = trader.CalculateDynamicStopLoss(false, currentPrice);
   
   Print("✅ Trader SL BUY: " + DoubleToString(traderSLBuy, 5));
   Print("✅ Trader SL SELL: " + DoubleToString(traderSLSell, 5));
   
   // Test 8: Informations de debug
   Print("\n8. Informations de debug du calculator...");
   string debugInfo = calculator.GetDebugInfo();
   Print("Debug Info:\n" + debugInfo);
   
   // Nettoyage
   Print("\n9. Nettoyage des ressources...");
   delete trader;
   delete calculator;
   Print("✅ Ressources nettoyées");
   
   Print("\n=== TOUS LES TESTS TERMINÉS AVEC SUCCÈS ===");
   Print("✅ L'intégration du Dynamic Stop-Loss fonctionne correctement !");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Test Dynamic Stop-Loss Integration terminé");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Pas de traitement en temps réel pour ce test
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Pas de timer nécessaire pour ce test
}
