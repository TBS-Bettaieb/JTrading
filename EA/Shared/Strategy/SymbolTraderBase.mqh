//+------------------------------------------------------------------+
//|                                          SymbolTraderBase.mqh     |
//|                    Classe abstraite de base pour les traders      |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../Core/VolumeManager.mqh"
#include "../Core/TradingValidator.mqh"
#include "../Core/PositionManager.mqh"
#include "../Core/PendingOrderManager.mqh"
#include "../Orchestration/DynamicAdjustmentManager.mqh"
#include "../Logger.mqh"

//+------------------------------------------------------------------+
//| Classe abstraite SymbolTraderBase - Base pour les traders        |
//+------------------------------------------------------------------+
class SymbolTraderBase
{
protected:
   // Données du symbole
   string            m_symbol;              // Nom du symbole
   int               m_magicNumber;         // Magic number unique
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe utilisé
   double            m_point;               // Point du symbole
   
   // Managers injectés
   VolumeManager*    m_volumeManager;       // Gestionnaire de volume
   TradingValidator* m_validator;           // Validateur de trading
   PositionManager*  m_positionManager;     // Gestionnaire de positions
   PendingOrderManager* m_orderManager;     // Gestionnaire d'ordres
   DynamicAdjustmentManager* m_adjustmentManager; // Gestionnaire d'ajustement
   
   // Paramètres de trading
   double            m_riskPercent;         // Risque par symbole
   int               m_tpPoints;            // Take Profit en points
   int               m_slPoints;            // Stop Loss en points
   string            m_tradeComment;        // Commentaire des trades
   
   // Gestion des barres
   datetime          m_lastBarTime;         // Dernière barre traitée
   
   // Multiplicateur de risque
   double            m_currentRiskMultiplier; // Multiplicateur de risque actuel
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   SymbolTraderBase(string symbol, int magicNumber, ENUM_TIMEFRAMES timeframe,
                   double riskPercent, int tpPoints, int slPoints, string tradeComment)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      m_riskPercent = riskPercent;
      m_tpPoints = tpPoints;
      m_slPoints = slPoints;
      m_tradeComment = tradeComment;
      
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_lastBarTime = iTime(symbol, timeframe, 0);
      m_currentRiskMultiplier = 1.0;
      
      // Les managers seront injectés par les classes dérivées
      m_volumeManager = NULL;
      m_validator = NULL;
      m_positionManager = NULL;
      m_orderManager = NULL;
      m_adjustmentManager = NULL;
      
