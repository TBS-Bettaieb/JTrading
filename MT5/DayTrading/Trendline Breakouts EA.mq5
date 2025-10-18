//+------------------------------------------------------------------+
//|                                   Trendline Breakouts EA.mq5     |
//|                                  Converted from Pine Script      |
//+------------------------------------------------------------------+
#property copyright "Converted to MQL5"
#property version   "1.00"
#property description "Trendline Breakouts With Targets EA"

//--- Input parameters
input group "➞ Core Settings 🔸"
input int      InpPeriod = 10;                    // Period
input bool     InpTrendType = true;               // Type: true=Wicks, false=Body
input int      InpExtension = 25;                 // Extension (25/50/75)
input bool     InpShowTargets = true;             // Show Targets
input color    InpLineColor = clrGray;            // Line Color

//--- Global variables
bool g_TradeIsOn = false;
bool g_LongTrade = false;
bool g_ShortTrade = false;
double g_TP = 0.0;
double g_SL = 0.0;
double g_Zband = 0.0;

// Trendline tracking
int g_UpdatedX = 0;
double g_UpdatedY = 0.0;
double g_UpdatedSlope = 0.0;
int g_UpdatedXLow = 0;
double g_UpdatedYLow = 0.0;
double g_UpdatedSlopeLow = 0.0;

// Previous pivot values
double g_PrevPH = 0.0;
double g_PrevPL = 0.0;

// Object names
string g_TPLineName = "TPLine";
string g_LabelName = "TargetLabel";
int g_ObjectCounter = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up objects
   ObjectsDeleteAll(0, "TBT_");
   ObjectDelete(0, g_TPLineName);
   ObjectDelete(0, g_LabelName);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update Zband
   g_Zband = CalculateZband();
   
   // Calculate pivots
   double ph = PivotHigh(InpTrendType, InpPeriod, InpPeriod / 2);
   double pl = PivotLow(InpTrendType, InpPeriod, InpPeriod / 2);
   
   // Process pivot high trendline
   if(ph != 0.0 && ph != g_PrevPH)
   {
      TrendlineData td = CalculateTrendline(ph, InpPeriod / 2, false);
      g_UpdatedX = td.startBar;
      g_UpdatedY = td.startPrice;
      g_UpdatedSlope = td.slope;
      g_PrevPH = ph;
      
      // Draw trendline
      DrawTrendline(td, false);
   }
   
   // Process pivot low trendline
   if(pl != 0.0 && pl != g_PrevPL)
   {
      TrendlineData td = CalculateTrendline(pl, InpPeriod / 2, true);
      g_UpdatedXLow = td.startBar;
      g_UpdatedYLow = td.startPrice;
      g_UpdatedSlopeLow = td.slope;
      g_PrevPL = pl;
      
      // Draw trendline
      DrawTrendline(td, true);
   }
   
   // Check for signals
   bool longSignal = CheckLongSignal();
   bool shortSignal = CheckShortSignal();
   
   // Process trade signals
   if(longSignal && !g_TradeIsOn)
   {
      g_LongTrade = true;
      g_ShortTrade = false;
      OpenTrade(true);
      DrawSignalArrow(true);
   }
   else if(shortSignal && !g_TradeIsOn)
   {
      g_LongTrade = false;
      g_ShortTrade = true;
      OpenTrade(false);
      DrawSignalArrow(false);
   }
   
   // Manage open trade
   if(g_TradeIsOn)
   {
      ManageTrade();
   }
}

//+------------------------------------------------------------------+
//| Calculate Zband (volatility adjustment)                          |
//+------------------------------------------------------------------+
double CalculateZband()
{
   double atr = iATR(_Symbol, PERIOD_CURRENT, 30);
   double atrValue = 0;
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   int handle = iATR(_Symbol, PERIOD_CURRENT, 30);
   if(handle == INVALID_HANDLE) return 0.01;
   
   if(CopyBuffer(handle, 0, 20, 1, buffer) > 0)
   {
      atrValue = buffer[0];
   }
   IndicatorRelease(handle);
   
   double close_price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double value = MathMin(atrValue * 0.3, close_price * (0.3 / 100.0));
   
   return value / 2.0;
}

