//+------------------------------------------------------------------+
//| AdxDirectionalScorer.mqh - Scorer basé sur D+ et D- de l'ADX    |
//|                   Gestion du scoring directionnel ADX            |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "IFilterScorer.mqh"

//+------------------------------------------------------------------+
//| Constantes de scoring directionnel ADX                          |
//+------------------------------------------------------------------+
#define SCORE_DIRECTIONAL_EXTREME 4   // Écart > 30
#define SCORE_DIRECTIONAL_STRONG 3    // Écart > 20
#define SCORE_DIRECTIONAL_MODERATE 2  // Écart > 10
#define SCORE_DIRECTIONAL_WEAK 1      // Écart > 5
#define SCORE_CROSSOVER_BONUS 2       // Bonus croisement
#define SCORE_DIRECTIONAL_CROSSOVER 3 // Bonus croisement amélioré
#define SCORE_DIRECTIONAL_MOMENTUM 2  // Bonus momentum directionnel

//+------------------------------------------------------------------+
//| Classe AdxDirectionalScorer - Scoring basé sur D+ et D-          |
//+------------------------------------------------------------------+
class AdxDirectionalScorer : public IFilterScorer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_handle;
   int m_period;
   
   double m_currentDPlus;   // D+ actuel
   double m_currentDMinus;  // D- actuel
   double m_prevDPlus;      // D+ précédent (pour détecter croisements)
   double m_prevDMinus;     // D- précédent
   
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   AdxDirectionalScorer(string symbol, ENUM_TIMEFRAMES timeframe, int period = 14)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_period = period;
      m_handle = INVALID_HANDLE;
      
      m_currentDPlus = 0;
      m_currentDMinus = 0;
      m_prevDPlus = 0;
      m_prevDMinus = 0;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructeur                                                     |
   //+------------------------------------------------------------------+
   ~AdxDirectionalScorer()
   {
      Release();
   }

   //+------------------------------------------------------------------+
   //| Initialiser le scorer directionnel ADX                        |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      // Créer l'indicateur ADX (même handle que AdxScorer, mais on utilise D+ et D-)
      m_handle = iADX(m_symbol, m_timeframe, m_period);
      
      if(m_handle == INVALID_HANDLE)
      {
         Print("❌ Erreur création ADX Directional pour ", m_symbol);
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ AdxDirectionalScorer initialisé | Period: ", m_period);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour les valeurs D+ et D-                             |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!m_isInitialized) return;
      
      // Sauvegarder valeurs précédentes
      m_prevDPlus = m_currentDPlus;
      m_prevDMinus = m_currentDMinus;
      
      double dPlusValues[1];
      double dMinusValues[1];
      
      // Buffer 1 = PLUS_DI (D+)
      // Buffer 2 = MINUS_DI (D-)
      int copiedPlus = CopyBuffer(m_handle, 1, 1, 1, dPlusValues);
      int copiedMinus = CopyBuffer(m_handle, 2, 1, 1, dMinusValues);
      
      if(copiedPlus <= 0 || copiedMinus <= 0)
      {
         Print("⚠️ Erreur copie D+/D-: Plus=", copiedPlus, " Minus=", copiedMinus);
         return;
      }
      
      m_currentDPlus = dPlusValues[0];
      m_currentDMinus = dMinusValues[0];
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score BUY basé sur D+ > D-                          |
   //+------------------------------------------------------------------+
   int GetBuyScore() override
   {
      if(!m_isInitialized) return 0;
      
      double spread = m_currentDPlus - m_currentDMinus;
      if(spread <= 0) return 0;
      int score = 0;
      
      // Scoring dynamique basé sur l'écart
      if(spread > 25) score = 4;      // Très fort écart
      else if(spread > 15) score = 3; // Fort écart  
      else if(spread > 8) score = 2;  // Écart moyen
      else if(spread > 3) score = 1;  // Faible écart
      
      // Bonus croisement D+ vers le haut
      if(IsCrossover()) score += SCORE_DIRECTIONAL_CROSSOVER;
      
      // Bonus momentum (D+ monte ET D- descend)
      if(m_currentDPlus > m_prevDPlus && m_currentDMinus < m_prevDMinus)
         score += SCORE_DIRECTIONAL_MOMENTUM;
         
      return score;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score SELL basé sur D- > D+                         |
   //+------------------------------------------------------------------+
   int GetSellScore() override
   {
      if(!m_isInitialized) return 0;
      
      double spread = m_currentDMinus - m_currentDPlus;
      if(spread <= 0) return 0;
      int score = 0;
      
      // Scoring dynamique basé sur l'écart
      if(spread > 25) score = 4;      // Très fort écart
      else if(spread > 15) score = 3; // Fort écart  
      else if(spread > 8) score = 2;  // Écart moyen
      else if(spread > 3) score = 1;  // Faible écart
      
      // Bonus croisement D- vers le haut
      if(IsCrossunder()) score += SCORE_DIRECTIONAL_CROSSOVER;
      
      // Bonus momentum (D- monte ET D+ descend)
      if(m_currentDMinus > m_prevDMinus && m_currentDPlus < m_prevDPlus)
         score += SCORE_DIRECTIONAL_MOMENTUM;
         
      return score;
   }

   //+------------------------------------------------------------------+
   //| Déterminer si la tendance directionnelle est forte             |
   //+------------------------------------------------------------------+
   bool IsHighTrend() override
   {
      double spread = MathAbs(m_currentDPlus - m_currentDMinus);
      return spread > 20;  // Écart significatif = tendance forte
   }

   //+------------------------------------------------------------------+
   //| Obtenir la valeur actuelle (moyenne D+ et D-)                  |
   //+------------------------------------------------------------------+
   double GetCurrentValue() override
   {
      return (m_currentDPlus + m_currentDMinus) / 2.0;
   }

   //+------------------------------------------------------------------+
   //| Détecter croisement D+ vers le haut (signal BUY)               |
   //+------------------------------------------------------------------+
   bool IsCrossover()
   {
      // D+ croise D- vers le haut (signal BUY)
      return (m_prevDPlus <= m_prevDMinus && m_currentDPlus > m_currentDMinus);
   }

   //+------------------------------------------------------------------+
   //| Détecter croisement D- vers le haut (signal SELL)              |
   //+------------------------------------------------------------------+
   bool IsCrossunder()
   {
      // D- croise D+ vers le haut (signal SELL)
      return (m_prevDMinus <= m_prevDPlus && m_currentDMinus > m_currentDPlus);
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
   double GetDPlus() const { return m_currentDPlus; }
   double GetDMinus() const { return m_currentDMinus; }
   int GetHandle() const { return m_handle; }
   int GetPeriod() const { return m_period; }
   bool IsInitialized() const { return m_isInitialized; }
   
   //+------------------------------------------------------------------+
   //| Obtenir l'écart entre D+ et D-                                 |
   //+------------------------------------------------------------------+
   double GetSpread() const 
   { 
      return MathAbs(m_currentDPlus - m_currentDMinus); 
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la direction dominante (1 = D+, -1 = D-, 0 = neutre)  |
   //+------------------------------------------------------------------+
   int GetDirection() const
   {
      if(m_currentDPlus > m_currentDMinus) return 1;   // D+ dominant
      if(m_currentDMinus > m_currentDPlus) return -1;  // D- dominant
      return 0;  // Neutre
   }
};
