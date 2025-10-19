//+------------------------------------------------------------------+
//|                                         MA_Crossover_USSession.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- Paramètres d'entrée
input int                 FastMAPeriod = 10;        // Période MA rapide
input int                 SlowMAPeriod = 100;       // Période MA lente
input ENUM_MA_METHOD      MAMethod = MODE_SMA;      // Méthode de la moyenne mobile
input ENUM_APPLIED_PRICE  MAPrice = PRICE_CLOSE;    // Prix appliqué

//--- Gestion du risque
input double              RiskPercent = 2.0;        // Risque en % du capital
input double              FixedLotSize = 0.0;       // Taille de lot fixe (0 = auto)
input int                 StopLoss = 100;           // Stop Loss (points)
input int                 TakeProfit = 200;         // Take Profit (points)

//--- Session US
input int                 USSessionStart = 13;      // Début session US (heure GMT)
input int                 USSessionEnd = 22;        // Fin session US (heure GMT)
input bool                TradeMonday = true;       // Trader le Lundi
input bool                TradeFriday = false;      // Trader le Vendredi

//--- Paramètres généraux
input int                 MagicNumber = 12345;      // Numéro magique
input int                 Slippage = 3;             // Slippage

//--- Handles pour les indicateurs
int                       fastMAHandle;
int                       slowMAHandle;

