//+------------------------------------------------------------------+
//|                                         DailyReversalSignal.mqh    |
//|     Detection du setup Daily : hausse > X % apres une baisse       |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Mode de mesure de la variation journaliere                        |
//+------------------------------------------------------------------+
enum ENUM_RISE_MODE
{
   RISE_CLOSE_TO_CLOSE = 0,   // Close J-1 vs Close J-2 (variation journaliere)
   RISE_OPEN_TO_CLOSE  = 1    // Close J-1 vs Open J-1 (corps de la bougie)
};

//+------------------------------------------------------------------+
//| Detecteur de retournement Daily                                   |
//+------------------------------------------------------------------+
class DailyReversalSignal
{
private:
   string            m_symbol;
   double            m_minRisePercent;
   int               m_bearishBarsRequired;
   bool              m_ignoreSundayBar;
   ENUM_RISE_MODE    m_riseMode;

   datetime          m_lastEvaluatedBar;   // Anti-recalcul a chaque tick
   bool              m_lastResult;
   double            m_lastRisePercent;
   datetime          m_lastSignalBarTime;
   string            m_lastRejectReason;

   //+------------------------------------------------------------------+
   //| Charge les D1 CLOTUREES, la plus recente en index 0               |
   //| Filtre au passage les bougies du dimanche : sur l'or beaucoup de  |
   //| brokers ouvrent une D1 "dimanche" de quelques minutes qui         |
   //| fausserait completement le calcul de pourcentage.                 |
   //+------------------------------------------------------------------+
   int LoadClosedDailyBars(MqlRates &bars[], int needed)
   {
      // Marge large : on ignore potentiellement 1 bougie sur 7 (dimanche)
      int toCopy = needed * 2 + 10;

      MqlRates raw[];
      ArraySetAsSeries(raw, true);

      // start_pos = 1 : on ne lit JAMAIS la bougie D1 en cours
      int copied = CopyRates(m_symbol, PERIOD_D1, 1, toCopy, raw);
      if(copied <= 0)
      {
         m_lastRejectReason = "CopyRates D1 a echoue (erreur " + IntegerToString(GetLastError()) + ")";
         return 0;
      }

      ArrayResize(bars, 0);
      int kept = 0;

      for(int i = 0; i < copied && kept < needed; i++)
      {
         if(m_ignoreSundayBar)
         {
            MqlDateTime dt;
            TimeToStruct(raw[i].time, dt);
            if(dt.day_of_week == 0)   // 0 = dimanche
               continue;
         }

         ArrayResize(bars, kept + 1);
         bars[kept] = raw[i];
         kept++;
      }

      return kept;
   }

public:
   DailyReversalSignal()
   {
      m_symbol              = "";
      m_minRisePercent      = 1.0;
      m_bearishBarsRequired = 1;
      m_ignoreSundayBar     = true;
      m_riseMode            = RISE_CLOSE_TO_CLOSE;
      m_lastEvaluatedBar    = 0;
      m_lastResult          = false;
      m_lastRisePercent     = 0.0;
      m_lastSignalBarTime   = 0;
      m_lastRejectReason    = "";
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                     |
   //+------------------------------------------------------------------+
   bool Configure(string symbol, double minRisePercent, int bearishBarsRequired,
                  bool ignoreSundayBar, ENUM_RISE_MODE riseMode)
   {
      if(symbol == "")
      {
         Logger::Error("Symbole vide dans DailyReversalSignal");
         return false;
      }

      if(minRisePercent <= 0.0)
      {
         Logger::Error(StringFormat("Seuil de hausse invalide : %.2f %% (doit etre > 0)", minRisePercent));
         return false;
      }

      if(bearishBarsRequired < 0 || bearishBarsRequired > 10)
      {
         Logger::Error(StringFormat("Nombre de bougies baissieres invalide : %d (attendu 0 a 10)", bearishBarsRequired));
         return false;
      }

      m_symbol              = symbol;
      m_minRisePercent      = minRisePercent;
      m_bearishBarsRequired = bearishBarsRequired;
      m_ignoreSundayBar     = ignoreSundayBar;
      m_riseMode            = riseMode;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Evaluation. Ne recalcule qu'a l'apparition d'une nouvelle D1.     |
   //| Retourne true si un signal VIENT d'etre detecte (front montant).  |
   //+------------------------------------------------------------------+
   bool Evaluate()
   {
      // Il faut la bougie du signal + la reference + les bougies baissieres
      int needed = 1 + MathMax(m_bearishBarsRequired, 1);

      MqlRates bars[];
      int available = LoadClosedDailyBars(bars, needed);

      if(available < needed)
      {
         m_lastRejectReason = StringFormat("Historique D1 insuffisant : %d bougies exploitables, %d requises",
                                           available, needed);
         return false;
      }

      // Une seule evaluation par bougie D1
      if(bars[0].time == m_lastEvaluatedBar)
         return false;

      m_lastEvaluatedBar = bars[0].time;
      m_lastResult       = false;

      //--- 1. Variation haussiere de la bougie J-1
      double reference = (m_riseMode == RISE_CLOSE_TO_CLOSE) ? bars[1].close : bars[0].open;

      if(reference <= 0.0)
      {
         m_lastRejectReason = "Prix de reference nul ou negatif";
         return false;
      }

      m_lastRisePercent = (bars[0].close - reference) / reference * 100.0;

      if(m_lastRisePercent < m_minRisePercent)
      {
         m_lastRejectReason = StringFormat("Hausse %.2f %% < seuil %.2f %%",
                                           m_lastRisePercent, m_minRisePercent);
         Logger::Debug(StringFormat("D1 %s : %s",
                                    TimeToString(bars[0].time, TIME_DATE), m_lastRejectReason));
         return false;
      }

      //--- 2. La ou les bougies precedentes doivent etre baissieres
      for(int k = 1; k <= m_bearishBarsRequired; k++)
      {
         if(bars[k].close >= bars[k].open)
         {
            m_lastRejectReason = StringFormat("Hausse %.2f %% OK mais J-%d n'est pas baissiere",
                                              m_lastRisePercent, k + 1);
            Logger::Debug(StringFormat("D1 %s : %s",
                                       TimeToString(bars[0].time, TIME_DATE), m_lastRejectReason));
            return false;
         }
      }

      //--- Signal valide
      m_lastResult        = true;
      m_lastSignalBarTime = bars[0].time;
      m_lastRejectReason  = "";

      Logger::Signal(true, StringFormat("Setup D1 valide | bougie %s | hausse %.2f %% (seuil %.2f %%) | %d bougie(s) baissiere(s) avant",
                                        TimeToString(bars[0].time, TIME_DATE),
                                        m_lastRisePercent,
                                        m_minRisePercent,
                                        m_bearishBarsRequired));
      return true;
   }

   //--- Accesseurs
   double   GetLastRisePercent()  const { return m_lastRisePercent; }
   datetime GetSignalBarTime()    const { return m_lastSignalBarTime; }
   string   GetLastRejectReason() const { return m_lastRejectReason; }
   bool     GetLastResult()       const { return m_lastResult; }

   string Describe() const
   {
      return StringFormat("hausse >= %.2f %% (%s) apres %d bougie(s) baissiere(s)%s",
                          m_minRisePercent,
                          m_riseMode == RISE_CLOSE_TO_CLOSE ? "close/close" : "open/close",
                          m_bearishBarsRequired,
                          m_ignoreSundayBar ? ", dimanches ignores" : "");
   }
};
//+------------------------------------------------------------------+
