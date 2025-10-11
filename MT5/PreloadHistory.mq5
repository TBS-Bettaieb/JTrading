//+------------------------------------------------------------------+
//|                                             PreloadHistory.mq5   |
//|                      Force le téléchargement de l'historique     |
//|                      (ex: pour Python ou backtests externes)     |
//+------------------------------------------------------------------+
#property script_show_inputs

input string   InpSymbol   = "EURUSD";     // Symbole à précharger
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1; // Timeframe à charger
input datetime InpFrom     = D'2018.01.01 00:00'; // Date de début
input bool     ShowProgress = true;       // Afficher progression

void OnStart()
{
   datetime from = InpFrom;
   datetime to   = TimeCurrent();
   MqlRates rates[];
   int total_loaded = 0;

   PrintFormat("⏳ Téléchargement de %s (%s) depuis %s jusqu’à %s ...",
               InpSymbol, EnumToString(InpTimeframe),
               TimeToString(from), TimeToString(to));

   // Boucle en paquets (évite surcharge serveur)
   datetime t0 = from;
   while(t0 < to)
   {
      datetime t1 = t0 + 30 * 86400; // tranches de 30 jours
      int copied = CopyRates(InpSymbol, InpTimeframe, t0, t1, rates);
      if(copied > 0)
      {
         total_loaded += copied;
         t0 = rates[copied-1].time + 60; // +1 minute pour éviter chevauchement
         if(ShowProgress)
            PrintFormat("✅ %s → %s (%d barres chargées, total %d)",
                        TimeToString(rates[0].time),
                        TimeToString(rates[copied-1].time),
                        copied, total_loaded);
      }
      else
      {
         PrintFormat("⚠️ Aucune donnée copiée entre %s et %s", TimeToString(t0), TimeToString(t1));
         t0 = t1;
      }
   }

   PrintFormat("✅ Fin du préchargement : %d barres téléchargées pour %s (%s)",
               total_loaded, InpSymbol, EnumToString(InpTimeframe));
}
