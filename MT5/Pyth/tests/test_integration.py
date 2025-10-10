"""
Tests d'intégration end-to-end pour le système de trading
"""
import pytest
import pandas as pd
import numpy as np
from datetime import datetime
import tempfile
import os

from config import StrategyConfig, EntryMode
from strategies.free_candle import FreeCandleStrategy
from backtesting.engine import BacktestEngine
from data.data_manager import DataManager
from analysis.performance import PerformanceAnalyzer
from analysis.visualization import Visualizer


class TestEndToEndIntegration:
    """Tests d'intégration complets"""
    
    def test_full_trading_workflow(self, sample_ohlcv_data, conservative_config):
        """Test du workflow complet de trading"""
        # 1. Configuration
        config = conservative_config
        
        # 2. Génération des signaux
        strategy = FreeCandleStrategy(config)
        signals = strategy.generate_signals(sample_ohlcv_data)
        
        assert isinstance(signals, list)
        
        # 3. Backtesting
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        results = engine.run_backtest(sample_ohlcv_data, signals, config)
        
        assert results is not None
        assert results.initial_capital == 10000
        assert results.final_capital >= 0
        assert len(results.trades) >= 0
        
        # 4. Analyse de performance
        analyzer = PerformanceAnalyzer()
        performance_report = analyzer.generate_report(results, save_to_file=False)
        
        assert performance_report is not None
        assert len(performance_report) > 0
        
        # 5. Visualisation
        visualizer = Visualizer()
        
        # Test de création des graphiques (sans les afficher)
        with tempfile.TemporaryDirectory() as temp_dir:
            visualizer.create_dashboard(results, save_path=temp_dir, show=False)
            
            # Vérifier que les fichiers ont été créés
            expected_files = ['equity_curve.png', 'drawdown.png', 'profit_dist.png', 
                            'monthly_returns.png', 'dashboard.png']
            
            for file in expected_files:
                file_path = os.path.join(temp_dir, file)
                assert os.path.exists(file_path)
    
    def test_data_management_integration(self, sample_ohlcv_data):
        """Test d'intégration avec le gestionnaire de données"""
        dm = DataManager()
        
        # 1. Validation des données
        is_valid, errors = dm.validate_ohlcv(sample_ohlcv_data)
        assert is_valid
        
        # 2. Mise en cache
        success = dm.cache_data(sample_ohlcv_data, "TEST_INTEGRATION", "M3")
        assert success
        
        # 3. Chargement depuis le cache
        cached_data = dm.load_from_cache("TEST_INTEGRATION", "M3")
        assert cached_data is not None
        assert len(cached_data) == len(sample_ohlcv_data)
        
        # 4. Resampling
        resampled_data = dm.resample_data(cached_data, "H1")
        assert resampled_data is not None
        assert len(resampled_data) <= len(cached_data)
        
        # 5. Utilisation dans la stratégie
        config = StrategyConfig()
        strategy = FreeCandleStrategy(config)
        signals = strategy.generate_signals(resampled_data)
        
        assert isinstance(signals, list)
    
    def test_different_configurations_integration(self, sample_ohlcv_data):
        """Test d'intégration avec différentes configurations"""
        configs = [
            StrategyConfig.get_conservative_config(),
            StrategyConfig.get_aggressive_config()
        ]
        
        results = []
        
        for i, config in enumerate(configs):
            # Génération des signaux
            strategy = FreeCandleStrategy(config)
            signals = strategy.generate_signals(sample_ohlcv_data)
            
            # Backtesting
            engine = BacktestEngine(initial_capital=10000, commission=0.0002)
            backtest_results = engine.run_backtest(sample_ohlcv_data, signals, config)
            
            results.append({
                'config_type': 'conservative' if i == 0 else 'aggressive',
                'results': backtest_results,
                'signals_count': len(signals)
            })
        
        # Vérifier que les deux configurations ont produit des résultats
        assert len(results) == 2
        assert all(r['results'] is not None for r in results)
        
        # Généralement, la configuration agressive devrait avoir plus de signaux
        # (mais pas toujours garanti selon les données)
        print(f"Signaux conservateurs: {results[0]['signals_count']}")
        print(f"Signaux agressifs: {results[1]['signals_count']}")
    
    def test_strategy_with_all_filters(self, sample_ohlcv_data):
        """Test de la stratégie avec tous les filtres activés"""
        config = StrategyConfig()
        
        # Activer tous les filtres
        config.rsi.use_filter = True
        config.ema.use_filter = True
        config.divergence.use_validator = True
        config.time_filter.use_time_filter = True
        
        # Configuration restrictive
        config.rsi.oversold = 20
        config.rsi.overbought = 80
        config.bollinger.deviation = 2.5
        
        strategy = FreeCandleStrategy(config)
        signals = strategy.generate_signals(sample_ohlcv_data)
        
        assert isinstance(signals, list)
        
        # Avec tous les filtres, il devrait y avoir moins de signaux
        # mais des signaux de meilleure qualité
        if signals:
            for signal in signals:
                assert signal.confidence >= 0
                assert signal.confidence <= 1
                assert signal.rr_ratio > 0
    
    def test_backtesting_with_realistic_scenarios(self, sample_ohlcv_data):
        """Test de backtesting avec des scénarios réalistes"""
        config = StrategyConfig()
        config.money_management.risk_percent = 1.0
        config.money_management.max_positions = 2
        
        strategy = FreeCandleStrategy(config)
        signals = strategy.generate_signals(sample_ohlcv_data)
        
        if signals:
            # Simuler différents scénarios de commission
            commission_scenarios = [0.0, 0.0001, 0.0002, 0.0005]
            
            results = []
            for commission in commission_scenarios:
                engine = BacktestEngine(initial_capital=10000, commission=commission)
                backtest_results = engine.run_backtest(sample_ohlcv_data, signals, config)
                results.append({
                    'commission': commission,
                    'final_capital': backtest_results.final_capital,
                    'net_profit': backtest_results.net_profit
                })
            
            # Vérifier que des commissions plus élevées réduisent le profit
            for i in range(1, len(results)):
                if results[i-1]['net_profit'] > 0:  # Seulement si le profit est positif
                    assert results[i]['net_profit'] <= results[i-1]['net_profit']
    
    def test_performance_analysis_integration(self, sample_ohlcv_data, sample_trades):
        """Test d'intégration de l'analyse de performance"""
        from backtesting.engine import BacktestResults
        
        # Créer des résultats de backtest
        results = BacktestResults(
            initial_capital=10000,
            final_capital=12000,
            trades=sample_trades,
            equity_curve=[10000, 10100, 10200, 12000],
            timestamps=[datetime(2023, 1, 1), datetime(2023, 1, 2), 
                       datetime(2023, 1, 3), datetime(2023, 1, 4)]
        )
        
        # Analyse de performance
        analyzer = PerformanceAnalyzer()
        
        # Test de génération de rapport
        report = analyzer.generate_report(results, save_to_file=False)
        assert report is not None
        assert len(report) > 0
        assert "Capital Initial" in report
        assert "Capital Final" in report
        
        # Test de sauvegarde de rapport
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            temp_file = f.name
        
        try:
            analyzer.generate_report(results, save_to_file=temp_file)
            assert os.path.exists(temp_file)
            
            # Vérifier le contenu du fichier
            with open(temp_file, 'r', encoding='utf-8') as f:
                content = f.read()
                assert len(content) > 0
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)
    
    def test_visualization_integration(self, sample_trades):
        """Test d'intégration de la visualisation"""
        from backtesting.engine import BacktestResults
        
        # Créer des résultats de backtest
        results = BacktestResults(
            initial_capital=10000,
            final_capital=12000,
            trades=sample_trades,
            equity_curve=[10000, 10100, 10200, 12000],
            timestamps=[datetime(2023, 1, 1), datetime(2023, 1, 2), 
                       datetime(2023, 1, 3), datetime(2023, 1, 4)]
        )
        
        visualizer = Visualizer()
        
        # Test de création de tous les graphiques
        with tempfile.TemporaryDirectory() as temp_dir:
            # Test de chaque type de graphique
            visualizer.plot_equity_curve(results, save_path=temp_dir, show=False)
            visualizer.plot_drawdown(results, save_path=temp_dir, show=False)
            visualizer.plot_profit_distribution(results, save_path=temp_dir, show=False)
            visualizer.plot_monthly_returns(results, save_path=temp_dir, show=False)
            visualizer.create_dashboard(results, save_path=temp_dir, show=False)
            
            # Vérifier que tous les fichiers ont été créés
            expected_files = [
                'equity_curve.png',
                'drawdown.png', 
                'profit_dist.png',
                'monthly_returns.png',
                'dashboard.png'
            ]
            
            for file in expected_files:
                file_path = os.path.join(temp_dir, file)
                assert os.path.exists(file_path)
    
    def test_error_handling_integration(self):
        """Test de gestion d'erreurs en intégration"""
        # Test avec des données invalides
        invalid_data = pd.DataFrame({
            'open': [100, -101, 102],  # Valeur négative
            'high': [99, 100, 101],    # high < low
            'low': [100, 101, 102],
            'close': [100.5, 101.5, 102.5],
            'volume': [1000, 1100, 1200]
        })
        
        dm = DataManager()
        is_valid, errors = dm.validate_ohlcv(invalid_data)
        assert not is_valid
        assert len(errors) > 0
        
        # Test avec des données vides
        empty_data = pd.DataFrame()
        strategy = FreeCandleStrategy(StrategyConfig())
        signals = strategy.generate_signals(empty_data)
        assert signals == []
        
        # Test avec des signaux vides
        engine = BacktestEngine(initial_capital=10000, commission=0.0002)
        results = engine.run_backtest(invalid_data, [], StrategyConfig())
        assert results is not None
        assert results.initial_capital == results.final_capital
    
    def test_memory_and_performance_integration(self, sample_ohlcv_data):
        """Test de mémoire et performance en intégration"""
        # Test avec une grande quantité de données
        large_data = pd.concat([sample_ohlcv_data] * 10)  # 10x plus de données
        
        config = StrategyConfig()
        strategy = FreeCandleStrategy(config)
        
        # Mesurer le temps d'exécution
        import time
        start_time = time.time()
        
        signals = strategy.generate_signals(large_data)
        
        end_time = time.time()
        execution_time = end_time - start_time
        
        print(f"Temps d'exécution pour {len(large_data)} barres: {execution_time:.2f}s")
        
        # L'exécution ne devrait pas prendre trop de temps
        assert execution_time < 60  # Moins d'une minute
        
        # Test du backtesting avec beaucoup de données
        if signals:
            engine = BacktestEngine(initial_capital=10000, commission=0.0002)
            
            start_time = time.time()
            results = engine.run_backtest(large_data, signals, config)
            end_time = time.time()
            
            backtest_time = end_time - start_time
            print(f"Temps de backtest: {backtest_time:.2f}s")
            
            assert results is not None
            assert backtest_time < 120  # Moins de 2 minutes
    
    def test_configuration_consistency_integration(self):
        """Test de cohérence des configurations en intégration"""
        configs = [
            StrategyConfig(),
            StrategyConfig.get_conservative_config(),
            StrategyConfig.get_aggressive_config()
        ]
        
        for config in configs:
            # Vérifier la cohérence interne
            assert config.ema.fast_period < config.ema.slow_period
            assert config.time_filter.start_hour < config.time_filter.end_hour
            assert config.money_management.risk_percent > 0
            assert config.bollinger.period > 0
            assert config.rsi.period > 0
            
            # Vérifier que la stratégie peut être initialisée
            strategy = FreeCandleStrategy(config)
            assert strategy is not None
            assert strategy.config == config
    
    def test_full_system_with_different_symbols(self):
        """Test du système complet avec différents symboles"""
        symbols = ["EURUSD", "GBPUSD", "USDJPY"]
        timeframes = ["M3", "H1"]
        
        # Créer des données simulées pour chaque symbole
        for symbol in symbols:
            for timeframe in timeframes:
                # Créer des données simulées
                dates = pd.date_range('2023-01-01', periods=500, freq='3min' if timeframe == 'M3' else '1H')
                data = pd.DataFrame({
                    'open': np.random.uniform(100, 110, 500),
                    'high': np.random.uniform(110, 120, 500),
                    'low': np.random.uniform(90, 100, 500),
                    'close': np.random.uniform(100, 110, 500),
                    'volume': np.random.randint(1000, 10000, 500)
                }, index=dates)
                
                # Test complet du workflow
                config = StrategyConfig()
                config.symbol.symbol = symbol
                config.symbol.timeframe = timeframe
                
                strategy = FreeCandleStrategy(config)
                signals = strategy.generate_signals(data)
                
                engine = BacktestEngine(initial_capital=10000, commission=0.0002)
                results = engine.run_backtest(data, signals, config)
                
                assert results is not None
                assert results.initial_capital == 10000
                
                print(f"Symbole: {symbol}, Timeframe: {timeframe}, Signaux: {len(signals)}, Trades: {len(results.trades)}")
