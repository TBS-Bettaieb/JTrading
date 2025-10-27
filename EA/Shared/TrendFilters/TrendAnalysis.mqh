//+------------------------------------------------------------------+
//|                                           TrendAnalysis.mqh       |
//|                   Analyse de tendance sur timeframe supérieur    |
//|                                                                   |
//| UTILISATION :                                                     |
//| 1. Incluez ce fichier : #include "TrendAnalysis.mqh"             |
//|                                                                   |
//| 2. Utilisez les méthodes statiques :                             |
//|    - CheckHigherTimeframeTrendAdvanced() : tendance avancée      |
//|    - CheckHigherTimeframeTrend() : tendance simple               |
//|                                                                   |
//| EXEMPLES :                                                        |
//| - TrendAnalysis::CheckHigherTimeframeTrendAdvanced("EURUSD", PERIOD_H4, true) |
//| - TrendAnalysis::CheckHigherTimeframeTrend("GBPUSD", PERIOD_D1, false)     |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Classe statique pour l'analyse de tendance                      |
//+------------------------------------------------------------------+
class TrendAnalysis
{
public:
//+------------------------------------------------------------------+
//| Détecte une tendance avancée sur un timeframe supérieur.         |
//| Utilise plusieurs indicateurs (MA + price action) pour une      |
//| analyse de tendance plus robuste.                                |
//| @param symbol Symbole à analyser                                  |
//| @param higher_tf Timeframe supérieur à analyser                 |
//| @param bullish true pour tendance haussière, false pour baissière |
//| @return true si tendance confirmée par plusieurs indicateurs     |
//+------------------------------------------------------------------+
static bool CheckHigherTimeframeTrendAdvanced(string symbol, ENUM_TIMEFRAMES higher_tf, bool bullish)
{
   double ema50[], ema200[], closePrice[];
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(closePrice, true);
   
   // Créer les handles pour EMA-50 et EMA-200
   int ema50Handle = iMA(symbol, higher_tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   int ema200Handle = iMA(symbol, higher_tf, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema50Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création des handles EMA pour ", symbol);
      return false;
   }
   
   // Copier les données
   if(CopyBuffer(ema50Handle, 0, 0, 2, ema50) <= 0 ||
      CopyBuffer(ema200Handle, 0, 0, 2, ema200) <= 0 ||
      CopyClose(symbol, higher_tf, 0, 2, closePrice) <= 0)
   {
      Print("Erreur lors de la copie des données pour ", symbol);
      IndicatorRelease(ema50Handle);
      IndicatorRelease(ema200Handle);
      return false;
   }
   
   // Libérer les handles
   IndicatorRelease(ema50Handle);
   IndicatorRelease(ema200Handle);
   
   if(bullish)
   {
      // Conditions pour tendance haussière forte:
      // 1. Prix au-dessus de l'EMA-50
      // 2. EMA-50 au-dessus de l'EMA-200 (Golden Cross)
      // 3. Prix en hausse
      bool condition1 = closePrice[0] > ema50[0];
      bool condition2 = ema50[0] > ema200[0];
      bool condition3 = closePrice[0] > closePrice[1];
      
      return (condition1 && condition2 && condition3);
   }
   else
   {
      // Conditions pour tendance baissière forte:
      // 1. Prix en dessous de l'EMA-50
      // 2. EMA-50 en dessous de l'EMA-200 (Death Cross)
      // 3. Prix en baisse
      bool condition1 = closePrice[0] < ema50[0];
      bool condition2 = ema50[0] < ema200[0];
      bool condition3 = closePrice[0] < closePrice[1];
      
      return (condition1 && condition2 && condition3);
   }
}

//+------------------------------------------------------------------+
//| Vérifie la tendance haussière ou baissière sur timeframe supérieur.|
//| Analyse simple basée uniquement sur les moyennes mobiles.        |
//| @param symbol Symbole à analyser                                  |
//| @param higher_tf Timeframe supérieur à analyser                 |
//| @param bullish true pour tendance haussière, false pour baissière |
//| @return true si tendance détectée par MA                         |
//+------------------------------------------------------------------+
static bool CheckHigherTimeframeTrend(string symbol, ENUM_TIMEFRAMES higher_tf, bool bullish)
{
   // Array pour stocker les prix de clôture
   double closePrice[];
   ArraySetAsSeries(closePrice, true);
   
   // Array pour stocker les valeurs EMA
   double emaValues[];
   ArraySetAsSeries(emaValues, true);
   
   // Créer un handle pour l'EMA sur le timeframe supérieur
   // Utilisation d'une EMA-50 pour déterminer la tendance
   int emaHandle = iMA(symbol, higher_tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   // Vérifier si le handle est valide
   if(emaHandle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du handle EMA pour ", symbol);
      return false;
   }
   
   // Copier les valeurs de l'EMA
   if(CopyBuffer(emaHandle, 0, 0, 3, emaValues) <= 0)
   {
      Print("Erreur lors de la copie du buffer EMA pour ", symbol);
      IndicatorRelease(emaHandle);
      return false;
   }
   
   // Copier les prix de clôture du timeframe supérieur
   if(CopyClose(symbol, higher_tf, 0, 3, closePrice) <= 0)
   {
      Print("Erreur lors de la copie des prix de clôture pour ", symbol);
      IndicatorRelease(emaHandle);
      return false;
   }
   
   // Valeurs actuelles
   double currentClose = closePrice[0];
   double currentEMA = emaValues[0];
   double previousClose = closePrice[1];
   double previousEMA = emaValues[1];
   
   // Libérer le handle
   IndicatorRelease(emaHandle);
   
   // Vérifier la tendance selon le paramètre
   if(bullish)
   {
      // Tendance haussière: prix au-dessus de l'EMA
      // ET l'EMA est en pente ascendante
      bool priceAboveEMA = currentClose > currentEMA;
      bool emaRising = currentEMA > previousEMA;
      
      return (priceAboveEMA && emaRising);
   }
   else
   {
      // Tendance baissière: prix en dessous de l'EMA
      // ET l'EMA est en pente descendante
      bool priceBelowEMA = currentClose < currentEMA;
      bool emaFalling = currentEMA < previousEMA;
      
      return (priceBelowEMA && emaFalling);
   }
}
};
