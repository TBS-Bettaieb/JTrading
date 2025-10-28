//+------------------------------------------------------------------+
//|                                      RSI_AlignmentDetector.mqh   |
//|                                    Détecteur Alignement RSI      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"

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
                            bool allowRepeat = false)
   {
      ENUM_RSI_SIGNAL currentSignal = RSI_SIGNAL_NONE;
      
      if(IsBuyAlignment(rsi1, rsi2, rsi3))
         currentSignal = RSI_SIGNAL_BUY;
      else if(IsSellAlignment(rsi1, rsi2, rsi3))
         currentSignal = RSI_SIGNAL_SELL;
      
      // Éviter les signaux répétés si demandé
      if(!allowRepeat && currentSignal == m_lastSignal)
      {
         Logger::Debug("Signal répété ignoré: " + SignalToString(currentSignal));
         return RSI_SIGNAL_NONE;
      }
      
      // Mettre à jour l'historique
      if(currentSignal != RSI_SIGNAL_NONE)
      {
         m_lastSignal = currentSignal;
         m_lastSignalTime = TimeCurrent();
         
         Logger::Signal(currentSignal == RSI_SIGNAL_BUY, 
                       "RSI Alignment Signal: " + SignalToString(currentSignal) + 
                       " | RSI: " + DoubleToString(rsi1, 1) + "/" + 
                       DoubleToString(rsi2, 1) + "/" + DoubleToString(rsi3, 1));
      }
      
      return currentSignal;
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
