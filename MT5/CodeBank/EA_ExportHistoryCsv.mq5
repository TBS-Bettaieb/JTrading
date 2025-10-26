//+------------------------------------------------------------------+
//|                                   EA_ExportHistoryCsv.mq5        |
//|           EA sans ordres : export OHLC en CSV                    |
//+------------------------------------------------------------------+
#property strict

//--------------------------- Inputs --------------------------------
input string           InpSymbol      = "";                 // Symbole (vide = _Symbol)
input ENUM_TIMEFRAMES  InpTF          = PERIOD_CURRENT;     // Timeframe
input datetime         InpFrom        = D'2018.01.01 00:00';
input datetime         InpTo          = 0;                  // 0 = TimeCurrent()
input int              InpChunkBars   = 10000;              // Barres par paquet
input bool             InpCommonDir   = true;               // Dossier commun
input string           InpCustomPath  = "";                 // Sous-dossier (ex: "MyExports" ou vide)
input bool             InpWriteHeader = true;               // Entete CSV

//--------------------------- Helpers -------------------------------
string Sym() 
{ 
   return (InpSymbol == "" ? _Symbol : InpSymbol); 
}

string MakeFileName(const string sym, const ENUM_TIMEFRAMES tf, const datetime from_dt, const datetime to_dt)
{
   MqlDateTime dt_from, dt_to;
   TimeToStruct(from_dt, dt_from);
   TimeToStruct(to_dt, dt_to);
   
   string tfstr = EnumToString(tf);
   string filename = StringFormat("%s_%s_%04d%02d%02d_%04d%02d%02d.csv",
                           sym, tfstr,
                           dt_from.year, dt_from.mon, dt_from.day,
                           dt_to.year, dt_to.mon, dt_to.day);
   
   // Ajouter le sous-dossier si spécifié
   if(InpCustomPath != "")
   {
      string path = InpCustomPath;
      // Remplacer les backslash par des forward slash
      StringReplace(path, "\\", "/");
      // Retirer le slash final s'il existe
      if(StringSubstr(path, StringLen(path)-1) == "/")
         path = StringSubstr(path, 0, StringLen(path)-1);
      
      filename = path + "/" + filename;
   }
   
   return filename;
}

int OpenCsv(const string name, const bool header)
{
   int flags = FILE_WRITE | FILE_CSV | FILE_ANSI;
   if(InpCommonDir) 
      flags |= FILE_COMMON;
      
   int h = FileOpen(name, flags, ';');
   if(h == INVALID_HANDLE)
   {
      Print("FileOpen failed: ", name, " err=", GetLastError());
      return h;
   }
   if(header)
      FileWrite(h, "time_unix","time_iso","open","high","low","close","tick_volume","real_volume","spread");
   return h;
}

//--------------------------- Export complet -------------------------
void ExportAllData()
{
   string symbol = Sym();
   ENUM_TIMEFRAMES tf = (InpTF == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF);
   datetime from_dt = InpFrom;
   datetime to_dt = (InpTo == 0 ? TimeCurrent() : InpTo);
   
   PrintFormat("Symbol: %s, TF: %s, From: %s, To: %s", 
               symbol, EnumToString(tf), TimeToString(from_dt), TimeToString(to_dt));
   
   if(!SymbolSelect(symbol, true))
   {
      Print("ERROR: Cannot select symbol: ", symbol);
      return;
   }
   
   // Vérifier les données disponibles
   int bars_available = Bars(symbol, tf);
   
   PrintFormat("Available bars: %d", bars_available);
   
   if(bars_available == 0)
   {
      Print("ERROR: No bars available for this symbol/timeframe!");
      return;
   }
   
   string fileName = MakeFileName(symbol, tf, from_dt, to_dt);
   int fh = OpenCsv(fileName, InpWriteHeader);
   if(fh == INVALID_HANDLE)
   {
      Print("ERROR: Cannot create file: ", fileName);
      return;
   }
   
   PrintFormat("File opened: %s (handle=%d)", fileName, fh);
   
   // Copier TOUTES les barres disponibles
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   
   Print("Copying all available rates...");
   int copied = CopyRates(symbol, tf, 0, bars_available, rates);
   
   PrintFormat("CopyRates returned: %d bars (requested: %d, error: %d)", 
               copied, bars_available, GetLastError());
   
   if(copied <= 0)
   {
      Print("ERROR: CopyRates failed!");
      FileClose(fh);
      return;
   }
   
   // Filtrer et écrire les barres dans la plage demandée
   int totalBars = 0;
   for(int i = 0; i < copied; i++)
   {
      // Ne garder que les barres dans la plage demandée
      if(rates[i].time < from_dt)
         continue;
      if(rates[i].time >= to_dt)
         break;
         
      string iso = TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES);
      FileWrite(fh,
                (long)rates[i].time, iso,
                DoubleToString(rates[i].open, _Digits),
                DoubleToString(rates[i].high, _Digits),
                DoubleToString(rates[i].low, _Digits),
                DoubleToString(rates[i].close, _Digits),
                (long)rates[i].tick_volume,
                (long)rates[i].real_volume,
                (int)rates[i].spread);
      totalBars++;
   }
   
   FileClose(fh);
   
   PrintFormat("========================================");
   PrintFormat("EXPORT COMPLETE: %d bars exported to %s", totalBars, fileName);
   PrintFormat("First bar time: %s", totalBars > 0 ? TimeToString(rates[0].time) : "N/A");
   PrintFormat("========================================");
}

//--------------------------- Global state ---------------------------
bool g_exported = false;
bool g_orderPlaced = false;
int g_tickCount = 0;

//--------------------------- Place Order --------------------------------
void PlaceSimpleBuyOrder()
{
   if(g_orderPlaced) return;
   
   string symbol = Sym();
   double volume = 0.01;
   double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = volume;
   request.type = ORDER_TYPE_BUY;
   request.price = price;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "Simple Buy Order";
   
   if(OrderSend(request, result))
   {
      PrintFormat("Buy order placed: ticket=%d, price=%f", result.order, result.price);
      g_orderPlaced = true;
   }
   else
   {
      PrintFormat("OrderSend failed: retcode=%d", result.retcode);
   }
}

//--------------------------- EA lifecycle --------------------------
int OnInit()
{
   Print("=== EA Initialized ===");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("EA stopped.");
}

void OnTick() 
{ 
   g_tickCount++;
   
   // Placer l'ordre Buy au premier tick
   if(g_tickCount == 1)
   {
      Print("=== First tick - placing order ===");
      PlaceSimpleBuyOrder();
   }
   
   // Exporter au 5ème tick (laisser le temps aux données de se charger)
   if(g_tickCount == 5 && !g_exported)
   {
      Print("=== Starting CSV Export ===");
      ExportAllData();
      g_exported = true;
   }
}