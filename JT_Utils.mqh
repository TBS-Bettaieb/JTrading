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
// Version optimisée utilisant iLowest/iHighest (O(1) au lieu de O(N))
bool CalculateSwingSLTP(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   bool isBuy,                // true pour achat, false pour vente
   int slPeriod,              // Nombre de bougies pour calculer le SL
   int tpPeriod,              // Nombre de bougies pour calculer le TP
   double &outSL,             // Valeur du SL calculée (retour par référence)
   double &outTP,             // Valeur du TP calculée (retour par référence)
   double currentPrice = 0.0, // Prix actuel, si 0 utilise Ask/Bid
   double rrFallback = 1.5,   // RR si aucun TP valide
   int minPointsFallback = 400 // distance mini si broker ne donne rien
) {
   // Prix courant
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) return false;
   if(currentPrice <= 0.0) currentPrice = isBuy ? tick.ask : tick.bid;

   // Contraintes broker
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int stopsLvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL); // en points
   // distance minimale en prix
   double minDist = MathMax(minPointsFallback, stopsLvl) * point;

   // --- SL via extrême récent (on ignore la bougie 0)
   if(isBuy) {
      // Pour un achat, SL = plus bas des slPeriod dernières bougies
      int slShift = iLowest(symbol, timeframe, MODE_LOW, slPeriod, 1);
      if(slShift == -1) return false;
      outSL = iLow(symbol, timeframe, slShift);
      if(currentPrice - outSL < minDist) outSL = currentPrice - minDist;

      // TP = plus haut des tpPeriod dernières bougies
      int tpShift = iHighest(symbol, timeframe, MODE_HIGH, tpPeriod, 1);
      if(tpShift == -1) return false;
      outTP = iHigh(symbol, timeframe, tpShift);

      // Extension si TP ≤ prix
      if(outTP <= currentPrice) {
         int extShift = iHighest(symbol, timeframe, MODE_HIGH, tpPeriod*2, 1);
         if(extShift != -1) outTP = iHigh(symbol, timeframe, extShift);
         if(outTP <= currentPrice) outTP = currentPrice + (currentPrice - outSL) * rrFallback;
      }
   } else {
      // Pour une vente, SL = plus haut des slPeriod dernières bougies
      int slShift = iHighest(symbol, timeframe, MODE_HIGH, slPeriod, 1);
      if(slShift == -1) return false;
      outSL = iHigh(symbol, timeframe, slShift);
      if(outSL - currentPrice < minDist) outSL = currentPrice + minDist;

      // TP = plus bas des tpPeriod dernières bougies
      int tpShift = iLowest(symbol, timeframe, MODE_LOW, tpPeriod, 1);
      if(tpShift == -1) return false;
      outTP = iLow(symbol, timeframe, tpShift);

      // Extension si TP ≥ prix
      if(outTP >= currentPrice) {
         int extShift = iLowest(symbol, timeframe, MODE_LOW, tpPeriod*2, 1);
         if(extShift != -1) outTP = iLow(symbol, timeframe, extShift);
         if(outTP >= currentPrice) outTP = currentPrice - (outSL - currentPrice) * rrFallback;
      }
   }

   // Normalisation au tick et décimales
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Normaliser SL au tick
   outSL = MathRound(outSL / tickSize) * tickSize;
   outSL = NormalizeDouble(outSL, digits);
   
   // Normaliser TP au tick
   outTP = MathRound(outTP / tickSize) * tickSize;
   outTP = NormalizeDouble(outTP, digits);

   // Sécurité: éviter SL==TP
   if(MathAbs(outTP - outSL) < tickSize * 2) {
      outTP = isBuy ? outSL + rrFallback * minDist : outSL - rrFallback * minDist;
      // Re-normaliser TP
      outTP = MathRound(outTP / tickSize) * tickSize;
      outTP = NormalizeDouble(outTP, digits);
   }
   
   return true;
}

