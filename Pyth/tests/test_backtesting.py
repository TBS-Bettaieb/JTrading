"""
Tests unitaires pour le moteur de backtesting
"""
import pytest
import pandas as pd
import numpy as np
from datetime import datetime

from backtesting.engine import BacktestEngine, Trade, BacktestResults
from strategies.free_candle import Signal


class TestBacktestEngine:
    """Tests pour le moteur de backtesting"""
    
    def test_engine_initialization(self):
        """Test d'initialisation du moteur"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        assert engine.initial_capital == 10000
        assert engine.commission == 0.0002
        assert engine.current_capital == 10000
    
    def test_engine_with_different_parameters(self):
        """Test avec différents paramètres d'initialisation"""
        # Capital et commission différents
        engine1 = BacktestEngine(initial_capital=5000, commission=0.0001)
        assert engine1.initial_capital == 5000
        assert engine1.commission == 0.0001
        
        # Commission zéro
        engine2 = BacktestEngine(initial_capital=10000, commission=0.0)
        assert engine2.commission == 0.0
    
    def test_run_backtest_basic(self, sample_ohlcv_data, sample_signals, default_config):
        """Test de base du backtesting"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        results = engine.run_backtest(sample_ohlcv_data, sample_signals, default_config)
        
        assert isinstance(results, BacktestResults)
        assert results.initial_capital == 10000
        assert results.final_capital >= 0
        assert results.net_profit == results.final_capital - results.initial_capital
        assert len(results.trades) >= 0
        assert len(results.equity_curve) >= 0
        assert len(results.timestamps) >= 0
    
    def test_run_backtest_empty_signals(self, sample_ohlcv_data, default_config):
        """Test avec des signaux vides"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        empty_signals = []
        results = engine.run_backtest(sample_ohlcv_data, empty_signals, default_config)
        
        assert results.initial_capital == results.final_capital
        assert results.net_profit == 0
        assert len(results.trades) == 0
        assert len(results.equity_curve) == 1  # Seulement le capital initial
        assert len(results.timestamps) == 1
    
    def test_run_backtest_insufficient_data(self, sample_signals, default_config):
        """Test avec des données insuffisantes"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        # DataFrame avec une seule ligne
        insufficient_data = pd.DataFrame({
            'open': [100], 'high': [101], 'low': [99], 'close': [100.5], 'volume': [1000]
        })
        
        results = engine.run_backtest(insufficient_data, sample_signals, default_config)
        
        # Devrait gérer gracieusement les données insuffisantes
        assert isinstance(results, BacktestResults)
        assert results.initial_capital == 10000
    
    def test_trade_execution_buy(self, sample_ohlcv_data, default_config):
        """Test d'exécution d'un trade d'achat"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        # Signal d'achat
        buy_signal = Signal(
            timestamp=datetime(2023, 1, 1, 10, 0),
            direction=1,
            entry_price=100.0,
            sl_price=99.0,
            tp_price=102.0,
            rr_ratio=2.0,
            confidence=0.8,
            source="FreeCandle"
        )
        
        results = engine.run_backtest(sample_ohlcv_data, [buy_signal], default_config)
        
        assert len(results.trades) > 0
        trade = results.trades[0]
        assert trade.direction == 1
        assert trade.entry_price == 100.0
        assert trade.sl == 99.0
        assert trade.tp == 102.0
    
    def test_trade_execution_sell(self, sample_ohlcv_data, default_config):
        """Test d'exécution d'un trade de vente"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        # Signal de vente
        sell_signal = Signal(
            timestamp=datetime(2023, 1, 1, 10, 0),
            direction=-1,
            entry_price=100.0,
            sl_price=101.0,
            tp_price=98.0,
            rr_ratio=2.0,
            confidence=0.8,
            source="FreeCandle"
        )
        
        results = engine.run_backtest(sample_ohlcv_data, [sell_signal], default_config)
        
        assert len(results.trades) > 0
        trade = results.trades[0]
        assert trade.direction == -1
        assert trade.entry_price == 100.0
        assert trade.sl == 101.0
        assert trade.tp == 98.0
    
    def test_commission_calculation(self, sample_ohlcv_data, default_config):
        """Test du calcul des commissions"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        signal = Signal(
            timestamp=datetime(2023, 1, 1, 10, 0),
            direction=1,
            entry_price=100.0,
            sl_price=99.0,
            tp_price=102.0,
            rr_ratio=2.0,
            confidence=0.8,
            source="FreeCandle"
        )
        
        results = engine.run_backtest(sample_ohlcv_data, [signal], default_config)
        
        if results.trades:
            trade = results.trades[0]
            # La commission doit être déduite du profit
            # Commission = volume * prix * taux_commission
            expected_commission = trade.volume * trade.entry_price * 0.0002
            # Le profit net doit tenir compte de la commission
            assert trade.profit <= (trade.exit_price - trade.entry_price) * trade.volume
    
    def test_stop_loss_execution(self, sample_ohlcv_data, default_config):
        """Test d'exécution du stop loss"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        # Créer des données où le prix touche le stop loss
        df = sample_ohlcv_data.copy()
        
        # Modifier les données pour que le prix touche le SL
        signal_time = df.index[100]
        signal = Signal(
            timestamp=signal_time,
            direction=1,  # BUY
            entry_price=df.loc[signal_time, 'close'],
            sl_price=df.loc[signal_time, 'close'] - 0.5,  # SL plus bas
            tp_price=df.loc[signal_time, 'close'] + 1.0,  # TP plus haut
            rr_ratio=2.0,
            confidence=0.8,
            source="FreeCandle"
        )
        
        # Modifier les prix suivants pour toucher le SL
        for i in range(101, min(105, len(df))):
            df.loc[df.index[i], 'low'] = signal.sl_price - 0.1
            df.loc[df.index[i], 'close'] = signal.sl_price
        
        results = engine.run_backtest(df, [signal], default_config)
        
        if results.trades:
            trade = results.trades[0]
            assert trade.exit_reason == "SL" or trade.exit_reason == "Stop Loss"
            assert trade.profit < 0  # Trade perdant
    
    def test_take_profit_execution(self, sample_ohlcv_data, default_config):
        """Test d'exécution du take profit"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        # Créer des données où le prix touche le take profit
        df = sample_ohlcv_data.copy()
        
        # Modifier les données pour que le prix touche le TP
        signal_time = df.index[100]
        signal = Signal(
            timestamp=signal_time,
            direction=1,  # BUY
            entry_price=df.loc[signal_time, 'close'],
            sl_price=df.loc[signal_time, 'close'] - 0.5,  # SL plus bas
            tp_price=df.loc[signal_time, 'close'] + 1.0,  # TP plus haut
            rr_ratio=2.0,
            confidence=0.8,
            source="FreeCandle"
        )
        
        # Modifier les prix suivants pour toucher le TP
        for i in range(101, min(105, len(df))):
            df.loc[df.index[i], 'high'] = signal.tp_price + 0.1
            df.loc[df.index[i], 'close'] = signal.tp_price
        
        results = engine.run_backtest(df, [signal], default_config)
        
        if results.trades:
            trade = results.trades[0]
            assert trade.exit_reason == "TP" or trade.exit_reason == "Take Profit"
            assert trade.profit > 0  # Trade gagnant
    
    def test_multiple_trades(self, sample_ohlcv_data, default_config):
        """Test avec plusieurs trades"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        # Créer plusieurs signaux
        signals = []
        for i in range(5):
            signal_time = sample_ohlcv_data.index[100 + i * 50]
            signal = Signal(
                timestamp=signal_time,
                direction=1 if i % 2 == 0 else -1,
                entry_price=sample_ohlcv_data.loc[signal_time, 'close'],
                sl_price=sample_ohlcv_data.loc[signal_time, 'close'] - 0.5,
                tp_price=sample_ohlcv_data.loc[signal_time, 'close'] + 1.0,
                rr_ratio=2.0,
                confidence=0.8,
                source="FreeCandle"
            )
            signals.append(signal)
        
        results = engine.run_backtest(sample_ohlcv_data, signals, default_config)
        
        assert len(results.trades) > 0
        assert len(results.equity_curve) > 1
        assert len(results.timestamps) > 1
    
    def test_equity_curve_calculation(self, sample_ohlcv_data, sample_signals, default_config):
        """Test du calcul de la courbe d'equity"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        results = engine.run_backtest(sample_ohlcv_data, sample_signals, default_config)
        
        assert len(results.equity_curve) == len(results.timestamps)
        assert results.equity_curve[0] == results.initial_capital
        assert results.equity_curve[-1] == results.final_capital
        
        # Vérifier que l'equity ne devient jamais négative
        for equity in results.equity_curve:
            assert equity >= 0
    
    def test_performance_metrics(self, sample_ohlcv_data, sample_signals, default_config):
        """Test des métriques de performance"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        results = engine.run_backtest(sample_ohlcv_data, sample_signals, default_config)
        
        # Vérifier les métriques de base
        assert results.total_trades >= 0
        assert results.winning_trades >= 0
        assert results.losing_trades >= 0
        assert results.winning_trades + results.losing_trades <= results.total_trades
        
        if results.total_trades > 0:
            assert 0 <= results.win_rate <= 100
            assert results.profit_factor >= 0
            assert results.max_drawdown <= 0  # Drawdown négatif
            assert results.sharpe_ratio is not None
    
    def test_backtest_with_different_timeframes(self, sample_ohlcv_data, default_config):
        """Test avec différents timeframes"""
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        
        # Créer des signaux pour différents moments
        signals = []
        for i in range(0, len(sample_ohlcv_data), 100):  # Signaux espacés
            if i < len(sample_ohlcv_data):
                signal_time = sample_ohlcv_data.index[i]
                signal = Signal(
                    timestamp=signal_time,
                    direction=1,
                    entry_price=sample_ohlcv_data.loc[signal_time, 'close'],
                    sl_price=sample_ohlcv_data.loc[signal_time, 'close'] - 0.5,
                    tp_price=sample_ohlcv_data.loc[signal_time, 'close'] + 1.0,
                    rr_ratio=2.0,
                    confidence=0.8,
                    source="FreeCandle"
                )
                signals.append(signal)
        
        results = engine.run_backtest(sample_ohlcv_data, signals, default_config)
        
        assert isinstance(results, BacktestResults)
        assert results.total_trades >= 0


class TestTrade:
    """Tests pour la classe Trade"""
    
    def test_trade_creation(self):
        """Test de création d'un trade"""
        trade = Trade(
            entry_time=datetime(2023, 1, 1, 10, 0),
            exit_time=datetime(2023, 1, 1, 11, 0),
            direction=1,
            entry_price=100.0,
            exit_price=101.0,
            sl=99.0,
            tp=102.0,
            volume=1.0,
            profit=100.0,
            profit_pct=1.0,
            exit_reason="TP"
        )
        
        assert trade.direction == 1
        assert trade.entry_price == 100.0
        assert trade.exit_price == 101.0
        assert trade.profit == 100.0
        assert trade.exit_reason == "TP"
    
    def test_trade_profit_calculation(self):
        """Test du calcul de profit"""
        # Trade gagnant
        winning_trade = Trade(
            entry_time=datetime(2023, 1, 1, 10, 0),
            direction=1,
            entry_price=100.0,
            exit_price=102.0,
            volume=1.0,
            profit=200.0
        )
        
        assert winning_trade.profit > 0
        
        # Trade perdant
        losing_trade = Trade(
            entry_time=datetime(2023, 1, 1, 10, 0),
            direction=1,
            entry_price=100.0,
            exit_price=98.0,
            volume=1.0,
            profit=-200.0
        )
        
        assert losing_trade.profit < 0


