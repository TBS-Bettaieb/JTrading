//+------------------------------------------------------------------+
//|                                              GoldAsiaTrader.mqh    |
//|   Machine a etats : arme (signal D1) -> achete (ouverture Asie)    |
//|                     -> gere -> cloture (fin de session)            |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#include "../Shared/Logger.mqh"
#include "../Shared/ChartManager.mqh"
#include "DailyReversalSignal.mqh"
#include "AsianSessionScheduler.mqh"
#include "ExitLevelsCalculator.mqh"

#define GAR_OBJ_PREFIX "GAR_"

//+------------------------------------------------------------------+
//| Etats de la strategie                                             |
//+------------------------------------------------------------------+
enum ENUM_GAR_STATE
{
   GAR_IDLE = 0,       // Aucun signal en attente
   GAR_ARMED,          // Signal D1 valide, on attend l'ouverture asiatique
   GAR_IN_POSITION     // Position ouverte, on attend la fin de session
};

//+------------------------------------------------------------------+
//| Configuration d'execution                                         |
//+------------------------------------------------------------------+
struct GoldAsiaConfig
{
   string   symbol;
   int      magic;
   double   lotSize;
   double   riskPercent;
   int      maxSpreadPoints;
   int      slippage;
   int      maxEntryDelayMinutes;
   string   tradeComment;
   bool     showVisuals;
   //--- Zones de session
   bool     drawSessionZones;
   bool     clearDrawingsOnExit;   // Faux = garder les traces apres un backtest
   int      zoneHistoryCount;      // Sessions passees dessinees au demarrage
   color    zoneColor;             // Session non tradee
   color    zoneWinColor;          // Session tradee gagnante
   color    zoneLossColor;         // Session tradee perdante
};

//+------------------------------------------------------------------+
//| Orchestrateur mono-symbole                                        |
//+------------------------------------------------------------------+
class GoldAsiaTrader
{
private:
   GoldAsiaConfig          m_cfg;
   CTrade                  m_trade;
   CPositionInfo           m_position;
   DailyReversalSignal     m_signal;
   AsianSessionScheduler   m_scheduler;
   ExitLevelsCalculator    m_exitLevels;
   ChartManager           *m_chart;

   ENUM_GAR_STATE          m_state;
   datetime                m_lastD1Bar;             // Derniere bougie D1 evaluee
   datetime                m_positionSessionKey;    // Session de rattachement de la position
   datetime                m_decidedSessionKey;     // Session deja arbitree (tradee ou ecartee)
   datetime                m_prevSessionKey;        // Session du tick precedent (detection de transition)
   bool                    m_firstTickDone;         // Faux tant qu'on n'a pas d'etat precedent fiable
   //--- Zone de session en cours de trace
   datetime                m_zoneSessionKey;
   double                  m_zoneHigh;
   double                  m_zoneLow;
   datetime                m_lastZoneRedraw;        // Anti-spam du redessin (granularite minute)
   datetime                m_entryTime;
   double                  m_entryPrice;
   int                     m_tradesOpened;
   int                     m_tradesClosed;
   double                  m_cumulatedProfit;
   string                  m_lastStatusLine;

