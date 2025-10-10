"""
Bollinger Bands Indicator
Conversion Python de l'indicateur BB MQL5
"""

import pandas as pd
import numpy as np
from typing import Tuple, Optional


class BollingerBands:
    """
    Calcule les Bollinger Bands
    
    Parameters:
        period: Période pour la moyenne mobile (défaut: 20)
        deviation: Nombre d'écarts-types (défaut: 2.0)
        shift: Décalage de l'indicateur (défaut: 0)
    """
    
    def __init__(self, period: int = 20, deviation: float = 2.0, shift: int = 0):
        self.period = period
        self.deviation = deviation
        self.shift = shift
        self._last_values = {}
    
    def calculate(self, df: pd.DataFrame, price_column: str = 'close') -> pd.DataFrame:
        """
        Calcule les Bollinger Bands sur un DataFrame
        
        Args:
            df: DataFrame avec colonnes OHLCV
            price_column: Colonne de prix à utiliser (défaut: 'close')
        
        Returns:
            DataFrame avec colonnes bb_upper, bb_middle, bb_lower ajoutées
        """
        df = df.copy()
        
        # Calculer la moyenne mobile (ligne médiane)
        df['bb_middle'] = df[price_column].rolling(window=self.period).mean()
        
        # Calculer l'écart-type
        std = df[price_column].rolling(window=self.period).std()
        
        # Calculer les bandes supérieure et inférieure
        df['bb_upper'] = df['bb_middle'] + (self.deviation * std)
        df['bb_lower'] = df['bb_middle'] - (self.deviation * std)
        
        # Appliquer le shift si nécessaire
        if self.shift != 0:
            df['bb_upper'] = df['bb_upper'].shift(self.shift)
            df['bb_middle'] = df['bb_middle'].shift(self.shift)
            df['bb_lower'] = df['bb_lower'].shift(self.shift)
        
        # Calculer la largeur des bandes (utile pour l'analyse)
        df['bb_width'] = df['bb_upper'] - df['bb_lower']
        
        # Calculer le %B (position du prix dans les bandes)
        df['bb_percent'] = (df[price_column] - df['bb_lower']) / df['bb_width']
        
        return df
    
    def get_current_values(self, df: pd.DataFrame) -> dict:
        """
        Retourne les valeurs actuelles des bandes
        
        Returns:
            dict avec 'upper', 'middle', 'lower', 'width', 'percent'
        """
        if len(df) == 0:
            return None
        
        last_row = df.iloc[-1]
        return {
            'upper': last_row.get('bb_upper', np.nan),
            'middle': last_row.get('bb_middle', np.nan),
            'lower': last_row.get('bb_lower', np.nan),
            'width': last_row.get('bb_width', np.nan),
            'percent': last_row.get('bb_percent', np.nan),
        }
    
    def is_free_candle(
        self, 
        row: pd.Series, 
        padding_points: float = 0, 
        body_only: bool = True,
        point_size: float = 0.0001
    ) -> Tuple[bool, int]:
        """
        Détecte si une bougie est "libre" (en dehors des Bollinger Bands)
        
        Args:
            row: Série pandas avec colonnes open, high, low, close, bb_upper, bb_lower
            padding_points: Marge supplémentaire en points au-delà de la bande
            body_only: Si True, ne vérifie que le corps de la bougie
            point_size: Taille d'un point pour le symbole
        
        Returns:
            Tuple (is_free, direction) où:
                - is_free: True si la bougie est hors des bandes
                - direction: 1 pour BUY (en-dessous), -1 pour SELL (au-dessus), 0 sinon
        """
        padding = padding_points * point_size
        
        if body_only:
            # Vérifier uniquement le corps de la bougie
            body_high = max(row['open'], row['close'])
            body_low = min(row['open'], row['close'])
            
            # Bougie au-dessus de la bande supérieure (signal SELL pour reversion)
            if body_low > row['bb_upper'] + padding:
                return True, -1
            
            # Bougie en-dessous de la bande inférieure (signal BUY pour reversion)
            if body_high < row['bb_lower'] - padding:
                return True, 1
        else:
            # Vérifier toute la bougie (incluant les mèches)
            # Bougie au-dessus de la bande supérieure
            if row['low'] > row['bb_upper'] + padding:
                return True, -1
            
            # Bougie en-dessous de la bande inférieure
            if row['high'] < row['bb_lower'] - padding:
                return True, 1
        
        return False, 0
    
    def is_touching_band(
        self, 
        row: pd.Series, 
        band: str = 'upper',
        tolerance_points: float = 5,
        point_size: float = 0.0001
    ) -> bool:
        """
        Vérifie si le prix touche une bande
        
        Args:
            row: Série pandas avec les données de prix et BB
            band: 'upper' ou 'lower'
            tolerance_points: Tolérance de touche en points
            point_size: Taille d'un point
        
        Returns:
            True si le prix touche la bande
        """
        tolerance = tolerance_points * point_size
        
        if band == 'upper':
            band_level = row['bb_upper']
            return row['high'] >= band_level - tolerance
        elif band == 'lower':
            band_level = row['bb_lower']
            return row['low'] <= band_level + tolerance
        elif band == 'middle':
            band_level = row['bb_middle']
            return (row['low'] <= band_level + tolerance and 
                    row['high'] >= band_level - tolerance)
        
        return False
    
    def get_band_squeeze(self, df: pd.DataFrame, lookback: int = 20) -> float:
        """
        Calcule l'indicateur de squeeze (contraction des bandes)
        
        Args:
            df: DataFrame avec colonnes BB
            lookback: Période de référence
        
        Returns:
            Valeur normalisée (0-1) indiquant le niveau de squeeze
        """
        if len(df) < lookback:
            return 0.0
        
        current_width = df.iloc[-1]['bb_width']
        historical_widths = df.iloc[-lookback:]['bb_width']
        
        min_width = historical_widths.min()
        max_width = historical_widths.max()
        
        if max_width == min_width:
            return 0.5
        
        # Normaliser entre 0 et 1 (0 = squeeze maximum, 1 = expansion maximum)
        normalized = (current_width - min_width) / (max_width - min_width)
        
        return normalized
    
    def __repr__(self) -> str:
        return f"BollingerBands(period={self.period}, deviation={self.deviation}, shift={self.shift})"


