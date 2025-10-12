//+------------------------------------------------------------------+
//|                                           BB_Candle_Outside.mq5  |
//|                      Entrée sur bougie hors Bollinger (MT5)      |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>
#include "common/JT_Indicators.mqh"
#include "common/JT_Positions.mqh"
#include "common/JT_Utils.mqh"
#include "common/JT_DivergenceValidator.mqh"
#include "common/JT_TradeTracker.mqh"
#include "common/JT_MoneyManagement.mqh"
CTrade trade;

//---------------------------- Inputs --------------------------------
input group "═══ Symbole et Timeframe ═══"
input string   InpSymbol           = "";                 // Symbole (vide = _Symbol)
input ENUM_TIMEFRAMES InpTF        = PERIOD_CURRENT;     // Timeframe

input group "═══ Bollinger Bands ═══"
input int      BB_Period           = 20;                 // Période
input double   BB_Dev              = 2.0;                // Déviation
input int      BB_Shift            = 0;                  // Shift

input group "═══ RSI - Filtre de confirmation ═══"
input bool     Use_RSI_Filter      = true;               // Activer filtre RSI
input int      RSI_Period          = 14;                 // Période RSI
input double   RSI_Oversold        = 29.0;               // Seuil survente (pour BUY)
input double   RSI_Overbought      = 71.0;               // Seuil surachat (pour SELL)

input group "═══ EMA - Filtre de tendance ═══"
input bool     Use_EMA_Filter      = true;               // Activer filtre EMA
input int      EMA_Fast_Period     = 50;                 // Période EMA rapide
input int      EMA_Slow_Period     = 100;                // Période EMA lente
enum EMA_MODE { 
   EMA_TREND=0,        // Suivre la tendance
   EMA_COUNTER=1,      // Contre-tendance
   EMA_ZONE=2          // Zone dynamique
};
input EMA_MODE EMA_Filter_Mode     = EMA_TREND;          // Mode de filtrage
input double   EMA_Zone_Distance   = 20.0;               // Distance zone (points)

input group "═══ Validateur de Divergence ═══"
input bool     Use_Divergence_Validator = true;          // Activer validation par divergence
input double   Div_RSI_Buy_Level   = 35.0;               // Seuil RSI pour validation BUY
input double   Div_RSI_Sell_Level  = 65.0;               // Seuil RSI pour validation SELL
input int      Div_Swing_Length    = 5;                  // Longueur pivot pour divergence

input group "═══ Mode d'Entrée ═══"
enum EntryMode { REVERSION=0, BREAKOUT=1 };
input EntryMode Mode               = REVERSION;          // Type d'entrée
enum TradeDirection { DIR_BOTH=0, DIR_ONLY_BUY=1, DIR_ONLY_SELL=2 };
input TradeDirection TradeDir      = DIR_BOTH;           // Filtre direction
input int      OutsidePaddingPoints  = 5;                // Marge mini au-delà de la bande (points)
input bool     BodyMustBeOutside     = true;             // Seulement le corps hors bande

input group "═══ Money Management ═══"
input double   Risk_Percent        = 0.1;                // % risque par trade
input bool     One_Pos_Per_Symbol  = true;               // 1 position par symbole max
input ulong    Magic               = 20251007;           // Magic Number

input group "═══ Stop Loss & Take Profit ═══"
input int      SL_Period           = 50;                 // Période pour SL (barres)
input int      TP_Period           = 30;                 // Période pour TP (barres)
input double   Min_RR              = 2.0;                // Ratio RR minimum (0 = désactivé)
input double   ATR_Multiplier      = 2.0;                // Multiplicateur ATR (fallback SL)
input int      ATR_Period          = 14;                 // Période ATR

input group "═══ Filtre Horaire ═══"
input bool     UseTimeFilter       = true;               // Activer filtre horaire
input string   HourRanges          = "8-10;16";          // Plages horaires (ex: 8-10;16)

input group "═══ Filtre Jours de la Semaine ═══"
input bool     UseDayFilter        = false;              // Activer filtre par jour
input string   DayRanges           = "1-5";              // Jours autorisés (0=Dim,1=Lun...6=Sam)

input group "═══ Gestion de Position ═══"
input bool     Close_On_OppositeBand = true;             // Fermer si touche bande opposée
input bool     BE_On_MiddleBand      = true;             // Break-Even sur médiane
input int      BE_Offset_Points      = 0;                // Offset BE (points)
input bool     UseFlatTime           = false;            // Clôture forcée à heure fixe
input int      Flat_Hour             = 23;               // Heure de clôture
input int      Flat_Minute           = 40;               // Minute de clôture
input bool     Exit_UsePrevBar       = true;             // Utiliser bandes barre fermée
input int      TouchPadPoints        = 5;                // Marge de touche (points)

input group "═══ Marqueurs Visuels ═══"
input bool     Mark_FreeCandles      = true;             // Marquer les Free Candles
input bool     Mark_DrawVLine        = true;             // Ligne verticale
input bool     Mark_DrawArrow        = true;             // Flèche directionnelle
input bool     Mark_DrawBox          = false;            // Rectangle autour bougie
input bool     Mark_DrawText         = false;            // Texte d'annotation

//---------------------------- Indicateurs --------------------------------
IndicatorHandles indicators;
IndicatorBuffers buffers;

//---------------------------- EMA Handles --------------------------------
int EMA_Fast_Handle = INVALID_HANDLE;
int EMA_Slow_Handle = INVALID_HANDLE;

//---------------------------- Divergence Validator -----------------------
JTDivergenceValidator divValidator;

//---------------------------- Trade Tracker -------------------------------
JTTradeTracker* tracker = NULL;

