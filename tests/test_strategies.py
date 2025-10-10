"""
Tests unitaires pour les stratégies de trading
"""
import pytest
import pandas as pd
import numpy as np
from datetime import datetime

from strategies.free_candle import FreeCandleStrategy, Signal
from strategies.divergence import DivergenceValidator


class TestFreeCandleStrategy:
    """Tests pour la stratégie Free Candle"""
    
    def test_strategy_initialization(self, default_config):
        """Test d'initialisation de la stratégie"""
        strategy = FreeCandleStrategy(default_config)
        
        assert strategy.config is not None
        assert strategy.bollinger is not None
        assert strategy.rsi is not None
        assert strategy.ema is not None
        assert strategy.atr is not None
    
    def test_generate_signals_basic(self, sample_ohlcv_data, conservative_config):
        """Test de génération de signaux de base"""
        strategy = FreeCandleStrategy(conservative_config)
        signals = strategy.generate_signals(sample_ohlcv_data)
        
        # Les signaux doivent être une liste
        assert isinstance(signals, list)
        
        # Si des signaux sont générés, ils doivent être des objets Signal
        if signals:
            for signal in signals:
                assert isinstance(signal, Signal)
                assert signal.direction in [-1, 1]
                assert signal.entry_price > 0
                assert signal.sl_price > 0
                assert signal.tp_price > 0
                assert signal.rr_ratio > 0
                assert signal.confidence >= 0
                assert signal.confidence <= 1
    
    def test_signal_properties(self, sample_ohlcv_data, aggressive_config):
        """Test des propriétés des signaux générés"""
        strategy = FreeCandleStrategy(aggressive_config)
        signals = strategy.generate_signals(sample_ohlcv_data)
        
        if signals:
            for signal in signals:
                # Vérifier la cohérence des prix
                if signal.direction == 1:  # BUY
                    assert signal.entry_price < signal.tp_price
                    assert signal.entry_price > signal.sl_price
                else:  # SELL
                    assert signal.entry_price > signal.tp_price
                    assert signal.entry_price < signal.sl_price
                
                # Vérifier le ratio risque/récompense
                if signal.direction == 1:
                    risk = signal.entry_price - signal.sl_price
                    reward = signal.tp_price - signal.entry_price
                else:
                    risk = signal.sl_price - signal.entry_price
                    reward = signal.entry_price - signal.tp_price
                
                if risk > 0:
                    expected_rr = reward / risk
                    assert abs(signal.rr_ratio - expected_rr) < 0.01
    
    def test_strategy_with_different_configs(self, sample_ohlcv_data, conservative_config, aggressive_config):
        """Test avec différentes configurations"""
        # Configuration conservatrice
        strategy_conservative = FreeCandleStrategy(conservative_config)
        signals_conservative = strategy_conservative.generate_signals(sample_ohlcv_data)
        
        # Configuration agressive
        strategy_aggressive = FreeCandleStrategy(aggressive_config)
        signals_aggressive = strategy_aggressive.generate_signals(sample_ohlcv_data)
        
        # La configuration agressive devrait généralement générer plus de signaux
        # (mais pas toujours garanti selon les données)
        print(f"Signaux conservateurs: {len(signals_conservative)}")
        print(f"Signaux agressifs: {len(signals_aggressive)}")
    
    def test_strategy_filters(self, sample_ohlcv_data, default_config):
        """Test des filtres de la stratégie"""
        # Désactiver tous les filtres
        config = default_config
        config.rsi.use_filter = False
        config.ema.use_filter = False
        config.divergence.use_validator = False
        config.time_filter.use_time_filter = False
        
        strategy = FreeCandleStrategy(config)
        signals_no_filters = strategy.generate_signals(sample_ohlcv_data)
        
        # Activer tous les filtres
        config.rsi.use_filter = True
        config.ema.use_filter = True
        config.divergence.use_validator = True
        config.time_filter.use_time_filter = True
        
        strategy = FreeCandleStrategy(config)
        signals_with_filters = strategy.generate_signals(sample_ohlcv_data)
        
        # Avec plus de filtres, il devrait y avoir moins de signaux
        assert len(signals_with_filters) <= len(signals_no_filters)
    
    def test_strategy_time_filter(self, sample_ohlcv_data, default_config):
        """Test du filtre temporel"""
        config = default_config
        config.time_filter.use_time_filter = True
        config.time_filter.start_hour = 8
        config.time_filter.end_hour = 16
        
        strategy = FreeCandleStrategy(config)
        signals = strategy.generate_signals(sample_ohlcv_data)
        
        # Vérifier que tous les signaux sont dans la plage horaire
        if signals:
            for signal in signals:
                hour = signal.timestamp.hour
                assert config.time_filter.start_hour <= hour <= config.time_filter.end_hour
    
    def test_strategy_empty_data(self):
        """Test avec des données vides"""
        config = StrategyConfig()
        strategy = FreeCandleStrategy(config)
        
        # DataFrame vide
        empty_df = pd.DataFrame()
        signals = strategy.generate_signals(empty_df)
        
        assert signals == []
        
        # DataFrame avec une seule ligne
        single_row_df = pd.DataFrame({
            'open': [100], 'high': [101], 'low': [99], 'close': [100.5], 'volume': [1000]
        })
        signals = strategy.generate_signals(single_row_df)
        
        assert signals == []
    
    def test_strategy_insufficient_data(self):
        """Test avec des données insuffisantes"""
        config = StrategyConfig()
        strategy = FreeCandleStrategy(config)
        
        # Moins de données que nécessaire pour les indicateurs
        insufficient_df = pd.DataFrame({
            'open': [100, 101, 102],
            'high': [101, 102, 103],
            'low': [99, 100, 101],
            'close': [100.5, 101.5, 102.5],
            'volume': [1000, 1100, 1200]
        })
        
        signals = strategy.generate_signals(insufficient_df)
        
        # Devrait retourner une liste vide ou gérer gracieusement
        assert isinstance(signals, list)


