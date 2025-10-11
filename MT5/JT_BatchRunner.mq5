//+------------------------------------------------------------------+
//|                                              JT_BatchRunner.mq5  |
//|                      EA pour tests batch automatisés             |
//|  Lit un fichier CSV de paramètres et lance des séries de tests  |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>
#include "common/JT_Indicators.mqh"
#include "common/JT_Positions.mqh"
#include "common/JT_Utils.mqh"
#include "common/JT_DivergenceValidator.mqh"
#include "common/JT_TradeTracker.mqh"
CTrade trade;

//--- Inputs pour le fichier de configuration
input string ConfigFile = "JT_BatchConfig.csv";  // Fichier CSV avec les paramètres
input int    TestID = 1;                         // ID du test à exécuter (ligne dans CSV)
input string InpSymbol = "";                     // Symbole (vide = _Symbol)
input ENUM_TIMEFRAMES InpTF = PERIOD_CURRENT;    // Timeframe

//--- Structure pour stocker une configuration de test
struct TestConfig
{
   int testID;
   string testName;
   
   // Paramètres BB
   int bb_period;
   double bb_dev;
   int bb_shift;
   
   // Paramètres RSI
   int rsi_period;
   double rsi_oversold;
   double rsi_overbought;
   
   // Paramètres EMA
   bool use_ema;
   int ema_fast;
   int ema_slow;
   int ema_mode;
   double ema_zone_distance;
   
   // Money Management
   double risk_percent;
   int sl_period;
   int tp_period;
   double min_rr;
   double atr_multiplier;
   int atr_period;
   
   // Entrée
   int mode;  // 0=REVERSION, 1=BREAKOUT
   int outside_padding;
   bool body_must_be_outside;
   
   // Divergence
   bool use_divergence;
   double div_rsi_buy;
   double div_rsi_sell;
   int div_swing_length;
   
   // Magic Number
   ulong magic;
};

//--- Variables globales
TestConfig currentConfig;
string resultsFile = "";
int totalTrades = 0;
double initialBalance = 0;
double maxBalance = 0;
double maxDrawdown = 0;
datetime testStartTime;

//--- Indicateurs et buffers
IndicatorHandles indicators;
IndicatorBuffers buffers;
int EMA_Fast_Handle = INVALID_HANDLE;
int EMA_Slow_Handle = INVALID_HANDLE;

//--- Divergence Validator
JTDivergenceValidator divValidator;

//--- Trade Tracker
JTTradeTracker* tracker = NULL;

//--- Utils
string Sym() { return (InpSymbol=="" ? _Symbol : InpSymbol); }
ENUM_TIMEFRAMES TF(){ return (InpTF==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF); }

