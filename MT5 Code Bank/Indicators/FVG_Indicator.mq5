//+------------------------------------------------------------------+
//|                                                FVG_Indicator.mq5 |
//|                                    Fair Value Gap Detection Tool |
//+------------------------------------------------------------------+
#property copyright "FVG Indicator"
#property version   "1.40"
#property indicator_chart_window
#property indicator_plots 0

#include "../../EA/Shared/FVGDetector.mqh"

//--- Détection
input ENUM_TIMEFRAMES   InpTimeframe          = PERIOD_M5;   // TF d'analyse
input int               InpATRPeriod          = 14;          // Période ATR
input double            InpMinGapATRPercent   = 5.0;         // Min gap en % ATR
input double            InpEpsilonPts         = 0.1;         // Tolérance en points
input bool              InpDebugMode          = false;

//--- Affichage
input int               InpLookbackBars       = 300;         // Fenêtre d'affichage
input int               InpExtendForwardBars  = 150;          // Extension max vers la droite
input color             InpBullishBaseColor   = clrGreen;    // Couleur haussière
input color             InpBearishBaseColor   = clrRed;      // Couleur baissière
input int               InpFillAlpha          = 70;          // 0..255
input int               InpBorderWidth        = 1;

//--- Invalidation
input double            InpInvalidatePct      = 30.0;        // Suppression si pénétration >= %
input InvalidationSide  InpInvalidateMode     = WICK_TOUCH;

//+------------------------------------------------------------------+
//| Convertit color + alpha en ARGB                                  |
//+------------------------------------------------------------------+
uint ColorToARGB(color clr, int alpha)
{
    uchar r = (uchar)((clr >> 0) & 0xFF);
    uchar g = (uchar)((clr >> 8) & 0xFF);
    uchar b = (uchar)((clr >> 16) & 0xFF);
    uchar a = (uchar)MathMin(255, MathMax(0, alpha));
    
    return (uint)((a << 24) | (r << 16) | (g << 8) | b);
}

//--- FVGDetector instance
FVGDetector g_fvgDetector;
FVGConfig   g_fvgConfig;

//--- Manager objets
class FVGObjectManager
{
public:
   static string GenerateName(const FVGInfo &fvg);
   static bool   DrawRectangle(const FVGInfo &fvg, datetime lastTfBar);
   static int    GetObjectCount();
};

//--- Globals
datetime g_lastTfBar = 0;

//--- Protos
void     DrawAllFVGs();
void     DeleteOldFVGs();
void     DisplayFVGInfo();
bool     IsNewBarOnTf(ENUM_TIMEFRAMES tf, datetime &out_lastBar);

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("FVG(%s, Gap>=%.1f%% ATR, Lkb=%d, Ext<=%d, Inv=%.0f%%)",
                   EnumToString(InpTimeframe), InpMinGapATRPercent, InpLookbackBars, InpExtendForwardBars, InpInvalidatePct));

   // Configuration FVGDetector
   g_fvgConfig.atrPeriod = InpATRPeriod;
   g_fvgConfig.minGapATRPercent = InpMinGapATRPercent;
   g_fvgConfig.epsilonPts = InpEpsilonPts;
   g_fvgConfig.invalidatePct = InpInvalidatePct;
   g_fvgConfig.mode = InpInvalidateMode;
   g_fvgConfig.lookbackBars = InpLookbackBars;
   g_fvgConfig.debugMode = InpDebugMode;
   
   if(!g_fvgDetector.Init(_Symbol, InpTimeframe, g_fvgConfig))
   {
      Print("FVGDetector initialization failed");
      return INIT_FAILED;
   }

   DeleteOldFVGs();
   g_lastTfBar = 0;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_fvgDetector.Deinit();
   DeleteOldFVGs();
   Comment("");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
   if(rates_total < 3) return 0;

   datetime lastBar;
   bool isNewBar = IsNewBarOnTf(InpTimeframe, lastBar);

   if(prev_calculated == 0) // init
   {
      ArrayResize(m_fvgList, 0);
      DeleteOldFVGs();
      g_lastTfBar = 0;
      isNewBar = true;
   }

   if(isNewBar)
   {
      g_lastTfBar = lastBar;  // Mise à jour de la dernière barre du timeframe
      g_fvgDetector.ProcessTimeframe(InpTimeframe);           // détecte et ajoute
      g_fvgDetector.FilterByLookback(InpTimeframe, InpLookbackBars); // limite à la fenêtre
      g_fvgDetector.UpdateInvalidation(InpTimeframe);         // supprime si pénétration >= %
      DrawAllFVGs();                                         // redessine avec extension progressive
   }

   DisplayFVGInfo();
   return rates_total;
}

//+------------------------------------------------------------------+
//| Détection - maintenant gérée par FVGDetector                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Invalidation - maintenant gérée par FVGDetector                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Filtrage - maintenant géré par FVGDetector                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Dessin                                                           |
//+------------------------------------------------------------------+
void DrawAllFVGs()
{
   // Efface tout puis redessine selon l'état actuel
   DeleteOldFVGs();

   datetime lastBar = (g_lastTfBar > 0) ? g_lastTfBar : TimeCurrent();
   
   // Récupérer les FVG valides depuis le détecteur
   FVGInfo fvgList[];
   g_fvgDetector.GetFVGList(fvgList, true);
   
   int drawn = 0;
   for(int i = 0; i < ArraySize(fvgList); i++)
   {
      if(FVGObjectManager::DrawRectangle(fvgList[i], lastBar)) 
         drawn++;
   }

   if(InpDebugMode) Print("FVG drawn: ", drawn);
}

