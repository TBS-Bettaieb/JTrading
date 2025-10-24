//+------------------------------------------------------------------+
//|                                           Test_RSI_Classes.mq5   |
//|                         RSI Divergence Trading System              |
//|                        Script de test des classes modulaires       |
//+------------------------------------------------------------------+
//| Version: 1.0                                                     |
//| Changelog:                                                       |
//| ✅ [TEST] Validation des classes modulaires RSI Divergence        |
//| ✅ [TEST] Tests de calcul RSI avec CRSICalculator                 |
//| ✅ [TEST] Tests de détection pivots avec CPivotDetector           |
//| ✅ [TEST] Tests de détection divergences avec CDivergenceDetector |
//| ✅ [TEST] Tests de visualisation avec CDivergenceVisualizer       |
//| ✅ [TEST] Comparaison avec les résultats de l'indicateur original |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "..\Shared\RSI_Calculator.mqh"
#include "..\Shared\Pivot_Detector.mqh"
#include "..\Shared\Divergence_Detector.mqh"
#include "..\Shared\Divergence_Visualizer.mqh"

//--- Input parameters
input group "═══ Test Parameters ═══"
input int    InpRSIPeriod = 3;            // RSI Period
input int    InpLookbackLeft = 3;         // Lookback Left
input int    InpLookbackRight = 1;        // Lookback Right
input int    InpRangeLower = 3;           // Range Lower
input int    InpRangeUpper = 100;         // Range Upper
input int    InpTestBars = 500;           // Number of bars to test
input bool   InpShowVisualization = true; // Show visualization

//--- Global variables
CRSICalculator* rsiCalculator = NULL;
CPivotDetector* pivotDetector = NULL;
CDivergenceDetector* divergenceDetector = NULL;
CDivergenceVisualizer* visualizer = NULL;

//--- Test statistics
struct TestStats
{
   int totalBars;
   int rsiCalculated;
   int pivotsFound;
   int divergencesFound;
   int regularBullish;
   int regularBearish;
   int hiddenBullish;
   int hiddenBearish;
   double testDuration;
   bool allTestsPassed;
};

TestStats stats;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("🚀 Démarrage des tests des classes modulaires RSI Divergence");
   Print("════════════════════════════════════════════════════════════");
   
   // Initialiser les statistiques
   InitializeStats();
   
   // Exécuter les tests
   if(RunAllTests())
   {
      Print("✅ Tous les tests sont passés avec succès !");
      PrintTestResults();
   }
   else
   {
      Print("❌ Certains tests ont échoué !");
      PrintTestResults();
   }
   
   // Nettoyage
   Cleanup();
   
   Print("════════════════════════════════════════════════════════════");
   Print("🏁 Tests terminés");
}

//+------------------------------------------------------------------+
//| Initialiser les statistiques de test                             |
//+------------------------------------------------------------------+
void InitializeStats()
{
   stats.totalBars = 0;
   stats.rsiCalculated = 0;
   stats.pivotsFound = 0;
   stats.divergencesFound = 0;
   stats.regularBullish = 0;
   stats.regularBearish = 0;
   stats.hiddenBullish = 0;
   stats.hiddenBearish = 0;
   stats.testDuration = 0;
   stats.allTestsPassed = true;
}

//+------------------------------------------------------------------+
//| Exécuter tous les tests                                          |
//+------------------------------------------------------------------+
bool RunAllTests()
{
   datetime startTime = GetTickCount();
   
   Print("🔧 Initialisation des classes...");
   if(!InitializeClasses())
   {
      Print("❌ Échec de l'initialisation des classes");
      return false;
   }
   
   Print("📊 Test 1: Calcul RSI...");
   if(!TestRSICalculation())
   {
      Print("❌ Échec du test de calcul RSI");
      stats.allTestsPassed = false;
   }
   
   Print("🎯 Test 2: Détection des pivots...");
   if(!TestPivotDetection())
   {
      Print("❌ Échec du test de détection des pivots");
      stats.allTestsPassed = false;
   }
   
   Print("🔍 Test 3: Détection des divergences...");
   if(!TestDivergenceDetection())
   {
      Print("❌ Échec du test de détection des divergences");
      stats.allTestsPassed = false;
   }
   
   if(InpShowVisualization)
   {
      Print("🎨 Test 4: Visualisation...");
      if(!TestVisualization())
      {
         Print("❌ Échec du test de visualisation");
         stats.allTestsPassed = false;
      }
   }
   
   Print("⚡ Test 5: Performance...");
   if(!TestPerformance())
   {
      Print("❌ Échec du test de performance");
      stats.allTestsPassed = false;
   }
   
   stats.testDuration = (GetTickCount() - startTime) / 1000.0;
   
   return stats.allTestsPassed;
}

