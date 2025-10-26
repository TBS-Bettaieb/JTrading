//+------------------------------------------------------------------+
//|                                        TrailingManager.mqh  |
//|                    Gestion centralisée du trailing TP/TSL        |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "../../../Shared/TrailingTP_System.mqh"
#include "../../../Shared/DynamicTrailingStop.mqh"
#include "../../../Shared/ForexCommissionManager.mqh"
#include "TrendlineManager.mqh"

//+------------------------------------------------------------------+
//| Structure pour tracker les positions avec trailing TP            |
//+------------------------------------------------------------------+
struct PositionTrailing {
   ulong ticket;
   CTrailingTP* trailing;
};

//+------------------------------------------------------------------+
//| Classe TrailingManager - Gestion du trailing TP/TSL        |
//+------------------------------------------------------------------+
class TrailingManager
{
private:
   string            m_symbol;
   int               m_magicNumber;
   
   // Trailing TP
   CTrailingTP*      m_trailingTP;
   bool              m_useTrailingTP;
   string            m_customTPLevels;
   ENUM_TRAILING_TP_MODE m_trailingMode;
   PositionTrailing  m_positionTrailings[];
   
   // Dynamic TSL
   CDynamicTrailingStop* m_dynamicTSL;
   ForexCommissionManager* m_commissionManager;
   
   // Trendline Manager pour mettre à jour les lignes TP/SL graphiques
   TrendlineManager* m_trendlineManager;
   
   // Objets de trading
   CTrade            m_trade;
   CPositionInfo     m_position;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   TrailingManager(string symbol, 
                        int magicNumber,
                        bool useTrailingTP,
                        ENUM_TRAILING_TP_MODE trailingTPMode,
                        string customTPLevels,
                        int tslPoints,
                        int tslTriggerPoints,
                        bool useDynamicTSLTrigger,
                        double tslCostMultiplier,
                        int tslMinTriggerPoints,
                        int slippagePoints,
                        ForexCommissionManager* commissionManager,
                        TrendlineManager* trendlineManager = NULL)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_useTrailingTP = useTrailingTP;
      m_customTPLevels = customTPLevels;
      m_trailingMode = trailingTPMode;
      m_commissionManager = commissionManager;
      m_trendlineManager = trendlineManager;
      
      // Initialiser Trailing TP
      if(m_useTrailingTP) {
         m_trailingTP = new CTrailingTP(m_trailingMode, m_customTPLevels);
         
         if(!m_trailingTP.ValidateConfiguration()) {
            Print("⚠️ Config Trailing TP invalide pour ", symbol);
            delete m_trailingTP;
            m_trailingTP = NULL;
            m_useTrailingTP = false;
         }
      } else {
         m_trailingTP = NULL;
      }
      ArrayResize(m_positionTrailings, 0);
      
      // Initialiser Dynamic TSL
      m_dynamicTSL = new CDynamicTrailingStop(
         tslPoints,
         tslTriggerPoints,
         useDynamicTSLTrigger,
         tslCostMultiplier,
         tslMinTriggerPoints,
         slippagePoints
      );
      m_dynamicTSL.SetCommissionManager(m_commissionManager);
      
      // Configurer le trading
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(slippagePoints);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
      
