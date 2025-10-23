//+------------------------------------------------------------------+
//|                                              Scalping Robot.mq5 |
//|                                                                  |
//|                                                     Version 1.00 |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include "common/JT_ChartManager.mqh"
#include "common/filters/TimesàDaysFilters/JT_TimeFilter.mqh"

CTrade trade;
CPositionInfo pos;
CChartManager* chartManager = NULL;

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

//--- Time Filters (moved to JT_TimeFilter.mqh)

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
   
   // SHInput / EHInput fournis par JT_TimeFilter.mqh
   
   Print("Scalping Robot initialized on ", currSymbol);
   Print("Magic Number: ", InpMagic);
   Print("Timeframe: ", EnumToString(Timeframe));
   
   // ═══ Initialiser CChartManager ═══
   chartManager = new CChartManager(0, "ScalpBot");
   
   if(chartManager != NULL)
   {
      // Appliquer le style du graphique
      chartManager.SetupChart();
      
      // Afficher le nom de la stratégie
      chartManager.ShowTopLeftLabel("Scalping Robot v1.0", clrDarkBlue, 12);
      
   }
   else
   {
      Print("⚠️ Warning: Chart Manager initialization failed");
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Scalping Robot stopped. Reason: ", reason);
   
   // Nettoyer le Chart Manager
   if(chartManager != NULL)
   {
      delete chartManager;
      chartManager = NULL;
      Print("✓ Chart Manager cleaned up");
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Trail existing positions
   TrailStop();
   
   // Mettre à jour les informations sur le graphique
   UpdateChartInfo();
   
   if(!IsNewBar()) return;
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   int HourNow = time.hour;
   
   // Close all orders outside trading hours (inputs from JT_TimeFilter)
   if(SHInput > 0 && HourNow < SHInput) {CloseAllOrders(); return;}
   if(EHInput > 0 && HourNow > EHInput) {CloseAllOrders(); return;}
   
   
   
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
//| Update chart information display                                 |
//+------------------------------------------------------------------+
void UpdateChartInfo()
{
   if(chartManager == NULL) return;
   
   static int tickCount = 0;
   tickCount++;
   
   // Mettre à jour toutes les 50 ticks pour éviter trop de rafraîchissements
   if(tickCount % 50 != 0) return;
   
   // Compter les positions actives
   int buyPositions = 0;
   int sellPositions = 0;
   double totalProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(pos.SelectByIndex(i))
      {
         if(pos.Magic() == InpMagic && pos.Symbol() == currSymbol)
         {
            totalProfit += pos.Profit() + pos.Swap() + pos.Commission();
            
            if(pos.PositionType() == POSITION_TYPE_BUY)
               buyPositions++;
            else
               sellPositions++;
         }
      }
   }
   
   // Compter les ordres en attente
   int buyOrders = 0;
   int sellOrders = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_SYMBOL) == currSymbol)
         {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
               buyOrders++;
            else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)
               sellOrders++;
         }
      }
   }
   
   // Construire le texte de statut
   string status = "";
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   int hourNow = time.hour;
   
   // Vérifier si on est dans les heures de trading
   bool tradingAllowed = TF_IsTradingAllowed();
   
   if(tradingAllowed)
      status = "Status: ACTIVE";
   else
      status = "Status: OUTSIDE HOURS";
   
   status += " | Pos: " + IntegerToString(buyPositions + sellPositions);
   status += " (B:" + IntegerToString(buyPositions) + " S:" + IntegerToString(sellPositions) + ")";
   status += " | Orders: " + IntegerToString(buyOrders + sellOrders);
   
   if(buyPositions + sellPositions > 0)
   {
      status += " | P/L: " + DoubleToString(totalProfit, 2);
   }
   
   // Mettre à jour la couleur selon le profit
   color statusColor = clrGreen;
   if(!tradingAllowed) 
      statusColor = clrOrange;
   else if(totalProfit < 0) 
      statusColor = clrRed;
   else if(totalProfit > 0)
      statusColor = clrGreen;
   
   // Mettre à jour le label
   chartManager.UpdateLabelText("TopRight", status);
   chartManager.UpdateLabelColor("TopRight", statusColor);
}
//+------------------------------------------------------------------+