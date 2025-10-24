//+------------------------------------------------------------------+
//|                                        ForexSymbolManager.mqh    |
//|                Gestionnaire de symboles multi-trading Forex     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../../EA/Shared/TradingUtils.mqh"
#include "../../../EA/Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Afficher les informations sur les symboles configurés           |
//+------------------------------------------------------------------+
void PrintSymbolsInfo(string &symbolArray[], int baseMagic, ENUM_TIMEFRAMES timeframe, string strategyName = "")
{
   int count = ArraySize(symbolArray);
   
   Logger::Info("═══════════════════════════════════════");
   Logger::Info("🔧 FOREX SYMBOLS CONFIGURATION");
   Logger::Info("═══════════════════════════════════════");
   Logger::Info("Total symbols: " + IntegerToString(count));
   Logger::Info("Strategy: " + strategyName);
   Logger::Info("Timeframe: " + EnumToString(timeframe));
   
   for(int i = 0; i < count; i++)
   {
      string symbol = symbolArray[i];
      
      // Informations sur le symbole
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      Logger::Info("  [" + IntegerToString(i+1) + "] " + symbol + " | Magic: " + IntegerToString(baseMagic));
      Logger::Info("      Point: " + DoubleToString(point, 5) + " | Spread: " + DoubleToString(spread, 0));
      Logger::Info("      Lots: " + DoubleToString(minLot, 2) + " - " + DoubleToString(maxLot, 2));
   }
   
   Logger::Info("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Obtenir les statistiques globales des symboles                  |
//+------------------------------------------------------------------+
string GetGlobalSymbolsStatus(string &symbolArray[], int symbolCount)
{
   int activeSymbols = 0;
   int totalPositions = 0;
   double totalProfit = 0;
   
   // Compter les positions et profits pour tous les symboles
   for(int i = 0; i < symbolCount; i++)
   {
      string symbol = symbolArray[i];
      
      // Compter les positions pour ce symbole
      int symbolPositions = 0;
      double symbolProfit = 0;
      
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong ticket = PositionGetTicket(j);
         if(ticket <= 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) == symbol)
         {
            symbolPositions++;
            symbolProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
      
      if(symbolPositions > 0) activeSymbols++;
      totalPositions += symbolPositions;
      totalProfit += symbolProfit;
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
