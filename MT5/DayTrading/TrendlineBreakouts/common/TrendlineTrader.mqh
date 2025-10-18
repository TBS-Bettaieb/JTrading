//+------------------------------------------------------------------+
//| TrendlineTrader.mqh - Main orchestrator class                    |
//| Coordinates all components and executes trades                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include "detectors/PivotDetector.mqh"
#include "detectors/TrendlineDetector.mqh"
#include "detectors/BreakoutDetector.mqh"
#include "filters/VolatilityFilter.mqh"
#include "managers/TrendlineManager.mqh"

//+------------------------------------------------------------------+
//| Main trader class                                                |
//+------------------------------------------------------------------+
class TrendlineTrader
{
private:
   // Configuration
   string m_symbol;
   int m_magicNumber;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Components (injected dependencies)
   PivotDetector* m_pivotDetector;
   TrendlineDetector* m_trendlineDetector;
   BreakoutDetector* m_breakoutDetector;
   VolatilityFilter* m_volatilityFilter;
   TrendlineManager* m_trendlineManager;
   
   // Trade settings
   double m_lotSize;
   int m_slippage;
   bool m_showTargets;
   int m_extension;
   color m_lineColor;
   
   // State tracking
   bool m_tradeIsOn;
   bool m_isLongTrade;
   double m_currentTP;
   double m_currentSL;
   datetime m_lastBarTime;
   
   // Trade execution
   CTrade m_trade;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TrendlineTrader(
      string symbol,
      int magicNumber,
      ENUM_TIMEFRAMES timeframe,
      int period,
      bool useWicks,
      int extension,
      double lotSize,
      int slippage,
      bool showTargets,
      color lineColor = clrGray
   )
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      m_lotSize = lotSize;
      m_slippage = slippage;
      m_showTargets = showTargets;
      m_extension = extension;
      m_lineColor = lineColor;
      
      // Initialize state
      m_tradeIsOn = false;
      m_isLongTrade = false;
      m_currentTP = 0;
      m_currentSL = 0;
      m_lastBarTime = 0;
      
      // Create components
      m_pivotDetector = new PivotDetector(symbol, timeframe, period, useWicks);
      m_trendlineDetector = new TrendlineDetector(symbol, timeframe);
      m_breakoutDetector = new BreakoutDetector(symbol, timeframe, m_trendlineDetector);
      m_volatilityFilter = new VolatilityFilter(symbol, timeframe, 30);
      m_trendlineManager = new TrendlineManager(symbol, extension, lineColor);
      
      // Configure trade object
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
      m_trade.SetAsyncMode(false);
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~TrendlineTrader()
   {
      if(m_pivotDetector != NULL) delete m_pivotDetector;
      if(m_trendlineDetector != NULL) delete m_trendlineDetector;
      if(m_breakoutDetector != NULL) delete m_breakoutDetector;
      if(m_volatilityFilter != NULL) delete m_volatilityFilter;
      if(m_trendlineManager != NULL) delete m_trendlineManager;
   }

   //+------------------------------------------------------------------+
   //| Initialize all components                                        |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      Print("═══════════════════════════════════════");
      Print("🚀 Initializing Trendline Trader");
      Print("═══════════════════════════════════════");
      
      // Initialize pivot detector
      if(!m_pivotDetector.Initialize())
      {
         Print("❌ Failed to initialize PivotDetector");
         return false;
      }
      
      // Initialize trendline detector
      if(!m_trendlineDetector.Initialize())
      {
         Print("❌ Failed to initialize TrendlineDetector");
         return false;
      }
      
      // Initialize breakout detector
      if(!m_breakoutDetector.Initialize())
      {
         Print("❌ Failed to initialize BreakoutDetector");
         return false;
      }
      
      // Initialize volatility filter
      if(!m_volatilityFilter.Initialize())
      {
         Print("❌ Failed to initialize VolatilityFilter");
         return false;
      }
      
