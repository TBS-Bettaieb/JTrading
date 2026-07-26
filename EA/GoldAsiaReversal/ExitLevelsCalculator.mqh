//+------------------------------------------------------------------+
//|                                       ExitLevelsCalculator.mqh     |
//|              Calcul du Stop Loss et du Take Profit                 |
//|                                                                    |
//| Note : EA/Shared/DynamicStopLossCalculator.mqh existe mais         |
//| auto-selectionne sa methode (swing -> ATR -> pourcentage) sans     |
//| choix explicite, et ne propose ni "low de la veille" ni "open de   |
//| la veille". D'ou ce calculateur dedie, a methode imposee.          |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "../Shared/Logger.mqh"

//+------------------------------------------------------------------+
//| Methode de calcul du Stop Loss                                    |
//+------------------------------------------------------------------+
enum ENUM_SL_METHOD
{
   SL_METHOD_ATR           = 0,   // ATR x multiplicateur
   SL_METHOD_PREV_DAY_LOW  = 1,   // Low de la bougie D1 du signal
   SL_METHOD_PREV_DAY_OPEN = 2,   // Open de la bougie D1 du signal
   SL_METHOD_FIXED_POINTS  = 3    // Distance fixe en points
};

//+------------------------------------------------------------------+
//| Mode de Take Profit                                               |
//| Dans TOUS les cas la position est cloturee a la fin de la session |
//| asiatique : le TP est une sortie anticipee, pas un remplacement.  |
//+------------------------------------------------------------------+
enum ENUM_TP_MODE
{
   TP_MODE_NONE         = 0,   // Aucun TP - cloture fin de session uniquement
   TP_MODE_RR_RATIO     = 1,   // Ratio R:R sur la distance de SL + cloture fin de session
   TP_MODE_ATR          = 2,   // ATR x multiplicateur + cloture fin de session
   TP_MODE_FIXED_POINTS = 3    // Distance fixe en points + cloture fin de session
};

//+------------------------------------------------------------------+
//| Niveaux calcules pour une entree                                  |
//+------------------------------------------------------------------+
struct ExitLevels
{
   double   stopLoss;
   double   takeProfit;
   double   slPoints;      // Distance SL en points (sert au sizing par risque)
   string   detail;        // Trace lisible pour les logs
};

//+------------------------------------------------------------------+
//| Calculateur SL / TP                                               |
//+------------------------------------------------------------------+
class ExitLevelsCalculator
{
private:
   string            m_symbol;

   //--- Stop Loss
   ENUM_SL_METHOD    m_slMethod;
   int               m_atrPeriod;
   ENUM_TIMEFRAMES   m_atrTimeframe;
   double            m_slAtrMultiplier;
   int               m_slFixedPoints;
   int               m_slBufferPoints;    // Marge sous le low / open de la veille
   int               m_minSlPoints;       // Garde-fou bas (0 = niveau broker)
   int               m_maxSlPoints;       // Garde-fou haut (0 = desactive)

   //--- Take Profit
   ENUM_TP_MODE      m_tpMode;
   double            m_rrRatio;
   double            m_tpAtrMultiplier;
   int               m_tpFixedPoints;

   int               m_atrHandle;

   double            m_point;
   int               m_digits;

   //+------------------------------------------------------------------+
   //| Valeur ATR sur la derniere bougie cloturee                        |
   //+------------------------------------------------------------------+
   bool GetATR(double &atrValue) const
   {
      atrValue = 0.0;

      if(m_atrHandle == INVALID_HANDLE)
         return false;

      double buffer[];
      ArraySetAsSeries(buffer, true);

      // shift 1 : derniere bougie cloturee, valeur stable
      if(CopyBuffer(m_atrHandle, 0, 1, 1, buffer) <= 0)
      {
         Logger::Warning("CopyBuffer ATR a echoue (erreur " + IntegerToString(GetLastError()) + ")");
         return false;
      }

      atrValue = buffer[0];
      return (atrValue > 0.0);
   }

