//+------------------------------------------------------------------+
//|                                                RSI_Calculator.mqh |
//|                         RSI Divergence Trading System              |
//|                        Classe pour calcul RSI optimisé              |
//+------------------------------------------------------------------+
//| Version: 1.0                                                     |
//| Changelog:                                                       |
//| ✅ [FEATURE] Calcul RSI avec formule RMA (équivalent Pine Script) |
//| ✅ [PERFORMANCE] Support calculs incrémentaux avec prev_calculated |
//| ✅ [PERFORMANCE] Buffers statiques pour éviter allocations répétées |
//| ✅ [VALIDATION] Validation robuste des paramètres d'entrée        |
//| ✅ [COMPATIBILITY] Compatible EA et Indicateurs                   |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Énumération pour les types de divergence                         |
//+------------------------------------------------------------------+
enum ENUM_DIVERGENCE_TYPE
{
   DIVERGENCE_NONE = 0,        // Aucune divergence
   DIVERGENCE_REGULAR_BULL,    // Divergence bullish régulière
   DIVERGENCE_REGULAR_BEAR,    // Divergence bearish régulière
   DIVERGENCE_HIDDEN_BULL,     // Divergence bullish cachée
   DIVERGENCE_HIDDEN_BEAR      // Divergence bearish cachée
};

//+------------------------------------------------------------------+
//| Classe pour calcul RSI optimisé                                  |
//+------------------------------------------------------------------+
class CRSICalculator
{
private:
   // Paramètres de configuration
   int                m_period;              // Période RSI
   ENUM_APPLIED_PRICE m_appliedPrice;        // Prix appliqué
   
   // Buffers de calcul
   double             m_upBuffer[];          // Buffer des gains
   double             m_downBuffer[];        // Buffer des pertes
   double             m_rsiBuffer[];         // Buffer RSI final
   
   // Variables de contrôle
   bool               m_initialized;         // État d'initialisation
   int                m_lastCalculated;      // Dernière barre calculée
   
   // Constantes
   int MAX_BUFFER_SIZE;  // Taille maximale des buffers

public:
   // Constructeur
   CRSICalculator(int rsiPeriod = 3, ENUM_APPLIED_PRICE appliedPrice = PRICE_CLOSE);
   
   // Destructeur
   ~CRSICalculator();
   
   // Méthodes principales
   bool Calculate(const int rates_total, const int prev_calculated, const double &close[]);
   bool Calculate(const int rates_total, const int prev_calculated, const double &open[], 
                  const double &high[], const double &low[], const double &close[]);
   
   // Méthodes d'accès aux données
   double GetValue(int index);
   bool GetBuffer(double &output[], int start = 0, int count = -1);
   bool IsValid(int index);
   
   // Méthodes de configuration
   void SetPeriod(int period);
   void SetAppliedPrice(ENUM_APPLIED_PRICE appliedPrice);
   int GetPeriod() const { return m_period; }
   ENUM_APPLIED_PRICE GetAppliedPrice() const { return m_appliedPrice; }
   
