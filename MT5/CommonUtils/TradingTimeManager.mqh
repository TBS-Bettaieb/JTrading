//+------------------------------------------------------------------+
//|                                        TradingTimeManager.mqh    |
//|                   Gestionnaire centralisé des filtres temporels   |
//|                   avec affichage visuel des alertes              |
//|                                                                   |
//| VERSION AUTONOME - N'inclut PAS les autres fichiers de filtre    |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ChartManager.mqh AVANT ce fichier                     |
//| 2. N'incluez PAS TimeFilter, TimeRangeFilter, DayRangeFilter     |
//| 3. Ce fichier gère tout en interne                               |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

// Include ChartManager pour utiliser ses méthodes
#include "ChartManager.mqh"

//+------------------------------------------------------------------+
//| Énumération des états du trading                                |
//+------------------------------------------------------------------+
enum ENUM_TRADING_STATUS
{
   TRADING_ACTIVE,           // Trading actif
   TRADING_BLOCKED_HOUR,     // Bloqué par filtre horaire
   TRADING_BLOCKED_DAY,      // Bloqué par filtre jour
   TRADING_BLOCKED_BOTH      // Bloqué par les deux filtres
};

//+------------------------------------------------------------------+
//| Classe de gestion centralisée des filtres temporels             |
//+------------------------------------------------------------------+
class TradingTimeManager
{
private:
   // Configuration des filtres
   bool              m_useTimeFilter;
   string            m_hourRanges;        // Ex: "8-10;16;20-22"
   bool              m_useDayFilter;
   string            m_dayRanges;         // Ex: "1-5;0"
   
   // Chart Manager pour l'affichage
   ChartManager*     m_chartManager;
   
   // Configuration affichage
   bool              m_showVisualAlerts;
   
   // État
   ENUM_TRADING_STATUS m_currentStatus;
   ENUM_TRADING_STATUS m_lastStatus;
   datetime          m_lastAlertTime;
   int               m_lastLoggedHour;
   int               m_lastLoggedDay;
   
   // Messages personnalisés
   string            m_hourBlockMessage;
   string            m_dayBlockMessage;
   string            m_bothBlockMessage;
   
