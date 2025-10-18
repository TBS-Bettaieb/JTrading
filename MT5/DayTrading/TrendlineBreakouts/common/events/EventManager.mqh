//+------------------------------------------------------------------+
//| EventManager.mqh                                                  |
//| Manages event listeners and dispatches events                    |
//+------------------------------------------------------------------+
#property once
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "ITradingEventListener.mqh"

//+------------------------------------------------------------------+
//| Event manager class                                               |
//+------------------------------------------------------------------+
class EventManager
{
private:
   ITradingEventListener* m_listeners[];
   int m_listenerCount;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   EventManager()
   {
      m_listenerCount = 0;
      ArrayResize(m_listeners, 0);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~EventManager()
   {
      // Note: We don't delete listeners - they're owned by caller
      ArrayFree(m_listeners);
   }

   //+------------------------------------------------------------------+
   //| Register an event listener                                      |
   //+------------------------------------------------------------------+
   void RegisterListener(ITradingEventListener* listener)
   {
      if(listener == NULL)
         return;
      
      // Check if already registered
      for(int i = 0; i < m_listenerCount; i++)
      {
         if(m_listeners[i] == listener)
            return;
      }
      
      // Add to array
      ArrayResize(m_listeners, m_listenerCount + 1);
      m_listeners[m_listenerCount] = listener;
      m_listenerCount++;
   }

   //+------------------------------------------------------------------+
   //| Unregister an event listener                                    |
   //+------------------------------------------------------------------+
   void UnregisterListener(ITradingEventListener* listener)
   {
      if(listener == NULL)
         return;
      
      for(int i = 0; i < m_listenerCount; i++)
      {
         if(m_listeners[i] == listener)
         {
            // Shift remaining elements
            for(int j = i; j < m_listenerCount - 1; j++)
            {
               m_listeners[j] = m_listeners[j + 1];
            }
            
            m_listenerCount--;
            ArrayResize(m_listeners, m_listenerCount);
            return;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Dispatch signal detected event                                  |
   //+------------------------------------------------------------------+
   void DispatchSignalDetected(bool isBuy, double confidence, datetime time)
   {
      for(int i = 0; i < m_listenerCount; i++)
      {
         if(m_listeners[i] != NULL)
         {
            // Wrap in basic error handling
            ResetLastError();
            m_listeners[i].OnSignalDetected(isBuy, confidence, time);
            int error = GetLastError();
            if(error != 0)
            {
               Print("⚠️ EventManager: Listener ", i, " failed with error: ", error);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Dispatch trade opened event                                     |
   //+------------------------------------------------------------------+
   void DispatchTradeOpened(bool isLong, ulong ticket, double price, double sl, double tp)
   {
      for(int i = 0; i < m_listenerCount; i++)
      {
         if(m_listeners[i] != NULL)
         {
            ResetLastError();
            m_listeners[i].OnTradeOpened(isLong, ticket, price, sl, tp);
            int error = GetLastError();
            if(error != 0)
            {
               Print("⚠️ EventManager: Listener ", i, " failed with error: ", error);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Dispatch trade closed event                                     |
   //+------------------------------------------------------------------+
   void DispatchTradeClosed(bool wasLong, ulong ticket, double profit, string reason)
   {
      for(int i = 0; i < m_listenerCount; i++)
      {
         if(m_listeners[i] != NULL)
         {
            ResetLastError();
            m_listeners[i].OnTradeClosed(wasLong, ticket, profit, reason);
            int error = GetLastError();
            if(error != 0)
            {
               Print("⚠️ EventManager: Listener ", i, " failed with error: ", error);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Dispatch trade modified event                                   |
   //+------------------------------------------------------------------+
   void DispatchTradeModified(ulong ticket, double newSL, double newTP)
   {
      for(int i = 0; i < m_listenerCount; i++)
      {
         if(m_listeners[i] != NULL)
         {
            ResetLastError();
            m_listeners[i].OnTradeModified(ticket, newSL, newTP);
            int error = GetLastError();
            if(error != 0)
            {
               Print("⚠️ EventManager: Listener ", i, " failed with error: ", error);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Dispatch pivot detected event                                   |
   //+------------------------------------------------------------------+
   void DispatchPivotDetected(bool isHigh, double price, int bar)
   {
      for(int i = 0; i < m_listenerCount; i++)
      {
         if(m_listeners[i] != NULL)
         {
            ResetLastError();
            m_listeners[i].OnPivotDetected(isHigh, price, bar);
            int error = GetLastError();
            if(error != 0)
            {
               Print("⚠️ EventManager: Listener ", i, " failed with error: ", error);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Dispatch trendline updated event                                |
   //+------------------------------------------------------------------+
   void DispatchTrendlineUpdated(bool isUpper, double slope, bool isValid)
   {
      for(int i = 0; i < m_listenerCount; i++)
      {
         if(m_listeners[i] != NULL)
         {
            ResetLastError();
            m_listeners[i].OnTrendlineUpdated(isUpper, slope, isValid);
            int error = GetLastError();
            if(error != 0)
            {
               Print("⚠️ EventManager: Listener ", i, " failed with error: ", error);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Get listener count                                              |
   //+------------------------------------------------------------------+
   int GetListenerCount() const { return m_listenerCount; }
};
