"""
Quick Backtest CLI - Version avec arguments ligne de commande et menu interactif
"""
from config_simple import get_simple_config
from strategies import FreeCandleStrategy
from backtesting import BacktestEngine
from data import DataManager
from utils import setup_logger
import pandas as pd
import argparse
from typing import Optional, List
import os


class QuickBacktest:
    """Classe pour gérer le backtest rapide avec configuration unifiée"""
    
    def __init__(
        self, 
        symbol: str = "EURUSD", 
        timeframe: str = "M3", 
        year: int = 2023,
        initial_capital: float = 10000,
        commission: float = 0.0002,
        verbose: bool = True
    ):
        """
        Initialise le backtest avec une configuration simple
        
        Args:
            symbol: Symbole à tester
            timeframe: Timeframe à utiliser
            year: Année à backtester
            initial_capital: Capital initial
            commission: Commission par trade
            verbose: Afficher les détails
        """
        # Configuration centralisée (initialisée UNE SEULE fois)
        self.config = get_simple_config()
        self.config.symbol.symbol = symbol
        self.config.symbol.timeframe = timeframe
        
        # Paramètres du backtest
        self.year = year
        self.initial_capital = initial_capital
        self.commission = commission
        self.verbose = verbose
        
        # Composants (initialisés une seule fois avec la config)
        self.data_manager = DataManager()
        self.strategy = FreeCandleStrategy(self.config)  # ✅ Initialisation unique
        self.engine = BacktestEngine(
            initial_capital=self.initial_capital, 
            commission=self.commission
        )
        
        # Logger
        self.logger = setup_logger('quick_backtest')
        
        # Données et résultats
        self.df: Optional[pd.DataFrame] = None
        self.signals: Optional[list] = None
        self.results: Optional[object] = None
    
    def load_data(self) -> bool:
        """Charge les données depuis le cache"""
        if self.verbose:
            print("\n📊 Chargement des données...")
        
        self.df = self.data_manager.load_from_cache(
            self.config.symbol.symbol, 
            self.config.symbol.timeframe
        )
        
        if self.df is None:
            print(f"❌ Pas de données en cache pour {self.config.symbol.symbol} {self.config.symbol.timeframe}")
            print("\n💡 Lancez d'abord:")
            print(f"   python backtest.py --symbol {self.config.symbol.symbol} --timeframe {self.config.symbol.timeframe}")
            return False
        
        # Filtrer par année
        self.df = self.df[
            (self.df.index >= f'{self.year}-01-01') & 
            (self.df.index < f'{self.year + 1}-01-01')
        ]
        
        if self.verbose:
            print(f"✅ {len(self.df)} barres chargées ({self.year})")
        
        return True
    
    def generate_signals(self) -> bool:
        """Génère les signaux de trading"""
        if self.verbose:
            print("\n🎯 Génération des signaux...")
        
        self.signals = self.strategy.generate_signals(self.df)
        
        num_signals = len(self.signals) if self.signals else 0
        
        if self.verbose:
            print(f"✅ {num_signals} signaux générés")
        
        if num_signals == 0:
            if self.verbose:
                self._display_no_signals_info()
            return False
        
        return True
    
    def run_backtest(self) -> bool:
        """Exécute le backtest"""
        if self.verbose:
            print("\n📈 Exécution du backtest...")
        
        self.results = self.engine.run_backtest(
            self.df, 
            self.signals, 
            self.config,
            verbose=self.verbose
        )
        return True
    
    def display_signals(self, n: int = 5):
        """Affiche les premiers signaux"""
        if not self.signals or not self.verbose:
            return
        
        print(f"\n📈 Exemples de signaux ({min(n, len(self.signals))} premiers):")
        for i, signal in enumerate(self.signals[:n]):
            signal_type = "BUY" if signal.direction == 1 else "SELL"
            print(f"  {i+1}. {signal.timestamp}: {signal_type} @ {signal.entry_price:.5f} | "
                  f"SL: {signal.sl_price:.5f} | TP: {signal.tp_price:.5f} | RR: {signal.rr_ratio:.2f}")
    
    def display_results(self):
        """Affiche les résultats du backtest"""
        if not self.results:
            return
        
        if self.verbose:
            print("\n" + "=" * 70)
            print("RÉSULTATS")
            print("=" * 70)
        
        final_equity = self.results.equity_curve[-1] if self.results.equity_curve else self.initial_capital
        total_return = ((final_equity / self.initial_capital) - 1) * 100
        
        print(f"\n💰 Capital initial: ${self.initial_capital:,.2f}")
        print(f"💰 Capital final: ${final_equity:,.2f}")
        print(f"📊 Rendement total: {total_return:+.2f}%")
        print(f"\n📊 Total trades: {len(self.results.trades)}")
        
        if len(self.results.trades) > 0:
            wins = sum(1 for t in self.results.trades if t.profit > 0)
            losses = sum(1 for t in self.results.trades if t.profit < 0)
            win_rate = (wins / len(self.results.trades)) * 100
            
            total_profit = sum(t.profit for t in self.results.trades if t.profit > 0)
            total_loss = abs(sum(t.profit for t in self.results.trades if t.profit < 0))
            profit_factor = total_profit / total_loss if total_loss > 0 else 0
            
            print(f"✅ Trades gagnants: {wins}")
            print(f"❌ Trades perdants: {losses}")
            print(f"📊 Win Rate: {win_rate:.1f}%")
            print(f"📊 Profit Factor: {profit_factor:.2f}")
            
            # Meilleur et pire trade
            best_trade = max(self.results.trades, key=lambda t: t.profit)
            worst_trade = min(self.results.trades, key=lambda t: t.profit)
            
            print(f"\n🏆 Meilleur trade: ${best_trade.profit:,.2f}")
            print(f"💀 Pire trade: ${worst_trade.profit:,.2f}")
        
        if self.verbose:
            print("\n" + "=" * 70)
            print("✅ Backtest terminé !")
            print("=" * 70)
    
    def _display_no_signals_info(self):
        """Affiche des informations de debug si aucun signal"""
        print("\n⚠️  Aucun signal généré!")
        print("\nCela peut être dû à:")
        print("  1. Paramètres Bollinger Bands trop serrés")
        print("  2. Pas de Free Candles dans cette période")
        print("  3. Filtres trop restrictifs")
        
        # Afficher des infos sur les données pour aider au debug
        if self.df is not None:
            print("\nℹ️  Infos sur les données:")
            print(f"  Nombre de barres: {len(self.df)}")
            print(f"  Date début: {self.df.index.min()}")
            print(f"  Date fin: {self.df.index.max()}")
            print(f"\n  Close min: {self.df['close'].min():.5f}")
            print(f"  Close max: {self.df['close'].max():.5f}")
            print(f"  Close moyen: {self.df['close'].mean():.5f}")
    
    def run(self) -> bool:
        """Exécute le workflow complet du backtest"""
        # 1. Charger les données
        if not self.load_data():
            return False
        
        # 2. Générer les signaux
        if not self.generate_signals():
            return False
        
        # 3. Afficher les signaux
        self.display_signals()
        
        # 4. Exécuter le backtest
        if not self.run_backtest():
            return False
        
        # 5. Afficher les résultats
        self.display_results()
        
        return True
    
    def get_summary(self) -> dict:
        """Retourne un résumé des résultats (utile pour comparaisons)"""
        if not self.results:
            return {}
        
        final_equity = self.results.equity_curve[-1] if self.results.equity_curve else self.initial_capital
        
        return {
            'symbol': self.config.symbol.symbol,
            'timeframe': self.config.symbol.timeframe,
            'year': self.year,
            'initial_capital': self.initial_capital,
            'final_capital': final_equity,
            'net_profit': final_equity - self.initial_capital,
            'return_pct': ((final_equity / self.initial_capital) - 1) * 100,
            'total_trades': len(self.results.trades),
            'winning_trades': sum(1 for t in self.results.trades if t.profit > 0),
            'losing_trades': sum(1 for t in self.results.trades if t.profit < 0),
            'win_rate': (sum(1 for t in self.results.trades if t.profit > 0) / len(self.results.trades) * 100) if self.results.trades else 0,
        }


