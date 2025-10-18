//+------------------------------------------------------------------+
//| PivotDetector.mqh                                                |
//| Detects Pivot Highs and Pivot Lows                              |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "ISignalDetector.mqh"

//+------------------------------------------------------------------+
//| Pivot detector class                                             |
//+------------------------------------------------------------------+
class PivotDetector : public ISignalDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_period;
   bool m_useWicks;           // true=Wicks, false=Body
   
   double m_lastPivotHigh;
   double m_lastPivotLow;
   int m_pivotHighBar;
   int m_pivotLowBar;
   
   double m_prevPivotHigh;    // Track previous to detect new pivots
   double m_prevPivotLow;
   
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   PivotDetector(string symbol, ENUM_TIMEFRAMES timeframe, int period, bool useWicks)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_period = period;
      m_useWicks = useWicks;
      
      m_lastPivotHigh = 0;
      m_lastPivotLow = 0;
      m_pivotHighBar = 0;
      m_pivotLowBar = 0;
      m_prevPivotHigh = 0;
      m_prevPivotLow = 0;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Initialize detector                                              |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      // Validate symbol
      if(!SymbolSelect(m_symbol, true))
      {
         Print("❌ PivotDetector: Invalid symbol ", m_symbol);
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ PivotDetector initialized: ", m_symbol, " | Period: ", m_period, 
            " | Type: ", m_useWicks ? "Wicks" : "Body");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Update pivot values on new bar                                   |
   //| Call this method when a new bar is detected                      |
   //| Updates both pivot high and pivot low values                     |
   //|                                                                  |
   //| @return void                                                     |
   //|                                                                  |
   //| @example                                                         |
   //|   if(IsNewBar()) {                                               |
   //|       detector.Update();                                         |
   //|       if(detector.IsNewPivotHigh()) {                            |
   //|           // Handle new pivot...                                 |
   //|       }                                                          |
   //|   }                                                              |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!m_isInitialized) return;
      
      int leftBars = m_period;
      int rightBars = m_period / 2;
      
      // Calculate new pivot high
      double ph = CalculatePivotHigh(m_useWicks, leftBars, rightBars);
      if(ph != 0.0 && ph != m_prevPivotHigh)
      {
         m_lastPivotHigh = ph;
         m_pivotHighBar = rightBars;
         m_prevPivotHigh = ph;
      }
      
      // Calculate new pivot low
      double pl = CalculatePivotLow(m_useWicks, leftBars, rightBars);
      if(pl != 0.0 && pl != m_prevPivotLow)
      {
         m_lastPivotLow = pl;
         m_pivotLowBar = rightBars;
         m_prevPivotLow = pl;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Pivot High using left/right bar analysis              |
   //| Determines if the center bar is higher than surrounding bars    |
   //|                                                                  |
   //| @param useWicks - true=use high/low wicks, false=use body       |
   //| @param leftBars - number of bars to check on the left side      |
   //| @param rightBars - number of bars to check on the right side    |
   //|                                                                  |
   //| @return double - pivot high price or 0.0 if no pivot found     |
   //|                                                                  |
   //| @note Returns 0.0 if insufficient bars or no valid pivot       |
   //+------------------------------------------------------------------+
   double CalculatePivotHigh(bool useWicks, int leftBars, int rightBars)
   {
      if(Bars(m_symbol, m_timeframe) < leftBars + rightBars + 1)
         return 0.0;
      
      int centerBar = rightBars;
      double centerValue = useWicks ? 
         iHigh(m_symbol, m_timeframe, centerBar) : 
         MathMax(iClose(m_symbol, m_timeframe, centerBar), 
                 iOpen(m_symbol, m_timeframe, centerBar));
      
      // Check left side
      for(int i = 1; i <= leftBars; i++)
      {
         double value = useWicks ? 
            iHigh(m_symbol, m_timeframe, centerBar + i) : 
            MathMax(iClose(m_symbol, m_timeframe, centerBar + i), 
                    iOpen(m_symbol, m_timeframe, centerBar + i));
         if(value >= centerValue)
            return 0.0;
      }
      
      // Check right side
      for(int i = 1; i <= rightBars; i++)
      {
         double value = useWicks ? 
            iHigh(m_symbol, m_timeframe, centerBar - i) : 
            MathMax(iClose(m_symbol, m_timeframe, centerBar - i), 
                    iOpen(m_symbol, m_timeframe, centerBar - i));
         if(value > centerValue)
            return 0.0;
      }
      
      return centerValue;
   }

   //+------------------------------------------------------------------+
   //| Calculate Pivot Low                                             |
   //+------------------------------------------------------------------+
   double CalculatePivotLow(bool useWicks, int leftBars, int rightBars)
   {
      if(Bars(m_symbol, m_timeframe) < leftBars + rightBars + 1)
         return 0.0;
      
      int centerBar = rightBars;
      double centerValue = useWicks ? 
         iLow(m_symbol, m_timeframe, centerBar) : 
         MathMin(iClose(m_symbol, m_timeframe, centerBar), 
                 iOpen(m_symbol, m_timeframe, centerBar));
      
      // Check left side
      for(int i = 1; i <= leftBars; i++)
      {
         double value = useWicks ? 
            iLow(m_symbol, m_timeframe, centerBar + i) : 
            MathMin(iClose(m_symbol, m_timeframe, centerBar + i), 
                    iOpen(m_symbol, m_timeframe, centerBar + i));
         if(value <= centerValue)
            return 0.0;
      }
      
      // Check right side
      for(int i = 1; i <= rightBars; i++)
      {
         double value = useWicks ? 
            iLow(m_symbol, m_timeframe, centerBar - i) : 
            MathMin(iClose(m_symbol, m_timeframe, centerBar - i), 
                    iOpen(m_symbol, m_timeframe, centerBar - i));
         if(value < centerValue)
            return 0.0;
      }
      
      return centerValue;
   }

   //+------------------------------------------------------------------+
   //| Not used for pivot detection                                    |
   //+------------------------------------------------------------------+
   bool HasBuySignal() override { return false; }
   bool HasSellSignal() override { return false; }

   //+------------------------------------------------------------------+
   //| Release resources                                               |
   //+------------------------------------------------------------------+
   void Release() override
   {
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Getters                                                         |
   //+------------------------------------------------------------------+
   double GetPivotHigh() const { return m_lastPivotHigh; }
   double GetPivotLow() const { return m_lastPivotLow; }
   int GetPivotHighBar() const { return m_pivotHighBar; }
   int GetPivotLowBar() const { return m_pivotLowBar; }
   bool IsNewPivotHigh() const { return m_lastPivotHigh != m_prevPivotHigh; }
   bool IsNewPivotLow() const { return m_lastPivotLow != m_prevPivotLow; }
   bool IsInitialized() override { return m_isInitialized; }
};
