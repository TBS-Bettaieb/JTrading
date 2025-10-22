//+------------------------------------------------------------------+
//|                                    FVG_Volume_Profile_CP.mq5      |
//|                        Converted from TradingView Pine Script     |
//|                   Original: FVG Volume Profile by ChartPrime      |
//+------------------------------------------------------------------+
#property copyright "Converted from Pine Script - Mozilla Public License 2.0"
#property link      "https://mozilla.org/MPL/2.0/"
#property version   "1.01"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input group "Volume DATA"
input bool     InpAutoTf = true;                    // Auto Timeframe
input ENUM_TIMEFRAMES InpCustomTf = PERIOD_M10;     // Custom Timeframe
input group "FVG Volume Profile"
input bool     InpHideVP = true;                    // Display Volume Profile
input int      InpBins = 15;                        // Resolution (Number of Bins)
input double   InpGapFilter = 0.5;                  // Filter Gaps (Minimum Size)
input color    InpBullColor = clrLimeGreen;         // Bullish Color
input color    InpBearColor = clrMagenta;           // Bearish Color
input int      InpMaxFVGs = 10;                     // Maximum FVGs to Display

//--- Structure to hold FVG data
struct FVGData
{
   string   boxName;
   bool     isBull;
   double   upperPrice;
   double   lowerPrice;
   datetime startTime;
   int      startBar;
   double   volumeProfile[];
   string   volumeBoxNames[];
   string   pocLineName;
   string   pocLabelName;
   double   pocPrice;
   double   totalVolume;
   bool     isActive;
};

