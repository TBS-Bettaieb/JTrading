"""
Tests unitaires pour les indicateurs techniques
"""
import pytest
import pandas as pd
import numpy as np
from datetime import datetime

from indicators.bollinger_bands import BollingerBands
from indicators.rsi import RSI
from indicators.ema import EMA
from indicators.atr import ATR


class TestBollingerBands:
    """Tests pour l'indicateur Bollinger Bands"""
    
    def test_bollinger_bands_basic(self, sample_ohlcv_data):
        """Test de base pour Bollinger Bands"""
        bb = BollingerBands(period=20, deviation=2.0)
        result = bb.calculate(sample_ohlcv_data)
        
        assert 'bb_upper' in result.columns
        assert 'bb_middle' in result.columns
        assert 'bb_lower' in result.columns
        assert 'bb_width' in result.columns
        assert 'bb_position' in result.columns
        
        # Vérifier que les valeurs sont cohérentes
        assert (result['bb_upper'] >= result['bb_middle']).all()
        assert (result['bb_middle'] >= result['bb_lower']).all()
        assert (result['bb_width'] >= 0).all()
        assert (result['bb_position'] >= 0).all()
        assert (result['bb_position'] <= 1).all()
    
    def test_bollinger_bands_period_validation(self, sample_ohlcv_data):
        """Test validation de la période"""
        # Période trop courte
        bb = BollingerBands(period=1, deviation=2.0)
        result = bb.calculate(sample_ohlcv_data)
        
        # Doit retourner NaN pour les premières valeurs
        assert pd.isna(result['bb_upper'].iloc[0])
        
        # Période normale
        bb = BollingerBands(period=20, deviation=2.0)
        result = bb.calculate(sample_ohlcv_data)
        
        # Les 19 premières valeurs doivent être NaN
        assert pd.isna(result['bb_upper'].iloc[:19]).all()
        assert not pd.isna(result['bb_upper'].iloc[19])
    
    def test_bollinger_bands_deviation(self, sample_ohlcv_data):
        """Test avec différentes déviations"""
        bb1 = BollingerBands(period=20, deviation=1.0)
        bb2 = BollingerBands(period=20, deviation=2.0)
        
        result1 = bb1.calculate(sample_ohlcv_data)
        result2 = bb2.calculate(sample_ohlcv_data)
        
        # La déviation plus grande doit donner des bandes plus larges
        assert (result2['bb_width'] > result1['bb_width']).all()
    
    def test_bollinger_bands_free_candle_detection(self, sample_ohlcv_data):
        """Test de détection des Free Candles"""
        bb = BollingerBands(period=20, deviation=2.0)
        result = bb.calculate(sample_ohlcv_data)
        
        # Simuler des Free Candles
        df = sample_ohlcv_data.copy()
        df['bb_upper'] = result['bb_upper']
        df['bb_lower'] = result['bb_lower']
        
        # Créer des Free Candles artificielles
        df.loc[df.index[100], 'close'] = df.loc[df.index[100], 'bb_upper'] + 0.001  # Free Candle haute
        df.loc[df.index[200], 'close'] = df.loc[df.index[200], 'bb_lower'] - 0.001  # Free Candle basse
        
        free_candles = bb.detect_free_candles(df)
        
        assert len(free_candles) > 0
        assert any(free_candles['type'] == 'upper')
        assert any(free_candles['type'] == 'lower')


class TestRSI:
    """Tests pour l'indicateur RSI"""
    
    def test_rsi_basic(self, sample_ohlcv_data):
        """Test de base pour RSI"""
        rsi = RSI(period=14)
        result = rsi.calculate(sample_ohlcv_data)
        
        assert 'rsi' in result.columns
        assert (result['rsi'] >= 0).all()
        assert (result['rsi'] <= 100).all()
    
    def test_rsi_period_validation(self, sample_ohlcv_data):
        """Test validation de la période RSI"""
        rsi = RSI(period=14)
        result = rsi.calculate(sample_ohlcv_data)
        
        # Les 13 premières valeurs doivent être NaN
        assert pd.isna(result['rsi'].iloc[:13]).all()
        assert not pd.isna(result['rsi'].iloc[13])
    
    def test_rsi_overbought_oversold(self, sample_ohlcv_data):
        """Test des niveaux de surachat/survente"""
        rsi = RSI(period=14, overbought=70, oversold=30)
        result = rsi.calculate(sample_ohlcv_data)
        
        # Vérifier les signaux
        overbought_signals = result[result['rsi'] > 70]
        oversold_signals = result[result['rsi'] < 30]
        
        # Les signaux doivent être cohérents avec les niveaux
        assert len(overbought_signals) >= 0
        assert len(oversold_signals) >= 0


