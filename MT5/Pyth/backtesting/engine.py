"""
Backtest Engine
Moteur de simulation de trading pour backtesting
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime
from tqdm import tqdm

from config.settings import StrategyConfig
from strategies import Signal
from risk_management import PositionSizer


@dataclass
class Trade:
    """Représente un trade exécuté"""
    entry_time: datetime
    exit_time: Optional[datetime] = None
    direction: int = 0  # 1=buy, -1=sell
    entry_price: float = 0.0
    exit_price: float = 0.0
    sl: float = 0.0
    tp: float = 0.0
    volume: float = 0.0
    profit: float = 0.0
    profit_pct: float = 0.0
    exit_reason: str = ""
    max_profit: float = 0.0
    max_drawdown: float = 0.0
    pips: float = 0.0
    commission: float = 0.0
    swap: float = 0.0
    
    # Indicateurs au moment de l'entrée
    entry_rsi: float = 0.0
    entry_atr: float = 0.0
    entry_bb_width: float = 0.0
    
    # Méta-données
    signal_confidence: float = 0.0
    planned_rr: float = 0.0
    actual_rr: float = 0.0


@dataclass
class BacktestResults:
    """Résultats complets du backtest"""
    trades: List[Trade] = field(default_factory=list)
    
    # Statistiques de base
    total_trades: int = 0
    winning_trades: int = 0
    losing_trades: int = 0
    break_even_trades: int = 0
    
    # Performance
    win_rate: float = 0.0
    profit_factor: float = 0.0
    total_profit: float = 0.0
    total_loss: float = 0.0
    net_profit: float = 0.0
    
    # Drawdown
    max_drawdown: float = 0.0
    max_drawdown_pct: float = 0.0
    avg_drawdown: float = 0.0
    
    # Profits/Pertes
    avg_win: float = 0.0
    avg_loss: float = 0.0
    largest_win: float = 0.0
    largest_loss: float = 0.0
    
    # Risk/Reward
    avg_rr: float = 0.0
    expectancy: float = 0.0
    
    # Durées
    avg_trade_duration: float = 0.0  # en heures
    avg_win_duration: float = 0.0
    avg_loss_duration: float = 0.0
    
    # Séries
    max_consecutive_wins: int = 0
    max_consecutive_losses: int = 0
    
    # Equity
    initial_capital: float = 0.0
    final_capital: float = 0.0
    total_return_pct: float = 0.0
    
    # Sharpe & Sortino
    sharpe_ratio: float = 0.0
    sortino_ratio: float = 0.0
    
    # Courbes
    equity_curve: List[float] = field(default_factory=list)
    drawdown_curve: List[float] = field(default_factory=list)
    timestamps: List[datetime] = field(default_factory=list)


class BacktestEngine:
    """
    Moteur de backtesting
    
    Simule l'exécution de trades sur données historiques avec:
    - Gestion réaliste des entrées/sorties
    - Calcul des commissions et slippage
    - Tracking de l'equity en temps réel
    - Calcul de toutes les métriques de performance
    """
    
    def __init__(
        self,
        initial_capital: float = 10000.0,
        commission: float = 0.0002,  # 0.02%
        slippage_points: float = 2.0,
        point_size: float = 0.0001,
        point_value: float = 10.0
    ):
        """
        Args:
            initial_capital: Capital initial
            commission: Commission par trade (en fraction, ex: 0.0002 = 0.02%)
            slippage_points: Slippage en points
            point_size: Taille d'un point (0.0001 pour EURUSD)
            point_value: Valeur d'un point par lot (10 USD pour EURUSD)
        """
        self.initial_capital = initial_capital
        self.commission = commission
        self.slippage_points = slippage_points
        self.point_size = point_size
        self.point_value = point_value
        
        # État du backtest
        self.capital = initial_capital
        self.equity_curve = [initial_capital]
        self.timestamps = []
        self.trades = []
        self.open_positions = []
        
        # Position sizer
        self.position_sizer = PositionSizer()
    
    def run_backtest(
        self,
        df: pd.DataFrame,
        signals: List[Signal],
        config: StrategyConfig,
        verbose: bool = True
    ) -> BacktestResults:
        """
        Exécute le backtest complet
        
        Args:
            df: DataFrame avec données OHLCV et indicateurs
            signals: Liste des signaux générés par la stratégie
            config: Configuration de la stratégie
            verbose: Afficher la barre de progression
        
        Returns:
            Résultats du backtest
        """
        # Réinitialiser l'état
        self.capital = self.initial_capital
        self.equity_curve = [self.initial_capital]
        self.timestamps = []
        self.trades = []
        self.open_positions = []
        
        # Trier les signaux par timestamp
        signals = sorted(signals, key=lambda s: s.timestamp)
        
        # Index des signaux
        signal_idx = 0
        
        # Barre de progression
        iterator = tqdm(range(len(df)), desc="Backtesting") if verbose else range(len(df))
        
        for i in iterator:
            row = df.iloc[i]
            current_time = row.name
            
            # Gérer les positions ouvertes
            self._manage_open_positions(row, current_time)
            
            # Vérifier s'il y a un signal à ce timestamp
            while signal_idx < len(signals) and signals[signal_idx].timestamp <= current_time:
                signal = signals[signal_idx]
                
                # Vérifier si on peut ouvrir une nouvelle position
                if config.money_management.one_pos_per_symbol and len(self.open_positions) > 0:
                    signal_idx += 1
                    continue
                
                # Ouvrir la position
                self._open_position(signal, config)
                signal_idx += 1
            
            # Enregistrer l'equity
            self._update_equity(row)
        
        # Fermer toutes les positions restantes
        if len(self.open_positions) > 0:
            last_row = df.iloc[-1]
            for pos in self.open_positions[:]:
                self._close_position(pos, last_row, "End of data")
        
        # Calculer les résultats
        results = self._calculate_results()
        
        return results
    
    def _open_position(self, signal: Signal, config: StrategyConfig):
        """Ouvre une nouvelle position basée sur un signal"""
        # Calculer la taille de position
        volume = self.position_sizer.fixed_percentage_risk(
            capital=self.capital,
            risk_percent=config.money_management.risk_percent,
            entry_price=signal.entry_price,
            stop_loss=signal.sl_price,
            point_value=self.point_value
        )
        
        if volume < config.money_management.min_volume:
            return
        
        # Appliquer le slippage
        slippage = self.slippage_points * self.point_size
        if signal.direction > 0:  # BUY
            entry_price = signal.entry_price + slippage
        else:  # SELL
            entry_price = signal.entry_price - slippage
        
        # Calculer la commission
        commission = volume * entry_price * self.commission
        
        # Créer le trade
        trade = Trade(
            entry_time=signal.timestamp,
            direction=signal.direction,
            entry_price=entry_price,
            sl=signal.sl_price,
            tp=signal.tp_price,
            volume=volume,
            commission=commission,
            entry_rsi=signal.indicators.get('rsi', 0),
            entry_atr=signal.indicators.get('atr', 0),
            entry_bb_width=signal.indicators.get('bb_width', 0),
            signal_confidence=signal.confidence,
            planned_rr=signal.rr_ratio
        )
        
        # Déduire la commission du capital
        self.capital -= commission
        
        # Ajouter aux positions ouvertes
        self.open_positions.append(trade)
    
    def _manage_open_positions(self, row: pd.Series, current_time: datetime):
        """Gère les positions ouvertes (vérifier SL/TP)"""
        for pos in self.open_positions[:]:
            # Calculer le profit actuel
            if pos.direction > 0:  # BUY
                # Vérifier SL (avec le low)
                if row['low'] <= pos.sl:
                    self._close_position(pos, row, "SL", exit_price=pos.sl)
                    continue
                
                # Vérifier TP (avec le high)
                if row['high'] >= pos.tp:
                    self._close_position(pos, row, "TP", exit_price=pos.tp)
                    continue
                
                # Mettre à jour max profit/drawdown
                current_profit = (row['close'] - pos.entry_price) * pos.volume * self.point_value
            else:  # SELL
                # Vérifier SL (avec le high)
                if row['high'] >= pos.sl:
                    self._close_position(pos, row, "SL", exit_price=pos.sl)
                    continue
                
                # Vérifier TP (avec le low)
                if row['low'] <= pos.tp:
                    self._close_position(pos, row, "TP", exit_price=pos.tp)
                    continue
                
                # Mettre à jour max profit/drawdown
                current_profit = (pos.entry_price - row['close']) * pos.volume * self.point_value
            
            # Mettre à jour les extrêmes
            if current_profit > pos.max_profit:
                pos.max_profit = current_profit
            if current_profit < pos.max_drawdown:
                pos.max_drawdown = current_profit
    
    def _close_position(
        self,
        trade: Trade,
        row: pd.Series,
        reason: str,
        exit_price: Optional[float] = None
    ):
        """Ferme une position"""
        # Prix de sortie
        if exit_price is None:
            exit_price = row['close']
        
        # Appliquer le slippage
        slippage = self.slippage_points * self.point_size
        if trade.direction > 0:  # BUY - vendre au bid
            exit_price -= slippage
        else:  # SELL - acheter à l'ask
            exit_price += slippage
        
        trade.exit_price = exit_price
        trade.exit_time = row.name
        trade.exit_reason = reason
        
        # Calculer le profit
        if trade.direction > 0:  # BUY
            profit_pct = (exit_price - trade.entry_price) / trade.entry_price
            pips = (exit_price - trade.entry_price) / self.point_size
        else:  # SELL
            profit_pct = (trade.entry_price - exit_price) / trade.entry_price
            pips = (trade.entry_price - exit_price) / self.point_size
        
        trade.profit_pct = profit_pct
        trade.pips = pips
        
        # Profit en capital
        trade.profit = profit_pct * trade.volume * trade.entry_price * self.point_value
        
        # Commission de sortie
        exit_commission = trade.volume * exit_price * self.commission
        trade.commission += exit_commission
        
        # Profit net
        net_profit = trade.profit - trade.commission
        
        # Mettre à jour le capital
        self.capital += net_profit
        
        # Calculer RR actuel
        risk = abs(trade.entry_price - trade.sl)
        reward = abs(exit_price - trade.entry_price)
        trade.actual_rr = reward / risk if risk > 0 else 0
        
        # Finaliser le trade
        trade.profit = net_profit
        
        # Retirer des positions ouvertes
        if trade in self.open_positions:
            self.open_positions.remove(trade)
        
        # Ajouter aux trades fermés
        self.trades.append(trade)
    
    def _update_equity(self, row: pd.Series):
        """Met à jour la courbe d'equity"""
        # Capital réalisé
        current_equity = self.capital
        
        # Ajouter les profits non réalisés
        for pos in self.open_positions:
            if pos.direction > 0:  # BUY
                unrealized_profit = (row['close'] - pos.entry_price) * pos.volume * self.point_value
            else:  # SELL
                unrealized_profit = (pos.entry_price - row['close']) * pos.volume * self.point_value
            
            current_equity += unrealized_profit
        
        self.equity_curve.append(current_equity)
        self.timestamps.append(row.name)
    
    def _calculate_results(self) -> BacktestResults:
        """Calcule toutes les métriques de performance"""
        results = BacktestResults()
        
        # Trades
        results.trades = self.trades
        results.total_trades = len(self.trades)
        
        if results.total_trades == 0:
            return results
        
        # Séparer winners/losers
        wins = [t for t in self.trades if t.profit > 0]
        losses = [t for t in self.trades if t.profit < 0]
        break_evens = [t for t in self.trades if t.profit == 0]
        
        results.winning_trades = len(wins)
        results.losing_trades = len(losses)
        results.break_even_trades = len(break_evens)
        
        # Win rate
        results.win_rate = (results.winning_trades / results.total_trades) * 100
        
        # Profits/Pertes
        if wins:
            results.total_profit = sum(t.profit for t in wins)
            results.avg_win = results.total_profit / len(wins)
            results.largest_win = max(t.profit for t in wins)
            
            # Durée moyenne des wins
            win_durations = [(t.exit_time - t.entry_time).total_seconds() / 3600 for t in wins if t.exit_time]
            results.avg_win_duration = np.mean(win_durations) if win_durations else 0
        
        if losses:
            results.total_loss = abs(sum(t.profit for t in losses))
            results.avg_loss = results.total_loss / len(losses)
            results.largest_loss = min(t.profit for t in losses)
            
            # Durée moyenne des losses
            loss_durations = [(t.exit_time - t.entry_time).total_seconds() / 3600 for t in losses if t.exit_time]
            results.avg_loss_duration = np.mean(loss_durations) if loss_durations else 0
        
        # Profit factor
        if results.total_loss > 0:
            results.profit_factor = results.total_profit / results.total_loss
        
        # Net profit
        results.net_profit = results.total_profit - results.total_loss
        
        # RR moyen
        rrs = [t.actual_rr for t in self.trades if t.actual_rr > 0]
        results.avg_rr = np.mean(rrs) if rrs else 0
        
        # Expectancy
        results.expectancy = (results.win_rate / 100 * results.avg_win) - \
                            ((100 - results.win_rate) / 100 * results.avg_loss)
        
        # Durée moyenne
        durations = [(t.exit_time - t.entry_time).total_seconds() / 3600 for t in self.trades if t.exit_time]
        results.avg_trade_duration = np.mean(durations) if durations else 0
        
        # Séries consécutives
        results.max_consecutive_wins = self._calculate_max_consecutive(wins=True)
        results.max_consecutive_losses = self._calculate_max_consecutive(wins=False)
        
        # Capital
        results.initial_capital = self.initial_capital
        results.final_capital = self.capital
        results.total_return_pct = ((self.capital - self.initial_capital) / self.initial_capital) * 100
        
        # Drawdown
        results.equity_curve = self.equity_curve
        results.timestamps = self.timestamps
        results.drawdown_curve = self._calculate_drawdown_curve()
        results.max_drawdown = abs(min(results.drawdown_curve)) if results.drawdown_curve else 0
        results.max_drawdown_pct = (results.max_drawdown / self.initial_capital) * 100
        
        # Sharpe & Sortino
        results.sharpe_ratio = self._calculate_sharpe_ratio()
        results.sortino_ratio = self._calculate_sortino_ratio()
        
        return results
    
    def _calculate_max_consecutive(self, wins: bool = True) -> int:
        """Calcule le nombre maximum de trades consécutifs gagnants/perdants"""
        max_consecutive = 0
        current_consecutive = 0
        
        for trade in self.trades:
            if (wins and trade.profit > 0) or (not wins and trade.profit < 0):
                current_consecutive += 1
                max_consecutive = max(max_consecutive, current_consecutive)
            else:
                current_consecutive = 0
        
        return max_consecutive
    
    def _calculate_drawdown_curve(self) -> List[float]:
        """Calcule la courbe de drawdown"""
        if not self.equity_curve:
            return []
        
        drawdown = []
        peak = self.equity_curve[0]
        
        for equity in self.equity_curve:
            if equity > peak:
                peak = equity
            dd = equity - peak
            drawdown.append(dd)
        
        return drawdown
    
    def _calculate_sharpe_ratio(self, risk_free_rate: float = 0.0) -> float:
        """Calcule le ratio de Sharpe"""
        if len(self.equity_curve) < 2:
            return 0.0
        
        # Calculer les rendements
        returns = np.diff(self.equity_curve) / self.equity_curve[:-1]
        
        if len(returns) == 0:
            return 0.0
        
        # Rendement moyen
        avg_return = np.mean(returns)
        
        # Volatilité
        std_return = np.std(returns)
        
        if std_return == 0:
            return 0.0
        
        # Sharpe ratio (annualisé)
        sharpe = (avg_return - risk_free_rate) / std_return
        sharpe_annualized = sharpe * np.sqrt(252)  # 252 jours de trading
        
        return sharpe_annualized
    
    def _calculate_sortino_ratio(self, risk_free_rate: float = 0.0) -> float:
        """Calcule le ratio de Sortino (comme Sharpe mais seulement downside volatility)"""
        if len(self.equity_curve) < 2:
            return 0.0
        
        # Calculer les rendements
        returns = np.diff(self.equity_curve) / self.equity_curve[:-1]
        
        if len(returns) == 0:
            return 0.0
        
        # Rendement moyen
        avg_return = np.mean(returns)
        
        # Downside volatility (seulement les rendements négatifs)
        downside_returns = returns[returns < 0]
        
        if len(downside_returns) == 0:
            return 0.0
        
        downside_std = np.std(downside_returns)
        
        if downside_std == 0:
            return 0.0
        
        # Sortino ratio (annualisé)
        sortino = (avg_return - risk_free_rate) / downside_std
        sortino_annualized = sortino * np.sqrt(252)
        
        return sortino_annualized


