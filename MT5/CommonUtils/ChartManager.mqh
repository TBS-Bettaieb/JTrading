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
      // Fond noir (RGB: 0,0,0)
      ChartSetInteger(m_chartId, CHART_COLOR_BACKGROUND, clrBlack);
      
      // Couleur du texte blanc (RGB: 255,255,255)
      ChartSetInteger(m_chartId, CHART_COLOR_FOREGROUND, clrWhite);
      
      // Grille désactivée
      ChartSetInteger(m_chartId, CHART_SHOW_GRID, false);
      
      // Couleurs des bougies
      ChartSetInteger(m_chartId, CHART_COLOR_CANDLE_BULL, C'38,166,154');    // Bougie haussière (corps) - Vert turquoise
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_UP, C'38,166,154');       // Bougie haussière (bordure) - Vert turquoise
      ChartSetInteger(m_chartId, CHART_COLOR_CANDLE_BEAR, C'239,83,80');      // Bougie baissière (corps) - Rouge
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_DOWN, C'239,83,80');       // Bougie baissière (bordure) - Rouge
      
      // Lignes de prix - Vert clair
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_LINE, C'86,186,132');
      
      // Volumes - Vert turquoise
      ChartSetInteger(m_chartId, CHART_COLOR_VOLUME, C'38,166,154');
      
      // Bid/Ask lines
      ChartSetInteger(m_chartId, CHART_COLOR_BID, C'38,166,154');             // Bid - Vert turquoise
      ChartSetInteger(m_chartId, CHART_COLOR_ASK, C'239,83,80');              // Ask - Rouge
      
      // Stop levels - Rouge
      ChartSetInteger(m_chartId, CHART_COLOR_STOP_LEVEL, C'239,83,80');
      
      // Rafraîchir le graphique
      ChartRedraw(m_chartId);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Configuration personnalisée du style du graphique               |
   //+------------------------------------------------------------------+
   bool SetupCustomChart(
      color backgroundColor = clrBlack,
      color foregroundColor = clrWhite,
      bool showGrid = false,
      color bullCandleColor = C'38,166,154',
      color bearCandleColor = C'239,83,80',
      color bidColor = C'38,166,154',
      color askColor = C'239,83,80'
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
      ChartSetInteger(m_chartId, CHART_COLOR_CHART_LINE, C'86,186,132');
      
      // Volumes
      ChartSetInteger(m_chartId, CHART_COLOR_VOLUME, bullCandleColor);
      
      // Bid/Ask lines
      ChartSetInteger(m_chartId, CHART_COLOR_BID, bidColor);
      ChartSetInteger(m_chartId, CHART_COLOR_ASK, askColor);
      
      // Échelle de prix
      ChartSetInteger(m_chartId, CHART_COLOR_STOP_LEVEL, bearCandleColor);
      
      // Rafraîchir le graphique
      ChartRedraw(m_chartId);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Afficher un label dans le coin supérieur droit                  |
   //+------------------------------------------------------------------+
   bool ShowTopRightLabel(string text, color clr = clrWhite, int fontSize = 18, int yDistance = 10)
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
   //| Afficher le nom de la stratégie (fond + texte)                  |
   //+------------------------------------------------------------------+
   bool ShowStrategyName(
      string strategyName,
      color textColor = clrWhite,
      int fontSize = 13,
      color backgroundColor = C'60,75,90'
   )
   {
      // Fond plus clair et plus présent pour ressortir sur fond noir
      string bgName = m_labelPrefix + "_StrategyBg";
      ObjectDelete(m_chartId, bgName);
      if(ObjectCreate(m_chartId, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         // Position
         ObjectSetInteger(m_chartId, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(m_chartId, bgName, OBJPROP_XDISTANCE, 15);
         ObjectSetInteger(m_chartId, bgName, OBJPROP_YDISTANCE, 15);

         // Dimensions augmentées pour plus de présence
         ObjectSetInteger(m_chartId, bgName, OBJPROP_XSIZE, 340);
         ObjectSetInteger(m_chartId, bgName, OBJPROP_YSIZE, 40);

         // Couleur de fond bien plus claire (ou passer en paramètre)
         ObjectSetInteger(m_chartId, bgName, OBJPROP_BGCOLOR, backgroundColor);

         // Bordure vive et épaisse pour attirer l'œil
         ObjectSetInteger(m_chartId, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(m_chartId, bgName, OBJPROP_COLOR, C'0,180,255');
         ObjectSetInteger(m_chartId, bgName, OBJPROP_WIDTH, 2);

         // Derrière le texte
         ObjectSetInteger(m_chartId, bgName, OBJPROP_BACK, true);
         ObjectSetInteger(m_chartId, bgName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, bgName, OBJPROP_HIDDEN, true);
      }
      
      // Texte très visible au-dessus du fond
      string labelName = m_labelPrefix + "_StrategyName";
      ObjectDelete(m_chartId, labelName);
      if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, 0, 0, 0))
         return false;
      
      // Position (légers paddings pour centrage visuel)
      ObjectSetInteger(m_chartId, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_XDISTANCE, 40);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_YDISTANCE, 31);

      // Contenu
      ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, strategyName);

      // Style: police plus grasse et taille supérieure pour lisibilité
      ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(m_chartId, labelName, OBJPROP_FONT, "Arial Black");

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
      color clr = clrWhite,
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
      color clr = clrWhite,
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
      color statusColor = clrWhite;
      
      // Déterminer la couleur selon le contenu - couleurs vives pour fond noir
      if(StringFind(text, "ACTIVE") >= 0 || StringFind(text, "PROFIT") >= 0)
         statusColor = clrLime;
      else if(StringFind(text, "LOSS") >= 0 || StringFind(text, "ERROR") >= 0)
         statusColor = clrRed;
      else if(StringFind(text, "WAIT") >= 0 || StringFind(text, "OUTSIDE") >= 0)
         statusColor = clrYellow;
      else if(StringFind(text, "INFO") >= 0)
         statusColor = clrDeepSkyBlue;
      
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
   //| Supprimer le nom de la stratégie (fond + texte)                 |
   //+------------------------------------------------------------------+
   bool DeleteStrategyName()
   {
      // Supprimer le fond
      ObjectDelete(m_chartId, m_labelPrefix + "_StrategyBg");
      
      // Supprimer le texte
      string labelName = m_labelPrefix + "_StrategyName";
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
      
      // Mettre à jour la couleur selon le contenu - couleurs vives pour fond noir
      color statusColor = clrWhite;
      if(StringFind(newText, "ACTIVE") >= 0 || StringFind(newText, "PROFIT") >= 0)
         statusColor = clrLime;
      else if(StringFind(newText, "LOSS") >= 0 || StringFind(newText, "ERROR") >= 0)
         statusColor = clrRed;
      else if(StringFind(newText, "WAIT") >= 0 || StringFind(newText, "OUTSIDE") >= 0)
         statusColor = clrYellow;
      else if(StringFind(newText, "INFO") >= 0)
         statusColor = clrDeepSkyBlue;
      
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
   
   //+------------------------------------------------------------------+
   //| Afficher une alerte au centre du graphique                      |
   //+------------------------------------------------------------------+
   bool ShowAlert(
      string alertText,
      color textColor = clrYellow,
      int fontSize = 42,
      string font = "Arial Black"
   )
   {
      string labelName = "AlertCenter";
      
      // Supprimer l'alerte existante si elle existe
      ObjectDelete(m_chartId, labelName);
      
      // Créer le label
      if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, 0, 0, 0))
         return false;
      
      // Positionner au centre du graphique
      ObjectSetInteger(m_chartId, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      
      // Calculer la position centrale approximative
      int chartWidth = (int)ChartGetInteger(m_chartId, CHART_WIDTH_IN_PIXELS);
      int chartHeight = (int)ChartGetInteger(m_chartId, CHART_HEIGHT_IN_PIXELS);
      
      int xDistance = (chartWidth > 0) ? chartWidth / 2 - 150 : 400;  // Centrage approximatif
      int yDistance = (chartHeight > 0) ? chartHeight / 2 - 25 : 300; // Centrage approximatif
      
      ObjectSetInteger(m_chartId, labelName, OBJPROP_XDISTANCE, xDistance);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_YDISTANCE, yDistance);
      
      // Définir le texte
      ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, alertText);
      
      // Style - très visible pour une alerte
      ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(m_chartId, labelName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(m_chartId, labelName, OBJPROP_FONT, font);
      
      // Propriétés pour une alerte
      ObjectSetInteger(m_chartId, labelName, OBJPROP_BACK, false);    // Au premier plan
      ObjectSetInteger(m_chartId, labelName, OBJPROP_SELECTABLE, false); // Non sélectionnable
      ObjectSetInteger(m_chartId, labelName, OBJPROP_HIDDEN, true);   // Caché dans la liste
      
      ChartRedraw(m_chartId);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Supprimer l'alerte du centre du graphique                       |
   //+------------------------------------------------------------------+
   bool HideAlert()
   {
      string labelName = "AlertCenter";
      bool result = ObjectDelete(m_chartId, labelName);
      ChartRedraw(m_chartId);
      return result;
   }
};
