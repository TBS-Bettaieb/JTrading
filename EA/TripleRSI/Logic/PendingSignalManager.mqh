//+------------------------------------------------------------------+
//|                                       PendingSignalManager.mqh   |
//|                           Gestionnaire de Signaux en Attente     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Enumération des signaux RSI (dupliquée pour éviter dépendance)  |
//+------------------------------------------------------------------+
enum ENUM_RSI_SIGNAL
  {
   RSI_SIGNAL_NONE = 0,    // Aucun signal
   RSI_SIGNAL_BUY = 1,     // Signal d'achat (3 RSI > oversold)
   RSI_SIGNAL_SELL = -1    // Signal de vente (3 RSI < overbought)
  };

//+------------------------------------------------------------------+
//| Structure pour stocker un signal en attente                      |
//+------------------------------------------------------------------+
struct SPendingSignal
  {
   ENUM_RSI_SIGNAL signalType;      // Type de signal (BUY/SELL)
   datetime        detectionTime;    // Heure de détection
   int             detectionBar;     // Numéro de barre de détection
   double          rsi1;             // RSI période 1
   double          rsi2;             // RSI période 2
   double          rsi3;             // RSI période 3
   double          detectionPrice;   // Prix au moment du signal (pivot initial)
   bool            isActive;         // Signal actif ou non
  };

//+------------------------------------------------------------------+
//| Classe de gestion des signaux en attente                         |
//+------------------------------------------------------------------+
class CPendingSignalManager
  {
private:
   SPendingSignal    m_pendingSignal;
   int               m_confirmationBars;  // Nombre de barres max pour confirmation

public:
   //--- Constructor
   CPendingSignalManager(int confirmBars = 8)
     {
      m_confirmationBars = confirmBars;
      Reset();
      Logger::Debug("PendingSignalManager initialized (confirmBars: " + 
                    IntegerToString(confirmBars) + ")");
     }

   //--- Destructor
   ~CPendingSignalManager()
     {
      Logger::Debug("PendingSignalManager destroyed");
     }

   //--- Ajouter un nouveau signal en attente
   void AddPendingSignal(ENUM_RSI_SIGNAL signal, double rsi1, double rsi2, double rsi3, 
                        int currentBar, double currentPrice)
     {
      m_pendingSignal.signalType = signal;
      m_pendingSignal.detectionTime = TimeCurrent();
      m_pendingSignal.detectionBar = currentBar;
      m_pendingSignal.rsi1 = rsi1;
      m_pendingSignal.rsi2 = rsi2;
      m_pendingSignal.rsi3 = rsi3;
      m_pendingSignal.detectionPrice = currentPrice;
      m_pendingSignal.isActive = true;

      string signalStr = (signal == RSI_SIGNAL_BUY) ? "BUY" : "SELL";
      Logger::Debug("Signal RSI " + signalStr + " mis en attente (" + 
                    IntegerToString(m_confirmationBars) + " barres max)");
      Logger::Debug("RSI: " + DoubleToString(rsi1, 1) + "/" + 
                    DoubleToString(rsi2, 1) + "/" + DoubleToString(rsi3, 1));
      Logger::Debug("Prix pivot initial: " + DoubleToString(currentPrice, _Digits));
     }

   //--- Vérifier si un signal est en attente
   bool HasPendingSignal() const
     {
      return m_pendingSignal.isActive;
     }

   //--- Vérifier si le timeout est atteint
   bool IsTimeout(int currentBar)
     {
      if(!m_pendingSignal.isActive)
         return false;

      int barsElapsed = currentBar - m_pendingSignal.detectionBar;
      
      if(barsElapsed >= m_confirmationBars)
        {
         Logger::Debug("IsTimeout: " + IntegerToString(barsElapsed) + 
                       " barres écoulées (max: " + IntegerToString(m_confirmationBars) + ")");
         return true;
        }
      
      return false;
     }

   //--- Obtenir le signal en attente
   SPendingSignal GetPendingSignal() const
     {
      return m_pendingSignal;
     }

   //--- Confirmer le signal (validation par divergence)
   void ConfirmSignal()
     {
      if(!m_pendingSignal.isActive)
        {
         Logger::Warning("Tentative de confirmation d'un signal inexistant");
         return;
        }

      string signalStr = (m_pendingSignal.signalType == RSI_SIGNAL_BUY) ? "BUY" : "SELL";
      Logger::Signal(m_pendingSignal.signalType == RSI_SIGNAL_BUY,
                     "Signal " + signalStr + " validé par divergence - Ordre autorisé");

      m_pendingSignal.isActive = false;
     }

   //--- Annuler le signal (timeout ou autre raison)
   void CancelSignal()
     {
      if(!m_pendingSignal.isActive)
         return;

      string signalStr = (m_pendingSignal.signalType == RSI_SIGNAL_BUY) ? "BUY" : "SELL";
      Logger::Debug("⏱️ Timeout signal " + signalStr + " après " + 
                    IntegerToString(m_confirmationBars) + " barres sans divergence - Annulation");

      m_pendingSignal.isActive = false;
     }

   //--- Réinitialiser complètement le gestionnaire
   void Reset()
     {
      m_pendingSignal.signalType = RSI_SIGNAL_NONE;
      m_pendingSignal.detectionTime = 0;
      m_pendingSignal.detectionBar = 0;
      m_pendingSignal.rsi1 = 0.0;
      m_pendingSignal.rsi2 = 0.0;
      m_pendingSignal.rsi3 = 0.0;
      m_pendingSignal.detectionPrice = 0.0;
      m_pendingSignal.isActive = false;
     }

   //--- Obtenir le nombre de barres de confirmation configuré
   int GetConfirmationBars() const
     {
      return m_confirmationBars;
     }

   //--- Modifier le nombre de barres de confirmation
   void SetConfirmationBars(int confirmBars)
     {
      m_confirmationBars = confirmBars;
      Logger::Info("Confirmation bars updated to: " + IntegerToString(confirmBars));
     }

   //--- Obtenir informations sur le signal en attente
   string GetPendingSignalInfo() const
     {
      if(!m_pendingSignal.isActive)
         return "Aucun signal en attente";

      string info = "Signal en attente:\n";
      info += "Type: " + ((m_pendingSignal.signalType == RSI_SIGNAL_BUY) ? "BUY" : "SELL") + "\n";
      info += "Détection: " + TimeToString(m_pendingSignal.detectionTime) + "\n";
      info += "Barre: " + IntegerToString(m_pendingSignal.detectionBar) + "\n";
      info += "RSI: " + DoubleToString(m_pendingSignal.rsi1, 1) + "/" +
              DoubleToString(m_pendingSignal.rsi2, 1) + "/" +
              DoubleToString(m_pendingSignal.rsi3, 1);

      return info;
     }
  };
//+------------------------------------------------------------------+

