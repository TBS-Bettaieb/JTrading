//+------------------------------------------------------------------+
//|                                            JTFreeCandle_v3.mq5   |
//|                      EA FreeCandle - Architecture Modulaire       |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "3.0"
#property description "EA Free Candle - Architecture orientée objet réutilisable"
#property strict

#include <Trade/Trade.mqh>
#include "common/JT_StrategyFactory.mqh"
#include "common/JT_Utils.mqh"

//---------------------------- Inputs --------------------------------

input group "═══ Profil de Stratégie ═══"
input ENUM_STRATEGY_PROFILE Strategy_Profile = PROFILE_CUSTOM;        // Profil prédéfini

input group "═══ Symbole et Timeframe ═══"
input string   InpSymbol           = "";                 // Symbole (vide = _Symbol)
input ENUM_TIMEFRAMES InpTF        = PERIOD_CURRENT;     // Timeframe

input group "═══ Bollinger Bands (mode CUSTOM) ═══"
input int      BB_Period           = 20;                 // Période
input double   BB_Dev              = 2.0;                // Déviation
input int      BB_Shift            = 0;                  // Shift

input group "═══ RSI - Filtre de confirmation (mode CUSTOM) ═══"
input bool     Use_RSI_Filter      = true;               // Activer filtre RSI
input int      RSI_Period          = 14;                 // Période RSI
input double   RSI_Oversold        = 29.0;               // Seuil survente (pour BUY)
input double   RSI_Overbought      = 71.0;               // Seuil surachat (pour SELL)

input group "═══ EMA - Filtre de tendance (mode CUSTOM) ═══"
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

input group "═══ Mode d'Entrée (mode CUSTOM) ═══"
input ENUM_ENTRY_MODE Mode         = ENTRY_REVERSION;    // Type d'entrée
input ENUM_TRADE_DIRECTION TradeDir = TRADE_BOTH;        // Filtre direction
input int      OutsidePaddingPoints  = 5;                // Marge mini au-delà de la bande (points)
input bool     BodyMustBeOutside     = true;             // Seulement le corps hors bande

input group "═══ Money Management (mode CUSTOM) ═══"
input ENUM_RISK_BASE Risk_Base = RISK_EQUITY;            // Calculer risque sur
input double   Risk_Percent        = 0.1;                // % risque par trade
input bool     One_Pos_Per_Config  = true;               // 1 position max par symbole+timeframe

input group "═══ Stop Loss & Take Profit (mode CUSTOM) ═══"
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

input group "═══ Protection Daily Drawdown ═══"
input bool     Use_Daily_DD        = true;               // Activer protection DD journalier
input ENUM_DD_MODE DD_Mode         = DD_PERCENT;         // Mode calcul (% ou fixe)
input double   DD_Percent          = 2.0;                // DD max en % du capital
input double   DD_Fixed_Amount     = 200.0;              // DD max en montant fixe
input bool     DD_Close_All        = false;              // Fermer positions si DD atteint
input bool     DD_Use_Equity       = true;               // Calculer sur Equity (sinon Balance)

input group "═══ Gestion de Position ═══"
input bool     Be_On_OppositeBand    = false;            // Break-Even si touche bande opposée
input int      BE_Offset_Points      = 10;               // Offset BE (points)
input bool     UseFlatTime           = false;            // Clôture forcée à heure fixe
input int      Flat_Hour             = 23;               // Heure de clôture
input int      Flat_Minute           = 40;               // Minute de clôture
input int      TouchPadPoints        = 5;                // Marge de touche (points)

input group "═══ Marqueurs Visuels ═══"
input bool     Mark_FreeCandles      = true;             // Marquer les Free Candles
input bool     Mark_DrawVLine        = false;            // Ligne verticale
input bool     Mark_DrawArrow        = false;            // Flèche directionnelle
input bool     Mark_DrawBox          = false;            // Rectangle autour bougie
input bool     Mark_DrawText         = false;            // Texte d'annotation

//---------------------------- Variables Globales --------------------
JTFreeCandleStrategy* strategy = NULL;
ulong Magic = 0;

