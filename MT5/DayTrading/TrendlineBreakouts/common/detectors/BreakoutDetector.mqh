//+------------------------------------------------------------------+
//| BreakoutDetector.mqh                                             |
//| Detect price breakouts of trendlines                            |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "ISignalDetector.mqh"
#include "TrendlineDetector.mqh"

//+------------------------------------------------------------------+
//| Breakout detector class                                          |
//+------------------------------------------------------------------+
class BreakoutDetector : public ISignalDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   TrendlineDetector* m_trendlineDetector;  // Injected dependency
   
   double m_zband;  // Volatility buffer
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   BreakoutDetector(string symbol, ENUM_TIMEFRAMES timeframe, 
                    TrendlineDetector* trendlineDetector)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_trendlineDetector = trendlineDetector;
      m_zband = 0;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Initialize detector                                              |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      if(m_trendlineDetector == NULL)
      {
         Print("❌ BreakoutDetector: TrendlineDetector is NULL");
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ BreakoutDetector initialized: ", m_symbol);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Update detector (not used - real-time detection)               |
   //+------------------------------------------------------------------+
   void Update() override
   {
      // Breakout detection is done in real-time in HasBuySignal/HasSellSignal
   }

   //+------------------------------------------------------------------+
   //| Check for BUY signal (price crosses above resistance)          |
   //+------------------------------------------------------------------+
   bool HasBuySignal() override
   {
      if(!m_isInitialized) return false;
      if(!m_trendlineDetector.IsUpperSlopeValid()) return false;
      
      // Get current and previous prices
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      double prevPrice = iClose(m_symbol, m_timeframe, 1);
      
      // Get trendline prices at current and previous bars
      double currentLine = m_trendlineDetector.GetUpperLinePrice();
      
      // Calculate previous line price manually
      TrendlineData td = m_trendlineDetector.GetUpperTrendline();
      datetime startTime = iTime(m_symbol, m_timeframe, td.startBar);
      datetime prevTime = iTime(m_symbol, m_timeframe, 1);
      long timeDiff = (long)(prevTime - startTime);
      double prevLine = td.startPrice + timeDiff * td.slope;
      
      // Check for crossover: price was below line, now above
      bool crossover = (prevPrice < prevLine) && (currentPrice > currentLine);
      
      if(crossover)
      {
         Print("🟢 BUY Signal: Price crossed above resistance trendline");
         Print("   Current Price: ", currentPrice, " | Line Price: ", currentLine);
         return true;
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| Check for SELL signal (price crosses below support)            |
   //+------------------------------------------------------------------+
   bool HasSellSignal() override
   {
      if(!m_isInitialized) return false;
      if(!m_trendlineDetector.IsLowerSlopeValid()) return false;
      
      // Get current and previous prices
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      double prevPrice = iClose(m_symbol, m_timeframe, 1);
      
      // Get trendline prices at current and previous bars
      double currentLine = m_trendlineDetector.GetLowerLinePrice();
      
      // Calculate previous line price manually
      TrendlineData td = m_trendlineDetector.GetLowerTrendline();
      datetime startTime = iTime(m_symbol, m_timeframe, td.startBar);
      datetime prevTime = iTime(m_symbol, m_timeframe, 1);
      long timeDiff = (long)(prevTime - startTime);
      double prevLine = td.startPrice + timeDiff * td.slope;
      
      // Apply Zband buffer for SELL signals (from original logic)
      double zbandAdjustment = m_zband * 0.1;
      
      // Check for crossunder: price was above line, now below (with buffer)
      bool crossunder = (prevPrice > prevLine - zbandAdjustment) && 
                        (currentPrice < currentLine - zbandAdjustment);
      
      if(crossunder)
      {
         Print("🔴 SELL Signal: Price crossed below support trendline");
         Print("   Current Price: ", currentPrice, " | Line Price: ", currentLine);
         Print("   Zband Buffer: ", zbandAdjustment);
         return true;
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| Set Zband value (updated from VolatilityFilter)                |
   //+------------------------------------------------------------------+
   void SetZband(double zband)
   {
      m_zband = zband;
   }

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
   double GetZband() const { return m_zband; }
   bool IsInitialized() override { return m_isInitialized; }
};
