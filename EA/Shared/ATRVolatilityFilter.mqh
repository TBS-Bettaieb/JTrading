//+------------------------------------------------------------------+
//|                                          ATRVolatilityFilter.mqh |
//|                    Filtre de volatilité basé sur comparaison ATR |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Classe de filtre de volatilité ATR                              |
//| Compare ATR court terme vs long terme pour détecter expansion   |
//+------------------------------------------------------------------+
class CATRVolatilityFilter
{
private:
   // Configuration
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_atrShortPeriod;     // Période ATR court terme (ex: 14)
   int               m_atrLongPeriod;      // Période ATR long terme (ex: 50)
   
   // Handles des indicateurs
   int               m_atrShortHandle;     // Handle ATR court terme
   int               m_atrLongHandle;      // Handle ATR long terme
   
   // Cache pour optimisation
   double            m_cachedATRShort;
   double            m_cachedATRLong;
   datetime          m_lastUpdateTime;
   
   // Statistiques
   int               m_expansionCount;
   int               m_totalChecks;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CATRVolatilityFilter()
   {
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      m_atrShortPeriod = 14;
      m_atrLongPeriod = 50;
      
      m_atrShortHandle = INVALID_HANDLE;
      m_atrLongHandle = INVALID_HANDLE;
      
      m_cachedATRShort = 0.0;
      m_cachedATRLong = 0.0;
      m_lastUpdateTime = 0;
      
      m_expansionCount = 0;
      m_totalChecks = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CATRVolatilityFilter()
   {
      Deinitialize();
   }
   
   //+------------------------------------------------------------------+
   //| Initialiser le filtre ATR                                       |
   //+------------------------------------------------------------------+
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, 
                   int atrShortPeriod = 14, int atrLongPeriod = 50)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_atrShortPeriod = MathMax(1, atrShortPeriod);
      m_atrLongPeriod = MathMax(m_atrShortPeriod + 1, atrLongPeriod);
      
      // Créer les handles ATR
      m_atrShortHandle = iATR(m_symbol, m_timeframe, m_atrShortPeriod);
      m_atrLongHandle = iATR(m_symbol, m_timeframe, m_atrLongPeriod);
      
      if(m_atrShortHandle == INVALID_HANDLE)
      {
         Logger::Error("Failed to create ATR Short handle for " + m_symbol + 
                      " (period: " + IntegerToString(m_atrShortPeriod) + ")");
         return false;
      }
      
      if(m_atrLongHandle == INVALID_HANDLE)
      {
         Logger::Error("Failed to create ATR Long handle for " + m_symbol + 
                      " (period: " + IntegerToString(m_atrLongPeriod) + ")");
         IndicatorRelease(m_atrShortHandle);
         m_atrShortHandle = INVALID_HANDLE;
         return false;
      }
      
