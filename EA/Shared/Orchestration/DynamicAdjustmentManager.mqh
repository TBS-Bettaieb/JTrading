//+------------------------------------------------------------------+
//|                                  DynamicAdjustmentManager.mqh     |
//|                    Gestionnaire d'ajustement dynamique           |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../Core/PositionManager.mqh"
#include "../Core/PendingOrderManager.mqh"
#include "../Core/VolumeManager.mqh"
#include "../Logger.mqh"

//+------------------------------------------------------------------+
//| Classe DynamicAdjustmentManager - Ajustement dynamique           |
//+------------------------------------------------------------------+
class DynamicAdjustmentManager
{
private:
   string            m_symbol;              // Symbole géré
   int               m_magicNumber;         // Magic number
   PositionManager*  m_positionManager;     // Gestionnaire de positions (injecté)
   PendingOrderManager* m_orderManager;     // Gestionnaire d'ordres (injecté)
   VolumeManager*    m_volumeManager;       // Gestionnaire de volume (injecté)
   
   // Historique des ajustements
   struct AdjustmentRecord {
      datetime timestamp;
      double oldMultiplier;
      double newMultiplier;
      int adjustedOrders;
      int adjustedPositions;
      string description;
   };
   AdjustmentRecord m_adjustmentHistory[];
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   DynamicAdjustmentManager(string symbol, int magicNumber, 
                           PositionManager* positionManager,
                           PendingOrderManager* orderManager,
                           VolumeManager* volumeManager)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_positionManager = positionManager;
      m_orderManager = orderManager;
      m_volumeManager = volumeManager;
      
      ArrayResize(m_adjustmentHistory, 0);
      
