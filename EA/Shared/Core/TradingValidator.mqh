//+------------------------------------------------------------------+
//|                                          TradingValidator.mqh     |
//|                    Validateur de trading et contraintes broker   |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../Logger.mqh"

//+------------------------------------------------------------------+
//| Classe TradingValidator - Validation des ordres et contraintes   |
//+------------------------------------------------------------------+
class TradingValidator
{
private:
   string            m_symbol;              // Symbole à valider
   double            m_point;               // Point du symbole
   double            m_minDistance;         // Distance minimum entre ordres
   double            m_maxDistance;         // Distance maximum entre ordres
   int               m_slippagePoints;      // Tolérance de slippage
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TradingValidator(string symbol, int minDistancePoints = 10, int maxDistancePoints = 1000, int slippagePoints = 3)
   {
      m_symbol = symbol;
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_minDistance = minDistancePoints * m_point;
      m_maxDistance = maxDistancePoints * m_point;
      m_slippagePoints = slippagePoints;
      
      Logger::Debug("TradingValidator initialized for " + symbol + 
                   " | Min dist: " + IntegerToString(minDistancePoints) + " pts" +
                   " | Max dist: " + IntegerToString(maxDistancePoints) + " pts" +
                   " | Slippage: " + IntegerToString(slippagePoints) + " pts");
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~TradingValidator()
   {
      Logger::Debug("TradingValidator destroyed for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Valider un prix d'entrée pour un ordre                          |
   //| @return true si valide, false sinon                             |
   //+------------------------------------------------------------------+
   bool ValidateEntryPrice(double entryPrice, ENUM_ORDER_TYPE orderType, string &errorMessage)
   {
      errorMessage = "";
      
      double currentPrice = 0;
      
      // FIXED: Séparer la logique pour BUY_STOP vs BUY_LIMIT et SELL_STOP vs SELL_LIMIT
      switch(orderType)
      {
         case ORDER_TYPE_BUY_STOP:
            // BUY_STOP: prix d'entrée DOIT être au-dessus du prix actuel (breakout haussier)
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            if(entryPrice <= currentPrice + m_minDistance)
            {
               errorMessage = StringFormat("BUY_STOP price %.5f must be above current price %.5f by at least %.5f", 
                                         entryPrice, currentPrice, m_minDistance);
               return false;
            }
            if(entryPrice > currentPrice + m_maxDistance)
            {
               errorMessage = StringFormat("BUY_STOP price %.5f exceeds max distance from current price %.5f", 
                                         entryPrice, currentPrice);
               return false;
            }
            break;
            
         case ORDER_TYPE_BUY_LIMIT:
            // BUY_LIMIT: prix d'entrée DOIT être en-dessous du prix actuel (pullback haussier)
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            if(entryPrice >= currentPrice - m_minDistance)
            {
               errorMessage = StringFormat("BUY_LIMIT price %.5f must be below current price %.5f by at least %.5f", 
                                         entryPrice, currentPrice, m_minDistance);
               return false;
            }
            if(entryPrice < currentPrice - m_maxDistance)
            {
               errorMessage = StringFormat("BUY_LIMIT price %.5f exceeds max distance from current price %.5f", 
                                         entryPrice, currentPrice);
               return false;
            }
            break;
            
         case ORDER_TYPE_SELL_STOP:
            // SELL_STOP: prix d'entrée DOIT être en-dessous du prix actuel (breakout baissier)
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            if(entryPrice >= currentPrice - m_minDistance)
            {
               errorMessage = StringFormat("SELL_STOP price %.5f must be below current price %.5f by at least %.5f", 
                                         entryPrice, currentPrice, m_minDistance);
               return false;
            }
            if(entryPrice < currentPrice - m_maxDistance)
            {
               errorMessage = StringFormat("SELL_STOP price %.5f exceeds max distance from current price %.5f", 
                                         entryPrice, currentPrice);
               return false;
            }
            break;
            
         case ORDER_TYPE_SELL_LIMIT:
            // SELL_LIMIT: prix d'entrée DOIT être au-dessus du prix actuel (pullback baissier)
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            if(entryPrice <= currentPrice + m_minDistance)
            {
               errorMessage = StringFormat("SELL_LIMIT price %.5f must be above current price %.5f by at least %.5f", 
                                         entryPrice, currentPrice, m_minDistance);
               return false;
            }
            if(entryPrice > currentPrice + m_maxDistance)
            {
               errorMessage = StringFormat("SELL_LIMIT price %.5f exceeds max distance from current price %.5f", 
                                         entryPrice, currentPrice);
               return false;
            }
            break;
            
         default:
            errorMessage = "Invalid order type for validation";
            return false;
      }
      
      // Vérifier les contraintes du symbole
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize > 0)
      {
         double remainder = MathMod(entryPrice, tickSize);
         if(remainder > 0.0001) // Tolérance pour les erreurs de précision
         {
            errorMessage = StringFormat("Entry price %.5f is not aligned with tick size %.5f", 
                                      entryPrice, tickSize);
            return false;
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Valider un Stop Loss                                            |
   //| @return true si SL valide ou optionnel (0), false si invalide   |
   //+------------------------------------------------------------------+
   bool ValidateStopLoss(double entryPrice, double slPrice, ENUM_ORDER_TYPE orderType, string &errorMessage)
   {
      errorMessage = "";
      
      if(slPrice <= 0) return true; // SL optionnel
      
      double minSLDistance = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
      if(minSLDistance <= 0) minSLDistance = 10 * m_point; // Fallback
      
      bool isValid = false;
      
      switch(orderType)
      {
         case ORDER_TYPE_BUY_STOP:
         case ORDER_TYPE_BUY_LIMIT:
            // Pour les ordres BUY, SL doit être en dessous du prix d'entrée
            isValid = (slPrice < entryPrice - minSLDistance);
            if(!isValid)
               errorMessage = StringFormat("SL %.5f must be below entry %.5f by at least %.5f", 
                                         slPrice, entryPrice, minSLDistance);
            break;
            
         case ORDER_TYPE_SELL_STOP:
         case ORDER_TYPE_SELL_LIMIT:
            // Pour les ordres SELL, SL doit être au-dessus du prix d'entrée
            isValid = (slPrice > entryPrice + minSLDistance);
            if(!isValid)
               errorMessage = StringFormat("SL %.5f must be above entry %.5f by at least %.5f", 
                                         slPrice, entryPrice, minSLDistance);
            break;
            
         default:
            errorMessage = "Invalid order type for SL validation";
            return false;
      }
      
      return isValid;
   }
   
   //+------------------------------------------------------------------+
   //| Valider un Take Profit                                          |
   //| @return true si TP valide ou optionnel (0), false si invalide   |
   //+------------------------------------------------------------------+
   bool ValidateTakeProfit(double entryPrice, double tpPrice, ENUM_ORDER_TYPE orderType, string &errorMessage)
   {
      errorMessage = "";
      
      if(tpPrice <= 0) return true; // TP optionnel
      
      double minTPDistance = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
      if(minTPDistance <= 0) minTPDistance = 10 * m_point; // Fallback
      
      bool isValid = false;
      
      switch(orderType)
      {
         case ORDER_TYPE_BUY_STOP:
         case ORDER_TYPE_BUY_LIMIT:
            // Pour les ordres BUY, TP doit être au-dessus du prix d'entrée
            isValid = (tpPrice > entryPrice + minTPDistance);
            if(!isValid)
               errorMessage = StringFormat("TP %.5f must be above entry %.5f by at least %.5f", 
                                         tpPrice, entryPrice, minTPDistance);
            break;
            
         case ORDER_TYPE_SELL_STOP:
         case ORDER_TYPE_SELL_LIMIT:
            // Pour les ordres SELL, TP doit être en dessous du prix d'entrée
            isValid = (tpPrice < entryPrice - minTPDistance);
            if(!isValid)
               errorMessage = StringFormat("TP %.5f must be below entry %.5f by at least %.5f", 
                                         tpPrice, entryPrice, minTPDistance);
            break;
            
         default:
            errorMessage = "Invalid order type for TP validation";
            return false;
      }
      
      return isValid;
   }
   
   //+------------------------------------------------------------------+
   //| Valider un ordre complet                                        |
   //| @return true si tous les paramètres sont valides, false sinon   |
   //+------------------------------------------------------------------+
   bool ValidateOrder(double entryPrice, double slPrice, double tpPrice, ENUM_ORDER_TYPE orderType, string &errorMessage)
   {
      errorMessage = "";
      
      // Valider le prix d'entrée
      if(!ValidateEntryPrice(entryPrice, orderType, errorMessage))
         return false;
      
      // Valider le Stop Loss
      if(!ValidateStopLoss(entryPrice, slPrice, orderType, errorMessage))
         return false;
      
      // Valider le Take Profit
      if(!ValidateTakeProfit(entryPrice, tpPrice, orderType, errorMessage))
         return false;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si le trading est autorisé sur ce symbole              |
   //| @return true si le trading est autorisé, false sinon            |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed(string &errorMessage)
   {
      errorMessage = "";
      
      // Vérifier si le symbole est visible
      if(!SymbolSelect(m_symbol, true))
      {
         errorMessage = "Symbol " + m_symbol + " is not visible in Market Watch";
         return false;
      }
      
      // Vérifier si le trading est autorisé
      if(!SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE))
      {
         errorMessage = "Trading is not allowed for " + m_symbol;
         return false;
      }
      
      // Vérifier les heures de trading
      datetime currentTime = TimeCurrent();
      long tradeMode = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
      if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
      {
         errorMessage = "Trading is not allowed at current time for " + m_symbol;
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier les contraintes de volume                              |
   //| @return true si le volume respecte les contraintes broker       |
   //+------------------------------------------------------------------+
   bool ValidateVolume(double volume, string &errorMessage)
   {
      errorMessage = "";
      
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      double volumeLimit = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_LIMIT);
      
      // Vérifier les limites
      if(volume < minLot)
      {
         errorMessage = StringFormat("Volume %.2f is below minimum %.2f", volume, minLot);
         return false;
      }
      
      if(maxLot > 0 && volume > maxLot)
      {
         errorMessage = StringFormat("Volume %.2f exceeds maximum %.2f", volume, maxLot);
         return false;
      }
      
      if(volumeLimit > 0 && volume > volumeLimit)
      {
         errorMessage = StringFormat("Volume %.2f exceeds limit %.2f", volume, volumeLimit);
         return false;
      }
      
      // Vérifier le pas de lot avec une méthode plus robuste
      if(lotStep > 0)
      {
         // Calculer le nombre de steps
         double steps = MathRound(volume / lotStep);
         double expectedVolume = steps * lotStep;
         double difference = MathAbs(volume - expectedVolume);
         
         // Tolérance basée sur la précision du lot step
         double tolerance = lotStep * 0.01; // 1% du lot step
         if(tolerance < 0.00001) tolerance = 0.00001; // Minimum 0.00001
         
         // ✅ OPTIMISATION: Logs détaillés seulement si LOG_DEBUG actif
         if(Logger::GetLevel() == LOG_DEBUG)
         {
            Logger::Debug("🔍 TradingValidator::ValidateVolume - Vérification lot step:");
            Logger::Debug("  - Volume: " + DoubleToString(volume, 5));
            Logger::Debug("  - Lot Step: " + DoubleToString(lotStep, 5));
            Logger::Debug("  - Steps calculés: " + DoubleToString(steps, 2));
            Logger::Debug("  - Volume attendu: " + DoubleToString(expectedVolume, 5));
            Logger::Debug("  - Différence: " + DoubleToString(difference, 5));
            Logger::Debug("  - Tolérance: " + DoubleToString(tolerance, 5));
         }
         
         if(difference > tolerance)
         {
            errorMessage = StringFormat("Volume %.2f is not aligned with lot step %.2f", volume, lotStep);
            Logger::Error("❌ Volume validation failed: " + errorMessage);
            return false;
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de validation                          |
   //+------------------------------------------------------------------+
   string GetValidationInfo()
   {
      string info = "Validation info for " + m_symbol + ": ";
      info += "Min dist: " + DoubleToString(m_minDistance / m_point, 0) + " pts, ";
      info += "Max dist: " + DoubleToString(m_maxDistance / m_point, 0) + " pts, ";
      info += "Slippage: " + IntegerToString(m_slippagePoints) + " pts";
      
      return info;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les distances de validation                       |
   //+------------------------------------------------------------------+
   void UpdateDistances(int minDistancePoints, int maxDistancePoints)
   {
      m_minDistance = minDistancePoints * m_point;
      m_maxDistance = maxDistancePoints * m_point;
      
      Logger::Debug("Updated validation distances: " + IntegerToString(minDistancePoints) + 
                   " - " + IntegerToString(maxDistancePoints) + " points");
   }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation                                             |
//+------------------------------------------------------------------+
/*
// Création du validateur
TradingValidator* validator = new TradingValidator("EURUSD", 10, 1000, 3);

// Validation d'un ordre
string errorMsg;
bool isValid = validator.ValidateOrder(1.1000, 1.0950, 1.1100, ORDER_TYPE_BUY_STOP, errorMsg);

if(!isValid)
{
   Print("Order validation failed: " + errorMsg);
}

// Validation du trading
if(!validator.IsTradingAllowed(errorMsg))
{
   Print("Trading not allowed: " + errorMsg);
}

// Nettoyage
delete validator;
*/
