//+------------------------------------------------------------------+
//|                                     Test_RSI_Signal_Reader.mq5   |
//+------------------------------------------------------------------+
#property script_show_inputs

input int TestBarsToRead = 100;  // Nombre de barres à lire
input bool TestNoGUIVersion = true;  // Tester la version NoGUI

void OnStart()
{
   Print("🔍 === TEST RSI SIGNAL READER ===");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Bars to read: ", TestBarsToRead);
   Print("Version NoGUI: ", (TestNoGUIVersion ? "OUI" : "NON"));
   
   // Charger l'indicateur
   string indicatorName = TestNoGUIVersion ? 
                         "RSI_Divergence_Indicator_NoGUI" : 
                         "RSI_Divergence_Indicator";
   
   int handle = iCustom(_Symbol, _Period, indicatorName,
                        3, PRICE_CLOSE, 90.0, 10.0, 5, 1, 5, 60);
   
   if(handle == INVALID_HANDLE)
   {
      Print("❌ Impossible de charger l'indicateur: ", indicatorName);
      Print("   Erreur: ", GetLastError());
      return;
   }
   
   Print("✅ Indicateur chargé, handle: ", handle);
   Print("   Nom: ", indicatorName);
   
   // Attendre que l'indicateur soit prêt
   Print("⏳ Attente de l'indicateur...");
   Sleep(3000);
   
   // Vérifier que l'indicateur a calculé des barres
   int barsCalculated = BarsCalculated(handle);
   int availableBars = Bars(_Symbol, _Period);
   
   Print("📊 État de l'indicateur:");
   Print("   Bars calculated: ", barsCalculated);
   Print("   Available bars: ", availableBars);
   Print("   Prêt? ", (barsCalculated >= availableBars - 5 ? "OUI" : "NON"));
   
   if(barsCalculated < availableBars - 10)
   {
      Print("⚠️ Indicateur pas encore prêt, tentative de lecture quand même...");
   }
   
   // Lire le buffer 7
   double signals[];
   ArraySetAsSeries(signals, true);
   int copied = CopyBuffer(handle, 7, 0, TestBarsToRead, signals);
   
   Print("═══ LECTURE BUFFER 7 - ", copied, " barres copiées ═══");
   
   if(copied <= 0)
   {
      Print("❌ Échec de lecture du buffer 7");
      Print("   Erreur: ", GetLastError());
      IndicatorRelease(handle);
      return;
   }
   
   // Analyser les signaux
   int signalsFound = 0;
   int regularBullish = 0;
   int regularBearish = 0;
   int hiddenBullish = 0;
   int hiddenBearish = 0;
   
   Print("🔍 Analyse des signaux:");
   
   for(int i = 0; i < copied; i++)
   {
      if(signals[i] != 0.0 && signals[i] != EMPTY_VALUE)
      {
         signalsFound++;
         datetime barTime = iTime(_Symbol, _Period, i);
         
         string signalType = "";
         if(signals[i] == 1.0)
         {
            signalType = "Regular Bullish";
            regularBullish++;
         }
         else if(signals[i] == 2.0)
         {
            signalType = "Regular Bearish";
            regularBearish++;
         }
         else if(signals[i] == 3.0)
         {
            signalType = "Hidden Bullish";
            hiddenBullish++;
         }
         else if(signals[i] == 4.0)
         {
            signalType = "Hidden Bearish";
            hiddenBearish++;
         }
         else
         {
            signalType = "Unknown (" + DoubleToString(signals[i], 1) + ")";
         }
         
         Print("🎯 Signal [", i, "] = ", signals[i], 
               " | Type: ", signalType,
               " | Time: ", TimeToString(barTime));
      }
   }
   
   // Résumé
   Print("═══ RÉSUMÉ ====");
   Print("Total signals trouvés: ", signalsFound, " sur ", copied, " barres");
   Print("Regular Bullish: ", regularBullish);
   Print("Regular Bearish: ", regularBearish);
   Print("Hidden Bullish: ", hiddenBullish);
   Print("Hidden Bearish: ", hiddenBearish);
   
   if(signalsFound == 0)
   {
      Print("⚠️ AUCUN SIGNAL TROUVÉ!");
      Print("   Cela peut indiquer:");
      Print("   - Paramètres trop stricts");
      Print("   - Pas de divergences sur cette période");
      Print("   - Problème dans l'indicateur");
      
      // Afficher quelques valeurs pour debug
      Print("🔍 Premières valeurs du buffer:");
      for(int i = 0; i < MathMin(10, copied); i++)
      {
         Print("   Buffer[", i, "] = ", signals[i]);
      }
   }
   else
   {
      Print("✅ Signaux détectés avec succès!");
   }
   
   // Test de lecture en temps réel
   Print("⏳ Test de lecture en temps réel (5 secondes)...");
   for(int test = 0; test < 5; test++)
   {
      Sleep(1000);
      
      double realTimeSignal[];
      ArraySetAsSeries(realTimeSignal, true);
      int realTimeCopied = CopyBuffer(handle, 7, 0, 1, realTimeSignal);
      
      if(realTimeCopied > 0)
      {
         Print("   Temps réel [0] = ", realTimeSignal[0]);
      }
   }
   
   IndicatorRelease(handle);
   Print("🏁 Test terminé");
}
