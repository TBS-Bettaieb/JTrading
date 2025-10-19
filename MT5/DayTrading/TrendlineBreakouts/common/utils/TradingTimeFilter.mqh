//+------------------------------------------------------------------+
//| TradingTimeFilter.mqh                                            |
//| Filtre de plage horaire avec format HH:MM et support overnight   |
//| Affichage visuel style MrCapFree                                  |
//+------------------------------------------------------------------+
#property once
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Trading Time Filter Class                                        |
//+------------------------------------------------------------------+
class TradingTimeFilter
{
private:
   bool   m_enabled;
   string m_startTime;      // Format "HH:MM"
   string m_endTime;        // Format "HH:MM"
   int    m_startMinutes;   // Parsed: heures*100 + minutes (ex: 830 = 8h30)
   int    m_endMinutes;     // Parsed: heures*100 + minutes (ex: 1745 = 17h45)
   
   // Logging anti-spam
   int    m_lastLoggedHour;
   int    m_lastLoggedMinute;
   bool   m_lastAlertVisible;
   
   // Line drawing tracking
   datetime m_lastStartLineTime;
   datetime m_lastEndLineTime;
   int      m_lastCheckedStartMinutes;
   int      m_lastCheckedEndMinutes;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TradingTimeFilter()
   {
      m_enabled = false;
      m_startTime = "";
      m_endTime = "";
      m_startMinutes = -1;
      m_endMinutes = -1;
      m_lastLoggedHour = -1;
      m_lastLoggedMinute = -1;
      m_lastAlertVisible = false;
      m_lastStartLineTime = 0;
      m_lastEndLineTime = 0;
      m_lastCheckedStartMinutes = -1;
      m_lastCheckedEndMinutes = -1;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~TradingTimeFilter()
   {
      HideAlert();
      ClearTimeLines();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize filter with start and end times                      |
   //+------------------------------------------------------------------+
   bool Initialize(string startTime, string endTime)
   {
      m_startTime = startTime;
      m_endTime = endTime;
      
      // Parse start time
      m_startMinutes = ParseTimeString(startTime);
      if(m_startMinutes == -1)
      {
         Logger::Error("Invalid start time format: " + startTime + " (expected HH:MM)");
         return false;
      }
      
      // Parse end time
      m_endMinutes = ParseTimeString(endTime);
      if(m_endMinutes == -1)
      {
         Logger::Error("Invalid end time format: " + endTime + " (expected HH:MM)");
         return false;
      }
      
      m_enabled = true;
      
      // Log initialization
      if(m_startMinutes > m_endMinutes)
      {
         Logger::Info("Time Filter: Overnight session " + startTime + " - " + endTime);
      }
      else
      {
         Logger::Info("Time Filter: Same day session " + startTime + " - " + endTime);
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if current time is within trading hours                   |
   //+------------------------------------------------------------------+
   bool IsWithinTradingHours()
   {
      if(!m_enabled || m_startMinutes == -1 || m_endMinutes == -1)
         return true;
      
      // Get current time
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentMinutes = dt.hour * 100 + dt.min;
      
      bool withinHours = false;
      
      // Handle overnight sessions (start > end, e.g., 22:00-02:00)
      if(m_startMinutes > m_endMinutes)
      {
         // Overnight: trading if >= start OR <= end
         withinHours = (currentMinutes >= m_startMinutes || currentMinutes <= m_endMinutes);
      }
      else
      {
         // Same day: trading if >= start AND <= end
         withinHours = (currentMinutes >= m_startMinutes && currentMinutes <= m_endMinutes);
      }
      
      // Check for start/end time transitions and draw lines
      CheckAndDrawTimeLines(dt, currentMinutes);
      
      // Anti-spam logging
      if(!withinHours && (m_lastLoggedHour != dt.hour || m_lastLoggedMinute != dt.min))
      {
         Logger::Debug("Outside trading hours: " + 
                      StringFormat("%02d:%02d (range: %s-%s)", 
                                 dt.hour, dt.min, m_startTime, m_endTime));
         m_lastLoggedHour = dt.hour;
         m_lastLoggedMinute = dt.min;
      }
      
      return withinHours;
   }
   
   //+------------------------------------------------------------------+
   //| Show alert message on chart (style MrCapFree)                  |
   //+------------------------------------------------------------------+
   void ShowAlert(string message)
   {
      // Delete previous alert if exists
      ObjectDelete(0, "Trading_Hour_Alert");
      
      if(message == "") 
      {
         m_lastAlertVisible = false;
         return;
      }
      
      // Create the alert object
      if(!ObjectCreate(0, "Trading_Hour_Alert", OBJ_LABEL, 0, 0, 0))
      {
         Logger::Error("Failed to create trading hour alert object! Error: " + IntegerToString(GetLastError()));
         return;
      }
      
      // Set text properties (copied from MrCapFree)
      ObjectSetString(0, "Trading_Hour_Alert", OBJPROP_TEXT, "• " + message + " •");
      ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_FONTSIZE, 14);
      ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_BGCOLOR, clrNavy);
      ObjectSetString(0, "Trading_Hour_Alert", OBJPROP_FONT, "Arial Black");
      
      // Position at center of chart (copied from MrCapFree)
      int xPos = (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2);
      int yPos = (int)(ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) / 2);
      
      ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_XDISTANCE, xPos);
      ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_BACK, false);
      
