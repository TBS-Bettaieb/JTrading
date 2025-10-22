//+------------------------------------------------------------------+
//|                                      JT_BreakoutStrategy.mqh     |
//|                   Stratégie de Breakout basée sur FreeCandle     |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"

#include "JT_FreeCandleStrategy.mqh"

//+------------------------------------------------------------------+
//| Stratégie Breakout - Extension de FreeCandle                     |
//| Trade les cassures de bandes BB avec confirmation              |
//+------------------------------------------------------------------+
class JTBreakoutStrategy : public JTFreeCandleStrategy
{
private:
   int m_confirmationBars;  // Nombre de barres pour confirmer le breakout
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   JTBreakoutStrategy(string symbol, ENUM_TIMEFRAMES tf, ulong magic) 
      : JTFreeCandleStrategy(symbol, tf, magic)
   {
      m_confirmationBars = 2;
      // Forcer le mode BREAKOUT
      m_entryMode = ENTRY_BREAKOUT;
   }
   
   //+------------------------------------------------------------------+
   //| Configuration                                                     |
   //+------------------------------------------------------------------+
   void SetConfirmationBars(int bars) { m_confirmationBars = bars; }
   
   //+------------------------------------------------------------------+
   //| Override: Nom de la stratégie                                   |
   //+------------------------------------------------------------------+
   virtual string GetStrategyName() override
   {
      return "Breakout";
   }
   
   //+------------------------------------------------------------------+
   //| Override: Détection du signal avec confirmation de breakout     |
   //+------------------------------------------------------------------+
   virtual int DetectSignal() override
   {
      // Récupérer les données des dernières barres
      MqlRates r[];
      int barsNeeded = m_confirmationBars + 2;
      if(CopyRates(m_symbol, m_timeframe, 0, barsNeeded, r) < barsNeeded) return 0;
      ArraySetAsSeries(r, true);
      
      // Récupérer les bandes de Bollinger
      if(!GetIndicatorData(m_indicators, m_buffers, barsNeeded, false)) return 0;
      
      // Vérifier le breakout sur la barre fermée (index 1)
      double close = r[1].close;
      double upper = m_buffers.BBUpper[1];
      double lower = m_buffers.BBLower[1];
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double padding = m_outsidePadding * point;
      
      // Détecter le breakout
      bool breakoutUp = (close > upper + padding);
      bool breakoutDown = (close < lower - padding);
      
      if(!breakoutUp && !breakoutDown) {
         return 0; // Pas de breakout
      }
      
      // Vérifier la confirmation sur les barres précédentes
      // Les barres précédentes doivent être à l'intérieur ou proche des bandes
      bool confirmed = true;
      for(int i = 2; i <= m_confirmationBars + 1; i++) {
         double prevClose = r[i].close;
         double prevUpper = m_buffers.BBUpper[i];
         double prevLower = m_buffers.BBLower[i];
         
         if(breakoutUp) {
            // Pour un breakout haussier, les barres précédentes doivent être en dessous
            if(prevClose > prevUpper) {
               confirmed = false;
               break;
            }
         } else { // breakoutDown
            // Pour un breakout baissier, les barres précédentes doivent être au dessus
            if(prevClose < prevLower) {
               confirmed = false;
               break;
            }
         }
      }
      
      if(!confirmed) {
         LogMessage("Breakout détecté mais non confirmé (barres précédentes invalides)");
         return 0;
      }
      
      // Signal confirmé
      int signal = breakoutUp ? +1 : -1;
      
      LogMessage("BREAKOUT CONFIRMÉ: " + (signal > 0 ? "HAUSSIER" : "BAISSIER") + 
                " - Close: " + DoubleToString(close, 5) + 
                " vs BB: " + DoubleToString(signal > 0 ? upper : lower, 5));
      
      // Marquer le breakout si activé
      if(m_markFreeCandles) {
         MarkFreeCandleOnChart(r[1].time, r[1].high, r[1].low, signal);
      }
      
      return signal;
   }
   
   //+------------------------------------------------------------------+
   //| Helper privé pour marquer le breakout                           |
   //+------------------------------------------------------------------+
   void MarkFreeCandleOnChart(datetime time, double high, double low, int signal)
   {
      double arrowPrice = (signal > 0) ? low : high;
      
      // Utiliser un préfixe différent pour les breakouts
      MarkFreeCandle(time, high, low, arrowPrice, signal, m_timeframe,
                    true, true, m_markDrawBox, true, "Breakout");
      
      LogMessage("Breakout marqué sur le graphique à " + TimeToString(time));
   }
};

