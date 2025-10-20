//+------------------------------------------------------------------+
//|                                              TradingUtils.mqh     |
//|                         Fonctions utilitaires pour le trading     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Parser la liste des symboles depuis une string                  |
//+------------------------------------------------------------------+
int ParseSymbolsList(string symbolsList, string &symbolArray[])
{
   if(symbolsList == "" || symbolsList == " ")
   {
      ArrayResize(symbolArray, 0);
      return 0;
   }
   
   // Nettoyer la string (supprimer espaces, caractères spéciaux)
   StringReplace(symbolsList, " ", "");
   StringReplace(symbolsList, "\t", "");
   StringReplace(symbolsList, "\n", "");
   StringReplace(symbolsList, "\r", "");
   
   // Séparer par virgules
   string temp[];
   int count = StringSplit(symbolsList, ',', temp);
   
   if(count <= 0)
   {
      ArrayResize(symbolArray, 0);
      return 0;
   }
   
   // Redimensionner le tableau de sortie
   ArrayResize(symbolArray, count);
   
   // Copier et valider chaque symbole
   int validCount = 0;
   for(int i = 0; i < count; i++)
   {
      string symbol = temp[i];
      StringTrimLeft(symbol);
      StringTrimRight(symbol);
      
      if(symbol != "" && ValidateSymbol(symbol))
      {
         symbolArray[validCount] = symbol;
         validCount++;
      }
      else if(symbol != "")
      {
         Print("⚠️ Invalid or unavailable symbol: ", symbol);
      }
   }
   
   // Redimensionner le tableau final
   ArrayResize(symbolArray, validCount);
   
   return validCount;
}

//+------------------------------------------------------------------+
//| Valider qu'un symbole existe et est tradable                    |
//+------------------------------------------------------------------+
bool ValidateSymbol(string symbol)
{
   if(symbol == "") return false;
   
   // Vérifier si le symbole existe
   if(!SymbolSelect(symbol, true))
   {
      Print("⚠️ Symbol ", symbol, " not found in Market Watch");
      return false;
   }
   
   // Vérifier les propriétés de trading
   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE))
   {
      Print("⚠️ Symbol ", symbol, " is not tradeable");
      return false;
   }
   
   // Vérifier les spreads (éviter les spreads trop élevés)
   double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread > 50) // Spread > 5 pips pour la plupart des brokers
   {
      Print("⚠️ Symbol ", symbol, " has high spread: ", spread, " points");
      // Ne pas bloquer, juste avertir
   }
   
   // Vérifier la liquidité (volume)
   long volume = SymbolInfoInteger(symbol, SYMBOL_VOLUME);
   if((double)volume <= 0)
   {
      Print("⚠️ Symbol ", symbol, " has no volume data");
      // Ne pas bloquer, juste avertir
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obtenir tous les symboles du Market Watch                       |
//+------------------------------------------------------------------+
int GetSymbolsFromMarketWatch(string &symbolArray[])
{
   int total = SymbolsTotal(true); // true = seulement Market Watch
   
   if(total <= 0)
   {
      ArrayResize(symbolArray, 0);
      return 0;
   }
   
   ArrayResize(symbolArray, total);
   
   int validCount = 0;
   for(int i = 0; i < total; i++)
   {
      string symbol = SymbolName(i, true);
      
      if(ValidateSymbol(symbol))
      {
         symbolArray[validCount] = symbol;
         validCount++;
      }
   }
   
   ArrayResize(symbolArray, validCount);
   
   return validCount;
}



//+------------------------------------------------------------------+
//| Fonction helper pour obtenir un hash du timeframe               |
//+------------------------------------------------------------------+
int GetTimeframeHash(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 1;
      case PERIOD_M5:  return 5;
      case PERIOD_M15: return 15;
      case PERIOD_M30: return 30;
      case PERIOD_H1:  return 10;
      case PERIOD_H4:  return 14;
      case PERIOD_D1:  return 20;
      case PERIOD_W1:  return 25;
      case PERIOD_MN1: return 30;
      default:         return 0;
   }
}

//+------------------------------------------------------------------+
//| Fonction helper pour obtenir un hash du nom de stratégie        |
//+------------------------------------------------------------------+
int GetStrategyHash(string strategyName)
{
   if(strategyName == "" || strategyName == NULL)
      return 0;
   
   // Calculer un hash simple basé sur les caractères
   int hash = 0;
   int len = StringLen(strategyName);
   
   for(int i = 0; i < len && i < 5; i++)
   {
      hash += StringGetCharacter(strategyName, i);
   }
   
   // Limiter à 0-99
   return hash % 100;
}

//+------------------------------------------------------------------+
//| Calculer le risque par symbole (divisé par le nombre total)     |
//+------------------------------------------------------------------+
double CalculateRiskPerSymbol(double totalRiskPercent, int symbolCount)
{
   if(symbolCount <= 0) return 0;
   
   // Diviser le risque total par le nombre de symboles
   double riskPerSymbol = totalRiskPercent / symbolCount;
   
   // Limiter à un minimum de 0.01% et maximum de 5%
   riskPerSymbol = MathMax(0.01, riskPerSymbol);
   riskPerSymbol = MathMin(5.0, riskPerSymbol);
   
   return riskPerSymbol;
}

//+------------------------------------------------------------------+
//| Vérifier la disponibilité des données historiques               |
//+------------------------------------------------------------------+
bool CheckHistoricalData(string symbol, ENUM_TIMEFRAMES timeframe, int barsRequired = 200)
{
   int bars = Bars(symbol, timeframe);
   
   if(bars < barsRequired)
   {
      Print("⚠️ Insufficient historical data for ", symbol, " | Bars: ", bars, " | Required: ", barsRequired);
      return false;
   }
   
   // Vérifier la qualité des données (pas de gaps trop importants)
   datetime lastBar = iTime(symbol, timeframe, 0);
   datetime previousBar = iTime(symbol, timeframe, 1);
   
   if(lastBar == 0 || previousBar == 0)
   {
      Print("⚠️ Invalid time data for ", symbol);
      return false;
   }
   
   int periodSeconds = PeriodSeconds(timeframe);
   long timeDiff = lastBar - previousBar;
   
   // Tolérance de 10% sur la différence de temps
   if(timeDiff > periodSeconds * 1.1 || timeDiff < periodSeconds * 0.9)
   {
      Print("⚠️ Irregular bar timing for ", symbol, " | Expected: ", periodSeconds, " | Actual: ", timeDiff);
      // Ne pas bloquer, juste avertir
   }
   
   return true;
}
