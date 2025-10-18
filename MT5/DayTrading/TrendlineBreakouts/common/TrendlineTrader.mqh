//+------------------------------------------------------------------+
//| TrendlineTrader.mqh - Main orchestrator class                    |
//| Coordinates all components and executes trades                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include "utils/Logger.mqh"
#include "../../../CommonUtils/TradingUtils.mqh"
#include "utils/SymbolClassifier.mqh"
#include "detectors/PivotDetector.mqh"
#include "detectors/TrendlineDetector.mqh"
#include "detectors/BreakoutDetector.mqh"
#include "filters/VolatilityFilter.mqh"
#include "managers/TrendlineManager.mqh"
#include "managers/TradeManager.mqh"
#include "events/EventManager.mqh"
#include "events/PerformanceTracker.mqh"

//+------------------------------------------------------------------+
//| TP/SL Method enumeration                                         |
//+------------------------------------------------------------------+
enum ENUM_TPSL_METHOD
{
   ZBAND = 0,           // Zband Multiplier (current method)
   FIXED_POINTS = 1,    // Fixed Points/Pips
   ATR_MULTIPLE = 2,    // ATR Multiple
   RISK_REWARD = 3,     // Risk/Reward Ratio
   PERCENT = 4,         // Percentage of Price
   HL_RATIO = 5         // High/Low 5-candle with 1:2 R:R
};

