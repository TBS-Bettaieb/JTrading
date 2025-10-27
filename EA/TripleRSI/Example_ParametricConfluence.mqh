//+------------------------------------------------------------------+
//|                                    Example_ParametricConfluence.mqh |
//|                   Exemple d'utilisation des Confluences Paramétrables |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier dans votre EA                             |
//| 2. Utilisez les méthodes de confluence paramétrables            |
//| 3. Configurez selon vos besoins avec les modes prédéfinis       |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - Configuration automatique selon le symbole                    |
//| - Configuration personnalisée                                   |
//| - Test des différents modes                                     |
//+------------------------------------------------------------------+
#property strict

#include "../Logic/ConfluenceFilters.mqh"

//+------------------------------------------------------------------+
//| Exemple d'utilisation des confluences paramétrables            |
//+------------------------------------------------------------------+
class CParametricConfluenceExample
{
public:
   //--- Exemple de configuration automatique selon le symbole
   static void SetupAutomaticConfiguration(string symbol)
   {
      Print("=== CONFIGURATION AUTOMATIQUE ===");
      Print("Symbol: ", symbol);
      
      if(StringFind(symbol, "US100") >= 0 || StringFind(symbol, "US30") >= 0)
      {
         // Configuration scalping pour indices
         Print("Detected INDICES symbol - Setting SCALPING mode");
         ConfluenceFilters::SetScalpingMode(symbol);
      }
      else if(StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "GBPUSD") >= 0)
      {
         // Configuration swing pour forex
         Print("Detected FOREX symbol - Setting SWING mode");
         ConfluenceFilters::SetSwingMode(symbol);
      }
      else if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0)
      {
         // Configuration conservative pour crypto
         Print("Detected CRYPTO symbol - Setting CONSERVATIVE mode");
         ConfluenceFilters::SetConservativeMode(symbol);
      }
      else
      {
         // Configuration par défaut
         Print("Unknown symbol - Setting CONSERVATIVE mode");
         ConfluenceFilters::SetConservativeMode(symbol);
      }
      
      // Afficher la configuration appliquée
      string configInfo = ConfluenceFilters::GetConfigInfo();
      Print(configInfo);
   }
   
   //--- Exemple de configuration personnalisée
   static void SetupCustomConfiguration()
   {
      Print("=== CONFIGURATION PERSONNALISÉE ===");
      
      // Configuration très stricte pour trading haute fréquence
      ConfluenceConfig customConfig;
      
      // Score très strict
      customConfig.minConfluenceScore = 5;
      customConfig.maxConfluenceScore = 6;
      customConfig.useStrictMode = true;
      
      // Volume très strict
      customConfig.enableVolumeFilter = true;
      customConfig.minVolumeMultiplier = 2.0;
      customConfig.volumePeriods = 10;
      
      // EMA200 très strict
      customConfig.enableEMA200Filter = true;
      customConfig.ema200Tolerance = 1.0;
      
      // MACD avec croisement
      customConfig.enableMACDFilter = true;
      customConfig.useMACDCrossover = true;
      customConfig.useMACDState = false;
      customConfig.macdFastPeriod = 5;
      customConfig.macdSlowPeriod = 13;
      customConfig.macdSignalPeriod = 3;
      
      // Stochastique strict
      customConfig.enableStochasticFilter = true;
      customConfig.stochOversoldLevel = 10;
      customConfig.stochOverboughtLevel = 90;
      
      // Multi-timeframe H1 avec tendance avancée
      customConfig.enableMultiTimeframe = true;
      customConfig.higherTimeframe = PERIOD_H1;
      customConfig.useAdvancedTrend = true;
      
      // Niveaux psychologiques
      customConfig.enablePsychologicalLevels = true;
      customConfig.psychologicalStep = 100.0;
      customConfig.psychologicalTolerance = 2.0;
      
      customConfig.presetMode = "CUSTOM_HIGH_FREQUENCY";
      customConfig.symbolType = "INDICES";
      
      // Appliquer la configuration
      ConfluenceFilters::SetConfluenceConfig(customConfig);
      
      // Valider et afficher
      if(customConfig.Validate())
      {
         customConfig.PrintConfig();
      }
      else
      {
         Print("❌ Configuration personnalisée invalide");
      }
   }
   
   //--- Exemple de test des différents modes
   static void TestAllModes(string symbol)
   {
      Print("=== TEST DE TOUS LES MODES ===");
      Print("Symbol: ", symbol);
      
      // Test mode SCALPING
      Print("\n--- MODE SCALPING ---");
      ConfluenceFilters::SetScalpingMode(symbol);
      TestConfluence(symbol, "SCALPING");
      
      // Test mode SWING
      Print("\n--- MODE SWING ---");
      ConfluenceFilters::SetSwingMode(symbol);
      TestConfluence(symbol, "SWING");
      
      // Test mode CONSERVATIVE
      Print("\n--- MODE CONSERVATIVE ---");
      ConfluenceFilters::SetConservativeMode(symbol);
      TestConfluence(symbol, "CONSERVATIVE");
      
      // Test mode AGGRESSIVE
      Print("\n--- MODE AGGRESSIVE ---");
      ConfluenceFilters::SetAggressiveMode(symbol);
      TestConfluence(symbol, "AGGRESSIVE");
   }
   
   //--- Exemple de test de confluence
   static void TestConfluence(string symbol, string mode)
   {
      ENUM_TIMEFRAMES timeframe = PERIOD_M5;
      int confluenceScore = 0;
      
      // Test signal BUY
      bool buyOK = ConfluenceFilters::CheckParametricConfluence(symbol, timeframe, true, confluenceScore);
      Print("BUY Signal - Score: ", IntegerToString(confluenceScore), ", Valid: ", (buyOK ? "YES" : "NO"));
      
      // Test signal SELL
      bool sellOK = ConfluenceFilters::CheckParametricConfluence(symbol, timeframe, false, confluenceScore);
      Print("SELL Signal - Score: ", IntegerToString(confluenceScore), ", Valid: ", (sellOK ? "YES" : "NO"));
      
      // Afficher configuration
      ConfluenceConfig config = ConfluenceFilters::GetConfluenceConfig();
      Print("Mode: ", config.presetMode, " | Min Score: ", IntegerToString(config.minConfluenceScore), 
            "/", IntegerToString(config.CalculateMaxScore()));
   }
   
   //--- Exemple d'intégration dans TripleRSITrader
   static bool ProcessTripleRSISignalWithParametricConfluence(string symbol, ENUM_TIMEFRAMES timeframe, 
                                                            double rsi1, double rsi2, double rsi3, bool isBuy)
   {
      // 1. Vérifier signal Triple RSI de base
      bool tripleRSISignal = false;
      if(isBuy)
      {
         tripleRSISignal = (rsi1 > 30 && rsi2 > 30 && rsi3 > 30);
      }
      else
      {
         tripleRSISignal = (rsi1 < 70 && rsi2 < 70 && rsi3 < 70);
      }
      
      if(!tripleRSISignal)
      {
         Print("❌ Triple RSI signal not valid");
         return false;
      }
      
      // 2. Valider confluences paramétrables
      int confluenceScore = 0;
      bool confluenceOK = ConfluenceFilters::CheckParametricConfluence(symbol, timeframe, isBuy, confluenceScore);
      
      if(confluenceOK)
      {
         // Obtenir configuration pour affichage
         ConfluenceConfig config = ConfluenceFilters::GetConfluenceConfig();
         
         Print("✅ SIGNAL VALIDÉ - Triple RSI + Confluences OK");
         Print("   Mode: ", config.presetMode);
         Print("   Score: ", IntegerToString(confluenceScore), "/", IntegerToString(config.CalculateMaxScore()));
         Print("   Symbol: ", symbol);
         Print("   Signal: ", (isBuy ? "BUY" : "SELL"));
         Print("   RSI: ", DoubleToString(rsi1, 1), "/", DoubleToString(rsi2, 1), "/", DoubleToString(rsi3, 1));
         
         return true;
      }
      else
      {
         ConfluenceConfig config = ConfluenceFilters::GetConfluenceConfig();
         Print("❌ SIGNAL REJETÉ - Confluences insuffisantes");
         Print("   Score: ", IntegerToString(confluenceScore), "/", IntegerToString(config.CalculateMaxScore()));
         Print("   Required: ", IntegerToString(config.minConfluenceScore));
         
         return false;
      }
   }
   
   //--- Exemple de configuration selon le timeframe
   static void SetupConfigurationByTimeframe(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      Print("=== CONFIGURATION PAR TIMEFRAME ===");
      Print("Symbol: ", symbol, " | Timeframe: ", EnumToString(timeframe));
      
      if(timeframe == PERIOD_M1 || timeframe == PERIOD_M5)
      {
         // Scalping - configuration stricte
         Print("Scalping timeframe detected - Setting SCALPING mode");
         ConfluenceFilters::SetScalpingMode(symbol);
      }
      else if(timeframe == PERIOD_M15 || timeframe == PERIOD_M30)
      {
         // Day trading - configuration équilibrée
         Print("Day trading timeframe detected - Setting SWING mode");
         ConfluenceFilters::SetSwingMode(symbol);
      }
      else if(timeframe == PERIOD_H1 || timeframe == PERIOD_H4)
      {
         // Swing trading - configuration flexible
         Print("Swing trading timeframe detected - Setting CONSERVATIVE mode");
         ConfluenceFilters::SetConservativeMode(symbol);
      }
      else
      {
         // Timeframe long - configuration très flexible
         Print("Long-term timeframe detected - Setting AGGRESSIVE mode");
         ConfluenceFilters::SetAggressiveMode(symbol);
      }
      
      // Afficher la configuration
      string configInfo = ConfluenceFilters::GetConfigInfo();
      Print(configInfo);
   }
   
   //--- Exemple de configuration dynamique selon les conditions de marché
   static void SetupDynamicConfiguration(string symbol, double volatility, double volume)
   {
      Print("=== CONFIGURATION DYNAMIQUE ===");
      Print("Symbol: ", symbol);
      Print("Volatility: ", DoubleToString(volatility, 2));
      Print("Volume: ", DoubleToString(volume, 2));
      
      if(volatility > 2.0 && volume > 1.5)
      {
         // Marché très volatil et volume élevé - mode strict
         Print("High volatility + High volume - Setting CONSERVATIVE mode");
         ConfluenceFilters::SetConservativeMode(symbol);
      }
      else if(volatility < 0.5 && volume < 0.8)
      {
         // Marché calme et volume faible - mode agressif
         Print("Low volatility + Low volume - Setting AGGRESSIVE mode");
         ConfluenceFilters::SetAggressiveMode(symbol);
      }
      else if(volatility > 1.0)
      {
         // Marché volatil - mode scalping
         Print("High volatility - Setting SCALPING mode");
         ConfluenceFilters::SetScalpingMode(symbol);
      }
      else
      {
         // Conditions normales - mode swing
         Print("Normal conditions - Setting SWING mode");
         ConfluenceFilters::SetSwingMode(symbol);
      }
      
      // Afficher la configuration
      string configInfo = ConfluenceFilters::GetConfigInfo();
      Print(configInfo);
   }
};

