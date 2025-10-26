//+------------------------------------------------------------------+
//|                                     JT_FreeCandleStrategy.mqh    |
//|                   Stratégie basée sur les Free Candles (BB)      |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"

#include "../common/JT_BaseStrategy.mqh"
#include "../common/JT_DivergenceValidator.mqh"
#include "../common/JT_TradeFilters.mqh"

//+------------------------------------------------------------------+
//| Stratégie Free Candle - Bougies hors bandes de Bollinger        |
//+------------------------------------------------------------------+
class JTFreeCandleStrategy : public JTBaseStrategy
{
protected:
   // Paramètres Bollinger Bands
   int               m_bbPeriod;
   double            m_bbDeviation;
   int               m_bbShift;
   int               m_outsidePadding;
   bool              m_bodyMustBeOutside;
   
   // Mode d'entrée
   ENUM_ENTRY_MODE   m_entryMode;
   
   // EMAs pour filtre de tendance
   int               m_emaFastHandle;
   int               m_emaSlowHandle;
   int               m_emaFastPeriod;
   int               m_emaSlowPeriod;
   ENUM_EMA_FILTER_MODE m_emaMode;
   double            m_emaZoneDistance;
   
   // RSI
   int               m_rsiPeriod;
   double            m_rsiOversold;
   double            m_rsiOverbought;
   
   // Divergence Validator
   JTDivergenceValidator* m_divValidator;
   double            m_divRsiBuyLevel;
   double            m_divRsiSellLevel;
   int               m_divSwingLength;
   
   // Trade Filters Manager
   JTTradeFilters*   m_filters;
   
