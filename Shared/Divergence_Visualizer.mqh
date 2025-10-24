//+------------------------------------------------------------------+
//|                                     Divergence_Visualizer.mqh    |
//|                         RSI Divergence Trading System              |
//|                      Classe pour affichage graphique des divergences |
//+------------------------------------------------------------------+
//| Version: 1.0                                                     |
//| Changelog:                                                       |
//| ✅ [FEATURE] Affichage graphique des divergences                  |
//| ✅ [FEATURE] Support trendlines, arrows et labels                 |
//| ✅ [FEATURE] Gestion automatique des objets graphiques            |
//| ✅ [PERFORMANCE] Optimisation mémoire et nettoyage automatique    |
//| ✅ [CUSTOMIZATION] Couleurs et styles personnalisables            |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Trading System"
#property link      ""
#property version   "1.00"

#include "Divergence_Detector.mqh"

//+------------------------------------------------------------------+
//| Structure pour configuration visuelle                            |
//+------------------------------------------------------------------+
struct SVisualConfig
{
   // Couleurs
   color             regularBullishColor;    // Couleur divergence bullish régulière
   color             regularBearishColor;    // Couleur divergence bearish régulière
   color             hiddenBullishColor;     // Couleur divergence bullish cachée
   color             hiddenBearishColor;     // Couleur divergence bearish cachée
   
   // Styles
   ENUM_LINE_STYLE   regularLineStyle;       // Style ligne divergences régulières
   ENUM_LINE_STYLE   hiddenLineStyle;        // Style ligne divergences cachées
   int               lineWidth;              // Épaisseur des lignes
   
   // Arrows
   int               regularArrowCode;       // Code flèche divergences régulières
   int               hiddenArrowCode;        // Code flèche divergences cachées
   
   // Labels
   bool              showLabels;             // Afficher les labels
   int               labelFontSize;          // Taille police des labels
   color             labelColor;             // Couleur des labels
   
   // Constructeur par défaut
   SVisualConfig()
   {
      regularBullishColor = clrLimeGreen;
      regularBearishColor = clrRed;
      hiddenBullishColor = clrDodgerBlue;
      hiddenBearishColor = clrOrange;
      
      regularLineStyle = STYLE_SOLID;
      hiddenLineStyle = STYLE_DASH;
      lineWidth = 2;
      
      regularArrowCode = 159;
      hiddenArrowCode = 159;
      
      showLabels = true;
      labelFontSize = 8;
      labelColor = clrWhite;
   }
};

//+------------------------------------------------------------------+
//| Classe pour affichage graphique des divergences                  |
//+------------------------------------------------------------------+
class CDivergenceVisualizer
{
private:
   // Configuration
   string            m_prefix;               // Préfixe des objets
   int               m_windowIndex;          // Index de la fenêtre
   SVisualConfig     m_config;               // Configuration visuelle
   
   // Gestion des objets
   int               m_objectCounter;        // Compteur d'objets
   string            m_objectNames[];        // Noms des objets créés
   int               m_maxObjects;           // Nombre maximum d'objets
   
   // Variables de contrôle
   bool              m_initialized;          // État d'initialisation
   bool              m_autoCleanup;          // Nettoyage automatique
   
   // Constantes
   int DEFAULT_MAX_OBJECTS;  // Nombre par défaut d'objets max

public:
   // Constructeur
   CDivergenceVisualizer(string objPrefix = "RSI_DIV_", int subwindow = 0, int maxObjects = 100);
   
   // Destructeur
   ~CDivergenceVisualizer();
   
   // Méthodes principales
   bool DrawDivergence(const SDivergenceResult &div, const datetime &time[]);
   bool DrawDivergenceTrendline(const SDivergenceResult &div, const datetime &time[]);
   bool DrawDivergenceArrow(const SDivergenceResult &div, const datetime &time[]);
   bool DrawDivergenceLabel(const SDivergenceResult &div, const datetime &time[]);
   
