//+------------------------------------------------------------------+
//|                                        Test_Paths_Simple.mq5     |
//|                         RSI Divergence Trading System              |
//|                        Test simple des chemins d'inclusion        |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"

// Test des inclusions avec chemins globaux
#include <Shared\RSI_Calculator.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("✅ Test des chemins d'inclusion réussi !");
   Print("Les fichiers MQH sont accessibles depuis le dossier Shared/");
   
   // Test de création d'instance
   CRSICalculator* rsiCalc = new CRSICalculator(14);
   if(rsiCalc != NULL)
   {
      Print("✅ Instance CRSICalculator créée avec succès !");
      delete rsiCalc;
   }
   else
   {
      Print("❌ Erreur lors de la création de l'instance.");
   }
}
