//+------------------------------------------------------------------+
//|                                             Pivot_Detector.mqh   |
//|                         RSI Divergence Trading System              |
//|                        Classe pour détection des pivots            |
//+------------------------------------------------------------------+
//| Version: 1.0                                                     |
//| Changelog:                                                       |
//| ✅ [FEATURE] Détection pivots bas et hauts (équivalent Pine Script) |
//| ✅ [FEATURE] Support lookback left et right configurables         |
//| ✅ [PERFORMANCE] Optimisation des boucles de recherche            |
//| ✅ [VALIDATION] Validation robuste des paramètres et indices      |
//| ✅ [COMPATIBILITY] Compatible EA et Indicateurs                   |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Structure pour stocker les informations de pivot                |
//+------------------------------------------------------------------+
struct SPivotInfo
{
   int      position;    // Position du pivot
   double   value;       // Valeur du pivot
   datetime time;        // Temps du pivot
   bool     isValid;     // Validité du pivot
};

//+------------------------------------------------------------------+
//| Classe pour détection des pivots                                 |
//+------------------------------------------------------------------+
class CPivotDetector
{
private:
   // Paramètres de configuration
   int                m_lookbackLeft;        // Nombre de barres à gauche
   int                m_lookbackRight;       // Nombre de barres à droite
   
   // Buffers de stockage
   SPivotInfo         m_pivotHighs[];        // Pivots hauts trouvés
   SPivotInfo         m_pivotLows[];         // Pivots bas trouvés
   
   // Variables de contrôle
   int                m_lastProcessed;       // Dernière position traitée
   bool               m_initialized;         // État d'initialisation
   
   // Constantes
   int MAX_PIVOTS;     // Nombre maximum de pivots à stocker

public:
   // Constructeur
   CPivotDetector(int lookbackLeft = 3, int lookbackRight = 1);
   
   // Destructeur
   ~CPivotDetector();
   
   // Méthodes principales de détection
   bool IsPivotLow(int pos, const double &buffer[], const datetime &time[]);
   bool IsPivotHigh(int pos, const double &buffer[], const datetime &time[]);
   
   // Méthodes de recherche avancées
   int FindPivots(const double &buffer[], const datetime &time[], int startPos, int endPos, 
                  SPivotInfo &pivotHighs[], SPivotInfo &pivotLows[], bool findHighs, bool findLows);
   
   // Méthodes de recherche de pivots spécifiques
   int FindPivotHighs(const double &buffer[], const datetime &time[], int startPos, int endPos, SPivotInfo &pivotHighs[]);
   int FindPivotLows(const double &buffer[], const datetime &time[], int startPos, int endPos, SPivotInfo &pivotLows[]);
   
   // Méthodes de recherche de pivots précédents
   bool FindPreviousPivotHigh(int currentPos, const double &buffer[], const datetime &time[], 
                              int rangeLower, int rangeUpper, SPivotInfo &previousPivot);
   bool FindPreviousPivotLow(int currentPos, const double &buffer[], const datetime &time[], 
                             int rangeLower, int rangeUpper, SPivotInfo &previousPivot);
   
   // Méthodes de configuration
   void SetLookbackLeft(int lookbackLeft);
   void SetLookbackRight(int lookbackRight);
   void SetLookback(int lookbackLeft, int lookbackRight);
   int GetLookbackLeft() const { return m_lookbackLeft; }
   int GetLookbackRight() const { return m_lookbackRight; }
   
   // Méthodes utilitaires
   void Reset();
   bool IsInitialized() const { return m_initialized; }
   int GetLastProcessed() const { return m_lastProcessed; }
   
