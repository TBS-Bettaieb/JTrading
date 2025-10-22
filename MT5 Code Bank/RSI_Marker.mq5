//+------------------------------------------------------------------+
//|                                                  RSI_Marker.mq5 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "RSI Marker EA"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- plot RSI
#property indicator_label1  "RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input parameters
input int      RSI_Period = 14;           // Période RSI
input ENUM_APPLIED_PRICE RSI_Price = PRICE_CLOSE; // Prix appliqué
input double   Level_Upper = 70.0;        // Niveau supérieur
input double   Level_Lower = 30.0;        // Niveau inférieur
input color    Circle_Color_Upper = clrRed;    // Couleur cercle niveau haut
input color    Circle_Color_Lower = clrLime;   // Couleur cercle niveau bas
input int      Circle_Size = 3;           // Taille des cercles

//--- indicator buffers
double RSIBuffer[];

//--- RSI handle
int rsi_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, RSIBuffer, INDICATOR_DATA);
   
   //--- Create RSI indicator
   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, RSI_Price);
   if(rsi_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du RSI");
      return(INIT_FAILED);
   }
   
   //--- Set indicator levels
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, Level_Upper);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, Level_Lower);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);
   
   //--- Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   //--- Set min/max for indicator window
   IndicatorSetDouble(INDICATOR_MINIMUM, 0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 100);
   
   return(INIT_SUCCEEDED);
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
   //--- Check if we have enough bars
   if(rates_total < RSI_Period)
      return(0);
   
   //--- Copy RSI values
   int to_copy;
   int start;
   
   if(prev_calculated == 0)
   {
      to_copy = rates_total;
      start = 0;
   }
   else
   {
      to_copy = rates_total - prev_calculated + 1;
      start = prev_calculated - 1;
   }
   
   if(CopyBuffer(rsi_handle, 0, 0, to_copy, RSIBuffer) <= 0)
   {
      Print("Erreur lors de la copie des données RSI");
      return(0);
   }
   
   //--- Draw circles on level crosses
   for(int i = start; i < rates_total - 1; i++)
   {
      // Check if RSI crosses upper level
      if(RSIBuffer[i] > Level_Upper && RSIBuffer[i-1] <= Level_Upper)
      {
         DrawCircle(time[i], RSIBuffer[i], Circle_Color_Upper, i);
      }
      
      // Check if RSI crosses lower level
      if(RSIBuffer[i] < Level_Lower && RSIBuffer[i-1] >= Level_Lower)
      {
         DrawCircle(time[i], RSIBuffer[i], Circle_Color_Lower, i);
      }
      
      // Check if RSI is above upper level
      if(RSIBuffer[i] >= Level_Upper)
      {
         DrawCircle(time[i], RSIBuffer[i], Circle_Color_Upper, i);
      }
      
      // Check if RSI is below lower level
      if(RSIBuffer[i] <= Level_Lower)
      {
         DrawCircle(time[i], RSIBuffer[i], Circle_Color_Lower, i);
      }
   }
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Draw circle on RSI curve                                         |
//+------------------------------------------------------------------+
void DrawCircle(datetime time, double value, color clr, int index)
{
   string obj_name = "RSI_Circle_" + IntegerToString(index) + "_" + TimeToString(time);
   
   //--- Delete old object if exists
   if(ObjectFind(0, obj_name) >= 0)
      ObjectDelete(0, obj_name);
   
   //--- Create circle object
   if(ObjectCreate(0, obj_name, OBJ_ARROW, ChartWindowFind(), time, value))
   {
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, 159); // Circle symbol
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, Circle_Size);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release RSI handle
   if(rsi_handle != INVALID_HANDLE)
      IndicatorRelease(rsi_handle);
   
   //--- Delete all circle objects
   int total = ObjectsTotal(0, 0, OBJ_ARROW);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_ARROW);
      if(StringFind(name, "RSI_Circle_") >= 0)
         ObjectDelete(0, name);
   }
   
   ChartRedraw();
}
//+------------------------------------------------------------------+