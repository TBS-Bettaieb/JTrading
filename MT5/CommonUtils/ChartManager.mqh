//+------------------------------------------------------------------+
//|                                            ChartManager.mqh      |
//|                      Gestionnaire d'affichage graphique universel |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.0"

//+------------------------------------------------------------------+
//| Classe de gestion de l'affichage du graphique                    |
//+------------------------------------------------------------------+
class ChartManager
{
private:
   long              m_chartId;              // ID du graphique
   string            m_labelPrefix;          // Préfixe pour les labels
   int               m_labelCounter;         // Compteur de labels
   
   // Générer un nom unique pour un label
   string GenerateLabelName(string suffix = "")
   {
      m_labelCounter++;
      if(suffix == "")
         return m_labelPrefix + "_Label_" + IntegerToString(m_labelCounter);
      else
         return m_labelPrefix + "_" + suffix;
   }
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   ChartManager(long chartId = 0, string prefix = "Chart")
   {
      m_chartId = (chartId == 0) ? ChartID() : chartId;
      m_labelPrefix = prefix;
      m_labelCounter = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor - Nettoyage automatique                              |
   //+------------------------------------------------------------------+
   ~ChartManager()
   {
      ClearLabels();
   }
   
   //+------------------------------------------------------------------+
   //| Configuration du style du graphique                             |
   //+------------------------------------------------------------------+
   bool SetupChart()
   {
      // Fond blanc
      ChartSetInteger(m_chartId, CHART_COLOR_BACKGROUND, clrWhite);
      
      // Couleur du texte
      ChartSetInteger(m_chartId, CHART_COLOR_FOREGROUND, clrBlack);
      
      // Grille désactivée
      ChartSetInteger(m_chartId, CHART_SHOW_GRID, false);
      
      // Couleurs des bougies
      ChartSetInteger(m_chartId, CHART_COLOR_CANDLE_BULL, clrLimeGreen);    // Bougie haussière (corps)
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_UP, clrLimeGreen);       // Bougie haussière (bordure)
      ChartSetInteger(m_chartId, CHART_COLOR_CANDLE_BEAR, clrRed);          // Bougie baissière (corps)
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_DOWN, clrRed);           // Bougie baissière (bordure)
      
