//+------------------------------------------------------------------+
//| AdxScoreTrader.mqh - Classe de trading ADX Score                |
//|                   Gestion complète du scoring et trading ADX    |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "2.0"
#property strict

#include <Trade\Trade.mqh>
#include "../../../CommonUtils/TradingUtils.mqh"
#include "../../../CommonUtils/TradingEnums.mqh"
#include "scorers/IFilterScorer.mqh"
#include "scorers/AdxScorer.mqh"
#include "scorers/RsiScorer.mqh"
#include "scorers/MaScorer.mqh"

//+------------------------------------------------------------------+
//| Constantes de scoring (comme dans l'original)                   |
//+------------------------------------------------------------------+

#define SCORE_CONFLUENCE_BONUS 3

//+------------------------------------------------------------------+
//| Classe principale de trading ADX Score                          |
//+------------------------------------------------------------------+
class AdxScoreTrader
{
private:
   // Configuration
   string m_symbol;
   int m_magicNumber;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Scorers
   AdxScorer* m_adxScorer;
   RsiScorer* m_rsiScorer;
   MaScorer* m_maScorer;
   
   // Paramètres indicateurs
   int m_adxPeriod;
   int m_rsiPeriod;
   int m_maPeriod;
   ENUM_MA_METHOD m_maMethod;
   
   // Paramètres stratégie
   int m_scoreMinEntry;
   int m_scoreHighConfidence;
   double m_riskNormal;
   double m_riskHigh;
   int m_slPoints;
   int m_tpMultiplier;
   int m_maxPositions;
   
   // Trailing Stop
   bool m_useTrailing;
   int m_trailingStart;
   int m_trailingStep;
   
   // Trade
   CTrade m_trade;
   
   // État
   datetime m_lastBarTime;
   int m_currentBuyScore;
   int m_currentSellScore;
   bool m_isInitialized;
   
   // Valeurs indicateurs actuelles
   double m_currentADX;
   double m_currentRSI;
   double m_currentMA;
   double m_currentPrice;
   
   // Valeurs précédentes pour détecter croisements
   double m_prevRSI;
   double m_prevPrice;
   double m_prevMA;
   
   // Composantes du score BUY
   int m_buyAdxScore;
   int m_buyRsiScore;
   int m_buyMaScore;
   int m_buyConfluenceScore;
   
   // Composantes du score SELL
   int m_sellAdxScore;
   int m_sellRsiScore;
   int m_sellMaScore;
   int m_sellConfluenceScore;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   AdxScoreTrader(
      string symbol,
      int magicNumber,
      ENUM_TIMEFRAMES timeframe,
      int scoreMinEntry,
      int scoreHighConfidence,
      double riskNormal,
      double riskHigh,
      int slPoints,
      int tpMultiplier,
      int maxPositions,
      int adxPeriod = 14,
      int rsiPeriod = 14,
      int maPeriod = 50,
      ENUM_MA_METHOD maMethod = MODE_SMA,
      bool useTrailing = false,
      int trailingStart = 50,
      int trailingStep = 20
   )
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_timeframe = timeframe;
      m_scoreMinEntry = scoreMinEntry;
      m_scoreHighConfidence = scoreHighConfidence;
      m_riskNormal = riskNormal;
      m_riskHigh = riskHigh;
      m_slPoints = slPoints;
      m_tpMultiplier = tpMultiplier;
      m_maxPositions = maxPositions;
      
      // Paramètres indicateurs
      m_adxPeriod = adxPeriod;
      m_rsiPeriod = rsiPeriod;
      m_maPeriod = maPeriod;
      m_maMethod = maMethod;
      
      // Trailing Stop
      m_useTrailing = useTrailing;
      m_trailingStart = trailingStart;
      m_trailingStep = trailingStep;
      
      m_adxScorer = NULL;
      m_rsiScorer = NULL;
      m_maScorer = NULL;
      
      m_lastBarTime = 0;
      m_currentBuyScore = 0;
      m_currentSellScore = 0;
      m_isInitialized = false;
      
      m_currentADX = 0;
      m_currentRSI = 0;
      m_currentMA = 0;
      m_currentPrice = 0;
      
      m_prevRSI = 0;
      m_prevPrice = 0;
      m_prevMA = 0;
      