   // Méthodes de gestion des objets
   void CleanOldObjects(int maxAge = 1000);
   void DeleteAllObjects();
   void DeleteObjectsByType(ENUM_DIVERGENCE_TYPE type);
   
   // Méthodes de configuration
   void SetPrefix(string prefix);
   void SetWindowIndex(int windowIndex);
   void SetMaxObjects(int maxObjects);
   void SetVisualConfig(const SVisualConfig &config);
   void SetAutoCleanup(bool enable);
   
   // Méthodes d'accès
   string GetPrefix() const { return m_prefix; }
   int GetWindowIndex() const { return m_windowIndex; }
   int GetMaxObjects() const { return m_maxObjects; }
   bool IsAutoCleanupEnabled() const { return m_autoCleanup; }
   
   // Méthodes utilitaires
   void Reset();
   bool IsInitialized() const { return m_initialized; }
   int GetObjectCount() const;
   
   // Méthodes de validation
   bool ValidateParameters() const;
   bool ValidateDivergence(const SDivergenceResult &div) const;

private:
   // Méthodes internes
   bool InitializeBuffers();
   string GenerateObjectName(ENUM_DIVERGENCE_TYPE type, const string &suffix);
   color GetDivergenceColor(ENUM_DIVERGENCE_TYPE type) const;
   ENUM_LINE_STYLE GetDivergenceLineStyle(ENUM_DIVERGENCE_TYPE type) const;
   int GetDivergenceArrowCode(ENUM_DIVERGENCE_TYPE type) const;
   string GetDivergenceLabelText(ENUM_DIVERGENCE_TYPE type) const;
   void AddObjectName(const string &objectName);
   void RemoveObjectName(const string &objectName);
   bool IsObjectNameExists(const string &objectName) const;
};

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
CDivergenceVisualizer::CDivergenceVisualizer(string objPrefix = "RSI_DIV_", int subwindow = 0, int maxObjects = 100)
{
   m_prefix = objPrefix;
   m_windowIndex = subwindow;
   m_maxObjects = maxObjects;
   m_objectCounter = 0;
   m_initialized = false;
   m_autoCleanup = true;
   DEFAULT_MAX_OBJECTS = 100;  // Initialiser la constante
   
   // Initialiser les buffers
   ArrayResize(m_objectNames, m_maxObjects);
   for(int i = 0; i < m_maxObjects; i++)
   {
      m_objectNames[i] = "";
   }
   
   m_initialized = InitializeBuffers();
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
CDivergenceVisualizer::~CDivergenceVisualizer()
{
   if(m_autoCleanup)
      DeleteAllObjects();
   
   ArrayFree(m_objectNames);
}

//+------------------------------------------------------------------+
//| Dessiner une divergence complète                                 |
//+------------------------------------------------------------------+
bool CDivergenceVisualizer::DrawDivergence(const SDivergenceResult &div, const datetime &time[])
{
   if(!ValidateParameters() || !ValidateDivergence(div))
      return false;
   
   bool success = true;
   
   // Dessiner la trendline
   if(!DrawDivergenceTrendline(div, time))
      success = false;
   
   // Dessiner la flèche
   if(!DrawDivergenceArrow(div, time))
      success = false;
   
   // Dessiner le label (optionnel)
   if(m_config.showLabels && !DrawDivergenceLabel(div, time))
      success = false;
   
   // Nettoyage automatique si activé
   if(m_autoCleanup && GetObjectCount() > m_maxObjects)
      CleanOldObjects();
   
   return success;
}

//+------------------------------------------------------------------+
//| Dessiner une trendline de divergence                             |
//+------------------------------------------------------------------+
bool CDivergenceVisualizer::DrawDivergenceTrendline(const SDivergenceResult &div, const datetime &time[])
{
   if(!ValidateParameters() || !ValidateDivergence(div))
      return false;
   
   // Générer le nom de l'objet
   string objName = GenerateObjectName(div.type, "TREND");
   
   // Supprimer l'objet existant s'il y en a un
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   // Créer la trendline
   if(ObjectCreate(0, objName, OBJ_TREND, m_windowIndex, 
                   div.previousTime, div.previousRSI,  // Point 1 : pivot précédent
                   div.currentTime, div.currentRSI))    // Point 2 : pivot actuel
   {
      // Configuration de la trendline
      ObjectSetInteger(0, objName, OBJPROP_COLOR, GetDivergenceColor(div.type));
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, m_config.lineWidth);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, GetDivergenceLineStyle(div.type));
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);  // Pas de prolongement
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);        // Dessinée en arrière-plan
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, GetDivergenceLabelText(div.type));
      
      AddObjectName(objName);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Dessiner une flèche de divergence                                |
