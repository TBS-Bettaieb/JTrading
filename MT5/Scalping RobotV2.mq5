//+------------------------------------------------------------------+
//|                                              Scalping Robot.mq5 |
//|                                                                  |
//|                                  Version 1.10 - Cost Management |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property version   "1.10"
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
input int      Tppoints           = 200;     // Take Profit (10 points = 1 pip)
input int      Slpoints           = 200;     // StopLoss Points (10 points = 1 pip)
input int      TslTriggerPoints   = 15;      // Points in profit before Trailing SL is activated
input int      TslPoints          = 10;      // Trailing Stop Loss (10 points = 1 pip)
input ENUM_TIMEFRAMES Timeframe   = PERIOD_CURRENT; // Time frame to run
input int      InpMagic           = 298347;  // EA identification
input string   TradeComment       = "Scalping Robot";

//--- Cost Management
input group "=== Cost Management ==="
input bool     UseSpreadFilter    = true;    // Activer filtre de spread
input int      MaxSpreadPoints    = 30;      // Spread maximum autorisé (en points)
input double   CommissionPerLot   = 7.0;     // Commission par lot (aller-retour)
input bool     AdjustTPForCosts   = true;    // Ajuster TP pour couvrir les coûts
input double   MinProfitPoints    = 50;      // Profit minimum après coûts (en points)

