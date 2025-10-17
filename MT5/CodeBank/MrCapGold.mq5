//+------------------------------------------------------------------+
//|                                                   MrCapGold.mq5  |
//|                              Optimized for XAUUSD (Gold Trading) |
//+------------------------------------------------------------------+
#property copyright "MrCapGold XAUUSD Edition"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade trade;
CPositionInfo posinfo;
COrderInfo ordinfo;

//+------------------------------------------------------------------+
//| ================ ENUMS =======================================  |
//+------------------------------------------------------------------+

enum ENUM_RESTRICTION_REASON {
   NO_RESTRICTION,
   TIME_RESTRICTION,
   DAY_RESTRICTION,
   NEWS_RESTRICTION,
   TIME_DAY_RESTRICTION,
   TIME_NEWS_RESTRICTION,
   DAY_NEWS_RESTRICTION,
   ALL_RESTRICTIONS
};

enum ENUM_TIMEFRAME_SELECTION {
   GMT_TIME,           // GMT Time
   BROKER_TIME         // Broker Server Time
};

enum ENUM_SEPARATOR {
   COMMA=0,            // Comma (,)
   SEMICOLON=1         // Semicolon (;)
};

enum ENUM_LOT_SIZE_MODE {
   FIXED_LOTS,              // Fixed Lots
   PCT_ACCOUNT_BALANCE,     // % of Account Balance
   PCT_EQUITY,              // % of Equity
   PCT_FREE_MARGIN,         // % of Free Margin
   FIXED_RISK_PER_TRADE     // Fixed $ Risk per Trade
};

//+------------------------------------------------------------------+
//| Input Parameters - Trading Time Settings                        |
//+------------------------------------------------------------------+
input group "=== GOLD TRADING SETTINGS ==="
input ENUM_TIMEFRAMES      Timeframe           = PERIOD_M15;     // Timeframe for Gold
input bool                 TradingTime         = true;           // Enable Trading Time Restrictions
input ENUM_TIMEFRAME_SELECTION TimeSelection   = BROKER_TIME;    // Time Reference
input int                  TradingStartHour    = 1;              // Start Hour (Asian Session)
input int                  TradingEndHour      = 22;             // End Hour (Before NY Close)

bool EnableTradingTime = TradingTime;

//+------------------------------------------------------------------+
//| Input Parameters - Lot Size Management                          |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input ENUM_LOT_SIZE_MODE   LotSizeMode         = FIXED_RISK_PER_TRADE; // Lot Size Calculation Method
input double               RiskPercentage      = 1.0;            // Risk Percentage (for % modes)
input double               FixedRiskAmount     = 100.0;          // Fixed Risk Amount ($) - Higher for Gold
input double               FixedLotSize        = 0.05;           // Fixed Lot Size (for Fixed Lots mode)

//+------------------------------------------------------------------+
//| Input Parameters - Gold Specific Parameters                     |
//+------------------------------------------------------------------+
input group "=== GOLD STRATEGY PARAMETERS ==="
input double               Sar_period          = 0.02;           // SAR Period (more sensitive for Gold)
input int                  Step                = 300;            // SAR Step (in Points) - Larger for Gold volatility
input int                  MinTimeLapse        = 30;             // Minimum Time Lapse (minutes)
input int                  PriceMvmtThreshold  = 500;            // Price Movement Threshold (points)
input int                  StopActivationPoints = 200;           // Points in Loss when Stoploss is activated
input int                  StopActivationBuffer = 150;           // StopLoss Activation Buffer
input int                  Magic               = 222222;         // EA Magic Number

//+------------------------------------------------------------------+
//| Input Parameters - Enhanced Gold Risk Management                |
//+------------------------------------------------------------------+
input group "=== ENHANCED GOLD MANAGEMENT ==="
input bool                 UseTrailingStop     = true;           // Enable Trailing Stop for Gold
input int                  BreakevenAtPoints   = 300;            // Activate breakeven at (points)
input double               TrailingStep        = 0.3;            // Trailing step (multiplier of SL)
input bool                 UseVolatilityAdjustment = true;       // Adjust parameters by volatility
input int                  MaxOrdersPerDirection = 1;            // Max orders per direction
input double               MaxDailyLoss        = 500.0;          // Max daily loss ($)
input bool                 CloseOnFriday       = true;           // Close all before weekend

