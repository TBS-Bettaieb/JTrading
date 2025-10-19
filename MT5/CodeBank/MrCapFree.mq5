//+------------------------------------------------------------------+
//|                                                   MrCapFree.mq5  |
//|                                    Reconstructed from Screenshots |
//+------------------------------------------------------------------+
#property copyright "MrCapFree"
#property version   "1.00"
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
//| Global Variables                                                 |
//+------------------------------------------------------------------+

ENUM_RESTRICTION_REASON LastRestrictionReason = NO_RESTRICTION;

//+------------------------------------------------------------------+
//| Input Parameters - Trading Time Settings                        |
//+------------------------------------------------------------------+
input group "Trading Time Settings"
input ENUM_TIMEFRAMES      Timeframe           = PERIOD_M5;      // Timeframe for the EA
input bool                 TradingTime         = true;           // Enable Trading Time Restrictions
input ENUM_TIMEFRAME_SELECTION TimeSelection   = BROKER_TIME;    // Time Reference
input int                  TradingStartHour    = 7;              // Start Hour (00-23)
input int                  TradingEndHour      = 21;             // End Hour (00-23)

bool EnableTradingTime = TradingTime;

//+------------------------------------------------------------------+
//| Input Parameters - Lot Size Management                          |
//+------------------------------------------------------------------+
input group "Lot Size Management"
input ENUM_LOT_SIZE_MODE   LotSizeMode         = FIXED_LOTS;     // Lot Size Calculation Method
input double               RiskPercentage      = 1.0;            // Risk Percentage (for % modes)
input double               FixedRiskAmount     = 50.0;           // Fixed Risk Amount ($)
input double               FixedLotSize        = 0.05;           // Fixed Lot Size (for Fixed Lots mode)

//+------------------------------------------------------------------+
//| Input Parameters - Other Stuff                                  |
//+------------------------------------------------------------------+
input group "other stuff"
input double               Sar_period          = 0.5;            // Sar Period
input int                  Step                = 25;             // Sar Buffer (in Points)
input int                  MinTimeLapse        = 9;              // Minimum Time Lapse
input int                  PriceMvmtThreshold  = 70;             // Price Movement Threshold
input int                  StopActivationPoints = 60;            // Points in Loss when Stoploss is activated
input int                  StopActivationBuffer = 25;            // StopLoss Activation Buffer
input int                  Magic               = 11111111;       // EA Magic Number

int StopLoss = (StopActivationPoints + StopActivationBuffer)*2;

//+------------------------------------------------------------------+
//| Input Parameters - News Filter Settings                         |
//+------------------------------------------------------------------+
input group "News Filter Settings"
input bool                 NewsFilterOn        = false;          // Enable News Filter
input string               NewsCurrencies      = "USD";          // Affected Currencies (comma sep)
input string               KeyNews             = "NFP,JOLTS,Nonfarm,PMI,Interest Rate"; // High Impact
input int                  StopBeforeMin       = 30;             // Minutes Before News to Stop Trading
input int                  StartTradingMin     = 10;             // Minutes After News to Resume
input int                  DaysNewsLookup      = 100;            // Days Ahead to Check News
input ENUM_SEPARATOR       separator           = 0;              // List Separator

bool        TrDisabledNews = false;
datetime    LastNewsAvoided = 0;
string      TradingEnabledComm = "";
string      Newstoavoid[];

//+------------------------------------------------------------------+
//| Input Parameters - Trading Day Settings                         |
//+------------------------------------------------------------------+
input group "Trading Day Settings"
input bool                 EnableDayFilter     = false;          // Enable Day of Week Filter
input bool                 TradeMonday         = true;           // Allow Trading on Monday
input bool                 TradeTuesday        = true;           // Allow Trading on Tuesday
input bool                 TradeWednesday      = true;           // Allow Trading on Wednesday
input bool                 TradeThursday       = true;           // Allow Trading on Thursday
input bool                 TradeFriday         = true;           // Allow Trading on Friday
input bool                 TradeSaturday       = true;           // Allow Trading on Saturday
input bool                 TradeSunday         = true;           // Allow Trading on Sunday

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+

