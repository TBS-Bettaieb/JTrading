//+------------------------------------------------------------------+
//|                                      JT_FreeCandleStrategy.mqh   |
//|                    Implémentation de la stratégie Free Candle    |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../common/JT_BaseStrategy.mqh"
#include "../common/JT_Utils.mqh"

// Configuration spécifique à la stratégie Free Candle
struct FreeCandleConfig {
   int bbPeriod;
   double bbDeviation;
   int bbShift;
   int rsiPeriod;
   int outsidePaddingPoints;
   bool bodyMustBeOutside;
   bool markCandles;         // Marquage visuel
   bool drawVLine;
   bool drawArrow;
   bool drawBox;
   bool drawText;
};

//+------------------------------------------------------------------+
//| Stratégie Free Candle                                            |
//+------------------------------------------------------------------+
class JTFreeCandleStrategy : public JTBaseStrategy
{
private:
   FreeCandleConfig m_config;
   
   // Gestion des marqueurs visuels
   void MarkSignal(datetime time, double high, double low, double price, int direction) {
      if(!m_config.markCandles) return;
      
      MarkFreeCandle(time, high, low, price, direction, m_params.timeframe,
                    m_config.drawVLine, m_config.drawArrow, 
                    m_config.drawBox, m_config.drawText, "FreeCandle");
   }
   
   // Marquer un signal de divergence
   void MarkDivergenceSignal(datetime time, double high, double low, double price, int direction) {
      if(!m_config.markCandles) return;
      
      MarkFreeCandle(time, high, low, price, direction, m_params.timeframe,
                    true, true, m_config.drawBox, true, "FreeCandleDIV");
   }
   
   // Détecte si une bougie est un "Free Candle"
   bool IsFreeCandleDetected(
      double open, double high, double low, double close,
      double upperBand, double lowerBand,
      bool &isAbove, bool &isBelow
   ) {
      // Vérifier si la bougie est hors bandes
      if(!IsFreeCandle(open, high, low, close, upperBand, lowerBand, 
                       m_config.outsidePaddingPoints, m_config.bodyMustBeOutside)) {
         return false;
      }
      
      // Déterminer si au-dessus ou en-dessous
      double point = SymbolInfoDouble(m_params.symbol, SYMBOL_POINT);
      double padding = m_config.outsidePaddingPoints * point;
      
      if(m_config.bodyMustBeOutside) {
         double bodyHigh = MathMax(open, close);
         double bodyLow = MathMin(open, close);
         isAbove = (bodyLow > upperBand + padding);
         isBelow = (bodyHigh < lowerBand - padding);
      } else {
         isAbove = (low > upperBand + padding);
         isBelow = (high < lowerBand - padding);
      }
      
      return (isAbove || isBelow);
   }

public:
   JTFreeCandleStrategy() {
      // Configuration par défaut
      m_config.bbPeriod = 20;
      m_config.bbDeviation = 2.0;
      m_config.bbShift = 0;
      m_config.rsiPeriod = 14;
      m_config.outsidePaddingPoints = 5;
      m_config.bodyMustBeOutside = true;
      m_config.markCandles = true;
      m_config.drawVLine = true;
      m_config.drawArrow = true;
      m_config.drawBox = false;
      m_config.drawText = false;
   }
   
   ~JTFreeCandleStrategy() {
      // Optionnel: nettoyer les marqueurs
      // DeleteAllFreeCandleMarkers("FreeCandle");
   }
   
   //+------------------------------------------------------------------+
   //| Configuration de la stratégie                                    |
   //+------------------------------------------------------------------+
   void Configure(FreeCandleConfig &fcConfig) {
      m_config = fcConfig;
   }
   
   FreeCandleConfig GetConfig() { return m_config; }
   
   //+------------------------------------------------------------------+
   //| Implémentation des méthodes virtuelles                          |
   //+------------------------------------------------------------------+
   
   virtual string GetStrategyName() override {
      return "Free Candle Strategy";
   }
   
   virtual bool InitializeIndicators() override {
      // Initialiser Bollinger Bands et RSI
      if(!InitIndicators(m_indicators, m_params.symbol, m_params.timeframe,
                        m_config.bbPeriod, m_config.bbDeviation, m_config.bbShift,
                        m_config.rsiPeriod)) {
         return false;
      }
      
      // Afficher les indicateurs sur le graphique
      ChartIndicatorAdd(0, 0, m_indicators.BB);
      ChartIndicatorAdd(0, ChartWindowFind(), m_indicators.RSI);
      
      // Nettoyer les anciens marqueurs
      if(m_config.markCandles) {
         DeleteAllFreeCandleMarkers("FreeCandle");
         DeleteAllFreeCandleMarkers("FreeCandleDIV");
      }
      
      return true;
   }
   
   virtual bool InitializeFilters() override {
      if(m_filters == NULL) return false;
      
      m_filters.SetSymbolAndTimeframe(m_params.symbol, m_params.timeframe);
      return true;
   }
   
