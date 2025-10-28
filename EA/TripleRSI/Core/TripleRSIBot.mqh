//+------------------------------------------------------------------+
//|                                            TripleRSIBot.mqh      |
//|                                    Moteur Principal Triple RSI   |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
#include "../../Shared/Logger.mqh"
#include "../../Shared/TradingUtils.mqh"
#include "../../Shared/ChartManager.mqh"
#include "TripleRSIConfig.mqh"
#include "TripleRSITrader.mqh"

//+------------------------------------------------------------------+
//| Triple RSI Bot Class                                             |
//+------------------------------------------------------------------+
class CTripleRSIBot
{
private:
   TripleRSIConfig m_config;
   ChartManager* m_chartManager;
   CTripleRSITrader* m_symbolTraders[];
   string m_symbols[];
   int m_totalSymbols;
   
   // Statistiques globales
   int m_totalTrades;
   int m_winningTrades;
   double m_totalProfit;
   datetime m_lastUpdateTime;
   
   // Gestion des mises à jour
   int m_tickCount;
   int m_detailUpdateCount;

public:
   //--- Constructor
   CTripleRSIBot(TripleRSIConfig &config)
   {
      m_config = config;
      m_chartManager = NULL;
      m_totalSymbols = 0;
      m_totalTrades = 0;
      m_winningTrades = 0;
      m_totalProfit = 0.0;
      m_lastUpdateTime = 0;
      m_tickCount = 0;
      m_detailUpdateCount = 0;
      
      Logger::Info("TripleRSI Bot created");
   }
   
   //--- Destructor
   ~CTripleRSIBot()
   {
      // Cleanup sera fait dans Deinitialize
   }
   
   //--- Initialiser le bot
   bool Initialize()
   {
      Logger::Initialize(m_config.logLevel, "[TripleRSI] ");
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🚀 Initializing Triple RSI Strategy");
      Logger::Info("═══════════════════════════════════════");
      
      // 1. Valider la configuration
      if(!m_config.Validate())
      {
         Logger::Error("Configuration validation failed");
         return false;
      }
      
      // 2. Afficher la configuration
      m_config.PrintConfig();
      
      // 3. Parser les symboles
      if(!ParseSymbols())
      {
         Logger::Error("Failed to parse symbols");
         return false;
      }
      
      // 4. Valider les données historiques
      if(!ValidateHistoricalData())
      {
         Logger::Warning("Historical data validation failed - continuing anyway");
      }
      
      // 5. Créer les traders
      if(!CreateSymbolTraders())
      {
         Logger::Error("Failed to create symbol traders");
         return false;
      }
      
      // 6. Initialiser Chart Manager
      if(!InitializeChartManager())
      {
         Logger::Warning("Chart Manager initialization failed - continuing anyway");
      }
      
      
      // 8. Afficher le résumé d'initialisation
      PrintInitializationSummary();
      
      Logger::Success("✅ Triple RSI Bot initialization completed!");
      return true;
   }
   
   //--- Désinitialiser le bot
   void Deinitialize(const int reason)
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🛑 Triple RSI Bot stopping...");
      Logger::Info("Reason: " + IntegerToString(reason));
      Logger::Info("═══════════════════════════════════════");
      
      // Cleanup traders avec gestion d'erreur robuste
      if(ArraySize(m_symbolTraders) > 0)
      {
         int tradersCleaned = 0;
         int tradersFailed = 0;
         
         for(int i = 0; i < ArraySize(m_symbolTraders); i++)
         {
            if(m_symbolTraders[i] != NULL)
            {
               // Sauvegarder le pointeur avant suppression
               CTripleRSITrader* trader = m_symbolTraders[i];
               m_symbolTraders[i] = NULL; // Prévenir double deletion
               
               // Suppression sécurisée
               delete trader;
               
               // Vérifier si la suppression a réussi
               if(trader == NULL)
               {
                  tradersCleaned++;
               }
               else
               {
                  tradersFailed++;
                  Logger::Error("❌ Failed to delete trader at index " + IntegerToString(i));
               }
            }
         }
         
         ArrayFree(m_symbolTraders);
         
         Logger::Info("✅ Traders cleaned: " + IntegerToString(tradersCleaned));
         if(tradersFailed > 0)
         {
            Logger::Error("❌ Failed to clean traders: " + IntegerToString(tradersFailed));
         }
         else
         {
            Logger::Success("✅ Symbol Traders cleaned up");
         }
      }
      