      // Lignes de prix
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_LINE, clrBlack);
      
      // Volumes (si affichés)
      ChartSetInteger(m_chartId, CHART_COLOR_VOLUME, clrGray);
      
      // Bid/Ask lines
      ChartSetInteger(m_chartId, CHART_COLOR_BID, clrBlue);
      ChartSetInteger(m_chartId, CHART_COLOR_ASK, clrRed);
      
      // Échelle de prix
      ChartSetInteger(m_chartId, CHART_COLOR_STOP_LEVEL, clrRed);
      
      // Rafraîchir le graphique
      ChartRedraw(m_chartId);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Configuration personnalisée du style du graphique               |
   //+------------------------------------------------------------------+
   bool SetupCustomChart(
      color backgroundColor = clrWhite,
      color foregroundColor = clrBlack,
      bool showGrid = false,
      color bullCandleColor = clrLimeGreen,
      color bearCandleColor = clrRed,
      color bidColor = clrBlue,
      color askColor = clrRed
   )
   {
      // Fond
      ChartSetInteger(m_chartId, CHART_COLOR_BACKGROUND, backgroundColor);
      
      // Couleur du texte
      ChartSetInteger(m_chartId, CHART_COLOR_FOREGROUND, foregroundColor);
      
      // Grille
      ChartSetInteger(m_chartId, CHART_SHOW_GRID, showGrid);
      
      // Couleurs des bougies
      ChartSetInteger(m_chartId, CHART_COLOR_CANDLE_BULL, bullCandleColor);
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_UP, bullCandleColor);
      ChartSetInteger(m_chartId, CHART_COLOR_CANDLE_BEAR, bearCandleColor);
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_DOWN, bearCandleColor);
      
      // Lignes de prix
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_LINE, clrBlack);
      
      // Volumes
      ChartSetInteger(m_chartId, CHART_COLOR_VOLUME, clrGray);
      
      // Bid/Ask lines
      ChartSetInteger(m_chartId, CHART_COLOR_BID, bidColor);
      ChartSetInteger(m_chartId, CHART_COLOR_ASK, askColor);
      
      // Échelle de prix
      ChartSetInteger(m_chartId, CHART_COLOR_STOP_LEVEL, clrRed);
      
      // Rafraîchir le graphique
      ChartRedraw(m_chartId);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Afficher un label dans le coin supérieur droit                  |
   //+------------------------------------------------------------------+
   bool ShowTopRightLabel(string text, color clr = clrBlack, int fontSize = 18, int yDistance = 10)
   {
      string labelName = GenerateLabelName("TopRight");
      
      // Créer le label
      if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, 0, 0, 0))
      {
         // Si existe déjà, le supprimer et recréer
         ObjectDelete(m_chartId, labelName);
         if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, 0, 0, 0))
            return false;
      }
      
      // Positionner dans le coin supérieur droit
      ObjectSetInteger(m_chartId, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_YDISTANCE, yDistance);
      
      // Définir le texte
      ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, text);
      
      // Style
      ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(m_chartId, labelName, OBJPROP_FONT, "Arial");
      
      // Toujours visible
      ObjectSetInteger(m_chartId, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_HIDDEN, true);
      
      ChartRedraw(m_chartId);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Afficher le nom de la stratégie dans le coin supérieur gauche   |
   //+------------------------------------------------------------------+
   bool ShowTopLeftLabel(string strategyName, color clr = clrBlue, int fontSize = 20)
   {
      string labelName = GenerateLabelName("TopLeft");
      
      // Créer le label
      if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, 0, 0, 0))
      {
         // Si existe déjà, le supprimer et recréer
         ObjectDelete(m_chartId, labelName);
         if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, 0, 0, 0))
            return false;
      }
      
      // Positionner dans le coin supérieur gauche
      ObjectSetInteger(m_chartId, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_XDISTANCE, 30);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_YDISTANCE, 30);
      
      // Définir le texte avec formatage
      string displayText = "═══ " + strategyName + " ═══";
      ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, displayText);
      
      // Style
      ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(m_chartId, labelName, OBJPROP_FONT, "Arial Bold");
      
      // Toujours visible
      ObjectSetInteger(m_chartId, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_HIDDEN, true);
      
      ChartRedraw(m_chartId);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Afficher un label personnalisé                                  |
   //+------------------------------------------------------------------+
   bool ShowCustomLabel(
      string text,
      ENUM_BASE_CORNER corner,
      int xDistance,
      int yDistance,
      color clr = clrBlack,
      int fontSize = 10,
      string font = "Arial"
   )
   {
      string labelName = GenerateLabelName();
      
      // Créer le label
      if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, 0, 0, 0))
      {
         ObjectDelete(m_chartId, labelName);
         if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, 0, 0, 0))
            return false;
      }
      
      // Position
      ObjectSetInteger(m_chartId, labelName, OBJPROP_CORNER, corner);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_XDISTANCE, xDistance);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_YDISTANCE, yDistance);
      
      // Texte
      ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, text);
      
      // Style
      ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(m_chartId, labelName, OBJPROP_FONT, font);
      
      // Propriétés
      ObjectSetInteger(m_chartId, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_HIDDEN, true);
      
      ChartRedraw(m_chartId);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Afficher plusieurs lignes d'informations                        |
   //+------------------------------------------------------------------+
   bool ShowMultiLineInfo(
      string &lines[],
      ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
      int xDistance = 10,
      int yDistanceStart = 30,
      int lineSpacing = 18,
      color clr = clrBlack,
      int fontSize = 9
   )
   {
      int arraySize = ArraySize(lines);
      
      for(int i = 0; i < arraySize; i++)
      {
         int yDistance = yDistanceStart + (i * lineSpacing);
         
         if(!ShowCustomLabel(lines[i], corner, xDistance, yDistance, clr, fontSize))
            return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Afficher un statut avec couleurs dynamiques                     |
   //+------------------------------------------------------------------+
   bool ShowStatusLabel(
      string text,
      ENUM_BASE_CORNER corner = CORNER_RIGHT_UPPER,
      int xDistance = 10,
      int yDistance = 10,
      int fontSize = 18
   )
   {
      color statusColor = clrBlack;
      
      // Déterminer la couleur selon le contenu
      if(StringFind(text, "ACTIVE") >= 0 || StringFind(text, "PROFIT") >= 0)
         statusColor = clrGreen;
      else if(StringFind(text, "LOSS") >= 0 || StringFind(text, "ERROR") >= 0)
         statusColor = clrRed;
      else if(StringFind(text, "WAIT") >= 0 || StringFind(text, "OUTSIDE") >= 0)
         statusColor = clrOrange;
      else if(StringFind(text, "INFO") >= 0)
         statusColor = clrBlue;
      
      return ShowCustomLabel(text, corner, xDistance, yDistance, statusColor, fontSize);
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer tous les labels créés par ce manager                  |
   //+------------------------------------------------------------------+
   void ClearLabels()
   {
      // Supprimer tous les objets avec notre préfixe
      int total = ObjectsTotal(m_chartId);
      
      for(int i = total - 1; i >= 0; i--)
      {
         string objName = ObjectName(m_chartId, i);
         
         // Vérifier si l'objet commence par notre préfixe
         if(StringFind(objName, m_labelPrefix + "_") == 0)
         {
            ObjectDelete(m_chartId, objName);
         }
      }
      
      ChartRedraw(m_chartId);
      m_labelCounter = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer un label spécifique                                   |
   //+------------------------------------------------------------------+
   bool DeleteLabel(string suffix)
   {
      string labelName = m_labelPrefix + "_" + suffix;
      bool result = ObjectDelete(m_chartId, labelName);
      ChartRedraw(m_chartId);
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour le texte d'un label existant                      |
   //+------------------------------------------------------------------+
   bool UpdateLabelText(string suffix, string newText)
   {
      string labelName = m_labelPrefix + "_" + suffix;
      
      if(ObjectFind(m_chartId, labelName) < 0)
         return false;
      
      ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, newText);
      ChartRedraw(m_chartId);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour la couleur d'un label                             |
   //+------------------------------------------------------------------+
   bool UpdateLabelColor(string suffix, color clr)
   {
      string labelName = m_labelPrefix + "_" + suffix;
      
      if(ObjectFind(m_chartId, labelName) < 0)
         return false;
      
      ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, clr);
      ChartRedraw(m_chartId);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Mettre à jour un label de statut avec couleur dynamique         |
   //+------------------------------------------------------------------+
   bool UpdateStatusLabel(string suffix, string newText)
   {
      string labelName = m_labelPrefix + "_" + suffix;
      
      if(ObjectFind(m_chartId, labelName) < 0)
         return false;
      
      // Mettre à jour le texte
      ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, newText);
      
      // Mettre à jour la couleur selon le contenu
      color statusColor = clrBlack;
      if(StringFind(newText, "ACTIVE") >= 0 || StringFind(newText, "PROFIT") >= 0)
         statusColor = clrGreen;
      else if(StringFind(newText, "LOSS") >= 0 || StringFind(newText, "ERROR") >= 0)
         statusColor = clrRed;
      else if(StringFind(newText, "WAIT") >= 0 || StringFind(newText, "OUTSIDE") >= 0)
         statusColor = clrOrange;
      else if(StringFind(newText, "INFO") >= 0)
         statusColor = clrBlue;
      
      ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, statusColor);
      ChartRedraw(m_chartId);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Réinitialiser le graphique aux couleurs par défaut              |
   //+------------------------------------------------------------------+
   void ResetChartColors()
   {
      ChartSetInteger(m_chartId, CHART_COLOR_BACKGROUND, clrBlack);
      ChartSetInteger(m_chartId, CHART_COLOR_FOREGROUND, clrWhite);
      ChartSetInteger(m_chartId, CHART_SHOW_GRID, true);
      ChartSetInteger(m_chartId, CHART_COLOR_CANDLE_BULL, clrWhite);
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_UP, clrWhite);
      ChartSetInteger(m_chartId, CHART_COLOR_CANDLE_BEAR, clrBlack);
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_DOWN, clrBlack);
      
      ChartRedraw(m_chartId);
   }
   
   //+------------------------------------------------------------------+
   //| Obtenir l'ID du graphique géré                                  |
   //+------------------------------------------------------------------+
   long GetChartId() const { return m_chartId; }
   
   //+------------------------------------------------------------------+
   //| Définir le préfixe des labels                                   |
   //+------------------------------------------------------------------+
   void SetLabelPrefix(string prefix) { m_labelPrefix = prefix; }
   
   //+------------------------------------------------------------------+
   //| Obtenir le préfixe des labels                                   |
   //+------------------------------------------------------------------+
   string GetLabelPrefix() const { return m_labelPrefix; }
};
