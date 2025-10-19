//+------------------------------------------------------------------+
//| VolatilityFilter.mqh                                             |
//| Calculate Zband (volatility adjustment) using ATR               |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "IFilter.mqh"

//+------------------------------------------------------------------+
//| Volatility filter class                                          |
//+------------------------------------------------------------------+
class VolatilityFilter : public IFilter
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_atrPeriod;
   int m_atrHandle;
   double m_currentZband;
   double m_currentATR;
   bool m_isInitialized;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   VolatilityFilter(string symbol, ENUM_TIMEFRAMES timeframe, int atrPeriod = 30)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_atrPeriod = atrPeriod;
      m_atrHandle = INVALID_HANDLE;
      m_currentZband = 0.01;
      m_currentATR = 0;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~VolatilityFilter()
   {
      Release();
   }

   //+------------------------------------------------------------------+
   //| Initialize filter                                                |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      m_atrHandle = iATR(m_symbol, m_timeframe, m_atrPeriod);
      
      if(m_atrHandle == INVALID_HANDLE)
      {
         Print("❌ VolatilityFilter: Failed to create ATR handle");
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ VolatilityFilter initialized: ", m_symbol, " | ATR Period: ", m_atrPeriod);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Update Zband value                                              |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!m_isInitialized) return;
      
      double buffer[];
      ArraySetAsSeries(buffer, true);
      
      if(CopyBuffer(m_atrHandle, 0, 20, 1, buffer) > 0)
      {
         m_currentATR = buffer[0];
      }
      
      double close_price = iClose(m_symbol, m_timeframe, 0);
      double value = MathMin(m_currentATR * 0.3, close_price * (0.3 / 100.0));
      
      m_currentZband = value / 2.0;
   }

   //+------------------------------------------------------------------+
   //| Filter is always passed (this is a value provider)             |
   //+------------------------------------------------------------------+
   bool IsFilterPassed() override
   {
      return true; // This filter provides values, doesn't filter signals
   }

   //+------------------------------------------------------------------+
   //| Getters                                                         |
   //+------------------------------------------------------------------+
   double GetZband() const { return m_currentZband; }
   double GetATR() const { return m_currentATR; }
   double GetFilterValue() override { return m_currentZband; }
   bool IsInitialized() override { return m_isInitialized; }

   //+------------------------------------------------------------------+
   //| Release resources                                               |
   //+------------------------------------------------------------------+
   void Release() override
   {
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }
};
