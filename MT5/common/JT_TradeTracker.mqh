//+------------------------------------------------------------------+
//|                                             JT_TradeTracker.mqh  |
//|                      Système de suivi et analyse des trades      |
//+------------------------------------------------------------------+
#property strict

#include <Trade/PositionInfo.mqh>

// Structure pour stocker TOUTES les données d'un trade
struct TradeRecord {
   // Données de base
   ulong    ticket;
   datetime openTime;
   datetime closeTime;
   string   symbol;
   int      type;           // 0=BUY, 1=SELL
   double   volume;
   double   openPrice;
   double   closePrice;
   double   sl;
   double   tp;
   double   profit;
   double   commission;
   double   swap;
   
   // Données de marché à l'entrée
   double   rsi;
   double   atr;
   double   spread;
   double   bbWidth;        // Largeur Bollinger en points
   double   emaFast;        // Valeur EMA50
   double   emaSlow;        // Valeur EMA100
   double   distToUpperBB;  // Distance à BB supérieure
   double   distToLowerBB;  // Distance à BB inférieure
   
   // Métriques EMA enrichies
   double   distEMAFastSlow; // Distance EMA50-EMA100 en points
   double   emaSpread;       // (EMA50-EMA100)/EMA100 en %
   string   emaTrend;        // "UP" si EMA50>EMA100, "DOWN" sinon
   string   priceVsEMA;      // ABOVE_BOTH, BETWEEN, BELOW_BOTH
   
   // Données divergence
   double   divAngle;        // Angle d'inclinaison en degrés
   double   divStrength;     // Force: diff RSI / diff prix
   int      divBars;         // Nombre de barres entre pivots
   
   // Contexte temporel
   int      hour;
   int      dayOfWeek;
   int      minute;
   
   // Métriques calculées
   double   plannedRR;      // RR prévu à l'entrée
   double   actualRR;       // RR réel à la sortie
   double   pips;           // Résultat en pips
   double   maxDrawdown;    // DD max pendant le trade
   double   maxProfit;      // Profit max atteint
   int      duration;       // Durée en minutes
   double   slDistance;     // Distance SL en points
   double   tpDistance;     // Distance TP en points
   
   // Raison de sortie
   string   exitReason;     // "TP", "SL", "Manual", "Signal", etc.
   bool     hitBE;          // A touché break-even
   
   // Paramètres EA actifs
   string   mode;           // "REVERSION" ou "BREAKOUT"
   bool     divergence;     // Trade validé par divergence
   string   emaMode;        // Mode EMA utilisé
   
   // Paramètres de configuration EA capturés à l'ouverture
   int      bb_period;           // Période BB utilisée
   double   bb_deviation;        // Déviation BB utilisée
   int      rsi_period_used;     // Période RSI utilisée
   double   rsi_oversold_level;  // Seuil RSI oversold
   double   rsi_overbought_level;// Seuil RSI overbought
   int      ema_fast_period;     // Période EMA rapide
   int      ema_slow_period;     // Période EMA lente
   double   ema_zone_distance;   // Distance zone EMA (points)
   double   risk_percent_used;   // % risque utilisé
   double   min_rr_config;       // Ratio RR minimum configuré
   int      sl_period_config;    // Période SL configurée
   int      tp_period_config;    // Période TP configurée
   double   atr_multiplier;      // Multiplicateur ATR
   int      outside_padding;     // Padding hors bande (points)
   bool     body_must_outside;   // Corps seul doit être dehors
   bool     use_rsi_filter;      // Filtre RSI activé
   bool     use_ema_filter;      // Filtre EMA activé
   bool     use_div_validator;   // Validateur divergence activé
};

class JTTradeTracker {
private:
   TradeRecord m_records[];
   string      m_csvFile;
   string      m_csvFileTemp;     // Nom temporaire avant renommage
   string      m_symbol;
   ulong       m_magic;
   int         m_fileHandle;
   ENUM_TIMEFRAMES m_timeframe;
   datetime    m_firstTradeTime;
   datetime    m_lastTradeTime;
   
   // Handles des indicateurs pour tracking
   int         m_bbHandle;
   int         m_rsiHandle;
   int         m_emaFastHandle;
   int         m_emaSlowHandle;
   
