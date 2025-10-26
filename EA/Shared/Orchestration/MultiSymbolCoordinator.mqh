//+------------------------------------------------------------------+
//|                                    MultiSymbolCoordinator.mqh     |
//|                    Coordinateur multi-symboles                    |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../Core/VolumeManager.mqh"
#include "../Core/TradingValidator.mqh"
#include "../Core/PositionManager.mqh"
#include "../Core/PendingOrderManager.mqh"
#include "../Orchestration/DynamicAdjustmentManager.mqh"
#include "../../ScalpingFx/common/ForexSymbolTrader.mqh"
#include "../Logger.mqh"

//+------------------------------------------------------------------+
//| Structure pour stocker les informations d'un symbole             |
//+------------------------------------------------------------------+
struct SymbolInfo
{
   string symbol;
   int magicNumber;
   ENUM_TIMEFRAMES timeframe;
   double riskPercent;
   VolumeManager* volumeManager;
   TradingValidator* validator;
   PositionManager* positionManager;
   PendingOrderManager* orderManager;
   DynamicAdjustmentManager* adjustmentManager;
   CTrade* trade;
   ForexSymbolTrader* trader;  // 🆕 Le trader principal
};

//+------------------------------------------------------------------+
//| Classe MultiSymbolCoordinator - Orchestration multi-symboles     |
//+------------------------------------------------------------------+
class MultiSymbolCoordinator
{
private:
   SymbolInfo        m_symbols[];           // Tableau des symboles gérés
   int               m_totalSymbols;        // Nombre total de symboles
   int               m_baseMagic;           // Magic number de base
   
