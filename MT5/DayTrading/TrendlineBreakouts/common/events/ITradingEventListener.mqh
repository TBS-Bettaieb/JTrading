//+------------------------------------------------------------------+
//| ITradingEventListener.mqh                                         |
//| Interface for trading event notifications                        |
//+------------------------------------------------------------------+
#property once
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Trading event listener interface                                  |
//+------------------------------------------------------------------+
class ITradingEventListener
{
public:
   // Called when a new trading signal is detected
   virtual void OnSignalDetected(bool isBuy, double confidence, datetime time) = 0;
   
   // Called when a trade is opened
   virtual void OnTradeOpened(bool isLong, ulong ticket, double price, double sl, double tp) = 0;
   
   // Called when a trade is closed
   virtual void OnTradeClosed(bool wasLong, ulong ticket, double profit, string reason) = 0;
   
   // Called when SL/TP is modified
   virtual void OnTradeModified(ulong ticket, double newSL, double newTP) = 0;
   
   // Called when a pivot is detected
   virtual void OnPivotDetected(bool isHigh, double price, int bar) = 0;
   
   // Called when a trendline is updated
   virtual void OnTrendlineUpdated(bool isUpper, double slope, bool isValid) = 0;
};
