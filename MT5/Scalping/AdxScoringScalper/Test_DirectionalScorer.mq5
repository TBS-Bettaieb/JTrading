//+------------------------------------------------------------------+
//|                                    Test_DirectionalScorer.mq5    |
//|                   Test de la classe AdxDirectionalScorer         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.0"
#property strict

#include "common/scorers/AdxDirectionalScorer.mqh"

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
AdxDirectionalScorer* directionalScorer = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🧪 Test AdxDirectionalScorer - Démarrage");
   
   // Créer et initialiser le scorer
   directionalScorer = new AdxDirectionalScorer(Symbol(), Period(), 14);
   
   if(!directionalScorer.Initialize())
   {
      Print("❌ Erreur initialisation AdxDirectionalScorer");
      return INIT_FAILED;
   }
   
   Print("✅ AdxDirectionalScorer initialisé avec succès");
   Print("   Symbole: ", Symbol());
   Print("   Timeframe: ", EnumToString(Period()));
   Print("   Période ADX: 14");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(directionalScorer != NULL)
   {
      delete directionalScorer;
      directionalScorer = NULL;
   }
   
   Print("🧪 Test AdxDirectionalScorer - Arrêt");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(directionalScorer == NULL) return;
   
   // Mettre à jour les valeurs
   directionalScorer.Update();
   
   // Afficher les informations toutes les 10 ticks
   static int tickCount = 0;
   tickCount++;
   
   if(tickCount % 10 == 0)
   {
      double dPlus = directionalScorer.GetDPlus();
      double dMinus = directionalScorer.GetDMinus();
      int buyScore = directionalScorer.GetBuyScore();
      int sellScore = directionalScorer.GetSellScore();
      bool isHighTrend = directionalScorer.IsHighTrend();
      bool isCrossover = directionalScorer.IsCrossover();
      bool isCrossunder = directionalScorer.IsCrossunder();
      double spread = directionalScorer.GetSpread();
      int direction = directionalScorer.GetDirection();
      
      Print("📊 AdxDirectionalScorer - Tick ", tickCount);
      Print("   D+: ", DoubleToString(dPlus, 2));
      Print("   D-: ", DoubleToString(dMinus, 2));
      Print("   Écart: ", DoubleToString(spread, 2));
      Print("   Direction: ", (direction == 1 ? "D+ Dominant" : direction == -1 ? "D- Dominant" : "Neutre"));
      Print("   Score BUY: ", buyScore);
      Print("   Score SELL: ", sellScore);
      Print("   Tendance forte: ", (isHighTrend ? "OUI" : "NON"));
      Print("   Croisement D+: ", (isCrossover ? "OUI" : "NON"));
      Print("   Croisement D-: ", (isCrossunder ? "OUI" : "NON"));
      Print("   ────────────────────────────────");
   }
}