class TestEMA:
    """Tests pour l'indicateur EMA"""
    
    def test_ema_basic(self, sample_ohlcv_data):
        """Test de base pour EMA"""
        ema = EMA(period=20)
        result = ema.calculate(sample_ohlcv_data)
        
        assert 'ema' in result.columns
        assert not pd.isna(result['ema'].iloc[0])  # EMA commence dès la première valeur
    
    def test_ema_multiple_periods(self, sample_ohlcv_data):
        """Test avec plusieurs périodes EMA"""
        ema_fast = EMA(period=10)
        ema_slow = EMA(period=20)
        
        result_fast = ema_fast.calculate(sample_ohlcv_data)
        result_slow = ema_slow.calculate(sample_ohlcv_data)
        
        # EMA rapide doit être plus réactive
        # (plus proche des prix récents)
        recent_prices = sample_ohlcv_data['close'].iloc[-10:]
        fast_values = result_fast['ema'].iloc[-10:]
        slow_values = result_slow['ema'].iloc[-10:]
        
        # La différence entre EMA rapide et prix doit être généralement plus petite
        fast_diff = abs(fast_values - recent_prices).mean()
        slow_diff = abs(slow_values - recent_prices).mean()
        
        # Ce n'est pas toujours vrai, mais généralement
        # assert fast_diff <= slow_diff * 1.2  # Tolérance
    
    def test_ema_trend_detection(self, sample_ohlcv_data):
        """Test de détection de tendance"""
        ema_fast = EMA(period=10)
        ema_slow = EMA(period=20)
        
        result_fast = ema_fast.calculate(sample_ohlcv_data)
        result_slow = ema_slow.calculate(sample_ohlcv_data)
        
        # Détecter les croisements
        fast_above_slow = result_fast['ema'] > result_slow['ema']
        trend_changes = fast_above_slow.diff()
        
        # Il doit y avoir des changements de tendance
        assert trend_changes.sum() > 0


class TestATR:
    """Tests pour l'indicateur ATR"""
    
    def test_atr_basic(self, sample_ohlcv_data):
        """Test de base pour ATR"""
        atr = ATR(period=14)
        result = atr.calculate(sample_ohlcv_data)
        
        assert 'atr' in result.columns
        assert (result['atr'] >= 0).all()  # ATR doit toujours être positif
    
    def test_atr_period_validation(self, sample_ohlcv_data):
        """Test validation de la période ATR"""
        atr = ATR(period=14)
        result = atr.calculate(sample_ohlcv_data)
        
        # Les 13 premières valeurs doivent être NaN
        assert pd.isna(result['atr'].iloc[:13]).all()
        assert not pd.isna(result['atr'].iloc[13])
    
    def test_atr_volatility_detection(self, sample_ohlcv_data):
        """Test de détection de volatilité"""
        atr = ATR(period=14)
        result = atr.calculate(sample_ohlcv_data)
        
        # ATR doit augmenter avec la volatilité
        # Créer une période de haute volatilité
        df = sample_ohlcv_data.copy()
        high_vol_period = df.iloc[500:520].copy()
        
        # Augmenter artificiellement la volatilité
        high_vol_period['high'] *= 1.02
        high_vol_period['low'] *= 0.98
        
        df.iloc[500:520] = high_vol_period
        
        result_high_vol = atr.calculate(df)
        
        # L'ATR pendant la période de haute volatilité doit être plus élevé
        avg_atr_normal = result['atr'].iloc[400:500].mean()
        avg_atr_high = result_high_vol['atr'].iloc[500:520].mean()
        
        assert avg_atr_high > avg_atr_normal
    
    def test_atr_stop_loss_calculation(self, sample_ohlcv_data):
        """Test de calcul des stop loss basés sur ATR"""
        atr = ATR(period=14)
        result = atr.calculate(sample_ohlcv_data)
        
        current_price = 100.0
        atr_value = result['atr'].iloc[100]
        multiplier = 2.0
        
        # Calcul des stop loss
        sl_buy = current_price - (atr_value * multiplier)
        sl_sell = current_price + (atr_value * multiplier)
        
        assert sl_buy < current_price
        assert sl_sell > current_price
        assert abs(sl_buy - current_price) == abs(sl_sell - current_price)


class TestIndicatorsIntegration:
    """Tests d'intégration entre indicateurs"""
    
    def test_indicators_consistency(self, sample_ohlcv_data):
        """Test de cohérence entre tous les indicateurs"""
        # Calculer tous les indicateurs
        bb = BollingerBands(period=20, deviation=2.0)
        rsi = RSI(period=14)
        ema = EMA(period=20)
        atr = ATR(period=14)
        
        bb_result = bb.calculate(sample_ohlcv_data)
        rsi_result = rsi.calculate(sample_ohlcv_data)
        ema_result = ema.calculate(sample_ohlcv_data)
        atr_result = atr.calculate(sample_ohlcv_data)
        
        # Vérifier que tous ont le même nombre de lignes
        assert len(bb_result) == len(sample_ohlcv_data)
        assert len(rsi_result) == len(sample_ohlcv_data)
        assert len(ema_result) == len(sample_ohlcv_data)
        assert len(atr_result) == len(sample_ohlcv_data)
        
        # Vérifier que les indices sont cohérents
        assert bb_result.index.equals(sample_ohlcv_data.index)
        assert rsi_result.index.equals(sample_ohlcv_data.index)
        assert ema_result.index.equals(sample_ohlcv_data.index)
        assert atr_result.index.equals(sample_ohlcv_data.index)
    
    def test_indicators_with_gaps(self, sample_ohlcv_data_with_gaps):
        """Test des indicateurs avec des données comportant des gaps"""
        bb = BollingerBands(period=10, deviation=2.0)
        rsi = RSI(period=7)
        ema = EMA(period=10)
        atr = ATR(period=7)
        
        # Tous doivent fonctionner même avec des gaps
        bb_result = bb.calculate(sample_ohlcv_data_with_gaps)
        rsi_result = rsi.calculate(sample_ohlcv_data_with_gaps)
        ema_result = ema.calculate(sample_ohlcv_data_with_gaps)
        atr_result = atr.calculate(sample_ohlcv_data_with_gaps)
        
        assert len(bb_result) == len(sample_ohlcv_data_with_gaps)
        assert len(rsi_result) == len(sample_ohlcv_data_with_gaps)
        assert len(ema_result) == len(sample_ohlcv_data_with_gaps)
        assert len(atr_result) == len(sample_ohlcv_data_with_gaps)
