"""
Main Entry Point
Point d'entrée principal du framework de trading
"""

import sys
import os
from datetime import datetime

# Ajouter le répertoire parent au path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import StrategyConfig, get_conservative_config, get_aggressive_config
from utils import setup_logger


def print_banner():
    """Affiche le banner du programme"""
    banner = r"""
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║     ██╗████████╗██████╗  █████╗ ██████╗ ██╗███╗   ██╗ ██████╗       ║
║     ██║╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██║████╗  ██║██╔════╝       ║
║     ██║   ██║   ██████╔╝███████║██║  ██║██║██╔██╗ ██║██║  ███╗      ║
║██   ██║   ██║   ██╔══██╗██╔══██║██║  ██║██║██║╚██╗██║██║   ██║      ║
║╚█████╔╝   ██║   ██║  ██║██║  ██║██████╔╝██║██║ ╚████║╚██████╔╝      ║
║ ╚════╝    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝       ║
║                                                                       ║
║                 Free Candle Strategy - Python Framework              ║
║                        Version 1.0 - 2025                            ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
"""
    print(banner)


def print_menu():
    """Affiche le menu principal"""
    print("\n" + "=" * 70)
    print("MENU PRINCIPAL".center(70))
    print("=" * 70)
    print("\n1. 📊 Backtest Strategy")
    print("2. 🤖 Live Trading (MT5)")
    print("3. 📈 Analyze Results")
    print("4. ⚙️  Configuration")
    print("5. 📚 Documentation")
    print("0. ❌ Quit")
    print("\n" + "=" * 70)


def run_backtest():
    """Lance un backtest"""
    print("\n" + "=" * 70)
    print("BACKTEST MODE".center(70))
    print("=" * 70)
    
    # Demander les paramètres
    symbol = input("\nSymbol [EURUSD]: ").strip() or "EURUSD"
    timeframe = input("Timeframe [H1]: ").strip() or "H1"
    start_date = input("Start Date [2023-01-01]: ").strip() or "2023-01-01"
    end_date = input("End Date [2024-12-31]: ").strip() or "2024-12-31"
    
    print("\nConfiguration:")
    print("1. Default")
    print("2. Conservative")
    print("3. Aggressive")
    config_choice = input("Choice [1]: ").strip() or "1"
    
    config_map = {
        "1": "default",
        "2": "conservative",
        "3": "aggressive"
    }
    config = config_map.get(config_choice, "default")
    
    generate_plots = input("\nGenerate plots? [y/N]: ").strip().lower() == 'y'
    save_report = input("Save report? [y/N]: ").strip().lower() == 'y'
    
    # Construire la commande
    cmd = f"python backtest.py --symbol {symbol} --timeframe {timeframe} "
    cmd += f"--start-date {start_date} --end-date {end_date} --config {config}"
    
    if generate_plots:
        cmd += " --plot"
    if save_report:
        cmd += " --save-report"
    
    print(f"\n🚀 Lancement du backtest...")
    print(f"Command: {cmd}\n")
    
    os.system(cmd)
    
    input("\nPress Enter to continue...")


def run_live_trading():
    """Lance le trading live"""
    print("\n" + "=" * 70)
    print("LIVE TRADING MODE".center(70))
    print("=" * 70)
    print("\n⚠️  WARNING: This will trade with real money!")
    print("Make sure you understand the risks before proceeding.\n")
    
    confirm = input("Do you want to continue? [y/N]: ").strip().lower()
    
    if confirm != 'y':
        print("Cancelled.")
        return
    
    # Demander les paramètres
    symbol = input("\nSymbol [EURUSD]: ").strip() or "EURUSD"
    timeframe = input("Timeframe [H1]: ").strip() or "H1"
    risk = input("Risk per trade (%) [0.1]: ").strip() or "0.1"
    
    print("\nMT5 Connection:")
    login = input("Login: ").strip()
    password = input("Password: ").strip()
    server = input("Server: ").strip()
    
    if not all([login, password, server]):
        print("❌ Missing credentials. Cancelled.")
        return
    
    # Construire la commande
    cmd = f"python live_trade.py --symbol {symbol} --timeframe {timeframe} "
    cmd += f"--risk {risk} --login {login} --password {password} --server {server}"
    
    print(f"\n🚀 Lancement du trading live...")
    print(f"Command: {cmd}\n")
    
    os.system(cmd)
    
    input("\nPress Enter to continue...")


