"""
Quick Backtest - Test rapide avec configuration simple
"""
from config_simple import get_simple_config
from strategies import FreeCandleStrategy
from backtesting import BacktestEngine, PerformanceMetrics
from data import DataManager
from utils import setup_logger
import pandas as pd

def main():
    # Setup
    logger = setup_logger('quick_backtest')
    
    print("\n" + "=" * 70)
    print("QUICK BACKTEST - Configuration Simple")
    print("=" * 70)
    
    # Configuration simple
    config = get_simple_config()
    config.symbol.symbol = "EURUSD"
    config.symbol.timeframe = "M3"
    
    # Charger données depuis le cache
    print("\n📊 Chargement des données...")
    data_manager = DataManager()
    df = data_manager.load_from_cache("EURUSD", "M3")
    
    if df is None:
        print("❌ Pas de données en cache. Lancez d'abord:")
        print("   python backtest.py --symbol EURUSD --timeframe H1")
        return
    
    # Filtrer 2023
    df = df[(df.index >= '2023-01-01') & (df.index < '2024-01-01')]
    print(f"✅ {len(df)} barres chargées (2023)")
    
    # Stratégie
    print("\n🎯 Génération des signaux...")
    strategy = FreeCandleStrategy(config)
    signals = strategy.generate_signals(df)
    
    # signals est une liste de Signal objects
    num_signals = len(signals) if signals else 0
    print(f"✅ {num_signals} signaux générés")
    
    if num_signals == 0:
        print("\n⚠️  Aucun signal généré!")
        print("\nCela peut être dû à:")
        print("  1. Paramètres Bollinger Bands trop serrés")
        print("  2. Pas de Free Candles dans cette période")
        print("  3. Problème dans le code de détection")
        print("\nVérifiez le code dans strategies/free_candle.py")
        
        # Debug: Afficher quelques stats
        print("\n📊 Statistiques des données:")
        print(f"  Première bougie: {df.index[0]}")
        print(f"  Dernière bougie: {df.index[-1]}")
        print(f"  Total barres: {len(df)}")
        print(f"\n  Close min: {df['close'].min():.5f}")
        print(f"  Close max: {df['close'].max():.5f}")
        print(f"  Close moyen: {df['close'].mean():.5f}")
        return
    
    # Afficher exemples de signaux
    print(f"\n📈 Exemples de signaux (5 premiers):")
    for i, signal in enumerate(signals[:5]):
        signal_type = "BUY" if signal.direction == 1 else "SELL"
        print(f"  {i+1}. {signal.timestamp}: {signal_type} @ {signal.entry_price:.5f} | SL: {signal.sl_price:.5f} | TP: {signal.tp_price:.5f} | RR: {signal.rr_ratio:.2f}")
    
    # Backtest
    print("\n📈 Exécution du backtest...")
    engine = BacktestEngine(initial_capital=10000, commission=0.0002)
    results = engine.run_backtest(df, signals, config)
    
    # Résultats
    print("\n" + "=" * 70)
    print("RÉSULTATS")
    print("=" * 70)
    
    final_equity = results.equity_curve[-1] if len(results.equity_curve) > 0 else 10000
    total_return = ((final_equity / 10000) - 1) * 100
    
    print(f"\n💰 Capital initial: $10,000.00")
    print(f"💰 Capital final: ${final_equity:,.2f}")
    print(f"📊 Rendement total: {total_return:+.2f}%")
    print(f"\n📊 Total trades: {len(results.trades)}")
    
    if len(results.trades) > 0:
        wins = sum(1 for t in results.trades if t.profit > 0)
        losses = sum(1 for t in results.trades if t.profit < 0)
        win_rate = (wins / len(results.trades)) * 100 if len(results.trades) > 0 else 0
        
        total_profit = sum(t.profit for t in results.trades if t.profit > 0)
        total_loss = abs(sum(t.profit for t in results.trades if t.profit < 0))
        profit_factor = total_profit / total_loss if total_loss > 0 else 0
        
        print(f"✅ Trades gagnants: {wins}")
        print(f"❌ Trades perdants: {losses}")
        print(f"📊 Win Rate: {win_rate:.1f}%")
        print(f"📊 Profit Factor: {profit_factor:.2f}")
        
        # Meilleur et pire trade
        best_trade = max(results.trades, key=lambda t: t.profit)
        worst_trade = min(results.trades, key=lambda t: t.profit)
        
        print(f"\n🏆 Meilleur trade: ${best_trade.profit:,.2f}")
        print(f"💀 Pire trade: ${worst_trade.profit:,.2f}")
    
    print("\n" + "=" * 70)
    print("✅ Backtest terminé !")
    print("=" * 70)


if __name__ == "__main__":
    main()

