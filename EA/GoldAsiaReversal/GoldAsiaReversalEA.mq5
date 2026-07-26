//+------------------------------------------------------------------+
//|                                          GoldAsiaReversalEA.mq5    |
//|                                                                    |
//| STRATEGIE                                                          |
//|   1. A la cloture Daily : detecter une hausse >= X % faisant suite  |
//|      a une (ou plusieurs) bougie(s) baissiere(s).                   |
//|   2. Acheter a l'OUVERTURE de la session asiatique suivante.        |
//|   3. Cloturer a la FIN de cette session (le TP, s'il est actif,     |
//|      permet une sortie anticipee).                                  |
//|                                                                    |
//| Concu pour l'or (XAUUSD) mais utilisable sur tout symbole.          |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property link      ""
#property version   "1.00"
#property description "Gold Asia Reversal - achat a l'ouverture asiatique apres un rebond Daily"

#include "../Shared/Logger.mqh"
#include "../Shared/ChartManager.mqh"
#include "../Shared/TradingUtils.mqh"
#include "GoldAsiaTrader.mqh"

//+------------------------------------------------------------------+
//| CONSTANTES FIGEES - volontairement retirees des inputs             |
//|                                                                    |
//| Ce ne sont pas des leviers de strategie : soit une seule valeur a  |
//| du sens, soit les optimiser ne ferait que gonfler l'espace de      |
//| recherche. Modifier ici si besoin, mais alors pour tous les tests. |
//+------------------------------------------------------------------+
const ENUM_RISE_MODE  CFG_RISE_MODE               = RISE_CLOSE_TO_CLOSE; // Variation journaliere standard (close/close)
const bool            CFG_IGNORE_SUNDAY_D1        = true;                // Les D1 "dimanche" de l'or faussent le %
const ENUM_TIMEFRAMES CFG_ATR_TIMEFRAME           = PERIOD_D1;           // Un ATR intraday n'a pas de sens sur un signal Daily
const int             CFG_ATR_PERIOD              = 14;                  // Standard
const int             CFG_MAX_ENTRY_DELAY_MINUTES = 90;                  // Garde-fou de rattachement uniquement
const string          CFG_TRADE_COMMENT           = "GoldAsiaReversal";
const bool            CFG_SETUP_CHART_STYLE       = false;               // Theme graphique du repo

//+------------------------------------------------------------------+
//| STRATEGIE - les seuls parametres a optimiser                      |
//+------------------------------------------------------------------+
input group "=== Signal Daily ==="
input double InpMinRisePercent      = 0.5;   // Hausse minimale de la bougie D1 (%)
input int    InpBearishBarsRequired = 0;     // Bougies baissieres requises avant la hausse (0 = condition desactivee)

input group "=== Stop Loss (toujours actif) ==="
input ENUM_SL_METHOD InpSlMethod        = SL_METHOD_FIXED_POINTS; // Methode de calcul du SL
input double         InpSlAtrMultiplier = 1.0;                    // Multiplicateur ATR pour le SL
input int            InpSlFixedPoints   = 3000;                   // SL en points fixes (et valeur de repli)
input int            InpSlBufferPoints  = 100;                    // Marge sous le low / open de la veille (points)

input group "=== Take Profit ==="
input ENUM_TP_MODE InpTpMode          = TP_MODE_RR_RATIO;  // Mode de TP (la cloture fin de session reste active)
input double       InpRiskRewardRatio = 3.0;               // Ratio R:R applique a la distance de SL
input double       InpTpAtrMultiplier = 1.5;               // Multiplicateur ATR pour le TP
input int          InpTpFixedPoints   = 3000;              // TP en points fixes

//+------------------------------------------------------------------+
//| CONCEPTION - a caler une fois pour votre broker, PAS a optimiser  |
//+------------------------------------------------------------------+
input group "=== Session asiatique ==="
input int    InpAsiaStartHHMM = 0;      // Ouverture au format HHMM (0 = 00:00, 2200 = 22:00)
input int    InpAsiaEndHHMM   = 800;    // Cloture au format HHMM (800 = 08:00)
input bool   InpUseServerTime = true;   // false = heures en GMT, true = heure serveur
input string InpTradeDays     = "0-6";  // Jours d'ouverture autorises (0=Dim ... 6=Sam)

