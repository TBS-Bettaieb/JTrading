"""
Diagnostic de l'historique disponible sur MT5
Vérifie exactement quelles données sont accessibles
"""
import MetaTrader5 as mt5
from datetime import datetime, timedelta
import pandas as pd
import sys

def check_available_history(symbol: str, timeframe: str = "M5"):
    """
    Vérifie l'historique maximum disponible pour un symbole
    """
    print(f"\n{'='*70}")
    print(f"🔍 DIAGNOSTIC HISTORIQUE: {symbol} {timeframe}")
    print(f"{'='*70}\n")
    
    # Mapping timeframes
    TF_MAP = {
        'M1': mt5.TIMEFRAME_M1,
        'M5': mt5.TIMEFRAME_M5,
        'M15': mt5.TIMEFRAME_M15,
        'M30': mt5.TIMEFRAME_M30,
        'H1': mt5.TIMEFRAME_H1,
        'H4': mt5.TIMEFRAME_H4,
        'D1': mt5.TIMEFRAME_D1,
    }
    
    if not mt5.initialize():
        print("❌ Impossible d'initialiser MT5")
        return None
    
    # Info compte
    account = mt5.account_info()
    if account:
        print(f"📊 Compte: {account.login} ({account.server})")
        print(f"   Type: {'DEMO' if 'Demo' in str(account.name) else 'RÉEL'}")
    
    # Vérifier le symbole
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        print(f"❌ Symbole '{symbol}' introuvable\n")
        print("💡 Symboles disponibles (10 premiers):")
        symbols = mt5.symbols_get()
        if symbols:
            for s in symbols[:10]:
                print(f"   - {s.name} ({s.description})")
        mt5.shutdown()
        return None
    
    # Activer le symbole
    if not symbol_info.visible:
        print(f"⚠️  Activation du symbole...")
        mt5.symbol_select(symbol, True)
    
    print(f"✅ Symbole: {symbol_info.name}")
    print(f"   Point: {symbol_info.point}")
    
    # Convertir timeframe
    mt5_tf = TF_MAP.get(timeframe.upper())
    if mt5_tf is None:
        print(f"❌ Timeframe invalide: {timeframe}")
        print(f"   Disponibles: {', '.join(TF_MAP.keys())}")
        mt5.shutdown()
        return None
    
    # TEST 1: Données récentes (méthode la plus fiable)
    print(f"\n📊 Test 1: Maximum de barres disponibles...")
    recent_rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 50000)
    
    if recent_rates is None or len(recent_rates) == 0:
        print(f"   ❌ Aucune donnée disponible")
        mt5.shutdown()
        return None
    
    df_recent = pd.DataFrame(recent_rates)
    df_recent['time'] = pd.to_datetime(df_recent['time'], unit='s')
    
    oldest = df_recent['time'].min()
    newest = df_recent['time'].max()
    duration_days = (newest - oldest).days
    
    print(f"   ✅ {len(recent_rates):,} barres disponibles")
    print(f"   📅 Plus ancienne: {oldest}")
    print(f"   📅 Plus récente: {newest}")
    print(f"   📏 Durée: {duration_days} jours (~{duration_days/365:.1f} ans)")
    
    # TEST 2: Disponibilité par période
    print(f"\n📊 Test 2: Disponibilité par période...")
    
    test_periods = [
        ("7 jours", 7),
        ("30 jours", 30),
        ("90 jours", 90),
        ("6 mois", 180),
        ("1 an", 365),
        ("2 ans", 730),
        ("3 ans", 1095),
        ("4 ans", 1460),
        ("5 ans", 1825),
    ]
    
    now = datetime.now()
    available_periods = []
    
    for period_name, days_back in test_periods:
        start_date = now - timedelta(days=days_back)
        
        rates = mt5.copy_rates_range(symbol, mt5_tf, start_date, now)
        
        if rates is not None and len(rates) > 0:
            df_test = pd.DataFrame(rates)
            df_test['time'] = pd.to_datetime(df_test['time'], unit='s')
            actual_start = df_test['time'].min()
            days_covered = (now - actual_start).days
            
            if days_covered >= days_back * 0.8:  # Au moins 80% des données
                status = "✅"
                available_periods.append(days_back)
            else:
                status = "⚠️"
            
            print(f"   {status} {period_name:15s}: {len(rates):6,} barres ({days_covered} jours)")
        else:
            print(f"   ❌ {period_name:15s}: Aucune donnée")
    
    # TEST 3: Années spécifiques
    print(f"\n📊 Test 3: Disponibilité par année...")
    
    current_year = datetime.now().year
    years_to_test = [current_year - i for i in range(6)]  # 6 dernières années
    
    oldest_year = None
    
    for year in years_to_test:
        start = datetime(year, 1, 1)
        end = datetime(year, 1, 8)  # Première semaine de janvier
        
        rates = mt5.copy_rates_range(symbol, mt5_tf, start, end)
        
        if rates is not None and len(rates) > 0:
            print(f"   ✅ {year}: Données disponibles")
            oldest_year = year
        else:
            print(f"   ❌ {year}: Pas de données")
            break
    
    # RÉSUMÉ
    print(f"\n{'='*70}")
    print("📋 RÉSUMÉ & RECOMMANDATIONS")
    print(f"{'='*70}\n")
    
    print(f"✅ Historique disponible:")
    print(f"   • Depuis: {oldest}")
    print(f"   • Jusqu'à: {newest}")
    print(f"   • Durée: ~{duration_days/365:.1f} ans ({duration_days} jours)")
    print(f"   • Barres: {len(recent_rates):,}")
    
    if oldest_year:
        print(f"   • Année la plus ancienne: {oldest_year}")
    
    print(f"\n💡 Recommandations pour {symbol} {timeframe}:")
    
    if duration_days < 90:
        print("   ⚠️  HISTORIQUE TRÈS LIMITÉ (< 3 mois)")
        print("   → Recommandation: Utiliser H1 ou D1 pour plus d'historique")
    elif duration_days < 365:
        print("   ⚠️  Historique court (< 1 an)")
        print("   → OK pour tests courts, mais considérer H1 pour backtests longs")
    elif duration_days < 730:
        print("   ✅ Historique correct (~1-2 ans)")
        print("   → Bon pour la plupart des backtests")
    else:
        print("   ✅ EXCELLENT historique (> 2 ans)")
        print("   → Parfait pour backtests robustes")
    
    # Suggestions d'utilisation
    print(f"\n🎯 Commandes recommandées:")
    
    # Suggérer le maximum disponible
    max_days = min(duration_days - 1, 365 if timeframe == "M5" else 730)
    print(f"\n   # Télécharger le maximum pour ce timeframe:")
    print(f"   python download_recent_data.py --symbol {symbol} --timeframe {timeframe} --days {max_days}")
    
    # Suggérer H1 si M5 est limité
    if timeframe == "M5" and duration_days < 365:
        print(f"\n   # Alternative avec H1 (plus d'historique):")
        print(f"   python download_recent_data.py --symbol {symbol} --timeframe H1 --days 730")
    
    # Info sur données anciennes
    if oldest.year > 2020:
        print(f"\n⚠️  IMPOSSIBLE d'obtenir données de 2020:")
        print(f"   • Historique commence en {oldest.year}")
        print(f"   • Pour 2020, utilisez:")
        print(f"     → Timeframe plus grand (H1/D1)")
        print(f"     → Source externe (Dukascopy, HistData)")
    
    mt5.shutdown()
    
    return {
        'symbol': symbol,
        'timeframe': timeframe,
        'oldest': oldest,
        'newest': newest,
        'duration_days': duration_days,
        'num_bars': len(recent_rates),
        'oldest_year': oldest_year
    }