//--- Strategy Parameters
input group "=== Strategy Parameters ==="
input int      BarsN              = 5;       // Bars pour détection swing
input int      ExpirationBars     = 100;     // Expiration des ordres en attente
input int      OrderDistPoints    = 100;     // Distance minimum pour placer ordre

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
   
   Print("╔════════════════════════════════════════════════════╗");
   Print("║      SCALPING ROBOT v1.10 - INITIALIZED          ║");
   Print("╠════════════════════════════════════════════════════╣");
   Print("║ Symbol: ", currSymbol);
   Print("║ Magic Number: ", InpMagic);
   Print("║ Timeframe: ", EnumToString(Timeframe));
   Print("║ Risk: ", RiskPercent, "%");
   Print("╚════════════════════════════════════════════════════╝");
   
   // Afficher les statistiques de coûts
   PrintCostStatistics();
   
   // Initialiser Chart Manager
   chartManager = new CChartManager(0, "ScalpBot");
   
   if(chartManager != NULL)
   {
      chartManager.SetupChart();
      chartManager.ShowTopLeftLabel("Scalping Robot v1.10", clrDarkBlue, 12);
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
   
   // Update chart information
   UpdateChartInfo();
   
   if(!IsNewBar()) return;
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   int HourNow = time.hour;
   
   // Close all orders outside trading hours
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
//| Obtenir le spread actuel en points                               |
//+------------------------------------------------------------------+
int GetCurrentSpread()
{
   double ask = SymbolInfoDouble(currSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(currSymbol, SYMBOL_BID);
   double spread = ask - bid;
   
   return (int)MathRound(spread / currPoint);
}

//+------------------------------------------------------------------+
//| Vérifier si le spread est acceptable                             |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable()
{
   if(!UseSpreadFilter) return true;
   
   int currentSpread = GetCurrentSpread();
   
   if(currentSpread > MaxSpreadPoints)
   {
      static datetime lastWarning = 0;
      if(TimeCurrent() - lastWarning > 300) // Warning toutes les 5 minutes
      {
         Print("⚠️ Spread trop élevé: ", currentSpread, " points (Max: ", MaxSpreadPoints, ")");
         lastWarning = TimeCurrent();
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculer le coût total en devise du compte                       |
//+------------------------------------------------------------------+
double CalculateTotalCost(double lots)
{
   // 1. Coût du spread
   int spread = GetCurrentSpread();
   double tickValue = SymbolInfoDouble(currSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(currSymbol, SYMBOL_TRADE_TICK_SIZE);
   
   double spreadCost = (spread * currPoint / tickSize) * tickValue * lots;
   
   // 2. Commission (aller-retour)
   double commissionCost = CommissionPerLot * lots;
   
   // 3. Coût total
   double totalCost = spreadCost + commissionCost;
   
   return totalCost;
}

//+------------------------------------------------------------------+
//| Calculer les lots ajustés avec les coûts                         |
//+------------------------------------------------------------------+
double calcLotsWithCosts(double slPoints)
{
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = accountEquity * RiskPercent / 100;
   
   double tickSize = SymbolInfoDouble(currSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(currSymbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_STEP);
   double minVolume = SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_MAX);
   
   // Méthode simplifiée et plus fiable
   // 1. Calculer combien vaut 1 pip en argent pour 1 lot
   double onePipValue = tickValue * (currPoint / tickSize);
   
   // 2. Calculer le risque total en argent pour 1 lot avec ce SL
   double riskPerLot = slPoints * onePipValue;
   
   // 3. Calculer les lots de base
   double lots = riskAmount / riskPerLot;
   
   // 4. Estimer et déduire les coûts (itération pour convergence)
   for(int iteration = 0; iteration < 3; iteration++)
   {
      double estimatedCost = CalculateTotalCost(lots);
      double adjustedRisk = riskAmount - estimatedCost;
      
      if(adjustedRisk <= 0)
      {
         lots = minVolume;
         break;
      }
      
      lots = adjustedRisk / riskPerLot;
   }
   
   // 5. Arrondir et appliquer les limites
   lots = MathFloor(lots / lotStep) * lotStep;
   
   if(lots < minVolume) lots = minVolume;
   if(maxVolume > 0 && lots > maxVolume) lots = maxVolume;
   
   lots = NormalizeDouble(lots, 2);
   
   // Log simplifié
   Print("💰 Lot calculé: ", lots, " | Risque: ", riskAmount, " | SL: ", slPoints, "pts");
   
   return lots;
}

//+------------------------------------------------------------------+
//| Calculer TP ajusté pour couvrir les coûts                        |
//+------------------------------------------------------------------+
double CalculateAdjustedTP(double entryPrice, double baseTpPoints, bool isBuy)
{
   if(!AdjustTPForCosts) 
   {
      return isBuy ? entryPrice + baseTpPoints * currPoint 
                   : entryPrice - baseTpPoints * currPoint;
   }
   
   // Calculer les points nécessaires pour couvrir les coûts
   int spread = GetCurrentSpread();
   double costPoints = spread + MinProfitPoints;
   
   // Ajouter les coûts au TP
   double adjustedTpPoints = MathMax(baseTpPoints, costPoints);
   
   double tp = isBuy ? entryPrice + adjustedTpPoints * currPoint
                     : entryPrice - adjustedTpPoints * currPoint;
   
   if(adjustedTpPoints > baseTpPoints)
   {
      Print("📊 TP ajusté pour coûts: ", baseTpPoints, " → ", adjustedTpPoints, " points");
   }
   
   return tp;
}

//+------------------------------------------------------------------+
//| TRAILING STOP AMÉLIORÉ                                           |
//+------------------------------------------------------------------+
void TrailStop()
{
   if(!IsSpreadAcceptable()) return; // Ne pas modifier si spread trop élevé
   
   double sl = 0;
   double tp = 0;
   double ask = SymbolInfoDouble(currSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(currSymbol, SYMBOL_BID);
   
   int currentSpread = GetCurrentSpread();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(pos.SelectByIndex(i))
      {
         ulong ticket = pos.Ticket();
         
         if(pos.Magic() == InpMagic && pos.Symbol() == currSymbol)
         {
            double positionProfit = pos.Profit()  + pos.Commission();
            double positionSize = pos.Volume();
            
            // Calculer le coût total de la position
            double totalCost = CalculateTotalCost(positionSize);
            
            // Profit net après coûts
            double netProfit = positionProfit - totalCost;
            
            if(pos.PositionType() == POSITION_TYPE_BUY)
            {
               double profitPoints = (bid - pos.PriceOpen()) / currPoint;
               
               // Activer trailing seulement si profit net > trigger
               double triggerWithCosts = TslTriggerPoints + currentSpread;
               
               if(profitPoints > triggerWithCosts && netProfit > 0)
               {
                  tp = pos.TakeProfit();
                  
                  // SL avec buffer pour le spread
                  sl = bid - (TslPoints + currentSpread) * currPoint;
                  
                  // S'assurer que le nouveau SL est meilleur
                  if(sl > pos.StopLoss() && sl != 0)
                  {
                     // Calculer le profit potentiel au nouveau SL
                     double potentialProfit = (sl - pos.PriceOpen()) / currPoint;
                     
                     // Ne déplacer le SL que si ça garantit un profit minimum
                     if(potentialProfit > MinProfitPoints)
                     {
                        if(trade.PositionModify(ticket, sl, tp))
                        {
                           Print("✅ Trailing SL BUY: ", pos.PriceOpen(), " → ", sl, 
                                 " (Profit net: ", DoubleToString(netProfit, 2), ")");
                        }
                     }
                  }
               }
            }
            else if(pos.PositionType() == POSITION_TYPE_SELL)
            {
               double profitPoints = (pos.PriceOpen() - ask) / currPoint;
               
               double triggerWithCosts = TslTriggerPoints + currentSpread;
               
               if(profitPoints > triggerWithCosts && netProfit > 0)
               {
                  tp = pos.TakeProfit();
                  
                  // SL avec buffer pour le spread
                  sl = ask + (TslPoints + currentSpread) * currPoint;
                  
                  if((sl < pos.StopLoss() || pos.StopLoss() == 0) && sl != 0)
                  {
                     double potentialProfit = (pos.PriceOpen() - sl) / currPoint;
                     
                     if(potentialProfit > MinProfitPoints)
                     {
                        if(trade.PositionModify(ticket, sl, tp))
                        {
                           Print("✅ Trailing SL SELL: ", pos.PriceOpen(), " → ", sl,
                                 " (Profit net: ", DoubleToString(netProfit, 2), ")");
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SEND BUY ORDER AMÉLIORÉ                                          |
//+------------------------------------------------------------------+
void SendBuyOrder(double entry)
{
   // 1. Vérifier le spread
   if(!IsSpreadAcceptable())
   {
      Print("❌ Ordre BUY annulé: spread trop élevé");
      return;
   }
   
   double ask = SymbolInfoDouble(currSymbol, SYMBOL_ASK);
   
   if(ask > entry - OrderDistPoints * currPoint) return;
   
   // 2. Calculer SL/TP avec ajustements
   double sl = entry - Slpoints * currPoint;
   double tp = CalculateAdjustedTP(entry, Tppoints, true);
   
   // 3. Vérifier que le ratio R:R est acceptable après ajustements
   double slDistance = entry - sl;
   double tpDistance = tp - entry;
   double actualRR = tpDistance / slDistance;
   
   
   // 4. Calculer lots avec prise en compte des coûts
   double lots = calcLotsWithCosts(slDistance / currPoint);
   
   if(lots <= 0)
   {
      Print("❌ Ordre BUY annulé: lot size = 0 (coûts trop élevés)");
      return;
   }
   
   // 5. Calculer et afficher les coûts prévus
   double totalCost = CalculateTotalCost(lots);
   int currentSpread = GetCurrentSpread();
   
   Print("📈 Ordre BUY STOP préparé:");
   Print("   Entry: ", entry, " | SL: ", sl, " | TP: ", tp);
   Print("   Lots: ", lots, " | Spread: ", currentSpread, " points");
   Print("   Coût total: ", DoubleToString(totalCost, 2), " | R:R: ", DoubleToString(actualRR, 2));
   
   // 6. Placer l'ordre
   datetime expiration = iTime(currSymbol, Timeframe, 0) + ExpirationBars * PeriodSeconds(Timeframe);
   
   if(trade.BuyStop(lots, entry, currSymbol, sl, tp, ORDER_TIME_SPECIFIED, expiration))
   {
      Print("✅ Ordre BUY STOP placé - Ticket: ", trade.ResultOrder());
   }
   else
   {
      Print("❌ Erreur placement ordre BUY: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| SEND SELL ORDER AMÉLIORÉ                                         |
//+------------------------------------------------------------------+
void SendSellOrder(double entry)
{
   // 1. Vérifier le spread
   if(!IsSpreadAcceptable())
   {
      Print("❌ Ordre SELL annulé: spread trop élevé");
      return;
   }
   
   double bid = SymbolInfoDouble(currSymbol, SYMBOL_BID);
   
   if(bid < entry + OrderDistPoints * currPoint) return;
   
   // 2. Calculer SL/TP avec ajustements
   double sl = entry + Slpoints * currPoint;
   double tp = CalculateAdjustedTP(entry, Tppoints, false);
   
   // 3. Vérifier ratio R:R
   double slDistance = sl - entry;
   double tpDistance = entry - tp;
   double actualRR = tpDistance / slDistance;
  
   
   // 4. Calculer lots avec prise en compte des coûts
   double lots = calcLotsWithCosts(slDistance / currPoint);
   
   if(lots <= 0)
   {
      Print("❌ Ordre SELL annulé: lot size = 0 (coûts trop élevés)");
      return;
   }
   
   // 5. Calculer et afficher les coûts prévus
   double totalCost = CalculateTotalCost(lots);
   int currentSpread = GetCurrentSpread();
   
   Print("📉 Ordre SELL STOP préparé:");
   Print("   Entry: ", entry, " | SL: ", sl, " | TP: ", tp);
   Print("   Lots: ", lots, " | Spread: ", currentSpread, " points");
   Print("   Coût total: ", DoubleToString(totalCost, 2), " | R:R: ", DoubleToString(actualRR, 2));
   
   // 6. Placer l'ordre
   datetime expiration = iTime(currSymbol, Timeframe, 0) + ExpirationBars * PeriodSeconds(Timeframe);
   
   if(trade.SellStop(lots, entry, currSymbol, sl, tp, ORDER_TIME_SPECIFIED, expiration))
   {
      Print("✅ Ordre SELL STOP placé - Ticket: ", trade.ResultOrder());
   }
   else
   {
      Print("❌ Erreur placement ordre SELL: ", trade.ResultRetcodeDescription());
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
//| Fonction utilitaire: Afficher les statistiques de coûts          |
//+------------------------------------------------------------------+
void PrintCostStatistics()
{
   int currentSpread = GetCurrentSpread();
   double minLot = SymbolInfoDouble(currSymbol, SYMBOL_VOLUME_MIN);
   double costPerMinLot = CalculateTotalCost(minLot);
   
   Print("╔════════════════════════════════════════╗");
   Print("║    STATISTIQUES DES COÛTS DE TRADING   ║");
   Print("╠════════════════════════════════════════╣");
   Print("║ Spread actuel: ", currentSpread, " points");
   Print("║ Commission/lot: ", CommissionPerLot);
   Print("║ Coût pour ", minLot, " lot: ", DoubleToString(costPerMinLot, 2));
   Print("║ Profit min requis: ", MinProfitPoints, " points");
   Print("╚════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Update chart information display                                 |
//+------------------------------------------------------------------+
void UpdateChartInfo()
{
   if(chartManager == NULL) return;
   
   static int tickCount = 0;
   tickCount++;
   
   // Mettre à jour toutes les 50 ticks
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
            totalProfit += pos.Profit()  + pos.Commission();
            
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
   
   // Informations sur le spread et les coûts
   int currentSpread = GetCurrentSpread();
   bool spreadOK = IsSpreadAcceptable();
   
   // Construire le texte de statut
   string status = "";
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   bool tradingAllowed = TF_IsTradingAllowed();
   
   if(tradingAllowed && spreadOK)
      status = "Status: ACTIVE ✓";
   else if(!tradingAllowed)
      status = "Status: OUTSIDE HOURS";
   else if(!spreadOK)
      status = "Status: SPREAD HIGH ⚠️";
   
   status += " | Spread: " + IntegerToString(currentSpread) + "pts";
   status += " | Pos: " + IntegerToString(buyPositions + sellPositions);
   status += " (B:" + IntegerToString(buyPositions) + " S:" + IntegerToString(sellPositions) + ")";
   status += " | Orders: " + IntegerToString(buyOrders + sellOrders);
   
   if(buyPositions + sellPositions > 0)
   {
      status += " | P/L: " + DoubleToString(totalProfit, 2);
   }
   
   // Mettre à jour la couleur selon le statut
   color statusColor = clrGreen;
   if(!tradingAllowed) 
      statusColor = clrOrange;
   else if(!spreadOK)
      statusColor = clrRed;
   else if(totalProfit < 0) 
      statusColor = clrCoral;
   else if(totalProfit > 0)
      statusColor = clrLimeGreen;
   
   // Mettre à jour le label
   chartManager.UpdateLabelText("TopRight", status);
   chartManager.UpdateLabelColor("TopRight", statusColor);
}
//+------------------------------------------------------------------+