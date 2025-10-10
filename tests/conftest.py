"""
Configuration des tests - fixtures communes
"""
import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import sys
import os

# Ajouter le répertoire Pyth au path pour les imports
pyth_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'Pyth')
sys.path.insert(0, pyth_dir)

from config import StrategyConfig


@pytest.fixture
def sample_ohlcv_data():
    """Génère des données OHLCV d'exemple pour les tests"""
    dates = pd.date_range(start='2023-01-01', periods=1000, freq='3min')
    
    # Générer des prix avec une tendance et de la volatilité
    np.random.seed(42)  # Pour des résultats reproductibles
    base_price = 100.0
    trend = np.linspace(0, 10, 1000)  # Tendance haussière
    noise = np.random.normal(0, 0.5, 1000)  # Bruit aléatoire
    
    close_prices = base_price + trend + noise
    
    # Générer OHLC à partir des prix de clôture
    data = []
    for i, close in enumerate(close_prices):
        high = close + abs(np.random.normal(0, 0.2))
        low = close - abs(np.random.normal(0, 0.2))
        open_price = close + np.random.normal(0, 0.1)
        volume = np.random.randint(100, 1000)
        
        data.append({
            'open': open_price,
            'high': high,
            'low': low,
            'close': close,
            'volume': volume
        })
    
    df = pd.DataFrame(data, index=dates)
    return df


@pytest.fixture
def sample_ohlcv_data_with_gaps():
    """Génère des données OHLCV avec des gaps pour tester la gestion des données manquantes"""
    dates = pd.date_range(start='2023-01-01', periods=100, freq='3min')
    
    # Supprimer quelques dates pour créer des gaps
    dates = dates.drop(dates[10:15]).drop(dates[30:35])
    
    np.random.seed(42)
    base_price = 100.0
    close_prices = base_price + np.random.normal(0, 1, len(dates))
    
    data = []
    for close in close_prices:
        high = close + abs(np.random.normal(0, 0.2))
        low = close - abs(np.random.normal(0, 0.2))
        open_price = close + np.random.normal(0, 0.1)
        volume = np.random.randint(100, 1000)
        
        data.append({
            'open': open_price,
            'high': high,
            'low': low,
            'close': close,
            'volume': volume
        })
    
    df = pd.DataFrame(data, index=dates)
    return df


@pytest.fixture
def default_config():
    """Configuration par défaut pour les tests"""
    return StrategyConfig()


@pytest.fixture
def conservative_config():
    """Configuration conservatrice pour les tests"""
    config = StrategyConfig()
    config.money_management.risk_percent = 0.5
    config.bollinger.period = 20
    config.bollinger.deviation = 2.0
    config.rsi.use_filter = True
    config.rsi.oversold = 30
    config.rsi.overbought = 70
    return config


@pytest.fixture
def aggressive_config():
    """Configuration agressive pour les tests"""
    config = StrategyConfig()
    config.money_management.risk_percent = 2.0
    config.bollinger.period = 15
    config.bollinger.deviation = 1.5
    config.rsi.use_filter = False
    config.ema.use_filter = False
    return config


@pytest.fixture
def sample_trades():
    """Génère des trades d'exemple pour les tests"""
    from backtesting.engine import Trade
    
    trades = [
        Trade(
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
        ),
        Trade(
            entry_time=datetime(2023, 1, 2, 10, 0),
            exit_time=datetime(2023, 1, 2, 11, 0),
            direction=-1,
            entry_price=100.0,
            exit_price=99.0,
            sl=101.0,
            tp=98.0,
            volume=1.0,
            profit=100.0,
            profit_pct=1.0,
            exit_reason="TP"
        ),
        Trade(
            entry_time=datetime(2023, 1, 3, 10, 0),
            exit_time=datetime(2023, 1, 3, 11, 0),
            direction=1,
            entry_price=100.0,
            exit_price=99.0,
            sl=99.0,
            tp=102.0,
            volume=1.0,
            profit=-100.0,
            profit_pct=-1.0,
            exit_reason="SL"
        )
    ]
    return trades


@pytest.fixture
def sample_signals():
    """Génère des signaux d'exemple pour les tests"""
    from strategies.free_candle import Signal
    
    signals = [
        Signal(
            timestamp=datetime(2023, 1, 1, 10, 0),
            direction=1,
            entry_price=100.0,
            sl_price=99.0,
            tp_price=102.0,
            rr_ratio=3.0,
            confidence=0.8,
            source="FreeCandle"
        ),
        Signal(
            timestamp=datetime(2023, 1, 2, 10, 0),
            direction=-1,
            entry_price=100.0,
            sl_price=101.0,
            tp_price=98.0,
            rr_ratio=2.0,
            confidence=0.7,
            source="FreeCandle"
        )
    ]
    return signals