      Print("✓ TrailingManager initialized for ", symbol, " | Magic: ", magicNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~TrailingManager()
   {
      // Nettoyer Trailing TP
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].trailing != NULL) {
            delete m_positionTrailings[i].trailing;
         }
      }
      if(m_trailingTP != NULL) {
         delete m_trailingTP;
         m_trailingTP = NULL;
      }
      
      // Nettoyer Dynamic TSL
      if(m_dynamicTSL != NULL) {
         delete m_dynamicTSL;
         m_dynamicTSL = NULL;
      }
      
      Print("✓ TrailingManager destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Appliquer le Trailing TP à toutes les positions                 |
   //+------------------------------------------------------------------+
   void ApplyTrailingTP()
   {
      if(!m_useTrailingTP) return;
      
      CheckForNewPositions();
      
      for(int i = ArraySize(m_positionTrailings) - 1; i >= 0; i--) {
         ulong ticket = m_positionTrailings[i].ticket;
         
         if(!PositionSelectByTicket(ticket)) {
            OnPositionClosed(ticket);
            continue;
         }
         
         double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
            ? SymbolInfoDouble(m_symbol, SYMBOL_BID)
            : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         
         double newSL, newTP;
         if(m_positionTrailings[i].trailing.Update(currentPrice, newSL, newTP)) {
            if(newSL > 0 || newTP > 0) {
               if(m_trade.PositionModify(ticket, newSL, newTP)) {
                  // ✅ Mise à jour réussie, rafraîchir les lignes TP/SL graphiques
                  if(m_trendlineManager != NULL) {
                     m_trendlineManager.UpdatePositionLines(ticket, newTP, newSL);
                  }
               }
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Trailing Stop Loss dynamique                                     |
   //+------------------------------------------------------------------+
   void TrailStop()
   {
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.ApplyTrailing(m_symbol, m_magicNumber);
         
         // ✅ Mettre à jour les trendlines après le trailing stop
         if(m_trendlineManager != NULL)
         {
            for(int i = 0; i < PositionsTotal(); i++)
            {
               if(!m_position.SelectByIndex(i)) continue;
               if(m_position.Magic() != m_magicNumber) continue;
               if(m_position.Symbol() != m_symbol) continue;
               
               ulong ticket = m_position.Ticket();
               double currentTP = PositionGetDouble(POSITION_TP);
               double currentSL = PositionGetDouble(POSITION_SL);
               
               m_trendlineManager.UpdatePositionLines(ticket, currentTP, currentSL);
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculer les coûts de position pour le TSL dynamique            |
   //+------------------------------------------------------------------+
   void OnPositionOpened(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return;
      
      // Calculer les coûts de position pour le TSL dynamique
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.CalculatePositionCosts(ticket, m_symbol);
      }
      
      // ✅ Créer les trendlines TP/SL pour cette position
      if(m_trendlineManager != NULL)
      {
         double tp = PositionGetDouble(POSITION_TP);
         double sl = PositionGetDouble(POSITION_SL);
         m_trendlineManager.CreatePositionLines(ticket, tp, sl);
      }
      
      // Gestion du trailing TP
      if(!m_useTrailingTP || m_trailingTP == NULL) return;
      
      // Vérifier que ce n'est pas déjà tracké
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].ticket == ticket) return;
      }
      
      // Créer un nouveau trailing TP
      CTrailingTP* newTrailing = new CTrailingTP(
         m_trailingTP.GetMode(),
         m_trailingTP.GetCustomLevelsString()
      );
      
      newTrailing.Initialize(
         PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_SL),
         PositionGetDouble(POSITION_TP),
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY
      );
      
      int size = ArraySize(m_positionTrailings);
      ArrayResize(m_positionTrailings, size + 1);
      m_positionTrailings[size].ticket = ticket;
      m_positionTrailings[size].trailing = newTrailing;
      
      Print("🎯 Trailing TP #", ticket, " | Mode: ", EnumToString(m_trailingTP.GetMode()),
            " | Niveaux: ", newTrailing.GetLevelCount());
   }
   
   //+------------------------------------------------------------------+
   //| Nettoyer quand une position est fermée                          |
   //+------------------------------------------------------------------+
   void OnPositionClosed(ulong ticket)
   {
      // ✅ Supprimer les trendlines TP/SL pour cette position
      if(m_trendlineManager != NULL)
      {
         m_trendlineManager.DeletePositionLines(ticket);
      }
      
      // Nettoyer les coûts de position pour le TSL dynamique
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.RemovePositionCosts(ticket);
      }
      
      // Gestion du trailing TP
      for(int i = 0; i < ArraySize(m_positionTrailings); i++) {
         if(m_positionTrailings[i].ticket == ticket) {
            if(m_positionTrailings[i].trailing != NULL) {
               delete m_positionTrailings[i].trailing;
            }
            for(int j = i; j < ArraySize(m_positionTrailings) - 1; j++) {
               m_positionTrailings[j] = m_positionTrailings[j + 1];
            }
            ArrayResize(m_positionTrailings, ArraySize(m_positionTrailings) - 1);
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Détecter les nouvelles positions                                 |
   //+------------------------------------------------------------------+
   void CheckForNewPositions()
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Magic() != m_magicNumber) continue;
         if(m_position.Symbol() != m_symbol) continue;
         
         ulong ticket = m_position.Ticket();
         
         bool alreadyTracked = false;
         for(int j = 0; j < ArraySize(m_positionTrailings); j++)
         {
            if(m_positionTrailings[j].ticket == ticket)
            {
               alreadyTracked = true;
               break;
            }
         }
         
         if(!alreadyTracked) OnPositionOpened(ticket);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configuration Dynamic TSL                                        |
   //+------------------------------------------------------------------+
   void SetDynamicTSLTrigger(bool enable)
   {
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.SetDynamicTrigger(enable);
      }
   }
   
   void SetDynamicTSLCostMultiplier(double multiplier)
   {
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.SetCostMultiplier(multiplier);
      }
   }
   
   void SetDynamicTSLMinTriggerPoints(int points)
   {
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.SetMinTriggerPoints(points);
      }
   }
   
   string GetDynamicTSLDebugInfo()
   {
      if(m_dynamicTSL != NULL)
      {
         return m_dynamicTSL.GetDebugInfo();
      }
      return "Dynamic TSL not initialized";
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de positions trackées                         |
   //+------------------------------------------------------------------+
   int GetTrackedPositionsCount()
   {
      return ArraySize(m_positionTrailings);
   }
};
