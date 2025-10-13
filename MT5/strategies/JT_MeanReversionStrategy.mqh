//+------------------------------------------------------------------+
//|                                  JT_MeanReversionStrategy.mqh    |
//|                   Stratégie de retour à la moyenne (BB Middle)   |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"

#include "../common/JT_BaseStrategy.mqh"

//+------------------------------------------------------------------+
//| Stratégie Mean Reversion - Retour à la moyenne BB               |
//| Trade le retour du prix vers la bande médiane                   |
//+------------------------------------------------------------------+
class JTMeanReversionStrategy : public JTBaseStrategy
{
private:
   // Paramètres Bollinger Bands
   int               m_bbPeriod;
   double            m_bbDeviation;
   int               m_bbShift;
   
   // Paramètres de stratégie
   double            m_minDistanceFromMiddle; // Distance minimale de la médiane en points
   double            m_entryThreshold;        // Seuil d'entrée en % de la largeur de bande
   
   // RSI pour filtrer les extrêmes
   int               m_rsiPeriod;
   double            m_rsiOversold;
   double            m_rsiOverbought;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   JTMeanReversionStrategy(string symbol, ENUM_TIMEFRAMES tf, ulong magic) 
      : JTBaseStrategy(symbol, tf, magic)
   {
      // Valeurs par défaut
      m_bbPeriod = 20;
      m_bbDeviation = 2.0;
      m_bbShift = 0;
      m_minDistanceFromMiddle = 20.0;
      m_entryThreshold = 0.8; // 80% de la largeur de bande
      m_rsiPeriod = 14;
      m_rsiOversold = 30.0;
      m_rsiOverbought = 70.0;
   }
   
   //+------------------------------------------------------------------+
   //| Configuration                                                     |
   //+------------------------------------------------------------------+
   void SetBBParameters(int period, double deviation, int shift = 0) {
      m_bbPeriod = period;
      m_bbDeviation = deviation;
      m_bbShift = shift;
   }
   
   void SetMeanReversionParameters(double minDistance, double threshold) {
      m_minDistanceFromMiddle = minDistance;
      m_entryThreshold = threshold;
   }
   
   void SetRSIParameters(int period, double oversold, double overbought) {
      m_rsiPeriod = period;
      m_rsiOversold = oversold;
      m_rsiOverbought = overbought;
   }
   
   //+------------------------------------------------------------------+
   //| Override: Nom de la stratégie                                   |
   //+------------------------------------------------------------------+
   virtual string GetStrategyName() override
   {
      return "MeanReversion";
   }
   
