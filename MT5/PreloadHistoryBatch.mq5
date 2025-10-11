//+------------------------------------------------------------------+
//|                                       PreloadHistoryBatch.mq5    |
//|             Précharge l'historique pour plusieurs symboles       |
//+------------------------------------------------------------------+
#property script_show_inputs

input string   InpSymbols      = "EURUSD,GBPUSD,XAUUSD";  // Liste symboles
input string   InpTimeframes   = "M1,M3,M5,M15,H1";        // Liste timeframes
input datetime InpFrom         = D'2018.01.01 00:00';
input bool     InpShowProgress = true;
input int      InpChunkDays    = 30;
input int      InpMaxRetries   = 3;
input int      InpPauseMs      = 250;

// --- Utils: Trim, Split ---
string TrimAll(string s) {
   StringReplace(s, "\r", "");
   StringReplace(s, "\n", "");
   StringReplace(s, " ", "");
   StringReplace(s, "\t", "");
   return s;
}
int Split(const string src, const string delim, string &out[]) {
   int count = StringSplit(src, StringGetCharacter(delim, 0), out);
   for (int i=0; i<count; i++) out[i] = TrimAll(out[i]);
   return count;
}

// --- Parse timeframe string robust ---
bool ParseTf(string token, ENUM_TIMEFRAMES &tf) {
   string t = TrimAll(token);
   StringToUpper(t);
   if(t=="M1")  { tf=PERIOD_M1;  return true; }
   if(t=="M2")  { tf=PERIOD_M2;  return true; }
   if(t=="M3")  { tf=PERIOD_M3;  return true; }
   if(t=="M5")  { tf=PERIOD_M5;  return true; }
   if(t=="M10") { tf=PERIOD_M10; return true; }
   if(t=="M15") { tf=PERIOD_M15; return true; }
   if(t=="M30") { tf=PERIOD_M30; return true; }
   if(t=="H1")  { tf=PERIOD_H1;  return true; }
   if(t=="H4")  { tf=PERIOD_H4;  return true; }
   if(t=="D1")  { tf=PERIOD_D1;  return true; }
   if(t=="W1")  { tf=PERIOD_W1;  return true; }
   if(t=="MN1") { tf=PERIOD_MN1; return true; }
   return false;
}

// --- Charge un intervalle ---
int LoadRange(const string symbol, ENUM_TIMEFRAMES tf, datetime from, datetime to, int chunkDays, int maxRetries, int pauseMs, bool verbose) {
   MqlRates rates[];
   int total=0; datetime t0=from;
   while(t0<to) {
      datetime t1 = t0 + chunkDays*86400;
      if(t1>to) t1=to;
      int copied = 0;
      for(int tr=0; tr<maxRetries; ++tr) {
         copied = CopyRates(symbol, tf, t0, t1, rates);
         if(copied>=0) break;
         Sleep(200);
      }
      if(copied>0) {
         total += copied;
         datetime nextStart = rates[copied-1].time + PeriodSeconds(tf);
         if(verbose)
            PrintFormat("✅ %s %s %s → %s +%d (total %d)",
                        symbol, EnumToString(tf),
                        TimeToString(rates[0].time),
                        TimeToString(rates[copied-1].time),
                        copied, total);
         t0 = nextStart;
      } else {
         if(verbose)
            PrintFormat("⚠️ %s %s aucune donnée %s → %s",
                        symbol, EnumToString(tf), TimeToString(t0), TimeToString(t1));
         t0 = t1;
      }
      if(pauseMs>0) Sleep(pauseMs);
   }
   return total;
}

// --- Main ---
void OnStart() {
   string syms_raw[], tfs_raw[];
   int nSyms = Split(InpSymbols, ",", syms_raw);
   int nTfs  = Split(InpTimeframes, ",", tfs_raw);
   datetime from = InpFrom, to = TimeCurrent();

   PrintFormat("⏳ Préchargement: %d symbole(s), %d timeframe(s), de %s à %s, paquets %d jours",
               nSyms, nTfs, TimeToString(from), TimeToString(to), InpChunkDays);

   for(int i=0; i<nSyms; ++i) {
      string sym = syms_raw[i];
      if(sym=="") continue;
      if(!SymbolSelect(sym, true)) {
         PrintFormat("❌ Impossible de sélectionner %s", sym);
         continue;
      }
      for(int j=0; j<nTfs; ++j) {
         ENUM_TIMEFRAMES tf;
         if(!ParseTf(tfs_raw[j], tf)) {
            PrintFormat("⚠️ Timeframe inconnu: %s (ignoré)", tfs_raw[j]);
            continue;
         }
         PrintFormat("➡️  %s  %s  (début %s)", sym, EnumToString(tf), TimeToString(from));
         int got = LoadRange(sym, tf, from, to, InpChunkDays, InpMaxRetries, InpPauseMs, InpShowProgress);
         PrintFormat("📦 Terminé: %s %s total=%d barres", sym, EnumToString(tf), got);
      }
   }
   Print("✅ Préchargement terminé.");
}
