//+------------------------------------------------------------------+
//|                                           BB_Candle_Outside.mq5  |
//|                      Entrée sur bougie hors Bollinger (MT5)      |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>
#include "JT_Indicators.mqh"
#include "JT_Positions.mqh"
#include "JT_Utils.mqh"
CTrade trade;

//---------------------------- Inputs --------------------------------
input string   InpSymbol           = "";                 // Symbole (vide = _Symbol)
input ENUM_TIMEFRAMES InpTF        = PERIOD_CURRENT;     // UT
input int      BB_Period           = 20;                 // Période Bollinger
input double   BB_Dev              = 2.0;                // Déviation
input int      BB_Shift            = 0;                  // Shift

// Entrée
enum EntryMode { REVERSION=0, BREAKOUT=1 };
input EntryMode Mode               = REVERSION;          // Type d'entrée

// Direction filter
enum TradeDirection { DIR_BOTH=0, DIR_ONLY_BUY=1, DIR_ONLY_SELL=2 };
input TradeDirection TradeDir      = DIR_BOTH;           // Filtre direction: Both/Only Buy/Only Sell

// Money management
input double   Risk_Percent        = 0.1;                // % risque/trade
input bool     One_Pos_Per_Symbol  = true;               // 1 position par symbole
input ulong    Magic               = 20251007;           // Magic

// SL/TP basés sur swing points
input int      SL_Period           = 50;                 // Période pour SL (nombre de bougies)
input int      TP_Period           = 30;                 // Période pour TP (nombre de bougies)

// Time filter (allow trading only in specific hour ranges)
input bool     UseTimeFilter       = true;               // Activer filtre horaire
input string   HourRanges          = "8-10;16";          // Plages horaires (ex: 8-10;16)

// Position management
input bool     Close_On_OppositeBand = true;             // Fermer si touche la bande opposée
input bool     BE_On_MiddleBand      = true;             // Passer Break-Even sur médiane
input int      BE_Offset_Points      = 0;                // Offset BE en points (>=0)
input int      Flat_Hour             = 23;               // Forcer clôture à HH:MM
input int      Flat_Minute           = 40;               // Forcer clôture à HH:MM

// Outside candle strictness
input int      OutsidePaddingPoints  = 5;                // marge mini au-delà de la bande
input bool     BodyMustBeOutside     = true;             // seulement le corps hors bande

// Exits threshold options
input bool     Exit_UsePrevBar       = true;             // utiliser bandes de la bougie fermée
input int      TouchPadPoints        = 5;                // marge de touche en points

//---------------------------- Handles --------------------------------
int hBB = INVALID_HANDLE;

//---------------------------- Buffers --------------------------------
double up[], mid[], lo[];

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

//---------------------------- Lifecycle -------------------------------
int OnInit()
{
   string s = Sym(); ENUM_TIMEFRAMES t = TF();

   hBB  = iBands(s, t, BB_Period,  BB_Shift, BB_Dev, PRICE_CLOSE);
   if(hBB==INVALID_HANDLE) return INIT_FAILED;

   ArraySetAsSeries(up,true);  ArraySetAsSeries(mid,true); ArraySetAsSeries(lo,true);

   trade.SetExpertMagicNumber((long)Magic);
   
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
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hBB!=INVALID_HANDLE)  IndicatorRelease(hBB);
}

//---------------------------- Trading Logic ---------------------------
void OnTick()
{
   string s = Sym(); ENUM_TIMEFRAMES t = TF();
   if(!IsHourAllowed()) return;
   static datetime last_bar=0;
   // Gestion en continu des positions
   ManageOpenPositions(s);

   // Détection de nouvelle bougie + logique d'entrée existante
   if(!NewBar(s,t,last_bar)) return;
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

   // Bandes à l'index 1 (mêmes bougies)
   // Buffer 0 = BASE_LINE (médiane), Buffer 1 = UPPER_BAND, Buffer 2 = LOWER_BAND
   double m1[], u1[], l1[];
   if(CopyBuffer(hBB,0,1,1,m1)<1) return 0;  // Ligne médiane
   if(CopyBuffer(hBB,1,1,1,u1)<1) return 0;  // Bande supérieure
   if(CopyBuffer(hBB,2,1,1,l1)<1) return 0;  // Bande inférieure
   double upper=u1[0], lower=l1[0];

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

   if(Mode==REVERSION){
      if(outsideBearAbove) return -1; // SELL
      if(outsideBullBelow) return +1; // BUY
   }else{
      if(isAboveBand) return +1;      // BUY breakout
      if(isBelowBand) return -1;      // SELL breakout
   }
   return 0;
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

   string s=Sym();
   ENUM_TIMEFRAMES t=TF();
   double ask=SymbolInfoDouble(s,SYMBOL_ASK);
   double bid=SymbolInfoDouble(s,SYMBOL_BID);
   
   // Variables pour SL et TP
   double sl = 0, tp = 0;
   bool isBuy = (dir > 0);
   
   // Calculer SL/TP basés sur les plus hauts/plus bas
   if(!CalculateSwingSLTP(s, t, isBuy, SL_Period, TP_Period, sl, tp)) {
      LogError("Erreur lors du calcul des niveaux SL/TP");
      return;
   }
   
   // Calculer le volume en fonction du risque
   double riskPrice = isBuy ? (bid - sl) : (sl - ask);
   if(riskPrice <= 0) {
      LogError("Distance de SL invalide");
      return;
   }
   
   double lots = CalcLotsByRisk(s, riskPrice);
   
   // Journaliser les niveaux
   string dirStr = isBuy ? "BUY" : "SELL";
   LogMessage("Signal " + dirStr + " détecté - SL: " + DoubleToString(sl, 5) + ", TP: " + DoubleToString(tp, 5));
   
   // Ouvrir la position
   if(isBuy){ // BUY
      if(lots>0) OpenBuyPosition(trade, s, lots, ask, sl, tp, "BB Outside BUY");
   } else {   // SELL
      if(lots>0) OpenSellPosition(trade, s, lots, bid, sl, tp, "BB Outside SELL");
   }
}
void ManageOpenPositions(const string s)
{
   // Bandes 0 et 1
   // Buffer 0 = BASE_LINE (médiane), Buffer 1 = UPPER_BAND, Buffer 2 = LOWER_BAND
   double m0[1], u0[1], l0[1], m1[1], u1[1], l1[1];
   if(CopyBuffer(hBB,0,0,1,m0)<1) return;  // Médiane bougie 0
   if(CopyBuffer(hBB,1,0,1,u0)<1) return;  // Bande sup bougie 0
   if(CopyBuffer(hBB,2,0,1,l0)<1) return;  // Bande inf bougie 0
   if(CopyBuffer(hBB,0,1,1,m1)<1) return;  // Médiane bougie 1
   if(CopyBuffer(hBB,1,1,1,u1)<1) return;  // Bande sup bougie 1
   if(CopyBuffer(hBB,2,1,1,l1)<1) return;  // Bande inf bougie 1

   double upper0=u0[0], middle0=m0[0], lower0=l0[0];
   double upper1=u1[0], middle1=m1[0], lower1=l1[0];

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
            continue;
         }
      }

      // BE sur médiane (après tentative de fermeture sur bande opposée)
      if(BE_On_MiddleBand)
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

      if(time_to_flat) ClosePosition(trade, tk, "Flat time", 0);
   }
}


// relance Process sur chaque nouvelle barre
void OnTimer(){} // non utilisé

// petite astuce: appeler Process depuis OnTick après NewBar pour garder le code clair
void OnCalculateProxy(){} // non utilisé
