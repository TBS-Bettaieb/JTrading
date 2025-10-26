//+------------------------------------------------------------------+
//|                                          JT_MoneyManagement.mqh |
//|                        Fonctions de money management (MT5)       |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+

// Détermine le nombre de décimales pour le volume
int GetVolumeDigits(string symbol) {
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) return 2; // Default to 2 digits if step is invalid
   
   int digits = 0;
   double s = step;
   // Increase precision until the scaled step becomes an integer (cap at 8)
   while(digits < 8) {
      double rounded = MathRound(s);
      if(MathAbs(s - rounded) <= 1e-9) break;
      s *= 10.0;
      digits++;
   }
   
   return digits;
}

// Normalise le volume selon les limites du symbole
double NormalizeVolume(string symbol, double volume) {
   double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // S'assurer que le volume est dans les limites
   volume = MathMax(minVolume, MathMin(maxVolume, volume));
   
   // Arrondir au pas de volume
   volume = MathFloor(volume / stepVolume) * stepVolume;
   
   // Normaliser à la précision correcte
   int digits = GetVolumeDigits(symbol);
   return NormalizeDouble(volume, digits);
}

// Calcule le volume basé sur le risque
double CalculateRiskBasedVolume(
   string symbol,
   double riskPercent,
   double stopLossPoints,
   bool useBalance = false  // false = Equity (défaut), true = Balance
) {
   if(stopLossPoints <= 0.0) return 0.01; // Volume minimum par défaut
   
   // Calculer le montant à risquer
   double balance = useBalance ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = balance * (riskPercent / 100.0);
   
   // Obtenir les informations du symbole
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculer le nombre de ticks par point
   double ticksPerPoint = point / tickSize;
   if(ticksPerPoint <= 0) ticksPerPoint = 1.0;
   
   // Calculer la valeur par point par lot
   double valuePerPointPerLot = tickValue * ticksPerPoint;
   
   // Calculer la valeur du stop loss par lot
   double stopLossValuePerLot = stopLossPoints * valuePerPointPerLot;
   
   // Calculer le volume
   double volume = 0.0;
   if(stopLossValuePerLot > 0.0) {
      volume = riskAmount / stopLossValuePerLot;
   }
   
   // Normaliser le volume
   return NormalizeVolume(symbol, volume);
}

// Convertit une distance en prix en points
double PriceToPoints(string symbol, double priceDistance) {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   return priceDistance / point;
}

// Calcule le stop loss basé sur l'ATR
double CalculateATRStopLoss(
   double atrValue,
   double multiplier,
   bool isBuy,
   double entryPrice,
   string symbol
) {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double atrDistance = atrValue * multiplier;
   
   if(isBuy) {
      return entryPrice - atrDistance;
   } else {
      return entryPrice + atrDistance;
   }
}

// Calcule le take profit basé sur le ratio risque/récompense
double CalculateRRTakeProfit(
   double entryPrice,
   double stopLoss,
   double rrRatio,
   bool isBuy
) {
   double risk = MathAbs(entryPrice - stopLoss);
   double reward = risk * rrRatio;
   
   if(isBuy) {
      return entryPrice + reward;
   } else {
      return entryPrice - reward;
   }
}
