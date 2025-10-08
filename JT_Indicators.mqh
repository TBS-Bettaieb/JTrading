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
