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
   
   // Filtres d'inclinaison et amplitude
   int     m_minBarsBetweenPivots;
   double  m_minAnglePriceDeg;
   double  m_minAngleRSIDeg;
   double  m_minPricePct;
   double  m_minRSIPoints;
   bool    m_useATRNorm;
   int     m_atrPeriod;
   double  m_minATRMult;
   
   FreeCandleMemory m_memory;

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
      
      // Filtres par défaut
      m_minBarsBetweenPivots = 5;
      m_minAnglePriceDeg = 10.0;
      m_minAngleRSIDeg = 10.0;
      m_minPricePct = 0.20;
      m_minRSIPoints = 4.0;
      m_useATRNorm = true;
      m_atrPeriod = 14;
      m_minATRMult = 0.5;
      
      ClearMemory();
   }
   
   ~JTDivergenceValidator()
   {
      if(m_rsiHandle != INVALID_HANDLE) {
         IndicatorRelease(m_rsiHandle);
      }
   }
   
   // Initialisation
   bool Init(string symbol, ENUM_TIMEFRAMES tf, int rsiPeriod, double rsiBuyLevel, double rsiSellLevel, int swingLength,
             int minBarsBetweenPivots = 5, double minAnglePriceDeg = 10.0, double minAngleRSIDeg = 10.0,
             double minPricePct = 0.20, double minRSIPoints = 4.0, bool useATRNorm = true,
             int atrPeriod = 14, double minATRMult = 0.5)
   {
      m_symbol = symbol;
      m_tf = tf;
      m_rsiPeriod = rsiPeriod;
      m_rsiBuyLevel = rsiBuyLevel;
      m_rsiSellLevel = rsiSellLevel;
      m_swingLength = swingLength;
      
      // Filtres d'inclinaison
      m_minBarsBetweenPivots = minBarsBetweenPivots;
      m_minAnglePriceDeg = minAnglePriceDeg;
      m_minAngleRSIDeg = minAngleRSIDeg;
      m_minPricePct = minPricePct;
      m_minRSIPoints = minRSIPoints;
      m_useATRNorm = useATRNorm;
      m_atrPeriod = atrPeriod;
      m_minATRMult = minATRMult;
      
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
   // Calcule l'angle en degrés à partir de dy/dx
   double AngleDeg(double dy, double dx)
   {
      if(dx == 0) return 0.0;
      return MathArctan(dy / dx) * 180.0 / M_PI;
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
   // Avec filtres d'inclinaison et amplitude
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
      
      int olderPivot = pivots[1];   // i1 - Plus ancien
      int recentPivot = pivots[0];  // i2 - Plus récent
      
      // Vérifier distance minimale entre pivots
      int barsBetween = olderPivot - recentPivot;
      if(barsBetween < m_minBarsBetweenPivots) {
         LogMessage("Pivots trop proches: " + IntegerToString(barsBetween) + " < " + 
                    IntegerToString(m_minBarsBetweenPivots), "DIVERGENCE");
         return false;
      }
      
      double p1 = GetLow(olderPivot);    // Prix ancien
      double p2 = GetLow(recentPivot);   // Prix récent
      double r1 = GetRSI(olderPivot);    // RSI ancien
      double r2 = GetRSI(recentPivot);   // RSI récent
      
      if(p1 == 0.0 || p2 == 0.0 || r1 == 0.0 || r2 == 0.0) {
         return false;
      }
      
      // Deltas
      double dx = (double)barsBetween;     // Espacement en barres
      double dP = p2 - p1;                 // Delta prix (doit être < 0 pour LL)
      double dR = r2 - r1;                 // Delta RSI (doit être > 0 pour HL)
      double pct = 100.0 * (p1 > 0 ? MathAbs(dP) / p1 : 0.0);
      
      // Angles (négatif car on va de i1 vers i2, donc dx négatif dans le temps)
      double aPrice = AngleDeg(dP, -dx);   // Pente prix
      double aRSI = AngleDeg(dR, -dx);     // Pente RSI
      
      // Filtres de base
      bool priceLowerLow = (p2 < p1);
      bool rsiHigherLow = (r2 > r1);
      
      if(!(priceLowerLow && rsiHigherLow)) {
         return false;
      }
      
      // Filtres d'inclinaison: Prix descend (angle négatif), RSI monte (angle positif)
      if(aPrice >= -m_minAnglePriceDeg) {
         LogMessage("Angle prix insuffisant: " + DoubleToString(aPrice, 2) + "° >= -" + 
                    DoubleToString(m_minAnglePriceDeg, 1) + "°", "DIVERGENCE");
         return false;
      }
      
      if(aRSI <= m_minAngleRSIDeg) {
         LogMessage("Angle RSI insuffisant: " + DoubleToString(aRSI, 2) + "° <= " + 
                    DoubleToString(m_minAngleRSIDeg, 1) + "°", "DIVERGENCE");
         return false;
      }
      
      // Filtre amplitude prix
      if(pct < m_minPricePct) {
         LogMessage("Delta prix % insuffisant: " + DoubleToString(pct, 3) + "% < " + 
                    DoubleToString(m_minPricePct, 2) + "%", "DIVERGENCE");
         return false;
      }
      
      // Filtre amplitude RSI
      if(MathAbs(dR) < m_minRSIPoints) {
         LogMessage("Delta RSI insuffisant: " + DoubleToString(MathAbs(dR), 2) + " < " + 
                    DoubleToString(m_minRSIPoints, 1), "DIVERGENCE");
         return false;
      }
      
      // Normalisation ATR optionnelle
      if(m_useATRNorm) {
         double atr = iATR(m_symbol, m_tf, m_atrPeriod, recentPivot);
         if(atr > 0) {
            if(MathAbs(dP) < m_minATRMult * atr) {
               LogMessage("Delta prix vs ATR insuffisant: " + DoubleToString(MathAbs(dP), 5) + 
                         " < " + DoubleToString(m_minATRMult * atr, 5), "DIVERGENCE");
               return false;
            }
         }
      }
      
      // Tous les filtres passés !
      LogMessage("✓ Divergence haussière VALIDE: Prix(" + DoubleToString(p1, 5) + " → " + 
                 DoubleToString(p2, 5) + " | " + DoubleToString(aPrice, 1) + "°), RSI(" + 
                 DoubleToString(r1, 2) + " → " + DoubleToString(r2, 2) + " | " + 
                 DoubleToString(aRSI, 1) + "°)", "DIVERGENCE");
      return true;
   }
   
   // Divergence baissière: Prix fait un HH (Higher High) mais RSI fait un LH (Lower High)
   // Avec filtres d'inclinaison et amplitude
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
      
      int olderPivot = pivots[1];   // i1 - Plus ancien
      int recentPivot = pivots[0];  // i2 - Plus récent
      
      // Vérifier distance minimale entre pivots
      int barsBetween = olderPivot - recentPivot;
      if(barsBetween < m_minBarsBetweenPivots) {
         LogMessage("Pivots trop proches: " + IntegerToString(barsBetween) + " < " + 
                    IntegerToString(m_minBarsBetweenPivots), "DIVERGENCE");
         return false;
      }
      
      double p1 = GetHigh(olderPivot);   // Prix ancien
      double p2 = GetHigh(recentPivot);  // Prix récent
      double r1 = GetRSI(olderPivot);    // RSI ancien
      double r2 = GetRSI(recentPivot);   // RSI récent
      
      if(p1 == 0.0 || p2 == 0.0 || r1 == 0.0 || r2 == 0.0) {
         return false;
      }
      
      // Deltas
      double dx = (double)barsBetween;     // Espacement en barres
      double dP = p2 - p1;                 // Delta prix (doit être > 0 pour HH)
      double dR = r2 - r1;                 // Delta RSI (doit être < 0 pour LH)
      double pct = 100.0 * (p1 > 0 ? MathAbs(dP) / p1 : 0.0);
      
      // Angles
      double aPrice = AngleDeg(dP, -dx);   // Pente prix
      double aRSI = AngleDeg(dR, -dx);     // Pente RSI
      
      // Filtres de base
      bool priceHigherHigh = (p2 > p1);
      bool rsiLowerHigh = (r2 < r1);
      
      if(!(priceHigherHigh && rsiLowerHigh)) {
         return false;
      }
      
      // Filtres d'inclinaison: Prix monte (angle positif), RSI descend (angle négatif)
      if(aPrice <= m_minAnglePriceDeg) {
         LogMessage("Angle prix insuffisant: " + DoubleToString(aPrice, 2) + "° <= " + 
                    DoubleToString(m_minAnglePriceDeg, 1) + "°", "DIVERGENCE");
         return false;
      }
      
      if(aRSI >= -m_minAngleRSIDeg) {
         LogMessage("Angle RSI insuffisant: " + DoubleToString(aRSI, 2) + "° >= -" + 
                    DoubleToString(m_minAngleRSIDeg, 1) + "°", "DIVERGENCE");
         return false;
      }
      
      // Filtre amplitude prix
      if(pct < m_minPricePct) {
         LogMessage("Delta prix % insuffisant: " + DoubleToString(pct, 3) + "% < " + 
                    DoubleToString(m_minPricePct, 2) + "%", "DIVERGENCE");
         return false;
      }
      
      // Filtre amplitude RSI
      if(MathAbs(dR) < m_minRSIPoints) {
         LogMessage("Delta RSI insuffisant: " + DoubleToString(MathAbs(dR), 2) + " < " + 
                    DoubleToString(m_minRSIPoints, 1), "DIVERGENCE");
         return false;
      }
      
      // Normalisation ATR optionnelle
      if(m_useATRNorm) {
         double atr = iATR(m_symbol, m_tf, m_atrPeriod, recentPivot);
         if(atr > 0) {
            if(MathAbs(dP) < m_minATRMult * atr) {
               LogMessage("Delta prix vs ATR insuffisant: " + DoubleToString(MathAbs(dP), 5) + 
                         " < " + DoubleToString(m_minATRMult * atr, 5), "DIVERGENCE");
               return false;
            }
         }
      }
      
      // Tous les filtres passés !
      LogMessage("✓ Divergence baissière VALIDE: Prix(" + DoubleToString(p1, 5) + " → " + 
                 DoubleToString(p2, 5) + " | " + DoubleToString(aPrice, 1) + "°), RSI(" + 
                 DoubleToString(r1, 2) + " → " + DoubleToString(r2, 2) + " | " + 
                 DoubleToString(aRSI, 1) + "°)", "DIVERGENCE");
      return true;
   }
};

