"""
RSI (Relative Strength Index) Indicator
Conversion Python de l'indicateur RSI MQL5
"""

import pandas as pd
import numpy as np
from typing import Tuple, Optional


class RSI:
    """
    Calcule le RSI (Relative Strength Index)
    
    Parameters:
        period: Période pour le calcul du RSI (défaut: 14)
        oversold: Niveau de survente (défaut: 30)
        overbought: Niveau de surachat (défaut: 70)
    """
    
    def __init__(self, period: int = 14, oversold: float = 30.0, overbought: float = 70.0):
        self.period = period
        self.oversold = oversold
        self.overbought = overbought
    
    def calculate(self, prices: pd.Series) -> pd.Series:
        """
        Calcule le RSI
        
        Args:
            prices: Série de prix (généralement les closes)
        
        Returns:
            Série avec les valeurs RSI
        """
        # Calculer les variations de prix
        delta = prices.diff()
        
        # Séparer les gains et les pertes
        gains = delta.where(delta > 0, 0.0)
        losses = -delta.where(delta < 0, 0.0)
        
        # Calculer les moyennes mobiles exponentielles des gains et pertes
        avg_gains = gains.ewm(span=self.period, adjust=False).mean()
        avg_losses = losses.ewm(span=self.period, adjust=False).mean()
        
        # Calculer le RS (Relative Strength)
        rs = avg_gains / avg_losses
        
        # Calculer le RSI
        rsi = 100.0 - (100.0 / (1.0 + rs))
        
        return rsi
    
    def calculate_dataframe(self, df: pd.DataFrame, price_column: str = 'close') -> pd.DataFrame:
        """
        Calcule le RSI et l'ajoute au DataFrame
        
        Args:
            df: DataFrame avec les données de prix
            price_column: Colonne de prix à utiliser
        
        Returns:
            DataFrame avec colonne 'rsi' ajoutée
        """
        df = df.copy()
        df['rsi'] = self.calculate(df[price_column])
        return df
    
    def is_oversold(self, rsi_value: float) -> bool:
        """Vérifie si le RSI est en zone de survente"""
        return rsi_value < self.oversold
    
    def is_overbought(self, rsi_value: float) -> bool:
        """Vérifie si le RSI est en zone de surachat"""
        return rsi_value > self.overbought
    
    def get_signal(self, rsi_value: float) -> int:
        """
        Retourne un signal basé sur les niveaux RSI
        
        Returns:
            1 pour BUY (survente), -1 pour SELL (surachat), 0 pour neutre
        """
        if self.is_oversold(rsi_value):
            return 1
        elif self.is_overbought(rsi_value):
            return -1
        return 0
    
    def detect_divergence(
        self, 
        prices: pd.Series, 
        rsi_values: pd.Series, 
        lookback: int = 50
    ) -> Tuple[bool, str]:
        """
        Détecte les divergences bullish/bearish
        
        Args:
            prices: Série de prix
            rsi_values: Série de valeurs RSI
            lookback: Nombre de barres à analyser
        
        Returns:
            Tuple (has_divergence, type) où type est 'bullish', 'bearish', ou 'none'
        """
        if len(prices) < lookback or len(rsi_values) < lookback:
            return False, 'none'
        
        # Dernières valeurs
        recent_prices = prices.iloc[-lookback:]
        recent_rsi = rsi_values.iloc[-lookback:]
        
        # Trouver les pivots (local min/max)
        price_lows = self._find_local_minima(recent_prices)
        price_highs = self._find_local_maxima(recent_prices)
        rsi_lows = self._find_local_minima(recent_rsi)
        rsi_highs = self._find_local_maxima(recent_rsi)
        
        # Divergence bullish: Prix fait un plus bas mais RSI fait un plus haut
        if len(price_lows) >= 2 and len(rsi_lows) >= 2:
            if price_lows[-1] < price_lows[-2] and rsi_lows[-1] > rsi_lows[-2]:
                return True, 'bullish'
        
        # Divergence bearish: Prix fait un plus haut mais RSI fait un plus bas
        if len(price_highs) >= 2 and len(rsi_highs) >= 2:
            if price_highs[-1] > price_highs[-2] and rsi_highs[-1] < rsi_highs[-2]:
                return True, 'bearish'
        
        return False, 'none'
    
    def _find_local_minima(self, series: pd.Series, order: int = 5) -> list:
        """Trouve les minima locaux"""
        from scipy.signal import argrelextrema
        
        values = series.values
        minima_indices = argrelextrema(values, np.less, order=order)[0]
        
        return [values[i] for i in minima_indices]
    
    def _find_local_maxima(self, series: pd.Series, order: int = 5) -> list:
        """Trouve les maxima locaux"""
        from scipy.signal import argrelextrema
        
        values = series.values
        maxima_indices = argrelextrema(values, np.greater, order=order)[0]
        
        return [values[i] for i in maxima_indices]
    
    def get_strength(self, rsi_value: float) -> str:
        """
        Retourne le niveau de force du RSI
        
        Returns:
            'extremely_oversold', 'oversold', 'neutral', 'overbought', 'extremely_overbought'
        """
        if rsi_value < 20:
            return 'extremely_oversold'
        elif rsi_value < self.oversold:
            return 'oversold'
        elif rsi_value > 80:
            return 'extremely_overbought'
        elif rsi_value > self.overbought:
            return 'overbought'
        else:
            return 'neutral'
    
    def __repr__(self) -> str:
        return f"RSI(period={self.period}, oversold={self.oversold}, overbought={self.overbought})"


if __name__ == "__main__":
    # Test de l'indicateur
    import matplotlib.pyplot as plt
    
    # Créer des données de test
    np.random.seed(42)
    dates = pd.date_range('2024-01-01', periods=200, freq='H')
    close_prices = 1.1000 + np.cumsum(np.random.randn(200) * 0.0005)
    
    df_test = pd.DataFrame({
        'close': close_prices,
    }, index=dates)
    
    # Calculer le RSI
    rsi = RSI(period=14, oversold=29, overbought=71)
    df_test = rsi.calculate_dataframe(df_test)
    
    # Afficher les résultats
    print("Dernières valeurs:")
    print(df_test[['close', 'rsi']].tail(10))
    
    current_rsi = df_test['rsi'].iloc[-1]
    print(f"\nRSI actuel: {current_rsi:.2f}")
    print(f"Niveau: {rsi.get_strength(current_rsi)}")
    print(f"Signal: {rsi.get_signal(current_rsi)}")
    
    # Visualisation
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    
    # Prix
    ax1.plot(df_test.index, df_test['close'], label='Close', color='black')
    ax1.set_ylabel('Price')
    ax1.set_title('Price and RSI Test')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # RSI
    ax2.plot(df_test.index, df_test['rsi'], label='RSI', color='blue')
    ax2.axhline(y=rsi.oversold, color='green', linestyle='--', label=f'Oversold ({rsi.oversold})')
    ax2.axhline(y=rsi.overbought, color='red', linestyle='--', label=f'Overbought ({rsi.overbought})')
    ax2.axhline(y=50, color='gray', linestyle='-', alpha=0.3)
    ax2.fill_between(df_test.index, 0, rsi.oversold, alpha=0.1, color='green')
    ax2.fill_between(df_test.index, rsi.overbought, 100, alpha=0.1, color='red')
    ax2.set_ylabel('RSI')
    ax2.set_xlabel('Time')
    ax2.set_ylim(0, 100)
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('rsi_test.png', dpi=150)
    print("\nGraphique sauvegardé: rsi_test.png")

