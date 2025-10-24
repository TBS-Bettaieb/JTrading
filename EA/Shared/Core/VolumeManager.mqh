//+------------------------------------------------------------------+
//|                                            VolumeManager.mqh     |
//|                    Gestionnaire de calcul de lots et volumes     |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+
#property strict

#include "../Logger.mqh"

//+------------------------------------------------------------------+
//| Classe VolumeManager - Calcul et normalisation des lots         |
//+------------------------------------------------------------------+
class VolumeManager
{
private:
   string            m_symbol;              // Symbole pour lequel calculer les lots
   double            m_point;               // Point du symbole
   double            m_tickSize;            // Taille du tick
   double            m_tickValue;           // Valeur du tick
   double            m_lotStep;             // Pas de lot
   double            m_minLot;              // Lot minimum
   double            m_maxLot;              // Lot maximum
   double            m_volumeLimit;         // Limite de volume
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   VolumeManager(string symbol)
   {
      m_symbol = symbol;
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      m_tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      m_lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      m_minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      m_maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      m_volumeLimit = SymbolInfoDouble(symbol, SYMBOL_VOLUME_LIMIT);
      
      Logger::Debug("VolumeManager initialized for " + symbol + 
                   " | Min: " + DoubleToString(m_minLot, 2) + 
                   " | Max: " + DoubleToString(m_maxLot, 2) + 
                   " | Step: " + DoubleToString(m_lotStep, 2));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~VolumeManager()
   {
      Logger::Debug("VolumeManager destroyed for " + m_symbol);
   }
   
   //+------------------------------------------------------------------+
   //| Calculer la taille du lot basée sur le risque                   |
   //| @return Lot calculé et normalisé (>= m_minLot)                  |
   //+------------------------------------------------------------------+
   double CalculateRiskBasedLots(double riskPercent, double riskMultiplier, double slPoints)
   {
      // Calculer le risque effectif
      double effectiveRisk = riskPercent * riskMultiplier;
      double risk = AccountInfoDouble(ACCOUNT_BALANCE) * effectiveRisk / 100;
      
      // ✅ OPTIMISATION: Logs détaillés seulement si LOG_DEBUG actif
      if(Logger::GetLevel() == LOG_DEBUG)
      {
         Logger::Debug("🔍 VolumeManager::CalculateRiskBasedLots:");
         Logger::Debug("  - Risk %: " + DoubleToString(riskPercent, 2) + "%");
         Logger::Debug("  - Risk Multiplier: " + DoubleToString(riskMultiplier, 2));
         Logger::Debug("  - Effective Risk: " + DoubleToString(effectiveRisk, 2) + "%");
         Logger::Debug("  - Account Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
         Logger::Debug("  - Risk Amount: " + DoubleToString(risk, 2));
         Logger::Debug("  - SL Points: " + DoubleToString(slPoints, 0));
      }
      
      // Calculer le lot basé sur le risque
      double moneyPerLotstep = slPoints / m_tickSize * m_tickValue * m_lotStep;
      
      double lots;
      if(moneyPerLotstep > 0)
      {
         // 🔥 CORRECTION CRITIQUE: Utiliser MathFloor comme dans l'ancienne version
         // MathRound peut arrondir vers le HAUT et créer des volumes invalides
         lots = MathFloor(risk / moneyPerLotstep) * m_lotStep;
         if(Logger::GetLevel() == LOG_DEBUG)
         {
            Logger::Debug("  - Money per lot step: " + DoubleToString(moneyPerLotstep, 2));
            Logger::Debug("  - Lots calculés (avant contraintes): " + DoubleToString(lots, 5));
         }
      }
      else
      {
         lots = m_minLot; // Fallback si moneyPerLotstep est 0
         Logger::Warning("⚠️ Money per lot step is 0, using min lot: " + DoubleToString(lots, 2));
      }
      
      // Appliquer les contraintes du broker
      if(m_volumeLimit != 0) lots = MathMin(lots, m_volumeLimit);
      if(m_maxLot != 0) lots = MathMin(lots, m_maxLot);
      if(m_minLot != 0) lots = MathMax(lots, m_minLot);
      
      // Normaliser avec la précision appropriée
      int precision = (m_lotStep >= 0.01) ? 2 : 3;
      lots = NormalizeDouble(lots, precision);
      
      // 🔧 CORRECTION CRITIQUE : Normaliser le volume selon le lot step AVANT de le retourner
      lots = NormalizeVolume(lots);
      
      Logger::Debug("✅ Risk calculation: " + DoubleToString(effectiveRisk, 2) + "% risk, " + 
                   DoubleToString(slPoints, 0) + " SL points = " + DoubleToString(lots, precision) + " lots");
      
      return lots;
   }
   
   //+------------------------------------------------------------------+
   //| Normaliser un volume selon les contraintes du broker            |
   //| @return Volume normalisé selon les contraintes (min >= m_minLot)|
   //+------------------------------------------------------------------+
   double NormalizeVolume(double volume)
   {
      // ✅ OPTIMISATION: Logs détaillés seulement si LOG_DEBUG actif
      if(Logger::GetLevel() == LOG_DEBUG)
      {
         Logger::Debug("🔍 VolumeManager::NormalizeVolume - Volume original: " + DoubleToString(volume, 5));
         Logger::Debug("  - Lot Step: " + DoubleToString(m_lotStep, 5));
         Logger::Debug("  - Min Lot: " + DoubleToString(m_minLot, 5));
         Logger::Debug("  - Max Lot: " + DoubleToString(m_maxLot, 5));
      }
      
      // Appliquer le pas de lot avec MathFloor (comme l'ancienne version)
      double normalizedVolume;
      if(m_lotStep > 0)
      {
         // 🔥 CORRECTION CRITIQUE: Utiliser MathFloor pour éviter les volumes invalides
         normalizedVolume = MathFloor(volume / m_lotStep) * m_lotStep;
         if(Logger::GetLevel() == LOG_DEBUG)
            Logger::Debug("  - Volume après arrondi lot step: " + DoubleToString(normalizedVolume, 5));
      }
      else
      {
         normalizedVolume = volume;
         Logger::Warning("⚠️ Lot step is 0, volume not normalized");
      }
      
      // FIXED: Vérifier si le volume normalisé est inférieur au minimum avant d'appliquer les limites
      if(m_minLot > 0 && normalizedVolume < m_minLot)
      {
         Logger::Warning("⚠️ Normalized volume " + DoubleToString(normalizedVolume, 5) + 
                        " is below min lot " + DoubleToString(m_minLot, 5) + 
                        ", using min lot instead");
         normalizedVolume = m_minLot;
      }
      
      // Appliquer les limites
      if(m_volumeLimit != 0) 
      {
         normalizedVolume = MathMin(normalizedVolume, m_volumeLimit);
         if(Logger::GetLevel() == LOG_DEBUG)
            Logger::Debug("  - Volume après limite: " + DoubleToString(normalizedVolume, 5));
      }
      if(m_maxLot != 0) 
      {
         normalizedVolume = MathMin(normalizedVolume, m_maxLot);
         if(Logger::GetLevel() == LOG_DEBUG)
            Logger::Debug("  - Volume après max lot: " + DoubleToString(normalizedVolume, 5));
      }
      if(m_minLot != 0) 
      {
         normalizedVolume = MathMax(normalizedVolume, m_minLot);
         if(Logger::GetLevel() == LOG_DEBUG)
            Logger::Debug("  - Volume après min lot: " + DoubleToString(normalizedVolume, 5));
      }
      
      // Normaliser avec la précision appropriée
      int precision = (m_lotStep >= 0.01) ? 2 : 3;
      normalizedVolume = NormalizeDouble(normalizedVolume, precision);
      
      Logger::Debug("✅ VolumeManager::NormalizeVolume - Volume final: " + DoubleToString(normalizedVolume, precision));
      
      return normalizedVolume;
   }
   
   //+------------------------------------------------------------------+
   //| Ajuster un volume avec un multiplicateur                        |
   //| @return Volume ajusté et normalisé selon le nouveau multiplicateur |
   //+------------------------------------------------------------------+
   double AdjustVolumeWithMultiplier(double currentVolume, double oldMultiplier, double newMultiplier)
   {
      // Calculer le volume de base
      double baseVolume = (oldMultiplier > 0) ? (currentVolume / oldMultiplier) : currentVolume;
      
      // Appliquer le nouveau multiplicateur
      double newVolume = baseVolume * newMultiplier;
      
      // Normaliser
      return NormalizeVolume(newVolume);
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si un volume est valide                                |
   //| @return true si le volume respecte toutes les contraintes broker |
   //+------------------------------------------------------------------+
   bool IsValidVolume(double volume)
   {
      // ✅ OPTIMISATION: Logs détaillés seulement si LOG_DEBUG actif
      if(Logger::GetLevel() == LOG_DEBUG)
         Logger::Debug("🔍 VolumeManager::IsValidVolume - Vérification volume: " + DoubleToString(volume, 5));
      
      if(volume < m_minLot) 
      {
         Logger::Error("❌ Volume " + DoubleToString(volume, 5) + " is below minimum " + DoubleToString(m_minLot, 5));
         return false;
      }
      
      if(m_maxLot > 0 && volume > m_maxLot) 
      {
         Logger::Error("❌ Volume " + DoubleToString(volume, 5) + " exceeds maximum " + DoubleToString(m_maxLot, 5));
         return false;
      }
      
      if(m_volumeLimit > 0 && volume > m_volumeLimit) 
      {
         Logger::Error("❌ Volume " + DoubleToString(volume, 5) + " exceeds limit " + DoubleToString(m_volumeLimit, 5));
         return false;
      }
      
      // Vérifier le pas de lot
      if(m_lotStep > 0)
      {
         double remainder = MathMod(volume, m_lotStep);
         if(remainder > 0.0001) 
         {
            Logger::Error("❌ Volume " + DoubleToString(volume, 5) + " is not aligned with lot step " + DoubleToString(m_lotStep, 5) + 
                         " (remainder: " + DoubleToString(remainder, 5) + ")");
            return false;
         }
      }
      
      Logger::Debug("✅ Volume " + DoubleToString(volume, 5) + " is valid");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations sur les contraintes de volume          |
   //+------------------------------------------------------------------+
   string GetVolumeConstraints()
   {
      string constraints = "Volume constraints for " + m_symbol + ": ";
      constraints += "Min=" + DoubleToString(m_minLot, 2) + 
                    ", Max=" + DoubleToString(m_maxLot, 2) + 
                    ", Step=" + DoubleToString(m_lotStep, 2);
      
      if(m_volumeLimit > 0)
         constraints += ", Limit=" + DoubleToString(m_volumeLimit, 2);
      
      return constraints;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le lot minimum                                          |
   //+------------------------------------------------------------------+
   double GetMinLot() const { return m_minLot; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le lot maximum                                          |
   //+------------------------------------------------------------------+
   double GetMaxLot() const { return m_maxLot; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le pas de lot                                           |
   //+------------------------------------------------------------------+
   double GetLotStep() const { return m_lotStep; }
   
   //+------------------------------------------------------------------+
   //| Obtenir la limite de volume                                     |
   //+------------------------------------------------------------------+
   double GetVolumeLimit() const { return m_volumeLimit; }
};

//+------------------------------------------------------------------+
//| Exemple d'utilisation                                             |
//+------------------------------------------------------------------+
/*
// Création du gestionnaire de volume
VolumeManager* volumeMgr = new VolumeManager("EURUSD");

// Calcul de lot basé sur le risque
double lots = volumeMgr.CalculateRiskBasedLots(2.0, 1.5, 100); // 2% risk, 1.5x multiplier, 100 points SL

// Normalisation d'un volume
double normalizedLots = volumeMgr.NormalizeVolume(0.123);

// Ajustement avec multiplicateur
double adjustedLots = volumeMgr.AdjustVolumeWithMultiplier(0.1, 1.0, 2.0); // Double le volume

// Validation
if(volumeMgr.IsValidVolume(lots))
{
   // Volume valide, procéder avec l'ordre
}

// Nettoyage
delete volumeMgr;
*/
