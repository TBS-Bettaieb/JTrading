//+------------------------------------------------------------------+
//|                                    RSI_Divergence_EA.mq5        |
//|                         Expert Advisor with RSI Divergences      |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "2.10"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   5

// RSI line
#property indicator_label1  "RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumPurple
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// MA Smoothing
#property indicator_label2  "RSI MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Bollinger Bands
#property indicator_label3  "BB Upper"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLimeGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  "BB Lower"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLimeGreen
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

// Divergence markers
#property indicator_label5  "Divergences"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrWhite
#property indicator_width5  2

//--- Input parameters
input group "═══ Trading Parameters ═══"
input double InpLotSize        = 0.01;      // Lot Size
input double InpRiskPercent    = 0.05;      // SL Risk Percent
input double InpRiskReward     = 1.5;       // Risk:Reward Ratio
input int    InpMagicNumber    = 123456;    // Magic Number
input string InpTradeComment   = "RSI_DIV"; // Trade Comment
input bool   InpEnableTrading  = true;      // Enable Auto Trading

input group "═══ RSI Settings ═══"
input int                InpRSIPeriod        = 14;              // RSI Length
input ENUM_APPLIED_PRICE InpRSIAppliedPrice = PRICE_CLOSE;     // Source

input group "═══ RSI Levels ═══"
input bool   InpShowLevels      = true;      // Show Levels
input double InpUpperLevel      = 70.0;      // Upper Level
input double InpMiddleLevel     = 50.0;      // Middle Level
input double InpLowerLevel      = 30.0;      // Lower Level
input color  InpLevelColor      = clrSilver; // Level Color

input group "═══ Smoothing ═══"
enum MA_TYPE_CUSTOM
{
   MA_NONE,           // None
   MA_SMA,            // SMA
   MA_SMA_BB,         // SMA + Bollinger Bands
   MA_EMA,            // EMA
   MA_SMMA,           // SMMA (RMA)
   MA_LWMA,           // LWMA
};

input MA_TYPE_CUSTOM InpMAType     = MA_NONE;    // MA Type
input int            InpMAPeriod   = 14;         // MA Length
input double         InpBBStdDev   = 2.0;        // BB StdDev

input group "═══ Divergence Settings ═══"
input int    InpLookbackLeft  = 5;      // Lookback Left
input int    InpLookbackRight = 5;      // Lookback Right
input int    InpRangeLower    = 5;      // Range Lower
input int    InpRangeUpper    = 60;     // Range Upper
input bool   InpShowTrendlines = true;  // Show Divergence Trendlines
input color  InpBullishColor  = clrLimeGreen;  // Bullish Divergence Color
input color  InpBearishColor  = clrRed;        // Bearish Divergence Color
input int    InpTrendlineWidth = 2;     // Trendline Width

//--- Indicator buffers
double RSIBuffer[];
double MABuffer[];
double BBUpperBuffer[];
double BBLowerBuffer[];
double DivergenceBuffer[];

// Calculation buffers
double UpBuffer[];
double DownBuffer[];
double StdDevBuffer[];

//--- Global variables
string indicatorPrefix = "RSI_DIV_";
int objectCounter = 0;
datetime lastTradeTime = 0;
bool newBullishDiv = false;
bool newBearishDiv = false;

