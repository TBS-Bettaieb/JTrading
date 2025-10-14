//+------------------------------------------------------------------+
//|                                              Scalping Robot.mq5 |
//|                                                                  |
//|                                                     Version 1.00 |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;
CPositionInfo pos;

//--- Trading Inputs
input group "=== Trading Inputs ==="
input double   RiskPercent        = 0.2;     // Risk as % of Trading Capital
input int      Tppoints           = 200;   // Take Profit (10 points = 1 pip)
input int      Slpoints           = 200;   // StopLoss Points (10 points = 1 pip)
input int      TslTriggerPoints   = 15;    // Points in profit before Trailing SL is activated (10 points = 1 pip)
input int      TslPoints          = 10;    // Trailing Stop Loss (10 points = 1 pip)
input ENUM_TIMEFRAMES Timeframe   = PERIOD_CURRENT; //Time frame to run
input int      InpMagic           = 298347;        //EA identification
input string   TradeComment       = "Scalping Robot";

//--- Time Filters
input group "=== Time Filter ==="
input int SHInput = 0;  // Start Hour (0 = Inactive, 1-23 = Active)
input int EHInput = 0;  // End Hour (0 = Inactive, 1-23 = Active)

int SHChoice;
int EHChoice;

//--- Bar management
input group "=== Strategy Parameters ==="
int      BarsN = 5;
int      ExpirationBars = 100;
int      OrderDistPoints = 100;

//--- Global variables
string currSymbol;
double currPoint;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   currSymbol = Symbol();
   currPoint = SymbolInfoDouble(currSymbol, SYMBOL_POINT);
   
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   SHChoice = SHInput;
   EHChoice = EHInput;
   
   Print("Scalping Robot initialized on ", currSymbol);
   Print("Magic Number: ", InpMagic);
   Print("Timeframe: ", EnumToString(Timeframe));
   
   
   
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Scalping Robot stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Trail existing positions
   TrailStop();
   
   if(!IsNewBar()) return;
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   int HourNow = time.hour;
   
   // Close all orders outside trading hours
   if(SHChoice > 0 && HourNow < SHChoice) {CloseAllOrders(); return;}
   if(EHChoice > 0 && HourNow > EHChoice) {CloseAllOrders(); return;}
   
   
   
   // Count existing positions and orders
   int BuyTotal = 0;
   int SellTotal = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      pos.SelectByIndex(i);
      if(pos.PositionType() == POSITION_TYPE_BUY && pos.Symbol() == currSymbol && pos.Magic() == InpMagic) BuyTotal++;
      if(pos.PositionType() == POSITION_TYPE_SELL && pos.Symbol() == currSymbol && pos.Magic() == InpMagic) SellTotal++;
   }
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP && OrderGetString(ORDER_SYMBOL) == currSymbol && OrderGetInteger(ORDER_MAGIC) == InpMagic) BuyTotal++;
         if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP && OrderGetString(ORDER_SYMBOL) == currSymbol && OrderGetInteger(ORDER_MAGIC) == InpMagic) SellTotal++;
      }
   }
   
   // Look for trading signals only if no existing positions/orders
   if(BuyTotal <= 0)
   {
      double high = findHigh();
      if(high > 0)
      {
         SendBuyOrder(high);
      }
   }
   
   if(SellTotal <= 0)
   {
      double low = findLow();
      if(low > 0)
      {
         SendSellOrder(low);
      }
   }
}

//+------------------------------------------------------------------+
//| Find highest high in lookback period                             |
//+------------------------------------------------------------------+
double findHigh()
{
   double highestHigh = 0;
   
   for(int i = 0; i < 200; i++)
   {
      double high = iHigh(currSymbol, Timeframe, i);
      
      if(i > BarsN && iHighest(currSymbol, Timeframe, MODE_HIGH, BarsN*2+1, i-BarsN) == i)
      {
         if(high > highestHigh)
         {
            return high;
         }
      }
      
      highestHigh = MathMax(high, highestHigh);
   }
   
   return -1;
}