//+------------------------------------------------------------------+
//| Fonction d'exemple pour tester le système paramétrable         |
//+------------------------------------------------------------------+
void TestParametricConfluenceSystem()
{
   Print("=== TEST SYSTÈME CONFLUENCE PARAMÉTRABLE ===");
   
   string testSymbols[] = {"US100", "EURUSD", "BTCUSD"};
   
   for(int i = 0; i < ArraySize(testSymbols); i++)
   {
      Print("\n--- TEST SYMBOLE: ", testSymbols[i], " ---");
      
      // Configuration automatique
      CParametricConfluenceExample::SetupAutomaticConfiguration(testSymbols[i]);
      
      // Test des modes
      CParametricConfluenceExample::TestAllModes(testSymbols[i]);
      
      // Test de confluence
      bool result = CParametricConfluenceExample::ProcessTripleRSISignalWithParametricConfluence(
         testSymbols[i], PERIOD_M5, 35, 32, 28, true);
      
      Print("Test result: ", (result ? "SUCCESS" : "FAILED"));
   }
   
   // Test configuration personnalisée
   Print("\n--- TEST CONFIGURATION PERSONNALISÉE ---");
   CParametricConfluenceExample::SetupCustomConfiguration();
   
   // Test configuration par timeframe
   Print("\n--- TEST CONFIGURATION PAR TIMEFRAME ---");
   CParametricConfluenceExample::SetupConfigurationByTimeframe("US100", PERIOD_M5);
   
   // Test configuration dynamique
   Print("\n--- TEST CONFIGURATION DYNAMIQUE ---");
   CParametricConfluenceExample::SetupDynamicConfiguration("US100", 1.5, 1.2);
   
   Print("=== FIN TEST SYSTÈME PARAMÉTRABLE ===");
}
