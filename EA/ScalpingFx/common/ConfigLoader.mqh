//+------------------------------------------------------------------+
//|                                            ConfigLoader.mqh      |
//|                        Configuration Loader with Group Classes    |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/TrailingTP_System.mqh"
#include "../../Shared/Logger.mqh"
#include "BotConfig.mqh"

//+------------------------------------------------------------------+
//| Base Configuration Group Class                                   |
//+------------------------------------------------------------------+
class CConfigGroup
{
protected:
   string            m_groupName;
   string            m_symbols[];
   BotConfig         m_config;
   int               m_symbolCount;
   
public:
   // Constructor
   CConfigGroup() 
   {
      m_symbolCount = 0;
   }
   
   // Virtual methods to be overridden by each group
   virtual bool Initialize() { return false; }
   virtual string GetGroupName() { return m_groupName; }
   virtual int GetSymbolCount() { return m_symbolCount; }
   virtual bool HasSymbol(string symbol) 
   { 
      for(int i = 0; i < m_symbolCount; i++)
      {
         if(m_symbols[i] == symbol) return true;
      }
      return false;
   }
   virtual string GetSymbol(int index)
   {
      if(index >= 0 && index < m_symbolCount)
         return m_symbols[index];
      return "";
   }
   
   // Get configuration for a specific symbol in this group
   BotConfig GetConfigForSymbol(string symbol)
   {
      BotConfig config = m_config;
      config.symbolsList = symbol; // Single symbol for this instance
      config.baseMagic = GenerateMagicNumber(m_config.baseMagic, symbol);
      return config;
   }
   
protected:
   // Helper method to add symbols to group
   void AddSymbols(string symbolsList)
   {
      string temp[];
      int count = StringSplit(symbolsList, ',', temp);
      ArrayResize(m_symbols, count);
      
      for(int i = 0; i < count; i++)
      {
         StringTrimLeft(temp[i]);
         StringTrimRight(temp[i]);
         m_symbols[i] = temp[i];
      }
      m_symbolCount = count;
   }
   
   // Generate unique magic number for symbol
   int GenerateMagicNumber(int baseMagic, string symbol)
   {
      ulong hash = 0;
      for(int i = 0; i < StringLen(symbol); i++)
         hash = hash * 31 + StringGetCharacter(symbol, i);
      return baseMagic + (int)(hash % 1000);
   }
   
   //--- Common parameter setup methods ---
   
   // Setup basic strategy parameters
   void SetupBasicParams(string strategyName, string strategyComment, int baseMagic)
   {
      m_config.strategyName = strategyName;
      m_config.strategyComment = strategyComment;
      m_config.baseMagic = baseMagic;
      m_config.useAllSymbols = false;
      m_config.timeframe = PERIOD_M5;
      m_config.strategyMode = STRATEGY_BREAKOUT;
   }
   
   // Setup risk and position sizing
   void SetupRiskParams(double riskPercent, int tpPoints, int slPoints)
   {
      m_config.riskPercent = riskPercent;
      m_config.tpPoints = tpPoints;
      m_config.slPoints = slPoints;
   }
   
   // Setup trailing stop parameters
   void SetupTrailingStop(int tslTriggerPoints, int tslPoints, bool useTrailingTP, 
                         ENUM_TRAILING_TP_MODE trailingTPMode, string customTPLevels = "")
   {
      m_config.tslTriggerPoints = tslTriggerPoints;
      m_config.tslPoints = tslPoints;
      m_config.useTrailingTP = useTrailingTP;
      m_config.trailingTPMode = trailingTPMode;
      if(customTPLevels != "") m_config.customTPLevels = customTPLevels;
   }
   
   // Setup trading hours
   void SetupTradingHours(int startHour, int endHour)
   {
      m_config.startHour = startHour;
      m_config.endHour = endHour;
   }
   