   // Logging
   string            m_logPrefix;
   bool              m_verboseLogging;
   

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TradingTimeManager(ChartManager* chartMgr = NULL)
   {
      m_chartManager = chartMgr;
      
      m_useTimeFilter = false;
      m_hourRanges = "";
      m_useDayFilter = false;
      m_dayRanges = "";
      
      m_showVisualAlerts = true;
      
      m_currentStatus = TRADING_ACTIVE;
      m_lastStatus = TRADING_ACTIVE;
      m_lastAlertTime = 0;
      m_lastLoggedHour = -1;
      m_lastLoggedDay = -1;
      
      m_hourBlockMessage = "⏰ TRADING PAUSED - Outside Trading Hours";
      m_dayBlockMessage = "📅 TRADING PAUSED - Outside Trading Days";
      m_bothBlockMessage = "🚫 TRADING PAUSED - Outside Trading Schedule";
      
      m_logPrefix = "[TradingTimeManager] ";
      m_verboseLogging = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~TradingTimeManager()
   {
      // Ne pas supprimer m_chartManager car il est géré ailleurs
      HideAlert();
   }

   //+------------------------------------------------------------------+
   //| Configuration initiale                                           |
   //+------------------------------------------------------------------+
   void Initialize(
      bool useTimeFilter, 
      string hourRanges,
      bool useDayFilter,
      string dayRanges,
      bool showVisualAlerts = true
   )
   {
      m_useTimeFilter = useTimeFilter;
      m_hourRanges = hourRanges;
      m_useDayFilter = useDayFilter;
      m_dayRanges = dayRanges;
      m_showVisualAlerts = showVisualAlerts;
      
      if(m_verboseLogging)
      {
         Print(m_logPrefix + "Initialized:");
         Print("  Time Filter: ", useTimeFilter ? "ENABLED (" + hourRanges + ")" : "DISABLED");
         Print("  Day Filter: ", useDayFilter ? "ENABLED (" + dayRanges + ")" : "DISABLED");
         Print("  Visual Alerts: ", showVisualAlerts ? "ENABLED" : "DISABLED");
      }
   }

   //+------------------------------------------------------------------+
   //| Attacher un ChartManager                                         |
   //+------------------------------------------------------------------+
   void AttachChartManager(ChartManager* chartMgr)
   {
      m_chartManager = chartMgr;
   }

   //+------------------------------------------------------------------+
   //| Vérification principale du trading                              |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      // Si aucun filtre n'est actif, le trading est toujours autorisé
      if(!m_useTimeFilter && !m_useDayFilter)
      {
         UpdateStatus(TRADING_ACTIVE);
         return true;
      }
      
      // Vérifier les filtres actifs
      bool timeAllowed = true;
      bool dayAllowed = true;
      
      if(m_useTimeFilter)
      {
         timeAllowed = CheckHourAllowed();
      }
      
      if(m_useDayFilter)
      {
         dayAllowed = CheckDayAllowed();
      }
      
      // Déterminer le statut
      ENUM_TRADING_STATUS newStatus;
      
      if(timeAllowed && dayAllowed)
      {
         newStatus = TRADING_ACTIVE;
      }
      else if(!timeAllowed && !dayAllowed)
      {
         newStatus = TRADING_BLOCKED_BOTH;
      }
      else if(!timeAllowed)
      {
         newStatus = TRADING_BLOCKED_HOUR;
      }
      else
      {
         newStatus = TRADING_BLOCKED_DAY;
      }
      
      // Mettre à jour le statut et afficher l'alerte si nécessaire
      UpdateStatus(newStatus);
      
      return (newStatus == TRADING_ACTIVE);
   }

   //+------------------------------------------------------------------+
   //| Vérification rapide sans mise à jour de l'affichage             |
   //+------------------------------------------------------------------+
   bool IsTradingAllowedQuick()
   {
      if(!m_useTimeFilter && !m_useDayFilter)
         return true;
      
      bool timeAllowed = true;
      bool dayAllowed = true;
      
      if(m_useTimeFilter)
         timeAllowed = CheckHourAllowed();
      
      if(m_useDayFilter)
         dayAllowed = CheckDayAllowed();
      
      return (timeAllowed && dayAllowed);
   }

   //+------------------------------------------------------------------+
   //| Obtenir le statut actuel                                        |
   //+------------------------------------------------------------------+
   ENUM_TRADING_STATUS GetCurrentStatus() const
   {
      return m_currentStatus;
   }

