//+------------------------------------------------------------------+
//|                                           Test_Compilation.mq5   |
//|                         RSI Divergence Trading System              |
//|                        Test de compilation des classes            |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"

// Test des inclusions
#include <Shared\RSI_Calculator.mqh>
#include <Shared\Pivot_Detector.mqh>
#include <Shared\Divergence_Detector.mqh>
#include <Shared\Divergence_Visualizer.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("✅ Test de compilation réussi !");
   Print("Toutes les classes MQH compilent sans erreur.");
   
   // Test de création d'instances
   CRSICalculator* rsiCalc = new CRSICalculator(14);
   CPivotDetector* pivotDet = new CPivotDetector(3, 1);
   CDivergenceDetector* divDet = new CDivergenceDetector(3, 100, pivotDet);
   CDivergenceVisualizer* visualizer = new CDivergenceVisualizer("TEST_");
   
   if(rsiCalc != NULL && pivotDet != NULL && divDet != NULL && visualizer != NULL)
   {
      Print("✅ Toutes les instances ont été créées avec succès !");
      
      // Nettoyage
      delete visualizer;
      delete divDet;
      delete pivotDet;
      delete rsiCalc;
      
      Print("✅ Test de compilation terminé avec succès !");
   }
   else
   {
      Print("❌ Erreur lors de la création des instances.");
   }
}
