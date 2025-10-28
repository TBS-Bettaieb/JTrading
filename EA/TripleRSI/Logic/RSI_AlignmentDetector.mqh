//+------------------------------------------------------------------+
//|                                      RSI_AlignmentDetector.mqh   |
//|                                    Détecteur Alignement RSI      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"
#include "../../Shared/TrendFilters/TrendAnalysis.mqh"
#include "../../Shared/TimeframeUtils.mqh"
#include "PendingSignalManager.mqh"  // Inclut ENUM_RSI_SIGNAL
#include "RSI_DivergenceDetector.mqh"

//+------------------------------------------------------------------+
//| Triple RSI Alignment Detector Class                              |
//+------------------------------------------------------------------+
class CRSIAlignmentDetector
  {
private:
   int               m_oversoldLevel;
   int               m_overboughtLevel;
   bool              m_useStrictAlignment;  // true = tous les RSI doivent être alignés

   // Historique des signaux pour éviter les signaux répétés
   ENUM_RSI_SIGNAL   m_lastSignal;
   datetime          m_lastSignalTime;

   // Système de confirmation par divergence
   CPendingSignalManager*     m_pendingManager;
   CRSIDivergenceDetector*    m_divDetector;
   bool                       m_useDivergenceConfirm;
   int                        m_divConfirmBars;
   int                        m_divLookbackBars;
   double                     m_divMinStrength;

   // Handles RSI pour la divergence
   int m_rsiHandle1;
   int m_rsiHandle2;
   int m_rsiHandle3;
   int m_divergenceRsiIndex;  // Quel RSI utiliser pour divergence (1, 2, ou 3)

   //--- Détecter le signal de base RSI
   ENUM_RSI_SIGNAL   DetectBaseSignal(double rsi1, double rsi2, double rsi3)
     {
      if(IsBuyAlignment(rsi1, rsi2, rsi3))
         return RSI_SIGNAL_BUY;
      if(IsSellAlignment(rsi1, rsi2, rsi3))
         return RSI_SIGNAL_SELL;
      return RSI_SIGNAL_NONE;
     }

   //--- Valider signal avec EMA sur timeframe supérieur
   bool              ValidateSignalWithEMA(ENUM_RSI_SIGNAL signal, string symbol, ENUM_TIMEFRAMES currentTF,
                                           int emaPeriod, bool useCrossFilter, int crossBarsCheck, int maxCrossings)
     {
      if(signal == RSI_SIGNAL_NONE)
         return true; // Pas de signal à valider

      string targetSymbol = (symbol == NULL) ? _Symbol : symbol;
      ENUM_TIMEFRAMES higherTF = TimeframeUtils::GetNextHigherTimeframe(currentTF);
      ENUM_TIMEFRAMES higherTFSecond = TimeframeUtils::GetNextHigherTimeframe(higherTF);

      bool isBullish = (signal == RSI_SIGNAL_BUY);

      // 1. Validation tendance classique
      bool emaConfirm = TrendAnalysis::CheckHigherTimeframeTrend(targetSymbol, higherTF, isBullish, emaPeriod);
      bool emaConfirmSecond = TrendAnalysis::CheckHigherTimeframeTrend(targetSymbol, higherTFSecond, isBullish, emaPeriod);

      int crossingsHigherTF = TrendAnalysis::CountEMACrossings(targetSymbol, higherTF, emaPeriod, crossBarsCheck);
      int crossingsHigherTFSecond = TrendAnalysis::CountEMACrossings(targetSymbol, higherTFSecond, emaPeriod, crossBarsCheck);

      bool tooCrossing=(crossingsHigherTF> maxCrossings) || (crossingsHigherTFSecond> maxCrossings);

      // 2. Validation croisements EMA (si activée)
      if(useCrossFilter && (emaConfirm || emaConfirmSecond))
        {
         if(tooCrossing)
            return false;
        }

      // 3. Résultat final
      bool tendanceOK = emaConfirm && emaConfirmSecond;

      return tendanceOK;
     }

   //--- Vérifier si le signal est une répétition
   bool IsRepeatedSignal(ENUM_RSI_SIGNAL signal)
     {
      if(signal == m_lastSignal)
        {
         if(signal != RSI_SIGNAL_NONE)
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
      Logger::Debug("RSI Values: " + DoubleToString(rsi1, 1) + "/" + 
      DoubleToString(rsi2, 1) + "/" + DoubleToString(rsi3, 1));
      
      Logger::Signal(signal == RSI_SIGNAL_BUY,
                     "RSI Alignment Signal: " + SignalToString(signal) +
                     " | RSI: " + DoubleToString(rsi1, 1) + "/" +
                     DoubleToString(rsi2, 1) + "/" + DoubleToString(rsi3, 1));
     }

public:
   //--- Constructor
                     CRSIAlignmentDetector(int oversold, int overbought, bool strictAlignment = true,
                                          bool useDivConfirm = false, int divConfirmBars = 8,
                                          int divLookback = 10, double divMinStrength = 3.0,
                                          int divergenceRsiIndex = 3)
     {
      m_oversoldLevel = oversold;
      m_overboughtLevel = overbought;
      m_useStrictAlignment = strictAlignment;
      m_lastSignal = RSI_SIGNAL_NONE;
      m_lastSignalTime = 0;

      // Initialisation du système de divergence
      m_useDivergenceConfirm = useDivConfirm;
      m_divergenceRsiIndex = divergenceRsiIndex;
      m_divConfirmBars = divConfirmBars;
      m_divLookbackBars = divLookback;
      m_divMinStrength = divMinStrength;
      m_rsiHandle1 = INVALID_HANDLE;
      m_rsiHandle2 = INVALID_HANDLE;
      m_rsiHandle3 = INVALID_HANDLE;

      if(useDivConfirm)
        {
         m_pendingManager = new CPendingSignalManager(divConfirmBars);
         
         // Mapper les paramètres d'input de l'EA vers le détecteur
         // Utiliser les niveaux RSI de l'EA (cohérent avec la stratégie Triple RSI)
         m_divDetector = new CRSIDivergenceDetector(
             3,                              // lookbackLeft (TradingView default)
             1,                              // lookbackRight (TradingView default)
             3,                              // rangeLower (distance min pivots)
             100,                            // rangeUpper (distance max pivots)
             (double)m_overboughtLevel,      // upperLevel (70 de l'EA)
             (double)m_oversoldLevel,        // lowerLevel (30 de l'EA)
             divMinStrength                  // minStrength (3.0 de l'EA)
         );
         
         Logger::Debug("Divergence confirmation system ENABLED");
         Logger::Debug("  RSI levels: " + IntegerToString(m_oversoldLevel) + 
                       " / " + IntegerToString(m_overboughtLevel) + 
                       " (from EA config)");
         Logger::Debug("  Lookback: 3/1 | Range: 3-100 | Strength: " + 
                       DoubleToString(divMinStrength, 1) + "%");
         
         string rsiType = (m_divergenceRsiIndex == 1) ? "RAPIDE" : 
                         (m_divergenceRsiIndex == 2) ? "MOYEN" : "LENT";
         Logger::Info("  RSI utilisé pour divergence: RSI" + IntegerToString(m_divergenceRsiIndex) + 
                      " (" + rsiType + ")");
        }
      else
        {
         m_pendingManager = NULL;
         m_divDetector = NULL;
        }

      Logger::Debug("RSI Alignment Detector initialized");
      Logger::Debug("Oversold: " + IntegerToString(oversold) +
                    " | Overbought: " + IntegerToString(overbought));
     }

   //--- Destructor
                    ~CRSIAlignmentDetector()
     {
      if(m_pendingManager != NULL)
         delete m_pendingManager;
      if(m_divDetector != NULL)
         delete m_divDetector;
      Logger::Debug("RSI Alignment Detector destroyed");
     }

   //--- Enregistrer les handles RSI pour la détection de divergence
   void SetRSIHandles(int handle1, int handle2, int handle3)
     {
      m_rsiHandle1 = handle1;
      m_rsiHandle2 = handle2;
      m_rsiHandle3 = handle3;
      Logger::Debug("RSI handles registered for divergence detection");
     }

   //--- Obtenir le handle RSI approprié pour la divergence
   int GetDivergenceRsiHandle()
     {
      switch(m_divergenceRsiIndex)
        {
         case 1: return m_rsiHandle1;
         case 2: return m_rsiHandle2;
         case 3: return m_rsiHandle3;
         default:
            Logger::Warning("Invalid divergence RSI index: " + 
                           IntegerToString(m_divergenceRsiIndex) + ", using RSI1");
            return m_rsiHandle1;
        }
     }

   //--- Obtenir la valeur RSI appropriée pour la divergence
   double GetDivergenceRsiValue(SPendingSignal &pending)
     {
      switch(m_divergenceRsiIndex)
        {
         case 1: return pending.rsi1;
         case 2: return pending.rsi2;
         case 3: return pending.rsi3;
         default:
            Logger::Warning("Invalid divergence RSI index: " + 
                           IntegerToString(m_divergenceRsiIndex) + ", using RSI1");
            return pending.rsi1;
        }
     }

   //--- Détecter alignement pour signal achat
   // Tous les RSI doivent être au-dessus du niveau oversold
   bool              IsBuyAlignment(double rsi1, double rsi2, double rsi3)
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
         if(rsi1 < m_oversoldLevel)
            count++;
         if(rsi2 < m_oversoldLevel)
            count++;

         return (count >= 2);
        }
     }

   //--- Détecter alignement pour signal vente
   // Tous les RSI doivent être en-dessous du niveau overbought
   bool              IsSellAlignment(double rsi1, double rsi2, double rsi3)
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
         if(rsi1 > m_overboughtLevel)
            count++;
         if(rsi2 > m_overboughtLevel)
            count++;

         return (count >= 2);
        }
     }

   //--- Obtenir signal global avec gestion des répétitions
   ENUM_RSI_SIGNAL GetSignal(double rsi1, double rsi2, double rsi3, 
                            bool allowRepeat = false,
                            bool validateWithEMA = false,
                            string symbol = NULL,
                            ENUM_TIMEFRAMES currentTF = PERIOD_CURRENT,
                            int emaPeriod = 50,
                            bool useCrossFilter = false,
                            int crossBarsCheck = 20,
                            int maxCrossings = 2)
   {
      // 1. Détection du signal de base
      ENUM_RSI_SIGNAL signal = DetectBaseSignal(rsi1, rsi2, rsi3);
      
      // ✨ AJOUT : Reset si on quitte la zone du signal précédent
   if(signal == RSI_SIGNAL_NONE && m_lastSignal != RSI_SIGNAL_NONE)
   {
      Logger::Debug("Exit from " + SignalToString(m_lastSignal) + " zone - Reset history");
      ResetSignalHistory();
   }

      // 2. Validation avec EMA si demandée
      if(validateWithEMA && !ValidateSignalWithEMA(signal, symbol, currentTF, emaPeriod, 
                                                 useCrossFilter, crossBarsCheck, maxCrossings))
      {
         // Signal rejeté par EMA → réinitialiser l'historique pour ne pas bloquer les prochains
         m_lastSignal = RSI_SIGNAL_NONE;
         return RSI_SIGNAL_NONE;
      }
      
      // 3. Vérification des répétitions
      if(!allowRepeat && IsRepeatedSignal(signal))
         return RSI_SIGNAL_NONE;
      
      // 4. Mise à jour de l'historique (seulement si toutes les validations passent)
      UpdateSignalHistory(signal, rsi1, rsi2, rsi3);
      
      return signal;
   }

   //--- Obtenir signal avec confirmation par divergence
   ENUM_RSI_SIGNAL GetSignalWithDivergence(double rsi1, double rsi2, double rsi3,
                                          string symbol, ENUM_TIMEFRAMES tf, int currentBar,
                                          bool allowRepeat = false,
                                          bool validateWithEMA = false,
                                          int emaPeriod = 50,
                                          bool useCrossFilter = false,
                                          int crossBarsCheck = 20,
                                          int maxCrossings = 2)
     {
      // Vérifier que les handles RSI sont valides si mode divergence activé
      if(m_useDivergenceConfirm && 
         (m_rsiHandle1 == INVALID_HANDLE || 
          m_rsiHandle2 == INVALID_HANDLE || 
          m_rsiHandle3 == INVALID_HANDLE))
        {
         Logger::Error("GetSignalWithDivergence: Handles RSI non enregistrés ! " +
                       "Appelez SetRSIHandles() dans OnInit()");
         
         // Mode dégradé : désactiver temporairement la divergence
         m_useDivergenceConfirm = false;
         Logger::Warning("Mode divergence désactivé temporairement");
        }
      
      // Si le mode divergence est désactivé, utiliser la méthode classique
      if(!m_useDivergenceConfirm)
        {
         return GetSignal(rsi1, rsi2, rsi3, allowRepeat, validateWithEMA, 
                         symbol, tf, emaPeriod, useCrossFilter, crossBarsCheck, maxCrossings);
        }

      // === ÉTAPE 1 : Vérifier si un signal est en attente ===
      if(m_pendingManager != NULL && m_pendingManager.HasPendingSignal())
        {
         // Vérifier le timeout
         if(m_pendingManager.IsTimeout(currentBar))
           {
            SPendingSignal pending = m_pendingManager.GetPendingSignal();
            Logger::Debug("⏱️ Timeout signal " + SignalToString(pending.signalType) + 
                          " après " + IntegerToString(m_divConfirmBars) + 
                          " barres sans divergence - Annulation");
            
            // Griser le marqueur pour indiquer l'annulation
            datetime signalTime = iTime(symbol, tf, pending.detectionBar);
            CancelPendingSignalMarker(symbol, tf, signalTime);
            
            m_pendingManager.CancelSignal();
            return RSI_SIGNAL_NONE;
           }

         // Récupérer le signal en attente
         SPendingSignal pending = m_pendingManager.GetPendingSignal();
         bool divergenceFound = false;

         // Calculer le nombre de barres écoulées depuis le signal
         int barsElapsed = currentBar - pending.detectionBar;
         
         Logger::Debug("Recherche divergence - Signal @ bar[" + IntegerToString(pending.detectionBar) + 
                       "] (il y a " + IntegerToString(barsElapsed) + " barres)");

         // Chercher la divergence selon le type de signal (dans le FUTUR depuis le signal initial)
         if(pending.signalType == RSI_SIGNAL_BUY)
           {
            // Chercher divergence bullish dans le futur (Prix ↓ RSI ↑)
            // Le signal initial est le premier pivot, on cherche un nouveau pivot qui se forme après
            if(m_divDetector != NULL)
              {
               divergenceFound = m_divDetector.DetectBullishDivergenceInFuture(
                  symbol,                          // Symbole
                  tf,                              // Timeframe
                  GetDivergenceRsiHandle(),        // Handle RSI (1, 2, ou 3 selon config)
                  barsElapsed,                     // Barre du signal (ancienneté)
                  GetDivergenceRsiValue(pending),  // RSI au moment du signal
                  pending.detectionPrice,          // Prix au moment du signal
                  m_divConfirmBars);               // Fenêtre de recherche max
               
               Logger::Debug("DetectBullishDivergenceInFuture appelé: " + 
                            (divergenceFound ? "TROUVÉE ✅" : "NON TROUVÉE ❌"));
              }
           }
         else
            if(pending.signalType == RSI_SIGNAL_SELL)
              {
               // Chercher divergence bearish dans le futur (Prix ↑ RSI ↓)
               if(m_divDetector != NULL)
                 {
                  divergenceFound = m_divDetector.DetectBearishDivergenceInFuture(
                     symbol,
                     tf,
                     GetDivergenceRsiHandle(),        // Handle RSI (1, 2, ou 3 selon config)
                     barsElapsed,
                     GetDivergenceRsiValue(pending),  // RSI au moment du signal
                     pending.detectionPrice,
                     m_divConfirmBars);
                  
                  Logger::Debug("DetectBearishDivergenceInFuture appelé: " + 
                               (divergenceFound ? "TROUVÉE ✅" : "NON TROUVÉE ❌"));
                 }
              }

         // Si divergence trouvée, confirmer et retourner le signal
         if(divergenceFound)
           {
            m_pendingManager.ConfirmSignal();
            UpdateSignalHistory(pending.signalType, pending.rsi1, pending.rsi2, pending.rsi3);
            
            // Changer la couleur du marqueur (bleu/orange → vert/rouge)
            datetime signalTime = iTime(symbol, tf, pending.detectionBar);
            ConfirmPendingSignalMarker(symbol, tf, signalTime, pending.signalType);
            
            return pending.signalType;
           }

         // Sinon, continuer d'attendre
         return RSI_SIGNAL_NONE;
        }

      // === ÉTAPE 2 : Détecter un nouveau signal RSI ===
      ENUM_RSI_SIGNAL signal = DetectBaseSignal(rsi1, rsi2, rsi3);

      // Reset si on quitte la zone du signal précédent
      if(signal == RSI_SIGNAL_NONE && m_lastSignal != RSI_SIGNAL_NONE)
        {
         Logger::Debug("Exit from " + SignalToString(m_lastSignal) + " zone - Reset history");
         ResetSignalHistory();
        }

      if(signal != RSI_SIGNAL_NONE)
        {
         // Validation avec EMA si demandée
         if(validateWithEMA && !ValidateSignalWithEMA(signal, symbol, tf, emaPeriod,
                                                      useCrossFilter, crossBarsCheck, maxCrossings))
           {
            m_lastSignal = RSI_SIGNAL_NONE;
            return RSI_SIGNAL_NONE;
           }

         // Vérifier les répétitions
         if(!allowRepeat && IsRepeatedSignal(signal))
            return RSI_SIGNAL_NONE;

         // Récupérer le prix actuel (pivot initial de la divergence)
         double currentPrice;
         if(signal == RSI_SIGNAL_BUY)
            currentPrice = iLow(symbol, tf, 0);   // Prix Low pour signal BUY
         else
            currentPrice = iHigh(symbol, tf, 0);  // Prix High pour signal SELL

         // Mettre le signal en attente pour confirmation par divergence
         if(m_pendingManager != NULL)
           {
            m_pendingManager.AddPendingSignal(signal, rsi1, rsi2, rsi3, currentBar, currentPrice);
            Logger::Debug("Signal en attente @ bar[" + IntegerToString(currentBar) + 
                         "] Prix=" + DoubleToString(currentPrice, _Digits));
            
            // Dessiner le marqueur visuel
            datetime barTime = iTime(symbol, tf, 0);
            DrawPendingSignalMarker(symbol, tf, barTime, currentPrice, signal);
           }

         // Retourner NONE car le signal n'est pas encore confirmé
         return RSI_SIGNAL_NONE;
        }

      return RSI_SIGNAL_NONE;
     }

   //--- Obtenir signal sans vérification de répétition
   ENUM_RSI_SIGNAL   GetRawSignal(double rsi1, double rsi2, double rsi3)
     {
      if(IsBuyAlignment(rsi1, rsi2, rsi3))
         return RSI_SIGNAL_BUY;
      if(IsSellAlignment(rsi1, rsi2, rsi3))
         return RSI_SIGNAL_SELL;
      return RSI_SIGNAL_NONE;
     }

   //--- Analyser la force du signal
   double            GetSignalStrength(double rsi1, double rsi2, double rsi3)
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
      else
         if(signal == RSI_SIGNAL_SELL)
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
   bool              IsNeutralZone(double rsi1, double rsi2, double rsi3)
     {
      return (rsi1 >= m_oversoldLevel && rsi1 <= m_overboughtLevel &&
              rsi2 >= m_oversoldLevel && rsi2 <= m_overboughtLevel &&
              rsi3 >= m_oversoldLevel && rsi3 <= m_overboughtLevel);
     }

   //--- Obtenir informations détaillées sur l'alignement
   string            GetAlignmentInfo(double rsi1, double rsi2, double rsi3)
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
      else
         if(buyAlign)
            info += "Zone: BULLISH\n";
         else
            if(sellAlign)
               info += "Zone: BEARISH\n";
            else
               info += "Zone: MIXED\n";

      double strength = GetSignalStrength(rsi1, rsi2, rsi3);
      info += "Signal Strength: " + DoubleToString(strength, 2);

      return info;
     }

   //--- Convertir signal en string
   string            SignalToString(ENUM_RSI_SIGNAL signal)
     {
      switch(signal)
        {
         case RSI_SIGNAL_BUY:
            return "BUY";
         case RSI_SIGNAL_SELL:
            return "SELL";
         case RSI_SIGNAL_NONE:
            return "NONE";
         default:
            return "UNKNOWN";
        }
     }

   //--- Obtenir le dernier signal
   ENUM_RSI_SIGNAL   GetLastSignal() const { return m_lastSignal; }

   //--- Obtenir le temps du dernier signal
   datetime          GetLastSignalTime() const { return m_lastSignalTime; }

   //--- Réinitialiser l'historique des signaux
   void              ResetSignalHistory()
     {
      m_lastSignal = RSI_SIGNAL_NONE;
      m_lastSignalTime = 0;
      Logger::Debug("Signal history reset");
     }

   //--- Modifier les niveaux
   void              SetLevels(int oversold, int overbought)
     {
      m_oversoldLevel = oversold;
      m_overboughtLevel = overbought;
      Logger::Info("RSI levels updated: " + IntegerToString(oversold) + "/" +
                   IntegerToString(overbought));
     }

   //--- Modifier le mode d'alignement
   void              SetStrictAlignment(bool strict)
     {
      m_useStrictAlignment = strict;
      Logger::Info("Alignment mode: " + (strict ? "STRICT" : "FLEXIBLE"));
     }

   //+------------------------------------------------------------------+
   //| Marqueurs visuels pour signaux en attente                        |
   //+------------------------------------------------------------------+
   
   //--- Dessiner un marqueur visuel pour signal en attente
   void DrawPendingSignalMarker(string symbol, ENUM_TIMEFRAMES tf,
                                datetime barTime, double price,
                                ENUM_RSI_SIGNAL signalType)
     {
      string objectName = "PendingSignal_" + TimeToString(barTime, TIME_DATE|TIME_MINUTES);
      
      // Supprimer l'ancien objet s'il existe
      if(ObjectFind(0, objectName) >= 0)
         ObjectDelete(0, objectName);
      
      // Créer une flèche
      int arrowCode = (signalType == RSI_SIGNAL_BUY) ? 241 : 242; // ⬆️ ou ⬇️
      color arrowColor = (signalType == RSI_SIGNAL_BUY) ? clrDodgerBlue : clrOrange;
      
      ObjectCreate(0, objectName, OBJ_ARROW, 0, barTime, price);
      ObjectSetInteger(0, objectName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 3);
      ObjectSetString(0, objectName, OBJPROP_TOOLTIP,
                      "Signal " + SignalToString(signalType) + " en attente de divergence");
      
      Logger::Debug("🎨 Marqueur dessiné @ " + TimeToString(barTime));
     }

   //--- Changer la couleur du marqueur quand divergence confirmée
   void ConfirmPendingSignalMarker(string symbol, ENUM_TIMEFRAMES tf,
                                   datetime barTime, ENUM_RSI_SIGNAL signalType)
     {
      string objectName = "PendingSignal_" + TimeToString(barTime, TIME_DATE|TIME_MINUTES);
      
      if(ObjectFind(0, objectName) >= 0)
        {
         // Changer en vert/rouge vif pour confirmation
         color confirmedColor = (signalType == RSI_SIGNAL_BUY) ? clrLime : clrRed;
         ObjectSetInteger(0, objectName, OBJPROP_COLOR, confirmedColor);
         ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 4);
         ObjectSetString(0, objectName, OBJPROP_TOOLTIP,
                         "Signal " + SignalToString(signalType) + " CONFIRME par divergence ✅");
         
         Logger::Debug("✅ Marqueur confirmé @ " + TimeToString(barTime));
        }
     }

   //--- Annuler le marqueur si timeout
   void CancelPendingSignalMarker(string symbol, ENUM_TIMEFRAMES tf, datetime barTime)
     {
      string objectName = "PendingSignal_" + TimeToString(barTime, TIME_DATE|TIME_MINUTES);
      
      if(ObjectFind(0, objectName) >= 0)
        {
         // Changer en gris pour annulation
         ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrGray);
         ObjectSetString(0, objectName, OBJPROP_TOOLTIP, "Signal annule (timeout) ❌");
         
         Logger::Debug("❌ Marqueur annulé @ " + TimeToString(barTime));
        }
     }
  };
//+------------------------------------------------------------------+
