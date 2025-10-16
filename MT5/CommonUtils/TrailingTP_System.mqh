//+------------------------------------------------------------------+
//|                                          TrailingTP_System.mqh   |
//|                              Système de Trailing Take Profit     |
//+------------------------------------------------------------------+

//--- Énumération pour le mode de trailing TP
enum ENUM_TRAILING_TP_MODE
{
   TRAILING_TP_OFF,          // Désactivé
   TRAILING_TP_LINEAR,       // Linéaire (votre système)
   TRAILING_TP_STEPPED,      // Par paliers (recommandé)
   TRAILING_TP_EXPONENTIAL   // Exponentiel (agressif)
};

//--- Structure pour un palier de trailing
struct TrailingLevel
{
   double profitPercent;     // % de profit atteint (0-100)
   double slMoveToPercent;   // Déplacer SL à ce % (0-100)
   double tpExtendPercent;   // Étendre TP de ce %
   bool triggered;           // Palier déclenché
};

//+------------------------------------------------------------------+
//| Classe de gestion du Trailing TP                                |
//+------------------------------------------------------------------+
class CTrailingTP
{
private:
   // Paramètres
   ENUM_TRAILING_TP_MODE m_mode;
   TrailingLevel m_levels[];
   int m_levelCount;
   
   // Données de position
   double m_entryPrice;
   double m_originalSL;
   double m_originalTP;
   double m_currentSL;
   double m_currentTP;
   double m_riskPoints;
   double m_rewardPoints;
   bool m_isBuy;
   
   // Statistiques
   int m_currentLevel;
   double m_maxProfit;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                     |
   //+------------------------------------------------------------------+
   CTrailingTP(ENUM_TRAILING_TP_MODE mode = TRAILING_TP_STEPPED)
   {
      m_mode = mode;
      m_currentLevel = 0;
      m_maxProfit = 0;
      
      // Initialiser les paliers par défaut
      InitializeDefaultLevels();
   }
   
