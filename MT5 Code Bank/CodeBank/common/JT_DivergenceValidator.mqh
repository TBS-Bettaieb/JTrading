//+------------------------------------------------------------------+
//|                                      JT_DivergenceValidator.mqh  |
//|                        Validateur de divergence RSI/Prix         |
//+------------------------------------------------------------------+
#property strict

// Structure pour mémoriser un Free Candle
struct FreeCandleMemory {
   bool isActive;
   int barIndex;
   datetime time;
   double priceLevel;
   int direction;  // +1 pour buy, -1 pour sell
};

// Classe de validation de divergence
class JTDivergenceValidator
{
private:
   string  m_symbol;
   ENUM_TIMEFRAMES m_tf;
   int     m_rsiHandle;
   int     m_rsiPeriod;
   double  m_rsiBuyLevel;      // Seuil pour buy (défaut 35)
   double  m_rsiSellLevel;     // Seuil pour sell (défaut 65)
   int     m_swingLength;      // Longueur pour détecter les pivots
   
   FreeCandleMemory m_memory;
   
   // Données de la dernière divergence détectée
   double  m_lastDivAngle;
   double  m_lastDivStrength;
   int     m_lastDivBars;

public:
   JTDivergenceValidator()
   {
      m_symbol = "";
      m_tf = PERIOD_CURRENT;
      m_rsiHandle = INVALID_HANDLE;
      m_rsiPeriod = 14;
      m_rsiBuyLevel = 35.0;
      m_rsiSellLevel = 65.0;
      m_swingLength = 5;
      m_lastDivAngle = 0.0;
      m_lastDivStrength = 0.0;
      m_lastDivBars = 0;
      ClearMemory();
   }
   
   ~JTDivergenceValidator()
   {
      if(m_rsiHandle != INVALID_HANDLE) {
         IndicatorRelease(m_rsiHandle);
      }
   }
   
   // Initialisation
   bool Init(string symbol, ENUM_TIMEFRAMES tf, int rsiPeriod, double rsiBuyLevel, double rsiSellLevel, int swingLength)
   {
      m_symbol = symbol;
      m_tf = tf;
      m_rsiPeriod = rsiPeriod;
      m_rsiBuyLevel = rsiBuyLevel;
      m_rsiSellLevel = rsiSellLevel;
      m_swingLength = swingLength;
      
      // Créer le handle RSI (sera différent du RSI principal si nécessaire)
      m_rsiHandle = iRSI(m_symbol, m_tf, m_rsiPeriod, PRICE_CLOSE);
      if(m_rsiHandle == INVALID_HANDLE) {
         Print("Erreur création RSI pour divergence validator");
         return false;
      }
      
      return true;
   }
   
   // Mémoriser un Free Candle
   void RememberFreeCandle(int barIndex, double priceLevel, int direction)
   {
      m_memory.isActive = true;
      m_memory.barIndex = barIndex;
      m_memory.priceLevel = priceLevel;
      m_memory.direction = direction;
      
      MqlRates rates[1];
      if(CopyRates(m_symbol, m_tf, barIndex, 1, rates) > 0) {
         m_memory.time = rates[0].time;
      }
      
      LogMessage("Free Candle mémorisé: bar=" + IntegerToString(barIndex) + 
                 ", direction=" + (direction > 0 ? "BUY" : "SELL") + 
                 ", price=" + DoubleToString(priceLevel, 5), "DIVERGENCE");
   }
   
   // Effacer la mémoire
   void ClearMemory()
   {
      m_memory.isActive = false;
      m_memory.barIndex = -1;
      m_memory.time = 0;
      m_memory.priceLevel = 0.0;
      m_memory.direction = 0;
   }
   
   // Vérifier si on a un Free Candle en mémoire
   bool HasFreeCandle() { return m_memory.isActive; }
   
   // Obtenir la direction du Free Candle en mémoire
   int GetMemorizedDirection() { return m_memory.direction; }
   
   // Getters pour les métriques de la dernière divergence
   double GetLastDivergenceAngle() { return m_lastDivAngle; }
   double GetLastDivergenceStrength() { return m_lastDivStrength; }
   int GetLastDivergenceBars() { return m_lastDivBars; }
   
