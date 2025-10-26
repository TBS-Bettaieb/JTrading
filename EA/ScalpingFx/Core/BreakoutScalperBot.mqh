//+------------------------------------------------------------------+
//|                                           BreakoutScalperBot.mqh    |
//|                                Bot Engine - All Logic Here       |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include "../../../EA/Shared/TradingEnums.mqh"
#include "../../../EA/Shared/TradingUtils.mqh"
#include "../../../EA/Shared/TradingTimeManager.mqh"
#include "../../../EA/Shared/ChartManager.mqh"
#include "../../../EA/Shared/NewsFilterManager.mqh"
#include "../../../EA/Shared/Logger.mqh"
#include "../common/config/BotConfig.mqh"
#include "BreakoutScalperTrader.mqh"
#include "BreakoutScalperManager.mqh"
#include "../../Shared/Filters/RiskMultiplierManager.mqh"

//+------------------------------------------------------------------+
//| Main Bot Class                                                   |
//+------------------------------------------------------------------+
class BreakoutScalperBot
{
private:
   BotConfig         m_config;
   ChartManager*     m_chartManager;
   TradingTimeManager* m_timeManager;
   RiskMultiplierManager* m_riskMultiplierManager;
   NewsFilterManager* m_newsFilterManager;
   BreakoutScalperTrader* m_symbolTraders[];
   string            m_symbols[];
   int               m_totalSymbols;
   int               m_tickCount;
   int               m_detailUpdateCount;
   
public:
   //--- Constructor
   BreakoutScalperBot(BotConfig &config)
   {
      m_config = config;
      m_chartManager = NULL;
      m_timeManager = NULL;
      m_riskMultiplierManager = NULL;
      m_newsFilterManager = NULL;
      m_totalSymbols = 0;
      m_tickCount = 0;
      m_detailUpdateCount = 0;
   }
   
   //--- Destructor
   ~BreakoutScalperBot()
   {
      // Cleanup is done in Deinitialize
   }
   
   //--- Initialize bot
   bool Initialize()
   {
      Logger::Initialize(m_config.logLevel, "[" + m_config.strategyName + "] ");
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🚀 Initializing " + m_config.strategyName);
      Logger::Info("═══════════════════════════════════════");
      
      // Step 1: Validate Trailing TP if needed
      if(!ValidateTrailingTP())
         return false;
      
      // Step 2: Parse and validate symbols
      if(!ParseSymbols())
         return false;
      
      // Step 3: Validate historical data
      if(!ValidateHistoricalData())
         return false;
      
      // Step 4: Calculate risk
      double riskPerSymbol = CalculateRiskPerSymbol(m_config.riskPercent, m_totalSymbols);
      Logger::Info("💰 Risk per symbol: " + DoubleToString(riskPerSymbol, 2) + "% (Total: " + 
            DoubleToString(m_config.riskPercent, 2) + "%)");
      
      // Step 5: Create symbol traders
      if(!CreateSymbolTraders(riskPerSymbol))
         return false;
      
      // Step 6: Initialize Chart Manager
      if(!InitializeChartManager())
         return false;
      
      // Step 7: Initialize Time Manager
      if(!InitializeTimeManager())
         return false;
      
      // Step 8: Initialize Risk Multiplier Manager
      if(!InitializeRiskMultiplier())
         return false;
      
      // Step 9: Initialize News Filter Manager
      if(!InitializeNewsFilter())
         return false;
      
      // Final summary
      PrintInitializationSummary();
      
      return true;
   }
   
   //--- Deinitialize bot
   void Deinitialize(const int reason)
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🛑 " + m_config.strategyName + " stopping...");
      Logger::Info("Reason: " + IntegerToString(reason));
      Logger::Info("═══════════════════════════════════════");
      
      // Cleanup symbol traders
      if(ArraySize(m_symbolTraders) > 0)
      {
         for(int i = 0; i < ArraySize(m_symbolTraders); i++)
         {
            if(m_symbolTraders[i] != NULL)
            {
               delete m_symbolTraders[i];
               m_symbolTraders[i] = NULL;
            }
         }
         ArrayFree(m_symbolTraders);
         Logger::Success("✅ Symbol Traders cleaned up");
      }
      
