//+------------------------------------------------------------------+
//|                                          JT_BaseStrategy.mqh     |
//|                      Classe de base pour toutes les stratégies   |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"

#include <Trade/Trade.mqh>
#include "JT_Enums.mqh"
#include "JT_Indicators.mqh"
#include "JT_Positions.mqh"
#include "JT_Utils.mqh"
#include "JT_TradeTracker.mqh"

//+------------------------------------------------------------------+
//| Classe de base abstraite pour toutes les stratégies              |
//+------------------------------------------------------------------+
class JTBaseStrategy
{
protected:
   // Configuration symbole et timeframe
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   ulong             m_magic;
   
   // Indicateurs communs
   IndicatorHandles  m_indicators;
   IndicatorBuffers  m_buffers;
   
   // Trade management
   CTrade*           m_trade;
   JTTradeTracker*   m_tracker;
   
   // Filtres activés
   bool              m_useRSIFilter;
   bool              m_useEMAFilter;
   bool              m_useDivergence;
   
   // Paramètres Risk Management
   ENUM_RISK_BASE    m_riskBase;
   double            m_riskPercent;
   double            m_minRR;
   bool              m_onePositionPerConfig;
   
   // Paramètres SL/TP
   int               m_slPeriod;
   int               m_tpPeriod;
   double            m_atrMultiplier;
   int               m_atrPeriod;
   
   // Filtre horaire
   bool              m_useTimeFilter;
   string            m_hourRanges;
   
   // Filtre jours
   bool              m_useDayFilter;
   string            m_dayRanges;
   
   // Protection Daily Drawdown
   bool              m_useDailyDD;
   ENUM_DD_MODE      m_ddMode;
   double            m_ddPercent;
   double            m_ddFixedAmount;
   bool              m_ddCloseAll;
   bool              m_ddUseEquity;
   datetime          m_ddLastResetDate;
   double            m_ddStartBalance;
   double            m_ddStartEquity;
   bool              m_ddLimitReached;
   
   // Gestion de position
   bool              m_beOnOppositeBand;
   int               m_beOffsetPoints;
   bool              m_useFlatTime;
   int               m_flatHour;
   int               m_flatMinute;
   int               m_touchPadPoints;
   
   // Filtre de direction
   ENUM_TRADE_DIRECTION m_tradeDirection;
   
   // Variables internes
   datetime          m_lastBarTime;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   JTBaseStrategy(string symbol, ENUM_TIMEFRAMES tf, ulong magic)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_magic = magic;
      
      m_trade = new CTrade();
      m_tracker = NULL;
      
      // Valeurs par défaut
      m_useRSIFilter = true;
      m_useEMAFilter = false;
      m_useDivergence = false;
      
      m_riskBase = RISK_EQUITY;
      m_riskPercent = 0.5;
      m_minRR = 2.0;
      m_onePositionPerConfig = true;
      
      m_slPeriod = 50;
      m_tpPeriod = 30;
      m_atrMultiplier = 2.0;
      m_atrPeriod = 14;
      
      m_useTimeFilter = false;
      m_hourRanges = "8-10;16";
      
      m_useDayFilter = false;
      m_dayRanges = "1-5";
      
      m_useDailyDD = false;
      m_ddMode = DD_PERCENT;
      m_ddPercent = 2.0;
      m_ddFixedAmount = 200.0;
      m_ddCloseAll = false;
      m_ddUseEquity = true;
      m_ddLastResetDate = 0;
      m_ddStartBalance = 0.0;
      m_ddStartEquity = 0.0;
      m_ddLimitReached = false;
      
      m_beOnOppositeBand = false;
      m_beOffsetPoints = 10;
      m_useFlatTime = false;
      m_flatHour = 23;
      m_flatMinute = 40;
      m_touchPadPoints = 5;
      
      m_tradeDirection = TRADE_BOTH;
      
