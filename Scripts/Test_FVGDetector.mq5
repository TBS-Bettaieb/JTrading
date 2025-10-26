//+------------------------------------------------------------------+
//|                                        Test_FVGDetector.mq5      |
//| Test de la classe FVGDetector réutilisable                       |
//+------------------------------------------------------------------+
#property copyright "Test FVGDetector"
#property version   "1.00"
#property script_show_inputs

#include "../EA/Shared/FVGDetector.mqh"

//--- Inputs
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5;   // Timeframe
input int             InpLookbackBars = 100;      // Lookback bars
input bool            InpDebugMode = true;        // Mode debug

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== TEST FVGDetector ===");
   
   // Configuration
   FVGConfig config;
   config.atrPeriod = 14;
   config.minGapATRPercent = 5.0;
   config.epsilonPts = 0.1;
   config.invalidatePct = 30.0;
   config.mode = WICK_TOUCH;
   config.lookbackBars = InpLookbackBars;
   config.debugMode = InpDebugMode;
   
   // Initialisation
   FVGDetector detector;
   if(!detector.Init(_Symbol, InpTimeframe, config))
   {
      Print("ERREUR: Initialisation échouée");
      return;
   }
   
   Print("Initialisation réussie pour ", _Symbol, " sur ", EnumToString(InpTimeframe));
   
   // Test de détection
   int startTime = GetTickCount();
   int added = detector.ProcessTimeframe(InpTimeframe);
   int elapsed = GetTickCount() - startTime;
   
   Print("Détection terminée: ", added, " FVG ajoutés en ", elapsed, " ms");
   
   // Test d'invalidation
   int invalidated = detector.UpdateInvalidation(InpTimeframe);
   Print("Invalidation: ", invalidated, " FVG invalidés");
   
   // Statistiques
   int total, bullish, bearish, valid;
   detector.GetStats(total, bullish, bearish, valid);
   Print("=== STATISTIQUES ===");
   Print("Total: ", total);
   Print("Bullish: ", bullish);
   Print("Bearish: ", bearish);
   Print("Valides: ", valid);
   
   // Test récupération FVG
   FVGInfo allFVGs[];
   detector.GetFVGList(allFVGs, true);
   Print("FVG valides récupérés: ", ArraySize(allFVGs));
   
   // Test filtrage par type
   FVGInfo bullishFVGs[];
   detector.GetBullishFVGs(bullishFVGs, true);
   Print("FVG bullish valides: ", ArraySize(bullishFVGs));
   
   FVGInfo bearishFVGs[];
   detector.GetBearishFVGs(bearishFVGs, true);
   Print("FVG bearish valides: ", ArraySize(bearishFVGs));
   
   // Test multi-timeframe
   Print("\n=== TEST MULTI-TIMEFRAME ===");
   FVGDetector multiDetector;
   ENUM_TIMEFRAMES tfs[] = {PERIOD_M5, PERIOD_M15};
   
   if(multiDetector.Init(_Symbol, tfs, config))
   {
      multiDetector.ProcessTimeframe(PERIOD_M5);
      multiDetector.ProcessTimeframe(PERIOD_M15);
      
      FVGInfo m5FVGs[];
      multiDetector.GetFVGsByTimeframe(PERIOD_M5, m5FVGs, true);
      Print("FVG M5: ", ArraySize(m5FVGs));
      
      FVGInfo m15FVGs[];
      multiDetector.GetFVGsByTimeframe(PERIOD_M15, m15FVGs, true);
      Print("FVG M15: ", ArraySize(m15FVGs));
      
      multiDetector.GetStats(total, bullish, bearish, valid);
      Print("Total multi-TF: ", total, " (Valides: ", valid, ")");
   }
   
   // Affichage de quelques FVG pour vérification
   if(ArraySize(allFVGs) > 0)
   {
      Print("\n=== EXEMPLES DE FVG ===");
      int showCount = MathMin(5, ArraySize(allFVGs));
      for(int i = 0; i < showCount; i++)
      {
         Print(StringFormat("FVG #%d: %s | Time: %s | Top: %.5f | Bottom: %.5f | Gap: %.5f",
                           i + 1,
                           allFVGs[i].isBullish ? "BULLISH" : "BEARISH",
                           TimeToString(allFVGs[i].time),
                           allFVGs[i].top,
                           allFVGs[i].bottom,
                           allFVGs[i].gapSize));
      }
   }
   
   Print("\n=== TEST TERMINÉ ===");
}

//+------------------------------------------------------------------+