      // Cleanup Risk Multiplier Manager
      if(m_riskMultiplierManager != NULL)
      {
         delete m_riskMultiplierManager;
         m_riskMultiplierManager = NULL;
         Logger::Success("✅ Risk Multiplier Manager cleaned up");
      }
      
      // Cleanup News Filter Manager
      if(m_newsFilterManager != NULL)
      {
         delete m_newsFilterManager;
         m_newsFilterManager = NULL;
         Logger::Success("✅ News Filter Manager cleaned up");
      }
      
      // Cleanup Time Manager
      if(m_timeManager != NULL)
      {
         delete m_timeManager;
         m_timeManager = NULL;
         Logger::Success("✅ Time Manager cleaned up");
      }
      
      // Cleanup Chart Manager
      if(m_chartManager != NULL)
      {
         delete m_chartManager;
         m_chartManager = NULL;
         Logger::Success("✅ Chart Manager cleaned up");
      }
      
      ArrayFree(m_symbols);
      Logger::Success("✅ All resources cleaned up successfully");
      Logger::Info("═══════════════════════════════════════");
   }
   
   //--- Main tick handler
   void OnTick()
   {
      // Validate objects
      if(m_chartManager == NULL || m_timeManager == NULL || ArraySize(m_symbolTraders) == 0)
         return;
      
      // 🆕 Vérifier changement de Risk Multiplier
      if(m_riskMultiplierManager != NULL && m_riskMultiplierManager.HasStatusChanged())
      {
         double currentMultiplier = m_riskMultiplierManager.GetCurrentMultiplier();
         AdjustAllPositionSizes(currentMultiplier);
      }
      
      // Check trading permissions
      bool timeAllowed = m_timeManager.IsTradingAllowed();
      bool newsAllowed = !m_config.useNewsFilter || 
                         (m_newsFilterManager != NULL && 
                          !m_newsFilterManager.IsNewsBlocking());
      
      bool tradingAllowed = timeAllowed && newsAllowed;
      
      // 🆕 Vérifier changement de statut news
      if(m_newsFilterManager != NULL && m_newsFilterManager.HasStatusChanged())
      {
         string newsStatus = m_newsFilterManager.GetStatusMessage();
         if(newsStatus != "")
            Logger::Info("📰 NEWS ALERT: " + newsStatus);
      }
      
      // 🆕 Obtenir multiplicateur actuel
      double currentRiskMultiplier = 1.0;
      if(m_riskMultiplierManager != NULL)
         currentRiskMultiplier = m_riskMultiplierManager.GetCurrentMultiplier();
      
      // Process all symbols
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            // 🆕 Mettre à jour le multiplicateur
            m_symbolTraders[i].SetRiskMultiplier(currentRiskMultiplier);
            
            // 🆕 Traiter le trailing à chaque tick (avant OnTick)
            m_symbolTraders[i].ProcessTrailing();
            
            if(tradingAllowed)
            {
               m_symbolTraders[i].OnTick();
            }
            else
            {
               m_symbolTraders[i].CancelAllPendingOrders();
            }
         }
      }
      
      // Update chart display
      UpdateChartInfo();
   }
   
   //--- Get ChartManager for external access
   ChartManager* GetChartManager() const { return m_chartManager; }

