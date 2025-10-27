//+------------------------------------------------------------------+
//|                                        EntryRulesValidator.mqh   |
//|                                    Validateur Règles d'Entrée    |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Entry Rules Validator Class                                      |
//+------------------------------------------------------------------+
class CEntryRulesValidator
{
private:
   int m_minSpreadPoints;     // Spread minimum acceptable
   int m_maxSpreadPoints;     // Spread maximum acceptable
   double m_minVolumeRatio;   // Volume minimum par rapport à la moyenne
   int m_volumePeriods;       // Périodes pour calculer volume moyen

public:
   //--- Constructor
   CEntryRulesValidator()
   {
      m_minSpreadPoints = 0;
      m_maxSpreadPoints = 50;  // 5 pips max pour la plupart des brokers
      m_minVolumeRatio = 0.5;  // Volume minimum 50% de la moyenne
      m_volumePeriods = 20;    // 20 périodes pour calculer volume moyen
      
      Logger::Debug("Entry Rules Validator initialized");
   }
   
   //--- Destructor
   ~CEntryRulesValidator()
   {
      Logger::Debug("Entry Rules Validator destroyed");
   }
   
   //--- Valider entrée BUY et calculer SL
   bool ValidateBuyEntry(string symbol, ENUM_TIMEFRAMES tf, 
                         int barsLookback, double &slPrice)
   {
      Logger::Debug("Validating BUY entry for " + symbol);
      
      // 1. Vérifier les conditions de base
      if(!ValidateBasicConditions(symbol))
         return false;
      
      // 2. Trouver le plus bas des N dernières barres pour SL
      if(!FindLowestPrice(symbol, tf, barsLookback, slPrice))
         return false;
      
      // 3. Vérifier que le SL est raisonnable
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double slDistance = currentPrice - slPrice;
      double slPoints = slDistance / SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(slPoints < 10) // SL trop proche
      {
         Logger::Warning("SL too close for BUY: " + DoubleToString(slPoints, 0) + " points");
         return false;
      }
      
      if(slPoints > 500) // SL trop éloigné
      {
         Logger::Warning("SL too far for BUY: " + DoubleToString(slPoints, 0) + " points");
         //return false;
      }
      
      Logger::Debug("BUY entry validated - SL: " + DoubleToString(slPrice, 5) + 
                    " (" + DoubleToString(slPoints, 0) + " points)");
      
      return true;
   }
   
   //--- Valider entrée SELL et calculer SL
   bool ValidateSellEntry(string symbol, ENUM_TIMEFRAMES tf, 
                          int barsLookback, double &slPrice)
   {
      Logger::Debug("Validating SELL entry for " + symbol);
      
      // 1. Vérifier les conditions de base
      if(!ValidateBasicConditions(symbol))
         return false;
      
      // 2. Trouver le plus haut des N dernières barres pour SL
      if(!FindHighestPrice(symbol, tf, barsLookback, slPrice))
         return false;
      
      // 3. Vérifier que le SL est raisonnable
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      double slDistance = slPrice - currentPrice;
      double slPoints = slDistance / SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(slPoints < 10) // SL trop proche
      {
         Logger::Warning("SL too close for SELL: " + DoubleToString(slPoints, 0) + " points");
         return false;
      }
      
      if(slPoints > 500) // SL trop éloigné
      {
         Logger::Warning("SL too far for SELL: " + DoubleToString(slPoints, 0) + " points");
         return false;
      }
      
      Logger::Debug("SELL entry validated - SL: " + DoubleToString(slPrice, 5) + 
                    " (" + DoubleToString(slPoints, 0) + " points)");
      
      return true;
   }
   
   //--- Trouver le plus bas prix pour SL BUY
   bool FindLowestPrice(string symbol, ENUM_TIMEFRAMES tf, 
                        int barsLookback, double &lowestPrice)
   {
      double low[];
      ArraySetAsSeries(low, true);
      
      if(CopyLow(symbol, tf, 0, barsLookback, low) <= 0)
      {
         Logger::Error("Failed to copy low prices for " + symbol);
         return false;
      }
      
      int minIndex = ArrayMinimum(low);
      if(minIndex < 0)
      {
         Logger::Error("Failed to find minimum low price");
         return false;
      }
      
      lowestPrice = low[minIndex];
      
      // Ajouter un petit buffer pour éviter les SL trop serrés
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      lowestPrice -= (point * 2); // 2 points de buffer
      
      Logger::Debug("Lowest price found: " + DoubleToString(lowestPrice, 5) + 
                    " (bar " + IntegerToString(minIndex) + ")");
      
      return true;
   }
   
   //--- Trouver le plus haut prix pour SL SELL
   bool FindHighestPrice(string symbol, ENUM_TIMEFRAMES tf, 
                         int barsLookback, double &highestPrice)
   {
      double high[];
      ArraySetAsSeries(high, true);
      
      if(CopyHigh(symbol, tf, 0, barsLookback, high) <= 0)
      {
         Logger::Error("Failed to copy high prices for " + symbol);
         return false;
      }
      
      int maxIndex = ArrayMaximum(high);
      if(maxIndex < 0)
      {
         Logger::Error("Failed to find maximum high price");
         return false;
      }
      
      highestPrice = high[maxIndex];
      
      // Ajouter un petit buffer pour éviter les SL trop serrés
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      highestPrice += (point * 2); // 2 points de buffer
      
      Logger::Debug("Highest price found: " + DoubleToString(highestPrice, 5) + 
                    " (bar " + IntegerToString(maxIndex) + ")");
      
      return true;
   }
   
