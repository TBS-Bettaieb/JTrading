//+------------------------------------------------------------------+
//|                              RSI_Divergence_Indicator_Modular.mq5 |
//|                         RSI Divergence Indicator (Modular)        |
//+------------------------------------------------------------------+
//| Version: 2.0 - Architecture modulaire avec classes MQH            |
//| Changelog:                                                       |
//| ✅ [ARCHITECTURE] Utilisation des classes MQH modulaires          |
//| ✅ [PERFORMANCE] Calcul RSI optimisé avec CRSICalculator          |
//| ✅ [PERFORMANCE] Détection pivots avec CPivotDetector             |
//| ✅ [PERFORMANCE] Détection divergences avec CDivergenceDetector   |
//| ✅ [FEATURE] Affichage graphique avec CDivergenceVisualizer       |
//| ✅ [FEATURE] Support Regular et Hidden Divergences                |
//| ✅ [FEATURE] Buffer de signaux pour communication avec EA         |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "2.00"
#property indicator_separate_window
#property indicator_buffers 11  // 11 buffers total
#property indicator_plots   8   // 8 plots visibles

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

// Hidden Divergence markers - Bullish
#property indicator_label6  "Hidden Bull Div"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrDodgerBlue
#property indicator_width6  2

// Hidden Divergence markers - Bearish
#property indicator_label7  "Hidden Bear Div"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrOrange
#property indicator_width7  2

// Signal buffer (invisible mais accessible par EA)
#property indicator_label8  "Divergence Signal"
#property indicator_type8   DRAW_NONE

//--- Input parameters
input group "═══ RSI Settings ═══"
input int                InpRSIPeriod        = 3;               // RSI Length
input ENUM_APPLIED_PRICE InpRSIAppliedPrice = PRICE_CLOSE;     // Source

input group "═══ RSI Levels ═══"
input double InpUpperLevel      = 90.0;      // Upper Level
input double InpLowerLevel      = 10.0;      // Lower Level

input group "═══ Divergence Settings ═══"
input int    InpLookbackLeft  = 3;      // Lookback Left
input int    InpLookbackRight = 1;      // Lookback Right
input int    InpRangeLower    = 3;      // Range Lower
input int    InpRangeUpper    = 100;    // Range Upper

input group "═══ Display Settings ═══"
input bool   InpShowTrendlines = true;      // Show Trendlines
input bool   InpShowLabels = true;          // Show Labels
input color  InpDashboardColor = clrWhite;  // Dashboard Color

//--- Constantes
const bool   SHOW_LEVELS = true;
const double MIDDLE_LEVEL = 50.0;
const color  LEVEL_COLOR = clrSilver;
const int    MAX_TRENDLINES = 50;
const int    MAX_BARS_CHECK = 100;

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

// Buffers pour hidden divergences
double HiddenBullDivBuffer[];
double HiddenBearDivBuffer[];

// Buffer de signaux pour l'EA
double DivergenceSignalBuffer[];  // Buffer 7: Codes: 0=Aucun, 1=RegBull, 2=RegBear, 3=HidBull, 4=HidBear

//--- Constantes
const double DIVERGENCE_MARKER_OFFSET = 5.0;

//--- Global variables
string indicatorPrefix = "RSI_DIV_Modular_";
int objectCounter = 0;

//--- Instances des classes modulaires
#include <Shared\RSI_Calculator.mqh>
#include <Shared\Pivot_Detector.mqh>
#include <Shared\Divergence_Detector.mqh>
#include <Shared\Divergence_Visualizer.mqh>