//---------------------------- Money Management ----------------------------
JTMoneyManagement* mmManager = NULL;

//---------------------------- Utils ----------------------------------
string Sym() { return (InpSymbol=="" ? _Symbol : InpSymbol); }
ENUM_TIMEFRAMES TF(){ return (InpTF==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF); }

bool NewBar(const string s, ENUM_TIMEFRAMES tf, datetime &last_time)
{
   MqlRates r[];
   if(CopyRates(s, tf, 0, 2, r) < 2) return false;
   ArraySetAsSeries(r,true);
   if(r[0].time != last_time){ last_time = r[0].time; return true; }
   return false;
}

bool IsHourAllowed()
{
   if(!UseTimeFilter) return true;  // Si le filtre horaire est désactivé, toujours autoriser
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentHour = dt.hour;
   
   bool isAllowed = IsHourAllowedCustom(HourRanges);
   
   if(!isAllowed) {
      // Ne pas afficher ce message à chaque tick pour éviter de spammer le journal
      static int lastHourLogged = -1;
      if(lastHourLogged != currentHour) {
         LogMessage("Heure actuelle: " + IntegerToString(currentHour) + ":00 - Trading non autorisé selon les plages configurées: " + HourRanges);
         lastHourLogged = currentHour;
      }
   }
   
   return isAllowed;
}

bool IsDayAllowed()
{
   if(!UseDayFilter) return true;  // Si le filtre de jour est désactivé, toujours autoriser
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentDay = dt.day_of_week;  // 0=Dimanche, 1=Lundi, 2=Mardi, ..., 6=Samedi
   
   bool isAllowed = IsDayAllowedCustom(DayRanges);
   
   if(!isAllowed) {
      // Ne pas afficher ce message à chaque tick pour éviter de spammer le journal
      static int lastDayLogged = -1;
      if(lastDayLogged != currentDay) {
         string dayNames[] = {"Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"};
         LogMessage("Jour actuel: " + dayNames[currentDay] + " (" + IntegerToString(currentDay) + ") - Trading non autorisé selon les jours configurés: " + DayRanges);
         lastDayLogged = currentDay;
      }
   }
   
   return isAllowed;
}

bool HaveOpenPos(const string s)
{
   if(!One_Pos_Per_Symbol) return false;
   
   int direction = 0;
   ulong ticket = 0;
   return HasOpenPosition(s, Magic, direction, ticket);
}

double NormalizeVolume(double lots, const string s)
{
   double minv=SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double maxv=SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   lots = MathMax(minv, MathMin(maxv, lots));
   return MathRound(lots/step)*step;
}

double CalcLotsByRisk(const string s, double sl_dist_price)
{
   if(sl_dist_price<=0) return 0.0;
double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
double risk = eq * (Risk_Percent/100.0);

   double tick_value = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
   if(tick_value<=0 || tick_size<=0) return 0.0;

   double money_per_lot = (sl_dist_price / tick_size) * tick_value;
   if(money_per_lot<=0) return 0.0;

   return NormalizeVolume(risk / money_per_lot, s);
}

//---------------------------- Filtre EMA -------------------------------
bool CheckEMAFilter(int signalDirection)
{
   if(!Use_EMA_Filter) return true;
   
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   if(CopyBuffer(EMA_Fast_Handle, 0, 0, 2, emaFast) < 2) {
      LogError("Erreur copie EMA Fast");
      return false;
   }
   if(CopyBuffer(EMA_Slow_Handle, 0, 0, 2, emaSlow) < 2) {
      LogError("Erreur copie EMA Slow");
      return false;
   }
   
   string s = Sym();
   double price = SymbolInfoDouble(s, SYMBOL_BID);
   bool uptrend = (emaFast[0] > emaSlow[0]);
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   
   string modeStr = "";
   bool filterPassed = false;
   
   switch(EMA_Filter_Mode) {
      case EMA_TREND: {
         // Mode TREND : Trade dans le sens de la tendance
         modeStr = "TREND";
         if(signalDirection > 0) { // BUY
            filterPassed = uptrend && (price > emaSlow[0]);
            if(!filterPassed) {
               LogMessage("Filtre EMA TREND: Rejet BUY - Tendance=" + (uptrend?"UP":"DOWN") + 
                         ", Prix=" + DoubleToString(price,5) + " vs EMA100=" + DoubleToString(emaSlow[0],5));
            }
         } else { // SELL
            filterPassed = !uptrend && (price < emaSlow[0]);
            if(!filterPassed) {
               LogMessage("Filtre EMA TREND: Rejet SELL - Tendance=" + (uptrend?"UP":"DOWN") + 
                         ", Prix=" + DoubleToString(price,5) + " vs EMA100=" + DoubleToString(emaSlow[0],5));
            }
         }
         break;
      }
         
      case EMA_COUNTER: {
         // Mode COUNTER : Trade les retournements aux extrêmes
         modeStr = "COUNTER";
         double distance = MathAbs(price - emaFast[0]) / point;
         if(signalDirection > 0) { // BUY
            filterPassed = !uptrend && (price < emaFast[0]) && (distance > EMA_Zone_Distance);
            if(!filterPassed) {
               LogMessage("Filtre EMA COUNTER: Rejet BUY - Distance=" + DoubleToString(distance,1) + 
                         "pts < " + DoubleToString(EMA_Zone_Distance,1) + "pts");
            }
         } else { // SELL
            filterPassed = uptrend && (price > emaFast[0]) && (distance > EMA_Zone_Distance);
            if(!filterPassed) {
               LogMessage("Filtre EMA COUNTER: Rejet SELL - Distance=" + DoubleToString(distance,1) + 
                         "pts < " + DoubleToString(EMA_Zone_Distance,1) + "pts");
            }
         }
         break;
      }
         
      case EMA_ZONE: {
         // Mode ZONE : Évite la zone neutre entre les EMAs
         modeStr = "ZONE";
         double maxEMA = MathMax(emaFast[0], emaSlow[0]);
         double minEMA = MathMin(emaFast[0], emaSlow[0]);
         bool inZone = (price < maxEMA + EMA_Zone_Distance * point) && 
                       (price > minEMA - EMA_Zone_Distance * point);
         filterPassed = !inZone;
         if(!filterPassed) {
            LogMessage("Filtre EMA ZONE: Rejet - Prix dans zone neutre [" + 
                      DoubleToString(minEMA,5) + " - " + DoubleToString(maxEMA,5) + "]");
         }
         break;
      }
   }
   
   if(filterPassed) {
      LogMessage("✓ Filtre EMA " + modeStr + " passé - Signal " + (signalDirection>0?"BUY":"SELL") + " validé");
   }
   
   return filterPassed;
}

