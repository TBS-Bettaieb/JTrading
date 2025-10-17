//+------------------------------------------------------------------+
//|                                              TimeFilter.mqh       |
//|                   Filtre horaire et jours pour le trading         |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Dans votre fichier .mq5 principal, ajoutez ces inputs :       |
//|    input group "=== Time Filter ==="                              |
//|    input int SHInput = 7;  // Start Hour (0-23)                  |
//|    input int EHInput = 19; // End Hour (0-23)                     |
//|                                                                   |
//| 2. Incluez ce fichier : #include "../CommonUtils/TimeFilter.mqh"  |
//|                                                                   |
//| 3. Utilisez les fonctions :                                       |
//|    - IsTradingAllowed() : utilise SHInput/EHInput automatiquement |
//|    - IsTradingAllowed(start, end) : paramètres explicites         |
//|    - CurrentHour() : heure actuelle                               |
//|    - TimeFilter class : filtres avancés                          |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - SHInput=7, EHInput=19 : trading de 7h à 19h                    |
//| - SHInput=22, EHInput=6 : trading de 22h à 6h (overnight)        |
//| - SHInput=0, EHInput=0 : pas de filtre horaire                   |
//+------------------------------------------------------------------+
#property strict

//---------------------------- Inputs (reusable) ---------------------
// ATTENTION DEVELOPPEUR : Pour utiliser ce TimeFilter dans votre EA, 
// vous devez AJOUTER ces inputs dans votre fichier .mq5 principal :
//
// input group "=== Time Filter ==="
// input int SHInput = 7;  // Start Hour (0 = Inactive, 1-23 = Active)
// input int EHInput = 19; // End Hour (0 = Inactive, 1-23 = Active)
//
// Ces inputs ne peuvent PAS être définis dans un fichier .mqh (include)
// Ils doivent être dans le fichier .mq5 principal de votre EA.
//
// Exemple d'utilisation dans votre EA :
// 1. Ajoutez les inputs ci-dessus dans votre .mq5
// 2. Incluez ce fichier : #include "../CommonUtils/TimeFilter.mqh"
// 3. Utilisez les fonctions : IsTradingAllowed(), CurrentHour(), etc.
//
// Ces variables sont commentées ici car elles causeraient des erreurs de compilation
// si définies dans un fichier include (.mqh)
// input group "=== Time Filter ==="
// input int SHInput = 7;  // Start Hour (0 = Inactive, 1-23 = Active)
// input int EHInput = 19; // End Hour (0 = Inactive, 1-23 = Active)

//+------------------------------------------------------------------+
//| Helpers globaux - Fonctions utilitaires                         |
//+------------------------------------------------------------------+
int CurrentHour()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); return dt.hour;
}

//+------------------------------------------------------------------+
//| Fonction principale de vérification horaire                     |
//| IMPORTANT: Cette fonction utilise les variables SHInput et EHInput |
//| qui doivent être définies dans le fichier .mq5 principal        |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   int h = CurrentHour();
   
   // Si les deux sont à 0, pas de filtre
   if(SHInput == 0 && EHInput == 0)
   {
      return true;
   }
   
   bool allowed = false;
   
   if(SHInput < EHInput) 
   {
      // Plage normale même journée (ex: 7h-19h)
      allowed = (h >= SHInput && h <= EHInput);
   }
   else if(SHInput > EHInput) 
   {
      // Plage overnight traverse minuit (ex: 22h-6h)
      allowed = (h >= SHInput || h <= EHInput);
   }
   else if(SHInput == EHInput && SHInput > 0)
   {
      // Une seule heure spécifique
      allowed = (h == SHInput);
   }
   
   // Debug: afficher le statut du filtre temps (une fois par heure)
   static int lastDebugHour = -1;
   if(h != lastDebugHour)
   {
      if(allowed)
         Print("✅ TimeFilter: Trading ALLOWED - Current=", h, "h, Range=", SHInput, "h-", EHInput, "h");
      else
         Print("🚫 TimeFilter: Trading BLOCKED - Current=", h, "h, Range=", SHInput, "h-", EHInput, "h");
      lastDebugHour = h;
   }
   
   return allowed;
}

//+------------------------------------------------------------------+
//| Fonction alternative avec paramètres explicites                 |
//| Utilisez cette fonction si vous préférez passer les heures      |
//| directement plutôt que d'utiliser les inputs globaux            |
//+------------------------------------------------------------------+
bool IsTradingAllowed(int startHour, int endHour)
{
   int h = CurrentHour();
   
   if(startHour < endHour) 
   {
      // Plage normale même journée (ex: 8h-17h)
      return (h >= startHour && h <= endHour);
   }
   else if(startHour > endHour) 
   {
      // Plage overnight traverse minuit (ex: 22h-6h)
      return (h >= startHour || h <= endHour);
   }
   else 
   {
      // Pas de filtre ou égalité
      return true;
   }
}

//+------------------------------------------------------------------+
//| Classe de gestion des filtres temporels                           |
//+------------------------------------------------------------------+
class TimeFilter
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
   TimeFilter()
   {
      m_useHourFilter = false;
      m_hourRanges = "";
      m_useDayFilter = false;
      m_dayRanges = "";
      m_lastLoggedHour = -1;
      m_lastLoggedDay = -1;
      m_logPrefix = "[TimeFilter] ";
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
