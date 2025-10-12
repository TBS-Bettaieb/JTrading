//+------------------------------------------------------------------+
//|                                              JT_AdaptiveSL.mqh  |
//|              Système de Stop Loss Adaptatif Multi-Actifs        |
//|                                      (c) 2025 - Version 1.0      |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Types d'actifs détectés automatiquement                         |
//+------------------------------------------------------------------+
enum ASSET_TYPE {
   ASSET_FOREX_MAJOR,      // EUR/USD, GBP/USD, USD/JPY...
   ASSET_FOREX_MINOR,      // EUR/GBP, AUD/NZD...
   ASSET_FOREX_EXOTIC,     // USD/TRY, EUR/ZAR...
   ASSET_INDEX,            // S&P500, DAX, NASDAQ...
   ASSET_CRYPTO,           // BTC/USD, ETH/USD...
   ASSET_COMMODITY,        // Gold, Silver, Oil...
   ASSET_UNKNOWN
};

//+------------------------------------------------------------------+
//| Profils de risque par type d'actif                              |
//+------------------------------------------------------------------+
struct AssetRiskProfile {
   double atrMultiplierMin;    // Multiplicateur ATR minimum
   double atrMultiplierMax;    // Multiplicateur ATR maximum
   double minDistancePercent;  // Distance min en % du prix
   double maxDistancePercent;  // Distance max en % du prix
   int spreadMultiplier;       // Multiplicateur du spread
   bool usePercentSL;          // Utiliser % du prix plutôt que points
   double volatilityFactor;    // Facteur de volatilité (1.0 = normal)
};

//+------------------------------------------------------------------+
//| Classe de gestion adaptative du SL                              |
//+------------------------------------------------------------------+
class JTAdaptiveSL {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   ASSET_TYPE m_assetType;
   AssetRiskProfile m_profile;
   int m_atrHandle;
   
   // Détection automatique du type d'actif
   ASSET_TYPE DetectAssetType(string symbol) {
      string sym = symbol;
      StringToUpper(sym);
      
      // Cryptos - patterns typiques
      if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || 
         StringFind(sym, "XRP") >= 0 || StringFind(sym, "LTC") >= 0 ||
         StringFind(sym, "ADA") >= 0 || StringFind(sym, "DOGE") >= 0) {
         return ASSET_CRYPTO;
      }
      
      // Indices - patterns typiques
      if(StringFind(sym, "SPX") >= 0 || StringFind(sym, "NAS") >= 0 || 
         StringFind(sym, "DAX") >= 0 || StringFind(sym, "FTSE") >= 0 ||
         StringFind(sym, "DJ") >= 0 || StringFind(sym, "NDX") >= 0 ||
         StringFind(sym, "US30") >= 0 || StringFind(sym, "US100") >= 0 ||
         StringFind(sym, "GER") >= 0 || StringFind(sym, "UK100") >= 0) {
         return ASSET_INDEX;
      }
      
      // Commodités
      if(StringFind(sym, "GOLD") >= 0 || StringFind(sym, "XAU") >= 0 ||
         StringFind(sym, "SILVER") >= 0 || StringFind(sym, "XAG") >= 0 ||
         StringFind(sym, "OIL") >= 0 || StringFind(sym, "WTI") >= 0 ||
         StringFind(sym, "BRENT") >= 0) {
         return ASSET_COMMODITY;
      }
      
      // Forex - vérifier la structure (6 caractères typiquement)
      int symLen = StringLen(sym);
      if(symLen >= 6) {
         string base = StringSubstr(sym, 0, 3);
         string quote = StringSubstr(sym, 3, 3);
         
         // Liste des devises majeures
         string majors[] = {"USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD"};
         bool baseIsMajor = false, quoteIsMajor = false;
         
         for(int i = 0; i < ArraySize(majors); i++) {
            if(base == majors[i]) baseIsMajor = true;
            if(quote == majors[i]) quoteIsMajor = true;
         }
         
         // Paires majeures (USD + autre majeure)
         if((base == "USD" || quote == "USD") && baseIsMajor && quoteIsMajor) {
            return ASSET_FOREX_MAJOR;
         }
         
         // Paires mineures (deux majeures sans USD)
         if(baseIsMajor && quoteIsMajor) {
            return ASSET_FOREX_MINOR;
         }
         
         // Paires exotiques (au moins une devise non majeure)
         if(baseIsMajor || quoteIsMajor) {
            return ASSET_FOREX_EXOTIC;
         }
      }
      
