"""
Force le téléchargement de l'historique complet depuis MT5
Télécharge année par année pour maximiser la disponibilité
"""
import MetaTrader5 as mt5
from datetime import datetime
import time
import sys
from pathlib import Path

# Ajouter le module data pour sauvegarder
sys.path.insert(0, str(Path(__file__).parent))
from data.data_manager import DataManager

def force_download_by_chunks(symbol: str = "EURUSD", timeframe: str = "M3", save_cache: bool = True):
    """
    Demande l'historique par petits morceaux pour forcer le téléchargement
    
    Args:
        symbol: Symbole à télécharger
        timeframe: Timeframe (M1, M3, M5, H1, etc.)
        save_cache: Sauvegarder dans le cache après téléchargement
    """
    
    TF_MAP = {
        'M1': mt5.TIMEFRAME_M1,
        'M2': mt5.TIMEFRAME_M2,
        'M3': mt5.TIMEFRAME_M3,
        'M4': mt5.TIMEFRAME_M4,
        'M5': mt5.TIMEFRAME_M5,
        'M6': mt5.TIMEFRAME_M6,
        'M10': mt5.TIMEFRAME_M10,
        'M12': mt5.TIMEFRAME_M12,
        'M15': mt5.TIMEFRAME_M15,
        'M20': mt5.TIMEFRAME_M20,
        'M30': mt5.TIMEFRAME_M30,
        'H1': mt5.TIMEFRAME_H1,
        'H2': mt5.TIMEFRAME_H2,
        'H3': mt5.TIMEFRAME_H3,
        'H4': mt5.TIMEFRAME_H4,
        'H6': mt5.TIMEFRAME_H6,
        'H8': mt5.TIMEFRAME_H8,
        'H12': mt5.TIMEFRAME_H12,
        'D1': mt5.TIMEFRAME_D1,
        'W1': mt5.TIMEFRAME_W1,
        'MN1': mt5.TIMEFRAME_MN1,
    }
    
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5")
        print("   Vérifiez que MT5 est ouvert")
        return None
    
    print(f"\n{'='*70}")
    print(f"🔄 TÉLÉCHARGEMENT FORCÉ: {symbol} {timeframe}")
    print(f"{'='*70}\n")
    
    # Vérifier le symbole
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        print(f"❌ Symbole '{symbol}' introuvable")
        mt5.shutdown()
        return None
    
    # Activer le symbole
    if not symbol_info.visible:
        print(f"⚙️  Activation du symbole...")
        mt5.symbol_select(symbol, True)
    
    print(f"✅ Symbole: {symbol_info.name}")
    print(f"   Description: {symbol_info.description}")
    print(f"   Point: {symbol_info.point}\n")
    
    mt5_tf = TF_MAP.get(timeframe.upper())
    if mt5_tf is None:
        print(f"❌ Timeframe invalide: {timeframe}")
        print(f"   Disponibles: {', '.join(TF_MAP.keys())}")
        mt5.shutdown()
        return None
    
    # Demander des chunks année par année (force le téléchargement)
    print(f"📥 Téléchargement par années (2000-2025)...\n")
    
    total_bars = 0
    years_data = []
    
    current_year = datetime.now().year
    
    for year in range(current_year, 1999, -1):  # De maintenant à 2000
        start = datetime(year, 1, 1)
        end = datetime(year + 1, 1, 1)
        
        print(f"📅 {year}... ", end="", flush=True)
        
        rates = mt5.copy_rates_range(symbol, mt5_tf, start, end)
        
        if rates is not None and len(rates) > 0:
            total_bars += len(rates)
            years_data.append((year, len(rates)))
            print(f"✅ {len(rates):,} barres")
        else:
            error = mt5.last_error()
            if error[0] != 1:  # 1 = pas de données (normal pour années anciennes)
                print(f"❌ Erreur: {error}")
            else:
                print(f"⊘  Pas de données")
                # Arrêter si on n'a plus de données
                if year < current_year - 2:  # Au moins 2 ans sans données
                    print(f"\n💡 Plus de données avant {year}")
                    break
        
        time.sleep(0.1)  # Petite pause pour ne pas surcharger MT5
    
    print(f"\n{'='*70}")
    print(f"📊 RÉSUMÉ DU TÉLÉCHARGEMENT PAR CHUNKS")
    print(f"{'='*70}")
    print(f"Total téléchargé: {total_bars:,} barres sur {len(years_data)} années\n")
    
    if years_data:
        print("Années disponibles:")
        for year, bars in years_data[:5]:  # Afficher les 5 plus récentes
            print(f"  • {year}: {bars:,} barres")
        if len(years_data) > 5:
            print(f"  ... et {len(years_data) - 5} années supplémentaires")
    
    # Test final - récupération complète
    print(f"\n{'='*70}")
    print(f"🧪 TEST DE RÉCUPÉRATION COMPLÈTE")
    print(f"{'='*70}\n")
    
    oldest_year = min(year for year, _ in years_data) if years_data else 2000
    
    print(f"📥 Tentative de récupération: {oldest_year}-{current_year}...")
    
    full = mt5.copy_rates_range(
        symbol, 
        mt5_tf,
        datetime(oldest_year, 1, 1),
        datetime.now()
    )
    
    result_df = None
    
    if full is not None and len(full) > 0:
        import pandas as pd
        df = pd.DataFrame(full)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        df.set_index('time', inplace=True)
        df.rename(columns={'tick_volume': 'volume'}, inplace=True)
        df = df[['open', 'high', 'low', 'close', 'volume']]
        
        print(f"\n✅ SUCCÈS !")
        print(f"   • Barres récupérées: {len(full):,}")
        print(f"   • Depuis: {df.index.min()}")
        print(f"   • Jusqu'à: {df.index.max()}")
        print(f"   • Durée: {(df.index.max() - df.index.min()).days} jours (~{(df.index.max() - df.index.min()).days/365:.1f} ans)")
        
        result_df = df
        
        # Sauvegarder dans le cache
        if save_cache:
            print(f"\n💾 Sauvegarde dans le cache...")
            data_manager = DataManager()
            cache_path = data_manager.cache_data(df, symbol, timeframe)
            print(f"   ✅ Sauvegardé: {cache_path}")
    else:
        error = mt5.last_error()
        print(f"\n⚠️  Récupération complète échouée")
        print(f"   Erreur: {error}")
        print(f"   Total téléchargé par chunks: {total_bars:,} barres")
        print(f"\n💡 Bien que le téléchargement par chunks ait réussi,")
        print(f"   la récupération complète échoue. Cela peut être dû à:")
        print(f"   • Limitation du broker pour ce timeframe")
        print(f"   • Trop de données demandées d'un coup")
        print(f"   • Utiliser copy_rates_from_pos() au lieu de copy_rates_range()")
        
        # Essayer avec copy_rates_from_pos (méthode alternative)
        print(f"\n🔄 Tentative alternative avec copy_rates_from_pos...")
        alt_rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 100000)
        
        if alt_rates is not None and len(alt_rates) > 0:
            import pandas as pd
            df = pd.DataFrame(alt_rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            df.rename(columns={'tick_volume': 'volume'}, inplace=True)
            df = df[['open', 'high', 'low', 'close', 'volume']]
            
            print(f"\n✅ SUCCÈS avec méthode alternative !")
            print(f"   • Barres récupérées: {len(alt_rates):,}")
            print(f"   • Depuis: {df.index.min()}")
            print(f"   • Jusqu'à: {df.index.max()}")
            print(f"   • Durée: {(df.index.max() - df.index.min()).days} jours (~{(df.index.max() - df.index.min()).days/365:.1f} ans)")
            
            result_df = df
            
            # Sauvegarder dans le cache
            if save_cache:
                print(f"\n💾 Sauvegarde dans le cache...")
                data_manager = DataManager()
                cache_path = data_manager.cache_data(df, symbol, timeframe)
                print(f"   ✅ Sauvegardé: {cache_path}")
    
    mt5.shutdown()
    
    print(f"\n{'='*70}")
    print(f"🎯 TÉLÉCHARGEMENT TERMINÉ")
    print(f"{'='*70}\n")
    
    return result_df


def batch_download(symbols: list = None, timeframes: list = None):
    """
    Télécharge plusieurs symboles et timeframes
    
    Args:
        symbols: Liste de symboles (défaut: ["EURUSD", "GBPUSD", "XAUUSD"])
        timeframes: Liste de TF (défaut: ["M5", "H1"])
    """
    if symbols is None:
        symbols = ["EURUSD", "GBPUSD", "XAUUSD", "US100.cash"]
    
    if timeframes is None:
        timeframes = ["M5", "H1"]
    
    print(f"\n{'='*70}")
    print(f"📥 TÉLÉCHARGEMENT BATCH")
    print(f"{'='*70}")
    print(f"\n📊 Configuration:")
    print(f"   • Symboles: {', '.join(symbols)}")
    print(f"   • Timeframes: {', '.join(timeframes)}")
    print(f"   • Total: {len(symbols) * len(timeframes)} configurations\n")
    
    results = []
    success = 0
    failed = 0
    
    for symbol in symbols:
        for tf in timeframes:
            print(f"\n{'─'*70}")
            df = force_download_by_chunks(symbol, tf, save_cache=True)
            
            if df is not None:
                success += 1
                results.append({
                    'symbol': symbol,
                    'timeframe': tf,
                    'bars': len(df),
                    'from': df.index.min(),
                    'to': df.index.max(),
                    'status': 'OK'
                })
            else:
                failed += 1
                results.append({
                    'symbol': symbol,
                    'timeframe': tf,
                    'status': 'FAILED'
                })
            
            time.sleep(1)  # Pause entre chaque téléchargement
    
    # Résumé final
    print(f"\n{'='*70}")
    print(f"📊 RÉSUMÉ FINAL")
    print(f"{'='*70}\n")
    
    print(f"✅ Réussis: {success}/{len(symbols) * len(timeframes)}")
    print(f"❌ Échecs: {failed}/{len(symbols) * len(timeframes)}\n")
    
    if success > 0:
        print("Configurations téléchargées:")
        for r in results:
            if r['status'] == 'OK':
                days = (r['to'] - r['from']).days
                print(f"  ✅ {r['symbol']:<15} {r['timeframe']:<5} {r['bars']:>7,} barres ({days:>4} jours)")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Force le téléchargement d'historique MT5")
    parser.add_argument('--symbol', type=str, help='Symbole (ex: EURUSD)')
    parser.add_argument('--timeframe', type=str, help='Timeframe (ex: M3, H1)')
    parser.add_argument('--batch', action='store_true', help='Mode batch (plusieurs symboles)')
    parser.add_argument('--no-cache', action='store_true', help='Ne pas sauvegarder dans le cache')
    
    args = parser.parse_args()
    
    if args.batch:
        # Mode batch
        batch_download()
    elif args.symbol and args.timeframe:
        # Mode simple
        force_download_by_chunks(
            symbol=args.symbol.upper(),
            timeframe=args.timeframe.upper(),
            save_cache=not args.no_cache
        )
    else:
        # Mode interactif
        print("\n🔄 Téléchargement forcé d'historique MT5\n")
        print("Ce script va forcer MT5 à télécharger l'historique")
        print("en demandant les données année par année.\n")
        
        symbol = input("Symbole (ex: EURUSD): ").strip().upper()
        timeframe = input("Timeframe (ex: M3, H1): ").strip().upper()
        
        if not symbol:
            symbol = "EURUSD"
        if not timeframe:
            timeframe = "M3"
        
        force_download_by_chunks(symbol, timeframe, save_cache=True)

