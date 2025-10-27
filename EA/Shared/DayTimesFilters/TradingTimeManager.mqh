//+------------------------------------------------------------------+
//|                                        TradingTimeManager.mqh    |
//|                   Gestionnaire centralisé des filtres temporels   |
//|                   avec architecture modulaire et filtres NULL-safe |
//|                                                                   |
//| VERSION MODULAIRE - Filtres séparés et initialisation à la carte  |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ChartManager.mqh AVANT ce fichier                     |
//| 2. Initialisez uniquement les filtres nécessaires               |
//| 3. Les filtres NULL sont automatiquement ignorés (sécurité)      |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "2.0"
#property strict

// Include ChartManager pour utiliser ses méthodes
#include "../ChartManager.mqh"

// Include des filtres modulaires - ORDRE IMPORTANT pour les énumérations
#include "SessionFilters/SessionFilter.mqh"     // Doit être en premier pour ENUM_TRADING_SESSION
#include "NewsFilters/NewsFilter.mqh"        // Doit être en deuxième pour ENUM_NEWS_SEPARATOR
#include "TimeFilters/TimeRangeFilter.mqh"
#include "DayFilters/DayRangeFilter.mqh"
#include "TimeFilters/TimeMinuteFilter.mqh"

//+------------------------------------------------------------------+
//| Énumération des états du trading                                |
//+------------------------------------------------------------------+
enum ENUM_TRADING_STATUS
{
   TRADING_ACTIVE,               // Trading actif
   TRADING_BLOCKED_HOUR,         // Bloqué par filtre horaire
   TRADING_BLOCKED_DAY,          // Bloqué par filtre jour
   TRADING_BLOCKED_SESSION,      // Bloqué par filtre session
   TRADING_BLOCKED_NEWS,         // Bloqué par filtre news
   TRADING_BLOCKED_TIME_MINUTE,  // Bloqué par filtre minute
   TRADING_BLOCKED_MULTIPLE,     // Plusieurs filtres bloqués
   TRADING_BLOCKED_BOTH          // Bloqué par les deux filtres (compatibilité)
};

//+------------------------------------------------------------------+
//| Classe de gestion centralisée des filtres temporels             |
//| Architecture modulaire avec filtres NULL-safe                   |
//+------------------------------------------------------------------+
class TradingTimeManager
{
private:
   // Filtres disponibles (NULL si non utilisé)
   TimeRangeFilter*     m_timeRangeFilter;
   DayRangeFilter*      m_dayRangeFilter;
   SessionFilter*       m_sessionFilter;
   NewsFilter*          m_newsFilter;
   TimeMinuteFilter*    m_timeMinuteFilter;
   
   // Paramètres des filtres
   string               m_hourRanges;
   string               m_dayRanges;
   ENUM_TRADING_SESSION m_session;
   int                  m_avoidOpeningMinutes;
   string               m_newsCurrencies;
   string               m_newsKeywords;
   int                  m_newsStopBefore;
   int                  m_newsStartAfter;
   int                  m_newsDaysLookup;
   ENUM_NEWS_SEPARATOR  m_newsSeparator;
   string               m_timeMinuteRanges;
   
   // Chart Manager pour l'affichage
   ChartManager*        m_chartManager;
   
   // Configuration affichage
   bool                 m_showVisualAlerts;
   
   // État
   ENUM_TRADING_STATUS  m_currentStatus;
   ENUM_TRADING_STATUS  m_lastStatus;
   datetime             m_lastAlertTime;
   int                  m_lastLoggedHour;
   int                  m_lastLoggedDay;
   
   // Messages personnalisés
   string               m_hourBlockMessage;
   string               m_dayBlockMessage;
   string               m_bothBlockMessage;
   