   //+------------------------------------------------------------------+
   //| Recupere open / low de la bougie D1 du signal                     |
   //+------------------------------------------------------------------+
   bool GetSignalDailyBar(datetime signalBarTime, MqlRates &bar) const
   {
      if(signalBarTime <= 0)
         return false;

      MqlRates rates[];
      if(CopyRates(m_symbol, PERIOD_D1, signalBarTime, 1, rates) <= 0)
      {
         Logger::Warning("CopyRates D1 sur la bougie du signal a echoue (erreur "
                         + IntegerToString(GetLastError()) + ")");
         return false;
      }

      bar = rates[0];
      return true;
   }

   //--- Distance minimale imposee par le broker
   double BrokerMinDistance() const
   {
      long stopsLvl = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      return stopsLvl * m_point;
   }

public:
   ExitLevelsCalculator()
   {
      m_symbol          = "";
      m_slMethod        = SL_METHOD_ATR;
      m_atrPeriod       = 14;
      m_atrTimeframe    = PERIOD_D1;
      m_slAtrMultiplier = 1.0;
      m_slFixedPoints   = 3000;
      m_slBufferPoints  = 100;
      m_minSlPoints     = 0;
      m_maxSlPoints     = 0;
      m_tpMode          = TP_MODE_NONE;
      m_rrRatio         = 1.5;
      m_tpAtrMultiplier = 1.5;
      m_tpFixedPoints   = 3000;
      m_atrHandle       = INVALID_HANDLE;
      m_point           = 0.0;
      m_digits          = 2;
   }

   ~ExitLevelsCalculator()
   {
      if(m_atrHandle != INVALID_HANDLE)
         IndicatorRelease(m_atrHandle);
   }

