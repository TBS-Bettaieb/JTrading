//+------------------------------------------------------------------+
//|                                     RSI_DivergenceDetector.mqh   |
//|                           Détecteur de Divergences RSI           |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Enumération des types de divergence                              |
//+------------------------------------------------------------------+
enum ENUM_DIVERGENCE_TYPE
  {
   DIV_NONE = 0,              // Aucune divergence
   DIV_REGULAR_BULLISH = 1,   // Divergence régulière haussière (Prix ↓ RSI ↑)
   DIV_REGULAR_BEARISH = -1   // Divergence régulière baissière (Prix ↑ RSI ↓)
  };

//+------------------------------------------------------------------+
//| Classe de détection de divergences RSI                           |
//+------------------------------------------------------------------+
class CRSIDivergenceDetector
  {
private:
   // Paramètres de configuration (correspondant à l'indicateur)
   int               m_lookbackLeft;     // Lookback Left (barres à gauche du pivot)
   int               m_lookbackRight;    // Lookback Right (barres à droite du pivot)
   int               m_rangeLower;       // Range Lower (distance min entre pivots)
   int               m_rangeUpper;       // Range Upper (distance max entre pivots)
   double            m_upperLevel;       // Niveau RSI surachat
   double            m_lowerLevel;       // Niveau RSI survente
   double            m_minDivStrength;   // Force minimum en % (optionnel)

   //--- Vérifier si une position est un pivot RSI bas (adapté de l'indicateur)
   bool IsPivotLow(int pos, int leftBars, int rightBars, const double &buffer[])
     {
      // Validation des limites
      if(pos < 0 || pos >= ArraySize(buffer))
         return false;
      
      // Vérifier qu'on a assez de barres de chaque côté
      if(pos < rightBars || pos + leftBars >= ArraySize(buffer))
         return false;
      
      double pivotValue = buffer[pos];
      
      // Vérifier que pos est le MINIMUM dans la fenêtre
      // De pos-rightBars à pos+leftBars (inclusif)
      // Si une valeur est STRICTEMENT inférieure, ce n'est pas un pivot
      for(int i = pos - rightBars; i <= pos + leftBars; i++)
        {
         // Ne pas comparer avec soi-même
         if(i == pos) 
            continue;
         
         // Validation de l'indice
         if(i < 0 || i >= ArraySize(buffer))
            continue;
         
         // Si une valeur est plus petite, ce n'est PAS un pivot bas
         if(buffer[i] < pivotValue)
            return false;
        }
      
      return true; // C'est un pivot bas valide
     }

   //--- Vérifier si une position est un pivot RSI haut (adapté de l'indicateur)
   bool IsPivotHigh(int pos, int leftBars, int rightBars, const double &buffer[])
     {
      // Validation des limites
      if(pos < 0 || pos >= ArraySize(buffer))
         return false;
      
      if(pos < rightBars || pos + leftBars >= ArraySize(buffer))
      return false;
      
      double pivotValue = buffer[pos];
      
      // Vérifier que pos est le MAXIMUM dans la fenêtre
      for(int i = pos - rightBars; i <= pos + leftBars; i++)
        {
         if(i == pos) 
            continue;
         
         if(i < 0 || i >= ArraySize(buffer))
            continue;
         
         // Si une valeur est plus grande, ce n'est PAS un pivot haut
         if(buffer[i] > pivotValue)
            return false;
        }
      
      return true; // C'est un pivot haut valide
     }


public:
   //--- Constructor (adapté aux paramètres de l'indicateur)
   CRSIDivergenceDetector(int lookbackLeft = 3, 
                          int lookbackRight = 1,
                          int rangeLower = 3,
                          int rangeUpper = 100,
                          double upperLevel = 90.0,
                          double lowerLevel = 10.0,
                          double minStrength = 3.0)
     {
      m_lookbackLeft = lookbackLeft;
      m_lookbackRight = lookbackRight;
      m_rangeLower = rangeLower;
      m_rangeUpper = rangeUpper;
      m_upperLevel = upperLevel;
      m_lowerLevel = lowerLevel;
      m_minDivStrength = minStrength;

      Logger::Debug("RSI Divergence Detector initialized");
      Logger::Debug("Lookback Left: " + IntegerToString(lookbackLeft) + 
                    " | Right: " + IntegerToString(lookbackRight));
      Logger::Debug("Range: " + IntegerToString(rangeLower) + 
                    " - " + IntegerToString(rangeUpper));
      Logger::Debug("RSI Levels: " + DoubleToString(lowerLevel, 1) + 
                    " - " + DoubleToString(upperLevel, 1));
     }

   //--- Destructor
   ~CRSIDivergenceDetector()
     {
      Logger::Debug("RSI Divergence Detector destroyed");
     }

   //--- Détecter divergence bullish (adapté de l'indicateur)
   bool DetectBullishDivergence(string symbol, ENUM_TIMEFRAMES tf,
                                int rsiHandle, int confirmBars)
     {
      Logger::Debug("=== DetectBullishDivergence START ===");
      Logger::Debug("Symbol: " + symbol + " | TF: " + EnumToString(tf) + " | ConfirmBars: " + IntegerToString(confirmBars));

      // Vérifier le handle RSI
      if(rsiHandle == INVALID_HANDLE)
        {
         Logger::Error("DetectBullishDivergence: Handle RSI invalide");
         return false;
        }

      // Obtenir le buffer RSI
      double rsiBuffer[];
      ArraySetAsSeries(rsiBuffer, true);

      int copySize = confirmBars + m_rangeUpper + m_lookbackLeft + 10;
      Logger::Debug("CopyBuffer RSI: size=" + IntegerToString(copySize));
      
      if(CopyBuffer(rsiHandle, 0, 0, copySize, rsiBuffer) <= 0)
        {
         Logger::Error("DetectBullishDivergence: Erreur CopyBuffer RSI");
         return false;
        }

      Logger::Debug("Buffer RSI copié: " + IntegerToString(ArraySize(rsiBuffer)) + " valeurs");

      // Scanner les barres pour trouver des pivots RSI
      int startPos = m_lookbackRight + 1;
      int endPos = MathMin(confirmBars, ArraySize(rsiBuffer) - m_lookbackLeft - 1);
      
      Logger::Debug("Scan pivots RSI de " + IntegerToString(startPos) + " à " + IntegerToString(endPos));

      int pivotsChecked = 0;
      int pivotsFound = 0;
      
      for(int checkPos = startPos; checkPos <= endPos; checkPos++)
        {
         // Vérifier si c'est un pivot RSI bas
         if(!IsPivotLow(checkPos, m_lookbackLeft, m_lookbackRight, rsiBuffer))
            continue;

         pivotsChecked++;
         double pivotRSI = rsiBuffer[checkPos];
         
         Logger::Debug("🔍 Pivot RSI trouvé @ bar[" + IntegerToString(checkPos) + "] RSI=" + DoubleToString(pivotRSI, 2));

         // Validation du niveau RSI - doit être dans la zone de survente
         if(pivotRSI > m_lowerLevel)
           {
            Logger::Debug("   ❌ RSI trop élevé (" + DoubleToString(pivotRSI, 2) + " > " + DoubleToString(m_lowerLevel, 1) + ")");
            continue;
           }
         
         Logger::Debug("   ✓ RSI dans zone survente (" + DoubleToString(pivotRSI, 2) + " <= " + DoubleToString(m_lowerLevel, 1) + ")");

         // Recherche du pivot précédent
         int prevPivotBar = -1;
         double prevPivotRSI = 0;

         int maxSearch = MathMin(checkPos + m_rangeUpper, ArraySize(rsiBuffer) - 1);
         int minSearch = MathMax(checkPos + m_rangeLower, m_lookbackRight);
         
         Logger::Debug("   Recherche pivot précédent de bar[" + IntegerToString(minSearch) + "] à bar[" + IntegerToString(maxSearch) + "]");

         for(int i = minSearch; i <= maxSearch; i++)
           {
            if(i < 0 || i >= ArraySize(rsiBuffer))
               continue;

            if(IsPivotLow(i, m_lookbackLeft, m_lookbackRight, rsiBuffer))
              {
               prevPivotBar = i;
               prevPivotRSI = rsiBuffer[i];
               Logger::Debug("   ✓ Pivot précédent trouvé @ bar[" + IntegerToString(i) + "] RSI=" + DoubleToString(prevPivotRSI, 2));
               break; // Premier pivot trouvé
              }
           }

         if(prevPivotBar < 0)
           {
            Logger::Debug("   ❌ Aucun pivot précédent trouvé dans le range");
            continue;
           }

         // ✅ PAS de validation du niveau RSI du pivot précédent
         // Le pivot précédent peut avoir N'IMPORTE QUEL niveau RSI
         Logger::Debug("   ✓ Pivot précédent: RSI=" + DoubleToString(prevPivotRSI, 2) + " (pas de restriction de niveau)");

         // Validation du range
         int barsSincePivot = prevPivotBar - checkPos;
         if(barsSincePivot < m_rangeLower || barsSincePivot > m_rangeUpper)
           {
            Logger::Debug("   ❌ Distance hors range (" + IntegerToString(barsSincePivot) + " barres)");
            continue;
           }
         
         Logger::Debug("   ✓ Distance OK: " + IntegerToString(barsSincePivot) + " barres");

         // Obtenir les prix aux positions des pivots RSI
         double currentPrice = iLow(symbol, tf, checkPos);
         double prevPivotPrice = iLow(symbol, tf, prevPivotBar);

         Logger::Debug("   Prix actuel: " + DoubleToString(currentPrice, _Digits) + " | Prix précédent: " + DoubleToString(prevPivotPrice, _Digits));

         // Conditions de divergence bullish: Prix ↓ et RSI ↑
         bool rsiHigherLow = pivotRSI > prevPivotRSI;
         bool priceLowerLow = currentPrice < prevPivotPrice;

         Logger::Debug("   RSI Higher Low: " + (rsiHigherLow ? "OUI ✓" : "NON ❌") + " (" + DoubleToString(pivotRSI, 2) + " vs " + DoubleToString(prevPivotRSI, 2) + ")");
         Logger::Debug("   Price Lower Low: " + (priceLowerLow ? "OUI ✓" : "NON ❌") + " (" + DoubleToString(currentPrice, _Digits) + " vs " + DoubleToString(prevPivotPrice, _Digits) + ")");

         if(rsiHigherLow && priceLowerLow)
           {
            pivotsFound++;
            Logger::Debug("✅✅✅ DIVERGENCE BULLISH CONFIRMÉE @ Bar[" + IntegerToString(checkPos) + "] ✅✅✅");
            Logger::Debug("   RSI: " + DoubleToString(pivotRSI, 2) + " > " + DoubleToString(prevPivotRSI, 2) + " (+HL)");
            Logger::Debug("   Prix: " + DoubleToString(currentPrice, _Digits) + " < " + DoubleToString(prevPivotPrice, _Digits) + " (-LL)");
            Logger::Debug("=== DetectBullishDivergence END: SUCCESS ===");
         return true;
        }
        }

      Logger::Debug("Pivots RSI vérifiés: " + IntegerToString(pivotsChecked) + " | Divergences trouvées: " + IntegerToString(pivotsFound));
      Logger::Debug("=== DetectBullishDivergence END: NO DIVERGENCE ===");
      return false;
     }

   //--- Détecter divergence bearish (adapté de l'indicateur)
   bool DetectBearishDivergence(string symbol, ENUM_TIMEFRAMES tf,
                                int rsiHandle, int confirmBars)
     {
      Logger::Debug("=== DetectBearishDivergence START ===");
      Logger::Debug("Symbol: " + symbol + " | TF: " + EnumToString(tf) + " | ConfirmBars: " + IntegerToString(confirmBars));

      // Vérifier le handle RSI
      if(rsiHandle == INVALID_HANDLE)
        {
         Logger::Error("DetectBearishDivergence: Handle RSI invalide");
         return false;
        }

      // Obtenir le buffer RSI
      double rsiBuffer[];
      ArraySetAsSeries(rsiBuffer, true);

      int copySize = confirmBars + m_rangeUpper + m_lookbackLeft + 10;
      Logger::Debug("CopyBuffer RSI: size=" + IntegerToString(copySize));
      
      if(CopyBuffer(rsiHandle, 0, 0, copySize, rsiBuffer) <= 0)
        {
         Logger::Error("DetectBearishDivergence: Erreur CopyBuffer RSI");
         return false;
        }

      Logger::Debug("Buffer RSI copié: " + IntegerToString(ArraySize(rsiBuffer)) + " valeurs");

      // Scanner les barres pour trouver des pivots RSI
      int startPos = m_lookbackRight + 1;
      int endPos = MathMin(confirmBars, ArraySize(rsiBuffer) - m_lookbackLeft - 1);
      
      Logger::Debug("Scan pivots RSI de " + IntegerToString(startPos) + " à " + IntegerToString(endPos));

      int pivotsChecked = 0;
      int pivotsFound = 0;
      
      for(int checkPos = startPos; checkPos <= endPos; checkPos++)
        {
         // Vérifier si c'est un pivot RSI haut
         if(!IsPivotHigh(checkPos, m_lookbackLeft, m_lookbackRight, rsiBuffer))
            continue;

         pivotsChecked++;
         double pivotRSI = rsiBuffer[checkPos];
         
         Logger::Debug("🔍 Pivot RSI trouvé @ bar[" + IntegerToString(checkPos) + "] RSI=" + DoubleToString(pivotRSI, 2));

         // Validation du niveau RSI - doit être dans la zone de surachat
         if(pivotRSI < m_upperLevel)
           {
            Logger::Debug("   ❌ RSI trop bas (" + DoubleToString(pivotRSI, 2) + " < " + DoubleToString(m_upperLevel, 1) + ")");
            continue;
           }
         
         Logger::Debug("   ✓ RSI dans zone surachat (" + DoubleToString(pivotRSI, 2) + " >= " + DoubleToString(m_upperLevel, 1) + ")");

         // Recherche du pivot précédent
         int prevPivotBar = -1;
         double prevPivotRSI = 0;

         int maxSearch = MathMin(checkPos + m_rangeUpper, ArraySize(rsiBuffer) - 1);
         int minSearch = MathMax(checkPos + m_rangeLower, m_lookbackRight);
         
         Logger::Debug("   Recherche pivot précédent de bar[" + IntegerToString(minSearch) + "] à bar[" + IntegerToString(maxSearch) + "]");

         for(int i = minSearch; i <= maxSearch; i++)
           {
            if(i < 0 || i >= ArraySize(rsiBuffer))
               continue;

            if(IsPivotHigh(i, m_lookbackLeft, m_lookbackRight, rsiBuffer))
              {
               prevPivotBar = i;
               prevPivotRSI = rsiBuffer[i];
               Logger::Debug("   ✓ Pivot précédent trouvé @ bar[" + IntegerToString(i) + "] RSI=" + DoubleToString(prevPivotRSI, 2));
               break; // Premier pivot trouvé
              }
           }

         if(prevPivotBar < 0)
           {
            Logger::Debug("   ❌ Aucun pivot précédent trouvé dans le range");
            continue;
           }

         // ✅ PAS de validation du niveau RSI du pivot précédent
         // Le pivot précédent peut avoir N'IMPORTE QUEL niveau RSI
         Logger::Debug("   ✓ Pivot précédent: RSI=" + DoubleToString(prevPivotRSI, 2) + " (pas de restriction de niveau)");

         // Validation du range
         int barsSincePivot = prevPivotBar - checkPos;
         if(barsSincePivot < m_rangeLower || barsSincePivot > m_rangeUpper)
           {
            Logger::Debug("   ❌ Distance hors range (" + IntegerToString(barsSincePivot) + " barres)");
            continue;
           }
         
         Logger::Debug("   ✓ Distance OK: " + IntegerToString(barsSincePivot) + " barres");

         // Obtenir les prix aux positions des pivots RSI
         double currentPrice = iHigh(symbol, tf, checkPos);
         double prevPivotPrice = iHigh(symbol, tf, prevPivotBar);

         Logger::Debug("   Prix actuel: " + DoubleToString(currentPrice, _Digits) + " | Prix précédent: " + DoubleToString(prevPivotPrice, _Digits));

         // Conditions de divergence bearish: Prix ↑ et RSI ↓
         bool rsiLowerHigh = pivotRSI < prevPivotRSI;
         bool priceHigherHigh = currentPrice > prevPivotPrice;

         Logger::Debug("   RSI Lower High: " + (rsiLowerHigh ? "OUI ✓" : "NON ❌") + " (" + DoubleToString(pivotRSI, 2) + " vs " + DoubleToString(prevPivotRSI, 2) + ")");
         Logger::Debug("   Price Higher High: " + (priceHigherHigh ? "OUI ✓" : "NON ❌") + " (" + DoubleToString(currentPrice, _Digits) + " vs " + DoubleToString(prevPivotPrice, _Digits) + ")");

         if(rsiLowerHigh && priceHigherHigh)
           {
            pivotsFound++;
            Logger::Debug("✅✅✅ DIVERGENCE BEARISH CONFIRMÉE @ Bar[" + IntegerToString(checkPos) + "] ✅✅✅");
            Logger::Debug("   RSI: " + DoubleToString(pivotRSI, 2) + " < " + DoubleToString(prevPivotRSI, 2) + " (-LH)");
            Logger::Debug("   Prix: " + DoubleToString(currentPrice, _Digits) + " > " + DoubleToString(prevPivotPrice, _Digits) + " (+HH)");
            Logger::Debug("=== DetectBearishDivergence END: SUCCESS ===");
         return true;
           }
        }

      Logger::Debug("Pivots RSI vérifiés: " + IntegerToString(pivotsChecked) + " | Divergences trouvées: " + IntegerToString(pivotsFound));
      Logger::Debug("=== DetectBearishDivergence END: NO DIVERGENCE ===");
      return false;
     }

   //+------------------------------------------------------------------+
   //| Chercher divergence bullish dans le FUTUR depuis un point donné |
   //| pivotBar : Barre du signal 3 RSI (point de départ)              |
   //| pivotRSI : Valeur RSI au moment du signal                       |
   //| pivotPrice : Prix au moment du signal                           |
   //| futureBarLimit : Combien de barres scanner dans le futur        |
   //+------------------------------------------------------------------+
   bool DetectBullishDivergenceInFuture(string symbol, ENUM_TIMEFRAMES tf,
                                        int rsiHandle,
                                        int pivotBar,
                                        double pivotRSI,
                                        double pivotPrice,
                                        int futureBarLimit)
     {
      Logger::Debug("=== DetectBullishDivergenceInFuture START ===");
      Logger::Debug("Pivot Initial @ bar[" + IntegerToString(pivotBar) + 
                    "] RSI=" + DoubleToString(pivotRSI, 2) + 
                    " Prix=" + DoubleToString(pivotPrice, _Digits));
      
      if(rsiHandle == INVALID_HANDLE)
        {
         Logger::Error("Handle RSI invalide");
         return false;
        }
      
      // Obtenir buffer RSI
      double rsiBuffer[];
      ArraySetAsSeries(rsiBuffer, true);
      
      int copySize = pivotBar + futureBarLimit + m_lookbackLeft + 10;
      if(CopyBuffer(rsiHandle, 0, 0, copySize, rsiBuffer) <= 0)
        {
         Logger::Error("Erreur CopyBuffer RSI");
         return false;
        }
      
      Logger::Debug("Buffer RSI copié: " + IntegerToString(ArraySize(rsiBuffer)) + " valeurs");
      
      // Scanner les barres APRÈS le signal (dans le futur)
      // pivotBar = barre du signal initial (ex: 7 si détecté il y a 7 barres)
      // On cherche un nouveau pivot entre [pivotBar-futureBarLimit] et [0]
      int searchStart = MathMax(m_lookbackRight, pivotBar - futureBarLimit);
      int searchEnd = MathMax(0, pivotBar - 1);
      
      Logger::Debug("Recherche nouveau pivot de bar[" + 
                    IntegerToString(searchStart) + "] à bar[" + 
                    IntegerToString(searchEnd) + "]");
      
      int pivotsChecked = 0;
      
      // Scanner pour trouver un NOUVEAU pivot bas
      for(int newPivotBar = searchStart; newPivotBar <= searchEnd; newPivotBar++)
        {
         if(!IsPivotLow(newPivotBar, m_lookbackLeft, m_lookbackRight, rsiBuffer))
            continue;
         
         pivotsChecked++;
         double newPivotRSI = rsiBuffer[newPivotBar];
         
         Logger::Debug("🔍 Nouveau pivot trouvé @ bar[" + 
                       IntegerToString(newPivotBar) + "] RSI=" + 
                       DoubleToString(newPivotRSI, 2));
         
         // Validation niveau RSI du nouveau pivot
         if(newPivotRSI > m_lowerLevel)
           {
            Logger::Debug("   ❌ RSI trop élevé (" + DoubleToString(newPivotRSI, 2) + " > " + DoubleToString(m_lowerLevel, 1) + ")");
            continue;
           }
         
         Logger::Debug("   ✓ RSI dans zone survente (" + DoubleToString(newPivotRSI, 2) + " <= " + DoubleToString(m_lowerLevel, 1) + ")");
         
         // Validation du range (distance entre les 2 pivots)
         int barsBetween = pivotBar - newPivotBar;
         if(barsBetween < m_rangeLower || barsBetween > m_rangeUpper)
           {
            Logger::Debug("   ❌ Distance hors range: " + IntegerToString(barsBetween) + " barres");
            continue;
           }
         
         Logger::Debug("   ✓ Distance OK: " + IntegerToString(barsBetween) + " barres");
         
         // Obtenir le prix du nouveau pivot
         double newPivotPrice = iLow(symbol, tf, newPivotBar);
         
         Logger::Debug("   Prix nouveau pivot: " + DoubleToString(newPivotPrice, _Digits));
         Logger::Debug("   Prix pivot initial: " + DoubleToString(pivotPrice, _Digits));
         
         // CONDITIONS DE DIVERGENCE BULLISH:
         // Le NOUVEAU pivot (plus récent) doit avoir:
         //   - Prix PLUS BAS que le pivot initial
         //   - RSI PLUS HAUT que le pivot initial
         bool priceLowerLow = newPivotPrice < pivotPrice;
         bool rsiHigherLow = newPivotRSI > pivotRSI;
         
         Logger::Debug("   Prix Lower Low: " + (priceLowerLow ? "OUI ✓" : "NON ❌") + 
                       " (" + DoubleToString(newPivotPrice, _Digits) + " vs " + DoubleToString(pivotPrice, _Digits) + ")");
         Logger::Debug("   RSI Higher Low: " + (rsiHigherLow ? "OUI ✓" : "NON ❌") + 
                       " (" + DoubleToString(newPivotRSI, 2) + " vs " + DoubleToString(pivotRSI, 2) + ")");
         
         if(priceLowerLow && rsiHigherLow)
           {
            Logger::Debug("✅✅✅ DIVERGENCE BULLISH CONFIRMÉE ✅✅✅");
            Logger::Debug("   Pivot initial (signal) @ bar[" + IntegerToString(pivotBar) + 
                          "] RSI=" + DoubleToString(pivotRSI, 2) + 
                          " Prix=" + DoubleToString(pivotPrice, _Digits));
            Logger::Debug("   Nouveau pivot @ bar[" + IntegerToString(newPivotBar) + 
                          "] RSI=" + DoubleToString(newPivotRSI, 2) + 
                          " Prix=" + DoubleToString(newPivotPrice, _Digits));
            Logger::Debug("=== DetectBullishDivergenceInFuture END: SUCCESS ===");
            return true;
           }
        }
      
      Logger::Debug("Pivots vérifiés: " + IntegerToString(pivotsChecked));
      Logger::Debug("=== DetectBullishDivergenceInFuture END: NO DIVERGENCE ===");
      return false;
     }

   //+------------------------------------------------------------------+
   //| Chercher divergence bearish dans le FUTUR depuis un point donné |
   //+------------------------------------------------------------------+
   bool DetectBearishDivergenceInFuture(string symbol, ENUM_TIMEFRAMES tf,
                                        int rsiHandle,
                                        int pivotBar,
                                        double pivotRSI,
                                        double pivotPrice,
                                        int futureBarLimit)
     {
      Logger::Debug("=== DetectBearishDivergenceInFuture START ===");
      Logger::Debug("Pivot Initial @ bar[" + IntegerToString(pivotBar) + 
                    "] RSI=" + DoubleToString(pivotRSI, 2) + 
                    " Prix=" + DoubleToString(pivotPrice, _Digits));
      
      if(rsiHandle == INVALID_HANDLE)
        {
         Logger::Error("Handle RSI invalide");
         return false;
        }
      
      double rsiBuffer[];
      ArraySetAsSeries(rsiBuffer, true);
      
      int copySize = pivotBar + futureBarLimit + m_lookbackLeft + 10;
      if(CopyBuffer(rsiHandle, 0, 0, copySize, rsiBuffer) <= 0)
        {
         Logger::Error("Erreur CopyBuffer RSI");
         return false;
        }
      
      Logger::Debug("Buffer RSI copié: " + IntegerToString(ArraySize(rsiBuffer)) + " valeurs");
      
      int searchStart = MathMax(m_lookbackRight, pivotBar - futureBarLimit);
      int searchEnd = MathMax(0, pivotBar - 1);
      
      Logger::Debug("Recherche nouveau pivot de bar[" + 
                    IntegerToString(searchStart) + "] à bar[" + 
                    IntegerToString(searchEnd) + "]");
      
      int pivotsChecked = 0;
      
      for(int newPivotBar = searchStart; newPivotBar <= searchEnd; newPivotBar++)
        {
         // Vérifier si c'est un pivot RSI HAUT
         if(!IsPivotHigh(newPivotBar, m_lookbackLeft, m_lookbackRight, rsiBuffer))
            continue;
         
         pivotsChecked++;
         double newPivotRSI = rsiBuffer[newPivotBar];
         
         Logger::Debug("🔍 Nouveau pivot trouvé @ bar[" + 
                       IntegerToString(newPivotBar) + "] RSI=" + 
                       DoubleToString(newPivotRSI, 2));
         
         if(newPivotRSI < m_upperLevel)
           {
            Logger::Debug("   ❌ RSI trop bas (" + DoubleToString(newPivotRSI, 2) + " < " + DoubleToString(m_upperLevel, 1) + ")");
            continue;
           }
         
         Logger::Debug("   ✓ RSI dans zone surachat (" + DoubleToString(newPivotRSI, 2) + " >= " + DoubleToString(m_upperLevel, 1) + ")");
         
         int barsBetween = pivotBar - newPivotBar;
         if(barsBetween < m_rangeLower || barsBetween > m_rangeUpper)
           {
            Logger::Debug("   ❌ Distance hors range: " + IntegerToString(barsBetween) + " barres");
            continue;
           }
         
         Logger::Debug("   ✓ Distance OK: " + IntegerToString(barsBetween) + " barres");
         
         double newPivotPrice = iHigh(symbol, tf, newPivotBar);
         
         Logger::Debug("   Prix nouveau pivot: " + DoubleToString(newPivotPrice, _Digits));
         Logger::Debug("   Prix pivot initial: " + DoubleToString(pivotPrice, _Digits));
         
         // CONDITIONS DE DIVERGENCE BEARISH:
         // Le NOUVEAU pivot doit avoir:
         //   - Prix PLUS HAUT que le pivot initial
         //   - RSI PLUS BAS que le pivot initial
         bool priceHigherHigh = newPivotPrice > pivotPrice;
         bool rsiLowerHigh = newPivotRSI < pivotRSI;
         
         Logger::Debug("   Prix Higher High: " + (priceHigherHigh ? "OUI ✓" : "NON ❌") + 
                       " (" + DoubleToString(newPivotPrice, _Digits) + " vs " + DoubleToString(pivotPrice, _Digits) + ")");
         Logger::Debug("   RSI Lower High: " + (rsiLowerHigh ? "OUI ✓" : "NON ❌") + 
                       " (" + DoubleToString(newPivotRSI, 2) + " vs " + DoubleToString(pivotRSI, 2) + ")");
         
         if(priceHigherHigh && rsiLowerHigh)
           {
            Logger::Debug("✅✅✅ DIVERGENCE BEARISH CONFIRMÉE ✅✅✅");
            Logger::Debug("   Pivot initial (signal) @ bar[" + IntegerToString(pivotBar) + 
                          "] RSI=" + DoubleToString(pivotRSI, 2) + 
                          " Prix=" + DoubleToString(pivotPrice, _Digits));
            Logger::Debug("   Nouveau pivot @ bar[" + IntegerToString(newPivotBar) + 
                          "] RSI=" + DoubleToString(newPivotRSI, 2) + 
                          " Prix=" + DoubleToString(newPivotPrice, _Digits));
            Logger::Debug("=== DetectBearishDivergenceInFuture END: SUCCESS ===");
            return true;
           }
        }
      
      Logger::Debug("Pivots vérifiés: " + IntegerToString(pivotsChecked));
      Logger::Debug("=== DetectBearishDivergenceInFuture END: NO DIVERGENCE ===");
      return false;
     }

   //--- Modifier les paramètres de lookback
   void SetLookbackLeft(int lookbackLeft)
     {
      m_lookbackLeft = lookbackLeft;
      Logger::Info("Divergence lookback left updated to: " + IntegerToString(lookbackLeft));
     }

   void SetLookbackRight(int lookbackRight)
     {
      m_lookbackRight = lookbackRight;
      Logger::Info("Divergence lookback right updated to: " + IntegerToString(lookbackRight));
     }

   //--- Modifier les paramètres de range
   void SetRangeLower(int rangeLower)
     {
      m_rangeLower = rangeLower;
      Logger::Info("Divergence range lower updated to: " + IntegerToString(rangeLower));
     }

   void SetRangeUpper(int rangeUpper)
     {
      m_rangeUpper = rangeUpper;
      Logger::Info("Divergence range upper updated to: " + IntegerToString(rangeUpper));
     }

   //--- Modifier les niveaux RSI
   void SetUpperLevel(double upperLevel)
     {
      m_upperLevel = upperLevel;
      Logger::Info("RSI upper level updated to: " + DoubleToString(upperLevel, 1));
     }

   void SetLowerLevel(double lowerLevel)
     {
      m_lowerLevel = lowerLevel;
      Logger::Info("RSI lower level updated to: " + DoubleToString(lowerLevel, 1));
     }

   //--- Modifier la force minimum
   void SetMinStrength(double minStrength)
     {
      m_minDivStrength = minStrength;
      Logger::Info("Divergence min strength updated to: " + DoubleToString(minStrength, 1) + "%");
     }

   //--- Obtenir les paramètres actuels
   int GetLookbackLeft() const { return m_lookbackLeft; }
   int GetLookbackRight() const { return m_lookbackRight; }
   int GetRangeLower() const { return m_rangeLower; }
   int GetRangeUpper() const { return m_rangeUpper; }
   double GetUpperLevel() const { return m_upperLevel; }
   double GetLowerLevel() const { return m_lowerLevel; }
   double GetMinStrength() const { return m_minDivStrength; }
  };
//+------------------------------------------------------------------+