      // Composantes du score BUY
      m_buyAdxScore = 0;
      m_buyRsiScore = 0;
      m_buyMaScore = 0;
      m_buyConfluenceScore = 0;
      
      // Composantes du score SELL
      m_sellAdxScore = 0;
      m_sellRsiScore = 0;
      m_sellMaScore = 0;
      m_sellConfluenceScore = 0;
      
      // Configuration du trade
      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(10);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                      |
   //+------------------------------------------------------------------+
   ~AdxScoreTrader()
   {
      if(m_adxScorer != NULL) delete m_adxScorer;
      if(m_rsiScorer != NULL) delete m_rsiScorer;
      if(m_maScorer != NULL) delete m_maScorer;
   }

   //+------------------------------------------------------------------+
   //| Initialisation                                                  |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      // Valider le symbole
      if(!ValidateSymbol(m_symbol))
      {
         Print("❌ Symbole invalide: ", m_symbol);
         return false;
      }
      
      // Créer les scorers
      m_adxScorer = new AdxScorer(m_symbol, m_timeframe, m_adxPeriod);
      m_rsiScorer = new RsiScorer(m_symbol, m_timeframe, m_rsiPeriod);
      m_maScorer = new MaScorer(m_symbol, m_timeframe, m_maPeriod, m_maMethod);
      
      // Initialiser les scorers
      if(!m_adxScorer.Initialize() || !m_rsiScorer.Initialize() || !m_maScorer.Initialize())
      {
         Print("❌ Erreur initialisation scorers pour ", m_symbol);
         return false;
      }
      
      m_isInitialized = true;
      Print("✅ AdxScoreTrader initialisé pour ", m_symbol, " | Magic: ", m_magicNumber);
      Print("   ADX(", m_adxPeriod, ") | RSI(", m_rsiPeriod, ") | MA(", m_maPeriod, ")");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Traitement du tick                                              |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(!m_isInitialized) return;
      
      // Vérifier nouvelle barre
      if(!IsNewBar()) return;
      
      // Mettre à jour les valeurs des indicateurs
      UpdateIndicatorValues();
      
      // Calculer les scores
      m_currentBuyScore = CalculateBuyScore();
      m_currentSellScore = CalculateSellScore();
      
      // Vérifier les signaux
      CheckTradingSignals();
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour les scores SANS trader (affichage seulement)      |
   //+------------------------------------------------------------------+
   void UpdateScoresOnly()
   {
      if(!m_isInitialized) return;
      
      // Mettre à jour les valeurs des indicateurs
      UpdateIndicatorValues();
      
      // Calculer les scores
      m_currentBuyScore = CalculateBuyScore();
      m_currentSellScore = CalculateSellScore();
      
      // NE PAS vérifier les signaux de trading ici
   }

