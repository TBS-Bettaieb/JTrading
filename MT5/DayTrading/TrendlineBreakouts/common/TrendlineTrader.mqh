//+------------------------------------------------------------------+
//| TrendlineTrader.mqh - Main orchestrator class                    |
//| Coordinates all components and executes trades                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include "utils/Logger.mqh"
#include "detectors/PivotDetector.mqh"
#include "detectors/TrendlineDetector.mqh"
#include "detectors/BreakoutDetector.mqh"
#include "filters/VolatilityFilter.mqh"
#include "managers/TrendlineManager.mqh"
#include "managers/TradeManager.mqh"
#include "events/EventManager.mqh"
#include "events/PerformanceTracker.mqh"

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
   TradeManager* m_tradeManager;        // ✅ Add TradeManager
   EventManager* m_eventManager;        // ✅ Add EventManager
   PerformanceTracker* m_perfTracker;   // ✅ Add PerformanceTracker
   
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
   ulong m_currentTicket;  // ✅ Add position ticket tracking

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
      color lineColor = clrGray,
      ENUM_LOG_LEVEL logLevel = LOG_INFO  // ✅ Add log level parameter
   )
   {
      // ═══ VALIDATE AND SANITIZE INPUTS ═══
      
      // Validate log level
      if(logLevel < LOG_NONE || logLevel > LOG_DEBUG)
      {
         Logger::Warning("Invalid log level (" + IntegerToString(logLevel) + "), using LOG_INFO");
         logLevel = LOG_INFO;
      }
      
      // ✅ ADD LOGGER INITIALIZATION AFTER VALIDATION:
      Logger::Initialize(logLevel, "[TBT] ");
      
      if(symbol == "" || symbol == NULL)
      {
         Logger::Warning("Invalid symbol provided, using current symbol");
         symbol = _Symbol;
      }
      
      if(magicNumber <= 0)
      {
         Logger::Warning("Invalid magic number (" + IntegerToString(magicNumber) + "), using 12345");
         magicNumber = 12345;
      }
      
      if(period < 2 || period > 100)
      {
         Logger::Warning("Invalid period (" + IntegerToString(period) + "), using 10");
         period = 10;
      }
      
      if(extension < 10 || extension > 100)
      {
         Logger::Warning("Invalid extension (" + IntegerToString(extension) + "), using 25");
         extension = 25;
      }
      
      if(lotSize <= 0 || lotSize > 100)
      {
         Logger::Warning("Invalid lot size (" + DoubleToString(lotSize) + "), using 0.01");
         lotSize = 0.01;
      }
      
      if(slippage < 0 || slippage > 100)
      {
         Logger::Warning("Invalid slippage (" + IntegerToString(slippage) + "), using 10");
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
      m_currentTicket = 0;  // ✅ Initialize ticket tracking
      
      // Create components
      m_pivotDetector = new PivotDetector(symbol, timeframe, period, useWicks);
      m_trendlineDetector = new TrendlineDetector(symbol, timeframe);
      m_breakoutDetector = new BreakoutDetector(symbol, timeframe, m_trendlineDetector);
      m_volatilityFilter = new VolatilityFilter(symbol, timeframe, 30);
      m_trendlineManager = new TrendlineManager(symbol, extension, lineColor);
      
      // ✅ ADD NEW MANAGERS:
      m_tradeManager = new TradeManager(symbol, magicNumber, lotSize, slippage);
      m_eventManager = new EventManager();
      m_perfTracker = new PerformanceTracker();
      m_eventManager.RegisterListener(m_perfTracker);
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
      
      // ✅ ADD NEW MANAGER CLEANUP:
      if(m_perfTracker != NULL) 
      {
         m_perfTracker.PrintReport();  // ✅ Print final report
         delete m_perfTracker;
      }
      
      if(m_eventManager != NULL) delete m_eventManager;
      if(m_tradeManager != NULL) delete m_tradeManager;
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
      
      // ✅ ADD SYMBOL VALIDATION FIRST:
      if(!ValidateSymbol())
         return false;
      
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
         static int warningCount = 0;
         datetime currentTime = TimeCurrent();
         
         // NEW CODE WITH LIMIT:
         if(currentTime - lastWarning > 60 && warningCount < 10)
         {
            Logger::Warning("Components not properly initialized (" + IntegerToString(++warningCount) + "/10), skipping tick");
            lastWarning = currentTime;
            
            if(warningCount == 10)
            {
               Logger::Error("═══════════════════════════════════════");
               Logger::Error("Maximum validation warnings reached!");
               Logger::Error("💡 TIP: Remove and re-add EA to chart to reinitialize.");
               Logger::Error("💡 TIP: Check symbol and timeframe settings.");
               Logger::Error("═══════════════════════════════════════");
            }
         }
         return;
      }
      
      // Check for new bar
      if(IsNewBar())
      {
         UpdateBarTime();
         OnNewBar();
      }
      
      // Update volatility filter (needed for Zband)
      m_volatilityFilter.Update();
      
      // Update breakout detector with latest Zband
      m_breakoutDetector.SetZband(m_volatilityFilter.GetZband());
      
      // ✅ ALWAYS sync state from TradeManager (single source of truth)
      SyncTradeState();
      
      // Check for signals if no trade is open
      if(!m_tradeIsOn)
      {
         CheckSignals();
      }
      else
      {
         ManageTrade();
      }
   }

   //+------------------------------------------------------------------+
   //| New bar handler                                                 |
   //+------------------------------------------------------------------+
   void OnNewBar()
   {
      Logger::Info("New bar detected - Updating components");
      
      // 1. Update pivot detector
      m_pivotDetector.Update();
      
      // 2. If new pivot high detected, update upper trendline
      if(m_pivotDetector.IsNewPivotHigh())
      {
         double pivotHigh = m_pivotDetector.GetPivotHigh();
         int pivotBar = m_pivotDetector.GetPivotHighBar();
         
         m_trendlineDetector.UpdateUpperTrendline(pivotHigh, pivotBar);
         
         // ✅ ADD EVENT:
         m_eventManager.DispatchPivotDetected(true, pivotHigh, pivotBar);
         
         // Draw trendline if no trade is open
         if(!m_tradeIsOn && m_trendlineDetector.IsUpperSlopeValid())
         {
            TrendlineData td = m_trendlineDetector.GetUpperTrendline();
            m_trendlineManager.DrawUpperTrendline(td);
            
            // ✅ ADD EVENT:
            m_eventManager.DispatchTrendlineUpdated(true, td.slope, td.isValid);
         }
      }
      
      // 3. If new pivot low detected, update lower trendline
      if(m_pivotDetector.IsNewPivotLow())
      {
         double pivotLow = m_pivotDetector.GetPivotLow();
         int pivotBar = m_pivotDetector.GetPivotLowBar();
         
         m_trendlineDetector.UpdateLowerTrendline(pivotLow, pivotBar);
         
         // ✅ ADD EVENT:
         m_eventManager.DispatchPivotDetected(false, pivotLow, pivotBar);
         
         // Draw trendline if no trade is open
         if(!m_tradeIsOn && m_trendlineDetector.IsLowerSlopeValid())
         {
            TrendlineData td = m_trendlineDetector.GetLowerTrendline();
            m_trendlineManager.DrawLowerTrendline(td);
            
            // ✅ ADD EVENT:
            m_eventManager.DispatchTrendlineUpdated(false, td.slope, td.isValid);
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
         // ✅ ADD EVENT:
         m_eventManager.DispatchSignalDetected(true, 1.0, TimeCurrent());
         ExecuteBuySignal();
      }
      
      // Check for sell signal (breakout below support)
      if(m_breakoutDetector.HasSellSignal())
      {
         // ✅ ADD EVENT:
         m_eventManager.DispatchSignalDetected(false, 1.0, TimeCurrent());
         ExecuteSellSignal();
      }
   }

   //+------------------------------------------------------------------+
   //| Execute buy signal                                              |
   //+------------------------------------------------------------------+
   void ExecuteBuySignal()
   {
      Logger::Signal(true, "BUY SIGNAL DETECTED");
      
      // ✅ Add null checks
      if(m_volatilityFilter == NULL || m_trendlineManager == NULL)
      {
         Logger::Warning("ExecuteBuySignal: Required components are NULL");
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
         m_currentTicket = m_tradeManager.GetCurrentTicket();  // ✅ Sync ticket
         
         // ✅ ADD EVENT:
         m_eventManager.DispatchTradeOpened(
            true, 
            m_currentTicket, 
            SymbolInfoDouble(m_symbol, SYMBOL_ASK),
            m_currentSL, 
            m_currentTP
         );
         
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
      Logger::Signal(false, "SELL SIGNAL DETECTED");
      
      // ✅ Add null checks
      if(m_volatilityFilter == NULL || m_trendlineManager == NULL)
      {
         Logger::Warning("ExecuteSellSignal: Required components are NULL");
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
         m_currentTicket = m_tradeManager.GetCurrentTicket();  // ✅ Sync ticket
         
         // ✅ ADD EVENT:
         m_eventManager.DispatchTradeOpened(
            false, 
            m_currentTicket, 
            SymbolInfoDouble(m_symbol, SYMBOL_BID),
            m_currentSL, 
            m_currentTP
         );
         
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
   
      return m_tradeManager.OpenPosition(isLong, price, m_currentSL, m_currentTP);
   }

   //+------------------------------------------------------------------+
   //| Manage open trade                                               |
   //+------------------------------------------------------------------+
   void ManageTrade()
   {
      // ✅ Add null checks
      if(m_trendlineManager == NULL || m_tradeManager == NULL)
      {
         Logger::Warning("ManageTrade: Required managers are NULL");
         return;
      }
      
      // ✅ Use TradeManager validation:
      if(!m_tradeManager.ValidatePosition())
      {
         m_tradeIsOn = false;
         m_trendlineManager.ClearSLTPLines();
         return;
      }
      
      double high = iHigh(m_symbol, m_timeframe, 0);
      double low = iLow(m_symbol, m_timeframe, 0);
      double close = iClose(m_symbol, m_timeframe, 0);
      
      // Update SL/TP line positions
      m_trendlineManager.UpdateSLTPLines(m_currentSL, m_currentTP);
      
      // Check for TP or SL hit and close position
      if(m_isLongTrade)
      {
         if(high >= m_currentTP)
         {
            // ✅ CAPTURE DATA BEFORE CLOSING
            ulong ticket = m_tradeManager.GetCurrentTicket();
            double profit = m_tradeManager.GetPositionProfit();
            
            if(m_tradeManager.ClosePosition("TP Hit"))
            {
               m_eventManager.DispatchTradeClosed(
                  true,
                  ticket,   // ✅ Use captured ticket
                  profit,   // ✅ Use captured profit
                  "TP Hit"
               );
               
               m_tradeIsOn = false;
               m_trendlineManager.ClearSLTPLines();
            }
         }
         else if(close <= m_currentSL)
         {
            // ✅ CAPTURE DATA BEFORE CLOSING
            ulong ticket = m_tradeManager.GetCurrentTicket();
            double profit = m_tradeManager.GetPositionProfit();
            
            if(m_tradeManager.ClosePosition("SL Hit"))
            {
               m_eventManager.DispatchTradeClosed(
                  true,
                  ticket,   // ✅ Use captured ticket
                  profit,   // ✅ Use captured profit
                  "SL Hit"
               );
               
               m_tradeIsOn = false;
               m_trendlineManager.ClearSLTPLines();
            }
         }
      }
      else // Short trade
      {
         if(low <= m_currentTP)
         {
            // ✅ CAPTURE DATA BEFORE CLOSING
            ulong ticket = m_tradeManager.GetCurrentTicket();
            double profit = m_tradeManager.GetPositionProfit();
            
            if(m_tradeManager.ClosePosition("TP Hit"))
            {
               m_eventManager.DispatchTradeClosed(
                  false,
                  ticket,   // ✅ Use captured ticket
                  profit,   // ✅ Use captured profit
                  "TP Hit"
               );
               
               m_tradeIsOn = false;
               m_trendlineManager.ClearSLTPLines();
            }
         }
         else if(close >= m_currentSL)
         {
            // ✅ CAPTURE DATA BEFORE CLOSING
            ulong ticket = m_tradeManager.GetCurrentTicket();
            double profit = m_tradeManager.GetPositionProfit();
            
            if(m_tradeManager.ClosePosition("SL Hit"))
            {
               m_eventManager.DispatchTradeClosed(
                  false,
                  ticket,   // ✅ Use captured ticket
                  profit,   // ✅ Use captured profit
                  "SL Hit"
               );
               
               m_tradeIsOn = false;
               m_trendlineManager.ClearSLTPLines();
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Check if new bar (pure function - no state modification)        |
   //+------------------------------------------------------------------+
   bool IsNewBar()
   {
      datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
      return (currentBarTime != m_lastBarTime);
   }

   //+------------------------------------------------------------------+
   //| Update bar time state (separate from IsNewBar check)            |
   //+------------------------------------------------------------------+
   void UpdateBarTime()
   {
      m_lastBarTime = iTime(m_symbol, m_timeframe, 0);
   }

   //+------------------------------------------------------------------+
   //| Getters for monitoring                                          |
   //+------------------------------------------------------------------+
   bool IsTradeOpen() const { return m_tradeIsOn; }
   bool IsLongTrade() const { return m_isLongTrade; }
   double GetCurrentTP() const { return m_currentTP; }
   double GetCurrentSL() const { return m_currentSL; }
   double GetZband() const { return m_volatilityFilter.GetZband(); }
   ulong GetCurrentTicket() const { return m_currentTicket; }

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

   //+------------------------------------------------------------------+
   //| Sync trade state from TradeManager (single source of truth)     |
   //+------------------------------------------------------------------+
   void SyncTradeState()
   {
      bool managerState = m_tradeManager.IsPositionOpen();
      
      if(managerState != m_tradeIsOn)
      {
         m_tradeIsOn = managerState;
         
         if(m_tradeIsOn)
         {
            m_currentTicket = m_tradeManager.GetCurrentTicket();
            m_isLongTrade = m_tradeManager.IsLongPosition();
            Logger::Info("Trade state synced: Position opened");
         }
         else
         {
            m_currentTicket = 0;
            Logger::Info("Trade state synced: Position closed externally");
            if(m_trendlineManager != NULL)
               m_trendlineManager.ClearSLTPLines();
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Validate symbol is tradeable and market conditions are suitable |
   //+------------------------------------------------------------------+
   bool ValidateSymbol()
   {
      // Check symbol exists and is selected
      if(!SymbolSelect(m_symbol, true))
      {
         Print("❌ Symbol ", m_symbol, " not available");
         return false;
      }
      
      // Check if trading is allowed for this symbol
      ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
      if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
      {
         Print("❌ Trading disabled for ", m_symbol);
         return false;
      }
      
      if(tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
      {
         Print("⚠️ Symbol ", m_symbol, " is in close-only mode");
         return false;
      }
      
      // Check if we have sufficient data
      int bars = Bars(m_symbol, m_timeframe);
      if(bars < 100)
      {
         Print("⚠️ Insufficient bars (", bars, ") for ", m_symbol);
         return false;
      }
      
      Print("✅ Symbol validation passed: ", m_symbol, " | Bars: ", bars, " | Trade Mode: ", EnumToString(tradeMode));
      return true;
   }
};