   // Validation principale: à appeler sur nouvelle barre
   // Retourne: 0 = pas de signal, +1 = buy validé, -1 = sell validé
   int ValidateDivergence()
   {
      if(!HasFreeCandle()) return 0;
      
      // Lire RSI actuel
      double rsi[];
      ArraySetAsSeries(rsi, true);
      if(CopyBuffer(m_rsiHandle, 0, 1, 1, rsi) <= 0) {
         LogMessage("Erreur lecture RSI pour validation", "DIVERGENCE");
         return 0;
      }
      
      double currentRSI = rsi[0];
      
      // Validation pour BUY
      if(m_memory.direction > 0) {
         // Si RSI > seuil buy, invalider
         if(currentRSI > m_rsiBuyLevel) {
            LogMessage("Free Candle BUY invalidé: RSI " + DoubleToString(currentRSI, 2) + 
                      " > " + DoubleToString(m_rsiBuyLevel, 2), "DIVERGENCE");
            ClearMemory();
            return 0;
         }
         
         // Vérifier divergence haussière
         if(IsBullishDivergence()) {
            LogMessage("✓ Divergence haussière confirmée avec RSI=" + DoubleToString(currentRSI, 2), "DIVERGENCE");
            ClearMemory();  // One-shot
            return +1;
         }
      }
      
      // Validation pour SELL
      if(m_memory.direction < 0) {
         // Si RSI < seuil sell, invalider
         if(currentRSI < m_rsiSellLevel) {
            LogMessage("Free Candle SELL invalidé: RSI " + DoubleToString(currentRSI, 2) + 
                      " < " + DoubleToString(m_rsiSellLevel, 2), "DIVERGENCE");
            ClearMemory();
            return 0;
         }
         
         // Vérifier divergence baissière
         if(IsBearishDivergence()) {
            LogMessage("✓ Divergence baissière confirmée avec RSI=" + DoubleToString(currentRSI, 2), "DIVERGENCE");
            ClearMemory();  // One-shot
            return -1;
         }
      }
      
      return 0;
   }

private:
   // Calculer l'angle de la divergence en degrés
   double CalculateDivergenceAngle(double price1, double price2, int bars)
   {
      if(bars == 0) return 0.0;
      
      double priceDiff = MathAbs(price2 - price1);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Normaliser par la valeur du pip pour avoir une échelle cohérente
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double pipSize = (digits == 3 || digits == 5) ? 10.0 : 1.0;
      double priceDiffPips = (priceDiff / point) / pipSize;
      
      // Échelle de temps en heures pour un angle plus réaliste
      int tfSeconds = PeriodSeconds(m_tf);
      double timeBarsInHours = (bars * tfSeconds) / 3600.0;
      
      // Si moins d'1 heure, utiliser directement les barres
      if(timeBarsInHours < 1.0) timeBarsInHours = bars;
      
      // Angle = arctan(pips / temps) en degrés
      double angle = MathArctan(priceDiffPips / timeBarsInHours) * 180.0 / M_PI;
      return angle;
   }
   
   // Calculer la force de la divergence
   double CalculateDivergenceStrength(double rsiDiff, double priceDiff)
   {
      if(priceDiff == 0.0) return 0.0;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double priceDiffPoints = priceDiff / point;
      
      // Force = différence RSI / différence prix en points
      return rsiDiff / priceDiffPoints;
   }
   
   // Obtenir le low d'une barre
   double GetLow(int shift)
   {
      double lows[];
      if(CopyLow(m_symbol, m_tf, shift, 1, lows) <= 0) return 0.0;
      return lows[0];
   }
   
   // Obtenir le high d'une barre
   double GetHigh(int shift)
   {
      double highs[];
      if(CopyHigh(m_symbol, m_tf, shift, 1, highs) <= 0) return 0.0;
      return highs[0];
   }
   
   // Obtenir le RSI d'une barre
   double GetRSI(int shift)
   {
      double rsi[];
      ArraySetAsSeries(rsi, true);
      if(CopyBuffer(m_rsiHandle, 0, shift, 1, rsi) <= 0) return 0.0;
      return rsi[0];
   }
   
   // Détecter un creux local (swing low)
   bool IsSwingLow(int index)
   {
      double centerLow = GetLow(index);
      if(centerLow == 0.0) return false;
      
      for(int k = 1; k <= m_swingLength; k++) {
         double leftLow = GetLow(index - k);
         double rightLow = GetLow(index + k);
         
         if(leftLow == 0.0 || rightLow == 0.0) return false;
         if(centerLow >= leftLow || centerLow >= rightLow) return false;
      }
      
      return true;
   }
   
   // Détecter un sommet local (swing high)
   bool IsSwingHigh(int index)
   {
      double centerHigh = GetHigh(index);
      if(centerHigh == 0.0) return false;
      
      for(int k = 1; k <= m_swingLength; k++) {
         double leftHigh = GetHigh(index - k);
         double rightHigh = GetHigh(index + k);
         
         if(leftHigh == 0.0 || rightHigh == 0.0) return false;
         if(centerHigh <= leftHigh || centerHigh <= rightHigh) return false;
      }
      
      return true;
   }
   
