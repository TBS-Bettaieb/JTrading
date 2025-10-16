//+------------------------------------------------------------------+
//|                                        TrailingTP_System.mqh     |
//|                   Système de Trailing Take Profit avancé        |
//|                   avec modes Linear, Stepped, Exponential et CUSTOM |
//|                                                                   |
//| VERSION: 2.0 - Mode CUSTOM ajouté                                |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "2.0"
#property strict

//+------------------------------------------------------------------+
//| Énumération des modes de Trailing TP                            |
//+------------------------------------------------------------------+
enum ENUM_TRAILING_TP_MODE
{
   TRAILING_TP_LINEAR,        // Mode linéaire (75% → SL+50%, TP+25%)
   TRAILING_TP_STEPPED,       // Mode par paliers (50% → BE, puis +50% TP)
   TRAILING_TP_EXPONENTIAL,   // Mode exponentiel (gains x8+)
   TRAILING_TP_CUSTOM         // Mode personnalisé avec niveaux définis
};

//+------------------------------------------------------------------+
//| Structure pour les niveaux personnalisés                        |
//+------------------------------------------------------------------+
struct TrailingLevel
{
   double profitPercent;      // Pourcentage de profit pour déclencher
   double slMovePercent;      // Pourcentage de déplacement du SL
   double tpExtendPercent;    // Pourcentage d'extension du TP
};

//+------------------------------------------------------------------+
//| Classe principale du système de Trailing TP                     |
//+------------------------------------------------------------------+
class CTrailingTP
{
private:
   // Configuration
   ENUM_TRAILING_TP_MODE m_mode;
   string m_customLevelsString;  // String des niveaux custom
   TrailingLevel m_customLevels[]; // Array des niveaux custom
   int m_levelCount;             // Nombre de niveaux custom
   
   // État de la position
   double m_entryPrice;
   double m_initialSL;
   double m_initialTP;
   bool m_isBuy;
   
   // Suivi des profits
   double m_maxProfit;
   double m_currentProfit;
   int m_currentLevel;           // Niveau actuel (0 = pas encore déclenché)
   
