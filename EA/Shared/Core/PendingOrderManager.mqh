//+------------------------------------------------------------------+
//|                                      PendingOrderManager.mqh     |
//|                    Gestionnaire d'ordres pending                 |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include "../Logger.mqh"
#include "VolumeManager.mqh"
#include "TradingValidator.mqh"

//+------------------------------------------------------------------+
//| Classe PendingOrderManager - Gestion des ordres pending          |
//+------------------------------------------------------------------+
class PendingOrderManager
{
private:
   string            m_symbol;              // Symbole géré
   int               m_magicNumber;         // Magic number pour filtrer
   CTrade*           m_trade;               // Objet de trading (injecté)
   COrderInfo        m_order;               // Gestionnaire d'ordres
   VolumeManager*    m_volumeManager;       // Gestionnaire de volume (injecté)
   TradingValidator* m_validator;           // Validateur (injecté)
   
   // Compteurs
   int               m_buyOrders;           // Nombre d'ordres BUY
   int               m_sellOrders;          // Nombre d'ordres SELL
   int               m_totalOrders;         // Total des ordres
   
   // Paramètres
   int               m_expirationBars;      // Expiration en barres
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe pour calculer l'expiration
   int               m_slippagePoints;      // Slippage en points
   string            m_comment;             // Commentaire des ordres
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   PendingOrderManager(string symbol, int magicNumber, CTrade* trade, 
                      VolumeManager* volumeManager, TradingValidator* validator,
                      int expirationBars, ENUM_TIMEFRAMES timeframe, 
                      int slippagePoints, string comment)
   {
      // FIXED: Vérification NULL des dépendances critiques
      if(trade == NULL || volumeManager == NULL || validator == NULL)
      {
         Logger::Error("CRITICAL: NULL dependency in PendingOrderManager constructor");
         Logger::Error("  - CTrade: " + (trade == NULL ? "NULL" : "OK"));
         Logger::Error("  - VolumeManager: " + (volumeManager == NULL ? "NULL" : "OK"));
         Logger::Error("  - TradingValidator: " + (validator == NULL ? "NULL" : "OK"));
         
         // Initialiser avec des valeurs sûres par défaut
         m_symbol = symbol;
         m_magicNumber = magicNumber;
         m_trade = trade;
         m_volumeManager = volumeManager;
         m_validator = validator;
         m_expirationBars = 0;
         m_timeframe = PERIOD_CURRENT;
         m_slippagePoints = 0;
         m_comment = "";
         m_buyOrders = 0;
         m_sellOrders = 0;
         m_totalOrders = 0;
         return;
      }
      
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_trade = trade;
      m_volumeManager = volumeManager;
      m_validator = validator;
      m_expirationBars = expirationBars;
      m_timeframe = timeframe;
      m_slippagePoints = slippagePoints;
      m_comment = comment;
      
      // Initialiser les compteurs
      m_buyOrders = 0;
      m_sellOrders = 0;
      m_totalOrders = 0;
      
      Logger::Debug("PendingOrderManager initialized for " + symbol + " | Magic: " + IntegerToString(magicNumber));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~PendingOrderManager()
   {
      Logger::Debug("PendingOrderManager destroyed for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour les compteurs d'ordres                            |
   //+------------------------------------------------------------------+
   void UpdateCounters()
   {
      m_buyOrders = 0;
      m_sellOrders = 0;
      m_totalOrders = 0;
      
      // Compter les ordres en attente
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetString(ORDER_SYMBOL) == m_symbol && OrderGetInteger(ORDER_MAGIC) == m_magicNumber)
            {
               m_totalOrders++;
               
               ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
               if(orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
                  m_buyOrders++;
               else if(orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_LIMIT)
                  m_sellOrders++;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Créer un ordre Buy Stop                                         |
   //| @return Ticket de l'ordre créé, 0 si échec                      |
   //+------------------------------------------------------------------+
   ulong CreateBuyStop(double volume, double price, double sl, double tp)
   {
      // 🔍 LOGS DE DEBUG DÉTAILLÉS POUR BUY STOP (seulement si LOG_DEBUG actif)
      if(Logger::GetLevel() == LOG_DEBUG)
      {
         Logger::Debug("🔍 PendingOrderManager::CreateBuyStop - Paramètres reçus:");
         Logger::Debug("  - Volume: " + DoubleToString(volume, 2));
         Logger::Debug("  - Price: " + DoubleToString(price, _Digits));
         Logger::Debug("  - Stop Loss: " + DoubleToString(sl, _Digits));
         Logger::Debug("  - Take Profit: " + DoubleToString(tp, _Digits));
         Logger::Debug("  - Symbol: " + m_symbol);
         Logger::Debug("  - Comment: " + m_comment);
      }
      
      // Valider l'ordre
      string errorMsg;
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_validator != NULL && !m_validator.ValidateOrder(price, sl, tp, ORDER_TYPE_BUY_STOP, errorMsg))
      {
         Logger::Error("❌ Buy Stop validation failed: " + errorMsg);
         Logger::Error("❌ Validation failed - Paramètres:");
         Logger::Error("    Price: " + DoubleToString(price, _Digits));
         Logger::Error("    SL: " + DoubleToString(sl, _Digits));
         Logger::Error("    TP: " + DoubleToString(tp, _Digits));
         return 0;
      }
      
      // Normaliser le volume
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      double normalizedVolume = m_volumeManager != NULL ? m_volumeManager.NormalizeVolume(volume) : volume;
      if(m_validator != NULL && !m_validator.ValidateVolume(normalizedVolume, errorMsg))
      {
         Logger::Error("❌ Volume validation failed: " + errorMsg);
         Logger::Error("❌ Volume original: " + DoubleToString(volume, 2) + " | Normalisé: " + DoubleToString(normalizedVolume, 2));
         return 0;
      }
      
      // Calculer l'expiration
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      // Vérifier les conditions de marché avant l'ordre (seulement si LOG_DEBUG actif)
      if(Logger::GetLevel() == LOG_DEBUG)
      {
         Logger::Debug("  - Expiration: " + TimeToString(expiration, TIME_DATE|TIME_MINUTES));
         double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         Logger::Debug("  - Prix actuel BID: " + DoubleToString(currentBid, _Digits));
         Logger::Debug("  - Prix actuel ASK: " + DoubleToString(currentAsk, _Digits));
         Logger::Debug("  - Spread: " + DoubleToString((currentAsk - currentBid)/SymbolInfoDouble(m_symbol, SYMBOL_POINT), 1) + " pts");
      }
      
      // Créer l'ordre
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_trade != NULL && m_trade.BuyStop(normalizedVolume, price, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_comment))
      {
         ulong ticket = m_trade.ResultOrder();
         Logger::Info("✅ Buy Stop order created #" + IntegerToString(ticket) + " | Price: " + DoubleToString(price, 5) + " | Volume: " + DoubleToString(normalizedVolume, 2));
         UpdateCounters();
         return ticket;
      }
      else
      {
         uint retcode = m_trade.ResultRetcode();
         string retcodeDesc = m_trade.ResultRetcodeDescription();
         Logger::Error("❌ Failed to create Buy Stop order | Retcode: " + IntegerToString(retcode) + " | " + retcodeDesc);
         Logger::Error("❌ BUY STOP FAILED - Détails:");
         Logger::Error("    Volume: " + DoubleToString(normalizedVolume, 2));
         Logger::Error("    Price: " + DoubleToString(price, _Digits));
         Logger::Error("    SL: " + DoubleToString(sl, _Digits));
         Logger::Error("    TP: " + DoubleToString(tp, _Digits));
         Logger::Error("    Symbol: " + m_symbol);
         Logger::Error("    Expiration: " + TimeToString(expiration, TIME_DATE|TIME_MINUTES));
         return 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Créer un ordre Sell Stop                                        |
   //| @return Ticket de l'ordre créé, 0 si échec                      |
   //+------------------------------------------------------------------+
   ulong CreateSellStop(double volume, double price, double sl, double tp)
   {
      // 🔍 LOGS DE DEBUG DÉTAILLÉS POUR SELL STOP (seulement si LOG_DEBUG actif)
      if(Logger::GetLevel() == LOG_DEBUG)
      {
         Logger::Debug("🔍 PendingOrderManager::CreateSellStop - Paramètres reçus:");
         Logger::Debug("  - Volume: " + DoubleToString(volume, 2));
         Logger::Debug("  - Price: " + DoubleToString(price, _Digits));
         Logger::Debug("  - Stop Loss: " + DoubleToString(sl, _Digits));
         Logger::Debug("  - Take Profit: " + DoubleToString(tp, _Digits));
         Logger::Debug("  - Symbol: " + m_symbol);
         Logger::Debug("  - Comment: " + m_comment);
      }
      
      // Valider l'ordre
      string errorMsg;
      // FIXED: Utiliser -> pour les pointeurs au lieu de .
      if(m_validator != NULL && !m_validator.ValidateOrder(price, sl, tp, ORDER_TYPE_SELL_STOP, errorMsg))
      {
         Logger::Error("❌ Sell Stop validation failed: " + errorMsg);
         Logger::Error("❌ Validation failed - Paramètres:");
         Logger::Error("    Price: " + DoubleToString(price, _Digits));
         Logger::Error("    SL: " + DoubleToString(sl, _Digits));
         Logger::Error("    TP: " + DoubleToString(tp, _Digits));
         return 0;
      }
      
      // Normaliser le volume
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      double normalizedVolume = m_volumeManager != NULL ? m_volumeManager.NormalizeVolume(volume) : volume;
      if(m_validator != NULL && !m_validator.ValidateVolume(normalizedVolume, errorMsg))
      {
         Logger::Error("❌ Volume validation failed: " + errorMsg);
         Logger::Error("❌ Volume original: " + DoubleToString(volume, 2) + " | Normalisé: " + DoubleToString(normalizedVolume, 2));
         return 0;
      }
      
      // Calculer l'expiration
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      // Vérifier les conditions de marché avant l'ordre (seulement si LOG_DEBUG actif)
      if(Logger::GetLevel() == LOG_DEBUG)
      {
         Logger::Debug("  - Expiration: " + TimeToString(expiration, TIME_DATE|TIME_MINUTES));
         double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         Logger::Debug("  - Prix actuel BID: " + DoubleToString(currentBid, _Digits));
         Logger::Debug("  - Prix actuel ASK: " + DoubleToString(currentAsk, _Digits));
         Logger::Debug("  - Spread: " + DoubleToString((currentAsk - currentBid)/SymbolInfoDouble(m_symbol, SYMBOL_POINT), 1) + " pts");
      }
      
      // Créer l'ordre
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_trade != NULL && m_trade.SellStop(normalizedVolume, price, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_comment))
      {
         ulong ticket = m_trade.ResultOrder();
         Logger::Info("✅ Sell Stop order created #" + IntegerToString(ticket) + " | Price: " + DoubleToString(price, 5) + " | Volume: " + DoubleToString(normalizedVolume, 2));
         UpdateCounters();
         return ticket;
      }
      else
      {
         uint retcode = m_trade.ResultRetcode();
         string retcodeDesc = m_trade.ResultRetcodeDescription();
         Logger::Error("❌ Failed to create Sell Stop order | Retcode: " + IntegerToString(retcode) + " | " + retcodeDesc);
         Logger::Error("❌ SELL STOP FAILED - Détails:");
         Logger::Error("    Volume: " + DoubleToString(normalizedVolume, 2));
         Logger::Error("    Price: " + DoubleToString(price, _Digits));
         Logger::Error("    SL: " + DoubleToString(sl, _Digits));
         Logger::Error("    TP: " + DoubleToString(tp, _Digits));
         Logger::Error("    Symbol: " + m_symbol);
         Logger::Error("    Expiration: " + TimeToString(expiration, TIME_DATE|TIME_MINUTES));
         return 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Créer un ordre Buy Limit                                        |
   //| @return Ticket de l'ordre créé, 0 si échec                      |
   //+------------------------------------------------------------------+
   ulong CreateBuyLimit(double volume, double price, double sl, double tp)
   {
      // Valider l'ordre
      string errorMsg;
      // FIXED: Utiliser -> pour les pointeurs au lieu de .
      if(m_validator != NULL && !m_validator.ValidateOrder(price, sl, tp, ORDER_TYPE_BUY_LIMIT, errorMsg))
      {
         Logger::Error("Buy Limit validation failed: " + errorMsg);
         return 0;
      }
      
      // Normaliser le volume
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      double normalizedVolume = m_volumeManager != NULL ? m_volumeManager.NormalizeVolume(volume) : volume;
      if(m_validator != NULL && !m_validator.ValidateVolume(normalizedVolume, errorMsg))
      {
         Logger::Error("Volume validation failed: " + errorMsg);
         return 0;
      }
      
      // Calculer l'expiration
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      // Créer l'ordre
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_trade != NULL && m_trade.BuyLimit(normalizedVolume, price, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_comment))
      {
         ulong ticket = m_trade.ResultOrder();
         Logger::Info("Buy Limit order created #" + IntegerToString(ticket) + " | Price: " + DoubleToString(price, 5) + " | Volume: " + DoubleToString(normalizedVolume, 2));
         UpdateCounters();
         return ticket;
      }
      else
      {
         Logger::Error("Failed to create Buy Limit order | Error: " + IntegerToString(GetLastError()));
         return 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Créer un ordre Sell Limit                                       |
   //| @return Ticket de l'ordre créé, 0 si échec                      |
   //+------------------------------------------------------------------+
   ulong CreateSellLimit(double volume, double price, double sl, double tp)
   {
      // Valider l'ordre
      string errorMsg;
      // FIXED: Utiliser -> pour les pointeurs au lieu de .
      if(m_validator != NULL && !m_validator.ValidateOrder(price, sl, tp, ORDER_TYPE_SELL_LIMIT, errorMsg))
      {
         Logger::Error("Sell Limit validation failed: " + errorMsg);
         return 0;
      }
      
      // Normaliser le volume
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      double normalizedVolume = m_volumeManager != NULL ? m_volumeManager.NormalizeVolume(volume) : volume;
      if(m_validator != NULL && !m_validator.ValidateVolume(normalizedVolume, errorMsg))
      {
         Logger::Error("Volume validation failed: " + errorMsg);
         return 0;
      }
      
      // Calculer l'expiration
      datetime expiration = iTime(m_symbol, m_timeframe, 0) + m_expirationBars * PeriodSeconds(m_timeframe);
      
      // Créer l'ordre
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_trade != NULL && m_trade.SellLimit(normalizedVolume, price, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, m_comment))
      {
         ulong ticket = m_trade.ResultOrder();
         Logger::Info("Sell Limit order created #" + IntegerToString(ticket) + " | Price: " + DoubleToString(price, 5) + " | Volume: " + DoubleToString(normalizedVolume, 2));
         UpdateCounters();
         return ticket;
      }
      else
      {
         Logger::Error("Failed to create Sell Limit order | Error: " + IntegerToString(GetLastError()));
         return 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer un ordre par ticket                                   |
   //| @return true si supprimé avec succès, false sinon               |
   //+------------------------------------------------------------------+
   bool DeleteOrder(ulong ticket)
   {
      if(!m_order.Select(ticket))
      {
         Logger::Error("Order #" + IntegerToString(ticket) + " not found");
         return false;
      }
      
      if(m_order.Symbol() != m_symbol || m_order.Magic() != m_magicNumber)
      {
         Logger::Error("Order #" + IntegerToString(ticket) + " does not belong to this manager");
         return false;
      }
      
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_trade != NULL && m_trade.OrderDelete(ticket))
      {
         Logger::Info("Order #" + IntegerToString(ticket) + " deleted for " + m_symbol);
         UpdateCounters();
         return true;
      }
      else
      {
         Logger::Error("Failed to delete order #" + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer tous les ordres                                       |
   //| @return Nombre d'ordres supprimés                               |
   //+------------------------------------------------------------------+
   int DeleteAllOrders()
   {
      int deletedCount = 0;
      
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetString(ORDER_SYMBOL) == m_symbol && OrderGetInteger(ORDER_MAGIC) == m_magicNumber)
            {
               // ✅ CORRECTION: Vérification NULL + syntaxe correcte
               if(m_trade != NULL && m_trade.OrderDelete(ticket))
               {
                  deletedCount++;
                  Logger::Info("Order #" + IntegerToString(ticket) + " deleted for " + m_symbol);
               }
               else
               {
                  Logger::Error("Failed to delete order #" + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
               }
            }
         }
      }
      
      if(deletedCount > 0)
      {
         Logger::Info("Deleted " + IntegerToString(deletedCount) + " order(s) for " + m_symbol);
         UpdateCounters();
      }
      
      return deletedCount;
   }
   
   //+------------------------------------------------------------------+
   //| Modifier un ordre                                               |
   //| @return true si modifié avec succès, false sinon                |
   //+------------------------------------------------------------------+
   bool ModifyOrder(ulong ticket, double newPrice, double newSL, double newTP)
   {
      if(!m_order.Select(ticket))
      {
         Logger::Error("Order #" + IntegerToString(ticket) + " not found");
         return false;
      }
      
      if(m_order.Symbol() != m_symbol || m_order.Magic() != m_magicNumber)
      {
         Logger::Error("Order #" + IntegerToString(ticket) + " does not belong to this manager");
         return false;
      }
      
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)m_order.Type();
      
      // Valider les nouveaux paramètres
      string errorMsg;
      // FIXED: Utiliser -> pour les pointeurs au lieu de .
      if(m_validator != NULL && !m_validator.ValidateOrder(newPrice, newSL, newTP, orderType, errorMsg))
      {
         Logger::Error("Order modification validation failed: " + errorMsg);
         return false;
      }
      
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_trade != NULL && m_trade.OrderModify(ticket, newPrice, newSL, newTP, ORDER_TIME_SPECIFIED, m_order.TimeExpiration()))
      {
         Logger::Info("Order #" + IntegerToString(ticket) + " modified | Price: " + DoubleToString(newPrice, 5) + 
                     " | SL: " + DoubleToString(newSL, 5) + " | TP: " + DoubleToString(newTP, 5));
         return true;
      }
      else
      {
         Logger::Error("Failed to modify order #" + IntegerToString(ticket) + " | Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Ajuster le volume d'un ordre                                    |
   //| @return true si ajusté avec succès, false sinon                 |
   //+------------------------------------------------------------------+
   bool AdjustOrderVolume(ulong ticket, double newVolume)
   {
      if(!m_order.Select(ticket))
      {
         Logger::Error("Order #" + IntegerToString(ticket) + " not found");
         return false;
      }
      
      if(m_order.Symbol() != m_symbol || m_order.Magic() != m_magicNumber)
      {
         Logger::Error("Order #" + IntegerToString(ticket) + " does not belong to this manager");
         return false;
      }
      
      // Normaliser le nouveau volume
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      double normalizedVolume = m_volumeManager != NULL ? m_volumeManager.NormalizeVolume(newVolume) : newVolume;
      
      // Valider le volume
      string errorMsg;
      // FIXED: Utiliser -> pour les pointeurs au lieu de .
      if(m_validator != NULL && !m_validator.ValidateVolume(normalizedVolume, errorMsg))
      {
         Logger::Error("Volume validation failed: " + errorMsg);
         return false;
      }
      
      // Récupérer les paramètres actuels
      double currentPrice = m_order.PriceOpen();
      double currentSL = m_order.StopLoss();
      double currentTP = m_order.TakeProfit();
      datetime expiration = m_order.TimeExpiration();
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)m_order.Type();
      
      // Supprimer l'ancien ordre
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_trade == NULL || !m_trade.OrderDelete(ticket))
      {
         Logger::Error("Failed to delete order #" + IntegerToString(ticket) + " for volume adjustment | Error: " + IntegerToString(GetLastError()));
         return false;
      }
      
      // Recréer l'ordre avec le nouveau volume
      bool success = false;
      ulong newTicket = 0;
      
      // ✅ CORRECTION: Vérification NULL + syntaxe correcte
      if(m_trade == NULL)
      {
         Logger::Error("CTrade object is NULL, cannot recreate order");
         return false;
      }
      
      switch(orderType)
      {
         case ORDER_TYPE_BUY_STOP:
            success = m_trade.BuyStop(normalizedVolume, currentPrice, m_symbol, currentSL, currentTP, ORDER_TIME_SPECIFIED, expiration, m_comment);
            break;
         case ORDER_TYPE_SELL_STOP:
            success = m_trade.SellStop(normalizedVolume, currentPrice, m_symbol, currentSL, currentTP, ORDER_TIME_SPECIFIED, expiration, m_comment);
            break;
         case ORDER_TYPE_BUY_LIMIT:
            success = m_trade.BuyLimit(normalizedVolume, currentPrice, m_symbol, currentSL, currentTP, ORDER_TIME_SPECIFIED, expiration, m_comment);
            break;
         case ORDER_TYPE_SELL_LIMIT:
            success = m_trade.SellLimit(normalizedVolume, currentPrice, m_symbol, currentSL, currentTP, ORDER_TIME_SPECIFIED, expiration, m_comment);
            break;
         default:
            Logger::Error("Unsupported order type for volume adjustment: " + EnumToString(orderType));
            return false;
      }
      
      if(success)
      {
         // ✅ CORRECTION: Vérification NULL + syntaxe correcte
         newTicket = m_trade.ResultOrder();
         Logger::Info("Order volume adjusted #" + IntegerToString(ticket) + " → #" + IntegerToString(newTicket) + 
                     " | Volume: " + DoubleToString(m_order.VolumeInitial(), 2) + " → " + DoubleToString(normalizedVolume, 2));
         UpdateCounters();
         return true;
      }
      else
      {
         Logger::Error("Failed to recreate order with new volume | Error: " + IntegerToString(GetLastError()));
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations d'un ordre                             |
   //| @return true si ordre trouvé, false sinon                       |
   //+------------------------------------------------------------------+
   bool GetOrderInfo(ulong ticket, double &price, double &volume, double &sl, double &tp, 
                    ENUM_ORDER_TYPE &orderType, datetime &expiration)
   {
      if(!m_order.Select(ticket))
         return false;
      
      if(m_order.Symbol() != m_symbol || m_order.Magic() != m_magicNumber)
         return false;
      
      price = m_order.PriceOpen();
      volume = m_order.VolumeInitial();
      sl = m_order.StopLoss();
      tp = m_order.TakeProfit();
      orderType = (ENUM_ORDER_TYPE)m_order.Type();
      expiration = m_order.TimeExpiration();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la liste des tickets d'ordres                           |
   //| @return Nombre d'ordres trouvés                                 |
   //+------------------------------------------------------------------+
   int GetOrderTickets(ulong &tickets[])
   {
      ArrayResize(tickets, 0);
      
      for(int i = 0; i < OrdersTotal(); i++)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
         {
            if(OrderGetString(ORDER_SYMBOL) == m_symbol && OrderGetInteger(ORDER_MAGIC) == m_magicNumber)
            {
               int size = ArraySize(tickets);
               ArrayResize(tickets, size + 1);
               tickets[size] = ticket;
            }
         }
      }
      
      return ArraySize(tickets);
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si un ordre existe                                     |
   //| @return true si l'ordre existe pour ce manager, false sinon     |
   //+------------------------------------------------------------------+
   bool HasOrder(ulong ticket)
   {
      if(!m_order.Select(ticket))
         return false;
      
      return (m_order.Symbol() == m_symbol && m_order.Magic() == m_magicNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre d'ordres BUY                                  |
   //+------------------------------------------------------------------+
   int GetBuyOrders() const { return m_buyOrders; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre d'ordres SELL                                 |
   //+------------------------------------------------------------------+
   int GetSellOrders() const { return m_sellOrders; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre total d'ordres                                |
   //+------------------------------------------------------------------+
   int GetTotalOrders() const { return m_totalOrders; }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut                              |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string status = m_symbol + ": ";
      
      if(m_totalOrders == 0)
         status += "NO ORDERS";
      else
      {
         status += "Orders: " + IntegerToString(m_totalOrders);
         status += " (B:" + IntegerToString(m_buyOrders) + " S:" + IntegerToString(m_sellOrders) + ")";
      }
      
      return status;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo()
   {
      string info = "PendingOrderManager for " + m_symbol + ":\n";
      info += "  Total Orders: " + IntegerToString(m_totalOrders) + "\n";
      info += "  Buy Orders: " + IntegerToString(m_buyOrders) + "\n";
      info += "  Sell Orders: " + IntegerToString(m_sellOrders) + "\n";
      info += "  Expiration: " + IntegerToString(m_expirationBars) + " bars\n";
      info += "  Timeframe: " + EnumToString(m_timeframe);
      
      return info;
   }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation                                             |
//+------------------------------------------------------------------+
/*
// Création des dépendances
CTrade* trade = new CTrade();
VolumeManager* volumeMgr = new VolumeManager("EURUSD");
TradingValidator* validator = new TradingValidator("EURUSD");

// Création du gestionnaire d'ordres
PendingOrderManager* orderMgr = new PendingOrderManager("EURUSD", 12345, trade, volumeMgr, validator, 10, PERIOD_M15, 3, "MyEA");

// Mettre à jour les compteurs
orderMgr.UpdateCounters();

// Créer des ordres
ulong buyStopTicket = orderMgr.CreateBuyStop(0.1, 1.1000, 1.0950, 1.1100);
ulong sellStopTicket = orderMgr.CreateSellStop(0.1, 1.0900, 1.0950, 1.0800);

// Modifier un ordre
bool modified = orderMgr.ModifyOrder(buyStopTicket, 1.1005, 1.0955, 1.1105);

// Ajuster le volume
bool adjusted = orderMgr.AdjustOrderVolume(buyStopTicket, 0.2);

// Supprimer un ordre
bool deleted = orderMgr.DeleteOrder(buyStopTicket);

// Supprimer tous les ordres
int deletedCount = orderMgr.DeleteAllOrders();

// Obtenir les statistiques
int totalOrders = orderMgr.GetTotalOrders();
string status = orderMgr.GetStatusInfo();

// Nettoyage
delete orderMgr;
delete validator;
delete volumeMgr;
delete trade;
*/