//+------------------------------------------------------------------+
//| Input Parameters - News Filter Settings                         |
//+------------------------------------------------------------------+
input group "=== NEWS FILTER ==="
input bool                 NewsFilterOn        = true;           // Enable News Filter for Gold
input string               NewsCurrencies      = "USD,XAU";      // Affected Currencies for Gold
input string               KeyNews             = "NFP,Nonfarm,CPI,Inflation,Rate Decision,FOMC"; // High Impact for Gold
input int                  StopBeforeMin       = 60;             // Minutes Before News to Stop Trading
input int                  StartTradingMin     = 30;             // Minutes After News to Resume
input int                  DaysNewsLookup      = 30;             // Days Ahead to Check News
input ENUM_SEPARATOR       separator           = 0;              // List Separator

//+------------------------------------------------------------------+
//| Input Parameters - Trading Day Settings                         |
//+------------------------------------------------------------------+
input group "=== TRADING DAYS ==="
input bool                 EnableDayFilter     = true;           // Enable Day of Week Filter
input bool                 TradeMonday         = true;           // Allow Trading on Monday
input bool                 TradeTuesday        = true;           // Allow Trading on Tuesday
input bool                 TradeWednesday      = true;           // Allow Trading on Wednesday
input bool                 TradeThursday       = true;           // Allow Trading on Thursday
input bool                 TradeFriday         = true;           // Allow Trading on Friday
input bool                 TradeSaturday       = false;          // No Trading on Saturday
input bool                 TradeSunday         = false;          // No Trading on Sunday

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+

ENUM_RESTRICTION_REASON LastRestrictionReason = NO_RESTRICTION;

double      Current_Spread;
double      Average_Spread;
int         MinimumProfitLockIn          = 100;
int         Spread_Array_Size            = 50;
double      profit_target_threshold      = 0;
int         Time_Difference;
int         Sell_Order_Time;
double      Price_Movement;
int         Max_Concurrent_Orders        = 2;
double      SAR_Buy_Level;
int         Order_Slippage               = 30;
double      SAR_Sell_Level;
string      EA_Comment                   = "MrCapGold";
int         Buy_Order_Time;
double      Step_Points;
double      Trailing_Distance_Sell;
double      Trailing_Distance_Buy;
double      StopPoints;
double      Spread_History_Array[];
double      Price_History_Array[];
int         Time_History_Array[];

// Gold specific variables
double      DailyProfitLoss              = 0;
double      DailyLossLimit               = 0;
datetime    LastDailyReset               = 0;
double      GoldVolatility               = 0;
bool        TradingEnabled               = true;
string      RestrictionReason            = "";