      m_lastBarTime = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   virtual ~JTBaseStrategy()
   {
      if(m_tracker != NULL) {
         m_tracker.PrintReport();
         delete m_tracker;
         m_tracker = NULL;
      }
      
      if(m_trade != NULL) {
         delete m_trade;
         m_trade = NULL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Méthodes virtuelles pures (à implémenter obligatoirement)        |
   //+------------------------------------------------------------------+
   
   // Détection du signal de trading (BUY=+1, SELL=-1, NONE=0)
   virtual int DetectSignal() = 0;
   
   // Validation du signal avant entrée (filtres spécifiques à la stratégie)
   virtual bool ValidateEntry(int signal) = 0;
   
   //+------------------------------------------------------------------+
   //| Méthodes virtuelles (peuvent être overridées)                    |
   //+------------------------------------------------------------------+
   
   // Nom de la stratégie
   virtual string GetStrategyName() { return "BaseStrategy"; }
   
   // Initialisation spécifique à la stratégie
   virtual bool InitStrategy() { return true; }
   
   // Deinitialisation spécifique
   virtual void DeinitStrategy() {}
   
   // Gestion de position spécifique
   virtual void ManagePositionStrategy(ulong ticket) {}
   
   // Calcul des niveaux SL/TP (peut être overridé)
   virtual bool CalculateLevels(bool isBuy, double &sl, double &tp)
   {
      // Utilise le calcul générique basé sur swings avec fallback ATR
      return CalculateSwingSLTP(
         m_symbol,
         m_timeframe,
         isBuy,
         m_slPeriod,
         m_tpPeriod,
         sl,
         tp,
         0.0,          // trailing offset (non utilisé ici)
         m_minRR,      // RR minimum
         1000,         // sécurité max bars
         m_atrMultiplier,
         m_atrPeriod
      );
   }
   
   //+------------------------------------------------------------------+
   //| Méthodes communes (non overridables)                             |
   //+------------------------------------------------------------------+
   
   // Initialisation complète
   bool Init()
   {
      LogMessage("Initialisation de la stratégie: " + GetStrategyName());
      
      // Configurer le magic number
      if(m_trade != NULL) {
         m_trade.SetExpertMagicNumber((long)m_magic);
      }
      
      // Initialiser la protection Daily Drawdown
      if(m_useDailyDD) {
         InitDailyDD();
      }
      
      // Initialisation spécifique à la stratégie
      if(!InitStrategy()) {
         LogError("Échec de l'initialisation spécifique de la stratégie");
         return false;
      }
      
      LogMessage("Stratégie " + GetStrategyName() + " initialisée avec succès");
      LogMessage("Symbol: " + m_symbol + " | Timeframe: " + EnumToString(m_timeframe) + " | Magic: " + IntegerToString(m_magic));
      
      return true;
   }
   
   // Deinitialisation complète
   void Deinit()
   {
      LogMessage("Deinitialisation de la stratégie: " + GetStrategyName());
      
      // Deinitialisation spécifique
      DeinitStrategy();
      
      // Afficher le rapport final du tracker
      if(m_tracker != NULL) {
         m_tracker.PrintReport();
      }
   }
   
   // Appelé à chaque tick
   void OnTick()
   {
      // Vérifier les filtres temporels
      if(!IsHourAllowed()) return;
      if(!IsDayAllowed()) return;
      
      // Vérifier le Daily Drawdown
      if(CheckDailyDDLimit()) {
         static datetime lastDDWarning = 0;
         if(TimeCurrent() - lastDDWarning > 300) {
            double currentDD = GetDailyDrawdown();
            LogMessage("⛔ Trading bloqué - DD journalier: " + 
                      DoubleToString(currentDD, 2) + " (attente nouveau jour)");
            lastDDWarning = TimeCurrent();
         }
         return;
      }
      
      // Suivre les trades actifs
      UpdateActiveTrades();
      
      // Afficher le statut DD
      if(m_useDailyDD) {
         DisplayDDStatus();
      }
      
      // Gestion des positions en continu
      ManageOpenPositions();
      
      // Vérifier les trades fermés automatiquement
      CheckClosedTrades();
      
      // Détection de nouvelle bougie
      if(NewBar()) {
         OnNewBar();
      }
   }
   
   // Appelé sur nouvelle bougie
   void OnNewBar()
   {
      // Détecter un signal
      int signal = DetectSignal();
      
      if(signal == 0) {
         return; // Pas de signal
      }
      
      // Vérifier si on a déjà une position
      if(HaveOpenPosition()) {
         LogMessage("Position déjà ouverte sur " + m_symbol + " - signal ignoré");
         return;
      }
      
      // Appliquer le filtre de direction
      if(m_tradeDirection == TRADE_ONLY_BUY && signal < 0) return;
      if(m_tradeDirection == TRADE_ONLY_SELL && signal > 0) return;
      
      // Valider le signal avec les filtres spécifiques
      if(!ValidateEntry(signal)) {
         LogMessage("Signal rejeté par les filtres de validation");
         return;
      }
      
      // Exécuter le trade
      ExecuteTrade(signal);
   }
   
   //+------------------------------------------------------------------+
   //| Getters/Setters                                                  |
   //+------------------------------------------------------------------+
   
   void SetRiskBase(ENUM_RISK_BASE base) { m_riskBase = base; }
   void SetRiskPercent(double risk) { m_riskPercent = risk; }
   void SetMinRR(double rr) { m_minRR = rr; }
   void SetOnePositionPerConfig(bool enable) { m_onePositionPerConfig = enable; }
   
   void SetSLTPParameters(int slPeriod, int tpPeriod, double atrMult, int atrPeriod) {
      m_slPeriod = slPeriod;
      m_tpPeriod = tpPeriod;
      m_atrMultiplier = atrMult;
      m_atrPeriod = atrPeriod;
   }
   
   void SetTimeFilter(bool enable, string hourRanges = "8-10;16") {
      m_useTimeFilter = enable;
      m_hourRanges = hourRanges;
   }
   
   void SetDayFilter(bool enable, string dayRanges = "1-5") {
      m_useDayFilter = enable;
      m_dayRanges = dayRanges;
   }
   
   void SetDailyDD(bool enable, ENUM_DD_MODE mode, double percent, double fixed, bool closeAll, bool useEquity) {
      m_useDailyDD = enable;
      m_ddMode = mode;
      m_ddPercent = percent;
      m_ddFixedAmount = fixed;
      m_ddCloseAll = closeAll;
      m_ddUseEquity = useEquity;
   }
   
   void SetPositionManagement(bool beOnOppositeBand, int beOffset, bool useFlatTime, int flatHour, int flatMinute, int touchPad) {
      m_beOnOppositeBand = beOnOppositeBand;
      m_beOffsetPoints = beOffset;
      m_useFlatTime = useFlatTime;
      m_flatHour = flatHour;
      m_flatMinute = flatMinute;
      m_touchPadPoints = touchPad;
   }
   
   void SetTradeDirection(ENUM_TRADE_DIRECTION direction) { m_tradeDirection = direction; }
   
   void EnableRSIFilter(bool enable) { m_useRSIFilter = enable; }
   void EnableEMAFilter(bool enable) { m_useEMAFilter = enable; }
   void EnableDivergence(bool enable) { m_useDivergence = enable; }
   
   void SetTracker(JTTradeTracker* tracker) { m_tracker = tracker; }
   
   string GetSymbol() const { return m_symbol; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
   ulong GetMagic() const { return m_magic; }
   
protected:
   //+------------------------------------------------------------------+
   //| Méthodes helper protégées                                        |
   //+------------------------------------------------------------------+
   
   // Détection de nouvelle bougie
   bool NewBar()
   {
      MqlRates r[];
      if(CopyRates(m_symbol, m_timeframe, 0, 2, r) < 2) return false;
      ArraySetAsSeries(r, true);
      if(r[0].time != m_lastBarTime) {
         m_lastBarTime = r[0].time;
         return true;
      }
      return false;
   }
   
   // Vérifier si une position est ouverte
   bool HaveOpenPosition()
   {
      if(!m_onePositionPerConfig) return false;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && 
            PositionGetInteger(POSITION_MAGIC) == m_magic) {
            return true;
         }
      }
         return false;
   }
   
   // Normaliser le volume
   double NormalizeVolume(double lots)
   {
      double minv = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxv = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      lots = MathMax(minv, MathMin(maxv, lots));
      return MathRound(lots / step) * step;
   }
   
   // Calculer le volume basé sur le risque
   double CalcLotsByRisk(double slDistPrice)
   {
      if(slDistPrice <= 0) return 0.0;
      
      double capital = (m_riskBase == RISK_BALANCE) ? 
                       AccountInfoDouble(ACCOUNT_BALANCE) : 
                       AccountInfoDouble(ACCOUNT_EQUITY);
      double risk = capital * (m_riskPercent / 100.0);
      
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickValue <= 0 || tickSize <= 0) return 0.0;
      
      double moneyPerLot = (slDistPrice / tickSize) * tickValue;
      if(moneyPerLot <= 0) return 0.0;
      
      return NormalizeVolume(risk / moneyPerLot);
   }
   
