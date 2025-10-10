"""
Position Sizing
Calcul de la taille de position basée sur le risque
Conversion Python de JT_MoneyManagement.mqh
"""

import pandas as pd
import numpy as np
from typing import Optional, Tuple


class PositionSizer:
    """
    Calcule la taille de position basée sur différentes méthodes
    
    Méthodes:
    1. Fixed Percentage Risk (% du capital à risquer)
    2. Fixed Fractional (% fixe du capital)
    3. Kelly Criterion (basé sur l'historique des trades)
    4. ATR-based (basé sur la volatilité)
    """
    
    def __init__(
        self,
        min_volume: float = 0.01,
        max_volume: float = 100.0,
        volume_step: float = 0.01
    ):
        """
        Args:
            min_volume: Volume minimum autorisé
            max_volume: Volume maximum autorisé
            volume_step: Pas de volume (lot step)
        """
        self.min_volume = min_volume
        self.max_volume = max_volume
        self.volume_step = volume_step
    
    def normalize_volume(self, volume: float) -> float:
        """
        Normalise le volume selon les contraintes du broker
        
        Args:
            volume: Volume brut calculé
        
        Returns:
            Volume normalisé
        """
        # Limiter aux min/max
        volume = max(self.min_volume, min(self.max_volume, volume))
        
        # Arrondir au pas de volume
        volume = round(volume / self.volume_step) * self.volume_step
        
        # Arrondir à 2 décimales
        volume = round(volume, 2)
        
        return volume
    
    def fixed_percentage_risk(
        self,
        capital: float,
        risk_percent: float,
        entry_price: float,
        stop_loss: float,
        point_value: float = 1.0,
        leverage: int = 1
    ) -> float:
        """
        Calcule la taille de position basée sur le % de risque
        
        Args:
            capital: Capital disponible
            risk_percent: Pourcentage du capital à risquer (ex: 1.0 pour 1%)
            entry_price: Prix d'entrée
            stop_loss: Prix du stop loss
            point_value: Valeur d'un point de mouvement
            leverage: Levier utilisé
        
        Returns:
            Volume de la position
        """
        if stop_loss == 0 or entry_price == stop_loss:
            return self.min_volume
        
        # Montant à risquer
        risk_amount = capital * (risk_percent / 100.0)
        
        # Distance du stop loss en prix
        sl_distance = abs(entry_price - stop_loss)
        
        # Calcul du volume
        volume = risk_amount / (sl_distance * point_value)
        
        # Ajuster pour le levier si nécessaire
        if leverage > 1:
            volume = volume * leverage
        
        return self.normalize_volume(volume)
    
    def fixed_fractional(
        self,
        capital: float,
        fraction_percent: float,
        entry_price: float,
        point_value: float = 1.0
    ) -> float:
        """
        Calcule la taille de position comme fraction fixe du capital
        
        Args:
            capital: Capital disponible
            fraction_percent: Pourcentage du capital à utiliser
            entry_price: Prix d'entrée
            point_value: Valeur d'un point
        
        Returns:
            Volume de la position
        """
        # Montant à investir
        invest_amount = capital * (fraction_percent / 100.0)
        
        # Calculer le volume
        volume = invest_amount / (entry_price * point_value)
        
        return self.normalize_volume(volume)
    
    def kelly_criterion(
        self,
        capital: float,
        win_rate: float,
        avg_win: float,
        avg_loss: float,
        entry_price: float,
        stop_loss: float,
        point_value: float = 1.0,
        kelly_fraction: float = 0.5
    ) -> float:
        """
        Calcule la taille de position selon le critère de Kelly
        
        Args:
            capital: Capital disponible
            win_rate: Taux de réussite (0-1)
            avg_win: Gain moyen
            avg_loss: Perte moyenne (valeur positive)
            entry_price: Prix d'entrée
            stop_loss: Prix du stop loss
            point_value: Valeur d'un point
            kelly_fraction: Fraction du Kelly à utiliser (0.5 = demi-Kelly, recommandé)
        
        Returns:
            Volume de la position
        """
        if avg_loss == 0 or win_rate == 0 or win_rate == 1:
            # Fallback sur fixed percentage
            return self.fixed_percentage_risk(capital, 1.0, entry_price, stop_loss, point_value)
        
        # Formule de Kelly: f = (p*b - q) / b
        # où p = win_rate, q = 1-p, b = avg_win/avg_loss
        b = avg_win / avg_loss
        q = 1 - win_rate
        
        kelly_pct = (win_rate * b - q) / b
        
        # Limiter Kelly entre 0 et 1
        kelly_pct = max(0, min(1, kelly_pct))
        
        # Appliquer la fraction de Kelly (plus conservateur)
        kelly_pct *= kelly_fraction
        
        # Convertir en pourcentage
        risk_pct = kelly_pct * 100
        
        return self.fixed_percentage_risk(capital, risk_pct, entry_price, stop_loss, point_value)
    
    def atr_based(
        self,
        capital: float,
        risk_percent: float,
        entry_price: float,
        atr_value: float,
        atr_multiplier: float = 2.0,
        point_value: float = 1.0
    ) -> float:
        """
        Calcule la taille de position basée sur l'ATR
        
        Args:
            capital: Capital disponible
            risk_percent: Pourcentage du capital à risquer
            entry_price: Prix d'entrée
            atr_value: Valeur actuelle de l'ATR
            atr_multiplier: Multiplicateur de l'ATR pour le SL
            point_value: Valeur d'un point
        
        Returns:
            Volume de la position
        """
        if atr_value == 0:
            return self.min_volume
        
        # Stop loss basé sur ATR
        sl_distance = atr_value * atr_multiplier
        
        # Calculer le SL virtuel
        virtual_sl = entry_price - sl_distance  # Pour un achat
        
        return self.fixed_percentage_risk(capital, risk_percent, entry_price, virtual_sl, point_value)
    
    def optimal_f(
        self,
        capital: float,
        trade_results: list,
        entry_price: float,
        stop_loss: float,
        point_value: float = 1.0
    ) -> float:
        """
        Calcule la taille optimale selon la méthode Optimal f de Ralph Vince
        
        Args:
            capital: Capital disponible
            trade_results: Liste des résultats des trades passés (P&L)
            entry_price: Prix d'entrée
            stop_loss: Prix du stop loss
            point_value: Valeur d'un point
        
        Returns:
            Volume de la position
        """
        if len(trade_results) < 10:
            # Pas assez d'historique, utiliser fixed percentage
            return self.fixed_percentage_risk(capital, 1.0, entry_price, stop_loss, point_value)
        
        # Trouver la perte maximale
        max_loss = abs(min(trade_results))
        
        if max_loss == 0:
            return self.min_volume
        
        # Calculer l'optimal f (simplifié)
        # C'est une méthode itérative, ici on utilise une approximation
        best_f = 0.0
        best_twr = 0.0
        
        # Tester différentes valeurs de f entre 0 et 1
        for f in np.arange(0.01, 1.0, 0.01):
            twr = 1.0  # Terminal Wealth Relative
            
            for result in trade_results:
                hpr = 1 + (f * result / max_loss)  # Holding Period Return
                twr *= hpr
            
            if twr > best_twr:
                best_twr = twr
                best_f = f
        
        # Utiliser la moitié de l'optimal f (plus conservateur)
        optimal_f_pct = best_f * 0.5 * 100
        
        return self.fixed_percentage_risk(capital, optimal_f_pct, entry_price, stop_loss, point_value)
    
    def calculate_position_value(
        self,
        volume: float,
        entry_price: float,
        point_value: float = 1.0
    ) -> float:
        """
        Calcule la valeur totale de la position
        
        Args:
            volume: Volume de la position
            entry_price: Prix d'entrée
            point_value: Valeur d'un point
        
        Returns:
            Valeur en capital de la position
        """
        return volume * entry_price * point_value
    
    def calculate_risk_amount(
        self,
        volume: float,
        entry_price: float,
        stop_loss: float,
        point_value: float = 1.0
    ) -> float:
        """
        Calcule le montant à risque pour une position
        
        Args:
            volume: Volume de la position
            entry_price: Prix d'entrée
            stop_loss: Prix du stop loss
            point_value: Valeur d'un point
        
        Returns:
            Montant à risque en capital
        """
        sl_distance = abs(entry_price - stop_loss)
        return volume * sl_distance * point_value
    
    def get_max_positions(
        self,
        capital: float,
        risk_percent_per_trade: float,
        max_total_risk_percent: float = 10.0
    ) -> int:
        """
        Calcule le nombre maximum de positions simultanées
        
        Args:
            capital: Capital disponible
            risk_percent_per_trade: Risque par trade (%)
            max_total_risk_percent: Risque total maximum (%)
        
        Returns:
            Nombre maximum de positions simultanées
        """
        max_positions = int(max_total_risk_percent / risk_percent_per_trade)
        return max(1, max_positions)
    
    def __repr__(self) -> str:
        return f"PositionSizer(min={self.min_volume}, max={self.max_volume}, step={self.volume_step})"


