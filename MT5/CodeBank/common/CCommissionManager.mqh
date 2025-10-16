//+------------------------------------------------------------------+
//| Classe helper pour gérer les commissions                         |
//+------------------------------------------------------------------+
class CCommissionManager
{
private:
    // Cache des commissions par broker/symbole
    double m_defaultCommissionPerLot;
    
public:
    CCommissionManager() : m_defaultCommissionPerLot(3.0) {}
    
    // Récupère la commission réelle d'une position
    double GetPositionCommission(ulong ticket)
    {
        // Essayer depuis HistorySelectByPosition
        if(HistorySelectByPosition(ticket))
        {
            for(int i = 0; i < HistoryDealsTotal(); i++)
            {
                ulong dealTicket = HistoryDealGetTicket(i);
                if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket)
                {
                    return HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                }
            }
        }
        return 0;
    }
    
    // Récupère ou estime la commission
    double GetCommission(CPositionInfo &position)
    {
        // 1. Essayer depuis la position
        double comm = position.Commission();
        if(comm != 0) return MathAbs(comm);
        
        // 2. Essayer depuis l'historique
        comm = GetPositionCommission(position.Ticket());
        if(comm != 0) return MathAbs(comm);
        
        // 3. Estimer
        return m_defaultCommissionPerLot * position.Volume();
    }
};