      m_lastAlertVisible = true;
      ChartRedraw();
   }
   
   //+------------------------------------------------------------------+
   //| Hide alert message                                              |
   //+------------------------------------------------------------------+
   void HideAlert()
   {
      ObjectDelete(0, "Trading_Hour_Alert");
      m_lastAlertVisible = false;
   }
   
   //+------------------------------------------------------------------+
   //| Update alert display (refresh without recreating)              |
   //+------------------------------------------------------------------+
   void UpdateAlert()
   {
      if(!m_enabled) return;
      
      bool currentlyOutside = !IsWithinTradingHours();
      
      if(currentlyOutside && !m_lastAlertVisible)
      {
         ShowAlert("⏰ TRADING PAUSED - Outside Trading Hours");
      }
      else if(!currentlyOutside && m_lastAlertVisible)
      {
         HideAlert();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get filter status description                                   |
   //+------------------------------------------------------------------+
   string GetStatusDescription()
   {
      if(!m_enabled)
         return "Time Filter: DISABLED";
         
      if(IsWithinTradingHours())
         return "Time Filter: ACTIVE (" + m_startTime + "-" + m_endTime + ")";
      else
         return "Time Filter: BLOCKED (" + m_startTime + "-" + m_endTime + ")";
   }
   
   //+------------------------------------------------------------------+
   //| Check if filter is enabled                                      |
   //+------------------------------------------------------------------+
   bool IsEnabled() const
   {
      return m_enabled;
   }

private:
   //+------------------------------------------------------------------+
   //| Parse time string "HH:MM" to minutes format                    |
   //+------------------------------------------------------------------+
   int ParseTimeString(string timeStr)
   {
      if(timeStr == "" || timeStr == NULL)
         return -1;
      
      int colon = StringFind(timeStr, ":");
      if(colon < 0) return -1;
      
      string hourStr = StringSubstr(timeStr, 0, colon);
      string minStr = StringSubstr(timeStr, colon + 1);
      
      int hour = (int)StringToInteger(hourStr);
      int min = (int)StringToInteger(minStr);
      
      // Validate time
      if(hour < 0 || hour > 23 || min < 0 || min > 59)
         return -1;
      
      return hour * 100 + min;  // 8h30 = 830, 17h45 = 1745
   }
   
   //+------------------------------------------------------------------+
   //| Check for time transitions and draw vertical lines              |
   //+------------------------------------------------------------------+
   void CheckAndDrawTimeLines(MqlDateTime &dt, int currentMinutes)
   {
      if(!m_enabled) return;
      
      datetime currentTime = TimeCurrent();
      
      // Check for start time transition (opening)
      if(ShouldDrawLineForTime(currentMinutes, m_startMinutes, m_lastCheckedStartMinutes))
      {
         DrawVerticalLine("TradingStart_", currentTime, "Trading Start: " + m_startTime);
         m_lastCheckedStartMinutes = currentMinutes;
         Logger::Debug("Trading START line drawn at " + 
                      StringFormat("%02d:%02d", dt.hour, dt.min));
      }
      
      // Check for end time transition (closing)
      if(ShouldDrawLineForTime(currentMinutes, m_endMinutes, m_lastCheckedEndMinutes))
      {
         DrawVerticalLine("TradingEnd_", currentTime, "Trading End: " + m_endTime);
         m_lastCheckedEndMinutes = currentMinutes;
         Logger::Debug("Trading END line drawn at " + 
                      StringFormat("%02d:%02d", dt.hour, dt.min));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if we should draw a line for the target time               |
   //+------------------------------------------------------------------+
   bool ShouldDrawLineForTime(int currentMinutes, int targetMinutes, int lastCheckedMinutes)
   {
      // Don't draw if we already checked this exact minute
      if(lastCheckedMinutes == currentMinutes) return false;
      
      // Draw if current time matches exactly with target time
      if(currentMinutes == targetMinutes)
         return true;
      
      // For overnight sessions, also check if we just passed the target time
      if(m_startMinutes > m_endMinutes && lastCheckedMinutes != -1)
      {
         // Check if we crossed the target time (handles overnight transitions)
         if((lastCheckedMinutes < targetMinutes && currentMinutes >= targetMinutes) ||
            (lastCheckedMinutes >= targetMinutes && currentMinutes < targetMinutes))
         {
            return true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if we crossed a time boundary                             |
   //+------------------------------------------------------------------+
   bool IsTimeTransition(int currentMinutes, int targetMinutes, int lastHour, int lastMinute)
   {
      if(lastHour == -1 || lastMinute == -1) return false;
      
      int lastMinutes = lastHour * 100 + lastMinute;
      
      // We crossed the target time boundary
      if(lastMinutes < targetMinutes && currentMinutes >= targetMinutes)
         return true;
      
      return false;
   }
   
   
   //+------------------------------------------------------------------+
   //| Draw a vertical line on the chart                               |
   //+------------------------------------------------------------------+
   void DrawVerticalLine(string prefix, datetime lineTime, string description)
   {
      MqlDateTime dt;
      TimeToStruct(lineTime, dt);
      string lineName = prefix + TimeToString(lineTime, TIME_DATE) + "_" + 
                       IntegerToString(dt.hour) + "_" + IntegerToString(dt.min);
      
      // Delete existing line if any
      ObjectDelete(0, lineName);
      
      // Create vertical line
      if(ObjectCreate(0, lineName, OBJ_VLINE, 0, lineTime, 0))
      {
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
         ObjectSetString(0, lineName, OBJPROP_TOOLTIP, description);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
         
         Logger::Info("Drew vertical line: " + description);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Clear all time lines from chart                                 |
   //+------------------------------------------------------------------+
   void ClearTimeLines()
   {
      // Clear start lines
      for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, "TradingStart_") == 0 || StringFind(objName, "TradingEnd_") == 0)
         {
            ObjectDelete(0, objName);
         }
      }
   }
};
