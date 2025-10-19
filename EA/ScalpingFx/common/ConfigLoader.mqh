//+------------------------------------------------------------------+
//|                                            ConfigLoader.mqh      |
//|                        Configuration Loader with Group Classes    |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../Shared/TradingEnums.mqh"
#include "../../Shared/TrailingTP_System.mqh"
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
      m_config.strategyName = "EU_GU_FXScalper V1.0";
      m_config.strategyComment = "EU_GU_FXScalper";
      m_config.baseMagic = 2971308;
      m_config.useAllSymbols = false;
      m_config.timeframe = PERIOD_M5;
      m_config.riskPercent = 1.0;
      m_config.tpPoints = 200;
      m_config.slPoints = 180;
      m_config.tslTriggerPoints = 10;
      m_config.tslPoints = 10;
      m_config.startHour = 7;
      m_config.endHour = 20;
      m_config.strategyMode = STRATEGY_BREAKOUT;
      m_config.barsN = 5;
      m_config.expirationBars = 50;
      m_config.orderDistPoints = 80;
      m_config.useTrailingTP = true;
      m_config.trailingTPMode = TRAILING_TP_CUSTOM;
      m_config.customTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150";
      m_config.useRiskMultiplier = false;
      m_config.riskMultStartHour = 13;
      m_config.riskMultStartMinute = 0;
      m_config.riskMultEndHour = 17;
      m_config.riskMultEndMinute = 0;
      m_config.riskMultiplier = 2.0;
      m_config.riskMultDescription = "London-NY Overlap";
      m_config.useNewsFilter = false;
      m_config.newsCurrencies = "USD,EUR,GBP";
      m_config.keyNewsEvents = "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP";
      m_config.stopBeforeNewsMin = 30;
      m_config.startAfterNewsMin = 10;
      m_config.newsLookupDays = 7;
      m_config.newsSeparator = COMMA;
      m_config.newsBlockMsg = "📰 TRADING PAUSED - High Impact News Event";
      m_config.hourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
      m_config.dayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
      m_config.bothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";
      
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
      m_config.strategyName = "GER40 Scalper V1.0";
      m_config.strategyComment = "GER40_Scalper";
      m_config.baseMagic = 28834731;
      m_config.useAllSymbols = false;
      m_config.timeframe = PERIOD_M5;
      m_config.riskPercent = 0.5;
      m_config.tpPoints = 5000;
      m_config.slPoints = 5000;
      m_config.tslTriggerPoints = 200;
      m_config.tslPoints = 150;
      m_config.startHour = 7;
      m_config.endHour = 21;
      m_config.strategyMode = STRATEGY_BREAKOUT;
      m_config.barsN = 6;
      m_config.expirationBars = 60;
      m_config.orderDistPoints = 120;
      m_config.useTrailingTP = true;
      m_config.trailingTPMode = TRAILING_TP_STEPPED;
      m_config.customTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150";
      m_config.useRiskMultiplier = true;
      m_config.riskMultStartHour = 8;
      m_config.riskMultStartMinute = 0;
      m_config.riskMultEndHour = 10;
      m_config.riskMultEndMinute = 0;
      m_config.riskMultiplier = 2.0;
      m_config.riskMultDescription = "Euro Session";
      m_config.useNewsFilter = true;
      m_config.newsCurrencies = "USD,EUR,GBP";
      m_config.keyNewsEvents = "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP";
      m_config.stopBeforeNewsMin = 30;
      m_config.startAfterNewsMin = 10;
      m_config.newsLookupDays = 7;
      m_config.newsSeparator = COMMA;
      m_config.newsBlockMsg = "📰 TRADING PAUSED - High Impact News Event";
      m_config.hourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
      m_config.dayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
      m_config.bothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";
      
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
      m_config.strategyName = "USDJPY_FXScalper V1.0";
      m_config.strategyComment = "USDJPY_FXScalper";
      m_config.baseMagic = 37483647;
      m_config.useAllSymbols = false;
      m_config.timeframe = PERIOD_M5;
      m_config.riskPercent = 0.5;
      m_config.tpPoints = 200;
      m_config.slPoints = 180;
      m_config.tslTriggerPoints = 10;
      m_config.tslPoints = 10;
      m_config.startHour = 13;
      m_config.endHour = 18;
      m_config.strategyMode = STRATEGY_BREAKOUT;
      m_config.barsN = 5;
      m_config.expirationBars = 50;
      m_config.orderDistPoints = 80;
      m_config.useTrailingTP = true;
      m_config.trailingTPMode = TRAILING_TP_CUSTOM;
      m_config.customTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150";
      m_config.useRiskMultiplier = true;
      m_config.riskMultStartHour = 14;
      m_config.riskMultStartMinute = 0;
      m_config.riskMultEndHour = 15;
      m_config.riskMultEndMinute = 30;
      m_config.riskMultiplier = 2.0;
      m_config.riskMultDescription = "London-NY Overlap";
      m_config.useNewsFilter = false;
      m_config.newsCurrencies = "USD,EUR,GBP";
      m_config.keyNewsEvents = "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP";
      m_config.stopBeforeNewsMin = 30;
      m_config.startAfterNewsMin = 10;
      m_config.newsLookupDays = 7;
      m_config.newsSeparator = COMMA;
      m_config.newsBlockMsg = "📰 TRADING PAUSED - High Impact News Event";
      m_config.hourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
      m_config.dayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
      m_config.bothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| US Indices Group Configuration                                    |