if __name__ == "__main__":
    # Test de l'indicateur
    import matplotlib.pyplot as plt
    
    # Créer des données de test
    np.random.seed(42)
    dates = pd.date_range('2024-01-01', periods=100, freq='H')
    close_prices = 1.1000 + np.cumsum(np.random.randn(100) * 0.0002)
    
    df_test = pd.DataFrame({
        'close': close_prices,
        'open': close_prices - 0.0001,
        'high': close_prices + 0.0003,
        'low': close_prices - 0.0003,
    }, index=dates)
    
    # Calculer les Bollinger Bands
    bb = BollingerBands(period=20, deviation=2.0)
    df_test = bb.calculate(df_test)
    
    # Afficher les résultats
    print("Dernières valeurs:")
    print(df_test[['close', 'bb_upper', 'bb_middle', 'bb_lower']].tail())
    
    print("\nValeurs actuelles:")
    print(bb.get_current_values(df_test))
    
    # Visualisation
    plt.figure(figsize=(12, 6))
    plt.plot(df_test.index, df_test['close'], label='Close', color='black', linewidth=1.5)
    plt.plot(df_test.index, df_test['bb_upper'], label='BB Upper', color='red', linestyle='--')
    plt.plot(df_test.index, df_test['bb_middle'], label='BB Middle', color='blue', linestyle='-')
    plt.plot(df_test.index, df_test['bb_lower'], label='BB Lower', color='green', linestyle='--')
    plt.fill_between(df_test.index, df_test['bb_upper'], df_test['bb_lower'], alpha=0.1)
    plt.legend()
    plt.title('Bollinger Bands Test')
    plt.xlabel('Time')
    plt.ylabel('Price')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig('bb_test.png', dpi=150)
    print("\nGraphique sauvegardé: bb_test.png")