   // Paramètres BB
   int         m_bbPeriod;
   double      m_bbDev;
   
   // Statistiques globales
   struct Stats {
      int    totalTrades;
      int    wins;
      int    losses;
      double totalProfit;
      double totalLoss;
      double bestTrade;
      double worstTrade;
      double avgWin;
      double avgLoss;
      double winRate;
      double profitFactor;
      double avgRR;
      double maxConsecWins;
      double maxConsecLosses;
      double maxDrawdown;
      double sharpeRatio;
   } m_stats;
   
   // Pour éviter les doublons de fermeture
   ulong m_closedTickets[];
   
   // Convertir le timeframe en string
   string TimeframeToString(ENUM_TIMEFRAMES tf) {
      switch(tf) {
         case PERIOD_M1:  return "M1";
         case PERIOD_M2:  return "M2";
         case PERIOD_M3:  return "M3";
         case PERIOD_M4:  return "M4";
         case PERIOD_M5:  return "M5";
         case PERIOD_M6:  return "M6";
         case PERIOD_M10: return "M10";
         case PERIOD_M12: return "M12";
         case PERIOD_M15: return "M15";
         case PERIOD_M20: return "M20";
         case PERIOD_M30: return "M30";
         case PERIOD_H1:  return "H1";
         case PERIOD_H2:  return "H2";
         case PERIOD_H3:  return "H3";
         case PERIOD_H4:  return "H4";
         case PERIOD_H6:  return "H6";
         case PERIOD_H8:  return "H8";
         case PERIOD_H12: return "H12";
         case PERIOD_D1:  return "D1";
         case PERIOD_W1:  return "W1";
         case PERIOD_MN1: return "MN1";
         default:         return "UNKNOWN";
      }
   }
   
   // Renommer le fichier CSV avec les dates
   void RenameCSVWithDates() {
      if(m_firstTradeTime == 0 || m_lastTradeTime == 0) return;
      
      MqlDateTime dtFirst, dtLast;
      TimeToStruct(m_firstTradeTime, dtFirst);
      TimeToStruct(m_lastTradeTime, dtLast);
      
      string dateFirst = StringFormat("%04d%02d%02d", dtFirst.year, dtFirst.mon, dtFirst.day);
      string dateLast = StringFormat("%04d%02d%02d", dtLast.year, dtLast.mon, dtLast.day);
      string tfStr = TimeframeToString(m_timeframe);
      
      string newFileName = "TradeAnalysis_" + m_symbol + "_" + tfStr + "_" + 
                          dateFirst + "_" + dateLast + ".csv";
      
      // Si le nom n'a pas changé ou si c'est le premier renommage
      if(newFileName == m_csvFile) return;
      
      // Copier le contenu vers le nouveau fichier
      int oldHandle = FileOpen(m_csvFile, FILE_READ|FILE_ANSI);
      if(oldHandle == INVALID_HANDLE) return;
      
      int newHandle = FileOpen(newFileName, FILE_WRITE|FILE_ANSI);
      if(newHandle == INVALID_HANDLE) {
         FileClose(oldHandle);
         return;
      }
      
      // Copier tout le contenu ligne par ligne
      while(!FileIsEnding(oldHandle)) {
         string line = FileReadString(oldHandle);
         if(StringLen(line) > 0) {
            // Ajouter \n seulement si la ligne n'en a pas déjà
            if(StringFind(line, "\n") < 0)
               FileWriteString(newHandle, line + "\n");
            else
               FileWriteString(newHandle, line);
         }
      }
      
      FileClose(oldHandle);
      FileClose(newHandle);
      
      // Supprimer l'ancien fichier
      FileDelete(m_csvFile);
      
      // Mettre à jour le nom
      m_csvFile = newFileName;
      Print("CSV renommé en: ", m_csvFile);
   }

public:
   // Constructeur avec paramètres
   JTTradeTracker(string symbol, ulong magic, int bbPeriod, double bbDev, 
                  int rsiPeriod, int emaFast, int emaSlow) {
      m_symbol = symbol;
      m_magic = magic;
      m_bbPeriod = bbPeriod;
      m_bbDev = bbDev;
      m_timeframe = (ENUM_TIMEFRAMES)_Period;
      m_firstTradeTime = 0;
      m_lastTradeTime = 0;
      
      // Créer un nom temporaire basé sur le magic number
      m_csvFileTemp = "TradeAnalysis_" + symbol + "_" + IntegerToString(magic) + ".csv";
      m_csvFile = m_csvFileTemp; // Sera renommé après le premier trade
      
      // Initialiser les handles d'indicateurs pour le tracking
      m_bbHandle = iBands(symbol, PERIOD_CURRENT, bbPeriod, 0, bbDev, PRICE_CLOSE);
      m_rsiHandle = iRSI(symbol, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE);
      m_emaFastHandle = iMA(symbol, PERIOD_CURRENT, emaFast, 0, MODE_EMA, PRICE_CLOSE);
      m_emaSlowHandle = iMA(symbol, PERIOD_CURRENT, emaSlow, 0, MODE_EMA, PRICE_CLOSE);
      
      ArrayResize(m_records, 0);
      ArrayResize(m_closedTickets, 0);
      
      InitializeCSV();
      
      Print("Trade Tracker initialisé - CSV: ", m_csvFile);
   }
   