   // Statistiques globales
   int               m_totalPositions;      // Total des positions
   int               m_totalOrders;         // Total des ordres
   double            m_totalProfit;         // Profit total
   int               m_activeSymbols;       // Nombre de symboles actifs
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   MultiSymbolCoordinator(int baseMagic)
   {
      m_baseMagic = baseMagic;
      m_totalSymbols = 0;
      m_totalPositions = 0;
      m_totalOrders = 0;
      m_totalProfit = 0;
      m_activeSymbols = 0;
      
      ArrayResize(m_symbols, 0);
      
      Logger::Info("MultiSymbolCoordinator initialized with base magic: " + IntegerToString(baseMagic));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~MultiSymbolCoordinator()
   {
      // Nettoyer tous les symboles
      for(int i = 0; i < m_totalSymbols; i++)
      {
         CleanupSymbol(i);
      }
      
      ArrayFree(m_symbols);
      Logger::Info("MultiSymbolCoordinator destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Ajouter un symbole au coordinateur                              |
   //+------------------------------------------------------------------+
   bool AddSymbol(string symbol, ENUM_TIMEFRAMES timeframe, double riskPercent,
                 int tpPoints, int slPoints, int expirationBars, int slippagePoints, string comment,
                 ENUM_STRATEGY_MODE strategyMode = STRATEGY_BREAKOUT, bool useTrailingTP = false,
                 ENUM_TRAILING_TP_MODE trailingTPMode = TRAILING_TP_STEPPED, string customTPLevels = "",
                 int tslTriggerPoints = 25, int tslPoints = 20, int barsN = 20, int orderDistPoints = 5,
                 int entryOffsetPoints = 2, bool useDynamicTSLTrigger = true, double tslCostMultiplier = 1.5,
                 int tslMinTriggerPoints = 50)
   {
      // Vérifier si le symbole existe déjà
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].symbol == symbol)
         {
            Logger::Warning("Symbol " + symbol + " already exists in coordinator");
            return false;
         }
      }
      
      // Générer un magic number unique
      int symbolMagic = GenerateSymbolMagicNumber(m_baseMagic, symbol, timeframe);
      
      // Redimensionner le tableau
      ArrayResize(m_symbols, m_totalSymbols + 1);
      int index = m_totalSymbols;
      
      // Initialiser les informations du symbole
      m_symbols[index].symbol = symbol;
      m_symbols[index].magicNumber = symbolMagic;
      m_symbols[index].timeframe = timeframe;
      m_symbols[index].riskPercent = riskPercent;
      
      // Créer les managers pour ce symbole
      if(!CreateManagersForSymbol(index, tpPoints, slPoints, expirationBars, slippagePoints, comment,
                                  strategyMode, useTrailingTP, trailingTPMode, customTPLevels,
                                  tslTriggerPoints, tslPoints, barsN, orderDistPoints, entryOffsetPoints,
                                  useDynamicTSLTrigger, tslCostMultiplier, tslMinTriggerPoints))
      {
         Logger::Error("Failed to create managers for symbol " + symbol);
         ArrayResize(m_symbols, m_totalSymbols); // Annuler l'ajout
         return false;
      }
      
      m_totalSymbols++;
      
      Logger::Info("Symbol " + symbol + " added to coordinator | Magic: " + IntegerToString(symbolMagic));
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer un symbole du coordinateur                            |
   //+------------------------------------------------------------------+
   bool RemoveSymbol(string symbol)
   {
      int index = FindSymbolIndex(symbol);
      if(index < 0)
      {
         Logger::Warning("Symbol " + symbol + " not found in coordinator");
         return false;
      }
      
      // Nettoyer le symbole
      CleanupSymbol(index);
      
      // Décaler les éléments du tableau
      for(int i = index; i < m_totalSymbols - 1; i++)
      {
         m_symbols[i] = m_symbols[i + 1];
      }
      
      m_totalSymbols--;
      ArrayResize(m_symbols, m_totalSymbols);
      
      Logger::Info("Symbol " + symbol + " removed from coordinator");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| 🔥 OPTIMISÉ: Traitement principal du tick pour tous les symboles |
   //| Version ultra-rapide identique à l'ancienne version              |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // ✅ OPTIMISATION: Pas de logs, juste le traitement
      // Traiter chaque symbole individuellement (comportement identique à l'ancienne version)
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].trader != NULL)
            m_symbols[i].trader.OnTick();
      }
      
      // Mettre à jour les statistiques globales
      UpdateGlobalStatistics();
   }
   
   //+------------------------------------------------------------------+
   //| 🔥 OPTIMISÉ: Gérer les positions ouvertes                       |
   //| Appelée À CHAQUE TICK, même quand le trading est bloqué         |
   //+------------------------------------------------------------------+
   void ManageOpenPositions()
   {
      // ✅ OPTIMISATION: Pas de logs, juste le traitement
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].trader != NULL)
         {
            // ✅ ORDRE CRITIQUE: TrailStop AVANT ApplyTrailingTP
            m_symbols[i].trader.TrailStop();
            m_symbols[i].trader.ApplyTrailingTP();
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les statistiques globales                         |
   //+------------------------------------------------------------------+
   void UpdateGlobalStatistics()
   {
      m_totalPositions = 0;
      m_totalOrders = 0;
      m_totalProfit = 0;
      m_activeSymbols = 0;
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].positionManager != NULL)
         {
            m_symbols[i].positionManager.UpdateCounters();
            int positions = m_symbols[i].positionManager.GetTotalPositions();
            double profit = m_symbols[i].positionManager.GetTotalPnL();
            
            m_totalPositions += positions;
            m_totalProfit += profit;
            
            if(positions > 0) m_activeSymbols++;
         }
         
         if(m_symbols[i].orderManager != NULL)
         {
            m_symbols[i].orderManager.UpdateCounters();
            int orders = m_symbols[i].orderManager.GetTotalOrders();
            m_totalOrders += orders;
            
            if(orders > 0) m_activeSymbols++;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Ajuster tous les symboles avec un multiplicateur                |
   //+------------------------------------------------------------------+
   int AdjustAllSymbols(double oldMultiplier, double newMultiplier, string description = "")
   {
      int totalAdjusted = 0;
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].adjustmentManager != NULL)
         {
            int adjusted = m_symbols[i].adjustmentManager.AdjustOrderVolumes(oldMultiplier, newMultiplier, description);
            totalAdjusted += adjusted;
         }
      }
      
      Logger::Info("Global adjustment completed: " + IntegerToString(totalAdjusted) + 
                  " order(s) adjusted across " + IntegerToString(m_totalSymbols) + " symbol(s)");
      
      return totalAdjusted;
   }
   
   //+------------------------------------------------------------------+
   //| 🔥 OPTIMISÉ: Annuler tous les ordres pending                    |
   //+------------------------------------------------------------------+
   int CancelAllPendingOrders()
   {
      int totalCancelled = 0;
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].orderManager != NULL)
         {
            int cancelled = m_symbols[i].orderManager.DeleteAllOrders();
            totalCancelled += cancelled;
         }
      }
      
      // ✅ OPTIMISATION: Log seulement si des ordres ont été annulés
      if(totalCancelled > 0)
      {
         Logger::Info("Global cancellation: " + IntegerToString(totalCancelled) + " order(s) cancelled");
      }
      
      return totalCancelled;
   }
   
   //+------------------------------------------------------------------+
   //| Fermer toutes les positions                                     |
   //+------------------------------------------------------------------+
   int CloseAllPositions()
   {
      int totalClosed = 0;
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].adjustmentManager != NULL)
         {
            int closed = m_symbols[i].adjustmentManager.CloseAllPositions();
            totalClosed += closed;
         }
      }
      
      Logger::Info("Global closing completed: " + IntegerToString(totalClosed) + 
                  " position(s) closed across " + IntegerToString(m_totalSymbols) + " symbol(s)");
      
      return totalClosed;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations d'un symbole spécifique                |
   //+------------------------------------------------------------------+
   string GetSymbolStatus(string symbol)
   {
      int index = FindSymbolIndex(symbol);
      if(index < 0)
         return "Symbol " + symbol + " not found";
      
      string status = symbol + ": ";
      
      if(m_symbols[index].positionManager != NULL)
      {
         status += m_symbols[index].positionManager.GetStatusInfo();
      }
      
      if(m_symbols[index].orderManager != NULL)
      {
         status += " | " + m_symbols[index].orderManager.GetStatusInfo();
      }
      
      return status;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le statut global                                        |
   //+------------------------------------------------------------------+
   string GetGlobalStatus()
   {
      UpdateGlobalStatistics();
      
      string status = "GLOBAL: ";
      status += "Symbols: " + IntegerToString(m_activeSymbols) + "/" + IntegerToString(m_totalSymbols);
      status += " | Positions: " + IntegerToString(m_totalPositions);
      status += " | Orders: " + IntegerToString(m_totalOrders);
      
      if(m_totalProfit != 0)
      {
         status += " | P/L: " + DoubleToString(m_totalProfit, 2);
      }
      
      return status;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo()
   {
      UpdateGlobalStatistics();
      
      string info = "MultiSymbolCoordinator Details:\n";
      info += "  Total Symbols: " + IntegerToString(m_totalSymbols) + "\n";
      info += "  Active Symbols: " + IntegerToString(m_activeSymbols) + "\n";
      info += "  Total Positions: " + IntegerToString(m_totalPositions) + "\n";
      info += "  Total Orders: " + IntegerToString(m_totalOrders) + "\n";
      info += "  Total P&L: " + DoubleToString(m_totalProfit, 2) + "\n\n";
      
      for(int i = 0; i < m_totalSymbols; i++)
      {
         info += "  [" + IntegerToString(i + 1) + "] " + m_symbols[i].symbol + 
                " | Magic: " + IntegerToString(m_symbols[i].magicNumber) + 
                " | Risk: " + DoubleToString(m_symbols[i].riskPercent, 2) + "%\n";
      }
      
      return info;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total de symboles                             |
   //+------------------------------------------------------------------+
   int GetTotalSymbols() const { return m_totalSymbols; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de symboles actifs                            |
   //+------------------------------------------------------------------+
   int GetActiveSymbols() const { return m_activeSymbols; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le profit total                                         |
   //+------------------------------------------------------------------+
   double GetTotalProfit() const { return m_totalProfit; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total de positions                            |
   //+------------------------------------------------------------------+
   int GetTotalPositions() const { return m_totalPositions; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total d'ordres                                |
   //+------------------------------------------------------------------+
   int GetTotalOrders() const { return m_totalOrders; }
   
   //+------------------------------------------------------------------+
   //| 🔥 OPTIMISÉ: Définir le multiplicateur de risque global         |
   //| Appelée À CHAQUE TICK, doit être ultra-rapide                   |
   //+------------------------------------------------------------------+
   void SetGlobalRiskMultiplier(double multiplier)
   {
      // ✅ OPTIMISATION: Pas de logs, juste le traitement
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].trader != NULL)
            m_symbols[i].trader.SetRiskMultiplier(multiplier);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les managers d'un symbole                               |
   //+------------------------------------------------------------------+
   bool GetSymbolManagers(string symbol, PositionManager* &positionManager, PendingOrderManager* &orderManager)
   {
      int index = FindSymbolIndex(symbol);
      if(index < 0)
         return false;
      
      positionManager = m_symbols[index].positionManager;
      orderManager = m_symbols[index].orderManager;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| 🔥 NOUVEAU: Obtenir le trader d'un symbole pour validation      |
   //+------------------------------------------------------------------+
   ForexSymbolTrader* GetSymbolTrader(string symbol)
   {
      int index = FindSymbolIndex(symbol);
      if(index < 0)
         return NULL;
      
      return m_symbols[index].trader;
   }
   
   //+------------------------------------------------------------------+
   //| 🔥 NOUVEAU: Valider tous les managers d'un symbole              |
   //+------------------------------------------------------------------+
   bool ValidateSymbolManagers(string symbol, string &errorMessage)
   {
      errorMessage = "";
      int index = FindSymbolIndex(symbol);
      
      if(index < 0)
      {
         errorMessage = "Symbol " + symbol + " not found in coordinator";
         return false;
      }
      
      // Vérifier le trader
      if(m_symbols[index].trader == NULL)
      {
         errorMessage = "Trader is NULL for " + symbol;
         return false;
      }
      
      // Vérifier VolumeManager
      if(m_symbols[index].volumeManager == NULL)
      {
         errorMessage = "VolumeManager is NULL for " + symbol;
         return false;
      }
      
      // Vérifier TradingValidator
      if(m_symbols[index].validator == NULL)
      {
         errorMessage = "TradingValidator is NULL for " + symbol;
         return false;
      }
      
      // Vérifier PositionManager
      if(m_symbols[index].positionManager == NULL)
      {
         errorMessage = "PositionManager is NULL for " + symbol;
         return false;
      }
      
      // Vérifier PendingOrderManager
      if(m_symbols[index].orderManager == NULL)
      {
         errorMessage = "PendingOrderManager is NULL for " + symbol;
         return false;
      }
      
      // Vérifier DynamicAdjustmentManager
      if(m_symbols[index].adjustmentManager == NULL)
      {
         errorMessage = "DynamicAdjustmentManager is NULL for " + symbol;
         return false;
      }
      
      // Vérifier CTrade
      if(m_symbols[index].trade == NULL)
      {
         errorMessage = "CTrade is NULL for " + symbol;
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| 🔥 OPTIMISÉ: Rafraîchir l'affichage des swing points           |
   //+------------------------------------------------------------------+
   void RefreshAllSwingDisplays()
   {
      // ✅ OPTIMISATION: Pas de logs d'erreur (appelé rarement, tous les 500 ticks)
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].trader != NULL)
            m_symbols[i].trader.RefreshSwingDisplay();
      }
   }
   
private:
   //+------------------------------------------------------------------+
   //| Créer les managers pour un symbole                              |
   //+------------------------------------------------------------------+
   bool CreateManagersForSymbol(int index, int tpPoints, int slPoints, int expirationBars, int slippagePoints, string comment,
                                ENUM_STRATEGY_MODE strategyMode, bool useTrailingTP, ENUM_TRAILING_TP_MODE trailingTPMode, 
                                string customTPLevels, int tslTriggerPoints, int tslPoints, int barsN, int orderDistPoints,
                                int entryOffsetPoints, bool useDynamicTSLTrigger, double tslCostMultiplier, int tslMinTriggerPoints)
   {
      string symbol = m_symbols[index].symbol;
      int magicNumber = m_symbols[index].magicNumber;
      
      // Créer l'objet de trading
      m_symbols[index].trade = new CTrade();
      if(m_symbols[index].trade == NULL)
      {
         Logger::Error("Failed to create CTrade for " + symbol);
         return false;
      }
      
      m_symbols[index].trade.SetExpertMagicNumber(magicNumber);
      m_symbols[index].trade.SetDeviationInPoints(slippagePoints);
      m_symbols[index].trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_symbols[index].trade.SetAsyncMode(false);
      
      // Créer le VolumeManager
      m_symbols[index].volumeManager = new VolumeManager(symbol);
      if(m_symbols[index].volumeManager == NULL)
      {
         Logger::Error("Failed to create VolumeManager for " + symbol);
         return false;
      }
      
      // Créer le TradingValidator
      m_symbols[index].validator = new TradingValidator(symbol, 10, 1000, slippagePoints);
      if(m_symbols[index].validator == NULL)
      {
         Logger::Error("Failed to create TradingValidator for " + symbol);
         return false;
      }
      
      // Créer le PositionManager
      m_symbols[index].positionManager = new PositionManager(symbol, magicNumber, m_symbols[index].trade);
      if(m_symbols[index].positionManager == NULL)
      {
         Logger::Error("Failed to create PositionManager for " + symbol);
         return false;
      }
      
      // Créer le PendingOrderManager
      m_symbols[index].orderManager = new PendingOrderManager(symbol, magicNumber, m_symbols[index].trade, 
                                                             m_symbols[index].volumeManager, m_symbols[index].validator,
                                                             expirationBars, m_symbols[index].timeframe, slippagePoints, comment);
      if(m_symbols[index].orderManager == NULL)
      {
         Logger::Error("Failed to create PendingOrderManager for " + symbol);
         return false;
      }
      
      // Créer le DynamicAdjustmentManager
      m_symbols[index].adjustmentManager = new DynamicAdjustmentManager(symbol, magicNumber, 
                                                                       m_symbols[index].positionManager,
                                                                       m_symbols[index].orderManager,
                                                                       m_symbols[index].volumeManager);
      if(m_symbols[index].adjustmentManager == NULL)
      {
         Logger::Error("Failed to create DynamicAdjustmentManager for " + symbol);
         return false;
      }
      
      // 🆕 Créer le ForexSymbolTrader
      m_symbols[index].trader = new ForexSymbolTrader(
         symbol,
         magicNumber,
         m_symbols[index].timeframe,
         m_symbols[index].riskPercent,
         tpPoints,
         slPoints,
         tslTriggerPoints,
         tslPoints,
         barsN,
         expirationBars,
         orderDistPoints,
         slippagePoints,
         entryOffsetPoints,
         comment,
         strategyMode,
         useTrailingTP,
         trailingTPMode,
         customTPLevels,
         useDynamicTSLTrigger,
         tslCostMultiplier,
         tslMinTriggerPoints
      );
      
      if(m_symbols[index].trader == NULL)
      {
         Logger::Error("Failed to create ForexSymbolTrader for " + symbol);
         return false;
      }
      
      // 🆕 Injecter les managers dans le trader
      m_symbols[index].trader.SetVolumeManager(m_symbols[index].volumeManager);
      m_symbols[index].trader.SetValidator(m_symbols[index].validator);
      m_symbols[index].trader.SetPositionManager(m_symbols[index].positionManager);
      m_symbols[index].trader.SetOrderManager(m_symbols[index].orderManager);
      m_symbols[index].trader.SetAdjustmentManager(m_symbols[index].adjustmentManager);
      
      Logger::Info("All managers and trader created successfully for " + symbol);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Nettoyer un symbole                                             |
   //+------------------------------------------------------------------+
   void CleanupSymbol(int index)
   {
      if(m_symbols[index].adjustmentManager != NULL)
      {
         delete m_symbols[index].adjustmentManager;
         m_symbols[index].adjustmentManager = NULL;
      }
      
      if(m_symbols[index].orderManager != NULL)
      {
         delete m_symbols[index].orderManager;
         m_symbols[index].orderManager = NULL;
      }
      
      if(m_symbols[index].positionManager != NULL)
      {
         delete m_symbols[index].positionManager;
         m_symbols[index].positionManager = NULL;
      }
      
      if(m_symbols[index].validator != NULL)
      {
         delete m_symbols[index].validator;
         m_symbols[index].validator = NULL;
      }
      
      if(m_symbols[index].volumeManager != NULL)
      {
         delete m_symbols[index].volumeManager;
         m_symbols[index].volumeManager = NULL;
      }
      
      if(m_symbols[index].trade != NULL)
      {
         delete m_symbols[index].trade;
         m_symbols[index].trade = NULL;
      }
      
      // 🆕 Nettoyer le trader
      if(m_symbols[index].trader != NULL)
      {
         delete m_symbols[index].trader;
         m_symbols[index].trader = NULL;
      }
      
      Logger::Info("Cleanup completed for " + m_symbols[index].symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Trouver l'index d'un symbole                                    |
   //+------------------------------------------------------------------+
   int FindSymbolIndex(string symbol)
   {
      for(int i = 0; i < m_totalSymbols; i++)
      {
         if(m_symbols[i].symbol == symbol)
            return i;
      }
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Générer un magic number unique pour un symbole                  |
   //+------------------------------------------------------------------+
   int GenerateSymbolMagicNumber(int baseMagic, string symbol, ENUM_TIMEFRAMES timeframe)
   {
      // Utiliser une fonction de hash simple pour générer un magic number unique
      int hash = 0;
      for(int i = 0; i < StringLen(symbol); i++)
      {
         hash = hash * 31 + StringGetCharacter(symbol, i);
      }
      
      // Ajouter le timeframe
      hash += (int)timeframe * 1000;
      
      // S'assurer que le magic number est positif et unique
      int magicNumber = baseMagic + (MathAbs(hash) % 10000);
      
      return magicNumber;
   }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation                                             |
//+------------------------------------------------------------------+
/*
// Création du coordinateur
MultiSymbolCoordinator* coordinator = new MultiSymbolCoordinator(12345);

// Ajouter des symboles
coordinator.AddSymbol("EURUSD", PERIOD_M15, 2.0, 100, 50, 10, 3, "MyEA");
coordinator.AddSymbol("GBPUSD", PERIOD_M15, 2.0, 100, 50, 10, 3, "MyEA");
coordinator.AddSymbol("USDJPY", PERIOD_M15, 2.0, 100, 50, 10, 3, "MyEA");

// Mettre à jour les statistiques
coordinator.UpdateGlobalStatistics();

// Ajuster tous les symboles
int adjusted = coordinator.AdjustAllSymbols(1.0, 2.0, "Risk increase");

// Annuler tous les ordres
int cancelled = coordinator.CancelAllPendingOrders();

// Fermer toutes les positions
int closed = coordinator.CloseAllPositions();

// Obtenir les informations
string globalStatus = coordinator.GetGlobalStatus();
string detailedInfo = coordinator.GetDetailedInfo();

// Obtenir les managers d'un symbole spécifique
PositionManager* posMgr;
PendingOrderManager* orderMgr;
if(coordinator.GetSymbolManagers("EURUSD", posMgr, orderMgr))
{
   // Utiliser les managers
}

// Supprimer un symbole
coordinator.RemoveSymbol("USDJPY");

// Nettoyage
delete coordinator;
*/