   //--- Valider les conditions de base
   bool ValidateBasicConditions(string symbol)
   {
      // 1. Vérifier que le symbole est tradable
      if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE))
      {
         Logger::Error("Symbol " + symbol + " is not tradeable");
         return false;
      }
      
      // 2. Vérifier le spread
      double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      if(spread < m_minSpreadPoints || spread > m_maxSpreadPoints)
      {
         Logger::Warning("Spread out of range for " + symbol + ": " + 
                        DoubleToString(spread, 0) + " points");
         // Ne pas bloquer, juste avertir
      }
      
      // 3. Vérifier le volume (si disponible)
      if(!ValidateVolume(symbol))
      {
         Logger::Warning("Volume validation failed for " + symbol);
         // Ne pas bloquer, juste avertir
      }
      
      // 4. Vérifier les heures de trading
      if(!IsTradingTime(symbol))
      {
         Logger::Warning("Outside trading hours for " + symbol);
         return false;
      }
      
      return true;
   }
   
   //--- Valider le volume
   bool ValidateVolume(string symbol)
   {
      long currentVolume = SymbolInfoInteger(symbol, SYMBOL_VOLUME);
      if(currentVolume <= 0)
      {
         Logger::Debug("No volume data available for " + symbol);
         return true; // Pas de données volume, ne pas bloquer
      }
      
      // Calculer volume moyen des dernières périodes
      long volumes[];
      ArraySetAsSeries(volumes, true);
      
      if(CopyTickVolume(symbol, PERIOD_CURRENT, 0, m_volumePeriods, volumes) <= 0)
      {
         Logger::Debug("Failed to get volume history for " + symbol);
         return true; // Pas de données historiques, ne pas bloquer
      }
      
      long avgVolume = 0;
      for(int i = 0; i < ArraySize(volumes); i++)
      {
         avgVolume += volumes[i];
      }
      avgVolume /= ArraySize(volumes);
      
      double volumeRatio = (double)currentVolume / (double)avgVolume;
      
      if(volumeRatio < m_minVolumeRatio)
      {
         Logger::Debug("Low volume for " + symbol + ": " + 
                       DoubleToString(volumeRatio, 2) + "x average");
         return false;
      }
      
      Logger::Debug("Volume OK for " + symbol + ": " + 
                   DoubleToString(volumeRatio, 2) + "x average");
      
      return true;
   }
   
   //--- Vérifier les heures de trading
   bool IsTradingTime(string symbol)
   {
      // Vérifier si le symbole est dans ses heures de trading
      datetime currentTime = TimeCurrent();
      MqlDateTime timeStruct;
      TimeToStruct(currentTime, timeStruct);
      
      // Exemple simple : éviter les heures de faible liquidité (22h-02h GMT)
      int hour = timeStruct.hour;
      if(hour >= 22 || hour <= 2)
      {
         Logger::Debug("Low liquidity period: " + IntegerToString(hour) + ":00 GMT");
         return false;
      }
      
      return true;
   }
   
   //--- Calculer la distance SL en points
   double CalculateSLDistance(string symbol, double entryPrice, double slPrice, bool isBuy)
   {
      double distance;
      if(isBuy)
         distance = entryPrice - slPrice;
      else
         distance = slPrice - entryPrice;
      
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      return distance / point;
   }
   
   //--- Obtenir informations de validation
   string GetValidationInfo(string symbol)
   {
      string info = "=== ENTRY VALIDATION INFO ===\n";
      info += "Symbol: " + symbol + "\n";
      
      double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      info += "Spread: " + DoubleToString(spread, 0) + " points\n";
      
      long volume = SymbolInfoInteger(symbol, SYMBOL_VOLUME);
      info += "Volume: " + IntegerToString(volume) + "\n";
      
      bool tradeable = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
      info += "Tradeable: " + (tradeable ? "YES" : "NO") + "\n";
      
      bool tradingTime = IsTradingTime(symbol);
      info += "Trading Time: " + (tradingTime ? "YES" : "NO") + "\n";
      
      info += "================================";
      
      return info;
   }
   
   //--- Modifier les paramètres de validation
   void SetSpreadLimits(int minSpread, int maxSpread)
   {
      m_minSpreadPoints = minSpread;
      m_maxSpreadPoints = maxSpread;
      Logger::Info("Spread limits updated: " + IntegerToString(minSpread) + 
                   "-" + IntegerToString(maxSpread) + " points");
   }
   
   void SetVolumeSettings(double minRatio, int periods)
   {
      m_minVolumeRatio = minRatio;
      m_volumePeriods = periods;
      Logger::Info("Volume settings updated: min=" + DoubleToString(minRatio, 2) + 
                   "x, periods=" + IntegerToString(periods));
   }
};
