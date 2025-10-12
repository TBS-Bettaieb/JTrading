//+------------------------------------------------------------------+
//|                                          JT_MoneyManagement.mqh  |
//|                    Système avancé de Money Management (MT5)      |
//|                                      (c) 2025 - Version 2.1      |
//+------------------------------------------------------------------+
#property strict

#include "JT_AdaptiveSL.mqh"

//+------------------------------------------------------------------+
//| Énumérations pour les différentes méthodes                       |
//+------------------------------------------------------------------+
enum SL_METHOD {
   SL_ATR = 0,              // ATR basé
   SL_SWING = 1,            // Swing high/low
   SL_FIXED_POINTS = 2,     // Points fixes
   SL_PERCENT = 3,          // Pourcentage du prix
   SL_BOLLINGER = 4,        // Bande de Bollinger opposée
   SL_SUPPORT_RESISTANCE = 5, // Niveau S/R le plus proche
   SL_ADAPTIVE = 6          // Adaptatif multi-actifs (RECOMMANDÉ)
};

enum TP_METHOD {
   TP_RR_RATIO = 0,         // Ratio risque/récompense
   TP_ATR = 1,              // Multiple d'ATR
   TP_SWING = 2,            // Swing high/low opposé
   TP_FIXED_POINTS = 3,     // Points fixes
   TP_BOLLINGER = 4,        // Bande de Bollinger opposée
   TP_FIBONACCI = 5         // Extensions Fibonacci
};

//+------------------------------------------------------------------+
//| Structure pour les paramètres de calcul                         |
//+------------------------------------------------------------------+
struct TPSLParams {
   // Paramètres SL
   SL_METHOD slMethod;
   double slATRMultiplier;
   int slSwingPeriod;
   double slFixedPoints;
   double slPercent;
   double slVolatilityMultiplier;  // Multiplicateur de volatilité pour SL adaptatif
   
   // Paramètres TP
   TP_METHOD tpMethod;
   double tpRRRatio;
   double tpATRMultiplier;
   int tpSwingPeriod;
   double tpFixedPoints;
   
   // Paramètres généraux
   double minRR;            // RR minimum acceptable
   double maxRR;            // RR maximum (pour éviter des TP irréalistes)
   bool useBreakEven;       // Activer break-even
   double beActivationRR;   // RR à partir duquel activer le BE (ex: 0.5)
   int beOffsetPoints;      // Offset du BE en points
   
   // Trailing Stop
   bool useTrailing;
   double trailingStartRR;  // RR à partir duquel activer le trailing
   double trailingStepPoints; // Pas du trailing stop
   double trailingStopPoints; // Distance du trailing stop
   
   // Validation
   int minDistancePoints;   // Distance minimale SL en points
   int maxDistancePoints;   // Distance maximale SL en points
};

//+------------------------------------------------------------------+
//| Classe principale de Money Management                            |
//+------------------------------------------------------------------+
class JTMoneyManagement {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   TPSLParams m_params;
   
   // Handles d'indicateurs
   int m_atrHandle;
   int m_bbHandle;
   bool m_ownsHandles;  // True si les handles sont créés par cette classe
   
   // Système adaptatif
   JTAdaptiveSL* m_adaptiveSL;
   
public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                     |
   //+------------------------------------------------------------------+
   JTMoneyManagement(string symbol, ENUM_TIMEFRAMES timeframe) {
      m_symbol = symbol;
      m_timeframe = timeframe;
      
      // Initialiser les handles
      m_atrHandle = INVALID_HANDLE;
      m_bbHandle = INVALID_HANDLE;
      m_ownsHandles = false;  // Par défaut, les handles sont externes
      
      // Initialiser le système adaptatif
      m_adaptiveSL = NULL;
      
      // Paramètres par défaut
      SetDefaultParams();
   }
   
