//+------------------------------------------------------------------+
//|                                        EA_ADX_RSI_MA50_Score.mq5 |
//|                                                                  |
//|  Stratégie avec système de scoring ADX + RSI + MA50             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include "../../CommonUtils/TimeFilter.mqh"
#include "../../CommonUtils/TradingUtils.mqh"
#include "../../CommonUtils/TradingEnums.mqh"

//+------------------------------------------------------------------+
//| PARAMÈTRES FIGÉS (pas d'inputs)                                 |
//+------------------------------------------------------------------+


// Système de scoring
input int SCORE_MIN_ENTRY = 6;           // Score minimum pour entrer en position
input int SCORE_HIGH_CONFIDENCE = 9;     // Score haute confiance (lot plus important)


// Gestion du risque
input group "=== Risk Management ==="
input ENUM_RISK_MODE RISK_MODE = RISK_PERCENTAGE;  // Mode de gestion du risque
input double RISK_PERCENT_NORMAL = 0.8;   // Risque normal
input double RISK_PERCENT_HIGH = 1.2;     // Risque si haute confiance
const double MIN_RR_RATIO = 1.5;          // Ratio R:R minimum
input int SL_POINTS = 400;                // Stop Loss en points
input int TP_MULTIPLIER = 2;              // TP = SL * multiplier



// Indicateurs
const int ADX_PERIOD = 5;
const int RSI_PERIOD = 3;
const int MA_PERIOD = 50;
const ENUM_MA_METHOD MA_METHOD = MODE_EMA;
input ENUM_TIMEFRAMES TIMEFRAME = PERIOD_CURRENT;





// Trading
const int BASE_MAGIC_NUMBER = 20251015;
const string TRADE_COMMENT = "Score_EA";
const string STRATEGY_NAME = "ScoreMaster";
input int MAX_POSITIONS = 1;
input bool USE_TRAILING = true;
input int TRAILING_START = 25;
input int TRAILING_STEP = 10;

// Filtre horaire (géré par CommonUtils/TimeFilter.mqh)
input group "=== Time Filter ==="
input int SHInput = 8;   // Start Hour (0-23)
input int EHInput = 18;  // End Hour (0-23)

//+------------------------------------------------------------------+
//| SYSTÈME DE SCORING - POIDS DES CONDITIONS                       |
//+------------------------------------------------------------------+

// ADX (force de tendance)
const int SCORE_ADX_WEAK = 0;        // ADX < 20
const int SCORE_ADX_MODERATE = 1;    // ADX 20-25
const int SCORE_ADX_STRONG = 2;      // ADX 25-35
const int SCORE_ADX_VERY_STRONG = 3; // ADX > 35

// RSI (momentum)
const int SCORE_RSI_EXTREME = 4;     
const int SCORE_RSI_ZONE = 2;        
const int SCORE_RSI_MODERATE = 0;    


// MA (tendance)
const int SCORE_MA_TREND = 2;        // Prix dans le sens de MA
const int SCORE_MA_DISTANCE_CLOSE = 1; // Prix proche de MA (<0.5%)
const int SCORE_MA_DISTANCE_FAR = -1;  // Prix très éloigné (>2%)

// Confluence (conditions multiples alignées)
const int SCORE_CONFLUENCE_BONUS = 2; // Bonus si ADX>30 + RSI zone + MA alignée

// Croisements
const int SCORE_PRICE_CROSS_MA = 1;   // Prix vient de croiser MA

//--- Variables globales
CTrade trade;
TimeFilter timeFilter;
int handle_ADX;
int handle_RSI;
int handle_MA;
int MAGIC_NUMBER;

double adx_buffer[];
double rsi_buffer[];
double ma_buffer[];