   // Setup strategy-specific parameters
   void SetupStrategyParams(int barsN, int expirationBars, int orderDistPoints, 
                           int slippagePoints = 10, int entryOffsetPoints = 0)
   {
      m_config.barsN = barsN;
      m_config.expirationBars = expirationBars;
      m_config.orderDistPoints = orderDistPoints;
      m_config.slippagePoints = slippagePoints;
      m_config.entryOffsetPoints = entryOffsetPoints;
   }
   
   // Setup risk multiplier
   void SetupRiskMultiplier(bool useRiskMultiplier, int startHour, int startMinute, 
                           int endHour, int endMinute, double multiplier, string description = "")
   {
      m_config.useRiskMultiplier = useRiskMultiplier;
      m_config.riskMultStartHour = startHour;
      m_config.riskMultStartMinute = startMinute;
      m_config.riskMultEndHour = endHour;
      m_config.riskMultEndMinute = endMinute;
      m_config.riskMultiplier = multiplier;
      if(description != "") m_config.riskMultDescription = description;
   }
   
   // Setup news filter parameters
   void SetupNewsFilter(bool useNewsFilter, string currencies = "USD,EUR,GBP", 
                       string keyEvents = "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP",
                       int stopBeforeMin = 30, int startAfterMin = 10, int lookupDays = 7)
   {
      m_config.useNewsFilter = useNewsFilter;
      m_config.newsCurrencies = currencies;
      m_config.keyNewsEvents = keyEvents;
      m_config.stopBeforeNewsMin = stopBeforeMin;
      m_config.startAfterNewsMin = startAfterMin;
      m_config.newsLookupDays = lookupDays;
      m_config.newsSeparator = COMMA;
   }
   
   // Setup block messages (used by all groups identically)
   void SetupBlockMessages()
   {
      m_config.newsBlockMsg = "📰 TRADING PAUSED - High Impact News Event";
      m_config.hourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
      m_config.dayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
      m_config.bothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";
   }
};