   // Validation
   bool m_isInitialized;
   bool m_isValidConfig;

public:
   //+------------------------------------------------------------------+
   //| Constructeur                                                    |
   //+------------------------------------------------------------------+
   CTrailingTP(ENUM_TRAILING_TP_MODE mode = TRAILING_TP_STEPPED, string customLevels = "")
   {
      m_mode = mode;
      m_customLevelsString = customLevels;
      m_levelCount = 0;
      
      m_entryPrice = 0;
      m_initialSL = 0;
      m_initialTP = 0;
      m_isBuy = true;
      
      m_maxProfit = 0;
      m_currentProfit = 0;
      m_currentLevel = 0;
      
      m_isInitialized = false;
      m_isValidConfig = true;
      
      // Parser les niveaux custom si fournis
      if(mode == TRAILING_TP_CUSTOM && customLevels != "")
      {
         ParseCustomLevels(customLevels);
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                      |
   //+------------------------------------------------------------------+
   ~CTrailingTP()
   {
      ArrayFree(m_customLevels);
   }

   //+------------------------------------------------------------------+
   //| Initialiser avec les données de position                       |
   //+------------------------------------------------------------------+
   bool Initialize(double entryPrice, double initialSL, double initialTP, bool isBuy)
   {
      if(entryPrice <= 0 || initialTP <= 0)
      {
         Print("❌ TrailingTP: Paramètres invalides - Entry: ", entryPrice, " TP: ", initialTP);
         return false;
      }
      
      m_entryPrice = entryPrice;
      m_initialSL = initialSL;
      m_initialTP = initialTP;
      m_isBuy = isBuy;
      
      m_maxProfit = 0;
      m_currentProfit = 0;
      m_currentLevel = 0;
      
      m_isInitialized = true;
      
      // Validation de la configuration
      m_isValidConfig = ValidateConfiguration();
      
      if(!m_isValidConfig)
      {
         Print("❌ TrailingTP: Configuration invalide pour le mode ", EnumToString(m_mode));
         return false;
      }
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| Mettre à jour avec le prix actuel                              |
   //+------------------------------------------------------------------+
   bool Update(double currentPrice, double &newSL, double &newTP)
   {
      if(!m_isInitialized || !m_isValidConfig)
         return false;
      
      // Calculer le profit actuel
      double profit = CalculateProfit(currentPrice);
      m_currentProfit = profit;
      
      // Mettre à jour le profit maximum
      if(profit > m_maxProfit)
         m_maxProfit = profit;
      
      // Appliquer la logique selon le mode
      bool modified = false;
      
      switch(m_mode)
      {
         case TRAILING_TP_LINEAR:
            modified = UpdateLinear(currentPrice, newSL, newTP);
            break;
            
         case TRAILING_TP_STEPPED:
            modified = UpdateStepped(currentPrice, newSL, newTP);
            break;
            
         case TRAILING_TP_EXPONENTIAL:
            modified = UpdateExponential(currentPrice, newSL, newTP);
            break;
            
         case TRAILING_TP_CUSTOM:
            modified = UpdateCustom(currentPrice, newSL, newTP);
            break;
      }
      
      return modified;
   }

   //+------------------------------------------------------------------+
   //| Obtenir le mode actuel                                         |
   //+------------------------------------------------------------------+
   ENUM_TRAILING_TP_MODE GetMode() const { return m_mode; }
   
   //+------------------------------------------------------------------+
   //| Obtenir la string des niveaux custom                           |
   //+------------------------------------------------------------------+
   string GetCustomLevelsString() const { return m_customLevelsString; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le nombre de niveaux custom                            |
   //+------------------------------------------------------------------+
   int GetLevelCount() const { return m_levelCount; }

   //+------------------------------------------------------------------+
   //| Obtenir les informations de statut                             |
   //+------------------------------------------------------------------+
   string GetStatusInfo()
   {
      string info = "Trailing TP: ";
      info += EnumToString(m_mode);
      
      if(m_mode == TRAILING_TP_CUSTOM)
      {
         info += " | Niveau: " + IntegerToString(m_currentLevel) + "/" + IntegerToString(m_levelCount);
      }
      else
      {
         info += " | Niveau: " + IntegerToString(m_currentLevel);
      }
      
      info += " | Max Profit: " + DoubleToString(m_maxProfit, 2) + "%";
      return info;
   }

   //+------------------------------------------------------------------+
   //| Validation de la configuration                                 |
   //+------------------------------------------------------------------+
   bool ValidateConfiguration()
   {
      switch(m_mode)
      {
         case TRAILING_TP_LINEAR:
         case TRAILING_TP_STEPPED:
         case TRAILING_TP_EXPONENTIAL:
            return true; // Modes prédéfinis toujours valides
            
         case TRAILING_TP_CUSTOM:
            return ValidateCustomLevels();
            
         default:
            return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Définir des paliers personnalisés                              |
   //+------------------------------------------------------------------+
   void SetCustomLevels(TrailingLevel &levels[])
   {
      if(m_mode != TRAILING_TP_CUSTOM) return;
      
      int size = ArraySize(levels);
      ArrayResize(m_customLevels, size);
      
      for(int i = 0; i < size; i++)
      {
         m_customLevels[i] = levels[i];
      }
      
      m_levelCount = size;
   }

private:
   //+------------------------------------------------------------------+
   //| Calculer le profit en pourcentage                              |
   //+------------------------------------------------------------------+
   double CalculateProfit(double currentPrice)
   {
      if(m_isBuy)
      {
         return ((currentPrice - m_entryPrice) / m_entryPrice) * 100;
      }
      else
      {
         return ((m_entryPrice - currentPrice) / m_entryPrice) * 100;
      }
   }

   //+------------------------------------------------------------------+
   //| Mode linéaire : 75% → SL+50%, TP+25%                          |
   //+------------------------------------------------------------------+
   bool UpdateLinear(double currentPrice, double &newSL, double &newTP)
   {
      if(m_currentLevel > 0) return false; // Déjà activé
      
      if(m_maxProfit >= 75.0) // 75% de profit
      {
         double slMove = (m_initialTP - m_initialSL) * 0.5; // 50% de la distance SL-TP
         double tpExtend = (m_initialTP - m_initialSL) * 0.25; // 25% de la distance SL-TP
         
         if(m_isBuy)
         {
            newSL = m_initialSL + slMove;
            newTP = m_initialTP + tpExtend;
         }
         else
         {
            newSL = m_initialSL - slMove;
            newTP = m_initialTP - tpExtend;
         }
         
         m_currentLevel = 1;
         return true;
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| Mode par paliers : 50% → BE, puis +50% TP                     |
   //+------------------------------------------------------------------+
   bool UpdateStepped(double currentPrice, double &newSL, double &newTP)
   {
      if(m_maxProfit >= 50.0 && m_currentLevel == 0) // Premier palier : 50%
      {
         // Mettre SL à BE
         newSL = m_entryPrice;
         newTP = m_initialTP; // Garder TP initial
         m_currentLevel = 1;
         return true;
      }
      else if(m_maxProfit >= 100.0 && m_currentLevel == 1) // Deuxième palier : 100%
      {
         // Étendre TP de 50%
         double tpExtend = (m_initialTP - m_entryPrice) * 0.5;
         
         if(m_isBuy)
         {
            newSL = m_entryPrice; // Garder SL à BE
            newTP = m_initialTP + tpExtend;
         }
         else
         {
            newSL = m_entryPrice; // Garder SL à BE
            newTP = m_initialTP - tpExtend;
         }
         
         m_currentLevel = 2;
         return true;
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| Mode exponentiel : gains x8+                                  |
   //+------------------------------------------------------------------+
   bool UpdateExponential(double currentPrice, double &newSL, double &newTP)
   {
      if(m_maxProfit >= 25.0 && m_currentLevel == 0) // 25% → SL à BE
      {
         newSL = m_entryPrice;
         newTP = m_initialTP;
         m_currentLevel = 1;
         return true;
      }
      else if(m_maxProfit >= 50.0 && m_currentLevel == 1) // 50% → TP x2
      {
         double tpExtend = (m_initialTP - m_entryPrice);
         
         if(m_isBuy)
         {
            newSL = m_entryPrice;
            newTP = m_initialTP + tpExtend;
         }
         else
         {
            newSL = m_entryPrice;
            newTP = m_initialTP - tpExtend;
         }
         
         m_currentLevel = 2;
         return true;
      }
      else if(m_maxProfit >= 100.0 && m_currentLevel == 2) // 100% → TP x4
      {
         double tpExtend = (m_initialTP - m_entryPrice) * 3;
         
         if(m_isBuy)
         {
            newSL = m_entryPrice;
            newTP = m_initialTP + tpExtend;
         }
         else
         {
            newSL = m_entryPrice;
            newTP = m_initialTP - tpExtend;
         }
         
         m_currentLevel = 3;
         return true;
      }
      else if(m_maxProfit >= 200.0 && m_currentLevel == 3) // 200% → TP x8
      {
         double tpExtend = (m_initialTP - m_entryPrice) * 7;
         
         if(m_isBuy)
         {
            newSL = m_entryPrice;
            newTP = m_initialTP + tpExtend;
         }
         else
         {
            newSL = m_entryPrice;
            newTP = m_initialTP - tpExtend;
         }
         
         m_currentLevel = 4;
         return true;
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| Mode personnalisé : niveaux définis par l'utilisateur          |
   //+------------------------------------------------------------------+
   bool UpdateCustom(double currentPrice, double &newSL, double &newTP)
   {
      if(m_levelCount == 0) return false;
      
      // Vérifier si on peut passer au niveau suivant
      if(m_currentLevel < m_levelCount)
      {
         TrailingLevel &level = m_customLevels[m_currentLevel];
         
         if(m_maxProfit >= level.profitPercent)
         {
            // Calculer les nouveaux SL et TP
            double slMove = (m_initialTP - m_initialSL) * (level.slMovePercent / 100.0);
            double tpExtend = (m_initialTP - m_initialSL) * (level.tpExtendPercent / 100.0);
            
            if(m_isBuy)
            {
               newSL = m_initialSL + slMove;
               newTP = m_initialTP + tpExtend;
            }
            else
            {
               newSL = m_initialSL - slMove;
               newTP = m_initialTP - tpExtend;
            }
            
            m_currentLevel++;
            return true;
         }
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| Parser la string des niveaux custom                            |
   //+------------------------------------------------------------------+
   void ParseCustomLevels(string levelsString)
   {
      string tokens[];
      int n = StringSplit(levelsString, ',', tokens);
      
      ArrayResize(m_customLevels, n);
      m_levelCount = 0;
      
      for(int i = 0; i < n; i++)
      {
         string token = tokens[i];
         StringTrimLeft(token);
         StringTrimRight(token);
         
         // Format: "profit:slMove:tpExtend"
         string parts[];
         int partsCount = StringSplit(token, ':', parts);
         
         if(partsCount == 3)
         {
            TrailingLevel level;
            level.profitPercent = StringToDouble(parts[0]);
            level.slMovePercent = StringToDouble(parts[1]);
            level.tpExtendPercent = StringToDouble(parts[2]);
            
            m_customLevels[m_levelCount] = level;
            m_levelCount++;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Validation des niveaux custom                                  |
   //+------------------------------------------------------------------+
   bool ValidateCustomLevels()
   {
      if(m_levelCount == 0) return false;
      
      // Vérifier que les niveaux sont dans l'ordre croissant
      for(int i = 0; i < m_levelCount; i++)
      {
         TrailingLevel &level = m_customLevels[i];
         
         // Vérifications de base
         if(level.profitPercent <= 0 || level.slMovePercent < 0 || level.tpExtendPercent < 0)
         {
            Print("❌ TrailingTP Custom: Niveau ", i, " invalide - profit: ", level.profitPercent, 
                  " slMove: ", level.slMovePercent, " tpExtend: ", level.tpExtendPercent);
            return false;
         }
         
         // Vérifier l'ordre croissant
         if(i > 0 && level.profitPercent <= m_customLevels[i-1].profitPercent)
         {
            Print("❌ TrailingTP Custom: Niveaux non ordonnés - niveau ", i, " doit être > niveau ", i-1);
            return false;
         }
      }
      
      return true;
   }
};