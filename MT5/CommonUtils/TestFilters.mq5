//+------------------------------------------------------------------+
//|                                                TestFilters.mq5   |
//|                                   Test des nouveaux filtres      |
//|                                                                   |
//+------------------------------------------------------------------+
#property strict

// Inputs pour TimeMinuteFilter
input group "=== Time Minute Filter ==="
input bool UseTimeMinuteFilter = true;
input string TimeMinuteRanges = "8:30-10:45;16:00;20:15-22:30";

// Inputs pour SessionFilter
input group "=== Session Filter ==="
input bool UseSessionFilter = true;
input int AllowedSession = 2;  // SESSION_OVERLAP = 2
input int AvoidOpeningMinutes = 30;

// Includes
#include "TimeMinuteFilter.mqh"
#include "SessionFilter.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== TEST DES NOUVEAUX FILTRES ===");
   
   // Test TimeMinuteFilter
   Print("\n--- Test TimeMinuteFilter ---");
   Print("Configuration: ", TimeMinuteRanges);
   Print("Heure actuelle: ", CurrentHourMinute());
   Print("Trading autorisé: ", IsTimeMinuteAllowed());
   
   // Test SessionFilter
   Print("\n--- Test SessionFilter ---");
   Print("Session autorisée: ", AllowedSession);
   Print("Session actuelle: ", GetCurrentSession());
   Print("Trading autorisé: ", IsSessionAllowed());
   
   // Test des classes
   TimeMinuteFilter timeFilter;
   timeFilter.InitFromInputs(UseTimeMinuteFilter, TimeMinuteRanges);
   Print("TimeMinuteFilter.IsTradingAllowed(): ", timeFilter.IsTradingAllowed());
   
   SessionFilter sessionFilter;
   sessionFilter.InitFromInputs(UseSessionFilter, (ENUM_TRADING_SESSION)AllowedSession, AvoidOpeningMinutes);
   Print("SessionFilter.IsTradingAllowed(): ", sessionFilter.IsTradingAllowed());
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Test toutes les minutes
   static datetime lastTest = 0;
   if(TimeCurrent() - lastTest >= 60) // Test toutes les minutes
   {
      lastTest = TimeCurrent();
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      Print("=== ", dt.hour, ":", (dt.min < 10 ? "0" : ""), dt.min, " ===");
      Print("TimeMinute: ", IsTimeMinuteAllowed());
      Print("Session: ", IsSessionAllowed());
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== FIN DES TESTS ===");
}
