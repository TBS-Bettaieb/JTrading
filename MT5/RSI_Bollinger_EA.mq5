//+------------------------------------------------------------------+
//|                                           RSI_Bollinger_EA.mq5   |
//|                        Bollinger + RSI Double Strategy           |
//|                        Based on ChartArt's Strategy v1.1         |
//+------------------------------------------------------------------+
#property copyright "Converted from PineScript"
#property link      ""
#property version   "1.00"
#property description "RSI + Bollinger Bands Strategy"
#property description "Buys when RSI and price cross above lower BB"
#property description "Sells when RSI and price cross below upper BB"

#include <Trade\Trade.mqh>
#include "..\EA\Shared\Logger.mqh"

//--- Input parameters
input group "=== Strategy Parameters ==="
input int      RSI_Period = 6;                    // RSI Period Length
input int      BB_Period = 200;                   // Bollinger Bands Period Length
input double   BB_Deviation = 2.0;                // Bollinger Bands Standard Deviation
input int      RSI_OverSold = 50;                 // RSI Oversold Level
input int      RSI_OverBought = 50;               // RSI Overbought Level

input group "=== Risk Management ==="
input double   RiskPercent = 2.0;                 // Risk Percent of Balance
input double   FixedLotSize = 0.0;                // Fixed Lot Size (0 = use risk %)
input int      StopLossPips = 0;                  // Stop Loss in Pips (0 = none)
input int      TakeProfitPips = 0;                // Take Profit in Pips (0 = none)

input group "=== Trading Settings ==="
input bool     AllowLong = true;                  // Allow Long Trades
input bool     AllowShort = true;                 // Allow Short Trades
input int      MagicNumber = 123456;              // Magic Number
input string   TradeComment = "RSI_BB";           // Trade Comment
input int      Slippage = 30;                     // Slippage in Points

//--- Global variables
CTrade trade;
int rsiHandle;
int bbHandle;
double rsiBuffer[];
double bbUpperBuffer[];
double bbLowerBuffer[];
double bbMiddleBuffer[];

double prevRSI = 0;
double prevPrice = 0;
double prevBBUpper = 0;
double prevBBLower = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize Logger
   Logger.Initialize(LOG_INFO, "RSI_Bollinger_EA");
   
   //--- Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   //--- Create RSI indicator
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
   {
      Logger.Error("Creating RSI indicator failed");
      return(INIT_FAILED);
   }
   
   //--- Create Bollinger Bands indicator
   bbHandle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   if(bbHandle == INVALID_HANDLE)
   {
      Logger.Error("Creating Bollinger Bands indicator failed");
      return(INIT_FAILED);
   }
   
   //--- Set array as series
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(bbUpperBuffer, true);
   ArraySetAsSeries(bbLowerBuffer, true);
   ArraySetAsSeries(bbMiddleBuffer, true);
   
   Logger.Success("EA initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(bbHandle != INVALID_HANDLE)
      IndicatorRelease(bbHandle);
      
   Logger.Info("EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime == lastBarTime)
      return;
      
   lastBarTime = currentBarTime;
   
   //--- Update indicators
   if(!UpdateIndicators())
      return;
   
   //--- Get current values
   double currentRSI = rsiBuffer[0];
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double currentBBUpper = bbUpperBuffer[0];
   double currentBBLower = bbLowerBuffer[0];
   
   //--- Check for trading signals
   bool longSignal = false;
   bool shortSignal = false;
   
   //--- Long signal: RSI crosses above oversold AND price crosses above lower BB
   if(prevRSI != 0 && prevPrice != 0)
   {
      if(prevRSI <= RSI_OverSold && currentRSI > RSI_OverSold &&
         prevPrice <= prevBBLower && currentPrice > currentBBLower)
      {
         longSignal = true;
      }
      
      //--- Short signal: RSI crosses below overbought AND price crosses below upper BB
      if(prevRSI >= RSI_OverBought && currentRSI < RSI_OverBought &&
         prevPrice >= prevBBUpper && currentPrice < currentBBUpper)
      {
         shortSignal = true;
      }
   }
   
   //--- Store current values for next bar
   prevRSI = currentRSI;
   prevPrice = currentPrice;
   prevBBUpper = currentBBUpper;
   prevBBLower = currentBBLower;
   
   //--- Execute trades
   if(longSignal && AllowLong)
   {
      if(!HasPosition(POSITION_TYPE_BUY))
      {
         CloseAllPositions(POSITION_TYPE_SELL);
         OpenPosition(ORDER_TYPE_BUY);
      }
   }
   
   if(shortSignal && AllowShort)
   {
      if(!HasPosition(POSITION_TYPE_SELL))
      {
         CloseAllPositions(POSITION_TYPE_BUY);
         OpenPosition(ORDER_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Update indicator values                                          |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   //--- Copy RSI values
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) <= 0)
   {
      Logger.Error("Copying RSI buffer failed");
      return false;
   }
   
   //--- Copy Bollinger Bands values
   if(CopyBuffer(bbHandle, 0, 0, 3, bbMiddleBuffer) <= 0 ||
      CopyBuffer(bbHandle, 1, 0, 3, bbUpperBuffer) <= 0 ||
      CopyBuffer(bbHandle, 2, 0, 3, bbLowerBuffer) <= 0)
   {
      Logger.Error("Copying Bollinger Bands buffer failed");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPoints)
{
   if(FixedLotSize > 0)
      return NormalizeLotSize(FixedLotSize);
      
   if(stopLossPoints <= 0)
      stopLossPoints = 100; // Default SL if not specified
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100.0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double moneyPerLot = (stopLossPoints * point / tickSize) * tickValue;
   double lotSize = riskAmount / moneyPerLot;
   
   return NormalizeLotSize(lotSize);
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lots < minLot)
      lots = minLot;
   if(lots > maxLot)
      lots = maxLot;
      
   lots = MathFloor(lots / lotStep) * lotStep;
   
   return lots;
}

//+------------------------------------------------------------------+
//| Open position                                                     |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double price = 0;
   double sl = 0;
   double tp = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   //--- Calculate lot size
   double lotSize = CalculateLotSize(StopLossPips);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      if(StopLossPips > 0)
         sl = NormalizeDouble(price - StopLossPips * point * 10, digits);
      if(TakeProfitPips > 0)
         tp = NormalizeDouble(price + TakeProfitPips * point * 10, digits);
         
      if(trade.Buy(lotSize, _Symbol, price, sl, tp, TradeComment))
         Logger.Success("Buy order opened successfully at " + DoubleToString(price, digits));
      else
         Logger.Error("Opening Buy order failed: " + IntegerToString(GetLastError()));
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(StopLossPips > 0)
         sl = NormalizeDouble(price + StopLossPips * point * 10, digits);
      if(TakeProfitPips > 0)
         tp = NormalizeDouble(price - TakeProfitPips * point * 10, digits);
         
      if(trade.Sell(lotSize, _Symbol, price, sl, tp, TradeComment))
         Logger.Success("Sell order opened successfully at " + DoubleToString(price, digits));
      else
         Logger.Error("Opening Sell order failed: " + IntegerToString(GetLastError()));
   }
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasPosition(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions of specific type                             |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}
//+------------------------------------------------------------------+