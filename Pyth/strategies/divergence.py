"""
Divergence Validator
Détection et validation des divergences RSI/Prix
Conversion Python de JT_DivergenceValidator.mqh
"""

import pandas as pd
import numpy as np
from typing import Tuple, Optional, List
from dataclasses import dataclass
from datetime import datetime

from indicators import RSI


@dataclass
class FreeCandleMemory:
    """Mémoire d'un Free Candle pour validation future"""
    is_active: bool = False
    bar_index: int = 0
    time: datetime = None
    price_level: float = 0.0
    direction: int = 0  # +1 pour buy, -1 pour sell


class DivergenceValidator:
    """
    Validateur de divergence RSI/Prix
    
    Logique:
    1. Mémorise un Free Candle détecté
    2. Attend une confirmation par divergence RSI/Prix
    3. Valide ou invalide le signal selon le RSI
    """
    
    def __init__(
        self,
        config=None,
        rsi_period: int = 14,
        rsi_buy_level: float = 35.0,
        rsi_sell_level: float = 65.0,
        swing_length: int = 5
    ):
        """
        Args:
            config: StrategyConfig (optionnel)
            rsi_period: Période du RSI
            rsi_buy_level: Seuil RSI pour validation BUY
            rsi_sell_level: Seuil RSI pour validation SELL
            swing_length: Longueur pour détecter les pivots (swings)
        """
        # Si config fourni, utiliser ses paramètres
        if config:
            self.rsi_period = config.rsi.period
            self.rsi_buy_level = config.divergence.rsi_buy_level
            self.rsi_sell_level = config.divergence.rsi_sell_level
            self.swing_length = config.divergence.swing_length
        else:
            self.rsi_period = rsi_period
            self.rsi_buy_level = rsi_buy_level
            self.rsi_sell_level = rsi_sell_level
            self.swing_length = swing_length
        
        # RSI indicator
        self.rsi_indicator = RSI(period=self.rsi_period)
        
        # Mémoire du Free Candle
        self.memory = FreeCandleMemory()
    
    def remember_free_candle(
        self,
        bar_index: int,
        price_level: float,
        direction: int,
        timestamp: datetime
    ):
        """
        Mémorise un Free Candle pour validation ultérieure
        
        Args:
            bar_index: Index de la barre du Free Candle
            price_level: Niveau de prix du Free Candle
            direction: +1 pour BUY, -1 pour SELL
            timestamp: Timestamp du Free Candle
        """
        self.memory.is_active = True
        self.memory.bar_index = bar_index
        self.memory.price_level = price_level
        self.memory.direction = direction
        self.memory.time = timestamp
    
    def clear_memory(self):
        """Efface la mémoire du Free Candle"""
        self.memory = FreeCandleMemory()
    
    def has_free_candle(self) -> bool:
        """Vérifie si on a un Free Candle en mémoire"""
        return self.memory.is_active
    
    def get_memorized_direction(self) -> int:
        """Retourne la direction du Free Candle mémorisé"""
        return self.memory.direction
    
    def validate_divergence(self, df: pd.DataFrame, current_index: int) -> Tuple[bool, int]:
        """
        Valide une divergence pour le Free Candle en mémoire
        
        Args:
            df: DataFrame avec prix et RSI
            current_index: Index actuel dans le DataFrame
        
        Returns:
            Tuple (is_validated, direction) où:
                - is_validated: True si divergence validée
                - direction: +1 pour BUY, -1 pour SELL, 0 sinon
        """
        if not self.has_free_candle():
            return False, 0
        
        # S'assurer que le RSI est calculé
        if 'rsi' not in df.columns:
            df = self.rsi_indicator.calculate_dataframe(df)
        
        current_rsi = df.iloc[current_index]['rsi']
        
        if pd.isna(current_rsi):
            return False, 0
        
        # Validation pour BUY
        if self.memory.direction > 0:
            # Si RSI > seuil buy, invalider
            if current_rsi > self.rsi_buy_level:
                self.clear_memory()
                return False, 0
            
            # Vérifier divergence haussière
            if self._is_bullish_divergence(df, current_index):
                self.clear_memory()  # One-shot
                return True, 1
        
        # Validation pour SELL
        if self.memory.direction < 0:
            # Si RSI < seuil sell, invalider
            if current_rsi < self.rsi_sell_level:
                self.clear_memory()
                return False, 0
            
            # Vérifier divergence baissière
            if self._is_bearish_divergence(df, current_index):
                self.clear_memory()  # One-shot
                return True, -1
        
        return False, 0
    
    def _find_swing_lows(self, df: pd.DataFrame, max_bars: int = 200) -> List[int]:
        """
        Trouve les creux locaux (swing lows)
        
        Args:
            df: DataFrame avec colonne 'low'
            max_bars: Nombre maximum de barres à analyser
        
        Returns:
            Liste des indices des swing lows
        """
        swing_lows = []
        
        # Limiter la recherche
        start_idx = max(0, len(df) - max_bars)
        
        for i in range(start_idx + self.swing_length, len(df) - self.swing_length):
            center_low = df.iloc[i]['low']
            
            # Vérifier que c'est un minimum local
            is_swing = True
            for k in range(1, self.swing_length + 1):
                left_low = df.iloc[i - k]['low']
                right_low = df.iloc[i + k]['low']
                
                if center_low >= left_low or center_low >= right_low:
                    is_swing = False
                    break
            
            if is_swing:
                swing_lows.append(i)
        
        return swing_lows
    
    def _find_swing_highs(self, df: pd.DataFrame, max_bars: int = 200) -> List[int]:
        """
        Trouve les sommets locaux (swing highs)
        
        Args:
            df: DataFrame avec colonne 'high'
            max_bars: Nombre maximum de barres à analyser
        
        Returns:
            Liste des indices des swing highs
        """
        swing_highs = []
        
        # Limiter la recherche
        start_idx = max(0, len(df) - max_bars)
        
        for i in range(start_idx + self.swing_length, len(df) - self.swing_length):
            center_high = df.iloc[i]['high']
            
            # Vérifier que c'est un maximum local
            is_swing = True
            for k in range(1, self.swing_length + 1):
                left_high = df.iloc[i - k]['high']
                right_high = df.iloc[i + k]['high']
                
                if center_high <= left_high or center_high <= right_high:
                    is_swing = False
                    break
            
            if is_swing:
                swing_highs.append(i)
        
        return swing_highs
    
    def _is_bullish_divergence(self, df: pd.DataFrame, current_index: int) -> bool:
        """
        Détecte une divergence haussière
        Prix fait un Lower Low (LL) mais RSI fait un Higher Low (HL)
        
        Args:
            df: DataFrame avec prix et RSI
            current_index: Index actuel
        
        Returns:
            True si divergence haussière détectée
        """
        # Trouver les swing lows
        swing_lows = self._find_swing_lows(df[:current_index+1])
        
        if len(swing_lows) < 2:
            return False
        
        # Prendre les 2 derniers swing lows
        recent_pivot = swing_lows[-1]
        older_pivot = swing_lows[-2]
        
        recent_low = df.iloc[recent_pivot]['low']
        older_low = df.iloc[older_pivot]['low']
        recent_rsi = df.iloc[recent_pivot]['rsi']
        older_rsi = df.iloc[older_pivot]['rsi']
        
        if pd.isna(recent_rsi) or pd.isna(older_rsi):
            return False
        
        # Divergence haussière: Prix LL, RSI HL
        price_lower_low = recent_low < older_low
        rsi_higher_low = recent_rsi > older_rsi
        
        return price_lower_low and rsi_higher_low
    
    def _is_bearish_divergence(self, df: pd.DataFrame, current_index: int) -> bool:
        """
        Détecte une divergence baissière
        Prix fait un Higher High (HH) mais RSI fait un Lower High (LH)
        
        Args:
            df: DataFrame avec prix et RSI
            current_index: Index actuel
        
        Returns:
            True si divergence baissière détectée
        """
        # Trouver les swing highs
        swing_highs = self._find_swing_highs(df[:current_index+1])
        
        if len(swing_highs) < 2:
            return False
        
        # Prendre les 2 derniers swing highs
        recent_pivot = swing_highs[-1]
        older_pivot = swing_highs[-2]
        
        recent_high = df.iloc[recent_pivot]['high']
        older_high = df.iloc[older_pivot]['high']
        recent_rsi = df.iloc[recent_pivot]['rsi']
        older_rsi = df.iloc[older_pivot]['rsi']
        
        if pd.isna(recent_rsi) or pd.isna(older_rsi):
            return False
        
        # Divergence baissière: Prix HH, RSI LH
        price_higher_high = recent_high > older_high
        rsi_lower_high = recent_rsi < older_rsi
        
        return price_higher_high and rsi_lower_high
    
    def scan_for_divergences(
        self, 
        df: pd.DataFrame, 
        lookback: int = 100
    ) -> List[Tuple[str, int, float, float]]:
        """
        Scanne le DataFrame pour toutes les divergences
        
        Args:
            df: DataFrame avec prix et RSI
            lookback: Nombre de barres à analyser
        
        Returns:
            Liste de tuples (type, index, price_level, rsi_level)
                où type est 'bullish' ou 'bearish'
        """
        divergences = []
        
        # S'assurer que le RSI est calculé
        if 'rsi' not in df.columns:
            df = self.rsi_indicator.calculate_dataframe(df)
        
        start_idx = max(self.swing_length * 2, len(df) - lookback)
        
        for i in range(start_idx, len(df)):
            # Vérifier divergence haussière
            if self._is_bullish_divergence(df, i):
                divergences.append(('bullish', i, df.iloc[i]['low'], df.iloc[i]['rsi']))
            
            # Vérifier divergence baissière
            if self._is_bearish_divergence(df, i):
                divergences.append(('bearish', i, df.iloc[i]['high'], df.iloc[i]['rsi']))
        
        return divergences
    
    def validate_signals(self, signals: List, df: pd.DataFrame) -> List:
        """
        Valide les signaux avec la divergence
        Compatible avec la logique MQL5 ValidateDivergence
        
        Args:
            signals: Liste de Signal objects
            df: DataFrame avec données et indicateurs
        
        Returns:
            Liste de signaux validés (peut être vide si tous rejetés)
        """
        if not signals:
            return []
        
        # Assurer que le RSI est calculé
        if 'rsi' not in df.columns:
            df = self.rsi_indicator.calculate_dataframe(df)
        
        validated_signals = []
        
        for signal in signals:
            # Trouver l'index correspondant au signal
            try:
                idx = df.index.get_loc(signal.timestamp)
            except:
                # Si timestamp pas trouvé, garder le signal
                validated_signals.append(signal)
                continue
            
            # Valider avec divergence
            has_divergence, div_direction = self.validate_divergence(df, idx)
            
            # Si divergence confirmée dans la bonne direction, augmenter confidence
            if has_divergence and div_direction == signal.direction:
                # Augmenter la confidence du signal
                signal.confidence = min(signal.confidence + 0.3, 1.0)
                signal.reason += "_DIV_CONFIRMED"
                validated_signals.append(signal)
            elif has_divergence and div_direction != signal.direction:
                # Divergence contraire, rejeter le signal
                continue
            else:
                # Pas de divergence, garder le signal tel quel
                validated_signals.append(signal)
        
        return validated_signals
    
    def __repr__(self) -> str:
        return (f"DivergenceValidator(rsi_period={self.rsi_period}, "
                f"buy_level={self.rsi_buy_level}, sell_level={self.rsi_sell_level}, "
                f"swing_length={self.swing_length})")


