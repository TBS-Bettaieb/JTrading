"""
EMA (Exponential Moving Average) Indicator
Conversion Python de l'indicateur EMA MQL5
"""

import pandas as pd
import numpy as np
from typing import List, Optional, Tuple


class EMA:
    """
    Calcule les moyennes mobiles exponentielles (EMA)
    
    Parameters:
        periods: Liste des périodes EMA à calculer (ex: [50, 100])
    """
    
    def __init__(self, periods: List[int] = None):
        if periods is None:
            periods = [50, 100]
        self.periods = periods
    
    def calculate(self, df: pd.DataFrame, price_column: str = 'close', inplace: bool = False) -> pd.DataFrame:
        """
        Calcule les EMAs et les ajoute au DataFrame
        
        Args:
            df: DataFrame avec les données de prix
            price_column: Colonne de prix à utiliser
            inplace: Si True, modifie le DataFrame original (plus rapide)
        
        Returns:
            DataFrame avec colonnes 'ema_X' ajoutées pour chaque période
        """
        if not inplace:
            df = df.copy()
        
        for period in self.periods:
            col_name = f'ema_{period}'
            df[col_name] = df[price_column].ewm(span=period, adjust=False).mean()
        
        return df
    
    def get_trend(
        self, 
        df: pd.DataFrame, 
        fast_period: int = None, 
        slow_period: int = None
    ) -> str:
        """
        Détermine la tendance basée sur le croisement des EMAs
        
        Args:
            df: DataFrame avec colonnes EMA
            fast_period: Période EMA rapide
            slow_period: Période EMA lente
        
        Returns:
            'uptrend', 'downtrend', ou 'neutral'
        """
        if fast_period is None:
            fast_period = min(self.periods)
        if slow_period is None:
            slow_period = max(self.periods)
        
        fast_col = f'ema_{fast_period}'
        slow_col = f'ema_{slow_period}'
        
        if fast_col not in df.columns or slow_col not in df.columns:
            return 'neutral'
        
        fast_ema = df[fast_col].iloc[-1]
        slow_ema = df[slow_col].iloc[-1]
        
        if fast_ema > slow_ema:
            return 'uptrend'
        elif fast_ema < slow_ema:
            return 'downtrend'
        else:
            return 'neutral'
    
    def detect_crossover(
        self, 
        df: pd.DataFrame, 
        fast_period: int = None, 
        slow_period: int = None
    ) -> Tuple[bool, str]:
        """
        Détecte un croisement des EMAs
        
        Returns:
            Tuple (has_crossover, type) où type est 'bullish', 'bearish', ou 'none'
        """
        if len(df) < 2:
            return False, 'none'
        
        if fast_period is None:
            fast_period = min(self.periods)
        if slow_period is None:
            slow_period = max(self.periods)
        
        fast_col = f'ema_{fast_period}'
        slow_col = f'ema_{slow_period}'
        
        if fast_col not in df.columns or slow_col not in df.columns:
            return False, 'none'
        
        # Valeurs actuelles
        fast_now = df[fast_col].iloc[-1]
        slow_now = df[slow_col].iloc[-1]
        
        # Valeurs précédentes
        fast_prev = df[fast_col].iloc[-2]
        slow_prev = df[slow_col].iloc[-2]
        
        # Croisement haussier (golden cross)
        if fast_prev <= slow_prev and fast_now > slow_now:
            return True, 'bullish'
        
        # Croisement baissier (death cross)
        if fast_prev >= slow_prev and fast_now < slow_now:
            return True, 'bearish'
        
        return False, 'none'
    
    def check_ema_filter(
        self, 
        df: pd.DataFrame, 
        signal_direction: int,
        fast_period: int = 50,
        slow_period: int = 100,
        mode: str = 'TREND',
        zone_distance: float = 20.0,
        point_size: float = 0.0001
    ) -> bool:
        """
        Vérifie le filtre EMA selon le mode configuré
        (Reproduction de la logique MQL5 CheckEMAFilter)
        
        Args:
            df: DataFrame avec données et EMAs
            signal_direction: 1 pour BUY, -1 pour SELL
            fast_period: Période EMA rapide
            slow_period: Période EMA lente
            mode: 'TREND', 'COUNTER', ou 'ZONE'
            zone_distance: Distance pour le mode ZONE (en points)
            point_size: Taille d'un point
        
        Returns:
            True si le filtre passe
        """
        fast_col = f'ema_{fast_period}'
        slow_col = f'ema_{slow_period}'
        
        if fast_col not in df.columns or slow_col not in df.columns:
            return True
        
        ema_fast = df[fast_col].iloc[-1]
        ema_slow = df[slow_col].iloc[-1]
        price = df['close'].iloc[-1]
        
        uptrend = ema_fast > ema_slow
        downtrend = ema_fast < ema_slow
        
        if mode == 'TREND':
            # Mode TREND: Trade dans le sens de la tendance
            if signal_direction > 0:  # BUY signal
                return uptrend and (price > ema_slow)
            else:  # SELL signal
                return downtrend and (price < ema_slow)
        
        elif mode == 'COUNTER':
            # Mode COUNTER: Trade les retournements aux extrêmes
            distance_points = abs(price - ema_fast) / point_size
            
            if signal_direction > 0:  # BUY signal
                return downtrend and (price < ema_fast) and (distance_points > zone_distance)
            else:  # SELL signal
                return uptrend and (price > ema_fast) and (distance_points > zone_distance)
        
        elif mode == 'ZONE':
            # Mode ZONE: Évite la zone neutre entre les EMAs
            max_ema = max(ema_fast, ema_slow)
            min_ema = min(ema_fast, ema_slow)
            zone_margin = zone_distance * point_size
            
            # Prix dans la zone neutre?
            in_zone = (price < max_ema + zone_margin) and (price > min_ema - zone_margin)
            
            return not in_zone
        
        return True
    
    def get_distance_to_ema(
        self, 
        df: pd.DataFrame, 
        period: int, 
        in_points: bool = True,
        point_size: float = 0.0001
    ) -> float:
        """
        Calcule la distance du prix actuel à une EMA
        
        Args:
            df: DataFrame avec données
            period: Période de l'EMA
            in_points: Si True, retourne en points, sinon en prix
            point_size: Taille d'un point
        
        Returns:
            Distance (positive si au-dessus, négative si en-dessous)
        """
        ema_col = f'ema_{period}'
        
        if ema_col not in df.columns:
            return 0.0
        
        price = df['close'].iloc[-1]
        ema_value = df[ema_col].iloc[-1]
        
        distance = price - ema_value
        
        if in_points:
            return distance / point_size
        
        return distance
    
    def is_price_above_all_emas(self, df: pd.DataFrame) -> bool:
        """Vérifie si le prix est au-dessus de toutes les EMAs"""
        price = df['close'].iloc[-1]
        
        for period in self.periods:
            ema_col = f'ema_{period}'
            if ema_col in df.columns:
                if price < df[ema_col].iloc[-1]:
                    return False
        
        return True
    
    def is_price_below_all_emas(self, df: pd.DataFrame) -> bool:
        """Vérifie si le prix est en-dessous de toutes les EMAs"""
        price = df['close'].iloc[-1]
        
        for period in self.periods:
            ema_col = f'ema_{period}'
            if ema_col in df.columns:
                if price > df[ema_col].iloc[-1]:
                    return False
        
        return True
    
    def get_ema_alignment(self, df: pd.DataFrame) -> str:
        """
        Vérifie l'alignement des EMAs
        
        Returns:
            'bullish' si EMAs alignées croissantes, 'bearish' si décroissantes, 'mixed' sinon
        """
        ema_values = []
        for period in sorted(self.periods):
            ema_col = f'ema_{period}'
            if ema_col in df.columns:
                ema_values.append(df[ema_col].iloc[-1])
        
        if len(ema_values) < 2:
            return 'mixed'
        
        # Vérifier si les EMAs sont alignées croissantes (bullish)
        if all(ema_values[i] < ema_values[i+1] for i in range(len(ema_values)-1)):
            return 'bullish'
        
        # Vérifier si les EMAs sont alignées décroissantes (bearish)
        if all(ema_values[i] > ema_values[i+1] for i in range(len(ema_values)-1)):
            return 'bearish'
        
        return 'mixed'
    
    def __repr__(self) -> str:
        return f"EMA(periods={self.periods})"


