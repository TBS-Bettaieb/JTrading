//+------------------------------------------------------------------+
//|                                                 JT_Enums.mqh     |
//|                        Énumérations communes du projet           |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

// Énumération des modes d'entrée
enum ENUM_ENTRY_MODE {
   ENTRY_REVERSION = 0,    // Réversion à la moyenne
   ENTRY_BREAKOUT = 1      // Cassure
};

// Énumération des directions de trading
enum ENUM_TRADE_DIRECTION {
   TRADE_BOTH = 0,         // Les deux directions
   TRADE_ONLY_BUY = 1,     // Achats uniquement
   TRADE_ONLY_SELL = 2     // Ventes uniquement
};

// Mode de filtre EMA
enum ENUM_EMA_FILTER_MODE {
   EMA_TREND = 0,          // Suivre la tendance
   EMA_COUNTER = 1,        // Contre-tendance
   EMA_ZONE = 2            // Éviter zone neutre
};
