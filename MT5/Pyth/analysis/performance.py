"""
Performance Analyzer
Analyse approfondie des performances de trading
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional
from datetime import datetime

from backtesting import BacktestResults, Trade


class PerformanceAnalyzer:
    """
    Analyseur de performance
    
    Fournit des analyses avancées:
    - Distribution des trades
    - Analyse temporelle
    - Corrélations
    - Patterns de performance
    """
    
    def __init__(self, results: Optional[BacktestResults] = None):
        """
        Args:
            results: Résultats de backtest à analyser
        """
        self.results = results
    
    def analyze_trade_distribution(self) -> Dict[str, Any]:
        """
        Analyse la distribution des profits/pertes
        
        Returns:
            Dict avec stats de distribution
        """
        if not self.results or not self.results.trades:
            return {}
        
        profits = [t.profit for t in self.results.trades]
        
        return {
            'mean': np.mean(profits),
            'median': np.median(profits),
            'std': np.std(profits),
            'min': min(profits),
            'max': max(profits),
            'q25': np.percentile(profits, 25),
            'q75': np.percentile(profits, 75),
            'skewness': pd.Series(profits).skew(),
            'kurtosis': pd.Series(profits).kurtosis()
        }
    
    def analyze_by_hour(self) -> pd.DataFrame:
        """
        Analyse la performance par heure de la journée
        """
        if not self.results or not self.results.trades:
            return pd.DataFrame()
        
        data = []
        for trade in self.results.trades:
            data.append({
                'hour': trade.entry_time.hour,
                'profit': trade.profit,
                'is_win': 1 if trade.profit > 0 else 0,
                'duration': (trade.exit_time - trade.entry_time).total_seconds() / 3600 if trade.exit_time else 0
            })
        
        df = pd.DataFrame(data)
        
        stats = df.groupby('hour').agg({
            'profit': ['sum', 'mean', 'count'],
            'is_win': 'mean',
            'duration': 'mean'
        }).round(2)
        
        stats.columns = ['Total Profit', 'Avg Profit', 'Count', 'Win Rate', 'Avg Duration (h)']
        stats['Win Rate'] = stats['Win Rate'] * 100
        
        return stats
    
    def analyze_by_day_of_week(self) -> pd.DataFrame:
        """
        Analyse la performance par jour de la semaine
        """
        if not self.results or not self.results.trades:
            return pd.DataFrame()
        
        day_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        
        data = []
        for trade in self.results.trades:
            data.append({
                'day': day_names[trade.entry_time.weekday()],
                'day_num': trade.entry_time.weekday(),
                'profit': trade.profit,
                'is_win': 1 if trade.profit > 0 else 0
            })
        
        df = pd.DataFrame(data)
        
        stats = df.groupby(['day_num', 'day']).agg({
            'profit': ['sum', 'mean', 'count'],
            'is_win': 'mean'
        }).round(2)
        
        stats.columns = ['Total Profit', 'Avg Profit', 'Count', 'Win Rate']
        stats['Win Rate'] = stats['Win Rate'] * 100
        
        return stats.reset_index().drop('day_num', axis=1).set_index('day')
    
    def analyze_trade_duration(self) -> Dict[str, Any]:
        """
        Analyse la durée des trades
        """
        if not self.results or not self.results.trades:
            return {}
        
        winning_durations = []
        losing_durations = []
        
        for trade in self.results.trades:
            if not trade.exit_time:
                continue
            
            duration_hours = (trade.exit_time - trade.entry_time).total_seconds() / 3600
            
            if trade.profit > 0:
                winning_durations.append(duration_hours)
            else:
                losing_durations.append(duration_hours)
        
        return {
            'avg_win_duration': np.mean(winning_durations) if winning_durations else 0,
            'avg_loss_duration': np.mean(losing_durations) if losing_durations else 0,
            'median_win_duration': np.median(winning_durations) if winning_durations else 0,
            'median_loss_duration': np.median(losing_durations) if losing_durations else 0
        }
    
    def find_best_worst_trades(self, n: int = 5) -> Dict[str, List[Trade]]:
        """
        Trouve les meilleurs et pires trades
        
        Args:
            n: Nombre de trades à retourner
        
        Returns:
            Dict avec 'best' et 'worst' trades
        """
        if not self.results or not self.results.trades:
            return {'best': [], 'worst': []}
        
        sorted_trades = sorted(self.results.trades, key=lambda t: t.profit, reverse=True)
        
        return {
            'best': sorted_trades[:n],
            'worst': sorted_trades[-n:][::-1]
        }
    
    def calculate_monthly_returns(self) -> pd.DataFrame:
        """
        Calcule les rendements mensuels
        """
        if not self.results or not self.results.equity_curve or not self.results.timestamps:
            return pd.DataFrame()
        
        # Créer série temporelle de l'equity
        equity_series = pd.Series(
            self.results.equity_curve,
            index=self.results.timestamps
        )
        
        # Resample par mois
        monthly = equity_series.resample('M').last()
        
        # Calculer rendements
        returns = monthly.pct_change() * 100
        
        return pd.DataFrame({
            'Month': monthly.index.strftime('%Y-%m'),
            'Equity': monthly.values,
            'Return (%)': returns.values
        })
    
    def analyze_drawdown_periods(self) -> pd.DataFrame:
        """
        Analyse les périodes de drawdown
        """
        if not self.results or not self.results.drawdown_curve:
            return pd.DataFrame()
        
        dd_curve = self.results.drawdown_curve
        timestamps = self.results.timestamps
        
        # Trouver les périodes de drawdown (quand dd < 0)
        in_dd = False
        dd_periods = []
        dd_start = None
        dd_max = 0
        
        for i, dd in enumerate(dd_curve):
            if dd < 0:
                if not in_dd:
                    # Début d'un nouveau drawdown
                    in_dd = True
                    dd_start = timestamps[i]
                    dd_max = dd
                else:
                    # Continuation du drawdown
                    dd_max = min(dd_max, dd)
            else:
                if in_dd:
                    # Fin du drawdown
                    dd_periods.append({
                        'start': dd_start,
                        'end': timestamps[i-1],
                        'duration': (timestamps[i-1] - dd_start).total_seconds() / 3600,
                        'max_dd': abs(dd_max)
                    })
                    in_dd = False
        
        return pd.DataFrame(dd_periods)
    
    def generate_report(self, save_to_file: Optional[str] = None) -> str:
        """
        Génère un rapport complet
        
        Args:
            save_to_file: Fichier de sortie (optionnel)
        
        Returns:
            Rapport en texte
        """
        if not self.results:
            return "Aucun résultat à analyser"
        
        report_lines = []
        report_lines.append("=" * 80)
        report_lines.append("PERFORMANCE ANALYSIS REPORT".center(80))
        report_lines.append("=" * 80)
        
        # Stats de base
        report_lines.append("\n📊 BASIC STATISTICS")
        report_lines.append("-" * 80)
        report_lines.append(f"Total Trades:          {self.results.total_trades}")
        report_lines.append(f"Win Rate:              {self.results.win_rate:.2f}%")
        report_lines.append(f"Profit Factor:         {self.results.profit_factor:.2f}")
        report_lines.append(f"Net Profit:            ${self.results.net_profit:,.2f}")
        report_lines.append(f"Total Return:          {self.results.total_return_pct:.2f}%")
        
        # Distribution
        report_lines.append("\n📈 TRADE DISTRIBUTION")
        report_lines.append("-" * 80)
        dist = self.analyze_trade_distribution()
        for key, value in dist.items():
            report_lines.append(f"{key:20s}: {value:.2f}")
        
        # Par heure
        report_lines.append("\n🕐 PERFORMANCE BY HOUR")
        report_lines.append("-" * 80)
        by_hour = self.analyze_by_hour()
        report_lines.append(by_hour.to_string())
        
        # Par jour
        report_lines.append("\n📅 PERFORMANCE BY DAY OF WEEK")
        report_lines.append("-" * 80)
        by_day = self.analyze_by_day_of_week()
        report_lines.append(by_day.to_string())
        
        # Meilleurs/Pires trades
        report_lines.append("\n🏆 BEST/WORST TRADES")
        report_lines.append("-" * 80)
        best_worst = self.find_best_worst_trades(3)
        
        report_lines.append("\nBest Trades:")
        for i, trade in enumerate(best_worst['best'], 1):
            report_lines.append(f"  {i}. Profit: ${trade.profit:.2f} | Entry: {trade.entry_time}")
        
        report_lines.append("\nWorst Trades:")
        for i, trade in enumerate(best_worst['worst'], 1):
            report_lines.append(f"  {i}. Profit: ${trade.profit:.2f} | Entry: {trade.entry_time}")
        
        report_lines.append("\n" + "=" * 80)
        
        report = "\n".join(report_lines)
        
        # Sauvegarder si demandé (UTF-8 pour compat Windows/emoji)
        if save_to_file:
            with open(save_to_file, 'w', encoding='utf-8') as f:
                f.write(report)
            print(f"✅ Rapport sauvegardé: {save_to_file}")
        
        return report


if __name__ == "__main__":
    # Test de l'analyseur
    from backtesting import BacktestResults, Trade
    
    # Mock results
    results = BacktestResults()
    results.total_trades = 100
    results.win_rate = 60.0
    results.profit_factor = 1.5
    results.net_profit = 5000
    results.total_return_pct = 50.0
    
    # Mock trades
    for i in range(100):
        trade = Trade(
            entry_time=datetime(2024, 1, 1) + pd.Timedelta(hours=i*24),
            exit_time=datetime(2024, 1, 1) + pd.Timedelta(hours=i*24+12),
            profit=np.random.randn() * 100,
        )
        results.trades.append(trade)
    
    # Analyser
    analyzer = PerformanceAnalyzer(results)
    report = analyzer.generate_report()
    
    print(report)