   //+------------------------------------------------------------------+
   //| Configuration                                                     |
   //+------------------------------------------------------------------+
   bool Configure(string symbol,
                  ENUM_SL_METHOD slMethod, ENUM_TIMEFRAMES atrTimeframe, int atrPeriod,
                  double slAtrMultiplier, int slFixedPoints, int slBufferPoints,
                  int minSlPoints, int maxSlPoints,
                  ENUM_TP_MODE tpMode, double rrRatio, double tpAtrMultiplier, int tpFixedPoints)
   {
      m_symbol = symbol;
      m_point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      if(m_point <= 0.0)
      {
         Logger::Error("Point du symbole invalide pour " + symbol);
         return false;
      }

      //--- Validation
      if(atrPeriod < 1 || atrPeriod > 500)
      {
         Logger::Error(StringFormat("Periode ATR invalide : %d (attendu 1 a 500)", atrPeriod));
         return false;
      }

      if(slAtrMultiplier <= 0.0 || tpAtrMultiplier <= 0.0)
      {
         Logger::Error("Les multiplicateurs ATR doivent etre > 0");
         return false;
      }

      if(slMethod == SL_METHOD_FIXED_POINTS && slFixedPoints <= 0)
      {
         Logger::Error("SL en points fixes selectionne mais distance <= 0");
         return false;
      }

      if(tpMode == TP_MODE_RR_RATIO && rrRatio <= 0.0)
      {
         Logger::Error(StringFormat("Ratio R:R invalide : %.2f (doit etre > 0)", rrRatio));
         return false;
      }

      if(tpMode == TP_MODE_FIXED_POINTS && tpFixedPoints <= 0)
      {
         Logger::Error("TP en points fixes selectionne mais distance <= 0");
         return false;
      }

      if(maxSlPoints > 0 && minSlPoints > 0 && maxSlPoints < minSlPoints)
      {
         Logger::Error(StringFormat("SL max (%d) inferieur au SL min (%d)", maxSlPoints, minSlPoints));
         return false;
      }

      m_slMethod        = slMethod;
      m_atrTimeframe    = atrTimeframe;
      m_atrPeriod       = atrPeriod;
      m_slAtrMultiplier = slAtrMultiplier;
      m_slFixedPoints   = slFixedPoints;
      m_slBufferPoints  = MathMax(0, slBufferPoints);
      m_minSlPoints     = MathMax(0, minSlPoints);
      m_maxSlPoints     = MathMax(0, maxSlPoints);
      m_tpMode          = tpMode;
      m_rrRatio         = rrRatio;
      m_tpAtrMultiplier = tpAtrMultiplier;
      m_tpFixedPoints   = tpFixedPoints;

      //--- Handle ATR uniquement si une methode en a besoin
      bool needsAtr = (slMethod == SL_METHOD_ATR) || (tpMode == TP_MODE_ATR);
      if(needsAtr)
      {
         m_atrHandle = iATR(symbol, atrTimeframe, atrPeriod);
         if(m_atrHandle == INVALID_HANDLE)
         {
            Logger::Error(StringFormat("Creation du handle ATR impossible (%s %s periode %d)",
                                       symbol, EnumToString(atrTimeframe), atrPeriod));
            return false;
         }
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Calcul des niveaux pour un BUY                                    |
   //| Le SL est OBLIGATOIRE : si la methode choisie echoue ou produit   |
   //| un niveau incoherent, on retombe sur la distance fixe.            |
   //+------------------------------------------------------------------+
   bool Calculate(double entryPrice, datetime signalBarTime, ExitLevels &levels)
   {
      levels.stopLoss   = 0.0;
      levels.takeProfit = 0.0;
      levels.slPoints   = 0.0;
      levels.detail     = "";

      if(entryPrice <= 0.0)
      {
         Logger::Error("Prix d'entree invalide pour le calcul des niveaux");
         return false;
      }

      double minDist = MathMax(BrokerMinDistance(), m_point);
      if(m_minSlPoints > 0)
         minDist = MathMax(minDist, m_minSlPoints * m_point);

      double rawSL = 0.0;
      string source = "";

      //--- 1. Niveau brut selon la methode choisie
      switch(m_slMethod)
      {
         case SL_METHOD_ATR:
         {
            double atr = 0.0;
            if(GetATR(atr))
            {
               rawSL  = entryPrice - m_slAtrMultiplier * atr;
               source = StringFormat("ATR(%d,%s)=%.2f x %.2f",
                                     m_atrPeriod, EnumToString(m_atrTimeframe), atr, m_slAtrMultiplier);
            }
            break;
         }

         case SL_METHOD_PREV_DAY_LOW:
         {
            MqlRates bar;
            if(GetSignalDailyBar(signalBarTime, bar))
            {
               rawSL  = bar.low - m_slBufferPoints * m_point;
               source = StringFormat("Low D1 du %s = %s (buffer %d pts)",
                                     TimeToString(bar.time, TIME_DATE),
                                     DoubleToString(bar.low, m_digits), m_slBufferPoints);
            }
            break;
         }

         case SL_METHOD_PREV_DAY_OPEN:
         {
            MqlRates bar;
            if(GetSignalDailyBar(signalBarTime, bar))
            {
               rawSL  = bar.open - m_slBufferPoints * m_point;
               source = StringFormat("Open D1 du %s = %s (buffer %d pts)",
                                     TimeToString(bar.time, TIME_DATE),
                                     DoubleToString(bar.open, m_digits), m_slBufferPoints);
            }
            break;
         }

         case SL_METHOD_FIXED_POINTS:
         {
            rawSL  = entryPrice - m_slFixedPoints * m_point;
            source = StringFormat("%d points fixes", m_slFixedPoints);
            break;
         }
      }

      //--- 2. Repli si la methode a echoue ou donne un SL au-dessus de l'entree
      //    (cas reel : gap baissier a l'ouverture asiatique avec SL sur l'open de la veille)
      if(rawSL <= 0.0 || rawSL > entryPrice - minDist)
      {
         double fallbackPoints = (m_slFixedPoints > 0) ? m_slFixedPoints : 3000;
         double fallbackSL     = entryPrice - fallbackPoints * m_point;

         Logger::Warning(StringFormat("SL %s inutilisable (%s), repli sur %d points fixes",
                                      EnumToString(m_slMethod),
                                      rawSL <= 0.0 ? "calcul indisponible" : "niveau trop proche ou au-dessus de l'entree",
                                      (int)fallbackPoints));

         rawSL  = fallbackSL;
         source = StringFormat("repli %d points fixes", (int)fallbackPoints);
      }

      //--- 3. Plafonnement de la distance
      double slDistance = entryPrice - rawSL;

      if(m_maxSlPoints > 0 && slDistance > m_maxSlPoints * m_point)
      {
         Logger::Info(StringFormat("SL plafonne : %.0f pts ramenes a %d pts",
                                   slDistance / m_point, m_maxSlPoints));
         slDistance = m_maxSlPoints * m_point;
         rawSL      = entryPrice - slDistance;
         source    += StringFormat(" [plafonne a %d pts]", m_maxSlPoints);
      }

      if(slDistance < minDist)
      {
         slDistance = minDist;
         rawSL      = entryPrice - slDistance;
         source    += " [distance minimale broker appliquee]";
      }

      levels.stopLoss = NormalizeDouble(rawSL, m_digits);
      levels.slPoints = slDistance / m_point;

      //--- 4. Take Profit
      string tpSource = "aucun (sortie fin de session)";

      switch(m_tpMode)
      {
         case TP_MODE_NONE:
            levels.takeProfit = 0.0;
            break;

         case TP_MODE_RR_RATIO:
            levels.takeProfit = entryPrice + m_rrRatio * slDistance;
            tpSource = StringFormat("R:R %.2f x %.0f pts de SL", m_rrRatio, levels.slPoints);
            break;

         case TP_MODE_ATR:
         {
            double atr = 0.0;
            if(GetATR(atr))
            {
               levels.takeProfit = entryPrice + m_tpAtrMultiplier * atr;
               tpSource = StringFormat("ATR %.2f x %.2f", atr, m_tpAtrMultiplier);
            }
            else
            {
               Logger::Warning("ATR indisponible pour le TP, TP desactive (sortie fin de session)");
               levels.takeProfit = 0.0;
               tpSource = "ATR indisponible - desactive";
            }
            break;
         }

         case TP_MODE_FIXED_POINTS:
            levels.takeProfit = entryPrice + m_tpFixedPoints * m_point;
            tpSource = StringFormat("%d points fixes", m_tpFixedPoints);
            break;
      }

      //--- Le TP doit respecter la distance minimale du broker
      if(levels.takeProfit > 0.0)
      {
         if(levels.takeProfit < entryPrice + minDist)
         {
            levels.takeProfit = entryPrice + minDist;
            tpSource += " [distance minimale broker appliquee]";
         }
         levels.takeProfit = NormalizeDouble(levels.takeProfit, m_digits);
      }

      levels.detail = StringFormat("SL %s (%.0f pts) via %s | TP %s via %s",
                                   DoubleToString(levels.stopLoss, m_digits),
                                   levels.slPoints,
                                   source,
                                   levels.takeProfit > 0.0 ? DoubleToString(levels.takeProfit, m_digits) : "aucun",
                                   tpSource);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Description pour les logs et le panneau graphique                 |
   //+------------------------------------------------------------------+
   string Describe() const
   {
      string sl = "";
      switch(m_slMethod)
      {
         case SL_METHOD_ATR:
            sl = StringFormat("ATR(%d %s) x %.2f", m_atrPeriod, EnumToString(m_atrTimeframe), m_slAtrMultiplier);
            break;
         case SL_METHOD_PREV_DAY_LOW:
            sl = StringFormat("low D1 du signal - %d pts", m_slBufferPoints);
            break;
         case SL_METHOD_PREV_DAY_OPEN:
            sl = StringFormat("open D1 du signal - %d pts", m_slBufferPoints);
            break;
         case SL_METHOD_FIXED_POINTS:
            sl = StringFormat("%d pts fixes", m_slFixedPoints);
            break;
      }

      if(m_maxSlPoints > 0)
         sl += StringFormat(" (max %d pts)", m_maxSlPoints);

      string tp = "";
      switch(m_tpMode)
      {
         case TP_MODE_NONE:         tp = "aucun";                                          break;
         case TP_MODE_RR_RATIO:     tp = StringFormat("R:R %.2f", m_rrRatio);              break;
         case TP_MODE_ATR:          tp = StringFormat("ATR x %.2f", m_tpAtrMultiplier);    break;
         case TP_MODE_FIXED_POINTS: tp = StringFormat("%d pts fixes", m_tpFixedPoints);    break;
      }

      return "SL " + sl + " | TP " + tp + " | sortie fin de session dans tous les cas";
   }
};
//+------------------------------------------------------------------+