# ========== LISTES DE SYMBOLES ET TIMEFRAMES ==========

AVAILABLE_SYMBOLS = {
    'Forex Majors': ['EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF', 'AUDUSD', 'USDCAD', 'NZDUSD'],
    'Forex Minors': ['EURGBP', 'EURJPY', 'GBPJPY', 'EURCHF', 'AUDJPY', 'CADJPY'],
    'Indices': ['US100.cash', 'US30.cash', 'US500.cash', 'GER40.cash', 'UK100.cash'],
    'Commodities': ['XAUUSD', 'XAGUSD', 'USOIL', 'UKOIL'],
    'Crypto': ['BTCUSD', 'ETHUSD', 'LTCUSD', 'XRPUSD']
}

AVAILABLE_TIMEFRAMES = {
    'Ultra-Court': ['M1', 'M3', 'M5'],
    'Court Terme': ['M15', 'M30'],
    'Moyen Terme': ['H1', 'H4'],
    'Long Terme': ['D1', 'W1', 'MN1']
}


def display_menu_symbols() -> str:
    """Affiche le menu de sélection de symboles"""
    print("\n" + "=" * 70)
    print("📊 SÉLECTION DU SYMBOLE")
    print("=" * 70)
    
    all_symbols = []
    category_idx = 1
    
    for category, symbols in AVAILABLE_SYMBOLS.items():
        print(f"\n{category_idx}. {category}:")
        for i, symbol in enumerate(symbols, 1):
            symbol_idx = len(all_symbols) + 1
            all_symbols.append(symbol)
            print(f"   {symbol_idx}. {symbol}")
        category_idx += 1
    
    print(f"\n0. Entrer un symbole personnalisé")
    print("=" * 70)
    
    while True:
        try:
            choice = input("\nChoisissez un symbole (numéro ou 0 pour custom): ").strip()
            
            if choice == '0':
                custom = input("Entrez le symbole: ").strip().upper()
                return custom
            
            choice_num = int(choice)
            if 1 <= choice_num <= len(all_symbols):
                return all_symbols[choice_num - 1]
            else:
                print(f"❌ Choix invalide. Choisissez entre 1 et {len(all_symbols)}")
        except ValueError:
            print("❌ Veuillez entrer un numéro valide")


