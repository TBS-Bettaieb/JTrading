"""
Performance Metrics
Calcul de métriques avancées de performance
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional
from dataclasses import dataclass

from .engine import BacktestResults, Trade


class PerformanceMetrics:
    """
    Calcule des métriques avancées de performance
    
    Métriques:
    - Calmar Ratio
    - MAR Ratio
    - Ulcer Index
    - Recovery Factor
    - Payoff Ratio
    - Kestner Ratio
    - Etc.
    """
    
    @staticmethod
    def calmar_ratio(results: BacktestResults, years: float = 1.0) -> float:
        """
        Calmar Ratio = Rendement annualisé / Max Drawdown
        
        Args:
            results: Résultats du backtest
            years: Nombre d'années de la période
        
        Returns:
            Calmar ratio
        """
        if results.max_drawdown == 0:
            return 0.0
        
        # Rendement annualisé
        annualized_return = results.total_return_pct / years
        
        return annualized_return / results.max_drawdown_pct
    
    @staticmethod
    def mar_ratio(results: BacktestResults) -> float:
        """
        MAR Ratio = Return / Max Adverse excursion
        Similaire au Calmar
        """
        if results.max_drawdown == 0:
            return 0.0
        
        return results.total_return_pct / results.max_drawdown_pct
    
    @staticmethod
    def ulcer_index(equity_curve: List[float]) -> float:
        """
        Ulcer Index - Mesure de la profondeur et durée des drawdowns
        
        Args:
            equity_curve: Courbe d'equity
        
        Returns:
            Ulcer index
        """
        if len(equity_curve) < 2:
            return 0.0
        
        # Calculer les drawdowns en %
        peak = equity_curve[0]
        drawdowns_pct = []
        
        for equity in equity_curve:
            if equity > peak:
                peak = equity
            dd_pct = ((equity - peak) / peak) * 100 if peak > 0 else 0
            drawdowns_pct.append(dd_pct ** 2)  # Carré des drawdowns
        
        # Ulcer Index = racine carrée de la moyenne des carrés
        ulcer = np.sqrt(np.mean(drawdowns_pct))
        
        return ulcer
    
    @staticmethod
    def ulcer_performance_index(
        results: BacktestResults,
        risk_free_rate: float = 0.0
    ) -> float:
        """
        UPI = (Return - Risk Free Rate) / Ulcer Index
        """
        ulcer = PerformanceMetrics.ulcer_index(results.equity_curve)
        
        if ulcer == 0:
            return 0.0
        
        return (results.total_return_pct - risk_free_rate) / ulcer
    
    @staticmethod
    def recovery_factor(results: BacktestResults) -> float:
        """
        Recovery Factor = Net Profit / Max Drawdown
        """
        if results.max_drawdown == 0:
            return 0.0
        
        return results.net_profit / results.max_drawdown
    
    @staticmethod
    def payoff_ratio(results: BacktestResults) -> float:
        """
        Payoff Ratio = Avg Win / Avg Loss
        """
        if results.avg_loss == 0:
            return 0.0
        
        return results.avg_win / results.avg_loss
    
    @staticmethod
    def kestner_ratio(equity_curve: List[float]) -> float:
        """
        Kestner Ratio - Mesure la tendance de l'equity curve
        
        K = Coefficient of determination (R²) * slope
        """
        if len(equity_curve) < 2:
            return 0.0
        
        # Créer une série temporelle
        x = np.arange(len(equity_curve))
        y = np.array(equity_curve)
        
        # Régression linéaire
        coeffs = np.polyfit(x, y, 1)
        slope = coeffs[0]
        
        # Calculer R²
        y_pred = np.polyval(coeffs, x)
        ss_res = np.sum((y - y_pred) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        
        r_squared = 1 - (ss_res / ss_tot) if ss_tot > 0 else 0
        
        # Kestner = R² * slope
        kestner = r_squared * slope
        
        return kestner
    
    @staticmethod
    def max_adverse_excursion(trades: List[Trade]) -> Dict[str, float]:
        """
        Maximum Adverse Excursion (MAE) - Plus gros drawdown intra-trade
        
        Returns:
            Dict avec avg_mae, max_mae, avg_mae_pct
        """
        if not trades:
            return {'avg_mae': 0, 'max_mae': 0, 'avg_mae_pct': 0}
        
        maes = [abs(t.max_drawdown) for t in trades]
        
        return {
            'avg_mae': np.mean(maes),
            'max_mae': max(maes),
            'avg_mae_pct': np.mean([abs(t.max_drawdown / t.entry_price) * 100 for t in trades if t.entry_price > 0])
        }
    
    @staticmethod
    def max_favorable_excursion(trades: List[Trade]) -> Dict[str, float]:
        """
        Maximum Favorable Excursion (MFE) - Plus gros profit intra-trade
        
        Returns:
            Dict avec avg_mfe, max_mfe, avg_mfe_pct
        """
        if not trades:
            return {'avg_mfe': 0, 'max_mfe': 0, 'avg_mfe_pct': 0}
        
        mfes = [t.max_profit for t in trades]
        
        return {
            'avg_mfe': np.mean(mfes),
            'max_mfe': max(mfes),
            'avg_mfe_pct': np.mean([t.max_profit / t.entry_price * 100 for t in trades if t.entry_price > 0])
        }
    
    @staticmethod
    def trade_efficiency(trades: List[Trade]) -> float:
        """
        Trade Efficiency = Avg(Profit/MFE) pour les trades gagnants
        Mesure si on capture bien les profits potentiels
        """
        winning_trades = [t for t in trades if t.profit > 0 and t.max_profit > 0]
        
        if not winning_trades:
            return 0.0
        
        efficiencies = [t.profit / t.max_profit for t in winning_trades]
        
        return np.mean(efficiencies) * 100
    
    @staticmethod
    def analyze_by_hour(trades: List[Trade]) -> pd.DataFrame:
        """
        Analyse la performance par heure de la journée
        
        Returns:
            DataFrame avec stats par heure
        """
        if not trades:
            return pd.DataFrame()
        
        # Extraire les heures
        hours_data = []
        
        for trade in trades:
            hours_data.append({
                'hour': trade.entry_time.hour,
                'profit': trade.profit,
                'is_win': 1 if trade.profit > 0 else 0
            })
        
        df = pd.DataFrame(hours_data)
        
        # Grouper par heure
        by_hour = df.groupby('hour').agg({
            'profit': ['sum', 'mean', 'count'],
            'is_win': 'mean'
        }).round(2)
        
        by_hour.columns = ['Total Profit', 'Avg Profit', 'Trade Count', 'Win Rate']
        by_hour['Win Rate'] = by_hour['Win Rate'] * 100
        
        return by_hour
    
    @staticmethod
    def analyze_by_day(trades: List[Trade]) -> pd.DataFrame:
        """
        Analyse la performance par jour de la semaine
        
        Returns:
            DataFrame avec stats par jour
        """
        if not trades:
            return pd.DataFrame()
        
        # Extraire les jours
        days_data = []
        day_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        
        for trade in trades:
            days_data.append({
                'day': day_names[trade.entry_time.weekday()],
                'day_num': trade.entry_time.weekday(),
                'profit': trade.profit,
                'is_win': 1 if trade.profit > 0 else 0
            })
        
        df = pd.DataFrame(days_data)
        
        # Grouper par jour
        by_day = df.groupby(['day_num', 'day']).agg({
            'profit': ['sum', 'mean', 'count'],
            'is_win': 'mean'
        }).round(2)
        
        by_day.columns = ['Total Profit', 'Avg Profit', 'Trade Count', 'Win Rate']
        by_day['Win Rate'] = by_day['Win Rate'] * 100
        
        return by_day.reset_index().drop('day_num', axis=1).set_index('day')
    
    @staticmethod
    def analyze_by_rr(trades: List[Trade]) -> Dict[str, Any]:
        """
        Analyse la performance par ratio RR
        """
        if not trades:
            return {}
        
        # Grouper les trades par RR planifié
        rr_groups = {
            '1:1 to 1:2': [],
            '1:2 to 1:3': [],
            '1:3+': []
        }
        
        for trade in trades:
            if trade.planned_rr < 2:
                rr_groups['1:1 to 1:2'].append(trade)
            elif trade.planned_rr < 3:
                rr_groups['1:2 to 1:3'].append(trade)
            else:
                rr_groups['1:3+'].append(trade)
        
        # Calculer stats pour chaque groupe
        stats = {}
        for group_name, group_trades in rr_groups.items():
            if group_trades:
                wins = [t for t in group_trades if t.profit > 0]
                stats[group_name] = {
                    'count': len(group_trades),
                    'win_rate': len(wins) / len(group_trades) * 100,
                    'avg_profit': np.mean([t.profit for t in group_trades]),
                    'total_profit': sum([t.profit for t in group_trades])
                }
        
        return stats
    
    @staticmethod
    def calculate_all_metrics(results: BacktestResults, years: float = 1.0) -> Dict[str, Any]:
        """
        Calcule toutes les métriques disponibles
        
        Args:
            results: Résultats du backtest
            years: Durée en années
        
        Returns:
            Dictionnaire complet de toutes les métriques
        """
        metrics = {
            # Métriques de base (déjà dans results)
            'total_trades': results.total_trades,
            'win_rate': results.win_rate,
            'profit_factor': results.profit_factor,
            'net_profit': results.net_profit,
            'total_return_pct': results.total_return_pct,
            
            # Ratios
            'sharpe_ratio': results.sharpe_ratio,
            'sortino_ratio': results.sortino_ratio,
            'calmar_ratio': PerformanceMetrics.calmar_ratio(results, years),
            'mar_ratio': PerformanceMetrics.mar_ratio(results),
            'recovery_factor': PerformanceMetrics.recovery_factor(results),
            'payoff_ratio': PerformanceMetrics.payoff_ratio(results),
            
            # Drawdown
            'max_drawdown': results.max_drawdown,
            'max_drawdown_pct': results.max_drawdown_pct,
            'ulcer_index': PerformanceMetrics.ulcer_index(results.equity_curve),
            'upi': PerformanceMetrics.ulcer_performance_index(results),
            
            # Equity curve
            'kestner_ratio': PerformanceMetrics.kestner_ratio(results.equity_curve),
            
            # MAE/MFE
            'mae': PerformanceMetrics.max_adverse_excursion(results.trades),
            'mfe': PerformanceMetrics.max_favorable_excursion(results.trades),
            'trade_efficiency': PerformanceMetrics.trade_efficiency(results.trades),
            
            # Expectancy
            'expectancy': results.expectancy,
            'avg_rr': results.avg_rr,
            
            # Durées
            'avg_trade_duration': results.avg_trade_duration,
            'avg_win_duration': results.avg_win_duration,
            'avg_loss_duration': results.avg_loss_duration,
            
            # Séries
            'max_consecutive_wins': results.max_consecutive_wins,
            'max_consecutive_losses': results.max_consecutive_losses,
        }
        
        return metrics
    
    @staticmethod
    def print_metrics_report(results: BacktestResults, years: float = 1.0):
        """
        Affiche un rapport complet des métriques
        """
        metrics = PerformanceMetrics.calculate_all_metrics(results, years)
        
        print("\n" + "="*70)
        print("PERFORMANCE METRICS REPORT".center(70))
        print("="*70)
        
        print("\n📊 BASIC STATISTICS")
        print("-" * 70)
        print(f"Total Trades:          {metrics['total_trades']}")
        print(f"Win Rate:              {metrics['win_rate']:.2f}%")
        print(f"Profit Factor:         {metrics['profit_factor']:.2f}")
        print(f"Net Profit:            ${metrics['net_profit']:.2f}")
        print(f"Total Return:          {metrics['total_return_pct']:.2f}%")
        
        print("\n📈 RISK-ADJUSTED RATIOS")
        print("-" * 70)
        print(f"Sharpe Ratio:          {metrics['sharpe_ratio']:.2f}")
        print(f"Sortino Ratio:         {metrics['sortino_ratio']:.2f}")
        print(f"Calmar Ratio:          {metrics['calmar_ratio']:.2f}")
        print(f"MAR Ratio:             {metrics['mar_ratio']:.2f}")
        print(f"Recovery Factor:       {metrics['recovery_factor']:.2f}")
        print(f"Payoff Ratio:          {metrics['payoff_ratio']:.2f}")
        print(f"Kestner Ratio:         {metrics['kestner_ratio']:.4f}")
        
        print("\n📉 DRAWDOWN METRICS")
        print("-" * 70)
        print(f"Max Drawdown:          ${metrics['max_drawdown']:.2f} ({metrics['max_drawdown_pct']:.2f}%)")
        print(f"Ulcer Index:           {metrics['ulcer_index']:.2f}")
        print(f"UPI:                   {metrics['upi']:.2f}")
        
        print("\n💰 PROFIT/LOSS ANALYSIS")
        print("-" * 70)
        print(f"Expectancy:            ${metrics['expectancy']:.2f}")
        print(f"Average RR:            1:{metrics['avg_rr']:.2f}")
        print(f"Avg MAE:               ${metrics['mae']['avg_mae']:.2f}")
        print(f"Avg MFE:               ${metrics['mfe']['avg_mfe']:.2f}")
        print(f"Trade Efficiency:      {metrics['trade_efficiency']:.2f}%")
        
        print("\n⏱️ DURATION METRICS")
        print("-" * 70)
        print(f"Avg Trade Duration:    {metrics['avg_trade_duration']:.1f} hours")
        print(f"Avg Win Duration:      {metrics['avg_win_duration']:.1f} hours")
        print(f"Avg Loss Duration:     {metrics['avg_loss_duration']:.1f} hours")
        
        print("\n🎯 CONSECUTIVE TRADES")
        print("-" * 70)
        print(f"Max Consecutive Wins:  {metrics['max_consecutive_wins']}")
        print(f"Max Consecutive Losses: {metrics['max_consecutive_losses']}")
        
        print("=" * 70)


if __name__ == "__main__":
    # Test des métriques
    from .engine import BacktestEngine, BacktestResults
    from strategies import FreeCandleStrategy
    from config import StrategyConfig
    
    # Créer un backtest fictif
    np.random.seed(42)
    
    # Mock results
    results = BacktestResults()
    results.total_trades = 100
    results.winning_trades = 60
    results.losing_trades = 40
    results.win_rate = 60.0
    results.total_profit = 15000
    results.total_loss = 8000
    results.net_profit = 7000
    results.profit_factor = 1.875
    results.avg_win = 250
    results.avg_loss = 200
    results.max_drawdown = 2000
    results.max_drawdown_pct = 20.0
    results.total_return_pct = 70.0
    results.initial_capital = 10000
    results.final_capital = 17000
    results.expectancy = 70
    results.avg_rr = 1.5
    
    # Mock equity curve
    results.equity_curve = list(10000 + np.cumsum(np.random.randn(1000) * 100))
    
    # Mock trades
    import datetime
    for i in range(100):
        trade = Trade(
            entry_time=datetime.datetime(2024, 1, 1) + datetime.timedelta(hours=i*24),
            exit_time=datetime.datetime(2024, 1, 1) + datetime.timedelta(hours=i*24+12),
            profit=np.random.randn() * 200,
            max_profit=abs(np.random.randn() * 300),
            max_drawdown=-abs(np.random.randn() * 150),
            entry_price=1.1000,
            planned_rr=np.random.uniform(1.5, 3.0)
        )
        results.trades.append(trade)
    
    # Afficher le rapport
    PerformanceMetrics.print_metrics_report(results, years=1.0)
    
    # Analyse par heure
    print("\n\n📅 PERFORMANCE BY HOUR")
    print("="*70)
    print(PerformanceMetrics.analyze_by_hour(results.trades))
    
    # Analyse par RR
    print("\n\n🎯 PERFORMANCE BY RR RATIO")
    print("="*70)
    rr_analysis = PerformanceMetrics.analyze_by_rr(results.trades)
    for rr_range, stats in rr_analysis.items():
        print(f"\n{rr_range}:")
        for key, value in stats.items():
            print(f"  {key}: {value:.2f}")