      Logger::Debug("SymbolTraderBase initialized for " + symbol + " | Magic: " + IntegerToString(magicNumber));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor virtuel                                               |
   //+------------------------------------------------------------------+
   virtual ~SymbolTraderBase()
   {
      Logger::Debug("SymbolTraderBase destroyed for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Méthodes virtuelles pures à implémenter par les classes dérivées |
   //+------------------------------------------------------------------+
   virtual void OnTick() = 0;                    // Traitement principal du tick
   virtual void OnNewBar() = 0;                  // Traitement d'une nouvelle barre
   virtual bool HasTradingSignal() = 0;          // Vérifier s'il y a un signal de trading
   virtual void ProcessTradingSignal() = 0;      // Traiter le signal de trading
   
   //+------------------------------------------------------------------+
   //| Méthodes communes à toutes les classes dérivées                  |
   //+------------------------------------------------------------------+
   
   //+------------------------------------------------------------------+
   //| Vérifier si c'est une nouvelle barre                            |
   //+------------------------------------------------------------------+
   bool IsNewBar()
   {
      datetime currentTime = iTime(m_symbol, m_timeframe, 0);
      
      if(m_lastBarTime != currentTime)
      {
         m_lastBarTime = currentTime;
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les compteurs                                      |
   //+------------------------------------------------------------------+
   void UpdateCounters()
   {
      if(m_positionManager != NULL)
         m_positionManager.UpdateCounters();
      
      if(m_orderManager != NULL)
         m_orderManager.UpdateCounters();
   }
   
   //+------------------------------------------------------------------+
   //| Fermer toutes les positions et ordres                           |
   //+------------------------------------------------------------------+
   void CloseAllOrders()
   {
      if(m_positionManager != NULL)
         m_positionManager.CloseAllPositions();
      
      if(m_orderManager != NULL)
         m_orderManager.DeleteAllOrders();
   }
   
   //+------------------------------------------------------------------+
   //| Annuler tous les ordres pending                                 |
   //+------------------------------------------------------------------+
   void CancelAllPendingOrders()
   {
      if(m_orderManager != NULL)
         m_orderManager.DeleteAllOrders();
   }
   
   //+------------------------------------------------------------------+
   //| 🚫 MÉTHODE DÉSACTIVÉE - Causait des duplications d'ordres       |
   //| Le multiplicateur affecte uniquement les NOUVEAUX ordres        |
   //+------------------------------------------------------------------+
   int AdjustPositionSizes(double newMultiplier)
   {
      // MÉTHODE DÉSACTIVÉE - Causait des duplications d'ordres
      // Le multiplicateur affecte uniquement les NOUVEAUX ordres
      // Les positions existantes gardent leur volume original
      return 0;
   }
   
   //+------------------------------------------------------------------+
   //| Définir le multiplicateur de risque                             |
   //+------------------------------------------------------------------+
   void SetRiskMultiplier(double multiplier)
   {
      m_currentRiskMultiplier = MathMax(0.1, MathMin(10.0, multiplier));
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le multiplicateur de risque                             |
   //+------------------------------------------------------------------+
   double GetRiskMultiplier() const { return m_currentRiskMultiplier; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le profit total                                         |
   //+------------------------------------------------------------------+
   double GetTotalProfit()
   {
      if(m_positionManager == NULL)
         return 0;
      
      return m_positionManager.GetTotalPnL();
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total de positions                            |
   //+------------------------------------------------------------------+
   int GetTotalPositions()
   {
      if(m_positionManager == NULL)
         return 0;
      
      return m_positionManager.GetTotalPositions();
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total d'ordres                                |
   //+------------------------------------------------------------------+
   int GetTotalOrders()
   {
      if(m_orderManager == NULL)
         return 0;
      
      return m_orderManager.GetTotalOrders();
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut                              |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string status = m_symbol + ": ";
      
      int totalPositions = GetTotalPositions();
      int totalOrders = GetTotalOrders();
      
      if(totalPositions + totalOrders == 0)
         status += "IDLE";
      else
      {
         status += "ACTIVE | Pos: " + IntegerToString(totalPositions) + " | Orders: " + IntegerToString(totalOrders);
         
         double profit = GetTotalProfit();
         if(profit != 0)
         {
            status += " | P/L: " + DoubleToString(profit, 2);
         }
      }
      
      return status;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo()
   {
      string info = "SymbolTraderBase for " + m_symbol + ":\n";
      info += "  Magic Number: " + IntegerToString(m_magicNumber) + "\n";
      info += "  Timeframe: " + EnumToString(m_timeframe) + "\n";
      info += "  Risk Percent: " + DoubleToString(m_riskPercent, 2) + "%\n";
      info += "  Risk Multiplier: " + DoubleToString(m_currentRiskMultiplier, 2) + "\n";
      info += "  TP Points: " + IntegerToString(m_tpPoints) + "\n";
      info += "  SL Points: " + IntegerToString(m_slPoints) + "\n";
      
      if(m_positionManager != NULL)
         info += "  " + m_positionManager.GetDetailedInfo() + "\n";
      
      if(m_orderManager != NULL)
         info += "  " + m_orderManager.GetDetailedInfo() + "\n";
      
      return info;
   }
   
   //+------------------------------------------------------------------+
   //| Méthodes d'accès aux propriétés                                  |
   //+------------------------------------------------------------------+
   string GetSymbol() const { return m_symbol; }
   int GetMagicNumber() const { return m_magicNumber; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
   double GetRiskPercent() const { return m_riskPercent; }
   int GetTPPoints() const { return m_tpPoints; }
   int GetSLPoints() const { return m_slPoints; }
   string GetTradeComment() const { return m_tradeComment; }
   
   //+------------------------------------------------------------------+
   //| Méthodes d'accès aux managers                                    |
   //+------------------------------------------------------------------+
   VolumeManager* GetVolumeManager() const { return m_volumeManager; }
   TradingValidator* GetValidator() const { return m_validator; }
   PositionManager* GetPositionManager() const { return m_positionManager; }
   PendingOrderManager* GetOrderManager() const { return m_orderManager; }
   DynamicAdjustmentManager* GetAdjustmentManager() const { return m_adjustmentManager; }
   
   //+------------------------------------------------------------------+
   //| Méthodes pour injecter les managers                              |
   //+------------------------------------------------------------------+
   void SetVolumeManager(VolumeManager* manager) { m_volumeManager = manager; }
   void SetValidator(TradingValidator* validator) { m_validator = validator; }
   void SetPositionManager(PositionManager* manager) { m_positionManager = manager; }
   void SetOrderManager(PendingOrderManager* manager) { m_orderManager = manager; }
   void SetAdjustmentManager(DynamicAdjustmentManager* manager) { m_adjustmentManager = manager; }
   
protected:
   //+------------------------------------------------------------------+
   //| 🔥 CORRECTION CRITIQUE: Calculer la taille du lot basée sur le risque |
   //| Si VolumeManager NULL, reproduire EXACTEMENT le calcul de l'ancienne version |
   //+------------------------------------------------------------------+
   double CalculateRiskBasedLots(double slPoints)
   {
      if(m_volumeManager == NULL)
      {
         Logger::Error("🔴 CRITICAL: VolumeManager is NULL for " + m_symbol + ", calculating fallback lots");
         
         // ✅ REPRODUIRE EXACTEMENT le calcul de l'ancienne version
         double effectiveRisk = m_riskPercent * m_currentRiskMultiplier;
         double risk = AccountInfoDouble(ACCOUNT_BALANCE) * effectiveRisk / 100;
         
         double ticksize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
         double tickvalue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
         double lotstep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         
         if(ticksize <= 0 || tickvalue <= 0 || lotstep <= 0)
         {
            Logger::Error("🔴 Invalid symbol parameters, returning min lot");
            return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
         }
         
         double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
         double lots = (moneyPerLotstep > 0) ? MathRound(risk / moneyPerLotstep) * lotstep : lotstep;
         
         // Contraintes du broker
         double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
         double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
         double volumeLimit = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_LIMIT);
         
         if(volumeLimit > 0) lots = MathMin(lots, volumeLimit);
         if(maxLot > 0) lots = MathMin(lots, maxLot);
         if(minLot > 0) lots = MathMax(lots, minLot);
         
         // Normaliser
         int precision = (lotstep >= 0.01) ? 2 : 3;
         lots = NormalizeDouble(lots, precision);
         
         Logger::Warning("⚠️ Fallback lot calculated: " + DoubleToString(lots, precision) + 
                        " (Risk: " + DoubleToString(effectiveRisk, 2) + "%, SL: " + DoubleToString(slPoints, 0) + " pts)");
         
         return lots;
      }
      
      return m_volumeManager.CalculateRiskBasedLots(m_riskPercent, m_currentRiskMultiplier, slPoints);
   }
   
   //+------------------------------------------------------------------+
   //| Valider un ordre                                                |
   //+------------------------------------------------------------------+
   bool ValidateOrder(double entryPrice, double slPrice, double tpPrice, ENUM_ORDER_TYPE orderType, string &errorMessage)
   {
      if(m_validator == NULL)
         return true; // Pas de validation si pas de validateur
      
      return m_validator.ValidateOrder(entryPrice, slPrice, tpPrice, orderType, errorMessage);
   }
   
   //+------------------------------------------------------------------+
   //| Créer un ordre Buy Stop                                         |
   //+------------------------------------------------------------------+
   ulong CreateBuyStop(double entryPrice, double slPrice, double tpPrice)
   {
      if(m_orderManager == NULL)
         return 0;
      
      double lots = CalculateRiskBasedLots(entryPrice - slPrice);
      return m_orderManager.CreateBuyStop(lots, entryPrice, slPrice, tpPrice);
   }
   
   //+------------------------------------------------------------------+
   //| Créer un ordre Sell Stop                                        |
   //+------------------------------------------------------------------+
   ulong CreateSellStop(double entryPrice, double slPrice, double tpPrice)
   {
      if(m_orderManager == NULL)
         return 0;
      
      double lots = CalculateRiskBasedLots(slPrice - entryPrice);
      return m_orderManager.CreateSellStop(lots, entryPrice, slPrice, tpPrice);
   }
   
   //+------------------------------------------------------------------+
   //| Créer un ordre Buy Limit                                        |
   //+------------------------------------------------------------------+
   ulong CreateBuyLimit(double entryPrice, double slPrice, double tpPrice)
   {
      if(m_orderManager == NULL)
         return 0;
      
      double lots = CalculateRiskBasedLots(entryPrice - slPrice);
      return m_orderManager.CreateBuyLimit(lots, entryPrice, slPrice, tpPrice);
   }
   
   //+------------------------------------------------------------------+
   //| Créer un ordre Sell Limit                                       |
   //+------------------------------------------------------------------+
   ulong CreateSellLimit(double entryPrice, double slPrice, double tpPrice)
   {
      if(m_orderManager == NULL)
         return 0;
      
      double lots = CalculateRiskBasedLots(slPrice - entryPrice);
      return m_orderManager.CreateSellLimit(lots, entryPrice, slPrice, tpPrice);
   }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation                                             |
//+------------------------------------------------------------------+
/*
// Classe dérivée exemple
class MySymbolTrader : public SymbolTraderBase
{
public:
   MySymbolTrader(string symbol, int magicNumber, ENUM_TIMEFRAMES timeframe,
                 double riskPercent, int tpPoints, int slPoints, string tradeComment)
   : SymbolTraderBase(symbol, magicNumber, timeframe, riskPercent, tpPoints, slPoints, tradeComment)
   {
      // Initialisation spécifique
   }
   
   virtual void OnTick() override
   {
      if(IsNewBar())
      {
         OnNewBar();
      }
      
      // Logique spécifique au tick
   }
   
   virtual void OnNewBar() override
   {
      UpdateCounters();
      
      if(HasTradingSignal())
      {
         ProcessTradingSignal();
      }
   }
   
   virtual bool HasTradingSignal() override
   {
      // Logique de détection de signal
      return false;
   }
   
   virtual void ProcessTradingSignal() override
   {
      // Logique de traitement du signal
   }
};

// Utilisation
MySymbolTrader* trader = new MySymbolTrader("EURUSD", 12345, PERIOD_M15, 2.0, 100, 50, "MyEA");

// Injecter les managers
VolumeManager* volumeMgr = new VolumeManager("EURUSD");
TradingValidator* validator = new TradingValidator("EURUSD");
// ... autres managers

trader.SetVolumeManager(volumeMgr);
trader.SetValidator(validator);
// ... injecter les autres managers

// Utilisation
trader.OnTick();
string status = trader.GetStatusInfo();

// Nettoyage
delete trader;
*/
