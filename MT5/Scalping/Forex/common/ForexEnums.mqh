//+------------------------------------------------------------------+
//|                                              ForexEnums.mqh      |
//|                              Énumérations pour le trading Forex  |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Strategy Mode Enumeration                                       |
//+------------------------------------------------------------------+
enum ENUM_FOREX_STRATEGY_MODE
{
   FOREX_STRATEGY_BREAKOUT,   // Breakout Strategy - Suivre la tendance
   FOREX_STRATEGY_REVERSION   // Mean Reversion Strategy - Contre-tendance
};

//+------------------------------------------------------------------+
//| Order Types for Forex Trading                                   |
//+------------------------------------------------------------------+
enum ENUM_FOREX_ORDER_TYPE
{
   FOREX_ORDER_BUY_STOP,      // Achat au-dessus du prix actuel
   FOREX_ORDER_SELL_STOP,     // Vente en-dessous du prix actuel
   FOREX_ORDER_BUY_LIMIT,     // Achat en-dessous du prix actuel
   FOREX_ORDER_SELL_LIMIT     // Vente au-dessus du prix actuel
};

//+------------------------------------------------------------------+
//| Swing Point Types                                               |
//+------------------------------------------------------------------+
enum ENUM_FOREX_SWING_TYPE
{
   FOREX_SWING_HIGH,          // Point haut (résistance)
   FOREX_SWING_LOW            // Point bas (support)
};

//+------------------------------------------------------------------+
//| Risk Management Modes                                           |
//+------------------------------------------------------------------+
enum ENUM_FOREX_RISK_MODE
{
   FOREX_RISK_FIXED_LOT,      // Lot fixe
   FOREX_RISK_PERCENTAGE,     // Pourcentage du capital
   FOREX_RISK_POINTS          // Basé sur les points de risque
};