//--- Variables pour gestion des barres
datetime last_bar = 0;
bool g_running = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   testStartTime = TimeCurrent();
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   maxBalance = initialBalance;
   
   // Charger la configuration depuis le CSV
   if(!LoadConfig(ConfigFile, TestID, currentConfig))
   {
      Print("❌ Erreur: Impossible de charger la configuration Test ID ", TestID);
      return INIT_FAILED;
   }
   
   // Afficher la configuration chargée
   PrintConfig(currentConfig);
   
   // Initialiser le symbole et timeframe
   string s = Sym(); 
   ENUM_TIMEFRAMES t = TF();
   
   // Initialiser les indicateurs via la structure
   if(!InitIndicators(indicators, s, t, currentConfig.bb_period, currentConfig.bb_dev, currentConfig.bb_shift, currentConfig.rsi_period)) {
      Print("❌ Erreur d'initialisation des indicateurs");
      return INIT_FAILED;
   }
   
   // Initialiser les EMAs si le filtre est activé
   if(currentConfig.use_ema) {
      EMA_Fast_Handle = iMA(s, t, currentConfig.ema_fast, 0, MODE_EMA, PRICE_CLOSE);
      EMA_Slow_Handle = iMA(s, t, currentConfig.ema_slow, 0, MODE_EMA, PRICE_CLOSE);
      
      if(EMA_Fast_Handle == INVALID_HANDLE || EMA_Slow_Handle == INVALID_HANDLE) {
         Print("❌ Erreur d'initialisation des EMAs");
         return INIT_FAILED;
      }
   }
   
   // Initialiser le validateur de divergence si activé
   if(currentConfig.use_divergence) {
      if(!divValidator.Init(s, t, currentConfig.rsi_period, currentConfig.div_rsi_buy, currentConfig.div_rsi_sell, currentConfig.div_swing_length)) {
         Print("❌ Erreur d'initialisation du validateur de divergence");
         return INIT_FAILED;
      }
   }
   
   // Initialiser le Trade Tracker
   tracker = new JTTradeTracker(
      s,                                    // Symbol
      currentConfig.magic,                  // Magic number
      currentConfig.bb_period,              // BB period
      currentConfig.bb_dev,                 // BB deviation
      currentConfig.rsi_period,             // RSI period
      currentConfig.use_ema ? currentConfig.ema_fast : 50,   // EMA fast
      currentConfig.use_ema ? currentConfig.ema_slow : 100   // EMA slow
   );
   
   // Configurer le trade
   trade.SetExpertMagicNumber((long)currentConfig.magic);
   
   // Créer le fichier de résultats
   resultsFile = "BatchResults_Test" + IntegerToString(TestID) + "_" + 
                 TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
   
   InitResultsFile(resultsFile);
   
   g_running = true;
   
   Print("✅ EA Batch Runner initialisé avec succès");
   Print("📁 Fichier résultats: ", resultsFile);
   Print("🎯 Configuration: ", currentConfig.testName);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_running = false;
   
   // Libérer les ressources
   ReleaseIndicators(indicators);
   
   if(EMA_Fast_Handle != INVALID_HANDLE) {
      IndicatorRelease(EMA_Fast_Handle);
      EMA_Fast_Handle = INVALID_HANDLE;
   }
   if(EMA_Slow_Handle != INVALID_HANDLE) {
      IndicatorRelease(EMA_Slow_Handle);
      EMA_Slow_Handle = INVALID_HANDLE;
   }
   
   // Afficher le rapport final et libérer le tracker
   if(tracker != NULL) {
      tracker.PrintReport();
      delete tracker;
      tracker = NULL;
   }
   
   // Calculer et sauvegarder les statistiques finales
   SaveFinalStats();
   
   Print("═══════════════════════════════════════════════════");
   Print("Test ID ", currentConfig.testID, " terminé: ", currentConfig.testName);
   Print("Total trades: ", totalTrades);
   Print("Balance finale: ", AccountInfoDouble(ACCOUNT_BALANCE));
   Print("Max DD: ", DoubleToString(maxDrawdown, 2), "%");
   Print("═══════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_running) return;
   
   string s = Sym(); 
   ENUM_TIMEFRAMES t = TF();
   
   // Mettre à jour les statistiques en temps réel
   UpdateStats();
   
   // Suivre les trades actifs pour max profit/DD
   if(tracker != NULL) {
      for(int i = PositionsTotal()-1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == currentConfig.magic) {
               tracker.UpdateTrade(ticket);
            }
         }
      }
   }
   
   // Gestion en continu des positions
   ManageOpenPositions(s);
   
   // Vérifier les trades fermés automatiquement
   CheckClosedTrades();

   // Détection de nouvelle bougie + logique d'entrée
   if(!NewBar(s, t, last_bar)) return;
   
   // Si le validateur de divergence est activé, vérifier d'abord
   if(currentConfig.use_divergence) {
      int divSignal = divValidator.ValidateDivergence();
      if(divSignal != 0) {
         // Divergence validée, exécuter le trade
         ExecuteTradeFromDivergence(divSignal);
         
         // Enregistrer les métriques de divergence dans le tracker
         if(tracker != NULL) {
            tracker.SetDivergenceData(
               divValidator.GetLastDivergenceAngle(),
               divValidator.GetLastDivergenceStrength(),
               divValidator.GetLastDivergenceBars()
            );
         }
         return;
      }
   }
   
   Process();
}

//+------------------------------------------------------------------+
//| Fonction pour détecter une nouvelle barre                        |
//+------------------------------------------------------------------+
bool NewBar(const string s, ENUM_TIMEFRAMES tf, datetime &last_time)
{
   MqlRates r[];
   if(CopyRates(s, tf, 0, 2, r) < 2) return false;
   ArraySetAsSeries(r, true);
   if(r[0].time != last_time){ last_time = r[0].time; return true; }
   return false;
}