//+------------------------------------------------------------------+
//| EU/GU Forex Group Configuration                                  |
//+------------------------------------------------------------------+
class CEUGUForexGroup : public CConfigGroup
{
public:
   bool Initialize() override
   {
      m_groupName = "EU_GU_Forex";
      AddSymbols("EURUSD,GBPUSD");
      
      // Configuration from EU_GU_FXScalper.mq5
      SetupBasicParams("EU_GU_FXScalper V1.0", "EU_GU_FXScalper", 2971308);
      SetupRiskParams(1.0, 200, 180);
      SetupTrailingStop(10, 10, true, TRAILING_TP_CUSTOM, "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150");
      SetupTradingHours(7, 21);
      SetupStrategyParams(5, 50, 80,10,0);
      SetupRiskMultiplier(false, 13, 0, 17, 0, 2.0, "London-NY Overlap");
      SetupNewsFilter(false);
      SetupBlockMessages();
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| GER40 Index Group Configuration                                   |
//+------------------------------------------------------------------+
class CGER40IndexGroup : public CConfigGroup
{
public:
   bool Initialize() override
   {
      m_groupName = "GER40_Index";
      AddSymbols("GER40.cash");
      
      // Configuration from GER40_Scalper.mq5
      SetupBasicParams("GER40 Scalper V1.0", "GER40_Scalper", 28834731);
      SetupRiskParams(0.5, 7000, 5500);
      SetupTrailingStop(100, 50, true, TRAILING_TP_CUSTOM, "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150");
      SetupTradingHours(7, 18);
      SetupStrategyParams(6, 60, 120,50,30);
      SetupRiskMultiplier(true, 8, 0, 10, 0, 2.0, "Euro Session");
      SetupNewsFilter(true);
      SetupBlockMessages();
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| USDJPY Forex Group Configuration                                  |
//+------------------------------------------------------------------+
class CUSDJPYForexGroup : public CConfigGroup
{
public:
   bool Initialize() override
   {
      m_groupName = "USDJPY_Forex";
      AddSymbols("USDJPY");
      
      // Configuration from USDJPY_FXScalper.mq5
      SetupBasicParams("USDJPY_FXScalper V1.0", "USDJPY_FXScalper", 37483647);
      SetupRiskParams(0.25, 230, 210);
      SetupTrailingStop(30, 20, true, TRAILING_TP_CUSTOM, "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150");
      SetupTradingHours(13, 18);
      SetupStrategyParams(5, 50, 80,10,30);
      SetupRiskMultiplier(true, 14, 0, 15, 30, 2.0, "London-NY Overlap");
      SetupNewsFilter(true);
      SetupBlockMessages();
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| US100 Index Group Configuration                                   |
//+------------------------------------------------------------------+
class CUS100IndexGroup : public CConfigGroup
{
public:
   bool Initialize() override
   {
      m_groupName = "US100_Index";
      AddSymbols("US100.cash");
      
      // Configuration from USIndices_Scalper.mq5
      SetupBasicParams("US100 Index Scalper V1.0", "US100_Scalper", 29834757);
      SetupRiskParams(0.5, 5000, 5000);
      SetupTrailingStop(200, 150, true, TRAILING_TP_CUSTOM, "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150");
      SetupTradingHours(13,21);
      SetupStrategyParams(6, 60, 120,50,20);
      SetupRiskMultiplier(false, 14, 30, 18, 0, 2.0, "London-NY Overlap");
      SetupNewsFilter(true);
      SetupBlockMessages();
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| US30 Index Group Configuration                                    |
//+------------------------------------------------------------------+
class CUS30IndexGroup : public CConfigGroup
{
public:
   bool Initialize() override
   {
      m_groupName = "US30_Index";
      AddSymbols("US30.cash");
      
      // Configuration from USIndices_Scalper.mq5
      SetupBasicParams("US30 Index Scalper V1.0", "US30_Scalper", 29834758);
      SetupRiskParams(0.5, 7000, 5500);
      SetupTrailingStop(800, 400, true, TRAILING_TP_CUSTOM, "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150");
      SetupTradingHours(8, 21);
      SetupStrategyParams(5, 50, 140,50,200);
      SetupRiskMultiplier(true, 14, 0, 18, 0, 2.0, "London-NY Overlap");
      SetupNewsFilter(true);
      SetupBlockMessages();
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| US500 Index Group Configuration                                   |
//+------------------------------------------------------------------+
class CUS500IndexGroup : public CConfigGroup
{
public:
   bool Initialize() override
   {
      m_groupName = "US500_Index";
      AddSymbols("US500.cash");
      
      // Configuration from USIndices_Scalper.mq5
      SetupBasicParams("US500 Index Scalper V1.0", "US500_Scalper", 29834759);
      SetupRiskParams(0.25, 4000, 3600);
      SetupTrailingStop(210, 60, true, TRAILING_TP_CUSTOM, "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150");
      SetupTradingHours(8, 20);
      SetupStrategyParams(6, 60, 120,30,60);
      SetupRiskMultiplier(true, 14, 0, 18, 0, 2.0, "London-NY Overlap");
      SetupNewsFilter(true);
      SetupBlockMessages();
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| XAUUSD Gold Group Configuration                                   |
//+------------------------------------------------------------------+
class CXAUUSDGoldGroup : public CConfigGroup
{
public:
   bool Initialize() override
   {
      m_groupName = "XAUUSD_Gold";
      AddSymbols("XAUUSD");
      
      // Configuration from XAUUSD_Gold_Scalper.mq5
      SetupBasicParams("XAUUSD Gold Scalper V1.0", "XAUUSD_Gold_Scalper", 29479999);
      SetupRiskParams(0.25, 1600,1400);
      SetupTrailingStop(70, 25, true, TRAILING_TP_CUSTOM, "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150");
      SetupTradingHours(7, 20);
      SetupStrategyParams(6, 60, 90,30,40);
      SetupRiskMultiplier(true, 13, 15, 18, 0, 2.0, "London-NY Overlap");
      SetupNewsFilter(true);
      SetupBlockMessages();
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| Configuration Manager Class                                       |
//+------------------------------------------------------------------+
class CConfigManager
{
private:
   CConfigGroup*     m_groups[];
   int               m_groupCount;
   
public:
   // Constructor
   CConfigManager()
   {
      m_groupCount = 0;
   }
   
   // Destructor
   ~CConfigManager()
   {
      for(int i = 0; i < m_groupCount; i++)
      {
         if(m_groups[i] != NULL)
            delete m_groups[i];
      }
      ArrayFree(m_groups);
   }
   
   // Initialize all configuration groups
   bool Initialize()
   {
      // Create all group instances
      ArrayResize(m_groups, 7);
      
      m_groups[0] = new CEUGUForexGroup();
      m_groups[1] = new CGER40IndexGroup();
      m_groups[2] = new CUSDJPYForexGroup();
      m_groups[3] = new CUS100IndexGroup();
      m_groups[4] = new CUS30IndexGroup();
      m_groups[5] = new CUS500IndexGroup();
      m_groups[6] = new CXAUUSDGoldGroup();
      
      m_groupCount = 7;
      
      // Initialize each group
      for(int i = 0; i < m_groupCount; i++)
      {
         if(m_groups[i] == NULL || !m_groups[i].Initialize())
         {
            Logger::Error("❌ ERROR: Failed to initialize group " + IntegerToString(i));
            return false;
         }
      }
      
      Logger::Success("✅ ConfigManager: Loaded " + IntegerToString(m_groupCount) + " configuration groups");
      return true;
   }
   
   // Find configuration by symbol
   bool GetConfigForSymbol(string symbol, BotConfig &config)
   {
      // Validate symbol first
      if(!ValidateSymbol(symbol))
      {
         Logger::Error("❌ ERROR: Symbol " + symbol + " is not valid or not available");
         return false;
      }
      
      // Find the group containing this symbol
      for(int i = 0; i < m_groupCount; i++)
      {
         if(m_groups[i] != NULL && m_groups[i].HasSymbol(symbol))
         {
            config = m_groups[i].GetConfigForSymbol(symbol);
            Logger::Info("📋 Symbol: " + symbol + " → Magic: " + IntegerToString(config.baseMagic));
            Logger::Success("✅ Found configuration for " + symbol + " in group: " + m_groups[i].GetGroupName());
            return true;
         }
      }
      
      Logger::Error("❌ ERROR: No configuration found for symbol: " + symbol);
      return false;
   }
   
   // Get all symbols from all groups
   int GetAllSymbols(string &symbolss[])
   {
      int totalSymbols = 0;
      string temp[];
      
      for(int i = 0; i < m_groupCount; i++)
      {
         if(m_groups[i] != NULL)
         {
            int count = m_groups[i].GetSymbolCount();
            for(int j = 0; j < count; j++)
            {
               ArrayResize(temp, totalSymbols + 1);
               temp[totalSymbols] = m_groups[i].GetSymbol(j);
               totalSymbols++;
            }
         }
      }
      
      ArrayResize(symbolss, totalSymbols);
      for(int i = 0; i < totalSymbols; i++)
      {
         symbolss[i] = temp[i];
      }
      
      return totalSymbols;
   }
   
private:
   // Generate unique magic number for symbol
   int GenerateMagicNumber(int baseMagic, string symbol)
   {
      ulong hash = 0;
      for(int i = 0; i < StringLen(symbol); i++)
         hash = hash * 31 + StringGetCharacter(symbol, i);
      return baseMagic + (int)(hash % 1000);
   }
   
   // Validate symbol exists and is available
   bool ValidateSymbol(string symbol)
   {
      if(!SymbolSelect(symbol, true))
      {
         Logger::Error("❌ ERROR: Symbol " + symbol + " not found in Market Watch");
         return false;
      }
      
      if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
      {
         Logger::Error("❌ ERROR: Symbol " + symbol + " not available for trading");
         return false;
      }
      
      return true;
   }
};
