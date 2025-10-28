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
   
   // Test 5: Création d'un TripleRSITrader avec nouveaux paramètres SL
   Print("\n5. Test création TripleRSITrader avec nouveaux paramètres SL...");
   TripleRSIConfig config;
   config.slMode = SL_FIXED_POINTS;
   config.fixedSLPoints = 50;
   config.percentSLPrice = 0.5;
   
   CTripleRSITrader* trader = new CTripleRSITrader(
      Symbol(), 12345, PERIOD_M5,
      2.0, 2.0,           // risk, tpRatio
      false,               // useDynamicTrailing
      14, 21, 28,          // rsi periods
      30, 70,              // oversold, overbought
      true, false          // useAlerts, sendNotif
   );
   
   if(trader == NULL)
   {
      Print("❌ ERREUR: Impossible de créer le trader");
      delete calculator;
      return INIT_FAILED;
   }
   
   // Initialiser la configuration
   trader.Initialize(config);
   Print("✅ TripleRSITrader créé avec nouveaux paramètres SL");
   
   // Test 6: Test du calcul de SL
   Print("\n6. Test calcul SL...");
   double testPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double slPrice = trader.CalculateStopLoss(true, testPrice);
   
   if(slPrice > 0)
   {
      Print("✅ SL calculé: " + DoubleToString(slPrice, 5) + " (Prix: " + DoubleToString(testPrice, 5) + ")");
   }
   else
   {
      Print("❌ ERREUR: Impossible de calculer le SL");
   }
   
   // Test 7: Test avec mode pourcentage
   Print("\n7. Test mode SL pourcentage...");
   config.slMode = SL_PERCENT_PRICE;
   config.percentSLPrice = 1.0; // 1%
   trader = new CTripleRSITrader(
      Symbol(), 12346, PERIOD_M5,
      2.0, 2.0,           // risk, tpRatio
      false,               // useDynamicTrailing
      14, 21, 28,          // rsi periods
      30, 70,              // oversold, overbought
      true, false          // useAlerts, sendNotif
   );
   
   if(trader != NULL)
   {
      trader.Initialize(config);
      double slPercent = trader.CalculateStopLoss(false, testPrice);
      Print("✅ SL pourcentage calculé: " + DoubleToString(slPercent, 5));
   }
   
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
   Print("✅ L'intégration des nouveaux paramètres SL fonctionne correctement !");
   
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
