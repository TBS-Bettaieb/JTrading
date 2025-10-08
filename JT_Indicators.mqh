//+------------------------------------------------------------------+
//|                                                JT_Indicators.mqh |
//|                          Fonctions liées aux indicateurs (MT5)   |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+

// Structure pour stocker les handles des indicateurs
struct IndicatorHandles {
   int BB;    // Bollinger Bands
   int RSI;   // RSI
   int ATR;   // ATR
   int EMA;   // EMA (optionnel)
};

// Structure pour stocker les buffers des indicateurs
struct IndicatorBuffers {
   double BBUpper[];
   double BBMiddle[];
   double BBLower[];
   double RSI[];
   double ATR[];
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
   int atrPeriod,
   int emaPeriod = 0  // Optionnel
) {
   // Initialiser Bollinger Bands
   handles.BB = iBands(symbol, timeframe, bbPeriod, bbDeviation, bbShift, PRICE_CLOSE);
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
   
   // Initialiser ATR
   handles.ATR = iATR(symbol, timeframe, atrPeriod);
   if(handles.ATR == INVALID_HANDLE) {
      Print("Erreur d'initialisation de l'ATR");
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
   if(handles.ATR != INVALID_HANDLE) IndicatorRelease(handles.ATR);
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
   if(CopyBuffer(handles.BB, 0, 0, bars, buffers.BBUpper) < bars) return false;
   if(CopyBuffer(handles.BB, 1, 0, bars, buffers.BBMiddle) < bars) return false;
   if(CopyBuffer(handles.BB, 2, 0, bars, buffers.BBLower) < bars) return false;
   
   // Copier les données du RSI
   if(CopyBuffer(handles.RSI, 0, 0, bars, buffers.RSI) < bars) return false;
   
   // Copier les données de l'ATR
   if(CopyBuffer(handles.ATR, 0, 0, bars, buffers.ATR) < bars) return false;
   
   // Copier les données de l'EMA (optionnel)
   if(useEMA && handles.EMA != INVALID_HANDLE) {
      if(CopyBuffer(handles.EMA, 0, 0, bars, buffers.EMA) < bars) return false;
   }
   
   // Définir les tableaux comme séries pour un accès plus intuitif
   ArraySetAsSeries(buffers.BBUpper, true);
   ArraySetAsSeries(buffers.BBMiddle, true);
   ArraySetAsSeries(buffers.BBLower, true);
   ArraySetAsSeries(buffers.RSI, true);
   ArraySetAsSeries(buffers.ATR, true);
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

// Détecte si une bougie est "libre" (en dehors des bandes de Bollinger)
bool IsFreeCandle(
   MqlRates &candle, 
   double upperBand, 
   double lowerBand, 
   double paddingPoints = 0, 
   bool bodyOnly = true
) {
   // Calculer la marge
   double padding = paddingPoints * _Point;
   
   // Vérifier si la bougie est à l'extérieur des bandes
   if(bodyOnly) {
      // Vérifier uniquement le corps de la bougie
      double bodyHigh = MathMax(candle.open, candle.close);
      double bodyLow = MathMin(candle.open, candle.close);
      
      // Bougie au-dessus de la bande supérieure
      bool isAbove = (bodyLow >= upperBand + padding);
      
      // Bougie en-dessous de la bande inférieure
      bool isBelow = (bodyHigh <= lowerBand - padding);
      
      return isAbove || isBelow;
   } else {
      // Vérifier toute la bougie (incluant les mèches)
      // Bougie au-dessus de la bande supérieure
      bool isAbove = (candle.low >= upperBand + padding);
      
      // Bougie en-dessous de la bande inférieure
      bool isBelow = (candle.high <= lowerBand - padding);
      
      return isAbove || isBelow;
   }
}

// Surcharge permettant d'utiliser directement les valeurs de prix
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
   // Calculer la marge
   double padding = paddingPoints * _Point;
   
   // Valeurs pour le log
   string details = "";
   
   // Vérifier si la bougie est à l'extérieur des bandes
   if(bodyOnly) {
      // Vérifier uniquement le corps de la bougie
      double bodyHigh = MathMax(open, close);
      double bodyLow = MathMin(open, close);
      
      // Bougie au-dessus de la bande supérieure
      bool isAbove = (bodyLow >= upperBand + padding);
      
      // Bougie en-dessous de la bande inférieure
      bool isBelow = (bodyHigh <= lowerBand - padding);
      
      // Pour debug: expliquer pourquoi la candle est considérée libre ou non
      if(isAbove) {
         details = "Corps au-dessus de la bande: bodyLow=" + DoubleToString(bodyLow, 5) + 
                   " >= upperBand+padding=" + DoubleToString(upperBand + padding, 5);
      } else if(isBelow) {
         details = "Corps en-dessous de la bande: bodyHigh=" + DoubleToString(bodyHigh, 5) + 
                   " <= lowerBand-padding=" + DoubleToString(lowerBand - padding, 5);
      } else {
         details = "Corps dans les bandes: bodyLow=" + DoubleToString(bodyLow, 5) + 
                   " < upperBand+padding=" + DoubleToString(upperBand + padding, 5) +
                   " ET bodyHigh=" + DoubleToString(bodyHigh, 5) + 
                   " > lowerBand-padding=" + DoubleToString(lowerBand - padding, 5);
      }
      
      Print("IsFreeCandle check (bodyOnly): " + details);
      return isAbove || isBelow;
   } else {
      // Vérifier toute la bougie (incluant les mèches)
      // Bougie au-dessus de la bande supérieure
      bool isAbove = (low >= upperBand + padding);
      
      // Bougie en-dessous de la bande inférieure
      bool isBelow = (high <= lowerBand - padding);
      
      // Pour debug: expliquer pourquoi la candle est considérée libre ou non
      if(isAbove) {
         details = "Bougie au-dessus de la bande: low=" + DoubleToString(low, 5) + 
                   " >= upperBand+padding=" + DoubleToString(upperBand + padding, 5);
      } else if(isBelow) {
         details = "Bougie en-dessous de la bande: high=" + DoubleToString(high, 5) + 
                   " <= lowerBand-padding=" + DoubleToString(lowerBand - padding, 5);
      } else {
         details = "Bougie dans les bandes: low=" + DoubleToString(low, 5) + 
                   " < upperBand+padding=" + DoubleToString(upperBand + padding, 5) +
                   " ET high=" + DoubleToString(high, 5) + 
                   " > lowerBand-padding=" + DoubleToString(lowerBand - padding, 5);
      }
      
      Print("IsFreeCandle check (!bodyOnly): " + details);
      return isAbove || isBelow;
   }
}