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

// Helpers pour arrondir au pas de cotation (tick)
double CeilToTick(double price, double tick)
{
   return MathCeil(price / tick) * tick;
}

double FloorToTick(double price, double tick)
{
   return MathFloor(price / tick) * tick;
}

double RoundToTick(double price, double tick)
{
   return MathRound(price / tick) * tick;
}

// Calcule la distance minimale de stop en PRIX alignée sur la grille de cotation
double MinStopDistPrice(string symbol, int minPointsFallback)
{
   double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int    stopsLvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL); // en points
   double byBroker = stopsLvl > 0 ? stopsLvl * point : 0.0;
   double byUser   = minPointsFallback * point;
   // distance mini en PRIX puis alignée à la grille de cotation
   return CeilToTick(MathMax(byBroker, byUser), tickSize);
}

// Calcule l'Average True Range (ATR) avec gestion robuste des erreurs
double iATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift)
{
   int handle = iATR(symbol, timeframe, period);
   if(handle == INVALID_HANDLE) return 0.0;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(handle, 0, shift, 1, atr) <= 0) {
      IndicatorRelease(handle);
      return 0.0;
   }
   
   double result = atr[0];
   IndicatorRelease(handle);
   return result;
}

// Calcule les niveaux de SL et TP basés sur les plus hauts/plus bas des X dernières bougies
// Version robuste : combine swing et ATR, aligne strictement sur grille de cotation
// Résout : confusion point/tick, stops level, manque de données, normalisation
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
   int minPointsFallback = 1000, // distance mini si broker ne donne rien
   double atrMultiplier = 2.0,   // Multiplicateur ATR pour SL (défaut 2.0)
   int atrPeriod = 14            // Période ATR (défaut 14)
)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) return false;
   if(currentPrice <= 0.0) currentPrice = isBuy ? tick.ask : tick.bid;

   const int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double tickSz = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0.0) return false;

   // Charger les données nécessaires une fois
   int need = MathMax(slPeriod, tpPeriod) + 2; // marge
   double lows[], highs[];
   if(CopyLow(symbol, timeframe, 0, need, lows)  < need) return false;
   if(CopyHigh(symbol, timeframe, 0, need, highs) < need) return false;

   // Vérifier assez de barres fermées
   if(Bars(symbol, timeframe) < need) return false;

   // Extrêmes "swing" sur barres 1..N (on ignore la 0)
   int loShift = ArrayMinimum(lows, 1, slPeriod);
   int hiShift = ArrayMaximum(highs, 1, slPeriod);
   double swingLow  = (loShift >= 1) ? lows[loShift] : 0.0;
   double swingHigh = (hiShift >= 1) ? highs[hiShift] : 0.0;

   // ATR floor
   double atr = iATR(symbol, timeframe, atrPeriod, 1);
   if(atr <= 0.0) atr = 0.0; // on reste tolérant, mais on garde minDist

   // Distance minimale broker alignée sur tick
   double minDist = MinStopDistPrice(symbol, minPointsFallback);

   // --------- SL
   double slBySwing, slByAtr, slCandidate;

   if(isBuy)
   {
      // swing peut être nul si data manquante
      slBySwing = (swingLow > 0.0 && swingLow < currentPrice) ? swingLow : currentPrice - 10.0 * minDist;
      slByAtr   = (atr > 0.0) ? (currentPrice - atrMultiplier * atr) : (currentPrice - minDist);

      // garder le PLUS LOIN du prix parmi les deux (plus protecteur pour un buy = plus bas)
      slCandidate = MathMin(slBySwing, slByAtr);

      // appliquer minDist
      if(currentPrice - slCandidate < minDist) slCandidate = currentPrice - minDist;

      // aligner à la grille
      outSL = FloorToTick(slCandidate, tickSz);
      if(outSL >= currentPrice) outSL = currentPrice - CeilToTick(minDist, tickSz);
   }
   else
   {
      slBySwing = (swingHigh > 0.0 && swingHigh > currentPrice) ? swingHigh : currentPrice + 10.0 * minDist;
      slByAtr   = (atr > 0.0) ? (currentPrice + atrMultiplier * atr) : (currentPrice + minDist);

      // pour un sell, garder le PLUS LOIN au-dessus du prix
      slCandidate = MathMax(slBySwing, slByAtr);

      if(slCandidate - currentPrice < minDist) slCandidate = currentPrice + minDist;

      outSL = CeilToTick(slCandidate, tickSz);
      if(outSL <= currentPrice) outSL = currentPrice + CeilToTick(minDist, tickSz);
   }
   outSL = NormalizeDouble(outSL, digits);

   // --------- TP
   // 1) cible swing opposée si valide, sinon RR fallback
   double tpSwing, tpRR, slDist = MathAbs(currentPrice - outSL);

   if(isBuy)
   {
      int hi2 = ArrayMaximum(highs, 1, tpPeriod);
      tpSwing = (hi2 >= 1) ? highs[hi2] : 0.0;

      if(tpSwing <= currentPrice) tpSwing = 0.0; // invalide
      tpRR = currentPrice + rrFallback * slDist;

      double tpRaw = (tpSwing > 0.0) ? MathMax(tpSwing, currentPrice + minDist) : tpRR;
      outTP = CeilToTick(tpRaw, tickSz);
   }
   else
   {
      int lo2 = ArrayMinimum(lows, 1, tpPeriod);
      tpSwing = (lo2 >= 1) ? lows[lo2] : 0.0;

      if(tpSwing >= currentPrice) tpSwing = 0.0;
      tpRR = currentPrice - rrFallback * slDist;

      double tpRaw = (tpSwing > 0.0) ? MathMin(tpSwing, currentPrice - minDist) : tpRR;
      outTP = FloorToTick(tpRaw, tickSz);
   }
   outTP = NormalizeDouble(outTP, digits);

   // Sécurité: TP doit être au moins à minDist du prix et ≠ SL
   if(isBuy)
   {
      if(outTP - currentPrice < minDist) outTP = CeilToTick(currentPrice + minDist, tickSz);
   }
   else
   {
      if(currentPrice - outTP < minDist) outTP = FloorToTick(currentPrice - minDist, tickSz);
   }
   if(MathAbs(outTP - outSL) < 2.0 * tickSz)
   {
      outTP = isBuy ? CeilToTick(outSL + rrFallback * MathMax(slDist, minDist), tickSz)
                    : FloorToTick(outSL - rrFallback * MathMax(slDist, minDist), tickSz);
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