def quick_check(symbol: str = "EURUSD"):
    """Vérifie rapidement plusieurs timeframes pour un symbole"""
    
    print(f"\n{'='*70}")
    print(f"⚡ VÉRIFICATION RAPIDE: {symbol}")
    print(f"{'='*70}\n")
    
    timeframes = ["M5", "M15", "H1", "H4", "D1"]
    results = []
    
    for tf in timeframes:
        if not mt5.initialize():
            continue
        
        TF_MAP = {
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1,
        }
        
        # Activer symbole
        mt5.symbol_select(symbol, True)
        
        # Récupérer rapidement les données
        rates = mt5.copy_rates_from_pos(symbol, TF_MAP[tf], 0, 10000)
        
        if rates is not None and len(rates) > 0:
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            oldest = df['time'].min()
            days = (datetime.now() - oldest).days
            
            results.append({
                'tf': tf,
                'bars': len(rates),
                'days': days,
                'oldest': oldest
            })
        
        mt5.shutdown()
    
    # Afficher résumé
    print(f"{'Timeframe':<10} {'Barres':<12} {'Durée':<15} {'Depuis'}")
    print("-" * 70)
    
    for r in results:
        years = r['days'] / 365
        print(f"{r['tf']:<10} {r['bars']:>10,}   {years:>5.1f} ans ({r['days']:>4} j)   {r['oldest'].date()}")
    
    print()


if __name__ == "__main__":
    
    if len(sys.argv) >= 2:
        if sys.argv[1] == "--quick":
            # Mode rapide
            symbol = sys.argv[2] if len(sys.argv) >= 3 else "EURUSD"
            quick_check(symbol)
        else:
            # Mode complet
            symbol = sys.argv[1]
            timeframe = sys.argv[2] if len(sys.argv) >= 3 else "M5"
            check_available_history(symbol, timeframe)
    else:
        # Mode interactif
        print("\n🔍 Vérification de l'historique MT5\n")
        print("1. Vérification rapide (tous timeframes)")
        print("2. Vérification détaillée (un timeframe)")
        
        choice = input("\nChoix (1 ou 2): ").strip()
        
        if choice == "1":
            symbol = input("Symbole (ex: EURUSD): ").strip().upper()
            if not symbol:
                symbol = "EURUSD"
            quick_check(symbol)
        else:
            symbol = input("Symbole (ex: EURUSD): ").strip().upper()
            timeframe = input("Timeframe (ex: M5, H1): ").strip().upper()
            
            if not symbol:
                symbol = "EURUSD"
            if not timeframe:
                timeframe = "M5"
            
            check_available_history(symbol, timeframe)

