//+------------------------------------------------------------------+
//|                              RSI_Divergence_Indicator_NoGUI.mq5  |
//|                         RSI Divergence Indicator (No GUI)         |
//+------------------------------------------------------------------+
//| Version optimisée sans GUI pour backtesting rapide               |
//| ✅ [PERFORMANCE] Suppression de tous les éléments graphiques     |
//| ✅ [PERFORMANCE] Conservation uniquement des calculs nécessaires |
//| ✅ [PERFORMANCE] Buffer 7 des signaux préservé pour l'EA         |
//| ✅ [PERFORMANCE] Pas de dessin de trendlines, labels, objets     |
//| ✅ [PERFORMANCE] Pas de ChartRedraw() ni d'affichage Comment()   |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "2.14_NoGUI_FIXED"
#property indicator_separate_window
#property indicator_buffers 11  // Même nombre de buffers que l'original
#property indicator_plots   8   // ✅ CORRECTION: 8 plots (tous invisibles)

// ✅ CORRECTION: Déclarer 8 plots même s'ils sont invisibles
// Plots 1-7: Buffers de calcul (invisibles pour performance)
#property indicator_label1  "RSI"
#property indicator_type1   DRAW_NONE

#property indicator_label2  "RSI MA"
#property indicator_type2   DRAW_NONE

#property indicator_label3  "BB Upper"
#property indicator_type3   DRAW_NONE

#property indicator_label4  "BB Lower"
#property indicator_type4   DRAW_NONE

#property indicator_label5  "Divergences"
#property indicator_type5   DRAW_NONE

#property indicator_label6  "Hidden Bull Div"
#property indicator_type6   DRAW_NONE

#property indicator_label7  "Hidden Bear Div"
#property indicator_type7   DRAW_NONE

// Plot 8: Signal buffer (invisible mais ACCESSIBLE par EA)
#property indicator_label8  "Divergence Signal"
#property indicator_type8   DRAW_NONE

//--- Input parameters (IDENTIQUES à l'original)
input int                InpRSIPeriod        = 3;               // RSI Length
input ENUM_APPLIED_PRICE InpRSIAppliedPrice = PRICE_CLOSE;     // Source
input double InpUpperLevel      = 90.0;      // Upper Level
input double InpLowerLevel      = 10.0;      // Lower Level
input int    InpLookbackLeft  = 3;      // Lookback Left (réduit pour test)
input int    InpLookbackRight = 1;      // Lookback Right (délai réduit)
input int    InpRangeLower    = 3;      // Range Lower (réduit pour test)
input int    InpRangeUpper    = 100;    // Range Upper (augmenté pour test)

//--- Constantes (paramètres en dur) - CONSERVÉS pour les calculs
const bool   SHOW_LEVELS = false;        // ❌ DÉSACTIVÉ - Pas d'affichage
const double MIDDLE_LEVEL = 50.0;
const color  LEVEL_COLOR = clrSilver;
const bool   SHOW_TRENDLINES = false;    // ❌ DÉSACTIVÉ - Pas de dessin
const color  BULLISH_COLOR = clrLimeGreen;
const color  BEARISH_COLOR = clrRed;
const int    TRENDLINE_WIDTH = 2;
const bool   SHOW_HIDDEN_DIV = true;     // ✅ CONSERVÉ - Calculs nécessaires
const color  HIDDEN_BULL_COLOR = clrDodgerBlue;
const color  HIDDEN_BEAR_COLOR = clrOrange;
const int    HIDDEN_TREND_WIDTH = 2;
const ENUM_LINE_STYLE HIDDEN_LINE_STYLE = STYLE_DASH;
const int    MAX_TRENDLINES = 50;
const int    MAX_BARS_CHECK = 100;

//--- Indicator buffers (TOUS CONSERVÉS pour les calculs)
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

