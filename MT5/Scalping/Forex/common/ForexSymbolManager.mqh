//+------------------------------------------------------------------+
//|                                        ForexSymbolManager.mqh    |
//|                Gestionnaire de symboles multi-trading Forex     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../CommonUtils/TradingUtils.mqh"

//+------------------------------------------------------------------+
//| Afficher les informations sur les symboles configurés           |
//+------------------------------------------------------------------+
void PrintSymbolsInfo(string &symbolArray[], int baseMagic, ENUM_TIMEFRAMES timeframe, string strategyName = "")
{
   int count = ArraySize(symbolArray);
   
   Print("═══════════════════════════════════════");
   Print("🔧 FOREX SYMBOLS CONFIGURATION");
   Print("═══════════════════════════════════════");
   Print("Total symbols: ", count);
   Print("Strategy: ", strategyName);
   Print("Timeframe: ", EnumToString(timeframe));
   
   for(int i = 0; i < count; i++)
   {
      int magic = GenerateMagicNumber(baseMagic, i, timeframe, strategyName);
      string symbol = symbolArray[i];
      
      // Informations sur le symbole
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      Print("  [", i+1, "] ", symbol, " | Magic: ", magic);
      Print("      Point: ", DoubleToString(point, 5), " | Spread: ", DoubleToString(spread, 0));
      Print("      Lots: ", DoubleToString(minLot, 2), " - ", DoubleToString(maxLot, 2));
   }
   
   Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Obtenir les statistiques globales des symboles                  |
//+------------------------------------------------------------------+
string GetGlobalSymbolsStatus(string &symbolArray[], ForexSymbolTrader* &traders[])
{
   if(ArraySize(symbolArray) != ArraySize(traders))
      return "ERROR: Array size mismatch";
   
   int symbolCount = ArraySize(symbolArray);
   int activeSymbols = 0;
   int totalPositions = 0;
   double totalProfit = 0;
   
   for(int i = 0; i < symbolCount; i++)
   {
      if(traders[i] != NULL)
      {
         int positions = traders[i].GetTotalPositions();
         double profit = traders[i].GetTotalProfit();
         
         if(positions > 0) activeSymbols++;
         totalPositions += positions;
         totalProfit += profit;
      }
   }
   
   string status = "FOREX GLOBAL: ";
   status += "Symbols: " + IntegerToString(activeSymbols) + "/" + IntegerToString(symbolCount);
   status += " | Positions: " + IntegerToString(totalPositions);
   
   if(totalProfit != 0)
   {
      status += " | P/L: " + DoubleToString(totalProfit, 2);
   }
   
   return status;
}
