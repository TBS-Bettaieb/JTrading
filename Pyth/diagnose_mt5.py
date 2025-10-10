"""
Diagnostic MT5 - Vérifie la connexion et les symboles disponibles
"""
import MetaTrader5 as mt5
from datetime import datetime, timedelta
import pandas as pd


def diagnose_mt5():
    """Diagnostic complet de la connexion MT5"""
    
    print("\n" + "=" * 70)
    print("🔬 DIAGNOSTIC MT5")
    print("=" * 70)
    
    # 1. Initialisation
    print("\n1️⃣ Initialisation MT5...")
    if not mt5.initialize():
        print(f"❌ Échec initialisation: {mt5.last_error()}")
        return False
    
    print("✅ MT5 initialisé")
    
    # 2. Informations terminal
    print("\n2️⃣ Informations Terminal:")
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"   Build: {terminal_info.build}")
        print(f"   Nom: {terminal_info.name}")
        print(f"   Chemin: {terminal_info.path}")
        print(f"   Data path: {terminal_info.data_path}")
        print(f"   Connexion: {terminal_info.connected}")
    
    # 3. Informations compte
    print("\n3️⃣ Informations Compte:")
    account_info = mt5.account_info()
    if account_info:
        print(f"   Login: {account_info.login}")
        print(f"   Serveur: {account_info.server}")
        print(f"   Balance: ${account_info.balance:,.2f}")
        print(f"   Levier: 1:{account_info.leverage}")
        print(f"   Trade allowed: {account_info.trade_allowed}")
    
    # 4. Symboles disponibles
    print("\n4️⃣ Symboles Disponibles:")
    symbols = mt5.symbols_get()
    if symbols:
        print(f"   Total symboles: {len(symbols)}")
        
        # Afficher quelques symboles majeurs
        major_symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 
                        'US100', 'US100.cash', 'US30', 'US500',
                        'XAUUSD', 'BTCUSD']
        
        print("\n   Symboles majeurs recherchés:")
        for symbol_name in major_symbols:
            symbol_info = mt5.symbol_info(symbol_name)
            if symbol_info:
                visible = "✅" if symbol_info.visible else "⚠️ (invisible)"
                print(f"      {symbol_name:15} {visible}")
            else:
                print(f"      {symbol_name:15} ❌ Non trouvé")
    
    # 5. Test de téléchargement
    print("\n5️⃣ Test de Téléchargement:")
    
    # Essayer plusieurs symboles
    test_symbols = ['EURUSD', 'GBPUSD', 'US100.cash', 'XAUUSD']
    test_timeframes = {
        'M5': mt5.TIMEFRAME_M5,
        'H1': mt5.TIMEFRAME_H1,
        'D1': mt5.TIMEFRAME_D1
    }
    
    for symbol in test_symbols:
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            continue
        
        # Sélectionner le symbole
        if not mt5.symbol_select(symbol, True):
            print(f"   ❌ {symbol}: Impossible de sélectionner")
            continue
        
        print(f"\n   📊 {symbol}:")
        print(f"      Point: {symbol_info.point}")
        print(f"      Digits: {symbol_info.digits}")
        print(f"      Spread: {symbol_info.spread}")
        
        # Tester téléchargement
        for tf_name, tf_value in list(test_timeframes.items())[:1]:  # Seulement M5
            # Méthode 1: copy_rates_from_pos
            rates1 = mt5.copy_rates_from_pos(symbol, tf_value, 0, 100)
            if rates1 is not None and len(rates1) > 0:
                print(f"      ✅ {tf_name} (from_pos): {len(rates1)} barres")
            else:
                error = mt5.last_error()
                print(f"      ❌ {tf_name} (from_pos): {error}")
            
            # Méthode 2: copy_rates_range
            date_to = datetime.now()
            date_from = date_to - timedelta(days=30)
            rates2 = mt5.copy_rates_range(symbol, tf_value, date_from, date_to)
            if rates2 is not None and len(rates2) > 0:
                print(f"      ✅ {tf_name} (range): {len(rates2)} barres")
            else:
                error = mt5.last_error()
                print(f"      ❌ {tf_name} (range): {error}")
    
    # 6. Recommandations
    print("\n" + "=" * 70)
    print("💡 RECOMMANDATIONS:")
    print("=" * 70)
    
    # Compter les symboles fonctionnels
    working_symbols = []
    for symbol in test_symbols:
        if mt5.symbol_info(symbol):
            if mt5.symbol_select(symbol, True):
                rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_H1, 0, 10)
                if rates is not None and len(rates) > 0:
                    working_symbols.append(symbol)
    
    if working_symbols:
        print(f"\n✅ Symboles fonctionnels trouvés: {', '.join(working_symbols)}")
        print("\n💡 Utilisez ces symboles pour vos backtests:")
        for sym in working_symbols:
            print(f"   python backtest.py --symbol {sym} --timeframe H1")
    else:
        print("\n❌ Aucun symbole fonctionnel trouvé")
        print("\n💡 Solutions possibles:")
        print("   1. Vérifier que MT5 est connecté à un serveur")
        print("   2. Ouvrir un graphique du symbole dans MT5 pour charger l'historique")
        print("   3. Vérifier Market Watch → Clic droit → Afficher tout")
        print("   4. Télécharger l'historique manuellement: Outils → Historique")
    
    # Nettoyage
    mt5.shutdown()
    
    print("\n" + "=" * 70)
    print("✅ Diagnostic terminé")
    print("=" * 70)
    
    return True


if __name__ == "__main__":
    diagnose_mt5()

