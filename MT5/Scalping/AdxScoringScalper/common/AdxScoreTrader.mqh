//+------------------------------------------------------------------+
//| AdxScoreTrader.mqh - Classe de trading ADX Score                |
//|                   Gestion complète du scoring et trading ADX    |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

#include "../../../CommonUtils/TradingUtils.mqh"
#include "../../../CommonUtils/TradingEnums.mqh"

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
   
   // Indicateurs
   int m_handleADX;
   int m_handleRSI;
   int m_handleMA;
   
   // Paramètres stratégie
   int m_scoreMinEntry;
   int m_scoreHighConfidence;
   double m_riskNormal;
   double m_riskHigh;
   int m_slPoints;
   int m_tpMultiplier;
   int m_maxPositions;
   
   // Trade
   CTrade m_trade;
   
   // État
   datetime m_lastBarTime;
   int m_currentBuyScore;
   int m_currentSellScore;
   
   // Valeurs indicateurs actuelles
   double m_currentADX;
   double m_currentRSI;
   double m_currentMA;
   double m_currentPrice;
   
   // Composantes du score
   int m_adxScore;
   int m_rsiScore;
   int m_maScore;
   int m_confluenceScore;

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
      int maxPositions
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
      
      m_handleADX = INVALID_HANDLE;
      m_handleRSI = INVALID_HANDLE;
      m_handleMA = INVALID_HANDLE;
      
      m_lastBarTime = 0;
      m_currentBuyScore = 0;
      m_currentSellScore = 0;
      
      m_currentADX = 0;
      m_currentRSI = 0;
      m_currentMA = 0;
      m_currentPrice = 0;
      
      m_adxScore = 0;
      m_rsiScore = 0;
      m_maScore = 0;
      m_confluenceScore = 0;
      
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
      if(m_handleADX != INVALID_HANDLE) IndicatorRelease(m_handleADX);
      if(m_handleRSI != INVALID_HANDLE) IndicatorRelease(m_handleRSI);
      if(m_handleMA != INVALID_HANDLE) IndicatorRelease(m_handleMA);
   }

   //+------------------------------------------------------------------+
   //| Initialisation                                                  |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      // Créer les indicateurs
      m_handleADX = iADX(m_symbol, m_timeframe, 14);
      m_handleRSI = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
      m_handleMA = iMA(m_symbol, m_timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
      
      if(m_handleADX == INVALID_HANDLE || m_handleRSI == INVALID_HANDLE || m_handleMA == INVALID_HANDLE)
      {
         Print("❌ Erreur création indicateurs pour ", m_symbol);
         return false;
      }
      
      Print("✅ AdxScoreTrader initialisé pour ", m_symbol, " | Magic: ", m_magicNumber);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Traitement du tick                                              |
   //+------------------------------------------------------------------+
   void OnTick()
   {
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
   //| Mettre à jour les valeurs des indicateurs                      |
   //+------------------------------------------------------------------+
   void UpdateIndicatorValues()
   {
      double adxValues[3];
      double rsiValues[1];
      double maValues[1];
      
      if(CopyBuffer(m_handleADX, 0, 1, 3, adxValues) > 0)
         m_currentADX = adxValues[0];
      
      if(CopyBuffer(m_handleRSI, 0, 1, 1, rsiValues) > 0)
         m_currentRSI = rsiValues[0];
      
      if(CopyBuffer(m_handleMA, 0, 1, 1, maValues) > 0)
         m_currentMA = maValues[0];
      
      m_currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   }

   //+------------------------------------------------------------------+
   //| Calculer le score BUY                                          |
   //+------------------------------------------------------------------+
   int CalculateBuyScore()
   {
      int score = 0;
      
      // Score ADX
      m_adxScore = 0;
      if(m_currentADX > 25) m_adxScore += 1;
      if(m_currentADX > 30) m_adxScore += 1;
      if(m_currentADX > 35) m_adxScore += 1;
      score += m_adxScore;
      
      // Score RSI
      m_rsiScore = 0;
      if(m_currentRSI < 70) m_rsiScore += 1;
      if(m_currentRSI < 60) m_rsiScore += 1;
      if(m_currentRSI < 50) m_rsiScore += 1;
      if(m_currentRSI < 40) m_rsiScore += 1;
      score += m_rsiScore;
      
      // Score MA
      m_maScore = 0;
      if(m_currentPrice > m_currentMA) m_maScore += 2;
      score += m_maScore;
      
      // Score confluence
      m_confluenceScore = 0;
      if(m_adxScore >= 2 && m_rsiScore >= 2) m_confluenceScore += 2;
      score += m_confluenceScore;
      
      return score;
   }

   //+------------------------------------------------------------------+
   //| Calculer le score SELL                                         |
   //+------------------------------------------------------------------+
   int CalculateSellScore()
   {
      int score = 0;
      
      // Score ADX
      m_adxScore = 0;
      if(m_currentADX > 25) m_adxScore += 1;
      if(m_currentADX > 30) m_adxScore += 1;
      if(m_currentADX > 35) m_adxScore += 1;
      score += m_adxScore;
      
      // Score RSI
      m_rsiScore = 0;
      if(m_currentRSI > 30) m_rsiScore += 1;
      if(m_currentRSI > 40) m_rsiScore += 1;
      if(m_currentRSI > 50) m_rsiScore += 1;
      if(m_currentRSI > 60) m_rsiScore += 1;
      score += m_rsiScore;
      
      // Score MA
      m_maScore = 0;
      if(m_currentPrice < m_currentMA) m_maScore += 2;
      score += m_maScore;
      
      // Score confluence
      m_confluenceScore = 0;
      if(m_adxScore >= 2 && m_rsiScore >= 2) m_confluenceScore += 2;
      score += m_confluenceScore;
      
      return score;
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
   //| Ouvrir position BUY                                            |
   //+------------------------------------------------------------------+
   void OpenBuy(int score, bool highConfidence)
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double sl = ask - m_slPoints * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tp = ask + (m_slPoints * m_tpMultiplier) * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      double risk = highConfidence ? m_riskHigh : m_riskNormal;
      double lots = CalculateLots(risk, ask - sl);
      
      string comment = StringFormat("ADX_BUY_%d_%s", score, highConfidence ? "HIGH" : "NORMAL");
      
      if(m_trade.Buy(lots, m_symbol, ask, sl, tp, comment))
      {
         Print("✅ BUY ouvert: ", m_symbol, " | Score: ", score, " | Lots: ", lots, " | ", comment);
      }
      else
      {
         Print("❌ Erreur BUY: ", m_symbol, " | Error: ", GetLastError());
      }
   }

   //+------------------------------------------------------------------+
   //| Ouvrir position SELL                                           |
   //+------------------------------------------------------------------+
   void OpenSell(int score, bool highConfidence)
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double sl = bid + m_slPoints * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tp = bid - (m_slPoints * m_tpMultiplier) * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      double risk = highConfidence ? m_riskHigh : m_riskNormal;
      double lots = CalculateLots(risk, sl - bid);
      
      string comment = StringFormat("ADX_SELL_%d_%s", score, highConfidence ? "HIGH" : "NORMAL");
      
      if(m_trade.Sell(lots, m_symbol, bid, sl, tp, comment))
      {
         Print("✅ SELL ouvert: ", m_symbol, " | Score: ", score, " | Lots: ", lots, " | ", comment);
      }
      else
      {
         Print("❌ Erreur SELL: ", m_symbol, " | Error: ", GetLastError());
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
   //| Compter les positions ouvertes                                 |
   //+------------------------------------------------------------------+
   int CountPositions()
   {
      int count = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionSelectByIndex(i))
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
   //| Getters pour l'affichage                                       |
   //+------------------------------------------------------------------+
   int GetBuyScore() const { return m_currentBuyScore; }
   int GetSellScore() const { return m_currentSellScore; }
   double GetADX() const { return m_currentADX; }
   double GetRSI() const { return m_currentRSI; }
   double GetMA() const { return m_currentMA; }
   double GetPrice() const { return m_currentPrice; }
   
   int GetADXScore() const { return m_adxScore; }
   int GetRSIScore() const { return m_rsiScore; }
   int GetMAScore() const { return m_maScore; }
   int GetConfluenceScore() const { return m_confluenceScore; }
   
   int GetMaxPositions() const { return m_maxPositions; }
   int GetCurrentPositions() const { return CountPositions(); }

   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut                             |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string info = StringFormat(
         "ADX: %.1f | RSI: %.1f | MA: %.5f | BUY: %d | SELL: %d | Pos: %d/%d",
         m_currentADX, m_currentRSI, m_currentMA, 
         m_currentBuyScore, m_currentSellScore,
         CountPositions(), m_maxPositions
      );
      return info;
   }
};
