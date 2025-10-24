//+------------------------------------------------------------------+
//|                                        Divergence_Detector.mqh   |
//|                         RSI Divergence Trading System              |
//|                      Classe pour détection des divergences         |
//+------------------------------------------------------------------+
//| Version: 1.0                                                     |
//| Changelog:                                                       |
//| ✅ [FEATURE] Détection divergences Regular et Hidden              |
//| ✅ [FEATURE] Support Bullish et Bearish divergences               |
//| ✅ [PERFORMANCE] Optimisation des algorithmes de recherche        |
//| ✅ [VALIDATION] Validation robuste des paramètres et conditions   |
//| ✅ [INTEGRATION] Intégration avec RSI_Calculator et Pivot_Detector |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"

#include "RSI_Calculator.mqh"
#include "Pivot_Detector.mqh"

//+------------------------------------------------------------------+
//| Structure pour stocker les résultats de divergence               |
//+------------------------------------------------------------------+
struct SDivergenceResult
{
   bool                    found;              // Divergence trouvée
   int                     currentBar;         // Position de la barre actuelle
   int                     previousBar;        // Position de la barre précédente
   double                  currentRSI;         // Valeur RSI actuelle
   double                  previousRSI;        // Valeur RSI précédente
   double                  currentPrice;       // Prix actuel
   double                  previousPrice;      // Prix précédent
   ENUM_DIVERGENCE_TYPE    type;               // Type de divergence
   datetime                currentTime;        // Temps actuel
   datetime                previousTime;       // Temps précédent
   bool                    isValid;            // Validité du résultat
   
   // Constructeur par défaut
   SDivergenceResult()
   {
      found = false;
      currentBar = -1;
      previousBar = -1;
      currentRSI = 0.0;
      previousRSI = 0.0;
      currentPrice = 0.0;
      previousPrice = 0.0;
      type = DIVERGENCE_NONE;
      currentTime = 0;
      previousTime = 0;
      isValid = false;
   }
};

//+------------------------------------------------------------------+
//| Classe pour détection des divergences                            |
//+------------------------------------------------------------------+
class CDivergenceDetector
{
private:
   // Paramètres de configuration
   int                m_rangeLower;           // Range minimum pour recherche
   int                m_rangeUpper;           // Range maximum pour recherche
   
   // Références aux classes
   CPivotDetector*    m_pivotDetector;        // Détecteur de pivots
   
   // Variables de contrôle
   bool               m_initialized;          // État d'initialisation
   int                m_lastProcessed;        // Dernière position traitée
   
   // Buffers de stockage
   SDivergenceResult  m_divergenceResults[];  // Résultats de divergences
   
   // Constantes
   int MAX_DIVERGENCES; // Nombre maximum de divergences à stocker

public:
   // Constructeur
   CDivergenceDetector(int rangeLower = 3, int rangeUpper = 100, CPivotDetector* pivotDetector = NULL);
   
   // Destructeur
   ~CDivergenceDetector();
   
   // Méthodes principales de détection
   bool CheckRegularBullish(int currentBar, const double &rsi[], const double &low[], 
                           const datetime &time[], SDivergenceResult &result);
   bool CheckRegularBearish(int currentBar, const double &rsi[], const double &high[], 
                            const datetime &time[], SDivergenceResult &result);
   bool CheckHiddenBullish(int currentBar, const double &rsi[], const double &low[], 
                          const datetime &time[], SDivergenceResult &result);
   bool CheckHiddenBearish(int currentBar, const double &rsi[], const double &high[], 
                           const datetime &time[], SDivergenceResult &result);
   
   // Méthodes de scan global
   int ScanDivergences(int startPos, int endPos, const double &rsi[], const double &high[], 
                      const double &low[], const datetime &time[], SDivergenceResult &results[]);
   
   int ScanRegularDivergences(int startPos, int endPos, const double &rsi[], const double &high[], 
                             const double &low[], const datetime &time[], SDivergenceResult &results[]);
   int ScanHiddenDivergences(int startPos, int endPos, const double &rsi[], const double &high[], 
                             const double &low[], const datetime &time[], SDivergenceResult &results[]);
   
