//+------------------------------------------------------------------+
//|                                          TimeMinuteFilter.mqh    |
//|                   Filtre par plages heure:minute pour le trading |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Dans votre fichier .mq5 principal, ajoutez ces inputs :       |
//|    input group "=== Time Minute Filter ==="                      |
//|    input bool UseTimeMinuteFilter = true;                        |
//|    input string TimeMinuteRanges = "8:30-10:45;16:00;20:15-22:30"; |
//|                                                                   |
//| 2. Incluez ce fichier : #include "../CommonUtils/TimeMinuteFilter.mqh" |
//|                                                                   |
//| 3. Utilisez les fonctions :                                       |
//|    - IsTimeMinuteAllowed() : utilise UseTimeMinuteFilter/TimeMinuteRanges |
//|    - IsTimeMinuteAllowed(enabled, ranges) : paramètres explicites |
//|    - CurrentHourMinute() : heure:minute actuelle (ex: 845 pour 8h45) |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - TimeMinuteRanges="8:30-10:45" : trading de 8h30 à 10h45        |
//| - TimeMinuteRanges="22:30-2:15" : trading overnight de 22h30 à 2h15 |
//| - TimeMinuteRanges="9:00;14:30;20:15" : trading aux moments exacts |
//| - TimeMinuteRanges="9:00-11:30;14:00-16:30" : deux sessions      |
//+------------------------------------------------------------------+
#property strict

//---------------------------- Inputs (reusable) ---------------------
// ATTENTION DEVELOPPEUR : Pour utiliser ce TimeMinuteFilter dans votre EA, 
// vous devez AJOUTER ces inputs dans votre fichier .mq5 principal :
//
// input group "=== Time Minute Filter ==="
// input bool UseTimeMinuteFilter = true;                    // Activer filtre heure:minute
// input string TimeMinuteRanges = "8:30-10:45;16:00;20:15-22:30"; // Plages heure:minute
//
// Ces inputs ne peuvent PAS être définis dans un fichier .mqh (include)
// Ils doivent être dans le fichier .mq5 principal de votre EA.
//
// Exemple d'utilisation dans votre EA :
// 1. Ajoutez les inputs ci-dessus dans votre .mq5
// 2. Incluez ce fichier : #include "../CommonUtils/TimeMinuteFilter.mqh"
// 3. Utilisez les fonctions : IsTimeMinuteAllowed(), CurrentHourMinute(), etc.
//
// Ces variables sont commentées ici car elles causeraient des erreurs de compilation
// si définies dans un fichier include (.mqh)
// input group "=== Time Minute Filter ==="
// input bool UseTimeMinuteFilter = true;                    // Activer filtre heure:minute
// input string TimeMinuteRanges = "8:30-10:45;16:00;20:15-22:30"; // Plages heure:minute

//+------------------------------------------------------------------+
//| Helpers globaux - Fonctions utilitaires                         |
//+------------------------------------------------------------------+
int CurrentHourMinute()
{
   MqlDateTime dt; 
   TimeToStruct(TimeCurrent(), dt); 
   return dt.hour * 100 + dt.min; // Ex: 8h45 = 845
}