//+------------------------------------------------------------------+
bool CDivergenceVisualizer::DrawDivergenceArrow(const SDivergenceResult &div, const datetime &time[])
{
   if(!ValidateParameters() || !ValidateDivergence(div))
      return false;
   
   // Générer le nom de l'objet
   string objName = GenerateObjectName(div.type, "ARROW");
   
   // Supprimer l'objet existant s'il y en a un
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   // Créer la flèche
   if(ObjectCreate(0, objName, OBJ_ARROW, m_windowIndex, div.currentTime, div.currentRSI))
   {
      // Configuration de la flèche
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, GetDivergenceArrowCode(div.type));
      ObjectSetInteger(0, objName, OBJPROP_COLOR, GetDivergenceColor(div.type));
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, m_config.lineWidth);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, GetDivergenceLabelText(div.type));
      
      AddObjectName(objName);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Dessiner un label de divergence                                  |
//+------------------------------------------------------------------+
bool CDivergenceVisualizer::DrawDivergenceLabel(const SDivergenceResult &div, const datetime &time[])
{
   if(!ValidateParameters() || !ValidateDivergence(div))
      return false;
   
   // Générer le nom de l'objet
   string objName = GenerateObjectName(div.type, "LABEL");
   
   // Supprimer l'objet existant s'il y en a un
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   // Créer le label
   if(ObjectCreate(0, objName, OBJ_TEXT, m_windowIndex, div.currentTime, div.currentRSI))
   {
      // Configuration du label
      ObjectSetString(0, objName, OBJPROP_TEXT, GetDivergenceLabelText(div.type));
      ObjectSetInteger(0, objName, OBJPROP_COLOR, m_config.labelColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, m_config.labelFontSize);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
      
      AddObjectName(objName);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Nettoyer les anciens objets                                      |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::CleanOldObjects(int maxAge = 1000)
{
   if(!m_initialized)
      return;
   
   int totalObjects = ObjectsTotal(0, -1, -1);
   datetime currentTime = TimeCurrent();
   
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      
      if(StringFind(objName, m_prefix) >= 0)
      {
         datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
         
         if(currentTime - objTime > maxAge)
         {
            ObjectDelete(0, objName);
            RemoveObjectName(objName);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Supprimer tous les objets                                        |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::DeleteAllObjects()
{
   if(!m_initialized)
      return;
   
   int totalObjects = ObjectsTotal(0, -1, -1);
   
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      
      if(StringFind(objName, m_prefix) >= 0)
      {
         ObjectDelete(0, objName);
      }
   }
   
   for(int i = 0; i < ArraySize(m_objectNames); i++)
   {
      m_objectNames[i] = "";
   }
   m_objectCounter = 0;
}

//+------------------------------------------------------------------+
//| Supprimer les objets par type                                    |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::DeleteObjectsByType(ENUM_DIVERGENCE_TYPE type)
{
   if(!m_initialized)
      return;
   
   int totalObjects = ObjectsTotal(0, -1, -1);
   string typeSuffix = "";
   
   switch(type)
   {
      case DIVERGENCE_REGULAR_BULL:
         typeSuffix = "BULL";
         break;
      case DIVERGENCE_REGULAR_BEAR:
         typeSuffix = "BEAR";
         break;
      case DIVERGENCE_HIDDEN_BULL:
         typeSuffix = "HBULL";
         break;
      case DIVERGENCE_HIDDEN_BEAR:
         typeSuffix = "HBEAR";
         break;
      default:
         return;
   }
   
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      
      if(StringFind(objName, m_prefix) >= 0 && StringFind(objName, typeSuffix) >= 0)
      {
         ObjectDelete(0, objName);
         RemoveObjectName(objName);
      }
   }
}

//+------------------------------------------------------------------+
//| Définir le préfixe des objets                                    |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::SetPrefix(string prefix)
{
   if(prefix == "")
      return;
   
   m_prefix = prefix;
   Reset();
}

//+------------------------------------------------------------------+
//| Définir l'index de la fenêtre                                    |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::SetWindowIndex(int windowIndex)
{
   if(windowIndex < 0)
      return;
   
   m_windowIndex = windowIndex;
}

//+------------------------------------------------------------------+
//| Définir le nombre maximum d'objets                               |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::SetMaxObjects(int maxObjects)
{
   if(maxObjects < 1)
      return;
   
   m_maxObjects = maxObjects;
   
   // Redimensionner l'array si nécessaire
   ArrayResize(m_objectNames, m_maxObjects);
}

//+------------------------------------------------------------------+
//| Définir la configuration visuelle                                |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::SetVisualConfig(const SVisualConfig &config)
{
   m_config = config;
}

//+------------------------------------------------------------------+
//| Activer/désactiver le nettoyage automatique                      |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::SetAutoCleanup(bool enable)
{
   m_autoCleanup = enable;
}

//+------------------------------------------------------------------+
//| Réinitialiser le visualiseur                                     |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::Reset()
{
   m_objectCounter = 0;
   for(int i = 0; i < ArraySize(m_objectNames); i++)
   {
      m_objectNames[i] = "";
   }
}

//+------------------------------------------------------------------+
//| Obtenir le nombre d'objets créés                                 |
//+------------------------------------------------------------------+
int CDivergenceVisualizer::GetObjectCount() const
{
   int count = 0;
   for(int i = 0; i < ArraySize(m_objectNames); i++)
   {
      if(m_objectNames[i] != "")
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Valider les paramètres de configuration                          |
//+------------------------------------------------------------------+
bool CDivergenceVisualizer::ValidateParameters() const
{
   if(m_prefix == "")
   {
      Print("❌ CDivergenceVisualizer::ValidateParameters - Préfixe vide");
      return false;
   }
   
   if(m_windowIndex < 0)
   {
      Print("❌ CDivergenceVisualizer::ValidateParameters - Index de fenêtre invalide: ", m_windowIndex);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Valider une divergence                                           |
//+------------------------------------------------------------------+
bool CDivergenceVisualizer::ValidateDivergence(const SDivergenceResult &div) const
{
   if(!div.found || !div.isValid)
      return false;
   
   if(div.currentBar < 0 || div.previousBar < 0)
      return false;
   
   if(div.currentTime == 0 || div.previousTime == 0)
      return false;
   
   if(div.type == DIVERGENCE_NONE)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialiser les buffers internes                                 |
//+------------------------------------------------------------------+
bool CDivergenceVisualizer::InitializeBuffers()
{
   if(m_prefix == "" || m_maxObjects < 1)
      return false;
   
   ArrayResize(m_objectNames, m_maxObjects);
   for(int i = 0; i < m_maxObjects; i++)
   {
      m_objectNames[i] = "";
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Générer un nom d'objet unique                                    |
//+------------------------------------------------------------------+
string CDivergenceVisualizer::GenerateObjectName(ENUM_DIVERGENCE_TYPE type, const string &suffix)
{
   string typeStr = "";
   
   switch(type)
   {
      case DIVERGENCE_REGULAR_BULL:
         typeStr = "BULL";
         break;
      case DIVERGENCE_REGULAR_BEAR:
         typeStr = "BEAR";
         break;
      case DIVERGENCE_HIDDEN_BULL:
         typeStr = "HBULL";
         break;
      case DIVERGENCE_HIDDEN_BEAR:
         typeStr = "HBEAR";
         break;
      default:
         typeStr = "UNKNOWN";
         break;
   }
   
   m_objectCounter++;
   return m_prefix + typeStr + suffix + "_" + IntegerToString(m_objectCounter);
}

//+------------------------------------------------------------------+
//| Obtenir la couleur selon le type de divergence                   |
//+------------------------------------------------------------------+
color CDivergenceVisualizer::GetDivergenceColor(ENUM_DIVERGENCE_TYPE type) const
{
   switch(type)
   {
      case DIVERGENCE_REGULAR_BULL:
         return m_config.regularBullishColor;
      case DIVERGENCE_REGULAR_BEAR:
         return m_config.regularBearishColor;
      case DIVERGENCE_HIDDEN_BULL:
         return m_config.hiddenBullishColor;
      case DIVERGENCE_HIDDEN_BEAR:
         return m_config.hiddenBearishColor;
      default:
         return clrWhite;
   }
}

//+------------------------------------------------------------------+
//| Obtenir le style de ligne selon le type de divergence            |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE CDivergenceVisualizer::GetDivergenceLineStyle(ENUM_DIVERGENCE_TYPE type) const
{
   switch(type)
   {
      case DIVERGENCE_REGULAR_BULL:
      case DIVERGENCE_REGULAR_BEAR:
         return m_config.regularLineStyle;
      case DIVERGENCE_HIDDEN_BULL:
      case DIVERGENCE_HIDDEN_BEAR:
         return m_config.hiddenLineStyle;
      default:
         return STYLE_SOLID;
   }
}

//+------------------------------------------------------------------+
//| Obtenir le code flèche selon le type de divergence               |
//+------------------------------------------------------------------+
int CDivergenceVisualizer::GetDivergenceArrowCode(ENUM_DIVERGENCE_TYPE type) const
{
   switch(type)
   {
      case DIVERGENCE_REGULAR_BULL:
      case DIVERGENCE_REGULAR_BEAR:
         return m_config.regularArrowCode;
      case DIVERGENCE_HIDDEN_BULL:
      case DIVERGENCE_HIDDEN_BEAR:
         return m_config.hiddenArrowCode;
      default:
         return 159;
   }
}

//+------------------------------------------------------------------+
//| Obtenir le texte du label selon le type de divergence            |
//+------------------------------------------------------------------+
string CDivergenceVisualizer::GetDivergenceLabelText(ENUM_DIVERGENCE_TYPE type) const
{
   switch(type)
   {
      case DIVERGENCE_REGULAR_BULL:
         return "Regular Bullish Divergence";
      case DIVERGENCE_REGULAR_BEAR:
         return "Regular Bearish Divergence";
      case DIVERGENCE_HIDDEN_BULL:
         return "Hidden Bullish Divergence";
      case DIVERGENCE_HIDDEN_BEAR:
         return "Hidden Bearish Divergence";
      default:
         return "Unknown Divergence";
   }
}

//+------------------------------------------------------------------+
//| Ajouter un nom d'objet à la liste                                |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::AddObjectName(const string &objectName)
{
   for(int i = 0; i < ArraySize(m_objectNames); i++)
   {
      if(m_objectNames[i] == "")
      {
         m_objectNames[i] = objectName;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Supprimer un nom d'objet de la liste                             |
//+------------------------------------------------------------------+
void CDivergenceVisualizer::RemoveObjectName(const string &objectName)
{
   for(int i = 0; i < ArraySize(m_objectNames); i++)
   {
      if(m_objectNames[i] == objectName)
      {
         m_objectNames[i] = "";
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier si un nom d'objet existe                                |
//+------------------------------------------------------------------+
bool CDivergenceVisualizer::IsObjectNameExists(const string &objectName) const
{
   for(int i = 0; i < ArraySize(m_objectNames); i++)
   {
      if(m_objectNames[i] == objectName)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