   // Méthodes utilitaires
   void Reset();
   bool IsInitialized() const { return m_initialized; }
   int GetLastCalculated() const { return m_lastCalculated; }

private:
   // Méthodes internes
   bool InitializeBuffers(int size);
   bool ValidateParameters(int rates_total);
   double GetAppliedPriceValue(int index, const double &open[], const double &high[], 
                              const double &low[], const double &close[]);
};

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
CRSICalculator::CRSICalculator(int rsiPeriod = 3, ENUM_APPLIED_PRICE appliedPrice = PRICE_CLOSE)
{
   m_period = rsiPeriod;
   m_appliedPrice = appliedPrice;
   m_initialized = false;
   m_lastCalculated = -1;
   MAX_BUFFER_SIZE = 10000;  // Initialiser la constante
   
   // Initialiser les buffers
   ArrayResize(m_upBuffer, MAX_BUFFER_SIZE);
   ArrayResize(m_downBuffer, MAX_BUFFER_SIZE);
   ArrayResize(m_rsiBuffer, MAX_BUFFER_SIZE);
   
   ArrayInitialize(m_upBuffer, 0.0);
   ArrayInitialize(m_downBuffer, 0.0);
   ArrayInitialize(m_rsiBuffer, EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
CRSICalculator::~CRSICalculator()
{
   ArrayFree(m_upBuffer);
   ArrayFree(m_downBuffer);
   ArrayFree(m_rsiBuffer);
}

//+------------------------------------------------------------------+
//| Calcul RSI avec array de prix close uniquement                  |
//+------------------------------------------------------------------+
bool CRSICalculator::Calculate(const int rates_total, const int prev_calculated, const double &close[])
{
   // Validation des paramètres
   if(!ValidateParameters(rates_total))
      return false;
   
   // Initialiser les buffers si nécessaire
   if(!m_initialized)
   {
      if(!InitializeBuffers(rates_total))
         return false;
   }
   
   // Déterminer la position de départ
   int start;
   if(prev_calculated == 0)
   {
      // Premier calcul : calculer tout
      start = rates_total - m_period - 1;
      if(start < 0) start = 0;
   }
   else
   {
      // Calcul incrémental : seulement les nouvelles barres
      start = rates_total - prev_calculated;
      if(start < 0) start = 0;
   }
   
   // Calcul initial avec SMA (première fois seulement)
   if(prev_calculated == 0)
   {
      if(start + m_period < rates_total)
      {
         double sumUp = 0, sumDown = 0;
         for(int j = 0; j < m_period; j++)
         {
            int idx = start + 1 + j;
            if(idx >= rates_total || idx >= ArraySize(close) || idx - 1 < 0 || idx - 1 >= ArraySize(close))
               break;
            
            double change = close[idx - 1] - close[idx];
            if(change > 0)
               sumUp += change;
            else
               sumDown += -change;
         }
         
         if(start >= 0 && start < ArraySize(m_upBuffer) && start < ArraySize(m_downBuffer))
         {
            m_upBuffer[start] = sumUp / m_period;
            m_downBuffer[start] = sumDown / m_period;
            
            // Calcul du RSI initial
            if(m_downBuffer[start] == 0)
               m_rsiBuffer[start] = 100;
            else if(m_upBuffer[start] == 0)
               m_rsiBuffer[start] = 0;
            else
               m_rsiBuffer[start] = 100.0 - (100.0 / (1.0 + m_upBuffer[start] / m_downBuffer[start]));
         }
      }
   }
   
   // Application de la formule RMA (équivalent ta.rma de Pine Script)
   for(int i = start; i >= 0; i--)
   {
      // Validation des indices
      if(i + 1 >= rates_total || i + 1 >= ArraySize(close) || i >= ArraySize(close) ||
         i >= ArraySize(m_upBuffer) || i + 1 >= ArraySize(m_upBuffer) ||
         i >= ArraySize(m_downBuffer) || i + 1 >= ArraySize(m_downBuffer) ||
         i >= ArraySize(m_rsiBuffer))
         continue;
      
      double change = close[i] - close[i + 1];
      
      // Formule RMA (équivalent ta.rma de Pine Script)
      m_upBuffer[i] = (m_upBuffer[i + 1] * (m_period - 1) + MathMax(change, 0)) / m_period;
      m_downBuffer[i] = (m_downBuffer[i + 1] * (m_period - 1) + MathMax(-change, 0)) / m_period;
      
      // Calcul du RSI
      if(m_downBuffer[i] == 0)
         m_rsiBuffer[i] = 100;
      else if(m_upBuffer[i] == 0)
         m_rsiBuffer[i] = 0;
      else
         m_rsiBuffer[i] = 100.0 - (100.0 / (1.0 + m_upBuffer[i] / m_downBuffer[i]));
   }
   
   m_lastCalculated = rates_total - 1;
   return true;
}

//+------------------------------------------------------------------+
//| Calcul RSI avec arrays OHLC complets                            |
//+------------------------------------------------------------------+
bool CRSICalculator::Calculate(const int rates_total, const int prev_calculated, 
                               const double &open[], const double &high[], 
                               const double &low[], const double &close[])
{
   // Créer un array temporaire pour les prix appliqués
   double appliedPrice[];
   ArrayResize(appliedPrice, rates_total);
   
   // Remplir l'array selon le prix appliqué
   for(int i = 0; i < rates_total; i++)
   {
      if(i >= ArraySize(open) || i >= ArraySize(high) || i >= ArraySize(low) || i >= ArraySize(close))
         continue;
      
      appliedPrice[i] = GetAppliedPriceValue(i, open, high, low, close);
   }
   
   // Appeler la méthode principale avec l'array de prix appliqués
   return Calculate(rates_total, prev_calculated, appliedPrice);
}

//+------------------------------------------------------------------+
//| Récupérer une valeur RSI à un index donné                        |
//+------------------------------------------------------------------+
double CRSICalculator::GetValue(int index)
{
   if(!m_initialized || index < 0 || index >= ArraySize(m_rsiBuffer))
      return EMPTY_VALUE;
   
   return m_rsiBuffer[index];
}

//+------------------------------------------------------------------+
//| Récupérer le buffer RSI complet                                  |
//+------------------------------------------------------------------+
bool CRSICalculator::GetBuffer(double &output[], int start = 0, int count = -1)
{
   if(!m_initialized || ArraySize(m_rsiBuffer) == 0)
      return false;
   
   int bufferSize = ArraySize(m_rsiBuffer);
   if(start < 0 || start >= bufferSize)
      return false;
   
   if(count < 0)
      count = bufferSize - start;
   
   if(start + count > bufferSize)
      count = bufferSize - start;
   
   ArrayResize(output, count);
   
   for(int i = 0; i < count; i++)
   {
      output[i] = m_rsiBuffer[start + i];
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si une valeur RSI est valide                           |
//+------------------------------------------------------------------+
bool CRSICalculator::IsValid(int index)
{
   if(!m_initialized || index < 0 || index >= ArraySize(m_rsiBuffer))
      return false;
   
   return (m_rsiBuffer[index] != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Définir la période RSI                                          |
//+------------------------------------------------------------------+
void CRSICalculator::SetPeriod(int period)
{
   if(period < 2)
      return;
   
   m_period = period;
   Reset();
}

//+------------------------------------------------------------------+
//| Définir le prix appliqué                                        |
//+------------------------------------------------------------------+
void CRSICalculator::SetAppliedPrice(ENUM_APPLIED_PRICE appliedPrice)
{
   m_appliedPrice = appliedPrice;
   Reset();
}

//+------------------------------------------------------------------+
//| Réinitialiser le calculateur                                    |
//+------------------------------------------------------------------+
void CRSICalculator::Reset()
{
   m_initialized = false;
   m_lastCalculated = -1;
   
   ArrayInitialize(m_upBuffer, 0.0);
   ArrayInitialize(m_downBuffer, 0.0);
   ArrayInitialize(m_rsiBuffer, EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Initialiser les buffers                                         |
//+------------------------------------------------------------------+
bool CRSICalculator::InitializeBuffers(int size)
{
   if(size <= 0 || size > MAX_BUFFER_SIZE)
      return false;
   
   ArrayResize(m_upBuffer, size);
   ArrayResize(m_downBuffer, size);
   ArrayResize(m_rsiBuffer, size);
   
   ArrayInitialize(m_upBuffer, 0.0);
   ArrayInitialize(m_downBuffer, 0.0);
   ArrayInitialize(m_rsiBuffer, EMPTY_VALUE);
   
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Valider les paramètres d'entrée                                 |
//+------------------------------------------------------------------+
bool CRSICalculator::ValidateParameters(int rates_total)
{
   if(rates_total < m_period + 2)
   {
      Print("❌ CRSICalculator::ValidateParameters - Pas assez de barres: ", rates_total, " (minimum: ", m_period + 2, ")");
      return false;
   }
   
   if(m_period < 2)
   {
      Print("❌ CRSICalculator::ValidateParameters - Période RSI invalide: ", m_period);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur du prix appliqué                              |
//+------------------------------------------------------------------+
double CRSICalculator::GetAppliedPriceValue(int index, const double &open[], const double &high[], 
                                           const double &low[], const double &close[])
{
   if(index < 0 || index >= ArraySize(close))
      return 0.0;
   
   switch(m_appliedPrice)
   {
      case PRICE_CLOSE:
         return close[index];
      case PRICE_OPEN:
         return open[index];
      case PRICE_HIGH:
         return high[index];
      case PRICE_LOW:
         return low[index];
      case PRICE_MEDIAN:
         return (high[index] + low[index]) / 2.0;
      case PRICE_TYPICAL:
         return (high[index] + low[index] + close[index]) / 3.0;
      case PRICE_WEIGHTED:
         return (high[index] + low[index] + close[index] + close[index]) / 4.0;
      default:
         return close[index];
   }
}

//+------------------------------------------------------------------+