if __name__ == "__main__":
    # Test du position sizer
    sizer = PositionSizer(min_volume=0.01, max_volume=100.0, volume_step=0.01)
    
    # Paramètres de test
    capital = 10000
    risk_pct = 1.0  # 1% de risque
    entry_price = 1.10000
    stop_loss = 1.09500
    point_value = 10.0  # Pour EURUSD, 1 pip = 10 USD pour 1 lot
    
    print("Position Sizer Test")
    print("=" * 50)
    print(f"Capital: ${capital}")
    print(f"Entry: {entry_price}")
    print(f"Stop Loss: {stop_loss}")
    print(f"Risk Distance: {abs(entry_price - stop_loss):.5f}")
    print()
    
    # Test Fixed Percentage Risk
    volume1 = sizer.fixed_percentage_risk(capital, risk_pct, entry_price, stop_loss, point_value)
    risk1 = sizer.calculate_risk_amount(volume1, entry_price, stop_loss, point_value)
    print(f"Fixed % Risk ({risk_pct}%):")
    print(f"  Volume: {volume1:.2f} lots")
    print(f"  Risk Amount: ${risk1:.2f}")
    print(f"  Position Value: ${sizer.calculate_position_value(volume1, entry_price, point_value):.2f}")
    print()
    
    # Test Fixed Fractional
    volume2 = sizer.fixed_fractional(capital, 10.0, entry_price, point_value)
    print(f"Fixed Fractional (10% of capital):")
    print(f"  Volume: {volume2:.2f} lots")
    print()
    
    # Test Kelly Criterion
    volume3 = sizer.kelly_criterion(
        capital, 
        win_rate=0.55, 
        avg_win=150, 
        avg_loss=100,
        entry_price=entry_price,
        stop_loss=stop_loss,
        point_value=point_value,
        kelly_fraction=0.5
    )
    print(f"Kelly Criterion (50% Kelly):")
    print(f"  Volume: {volume3:.2f} lots")
    print()
    
    # Test ATR-based
    atr_value = 0.0050
    volume4 = sizer.atr_based(capital, risk_pct, entry_price, atr_value, 2.0, point_value)
    print(f"ATR-based (ATR={atr_value}, 2x multiplier):")
    print(f"  Volume: {volume4:.2f} lots")
    print()
    
    # Max positions
    max_pos = sizer.get_max_positions(capital, risk_pct, max_total_risk_percent=5.0)
    print(f"Max simultaneous positions (5% total risk): {max_pos}")