if __name__ == "__main__":
    # Test du backtest engine
    from strategies import FreeCandleStrategy
    from config import StrategyConfig
    
    # Configuration
    config = StrategyConfig()
    
    # Créer données de test
    np.random.seed(42)
    dates = pd.date_range('2024-01-01', periods=1000, freq='H')
    close_prices = 1.1000 + np.cumsum(np.random.randn(1000) * 0.0003)
    
    df_test = pd.DataFrame({
        'open': close_prices - 0.0001,
        'high': close_prices + 0.0002,
        'low': close_prices - 0.0002,
        'close': close_prices,
        'volume': np.random.randint(100, 1000, 1000)
    }, index=dates)
    
    # Créer stratégie et générer signaux
    strategy = FreeCandleStrategy(config)
    signals = strategy.generate_signals(df_test)
    
    # Créer et exécuter le backtest
    engine = BacktestEngine(initial_capital=10000)
    results = engine.run_backtest(df_test, signals, config)
    
    # Afficher les résultats
    print("\n" + "="*60)
    print("BACKTEST RESULTS")
    print("="*60)
    print(f"Total Trades: {results.total_trades}")
    print(f"Winning Trades: {results.winning_trades} ({results.win_rate:.2f}%)")
    print(f"Losing Trades: {results.losing_trades}")
    print(f"\nProfit Factor: {results.profit_factor:.2f}")
    print(f"Net Profit: ${results.net_profit:.2f}")
    print(f"Total Return: {results.total_return_pct:.2f}%")
    print(f"\nAvg Win: ${results.avg_win:.2f}")
    print(f"Avg Loss: ${results.avg_loss:.2f}")
    print(f"Avg RR: 1:{results.avg_rr:.2f}")
    print(f"\nMax Drawdown: ${results.max_drawdown:.2f} ({results.max_drawdown_pct:.2f}%)")
    print(f"Sharpe Ratio: {results.sharpe_ratio:.2f}")
    print(f"Sortino Ratio: {results.sortino_ratio:.2f}")
    print(f"\nMax Consecutive Wins: {results.max_consecutive_wins}")
    print(f"Max Consecutive Losses: {results.max_consecutive_losses}")
    print("="*60)