CRSICalculator* rsiCalculator = NULL;
CPivotDetector* pivotDetector = NULL;
CDivergenceDetector* divergenceDetector = NULL;
CDivergenceVisualizer* visualizer = NULL;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🔍 DEBUG - Paramètres reçus:");
   Print("   InpRSIPeriod = ", InpRSIPeriod);
   Print("   InpRSIAppliedPrice = ", InpRSIAppliedPrice);
   Print("   InpUpperLevel = ", InpUpperLevel);
   Print("   InpLowerLevel = ", InpLowerLevel);
   Print("   InpLookbackLeft = ", InpLookbackLeft);
   Print("   InpLookbackRight = ", InpLookbackRight);
   Print("   InpRangeLower = ", InpRangeLower);
   Print("   InpRangeUpper = ", InpRangeUpper);

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
   
   if(InpRangeLower < 1)
   {
      Print("❌ Erreur: Range Lower doit être >= 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Indicator buffers mapping
   // Buffers 0-4 : Affichage graphique
   SetIndexBuffer(0, RSIBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, MABuffer, INDICATOR_DATA);
   SetIndexBuffer(2, BBUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BBLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, DivergenceBuffer, INDICATOR_DATA);

   // Buffers 5-6 : Hidden divergences (affichage)
   SetIndexBuffer(5, HiddenBullDivBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, HiddenBearDivBuffer, INDICATOR_DATA);

   // Buffer 7 : Signal pour EA (ACCESSIBLE - DOIT être INDICATOR_DATA)
   SetIndexBuffer(7, DivergenceSignalBuffer, INDICATOR_DATA);
   
   // Buffers 8-10 : Calculs internes (déplacés pour libérer buffer 7)
   SetIndexBuffer(8, UpBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, DownBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, StdDevBuffer, INDICATOR_CALCULATIONS);

   // Configuration du plot 8 (index 7) pour le signal invisible
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE);  // Plot invisible
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, 0.0);       // Valeur vide = 0
   PlotIndexSetString(7, PLOT_LABEL, "Signal");        // Label pour debug

   // Initialiser APRÈS la configuration
   ArrayInitialize(DivergenceSignalBuffer, 0.0);

   Print("✅ Buffer 7 (DivergenceSignalBuffer) configuré - Type: INDICATOR_DATA");
   
   //--- Set arrow code for divergences
   PlotIndexSetInteger(4, PLOT_ARROW, 159);
   
   // Configuration des arrows pour hidden divergences
   PlotIndexSetInteger(5, PLOT_ARROW, 159);  // Hidden Bullish
   PlotIndexSetInteger(6, PLOT_ARROW, 159);  // Hidden Bearish
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // Empty values pour hidden divergences
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "RSI_Div_Modular(" + string(InpRSIPeriod) + ")");
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   //--- Create RSI levels (toujours affichés)
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpUpperLevel);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, MIDDLE_LEVEL);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLowerLevel);
   
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, LEVEL_COLOR);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, LEVEL_COLOR);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, LEVEL_COLOR);
   
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 2, STYLE_DOT);
   
   // Initialiser les classes modulaires
   Print("🔧 Initialisation des classes modulaires...");
   
   // 1. Calculateur RSI
   rsiCalculator = new CRSICalculator(InpRSIPeriod, InpRSIAppliedPrice);
   if(rsiCalculator == NULL)
   {
      Print("❌ Erreur: Impossible de créer CRSICalculator");
      return INIT_FAILED;
   }
   Print("✅ CRSICalculator initialisé - Période: ", InpRSIPeriod);
   
   // 2. Détecteur de pivots
   pivotDetector = new CPivotDetector(InpLookbackLeft, InpLookbackRight);
   if(pivotDetector == NULL)
   {
      Print("❌ Erreur: Impossible de créer CPivotDetector");
      return INIT_FAILED;
   }
   Print("✅ CPivotDetector initialisé - Lookback: ", InpLookbackLeft, "/", InpLookbackRight);
   
   // 3. Détecteur de divergences
   divergenceDetector = new CDivergenceDetector(InpRangeLower, InpRangeUpper, pivotDetector);
   if(divergenceDetector == NULL)
   {
      Print("❌ Erreur: Impossible de créer CDivergenceDetector");
      return INIT_FAILED;
   }
   Print("✅ CDivergenceDetector initialisé - Range: ", InpRangeLower, "-", InpRangeUpper);
   
   // 4. Visualiseur de divergences
   int subwindow = ChartWindowFind(0, "RSI_Div_Modular(" + IntegerToString(InpRSIPeriod) + ")");
   if(subwindow < 0)
      subwindow = 0; // Utiliser la fenêtre principale par défaut
   
   visualizer = new CDivergenceVisualizer(indicatorPrefix, subwindow, MAX_TRENDLINES);
   if(visualizer == NULL)
   {
      Print("❌ Erreur: Impossible de créer CDivergenceVisualizer");
      return INIT_FAILED;
   }
   Print("✅ CDivergenceVisualizer initialisé - Préfixe: ", indicatorPrefix);
   
   //--- Delete old objects
   DeleteAllObjects();
   
   Print("✅ RSI Divergence Indicator Modular Initialized!");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Architecture: Modulaire avec classes MQH");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libérer les instances des classes
   if(rsiCalculator != NULL)
   {
      delete rsiCalculator;
      rsiCalculator = NULL;
   }
   
   if(pivotDetector != NULL)
   {
      delete pivotDetector;
      pivotDetector = NULL;
   }
   
   if(divergenceDetector != NULL)
   {
      delete divergenceDetector;
      divergenceDetector = NULL;
   }
   
   if(visualizer != NULL)
   {
      delete visualizer;
      visualizer = NULL;
   }
   
   DeleteAllObjects();
   Print("RSI Divergence Indicator Modular stopped. Reason: ", reason);
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
   // Validation des limites des arrays
   if(rates_total < InpRSIPeriod + InpRangeUpper + 10)
      return(0);
   
   // Cohérence indexation - tous les arrays en série inversée
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
   
   // Arrays pour hidden divergences
   ArraySetAsSeries(HiddenBullDivBuffer, true);
   ArraySetAsSeries(HiddenBearDivBuffer, true);
   
   // Array pour signal de divergence encodé
   ArraySetAsSeries(DivergenceSignalBuffer, true);
   
   // Calculer RSI avec la classe modulaire
   if(!rsiCalculator.Calculate(rates_total, prev_calculated, close))
   {
      Print("❌ Erreur: Échec du calcul RSI");
      return(0);
   }
   
   // Obtenir le buffer RSI calculé
   if(!rsiCalculator.GetBuffer(RSIBuffer, 0, rates_total))
   {
      Print("❌ Erreur: Impossible d'obtenir le buffer RSI");
      return(0);
   }
   
   // Détection nouvelle barre robuste avec prev_calculated
   bool isNewBar = (prev_calculated == 0 || rates_total > prev_calculated);
   
   if(isNewBar)
   {
      // Supprimer les anciennes trendlines AVANT de détecter les nouvelles
      if(visualizer != NULL)
         visualizer.CleanOldObjects();
      
      // Vérifier qu'on a assez de données
      if(rates_total > InpRangeLower + InpLookbackLeft + InpLookbackRight + 20)
      {
         int startPos, endPos;
         
         // Différencier premier chargement et nouvelles barres
         if(prev_calculated == 0)
         {
            // PREMIER CHARGEMENT : Analyser toutes les barres historiques
            startPos = InpLookbackRight + 1;
            endPos = MathMin(MAX_BARS_CHECK, rates_total - InpRangeUpper - InpLookbackLeft - 1);
            
            Print("🔍 PREMIER CHARGEMENT - Analyse de ", startPos, " à ", endPos, " (", endPos - startPos + 1, " barres)");
         }
         else
         {
            // NOUVELLES BARRES : Analyser seulement les positions récemment confirmées
            int newBars = rates_total - prev_calculated;
            startPos = InpLookbackRight + 1;
            endPos = InpLookbackRight + newBars + InpLookbackLeft + 5;
            endPos = MathMin(endPos, startPos + 30);  // Maximum 30 barres à vérifier
         }
         
         // Scanner les divergences avec la classe modulaire
         SDivergenceResult results[];
         int found = divergenceDetector.ScanDivergences(startPos, endPos, RSIBuffer, high, low, time, results);
         
         if(found > 0)
         {
            Print("🎯 ", found, " divergence(s) trouvée(s) avec classes modulaires");
            
            // Traiter chaque divergence trouvée
            for(int i = 0; i < found; i++)
            {
               if(!results[i].found || !results[i].isValid)
                  continue;
               
               // Marquer la divergence dans les buffers appropriés
               switch(results[i].type)
               {
                  case DIVERGENCE_REGULAR_BULL:
                     DivergenceBuffer[results[i].currentBar] = results[i].currentRSI - DIVERGENCE_MARKER_OFFSET;
                     DivergenceSignalBuffer[results[i].currentBar] = 1.0; // Regular Bullish
                     break;
                     
                  case DIVERGENCE_REGULAR_BEAR:
                     DivergenceBuffer[results[i].currentBar] = results[i].currentRSI + DIVERGENCE_MARKER_OFFSET;
                     DivergenceSignalBuffer[results[i].currentBar] = 2.0; // Regular Bearish
                     break;
                     
                  case DIVERGENCE_HIDDEN_BULL:
                     HiddenBullDivBuffer[results[i].currentBar] = results[i].currentRSI - DIVERGENCE_MARKER_OFFSET;
                     DivergenceSignalBuffer[results[i].currentBar] = 3.0; // Hidden Bullish
                     break;
                     
                  case DIVERGENCE_HIDDEN_BEAR:
                     HiddenBearDivBuffer[results[i].currentBar] = results[i].currentRSI + DIVERGENCE_MARKER_OFFSET;
                     DivergenceSignalBuffer[results[i].currentBar] = 4.0; // Hidden Bearish
                     break;
               }
               
               // Dessiner la divergence si le visualiseur est disponible
               if(visualizer != NULL && InpShowTrendlines)
               {
                  visualizer.DrawDivergence(results[i], time);
               }
               
               Print("✅ Divergence traitée: Type=", EnumToString(results[i].type), 
                     " Bar=", results[i].currentBar, " RSI=", DoubleToString(results[i].currentRSI, 2));
            }
         }
      }
   }
   
   // Display information on chart
   DisplayIndicatorInfo();
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Delete all objects created by this indicator                    |
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
   // Validation des arrays avant affichage
   if(ArraySize(RSIBuffer) > 0 && RSIBuffer[0] != EMPTY_VALUE)
   {
      double currentRSI = RSIBuffer[0];
      double currentMA = 0;  // MA désactivé
      
      string info = StringFormat(
         "RSI Modular: %.2f | MA: %.2f | Time: %s",
         currentRSI,
         currentMA,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
      );
      
      Comment(info);
   }
}

//+------------------------------------------------------------------+