//--- Global variables
FVGData g_fvgs[];
int g_fvgCount = 0;
ENUM_TIMEFRAMES g_calcTimeframe;
int g_objectCounter = 0;
int g_lastProcessedBar = -1;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Determine calculation timeframe
   if(InpAutoTf)
   {
      int currentTfSeconds = PeriodSeconds();
      g_calcTimeframe = GetLowerTimeframe(currentTfSeconds);
   }
   else
   {
      g_calcTimeframe = InpCustomTf;
   }
   
   // Validate timeframe
   if(PeriodSeconds(g_calcTimeframe) >= PeriodSeconds())
   {
      string msg = "⚠️ Warning: Use Lower Timeframes or enable 'Auto mode'";
      Comment(msg);
      Print(msg);
   }
   else
   {
      string msg = "FVG Volume Profile loaded. Lower TF: " + EnumToString(g_calcTimeframe);
      Comment(msg);
      Print(msg);
   }
   
   ArrayResize(g_fvgs, 100); // Capacité pour 100 FVGs
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Delete all created objects
   ObjectsDeleteAll(0, "FVG_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   
   if(rates_total < 5) return(0);
   
   // Détecter les nouveaux FVG seulement sur nouvelle barre
   int currentBar = Bars(_Symbol, _Period);
   if(currentBar != g_lastProcessedBar)
   {
      g_lastProcessedBar = currentBar;
      
      // Scanner les 50 dernières barres pour détecter tous les FVG
      int barsToScan = MathMin(50, rates_total - 3);
      for(int i = 1; i < barsToScan; i++)
      {
         DetectFairValueGap(time, high, low, i);
      }
   }
   
   // Update existing FVGs
   UpdateFVGDisplay(time);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Get lower timeframe based on current chart timeframe            |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetLowerTimeframe(int currentSeconds)
{
   int lowerSeconds = currentSeconds / 10;
   
   if(lowerSeconds <= 60) return PERIOD_M1;
   else if(lowerSeconds <= 120) return PERIOD_M2;
   else if(lowerSeconds <= 180) return PERIOD_M3;
   else if(lowerSeconds <= 240) return PERIOD_M4;
   else if(lowerSeconds <= 300) return PERIOD_M5;
   else if(lowerSeconds <= 360) return PERIOD_M6;
   else if(lowerSeconds <= 600) return PERIOD_M10;
   else if(lowerSeconds <= 720) return PERIOD_M12;
   else if(lowerSeconds <= 900) return PERIOD_M15;
   else if(lowerSeconds <= 1200) return PERIOD_M20;
   else if(lowerSeconds <= 1800) return PERIOD_M30;
   else if(lowerSeconds <= 3600) return PERIOD_H1;
   else if(lowerSeconds <= 7200) return PERIOD_H2;
   else if(lowerSeconds <= 10800) return PERIOD_H3;
   else if(lowerSeconds <= 14400) return PERIOD_H4;
   else if(lowerSeconds <= 21600) return PERIOD_H6;
   else if(lowerSeconds <= 28800) return PERIOD_H8;
   else if(lowerSeconds <= 43200) return PERIOD_H12;
   else return PERIOD_D1;
}

//+------------------------------------------------------------------+
//| Calculate standard deviation for gap filter                     |
//+------------------------------------------------------------------+
double CalculateStdDev(const double &high[], const double &low[], int startIdx, int period, bool isBull)
{
   if(period <= 1) return 1.0;
   
   double gaps[];
   ArrayResize(gaps, period);
   
   int count = 0;
   for(int i = startIdx; i < startIdx + period && i < ArraySize(high) - 2; i++)
   {
      if(isBull)
         gaps[count] = low[i] - high[i + 2];
      else
         gaps[count] = low[i + 2] - high[i];
      count++;
   }
   
   if(count < 2) return 1.0;
   
   // Calculate mean
   double sum = 0.0;
   for(int i = 0; i < count; i++)
      sum += gaps[i];
   double mean = sum / count;
   
   // Calculate variance
   sum = 0.0;
   for(int i = 0; i < count; i++)
   {
      double diff = gaps[i] - mean;
      sum += diff * diff;
   }
   
   double stdDev = MathSqrt(sum / count);
   return (stdDev > 0) ? stdDev : 1.0;
}

//+------------------------------------------------------------------+
//| Check if FVG already exists at this location                    |
//+------------------------------------------------------------------+
bool FVGExistsAt(datetime checkTime, double upper, double lower, bool isBull)
{
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(!g_fvgs[i].isActive) continue;
      
      if(g_fvgs[i].isBull == isBull &&
         MathAbs(g_fvgs[i].startTime - checkTime) < PeriodSeconds() * 3 &&
         MathAbs(g_fvgs[i].upperPrice - upper) < _Point * 10 &&
         MathAbs(g_fvgs[i].lowerPrice - lower) < _Point * 10)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gap at specific bar index                     |
//+------------------------------------------------------------------+
void DetectFairValueGap(const datetime &time[], const double &high[], const double &low[], int barIdx)
{
   if(barIdx + 2 >= ArraySize(high)) return;
   
   // Calculate standard deviation for filtering
   double bullStdDev = CalculateStdDev(high, low, barIdx, 200, true);
   double bearStdDev = CalculateStdDev(high, low, barIdx, 200, false);
   
   // Check for bullish FVG (gap between high[barIdx+2] and low[barIdx])
   double bullish_gap = low[barIdx] - high[barIdx + 2];
   double bullish_gap_size = bullish_gap / bullStdDev;
   bool bullish_gap_condition = (low[barIdx] > high[barIdx + 2]) && 
                                 (high[barIdx + 1] > high[barIdx + 2]) && 
                                 (bullish_gap_size > InpGapFilter);
   
   // Check for bearish FVG (gap between low[barIdx+2] and high[barIdx])
   double bearish_gap = low[barIdx + 2] - high[barIdx];
   double bearish_gap_size = bearish_gap / bearStdDev;
   bool bearish_gap_condition = (high[barIdx] < low[barIdx + 2]) && 
                                 (low[barIdx + 1] < low[barIdx + 2]) && 
                                 (bearish_gap_size > InpGapFilter);
   
   // Create bullish FVG
   if(bullish_gap_condition)
   {
      double fvg_upper = low[barIdx];
      double fvg_lower = high[barIdx + 2];
      
      // Vérifier si ce FVG existe déjà
      if(!FVGExistsAt(time[barIdx], fvg_upper, fvg_lower, true))
      {
         CreateNewFVG(time[barIdx], fvg_upper, fvg_lower, true, barIdx);
      }
   }
   
   // Create bearish FVG
   if(bearish_gap_condition)
   {
      double fvg_upper = low[barIdx + 2];
      double fvg_lower = high[barIdx];
      
      // Vérifier si ce FVG existe déjà
      if(!FVGExistsAt(time[barIdx], fvg_upper, fvg_lower, false))
      {
         CreateNewFVG(time[barIdx], fvg_upper, fvg_lower, false, barIdx);
      }
   }
}

//+------------------------------------------------------------------+
//| Create new FVG with volume profile                              |
//+------------------------------------------------------------------+
void CreateNewFVG(datetime startTime, double upper, double lower, bool isBull, int barIdx)
{
   // Remove oldest FVG if at maximum
   if(g_fvgCount >= InpMaxFVGs)
   {
      // Find oldest FVG
      int oldestIdx = -1;
      datetime oldestTime = TimeCurrent();
      for(int i = 0; i < g_fvgCount; i++)
      {
         if(g_fvgs[i].isActive && g_fvgs[i].startTime < oldestTime)
         {
            oldestTime = g_fvgs[i].startTime;
            oldestIdx = i;
         }
      }
      
      if(oldestIdx >= 0)
      {
         DeleteFVGObjects(oldestIdx);
         g_fvgs[oldestIdx].isActive = false;
      }
   }
   
   // Find empty slot
   int idx = -1;
   for(int i = 0; i < ArraySize(g_fvgs); i++)
   {
      if(!g_fvgs[i].isActive)
      {
         idx = i;
         break;
      }
   }
   
   if(idx < 0)
   {
      idx = g_fvgCount;
      if(idx >= ArraySize(g_fvgs))
         ArrayResize(g_fvgs, ArraySize(g_fvgs) + 10);
   }
   
   // Initialize new FVG
   g_objectCounter++;
   
   g_fvgs[idx].isBull = isBull;
   g_fvgs[idx].upperPrice = upper;
   g_fvgs[idx].lowerPrice = lower;
   g_fvgs[idx].startTime = startTime;
   g_fvgs[idx].startBar = barIdx;
   g_fvgs[idx].isActive = true;
   g_fvgs[idx].boxName = "FVG_Box_" + IntegerToString(g_objectCounter);
   g_fvgs[idx].pocLineName = "FVG_POC_" + IntegerToString(g_objectCounter);
   g_fvgs[idx].pocLabelName = "FVG_POCLabel_" + IntegerToString(g_objectCounter);
   
   ArrayResize(g_fvgs[idx].volumeProfile, InpBins);
   ArrayResize(g_fvgs[idx].volumeBoxNames, InpBins);
   ArrayInitialize(g_fvgs[idx].volumeProfile, 0.0);
   
   // Calculate volume profile from lower timeframe
   CalculateVolumeProfile(idx, startTime);
   
   // Draw FVG box
   datetime timeRight = TimeCurrent() + PeriodSeconds() * 25;
   color bgColor = isBull ? InpBullColor : InpBearColor;
   
   ObjectCreate(0, g_fvgs[idx].boxName, OBJ_RECTANGLE, 0, startTime, upper, timeRight, lower);
   ObjectSetInteger(0, g_fvgs[idx].boxName, OBJPROP_COLOR, bgColor);
   ObjectSetInteger(0, g_fvgs[idx].boxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_fvgs[idx].boxName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, g_fvgs[idx].boxName, OBJPROP_FILL, true);
   ObjectSetInteger(0, g_fvgs[idx].boxName, OBJPROP_BACK, true);
   ObjectSetInteger(0, g_fvgs[idx].boxName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_fvgs[idx].boxName, OBJPROP_HIDDEN, true);
   
   // Set transparency
   int r = (bgColor & 0xFF);
   int g = ((bgColor >> 8) & 0xFF);
   int b = ((bgColor >> 16) & 0xFF);
   color transparentColor = (color)((int)(255 * 0.3) << 24 | b << 16 | g << 8 | r);
   ObjectSetInteger(0, g_fvgs[idx].boxName, OBJPROP_BGCOLOR, transparentColor);
   
   // Draw volume profile bins
   if(InpHideVP)
   {
      DrawVolumeProfile(idx, startTime, timeRight);
   }
   
   // Draw POC line and label
   DrawPOC(idx, startTime, timeRight);
   
   if(idx >= g_fvgCount)
      g_fvgCount = idx + 1;
      
   Print("FVG Created: ", (isBull ? "BULLISH" : "BEARISH"), 
         " at ", TimeToString(startTime), 
         " | Range: ", DoubleToString(lower, _Digits), " - ", DoubleToString(upper, _Digits),
         " | Volume: ", DoubleToString(g_fvgs[idx].totalVolume, 0));
}

//+------------------------------------------------------------------+
//| Calculate volume profile from lower timeframe data              |
//+------------------------------------------------------------------+
void CalculateVolumeProfile(int fvgIdx, datetime startTime)
{
   double upper = g_fvgs[fvgIdx].upperPrice;
   double lower = g_fvgs[fvgIdx].lowerPrice;
   double binSize = (upper - lower) / InpBins;
   
   if(binSize <= 0) return;
   
   // Get lower timeframe data with more bars
   double ltf_close[];
   long ltf_volume[];
   
   // Request more bars for better volume data
   int barsToRequest = 500;
   datetime timeFrom = startTime - PeriodSeconds(g_calcTimeframe) * barsToRequest;
   datetime timeTo = startTime + PeriodSeconds(g_calcTimeframe) * 100;
   
   int closeCopied = CopyClose(_Symbol, g_calcTimeframe, timeFrom, timeTo, ltf_close);
   int volumeCopied = CopyTickVolume(_Symbol, g_calcTimeframe, timeFrom, timeTo, ltf_volume);
   
   if(closeCopied <= 0 || volumeCopied <= 0)
   {
      Print("Warning: Could not copy lower timeframe data. Close: ", closeCopied, " Volume: ", volumeCopied);
      return;
   }
   
   // Calculate volume for each bin
   g_fvgs[fvgIdx].totalVolume = 0;
   
   for(int k = 0; k < InpBins; k++)
   {
      double binLower = lower + binSize * k;
      double binUpper = binLower + binSize;
      double binMid = binLower + binSize / 2.0;
      
      g_fvgs[fvgIdx].volumeProfile[k] = 0;
      
      for(int i = 0; i < closeCopied; i++)
      {
         // Check if price is within bin range
         if(ltf_close[i] >= binLower && ltf_close[i] <= binUpper)
         {
            g_fvgs[fvgIdx].volumeProfile[k] += (double)ltf_volume[i];
         }
      }
      
      g_fvgs[fvgIdx].totalVolume += g_fvgs[fvgIdx].volumeProfile[k];
   }
   
   // Find POC (Point of Control)
   double maxVol = 0;
   int pocBin = 0;
   for(int k = 0; k < InpBins; k++)
   {
      if(g_fvgs[fvgIdx].volumeProfile[k] > maxVol)
      {
         maxVol = g_fvgs[fvgIdx].volumeProfile[k];
         pocBin = k;
      }
   }
   
   g_fvgs[fvgIdx].pocPrice = lower + binSize * pocBin + binSize / 2.0;
}

//+------------------------------------------------------------------+
//| Draw volume profile histogram                                   |
//+------------------------------------------------------------------+
void DrawVolumeProfile(int fvgIdx, datetime timeLeft, datetime timeRight)
{
   double upper = g_fvgs[fvgIdx].upperPrice;
   double lower = g_fvgs[fvgIdx].lowerPrice;
   double binSize = (upper - lower) / InpBins;
   
   double maxVol = 0;
   for(int k = 0; k < InpBins; k++)
   {
      if(g_fvgs[fvgIdx].volumeProfile[k] > maxVol)
         maxVol = g_fvgs[fvgIdx].volumeProfile[k];
   }
   
   if(maxVol == 0) return;
   
   long timeDiff = timeRight - timeLeft;
   double widthMultiplier = g_fvgs[fvgIdx].isBull ? 50.0 : 40.0;
   
   for(int k = 0; k < InpBins; k++)
   {
      double binLower = lower + binSize * k;
      double binUpper = binLower + binSize;
      
      double volRatio = g_fvgs[fvgIdx].volumeProfile[k] / maxVol;
      long boxWidth = (long)(volRatio * timeDiff / widthMultiplier);
      
      if(boxWidth > 0 && volRatio > 0.01) // Only draw if volume > 1%
      {
         string boxName = "FVG_VolBox_" + IntegerToString(g_objectCounter) + "_" + IntegerToString(k);
         g_fvgs[fvgIdx].volumeBoxNames[k] = boxName;
         
         datetime boxRight = timeLeft + boxWidth;
         
         color boxColor = g_fvgs[fvgIdx].isBull ? InpBullColor : InpBearColor;
         
         // Calculate gradient color
         int transparency = (int)(100.0 - volRatio * 70.0); // 30% to 100% opacity
         int r = (boxColor & 0xFF);
         int g = ((boxColor >> 8) & 0xFF);
         int b = ((boxColor >> 16) & 0xFF);
         int alpha = (int)(255.0 * (100 - transparency) / 100.0);
         color gradientColor = (color)(alpha << 24 | b << 16 | g << 8 | r);
         
         ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, timeLeft, binUpper, boxRight, binLower);
         ObjectSetInteger(0, boxName, OBJPROP_COLOR, boxColor);
         ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 0);
         ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
         ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
         ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, gradientColor);
         ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, boxName, OBJPROP_HIDDEN, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Point of Control (POC) line and label                      |
//+------------------------------------------------------------------+
void DrawPOC(int fvgIdx, datetime timeLeft, datetime timeRight)
{
   double pocPrice = g_fvgs[fvgIdx].pocPrice;
   color pocColor = g_fvgs[fvgIdx].isBull ? InpBullColor : InpBearColor;
   
   // Draw POC line
   ObjectCreate(0, g_fvgs[fvgIdx].pocLineName, OBJ_TREND, 0, timeLeft, pocPrice, timeRight, pocPrice);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLineName, OBJPROP_COLOR, pocColor);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLineName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLineName, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLineName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLineName, OBJPROP_HIDDEN, true);
   
   // Draw POC label with volume
   string volText = FormatVolume(g_fvgs[fvgIdx].totalVolume);
   
   ObjectCreate(0, g_fvgs[fvgIdx].pocLabelName, OBJ_TEXT, 0, timeRight, pocPrice);
   ObjectSetString(0, g_fvgs[fvgIdx].pocLabelName, OBJPROP_TEXT, " " + volText);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLabelName, OBJPROP_COLOR, pocColor);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLabelName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLabelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_fvgs[fvgIdx].pocLabelName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Format volume for display                                       |
