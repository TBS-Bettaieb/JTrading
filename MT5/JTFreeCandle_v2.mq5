//+------------------------------------------------------------------+
//|                                         JTFreeCandle_v2.mq5      |
//|                      EA Free Candle - Version refactorisée       |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "2.0"
#property strict

#include <Trade/Trade.mqh>
#include "common/JT_Enums.mqh"
#include "strategies/JT_FreeCandleStrategy.mqh"
#include "common/JT_Positions.mqh"
#include "common/JT_TradeTracker.mqh"
#include "common/JT_DivergenceValidator.mqh"

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
input ENUM_EMA_FILTER_MODE EMA_Filter_Mode = EMA_TREND;  // Mode de filtrage
input double   EMA_Zone_Distance   = 20.0;               // Distance zone (points)

input group "═══ Validateur de Divergence ═══"
input bool     Use_Divergence_Validator = true;          // Activer validation par divergence
input double   Div_RSI_Buy_Level   = 35.0;               // Seuil RSI pour validation BUY
input double   Div_RSI_Sell_Level  = 65.0;               // Seuil RSI pour validation SELL
input int      Div_Swing_Length    = 5;                  // Longueur pivot pour divergence

input group "═══ Mode d'Entrée ═══"
input ENUM_ENTRY_MODE Mode         = ENTRY_REVERSION;    // Type d'entrée
input ENUM_TRADE_DIRECTION TradeDir = TRADE_BOTH;        // Filtre direction
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
input int      TouchPadPoints        = 5;                // Marge de touche (points)

input group "═══ Marqueurs Visuels ═══"
input bool     Mark_FreeCandles      = true;             // Marquer les Free Candles
input bool     Mark_DrawVLine        = true;             // Ligne verticale
input bool     Mark_DrawArrow        = true;             // Flèche directionnelle
input bool     Mark_DrawBox          = false;            // Rectangle autour bougie
input bool     Mark_DrawText         = false;            // Texte d'annotation

//---------------------------- Variables globales --------------------------------
JTFreeCandleStrategy* strategy = NULL;
JTTradeTracker* tracker = NULL;
JTDivergenceValidator* divValidator = NULL;

// Handles EMA séparés (pour les filtres)
int EMA_Fast_Handle = INVALID_HANDLE;
int EMA_Slow_Handle = INVALID_HANDLE;