   //+------------------------------------------------------------------+
   //| Obtenir une description du statut                               |
   //+------------------------------------------------------------------+
   string GetStatusDescription() const
   {
      switch(m_currentStatus)
      {
         case TRADING_ACTIVE:
            return "Trading Active";
         case TRADING_BLOCKED_HOUR:
            return "Blocked (Time)";
         case TRADING_BLOCKED_DAY:
            return "Blocked (Day)";
         case TRADING_BLOCKED_BOTH:
            return "Blocked (Time & Day)";
         default:
            return "Unknown";
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir des informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo() const
   {
      string info = "=== Trading Time Manager ===\n";
      info += "Status: " + GetStatusDescription() + "\n";
      
      if(m_useTimeFilter)
      {
         info += "Time Filter: Hours: " + m_hourRanges + "\n";
      }
      
      if(m_useDayFilter)
      {
         info += "Day Filter: Days: " + m_dayRanges + "\n";
      }
      
      // Informations actuelles
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      string dayNames[] = {"Dimanche","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi"};
      string currentDay = (dt.day_of_week >= 0 && dt.day_of_week < 7) ? dayNames[dt.day_of_week] : "Unknown";
      
      info += StringFormat("Current: %s %02d:%02d", currentDay, dt.hour, dt.min);
      
      return info;
   }

   //+------------------------------------------------------------------+
   //| Configuration des messages personnalisés                        |
   //+------------------------------------------------------------------+
   void SetAlertMessages(
      string hourBlockMsg = "",
      string dayBlockMsg = "",
      string bothBlockMsg = ""
   )
   {
      if(hourBlockMsg != "") m_hourBlockMessage = hourBlockMsg;
      if(dayBlockMsg != "") m_dayBlockMessage = dayBlockMsg;
      if(bothBlockMsg != "") m_bothBlockMessage = bothBlockMsg;
   }

   //+------------------------------------------------------------------+
   //| Activer/désactiver les alertes visuelles                        |
   //+------------------------------------------------------------------+
   void SetVisualAlerts(bool enabled)
   {
      m_showVisualAlerts = enabled;
      
      // Si on désactive, masquer l'alerte en cours
      if(!enabled)
      {
         HideAlert();
      }
   }

   //+------------------------------------------------------------------+
   //| Activer/désactiver le logging verbeux                           |
   //+------------------------------------------------------------------+
   void SetVerboseLogging(bool enabled)
   {
      m_verboseLogging = enabled;
   }

   //+------------------------------------------------------------------+
   //| Forcer la mise à jour de l'affichage                            |
   //+------------------------------------------------------------------+
   void RefreshDisplay()
   {
      UpdateStatus(m_currentStatus, true);
   }

   //+------------------------------------------------------------------+
   //| Masquer l'alerte manuellement                                   |
   //+------------------------------------------------------------------+
   void HideAlert()
   {
      if(m_chartManager != NULL)
      {
         m_chartManager.HideAlert();
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir l'heure actuelle                                        |
   //+------------------------------------------------------------------+
   int GetCurrentHour()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return dt.hour;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le jour de la semaine actuel                            |
   //+------------------------------------------------------------------+
   int GetCurrentWeekDay()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return dt.day_of_week;
   }

private:
   //+------------------------------------------------------------------+
   //| Vérifier si l'heure actuelle est autorisée                      |
   //+------------------------------------------------------------------+
   bool CheckHourAllowed()
   {
      if(m_hourRanges == "" || m_hourRanges == " ")
         return true;
      
      int currentHour = GetCurrentHour();
      bool allowed = IsHourInRanges(m_hourRanges, currentHour);
      
      if(!allowed && m_lastLoggedHour != currentHour)
      {
         if(m_verboseLogging)
            Print(m_logPrefix + "Heure non autorisée: ", currentHour, ":00 | Ranges: ", m_hourRanges);
         m_lastLoggedHour = currentHour;
      }
      
      return allowed;
   }

   //+------------------------------------------------------------------+
   //| Vérifier si le jour actuel est autorisé                         |
   //+------------------------------------------------------------------+
   bool CheckDayAllowed()
   {
      if(m_dayRanges == "" || m_dayRanges == " ")
         return true;
      
      int currentDay = GetCurrentWeekDay();
      bool allowed = IsDayInRanges(m_dayRanges, currentDay);
      
      if(!allowed && m_lastLoggedDay != currentDay)
      {
         if(m_verboseLogging)
         {
            string dayNames[] = {"Dimanche","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi"};
            string dayName = (currentDay >= 0 && currentDay < 7) ? dayNames[currentDay] : "Unknown";
            Print(m_logPrefix + "Jour non autorisé: ", dayName, " (", currentDay, ") | Ranges: ", m_dayRanges);
         }
         m_lastLoggedDay = currentDay;
      }
      
      return allowed;
   }

   //+------------------------------------------------------------------+
   //| Parsing "8-10;16;20-22" → test d'appartenance                   |
   //+------------------------------------------------------------------+
   bool IsHourInRanges(string ranges, int hour)
   {
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
            // Plage d'heures (ex: "8-10")
            int startH = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endH = (int)StringToInteger(StringSubstr(token, dash + 1));
            
            if(startH <= endH)
            {
               // Plage normale (ex: 8-10)
               if(hour >= startH && hour <= endH) return true;
            }
            else
            {
               // Plage chevauchant minuit (ex: 22-6)
               if(hour >= startH || hour <= endH) return true;
            }
         }
         else
         {
            // Heure exacte (ex: "16")
            int h = (int)StringToInteger(token);
            if(hour == h) return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Parsing "1-5;0" → test d'appartenance (0=Dim .. 6=Sam)         |
   //+------------------------------------------------------------------+
   bool IsDayInRanges(string ranges, int weekday)
   {
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
            // Plage de jours (ex: "1-5")
            int startD = (int)StringToInteger(StringSubstr(token, 0, dash));
            int endD = (int)StringToInteger(StringSubstr(token, dash + 1));
            
            if(startD <= endD)
            {
               // Plage normale (ex: 1-5 = Lundi à Vendredi)
               if(weekday >= startD && weekday <= endD) return true;
            }
            else
            {
               // Plage chevauchant fin de semaine (ex: 5-1 = Vendredi à Lundi)
               if(weekday >= startD || weekday <= endD) return true;
            }
         }
         else
         {
            // Jour exact (ex: "1" = Lundi)
            int d = (int)StringToInteger(token);
            if(weekday == d) return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour le statut et afficher l'alerte si nécessaire      |
   //+------------------------------------------------------------------+
   void UpdateStatus(ENUM_TRADING_STATUS newStatus, bool forceUpdate = false)
   {
      bool statusChanged = (newStatus != m_lastStatus);
      
      // Mettre à jour le statut actuel
      m_currentStatus = newStatus;
      
      // Afficher une alerte si nécessaire
      if(m_showVisualAlerts && m_chartManager != NULL)
      {
         if(newStatus == TRADING_ACTIVE)
         {
            // Si on revient en mode actif, masquer l'alerte
            if(statusChanged)
            {
               m_chartManager.HideAlert();
               
               if(m_verboseLogging)
                  Print(m_logPrefix + "✅ Trading resumed - Filters passed");
            }
         }
         else
         {
            // Afficher l'alerte de blocage
            datetime currentTime = TimeCurrent();
            
            // Mettre à jour l'alerte toutes les 5 minutes ou si le statut change
            if(forceUpdate || statusChanged || (currentTime - m_lastAlertTime) >= 300)
            {
               string alertMessage = GetBlockMessage(newStatus);
               color alertColor = GetBlockColor(newStatus);
               
               m_chartManager.ShowAlert(alertMessage, alertColor, 36);
               m_lastAlertTime = currentTime;
               
               if(m_verboseLogging && statusChanged)
                  Print(m_logPrefix + "🚫 " + alertMessage);
            }
         }
      }
      
      m_lastStatus = newStatus;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le message de blocage approprié                         |
   //+------------------------------------------------------------------+
   string GetBlockMessage(ENUM_TRADING_STATUS status)
   {
      switch(status)
      {
         case TRADING_BLOCKED_HOUR:
            return m_hourBlockMessage;
         case TRADING_BLOCKED_DAY:
            return m_dayBlockMessage;
         case TRADING_BLOCKED_BOTH:
            return m_bothBlockMessage;
         default:
            return "Trading Status Unknown";
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir la couleur de l'alerte selon le statut                  |
   //+------------------------------------------------------------------+
   color GetBlockColor(ENUM_TRADING_STATUS status)
   {
      switch(status)
      {
         case TRADING_BLOCKED_HOUR:
            return clrOrange;
         case TRADING_BLOCKED_DAY:
            return clrYellow;
         case TRADING_BLOCKED_BOTH:
            return clrRed;
         default:
            return clrWhite;
      }
   }
};