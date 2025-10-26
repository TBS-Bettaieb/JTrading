//+------------------------------------------------------------------+
//|                                          SymbolDisplay.mqh   |
//|                    Affichage et visualisation pour un symbole   |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../../../Shared/TradingEnums.mqh"
#include "../../../Shared/Logger.mqh"
#include "SymbolStatus.mqh"
#include "../analysis/SwingAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Classe SymbolDisplay - Gestion de l'affichage        |
//+------------------------------------------------------------------+
class SymbolDisplay
{
private:
   string            m_symbol;
   int               m_magicNumber;
   SymbolStatus* m_statusManager;
   SwingAnalyzer* m_swingAnalyzer;
   
   // Paramètres de trading pour affichage
   double            m_riskPercent;
   int               m_tpPoints;
   int               m_slPoints;
   ENUM_TIMEFRAMES   m_timeframe;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   SymbolDisplay(string symbol,
                            int magicNumber,
                            SymbolStatus* statusManager,
                            SwingAnalyzer* swingAnalyzer,
                            double riskPercent,
                            int tpPoints,
                            int slPoints,
                            ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_statusManager = statusManager;
      m_swingAnalyzer = swingAnalyzer;
      m_riskPercent = riskPercent;
      m_tpPoints = tpPoints;
      m_slPoints = slPoints;
      m_timeframe = timeframe;
      
      // Créer les labels d'information
      CreateInfoLabels();
      
      Print("✓ SymbolDisplay initialized for ", symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~SymbolDisplay()
   {
      // Nettoyage des objets graphiques si nécessaire
      Print("✓ SymbolDisplay destroyed for ", m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Rafraîchir l'affichage des lignes swing                         |
   //+------------------------------------------------------------------+
   void RefreshSwingDisplay()
   {
      if(m_swingAnalyzer != NULL)
      {
         m_swingAnalyzer.RefreshSwingDisplay();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les informations du graphique                     |
   //+------------------------------------------------------------------+
   void UpdateChartInfo()
   {
      if(m_statusManager != NULL)
      {
         string info = m_statusManager.GetStatusInfo();
         // Afficher sur le graphique ou dans Comment()
         Comment(info);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Afficher les informations de trading                            |
   //+------------------------------------------------------------------+
   void DisplayTradingInfo()
   {
      if(m_statusManager == NULL) return;
      
      string info = StringFormat(
         "=== %s ===\n" +
         "Mode: BREAKOUT | TF: %s\n" +
         "Positions: %d | P&L: %.2f\n" +
         "Risk: %.2f%% | TP: %d | SL: %d",
         m_symbol,
         EnumToString(m_timeframe),
         m_statusManager.GetTotalPositions(),
         m_statusManager.GetTotalProfit(),
         m_riskPercent,
         m_tpPoints,
         m_slPoints
      );
      
      Print("📊 Trading Info - ", info);
   }
   
   //+------------------------------------------------------------------+
   //| Créer les labels d'information sur le graphique                |
   //+------------------------------------------------------------------+
   void CreateInfoLabels()
   {
      string prefix = "Display_" + IntegerToString(m_magicNumber) + "_";
      
      // Créer un label principal (exemple simplifié)
      string labelName = prefix + "MainInfo";
      
      if(ObjectFind(0, labelName) < 0)
      {
         ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20 + (m_magicNumber * 20));
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      }
      
      // Mettre à jour le contenu
      UpdateInfoLabel(labelName);
   }
   
   //+------------------------------------------------------------------+
   //| Afficher les paramètres d'entrée                                |
   //+------------------------------------------------------------------+
   void DisplayInputs()
   {
      string info = StringFormat(
         "=== PARAMÈTRES %s ===\n" +
         "Symbole: %s\n" +
         "Timeframe: %s\n" +
         "Stop Loss: %d\n" +
         "Take Profit: %d\n" +
         "Risk: %.2f%%\n" +
         "Strategy: %s",
         m_symbol,
         m_symbol,
         EnumToString(m_timeframe),
         m_slPoints,
         m_tpPoints,
         m_riskPercent,
         "BREAKOUT"
      );
      
      Print("📋 Inputs - ", info);
   }
   
   //+------------------------------------------------------------------+
   //| Afficher les résultats                                          |
   //+------------------------------------------------------------------+
   void DisplayResults()
   {
      if(m_statusManager == NULL) return;
      
      string info = StringFormat(
         "=== RÉSULTATS %s ===\n" +
         "Positions: %d\n" +
         "P&L: %.2f %s\n" +
         "Win Rate: %.1f%%",
         m_symbol,
         m_statusManager.GetTotalPositions(),
         m_statusManager.GetTotalProfit(),
         AccountInfoString(ACCOUNT_CURRENCY),
         CalculateWinRate()
      );
      
      Print("📊 Results - ", info);
   }
   
   //+------------------------------------------------------------------+
   //| Dessiner un trade sur le graphique                             |
   //+------------------------------------------------------------------+
   void DrawTrade(datetime time, double price, bool isBuy)
   {
      string arrowName = "Trade_" + IntegerToString(m_magicNumber) + "_" + TimeToString(time);
      
      if(ObjectFind(0, arrowName) < 0)
      {
         ObjectCreate(0, arrowName, OBJ_ARROW, 0, time, price);
         ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuy ? clrLime : clrRed);
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      }
   }
   
private:
   //+------------------------------------------------------------------+
   //| Calculer le win rate                                            |
   //+------------------------------------------------------------------+
   double CalculateWinRate()
   {
      if(m_statusManager == NULL) return 0.0;
      
      // Logique de calcul du win rate
      // (à implémenter selon vos besoins)
      return 0.0;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour le label d'information                            |
   //+------------------------------------------------------------------+
   void UpdateInfoLabel(string labelName)
   {
      if(m_statusManager == NULL) return;
      
      string text = StringFormat(
         "%s | P&L: %.2f | Pos: %d",
         m_symbol,
         m_statusManager.GetTotalProfit(),
         m_statusManager.GetTotalPositions()
      );
      
      ObjectSetString(0, labelName, OBJPROP_TEXT, text);
   }
};
