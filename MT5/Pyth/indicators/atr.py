"""
ATR (Average True Range) Indicator
Conversion Python de l'indicateur ATR MQL5
"""

import pandas as pd
import numpy as np
from typing import Optional


class ATR:
    """
    Calcule l'Average True Range (ATR)
    
    Parameters:
        period: Période pour le calcul de l'ATR (défaut: 14)
    """
    
    def __init__(self, period: int = 14):
        self.period = period
    
    def calculate(self, df: pd.DataFrame) -> pd.Series:
        """
        Calcule l'ATR
        
        Args:
            df: DataFrame avec colonnes high, low, close
        
        Returns:
            Série avec les valeurs ATR
        """
        # Calculer le True Range
        high_low = df['high'] - df['low']
        high_close = np.abs(df['high'] - df['close'].shift())
        low_close = np.abs(df['low'] - df['close'].shift())
        
        # True Range = max des trois composantes
        ranges = pd.concat([high_low, high_close, low_close], axis=1)
        true_range = ranges.max(axis=1)
        
        # ATR = moyenne mobile exponentielle du True Range
        atr = true_range.ewm(span=self.period, adjust=False).mean()
        
        return atr
    
    def calculate_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Calcule l'ATR et l'ajoute au DataFrame
        
        Args:
            df: DataFrame avec colonnes high, low, close
        
        Returns:
            DataFrame avec colonne 'atr' ajoutée
        """
        df = df.copy()
        df['atr'] = self.calculate(df)
        return df
    
    def get_atr_stop_loss(
        self, 
        df: pd.DataFrame, 
        entry_price: float, 
        is_buy: bool, 
        multiplier: float = 2.0
    ) -> float:
        """
        Calcule un stop loss basé sur l'ATR
        
        Args:
            df: DataFrame avec colonne 'atr'
            entry_price: Prix d'entrée
            is_buy: True pour un achat, False pour une vente
            multiplier: Multiplicateur de l'ATR (défaut: 2.0)
        
        Returns:
            Niveau de stop loss
        """
        if 'atr' not in df.columns:
            df = self.calculate_dataframe(df)
        
        current_atr = df['atr'].iloc[-1]
        
        if pd.isna(current_atr):
            return entry_price
        
        atr_distance = current_atr * multiplier
        
        if is_buy:
            stop_loss = entry_price - atr_distance
        else:
            stop_loss = entry_price + atr_distance
        
        return stop_loss
    
    def get_atr_take_profit(
        self, 
        df: pd.DataFrame, 
        entry_price: float, 
        stop_loss: float,
        is_buy: bool, 
        rr_ratio: float = 2.0
    ) -> float:
        """
        Calcule un take profit basé sur l'ATR et le ratio RR
        
        Args:
            df: DataFrame avec colonne 'atr'
            entry_price: Prix d'entrée
            stop_loss: Niveau de stop loss
            is_buy: True pour un achat, False pour une vente
            rr_ratio: Ratio risque/récompense souhaité
        
        Returns:
            Niveau de take profit
        """
        risk = abs(entry_price - stop_loss)
        reward = risk * rr_ratio
        
        if is_buy:
            take_profit = entry_price + reward
        else:
            take_profit = entry_price - reward
        
        return take_profit
    
    def get_volatility_level(self, df: pd.DataFrame, lookback: int = 50) -> str:
        """
        Détermine le niveau de volatilité basé sur l'ATR
        
        Args:
            df: DataFrame avec colonne 'atr'
            lookback: Nombre de barres pour la référence
        
        Returns:
            'low', 'normal', 'high', 'extreme'
        """
        if 'atr' not in df.columns:
            df = self.calculate_dataframe(df)
        
        if len(df) < lookback:
            return 'normal'
        
        current_atr = df['atr'].iloc[-1]
        historical_atr = df['atr'].iloc[-lookback:]
        
        atr_mean = historical_atr.mean()
        atr_std = historical_atr.std()
        
        if pd.isna(current_atr) or pd.isna(atr_mean) or pd.isna(atr_std):
            return 'normal'
        
        # Calcul du z-score
        z_score = (current_atr - atr_mean) / atr_std if atr_std > 0 else 0
        
        if z_score < -1:
            return 'low'
        elif z_score > 2:
            return 'extreme'
        elif z_score > 1:
            return 'high'
        else:
            return 'normal'
    
    def is_expanding(self, df: pd.DataFrame, lookback: int = 5) -> bool:
        """
        Vérifie si la volatilité (ATR) est en expansion
        
        Args:
            df: DataFrame avec colonne 'atr'
            lookback: Nombre de barres à analyser
        
        Returns:
            True si l'ATR est en expansion
        """
        if 'atr' not in df.columns:
            df = self.calculate_dataframe(df)
        
        if len(df) < lookback:
            return False
        
        recent_atr = df['atr'].iloc[-lookback:].values
        
        # Vérifier si l'ATR est globalement croissante
        atr_diff = np.diff(recent_atr)
        expanding = np.sum(atr_diff > 0) > len(atr_diff) / 2
        
        return expanding
    
    def is_contracting(self, df: pd.DataFrame, lookback: int = 5) -> bool:
        """
        Vérifie si la volatilité (ATR) est en contraction
        
        Args:
            df: DataFrame avec colonne 'atr'
            lookback: Nombre de barres à analyser
        
        Returns:
            True si l'ATR est en contraction
        """
        if 'atr' not in df.columns:
            df = self.calculate_dataframe(df)
        
        if len(df) < lookback:
            return False
        
        recent_atr = df['atr'].iloc[-lookback:].values
        
        # Vérifier si l'ATR est globalement décroissante
        atr_diff = np.diff(recent_atr)
        contracting = np.sum(atr_diff < 0) > len(atr_diff) / 2
        
        return contracting
    
    def get_position_size_by_atr(
        self,
        df: pd.DataFrame,
        capital: float,
        risk_percent: float,
        entry_price: float,
        multiplier: float = 2.0,
        point_value: float = 1.0
    ) -> float:
        """
        Calcule la taille de position basée sur l'ATR
        
        Args:
            df: DataFrame avec colonne 'atr'
            capital: Capital disponible
            risk_percent: Pourcentage du capital à risquer
            entry_price: Prix d'entrée
            multiplier: Multiplicateur de l'ATR pour le SL
            point_value: Valeur d'un point de mouvement
        
        Returns:
            Taille de position recommandée
        """
        if 'atr' not in df.columns:
            df = self.calculate_dataframe(df)
        
        current_atr = df['atr'].iloc[-1]
        
        if pd.isna(current_atr) or current_atr == 0:
            return 0.0
        
        # Montant à risquer
        risk_amount = capital * (risk_percent / 100.0)
        
        # Distance du stop loss en termes d'ATR
        sl_distance = current_atr * multiplier
        
        # Calculer la taille de position
        position_size = risk_amount / (sl_distance * point_value)
        
        return position_size
    
    def __repr__(self) -> str:
        return f"ATR(period={self.period})"


if __name__ == "__main__":
    # Test de l'indicateur
    import matplotlib.pyplot as plt
    
    # Créer des données de test
    np.random.seed(42)
    dates = pd.date_range('2024-01-01', periods=200, freq='H')
    
    # Simuler des prix avec volatilité variable
    base_price = 1.1000
    volatility = 0.0003
    prices = [base_price]
    
    for i in range(1, len(dates)):
        # Augmenter progressivement la volatilité
        if i > 100:
            volatility = 0.0006
        change = np.random.randn() * volatility
        prices.append(prices[-1] + change)
    
    df_test = pd.DataFrame({
        'close': prices,
    }, index=dates)
    
    df_test['high'] = df_test['close'] + abs(np.random.randn(len(df_test)) * 0.0001)
    df_test['low'] = df_test['close'] - abs(np.random.randn(len(df_test)) * 0.0001)
    df_test['open'] = df_test['close'].shift(1).fillna(base_price)
    
    # Calculer l'ATR
    atr = ATR(period=14)
    df_test = atr.calculate_dataframe(df_test)
    
    # Afficher les résultats
    print("Dernières valeurs:")
    print(df_test[['close', 'atr']].tail(10))
    
    current_atr = df_test['atr'].iloc[-1]
    print(f"\nATR actuel: {current_atr:.6f}")
    print(f"Niveau de volatilité: {atr.get_volatility_level(df_test)}")
    print(f"Expansion: {atr.is_expanding(df_test)}")
    print(f"Contraction: {atr.is_contracting(df_test)}")
    
    # Test du stop loss basé sur ATR
    entry_price = df_test['close'].iloc[-1]
    sl_buy = atr.get_atr_stop_loss(df_test, entry_price, is_buy=True, multiplier=2.0)
    sl_sell = atr.get_atr_stop_loss(df_test, entry_price, is_buy=False, multiplier=2.0)
    
    print(f"\nPrix d'entrée: {entry_price:.5f}")
    print(f"SL BUY (2xATR): {sl_buy:.5f} (distance: {(entry_price - sl_buy):.5f})")
    print(f"SL SELL (2xATR): {sl_sell:.5f} (distance: {(sl_sell - entry_price):.5f})")
    
    # Visualisation
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 10), sharex=True)
    
    # Prix
    ax1.plot(df_test.index, df_test['close'], label='Close', color='black')
    ax1.fill_between(df_test.index, df_test['low'], df_test['high'], alpha=0.2, color='blue')
    ax1.set_ylabel('Price')
    ax1.set_title('Price and ATR Test')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # ATR
    ax2.plot(df_test.index, df_test['atr'], label='ATR', color='red', linewidth=1.5)
    ax2.fill_between(df_test.index, 0, df_test['atr'], alpha=0.2, color='red')
    ax2.axvline(x=df_test.index[100], color='green', linestyle='--', alpha=0.5, label='Volatility increase')
    ax2.set_ylabel('ATR')
    ax2.set_xlabel('Time')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('atr_test.png', dpi=150)
    print("\nGraphique sauvegardé: atr_test.png")