//+------------------------------------------------------------------+
//| Find lowest low in lookback period                               |
//+------------------------------------------------------------------+
double findLow()
{
   double lowestLow = DBL_MAX;
   
   for(int i = 0; i < 200; i++)
   {
      double low = iLow(currSymbol, Timeframe, i);
      
      if(i > BarsN && iLowest(currSymbol, Timeframe, MODE_LOW, BarsN*2+1, i-BarsN) == i)
      {
         if(low < lowestLow)
         {
            return low;
         }
      }
      
      lowestLow = MathMin(low, lowestLow);
   }
   
   return -1;
}

//+------------------------------------------------------------------+
//| Trailing Stop function                                           |
//+------------------------------------------------------------------+
void TrailStop()
{
   double sl = 0;
   double tp = 0;
   double ask = SymbolInfoDouble(currSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(currSymbol, SYMBOL_BID);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(pos.SelectByIndex(i))
      {
         ulong ticket = pos.Ticket();
         
         if(pos.Magic() == InpMagic && pos.Symbol() == currSymbol)
         {
            if(pos.PositionType() == POSITION_TYPE_BUY)
            {
               if(bid - pos.PriceOpen() > TslTriggerPoints * currPoint)
               {
                  tp = pos.TakeProfit();
                  sl = bid - (TslPoints * currPoint);
                  
                  if(sl > pos.StopLoss() && sl != 0)
                  {
                     trade.PositionModify(ticket, sl, tp);
                  }
               }
            }
            else if(pos.PositionType() == POSITION_TYPE_SELL)
            {
               if(pos.PriceOpen() - ask > TslTriggerPoints * currPoint)
               {
                  tp = pos.TakeProfit();
                  sl = ask + (TslPoints * currPoint);
                  
                  if(sl < pos.StopLoss() && sl != 0)
                  {
                     trade.PositionModify(ticket, sl, tp);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                      |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime previousTime = 0;
   datetime currentTime = iTime(currSymbol, Timeframe, 0);
   
   if(previousTime != currentTime)
   {
      previousTime = currentTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double calcLots(double slPoints)
{
   double risk = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100;
   
   double ticksize = SymbolInfoDouble(currSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(currSymbol, SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_STEP);
   double maxvolume = SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_MAX);
   double minvolume = SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_MIN);
   double volumelimit = SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_LIMIT);
   
   double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
   double lots = MathFloor(risk / moneyPerLotstep) * lotstep;
   
   if(volumelimit != 0) lots = MathMin(lots, volumelimit);
   if(maxvolume != 0) lots = MathMin(lots, SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_MAX));
   if(minvolume != 0) lots = MathMax(lots, SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_MIN));
   lots = NormalizeDouble(lots, 2);
   
   return lots;
}

//+------------------------------------------------------------------+
//| Send Buy Stop Order                                              |
//+------------------------------------------------------------------+
void SendBuyOrder(double entry)
{
   double ask = SymbolInfoDouble(currSymbol, SYMBOL_ASK);
   
   if(ask > entry - OrderDistPoints * currPoint) return;
   
   double tp = entry + Tppoints * currPoint;
   double sl = entry - Slpoints * currPoint;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(entry - sl);
   
   datetime expiration = iTime(currSymbol, Timeframe, 0) + ExpirationBars * PeriodSeconds(Timeframe);
   
   trade.BuyStop(lots, entry, currSymbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
}

//+------------------------------------------------------------------+
//| Send Sell Stop Order                                             |
//+------------------------------------------------------------------+
void SendSellOrder(double entry)
{
   double bid = SymbolInfoDouble(currSymbol, SYMBOL_BID);
   
   if(bid < entry + OrderDistPoints * currPoint) return;
   
   double tp = entry - Tppoints * currPoint;
   double sl = entry + Slpoints * currPoint;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(sl - entry);
   
   datetime expiration = iTime(currSymbol, Timeframe, 0) + ExpirationBars * PeriodSeconds(Timeframe);
   
   trade.SellStop(lots, entry, currSymbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
}

//+------------------------------------------------------------------+
//| Close all orders and positions                                   |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   // Close all positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(pos.SelectByIndex(i))
      {
         if(pos.Magic() == InpMagic && pos.Symbol() == currSymbol)
         {
            trade.PositionClose(pos.Ticket());
         }
      }
   }
   
   // Delete all pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_SYMBOL) == currSymbol)
         {
            trade.OrderDelete(ticket);
         }
      }
   }
}
//+------------------------------------------------------------------+