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
#include "JT_DivergenceValidator.mqh"
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

//---------------------------- Divergence Validator -----------------------
JTDivergenceValidator divValidator;

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
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ReleaseIndicators(indicators);
   
   // Nettoyer les marqueurs Free Candles si souhaité
   // Commenté pour garder les marqueurs après déconnexion de l'EA
   // DeleteAllFreeCandleMarkers("FreeCandle");
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
   
   // Calculer SL/TP basés sur les plus hauts/plus bas avec ATR fallback
   if(!CalculateSwingSLTP(s, t, isBuy, SL_Period, TP_Period, sl, tp, 0.0, Min_RR, 1000, ATR_Multiplier, ATR_Period)) {
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
   
   // Calculer le ratio risque/récompense (RR)
   double entryPrice = isBuy ? ask : bid;
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
   
   // Vérifier le seuil RR minimum
   if(Min_RR > 0 && rr < Min_RR) {
      LogMessage("Trade rejeté - RR insuffisant: 1:" + DoubleToString(rr, 2) + 
                 " < minimum requis: 1:" + DoubleToString(Min_RR, 2));
      return;
   }
   
   // Récupérer la valeur RSI actuelle pour le commentaire
   double currentRSI = buffers.RSI[1];
   
   // Préparer le commentaire avec RR et RSI
   string orderComment = "BB Outside " + dirStr + 
                         " | RR:1:" + DoubleToString(rr, 2) + " | RSI:" + DoubleToString(currentRSI, 1);
   
   // Ouvrir la position
   if(isBuy){ // BUY
      if(lots>0) OpenBuyPosition(trade, s, lots, ask, sl, tp, orderComment);
   } else {   // SELL
      if(lots>0) OpenSellPosition(trade, s, lots, bid, sl, tp, orderComment);
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
   
   // Calculer SL/TP basés sur les plus hauts/plus bas avec ATR fallback
   if(!CalculateSwingSLTP(s, t, isBuy, SL_Period, TP_Period, sl, tp, 0.0, Min_RR, 1000, ATR_Multiplier, ATR_Period)) {
      LogError("Erreur lors du calcul des niveaux SL/TP pour divergence");
      return;
   }
   
   // Calculer le volume en fonction du risque
   double riskPrice = isBuy ? (bid - sl) : (sl - ask);
   if(riskPrice <= 0) {
      LogError("Distance de SL invalide pour divergence");
      return;
   }
   
   double lots = CalcLotsByRisk(s, riskPrice);
   
   // Calculer le ratio risque/récompense (RR)
   double entryPrice = isBuy ? ask : bid;
   double reward = isBuy ? (tp - entryPrice) : (entryPrice - tp);
   double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
   double rr = (risk > 0) ? (reward / risk) : 0;
   
   // Journaliser les niveaux avec RR
   string dirStr = isBuy ? "BUY" : "SELL";
   LogMessage("DIVERGENCE VALIDÉE - Signal " + dirStr + " - Entry: " + DoubleToString(entryPrice, 5) + 
              ", SL: " + DoubleToString(sl, 5) + 
              ", TP: " + DoubleToString(tp, 5) + 
              ", RR: 1:" + DoubleToString(rr, 2) + 
              ", Lots: " + DoubleToString(lots, 2));
   
   // Vérifier le seuil RR minimum
   if(Min_RR > 0 && rr < Min_RR) {
      LogMessage("Trade divergence rejeté - RR insuffisant: 1:" + DoubleToString(rr, 2) + 
                 " < minimum requis: 1:" + DoubleToString(Min_RR, 2));
      return;
   }
   
   // Récupérer la valeur RSI actuelle pour le commentaire
   double currentRSI = 0.0;
   if(GetIndicatorData(indicators, buffers, 2, false)) {
      currentRSI = buffers.RSI[1];  // RSI de la bougie fermée
   }
   
   // Préparer le commentaire avec RSI
   string orderComment = "DIVERGENCE " + dirStr + " | RR:1:" + DoubleToString(rr, 2) + " | RSI:" + DoubleToString(currentRSI, 1);
   
   // Ouvrir la position
   if(isBuy) {
      if(lots > 0) OpenBuyPosition(trade, s, lots, ask, sl, tp, orderComment);
   } else {
      if(lots > 0) OpenSellPosition(trade, s, lots, bid, sl, tp, orderComment);
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

      // Fermer à l'heure de flat time si activé
      if(UseFlatTime && time_to_flat) {
         ClosePosition(trade, tk, "Flat time", 0);
      }
   }
}


// relance Process sur chaque nouvelle barre
void OnTimer(){} // non utilisé

// petite astuce: appeler Process depuis OnTick après NewBar pour garder le code clair
void OnCalculateProxy(){} // non utilisé
