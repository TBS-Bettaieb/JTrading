//+------------------------------------------------------------------+
//|                                           ForexScalperBot.mqh    |
//|                                Bot Engine - All Logic Here       |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include "../../../EA/Shared/TradingEnums.mqh"
#include "../../../EA/Shared/TradingUtils.mqh"
#include "../../../EA/Shared/TradingTimeManager.mqh"
#include "../../../EA/Shared/ChartManager.mqh"
#include "../../../EA/Shared/NewsFilterManager.mqh"
#include "../../../EA/Shared/Logger.mqh"
#include "../../../EA/Shared/Orchestration/MultiSymbolCoordinator.mqh"
#include "../common/BotConfig.mqh"
#include "../common/RiskMultiplierManager.mqh"
#include "../common/ForexSymbolManager.mqh"

//+------------------------------------------------------------------+
//| Classe ForexScalperBot - Version modulaire                        |
//+------------------------------------------------------------------+
class ForexScalperBot
{
private:
   BotConfig         m_config;
   ChartManager*     m_chartManager;
   TradingTimeManager* m_timeManager;
   RiskMultiplierManager* m_riskMultiplierManager;
   NewsFilterManager* m_newsFilterManager;
   MultiSymbolCoordinator* m_coordinator;  // 🆕 Coordinateur multi-symboles
   
