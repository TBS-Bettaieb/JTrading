//+------------------------------------------------------------------+
//| TradeManager.mqh                                                  |
//| Centralized trade execution and position management              |
//+------------------------------------------------------------------+
#property once
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include "../utils/Logger.mqh"
#include "../../../../CommonUtils/TradingUtils.mqh"

//+------------------------------------------------------------------+
//| Trade manager class                                              |
//+------------------------------------------------------------------+
class TradeManager
{
private:
   string m_symbol;
   int m_baseMagicNumber;
   double m_lotSize;
   int m_slippage;
   int m_maxPositions;
   ENUM_TIMEFRAMES m_timeframe;
   
   CTrade m_trade;
   ulong m_activeTickets[];
   bool m_isLongPositions[];

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TradeManager(string symbol, int baseMagicNumber, double lotSize, int slippage, int maxPositions = 3, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      m_symbol = symbol;
      m_baseMagicNumber = baseMagicNumber;
      m_lotSize = lotSize;
      m_slippage = slippage;
      m_maxPositions = maxPositions;
      m_timeframe = timeframe;
      
      // Initialize arrays
      ArrayResize(m_activeTickets, 0);
      ArrayResize(m_isLongPositions, 0);
      
      // Configure trade object
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
      m_trade.SetAsyncMode(false);
   }

   //+------------------------------------------------------------------+
   //| Open a new position                                             |
   //+------------------------------------------------------------------+
   bool OpenPosition(bool isLong, double price, double sl, double tp)
   {
      // Check maximum positions limit
      int currentCount = ArraySize(m_activeTickets);
      if(currentCount >= m_maxPositions)
      {
         Logger::Warning("Cannot open new position - maximum positions reached (" + IntegerToString(m_maxPositions) + ")");
         return false;
      }
      
      // Validate parameters
      if(price <= 0)
      {
         Logger::Error("Invalid price: " + DoubleToString(price));
         return false;
      }
      
      if(tp <= 0 || sl <= 0)
      {
         Logger::Error("Invalid TP/SL: TP=" + DoubleToString(tp) + " SL=" + DoubleToString(sl));
         return false;
      }
      
      // ✅ ADD LOT SIZE VALIDATION
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      
      if(m_lotSize < minLot || m_lotSize > maxLot)
      {
         Logger::Error("Invalid lot size: " + DoubleToString(m_lotSize) + 
                      " (Min: " + DoubleToString(minLot) + 
                      ", Max: " + DoubleToString(maxLot) + ")");
         return false;
      }
      
      // Normalize lot size to step
      double originalLotSize = m_lotSize;
      m_lotSize = MathFloor(m_lotSize / stepLot) * stepLot;
      m_lotSize = NormalizeDouble(m_lotSize, 2);
      
      if(m_lotSize != originalLotSize)
      {
         Logger::Info("Lot size adjusted from " + DoubleToString(originalLotSize, 2) + 
                     " to " + DoubleToString(m_lotSize, 2) + " (step: " + DoubleToString(stepLot, 2) + ")");
      }
      
      // Normalize levels
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      tp = NormalizeDouble(tp, digits);
      sl = NormalizeDouble(sl, digits);
      
      // Check and adjust for minimum stop levels
      if(!ValidateAndAdjustLevels(isLong, price, sl, tp))
      {
         Logger::Error("Failed to validate/adjust stop levels");
         return false;
      }
      
      // Generate unique magic number for this position
      int positionIndex = ArraySize(m_activeTickets);
      int uniqueMagic = GenerateMagicNumber(m_baseMagicNumber, positionIndex, m_timeframe, "TBT");
      
      // Set magic number for trade
      m_trade.SetExpertMagicNumber(uniqueMagic);
      
      // Execute order
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
         ulong newTicket = m_trade.ResultOrder();
         
         // Verify position opened - retry up to 5 times with small delay
         int retries = 0;
         while(retries < 5 && !PositionSelectByTicket(newTicket))
         {
            Sleep(20);  // Short delay
            retries++;
         }

         if(!PositionSelectByTicket(newTicket))
         {
            Logger::Warning("Order executed but position not found after " + IntegerToString(retries) + " retries! Ticket: " + IntegerToString(newTicket));
            return false;
         }
         
         // Add to active positions array
         int newSize = ArraySize(m_activeTickets) + 1;
         ArrayResize(m_activeTickets, newSize);
         ArrayResize(m_isLongPositions, newSize);
         
         m_activeTickets[newSize - 1] = newTicket;
         m_isLongPositions[newSize - 1] = isLong;
         
         Logger::Success("Position opened: " + (isLong ? "BUY" : "SELL") + 
                        " | Ticket: " + IntegerToString(newTicket) +
                        " | Magic: " + IntegerToString(uniqueMagic) +
                        " | Price: " + DoubleToString(price, digits) + 
                        " | SL: " + DoubleToString(sl, digits) + 
                        " | TP: " + DoubleToString(tp, digits) +
                        " | Active positions: " + IntegerToString(ArraySize(m_activeTickets)));
      }
      else
      {
         HandleOrderError(isLong, price, sl, tp);
      }
      