double      Current_Spread;
double      Average_Spread;
int         MinimumProfitLockIn          = 33;
int         Spread_Array_Size            = 100;
double      profit_target_threshold      = 0;
int         Time_Difference;
int         Sell_Order_Time;
double      Price_Movement;
int         Max_Concurrent_Orders        = 1;
double      SAR_Buy_Level;
int         Order_Slippage               = 10;
double      SAR_Sell_Level;
string      EA_Comment                   = "MrCapFree";
int         Buy_Order_Time;
double      Step_Points;
double      Trailing_Distance_Sell;
double      Trailing_Distance_Buy;
double      StopPoints;
double      Spread_History_Array[];
double      Price_History_Array[];
int         Time_History_Array[];

int         sar_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   
   trade.SetExpertMagicNumber(Magic);
   
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   
   sar_handle = iSAR(_Symbol, Timeframe, Sar_period, 0.2);
   if(sar_handle == INVALID_HANDLE)
   {
      Print("Failed to create SAR indicator handle");
      return INIT_FAILED;
   }
   
   // Add time validation
   if(TradingTime)
   {
      if(TradingStartHour < 0 || TradingStartHour > 23 || TradingEndHour < 0 || TradingEndHour > 23)
      {
         ShowAlert("?? INVALID HOURS! Must be between 00-23. Trading time disabled.");
         EnableTradingTime = false;
      }
      else if(TradingStartHour == TradingEndHour)
      {
         ShowAlert("?? START HOUR = END HOUR! Trading time disabled.");
         EnableTradingTime = false;
      }
   }
   
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
   
   int buy_stop_orders_count = 0;
   int sell_stop_orders_count = 0;
   int Order_Count = 0;
   int order_loop_index = 0;
   double total_current_profit = 0;
   double lowest_open_price = 1000000;
   double highest_open_price = 0;
   
   double Ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
   Current_Spread = NormalizeDouble((Ask - Bid), _Digits);
   Average_Spread = Current_Spread;
   ArrayResize(Spread_History_Array, Spread_Array_Size, 0);
   
   if (Spread_Array_Size != 0) {
      ArrayFill(Spread_History_Array, 0, Spread_Array_Size, Average_Spread);
   }
   
   update_price_movement_data(Ask, Bid);
   
   // Loop through pending orders
   for (int i = OrdersTotal()-1; i>=0; i--){
      if ( !ordinfo.SelectByIndex(i) ) continue;
      if(ordinfo.Symbol() != _Symbol || ordinfo.Magic() != Magic) continue;
      
      Order_Count++;
      int CurrTime = (int) TimeCurrent();
      
      if (ordinfo.OrderType() == ORDER_TYPE_BUY_STOP){
         Time_Difference = CurrTime - Buy_Order_Time;
         if (Time_Difference > MinTimeLapse && (Price_Movement < (_Point * PriceMvmtThreshold))) {
            trade.OrderDelete(ordinfo.Ticket());
         }
         buy_stop_orders_count++;
      }
      
      if (ordinfo.OrderType() == ORDER_TYPE_SELL_STOP){
         Time_Difference = CurrTime - Sell_Order_Time;
         if (Time_Difference > MinTimeLapse && (Price_Movement > (_Point * -PriceMvmtThreshold))) {
            trade.OrderDelete(ordinfo.Ticket());
         }
         sell_stop_orders_count++;
      }
   }
   
   // Loop through open positions
   for (int i = PositionsTotal()-1; i>=0; i--){
      if( !posinfo.SelectByIndex(i) ) continue;
      if( posinfo.Symbol() != _Symbol || posinfo.Magic() != Magic ) continue;
      Order_Count++;
      
      if( posinfo.PositionType() == POSITION_TYPE_BUY ){
         if ( Price_Movement < (_Point * -PriceMvmtThreshold) && (Bid < posinfo.PriceOpen() - (_Point * StopActivationPoints))){
            if (posinfo.StopLoss() == 0) {
               StopPoints = (StopActivationBuffer * _Point);
               trade.PositionModify(posinfo.Ticket(), Bid - StopPoints, posinfo.TakeProfit());
            }
         }
      }
      
      if( posinfo.PositionType() == POSITION_TYPE_SELL ){
         if ((Price_Movement > (_Point * PriceMvmtThreshold)) && (Ask > ((_Point * StopActivationPoints) + posinfo.PriceOpen()))){
            if (posinfo.StopLoss() == 0 ) {
               StopPoints = (StopActivationBuffer * _Point);
               trade.PositionModify(posinfo.Ticket(), Ask + StopPoints, posinfo.TakeProfit());
            }
         }
      }
      
      total_current_profit = (total_current_profit + posinfo.Profit());
      if (posinfo.PriceOpen() < lowest_open_price) {
         lowest_open_price = posinfo.PriceOpen();
      }
      if (posinfo.PriceOpen() > highest_open_price) {
         highest_open_price = posinfo.PriceOpen();
      }
   }
   
   // Close all positions if profit target reached
   if ((total_current_profit > profit_target_threshold)) {
      for (int i = PositionsTotal() - 1; i >= 0; i--){
         if( !posinfo.SelectByIndex(i) ) continue;
         if( posinfo.Symbol() != _Symbol || posinfo.Magic() != Magic ) continue;
         trade.PositionClose(posinfo.Ticket());
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check Trading Filters                                            |
   //+------------------------------------------------------------------+
   static bool alertShown = false;
   bool timeOK = !EnableTradingTime || IsWithinTradingHours();
   bool dayOK = !EnableDayFilter || IsTradingDayAllowed();
   bool newsOK = !NewsFilterOn || !IsUpcomingNews();
   
   ENUM_RESTRICTION_REASON currentReason = NO_RESTRICTION;
   
   if(!timeOK && !dayOK && !newsOK) currentReason = ALL_RESTRICTIONS;
   else if(!timeOK && !dayOK) currentReason = TIME_DAY_RESTRICTION;
   else if(!timeOK && !newsOK) currentReason = TIME_NEWS_RESTRICTION;
   else if(!dayOK && !newsOK) currentReason = DAY_NEWS_RESTRICTION;
   else if(!timeOK) currentReason = TIME_RESTRICTION;
   else if(!dayOK) currentReason = DAY_RESTRICTION;
   else if(!newsOK) currentReason = NEWS_RESTRICTION;
   

   if(currentReason != NO_RESTRICTION)
   {
      if(currentReason != LastRestrictionReason || !alertShown)
      {
         string alertMsg = GetRestrictionMessage(currentReason);
         ShowTradingHourAlert(alertMsg);
         alertShown = true;
         LastRestrictionReason = currentReason;
      }
      return;
   }
   else
   {
      if(LastRestrictionReason != NO_RESTRICTION || alertShown)
      {
         ShowTradingHourAlert("");
         alertShown = false;
         LastRestrictionReason = NO_RESTRICTION;
      }
   }


   //+------------------------------------------------------------------+
   //| Place New Orders                                                 |
   //+------------------------------------------------------------------+
   if (Order_Count < Max_Concurrent_Orders) {
      
      if ((Price_Movement > (_Point * StopActivationPoints))) {
         
         double sar_values[1];
         CopyBuffer(sar_handle, 0, 1, 1, sar_values);
         SAR_Buy_Level = (Step * _Point);
         SAR_Buy_Level = (sar_values[0] - SAR_Buy_Level);
         if ( SAR_Buy_Level > Ask  && (((Step * _Point) + Ask) < lowest_open_price)) {
            Step_Points = (Step * _Point);
            trade.BuyStop(CalculateLotSize(), (Ask + Step_Points), _Symbol, 0, 0, ORDER_TIME_GTC, 0, EA_Comment);
            Buy_Order_Time = (int) TimeCurrent();
         }
      }
      
      if ((Price_Movement < (_Point * -StopActivationPoints))) {
         
         double sar_values[1];
         CopyBuffer(sar_handle, 0, 1, 1, sar_values);
         SAR_Sell_Level = (Step * _Point);
         SAR_Sell_Level = (sar_values[0] + SAR_Sell_Level);
         if ((SAR_Sell_Level < Bid)) {
            SAR_Sell_Level = (Step * _Point);
            if (((Bid - SAR_Sell_Level) > highest_open_price)) {
               Step_Points = (Step * _Point);
               trade.SellStop(CalculateLotSize(), (Bid - Step_Points), _Symbol, 0, 0, ORDER_TIME_GTC, 0 , EA_Comment);
               Sell_Order_Time = (int) TimeCurrent();
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update Price Movement Data                                       |
//+------------------------------------------------------------------+
void update_price_movement_data(double Ask, double Bid){

   int    currentTimestamp;
   double currentBidPrice;
   double historicalBidPrice;
   int    historyIndex;
   
   // Shift array elements left (more efficient than ArrayCopy)
   for(int i = 0; i < Spread_Array_Size - 1; i++){
      Spread_History_Array[i] = Spread_History_Array[i+1];
   }
   
   // Add new spread at the end
   Spread_History_Array[Spread_Array_Size-1] = NormalizeDouble(Ask - Bid, _Digits);
   
   double sum = 0.0;
   for(int i = 0; i < Spread_Array_Size; i++){
      sum += Spread_History_Array[i];
   }
   Average_Spread = sum / Spread_Array_Size;
   
   double tempPriceArray[];
   double tempTimeArray[];
   
   ArrayResize(tempPriceArray, Spread_Array_Size - 1);
   ArrayResize(tempTimeArray, Spread_Array_Size - 1);
   ArrayCopy(tempPriceArray, Price_History_Array, 0, 1, Spread_Array_Size - 1);
   ArrayCopy(tempTimeArray, Time_History_Array, 0, 1, Spread_Array_Size - 1);
   ArrayResize(tempPriceArray, Spread_Array_Size);
   ArrayResize(tempTimeArray, Spread_Array_Size);
   tempPriceArray[Spread_Array_Size - 1] = Bid;
   tempTimeArray[Spread_Array_Size - 1] = (int)TimeCurrent();
   ArrayCopy(Price_History_Array, tempPriceArray);
   ArrayCopy(Time_History_Array, tempTimeArray);
   
   currentTimestamp = (int)Time_History_Array[Spread_Array_Size - 1];
   currentBidPrice = Price_History_Array[Spread_Array_Size - 1];
   historicalBidPrice = 0;
   
   for (historyIndex = Spread_Array_Size - 1; historyIndex >= 0; historyIndex--)
   {
      int secondsElapsed = currentTimestamp - Time_History_Array[historyIndex];
      if (secondsElapsed > MinTimeLapse)
      {
         historicalBidPrice = Price_History_Array[historyIndex];
         break;
      }
   }
   
   Price_Movement = currentBidPrice - historicalBidPrice;
   
   if (Price_Movement / _Point > 1000)
      Price_Movement = 0;
   
   ArrayFree(tempPriceArray);
   ArrayFree(tempTimeArray);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(){
   double lotSize = FixedLotSize;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   //--- Basic validation checks
   if(StopLoss <= 0)
   {
      ShowAlert("?? INVALID STOPLOSS! Using fixed lots");
      return FixedLotSize;
   }
   
   if(tickValue <= 0 || tickSize <= 0)
   {
      ShowAlert("?? BROKER DATA ERROR! Using fixed lots");
      return FixedLotSize;
   }
   
   if(lotStep <= 0)
   {
      ShowAlert("?? INVALID LOT STEP! Using fixed lots");
      return FixedLotSize;
   }
   
   //--- Calculate based on selected mode
   switch(LotSizeMode)
   {
      case FIXED_LOTS:
         lotSize = FixedLotSize;
         ShowAlert(StringFormat("LOTS: %.2f (FIXED)", lotSize));
         break;
         
      case PCT_ACCOUNT_BALANCE:
         lotSize = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercentage / 100) /
                   (StopLoss / lotStep * tickValue * tickSize);
         ShowAlert(StringFormat("LOTS: %.2f (%.1f%% of $%.0f Balance)", lotSize, RiskPercentage, AccountInfoDouble(ACCOUNT_BALANCE)));
         break;
         
      case PCT_EQUITY:
         lotSize = (AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercentage / 100) /
                   (StopLoss / lotStep * tickValue * tickSize);
         ShowAlert(StringFormat("LOTS: %.2f (%.1f%% of $%.0f Equity)", lotSize, RiskPercentage, AccountInfoDouble(ACCOUNT_EQUITY)));
         break;
         
      case PCT_FREE_MARGIN:
         lotSize = (AccountInfoDouble(ACCOUNT_MARGIN_FREE) * RiskPercentage / 100) /
                   (StopLoss / lotStep * tickValue * tickSize);
         ShowAlert(StringFormat("LOTS: %.2f (%.1f%% of $%.0f Free Margin)", lotSize, RiskPercentage, AccountInfoDouble(ACCOUNT_MARGIN_FREE)));
         break;
         
      case FIXED_RISK_PER_TRADE:
         lotSize = FixedRiskAmount /
                   (StopLoss / lotStep * tickValue * tickSize);
         ShowAlert(StringFormat("LOTS: %.2f ($%.0f Risk)", lotSize, FixedRiskAmount));
         break;
   }
   
   //--- Normalize to broker's lot step
   lotSize = NormalizeDouble(floor(lotSize / lotStep) * lotStep, _Digits);
   
   //--- Check against minimum/maximum allowed lots
   if(lotSize < minLot)
   {
      ShowAlert(StringFormat("?? LOTS TOO SMALL! Using min %.2f", minLot));
      lotSize = minLot;
   }
   else if(lotSize > maxLot)
   {
      ShowAlert(StringFormat("?? LOTS TOO BIG! Using max %.2f", maxLot));
      lotSize = maxLot;
   }
   
   //--- Margin check
   double marginRequired;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotSize, ask, marginRequired))
   {
      ShowAlert("?? MARGIN CALCULATION FAILED! Using min lot");
      return minLot;
   }
   
   if(marginRequired > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      ShowAlert("?? MARGIN WARNING! Reducing lots...");
      
      // Calculate maximum possible lot size
      while(lotSize > minLot)
      {
         if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotSize, ask, marginRequired))
         {
            if(marginRequired <= AccountInfoDouble(ACCOUNT_MARGIN_FREE))
               break;
         }
         lotSize = MathMax(minLot, lotSize - lotStep);
      }
      
      ShowAlert(StringFormat("ADJUSTED LOTS: %.2f", lotSize));
   }
   
   profit_target_threshold = lotSize * (StopLoss / lotStep * tickValue * tickSize);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   if(!EnableTradingTime) return true; // Always true if not enabled
   
   datetime currentTime;
   if(TimeSelection == GMT_TIME) {
      currentTime = TimeGMT();
   } else {
      currentTime = TimeCurrent();
   }
   
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   int hournow = timeStruct.hour;
   // Handle overnight sessions (e.g., 20:00 to 04:00)
   if(TradingStartHour > TradingEndHour) {
      return (timeStruct.hour >= TradingStartHour) || (timeStruct.hour < TradingEndHour);
   } else {
      return (timeStruct.hour >= TradingStartHour) && (timeStruct.hour < TradingEndHour);
   }
}

//+------------------------------------------------------------------+
//| Check if trading allowed on current day                          |
//+------------------------------------------------------------------+
bool IsTradingDayAllowed()
{
   if(!EnableDayFilter) return true; // Always true if not enabled
   
   datetime currentTime;
   if(TimeSelection == GMT_TIME) {
      currentTime = TimeGMT();
   } else {
      currentTime = TimeCurrent();
   }
   
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   switch(timeStruct.day_of_week)
   {
      case 0: return TradeSunday;    // Sunday
      case 1: return TradeMonday;    // Monday
      case 2: return TradeTuesday;   // Tuesday
      case 3: return TradeWednesday; // Wednesday
      case 4: return TradeThursday;  // Thursday
      case 5: return TradeFriday;    // Friday
      case 6: return TradeSaturday;  // Saturday
   }
   
   return true; // Default allow if unknown day
}

//+------------------------------------------------------------------+
//| Check for upcoming news                                          |
//+------------------------------------------------------------------+
bool IsUpcomingNews()
{
   if(!NewsFilterOn) return false;
   
   if(TrDisabledNews && TimeCurrent()-LastNewsAvoided < StartTradingMin*60)
   {
      TradingEnabledComm = "Waiting " + IntegerToString(StartTradingMin) +
                          "min after news before trading";
      return true;
   }
   
   TrDisabledNews = false;
   string sep = (separator == COMMA) ? "," : ";";
   ushort sep_code = StringGetCharacter(sep,0);
   
   int k = StringSplit(KeyNews, sep_code, Newstoavoid);
   if(k <= 0) return false;
   
   MqlCalendarValue values[];
   datetime starttime = TimeCurrent();
   datetime endtime = starttime + 86400*DaysNewsLookup;
   
   if(!CalendarValueHistory(values, starttime, endtime)) return false;
   
   for(int i = 0; i < ArraySize(values); i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event)) continue;
      
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country)) continue;
      
      if(StringFind(NewsCurrencies, country.currency) < 0) continue;
      
      for(int j = 0; j < k; j++)
      {
         if(StringFind(event.name, Newstoavoid[j]) >= 0)
         {
            datetime newsTime = values[i].time;
            int secondsBefore = StopBeforeMin * 60;
            
            if(newsTime - TimeCurrent() < secondsBefore)
            {
               LastNewsAvoided = newsTime;
               TrDisabledNews = true;
               TradingEnabledComm = "Trading disabled: " + country.currency +
                                   " " + event.name + " at " +
                                   TimeToString(newsTime, TIME_MINUTES);
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Show Alert Function                                              |
//+------------------------------------------------------------------+
void ShowAlert(string message){

   // Delete previous alert if exists
   ObjectDelete(0, "LOT_SIZE_ALERT");
   
   if(message=="") return;
   
   // Create the alert object
   if(!ObjectCreate(0, "LOT_SIZE_ALERT", OBJ_LABEL, 0, 0, 0))
   {
      Print("Failed to create alert object! Error: ", GetLastError());
      return;
   }
   
   // Set text properties
   ObjectSetString(0, "LOT_SIZE_ALERT", OBJPROP_TEXT, "• " + message + " •");
   ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_BGCOLOR, clrNavy);
   ObjectSetString(0, "LOT_SIZE_ALERT", OBJPROP_FONT, "Arial Black");
   
   // Position at top-left corner with some padding
   ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_XDISTANCE, 10);  // 10 pixels from left
   ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_YDISTANCE, 25);  // 25 pixels from top
   
   ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_BACK, false);
   
   // Make it blink for warnings
   if(StringFind(message, "??", 0) >= 0)
   {
      for(int i = 0; i < 3; i++)
      {
         ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_COLOR, clrRed);
         ChartRedraw();
         Sleep(300);
         ObjectSetInteger(0, "LOT_SIZE_ALERT", OBJPROP_COLOR, clrGold);
         ChartRedraw();
         Sleep(300);
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+


string GetRestrictionMessage(ENUM_RESTRICTION_REASON reason)
{
    switch(reason)
    {
        case TIME_RESTRICTION: return "Outside Trading Hours - EA Paused";
        case DAY_RESTRICTION: return "Trading Day Restricted - EA Paused";
        case NEWS_RESTRICTION: return TradingEnabledComm;
        case TIME_DAY_RESTRICTION: return "Outside Hours & Day Restricted - EA Paused";
        case TIME_NEWS_RESTRICTION: return "Outside Hours & News Event - EA Paused";
        case DAY_NEWS_RESTRICTION: return "Day Restricted & News Event - EA Paused";
        case ALL_RESTRICTIONS: return "Outside Hours, Day Restricted & News - EA Paused";
    }
    return "";
}


void ShowTradingHourAlert(string message)
{
   // Delete previous alert if exists
ObjectDelete(0, "Trading_Hour_Alert");

if(message=="") return;

// Create the alert object
if(!ObjectCreate(0, "Trading_Hour_Alert", OBJ_LABEL, 0, 0, 0))
{
    Print("Failed to create alert object! Error: ", GetLastError());
    return;
}

// Set text properties - CORRECTED FONT SETTING

ObjectSetString(0, "Trading_Hour_Alert", OBJPROP_TEXT, "• " + message + " •");
ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_FONTSIZE, 14);
ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_COLOR, clrGold);
ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_BGCOLOR, clrNavy);
ObjectSetString(0, "Trading_Hour_Alert", OBJPROP_FONT, "Arial Black");

// Position at center of chart
int xPos = (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2);
int yPos = (int)(ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) / 2);

ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_ANCHOR, ANCHOR_CENTER);
ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_XDISTANCE, xPos);
ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_YDISTANCE, yPos);
ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_BACK, false);

// Make it blink for warnings
if(StringFind(message, "?") >= 0)
{
    for(int i = 0; i < 3; i++)
    {
        ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_COLOR, clrRed);
        ChartRedraw();
        Sleep(300);
        ObjectSetInteger(0, "Trading_Hour_Alert", OBJPROP_COLOR, clrGold);
        ChartRedraw();
        Sleep(300);
    }
}
ChartRedraw();
}