void DeleteOldFVGs()
{
   int total = ObjectsTotal(0);
   for(int i=total-1;i>=0;i--)
   {
      string name = ObjectName(0,i);
      if(StringFind(name,"FVG_")>=0)
         ObjectDelete(0,name);
   }
}

//+------------------------------------------------------------------+
//| Utilitaires - maintenant gérés par FVGDetector                  |
//+------------------------------------------------------------------+

void DisplayFVGInfo()
{
   int total, bulls, bears, valid;
   g_fvgDetector.GetStats(total, bulls, bears, valid);
   
   string info = "=== FVG INDICATOR ===\n";
   info += StringFormat("%s: %d zones (↑%d ↓%d) - Valides: %d\n", 
                        EnumToString(InpTimeframe), total, bulls, bears, valid);
   info += StringFormat("Lookback=%d | Extend<=%d | Invalidate=%.0f%% %s\n",
                        InpLookbackBars, InpExtendForwardBars, InpInvalidatePct,
                        (InpInvalidateMode==WICK_TOUCH?"wick":"close"));
   Comment(info);
}

bool IsNewBarOnTf(ENUM_TIMEFRAMES tf, datetime &out_lastBar)
{
   datetime t[2];
   int n = CopyTime(_Symbol, tf, 0, 2, t);
   if(n < 2) return false;
   out_lastBar = t[0];
   if(t[0] != g_lastTfBar){ g_lastTfBar = t[0]; return true; }
   return false;
}

//+------------------------------------------------------------------+
//| ExistsFVG - maintenant géré par FVGDetector                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manager objets                                                   |
//+------------------------------------------------------------------+
string FVGObjectManager::GenerateName(const FVGInfo &fvg)
{
   // B/S + time + prix arrondis en points → < 40 chars
   long topPt = (long)MathRound(fvg.top/_Point);
   long botPt = (long)MathRound(fvg.bottom/_Point);
   return StringFormat("FVG_%c_%u_%ld_%ld",
                       (fvg.isBullish?'B':'S'),
                       (uint)fvg.time, topPt, botPt);
}

// Dessin avec extension progressive jusqu'à InpExtendForwardBars
bool FVGObjectManager::DrawRectangle(const FVGInfo &fvg, datetime lastTfBar)
{
   string objName = GenerateName(fvg);
   if(ObjectFind(0, objName) >= 0) ObjectDelete(0, objName);

   // Normalisation
   datetime t1 = fvg.startTime, t2 = fvg.endTime;
   if(t2 < t1) { datetime s=t1; t1=t2; t2=s; }
   double pTop = MathMax(fvg.top, fvg.bottom);
   double pBot = MathMin(fvg.top, fvg.bottom);

   // LOG avant création
   if(InpDebugMode)
      PrintFormat("FVG: %s t1=%s t2=%s top=%.5f bot=%.5f", 
                  objName, TimeToString(t1), TimeToString(t2), pTop, pBot);

   // Extension dynamique
   int secPerBar = PeriodSeconds(fvg.timeframe);
   if(secPerBar <= 0) secPerBar = PeriodSeconds(_Period);

   long passedSec = (long)(lastTfBar - t2);
   int  passedBars = (passedSec>0 ? (int)(passedSec / secPerBar) : 0);
   int  extBars = MathMin(MathMax(passedBars,0), InpExtendForwardBars);

   // Extension temporelle réactivée
   datetime t2ext = t2 + (datetime)((long)extBars * (long)secPerBar);

   if(InpDebugMode)
      PrintFormat("Extension: passed=%d ext=%d t2ext=%s", passedBars, extBars, TimeToString(t2ext));

   // Vérifications
   if(pTop <= pBot || t2ext <= t1)
   {
      if(InpDebugMode)
         Print("ERROR: Invalid coordinates! pTop=", pTop, " pBot=", pBot, " t2ext=", TimeToString(t2ext), " t1=", TimeToString(t1));
      return false;
   }

   // Création
   if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, t1, pTop, t2ext, pBot))
   {
      PrintFormat("ObjectCreate FAILED: err=%d objName=%s t1=%s t2ext=%s pTop=%.5f pBot=%.5f",
                  GetLastError(), objName, TimeToString(t1), TimeToString(t2ext), pTop, pBot);
      return false;
   }

   // Configuration visuelle
   color base = fvg.isBullish ? InpBullishBaseColor : InpBearishBaseColor;
   uint argb = ColorToARGB(base, InpFillAlpha);

   ObjectSetInteger(0, objName, OBJPROP_COLOR, base);          // Bordure
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, argb);        // Remplissage avec transparence
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpBorderWidth);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);

   return true;
}

int FVGObjectManager::GetObjectCount()
{
   int count=0;
   int total = ObjectsTotal(0,0,OBJ_RECTANGLE);
   for(int i=0;i<total;i++)
   {
      string name = ObjectName(0,i,0,OBJ_RECTANGLE);
      if(StringFind(name,"FVG_")>=0) count++;
   }
   return count;
}
//+------------------------------------------------------------------+
