//+------------------------------------------------------------------+
//|                                            JT_TradeFilters.mqh   |
//|                        Module unifié de filtres de trading       |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "JT_Enums.mqh"
#include "JT_Utils.mqh"
#include "JT_DivergenceValidator.mqh"

// Configuration du filtre RSI
struct RSIFilterConfig {
   bool enabled;
   int handle;
   double oversoldLevel;   // Seuil survente pour BUY
   double overboughtLevel; // Seuil surachat pour SELL
};

// Configuration du filtre EMA
struct EMAFilterConfig {
   bool enabled;
   int handleFast;
   int handleSlow;
   int periodFast;
   int periodSlow;
   ENUM_EMA_FILTER_MODE mode;
   double zoneDistance;    // Distance zone en points
};

// Configuration du filtre temporel
struct TimeFilterConfig {
   bool useHourFilter;
   string hourRanges;      // Format: "8-10;16"
   bool useDayFilter;
   string dayRanges;       // Format: "1-5"
};

// Configuration du filtre de divergence
struct DivergenceFilterConfig {
   bool enabled;
   JTDivergenceValidator* validator;
   double rsiBuyLevel;
   double rsiSellLevel;
   int swingLength;
};

//+------------------------------------------------------------------+
//| Classe de gestion des filtres de trading                        |
//+------------------------------------------------------------------+
class JTTradeFilters
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Filtres
   RSIFilterConfig m_rsiFilter;
   EMAFilterConfig m_emaFilter;
   TimeFilterConfig m_timeFilter;
   DivergenceFilterConfig m_divFilter;
   
   // Dernières valeurs de log (pour éviter le spam)
   int m_lastLoggedHour;
   int m_lastLoggedDay;
   
   // Logging
   void LogInfo(string message) {
      Print("[FILTER][INFO] ", message);
   }
   
   void LogDebug(string message) {
      Print("[FILTER][DEBUG] ", message);
   }