// Price data arrays
double priceData[];
datetime timeData[];
double highData[];
double lowData[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Check if trading is allowed
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Alert("⚠️ Automated trading is disabled in terminal settings!");
   }
   
   //--- Indicator buffers mapping
   SetIndexBuffer(0, RSIBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, MABuffer, INDICATOR_DATA);
   SetIndexBuffer(2, BBUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BBLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, DivergenceBuffer, INDICATOR_DATA);
   
   SetIndexBuffer(5, UpBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, DownBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, StdDevBuffer, INDICATOR_CALCULATIONS);
   
   //--- Set arrow code for divergences
   PlotIndexSetInteger(4, PLOT_ARROW, 159);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "RSI_EA(" + string(InpRSIPeriod) + ")");
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   //--- Create RSI levels
   if(InpShowLevels)
   {
      IndicatorSetInteger(INDICATOR_LEVELS, 3);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpUpperLevel);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpMiddleLevel);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLowerLevel);
      
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, InpLevelColor);
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, InpLevelColor);
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, InpLevelColor);
      
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 2, STYLE_DOT);
   }
   
   //--- Set array as series
   ArraySetAsSeries(priceData, true);
   ArraySetAsSeries(timeData, true);
   ArraySetAsSeries(highData, true);
   ArraySetAsSeries(lowData, true);
   
   //--- Delete old objects
   DeleteAllObjects();
   
   Print("═══════════════════════════════════════════════");
   Print("✅ RSI Divergence EA Initialized Successfully!");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Auto Trading: ", InpEnableTrading ? "ENABLED" : "DISABLED");
   Print("═══════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllObjects();
   Print("RSI Divergence EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime[1];
   
   if(CopyTime(_Symbol, _Period, 0, 1, currentBarTime) <= 0)
      return;
      
   if(currentBarTime[0] == lastBarTime)
      return;
      
   lastBarTime = currentBarTime[0];
   
   //--- Get price data
   int bars = Bars(_Symbol, _Period);
   if(bars < InpRSIPeriod + InpRangeUpper + 10)
      return;
   
   int copied = CopyClose(_Symbol, _Period, 0, bars, priceData);
   CopyTime(_Symbol, _Period, 0, bars, timeData);
   CopyHigh(_Symbol, _Period, 0, bars, highData);
   CopyLow(_Symbol, _Period, 0, bars, lowData);
   
   if(copied <= 0)
      return;
   
   //--- Calculate RSI and check divergences
   CalculateRSI(copied);
   
   //--- Execute trades if enabled and divergence detected
   if(InpEnableTrading)
   {
      if(newBullishDiv && lastTradeTime != currentBarTime[0])
      {
         OpenBuyTrade();
         newBullishDiv = false;
         lastTradeTime = currentBarTime[0];
      }
      
      if(newBearishDiv && lastTradeTime != currentBarTime[0])
      {
         OpenSellTrade();
         newBearishDiv = false;
         lastTradeTime = currentBarTime[0];
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate RSI and divergences                                    |
//+------------------------------------------------------------------+
void CalculateRSI(int rates_total)
{
   if(rates_total < InpRSIPeriod)
      return;
   
   ArrayResize(RSIBuffer, rates_total);
   ArrayResize(UpBuffer, rates_total);
   ArrayResize(DownBuffer, rates_total);
   ArrayResize(MABuffer, rates_total);
   ArrayResize(BBUpperBuffer, rates_total);
   ArrayResize(BBLowerBuffer, rates_total);
   ArrayResize(DivergenceBuffer, rates_total);
   ArrayResize(StdDevBuffer, rates_total);
   
   ArraySetAsSeries(RSIBuffer, true);
   ArraySetAsSeries(UpBuffer, true);
   ArraySetAsSeries(DownBuffer, true);
   ArraySetAsSeries(MABuffer, true);
   
   //--- Calculate RSI
   for(int i = 0; i < rates_total - 1; i++)
   {
      double change = priceData[i] - priceData[i + 1];
      
      if(i == InpRSIPeriod - 1)
      {
         double sumUp = 0, sumDown = 0;
         for(int j = 0; j < InpRSIPeriod; j++)
         {
            double ch = priceData[j] - priceData[j + 1];
            if(ch > 0) sumUp += ch;
            else sumDown += -ch;
         }
         UpBuffer[i] = sumUp / InpRSIPeriod;
         DownBuffer[i] = sumDown / InpRSIPeriod;
      }
      else if(i > InpRSIPeriod - 1)
      {
         double alpha = 1.0 / InpRSIPeriod;
         UpBuffer[i] = alpha * MathMax(change, 0) + (1 - alpha) * UpBuffer[i + 1];
         DownBuffer[i] = alpha * MathMax(-change, 0) + (1 - alpha) * DownBuffer[i + 1];
      }
      
      if(i >= InpRSIPeriod - 1)
      {
         if(DownBuffer[i] == 0)
            RSIBuffer[i] = 100;
         else if(UpBuffer[i] == 0)
            RSIBuffer[i] = 0;
         else
            RSIBuffer[i] = 100.0 - (100.0 / (1.0 + UpBuffer[i] / DownBuffer[i]));
      }
   }
   
   //--- Calculate MA smoothing
   if(InpMAType != MA_NONE && rates_total > InpRSIPeriod + InpMAPeriod)
   {
      for(int i = 0; i < rates_total - InpRSIPeriod - InpMAPeriod; i++)
      {
         MABuffer[i] = CalculateMA(i, InpMAPeriod, InpMAType);
         
         if(InpMAType == MA_SMA_BB)
         {
            double sum = 0;
            for(int j = 0; j < InpMAPeriod; j++)
            {
               double diff = RSIBuffer[i + j] - MABuffer[i];
               sum += diff * diff;
            }
            StdDevBuffer[i] = MathSqrt(sum / InpMAPeriod);
            
            BBUpperBuffer[i] = MABuffer[i] + InpBBStdDev * StdDevBuffer[i];
            BBLowerBuffer[i] = MABuffer[i] - InpBBStdDev * StdDevBuffer[i];
         }
      }
   }
   
   //--- Check for divergences on closed bar (index 1)
   if(rates_total > InpRangeLower + InpLookbackLeft + InpLookbackRight + 20)
   {
      CheckBullishDivergence(InpLookbackRight + 1);
      CheckBearishDivergence(InpLookbackRight + 1);
   }
}

//+------------------------------------------------------------------+
//| Calculate Moving Average                                          |
//+------------------------------------------------------------------+
double CalculateMA(int pos, int period, MA_TYPE_CUSTOM ma_type)
{
   double sum = 0;
   
   switch(ma_type)
   {
      case MA_SMA:
      case MA_SMA_BB:
         for(int i = 0; i < period; i++)
            sum += RSIBuffer[pos + i];
         return sum / period;
         
      case MA_EMA:
         if(pos >= ArraySize(MABuffer) - period - 1)
         {
            for(int i = 0; i < period; i++)
               sum += RSIBuffer[pos + i];
            return sum / period;
         }
         else
         {
            double alpha = 2.0 / (period + 1.0);
            return alpha * RSIBuffer[pos] + (1 - alpha) * MABuffer[pos + 1];
         }
         
      case MA_SMMA:
         if(pos >= ArraySize(MABuffer) - period - 1)
         {
            for(int i = 0; i < period; i++)
               sum += RSIBuffer[pos + i];
            return sum / period;
         }
         else
         {
            return (MABuffer[pos + 1] * (period - 1) + RSIBuffer[pos]) / period;
         }
         
      case MA_LWMA:
      {
         double weightSum = 0;
         for(int i = 0; i < period; i++)
         {
            int weight = period - i;
            sum += RSIBuffer[pos + i] * weight;
            weightSum += weight;
         }
         return sum / weightSum;
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Check for bullish divergence                                     |
//+------------------------------------------------------------------+
void CheckBullishDivergence(int pos)
{
   if(pos >= ArraySize(RSIBuffer) - InpLookbackLeft - InpRangeUpper)
      return;
      
   bool isPivotLow = true;
   double centerRSI = RSIBuffer[pos];
   
   for(int i = 1; i <= InpLookbackLeft; i++)
   {
      if(RSIBuffer[pos + i] <= centerRSI)
      {
         isPivotLow = false;
         break;
      }
   }
   
   for(int i = 1; i <= InpLookbackRight; i++)
   {
      if(RSIBuffer[pos - i] < centerRSI)
      {
         isPivotLow = false;
         break;
      }
   }
   
   if(!isPivotLow) return;
   
   int prevPivotBar = -1;
   for(int i = pos + InpRangeLower; i <= pos + InpRangeUpper && i < ArraySize(RSIBuffer); i++)
   {
      bool isPrevPivot = true;
      for(int j = 1; j <= InpLookbackLeft && i + j < ArraySize(RSIBuffer); j++)
      {
         if(RSIBuffer[i + j] <= RSIBuffer[i])
         {
            isPrevPivot = false;
            break;
         }
      }
      
      if(isPrevPivot)
      {
         prevPivotBar = i;
         break;
      }
   }
   
   if(prevPivotBar < 0) return;
   
   bool rsiHigherLow = centerRSI > RSIBuffer[prevPivotBar];
   bool priceLowerLow = lowData[pos] < lowData[prevPivotBar];
   
   if(rsiHigherLow && priceLowerLow)
   {
      newBullishDiv = true;
      
      Print("═══════════════════════════════════════════════");
      Print("🟢 BULLISH DIVERGENCE DETECTED!");
      Print("Time: ", TimeToString(timeData[pos], TIME_DATE|TIME_MINUTES));
      Print("Price Low: ", DoubleToString(lowData[prevPivotBar], _Digits), 
            " → ", DoubleToString(lowData[pos], _Digits));
      Print("RSI Low: ", DoubleToString(RSIBuffer[prevPivotBar], 2), 
            " → ", DoubleToString(centerRSI, 2));
      Print("═══════════════════════════════════════════════");
      
      if(InpShowTrendlines)
      {
         DrawRSITrendline(timeData[prevPivotBar], RSIBuffer[prevPivotBar],
                          timeData[pos], centerRSI,
                          InpBullishColor, "BULL");
      }
   }
}

//+------------------------------------------------------------------+
//| Check for bearish divergence                                     |
//+------------------------------------------------------------------+
void CheckBearishDivergence(int pos)
{
   if(pos >= ArraySize(RSIBuffer) - InpLookbackLeft - InpRangeUpper)
      return;
      
   bool isPivotHigh = true;
   double centerRSI = RSIBuffer[pos];
   
   for(int i = 1; i <= InpLookbackLeft; i++)
   {
      if(RSIBuffer[pos + i] >= centerRSI)
      {
         isPivotHigh = false;
         break;
      }
   }
   
   for(int i = 1; i <= InpLookbackRight; i++)
   {
      if(RSIBuffer[pos - i] > centerRSI)
      {
         isPivotHigh = false;
         break;
      }
   }
   
   if(!isPivotHigh) return;
   
   int prevPivotBar = -1;
   for(int i = pos + InpRangeLower; i <= pos + InpRangeUpper && i < ArraySize(RSIBuffer); i++)
   {
      bool isPrevPivot = true;
      for(int j = 1; j <= InpLookbackLeft && i + j < ArraySize(RSIBuffer); j++)
      {
         if(RSIBuffer[i + j] >= RSIBuffer[i])
         {
            isPrevPivot = false;
            break;
         }
      }
      
      if(isPrevPivot)
      {
         prevPivotBar = i;
         break;
      }
   }
   
   if(prevPivotBar < 0) return;
   
   bool rsiLowerHigh = centerRSI < RSIBuffer[prevPivotBar];
   bool priceHigherHigh = highData[pos] > highData[prevPivotBar];
   
   if(rsiLowerHigh && priceHigherHigh)
   {
      newBearishDiv = true;
      
      Print("═══════════════════════════════════════════════");
      Print("🔴 BEARISH DIVERGENCE DETECTED!");
      Print("Time: ", TimeToString(timeData[pos], TIME_DATE|TIME_MINUTES));
      Print("Price High: ", DoubleToString(highData[prevPivotBar], _Digits), 
            " → ", DoubleToString(highData[pos], _Digits));
      Print("RSI High: ", DoubleToString(RSIBuffer[prevPivotBar], 2), 
            " → ", DoubleToString(centerRSI, 2));
      Print("═══════════════════════════════════════════════");
      
      if(InpShowTrendlines)
      {
         DrawRSITrendline(timeData[prevPivotBar], RSIBuffer[prevPivotBar],
                          timeData[pos], centerRSI,
                          InpBearishColor, "BEAR");
      }
   }
}

//+------------------------------------------------------------------+
//| Open Buy Trade                                                    |
//+------------------------------------------------------------------+
void OpenBuyTrade()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double slDistance = price * InpRiskPercent / 100.0;
   double sl = NormalizeDouble(price - slDistance, _Digits);
   double tp = NormalizeDouble(price + (slDistance * InpRiskReward), _Digits);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = InpLotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = InpTradeComment + "_BUY";
   
   if(OrderSend(request, result))
   {
      Print("═══════════════════════════════════════════════");
      Print("✅ BUY ORDER OPENED!");
      Print("Ticket: ", result.order);
      Print("Price: ", price);
      Print("SL: ", sl, " (", DoubleToString(slDistance, _Digits), ")");
      Print("TP: ", tp, " | R:R = 1:", InpRiskReward);
      Print("═══════════════════════════════════════════════");
      
      DrawTradeArrow(timeData[1], lowData[1], 
                     "BUY_" + IntegerToString(result.order), clrLimeGreen, 233);
   }
   else
   {
      Print("❌ Buy order failed! Error: ", GetLastError(), " | ", result.comment);
   }
}

//+------------------------------------------------------------------+
//| Open Sell Trade                                                   |
//+------------------------------------------------------------------+
void OpenSellTrade()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = price * InpRiskPercent / 100.0;
   double sl = NormalizeDouble(price + slDistance, _Digits);
   double tp = NormalizeDouble(price - (slDistance * InpRiskReward), _Digits);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = InpLotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = InpTradeComment + "_SELL";
   
   if(OrderSend(request, result))
   {
      Print("═══════════════════════════════════════════════");
      Print("✅ SELL ORDER OPENED!");
      Print("Ticket: ", result.order);
      Print("Price: ", price);
      Print("SL: ", sl, " (", DoubleToString(slDistance, _Digits), ")");
      Print("TP: ", tp, " | R:R = 1:", InpRiskReward);
      Print("═══════════════════════════════════════════════");
      
      DrawTradeArrow(timeData[1], highData[1], 
                     "SELL_" + IntegerToString(result.order), clrRed, 234);
   }
   else
   {
      Print("❌ Sell order failed! Error: ", GetLastError(), " | ", result.comment);
   }
}

//+------------------------------------------------------------------+
//| Draw trade arrow on main chart                                   |
//+------------------------------------------------------------------+
void DrawTradeArrow(datetime time, double price, string name, color clr, int arrowCode)
{
   string objName = indicatorPrefix + "TRADE_" + name;
   
   if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
   }
}

//+------------------------------------------------------------------+
//| Draw trendline on RSI indicator window                          |
//+------------------------------------------------------------------+
void DrawRSITrendline(datetime time1, double rsi1, datetime time2, double rsi2, 
                      color lineColor, string divType)
{
   objectCounter++;
   string objName = indicatorPrefix + divType + "_" + IntegerToString(objectCounter);
   
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   int subwindow = ChartWindowFind(0, "RSI_EA(" + string(InpRSIPeriod) + ")");
   
   if(ObjectCreate(0, objName, OBJ_TREND, subwindow, time1, rsi1, time2, rsi2))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpTrendlineWidth);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, divType + " Divergence");
   }
}

//+------------------------------------------------------------------+
//| Delete all objects created by this EA                           |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0, -1, -1);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      
      if(StringFind(objName, indicatorPrefix) >= 0)
      {
         ObjectDelete(0, objName);
      }
   }
   
   objectCounter = 0;
}

//+------------------------------------------------------------------+
//| OnCalculate function for indicator display                       |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // This function is called automatically by MT5 for indicator display
   // The actual calculation is done in CalculateRSI() called from OnTick()
   return(rates_total);
}
//+------------------------------------------------------------------+