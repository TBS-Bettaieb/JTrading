//+------------------------------------------------------------------+
//| TrendlineManager.mqh                                             |
//| Draw and manage trendline objects on chart                      |
//+------------------------------------------------------------------+
#property once
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "../detectors/TrendlineDetector.mqh"
#include "../utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Trendline manager class                                          |
//+------------------------------------------------------------------+
class TrendlineManager
{
private:
   string m_symbol;
   int m_extension;
   color m_lineColor;
   int m_objectCounter;
   
   // Object names for SL/TP lines
   string m_slLineName;
   string m_tpLineName;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TrendlineManager(string symbol, int extension, color lineColor)
   {
      m_symbol = symbol;
      m_extension = extension;
      m_lineColor = lineColor;
      m_objectCounter = 0;
      
      m_slLineName = "TBT_SL_Line";
      m_tpLineName = "TBT_TP_Line";
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~TrendlineManager()
   {
      ClearAllObjects();
   }

   //+------------------------------------------------------------------+
   //| Draw upper trendline (resistance)                               |
   //+------------------------------------------------------------------+
   void DrawUpperTrendline(TrendlineData& td)
   {
      if(!td.isValid) return;
      
      string objName = "TBT_Upper_" + IntegerToString(m_objectCounter++);
      
      datetime startTime = iTime(m_symbol, PERIOD_CURRENT, td.startBar);
      datetime endTime = startTime + m_extension * PeriodSeconds(PERIOD_CURRENT) * 25;
      
      double endPrice = td.startPrice + (endTime - startTime) * td.slope;
      
      ObjectCreate(0, objName, OBJ_TREND, 0, startTime, td.startPrice, endTime, endPrice);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, m_lineColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      
      Logger::Debug("Upper trendline drawn: " + objName);
   }

   //+------------------------------------------------------------------+
   //| Draw lower trendline (support)                                  |
   //+------------------------------------------------------------------+
   void DrawLowerTrendline(TrendlineData& td)
   {
      if(!td.isValid) return;
      
      string objName = "TBT_Lower_" + IntegerToString(m_objectCounter++);
      
      datetime startTime = iTime(m_symbol, PERIOD_CURRENT, td.startBar);
      datetime endTime = startTime + m_extension * PeriodSeconds(PERIOD_CURRENT) * 25;
      
      double endPrice = td.startPrice + (endTime - startTime) * td.slope;
      
      ObjectCreate(0, objName, OBJ_TREND, 0, startTime, td.startPrice, endTime, endPrice);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, m_lineColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      
      Logger::Debug("Lower trendline drawn: " + objName);
   }

   //+------------------------------------------------------------------+
   //| Draw SL and TP lines when trade opens                          |
   //+------------------------------------------------------------------+
   void DrawSLTPLines(double sl, double tp)
   {
      datetime time0 = iTime(m_symbol, PERIOD_CURRENT, 0);
      datetime timeEnd = time0 + PeriodSeconds(PERIOD_CURRENT) * 50;
      
      // Draw SL Line (Red)
      ObjectDelete(0, m_slLineName);
      ObjectCreate(0, m_slLineName, OBJ_TREND, 0, time0, sl, timeEnd, sl);
      ObjectSetInteger(0, m_slLineName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, m_slLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, m_slLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, m_slLineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, m_slLineName, OBJPROP_BACK, false);
      
      // Draw TP Line (Green)
      ObjectDelete(0, m_tpLineName);
      ObjectCreate(0, m_tpLineName, OBJ_TREND, 0, time0, tp, timeEnd, tp);
      ObjectSetInteger(0, m_tpLineName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, m_tpLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, m_tpLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, m_tpLineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, m_tpLineName, OBJPROP_BACK, false);
      
      Logger::Info("SL/TP lines drawn | SL: " + DoubleToString(sl) + " | TP: " + DoubleToString(tp));
   }

   //+------------------------------------------------------------------+
   //| Update SL/TP line positions                                     |
   //+------------------------------------------------------------------+
   void UpdateSLTPLines(double sl, double tp)
   {
      if(ObjectFind(0, m_slLineName) >= 0)
      {
         datetime currentTime = iTime(m_symbol, PERIOD_CURRENT, 0);
         datetime timeEnd = currentTime + PeriodSeconds(PERIOD_CURRENT) * 50;
         
         ObjectSetInteger(0, m_slLineName, OBJPROP_TIME, 1, timeEnd);
         ObjectSetInteger(0, m_tpLineName, OBJPROP_TIME, 1, timeEnd);
      }
   }

   //+------------------------------------------------------------------+
   //| Clear SL/TP lines                                               |
   //+------------------------------------------------------------------+
   void ClearSLTPLines()
   {
      ObjectDelete(0, m_slLineName);
      ObjectDelete(0, m_tpLineName);
      Logger::Debug("SL/TP lines cleared");
   }

   //+------------------------------------------------------------------+
   //| Draw signal arrow                                               |
   //+------------------------------------------------------------------+
   void DrawSignalArrow(bool isLong, datetime time, double price)
   {
      string arrowName = "TBT_Arrow_" + IntegerToString(m_objectCounter++);
      
      ObjectCreate(0, arrowName, isLong ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, time, price);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isLong ? clrLime : clrRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
      
      Logger::Signal(isLong, "Signal arrow drawn");
   }

   //+------------------------------------------------------------------+
   //| Draw target projection line (optional)                          |
   //+------------------------------------------------------------------+
   void DrawTargetLine(bool isLong, double entry, double tp)
   {
      datetime time0 = iTime(m_symbol, PERIOD_CURRENT, 0);
      
      // Vertical line from entry to target
      string vertLine = "TBT_Target_" + IntegerToString(m_objectCounter++);
      ObjectCreate(0, vertLine, OBJ_TREND, 0, time0, entry, time0, tp);
      ObjectSetInteger(0, vertLine, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, vertLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, vertLine, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, vertLine, OBJPROP_RAY_RIGHT, false);
      
      // Horizontal target line
      string horizLine = "TBT_TargetH_" + IntegerToString(m_objectCounter++);
      datetime timeEnd = time0 + PeriodSeconds(PERIOD_CURRENT) * 10;
      ObjectCreate(0, horizLine, OBJ_TREND, 0, time0, tp, timeEnd, tp);
      ObjectSetInteger(0, horizLine, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, horizLine, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, horizLine, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, horizLine, OBJPROP_RAY_RIGHT, false);
      
      // Label
      string labelName = "TBT_Label_" + IntegerToString(m_objectCounter++);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, time0, tp);
      ObjectSetString(0, labelName, OBJPROP_TEXT, "Target");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      
      Logger::Debug("Target projection drawn");
   }

   //+------------------------------------------------------------------+
   //| Clear all trendline objects                                     |
   //+------------------------------------------------------------------+
   void ClearTrendlines()
   {
      ObjectsDeleteAll(0, "TBT_Upper_");
      ObjectsDeleteAll(0, "TBT_Lower_");
      Logger::Debug("Trendlines cleared");
   }

   //+------------------------------------------------------------------+
   //| Clear all objects created by this manager                       |
   //+------------------------------------------------------------------+
   void ClearAllObjects()
   {
      ObjectsDeleteAll(0, "TBT_");
      ObjectDelete(0, m_slLineName);
      ObjectDelete(0, m_tpLineName);
      Logger::Debug("All TBT objects cleared");
   }

   //+------------------------------------------------------------------+
   //| Reset object counter                                            |
   //+------------------------------------------------------------------+
   void ResetCounter()
   {
      m_objectCounter = 0;
   }
};