   // Méthodes de configuration
   void SetRangeLower(int rangeLower);
   void SetRangeUpper(int rangeUpper);
   void SetRange(int rangeLower, int rangeUpper);
   void SetPivotDetector(CPivotDetector* pivotDetector);
   int GetRangeLower() const { return m_rangeLower; }
   int GetRangeUpper() const { return m_rangeUpper; }
   
   // Méthodes utilitaires
   void Reset();
   bool IsInitialized() const { return m_initialized; }
   int GetLastProcessed() const { return m_lastProcessed; }
   
   // Méthodes de validation
   bool ValidateParameters() const;
   bool ValidatePosition(int pos, int bufferSize) const;
   
   // Méthodes d'accès aux résultats
   int GetDivergenceCount() const;
   bool GetDivergence(int index, SDivergenceResult &result) const;

private:
   // Méthodes internes
   bool InitializeBuffers();
   bool ValidateDivergenceConditions(double currentRSI, double previousRSI, 
                                    double currentPrice, double previousPrice, 
                                    ENUM_DIVERGENCE_TYPE type) const;
   void AddDivergenceResult(const SDivergenceResult &result);
   void CleanOldResults();
};

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
CDivergenceDetector::CDivergenceDetector(int rangeLower = 3, int rangeUpper = 100, CPivotDetector* pivotDetector = NULL)
{
   m_rangeLower = rangeLower;
   m_rangeUpper = rangeUpper;
   m_pivotDetector = pivotDetector;
   m_lastProcessed = -1;
   m_initialized = false;
   MAX_DIVERGENCES = 1000;  // Initialiser la constante
   
   // Initialiser les buffers
   ArrayResize(m_divergenceResults, MAX_DIVERGENCES);
   for(int i = 0; i < MAX_DIVERGENCES; i++)
   {
      m_divergenceResults[i].found = false;
      m_divergenceResults[i].currentBar = -1;
      m_divergenceResults[i].previousBar = -1;
      m_divergenceResults[i].currentRSI = 0.0;
      m_divergenceResults[i].previousRSI = 0.0;
      m_divergenceResults[i].currentPrice = 0.0;
      m_divergenceResults[i].previousPrice = 0.0;
      m_divergenceResults[i].type = DIVERGENCE_NONE;
      m_divergenceResults[i].currentTime = 0;
      m_divergenceResults[i].previousTime = 0;
   }
   
   m_initialized = InitializeBuffers();
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
CDivergenceDetector::~CDivergenceDetector()
{
   ArrayFree(m_divergenceResults);
}

//+------------------------------------------------------------------+
//| Vérifier une divergence bullish régulière                        |
//+------------------------------------------------------------------+
bool CDivergenceDetector::CheckRegularBullish(int currentBar, const double &rsi[], const double &low[], 
                                              const datetime &time[], SDivergenceResult &result)
{
   // Initialiser le résultat
   result = SDivergenceResult();
   
   // Validation des paramètres
   if(!ValidateParameters() || m_pivotDetector == NULL)
      return false;
   
   if(!ValidatePosition(currentBar, ArraySize(rsi)))
      return false;
   
   // Vérifier que c'est un pivot bas sur le RSI
   if(!m_pivotDetector.IsPivotLow(currentBar, rsi, time))
      return false;
   
   double pivotRSI = rsi[currentBar];
   
   // Rechercher le pivot précédent
   SPivotInfo prevPivot;
   if(!m_pivotDetector.FindPreviousPivotLow(currentBar, rsi, time, m_rangeLower, m_rangeUpper, prevPivot))
      return false;
   
   // Conditions de divergence bullish régulière
   double currentPrice = low[currentBar];
   bool rsiHigherLow = pivotRSI > prevPivot.value;
   bool priceLowerLow = (prevPivot.position >= 0 && prevPivot.position < ArraySize(low)) ? 
                        (currentPrice < low[prevPivot.position]) : false;
   
   if(rsiHigherLow && priceLowerLow)
   {
      result.found = true;
      result.currentBar = currentBar;
      result.previousBar = prevPivot.position;
      result.currentRSI = pivotRSI;
      result.previousRSI = prevPivot.value;
      result.currentPrice = currentPrice;
      result.previousPrice = low[prevPivot.position];
      result.type = DIVERGENCE_REGULAR_BULL;
      result.currentTime = (ArraySize(time) > 0 && currentBar < ArraySize(time)) ? time[currentBar] : 0;
      result.previousTime = prevPivot.time;
      result.isValid = true;
      
      AddDivergenceResult(result);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier une divergence bearish régulière                        |
//+------------------------------------------------------------------+
bool CDivergenceDetector::CheckRegularBearish(int currentBar, const double &rsi[], const double &high[], 
                                              const datetime &time[], SDivergenceResult &result)
{
   // Initialiser le résultat
   result = SDivergenceResult();
   
   // Validation des paramètres
   if(!ValidateParameters() || m_pivotDetector == NULL)
      return false;
   
   if(!ValidatePosition(currentBar, ArraySize(rsi)))
      return false;
   
   // Vérifier que c'est un pivot haut sur le RSI
   if(!m_pivotDetector.IsPivotHigh(currentBar, rsi, time))
      return false;
   
   double pivotRSI = rsi[currentBar];
   
   // Rechercher le pivot précédent
   SPivotInfo prevPivot;
   if(!m_pivotDetector.FindPreviousPivotHigh(currentBar, rsi, time, m_rangeLower, m_rangeUpper, prevPivot))
      return false;
   
   // Conditions de divergence bearish régulière
   double currentPrice = high[currentBar];
   bool rsiLowerHigh = pivotRSI < prevPivot.value;
   bool priceHigherHigh = (prevPivot.position >= 0 && prevPivot.position < ArraySize(high)) ? 
                          (currentPrice > high[prevPivot.position]) : false;
   
   if(rsiLowerHigh && priceHigherHigh)
   {
      result.found = true;
      result.currentBar = currentBar;
      result.previousBar = prevPivot.position;
      result.currentRSI = pivotRSI;
      result.previousRSI = prevPivot.value;
      result.currentPrice = currentPrice;
      result.previousPrice = high[prevPivot.position];
      result.type = DIVERGENCE_REGULAR_BEAR;
      result.currentTime = (ArraySize(time) > 0 && currentBar < ArraySize(time)) ? time[currentBar] : 0;
      result.previousTime = prevPivot.time;
      result.isValid = true;
      
      AddDivergenceResult(result);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier une divergence bullish cachée                           |
//+------------------------------------------------------------------+
bool CDivergenceDetector::CheckHiddenBullish(int currentBar, const double &rsi[], const double &low[], 
                                             const datetime &time[], SDivergenceResult &result)
{
   // Initialiser le résultat
   result = SDivergenceResult();
   
   // Validation des paramètres
   if(!ValidateParameters() || m_pivotDetector == NULL)
      return false;
   
   if(!ValidatePosition(currentBar, ArraySize(rsi)))
      return false;
   
   // Vérifier que c'est un pivot bas sur le RSI
   if(!m_pivotDetector.IsPivotLow(currentBar, rsi, time))
      return false;
   
   double pivotRSI = rsi[currentBar];
   
   // Rechercher le pivot précédent
   SPivotInfo prevPivot;
   if(!m_pivotDetector.FindPreviousPivotLow(currentBar, rsi, time, m_rangeLower, m_rangeUpper, prevPivot))
      return false;
   
   // Conditions de divergence bullish cachée (inversées par rapport à régulière)
   double currentPrice = low[currentBar];
   bool rsiLowerLow = pivotRSI < prevPivot.value;
   bool priceHigherLow = (prevPivot.position >= 0 && prevPivot.position < ArraySize(low)) ? 
                         (currentPrice > low[prevPivot.position]) : false;
   
   if(rsiLowerLow && priceHigherLow)
   {
      result.found = true;
      result.currentBar = currentBar;
      result.previousBar = prevPivot.position;
      result.currentRSI = pivotRSI;
      result.previousRSI = prevPivot.value;
      result.currentPrice = currentPrice;
      result.previousPrice = low[prevPivot.position];
      result.type = DIVERGENCE_HIDDEN_BULL;
      result.currentTime = (ArraySize(time) > 0 && currentBar < ArraySize(time)) ? time[currentBar] : 0;
      result.previousTime = prevPivot.time;
      result.isValid = true;
      
      AddDivergenceResult(result);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier une divergence bearish cachée                           |
//+------------------------------------------------------------------+
bool CDivergenceDetector::CheckHiddenBearish(int currentBar, const double &rsi[], const double &high[], 
                                             const datetime &time[], SDivergenceResult &result)
{
   // Initialiser le résultat
   result = SDivergenceResult();
   
   // Validation des paramètres
   if(!ValidateParameters() || m_pivotDetector == NULL)
      return false;
   
   if(!ValidatePosition(currentBar, ArraySize(rsi)))
      return false;
   
   // Vérifier que c'est un pivot haut sur le RSI
   if(!m_pivotDetector.IsPivotHigh(currentBar, rsi, time))
      return false;
   
   double pivotRSI = rsi[currentBar];
   
   // Rechercher le pivot précédent
   SPivotInfo prevPivot;
   if(!m_pivotDetector.FindPreviousPivotHigh(currentBar, rsi, time, m_rangeLower, m_rangeUpper, prevPivot))
      return false;
   
   // Conditions de divergence bearish cachée (inversées par rapport à régulière)
   double currentPrice = high[currentBar];
   bool rsiHigherHigh = pivotRSI > prevPivot.value;
   bool priceLowerHigh = (prevPivot.position >= 0 && prevPivot.position < ArraySize(high)) ? 
                         (currentPrice < high[prevPivot.position]) : false;
   
   if(rsiHigherHigh && priceLowerHigh)
   {
      result.found = true;
      result.currentBar = currentBar;
      result.previousBar = prevPivot.position;
      result.currentRSI = pivotRSI;
      result.previousRSI = prevPivot.value;
      result.currentPrice = currentPrice;
      result.previousPrice = high[prevPivot.position];
      result.type = DIVERGENCE_HIDDEN_BEAR;
      result.currentTime = (ArraySize(time) > 0 && currentBar < ArraySize(time)) ? time[currentBar] : 0;
      result.previousTime = prevPivot.time;
      result.isValid = true;
      
      AddDivergenceResult(result);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Scanner toutes les divergences dans un range                     |
//+------------------------------------------------------------------+
int CDivergenceDetector::ScanDivergences(int startPos, int endPos, const double &rsi[], const double &high[], 
                                         const double &low[], const datetime &time[], SDivergenceResult &results[])
{
   int totalFound = 0;
   
   // Validation des paramètres
   if(!ValidateParameters() || m_pivotDetector == NULL)
      return 0;
   
   if(startPos < 0 || endPos >= ArraySize(rsi) || startPos > endPos)
      return 0;
   
   // Initialiser l'array de résultats
   ArrayResize(results, 0);
   
   // Scanner les barres dans le range
   for(int i = startPos; i <= endPos; i++)
   {
      SDivergenceResult result;
      
      // Vérifier toutes les types de divergences
      if(CheckRegularBullish(i, rsi, low, time, result) && result.found)
      {
         int size = ArraySize(results);
         ArrayResize(results, size + 1);
         results[size] = result;
         totalFound++;
      }
      
      if(CheckRegularBearish(i, rsi, high, time, result) && result.found)
      {
         int size = ArraySize(results);
         ArrayResize(results, size + 1);
         results[size] = result;
         totalFound++;
      }
      
      if(CheckHiddenBullish(i, rsi, low, time, result) && result.found)
      {
         int size = ArraySize(results);
         ArrayResize(results, size + 1);
         results[size] = result;
         totalFound++;
      }
      
      if(CheckHiddenBearish(i, rsi, high, time, result) && result.found)
      {
         int size = ArraySize(results);
         ArrayResize(results, size + 1);
         results[size] = result;
         totalFound++;
      }
   }
   
   return totalFound;
}

//+------------------------------------------------------------------+
//| Scanner les divergences régulières                               |
//+------------------------------------------------------------------+
int CDivergenceDetector::ScanRegularDivergences(int startPos, int endPos, const double &rsi[], const double &high[], 
                                                const double &low[], const datetime &time[], SDivergenceResult &results[])
{
   int totalFound = 0;
   
   // Validation des paramètres
   if(!ValidateParameters() || m_pivotDetector == NULL)
      return 0;
   
   if(startPos < 0 || endPos >= ArraySize(rsi) || startPos > endPos)
      return 0;
   
   // Initialiser l'array de résultats
   ArrayResize(results, 0);
   
   // Scanner les barres dans le range
   for(int i = startPos; i <= endPos; i++)
   {
      SDivergenceResult result;
      
      // Vérifier les divergences régulières uniquement
      if(CheckRegularBullish(i, rsi, low, time, result) && result.found)
      {
         int size = ArraySize(results);
         ArrayResize(results, size + 1);
         results[size] = result;
         totalFound++;
      }
      
      if(CheckRegularBearish(i, rsi, high, time, result) && result.found)
      {
         int size = ArraySize(results);
         ArrayResize(results, size + 1);
         results[size] = result;
         totalFound++;
      }
   }
   
   return totalFound;
}

//+------------------------------------------------------------------+
//| Scanner les divergences cachées                                  |
//+------------------------------------------------------------------+
int CDivergenceDetector::ScanHiddenDivergences(int startPos, int endPos, const double &rsi[], const double &high[], 
                                               const double &low[], const datetime &time[], SDivergenceResult &results[])
{
   int totalFound = 0;
   
   // Validation des paramètres
   if(!ValidateParameters() || m_pivotDetector == NULL)
      return 0;
   
   if(startPos < 0 || endPos >= ArraySize(rsi) || startPos > endPos)
      return 0;
   
   // Initialiser l'array de résultats
   ArrayResize(results, 0);
   
   // Scanner les barres dans le range
   for(int i = startPos; i <= endPos; i++)
   {
      SDivergenceResult result;
      
      // Vérifier les divergences cachées uniquement
      if(CheckHiddenBullish(i, rsi, low, time, result) && result.found)
      {
         int size = ArraySize(results);
         ArrayResize(results, size + 1);
         results[size] = result;
         totalFound++;
      }
      
      if(CheckHiddenBearish(i, rsi, high, time, result) && result.found)
      {
         int size = ArraySize(results);
         ArrayResize(results, size + 1);
         results[size] = result;
         totalFound++;
      }
   }
   
   return totalFound;
}

//+------------------------------------------------------------------+
//| Définir le range inférieur                                       |
//+------------------------------------------------------------------+
void CDivergenceDetector::SetRangeLower(int rangeLower)
{
   if(rangeLower < 1)
      return;
   
   m_rangeLower = rangeLower;
   Reset();
}

//+------------------------------------------------------------------+
//| Définir le range supérieur                                       |
//+------------------------------------------------------------------+
void CDivergenceDetector::SetRangeUpper(int rangeUpper)
{
   if(rangeUpper < m_rangeLower)
      return;
   
   m_rangeUpper = rangeUpper;
   Reset();
}

//+------------------------------------------------------------------+
//| Définir les ranges                                               |
//+------------------------------------------------------------------+
void CDivergenceDetector::SetRange(int rangeLower, int rangeUpper)
{
   if(rangeLower < 1 || rangeUpper < rangeLower)
      return;
   
   m_rangeLower = rangeLower;
   m_rangeUpper = rangeUpper;
   Reset();
}

//+------------------------------------------------------------------+
//| Définir le détecteur de pivots                                   |
//+------------------------------------------------------------------+
void CDivergenceDetector::SetPivotDetector(CPivotDetector* pivotDetector)
{
   m_pivotDetector = pivotDetector;
   Reset();
}

//+------------------------------------------------------------------+
//| Réinitialiser le détecteur                                      |
//+------------------------------------------------------------------+
void CDivergenceDetector::Reset()
{
   m_lastProcessed = -1;
   for(int i = 0; i < ArraySize(m_divergenceResults); i++)
   {
      m_divergenceResults[i].found = false;
      m_divergenceResults[i].currentBar = -1;
      m_divergenceResults[i].previousBar = -1;
      m_divergenceResults[i].currentRSI = 0.0;
      m_divergenceResults[i].previousRSI = 0.0;
      m_divergenceResults[i].currentPrice = 0.0;
      m_divergenceResults[i].previousPrice = 0.0;
      m_divergenceResults[i].type = DIVERGENCE_NONE;
      m_divergenceResults[i].currentTime = 0;
      m_divergenceResults[i].previousTime = 0;
   }
}

//+------------------------------------------------------------------+
//| Valider les paramètres de configuration                          |
//+------------------------------------------------------------------+
bool CDivergenceDetector::ValidateParameters() const
{
   if(m_rangeLower < 1 || m_rangeUpper < m_rangeLower)
   {
      Print("❌ CDivergenceDetector::ValidateParameters - Ranges invalides: Lower=", m_rangeLower, ", Upper=", m_rangeUpper);
      return false;
   }
   
   if(m_pivotDetector == NULL)
   {
      Print("❌ CDivergenceDetector::ValidateParameters - PivotDetector non initialisé");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Valider une position dans un buffer                              |
//+------------------------------------------------------------------+
bool CDivergenceDetector::ValidatePosition(int pos, int bufferSize) const
{
   if(pos < 0 || pos >= bufferSize)
   {
      Print("❌ CDivergenceDetector::ValidatePosition - Position invalide: ", pos, " (Buffer size: ", bufferSize, ")");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de divergences trouvées                        |
//+------------------------------------------------------------------+
int CDivergenceDetector::GetDivergenceCount() const
{
   int count = 0;
   for(int i = 0; i < ArraySize(m_divergenceResults); i++)
   {
      if(m_divergenceResults[i].isValid)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Obtenir une divergence par index                                 |
//+------------------------------------------------------------------+
bool CDivergenceDetector::GetDivergence(int index, SDivergenceResult &result) const
{
   if(index < 0 || index >= ArraySize(m_divergenceResults))
      return false;
   
   if(!m_divergenceResults[index].isValid)
      return false;
   
   result = m_divergenceResults[index];
   return true;
}

//+------------------------------------------------------------------+
//| Initialiser les buffers internes                                 |
//+------------------------------------------------------------------+
bool CDivergenceDetector::InitializeBuffers()
{
   if(m_rangeLower < 1 || m_rangeUpper < m_rangeLower)
      return false;
   
   ArrayResize(m_divergenceResults, MAX_DIVERGENCES);
   for(int i = 0; i < MAX_DIVERGENCES; i++)
   {
      m_divergenceResults[i].found = false;
      m_divergenceResults[i].currentBar = -1;
      m_divergenceResults[i].previousBar = -1;
      m_divergenceResults[i].currentRSI = 0.0;
      m_divergenceResults[i].previousRSI = 0.0;
      m_divergenceResults[i].currentPrice = 0.0;
      m_divergenceResults[i].previousPrice = 0.0;
      m_divergenceResults[i].type = DIVERGENCE_NONE;
      m_divergenceResults[i].currentTime = 0;
      m_divergenceResults[i].previousTime = 0;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Valider les conditions de divergence                             |
//+------------------------------------------------------------------+
bool CDivergenceDetector::ValidateDivergenceConditions(double currentRSI, double previousRSI, 
                                                       double currentPrice, double previousPrice, 
                                                       ENUM_DIVERGENCE_TYPE type) const
{
   // Validation basique des valeurs
   if(currentRSI == EMPTY_VALUE || previousRSI == EMPTY_VALUE)
      return false;
   
   if(currentPrice <= 0 || previousPrice <= 0)
      return false;
   
   // Validation selon le type de divergence
   switch(type)
   {
      case DIVERGENCE_REGULAR_BULL:
         return (currentRSI > previousRSI && currentPrice < previousPrice);
      
      case DIVERGENCE_REGULAR_BEAR:
         return (currentRSI < previousRSI && currentPrice > previousPrice);
      
      case DIVERGENCE_HIDDEN_BULL:
         return (currentRSI < previousRSI && currentPrice > previousPrice);
      
      case DIVERGENCE_HIDDEN_BEAR:
         return (currentRSI > previousRSI && currentPrice < previousPrice);
      
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Ajouter un résultat de divergence                                |
//+------------------------------------------------------------------+
void CDivergenceDetector::AddDivergenceResult(const SDivergenceResult &result)
{
   // Trouver la première position libre
   for(int i = 0; i < ArraySize(m_divergenceResults); i++)
   {
      if(!m_divergenceResults[i].isValid)
      {
         m_divergenceResults[i] = result;
         return;
      }
   }
   
   // Si aucune position libre, nettoyer les anciens résultats
   CleanOldResults();
   
   // Réessayer d'ajouter
   for(int i = 0; i < ArraySize(m_divergenceResults); i++)
   {
      if(!m_divergenceResults[i].isValid)
      {
         m_divergenceResults[i] = result;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Nettoyer les anciens résultats                                   |
//+------------------------------------------------------------------+
void CDivergenceDetector::CleanOldResults()
{
   // Pour l'instant, on garde tous les résultats
   // Cette méthode peut être implémentée pour nettoyer les anciens résultats
   // si nécessaire pour l'optimisation mémoire
}

//+------------------------------------------------------------------+