public:
   JTTradeFilters() : m_lastLoggedHour(-1), m_lastLoggedDay(-1) {
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      
      // Initialiser configurations par défaut
      m_rsiFilter.enabled = false;
      m_rsiFilter.handle = INVALID_HANDLE;
      
      m_emaFilter.enabled = false;
      m_emaFilter.handleFast = INVALID_HANDLE;
      m_emaFilter.handleSlow = INVALID_HANDLE;
      
      m_timeFilter.useHourFilter = false;
      m_timeFilter.useDayFilter = false;
      
      m_divFilter.enabled = false;
      m_divFilter.validator = NULL;
   }
   
   ~JTTradeFilters() {
      // Les handles d'indicateurs sont gérés ailleurs
      // Le validator de divergence aussi
   }
   
   //+------------------------------------------------------------------+
   //| Initialisation                                                   |
   //+------------------------------------------------------------------+
   void SetSymbolAndTimeframe(string symbol, ENUM_TIMEFRAMES tf) {
      m_symbol = symbol;
      m_timeframe = tf;
   }
   
   //+------------------------------------------------------------------+
   //| Configuration du filtre RSI                                      |
   //+------------------------------------------------------------------+
   void ConfigureRSIFilter(bool enabled, int handle, double oversold, double overbought) {
      m_rsiFilter.enabled = enabled;
      m_rsiFilter.handle = handle;
      m_rsiFilter.oversoldLevel = oversold;
      m_rsiFilter.overboughtLevel = overbought;
      
      if(enabled) {
         LogInfo("Filtre RSI activé: Oversold<" + DoubleToString(oversold, 1) + 
                 ", Overbought>" + DoubleToString(overbought, 1));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configuration du filtre EMA                                      |
   //+------------------------------------------------------------------+
   void ConfigureEMAFilter(
      bool enabled,
      int handleFast,
      int handleSlow,
      int periodFast,
      int periodSlow,
      ENUM_EMA_FILTER_MODE mode,
      double zoneDistance
   ) {
      m_emaFilter.enabled = enabled;
      m_emaFilter.handleFast = handleFast;
      m_emaFilter.handleSlow = handleSlow;
      m_emaFilter.periodFast = periodFast;
      m_emaFilter.periodSlow = periodSlow;
      m_emaFilter.mode = mode;
      m_emaFilter.zoneDistance = zoneDistance;
      
      if(enabled) {
         string modeText = "";
         switch(mode) {
            case EMA_TREND: modeText = "TREND (suivre tendance)"; break;
            case EMA_COUNTER: modeText = "COUNTER (contre-tendance)"; break;
            case EMA_ZONE: modeText = "ZONE (éviter zone neutre)"; break;
         }
         LogInfo("Filtre EMA activé: EMA" + IntegerToString(periodFast) + "/EMA" + 
                 IntegerToString(periodSlow) + " - Mode: " + modeText);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configuration du filtre temporel                                 |
   //+------------------------------------------------------------------+
   void ConfigureTimeFilter(
      bool useHourFilter,
      string hourRanges,
      bool useDayFilter,
      string dayRanges
   ) {
      m_timeFilter.useHourFilter = useHourFilter;
      m_timeFilter.hourRanges = hourRanges;
      m_timeFilter.useDayFilter = useDayFilter;
      m_timeFilter.dayRanges = dayRanges;
      
      if(useHourFilter) {
         LogInfo("Filtre horaire activé: " + hourRanges);
      }
      if(useDayFilter) {
         LogInfo("Filtre jours activé: " + dayRanges);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configuration du filtre de divergence                            |
   //+------------------------------------------------------------------+
   void ConfigureDivergenceFilter(
      bool enabled,
      JTDivergenceValidator* validator
   ) {
      m_divFilter.enabled = enabled;
      m_divFilter.validator = validator;
      
      if(enabled) {
         LogInfo("Filtre divergence activé");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Vérification des filtres temporels                              |
   //+------------------------------------------------------------------+
   bool IsTimeAllowed() {
      // Vérifier filtre horaire
      if(m_timeFilter.useHourFilter) {
         if(!IsHourAllowedCustom(m_timeFilter.hourRanges)) {
            MqlDateTime dt;
            TimeToStruct(TimeCurrent(), dt);
            if(m_lastLoggedHour != dt.hour) {
               LogDebug("Heure non autorisée: " + IntegerToString(dt.hour) + ":00");
               m_lastLoggedHour = dt.hour;
            }
            return false;
         }
      }
      
      // Vérifier filtre de jour
      if(m_timeFilter.useDayFilter) {
         if(!IsDayAllowedCustom(m_timeFilter.dayRanges)) {
            MqlDateTime dt;
            TimeToStruct(TimeCurrent(), dt);
            if(m_lastLoggedDay != dt.day_of_week) {
               string dayNames[] = {"Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"};
               LogDebug("Jour non autorisé: " + dayNames[dt.day_of_week]);
               m_lastLoggedDay = dt.day_of_week;
            }
            return false;
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Vérification du filtre RSI                                       |
   //+------------------------------------------------------------------+
   bool CheckRSIFilter(int signalDirection, double rsiValue) {
      if(!m_rsiFilter.enabled) return true;
      
      bool passed = false;
      
      if(signalDirection > 0) {
         // Pour BUY, RSI doit être en survente
         passed = (rsiValue < m_rsiFilter.oversoldLevel);
         if(!passed) {
            LogDebug("Signal BUY rejeté - RSI " + DoubleToString(rsiValue, 2) + 
                     " >= " + DoubleToString(m_rsiFilter.oversoldLevel, 2));
         }
      } else if(signalDirection < 0) {
         // Pour SELL, RSI doit être en surachat
         passed = (rsiValue > m_rsiFilter.overboughtLevel);
         if(!passed) {
            LogDebug("Signal SELL rejeté - RSI " + DoubleToString(rsiValue, 2) + 
                     " <= " + DoubleToString(m_rsiFilter.overboughtLevel, 2));
         }
      }
      
      if(passed) {
         LogInfo("✓ Filtre RSI passé: " + DoubleToString(rsiValue, 2));
      }
      
      return passed;
   }
   
   //+------------------------------------------------------------------+
   //| Vérification du filtre EMA                                       |
   //+------------------------------------------------------------------+
   bool CheckEMAFilter(int signalDirection) {
      if(!m_emaFilter.enabled) return true;
      
      double emaFast[], emaSlow[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);
      
      if(CopyBuffer(m_emaFilter.handleFast, 0, 0, 2, emaFast) < 2) {
         LogInfo("Erreur copie EMA Fast");
         return false;
      }
      if(CopyBuffer(m_emaFilter.handleSlow, 0, 0, 2, emaSlow) < 2) {
         LogInfo("Erreur copie EMA Slow");
         return false;
      }
      
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      bool uptrend = (emaFast[0] > emaSlow[0]);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      bool filterPassed = false;
      string modeStr = "";
      
      switch(m_emaFilter.mode) {
         case EMA_TREND: {
            // Mode TREND: Trade dans le sens de la tendance
            modeStr = "TREND";
            if(signalDirection > 0) {
               filterPassed = uptrend && (price > emaSlow[0]);
               if(!filterPassed) {
                  LogDebug("Filtre EMA TREND: Rejet BUY - Tendance=" + (uptrend?"UP":"DOWN"));
               }
            } else {
               filterPassed = !uptrend && (price < emaSlow[0]);
               if(!filterPassed) {
                  LogDebug("Filtre EMA TREND: Rejet SELL - Tendance=" + (uptrend?"UP":"DOWN"));
               }
            }
            break;
         }
         
         case EMA_COUNTER: {
            // Mode COUNTER: Trade les retournements
            modeStr = "COUNTER";
            double distance = MathAbs(price - emaFast[0]) / point;
            if(signalDirection > 0) {
               filterPassed = !uptrend && (price < emaFast[0]) && 
                             (distance > m_emaFilter.zoneDistance);
               if(!filterPassed) {
                  LogDebug("Filtre EMA COUNTER: Rejet BUY - Distance=" + 
                           DoubleToString(distance, 1) + "pts");
               }
            } else {
               filterPassed = uptrend && (price > emaFast[0]) && 
                             (distance > m_emaFilter.zoneDistance);
               if(!filterPassed) {
                  LogDebug("Filtre EMA COUNTER: Rejet SELL - Distance=" + 
                           DoubleToString(distance, 1) + "pts");
               }
            }
            break;
         }
         
         case EMA_ZONE: {
            // Mode ZONE: Éviter la zone neutre
            modeStr = "ZONE";
            double maxEMA = MathMax(emaFast[0], emaSlow[0]);
            double minEMA = MathMin(emaFast[0], emaSlow[0]);
            bool inZone = (price < maxEMA + m_emaFilter.zoneDistance * point) && 
                         (price > minEMA - m_emaFilter.zoneDistance * point);
            filterPassed = !inZone;
            if(!filterPassed) {
               LogDebug("Filtre EMA ZONE: Rejet - Prix dans zone neutre");
            }
            break;
         }
      }
      
      if(filterPassed) {
         LogInfo("✓ Filtre EMA " + modeStr + " passé - Signal " + 
                 (signalDirection>0?"BUY":"SELL") + " validé");
      }
      
      return filterPassed;
   }
   
   //+------------------------------------------------------------------+
   //| Vérification de la direction de trading autorisée               |
   //+------------------------------------------------------------------+
   bool CheckTradeDirection(int signalDirection, ENUM_TRADE_DIRECTION allowedDirection) {
      if(allowedDirection == TRADE_BOTH) return true;
      
      if(allowedDirection == TRADE_ONLY_BUY && signalDirection < 0) {
         LogDebug("Signal SELL rejeté - Seuls les BUY sont autorisés");
         return false;
      }
      
      if(allowedDirection == TRADE_ONLY_SELL && signalDirection > 0) {
         LogDebug("Signal BUY rejeté - Seuls les SELL sont autorisés");
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Validation par divergence                                        |
   //+------------------------------------------------------------------+
   int CheckDivergenceValidator() {
      if(!m_divFilter.enabled || m_divFilter.validator == NULL) return 0;
      
      return m_divFilter.validator.ValidateDivergence();
   }
   
   //+------------------------------------------------------------------+
   //| Mémoriser un Free Candle pour validation future                 |
   //+------------------------------------------------------------------+
   void RememberFreeCandle(int barIndex, double priceLevel, int direction) {
      if(m_divFilter.enabled && m_divFilter.validator != NULL) {
         m_divFilter.validator.RememberFreeCandle(barIndex, priceLevel, direction);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les données de la dernière divergence                   |
   //+------------------------------------------------------------------+
   void GetLastDivergenceData(double &angle, double &strength, int &bars) {
      angle = 0.0;
      strength = 0.0;
      bars = 0;
      
      if(m_divFilter.enabled && m_divFilter.validator != NULL) {
         angle = m_divFilter.validator.GetLastDivergenceAngle();
         strength = m_divFilter.validator.GetLastDivergenceStrength();
         bars = m_divFilter.validator.GetLastDivergenceBars();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Accesseurs                                                       |
   //+------------------------------------------------------------------+
   bool IsRSIFilterEnabled() { return m_rsiFilter.enabled; }
   bool IsEMAFilterEnabled() { return m_emaFilter.enabled; }
   bool IsDivergenceEnabled() { return m_divFilter.enabled; }
   
   ENUM_EMA_FILTER_MODE GetEMAMode() { return m_emaFilter.mode; }
};

