//+------------------------------------------------------------------+
//| SymbolClassifier.mqh - Asset classification and thresholds      |
//| Utility class for detecting asset types and dynamic thresholds   |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Asset Classification Enumeration                                |
//+------------------------------------------------------------------+
enum ENUM_ASSET_CLASS
{
   ASSET_FOREX = 0,
   ASSET_INDICES = 1,
   ASSET_CRYPTO = 2,
   ASSET_COMMODITIES = 3,
   ASSET_UNKNOWN = 4
};

//+------------------------------------------------------------------+
//| Symbol Classifier Utility Class                                 |
//+------------------------------------------------------------------+
class SymbolClassifier
{
public:
   //+------------------------------------------------------------------+
   //| Detect asset class based on symbol name pattern                 |
   //| @param symbol - symbol name to classify                         |
   //| @return ENUM_ASSET_CLASS - detected asset type                 |
   //+------------------------------------------------------------------+
   static ENUM_ASSET_CLASS DetectAssetClass(string symbol)
   {
      string upperSymbol = symbol;
      StringToUpper(upperSymbol);
      
      // Check for Forex (currency pairs)
      if(IsForexSymbol(upperSymbol))
         return ASSET_FOREX;
      
      // Check for Indices
      if(IsIndexSymbol(upperSymbol))
         return ASSET_INDICES;
      
      // Check for Crypto
      if(IsCryptoSymbol(upperSymbol))
         return ASSET_CRYPTO;
      
      // Check for Commodities
      if(IsCommoditySymbol(upperSymbol))
         return ASSET_COMMODITIES;
      
      return ASSET_UNKNOWN;
   }
   
   //+------------------------------------------------------------------+
   //| Get minimum threshold points based on asset class                |
   //| @param assetClass - classified asset type                       |
   //| @param symbol - symbol name for additional context              |
   //| @return double - minimum threshold in points                   |
   //+------------------------------------------------------------------+
   static double GetMinThresholdPoints(ENUM_ASSET_CLASS assetClass, string symbol)
   {
      switch(assetClass)
      {
         case ASSET_FOREX:
            return GetForexThreshold(symbol);
            
         case ASSET_INDICES:
            return GetIndexThreshold(symbol);
            
         case ASSET_CRYPTO:
            return GetCryptoThreshold(symbol);
            
         case ASSET_COMMODITIES:
            return GetCommodityThreshold(symbol);
            
         default:
            Print("⚠️ Unknown asset class, using forex default threshold");
            return GetForexThreshold(symbol);
      }
   }

private:
   //+------------------------------------------------------------------+
   //| Check if symbol is Forex (currency pair)                        |
   //+------------------------------------------------------------------+
   static bool IsForexSymbol(string upperSymbol)
   {
      // Major currency pairs
      string currencies[] = {"EUR", "USD", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD"};
      
      for(int i = 0; i < ArraySize(currencies); i++)
      {
         if(StringFind(upperSymbol, currencies[i]) >= 0)
         {
            // Additional check - should contain at least 2 currency codes
            int count = 0;
            for(int j = 0; j < ArraySize(currencies); j++)
            {
               if(StringFind(upperSymbol, currencies[j]) >= 0)
                  count++;
            }
            if(count >= 2)
               return true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if symbol is Index                                         |
   //+------------------------------------------------------------------+
   static bool IsIndexSymbol(string upperSymbol)
   {
      string indices[] = {
         "US30", "US100", "US500", "NAS100", "GER40", "UK100", 
         "SPX", "DJI", "NDX", "DAX", "FTSE", "NQ", "ES", "YM"
      };
      
      for(int i = 0; i < ArraySize(indices); i++)
      {
         if(StringFind(upperSymbol, indices[i]) >= 0)
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if symbol is Crypto                                        |
   //+------------------------------------------------------------------+
   static bool IsCryptoSymbol(string upperSymbol)
   {
      string crypto[] = {"BTC", "ETH", "LTC", "XRP", "BCH", "ADA", "DOT", "LINK", "UNI", "AAVE"};
      
      for(int i = 0; i < ArraySize(crypto); i++)
      {
         if(StringFind(upperSymbol, crypto[i]) >= 0)
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if symbol is Commodity                                     |
   //+------------------------------------------------------------------+
   static bool IsCommoditySymbol(string upperSymbol)
   {
      string commodities[] = {"XAU", "XAG", "GOLD", "SILVER", "OIL", "CRUDE", "WTI", "BRENT"};
      
      for(int i = 0; i < ArraySize(commodities); i++)
      {
         if(StringFind(upperSymbol, commodities[i]) >= 0)
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get Forex threshold based on pip value                           |
   //+------------------------------------------------------------------+
   static double GetForexThreshold(string symbol)
   {
      double pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(pipValue > 0 && tickSize > 0 && point > 0)
      {
         // Calculate pip size (usually 0.0001 for major pairs, 0.01 for JPY pairs)
         double pipSize = point * 10;
         if(StringFind(symbol, "JPY") >= 0 || StringFind(symbol, "jpy") >= 0)
            pipSize = point;
            
         // Threshold: 15-25 pips minimum distance
         return 15 * pipSize / point;  // Convert to points
      }
      
      // Fallback: assume 4-digit quote, 15 points = ~1.5 pips
      return 15.0;
   }
   
   //+------------------------------------------------------------------+
   //| Get Index threshold based on volatility                          |
   //+------------------------------------------------------------------+
   static double GetIndexThreshold(string symbol)
   {
      // Indices are more volatile, need larger thresholds
      if(StringFind(symbol, "US30") >= 0 || StringFind(symbol, "DJI") >= 0)
         return 200.0;  // Dow Jones - higher volatility
      
      if(StringFind(symbol, "US100") >= 0 || StringFind(symbol, "NAS100") >= 0 || StringFind(symbol, "NDX") >= 0)
         return 300.0;  // NASDAQ - very high volatility
         
      if(StringFind(symbol, "US500") >= 0 || StringFind(symbol, "SPX") >= 0)
         return 250.0;  // S&P 500 - high volatility
      
      // Default for other indices
      return 250.0;
   }
   
   //+------------------------------------------------------------------+
   //| Get Crypto threshold based on volatility                         |
   //+------------------------------------------------------------------+
   static double GetCryptoThreshold(string symbol)
   {
      // Crypto is extremely volatile
      if(StringFind(symbol, "BTC") >= 0)
         return 800.0;  // Bitcoin - very high volatility
      
      if(StringFind(symbol, "ETH") >= 0)
         return 900.0;  // Ethereum - extreme volatility
      
      // Default for other crypto
      return 1000.0;
   }
   
   //+------------------------------------------------------------------+
   //| Get Commodity threshold based on asset type                      |
   //+------------------------------------------------------------------+
   static double GetCommodityThreshold(string symbol)
   {
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
         return 100.0;  // Gold - moderate volatility
      
      if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
         return 150.0;  // Silver - higher volatility than gold
      
      if(StringFind(symbol, "OIL") >= 0 || StringFind(symbol, "CRUDE") >= 0)
         return 80.0;   // Oil - moderate volatility
      
      // Default for other commodities
      return 120.0;
   }
};
