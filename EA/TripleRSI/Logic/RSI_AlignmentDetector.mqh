//+------------------------------------------------------------------+
//|                                      RSI_AlignmentDetector.mqh   |
//|                                    Détecteur Alignement RSI      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"
#include "../../Shared/TrendFilters/TrendAnalysis.mqh"
#include "../../Shared/TimeframeUtils.mqh"

//+------------------------------------------------------------------+
//| Enumération des signaux RSI                                      |
//+------------------------------------------------------------------+
enum ENUM_RSI_SIGNAL
{
   RSI_SIGNAL_NONE = 0,    // Aucun signal
   RSI_SIGNAL_BUY = 1,     // Signal d'achat (3 RSI > oversold)
   RSI_SIGNAL_SELL = -1    // Signal de vente (3 RSI < overbought)
};

//+------------------------------------------------------------------+
//| Triple RSI Alignment Detector Class                              |
//+------------------------------------------------------------------+
class CRSIAlignmentDetector
{
private:
   int m_oversoldLevel;
   int m_overboughtLevel;
   bool m_useStrictAlignment;  // true = tous les RSI doivent être alignés
   
   // Historique des signaux pour éviter les signaux répétés
   ENUM_RSI_SIGNAL m_lastSignal;
   datetime m_lastSignalTime;
   
   //--- Détecter le signal de base RSI
   ENUM_RSI_SIGNAL DetectBaseSignal(double rsi1, double rsi2, double rsi3)
   {
      if(IsBuyAlignment(rsi1, rsi2, rsi3))
         return RSI_SIGNAL_BUY;
      if(IsSellAlignment(rsi1, rsi2, rsi3))
         return RSI_SIGNAL_SELL;
      return RSI_SIGNAL_NONE;
   }
   
   //--- Valider signal avec EMA sur timeframe supérieur
   bool ValidateSignalWithEMA(ENUM_RSI_SIGNAL signal, string symbol, ENUM_TIMEFRAMES currentTF, int emaPeriod)
   {
      if(signal == RSI_SIGNAL_NONE)
         return true; // Pas de signal à valider
      
      string targetSymbol = (symbol == NULL) ? _Symbol : symbol;
      ENUM_TIMEFRAMES higherTF = TimeframeUtils::GetNextHigherTimeframe(currentTF);
      ENUM_TIMEFRAMES higherTFSecond = TimeframeUtils::GetNextHigherTimeframe(higherTF);
      bool isBullish = (signal == RSI_SIGNAL_BUY);
      bool emaConfirm = TrendAnalysis::CheckHigherTimeframeTrend(targetSymbol, higherTF, isBullish, emaPeriod);
      bool emaConfirmSecond = TrendAnalysis::CheckHigherTimeframeTrend(targetSymbol, higherTFSecond, isBullish, emaPeriod);
      if(!emaConfirm && !emaConfirmSecond)
      {
         Logger::Debug("Signal RSI " + SignalToString(signal) + 
                      " rejeté par validation EMA-" + IntegerToString(emaPeriod) + 
                      " sur " + TimeframeUtils::GetTimeframeName(higherTF));
      }
      else
      {
         Logger::Debug("Signal RSI " + SignalToString(signal) + 
                      " confirmé par EMA-" + IntegerToString(emaPeriod) + 
                      " sur " + TimeframeUtils::GetTimeframeName(higherTF));
      }
      
      return emaConfirm || emaConfirmSecond;
   }
   
   //--- Vérifier si le signal est une répétition
   bool IsRepeatedSignal(ENUM_RSI_SIGNAL signal)
   {
      if(signal == m_lastSignal)
      {
         Logger::Debug("Signal répété ignoré: " + SignalToString(signal));
         return true;
      }
      return false;
   }
   