//+------------------------------------------------------------------+
//| TP/SL Levels structure                                           |
//+------------------------------------------------------------------+
struct TPSLLevels
{
   double takeProfit;
   double stopLoss;
};

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
   
   // TP/SL Settings
   ENUM_TPSL_METHOD m_tpslMethod;
   double m_zbandMultiplier;
   int m_fixedPoints;
   double m_atrMultiple;
   double m_riskReward;
   double m_percent;
   
   // State tracking
   double m_currentTP;
   double m_currentSL;
   datetime m_lastBarTime;
   int m_maxPositions;
   bool m_closeOnOpposite;

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
      ENUM_LOG_LEVEL logLevel = LOG_INFO,  // ✅ Add log level parameter
      int maxPositions = 3,  // ✅ Add max positions parameter
      bool closeOnOpposite = true,  // ✅ Add close on opposite parameter
      // TP/SL Parameters
      ENUM_TPSL_METHOD tpslMethod = ZBAND,
      double zbandMultiplier = 20.0,
      int fixedPoints = 100,
      double atrMultiple = 2.0,
      double riskReward = 2.0,
      double percent = 1.0
   )
   {
      // ═══ INITIALIZE LOGGER FIRST ═══
      Logger::Initialize(logLevel, "[TBT] ");
      
      // ═══ VALIDATE AND SANITIZE INPUTS ═══
      
      // Validate log level (after logger init)
      if(logLevel < LOG_NONE || logLevel > LOG_DEBUG)
      {
         Logger::Warning("Invalid log level (" + IntegerToString(logLevel) + "), using LOG_INFO");
         logLevel = LOG_INFO;
      }
      
      if(symbol == "" || symbol == NULL)
      {
         Logger::Warning("Invalid symbol provided, using current symbol");
         symbol = _Symbol;
      }
      
      if(magicNumber <= 0 || magicNumber > 999999)
      {
         Logger::Warning("Invalid magic number (" + IntegerToString(magicNumber) + "), must be between 1-999999, using 12345");
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
      
      // Validate TP/SL parameters
      if(zbandMultiplier <= 0 || zbandMultiplier > 100)
      {
         Logger::Warning("Invalid zband multiplier (" + DoubleToString(zbandMultiplier) + "), using 20.0");
         zbandMultiplier = 20.0;
      }
      
      if(fixedPoints <= 0 || fixedPoints > 10000)
      {
         Logger::Warning("Invalid fixed points (" + IntegerToString(fixedPoints) + "), using 100");
         fixedPoints = 100;
      }
      
      if(atrMultiple <= 0 || atrMultiple > 10)
      {
         Logger::Warning("Invalid ATR multiple (" + DoubleToString(atrMultiple) + "), using 2.0");
         atrMultiple = 2.0;
      }
      
      if(riskReward <= 0 || riskReward > 10)
      {
         Logger::Warning("Invalid risk/reward ratio (" + DoubleToString(riskReward) + "), using 2.0");
         riskReward = 2.0;
      }
      
      if(percent <= 0 || percent > 10)
      {
         Logger::Warning("Invalid percent (" + DoubleToString(percent) + "), using 1.0");
         percent = 1.0;
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
      
      // Assign TP/SL settings
      m_tpslMethod = tpslMethod;
      m_zbandMultiplier = zbandMultiplier;
      m_fixedPoints = fixedPoints;
      m_atrMultiple = atrMultiple;
      m_riskReward = riskReward;
      m_percent = percent;
      
      // Initialize state
      m_maxPositions = maxPositions;
      m_closeOnOpposite = closeOnOpposite;
      m_currentTP = 0;
      m_currentSL = 0;
      m_lastBarTime = 0;
      
      // Create components
      m_pivotDetector = new PivotDetector(symbol, timeframe, period, useWicks);
      m_trendlineDetector = new TrendlineDetector(symbol, timeframe);
      m_breakoutDetector = new BreakoutDetector(symbol, timeframe, m_trendlineDetector);
      m_volatilityFilter = new VolatilityFilter(symbol, timeframe, 30);
      m_trendlineManager = new TrendlineManager(symbol, extension, lineColor);
      
      // ✅ ADD NEW MANAGERS:
      m_tradeManager = new TradeManager(symbol, magicNumber, lotSize, slippage, m_maxPositions, timeframe);
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
      m_tradeManager.ValidatePositions();
      
      // Always check for signals (allow multiple simultaneous trades)
      CheckSignals();
      
      // Manage all active positions
      ManageTrade();
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
         
         Logger::Info("🟢 Processing NEW PIVOT HIGH: " + DoubleToString(pivotHigh) + " at bar " + IntegerToString(pivotBar));
         
         m_trendlineDetector.UpdateUpperTrendline(pivotHigh, pivotBar);
         
         // ✅ ADD EVENT:
         m_eventManager.DispatchPivotDetected(true, pivotHigh, pivotBar);
         
         // Draw trendline if slope is valid (allow multiple positions)
         if(m_trendlineDetector.IsUpperSlopeValid())
         {
            TrendlineData td = m_trendlineDetector.GetUpperTrendline();
            m_trendlineManager.DrawUpperTrendline(td);
            
            // ✅ ADD EVENT:
            m_eventManager.DispatchTrendlineUpdated(true, td.slope, td.isValid);
            
            Logger::Info("📈 Upper trendline drawn | Slope: " + DoubleToString(td.slope) + " | Valid: " + (td.isValid ? "YES" : "NO") +
                        " | ActivePositions: " + IntegerToString(m_tradeManager.GetActivePositionCount()));
         }
         else
         {
            Logger::Info("Upper trendline NOT drawn | SlopeValid: " + (m_trendlineDetector.IsUpperSlopeValid() ? "YES" : "NO"));
         }
      }
      
      // 3. If new pivot low detected, update lower trendline
      if(m_pivotDetector.IsNewPivotLow())
      {
         double pivotLow = m_pivotDetector.GetPivotLow();
         int pivotBar = m_pivotDetector.GetPivotLowBar();
         
         Logger::Info("🔴 Processing NEW PIVOT LOW: " + DoubleToString(pivotLow) + " at bar " + IntegerToString(pivotBar));
         
         m_trendlineDetector.UpdateLowerTrendline(pivotLow, pivotBar);
         
         // ✅ ADD EVENT:
         m_eventManager.DispatchPivotDetected(false, pivotLow, pivotBar);
         
         // Draw trendline if slope is valid (allow multiple positions)
         if(m_trendlineDetector.IsLowerSlopeValid())
         {
            TrendlineData td = m_trendlineDetector.GetLowerTrendline();
            m_trendlineManager.DrawLowerTrendline(td);
            
            // ✅ ADD EVENT:
            m_eventManager.DispatchTrendlineUpdated(false, td.slope, td.isValid);
            
            Logger::Info("📉 Lower trendline drawn | Slope: " + DoubleToString(td.slope) + " | Valid: " + (td.isValid ? "YES" : "NO") +
                        " | ActivePositions: " + IntegerToString(m_tradeManager.GetActivePositionCount()));
         }
         else
         {
            Logger::Info("Lower trendline NOT drawn | SlopeValid: " + (m_trendlineDetector.IsLowerSlopeValid() ? "YES" : "NO"));
         }
      }
      
      // Add summary logging if no pivots detected
      static int noPivotCount = 0;
      if(!m_pivotDetector.IsNewPivotHigh() && !m_pivotDetector.IsNewPivotLow())
      {
         noPivotCount++;
         if(noPivotCount % 50 == 0) // Log every 50 new bars without pivots
         {
            Logger::Info("⏳ No pivots detected for " + IntegerToString(noPivotCount) + " new bars | " +
                        "UpperTrend Valid: " + (m_trendlineDetector.IsUpperSlopeValid() ? "YES" : "NO") +
                        " | LowerTrend Valid: " + (m_trendlineDetector.IsLowerSlopeValid() ? "YES" : "NO"));
         }
      }
      else
      {
         noPivotCount = 0; // Reset counter when pivots are detected
      }
      
      // Clear pivot flags after processing
      m_pivotDetector.ClearNewPivotFlags();
   }

   //+------------------------------------------------------------------+
   //| Check for trading signals                                       |
   //+------------------------------------------------------------------+
   void CheckSignals()
   {
      // Add diagnostic logging for signal detection
      static datetime lastSignalCheck = 0;
      datetime currentTime = TimeCurrent();
      
      // Log signal check status every 30 seconds max
      if(currentTime - lastSignalCheck > 30)
      {
         // Get more detailed diagnostic information
         bool hasUpperTrend = m_trendlineDetector.IsUpperSlopeValid();
         bool hasLowerTrend = m_trendlineDetector.IsLowerSlopeValid();
         
         if(hasUpperTrend)
         {
            TrendlineData upperData = m_trendlineDetector.GetUpperTrendline();
            Logger::Info("📈 Upper trendline active | Slope: " + DoubleToString(upperData.slope, 6) + 
                        " | StartPrice: " + DoubleToString(upperData.startPrice, 5) +
                        " | CurrentPrice: " + DoubleToString(m_trendlineDetector.GetUpperLinePrice(), 5));
         }
         
         if(hasLowerTrend)
         {
            TrendlineData lowerData = m_trendlineDetector.GetLowerTrendline();
            Logger::Info("📉 Lower trendline active | Slope: " + DoubleToString(lowerData.slope, 6) + 
                        " | StartPrice: " + DoubleToString(lowerData.startPrice, 5) +
                        " | CurrentPrice: " + DoubleToString(m_trendlineDetector.GetLowerLinePrice(), 5));
         }
         
         Logger::Info("🔍 Signal Status | BreakoutDetector: " + (m_breakoutDetector.IsInitialized() ? "OK" : "FAILED") +
                     " | UpperTrend: " + (hasUpperTrend ? "VALID" : "NONE") +
                     " | LowerTrend: " + (hasLowerTrend ? "VALID" : "NONE") +
                     " | ActivePositions: " + IntegerToString(m_tradeManager.GetActivePositionCount()));
         lastSignalCheck = currentTime;
      }
      
      // Check for buy signal (breakout above resistance)
      if(m_breakoutDetector.HasBuySignal())
      {
         Logger::Info("🟢 BUY SIGNAL DETECTED - Executing...");
         
         // Close any existing SHORT positions before opening LONG position (if enabled)
         if(m_closeOnOpposite && m_tradeManager.HasPositionInDirection(false))
         {
            Logger::Info("Closing SHORT positions before opening LONG position");
            m_tradeManager.ClosePositionsByDirection(false, "Opposite signal");
         }
         else if(!m_closeOnOpposite && m_tradeManager.HasPositionInDirection(false))
         {
            Logger::Info("Close on opposite disabled - keeping SHORT positions open");
         }
         
         // ✅ ADD EVENT:
         m_eventManager.DispatchSignalDetected(true, 1.0, TimeCurrent());
         ExecuteBuySignal();
      }
      
      // Check for sell signal (breakout below support)
      if(m_breakoutDetector.HasSellSignal())
      {
         Logger::Info("🔴 SELL SIGNAL DETECTED - Executing...");
         
         // Close any existing LONG positions before opening SHORT position (if enabled)
         if(m_closeOnOpposite && m_tradeManager.HasPositionInDirection(true))
         {
            Logger::Info("Closing LONG positions before opening SHORT position");
            m_tradeManager.ClosePositionsByDirection(true, "Opposite signal");
         }
         else if(!m_closeOnOpposite && m_tradeManager.HasPositionInDirection(true))
         {
            Logger::Info("Close on opposite disabled - keeping LONG positions open");
         }
         
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
      
      double high = iHigh(m_symbol, m_timeframe, 0);
      double low = iLow(m_symbol, m_timeframe, 0);
      
      // Calculate TP and SL using the new modular system
      TPSLLevels levels = CalculateTPSL(true, high);
      m_currentTP = levels.takeProfit;
      m_currentSL = levels.stopLoss;
      
      // Send order
      if(SendOrder(true))
      {
         // Get the latest ticket from active positions array
         ulong activeTickets[];
         if(m_tradeManager.GetActiveTickets(activeTickets) && ArraySize(activeTickets) > 0)
         {
            ulong latestTicket = activeTickets[ArraySize(activeTickets) - 1];
            
            // ✅ ADD EVENT:
            m_eventManager.DispatchTradeOpened(
               true, 
               latestTicket, 
               SymbolInfoDouble(m_symbol, SYMBOL_ASK),
               m_currentSL, 
               m_currentTP
            );
         }
         
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
      
      double high = iHigh(m_symbol, m_timeframe, 0);
      double low = iLow(m_symbol, m_timeframe, 0);
      
      // Calculate TP and SL using the new modular system
      TPSLLevels levels = CalculateTPSL(false, low);
      m_currentTP = levels.takeProfit;
      m_currentSL = levels.stopLoss;
      
      // Send order
      if(SendOrder(false))
      {
         // Get the latest ticket from active positions array
         ulong activeTickets[];
         if(m_tradeManager.GetActiveTickets(activeTickets) && ArraySize(activeTickets) > 0)
         {
            ulong latestTicket = activeTickets[ArraySize(activeTickets) - 1];
            
            // ✅ ADD EVENT:
            m_eventManager.DispatchTradeOpened(
               false, 
               latestTicket, 
               SymbolInfoDouble(m_symbol, SYMBOL_BID),
               m_currentSL, 
               m_currentTP
            );
         }
         
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
   //| Manage all active positions                                     |
   //+------------------------------------------------------------------+
   void ManageTrade()
   {
      // ✅ Add null checks
      if(m_trendlineManager == NULL || m_tradeManager == NULL)
      {
         Logger::Warning("ManageTrade: Required managers are NULL");
         return;
      }
      
      // Get all active positions
      ulong activeTickets[];
      if(!m_tradeManager.GetActiveTickets(activeTickets))
      {
         // No positions to manage, clear SL/TP lines if any
         m_trendlineManager.ClearSLTPLines();
         return;
      }
      
      double high = iHigh(m_symbol, m_timeframe, 0);
      double low = iLow(m_symbol, m_timeframe, 0);
      double close = iClose(m_symbol, m_timeframe, 0);
      
      // Update SL/TP line positions (using the most recent trade levels)
      m_trendlineManager.UpdateSLTPLines(m_currentSL, m_currentTP);
      
      // Check each active position for TP/SL hits
      int count = ArraySize(activeTickets);
      for(int i = count - 1; i >= 0; i--)
      {
         ulong ticket = activeTickets[i];
         
         // Get position direction and prices
         bool isLong;
         if(!m_tradeManager.GetPositionDirection(ticket, isLong))
         {
            // Position not found in our tracking, skip
            continue;
         }
         
         if(!PositionSelectByTicket(ticket))
         {
            // Position closed externally, remove from tracking
            continue;
         }
         
         // Get position's TP and SL
         double positionTP = PositionGetDouble(POSITION_TP);
         double positionSL = PositionGetDouble(POSITION_SL);
         
         bool shouldClose = false;
         string closeReason = "";
         
         if(isLong)
         {
            if(high >= positionTP && positionTP > 0)
            {
               shouldClose = true;
               closeReason = "TP Hit";
            }
            else if(close <= positionSL && positionSL > 0)
            {
               shouldClose = true;
               closeReason = "SL Hit";
            }
         }
         else
         {
            if(low <= positionTP && positionTP > 0)
            {
               shouldClose = true;
               closeReason = "TP Hit";
            }
            else if(close >= positionSL && positionSL > 0)
            {
               shouldClose = true;
               closeReason = "SL Hit";
            }
         }
         
         if(shouldClose)
         {
            // Capture data before closing
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            if(m_tradeManager.ClosePosition(ticket, closeReason))
            {
               m_eventManager.DispatchTradeClosed(
                  isLong,
                  ticket,
                  profit,
                  closeReason
               );
            }
            else
            {
               Logger::Error("Failed to close position " + IntegerToString(ticket) + " at " + closeReason);
            }
         }
      }
      
      // Clear SL/TP lines if no positions are open
      if(m_tradeManager.GetActivePositionCount() == 0)
      {
         m_trendlineManager.ClearSLTPLines();
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
   int GetActiveTradeCount() const { return m_tradeManager.GetActivePositionCount(); }
   double GetCurrentTP() const { return m_currentTP; }
   double GetCurrentSL() const { return m_currentSL; }
   double GetZband() const { return m_volatilityFilter.GetZband(); }
   int GetMaxPositions() const { return m_maxPositions; }
   bool GetCloseOnOpposite() const { return m_closeOnOpposite; }

private:
   //+------------------------------------------------------------------+
   //| Calculate ZBAND-based TP/SL levels                              |
   //|                                                                  |
   //| @param isLong - true for LONG position, false for SHORT         |
   //| @param entryPrice - entry price of the trade                    |
   //| @param multiplier - ZBAND multiplier value                       |
   //|                                                                  |
   //| @return TPSLLevels - structure containing calculated TP and SL  |
   //+------------------------------------------------------------------+
   TPSLLevels CalculateZbandTPSL(bool isLong, double entryPrice, double multiplier)
   {
      TPSLLevels levels;
      levels.takeProfit = 0;
      levels.stopLoss = 0;
      
      if(m_volatilityFilter == NULL)
      {
         Logger::Error("CalculateZbandTPSL: VolatilityFilter is NULL");
         return levels;
      }
      
      double zband = m_volatilityFilter.GetZband();
      
      if(isLong)
      {
         levels.takeProfit = entryPrice + (zband * multiplier);
         levels.stopLoss = entryPrice - (zband * multiplier);
      }
      else
      {
         levels.takeProfit = entryPrice - (zband * multiplier);
         levels.stopLoss = entryPrice + (zband * multiplier);
      }
      
      return levels;
   }

   //+------------------------------------------------------------------+
   //| Calculate TP/SL levels based on selected method                  |
   //|                                                                  |
   //| @param isLong - true for LONG position, false for SHORT         |
   //| @param entryPrice - entry price of the trade                    |
   //|                                                                  |
   //| @return TPSLLevels - structure containing calculated TP and SL  |
   //+------------------------------------------------------------------+
   TPSLLevels CalculateTPSL(bool isLong, double entryPrice)
   {
      TPSLLevels levels;
      levels.takeProfit = 0;
      levels.stopLoss = 0;
      
      if(m_volatilityFilter == NULL)
      {
         Logger::Error("CalculateTPSL: VolatilityFilter is NULL");
         return levels;
      }
      
      double zband = m_volatilityFilter.GetZband();
      double atr = m_volatilityFilter.GetATR();
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      switch(m_tpslMethod)
      {
         case ZBAND:
            // Method 1: ZBAND (current method - kept for compatibility)
            levels = CalculateZbandTPSL(isLong, entryPrice, m_zbandMultiplier);
            break;
            
         case FIXED_POINTS:
            // Method 2: Fixed Points/Pips
            if(isLong)
            {
               levels.takeProfit = entryPrice + (m_fixedPoints * point);
               levels.stopLoss = entryPrice - (m_fixedPoints * point);
            }
            else
            {
               levels.takeProfit = entryPrice - (m_fixedPoints * point);
               levels.stopLoss = entryPrice + (m_fixedPoints * point);
            }
            break;
            
         case ATR_MULTIPLE:
            // Method 3: ATR Multiple
            if(isLong)
            {
               levels.takeProfit = entryPrice + (atr * m_atrMultiple);
               levels.stopLoss = entryPrice - (atr * m_atrMultiple);
            }
            else
            {
               levels.takeProfit = entryPrice - (atr * m_atrMultiple);
               levels.stopLoss = entryPrice + (atr * m_atrMultiple);
            }
            break;
            
         case RISK_REWARD:
            // Method 4: Risk/Reward Ratio (SL based on Zband, TP calculated by ratio)
            {
               if(isLong)
               {
                  levels.stopLoss = entryPrice - (zband * m_zbandMultiplier);
                  double riskDistance = entryPrice - levels.stopLoss;
                  levels.takeProfit = entryPrice + (riskDistance * m_riskReward);
               }
               else
               {
                  levels.stopLoss = entryPrice + (zband * m_zbandMultiplier);
                  double riskDistance = levels.stopLoss - entryPrice;
                  levels.takeProfit = entryPrice - (riskDistance * m_riskReward);
               }
            }
            break;
            
         case PERCENT:
            // Method 5: Percentage of Price
            {
               double tpDistance = entryPrice * (m_percent / 100.0);
               double slDistance = entryPrice * (m_percent / 100.0);
               
               if(isLong)
               {
                  levels.takeProfit = entryPrice + tpDistance;
                  levels.stopLoss = entryPrice - slDistance;
               }
               else
               {
                  levels.takeProfit = entryPrice - tpDistance;
                  levels.stopLoss = entryPrice + slDistance;
               }
            }
            break;
            
         case HL_RATIO:
            // Method 6: High/Low 5-candle with 1:2 R:R
            levels = CalculateHL5TPSLWithFallback(isLong, entryPrice);
            break;
            
         default:
            Logger::Warning("CalculateTPSL: Unknown TP/SL method, using ZBAND");
            levels = CalculateZbandTPSL(isLong, entryPrice, m_zbandMultiplier);
            break;
      }
      
      // Validate and normalize the results
      if(levels.takeProfit <= 0 || levels.stopLoss <= 0)
      {
         Logger::Warning("CalculateTPSL: Invalid TP/SL calculated, using defaults");
         // Use ZBAND as fallback with default multiplier
         levels = CalculateZbandTPSL(isLong, entryPrice, 20.0);
      }
      
      // Validate TP vs SL relationship
      if(isLong && levels.takeProfit <= levels.stopLoss)
      {
         Logger::Warning("CalculateTPSL: TP <= SL for LONG position, adjusting");
         double distance = (levels.stopLoss - entryPrice) * 0.5;
         levels.takeProfit = entryPrice + MathAbs(distance);
      }
      else if(!isLong && levels.takeProfit >= levels.stopLoss)
      {
         Logger::Warning("CalculateTPSL: TP >= SL for SHORT position, adjusting");
         double distance = (levels.stopLoss - entryPrice) * 0.5;
         levels.takeProfit = entryPrice - MathAbs(distance);
      }
      
      // Normalize to symbol digits
      levels.takeProfit = NormalizeDouble(levels.takeProfit, digits);
      levels.stopLoss = NormalizeDouble(levels.stopLoss, digits);
      
      Logger::Info(StringFormat("CalculateTPSL: Method=%d, TP=%.5f, SL=%.5f", 
                                (int)m_tpslMethod, levels.takeProfit, levels.stopLoss));
      
      return levels;
   }

   //+------------------------------------------------------------------+
   //| Calculate High/Low 5-candle TP/SL with fallback                 |
   //| SL = H/L of last 5 candles, TP = 1:2 R:R, fallback if too close |
   //| @param isLong - true for LONG position, false for SHORT         |
   //| @param entryPrice - entry price of the trade                    |
   //| @return TPSLLevels - structure containing calculated TP and SL  |
   //+------------------------------------------------------------------+
   TPSLLevels CalculateHL5TPSLWithFallback(bool isLong, double entryPrice)
   {
      TPSLLevels levels;
      levels.takeProfit = 0;
      levels.stopLoss = 0;
      
      // Step 1: Get H/L of last 5 candles
      double slLevel = GetHL5Level(isLong);
      
      if(slLevel <= 0)
      {
         Logger::Warning("CalculateHL5TPSLWithFallback: Invalid HL5 level, using ZBAND fallback");
         return CalculateZbandTPSL(isLong, entryPrice, m_zbandMultiplier);
      }
      
      // Step 2: Calculate SL distance
      double slDistance = MathAbs(entryPrice - slLevel);
      
      // Step 3: Check against dynamic threshold
      ENUM_ASSET_CLASS assetClass = SymbolClassifier::DetectAssetClass(m_symbol);
      double minThresholdPoints = SymbolClassifier::GetMinThresholdPoints(assetClass, m_symbol);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double minThresholdDistance = minThresholdPoints * point;
      
      Logger::Info(StringFormat("HL5 Check: SL=%.5f, Entry=%.5f, Distance=%.5f, Threshold=%.5f", 
                                slLevel, entryPrice, slDistance, minThresholdDistance));
      
      // Step 4: If too close, fallback to best alternative method
      if(slDistance < minThresholdDistance)
      {
         Logger::Warning(StringFormat("HL5 distance (%.5f) too close, using fallback method", slDistance));
         return GetBestFallbackTPSL(isLong, entryPrice, minThresholdDistance);
      }
      
      // Step 5: Calculate TP at 1:2 R:R
      levels.stopLoss = slLevel;
      levels.takeProfit = isLong ? 
         entryPrice + (slDistance * 2.0) : 
         entryPrice - (slDistance * 2.0);
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      levels.takeProfit = NormalizeDouble(levels.takeProfit, digits);
      levels.stopLoss = NormalizeDouble(levels.stopLoss, digits);
      
      Logger::Info(StringFormat("HL5 TPSL: SL=%.5f, TP=%.5f, R:R=1:2", levels.stopLoss, levels.takeProfit));
      
      return levels;
   }

   //+------------------------------------------------------------------+
   //| Get High/Low level from last 5 candles                           |
   //| @param isLong - true for lowest low, false for highest high      |
   //| @return double - extreme level from last 5 candles               |
   //+------------------------------------------------------------------+
   double GetHL5Level(bool isLong)
   {
      double extremeLevel = isLong ? DBL_MAX : 0.0;
      
      for(int i = 1; i <= 5; i++)  // Last 5 closed candles
      {
         if(isLong)
         {
            double low = iLow(m_symbol, m_timeframe, i);
            if(low > 0 && low < extremeLevel) 
               extremeLevel = low;
         }
         else
         {
            double high = iHigh(m_symbol, m_timeframe, i);
            if(high > 0 && high > extremeLevel) 
               extremeLevel = high;
         }
      }
      
      return extremeLevel;
   }

   //+------------------------------------------------------------------+
   //| Get best fallback TP/SL method when HL5 is too close             |
   //| @param isLong - true for LONG position, false for SHORT         |
   //| @param entryPrice - entry price of the trade                    |
   //| @param minDistance - minimum required distance                   |
   //| @return TPSLLevels - best fallback method result                |
   //+------------------------------------------------------------------+
   TPSLLevels GetBestFallbackTPSL(bool isLong, double entryPrice, double minDistance)
   {
      // Test all methods, return closest valid one above threshold
      TPSLLevels candidates[4];
      double distances[4];
      
      // Test ZBAND
      candidates[0] = CalculateZbandTPSL(isLong, entryPrice, m_zbandMultiplier);
      distances[0] = MathAbs(entryPrice - candidates[0].stopLoss);
      
      // Test ATR
      if(m_volatilityFilter != NULL)
      {
         double atr = m_volatilityFilter.GetATR();
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         
         candidates[1].stopLoss = isLong ? 
            entryPrice - (atr * m_atrMultiple) : 
            entryPrice + (atr * m_atrMultiple);
         candidates[1].takeProfit = isLong ? 
            entryPrice + (atr * m_atrMultiple) : 
            entryPrice - (atr * m_atrMultiple);
         distances[1] = MathAbs(entryPrice - candidates[1].stopLoss);
      }
      else
      {
         distances[1] = 0; // Invalid
      }
      
      // Test FIXED_POINTS
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      candidates[2].stopLoss = isLong ? 
         entryPrice - (m_fixedPoints * point) : 
         entryPrice + (m_fixedPoints * point);
      candidates[2].takeProfit = isLong ? 
         entryPrice + (m_fixedPoints * point) : 
         entryPrice - (m_fixedPoints * point);
      distances[2] = MathAbs(entryPrice - candidates[2].stopLoss);
      
      // Test PERCENT
      double tpDistance = entryPrice * (m_percent / 100.0);
      candidates[3].stopLoss = isLong ? 
         entryPrice - tpDistance : 
         entryPrice + tpDistance;
      candidates[3].takeProfit = isLong ? 
         entryPrice + tpDistance : 
         entryPrice - tpDistance;
      distances[3] = MathAbs(entryPrice - candidates[3].stopLoss);
      
      // Find closest valid method (distance >= minDistance)
      int bestIdx = -1;
      double closestValid = DBL_MAX;
      
      for(int i = 0; i < 4; i++)
      {
         if(distances[i] >= minDistance && distances[i] < closestValid)
         {
            closestValid = distances[i];
            bestIdx = i;
         }
      }
      
      if(bestIdx >= 0)
      {
         Logger::Info(StringFormat("Using fallback method %d with distance %.5f", bestIdx + 1, closestValid));
         return candidates[bestIdx];
      }
      else
      {
         Logger::Warning("All fallback methods too close, using ZBAND default");
         return candidates[0]; // Default to ZBAND
      }
   }

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
