"""
Script pour télécharger et cacher les données récentes disponibles depuis MT5
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from live_trading.mt5_connector import MT5Connector
from data.data_manager import DataManager
from datetime import datetime, timedelta
import pandas as pd

def download_recent_data(symbol: str, timeframe: str, days_back: int = 90):
    """
    Télécharge les données récentes disponibles
    
    Args:
        symbol: Symbole à télécharger
        timeframe: Timeframe (M5, H1, etc.)
        days_back: Nombre de jours à remonter (défaut: 90)
    """
    print(f"\n{'='*60}")
    print(f"📥 Téléchargement de {symbol} {timeframe}")
    print(f"{'='*60}\n")
    
    connector = MT5Connector()
    data_manager = DataManager()
    
    # Se connecter
    if not connector.connect():
        print("❌ Impossible de se connecter à MT5")
        return False
    
    print(f"📊 Téléchargement des {days_back} derniers jours...")
    
    # Calculer les dates
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days_back)
    
    # Télécharger
    df = connector.get_ohlcv_range(symbol, timeframe, start_date, end_date)
    
    if df is None or len(df) == 0:
        print(f"❌ Aucune donnée disponible pour {symbol} {timeframe}")
        
        # Essayer avec copy_rates_from_pos
        print(f"\n🔄 Essai avec méthode alternative (barres récentes)...")
        df = connector.get_ohlcv(symbol, timeframe, count=50000)
        
        if df is None or len(df) == 0:
            print(f"❌ Échec total pour {symbol} {timeframe}")
            connector.disconnect()
            return False
    
    print(f"✅ {len(df)} barres téléchargées")
    print(f"📅 Période: {df.index[0]} → {df.index[-1]}")
    print(f"💾 Taille: {df.memory_usage().sum() / 1024 / 1024:.2f} MB")
    
    # Cacher les données
    cache_path = data_manager.cache_data(df, symbol, timeframe)
    print(f"💾 Données cachées: {cache_path}")
    
    # Déconnecter
    connector.disconnect()
    
    print(f"\n{'='*60}")
    print(f"✅ Téléchargement terminé !")
    print(f"{'='*60}\n")
    
    return True

def download_multiple_symbols():
    """Télécharge plusieurs symboles populaires"""
    
    configurations = [
        # Forex majeurs - 90 jours (disponibles facilement)
        ("EURUSD", "M5", 90),
        ("EURUSD", "H1", 180),
        ("GBPUSD", "M5", 90),
        ("GBPUSD", "H1", 180),
        
        # Indices - données plus limitées
        ("US100.cash", "M5", 30),
        ("US100.cash", "H1", 90),
        
        # Or
        ("XAUUSD", "M5", 60),
        ("XAUUSD", "H1", 120),
    ]
    
    print("\n" + "="*60)
    print("📥 TÉLÉCHARGEMENT MULTIPLE")
    print("="*60)
    print(f"\n📊 {len(configurations)} configurations à télécharger\n")
    
    success_count = 0
    fail_count = 0
    
    for symbol, timeframe, days in configurations:
        if download_recent_data(symbol, timeframe, days):
            success_count += 1
        else:
            fail_count += 1
        print()  # Ligne vide entre chaque téléchargement
    
    print("\n" + "="*60)
    print(f"✅ Réussis: {success_count}/{len(configurations)}")
    print(f"❌ Échecs: {fail_count}/{len(configurations)}")
    print("="*60 + "\n")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Télécharger données MT5")
    parser.add_argument('--symbol', type=str, help='Symbole (ex: EURUSD)')
    parser.add_argument('--timeframe', type=str, help='Timeframe (ex: M5, H1)')
    parser.add_argument('--days', type=int, default=90, help='Jours à télécharger (défaut: 90)')
    parser.add_argument('--batch', action='store_true', help='Télécharger plusieurs symboles')
    
    args = parser.parse_args()
    
    if args.batch:
        download_multiple_symbols()
    elif args.symbol and args.timeframe:
        download_recent_data(args.symbol, args.timeframe, args.days)
    else:
        # Mode interactif
        print("\n📥 Téléchargement de données MT5\n")
        symbol = input("Symbole (ex: EURUSD): ").strip().upper()
        timeframe = input("Timeframe (ex: M5, H1): ").strip().upper()
        days = input("Jours à télécharger (défaut: 90): ").strip()
        days = int(days) if days else 90
        
        download_recent_data(symbol, timeframe, days)

