//+------------------------------------------------------------------+
//| TestScorers.mqh - Test des classes de scorers                  |
//|                   Fichier de test pour valider la refactorisation |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "IFilterScorer.mqh"
#include "AdxScorer.mqh"
#include "RsiScorer.mqh"
#include "MaScorer.mqh"

//+------------------------------------------------------------------+
//| Classe de test pour valider les scorers                         |
//+------------------------------------------------------------------+
class TestScorers
{
public:
   //+------------------------------------------------------------------+
   //| Tester tous les scorers                                         |
   //+------------------------------------------------------------------+
   static bool TestAllScorers(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      Print("🧪 Début des tests des scorers pour ", symbol);
      
      bool allTestsPassed = true;
      
      // Test AdxScorer
      if(!TestAdxScorer(symbol, timeframe))
      {
         Print("❌ Test AdxScorer échoué");
         allTestsPassed = false;
      }
      
      // Test RsiScorer
      if(!TestRsiScorer(symbol, timeframe))
      {
         Print("❌ Test RsiScorer échoué");
         allTestsPassed = false;
      }
      
      // Test MaScorer
      if(!TestMaScorer(symbol, timeframe))
      {
         Print("❌ Test MaScorer échoué");
         allTestsPassed = false;
      }
      
      if(allTestsPassed)
      {
         Print("✅ Tous les tests des scorers ont réussi");
      }
      else
      {
         Print("❌ Certains tests des scorers ont échoué");
      }
      
      return allTestsPassed;
   }

private:
   //+------------------------------------------------------------------+
   //| Tester AdxScorer                                                |
   //+------------------------------------------------------------------+
   static bool TestAdxScorer(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      Print("🧪 Test AdxScorer...");
      
      AdxScorer* scorer = new AdxScorer(symbol, timeframe, 14);
      
      if(!scorer.Initialize())
      {
         Print("❌ AdxScorer: Échec initialisation");
         delete scorer;
         return false;
      }
      
      scorer.Update();
      
      double adxValue = scorer.GetCurrentValue();
      int buyScore = scorer.GetBuyScore();
      int sellScore = scorer.GetSellScore();
      bool isHighTrend = scorer.IsHighTrend();
      
      Print("   ADX Value: ", adxValue);
      Print("   Buy Score: ", buyScore);
      Print("   Sell Score: ", sellScore);
      Print("   Is High Trend: ", isHighTrend);
      
      delete scorer;
      Print("✅ Test AdxScorer réussi");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Tester RsiScorer                                                |
   //+------------------------------------------------------------------+
   static bool TestRsiScorer(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      Print("🧪 Test RsiScorer...");
      
      RsiScorer* scorer = new RsiScorer(symbol, timeframe, 14);
      
      if(!scorer.Initialize())
      {
         Print("❌ RsiScorer: Échec initialisation");
         delete scorer;
         return false;
      }
      
      scorer.Update();
      
      double rsiValue = scorer.GetCurrentValue();
      int buyScore = scorer.GetBuyScore();
      int sellScore = scorer.GetSellScore();
      bool isHighTrend = scorer.IsHighTrend();
      
      Print("   RSI Value: ", rsiValue);
      Print("   Buy Score: ", buyScore);
      Print("   Sell Score: ", sellScore);
      Print("   Is High Trend: ", isHighTrend);
      
      delete scorer;
      Print("✅ Test RsiScorer réussi");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Tester MaScorer                                                 |
   //+------------------------------------------------------------------+
   static bool TestMaScorer(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      Print("🧪 Test MaScorer...");
      
      MaScorer* scorer = new MaScorer(symbol, timeframe, 50, MODE_SMA);
      
      if(!scorer.Initialize())
      {
         Print("❌ MaScorer: Échec initialisation");
         delete scorer;
         return false;
      }
      
      scorer.Update();
      
      double maValue = scorer.GetCurrentValue();
      double price = scorer.GetCurrentPrice();
      int buyScore = scorer.GetBuyScore();
      int sellScore = scorer.GetSellScore();
      bool isHighTrend = scorer.IsHighTrend();
      double distance = scorer.GetDistancePercent();
      
      Print("   MA Value: ", maValue);
      Print("   Price: ", price);
      Print("   Buy Score: ", buyScore);
      Print("   Sell Score: ", sellScore);
      Print("   Is High Trend: ", isHighTrend);
      Print("   Distance %: ", distance);
      
      delete scorer;
      Print("✅ Test MaScorer réussi");
      return true;
   }
};
