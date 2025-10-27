//+------------------------------------------------------------------+
//|                                    Example_ConfluenceUsage.mqh   |
//|                   Exemple d'utilisation des Confluences          |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier dans votre EA                             |
//| 2. Utilisez les méthodes de confluence dans votre logique       |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - Validation complète de confluence pour Triple RSI            |
//| - Utilisation individuelle des filtres                        |
//+------------------------------------------------------------------+
#property strict

#include "../Logic/ConfluenceFilters.mqh"

//+------------------------------------------------------------------+
//| Exemple d'utilisation des confluences dans Triple RSI          |
//+------------------------------------------------------------------+
class CConfluenceExample
{
public:
   //--- Exemple de validation complète de confluence
   static bool ValidateTripleRSIConfluence(string symbol, ENUM_TIMEFRAMES timeframe, 
                                          double rsi1, double rsi2, double rsi3, bool isBuy)
   {
      Print("=== VALIDATION CONFLUENCE TRIPLE RSI ===");
      Print("Symbol: ", symbol, " | Timeframe: ", EnumToString(timeframe));
      Print("RSI Values: ", DoubleToString(rsi1, 1), "/", DoubleToString(rsi2, 1), "/", DoubleToString(rsi3, 1));
      Print("Signal: ", (isBuy ? "BUY" : "SELL"));
      
      int confluenceScore = 0;
      bool confluenceOK = ConfluenceFilters::CheckCompleteConfluence(symbol, timeframe, isBuy, confluenceScore);
      
      Print("Confluence Score: ", IntegerToString(confluenceScore), "/6");
      Print("Confluence Valid: ", (confluenceOK ? "YES" : "NO"));
      Print("=========================================");
      
      return confluenceOK;
   }
   
   //--- Exemple d'utilisation individuelle des filtres
   static void TestIndividualFilters(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy)
   {
      Print("=== TEST FILTRES INDIVIDUELS ===");
      
      // 1. MACD
      bool macdOK = ConfluenceFilters::CheckMACDBullish(symbol, timeframe);
      Print("MACD Confluence: ", (macdOK ? "YES" : "NO"));
      
      // 2. Multi-timeframe Trend
      bool trendOK = ConfluenceFilters::CheckHigherTimeframeTrend(symbol, PERIOD_M15, isBuy);
      Print("Multi-timeframe Trend: ", (trendOK ? "YES" : "NO"));
      
      // 3. Volume
      bool volumeOK = ConfluenceFilters::CheckVolumeConfluence(symbol, timeframe, isBuy);
      Print("Volume Confluence: ", (volumeOK ? "YES" : "NO"));
      
      // 4. EMA200
      bool ema200OK = ConfluenceFilters::CheckEMA200Confluence(symbol, timeframe, isBuy);
      Print("EMA200 Confluence: ", (ema200OK ? "YES" : "NO"));
      
      // 5. Stochastique
      bool stochOK = ConfluenceFilters::CheckStochasticConfluence(symbol, timeframe, isBuy);
      Print("Stochastic Confluence: ", (stochOK ? "YES" : "NO"));
      
      // 6. Niveaux psychologiques
      bool psychologicalOK = ConfluenceFilters::CheckPsychologicalLevels(symbol, 100.0, isBuy);
      Print("Psychological Levels: ", (psychologicalOK ? "YES" : "NO"));
      
      Print("===============================");
   }
   
   //--- Exemple d'intégration dans TripleRSITrader
   static bool ProcessTripleRSISignal(string symbol, ENUM_TIMEFRAMES timeframe, 
                                     double rsi1, double rsi2, double rsi3, bool isBuy)
   {
      // 1. Vérifier signal Triple RSI de base
      bool tripleRSISignal = false;
      if(isBuy)
      {
         tripleRSISignal = (rsi1 > 30 && rsi2 > 30 && rsi3 > 30);
      }
      else
      {
         tripleRSISignal = (rsi1 < 70 && rsi2 < 70 && rsi3 < 70);
      }
      
      if(!tripleRSISignal)
      {
         Print("Triple RSI signal not valid");
         return false;
      }
      
      // 2. Valider confluences techniques
      bool confluenceOK = ValidateTripleRSIConfluence(symbol, timeframe, rsi1, rsi2, rsi3, isBuy);
      
      if(confluenceOK)
      {
         Print("✅ SIGNAL VALIDÉ - Triple RSI + Confluences OK");
         return true;
      }
      else
      {
         Print("❌ SIGNAL REJETÉ - Confluences insuffisantes");
         return false;
      }
   }
   
   //--- Exemple de configuration optimale pour scalping
   static void ShowOptimalConfiguration()
   {
      Print("=== CONFIGURATION OPTIMALE SCALPING ===");
      Print("1. Volume: Multiplicateur minimum 1.2x");
      Print("2. EMA200: Tolérance 5 points");
      Print("3. MACD: Standard (12,26,9)");
      Print("4. Stochastique: Standard (14,3,3)");
      Print("5. Multi-timeframe: M15 pour confirmation");
      Print("6. Niveaux psychologiques: 100 points (US100/US30)");
      Print("7. Score minimum: 3/6 confluences");
      Print("=======================================");
   }
   
   //--- Exemple d'affichage des informations de confluence
   static void DisplayConfluenceInfo(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy)
   {
      Print("=== INFORMATIONS CONFLUENCE ===");
      Print("Symbol: ", symbol);
      Print("Timeframe: ", EnumToString(timeframe));
      Print("Signal: ", (isBuy ? "BUY" : "SELL"));
      Print("Time: ", TimeToString(TimeCurrent()));
      
      // Test des filtres individuels
      TestIndividualFilters(symbol, timeframe, isBuy);
      
      Print("===============================");
   }
};

//+------------------------------------------------------------------+
//| Fonction d'exemple pour tester les confluences                 |
//+------------------------------------------------------------------+
void TestConfluenceSystem()
{
   string symbol = "US100";
   ENUM_TIMEFRAMES timeframe = PERIOD_M5;
   
   Print("=== TEST SYSTÈME CONFLUENCE ===");
   
   // Test signal BUY
   Print("\n--- TEST SIGNAL BUY ---");
   bool buyResult = CConfluenceExample::ProcessTripleRSISignal(symbol, timeframe, 35, 32, 28, true);
   
   // Test signal SELL
   Print("\n--- TEST SIGNAL SELL ---");
   bool sellResult = CConfluenceExample::ProcessTripleRSISignal(symbol, timeframe, 65, 68, 72, false);
   
   // Afficher configuration optimale
   CConfluenceExample::ShowOptimalConfiguration();
   
   Print("=== FIN TEST ===");
}