      return ASSET_UNKNOWN;
   }
   
   // Configurer le profil selon le type d'actif
   void ConfigureProfile() {
      switch(m_assetType) {
         case ASSET_FOREX_MAJOR:
            m_profile.atrMultiplierMin = 2.5;
            m_profile.atrMultiplierMax = 4.0;
            m_profile.minDistancePercent = 0.15;  // 0.15% du prix
            m_profile.maxDistancePercent = 0.50;  // 0.50% du prix
            m_profile.spreadMultiplier = 3;
            m_profile.usePercentSL = false;
            m_profile.volatilityFactor = 1.0;
            break;
            
         case ASSET_FOREX_MINOR:
            m_profile.atrMultiplierMin = 3.0;
            m_profile.atrMultiplierMax = 4.5;
            m_profile.minDistancePercent = 0.20;
            m_profile.maxDistancePercent = 0.60;
            m_profile.spreadMultiplier = 4;
            m_profile.usePercentSL = false;
            m_profile.volatilityFactor = 1.2;
            break;
            
         case ASSET_FOREX_EXOTIC:
            m_profile.atrMultiplierMin = 3.5;
            m_profile.atrMultiplierMax = 5.0;
            m_profile.minDistancePercent = 0.30;
            m_profile.maxDistancePercent = 0.80;
            m_profile.spreadMultiplier = 5;
            m_profile.usePercentSL = true;  // Utiliser % pour les exotiques
            m_profile.volatilityFactor = 1.5;
            break;
            
         case ASSET_INDEX:
            m_profile.atrMultiplierMin = 2.0;
            m_profile.atrMultiplierMax = 3.5;
            m_profile.minDistancePercent = 0.10;
            m_profile.maxDistancePercent = 0.40;
            m_profile.spreadMultiplier = 2;
            m_profile.usePercentSL = false;
            m_profile.volatilityFactor = 1.0;
            break;
            
         case ASSET_CRYPTO:
            m_profile.atrMultiplierMin = 3.0;
            m_profile.atrMultiplierMax = 5.0;
            m_profile.minDistancePercent = 0.50;  // 0.5% - Crypto très volatil
            m_profile.maxDistancePercent = 2.00;  // 2.0% max
            m_profile.spreadMultiplier = 5;
            m_profile.usePercentSL = true;  // Toujours en % pour crypto
            m_profile.volatilityFactor = 2.0;  // Double volatilité
            break;
            
         case ASSET_COMMODITY:
            m_profile.atrMultiplierMin = 2.5;
            m_profile.atrMultiplierMax = 4.0;
            m_profile.minDistancePercent = 0.20;
            m_profile.maxDistancePercent = 0.60;
            m_profile.spreadMultiplier = 3;
            m_profile.usePercentSL = false;
            m_profile.volatilityFactor = 1.2;
            break;
            
         default: // ASSET_UNKNOWN - Configuration conservatrice
            m_profile.atrMultiplierMin = 3.0;
            m_profile.atrMultiplierMax = 4.5;
            m_profile.minDistancePercent = 0.25;
            m_profile.maxDistancePercent = 0.75;
            m_profile.spreadMultiplier = 4;
            m_profile.usePercentSL = true;
            m_profile.volatilityFactor = 1.5;
            break;
      }
   }
   
   // Calculer l'ATR actuel
   double GetCurrentATR() {
      if(m_atrHandle == INVALID_HANDLE) return 0;
      
      double atr[];
      ArraySetAsSeries(atr, true);
      
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) <= 0) {
         return 0;
      }
      
      return atr[0];
   }
   
   // Obtenir le spread en points
   int GetSpreadPoints() {
      return (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   }
   
   // Calculer la distance minimale basée sur le spread
   double GetMinDistanceFromSpread() {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int spread = GetSpreadPoints();
      
      return spread * m_profile.spreadMultiplier * point;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                     |
   //+------------------------------------------------------------------+
   JTAdaptiveSL(string symbol, ENUM_TIMEFRAMES timeframe, int atrPeriod = 14) {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_atrHandle = INVALID_HANDLE;
      
      // Détecter le type d'actif
      m_assetType = DetectAssetType(symbol);
      
      // Configurer le profil
      ConfigureProfile();
      
      // Initialiser l'ATR
      m_atrHandle = iATR(symbol, timeframe, atrPeriod);
      if(m_atrHandle == INVALID_HANDLE) {
         Print("Erreur création handle ATR pour ", symbol);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Destructeur                                                      |
   //+------------------------------------------------------------------+
   ~JTAdaptiveSL() {
      if(m_atrHandle != INVALID_HANDLE) {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le type d'actif détecté                                 |
   //+------------------------------------------------------------------+
   ASSET_TYPE GetAssetType() { return m_assetType; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nom du type d'actif                                  |
   //+------------------------------------------------------------------+
   string GetAssetTypeName() {
      switch(m_assetType) {
         case ASSET_FOREX_MAJOR: return "Forex Major";
         case ASSET_FOREX_MINOR: return "Forex Minor";
         case ASSET_FOREX_EXOTIC: return "Forex Exotic";
         case ASSET_INDEX: return "Index";
         case ASSET_CRYPTO: return "Crypto";
         case ASSET_COMMODITY: return "Commodity";
         default: return "Unknown";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculer le SL adaptatif optimal                                |
   //+------------------------------------------------------------------+
   double CalculateAdaptiveSL(bool isBuy, double entryPrice, string &reason) {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double atr = GetCurrentATR();
      
      if(atr <= 0) {
         reason = "ATR invalide";
         return 0;
      }
      
      // Méthode 1: SL basé sur ATR avec multiplicateur adaptatif
      double atrMultiplier = (m_profile.atrMultiplierMin + m_profile.atrMultiplierMax) / 2.0;
      atrMultiplier *= m_profile.volatilityFactor;
      
      double slDistanceATR = atr * atrMultiplier;
      
      // Méthode 2: SL basé sur % du prix (pour actifs très volatils)
      double slDistancePercent = entryPrice * m_profile.minDistancePercent / 100.0;
      
      // Méthode 3: SL basé sur le spread
      double slDistanceSpread = GetMinDistanceFromSpread();
      
      // Choisir la distance la plus grande (la plus protectrice)
      double slDistance = MathMax(slDistanceATR, slDistancePercent);
      slDistance = MathMax(slDistance, slDistanceSpread);
      
      // Valider les limites min/max en % du prix
      double minDistance = entryPrice * m_profile.minDistancePercent / 100.0;
      double maxDistance = entryPrice * m_profile.maxDistancePercent / 100.0;
      
      slDistance = MathMax(slDistance, minDistance);
      slDistance = MathMin(slDistance, maxDistance);
      
      // Calculer le SL final
      double sl = isBuy ? (entryPrice - slDistance) : (entryPrice + slDistance);
      
      // Raison du calcul
      reason = StringFormat("ATR:%.1fx (%.5f) | Spread:%dx | Dist:%.2f%%",
                           atrMultiplier, atr, m_profile.spreadMultiplier,
                           (slDistance / entryPrice) * 100.0);
      
      return NormalizeDouble(sl, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
   }
   
   //+------------------------------------------------------------------+
   //| Valider un SL existant                                          |
   //+------------------------------------------------------------------+
   bool ValidateSL(bool isBuy, double entryPrice, double stopLoss, string &errorMsg) {
      if(stopLoss <= 0) {
         errorMsg = "SL est zéro ou négatif";
         return false;
      }
      
      // Vérifier la direction
      if(isBuy && stopLoss >= entryPrice) {
         errorMsg = "SL BUY doit être < entry";
         return false;
      }
      if(!isBuy && stopLoss <= entryPrice) {
         errorMsg = "SL SELL doit être > entry";
         return false;
      }
      
      // Calculer la distance en % du prix
      double slDistance = MathAbs(entryPrice - stopLoss);
      double slPercent = (slDistance / entryPrice) * 100.0;
      
      // Valider contre les limites du profil
      if(slPercent < m_profile.minDistancePercent) {
         errorMsg = StringFormat("SL trop proche: %.2f%% < %.2f%% min (%s)",
                                slPercent, m_profile.minDistancePercent, GetAssetTypeName());
         return false;
      }
      
      if(slPercent > m_profile.maxDistancePercent) {
         errorMsg = StringFormat("SL trop loin: %.2f%% > %.2f%% max (%s)",
                                slPercent, m_profile.maxDistancePercent, GetAssetTypeName());
         return false;
      }
      
      // Vérifier la distance minimum basée sur le spread
      double minSpreadDistance = GetMinDistanceFromSpread();
      if(slDistance < minSpreadDistance) {
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         errorMsg = StringFormat("SL trop proche du spread: %.1f pts < %.1f pts min",
                                slDistance / point, minSpreadDistance / point);
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les recommandations pour l'actif actuel                 |
   //+------------------------------------------------------------------+
   string GetRecommendations() {
      string rec = "\n╔══════════════════════════════════════════════════╗\n";
      rec += StringFormat("║ Actif: %-42s║\n", m_symbol);
      rec += StringFormat("║ Type: %-43s║\n", GetAssetTypeName());
      rec += "╠══════════════════════════════════════════════════╣\n";
      rec += "║ RECOMMANDATIONS ADAPTATIVES                      ║\n";
      rec += "╠══════════════════════════════════════════════════╣\n";
      rec += StringFormat("║ Multiplicateur ATR: %.1f - %.1f%-18s║\n",
                         m_profile.atrMultiplierMin, m_profile.atrMultiplierMax, "");
      rec += StringFormat("║ Distance SL min: %.2f%% du prix%-18s║\n",
                         m_profile.minDistancePercent, "");
      rec += StringFormat("║ Distance SL max: %.2f%% du prix%-18s║\n",
                         m_profile.maxDistancePercent, "");
      rec += StringFormat("║ Multiplicateur spread: %dx%-24s║\n",
                         m_profile.spreadMultiplier, "");
      rec += StringFormat("║ Facteur volatilité: %.1fx%-25s║\n",
                         m_profile.volatilityFactor, "");
      rec += StringFormat("║ Utiliser %% du prix: %s%-26s║\n",
                         m_profile.usePercentSL ? "OUI" : "NON", "");
      rec += "╠══════════════════════════════════════════════════╣\n";
      
      // Ajouter les valeurs actuelles du marché
      double atr = GetCurrentATR();
      int spread = GetSpreadPoints();
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      rec += "║ VALEURS ACTUELLES DU MARCHÉ                      ║\n";
      rec += "╠══════════════════════════════════════════════════╣\n";
      rec += StringFormat("║ Prix: %.5f%-37s║\n", price, "");
      rec += StringFormat("║ ATR(14): %.5f%-35s║\n", atr, "");
      rec += StringFormat("║ Spread: %d points%-33s║\n", spread, "");
      rec += StringFormat("║ Distance SL min recommandée: %.2f%%%-17s║\n",
                         (atr * m_profile.atrMultiplierMin / price) * 100.0, "");
      rec += "╚══════════════════════════════════════════════════╝\n";
      
      return rec;
   }
   
   //+------------------------------------------------------------------+
   //| Ajuster dynamiquement le profil selon la volatilité             |
   //+------------------------------------------------------------------+
   void AdjustForVolatility(double volatilityMultiplier = 1.0) {
      // Permet d'ajuster temporairement le profil
      // Par exemple, augmenter les distances si détection de forte volatilité
      m_profile.atrMultiplierMin *= volatilityMultiplier;
      m_profile.atrMultiplierMax *= volatilityMultiplier;
      m_profile.minDistancePercent *= volatilityMultiplier;
      m_profile.maxDistancePercent *= volatilityMultiplier;
   }
};

