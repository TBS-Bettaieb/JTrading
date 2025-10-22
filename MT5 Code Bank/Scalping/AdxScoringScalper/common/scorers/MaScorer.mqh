//+------------------------------------------------------------------+
//| MaScorer.mqh - Scorer basé sur la Moving Average               |
//|                   Gestion du scoring MA pour tendances         |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "IFilterScorer.mqh"

//+------------------------------------------------------------------+
//| Constantes de scoring MA                                        |
//+------------------------------------------------------------------+
#define SCORE_MA_TREND 2
#define SCORE_MA_DISTANCE_CLOSE 0
#define SCORE_MA_DISTANCE_FAR -2
#define SCORE_PRICE_CROSS_MA 1

//+------------------------------------------------------------------+
//| Classe MaScorer - Scoring basé sur la Moving Average            |
//+------------------------------------------------------------------+
class MaScorer : public IFilterScorer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_period;
   ENUM_MA_METHOD m_method;
   int m_handle;
   double m_currentValue;
   double m_currentPrice;
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   MaScorer(string symbol, ENUM_TIMEFRAMES timeframe, int period = 50, ENUM_MA_METHOD method = MODE_SMA)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_period = period;
      m_method = method;
      m_handle = INVALID_HANDLE;
      m_currentValue = 0.0;
      m_currentPrice = 0.0;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructeur                                                     |
   //+------------------------------------------------------------------+
   ~MaScorer()
   {
      Release();
   }

   //+------------------------------------------------------------------+
   //| Initialiser le scorer MA                                       |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      m_handle = iMA(m_symbol, m_timeframe, m_period, 0, m_method, PRICE_CLOSE);
      
      if(m_handle == INVALID_HANDLE)
      {
         Print("❌ Erreur création handle MA pour ", m_symbol, " période ", m_period);
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ MaScorer initialisé: ", m_symbol, " MA(", m_period, ", ", EnumToString(m_method), ")");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour les valeurs MA et prix                          |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!m_isInitialized) return;
      
      double maValues[1];
      int copied = CopyBuffer(m_handle, 0, 1, 1, maValues);
      
      if(copied > 0)
      {
         m_currentValue = maValues[0];
         m_currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      }
      else
      {
         Print("⚠️ Erreur copie buffer MA: ", copied);
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score BUY basé sur la MA                          |
   //+------------------------------------------------------------------+
   int GetBuyScore() override
   {
      if(m_currentValue == 0) return 0;
      
      double distance_pct = (m_currentPrice - m_currentValue) / m_currentValue * 100;
      
      if(m_currentPrice > m_currentValue)
      {
         // Prix au-dessus de la MA = tendance haussière
         int score = SCORE_MA_TREND;
         
         if(MathAbs(distance_pct) < 0.5)
            score += SCORE_MA_DISTANCE_CLOSE;  // Proche de la MA
         else if(MathAbs(distance_pct) > 2.0)
            score += SCORE_MA_DISTANCE_FAR;    // Trop loin de la MA
         
         return score;
      }
      else
      {
         // Prix en-dessous de la MA
         if(MathAbs(distance_pct) < 0.3)
            return SCORE_PRICE_CROSS_MA;       // Proche du croisement
         else
            return -1;                         // Pénalité
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score SELL basé sur la MA                         |
   //+------------------------------------------------------------------+
   int GetSellScore() override
   {
      if(m_currentValue == 0) return 0;
      
      double distance_pct = (m_currentPrice - m_currentValue) / m_currentValue * 100;
      
      if(m_currentPrice < m_currentValue)
      {
         // Prix en-dessous de la MA = tendance baissière
         int score = SCORE_MA_TREND;
         
         if(MathAbs(distance_pct) < 0.5)
            score += SCORE_MA_DISTANCE_CLOSE;  // Proche de la MA
         else if(MathAbs(distance_pct) > 2.0)
            score += SCORE_MA_DISTANCE_FAR;    // Trop loin de la MA
         
         return score;
      }
      else
      {
         // Prix au-dessus de la MA
         if(MathAbs(distance_pct) < 0.3)
            return SCORE_PRICE_CROSS_MA;       // Proche du croisement
         else
            return -1;                         // Pénalité
      }
   }

   //+------------------------------------------------------------------+
   //| Déterminer si proche de la MA (bonus confluence)              |
   //+------------------------------------------------------------------+
   bool IsHighTrend() override
   {
      if(m_currentValue == 0) return false;
      
      double distance_pct = MathAbs((m_currentPrice - m_currentValue) / m_currentValue * 100);
      return (distance_pct < 0.5); // Proche si distance < 0.5%
   }

   //+------------------------------------------------------------------+
   //| Obtenir la valeur actuelle de la MA                          |
   //+------------------------------------------------------------------+
   double GetCurrentValue() override
   {
      return m_currentValue;
   }

   //+------------------------------------------------------------------+
   //| Libérer les ressources                                         |
   //+------------------------------------------------------------------+
   void Release() override
   {
      if(m_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle);
         m_handle = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Getters pour informations de debug                             |
   //+------------------------------------------------------------------+
   int GetHandle() const { return m_handle; }
   int GetPeriod() const { return m_period; }
   ENUM_MA_METHOD GetMethod() const { return m_method; }
   double GetCurrentPrice() const { return m_currentPrice; }
   bool IsInitialized() const { return m_isInitialized; }
   
   //+------------------------------------------------------------------+
   //| Méthodes utilitaires pour analyse MA                          |
   //+------------------------------------------------------------------+
   double GetDistancePercent() const 
   { 
      if(m_currentValue == 0) return 0;
      return (m_currentPrice - m_currentValue) / m_currentValue * 100;
   }
   
   bool IsPriceAboveMA() const { return m_currentPrice > m_currentValue; }
   bool IsPriceBelowMA() const { return m_currentPrice < m_currentValue; }
   bool IsPriceNearMA(double threshold = 0.5) const 
   { 
      if(m_currentValue == 0) return false;
      return MathAbs(GetDistancePercent()) < threshold; 
   }
};
