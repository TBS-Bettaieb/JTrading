//+------------------------------------------------------------------+
//|                                    Example_SignalDetection.mqh   |
//|                    Exemple d'utilisation du SignalDetectionManager |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../analysis/SignalDetectionManager.mqh"

//+------------------------------------------------------------------+
//| Exemple d'utilisation du SignalDetectionManager                  |
//+------------------------------------------------------------------+
void ExampleSignalDetectionUsage()
{
   // Créer les objets nécessaires (normalement dans le constructeur)
   SwingAnalyzer swingAnalyzer("EURUSD", PERIOD_M15, 12345, 20);
   SymbolStatus statusManager("EURUSD", 12345, PERIOD_M15);
   
   // Créer le Signal Detection Manager
   SignalDetectionManager signalManager(
      "EURUSD",
      PERIOD_M15,
      STRATEGY_BREAKOUT,  // ou STRATEGY_REVERSION
      &swingAnalyzer,
      &statusManager
   );
   
   // Configuration des signaux
   signalManager.EnableBuySignals(true);
   signalManager.EnableSellSignals(true);
   
   // Dans votre OnTick() ou boucle principale
   SignalInfo signal;
   
   // Vérifier les signaux d'achat
   if(signalManager.CheckForBuySignal(signal))
   {
      Print("🎯 Signal d'achat détecté !");
      Print("   Type: ", EnumToString(signal.signalType));
      Print("   Prix: ", DoubleToString(signal.triggerPrice, 5));
      Print("   Mode: ", EnumToString(signal.strategyMode));
      Print("   Description: ", signal.description);
      
      // Ici vous pouvez envoyer l'ordre
      // m_orderManager.SendBuyOrder(signal.triggerPrice);
   }
   
   // Vérifier les signaux de vente
   if(signalManager.CheckForSellSignal(signal))
   {
      Print("🎯 Signal de vente détecté !");
      Print("   Type: ", EnumToString(signal.signalType));
      Print("   Prix: ", DoubleToString(signal.triggerPrice, 5));
      Print("   Mode: ", EnumToString(signal.strategyMode));
      Print("   Description: ", signal.description);
      
      // Ici vous pouvez envoyer l'ordre
      // m_orderManager.SendSellOrder(signal.triggerPrice);
   }
   
   // Obtenir des informations sur le manager
   Print("📊 Configuration actuelle:");
   Print("   Symbole: ", signalManager.GetSymbol());
   Print("   Timeframe: ", EnumToString(signalManager.GetTimeframe()));
   Print("   Mode stratégie: ", EnumToString(signalManager.GetStrategyMode()));
   Print("   Signaux d'achat activés: ", signalManager.IsBuySignalsEnabled());
   Print("   Signaux de vente activés: ", signalManager.IsSellSignalsEnabled());
}

//+------------------------------------------------------------------+
//| Exemple de configuration dynamique des signaux                  |
//+------------------------------------------------------------------+
void ExampleDynamicSignalConfiguration()
{
   // Simuler un changement de configuration selon les conditions du marché
   SwingAnalyzer swingAnalyzer("GBPUSD", PERIOD_H1, 54321, 50);
   SymbolStatus statusManager("GBPUSD", 54321, PERIOD_H1);
   
   SignalDetectionManager signalManager(
      "GBPUSD",
      PERIOD_H1,
      STRATEGY_REVERSION,
      &swingAnalyzer,
      &statusManager
   );
   
   // Configuration selon la volatilité (exemple)
   double atr = 0; // Calculer l'ATR ici
   
   if(atr > 0.01) // Marché très volatil
   {
      // Désactiver les signaux d'achat en cas de forte volatilité
      signalManager.EnableBuySignals(false);
      Print("⚠️ Signaux d'achat désactivés - Volatilité élevée");
   }
   else
   {
      // Réactiver tous les signaux
      signalManager.EnableBuySignals(true);
      signalManager.EnableSellSignals(true);
      Print("✅ Tous les signaux activés");
   }
   
   // Vérifier la configuration actuelle
   Print("🔧 Configuration dynamique appliquée:");
   Print("   Achat: ", signalManager.IsBuySignalsEnabled() ? "ACTIF" : "INACTIF");
   Print("   Vente: ", signalManager.IsSellSignalsEnabled() ? "ACTIF" : "INACTIF");
}
