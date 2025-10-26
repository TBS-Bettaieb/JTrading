//+------------------------------------------------------------------+
//|                                    SignalDetectionManager.mqh   |
//|                    Gestionnaire de détection des signaux         |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../../Shared/TradingEnums.mqh"
#include "SwingAnalyzer.mqh"
#include "../status/SymbolStatus.mqh"

//+------------------------------------------------------------------+
//| Structure pour les signaux détectés                             |
//+------------------------------------------------------------------+
struct SignalInfo
{
   ENUM_ORDER_TYPE signalType;    // ORDER_TYPE_BUY ou ORDER_TYPE_SELL
   double          triggerPrice;  // Prix de déclenchement
   ENUM_STRATEGY_MODE strategyMode; // Mode utilisé pour le signal
   datetime        timestamp;     // Timestamp du signal
   string          description;   // Description du signal
};

//+------------------------------------------------------------------+
//| Classe SignalDetectionManager                                   |
//+------------------------------------------------------------------+
class SignalDetectionManager
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   ENUM_STRATEGY_MODE m_strategyMode;
   
   SwingAnalyzer*    m_swingAnalyzer;
   SymbolStatus*     m_statusManager;
   
   // Configuration des signaux
   bool              m_enableBuySignals;
   bool              m_enableSellSignals;
   
public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   SignalDetectionManager(string symbol, ENUM_TIMEFRAMES timeframe, 
                         ENUM_STRATEGY_MODE strategyMode,
                         SwingAnalyzer* swingAnalyzer, 
                         SymbolStatus* statusManager)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_strategyMode = strategyMode;
      m_swingAnalyzer = swingAnalyzer;
      m_statusManager = statusManager;
      
      // Par défaut, tous les signaux sont activés
      m_enableBuySignals = true;
      m_enableSellSignals = true;
   }
   
   //+------------------------------------------------------------------+
   //| Destructeur                                                     |
   //+------------------------------------------------------------------+
   ~SignalDetectionManager()
   {
      // Les objets SwingAnalyzer et SymbolStatus sont gérés par le parent
      // Pas de suppression ici
   }
   
   //+------------------------------------------------------------------+
   //| Vérification des signaux d'achat                              |
   //+------------------------------------------------------------------+
   bool CheckForBuySignal(SignalInfo &signal)
   {
      if(!m_enableBuySignals || m_statusManager.GetBuyTotal() > 0)
         return false;
      
      double triggerPrice = 0;
      string description = "";
      
      if(m_strategyMode == STRATEGY_BREAKOUT)
      {
         // Mode BREAKOUT : acheter quand le prix CASSE un swing high (suivre la tendance)
         triggerPrice = m_swingAnalyzer.FindHigh();
         description = "Breakout Buy Signal - Price breaks swing high";
      }
      else if(m_strategyMode == STRATEGY_REVERSION)
      {
         // Mode REVERSION : acheter quand le prix TOUCHE un swing low et rebondit (contre-tendance)
         triggerPrice = m_swingAnalyzer.FindLow();
         description = "Reversion Buy Signal - Price touches swing low";
      }
      
      if(triggerPrice > 0)
      {
         signal.signalType = ORDER_TYPE_BUY;
         signal.triggerPrice = triggerPrice;
         signal.strategyMode = m_strategyMode;
         signal.timestamp = TimeCurrent();
         signal.description = description;
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Vérification des signaux de vente                              |
   //+------------------------------------------------------------------+
   bool CheckForSellSignal(SignalInfo &signal)
   {
      if(!m_enableSellSignals || m_statusManager.GetSellTotal() > 0)
         return false;
      
      double triggerPrice = 0;
      string description = "";
      
      if(m_strategyMode == STRATEGY_BREAKOUT)
      {
         // Mode BREAKOUT : vendre quand le prix CASSE un swing low (suivre la tendance)
         triggerPrice = m_swingAnalyzer.FindLow();
         description = "Breakout Sell Signal - Price breaks swing low";
      }
      else if(m_strategyMode == STRATEGY_REVERSION)
      {
         // Mode REVERSION : vendre quand le prix TOUCHE un swing high et redescend (contre-tendance)
         triggerPrice = m_swingAnalyzer.FindHigh();
         description = "Reversion Sell Signal - Price touches swing high";
      }
      
      if(triggerPrice > 0)
      {
         signal.signalType = ORDER_TYPE_SELL;
         signal.triggerPrice = triggerPrice;
         signal.strategyMode = m_strategyMode;
         signal.timestamp = TimeCurrent();
         signal.description = description;
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Méthodes de configuration                                       |
   //+------------------------------------------------------------------+
   void EnableBuySignals(bool enable) { m_enableBuySignals = enable; }
   void EnableSellSignals(bool enable) { m_enableSellSignals = enable; }
   
   //+------------------------------------------------------------------+
   //| Getters                                                         |
   //+------------------------------------------------------------------+
   ENUM_STRATEGY_MODE GetStrategyMode() const { return m_strategyMode; }
   string GetSymbol() const { return m_symbol; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
   
   //+------------------------------------------------------------------+
   //| Obtenir une description détaillée du signal                     |
   //+------------------------------------------------------------------+
   string GetSignalDescription(const SignalInfo &signal) const
   {
      string modeStr = (signal.strategyMode == STRATEGY_BREAKOUT) ? "Breakout" : "Reversion";
      string typeStr = (signal.signalType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      
      return StringFormat("[%s] %s %s Signal at %.5f - %s", 
                         m_symbol, modeStr, typeStr, 
                         signal.triggerPrice, signal.description);
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si les signaux sont activés                           |
   //+------------------------------------------------------------------+
   bool IsBuySignalsEnabled() const { return m_enableBuySignals; }
   bool IsSellSignalsEnabled() const { return m_enableSellSignals; }
};
