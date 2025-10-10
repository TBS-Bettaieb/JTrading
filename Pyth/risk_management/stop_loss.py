"""
Stop Loss Calculator
Calcul dynamique des Stop Loss et Take Profit
Conversion Python de CalculateSwingSLTP (JT_Utils.mqh)
"""

import pandas as pd
import numpy as np
from typing import Tuple, Optional


class StopLossCalculator:
    """
    Calcule les niveaux de Stop Loss et Take Profit
    
    Méthodes:
    1. Swing-based (basé sur les plus hauts/plus bas)
    2. ATR-based (basé sur la volatilité)
    3. Fixed points (distance fixe en points)
    4. Percentage-based (% du prix)
    5. Support/Resistance (niveaux techniques)
    """
    
    def __init__(
        self,
        min_sl_points: float = 10.0,
        min_tp_points: float = 10.0,
        default_rr_ratio: float = 2.0
    ):
        """
        Args:
            min_sl_points: Distance minimale du SL en points
            min_tp_points: Distance minimale du TP en points
            default_rr_ratio: Ratio risque/récompense par défaut
        """
        self.min_sl_points = min_sl_points
        self.min_tp_points = min_tp_points
        self.default_rr_ratio = default_rr_ratio
    
    def swing_sl_tp(
        self,
        df: pd.DataFrame,
        current_index: int,
        is_buy: bool,
        sl_period: int = 50,
        tp_period: int = 30,
        atr_multiplier: float = 2.0,
        min_rr_ratio: float = 2.0,
        point_size: float = 0.0001
    ) -> Tuple[float, float, float]:
        """
        Calcule SL/TP basés sur les swing high/low avec fallback ATR
        (Reproduction de CalculateSwingSLTP du MQL5)
        
        Args:
            df: DataFrame avec colonnes OHLCV et 'atr'
            current_index: Index actuel
            is_buy: True pour un achat, False pour une vente
            sl_period: Nombre de barres pour le SL
            tp_period: Nombre de barres pour le TP
            atr_multiplier: Multiplicateur ATR pour fallback
            min_rr_ratio: Ratio RR minimum
            point_size: Taille d'un point
        
        Returns:
            Tuple (stop_loss, take_profit, rr_ratio)
        """
        entry_price = df.iloc[current_index]['close']
        
        # Calculer l'ATR si pas présent
        if 'atr' not in df.columns:
            from indicators import ATR
            atr_calc = ATR()
            df = atr_calc.calculate_dataframe(df)
        
        current_atr = df.iloc[current_index]['atr']
        
        # Distance minimale
        min_dist = max(self.min_sl_points * point_size, current_atr * 0.5)
        
        # Calculer le SL basé sur swing
        start_idx = max(0, current_index - sl_period)
        
        if is_buy:
            # SL au swing low
            swing_sl = df.iloc[start_idx:current_index]['low'].min()
            # SL basé sur ATR
            atr_sl = entry_price - (atr_multiplier * current_atr)
            # Prendre le plus protecteur (plus bas pour un buy)
            sl = min(swing_sl, atr_sl)
            
            # Vérifier distance minimale
            if entry_price - sl < min_dist:
                sl = entry_price - min_dist
        else:
            # SL au swing high
            swing_sl = df.iloc[start_idx:current_index]['high'].max()
            # SL basé sur ATR
            atr_sl = entry_price + (atr_multiplier * current_atr)
            # Prendre le plus protecteur (plus haut pour un sell)
            sl = max(swing_sl, atr_sl)
            
            # Vérifier distance minimale
            if sl - entry_price < min_dist:
                sl = entry_price + min_dist
        
        # Calculer le TP basé sur swing opposé
        tp_start_idx = max(0, current_index - tp_period)
        
        if is_buy:
            swing_tp = df.iloc[tp_start_idx:current_index]['high'].max()
            
            # Vérifier si le TP swing est valide
            if swing_tp <= entry_price:
                # Utiliser ratio RR
                risk = abs(entry_price - sl)
                tp = entry_price + (risk * min_rr_ratio)
            else:
                # Utiliser le swing TP s'il donne un bon RR
                tp = swing_tp
                risk = abs(entry_price - sl)
                reward = abs(tp - entry_price)
                
                if reward / risk < min_rr_ratio:
                    tp = entry_price + (risk * min_rr_ratio)
        else:
            swing_tp = df.iloc[tp_start_idx:current_index]['low'].min()
            
            # Vérifier si le TP swing est valide
            if swing_tp >= entry_price:
                # Utiliser ratio RR
                risk = abs(sl - entry_price)
                tp = entry_price - (risk * min_rr_ratio)
            else:
                # Utiliser le swing TP s'il donne un bon RR
                tp = swing_tp
                risk = abs(sl - entry_price)
                reward = abs(entry_price - tp)
                
                if reward / risk < min_rr_ratio:
                    tp = entry_price - (risk * min_rr_ratio)
        
        # Calculer RR ratio final
        risk = abs(entry_price - sl)
        reward = abs(tp - entry_price)
        rr_ratio = reward / risk if risk > 0 else 0
        
        return sl, tp, rr_ratio
    
    def atr_sl_tp(
        self,
        entry_price: float,
        atr_value: float,
        is_buy: bool,
        sl_multiplier: float = 2.0,
        rr_ratio: float = 2.0
    ) -> Tuple[float, float]:
        """
        Calcule SL/TP basés uniquement sur l'ATR
        
        Args:
            entry_price: Prix d'entrée
            atr_value: Valeur de l'ATR
            is_buy: True pour achat
            sl_multiplier: Multiplicateur ATR pour le SL
            rr_ratio: Ratio risque/récompense
        
        Returns:
            Tuple (stop_loss, take_profit)
        """
        sl_distance = atr_value * sl_multiplier
        
        if is_buy:
            sl = entry_price - sl_distance
            tp = entry_price + (sl_distance * rr_ratio)
        else:
            sl = entry_price + sl_distance
            tp = entry_price - (sl_distance * rr_ratio)
        
        return sl, tp
    
    def fixed_points_sl_tp(
        self,
        entry_price: float,
        is_buy: bool,
        sl_points: float,
        tp_points: float,
        point_size: float = 0.0001
    ) -> Tuple[float, float]:
        """
        Calcule SL/TP à distance fixe en points
        
        Args:
            entry_price: Prix d'entrée
            is_buy: True pour achat
            sl_points: Distance du SL en points
            tp_points: Distance du TP en points
            point_size: Taille d'un point
        
        Returns:
            Tuple (stop_loss, take_profit)
        """
        sl_distance = sl_points * point_size
        tp_distance = tp_points * point_size
        
        if is_buy:
            sl = entry_price - sl_distance
            tp = entry_price + tp_distance
        else:
            sl = entry_price + sl_distance
            tp = entry_price - tp_distance
        
        return sl, tp
    
    def percentage_sl_tp(
        self,
        entry_price: float,
        is_buy: bool,
        sl_percent: float = 1.0,
        tp_percent: float = 2.0
    ) -> Tuple[float, float]:
        """
        Calcule SL/TP en pourcentage du prix
        
        Args:
            entry_price: Prix d'entrée
            is_buy: True pour achat
            sl_percent: Distance du SL en %
            tp_percent: Distance du TP en %
        
        Returns:
            Tuple (stop_loss, take_profit)
        """
        sl_distance = entry_price * (sl_percent / 100.0)
        tp_distance = entry_price * (tp_percent / 100.0)
        
        if is_buy:
            sl = entry_price - sl_distance
            tp = entry_price + tp_distance
        else:
            sl = entry_price + sl_distance
            tp = entry_price - tp_distance
        
        return sl, tp
    
    def support_resistance_sl_tp(
        self,
        df: pd.DataFrame,
        current_index: int,
        entry_price: float,
        is_buy: bool,
        lookback: int = 100,
        rr_ratio: float = 2.0,
        point_size: float = 0.0001
    ) -> Tuple[float, float]:
        """
        Calcule SL/TP basés sur les niveaux de support/résistance
        
        Args:
            df: DataFrame avec OHLC
            current_index: Index actuel
            entry_price: Prix d'entrée
            is_buy: True pour achat
            lookback: Nombre de barres à analyser
            rr_ratio: Ratio RR minimum
            point_size: Taille d'un point
        
        Returns:
            Tuple (stop_loss, take_profit)
        """
        start_idx = max(0, current_index - lookback)
        historical_data = df.iloc[start_idx:current_index]
        
        if is_buy:
            # Pour un achat, SL au support le plus proche en-dessous
            supports = self._find_support_levels(historical_data)
            supports_below = [s for s in supports if s < entry_price]
            
            if supports_below:
                sl = max(supports_below) - (5 * point_size)  # 5 points en-dessous du support
            else:
                # Fallback sur le low minimum
                sl = historical_data['low'].min() - (10 * point_size)
            
            # TP à la résistance au-dessus
            resistances = self._find_resistance_levels(historical_data)
            resistances_above = [r for r in resistances if r > entry_price]
            
            if resistances_above:
                tp = min(resistances_above) - (5 * point_size)
            else:
                # Fallback sur RR ratio
                risk = abs(entry_price - sl)
                tp = entry_price + (risk * rr_ratio)
        else:
            # Pour une vente, SL à la résistance au-dessus
            resistances = self._find_resistance_levels(historical_data)
            resistances_above = [r for r in resistances if r > entry_price]
            
            if resistances_above:
                sl = min(resistances_above) + (5 * point_size)
            else:
                # Fallback sur le high maximum
                sl = historical_data['high'].max() + (10 * point_size)
            
            # TP au support en-dessous
            supports = self._find_support_levels(historical_data)
            supports_below = [s for s in supports if s < entry_price]
            
            if supports_below:
                tp = max(supports_below) + (5 * point_size)
            else:
                # Fallback sur RR ratio
                risk = abs(sl - entry_price)
                tp = entry_price - (risk * rr_ratio)
        
        return sl, tp
    
    def _find_support_levels(self, df: pd.DataFrame, tolerance: float = 0.0002) -> list:
        """
        Trouve les niveaux de support (simplifiés)
        
        Args:
            df: DataFrame avec OHLC
            tolerance: Tolérance pour grouper les niveaux
        
        Returns:
            Liste des niveaux de support
        """
        # Trouver les minima locaux
        lows = df['low'].values
        supports = []
        
        for i in range(2, len(lows) - 2):
            if lows[i] < lows[i-1] and lows[i] < lows[i+1]:
                supports.append(lows[i])
        
        # Grouper les supports proches
        if not supports:
            return []
        
        grouped_supports = []
        supports.sort()
        
        current_level = supports[0]
        for level in supports[1:]:
            if level - current_level > tolerance:
                grouped_supports.append(current_level)
                current_level = level
        grouped_supports.append(current_level)
        
        return grouped_supports
    
    def _find_resistance_levels(self, df: pd.DataFrame, tolerance: float = 0.0002) -> list:
        """
        Trouve les niveaux de résistance (simplifiés)
        
        Args:
            df: DataFrame avec OHLC
            tolerance: Tolérance pour grouper les niveaux
        
        Returns:
            Liste des niveaux de résistance
        """
        # Trouver les maxima locaux
        highs = df['high'].values
        resistances = []
        
        for i in range(2, len(highs) - 2):
            if highs[i] > highs[i-1] and highs[i] > highs[i+1]:
                resistances.append(highs[i])
        
        # Grouper les résistances proches
        if not resistances:
            return []
        
        grouped_resistances = []
        resistances.sort()
        
        current_level = resistances[0]
        for level in resistances[1:]:
            if level - current_level > tolerance:
                grouped_resistances.append(current_level)
                current_level = level
        grouped_resistances.append(current_level)
        
        return grouped_resistances
    
    def trailing_stop(
        self,
        entry_price: float,
        current_price: float,
        current_sl: float,
        is_buy: bool,
        trailing_distance: float,
        point_size: float = 0.0001
    ) -> float:
        """
        Calcule un trailing stop
        
        Args:
            entry_price: Prix d'entrée
            current_price: Prix actuel
            current_sl: SL actuel
            is_buy: True pour achat
            trailing_distance: Distance du trailing en points
            point_size: Taille d'un point
        
        Returns:
            Nouveau niveau de SL
        """
        trail_dist = trailing_distance * point_size
        
        if is_buy:
            # Pour un achat, le trailing suit le prix vers le haut
            new_sl = current_price - trail_dist
            # Ne jamais baisser le SL
            return max(new_sl, current_sl)
        else:
            # Pour une vente, le trailing suit le prix vers le bas
            new_sl = current_price + trail_dist
            # Ne jamais monter le SL
            return min(new_sl, current_sl)
    
    def break_even(
        self,
        entry_price: float,
        is_buy: bool,
        offset_points: float = 0,
        point_size: float = 0.0001
    ) -> float:
        """
        Calcule le niveau de break-even
        
        Args:
            entry_price: Prix d'entrée
            is_buy: True pour achat
            offset_points: Offset en points au-delà du break-even
            point_size: Taille d'un point
        
        Returns:
            Niveau de break-even
        """
        offset = offset_points * point_size
        
        if is_buy:
            return entry_price + offset
        else:
            return entry_price - offset
    
    def __repr__(self) -> str:
        return f"StopLossCalculator(min_sl={self.min_sl_points}, min_tp={self.min_tp_points}, rr={self.default_rr_ratio})"


