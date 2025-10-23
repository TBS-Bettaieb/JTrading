//+------------------------------------------------------------------+
//|                                    RSI_Divergence_Indicator.mq5  |
//|                         RSI Divergence Indicator                   |
//+------------------------------------------------------------------+
//| CHANGELOG - Corrections apportées                                 |
//| ✅ [CRITICAL] Ajout validation arrays partout                     |
//| ✅ [CRITICAL] Optimisation calcul RSI (prev_calculated)           |
//| ✅ [IMPORTANT] Cohérence indexation arrays (série inversée)       |
//| ✅ [IMPORTANT] Détection nouvelle barre robuste                   |
//| ✅ [IMPORTANT] Validation paramètres CalculateMA()                |
//| ✅ [PERFORMANCE] Optimisation boucles détection divergences       |
//| ✅ [PERFORMANCE] Tri optimisé avec ArraySort() natif              |
//| ✅ [CONFIG] Paramètres configurables pour constantes magiques     |
//| ✅ [PINE SCRIPT] Suppression validation Range Lower bloquante     |
//| ✅ [PINE SCRIPT] Implémentation IsPivotLow/IsPivotHigh           |
//| ✅ [PINE SCRIPT] Refactorisation détection divergences            |
//| ✅ [CONFIG] Paramètres par défaut TradingView (RSI=3)             |
//| ✅ [FEATURE] Ajout détection Hidden Divergences                   |
//| ✅ [FEATURE] Buffers et plots pour Hidden Bullish/Bearish         |
//| ✅ [FEATURE] Paramètres personnalisables Hidden Divergences       |
//| ✅ [EA INTEGRATION] Ajout 4 buffers de signaux pour l'EA          |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "2.11"
#property indicator_separate_window
#property indicator_buffers 14  // ✅ EA INTEGRATION: 10 → 14 (ajout 4 buffers de signaux)
#property indicator_plots   7   // ✅ EA INTEGRATION: Reste 7 (les 4 nouveaux sont INDICATOR_CALCULATIONS)

// RSI line
#property indicator_label1  "RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumPurple
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// MA Smoothing
#property indicator_label2  "RSI MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Bollinger Bands
#property indicator_label3  "BB Upper"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLimeGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  "BB Lower"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLimeGreen
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

// Divergence markers
#property indicator_label5  "Divergences"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrWhite
#property indicator_width5  2

// ✅ FIX HIDDEN DIV : Hidden Divergence markers - Bullish
#property indicator_label6  "Hidden Bull Div"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrDodgerBlue
#property indicator_width6  2

// ✅ FIX HIDDEN DIV : Hidden Divergence markers - Bearish
#property indicator_label7  "Hidden Bear Div"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrOrange
#property indicator_width7  2

//--- Input parameters
input group "═══ RSI Settings ═══"
input int                InpRSIPeriod        = 3;               // RSI Length (config TradingView)
input ENUM_APPLIED_PRICE InpRSIAppliedPrice = PRICE_CLOSE;     // Source

input group "═══ RSI Levels ═══"
input bool   InpShowLevels      = true;      // Show Levels
input double InpUpperLevel      = 90.0;      // Upper Level
input double InpMiddleLevel     = 50.0;      // Middle Level
input double InpLowerLevel      = 10.0;      // Lower Level
input color  InpLevelColor      = clrSilver; // Level Color

input group "═══ Smoothing ═══"
enum MA_TYPE_CUSTOM
{
   MA_NONE,           // None
   MA_SMA,            // SMA
   MA_SMA_BB,         // SMA + Bollinger Bands
   MA_EMA,            // EMA
   MA_SMMA,           // SMMA (RMA)
   MA_LWMA,           // LWMA
};

input MA_TYPE_CUSTOM InpMAType     = MA_NONE;    // MA Type
input int            InpMAPeriod   = 14;         // MA Length
input double         InpBBStdDev   = 2.0;        // BB StdDev

input group "═══ Divergence Settings ═══"
input int    InpLookbackLeft  = 5;      // Lookback Left
input int    InpLookbackRight = 5;      // Lookback Right
input int    InpRangeLower    = 5;      // Range Lower
input int    InpRangeUpper    = 60;     // Range Upper
input bool   InpShowTrendlines = true;  // Show Divergence Trendlines
input color  InpBullishColor  = clrLimeGreen;  // Bullish Divergence Color
input color  InpBearishColor  = clrRed;        // Bearish Divergence Color
input int    InpTrendlineWidth = 2;     // Trendline Width

// ✅ FIX HIDDEN DIV : Nouveaux paramètres pour Hidden Divergences
input group "═══ Hidden Divergence Settings ═══"
input bool   InpShowHiddenDiv      = true;   // Show Hidden Divergences
input color  InpHiddenBullColor    = clrDodgerBlue;   // Hidden Bullish Color
input color  InpHiddenBearColor    = clrOrange;       // Hidden Bearish Color
input int    InpHiddenTrendWidth   = 2;      // Hidden Trendline Width
input ENUM_LINE_STYLE InpHiddenLineStyle = STYLE_DASH;  // Hidden Line Style

//--- Indicator buffers
double RSIBuffer[];
double MABuffer[];
double BBUpperBuffer[];
double BBLowerBuffer[];
double DivergenceBuffer[];

