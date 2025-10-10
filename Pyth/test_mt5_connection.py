"""
Test de connexion MetaTrader 5
"""
import MetaTrader5 as mt5
from datetime import datetime


def test_mt5_connection():
    """Teste la connexion à MetaTrader 5"""
    
    print("=" * 70)
    print("TEST DE CONNEXION METATRADER 5")
    print("=" * 70)
    print()
    
    # Initialisation
    print("🔌 Tentative de connexion à MetaTrader 5...")
    
    if not mt5.initialize():
        print(f"❌ Échec de l'initialisation, code d'erreur: {mt5.last_error()}")
        print("\n⚠️  Vérifiez que:")
        print("   1. MetaTrader 5 est installé")
        print("   2. MetaTrader 5 est en cours d'exécution")
        print("   3. Vous avez les droits d'accès")
        mt5.shutdown()
        return False
    
    print("✅ Connexion réussie!")
    print()
    
    # Informations sur le compte
    print("=" * 70)
    print("INFORMATIONS DU COMPTE")
    print("=" * 70)
    
    account_info = mt5.account_info()
    if account_info is not None:
        print(f"  Login:           {account_info.login}")
        print(f"  Serveur:         {account_info.server}")
        print(f"  Nom:             {account_info.name}")
        print(f"  Devise:          {account_info.currency}")
        print(f"  Balance:         {account_info.balance:,.2f}")
        print(f"  Equity:          {account_info.equity:,.2f}")
        print(f"  Marge:           {account_info.margin:,.2f}")
        print(f"  Marge libre:     {account_info.margin_free:,.2f}")
        print(f"  Niveau marge:    {account_info.margin_level:.2f}%")
        print(f"  Type compte:     {'DEMO' if account_info.trade_mode == 0 else 'RÉEL'}")
    
    print()
    
    # Informations sur le terminal
    print("=" * 70)
    print("INFORMATIONS DU TERMINAL")
    print("=" * 70)
    
    terminal_info = mt5.terminal_info()
    if terminal_info is not None:
        print(f"  Version MT5:     {terminal_info.build}")
        print(f"  Entreprise:      {terminal_info.company}")
        print(f"  Nom:             {terminal_info.name}")
        print(f"  Chemin:          {terminal_info.path}")
        print(f"  Connecté:        {'✅ Oui' if terminal_info.connected else '❌ Non'}")
        print(f"  Trading autorisé: {'✅ Oui' if terminal_info.trade_allowed else '❌ Non'}")
    
    print()
    
    # Test de récupération de symboles
    print("=" * 70)
    print("SYMBOLES DISPONIBLES (5 premiers)")
    print("=" * 70)
    
    symbols = mt5.symbols_get()
    if symbols:
        print(f"  Total symboles: {len(symbols)}\n")
        for symbol in symbols[:5]:
            print(f"  • {symbol.name:12s} - {symbol.description}")
    
    print()
    
    # Test de récupération de données
    print("=" * 70)
    print("TEST DE RÉCUPÉRATION DE DONNÉES (EURUSD)")
    print("=" * 70)
    
    symbol = "EURUSD"
    
    # Sélectionner le symbole
    if not mt5.symbol_select(symbol, True):
        print(f"⚠️  Symbole {symbol} non disponible, essai avec un autre...")
        # Essayer avec le premier symbole disponible
        if symbols:
            symbol = symbols[0].name
            mt5.symbol_select(symbol, True)
    
    # Récupérer les derniers ticks
    ticks = mt5.copy_ticks_from(symbol, datetime.now(), 10, mt5.COPY_TICKS_ALL)
    if ticks is not None and len(ticks) > 0:
        print(f"✅ {len(ticks)} ticks récupérés pour {symbol}")
        print(f"  Dernier Bid: {ticks[-1]['bid']:.5f}")
        print(f"  Dernier Ask: {ticks[-1]['ask']:.5f}")
    else:
        print(f"⚠️  Pas de ticks disponibles pour {symbol}")
    
    # Récupérer des barres
    from datetime import timedelta
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    
    rates = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_H1, start_date, end_date)
    if rates is not None and len(rates) > 0:
        print(f"✅ {len(rates)} barres H1 récupérées")
        print(f"  Dernière clôture: {rates[-1]['close']:.5f}")
        print(f"  Plus haut: {rates[-1]['high']:.5f}")
        print(f"  Plus bas: {rates[-1]['low']:.5f}")
    else:
        print(f"⚠️  Pas de barres disponibles pour {symbol}")
    
    print()
    
    # Fermeture
    mt5.shutdown()
    
    print("=" * 70)
    print("✅ TEST TERMINÉ AVEC SUCCÈS!")
    print("=" * 70)
    print()
    print("🚀 Vous êtes prêt à utiliser le système de trading!")
    print()
    
    return True


if __name__ == "__main__":
    import sys
    success = test_mt5_connection()
    sys.exit(0 if success else 1)