int         sar_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(Order_Slippage);
   
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   
   // Initialize SAR with Gold-optimized parameters
   sar_handle = iSAR(_Symbol, Timeframe, Sar_period, 0.2);
   if(sar_handle == INVALID_HANDLE) {
      Print("Failed to create SAR indicator handle for Gold");
      return INIT_FAILED;
   }
   
   // Initialize arrays for Gold price tracking
   ArrayResize(Price_History_Array, Spread_Array_Size);
   ArrayResize(Time_History_Array, Spread_Array_Size);
   ArrayResize(Spread_History_Array, Spread_Array_Size);
   ArrayInitialize(Price_History_Array, 0);
   ArrayInitialize(Time_History_Array, 0);
   ArrayInitialize(Spread_History_Array, 0);
   
   // Calculate initial Gold volatility
   GoldVolatility = CalculateGoldVolatility();
   Print("Initial Gold Volatility: ", GoldVolatility);
   
   // Set daily loss limit
   DailyLossLimit = MaxDailyLoss;
   LastDailyReset = iTime(_Symbol, PERIOD_D1, 0);
   
   // Validate trading hours for Gold
   if(TradingTime) {
      if(TradingStartHour < 0 || TradingStartHour > 23 || TradingEndHour < 0 || TradingEndHour > 23) {
         ShowAlert("?? INVALID HOURS! Must be between 00-23. Trading time disabled.");
         EnableTradingTime = false;
      }
      else if(TradingStartHour == TradingEndHour) {
         ShowAlert("?? START HOUR = END HOUR! Trading time disabled.");
         EnableTradingTime = false;
      }
   }
   
   Print("MrCapGold EA initialized successfully for XAUUSD");
   Print("Gold Volatility: ", GoldVolatility, " | Recommended Stop: ", StopActivationPoints + StopActivationBuffer, " points");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(sar_handle != INVALID_HANDLE)
      IndicatorRelease(sar_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   
   // Check for new day and reset daily counters
   CheckDailyReset();
   
   // Check if trading is allowed
   TradingEnabled = CheckTradingConditions();
   
   if(!TradingEnabled) {
      // Clean up pending orders if restrictions active
      if(EnableTradingTime || EnableDayFilter || NewsFilterOn) {
         DeleteAllPendingOrders();
      }
      // Close Friday positions if enabled
      if(CloseOnFriday && IsFridayCloseTime()) {
         CloseAllPositions();
      }
      return;
   }
   
   // Check daily loss limit
   if(DailyProfitLoss <= -DailyLossLimit) {
      ShowAlert("DAILY LOSS LIMIT REACHED! Trading stopped for today.");
      CloseAllPositions();
      DeleteAllPendingOrders();
      return;
   }
   
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   Current_Spread = NormalizeDouble((Ask - Bid), _Digits);
   UpdateSpreadHistory();
   UpdatePriceMovementData(Ask, Bid);
   
   // Manage existing positions
   ManageExistingPositions();
   
   // Manage pending orders
   ManagePendingOrders();
   
   // Place new orders if conditions met
   if(ShouldPlaceNewOrders()) {
      PlaceNewOrders();
   }
   
   // Update display
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Check all trading conditions                                     |
//+------------------------------------------------------------------+
bool CheckTradingConditions() {
   bool timeOK = !EnableTradingTime || IsWithinTradingHours();
   bool dayOK = !EnableDayFilter || IsTradingDayAllowed();
   bool newsOK = !NewsFilterOn || !IsUpcomingNews();
   
   if(!timeOK) {
      RestrictionReason = "Outside Gold trading hours";
      LastRestrictionReason = TIME_RESTRICTION;
      return false;
   }
   if(!dayOK) {
      RestrictionReason = "Trading not allowed today";
      LastRestrictionReason = DAY_RESTRICTION;
      return false;
   }
   if(!newsOK) {
      RestrictionReason = "Gold news event approaching";
      LastRestrictionReason = NEWS_RESTRICTION;
      return false;
   }
   
   RestrictionReason = "Gold trading enabled";
   LastRestrictionReason = NO_RESTRICTION;
   return true;
}

//+------------------------------------------------------------------+
//| Manage existing positions with enhanced trailing stops           |
//+------------------------------------------------------------------+
void ManageExistingPositions() {
   double totalProfit = 0;
   int positionCount = 0;
   
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol() != _Symbol || posinfo.Magic() != Magic) continue;
      
      totalProfit += posinfo.Profit();
      positionCount++;
      
      // Apply enhanced trailing stop for Gold
      if(UseTrailingStop) {
         ApplyGoldTrailingStop(posinfo);
      }
   }
   
   DailyProfitLoss = totalProfit;
   
   // Dynamic profit target for Gold
   if(totalProfit > CalculateDynamicProfitTarget()) {
      CloseAllPositions();
      ShowAlert("GOLD Profit target reached: $" + DoubleToString(totalProfit, 2));
   }
}