   // Logging
   string               m_logPrefix;
   bool                 m_verboseLogging;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TradingTimeManager(ChartManager* chartMgr = NULL)
   {
      // Initialiser tous les filtres à NULL
      m_timeRangeFilter = NULL;
      m_dayRangeFilter = NULL;
      m_sessionFilter = NULL;
      m_newsFilter = NULL;
      m_timeMinuteFilter = NULL;
      
      // Initialiser les paramètres des filtres
      m_hourRanges = "";
      m_dayRanges = "";
      m_session = SESSION_ALL;
      m_avoidOpeningMinutes = 0;
      m_newsCurrencies = "";
      m_newsKeywords = "";
      m_newsStopBefore = 0;
      m_newsStartAfter = 0;
      m_newsDaysLookup = 0;
      m_newsSeparator = NEWS_COMMA;
      m_timeMinuteRanges = "";
      
      m_chartManager = chartMgr;
      
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
      // Nettoyer tous les filtres
      if(m_timeRangeFilter != NULL) { delete m_timeRangeFilter; m_timeRangeFilter = NULL; }
      if(m_dayRangeFilter != NULL) { delete m_dayRangeFilter; m_dayRangeFilter = NULL; }
      if(m_sessionFilter != NULL) { delete m_sessionFilter; m_sessionFilter = NULL; }
      if(m_newsFilter != NULL) { delete m_newsFilter; m_newsFilter = NULL; }
      if(m_timeMinuteFilter != NULL) { delete m_timeMinuteFilter; m_timeMinuteFilter = NULL; }
      
      // Ne pas supprimer m_chartManager car il est géré ailleurs
      HideAlert();
   }

   //+------------------------------------------------------------------+
   //| Configuration initiale (COMPATIBILITÉ DESCENDANTE)              |
   //+------------------------------------------------------------------+
   void Initialize(
      bool useTimeFilter, 
      string hourRanges,
      bool useDayFilter,
      string dayRanges,
      bool showVisualAlerts = true
   )
   {
      // Initialiser TimeRange Filter si demandé
      if(useTimeFilter && hourRanges != "")
      {
         InitTimeRangeFilter(true, hourRanges);
      }
      
      // Initialiser DayRange Filter si demandé
      if(useDayFilter && dayRanges != "")
      {
         InitDayRangeFilter(true, dayRanges);
      }
      
      m_showVisualAlerts = showVisualAlerts;
      
      if(m_verboseLogging)
      {
         Print(m_logPrefix + "Initialized (Legacy Mode):");
         Print("  Time Filter: ", useTimeFilter ? "ENABLED (" + hourRanges + ")" : "DISABLED");
         Print("  Day Filter: ", useDayFilter ? "ENABLED (" + dayRanges + ")" : "DISABLED");
         Print("  Visual Alerts: ", showVisualAlerts ? "ENABLED" : "DISABLED");
      }
   }

   //+------------------------------------------------------------------+
   //| Initialiser le filtre TimeRange (ex: "8-10;16-18")             |
   //+------------------------------------------------------------------+
   void InitTimeRangeFilter(bool enabled, string hourRanges)
   {
      if(!enabled || hourRanges == "")
      {
         if(m_timeRangeFilter != NULL) { delete m_timeRangeFilter; m_timeRangeFilter = NULL; }
         m_hourRanges = "";
         if(m_verboseLogging) Print(m_logPrefix + "TimeRange Filter: DISABLED");
         return;
      }
      
      m_timeRangeFilter = new TimeRangeFilter();
      m_hourRanges = hourRanges;
      
      if(m_verboseLogging) Print(m_logPrefix + "TimeRange Filter: ENABLED (" + hourRanges + ")");
   }

   //+------------------------------------------------------------------+
   //| Initialiser le filtre DayRange (ex: "1-5" = Lundi-Vendredi)    |
   //+------------------------------------------------------------------+
   void InitDayRangeFilter(bool enabled, string dayRanges)
   {
      if(!enabled || dayRanges == "")
      {
         if(m_dayRangeFilter != NULL) { delete m_dayRangeFilter; m_dayRangeFilter = NULL; }
         m_dayRanges = "";
         if(m_verboseLogging) Print(m_logPrefix + "DayRange Filter: DISABLED");
         return;
      }
      
      m_dayRangeFilter = new DayRangeFilter();
      m_dayRanges = dayRanges;
      
      if(m_verboseLogging) Print(m_logPrefix + "DayRange Filter: ENABLED (" + dayRanges + ")");
   }

   //+------------------------------------------------------------------+
   //| Initialiser le filtre Session (ex: SESSION_OVERLAP)            |
   //+------------------------------------------------------------------+
   void InitSessionFilter(bool enabled, ENUM_TRADING_SESSION session, int avoidOpeningMinutes)
   {
      if(!enabled)
      {
         if(m_sessionFilter != NULL) { delete m_sessionFilter; m_sessionFilter = NULL; }
         m_session = SESSION_ALL;
         m_avoidOpeningMinutes = 0;
         if(m_verboseLogging) Print(m_logPrefix + "Session Filter: DISABLED");
         return;
      }
      
      m_sessionFilter = new SessionFilter();
      m_session = session;
      m_avoidOpeningMinutes = avoidOpeningMinutes;
      
      if(m_verboseLogging) Print(m_logPrefix + "Session Filter: ENABLED (Session: " + IntegerToString(session) + ", Avoid: " + IntegerToString(avoidOpeningMinutes) + "min)");
   }

