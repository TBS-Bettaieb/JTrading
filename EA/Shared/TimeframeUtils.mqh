//+------------------------------------------------------------------+
//| TimeframeUtils.mqh                                              |
//| Classe statique pour les utilitaires de gestion des timeframes |
//+------------------------------------------------------------------+
#property copyright "JTrading"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Classe statique pour les utilitaires de timeframes              |
//+------------------------------------------------------------------+
class TimeframeUtils
{
public:
   //+------------------------------------------------------------------+
   //| Obtenir le timeframe supérieur suivant                          |
   //+------------------------------------------------------------------+
   static ENUM_TIMEFRAMES GetNextHigherTimeframe(ENUM_TIMEFRAMES current)
   {
      switch(current)
      {
         case PERIOD_M1:  return PERIOD_M5;
         case PERIOD_M5:  return PERIOD_M15;
         case PERIOD_M15: return PERIOD_M30;
         case PERIOD_M30: return PERIOD_H1;
         case PERIOD_H1:  return PERIOD_H4;
         case PERIOD_H4:  return PERIOD_D1;
         case PERIOD_D1:  return PERIOD_W1;
         case PERIOD_W1:  return PERIOD_MN1;
         default:         return PERIOD_CURRENT;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le timeframe inférieur précédent                        |
   //+------------------------------------------------------------------+
   static ENUM_TIMEFRAMES GetNextLowerTimeframe(ENUM_TIMEFRAMES current)
   {
      switch(current)
      {
         case PERIOD_MN1: return PERIOD_W1;
         case PERIOD_W1:  return PERIOD_D1;
         case PERIOD_D1:  return PERIOD_H4;
         case PERIOD_H4:  return PERIOD_H1;
         case PERIOD_H1:  return PERIOD_M30;
         case PERIOD_M30: return PERIOD_M15;
         case PERIOD_M15: return PERIOD_M5;
         case PERIOD_M5:  return PERIOD_M1;
         default:         return PERIOD_CURRENT;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nom du timeframe en string                           |
   //+------------------------------------------------------------------+
   static string GetTimeframeName(ENUM_TIMEFRAMES timeframe)
   {
      switch(timeframe)
      {
         case PERIOD_M1:  return "M1";
         case PERIOD_M5:  return "M5";
         case PERIOD_M15: return "M15";
         case PERIOD_M30: return "M30";
         case PERIOD_H1:  return "H1";
         case PERIOD_H4:  return "H4";
         case PERIOD_D1:  return "D1";
         case PERIOD_W1:  return "W1";
         case PERIOD_MN1: return "MN1";
         default:         return "UNKNOWN";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la durée en minutes d'un timeframe                      |
   //+------------------------------------------------------------------+
   static int GetTimeframeMinutes(ENUM_TIMEFRAMES timeframe)
   {
      switch(timeframe)
      {
         case PERIOD_M1:  return 1;
         case PERIOD_M5:  return 5;
         case PERIOD_M15: return 15;
         case PERIOD_M30: return 30;
         case PERIOD_H1:  return 60;
         case PERIOD_H4:  return 240;
         case PERIOD_D1:  return 1440;
         case PERIOD_W1:  return 10080;
         case PERIOD_MN1: return 43200;
         default:         return 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si un timeframe est valide                             |
   //+------------------------------------------------------------------+
   static bool IsValidTimeframe(ENUM_TIMEFRAMES timeframe)
   {
      return (timeframe == PERIOD_M1 || timeframe == PERIOD_M5 || 
              timeframe == PERIOD_M15 || timeframe == PERIOD_M30 ||
              timeframe == PERIOD_H1 || timeframe == PERIOD_H4 ||
              timeframe == PERIOD_D1 || timeframe == PERIOD_W1 ||
              timeframe == PERIOD_MN1);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le timeframe supérieur suivant avec validation          |
   //+------------------------------------------------------------------+
   static ENUM_TIMEFRAMES GetNextHigherTimeframeSafe(ENUM_TIMEFRAMES current)
   {
      if(!IsValidTimeframe(current))
         return PERIOD_CURRENT;
         
      return GetNextHigherTimeframe(current);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le timeframe inférieur précédent avec validation        |
   //+------------------------------------------------------------------+
   static ENUM_TIMEFRAMES GetNextLowerTimeframeSafe(ENUM_TIMEFRAMES current)
   {
      if(!IsValidTimeframe(current))
         return PERIOD_CURRENT;
         
      return GetNextLowerTimeframe(current);
   }
};