// Variables pour profils
int      g_BB_Period;
double   g_BB_Dev;
bool     g_Use_RSI_Filter;
int      g_RSI_Period;
double   g_RSI_Oversold;
double   g_RSI_Overbought;
bool     g_Use_EMA_Filter;
int      g_EMA_Fast_Period;
int      g_EMA_Slow_Period;
ENUM_EMA_FILTER_MODE g_EMA_Filter_Mode;
double   g_EMA_Zone_Distance;
ENUM_ENTRY_MODE g_Mode;
double   g_Risk_Percent;
double   g_Min_RR;

//---------------------------- Utils ----------------------------------
string Sym() { return (InpSymbol=="" ? _Symbol : InpSymbol); }
ENUM_TIMEFRAMES TF(){ return (InpTF==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF); }

//---------------------------- Chargement des Profils -----------------
void LoadProfileSettings()
{
   switch(Strategy_Profile)
   {
      case PROFILE_CONSERVATIVE:
         g_BB_Period = 20;
         g_BB_Dev = 2.0;
         g_Use_RSI_Filter = true;
         g_RSI_Period = 14;
         g_RSI_Oversold = 25.0;
         g_RSI_Overbought = 75.0;
         g_Use_EMA_Filter = true;
         g_EMA_Fast_Period = 50;
         g_EMA_Slow_Period = 100;
         g_EMA_Filter_Mode = EMA_TREND;
         g_EMA_Zone_Distance = 20.0;
         g_Mode = ENTRY_REVERSION;
         g_Risk_Percent = 0.5;
         g_Min_RR = 2.5;
         LogMessage("✓ Profil CONSERVATIVE chargé");
         break;
         
      case PROFILE_AGGRESSIVE:
         g_BB_Period = 15;
         g_BB_Dev = 1.8;
         g_Use_RSI_Filter = true;
         g_RSI_Period = 14;
         g_RSI_Oversold = 30.0;
         g_RSI_Overbought = 70.0;
         g_Use_EMA_Filter = false;
         g_EMA_Fast_Period = 50;
         g_EMA_Slow_Period = 100;
         g_EMA_Filter_Mode = EMA_TREND;
         g_EMA_Zone_Distance = 20.0;
         g_Mode = ENTRY_REVERSION;
         g_Risk_Percent = 1.0;
         g_Min_RR = 1.8;
         LogMessage("✓ Profil AGGRESSIVE chargé");
         break;
         
      case PROFILE_COUNTER_TREND:
         g_BB_Period = 25;
         g_BB_Dev = 2.5;
         g_Use_RSI_Filter = true;
         g_RSI_Period = 14;
         g_RSI_Oversold = 29.0;
         g_RSI_Overbought = 71.0;
         g_Use_EMA_Filter = true;
         g_EMA_Fast_Period = 50;
         g_EMA_Slow_Period = 100;
         g_EMA_Filter_Mode = EMA_COUNTER;
         g_EMA_Zone_Distance = 20.0;
         g_Mode = ENTRY_REVERSION;
         g_Risk_Percent = 0.3;
         g_Min_RR = 3.0;
         LogMessage("✓ Profil COUNTER_TREND chargé");
         break;
         
      case PROFILE_BREAKOUT_MODE:
         g_BB_Period = 20;
         g_BB_Dev = 1.5;
         g_Use_RSI_Filter = false;
         g_RSI_Period = 14;
         g_RSI_Oversold = 29.0;
         g_RSI_Overbought = 71.0;
         g_Use_EMA_Filter = false;
         g_EMA_Fast_Period = 50;
         g_EMA_Slow_Period = 100;
         g_EMA_Filter_Mode = EMA_TREND;
         g_EMA_Zone_Distance = 20.0;
         g_Mode = ENTRY_BREAKOUT;
         g_Risk_Percent = 0.8;
         g_Min_RR = 2.0;
         LogMessage("✓ Profil BREAKOUT_MODE chargé");
         break;
         
      case PROFILE_CUSTOM:
      default:
         g_BB_Period = BB_Period;
         g_BB_Dev = BB_Dev;
         g_Use_RSI_Filter = Use_RSI_Filter;
         g_RSI_Period = RSI_Period;
         g_RSI_Oversold = RSI_Oversold;
         g_RSI_Overbought = RSI_Overbought;
         g_Use_EMA_Filter = Use_EMA_Filter;
         g_EMA_Fast_Period = EMA_Fast_Period;
         g_EMA_Slow_Period = EMA_Slow_Period;
         g_EMA_Filter_Mode = EMA_Filter_Mode;
         g_EMA_Zone_Distance = EMA_Zone_Distance;
         g_Mode = Mode;
         g_Risk_Percent = Risk_Percent;
         g_Min_RR = Min_RR;
         LogMessage("✓ Profil CUSTOM chargé");
         break;
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Charger les paramètres du profil
   LoadProfileSettings();
   
   string s = Sym();
   ENUM_TIMEFRAMES tf = TF();
   
   // Générer le magic number
   Magic = GenerateMagicNumber(s, tf);
   LogMessage("═══════════════════════════════════════════════════");
   LogMessage("  JTFreeCandle v3.0 - Architecture Modulaire");
   LogMessage("═══════════════════════════════════════════════════");
   LogMessage("Magic number: " + IntegerToString(Magic) + " pour " + s + " " + EnumToString(tf));
   
   // Créer la stratégie via la factory
   strategy = JTStrategyFactory::CreateFreeCandleStrategy(
      s, tf, Magic,
      // BB
      g_BB_Period, g_BB_Dev, OutsidePaddingPoints, BodyMustBeOutside,
      // RSI
      g_Use_RSI_Filter, g_RSI_Period, g_RSI_Oversold, g_RSI_Overbought,
      // EMA
      g_Use_EMA_Filter, g_EMA_Fast_Period, g_EMA_Slow_Period, g_EMA_Filter_Mode, g_EMA_Zone_Distance,
      // Mode
      g_Mode,
      // Divergence
      Use_Divergence_Validator, Div_RSI_Buy_Level, Div_RSI_Sell_Level, Div_Swing_Length,
      // Risk
      Risk_Base, g_Risk_Percent, g_Min_RR, One_Pos_Per_Config,
      // SL/TP
      SL_Period, TP_Period, ATR_Multiplier, ATR_Period,
      // Time filters
      UseTimeFilter, HourRanges, UseDayFilter, DayRanges,
      // Daily DD
      Use_Daily_DD, DD_Mode, DD_Percent, DD_Fixed_Amount, DD_Close_All, DD_Use_Equity,
      // Position management
      Be_On_OppositeBand, BE_Offset_Points, UseFlatTime, Flat_Hour, Flat_Minute, TouchPadPoints,
      // Direction
      TradeDir,
      // Markers
      Mark_FreeCandles, Mark_DrawVLine, Mark_DrawArrow, Mark_DrawBox, Mark_DrawText
   );
   
   if(strategy == NULL) {
      LogError("Échec de création de la stratégie");
      return INIT_FAILED;
   }
   
   // Initialiser la stratégie
   if(!strategy.Init()) {
      delete strategy;
      strategy = NULL;
      LogError("Échec de l'initialisation de la stratégie");
      return INIT_FAILED;
   }
   
   LogMessage("═══════════════════════════════════════════════════");
   LogMessage("✓ EA initialisé avec succès - Prêt au trading");
   LogMessage("═══════════════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LogMessage("═══════════════════════════════════════════════════");
   LogMessage("  Déinitialisation de l'EA");
   LogMessage("  Raison: " + IntegerToString(reason));
   LogMessage("═══════════════════════════════════════════════════");
   
   if(strategy != NULL) {
      strategy.Deinit();
      delete strategy;
      strategy = NULL;
   }
   
   LogMessage("✓ EA déinitialisé avec succès");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(strategy != NULL) {
      strategy.OnTick();
   }
}

//+------------------------------------------------------------------+

