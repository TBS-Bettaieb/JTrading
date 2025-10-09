//+------------------------------------------------------------------+
//|                                 JT_BB_FreeCandle_Rsi_Refactored.mq5  |
//|                Bollinger Bands + RSI avec bougie libre (MT5)    |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict
#property description "EA: Bollinger Bands avec confirmation RSI et bougie libre."
#property description "Entrée: pullback/cassure avec confirmation RSI."
#property description "Sortie: SL basé ATR, TP par RR, option fermeture sur bande opposée."

// Inclure nos fichiers d'utilitaires
#include "JT_Indicators.mqh"
#include "JT_Positions.mqh"
#include "JT_MoneyManagement.mqh"
#include "JT_Utils.mqh"

//---------------------------- Inputs --------------------------------
input string InpSymbol              = "";                 // Symbole (vide = _Symbol)
input ENUM_TIMEFRAMES InpTimeframe  = PERIOD_CURRENT;     // Unité de temps
// Bollinger
input int      InpBBPeriod          = 20;                 // Période BB
input double   InpBBDeviation       = 2.0;                // Déviation BB
input int      InpBBShift           = 0;                  // Décalage BB
// RSI
input int      InpRSIPeriod         = 14;                 // RSI période
input int      InpRSIBuyLevel       = 35;                 // RSI niveau achat (cross up)
input int      InpRSISellLevel      = 65;                 // RSI niveau vente (cross down)
// Entrée
enum EntryMode { REVERSION=0, BREAKOUT=1 };
input EntryMode Mode                = REVERSION;          // Type d'entrée
// Direction filter
enum TradeDirection { DIR_BOTH=0, DIR_ONLY_BUY=1, DIR_ONLY_SELL=2 };
input TradeDirection TradeDir       = DIR_BOTH;           // Filtre direction: Both/Only Buy/Only Sell
// Money management
input double   Risk_Percent         = 0.10;               // % du solde risqué par trade
input int      ATR_Period           = 14;                 // ATR période pour SL
input double   ATR_SL_Mult          = 4.0;                // SL = ATR * multiplicateur
input double   RR_TP                = 1.5;                // TP = RR * risque
input bool     One_Pos_Per_Symbol   = true;               // 1 position par symbole
input ulong    Magic                = 20251009;           // Magic number (identifie l'EA)
input int      Slippage             = 10;                 // Slippage (points)
// Sorties
input bool     ExitOnOppositeBand   = true;               // Fermer si touche bande opposée
input bool     ExitOnRSI_Midline    = false;              // Fermer si RSI croise 50
input bool     BE_On_MiddleBand     = true;               // Passer Break-Even sur médiane
input int      BE_Offset_Points     = 0;                  // Offset BE en points (>=0)
// Time filter (allow trading only in specific hour ranges)
input bool     UseTimeFilter        = false;              // Activer filtre horaire
input int      Range1StartHour      = 1;                  // Début plage 1 (0-23)
input int      Range1EndHour        = 1;                  // Fin plage 1 (0-23)
input int      Range2StartHour      = 8;                  // Début plage 2 (0-23)
input int      Range2EndHour        = 9;                  // Fin plage 2 (0-23)
input int      Range3StartHour      = 16;                 // Début plage 3 (0-23)
input int      Range3EndHour        = 23;                 // Fin plage 3 (0-23)
// Outside candle strictness
input int      OutsidePaddingPoints = 5;                  // marge mini au-delà de la bande
input bool     BodyMustBeOutside    = true;               // seulement le corps hors bande
input string   OrderComment         = "JT_BB_FreeCandle_Rsi"; // Commentaire ordre

//---------------------------- Globals --------------------------------
CTrade trade;
string sym;
ENUM_TIMEFRAMES tf;
datetime lastBarTime = 0;

// Structures pour les indicateurs
IndicatorHandles indicators;
IndicatorBuffers buffers;

//---------------------------- Lifecycle --------------------------------
int OnInit()
{
   // Initialiser les variables globales
   sym = (InpSymbol == "" ? _Symbol : InpSymbol);
   tf  = InpTimeframe;
   
   // Initialiser les indicateurs
   if(!InitIndicators(
      indicators,
      sym,
      tf,
      InpBBPeriod,
      InpBBDeviation,
      InpBBShift,
      InpRSIPeriod,
      ATR_Period
   )) {
      return(INIT_FAILED);
   }
   
   // Configurer le trade
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(Slippage);
   
   LogMessage("EA initialisé avec succès sur " + sym + " / " + EnumToString(tf));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Libérer les handles des indicateurs
   ReleaseIndicators(indicators);
   LogMessage("EA arrêté, raison: " + IntegerToString(reason));
}

