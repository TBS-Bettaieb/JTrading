"""
Tests unitaires pour la configuration
"""
import pytest
import sys
from pathlib import Path

# Ajouter le répertoire Pyth au path
sys.path.insert(0, str(Path(__file__).parent.parent / 'Pyth'))

from config import StrategyConfig, EntryMode


class TestStrategyConfig:
    """Tests pour la configuration de stratégie"""
    
    def test_config_initialization(self):
        """Test d'initialisation de la configuration"""
        config = StrategyConfig()
        
        assert config is not None
        assert hasattr(config, 'symbol')
        assert hasattr(config, 'bollinger')
        assert hasattr(config, 'rsi')
        assert hasattr(config, 'ema')
        assert hasattr(config, 'divergence')
        assert hasattr(config, 'entry')
        assert hasattr(config, 'money_management')
        assert hasattr(config, 'stop_loss')
        assert hasattr(config, 'time_filter')
        assert hasattr(config, 'position_management')
        assert hasattr(config, 'backtest')
        assert hasattr(config, 'live_trading')
        assert hasattr(config, 'logging')
        assert hasattr(config, 'visualization')
    
    def test_config_default_values(self):
        """Test des valeurs par défaut"""
        config = StrategyConfig()
        
        # Symbol
        assert config.symbol.symbol == "EURUSD"
        assert config.symbol.timeframe == "M3"
        assert config.symbol.digits == 5
        
        # Bollinger Bands
        assert config.bollinger.period == 20
        assert config.bollinger.deviation == 2.0
        
        # RSI
        assert config.rsi.period == 14
        assert config.rsi.oversold == 30
        assert config.rsi.overbought == 70
        assert config.rsi.use_filter == True
        
        # EMA
        assert config.ema.fast_period == 12
        assert config.ema.slow_period == 26
        assert config.ema.use_filter == True
        assert config.ema.trend_mode == "TREND"
        
        # Divergence
        assert config.divergence.use_validator == True
        assert config.divergence.min_bars == 5
        assert config.divergence.max_bars == 50
        
        # Entry
        assert config.entry.entry_mode == EntryMode.REVERSION
        
        # Money Management
        assert config.money_management.risk_percent == 1.0
        assert config.money_management.max_positions == 3
        assert config.money_management.one_pos_per_symbol == True
        
        # Stop Loss
        assert config.stop_loss.sl_period == 50
        assert config.stop_loss.tp_period == 30
        assert config.stop_loss.min_rr == 1.5
        
        # Time Filter
        assert config.time_filter.use_time_filter == True
        assert config.time_filter.start_hour == 8
        assert config.time_filter.end_hour == 16
        assert config.time_filter.allowed_days == [1, 2, 3, 4, 5]  # Lundi-Vendredi
    
    def test_config_validation(self):
        """Test de validation de la configuration"""
        config = StrategyConfig()
        
        # Test avec des valeurs valides
        config.bollinger.period = 20
        config.bollinger.deviation = 2.0
        config.rsi.period = 14
        config.ema.fast_period = 12
        config.ema.slow_period = 26
        
        # Ces valeurs doivent être acceptées
        assert config.bollinger.period == 20
        assert config.bollinger.deviation == 2.0
        assert config.rsi.period == 14
        assert config.ema.fast_period == 12
        assert config.ema.slow_period == 26
    
    def test_config_entry_modes(self):
        """Test des différents modes d'entrée"""
        config = StrategyConfig()
        
        # Test REVERSION
        config.entry.entry_mode = EntryMode.REVERSION
        assert config.entry.entry_mode == EntryMode.REVERSION
        
        # Test TREND
        config.entry.entry_mode = EntryMode.TREND
        assert config.entry.entry_mode == EntryMode.TREND
        
        # Test COUNTER
        config.entry.entry_mode = EntryMode.COUNTER
        assert config.entry.entry_mode == EntryMode.COUNTER
    
    def test_config_money_management(self):
        """Test de la configuration du money management"""
        config = StrategyConfig()
        
        # Test des limites
        config.money_management.risk_percent = 0.5
        config.money_management.max_positions = 5
        config.money_management.one_pos_per_symbol = False
        
        assert config.money_management.risk_percent == 0.5
        assert config.money_management.max_positions == 5
        assert config.money_management.one_pos_per_symbol == False
        
        # Test avec des valeurs extrêmes
        config.money_management.risk_percent = 10.0  # Très risqué
        config.money_management.max_positions = 1
        
        assert config.money_management.risk_percent == 10.0
        assert config.money_management.max_positions == 1
    
    def test_config_stop_loss(self):
        """Test de la configuration des stop loss"""
        config = StrategyConfig()
        
        config.stop_loss.sl_period = 30
        config.stop_loss.tp_period = 20
        config.stop_loss.min_rr = 2.0
        
        assert config.stop_loss.sl_period == 30
        assert config.stop_loss.tp_period == 20
        assert config.stop_loss.min_rr == 2.0
    
    def test_config_time_filter(self):
        """Test de la configuration du filtre temporel"""
        config = StrategyConfig()
        
        config.time_filter.use_time_filter = False
        config.time_filter.start_hour = 9
        config.time_filter.end_hour = 17
        config.time_filter.allowed_days = [1, 3, 5]  # Lundi, Mercredi, Vendredi
        
        assert config.time_filter.use_time_filter == False
        assert config.time_filter.start_hour == 9
        assert config.time_filter.end_hour == 17
        assert config.time_filter.allowed_days == [1, 3, 5]
    
    def test_config_backtest(self):
        """Test de la configuration du backtesting"""
        config = StrategyConfig()
        
        config.backtest.initial_capital = 50000
        config.backtest.commission = 0.0001
        config.backtest.slippage = 0.00005
        
        assert config.backtest.initial_capital == 50000
        assert config.backtest.commission == 0.0001
        assert config.backtest.slippage == 0.00005
    
    def test_config_live_trading(self):
        """Test de la configuration du trading en direct"""
        config = StrategyConfig()
        
        config.live_trading.enabled = False
        config.live_trading.max_daily_trades = 10
        config.live_trading.max_daily_loss = 500.0
        
        assert config.live_trading.enabled == False
        assert config.live_trading.max_daily_trades == 10
        assert config.live_trading.max_daily_loss == 500.0
    
    def test_config_logging(self):
        """Test de la configuration du logging"""
        config = StrategyConfig()
        
        config.logging.level = "INFO"
        config.logging.file_enabled = True
        config.logging.console_enabled = False
        
        assert config.logging.level == "INFO"
        assert config.logging.file_enabled == True
        assert config.logging.console_enabled == False
    
    def test_config_visualization(self):
        """Test de la configuration de la visualisation"""
        config = StrategyConfig()
        
        config.visualization.show_plots = False
        config.visualization.save_plots = True
        config.visualization.plot_size = (15, 10)
        
        assert config.visualization.show_plots == False
        assert config.visualization.save_plots == True
        assert config.visualization.plot_size == (15, 10)
    
    def test_config_consistency(self):
        """Test de cohérence de la configuration"""
        config = StrategyConfig()
        
        # Vérifier que les périodes EMA sont cohérentes
        assert config.ema.fast_period < config.ema.slow_period
        
        # Vérifier que les heures de trading sont cohérentes
        assert config.time_filter.start_hour < config.time_filter.end_hour
        
        # Vérifier que le risk_percent est positif
        assert config.money_management.risk_percent > 0
        
        # Vérifier que les périodes d'indicateurs sont positives
        assert config.bollinger.period > 0
        assert config.rsi.period > 0
        assert config.ema.fast_period > 0
        assert config.ema.slow_period > 0
    
    def test_config_preset_functions(self):
        """Test des fonctions de configuration prédéfinies"""
        # Test de la configuration conservatrice
        conservative_config = StrategyConfig.get_conservative_config()
        
        assert conservative_config.money_management.risk_percent < 2.0
        assert conservative_config.bollinger.deviation >= 2.0
        assert conservative_config.rsi.use_filter == True
        assert conservative_config.ema.use_filter == True
        
        # Test de la configuration agressive
        aggressive_config = StrategyConfig.get_aggressive_config()
        
        assert aggressive_config.money_management.risk_percent > 1.0
        assert aggressive_config.bollinger.deviation <= 2.0
        assert aggressive_config.money_management.max_positions >= 3
    
    def test_config_copy_and_modify(self):
        """Test de copie et modification de configuration"""
        original_config = StrategyConfig()
        modified_config = StrategyConfig()
        
        # Modifier une copie
        modified_config.bollinger.period = 30
        modified_config.rsi.period = 21
        
        # Vérifier que l'original n'est pas affecté
        assert original_config.bollinger.period == 20
        assert original_config.rsi.period == 14
        
        # Vérifier que la copie est modifiée
        assert modified_config.bollinger.period == 30
        assert modified_config.rsi.period == 21
    
    def test_config_edge_cases(self):
        """Test des cas limites de configuration"""
        config = StrategyConfig()
        
        # Valeurs minimales
        config.bollinger.period = 1
        config.rsi.period = 1
        config.ema.fast_period = 1
        config.ema.slow_period = 2
        
        assert config.bollinger.period == 1
        assert config.rsi.period == 1
        assert config.ema.fast_period == 1
        assert config.ema.slow_period == 2
        
        # Valeurs maximales
        config.bollinger.period = 200
        config.rsi.period = 100
        config.ema.fast_period = 100
        config.ema.slow_period = 200
        
        assert config.bollinger.period == 200
        assert config.rsi.period == 100
        assert config.ema.fast_period == 100
        assert config.ema.slow_period == 200
    
    def test_config_symbol_validation(self):
        """Test de validation des symboles"""
        config = StrategyConfig()
        
        # Test avec différents symboles
        test_symbols = ["EURUSD", "GBPUSD", "USDJPY", "US100.cash", "GOLD"]
        
        for symbol in test_symbols:
            config.symbol.symbol = symbol
            assert config.symbol.symbol == symbol
    
    def test_config_timeframe_validation(self):
        """Test de validation des timeframes"""
        config = StrategyConfig()
        
        # Test avec différents timeframes
        test_timeframes = ["M1", "M3", "M5", "M15", "M30", "H1", "H4", "D1"]
        
        for timeframe in test_timeframes:
            config.symbol.timeframe = timeframe
            assert config.symbol.timeframe == timeframe
    
    def test_config_boolean_flags(self):
        """Test des flags booléens"""
        config = StrategyConfig()
        
        # Tester tous les flags booléens
        config.rsi.use_filter = False
        config.ema.use_filter = False
        config.divergence.use_validator = False
        config.time_filter.use_time_filter = False
        config.money_management.one_pos_per_symbol = False
        config.live_trading.enabled = True
        config.logging.file_enabled = False
        config.logging.console_enabled = True
        config.visualization.show_plots = True
        config.visualization.save_plots = False
        
        assert config.rsi.use_filter == False
        assert config.ema.use_filter == False
        assert config.divergence.use_validator == False
        assert config.time_filter.use_time_filter == False
        assert config.money_management.one_pos_per_symbol == False
        assert config.live_trading.enabled == True
        assert config.logging.file_enabled == False
        assert config.logging.console_enabled == True
        assert config.visualization.show_plots == True
        assert config.visualization.save_plots == False