   //+------------------------------------------------------------------+
   //| Vérifier les signaux de trading                                |
   //+------------------------------------------------------------------+
   void CheckTradingSignals()
   {
      // Vérifier le nombre de positions
      if(CountPositions() >= m_maxPositions) return;
      
      // Vérifier les signaux BUY
      if(m_currentBuyScore >= m_scoreMinEntry)
      {
         bool highConfidence = (m_currentBuyScore >= m_scoreHighConfidence);
         OpenBuy(m_currentBuyScore, highConfidence);
      }
      
      // Vérifier les signaux SELL
      if(m_currentSellScore >= m_scoreMinEntry)
      {
         bool highConfidence = (m_currentSellScore >= m_scoreHighConfidence);
         OpenSell(m_currentSellScore, highConfidence);
      }
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour les valeurs des indicateurs                      |
   //+------------------------------------------------------------------+
   void UpdateIndicatorValues()
   {
      // Sauvegarder les valeurs précédentes
      m_prevRSI = m_currentRSI;
      m_prevPrice = m_currentPrice;
      m_prevMA = m_currentMA;
      
      // Mettre à jour les scorers
      m_adxScorer.Update();
      m_rsiScorer.Update();
      m_maScorer.Update();
      
      // Récupérer les valeurs actuelles
      m_currentADX = m_adxScorer.GetCurrentValue();
      m_currentRSI = m_rsiScorer.GetCurrentValue();
      m_currentMA = m_maScorer.GetCurrentValue();
      m_currentPrice = m_maScorer.GetCurrentPrice();
   }

   //+------------------------------------------------------------------+
   //| Calculer le score BUY                                          |
   //+------------------------------------------------------------------+
   int CalculateBuyScore()
   {
      // Obtenir les scores des scorers
      m_buyAdxScore = m_adxScorer.GetBuyScore();
      m_buyRsiScore = m_rsiScorer.GetBuyScore();
      m_buyMaScore = m_maScorer.GetBuyScore();
      
      // Bonus confluence
      m_buyConfluenceScore = 0;
      if(m_adxScorer.IsHighTrend() && 
         m_rsiScorer.IsHighTrend() && 
         m_maScorer.IsHighTrend())
      {
         m_buyConfluenceScore = SCORE_CONFLUENCE_BONUS;
      }
      
      return m_buyAdxScore + m_buyRsiScore + m_buyMaScore + m_buyConfluenceScore;
   }

   //+------------------------------------------------------------------+
   //| Calculer le score SELL                                         |
   //+------------------------------------------------------------------+
   int CalculateSellScore()
   {
      // Obtenir les scores des scorers
      m_sellAdxScore = m_adxScorer.GetSellScore();
      m_sellRsiScore = m_rsiScorer.GetSellScore();
      m_sellMaScore = m_maScorer.GetSellScore();
      
      // Bonus confluence
      m_sellConfluenceScore = 0;
      if(m_adxScorer.IsHighTrend() && 
         m_rsiScorer.IsHighTrend() && 
         m_maScorer.IsHighTrend())
      {
         m_sellConfluenceScore = SCORE_CONFLUENCE_BONUS;
      }
      
      return m_sellAdxScore + m_sellRsiScore + m_sellMaScore + m_sellConfluenceScore;
   }


   //+------------------------------------------------------------------+
   //| Ouvrir position BUY                                            |
   //+------------------------------------------------------------------+
   void OpenBuy(int score, bool highConfidence)
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      double sl = NormalizeDouble(ask - m_slPoints * point, digits);
      double tp = NormalizeDouble(ask + (m_slPoints * m_tpMultiplier) * point, digits);
      
      double risk = highConfidence ? m_riskHigh : m_riskNormal;
      double lots = CalculateLots(risk, ask - sl);
      
      // Vérifier que les lots sont valides
      if(lots < SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
      {
         Print("⚠️ Lots trop petits pour ", m_symbol, ": ", lots);
         return;
      }
      
      string comment = StringFormat("ADX_BUY_%d_%s", score, highConfidence ? "HIGH" : "NORMAL");
      
      if(m_trade.Buy(lots, m_symbol, 0, sl, tp, comment))
      {
         Print("✅ BUY ouvert: ", m_symbol, " | Score: ", score, " | Lots: ", lots, " | ", comment);
      }
      else
      {
         Print("❌ Erreur BUY: ", m_symbol);
         Print("   RetCode: ", m_trade.ResultRetcode());
         Print("   Description: ", m_trade.ResultRetcodeDescription());
         Print("   Ask: ", ask, " | SL: ", sl, " | TP: ", tp, " | Lots: ", lots);
      }
   }

   //+------------------------------------------------------------------+
   //| Ouvrir position SELL                                           |
   //+------------------------------------------------------------------+
   void OpenSell(int score, bool highConfidence)
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      double sl = NormalizeDouble(bid + m_slPoints * point, digits);
      double tp = NormalizeDouble(bid - (m_slPoints * m_tpMultiplier) * point, digits);
      
      double risk = highConfidence ? m_riskHigh : m_riskNormal;
      double lots = CalculateLots(risk, sl - bid);
      
      // Vérifier que les lots sont valides
      if(lots < SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
      {
         Print("⚠️ Lots trop petits pour ", m_symbol, ": ", lots);
         return;
      }
      
      string comment = StringFormat("ADX_SELL_%d_%s", score, highConfidence ? "HIGH" : "NORMAL");
      
      if(m_trade.Sell(lots, m_symbol, 0, sl, tp, comment))
      {
         Print("✅ SELL ouvert: ", m_symbol, " | Score: ", score, " | Lots: ", lots, " | ", comment);
      }
      else
      {
         Print("❌ Erreur SELL: ", m_symbol);
         Print("   RetCode: ", m_trade.ResultRetcode());
         Print("   Description: ", m_trade.ResultRetcodeDescription());
         Print("   Bid: ", bid, " | SL: ", sl, " | TP: ", tp, " | Lots: ", lots);
      }
   }

   //+------------------------------------------------------------------+
   //| Calculer la taille de lot                                      |
   //+------------------------------------------------------------------+
   double CalculateLots(double riskPercent, double slDistance)
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * (riskPercent / 100.0);
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickValue == 0 || tickSize == 0 || slDistance == 0) return 0.01;
      
