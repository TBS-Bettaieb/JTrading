//+------------------------------------------------------------------+
//|                                            RSI_Calculator.mqh    |
//|                                    Calculateur Triple RSI        |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Triple RSI Calculator Class                                      |
//+------------------------------------------------------------------+
class CTripleRSICalculator
{
private:
   int m_rsi1Handle;
   int m_rsi2Handle;
   int m_rsi3Handle;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   bool m_initialized;

public:
   //--- Constructor
   CTripleRSICalculator()
   {
      m_rsi1Handle = INVALID_HANDLE;
      m_rsi2Handle = INVALID_HANDLE;
      m_rsi3Handle = INVALID_HANDLE;
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      m_initialized = false;
   }
   
   //--- Destructor
   ~CTripleRSICalculator()
   {
      Deinitialize();
   }
   
   //--- Initialisation des handles RSI
   bool Initialize(string symbol, ENUM_TIMEFRAMES tf, 
                   int period1, int period2, int period3)
   {
      if(m_initialized)
      {
         Logger::Warning("RSI Calculator already initialized, deinitializing first");
         Deinitialize();
      }
      
      m_symbol = symbol;
      m_timeframe = tf;
      
      Logger::Debug("Initializing RSI handles for " + symbol + " " + EnumToString(tf));
      Logger::Debug("Periods: " + IntegerToString(period1) + "/" + 
                    IntegerToString(period2) + "/" + IntegerToString(period3));
      
      // Créer les handles RSI
      m_rsi1Handle = iRSI(symbol, tf, period1, PRICE_CLOSE);
      m_rsi2Handle = iRSI(symbol, tf, period2, PRICE_CLOSE);
      m_rsi3Handle = iRSI(symbol, tf, period3, PRICE_CLOSE);
      
      // Vérifier que tous les handles sont valides
      if(m_rsi1Handle == INVALID_HANDLE)
      {
         Logger::Error("Failed to create RSI1 handle (period " + IntegerToString(period1) + ")");
         return false;
      }
      
      if(m_rsi2Handle == INVALID_HANDLE)
      {
         Logger::Error("Failed to create RSI2 handle (period " + IntegerToString(period2) + ")");
         return false;
      }
      
      if(m_rsi3Handle == INVALID_HANDLE)
      {
         Logger::Error("Failed to create RSI3 handle (period " + IntegerToString(period3) + ")");
         return false;
      }
      
      m_initialized = true;
      Logger::Success("RSI Calculator initialized successfully");
      return true;
   }
   
   //--- Récupérer valeurs RSI courantes
   bool GetCurrentValues(double &rsi1, double &rsi2, double &rsi3)
   {
      if(!m_initialized)
      {
         Logger::Error("RSI Calculator not initialized");
         return false;
      }
      
      double buffer1[], buffer2[], buffer3[];
      ArraySetAsSeries(buffer1, true);
      ArraySetAsSeries(buffer2, true);
      ArraySetAsSeries(buffer3, true);
      
      // Copier les buffers RSI
      if(CopyBuffer(m_rsi1Handle, 0, 0, 1, buffer1) <= 0)
      {
         Logger::Error("Failed to copy RSI1 buffer");
         return false;
      }
      
      if(CopyBuffer(m_rsi2Handle, 0, 0, 1, buffer2) <= 0)
      {
         Logger::Error("Failed to copy RSI2 buffer");
         return false;
      }
      
      if(CopyBuffer(m_rsi3Handle, 0, 0, 1, buffer3) <= 0)
      {
         Logger::Error("Failed to copy RSI3 buffer");
         return false;
      }
      
      rsi1 = buffer1[0];
      rsi2 = buffer2[0];
      rsi3 = buffer3[0];
      
      // Validation des valeurs
      if(rsi1 < 0 || rsi1 > 100 || rsi2 < 0 || rsi2 > 100 || rsi3 < 0 || rsi3 > 100)
      {
         Logger::Error("Invalid RSI values: " + DoubleToString(rsi1, 2) + "/" + 
                       DoubleToString(rsi2, 2) + "/" + DoubleToString(rsi3, 2));
         return false;
      }
      
      
      return true;
   }
   
   //--- Récupérer valeurs RSI historiques
   bool GetHistoricalValues(int barsBack, double &rsi1[], double &rsi2[], double &rsi3[])
   {
      if(!m_initialized)
      {
         Logger::Error("RSI Calculator not initialized");
         return false;
      }
      
      ArrayResize(rsi1, barsBack);
      ArrayResize(rsi2, barsBack);
      ArrayResize(rsi3, barsBack);
      ArraySetAsSeries(rsi1, true);
      ArraySetAsSeries(rsi2, true);
      ArraySetAsSeries(rsi3, true);
      
      // Copier les buffers historiques
      if(CopyBuffer(m_rsi1Handle, 0, 0, barsBack, rsi1) <= 0)
      {
         Logger::Error("Failed to copy historical RSI1 buffer");
         return false;
      }
      
      if(CopyBuffer(m_rsi2Handle, 0, 0, barsBack, rsi2) <= 0)
      {
         Logger::Error("Failed to copy historical RSI2 buffer");
         return false;
      }
      
      if(CopyBuffer(m_rsi3Handle, 0, 0, barsBack, rsi3) <= 0)
      {
         Logger::Error("Failed to copy historical RSI3 buffer");
         return false;
      }
      
      return true;
   }
   
   //--- Vérifier si initialisé
   bool IsInitialized() const { return m_initialized; }
   
   //--- Obtenir informations sur les handles
   string GetHandleInfo()
   {
      if(!m_initialized)
         return "Not initialized";
      
      return "RSI1:" + IntegerToString(m_rsi1Handle) + 
             " RSI2:" + IntegerToString(m_rsi2Handle) + 
             " RSI3:" + IntegerToString(m_rsi3Handle);
   }
   
   //--- Obtenir les handles RSI (pour divergence detection)
   void GetHandles(int &handle1, int &handle2, int &handle3)
   {
      handle1 = m_rsi1Handle;
      handle2 = m_rsi2Handle;
      handle3 = m_rsi3Handle;
   }
   
   //--- Cleanup
   void Deinitialize()
   {
      if(m_rsi1Handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_rsi1Handle);
         m_rsi1Handle = INVALID_HANDLE;
      }
      
      if(m_rsi2Handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_rsi2Handle);
         m_rsi2Handle = INVALID_HANDLE;
      }
      
      if(m_rsi3Handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_rsi3Handle);
         m_rsi3Handle = INVALID_HANDLE;
      }
      
      m_initialized = false;
      Logger::Debug("RSI Calculator deinitialized");
   }
};