//+------------------------------------------------------------------+
string FormatVolume(double volume)
{
   if(volume >= 1000000000)
      return DoubleToString(volume / 1000000000, 2) + "B";
   else if(volume >= 1000000)
      return DoubleToString(volume / 1000000, 2) + "M";
   else if(volume >= 1000)
      return DoubleToString(volume / 1000, 2) + "K";
   else
      return DoubleToString(volume, 0);
}

//+------------------------------------------------------------------+
//| Update FVG display on each tick                                 |
//+------------------------------------------------------------------+
void UpdateFVGDisplay(const datetime &time[])
{
   // Get current Bid and Ask prices
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   datetime currentTime = TimeCurrent();
   datetime timeRight = currentTime + PeriodSeconds() * 25;
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(!g_fvgs[i].isActive) continue;
      
      double upper = g_fvgs[i].upperPrice;
      double lower = g_fvgs[i].lowerPrice;
      bool shouldDelete = false;
      
      // Check if FVG should be deleted (filled)
      if(g_fvgs[i].isBull && currentBid < lower)
      {
         shouldDelete = true;
         Print("Bullish FVG filled at ", TimeToString(currentTime));
      }
      else if(!g_fvgs[i].isBull && currentAsk > upper)
      {
         shouldDelete = true;
         Print("Bearish FVG filled at ", TimeToString(currentTime));
      }
      
      if(shouldDelete)
      {
         DeleteFVGObjects(i);
         g_fvgs[i].isActive = false;
         continue;
      }
      
      // Update object positions
      datetime timeLeft = g_fvgs[i].startTime;
      
      ObjectSetInteger(0, g_fvgs[i].boxName, OBJPROP_TIME, 1, timeRight);
      ObjectSetInteger(0, g_fvgs[i].pocLineName, OBJPROP_TIME, 1, timeRight);
      ObjectSetInteger(0, g_fvgs[i].pocLabelName, OBJPROP_TIME, 0, timeRight);
      
      // Update volume profile boxes
      if(InpHideVP)
      {
         long timeDiff = timeRight - timeLeft;
         double binSize = (upper - lower) / InpBins;
         double maxVol = 0;
         
         for(int k = 0; k < InpBins; k++)
         {
            if(g_fvgs[i].volumeProfile[k] > maxVol)
               maxVol = g_fvgs[i].volumeProfile[k];
         }
         
         if(maxVol > 0)
         {
            double widthMultiplier = g_fvgs[i].isBull ? 50.0 : 40.0;
            
            for(int k = 0; k < InpBins; k++)
            {
               if(g_fvgs[i].volumeBoxNames[k] != "" && ObjectFind(0, g_fvgs[i].volumeBoxNames[k]) >= 0)
               {
                  double volRatio = g_fvgs[i].volumeProfile[k] / maxVol;
                  long boxWidth = (long)(volRatio * timeDiff / widthMultiplier);
                  datetime boxRight2 = timeLeft + boxWidth;
                  
                  ObjectSetInteger(0, g_fvgs[i].volumeBoxNames[k], OBJPROP_TIME, 1, boxRight2);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Delete all objects associated with an FVG                       |
//+------------------------------------------------------------------+
void DeleteFVGObjects(int idx)
{
   if(idx >= ArraySize(g_fvgs)) return;
   
   ObjectDelete(0, g_fvgs[idx].boxName);
   ObjectDelete(0, g_fvgs[idx].pocLineName);
   ObjectDelete(0, g_fvgs[idx].pocLabelName);
   
   for(int k = 0; k < InpBins; k++)
   {
      if(g_fvgs[idx].volumeBoxNames[k] != "")
      {
         ObjectDelete(0, g_fvgs[idx].volumeBoxNames[k]);
      }
   }
}
//+------------------------------------------------------------------+
