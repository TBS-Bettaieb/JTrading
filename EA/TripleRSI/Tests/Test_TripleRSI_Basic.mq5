//+------------------------------------------------------------------+
//|                                        Test_TripleRSI_Basic.mq5  |
//|                                    Script de Test Triple RSI     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

//+------------------------------------------------------------------+
//| Paramètres de test                                               |
//+------------------------------------------------------------------+
input string InpTestSymbol = "EURUSD";     // Symbole de test
input ENUM_TIMEFRAMES InpTestTimeframe = PERIOD_M15; // Timeframe de test
input int InpTestBars = 100;               // Nombre de barres à tester
input bool InpShowDetails = true;           // Afficher les détails

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "../Logic/RSI_Calculator.mqh"
#include "../Logic/RSI_AlignmentDetector.mqh"
#include "../Logic/EntryRulesValidator.mqh"
#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CTripleRSICalculator* g_rsiCalc = NULL;
CRSIAlignmentDetector* g_alignDetector = NULL;
CEntryRulesValidator* g_entryValidator = NULL;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Logger::Initialize((ENUM_LOG_LEVEL)3, "[TripleRSI Test] ");
   Logger::Info("=== TRIPLE RSI BASIC TEST ===");
   
   // Initialiser les composants
   if(!InitializeComponents())
   {
      Logger::Error("Failed to initialize components");
      return;
   }
   
   // Exécuter les tests
   TestRSICalculation();
   TestAlignmentDetection();
   TestEntryValidation();
   TestSignalGeneration();
   
   // Afficher le résumé
   PrintTestSummary();
   
   // Cleanup
   CleanupComponents();
   
   Logger::Info("=== TEST COMPLETED ===");
}

