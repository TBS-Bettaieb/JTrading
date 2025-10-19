//+------------------------------------------------------------------+
//| IFilter.mqh                                                      |
//| Base interface for all filter components                         |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Base interface for filters                                        |
//+------------------------------------------------------------------+
class IFilter
{
public:
   // Core methods that all filters must implement
   virtual bool Initialize() = 0;
   virtual void Update() = 0;
   virtual bool IsFilterPassed() = 0;
   virtual void Release() = 0;
   
   // Optional: Get filter value
   virtual double GetFilterValue() { return 0.0; }
   
   // Optional: Check if filter is ready
   virtual bool IsInitialized() { return false; }
};