//---------------------------- Core logic --------------------------------
void OnTick()
{
   // Vérifications préliminaires
   if(_Symbol != sym) return;
   
   if(!IsHourAllowed(
      UseTimeFilter,
      Range1StartHour,
      Range1EndHour,
      Range2StartHour,
      Range2EndHour,
      Range3StartHour,
      Range3EndHour
   )) return;
   
   // Récupérer les données des indicateurs
   if(!GetIndicatorData(indicators, buffers)) {
      LogError("Erreur lors de la récupération des données des indicateurs");
      return;
   }
   
   // Gestion des positions existantes
   ManagePositions();
   
   // Vérifier si c'est une nouvelle bougie pour les entrées
   if(!IsNewBar(sym, tf, lastBarTime)) return;
   
   // Récupérer les données des bougies
   CandleData candles[3];
   if(!GetCandleData(sym, tf, 3, candles)) {
      LogError("Erreur lors de la récupération des données des bougies");
      return;
   }
   
   // Analyser les conditions d'entrée
   int signal = AnalyzeEntryConditions(candles);
   
   // Vérifier s'il y a une position ouverte
   int dir = 0;
   ulong ticket = 0;
   bool hasPos = HasOpenPosition(sym, Magic, dir, ticket);
   
   // Exécuter l'entrée si un signal est détecté
   if(signal != 0 && (!hasPos || !One_Pos_Per_Symbol)) {
      ExecuteEntry(signal == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   }
}

// Analyse les conditions d'entrée et retourne un signal (1=buy, -1=sell, 0=none)
int AnalyzeEntryConditions(CandleData &candles[])
{
   // Récupérer les valeurs des indicateurs
   double rsi0 = buffers.RSI[0];
   double rsi1 = buffers.RSI[1];
   
   double up0 = buffers.BBUpper[0];
   double mid0 = buffers.BBMiddle[0];
   double lo0 = buffers.BBLower[0];
   
   double up1 = buffers.BBUpper[1];
   double mid1 = buffers.BBMiddle[1];
   double lo1 = buffers.BBLower[1];
   
   // Vérifier si les bougies sont à l'extérieur des bandes
   bool isAboveUpperBand = IsCandleOutsideBand(
      candles[1],
      up1,
      true,
      OutsidePaddingPoints,
      BodyMustBeOutside
   );
   
   bool isBelowLowerBand = IsCandleOutsideBand(
      candles[1],
      lo1,
      false,
      OutsidePaddingPoints,
      BodyMustBeOutside
   );
   
   int signal = 0;
   
   // Logique d'entrée selon le mode
   if(Mode == REVERSION) {
      // Mode Reversion: entrer dans la direction opposée à la cassure
      if(isAboveUpperBand && candles[1].isRed && CrossDown(rsi1, rsi0, InpRSISellLevel)) 
         signal = -1; // SELL
      if(isBelowLowerBand && candles[1].isGreen && CrossUp(rsi1, rsi0, InpRSIBuyLevel)) 
         signal = 1;  // BUY
   } else {
      // Mode Breakout: entrer dans la direction de la cassure
      if(isAboveUpperBand && CrossUp(rsi1, rsi0, InpRSIBuyLevel)) 
         signal = 1;  // BUY
      if(isBelowLowerBand && CrossDown(rsi1, rsi0, InpRSISellLevel)) 
         signal = -1; // SELL
   }
   
   // Apply direction filter
   if(TradeDir == DIR_ONLY_BUY && signal < 0) signal = 0;
   if(TradeDir == DIR_ONLY_SELL && signal > 0) signal = 0;
   
   // Log du signal
   if(signal != 0) {
      string signalType = signal > 0 ? "BUY" : "SELL";
      string modeType = Mode == REVERSION ? "REVERSION" : "BREAKOUT";
      LogMessage("Signal " + signalType + " détecté - RSI: " + DoubleToString(rsi0, 2) + 
                 " Mode: " + modeType);
   }
   
   return signal;
}

// Gère les positions ouvertes
void ManagePositions()
{
   // Récupérer les données des bougies
   CandleData candles[1];
   if(!GetCandleData(sym, tf, 1, candles)) return;
   
   // Récupérer les valeurs des indicateurs
   double rsi0 = buffers.RSI[0];
   double up0 = buffers.BBUpper[0];
   double mid0 = buffers.BBMiddle[0];
   double lo0 = buffers.BBLower[0];
   
   // Vérifier s'il y a une position ouverte
   int dir = 0;
   ulong ticket = 0;
   bool hasPos = HasOpenPosition(sym, Magic, dir, ticket);
   
   if(!hasPos) return;
   
   // Récupérer les informations de la position
   if(!PositionSelectByTicket(ticket)) return;
   
   double op = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   
   // Fermeture sur bande opposée
   if(ExitOnOppositeBand) {
      bool shouldClose = false;
      
      if(dir == 1 && (candles[0].close >= up0 || candles[0].high >= up0)) {
         // Long touche bande haute
         shouldClose = true;
         LogMessage("Fermeture LONG sur bande haute: " + FormatPrice(up0, sym));
      }
      
      if(dir == -1 && (candles[0].close <= lo0 || candles[0].low <= lo0)) {
         // Short touche bande basse
         shouldClose = true;
         LogMessage("Fermeture SHORT sur bande basse: " + FormatPrice(lo0, sym));
      }
      
      if(shouldClose) {
         if(!ClosePosition(trade, ticket)) {
            LogError("Échec de fermeture de position", GetLastError());
         }
         return;
      }
   }
   
   // Fermeture sur croisement RSI
   if(ExitOnRSI_Midline) {
      static double prevRSI = 50.0;
      bool cross50up = CrossUp(prevRSI, rsi0, 50.0);
      bool cross50down = CrossDown(prevRSI, rsi0, 50.0);
      
      if((dir == 1 && cross50down) || (dir == -1 && cross50up)) {
         LogMessage("Fermeture sur croisement RSI 50: " + DoubleToString(rsi0, 2));
         if(!ClosePosition(trade, ticket)) {
            LogError("Échec de fermeture de position", GetLastError());
         }
         return;
      }
      
      prevRSI = rsi0;
   }
   
   // Break-even sur bande médiane
   if(BE_On_MiddleBand) {
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      
      if(dir == 1 && (candles[0].close >= mid0 || candles[0].high >= mid0)) {
         double newSL = op + BE_Offset_Points * point;
         if(sl < newSL) {
            LogMessage("Modification SL à BE+" + IntegerToString(BE_Offset_Points) + " points");
            if(!ModifyPosition(trade, ticket, newSL, tp)) {
               LogError("Échec de modification de position", GetLastError());
            }
         }
      }
      
      if(dir == -1 && (candles[0].close <= mid0 || candles[0].low <= mid0)) {
         double newSL = op - BE_Offset_Points * point;
         if(sl == 0.0 || sl > newSL) {
            LogMessage("Modification SL à BE+" + IntegerToString(BE_Offset_Points) + " points");
            if(!ModifyPosition(trade, ticket, newSL, tp)) {
               LogError("Échec de modification de position", GetLastError());
            }
         }
      }
   }
}

// Exécute une entrée de position
void ExecuteEntry(ENUM_ORDER_TYPE type)
{
   // Récupérer les prix actuels
   MqlTick tick;
   if(!SymbolInfoTick(sym, tick)) {
      LogError("Impossible d'obtenir les prix actuels");
      return;
   }
   
   double ask = tick.ask;
   double bid = tick.bid;
   double atr = buffers.ATR[0];
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   
   // Calculer la distance du SL en points
   double sl_points = PriceToPoints(sym, atr * ATR_SL_Mult);
   if(sl_points <= 0) {
      LogError("Distance du SL invalide");
      return;
   }
   
   // Calculer le volume
   double lots = CalculateRiskBasedVolume(sym, Risk_Percent, sl_points);
   if(lots <= 0) {
      LogError("Volume de lot invalide");
      return;
   }
   
   // Calculer SL et TP
   double sl = 0, tp = 0;
   
   if(type == ORDER_TYPE_BUY) {
      sl = ask - sl_points * point;
      double risk = ask - sl;
      tp = ask + risk * RR_TP;
      
      LogMessage("Ouverture BUY: Lot=" + DoubleToString(lots, 2) + 
                ", SL=" + FormatPrice(sl, sym) + 
                ", TP=" + FormatPrice(tp, sym));
                
      if(!OpenBuyPosition(trade, sym, lots, ask, sl, tp, OrderComment)) {
         LogError("Échec d'ouverture BUY", GetLastError());
      }
   }
   else if(type == ORDER_TYPE_SELL) {
      sl = bid + sl_points * point;
      double risk = sl - bid;
      tp = bid - risk * RR_TP;
      
      LogMessage("Ouverture SELL: Lot=" + DoubleToString(lots, 2) + 
                ", SL=" + FormatPrice(sl, sym) + 
                ", TP=" + FormatPrice(tp, sym));
                
      if(!OpenSellPosition(trade, sym, lots, bid, sl, tp, OrderComment)) {
         LogError("Échec d'ouverture SELL", GetLastError());
      }
   }
}
//+------------------------------------------------------------------+