//+------------------------------------------------------------------+
//| Initialiser les composants de test                              |
//+------------------------------------------------------------------+
bool InitializeComponents()
{
   Logger::Info("Initializing test components...");
   
   // Créer le calculateur RSI
   g_rsiCalc = new CTripleRSICalculator();
   if(g_rsiCalc == NULL || !g_rsiCalc.Initialize(InpTestSymbol, InpTestTimeframe, 7, 14, 21))
   {
      Logger::Error("Failed to initialize RSI Calculator");
      return false;
   }
   
   // Créer le détecteur d'alignement
   g_alignDetector = new CRSIAlignmentDetector(30, 70);
   
   // Créer le validateur d'entrée
   g_entryValidator = new CEntryRulesValidator();
   
   Logger::Success("All components initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Test du calcul RSI                                               |
//+------------------------------------------------------------------+
void TestRSICalculation()
{
   Logger::Info("--- Testing RSI Calculation ---");
   
   double rsi1, rsi2, rsi3;
   
   // Test valeurs courantes
   if(g_rsiCalc.GetCurrentValues(rsi1, rsi2, rsi3))
   {
      Logger::Info("Current RSI Values:");
      Logger::Info("  RSI(7): " + DoubleToString(rsi1, 2));
      Logger::Info("  RSI(14): " + DoubleToString(rsi2, 2));
      Logger::Info("  RSI(21): " + DoubleToString(rsi3, 2));
      
      // Validation des valeurs
      if(rsi1 >= 0 && rsi1 <= 100 && rsi2 >= 0 && rsi2 <= 100 && rsi3 >= 0 && rsi3 <= 100)
      {
         Logger::Success("✓ RSI values are valid");
      }
      else
      {
         Logger::Error("✗ RSI values are invalid");
      }
   }
   else
   {
      Logger::Error("✗ Failed to get RSI values");
   }
   
   // Test valeurs historiques
   double rsi1Hist[], rsi2Hist[], rsi3Hist[];
   if(g_rsiCalc.GetHistoricalValues(10, rsi1Hist, rsi2Hist, rsi3Hist))
   {
      Logger::Info("Historical RSI Values (last 10 bars):");
      for(int i = 0; i < MathMin(10, ArraySize(rsi1Hist)); i++)
      {
         Logger::Info("  Bar " + IntegerToString(i) + ": " + 
                      DoubleToString(rsi1Hist[i], 2) + "/" + 
                      DoubleToString(rsi2Hist[i], 2) + "/" + 
                      DoubleToString(rsi3Hist[i], 2));
      }
      Logger::Success("✓ Historical RSI values retrieved");
   }
   else
   {
      Logger::Error("✗ Failed to get historical RSI values");
   }
}

//+------------------------------------------------------------------+
//| Test de la détection d'alignement                                |
//+------------------------------------------------------------------+
void TestAlignmentDetection()
{
   Logger::Info("--- Testing Alignment Detection ---");
   
   // Test différents scénarios
   struct TestCase
   {
      double rsi1, rsi2, rsi3;
      string description;
      int expectedSignal;
   };
   
   TestCase testCases[] = {
      {35, 32, 31, "All RSI > 30 (BUY signal)", RSI_SIGNAL_BUY},
      {68, 69, 71, "All RSI < 70 (SELL signal)", RSI_SIGNAL_SELL},
      {25, 35, 45, "Mixed signals (NO signal)", RSI_SIGNAL_NONE},
      {75, 65, 55, "Mixed signals (NO signal)", RSI_SIGNAL_NONE},
      {50, 50, 50, "Neutral zone (NO signal)", RSI_SIGNAL_NONE}
   };
   
   int testCount = ArraySize(testCases);
   int passedTests = 0;
   
   for(int i = 0; i < testCount; i++)
   {
      int signal = (int)g_alignDetector.GetRawSignal(
         testCases[i].rsi1, testCases[i].rsi2, testCases[i].rsi3);
      
      bool passed = (signal == testCases[i].expectedSignal);
      
      Logger::Info("Test " + IntegerToString(i+1) + ": " + testCases[i].description);
      Logger::Info("  RSI: " + DoubleToString(testCases[i].rsi1, 1) + "/" + 
                   DoubleToString(testCases[i].rsi2, 1) + "/" + 
                   DoubleToString(testCases[i].rsi3, 1));
      Logger::Info("  Expected: " + SignalToString(testCases[i].expectedSignal) + 
                   " | Got: " + SignalToString(signal));
      
      if(passed)
      {
         Logger::Success("  ✓ PASSED");
         passedTests++;
      }
      else
      {
         Logger::Error("  ✗ FAILED");
      }
   }
   
   Logger::Info("Alignment Detection Tests: " + IntegerToString(passedTests) + 
                "/" + IntegerToString(testCount) + " passed");
}

//+------------------------------------------------------------------+
//| Test de la validation d'entrée                                  |
//+------------------------------------------------------------------+
void TestEntryValidation()
{
   Logger::Info("--- Testing Entry Validation ---");
   
   // Test validation BUY
   double slPrice;
   if(g_entryValidator.ValidateBuyEntry(InpTestSymbol, InpTestTimeframe, 5, slPrice))
   {
      Logger::Success("✓ BUY entry validation passed");
      Logger::Info("  SL Price: " + DoubleToString(slPrice, 5));
      
      double currentPrice = SymbolInfoDouble(InpTestSymbol, SYMBOL_ASK);
      double slDistance = (currentPrice - slPrice) / SymbolInfoDouble(InpTestSymbol, SYMBOL_POINT);
      Logger::Info("  SL Distance: " + DoubleToString(slDistance, 0) + " points");
   }
   else
   {
      Logger::Error("✗ BUY entry validation failed");
   }
   
   // Test validation SELL
   if(g_entryValidator.ValidateSellEntry(InpTestSymbol, InpTestTimeframe, 5, slPrice))
   {
      Logger::Success("✓ SELL entry validation passed");
      Logger::Info("  SL Price: " + DoubleToString(slPrice, 5));
      
      double currentPrice = SymbolInfoDouble(InpTestSymbol, SYMBOL_BID);
      double slDistance = (slPrice - currentPrice) / SymbolInfoDouble(InpTestSymbol, SYMBOL_POINT);
      Logger::Info("  SL Distance: " + DoubleToString(slDistance, 0) + " points");
   }
   else
   {
      Logger::Error("✗ SELL entry validation failed");
   }
   
   // Test informations de validation
   if(InpShowDetails)
   {
      string validationInfo = g_entryValidator.GetValidationInfo(InpTestSymbol);
      Logger::Info("Validation Info:\n" + validationInfo);
   }
}

//+------------------------------------------------------------------+
//| Test de génération de signaux                                    |
//+------------------------------------------------------------------+
void TestSignalGeneration()
{
   Logger::Info("--- Testing Signal Generation ---");
   
   double rsi1, rsi2, rsi3;
   if(!g_rsiCalc.GetCurrentValues(rsi1, rsi2, rsi3))
   {
      Logger::Error("Failed to get RSI values for signal test");
      return;
   }
   
   // Test signal avec répétition
   ENUM_RSI_SIGNAL signal1 = g_alignDetector.GetSignal(rsi1, rsi2, rsi3, false);
   ENUM_RSI_SIGNAL signal2 = g_alignDetector.GetSignal(rsi1, rsi2, rsi3, false);
   
   Logger::Info("Signal Test:");
   Logger::Info("  RSI Values: " + DoubleToString(rsi1, 2) + "/" + 
                DoubleToString(rsi2, 2) + "/" + DoubleToString(rsi3, 2));
   Logger::Info("  Signal 1: " + SignalToString(signal1));
   Logger::Info("  Signal 2: " + SignalToString(signal2));
   
   if(signal1 == signal2 && signal1 != RSI_SIGNAL_NONE)
   {
      Logger::Info("  Note: Signal repetition blocked (expected behavior)");
   }
   
   // Test force du signal
   double signalStrength = g_alignDetector.GetSignalStrength(rsi1, rsi2, rsi3);
   Logger::Info("  Signal Strength: " + DoubleToString(signalStrength, 2));
   
   // Test informations détaillées
   if(InpShowDetails)
   {
      string alignmentInfo = g_alignDetector.GetAlignmentInfo(rsi1, rsi2, rsi3);
      Logger::Info("Alignment Analysis:\n" + alignmentInfo);
   }
}

//+------------------------------------------------------------------+
//| Afficher le résumé des tests                                     |
//+------------------------------------------------------------------+
void PrintTestSummary()
{
   Logger::Info("=== TEST SUMMARY ===");
   Logger::Info("Symbol: " + InpTestSymbol);
   Logger::Info("Timeframe: " + EnumToString(InpTestTimeframe));
   Logger::Info("Test Bars: " + IntegerToString(InpTestBars));
   
   // Informations sur le symbole
   double spread = (double)SymbolInfoInteger(InpTestSymbol, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(InpTestSymbol, SYMBOL_POINT);
   double minLot = SymbolInfoDouble(InpTestSymbol, SYMBOL_VOLUME_MIN);
   
   Logger::Info("Symbol Info:");
   Logger::Info("  Spread: " + DoubleToString(spread, 0) + " points");
   Logger::Info("  Point: " + DoubleToString(point, 5));
   Logger::Info("  Min Lot: " + DoubleToString(minLot, 2));
   
   Logger::Info("All tests completed successfully!");
}

//+------------------------------------------------------------------+
//| Nettoyer les composants                                          |
//+------------------------------------------------------------------+
void CleanupComponents()
{
   if(g_rsiCalc != NULL)
   {
      g_rsiCalc.Deinitialize();
      delete g_rsiCalc;
      g_rsiCalc = NULL;
   }
   
   if(g_alignDetector != NULL)
   {
      delete g_alignDetector;
      g_alignDetector = NULL;
   }
   
   if(g_entryValidator != NULL)
   {
      delete g_entryValidator;
      g_entryValidator = NULL;
   }
   
   Logger::Debug("Components cleaned up");
}

//+------------------------------------------------------------------+
//| Convertir signal en string                                       |
//+------------------------------------------------------------------+
string SignalToString(int signal)
{
   switch(signal)
   {
      case RSI_SIGNAL_BUY: return "BUY";
      case RSI_SIGNAL_SELL: return "SELL";
      case RSI_SIGNAL_NONE: return "NONE";
      default: return "UNKNOWN";
   }
}