if __name__ == "__main__":
    # Test du calculateur de stop loss
    import matplotlib.pyplot as plt
    from indicators import ATR
    
    # Créer des données de test
    np.random.seed(42)
    dates = pd.date_range('2024-01-01', periods=200, freq='H')
    close_prices = 1.1000 + np.cumsum(np.random.randn(200) * 0.0003)
    
    df_test = pd.DataFrame({
        'close': close_prices,
        'open': close_prices - 0.0001,
        'high': close_prices + 0.0002,
        'low': close_prices - 0.0002,
    }, index=dates)
    
    # Calculer ATR
    atr_calc = ATR(period=14)
    df_test = atr_calc.calculate_dataframe(df_test)
    
    # Créer le calculateur
    sl_calc = StopLossCalculator(min_sl_points=10, default_rr_ratio=2.0)
    
    # Test sur une position BUY à l'index 150
    test_idx = 150
    entry_price = df_test.iloc[test_idx]['close']
    
    print("Stop Loss Calculator Test")
    print("=" * 50)
    print(f"Entry Price: {entry_price:.5f}")
    print(f"ATR: {df_test.iloc[test_idx]['atr']:.5f}")
    print()
    
    # Test Swing SL/TP
    sl1, tp1, rr1 = sl_calc.swing_sl_tp(df_test, test_idx, is_buy=True)
    print(f"Swing-based SL/TP:")
    print(f"  SL: {sl1:.5f} (distance: {(entry_price - sl1)*10000:.1f} points)")
    print(f"  TP: {tp1:.5f} (distance: {(tp1 - entry_price)*10000:.1f} points)")
    print(f"  RR: 1:{rr1:.2f}")
    print()
    
    # Test ATR SL/TP
    sl2, tp2 = sl_calc.atr_sl_tp(entry_price, df_test.iloc[test_idx]['atr'], is_buy=True)
    print(f"ATR-based SL/TP (2x ATR):")
    print(f"  SL: {sl2:.5f}")
    print(f"  TP: {tp2:.5f}")
    print()
    
    # Test Fixed Points
    sl3, tp3 = sl_calc.fixed_points_sl_tp(entry_price, is_buy=True, sl_points=50, tp_points=100)
    print(f"Fixed Points SL/TP (50/100 points):")
    print(f"  SL: {sl3:.5f}")
    print(f"  TP: {tp3:.5f}")
    print()
    
    # Test Percentage
    sl4, tp4 = sl_calc.percentage_sl_tp(entry_price, is_buy=True, sl_percent=0.5, tp_percent=1.0)
    print(f"Percentage SL/TP (0.5%/1.0%):")
    print(f"  SL: {sl4:.5f}")
    print(f"  TP: {tp4:.5f}")
    print()
    
    # Visualisation
    plt.figure(figsize=(14, 8))
    
    # Prix
    plt.plot(df_test.index, df_test['close'], label='Close', color='black', linewidth=1.5)
    
    # Marquer le point d'entrée
    entry_time = df_test.index[test_idx]
    plt.scatter(entry_time, entry_price, color='blue', s=200, marker='o', zorder=5, label='Entry')
    
    # Marquer les SL/TP
    plt.axhline(y=sl1, color='red', linestyle='--', alpha=0.7, label=f'SL Swing: {sl1:.5f}')
    plt.axhline(y=tp1, color='green', linestyle='--', alpha=0.7, label=f'TP Swing: {tp1:.5f}')
    
    plt.axhline(y=sl2, color='orange', linestyle=':', alpha=0.7, label=f'SL ATR: {sl2:.5f}')
    plt.axhline(y=tp2, color='lightgreen', linestyle=':', alpha=0.7, label=f'TP ATR: {tp2:.5f}')
    
    plt.title('Stop Loss Calculator Test - Various Methods')
    plt.xlabel('Time')
    plt.ylabel('Price')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig('stoploss_test.png', dpi=150)
    print("Graphique sauvegardé: stoploss_test.png")