//---------------------------- Fonctions utilitaires --------------------------------
string Sym() { return (InpSymbol == "" ? _Symbol : InpSymbol); }
ENUM_TIMEFRAMES TF() { return (InpTF == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF); }

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   string s = Sym();
   ENUM_TIMEFRAMES t = TF();
   
   // Créer la stratégie
   strategy = new JTFreeCandleStrategy();
   if(strategy == NULL) {
      Print("Erreur: impossible de créer la stratégie");
      return INIT_FAILED;
   }
   
   // Configurer les paramètres de trading
   TradingParameters params;
   params.symbol = s;
   params.timeframe = t;
   params.riskPercent = Risk_Percent;
   params.magic = Magic;
   params.onePositionPerSymbol = One_Pos_Per_Symbol;
   params.minRR = Min_RR;
   params.slPeriod = SL_Period;
   params.tpPeriod = TP_Period;
   params.atrMultiplier = ATR_Multiplier;
   params.atrPeriod = ATR_Period;
   params.entryMode = Mode;
   params.tradeDirection = TradeDir;
   
   // Configurer la stratégie Free Candle
   FreeCandleConfig fcConfig;
   fcConfig.bbPeriod = BB_Period;
   fcConfig.bbDeviation = BB_Dev;
   fcConfig.bbShift = BB_Shift;
   fcConfig.rsiPeriod = RSI_Period;
   fcConfig.outsidePaddingPoints = OutsidePaddingPoints;
   fcConfig.bodyMustBeOutside = BodyMustBeOutside;
   fcConfig.markCandles = Mark_FreeCandles;
   fcConfig.drawVLine = Mark_DrawVLine;
   fcConfig.drawArrow = Mark_DrawArrow;
   fcConfig.drawBox = Mark_DrawBox;
   fcConfig.drawText = Mark_DrawText;
   
   strategy.Configure(fcConfig);
   
   // Initialiser la stratégie
   if(!strategy.Initialize(params)) {
      Print("Erreur d'initialisation de la stratégie");
      delete strategy;
      strategy = NULL;
      return INIT_FAILED;
   }
   
   // Configurer les filtres
   JTTradeFilters* filters = strategy.GetFilters();
   if(filters == NULL) {
      Print("Erreur: filtres non disponibles");
      delete strategy;
      strategy = NULL;
      return INIT_FAILED;
   }
   
   // Filtre temporel
   filters.ConfigureTimeFilter(UseTimeFilter, HourRanges, UseDayFilter, DayRanges);
   
   // Filtre RSI
   if(Use_RSI_Filter) {
      IndicatorHandles handles = strategy.GetIndicators();
      filters.ConfigureRSIFilter(true, handles.RSI, RSI_Oversold, RSI_Overbought);
   }
   
   // Filtre EMA
   if(Use_EMA_Filter) {
      EMA_Fast_Handle = iMA(s, t, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
      EMA_Slow_Handle = iMA(s, t, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
      
      if(EMA_Fast_Handle == INVALID_HANDLE || EMA_Slow_Handle == INVALID_HANDLE) {
         Print("Erreur d'initialisation des EMAs");
         delete strategy;
         strategy = NULL;
         return INIT_FAILED;
      }
      
      filters.ConfigureEMAFilter(true, EMA_Fast_Handle, EMA_Slow_Handle,
                                EMA_Fast_Period, EMA_Slow_Period,
                                EMA_Filter_Mode, EMA_Zone_Distance);
      
      // Afficher les EMAs
      ChartIndicatorAdd(0, 0, EMA_Fast_Handle);
      ChartIndicatorAdd(0, 0, EMA_Slow_Handle);
   }
   
   // Validateur de divergence
   if(Use_Divergence_Validator) {
      divValidator = new JTDivergenceValidator();
      if(!divValidator.Init(s, t, RSI_Period, Div_RSI_Buy_Level, Div_RSI_Sell_Level, Div_Swing_Length)) {
         Print("Erreur d'initialisation du validateur de divergence");
         delete strategy;
         strategy = NULL;
         return INIT_FAILED;
      }
      
      filters.ConfigureDivergenceFilter(true, divValidator);
   }
   
   // Configurer le trade manager
   trade.SetExpertMagicNumber((long)Magic);
   
   // Initialiser le Trade Tracker
   tracker = new JTTradeTracker(s, Magic, BB_Period, BB_Dev, RSI_Period,
                                Use_EMA_Filter ? EMA_Fast_Period : 50,
                                Use_EMA_Filter ? EMA_Slow_Period : 100);
   
   if(tracker != NULL) {
      Print("Trade Tracker activé - Fichier CSV: TradeAnalysis_", s, "_", Magic, ".csv");
   }
   
   Print("========================================");
   Print("EA JTFreeCandle v2.0 initialisé");
   Print("Stratégie: ", strategy.GetStrategyName());
   Print("Symbole: ", s, " | Timeframe: ", EnumToString(t));
   Print("========================================");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Déinitialisation                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libérer les handles EMA
   if(EMA_Fast_Handle != INVALID_HANDLE) {
      IndicatorRelease(EMA_Fast_Handle);
      EMA_Fast_Handle = INVALID_HANDLE;
   }
   if(EMA_Slow_Handle != INVALID_HANDLE) {
      IndicatorRelease(EMA_Slow_Handle);
      EMA_Slow_Handle = INVALID_HANDLE;
   }
   
   // Rapport et libération du tracker
   if(tracker != NULL) {
      tracker.PrintReport();
      delete tracker;
      tracker = NULL;
   }
   
   // Libérer le validateur de divergence
   if(divValidator != NULL) {
      delete divValidator;
      divValidator = NULL;
   }
   
   // Libérer la stratégie
   if(strategy != NULL) {
      delete strategy;
      strategy = NULL;
   }
   
   Print("EA JTFreeCandle v2.0 déchargé");
}

//+------------------------------------------------------------------+
//| Gestion des positions ouvertes                                   |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   if(strategy == NULL) return;
   
   TradingParameters params = strategy.GetParameters();
   string s = params.symbol;
   ENUM_TIMEFRAMES t = params.timeframe;
   
   // Obtenir les bandes BB
   IndicatorHandles handles = strategy.GetIndicators();
   IndicatorBuffers buffers = strategy.GetBuffers();
   
   if(!GetIndicatorData(handles, buffers, 2, false)) return;
   
   double upper0 = buffers.BBUpper[0];
   double middle0 = buffers.BBMiddle[0];
   double lower0 = buffers.BBLower[0];
   double upper1 = buffers.BBUpper[1];
   double middle1 = buffers.BBMiddle[1];
   double lower1 = buffers.BBLower[1];
   
   // Barre en cours
   MqlRates bar[1];
   if(CopyRates(s, t, 0, 1, bar) < 1) return;
   double barHigh = bar[0].high, barLow = bar[0].low;
   
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   double pad = TouchPadPoints * point;
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);
   
   // Heure limite
   MqlDateTime ts;
   TimeToStruct(TimeCurrent(), ts);
   bool time_to_flat = (ts.hour > Flat_Hour) || (ts.hour == Flat_Hour && ts.min >= Flat_Minute);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      
      // Fermer si touche bande opposée (PRIORITAIRE)
      if(Close_On_OppositeBand) {
         bool touchedOpposite = false;
         if(type == POSITION_TYPE_BUY) {
            touchedOpposite = (barHigh >= upper1 - pad || bid >= upper0 - pad);
         }
         if(type == POSITION_TYPE_SELL) {
            touchedOpposite = (barLow <= lower1 + pad || ask <= lower0 + pad);
         }
         
         if(touchedOpposite) {
            ClosePosition(trade, tk, "Band touch exit", 0);
            if(tracker != NULL) tracker.RecordTradeClose(tk, "Band Touch");
            continue;
         }
      }
      
      // Break-Even sur médiane
      if(BE_On_MiddleBand) {
         if(type == POSITION_TYPE_BUY && (barHigh >= middle1 - pad || bid >= middle0 - pad)) {
            double newSL = op + BE_Offset_Points * point;
            if(sl < newSL) ModifyPosition(trade, tk, newSL, tp);
         }
         if(type == POSITION_TYPE_SELL && (barLow <= middle1 + pad || ask <= middle0 + pad)) {
            double newSL = op - BE_Offset_Points * point;
            if(sl == 0.0 || sl > newSL) ModifyPosition(trade, tk, newSL, tp);
         }
      }
      
      // Flat time
      if(UseFlatTime && time_to_flat) {
         ClosePosition(trade, tk, "Flat time", 0);
         if(tracker != NULL) tracker.RecordTradeClose(tk, "Flat Time");
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
      
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == Magic &&
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
//| Exécuter un trade                                                |
//+------------------------------------------------------------------+
void ExecuteTrade(SignalResult &signal, bool isDivergence = false)
{
   if(strategy == NULL || tracker == NULL) return;
   
   TradingParameters params = strategy.GetParameters();
   string s = params.symbol;
   
   double bid, ask;
   if(!strategy.GetCurrentPrices(bid, ask)) return;
   
   bool isBuy = (signal.direction > 0);
   double sl = 0, tp = 0;
   
   // Calculer SL/TP
   if(!strategy.CalculateEntryLevels(isBuy, sl, tp)) {
      Print("Erreur calcul SL/TP");
      return;
   }
   
   // Valider RR
   double entryPrice = isBuy ? ask : bid;
   if(!strategy.ValidateRiskReward(isBuy, entryPrice, sl, tp)) {
      return;
   }
   
   // Calculer le volume
   double riskPrice = isBuy ? (bid - sl) : (sl - ask);
   double lots = strategy.CalculateLotSize(riskPrice);
   
   if(lots <= 0) {
      Print("Volume invalide");
      return;
   }
   
   // Calculer RR pour le commentaire
   double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
   double reward = isBuy ? (tp - entryPrice) : (entryPrice - tp);
   double rr = (risk > 0) ? (reward / risk) : 0;
   
   // Récupérer RSI
   IndicatorBuffers buffers = strategy.GetBuffers();
   int rsiI = (int)MathRound(buffers.RSI[1]);
   
   // Préparer le commentaire
   string dirStr = isBuy ? "BUY" : "SELL";
   string orderComment = StringFormat("%s %s|R:%.2f|I:%d", 
                                     isDivergence ? "DIV" : "BB", 
                                     dirStr, rr, rsiI);
   
   // Ouvrir la position
   bool success = false;
   if(isBuy) {
      success = OpenBuyPosition(trade, s, lots, ask, sl, tp, orderComment);
   } else {
      success = OpenSellPosition(trade, s, lots, bid, sl, tp, orderComment);
   }
   
   // Enregistrer dans le tracker
   if(success && trade.ResultOrder() > 0) {
      string tradeMode = (params.entryMode == ENTRY_REVERSION ? "REVERSION" : "BREAKOUT");
      string emaMode = "";
      
      JTTradeFilters* filters = strategy.GetFilters();
      if(filters.IsEMAFilterEnabled()) {
         ENUM_EMA_FILTER_MODE mode = filters.GetEMAMode();
         switch(mode) {
            case EMA_TREND: emaMode = "TREND"; break;
            case EMA_COUNTER: emaMode = "COUNTER"; break;
            case EMA_ZONE: emaMode = "ZONE"; break;
         }
      }
      
      // Données de divergence
      double divAngle = 0, divStrength = 0;
      int divBars = 0;
      if(isDivergence) {
         strategy.GetDivergenceMetrics(divAngle, divStrength, divBars);
      }
      
      // Récupérer la config
      FreeCandleConfig fcConfig = strategy.GetConfig();
      
      tracker.RecordTradeOpen(
         trade.ResultOrder(), tradeMode, isDivergence, emaMode,
         divAngle, divStrength, divBars,
         fcConfig.bbPeriod, fcConfig.bbDeviation, fcConfig.rsiPeriod,
         RSI_Oversold, RSI_Overbought,
         EMA_Fast_Period, EMA_Slow_Period, EMA_Zone_Distance,
         Risk_Percent, Min_RR,
         SL_Period, TP_Period, ATR_Multiplier, ATR_Period,
         fcConfig.outsidePaddingPoints, fcConfig.bodyMustBeOutside,
         Use_RSI_Filter, Use_EMA_Filter, Use_Divergence_Validator
      );
      
      Print("Trade ouvert: ", orderComment);
   }
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   if(strategy == NULL) return;
   
   // Suivre les trades actifs
   if(tracker != NULL) {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == Magic) {
               tracker.UpdateTrade(ticket);
            }
         }
      }
   }
   
   // Gestion des positions
   ManageOpenPositions();
   CheckClosedTrades();
   
   // Nouvelle barre ?
   if(!strategy.IsNewBar()) return;
   
   // Vérifier si on peut trader
   if(!strategy.CanTrade()) return;
   
   // Vérifier d'abord les divergences
   if(Use_Divergence_Validator) {
      SignalResult divSignal = strategy.CheckDivergenceSignal();
      if(divSignal.isValid && divSignal.direction != 0) {
         ExecuteTrade(divSignal, true);
         return;
      }
   }
   
   // Analyser le marché
   SignalResult signal = strategy.AnalyzeMarket();
   if(signal.isValid && signal.direction != 0) {
      ExecuteTrade(signal, false);
   }
}