def display_menu_timeframes() -> str:
    """Affiche le menu de sélection de timeframes"""
    print("\n" + "=" * 70)
    print("⏰ SÉLECTION DU TIMEFRAME")
    print("=" * 70)
    
    all_timeframes = []
    
    for category, timeframes in AVAILABLE_TIMEFRAMES.items():
        print(f"\n{category}:")
        for tf in timeframes:
            tf_idx = len(all_timeframes) + 1
            all_timeframes.append(tf)
            print(f"   {tf_idx}. {tf}")
    
    print("=" * 70)
    
    while True:
        try:
            choice = input("\nChoisissez un timeframe (numéro): ").strip()
            choice_num = int(choice)
            
            if 1 <= choice_num <= len(all_timeframes):
                return all_timeframes[choice_num - 1]
            else:
                print(f"❌ Choix invalide. Choisissez entre 1 et {len(all_timeframes)}")
        except ValueError:
            print("❌ Veuillez entrer un numéro valide")


def display_menu_years() -> int:
    """Affiche le menu de sélection d'année"""
    print("\n" + "=" * 70)
    print("📅 SÉLECTION DE L'ANNÉE")
    print("=" * 70)
    
    current_year = 2025
    available_years = list(range(2020, current_year + 1))
    
    print("\nAnnées disponibles:")
    for i, year in enumerate(available_years, 1):
        print(f"   {i}. {year}")
    
    print("=" * 70)
    
    while True:
        try:
            choice = input("\nChoisissez une année (numéro): ").strip()
            choice_num = int(choice)
            
            if 1 <= choice_num <= len(available_years):
                return available_years[choice_num - 1]
            else:
                print(f"❌ Choix invalide. Choisissez entre 1 et {len(available_years)}")
        except ValueError:
            print("❌ Veuillez entrer un numéro valide")


