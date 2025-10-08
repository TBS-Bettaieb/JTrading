//+------------------------------------------------------------------+
//|                                                   JT_Utils.mqh |
//|                              Fonctions utilitaires (MT5)        |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+

// Structure pour stocker les données des bougies
struct CandleData {
   double open;
   double high;
   double low;
   double close;
   datetime time;
   long volume;
   bool isGreen;
   bool isRed;
};

// Récupère les données des bougies
bool GetCandleData(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int count,
   CandleData &candles[]
) {
   MqlRates rates[];
   
   if(CopyRates(symbol, timeframe, 0, count, rates) < count) {
      Print("Erreur lors de la récupération des données de bougies");
      return false;
   }
   
   ArraySetAsSeries(rates, true);
   ArrayResize(candles, count);
   
   for(int i=0; i<count; i++) {
      candles[i].open = rates[i].open;
      candles[i].high = rates[i].high;
      candles[i].low = rates[i].low;
      candles[i].close = rates[i].close;
      candles[i].time = rates[i].time;
      candles[i].volume = rates[i].tick_volume;
      candles[i].isGreen = rates[i].close > rates[i].open;
      candles[i].isRed = rates[i].open > rates[i].close;
   }
   
   return true;
}

// Vérifie si une bougie est à l'extérieur d'une bande
bool IsCandleOutsideBand(
   const CandleData &candle,
   double bandLevel,
   bool isUpperBand,
   double paddingPoints,
   bool bodyOnly
) {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double padding = paddingPoints * point;
   
   if(isUpperBand) {
      if(bodyOnly) {
         // Vérifier si le corps est au-dessus de la bande
         double bodyLow = MathMin(candle.open, candle.close);
         return bodyLow >= bandLevel + padding;
      } else {
         // Vérifier si le haut de la bougie est au-dessus de la bande
         return candle.high >= bandLevel + padding;
      }
   } else {
      if(bodyOnly) {
         // Vérifier si le corps est en dessous de la bande
         double bodyHigh = MathMax(candle.open, candle.close);
         return bodyHigh <= bandLevel - padding;
      } else {
         // Vérifier si le bas de la bougie est en dessous de la bande
         return candle.low <= bandLevel - padding;
      }
   }
}

// Récupère le spread actuel en points
int GetCurrentSpreadPoints(string symbol) {
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   return (int)((ask - bid) / point);
}

// Formatte un prix pour l'affichage
string FormatPrice(double price, string symbol) {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return DoubleToString(price, digits);
}

// Journalisation avec préfixe et horodatage
void LogMessage(string message, string prefix = "INFO") {
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   Print("[", timestamp, "][", prefix, "] ", message);
}

// Journalisation des erreurs
void LogError(string message, int errorCode = 0) {
   string errorMessage = message;
   if(errorCode != 0) {
      errorMessage += " - Erreur #" + IntegerToString(errorCode) + ": " + ErrorDescription(errorCode);
   }
   LogMessage(errorMessage, "ERROR");
}

// Récupère la description d'une erreur
string ErrorDescription(int errorCode) {
   switch(errorCode) {
      case ERR_SUCCESS:                   return "L'opération a réussi";
      case ERR_INTERNAL_ERROR:            return "Erreur interne inattendue";
      case ERR_WRONG_INTERNAL_PARAMETER:  return "Paramètre interne incorrect";
      case ERR_INVALID_PARAMETER:         return "Paramètre incorrect";
      case ERR_NOT_ENOUGH_MEMORY:         return "Pas assez de mémoire";
      case ERR_STRUCT_WITHOBJECTS_ORCLASS:return "Structure contient des objets de chaînes et/ou de classes et/ou de structures";
      case ERR_INVALID_ARRAY:             return "Tableau invalide";
      case ERR_ARRAY_RESIZE_ERROR:        return "Erreur de redimensionnement du tableau";
      case ERR_STRING_RESIZE_ERROR:       return "Erreur de redimensionnement de chaîne";
      case ERR_NOTINITIALIZED_STRING:     return "Chaîne non initialisée";
      case ERR_INVALID_DATETIME:          return "DateTime invalide";
      case ERR_ARRAY_BAD_SIZE:            return "Taille de tableau incorrecte";
      case ERR_INVALID_POINTER:           return "Pointeur invalide";
      case ERR_INVALID_POINTER_TYPE:      return "Type de pointeur invalide";
     // case ERR_TRADE_ERROR:               return "Erreur de trading générique";
      // Ajoutez d'autres codes d'erreur au besoin
      default:                            return "Erreur inconnue";
   }
}