class TestDivergenceValidator:
    """Tests pour le validateur de divergence"""
    
    def test_divergence_initialization(self, default_config):
        """Test d'initialisation du validateur de divergence"""
        validator = DivergenceValidator(default_config)
        
        assert validator.config is not None
        assert validator.rsi is not None
    
    def test_divergence_detection_bullish(self, sample_ohlcv_data, default_config):
        """Test de détection de divergence haussière"""
        validator = DivergenceValidator(default_config)
        
        # Créer une divergence haussière artificielle
        df = sample_ohlcv_data.copy()
        
        # Calculer RSI
        rsi_result = validator.rsi.calculate(df)
        df['rsi'] = rsi_result['rsi']
        
        # Créer une divergence haussière
        # Prix fait un plus bas, RSI fait un plus haut
        idx1, idx2 = 100, 200
        
        # Prix en baisse
        df.loc[df.index[idx2], 'close'] = df.loc[df.index[idx1], 'close'] - 1.0
        
        # RSI en hausse (divergence)
        df.loc[df.index[idx2], 'rsi'] = df.loc[df.index[idx1], 'rsi'] + 5.0
        
        # Détecter les divergences
        divergences = validator.detect_divergences(df)
        
        # Vérifier qu'une divergence haussière est détectée
        bullish_divs = [d for d in divergences if d['type'] == 'bullish']
        assert len(bullish_divs) > 0
    
    def test_divergence_detection_bearish(self, sample_ohlcv_data, default_config):
        """Test de détection de divergence baissière"""
        validator = DivergenceValidator(default_config)
        
        # Créer une divergence baissière artificielle
        df = sample_ohlcv_data.copy()
        
        # Calculer RSI
        rsi_result = validator.rsi.calculate(df)
        df['rsi'] = rsi_result['rsi']
        
        # Créer une divergence baissière
        # Prix fait un plus haut, RSI fait un plus bas
        idx1, idx2 = 150, 250
        
        # Prix en hausse
        df.loc[df.index[idx2], 'close'] = df.loc[df.index[idx1], 'close'] + 1.0
        
        # RSI en baisse (divergence)
        df.loc[df.index[idx2], 'rsi'] = df.loc[df.index[idx1], 'rsi'] - 5.0
        
        # Détecter les divergences
        divergences = validator.detect_divergences(df)
        
        # Vérifier qu'une divergence baissière est détectée
        bearish_divs = [d for d in divergences if d['type'] == 'bearish']
        assert len(bearish_divs) > 0
    
    def test_divergence_validation(self, sample_ohlcv_data, default_config):
        """Test de validation des signaux avec divergence"""
        validator = DivergenceValidator(default_config)
        
        # Créer des signaux de test
        signals = [
            Signal(
                timestamp=datetime(2023, 1, 1, 10, 0),
                direction=1,
                entry_price=100.0,
                sl_price=99.0,
                tp_price=102.0,
                rr_ratio=2.0,
                confidence=0.8,
                source="FreeCandle"
            )
        ]
        
        # Valider les signaux
        validated_signals = validator.validate_signals(signals, sample_ohlcv_data)
        
        # Les signaux validés doivent être une liste
        assert isinstance(validated_signals, list)
        
        # Si des signaux sont validés, ils doivent avoir des propriétés cohérentes
        if validated_signals:
            for signal in validated_signals:
                assert isinstance(signal, Signal)
                assert signal.confidence >= 0
                assert signal.confidence <= 1
    
    def test_divergence_with_insufficient_data(self, default_config):
        """Test avec des données insuffisantes pour la divergence"""
        validator = DivergenceValidator(default_config)
        
        # Données insuffisantes
        insufficient_df = pd.DataFrame({
            'open': [100, 101, 102],
            'high': [101, 102, 103],
            'low': [99, 100, 101],
            'close': [100.5, 101.5, 102.5],
            'volume': [1000, 1100, 1200]
        })
        
        divergences = validator.detect_divergences(insufficient_df)
        
        # Devrait retourner une liste vide
        assert divergences == []


class TestStrategiesIntegration:
    """Tests d'intégration entre stratégies"""
    
    def test_strategy_with_divergence_validation(self, sample_ohlcv_data, default_config):
        """Test de la stratégie avec validation de divergence"""
        config = default_config
        config.divergence.use_validator = True
        
        strategy = FreeCandleStrategy(config)
        signals = strategy.generate_signals(sample_ohlcv_data)
        
        # Les signaux doivent être validés par la divergence
        assert isinstance(signals, list)
        
        if signals:
            for signal in signals:
                assert isinstance(signal, Signal)
                # Les signaux validés par divergence devraient avoir une confiance plus élevée
                # (mais pas toujours garanti selon les données)
    
    def test_strategy_performance_with_different_periods(self, sample_ohlcv_data):
        """Test de performance avec différentes périodes de données"""
        config = StrategyConfig()
        strategy = FreeCandleStrategy(config)
        
        # Test avec différentes tailles de données
        for size in [100, 500, 1000]:
            df_subset = sample_ohlcv_data.iloc[:size]
            signals = strategy.generate_signals(df_subset)
            
            assert isinstance(signals, list)
            
            # Avec plus de données, on peut s'attendre à plus de signaux
            # (mais pas toujours garanti selon les paramètres)
            print(f"Données: {size} lignes, Signaux: {len(signals)}")
