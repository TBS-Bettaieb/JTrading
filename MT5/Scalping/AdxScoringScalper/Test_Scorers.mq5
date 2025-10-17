//+------------------------------------------------------------------+
//|                                            Test_Scorers.mq5       |
//|                   Script de test pour valider la refactorisation |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.0"
#property strict

#include "common/scorers/TestScorers.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("🚀 Début du test de refactorisation des scorers");
   
   string symbol = Symbol();
   ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT;
   
   Print("Symbole de test: ", symbol);
   Print("Timeframe: ", EnumToString(timeframe));
   
   // Tester tous les scorers
   bool testResult = TestScorers::TestAllScorers(symbol, timeframe);
   
   if(testResult)
   {
      Print("🎉 REFACTORISATION VALIDÉE - Tous les tests ont réussi !");
      Print("✅ Les classes de scorers fonctionnent correctement");
      Print("✅ L'interface IFilterScorer est bien implémentée");
      Print("✅ AdxScoreTrader peut utiliser les nouveaux scorers");
   }
   else
   {
      Print("❌ REFACTORISATION ÉCHOUÉE - Des tests ont échoué");
      Print("⚠️ Vérifiez les erreurs ci-dessus");
   }
   
   Print("🏁 Fin du test de refactorisation");
}
