//+------------------------------------------------------------------+
//|                                           ForexTimeFilter.mqh    |
//|                   Filtre horaire et jours pour le Forex         |
//+------------------------------------------------------------------+
#property strict

//---------------------------- Inputs (reusable) ---------------------
// Ces inputs sont exposés à tout EA qui inclut ce fichier
input group "=== Time Filter ==="
input int SHInput = 7;  // Start Hour (0 = Inactive, 1-23 = Active)
input int EHInput = 19;  // End Hour (0 = Inactive, 1-23 = Active)

// Helpers globaux compatibles avec SHInput/EHInput
int ForexCurrentHour()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); return dt.hour;
}

bool ForexIsTradingAllowed()
{
   int h = ForexCurrentHour();
   
   if(SHInput < EHInput) 
   {
      // Plage normale même journée (ex: 8h-17h)
      return (h >= SHInput && h <= EHInput);
   }
   else if(SHInput > EHInput) 
   {
      // Plage overnight traverse minuit (ex: 22h-6h)
      return (h >= SHInput || h <= EHInput);
   }
   else 
   {
      // Pas de filtre ou égalité (SHInput == EHInput)
      return true;
   }
}

//+------------------------------------------------------------------+
//| Classe de gestion des filtres temporels                           |
//+------------------------------------------------------------------+
class ForexTimeFilter
{
private:
   // Configuration
   bool              m_useHourFilter;
   string            m_hourRanges;        // Ex: "8-10;16;20-22"
   bool              m_useDayFilter;
   string            m_dayRanges;         // Ex: "1-5;0"  (0=Dim,1=Lun,..,6=Sam)

   // Logging (anti-spam)
   int               m_lastLoggedHour;
   int               m_lastLoggedDay;
   string            m_logPrefix;
   string            m_lastBlockReason;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   ForexTimeFilter()
   {
      m_useHourFilter = false;
      m_hourRanges = "";
      m_useDayFilter = false;
      m_dayRanges = "";
      m_lastLoggedHour = -1;
      m_lastLoggedDay = -1;
      m_logPrefix = "[ForexTimeFilter] ";
      m_lastBlockReason = "";
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   void SetHourFilter(bool enabled, string ranges)
   {
      m_useHourFilter = enabled;
      m_hourRanges = ranges;
   }

   void SetDayFilter(bool enabled, string ranges)
   {
      m_useDayFilter = enabled;
      m_dayRanges = ranges;
   }

   void SetLogPrefix(string prefix)
   {
      m_logPrefix = prefix;
   }

   // Chargement rapide depuis une configuration simple Start/End hour
   void InitFromSimpleHours(int startHour, int endHour)
   {
      // 0/0 => pas de filtre; seulement start => start-23; seulement end => 0-end
      if(startHour <= 0 && endHour <= 0)
      {
         m_useHourFilter = false;
         m_hourRanges = "";
         return;
      }

      if(startHour > 0 && endHour > 0)
         m_hourRanges = IntegerToString(startHour) + "-" + IntegerToString(endHour);
      else if(startHour > 0)
         m_hourRanges = IntegerToString(startHour) + "-23";
      else // endHour > 0
         m_hourRanges = "0-" + IntegerToString(endHour);

      m_useHourFilter = true;
   }

   // Configuration par structure
   void Configure(bool useHour, string hourRanges, bool useDay, string dayRanges)
   {
      m_useHourFilter = useHour; m_hourRanges = hourRanges;
      m_useDayFilter = useDay;   m_dayRanges = dayRanges;
   }

   //+------------------------------------------------------------------+
   //| Vérifications principales                                       |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      bool hourOk = IsHourAllowed();
      bool dayOk  = IsDayAllowed();
      if(!hourOk)
      {
         m_lastBlockReason = "Hour not allowed";
         return false;
      }
      if(!dayOk)
      {
         m_lastBlockReason = "Day not allowed";
         return false;
      }
      m_lastBlockReason = "";
      return true;
   }

   bool IsHourAllowed()
   {
      if(!m_useHourFilter) return true;

      int currentHour = CurrentHour();
      bool allowed = IsHourAllowedCustom(m_hourRanges, currentHour);

      if(!allowed && m_lastLoggedHour != currentHour)
      {
         Print(m_logPrefix + "Heure non autorisée: ", currentHour, ":00 | Ranges: ", m_hourRanges);
         m_lastLoggedHour = currentHour;
      }

      return allowed;
   }

   bool IsDayAllowed()
   {
      if(!m_useDayFilter) return true;

      int currentDay = CurrentWeekDay();
      bool allowed = IsDayAllowedCustom(m_dayRanges, currentDay);

      if(!allowed && m_lastLoggedDay != currentDay)
      {
         static string dayNames[] = {"Dimanche","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi"};
         Print(m_logPrefix + "Jour non autorisé: ", dayNames[currentDay], " (", currentDay, ") | Ranges: ", m_dayRanges);
         m_lastLoggedDay = currentDay;
      }

      return allowed;
   }

   //+------------------------------------------------------------------+
   //| Helpers publics                                                  |
   //+------------------------------------------------------------------+
   int CurrentHour()
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); return dt.hour;
   }

   int CurrentWeekDay()
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); return dt.day_of_week; // 0..6
   }

   // Raison du blocage lors du dernier appel à IsTradingAllowed()
   string GetLastBlockReason() const
   {
      return m_lastBlockReason;
   }

   // Représentation humaine des plages configurées
   string Describe() const
   {
      string txt = "";
      if(m_useHourFilter)  txt += "Hours: " + m_hourRanges;
      if(m_useDayFilter)   txt += (txt==""?"":" | ") + "Days: " + m_dayRanges;
      if(txt=="") txt = "No time filters";
      return txt;
   }

private:
   //+------------------------------------------------------------------+
   //| Parsing "8-10;16;20-22" → test d'appartenance                   |
   //+------------------------------------------------------------------+
   bool IsHourAllowedCustom(string ranges, int hour)
   {
      if(ranges == "" ) return true; // rien => tout autorisé

      string tokens[]; int n = StringSplit(ranges, ';', tokens);
      for(int i=0;i<n;i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         if(token == "") continue;

         int dash = StringFind(token, "-");
         if(dash >= 0)
         {
            int startH = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endH   = (int)StringToInteger(StringSubstr(token, dash+1));
            if(startH <= endH)
            {
               if(hour >= startH && hour <= endH) return true;
            }
            else
            {
               // plage chevauchant minuit, ex: 22-2
               if(hour >= startH || hour <= endH) return true;
            }
         }
         else
         {
            int h = (int)StringToInteger(token);
            if(hour == h) return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Parsing "1-5;0" → test d'appartenance (0=Dim .. 6=Sam)         |
   //+------------------------------------------------------------------+
   bool IsDayAllowedCustom(string ranges, int weekday)
   {
      if(ranges == "") return true;

      string tokens[]; int n = StringSplit(ranges, ';', tokens);
      for(int i=0;i<n;i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         if(token == "") continue;

         int dash = StringFind(token, "-");
         if(dash >= 0)
         {
            int startD = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endD   = (int)StringToInteger(StringSubstr(token, dash+1));
            if(startD <= endD)
            {
               if(weekday >= startD && weekday <= endD) return true;
            }
            else
            {
               // plage chevauchant fin de semaine, ex: 5-1 (Vendredi à Lundi)
               if(weekday >= startD || weekday <= endD) return true;
            }
         }
         else
         {
            int d = (int)StringToInteger(token);
            if(weekday == d) return true;
         }
      }
      return false;
   }
};