def interactive_mode() -> dict:
    """Mode interactif avec menus"""
    print("\n" + "=" * 70)
    print("🎯 MODE INTERACTIF - QUICK BACKTEST")
    print("=" * 70)
    
    # Sélection du symbole
    symbol = display_menu_symbols()
    
    # Sélection du timeframe
    timeframe = display_menu_timeframes()
    
    # Sélection de l'année
    year = display_menu_years()
    
    # Capital
    print("\n" + "=" * 70)
    print("💰 CAPITAL INITIAL")
    print("=" * 70)
    capital_input = input("\nCapital initial (défaut: 10000): ").strip()
    capital = float(capital_input) if capital_input else 10000
    
    # Commission
    print("\n" + "=" * 70)
    print("💳 COMMISSION")
    print("=" * 70)
    print("Exemples: 0.0002 (0.02%), 0.0001 (0.01%), 0.0005 (0.05%)")
    commission_input = input("\nCommission par trade (défaut: 0.0002): ").strip()
    commission = float(commission_input) if commission_input else 0.0002
    
    return {
        'symbol': symbol,
        'timeframe': timeframe,
        'year': year,
        'capital': capital,
        'commission': commission
    }


def batch_mode(symbols: List[str], timeframes: List[str], years: List[int]) -> List[dict]:
    """Mode batch pour tester plusieurs configurations"""
    print("\n" + "=" * 70)
    print("🔄 MODE BATCH - BACKTESTS MULTIPLES")
    print("=" * 70)
    
    results = []
    total_tests = len(symbols) * len(timeframes) * len(years)
    
    print(f"\n📊 {total_tests} backtests à exécuter")
    print(f"   Symboles: {', '.join(symbols)}")
    print(f"   Timeframes: {', '.join(timeframes)}")
    print(f"   Années: {', '.join(map(str, years))}")
    
    confirm = input("\n▶️  Continuer ? (o/n): ").strip().lower()
    if confirm not in ['o', 'y', 'oui', 'yes']:
        print("❌ Annulé")
        return []
    
    current = 0
    for symbol in symbols:
        for timeframe in timeframes:
            for year in years:
                current += 1
                print(f"\n{'='*70}")
                print(f"📊 Test {current}/{total_tests}: {symbol} {timeframe} {year}")
                print(f"{'='*70}")
                
                backtest = QuickBacktest(
                    symbol=symbol,
                    timeframe=timeframe,
                    year=year,
                    verbose=False  # Mode silencieux pour batch
                )
                
                if backtest.run():
                    summary = backtest.get_summary()
                    results.append(summary)
                    
                    # Afficher résumé compact
                    print(f"✅ Profit: ${summary['net_profit']:+,.2f} ({summary['return_pct']:+.2f}%) | "
                          f"Trades: {summary['total_trades']} | Win Rate: {summary['win_rate']:.1f}%")
                else:
                    print(f"❌ Échec (pas de données ou signaux)")
    
    return results