   // Méthodes de validation
   bool ValidateParameters() const;
   bool ValidatePosition(int pos, int bufferSize) const;

private:
   // Méthodes internes
   bool InitializeBuffers();
   bool IsValidPivotPosition(int pos, int bufferSize) const;
   void CleanOldPivots();
};

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
CPivotDetector::CPivotDetector(int lookbackLeft = 3, int lookbackRight = 1)
{
   m_lookbackLeft = lookbackLeft;
   m_lookbackRight = lookbackRight;
   m_lastProcessed = -1;
   m_initialized = false;
   MAX_PIVOTS = 1000;  // Initialiser la constante
   
   // Initialiser les buffers
   ArrayResize(m_pivotHighs, MAX_PIVOTS);
   ArrayResize(m_pivotLows, MAX_PIVOTS);
   
   // Initialiser les structures
   for(int i = 0; i < MAX_PIVOTS; i++)
   {
      m_pivotHighs[i].position = -1;
      m_pivotHighs[i].value = 0.0;
      m_pivotHighs[i].time = 0;
      m_pivotLows[i].position = -1;
      m_pivotLows[i].value = 0.0;
      m_pivotLows[i].time = 0;
   }
   
   m_initialized = InitializeBuffers();
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
CPivotDetector::~CPivotDetector()
{
   ArrayFree(m_pivotHighs);
   ArrayFree(m_pivotLows);
}

//+------------------------------------------------------------------+
//| Détecter un pivot bas (équivalent ta.pivotlow de Pine Script)   |
//+------------------------------------------------------------------+
bool CPivotDetector::IsPivotLow(int pos, const double &buffer[], const datetime &time[])
{
   // Validation des paramètres
   if(!ValidateParameters() || !ValidatePosition(pos, ArraySize(buffer)))
      return false;
   
   // Vérifier qu'on a assez de barres de chaque côté
   if(pos < m_lookbackRight || pos + m_lookbackLeft >= ArraySize(buffer))
      return false;
   
   double pivotValue = buffer[pos];
   
   // Vérifier que pos est le MINIMUM dans la fenêtre
   // De pos-rightBars à pos+leftBars (inclusif)
   for(int i = pos - m_lookbackRight; i <= pos + m_lookbackLeft; i++)
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

//+------------------------------------------------------------------+
//| Détecter un pivot haut (équivalent ta.pivothigh de Pine Script) |
//+------------------------------------------------------------------+
bool CPivotDetector::IsPivotHigh(int pos, const double &buffer[], const datetime &time[])
{
   // Validation des paramètres
   if(!ValidateParameters() || !ValidatePosition(pos, ArraySize(buffer)))
      return false;
   
   // Vérifier qu'on a assez de barres de chaque côté
   if(pos < m_lookbackRight || pos + m_lookbackLeft >= ArraySize(buffer))
      return false;
   
   double pivotValue = buffer[pos];
   
   // Vérifier que pos est le MAXIMUM dans la fenêtre
   for(int i = pos - m_lookbackRight; i <= pos + m_lookbackLeft; i++)
   {
      // Ne pas comparer avec soi-même
      if(i == pos) 
         continue;
      
      // Validation de l'indice
      if(i < 0 || i >= ArraySize(buffer))
         continue;
      
      // Si une valeur est plus grande, ce n'est PAS un pivot haut
      if(buffer[i] > pivotValue)
         return false;
   }
   
   return true; // C'est un pivot haut valide
}


//+------------------------------------------------------------------+
//| Trouver tous les pivots dans un range donné                      |
//+------------------------------------------------------------------+
int CPivotDetector::FindPivots(const double &buffer[], const datetime &time[], int startPos, int endPos, 
                               SPivotInfo &pivotHighs[], SPivotInfo &pivotLows[], bool findHighs, bool findLows)
{
   int totalFound = 0;
   
   // Validation des paramètres
   if(!ValidateParameters() || ArraySize(buffer) == 0)
      return 0;
   
   if(startPos < 0 || endPos >= ArraySize(buffer) || startPos > endPos)
      return 0;
   
   // Ajuster les limites pour tenir compte des lookbacks
   int adjustedStart = MathMax(startPos, m_lookbackRight);
   int adjustedEnd = MathMin(endPos, ArraySize(buffer) - m_lookbackLeft - 1);
   
   if(adjustedStart > adjustedEnd)
      return 0;
   
   // Initialiser les arrays de résultats
   ArrayResize(pivotHighs, 0);
   ArrayResize(pivotLows, 0);
   
   // Rechercher les pivots
   for(int i = adjustedStart; i <= adjustedEnd; i++)
   {
      SPivotInfo pivot;
      pivot.position = i;
      pivot.value = buffer[i];
      pivot.time = (ArraySize(time) > 0 && i < ArraySize(time)) ? time[i] : 0;
      pivot.isValid = true;
      
      // Vérifier pivot haut
      if(findHighs && IsPivotHigh(i, buffer, time))
      {
         int size = ArraySize(pivotHighs);
         ArrayResize(pivotHighs, size + 1);
         pivotHighs[size] = pivot;
         totalFound++;
      }
      
      // Vérifier pivot bas
      if(findLows && IsPivotLow(i, buffer, time))
      {
         int size = ArraySize(pivotLows);
         ArrayResize(pivotLows, size + 1);
         pivotLows[size] = pivot;
         totalFound++;
      }
   }
   
   return totalFound;
}

//+------------------------------------------------------------------+
//| Trouver tous les pivots hauts dans un range                      |
//+------------------------------------------------------------------+
int CPivotDetector::FindPivotHighs(const double &buffer[], const datetime &time[], int startPos, int endPos, SPivotInfo &pivotHighs[])
{
   SPivotInfo dummyLows[];
   return FindPivots(buffer, time, startPos, endPos, pivotHighs, dummyLows, true, false);
}

//+------------------------------------------------------------------+
//| Trouver tous les pivots bas dans un range                        |
//+------------------------------------------------------------------+
int CPivotDetector::FindPivotLows(const double &buffer[], const datetime &time[], int startPos, int endPos, SPivotInfo &pivotLows[])
{
   SPivotInfo dummyHighs[];
   return FindPivots(buffer, time, startPos, endPos, dummyHighs, pivotLows, false, true);
}

//+------------------------------------------------------------------+
//| Trouver le pivot haut précédent                                  |
//+------------------------------------------------------------------+
bool CPivotDetector::FindPreviousPivotHigh(int currentPos, const double &buffer[], const datetime &time[], 
                                           int rangeLower, int rangeUpper, SPivotInfo &previousPivot)
{
   // Validation des paramètres
   if(!ValidateParameters() || !ValidatePosition(currentPos, ArraySize(buffer)))
      return false;
   
   if(rangeLower < 1 || rangeUpper < rangeLower)
      return false;
   
   // Définir la zone de recherche
   int maxSearch = MathMin(currentPos + rangeUpper, ArraySize(buffer) - 1);
   int minSearch = MathMax(currentPos + rangeLower, m_lookbackRight);
   
   if(minSearch > maxSearch)
      return false;
   
   // Rechercher le premier pivot haut valide
   for(int i = minSearch; i <= maxSearch; i++)
   {
      if(IsPivotHigh(i, buffer, time))
      {
         previousPivot.position = i;
         previousPivot.value = buffer[i];
         previousPivot.time = (ArraySize(time) > 0 && i < ArraySize(time)) ? time[i] : 0;
         previousPivot.isValid = true;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Trouver le pivot bas précédent                                   |
//+------------------------------------------------------------------+
bool CPivotDetector::FindPreviousPivotLow(int currentPos, const double &buffer[], const datetime &time[], 
                                          int rangeLower, int rangeUpper, SPivotInfo &previousPivot)
{
   // Validation des paramètres
   if(!ValidateParameters() || !ValidatePosition(currentPos, ArraySize(buffer)))
      return false;
   
   if(rangeLower < 1 || rangeUpper < rangeLower)
      return false;
   
   // Définir la zone de recherche
   int maxSearch = MathMin(currentPos + rangeUpper, ArraySize(buffer) - 1);
   int minSearch = MathMax(currentPos + rangeLower, m_lookbackRight);
   
   if(minSearch > maxSearch)
      return false;
   
   // Rechercher le premier pivot bas valide
   for(int i = minSearch; i <= maxSearch; i++)
   {
      if(IsPivotLow(i, buffer, time))
      {
         previousPivot.position = i;
         previousPivot.value = buffer[i];
         previousPivot.time = (ArraySize(time) > 0 && i < ArraySize(time)) ? time[i] : 0;
         previousPivot.isValid = true;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Définir le lookback gauche                                       |
//+------------------------------------------------------------------+
void CPivotDetector::SetLookbackLeft(int lookbackLeft)
{
   if(lookbackLeft < 1)
      return;
   
   m_lookbackLeft = lookbackLeft;
   Reset();
}

//+------------------------------------------------------------------+
//| Définir le lookback droit                                        |
//+------------------------------------------------------------------+
void CPivotDetector::SetLookbackRight(int lookbackRight)
{
   if(lookbackRight < 1)
      return;
   
   m_lookbackRight = lookbackRight;
   Reset();
}

//+------------------------------------------------------------------+
//| Définir les lookbacks                                            |
//+------------------------------------------------------------------+
void CPivotDetector::SetLookback(int lookbackLeft, int lookbackRight)
{
   if(lookbackLeft < 1 || lookbackRight < 1)
      return;
   
   m_lookbackLeft = lookbackLeft;
   m_lookbackRight = lookbackRight;
   Reset();
}

//+------------------------------------------------------------------+
//| Réinitialiser le détecteur                                      |
//+------------------------------------------------------------------+
void CPivotDetector::Reset()
{
   m_lastProcessed = -1;
   
   // Réinitialiser les structures
   for(int i = 0; i < ArraySize(m_pivotHighs); i++)
   {
      m_pivotHighs[i].position = -1;
      m_pivotHighs[i].value = 0.0;
      m_pivotHighs[i].time = 0;
      m_pivotHighs[i].isValid = false;
   }
   
   for(int i = 0; i < ArraySize(m_pivotLows); i++)
   {
      m_pivotLows[i].position = -1;
      m_pivotLows[i].value = 0.0;
      m_pivotLows[i].time = 0;
      m_pivotLows[i].isValid = false;
   }
}

//+------------------------------------------------------------------+
//| Valider les paramètres de configuration                          |
//+------------------------------------------------------------------+
bool CPivotDetector::ValidateParameters() const
{
   if(m_lookbackLeft < 1 || m_lookbackRight < 1)
   {
      Print("❌ CPivotDetector::ValidateParameters - Lookbacks invalides: Left=", m_lookbackLeft, ", Right=", m_lookbackRight);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Valider une position dans un buffer                              |
//+------------------------------------------------------------------+
bool CPivotDetector::ValidatePosition(int pos, int bufferSize) const
{
   if(pos < 0 || pos >= bufferSize)
   {
      Print("❌ CPivotDetector::ValidatePosition - Position invalide: ", pos, " (Buffer size: ", bufferSize, ")");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialiser les buffers internes                                 |
//+------------------------------------------------------------------+
bool CPivotDetector::InitializeBuffers()
{
   if(m_lookbackLeft < 1 || m_lookbackRight < 1)
      return false;
   
   ArrayResize(m_pivotHighs, MAX_PIVOTS);
   ArrayResize(m_pivotLows, MAX_PIVOTS);
   
   // Initialiser les structures
   for(int i = 0; i < MAX_PIVOTS; i++)
   {
      m_pivotHighs[i].position = -1;
      m_pivotHighs[i].value = 0.0;
      m_pivotHighs[i].time = 0;
      m_pivotHighs[i].isValid = false;
      m_pivotLows[i].position = -1;
      m_pivotLows[i].value = 0.0;
      m_pivotLows[i].time = 0;
      m_pivotLows[i].isValid = false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si une position peut être un pivot valide               |
//+------------------------------------------------------------------+
bool CPivotDetector::IsValidPivotPosition(int pos, int bufferSize) const
{
   return (pos >= m_lookbackRight && pos + m_lookbackLeft < bufferSize);
}

//+------------------------------------------------------------------+
//| Nettoyer les anciens pivots (pour optimisation mémoire)          |
//+------------------------------------------------------------------+
void CPivotDetector::CleanOldPivots()
{
   // Cette méthode peut être implémentée pour nettoyer les anciens pivots
   // si nécessaire pour l'optimisation mémoire
   // Pour l'instant, on garde tous les pivots trouvés
}

//+------------------------------------------------------------------+