      Print("✅ All components initialized successfully");
      Print("Symbol: ", m_symbol);
      Print("Magic Number: ", m_magicNumber);
      Print("Lot Size: ", m_lotSize);
      Print("═══════════════════════════════════════");
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| Main tick handler                                               |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // Check for new bar
      if(IsNewBar())
      {
         OnNewBar();
      }
      
      // Update volatility filter (needed for Zband)
      m_volatilityFilter.Update();
      
      // Update breakout detector with latest Zband
      m_breakoutDetector.SetZband(m_volatilityFilter.GetZband());
      
      // Check for signals if no trade is open
      if(!m_tradeIsOn)
      {
         CheckSignals();
      }
      else
      {
         // Manage open trade
         ManageTrade();
      }
   }

   //+------------------------------------------------------------------+
   //| New bar handler                                                 |
   //+------------------------------------------------------------------+
   void OnNewBar()
   {
      Print("📊 New bar detected - Updating components");
      
      // 1. Update pivot detector
      m_pivotDetector.Update();
      
      // 2. If new pivot high detected, update upper trendline
      if(m_pivotDetector.IsNewPivotHigh())
      {
         double pivotHigh = m_pivotDetector.GetPivotHigh();
         int pivotBar = m_pivotDetector.GetPivotHighBar();
         
         m_trendlineDetector.UpdateUpperTrendline(pivotHigh, pivotBar);
         
         // Draw trendline if no trade is open
         if(!m_tradeIsOn && m_trendlineDetector.IsUpperSlopeValid())
         {
            TrendlineData td = m_trendlineDetector.GetUpperTrendline();
            m_trendlineManager.DrawUpperTrendline(td);
         }
      }
      
      // 3. If new pivot low detected, update lower trendline
      if(m_pivotDetector.IsNewPivotLow())
      {
         double pivotLow = m_pivotDetector.GetPivotLow();
         int pivotBar = m_pivotDetector.GetPivotLowBar();
         
         m_trendlineDetector.UpdateLowerTrendline(pivotLow, pivotBar);
         
         // Draw trendline if no trade is open
         if(!m_tradeIsOn && m_trendlineDetector.IsLowerSlopeValid())
         {
            TrendlineData td = m_trendlineDetector.GetLowerTrendline();
            m_trendlineManager.DrawLowerTrendline(td);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Check for trading signals                                       |
   //+------------------------------------------------------------------+
   void CheckSignals()
   {
      // Check for buy signal (breakout above resistance)
      if(m_breakoutDetector.HasBuySignal())
      {
         ExecuteBuySignal();
      }
      
      // Check for sell signal (breakout below support)
      if(m_breakoutDetector.HasSellSignal())
      {
         ExecuteSellSignal();
      }
   }

   //+------------------------------------------------------------------+
   //| Execute buy signal                                              |
   //+------------------------------------------------------------------+
   void ExecuteBuySignal()
   {
      Print("🟢 BUY SIGNAL DETECTED");
      
      double zband = m_volatilityFilter.GetZband();
      double high = iHigh(m_symbol, m_timeframe, 0);
      double low = iLow(m_symbol, m_timeframe, 0);
      
      // Calculate TP and SL
      m_currentTP = high + (zband * 20);
      m_currentSL = low - (zband * 20);
      
      // Send order
      if(SendOrder(true))
      {
         m_tradeIsOn = true;
         m_isLongTrade = true;
         
         // Draw SL/TP lines
         m_trendlineManager.DrawSLTPLines(m_currentSL, m_currentTP);
         
         // Draw signal arrow
         datetime time0 = iTime(m_symbol, m_timeframe, 0);
         m_trendlineManager.DrawSignalArrow(true, time0, low);
         
         // Draw target line if enabled
         if(m_showTargets)
         {
            m_trendlineManager.DrawTargetLine(true, high, m_currentTP);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Execute sell signal                                             |
   //+------------------------------------------------------------------+
   void ExecuteSellSignal()
   {
      Print("🔴 SELL SIGNAL DETECTED");
      
      double zband = m_volatilityFilter.GetZband();
      double high = iHigh(m_symbol, m_timeframe, 0);
      double low = iLow(m_symbol, m_timeframe, 0);
      
      // Calculate TP and SL
      m_currentTP = low - (zband * 20);
      m_currentSL = high + (zband * 20);
      
      // Send order
      if(SendOrder(false))
      {
         m_tradeIsOn = true;
         m_isLongTrade = false;
         
         // Draw SL/TP lines
         m_trendlineManager.DrawSLTPLines(m_currentSL, m_currentTP);
         
         // Draw signal arrow
         datetime time0 = iTime(m_symbol, m_timeframe, 0);
         m_trendlineManager.DrawSignalArrow(false, time0, high);
         
         // Draw target line if enabled
         if(m_showTargets)
         {
            m_trendlineManager.DrawTargetLine(false, low, m_currentTP);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Send order to broker                                            |
   //+------------------------------------------------------------------+
   bool SendOrder(bool isLong)
   {
      double price = isLong ? 
         SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
         SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double tp = NormalizeDouble(m_currentTP, digits);
      double sl = NormalizeDouble(m_currentSL, digits);
      
      bool result = false;
      if(isLong)
      {
         result = m_trade.Buy(m_lotSize, m_symbol, price, sl, tp, "TBT Long");
      }
      else
      {
         result = m_trade.Sell(m_lotSize, m_symbol, price, sl, tp, "TBT Short");
      }
      
      if(result)
      {
         Print("✅ Order executed: ", isLong ? "BUY" : "SELL", 
               " | Price: ", price, " | SL: ", sl, " | TP: ", tp);
      }
      else
      {
         Print("❌ Order failed! Error: ", GetLastError(), 
               " | Return code: ", m_trade.ResultRetcode());
      }
      
      return result;
   }

   //+------------------------------------------------------------------+
   //| Manage open trade                                               |
   //+------------------------------------------------------------------+
   void ManageTrade()
   {
      double high = iHigh(m_symbol, m_timeframe, 0);
      double low = iLow(m_symbol, m_timeframe, 0);
      double close = iClose(m_symbol, m_timeframe, 0);
      
      // Update SL/TP line positions
      m_trendlineManager.UpdateSLTPLines(m_currentSL, m_currentTP);
      
      // Check for TP or SL hit
      if(m_isLongTrade)
      {
         if(high >= m_currentTP)
         {
            Print("✅ Long Trade closed at TP: ", m_currentTP);
            m_tradeIsOn = false;
            m_trendlineManager.ClearSLTPLines();
         }
         else if(close <= m_currentSL)
         {
            Print("❌ Long Trade closed at SL: ", m_currentSL);
            m_tradeIsOn = false;
            m_trendlineManager.ClearSLTPLines();
         }
      }
      else // Short trade
      {
         if(low <= m_currentTP)
         {
            Print("✅ Short Trade closed at TP: ", m_currentTP);
            m_tradeIsOn = false;
            m_trendlineManager.ClearSLTPLines();
         }
         else if(close >= m_currentSL)
         {
            Print("❌ Short Trade closed at SL: ", m_currentSL);
            m_tradeIsOn = false;
            m_trendlineManager.ClearSLTPLines();
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Check if new bar                                                |
   //+------------------------------------------------------------------+
   bool IsNewBar()
   {
      datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
      if(currentBarTime != m_lastBarTime)
      {
         m_lastBarTime = currentBarTime;
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Getters for monitoring                                          |
   //+------------------------------------------------------------------+
   bool IsTradeOpen() const { return m_tradeIsOn; }
   bool IsLongTrade() const { return m_isLongTrade; }
   double GetCurrentTP() const { return m_currentTP; }
   double GetCurrentSL() const { return m_currentSL; }
   double GetZband() const { return m_volatilityFilter.GetZband(); }
};
