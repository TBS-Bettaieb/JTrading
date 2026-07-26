//+------------------------------------------------------------------+
//|                                       AsianSessionScheduler.mqh   |
//|          Fenetre de session parametrable (ouverture / cloture)     |
//|                                                                    |
//| Complete SessionFilter.mqh (EA/Shared/DayTimesFilters/) qui code   |
//| SESSION_ASIA en dur (22:00-06:00 GMT) et ne sait que BLOQUER le    |
//| trading. Ici on a besoin de DECLENCHER a l'ouverture et de FORCER  |
//| la sortie a la cloture : il faut donc les instants, pas un booleen.|
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "../Shared/Logger.mqh"
#include "../Shared/DayTimesFilters/DayFilters/DayRangeFilter.mqh"

#define SECONDS_PER_DAY  86400
#define MINUTES_PER_DAY  1440

//+------------------------------------------------------------------+
//| Planificateur de session (gere le franchissement de minuit)       |
//+------------------------------------------------------------------+
class AsianSessionScheduler
{
private:
   int      m_startMinutes;      // Minutes depuis minuit (ouverture)
   int      m_endMinutes;        // Minutes depuis minuit (cloture)
   int      m_durationMinutes;   // Duree effective de la session
   bool     m_crossesMidnight;   // true si start > end (ex: 22:00 -> 06:00)
   bool     m_useServerTime;     // false = TimeGMT() (convention du repo)
   string   m_tradeDays;         // Format DayRangeFilter : "1-5", "1;3;5"...

   //--- Convertit un input HHMM (0, 800, 2230) en minutes depuis minuit
   bool ParseHHMM(int hhmm, int &minutesOut) const
   {
      int hh = hhmm / 100;
      int mm = hhmm % 100;

      if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
         return false;

      minutesOut = hh * 60 + mm;
      return true;
   }

   //--- Minutes depuis minuit d'un datetime
   int MinutesOfDay(datetime t) const
   {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return dt.hour * 60 + dt.min;
   }

   //--- Minuit du jour contenant t (datetime = secondes depuis epoch)
   datetime DayStart(datetime t) const
   {
      return (datetime)(((long)t / SECONDS_PER_DAY) * SECONDS_PER_DAY);
   }

public:
   AsianSessionScheduler()
   {
      m_startMinutes    = 0;
      m_endMinutes      = 480;      // 08:00
      m_durationMinutes = 480;
      m_crossesMidnight = false;
      m_useServerTime   = false;
      m_tradeDays       = "1-5";
   }