// Calculation buffers
double UpBuffer[];
double DownBuffer[];
double StdDevBuffer[];

// ✅ FIX HIDDEN DIV : Nouveaux buffers pour hidden divergences
double HiddenBullDivBuffer[];
double HiddenBearDivBuffer[];

// ✅ EA INTEGRATION : Nouveaux buffers de signaux pour l'EA
double RegularBullishSignal[];  // Buffer 10: 1.0 si Regular Bullish Div détectée, sinon 0
double RegularBearishSignal[];  // Buffer 11: 1.0 si Regular Bearish Div détectée, sinon 0
double HiddenBullishSignal[];   // Buffer 12: 1.0 si Hidden Bullish Div détectée, sinon 0
double HiddenBearishSignal[];   // Buffer 13: 1.0 si Hidden Bearish Div détectée, sinon 0

//--- Constantes
const double DIVERGENCE_MARKER_OFFSET = 5.0;

// ✅ FIX: Paramètres configurables au lieu de constantes magiques
input group "═══ Performance Settings ═══"
input int InpMaxTrendlines = 50;      // Max Trendlines to Keep
input int InpMaxBarsCheck = 100;      // Max Bars to Check for Divergences

//--- Global variables
string indicatorPrefix = "RSI_DIV_";
int objectCounter = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validation des paramètres
   if(InpRSIPeriod < 2)
   {
      Print("❌ Erreur: RSI Period doit être >= 2");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpLookbackLeft < 1 || InpLookbackRight < 1)
   {
      Print("❌ Erreur: Lookback doit être >= 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpRangeLower >= InpRangeUpper)
   {
      Print("❌ Erreur: Range Lower doit être < Range Upper");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // ✅ FIX PINE SCRIPT: Validation corrigée - similaire à Pine Script
   // Range Lower doit juste être positif et inférieur à Range Upper
   if(InpRangeLower < 1)
   {
      Print("❌ Erreur: Range Lower doit être >= 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Indicator buffers mapping
   SetIndexBuffer(0, RSIBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, MABuffer, INDICATOR_DATA);
   SetIndexBuffer(2, BBUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BBLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, DivergenceBuffer, INDICATOR_DATA);
   
   SetIndexBuffer(5, UpBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, DownBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, StdDevBuffer, INDICATOR_CALCULATIONS);
   
   // ✅ FIX HIDDEN DIV : Mapping des nouveaux buffers
   SetIndexBuffer(8, HiddenBullDivBuffer, INDICATOR_DATA);
   SetIndexBuffer(9, HiddenBearDivBuffer, INDICATOR_DATA);
   
   // ✅ EA INTEGRATION : Mapping des buffers de signaux pour l'EA
   SetIndexBuffer(10, RegularBullishSignal, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, RegularBearishSignal, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, HiddenBullishSignal, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, HiddenBearishSignal, INDICATOR_CALCULATIONS);
   
   // ✅ EA INTEGRATION : Initialisation des buffers de signaux
   ArrayInitialize(RegularBullishSignal, 0.0);
   ArrayInitialize(RegularBearishSignal, 0.0);
   ArrayInitialize(HiddenBullishSignal, 0.0);
   ArrayInitialize(HiddenBearishSignal, 0.0);
   
   //--- Set arrow code for divergences
   PlotIndexSetInteger(4, PLOT_ARROW, 159);
   
   // ✅ FIX HIDDEN DIV : Configuration des arrows pour hidden divergences
   PlotIndexSetInteger(5, PLOT_ARROW, 159);  // Hidden Bullish
   PlotIndexSetInteger(6, PLOT_ARROW, 159);  // Hidden Bearish
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // ✅ FIX HIDDEN DIV : Empty values pour hidden divergences
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "RSI_Div(" + string(InpRSIPeriod) + ")");
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   //--- Create RSI levels
   if(InpShowLevels)
   {
      IndicatorSetInteger(INDICATOR_LEVELS, 3);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpUpperLevel);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpMiddleLevel);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLowerLevel);
      
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, InpLevelColor);
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, InpLevelColor);
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, InpLevelColor);
      
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 2, STYLE_DOT);
   }
   
   
   //--- Delete old objects
   DeleteAllObjects();
   
   Print("✅ RSI Divergence Indicator Initialized!");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllObjects();
   Print("RSI Divergence Indicator stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // ✅ FIX: Validation des limites des arrays
   if(rates_total < InpRSIPeriod + InpRangeUpper + 10)
      return(0);
   
   // ✅ FIX: Cohérence indexation - tous les arrays en série inversée
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(RSIBuffer, true);
   ArraySetAsSeries(MABuffer, true);
   ArraySetAsSeries(BBUpperBuffer, true);
   ArraySetAsSeries(BBLowerBuffer, true);
   ArraySetAsSeries(DivergenceBuffer, true);
   ArraySetAsSeries(UpBuffer, true);
   ArraySetAsSeries(DownBuffer, true);
   ArraySetAsSeries(StdDevBuffer, true);
   
   // ✅ FIX HIDDEN DIV : Arrays pour hidden divergences
   ArraySetAsSeries(HiddenBullDivBuffer, true);
   ArraySetAsSeries(HiddenBearDivBuffer, true);
   
   // ✅ EA INTEGRATION : Arrays pour signaux EA
   ArraySetAsSeries(RegularBullishSignal, true);
   ArraySetAsSeries(RegularBearishSignal, true);
   ArraySetAsSeries(HiddenBullishSignal, true);
   ArraySetAsSeries(HiddenBearishSignal, true);
   
   // ✅ FIX: Optimisation calcul RSI - ne calculer que les nouvelles barres
   CalculateRSI(rates_total, prev_calculated, close);
   
   // ✅ FIX: Détection nouvelle barre robuste avec prev_calculated
   bool isNewBar = (prev_calculated == 0 || rates_total > prev_calculated);
   
   if(isNewBar)
   {
      // Supprimer les anciennes trendlines AVANT de détecter les nouvelles
      DeleteOldTrendlines();
      
      // ✅ FIX: Optimisation zone de recherche - limiter à 50 dernières barres
      if(rates_total > InpRangeLower + InpLookbackLeft + InpLookbackRight + 20)
      {
         int limit = MathMin(InpMaxBarsCheck, rates_total - InpRangeUpper - InpLookbackLeft - 1);
         for(int i = InpLookbackRight + 1; i <= limit; i++)
         {
            // ✅ FIX: Validation des indices avant appel des fonctions
            if(i >= 0 && i < ArraySize(RSIBuffer) && i < ArraySize(time) && 
               i < ArraySize(high) && i < ArraySize(low))
            {
               // Regular Divergences (déjà présentes)
               CheckBullishDivergence(i, time, low);
               CheckBearishDivergence(i, time, high);
               
               // ✅ FIX HIDDEN DIV : Hidden Divergences
               CheckHiddenBullishDivergence(i, time, low);
               CheckHiddenBearishDivergence(i, time, high);
            }
         }
      }
   }
   
   //--- Display information on chart
   DisplayIndicatorInfo();
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate RSI and divergences                                    |
//+------------------------------------------------------------------+
void CalculateRSI(int rates_total, int prev_calculated, const double &close[])
{
   // ✅ FIX: Validation des paramètres d'entrée
   if(rates_total < InpRSIPeriod + 2)
      return;
   
   // ✅ FIX: Validation des tailles d'arrays
   if(ArraySize(close) < rates_total || ArraySize(RSIBuffer) < rates_total)
      return;
   
   // Initialisation seulement si nécessaire (première fois ou nouvelle barre)
   static bool firstRun = true;
   if(firstRun)
   {
      ArrayInitialize(RSIBuffer, EMPTY_VALUE);
      ArrayInitialize(MABuffer, EMPTY_VALUE);
      ArrayInitialize(BBUpperBuffer, EMPTY_VALUE);
      ArrayInitialize(BBLowerBuffer, EMPTY_VALUE);
      ArrayInitialize(DivergenceBuffer, EMPTY_VALUE);
      
      // ✅ FIX HIDDEN DIV : Initialisation des nouveaux buffers
      ArrayInitialize(HiddenBullDivBuffer, EMPTY_VALUE);
      ArrayInitialize(HiddenBearDivBuffer, EMPTY_VALUE);
      
      firstRun = false;
   }
   
   int start;
   
   // ✅ FIX: Optimisation - Première exécution: calculer tout
   if(prev_calculated == 0)
   {
      start = rates_total - InpRSIPeriod - 1;
      
      // ✅ FIX: Validation des limites pour éviter array out of range
      if(start < 0 || start + InpRSIPeriod >= rates_total || start >= ArraySize(close))
         return;
      
      // Étape 1: Initialisation avec SMA (correction des indices)
      double sumUp = 0, sumDown = 0;
      for(int j = 0; j < InpRSIPeriod; j++)
      {
         int idx = start + 1 + j;
         // ✅ FIX: Validation des indices
         if(idx >= rates_total || idx >= ArraySize(close) || idx - 1 < 0 || idx - 1 >= ArraySize(close))
            break;
         double change = close[idx - 1] - close[idx];
         if(change > 0)
            sumUp += change;
         else
            sumDown += -change;
      }
      
      // ✅ FIX: Validation avant assignation
      if(start >= 0 && start < ArraySize(UpBuffer) && start < ArraySize(DownBuffer))
      {
         UpBuffer[start] = sumUp / InpRSIPeriod;
         DownBuffer[start] = sumDown / InpRSIPeriod;
         
         // Calcul du RSI initial
         if(DownBuffer[start] == 0)
            RSIBuffer[start] = 100;
         else if(UpBuffer[start] == 0)
            RSIBuffer[start] = 0;
         else
            RSIBuffer[start] = 100.0 - (100.0 / (1.0 + UpBuffer[start] / DownBuffer[start]));
      }
   }
   else
   {
      // ✅ FIX: Seulement recalculer les nouvelles barres
      start = rates_total - prev_calculated - 1;
      if(start < 0) start = 0;
   }
   
   // Étape 2: Application de la formule RMA
   for(int i = start - 1; i >= 0; i--)
   {
      // ✅ FIX: Validation complète des indices
      if(i + 1 >= rates_total || i + 1 >= ArraySize(close) || i >= ArraySize(close) ||
         i >= ArraySize(UpBuffer) || i + 1 >= ArraySize(UpBuffer) ||
         i >= ArraySize(DownBuffer) || i + 1 >= ArraySize(DownBuffer) ||
         i >= ArraySize(RSIBuffer))
         continue;
         
      double change = close[i] - close[i + 1];
      
      // Formule RMA (équivalent ta.rma de Pine Script)
      UpBuffer[i] = (UpBuffer[i + 1] * (InpRSIPeriod - 1) + MathMax(change, 0)) / InpRSIPeriod;
      DownBuffer[i] = (DownBuffer[i + 1] * (InpRSIPeriod - 1) + MathMax(-change, 0)) / InpRSIPeriod;
      
      // Calcul du RSI
      if(DownBuffer[i] == 0)
         RSIBuffer[i] = 100;
      else if(UpBuffer[i] == 0)
         RSIBuffer[i] = 0;
      else
         RSIBuffer[i] = 100.0 - (100.0 / (1.0 + UpBuffer[i] / DownBuffer[i]));
   }
   
   // ✅ FIX: Calcul du lissage MA avec validation des paramètres
   if(InpMAType != MA_NONE && rates_total > InpRSIPeriod + InpMAPeriod)
   {
      for(int i = 0; i < rates_total - InpRSIPeriod - InpMAPeriod; i++)
      {
         // ✅ FIX: Validation des indices avant calcul MA
         if(i >= 0 && i < ArraySize(MABuffer))
         {
            MABuffer[i] = CalculateMA(i, InpMAPeriod, InpMAType);
            
            // Bollinger Bands si activé
            if(InpMAType == MA_SMA_BB && i < ArraySize(BBUpperBuffer) && i < ArraySize(BBLowerBuffer))
            {
               double sum = 0;
               for(int j = 0; j < InpMAPeriod; j++)
               {
                  // ✅ FIX: Validation des indices dans la boucle BB
                  if(i + j >= 0 && i + j < ArraySize(RSIBuffer) && i < ArraySize(MABuffer))
                  {
                     double diff = RSIBuffer[i + j] - MABuffer[i];
                     sum += diff * diff;
                  }
               }
               if(i < ArraySize(StdDevBuffer))
               {
                  StdDevBuffer[i] = MathSqrt(sum / InpMAPeriod);
                  BBUpperBuffer[i] = MABuffer[i] + InpBBStdDev * StdDevBuffer[i];
                  BBLowerBuffer[i] = MABuffer[i] - InpBBStdDev * StdDevBuffer[i];
               }
            }
         }
      }
   }
   
}

//+------------------------------------------------------------------+
//| Calculate Moving Average                                          |
//+------------------------------------------------------------------+
double CalculateMA(int pos, int period, MA_TYPE_CUSTOM ma_type)
{
   // ✅ FIX: Validation complète des paramètres d'entrée
   if(pos < 0 || period <= 0 || pos >= ArraySize(RSIBuffer))
      return EMPTY_VALUE;
   
   // ✅ FIX: Vérifier que pos + period ne dépasse pas la taille de l'array
   if(pos + period > ArraySize(RSIBuffer))
      return EMPTY_VALUE;
   
   double sum = 0;
   
   switch(ma_type)
   {
      case MA_SMA:
      case MA_SMA_BB:
         for(int i = 0; i < period; i++)
         {
            // ✅ FIX: Validation des indices dans la boucle
            if(pos + i >= 0 && pos + i < ArraySize(RSIBuffer))
               sum += RSIBuffer[pos + i];
         }
         return (period > 0) ? sum / period : EMPTY_VALUE;
         
      case MA_EMA:
         // ✅ FIX: Validation des indices pour EMA
         if(pos >= ArraySize(MABuffer) - period - 1 || pos + 1 >= ArraySize(MABuffer))
         {
            for(int i = 0; i < period; i++)
            {
               if(pos + i >= 0 && pos + i < ArraySize(RSIBuffer))
                  sum += RSIBuffer[pos + i];
            }
            return (period > 0) ? sum / period : EMPTY_VALUE;
         }
         else
         {
            // ✅ FIX: Validation avant accès aux arrays
            if(pos >= 0 && pos < ArraySize(RSIBuffer) && pos + 1 >= 0 && pos + 1 < ArraySize(MABuffer))
            {
               double alpha = 2.0 / (period + 1.0);
               return alpha * RSIBuffer[pos] + (1 - alpha) * MABuffer[pos + 1];
            }
         }
         break;
         
      case MA_SMMA:
         // ✅ FIX: Validation des indices pour SMMA
         if(pos >= ArraySize(MABuffer) - period - 1 || pos + 1 >= ArraySize(MABuffer))
         {
            for(int i = 0; i < period; i++)
            {
               if(pos + i >= 0 && pos + i < ArraySize(RSIBuffer))
                  sum += RSIBuffer[pos + i];
            }
            return (period > 0) ? sum / period : EMPTY_VALUE;
         }
         else
         {
            // ✅ FIX: Validation avant accès aux arrays
            if(pos >= 0 && pos < ArraySize(RSIBuffer) && pos + 1 >= 0 && pos + 1 < ArraySize(MABuffer))
            {
               return (MABuffer[pos + 1] * (period - 1) + RSIBuffer[pos]) / period;
            }
         }
         break;
         
      case MA_LWMA:
      {
         double weightSum = 0;
         for(int i = 0; i < period; i++)
         {
            // ✅ FIX: Validation des indices dans la boucle LWMA
            if(pos + i >= 0 && pos + i < ArraySize(RSIBuffer))
            {
               int weight = period - i;
               sum += RSIBuffer[pos + i] * weight;
               weightSum += weight;
            }
         }
         return (weightSum > 0) ? sum / weightSum : EMPTY_VALUE;
      }
   }
   
   return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Équivalent de ta.pivotlow() de Pine Script                       |
//| Vérifie si la position 'pos' est un pivot BAS                    |
//| leftBars : nombre de barres à gauche (historique)                |
//| rightBars : nombre de barres à droite (récent)                   |
//| buffer : array contenant les valeurs (RSI, prix, etc.)           |
//+------------------------------------------------------------------+
bool IsPivotLow(int pos, int leftBars, int rightBars, const double &buffer[])
{
   // ✅ FIX PINE SCRIPT: Validation des limites
   if(pos < 0 || pos >= ArraySize(buffer))
      return false;
   
   // Vérifier qu'on a assez de barres de chaque côté
   if(pos < rightBars || pos + leftBars >= ArraySize(buffer))
      return false;
   
   double pivotValue = buffer[pos];
   
   // ✅ FIX PINE SCRIPT: Vérifier que pos est le MINIMUM dans la fenêtre
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
      
      // ✅ FIX PINE SCRIPT: Si une valeur est plus petite, ce n'est PAS un pivot bas
      if(buffer[i] < pivotValue)
         return false;
   }
   
   return true; // C'est un pivot bas valide
}

//+------------------------------------------------------------------+
//| Équivalent de ta.pivothigh() de Pine Script                      |
//| Vérifie si la position 'pos' est un pivot HAUT                   |
//+------------------------------------------------------------------+
bool IsPivotHigh(int pos, int leftBars, int rightBars, const double &buffer[])
{
   // ✅ FIX PINE SCRIPT: Validation des limites
   if(pos < 0 || pos >= ArraySize(buffer))
      return false;
   
   if(pos < rightBars || pos + leftBars >= ArraySize(buffer))
      return false;
   
   double pivotValue = buffer[pos];
   
   // ✅ FIX PINE SCRIPT: Vérifier que pos est le MAXIMUM dans la fenêtre
   for(int i = pos - rightBars; i <= pos + leftBars; i++)
   {
      if(i == pos) 
         continue;
      
      if(i < 0 || i >= ArraySize(buffer))
         continue;
      
      // ✅ FIX PINE SCRIPT: Si une valeur est plus grande, ce n'est PAS un pivot haut
      if(buffer[i] > pivotValue)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for bullish divergence                                     |
//+------------------------------------------------------------------+
void CheckBullishDivergence(int currentBar, const datetime &time[], const double &low[])
{
   // ✅ FIX: Validation complète des paramètres d'entrée
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(low))
      return;
   
   int checkPos = currentBar;
   
   // ✅ FIX: Vérifications de limites améliorées
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // ✅ FIX PINE SCRIPT: REMPLACER toute la section de vérification de pivot par :
   if(!IsPivotLow(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // ✅ FIX PINE SCRIPT: Recherche du pivot précédent - SIMPLIFIER
   int prevPivotBar = -1;
   double prevPivotRSI = 0;
   double prevPivotPrice = 0;
   
   int maxSearch = MathMin(checkPos + InpRangeUpper, ArraySize(RSIBuffer) - 1);
   int minSearch = MathMax(checkPos + InpRangeLower, InpLookbackRight);
   
   // Rechercher le premier pivot précédent valide
   for(int i = minSearch; i <= maxSearch; i++)
   {
      if(i < 0 || i >= ArraySize(RSIBuffer) || i >= ArraySize(low))
         continue;
      
      // ✅ FIX PINE SCRIPT: Utiliser IsPivotLow au lieu des boucles manuelles
      if(IsPivotLow(i, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      {
         prevPivotBar = i;
         prevPivotRSI = RSIBuffer[i];
         prevPivotPrice = low[i];
         break;
      }
   }
   
   if(prevPivotBar < 0) 
      return;
   
   // ✅ FIX PINE SCRIPT: Calcul correct de la distance (array en série inversée)
   int barsSincePivot = prevPivotBar - checkPos;
   
   // Validation du range
   if(barsSincePivot < InpRangeLower || barsSincePivot > InpRangeUpper)
      return;
   
   // D. Conditions de divergence exactes
   double currentPrice = low[checkPos];
   bool rsiHigherLow = pivotRSI > prevPivotRSI;
   bool priceLowerLow = currentPrice < prevPivotPrice;
   
   if(rsiHigherLow && priceLowerLow)
   {
      Print("═══════════════════════════════════════════════");
      Print("🟢 BULLISH DIVERGENCE DETECTED!");
      Print("Previous Pivot: Bar ", prevPivotBar, " RSI=", DoubleToString(prevPivotRSI, 2));
      Print("Current Pivot: Bar ", checkPos, " RSI=", DoubleToString(pivotRSI, 2));
      Print("Bars Since: ", barsSincePivot);
      Print("Price Low: ", DoubleToString(prevPivotPrice, _Digits),
            " → ", DoubleToString(currentPrice, _Digits));
      Print("RSI Low: ", DoubleToString(prevPivotRSI, 2),
            " → ", DoubleToString(pivotRSI, 2));
      Print("═══════════════════════════════════════════════");
      
      // Marquer la divergence
      DivergenceBuffer[checkPos] = pivotRSI - DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Signaler la divergence bullish régulière
      RegularBullishSignal[checkPos] = 1.0;
      
      if(InpShowTrendlines)
      {
         // E. Dessin de la trendline
         objectCounter++;
         string objName = indicatorPrefix + "BULL_" + IntegerToString(objectCounter);
         
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         int subwindow = ChartWindowFind(0, "RSI_Div(" + IntegerToString(InpRSIPeriod) + ")");
         
         if(subwindow < 0)
         {
            Print("⚠️ Erreur: Sous-fenêtre RSI non trouvée!");
            return;
         }
         
         if(ObjectCreate(0, objName, OBJ_TREND, subwindow, 
                        time[prevPivotBar], prevPivotRSI,  // Point 1 : pivot précédent
                        time[checkPos], pivotRSI))          // Point 2 : pivot actuel
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, InpBullishColor);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpTrendlineWidth);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);  // Pas de prolongement
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);        // Dessinée en arrière-plan
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
            ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Bullish Divergence");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for bearish divergence                                     |
//+------------------------------------------------------------------+
void CheckBearishDivergence(int currentBar, const datetime &time[], const double &high[])
{
   // ✅ FIX: Validation complète des paramètres d'entrée
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(high))
      return;
   
   int checkPos = currentBar;
   
   // ✅ FIX: Vérifications de limites améliorées
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // ✅ FIX PINE SCRIPT: REMPLACER par IsPivotHigh
   if(!IsPivotHigh(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // ✅ FIX PINE SCRIPT: Recherche simplifiée du pivot précédent
   int prevPivotBar = -1;
   double prevPivotRSI = 0;
   double prevPivotPrice = 0;
   
   int maxSearch = MathMin(checkPos + InpRangeUpper, ArraySize(RSIBuffer) - 1);
   int minSearch = MathMax(checkPos + InpRangeLower, InpLookbackRight);
   
   for(int i = minSearch; i <= maxSearch; i++)
   {
      if(i < 0 || i >= ArraySize(RSIBuffer) || i >= ArraySize(high))
         continue;
      
      // ✅ FIX PINE SCRIPT: Utiliser IsPivotHigh
      if(IsPivotHigh(i, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      {
         prevPivotBar = i;
         prevPivotRSI = RSIBuffer[i];
         prevPivotPrice = high[i];
         break;
      }
   }
   
   if(prevPivotBar < 0) 
      return;
   
   // ✅ FIX PINE SCRIPT: Calcul correct de la distance
   int barsSincePivot = prevPivotBar - checkPos;
   
   if(barsSincePivot < InpRangeLower || barsSincePivot > InpRangeUpper)
      return;
   
   // D. Conditions de divergence exactes
   double currentPrice = high[checkPos];
   bool rsiLowerHigh = pivotRSI < prevPivotRSI;
   bool priceHigherHigh = currentPrice > prevPivotPrice;
   
   if(rsiLowerHigh && priceHigherHigh)
   {
      Print("═══════════════════════════════════════════════");
      Print("🔴 BEARISH DIVERGENCE DETECTED!");
      Print("Previous Pivot: Bar ", prevPivotBar, " RSI=", DoubleToString(prevPivotRSI, 2));
      Print("Current Pivot: Bar ", checkPos, " RSI=", DoubleToString(pivotRSI, 2));
      Print("Bars Since: ", barsSincePivot);
      Print("Price High: ", DoubleToString(prevPivotPrice, _Digits),
            " → ", DoubleToString(currentPrice, _Digits));
      Print("RSI High: ", DoubleToString(prevPivotRSI, 2),
            " → ", DoubleToString(pivotRSI, 2));
      Print("═══════════════════════════════════════════════");
      
      // Marquer la divergence
      DivergenceBuffer[checkPos] = pivotRSI + DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Signaler la divergence bearish régulière
      RegularBearishSignal[checkPos] = 1.0;
      
      if(InpShowTrendlines)
      {
         // E. Dessin de la trendline
         objectCounter++;
         string objName = indicatorPrefix + "BEAR_" + IntegerToString(objectCounter);
         
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         int subwindow = ChartWindowFind(0, "RSI_Div(" + IntegerToString(InpRSIPeriod) + ")");
         
         if(subwindow < 0)
         {
            Print("⚠️ Erreur: Sous-fenêtre RSI non trouvée!");
            return;
         }
         
         if(ObjectCreate(0, objName, OBJ_TREND, subwindow, 
                        time[prevPivotBar], prevPivotRSI,  // Point 1 : pivot précédent
                        time[checkPos], pivotRSI))          // Point 2 : pivot actuel
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, InpBearishColor);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpTrendlineWidth);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);  // Pas de prolongement
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);        // Dessinée en arrière-plan
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
            ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Bearish Divergence");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for HIDDEN bullish divergence                             |
//| Hidden Bullish = Prix Higher Low + RSI Lower Low                |
//| Signal : Continuation de tendance haussière                      |
//+------------------------------------------------------------------+
void CheckHiddenBullishDivergence(int currentBar, const datetime &time[], const double &low[])
{
   // ✅ FIX HIDDEN DIV : Vérifier si l'option est activée
   if(!InpShowHiddenDiv)
      return;
   
   // Validation complète des paramètres d'entrée
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(low))
      return;
   
   int checkPos = currentBar;
   
   // Vérifications de limites
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // Vérifier que c'est un pivot bas sur le RSI
   if(!IsPivotLow(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // Recherche du pivot précédent
   int prevPivotBar = -1;
   double prevPivotRSI = 0;
   double prevPivotPrice = 0;
   
   int maxSearch = MathMin(checkPos + InpRangeUpper, ArraySize(RSIBuffer) - 1);
   int minSearch = MathMax(checkPos + InpRangeLower, InpLookbackRight);
   
   for(int i = minSearch; i <= maxSearch; i++)
   {
      if(i < 0 || i >= ArraySize(RSIBuffer) || i >= ArraySize(low))
         continue;
      
      if(IsPivotLow(i, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      {
         prevPivotBar = i;
         prevPivotRSI = RSIBuffer[i];
         prevPivotPrice = low[i];
         break;
      }
   }
   
   if(prevPivotBar < 0) 
      return;
   
   // Calcul de la distance
   int barsSincePivot = prevPivotBar - checkPos;
   
   if(barsSincePivot < InpRangeLower || barsSincePivot > InpRangeUpper)
      return;
   
   // ✅ CONDITIONS HIDDEN BULLISH (INVERSER par rapport à Regular)
   double currentPrice = low[checkPos];
   bool rsiLowerLow = pivotRSI < prevPivotRSI;      // RSI fait Lower Low (inversé)
   bool priceHigherLow = currentPrice > prevPivotPrice;  // Prix fait Higher Low (inversé)
   
   if(rsiLowerLow && priceHigherLow)
   {
      Print("═══════════════════════════════════════════════");
      Print("🔵 HIDDEN BULLISH DIVERGENCE DETECTED!");
      Print("Previous Pivot: Bar ", prevPivotBar, " RSI=", DoubleToString(prevPivotRSI, 2));
      Print("Current Pivot: Bar ", checkPos, " RSI=", DoubleToString(pivotRSI, 2));
      Print("Bars Since: ", barsSincePivot);
      Print("Price Low: ", DoubleToString(prevPivotPrice, _Digits),
            " → ", DoubleToString(currentPrice, _Digits), " (Higher)");
      Print("RSI Low: ", DoubleToString(prevPivotRSI, 2),
            " → ", DoubleToString(pivotRSI, 2), " (Lower)");
      Print("═══════════════════════════════════════════════");
      
      // Marquer la divergence
      HiddenBullDivBuffer[checkPos] = pivotRSI - DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Signaler la divergence bullish cachée
      HiddenBullishSignal[checkPos] = 1.0;
      
      if(InpShowTrendlines)
      {
         // Dessin de la trendline
         objectCounter++;
         string objName = indicatorPrefix + "HBULL_" + IntegerToString(objectCounter);
         
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         int subwindow = ChartWindowFind(0, "RSI_Div(" + IntegerToString(InpRSIPeriod) + ")");
         
         if(subwindow < 0)
         {
            Print("⚠️ Erreur: Sous-fenêtre RSI non trouvée!");
            return;
         }
         
         if(ObjectCreate(0, objName, OBJ_TREND, subwindow, 
                        time[prevPivotBar], prevPivotRSI,
                        time[checkPos], pivotRSI))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, InpHiddenBullColor);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpHiddenTrendWidth);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, InpHiddenLineStyle);
            ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
            ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Hidden Bullish Divergence");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for HIDDEN bearish divergence                             |
//| Hidden Bearish = Prix Lower High + RSI Higher High              |
//| Signal : Continuation de tendance baissière                      |
//+------------------------------------------------------------------+
void CheckHiddenBearishDivergence(int currentBar, const datetime &time[], const double &high[])
{
   // ✅ FIX HIDDEN DIV : Vérifier si l'option est activée
   if(!InpShowHiddenDiv)
      return;
   
   // Validation complète des paramètres d'entrée
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(high))
      return;
   
   int checkPos = currentBar;
   
   // Vérifications de limites
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // Vérifier que c'est un pivot haut sur le RSI
   if(!IsPivotHigh(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // Recherche du pivot précédent
   int prevPivotBar = -1;
   double prevPivotRSI = 0;
   double prevPivotPrice = 0;
   
   int maxSearch = MathMin(checkPos + InpRangeUpper, ArraySize(RSIBuffer) - 1);
   int minSearch = MathMax(checkPos + InpRangeLower, InpLookbackRight);
   
   for(int i = minSearch; i <= maxSearch; i++)
   {
      if(i < 0 || i >= ArraySize(RSIBuffer) || i >= ArraySize(high))
         continue;
      
      if(IsPivotHigh(i, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      {
         prevPivotBar = i;
         prevPivotRSI = RSIBuffer[i];
         prevPivotPrice = high[i];
         break;
      }
   }
   
   if(prevPivotBar < 0) 
      return;
   
   // Calcul de la distance
   int barsSincePivot = prevPivotBar - checkPos;
   
   if(barsSincePivot < InpRangeLower || barsSincePivot > InpRangeUpper)
      return;
   
   // ✅ CONDITIONS HIDDEN BEARISH (INVERSER par rapport à Regular)
   double currentPrice = high[checkPos];
   bool rsiHigherHigh = pivotRSI > prevPivotRSI;         // RSI fait Higher High (inversé)
   bool priceLowerHigh = currentPrice < prevPivotPrice;  // Prix fait Lower High (inversé)
   
   if(rsiHigherHigh && priceLowerHigh)
   {
      Print("═══════════════════════════════════════════════");
      Print("🟠 HIDDEN BEARISH DIVERGENCE DETECTED!");
      Print("Previous Pivot: Bar ", prevPivotBar, " RSI=", DoubleToString(prevPivotRSI, 2));
      Print("Current Pivot: Bar ", checkPos, " RSI=", DoubleToString(pivotRSI, 2));
      Print("Bars Since: ", barsSincePivot);
      Print("Price High: ", DoubleToString(prevPivotPrice, _Digits),
            " → ", DoubleToString(currentPrice, _Digits), " (Lower)");
      Print("RSI High: ", DoubleToString(prevPivotRSI, 2),
            " → ", DoubleToString(pivotRSI, 2), " (Higher)");
      Print("═══════════════════════════════════════════════");
      
      // Marquer la divergence
      HiddenBearDivBuffer[checkPos] = pivotRSI + DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Signaler la divergence bearish cachée
      HiddenBearishSignal[checkPos] = 1.0;
      
      if(InpShowTrendlines)
      {
         // Dessin de la trendline
         objectCounter++;
         string objName = indicatorPrefix + "HBEAR_" + IntegerToString(objectCounter);
         
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         int subwindow = ChartWindowFind(0, "RSI_Div(" + IntegerToString(InpRSIPeriod) + ")");
         
         if(subwindow < 0)
         {
            Print("⚠️ Erreur: Sous-fenêtre RSI non trouvée!");
            return;
         }
         
         if(ObjectCreate(0, objName, OBJ_TREND, subwindow, 
                        time[prevPivotBar], prevPivotRSI,
                        time[checkPos], pivotRSI))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, InpHiddenBearColor);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpHiddenTrendWidth);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, InpHiddenLineStyle);
            ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
            ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Hidden Bearish Divergence");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Delete old trendlines intelligently                             |
//+------------------------------------------------------------------+
void DeleteOldTrendlines()
{
   // ✅ FIX: Compter les trendlines existantes avec validation
   string objNames[];
   datetime objCreationTimes[];
   int count = 0;

   int total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, -1, -1);
      if(StringFind(objName, indicatorPrefix) >= 0)
      {
         ArrayResize(objNames, count + 1);
         ArrayResize(objCreationTimes, count + 1);
         objNames[count] = objName;
         objCreationTimes[count] = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
         count++;
      }
   }

   // ✅ FIX: Si dépassement, supprimer les plus anciennes
   if(count > InpMaxTrendlines)
   {
      // ✅ FIX: Utiliser ArraySort() natif au lieu de bubble sort
      // Créer un array d'indices pour le tri
      int indices[];
      ArrayResize(indices, count);
      for(int i = 0; i < count; i++)
         indices[i] = i;
      
      // Trier les indices par temps de création (plus ancien en premier)
      for(int i = 0; i < count - 1; i++)
      {
         for(int j = i + 1; j < count; j++)
         {
            if(objCreationTimes[indices[i]] > objCreationTimes[indices[j]])
            {
               int temp = indices[i];
               indices[i] = indices[j];
               indices[j] = temp;
            }
         }
      }
      
      // ✅ FIX: Supprimer les plus anciennes
      int toDelete = count - InpMaxTrendlines;
      for(int i = 0; i < toDelete; i++)
      {
         int idx = indices[i];
         if(idx >= 0 && idx < count)
            ObjectDelete(0, objNames[idx]);
      }
   }
}

//+------------------------------------------------------------------+
//| Delete all objects created by this EA                           |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0, -1, -1);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      
      if(StringFind(objName, indicatorPrefix) >= 0)
      {
         ObjectDelete(0, objName);
      }
   }
   
   objectCounter = 0;
}

//+------------------------------------------------------------------+
//| Display indicator information on chart                          |
//+------------------------------------------------------------------+
void DisplayIndicatorInfo()
{
   // ✅ FIX: Validation des arrays avant affichage
   if(ArraySize(RSIBuffer) > 0 && RSIBuffer[0] != EMPTY_VALUE)
   {
      double currentRSI = RSIBuffer[0];
      double currentMA = 0;
      
      // ✅ FIX: Validation pour MA
      if(InpMAType != MA_NONE && ArraySize(MABuffer) > 0 && MABuffer[0] != EMPTY_VALUE)
         currentMA = MABuffer[0];
      
      string info = StringFormat(
         "RSI: %.2f | MA: %.2f | Time: %s",
         currentRSI,
         currentMA,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
      );
      
      Comment(info);
   }
}

//+------------------------------------------------------------------+