   //+------------------------------------------------------------------+
   //| Override: Initialisation spécifique                             |
   //+------------------------------------------------------------------+
   virtual bool InitStrategy() override
   {
      // Initialiser les indicateurs BB et RSI
      if(!InitIndicators(m_indicators, m_symbol, m_timeframe, 
                        m_bbPeriod, m_bbDeviation, m_bbShift, m_rsiPeriod)) {
         LogError("Erreur d'initialisation des indicateurs BB/RSI");
         return false;
      }
      
      // Afficher sur le graphe
      if(!ChartIndicatorAdd(0, 0, m_indicators.BB)) {
         Print("Attention: impossible d'afficher les Bollinger Bands");
      }
      if(!ChartIndicatorAdd(0, ChartWindowFind(), m_indicators.RSI)) {
         Print("Attention: impossible d'afficher le RSI");
      }
      
      LogMessage("Stratégie MeanReversion initialisée:");
      LogMessage("  BB: " + IntegerToString(m_bbPeriod) + "/" + DoubleToString(m_bbDeviation, 1));
      LogMessage("  Seuil d'entrée: " + DoubleToString(m_entryThreshold * 100, 0) + "% de la largeur");
      LogMessage("  Distance minimale: " + DoubleToString(m_minDistanceFromMiddle, 1) + " points");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Override: Deinitialisation                                       |
   //+------------------------------------------------------------------+
   virtual void DeinitStrategy() override
   {
      ReleaseIndicators(m_indicators);
   }
   
   //+------------------------------------------------------------------+
   //| Override: Détection du signal de retour à la moyenne            |
   //+------------------------------------------------------------------+
   virtual int DetectSignal() override
   {
      // Récupérer les données de la barre fermée
      MqlRates r[];
      if(CopyRates(m_symbol, m_timeframe, 0, 3, r) < 3) return 0;
      ArraySetAsSeries(r, true);
      
      double close = r[1].close;
      
      // Récupérer les bandes BB
      if(!GetIndicatorData(m_indicators, m_buffers, 3, false)) return 0;
      
      double upper = m_buffers.BBUpper[1];
      double middle = m_buffers.BBMiddle[1];
      double lower = m_buffers.BBLower[1];
      
      // Calculer la largeur de bande et la distance du prix à la médiane
      double bandWidth = upper - lower;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double distanceFromMiddle = MathAbs(close - middle) / point;
      
      // Vérifier la distance minimale
      if(distanceFromMiddle < m_minDistanceFromMiddle) {
         return 0; // Trop proche de la médiane
      }
      
      // Calculer la position relative du prix dans la bande (0 = médiane, 1 = bande extérieure)
      double pricePosition = MathAbs(close - middle) / (bandWidth / 2.0);
      
      // Vérifier si le prix est au-delà du seuil d'entrée
      if(pricePosition < m_entryThreshold) {
         return 0; // Pas assez éloigné de la médiane
      }
      
      // Déterminer la direction du retour à la moyenne
      int signal = 0;
      
      if(close > middle) {
         // Prix au-dessus de la médiane → Signal SELL (retour vers le bas)
         signal = -1;
         
         // Filtre RSI: vérifier le surachat
         if(m_useRSIFilter) {
            double rsi = m_buffers.RSI[1];
            if(rsi < m_rsiOverbought) {
               LogMessage("Signal SELL MeanReversion rejeté - RSI " + DoubleToString(rsi, 2) + " < " + DoubleToString(m_rsiOverbought, 2));
               return 0;
            }
         }
         
      } else if(close < middle) {
         // Prix en-dessous de la médiane → Signal BUY (retour vers le haut)
         signal = +1;
         
         // Filtre RSI: vérifier la survente
         if(m_useRSIFilter) {
            double rsi = m_buffers.RSI[1];
            if(rsi > m_rsiOversold) {
               LogMessage("Signal BUY MeanReversion rejeté - RSI " + DoubleToString(rsi, 2) + " > " + DoubleToString(m_rsiOversold, 2));
               return 0;
            }
         }
      }
      
      if(signal != 0) {
         LogMessage("MEAN REVERSION Signal: " + (signal > 0 ? "BUY" : "SELL") + 
                   " - Prix: " + DoubleToString(close, 5) + 
                   " - Médiane: " + DoubleToString(middle, 5) + 
                   " - Position: " + DoubleToString(pricePosition * 100, 1) + "%");
      }
      
      return signal;
   }
   
   //+------------------------------------------------------------------+
   //| Override: Validation du signal                                  |
   //+------------------------------------------------------------------+
   virtual bool ValidateEntry(int signal) override
   {
      if(signal == 0) return false;
      
      // Validation basique - peut être étendue
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Override: Calcul des niveaux SL/TP spécifiques                  |
   //+------------------------------------------------------------------+
   virtual bool CalculateLevels(bool isBuy, double &sl, double &tp) override
   {
      // Récupérer la médiane BB comme TP (objectif de retour à la moyenne)
      if(!GetIndicatorData(m_indicators, m_buffers, 2, false)) {
         return false;
      }
      
      double middle = m_buffers.BBMiddle[1];
      double upper = m_buffers.BBUpper[1];
      double lower = m_buffers.BBLower[1];
      
      // TP = Médiane BB (retour à la moyenne)
      tp = middle;
      
      // SL = Bande opposée + marge
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double margin = 10 * point; // Marge de sécurité
      
      if(isBuy) {
         sl = lower - margin;
      } else {
         sl = upper + margin;
      }
      
      // Vérifier le ratio RR
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick)) return false;
      
      double entryPrice = isBuy ? tick.ask : tick.bid;
      double reward = isBuy ? (tp - entryPrice) : (entryPrice - tp);
      double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
      double rr = (risk > 0) ? (reward / risk) : 0;
      
      LogMessage("MeanReversion Levels - Entry: " + DoubleToString(entryPrice, 5) + 
                ", SL: " + DoubleToString(sl, 5) + 
                ", TP (Middle): " + DoubleToString(tp, 5) + 
                ", RR: 1:" + DoubleToString(rr, 2));
      
      return true;
   }
};