   string            m_symbols[];
   int               m_totalSymbols;
   int               m_tickCount;
   int               m_detailUpdateCount;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   ForexScalperBot(BotConfig &config)
   {
      m_config = config;
      m_chartManager = NULL;
      m_timeManager = NULL;
      m_riskMultiplierManager = NULL;
      m_newsFilterManager = NULL;
      m_coordinator = NULL;  // 🆕
      m_totalSymbols = 0;
      m_tickCount = 0;
      m_detailUpdateCount = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~ForexScalperBot()
   {
      // Cleanup is done in Deinitialize
   }
   
   //+------------------------------------------------------------------+
   //| Initialize bot                                                   |
   //+------------------------------------------------------------------+
   bool Initialize(bool skipLoggerInit = false)
   {
      if(!skipLoggerInit)
      {
         Logger::Initialize(m_config.logLevel, "[" + m_config.strategyName + "] ");
      }
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
      
      // Step 5: 🆕 Create MultiSymbolCoordinator
      if(!CreateMultiSymbolCoordinator(riskPerSymbol))
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
   
   //+------------------------------------------------------------------+
   //| Deinitialize bot                                                 |
   //+------------------------------------------------------------------+
   void Deinitialize(const int reason)
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🛑 " + m_config.strategyName + " stopping...");
      Logger::Info("Reason: " + IntegerToString(reason));
      Logger::Info("═══════════════════════════════════════");
      
      // 🆕 Cleanup MultiSymbolCoordinator (nettoie automatiquement tous les managers)
      if(m_coordinator != NULL)
      {
         delete m_coordinator;
         m_coordinator = NULL;
         Logger::Success("✅ MultiSymbolCoordinator cleaned up");
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
   
   //+------------------------------------------------------------------+
   //| Main tick handler - VERSION OPTIMISÉE POUR PERFORMANCE          |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // ========== ÉTAPE 1: VALIDATION MINIMALE ==========
      // ✅ OPTIMISATION: Validation silencieuse (pas de logs à chaque tick)
      if(m_coordinator == NULL) return;
      
      // ========== ÉTAPE 2: VÉRIFIER CHANGEMENT RISK MULTIPLIER AVANT RÉCUPÉRATION ==========
      // ✅ Détecter changement AVANT récupération (comportement ancienne version)
      if(m_riskMultiplierManager != NULL && m_riskMultiplierManager.HasStatusChanged())
      {
         double newMultiplier = m_riskMultiplierManager.GetCurrentMultiplier();
         AdjustAllPositionSizes(newMultiplier);
      }

      // ========== ÉTAPE 3: RÉCUPÉRER MULTIPLICATEUR ACTUEL ==========
      // ✅ Récupérer après ajustement des positions existantes
      double currentRiskMultiplier = 1.0;
      if(m_riskMultiplierManager != NULL)
         currentRiskMultiplier = m_riskMultiplierManager.GetCurrentMultiplier();

      // ========== ÉTAPE 4: METTRE À JOUR MULTIPLICATEUR DANS COORDINATEUR ==========
      // ✅ Mettre à jour pour nouveaux ordres
      m_coordinator.SetGlobalRiskMultiplier(currentRiskMultiplier);

      // ========== ÉTAPE 5: CALCULER PERMISSIONS DE TRADING ==========
      bool timeAllowed = m_timeManager.IsTradingAllowed();
      bool newsAllowed = !m_config.useNewsFilter || 
                         (m_newsFilterManager != NULL && 
                          !m_newsFilterManager.IsNewsBlocking());

      bool tradingAllowed = timeAllowed && newsAllowed;

      // ========== ÉTAPE 6: VÉRIFIER CHANGEMENT STATUT NEWS ==========
      // ✅ Logs seulement lors de changement de statut
      if(m_newsFilterManager != NULL && m_newsFilterManager.HasStatusChanged())
      {
         string newsStatus = m_newsFilterManager.GetStatusMessage();
         if(newsStatus != "")
            Logger::Info("📰 NEWS ALERT: " + newsStatus);
      }
      
      // ========== ÉTAPE 7: TRAITER TOUS LES SYMBOLES ==========
      // ✅ CRITIQUE: Reproduit EXACTEMENT le comportement de l'ancienne version
      
      // A. NOUVELLES ENTRÉES (seulement si autorisé)
      if(tradingAllowed)
      {
         ProcessTradingLogic();  // Appelle m_coordinator.OnTick()
      }
      else
      {
         // B. ✅ ANNULER SYSTÉMATIQUEMENT tous ordres pending si !tradingAllowed
         m_coordinator.CancelAllPendingOrders();
      }
      
      // C. ✅ TOUJOURS GÉRER LES POSITIONS OUVERTES (trailing stops, trailing TP)
      // Indépendamment de tradingAllowed, comme dans l'ancienne version
      m_coordinator.ManageOpenPositions();
      
      // ========== ÉTAPE 8: UPDATE CHART ==========
      UpdateChartInfo();
   }
   
   //+------------------------------------------------------------------+
   //| Get ChartManager for external access                            |
   //+------------------------------------------------------------------+
   ChartManager* GetChartManager() const { return m_chartManager; }
   
   //+------------------------------------------------------------------+
   //| 🆕 Get MultiSymbolCoordinator for external access               |
   //+------------------------------------------------------------------+
   MultiSymbolCoordinator* GetCoordinator() const { return m_coordinator; }

private:
   //+------------------------------------------------------------------+
   //| 🆕 Create MultiSymbolCoordinator                                |
   //+------------------------------------------------------------------+
   bool CreateMultiSymbolCoordinator(double riskPerSymbol)
   {
      m_coordinator = new MultiSymbolCoordinator(m_config.baseMagic);
      if(m_coordinator == NULL)
      {
         Logger::Error("❌ ERROR: Failed to create MultiSymbolCoordinator");
         return false;
      }
      
      // Afficher le mapping des magic numbers
      PrintMagicNumberMapping(m_symbols, m_config.baseMagic, m_config.timeframe);
      
      // Ajouter chaque symbole au coordinateur
      for(int i = 0; i < m_totalSymbols; i++)
      {
         Logger::Info("✅ Adding symbol to coordinator: " + m_symbols[i]);
         
         bool success = m_coordinator.AddSymbol(
            m_symbols[i],
            m_config.timeframe,
            riskPerSymbol,
            m_config.tpPoints,
            m_config.slPoints,
            m_config.expirationBars,
            m_config.slippagePoints,
            m_config.strategyComment,
            m_config.strategyMode,
            m_config.useTrailingTP,
            m_config.trailingTPMode,
            m_config.customTPLevels,
            m_config.tslTriggerPoints,
            m_config.tslPoints,
            m_config.barsN,
            m_config.orderDistPoints,
            m_config.entryOffsetPoints,
            m_config.useDynamicTSLTrigger,
            m_config.tslCostMultiplier,
            m_config.tslMinTriggerPoints
         );
         
         if(!success)
         {
            Logger::Error("❌ ERROR: Failed to add symbol " + m_symbols[i] + " to coordinator");
            return false;
         }
      }
      
      Logger::Info("✅ MultiSymbolCoordinator created with " + IntegerToString(m_totalSymbols) + " symbols");
      
      // 🔥 VALIDATION CRITIQUE: Vérifier que tous les managers sont correctement initialisés
      Logger::Info("🔍 Validating managers for all symbols...");
      for(int i = 0; i < m_totalSymbols; i++)
      {
         string errorMessage;
         if(!m_coordinator.ValidateSymbolManagers(m_symbols[i], errorMessage))
         {
            Logger::Error("❌ CRITICAL: Manager validation failed for " + m_symbols[i]);
            Logger::Error("❌ Error: " + errorMessage);
            return false;
         }
         
         Logger::Debug("✅ All managers validated for " + m_symbols[i]);
      }
      
      Logger::Success("✅ All managers validated successfully for " + IntegerToString(m_totalSymbols) + " symbols");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Process trading logic - Appeler le coordinateur               |
   //+------------------------------------------------------------------+
   void ProcessTradingLogic()
   {
      // ✅ OPTIMISATION: Validation silencieuse (déjà validé dans OnTick)
      if(m_coordinator == NULL) return;
      
      // Appeler le coordinateur pour traiter tous les symboles
      m_coordinator.OnTick();
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Ajuster toutes les positions via le coordinateur             |
   //+------------------------------------------------------------------+
   void AdjustAllPositionSizes(double multiplier)
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🔄 AJUSTEMENT DES POSITIONS - Multiplier: x" + DoubleToString(multiplier, 2));
      Logger::Info("═══════════════════════════════════════");
      
      if(m_coordinator != NULL)
      {
         int adjustedCount = m_coordinator.AdjustAllSymbols(1.0, multiplier, "Risk multiplier change");
         
         if(adjustedCount > 0)
            Logger::Info("✅ " + IntegerToString(adjustedCount) + " order(s) adjusted across all symbols");
         else
            Logger::Info("ℹ️ No orders to adjust");
      }
      
      Logger::Info("═══════════════════════════════════════");
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Update chart information using coordinator                    |
   //+------------------------------------------------------------------+
   void UpdateChartInfo()
   {
      if(m_chartManager == NULL || m_coordinator == NULL) return;
      
      m_tickCount++;
      
      // Update every 100 ticks
      if(m_tickCount % 100 != 0) return;
      
      // 🆕 Build global status using coordinator
      string globalStatus = m_coordinator.GetGlobalStatus();
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
   
   //+------------------------------------------------------------------+
   //| 🔥 OPTIMISÉ: Update detailed information using coordinator      |
   //+------------------------------------------------------------------+
   void UpdateDetailedInfo()
   {
      // ✅ OPTIMISATION: Pas de logs (appelé rarement, tous les 500 ticks)
      if(m_coordinator != NULL)
         m_coordinator.RefreshAllSwingDisplays();
      
      // Supprimer les anciens labels de symbol details s'ils existent
      if(m_chartManager != NULL)
      {
         long chartId = m_chartManager.GetChartId();
         string prefix = m_chartManager.GetLabelPrefix();
         string searchPattern = prefix + "_SymbolDetails_";
         
         int total = ObjectsTotal(chartId);
         for(int i = total - 1; i >= 0; i--)
         {
            string objName = ObjectName(chartId, i);
            if(StringFind(objName, searchPattern) == 0)
               ObjectDelete(chartId, objName);
         }
         ChartRedraw(chartId);
      }
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Print initialization summary using coordinator               |
   //+------------------------------------------------------------------+
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
      
      // 🆕 Afficher les informations du coordinateur
      if(m_coordinator != NULL)
      {
         Logger::Info("🎛️ COORDINATOR: " + m_coordinator.GetDetailedInfo());
      }
      
      Logger::Info("═══════════════════════════════════════");
   }
   
   //+------------------------------------------------------------------+
   //| Validate Trailing TP configuration (unchanged)                  |
   //+------------------------------------------------------------------+
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
   
   //+------------------------------------------------------------------+
   //| Parse symbols list (unchanged)                                  |
   //+------------------------------------------------------------------+
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
   
   //+------------------------------------------------------------------+
   //| Validate historical data (unchanged)                            |
   //+------------------------------------------------------------------+
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
   
   //+------------------------------------------------------------------+
   //| Initialize Chart Manager (unchanged)                            |
   //+------------------------------------------------------------------+
   bool InitializeChartManager()
   {
      m_chartManager = new ChartManager(0, "ForexScalpBot");
      
      if(m_chartManager != NULL)
      {
         m_chartManager.SetupChart();
         m_chartManager.ShowStrategyName(m_config.strategyName);
         PrintSymbolsInfo(m_symbols, m_config.baseMagic, m_config.timeframe, "ScalpingRobot");
         return true;
      }
      else
      {
         Logger::Warning("⚠️ Warning: Chart Manager initialization failed");
         return true; // Non-critical
      }
   }
   
   //+------------------------------------------------------------------+
   //| Initialize Time Manager (unchanged)                             |
   //+------------------------------------------------------------------+
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
   
   //+------------------------------------------------------------------+
   //| Initialize Risk Multiplier Manager (unchanged)                  |
   //+------------------------------------------------------------------+
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
   
   //+------------------------------------------------------------------+
   //| Initialize News Filter Manager (unchanged)                      |
   //+------------------------------------------------------------------+
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
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation                                             |
//+------------------------------------------------------------------+
/*
// Création du bot
BotConfig config;
// ... configuration du bot ...

ForexScalperBot* bot = new ForexScalperBot(config);

// Initialisation
if(bot.Initialize())
{
   Print("Bot initialized successfully");
   
   // Dans OnTick()
   bot.OnTick();
   
   // Accès au coordinateur pour des opérations avancées
   MultiSymbolCoordinator* coordinator = bot.GetCoordinator();
   if(coordinator != NULL)
   {
      string status = coordinator.GetGlobalStatus();
      Print("Global status: ", status);
   }
}
else
{
   Print("Bot initialization failed");
}

// Nettoyage
delete bot;
*/