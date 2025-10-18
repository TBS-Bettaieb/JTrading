//+------------------------------------------------------------------+
//| PerformanceTracker.mqh                                            |
//| Sample event listener that tracks performance metrics            |
//+------------------------------------------------------------------+
#property once
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "ITradingEventListener.mqh"
#include "../utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Performance tracker class                                         |
//+------------------------------------------------------------------+
class PerformanceTracker : public ITradingEventListener
{
private:
   int m_totalSignals;
   int m_totalTrades;
   int m_winningTrades;
   int m_losingTrades;
   int m_breakevenTrades;
   double m_totalProfit;
   double m_grossProfit;
   double m_grossLoss;
   int m_longTrades;
   int m_shortTrades;
   datetime m_startTime;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   PerformanceTracker()
   {
      Reset();
   }

   //+------------------------------------------------------------------+
   //| Reset statistics                                                 |
   //+------------------------------------------------------------------+
   void Reset()
   {
      m_totalSignals = 0;
      m_totalTrades = 0;
      m_winningTrades = 0;
      m_losingTrades = 0;
      m_breakevenTrades = 0;
      m_totalProfit = 0;
      m_grossProfit = 0;
      m_grossLoss = 0;
      m_longTrades = 0;
      m_shortTrades = 0;
      m_startTime = TimeCurrent();
   }

   //+------------------------------------------------------------------+
   //| Event: Signal detected                                          |
   //+------------------------------------------------------------------+
   void OnSignalDetected(bool isBuy, double confidence, datetime time) override
   {
      m_totalSignals++;
      Logger::Debug("Signal #" + IntegerToString(m_totalSignals) + " detected: " + 
                   (isBuy ? "BUY" : "SELL") + " | Confidence: " + DoubleToString(confidence, 2));
   }

   //+------------------------------------------------------------------+
   //| Event: Trade opened                                             |
   //+------------------------------------------------------------------+
   void OnTradeOpened(bool isLong, ulong ticket, double price, double sl, double tp) override
   {
      m_totalTrades++;
      if(isLong) m_longTrades++;
      else m_shortTrades++;
      
      Logger::Debug("Trade opened: #" + IntegerToString(m_totalTrades) + 
                   " | " + (isLong ? "LONG" : "SHORT") + 
                   " | Ticket: " + IntegerToString(ticket));
   }

   //+------------------------------------------------------------------+
   //| Event: Trade closed                                             |
   //+------------------------------------------------------------------+
   void OnTradeClosed(bool wasLong, ulong ticket, double profit, string reason) override
   {
      m_totalProfit += profit;
      
      if(profit > 0)
      {
         m_winningTrades++;
         m_grossProfit += profit;
      }
      else if(profit < 0)
      {
         m_losingTrades++;
         m_grossLoss += MathAbs(profit);
      }
      else
      {
         m_breakevenTrades++;
      }
      
      Logger::Debug("Trade closed: Ticket " + IntegerToString(ticket) + 
                   " | " + reason + 
                   " | Profit: " + DoubleToString(profit, 2) + 
                   " | Total P/L: " + DoubleToString(m_totalProfit, 2));
   }

   //+------------------------------------------------------------------+
   //| Event: Trade modified                                           |
   //+------------------------------------------------------------------+
   void OnTradeModified(ulong ticket, double newSL, double newTP) override
   {
      Logger::Debug("Trade modified: Ticket " + IntegerToString(ticket) + 
                   " | New SL: " + DoubleToString(newSL) + 
                   " | New TP: " + DoubleToString(newTP));
   }

   //+------------------------------------------------------------------+
   //| Event: Pivot detected                                           |
   //+------------------------------------------------------------------+
   void OnPivotDetected(bool isHigh, double price, int bar) override
   {
      Logger::Debug("Pivot " + (isHigh ? "HIGH" : "LOW") + " detected: " + 
                   DoubleToString(price) + " at bar " + IntegerToString(bar));
   }

   //+------------------------------------------------------------------+
   //| Event: Trendline updated                                        |
   //+------------------------------------------------------------------+
   void OnTrendlineUpdated(bool isUpper, double slope, bool isValid) override
   {
      Logger::Debug((isUpper ? "Upper" : "Lower") + " trendline updated: " + 
                   "Slope=" + DoubleToString(slope, 8) + 
                   " | Valid=" + (isValid ? "Yes" : "No"));
   }

   //+------------------------------------------------------------------+
   //| Print performance report                                        |
   //+------------------------------------------------------------------+
   void PrintReport()
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("📊 PERFORMANCE REPORT");
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("Trading Period: " + TimeToString(m_startTime) + " - " + TimeToString(TimeCurrent()));
      Logger::Info("Total Signals: " + IntegerToString(m_totalSignals));
      Logger::Info("Total Trades: " + IntegerToString(m_totalTrades));
      Logger::Info("  Long Trades: " + IntegerToString(m_longTrades));
      Logger::Info("  Short Trades: " + IntegerToString(m_shortTrades));
      Logger::Info("───────────────────────────────────────");
      Logger::Info("Winning Trades: " + IntegerToString(m_winningTrades));
      Logger::Info("Losing Trades: " + IntegerToString(m_losingTrades));
      Logger::Info("Breakeven Trades: " + IntegerToString(m_breakevenTrades));
      
      if(m_totalTrades > 0)
      {
         double winRate = (m_winningTrades / (double)m_totalTrades) * 100;
         Logger::Info("Win Rate: " + DoubleToString(winRate, 2) + "%");
      }
      
      Logger::Info("───────────────────────────────────────");
      Logger::Info("Total Profit: " + DoubleToString(m_totalProfit, 2));
      Logger::Info("Gross Profit: " + DoubleToString(m_grossProfit, 2));
      Logger::Info("Gross Loss: " + DoubleToString(m_grossLoss, 2));
      
      if(m_grossLoss > 0)
      {
         double profitFactor = m_grossProfit / m_grossLoss;
         Logger::Info("Profit Factor: " + DoubleToString(profitFactor, 2));
      }
      
      if(m_totalTrades > 0)
      {
         double avgProfit = m_totalProfit / m_totalTrades;
         Logger::Info("Average Trade: " + DoubleToString(avgProfit, 2));
      }
      
      Logger::Info("═══════════════════════════════════════");
   }

   //+------------------------------------------------------------------+
   //| Getters for external access                                     |
   //+------------------------------------------------------------------+
   int GetTotalSignals() const { return m_totalSignals; }
   int GetTotalTrades() const { return m_totalTrades; }
   int GetWinningTrades() const { return m_winningTrades; }
   int GetLosingTrades() const { return m_losingTrades; }
   double GetTotalProfit() const { return m_totalProfit; }
   double GetWinRate() const 
   { 
      return m_totalTrades > 0 ? (m_winningTrades / (double)m_totalTrades) * 100 : 0; 
   }
};
