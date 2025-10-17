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
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   AdxScorer(string symbol, ENUM_TIMEFRAMES timeframe, int period = 14)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_period = period;
      m_handle = INVALID_HANDLE;
      m_currentValue = 0.0;
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
   //| Mettre à jour la valeur ADX                                    |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!m_isInitialized) return;
      
      double adxValues[1];
      int copied = CopyBuffer(m_handle, 0, 1, 1, adxValues);
      
      if(copied > 0)
      {
         m_currentValue = adxValues[0];
      }
      else
      {
         Print("⚠️ Erreur copie buffer ADX: ", copied);
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score BUY basé sur l'ADX                           |
   //+------------------------------------------------------------------+
   int GetBuyScore() override
   {
      if(m_currentValue > 35)
         return SCORE_ADX_VERY_STRONG;
      else if(m_currentValue > 25)
         return SCORE_ADX_STRONG;
      else if(m_currentValue > 20)
         return SCORE_ADX_MODERATE;
      else
         return SCORE_ADX_WEAK;
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
      // Tendance forte si ADX > 35
      return (m_currentValue > 35);
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
   //| Getters pour informations de debug                             |
   //+------------------------------------------------------------------+
   int GetHandle() const { return m_handle; }
   int GetPeriod() const { return m_period; }
   bool IsInitialized() const { return m_isInitialized; }
};
