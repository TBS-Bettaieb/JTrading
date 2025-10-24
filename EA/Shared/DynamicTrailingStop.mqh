//+------------------------------------------------------------------+
//|                                        DynamicTrailingStop.mqh   |
//|                    Classe de Trailing Stop Loss Dynamique        |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "ForexCommissionManager.mqh"

//+------------------------------------------------------------------+
//| Classe CDynamicTrailingStop - TSL basé sur les coûts réels      |
//+------------------------------------------------------------------+
class CDynamicTrailingStop
{
private:
   // Paramètres de configuration
   int               m_tslPoints;              // Distance du trailing stop
   int               m_tslTriggerPoints;       // Trigger fixe par défaut
   bool              m_useDynamicTrigger;      // Activer le trigger dynamique
   double            m_tslCostMultiplier;      // Multiplicateur pour calcul trigger (ex: 1.5x)
   int               m_tslMinTriggerPoints;    // Trigger minimum en points
   
   // Tracking des coûts par position
   struct PositionCosts {
      ulong ticket;
      double totalCostPoints;
      double breakEvenSL;
      int dynamicTrigger;
   };
   PositionCosts m_positionCosts[];
   
   // Objets nécessaires
   CTrade            m_trade;
   CPositionInfo     m_position;
   ForexCommissionManager* m_commissionManager;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CDynamicTrailingStop(int tslPoints, 
                        int tslTriggerPoints,
                        bool useDynamicTrigger = true,
                        double tslCostMultiplier = 1.5,
                        int tslMinTriggerPoints = 50,
                        int slippagePoints = 10)
   {
      m_tslPoints = tslPoints;
      m_tslTriggerPoints = tslTriggerPoints;
      m_useDynamicTrigger = useDynamicTrigger;
      m_tslCostMultiplier = tslCostMultiplier;
      m_tslMinTriggerPoints = tslMinTriggerPoints;
      
      // Initialiser l'array des coûts
      ArrayResize(m_positionCosts, 0);
      
      // Configurer l'objet de trading
      m_trade.SetAsyncMode(false);
      m_trade.SetDeviationInPoints(slippagePoints);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      
      // Commission manager sera défini via SetCommissionManager()
      m_commissionManager = NULL;
      
      Print("✓ CDynamicTrailingStop initialized | TSL: ", m_tslPoints, " pts | Trigger: ", m_tslTriggerPoints, " pts",
            " | Dynamic: ", (m_useDynamicTrigger ? "ON" : "OFF"),
            " | Cost Multiplier: ", DoubleToString(m_tslCostMultiplier, 1),
            " | Slippage: ", slippagePoints, " pts");
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CDynamicTrailingStop()
   {
      ArrayFree(m_positionCosts);
      Print("✓ CDynamicTrailingStop destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Définir le gestionnaire de commission                           |
   //+------------------------------------------------------------------+
   void SetCommissionManager(ForexCommissionManager* manager)
   {
      m_commissionManager = manager;
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Calculer et stocker les coûts d'une position                 |
   //+------------------------------------------------------------------+
   void CalculatePositionCosts(ulong ticket, string symbol)
   {
      if(!m_position.SelectByTicket(ticket)) return;
      
      // 🆕 Avertissement si Commission Manager n'est pas configuré
      if(m_commissionManager == NULL)
      {
         static bool warningShown = false;
         if(!warningShown)
         {
            Print("⚠️ [DynamicTrailingStop] Commission Manager not set - costs may be underestimated");
            warningShown = true;
         }
      }
      
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // Calculer les coûts
      double commission = 0;
      double commissionPoints = 0;
      
      if(m_commissionManager != NULL)
      {
         commission = m_commissionManager.GetCommission(m_position);
         commissionPoints = m_commissionManager.CalculateCommissionInPoints(
             symbol, 
             commission, 
             m_position.Volume()
         );
      }
      
      double spreadPoints = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      
      double swap = PositionGetDouble(POSITION_SWAP);
      double swapPoints = 0;
      if(swap < 0)
      {
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         
         if(tickValue > 0 && volume > 0)
         {
            swapPoints = MathAbs((swap / tickValue / volume) * (tickSize / point));
         }
      }
      
      double totalCostPoints = commissionPoints + spreadPoints + swapPoints;
      
      // Calculer le breakeven SL
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double breakEvenSL = (posType == POSITION_TYPE_BUY) 
         ? openPrice + (totalCostPoints * point)
         : openPrice - (totalCostPoints * point);
      
      // Calculer le trigger dynamique
      int dynamicTrigger = (int)(totalCostPoints * m_tslCostMultiplier);
      dynamicTrigger = MathMax(dynamicTrigger, m_tslMinTriggerPoints);
      
      // Chercher si déjà existant
      int index = -1;
      for(int i = 0; i < ArraySize(m_positionCosts); i++)
      {
         if(m_positionCosts[i].ticket == ticket)
         {
            index = i;
            break;
         }
      }
      
      // Ajouter ou mettre à jour
      if(index == -1)
      {
         int size = ArraySize(m_positionCosts);
         ArrayResize(m_positionCosts, size + 1);
         index = size;
         m_positionCosts[index].ticket = ticket;
      }
      
      m_positionCosts[index].totalCostPoints = totalCostPoints;
      m_positionCosts[index].breakEvenSL = breakEvenSL;
      m_positionCosts[index].dynamicTrigger = dynamicTrigger;
      
      Print("💰 #", ticket, " [", symbol, "] Costs: ", DoubleToString(totalCostPoints, 1), " pts",
            " | BE: ", DoubleToString(breakEvenSL, 5),
            " | Dynamic Trigger: ", dynamicTrigger, " pts");
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Obtenir les informations de coûts d'une position             |
   //+------------------------------------------------------------------+
   bool GetPositionCosts(ulong ticket, double &totalCostPoints, double &breakEvenSL, int &dynamicTrigger)
   {
      for(int i = 0; i < ArraySize(m_positionCosts); i++)
      {
         if(m_positionCosts[i].ticket == ticket)
         {
            totalCostPoints = m_positionCosts[i].totalCostPoints;
            breakEvenSL = m_positionCosts[i].breakEvenSL;
            dynamicTrigger = m_positionCosts[i].dynamicTrigger;
            return true;
         }
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Nettoyer les coûts d'une position fermée                     |
   //+------------------------------------------------------------------+
   void RemovePositionCosts(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_positionCosts); i++)
      {
         if(m_positionCosts[i].ticket == ticket)
         {
            for(int j = i; j < ArraySize(m_positionCosts) - 1; j++)
            {
               m_positionCosts[j] = m_positionCosts[j + 1];
            }
            ArrayResize(m_positionCosts, ArraySize(m_positionCosts) - 1);
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| 🆕 Trailing Stop Loss DYNAMIQUE basé sur les coûts réels        |
   //+------------------------------------------------------------------+
   void ApplyTrailing(string symbol, int magicNumber)
   {
      // ✅ CRITIQUE: Configurer le magic number pour isoler cet EA
      m_trade.SetExpertMagicNumber(magicNumber);
      
      int stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double minDistance = stopLevel * point;

      if(stopLevel == 0)
      {
         int spread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
         minDistance = spread * point * 2.0;
      }

      double safetyMargin = MathMax(minDistance * 0.1, 5.0 * point);
      minDistance += safetyMargin;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
         
         if(!m_position.SelectByTicket(ticket)) continue;
         
         // 🆕 Calculer ou récupérer les coûts
         double totalCostPoints, breakEvenSL;
         int effectiveTrigger;
         
         if(!GetPositionCosts(ticket, totalCostPoints, breakEvenSL, effectiveTrigger))
         {
            CalculatePositionCosts(ticket, symbol);
            if(!GetPositionCosts(ticket, totalCostPoints, breakEvenSL, effectiveTrigger))
            {
               effectiveTrigger = m_tslTriggerPoints;
            }
         }
         else
         {
            CalculatePositionCosts(ticket, symbol);
            GetPositionCosts(ticket, totalCostPoints, breakEvenSL, effectiveTrigger);
         }
         
         // 🆕 Utiliser le trigger dynamique ou fixe
         int finalTrigger = m_useDynamicTrigger ? effectiveTrigger : m_tslTriggerPoints;
         
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         double profitPoints = 0;
         double newSL = 0;
         
         if(posType == POSITION_TYPE_BUY)
         {
            profitPoints = (currentPrice - openPrice) / point;
            
            if(profitPoints >= finalTrigger)
            {
               double trailingSL = currentPrice - (m_tslPoints * point);
               newSL = MathMax(breakEvenSL, trailingSL);
               
               double actualDistance = currentPrice - newSL;
               if(actualDistance < minDistance)
               {
                  newSL = currentPrice - minDistance;
               }
               
               newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
               
               if(newSL > currentSL + point)
               {
                  if(m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
                  {
                     Print("📈 TSL #", ticket, " [", symbol, "] BUY: ", 
                           DoubleToString(currentSL, 5), " → ", DoubleToString(newSL, 5),
                           " | Profit: ", DoubleToString(profitPoints, 1), " pts",
                           " | Trigger: ", finalTrigger, " pts ",
                           (m_useDynamicTrigger ? "(DYNAMIC)" : "(FIXED)"),
                           " | BE: ", DoubleToString(breakEvenSL, 5),
                           " | Costs: ", DoubleToString(totalCostPoints, 1), " pts");
                  }
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            profitPoints = (openPrice - currentPrice) / point;
            
            if(profitPoints >= finalTrigger)
            {
               double trailingSL = currentPrice + (m_tslPoints * point);
               newSL = MathMin(breakEvenSL, trailingSL);
               
               double actualDistance = newSL - currentPrice;
               if(actualDistance < minDistance)
               {
                  newSL = currentPrice + minDistance;
               }
               
               newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
               
               if((newSL < currentSL - point) || currentSL == 0)
               {
                  if(m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
                  {
                     Print("📉 TSL #", ticket, " [", symbol, "] SELL: ", 
                           DoubleToString(currentSL, 5), " → ", DoubleToString(newSL, 5),
                           " | Profit: ", DoubleToString(profitPoints, 1), " pts",
                           " | Trigger: ", finalTrigger, " pts ",
                           (m_useDynamicTrigger ? "(DYNAMIC)" : "(FIXED)"),
                           " | BE: ", DoubleToString(breakEvenSL, 5),
                           " | Costs: ", DoubleToString(totalCostPoints, 1), " pts");
                  }
               }
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Getters/Setters                                                  |
   //+------------------------------------------------------------------+
   void SetDynamicTrigger(bool enable)
   {
      m_useDynamicTrigger = enable;
      Print("🔧 Dynamic TSL Trigger: ", (enable ? "ENABLED" : "DISABLED"));
   }
   
   void SetCostMultiplier(double multiplier)
   {
      m_tslCostMultiplier = MathMax(0.1, MathMin(10.0, multiplier));
      Print("🔧 TSL Cost Multiplier: ", DoubleToString(m_tslCostMultiplier, 1));
   }
   
   void SetMinTriggerPoints(int points)
   {
      m_tslMinTriggerPoints = MathMax(1, points);
      Print("🔧 TSL Min Trigger Points: ", m_tslMinTriggerPoints);
   }
   
   void SetTSLPoints(int points)
   {
      m_tslPoints = MathMax(1, points);
      Print("🔧 TSL Points: ", m_tslPoints);
   }
   
   void SetTSLTriggerPoints(int points)
   {
      m_tslTriggerPoints = MathMax(1, points);
      Print("🔧 TSL Trigger Points: ", m_tslTriggerPoints);
   }
   
   // Getters
   bool GetDynamicTrigger() const { return m_useDynamicTrigger; }
   double GetCostMultiplier() const { return m_tslCostMultiplier; }
   int GetMinTriggerPoints() const { return m_tslMinTriggerPoints; }
   int GetTSLPoints() const { return m_tslPoints; }
   int GetTSLTriggerPoints() const { return m_tslTriggerPoints; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de positions trackées                         |
   //+------------------------------------------------------------------+
   int GetTrackedPositionsCount() const
   {
      return ArraySize(m_positionCosts);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de debug                               |
   //+------------------------------------------------------------------+
   string GetDebugInfo() const
   {
      string info = "CDynamicTrailingStop Debug Info:\n";
      info += "  TSL Points: " + IntegerToString(m_tslPoints) + "\n";
      info += "  TSL Trigger Points: " + IntegerToString(m_tslTriggerPoints) + "\n";
      info += "  Dynamic Trigger: " + (m_useDynamicTrigger ? "ON" : "OFF") + "\n";
      info += "  Cost Multiplier: " + DoubleToString(m_tslCostMultiplier, 1) + "\n";
      info += "  Min Trigger Points: " + IntegerToString(m_tslMinTriggerPoints) + "\n";
      info += "  Tracked Positions: " + IntegerToString(ArraySize(m_positionCosts));
      
      return info;
   }
   
};