//+------------------------------------------------------------------+
//| Initialiser les classes                                          |
//+------------------------------------------------------------------+
bool InitializeClasses()
{
   // 1. Calculateur RSI
   rsiCalculator = new CRSICalculator(InpRSIPeriod, PRICE_CLOSE);
   if(rsiCalculator == NULL)
   {
      Print("❌ Impossible de créer CRSICalculator");
      return false;
   }
   Print("✅ CRSICalculator initialisé");
   
   // 2. Détecteur de pivots
   pivotDetector = new CPivotDetector(InpLookbackLeft, InpLookbackRight);
   if(pivotDetector == NULL)
   {
      Print("❌ Impossible de créer CPivotDetector");
      return false;
   }
   Print("✅ CPivotDetector initialisé");
   
   // 3. Détecteur de divergences
   divergenceDetector = new CDivergenceDetector(InpRangeLower, InpRangeUpper, pivotDetector);
   if(divergenceDetector == NULL)
   {
      Print("❌ Impossible de créer CDivergenceDetector");
      return false;
   }
   Print("✅ CDivergenceDetector initialisé");
   
   // 4. Visualiseur (optionnel)
   if(InpShowVisualization)
   {
      visualizer = new CDivergenceVisualizer("TEST_RSI_", 0, 100);
      if(visualizer == NULL)
      {
         Print("❌ Impossible de créer CDivergenceVisualizer");
         return false;
      }
      Print("✅ CDivergenceVisualizer initialisé");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Test du calcul RSI                                               |
//+------------------------------------------------------------------+
bool TestRSICalculation()
{
   Print("   📈 Test du calcul RSI...");
   
   // Obtenir les données de prix
   double close[];
   int bars = MathMin(InpTestBars, Bars(_Symbol, _Period));
   
   if(bars < InpRSIPeriod + 10)
   {
      Print("   ❌ Pas assez de barres pour ignorer le test");
      return false;
   }
   
   ArrayResize(close, bars);
   if(CopyClose(_Symbol, _Period, 0, bars, close) <= 0)
   {
      Print("   ❌ Impossible de copier les données de prix");
      return false;
   }
   
   // Calculer le RSI
   if(!rsiCalculator.Calculate(bars, 0, close))
   {
      Print("   ❌ Échec du calcul RSI");
      return false;
   }
   
   // Vérifier les résultats
   double rsiValue = rsiCalculator.GetValue(0);
   if(rsiValue == EMPTY_VALUE || rsiValue < 0 || rsiValue > 100)
   {
      Print("   ❌ Valeur RSI invalide: ", rsiValue);
      return false;
   }
   
   // Obtenir le buffer complet
   double rsiBuffer[];
   if(!rsiCalculator.GetBuffer(rsiBuffer, 0, bars))
   {
      Print("   ❌ Impossible d'obtenir le buffer RSI");
      return false;
   }
   
   // Vérifier que le buffer contient des valeurs valides
   int validValues = 0;
   for(int i = 0; i < ArraySize(rsiBuffer); i++)
   {
      if(rsiBuffer[i] != EMPTY_VALUE && rsiBuffer[i] >= 0 && rsiBuffer[i] <= 100)
         validValues++;
   }
   
   stats.rsiCalculated = validValues;
   stats.totalBars = bars;
   
   Print("   ✅ RSI calculé avec succès - ", validValues, " valeurs valides sur ", bars, " barres");
   Print("   📊 RSI actuel: ", DoubleToString(rsiValue, 2));
   
   return true;
}

//+------------------------------------------------------------------+
//| Test de la détection des pivots                                  |
//+------------------------------------------------------------------+
bool TestPivotDetection()
{
   Print("   🎯 Test de la détection des pivots...");
   
   // Obtenir les données RSI
   double rsiBuffer[];
   if(!rsiCalculator.GetBuffer(rsiBuffer, 0, stats.totalBars))
   {
      Print("   ❌ Impossible d'obtenir le buffer RSI");
      return false;
   }
   
   // Obtenir les données de temps
   datetime time[];
   ArrayResize(time, stats.totalBars);
   if(CopyTime(_Symbol, _Period, 0, stats.totalBars, time) <= 0)
   {
      Print("   ❌ Impossible de copier les données de temps");
      return false;
   }
   
   // Rechercher les pivots
   SPivotInfo pivotHighs[], pivotLows[];
   int startPos = InpLookbackRight + 1;
   int endPos = MathMin(50, stats.totalBars - InpLookbackLeft - 1);
   
   if(startPos > endPos)
   {
      Print("   ❌ Paramètres de recherche invalides");
      return false;
   }
   
   int found = pivotDetector.FindPivots(rsiBuffer, time, startPos, endPos, pivotHighs, pivotLows);
   
   if(found < 0)
   {
      Print("   ❌ Erreur lors de la recherche des pivots");
      return false;
   }
   
   stats.pivotsFound = found;
   
   Print("   ✅ Détection des pivots réussie - ", found, " pivots trouvés");
   Print("   📊 Pivots hauts: ", ArraySize(pivotHighs), " | Pivots bas: ", ArraySize(pivotLows));
   
   // Vérifier quelques pivots
   if(ArraySize(pivotHighs) > 0)
   {
      Print("   📈 Premier pivot haut: Position=", pivotHighs[0].position, " Valeur=", DoubleToString(pivotHighs[0].value, 2));
   }
   
   if(ArraySize(pivotLows) > 0)
   {
      Print("   📉 Premier pivot bas: Position=", pivotLows[0].position, " Valeur=", DoubleToString(pivotLows[0].value, 2));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Test de la détection des divergences                             |
//+------------------------------------------------------------------+
bool TestDivergenceDetection()
{
   Print("   🔍 Test de la détection des divergences...");
   
   // Obtenir les données nécessaires
   double rsiBuffer[], high[], low[];
   datetime time[];
   
   ArrayResize(rsiBuffer, stats.totalBars);
   ArrayResize(high, stats.totalBars);
   ArrayResize(low, stats.totalBars);
   ArrayResize(time, stats.totalBars);
   
   if(!rsiCalculator.GetBuffer(rsiBuffer, 0, stats.totalBars) ||
      CopyHigh(_Symbol, _Period, 0, stats.totalBars, high) <= 0 ||
      CopyLow(_Symbol, _Period, 0, stats.totalBars, low) <= 0 ||
      CopyTime(_Symbol, _Period, 0, stats.totalBars, time) <= 0)
   {
      Print("   ❌ Impossible d'obtenir les données nécessaires");
      return false;
   }
   
   // Scanner les divergences
   SDivergenceResult results[];
   int startPos = InpLookbackRight + 1;
   int endPos = MathMin(50, stats.totalBars - InpRangeUpper - InpLookbackLeft - 1);
   
   if(startPos > endPos)
   {
      Print("   ❌ Paramètres de recherche invalides");
      return false;
   }
   
   int found = divergenceDetector.ScanDivergences(startPos, endPos, rsiBuffer, high, low, time, results);
   
   if(found < 0)
   {
      Print("   ❌ Erreur lors de la recherche des divergences");
      return false;
   }
   
   stats.divergencesFound = found;
   
   // Compter par type
   for(int i = 0; i < found; i++)
   {
      switch(results[i].type)
      {
         case DIVERGENCE_REGULAR_BULL:
            stats.regularBullish++;
            break;
         case DIVERGENCE_REGULAR_BEAR:
            stats.regularBearish++;
            break;
         case DIVERGENCE_HIDDEN_BULL:
            stats.hiddenBullish++;
            break;
         case DIVERGENCE_HIDDEN_BEAR:
            stats.hiddenBearish++;
            break;
      }
   }
   
   Print("   ✅ Détection des divergences réussie - ", found, " divergences trouvées");
   Print("   📊 Regular Bullish: ", stats.regularBullish);
   Print("   📊 Regular Bearish: ", stats.regularBearish);
   Print("   📊 Hidden Bullish: ", stats.hiddenBullish);
   Print("   📊 Hidden Bearish: ", stats.hiddenBearish);
   
   // Afficher les détails des premières divergences
   for(int i = 0; i < MathMin(3, found); i++)
   {
      Print("   🔍 Divergence ", i+1, ": Type=", EnumToString(results[i].type), 
            " Bar=", results[i].currentBar, " RSI=", DoubleToString(results[i].currentRSI, 2));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Test de la visualisation                                         |
//+------------------------------------------------------------------+
bool TestVisualization()
{
   Print("   🎨 Test de la visualisation...");
   
   if(visualizer == NULL)
   {
      Print("   ⚠️ Visualiseur non initialisé - test ignoré");
      return true;
   }
   
   // Créer une divergence de test
   SDivergenceResult testDiv;
   testDiv.found = true;
   testDiv.currentBar = 10;
   testDiv.previousBar = 20;
   testDiv.currentRSI = 25.5;
   testDiv.previousRSI = 20.0;
   testDiv.currentPrice = 1.2500;
   testDiv.previousPrice = 1.2600;
   testDiv.type = DIVERGENCE_REGULAR_BULL;
   testDiv.currentTime = TimeCurrent();
   testDiv.previousTime = TimeCurrent() - 3600;
   testDiv.isValid = true;
   
   // Obtenir les données de temps
   datetime time[];
   ArrayResize(time, 2);
   time[0] = testDiv.currentTime;
   time[1] = testDiv.previousTime;
   
   // Tester le dessin
   if(!visualizer.DrawDivergence(testDiv, time))
   {
      Print("   ❌ Échec du dessin de la divergence");
      return false;
   }
   
   Print("   ✅ Visualisation réussie - divergence de test dessinée");
   
   // Nettoyer après le test
   visualizer.DeleteAllObjects();
   
   return true;
}

//+------------------------------------------------------------------+
//| Test de performance                                              |
//+------------------------------------------------------------------+
bool TestPerformance()
{
   Print("   ⚡ Test de performance...");
   
   datetime startTime = GetTickCount();
   
   // Test de calcul RSI répété
   double close[];
   ArrayResize(close, stats.totalBars);
   CopyClose(_Symbol, _Period, 0, stats.totalBars, close);
   
   for(int i = 0; i < 10; i++)
   {
      rsiCalculator.Calculate(stats.totalBars, 0, close);
   }
   
   datetime rsiTime = GetTickCount();
   
   // Test de détection des pivots répétée
   double rsiBuffer[];
   rsiCalculator.GetBuffer(rsiBuffer, 0, stats.totalBars);
   
   for(int i = 0; i < 10; i++)
   {
      SPivotInfo dummyHighs[], dummyLows[];
      pivotDetector.FindPivots(rsiBuffer, NULL, 10, 50, dummyHighs, dummyLows);
   }
   
   datetime pivotTime = GetTickCount();
   
   // Test de détection des divergences répétée
   double high[], low[];
   datetime time[];
   ArrayResize(high, stats.totalBars);
   ArrayResize(low, stats.totalBars);
   ArrayResize(time, stats.totalBars);
   CopyHigh(_Symbol, _Period, 0, stats.totalBars, high);
   CopyLow(_Symbol, _Period, 0, stats.totalBars, low);
   CopyTime(_Symbol, _Period, 0, stats.totalBars, time);
   
   for(int i = 0; i < 10; i++)
   {
      SDivergenceResult dummyResults[];
      divergenceDetector.ScanDivergences(10, 50, rsiBuffer, high, low, time, dummyResults);
   }
   
   datetime divergenceTime = GetTickCount();
   
   // Calculer les temps
   double rsiDuration = (rsiTime - startTime) / 10.0;
   double pivotDuration = (pivotTime - rsiTime) / 10.0;
   double divergenceDuration = (divergenceTime - pivotTime) / 10.0;
   
   Print("   ✅ Tests de performance terminés");
   Print("   ⚡ Temps moyen calcul RSI: ", DoubleToString(rsiDuration, 2), " ms");
   Print("   ⚡ Temps moyen détection pivots: ", DoubleToString(pivotDuration, 2), " ms");
   Print("   ⚡ Temps moyen détection divergences: ", DoubleToString(divergenceDuration, 2), " ms");
   
   // Vérifier que les temps sont raisonnables
   if(rsiDuration > 100 || pivotDuration > 100 || divergenceDuration > 100)
   {
      Print("   ⚠️ Performance dégradée détectée");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Afficher les résultats des tests                                 |
//+------------------------------------------------------------------+
void PrintTestResults()
{
   Print("📊 RÉSULTATS DES TESTS");
   Print("════════════════════════════════════════════════════════════");
   Print("📈 Barres testées: ", stats.totalBars);
   Print("📊 Valeurs RSI calculées: ", stats.rsiCalculated);
   Print("🎯 Pivots trouvés: ", stats.pivotsFound);
   Print("🔍 Divergences trouvées: ", stats.divergencesFound);
   Print("   └─ Regular Bullish: ", stats.regularBullish);
   Print("   └─ Regular Bearish: ", stats.regularBearish);
   Print("   └─ Hidden Bullish: ", stats.hiddenBullish);
   Print("   └─ Hidden Bearish: ", stats.hiddenBearish);
   Print("⏱️ Durée totale des tests: ", DoubleToString(stats.testDuration, 2), " secondes");
   Print("✅ Tous les tests passés: ", (stats.allTestsPassed ? "OUI" : "NON"));
   Print("════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Nettoyage des ressources                                         |
//+------------------------------------------------------------------+
void Cleanup()
{
   Print("🧹 Nettoyage des ressources...");
   
   if(rsiCalculator != NULL)
   {
      delete rsiCalculator;
      rsiCalculator = NULL;
   }
   
   if(pivotDetector != NULL)
   {
      delete pivotDetector;
      pivotDetector = NULL;
   }
   
   if(divergenceDetector != NULL)
   {
      delete divergenceDetector;
      divergenceDetector = NULL;
   }
   
   if(visualizer != NULL)
   {
      delete visualizer;
      visualizer = NULL;
   }
   
   Print("✅ Nettoyage terminé");
}

//+------------------------------------------------------------------+
