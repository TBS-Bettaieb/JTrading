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

// Calcule les niveaux de SL et TP basés sur les plus hauts/plus bas des X dernières bougies
bool CalculateSwingSLTP(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   bool isBuy,                // true pour achat, false pour vente
   int slPeriod,              // Nombre de bougies pour calculer le SL
   int tpPeriod,              // Nombre de bougies pour calculer le TP
   double &outSL,             // Valeur du SL calculée (retour par référence)
   double &outTP,             // Valeur du TP calculée (retour par référence)
   double currentPrice = 0    // Prix actuel, si 0 utilise Ask/Bid
) {
   // Tableau de bougies pour le calcul
   MqlRates rates[];
   int maxPeriod = MathMax(slPeriod, tpPeriod);
   
   // Récupérer les données des bougies
   if(CopyRates(symbol, timeframe, 0, maxPeriod + 1, rates) < maxPeriod + 1) {
      LogError("Erreur lors de la récupération des données de bougies pour calculer SL/TP");
      return false;
   }
   
   ArraySetAsSeries(rates, true); // 0 = bougie actuelle, 1 = bougie précédente, etc.
   
   // Déterminer le prix courant si non fourni
   if(currentPrice <= 0) {
      currentPrice = isBuy ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   }
   
   // Calculer le SL en fonction de la direction
   if(isBuy) {
      // Pour un achat, le SL est le plus bas des slPeriod dernières bougies
      outSL = rates[1].low;  // Commencer par la bougie précédente
      for(int i=2; i <= slPeriod; i++) {
         outSL = MathMin(outSL, rates[i].low);
      }
      
      // Pour un achat, le TP est le plus haut des tpPeriod dernières bougies
      outTP = rates[1].high;
      for(int i=2; i <= tpPeriod; i++) {
         outTP = MathMax(outTP, rates[i].high);
      }
      
      // Vérifier si le SL est trop proche (moins de 10 points)
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double minDistance = 10 * point;
      if(currentPrice - outSL < minDistance) {
         outSL = currentPrice - minDistance;
      }
      
      // Si le TP n'est pas au-dessus du prix actuel, on cherche le prochain plus haut
      if(outTP <= currentPrice) {
         // On étend la recherche
         int extendedPeriod = tpPeriod * 2;
         if(CopyRates(symbol, timeframe, 0, extendedPeriod + 1, rates) >= extendedPeriod + 1) {
            ArraySetAsSeries(rates, true);
            for(int i=tpPeriod+1; i <= extendedPeriod; i++) {
               double high = rates[i].high;
               if(high > currentPrice) {
                  outTP = high;
                  break;
               }
            }
            
            // Si toujours pas de TP valide, on utilise une valeur par défaut
            if(outTP <= currentPrice) {
               outTP = currentPrice + (currentPrice - outSL) * 1.5; // RR par défaut de 1.5
            }
         }
      }
   } else {
      // Pour une vente, le SL est le plus haut des slPeriod dernières bougies
      outSL = rates[1].high;
      for(int i=2; i <= slPeriod; i++) {
         outSL = MathMax(outSL, rates[i].high);
      }
      
      // Pour une vente, le TP est le plus bas des tpPeriod dernières bougies
      outTP = rates[1].low;
      for(int i=2; i <= tpPeriod; i++) {
         outTP = MathMin(outTP, rates[i].low);
      }
      
      // Vérifier si le SL est trop proche (moins de 10 points)
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double minDistance = 10 * point;
      if(outSL - currentPrice < minDistance) {
         outSL = currentPrice + minDistance;
      }
      
      // Si le TP n'est pas en-dessous du prix actuel, on cherche le prochain plus bas
      if(outTP >= currentPrice) {
         // On étend la recherche
         int extendedPeriod = tpPeriod * 2;
         if(CopyRates(symbol, timeframe, 0, extendedPeriod + 1, rates) >= extendedPeriod + 1) {
            ArraySetAsSeries(rates, true);
            for(int i=tpPeriod+1; i <= extendedPeriod; i++) {
               double low = rates[i].low;
               if(low < currentPrice) {
                  outTP = low;
                  break;
               }
            }
            
            // Si toujours pas de TP valide, on utilise une valeur par défaut
            if(outTP >= currentPrice) {
               outTP = currentPrice - (outSL - currentPrice) * 1.5; // RR par défaut de 1.5
            }
         }
      }
   }
   
   // Arrondir les valeurs au nombre de décimales du symbole
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   outSL = NormalizeDouble(outSL, digits);
   outTP = NormalizeDouble(outTP, digits);
   
   return true;
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