private:
   //--- Validate Trailing TP configuration
   bool ValidateTrailingTP()
   {
      if(m_config.useTrailingTP && m_config.trailingTPMode == TRAILING_TP_CUSTOM)
      {
         Logger::Debug("🔍 Validation Custom Trailing TP...");
         string errorMessage;
         bool isValid = CTrailingTPValidator::ValidateCustomLevelsString(
            m_config.customTPLevels, errorMessage);
         
         if(!isValid)
         {
            Logger::Error("❌ ERREUR: " + errorMessage);
            Logger::Info("💡 Exemple: \"50:0:0, 75:25:50, 100:50:100\"");
            return false;
         }
         
         CTrailingTPValidator::PrintParsedLevels(m_config.customTPLevels);
         Logger::Info(errorMessage);
      }
      return true;
   }
   
   //--- Parse symbols list
   bool ParseSymbols()
   {
      if(m_config.useAllSymbols)
      {
         m_totalSymbols = GetSymbolsFromMarketWatch(m_symbols);
         Logger::Info("📊 Using all symbols from Market Watch: " + IntegerToString(m_totalSymbols) + " symbols");
      }
      else
      {
         m_totalSymbols = ParseSymbolsList(m_config.symbolsList, m_symbols);
         Logger::Info("📊 Using custom symbols list: " + IntegerToString(m_totalSymbols) + " symbols");
      }
      
      if(m_totalSymbols <= 0)
      {
         Logger::Error("❌ ERROR: No valid symbols found");
         return false;
      }
      
      return true;
   }
   
   //--- Validate historical data
   bool ValidateHistoricalData()
   {
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(!CheckHistoricalData(m_symbols[i], m_config.timeframe))
         {
            Logger::Warning("⚠️ Warning: Limited historical data for " + m_symbols[i]);
         }
      }
      return true;
   }
   
   //--- Create symbol traders
   bool CreateSymbolTraders(double riskPerSymbol)
   {
      ArrayResize(m_symbolTraders, m_totalSymbols);
      
      // Afficher le mapping des magic numbers
      PrintMagicNumberMapping(m_symbols, m_config.baseMagic, m_config.timeframe);
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         // Générer un magic number unique par symbole
         int symbolMagic = GenerateSymbolMagicNumber(
            m_config.baseMagic, 
            m_symbols[i], 
            m_config.timeframe
         );
         
         Logger::Info("✅ Creating trader for " + m_symbols[i] + " with magic " + IntegerToString(symbolMagic));
         
         m_symbolTraders[i] = new BreakoutScalperTrader(
            m_symbols[i],
            symbolMagic,  // ✅ CORRECTION : magic unique
            m_config.timeframe,
            riskPerSymbol,
            m_config.tpPoints,
            m_config.slPoints,
            m_config.tslTriggerPoints,
            m_config.tslPoints,
            m_config.barsN,
            m_config.expirationBars,
            m_config.orderDistPoints,
            m_config.slippagePoints,        // NEW
            m_config.entryOffsetPoints,     // NEW
            m_config.strategyComment,
            m_config.strategyMode,
            m_config.useTrailingTP,
            m_config.trailingTPMode,
            m_config.customTPLevels,
            m_config.useDynamicTSLTrigger,      // 🆕 AJOUTER
            m_config.tslCostMultiplier,         // 🆕 AJOUTER
            m_config.tslMinTriggerPoints        // 🆕 AJOUTER
         );
         
         if(m_symbolTraders[i] == NULL)
         {
            Logger::Error("❌ ERROR: Failed to create BreakoutScalperTrader for " + m_symbols[i]);
            return false;
         }
      }
      
      return true;
   }
   
   //--- Initialize Chart Manager
   bool InitializeChartManager()
   {
      m_chartManager = new ChartManager(0, "BreakoutScalperBot");
      
      if(m_chartManager != NULL)
      {
         m_chartManager.SetupChart();
         m_chartManager.ShowStrategyName(m_config.strategyName);
         PrintSymbolsInfo(m_symbols, m_config.baseMagic, m_config.timeframe, "BreakoutScalperRobot");
         return true;
      }
      else
      {
         Logger::Warning("⚠️ Warning: Chart Manager initialization failed");
         return true; // Non-critical
      }
   }
   
   //--- Initialize Time Manager
   bool InitializeTimeManager()
   {
      m_timeManager = new TradingTimeManager(m_chartManager);
      
      // Utiliser le nouveau format unifié si disponible
      if(m_config.tradingTimeRanges != "")
      {
         m_timeManager.Initialize(
            true,  // useHourFilter
            m_config.tradingTimeRanges,
            false, // useDayFilter
            "",    // dayRanges
            true   // verboseLogging
         );
      }
      else
      {
         // Fallback vers l'ancien format (rétro-compatibilité)
         m_timeManager.Initialize(
            (m_config.startHour != 0 || m_config.endHour != 0),
            IntegerToString(m_config.startHour) + "-" + IntegerToString(m_config.endHour),
            false,
            "",
            true
         );
      }
      
      m_timeManager.SetVerboseLogging(true);
      m_timeManager.SetAlertMessages(m_config.hourBlockMsg, m_config.dayBlockMsg, 
                                     m_config.bothBlockMsg);
      
      Logger::Info("⏰ Time Manager Configuration:");
      Logger::Info(m_timeManager.GetDetailedInfo());
      
      return true;
   }
   
   //--- Initialize Risk Multiplier Manager
   bool InitializeRiskMultiplier()
   {
      m_riskMultiplierManager = new RiskMultiplierManager();
      if(m_riskMultiplierManager == NULL)
      {
         Logger::Warning("⚠️ Warning: Risk Multiplier Manager creation failed");
         return true; // Non-critical
      }
      
      // Utiliser le nouveau format unifié si disponible
      if(m_config.riskMultTimeRanges != "")
      {
         m_riskMultiplierManager.InitializeUnified(
            m_config.useRiskMultiplier,
            m_config.riskMultTimeRanges,
            m_config.riskMultiplier,
            m_config.riskMultDescription
         );
      }
      else
      {
         // Fallback vers l'ancien format (rétro-compatibilité)
         m_riskMultiplierManager.Initialize(
            m_config.useRiskMultiplier,
            m_config.riskMultStartHour,
            m_config.riskMultStartMinute,
            m_config.riskMultEndHour,
            m_config.riskMultEndMinute,
            m_config.riskMultiplier,
            m_config.riskMultDescription
         );
      }
      
      return true;
   }
   
   //--- Initialize News Filter Manager
   bool InitializeNewsFilter()
   {
      m_newsFilterManager = new NewsFilterManager();
      if(m_newsFilterManager == NULL)
      {
         Logger::Warning("⚠️ Warning: News Filter Manager creation failed");
         return true; // Non-critical
      }
      
      m_newsFilterManager.Initialize(
         m_config.useNewsFilter,
         m_config.newsCurrencies,
         m_config.keyNewsEvents,
         m_config.stopBeforeNewsMin,
         m_config.startAfterNewsMin,
         m_config.newsLookupDays,
         m_config.newsSeparator
      );
      
      if(m_config.useNewsFilter)
      {
         Logger::Info("📰 NEWS FILTER ENABLED");
         Logger::Info("   Currencies: " + m_config.newsCurrencies);
         Logger::Info("   Events: " + m_config.keyNewsEvents);
         Logger::Info("   Stop Before: " + IntegerToString(m_config.stopBeforeNewsMin) + " min");
         Logger::Info("   Resume After: " + IntegerToString(m_config.startAfterNewsMin) + " min");
      }
      
      return true;
   }
   
   //--- Print initialization summary
   void PrintInitializationSummary()
   {
      Logger::Success("✅ Initialization completed successfully!");
      Logger::Info("📈 Trading " + IntegerToString(m_totalSymbols) + " symbols simultaneously");
      Logger::Info("🕒 Timeframe: " + EnumToString(m_config.timeframe));
      
      if(m_config.useTrailingTP)
      {
         Logger::Info("🎯 TRAILING TP: " + EnumToString(m_config.trailingTPMode));
         if(m_config.trailingTPMode == TRAILING_TP_CUSTOM)
            Logger::Info("   Niveaux: " + m_config.customTPLevels);
      }
      
      if(m_config.useRiskMultiplier && m_riskMultiplierManager != NULL)
      {
         Logger::Info("🚀 RISK MULTIPLIER: " + m_riskMultiplierManager.GetDetailedInfo());
      }
      
      if(m_config.useNewsFilter && m_newsFilterManager != NULL)
      {
         Logger::Info("📰 NEWS FILTER: " + m_newsFilterManager.GetDetailedInfo());
      }
      
      Logger::Info("═══════════════════════════════════════");
   }
   
   //--- Ajuster toutes les positions
   void AdjustAllPositionSizes(double multiplier)
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🔄 AJUSTEMENT DES POSITIONS - Multiplier: x" + DoubleToString(multiplier, 2));
      Logger::Info("═══════════════════════════════════════");
      
      int adjustedCount = 0;
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            int adjusted = m_symbolTraders[i].AdjustPositionSizes(multiplier);
            adjustedCount += adjusted;
         }
      }
      
      if(adjustedCount > 0)
         Logger::Info("✅ " + IntegerToString(adjustedCount) + " position(s) ajustée(s)");
      else
         Logger::Info("ℹ️ Aucune position à ajuster");
      
      Logger::Info("═══════════════════════════════════════");
   }
   
   //--- Update chart information
   void UpdateChartInfo()
   {
      if(m_chartManager == NULL || ArraySize(m_symbolTraders) == 0) return;
      
      m_tickCount++;
      
      // Update every 100 ticks
      if(m_tickCount % 100 != 0) return;
      
      // Build global status
      string globalStatus = GetGlobalSymbolsStatus(m_symbols, m_symbolTraders);
      string timeStatus = m_timeManager.GetStatusDescription();
      
      // Determine color and build status
      color statusColor = clrGreen;
      
      // 🆕 Ajouter status News
      string newsStatus = "";
      if(m_newsFilterManager != NULL && m_config.useNewsFilter)
      {
         if(m_newsFilterManager.IsNewsBlocking())
         {
            newsStatus = m_newsFilterManager.GetStatusMessage();
            statusColor = clrRed;
         }
      }
      
      // 🆕 Ajouter status Risk Multiplier
      string riskMultStatus = "";
      if(m_riskMultiplierManager != NULL && m_config.useRiskMultiplier)
      {
         riskMultStatus = m_riskMultiplierManager.GetStatusDescription();
      }
      
      // Build combined status
      if(newsStatus != "")
         globalStatus = newsStatus + " | " + timeStatus + " | " + globalStatus;
      else
         globalStatus = timeStatus + " | " + globalStatus;
      
      if(riskMultStatus != "")
         globalStatus = riskMultStatus + " | " + globalStatus;
      ENUM_TRADING_STATUS status = m_timeManager.GetCurrentStatus();
      
      if(status != TRADING_ACTIVE)
         statusColor = clrOrange;
      else if(m_riskMultiplierManager != NULL && m_riskMultiplierManager.IsInActivePeriod())
         statusColor = clrYellow;
      else if(StringFind(globalStatus, "P/L: -") >= 0)
         statusColor = clrRed;
      else if(StringFind(globalStatus, "P/L: ") >= 0)
         statusColor = clrLime;
      
      // Update main label
      m_chartManager.UpdateLabelText("TopRight", globalStatus);
      m_chartManager.UpdateLabelColor("TopRight", statusColor);
      
      // Update details every 500 ticks
      m_detailUpdateCount++;
      if(m_detailUpdateCount % 500 == 0)
      {
         UpdateDetailedInfo();
      }
   }
   
   //--- Update detailed information
   void UpdateDetailedInfo()
   {
      // Suppression de l'affichage des détails des symboles
      // On garde seulement le refresh des swing points
      
      // Supprimer les anciens labels de symbol details s'ils existent
      if(m_chartManager != NULL)
      {
         // Supprimer spécifiquement le groupe "SymbolDetails"
         long chartId = m_chartManager.GetChartId();
         string prefix = m_chartManager.GetLabelPrefix();
         string searchPattern = prefix + "_SymbolDetails_";
         
         int total = ObjectsTotal(chartId);
         for(int i = total - 1; i >= 0; i--)
         {
            string objName = ObjectName(chartId, i);
            if(StringFind(objName, searchPattern) == 0)
            {
               ObjectDelete(chartId, objName);
            }
         }
         ChartRedraw(chartId);
      }
      
      // Refresh swing points seulement
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            m_symbolTraders[i].RefreshSwingDisplay();
         }
      }
   }
};
//+------------------------------------------------------------------+
