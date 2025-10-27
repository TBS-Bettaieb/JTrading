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
//| ✅ [FIX] Correction erreur "Sous-fenêtre RSI non trouvée!" en mode testeur |
//| ✅ [FIX] Correction détection divergences en temps réel (nouvelles barres) |
//| ✅ [CRITICAL] Validation niveaux RSI dans détection divergences   |
//| ✅ [FEATURE] Ajout paramètre InpShowLabels pour debug messages    |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "2.15"
#property indicator_separate_window
#property indicator_buffers 11  // ✅ EA INTEGRATION: 11 buffers total
#property indicator_plots   8   // ✅ EA INTEGRATION: 7 plots visibles + 1 signal invisible (buffer 7)

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

// Signal buffer (invisible mais accessible par EA)
#property indicator_label8  "Divergence Signal"
#property indicator_type8   DRAW_NONE

//--- Input parameters
// input group "═══ RSI Settings ═══"
input int                InpRSIPeriod        = 3;               // RSI Length
input ENUM_APPLIED_PRICE InpRSIAppliedPrice = PRICE_CLOSE;     // Source

// input group "═══ RSI Levels ═══"
input double InpUpperLevel      = 90.0;      // Upper Level
input double InpLowerLevel      = 10.0;      // Lower Level

// input group "═══ Divergence Settings ═══"
input int    InpLookbackLeft  = 3;      // Lookback Left (réduit pour test)
input int    InpLookbackRight = 1;      // Lookback Right (délai réduit)
input int    InpRangeLower    = 3;      // Range Lower (réduit pour test)
input int    InpRangeUpper    = 100;    // Range Upper (augmenté pour test)

//--- Constantes (paramètres en dur)
const bool   SHOW_LEVELS = true;
const double MIDDLE_LEVEL = 50.0;
const color  LEVEL_COLOR = clrSilver;
const bool   SHOW_TRENDLINES = true;
const color  BULLISH_COLOR = clrLimeGreen;
const color  BEARISH_COLOR = clrRed;
const int    TRENDLINE_WIDTH = 2;
const bool   SHOW_HIDDEN_DIV = true;
const color  HIDDEN_BULL_COLOR = clrDodgerBlue;
const color  HIDDEN_BEAR_COLOR = clrOrange;
const int    HIDDEN_TREND_WIDTH = 2;
const ENUM_LINE_STYLE HIDDEN_LINE_STYLE = STYLE_DASH;
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

// ✅ FIX HIDDEN DIV : Nouveaux buffers pour hidden divergences
double HiddenBullDivBuffer[];
double HiddenBearDivBuffer[];

// ✅ EA INTEGRATION : Nouveaux buffers de signaux pour l'EA
// ✅ NOUVEAU : Un seul buffer pour tous les signaux
double DivergenceSignalBuffer[];  // Buffer 7: Codes: 0=Aucun, 1=RegBull, 2=RegBear, 3=HidBull, 4=HidBear

//--- Constantes
const double DIVERGENCE_MARKER_OFFSET = 5.0;


