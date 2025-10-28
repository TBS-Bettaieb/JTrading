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
                         SwingAnalyzer* swingAnalyzer, 
                         SymbolStatus* statusManager)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
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
      // Un signal BUY breakout place un ordre au-dessus du prix (overPrice)
      // On vérifie qu'il n'y a pas déjà un ordre overPrice
      if(!m_enableBuySignals || m_statusManager.GetOverPriceTotal() > 0)
         return false;
      
      double triggerPrice = 0;
      string description = "";
      
      // Mode BREAKOUT : acheter quand le prix CASSE un swing high (suivre la tendance)
      triggerPrice = m_swingAnalyzer.FindHigh();
      description = "Breakout Buy Signal - Price breaks swing high";
      
      if(triggerPrice > 0)
      {
         signal.signalType = ORDER_TYPE_BUY;
         signal.triggerPrice = triggerPrice;
         signal.timestamp = TimeGMT();
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
      // Un signal SELL breakout place un ordre en-dessous du prix (underPrice)
      // On vérifie qu'il n'y a pas déjà un ordre underPrice
      if(!m_enableSellSignals || m_statusManager.GetUnderPriceTotal() > 0)
         return false;
      
      double triggerPrice = 0;
      string description = "";
      
      // Mode BREAKOUT : vendre quand le prix CASSE un swing low (suivre la tendance)
      triggerPrice = m_swingAnalyzer.FindLow();
      description = "Breakout Sell Signal - Price breaks swing low";
      
      if(triggerPrice > 0)
      {
         signal.signalType = ORDER_TYPE_SELL;
         signal.triggerPrice = triggerPrice;
         signal.timestamp = TimeGMT();
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
   string GetSymbol() const { return m_symbol; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
   
   //+------------------------------------------------------------------+
   //| Obtenir une description détaillée du signal                     |
   //+------------------------------------------------------------------+
   string GetSignalDescription(const SignalInfo &signal) const
   {
      string typeStr = (signal.signalType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      
      return StringFormat("[%s] Breakout %s Signal at %.5f - %s", 
                         m_symbol, typeStr, 
                         signal.triggerPrice, signal.description);
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si les signaux sont activés                           |
   //+------------------------------------------------------------------+
   bool IsBuySignalsEnabled() const { return m_enableBuySignals; }
   bool IsSellSignalsEnabled() const { return m_enableSellSignals; }
};