//---------------------------- Lifecycle -------------------------------
int OnInit()
{
   string s = Sym(); ENUM_TIMEFRAMES t = TF();

   // Initialiser les indicateurs via la structure
   if(!InitIndicators(indicators, s, t, BB_Period, BB_Dev, BB_Shift, RSI_Period)) {
      return INIT_FAILED;
   }
   
   // Afficher les Bollinger Bands sur le graphe
   if(!ChartIndicatorAdd(0, 0, indicators.BB)) {
      Print("Attention: impossible d'afficher les Bollinger Bands sur le graphe");
   }
   
   // Afficher le RSI dans une sous-fenêtre
   if(!ChartIndicatorAdd(0, ChartWindowFind(), indicators.RSI)) {
      Print("Attention: impossible d'afficher le RSI sur le graphe");
   }
   
   // Initialiser les EMAs si le filtre est activé
   if(Use_EMA_Filter) {
      EMA_Fast_Handle = iMA(s, t, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
      EMA_Slow_Handle = iMA(s, t, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
      
      if(EMA_Fast_Handle == INVALID_HANDLE || EMA_Slow_Handle == INVALID_HANDLE) {
         LogError("Erreur d'initialisation des EMAs");
         return INIT_FAILED;
      }
      
      // Afficher les EMAs sur le graphe
      if(!ChartIndicatorAdd(0, 0, EMA_Fast_Handle)) {
         Print("Attention: impossible d'afficher EMA" + IntegerToString(EMA_Fast_Period));
      }
      if(!ChartIndicatorAdd(0, 0, EMA_Slow_Handle)) {
         Print("Attention: impossible d'afficher EMA" + IntegerToString(EMA_Slow_Period));
      }
      
      string modeText = "";
      switch(EMA_Filter_Mode) {
         case EMA_TREND: modeText = "TREND (suivre tendance)"; break;
         case EMA_COUNTER: modeText = "COUNTER (contre-tendance)"; break;
         case EMA_ZONE: modeText = "ZONE (éviter zone neutre)"; break;
      }
      LogMessage("Filtre EMA activé: EMA" + IntegerToString(EMA_Fast_Period) + "/EMA" + 
                 IntegerToString(EMA_Slow_Period) + " - Mode: " + modeText);
   }

   trade.SetExpertMagicNumber((long)Magic);
   
   // Nettoyer les anciens marqueurs Free Candles
   if(Mark_FreeCandles) {
      DeleteAllFreeCandleMarkers("FreeCandle");
      LogMessage("Marqueurs Free Candles activés");
   }
   
   // Initialiser le validateur de divergence si activé
   if(Use_Divergence_Validator) {
      if(!divValidator.Init(s, t, RSI_Period, Div_RSI_Buy_Level, Div_RSI_Sell_Level, Div_Swing_Length)) {
         LogError("Erreur d'initialisation du validateur de divergence");
         return INIT_FAILED;
      }
      LogMessage("Validateur de divergence activé: RSI Buy<" + DoubleToString(Div_RSI_Buy_Level, 1) + 
                 ", RSI Sell>" + DoubleToString(Div_RSI_Sell_Level, 1));
   }
   
   // Afficher les plages horaires configurées
   if(UseTimeFilter) {
      // Parser les plages horaires pour vérification
      HourRange ranges[];
      if(ParseHourRanges(HourRanges, ranges)) {
         LogHourRanges(ranges, "Plages horaires configurées");
      } else {
         LogError("Format de plage horaire invalide: " + HourRanges);
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   
   // Afficher les jours de trading configurés
   if(UseDayFilter) {
      string dayNames[] = {"Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"};
      string dayMsg = "Filtre jours activé: " + DayRanges + " (";
      
      // Parser et afficher les jours en clair
      string ranges[];
      int rangeCount = StringSplit(DayRanges, ';', ranges);
      
      for(int i = 0; i < rangeCount; i++) {
         if(i > 0) dayMsg += ", ";
         
         string range = ranges[i];
         int dashPos = StringFind(range, "-");
         
         if(dashPos > 0) {
            int startDay = (int)StringToInteger(StringSubstr(range, 0, dashPos));
            int endDay = (int)StringToInteger(StringSubstr(range, dashPos + 1));
            if(startDay >= 0 && startDay <= 6 && endDay >= 0 && endDay <= 6) {
               dayMsg += dayNames[startDay] + "-" + dayNames[endDay];
            }
         } else {
            int day = (int)StringToInteger(range);
            if(day >= 0 && day <= 6) {
               dayMsg += dayNames[day];
            }
         }
      }
      dayMsg += ")";
      LogMessage(dayMsg);
   }
   
   // Initialiser le Trade Tracker
   tracker = new JTTradeTracker(
      s,                               // Symbol
      Magic,                           // Magic number
      BB_Period,                       // BB period
      BB_Dev,                          // BB deviation
      RSI_Period,                      // RSI period
      Use_EMA_Filter ? EMA_Fast_Period : 50,  // EMA fast
      Use_EMA_Filter ? EMA_Slow_Period : 100  // EMA slow
   );
   
   if(tracker != NULL) {
      string tfStr = "";
      switch(t) {
         case PERIOD_M1: tfStr = "M1"; break;
         case PERIOD_M3: tfStr = "M3"; break;
         case PERIOD_M5: tfStr = "M5"; break;
         case PERIOD_M15: tfStr = "M15"; break;
         case PERIOD_M30: tfStr = "M30"; break;
         case PERIOD_H1: tfStr = "H1"; break;
         case PERIOD_H4: tfStr = "H4"; break;
         case PERIOD_D1: tfStr = "D1"; break;
         default: tfStr = "UNKNOWN"; break;
      }
      LogMessage("Trade Tracker activé - Fichier CSV: TradeAnalysis_" + s + "_" + tfStr + ".csv");
   }
   
   // Initialiser le Money Management
   mmManager = new JTMoneyManagement(s, t);
   
   if(mmManager != NULL) {
      // Configurer les paramètres selon les inputs de l'EA
      TPSLParams params;
      params.slMethod = SL_SWING;
      params.slSwingPeriod = SL_Period;
      params.slATRMultiplier = ATR_Multiplier;
      
      params.tpMethod = TP_RR_RATIO;
      params.tpRRRatio = Min_RR;
      params.tpSwingPeriod = TP_Period;
      
      params.minRR = Min_RR;
      params.maxRR = 5.0;
      params.useBreakEven = BE_On_MiddleBand;
      params.beActivationRR = 0.5;
      params.beOffsetPoints = BE_Offset_Points;
      
      params.useTrailing = false;  // Désactivé par défaut
      params.trailingStartRR = 1.0;
      params.trailingStepPoints = 10;
      params.trailingStopPoints = 50;
      
      params.minDistancePoints = 20;
      params.maxDistancePoints = 1000;
      
      mmManager.SetParams(params);
      LogMessage("Money Management activé - Méthode SL: SWING, Méthode TP: RR_RATIO");
   }
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ReleaseIndicators(indicators);
   
   // Libérer les handles EMA
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
   
   // Libérer le Money Management
   if(mmManager != NULL) {
      delete mmManager;
      mmManager = NULL;
   }
   
   // Nettoyer les marqueurs Free Candles si souhaité
   // Commenté pour garder les marqueurs après déconnexion de l'EA
   // DeleteAllFreeCandleMarkers("FreeCandle");
}

//---------------------------- Trading Logic ---------------------------
void OnTick()
{
   string s = Sym(); ENUM_TIMEFRAMES t = TF();
   if(!IsHourAllowed()) return;
   if(!IsDayAllowed()) return;
   static datetime last_bar=0;
   
   // Suivre les trades actifs pour max profit/DD
   if(tracker != NULL) {
      for(int i = PositionsTotal()-1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == Magic) {
               tracker.UpdateTrade(ticket);
            }
         }
      }
   }
   
   // Gestion en continu des positions
   ManageOpenPositions(s);
   
   // Vérifier les trades fermés automatiquement
   CheckClosedTrades();

   // Détection de nouvelle bougie + logique d'entrée existante
   if(!NewBar(s,t,last_bar)) return;
   
   // Si le validateur de divergence est activé, vérifier d'abord
   if(Use_Divergence_Validator) {
      int divSignal = divValidator.ValidateDivergence();
      if(divSignal != 0) {
         // Divergence validée, exécuter le trade
         ExecuteTradeFromDivergence(divSignal);
         return;
      }
   }
   
   Process();
}

// helper to avoid typo on CopyBuffer above
int CCopy(int handle,int buf,int start,int cnt,double &arr[]){ return CopyBuffer(handle,buf,start,cnt,arr); }

int SignalFromClosedBarStrict()
{
   string s = Sym(); ENUM_TIMEFRAMES t = TF();
   // Bougie N-1 (fermée)
   MqlRates r[]; if(CopyRates(s,t,0,3,r)<3) return 0; ArraySetAsSeries(r,true);
   double o=r[1].open, h=r[1].high, l=r[1].low, c=r[1].close;

   // Récupérer les données BB et RSI via GetIndicatorData
   if(!GetIndicatorData(indicators, buffers, 3, false)) return 0;
   
   double upper = buffers.BBUpper[1];   // Bande supérieure à l'index 1
   double lower = buffers.BBLower[1];   // Bande inférieure à l'index 1

   bool red   = (o>c);
   bool green = (c>o);

   // Debug - Afficher les valeurs pour comprendre le problème
   string debugInfo = 
      "Candle: O=" + DoubleToString(o, 5) + 
      " H=" + DoubleToString(h, 5) + 
      " L=" + DoubleToString(l, 5) + 
      " C=" + DoubleToString(c, 5) +
      " | BB: Upper=" + DoubleToString(upper, 5) + 
      " Lower=" + DoubleToString(lower, 5) +
      " | Padding=" + IntegerToString(OutsidePaddingPoints) + " points, BodyOnly=" + (BodyMustBeOutside ? "true" : "false");
   LogMessage(debugInfo);
   
   // Utiliser la fonction IsFreeCandle pour détecter si la bougie est hors bandes
   bool isFreeCandle = IsFreeCandle(o, h, l, c, upper, lower, OutsidePaddingPoints, BodyMustBeOutside);
   
   if(!isFreeCandle) {
      LogMessage("Pas de free candle détectée");
      return 0;
   }
   
   LogMessage("FREE CANDLE DÉTECTÉE!");
   
   // Déterminer si la bougie est au-dessus ou en-dessous
   bool isAboveBand = false;
   bool isBelowBand = false;
   
  if(BodyMustBeOutside) {
     double bodyHigh = MathMax(o, c);
     double bodyLow = MathMin(o, c);
     // Strict: tout le corps doit être en dehors
     isAboveBand = (bodyLow > upper + OutsidePaddingPoints * _Point);
     isBelowBand = (bodyHigh < lower - OutsidePaddingPoints * _Point);
  } else {
     // Strict: toute la bougie (mèches comprises) doit être en dehors
     isAboveBand = (l > upper + OutsidePaddingPoints * _Point);
     isBelowBand = (h < lower - OutsidePaddingPoints * _Point);
  }
   
   bool outsideBearAbove = isAboveBand && red;
   bool outsideBullBelow = isBelowBand && green;

   // Déterminer le signal potentiel
   int signal = 0;
   if(Mode==REVERSION){
      if(outsideBearAbove) signal = -1; // SELL
      if(outsideBullBelow) signal = +1; // BUY
   }else{
      if(isAboveBand) signal = +1;      // BUY breakout
      if(isBelowBand) signal = -1;      // SELL breakout
   }
   
   // Si pas de signal, retourner 0
   if(signal == 0) return 0;
   
   // Appliquer le filtre EMA AVANT le filtre RSI
   if(!CheckEMAFilter(signal)) {
      LogMessage("Signal rejeté par filtre EMA");
      return 0;
   }
   
   // Appliquer le filtre RSI si activé
   if(Use_RSI_Filter) {
      double currentRSI = buffers.RSI[1];  // RSI de la bougie fermée
      LogMessage("RSI valeur: " + DoubleToString(currentRSI, 2));
      
      // Pour un signal BUY, vérifier que RSI est en survente
      if(signal > 0 && currentRSI >= RSI_Oversold) {
         LogMessage("Signal BUY rejeté - RSI " + DoubleToString(currentRSI, 2) + 
                    " >= seuil oversold " + DoubleToString(RSI_Oversold, 2));
         return 0;
      }
      
      // Pour un signal SELL, vérifier que RSI est en surachat
      if(signal < 0 && currentRSI <= RSI_Overbought) {
         LogMessage("Signal SELL rejeté - RSI " + DoubleToString(currentRSI, 2) + 
                    " <= seuil overbought " + DoubleToString(RSI_Overbought, 2));
         return 0;
      }
      
      LogMessage("Signal confirmé par RSI: " + DoubleToString(currentRSI, 2));
   }
   
   return signal;
}

void Process()
{
   int dir = SignalFromClosedBarStrict();
   
   // Log pour le debug
   LogMessage("SignalFromClosedBarStrict retourne: " + IntegerToString(dir));
   
   if(dir==0) {
      LogMessage("Pas de signal détecté - aucune action prise");
      return;
   }
   
   if(HaveOpenPos(Sym())) {
      LogMessage("Position déjà ouverte sur ce symbole - aucune action prise");
      return;
   }

   // Apply direction filter
   if(TradeDir==DIR_ONLY_BUY && dir<0) return;
   if(TradeDir==DIR_ONLY_SELL && dir>0) return;
   
   // Marquer le Free Candle sur le graphique
   if(Mark_FreeCandles) {
      string s = Sym();
      ENUM_TIMEFRAMES t = TF();
      
      // Récupérer les données de la bougie fermée (index 1)
      MqlRates rates[];
      if(CopyRates(s, t, 1, 1, rates) > 0) {
         double high = rates[0].high;
         double low = rates[0].low;
         double close = rates[0].close;
         datetime time = rates[0].time;
         
         // Position de la flèche
         double arrowPrice = (dir > 0) ? low : high;
         
         // Dessiner les marqueurs
         MarkFreeCandle(time, high, low, arrowPrice, dir, t, 
                       Mark_DrawVLine, Mark_DrawArrow, Mark_DrawBox, Mark_DrawText, "FreeCandle");
         
         LogMessage("Free Candle marqué sur le graphique à " + TimeToString(time));
      }
   }
   
   // Si le validateur de divergence est activé, mémoriser le free candle au lieu d'exécuter
   if(Use_Divergence_Validator) {
      string s = Sym();
      MqlTick tick;
      if(!SymbolInfoTick(s, tick)) return;
      
      double priceLevel = (dir > 0) ? tick.bid : tick.ask;
      divValidator.RememberFreeCandle(1, priceLevel, dir);
      LogMessage("Free Candle mémorisé pour validation divergence future");
      return;  // On n'exécute pas immédiatement
   }

   string s=Sym();
   ENUM_TIMEFRAMES t=TF();
   double ask=SymbolInfoDouble(s,SYMBOL_ASK);
   double bid=SymbolInfoDouble(s,SYMBOL_BID);
   
   // Variables pour SL et TP
   double sl = 0, tp = 0;
   bool isBuy = (dir > 0);
   double entryPrice = isBuy ? ask : bid;
   
   // Utiliser le nouveau système de Money Management
   string errorMsg = "";
   if(mmManager == NULL || !mmManager.CalculateTPSL(isBuy, entryPrice, sl, tp, errorMsg)) {
      LogError("Erreur calcul TP/SL: " + errorMsg);
      return;
   }
   
   // Calculer le volume en fonction du risque
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   double slDistancePoints = MathAbs(entryPrice - sl) / point;
   double lots = (mmManager != NULL) ? mmManager.CalculateVolume(Risk_Percent, slDistancePoints) : 
                                       CalcLotsByRisk(s, MathAbs(entryPrice - sl));
   
   // Calculer le ratio risque/récompense (RR)
   double reward = isBuy ? (tp - entryPrice) : (entryPrice - tp);
   double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
   double rr = (risk > 0) ? (reward / risk) : 0;
   
   // Journaliser les niveaux avec RR
   string dirStr = isBuy ? "BUY" : "SELL";
   LogMessage("Signal " + dirStr + " détecté - Entry: " + DoubleToString(entryPrice, 5) + 
              ", SL: " + DoubleToString(sl, 5) + 
              ", TP: " + DoubleToString(tp, 5) + 
              ", RR: 1:" + DoubleToString(rr, 2) + 
              ", Lots: " + DoubleToString(lots, 2));
   
   // Note: La vérification du RR minimum est déjà faite dans mmManager.CalculateTPSL()
   
   // Récupérer la valeur RSI actuelle pour le commentaire
   int rsiI = (int)MathRound(buffers.RSI[1]);
   
   // Préparer le commentaire compact
   string orderComment = StringFormat("BB %s|R:%.2f|I:%d", dirStr, rr, rsiI);
   
   // Ouvrir la position
   if(isBuy){ // BUY
      if(lots>0) {
         OpenBuyPosition(trade, s, lots, ask, sl, tp, orderComment);
         // Enregistrer le trade dans le tracker (sans divergence)
         if(trade.ResultOrder() > 0 && tracker != NULL) {
            string tradeMode = (Mode == REVERSION ? "REVERSION" : "BREAKOUT");
            string emaMode = "";
            if(Use_EMA_Filter) {
               switch(EMA_Filter_Mode) {
                  case EMA_TREND: emaMode = "TREND"; break;
                  case EMA_COUNTER: emaMode = "COUNTER"; break;
                  case EMA_ZONE: emaMode = "ZONE"; break;
               }
            }
            tracker.RecordTradeOpen(trade.ResultOrder(), tradeMode, false, emaMode,
                                   0.0, 0.0, 0,  // Pas de divergence
                                   // Config EA
                                   BB_Period, BB_Dev, RSI_Period,
                                   RSI_Oversold, RSI_Overbought,
                                   EMA_Fast_Period, EMA_Slow_Period, EMA_Zone_Distance,
                                   Risk_Percent, Min_RR,
                                   SL_Period, TP_Period, ATR_Multiplier, ATR_Period,
                                   OutsidePaddingPoints, BodyMustBeOutside,
                                   Use_RSI_Filter, Use_EMA_Filter, Use_Divergence_Validator);
         }
      }
   } else {   // SELL
      if(lots>0) {
         OpenSellPosition(trade, s, lots, bid, sl, tp, orderComment);
         // Enregistrer le trade dans le tracker (sans divergence)
         if(trade.ResultOrder() > 0 && tracker != NULL) {
            string tradeMode = (Mode == REVERSION ? "REVERSION" : "BREAKOUT");
            string emaMode = "";
            if(Use_EMA_Filter) {
               switch(EMA_Filter_Mode) {
                  case EMA_TREND: emaMode = "TREND"; break;
                  case EMA_COUNTER: emaMode = "COUNTER"; break;
                  case EMA_ZONE: emaMode = "ZONE"; break;
               }
            }
            tracker.RecordTradeOpen(trade.ResultOrder(), tradeMode, false, emaMode,
                                   0.0, 0.0, 0,  // Pas de divergence
                                   // Config EA
                                   BB_Period, BB_Dev, RSI_Period,
                                   RSI_Oversold, RSI_Overbought,
                                   EMA_Fast_Period, EMA_Slow_Period, EMA_Zone_Distance,
                                   Risk_Percent, Min_RR,
                                   SL_Period, TP_Period, ATR_Multiplier, ATR_Period,
                                   OutsidePaddingPoints, BodyMustBeOutside,
                                   Use_RSI_Filter, Use_EMA_Filter, Use_Divergence_Validator);
         }
      }
   }
}

// Fonction pour exécuter un trade validé par divergence
void ExecuteTradeFromDivergence(int dir)
{
   string s = Sym();
   ENUM_TIMEFRAMES t = TF();
   
   if(HaveOpenPos(s)) {
      LogMessage("Position déjà ouverte - divergence validée mais pas d'entrée");
      return;
   }
   
   // Apply direction filter
   if(TradeDir==DIR_ONLY_BUY && dir<0) return;
   if(TradeDir==DIR_ONLY_SELL && dir>0) return;
   
   // RÉCUPÉRER LES DONNÉES DE DIVERGENCE AVANT D'OUVRIR LE TRADE
   double divAngle = divValidator.GetLastDivergenceAngle();
   double divStrength = divValidator.GetLastDivergenceStrength();
   int divBars = divValidator.GetLastDivergenceBars();
   
   // Marquer la divergence validée sur le graphique
   if(Mark_FreeCandles) {
      MqlRates rates[];
      if(CopyRates(s, t, 1, 1, rates) > 0) {
         double high = rates[0].high;
         double low = rates[0].low;
         datetime time = rates[0].time;
         double arrowPrice = (dir > 0) ? low : high;
         
         // Utiliser un préfixe différent pour les divergences validées
         MarkFreeCandle(time, high, low, arrowPrice, dir, t, 
                       true, true, Mark_DrawBox, true, "FreeCandleDIV");
         
         LogMessage("Divergence validée marquée sur le graphique");
      }
   }
   
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   
   // Variables pour SL et TP
   double sl = 0, tp = 0;
   bool isBuy = (dir > 0);
   double entryPrice = isBuy ? ask : bid;
   
   // Utiliser le nouveau système de Money Management
   string errorMsg = "";
   if(mmManager == NULL || !mmManager.CalculateTPSL(isBuy, entryPrice, sl, tp, errorMsg)) {
      LogError("Erreur calcul TP/SL divergence: " + errorMsg);
      return;
   }
   
   // Calculer le volume en fonction du risque
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   double slDistancePoints = MathAbs(entryPrice - sl) / point;
   double lots = (mmManager != NULL) ? mmManager.CalculateVolume(Risk_Percent, slDistancePoints) : 
                                       CalcLotsByRisk(s, MathAbs(entryPrice - sl));
   
   // Calculer le ratio risque/récompense (RR)
   double reward = isBuy ? (tp - entryPrice) : (entryPrice - tp);
   double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
   double rr = (risk > 0) ? (reward / risk) : 0;
   
   // Journaliser les niveaux avec RR
   string dirStr = isBuy ? "BUY" : "SELL";
   LogMessage("DIVERGENCE VALIDÉE - Signal " + dirStr + " - Entry: " + DoubleToString(entryPrice, 5) + 
              ", SL: " + DoubleToString(sl, 5) + 
              ", TP: " + DoubleToString(tp, 5) + 
              ", RR: 1:" + DoubleToString(rr, 2) + 
              ", Lots: " + DoubleToString(lots, 2) + 
              ", DivAngle: " + DoubleToString(divAngle, 2) + "°" +
              ", DivStrength: " + DoubleToString(divStrength, 6) + 
              ", DivBars: " + IntegerToString(divBars));
   
   // Note: La vérification du RR minimum est déjà faite dans mmManager.CalculateTPSL()
   
   // Récupérer la valeur RSI actuelle pour le commentaire
   int rsiI = 0;
   if(GetIndicatorData(indicators, buffers, 2, false)) {
      rsiI = (int)MathRound(buffers.RSI[1]);  // RSI de la bougie fermée (arrondi)
   }
   
   // Préparer le commentaire compact
   string orderComment = StringFormat("DIV %s|R:%.2f|I:%d", dirStr, rr, rsiI);
   
   // Ouvrir la position
   if(isBuy) {
      if(lots > 0) {
         OpenBuyPosition(trade, s, lots, ask, sl, tp, orderComment);
         // Enregistrer le trade divergence dans le tracker AVEC LES DONNÉES DE DIVERGENCE
         if(trade.ResultOrder() > 0 && tracker != NULL) {
            string tradeMode = (Mode == REVERSION ? "REVERSION" : "BREAKOUT");
            string emaMode = "";
            if(Use_EMA_Filter) {
               switch(EMA_Filter_Mode) {
                  case EMA_TREND: emaMode = "TREND"; break;
                  case EMA_COUNTER: emaMode = "COUNTER"; break;
                  case EMA_ZONE: emaMode = "ZONE"; break;
               }
            }
            tracker.RecordTradeOpen(trade.ResultOrder(), tradeMode, true, emaMode,
                                   divAngle, divStrength, divBars,
                                   // Config EA
                                   BB_Period, BB_Dev, RSI_Period,
                                   RSI_Oversold, RSI_Overbought,
                                   EMA_Fast_Period, EMA_Slow_Period, EMA_Zone_Distance,
                                   Risk_Percent, Min_RR,
                                   SL_Period, TP_Period, ATR_Multiplier, ATR_Period,
                                   OutsidePaddingPoints, BodyMustBeOutside,
                                   Use_RSI_Filter, Use_EMA_Filter, Use_Divergence_Validator);
         }
      }
   } else {
      if(lots > 0) {
         OpenSellPosition(trade, s, lots, bid, sl, tp, orderComment);
         // Enregistrer le trade divergence dans le tracker AVEC LES DONNÉES DE DIVERGENCE
         if(trade.ResultOrder() > 0 && tracker != NULL) {
            string tradeMode = (Mode == REVERSION ? "REVERSION" : "BREAKOUT");
            string emaMode = "";
            if(Use_EMA_Filter) {
               switch(EMA_Filter_Mode) {
                  case EMA_TREND: emaMode = "TREND"; break;
                  case EMA_COUNTER: emaMode = "COUNTER"; break;
                  case EMA_ZONE: emaMode = "ZONE"; break;
               }
            }
            tracker.RecordTradeOpen(trade.ResultOrder(), tradeMode, true, emaMode,
                                   divAngle, divStrength, divBars,
                                   // Config EA
                                   BB_Period, BB_Dev, RSI_Period,
                                   RSI_Oversold, RSI_Overbought,
                                   EMA_Fast_Period, EMA_Slow_Period, EMA_Zone_Distance,
                                   Risk_Percent, Min_RR,
                                   SL_Period, TP_Period, ATR_Multiplier, ATR_Period,
                                   OutsidePaddingPoints, BodyMustBeOutside,
                                   Use_RSI_Filter, Use_EMA_Filter, Use_Divergence_Validator);
         }
      }
   }
}

void ManageOpenPositions(const string s)
{
   // Récupérer les bandes de Bollinger pour les bougies 0 et 1
   if(!GetIndicatorData(indicators, buffers, 2, false)) return;
   
   double upper0  = buffers.BBUpper[0];   // Bande supérieure bougie 0
   double middle0 = buffers.BBMiddle[0];  // Médiane bougie 0
   double lower0  = buffers.BBLower[0];   // Bande inférieure bougie 0
   
   double upper1  = buffers.BBUpper[1];   // Bande supérieure bougie 1
   double middle1 = buffers.BBMiddle[1];  // Médiane bougie 1
   double lower1  = buffers.BBLower[1];   // Bande inférieure bougie 1

   // extrêmes bougie en cours
   MqlRates bar[1]; if(CopyRates(s,TF(),0,1,bar)<1) return;
   ArraySetAsSeries(bar,true);
   double barHigh=bar[0].high, barLow=bar[0].low; // pas de "lo" local

   double point=SymbolInfoDouble(s,SYMBOL_POINT);
   double pad=TouchPadPoints*point;
   double bid=SymbolInfoDouble(s,SYMBOL_BID);
   double ask=SymbolInfoDouble(s,SYMBOL_ASK);
   double spr=(double)SymbolInfoInteger(s,SYMBOL_SPREAD)*point;

   // heure limite
   MqlDateTime ts; TimeToStruct(TimeCurrent(), ts);
   bool time_to_flat = (ts.hour>Flat_Hour) || (ts.hour==Flat_Hour && ts.min>=Flat_Minute);

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)Magic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=s) continue;

      long type=PositionGetInteger(POSITION_TYPE);
      double op=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);

      // fermer si touche la bande opposée (PRIORITAIRE)
      if(Close_On_OppositeBand)
      {
         bool touchedOpposite = false;
         // Utiliser la logique de la fonction IsFreeCandle pour déterminer si le prix est proche d'une bande
         if(type==POSITION_TYPE_BUY) {
            // Pour un achat, vérifier si le prix approche la bande supérieure
            touchedOpposite = (barHigh >= upper1-pad || bid >= upper0-pad);
         }
         if(type==POSITION_TYPE_SELL) {
            // Pour une vente, vérifier si le prix approche la bande inférieure
            touchedOpposite = (barLow <= lower1+pad || ask <= lower0+pad);
         }
         
         if(touchedOpposite)
         {
            ClosePosition(trade, tk, "Band touch exit", 0);
            // Enregistrer la fermeture dans le tracker
            if(tracker != NULL) {
               tracker.RecordTradeClose(tk, "Band Touch");
            }
            continue;
         }
      }

      // Gestion du Break-Even via Money Management
      if(mmManager != NULL && mmManager.CheckBreakEven(tk, type==POSITION_TYPE_BUY, op, sl)) {
         double newSL = op + BE_Offset_Points*point * (type==POSITION_TYPE_BUY ? 1 : -1);
         if((type==POSITION_TYPE_BUY && sl<newSL) || (type==POSITION_TYPE_SELL && (sl==0.0 || sl>newSL))) {
            ModifyPosition(trade, tk, newSL, tp);
            LogMessage("Break-Even activé pour ticket " + IntegerToString(tk));
         }
      }
      
      // Gestion du Trailing Stop via Money Management
      double newSL;
      if(mmManager != NULL && mmManager.CheckTrailingStop(tk, type==POSITION_TYPE_BUY, op, sl, newSL)) {
         ModifyPosition(trade, tk, newSL, tp);
         LogMessage("Trailing Stop activé pour ticket " + IntegerToString(tk) + " - Nouveau SL: " + DoubleToString(newSL, 5));
      }
      
      // BE sur médiane (garde l'ancienne logique comme backup si mmManager est NULL)
      if(BE_On_MiddleBand && mmManager == NULL)
      {
         if(type==POSITION_TYPE_BUY  && (barHigh>=middle1-pad || bid>=middle0-pad)){
            double newSL=op + BE_Offset_Points*point;
            if(sl<newSL) ModifyPosition(trade, tk, newSL, tp);
         }
         if(type==POSITION_TYPE_SELL && (barLow<=middle1+pad || ask<=middle0+pad)){
            double newSL=op - BE_Offset_Points*point;
            if(sl==0.0 || sl>newSL) ModifyPosition(trade, tk, newSL, tp);
         }
      }

      // Fermer à l'heure de flat time si activé
      if(UseFlatTime && time_to_flat) {
         ClosePosition(trade, tk, "Flat time", 0);
         // Enregistrer la fermeture dans le tracker
         if(tracker != NULL) {
            tracker.RecordTradeClose(tk, "Flat Time");
         }
      }
   }
}