   // Marqueurs visuels
   bool              m_markFreeCandles;
   bool              m_markDrawVLine;
   bool              m_markDrawArrow;
   bool              m_markDrawBox;
   bool              m_markDrawText;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   JTFreeCandleStrategy(string symbol, ENUM_TIMEFRAMES tf, ulong magic) 
      : JTBaseStrategy(symbol, tf, magic)
   {
      // Valeurs par défaut BB
      m_bbPeriod = 20;
      m_bbDeviation = 2.0;
      m_bbShift = 0;
      m_outsidePadding = 5;
      m_bodyMustBeOutside = true;
      
      // Mode par défaut
      m_entryMode = ENTRY_REVERSION;
      
      // EMAs
      m_emaFastHandle = INVALID_HANDLE;
      m_emaSlowHandle = INVALID_HANDLE;
      m_emaFastPeriod = 50;
      m_emaSlowPeriod = 100;
      m_emaMode = EMA_TREND;
      m_emaZoneDistance = 20.0;
      
      // RSI
      m_rsiPeriod = 14;
      m_rsiOversold = 29.0;
      m_rsiOverbought = 71.0;
      
      // Divergence
      m_divValidator = NULL;
      m_divRsiBuyLevel = 35.0;
      m_divRsiSellLevel = 65.0;
      m_divSwingLength = 5;
      
      // Filters
      m_filters = new JTTradeFilters();
      m_filters.SetSymbolAndTimeframe(symbol, tf);
      
      // Marqueurs
      m_markFreeCandles = false;
      m_markDrawVLine = false;
      m_markDrawArrow = false;
      m_markDrawBox = false;
      m_markDrawText = false;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~JTFreeCandleStrategy()
   {
      // Libérer les handles
      if(m_emaFastHandle != INVALID_HANDLE) {
         IndicatorRelease(m_emaFastHandle);
         m_emaFastHandle = INVALID_HANDLE;
      }
      if(m_emaSlowHandle != INVALID_HANDLE) {
         IndicatorRelease(m_emaSlowHandle);
         m_emaSlowHandle = INVALID_HANDLE;
      }
      
      // Libérer le validateur de divergence
      if(m_divValidator != NULL) {
         delete m_divValidator;
         m_divValidator = NULL;
      }
      
      // Libérer les filtres
      if(m_filters != NULL) {
         delete m_filters;
         m_filters = NULL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configuration des paramètres                                     |
   //+------------------------------------------------------------------+
   
   void SetBBParameters(int period, double deviation, int padding, bool bodyOnly, int shift = 0)
   {
      m_bbPeriod = period;
      m_bbDeviation = deviation;
      m_outsidePadding = padding;
      m_bodyMustBeOutside = bodyOnly;
      m_bbShift = shift;
   }
   
   void SetRSIParameters(int period, double oversold, double overbought)
   {
      m_rsiPeriod = period;
      m_rsiOversold = oversold;
      m_rsiOverbought = overbought;
   }
   
   void SetEMAParameters(int fast, int slow, ENUM_EMA_FILTER_MODE mode, double zoneDistance = 20.0)
   {
      m_emaFastPeriod = fast;
      m_emaSlowPeriod = slow;
      m_emaMode = mode;
      m_emaZoneDistance = zoneDistance;
   }
   
   void SetDivergenceParameters(double rsiBuy, double rsiSell, int swingLength)
   {
      m_divRsiBuyLevel = rsiBuy;
      m_divRsiSellLevel = rsiSell;
      m_divSwingLength = swingLength;
   }
   
   void SetEntryMode(ENUM_ENTRY_MODE mode)
   {
      m_entryMode = mode;
   }
   
   void SetVisualMarkers(bool markCandles, bool vline, bool arrow, bool box, bool text)
   {
      m_markFreeCandles = markCandles;
      m_markDrawVLine = vline;
      m_markDrawArrow = arrow;
      m_markDrawBox = box;
      m_markDrawText = text;
   }
   
   //+------------------------------------------------------------------+
   //| Override: Nom de la stratégie                                   |
   //+------------------------------------------------------------------+
   virtual string GetStrategyName() override
   {
      return "FreeCandle";
   }
   
   //+------------------------------------------------------------------+
   //| Override: Initialisation spécifique                             |
   //+------------------------------------------------------------------+
   virtual bool InitStrategy() override
   {
      // Initialiser les indicateurs BB et RSI
      if(!InitIndicators(m_indicators, m_symbol, m_timeframe, 
                        m_bbPeriod, m_bbDeviation, m_bbShift, m_rsiPeriod)) {
         LogError("Erreur d'initialisation des indicateurs BB/RSI");
         return false;
      }
      
      // Afficher les Bollinger Bands sur le graphe
      if(!ChartIndicatorAdd(0, 0, m_indicators.BB)) {
         Print("Attention: impossible d'afficher les Bollinger Bands sur le graphe");
      }
      
      // Afficher le RSI dans une sous-fenêtre
      if(!ChartIndicatorAdd(0, ChartWindowFind(), m_indicators.RSI)) {
         Print("Attention: impossible d'afficher le RSI sur le graphe");
      }
      
      // Initialiser les EMAs si le filtre est activé
      if(m_useEMAFilter) {
         m_emaFastHandle = iMA(m_symbol, m_timeframe, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
         m_emaSlowHandle = iMA(m_symbol, m_timeframe, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
         
         if(m_emaFastHandle == INVALID_HANDLE || m_emaSlowHandle == INVALID_HANDLE) {
            LogError("Erreur d'initialisation des EMAs");
            return false;
         }
         
         // Afficher les EMAs sur le graphe
         if(!ChartIndicatorAdd(0, 0, m_emaFastHandle)) {
            Print("Attention: impossible d'afficher EMA" + IntegerToString(m_emaFastPeriod));
         }
         if(!ChartIndicatorAdd(0, 0, m_emaSlowHandle)) {
            Print("Attention: impossible d'afficher EMA" + IntegerToString(m_emaSlowPeriod));
         }
         
         // Configurer le filtre EMA
         m_filters.ConfigureEMAFilter(true, m_emaFastHandle, m_emaSlowHandle,
                                     m_emaFastPeriod, m_emaSlowPeriod,
                                     m_emaMode, m_emaZoneDistance);
      }
      
      // Configurer le filtre RSI
      if(m_useRSIFilter) {
         m_filters.ConfigureRSIFilter(true, m_indicators.RSI, m_rsiOversold, m_rsiOverbought);
      }
      
      // Initialiser le validateur de divergence si activé
      if(m_useDivergence) {
         m_divValidator = new JTDivergenceValidator();
         if(!m_divValidator.Init(m_symbol, m_timeframe, m_rsiPeriod, 
                                m_divRsiBuyLevel, m_divRsiSellLevel, m_divSwingLength)) {
            LogError("Erreur d'initialisation du validateur de divergence");
            return false;
         }
         
         m_filters.ConfigureDivergenceFilter(true, m_divValidator);
         
         LogMessage("Validateur de divergence activé: RSI Buy<" + DoubleToString(m_divRsiBuyLevel, 1) + 
                   ", RSI Sell>" + DoubleToString(m_divRsiSellLevel, 1));
      }
      
      // Nettoyer les anciens marqueurs si activés
      if(m_markFreeCandles) {
         DeleteAllFreeCandleMarkers("FreeCandle");
         LogMessage("Marqueurs Free Candles activés");
      }
      
      // Créer le Trade Tracker
      m_tracker = new JTTradeTracker(
         m_symbol,
         m_magic,
         m_bbPeriod,
         m_bbDeviation,
         m_rsiPeriod,
         m_useEMAFilter ? m_emaFastPeriod : 50,
         m_useEMAFilter ? m_emaSlowPeriod : 100
      );
      
      if(m_tracker != NULL) {
         LogMessage("Trade Tracker activé - Fichier CSV: TradeAnalysis_" + m_symbol + "_" + IntegerToString(m_magic) + ".csv");
      }
      
      LogMessage("Stratégie FreeCandle initialisée:");
      LogMessage("  BB: " + IntegerToString(m_bbPeriod) + "/" + DoubleToString(m_bbDeviation, 1));
      LogMessage("  RSI: " + (m_useRSIFilter ? "ON" : "OFF") + " (" + IntegerToString(m_rsiPeriod) + ")");
      LogMessage("  EMA: " + (m_useEMAFilter ? "ON" : "OFF"));
      LogMessage("  Mode: " + (m_entryMode == ENTRY_REVERSION ? "REVERSION" : "BREAKOUT"));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Override: Deinitialisation spécifique                           |
   //+------------------------------------------------------------------+
   virtual void DeinitStrategy() override
   {
      ReleaseIndicators(m_indicators);
   }
   
   //+------------------------------------------------------------------+
   //| Override: Détection du signal                                   |
   //+------------------------------------------------------------------+
   virtual int DetectSignal() override
   {
      // Si le validateur de divergence est activé, vérifier d'abord
      if(m_useDivergence && m_divValidator != NULL) {
         int divSignal = m_divValidator.ValidateDivergence();
         if(divSignal != 0) {
            LogMessage("DIVERGENCE VALIDÉE - Signal: " + (divSignal > 0 ? "BUY" : "SELL"));
            return divSignal;
         }
      }
      
      // Logique standard de détection de Free Candle
      return DetectFreeCandleSignal();
   }
   
   //+------------------------------------------------------------------+
   //| Détection du signal Free Candle                                 |
   //+------------------------------------------------------------------+
   int DetectFreeCandleSignal()
   {
      // Récupérer les données de la bougie fermée (N-1)
      MqlRates r[];
      if(CopyRates(m_symbol, m_timeframe, 0, 3, r) < 3) return 0;
      ArraySetAsSeries(r, true);
      
      double open = r[1].open;
      double high = r[1].high;
      double low = r[1].low;
      double close = r[1].close;
      
      // Récupérer les bandes de Bollinger
      if(!GetIndicatorData(m_indicators, m_buffers, 3, false)) return 0;
      
      double upper = m_buffers.BBUpper[1];
      double lower = m_buffers.BBLower[1];
      
      // Vérifier si c'est une Free Candle
      if(!IsFreeCandle(open, high, low, close, upper, lower)) {
         return 0;
      }
      
      LogMessage("FREE CANDLE DÉTECTÉE!");
      
      // Déterminer la direction
      bool isAboveBand = false;
      bool isBelowBand = false;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double padding = m_outsidePadding * point;
      
      if(m_bodyMustBeOutside) {
         double bodyHigh = MathMax(open, close);
         double bodyLow = MathMin(open, close);
         isAboveBand = (bodyLow > upper + padding);
         isBelowBand = (bodyHigh < lower - padding);
      } else {
         isAboveBand = (low > upper + padding);
         isBelowBand = (high < lower - padding);
      }
      
      bool red = (open > close);
      bool green = (close > open);
      bool outsideBearAbove = isAboveBand && red;
      bool outsideBullBelow = isBelowBand && green;
      
      // Déterminer le signal selon le mode
      int signal = 0;
      if(m_entryMode == ENTRY_REVERSION) {
         if(outsideBearAbove) signal = -1; // SELL (réversion)
         if(outsideBullBelow) signal = +1; // BUY (réversion)
      } else { // BREAKOUT
         if(isAboveBand) signal = +1;      // BUY (breakout)
         if(isBelowBand) signal = -1;      // SELL (breakout)
      }
      
      // Si divergence activée, mémoriser le free candle au lieu de retourner le signal
      if(signal != 0 && m_useDivergence && m_divValidator != NULL) {
         MqlTick tick;
         if(SymbolInfoTick(m_symbol, tick)) {
            double priceLevel = (signal > 0) ? tick.bid : tick.ask;
            m_divValidator.RememberFreeCandle(1, priceLevel, signal);
            LogMessage("Free Candle mémorisé pour validation divergence future");
         }
         return 0; // Ne pas retourner le signal immédiatement
      }
      
      // Marquer le Free Candle si activé
      if(m_markFreeCandles && signal != 0) {
         MarkFreeCandleOnChart(r[1].time, high, low, signal);
      }
      
      return signal;
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si c'est une Free Candle                               |
   //+------------------------------------------------------------------+
   bool IsFreeCandle(double open, double high, double low, double close,
                     double upper, double lower)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double padding = m_outsidePadding * point;
      
      if(m_bodyMustBeOutside) {
         // Le corps doit être entièrement hors bande
         double bodyHigh = MathMax(open, close);
         double bodyLow = MathMin(open, close);
         
         bool bodyAbove = (bodyLow > upper + padding);
         bool bodyBelow = (bodyHigh < lower - padding);
         
         return (bodyAbove || bodyBelow);
      } else {
         // Toute la bougie (mèches comprises) doit être hors bande
         bool candleAbove = (low > upper + padding);
         bool candleBelow = (high < lower - padding);
         
         return (candleAbove || candleBelow);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Override: Validation du signal avant entrée                     |
   //+------------------------------------------------------------------+
   virtual bool ValidateEntry(int signal) override
   {
      if(signal == 0) return false;
      
      // Vérifier le filtre de direction
      if(!m_filters.CheckTradeDirection(signal, m_tradeDirection)) {
         return false;
      }
      
      // Appliquer le filtre EMA
      if(m_useEMAFilter) {
         if(!m_filters.CheckEMAFilter(signal)) {
            LogMessage("Signal rejeté par filtre EMA");
            return false;
         }
      }
      
      // Appliquer le filtre RSI
      if(m_useRSIFilter) {
         // Récupérer la valeur RSI actuelle
         if(!GetIndicatorData(m_indicators, m_buffers, 2, false)) {
            LogError("Erreur lors de la récupération du RSI");
            return false;
         }
         
         double currentRSI = m_buffers.RSI[1];
         if(!m_filters.CheckRSIFilter(signal, currentRSI)) {
            LogMessage("Signal rejeté par filtre RSI");
            return false;
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Override: Enregistrer le trade dans le tracker                  |
   //+------------------------------------------------------------------+
   virtual void RecordTradeInTracker(ulong ticket, bool isBuy, double rr) override
   {
      if(m_tracker == NULL) return;
      
      // Déterminer si c'est un trade de divergence
      bool isDivergence = false;
      double divAngle = 0.0;
      double divStrength = 0.0;
      int divBars = 0;
      
      if(m_useDivergence && m_divValidator != NULL) {
         m_filters.GetLastDivergenceData(divAngle, divStrength, divBars);
         isDivergence = (divBars > 0); // Si on a des données de divergence
      }
      
      // Mode de trading
      string tradeMode = (m_entryMode == ENTRY_REVERSION ? "REVERSION" : "BREAKOUT");
      
      // Mode EMA
      string emaMode = "";
      if(m_useEMAFilter) {
         switch(m_emaMode) {
            case EMA_TREND: emaMode = "TREND"; break;
            case EMA_COUNTER: emaMode = "COUNTER"; break;
            case EMA_ZONE: emaMode = "ZONE"; break;
         }
      }
      
      // Enregistrer le trade avec toutes les infos
      m_tracker.RecordTradeOpen(
         ticket,
         tradeMode,
         isDivergence,
         emaMode,
         divAngle,
         divStrength,
         divBars,
         // Config EA
         m_bbPeriod,
         m_bbDeviation,
         m_rsiPeriod,
         m_rsiOversold,
         m_rsiOverbought,
         m_emaFastPeriod,
         m_emaSlowPeriod,
         m_emaZoneDistance,
         m_riskPercent,
         m_minRR,
         m_slPeriod,
         m_tpPeriod,
         m_atrMultiplier,
         m_atrPeriod,
         m_outsidePadding,
         m_bodyMustBeOutside,
         m_useRSIFilter,
         m_useEMAFilter,
         m_useDivergence
      );
   }
   
private:
   //+------------------------------------------------------------------+
   //| Marquer un Free Candle sur le graphique                         |
   //+------------------------------------------------------------------+
   void MarkFreeCandleOnChart(datetime time, double high, double low, int signal)
   {
      double arrowPrice = (signal > 0) ? low : high;
      
      // Utiliser la fonction helper de JT_Utils
      MarkFreeCandle(time, high, low, arrowPrice, signal, m_timeframe,
                    m_markDrawVLine, m_markDrawArrow, m_markDrawBox, m_markDrawText,
                    "FreeCandle");
      
      LogMessage("Free Candle marqué sur le graphique à " + TimeToString(time));
   }
};
