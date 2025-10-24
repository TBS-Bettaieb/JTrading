//+------------------------------------------------------------------+
//|                                                FVG_Indicator.mq5 |
//|                                    Fair Value Gap Detection Tool |
//+------------------------------------------------------------------+
#property copyright "FVG Indicator"
#property version   "1.30"
#property indicator_chart_window
#property indicator_plots 0

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
enum InvalidationSide { WICK_TOUCH = 0, CLOSE_BODY = 1 };
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

//--- Structure
struct FVGInfo
{
   datetime time;            // bougie centrale
   datetime startTime;       // bougie 1
   datetime endTime;         // bougie 3
   double   top;             // prix haut de zone
   double   bottom;          // prix bas de zone
   bool     isBullish;
   ENUM_TIMEFRAMES timeframe;
   double   gapSize;
   bool     IsValid;         // indique si le FVG est encore valide
};

//--- Manager objets
class FVGObjectManager
{
public:
   static string GenerateName(const FVGInfo &fvg);
   static bool   DrawRectangle(const FVGInfo &fvg, datetime lastTfBar);
   static int    GetObjectCount();
};

//--- Globals
FVGInfo  m_fvgList[];
int      m_atrHandle        = INVALID_HANDLE;
datetime g_lastTfBar        = 0;

//--- Protos
void     ProcessTimeframe(ENUM_TIMEFRAMES tf, int atrHandle);
void     DrawAllFVGs();
void     DeleteOldFVGs();
FVGInfo  CreateFVGInfo(datetime time, datetime startTime, datetime endTime, double top, double bottom, bool isBullish, ENUM_TIMEFRAMES tf, double gapSize);
void     AddFVGToList(FVGInfo &fvg);
void     SortFVGsByTime(FVGInfo &tempList[]);
void     DisplayFVGInfo();
bool     IsNewBarOnTf(ENUM_TIMEFRAMES tf, datetime &out_lastBar);
bool     ExistsFVG(const FVGInfo &x);
void     FilterFVGsByLookback(ENUM_TIMEFRAMES tf, int lookbackBars);
void     UpdateAndInvalidateFVGs(ENUM_TIMEFRAMES tf);

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("FVG(%s, Gap>=%.1f%% ATR, Lkb=%d, Ext<=%d, Inv=%.0f%%)",
                   EnumToString(InpTimeframe), InpMinGapATRPercent, InpLookbackBars, InpExtendForwardBars, InpInvalidatePct));

   m_atrHandle = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   if(m_atrHandle == INVALID_HANDLE)
   {
      Print("ATR creation failed for ", EnumToString(InpTimeframe), " err=", GetLastError());
      return INIT_FAILED;
   }

   ArrayResize(m_fvgList, 0);
   DeleteOldFVGs();
   g_lastTfBar = 0;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
   DeleteOldFVGs();
   ArrayFree(m_fvgList);
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
      ProcessTimeframe(InpTimeframe, m_atrHandle);     // détecte et ajoute
      FilterFVGsByLookback(InpTimeframe, InpLookbackBars); // limite à la fenêtre
      UpdateAndInvalidateFVGs(InpTimeframe);           // supprime si pénétration >= %
      DrawAllFVGs();                                   // redessine avec extension progressive
   }

   DisplayFVGInfo();
   return rates_total;
}