   //+------------------------------------------------------------------+
   //| Configuration - retourne false si les bornes sont invalides       |
   //+------------------------------------------------------------------+
   bool Configure(int startHHMM, int endHHMM, bool useServerTime, string tradeDays)
   {
      if(!ParseHHMM(startHHMM, m_startMinutes))
      {
         Logger::Error(StringFormat("Heure d'ouverture invalide : %d (format attendu HHMM, ex 0 ou 2230)", startHHMM));
         return false;
      }

      if(!ParseHHMM(endHHMM, m_endMinutes))
      {
         Logger::Error(StringFormat("Heure de cloture invalide : %d (format attendu HHMM, ex 800)", endHHMM));
         return false;
      }

      if(m_startMinutes == m_endMinutes)
      {
         Logger::Error("Ouverture et cloture identiques : la session serait vide ou permanente");
         return false;
      }

      m_crossesMidnight = (m_startMinutes > m_endMinutes);
      m_durationMinutes = m_crossesMidnight
                          ? (MINUTES_PER_DAY - m_startMinutes + m_endMinutes)
                          : (m_endMinutes - m_startMinutes);

      m_useServerTime = useServerTime;
      m_tradeDays     = tradeDays;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Base de temps : GMT par defaut (convention documentee du repo)    |
   //+------------------------------------------------------------------+
   datetime Now() const
   {
      return m_useServerTime ? TimeCurrent() : TimeGMT();
   }

   bool UsesServerTime() const { return m_useServerTime; }

   //+------------------------------------------------------------------+
   //| Conversion vers l'heure SERVEUR                                   |
   //| Les objets graphiques et CopyRates(start_time,...) raisonnent en  |
   //| heure serveur : sans cette conversion, tout ce qui est dessine    |
   //| serait decale de l'offset GMT du broker.                          |
   //+------------------------------------------------------------------+
   datetime ToChartTime(datetime t) const
   {
      if(m_useServerTime || t == 0)
         return t;

      return (datetime)(t + (TimeCurrent() - TimeGMT()));
   }

   //+------------------------------------------------------------------+
   //| L'instant t est-il dans la fenetre horaire ?                      |
   //+------------------------------------------------------------------+
   bool IsInSession(datetime t) const
   {
      int m = MinutesOfDay(t);

      if(m_crossesMidnight)
         return (m >= m_startMinutes || m < m_endMinutes);

      return (m >= m_startMinutes && m < m_endMinutes);
   }

   //+------------------------------------------------------------------+
   //| Instant d'ouverture de l'occurrence de session contenant t        |
   //| Retourne 0 si t est hors session. Sert de cle d'identite : deux   |
   //| ticks de la meme session renvoient la meme valeur.                |
   //+------------------------------------------------------------------+
   datetime SessionKey(datetime t) const
   {
      if(!IsInSession(t))
         return 0;

      datetime dayStart = DayStart(t);
      int m = MinutesOfDay(t);

      // Fenetre a cheval sur minuit et on est dans la queue :
      // l'ouverture appartient au jour precedent.
      if(m_crossesMidnight && m < m_endMinutes)
         dayStart -= SECONDS_PER_DAY;

      return (datetime)(dayStart + (long)m_startMinutes * 60);
   }

   //+------------------------------------------------------------------+
   //| Instant de cloture d'une session identifiee par sa cle            |
   //+------------------------------------------------------------------+
   datetime SessionEnd(datetime sessionKey) const
   {
      if(sessionKey == 0)
         return 0;

      return (datetime)(sessionKey + (long)m_durationMinutes * 60);
   }

   //+------------------------------------------------------------------+
   //| Prochaine ouverture a partir de t (pour l'affichage)              |
   //+------------------------------------------------------------------+
   datetime NextOpen(datetime t) const
   {
      datetime todayOpen = (datetime)(DayStart(t) + (long)m_startMinutes * 60);

      if(todayOpen > t)
         return todayOpen;

      return (datetime)(todayOpen + SECONDS_PER_DAY);
   }

   //+------------------------------------------------------------------+
   //| Derniere ouverture a ou avant t (sert au trace de l'historique)    |
   //+------------------------------------------------------------------+
   datetime LastOpen(datetime t) const
   {
      datetime todayOpen = (datetime)(DayStart(t) + (long)m_startMinutes * 60);

      if(todayOpen <= t)
         return todayOpen;

      return (datetime)(todayOpen - SECONDS_PER_DAY);
   }

   //+------------------------------------------------------------------+
   //| Le jour d'OUVERTURE de la session est-il autorise ?               |
   //| On teste le jour de l'ouverture, pas celui du tick courant : une  |
   //| session a cheval sur minuit reste rattachee a son jour de depart. |
   //+------------------------------------------------------------------+
   bool IsSessionDayAllowed(datetime sessionKey) const
   {
      if(sessionKey == 0)
         return false;

      MqlDateTime dt;
      TimeToStruct(sessionKey, dt);

      return IsDayAllowedCustom(m_tradeDays, dt.day_of_week);
   }

   //+------------------------------------------------------------------+
   //| Minutes ecoulees depuis l'ouverture de la session                 |
   //+------------------------------------------------------------------+
   int MinutesSinceOpen(datetime sessionKey, datetime t) const
   {
      if(sessionKey == 0)
         return -1;

      return (int)((t - sessionKey) / 60);
   }

   int GetDurationMinutes() const { return m_durationMinutes; }

   //+------------------------------------------------------------------+
   //| Description lisible pour les logs et le panneau graphique         |
   //+------------------------------------------------------------------+
   string Describe() const
   {
      string tz = m_useServerTime ? "heure serveur" : "GMT";

      return StringFormat("%02d:%02d -> %02d:%02d %s (%d min%s) | jours: %s",
                          m_startMinutes / 60, m_startMinutes % 60,
                          m_endMinutes / 60, m_endMinutes % 60,
                          tz,
                          m_durationMinutes,
                          m_crossesMidnight ? ", a cheval sur minuit" : "",
                          m_tradeDays == "" ? "tous" : m_tradeDays);
   }
};
//+------------------------------------------------------------------+