//+------------------------------------------------------------------+
//| Fonction helper globale pour parsing des plages heure:minute    |
//+------------------------------------------------------------------+
bool IsTimeMinuteInRangesGlobal(string ranges, int currentTimeMinute)
{
   if(ranges == "" || ranges == " ") return true; // rien => tout autorisé

   string tokens[]; 
   int n = StringSplit(ranges, ';', tokens);
   
   for(int i = 0; i < n; i++)
   {
      string token = tokens[i];
      StringTrimLeft(token);
      StringTrimRight(token);
      if(token == "") continue;

      int dash = StringFind(token, "-");
      if(dash >= 0)
      {
         // Plage d'heures:minutes (ex: "8:30-10:45")
         string startTime = StringSubstr(token, 0, dash);
         string endTime = StringSubstr(token, dash + 1);
         
         int startTimeMinute = ParseTimeMinuteGlobal(startTime);
         int endTimeMinute = ParseTimeMinuteGlobal(endTime);
         
         if(startTimeMinute == -1 || endTimeMinute == -1) continue; // Format invalide
         
         if(startTimeMinute <= endTimeMinute)
         {
            // Plage normale (ex: 8:30-10:45)
            if(currentTimeMinute >= startTimeMinute && currentTimeMinute <= endTimeMinute) 
               return true;
         }
         else
         {
            // Plage chevauchant minuit (ex: 22:30-2:15)
            if(currentTimeMinute >= startTimeMinute || currentTimeMinute <= endTimeMinute) 
               return true;
         }
      }
      else
      {
         // Moment exact (ex: "16:00")
         int timeMinute = ParseTimeMinuteGlobal(token);
         if(timeMinute != -1 && currentTimeMinute == timeMinute) 
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Fonction helper globale pour conversion "8:30" → 830            |
//+------------------------------------------------------------------+
int ParseTimeMinuteGlobal(string time)
{
   int colon = StringFind(time, ":");
   if(colon < 0) return -1; // Format invalide
   
   int hour = (int)StringToInteger(StringSubstr(time, 0, colon));
   int minute = (int)StringToInteger(StringSubstr(time, colon + 1));
   
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59) return -1;
   
   return hour * 100 + minute;
}

//+------------------------------------------------------------------+
//| Fonction principale de vérification par plages heure:minute     |
//| IMPORTANT: Cette fonction utilise les variables UseTimeMinuteFilter |
//| et TimeMinuteRanges qui doivent être définies dans le fichier .mq5 |
//+------------------------------------------------------------------+
bool IsTimeMinuteAllowed()
{
   // Si le filtre est désactivé, autoriser le trading
   if(!UseTimeMinuteFilter) return true;
   
   int currentTimeMinute = CurrentHourMinute();
   return IsTimeMinuteInRangesGlobal(TimeMinuteRanges, currentTimeMinute);
}

//+------------------------------------------------------------------+
//| Fonction alternative avec paramètres explicites                 |
//| Utilisez cette fonction si vous préférez passer les paramètres  |
//| directement plutôt que d'utiliser les inputs globaux            |
//+------------------------------------------------------------------+
bool IsTimeMinuteAllowed(bool useFilter, string timeMinuteRanges)
{
   // Si le filtre est désactivé, autoriser le trading
   if(!useFilter) return true;
   
   int currentTimeMinute = CurrentHourMinute();
   return IsTimeMinuteInRangesGlobal(timeMinuteRanges, currentTimeMinute);
}

//+------------------------------------------------------------------+
//| Classe de gestion des filtres par plages heure:minute           |
//+------------------------------------------------------------------+
class TimeMinuteFilter
{
private:
   // Configuration
   bool              m_useFilter;
   string            m_timeMinuteRanges;    // Ex: "8:30-10:45;16:00;20:15-22:30"
   
   // Logging (anti-spam)
   int               m_lastLoggedHour;
   int               m_lastLoggedMinute;
   string            m_logPrefix;
   string            m_lastBlockReason;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TimeMinuteFilter()
   {
      m_useFilter = false;
      m_timeMinuteRanges = "";
      m_lastLoggedHour = -1;
      m_lastLoggedMinute = -1;
      m_logPrefix = "[TimeMinuteFilter] ";
      m_lastBlockReason = "";
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   void SetFilter(bool enabled, string ranges)
   {
      m_useFilter = enabled;
      m_timeMinuteRanges = ranges;
   }

   void SetLogPrefix(string prefix)
   {
      m_logPrefix = prefix;
   }

   // Chargement rapide depuis une configuration simple
   void InitFromInputs(bool useFilter, string timeMinuteRanges)
   {
      m_useFilter = useFilter;
      m_timeMinuteRanges = timeMinuteRanges;
   }

   //+------------------------------------------------------------------+
   //| Vérifications principales                                       |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      if(!m_useFilter) return true;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentTimeMinute = dt.hour * 100 + dt.min;
      bool allowed = IsTimeMinuteInRangesGlobal(m_timeMinuteRanges, currentTimeMinute);

      // Logging anti-spam : une fois par minute seulement
      if(!allowed && (m_lastLoggedHour != dt.hour || m_lastLoggedMinute != dt.min))
      {
         Print(m_logPrefix + "Heure non autorisée: ", dt.hour, ":", 
               (dt.min < 10 ? "0" : ""), dt.min, " | Ranges: ", m_timeMinuteRanges);
         m_lastLoggedHour = dt.hour;
         m_lastLoggedMinute = dt.min;
         m_lastBlockReason = "Time not in allowed ranges";
      }
      else if(allowed)
      {
         m_lastBlockReason = "";
      }

      return allowed;
   }

   //+------------------------------------------------------------------+
   //| Helpers publics                                                  |
   //+------------------------------------------------------------------+
   int CurrentHourMinute()
   {
      MqlDateTime dt; 
      TimeToStruct(TimeCurrent(), dt); 
      return dt.hour * 100 + dt.min;
   }

   // Raison du blocage lors du dernier appel à IsTradingAllowed()
   string GetLastBlockReason() const
   {
      return m_lastBlockReason;
   }

   // Représentation humaine des plages configurées
   string Describe() const
   {
      if(!m_useFilter) return "Time minute filter disabled";
      return "Time ranges: " + m_timeMinuteRanges;
   }

   // Obtenir les plages heure:minute configurées
   string GetTimeMinuteRanges() const
   {
      return m_timeMinuteRanges;
   }

   // Vérifier si le filtre est activé
   bool IsEnabled() const
   {
      return m_useFilter;
   }

private:
};
