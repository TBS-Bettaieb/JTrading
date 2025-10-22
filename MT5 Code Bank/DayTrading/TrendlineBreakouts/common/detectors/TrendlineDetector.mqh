//+------------------------------------------------------------------+
//| TrendlineDetector.mqh                                            |
//| Calculate and track trendline parameters                        |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "ISignalDetector.mqh"

//+------------------------------------------------------------------+
//| Trendline data structure                                        |
//+------------------------------------------------------------------+
struct TrendlineData
{
   int startBar;
   double startPrice;
   double slope;
   datetime startTime;
   bool isValid;
};

//+------------------------------------------------------------------+
//| Trendline detector class                                        |
//+------------------------------------------------------------------+
class TrendlineDetector : public ISignalDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   TrendlineData m_upperTrendline;  // Resistance (from pivot highs)
   TrendlineData m_lowerTrendline;  // Support (from pivot lows)
   
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TrendlineDetector(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_isInitialized = false;
      
      // Initialize trendline data
      m_upperTrendline.startBar = 0;
      m_upperTrendline.startPrice = 0;
      m_upperTrendline.slope = 0;
      m_upperTrendline.startTime = 0;
      m_upperTrendline.isValid = false;
      
      m_lowerTrendline.startBar = 0;
      m_lowerTrendline.startPrice = 0;
      m_lowerTrendline.slope = 0;
      m_lowerTrendline.startTime = 0;
      m_lowerTrendline.isValid = false;
   }

   //+------------------------------------------------------------------+
   //| Initialize detector                                              |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      m_isInitialized = true;
      Print("✅ TrendlineDetector initialized: ", m_symbol);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Update trendlines (call when new pivots detected)              |
   //+------------------------------------------------------------------+
   void Update() override
   {
      // This will be called from main trader when new pivots are detected
      // Actual update is done via UpdateUpperTrendline/UpdateLowerTrendline
   }

   //+------------------------------------------------------------------+
   //| Update upper trendline from pivot high                         |
   //+------------------------------------------------------------------+
   void UpdateUpperTrendline(double pivotHigh, int pivotBar)
   {
      m_upperTrendline.startBar = pivotBar;
      m_upperTrendline.startPrice = pivotHigh;
      m_upperTrendline.startTime = iTime(m_symbol, m_timeframe, pivotBar);
      
      // Calculate slope to current bar
      double currentPrice = iHigh(m_symbol, m_timeframe, 0);
      datetime currentTime = iTime(m_symbol, m_timeframe, 0);
      
      long timeDiff = (long)(currentTime - m_upperTrendline.startTime);
      if(timeDiff != 0)
         m_upperTrendline.slope = (currentPrice - m_upperTrendline.startPrice) / (double)timeDiff;
      else
         m_upperTrendline.slope = 0;
      
      // Validate: upper trendline should have negative slope (resistance)
      m_upperTrendline.isValid = (m_upperTrendline.slope <= 0);
      
      if(m_upperTrendline.isValid)
         Print("📈 Upper trendline updated | Slope: ", m_upperTrendline.slope);
   }

   //+------------------------------------------------------------------+
   //| Update lower trendline from pivot low                          |
   //+------------------------------------------------------------------+
   void UpdateLowerTrendline(double pivotLow, int pivotBar)
   {
      m_lowerTrendline.startBar = pivotBar;
      m_lowerTrendline.startPrice = pivotLow;
      m_lowerTrendline.startTime = iTime(m_symbol, m_timeframe, pivotBar);
      
      // Calculate slope to current bar
      double currentPrice = iLow(m_symbol, m_timeframe, 0);
      datetime currentTime = iTime(m_symbol, m_timeframe, 0);
      
      long timeDiff = (long)(currentTime - m_lowerTrendline.startTime);
      if(timeDiff != 0)
         m_lowerTrendline.slope = (currentPrice - m_lowerTrendline.startPrice) / (double)timeDiff;
      else
         m_lowerTrendline.slope = 0;
      
      // Validate: lower trendline should have positive slope (support)
      m_lowerTrendline.isValid = (m_lowerTrendline.slope >= 0);
      
      if(m_lowerTrendline.isValid)
         Print("📉 Lower trendline updated | Slope: ", m_lowerTrendline.slope);
   }

   //+------------------------------------------------------------------+
   //| Get line price at current bar                                  |
   //+------------------------------------------------------------------+
   double GetUpperLinePrice()
   {
      if(!m_upperTrendline.isValid) return 0;
      
      datetime startTime = iTime(m_symbol, m_timeframe, m_upperTrendline.startBar);
      datetime currentTime = iTime(m_symbol, m_timeframe, 0);
      long timeDiff = (long)(currentTime - startTime);
      
      return m_upperTrendline.startPrice + timeDiff * m_upperTrendline.slope;
   }

   double GetLowerLinePrice()
   {
      if(!m_lowerTrendline.isValid) return 0;
      
      datetime startTime = iTime(m_symbol, m_timeframe, m_lowerTrendline.startBar);
      datetime currentTime = iTime(m_symbol, m_timeframe, 0);
      long timeDiff = (long)(currentTime - startTime);
      
      return m_lowerTrendline.startPrice + timeDiff * m_lowerTrendline.slope;
   }

   //+------------------------------------------------------------------+
   //| Not used for trendline detection                                |
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
   TrendlineData GetUpperTrendline() const { return m_upperTrendline; }
   TrendlineData GetLowerTrendline() const { return m_lowerTrendline; }
   bool IsUpperSlopeValid() const { return m_upperTrendline.isValid; }
   bool IsLowerSlopeValid() const { return m_lowerTrendline.isValid; }
   bool IsInitialized() override { return m_isInitialized; }
};