datetime last_bar_time = 0;
int total_bars = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    // Générer un magic number unique et valider le symbole
    if(!ValidateSymbol(_Symbol))
    {
        Print("❌ Symbole invalide: ", _Symbol);
        return(INIT_FAILED);
    }
    MAGIC_NUMBER = GenerateMagicNumber(BASE_MAGIC_NUMBER, 0, TIMEFRAME, STRATEGY_NAME);
    
    trade.SetExpertMagicNumber(MAGIC_NUMBER);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetDeviationInPoints(30);
    
    handle_ADX = iADX(_Symbol, TIMEFRAME, ADX_PERIOD);
    handle_RSI = iRSI(_Symbol, TIMEFRAME, RSI_PERIOD, PRICE_CLOSE);
    handle_MA = iMA(_Symbol, TIMEFRAME, MA_PERIOD, 0, MA_METHOD, PRICE_CLOSE);
    
    if(handle_ADX == INVALID_HANDLE || handle_RSI == INVALID_HANDLE || handle_MA == INVALID_HANDLE)
    {
        Print("Erreur création indicateurs");
        return(INIT_FAILED);
    }
    
    ArraySetAsSeries(adx_buffer, true);
    ArraySetAsSeries(rsi_buffer, true);
    ArraySetAsSeries(ma_buffer, true);
    
    // Initialiser le filtre horaire
    timeFilter.InitFromSimpleHours(SHInput, EHInput);
    timeFilter.SetLogPrefix("[ScoreMaster] ");
    Print("╔════════════════════════════════════════════════════════╗");
    Print("║      EA ADX + RSI + MA50 - SYSTÈME DE SCORING         ║");
    Print("╚════════════════════════════════════════════════════════╝");
    Print("Symbole: ", _Symbol, " | Timeframe: ", EnumToString(TIMEFRAME));
    Print("Magic Number: ", MAGIC_NUMBER, " | Stratégie: ", STRATEGY_NAME);
    Print("Score minimum: ", SCORE_MIN_ENTRY, " | Haute confiance: ", SCORE_HIGH_CONFIDENCE);
    Print("Mode risque: ", EnumToString(RISK_MODE), " | Normal: ", RISK_PERCENT_NORMAL, "% | Élevé: ", RISK_PERCENT_HIGH, "%");
    Print("ADX:", ADX_PERIOD, " | RSI:", RSI_PERIOD, " | MA:", MA_PERIOD);
    Print("Filtre horaire: ", timeFilter.Describe());
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(handle_ADX != INVALID_HANDLE) IndicatorRelease(handle_ADX);
    if(handle_RSI != INVALID_HANDLE) IndicatorRelease(handle_RSI);
    if(handle_MA != INVALID_HANDLE) IndicatorRelease(handle_MA);
    
    Comment("");
    Print("EA arrêté");
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   if(USE_TRAILING) TrailingStop();
    if(!IsNewBar()) return;
    
    if(!IsTimeToTrade()) return;
    
    if(CopyBuffer(handle_ADX, 0, 0, 3, adx_buffer) <= 0) return;
    if(CopyBuffer(handle_RSI, 0, 0, 3, rsi_buffer) <= 0) return;
    if(CopyBuffer(handle_MA, 0, 0, 3, ma_buffer) <= 0) return;
    
    double adx_curr = adx_buffer[1];
    double adx_prev = adx_buffer[2];
    double rsi_curr = rsi_buffer[1];
    double rsi_prev = rsi_buffer[2];
    double ma_curr = ma_buffer[1];
    double ma_prev = ma_buffer[2];
    
    double close_curr = iClose(_Symbol, TIMEFRAME, 1);
    double close_prev = iClose(_Symbol, TIMEFRAME, 2);
    double high_curr = iHigh(_Symbol, TIMEFRAME, 1);
    double low_curr = iLow(_Symbol, TIMEFRAME, 1);
    
    //--- Calculer les scores
    int buy_score = CalculateBuyScore(adx_curr, rsi_curr, rsi_prev, ma_curr, close_curr, close_prev);
    int sell_score = CalculateSellScore(adx_curr, rsi_curr, rsi_prev, ma_curr, close_curr, close_prev);
    
    //--- Affichage
    string signal = "⚪ NEUTRE";
    int max_score = MathMax(buy_score, sell_score);
    
    if(buy_score >= SCORE_MIN_ENTRY) 
        signal = StringFormat("🟢 ACHAT (Score: %d)", buy_score);
    else if(sell_score >= SCORE_MIN_ENTRY) 
        signal = StringFormat("🔴 VENTE (Score: %d)", sell_score);
    
    Comment(StringFormat(
        "╔═══════════════════════════════════════╗\n" +
        "║  %s - %s\n" +
        "╠═══════════════════════════════════════╣\n" +
        "║ ADX: %.1f | RSI: %.1f | MA: %.5f\n" +
        "║ Prix: %.5f | Positions: %d/%d\n" +
        "╠═══════════════════════════════════════╣\n" +
        "║ Score ACHAT:  %2d / %d %s\n" +
        "║ Score VENTE:  %2d / %d %s\n" +
        "╠═══════════════════════════════════════╣\n" +
        "║ %s\n" +
        "╚═══════════════════════════════════════╝",
        _Symbol, EnumToString(TIMEFRAME),
        adx_curr, rsi_curr, ma_curr,
        close_curr, CountPositions(), MAX_POSITIONS,
        buy_score, SCORE_MIN_ENTRY, (buy_score >= SCORE_HIGH_CONFIDENCE ? "⭐" : ""),
        sell_score, SCORE_MIN_ENTRY, (sell_score >= SCORE_HIGH_CONFIDENCE ? "⭐" : ""),
        signal
    ));
    
    if(CountPositions() >= MAX_POSITIONS) return;
    
    
    
    //--- Exécuter les trades
    if(buy_score >= SCORE_MIN_ENTRY)
    {
        bool high_confidence = (buy_score >= SCORE_HIGH_CONFIDENCE);
        OpenBuy(buy_score, high_confidence);
    }
    else if(sell_score >= SCORE_MIN_ENTRY)
    {
        bool high_confidence = (sell_score >= SCORE_HIGH_CONFIDENCE);
        OpenSell(sell_score, high_confidence);
    }
}