   // Exécuter un trade
   void ExecuteTrade(int signal)
   {
      bool isBuy = (signal > 0);
      
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Calculer SL/TP
      double sl = 0, tp = 0;
      if(!CalculateLevels(isBuy, sl, tp)) {
         LogError("Erreur lors du calcul des niveaux SL/TP");
         return;
      }
      
      // Calculer le volume
      double riskPrice = isBuy ? (bid - sl) : (sl - ask);
      if(riskPrice <= 0) {
         LogError("Distance de SL invalide");
         return;
      }
      
      double lots = CalcLotsByRisk(riskPrice);
      if(lots <= 0) {
         LogError("Volume calculé invalide: " + DoubleToString(lots, 2));
         return;
      }
      
      // Calculer le ratio risque/récompense
      double entryPrice = isBuy ? ask : bid;
      double reward = isBuy ? (tp - entryPrice) : (entryPrice - tp);
      double risk = isBuy ? (entryPrice - sl) : (sl - entryPrice);
      double rr = (risk > 0) ? (reward / risk) : 0;
      
      // Vérifier le seuil RR minimum
      if(m_minRR > 0 && rr < m_minRR) {
         LogMessage("Trade rejeté - RR insuffisant: 1:" + DoubleToString(rr, 2) + 
                   " < minimum requis: 1:" + DoubleToString(m_minRR, 2));
         return;
      }
      
      // Préparer le commentaire
      string dirStr = isBuy ? "BUY" : "SELL";
      string orderComment = StringFormat("%s %s|RR:%.2f", GetStrategyName(), dirStr, rr);
      
      // Log
      LogMessage("Signal " + dirStr + " - Entry: " + DoubleToString(entryPrice, 5) + 
                ", SL: " + DoubleToString(sl, 5) + 
                ", TP: " + DoubleToString(tp, 5) + 
                ", RR: 1:" + DoubleToString(rr, 2) + 
                ", Lots: " + DoubleToString(lots, 2));
      
      // Ouvrir la position
      if(isBuy) {
         OpenBuyPosition(m_trade, m_symbol, lots, ask, sl, tp, orderComment);
      } else {
         OpenSellPosition(m_trade, m_symbol, lots, bid, sl, tp, orderComment);
      }
      
      // Tracker
      if(m_trade.ResultOrder() > 0 && m_tracker != NULL) {
         RecordTradeInTracker(m_trade.ResultOrder(), isBuy, rr);
      }
   }
   
