//+------------------------------------------------------------------+
//|                                                JT_Positions.mqh |
//|                       Fonctions de gestion des positions (MT5)   |
//|                                      (c) 2025 - Public Domain    |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

// Vérifie si une position est ouverte sur un symbole
bool HasOpenPosition(
   string symbol,
   ulong magic,
   int &direction,    // 1=buy, -1=sell, 0=none
   ulong &ticket
) {
   direction = 0; 
   ticket = 0;
   int total = PositionsTotal();
   
   for(int i=0; i<total; i++) {
      // Obtenir le ticket de la position par son index
      ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0) continue;
      
      // Sélectionner la position par son ticket
      if(!PositionSelectByTicket(pos_ticket)) continue;
      
      // Vérifier le symbole
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      if(posSymbol != symbol) continue;
      
      // Vérifier le magic number
      if(magic > 0 && PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      // Position trouvée, récupérer les informations
      long type = PositionGetInteger(POSITION_TYPE);
      ticket = pos_ticket;
      direction = (type == POSITION_TYPE_BUY ? 1 : -1);
      return true;
   }
   
   return false;
}

// Ferme une position par ticket
bool ClosePosition(
   CTrade &trade,
   ulong ticket,
   string comment = "",
   double slippage = 0
) {
   if(!PositionSelectByTicket(ticket)) return false;
   
   return trade.PositionClose(ticket, slippage);
}

// Modifie le SL/TP d'une position
bool ModifyPosition(
   CTrade &trade,
   ulong ticket,
   double newSL,
   double newTP
) {
   if(!PositionSelectByTicket(ticket)) return false;
   
   return trade.PositionModify(ticket, newSL, newTP);
}

// Ouvre une position d'achat
bool OpenBuyPosition(
   CTrade &trade,
   string symbol,
   double volume,
   double price,
   double sl,
   double tp,
   string comment = ""
) {
   return trade.Buy(volume, symbol, price, sl, tp, comment);
}

// Ouvre une position de vente
bool OpenSellPosition(
   CTrade &trade,
   string symbol,
   double volume,
   double price,
   double sl,
   double tp,
   string comment = ""
) {
   return trade.Sell(volume, symbol, price, sl, tp, comment);
}

// Vérifie si l'heure actuelle est dans une plage autorisée
bool InRangeHour(const int hourVal, const int startH, const int endH) {
   if(startH == endH) return (hourVal == startH);
   if(startH < endH) return (hourVal >= startH && hourVal <= endH);
   // wrap over midnight
   return (hourVal >= startH || hourVal <= endH);
}

// Vérifie si l'heure actuelle est autorisée pour le trading
bool IsHourAllowed(
   bool useFilter,
   int range1Start,
   int range1End,
   int range2Start,
   int range2End,
   int range3Start,
   int range3End
) {
   if(!useFilter) return true;
   
   MqlDateTime dt; 
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;

   if(InRangeHour(h, range1Start, range1End)) return true;
   if(InRangeHour(h, range2Start, range2End)) return true;
   if(InRangeHour(h, range3Start, range3End)) return true;
   
   return false;
}
