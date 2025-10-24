//+------------------------------------------------------------------+
//|                              Example_DynamicTrailingStop_Usage.mqh |
//|                    Exemple d'utilisation de CDynamicTrailingStop  |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "DynamicTrailingStop.mqh"
#include "ForexCommissionManager.mqh"

//+------------------------------------------------------------------+
//| Exemple d'utilisation de CDynamicTrailingStop dans un EA         |
//+------------------------------------------------------------------+
class ExampleEA
{
private:
   // Objets nécessaires
   CDynamicTrailingStop* m_dynamicTSL;
   ForexCommissionManager m_commissionManager;
   CTrade m_trade;
   
   // Paramètres
   string m_symbol;
   int m_magicNumber;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   ExampleEA(string symbol, int magicNumber)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      
      // Initialiser le Dynamic Trailing Stop
      m_dynamicTSL = new CDynamicTrailingStop(
         50,        // TSL Points: 50 points de trailing
         30,        // TSL Trigger Points: 30 points de profit avant activation
         true,      // Use Dynamic Trigger: activé
         1.5,       // Cost Multiplier: 1.5x les coûts
         20         // Min Trigger Points: minimum 20 points
      );
      
      // Configurer le gestionnaire de commission
      m_dynamicTSL.SetCommissionManager(&m_commissionManager);
      
      Print("✓ ExampleEA initialized with Dynamic TSL");
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~ExampleEA()
   {
      if(m_dynamicTSL != NULL)
      {
         delete m_dynamicTSL;
         m_dynamicTSL = NULL;
      }
      Print("✓ ExampleEA destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Traitement principal du tick                                    |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // Appliquer le trailing stop dynamique
      if(m_dynamicTSL != NULL)
      {
         m_dynamicTSL.ApplyTrailing(m_symbol, m_magicNumber);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Exemple d'ouverture de position avec calcul automatique des coûts |
   //+------------------------------------------------------------------+
   void OpenPositionExample()
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double sl = ask - 100 * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tp = ask + 150 * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      if(m_trade.Buy(0.01, m_symbol, ask, sl, tp, "Example Trade"))
      {
         ulong ticket = m_trade.ResultOrder();
         Print("✓ Position ouverte #", ticket);
         
         // Calculer automatiquement les coûts pour le TSL dynamique
         if(m_dynamicTSL != NULL)
         {
            m_dynamicTSL.CalculatePositionCosts(ticket, m_symbol);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Exemple de fermeture de position avec nettoyage automatique     |
   //+------------------------------------------------------------------+
   void ClosePositionExample(ulong ticket)
   {
      if(m_trade.PositionClose(ticket))
      {
         Print("✓ Position fermée #", ticket);
         
         // Nettoyer automatiquement les coûts trackés
         if(m_dynamicTSL != NULL)
         {
            m_dynamicTSL.RemovePositionCosts(ticket);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Exemples de configuration dynamique                             |
   //+------------------------------------------------------------------+
   void ConfigureDynamicTSL()
   {
      if(m_dynamicTSL == NULL) return;
      
      // Désactiver le trigger dynamique (utiliser le trigger fixe)
      m_dynamicTSL.SetDynamicTrigger(false);
      
      // Modifier le multiplicateur de coûts
      m_dynamicTSL.SetCostMultiplier(2.0); // 2x les coûts
      
      // Modifier le trigger minimum
      m_dynamicTSL.SetMinTriggerPoints(40); // minimum 40 points
      
      // Modifier la distance de trailing
      m_dynamicTSL.SetTSLPoints(75); // 75 points de trailing
      
      // Modifier le trigger fixe
      m_dynamicTSL.SetTSLTriggerPoints(50); // 50 points de profit avant activation
      
      Print("✓ Dynamic TSL reconfiguré");
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de debug                               |
   //+------------------------------------------------------------------+
   void ShowDebugInfo()
   {
      if(m_dynamicTSL != NULL)
      {
         Print("=== Dynamic TSL Debug Info ===");
         Print(m_dynamicTSL.GetDebugInfo());
         Print("Positions trackées: ", m_dynamicTSL.GetTrackedPositionsCount());
      }
   }
   
   //+------------------------------------------------------------------+
   //| Exemple d'utilisation avancée avec gestion d'erreurs            |
   //+------------------------------------------------------------------+
   void AdvancedUsageExample()
   {
      if(m_dynamicTSL == NULL)
      {
         Print("❌ Dynamic TSL not initialized");
         return;
      }
      
      // Vérifier si le trigger dynamique est activé
      if(m_dynamicTSL.GetDynamicTrigger())
      {
         Print("✓ Trigger dynamique activé");
         Print("  - Multiplicateur: ", DoubleToString(m_dynamicTSL.GetCostMultiplier(), 1));
         Print("  - Trigger minimum: ", m_dynamicTSL.GetMinTriggerPoints(), " points");
      }
      else
      {
         Print("✓ Trigger fixe activé: ", m_dynamicTSL.GetTSLTriggerPoints(), " points");
      }
      
      Print("  - Distance TSL: ", m_dynamicTSL.GetTSLPoints(), " points");
      Print("  - Positions trackées: ", m_dynamicTSL.GetTrackedPositionsCount());
   }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation dans un Expert Advisor                     |
//+------------------------------------------------------------------+
/*
// Dans votre EA principal :

ExampleEA* g_exampleEA = NULL;

int OnInit()
{
   g_exampleEA = new ExampleEA(Symbol(), 12345);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_exampleEA != NULL)
   {
      delete g_exampleEA;
      g_exampleEA = NULL;
   }
}

void OnTick()
{
   if(g_exampleEA != NULL)
   {
      g_exampleEA.OnTick();
   }
}

// Exemple d'utilisation avec des paramètres d'entrée
input int InpTSLPoints = 50;
input int InpTSLTriggerPoints = 30;
input bool InpUseDynamicTrigger = true;
input double InpCostMultiplier = 1.5;
input int InpMinTriggerPoints = 20;

// Dans OnInit() :
g_exampleEA = new ExampleEA(Symbol(), 12345);
if(g_exampleEA != NULL)
{
   g_exampleEA.SetDynamicTSLTrigger(InpUseDynamicTrigger);
   g_exampleEA.SetDynamicTSLCostMultiplier(InpCostMultiplier);
   g_exampleEA.SetDynamicTSLMinTriggerPoints(InpMinTriggerPoints);
}
*/