   //--- Mettre à jour l'historique du signal
   void UpdateSignalHistory(ENUM_RSI_SIGNAL signal, double rsi1, double rsi2, double rsi3)
   {
      if(signal == RSI_SIGNAL_NONE)
         return;
      
      m_lastSignal = signal;
      m_lastSignalTime = TimeCurrent();
      
      Logger::Signal(signal == RSI_SIGNAL_BUY, 
                    "RSI Alignment Signal: " + SignalToString(signal) + 
                    " | RSI: " + DoubleToString(rsi1, 1) + "/" + 
                    DoubleToString(rsi2, 1) + "/" + DoubleToString(rsi3, 1));
   }

public:
   //--- Constructor
   CRSIAlignmentDetector(int oversold, int overbought, bool strictAlignment = true)
   {
      m_oversoldLevel = oversold;
      m_overboughtLevel = overbought;
      m_useStrictAlignment = strictAlignment;
      m_lastSignal = RSI_SIGNAL_NONE;
      m_lastSignalTime = 0;
      
      Logger::Debug("RSI Alignment Detector initialized");
      Logger::Debug("Oversold: " + IntegerToString(oversold) + 
                    " | Overbought: " + IntegerToString(overbought));
   }
   
   //--- Destructor
   ~CRSIAlignmentDetector()
   {
      Logger::Debug("RSI Alignment Detector destroyed");
   }
   
   //--- Détecter alignement pour signal achat
   // Tous les RSI doivent être au-dessus du niveau oversold
   bool IsBuyAlignment(double rsi1, double rsi2, double rsi3)
   {
      if(m_useStrictAlignment)
      {
         // Alignement strict : tous les RSI > oversold
         return (rsi1 < m_oversoldLevel && 
                 rsi2 < m_oversoldLevel && 
                 rsi3 < m_oversoldLevel);
      }
      else
      {
         // Alignement flexible : au moins 2 sur 3 RSI > oversold
         int count = 0;
         if(rsi1 < m_oversoldLevel) count++;
         if(rsi2 < m_oversoldLevel) count++;
         
         return (count >= 2);
      }
   }
   
   //--- Détecter alignement pour signal vente
   // Tous les RSI doivent être en-dessous du niveau overbought
   bool IsSellAlignment(double rsi1, double rsi2, double rsi3)
   {
      if(m_useStrictAlignment)
      {
         // Alignement strict : tous les RSI < overbought
         return (rsi1 > m_overboughtLevel && 
                 rsi2 > m_overboughtLevel && 
                 rsi3 > m_overboughtLevel);
      }
      else
      {
         // Alignement flexible : au moins 2 sur 3 RSI < overbought
         int count = 0;
         if(rsi1 > m_overboughtLevel) count++;
         if(rsi2 > m_overboughtLevel) count++;
         
         return (count >= 2);
      }
   }
   
   //--- Obtenir signal global avec gestion des répétitions
   ENUM_RSI_SIGNAL GetSignal(double rsi1, double rsi2, double rsi3, 
                            bool allowRepeat = false,
                            bool validateWithEMA = false,
                            string symbol = NULL,
                            ENUM_TIMEFRAMES currentTF = PERIOD_CURRENT,
                            int emaPeriod = 50)
   {
      // 1. Détection du signal de base
      ENUM_RSI_SIGNAL signal = DetectBaseSignal(rsi1, rsi2, rsi3);
      
      // 2. Validation avec EMA si demandée
      if(validateWithEMA && !ValidateSignalWithEMA(signal, symbol, currentTF, emaPeriod))
         return RSI_SIGNAL_NONE;
      
      // 3. Vérification des répétitions
      if(!allowRepeat && IsRepeatedSignal(signal))
         return RSI_SIGNAL_NONE;
      
      // 4. Mise à jour de l'historique
      UpdateSignalHistory(signal, rsi1, rsi2, rsi3);
      
      return signal;
   }
   
   //--- Obtenir signal sans vérification de répétition
   ENUM_RSI_SIGNAL GetRawSignal(double rsi1, double rsi2, double rsi3)
   {
      if(IsBuyAlignment(rsi1, rsi2, rsi3))
         return RSI_SIGNAL_BUY;
      if(IsSellAlignment(rsi1, rsi2, rsi3))
         return RSI_SIGNAL_SELL;
      return RSI_SIGNAL_NONE;
   }
   
