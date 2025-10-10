"""
Quick Backtest - Test rapide avec configuration simple
"""
from config_simple import get_simple_config
from strategies import FreeCandleStrategy
from backtesting import BacktestEngine, PerformanceMetrics
from data import DataManager
from utils import setup_logger
import pandas as pd


class QuickBacktest:
    """Classe pour gérer le backtest rapide avec configuration unifiée"""
    
    def __init__(self, symbol: str = "USDJPY", timeframe: str = "M3", year: int = 2025):
        """
        Initialise le backtest avec une configuration simple
        
        Args:
            symbol: Symbole à tester
            timeframe: Timeframe à utiliser
            year: Année à backtester
        """
        # Configuration centralisée
        self.config = get_simple_config()
        self.config.symbol.symbol = symbol
        self.config.symbol.timeframe = timeframe
        
        # Paramètres du backtest
        self.year = year
        self.initial_capital = 10000
        self.commission = 0.0002
        
        # Components (initialisés une seule fois)
        self.data_manager = DataManager()
        self.strategy = FreeCandleStrategy(self.config)
        self.engine = BacktestEngine(
            initial_capital=self.initial_capital, 
            commission=self.commission
        )
        
        # Logger
        self.logger = setup_logger('quick_backtest')
        
        # Données
        self.df = None
        self.signals = None
        self.results = None
    
    def load_data(self) -> bool:
        """Charge les données depuis le cache"""
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
        
        print(f"✅ {len(self.df)} barres chargées ({self.year})")
        return True
    
    def generate_signals(self) -> bool:
        """Génère les signaux de trading"""
        print("\n🎯 Génération des signaux...")
        self.signals = self.strategy.generate_signals(self.df)
        
        num_signals = len(self.signals) if self.signals else 0
        print(f"✅ {num_signals} signaux générés")
        
        if num_signals == 0:
            self._display_no_signals_info()
            return False
        
        return True
    
    def run_backtest(self) -> bool:
        """Exécute le backtest"""
        print("\n📈 Exécution du backtest...")
        self.results = self.engine.run_backtest(self.df, self.signals, self.config)
        return True
    
    def display_signals(self, n: int = 5):
        """Affiche les premiers signaux"""
        if not self.signals:
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
        
        print("\n" + "=" * 70)
        print("✅ Backtest terminé !")
        print("=" * 70)
    
    def _display_no_signals_info(self):
        """Affiche des informations de debug si aucun signal"""
        print("\n⚠️  Aucun signal généré!")
        print("\nCela peut être dû à:")
        print("  1. Paramètres Bollinger Bands trop serrés")
        print("  2. Pas de Free Candles dans cette période")
        print("  3. Problème dans le code de détection")
        
        # Afficher des infos sur les données pour aider au debug
        if self.df is not None:
            print("\nℹ️  Infos sur les données:")
            print(f"  Nombre de barres: {len(self.df)}")
            print(f"  Date début: {self.df.index.min()}")
            print(f"  Date fin: {self.df.index.max()}")
            print(f"\n  Close min: {self.df['close'].min():.5f}")
            print(f"  Close max: {self.df['close'].max():.5f}")
            print(f"  Close moyen: {self.df['close'].mean():.5f}")
    
    def run(self):
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


def main():
    """Point d'entrée principal"""
    # Créer et exécuter le backtest avec configuration centralisée
    backtest = QuickBacktest(symbol="EURUSD", timeframe="M3", year=2023)
    backtest.run()


if __name__ == "__main__":
    main()

