//+------------------------------------------------------------------+
//|                                    Example_DynamicStopLossUsage.mqh |
//|                    Exemple d'utilisation du calculateur de SL dynamique |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "DynamicStopLossCalculator.mqh"

//+------------------------------------------------------------------+
//| Exemple d'utilisation simple                                     |
//+------------------------------------------------------------------+
void ExampleSimpleUsage()
{
   string symbol = "EURUSD";
   ENUM_TIMEFRAMES timeframe = PERIOD_H1;
   bool isBuy = true;
   double entryPrice = 1.0850;
   
   // Utilisation simple avec fonction utilitaire
   double stopLoss = CalculateDynamicStopLoss(symbol, timeframe, isBuy, entryPrice);
   
   if(stopLoss > 0)
   {
      Print("✓ Stop-Loss calculé: ", DoubleToString(stopLoss, 5));
      Print("  Distance: ", DoubleToString(MathAbs(stopLoss - entryPrice), 5), " pips");
   }
   else
   {
      Print("❌ Erreur dans le calcul du Stop-Loss");
   }
}

//+------------------------------------------------------------------+
//| Exemple d'utilisation avec objet complet                        |
//+------------------------------------------------------------------+
void ExampleAdvancedUsage()
{
   string symbol = "GBPUSD";
   ENUM_TIMEFRAMES timeframe = PERIOD_M15;
   
   // Créer l'objet calculateur
   CDynamicStopLossCalculator calculator(symbol, timeframe);
   
   // Afficher les informations de debug
   Print(calculator.GetDebugInfo());
   
   // Calculer pour différents scénarios
   double buyEntry = 1.2500;
   double sellEntry = 1.2550;
   
   // Stop-Loss pour achat
   double buySL = calculator.CalculateStopLoss(true, buyEntry);
   if(buySL > 0)
   {
      Print("📈 BUY SL: ", DoubleToString(buySL, 5), 
            " | Distance: ", DoubleToString(MathAbs(buySL - buyEntry), 5));
   }
   
   // Stop-Loss pour vente
   double sellSL = calculator.CalculateStopLoss(false, sellEntry);
   if(sellSL > 0)
   {
      Print("📉 SELL SL: ", DoubleToString(sellSL, 5), 
            " | Distance: ", DoubleToString(MathAbs(sellSL - sellEntry), 5));
   }
}

//+------------------------------------------------------------------+
//| Exemple d'intégration dans un EA                                |
//+------------------------------------------------------------------+
class ExampleEA
{
private:
   CDynamicStopLossCalculator* m_slCalculator;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
public:
   ExampleEA(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_slCalculator = new CDynamicStopLossCalculator(symbol, timeframe);
   }
   
   ~ExampleEA()
   {
      if(m_slCalculator != NULL)
         delete m_slCalculator;
   }
   
   //+------------------------------------------------------------------+
   //| Ouvrir une position avec SL dynamique                           |
   //+------------------------------------------------------------------+
   bool OpenPositionWithDynamicSL(bool isBuy, double lotSize)
   {
      double entryPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
                                 SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Calculer le stop-loss dynamique
      double stopLoss = m_slCalculator.CalculateStopLoss(isBuy, entryPrice);
      
      if(stopLoss <= 0)
      {
         Print("❌ Impossible de calculer le Stop-Loss");
         return false;
      }
      
      // Calculer le take-profit (exemple: 2:1 ratio)
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double slDistance = MathAbs(stopLoss - entryPrice);
      double takeProfit = 0;
      
      if(isBuy)
         takeProfit = entryPrice + (slDistance * 2.0);
      else
         takeProfit = entryPrice - (slDistance * 2.0);
      
      // Normaliser les prix
      stopLoss = NormalizeDouble(stopLoss, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
      takeProfit = NormalizeDouble(takeProfit, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
      
      Print("🎯 Ouverture position:");
      Print("  Direction: ", (isBuy ? "BUY" : "SELL"));
      Print("  Entry: ", DoubleToString(entryPrice, 5));
      Print("  Stop-Loss: ", DoubleToString(stopLoss, 5));
      Print("  Take-Profit: ", DoubleToString(takeProfit, 5));
      Print("  Lot Size: ", DoubleToString(lotSize, 2));
      
      // Ici vous pouvez utiliser CTrade pour ouvrir la position
      // m_trade.Buy(lotSize, m_symbol, entryPrice, stopLoss, takeProfit, "Dynamic SL");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour le SL d'une position existante                   |
   //+------------------------------------------------------------------+
   bool UpdatePositionSL(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return false;
      
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      // Calculer le nouveau SL
      double newSL = m_slCalculator.CalculateStopLoss(isBuy, currentPrice);
      
      if(newSL <= 0) return false;
      
      double currentSL = PositionGetDouble(POSITION_SL);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Vérifier si le nouveau SL est meilleur
      bool shouldUpdate = false;
      
      if(isBuy && newSL > currentSL + point)
         shouldUpdate = true;
      else if(!isBuy && (newSL < currentSL - point || currentSL == 0))
         shouldUpdate = true;
      
      if(shouldUpdate)
      {
         Print("🔄 Mise à jour SL #", ticket, ": ", 
               DoubleToString(currentSL, 5), " → ", DoubleToString(newSL, 5));
         
         // Ici vous pouvez utiliser CTrade pour modifier la position
         // m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         
         return true;
      }
      
      return false;
   }
};

//+------------------------------------------------------------------+
//| Fonction de test pour valider le fonctionnement                 |
//+------------------------------------------------------------------+
void TestDynamicStopLossCalculator()
{
   Print("═══════════════════════════════════════");
   Print("🧪 TEST DYNAMIC STOP-LOSS CALCULATOR");
   Print("═══════════════════════════════════════");
   
   // Test 1: Utilisation simple
   Print("\n📋 Test 1: Utilisation simple");
   ExampleSimpleUsage();
   
   // Test 2: Utilisation avancée
   Print("\n📋 Test 2: Utilisation avancée");
   ExampleAdvancedUsage();
   
   // Test 3: Intégration EA
   Print("\n📋 Test 3: Intégration EA");
   ExampleEA ea("EURUSD", PERIOD_H1);
   ea.OpenPositionWithDynamicSL(true, 0.1);
   
   Print("═══════════════════════════════════════");
   Print("✅ Tests terminés");
   Print("═══════════════════════════════════════");
}