//+------------------------------------------------------------------+
//| Structure for trendline data                                     |
//+------------------------------------------------------------------+
struct TrendlineData
{
   int startBar;
   double startPrice;
   double slope;
   datetime startTime;
};

//+------------------------------------------------------------------+
//| Calculate Pivot High                                             |
//+------------------------------------------------------------------+
double PivotHigh(bool useWicks, int leftBars, int rightBars)
{
   if(Bars(_Symbol, PERIOD_CURRENT) < leftBars + rightBars + 1)
      return 0.0;
   
   int centerBar = rightBars;
   double centerValue = useWicks ? iHigh(_Symbol, PERIOD_CURRENT, centerBar) : 
                                   MathMax(iClose(_Symbol, PERIOD_CURRENT, centerBar), 
                                           iOpen(_Symbol, PERIOD_CURRENT, centerBar));
   
   // Check left side
   for(int i = 1; i <= leftBars; i++)
   {
      double value = useWicks ? iHigh(_Symbol, PERIOD_CURRENT, centerBar + i) : 
                                MathMax(iClose(_Symbol, PERIOD_CURRENT, centerBar + i), 
                                        iOpen(_Symbol, PERIOD_CURRENT, centerBar + i));
      if(value >= centerValue)
         return 0.0;
   }
   
   // Check right side
   for(int i = 1; i <= rightBars; i++)
   {
      double value = useWicks ? iHigh(_Symbol, PERIOD_CURRENT, centerBar - i) : 
                                MathMax(iClose(_Symbol, PERIOD_CURRENT, centerBar - i), 
                                        iOpen(_Symbol, PERIOD_CURRENT, centerBar - i));
      if(value > centerValue)
         return 0.0;
   }
   
   return centerValue;
}

//+------------------------------------------------------------------+
//| Calculate Pivot Low                                              |
//+------------------------------------------------------------------+
double PivotLow(bool useWicks, int leftBars, int rightBars)
{
   if(Bars(_Symbol, PERIOD_CURRENT) < leftBars + rightBars + 1)
      return 0.0;
   
   int centerBar = rightBars;
   double centerValue = useWicks ? iLow(_Symbol, PERIOD_CURRENT, centerBar) : 
                                   MathMin(iClose(_Symbol, PERIOD_CURRENT, centerBar), 
                                           iOpen(_Symbol, PERIOD_CURRENT, centerBar));
   
   // Check left side
   for(int i = 1; i <= leftBars; i++)
   {
      double value = useWicks ? iLow(_Symbol, PERIOD_CURRENT, centerBar + i) : 
                                MathMin(iClose(_Symbol, PERIOD_CURRENT, centerBar + i), 
                                        iOpen(_Symbol, PERIOD_CURRENT, centerBar + i));
      if(value <= centerValue)
         return 0.0;
   }
   
   // Check right side
   for(int i = 1; i <= rightBars; i++)
   {
      double value = useWicks ? iLow(_Symbol, PERIOD_CURRENT, centerBar - i) : 
                                MathMin(iClose(_Symbol, PERIOD_CURRENT, centerBar - i), 
                                        iOpen(_Symbol, PERIOD_CURRENT, centerBar - i));
      if(value < centerValue)
         return 0.0;
   }
   
   return centerValue;
}