//+------------------------------------------------------------------+
//| Calcule le score pour un signal ACHAT                           |
//+------------------------------------------------------------------+
int CalculateBuyScore(double adx, double rsi, double rsi_prev, double ma, double close, double close_prev)
{
    int score = 0;
    
    //--- 1. SCORE ADX (force de tendance)
    if(adx > 30)
        score += SCORE_ADX_VERY_STRONG;
    else if(adx > 25)
        score += SCORE_ADX_STRONG;
    else if(adx > 20)
        score += SCORE_ADX_MODERATE;
    else
        score += SCORE_ADX_WEAK;
    
    //--- 2. SCORE RSI (survente = opportunité achat)
    if(rsi < 20)
        score += SCORE_RSI_EXTREME;
    else if(rsi < 25)
        score += SCORE_RSI_ZONE;
    else if(rsi < 30)
        score += SCORE_RSI_MODERATE;
    else if(rsi >= 31)
        score += -2; // Pénalité si surachat
    
    
    //--- 3. SCORE MA (tendance haussière)
    double distance_pct = (close - ma) / ma * 100;
    
    if(close > ma) // Prix au-dessus de MA (tendance haussière)
    {
        score += SCORE_MA_TREND;
        
        if(MathAbs(distance_pct) < 0.5) // Très proche
            score += SCORE_MA_DISTANCE_CLOSE;
        else if(MathAbs(distance_pct) > 2.0) // Trop éloigné
            score += SCORE_MA_DISTANCE_FAR;
    }
    else // Prix sous MA
    {
        if(MathAbs(distance_pct) < 0.3) // Très proche, pourrait rebondir
            score += 1;
        else
            score -= 1; // Contre-tendance
    }
    
    //--- 4. BONUS CONFLUENCE
    if(adx > 30 && rsi < 35 && close > ma)
    {
        score += SCORE_CONFLUENCE_BONUS;
    }
    
    //--- 5. CROISEMENT MA
    if(close > ma && close_prev <= ma) // Prix vient de croiser MA à la hausse
    {
        score += SCORE_PRICE_CROSS_MA;
    }
    
    //--- 6. RSI MOMENTUM (sortie de survente)
    if(rsi > rsi_prev && rsi_prev < 30 && rsi < 50)
    {
        score += 1; // RSI remonte de la survente
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Calcule le score pour un signal VENTE                           |
//+------------------------------------------------------------------+
int CalculateSellScore(double adx, double rsi, double rsi_prev, double ma, double close, double close_prev)
{
    int score = 0;
    
    //--- 1. SCORE ADX (force de tendance)
    if(adx > 30)
        score += SCORE_ADX_VERY_STRONG;
    else if(adx > 25)
        score += SCORE_ADX_STRONG;
    else if(adx > 20)
        score += SCORE_ADX_MODERATE;
    else
        score += SCORE_ADX_WEAK;
    
    //--- 2. SCORE RSI (surachat = opportunité vente)
    if(rsi > 80)
        score += SCORE_RSI_EXTREME;
    else if(rsi > 75)
        score += SCORE_RSI_ZONE;
    else if(rsi > 70)
        score += SCORE_RSI_MODERATE;
    else if(rsi <= 69)
        score -= 2; // Pénalité si survente
    
    //--- 3. SCORE MA (tendance baissière)
    double distance_pct = (ma - close) / ma * 100;
    
    if(close < ma) // Prix sous MA (tendance baissière)
    {
        score += SCORE_MA_TREND;
        
        if(MathAbs(distance_pct) < 0.5)
            score += SCORE_MA_DISTANCE_CLOSE;
        else if(MathAbs(distance_pct) > 2.0)
            score += SCORE_MA_DISTANCE_FAR;
    }
    else // Prix au-dessus MA
    {
        if(MathAbs(distance_pct) < 0.3)
            score += 1;
        else
            score -= 1;
    }
    
    //--- 4. BONUS CONFLUENCE
    if(adx > 30 && rsi > 65 && close < ma)
    {
        score += SCORE_CONFLUENCE_BONUS;
    }
    
    //--- 5. CROISEMENT MA
    if(close < ma && close_prev >= ma) // Prix vient de croiser MA à la baisse
    {
        score += SCORE_PRICE_CROSS_MA;
    }
    
    //--- 6. RSI MOMENTUM (sortie de surachat)
    if(rsi < rsi_prev && rsi_prev > 70 && rsi > 50)
    {
        score += 1; // RSI redescend du surachat
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Ouvre position ACHAT                                             |
//+------------------------------------------------------------------+
void OpenBuy(int score, bool high_confidence)
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    double sl = NormalizeDouble(ask - SL_POINTS * point, digits);
    double tp = NormalizeDouble(ask + (SL_POINTS * TP_MULTIPLIER * point), digits);
    
    double risk_pct = high_confidence ? RISK_PERCENT_HIGH : RISK_PERCENT_NORMAL;
    double lot = CalculateLotSize(ask, sl, risk_pct);
    
    if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        return;
    
    string comment = StringFormat("%s|BUY|S%d%s", TRADE_COMMENT, score, (high_confidence ? "|HC" : ""));
    
    if(trade.Buy(lot, _Symbol, ask, sl, tp, comment))
    {
        Print(StringFormat("✓ ACHAT | Score: %d%s | Lot: %.2f | SL: %.5f | TP: %.5f", 
                          score, (high_confidence ? " ⭐" : ""), lot, sl, tp));
    }
    else
    {
        Print("✗ Erreur ACHAT: ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Ouvre position VENTE                                             |
//+------------------------------------------------------------------+
void OpenSell(int score, bool high_confidence)
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    double sl = NormalizeDouble(bid + SL_POINTS * point, digits);
    double tp = NormalizeDouble(bid - (SL_POINTS * TP_MULTIPLIER * point), digits);
    
    double risk_pct = high_confidence ? RISK_PERCENT_HIGH : RISK_PERCENT_NORMAL;
    double lot = CalculateLotSize(bid, sl, risk_pct);
    
    if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        return;
    
    string comment = StringFormat("%s|SELL|S%d%s", TRADE_COMMENT, score, (high_confidence ? "|HC" : ""));
    
    if(trade.Sell(lot, _Symbol, bid, sl, tp, comment))
    {
        Print(StringFormat("✓ VENTE | Score: %d%s | Lot: %.2f | SL: %.5f | TP: %.5f", 
                          score, (high_confidence ? " ⭐" : ""), lot, sl, tp));
    }
    else
    {
        Print("✗ Erreur VENTE: ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Calcule taille du lot                                           |
//+------------------------------------------------------------------+
double CalculateLotSize(double entry, double sl, double risk_pct)
{
    if(sl == 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * risk_pct / 100.0;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    double sl_distance = MathAbs(entry - sl) / point;
    double lot = risk_amount / (sl_distance * tick_value);
    
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot = MathFloor(lot / lot_step) * lot_step;
    lot = MathMax(min_lot, MathMin(max_lot, lot));
    
    return lot;
}

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
//+------------------------------------------------------------------+
void TrailingStop()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;
        
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        
        double pos_open = PositionGetDouble(POSITION_PRICE_OPEN);
        double pos_sl = PositionGetDouble(POSITION_SL);
        double pos_tp = PositionGetDouble(POSITION_TP);
        
        ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        if(pos_type == POSITION_TYPE_BUY)
        {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double profit_points = (bid - pos_open) / point;
            
            if(profit_points >= TRAILING_START)
            {
                double new_sl = bid - TRAILING_STEP * point;
                new_sl = NormalizeDouble(new_sl, digits);
                
                if(new_sl > pos_sl + point)
                {
                    trade.PositionModify(ticket, new_sl, pos_tp);
                }
            }
        }
        else
        {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profit_points = (pos_open - ask) / point;
            
            if(profit_points >= TRAILING_START)
            {
                double new_sl = ask + TRAILING_STEP * point;
                new_sl = NormalizeDouble(new_sl, digits);
                
                if(new_sl < pos_sl - point || pos_sl == 0)
                {
                    trade.PositionModify(ticket, new_sl, pos_tp);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Compte positions                                                 |
//+------------------------------------------------------------------+
int CountPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Vérifie nouvelle barre                                          |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    int bars = iBars(_Symbol, TIMEFRAME);
    if(bars != total_bars)
    {
        total_bars = bars;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Vérifie filtre horaire                                          |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    int current_hour = time_struct.hour;
    
    if(SHInput <= EHInput)
        return (current_hour >= SHInput && current_hour < EHInput);
    else
        return (current_hour >= SHInput || current_hour < EHInput);
}

//+------------------------------------------------------------------+