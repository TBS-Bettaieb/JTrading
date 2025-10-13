//+------------------------------------------------------------------+
//|                                            JT_BaseStrategy.mqh   |
//|                        Classe abstraite pour stratégies de trading|
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "JT_Enums.mqh"
#include "JT_Indicators.mqh"
#include "JT_MoneyManagement.mqh"
#include "JT_TradeFilters.mqh"

// Structure pour les paramètres de trading
struct TradingParameters {
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   double riskPercent;
   ulong magic;
   bool onePositionPerSymbol;
   double minRR;
   int slPeriod;
   int tpPeriod;
   double atrMultiplier;
   int atrPeriod;
   ENUM_ENTRY_MODE entryMode;
   ENUM_TRADE_DIRECTION tradeDirection;
};

// Structure pour le résultat d'analyse de signal
struct SignalResult {
   int direction;          // 0=aucun, +1=buy, -1=sell
   bool isValid;           // Signal valide après filtres
   string reason;          // Raison du signal/rejet
   double confidence;      // Niveau de confiance (0-1)
};

//+------------------------------------------------------------------+
//| Classe abstraite de base pour toutes les stratégies             |
//+------------------------------------------------------------------+
class JTBaseStrategy
{
protected:
   // Paramètres de trading
   TradingParameters m_params;
   
   // Indicateurs et filtres
   IndicatorHandles m_indicators;
   IndicatorBuffers m_buffers;
   JTTradeFilters* m_filters;
   
   // État
   datetime m_lastBarTime;
   bool m_initialized;
   
   // Logging
   void LogInfo(string message) {
      Print("[", m_params.symbol, "][INFO] ", message);
   }
   
   void LogError(string message) {
      Print("[", m_params.symbol, "][ERROR] ", message);
   }
   
   void LogSignal(string message) {
      Print("[", m_params.symbol, "][SIGNAL] ", message);
   }

public:
   JTBaseStrategy() : m_filters(NULL), m_initialized(false), m_lastBarTime(0) {
      // Constructeur vide
   }
   
   virtual ~JTBaseStrategy() {
      if(m_filters != NULL) {
         delete m_filters;
         m_filters = NULL;
      }
      ReleaseIndicators(m_indicators);
   }
   
   //+------------------------------------------------------------------+
   //| Initialisation de la stratégie                                  |
   //+------------------------------------------------------------------+
   virtual bool Initialize(TradingParameters &params) {
      m_params = params;
      m_initialized = false;
      
      // Initialiser les indicateurs (à implémenter par les classes dérivées)
      if(!InitializeIndicators()) {
         LogError("Échec de l'initialisation des indicateurs");
         return false;
      }
      
      // Initialiser les filtres
      m_filters = new JTTradeFilters();
      if(m_filters == NULL) {
         LogError("Échec de création des filtres");
         return false;
      }
      
      // Initialiser les filtres spécifiques (à implémenter par les classes dérivées)
      if(!InitializeFilters()) {
         LogError("Échec de l'initialisation des filtres");
         return false;
      }
      
      m_initialized = true;
      LogInfo("Stratégie initialisée: " + GetStrategyName());
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Méthodes virtuelles pures (à implémenter obligatoirement)       |
   //+------------------------------------------------------------------+
   
   // Nom de la stratégie
   virtual string GetStrategyName() = 0;
   
   // Initialiser les indicateurs spécifiques à la stratégie
   virtual bool InitializeIndicators() = 0;
   
   // Initialiser les filtres spécifiques à la stratégie
   virtual bool InitializeFilters() = 0;
   
   // Analyser le marché et générer un signal
   virtual SignalResult AnalyzeMarket() = 0;
   
   // Calculer les niveaux d'entrée (SL/TP)
   virtual bool CalculateEntryLevels(bool isBuy, double &sl, double &tp) = 0;
   
   //+------------------------------------------------------------------+
   //| Méthodes communes (peuvent être surchargées)                    |
   //+------------------------------------------------------------------+
   
   // Vérifier si une nouvelle barre est formée
   virtual bool IsNewBar() {
      datetime currentTime = iTime(m_params.symbol, m_params.timeframe, 0);
      if(currentTime != m_lastBarTime) {
         m_lastBarTime = currentTime;
         return true;
      }
      return false;
   }
   
   // Vérifier si on peut trader
   virtual bool CanTrade() {
      if(!m_initialized) return false;
      
      // Vérifier les filtres temporels
      if(!m_filters.IsTimeAllowed()) {
         return false;
      }
      
      // Vérifier si on a déjà une position
      if(m_params.onePositionPerSymbol && HasOpenPosition()) {
         return false;
      }
      
      return true;
   }
   
   // Vérifier si une position est ouverte
   virtual bool HasOpenPosition() {
      int direction = 0;
      ulong ticket = 0;
      return ::HasOpenPosition(m_params.symbol, m_params.magic, direction, ticket);
   }
   
   // Calculer le volume basé sur le risque
   virtual double CalculateLotSize(double slDistancePrice) {
      if(slDistancePrice <= 0) return 0.0;
      
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount = equity * (m_params.riskPercent / 100.0);
      
      double tickValue = SymbolInfoDouble(m_params.symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_params.symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickValue <= 0 || tickSize <= 0) return 0.0;
      
      double moneyPerLot = (slDistancePrice / tickSize) * tickValue;
      if(moneyPerLot <= 0) return 0.0;
      
      double lots = riskAmount / moneyPerLot;
      return NormalizeVolume(m_params.symbol, lots);
   }
   
   // Obtenir les prix actuels
   virtual bool GetCurrentPrices(double &bid, double &ask) {
      MqlTick tick;
      if(!SymbolInfoTick(m_params.symbol, tick)) return false;
      bid = tick.bid;
      ask = tick.ask;
      return true;
   }
   
   // Valider le ratio risque/récompense
   virtual bool ValidateRiskReward(bool isBuy, double entry, double sl, double tp) {
      if(m_params.minRR <= 0) return true;
      
      double risk = isBuy ? (entry - sl) : (sl - entry);
      double reward = isBuy ? (tp - entry) : (entry - tp);
      
      if(risk <= 0) return false;
      
      double rr = reward / risk;
      
      if(rr < m_params.minRR) {
         LogInfo("RR insuffisant: 1:" + DoubleToString(rr, 2) + 
                 " < minimum: 1:" + DoubleToString(m_params.minRR, 2));
         return false;
      }
      
      return true;
   }
   
   // Obtenir les paramètres
   TradingParameters GetParameters() { return m_params; }
   
   // Obtenir les filtres
   JTTradeFilters* GetFilters() { return m_filters; }
   
   // Obtenir les handles d'indicateurs
   IndicatorHandles GetIndicators() { return m_indicators; }
   
   // Obtenir les buffers d'indicateurs
   IndicatorBuffers GetBuffers() { return m_buffers; }
   
   // Vérifier si initialisé
   bool IsInitialized() { return m_initialized; }
};

