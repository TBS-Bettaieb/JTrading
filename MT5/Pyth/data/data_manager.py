"""
Data Manager
Gestion centralisée des données de marché
"""

import pandas as pd
import numpy as np
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
import os
import pickle


class DataManager:
    """
    Gestionnaire de données de marché
    
    Features:
    - Chargement de données historiques
    - Cache local des données
    - Gestion multi-symboles
    - Resampling de timeframes
    """
    
    def __init__(self, cache_dir: str = "data_cache"):
        """
        Args:
            cache_dir: Répertoire pour le cache des données
        """
        self.cache_dir = cache_dir
        
        # Créer le répertoire de cache s'il n'existe pas
        os.makedirs(cache_dir, exist_ok=True)
    
    def load_csv(
        self,
        filepath: str,
        date_column: str = 'time',
        parse_dates: bool = True
    ) -> pd.DataFrame:
        """
        Charge des données depuis un fichier CSV
        
        Args:
            filepath: Chemin du fichier CSV
            date_column: Nom de la colonne de date
            parse_dates: Parser les dates
        
        Returns:
            DataFrame avec les données
        """
        df = pd.read_csv(filepath, parse_dates=[date_column] if parse_dates else None)
        
        if parse_dates:
            df.set_index(date_column, inplace=True)
        
        return df
    
    def save_csv(
        self,
        df: pd.DataFrame,
        filepath: str,
        include_index: bool = True
    ):
        """
        Sauvegarde des données dans un fichier CSV
        
        Args:
            df: DataFrame à sauvegarder
            filepath: Chemin du fichier de sortie
            include_index: Inclure l'index dans le CSV
        """
        df.to_csv(filepath, index=include_index)
        print(f"✅ Données sauvegardées: {filepath}")
    
    def cache_data(
        self,
        df: pd.DataFrame,
        symbol: str,
        timeframe: str
    ):
        """
        Met en cache les données
        
        Args:
            df: DataFrame à cacher
            symbol: Symbole
            timeframe: Timeframe
        """
        cache_file = os.path.join(self.cache_dir, f"{symbol}_{timeframe}.pkl")
        
        with open(cache_file, 'wb') as f:
            pickle.dump(df, f)
        
        print(f"💾 Données cachées: {cache_file}")
    
    def load_from_cache(
        self,
        symbol: str,
        timeframe: str
    ) -> Optional[pd.DataFrame]:
        """
        Charge les données depuis le cache
        
        Args:
            symbol: Symbole
            timeframe: Timeframe
        
        Returns:
            DataFrame ou None si pas en cache
        """
        cache_file = os.path.join(self.cache_dir, f"{symbol}_{timeframe}.pkl")
        
        if not os.path.exists(cache_file):
            return None
        
        with open(cache_file, 'rb') as f:
            df = pickle.load(f)
        
        print(f"📂 Données chargées depuis cache: {cache_file}")
        return df
    
    def resample(
        self,
        df: pd.DataFrame,
        target_timeframe: str
    ) -> pd.DataFrame:
        """
        Resample les données vers un timeframe différent
        
        Args:
            df: DataFrame source avec OHLCV
            target_timeframe: Timeframe cible (ex: '4H', 'D', 'W')
        
        Returns:
            DataFrame resampleé
        """
        if not isinstance(df.index, pd.DatetimeIndex):
            raise ValueError("DataFrame doit avoir un DatetimeIndex")
        
        # Règles de resampling OHLCV
        ohlc_dict = {
            'open': 'first',
            'high': 'max',
            'low': 'min',
            'close': 'last',
            'volume': 'sum'
        }
        
        # Filtrer seulement les colonnes présentes
        available_cols = {k: v for k, v in ohlc_dict.items() if k in df.columns}
        
        # Resample
        df_resampled = df.resample(target_timeframe).agg(available_cols)
        
        # Supprimer les lignes avec NaN
        df_resampled.dropna(inplace=True)
        
        return df_resampled
    
    def merge_data(
        self,
        df1: pd.DataFrame,
        df2: pd.DataFrame,
        how: str = 'inner'
    ) -> pd.DataFrame:
        """
        Fusionne deux DataFrames
        
        Args:
            df1: Premier DataFrame
            df2: Second DataFrame
            how: Type de jointure ('inner', 'outer', 'left', 'right')
        
        Returns:
            DataFrame fusionné
        """
        return pd.merge(df1, df2, left_index=True, right_index=True, how=how)
    
    def fill_missing_data(
        self,
        df: pd.DataFrame,
        method: str = 'ffill'
    ) -> pd.DataFrame:
        """
        Remplit les données manquantes
        
        Args:
            df: DataFrame avec données manquantes
            method: Méthode de remplissage ('ffill', 'bfill', 'interpolate')
        
        Returns:
            DataFrame avec données remplies
        """
        if method == 'ffill':
            return df.fillna(method='ffill')
        elif method == 'bfill':
            return df.fillna(method='bfill')
        elif method == 'interpolate':
            return df.interpolate()
        else:
            raise ValueError(f"Méthode inconnue: {method}")
    
    def get_data_summary(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Obtient un résumé des données
        
        Args:
            df: DataFrame
        
        Returns:
            Dict avec statistiques
        """
        summary = {
            'rows': len(df),
            'columns': list(df.columns),
            'start_date': df.index[0] if len(df) > 0 else None,
            'end_date': df.index[-1] if len(df) > 0 else None,
            'missing_values': df.isnull().sum().to_dict(),
            'dtypes': df.dtypes.to_dict()
        }
        
        return summary
    
    def validate_ohlcv(self, df: pd.DataFrame) -> tuple:
        """
        Valide que le DataFrame contient les colonnes OHLCV
        
        Args:
            df: DataFrame à valider
        
        Returns:
            Tuple (is_valid, errors) où errors est une liste de messages d'erreur
        """
        errors = []
        required_cols = ['open', 'high', 'low', 'close']
        
        # Vérifier les colonnes requises
        for col in required_cols:
            if col not in df.columns:
                errors.append(f"Colonne manquante: {col}")
        
        if errors:
            return False, errors
        
        # Vérifier les valeurs négatives
        for col in required_cols:
            if (df[col] < 0).any():
                errors.append(f"Valeurs négatives détectées dans {col}")
        
        # Vérifier que high >= low
        if (df['high'] < df['low']).any():
            errors.append("Incohérence: High < Low détecté")
        
        # Vérifier que open/close sont entre high et low
        if ((df['open'] > df['high']) | (df['open'] < df['low'])).any():
            errors.append("Incohérence: Open hors de la plage High/Low")
        
        if ((df['close'] > df['high']) | (df['close'] < df['low'])).any():
            errors.append("Incohérence: Close hors de la plage High/Low")
        
        # Vérifier les valeurs NaN
        if df[required_cols].isnull().any().any():
            errors.append("Valeurs NaN détectées dans les colonnes OHLC")
        
        if errors:
            for error in errors:
                print(f"❌ {error}")
            return False, errors
        
        return True, []
    
    def __repr__(self) -> str:
        return f"DataManager(cache_dir='{self.cache_dir}')"


if __name__ == "__main__":
    # Test du data manager
    print("🔧 Test DataManager")
    print("=" * 60)
    
    # Créer le gestionnaire
    dm = DataManager()
    
    # Créer des données de test
    dates = pd.date_range('2024-01-01', periods=1000, freq='H')
    df_test = pd.DataFrame({
        'open': 1.1000 + np.cumsum(np.random.randn(1000) * 0.0001),
        'high': 1.1000 + np.cumsum(np.random.randn(1000) * 0.0001) + 0.0002,
        'low': 1.1000 + np.cumsum(np.random.randn(1000) * 0.0001) - 0.0002,
        'close': 1.1000 + np.cumsum(np.random.randn(1000) * 0.0001),
        'volume': np.random.randint(100, 1000, 1000)
    }, index=dates)
    
    # Valider
    print("\n✓ Validation OHLCV:")
    is_valid, errors = dm.validate_ohlcv(df_test)
    print(f"  Résultat: {'✅ Valide' if is_valid else '❌ Invalide'}")
    if errors:
        print(f"  Erreurs: {errors}")
    
    # Résumé
    print("\n📊 Résumé des données:")
    summary = dm.get_data_summary(df_test)
    for key, value in summary.items():
        if key != 'dtypes':
            print(f"  {key}: {value}")
    
    # Resample vers Daily
    print("\n🔄 Resampling H1 -> D1:")
    df_daily = dm.resample(df_test, 'D')
    print(f"  Lignes: {len(df_test)} -> {len(df_daily)}")
    
    # Cache
    print("\n💾 Test du cache:")
    dm.cache_data(df_test, "EURUSD", "H1")
    df_loaded = dm.load_from_cache("EURUSD", "H1")
    print(f"  Données rechargées: {len(df_loaded)} lignes")
    
    print("\n" + "=" * 60)
    print("✅ Test terminé")