      // Cleanup chart manager avec gestion d'erreur
      if(m_chartManager != NULL)
      {
         ChartManager* chart = m_chartManager;
         m_chartManager = NULL;
         delete chart;
         
         if(chart == NULL)
         {
            Logger::Success("✅ Chart Manager cleaned up");
         }
         else
         {
            Logger::Error("❌ Failed to clean Chart Manager");
         }
      }
      
      ArrayFree(m_symbols);
      Logger::Success("✅ All resources cleaned up successfully");
      Logger::Info("═══════════════════════════════════════");
   }
   
   //--- Fonction OnTick principale
   void OnTick()
   {
      // Vérifier que les traders sont initialisés
      if(ArraySize(m_symbolTraders) == 0)
         return;
      
      m_tickCount++;
      
      // Traiter tous les symboles
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            m_symbolTraders[i].OnTick();
         }
      }
      
      // Mettre à jour l'affichage du graphique
      UpdateChartInfo();
   }
   
   //--- Obtenir le ChartManager pour accès externe
   ChartManager* GetChartManager() const { return m_chartManager; }

private:
   //--- Parser les symboles
   bool ParseSymbols()
   {
      m_totalSymbols = ParseSymbolsList(m_config.symbolsList, m_symbols);
      
      if(m_totalSymbols <= 0)
      {
         Logger::Error("No valid symbols found in list: " + m_config.symbolsList);
         return false;
      }
      
      Logger::Info("📊 Trading " + IntegerToString(m_totalSymbols) + " symbols:");
      for(int i = 0; i < m_totalSymbols; i++)
      {
         Logger::Info("  [" + IntegerToString(i+1) + "] " + m_symbols[i]);
      }
      
      return true;
   }
   
   //--- Valider les données historiques
   bool ValidateHistoricalData()
   {
      bool allValid = true;
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(!CheckHistoricalData(m_symbols[i], m_config.timeframe))
         {
            Logger::Warning("⚠️ Limited historical data for " + m_symbols[i]);
            allValid = false;
         }
      }
      
      return allValid;
   }
   
   //--- Créer les traders pour chaque symbole
   bool CreateSymbolTraders()
   {
      ArrayResize(m_symbolTraders, m_totalSymbols);
      
      // Afficher le mapping des magic numbers
      PrintMagicNumberMapping();
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         // Générer un magic number unique par symbole
         int symbolMagic = m_config.baseMagic + i;
         
         Logger::Info("✅ Creating trader for " + m_symbols[i] + " with magic " + IntegerToString(symbolMagic));
         
         m_symbolTraders[i] = new CTripleRSITrader(
            m_symbols[i], symbolMagic, m_config.timeframe,
            m_config.riskPercent, m_config.tpRatio,
            m_config.useDynamicTrailing,
            m_config.rsiPeriod1, m_config.rsiPeriod2, m_config.rsiPeriod3,
            m_config.rsiOversold, m_config.rsiOverbought,
            m_config.useStrictAlignment,
            m_config.useAlerts, m_config.sendNotifications
         );
         
         if(m_symbolTraders[i] == NULL)
         {
            Logger::Error("❌ ERROR: Failed to create TripleRSI Trader for " + m_symbols[i]);
            return false;
         }
         
         // Initialiser la configuration
         m_symbolTraders[i].Initialize(m_config);
         
         Logger::Success("✅ TripleRSI Trader created successfully for " + m_symbols[i]);
      }
      
      return true;
   }
   
   //--- Afficher le mapping des magic numbers
   void PrintMagicNumberMapping()
   {
      Logger::Info("🔢 Magic Number Mapping:");
      for(int i = 0; i < m_totalSymbols; i++)
      {
         int symbolMagic = m_config.baseMagic + i;
         Logger::Info("  " + m_symbols[i] + " → Magic " + IntegerToString(symbolMagic));
      }
   }
   
   //--- Initialiser Chart Manager
   bool InitializeChartManager()
   {
      m_chartManager = new ChartManager(0, "TripleRSI");
      
      if(m_chartManager != NULL)
      {
         m_chartManager.SetupChart();
         m_chartManager.ShowStrategyName(m_config.strategyName);
         PrintSymbolsInfo();
         return true;
      }
      else
      {
         Logger::Warning("⚠️ Warning: Chart Manager initialization failed");
         return false;
      }
   }
   
   //--- Afficher les informations sur les symboles
   void PrintSymbolsInfo()
   {
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("🔧 TRIPLE RSI SYMBOLS CONFIGURATION");
      Logger::Info("═══════════════════════════════════════");
      Logger::Info("Total symbols: " + IntegerToString(m_totalSymbols));
      Logger::Info("Strategy: " + m_config.strategyName);
      Logger::Info("Timeframe: " + EnumToString(m_config.timeframe));
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         string symbol = m_symbols[i];
         
         // Informations sur le symbole
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
         double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
         double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
         
         Logger::Info("  [" + IntegerToString(i+1) + "] " + symbol + 
                      " | Magic: " + IntegerToString(m_config.baseMagic + i));
         Logger::Info("      Point: " + DoubleToString(point, 5) + 
                      " | Spread: " + DoubleToString(spread, 0));
         Logger::Info("      Lots: " + DoubleToString(minLot, 2) + 
                      " - " + DoubleToString(maxLot, 2));
      }
      
      Logger::Info("═══════════════════════════════════════");
   }
   
   
   //--- Afficher le résumé d'initialisation
   void PrintInitializationSummary()
   {
      Logger::Success("✅ Initialization completed successfully!");
      Logger::Info("📈 Trading " + IntegerToString(m_totalSymbols) + " symbols simultaneously");
      Logger::Info("🕒 Timeframe: " + EnumToString(m_config.timeframe));
      Logger::Info("💰 Risk per trade: " + DoubleToString(m_config.riskPercent, 1) + "%");
      Logger::Info("🎯 TP Ratio: " + DoubleToString(m_config.tpRatio, 1) + "x");
      
      if(m_config.useDynamicTrailing)
      {
         Logger::Info("🔄 TRAILING STOP: ON (Dynamic TSL only)");
         Logger::Info("   Mode: Dynamic TSL with cost-based trigger");
      }
      else
      {
         Logger::Info("🔄 TRAILING STOP: OFF");
      }
      
      Logger::Info("📊 RSI Configuration:");
      Logger::Info("   Periods: " + IntegerToString(m_config.rsiPeriod1) + "/" + 
                   IntegerToString(m_config.rsiPeriod2) + "/" + IntegerToString(m_config.rsiPeriod3));
      Logger::Info("   Levels: " + IntegerToString(m_config.rsiOversold) + "/" + 
                   IntegerToString(m_config.rsiOverbought));
      
      Logger::Info("═══════════════════════════════════════");
   }
   
   //--- Mettre à jour les informations du graphique
   void UpdateChartInfo()
   {
      if(m_chartManager == NULL || ArraySize(m_symbolTraders) == 0) 
         return;
      
      // Mettre à jour toutes les 100 ticks
      if(m_tickCount % 100 != 0) 
         return;
      
      // Construire le statut global
      string globalStatus = GetGlobalStatus();
      
      // Déterminer la couleur du statut
      color statusColor = DetermineStatusColor();
      
      // Mettre à jour le label principal
      m_chartManager.UpdateLabelText("TopRight", globalStatus);
      m_chartManager.UpdateLabelColor("TopRight", statusColor);
      
      // Mettre à jour les détails toutes les 500 ticks
      m_detailUpdateCount++;
      if(m_detailUpdateCount % 500 == 0)
      {
         UpdateDetailedInfo();
      }
   }
   
   //--- Obtenir le statut global
   string GetGlobalStatus()
   {
      int activeSymbols = 0;
      int totalPositions = 0;
      double totalProfit = 0.0;
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            if(m_symbolTraders[i].HasPosition())
            {
               activeSymbols++;
               totalPositions++;
               
               double entryPrice, slPrice, tpPrice, profit;
               ENUM_POSITION_TYPE type;
               if(m_symbolTraders[i].GetCurrentPosition(entryPrice, slPrice, tpPrice, profit, type))
               {
                  totalProfit += profit;
               }
            }
         }
      }
      
      string status = "TRIPLE RSI: ";
      status += "Symbols: " + IntegerToString(activeSymbols) + "/" + IntegerToString(m_totalSymbols);
      status += " | Positions: " + IntegerToString(totalPositions);
      
      if(totalProfit != 0)
      {
         status += " | P&L: " + DoubleToString(totalProfit, 2);
      }
      
      return status;
   }
   
   //--- Déterminer la couleur du statut
   color DetermineStatusColor()
   {
      int activePositions = 0;
      double totalProfit = 0.0;
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL && m_symbolTraders[i].HasPosition())
         {
            activePositions++;
            double entryPrice, slPrice, tpPrice, profit;
            ENUM_POSITION_TYPE type;
            if(m_symbolTraders[i].GetCurrentPosition(entryPrice, slPrice, tpPrice, profit, type))
            {
               totalProfit += profit;
            }
         }
      }
      
      if(activePositions == 0)
         return clrGray;
      else if(totalProfit > 0)
         return clrLime;
      else if(totalProfit < 0)
         return clrRed;
      else
         return clrYellow;
   }
   
   //--- Mettre à jour les informations détaillées
   void UpdateDetailedInfo()
   {
      // Cette fonction peut être étendue pour afficher des informations détaillées
      // sur chaque symbole, les statistiques, etc.
      Logger::Debug("Detailed info update - " + IntegerToString(m_totalSymbols) + " symbols");
   }
   