//+------------------------------------------------------------------+
//| Détection                                                        |
//+------------------------------------------------------------------+
void ProcessTimeframe(ENUM_TIMEFRAMES tf, int atrHandle)
{
   int need = MathMax(InpLookbackBars+10, 500);

   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 0, need, rates);
   if(copied < 3) return;
   ArraySetAsSeries(rates, true);

   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, copied, atr) <= 0) return;
   ArraySetAsSeries(atr, true);

   double eps = InpEpsilonPts * _Point;
   int added=0;

   for(int i=1; i<copied-2; i++) // éviter bar 0
   {
      datetime t_old = rates[i+2].time;
      datetime t_new = rates[i].time;
      datetime startTime = (t_old < t_new ? t_old : t_new);
      datetime endTime   = (t_old < t_new ? t_new : t_old);

      double minGap = atr[i] * InpMinGapATRPercent / 100.0;

      // Bullish: low[i] > high[i+2] + eps
      if( (rates[i].low - rates[i+2].high) > eps )
      {
         double rawTop = rates[i].low;
         double rawBot = rates[i+2].high;
         double top    = MathMax(rawTop, rawBot);
         double bottom = MathMin(rawTop, rawBot);
         double gapSz  = top - bottom;

         if(gapSz >= minGap)
         {
            FVGInfo fvg = CreateFVGInfo(rates[i+1].time, startTime, endTime, top, bottom, true, tf, gapSz);
            if(!ExistsFVG(fvg)) { AddFVGToList(fvg); added++; }
         }
      }
      // Bearish: low[i+2] > high[i] + eps
      else if( (rates[i+2].low - rates[i].high) > eps )
      {
         double rawTop = rates[i].high;
         double rawBot = rates[i+2].low;
         double top    = MathMax(rawTop, rawBot);
         double bottom = MathMin(rawTop, rawBot);
         double gapSz  = top - bottom;

         if(gapSz >= minGap)
         {
            FVGInfo fvg = CreateFVGInfo(rates[i+1].time, startTime, endTime, top, bottom, false, tf, gapSz);
            if(!ExistsFVG(fvg)) { AddFVGToList(fvg); added++; }
         }
      }
   }
   if(InpDebugMode) Print("FVG added: ", added, " total=", ArraySize(m_fvgList));
}

//+------------------------------------------------------------------+
//| Supprime les FVG pénétrés à >= X%                                |
//+------------------------------------------------------------------+
void UpdateAndInvalidateFVGs(ENUM_TIMEFRAMES tf)
{
   // Parcours: ne traite que les FVG encore valides
   for(int idx = 0; idx < ArraySize(m_fvgList); ++idx)
   {
      if(!m_fvgList[idx].IsValid) 
         continue;

      // Récup clés
      double top = m_fvgList[idx].top;
      double bot = m_fvgList[idx].bottom;

      // Normalisation bornes si inversées
      if(top < bot)
      {
         double tmp = top; 
         top = bot; 
         bot = tmp;
      }

      // Garde: hauteur strictement positive
      const double height = top - bot;
      if(height <= 0.0)
         continue;

      // Seuil d’invalidation (pénétration requise)
      const double threshold = height * InpInvalidatePct / 100.0;

      // Index MT5 de la bougie correspondant à endTime
      // true => retourne l'index de la première barre avec time <= endTime
      int endIdx = iBarShift(_Symbol, tf, m_fvgList[idx].endTime, true);
      if(endIdx == WRONG_VALUE) 
         continue;

      // Si endIdx <= 0, aucune bougie strictement postérieure à endTime
      if(endIdx <= 0) 
         continue;

      bool invalidate = false;

      // Balayage des bougies STRICTEMENT postérieures à endTime:
      // Série MT5: bar 0 = la plus récente, bar endIdx = à la frontière endTime,
      // donc on teste [0 .. endIdx-1].
      for(int k = 0; k < endIdx; ++k)
      {
         // Données bougie k
         double barLow   = iLow(_Symbol, tf, k);
         double barHigh  = iHigh(_Symbol, tf, k);
         double barClose = iClose(_Symbol, tf, k);

         if(InpInvalidateMode == WICK_TOUCH)
         {
            if(m_fvgList[idx].isBullish)
               invalidate = (barLow  <= (top - threshold));
            else
               invalidate = (barHigh >= (bot + threshold));
         }
         else // CLOSE_BODY
         {
            if(m_fvgList[idx].isBullish)
               invalidate = (barClose <= (top - threshold));
            else
               invalidate = (barClose >= (bot + threshold));
         }

         if(invalidate) 
            break;
      }

      if(invalidate)
      {
         m_fvgList[idx].IsValid = false;

         // Supprime l’objet graphique associé si présent
         string name = FVGObjectManager::GenerateName(m_fvgList[idx]);
         ObjectDelete(0, name);
      }
   }
}