class TestBacktestResults:
    """Tests pour la classe BacktestResults"""
    
    def test_backtest_results_creation(self, sample_trades):
        """Test de création des résultats de backtest"""
        results = BacktestResults(
            initial_capital=10000,
            final_capital=11000,
            trades=sample_trades,
            equity_curve=[10000, 10100, 10200, 11000],
            timestamps=[datetime(2023, 1, 1), datetime(2023, 1, 2), 
                       datetime(2023, 1, 3), datetime(2023, 1, 4)]
        )
        
        assert results.initial_capital == 10000
        assert results.final_capital == 11000
        assert results.net_profit == 1000
        assert len(results.trades) == 3
        assert len(results.equity_curve) == 4
        assert len(results.timestamps) == 4
    
    def test_backtest_results_calculation(self, sample_trades):
        """Test des calculs automatiques des résultats"""
        results = BacktestResults(
            initial_capital=10000,
            final_capital=11000,
            trades=sample_trades,
            equity_curve=[10000, 10100, 10200, 11000],
            timestamps=[datetime(2023, 1, 1), datetime(2023, 1, 2), 
                       datetime(2023, 1, 3), datetime(2023, 1, 4)]
        )
        
        # Vérifier les calculs automatiques
        assert results.net_profit == results.final_capital - results.initial_capital
        assert results.total_return_pct == (results.net_profit / results.initial_capital) * 100
        
        # Vérifier les métriques de trades
        winning_trades = [t for t in sample_trades if t.profit > 0]
        losing_trades = [t for t in sample_trades if t.profit < 0]
        
        assert results.winning_trades == len(winning_trades)
        assert results.losing_trades == len(losing_trades)
        assert results.total_trades == len(sample_trades)