      return result;
   }

   //+------------------------------------------------------------------+
   //| Close position by ticket                                        |
   //+------------------------------------------------------------------+
   bool ClosePosition(ulong ticket, string reason = "")
   {
      if(!PositionSelectByTicket(ticket))
      {
         Logger::Warning("Position not found for ticket: " + IntegerToString(ticket));
         RemoveTicketFromArray(ticket);
         return false;
      }
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      if(m_trade.PositionClose(ticket))
      {
         string msg = "Position closed" + (reason != "" ? " (" + reason + ")" : "") +
                     " | Ticket: " + IntegerToString(ticket) +
                     " | Profit: " + DoubleToString(profit, 2);
         
         if(profit >= 0)
            Logger::Success(msg);
         else
            Logger::Info(msg);
         
         RemoveTicketFromArray(ticket);
         return true;
      }
      else
      {
         Logger::Error("Failed to close position " + IntegerToString(ticket) + ". Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Close all positions                                             |
   //+------------------------------------------------------------------+
   bool CloseAllPositions(string reason = "")
   {
      int count = ArraySize(m_activeTickets);
      if(count == 0)
      {
         Logger::Info("No positions to close");
         return true;
      }
      
      Logger::Info("Closing all " + IntegerToString(count) + " positions" + (reason != "" ? " (" + reason + ")" : ""));
      
      bool allClosed = true;
      for(int i = count - 1; i >= 0; i--)
      {
         ulong ticket = m_activeTickets[i];
         if(!ClosePosition(ticket, reason))
         {
            allClosed = false;
         }
      }
      
      return allClosed;
   }

   //+------------------------------------------------------------------+
   //| Close positions by direction                                    |
   //+------------------------------------------------------------------+
   bool ClosePositionsByDirection(bool isLong, string reason = "")
   {
      int count = ArraySize(m_activeTickets);
      if(count == 0)
      {
         Logger::Info("No positions to close");
         return true;
      }
      
      int closeCount = 0;
      for(int i = count - 1; i >= 0; i--)
      {
         if(m_isLongPositions[i] == isLong)
         {
            closeCount++;
         }
      }
      
      if(closeCount == 0)
      {
         Logger::Info("No " + (isLong ? "LONG" : "SHORT") + " positions to close");
         return true;
      }
      
      Logger::Info("Closing " + IntegerToString(closeCount) + " " + (isLong ? "LONG" : "SHORT") + 
                  " positions" + (reason != "" ? " (" + reason + ")" : ""));
      
      bool allClosed = true;
      for(int i = count - 1; i >= 0; i--)
      {
         if(m_isLongPositions[i] == isLong)
         {
            ulong ticket = m_activeTickets[i];
            if(!ClosePosition(ticket, reason))
            {
               allClosed = false;
            }
         }
      }
      
      return allClosed;
   }

   //+------------------------------------------------------------------+
   //| Validate all positions and remove closed ones                  |
   //+------------------------------------------------------------------+
   bool ValidatePositions()
   {
      int count = ArraySize(m_activeTickets);
      if(count == 0)
         return false;
      
      bool hasValidPositions = false;
      
      // Loop backwards to allow safe removal
      for(int i = count - 1; i >= 0; i--)
      {
         ulong ticket = m_activeTickets[i];
         
         if(!PositionSelectByTicket(ticket))
         {
            Logger::Info("Position no longer exists for ticket " + IntegerToString(ticket));
            RemoveTicketFromArray(ticket);
            continue;
         }
         
         // Verify it's still our symbol and has valid magic (any of our generated magics)
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if(posSymbol != m_symbol)
         {
            Logger::Warning("Position symbol mismatch: " + posSymbol + " vs " + m_symbol + " | Ticket: " + IntegerToString(ticket));
            RemoveTicketFromArray(ticket);
            continue;
         }
         
         // Check if magic number is one of our generated ones
         long positionMagic = PositionGetInteger(POSITION_MAGIC);
         if(!IsOurMagicNumber(positionMagic))
         {
            Logger::Warning("Position magic not ours: " + IntegerToString(positionMagic) + " | Ticket: " + IntegerToString(ticket));
            RemoveTicketFromArray(ticket);
            continue;
         }
         
         hasValidPositions = true;
      }
      
      return hasValidPositions;
   }

   //+------------------------------------------------------------------+
   //| Update SL/TP levels for specific position                       |
   //+------------------------------------------------------------------+
   bool ModifyPosition(ulong ticket, double newSL, double newTP)
   {
      if(!PositionSelectByTicket(ticket))
      {
         Logger::Warning("Cannot modify - position not found: " + IntegerToString(ticket));
         RemoveTicketFromArray(ticket);
         return false;
      }
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      newSL = NormalizeDouble(newSL, digits);
      newTP = NormalizeDouble(newTP, digits);
      
      if(m_trade.PositionModify(ticket, newSL, newTP))
      {
         Logger::Debug("Position " + IntegerToString(ticket) + " modified | SL: " + DoubleToString(newSL, digits) + 
                      " | TP: " + DoubleToString(newTP, digits));
         return true;
      }
      else
      {
         Logger::Error("Failed to modify position " + IntegerToString(ticket) + ". Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Get position profit for specific ticket                         |
   //+------------------------------------------------------------------+
   double GetPositionProfit(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
      {
         RemoveTicketFromArray(ticket);
         return 0.0;
      }
      
      return PositionGetDouble(POSITION_PROFIT);
   }

   //+------------------------------------------------------------------+
   //| Getters                                                         |
   //+------------------------------------------------------------------+
   int GetActivePositionCount() const { return ArraySize(m_activeTickets); }
   
   bool HasPositionInDirection(bool isLong) const 
   {
      int count = ArraySize(m_activeTickets);
      for(int i = 0; i < count; i++)
      {
         if(m_isLongPositions[i] == isLong)
            return true;
      }
      return false;
   }
   
   bool GetActiveTickets(ulong &tickets[])
   {
      int count = ArraySize(m_activeTickets);
      ArrayResize(tickets, count);
      for(int i = 0; i < count; i++)
      {
         tickets[i] = m_activeTickets[i];
      }
      return count > 0;
   }
   
   bool GetPositionDirection(ulong ticket, bool &isLong)
   {
      int count = ArraySize(m_activeTickets);
      for(int i = 0; i < count; i++)
      {
         if(m_activeTickets[i] == ticket)
         {
            isLong = m_isLongPositions[i];
            return true;
         }
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Set lot size                                                    |
   //+------------------------------------------------------------------+
   void SetLotSize(double lots) { m_lotSize = lots; }
   double GetLotSize() const { return m_lotSize; }

private:
   //+------------------------------------------------------------------+
   //| Validate and adjust stop levels                                |
   //+------------------------------------------------------------------+
   bool ValidateAndAdjustLevels(bool isLong, double price, double& sl, double& tp)
   {
      long minStopsLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minStops = minStopsLevel * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      if(minStops == 0)
         return true;  // No restrictions
      
      double slDistance = isLong ? (price - sl) : (sl - price);
      double tpDistance = isLong ? (tp - price) : (price - tp);
      
      bool adjusted = false;
      
      // Adjust SL if too close
      if(slDistance < minStops)
      {
         Logger::Warning("SL too close: " + DoubleToString(slDistance, digits) + 
                        " < " + DoubleToString(minStops, digits));
         sl = isLong ? 
            NormalizeDouble(price - minStops * 1.1, digits) : 
            NormalizeDouble(price + minStops * 1.1, digits);
         Logger::Info("Adjusted SL to: " + DoubleToString(sl, digits));
         adjusted = true;
      }
      
      // Adjust TP if too close
      if(tpDistance < minStops)
      {
         Logger::Warning("TP too close: " + DoubleToString(tpDistance, digits) + 
                        " < " + DoubleToString(minStops, digits));
         tp = isLong ? 
            NormalizeDouble(price + minStops * 1.1, digits) : 
            NormalizeDouble(price - minStops * 1.1, digits);
         Logger::Info("Adjusted TP to: " + DoubleToString(tp, digits));
         adjusted = true;
      }
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| Handle order execution errors                                   |
   //+------------------------------------------------------------------+
   void HandleOrderError(bool isLong, double price, double sl, double tp)
   {
      uint errorCode = GetLastError();
      uint retCode = m_trade.ResultRetcode();
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      Logger::Error("═══════════════════════════════════════");
      Logger::Error("ORDER EXECUTION FAILED");
      Logger::Error("Symbol: " + m_symbol);
      Logger::Error("Direction: " + (isLong ? "BUY" : "SELL"));
      Logger::Error("Price: " + DoubleToString(price, digits));
      Logger::Error("Lot Size: " + DoubleToString(m_lotSize));
      Logger::Error("SL: " + DoubleToString(sl, digits));
      Logger::Error("TP: " + DoubleToString(tp, digits));
      Logger::Error("Error Code: " + IntegerToString(errorCode));
      Logger::Error("Return Code: " + IntegerToString(retCode));
      Logger::Error("Description: " + m_trade.ResultRetcodeDescription());
      
      // Provide specific guidance
      switch(retCode)
      {
         case TRADE_RETCODE_INVALID_STOPS:
            Logger::Error("💡 TIP: SL/TP violates broker's minimum distance");
            break;
            
         case TRADE_RETCODE_INVALID_VOLUME:
            Logger::Error("💡 TIP: Lot size not within allowed range");
            Logger::Error("   Min: " + DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN)));
            Logger::Error("   Max: " + DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX)));
            break;
            
         case TRADE_RETCODE_NO_MONEY:
            Logger::Error("💡 TIP: Insufficient funds to place order");
            break;
            
         case TRADE_RETCODE_MARKET_CLOSED:
            Logger::Error("💡 TIP: Market is closed for " + m_symbol);
            break;
            
         case TRADE_RETCODE_INVALID_PRICE:
            Logger::Error("💡 TIP: Price has changed, retry required");
            break;
      }
      
      Logger::Error("═══════════════════════════════════════");
   }

   //+------------------------------------------------------------------+
   //| Remove ticket from tracking arrays                              |
   //+------------------------------------------------------------------+
   void RemoveTicketFromArray(ulong ticket)
   {
      int count = ArraySize(m_activeTickets);
      for(int i = 0; i < count; i++)
      {
         if(m_activeTickets[i] == ticket)
         {
            // Shift remaining elements left
            for(int j = i; j < count - 1; j++)
            {
               m_activeTickets[j] = m_activeTickets[j + 1];
               m_isLongPositions[j] = m_isLongPositions[j + 1];
            }
            
            // Resize arrays
            ArrayResize(m_activeTickets, count - 1);
            ArrayResize(m_isLongPositions, count - 1);
            break;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Check if magic number belongs to us                             |
   //+------------------------------------------------------------------+
   bool IsOurMagicNumber(long magic)
   {
      // Check if this magic number could have been generated by our system
      // Our magic numbers use format: baseMagic * 10000 + strategyHash * 100 + timeframeHash * 10 + positionIndex
      int base = (int)(magic / 10000);
      return (base == m_baseMagicNumber || base % 100 == m_baseMagicNumber % 100);
   }
};