//--- Variables pour stocker les valeurs des MA
double                    fastMA[], slowMA[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Création des handles pour les indicateurs MA
   fastMAHandle = iMA(_Symbol, _Period, FastMAPeriod, 0, MAMethod, MAPrice);
   slowMAHandle = iMA(_Symbol, _Period, SlowMAPeriod, 0, MAMethod, MAPrice);
   
   //--- Vérification que les handles sont valides
   if(fastMAHandle == INVALID_HANDLE || slowMAHandle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création des handles des indicateurs");
      return(INIT_FAILED);
   }
   
   //--- Initialisation des tableaux
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   
   Print("EA MA Crossover Session US initialisé avec succès");
   Print("Session US: ", USSessionStart, "h - ", USSessionEnd, "h GMT");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Libération des handles
   if(fastMAHandle != INVALID_HANDLE)
      IndicatorRelease(fastMAHandle);
   if(slowMAHandle != INVALID_HANDLE)
      IndicatorRelease(slowMAHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Vérification si c'est une nouvelle barre
   if(!IsNewBar())
      return;
   
   //--- Vérification de la session US
   if(!IsUSSession())
      return;
   
   //--- Récupération des valeurs des MA
   if(CopyBuffer(fastMAHandle, 0, 0, 3, fastMA) < 3 ||
      CopyBuffer(slowMAHandle, 0, 0, 3, slowMA) < 3)
   {
      Print("Erreur lors de la copie des données des MA");
      return;
   }
   
   //--- Détection des signaux
   CheckForSignals();
}

//+------------------------------------------------------------------+
//| Vérifie si c'est une nouvelle barre                             |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   
   if(lastBarTime != currentBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si on est dans la session US                            |
//+------------------------------------------------------------------+
bool IsUSSession()
{
   MqlDateTime currentTime;
   TimeCurrent(currentTime);
   
   int currentHour = currentTime.hour;
   int currentDay = currentTime.day_of_week;
   
   //--- Vérification des jours de trading
   if(currentDay == 1 && !TradeMonday) return false;    // Lundi
   if(currentDay == 5 && !TradeFriday) return false;    // Vendredi
   
   //--- Vérification des heures de session US
   if(currentHour >= USSessionStart && currentHour < USSessionEnd)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calcul du lot size automatique - CORRIGÉ POUR INDICES           |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lotSize = 0.0;
   
   //--- Si lot fixe est spécifié
   if(FixedLotSize > 0)
      return NormalizeDouble(FixedLotSize, 2);
   
   //--- Calcul basé sur le risque
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100.0;
   
   string symbol = _Symbol;
   bool isIndex = false;
   
   //--- Détection des indices (NAS100, US30, US500, etc.)
   if(StringFind(symbol, "NAS100") >= 0 || StringFind(symbol, "US30") >= 0 || 
      StringFind(symbol, "US500") >= 0 || StringFind(symbol, "DJI") >= 0 ||
      StringFind(symbol, "SPX") >= 0 || StringFind(symbol, "NDX") >= 0)
   {
      isIndex = true;
   }
   
   if(isIndex)
   {
      //--- CALCUL SPÉCIFIQUE POUR LES INDICES
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      Print("Indice détecté: ", symbol);
      Print("Contract Size: ", contractSize, ", Tick Size: ", tickSize, ", Tick Value: ", tickValue, ", Point: ", pointValue);
      
      if(StopLoss > 0 && tickValue > 0)
      {
         // Pour les indices, calcul basé sur la valeur du tick
         double riskInMoney = riskAmount;
         double riskInTicks = StopLoss; // SL en points
         
         // Conversion des points en valeur monétaire
         double riskMoneyValue = riskInTicks * pointValue * tickValue / tickSize;
         
         if(riskMoneyValue > 0)
         {
            lotSize = riskAmount / riskMoneyValue;
         }
         else
         {
            // Méthode alternative pour les indices
            lotSize = riskAmount / (StopLoss * 1.0); // Approximation
         }
      }
   }
   else
   {
      //--- CALCUL POUR FOREX
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(StopLoss > 0 && tickSize > 0 && tickValue > 0)
      {
         double riskPoints = StopLoss * pointValue;
         if(riskPoints > 0)
         {
            lotSize = riskAmount / (riskPoints / tickSize * tickValue);
         }
      }
   }
   
   //--- Vérification des limites du broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   
   //--- Arrondi au step près
   if(stepLot > 0)
      lotSize = MathRound(lotSize / stepLot) * stepLot;
   
   lotSize = NormalizeDouble(lotSize, 2);
   
   Print("Lot calculé: ", lotSize, " pour ", symbol, " - Balance: ", accountBalance, " - Risque: ", RiskPercent, "%");
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Vérification des signaux de trading                             |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   //--- Vérification du croisement haussier (ACHAT)
   if(fastMA[1] <= slowMA[1] && fastMA[0] > slowMA[0]) // Croisement haussier
   {
      if(CountPositions() == 0) // Pas de position ouverte
      {
         OpenBuyOrder();
         Print("Signal ACHAT détecté - MA", FastMAPeriod, " croise au-dessus de MA", SlowMAPeriod);
      }
   }
   
   //--- Vérification du croisement baissier (VENTE)
   if(fastMA[1] >= slowMA[1] && fastMA[0] < slowMA[0]) // Croisement baissier
   {
      if(CountPositions() == 0) // Pas de position ouverte
      {
         OpenSellOrder();
         Print("Signal VENTE détecté - MA", FastMAPeriod, " croise en-dessous de MA", SlowMAPeriod);
      }
   }
}

//+------------------------------------------------------------------+
//| Ouverture d'un ordre d'achat - CORRIGÉ                          |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = StopLoss > 0 ? price - StopLoss * _Point : 0;
   double tp = TakeProfit > 0 ? price + TakeProfit * _Point : 0;
   double lotSize = CalculateLotSize();
   
   //--- Vérification des fonds suffisants
   if(!CheckMoneyForTrade(lotSize, ORDER_TYPE_BUY))
   {
      Print("Fonds insuffisants pour ouvrir un ordre d'achat");
      return;
   }
   
   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.volume    = lotSize;
   request.type      = ORDER_TYPE_BUY;
   request.price     = price;
   request.sl        = sl;
   request.tp        = tp;
   request.deviation = Slippage;
   request.magic     = MagicNumber;
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
         Print("Ordre ACHAT ouvert avec succès. Ticket: ", result.order, ", Lot: ", lotSize, ", Prix: ", price);
      else
         Print("Erreur ouverture ordre ACHAT. Code: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Ouverture d'un ordre de vente - CORRIGÉ                         |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = StopLoss > 0 ? price + StopLoss * _Point : 0;
   double tp = TakeProfit > 0 ? price - TakeProfit * _Point : 0;
   double lotSize = CalculateLotSize();
   
   //--- Vérification des fonds suffisants
   if(!CheckMoneyForTrade(lotSize, ORDER_TYPE_SELL))
   {
      Print("Fonds insuffisants pour ouvrir un ordre de vente");
      return;
   }
   
   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.volume    = lotSize;
   request.type      = ORDER_TYPE_SELL;
   request.price     = price;
   request.sl        = sl;
   request.tp        = tp;
   request.deviation = Slippage;
   request.magic     = MagicNumber;
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
         Print("Ordre VENTE ouvert avec succès. Ticket: ", result.order, ", Lot: ", lotSize, ", Prix: ", price);
      else
         Print("Erreur ouverture ordre VENTE. Code: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Vérifie les fonds disponibles pour le trade                     |
//+------------------------------------------------------------------+
bool CheckMoneyForTrade(double lots, ENUM_ORDER_TYPE type)
{
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginRequired = 0;
   
   if(type == ORDER_TYPE_BUY)
      marginRequired = lots * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_LONG);
   else if(type == ORDER_TYPE_SELL)
      marginRequired = lots * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_SHORT);
   
   if(marginRequired > freeMargin)
   {
      Print("Marge insuffisante. Requis: ", marginRequired, ", Disponible: ", freeMargin);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Compte le nombre de positions ouvertes                          |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Fonction pour obtenir les informations du symbole               |
//+------------------------------------------------------------------+
void PrintSymbolInfo()
{
   Print("=== INFORMATIONS SYMBOLE ===");
   Print("Symbole: ", _Symbol);
   Print("Contract Size: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE));
   Print("Tick Size: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   Print("Tick Value: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
   Print("Point: ", SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   Print("Lot Min: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   Print("Lot Max: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   Print("Lot Step: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
   Print("=============================");
}