if __name__ == "__main__":
    # Test de l'indicateur
    import matplotlib.pyplot as plt
    
    # Créer des données de test
    np.random.seed(42)
    dates = pd.date_range('2024-01-01', periods=300, freq='H')
    close_prices = 1.1000 + np.cumsum(np.random.randn(300) * 0.0003)
    
    df_test = pd.DataFrame({
        'close': close_prices,
        'open': close_prices - 0.0001,
        'high': close_prices + 0.0002,
        'low': close_prices - 0.0002,
    }, index=dates)
    
    # Calculer les EMAs
    ema = EMA(periods=[20, 50, 100, 200])
    df_test = ema.calculate(df_test)
    
    # Afficher les résultats
    print("Dernières valeurs:")
    print(df_test[['close', 'ema_20', 'ema_50', 'ema_100', 'ema_200']].tail())
    
    trend = ema.get_trend(df_test, 50, 100)
    alignment = ema.get_ema_alignment(df_test)
    
    print(f"\nTendance (EMA 50/100): {trend}")
    print(f"Alignement des EMAs: {alignment}")
    
    has_cross, cross_type = ema.detect_crossover(df_test, 50, 100)
    if has_cross:
        print(f"Croisement détecté: {cross_type}")
    
    # Visualisation
    plt.figure(figsize=(14, 8))
    plt.plot(df_test.index, df_test['close'], label='Close', color='black', linewidth=1.5)
    plt.plot(df_test.index, df_test['ema_20'], label='EMA 20', color='blue', alpha=0.7)
    plt.plot(df_test.index, df_test['ema_50'], label='EMA 50', color='green', alpha=0.7)
    plt.plot(df_test.index, df_test['ema_100'], label='EMA 100', color='orange', alpha=0.7)
    plt.plot(df_test.index, df_test['ema_200'], label='EMA 200', color='red', alpha=0.7)
    
    plt.legend()
    plt.title('EMA Test - Multiple Periods')
    plt.xlabel('Time')
    plt.ylabel('Price')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig('ema_test.png', dpi=150)
    print("\nGraphique sauvegardé: ema_test.png")

