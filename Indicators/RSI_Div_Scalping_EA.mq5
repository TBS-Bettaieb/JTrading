//+------------------------------------------------------------------+
//|                                    RSI_Divergence_Indicator.mq5  |
//|                         RSI Divergence Indicator                   |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "2.10"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   5

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

//--- Input parameters
input group "═══ RSI Settings ═══"
input int                InpRSIPeriod        = 14;              // RSI Length
input ENUM_APPLIED_PRICE InpRSIAppliedPrice = PRICE_CLOSE;     // Source

input group "═══ RSI Levels ═══"
input bool   InpShowLevels      = true;      // Show Levels
input double InpUpperLevel      = 70.0;      // Upper Level
input double InpMiddleLevel     = 50.0;      // Middle Level
input double InpLowerLevel      = 30.0;      // Lower Level
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

//--- Constantes
const double DIVERGENCE_MARKER_OFFSET = 5.0;
const int MAX_TRENDLINES_TO_KEEP = 50;
const int MAX_BARS_TO_CHECK = 100;

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
   
   if(InpRangeLower < InpLookbackLeft + InpLookbackRight)
   {
      Print("❌ Erreur: Range Lower trop petit pour la détection de pivots");
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
   
   //--- Set arrow code for divergences
   PlotIndexSetInteger(4, PLOT_ARROW, 159);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
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
   //--- Check for minimum bars
   if(rates_total < InpRSIPeriod + InpRangeUpper + 10)
      return(0);
   
   //--- Set arrays as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   // Utiliser directement les paramètres passés à OnCalculate
   
   //--- Calculate RSI FIRST (calcul complet sur tous les historiques)
   CalculateRSI(rates_total, prev_calculated, close);
   
   //--- Check divergences ONLY on new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime[1];
   
   if(CopyTime(_Symbol, _Period, 0, 1, currentBarTime) <= 0)
      return(prev_calculated);
   
   // Détecter les divergences uniquement sur nouvelle barre
   if(currentBarTime[0] != lastBarTime)
   {
      lastBarTime = currentBarTime[0];
      
      // Supprimer les anciennes trendlines AVANT de détecter les nouvelles
      DeleteOldTrendlines();
      
      // Vérifier les divergences sur les 100 dernières barres seulement pour optimiser la performance
      if(rates_total > InpRangeLower + InpLookbackLeft + InpLookbackRight + 20)
      {
         int limit = MathMin(MAX_BARS_TO_CHECK, rates_total - InpRangeUpper - InpLookbackLeft - 1);
         for(int i = InpLookbackRight + 1; i <= limit; i++)
         {
            CheckBullishDivergence(i, time, low);
            CheckBearishDivergence(i, time, high);
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
   if(rates_total < InpRSIPeriod + 2)
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
      firstRun = false;
   }
   
   int start;
   
   // Première exécution: calculer tout
   if(prev_calculated == 0)
   {
      start = rates_total - InpRSIPeriod - 1;
      
      // Vérification des limites pour éviter array out of range
      if(start < 0 || start + InpRSIPeriod >= rates_total)
         return;
      
      // Étape 1: Initialisation avec SMA (correction des indices)
      double sumUp = 0, sumDown = 0;
      for(int j = 0; j < InpRSIPeriod; j++)
      {
         int idx = start + 1 + j;
         if(idx >= rates_total) break;
         double change = close[idx - 1] - close[idx];
         if(change > 0)
            sumUp += change;
         else
            sumDown += -change;
      }
      
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
   else
   {
      // Seulement recalculer les nouvelles barres
      start = rates_total - prev_calculated - 1;
      if(start < 0) start = 0;
   }
   
   // Étape 2: Application de la formule RMA
   for(int i = start - 1; i >= 0; i--)
   {
      // Vérifier que i+1 est accessible
      if(i + 1 >= rates_total)
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
   
   // Calcul du lissage MA si activé
   if(InpMAType != MA_NONE && rates_total > InpRSIPeriod + InpMAPeriod)
   {
      for(int i = 0; i < rates_total - InpRSIPeriod - InpMAPeriod; i++)
      {
         MABuffer[i] = CalculateMA(i, InpMAPeriod, InpMAType);
         
         // Bollinger Bands si activé
         if(InpMAType == MA_SMA_BB)
         {
            double sum = 0;
            for(int j = 0; j < InpMAPeriod; j++)
            {
               double diff = RSIBuffer[i + j] - MABuffer[i];
               sum += diff * diff;
            }
            StdDevBuffer[i] = MathSqrt(sum / InpMAPeriod);
            BBUpperBuffer[i] = MABuffer[i] + InpBBStdDev * StdDevBuffer[i];
            BBLowerBuffer[i] = MABuffer[i] - InpBBStdDev * StdDevBuffer[i];
         }
      }
   }
   
}

//+------------------------------------------------------------------+
//| Calculate Moving Average                                          |
//+------------------------------------------------------------------+
double CalculateMA(int pos, int period, MA_TYPE_CUSTOM ma_type)
{
   double sum = 0;
   
   switch(ma_type)
   {
      case MA_SMA:
      case MA_SMA_BB:
         for(int i = 0; i < period; i++)
            sum += RSIBuffer[pos + i];
         return sum / period;
         
      case MA_EMA:
         if(pos >= ArraySize(MABuffer) - period - 1)
         {
            for(int i = 0; i < period; i++)
               sum += RSIBuffer[pos + i];
            return sum / period;
         }
         else
         {
            double alpha = 2.0 / (period + 1.0);
            return alpha * RSIBuffer[pos] + (1 - alpha) * MABuffer[pos + 1];
         }
         
      case MA_SMMA:
         if(pos >= ArraySize(MABuffer) - period - 1)
         {
            for(int i = 0; i < period; i++)
               sum += RSIBuffer[pos + i];
            return sum / period;
         }
         else
         {
            return (MABuffer[pos + 1] * (period - 1) + RSIBuffer[pos]) / period;
         }
         
      case MA_LWMA:
      {
         double weightSum = 0;
         for(int i = 0; i < period; i++)
         {
            int weight = period - i;
            sum += RSIBuffer[pos + i] * weight;
            weightSum += weight;
         }
         return sum / weightSum;
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Check for bullish divergence                                     |
//+------------------------------------------------------------------+
void CheckBullishDivergence(int currentBar, const datetime &time[], const double &low[])
{
   // A. Position de vérification (currentBar contient déjà la bonne position)
   int checkPos = currentBar;
   
   // Vérifications de limites
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // B. Vérification stricte du pivot BAS actuel
   double pivotRSI = RSIBuffer[checkPos];
   bool isPivotLow = true;
   
   // Vérifier TOUTES les barres à gauche (passé)
   for(int i = 1; i <= InpLookbackLeft; i++)
   {
      if(checkPos + i >= ArraySize(RSIBuffer))
         return;
      if(RSIBuffer[checkPos + i] <= pivotRSI)  // Strictement supérieures
      {
         isPivotLow = false;
         break;
      }
   }
   
   // Vérifier TOUTES les barres à droite (futur)
   for(int i = 1; i <= InpLookbackRight; i++)
   {
      if(checkPos - i < 0)
         return;
      if(RSIBuffer[checkPos - i] <= pivotRSI)  // Strictement supérieures
      {
         isPivotLow = false;
         break;
      }
   }
   
   if(!isPivotLow) return;
   
   // C. Recherche du pivot précédent avec validation complète
   int prevPivotBar = -1;
   double prevPivotRSI = 0;
   double prevPivotPrice = 0;
   int barsSincePivot = 0;
   
   for(int i = checkPos + InpRangeLower; i <= checkPos + InpRangeUpper && i < ArraySize(RSIBuffer); i++)
   {
      // Vérifier que le candidat est aussi un pivot bas valide
      bool isPrevPivot = true;
      double candidateRSI = RSIBuffer[i];
      
      // Vérifier les barres à gauche du pivot potentiel
      for(int j = 1; j <= InpLookbackLeft; j++)
      {
         if(i + j >= ArraySize(RSIBuffer))
            break;
         if(RSIBuffer[i + j] <= candidateRSI)
         {
            isPrevPivot = false;
            break;
         }
      }
      
      // Vérifier les barres à droite du pivot potentiel
      if(isPrevPivot)
      {
         for(int j = 1; j <= InpLookbackRight; j++)
         {
            if(i - j < 0)
               break;
            if(RSIBuffer[i - j] <= candidateRSI)
            {
               isPrevPivot = false;
               break;
            }
         }
      }
      
      if(isPrevPivot)
      {
         prevPivotBar = i;
         prevPivotRSI = candidateRSI;
         prevPivotPrice = low[i];
         barsSincePivot = checkPos - i;
         break;
      }
   }
   
   if(prevPivotBar < 0) return;
   
   // Valider que barsSincePivot est dans la plage
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
   // A. Position de vérification (currentBar contient déjà la bonne position)
   int checkPos = currentBar;
   
   // Vérifications de limites
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // B. Vérification stricte du pivot HAUT actuel
   double pivotRSI = RSIBuffer[checkPos];
   bool isPivotHigh = true;
   
   // Vérifier TOUTES les barres à gauche (passé)
   for(int i = 1; i <= InpLookbackLeft; i++)
   {
      if(checkPos + i >= ArraySize(RSIBuffer))
         return;
      if(RSIBuffer[checkPos + i] >= pivotRSI)  // Strictement inférieures
      {
         isPivotHigh = false;
         break;
      }
   }
   
   // Vérifier TOUTES les barres à droite (futur)
   for(int i = 1; i <= InpLookbackRight; i++)
   {
      if(checkPos - i < 0)
         return;
      if(RSIBuffer[checkPos - i] >= pivotRSI)  // Strictement inférieures
      {
         isPivotHigh = false;
         break;
      }
   }
   
   if(!isPivotHigh) return;
   
   // C. Recherche du pivot précédent avec validation complète
   int prevPivotBar = -1;
   double prevPivotRSI = 0;
   double prevPivotPrice = 0;
   int barsSincePivot = 0;
   
   for(int i = checkPos + InpRangeLower; i <= checkPos + InpRangeUpper && i < ArraySize(RSIBuffer); i++)
   {
      // Vérifier que le candidat est aussi un pivot haut valide
      bool isPrevPivot = true;
      double candidateRSI = RSIBuffer[i];
      
      // Vérifier les barres à gauche du pivot potentiel
      for(int j = 1; j <= InpLookbackLeft; j++)
      {
         if(i + j >= ArraySize(RSIBuffer))
            break;
         if(RSIBuffer[i + j] >= candidateRSI)
         {
            isPrevPivot = false;
            break;
         }
      }
      
      // Vérifier les barres à droite du pivot potentiel
      if(isPrevPivot)
      {
         for(int j = 1; j <= InpLookbackRight; j++)
         {
            if(i - j < 0)
               break;
            if(RSIBuffer[i - j] >= candidateRSI)
            {
               isPrevPivot = false;
               break;
            }
         }
      }
      
      if(isPrevPivot)
      {
         prevPivotBar = i;
         prevPivotRSI = candidateRSI;
         prevPivotPrice = high[i];
         barsSincePivot = checkPos - i;
         break;
      }
   }
   
   if(prevPivotBar < 0) return;
   
   // Valider que barsSincePivot est dans la plage
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
//| Delete old trendlines intelligently                             |
//+------------------------------------------------------------------+
void DeleteOldTrendlines()
{
   // Compter les trendlines existantes
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

   // Si dépassement, supprimer les plus anciennes
   if(count > MAX_TRENDLINES_TO_KEEP)
   {
      // Trier par temps (plus ancien en premier)
      for(int i = 0; i < count - 1; i++)
      {
         for(int j = i + 1; j < count; j++)
         {
            if(objCreationTimes[i] > objCreationTimes[j])
            {
               // Swap
               datetime tempTime = objCreationTimes[i];
               objCreationTimes[i] = objCreationTimes[j];
               objCreationTimes[j] = tempTime;
               
               string tempName = objNames[i];
               objNames[i] = objNames[j];
               objNames[j] = tempName;
            }
         }
      }
      
      // Supprimer les plus anciennes
      for(int i = 0; i < count - MAX_TRENDLINES_TO_KEEP; i++)
      {
         ObjectDelete(0, objNames[i]);
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
   if(ArraySize(RSIBuffer) > 0)
   {
      double currentRSI = RSIBuffer[0];
      double currentMA = (InpMAType != MA_NONE && ArraySize(MABuffer) > 0) ? MABuffer[0] : 0;
      
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