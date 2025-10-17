//+------------------------------------------------------------------+
//| RsiScorer.mqh - Scorer basé sur l'indicateur RSI               |
//|                   Gestion du scoring RSI pour survente/surachat |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "IFilterScorer.mqh"

//+------------------------------------------------------------------+
//| Constantes de scoring RSI                                       |
//+------------------------------------------------------------------+
#define SCORE_RSI_EXTREME 4
#define SCORE_RSI_ZONE 1
#define SCORE_RSI_MODERATE 0

//+------------------------------------------------------------------+
//| Classe RsiScorer - Scoring basé sur le RSI                      |
//+------------------------------------------------------------------+
class RsiScorer : public IFilterScorer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_period;
   int m_handle;
   double m_currentValue;
   double m_prevValue;
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   RsiScorer(string symbol, ENUM_TIMEFRAMES timeframe, int period = 14)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_period = period;
      m_handle = INVALID_HANDLE;
      m_currentValue = 50.0; // Valeur neutre par défaut
      m_prevValue = 50.0;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructeur                                                     |
   //+------------------------------------------------------------------+
   ~RsiScorer()
   {
      Release();
   }

   //+------------------------------------------------------------------+
   //| Initialiser le scorer RSI                                      |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      m_handle = iRSI(m_symbol, m_timeframe, m_period, PRICE_CLOSE);
      
      if(m_handle == INVALID_HANDLE)
      {
         Print("❌ Erreur création handle RSI pour ", m_symbol, " période ", m_period);
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ RsiScorer initialisé: ", m_symbol, " RSI(", m_period, ")");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour la valeur RSI                                   |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!m_isInitialized) return;
      
      m_prevValue = m_currentValue;
      
      double rsiValues[1];
      int copied = CopyBuffer(m_handle, 0, 1, 1, rsiValues);
      
      if(copied > 0)
      {
         m_currentValue = rsiValues[0];
      }
      else
      {
         Print("⚠️ Erreur copie buffer RSI: ", copied);
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score BUY basé sur le RSI                         |
   //+------------------------------------------------------------------+
   int GetBuyScore() override
   {
      int score = 0;
      
      // Scoring basé sur les zones RSI
      if(m_currentValue < 25) score = 4;        // Survente extrême
      else if(m_currentValue < 35) score = 2;   // Zone survente
      else if(m_currentValue >= 65) score = -2; // Pénalité surachat
      else if(m_currentValue < 50) score = 1;   // Légèrement survendu
      
      // NOUVEAU: Bonus momentum haussier
      // RSI qui monte depuis une zone basse = signal fort
      if(m_currentValue > m_prevValue && m_prevValue < 40)
         score += 2;
         
      return score;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score SELL basé sur le RSI                        |
   //+------------------------------------------------------------------+
   int GetSellScore() override
   {
      int score = 0;
      
      // Scoring basé sur les zones RSI
      if(m_currentValue > 75) score = 4;        // Surachat extrême
      else if(m_currentValue > 65) score = 2;   // Zone surachat
      else if(m_currentValue <= 35) score = -2; // Pénalité survente
      else if(m_currentValue > 50) score = 1;   // Légèrement suracheté
      
      // NOUVEAU: Bonus momentum baissier
      // RSI qui descend depuis une zone haute = signal fort
      if(m_currentValue < m_prevValue && m_prevValue > 60)
         score += 2;
         
      return score;
   }

   //+------------------------------------------------------------------+
   //| Déterminer si en zone extrême (bonus confluence)             |
   //+------------------------------------------------------------------+
   bool IsHighTrend() override
   {
      // Zone extrême si RSI < 20 OU RSI > 80
      return (m_currentValue < 20 || m_currentValue > 80);
   }

   //+------------------------------------------------------------------+
   //| Obtenir la valeur actuelle du RSI                            |
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
   
   //+------------------------------------------------------------------+
   //| Méthodes utilitaires pour zones RSI                           |
   //+------------------------------------------------------------------+
   bool IsOversold() const { return m_currentValue < 30; }
   bool IsOverbought() const { return m_currentValue > 70; }
   bool IsExtremeOversold() const { return m_currentValue < 20; }
   bool IsExtremeOverbought() const { return m_currentValue > 80; }
   
   //+------------------------------------------------------------------+
   //| Getters pour le momentum RSI                                   |
   //+------------------------------------------------------------------+
   double GetPrevValue() const { return m_prevValue; }
   bool HasMomentumUp() const { return m_currentValue > m_prevValue; }
   bool HasMomentumDown() const { return m_currentValue < m_prevValue; }
};
