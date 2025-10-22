//+------------------------------------------------------------------+
//| VolatilityFilter.mqh - Filtre de volatilité basé sur ATR       |
//|                   Vérifie si la volatilité est optimale         |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Classe VolatilityFilter                                         |
//+------------------------------------------------------------------+
class VolatilityFilter
{
private:
   int m_atrHandle;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_period;
   double m_minVolatilityRatio;
   double m_maxVolatilityRatio;
   bool m_isInitialized;
   double m_currentATR;
   double m_currentRatio;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   VolatilityFilter(string symbol, ENUM_TIMEFRAMES timeframe, int period, 
                    double minRatio, double maxRatio)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_period = period;
      m_minVolatilityRatio = minRatio;
      m_maxVolatilityRatio = maxRatio;
      m_atrHandle = INVALID_HANDLE;
      m_isInitialized = false;
      m_currentATR = 0;
      m_currentRatio = 0;
   }

   //+------------------------------------------------------------------+
   //| Destructeur                                                     |
   //+------------------------------------------------------------------+
   ~VolatilityFilter()
   {
      Release();
   }

   //+------------------------------------------------------------------+
   //| Initialisation                                                  |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      m_atrHandle = iATR(m_symbol, m_timeframe, m_period);
      
      if(m_atrHandle == INVALID_HANDLE)
      {
         Print("❌ Erreur création ATR pour ", m_symbol);
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ VolatilityFilter initialisé: ", m_symbol, " ATR(", m_period, ")");
      Print("   Ratio min: ", m_minVolatilityRatio, " | Ratio max: ", m_maxVolatilityRatio);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour l'ATR                                            |
   //+------------------------------------------------------------------+
   void Update()
   {
      if(!m_isInitialized) return;
      
      double atrValues[1];
      int copied = CopyBuffer(m_atrHandle, 0, 1, 1, atrValues);
      
      if(copied > 0)
      {
         m_currentATR = atrValues[0];
         
         // Calculer le ratio de volatilité
         double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         if(currentPrice > 0)
            m_currentRatio = m_currentATR / currentPrice;
         else
            m_currentRatio = 0;
      }
      else
      {
         Print("⚠️ Erreur copie buffer ATR: ", copied);
      }
   }

   //+------------------------------------------------------------------+
   //| Obtenir le ratio de volatilité actuel                          |
   //+------------------------------------------------------------------+
   double GetVolatilityRatio()
   {
      return m_currentRatio;
   }

   //+------------------------------------------------------------------+
   //| Vérifier si la volatilité est optimale pour trader             |
   //+------------------------------------------------------------------+
   bool IsVolatilityOptimal()
   {
      if(!m_isInitialized) return false;
      
      // La volatilité doit être entre min et max
      return (m_currentRatio >= m_minVolatilityRatio && 
              m_currentRatio <= m_maxVolatilityRatio);
   }

   //+------------------------------------------------------------------+
   //| Libérer les ressources                                         |
   //+------------------------------------------------------------------+
   void Release()
   {
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Getters pour debug et affichage                                |
   //+------------------------------------------------------------------+
   double GetATR() const { return m_currentATR; }
   bool IsInitialized() const { return m_isInitialized; }
   int GetPeriod() const { return m_period; }
   double GetMinRatio() const { return m_minVolatilityRatio; }
   double GetMaxRatio() const { return m_maxVolatilityRatio; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le statut de volatilité en texte                       |
   //+------------------------------------------------------------------+
   string GetVolatilityStatus()
   {
      if(!m_isInitialized) return "Non initialisé";
      
      if(m_currentRatio < m_minVolatilityRatio)
         return "Trop faible";
      else if(m_currentRatio > m_maxVolatilityRatio)
         return "Trop élevée";
      else
         return "Optimale";
   }
};
