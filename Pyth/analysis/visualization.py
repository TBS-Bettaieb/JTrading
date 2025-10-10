"""
Visualizer
Création de graphiques et visualisations
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from typing import List, Optional, Tuple
from datetime import datetime
import os

from backtesting import BacktestResults, Trade


class Visualizer:
    """
    Créateur de visualisations pour les résultats de trading
    
    Génère:
    - Courbe d'equity
    - Courbe de drawdown
    - Distribution des profits
    - Performance par heure/jour
    - Heatmaps
    """
    
    def __init__(self, style: str = 'seaborn-v0_8-darkgrid'):
        """
        Args:
            style: Style matplotlib
        """
        try:
            plt.style.use(style)
        except:
            plt.style.use('default')
        
        # Configuration seaborn
        sns.set_palette("husl")
        
        self.figsize = (14, 8)

    def _align_xy(self, x, y):
        """Ensure x and y have the same length by trimming the longer one.
        Matplotlib requires equal-length sequences; engine results may differ by 1.
        """
        if x is None or y is None:
            return x, y
        len_x = len(x)
        len_y = len(y)
        if len_x == len_y:
            return x, y
        n = min(len_x, len_y)
        return x[:n], y[:n]
    
    def plot_equity_curve(
        self,
        results: BacktestResults,
        save_path: Optional[str] = None,
        show: bool = True
    ):
        """
        Trace la courbe d'equity
        
        Args:
            results: Résultats du backtest
            save_path: Chemin de sauvegarde (optionnel)
            show: Afficher le graphique
        """
        if not results.equity_curve or not results.timestamps:
            print("❌ Pas de données d'equity")
            return
        
        fig, ax = plt.subplots(figsize=self.figsize)

        x, y = self._align_xy(list(results.timestamps), list(results.equity_curve))
        ax.plot(x, y, linewidth=2, label='Equity')
        ax.axhline(y=results.initial_capital, color='gray', linestyle='--', label='Initial Capital')
        
        ax.set_title('Equity Curve', fontsize=16, fontweight='bold')
        ax.set_xlabel('Time')
        ax.set_ylabel('Equity ($)')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        # Format y-axis avec virgules
        ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"✅ Graphique sauvegardé: {save_path}")
        
        if show:
            plt.show()
        else:
            plt.close()
    
    def plot_drawdown(
        self,
        results: BacktestResults,
        save_path: Optional[str] = None,
        show: bool = True
    ):
        """
        Trace la courbe de drawdown
        """
        if not results.drawdown_curve or not results.timestamps:
            print("❌ Pas de données de drawdown")
            return
        
        fig, ax = plt.subplots(figsize=self.figsize)
        x, y = self._align_xy(list(results.timestamps), list(results.drawdown_curve))
        ax.fill_between(x, y, 0, 
                        color='red', alpha=0.3, label='Drawdown')
        ax.plot(x, y, color='red', linewidth=1)
        
        ax.set_title('Drawdown Curve', fontsize=16, fontweight='bold')
        ax.set_xlabel('Time')
        ax.set_ylabel('Drawdown ($)')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"✅ Graphique sauvegardé: {save_path}")
        
        if show:
            plt.show()
        else:
            plt.close()
    
    def plot_profit_distribution(
        self,
        results: BacktestResults,
        save_path: Optional[str] = None,
        show: bool = True
    ):
        """
        Trace la distribution des profits
        """
        if not results.trades:
            print("❌ Pas de trades")
            return
        
        profits = [t.profit for t in results.trades]
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=self.figsize)
        
        # Histogramme
        ax1.hist(profits, bins=30, color='steelblue', alpha=0.7, edgecolor='black')
        ax1.axvline(x=0, color='red', linestyle='--', linewidth=2, label='Break Even')
        ax1.axvline(x=np.mean(profits), color='green', linestyle='--', linewidth=2, label=f'Mean: ${np.mean(profits):.2f}')
        ax1.set_title('Profit Distribution', fontweight='bold')
        ax1.set_xlabel('Profit ($)')
        ax1.set_ylabel('Frequency')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Box plot
        ax2.boxplot(profits, vert=True)
        ax2.set_title('Profit Box Plot', fontweight='bold')
        ax2.set_ylabel('Profit ($)')
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"✅ Graphique sauvegardé: {save_path}")
        
        if show:
            plt.show()
        else:
            plt.close()
    
    def plot_monthly_returns(
        self,
        results: BacktestResults,
        save_path: Optional[str] = None,
        show: bool = True
    ):
        """
        Trace les rendements mensuels
        """
        if not results.equity_curve or not results.timestamps:
            print("❌ Pas de données d'equity")
            return
        
        # Créer série temporelle
        x, y = self._align_xy(list(results.timestamps), list(results.equity_curve))
        equity_series = pd.Series(y, index=pd.to_datetime(x))
        
        # Resample par mois
        monthly = equity_series.resample('M').last()
        returns = monthly.pct_change() * 100
        returns = returns.dropna()
        
        if len(returns) == 0:
            print("❌ Pas assez de données pour les rendements mensuels")
            return
        
        fig, ax = plt.subplots(figsize=self.figsize)
        
        colors = ['green' if x > 0 else 'red' for x in returns]
        ax.bar(range(len(returns)), returns, color=colors, alpha=0.7)
        
        ax.set_title('Monthly Returns', fontsize=16, fontweight='bold')
        ax.set_xlabel('Month')
        ax.set_ylabel('Return (%)')
        ax.axhline(y=0, color='black', linestyle='-', linewidth=1)
        ax.grid(True, alpha=0.3)
        
        # Labels des mois
        ax.set_xticks(range(len(returns)))
        ax.set_xticklabels([d.strftime('%Y-%m') for d in returns.index], rotation=45)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"✅ Graphique sauvegardé: {save_path}")
        
        if show:
            plt.show()
        else:
            plt.close()
    
    def plot_hour_heatmap(
        self,
        results: BacktestResults,
        save_path: Optional[str] = None,
        show: bool = True
    ):
        """
        Crée une heatmap de performance par heure et jour
        """
        if not results.trades:
            print("❌ Pas de trades")
            return
        
        # Créer matrice heure x jour
        data = np.zeros((7, 24))  # 7 jours x 24 heures
        counts = np.zeros((7, 24))
        
        for trade in results.trades:
            day = trade.entry_time.weekday()
            hour = trade.entry_time.hour
            data[day, hour] += trade.profit
            counts[day, hour] += 1
        
        # Moyenne par cellule
        with np.errstate(divide='ignore', invalid='ignore'):
            avg_data = np.where(counts > 0, data / counts, 0)
        
        # Créer heatmap
        fig, ax = plt.subplots(figsize=(16, 8))
        
        days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        
        sns.heatmap(avg_data, annot=False, fmt='.0f', cmap='RdYlGn', center=0,
                   xticklabels=[f'{h:02d}:00' for h in range(24)],
                   yticklabels=days,
                   cbar_kws={'label': 'Avg Profit ($)'},
                   ax=ax)
        
        ax.set_title('Performance Heatmap (Hour x Day)', fontsize=16, fontweight='bold')
        ax.set_xlabel('Hour of Day')
        ax.set_ylabel('Day of Week')
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"✅ Graphique sauvegardé: {save_path}")
        
        if show:
            plt.show()
        else:
            plt.close()
    
    def create_dashboard(
        self,
        results: BacktestResults,
        save_path: Optional[str] = None,
        show: bool = True
    ):
        """
        Crée un dashboard complet
        """
        fig = plt.figure(figsize=(20, 12))
        gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
        
        # Equity curve
        ax1 = fig.add_subplot(gs[0, :])
        x, y = self._align_xy(list(results.timestamps), list(results.equity_curve))
        ax1.plot(x, y, linewidth=2, label='Equity')
        ax1.axhline(y=results.initial_capital, color='gray', linestyle='--')
        ax1.set_title('Equity Curve', fontweight='bold')
        ax1.set_ylabel('Equity ($)')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Drawdown
        ax2 = fig.add_subplot(gs[1, :])
        x2, y2 = self._align_xy(list(results.timestamps), list(results.drawdown_curve))
        ax2.fill_between(x2, y2, 0, color='red', alpha=0.3)
        ax2.set_title('Drawdown', fontweight='bold')
        ax2.set_ylabel('Drawdown ($)')
        ax2.grid(True, alpha=0.3)
        
        # Distribution
        ax3 = fig.add_subplot(gs[2, 0])
        profits = [t.profit for t in results.trades]
        ax3.hist(profits, bins=30, color='steelblue', alpha=0.7, edgecolor='black')
        ax3.axvline(x=0, color='red', linestyle='--')
        ax3.set_title('Profit Distribution', fontweight='bold')
        ax3.set_xlabel('Profit ($)')
        
        # Stats
        ax4 = fig.add_subplot(gs[2, 1])
        ax4.axis('off')
        stats_text = f"""
        Total Trades: {results.total_trades}
        Win Rate: {results.win_rate:.1f}%
        Profit Factor: {results.profit_factor:.2f}
        
        Net Profit: ${results.net_profit:,.2f}
        Return: {results.total_return_pct:.1f}%
        Max DD: ${results.max_drawdown:,.2f}
        
        Sharpe: {results.sharpe_ratio:.2f}
        Avg RR: 1:{results.avg_rr:.2f}
        """
        ax4.text(0.1, 0.5, stats_text, fontsize=12, verticalalignment='center',
                family='monospace')
        
        # Win/Loss pie
        ax5 = fig.add_subplot(gs[2, 2])
        sizes = [results.winning_trades, results.losing_trades]
        colors = ['green', 'red']
        labels = [f'Wins\n{results.winning_trades}', f'Losses\n{results.losing_trades}']
        ax5.pie(sizes, labels=labels, colors=colors, autopct='%1.1f%%', startangle=90)
        ax5.set_title('Win/Loss Ratio', fontweight='bold')
        
        plt.suptitle('Trading Performance Dashboard', fontsize=18, fontweight='bold')
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"✅ Dashboard sauvegardé: {save_path}")
        
        if show:
            plt.show()
        else:
            plt.close()


if __name__ == "__main__":
    # Test du visualizer
    from backtesting import BacktestResults, Trade
    
    # Mock results
    results = BacktestResults()
    results.total_trades = 100
    results.winning_trades = 60
    results.losing_trades = 40
    results.win_rate = 60.0
    results.profit_factor = 1.5
    results.net_profit = 5000
    results.total_return_pct = 50.0
    results.initial_capital = 10000
    results.max_drawdown = 1500
    results.sharpe_ratio = 1.2
    results.avg_rr = 1.5
    
    # Mock equity curve
    np.random.seed(42)
    equity = [10000]
    for i in range(1000):
        equity.append(equity[-1] + np.random.randn() * 50)
    
    results.equity_curve = equity
    results.timestamps = pd.date_range('2024-01-01', periods=len(equity), freq='H')
    
    # Mock drawdown
    peak = equity[0]
    dd = []
    for e in equity:
        if e > peak:
            peak = e
        dd.append(e - peak)
    results.drawdown_curve = dd
    
    # Mock trades
    for i in range(100):
        trade = Trade(
            entry_time=datetime(2024, 1, 1) + pd.Timedelta(hours=i*10),
            exit_time=datetime(2024, 1, 1) + pd.Timedelta(hours=i*10+5),
            profit=np.random.randn() * 100,
        )
        results.trades.append(trade)
    
    # Créer visualisations
    viz = Visualizer()
    
    print("📊 Création des visualisations...")
    viz.plot_equity_curve(results, save_path='equity_curve.png', show=False)
    viz.plot_drawdown(results, save_path='drawdown.png', show=False)
    viz.plot_profit_distribution(results, save_path='profit_dist.png', show=False)
    viz.create_dashboard(results, save_path='dashboard.png', show=False)
    
    print("\n✅ Visualisations créées avec succès!")

