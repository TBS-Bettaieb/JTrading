"""
Tests unitaires pour le gestionnaire de données
"""
import pytest
import pandas as pd
import numpy as np
from datetime import datetime
import tempfile
import os
import sys
from pathlib import Path

# Ajouter le répertoire Pyth au path
sys.path.insert(0, str(Path(__file__).parent.parent / 'Pyth'))

from data.data_manager import DataManager


class TestDataManager:
    """Tests pour le gestionnaire de données"""
    
    def test_data_manager_initialization(self):
        """Test d'initialisation du gestionnaire de données"""
        dm = DataManager()
        assert dm is not None
        assert hasattr(dm, 'cache_dir')
    
    def test_validate_ohlcv_valid_data(self, sample_ohlcv_data):
        """Test de validation avec des données valides"""
        dm = DataManager()
        is_valid, errors = dm.validate_ohlcv(sample_ohlcv_data)
        
        assert is_valid
        assert len(errors) == 0
    
    def test_validate_ohlcv_missing_columns(self):
        """Test de validation avec des colonnes manquantes"""
        dm = DataManager()
        
        # Données avec colonnes manquantes
        invalid_data = pd.DataFrame({
            'open': [100, 101, 102],
            'high': [101, 102, 103],
            # 'low' manquant
            'close': [100.5, 101.5, 102.5],
            'volume': [1000, 1100, 1200]
        })
        
        is_valid, errors = dm.validate_ohlcv(invalid_data)
        
        assert not is_valid
        assert any('low' in error.lower() for error in errors)
    
    def test_validate_ohlcv_invalid_values(self):
        """Test de validation avec des valeurs invalides"""
        dm = DataManager()
        
        # Données avec valeurs négatives
        invalid_data = pd.DataFrame({
            'open': [100, -101, 102],
            'high': [101, 102, 103],
            'low': [99, 100, 101],
            'close': [100.5, 101.5, 102.5],
            'volume': [1000, 1100, 1200]
        })
        
        is_valid, errors = dm.validate_ohlcv(invalid_data)
        
        assert not is_valid
        assert any('negative' in error.lower() for error in errors)
    
    def test_validate_ohlcv_ohlc_consistency(self):
        """Test de validation de la cohérence OHLC"""
        dm = DataManager()
        
        # Données avec high < low
        invalid_data = pd.DataFrame({
            'open': [100, 101, 102],
            'high': [99, 100, 101],  # high < low
            'low': [100, 101, 102],
            'close': [100.5, 101.5, 102.5],
            'volume': [1000, 1100, 1200]
        })
        
        is_valid, errors = dm.validate_ohlcv(invalid_data)
        
        assert not is_valid
        assert any('high' in error.lower() and 'low' in error.lower() for error in errors)
    
    def test_load_csv_valid_file(self, sample_ohlcv_data):
        """Test de chargement d'un fichier CSV valide"""
        dm = DataManager()
        
        # Créer un fichier temporaire
        with tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False) as f:
            sample_ohlcv_data.to_csv(f.name)
            temp_file = f.name
        
        try:
            loaded_data = dm.load_csv(temp_file)
            
            assert loaded_data is not None
            assert len(loaded_data) == len(sample_ohlcv_data)
            assert list(loaded_data.columns) == list(sample_ohlcv_data.columns)
        finally:
            os.unlink(temp_file)
    
    def test_load_csv_invalid_file(self):
        """Test de chargement d'un fichier CSV invalide"""
        dm = DataManager()
        
        # Fichier inexistant
        loaded_data = dm.load_csv('nonexistent_file.csv')
        assert loaded_data is None
    
    def test_save_csv(self, sample_ohlcv_data):
        """Test de sauvegarde en CSV"""
        dm = DataManager()
        
        # Créer un fichier temporaire
        with tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False) as f:
            temp_file = f.name
        
        try:
            success = dm.save_csv(sample_ohlcv_data, temp_file)
            assert success
            
            # Vérifier que le fichier a été créé
            assert os.path.exists(temp_file)
            
            # Vérifier le contenu
            loaded_data = dm.load_csv(temp_file)
            assert loaded_data is not None
            assert len(loaded_data) == len(sample_ohlcv_data)
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)
    
    def test_cache_data_and_load_from_cache(self, sample_ohlcv_data):
        """Test de mise en cache et chargement depuis le cache"""
        dm = DataManager()
        
        symbol = "TEST"
        timeframe = "M3"
        
        # Sauvegarder en cache
        success = dm.cache_data(sample_ohlcv_data, symbol, timeframe)
        assert success
        
        # Charger depuis le cache
        cached_data = dm.load_from_cache(symbol, timeframe)
        
        assert cached_data is not None
        assert len(cached_data) == len(sample_ohlcv_data)
        assert list(cached_data.columns) == list(sample_ohlcv_data.columns)
        
        # Vérifier que les données sont identiques
        pd.testing.assert_frame_equal(cached_data, sample_ohlcv_data)
    
    def test_load_from_cache_nonexistent(self):
        """Test de chargement depuis le cache avec des données inexistantes"""
        dm = DataManager()
        
        cached_data = dm.load_from_cache("NONEXISTENT", "H1")
        assert cached_data is None
    
    def test_resample_data(self, sample_ohlcv_data):
        """Test de resampling des données"""
        dm = DataManager()
        
        # Resampling de M3 vers H1
        resampled = dm.resample_data(sample_ohlcv_data, "H1")
        
        assert resampled is not None
        assert len(resampled) <= len(sample_ohlcv_data)  # Moins de données après resampling
        
        # Vérifier que les colonnes OHLCV sont présentes
        required_columns = ['open', 'high', 'low', 'close', 'volume']
        for col in required_columns:
            assert col in resampled.columns
    
    def test_resample_data_invalid_timeframe(self, sample_ohlcv_data):
        """Test de resampling avec un timeframe invalide"""
        dm = DataManager()
        
        resampled = dm.resample_data(sample_ohlcv_data, "INVALID")
        assert resampled is None
    
    def test_merge_data(self, sample_ohlcv_data):
        """Test de fusion de données"""
        dm = DataManager()
        
        # Créer deux datasets qui se chevauchent
        data1 = sample_ohlcv_data.iloc[:500]
        data2 = sample_ohlcv_data.iloc[400:]  # Chevauchement
        
        merged = dm.merge_data([data1, data2])
        
        assert merged is not None
        assert len(merged) >= len(data1)
        assert len(merged) >= len(data2)
        
        # Vérifier qu'il n'y a pas de doublons
        assert not merged.index.duplicated().any()
    
    def test_merge_data_no_overlap(self, sample_ohlcv_data):
        """Test de fusion de données sans chevauchement"""
        dm = DataManager()
        
        # Créer deux datasets sans chevauchement
        data1 = sample_ohlcv_data.iloc[:300]
        data2 = sample_ohlcv_data.iloc[300:]
        
        merged = dm.merge_data([data1, data2])
        
        assert merged is not None
        assert len(merged) == len(data1) + len(data2)
    
    def test_fill_missing_data(self, sample_ohlcv_data_with_gaps):
        """Test de remplissage des données manquantes"""
        dm = DataManager()
        
        filled_data = dm.fill_missing_data(sample_ohlcv_data_with_gaps)
        
        assert filled_data is not None
        assert len(filled_data) >= len(sample_ohlcv_data_with_gaps)
        
        # Vérifier qu'il n'y a pas de valeurs NaN dans les colonnes principales
        assert not filled_data['close'].isna().any()
        assert not filled_data['open'].isna().any()
        assert not filled_data['high'].isna().any()
        assert not filled_data['low'].isna().any()
    
    def test_fill_missing_data_no_gaps(self, sample_ohlcv_data):
        """Test de remplissage avec des données sans gaps"""
        dm = DataManager()
        
        filled_data = dm.fill_missing_data(sample_ohlcv_data)
        
        assert filled_data is not None
        assert len(filled_data) == len(sample_ohlcv_data)
    
    def test_get_data_info(self, sample_ohlcv_data):
        """Test d'obtention d'informations sur les données"""
        dm = DataManager()
        
        info = dm.get_data_info(sample_ohlcv_data)
        
        assert 'rows' in info
        assert 'columns' in info
        assert 'start_date' in info
        assert 'end_date' in info
        assert 'timeframe' in info
        
        assert info['rows'] == len(sample_ohlcv_data)
        assert info['columns'] == list(sample_ohlcv_data.columns)
        assert info['start_date'] == sample_ohlcv_data.index.min()
        assert info['end_date'] == sample_ohlcv_data.index.max()
    
    def test_data_manager_with_different_formats(self):
        """Test avec différents formats de données"""
        dm = DataManager()
        
        # Données avec index datetime
        dates = pd.date_range('2023-01-01', periods=100, freq='3min')
        data_with_datetime = pd.DataFrame({
            'open': np.random.uniform(100, 110, 100),
            'high': np.random.uniform(110, 120, 100),
            'low': np.random.uniform(90, 100, 100),
            'close': np.random.uniform(100, 110, 100),
            'volume': np.random.randint(1000, 10000, 100)
        }, index=dates)
        
        is_valid, errors = dm.validate_ohlcv(data_with_datetime)
        assert is_valid
        
        # Données avec index numérique
        data_with_numeric = data_with_datetime.reset_index(drop=True)
        is_valid, errors = dm.validate_ohlcv(data_with_numeric)
        assert is_valid  # Devrait toujours être valide
    
    def test_cache_cleanup(self, sample_ohlcv_data):
        """Test de nettoyage du cache"""
        dm = DataManager()
        
        symbol = "CLEANUP_TEST"
        timeframe = "M3"
        
        # Sauvegarder en cache
        dm.cache_data(sample_ohlcv_data, symbol, timeframe)
        
        # Vérifier que le fichier de cache existe
        cache_file = dm.cache_dir / f"{symbol}_{timeframe}.pkl"
        assert cache_file.exists()
        
        # Nettoyer le cache (simulation)
        if cache_file.exists():
            cache_file.unlink()
        
        # Vérifier que le cache a été nettoyé
        cached_data = dm.load_from_cache(symbol, timeframe)
        assert cached_data is None