   //+------------------------------------------------------------------+
   //| Initialiser le filtre News                                     |
   //+------------------------------------------------------------------+
   void InitNewsFilter(bool enabled, string currencies, string keywords, 
                       int stopBefore, int startAfter, int daysLookup, 
                       ENUM_NEWS_SEPARATOR separator)
   {
      if(!enabled || currencies == "" || keywords == "")
      {
         if(m_newsFilter != NULL) { delete m_newsFilter; m_newsFilter = NULL; }
         m_newsCurrencies = "";
         m_newsKeywords = "";
         m_newsStopBefore = 0;
         m_newsStartAfter = 0;
         m_newsDaysLookup = 0;
         m_newsSeparator = NEWS_COMMA;
         if(m_verboseLogging) Print(m_logPrefix + "News Filter: DISABLED");
         return;
      }
      
      m_newsFilter = new NewsFilter();
      m_newsCurrencies = currencies;
      m_newsKeywords = keywords;
      m_newsStopBefore = stopBefore;
      m_newsStartAfter = startAfter;
      m_newsDaysLookup = daysLookup;
      m_newsSeparator = separator;
      
      if(m_verboseLogging) Print(m_logPrefix + "News Filter: ENABLED (" + currencies + ", " + keywords + ")");
   }

   //+------------------------------------------------------------------+
   //| Initialiser le filtre TimeMinute (ex: "8:30-10:45;16:00")     |
   //+------------------------------------------------------------------+
   void InitTimeMinuteFilter(bool enabled, string timeMinuteRanges)
   {
      if(!enabled || timeMinuteRanges == "")
      {
         if(m_timeMinuteFilter != NULL) { delete m_timeMinuteFilter; m_timeMinuteFilter = NULL; }
         m_timeMinuteRanges = "";
         if(m_verboseLogging) Print(m_logPrefix + "TimeMinute Filter: DISABLED");
         return;
      }
      
      m_timeMinuteFilter = new TimeMinuteFilter();
      m_timeMinuteRanges = timeMinuteRanges;
      
      if(m_verboseLogging) Print(m_logPrefix + "TimeMinute Filter: ENABLED (" + timeMinuteRanges + ")");
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
   //| Architecture modulaire avec gestion NULL-safe                  |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      // Si aucun filtre n'est actif, le trading est toujours autorisé
      if(m_timeRangeFilter == NULL && m_dayRangeFilter == NULL && 
         m_sessionFilter == NULL && m_newsFilter == NULL && 
         m_timeMinuteFilter == NULL)
      {
         UpdateStatus(TRADING_ACTIVE);
         return true;
      }
      
      // Vérifier chaque filtre - SI NULL, retourner TRUE (filtre non actif)
      
      // 1. TimeRange Filter
      if(m_timeRangeFilter != NULL)
      {
         if(!IsTimeRangeAllowed())
         {
            UpdateStatus(TRADING_BLOCKED_HOUR);
            return false;
         }
      }
      
      // 2. DayRange Filter
      if(m_dayRangeFilter != NULL)
      {
         if(!IsDayRangeAllowed())
         {
            UpdateStatus(TRADING_BLOCKED_DAY);
            return false;
         }
      }
      
      // 3. Session Filter
      if(m_sessionFilter != NULL)
      {
         if(!IsSessionAllowed())
         {
            UpdateStatus(TRADING_BLOCKED_SESSION);
            return false;
         }
      }
      
      // 4. News Filter
      if(m_newsFilter != NULL)
      {
         if(!IsNewsAllowed())
         {
            UpdateStatus(TRADING_BLOCKED_NEWS);
            return false;
         }
      }
      
      // 5. TimeMinute Filter
      if(m_timeMinuteFilter != NULL)
      {
         if(!IsTimeMinuteAllowed())
         {
            UpdateStatus(TRADING_BLOCKED_TIME_MINUTE);
            return false;
         }
      }
      
      // Tous les filtres actifs sont OK
      UpdateStatus(TRADING_ACTIVE);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Vérification rapide sans mise à jour de l'affichage             |
   //+------------------------------------------------------------------+
   bool IsTradingAllowedQuick()
   {
      // TimeRange Filter
      if(m_timeRangeFilter != NULL && !IsTimeRangeAllowed()) return false;
      
      // DayRange Filter
      if(m_dayRangeFilter != NULL && !IsDayRangeAllowed()) return false;
      
      // Session Filter
      if(m_sessionFilter != NULL && !IsSessionAllowed()) return false;
      
      // News Filter
      if(m_newsFilter != NULL && !IsNewsAllowed()) return false;
      
      // TimeMinute Filter
      if(m_timeMinuteFilter != NULL && !IsTimeMinuteAllowed()) return false;
      
      return true;
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
         case TRADING_BLOCKED_SESSION:
            return "Blocked (Session)";
         case TRADING_BLOCKED_NEWS:
            return "Blocked (News)";
         case TRADING_BLOCKED_TIME_MINUTE:
            return "Blocked (TimeMinute)";
         case TRADING_BLOCKED_MULTIPLE:
            return "Blocked (Multiple)";
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
      string info = "=== Trading Time Manager (Modular) ===\n";
      info += "Status: " + GetStatusDescription() + "\n";
      
      // Afficher les filtres actifs
      info += "Active Filters:\n";
      if(m_timeRangeFilter != NULL) info += "  ✓ TimeRange\n";
      if(m_dayRangeFilter != NULL) info += "  ✓ DayRange\n";
      if(m_sessionFilter != NULL) info += "  ✓ Session\n";
      if(m_newsFilter != NULL) info += "  ✓ News\n";
      if(m_timeMinuteFilter != NULL) info += "  ✓ TimeMinute\n";
      
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
   bool IsTimeRangeAllowed()
   {
      if(m_timeRangeFilter == NULL) return true;
      
      // Utiliser la vraie fonction du filtre avec un nom différent
      return ::IsTimeRangeAllowed(true, m_hourRanges);
   }

   //+------------------------------------------------------------------+
   //| Vérifier si le jour actuel est autorisé                         |
   //+------------------------------------------------------------------+
   bool IsDayRangeAllowed()
   {
      if(m_dayRangeFilter == NULL) return true;
      
      // Utiliser la vraie fonction du filtre avec un nom différent
      return ::IsDayRangeAllowed(true, m_dayRanges);
   }

   //+------------------------------------------------------------------+
   //| Vérifier si la session actuelle est autorisée                   |
   //+------------------------------------------------------------------+
   bool IsSessionAllowed()
   {
      if(m_sessionFilter == NULL) return true;
      
      // Utiliser la vraie fonction du filtre avec un nom différent
      return ::IsSessionAllowedCustom(m_session, m_avoidOpeningMinutes);
   }

   //+------------------------------------------------------------------+
   //| Vérifier si les news permettent le trading                      |
   //+------------------------------------------------------------------+
   bool IsNewsAllowed()
   {
      if(m_newsFilter == NULL) return true;
      
      // Utiliser la vraie fonction du filtre avec un nom différent
      return ::IsNewsAllowed(m_newsCurrencies, m_newsKeywords, m_newsStopBefore, 
                            m_newsStartAfter, m_newsDaysLookup, m_newsSeparator);
   }

   //+------------------------------------------------------------------+
   //| Vérifier si l'heure/minute actuelle est autorisée               |
   //+------------------------------------------------------------------+
   bool IsTimeMinuteAllowed()
   {
      if(m_timeMinuteFilter == NULL) return true;
      
      // Utiliser la vraie fonction du filtre avec un nom différent
      return ::IsTimeMinuteAllowed(true, m_timeMinuteRanges);
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
                  Print(m_logPrefix + "✅ Trading resumed - All filters passed");
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
         case TRADING_BLOCKED_SESSION:
            return "📊 TRADING PAUSED - Outside Trading Session";
         case TRADING_BLOCKED_NEWS:
            return "📰 TRADING PAUSED - News Event Detected";
         case TRADING_BLOCKED_TIME_MINUTE:
            return "⏱️ TRADING PAUSED - Outside Time Minute Range";
         case TRADING_BLOCKED_MULTIPLE:
            return "🚫 TRADING PAUSED - Multiple Filters Blocked";
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
         case TRADING_BLOCKED_SESSION:
            return clrBlue;
         case TRADING_BLOCKED_NEWS:
            return clrMagenta;
         case TRADING_BLOCKED_TIME_MINUTE:
            return clrCyan;
         case TRADING_BLOCKED_MULTIPLE:
            return clrRed;
         case TRADING_BLOCKED_BOTH:
            return clrRed;
         default:
            return clrWhite;
      }
   }
};