def display_batch_comparison(results: List[dict]):
    """Affiche la comparaison des résultats batch"""
    if not results:
        return
    
    print("\n" + "=" * 70)
    print("📊 COMPARAISON DES RÉSULTATS")
    print("=" * 70)
    
    # Créer un DataFrame pour l'affichage
    df_results = pd.DataFrame(results)
    
    # Trier par profit
    df_results = df_results.sort_values('return_pct', ascending=False)
    
    print("\n🏆 CLASSEMENT PAR PERFORMANCE:")
    print("-" * 70)
    
    for i, row in df_results.iterrows():
        print(f"{i+1}. {row['symbol']:12} {row['timeframe']:4} {row['year']} | "
              f"Return: {row['return_pct']:+7.2f}% | "
              f"Trades: {row['total_trades']:3} | "
              f"Win Rate: {row['win_rate']:5.1f}%")
    
    print("\n" + "=" * 70)
    print("📈 STATISTIQUES GLOBALES:")
    print("-" * 70)
    print(f"Total backtests: {len(results)}")
    print(f"Rentables: {sum(1 for r in results if r['net_profit'] > 0)}")
    print(f"Perdants: {sum(1 for r in results if r['net_profit'] < 0)}")
    print(f"\nMeilleure performance: {df_results.iloc[0]['symbol']} {df_results.iloc[0]['timeframe']} "
          f"({df_results.iloc[0]['return_pct']:+.2f}%)")
    print(f"Pire performance: {df_results.iloc[-1]['symbol']} {df_results.iloc[-1]['timeframe']} "
          f"({df_results.iloc[-1]['return_pct']:+.2f}%)")
    print(f"\nReturn moyen: {df_results['return_pct'].mean():+.2f}%")
    print(f"Win rate moyen: {df_results['win_rate'].mean():.1f}%")
    print("=" * 70)


def check_available_data() -> List[tuple]:
    """Vérifie quelles données sont disponibles en cache"""
    cache_dir = "data_cache"
    available = []
    
    if not os.path.exists(cache_dir):
        return available
    
    for filename in os.listdir(cache_dir):
        if filename.endswith('.pkl'):
            # Format: SYMBOL_TIMEFRAME.pkl
            parts = filename.replace('.pkl', '').split('_')
            if len(parts) == 2:
                symbol, timeframe = parts
                available.append((symbol, timeframe))
    
    return available


def display_available_data():
    """Affiche les données disponibles en cache"""
    print("\n" + "=" * 70)
    print("💾 DONNÉES DISPONIBLES EN CACHE")
    print("=" * 70)
    
    available = check_available_data()
    
    if not available:
        print("\n❌ Aucune donnée en cache")
        print("\n💡 Téléchargez des données avec:")
        print("   python backtest.py --symbol EURUSD --timeframe M3")
        return
    
    print(f"\n✅ {len(available)} datasets disponibles:\n")
    
    for i, (symbol, timeframe) in enumerate(sorted(available), 1):
        print(f"   {i}. {symbol:15} {timeframe:5}")
    
    print("=" * 70)