input group "=== Garde-fous SL ==="
input int InpMinSlPoints = 0;   // Distance SL minimale (0 = niveau broker)
input int InpMaxSlPoints = 0;   // Distance SL maximale (0 = sans limite)

//+------------------------------------------------------------------+
//| ENVIRONNEMENT - dependant du broker et du compte, PAS a optimiser |
//+------------------------------------------------------------------+
input group "=== Money management ==="
input double InpLotSize         = 0.01;  // Volume fixe (ignore si InpRiskPercent > 0)
input double InpRiskPercent     = 1.0;   // Risque par trade en % (0 = utiliser le volume fixe)
input int    InpMaxSpreadPoints = 50;    // Spread maximal a l'entree (0 = pas de controle)
input int    InpSlippage        = 20;    // Deviation autorisee (points)

input group "=== Divers ==="
input int            InpMagicNumber = 778001;    // Magic number de base
input ENUM_LOG_LEVEL InpLogLevel    = LOG_INFO;  // Niveau de log
input bool           InpShowVisuals = true;      // Afficher panneau et marqueurs

input group "=== Zones de session (rectangles) ==="
input bool  InpDrawSessionZones = true;          // Dessiner un rectangle par session asiatique
input int   InpZoneHistoryCount = 30;            // Sessions passees dessinees au demarrage (0 = aucune)
input color InpZoneColor        = C'220,235,255';// Session non tradee
input color InpZoneWinColor     = C'205,240,205';// Session tradee gagnante
input color InpZoneLossColor    = C'250,215,215';// Session tradee perdante
input bool  InpClearDrawingsOnExit = false;      // Effacer zones et marqueurs a l'arret (false = les garder)

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
GoldAsiaTrader *g_trader = NULL;
ChartManager   *g_chart  = NULL;

