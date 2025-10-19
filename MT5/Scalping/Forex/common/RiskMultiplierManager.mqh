//+------------------------------------------------------------------+
//|                                     RiskMultiplierManager.mqh   |
//|                    Gestionnaire de multiplication de risque      |
//|                                          (c) 2025 - Public Domain |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Structure pour une période de multiplication                    |
//+------------------------------------------------------------------+
struct RiskMultiplierPeriod {
   bool enabled;
   int startHour;
   int startMinute;
   int endHour;
   int endMinute;
   double multiplier;
   string description;
};

//+------------------------------------------------------------------+
//| Classe RiskMultiplierManager                                    |
//+------------------------------------------------------------------+
class RiskMultiplierManager {
private:
   RiskMultiplierPeriod m_period;
   bool m_wasActive;
   datetime m_lastCheckTime;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   RiskMultiplierManager()
   {
      m_period.enabled = false;
      m_period.startHour = 0;
      m_period.startMinute = 0;
      m_period.endHour = 0;
      m_period.endMinute = 0;
      m_period.multiplier = 1.0;
      m_period.description = "";
      m_wasActive = false;
      m_lastCheckTime = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Initialiser le gestionnaire                                     |
   //+------------------------------------------------------------------+
   void Initialize(bool enabled, int startHour, int startMinute, 
                   int endHour, int endMinute, double multiplier,
                   string description = "Risk Boost Period")
   {
      m_period.enabled = enabled;
      m_period.startHour = MathMax(0, MathMin(23, startHour));
      m_period.startMinute = MathMax(0, MathMin(59, startMinute));
      m_period.endHour = MathMax(0, MathMin(23, endHour));
      m_period.endMinute = MathMax(0, MathMin(59, endMinute));
      m_period.multiplier = MathMax(0.1, MathMin(10.0, multiplier));
      m_period.description = description;
      m_lastCheckTime = 0;
      
      if(m_period.enabled)
      {
         if(ValidatePeriod())
         {
            Print("🚀 RISK MULTIPLIER ACTIVÉ: ", description);
            Print("   Période: ", GetPeriodString());
            Print("   Multiplicateur: x", DoubleToString(m_period.multiplier, 2));
         }
         else
         {
            Print("❌ ERREUR: Configuration Risk Multiplier invalide");
            m_period.enabled = false;
         }
      }
      else
      {
         Print("ℹ️ Risk Multiplier DÉSACTIVÉ");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir le multiplicateur actuel                                |
   //+------------------------------------------------------------------+
   double GetCurrentMultiplier()
   {
      if(!m_period.enabled) return 1.0;
      
      if(IsInActivePeriod())
         return m_period.multiplier;
      else
         return 1.0;
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si on est dans la période active                       |
   //+------------------------------------------------------------------+
   bool IsInActivePeriod()
   {
      if(!m_period.enabled) return false;
      
      datetime currentTime = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      int currentMinutes = dt.hour * 60 + dt.min;
      int startMinutes = m_period.startHour * 60 + m_period.startMinute;
      int endMinutes = m_period.endHour * 60 + m_period.endMinute;
      
      // Gérer les périodes traversant minuit (ex: 22h-2h)
      if(endMinutes <= startMinutes)
      {
         // Période traverse minuit
         return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
      }
      else
      {
         // Période normale
         return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Vérifier si le statut a changé                                  |
   //+------------------------------------------------------------------+
   bool HasStatusChanged()
   {
      datetime currentTime = TimeCurrent();
      
      // Vérifier chaque minute seulement
      if(currentTime - m_lastCheckTime < 60) return false;
      
      bool currentlyActive = IsInActivePeriod();
      
      if(m_wasActive != currentlyActive)
      {
         m_wasActive = currentlyActive;
         m_lastCheckTime = currentTime;
         
         if(currentlyActive)
         {
            Print("🟡 RISK MULTIPLIER ACTIVÉ: x", DoubleToString(m_period.multiplier, 2), 
                  " | Période: ", GetPeriodString());
         }
         else
         {
            Print("🔴 RISK MULTIPLIER DÉSACTIVÉ | Retour à x1.0");
         }
         
         return true;
      }
      
      m_lastCheckTime = currentTime;
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la description du statut                                |
   //+------------------------------------------------------------------+
   string GetStatusDescription()
   {
      if(!m_period.enabled)
         return "Risk Mult: OFF";
      
      double currentMultiplier = GetCurrentMultiplier();
      if(IsInActivePeriod())
         return StringFormat("Risk Mult: x%.1f", currentMultiplier);
      else
         return "Risk Mult: x1.0";
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir les informations détaillées                             |
   //+------------------------------------------------------------------+
   string GetDetailedInfo()
   {
      if(!m_period.enabled)
         return "Risk Multiplier: DISABLED";
      
      string info = "Risk Multiplier: " + m_period.description + "\n";
      info += "  Period: " + GetPeriodString() + "\n";
      info += "  Multiplier: x" + DoubleToString(m_period.multiplier, 2) + "\n";
      info += "  Status: " + (IsInActivePeriod() ? "ACTIVE" : "INACTIVE");
      
      return info;
   }

private:
   //+------------------------------------------------------------------+
   //| Valider la configuration de la période                          |
   //+------------------------------------------------------------------+
   bool ValidatePeriod()
   {
      // Vérifier les heures (0-23)
      if(m_period.startHour < 0 || m_period.startHour > 23 ||
         m_period.endHour < 0 || m_period.endHour > 23)
      {
         Print("❌ Erreur: Heures invalides (doivent être entre 0 et 23)");
         return false;
      }
      
      // Vérifier les minutes (0-59)
      if(m_period.startMinute < 0 || m_period.startMinute > 59 ||
         m_period.endMinute < 0 || m_period.endMinute > 59)
      {
         Print("❌ Erreur: Minutes invalides (doivent être entre 0 et 59)");
         return false;
      }
      
      // Vérifier le multiplicateur (0.1 à 10.0)
      if(m_period.multiplier < 0.1 || m_period.multiplier > 10.0)
      {
         Print("❌ Erreur: Multiplicateur invalide (doit être entre 0.1 et 10.0)");
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir la chaîne de période formatée                           |
   //+------------------------------------------------------------------+
   string GetPeriodString()
   {
      return StringFormat("%02d:%02d-%02d:%02d", 
                         m_period.startHour, m_period.startMinute,
                         m_period.endHour, m_period.endMinute);
   }
};