   // Destructeur
   ~JTTradeTracker() {
      if(m_bbHandle != INVALID_HANDLE) IndicatorRelease(m_bbHandle);
      if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
      if(m_emaFastHandle != INVALID_HANDLE) IndicatorRelease(m_emaFastHandle);
      if(m_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(m_emaSlowHandle);
   }

   // Enregistrer l'ouverture d'un trade avec TOUTES les données
   void RecordTradeOpen(ulong ticket, string mode = "", bool isDivergence = false, string emaMode = "",
                        double divAngle = 0.0, double divStrength = 0.0, int divBars = 0,
                        // Paramètres de configuration EA
                        int bbPeriod = 20, double bbDev = 2.0, int rsiPeriod = 14,
                        double rsiOversold = 30.0, double rsiOverbought = 70.0,
                        int emaFast = 50, int emaSlow = 100, double emaZoneDist = 20.0,
                        double riskPct = 1.0, double minRR = 2.0,
                        int slPeriod = 50, int tpPeriod = 30, double atrMult = 2.0,
                        int outsidePad = 5, bool bodyOut = true,
                        bool useRSI = true, bool useEMA = true, bool useDiv = true) {
      if(!PositionSelectByTicket(ticket)) return;
      
      int idx = ArraySize(m_records);
      ArrayResize(m_records, idx + 1);
      TradeRecord rec;
      
      // Initialiser toutes les valeurs à 0
      rec.ticket = 0;
      rec.openTime = 0;
      rec.closeTime = 0;
      rec.symbol = "";
      rec.type = 0;
      rec.volume = 0;
      rec.openPrice = 0;
      rec.closePrice = 0;
      rec.sl = 0;
      rec.tp = 0;
      rec.profit = 0;
      rec.commission = 0;
      rec.swap = 0;
      rec.rsi = 0;
      rec.atr = 0;
      rec.spread = 0;
      rec.bbWidth = 0;
      rec.emaFast = 0;
      rec.emaSlow = 0;
      rec.distToUpperBB = 0;
      rec.distToLowerBB = 0;
      rec.hour = 0;
      rec.dayOfWeek = 0;
      rec.minute = 0;
      rec.plannedRR = 0;
      rec.actualRR = 0;
      rec.pips = 0;
      rec.maxDrawdown = 0;
      rec.maxProfit = 0;
      rec.duration = 0;
      rec.slDistance = 0;
      rec.tpDistance = 0;
      rec.exitReason = "";
      rec.hitBE = false;
      rec.mode = "";
      rec.divergence = false;
      rec.emaMode = "";
      rec.distEMAFastSlow = 0;
      rec.emaSpread = 0;
      rec.emaTrend = "";
      rec.priceVsEMA = "";
      rec.bb_period = 0;
      rec.bb_deviation = 0;
      rec.rsi_period_used = 0;
      rec.rsi_oversold_level = 0;
      rec.rsi_overbought_level = 0;
      rec.ema_fast_period = 0;
      rec.ema_slow_period = 0;
      rec.ema_zone_distance = 0;
      rec.risk_percent_used = 0;
      rec.min_rr_config = 0;
      rec.sl_period_config = 0;
      rec.tp_period_config = 0;
      rec.atr_multiplier = 0;
      rec.outside_padding = 0;
      rec.body_must_outside = false;
      rec.use_rsi_filter = false;
      rec.use_ema_filter = false;
      rec.use_div_validator = false;
      
      // Données de position
      rec.ticket = ticket;
      rec.openTime = (datetime)PositionGetInteger(POSITION_TIME);
      rec.symbol = PositionGetString(POSITION_SYMBOL);
      rec.type = (int)PositionGetInteger(POSITION_TYPE);
      rec.volume = PositionGetDouble(POSITION_VOLUME);
      rec.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      rec.sl = PositionGetDouble(POSITION_SL);
      rec.tp = PositionGetDouble(POSITION_TP);
      
      // Collecter les données de marché
      CollectMarketData(rec);
      
      // Contexte
      MqlDateTime dt;
      TimeToStruct(rec.openTime, dt);
      rec.hour = dt.hour;
      rec.minute = dt.min;
      rec.dayOfWeek = dt.day_of_week;
      
      // Paramètres EA
      rec.mode = mode;
      rec.divergence = isDivergence;
      rec.emaMode = emaMode;
      
      // Données de divergence (passées en paramètres)
      rec.divAngle = divAngle;
      rec.divStrength = divStrength;
      rec.divBars = divBars;
      
      // Paramètres de configuration EA (passés en paramètres)
      rec.bb_period = bbPeriod;
      rec.bb_deviation = bbDev;
      rec.rsi_period_used = rsiPeriod;
      rec.rsi_oversold_level = rsiOversold;
      rec.rsi_overbought_level = rsiOverbought;
      rec.ema_fast_period = emaFast;
      rec.ema_slow_period = emaSlow;
      rec.ema_zone_distance = emaZoneDist;
      rec.risk_percent_used = riskPct;
      rec.min_rr_config = minRR;
      rec.sl_period_config = slPeriod;
      rec.tp_period_config = tpPeriod;
      rec.atr_multiplier = atrMult;
      rec.outside_padding = outsidePad;
      rec.body_must_outside = bodyOut;
      rec.use_rsi_filter = useRSI;
      rec.use_ema_filter = useEMA;
      rec.use_div_validator = useDiv;
      
      // Calculer RR prévu
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      rec.slDistance = MathAbs(rec.openPrice - rec.sl) / point;
      rec.tpDistance = MathAbs(rec.tp - rec.openPrice) / point;
      rec.plannedRR = (rec.slDistance > 0) ? rec.tpDistance / rec.slDistance : 0;
      
      m_records[idx] = rec;
      
      // Gérer le premier trade
      if(m_firstTradeTime == 0) {
         m_firstTradeTime = rec.openTime;
         RenameCSVWithDates(); // Premier renommage
      }
      
      // Mettre à jour la date du dernier trade
      if(rec.openTime > m_lastTradeTime) {
         m_lastTradeTime = rec.openTime;
      }
      
      // Log immédiat
      LogTradeOpen(rec);
      SaveToCSV(rec, true);
   }

   // Collecter les données de marché actuelles
   void CollectMarketData(TradeRecord &rec) {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // RSI
      double rsi[];
      ArraySetAsSeries(rsi, true);
      if(CopyBuffer(m_rsiHandle, 0, 0, 1, rsi) > 0)
         rec.rsi = rsi[0];
      
      // Bollinger Bands
      double upper[], middle[], lower[];
      ArraySetAsSeries(upper, true);
      ArraySetAsSeries(middle, true);
      ArraySetAsSeries(lower, true);
      
      if(CopyBuffer(m_bbHandle, 1, 0, 1, upper) > 0 &&
         CopyBuffer(m_bbHandle, 0, 0, 1, middle) > 0 &&
         CopyBuffer(m_bbHandle, 2, 0, 1, lower) > 0) {
         rec.bbWidth = (upper[0] - lower[0]) / point;
         rec.distToUpperBB = (upper[0] - rec.openPrice) / point;
         rec.distToLowerBB = (rec.openPrice - lower[0]) / point;
      }
      
      // EMAs
      double emaFast[], emaSlow[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);
      
      if(CopyBuffer(m_emaFastHandle, 0, 0, 1, emaFast) > 0)
         rec.emaFast = emaFast[0];
      if(CopyBuffer(m_emaSlowHandle, 0, 0, 1, emaSlow) > 0)
         rec.emaSlow = emaSlow[0];
      
      // Calculer les métriques EMA enrichies
      if(rec.emaFast > 0 && rec.emaSlow > 0) {
         // Distance entre EMAs en points
         rec.distEMAFastSlow = MathAbs(rec.emaFast - rec.emaSlow) / point;
         
         // Spread EMA en pourcentage
         rec.emaSpread = ((rec.emaFast - rec.emaSlow) / rec.emaSlow) * 100.0;
         
         // Tendance EMA
         rec.emaTrend = (rec.emaFast > rec.emaSlow) ? "UP" : "DOWN";
         
         // Position du prix par rapport aux EMAs
         double maxEMA = MathMax(rec.emaFast, rec.emaSlow);
         double minEMA = MathMin(rec.emaFast, rec.emaSlow);
         
         if(rec.openPrice > maxEMA)
            rec.priceVsEMA = "ABOVE_BOTH";
         else if(rec.openPrice < minEMA)
            rec.priceVsEMA = "BELOW_BOTH";
         else
            rec.priceVsEMA = "BETWEEN";
      }
      
      // ATR
      int atrHandle = iATR(m_symbol, PERIOD_CURRENT, 14);
      if(atrHandle != INVALID_HANDLE) {
         double atr[];
         ArraySetAsSeries(atr, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            rec.atr = atr[0];
         IndicatorRelease(atrHandle);
      }
      
      // Spread
      rec.spread = (SymbolInfoDouble(m_symbol, SYMBOL_ASK) - 
                   SymbolInfoDouble(m_symbol, SYMBOL_BID)) / point;
   }

   // Mettre à jour un trade en cours (appelé à chaque tick)
   void UpdateTrade(ulong ticket) {
      if(!PositionSelectByTicket(ticket)) return;
      
      // Trouver le trade dans nos records
      for(int i = 0; i < ArraySize(m_records); i++) {
         if(m_records[i].ticket == ticket && m_records[i].closeTime == 0) {
            double currentProfit = PositionGetDouble(POSITION_PROFIT);
            
            // Mettre à jour max profit et drawdown
            if(currentProfit > m_records[i].maxProfit)
               m_records[i].maxProfit = currentProfit;
            if(currentProfit < m_records[i].maxDrawdown)
               m_records[i].maxDrawdown = currentProfit;
               
            break;
         }
      }
   }

   // Enregistrer la fermeture d'un trade
   void RecordTradeClose(ulong ticket, string reason = "") {
      // Vérifier si déjà enregistré
      for(int j = 0; j < ArraySize(m_closedTickets); j++) {
         if(m_closedTickets[j] == ticket) {
            return; // Déjà enregistré
         }
      }
      
      // Chercher le trade dans nos records
      int recordIdx = -1;
      for(int i = 0; i < ArraySize(m_records); i++) {
         if(m_records[i].ticket == ticket) {
            recordIdx = i;
            break;
         }
      }
      
      if(recordIdx < 0) return; // Trade non trouvé
      
      TradeRecord rec = m_records[recordIdx];
      
      // Chercher dans l'historique
      if(!HistorySelectByPosition(ticket)) {
         HistorySelect(0, TimeCurrent());
      }
      
      // Obtenir les données de fermeture
      uint total = HistoryDealsTotal();
      bool found = false;
      
      for(uint j = 0; j < total; j++) {
         ulong dealTicket = HistoryDealGetTicket(j);
         if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket &&
            HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            rec.closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            rec.closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            rec.profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            rec.commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            rec.swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            found = true;
            break;
         }
      }
      
      if(!found) return;
      
      // Calculer métriques finales
      rec.duration = (int)((rec.closeTime - rec.openTime) / 60);
      rec.exitReason = reason;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(rec.type == 0) // BUY
         rec.pips = (rec.closePrice - rec.openPrice) / point;
      else // SELL
         rec.pips = (rec.openPrice - rec.closePrice) / point;
      
      // RR réel
      if(rec.slDistance > 0)
         rec.actualRR = rec.pips / rec.slDistance;
      
      // Déterminer la raison de sortie si non spécifiée
      if(reason == "") {
         if(MathAbs(rec.closePrice - rec.tp) < 10 * point)
            rec.exitReason = "TP";
         else if(MathAbs(rec.closePrice - rec.sl) < 10 * point)
            rec.exitReason = "SL";
         else
            rec.exitReason = "Manual/Other";
      }
      
      // Mettre à jour le record
      m_records[recordIdx] = rec;
      
      // Marquer comme fermé
      int size = ArraySize(m_closedTickets);
      ArrayResize(m_closedTickets, size + 1);
      m_closedTickets[size] = ticket;
      
      // Mettre à jour la date du dernier trade
      if(rec.closeTime > m_lastTradeTime) {
         m_lastTradeTime = rec.closeTime;
         RenameCSVWithDates(); // Renommer après chaque fermeture
      }
      
      // Sauvegarder et mettre à jour stats
      SaveToCSV(rec, false);
      UpdateStatistics();
      LogTradeClose(rec);
   }

   // Initialiser le fichier CSV
   void InitializeCSV() {
      m_fileHandle = FileOpen(m_csvFile, FILE_WRITE|FILE_ANSI, ",");
      
      if(m_fileHandle != INVALID_HANDLE) {
         if(FileSize(m_fileHandle) == 0) {
            // Écrire l'en-tête complet avec les nouvelles colonnes
            string header = "Ticket,OpenTime,CloseTime,Symbol,Type,Volume," +
               "OpenPrice,ClosePrice,SL,TP,Profit,Pips," +
               "Commission,Swap,PlannedRR,ActualRR," +
               "RSI,ATR,Spread,BBWidth,DistUpperBB,DistLowerBB," +
               "EMA50,EMA100," +
               "DistEMAFastSlow,EMASpread,EMATrend,PriceVsEMA," +
               "DivAngle,DivStrength,DivBars," +
               "Hour,Minute,DayOfWeek," +
               "Duration,MaxProfit,MaxDD,ExitReason,Mode,Divergence,EMAMode," +
               "BB_Period,BB_Dev,RSI_Period,RSI_Oversold,RSI_Overbought," +
               "EMA_Fast,EMA_Slow,EMA_ZoneDist,Risk%,MinRR," +
               "SL_Period,TP_Period,ATR_Mult,OutsidePad,BodyOnly,UseRSI,UseEMA,UseDiv\n";
            
            FileWriteString(m_fileHandle, header);
         }
         FileClose(m_fileHandle);
      } else {
         Print("ERREUR: Impossible de créer le fichier CSV: ", m_csvFile);
      }
   }

   // Sauvegarder dans CSV
   void SaveToCSV(const TradeRecord &rec, bool isOpen) {
      int handle = FileOpen(m_csvFile, FILE_WRITE|FILE_READ|FILE_ANSI);
      
      if(handle != INVALID_HANDLE) {
         FileSeek(handle, 0, SEEK_END);
         
         string row = StringFormat("%d,%s,%s,%s,%s,%.2f,%.5f,%.5f,%.5f,%.5f,%.2f,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.5f,%.1f,%.1f,%.1f,%.1f,%.5f,%.5f,%.1f,%.4f,%s,%s,%.2f,%.6f,%d,%d,%d,%d,%d,%.2f,%.2f,%s,%s,%s,%s,%d,%.1f,%d,%.1f,%.1f,%d,%d,%.1f,%.2f,%.1f,%d,%d,%.1f,%d,%s,%s,%s,%s\n",
            rec.ticket,
            TimeToString(rec.openTime, TIME_DATE|TIME_SECONDS),
            isOpen ? "" : TimeToString(rec.closeTime, TIME_DATE|TIME_SECONDS),
            rec.symbol,
            rec.type == 0 ? "BUY" : "SELL",
            rec.volume,
            rec.openPrice,
            isOpen ? 0 : rec.closePrice,
            rec.sl,
            rec.tp,
            isOpen ? 0 : rec.profit,
            isOpen ? 0 : rec.pips,
            isOpen ? 0 : rec.commission,
            isOpen ? 0 : rec.swap,
            rec.plannedRR,
            isOpen ? 0 : rec.actualRR,
            rec.rsi,
            rec.atr,
            rec.spread,
            rec.bbWidth,
            rec.distToUpperBB,
            rec.distToLowerBB,
            rec.emaFast,
            rec.emaSlow,
            rec.distEMAFastSlow,
            rec.emaSpread,
            rec.emaTrend,
            rec.priceVsEMA,
            rec.divAngle,
            rec.divStrength,
            rec.divBars,
            rec.hour,
            rec.minute,
            rec.dayOfWeek,
            isOpen ? 0 : rec.duration,
            isOpen ? 0 : rec.maxProfit,
            isOpen ? 0 : rec.maxDrawdown,
            rec.exitReason,
            rec.mode,
            rec.divergence ? "YES" : "NO",
            rec.emaMode,
            rec.bb_period,
            rec.bb_deviation,
            rec.rsi_period_used,
            rec.rsi_oversold_level,
            rec.rsi_overbought_level,
            rec.ema_fast_period,
            rec.ema_slow_period,
            rec.ema_zone_distance,
            rec.risk_percent_used,
            rec.min_rr_config,
            rec.sl_period_config,
            rec.tp_period_config,
            rec.atr_multiplier,
            rec.outside_padding,
            rec.body_must_outside ? "YES" : "NO",
            rec.use_rsi_filter ? "YES" : "NO",
            rec.use_ema_filter ? "YES" : "NO",
            rec.use_div_validator ? "YES" : "NO"
         );
         
         FileWriteString(handle, row);
         FileClose(handle);
      }
   }

   // Logs détaillés
   void LogTradeOpen(const TradeRecord &rec) {
      Print("=== NOUVEAU TRADE OUVERT ===");
      Print("Ticket: ", rec.ticket, " | ", rec.type == 0 ? "BUY" : "SELL", 
            " | Volume: ", rec.volume);
      Print("Entry: ", rec.openPrice, " | SL: ", rec.sl, " | TP: ", rec.tp);
      Print("RR prévu: 1:", DoubleToString(rec.plannedRR, 2));
      Print("RSI: ", DoubleToString(rec.rsi, 2), 
            " | Spread: ", DoubleToString(rec.spread, 1), " pts");
      Print("BB Width: ", DoubleToString(rec.bbWidth, 1), " pts");
      Print("EMA: Dist=", DoubleToString(rec.distEMAFastSlow, 1), "pts | Spread=", 
            DoubleToString(rec.emaSpread, 4), "% | Trend=", rec.emaTrend, 
            " | Price=", rec.priceVsEMA);
      if(rec.divergence) {
         Print("Divergence: Angle=", DoubleToString(rec.divAngle, 2), "° | Strength=", 
               DoubleToString(rec.divStrength, 6), " | Bars=", rec.divBars);
      }
      Print("Heure: ", rec.hour, ":", rec.minute, 
            " | Jour: ", rec.dayOfWeek);
      Print("Mode: ", rec.mode, " | Divergence: ", rec.divergence ? "OUI" : "NON",
            " | EMA: ", rec.emaMode);
   }

   void LogTradeClose(const TradeRecord &rec) {
      Print("=== TRADE FERMÉ ===");
      Print("Ticket: ", rec.ticket, " | Profit: ", rec.profit);
      Print("Pips: ", rec.pips, " | RR réel: 1:", DoubleToString(rec.actualRR, 2));
      Print("Durée: ", rec.duration, " min | Raison: ", rec.exitReason);
      Print("Max Profit atteint: ", rec.maxProfit);
      Print("Max Drawdown: ", rec.maxDrawdown);
   }

   // Mettre à jour les statistiques
   void UpdateStatistics() {
      m_stats.totalTrades = 0;
      m_stats.wins = 0;
      m_stats.losses = 0;
      m_stats.totalProfit = 0;
      m_stats.totalLoss = 0;
      m_stats.bestTrade = 0;
      m_stats.worstTrade = 0;
      
      double sumRR = 0;
      double sumPips = 0;
      
      for(int i = 0; i < ArraySize(m_records); i++) {
         if(m_records[i].closeTime > 0) {
            m_stats.totalTrades++;
            
            if(m_records[i].profit > 0) {
               m_stats.wins++;
               m_stats.totalProfit += m_records[i].profit;
               if(m_records[i].profit > m_stats.bestTrade)
                  m_stats.bestTrade = m_records[i].profit;
            } else {
               m_stats.losses++;
               m_stats.totalLoss += MathAbs(m_records[i].profit);
               if(m_records[i].profit < m_stats.worstTrade)
                  m_stats.worstTrade = m_records[i].profit;
            }
            
            sumRR += m_records[i].actualRR;
            sumPips += m_records[i].pips;
         }
      }
      
      // Calculer les moyennes et ratios
      if(m_stats.totalTrades > 0) {
         m_stats.winRate = (double)m_stats.wins / m_stats.totalTrades * 100;
         m_stats.avgRR = sumRR / m_stats.totalTrades;
      }
      
      if(m_stats.wins > 0)
         m_stats.avgWin = m_stats.totalProfit / m_stats.wins;
         
      if(m_stats.losses > 0)
         m_stats.avgLoss = m_stats.totalLoss / m_stats.losses;
         
      if(m_stats.totalLoss > 0)
         m_stats.profitFactor = m_stats.totalProfit / m_stats.totalLoss;
   }

   // Afficher un rapport complet
   void PrintReport() {
      UpdateStatistics();
      
      Print("╔════════════════════════════════════════╗");
      Print("║     RAPPORT DE PERFORMANCE COMPLET     ║");
      Print("╠════════════════════════════════════════╣");
      Print("║ Total Trades: ", m_stats.totalTrades);
      Print("║ Gagnants: ", m_stats.wins, " (", DoubleToString(m_stats.winRate, 1), "%)");
      Print("║ Perdants: ", m_stats.losses);
      Print("║ Profit Net: $", DoubleToString(m_stats.totalProfit - m_stats.totalLoss, 2));
      Print("║ Profit Factor: ", DoubleToString(m_stats.profitFactor, 2));
      Print("║ Gain Moyen: $", DoubleToString(m_stats.avgWin, 2));
      Print("║ Perte Moyenne: $", DoubleToString(m_stats.avgLoss, 2));
      Print("║ RR Moyen: 1:", DoubleToString(m_stats.avgRR, 2));
      Print("║ Meilleur Trade: $", DoubleToString(m_stats.bestTrade, 2));
      Print("║ Pire Trade: $", DoubleToString(m_stats.worstTrade, 2));
      Print("╚════════════════════════════════════════╝");
      
      // Analyse par heure
      Print("\n=== PERFORMANCE PAR HEURE ===");
      for(int h = 0; h < 24; h++) {
         int count = 0;
         double profit = 0;
         int wins = 0;
         
         for(int i = 0; i < ArraySize(m_records); i++) {
            if(m_records[i].hour == h && m_records[i].closeTime > 0) {
               count++;
               profit += m_records[i].profit;
               if(m_records[i].profit > 0) wins++;
            }
         }
         
         if(count > 0) {
            double wr = (double)wins / count * 100;
            Print(StringFormat("%02d:00 - Trades: %d | Profit: $%.2f | WR: %.1f%%", 
                  h, count, profit, wr));
         }
      }
      
      // Analyse par jour
      Print("\n=== PERFORMANCE PAR JOUR ===");
      string days[] = {"Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"};
      
      for(int d = 0; d < 7; d++) {
         int count = 0;
         double profit = 0;
         int wins = 0;
         
         for(int i = 0; i < ArraySize(m_records); i++) {
            if(m_records[i].dayOfWeek == d && m_records[i].closeTime > 0) {
               count++;
               profit += m_records[i].profit;
               if(m_records[i].profit > 0) wins++;
            }
         }
         
         if(count > 0) {
            double wr = (double)wins / count * 100;
            Print(StringFormat("%s: Trades: %d | Profit: $%.2f | WR: %.1f%%", 
                  days[d], count, profit, wr));
         }
      }
   }

   // Getters pour accès externe
   double GetWinRate() { return m_stats.winRate; }
   double GetProfitFactor() { return m_stats.profitFactor; }
   double GetAvgRR() { return m_stats.avgRR; }
   int GetTotalTrades() { return m_stats.totalTrades; }
};