class TestDataManagerIntegration:
    """Tests d'intégration pour le gestionnaire de données"""
    
    def test_full_data_workflow(self, sample_ohlcv_data):
        """Test du workflow complet de gestion des données"""
        dm = DataManager()
        
        symbol = "WORKFLOW_TEST"
        timeframe = "M3"
        
        # 1. Valider les données
        is_valid, errors = dm.validate_ohlcv(sample_ohlcv_data)
        assert is_valid
        
        # 2. Sauvegarder en cache
        success = dm.cache_data(sample_ohlcv_data, symbol, timeframe)
        assert success
        
        # 3. Charger depuis le cache
        cached_data = dm.load_from_cache(symbol, timeframe)
        assert cached_data is not None
        
        # 4. Resampler les données
        resampled = dm.resample_data(cached_data, "H1")
        assert resampled is not None
        
        # 5. Obtenir des informations
        info = dm.get_data_info(resampled)
        assert info['rows'] > 0
        
        # 6. Sauvegarder le résultat
        with tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False) as f:
            temp_file = f.name
        
        try:
            success = dm.save_csv(resampled, temp_file)
            assert success
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)
    
    def test_data_manager_with_real_market_data(self):
        """Test avec des données de marché réalistes"""
        dm = DataManager()
        
        # Créer des données plus réalistes
        dates = pd.date_range('2023-01-01', periods=1000, freq='3min')
        
        # Simulation de prix avec tendance et volatilité
        np.random.seed(42)
        base_price = 100.0
        trend = np.linspace(0, 5, 1000)  # Tendance haussière
        volatility = np.random.normal(0, 0.5, 1000)
        
        close_prices = base_price + trend + volatility
        
        realistic_data = []
        for i, close in enumerate(close_prices):
            # Générer OHLC réalistes
            high = close + abs(np.random.normal(0, 0.3))
            low = close - abs(np.random.normal(0, 0.3))
            open_price = close + np.random.normal(0, 0.1)
            volume = np.random.randint(1000, 10000)
            
            realistic_data.append({
                'open': open_price,
                'high': high,
                'low': low,
                'close': close,
                'volume': volume
            })
        
        df = pd.DataFrame(realistic_data, index=dates)
        
        # Tester toutes les fonctionnalités
        is_valid, errors = dm.validate_ohlcv(df)
        assert is_valid
        
        info = dm.get_data_info(df)
        assert info['rows'] == 1000
        assert info['timeframe'] == '3min'
        
        # Test de resampling
        resampled = dm.resample_data(df, "H1")
        assert resampled is not None
        assert len(resampled) < len(df)  # Moins de données après resampling