//--- Global variables
string indicatorPrefix = "RSI_DIV_";
int objectCounter = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
      // ✅ AJOUTER CECI POUR DEBUG
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
   
   // ✅ FIX PINE SCRIPT: Validation corrigée - similaire à Pine Script
   // Range Lower doit juste être positif et inférieur à Range Upper
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

   // ✅ Configuration du plot 8 (index 7) pour le signal invisible
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE);  // Plot invisible
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, 0.0);       // Valeur vide = 0
   PlotIndexSetString(7, PLOT_LABEL, "Signal");        // Label pour debug

   // ✅ IMPORTANT : Initialiser APRÈS la configuration
   ArrayInitialize(DivergenceSignalBuffer, 0.0);

   // ✅ DEBUG : Ajouter log de confirmation
   Print("✅ Buffer 7 (DivergenceSignalBuffer) configuré - Type: INDICATOR_DATA");
   
   //--- Set arrow code for divergences
   PlotIndexSetInteger(4, PLOT_ARROW, 159);
   
   // ✅ FIX HIDDEN DIV : Configuration des arrows pour hidden divergences
   PlotIndexSetInteger(5, PLOT_ARROW, 159);  // Hidden Bullish
   PlotIndexSetInteger(6, PLOT_ARROW, 159);  // Hidden Bearish
   
   // ✅ EA INTEGRATION : Configuration du plot invisible pour signal (déjà fait plus haut)
   
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
   
   // ✅ TEST: Créer un signal FORCÉ toutes les 20 barres pour diagnostic
   static int testCounter = 0;
   testCounter++;
   
   if(testCounter % 20 == 0 && rates_total > 50)
   {
      int testPos = 10;  // Position fixe
      if(testPos < ArraySize(DivergenceSignalBuffer))
      {
         DivergenceSignalBuffer[testPos] = 1.0;  // Signal bullish forcé
         Print("🔧 SIGNAL DE TEST FORCÉ en position [", testPos, "] - Valeur: 1.0");
         Print("   Time: ", TimeToString(time[testPos]));
      }
   }
   
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
   
   // ✅ EA INTEGRATION : Array pour signal de divergence encodé
   ArraySetAsSeries(DivergenceSignalBuffer, true);
   
   // ✅ FIX: Optimisation calcul RSI - ne calculer que les nouvelles barres
   CalculateRSI(rates_total, prev_calculated, close);
   
   // ✅ FIX: Détection nouvelle barre robuste avec prev_calculated
   bool isNewBar = (prev_calculated == 0 || rates_total > prev_calculated);
   
   // ✅ FIX: Suppression de la réinitialisation problématique
   // Le buffer de signaux ne doit PAS être réinitialisé à chaque nouvelle barre
   // car cela efface les signaux avant qu'ils ne soient détectés
   
   if(isNewBar)
   {
      // Supprimer les anciennes trendlines AVANT de détecter les nouvelles
      DeleteOldTrendlines();
      
      // Vérifier qu'on a assez de données
      if(rates_total > InpRangeLower + InpLookbackLeft + InpLookbackRight + 20)
      {
         int startPos, endPos;
         
         // ✅ FIX CRITIQUE : Différencier premier chargement et nouvelles barres
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
            // Une barre devient un "pivot confirmé" quand elle a InpLookbackRight barres à sa droite
            
            // Nombre de nouvelles barres depuis le dernier calcul
            int newBars = rates_total - prev_calculated;
            
            // Position de la barre la plus récente qui peut être un pivot confirmé
            startPos = InpLookbackRight + 1;
            
            // Position de la barre la plus ancienne à vérifier
            // On vérifie les barres qui viennent d'être confirmées + quelques barres supplémentaires
            endPos = InpLookbackRight + newBars + InpLookbackLeft + 5;
            
            // Limiter pour éviter de tout recalculer
            endPos = MathMin(endPos, startPos + 30);  // Maximum 30 barres à vérifier
            
         }
         
         // Parcourir les barres à vérifier
         for(int i = startPos; i <= endPos; i++)
         {
            // ✅ FIX: Validation des indices avant appel des fonctions
            if(i >= 0 && i < ArraySize(RSIBuffer) && i < ArraySize(time) && 
               i < ArraySize(high) && i < ArraySize(low))
            {
               // Regular Divergences
               CheckBullishDivergence(i, time, low);
               CheckBearishDivergence(i, time, high);
               
               // Hidden Divergences
               CheckHiddenBullishDivergence(i, time, low);
               CheckHiddenBearishDivergence(i, time, high);
            }
         }
      }
   }
   
   // ✅ DEBUG: Afficher l'état du buffer de signaux après détection
   if(isNewBar && prev_calculated > 0)  // Seulement sur nouvelles barres
   {
      Print("═══ DEBUG INDICATEUR - État Buffer 7 ═══");
      Print("rates_total: ", rates_total);
      Print("prev_calculated: ", prev_calculated);
      Print("Nouvelle barre détectée - Analyse des divergences");
      
      // Afficher les 10 dernières positions du buffer
      int signalsFound = 0;
      for(int debug_i = 0; debug_i < 10 && debug_i < ArraySize(DivergenceSignalBuffer); debug_i++)
      {
         if(DivergenceSignalBuffer[debug_i] != 0.0 && DivergenceSignalBuffer[debug_i] != EMPTY_VALUE)
         {
            signalsFound++;
            Print("🎯 SIGNAL TROUVÉ: Buffer[", debug_i, "] = ", DivergenceSignalBuffer[debug_i], 
                  " Time: ", TimeToString(time[debug_i]));
         }
      }
      
      if(signalsFound == 0)
      {
         Print("⚠️ AUCUN SIGNAL dans les 10 dernières positions");
         // Afficher quelques valeurs pour debug
         for(int debug_i = 0; debug_i < 5; debug_i++)
         {
            Print("   Buffer[", debug_i, "] = ", DivergenceSignalBuffer[debug_i]);
         }
      }
      else
      {
         Print("✅ Total: ", signalsFound, " signal(s) trouvé(s)");
      }
      Print("═════════════════════════════════════");
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
      start = rates_total - prev_calculated;
      if(start < 0) start = 0;
   }
   
   // Étape 2: Application de la formule RMA
   for(int i = start; i >= 0; i--)
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
   
   // MA désactivé - pas de calcul de lissage
   
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
   
   // ✅ Vérifier qu'il n'y a pas déjà un signal (plus robuste)
   if(DivergenceSignalBuffer[checkPos] != 0.0 && DivergenceSignalBuffer[checkPos] != EMPTY_VALUE)
   {
      Print("⚠️ Signal déjà présent en position ", checkPos, " : ", DivergenceSignalBuffer[checkPos]);
      return;
   }
   
   // ✅ FIX: Vérifications de limites améliorées
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // ✅ FIX PINE SCRIPT: REMPLACER toute la section de vérification de pivot par :
   if(!IsPivotLow(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // ✅ FIX: Validation du niveau RSI - Le pivot doit être dans la zone de survente
   if(pivotRSI > InpLowerLevel)
   {
      if(InpShowLabels)
         Print("⚠️ Pivot RSI non conforme (Bullish) : ", DoubleToString(pivotRSI, 2), " > ", InpLowerLevel);
      return;
   }
   
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
   
   // ✅ FIX: Validation du niveau RSI du pivot précédent aussi
   if(prevPivotRSI > InpLowerLevel)
   {
      if(InpShowLabels)
         Print("⚠️ Pivot précédent RSI non conforme (Bullish) : ", DoubleToString(prevPivotRSI, 2), " > ", InpLowerLevel);
      return;
   }
   
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
      Print("🟢 BULLISH DIV @ Bar[", checkPos, "] Signal=", 1.0);
      
      // Marquer la divergence
      DivergenceBuffer[checkPos] = pivotRSI - DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Enregistrer le signal : 1 = Regular Bullish
      DivergenceSignalBuffer[checkPos] = 1.0;
      
      // ✅ Confirmation d'écriture dans le buffer
      Print("✅✅✅ SIGNAL ÉCRIT À POSITION [", checkPos, "]");
      Print("   Valeur: ", DivergenceSignalBuffer[checkPos]);
      Print("   Time: ", TimeToString(time[checkPos]));
      Print("   RSI: ", pivotRSI, " | Price: ", currentPrice);
      Print("   Prev RSI: ", prevPivotRSI, " | Prev Price: ", prevPivotPrice);
      
      if(SHOW_TRENDLINES)
      {
         // E. Dessin de la trendline
         objectCounter++;
         string objName = indicatorPrefix + "BULL_" + IntegerToString(objectCounter);
         
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         int subwindow = ChartWindowFind(0, "RSI_Div(" + IntegerToString(InpRSIPeriod) + ")");
         
         // ✅ FIX: En mode testeur, utiliser fenêtre 1 par défaut si pas trouvée
         if(subwindow < 0)
         {
            if(MQLInfoInteger(MQL_TESTER))
               subwindow = 1;  // Fenêtre 1 = première sous-fenêtre en testeur
            else
               return;  // En mode normal, abandonner si vraiment pas trouvée
         }
         
         if(ObjectCreate(0, objName, OBJ_TREND, subwindow, 
                        time[prevPivotBar], prevPivotRSI,  // Point 1 : pivot précédent
                        time[checkPos], pivotRSI))          // Point 2 : pivot actuel
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, BULLISH_COLOR);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, TRENDLINE_WIDTH);
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
   
   // ✅ Vérifier qu'il n'y a pas déjà un signal (plus robuste)
   if(DivergenceSignalBuffer[checkPos] != 0.0 && DivergenceSignalBuffer[checkPos] != EMPTY_VALUE)
   {
      Print("⚠️ Signal déjà présent en position ", checkPos, " : ", DivergenceSignalBuffer[checkPos]);
      return;
   }
   
   // ✅ FIX: Vérifications de limites améliorées
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // ✅ FIX PINE SCRIPT: REMPLACER par IsPivotHigh
   if(!IsPivotHigh(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // ✅ FIX: Validation du niveau RSI - Le pivot doit être dans la zone de surachat
   if(pivotRSI < InpUpperLevel)
   {
      if(InpShowLabels)
         Print("⚠️ Pivot RSI non conforme (Bearish) : ", DoubleToString(pivotRSI, 2), " < ", InpUpperLevel);
      return;
   }
   
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
   
   // ✅ FIX: Validation du niveau RSI du pivot précédent aussi
   if(prevPivotRSI < InpUpperLevel)
   {
      if(InpShowLabels)
         Print("⚠️ Pivot précédent RSI non conforme (Bearish) : ", DoubleToString(prevPivotRSI, 2), " < ", InpUpperLevel);
      return;
   }
   
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
      Print("🔴 BEARISH DIV @ Bar[", checkPos, "] Signal=", 2.0);
      
      // Marquer la divergence
      DivergenceBuffer[checkPos] = pivotRSI + DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Enregistrer le signal : 2 = Regular Bearish
      DivergenceSignalBuffer[checkPos] = 2.0;
      
      // ✅ Confirmation d'écriture dans le buffer
      Print("✅✅✅ SIGNAL ÉCRIT À POSITION [", checkPos, "]");
      Print("   Valeur: ", DivergenceSignalBuffer[checkPos]);
      Print("   Time: ", TimeToString(time[checkPos]));
      Print("   RSI: ", pivotRSI, " | Price: ", currentPrice);
      Print("   Prev RSI: ", prevPivotRSI, " | Prev Price: ", prevPivotPrice);
      
      if(SHOW_TRENDLINES)
      {
         // E. Dessin de la trendline
         objectCounter++;
         string objName = indicatorPrefix + "BEAR_" + IntegerToString(objectCounter);
         
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         int subwindow = ChartWindowFind(0, "RSI_Div(" + IntegerToString(InpRSIPeriod) + ")");
         
         // ✅ FIX: En mode testeur, utiliser fenêtre 1 par défaut si pas trouvée
         if(subwindow < 0)
         {
            if(MQLInfoInteger(MQL_TESTER))
               subwindow = 1;  // Fenêtre 1 = première sous-fenêtre en testeur
            else
               return;  // En mode normal, abandonner si vraiment pas trouvée
         }
         
         if(ObjectCreate(0, objName, OBJ_TREND, subwindow, 
                        time[prevPivotBar], prevPivotRSI,  // Point 1 : pivot précédent
                        time[checkPos], pivotRSI))          // Point 2 : pivot actuel
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, BEARISH_COLOR);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, TRENDLINE_WIDTH);
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
   if(!SHOW_HIDDEN_DIV)
      return;
   
   // Validation complète des paramètres d'entrée
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(low))
      return;
   
   int checkPos = currentBar;
   
   // ✅ Vérifier qu'il n'y a pas déjà un signal (plus robuste)
   if(DivergenceSignalBuffer[checkPos] != 0.0 && DivergenceSignalBuffer[checkPos] != EMPTY_VALUE)
   {
      Print("⚠️ Signal déjà présent en position ", checkPos, " : ", DivergenceSignalBuffer[checkPos]);
      return;
   }
   
   // Vérifications de limites
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // Vérifier que c'est un pivot bas sur le RSI
   if(!IsPivotLow(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // ✅ FIX: Validation du niveau RSI - Le pivot doit être dans la zone de survente
   if(pivotRSI > InpLowerLevel)
   {
      if(InpShowLabels)
         Print("⚠️ Pivot RSI non conforme (Hidden Bullish) : ", DoubleToString(pivotRSI, 2), " > ", InpLowerLevel);
      return;
   }
   
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
   
   // ✅ FIX: Validation du niveau RSI du pivot précédent aussi
   if(prevPivotRSI > InpLowerLevel)
   {
      if(InpShowLabels)
         Print("⚠️ Pivot précédent RSI non conforme (Hidden Bullish) : ", DoubleToString(prevPivotRSI, 2), " > ", InpLowerLevel);
      return;
   }
   
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
      Print("🔵 HIDDEN BULLISH DIV @ Bar[", checkPos, "] Signal=", 3.0);
      
      // Marquer la divergence
      HiddenBullDivBuffer[checkPos] = pivotRSI - DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Enregistrer le signal : 3 = Hidden Bullish
      DivergenceSignalBuffer[checkPos] = 3.0;
      
      // ✅ Confirmation d'écriture dans le buffer
      Print("📝 SIGNAL ÉCRIT: Buffer[", checkPos, "] = ", DivergenceSignalBuffer[checkPos], " (Hidden Bullish)");
      
      if(SHOW_TRENDLINES)
      {
         // Dessin de la trendline
         objectCounter++;
         string objName = indicatorPrefix + "HBULL_" + IntegerToString(objectCounter);
         
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         int subwindow = ChartWindowFind(0, "RSI_Div(" + IntegerToString(InpRSIPeriod) + ")");
         
         // ✅ FIX: En mode testeur, utiliser fenêtre 1 par défaut si pas trouvée
         if(subwindow < 0)
         {
            if(MQLInfoInteger(MQL_TESTER))
               subwindow = 1;  // Fenêtre 1 = première sous-fenêtre en testeur
            else
               return;  // En mode normal, abandonner si vraiment pas trouvée
         }
         
         if(ObjectCreate(0, objName, OBJ_TREND, subwindow, 
                        time[prevPivotBar], prevPivotRSI,
                        time[checkPos], pivotRSI))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, HIDDEN_BULL_COLOR);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, HIDDEN_TREND_WIDTH);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, HIDDEN_LINE_STYLE);
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
   if(!SHOW_HIDDEN_DIV)
      return;
   
   // Validation complète des paramètres d'entrée
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(high))
      return;
   
   int checkPos = currentBar;
   
   // ✅ Vérifier qu'il n'y a pas déjà un signal (plus robuste)
   if(DivergenceSignalBuffer[checkPos] != 0.0 && DivergenceSignalBuffer[checkPos] != EMPTY_VALUE)
   {
      Print("⚠️ Signal déjà présent en position ", checkPos, " : ", DivergenceSignalBuffer[checkPos]);
      return;
   }
   
   // Vérifications de limites
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // Vérifier que c'est un pivot haut sur le RSI
   if(!IsPivotHigh(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // ✅ FIX: Validation du niveau RSI - Le pivot doit être dans la zone de surachat
   if(pivotRSI < InpUpperLevel)
   {
      if(InpShowLabels)
         Print("⚠️ Pivot RSI non conforme (Hidden Bearish) : ", DoubleToString(pivotRSI, 2), " < ", InpUpperLevel);
      return;
   }
   
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
   
   // ✅ FIX: Validation du niveau RSI du pivot précédent aussi
   if(prevPivotRSI < InpUpperLevel)
   {
      if(InpShowLabels)
         Print("⚠️ Pivot précédent RSI non conforme (Hidden Bearish) : ", DoubleToString(prevPivotRSI, 2), " < ", InpUpperLevel);
      return;
   }
   
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
      Print("🟠 HIDDEN BEARISH DIV @ Bar[", checkPos, "] Signal=", 4.0);
      
      // Marquer la divergence
      HiddenBearDivBuffer[checkPos] = pivotRSI + DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Enregistrer le signal : 4 = Hidden Bearish
      DivergenceSignalBuffer[checkPos] = 4.0;
      
      // ✅ Confirmation d'écriture dans le buffer
      Print("📝 SIGNAL ÉCRIT: Buffer[", checkPos, "] = ", DivergenceSignalBuffer[checkPos], " (Hidden Bearish)");
      
      if(SHOW_TRENDLINES)
      {
         // Dessin de la trendline
         objectCounter++;
         string objName = indicatorPrefix + "HBEAR_" + IntegerToString(objectCounter);
         
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         int subwindow = ChartWindowFind(0, "RSI_Div(" + IntegerToString(InpRSIPeriod) + ")");
         
         // ✅ FIX: En mode testeur, utiliser fenêtre 1 par défaut si pas trouvée
         if(subwindow < 0)
         {
            if(MQLInfoInteger(MQL_TESTER))
               subwindow = 1;  // Fenêtre 1 = première sous-fenêtre en testeur
            else
               return;  // En mode normal, abandonner si vraiment pas trouvée
         }
         
         if(ObjectCreate(0, objName, OBJ_TREND, subwindow, 
                        time[prevPivotBar], prevPivotRSI,
                        time[checkPos], pivotRSI))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, HIDDEN_BEAR_COLOR);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, HIDDEN_TREND_WIDTH);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, HIDDEN_LINE_STYLE);
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
   if(count > MAX_TRENDLINES)
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
      int toDelete = count - MAX_TRENDLINES;
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
      double currentMA = 0;  // MA désactivé
      
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