//+------------------------------------------------------------------+
class CUSIndicesGroup : public CConfigGroup
{
public:
   bool Initialize() override
   {
      m_groupName = "US_Indices";
      AddSymbols("US100.cash,US30.cash,US500.cash");
      
      // Configuration from USIndices_Scalper.mq5
      m_config.strategyName = "US Indices Scalper V1.0";
      m_config.strategyComment = "USIndices_Scalper";
      m_config.baseMagic = 29834757;
      m_config.useAllSymbols = false;
      m_config.timeframe = PERIOD_M5;
      m_config.riskPercent = 1.5;
      m_config.tpPoints = 5000;
      m_config.slPoints = 5000;
      m_config.tslTriggerPoints = 200;
      m_config.tslPoints = 150;
      m_config.startHour = 0;
      m_config.endHour = 0;
      m_config.strategyMode = STRATEGY_BREAKOUT;
      m_config.barsN = 6;
      m_config.expirationBars = 60;
      m_config.orderDistPoints = 120;
      m_config.useTrailingTP = true;
      m_config.trailingTPMode = TRAILING_TP_STEPPED;
      m_config.customTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150";
      m_config.useRiskMultiplier = true;
      m_config.riskMultStartHour = 14;
      m_config.riskMultStartMinute = 0;
      m_config.riskMultEndHour = 18;
      m_config.riskMultEndMinute = 0;
      m_config.riskMultiplier = 2.0;
      m_config.riskMultDescription = "London-NY Overlap";
      m_config.useNewsFilter = true;
      m_config.newsCurrencies = "USD,EUR,GBP";
      m_config.keyNewsEvents = "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP";
      m_config.stopBeforeNewsMin = 30;
      m_config.startAfterNewsMin = 10;
      m_config.newsLookupDays = 7;
      m_config.newsSeparator = COMMA;
      m_config.newsBlockMsg = "📰 TRADING PAUSED - High Impact News Event";
      m_config.hourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
      m_config.dayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
      m_config.bothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";
      
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
      m_config.strategyName = "XAUUSD Gold Scalper V1.0";
      m_config.strategyComment = "XAUUSD_Gold_Scalper";
      m_config.baseMagic = 29479999;
      m_config.useAllSymbols = false;
      m_config.timeframe = PERIOD_M5;
      m_config.riskPercent = 0.5;
      m_config.tpPoints = 1500;
      m_config.slPoints = 1500;
      m_config.tslTriggerPoints = 20;
      m_config.tslPoints = 15;
      m_config.startHour = 10;
      m_config.endHour = 17;
      m_config.strategyMode = STRATEGY_BREAKOUT;
      m_config.barsN = 6;
      m_config.expirationBars = 60;
      m_config.orderDistPoints = 120;
      m_config.useTrailingTP = true;
      m_config.trailingTPMode = TRAILING_TP_STEPPED;
      m_config.customTPLevels = "25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150";
      m_config.useRiskMultiplier = true;
      m_config.riskMultStartHour = 13;
      m_config.riskMultStartMinute = 0;
      m_config.riskMultEndHour = 18;
      m_config.riskMultEndMinute = 0;
      m_config.riskMultiplier = 2.0;
      m_config.riskMultDescription = "London-NY Overlap";
      m_config.useNewsFilter = true;
      m_config.newsCurrencies = "USD,EUR,GBP";
      m_config.keyNewsEvents = "NFP,JOLTS,Nonfarm,PMI,Interest Rate,CPI,GDP";
      m_config.stopBeforeNewsMin = 30;
      m_config.startAfterNewsMin = 10;
      m_config.newsLookupDays = 7;
      m_config.newsSeparator = COMMA;
      m_config.newsBlockMsg = "📰 TRADING PAUSED - High Impact News Event";
      m_config.hourBlockMsg = "⏰ TRADING PAUSED - Outside Trading Hours";
      m_config.dayBlockMsg = "📅 TRADING PAUSED - Outside Trading Days";
      m_config.bothBlockMsg = "🚫 TRADING PAUSED - Outside Trading Schedule";
      
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
      ArrayResize(m_groups, 5);
      
      m_groups[0] = new CEUGUForexGroup();
      m_groups[1] = new CGER40IndexGroup();
      m_groups[2] = new CUSDJPYForexGroup();
      m_groups[3] = new CUSIndicesGroup();
      m_groups[4] = new CXAUUSDGoldGroup();
      
      m_groupCount = 5;
      
      // Initialize each group
      for(int i = 0; i < m_groupCount; i++)
      {
         if(m_groups[i] == NULL || !m_groups[i].Initialize())
         {
            Print("❌ ERROR: Failed to initialize group ", i);
            return false;
         }
      }
      
      Print("✅ ConfigManager: Loaded ", m_groupCount, " configuration groups");
      return true;
   }
   
   // Find configuration by symbol
   bool GetConfigForSymbol(string symbol, BotConfig &config)
   {
      // Validate symbol first
      if(!ValidateSymbol(symbol))
      {
         Print("❌ ERROR: Symbol ", symbol, " is not valid or not available");
         return false;
      }
      
      // Find the group containing this symbol
      for(int i = 0; i < m_groupCount; i++)
      {
         if(m_groups[i] != NULL && m_groups[i].HasSymbol(symbol))
         {
            config = m_groups[i].GetConfigForSymbol(symbol);
            Print("✅ Found configuration for ", symbol, " in group: ", m_groups[i].GetGroupName());
            return true;
         }
      }
      
      Print("❌ ERROR: No configuration found for symbol: ", symbol);
      return false;
   }
   
   // Get all symbols from all groups
   int GetAllSymbols(string &symbols[])
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
      
      ArrayResize(symbols, totalSymbols);
      for(int i = 0; i < totalSymbols; i++)
      {
         symbols[i] = temp[i];
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
         Print("❌ ERROR: Symbol ", symbol, " not found in Market Watch");
         return false;
      }
      
      if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
      {
         Print("❌ ERROR: Symbol ", symbol, " not available for trading");
         return false;
      }
      
      return true;
   }
};
