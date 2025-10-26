//+------------------------------------------------------------------+
//| PriceActionConfirmer.mqh - Confirmateur de Price Action         |
//|                   Détection de patterns de chandeliers          |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Constantes de scoring Price Action                              |
//+------------------------------------------------------------------+
#define SCORE_PATTERN_ENGULFING 2    // Pattern engulfing détecté

//+------------------------------------------------------------------+
//| Classe PriceActionConfirmer                                      |
//+------------------------------------------------------------------+
class PriceActionConfirmer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   PriceActionConfirmer(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Initialisation                                                  |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      m_isInitialized = true;
      Print("✅ PriceActionConfirmer initialisé: ", m_symbol);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Détection Bullish Engulfing (pattern haussier)                 |
   //+------------------------------------------------------------------+
   bool IsBullishEngulfing()
   {
      if(!m_isInitialized) return false;
      
      // Barre précédente (1) et barre actuelle (0)
      double open1 = iOpen(m_symbol, m_timeframe, 1);
      double close1 = iClose(m_symbol, m_timeframe, 1);
      double open0 = iOpen(m_symbol, m_timeframe, 0);
      double close0 = iClose(m_symbol, m_timeframe, 0);
      
      // Conditions pour Bullish Engulfing:
      // 1. Barre précédente baissière (close1 < open1)
      // 2. Barre actuelle haussière (close0 > open0)
      // 3. Barre actuelle engloutit la précédente
      return (close1 < open1 &&           // Barre 1 baissière
              close0 > open0 &&           // Barre 0 haussière
              close0 > open1 &&           // Close actuel > open précédent
              open0 < close1);            // Open actuel < close précédent
   }

   //+------------------------------------------------------------------+
   //| Détection Bearish Engulfing (pattern baissier)                 |
   //+------------------------------------------------------------------+
   bool IsBearishEngulfing()
   {
      if(!m_isInitialized) return false;
      
      // Barre précédente (1) et barre actuelle (0)
      double open1 = iOpen(m_symbol, m_timeframe, 1);
      double close1 = iClose(m_symbol, m_timeframe, 1);
      double open0 = iOpen(m_symbol, m_timeframe, 0);
      double close0 = iClose(m_symbol, m_timeframe, 0);
      
      // Conditions pour Bearish Engulfing:
      // 1. Barre précédente haussière (close1 > open1)
      // 2. Barre actuelle baissière (close0 < open0)
      // 3. Barre actuelle engloutit la précédente
      return (close1 > open1 &&           // Barre 1 haussière
              close0 < open0 &&           // Barre 0 baissière
              close0 < open1 &&           // Close actuel < open précédent
              open0 > close1);            // Open actuel > close précédent
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score de confirmation pour BUY                       |
   //+------------------------------------------------------------------+
   int GetBuyConfirmation()
   {
      if(!m_isInitialized) return 0;
      
      // Si Bullish Engulfing détecté = +2 points
      if(IsBullishEngulfing())
         return SCORE_PATTERN_ENGULFING;
         
      return 0;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score de confirmation pour SELL                      |
   //+------------------------------------------------------------------+
   int GetSellConfirmation()
   {
      if(!m_isInitialized) return 0;
      
      // Si Bearish Engulfing détecté = +2 points
      if(IsBearishEngulfing())
         return SCORE_PATTERN_ENGULFING;
         
      return 0;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le score de confirmation générique                      |
   //+------------------------------------------------------------------+
   int GetConfirmationScore(int direction)
   {
      if(!m_isInitialized) return 0;
      
      // direction: 1 pour BUY, -1 pour SELL
      if(direction == 1)
         return GetBuyConfirmation();
      else if(direction == -1)
         return GetSellConfirmation();
         
      return 0;
   }

   //+------------------------------------------------------------------+
   //| Libérer les ressources                                         |
   //+------------------------------------------------------------------+
   void Release()
   {
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Getters pour debug                                             |
   //+------------------------------------------------------------------+
   bool IsInitialized() const { return m_isInitialized; }
   string GetSymbol() const { return m_symbol; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
};