//+------------------------------------------------------------------+
//| Logique principale de trading                                    |
//+------------------------------------------------------------------+
void Process()
{
   int dir = SignalFromClosedBarStrict();
   
   if(dir == 0) return;
   
   if(HaveOpenPos(Sym())) return;

   // Appliquer le filtre de direction
   if(currentConfig.mode == 0 && dir > 0) return; // REVERSION: seulement SELL si au-dessus
   if(currentConfig.mode == 1 && dir < 0) return; // BREAKOUT: seulement BUY si au-dessus
   
   // Marquer le Free Candle sur le graphique
   MarkFreeCandleOnChart(dir);
   
   // Si le validateur de divergence est activé, mémoriser le free candle
   if(currentConfig.use_divergence) {
      string s = Sym();
      MqlTick tick;
      if(!SymbolInfoTick(s, tick)) return;
      
      double priceLevel = (dir > 0) ? tick.bid : tick.ask;
      divValidator.RememberFreeCandle(1, priceLevel, dir);
      return;
   }

   ExecuteTrade(dir);
}

//+------------------------------------------------------------------+
//| Détection du signal depuis la barre fermée                       |
//+------------------------------------------------------------------+
int SignalFromClosedBarStrict()
{
   string s = Sym(); 
   ENUM_TIMEFRAMES t = TF();
   
   // Bougie N-1 (fermée)
   MqlRates r[]; 
   if(CopyRates(s, t, 0, 3, r) < 3) return 0; 
   ArraySetAsSeries(r, true);
   
   double o = r[1].open, h = r[1].high, l = r[1].low, c = r[1].close;

   // Récupérer les données BB et RSI
   if(!GetIndicatorData(indicators, buffers, 3, false)) return 0;
   
   double upper = buffers.BBUpper[1];
   double lower = buffers.BBLower[1];

   bool red = (o > c);
   bool green = (c > o);

   // Utiliser la fonction IsFreeCandle pour détecter si la bougie est hors bandes
   bool isFreeCandle = IsFreeCandle(o, h, l, c, upper, lower, currentConfig.outside_padding, currentConfig.body_must_be_outside);
   
   if(!isFreeCandle) return 0;
   
   // Déterminer si la bougie est au-dessus ou en-dessous
   bool isAboveBand = false;
   bool isBelowBand = false;
   
   if(currentConfig.body_must_be_outside) {
      double bodyHigh = MathMax(o, c);
      double bodyLow = MathMin(o, c);
      isAboveBand = (bodyLow > upper + currentConfig.outside_padding * _Point);
      isBelowBand = (bodyHigh < lower - currentConfig.outside_padding * _Point);
   } else {
      isAboveBand = (l > upper + currentConfig.outside_padding * _Point);
      isBelowBand = (h < lower - currentConfig.outside_padding * _Point);
   }
   
   bool outsideBearAbove = isAboveBand && red;
   bool outsideBullBelow = isBelowBand && green;

   // Déterminer le signal potentiel
   int signal = 0;
   if(currentConfig.mode == 0) { // REVERSION
      if(outsideBearAbove) signal = -1; // SELL
      if(outsideBullBelow) signal = +1; // BUY
   } else { // BREAKOUT
      if(isAboveBand) signal = +1;      // BUY breakout
      if(isBelowBand) signal = -1;      // SELL breakout
   }
   
   if(signal == 0) return 0;
   
   // Appliquer le filtre EMA
   if(currentConfig.use_ema && !CheckEMAFilter(signal)) {
      return 0;
   }
   
   // Appliquer le filtre RSI
   double currentRSI = buffers.RSI[1];
   
   if(signal > 0 && currentRSI >= currentConfig.rsi_oversold) {
      return 0;
   }
   
   if(signal < 0 && currentRSI <= currentConfig.rsi_overbought) {
      return 0;
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| Vérifier le filtre EMA                                           |
//+------------------------------------------------------------------+
bool CheckEMAFilter(int signalDirection)
{
   if(!currentConfig.use_ema) return true;
   
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   if(CopyBuffer(EMA_Fast_Handle, 0, 0, 2, emaFast) < 2) return false;
   if(CopyBuffer(EMA_Slow_Handle, 0, 0, 2, emaSlow) < 2) return false;
   
   string s = Sym();
   double price = SymbolInfoDouble(s, SYMBOL_BID);
   bool uptrend = (emaFast[0] > emaSlow[0]);
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   
   switch(currentConfig.ema_mode) {
      case 0: { // TREND
         if(signalDirection > 0) { // BUY
            return uptrend && (price > emaSlow[0]);
         } else { // SELL
            return !uptrend && (price < emaSlow[0]);
         }
      }
         
      case 1: { // COUNTER
         double distance = MathAbs(price - emaFast[0]) / point;
         if(signalDirection > 0) { // BUY
            return !uptrend && (price < emaFast[0]) && (distance > currentConfig.ema_zone_distance);
         } else { // SELL
            return uptrend && (price > emaFast[0]) && (distance > currentConfig.ema_zone_distance);
         }
      }
         
      case 2: { // ZONE
         double maxEMA = MathMax(emaFast[0], emaSlow[0]);
         double minEMA = MathMin(emaFast[0], emaSlow[0]);
         bool inZone = (price < maxEMA + currentConfig.ema_zone_distance * point) && 
                       (price > minEMA - currentConfig.ema_zone_distance * point);
         return !inZone;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Vérifier s'il y a une position ouverte                           |
//+------------------------------------------------------------------+
bool HaveOpenPos(const string s)
{
   int direction = 0;
   ulong ticket = 0;
   return HasOpenPosition(s, currentConfig.magic, direction, ticket);
}

//+------------------------------------------------------------------+
//| Normaliser le volume                                             |
//+------------------------------------------------------------------+
double NormalizeVolume(double lots, const string s)
{
   double minv = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   lots = MathMax(minv, MathMin(maxv, lots));
   return MathRound(lots/step)*step;
}

//+------------------------------------------------------------------+
//| Calculer les lots par risque                                     |
//+------------------------------------------------------------------+
double CalcLotsByRisk(const string s, double sl_dist_price)
{
   if(sl_dist_price <= 0) return 0.0;
   
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk = eq * (currentConfig.risk_percent / 100.0);

   double tick_value = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
   if(tick_value <= 0 || tick_size <= 0) return 0.0;

   double money_per_lot = (sl_dist_price / tick_size) * tick_value;
   if(money_per_lot <= 0) return 0.0;

   return NormalizeVolume(risk / money_per_lot, s);
}

//+------------------------------------------------------------------+
//| Exécuter un trade                                                |
//+------------------------------------------------------------------+
void ExecuteTrade(int dir)
{
   string s = Sym();
   ENUM_TIMEFRAMES t = TF();
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   
   // Variables pour SL et TP
   double sl = 0, tp = 0;
   bool isBuy = (dir > 0);
   
   // Calculer SL/TP basés sur les plus hauts/plus bas avec ATR fallback
   if(!CalculateSwingSLTP(s, t, isBuy, currentConfig.sl_period, currentConfig.tp_period, sl, tp, 0.0, currentConfig.min_rr, 1000, currentConfig.atr_multiplier, currentConfig.atr_period)) {
      Print("❌ Erreur lors du calcul des niveaux SL/TP");
      return;
   }
   
   // Calculer le volume en fonction du risque
   double riskPrice = isBuy ? (bid - sl) : (sl - ask);
   if(riskPrice <= 0) {
      Print("❌ Distance de SL invalide");
      return;
   }
   
   double lots = CalcLotsByRisk(s, riskPrice);
   
   // Calculer le ratio risque/récompense (RR)
   double entryPrice = isBuy ? ask : bid;
   double reward = isBuy ? (tp - entryPrice) : (entryPrice - tp);
   double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
   double rr = (risk > 0) ? (reward / risk) : 0;
   
   // Vérifier le seuil RR minimum
   if(currentConfig.min_rr > 0 && rr < currentConfig.min_rr) {
      return;
   }
   
   // Récupérer la valeur RSI actuelle pour le commentaire
   int rsiI = (int)MathRound(buffers.RSI[1]);
   
   // Préparer le commentaire compact
   string dirStr = isBuy ? "BUY" : "SELL";
   string orderComment = StringFormat("BB %s|R:%.2f|I:%d", dirStr, rr, rsiI);
   
   // Ouvrir la position
   if(isBuy) {
      if(lots > 0) {
         OpenBuyPosition(trade, s, lots, ask, sl, tp, orderComment);
         if(trade.ResultOrder() > 0 && tracker != NULL) {
            string tradeMode = (currentConfig.mode == 0 ? "REVERSION" : "BREAKOUT");
            string emaMode = "";
            if(currentConfig.use_ema) {
               switch(currentConfig.ema_mode) {
                  case 0: emaMode = "TREND"; break;
                  case 1: emaMode = "COUNTER"; break;
                  case 2: emaMode = "ZONE"; break;
               }
            }
            tracker.RecordTradeOpen(trade.ResultOrder(), tradeMode, false, emaMode);
         }
      }
   } else {
      if(lots > 0) {
         OpenSellPosition(trade, s, lots, bid, sl, tp, orderComment);
         if(trade.ResultOrder() > 0 && tracker != NULL) {
            string tradeMode = (currentConfig.mode == 0 ? "REVERSION" : "BREAKOUT");
            string emaMode = "";
            if(currentConfig.use_ema) {
               switch(currentConfig.ema_mode) {
                  case 0: emaMode = "TREND"; break;
                  case 1: emaMode = "COUNTER"; break;
                  case 2: emaMode = "ZONE"; break;
               }
            }
            tracker.RecordTradeOpen(trade.ResultOrder(), tradeMode, false, emaMode);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction pour exécuter un trade validé par divergence            |
//+------------------------------------------------------------------+
void ExecuteTradeFromDivergence(int dir)
{
   string s = Sym();
   
   if(HaveOpenPos(s)) return;
   
   ExecuteTrade(dir);
}

//+------------------------------------------------------------------+
//| Marquer le Free Candle sur le graphique                          |
//+------------------------------------------------------------------+
void MarkFreeCandleOnChart(int dir)
{
   string s = Sym();
   ENUM_TIMEFRAMES t = TF();
   
   MqlRates rates[];
   if(CopyRates(s, t, 1, 1, rates) > 0) {
      double high = rates[0].high;
      double low = rates[0].low;
      datetime time = rates[0].time;
      
      double arrowPrice = (dir > 0) ? low : high;
      
      MarkFreeCandle(time, high, low, arrowPrice, dir, t, 
                    true, true, false, false, "FreeCandle");
   }
}

//+------------------------------------------------------------------+
//| Gestion des positions ouvertes                                   |
//+------------------------------------------------------------------+
void ManageOpenPositions(const string s)
{
   // Récupérer les bandes de Bollinger pour les bougies 0 et 1
   if(!GetIndicatorData(indicators, buffers, 2, false)) return;
   
   double upper1 = buffers.BBUpper[1];
   double middle1 = buffers.BBMiddle[1];
   double lower1 = buffers.BBLower[1];

   // extrêmes bougie en cours
   MqlRates bar[1]; 
   if(CopyRates(s, TF(), 0, 1, bar) < 1) return;
   ArraySetAsSeries(bar, true);
   double barHigh = bar[0].high, barLow = bar[0].low;

   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   double pad = 5 * point; // TouchPadPoints fixe pour le batch
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);

   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)currentConfig.magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      // Fermer si touche la bande opposée
      bool touchedOpposite = false;
      if(type == POSITION_TYPE_BUY) {
         touchedOpposite = (barHigh >= upper1-pad || bid >= upper1-pad);
      }
      if(type == POSITION_TYPE_SELL) {
         touchedOpposite = (barLow <= lower1+pad || ask <= lower1+pad);
      }
      
      if(touchedOpposite) {
         ClosePosition(trade, tk, "Band touch exit", 0);
         if(tracker != NULL) {
            tracker.RecordTradeClose(tk, "Band Touch");
         }
         continue;
      }

      // BE sur médiane
      if(type == POSITION_TYPE_BUY && (barHigh >= middle1-pad || bid >= middle1-pad)) {
         double newSL = op;
         if(sl < newSL) ModifyPosition(trade, tk, newSL, tp);
      }
      if(type == POSITION_TYPE_SELL && (barLow <= middle1+pad || ask <= middle1+pad)) {
         double newSL = op;
         if(sl == 0.0 || sl > newSL) ModifyPosition(trade, tk, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier les trades fermés automatiquement                       |
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   if(tracker == NULL) return;
   
   static datetime lastCheck = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastCheck < 30) return;
   lastCheck = currentTime;
   
   if(!HistorySelect(currentTime - 86400, currentTime)) return;
   
   uint totalDeals = HistoryDealsTotal();
   
   for(uint i = 0; i < totalDeals; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == currentConfig.magic &&
         HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         
         ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         
         string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
         string reason = "";
         
         if(StringFind(comment, "tp") >= 0 || StringFind(comment, "TP") >= 0)
            reason = "TP";
         else if(StringFind(comment, "sl") >= 0 || StringFind(comment, "SL") >= 0)
            reason = "SL";
         else
            reason = "Auto Close";
         
         tracker.RecordTradeClose(posTicket, reason);
      }
   }
}

//+------------------------------------------------------------------+
//| Charger la configuration depuis un CSV                           |
//+------------------------------------------------------------------+
bool LoadConfig(string filename, int testID, TestConfig &config)
{
   int handle = FileOpen(filename, FILE_READ|FILE_CSV|FILE_ANSI, ",");
   
   if(handle == INVALID_HANDLE) {
      Print("❌ Erreur: fichier ", filename, " introuvable");
      return false;
   }
   
   // Lire l'en-tête (première ligne)
   string header = FileReadString(handle);
   
   // Chercher la ligne correspondant au testID
   bool found = false;
   
   while(!FileIsEnding(handle)) {
      int id = (int)FileReadNumber(handle);
      
      if(id == testID) {
         found = true;
         
         // Lire tous les paramètres
         config.testID = id;
         config.testName = FileReadString(handle);
         config.bb_period = (int)FileReadNumber(handle);
         config.bb_dev = FileReadNumber(handle);
         config.bb_shift = 0; // Non dans le CSV, valeur par défaut
         config.rsi_period = (int)FileReadNumber(handle);
         config.rsi_oversold = FileReadNumber(handle);
         config.rsi_overbought = FileReadNumber(handle);
         config.use_ema = (bool)FileReadNumber(handle);
         config.ema_fast = (int)FileReadNumber(handle);
         config.ema_slow = (int)FileReadNumber(handle);
         config.ema_mode = (int)FileReadNumber(handle);
         config.ema_zone_distance = 20.0; // Valeur par défaut
         config.risk_percent = FileReadNumber(handle);
         config.sl_period = (int)FileReadNumber(handle);
         config.tp_period = (int)FileReadNumber(handle);
         config.min_rr = FileReadNumber(handle);
         config.atr_multiplier = 2.0; // Valeur par défaut
         config.atr_period = 14; // Valeur par défaut
         config.mode = (int)FileReadNumber(handle);
         config.outside_padding = (int)FileReadNumber(handle);
         config.body_must_be_outside = (bool)FileReadNumber(handle);
         config.use_divergence = (bool)FileReadNumber(handle);
         config.div_rsi_buy = FileReadNumber(handle);
         config.div_rsi_sell = FileReadNumber(handle);
         config.div_swing_length = 5; // Valeur par défaut
         config.magic = 20250000 + testID; // Magic unique par test
         
         break;
      } else {
         // Sauter cette ligne
         FileReadString(handle);
      }
   }
   
   FileClose(handle);
   
   return found;
}

//+------------------------------------------------------------------+
//| Afficher la configuration                                         |
//+------------------------------------------------------------------+
void PrintConfig(TestConfig &config)
{
   Print("═══════════════════════════════════════════════════");
   Print("CONFIGURATION TEST #", config.testID);
   Print("Nom: ", config.testName);
   Print("───────────────────────────────────────────────────");
   Print("BB: Période=", config.bb_period, " Dev=", config.bb_dev);
   Print("RSI: Période=", config.rsi_period, " OS=", config.rsi_oversold, 
         " OB=", config.rsi_overbought);
   
   if(config.use_ema) {
      string emaMode = "";
      switch(config.ema_mode) {
         case 0: emaMode = "TREND"; break;
         case 1: emaMode = "COUNTER"; break;
         case 2: emaMode = "ZONE"; break;
      }
      Print("EMA: Fast=", config.ema_fast, " Slow=", config.ema_slow, 
            " Mode=", emaMode);
   }
   
   Print("Risk: ", config.risk_percent, "% | RR: 1:", config.min_rr);
   Print("SL/TP: ", config.sl_period, "/", config.tp_period, " périodes");
   Print("Mode: ", (config.mode == 0 ? "REVERSION" : "BREAKOUT"));
   Print("Magic: ", config.magic);
   
   if(config.use_divergence) {
      Print("Divergence: RSI Buy<", config.div_rsi_buy, 
            " Sell>", config.div_rsi_sell);
   }
   
   Print("═══════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Initialiser le fichier de résultats                              |
//+------------------------------------------------------------------+
void InitResultsFile(string filename)
{
   int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
   
   if(handle == INVALID_HANDLE) {
      Print("❌ Erreur: impossible de créer ", filename);
      return;
   }
   
   // En-tête CSV
   FileWrite(handle, "Timestamp", "TestID", "TestName", "TotalTrades", 
             "Balance", "Equity", "Profit%", "ProfitFactor", "WinRate%", 
             "AvgWin", "AvgLoss", "MaxDD%", "Sharpe", "Status");
   
   FileClose(handle);
   
   Print("✅ Fichier résultats créé: ", filename);
}

//+------------------------------------------------------------------+
//| Mettre à jour les statistiques en temps réel                     |
//+------------------------------------------------------------------+
void UpdateStats()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Suivre le max pour calculer le drawdown
   if(currentBalance > maxBalance)
      maxBalance = currentBalance;
   
   // Calculer le drawdown actuel
   if(maxBalance > 0) {
      double currentDD = ((maxBalance - currentBalance) / maxBalance) * 100.0;
      if(currentDD > maxDrawdown)
         maxDrawdown = currentDD;
   }
   
   // Compter les trades
   totalTrades = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         if(PositionGetInteger(POSITION_MAGIC) == currentConfig.magic) {
            totalTrades++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sauvegarder les statistiques finales                             |
//+------------------------------------------------------------------+
void SaveFinalStats()
{
   int handle = FileOpen(resultsFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
   
   if(handle == INVALID_HANDLE) {
      Print("❌ Erreur: impossible d'ouvrir ", resultsFile);
      return;
   }
   
   // Aller à la fin du fichier
   FileSeek(handle, 0, SEEK_END);
   
   // Calculer les statistiques
   double finalBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profitPercent = ((finalBalance - initialBalance) / initialBalance) * 100.0;
   
   // Récupérer les stats depuis l'historique
   HistorySelect(testStartTime, TimeCurrent());
   
   int totalDeals = HistoryDealsTotal();
   int wins = 0;
   int losses = 0;
   double totalWinProfit = 0;
   double totalLossProfit = 0;
   
   for(int i = 0; i < totalDeals; i++) {
      ulong ticket = HistoryDealGetTicket(i);
      
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == currentConfig.magic) {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         
         if(profit > 0) {
            wins++;
            totalWinProfit += profit;
         } else if(profit < 0) {
            losses++;
            totalLossProfit += MathAbs(profit);
         }
      }
   }
   
   double winRate = (wins + losses > 0) ? (wins * 100.0 / (wins + losses)) : 0;
   double avgWin = (wins > 0) ? (totalWinProfit / wins) : 0;
   double avgLoss = (losses > 0) ? (totalLossProfit / losses) : 0;
   double profitFactor = (totalLossProfit > 0) ? (totalWinProfit / totalLossProfit) : 0;
   
   // Calcul simplifié du Sharpe
   double sharpe = 0;  // À implémenter selon les besoins
   
   // Écrire la ligne de résultat
   FileWrite(handle,
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
      currentConfig.testID,
      currentConfig.testName,
      totalTrades,
      DoubleToString(finalBalance, 2),
      DoubleToString(equity, 2),
      DoubleToString(profitPercent, 2),
      DoubleToString(profitFactor, 2),
      DoubleToString(winRate, 1),
      DoubleToString(avgWin, 2),
      DoubleToString(avgLoss, 2),
      DoubleToString(maxDrawdown, 2),
      DoubleToString(sharpe, 2),
      "COMPLETED"
   );
   
   FileClose(handle);
   
   Print("✅ Statistiques finales sauvegardées dans ", resultsFile);
}