// ✅ EA INTEGRATION : Buffer de signaux pour l'EA (SEUL BUFFER UTILISÉ)
double DivergenceSignalBuffer[];  // Buffer 7: Codes: 0=Aucun, 1=RegBull, 2=RegBear, 3=HidBull, 4=HidBear

//--- Constantes
const double DIVERGENCE_MARKER_OFFSET = 5.0;

//--- Global variables (SIMPLIFIÉS)
string indicatorPrefix = "RSI_DIV_";
int objectCounter = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // ✅ DEBUG SIMPLIFIÉ - Pas de logs verbeux
   Print("🔍 RSI_Divergence_Indicator_NoGUI - Version optimisée pour backtesting");

   // Validation des paramètres (IDENTIQUE à l'original)
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
   
   //--- Indicator buffers mapping (IDENTIQUE à l'original)
   // Buffers 0-4 : Calculs nécessaires (mais pas d'affichage)
   SetIndexBuffer(0, RSIBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(1, MABuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BBUpperBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BBLowerBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, DivergenceBuffer, INDICATOR_CALCULATIONS);

   // Buffers 5-6 : Hidden divergences (calculs)
   SetIndexBuffer(5, HiddenBullDivBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, HiddenBearDivBuffer, INDICATOR_CALCULATIONS);

   // Buffer 7 : Signal pour EA (ACCESSIBLE - DOIT être INDICATOR_DATA)
   SetIndexBuffer(7, DivergenceSignalBuffer, INDICATOR_DATA);
   
   // Buffers 8-10 : Calculs internes
   SetIndexBuffer(8, UpBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, DownBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, StdDevBuffer, INDICATOR_CALCULATIONS);

   // ✅ CORRECTION: Configuration des 8 plots (tous invisibles)
   for(int i = 0; i < 7; i++)
   {
      PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, 0.0);
   }
   
   // Configuration spécifique du plot 8 (index 7) - Buffer de signaux
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetString(7, PLOT_LABEL, "Signal");

   // ✅ Initialiser le buffer de signaux
   ArrayInitialize(DivergenceSignalBuffer, 0.0);

   // ✅ DEBUG : Log de confirmation
   Print("✅ Buffer 7 (DivergenceSignalBuffer) configuré - Version NoGUI FIXED");
   Print("✅ 8 plots déclarés (tous invisibles) pour compatibilité EA");
   
   // ❌ SUPPRIMÉ : Configuration des arrows (pas d'affichage)
   // ❌ SUPPRIMÉ : Configuration des empty values (pas d'affichage)
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "RSI_Div_NoGUI(" + string(InpRSIPeriod) + ")");
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   // ❌ SUPPRIMÉ : Création des niveaux RSI (pas d'affichage)
   // ❌ SUPPRIMÉ : Suppression des anciens objets (pas d'objets)
   
   Print("✅ RSI Divergence Indicator NoGUI Initialized!");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // ❌ SUPPRIMÉ : DeleteAllObjects() - pas d'objets à supprimer
   Print("RSI Divergence Indicator NoGUI stopped. Reason: ", reason);
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
   // ✅ FIX: Validation des limites des arrays (IDENTIQUE à l'original)
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
         Print("🔧 SIGNAL DE TEST FORCÉ NoGUI en position [", testPos, "] - Valeur: 1.0");
         Print("   Time: ", TimeToString(time[testPos]));
      }
   }
   
   // ✅ FIX: Cohérence indexation - tous les arrays en série inversée (IDENTIQUE)
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
   
   // ✅ FIX: Optimisation calcul RSI - ne calculer que les nouvelles barres (IDENTIQUE)
   CalculateRSI(rates_total, prev_calculated, close);
   
   // ✅ FIX: Détection nouvelle barre robuste avec prev_calculated (IDENTIQUE)
   bool isNewBar = (prev_calculated == 0 || rates_total > prev_calculated);
   
   if(isNewBar)
   {
      // ❌ SUPPRIMÉ : DeleteOldTrendlines() - pas de trendlines à supprimer
      
      // Vérifier qu'on a assez de données (IDENTIQUE)
      if(rates_total > InpRangeLower + InpLookbackLeft + InpLookbackRight + 20)
      {
         int startPos, endPos;
         
         // ✅ FIX CRITIQUE : Différencier premier chargement et nouvelles barres (IDENTIQUE)
         if(prev_calculated == 0)
         {
            // PREMIER CHARGEMENT : Analyser toutes les barres historiques
            startPos = InpLookbackRight + 1;
            endPos = MathMin(MAX_BARS_CHECK, rates_total - InpRangeUpper - InpLookbackLeft - 1);
         }
         else
         {
            // NOUVELLES BARRES : Analyser seulement les positions récemment confirmées
            int newBars = rates_total - prev_calculated;
            startPos = InpLookbackRight + 1;
            endPos = InpLookbackRight + newBars + InpLookbackLeft + 5;
            endPos = MathMin(endPos, startPos + 30);  // Maximum 30 barres à vérifier
         }
         
         // Parcourir les barres à vérifier (IDENTIQUE)
         for(int i = startPos; i <= endPos; i++)
         {
            // ✅ FIX: Validation des indices avant appel des fonctions (IDENTIQUE)
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
      Print("═══ DEBUG INDICATEUR NoGUI - État Buffer 7 ═══");
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
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate RSI and divergences                                    |
//+------------------------------------------------------------------+
void CalculateRSI(int rates_total, int prev_calculated, const double &close[])
{
   // ✅ FIX: Validation des paramètres d'entrée (IDENTIQUE à l'original)
   if(rates_total < InpRSIPeriod + 2)
      return;
   
   // ✅ FIX: Validation des tailles d'arrays (IDENTIQUE)
   if(ArraySize(close) < rates_total || ArraySize(RSIBuffer) < rates_total)
      return;
   
   // Initialisation seulement si nécessaire (IDENTIQUE)
   static bool firstRun = true;
   if(firstRun)
   {
      ArrayInitialize(RSIBuffer, EMPTY_VALUE);
      ArrayInitialize(MABuffer, EMPTY_VALUE);
      ArrayInitialize(BBUpperBuffer, EMPTY_VALUE);
      ArrayInitialize(BBLowerBuffer, EMPTY_VALUE);
      ArrayInitialize(DivergenceBuffer, EMPTY_VALUE);
      
      // Initialisation des buffers hidden divergences
      ArrayInitialize(HiddenBullDivBuffer, EMPTY_VALUE);
      ArrayInitialize(HiddenBearDivBuffer, EMPTY_VALUE);
      
      firstRun = false;
   }
   
   int start;
   
   // ✅ FIX: Optimisation - Première exécution: calculer tout (IDENTIQUE)
   if(prev_calculated == 0)
   {
      start = rates_total - InpRSIPeriod - 1;
      
      // ✅ FIX: Validation des limites pour éviter array out of range (IDENTIQUE)
      if(start < 0 || start + InpRSIPeriod >= rates_total || start >= ArraySize(close))
         return;
      
      // Étape 1: Initialisation avec SMA (IDENTIQUE)
      double sumUp = 0, sumDown = 0;
      for(int j = 0; j < InpRSIPeriod; j++)
      {
         int idx = start + 1 + j;
         // ✅ FIX: Validation des indices (IDENTIQUE)
         if(idx >= rates_total || idx >= ArraySize(close) || idx - 1 < 0 || idx - 1 >= ArraySize(close))
            break;
         double change = close[idx - 1] - close[idx];
         if(change > 0)
            sumUp += change;
         else
            sumDown += -change;
      }
      
      // ✅ FIX: Validation avant assignation (IDENTIQUE)
      if(start >= 0 && start < ArraySize(UpBuffer) && start < ArraySize(DownBuffer))
      {
         UpBuffer[start] = sumUp / InpRSIPeriod;
         DownBuffer[start] = sumDown / InpRSIPeriod;
         
         // Calcul du RSI initial (IDENTIQUE)
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
      // ✅ FIX: Seulement recalculer les nouvelles barres (IDENTIQUE)
      start = rates_total - prev_calculated;
      if(start < 0) start = 0;
   }
   
   // Étape 2: Application de la formule RMA (IDENTIQUE)
   for(int i = start; i >= 0; i--)
   {
      // ✅ FIX: Validation complète des indices (IDENTIQUE)
      if(i + 1 >= rates_total || i + 1 >= ArraySize(close) || i >= ArraySize(close) ||
         i >= ArraySize(UpBuffer) || i + 1 >= ArraySize(UpBuffer) ||
         i >= ArraySize(DownBuffer) || i + 1 >= ArraySize(DownBuffer) ||
         i >= ArraySize(RSIBuffer))
         continue;
         
      double change = close[i] - close[i + 1];
      
      // Formule RMA (équivalent ta.rma de Pine Script) (IDENTIQUE)
      UpBuffer[i] = (UpBuffer[i + 1] * (InpRSIPeriod - 1) + MathMax(change, 0)) / InpRSIPeriod;
      DownBuffer[i] = (DownBuffer[i + 1] * (InpRSIPeriod - 1) + MathMax(-change, 0)) / InpRSIPeriod;
      
      // Calcul du RSI (IDENTIQUE)
      if(DownBuffer[i] == 0)
         RSIBuffer[i] = 100;
      else if(UpBuffer[i] == 0)
         RSIBuffer[i] = 0;
      else
         RSIBuffer[i] = 100.0 - (100.0 / (1.0 + UpBuffer[i] / DownBuffer[i]));
   }
}

//+------------------------------------------------------------------+
//| Équivalent de ta.pivotlow() de Pine Script                       |
//+------------------------------------------------------------------+
bool IsPivotLow(int pos, int leftBars, int rightBars, const double &buffer[])
{
   // ✅ FIX PINE SCRIPT: Validation des limites (IDENTIQUE à l'original)
   if(pos < 0 || pos >= ArraySize(buffer))
      return false;
   
   // Vérifier qu'on a assez de barres de chaque côté (IDENTIQUE)
   if(pos < rightBars || pos + leftBars >= ArraySize(buffer))
      return false;
   
   double pivotValue = buffer[pos];
   
   // ✅ FIX PINE SCRIPT: Vérifier que pos est le MINIMUM dans la fenêtre (IDENTIQUE)
   for(int i = pos - rightBars; i <= pos + leftBars; i++)
   {
      // Ne pas comparer avec soi-même (IDENTIQUE)
      if(i == pos) 
         continue;
      
      // Validation de l'indice (IDENTIQUE)
      if(i < 0 || i >= ArraySize(buffer))
         continue;
      
      // ✅ FIX PINE SCRIPT: Si une valeur est plus petite, ce n'est PAS un pivot bas (IDENTIQUE)
      if(buffer[i] < pivotValue)
         return false;
   }
   
   return true; // C'est un pivot bas valide
}

//+------------------------------------------------------------------+
//| Équivalent de ta.pivothigh() de Pine Script                      |
//+------------------------------------------------------------------+
bool IsPivotHigh(int pos, int leftBars, int rightBars, const double &buffer[])
{
   // ✅ FIX PINE SCRIPT: Validation des limites (IDENTIQUE à l'original)
   if(pos < 0 || pos >= ArraySize(buffer))
      return false;
   
   if(pos < rightBars || pos + leftBars >= ArraySize(buffer))
      return false;
   
   double pivotValue = buffer[pos];
   
   // ✅ FIX PINE SCRIPT: Vérifier que pos est le MAXIMUM dans la fenêtre (IDENTIQUE)
   for(int i = pos - rightBars; i <= pos + leftBars; i++)
   {
      if(i == pos) 
         continue;
      
      if(i < 0 || i >= ArraySize(buffer))
         continue;
      
      // ✅ FIX PINE SCRIPT: Si une valeur est plus grande, ce n'est PAS un pivot haut (IDENTIQUE)
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
   // ✅ FIX: Validation complète des paramètres d'entrée (IDENTIQUE à l'original)
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(low))
      return;
   
   int checkPos = currentBar;
   
   // ✅ Vérifier qu'il n'y a pas déjà un signal (IDENTIQUE)
   if(DivergenceSignalBuffer[checkPos] != 0.0 && DivergenceSignalBuffer[checkPos] != EMPTY_VALUE)
      return;
   
   // ✅ FIX: Vérifications de limites améliorées (IDENTIQUE)
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // ✅ FIX PINE SCRIPT: REMPLACER toute la section de vérification de pivot (IDENTIQUE)
   if(!IsPivotLow(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // ✅ FIX PINE SCRIPT: Recherche du pivot précédent - SIMPLIFIER (IDENTIQUE)
   int prevPivotBar = -1;
   double prevPivotRSI = 0;
   double prevPivotPrice = 0;
   
   int maxSearch = MathMin(checkPos + InpRangeUpper, ArraySize(RSIBuffer) - 1);
   int minSearch = MathMax(checkPos + InpRangeLower, InpLookbackRight);
   
   // Rechercher le premier pivot précédent valide (IDENTIQUE)
   for(int i = minSearch; i <= maxSearch; i++)
   {
      if(i < 0 || i >= ArraySize(RSIBuffer) || i >= ArraySize(low))
         continue;
      
      // ✅ FIX PINE SCRIPT: Utiliser IsPivotLow au lieu des boucles manuelles (IDENTIQUE)
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
   
   // ✅ FIX PINE SCRIPT: Calcul correct de la distance (IDENTIQUE)
   int barsSincePivot = prevPivotBar - checkPos;
   
   // Validation du range (IDENTIQUE)
   if(barsSincePivot < InpRangeLower || barsSincePivot > InpRangeUpper)
      return;
   
   // D. Conditions de divergence exactes (IDENTIQUE)
   double currentPrice = low[checkPos];
   bool rsiHigherLow = pivotRSI > prevPivotRSI;
   bool priceLowerLow = currentPrice < prevPivotPrice;
   
   if(rsiHigherLow && priceLowerLow)
   {
      // ✅ DEBUG: Logs pour diagnostic (temporaire)
      Print("🟢 BULLISH DIV @ Bar[", checkPos, "] Signal=", 1.0);
      
      // Marquer la divergence (IDENTIQUE)
      DivergenceBuffer[checkPos] = pivotRSI - DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Enregistrer le signal : 1 = Regular Bullish (IDENTIQUE)
      DivergenceSignalBuffer[checkPos] = 1.0;
      
      // ✅ DEBUG: Confirmation d'écriture dans le buffer
      Print("✅✅✅ SIGNAL ÉCRIT À POSITION [", checkPos, "]");
      Print("   Valeur: ", DivergenceSignalBuffer[checkPos]);
      Print("   Time: ", TimeToString(time[checkPos]));
      Print("   RSI: ", pivotRSI, " | Price: ", currentPrice);
      Print("   Prev RSI: ", prevPivotRSI, " | Prev Price: ", prevPivotPrice);
      
      // ❌ SUPPRIMÉ : Dessin de la trendline - pas d'affichage graphique
   }
}

//+------------------------------------------------------------------+
//| Check for bearish divergence                                     |
//+------------------------------------------------------------------+
void CheckBearishDivergence(int currentBar, const datetime &time[], const double &high[])
{
   // ✅ FIX: Validation complète des paramètres d'entrée (IDENTIQUE à l'original)
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(high))
      return;
   
   int checkPos = currentBar;
   
   // ✅ Vérifier qu'il n'y a pas déjà un signal (IDENTIQUE)
   if(DivergenceSignalBuffer[checkPos] != 0.0 && DivergenceSignalBuffer[checkPos] != EMPTY_VALUE)
      return;
   
   // ✅ FIX: Vérifications de limites améliorées (IDENTIQUE)
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // ✅ FIX PINE SCRIPT: REMPLACER par IsPivotHigh (IDENTIQUE)
   if(!IsPivotHigh(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // ✅ FIX PINE SCRIPT: Recherche simplifiée du pivot précédent (IDENTIQUE)
   int prevPivotBar = -1;
   double prevPivotRSI = 0;
   double prevPivotPrice = 0;
   
   int maxSearch = MathMin(checkPos + InpRangeUpper, ArraySize(RSIBuffer) - 1);
   int minSearch = MathMax(checkPos + InpRangeLower, InpLookbackRight);
   
   for(int i = minSearch; i <= maxSearch; i++)
   {
      if(i < 0 || i >= ArraySize(RSIBuffer) || i >= ArraySize(high))
         continue;
      
      // ✅ FIX PINE SCRIPT: Utiliser IsPivotHigh (IDENTIQUE)
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
   
   // ✅ FIX PINE SCRIPT: Calcul correct de la distance (IDENTIQUE)
   int barsSincePivot = prevPivotBar - checkPos;
   
   if(barsSincePivot < InpRangeLower || barsSincePivot > InpRangeUpper)
      return;
   
   // D. Conditions de divergence exactes (IDENTIQUE)
   double currentPrice = high[checkPos];
   bool rsiLowerHigh = pivotRSI < prevPivotRSI;
   bool priceHigherHigh = currentPrice > prevPivotPrice;
   
   if(rsiLowerHigh && priceHigherHigh)
   {
      // ✅ DEBUG: Logs pour diagnostic (temporaire)
      Print("🔴 BEARISH DIV @ Bar[", checkPos, "] Signal=", 2.0);
      
      // Marquer la divergence (IDENTIQUE)
      DivergenceBuffer[checkPos] = pivotRSI + DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Enregistrer le signal : 2 = Regular Bearish (IDENTIQUE)
      DivergenceSignalBuffer[checkPos] = 2.0;
      
      // ✅ DEBUG: Confirmation d'écriture dans le buffer
      Print("✅✅✅ SIGNAL ÉCRIT À POSITION [", checkPos, "]");
      Print("   Valeur: ", DivergenceSignalBuffer[checkPos]);
      Print("   Time: ", TimeToString(time[checkPos]));
      Print("   RSI: ", pivotRSI, " | Price: ", currentPrice);
      Print("   Prev RSI: ", prevPivotRSI, " | Prev Price: ", prevPivotPrice);
      
      // ❌ SUPPRIMÉ : Dessin de la trendline
   }
}

//+------------------------------------------------------------------+
//| Check for HIDDEN bullish divergence                             |
//+------------------------------------------------------------------+
void CheckHiddenBullishDivergence(int currentBar, const datetime &time[], const double &low[])
{
   // ✅ FIX HIDDEN DIV : Vérifier si l'option est activée (IDENTIQUE)
   if(!SHOW_HIDDEN_DIV)
      return;
   
   // Validation complète des paramètres d'entrée (IDENTIQUE)
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(low))
      return;
   
   int checkPos = currentBar;
   
   // ✅ Vérifier qu'il n'y a pas déjà un signal (IDENTIQUE)
   if(DivergenceSignalBuffer[checkPos] != 0.0 && DivergenceSignalBuffer[checkPos] != EMPTY_VALUE)
      return;
   
   // Vérifications de limites (IDENTIQUE)
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // Vérifier que c'est un pivot bas sur le RSI (IDENTIQUE)
   if(!IsPivotLow(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // Recherche du pivot précédent (IDENTIQUE)
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
   
   // Calcul de la distance (IDENTIQUE)
   int barsSincePivot = prevPivotBar - checkPos;
   
   if(barsSincePivot < InpRangeLower || barsSincePivot > InpRangeUpper)
      return;
   
   // ✅ CONDITIONS HIDDEN BULLISH (INVERSER par rapport à Regular) (IDENTIQUE)
   double currentPrice = low[checkPos];
   bool rsiLowerLow = pivotRSI < prevPivotRSI;      // RSI fait Lower Low (inversé)
   bool priceHigherLow = currentPrice > prevPivotPrice;  // Prix fait Higher Low (inversé)
   
   if(rsiLowerLow && priceHigherLow)
   {
      // ❌ SUPPRIMÉ : Print() - pas de logs verbeux
      
      // Marquer la divergence (IDENTIQUE)
      HiddenBullDivBuffer[checkPos] = pivotRSI - DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Enregistrer le signal : 3 = Hidden Bullish (IDENTIQUE)
      DivergenceSignalBuffer[checkPos] = 3.0;
      
      // ❌ SUPPRIMÉ : Confirmation d'écriture dans le buffer
      
      // ❌ SUPPRIMÉ : Dessin de la trendline
   }
}

//+------------------------------------------------------------------+
//| Check for HIDDEN bearish divergence                             |
//+------------------------------------------------------------------+
void CheckHiddenBearishDivergence(int currentBar, const datetime &time[], const double &high[])
{
   // ✅ FIX HIDDEN DIV : Vérifier si l'option est activée (IDENTIQUE)
   if(!SHOW_HIDDEN_DIV)
      return;
   
   // Validation complète des paramètres d'entrée (IDENTIQUE)
   if(currentBar < 0 || currentBar >= ArraySize(RSIBuffer) || 
      currentBar >= ArraySize(time) || currentBar >= ArraySize(high))
      return;
   
   int checkPos = currentBar;
   
   // ✅ Vérifier qu'il n'y a pas déjà un signal (IDENTIQUE)
   if(DivergenceSignalBuffer[checkPos] != 0.0 && DivergenceSignalBuffer[checkPos] != EMPTY_VALUE)
      return;
   
   // Vérifications de limites (IDENTIQUE)
   if(checkPos >= ArraySize(RSIBuffer) - InpLookbackLeft)
      return;
   if(checkPos < InpLookbackRight)
      return;
   
   // Vérifier que c'est un pivot haut sur le RSI (IDENTIQUE)
   if(!IsPivotHigh(checkPos, InpLookbackLeft, InpLookbackRight, RSIBuffer))
      return;
   
   double pivotRSI = RSIBuffer[checkPos];
   
   // Recherche du pivot précédent (IDENTIQUE)
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
   
   // Calcul de la distance (IDENTIQUE)
   int barsSincePivot = prevPivotBar - checkPos;
   
   if(barsSincePivot < InpRangeLower || barsSincePivot > InpRangeUpper)
      return;
   
   // ✅ CONDITIONS HIDDEN BEARISH (INVERSER par rapport à Regular) (IDENTIQUE)
   double currentPrice = high[checkPos];
   bool rsiHigherHigh = pivotRSI > prevPivotRSI;         // RSI fait Higher High (inversé)
   bool priceLowerHigh = currentPrice < prevPivotPrice;  // Prix fait Lower High (inversé)
   
   if(rsiHigherHigh && priceLowerHigh)
   {
      // ❌ SUPPRIMÉ : Print() - pas de logs verbeux
      
      // Marquer la divergence (IDENTIQUE)
      HiddenBearDivBuffer[checkPos] = pivotRSI + DIVERGENCE_MARKER_OFFSET;
      
      // ✅ EA INTEGRATION : Enregistrer le signal : 4 = Hidden Bearish (IDENTIQUE)
      DivergenceSignalBuffer[checkPos] = 4.0;
      
      // ❌ SUPPRIMÉ : Confirmation d'écriture dans le buffer
      
      // ❌ SUPPRIMÉ : Dessin de la trendline
   }
}

//+------------------------------------------------------------------+