//+------------------------------------------------------------------+
//| Limitation à la fenêtre d'affichage                              |
//+------------------------------------------------------------------+
void FilterFVGsByLookback(ENUM_TIMEFRAMES tf, int lookbackBars)
{
   if(lookbackBars <= 0) return;
   datetime tt[];
   int n = CopyTime(_Symbol, tf, 0, lookbackBars+1, tt);
   if(n < 1) return;
   ArraySetAsSeries(tt, true);
   datetime threshold = tt[MathMin(lookbackBars, n-1)];

   SortFVGsByTime(m_fvgList);

   FVGInfo kept[];
   for(int i=0;i<ArraySize(m_fvgList);i++)
   {
      if(m_fvgList[i].time >= threshold)
      {
         int k = ArraySize(kept);
         ArrayResize(kept, k+1);
         kept[k] = m_fvgList[i];
      }
   }
   ArrayResize(m_fvgList, 0);
   for(int i=0;i<ArraySize(kept);i++)
   {
      int k = ArraySize(m_fvgList);
      ArrayResize(m_fvgList, k+1);
      m_fvgList[k] = kept[i];
   }
}

//+------------------------------------------------------------------+
//| Dessin                                                           |
//+------------------------------------------------------------------+
void DrawAllFVGs()
{
   // Efface tout puis redessine selon l'état actuel
   DeleteOldFVGs();

   datetime lastBar = (g_lastTfBar > 0) ? g_lastTfBar : TimeCurrent();
   int drawn=0;
   for(int i=0;i<ArraySize(m_fvgList);i++)
   {
      // Ne dessiner que les FVG valides
      if(m_fvgList[i].IsValid)
         if(FVGObjectManager::DrawRectangle(m_fvgList[i], lastBar)) drawn++;
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
//| Utilitaires                                                      |
//+------------------------------------------------------------------+
FVGInfo CreateFVGInfo(datetime time, datetime startTime, datetime endTime, double top, double bottom, bool isBullish, ENUM_TIMEFRAMES tf, double gapSize)
{
   FVGInfo fvg;
   fvg.time=time; fvg.startTime=startTime; fvg.endTime=endTime;
   fvg.top=top; fvg.bottom=bottom; fvg.isBullish=isBullish;
   fvg.timeframe=tf; fvg.gapSize=gapSize;
   fvg.IsValid=true;  // initialiser comme valide
   return fvg;
}

void AddFVGToList(FVGInfo &fvg)
{
   int n = ArraySize(m_fvgList); ArrayResize(m_fvgList, n+1); m_fvgList[n]=fvg;
}

void SortFVGsByTime(FVGInfo &a[])
{
   int n = ArraySize(a); if(n<=1) return;
   for(int i=0;i<n-1;i++)
      for(int j=0;j<n-i-1;j++)
         if(a[j].time < a[j+1].time){ FVGInfo t=a[j]; a[j]=a[j+1]; a[j+1]=t; }
}

void DisplayFVGInfo()
{
   int bulls=0,bears=0,valid=0; 
   for(int i=0;i<ArraySize(m_fvgList);i++) 
   {
      if(m_fvgList[i].isBullish) bulls++; else bears++;
      if(m_fvgList[i].IsValid) valid++;
   }
   string info = "=== FVG INDICATOR ===\n";
   info += StringFormat("%s: %d zones (↑%d ↓%d) - Valides: %d\n", 
                        EnumToString(InpTimeframe), ArraySize(m_fvgList), bulls, bears, valid);
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

bool ExistsFVG(const FVGInfo &x)
{
   long xt1=(long)x.startTime, xt2=(long)x.endTime;
   long xtop=(long)MathRound(x.top/_Point), xbot=(long)MathRound(x.bottom/_Point);
   for(int k=0;k<ArraySize(m_fvgList);k++)
   {
      FVGInfo y=m_fvgList[k];
      if((long)y.startTime==xt1 && (long)y.endTime==xt2 &&
         (long)MathRound(y.top/_Point)==xtop &&
         (long)MathRound(y.bottom/_Point)==xbot && y.isBullish==x.isBullish)
         return true;
   }
   return false;
}

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