// Vérifier les trades fermés automatiquement (TP/SL)
void CheckClosedTrades()
{
   if(tracker == NULL) return;
   
   static datetime lastCheck = 0;
   datetime currentTime = TimeCurrent();
   
   // Vérifier toutes les 30 secondes
   if(currentTime - lastCheck < 30) return;
   lastCheck = currentTime;
   
   // Sélectionner l'historique récent (dernières 24h)
   if(!HistorySelect(currentTime - 86400, currentTime)) return;
   
   uint totalDeals = HistoryDealsTotal();
   
   for(uint i = 0; i < totalDeals; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      // Vérifier si c'est notre magic et une sortie de position
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == Magic &&
         HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         
         ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         
         // Déterminer la raison de la fermeture
         string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
         string reason = "";
         
         if(StringFind(comment, "tp") >= 0 || StringFind(comment, "TP") >= 0)
            reason = "TP";
         else if(StringFind(comment, "sl") >= 0 || StringFind(comment, "SL") >= 0)
            reason = "SL";
         else
            reason = "Auto Close";
         
         // Enregistrer la fermeture (la fonction évite les doublons)
         tracker.RecordTradeClose(posTicket, reason);
      }
   }
}

// relance Process sur chaque nouvelle barre
void OnTimer(){} // non utilisé

// petite astuce: appeler Process depuis OnTick après NewBar pour garder le code clair
void OnCalculateProxy(){} // non utilisé