def analyze_results():
    """Analyse des résultats"""
    print("\n" + "=" * 70)
    print("ANALYSIS MODE".center(70))
    print("=" * 70)
    
    print("\nThis feature allows you to analyze backtest results.")
    print("Implementation: Load a backtest results file and generate analysis.\n")
    
    results_file = input("Results file path: ").strip()
    
    if not results_file or not os.path.exists(results_file):
        print("❌ File not found.")
        return
    
    print(f"\n📊 Analyzing {results_file}...")
    print("(Feature to be implemented)")
    
    input("\nPress Enter to continue...")


def show_configuration():
    """Affiche et permet de modifier la configuration"""
    print("\n" + "=" * 70)
    print("CONFIGURATION".center(70))
    print("=" * 70)
    
    config = StrategyConfig()
    
    print("\nCurrent Configuration:")
    print(f"  Symbol: {config.symbol.symbol}")
    print(f"  Timeframe: {config.symbol.timeframe}")
    print(f"  BB Period: {config.bollinger.period}")
    print(f"  RSI Period: {config.rsi.period}")
    print(f"  RSI Oversold: {config.rsi.oversold}")
    print(f"  RSI Overbought: {config.rsi.overbought}")
    print(f"  EMA Fast: {config.ema.fast_period}")
    print(f"  EMA Slow: {config.ema.slow_period}")
    print(f"  Risk per trade: {config.money_management.risk_percent}%")
    print(f"  Min RR: {config.stop_loss.min_rr}")
    
    print("\nPresets:")
    print("1. Save current config to YAML")
    print("2. Load config from YAML")
    print("3. Reset to default")
    
    choice = input("\nChoice [0 to cancel]: ").strip()
    
    if choice == "1":
        filename = input("Filename [config.yaml]: ").strip() or "config.yaml"
        config.save_to_yaml(filename)
        print(f"✅ Configuration saved to {filename}")
    elif choice == "2":
        filename = input("Filename: ").strip()
        if os.path.exists(filename):
            config = StrategyConfig.load_from_yaml(filename)
            print(f"✅ Configuration loaded from {filename}")
        else:
            print("❌ File not found.")
    elif choice == "3":
        config = StrategyConfig()
        print("✅ Configuration reset to default")
    
    input("\nPress Enter to continue...")


def show_documentation():
    """Affiche la documentation"""
    print("\n" + "=" * 70)
    print("DOCUMENTATION".center(70))
    print("=" * 70)
    
    print("""
📚 JTrading Python Framework - Documentation

OVERVIEW:
  This framework converts the MQL5 JTFreeCandle Expert Advisor to Python.
  It provides backtesting, live trading, and analysis capabilities.

FEATURES:
  ✓ Free Candle detection (Bollinger Bands)
  ✓ RSI filter
  ✓ EMA filter (3 modes: TREND, COUNTER, ZONE)
  ✓ Divergence validator
  ✓ Advanced money management
  ✓ Comprehensive backtesting engine
  ✓ Live trading via MT5 API
  ✓ Performance analysis & visualization

USAGE:

  Backtest:
    python backtest.py --symbol EURUSD --timeframe H1 --plot

  Live Trading:
    python live_trade.py --symbol EURUSD --risk 0.1 --login XXX --password XXX --server XXX

  Custom Script:
    from config import StrategyConfig
    from strategies import FreeCandleStrategy
    from backtesting import BacktestEngine
    
    config = StrategyConfig()
    strategy = FreeCandleStrategy(config)
    engine = BacktestEngine(initial_capital=10000)
    
    signals = strategy.generate_signals(df)
    results = engine.run_backtest(df, signals, config)

FILES:
  README.md - Full documentation
  requirements.txt - Dependencies
  config/ - Configuration files
  indicators/ - Technical indicators
  strategies/ - Trading strategies
  backtesting/ - Backtest engine
  live_trading/ - MT5 integration
  analysis/ - Performance analysis

For more details, see README.md
""")
    
    input("\nPress Enter to continue...")


def main():
    """Fonction principale"""
    logger = setup_logger('main', log_file='logs/main.log')
    
    while True:
        os.system('cls' if os.name == 'nt' else 'clear')
        print_banner()
        print_menu()
        
        choice = input("\nYour choice: ").strip()
        
        if choice == '0':
            print("\n👋 Goodbye!")
            sys.exit(0)
        elif choice == '1':
            run_backtest()
        elif choice == '2':
            run_live_trading()
        elif choice == '3':
            analyze_results()
        elif choice == '4':
            show_configuration()
        elif choice == '5':
            show_documentation()
        else:
            print("\n❌ Invalid choice. Please try again.")
            input("\nPress Enter to continue...")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 Interrupted by user. Goodbye!")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