      Logger::Success("✅ ATR Volatility Filter initialized for " + m_symbol);
      Logger::Info("   ATR Short: " + IntegerToString(m_atrShortPeriod) + " periods");
      Logger::Info("   ATR Long: " + IntegerToString(m_atrLongPeriod) + " periods");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Libérer les ressources                                          |
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_atrShortHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrShortHandle);
         m_atrShortHandle = INVALID_HANDLE;
      }
      
      if(m_atrLongHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrLongHandle);
         m_atrLongHandle = INVALID_HANDLE;
      }
      
      Logger::Debug("ATR Volatility Filter deinitialized for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si expansion de volatilité                             |
   //| Retourne true si ATR_Current > ATR_Baseline × multiplier        |
   //+------------------------------------------------------------------+
   bool IsVolatilityExpansion(double multiplier = 1.3)
   {
      m_totalChecks++;
      
      // Mettre à jour le cache si nécessaire
      if(!UpdateCache())
      {
         Logger::Warning("Failed to update ATR cache for volatility check");
         return false;
      }
      
      // Vérifier que les valeurs sont valides
      if(m_cachedATRShort <= 0 || m_cachedATRLong <= 0)
      {
         Logger::Warning("Invalid ATR values (Short: " + DoubleToString(m_cachedATRShort, 5) + 
                        ", Long: " + DoubleToString(m_cachedATRLong, 5) + ")");
         return false;
      }
      
      // Calculer le ratio
      double ratio = m_cachedATRShort / m_cachedATRLong;
      double threshold = multiplier;
      
      // Vérifier l'expansion
      bool isExpansion = (ratio >= threshold);
      
      if(isExpansion)
      {
         m_expansionCount++;
      }
      
      // Log détaillé (anti-spam avec vérification par barre)
      static datetime lastLogTime = 0;
      datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
      
      if(currentBarTime != lastLogTime)
      {
         if(isExpansion)
         {
            Logger::Info("✅ VOLATILITY EXPANSION | ATR(" + IntegerToString(m_atrShortPeriod) + "): " + 
                        DoubleToString(m_cachedATRShort, 5) + " | ATR(" + IntegerToString(m_atrLongPeriod) + 
                        "): " + DoubleToString(m_cachedATRLong, 5) + " | Ratio: " + 
                        DoubleToString(ratio, 2) + " (>= " + DoubleToString(threshold, 2) + ")");
         }
         else
         {
            Logger::Debug("❌ NO EXPANSION | ATR(" + IntegerToString(m_atrShortPeriod) + "): " + 
                         DoubleToString(m_cachedATRShort, 5) + " | ATR(" + IntegerToString(m_atrLongPeriod) + 
                         "): " + DoubleToString(m_cachedATRLong, 5) + " | Ratio: " + 
                         DoubleToString(ratio, 2) + " (< " + DoubleToString(threshold, 2) + ")");
         }
         lastLogTime = currentBarTime;
      }
      
      return isExpansion;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la valeur ATR court terme (current)                     |
   //+------------------------------------------------------------------+
   double GetCurrentATR()
   {
      UpdateCache();
      return m_cachedATRShort;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la valeur ATR long terme (baseline)                     |
   //+------------------------------------------------------------------+
   double GetBaselineATR()
   {
      UpdateCache();
      return m_cachedATRLong;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le ratio de volatilité actuel                           |
   //+------------------------------------------------------------------+
   double GetVolatilityRatio()
   {
      UpdateCache();
      
      if(m_cachedATRLong <= 0)
         return 0.0;
      
      return m_cachedATRShort / m_cachedATRLong;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les statistiques                                        |
   //+------------------------------------------------------------------+
   string GetStatistics() const
   {
      string stats = "=== ATR VOLATILITY FILTER STATISTICS ===\n";
      stats += "Symbol: " + m_symbol + "\n";
      stats += "Timeframe: " + EnumToString(m_timeframe) + "\n";
      stats += "ATR Short Period: " + IntegerToString(m_atrShortPeriod) + "\n";
      stats += "ATR Long Period: " + IntegerToString(m_atrLongPeriod) + "\n";
      stats += "Current ATR: " + DoubleToString(m_cachedATRShort, 5) + "\n";
      stats += "Baseline ATR: " + DoubleToString(m_cachedATRLong, 5) + "\n";
      stats += "Ratio: " + DoubleToString(GetVolatilityRatioConst(), 2) + "\n";
      stats += "Total Checks: " + IntegerToString(m_totalChecks) + "\n";
      stats += "Expansions: " + IntegerToString(m_expansionCount) + "\n";
      
      if(m_totalChecks > 0)
      {
         double expansionRate = (double)m_expansionCount / (double)m_totalChecks * 100.0;
         stats += "Expansion Rate: " + DoubleToString(expansionRate, 1) + "%\n";
      }
      
      stats += "========================================";
      
      return stats;
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si le filtre est initialisé                            |
   //+------------------------------------------------------------------+
   bool IsInitialized() const
   {
      return (m_atrShortHandle != INVALID_HANDLE && m_atrLongHandle != INVALID_HANDLE);
   }

private:
   //+------------------------------------------------------------------+
   //| Mettre à jour le cache des valeurs ATR                          |
   //+------------------------------------------------------------------+
   bool UpdateCache()
   {
      // Vérifier si déjà à jour pour cette barre
      datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
      if(m_lastUpdateTime == currentBarTime && m_cachedATRShort > 0 && m_cachedATRLong > 0)
      {
         return true; // Cache encore valide
      }
      
      // Récupérer les valeurs ATR
      double atrShort[];
      double atrLong[];
      ArraySetAsSeries(atrShort, true);
      ArraySetAsSeries(atrLong, true);
      
      if(CopyBuffer(m_atrShortHandle, 0, 0, 1, atrShort) <= 0)
      {
         Logger::Error("Failed to copy ATR Short buffer for " + m_symbol);
         return false;
      }
      
      if(CopyBuffer(m_atrLongHandle, 0, 0, 1, atrLong) <= 0)
      {
         Logger::Error("Failed to copy ATR Long buffer for " + m_symbol);
         return false;
      }
      
      // Mettre à jour le cache
      m_cachedATRShort = atrShort[0];
      m_cachedATRLong = atrLong[0];
      m_lastUpdateTime = currentBarTime;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Version const du ratio pour les méthodes const                  |
   //+------------------------------------------------------------------+
   double GetVolatilityRatioConst() const
   {
      if(m_cachedATRLong <= 0)
         return 0.0;
      
      return m_cachedATRShort / m_cachedATRLong;
   }
};