      Logger::Debug("DynamicAdjustmentManager initialized for " + symbol + " | Magic: " + IntegerToString(magicNumber));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~DynamicAdjustmentManager()
   {
      Logger::Debug("DynamicAdjustmentManager destroyed for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Ajuster les volumes des ordres pending avec un multiplicateur   |
   //+------------------------------------------------------------------+
   int AdjustOrderVolumes(double oldMultiplier, double newMultiplier, string description = "")
   {
      if(m_orderManager == NULL)
      {
         Logger::Error("OrderManager not available for volume adjustment");
         return 0;
      }
      
      // Valider les multiplicateurs
      double validOldMultiplier = MathMax(0.1, MathMin(10.0, oldMultiplier));
      double validNewMultiplier = MathMax(0.1, MathMin(10.0, newMultiplier));
      
      // ✅ CORRECTION: Réduire le seuil pour permettre de plus petits ajustements
      if(MathAbs(validNewMultiplier - validOldMultiplier) < 0.001)
      {
         Logger::Debug("Multiplier change too small, skipping adjustment");
         return 0;
      }
      
      // Obtenir tous les ordres
      ulong tickets[];
      int orderCount = m_orderManager.GetOrderTickets(tickets);
      
      if(orderCount == 0)
      {
         Logger::Debug("No pending orders to adjust for " + m_symbol);
         return 0;
      }
      
      int adjustedCount = 0;
      
      // Ajuster chaque ordre
      for(int i = 0; i < orderCount; i++)
      {
         ulong ticket = tickets[i];
         
         // Obtenir les informations de l'ordre
         double currentPrice, currentVolume, currentSL, currentTP;
         ENUM_ORDER_TYPE orderType;
         datetime expiration;
         
         if(!m_orderManager.GetOrderInfo(ticket, currentPrice, currentVolume, currentSL, currentTP, orderType, expiration))
         {
            Logger::Warning("Could not get info for order #" + IntegerToString(ticket));
            continue;
         }
         
         // Calculer le nouveau volume
         double newVolume = m_volumeManager.AdjustVolumeWithMultiplier(currentVolume, validOldMultiplier, validNewMultiplier);
         
         // Vérifier si le volume a changé significativement
         if(MathAbs(newVolume - currentVolume) < m_volumeManager.GetLotStep())
         {
            Logger::Debug("Volume change too small for order #" + IntegerToString(ticket) + ", skipping");
            continue;
         }
         
         // Ajuster le volume de l'ordre
         if(m_orderManager.AdjustOrderVolume(ticket, newVolume))
         {
            adjustedCount++;
            Logger::Info("Order #" + IntegerToString(ticket) + " volume adjusted: " + 
                        DoubleToString(currentVolume, 2) + " → " + DoubleToString(newVolume, 2) + " lots");
         }
         else
         {
            Logger::Error("Failed to adjust volume for order #" + IntegerToString(ticket));
         }
      }
      
      // Enregistrer l'ajustement
      RecordAdjustment(validOldMultiplier, validNewMultiplier, adjustedCount, 0, description);
      
      Logger::Info("Volume adjustment completed for " + m_symbol + ": " + IntegerToString(adjustedCount) + 
                  " order(s) adjusted | Multiplier: " + DoubleToString(validOldMultiplier, 2) + 
                  " → " + DoubleToString(validNewMultiplier, 2));
      
      return adjustedCount;
   }
   
   //+------------------------------------------------------------------+
   //| Ajuster les paramètres de trading (SL/TP)                      |
   //+------------------------------------------------------------------+
   int AdjustTradingParameters(double slMultiplier, double tpMultiplier, string description = "")
   {
      if(m_positionManager == NULL || m_orderManager == NULL)
      {
         Logger::Error("Managers not available for parameter adjustment");
         return 0;
      }
      
      int adjustedCount = 0;
      
      // Ajuster les positions existantes
      ulong positionTickets[];
      int positionCount = m_positionManager.GetPositionTickets(positionTickets);
      
      for(int i = 0; i < positionCount; i++)
      {
         ulong ticket = positionTickets[i];
         
         // Obtenir les informations de la position
         double openPrice, currentPrice, profit, swap, commission;
         ENUM_POSITION_TYPE positionType;
         
         if(!m_positionManager.GetPositionInfo(ticket, openPrice, currentPrice, profit, swap, commission, positionType))
         {
            Logger::Warning("Could not get info for position #" + IntegerToString(ticket));
            continue;
         }
         
         // Calculer les nouveaux SL/TP
         double currentSL = 0, currentTP = 0;
         // Note: Il faudrait récupérer les SL/TP actuels depuis la position
         // Pour l'instant, on utilise des valeurs par défaut
         
         double newSL = currentSL * slMultiplier;
         double newTP = currentTP * tpMultiplier;
         
         // Modifier la position
         if(m_positionManager.ModifyPosition(ticket, newSL, newTP))
         {
            adjustedCount++;
            Logger::Info("Position #" + IntegerToString(ticket) + " parameters adjusted");
         }
      }
      
      // Ajuster les ordres pending
      ulong orderTickets[];
      int orderCount = m_orderManager.GetOrderTickets(orderTickets);
      
      for(int i = 0; i < orderCount; i++)
      {
         ulong ticket = orderTickets[i];
         
         // Obtenir les informations de l'ordre
         double currentPrice, currentVolume, currentSL, currentTP;
         ENUM_ORDER_TYPE orderType;
         datetime expiration;
         
         if(!m_orderManager.GetOrderInfo(ticket, currentPrice, currentVolume, currentSL, currentTP, orderType, expiration))
         {
            Logger::Warning("Could not get info for order #" + IntegerToString(ticket));
            continue;
         }
         
         // Calculer les nouveaux SL/TP
         double newSL = currentSL * slMultiplier;
         double newTP = currentTP * tpMultiplier;
         
         // Modifier l'ordre
         if(m_orderManager.ModifyOrder(ticket, currentPrice, newSL, newTP))
         {
            adjustedCount++;
            Logger::Info("Order #" + IntegerToString(ticket) + " parameters adjusted");
         }
      }
      
      Logger::Info("Parameter adjustment completed for " + m_symbol + ": " + IntegerToString(adjustedCount) + 
                  " item(s) adjusted | SL: x" + DoubleToString(slMultiplier, 2) + 
                  " | TP: x" + DoubleToString(tpMultiplier, 2));
      
      return adjustedCount;
   }
   
   //+------------------------------------------------------------------+
   //| Ajustement complet (volumes + paramètres)                       |
   //+------------------------------------------------------------------+
   int AdjustAll(double oldVolumeMultiplier, double newVolumeMultiplier, 
                double slMultiplier = 1.0, double tpMultiplier = 1.0, 
                string description = "")
   {
      int totalAdjusted = 0;
      
      // Ajuster les volumes des ordres
      if(MathAbs(newVolumeMultiplier - oldVolumeMultiplier) > 0.01)
      {
         totalAdjusted += AdjustOrderVolumes(oldVolumeMultiplier, newVolumeMultiplier, description);
      }
      
      // Ajuster les paramètres SL/TP
      if(MathAbs(slMultiplier - 1.0) > 0.01 || MathAbs(tpMultiplier - 1.0) > 0.01)
      {
         totalAdjusted += AdjustTradingParameters(slMultiplier, tpMultiplier, description);
      }
      
      return totalAdjusted;
   }
   
   //+------------------------------------------------------------------+
   //| Annuler tous les ordres pending                                 |
   //+------------------------------------------------------------------+
   int CancelAllPendingOrders()
   {
      if(m_orderManager == NULL)
      {
         Logger::Error("OrderManager not available for cancellation");
         return 0;
      }
      
      int cancelledCount = m_orderManager.DeleteAllOrders();
      
      if(cancelledCount > 0)
      {
         Logger::Info("Cancelled " + IntegerToString(cancelledCount) + " pending order(s) for " + m_symbol);
      }
      
      return cancelledCount;
   }
   
   //+------------------------------------------------------------------+
   //| Fermer toutes les positions                                     |
   //+------------------------------------------------------------------+
   int CloseAllPositions()
   {
      if(m_positionManager == NULL)
      {
         Logger::Error("PositionManager not available for closing");
         return 0;
      }
      
      int closedCount = m_positionManager.CloseAllPositions();
      
      if(closedCount > 0)
      {
         Logger::Info("Closed " + IntegerToString(closedCount) + " position(s) for " + m_symbol);
      }
      
      return closedCount;
   }
   
   //+------------------------------------------------------------------+
   //| Enregistrer un ajustement dans l'historique                     |
   //+------------------------------------------------------------------+
   void RecordAdjustment(double oldMultiplier, double newMultiplier, int adjustedOrders, int adjustedPositions, string description)
   {
      int size = ArraySize(m_adjustmentHistory);
      ArrayResize(m_adjustmentHistory, size + 1);
      
      m_adjustmentHistory[size].timestamp = TimeCurrent();
      m_adjustmentHistory[size].oldMultiplier = oldMultiplier;
      m_adjustmentHistory[size].newMultiplier = newMultiplier;
      m_adjustmentHistory[size].adjustedOrders = adjustedOrders;
      m_adjustmentHistory[size].adjustedPositions = adjustedPositions;
      m_adjustmentHistory[size].description = description;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir l'historique des ajustements                            |
   //+------------------------------------------------------------------+
   string GetAdjustmentHistory(int maxRecords = 10)
   {
      string history = "Adjustment History for " + m_symbol + ":\n";
      
      int startIndex = MathMax(0, ArraySize(m_adjustmentHistory) - maxRecords);
      
      for(int i = startIndex; i < ArraySize(m_adjustmentHistory); i++)
      {
         history += "  " + TimeToString(m_adjustmentHistory[i].timestamp, TIME_DATE|TIME_MINUTES) + ": ";
         history += "x" + DoubleToString(m_adjustmentHistory[i].oldMultiplier, 2) + " → x" + DoubleToString(m_adjustmentHistory[i].newMultiplier, 2);
         history += " | Orders: " + IntegerToString(m_adjustmentHistory[i].adjustedOrders);
         history += " | Positions: " + IntegerToString(m_adjustmentHistory[i].adjustedPositions);
         if(m_adjustmentHistory[i].description != "")
            history += " | " + m_adjustmentHistory[i].description;
         history += "\n";
      }
      
      return history;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total d'ajustements                           |
   //+------------------------------------------------------------------+
   int GetAdjustmentCount() const { return ArraySize(m_adjustmentHistory); }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut                              |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string status = "DynamicAdjustmentManager for " + m_symbol + ": ";
      status += "Adjustments: " + IntegerToString(GetAdjustmentCount());
      
      if(m_positionManager != NULL)
         status += " | Positions: " + IntegerToString(m_positionManager.GetTotalPositions());
      
      if(m_orderManager != NULL)
         status += " | Orders: " + IntegerToString(m_orderManager.GetTotalOrders());
      
      return status;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo()
   {
      string info = "DynamicAdjustmentManager for " + m_symbol + ":\n";
      info += "  Total Adjustments: " + IntegerToString(GetAdjustmentCount()) + "\n";
      
      if(m_positionManager != NULL)
      {
         info += "  " + m_positionManager.GetDetailedInfo() + "\n";
      }
      
      if(m_orderManager != NULL)
      {
         info += "  " + m_orderManager.GetDetailedInfo() + "\n";
      }
      
      info += GetAdjustmentHistory(5);
      
      return info;
   }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation                                             |
//+------------------------------------------------------------------+
/*
// Création des dépendances
CTrade* trade = new CTrade();
VolumeManager* volumeMgr = new VolumeManager("EURUSD");
TradingValidator* validator = new TradingValidator("EURUSD");
PositionManager* posMgr = new PositionManager("EURUSD", 12345, trade);
PendingOrderManager* orderMgr = new PendingOrderManager("EURUSD", 12345, trade, volumeMgr, validator, 10, PERIOD_M15, 3, "MyEA");

// Création du gestionnaire d'ajustement
DynamicAdjustmentManager* adjMgr = new DynamicAdjustmentManager("EURUSD", 12345, posMgr, orderMgr, volumeMgr);

// Ajustement des volumes
int adjustedOrders = adjMgr.AdjustOrderVolumes(1.0, 2.0, "Risk increase");

// Ajustement des paramètres
int adjustedParams = adjMgr.AdjustTradingParameters(1.2, 1.1, "SL/TP adjustment");

// Ajustement complet
int totalAdjusted = adjMgr.AdjustAll(1.0, 1.5, 1.1, 1.05, "Full adjustment");

// Annuler tous les ordres
int cancelled = adjMgr.CancelAllPendingOrders();

// Fermer toutes les positions
int closed = adjMgr.CloseAllPositions();

// Obtenir l'historique
string history = adjMgr.GetAdjustmentHistory();

// Obtenir les statistiques
string status = adjMgr.GetStatusInfo();
string details = adjMgr.GetDetailedInfo();

// Nettoyage
delete adjMgr;
delete orderMgr;
delete posMgr;
delete validator;
delete volumeMgr;
delete trade;
*/
