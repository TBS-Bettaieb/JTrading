//+------------------------------------------------------------------+
//| Trendline Breakouts EA.mq5                                       |
//| Modular Architecture - Simplified Main EA                       |
//+------------------------------------------------------------------+
#property copyright "Converted to MQL5"
#property version   "2.00"
#property description "Trendline Breakouts - Modular Architecture"

#include <Trade\Trade.mqh>
#include "common/TrendlineTrader.mqh"

//--- Input parameters
input group "➞ Core Settings 🔸"
input int      InpPeriod = 10;                    // Period
input bool     InpTrendType = true;               // Type: true=Wicks, false=Body
input int      InpExtension = 25;                 // Extension (25/50/75)
input bool     InpShowTargets = true;             // Show Targets
input color    InpLineColor = clrGray;            // Line Color

input group "➞ Trade Settings 🔸"
input double   InpLotSize = 0.01;                 // Lot Size
input int      InpSlippage = 10;                  // Slippage (points)
input int      InpMagicNumber = 12345;            // Magic Number

//--- Global
TrendlineTrader* g_trader = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════");
   Print("🚀 Trendline Breakouts EA v2.0");
   Print("═══════════════════════════════════════");
   
   g_trader = new TrendlineTrader(
      _Symbol, 
      InpMagicNumber,  // ✅ Now configurable
      PERIOD_CURRENT,
      InpPeriod,
      InpTrendType,
      InpExtension,
      InpLotSize,
      InpSlippage,
      InpShowTargets,
      InpLineColor
   );
   
   if(!g_trader.Initialize())
   {
      Print("❌ Failed to initialize trader");
      delete g_trader;
      g_trader = NULL;
      return INIT_FAILED;
   }
   
   Print("✅ Initialization successful");
   Print("═══════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🔄 Shutting down Trendline Breakouts EA");
   
   if(g_trader != NULL)
   {
      delete g_trader;
      g_trader = NULL;
      Print("✅ Cleanup completed");
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_trader != NULL)
      g_trader.OnTick();
}