   // Enregistrer le trade dans le tracker (à override si besoin)
   virtual void RecordTradeInTracker(ulong ticket, bool isBuy, double rr)
   {
      // Implémentation par défaut (vide)
      // Les stratégies dérivées peuvent override pour ajouter des infos spécifiques
   }
   
   // Mettre à jour les trades actifs
   void UpdateActiveTrades()
   {
      if(m_tracker == NULL) return;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic) {
               m_tracker.UpdateTrade(ticket);
            }
         }
      }
   }
   
   // Gestion des positions ouvertes
   void ManageOpenPositions()
   {
      // Récupérer les données d'indicateurs si nécessaire
      if(!GetIndicatorData(m_indicators, m_buffers, 2, false)) return;
      
      double upper0 = m_buffers.BBUpper[0];
      double middle0 = m_buffers.BBMiddle[0];
      double lower0 = m_buffers.BBLower[0];
      double upper1 = m_buffers.BBUpper[1];
      double lower1 = m_buffers.BBLower[1];
      
      MqlRates bar[];
      if(CopyRates(m_symbol, m_timeframe, 0, 1, bar) < 1) return;
      ArraySetAsSeries(bar, true);
      double barHigh = bar[0].high;
      double barLow = bar[0].low;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double pad = m_touchPadPoints * point;
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      // Heure limite pour flat time
      MqlDateTime ts;
      TimeToStruct(TimeCurrent(), ts);
      bool timeToFlat = (ts.hour > m_flatHour) || (ts.hour == m_flatHour && ts.min >= m_flatMinute);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         
         long type = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         
         // Break-Even sur bande opposée
         if(m_beOnOppositeBand) {
            bool touchedOpposite = false;
            if(type == POSITION_TYPE_BUY) {
               touchedOpposite = (barHigh >= upper1 - pad || bid >= upper0 - pad);
            }
            if(type == POSITION_TYPE_SELL) {
               touchedOpposite = (barLow <= lower1 + pad || ask <= lower0 + pad);
            }
            
            if(touchedOpposite) {
               if(type == POSITION_TYPE_BUY) {
                  double newSL = openPrice + m_beOffsetPoints * point;
                  if(sl < newSL) ModifyPosition(m_trade, ticket, newSL, tp);
               }
               if(type == POSITION_TYPE_SELL) {
                  double newSL = openPrice - m_beOffsetPoints * point;
                  if(sl == 0.0 || sl > newSL) ModifyPosition(m_trade, ticket, newSL, tp);
               }
            }
         }
         
         // Flat time
         if(m_useFlatTime && timeToFlat) {
            ClosePosition(m_trade, ticket, "Flat time", 0);
            if(m_tracker != NULL) {
               m_tracker.RecordTradeClose(ticket, "Flat Time");
            }
         }
         
         // Gestion spécifique à la stratégie
         ManagePositionStrategy(ticket);
      }
   }
   
   // Vérifier les trades fermés
   void CheckClosedTrades()
   {
      if(m_tracker == NULL) return;
      
      static datetime lastCheck = 0;
      datetime currentTime = TimeCurrent();
      
      if(currentTime - lastCheck < 30) return;
      lastCheck = currentTime;
      
      if(!HistorySelect(currentTime - 86400, currentTime)) return;
      
      uint totalDeals = HistoryDealsTotal();
      for(uint i = 0; i < totalDeals; i++) {
         ulong dealTicket = HistoryDealGetTicket(i);
         
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == m_magic &&
            HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            
            ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
            
            string reason = "";
            if(StringFind(comment, "tp") >= 0 || StringFind(comment, "TP") >= 0)
               reason = "TP";
            else if(StringFind(comment, "sl") >= 0 || StringFind(comment, "SL") >= 0)
               reason = "SL";
            else
               reason = "Auto Close";
            
            m_tracker.RecordTradeClose(posTicket, reason);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Filtres temporels                                                |
   //+------------------------------------------------------------------+
   
   bool IsHourAllowed()
   {
      if(!m_useTimeFilter) return true;
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentHour = dt.hour;
      
      bool isAllowed = IsHourAllowedCustom(m_hourRanges);
      
      if(!isAllowed) {
         static int lastHourLogged = -1;
         if(lastHourLogged != currentHour) {
            LogMessage("Heure actuelle: " + IntegerToString(currentHour) + 
                      ":00 - Trading non autorisé selon les plages: " + m_hourRanges);
            lastHourLogged = currentHour;
         }
      }
      
      return isAllowed;
   }
   
   bool IsDayAllowed()
   {
      if(!m_useDayFilter) return true;
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentDay = dt.day_of_week;
      
      bool isAllowed = IsDayAllowedCustom(m_dayRanges);
      
      if(!isAllowed) {
         static int lastDayLogged = -1;
         if(lastDayLogged != currentDay) {
            string dayNames[] = {"Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"};
            LogMessage("Jour actuel: " + dayNames[currentDay] + " (" + IntegerToString(currentDay) + 
                      ") - Trading non autorisé selon: " + m_dayRanges);
            lastDayLogged = currentDay;
         }
      }
      
      return isAllowed;
   }
   
   //+------------------------------------------------------------------+
   //| Protection Daily Drawdown                                        |
   //+------------------------------------------------------------------+
   
   void InitDailyDD()
   {
      m_ddStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_ddStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_ddLastResetDate = TimeCurrent();
      m_ddLimitReached = false;
      
      LogMessage("Protection DD activée - Mode: " + 
                (m_ddMode == DD_PERCENT ? DoubleToString(m_ddPercent, 2) + "%" : 
                 DoubleToString(m_ddFixedAmount, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY)));
   }
   
   bool CheckDailyReset()
   {
      if(!m_useDailyDD) return false;
      
      MqlDateTime current, last;
      TimeToStruct(TimeCurrent(), current);
      TimeToStruct(m_ddLastResetDate, last);
      
      if(current.day != last.day || current.mon != last.mon || current.year != last.year) {
         m_ddStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_ddStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         m_ddLastResetDate = TimeCurrent();
         m_ddLimitReached = false;
         
         LogMessage("═══ NOUVEAU JOUR ═══ Daily DD réinitialisé - Capital: " + 
                   DoubleToString(m_ddStartBalance, 2));
         return true;
      }
      
      return false;
   }
   
   double GetDailyDrawdown()
   {
      if(!m_useDailyDD) return 0.0;
      
      double currentValue = m_ddUseEquity ? 
                           AccountInfoDouble(ACCOUNT_EQUITY) : 
                           AccountInfoDouble(ACCOUNT_BALANCE);
      double startValue = m_ddUseEquity ? m_ddStartEquity : m_ddStartBalance;
      
      return startValue - currentValue;
   }
   
   bool CheckDailyDDLimit()
   {
      if(!m_useDailyDD) return false;
      
      CheckDailyReset();
      
      if(m_ddLimitReached) return true;
      
      double currentDD = GetDailyDrawdown();
      double maxDD = 0.0;
      
      if(m_ddMode == DD_PERCENT) {
         double startValue = m_ddUseEquity ? m_ddStartEquity : m_ddStartBalance;
         maxDD = startValue * (m_ddPercent / 100.0);
      } else {
         maxDD = m_ddFixedAmount;
      }
      
      if(currentDD >= maxDD) {
         if(!m_ddLimitReached) {
            m_ddLimitReached = true;
            
            string ddStr = (m_ddMode == DD_PERCENT) ? 
                          DoubleToString(m_ddPercent, 2) + "%" : 
                          DoubleToString(m_ddFixedAmount, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY);
            
            LogMessage("⚠️ DAILY DRAWDOWN ATTEINT ⚠️");
            LogMessage("Perte journalière: " + DoubleToString(currentDD, 2) + 
                      " / Limite: " + DoubleToString(maxDD, 2));
            LogMessage("Trading bloqué jusqu'à demain. Seuil: " + ddStr);
            
            if(m_ddCloseAll) {
               CloseAllPositions("DD Limit");
            }
         }
         return true;
      }
      
      return false;
   }
   
   void CloseAllPositions(string reason)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && 
            PositionGetInteger(POSITION_MAGIC) == m_magic) {
            ClosePosition(m_trade, ticket, reason, 0);
            
            if(m_tracker != NULL) {
               m_tracker.RecordTradeClose(ticket, reason);
            }
         }
      }
      
      LogMessage("Toutes les positions fermées - Raison: " + reason);
   }
   
   void DisplayDDStatus()
   {
      double currentDD = GetDailyDrawdown();
      double maxDD = 0.0;
      
      if(m_ddMode == DD_PERCENT) {
         double startValue = m_ddUseEquity ? m_ddStartEquity : m_ddStartBalance;
         maxDD = startValue * (m_ddPercent / 100.0);
      } else {
         maxDD = m_ddFixedAmount;
      }
      
      double ddPercent = (maxDD > 0) ? (currentDD / maxDD) * 100.0 : 0.0;
      
      string text = "Daily DD: " + DoubleToString(currentDD, 2) + " / " + 
                    DoubleToString(maxDD, 2) + " (" + DoubleToString(ddPercent, 1) + "%)";
      
      if(m_ddLimitReached) {
         text += " ⛔ BLOQUÉ";
      }
      
      string labelName = "DD_Status_" + IntegerToString(m_magic);
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 30);
      ObjectSetString(0, labelName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, m_ddLimitReached ? clrRed : (ddPercent > 80 ? clrOrange : clrLimeGreen));
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
   }
};