      double lots = riskAmount / (slDistance / tickSize * tickValue);
      
      // Normaliser selon les contraintes du symbole
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      
      lots = MathMax(lots, minLot);
      lots = MathMin(lots, maxLot);
      lots = MathRound(lots / lotStep) * lotStep;
      
      return lots;
   }

   //+------------------------------------------------------------------+
   //| Trailing Stop                                                   |
   //+------------------------------------------------------------------+
   void TrailingStop()
   {
      if(!m_useTrailing) return;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         if(posType == POSITION_TYPE_BUY)
         {
            double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            double profitPoints = (bid - openPrice) / point;
            
            if(profitPoints >= m_trailingStart)
            {
               double newSL = bid - m_trailingStep * point;
               newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
               
               if(newSL > currentSL)
               {
                  m_trade.PositionModify(ticket, newSL, currentTP);
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            double profitPoints = (openPrice - ask) / point;
            
            if(profitPoints >= m_trailingStart)
            {
               double newSL = ask + m_trailingStep * point;
               newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
               
               if(newSL < currentSL || currentSL == 0)
               {
                  m_trade.PositionModify(ticket, newSL, currentTP);
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Compter les positions ouvertes                                 |
   //+------------------------------------------------------------------+
   int CountPositions()
   {
      int count = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber && 
               PositionGetString(POSITION_SYMBOL) == m_symbol)
            {
               count++;
            }
         }
      }
      return count;
   }

   //+------------------------------------------------------------------+
   //| Vérifier si c'est une nouvelle barre                           |
   //+------------------------------------------------------------------+
   bool IsNewBar()
   {
      datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
      if(currentBarTime != m_lastBarTime)
      {
         m_lastBarTime = currentBarTime;
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le temps de la dernière barre (pour debug)             |
   //+------------------------------------------------------------------+
   datetime GetLastBarTime() const { return m_lastBarTime; }

   //+------------------------------------------------------------------+
   //| Getters pour l'affichage                                       |
   //+------------------------------------------------------------------+
   int GetBuyScore() const { return m_currentBuyScore; }
   int GetSellScore() const { return m_currentSellScore; }
   double GetADX() const { return m_adxScorer != NULL ? m_adxScorer.GetCurrentValue() : 0; }
   double GetRSI() const { return m_rsiScorer != NULL ? m_rsiScorer.GetCurrentValue() : 0; }
   double GetMA() const { return m_maScorer != NULL ? m_maScorer.GetCurrentValue() : 0; }
   double GetPrice() const { return m_maScorer != NULL ? m_maScorer.GetCurrentPrice() : 0; }
   
   // Getters pour les scores BUY
   int GetBuyADXScore() const { return m_buyAdxScore; }
   int GetBuyRSIScore() const { return m_buyRsiScore; }
   int GetBuyMAScore() const { return m_buyMaScore; }
   int GetBuyConfluenceScore() const { return m_buyConfluenceScore; }
   
   // Getters pour les scores SELL
   int GetSellADXScore() const { return m_sellAdxScore; }
   int GetSellRSIScore() const { return m_sellRsiScore; }
   int GetSellMAScore() const { return m_sellMaScore; }
   int GetSellConfluenceScore() const { return m_sellConfluenceScore; }
   
   int GetMaxPositions() const { return m_maxPositions; }
   int GetCurrentPositions() { return CountPositions(); }

   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut                             |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      double adx = GetADX();
      double rsi = GetRSI();
      double ma = GetMA();
      
      string info = StringFormat(
         "ADX: %.1f | RSI: %.1f | MA: %.5f | BUY: %d | SELL: %d | Pos: %d/%d",
         adx, rsi, ma, 
         m_currentBuyScore, m_currentSellScore,
         CountPositions(), m_maxPositions
      );
      return info;
   }
};
