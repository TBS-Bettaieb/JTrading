//+------------------------------------------------------------------+
//|                                                JT_Indicators.mqh |
//|                          Fonctions liées aux indicateurs (MT5)   |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+

// Structure pour stocker les handles des indicateurs
struct IndicatorHandles {
   int BB;    // Bollinger Bands
   int RSI;   // RSI
   int EMA;   // EMA (optionnel)
};

// Structure pour stocker les buffers des indicateurs
struct IndicatorBuffers {
   double BBUpper[];
   double BBMiddle[];
   double BBLower[];
   double RSI[];
   double EMA[];  // Optionnel
};

// Initialise les handles des indicateurs
bool InitIndicators(
   IndicatorHandles &handles,
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int bbPeriod,
   double bbDeviation,
   int bbShift,
   int rsiPeriod,
   int emaPeriod = 0  // Optionnel
) {
   // Initialiser Bollinger Bands
   handles.BB = iBands(symbol, timeframe, bbPeriod, bbShift, bbDeviation, PRICE_CLOSE);
   if(handles.BB == INVALID_HANDLE) {
      Print("Erreur d'initialisation des Bollinger Bands");
      return false;
   }
   
   // Initialiser RSI
   handles.RSI = iRSI(symbol, timeframe, rsiPeriod, PRICE_CLOSE);
   if(handles.RSI == INVALID_HANDLE) {
      Print("Erreur d'initialisation du RSI");
      return false;
   }
   
   // Initialiser EMA (optionnel)
   if(emaPeriod > 0) {
      handles.EMA = iMA(symbol, timeframe, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(handles.EMA == INVALID_HANDLE) {
         Print("Erreur d'initialisation de l'EMA");
         return false;
      }
   } else {
      handles.EMA = INVALID_HANDLE;
   }
   
   return true;
}

// Libère les handles des indicateurs
void ReleaseIndicators(IndicatorHandles &handles) {
   if(handles.BB != INVALID_HANDLE) IndicatorRelease(handles.BB);
   if(handles.RSI != INVALID_HANDLE) IndicatorRelease(handles.RSI);
   if(handles.EMA != INVALID_HANDLE) IndicatorRelease(handles.EMA);
}

// Copie les données des indicateurs dans les buffers
bool GetIndicatorData(
   const IndicatorHandles &handles,
   IndicatorBuffers &buffers,
   int bars = 5,
   bool useEMA = false
) {
   // Copier les données des Bollinger Bands
   // Buffer 0 = BASE_LINE (milieu), Buffer 1 = UPPER_BAND, Buffer 2 = LOWER_BAND
   if(CopyBuffer(handles.BB, 1, 0, bars, buffers.BBUpper) < bars) return false;
   if(CopyBuffer(handles.BB, 0, 0, bars, buffers.BBMiddle) < bars) return false;
   if(CopyBuffer(handles.BB, 2, 0, bars, buffers.BBLower) < bars) return false;
   
   // Copier les données du RSI
   if(CopyBuffer(handles.RSI, 0, 0, bars, buffers.RSI) < bars) return false;
   
   // Copier les données de l'EMA (optionnel)
   if(useEMA && handles.EMA != INVALID_HANDLE) {
      if(CopyBuffer(handles.EMA, 0, 0, bars, buffers.EMA) < bars) return false;
   }
   
   // Définir les tableaux comme séries pour un accès plus intuitif
   ArraySetAsSeries(buffers.BBUpper, true);
   ArraySetAsSeries(buffers.BBMiddle, true);
   ArraySetAsSeries(buffers.BBLower, true);
   ArraySetAsSeries(buffers.RSI, true);
   if(useEMA) ArraySetAsSeries(buffers.EMA, true);
   
   return true;
}

// Fonctions de détection de croisement
bool CrossUp(double prev, double curr, double level) { 
   return prev < level && curr >= level; 
}

bool CrossDown(double prev, double curr, double level) { 
   return prev > level && curr <= level; 
}

// Détecte une nouvelle bougie
bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe, datetime &lastBarTime) {
   datetime currentBarTime = iTime(symbol, timeframe, 0);
   if(currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

// Détecte si une bougie est "libre" (entièrement en dehors des bandes de Bollinger)
// Version simplifiée avec MqlRates
bool IsFreeCandle(
   MqlRates &candle, 
   double upperBand, 
   double lowerBand, 
   double paddingPoints = 0, 
   bool bodyOnly = true
) {
   double padding = paddingPoints * _Point;
   
   if(bodyOnly) {
      double bodyHigh = MathMax(candle.open, candle.close);
      double bodyLow = MathMin(candle.open, candle.close);
      return (bodyLow > upperBand + padding) || (bodyHigh < lowerBand - padding);
   } else {
      return (candle.low > upperBand + padding) || (candle.high < lowerBand - padding);
   }
}

// Surcharge avec valeurs de prix directes (version principale)
bool IsFreeCandle(
   double open,
   double high,
   double low,
   double close,
   double upperBand, 
   double lowerBand, 
   double paddingPoints = 0, 
   bool bodyOnly = true
) {
   double padding = paddingPoints * _Point;
   
   if(bodyOnly) {
      double bodyHigh = MathMax(open, close);
      double bodyLow = MathMin(open, close);
      return (bodyLow > upperBand + padding) || (bodyHigh < lowerBand - padding);
   } else {
      return (low > upperBand + padding) || (high < lowerBand - padding);
   }
}