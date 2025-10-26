//+------------------------------------------------------------------+
//|                                    Example_DynamicTrailingUsage.mqh |
//|                                    Exemple d'utilisation TSL Dynamique |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Exemple d'utilisation du Trailing Stop Dynamique                 |
//+------------------------------------------------------------------+

/*
=== COMMENT UTILISER LE TRAILING STOP DYNAMIQUE ===

1. PARAMÈTRES D'ENTRÉE DANS METAEDITOR :

   === TRAILING STOP ===
   ✓ InpUseTrailing = true              // Activer Trailing Stop
   ✓ InpUseDynamicTrailing = true      // Activer TSL Dynamique
   ✓ InpTSLTrigger = 50                // Déclenchement (points)
   ✓ InpTSLDistance = 30               // Distance (points)
   ✓ InpTSLCostMultiplier = 1.5         // Multiplicateur coûts TSL
   ✓ InpTSLMinTriggerPoints = 50       // Trigger minimum TSL (points)

2. FONCTIONNEMENT :

   a) CALCUL DES COÛTS RÉELS :
      - Commission réelle de la position
      - Spread au moment de l'ouverture
      - Swap négatif (si applicable)
      - Total converti en points

   b) TRIGGER DYNAMIQUE :
      - Trigger = Coûts réels × Multiplicateur (1.5x par défaut)
      - Minimum = InpTSLMinTriggerPoints (50 pts par défaut)
      - Exemple : Si coûts = 20 pts → Trigger = 30 pts (20 × 1.5)

   c) BREAKEVEN INTELLIGENT :
      - SL minimum = Prix d'ouverture + Coûts réels
      - Protection contre les pertes dues aux coûts

3. LOGS EN TEMPS RÉEL :

   💰 #123456 [EURUSD] Costs: 25.3 pts | BE: 1.08523 | Dynamic Trigger: 38 pts
   📈 TSL #123456 [EURUSD] BUY: 1.08500 → 1.08515 | Profit: 45.2 pts | Trigger: 38 pts (DYNAMIC) | BE: 1.08523 | Costs: 25.3 pts

4. AVANTAGES :

   ✅ Protection intelligente basée sur les coûts réels
   ✅ Trigger adaptatif selon le broker/symbole
   ✅ Breakeven automatique après couverture des coûts
   ✅ Fallback vers TSL classique si problème
   ✅ Logs détaillés pour monitoring

5. CONFIGURATION RECOMMANDÉE :

   Pour EURUSD (spread ~1-2 pts) :
   - InpTSLTrigger = 30-50 pts
   - InpTSLDistance = 20-30 pts
   - InpTSLCostMultiplier = 1.5-2.0
   - InpTSLMinTriggerPoints = 30-50 pts

   Pour GBPUSD (spread ~2-3 pts) :
   - InpTSLTrigger = 40-60 pts
   - InpTSLDistance = 25-35 pts
   - InpTSLCostMultiplier = 1.5-2.0
   - InpTSLMinTriggerPoints = 40-60 pts

6. MONITORING :

   Dans les logs, surveillez :
   - "Dynamic Trailing Stop initialized" → Initialisation OK
   - "Costs: X.X pts" → Calcul des coûts
   - "Dynamic Trigger: X pts" → Trigger calculé
   - "TSL #XXXXX [SYMBOL] BUY/SELL" → Modifications TSL

7. DÉPANNAGE :

   Si problème avec TSL dynamique :
   - Le système bascule automatiquement vers TSL classique
   - Vérifiez les logs pour "Commission Manager not set"
   - Assurez-vous que ForexCommissionManager.mqh est inclus

=== EXEMPLE DE SORTIE LOGS ===

2025.01.15 10:30:15 ✓ CDynamicTrailingStop initialized | TSL: 30 pts | Trigger: 50 pts | Dynamic: ON | Cost Multiplier: 1.5 | Slippage: 10 pts
2025.01.15 10:30:15 Dynamic Trailing Stop initialized for EURUSD
2025.01.15 10:30:15 TripleRSI Trader created for EURUSD (Magic: 123456) | Dynamic TSL: ON
2025.01.15 10:30:20 💰 #123456 [EURUSD] Costs: 22.5 pts | BE: 1.08522 | Dynamic Trigger: 34 pts
2025.01.15 10:30:25 📈 TSL #123456 [EURUSD] BUY: 1.08500 → 1.08510 | Profit: 35.2 pts | Trigger: 34 pts (DYNAMIC) | BE: 1.08522 | Costs: 22.5 pts

*/

//+------------------------------------------------------------------+
//| Fonction de test pour vérifier le TSL dynamique                  |
//+------------------------------------------------------------------+
void TestDynamicTrailingStop()
{
   Print("=== TEST DYNAMIC TRAILING STOP ===");
   Print("1. Vérifiez que InpUseDynamicTrailing = true");
   Print("2. Ouvrez une position manuellement");
   Print("3. Surveillez les logs pour les calculs de coûts");
   Print("4. Attendez que le profit atteigne le trigger dynamique");
   Print("5. Vérifiez que le TSL se met à jour avec 'DYNAMIC' dans les logs");
   Print("================================");
}

//+------------------------------------------------------------------+
//| Fonction d'aide pour configurer les paramètres                 |
//+------------------------------------------------------------------+
void ConfigureDynamicTrailingForSymbol(string symbol)
{
   Print("=== CONFIGURATION TSL DYNAMIQUE POUR " + symbol + " ===");
   
   if(symbol == "EURUSD")
   {
      Print("Paramètres recommandés EURUSD :");
      Print("- InpTSLTrigger = 40 pts");
      Print("- InpTSLDistance = 25 pts");
      Print("- InpTSLCostMultiplier = 1.5");
      Print("- InpTSLMinTriggerPoints = 40 pts");
   }
   else if(symbol == "GBPUSD")
   {
      Print("Paramètres recommandés GBPUSD :");
      Print("- InpTSLTrigger = 50 pts");
      Print("- InpTSLDistance = 30 pts");
      Print("- InpTSLCostMultiplier = 1.5");
      Print("- InpTSLMinTriggerPoints = 50 pts");
   }
   else if(symbol == "USDJPY")
   {
      Print("Paramètres recommandés USDJPY :");
      Print("- InpTSLTrigger = 60 pts");
      Print("- InpTSLDistance = 35 pts");
      Print("- InpTSLCostMultiplier = 1.5");
      Print("- InpTSLMinTriggerPoints = 60 pts");
   }
   else
   {
      Print("Paramètres génériques :");
      Print("- InpTSLTrigger = 50 pts");
      Print("- InpTSLDistance = 30 pts");
      Print("- InpTSLCostMultiplier = 1.5");
      Print("- InpTSLMinTriggerPoints = 50 pts");
   }
   
   Print("================================");
}