if __name__ == "__main__":
    # Test du validateur de divergence
    import matplotlib.pyplot as plt
    
    # Créer des données de test avec divergence intentionnelle
    np.random.seed(42)
    dates = pd.date_range('2024-01-01', periods=300, freq='H')
    
    # Simuler un trend baissier suivi d'une divergence haussière
    prices = []
    base_price = 1.1000
    
    for i in range(len(dates)):
        if i < 150:
            # Trend baissier
            base_price -= 0.00005 + np.random.randn() * 0.0001
        else:
            # Oscillation avec divergence potentielle
            base_price += np.sin(i / 10) * 0.0002 + np.random.randn() * 0.0001
        prices.append(base_price)
    
    df_test = pd.DataFrame({
        'close': prices,
        'high': [p + abs(np.random.randn() * 0.0001) for p in prices],
        'low': [p - abs(np.random.randn() * 0.0001) for p in prices],
    }, index=dates)
    
    # Créer le validateur
    validator = DivergenceValidator(
        rsi_period=14,
        rsi_buy_level=35.0,
        rsi_sell_level=65.0,
        swing_length=5
    )
    
    # Calculer le RSI
    df_test = validator.rsi_indicator.calculate_dataframe(df_test)
    
    # Scanner les divergences
    divergences = validator.scan_for_divergences(df_test)
    
    print(f"Validateur: {validator}")
    print(f"\nNombre de divergences trouvées: {len(divergences)}")
    
    if divergences:
        print("\nDivergences détectées:")
        for div_type, idx, price, rsi in divergences:
            timestamp = df_test.index[idx]
            print(f"  {timestamp} - {div_type.upper()}: Prix={price:.5f}, RSI={rsi:.2f}")
    
    # Visualisation
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 10), sharex=True)
    
    # Prix
    ax1.plot(df_test.index, df_test['close'], label='Close', color='black')
    
    # Marquer les divergences
    for div_type, idx, price, rsi in divergences:
        timestamp = df_test.index[idx]
        color = 'green' if div_type == 'bullish' else 'red'
        marker = '^' if div_type == 'bullish' else 'v'
        ax1.scatter(timestamp, price, color=color, marker=marker, s=100, zorder=5)
    
    ax1.set_ylabel('Price')
    ax1.set_title('Divergence Detection Test')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # RSI
    ax2.plot(df_test.index, df_test['rsi'], label='RSI', color='blue')
    ax2.axhline(y=validator.rsi_buy_level, color='green', linestyle='--', label=f'Buy Level ({validator.rsi_buy_level})')
    ax2.axhline(y=validator.rsi_sell_level, color='red', linestyle='--', label=f'Sell Level ({validator.rsi_sell_level})')
    ax2.axhline(y=50, color='gray', linestyle='-', alpha=0.3)
    
    # Marquer les divergences sur le RSI
    for div_type, idx, price, rsi_val in divergences:
        timestamp = df_test.index[idx]
        color = 'green' if div_type == 'bullish' else 'red'
        marker = '^' if div_type == 'bullish' else 'v'
        ax2.scatter(timestamp, rsi_val, color=color, marker=marker, s=100, zorder=5)
    
    ax2.set_ylabel('RSI')
    ax2.set_xlabel('Time')
    ax2.set_ylim(0, 100)
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('divergence_test.png', dpi=150)
    print("\nGraphique sauvegardé: divergence_test.png")