   //+------------------------------------------------------------------+
   //| Mode de remplissage supporte par le broker pour ce symbole        |
   //+------------------------------------------------------------------+
   ENUM_ORDER_TYPE_FILLING PickFillingMode() const
   {
      long modes = SymbolInfoInteger(m_cfg.symbol, SYMBOL_FILLING_MODE);

      if((modes & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
      if((modes & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;

      return ORDER_FILLING_RETURN;
   }

   //+------------------------------------------------------------------+
   //| Normalisation du volume aux contraintes du broker                 |
   //+------------------------------------------------------------------+
   double NormalizeLots(double lots) const
   {
      double minLot  = SymbolInfoDouble(m_cfg.symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(m_cfg.symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(m_cfg.symbol, SYMBOL_VOLUME_STEP);

      if(stepLot <= 0.0) stepLot = 0.01;

      lots = MathFloor(lots / stepLot) * stepLot;
      lots = MathMax(minLot, MathMin(maxLot, lots));

      int lotDigits = (int)MathMax(0.0, MathCeil(-MathLog10(stepLot)));
      return NormalizeDouble(lots, lotDigits);
   }

   //+------------------------------------------------------------------+
   //| Volume : risque en % si SL defini, sinon lot fixe                 |
   //| Passe par TICK_VALUE / TICK_SIZE : l'or n'a pas la meme valeur    |
   //| du point qu'une paire forex et varie selon le broker.             |
   //+------------------------------------------------------------------+
   double CalcLots(double slPoints) const
   {
      if(m_cfg.riskPercent <= 0.0 || slPoints <= 0.0)
         return NormalizeLots(m_cfg.lotSize);

      double tickValue = SymbolInfoDouble(m_cfg.symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(m_cfg.symbol, SYMBOL_TRADE_TICK_SIZE);
      double point     = SymbolInfoDouble(m_cfg.symbol, SYMBOL_POINT);

      if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0)
      {
         Logger::Warning("Donnees de tick indisponibles, repli sur le lot fixe");
         return NormalizeLots(m_cfg.lotSize);
      }

      double lossPerLot = (slPoints * point / tickSize) * tickValue;
      if(lossPerLot <= 0.0)
         return NormalizeLots(m_cfg.lotSize);

      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * m_cfg.riskPercent / 100.0;
      return NormalizeLots(riskMoney / lossPerLot);
   }

   //+------------------------------------------------------------------+
   //| Position ouverte appartenant a cet EA ?                           |
   //+------------------------------------------------------------------+
   bool HasOpenPosition(ulong &ticket)
   {
      ticket = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i))
            continue;

         if(m_position.Magic() == m_cfg.magic && m_position.Symbol() == m_cfg.symbol)
         {
            ticket = m_position.Ticket();
            return true;
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Ouverture du BUY marche a l'ouverture de session                  |
   //+------------------------------------------------------------------+
   bool OpenBuy(datetime sessionKey)
   {
      double ask = SymbolInfoDouble(m_cfg.symbol, SYMBOL_ASK);
      if(ask <= 0.0)
      {
         Logger::Warning("Prix Ask indisponible, entree reportee au tick suivant");
         return false;
      }

      //--- SL obligatoire + TP optionnel, calcules sur la bougie D1 du signal
      ExitLevels levels;
      if(!m_exitLevels.Calculate(ask, m_signal.GetSignalBarTime(), levels))
      {
         Logger::Error("Calcul des niveaux SL/TP impossible, entree annulee");
         return false;
      }

      double sl = levels.stopLoss;
      double tp = levels.takeProfit;

      double lots = CalcLots(levels.slPoints);
      if(lots <= 0.0)
      {
         Logger::Error("Volume calcule nul, entree annulee");
         return false;
      }

      //--- Marge disponible
      double margin = 0.0;
      if(OrderCalcMargin(ORDER_TYPE_BUY, m_cfg.symbol, lots, ask, margin))
      {
         double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         if(margin > freeMargin)
         {
            Logger::Error(StringFormat("Marge insuffisante : %.2f requise, %.2f disponible", margin, freeMargin));
            return false;
         }
      }

      if(!m_trade.Buy(lots, m_cfg.symbol, 0.0, sl, tp, m_cfg.tradeComment))
      {
         Logger::Error(StringFormat("Echec ouverture BUY | retcode=%d (%s)",
                                    m_trade.ResultRetcode(),
                                    m_trade.ResultRetcodeDescription()));
         return false;
      }

      m_entryPrice         = (m_trade.ResultPrice() > 0.0) ? m_trade.ResultPrice() : ask;
      m_entryTime          = TimeCurrent();   // heure serveur : sert aux objets graphiques
      m_positionSessionKey = sessionKey;
      m_state              = GAR_IN_POSITION;
      m_tradesOpened++;

      Logger::Success(StringFormat("BUY ouvert | %.2f lot(s) @ %s | session du %s",
                                   lots,
                                   DoubleToString(m_entryPrice, (int)SymbolInfoInteger(m_cfg.symbol, SYMBOL_DIGITS)),
                                   TimeToString(sessionKey, TIME_DATE | TIME_MINUTES)));
      Logger::Info("Niveaux : " + levels.detail);

      DrawEntryArrow();
      DrawLevelLines(sl, tp);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Cloture de la position (meme pattern que BreakoutScalperTrader)   |
   //+------------------------------------------------------------------+
   bool ClosePosition(string reason)
   {
      bool allClosed = true;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i))
            continue;

         if(m_position.Magic() != m_cfg.magic || m_position.Symbol() != m_cfg.symbol)
            continue;

         ulong  ticket = m_position.Ticket();
         double profit = m_position.Profit() + m_position.Swap() + m_position.Commission();

         bool closed = false;
         for(int attempt = 1; attempt <= 3 && !closed; attempt++)
         {
            closed = m_trade.PositionClose(ticket);

            if(!closed)
               Logger::Warning(StringFormat("Echec cloture #%I64u (tentative %d/3) | retcode=%d (%s)",
                                            ticket, attempt,
                                            m_trade.ResultRetcode(),
                                            m_trade.ResultRetcodeDescription()));
         }

         if(closed)
         {
            m_tradesClosed++;
            m_cumulatedProfit += profit;

            Logger::Success(StringFormat("Position #%I64u cloturee (%s) | P&L %.2f %s | cumul %.2f",
                                         ticket, reason, profit,
                                         AccountInfoString(ACCOUNT_CURRENCY),
                                         m_cumulatedProfit));
            DrawExitMarkers(profit);
         }
         else
         {
            allClosed = false;
            Logger::Error(StringFormat("Position #%I64u NON cloturee apres 3 tentatives", ticket));
         }
      }

      return allClosed;
   }

   //+------------------------------------------------------------------+
   //| Arbitrage de l'entree pour la session courante                    |
   //+------------------------------------------------------------------+
   void TryEnter(datetime now, datetime sessionKey, bool observedOpen)
   {
      //--- Jour d'ouverture autorise ?
      if(!m_scheduler.IsSessionDayAllowed(sessionKey))
      {
         Logger::Info(StringFormat("Session du %s ignoree : jour non autorise",
                                   TimeToString(sessionKey, TIME_DATE)));
         m_decidedSessionKey = sessionKey;
         return;
      }

      int elapsed = m_scheduler.MinutesSinceOpen(sessionKey, now);

      //--- Fenetre d'entree.
      //    Si l'EA a VU la session s'ouvrir (le tick precedent etait hors session),
      //    ce tick EST la premiere occasion de trader : on entre, meme si le marche
      //    a ouvert en retard. Sur l'or beaucoup de brokers ne cotent qu'a partir
      //    de 01:00-01:05 heure serveur, soit largement apres 00:00.
      //    Le delai maximal ne s'applique donc qu'au rattachement en pleine session
      //    (EA attache ou redemarre apres l'ouverture).
      if(!observedOpen && elapsed > m_cfg.maxEntryDelayMinutes)
      {
         Logger::Warning(StringFormat("Session du %s ignoree : rattachement %d min apres l'ouverture (limite %d)",
                                      TimeToString(sessionKey, TIME_DATE | TIME_MINUTES),
                                      elapsed, m_cfg.maxEntryDelayMinutes));
         m_decidedSessionKey = sessionKey;
         return;
      }

      if(observedOpen && elapsed > m_cfg.maxEntryDelayMinutes)
         Logger::Info(StringFormat("Premier tick de la session %d min apres l'heure planifiee (marche ferme entre-temps)",
                                   elapsed));

      //--- Spread : transitoire, on retentera au tick suivant dans la fenetre
      long spread = SymbolInfoInteger(m_cfg.symbol, SYMBOL_SPREAD);
      if(m_cfg.maxSpreadPoints > 0 && spread > m_cfg.maxSpreadPoints)
      {
         Logger::Debug(StringFormat("Entree differee : spread %d > %d points", (int)spread, m_cfg.maxSpreadPoints));
         return;
      }

      if(OpenBuy(sessionKey))
         m_decidedSessionKey = sessionKey;
   }

   //+------------------------------------------------------------------+
   //| Visuels                                                           |
   //+------------------------------------------------------------------+
   void DrawSignalArrow(datetime barTime, double price)
   {
      if(!m_cfg.showVisuals || m_chart == NULL) return;

      string name = GAR_OBJ_PREFIX + "Sig_" + IntegerToString((long)barTime);
      long   cid  = m_chart.GetChartId();

      ObjectDelete(cid, name);
      if(!ObjectCreate(cid, name, OBJ_ARROW_UP, 0, barTime, price))
         return;

      ObjectSetInteger(cid, name, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(cid, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(cid, name, OBJPROP_SELECTABLE, false);
      ObjectSetString(cid, name, OBJPROP_TOOLTIP,
                      StringFormat("Setup D1 : +%.2f %%", m_signal.GetLastRisePercent()));
   }

   void DrawEntryArrow()
   {
      if(!m_cfg.showVisuals || m_chart == NULL) return;

      string name = GAR_OBJ_PREFIX + "Entry_" + IntegerToString((long)m_positionSessionKey);
      long   cid  = m_chart.GetChartId();

      ObjectDelete(cid, name);
      if(!ObjectCreate(cid, name, OBJ_ARROW_BUY, 0, TimeCurrent(), m_entryPrice))
         return;

      ObjectSetInteger(cid, name, OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(cid, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(cid, name, OBJPROP_SELECTABLE, false);
      ObjectSetString(cid, name, OBJPROP_TOOLTIP, "Entree ouverture session asiatique");
   }

   //--- Segments SL / TP sur la duree de la session
   void DrawLevelLines(double sl, double tp)
   {
      if(!m_cfg.showVisuals || m_chart == NULL) return;

      long     cid       = m_chart.GetChartId();
      datetime endOfSess = m_scheduler.ToChartTime(m_scheduler.SessionEnd(m_positionSessionKey));
      string   suffix    = IntegerToString((long)m_positionSessionKey);

      if(sl > 0.0)
      {
         string name = GAR_OBJ_PREFIX + "SL_" + suffix;
         ObjectDelete(cid, name);
         if(ObjectCreate(cid, name, OBJ_TREND, 0, m_entryTime, sl, endOfSess, sl))
         {
            ObjectSetInteger(cid, name, OBJPROP_COLOR, clrCrimson);
            ObjectSetInteger(cid, name, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(cid, name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(cid, name, OBJPROP_SELECTABLE, false);
            ObjectSetString(cid, name, OBJPROP_TOOLTIP, "Stop Loss");
         }
      }

      if(tp > 0.0)
      {
         string name = GAR_OBJ_PREFIX + "TP_" + suffix;
         ObjectDelete(cid, name);
         if(ObjectCreate(cid, name, OBJ_TREND, 0, m_entryTime, tp, endOfSess, tp))
         {
            ObjectSetInteger(cid, name, OBJPROP_COLOR, clrTeal);
            ObjectSetInteger(cid, name, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(cid, name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(cid, name, OBJPROP_SELECTABLE, false);
            ObjectSetString(cid, name, OBJPROP_TOOLTIP, "Take Profit");
         }
      }
   }

   void DrawExitMarkers(double profit)
   {
      if(!m_cfg.showVisuals || m_chart == NULL) return;

      long     cid      = m_chart.GetChartId();
      datetime exitTime = TimeCurrent();
      double   exitBid  = SymbolInfoDouble(m_cfg.symbol, SYMBOL_BID);
      string   suffix   = IntegerToString((long)m_positionSessionKey);

      //--- Fleche de sortie
      string arrow = GAR_OBJ_PREFIX + "Exit_" + suffix;
      ObjectDelete(cid, arrow);
      if(ObjectCreate(cid, arrow, OBJ_ARROW_SELL, 0, exitTime, exitBid))
      {
         ObjectSetInteger(cid, arrow, OBJPROP_COLOR, profit >= 0.0 ? clrForestGreen : clrCrimson);
         ObjectSetInteger(cid, arrow, OBJPROP_WIDTH, 2);
         ObjectSetInteger(cid, arrow, OBJPROP_SELECTABLE, false);
         ObjectSetString(cid, arrow, OBJPROP_TOOLTIP,
                         StringFormat("Sortie fin de session | P&L %.2f", profit));
      }

      //--- Trace entree -> sortie
      string line = GAR_OBJ_PREFIX + "Trade_" + suffix;
      ObjectDelete(cid, line);
      if(ObjectCreate(cid, line, OBJ_TREND, 0, m_entryTime, m_entryPrice, exitTime, exitBid))
      {
         ObjectSetInteger(cid, line, OBJPROP_COLOR, profit >= 0.0 ? clrForestGreen : clrCrimson);
         ObjectSetInteger(cid, line, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(cid, line, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(cid, line, OBJPROP_SELECTABLE, false);
      }

      //--- La zone de session prend la couleur du resultat
      ColorSessionZone(m_positionSessionKey, profit);
   }

   //+------------------------------------------------------------------+
   //| ZONES DE SESSION                                                  |
   //| Un rectangle par session asiatique, tradee ou non : bornes        |
   //| horizontales = ouverture/cloture, bornes verticales = high/low.   |
   //+------------------------------------------------------------------+
   string ZoneName(datetime sessionKey) const
   {
      return GAR_OBJ_PREFIX + "Zone_" + IntegerToString((long)sessionKey);
   }

   //--- Cree ou repositionne le rectangle d'une session
   void PlaceZone(datetime sessionKey, datetime chartStart, datetime chartEnd,
                  double hi, double lo, color clr, string tooltip)
   {
      if(m_chart == NULL || hi <= lo) return;

      long   cid  = m_chart.GetChartId();
      string name = ZoneName(sessionKey);

      if(ObjectFind(cid, name) < 0)
      {
         if(!ObjectCreate(cid, name, OBJ_RECTANGLE, 0, chartStart, hi, chartEnd, lo))
            return;

         ObjectSetInteger(cid, name, OBJPROP_FILL, true);
         ObjectSetInteger(cid, name, OBJPROP_BACK, true);
         ObjectSetInteger(cid, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(cid, name, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectMove(cid, name, 0, chartStart, hi);
         ObjectMove(cid, name, 1, chartEnd,   lo);
      }

      ObjectSetInteger(cid, name, OBJPROP_COLOR, clr);
      ObjectSetString(cid, name, OBJPROP_TOOLTIP, tooltip);
   }

   //--- Recolore une zone une fois le trade denoue
   void ColorSessionZone(datetime sessionKey, double profit)
   {
      if(!m_cfg.showVisuals || !m_cfg.drawSessionZones || m_chart == NULL || sessionKey == 0)
         return;

      long   cid  = m_chart.GetChartId();
      string name = ZoneName(sessionKey);

      if(ObjectFind(cid, name) < 0)
         return;

      ObjectSetInteger(cid, name, OBJPROP_COLOR, profit >= 0.0 ? m_cfg.zoneWinColor : m_cfg.zoneLossColor);
      ObjectSetString(cid, name, OBJPROP_TOOLTIP,
                      StringFormat("Session asiatique tradee | P&L %.2f", profit));
   }

   //+------------------------------------------------------------------+
   //| Suivi en direct de la zone de la session en cours                 |
   //| High/low accumules tick par tick : bien moins couteux qu'un       |
   //| CopyRates a chaque tick.                                          |
   //+------------------------------------------------------------------+
   void TrackCurrentZone(datetime now, bool inSession, datetime sessionKey)
   {
      if(!m_cfg.showVisuals || !m_cfg.drawSessionZones || m_chart == NULL)
         return;

      if(!inSession || sessionKey == 0)
         return;

      double bid = SymbolInfoDouble(m_cfg.symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return;

      //--- Nouvelle session : on repart d'une plage vierge
      if(sessionKey != m_zoneSessionKey)
      {
         m_zoneSessionKey = sessionKey;
         m_zoneHigh       = bid;
         m_zoneLow        = bid;
         m_lastZoneRedraw = 0;
      }

      bool extended = false;
      if(bid > m_zoneHigh) { m_zoneHigh = bid; extended = true; }
      if(bid < m_zoneLow)  { m_zoneLow  = bid; extended = true; }

      //--- Redessin : a chaque extension, sinon une fois par minute
      datetime minuteBucket = (datetime)(((long)now / 60) * 60);
      if(!extended && minuteBucket == m_lastZoneRedraw)
         return;
      m_lastZoneRedraw = minuteBucket;

      datetime chartStart = m_scheduler.ToChartTime(sessionKey);
      datetime chartEnd   = TimeCurrent();

      PlaceZone(sessionKey, chartStart, chartEnd, m_zoneHigh, m_zoneLow, m_cfg.zoneColor,
                StringFormat("Session asiatique en cours | range %s - %s",
                             DoubleToString(m_zoneLow,  (int)SymbolInfoInteger(m_cfg.symbol, SYMBOL_DIGITS)),
                             DoubleToString(m_zoneHigh, (int)SymbolInfoInteger(m_cfg.symbol, SYMBOL_DIGITS))));
   }

   //+------------------------------------------------------------------+
   //| Fige la zone a la fin de la session (bornes definitives)          |
   //+------------------------------------------------------------------+
   void FinalizeZone(datetime sessionKey)
   {
      if(!m_cfg.showVisuals || !m_cfg.drawSessionZones || m_chart == NULL || sessionKey == 0)
         return;

      double hi, lo;
      if(!SessionRange(sessionKey, hi, lo))
         return;

      PlaceZone(sessionKey,
                m_scheduler.ToChartTime(sessionKey),
                m_scheduler.ToChartTime(m_scheduler.SessionEnd(sessionKey)),
                hi, lo, m_cfg.zoneColor, "Session asiatique");
   }

   //--- High/low reels d'une session, lus sur l'historique M15
   bool SessionRange(datetime sessionKey, double &hi, double &lo)
   {
      hi = 0.0;
      lo = 0.0;

      datetime start = m_scheduler.ToChartTime(sessionKey);
      datetime end   = m_scheduler.ToChartTime(m_scheduler.SessionEnd(sessionKey));

      MqlRates rates[];
      int copied = CopyRates(m_cfg.symbol, PERIOD_M15, start, end, rates);
      if(copied <= 0)
         return false;   // week-end, jour ferie : rien a dessiner

      hi = rates[0].high;
      lo = rates[0].low;

      for(int i = 1; i < copied; i++)
      {
         hi = MathMax(hi, rates[i].high);
         lo = MathMin(lo, rates[i].low);
      }

      return (hi > lo);
   }

   //+------------------------------------------------------------------+
   //| Dessine les sessions passees au demarrage (lisibilite backtest)   |
   //+------------------------------------------------------------------+
   void DrawHistoricalZones()
   {
      if(!m_cfg.showVisuals || !m_cfg.drawSessionZones || m_chart == NULL)
         return;

      if(m_cfg.zoneHistoryCount <= 0)
         return;

      datetime baseKey = m_scheduler.LastOpen(m_scheduler.Now());
      int drawn = 0;

      for(int i = 0; i < m_cfg.zoneHistoryCount; i++)
      {
         datetime key = (datetime)(baseKey - (long)i * SECONDS_PER_DAY);

         if(!m_scheduler.IsSessionDayAllowed(key))
            continue;

         double hi, lo;
         if(!SessionRange(key, hi, lo))
            continue;

         PlaceZone(key,
                   m_scheduler.ToChartTime(key),
                   m_scheduler.ToChartTime(m_scheduler.SessionEnd(key)),
                   hi, lo, m_cfg.zoneColor, "Session asiatique");
         drawn++;
      }

      Logger::Info(StringFormat("%d zone(s) de session dessinee(s) sur l'historique", drawn));
   }

   //+------------------------------------------------------------------+
   //| Panneau d'information (le volet "indicateur")                     |
   //+------------------------------------------------------------------+
   void UpdateDisplay(datetime now, bool inSession, datetime sessionKey)
   {
      if(!m_cfg.showVisuals || m_chart == NULL)
         return;

      string stateText = "";
      color  stateColor = clrDimGray;

      switch(m_state)
      {
         case GAR_ARMED:
            stateText  = "SIGNAL ARME - attente ouverture Asie";
            stateColor = clrDarkOrange;
            break;
         case GAR_IN_POSITION:
            stateText  = "EN POSITION - cloture a la fin de session";
            stateColor = clrForestGreen;
            break;
         default:
            stateText  = "EN VEILLE - pas de setup D1";
            stateColor = clrDimGray;
            break;
      }

      // Anti-spam : on ne redessine que si quelque chose a change
      string signature = stateText + "|" + IntegerToString((long)sessionKey) + "|" + (inSession ? "1" : "0");
      if(signature == m_lastStatusLine)
         return;
      m_lastStatusLine = signature;

      string lines[];
      ArrayResize(lines, 8);

      lines[0] = "GOLD ASIA REVERSAL";
      lines[1] = "Etat      : " + stateText;
      lines[2] = "Setup D1  : " + m_signal.Describe();
      lines[3] = StringFormat("Derniere D1 : %+.2f %%", m_signal.GetLastRisePercent());
      lines[4] = "Session   : " + m_scheduler.Describe();
      lines[5] = "Sorties   : " + m_exitLevels.Describe();
      lines[6] = inSession
                 ? StringFormat("En session depuis %d min", m_scheduler.MinutesSinceOpen(sessionKey, now))
                 : "Prochaine ouverture : " + TimeToString(m_scheduler.NextOpen(now), TIME_DATE | TIME_MINUTES);
      lines[7] = StringFormat("Trades : %d ouverts / %d clotures | cumul %.2f",
                              m_tradesOpened, m_tradesClosed, m_cumulatedProfit);

      m_chart.ShowMultiLineInfo(lines, CORNER_LEFT_UPPER, 10, 40, 18, stateColor, 9, "GARInfo");
   }

public:
   GoldAsiaTrader()
   {
      m_chart              = NULL;
      m_state              = GAR_IDLE;
      m_lastD1Bar          = 0;
      m_positionSessionKey = 0;
      m_decidedSessionKey  = 0;
      m_prevSessionKey     = 0;
      m_firstTickDone      = false;
      m_zoneSessionKey     = 0;
      m_zoneHigh           = 0.0;
      m_zoneLow            = 0.0;
      m_lastZoneRedraw     = 0;
      m_entryTime          = 0;
      m_entryPrice         = 0.0;
      m_tradesOpened       = 0;
      m_tradesClosed       = 0;
      m_cumulatedProfit    = 0.0;
      m_lastStatusLine     = "";
   }

   //+------------------------------------------------------------------+
   //| Initialisation                                                    |
   //+------------------------------------------------------------------+
   bool Initialize(GoldAsiaConfig &config,
                   double minRisePercent, int bearishBarsRequired,
                   bool ignoreSundayBar, ENUM_RISE_MODE riseMode,
                   int asiaStartHHMM, int asiaEndHHMM,
                   bool useServerTime, string tradeDays,
                   ENUM_SL_METHOD slMethod, ENUM_TIMEFRAMES atrTimeframe, int atrPeriod,
                   double slAtrMultiplier, int slFixedPoints, int slBufferPoints,
                   int minSlPoints, int maxSlPoints,
                   ENUM_TP_MODE tpMode, double rrRatio, double tpAtrMultiplier, int tpFixedPoints,
                   ChartManager *chartManager)
   {
      m_cfg   = config;
      m_chart = chartManager;

      if(!m_signal.Configure(m_cfg.symbol, minRisePercent, bearishBarsRequired, ignoreSundayBar, riseMode))
         return false;

      if(!m_scheduler.Configure(asiaStartHHMM, asiaEndHHMM, useServerTime, tradeDays))
         return false;

      if(!m_exitLevels.Configure(m_cfg.symbol, slMethod, atrTimeframe, atrPeriod,
                                 slAtrMultiplier, slFixedPoints, slBufferPoints,
                                 minSlPoints, maxSlPoints,
                                 tpMode, rrRatio, tpAtrMultiplier, tpFixedPoints))
         return false;

      m_trade.SetExpertMagicNumber(m_cfg.magic);
      m_trade.SetDeviationInPoints(m_cfg.slippage);
      m_trade.SetTypeFilling(PickFillingMode());
      m_trade.SetAsyncMode(false);

      //--- Reprise apres redemarrage : adopter une position deja ouverte
      ulong ticket = 0;
      if(HasOpenPosition(ticket))
      {
         datetime now = m_scheduler.Now();
         m_state              = GAR_IN_POSITION;
         m_positionSessionKey = m_scheduler.IsInSession(now) ? m_scheduler.SessionKey(now) : 0;
         m_entryTime          = m_position.Time();
         m_entryPrice         = m_position.PriceOpen();

         Logger::Warning(StringFormat("Position #%I64u deja ouverte reprise en gestion (session %s)",
                                      ticket,
                                      m_positionSessionKey > 0
                                        ? TimeToString(m_positionSessionKey, TIME_DATE | TIME_MINUTES)
                                        : "hors session - cloture au prochain tick"));
      }

      Logger::Info("Setup D1  : " + m_signal.Describe());
      Logger::Info("Session   : " + m_scheduler.Describe());
      Logger::Info("Sorties   : " + m_exitLevels.Describe());

      if(useServerTime)
         Logger::Warning("Mode heure serveur actif : un decalage d'1 h apparaitra aux changements d'heure d'ete");

      DrawHistoricalZones();

      return true;
   }

   //+------------------------------------------------------------------+
   //| Boucle principale                                                 |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      datetime now       = m_scheduler.Now();
      bool     inSession = m_scheduler.IsInSession(now);
      datetime sessionKey = inSession ? m_scheduler.SessionKey(now) : 0;

      //--- Transition d'ouverture : le tick precedent n'appartenait pas a cette
      //    session. C'est le vrai signal "ouverture", independamment de l'heure
      //    murale (le marche peut ouvrir en retard).
      datetime prevKey      = m_prevSessionKey;
      bool     observedOpen  = m_firstTickDone && (sessionKey != 0) && (sessionKey != prevKey);
      bool     observedClose = m_firstTickDone && (prevKey != 0)    && (sessionKey != prevKey);

      m_prevSessionKey = sessionKey;
      m_firstTickDone  = true;

      //--- Zones de session : figer celle qui vient de se terminer, suivre celle en cours
      if(observedClose)
         FinalizeZone(prevKey);

      TrackCurrentZone(now, inSession, sessionKey);

      ulong ticket = 0;
      bool  hasPos = HasOpenPosition(ticket);

      //--- A. Une position ouverte prime sur tout le reste
      if(hasPos)
      {
         m_state = GAR_IN_POSITION;

         // Position orpheline (redemarrage, coupure) : on l'adopte
         if(m_positionSessionKey == 0 && inSession)
            m_positionSessionKey = sessionKey;

         bool sessionOver = (!inSession) || (sessionKey != m_positionSessionKey);

         if(sessionOver)
         {
            string reason = inSession ? "session suivante atteinte" : "fin de session asiatique";
            if(ClosePosition(reason))
            {
               m_state              = GAR_IDLE;
               m_positionSessionKey = 0;
            }
         }

         UpdateDisplay(now, inSession, sessionKey);
         return;
      }

      //--- La position a disparu entre deux ticks : SL ou TP touche
      if(m_state == GAR_IN_POSITION)
      {
         Logger::Info("Position fermee hors gestion EA (SL/TP atteint)");
         m_state              = GAR_IDLE;
         m_positionSessionKey = 0;
      }

      //--- B. Nouvelle bougie D1 : le signal precedent expire, on reevalue
      datetime currentD1 = iTime(m_cfg.symbol, PERIOD_D1, 0);
      if(currentD1 > 0 && currentD1 != m_lastD1Bar)
      {
         m_lastD1Bar = currentD1;
         m_state     = GAR_IDLE;

         if(m_signal.Evaluate())
         {
            m_state = GAR_ARMED;

            datetime sigBar = m_signal.GetSignalBarTime();
            double   low    = iLow(m_cfg.symbol, PERIOD_D1, iBarShift(m_cfg.symbol, PERIOD_D1, sigBar));
            DrawSignalArrow(sigBar, low);

            // Si la session courante n'a pas encore ete arbitree, c'est ELLE
            // la cible - pas la suivante.
            bool targetIsCurrent = inSession && sessionKey != 0 && sessionKey != m_decidedSessionKey;

            Logger::Info(StringFormat("Achat arme pour la session asiatique du %s%s",
                                      TimeToString(targetIsCurrent ? sessionKey : m_scheduler.NextOpen(now),
                                                   TIME_DATE | TIME_MINUTES),
                                      targetIsCurrent ? " (deja ouverte)" : ""));
         }
      }

      //--- C. Ouverture de session avec un signal arme
      if(m_state == GAR_ARMED && inSession && sessionKey != 0 && sessionKey != m_decidedSessionKey)
         TryEnter(now, sessionKey, observedOpen);

      UpdateDisplay(now, inSession, sessionKey);
   }

   //+------------------------------------------------------------------+
   //| Arret                                                             |
   //+------------------------------------------------------------------+
   void Deinitialize(const int reason)
   {
      Logger::Info(StringFormat("Bilan : %d trades ouverts, %d clotures, P&L cumule %.2f %s",
                                m_tradesOpened, m_tradesClosed, m_cumulatedProfit,
                                AccountInfoString(ACCOUNT_CURRENCY)));

      // Par defaut on GARDE les traces : apres un backtest visuel, les zones de
      // session et les marqueurs de trade sont justement ce qu'on veut relire.
      if(m_chart != NULL && m_cfg.clearDrawingsOnExit)
      {
         long cid = m_chart.GetChartId();
         ObjectsDeleteAll(cid, GAR_OBJ_PREFIX);
         Logger::Info("Traces graphiques effacees");
      }
   }
};
//+------------------------------------------------------------------+