   //+------------------------------------------------------------------+
   //| Définir les handles existants (RECOMMANDÉ)                      |
   //+------------------------------------------------------------------+
   bool SetExternalHandles(int atrHandle, int bbHandle) {
      m_atrHandle = atrHandle;
      m_bbHandle = bbHandle;
      m_ownsHandles = false;  // Les handles sont gérés par l'appelant
      return (m_atrHandle != INVALID_HANDLE && m_bbHandle != INVALID_HANDLE);
   }
   
   //+------------------------------------------------------------------+
   //| Initialiser le système adaptatif (pour SL_ADAPTIVE)             |
   //+------------------------------------------------------------------+
   bool InitAdaptiveSL(int atrPeriod = 14) {
      if(m_adaptiveSL != NULL) {
         delete m_adaptiveSL;
         m_adaptiveSL = NULL;
      }
      
      m_adaptiveSL = new JTAdaptiveSL(m_symbol, m_timeframe, atrPeriod);
      
      if(m_adaptiveSL == NULL) {
         Print("Erreur création système adaptatif pour ", m_symbol);
         return false;
      }
      
      // Afficher les recommandations
      Print(m_adaptiveSL.GetRecommendations());
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Initialisation des indicateurs (LEGACY - préférer SetExternalHandles) |
   //+------------------------------------------------------------------+
   bool InitIndicators(int atrPeriod = 14, int bbPeriod = 20, double bbDev = 2.0) {
      // ATR
      if(m_atrHandle == INVALID_HANDLE) {
         m_atrHandle = iATR(m_symbol, m_timeframe, atrPeriod);
         if(m_atrHandle == INVALID_HANDLE) {
            Print("Erreur création handle ATR");
            return false;
         }
      }
      
      // Bollinger Bands
      if(m_bbHandle == INVALID_HANDLE) {
         m_bbHandle = iBands(m_symbol, m_timeframe, bbPeriod, 0, bbDev, PRICE_CLOSE);
         if(m_bbHandle == INVALID_HANDLE) {
            Print("Erreur création handle BB");
            return false;
         }
      }
      
      m_ownsHandles = true;  // Cette classe possède les handles et doit les libérer
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Destructeur                                                      |
   //+------------------------------------------------------------------+
   ~JTMoneyManagement() {
      // Libérer les handles uniquement si cette classe les possède
      if(m_ownsHandles) {
         if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
         if(m_bbHandle != INVALID_HANDLE) IndicatorRelease(m_bbHandle);
      }
      
      // Libérer le système adaptatif
      if(m_adaptiveSL != NULL) {
         delete m_adaptiveSL;
         m_adaptiveSL = NULL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configuration des paramètres par défaut                         |
   //+------------------------------------------------------------------+
   void SetDefaultParams() {
      m_params.slMethod = SL_ADAPTIVE;  // Par défaut: adaptatif
      m_params.slATRMultiplier = 2.0;
      m_params.slSwingPeriod = 20;
      m_params.slFixedPoints = 100;
      m_params.slPercent = 1.0;
      m_params.slVolatilityMultiplier = 1.0;
      
      m_params.tpMethod = TP_RR_RATIO;
      m_params.tpRRRatio = 2.0;
      m_params.tpATRMultiplier = 3.0;
      m_params.tpSwingPeriod = 20;
      m_params.tpFixedPoints = 200;
      
      m_params.minRR = 1.5;
      m_params.maxRR = 5.0;
      m_params.useBreakEven = true;
      m_params.beActivationRR = 0.5;
      m_params.beOffsetPoints = 5;
      
      m_params.useTrailing = true;
      m_params.trailingStartRR = 1.0;
      m_params.trailingStepPoints = 10;
      m_params.trailingStopPoints = 50;
      
      m_params.minDistancePoints = 20;
      m_params.maxDistancePoints = 500;
   }
   
   //+------------------------------------------------------------------+
   //| Définir les paramètres manuellement                             |
   //+------------------------------------------------------------------+
   void SetParams(TPSLParams &params) {
      m_params = params;
   }
   
   //+------------------------------------------------------------------+
   //| Calcul complet SL/TP avec validation                            |
   //+------------------------------------------------------------------+
   bool CalculateTPSL(
      bool isBuy,
      double entryPrice,
      double &stopLoss,
      double &takeProfit,
      string &errorMsg
   ) {
      // 1. Calculer le Stop Loss
      stopLoss = CalculateStopLoss(isBuy, entryPrice);
      
      if(stopLoss == 0) {
         errorMsg = "Échec calcul Stop Loss";
         return false;
      }
      
      // 2. Valider la distance du SL
      if(!ValidateStopLoss(isBuy, entryPrice, stopLoss, errorMsg)) {
         return false;
      }
      
      // 3. Calculer le Take Profit
      takeProfit = CalculateTakeProfit(isBuy, entryPrice, stopLoss);
      
      if(takeProfit == 0) {
         errorMsg = "Échec calcul Take Profit";
         return false;
      }
      
      // 4. Valider que le TP est dans la bonne direction
      if(isBuy && takeProfit <= entryPrice) {
         errorMsg = "TP invalide pour BUY (doit être > entry)";
         return false;
      }
      if(!isBuy && takeProfit >= entryPrice) {
         errorMsg = "TP invalide pour SELL (doit être < entry)";
         return false;
      }
      
      // 5. Valider le ratio RR avec tolérance de 5%
      double actualRR = CalculateRR(isBuy, entryPrice, stopLoss, takeProfit);
      double tolerance = 0.05; // 5% de tolérance pour éviter rejets dus aux arrondis
      
      if(actualRR < m_params.minRR * (1.0 - tolerance)) {
         errorMsg = StringFormat("RR insuffisant: %.2f < %.2f (min avec tolérance)", 
                                actualRR, m_params.minRR);
         return false;
      }
      
      if(actualRR > m_params.maxRR) {
         // Ajuster le TP pour respecter le maxRR
         takeProfit = CalculateRRTakeProfit(entryPrice, stopLoss, m_params.maxRR, isBuy);
         Print("TP ajusté au RR max: 1:", m_params.maxRR);
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Calcul du Stop Loss selon la méthode choisie                    |
   //+------------------------------------------------------------------+
   double CalculateStopLoss(bool isBuy, double entryPrice) {
      double sl = 0;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      switch(m_params.slMethod) {
         case SL_ATR:
            sl = CalculateSL_ATR(isBuy, entryPrice);
            break;
            
         case SL_SWING:
            sl = CalculateSL_Swing(isBuy, entryPrice);
            break;
            
         case SL_FIXED_POINTS:
            if(isBuy)
               sl = entryPrice - m_params.slFixedPoints * point;
            else
               sl = entryPrice + m_params.slFixedPoints * point;
            break;
            
         case SL_PERCENT:
            if(isBuy)
               sl = entryPrice * (1 - m_params.slPercent / 100.0);
            else
               sl = entryPrice * (1 + m_params.slPercent / 100.0);
            break;
            
         case SL_BOLLINGER:
            sl = CalculateSL_Bollinger(isBuy);
            break;
            
         case SL_SUPPORT_RESISTANCE:
            sl = CalculateSL_SR(isBuy, entryPrice);
            break;
            
         case SL_ADAPTIVE:
            sl = CalculateSL_Adaptive(isBuy, entryPrice);
            break;
      }
      
      return NormalizeDouble(sl, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
   }
   
   //+------------------------------------------------------------------+
   //| SL basé sur ATR                                                  |
   //+------------------------------------------------------------------+
   double CalculateSL_ATR(bool isBuy, double entryPrice) {
      if(m_atrHandle == INVALID_HANDLE) {
         Print("Erreur: Handle ATR non initialisé. Appelez InitIndicators() dans OnInit()");
         return 0;
      }
      
      double atr[];
      ArraySetAsSeries(atr, true);
      
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) <= 0) {
         Print("Erreur CopyBuffer ATR");
         return 0;
      }
      
      double slDistance = atr[0] * m_params.slATRMultiplier;
      
      if(isBuy)
         return entryPrice - slDistance;
      else
         return entryPrice + slDistance;
   }
   
   //+------------------------------------------------------------------+
   //| SL basé sur Swing High/Low                                      |
   //+------------------------------------------------------------------+
   double CalculateSL_Swing(bool isBuy, double entryPrice) {
      double sl = 0;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      if(isBuy) {
         // Trouver le plus bas des N dernières barres
         sl = FindLowestLow(m_params.slSwingPeriod);
         sl -= 5 * point; // Petit buffer
      } else {
         // Trouver le plus haut des N dernières barres
         sl = FindHighestHigh(m_params.slSwingPeriod);
         sl += 5 * point; // Petit buffer
      }
      
      return sl;
   }
   
   //+------------------------------------------------------------------+
   //| SL basé sur Bollinger Band                                      |
   //+------------------------------------------------------------------+
   double CalculateSL_Bollinger(bool isBuy) {
      if(m_bbHandle == INVALID_HANDLE) {
         Print("Erreur: Handle BB non initialisé. Appelez InitIndicators() dans OnInit()");
         return 0;
      }
      
      double upper[], lower[];
      ArraySetAsSeries(upper, true);
      ArraySetAsSeries(lower, true);
      
      // CORRECTION: Copier 2 bougies pour utiliser l'index 1 (bougie fermée)
      if(CopyBuffer(m_bbHandle, 1, 0, 2, upper) < 2) {
         Print("Erreur CopyBuffer BB upper");
         return 0;
      }
      if(CopyBuffer(m_bbHandle, 2, 0, 2, lower) < 2) {
         Print("Erreur CopyBuffer BB lower");
         return 0;
      }
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // CORRECTION: Utiliser index 1 (bougie fermée) au lieu de 0 (bougie en cours)
      if(isBuy)
         return lower[1] - 5 * point;
      else
         return upper[1] + 5 * point;
   }
   
   //+------------------------------------------------------------------+
   //| SL basé sur Support/Résistance (simplifié)                      |
   //+------------------------------------------------------------------+
   double CalculateSL_SR(bool isBuy, double entryPrice) {
      // Implémentation simplifiée: utilise les fractales
      // Pour une version avancée, tu pourrais détecter les vrais S/R
      
      double sr = FindNearestSR(isBuy, entryPrice, 50);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      if(isBuy)
         return sr - 10 * point;
      else
         return sr + 10 * point;
   }
   
   //+------------------------------------------------------------------+
   //| SL Adaptatif Multi-Actifs (RECOMMANDÉ)                          |
   //+------------------------------------------------------------------+
   double CalculateSL_Adaptive(bool isBuy, double entryPrice) {
      if(m_adaptiveSL == NULL) {
         Print("Erreur: Système adaptatif non initialisé. Utilisez InitAdaptiveSL()");
         return 0;
      }
      
      // Appliquer le multiplicateur de volatilité si configuré
      if(m_params.slVolatilityMultiplier != 1.0) {
         m_adaptiveSL.AdjustForVolatility(m_params.slVolatilityMultiplier);
      }
      
      string reason = "";
      double sl = m_adaptiveSL.CalculateAdaptiveSL(isBuy, entryPrice, reason);
      
      if(sl > 0) {
         Print(StringFormat("SL Adaptatif calculé pour %s (%s): Entry=%.5f, SL=%.5f | %s",
                           m_symbol, m_adaptiveSL.GetAssetTypeName(), entryPrice, sl, reason));
      }
      
      return sl;
   }
   
   //+------------------------------------------------------------------+
   //| Calcul du Take Profit selon la méthode choisie                  |
   //+------------------------------------------------------------------+
   double CalculateTakeProfit(bool isBuy, double entryPrice, double stopLoss) {
      double tp = 0;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      switch(m_params.tpMethod) {
         case TP_RR_RATIO:
            tp = CalculateRRTakeProfit(entryPrice, stopLoss, m_params.tpRRRatio, isBuy);
            break;
            
         case TP_ATR:
            tp = CalculateTP_ATR(isBuy, entryPrice);
            break;
            
         case TP_SWING:
            tp = CalculateTP_Swing(isBuy, entryPrice);
            break;
            
         case TP_FIXED_POINTS:
            if(isBuy)
               tp = entryPrice + m_params.tpFixedPoints * point;
            else
               tp = entryPrice - m_params.tpFixedPoints * point;
            break;
            
         case TP_BOLLINGER:
            tp = CalculateTP_Bollinger(isBuy);
            break;
            
         case TP_FIBONACCI:
            tp = CalculateTP_Fibonacci(isBuy, entryPrice, stopLoss);
            break;
      }
      
      return NormalizeDouble(tp, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
   }
   
   //+------------------------------------------------------------------+
   //| TP basé sur le ratio RR                                         |
   //+------------------------------------------------------------------+
   double CalculateRRTakeProfit(double entryPrice, double stopLoss, double rrRatio, bool isBuy) {
      double risk = MathAbs(entryPrice - stopLoss);
      double reward = risk * rrRatio;
      
      if(isBuy)
         return entryPrice + reward;
      else
         return entryPrice - reward;
   }
   
   //+------------------------------------------------------------------+
   //| TP basé sur ATR                                                  |
   //+------------------------------------------------------------------+
   double CalculateTP_ATR(bool isBuy, double entryPrice) {
      if(m_atrHandle == INVALID_HANDLE) {
         Print("Erreur: Handle ATR non initialisé. Appelez InitIndicators() dans OnInit()");
         return 0;
      }
      
      double atr[];
      ArraySetAsSeries(atr, true);
      
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) <= 0) {
         Print("Erreur CopyBuffer ATR");
         return 0;
      }
      
      double tpDistance = atr[0] * m_params.tpATRMultiplier;
      
      if(isBuy)
         return entryPrice + tpDistance;
      else
         return entryPrice - tpDistance;
   }
   
   //+------------------------------------------------------------------+
   //| TP basé sur Swing                                               |
   //+------------------------------------------------------------------+
   double CalculateTP_Swing(bool isBuy, double entryPrice) {
      double tp = 0;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      if(isBuy) {
         tp = FindHighestHigh(m_params.tpSwingPeriod);
         tp += 5 * point;
      } else {
         tp = FindLowestLow(m_params.tpSwingPeriod);
         tp -= 5 * point;
      }
      
      return tp;
   }
   
   //+------------------------------------------------------------------+
   //| TP basé sur Bollinger                                           |
   //+------------------------------------------------------------------+
   double CalculateTP_Bollinger(bool isBuy) {
      if(m_bbHandle == INVALID_HANDLE) {
         Print("Erreur: Handle BB non initialisé. Appelez InitIndicators() dans OnInit()");
         return 0;
      }
      
      double upper[], lower[];
      ArraySetAsSeries(upper, true);
      ArraySetAsSeries(lower, true);
      
      // CORRECTION: Copier 2 bougies pour utiliser l'index 1 (bougie fermée)
      if(CopyBuffer(m_bbHandle, 1, 0, 2, upper) < 2) {
         Print("Erreur CopyBuffer BB upper");
         return 0;
      }
      if(CopyBuffer(m_bbHandle, 2, 0, 2, lower) < 2) {
         Print("Erreur CopyBuffer BB lower");
         return 0;
      }
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // CORRECTION: Utiliser index 1 (bougie fermée) au lieu de 0 (bougie en cours)
      if(isBuy)
         return upper[1] + 5 * point;
      else
         return lower[1] - 5 * point;
   }
   
   //+------------------------------------------------------------------+
   //| TP basé sur Fibonacci                                           |
   //+------------------------------------------------------------------+
   double CalculateTP_Fibonacci(bool isBuy, double entryPrice, double stopLoss) {
      double risk = MathAbs(entryPrice - stopLoss);
      
      // Extensions Fibonacci courantes : 1.618, 2.618
      double fibLevel = 1.618; // Extension Fib par défaut
      double reward = risk * fibLevel;
      
      if(isBuy)
         return entryPrice + reward;
      else
         return entryPrice - reward;
   }
   
   //+------------------------------------------------------------------+
   //| Validation du Stop Loss                                         |
   //+------------------------------------------------------------------+
   bool ValidateStopLoss(bool isBuy, double entryPrice, double stopLoss, string &errorMsg) {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double distance = MathAbs(entryPrice - stopLoss) / point;
      
      if(distance < m_params.minDistancePoints) {
         errorMsg = StringFormat("SL trop proche: %.0f pts < %d pts min", 
                                distance, m_params.minDistancePoints);
         return false;
      }
      
      if(distance > m_params.maxDistancePoints) {
         errorMsg = StringFormat("SL trop éloigné: %.0f pts > %d pts max", 
                                distance, m_params.maxDistancePoints);
         return false;
      }
      
      // Vérifier que le SL est dans la bonne direction
      if(isBuy && stopLoss >= entryPrice) {
         errorMsg = "SL invalide pour BUY (doit être < entry)";
         return false;
      }
      
      if(!isBuy && stopLoss <= entryPrice) {
         errorMsg = "SL invalide pour SELL (doit être > entry)";
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Calcul du ratio RR réel                                         |
   //+------------------------------------------------------------------+
   double CalculateRR(bool isBuy, double entry, double sl, double tp) {
      double risk = MathAbs(entry - sl);
      double reward = MathAbs(tp - entry);
      
      if(risk == 0) return 0;
      return reward / risk;
   }
   
   //+------------------------------------------------------------------+
   //| Gestion du Break-Even                                           |
   //+------------------------------------------------------------------+
   bool CheckBreakEven(ulong ticket, bool isBuy, double entryPrice, double currentSL, double &newSL) {
      if(!m_params.useBreakEven) return false;
      
      // Vérifier que la position existe encore
      if(!PositionSelectByTicket(ticket)) {
         return false;
      }
      
      // CORRECTION: Vérifier si BE déjà activé
      double ticketSL = PositionGetDouble(POSITION_SL);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double beLevel = entryPrice + (m_params.beOffsetPoints * point * (isBuy ? 1 : -1));
      
      // Normaliser le niveau BE pour comparaison
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      beLevel = NormalizeDouble(beLevel, digits);
      
      // Si SL déjà au niveau BE ou mieux, ne rien faire
      if(isBuy && ticketSL >= beLevel - point) return false;
      if(!isBuy && ticketSL <= beLevel + point && ticketSL > 0) return false;
      
      // Validation du currentSL
      if(currentSL <= 0) {
         currentSL = ticketSL;
         if(currentSL <= 0) return false;
      }
      
      double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      double risk = MathAbs(entryPrice - currentSL);
      if(risk <= 0) return false;
      
      double currentReward = isBuy ? (currentPrice - entryPrice) : 
                                     (entryPrice - currentPrice);
      
      if(currentReward <= 0) return false; // Pas encore en profit
      
      double currentRR = currentReward / risk;
      
      // Activer BE si le RR est atteint
      if(currentRR >= m_params.beActivationRR) {
         newSL = beLevel;
         
         // Vérifier que le nouveau SL est meilleur que le SL actuel
         if((isBuy && newSL > currentSL) || (!isBuy && newSL < currentSL)) {
            Print(StringFormat("BE activé: RR=%.2f >= %.2f, SL %.5f -> %.5f",
                              currentRR, m_params.beActivationRR, currentSL, newSL));
            return true; // Signaler qu'il faut modifier le SL
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Gestion du Trailing Stop                                        |
   //+------------------------------------------------------------------+
   bool CheckTrailingStop(ulong ticket, bool isBuy, double entryPrice, 
                          double currentSL, double &newSL) {
      if(!m_params.useTrailing) return false;
      
      // Validation du currentSL
      if(currentSL <= 0) return false;
      
      double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      double risk = MathAbs(entryPrice - currentSL);
      double currentReward = isBuy ? (currentPrice - entryPrice) : 
                                     (entryPrice - currentPrice);
      
      double currentRR = (risk > 0) ? (currentReward / risk) : 0;
      
      // Activer trailing si le RR est atteint
      if(currentRR < m_params.trailingStartRR) return false;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double trailDistance = m_params.trailingStopPoints * point;
      
      if(isBuy) {
         newSL = currentPrice - trailDistance;
         if(newSL > currentSL + m_params.trailingStepPoints * point) {
            return true;
         }
      } else {
         newSL = currentPrice + trailDistance;
         if(newSL < currentSL - m_params.trailingStepPoints * point) {
            return true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Calcul du volume basé sur le risque                             |
   //+------------------------------------------------------------------+
   double CalculateVolume(double riskPercent, double stopLossPoints) {
      if(stopLossPoints <= 0.0) return 0.01;
      
   double balance = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = balance * (riskPercent / 100.0);
   
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
   double ticksPerPoint = point / tickSize;
   if(ticksPerPoint <= 0) ticksPerPoint = 1.0;
   
   double valuePerPointPerLot = tickValue * ticksPerPoint;
   double stopLossValuePerLot = stopLossPoints * valuePerPointPerLot;
   
   double volume = 0.0;
   if(stopLossValuePerLot > 0.0) {
      volume = riskAmount / stopLossValuePerLot;
   }
   
      return NormalizeVolume(m_symbol, volume);
   }
   
   //+------------------------------------------------------------------+
   //| Fonctions utilitaires privées                                   |
   //+------------------------------------------------------------------+
private:
   double FindLowestLow(int period) {
      double low[];
      ArraySetAsSeries(low, true);
      
      if(CopyLow(m_symbol, m_timeframe, 1, period, low) <= 0) return 0;
      
      return low[ArrayMinimum(low)];
   }
   
   double FindHighestHigh(int period) {
      double high[];
      ArraySetAsSeries(high, true);
      
      if(CopyHigh(m_symbol, m_timeframe, 1, period, high) <= 0) return 0;
      
      return high[ArrayMaximum(high)];
   }
   
   double FindNearestSR(bool isBuy, double entryPrice, int lookback) {
      // Implémentation simplifiée: cherche un niveau pivot
      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);
      
      if(CopyHigh(m_symbol, m_timeframe, 1, lookback, highs) <= 0) {
         Print("Erreur CopyHigh dans FindNearestSR");
         return 0;
      }
      if(CopyLow(m_symbol, m_timeframe, 1, lookback, lows) <= 0) {
         Print("Erreur CopyLow dans FindNearestSR");
         return 0;
      }
      
      // Pour BUY, chercher le dernier low significatif
   if(isBuy) {
         for(int i = 2; i < lookback - 2; i++) {
            if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
               lows[i] < lows[i+1] && lows[i] < lows[i+2]) {
               return lows[i];
            }
         }
         return lows[ArrayMinimum(lows)];
   } else {
         // Pour SELL, chercher le dernier high significatif
         for(int i = 2; i < lookback - 2; i++) {
            if(highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
               highs[i] > highs[i+1] && highs[i] > highs[i+2]) {
               return highs[i];
            }
         }
         return highs[ArrayMaximum(highs)];
      }
   }
   
   double NormalizeVolume(string symbol, double volume) {
      double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      volume = MathMax(minVolume, MathMin(maxVolume, volume));
      volume = MathFloor(volume / stepVolume) * stepVolume;
      
      int digits = GetVolumeDigits(symbol);
      return NormalizeDouble(volume, digits);
   }
   
   int GetVolumeDigits(string symbol) {
      double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) return 2;
      
      int digits = 0;
      double s = step;
      while(digits < 8) {
         double rounded = MathRound(s);
         if(MathAbs(s - rounded) <= 1e-9) break;
         s *= 10.0;
         digits++;
      }
      
      return digits;
   }
};