   //+------------------------------------------------------------------+
   //| Initialiser les paliers par défaut                              |
   //+------------------------------------------------------------------+
   void InitializeDefaultLevels()
   {
      switch(m_mode)
      {
         case TRAILING_TP_LINEAR:
            // Votre système original
            ArrayResize(m_levels, 4);
            m_levelCount = 4;
            
            // Niveau 1: 75% profit atteint
            m_levels[0].profitPercent = 75.0;
            m_levels[0].slMoveToPercent = 50.0;
            m_levels[0].tpExtendPercent = 25.0;
            m_levels[0].triggered = false;
            
            // Niveau 2: 100% profit (TP original atteint)
            m_levels[1].profitPercent = 100.0;
            m_levels[1].slMoveToPercent = 75.0;
            m_levels[1].tpExtendPercent = 25.0;
            m_levels[1].triggered = false;
            
            // Niveau 3: 125%
            m_levels[2].profitPercent = 125.0;
            m_levels[2].slMoveToPercent = 100.0;
            m_levels[2].tpExtendPercent = 25.0;
            m_levels[2].triggered = false;
            
            // Niveau 4: 150%
            m_levels[3].profitPercent = 150.0;
            m_levels[3].slMoveToPercent = 125.0;
            m_levels[3].tpExtendPercent = 25.0;
            m_levels[3].triggered = false;
            break;
            
         case TRAILING_TP_STEPPED:
            // Système par paliers (RECOMMANDÉ)
            ArrayResize(m_levels, 5);
            m_levelCount = 5;
            
            // Palier 1: 50% → SL à BE
            m_levels[0].profitPercent = 50.0;
            m_levels[0].slMoveToPercent = 0.0;  // Break-even
            m_levels[0].tpExtendPercent = 0.0;
            m_levels[0].triggered = false;
            
            // Palier 2: 75% → SL à 25%, TP +50%
            m_levels[1].profitPercent = 75.0;
            m_levels[1].slMoveToPercent = 25.0;
            m_levels[1].tpExtendPercent = 50.0;
            m_levels[1].triggered = false;
            
            // Palier 3: 100% → SL à 50%, TP +50%
            m_levels[2].profitPercent = 100.0;
            m_levels[2].slMoveToPercent = 50.0;
            m_levels[2].tpExtendPercent = 50.0;
            m_levels[2].triggered = false;
            
            // Palier 4: 150% → SL à 100%, TP +100%
            m_levels[3].profitPercent = 150.0;
            m_levels[3].slMoveToPercent = 100.0;
            m_levels[3].tpExtendPercent = 100.0;
            m_levels[3].triggered = false;
            
            // Palier 5: 200% → SL à 150%, TP +100%
            m_levels[4].profitPercent = 200.0;
            m_levels[4].slMoveToPercent = 150.0;
            m_levels[4].tpExtendPercent = 100.0;
            m_levels[4].triggered = false;
            break;
            
         case TRAILING_TP_EXPONENTIAL:
            // Système exponentiel (agressif)
            ArrayResize(m_levels, 4);
            m_levelCount = 4;
            
            m_levels[0].profitPercent = 50.0;
            m_levels[0].slMoveToPercent = 0.0;
            m_levels[0].tpExtendPercent = 50.0;
            m_levels[0].triggered = false;
            
            m_levels[1].profitPercent = 100.0;
            m_levels[1].slMoveToPercent = 50.0;
            m_levels[1].tpExtendPercent = 100.0;
            m_levels[1].triggered = false;
            
            m_levels[2].profitPercent = 200.0;
            m_levels[2].slMoveToPercent = 100.0;
            m_levels[2].tpExtendPercent = 200.0;
            m_levels[2].triggered = false;
            
            m_levels[3].profitPercent = 400.0;
            m_levels[3].slMoveToPercent = 200.0;
            m_levels[3].tpExtendPercent = 400.0;
            m_levels[3].triggered = false;
            break;
            
         default:
            ArrayResize(m_levels, 0);
            m_levelCount = 0;
            break;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Initialiser avec une position                                   |
   //+------------------------------------------------------------------+
   void Initialize(double entryPrice, double sl, double tp, bool isBuy)
   {
      m_entryPrice = entryPrice;
      m_originalSL = sl;
      m_originalTP = tp;
      m_currentSL = sl;
      m_currentTP = tp;
      m_isBuy = isBuy;
      
      // Calculer les points de risque/récompense
      if(isBuy)
      {
         m_riskPoints = entryPrice - sl;
         m_rewardPoints = tp - entryPrice;
      }
      else
      {
         m_riskPoints = sl - entryPrice;
         m_rewardPoints = entryPrice - tp;
      }
      
      // Réinitialiser les paliers
      for(int i = 0; i < m_levelCount; i++)
      {
         m_levels[i].triggered = false;
      }
      
      m_currentLevel = 0;
      m_maxProfit = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Calculer le profit actuel en %                                  |
   //+------------------------------------------------------------------+
   double CalculateCurrentProfitPercent(double currentPrice)
   {
      double profit;
      
      if(m_isBuy)
         profit = currentPrice - m_entryPrice;
      else
         profit = m_entryPrice - currentPrice;
      
      // % par rapport au reward original
      if(m_rewardPoints > 0)
         return (profit / m_rewardPoints) * 100.0;
      
      return 0.0;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour le trailing (appelé sur chaque tick)              |
   //+------------------------------------------------------------------+
   bool Update(double currentPrice, double &newSL, double &newTP)
   {
      if(m_mode == TRAILING_TP_OFF)
         return false;
      
      // Calculer le profit actuel en %
      double currentProfitPercent = CalculateCurrentProfitPercent(currentPrice);
      
      // Mettre à jour le profit maximum
      if(currentProfitPercent > m_maxProfit)
         m_maxProfit = currentProfitPercent;
      
      bool modified = false;
      
      // Vérifier chaque palier
      for(int i = m_currentLevel; i < m_levelCount; i++)
      {
         if(!m_levels[i].triggered && currentProfitPercent >= m_levels[i].profitPercent)
         {
            // Déclencher ce palier
            m_levels[i].triggered = true;
            m_currentLevel = i + 1;
            
            // Calculer le nouveau SL
            double slMoveDistance = m_riskPoints + (m_rewardPoints * m_levels[i].slMoveToPercent / 100.0);
            if(m_isBuy)
               m_currentSL = m_entryPrice + slMoveDistance;
            else
               m_currentSL = m_entryPrice - slMoveDistance;
            
            // Calculer le nouveau TP
            double tpExtension = m_rewardPoints * (m_levels[i].tpExtendPercent / 100.0);
            if(m_isBuy)
               m_currentTP = m_currentTP + tpExtension;
            else
               m_currentTP = m_currentTP - tpExtension;
            
            newSL = m_currentSL;
            newTP = m_currentTP;
            modified = true;
            
            Print("🎯 Trailing TP Niveau ", i+1, " déclenché!");
            Print("   Profit: ", DoubleToString(currentProfitPercent, 2), "%");
            Print("   Nouveau SL: ", DoubleToString(newSL, _Digits));
            Print("   Nouveau TP: ", DoubleToString(newTP, _Digits));
         }
      }
      
      return modified;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut                              |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string info = "Trailing TP: ";
      info += EnumToString(m_mode);
      info += " | Niveau: " + IntegerToString(m_currentLevel) + "/" + IntegerToString(m_levelCount);
      info += " | Max Profit: " + DoubleToString(m_maxProfit, 2) + "%";
      return info;
   }
   
   //+------------------------------------------------------------------+
   //| Définir des paliers personnalisés                               |
   //+------------------------------------------------------------------+
   void SetCustomLevels(TrailingLevel &levels[])
   {
      m_levelCount = ArraySize(levels);
      ArrayResize(m_levels, m_levelCount);
      ArrayCopy(m_levels, levels);
   }
};

//+------------------------------------------------------------------+
//| Fonction d'aide pour appliquer le trailing TP à une position    |
//+------------------------------------------------------------------+
bool ApplyTrailingTP(ulong ticket, CTrailingTP &trailingTP, double currentPrice)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   
   double newSL, newTP;
   
   if(trailingTP.Update(currentPrice, newSL, newTP))
   {
      // Modifier la position
      CTrade trade;
      if(trade.PositionModify(ticket, newSL, newTP))
      {
         Print("✅ Position ", ticket, " modifiée - SL: ", newSL, " TP: ", newTP);
         return true;
      }
      else
      {
         Print("❌ Erreur modification position ", ticket, ": ", GetLastError());
         return false;
      }
   }
   
   return false;
}