def main():
    """Point d'entrée principal avec arguments CLI et menu interactif"""
    parser = argparse.ArgumentParser(
        description='Quick Backtest - Test rapide avec configuration simple',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modes d'utilisation:
  1. Mode CLI (arguments):
     python quick_backtest_cli.py --symbol EURUSD --timeframe M3 --year 2023
  
  2. Mode interactif (menu):
     python quick_backtest_cli.py --interactive
  
  3. Mode batch (plusieurs symboles):
     python quick_backtest_cli.py --batch
  
  4. Lister les données disponibles:
     python quick_backtest_cli.py --list

Exemples CLI:
  python quick_backtest_cli.py --symbol GBPUSD --timeframe H1 --year 2022
  python quick_backtest_cli.py --symbol US100.cash --capital 20000
  python quick_backtest_cli.py --quiet
        """
    )
    
    # Mode de fonctionnement
    parser.add_argument(
        '--interactive', '-i',
        action='store_true',
        help='Mode interactif avec menus'
    )
    
    parser.add_argument(
        '--batch', '-b',
        action='store_true',
        help='Mode batch pour tester plusieurs configurations'
    )
    
    parser.add_argument(
        '--list', '-l',
        action='store_true',
        help='Lister les données disponibles en cache'
    )
    
    # Paramètres de backtest
    parser.add_argument(
        '--symbol', 
        type=str, 
        default='EURUSD',
        help='Symbole à backtester (défaut: EURUSD)'
    )
    
    parser.add_argument(
        '--timeframe', 
        type=str, 
        default='M3',
        help='Timeframe (M1, M3, M5, H1, etc.) (défaut: M3)'
    )
    
    parser.add_argument(
        '--year', 
        type=int, 
        default=2023,
        help='Année à backtester (défaut: 2023)'
    )
    
    parser.add_argument(
        '--capital', 
        type=float, 
        default=10000,
        help='Capital initial (défaut: 10000)'
    )
    
    parser.add_argument(
        '--commission', 
        type=float, 
        default=0.0002,
        help='Commission par trade (défaut: 0.0002)'
    )
    
    parser.add_argument(
        '--quiet', '-q',
        action='store_true',
        help='Mode silencieux (moins de détails)'
    )
    
    args = parser.parse_args()
    
    # Mode liste
    if args.list:
        display_available_data()
        return
    
    # Mode batch
    if args.batch:
        print("\n" + "=" * 70)
        print("🔄 MODE BATCH - Configuration")
        print("=" * 70)
        
        # Menu pour sélectionner plusieurs symboles
        print("\n📊 Sélection des symboles (séparés par des virgules):")
        print("Exemples: EURUSD,GBPUSD,USDJPY ou tapez 'all' pour tous les Forex majors")
        
        symbols_input = input("\nSymboles: ").strip()
        if symbols_input.lower() == 'all':
            symbols = AVAILABLE_SYMBOLS['Forex Majors']
        else:
            symbols = [s.strip().upper() for s in symbols_input.split(',')]
        
        print(f"\n⏰ Sélection des timeframes (séparés par des virgules):")
        print("Exemples: M3,H1,D1 ou tapez 'all' pour M3,H1")
        
        timeframes_input = input("\nTimeframes: ").strip()
        if timeframes_input.lower() == 'all':
            timeframes = ['M3', 'H1']
        else:
            timeframes = [tf.strip().upper() for tf in timeframes_input.split(',')]
        
        print(f"\n📅 Sélection des années (séparées par des virgules):")
        print("Exemples: 2023,2024 ou tapez '2023' pour une seule année")
        
        years_input = input("\nAnnées: ").strip()
        years = [int(y.strip()) for y in years_input.split(',')]
        
        # Exécuter batch
        results = batch_mode(symbols, timeframes, years)
        
        # Afficher comparaison
        if results:
            display_batch_comparison(results)
            
            # Proposer sauvegarde
            save = input("\n💾 Sauvegarder les résultats en CSV ? (o/n): ").strip().lower()
            if save in ['o', 'y', 'oui', 'yes']:
                filename = f"batch_results_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.csv"
                df_results = pd.DataFrame(results)
                df_results.to_csv(filename, index=False)
                print(f"✅ Résultats sauvegardés: {filename}")
        
        return
    
    # Mode interactif
    if args.interactive:
        params = interactive_mode()
        
        # Créer le backtest avec les paramètres du menu
        backtest = QuickBacktest(
            symbol=params['symbol'],
            timeframe=params['timeframe'],
            year=params['year'],
            initial_capital=params['capital'],
            commission=params['commission'],
            verbose=True
        )
    else:
        # Mode CLI classique
        print("\n" + "=" * 70)
        print("QUICK BACKTEST - Configuration Simple")
        print("=" * 70)
        print(f"\n🎯 Paramètres:")
        print(f"   Symbole: {args.symbol}")
        print(f"   Timeframe: {args.timeframe}")
        print(f"   Année: {args.year}")
        print(f"   Capital: ${args.capital:,.2f}")
        print(f"   Commission: {args.commission:.4f}")
        
        backtest = QuickBacktest(
            symbol=args.symbol,
            timeframe=args.timeframe,
            year=args.year,
            initial_capital=args.capital,
            commission=args.commission,
            verbose=not args.quiet
        )
    
    # Exécuter le backtest
    success = backtest.run()
    
    if success and not args.quiet:
        # Afficher le résumé structuré
        summary = backtest.get_summary()
        print(f"\n📊 Résumé exportable:")
        for key, value in summary.items():
            print(f"   {key}: {value}")


if __name__ == "__main__":
    main()