//+------------------------------------------------------------------+
//| Calculate trendline parameters                                   |
//+------------------------------------------------------------------+
TrendlineData CalculateTrendline(double pivotPrice, int barsAgo, bool isLow)
{
   TrendlineData td;
   td.startBar = barsAgo;
   td.startPrice = pivotPrice;
   td.startTime = iTime(_Symbol, PERIOD_CURRENT, barsAgo);
   
   double currentPrice = isLow ? iLow(_Symbol, PERIOD_CURRENT, 0) : 
                                 iHigh(_Symbol, PERIOD_CURRENT, 0);
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   long timeDiff = (long)(currentTime - td.startTime);
   if(timeDiff != 0)
      td.slope = (currentPrice - td.startPrice) / (double)timeDiff;
   else
      td.slope = 0;
   
   return td;
}

//+------------------------------------------------------------------+
//| Draw trendline on chart                                          |
//+------------------------------------------------------------------+
void DrawTrendline(TrendlineData &td, bool isLow)
{
   if(g_TradeIsOn) return;
   
   string objName = "TBT_Line_" + IntegerToString(g_ObjectCounter++);
   
   datetime startTime = iTime(_Symbol, PERIOD_CURRENT, td.startBar);
   datetime endTime = startTime + InpExtension * PeriodSeconds(PERIOD_CURRENT) * 25;
   
   double endPrice = td.startPrice + (endTime - startTime) * td.slope;
   
   // Check if slope direction is valid for the trade type
   bool validSlope = isLow ? (td.slope >= 0) : (td.slope <= 0);
   if(!validSlope) return;
   
   ObjectCreate(0, objName, OBJ_TREND, 0, startTime, td.startPrice, endTime, endPrice);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, InpLineColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Get line price at current time                                   |
//+------------------------------------------------------------------+
double GetLinePrice(int startBar, double startPrice, double slope)
{
   datetime startTime = iTime(_Symbol, PERIOD_CURRENT, startBar);
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   long timeDiff = (long)(currentTime - startTime);
   
   return startPrice + timeDiff * slope;
}

//+------------------------------------------------------------------+
//| Check for long signal                                            |
//+------------------------------------------------------------------+
bool CheckLongSignal()
{
   if(g_TradeIsOn || g_UpdatedX == 0) return false;
   
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double prevPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   double currentLine = GetLinePrice(g_UpdatedX, g_UpdatedY, g_UpdatedSlope);
   double prevLine = GetLinePrice(g_UpdatedX + 1, g_UpdatedY, g_UpdatedSlope);
   
   // Check for downward slope and crossover
   bool validSlope = (g_UpdatedSlope < 0);
   bool crossover = (prevPrice < prevLine) && (currentPrice > currentLine);
   
   return validSlope && crossover;
}

//+------------------------------------------------------------------+
//| Check for short signal                                           |
//+------------------------------------------------------------------+
bool CheckShortSignal()
{
   if(g_TradeIsOn || g_UpdatedXLow == 0) return false;
   
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double prevPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   double currentLine = GetLinePrice(g_UpdatedXLow, g_UpdatedYLow, g_UpdatedSlopeLow);
   double prevLine = GetLinePrice(g_UpdatedXLow + 1, g_UpdatedYLow, g_UpdatedSlopeLow);
   
   // Check for upward slope and crossunder
   bool validSlope = (g_UpdatedSlopeLow > 0);
   bool crossunder = (prevPrice > prevLine - g_Zband * 0.1) && (currentPrice < currentLine - g_Zband * 0.1);
   
   return validSlope && crossunder;
}

//+------------------------------------------------------------------+
//| Open trade and set targets                                       |
//+------------------------------------------------------------------+
void OpenTrade(bool isLong)
{
   double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double low = iLow(_Symbol, PERIOD_CURRENT, 0);
   
   if(isLong)
   {
      g_TP = high + (g_Zband * 20);
      g_SL = low - (g_Zband * 20);
   }
   else
   {
      g_TP = low - (g_Zband * 20);
      g_SL = high + (g_Zband * 20);
   }
   
   g_TradeIsOn = true;
   
   // Draw target line if enabled
   if(InpShowTargets)
   {
      DrawTargetLine(isLong);
   }
   
   // Here you would place the actual trade
   // For example: OrderSend(...);
   Print("Trade Signal: ", isLong ? "LONG" : "SHORT", " | TP: ", g_TP, " | SL: ", g_SL);
}

//+------------------------------------------------------------------+
//| Draw target line                                                 |
//+------------------------------------------------------------------+
void DrawTargetLine(bool isLong)
{
   datetime time0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   double entryPrice = isLong ? iHigh(_Symbol, PERIOD_CURRENT, 0) : iLow(_Symbol, PERIOD_CURRENT, 0);
   
   // Vertical line to target
   string vertLine = "TBT_Vert_" + IntegerToString(g_ObjectCounter++);
   ObjectCreate(0, vertLine, OBJ_TREND, 0, time0, entryPrice, time0, g_TP);
   ObjectSetInteger(0, vertLine, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, vertLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, vertLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, vertLine, OBJPROP_RAY_RIGHT, false);
   
   // Horizontal target line
   ObjectDelete(0, g_TPLineName);
   ObjectCreate(0, g_TPLineName, OBJ_TREND, 0, time0, g_TP, time0 + PeriodSeconds() * 10, g_TP);
   ObjectSetInteger(0, g_TPLineName, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, g_TPLineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, g_TPLineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, g_TPLineName, OBJPROP_RAY_RIGHT, false);
   
   // Label
   ObjectDelete(0, g_LabelName);
   ObjectCreate(0, g_LabelName, OBJ_TEXT, 0, time0, g_TP);
   ObjectSetString(0, g_LabelName, OBJPROP_TEXT, "Target");
   ObjectSetInteger(0, g_LabelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, g_LabelName, OBJPROP_FONTSIZE, 8);
}

//+------------------------------------------------------------------+
//| Manage open trade                                                |
//+------------------------------------------------------------------+
void ManageTrade()
{
   double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double low = iLow(_Symbol, PERIOD_CURRENT, 0);
   double close = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   // Update target line
   if(InpShowTargets && ObjectFind(0, g_TPLineName) >= 0)
   {
      datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      ObjectSetInteger(0, g_TPLineName, OBJPROP_TIME, 1, currentTime + PeriodSeconds() * 10);
      ObjectSetInteger(0, g_LabelName, OBJPROP_TIME, 0, currentTime + PeriodSeconds() * 5);
   }
   
   // Check for TP or SL hit
   if(g_LongTrade)
   {
      if(high >= g_TP)
      {
         ObjectSetInteger(0, g_LabelName, OBJPROP_COLOR, clrLime);
         Print("Long Trade closed at TP: ", g_TP);
         g_TradeIsOn = false;
      }
      else if(close <= g_SL)
      {
         ObjectSetInteger(0, g_LabelName, OBJPROP_COLOR, clrRed);
         Print("Long Trade closed at SL: ", g_SL);
         g_TradeIsOn = false;
      }
   }
   else if(g_ShortTrade)
   {
      if(low <= g_TP)
      {
         ObjectSetInteger(0, g_LabelName, OBJPROP_COLOR, clrLime);
         Print("Short Trade closed at TP: ", g_TP);
         g_TradeIsOn = false;
      }
      else if(close >= g_SL)
      {
         ObjectSetInteger(0, g_LabelName, OBJPROP_COLOR, clrRed);
         Print("Short Trade closed at SL: ", g_SL);
         g_TradeIsOn = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Draw signal arrow                                                |
//+------------------------------------------------------------------+
void DrawSignalArrow(bool isLong)
{
   string arrowName = "TBT_Arrow_" + IntegerToString(g_ObjectCounter++);
   datetime time0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   double price = isLong ? iLow(_Symbol, PERIOD_CURRENT, 0) : iHigh(_Symbol, PERIOD_CURRENT, 0);
   
   ObjectCreate(0, arrowName, isLong ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, time0, price);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isLong ? clrLime : clrRed);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
}
//+------------------------------------------------------------------+