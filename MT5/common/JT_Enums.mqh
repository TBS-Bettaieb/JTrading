//+------------------------------------------------------------------+
//|                                                 JT_Enums.mqh     |
//|                        Énumérations communes du projet           |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

// Profils de stratégie prédéfinis
enum ENUM_STRATEGY_PROFILE {
   PROFILE_CONSERVATIVE = 0,    // Conservateur (BB 20/2.0, RSI 25/75, EMA TREND, Risk 0.5%, RR 2.5)
   PROFILE_AGGRESSIVE = 1,      // Agressif (BB 15/1.8, RSI 30/70, EMA OFF, Risk 1.0%, RR 1.8)
   PROFILE_COUNTER_TREND = 2,   // Contre-tendance (BB 25/2.5, RSI 29/71, EMA COUNTER, Risk 0.3%, RR 3.0)
   PROFILE_BREAKOUT_MODE = 3,   // Breakout (BB 20/1.5, Mode BREAKOUT, RSI OFF, Risk 0.8%, RR 2.0)
   PROFILE_CUSTOM = 4           // Personnalisé (utilise les inputs personnalisés)
};

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

// Base de calcul du risque
enum ENUM_RISK_BASE {
   RISK_BALANCE = 0,       // Calculer sur le solde (balance)
   RISK_EQUITY = 1         // Calculer sur l'équité (equity)
};