// Structure pour représenter une plage horaire
struct HourRange {
   int startHour;
   int endHour;
};

// Vérifie si l'heure actuelle est autorisée selon le format de plage horaire spécifié
// Exemple de formats: "8-10", "16", "8-10;16", "9-11;14-15;21-22"
bool IsHourAllowedCustom(string hourRangeStr) {
   if(hourRangeStr == "") return true; // Si vide, autorise toutes les heures
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentHour = dt.hour;
   
   // Séparer les différentes plages (séparées par des ";")
   string ranges[];
   int rangeCount = StringSplit(hourRangeStr, ';', ranges);
   
   for(int i = 0; i < rangeCount; i++) {
      string range = ranges[i];
      
      // Vérifier s'il s'agit d'une plage (contient "-") ou d'une heure unique
      int dashPos = StringFind(range, "-");
      
      if(dashPos > 0) {
         // Format plage (ex: "8-10")
         int startHour = (int)StringToInteger(StringSubstr(range, 0, dashPos));
         int endHour = (int)StringToInteger(StringSubstr(range, dashPos + 1));
         
         // Vérifier si l'heure actuelle est dans cette plage
         if(startHour < endHour) {
            // Plage normale (ex: 8-10)
            if(currentHour >= startHour && currentHour < endHour) {
               return true;
            }
         } else if(startHour > endHour) {
            // Plage qui traverse minuit (ex: 22-2)
            if(currentHour >= startHour || currentHour < endHour) {
               return true;
            }
         } else {
            // startHour == endHour, vérifier uniquement cette heure
            if(currentHour == startHour) {
               return true;
            }
         }
      } else {
         // Format heure unique (ex: "16")
         int hour = (int)StringToInteger(range);
         if(currentHour == hour) {
            return true;
         }
      }
   }
   
   // Si aucune plage ne correspond à l'heure actuelle
   return false;
}

// Fonction utilitaire pour extraire les plages horaires sous forme de structures
// Cette fonction est utile si vous avez besoin de stocker les plages pour utilisation future
bool ParseHourRanges(string hourRangeStr, HourRange &ranges[]) {
   if(hourRangeStr == "") {
      ArrayResize(ranges, 0);
      return true;
   }
   
   // Séparer les différentes plages (séparées par des ";")
   string rangeStrings[];
   int rangeCount = StringSplit(hourRangeStr, ';', rangeStrings);
   
   ArrayResize(ranges, rangeCount);
   
   for(int i = 0; i < rangeCount; i++) {
      string range = rangeStrings[i];
      
      // Vérifier s'il s'agit d'une plage (contient "-") ou d'une heure unique
      int dashPos = StringFind(range, "-");
      
      if(dashPos > 0) {
         // Format plage (ex: "8-10")
         ranges[i].startHour = (int)StringToInteger(StringSubstr(range, 0, dashPos));
         ranges[i].endHour = (int)StringToInteger(StringSubstr(range, dashPos + 1));
      } else {
         // Format heure unique (ex: "16")
         ranges[i].startHour = (int)StringToInteger(range);
         ranges[i].endHour = ranges[i].startHour + 1; // L'heure de fin est exclusive
      }
      
      // Validation basique des valeurs
      if(ranges[i].startHour < 0 || ranges[i].startHour > 23 || 
         ranges[i].endHour < 0 || ranges[i].endHour > 24) {
         LogError("Format de plage horaire invalide: " + range);
         return false;
      }
   }
   
   return true;
}

// Log de débogage pour les plages horaires
void LogHourRanges(HourRange &ranges[], string prefix = "HourRanges") {
   string rangesStr = "";
   for(int i = 0; i < ArraySize(ranges); i++) {
      if(i > 0) rangesStr += ", ";
      rangesStr += IntegerToString(ranges[i].startHour) + "-" + IntegerToString(ranges[i].endHour);
   }
   LogMessage(prefix + ": " + rangesStr);
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
