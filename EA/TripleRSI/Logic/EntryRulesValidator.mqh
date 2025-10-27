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
   
   //--- Valider entrée BUY
   bool ValidateBuyEntry(string symbol, ENUM_TIMEFRAMES tf, int barsLookback)
   {
      Logger::Debug("Validating BUY entry for " + symbol);
      
      // Vérifier les conditions de base uniquement
      if(!ValidateBasicConditions(symbol))
         return false;
      
      Logger::Debug("BUY entry validated");
      return true;
   }
   
   //--- Valider entrée SELL
   bool ValidateSellEntry(string symbol, ENUM_TIMEFRAMES tf, int barsLookback)
   {
      Logger::Debug("Validating SELL entry for " + symbol);
      
      // Vérifier les conditions de base uniquement
      if(!ValidateBasicConditions(symbol))
         return false;
      
      Logger::Debug("SELL entry validated");
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
