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
      // ═══ VALIDATE AND SANITIZE INPUTS ═══
      
      if(symbol == "" || symbol == NULL)
      {
         Print("⚠️ Invalid symbol provided, using current symbol");
         symbol = _Symbol;
      }
      
      if(magicNumber <= 0)
      {
         Print("⚠️ Invalid magic number (", magicNumber, "), using 12345");
         magicNumber = 12345;
      }
      
      if(period < 2 || period > 100)
      {
         Print("⚠️ Invalid period (", period, "), using 10");
         period = 10;
      }
      
      if(extension < 10 || extension > 100)
      {
         Print("⚠️ Invalid extension (", extension, "), using 25");
         extension = 25;
      }
      
      if(lotSize <= 0 || lotSize > 100)
      {
         Print("⚠️ Invalid lot size (", lotSize, "), using 0.01");
         lotSize = 0.01;
      }
      
      if(slippage < 0 || slippage > 100)
      {
         Print("⚠️ Invalid slippage (", slippage, "), using 10");
         slippage = 10;
      }
      
      // Assign validated values
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
   //| Initialize all components with proper error handling             |
   //| Sets up all detectors, filters, and managers                     |
   //| Implements rollback on any initialization failure                |
   //|                                                                  |
   //| @return bool - true if all components initialized successfully   |
   //|                                                                  |
   //| @note Automatically cleans up components if any initialization   |
   //|       fails to prevent memory leaks                              |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      Print("═══════════════════════════════════════");
      Print("🚀 Initializing Trendline Trader");
      Print("═══════════════════════════════════════");
      
      // Track initialization status for each component
      bool pivotOK = false;
      bool trendlineOK = false;
      bool breakoutOK = false;
      bool volatilityOK = false;
      
      // Initialize all components and track success
      pivotOK = m_pivotDetector.Initialize();
      if(!pivotOK) 
         Print("❌ Failed to initialize PivotDetector");
      
      trendlineOK = m_trendlineDetector.Initialize();
      if(!trendlineOK) 
         Print("❌ Failed to initialize TrendlineDetector");
      
      breakoutOK = m_breakoutDetector.Initialize();
      if(!breakoutOK) 
         Print("❌ Failed to initialize BreakoutDetector");
      
      volatilityOK = m_volatilityFilter.Initialize();
      if(!volatilityOK) 
         Print("❌ Failed to initialize VolatilityFilter");
      
      // Check if all components initialized successfully
      bool allSuccess = pivotOK && trendlineOK && breakoutOK && volatilityOK;
      
      if(!allSuccess)
      {
         Print("═══════════════════════════════════════");
         Print("❌ Initialization failed - Cleaning up");
         Print("═══════════════════════════════════════");
         
         // Cleanup any successfully initialized components
         if(pivotOK && m_pivotDetector != NULL)
            m_pivotDetector.Release();
         
         if(trendlineOK && m_trendlineDetector != NULL)
            m_trendlineDetector.Release();
         
         if(breakoutOK && m_breakoutDetector != NULL)
            m_breakoutDetector.Release();
         
         if(volatilityOK && m_volatilityFilter != NULL)
            m_volatilityFilter.Release();
         
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
   //| Main tick handler with component validation                      |
   //| Processes each market tick with comprehensive error checking     |
   //| Updates components and checks for trading signals                |
   //|                                                                  |
   //| @return void                                                     |
   //|                                                                  |
   //| @note Validates all components before processing to prevent     |
   //|       crashes from uninitialized components                      |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // ✅ Verify components are initialized
      if(!ValidateComponentState())
      {
         static datetime lastWarning = 0;
         datetime currentTime = TimeCurrent();
         
         // Log warning once per minute to avoid spam
         if(currentTime - lastWarning > 60)
         {
            Print("⚠️ Components not properly initialized, skipping tick");
            lastWarning = currentTime;
         }
         return;
      }
      
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
      
      // ✅ Add null checks
      if(m_volatilityFilter == NULL || m_trendlineManager == NULL)
      {
         Print("⚠️ ExecuteBuySignal: Required components are NULL");
         return;
      }
      
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
      
      // ✅ Add null checks
      if(m_volatilityFilter == NULL || m_trendlineManager == NULL)
      {
         Print("⚠️ ExecuteSellSignal: Required components are NULL");
         return;
      }
      
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
   //| Send order to broker with comprehensive validation               |
   //| Validates order parameters and provides detailed error reporting |
   //| Automatically adjusts SL/TP if they violate broker requirements  |
   //|                                                                  |
   //| @param isLong - true for BUY order, false for SELL order        |
   //|                                                                  |
   //| @return bool - true if order executed successfully               |
   //|                                                                  |
   //| @note Includes detailed error reporting with specific tips for  |
   //|       common order execution failures                             |
   //+------------------------------------------------------------------+
   bool SendOrder(bool isLong)
   {
      double price = isLong ? 
         SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
         SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double tp = NormalizeDouble(m_currentTP, digits);
      double sl = NormalizeDouble(m_currentSL, digits);
      
      // ═══ VALIDATE ORDER PARAMETERS ═══
      
      if(price <= 0)
      {
         Print("❌ Invalid price: ", price);
         return false;
      }
      
      if(tp <= 0 || sl <= 0)
      {
         Print("❌ Invalid TP/SL: TP=", tp, " SL=", sl);
         return false;
      }
      
      // Check minimum stop level
      long minStopsLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minStops = minStopsLevel * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      double slDistance = isLong ? (price - sl) : (sl - price);
      double tpDistance = isLong ? (tp - price) : (price - tp);
      
      // Adjust SL if too close
      if(slDistance < minStops && minStops > 0)
      {
         Print("⚠️ SL too close: ", slDistance, " < ", minStops);
         sl = isLong ? 
            NormalizeDouble(price - minStops * 1.1, digits) : 
            NormalizeDouble(price + minStops * 1.1, digits);
         Print("   Adjusted SL to: ", sl);
      }
      
      // Adjust TP if too close
      if(tpDistance < minStops && minStops > 0)
      {
         Print("⚠️ TP too close: ", tpDistance, " < ", minStops);
         tp = isLong ? 
            NormalizeDouble(price + minStops * 1.1, digits) : 
            NormalizeDouble(price - minStops * 1.1, digits);
         Print("   Adjusted TP to: ", tp);
      }
      
      // ═══ EXECUTE ORDER ═══
      
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
         // ═══ DETAILED ERROR REPORTING ═══
         
         uint errorCode = GetLastError();
         uint retCode = m_trade.ResultRetcode();
         
         Print("═══════════════════════════════════════");
         Print("❌ ORDER EXECUTION FAILED");
         Print("═══════════════════════════════════════");
         Print("Symbol: ", m_symbol);
         Print("Direction: ", isLong ? "BUY" : "SELL");
         Print("Price: ", price);
         Print("Lot Size: ", m_lotSize);
         Print("SL: ", sl, " (Distance: ", slDistance, ")");
         Print("TP: ", tp, " (Distance: ", tpDistance, ")");
         Print("Min Stops: ", minStops);
         Print("─────────────────────────────────────");
         Print("Error Code: ", errorCode);
         Print("Return Code: ", retCode);
         Print("Description: ", m_trade.ResultRetcodeDescription());
         Print("Comment: ", m_trade.ResultComment());
         Print("═══════════════════════════════════════");
         
         // Provide specific guidance based on error
         switch(retCode)
         {
            case TRADE_RETCODE_INVALID_STOPS:
               Print("💡 TIP: SL/TP violates broker's minimum distance");
               Print("   Check SYMBOL_TRADE_STOPS_LEVEL for ", m_symbol);
               break;
               
            case TRADE_RETCODE_INVALID_VOLUME:
               Print("💡 TIP: Lot size not within allowed range");
               Print("   Min: ", SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN));
               Print("   Max: ", SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX));
               Print("   Step: ", SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP));
               break;
               
            case TRADE_RETCODE_NO_MONEY:
               Print("💡 TIP: Insufficient funds to place order");
               Print("   Free Margin: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
               Print("   Required: ~", m_lotSize * SymbolInfoDouble(m_symbol, SYMBOL_MARGIN_INITIAL));
               break;
               
            case TRADE_RETCODE_MARKET_CLOSED:
               Print("💡 TIP: Market is closed for ", m_symbol);
               break;
               
            case TRADE_RETCODE_INVALID_PRICE:
               Print("💡 TIP: Price has changed, order needs to be retried");
               break;
               
            case TRADE_RETCODE_PRICE_OFF:
               Print("💡 TIP: Requested price is too far from current market");
               break;
         }
         
         Print("═══════════════════════════════════════");
      }
      
      return result;
   }

   //+------------------------------------------------------------------+
   //| Manage open trade                                               |
   //+------------------------------------------------------------------+
   void ManageTrade()
   {
      // ✅ Add null check
      if(m_trendlineManager == NULL)
      {
         Print("⚠️ ManageTrade: TrendlineManager is NULL");
         return;
      }
      
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

private:
   //+------------------------------------------------------------------+
   //| Validate that all components are properly initialized           |
   //+------------------------------------------------------------------+
   bool ValidateComponentState()
   {
      if(m_pivotDetector == NULL || !m_pivotDetector.IsInitialized())
      {
         Print("⚠️ PivotDetector not initialized");
         return false;
      }
      
      if(m_trendlineDetector == NULL || !m_trendlineDetector.IsInitialized())
      {
         Print("⚠️ TrendlineDetector not initialized");
         return false;
      }
      
      if(m_breakoutDetector == NULL || !m_breakoutDetector.IsInitialized())
      {
         Print("⚠️ BreakoutDetector not initialized");
         return false;
      }
      
      if(m_volatilityFilter == NULL || !m_volatilityFilter.IsInitialized())
      {
         Print("⚠️ VolatilityFilter not initialized");
         return false;
      }
      
      if(m_trendlineManager == NULL)
      {
         Print("⚠️ TrendlineManager is NULL");
         return false;
      }
      
      return true;
   }
};