   // Divergence haussière: Prix fait un LL (Lower Low) mais RSI fait un HL (Higher Low)
   bool IsBullishDivergence()
   {
      int barsAvailable = Bars(m_symbol, m_tf);
      int maxBars = MathMin(200, barsAvailable - m_swingLength - 1);
      
      int pivots[2];
      int found = 0;
      
      // Trouver les 2 derniers creux de prix
      for(int i = 2; i < maxBars && found < 2; i++) {
         if(IsSwingLow(i)) {
            pivots[found++] = i;
         }
      }
      
      if(found < 2) {
         LogMessage("Pas assez de pivots pour divergence haussière", "DIVERGENCE");
         return false;
      }
      
      int recentPivot = pivots[0];  // Plus récent
      int olderPivot = pivots[1];   // Plus ancien
      
      double recentLow = GetLow(recentPivot);
      double olderLow = GetLow(olderPivot);
      double recentRSI = GetRSI(recentPivot);
      double olderRSI = GetRSI(olderPivot);
      
      if(recentLow == 0.0 || olderLow == 0.0 || recentRSI == 0.0 || olderRSI == 0.0) {
         return false;
      }
      
      bool priceLowerLow = (recentLow < olderLow);
      bool rsiHigherLow = (recentRSI > olderRSI);
      
      if(priceLowerLow && rsiHigherLow) {
         // Calculer les métriques de divergence
         double priceDiff = MathAbs(olderLow - recentLow);
         double rsiDiff = MathAbs(recentRSI - olderRSI);
         int bars = olderPivot - recentPivot;
         
         m_lastDivAngle = CalculateDivergenceAngle(olderLow, recentLow, bars);
         m_lastDivStrength = CalculateDivergenceStrength(rsiDiff, priceDiff);
         m_lastDivBars = bars;
         
         LogMessage("Divergence haussière détectée: Prix(" + DoubleToString(olderLow, 5) + " → " + 
                    DoubleToString(recentLow, 5) + "), RSI(" + DoubleToString(olderRSI, 2) + 
                    " → " + DoubleToString(recentRSI, 2) + "), Angle=" + DoubleToString(m_lastDivAngle, 2) + 
                    "°, Force=" + DoubleToString(m_lastDivStrength, 6) + ", Bars=" + IntegerToString(m_lastDivBars), "DIVERGENCE");
         return true;
      }
      
      return false;
   }
   
   // Divergence baissière: Prix fait un HH (Higher High) mais RSI fait un LH (Lower High)
   bool IsBearishDivergence()
   {
      int barsAvailable = Bars(m_symbol, m_tf);
      int maxBars = MathMin(200, barsAvailable - m_swingLength - 1);
      
      int pivots[2];
      int found = 0;
      
      // Trouver les 2 derniers sommets de prix
      for(int i = 2; i < maxBars && found < 2; i++) {
         if(IsSwingHigh(i)) {
            pivots[found++] = i;
         }
      }
      
      if(found < 2) {
         LogMessage("Pas assez de pivots pour divergence baissière", "DIVERGENCE");
         return false;
      }
      
      int recentPivot = pivots[0];  // Plus récent
      int olderPivot = pivots[1];   // Plus ancien
      
      double recentHigh = GetHigh(recentPivot);
      double olderHigh = GetHigh(olderPivot);
      double recentRSI = GetRSI(recentPivot);
      double olderRSI = GetRSI(olderPivot);
      
      if(recentHigh == 0.0 || olderHigh == 0.0 || recentRSI == 0.0 || olderRSI == 0.0) {
         return false;
      }
      
      bool priceHigherHigh = (recentHigh > olderHigh);
      bool rsiLowerHigh = (recentRSI < olderRSI);
      
      if(priceHigherHigh && rsiLowerHigh) {
         // Calculer les métriques de divergence
         double priceDiff = MathAbs(recentHigh - olderHigh);
         double rsiDiff = MathAbs(olderRSI - recentRSI);
         int bars = olderPivot - recentPivot;
         
         m_lastDivAngle = CalculateDivergenceAngle(olderHigh, recentHigh, bars);
         m_lastDivStrength = CalculateDivergenceStrength(rsiDiff, priceDiff);
         m_lastDivBars = bars;
         
         LogMessage("Divergence baissière détectée: Prix(" + DoubleToString(olderHigh, 5) + " → " + 
                    DoubleToString(recentHigh, 5) + "), RSI(" + DoubleToString(olderRSI, 2) + 
                    " → " + DoubleToString(recentRSI, 2) + "), Angle=" + DoubleToString(m_lastDivAngle, 2) + 
                    "°, Force=" + DoubleToString(m_lastDivStrength, 6) + ", Bars=" + IntegerToString(m_lastDivBars), "DIVERGENCE");
         return true;
      }
      
      return false;
   }
};

