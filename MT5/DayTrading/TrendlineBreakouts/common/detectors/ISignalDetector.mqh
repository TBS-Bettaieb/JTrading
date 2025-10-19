//+------------------------------------------------------------------+
//| ISignalDetector.mqh                                              |
//| Base interface for all signal detection components              |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Base interface for signal detectors                              |
//+------------------------------------------------------------------+
class ISignalDetector
{
public:
   // Core methods that all detectors must implement
   virtual bool Initialize() = 0;
   virtual void Update() = 0;
   virtual bool HasBuySignal() = 0;
   virtual bool HasSellSignal() = 0;
   virtual void Release() = 0;
   
   // Optional: Get signal strength (0-10 scale)
   virtual int GetSignalStrength() { return 0; }
   
   // Optional: Check if detector is ready
   virtual bool IsInitialized() { return false; }
};
