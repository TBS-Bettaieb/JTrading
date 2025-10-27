//+------------------------------------------------------------------+
//|                                        DynamicStopLossCalculator.mqh |
//|                    Calculateur automatique de Stop-Loss dynamique    |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "Logger.mqh"
#include "TradingEnums.mqh"

//+------------------------------------------------------------------+
//| PARAMÈTRES CONFIGURABLES - À MODIFIER SELON VOS BESOINS         |
//+------------------------------------------------------------------+
// Paramètres Swing Points
input int    SWING_LOOKBACK_PERIODS = 20;        // Périodes pour détecter les swings
input int    SWING_MIN_DISTANCE_POINTS = 30;     // Distance minimale swing (points)
input double SWING_VOLUME_THRESHOLD = 1.2;      // Seuil volume pour validation swing
input int    SWING_BUFFER_POINTS = 5;            // Buffer de sécurité swing (points)

// Paramètres ATR
input int    ATR_PERIOD = 14;                    // Période ATR standard
input double ATR_MULTIPLIER = 1.5;               // Multiplicateur ATR standard
input int    ATR_LONG_PERIOD = 28;               // Période ATR longue (volatilité élevée)
input double ATR_LONG_MULTIPLIER = 1.2;          // Multiplicateur ATR longue
input double ATR_VOLATILITY_THRESHOLD = 1.7;     // Seuil volatilité élevée (x moyenne)

// Paramètres Stop-Loss par défaut
input double DEFAULT_SL_PERCENT = 0.5;           // Stop-loss par défaut (% du prix)

//+------------------------------------------------------------------+
//| Structure pour stocker les informations de swing                |
//+------------------------------------------------------------------+
struct SwingPoint
{
   datetime time;
   double   price;
   ENUM_SWING_TYPE type;
   double   volume;
   bool     isValid;
};

//+------------------------------------------------------------------+
//| Classe principale pour le calcul de Stop-Loss dynamique         |
//+------------------------------------------------------------------+
class CDynamicStopLossCalculator
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Handles des indicateurs
   int m_atrHandle;
   int m_atrLongHandle;
   int m_volumeHandle;
   
   // Cache pour éviter les recalculs
   double m_cachedATR;
   double m_cachedATRLong;
   datetime m_lastATRUpdate;
   