public:
   //--- Obtenir les statistiques globales
   string GetGlobalStatistics()
   {
      int totalTrades = 0;
      int winningTrades = 0;
      double totalProfit = 0.0;
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbolTraders[i] != NULL)
         {
            totalTrades += m_symbolTraders[i].GetTotalTrades();
            totalProfit += m_symbolTraders[i].GetTotalProfit();
            
            double winRate = m_symbolTraders[i].GetWinRate();
            if(winRate > 0)
               winningTrades += (int)(m_symbolTraders[i].GetTotalTrades() * winRate / 100.0);
         }
      }
      
      string stats = "=== GLOBAL STATISTICS ===\n";
      stats += "Total Trades: " + IntegerToString(totalTrades) + "\n";
      stats += "Winning Trades: " + IntegerToString(winningTrades) + "\n";
      if(totalTrades > 0)
         stats += "Win Rate: " + DoubleToString((double)winningTrades / totalTrades * 100.0, 1) + "%\n";
      stats += "Total Profit: " + DoubleToString(totalProfit, 2) + "\n";
      stats += "========================";
      
      return stats;
   }
   
   //--- Obtenir le nombre total de symboles
   int GetTotalSymbols() const { return m_totalSymbols; }
   
   //--- Obtenir le symbole à l'index donné
   string GetSymbol(int index) const 
   { 
      if(index >= 0 && index < m_totalSymbols)
         return m_symbols[index];
      return "";
   }
   
   //--- Obtenir le trader à l'index donné
   CTripleRSITrader* GetTrader(int index) const 
   { 
      if(index >= 0 && index < ArraySize(m_symbolTraders))
         return m_symbolTraders[index];
      return NULL;
   }
};
