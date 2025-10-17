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
      // Score BUY : zones de survente = opportunités d'achat
      if(m_currentValue < 20)
         return SCORE_RSI_EXTREME;      // Survente extrême
      else if(m_currentValue < 30)
         return SCORE_RSI_ZONE;         // Zone de survente
      else if(m_currentValue >= 35)
         return 0;                      // Pénalité si surachat
      else
         return SCORE_RSI_MODERATE;     // Zone neutre
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score SELL basé sur le RSI                        |
   //+------------------------------------------------------------------+
   int GetSellScore() override
   {
      // Score SELL : zones de surachat = opportunités de vente
      if(m_currentValue > 80)
         return SCORE_RSI_EXTREME;      // Surachat extrême
      else if(m_currentValue > 75)
         return SCORE_RSI_ZONE;         // Zone de surachat
      else if(m_currentValue > 70)
         return SCORE_RSI_MODERATE;     // Surachat modéré
      else if(m_currentValue <= 55)
         return 0;                      // Pénalité si survendu
      else
         return SCORE_RSI_MODERATE;     // Zone neutre
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
};