public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                     |
   //+------------------------------------------------------------------+
   CDynamicStopLossCalculator(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      
      // Initialiser les handles des indicateurs
      m_atrHandle = iATR(symbol, timeframe, ATR_PERIOD);
      m_atrLongHandle = iATR(symbol, timeframe, ATR_LONG_PERIOD);
      m_volumeHandle = iVolumes(symbol, timeframe, VOLUME_TICK);
      
      // Initialiser le cache
      m_cachedATR = 0;
      m_cachedATRLong = 0;
      m_lastATRUpdate = 0;
      
      // Vérifier la validité des handles
      if(m_atrHandle == INVALID_HANDLE || m_atrLongHandle == INVALID_HANDLE)
      {
         Logger::Error("Failed to create ATR handles for " + symbol);
      }
      
      Logger::Info("Initialized for " + symbol + " on " + EnumToString(timeframe));
   }
   
   //+------------------------------------------------------------------+
   //| Destructeur                                                      |
   //+------------------------------------------------------------------+
   ~CDynamicStopLossCalculator()
   {
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
      if(m_atrLongHandle != INVALID_HANDLE) IndicatorRelease(m_atrLongHandle);
      if(m_volumeHandle != INVALID_HANDLE) IndicatorRelease(m_volumeHandle);
      
      Logger::Info("Destroyed for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Méthode principale : Calculer le Stop-Loss optimal             |
   //+------------------------------------------------------------------+
   double CalculateStopLoss(bool isBuy, double entryPrice)
   {
      Logger::Info("Calculating SL for " + m_symbol + 
                  " | Direction: " + (isBuy ? "BUY" : "SELL") + 
                  " | Entry: " + DoubleToString(entryPrice, 5));
      
      double stopLoss = 0;
      string method = "";
      
      // 1. PRIORITÉ 1 : Dernier swing high/low confirmé
      double swingSL = CalculateSwingStopLoss(isBuy, entryPrice);
      if(swingSL > 0)
      {
         stopLoss = swingSL;
         method = "SWING";
         Logger::Info("✓ Using SWING method: " + DoubleToString(stopLoss, 5));
      }
      else
      {
         // 2. PRIORITÉ 2 : ATR classique
         double atrSL = CalculateATRStopLoss(isBuy, entryPrice, false);
         if(atrSL > 0)
         {
            stopLoss = atrSL;
            method = "ATR";
            Logger::Info("✓ Using ATR method: " + DoubleToString(stopLoss, 5));
         }
         else
         {
            // 3. PRIORITÉ 3 : ATR avec seuil (volatilité élevée)
            double atrLongSL = CalculateATRStopLoss(isBuy, entryPrice, true);
            if(atrLongSL > 0)
            {
               stopLoss = atrLongSL;
               method = "ATR_LONG";
               Logger::Info("✓ Using ATR_LONG method: " + DoubleToString(stopLoss, 5));
            }
            else
            {
               // 4. PRIORITÉ 4 : Pourcentage fixe
               stopLoss = CalculatePercentageStopLoss(isBuy, entryPrice);
               method = "PERCENTAGE";
               Logger::Info("✓ Using PERCENTAGE method: " + DoubleToString(stopLoss, 5));
            }
         }
      }
      
      // Validation finale
      if(stopLoss <= 0)
      {
         Logger::Error("Failed to calculate valid stop-loss");
         return 0;
      }
      
      // Vérifier la distance minimale du broker
      double minDistance = GetMinimumStopDistance();
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double actualDistance = MathAbs(stopLoss - entryPrice);
      
      if(actualDistance < minDistance)
      {
         Logger::Warning("SL distance too small, adjusting to minimum");
         if(isBuy)
            stopLoss = entryPrice - minDistance;
         else
            stopLoss = entryPrice + minDistance;
      }
      
      Logger::Info("Final SL: " + DoubleToString(stopLoss, 5) + 
                  " | Method: " + method + " | Distance: " + DoubleToString(actualDistance/point, 1) + " pts");
      
      return NormalizeDouble(stopLoss, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
   }
   
private:
   //+------------------------------------------------------------------+
   //| 1. Calculer Stop-Loss basé sur les swing points                |
   //+------------------------------------------------------------------+
   double CalculateSwingStopLoss(bool isBuy, double entryPrice)
   {
      Logger::Debug("Analyzing swing points...");
      
      // Obtenir les données OHLC et volume
      double high[], low[], close[];
      long volume[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(volume, true);
      
      int lookback = SWING_LOOKBACK_PERIODS + 5; // Buffer pour la détection
      
      if(CopyHigh(m_symbol, m_timeframe, 0, lookback, high) <= 0 ||
         CopyLow(m_symbol, m_timeframe, 0, lookback, low) <= 0 ||
         CopyClose(m_symbol, m_timeframe, 0, lookback, close) <= 0 ||
         CopyTickVolume(m_symbol, m_timeframe, 0, lookback, volume) <= 0)
      {
         Logger::Error("Failed to get OHLC data for swing analysis");
         return 0;
      }
      
      // Détecter le dernier swing point valide
      SwingPoint lastSwing = FindLastValidSwing(high, low, close, volume, lookback, isBuy);
      
      if(!lastSwing.isValid)
      {
         Logger::Debug("No valid swing point found");
         return 0;
      }
      
      // Calculer le stop-loss basé sur le swing
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double buffer = SWING_BUFFER_POINTS * point;
      double swingSL = 0;
      
      if(isBuy)
      {
         // Pour achat : stop sous le dernier swing low
         if(lastSwing.type == SWING_LOW)
         {
            swingSL = lastSwing.price - buffer;
            Logger::Debug("BUY swing SL: " + DoubleToString(swingSL, 5) + 
                         " (swing low: " + DoubleToString(lastSwing.price, 5) + ")");
         }
      }
      else
      {
         // Pour vente : stop au-dessus du dernier swing high
         if(lastSwing.type == SWING_HIGH)
         {
            swingSL = lastSwing.price + buffer;
            Logger::Debug("SELL swing SL: " + DoubleToString(swingSL, 5) + 
                         " (swing high: " + DoubleToString(lastSwing.price, 5) + ")");
         }
      }
      
      // Vérifier que le stop-loss est logique par rapport au prix d'entrée
      if(swingSL > 0)
      {
         if(isBuy && swingSL >= entryPrice)
         {
            Logger::Warning("Swing SL above entry price, invalid");
            return 0;
         }
         if(!isBuy && swingSL <= entryPrice)
         {
            Logger::Warning("Swing SL below entry price, invalid");
            return 0;
         }
      }
      
      return swingSL;
   }
   
   //+------------------------------------------------------------------+
   //| 2. Calculer Stop-Loss basé sur ATR                             |
   //+------------------------------------------------------------------+
   double CalculateATRStopLoss(bool isBuy, double entryPrice, bool useLongATR)
   {
      Logger::Debug("Calculating ATR stop-loss (long: " + 
                   (useLongATR ? "YES" : "NO") + ")");
      
      // Obtenir la valeur ATR actuelle
      double atrValue = GetATRValue(useLongATR);
      if(atrValue <= 0)
      {
         Logger::Error("Invalid ATR value");
         return 0;
      }
      
      // Vérifier le seuil de volatilité si on utilise ATR long
      if(useLongATR)
      {
         double atrStandard = GetATRValue(false);
         double atrAverage = GetATRAverage();
         
         if(atrStandard <= 0 || atrAverage <= 0)
         {
            Logger::Warning("Cannot calculate volatility threshold");
            return 0;
         }
         
         double volatilityRatio = atrStandard / atrAverage;
         if(volatilityRatio < ATR_VOLATILITY_THRESHOLD)
         {
            Logger::Debug("Volatility too low for ATR_LONG method");
            return 0;
         }
         
         Logger::Info("High volatility detected: " + 
                     DoubleToString(volatilityRatio, 2) + "x average");
      }
      
      // Calculer le stop-loss
      double multiplier = useLongATR ? ATR_LONG_MULTIPLIER : ATR_MULTIPLIER;
      double atrDistance = atrValue * multiplier;
      
      double atrSL = 0;
      if(isBuy)
         atrSL = entryPrice - atrDistance;
      else
         atrSL = entryPrice + atrDistance;
      
      Logger::Debug("ATR SL: " + DoubleToString(atrSL, 5) + 
                   " | ATR: " + DoubleToString(atrValue, 5) + 
                   " | Multiplier: " + DoubleToString(multiplier, 1));
      
      return atrSL;
   }
   
   //+------------------------------------------------------------------+
   //| 3. Calculer Stop-Loss basé sur pourcentage fixe                |
   //+------------------------------------------------------------------+
   double CalculatePercentageStopLoss(bool isBuy, double entryPrice)
   {
      Logger::Debug("Calculating percentage stop-loss");
      
      double percentageDistance = entryPrice * (DEFAULT_SL_PERCENT / 100.0);
      
      double percentageSL = 0;
      if(isBuy)
         percentageSL = entryPrice - percentageDistance;
      else
         percentageSL = entryPrice + percentageDistance;
      
      Logger::Debug("Percentage SL: " + DoubleToString(percentageSL, 5) + 
                   " | Distance: " + DoubleToString(percentageDistance, 5));
      
      return percentageSL;
   }
   
   //+------------------------------------------------------------------+
   //| Trouver le dernier swing point valide                           |
   //+------------------------------------------------------------------+
   SwingPoint FindLastValidSwing(double &high[], double &low[], double &close[], 
                                long &volume[], int lookback, bool isBuy)
   {
      SwingPoint swing;
      swing.isValid = false;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double minDistance = SWING_MIN_DISTANCE_POINTS * point;
      
      // Calculer la moyenne du volume pour le seuil
      double avgVolume = 0;
      for(int i = 0; i < lookback; i++)
         avgVolume += (double)volume[i];
      avgVolume /= lookback;
      
      if(isBuy)
      {
         // Chercher le dernier swing low valide
         for(int i = 2; i < lookback - 2; i++)
         {
            // Vérifier si c'est un swing low (plus bas que les 2 périodes de chaque côté)
            if(low[i] < low[i-1] && low[i] < low[i-2] && 
               low[i] < low[i+1] && low[i] < low[i+2])
            {
               // Vérifier la distance minimale
               double distance = MathAbs(close[0] - low[i]);
               if(distance >= minDistance)
               {
                  // Vérifier le volume
                  if((double)volume[i] >= avgVolume * SWING_VOLUME_THRESHOLD)
                  {
                     swing.time = iTime(m_symbol, m_timeframe, i);
                     swing.price = low[i];
                     swing.type = SWING_LOW;
                     swing.volume = (double)volume[i];
                     swing.isValid = true;
                     
                     Logger::Debug("Valid swing low found at " + 
                                  DoubleToString(low[i], 5) + " | Volume: " + DoubleToString((double)volume[i], 0));
                     break;
                  }
               }
            }
         }
      }
      else
      {
         // Chercher le dernier swing high valide
         for(int i = 2; i < lookback - 2; i++)
         {
            // Vérifier si c'est un swing high (plus haut que les 2 périodes de chaque côté)
            if(high[i] > high[i-1] && high[i] > high[i-2] && 
               high[i] > high[i+1] && high[i] > high[i+2])
            {
               // Vérifier la distance minimale
               double distance = MathAbs(high[i] - close[0]);
               if(distance >= minDistance)
               {
                  // Vérifier le volume
                  if((double)volume[i] >= avgVolume * SWING_VOLUME_THRESHOLD)
                  {
                     swing.time = iTime(m_symbol, m_timeframe, i);
                     swing.price = high[i];
                     swing.type = SWING_HIGH;
                     swing.volume = (double)volume[i];
                     swing.isValid = true;
                     
                     Logger::Debug("Valid swing high found at " + 
                                  DoubleToString(high[i], 5) + " | Volume: " + DoubleToString((double)volume[i], 0));
                     break;
                  }
               }
            }
         }
      }
      
      return swing;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la valeur ATR actuelle                                  |
   //+------------------------------------------------------------------+
   double GetATRValue(bool useLongATR)
   {
      // Utiliser le cache si disponible
      datetime currentTime = TimeCurrent();
      if(m_lastATRUpdate == currentTime)
      {
         return useLongATR ? m_cachedATRLong : m_cachedATR;
      }
      
      int handle = useLongATR ? m_atrLongHandle : m_atrHandle;
      double atr[];
      ArraySetAsSeries(atr, true);
      
      if(CopyBuffer(handle, 0, 0, 1, atr) <= 0)
      {
         Logger::Error("Failed to get ATR value");
         return 0;
      }
      
      // Mettre à jour le cache
      if(useLongATR)
         m_cachedATRLong = atr[0];
      else
         m_cachedATR = atr[0];
      
      m_lastATRUpdate = currentTime;
      
      return atr[0];
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la moyenne ATR sur plusieurs périodes                   |
   //+------------------------------------------------------------------+
   double GetATRAverage()
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      
      if(CopyBuffer(m_atrHandle, 0, 0, 10, atr) <= 0)
      {
         Logger::Error("Failed to get ATR history");
         return 0;
      }
      
      double sum = 0;
      for(int i = 0; i < 10; i++)
         sum += atr[i];
      
      return sum / 10.0;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la distance minimale de stop du broker                   |
   //+------------------------------------------------------------------+
   double GetMinimumStopDistance()
   {
      int stopLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      if(stopLevel > 0)
         return stopLevel * point;
      
      // Fallback : utiliser le spread comme distance minimale
      int spread = (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      return spread * point * 2.0;
   }
   
public:
   //+------------------------------------------------------------------+
   //| Obtenir les informations de debug                               |
   //+------------------------------------------------------------------+
   string GetDebugInfo()
   {
      string info = "=== DYNAMIC STOP-LOSS CALCULATOR DEBUG ===\n";
      info += "Symbol: " + m_symbol + "\n";
      info += "Timeframe: " + EnumToString(m_timeframe) + "\n";
      info += "ATR Handle: " + (m_atrHandle != INVALID_HANDLE ? "OK" : "INVALID") + "\n";
      info += "ATR Long Handle: " + (m_atrLongHandle != INVALID_HANDLE ? "OK" : "INVALID") + "\n";
      info += "Volume Handle: " + (m_volumeHandle != INVALID_HANDLE ? "OK" : "INVALID") + "\n";
      info += "Current ATR: " + DoubleToString(GetATRValue(false), 5) + "\n";
      info += "Current ATR Long: " + DoubleToString(GetATRValue(true), 5) + "\n";
      info += "ATR Average: " + DoubleToString(GetATRAverage(), 5) + "\n";
      info += "Min Stop Distance: " + DoubleToString(GetMinimumStopDistance(), 5) + "\n";
      info += "================================================";
      
      return info;
   }
};

//+------------------------------------------------------------------+
//| Fonction utilitaire pour utilisation simple                      |
//+------------------------------------------------------------------+
double CalculateDynamicStopLoss(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy, double entryPrice)
{
   CDynamicStopLossCalculator calculator(symbol, timeframe);
   return calculator.CalculateStopLoss(isBuy, entryPrice);
}