   //--- Analyser la force du signal
   double GetSignalStrength(double rsi1, double rsi2, double rsi3)
   {
      ENUM_RSI_SIGNAL signal = GetRawSignal(rsi1, rsi2, rsi3);
      
      if(signal == RSI_SIGNAL_NONE)
         return 0.0;
      
      double strength = 0.0;
      
      if(signal == RSI_SIGNAL_BUY)
      {
         // Force basée sur la distance moyenne au niveau oversold
         double avgDistance = ((rsi1 - m_oversoldLevel) + 
                              (rsi2 - m_oversoldLevel) + 
                              (rsi3 - m_oversoldLevel)) / 3.0;
         strength = MathMin(avgDistance / 20.0, 1.0); // Normalisé sur 20 points
      }
      else if(signal == RSI_SIGNAL_SELL)
      {
         // Force basée sur la distance moyenne au niveau overbought
         double avgDistance = ((m_overboughtLevel - rsi1) + 
                              (m_overboughtLevel - rsi2) + 
                              (m_overboughtLevel - rsi3)) / 3.0;
         strength = MathMin(avgDistance / 20.0, 1.0); // Normalisé sur 20 points
      }
      
      return strength;
   }
   
   //--- Vérifier si les RSI sont dans une zone neutre
   bool IsNeutralZone(double rsi1, double rsi2, double rsi3)
   {
      return (rsi1 >= m_oversoldLevel && rsi1 <= m_overboughtLevel &&
              rsi2 >= m_oversoldLevel && rsi2 <= m_overboughtLevel &&
              rsi3 >= m_oversoldLevel && rsi3 <= m_overboughtLevel);
   }
   
   //--- Obtenir informations détaillées sur l'alignement
   string GetAlignmentInfo(double rsi1, double rsi2, double rsi3)
   {
      string info = "RSI Alignment Analysis:\n";
      info += "RSI Values: " + DoubleToString(rsi1, 1) + "/" + 
              DoubleToString(rsi2, 1) + "/" + DoubleToString(rsi3, 1) + "\n";
      info += "Levels: Oversold=" + IntegerToString(m_oversoldLevel) + 
              " | Overbought=" + IntegerToString(m_overboughtLevel) + "\n";
      
      bool buyAlign = IsBuyAlignment(rsi1, rsi2, rsi3);
      bool sellAlign = IsSellAlignment(rsi1, rsi2, rsi3);
      
      info += "Buy Alignment: " + (buyAlign ? "YES" : "NO") + "\n";
      info += "Sell Alignment: " + (sellAlign ? "YES" : "NO") + "\n";
      
      if(IsNeutralZone(rsi1, rsi2, rsi3))
         info += "Zone: NEUTRAL\n";
      else if(buyAlign)
         info += "Zone: BULLISH\n";
      else if(sellAlign)
         info += "Zone: BEARISH\n";
      else
         info += "Zone: MIXED\n";
      
      double strength = GetSignalStrength(rsi1, rsi2, rsi3);
      info += "Signal Strength: " + DoubleToString(strength, 2);
      
      return info;
   }
   
   //--- Convertir signal en string
   string SignalToString(ENUM_RSI_SIGNAL signal)
   {
      switch(signal)
      {
         case RSI_SIGNAL_BUY: return "BUY";
         case RSI_SIGNAL_SELL: return "SELL";
         case RSI_SIGNAL_NONE: return "NONE";
         default: return "UNKNOWN";
      }
   }
   
   //--- Obtenir le dernier signal
   ENUM_RSI_SIGNAL GetLastSignal() const { return m_lastSignal; }
   
   //--- Obtenir le temps du dernier signal
   datetime GetLastSignalTime() const { return m_lastSignalTime; }
   
   //--- Réinitialiser l'historique des signaux
   void ResetSignalHistory()
   {
      m_lastSignal = RSI_SIGNAL_NONE;
      m_lastSignalTime = 0;
      Logger::Debug("Signal history reset");
   }
   
   //--- Modifier les niveaux
   void SetLevels(int oversold, int overbought)
   {
      m_oversoldLevel = oversold;
      m_overboughtLevel = overbought;
      Logger::Info("RSI levels updated: " + IntegerToString(oversold) + "/" + 
                   IntegerToString(overbought));
   }
   
   //--- Modifier le mode d'alignement
   void SetStrictAlignment(bool strict)
   {
      m_useStrictAlignment = strict;
      Logger::Info("Alignment mode: " + (strict ? "STRICT" : "FLEXIBLE"));
   }
};
