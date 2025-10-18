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

//+------------------------------------------------------------------+
//| Trade manager class                                              |
//+------------------------------------------------------------------+
class TradeManager
{
private:
   string m_symbol;
   int m_magicNumber;
   double m_lotSize;
   int m_slippage;
   
   CTrade m_trade;
   ulong m_currentTicket;
   bool m_positionIsOpen;
   bool m_isLongPosition;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TradeManager(string symbol, int magicNumber, double lotSize, int slippage)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_lotSize = lotSize;
      m_slippage = slippage;
      m_currentTicket = 0;
      m_positionIsOpen = false;
      m_isLongPosition = false;
      
      // Configure trade object
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
      m_trade.SetAsyncMode(false);
   }

   //+------------------------------------------------------------------+
   //| Open a new position                                             |
   //+------------------------------------------------------------------+
   bool OpenPosition(bool isLong, double price, double sl, double tp)
   {
      // Validate position isn't already open
      if(m_positionIsOpen)
      {
         Logger::Warning("Cannot open new position - position already open");
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
         m_currentTicket = m_trade.ResultOrder();
         
         // Verify position opened - retry up to 5 times with small delay
         int retries = 0;
         while(retries < 5 && !PositionSelectByTicket(m_currentTicket))
         {
            Sleep(20);  // Short delay
            retries++;
         }

         if(!PositionSelectByTicket(m_currentTicket))
         {
            Logger::Warning("Order executed but position not found after " + IntegerToString(retries) + " retries! Ticket: " + IntegerToString(m_currentTicket));
            return false;
         }
         
         m_positionIsOpen = true;
         m_isLongPosition = isLong;
         
         Logger::Success("Position opened: " + (isLong ? "BUY" : "SELL") + 
                        " | Ticket: " + IntegerToString(m_currentTicket) +
                        " | Price: " + DoubleToString(price, digits) + 
                        " | SL: " + DoubleToString(sl, digits) + 
                        " | TP: " + DoubleToString(tp, digits));
      }
      else
      {
         HandleOrderError(isLong, price, sl, tp);
      }
      
      return result;
   }

   //+------------------------------------------------------------------+
   //| Close current position                                          |
   //+------------------------------------------------------------------+
   bool ClosePosition(string reason = "")
   {
      if(!m_positionIsOpen || m_currentTicket == 0)
      {
         Logger::Warning("No position to close");
         return false;
      }
      
      if(!PositionSelectByTicket(m_currentTicket))
      {
         Logger::Warning("Position not found for ticket: " + IntegerToString(m_currentTicket));
         m_positionIsOpen = false;
         m_currentTicket = 0;
         return false;
      }
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      if(m_trade.PositionClose(m_currentTicket))
      {
         string msg = "Position closed" + (reason != "" ? " (" + reason + ")" : "") +
                     " | Ticket: " + IntegerToString(m_currentTicket) +
                     " | Profit: " + DoubleToString(profit, 2);
         
         if(profit >= 0)
            Logger::Success(msg);
         else
            Logger::Info(msg);
         
         m_positionIsOpen = false;
         m_currentTicket = 0;
         m_isLongPosition = false;
         
         return true;
      }
      else
      {
         Logger::Error("Failed to close position. Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Check if our position is still open                            |
   //+------------------------------------------------------------------+
   bool ValidatePosition()
   {
      if(!m_positionIsOpen || m_currentTicket == 0)
         return false;
      
      // Select by ticket first (more specific)
      if(!PositionSelectByTicket(m_currentTicket))
      {
         Logger::Info("Position no longer exists for ticket " + IntegerToString(m_currentTicket));
         m_positionIsOpen = false;
         m_currentTicket = 0;
         return false;
      }
      
      // Verify it's still our symbol
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      if(posSymbol != m_symbol)
      {
         Logger::Warning("Position symbol mismatch: " + posSymbol + " vs " + m_symbol);
         m_positionIsOpen = false;
         m_currentTicket = 0;
         return false;
      }
      
      // Verify magic number
      long positionMagic = PositionGetInteger(POSITION_MAGIC);
      if(positionMagic != m_magicNumber)
      {
         Logger::Warning("Position magic mismatch: " + IntegerToString(positionMagic) + 
                        " vs " + IntegerToString(m_magicNumber));
         m_positionIsOpen = false;
         m_currentTicket = 0;
         return false;
      }
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| Update SL/TP levels                                             |
   //+------------------------------------------------------------------+
   bool ModifyPosition(double newSL, double newTP)
   {
      if(!m_positionIsOpen || !ValidatePosition())
      {
         Logger::Warning("Cannot modify - no valid position");
         return false;
      }
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      newSL = NormalizeDouble(newSL, digits);
      newTP = NormalizeDouble(newTP, digits);
      
      if(m_trade.PositionModify(m_currentTicket, newSL, newTP))
      {
         Logger::Debug("Position modified | SL: " + DoubleToString(newSL, digits) + 
                      " | TP: " + DoubleToString(newTP, digits));
         return true;
      }
      else
      {
         Logger::Error("Failed to modify position. Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Get current position profit                                     |
   //+------------------------------------------------------------------+
   double GetPositionProfit()
   {
      if(!m_positionIsOpen || !ValidatePosition())
         return 0.0;
      
      return PositionGetDouble(POSITION_PROFIT);
   }

   //+------------------------------------------------------------------+
   //| Getters                                                         |
   //+------------------------------------------------------------------+
   bool IsPositionOpen() const { return m_positionIsOpen; }
   bool IsLongPosition() const { return m_isLongPosition; }
   ulong GetCurrentTicket() const { return m_currentTicket; }
   
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
};