//+------------------------------------------------------------------+
//| Validation des parametres                                        |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   if(InpMinRisePercent <= 0.0)
   {
      Logger::Error(StringFormat("InpMinRisePercent doit etre > 0 (valeur : %.2f)", InpMinRisePercent));
      return false;
   }

   if(InpLotSize <= 0.0 && InpRiskPercent <= 0.0)
   {
      Logger::Error("Il faut soit un volume fixe > 0, soit un risque en % > 0");
      return false;
   }

   if(InpRiskPercent < 0.0 || InpRiskPercent > 20.0)
   {
      Logger::Error(StringFormat("InpRiskPercent hors bornes : %.2f (attendu 0 a 20)", InpRiskPercent));
      return false;
   }

   if(InpBearishBarsRequired < 0 || InpBearishBarsRequired > 10)
   {
      Logger::Error(StringFormat("InpBearishBarsRequired hors bornes : %d (attendu 0 a 10)", InpBearishBarsRequired));
      return false;
   }

   if(InpSlippage < 0)
   {
      Logger::Error("InpSlippage ne peut pas etre negatif");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Recapitulatif de configuration                                   |
//+------------------------------------------------------------------+
void DisplayConfigurationInfo(int magic)
{
   Logger::Info("═══════════════════════════════════════════════");
   Logger::Info("🚀 GOLD ASIA REVERSAL");
   Logger::Info("═══════════════════════════════════════════════");
   Logger::Info("Symbole      : " + _Symbol);
   Logger::Info("Magic        : " + IntegerToString(magic));
   Logger::Info(StringFormat("Volume       : %s",
                             InpRiskPercent > 0.0
                               ? StringFormat("risque %.2f %% du capital", InpRiskPercent)
                               : StringFormat("%.2f lot fixe", InpLotSize)));
   Logger::Info(StringFormat("Spread max   : %d points", InpMaxSpreadPoints));
   Logger::Info(StringFormat("Rattachement : %d min max si l'ouverture n'a pas ete observee", CFG_MAX_ENTRY_DELAY_MINUTES));

   if(InpBearishBarsRequired == 0)
      Logger::Warning("InpBearishBarsRequired = 0 : la condition \"suite a une baisse\" est DESACTIVEE, "
                      "toute bougie D1 haussiere au-dessus du seuil declenche un signal");

   Logger::Info("═══════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Logger::Initialize(InpLogLevel, "[GoldAsiaReversal] ");

   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   if(!ValidateSymbol(_Symbol))
   {
      Logger::Error("Symbole " + _Symbol + " indisponible ou non tradable");
      return INIT_FAILED;
   }

   // Le signal a besoin d'un historique Daily suffisant
   if(!CheckHistoricalData(_Symbol, PERIOD_D1, 30))
   {
      Logger::Error("Historique Daily insuffisant pour " + _Symbol);
      return INIT_FAILED;
   }

   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Logger::Warning("Symbole " + _Symbol + " : l'EA est calibre pour l'or, verifiez les distances en points");

   //--- Magic unique par symbole (convention TradingUtils.mqh)
   int magic = GenerateSymbolMagicNumber(InpMagicNumber, _Symbol, PERIOD_D1);

   //--- Affichage
   // Prefixe distinct de GAR_ (utilise par les traces du trader) : ClearLabels()
   // supprime tout ce qui commence par son prefixe, il ne doit donc pas
   // emporter les zones de session et les marqueurs de trade.
   g_chart = new ChartManager(ChartID(), "GARui");
   if(g_chart == NULL)
   {
      Logger::Error("Allocation de ChartManager impossible");
      return INIT_FAILED;
   }

   if(InpShowVisuals)
   {
      if(CFG_SETUP_CHART_STYLE)
         g_chart.SetupChart();
      g_chart.ShowStrategyName("Gold Asia Reversal");
   }

   //--- Trader
   GoldAsiaConfig cfg;
   cfg.symbol               = _Symbol;
   cfg.magic                = magic;
   cfg.lotSize              = InpLotSize;
   cfg.riskPercent          = InpRiskPercent;
   cfg.maxSpreadPoints      = InpMaxSpreadPoints;
   cfg.slippage             = InpSlippage;
   cfg.maxEntryDelayMinutes = CFG_MAX_ENTRY_DELAY_MINUTES;
   cfg.tradeComment         = CFG_TRADE_COMMENT;
   cfg.showVisuals          = InpShowVisuals;
   cfg.drawSessionZones     = InpDrawSessionZones;
   cfg.clearDrawingsOnExit  = InpClearDrawingsOnExit;
   cfg.zoneHistoryCount     = InpZoneHistoryCount;
   cfg.zoneColor            = InpZoneColor;
   cfg.zoneWinColor         = InpZoneWinColor;
   cfg.zoneLossColor        = InpZoneLossColor;

   g_trader = new GoldAsiaTrader();
   if(g_trader == NULL)
   {
      Logger::Error("Allocation de GoldAsiaTrader impossible");
      delete g_chart;
      g_chart = NULL;
      return INIT_FAILED;
   }

   if(!g_trader.Initialize(cfg,
                           InpMinRisePercent, InpBearishBarsRequired,
                           CFG_IGNORE_SUNDAY_D1, CFG_RISE_MODE,
                           InpAsiaStartHHMM, InpAsiaEndHHMM,
                           InpUseServerTime, InpTradeDays,
                           InpSlMethod, CFG_ATR_TIMEFRAME, CFG_ATR_PERIOD,
                           InpSlAtrMultiplier, InpSlFixedPoints, InpSlBufferPoints,
                           InpMinSlPoints, InpMaxSlPoints,
                           InpTpMode, InpRiskRewardRatio, InpTpAtrMultiplier, InpTpFixedPoints,
                           g_chart))
   {
      Logger::Error("Initialisation du trader echouee");
      delete g_trader;
      g_trader = NULL;
      delete g_chart;
      g_chart = NULL;
      return INIT_FAILED;
   }

   DisplayConfigurationInfo(magic);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Arret                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_trader != NULL)
   {
      g_trader.Deinitialize(reason);
      delete g_trader;
      g_trader = NULL;
   }

   if(g_chart != NULL)
   {
      g_chart.ClearLabels();
      delete g_chart;
      g_chart = NULL;
   }

   Comment("");
}

//+------------------------------------------------------------------+
//| Boucle principale                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_trader != NULL)
      g_trader.OnTick();
}
//+------------------------------------------------------------------+