//+------------------------------------------------------------------+
//| Gold-optimized trailing stop                                    |
//+------------------------------------------------------------------+
void ApplyGoldTrailingStop(CPositionInfo &position) {
   double currentPrice = (position.PositionType() == POSITION_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double profitPoints = MathAbs(currentPrice - position.PriceOpen()) / _Point;
   double newStopLoss = position.StopLoss();
   
   // Breakeven at specified points for Gold
   if(profitPoints >= BreakevenAtPoints && position.StopLoss() == 0) {
      newStopLoss = position.PriceOpen();
      Print("Breakeven activated for position ", position.Ticket());
   }
   // Trailing stop after breakeven
   else if(profitPoints > BreakevenAtPoints * 1.5) {
      double trailDistance = (StopActivationPoints + StopActivationBuffer) * TrailingStep * _Point;
      if(position.PositionType() == POSITION_TYPE_BUY) {
         newStopLoss = MathMax(newStopLoss, currentPrice - trailDistance);
      } else {
         newStopLoss = MathMin(newStopLoss, currentPrice + trailDistance);
      }
   }
   
   if(newStopLoss != position.StopLoss()) {
      if(trade.PositionModify(position.Ticket(), newStopLoss, position.TakeProfit())) {
         Print("Trailing stop updated for position ", position.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Manage pending orders                                           |
//+------------------------------------------------------------------+
void ManagePendingOrders() {
   int buyStopCount = 0, sellStopCount = 0;
   
   for(int i = OrdersTotal()-1; i >= 0; i--) {
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol() != _Symbol || ordinfo.Magic() != Magic) continue;
      
      if(ordinfo.OrderType() == ORDER_TYPE_BUY_STOP) {
         buyStopCount++;
         ManageBuyStopOrder(ordinfo);
      }
      else if(ordinfo.OrderType() == ORDER_TYPE_SELL_STOP) {
         sellStopCount++;
         ManageSellStopOrder(ordinfo);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage buy stop orders                                          |
//+------------------------------------------------------------------+
void ManageBuyStopOrder(COrderInfo &order) {
   int currentTime = (int)TimeCurrent();
   Time_Difference = currentTime - Buy_Order_Time;
   
   if(Time_Difference > MinTimeLapse * 60 && (Price_Movement < (_Point * PriceMvmtThreshold))) {
      trade.OrderDelete(order.Ticket());
      Print("Buy stop order deleted due to time lapse");
   }
}

//+------------------------------------------------------------------+
//| Manage sell stop orders                                         |
//+------------------------------------------------------------------+
void ManageSellStopOrder(COrderInfo &order) {
   int currentTime = (int)TimeCurrent();
   Time_Difference = currentTime - Sell_Order_Time;
   
   if(Time_Difference > MinTimeLapse * 60 && (Price_Movement > (_Point * -PriceMvmtThreshold))) {
      trade.OrderDelete(order.Ticket());
      Print("Sell stop order deleted due to time lapse");
   }
}

//+------------------------------------------------------------------+
//| Place new orders based on Gold conditions                       |
//+------------------------------------------------------------------+
void PlaceNewOrders() {
   int currentOrders = PositionsTotal() + OrdersTotal();
   if(currentOrders >= Max_Concurrent_Orders * 2) return; // Considering both buy/sell
   
   double sar_values[1];
   if(CopyBuffer(sar_handle, 0, 1, 1, sar_values) <= 0) {
      Print("Failed to copy SAR buffer");
      return;
   }
   
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Buy conditions for Gold
   if((Price_Movement > (_Point * StopActivationPoints))) {
      SAR_Buy_Level = (Step * _Point);
      SAR_Buy_Level = (sar_values[0] - SAR_Buy_Level);
      
      if(SAR_Buy_Level > Ask) {
         double buyPrice = Ask + (Step * _Point);
         double lotSize = CalculateLotSize();
         double sl = buyPrice - (StopActivationPoints + StopActivationBuffer) * _Point;
         double tp = 0; // No take profit for Gold (use trailing)
         
         if(trade.BuyStop(lotSize, buyPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, EA_Comment)) {
            Buy_Order_Time = (int)TimeCurrent();
            Print("Gold BUY STOP placed at ", buyPrice, " Lot: ", lotSize);
         }
      }
   }
   
   // Sell conditions for Gold
   if((Price_Movement < (_Point * -StopActivationPoints))) {
      SAR_Sell_Level = (Step * _Point);
      SAR_Sell_Level = (sar_values[0] + SAR_Sell_Level);
      
      if(SAR_Sell_Level < Bid) {
         double sellPrice = Bid - (Step * _Point);
         double lotSize = CalculateLotSize();
         double sl = sellPrice + (StopActivationPoints + StopActivationBuffer) * _Point;
         double tp = 0; // No take profit for Gold (use trailing)
         
         if(trade.SellStop(lotSize, sellPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, EA_Comment)) {
            Sell_Order_Time = (int)TimeCurrent();
            Print("Gold SELL STOP placed at ", sellPrice, " Lot: ", lotSize);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size for Gold                                     |
//+------------------------------------------------------------------+
double CalculateLotSize() {
   double lotSize = FixedLotSize;
   
   if((StopActivationPoints + StopActivationBuffer) <= 0) {
      ShowAlert("?? INVALID STOPLOSS! Using fixed lots");
      return MathMin(FixedLotSize, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   }
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(tickValue <= 0 || tickSize <= 0 || lotStep <= 0) {
      ShowAlert("?? BROKER DATA ERROR! Using fixed lots");
      return MathMin(FixedLotSize, maxLot);
   }
   
   double riskAmount = 0;
   switch(LotSizeMode) {
      case FIXED_LOTS:
         lotSize = FixedLotSize;
         break;
         
      case PCT_ACCOUNT_BALANCE:
         riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercentage / 100;
         break;
         
      case PCT_EQUITY:
         riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercentage / 100;
         break;
         
      case PCT_FREE_MARGIN:
         riskAmount = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * RiskPercentage / 100;
         break;
         
      case FIXED_RISK_PER_TRADE:
         riskAmount = FixedRiskAmount;
         break;
   }
   
   if(LotSizeMode != FIXED_LOTS) {
      double riskPerLot = (StopActivationPoints + StopActivationBuffer) * tickValue / tickSize;
      if(riskPerLot > 0) {
         lotSize = riskAmount / riskPerLot;
         lotSize = NormalizeDouble(lotSize, 2);
      }
   }
   
   // Normalize and validate
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = NormalizeDouble(floor(lotSize / lotStep) * lotStep, 2);
   
   // Margin check for Gold (requires more margin)
   if(!CheckMarginRequirements(lotSize)) {
      lotSize = CalculateMaxLotByMargin();
   }
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Check margin requirements for Gold                              |
//+------------------------------------------------------------------+
bool CheckMarginRequirements(double lotSize) {
   double marginRequired;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotSize, ask, marginRequired)) {
      return false;
   }
   
   return (marginRequired <= AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.8); // 80% safety margin
}

//+------------------------------------------------------------------+
//| Calculate maximum lot by margin                                 |
//+------------------------------------------------------------------+
double CalculateMaxLotByMargin() {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double testLot = maxLot;
   double marginRequired;
   
   while(testLot >= minLot) {
      if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, testLot, ask, marginRequired)) {
         if(marginRequired <= AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.8) {
            return NormalizeDouble(testLot, 2);
         }
      }
      testLot -= lotStep;
   }
   
   return minLot;
}

//+------------------------------------------------------------------+
//| Calculate dynamic profit target for Gold                        |
//+------------------------------------------------------------------+
double CalculateDynamicProfitTarget() {
   double baseTarget = CalculateLotSize() * ((StopActivationPoints + StopActivationBuffer) * 
                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / 
                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   
   // Adjust based on Gold volatility
   if(UseVolatilityAdjustment) {
      double currentVolatility = CalculateGoldVolatility();
      if(currentVolatility > GoldVolatility * 1.2) {
         baseTarget *= 1.3; // Increase target in high volatility
      } else if(currentVolatility < GoldVolatility * 0.8) {
         baseTarget *= 0.8; // Decrease target in low volatility
      }
   }
   
   return baseTarget;
}

//+------------------------------------------------------------------+
//| Calculate Gold volatility                                       |
//+------------------------------------------------------------------+
double CalculateGoldVolatility() {
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   int bars = 20; // Look at last 20 bars
   CopyHigh(_Symbol, PERIOD_H1, 0, bars, highs);
   CopyLow(_Symbol, PERIOD_H1, 0, bars, lows);
   
   double totalRange = 0;
   int count = 0;
   for(int i = 0; i < bars; i++) {
      if(highs[i] > 0 && lows[i] > 0) {
         totalRange += (highs[i] - lows[i]);
         count++;
      }
   }
   
   return (count > 0) ? totalRange / count : 100 * _Point;
}

//+------------------------------------------------------------------+
//| Update price movement data                                      |
//+------------------------------------------------------------------+
void UpdatePriceMovementData(double Ask, double Bid) {
   // Shift array elements
   for(int i = 0; i < Spread_Array_Size - 1; i++) {
      Price_History_Array[i] = Price_History_Array[i + 1];
      Time_History_Array[i] = Time_History_Array[i + 1];
   }
   
   // Add new data
   Price_History_Array[Spread_Array_Size - 1] = Bid;
   Time_History_Array[Spread_Array_Size - 1] = (int)TimeCurrent();
   
   // Calculate price movement
   int currentTimestamp = Time_History_Array[Spread_Array_Size - 1];
   double currentBidPrice = Price_History_Array[Spread_Array_Size - 1];
   double historicalBidPrice = 0;
   
   for(int i = Spread_Array_Size - 1; i >= 0; i--) {
      int secondsElapsed = currentTimestamp - Time_History_Array[i];
      if(secondsElapsed > MinTimeLapse * 60) {
         historicalBidPrice = Price_History_Array[i];
         break;
      }
   }
   
   Price_Movement = currentBidPrice - historicalBidPrice;
   
   // Safety check for abnormal movements
   if(MathAbs(Price_Movement / _Point) > 5000) {
      Price_Movement = 0;
   }
}

//+------------------------------------------------------------------+
//| Update spread history                                           |
//+------------------------------------------------------------------+
void UpdateSpreadHistory() {
   // Shift array
   for(int i = 0; i < Spread_Array_Size - 1; i++) {
      Spread_History_Array[i] = Spread_History_Array[i + 1];
   }
   
   // Add new spread
   Spread_History_Array[Spread_Array_Size - 1] = Current_Spread;
   
   // Calculate average
   double sum = 0;
   for(int i = 0; i < Spread_Array_Size; i++) {
      sum += Spread_History_Array[i];
   }
   Average_Spread = sum / Spread_Array_Size;
}

//+------------------------------------------------------------------+
//| Check daily reset                                               |
//+------------------------------------------------------------------+
void CheckDailyReset() {
   datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
   if(currentDay > LastDailyReset) {
      DailyProfitLoss = 0;
      LastDailyReset = currentDay;
      Print("Daily counters reset for new trading day");
   }
}

//+------------------------------------------------------------------+
//| Check if should place new orders                                |
//+------------------------------------------------------------------+
bool ShouldPlaceNewOrders() {
   if(!TradingEnabled) return false;
   if(DailyProfitLoss <= -DailyLossLimit) return false;
   if(PositionsTotal() + OrdersTotal() >= Max_Concurrent_Orders * 2) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                       |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders() {
   for(int i = OrdersTotal()-1; i >= 0; i--) {
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol() != _Symbol || ordinfo.Magic() != Magic) continue;
      
      trade.OrderDelete(ordinfo.Ticket());
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                             |
//+------------------------------------------------------------------+
void CloseAllPositions() {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol() != _Symbol || posinfo.Magic() != Magic) continue;
      
      trade.PositionClose(posinfo.Ticket());
   }
}

//+------------------------------------------------------------------+
//| Check if Friday close time                                      |
//+------------------------------------------------------------------+
bool IsFridayCloseTime() {
   MqlDateTime timeStruct;
   TimeCurrent(timeStruct);
   
   if(timeStruct.day_of_week == 5) { // Friday
      if(timeStruct.hour >= 20) { // After 8 PM
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Trading hours check                                             |
//+------------------------------------------------------------------+
bool IsWithinTradingHours() {
   if(!EnableTradingTime) return true;
   
   datetime currentTime;
   if(TimeSelection == GMT_TIME) {
      currentTime = TimeGMT();
   } else {
      currentTime = TimeCurrent();
   }
   
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   int currentHour = timeStruct.hour;
   
   // Gold trading hours: Asian session through NY session
   if(TradingStartHour > TradingEndHour) {
      return (currentHour >= TradingStartHour) || (currentHour < TradingEndHour);
   } else {
      return (currentHour >= TradingStartHour) && (currentHour < TradingEndHour);
   }
}

//+------------------------------------------------------------------+
//| Trading day check                                               |
//+------------------------------------------------------------------+
bool IsTradingDayAllowed() {
   if(!EnableDayFilter) return true;
   
   datetime currentTime;
   if(TimeSelection == GMT_TIME) {
      currentTime = TimeGMT();
   } else {
      currentTime = TimeCurrent();
   }
   
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   switch(timeStruct.day_of_week) {
      case 0: return TradeSunday;
      case 1: return TradeMonday;
      case 2: return TradeTuesday;
      case 3: return TradeWednesday;
      case 4: return TradeThursday;
      case 5: return TradeFriday;
      case 6: return TradeSaturday;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| News check for Gold                                            |
//+------------------------------------------------------------------+
bool IsUpcomingNews() {
   if(!NewsFilterOn) return false;
   
   // Simplified news check - in practice, you'd use a news API
   MqlDateTime timeStruct;
   TimeCurrent(timeStruct);
   
   // Example: Avoid first Friday of month (NFP)
   if(timeStruct.day_of_week == 5 && timeStruct.day <= 7) {
      if(timeStruct.hour >= 7 && timeStruct.hour <= 10) {
         RestrictionReason = "NFP News Day - Trading paused";
         return true;
      }
   }
   
   // Add more specific Gold news checks here
   // This is a simplified version - consider integrating with news API
   
   return false;
}

//+------------------------------------------------------------------+
//| Show Alert Function                                             |
//+------------------------------------------------------------------+
void ShowAlert(string message) {
   Print("GOLD ALERT: ", message);
   
   // You can add visual alert logic here
   if(StringFind(message, "??", 0) >= 0) {
      // Blinking effect for warnings
      for(int i = 0; i < 2; i++) {
         Sleep(200);
      }
   }
}

//+------------------------------------------------------------------+
//| Update dashboard display                                        |
//+------------------------------------------------------------------+
void UpdateDashboard() {
   string dashboardText = "";
   dashboardText += "=== MR CAP GOLD DASHBOARD ===\n";
   dashboardText += "Status: " + RestrictionReason + "\n";
   dashboardText += "Daily P/L: $" + DoubleToString(DailyProfitLoss, 2) + "\n";
   dashboardText += "Gold Volatility: " + DoubleToString(GoldVolatility/_Point, 0) + " points\n";
   dashboardText += "Current Spread: " + DoubleToString(Current_Spread/_Point, 0) + " points\n";
   dashboardText += "Price Movement: " + DoubleToString(Price_Movement/_Point, 0) + " points\n";
   dashboardText += "Positions: " + IntegerToString(PositionsTotal()) + "\n";
   dashboardText += "Pending Orders: " + IntegerToString(OrdersTotal());
   
   Comment(dashboardText);
}

//+------------------------------------------------------------------+