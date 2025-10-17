//+------------------------------------------------------------------+
//| AdxScorer.mqh - Scorer basé sur l'indicateur ADX               |
//|                   Gestion du scoring ADX pour tendances        |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "IFilterScorer.mqh"

//+------------------------------------------------------------------+
//| Constantes de scoring ADX                                       |
//+------------------------------------------------------------------+
#define SCORE_ADX_WEAK -2
#define SCORE_ADX_MODERATE 0
#define SCORE_ADX_STRONG 1
#define SCORE_ADX_VERY_STRONG 3

//+------------------------------------------------------------------+
//| Classe AdxScorer - Scoring basé sur l'ADX                       |
//+------------------------------------------------------------------+
class AdxScorer : public IFilterScorer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_period;
   int m_handle;
   double m_currentValue;
   double m_prevValue;           // Previous ADX (bar n-1)
   double m_prevValue2;          // Previous-2 ADX (bar n-2)
   bool m_isInitialized;
   
   // Seuils paramétrables
   int m_thresholdWeak;
   int m_thresholdModerate;
   int m_thresholdStrong;
   int m_thresholdVeryStrong;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   AdxScorer(
      string symbol, 
      ENUM_TIMEFRAMES timeframe, 
      int period = 14,
      int thresholdWeak = 18,
      int thresholdModerate = 20,
      int thresholdStrong = 25,
      int thresholdVeryStrong = 35
   )
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_period = period;
      m_thresholdWeak = thresholdWeak;
      m_thresholdModerate = thresholdModerate;
      m_thresholdStrong = thresholdStrong;
      m_thresholdVeryStrong = thresholdVeryStrong;
      m_handle = INVALID_HANDLE;
      m_currentValue = 0.0;
      m_prevValue = 0.0;              // Initialize previous values
      m_prevValue2 = 0.0;             // Initialize previous-2 values
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructeur                                                     |
   //+------------------------------------------------------------------+
   ~AdxScorer()
   {
      Release();
   }

   //+------------------------------------------------------------------+
   //| Initialiser le scorer ADX                                      |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      m_handle = iADX(m_symbol, m_timeframe, m_period);
      
      if(m_handle == INVALID_HANDLE)
      {
         Print("❌ Erreur création handle ADX pour ", m_symbol, " période ", m_period);
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ AdxScorer initialisé: ", m_symbol, " ADX(", m_period, ")");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour la valeur ADX                                      |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!m_isInitialized) return;
      
      // Shift values (cascade)
      m_prevValue2 = m_prevValue;        // Save n-2 value
      m_prevValue = m_currentValue;      // Save n-1 value
      
      double adxValues[1];
      int copied = CopyBuffer(m_handle, 0, 1, 1, adxValues);
      
      if(copied > 0)
      {
         m_currentValue = adxValues[0];  // Update current value
      }
      else
      {
         Print("⚠️ Erreur copie buffer ADX: ", copied);
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score BUY basé sur l'ADX avec momentum                |
   //+------------------------------------------------------------------+
   int GetBuyScore() override
   {
      int score = 0;
      
      // ═══ STEP 1: Base scoring (ADX absolute value) ═══
      if(m_currentValue > m_thresholdVeryStrong)
         score = SCORE_ADX_VERY_STRONG;      // +3
      else if(m_currentValue > m_thresholdStrong)
         score = SCORE_ADX_STRONG;           // +1
      else if(m_currentValue > m_thresholdModerate)
         score = SCORE_ADX_MODERATE;         // 0
      else
         score = SCORE_ADX_WEAK;             // -2
      
      // ═══ STEP 2: Apply momentum adjustment ═══
      int momentum = GetADXMomentum();
      if(momentum < 0)
      {
         // ADX DECELERATING: current < prev < prev2
         // Example: ADX 35 → 30 → 26
         // Penalty: -2 points (weakening trend)
         score -= 2;
         
         // Optional: Log for monitoring
         // Print("⚠️ ADX Momentum Penalty: ", GetMomentumDescription());
      }
      // else momentum == 0: Plateau or mixed → no adjustment
      
      return score;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score SELL basé sur l'ADX                          |
   //+------------------------------------------------------------------+
   int GetSellScore() override
   {
      // Pour l'ADX, le scoring est identique pour BUY et SELL
      // car l'ADX mesure la force de tendance, pas la direction
      return GetBuyScore();
   }

   //+------------------------------------------------------------------+
   //| Déterminer si la tendance est forte (bonus confluence)        |
   //+------------------------------------------------------------------+
   bool IsHighTrend() override
   {
      return (m_currentValue > m_thresholdVeryStrong);
   }

   //+------------------------------------------------------------------+
   //| Obtenir la valeur actuelle de l'ADX                           |
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
   //| Analyze ADX momentum trend (3-period analysis)                   |
   //| Returns: +1 (accelerating), 0 (plateau), -1 (decelerating)      |
   //+------------------------------------------------------------------+
   int GetADXMomentum() const
   {
      // Need at least 2 previous values for comparison
      if(m_prevValue == 0 || m_prevValue2 == 0)
         return 0;  // Not enough data yet
      
      // Use threshold of 0.5 to avoid noise from small fluctuations
      const double threshold = 0.5;
      
      // Case 1: Accelerating trend (current > prev > prev2)
      // ADX is rising consistently = STRONG MOMENTUM
      if(m_currentValue > m_prevValue + threshold && 
         m_prevValue > m_prevValue2 + threshold)
      {
         return +1;  // Bonus: Strong accelerating momentum
      }
      
      // Case 2: Decelerating trend (current < prev < prev2)
      // ADX is falling consistently = WEAK MOMENTUM
      else if(m_currentValue < m_prevValue - threshold && 
              m_prevValue < m_prevValue2 - threshold)
      {
         return -1;  // Penalty: Trend is weakening
      }
      
      // Case 3: Mixed signals or plateau
      // Examples:
      // - current < prev but prev > prev2 (slowing down after rise)
      // - current > prev but prev < prev2 (recovering after dip)
      // - Small fluctuations within threshold
      else
      {
         return 0;   // Neutral: No clear momentum direction
      }
   }

   //+------------------------------------------------------------------+
   //| Get detailed momentum description for logging                    |
   //+------------------------------------------------------------------+
   string GetMomentumDescription() const
   {
      int momentum = GetADXMomentum();
      
      string desc = StringFormat("ADX[%.1f → %.1f → %.1f]", 
                                 m_prevValue2, m_prevValue, m_currentValue);
      
      if(momentum > 0)
         desc += " 🚀 ACCELERATING";
      else if(momentum < 0)
         desc += " 📉 DECELERATING";
      else
         desc += " ➡️ PLATEAU";
      
      return desc;
   }

   //+------------------------------------------------------------------+
   //| Getters pour informations de debug                             |
   //+------------------------------------------------------------------+
   int GetHandle() const { return m_handle; }
   int GetPeriod() const { return m_period; }
   bool IsInitialized() const { return m_isInitialized; }
   
   // New getters for momentum analysis
   double GetPrevValue() const { return m_prevValue; }
   double GetPrevValue2() const { return m_prevValue2; }
   int GetMomentum() const { return GetADXMomentum(); }
};