   virtual SignalResult AnalyzeMarket() override {
      SignalResult result;
      result.direction = 0;
      result.isValid = false;
      result.confidence = 0.0;
      result.reason = "";
      
      // Copier les données de la bougie fermée (index 1)
      MqlRates rates[];
      if(CopyRates(m_params.symbol, m_params.timeframe, 0, 3, rates) < 3) {
         result.reason = "Erreur copie rates";
         return result;
      }
      ArraySetAsSeries(rates, true);
      
      double open = rates[1].open;
      double high = rates[1].high;
      double low = rates[1].low;
      double close = rates[1].close;
      datetime time = rates[1].time;
      
      // Copier les indicateurs
      if(!GetIndicatorData(m_indicators, m_buffers, 3, false)) {
         result.reason = "Erreur copie indicateurs";
         return result;
      }
      
      double upperBand = m_buffers.BBUpper[1];
      double lowerBand = m_buffers.BBLower[1];
      double rsiValue = m_buffers.RSI[1];
      
      // Vérifier si c'est un Free Candle
      bool isAbove = false, isBelow = false;
      if(!IsFreeCandleDetected(open, high, low, close, upperBand, lowerBand, isAbove, isBelow)) {
         result.reason = "Pas de Free Candle détectée";
         return result;
      }
      
      LogSignal("FREE CANDLE DÉTECTÉE!");
      
      // Déterminer la direction du signal
      bool isRed = (open > close);
      bool isGreen = (close > open);
      
      if(m_params.entryMode == ENTRY_REVERSION) {
         // Mode REVERSION: Bear candle au-dessus → SELL, Bull candle en-dessous → BUY
         if(isAbove && isRed) result.direction = -1;
         if(isBelow && isGreen) result.direction = +1;
      } else {
         // Mode BREAKOUT: Au-dessus → BUY, En-dessous → SELL
         if(isAbove) result.direction = +1;
         if(isBelow) result.direction = -1;
      }
      
      if(result.direction == 0) {
         result.reason = "Pas de signal valide";
         return result;
      }
      
      // Appliquer le filtre de direction
      if(!m_filters.CheckTradeDirection(result.direction, m_params.tradeDirection)) {
         result.reason = "Direction non autorisée";
         return result;
      }
      
      // Appliquer le filtre EMA
      if(!m_filters.CheckEMAFilter(result.direction)) {
         result.reason = "Rejeté par filtre EMA";
         return result;
      }
      
      // Appliquer le filtre RSI
      if(!m_filters.CheckRSIFilter(result.direction, rsiValue)) {
         result.reason = "Rejeté par filtre RSI";
         return result;
      }
      
      // Si le validateur de divergence est activé, mémoriser au lieu de valider
      if(m_filters.IsDivergenceEnabled()) {
         MqlTick tick;
         if(SymbolInfoTick(m_params.symbol, tick)) {
            double priceLevel = (result.direction > 0) ? tick.bid : tick.ask;
            m_filters.RememberFreeCandle(1, priceLevel, result.direction);
            result.reason = "Free Candle mémorisé pour validation divergence";
            result.isValid = false;
            
            // Marquer le Free Candle
            double arrowPrice = (result.direction > 0) ? low : high;
            MarkSignal(time, high, low, arrowPrice, result.direction);
            
            return result;
         }
      }
      
      // Signal valide
      result.isValid = true;
      result.confidence = 0.8;
      result.reason = "Signal Free Candle validé";
      
      // Marquer le Free Candle
      double arrowPrice = (result.direction > 0) ? low : high;
      MarkSignal(time, high, low, arrowPrice, result.direction);
      
      return result;
   }
   
   virtual bool CalculateEntryLevels(bool isBuy, double &sl, double &tp) override {
      return CalculateSwingSLTP(
         m_params.symbol,
         m_params.timeframe,
         isBuy,
         m_params.slPeriod,
         m_params.tpPeriod,
         sl,
         tp,
         0.0,
         m_params.minRR,
         1000,
         m_params.atrMultiplier,
         m_params.atrPeriod
      );
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier les signaux de divergence                              |
   //+------------------------------------------------------------------+
   SignalResult CheckDivergenceSignal() {
      SignalResult result;
      result.direction = 0;
      result.isValid = false;
      result.confidence = 0.0;
      result.reason = "";
      
      if(!m_filters.IsDivergenceEnabled()) return result;
      
      int divSignal = m_filters.CheckDivergenceValidator();
      if(divSignal == 0) return result;
      
      // Divergence validée
      result.direction = divSignal;
      result.isValid = true;
      result.confidence = 0.9;  // Plus de confiance avec divergence
      result.reason = "Divergence validée";
      
      // Marquer la divergence
      MqlRates rates[];
      if(CopyRates(m_params.symbol, m_params.timeframe, 1, 1, rates) > 0) {
         double high = rates[0].high;
         double low = rates[0].low;
         datetime time = rates[0].time;
         double arrowPrice = (divSignal > 0) ? low : high;
         
         MarkDivergenceSignal(time, high, low, arrowPrice, divSignal);
      }
      
      LogSignal("✓ DIVERGENCE VALIDÉE - Signal " + (divSignal > 0 ? "BUY" : "SELL"));
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les métriques de divergence                             |
   //+------------------------------------------------------------------+
   void GetDivergenceMetrics(double &angle, double &strength, int &bars) {
      m_filters.GetLastDivergenceData(angle, strength, bars);
   }
};

