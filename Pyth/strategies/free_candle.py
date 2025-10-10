"""
Free Candle Strategy
Stratégie basée sur les bougies hors des Bollinger Bands
Conversion Python de la logique MQL5
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Tuple, Optional
from dataclasses import dataclass
from datetime import datetime

from config.settings import StrategyConfig, EntryMode, TradeDirection, EMAMode
from indicators import BollingerBands, RSI, EMA, ATR


@dataclass
class Signal:
    """Signal de trading généré par la stratégie"""
    timestamp: datetime
    direction: int  # 1=buy, -1=sell
    entry_price: float
    sl_price: float
    tp_price: float
    rr_ratio: float
    confidence: float
    indicators: Dict[str, float]
    reason: str = ""  # Raison du signal
    
    def validate(self) -> tuple:
        """
        Valide que le signal est cohérent
        
        Returns:
            Tuple (is_valid, error_message)
        """
        errors = []
        
        # Vérifier la direction
        if self.direction not in [-1, 1]:
            errors.append(f"Direction invalide: {self.direction} (doit être 1 ou -1)")
        
        # Vérifier les prix positifs
        if self.entry_price <= 0:
            errors.append(f"Entry price invalide: {self.entry_price}")
        if self.sl_price <= 0:
            errors.append(f"SL price invalide: {self.sl_price}")
        if self.tp_price <= 0:
            errors.append(f"TP price invalide: {self.tp_price}")
        
        # Vérifier la logique SL/TP selon la direction
        if self.direction == 1:  # BUY
            if self.sl_price >= self.entry_price:
                errors.append(f"BUY: SL ({self.sl_price}) doit être < entry ({self.entry_price})")
            if self.tp_price <= self.entry_price:
                errors.append(f"BUY: TP ({self.tp_price}) doit être > entry ({self.entry_price})")
        else:  # SELL
            if self.sl_price <= self.entry_price:
                errors.append(f"SELL: SL ({self.sl_price}) doit être > entry ({self.entry_price})")
            if self.tp_price >= self.entry_price:
                errors.append(f"SELL: TP ({self.tp_price}) doit être < entry ({self.entry_price})")
        
        # Vérifier RR ratio
        if self.rr_ratio <= 0:
            errors.append(f"RR ratio invalide: {self.rr_ratio} (doit être > 0)")
        
        # Vérifier confidence
        if not (0 <= self.confidence <= 1):
            errors.append(f"Confidence invalide: {self.confidence} (doit être entre 0 et 1)")
        
        if errors:
            return False, "; ".join(errors)
        
        return True, ""


class FreeCandleStrategy:
    """
    Stratégie principale basée sur les Free Candles
    
    Logique:
    1. Détecte les bougies hors Bollinger Bands ("Free Candles")
    2. Applique les filtres (RSI, EMA, divergence)
    3. Calcule SL/TP dynamiques
    4. Génère des signaux de trading
    """
    
    def __init__(self, config: StrategyConfig):
        self.config = config
        
        # Initialiser les indicateurs
        self.bb = BollingerBands(
            period=config.bollinger.period,
            deviation=config.bollinger.deviation,
            shift=config.bollinger.shift
        )
        
        self.rsi = RSI(
            period=config.rsi.period,
            oversold=config.rsi.oversold,
            overbought=config.rsi.overbought
        )
        
        self.ema = EMA(
            periods=[config.ema.fast_period, config.ema.slow_period]
        )
        
        self.atr = ATR(period=config.stop_loss.atr_period)
        
        # Variable pour la divergence (si activée)
        self.divergence_memory = None
    
    def prepare_data(self, df: pd.DataFrame, inplace: bool = False) -> pd.DataFrame:
        """
        Prépare les données avec tous les indicateurs
        
        Args:
            df: DataFrame avec colonnes OHLCV
            inplace: Si True, modifie le DataFrame original (économie mémoire)
        
        Returns:
            DataFrame avec tous les indicateurs calculés
        """
        if not inplace:
            df = df.copy()
        
        # Calculer les indicateurs (inplace pour éviter les copies multiples)
        self.bb.calculate(df, inplace=True)
        self.rsi.calculate_dataframe(df, inplace=True)
        self.ema.calculate(df, inplace=True)
        self.atr.calculate_dataframe(df, inplace=True)
        
        return df
    
    def check_time_filter(self, timestamp: datetime) -> bool:
        """
        Vérifie si l'heure est autorisée pour le trading
        
        Args:
            timestamp: Timestamp à vérifier
        
        Returns:
            True si l'heure est autorisée
        """
        if not self.config.time_filter.use_time_filter:
            return True
        
        hour = timestamp.hour
        
        # Parser les plages horaires
        hour_ranges = self.config.time_filter.hour_ranges.split(';')
        
        for hour_range in hour_ranges:
            if '-' in hour_range:
                # Plage (ex: "8-10")
                start, end = map(int, hour_range.split('-'))
                if start <= hour < end:
                    return True
            else:
                # Heure unique (ex: "16")
                if int(hour_range) == hour:
                    return True
        
        return False
    
    def check_day_filter(self, timestamp: datetime) -> bool:
        """
        Vérifie si le jour est autorisé pour le trading
        
        Args:
            timestamp: Timestamp à vérifier
        
        Returns:
            True si le jour est autorisé
        """
        if not self.config.time_filter.use_day_filter:
            return True
        
        day_of_week = timestamp.weekday()  # 0=Lundi, 6=Dimanche
        
        # Parser les plages de jours
        day_ranges = self.config.time_filter.day_ranges.split(';')
        
        for day_range in day_ranges:
            if '-' in day_range:
                # Plage (ex: "1-5")
                start, end = map(int, day_range.split('-'))
                if start <= day_of_week <= end:
                    return True
            else:
                # Jour unique
                if int(day_range) == day_of_week:
                    return True
        
        return False
    
    def check_rsi_filter(self, row: pd.Series, direction: int) -> bool:
        """
        Vérifie le filtre RSI
        
        Args:
            row: Ligne de données avec RSI
            direction: 1 pour BUY, -1 pour SELL
        
        Returns:
            True si le filtre passe
        """
        if not self.config.rsi.use_filter:
            return True
        
        rsi = row['rsi']
        
        if pd.isna(rsi):
            return False
        
        if direction > 0:  # BUY signal
            return rsi < self.config.rsi.oversold
        else:  # SELL signal
            return rsi > self.config.rsi.overbought
    
    def check_ema_filter(self, row: pd.Series, direction: int) -> bool:
        """
        Vérifie le filtre EMA selon le mode configuré
        
        Args:
            row: Ligne de données avec EMAs
            direction: 1 pour BUY, -1 pour SELL
        
        Returns:
            True si le filtre passe
        """
        if not self.config.ema.use_filter:
            return True
        
        ema_fast_col = f'ema_{self.config.ema.fast_period}'
        ema_slow_col = f'ema_{self.config.ema.slow_period}'
        
        if ema_fast_col not in row or ema_slow_col not in row:
            return False
        
        ema_fast = row[ema_fast_col]
        ema_slow = row[ema_slow_col]
        price = row['close']
        
        if pd.isna(ema_fast) or pd.isna(ema_slow):
            return False
        
        uptrend = ema_fast > ema_slow
        downtrend = ema_fast < ema_slow
        
        # Taille d'un point (à ajuster selon le symbole)
        point_size = 0.0001  # Pour EURUSD
        
        if self.config.ema.filter_mode == EMAMode.TREND:
            # Mode TREND : Trade dans le sens de la tendance
            if direction > 0:  # BUY
                return uptrend and (price > ema_slow)
            else:  # SELL
                return downtrend and (price < ema_slow)
        
        elif self.config.ema.filter_mode == EMAMode.COUNTER:
            # Mode COUNTER : Trade les retournements aux extrêmes
            distance_points = abs(price - ema_fast) / point_size
            
            if direction > 0:  # BUY
                return downtrend and (price < ema_fast) and (distance_points > self.config.ema.zone_distance)
            else:  # SELL
                return uptrend and (price > ema_fast) and (distance_points > self.config.ema.zone_distance)
        
        elif self.config.ema.filter_mode == EMAMode.ZONE:
            # Mode ZONE : Évite la zone neutre entre les EMAs
            max_ema = max(ema_fast, ema_slow)
            min_ema = min(ema_fast, ema_slow)
            zone_margin = self.config.ema.zone_distance * point_size
            
            # Prix dans la zone neutre?
            in_zone = (price < max_ema + zone_margin) and (price > min_ema - zone_margin)
            
            return not in_zone
        
        return True
    
    def calculate_stops(
        self, 
        df: pd.DataFrame, 
        idx: int, 
        direction: int,
        point_size: float = 0.0001
    ) -> Tuple[float, float, float]:
        """
        Calcule SL et TP basés sur swing et ATR
        
        Args:
            df: DataFrame avec données et indicateurs
            idx: Index de la bougie courante
            direction: 1 pour BUY, -1 pour SELL
            point_size: Taille d'un point
        
        Returns:
            Tuple (sl, tp, rr_ratio)
        """
        current_row = df.iloc[idx]
        entry_price = current_row['close']
        
        # Période de lookback pour swing
        sl_period = self.config.stop_loss.sl_period
        tp_period = self.config.stop_loss.tp_period
        
        # Calculer SL basé sur swing
        start_idx = max(0, idx - sl_period)
        
        if direction > 0:  # BUY
            # SL au swing low
            swing_sl = df.iloc[start_idx:idx]['low'].min()
            # SL basé sur ATR
            atr_sl = entry_price - (self.config.stop_loss.atr_multiplier * current_row['atr'])
            # Prendre le plus protecteur
            sl = min(swing_sl, atr_sl)
        else:  # SELL
            # SL au swing high
            swing_sl = df.iloc[start_idx:idx]['high'].max()
            # SL basé sur ATR
            atr_sl = entry_price + (self.config.stop_loss.atr_multiplier * current_row['atr'])
            # Prendre le plus protecteur
            sl = max(swing_sl, atr_sl)
        
        # Calculer TP basé sur swing opposé ou ratio RR
        tp_start_idx = max(0, idx - tp_period)
        
        if direction > 0:  # BUY
            swing_tp = df.iloc[tp_start_idx:idx]['high'].max()
            # Vérifier si le TP swing est valide
            if swing_tp <= entry_price:
                # Utiliser ratio RR
                risk = abs(entry_price - sl)
                tp = entry_price + (risk * self.config.stop_loss.min_rr)
            else:
                tp = max(swing_tp, entry_price + abs(entry_price - sl) * self.config.stop_loss.min_rr)
        else:  # SELL
            swing_tp = df.iloc[tp_start_idx:idx]['low'].min()
            # Vérifier si le TP swing est valide
            if swing_tp >= entry_price:
                # Utiliser ratio RR
                risk = abs(sl - entry_price)
                tp = entry_price - (risk * self.config.stop_loss.min_rr)
            else:
                tp = min(swing_tp, entry_price - abs(sl - entry_price) * self.config.stop_loss.min_rr)
        
        # Calculer RR ratio
        risk = abs(entry_price - sl)
        reward = abs(tp - entry_price)
        rr_ratio = reward / risk if risk > 0 else 0
        
        return sl, tp, rr_ratio
    
    def calculate_confidence(self, row: pd.Series, direction: int) -> float:
        """
        Calcule un score de confiance pour le signal
        
        Args:
            row: Ligne de données avec indicateurs
            direction: 1 pour BUY, -1 pour SELL
        
        Returns:
            Score de confiance (0.0 - 1.0)
        """
        confidence = 0.5  # Base
        
        # RSI extrême augmente la confiance
        rsi = row['rsi']
        if not pd.isna(rsi):
            if direction > 0 and rsi < 25:
                confidence += 0.2
            elif direction < 0 and rsi > 75:
                confidence += 0.2
        
        # Largeur des bandes (expansion = plus de confiance)
        bb_width = row['bb_width']
        atr = row['atr']
        if not pd.isna(bb_width) and not pd.isna(atr) and atr > 0:
            if bb_width > atr * 2:
                confidence += 0.15
        
        # Alignement EMA
        ema_fast_col = f'ema_{self.config.ema.fast_period}'
        ema_slow_col = f'ema_{self.config.ema.slow_period}'
        
        if ema_fast_col in row and ema_slow_col in row:
            ema_fast = row[ema_fast_col]
            ema_slow = row[ema_slow_col]
            
            if not pd.isna(ema_fast) and not pd.isna(ema_slow):
                if (direction > 0 and ema_fast > ema_slow) or \
                   (direction < 0 and ema_fast < ema_slow):
                    confidence += 0.15
        
        return min(confidence, 1.0)
    
    def generate_signals(
        self, 
        df: pd.DataFrame, 
        point_size: float = 0.0001
    ) -> List[Signal]:
        """
        Génère les signaux de trading
        
        Args:
            df: DataFrame avec données OHLCV
            point_size: Taille d'un point pour le symbole
        
        Returns:
            Liste de signaux générés
        """
        # Préparer les données
        df = self.prepare_data(df)
        
        signals = []
        
        # Commencer après la période de warm-up des indicateurs
        start_idx = max(
            self.config.bollinger.period,
            self.config.rsi.period,
            self.config.ema.slow_period,
            self.config.stop_loss.sl_period
        ) + 1
        
        for i in range(start_idx, len(df)):
            row = df.iloc[i]
            prev_row = df.iloc[i-1]
            
            # Vérifier les filtres temporels
            if not self.check_time_filter(row.name):
                continue
            
            if not self.check_day_filter(row.name):
                continue
            
            # Vérifier Free Candle sur la bougie fermée (i-1)
            is_free, direction = self.bb.is_free_candle(
                prev_row,
                padding_points=self.config.entry.outside_padding_points,
                body_only=self.config.entry.body_must_be_outside,
                point_size=point_size
            )
            
            if not is_free or direction == 0:
                continue
            
            # Inverser la direction si mode BREAKOUT
            if self.config.entry.entry_mode == EntryMode.BREAKOUT:
                direction = -direction
            
            # Appliquer les filtres
            if not self.check_rsi_filter(row, direction):
                continue
            
            if not self.check_ema_filter(row, direction):
                continue
            
            # Vérifier la direction autorisée
            if self.config.entry.trade_direction == TradeDirection.ONLY_BUY and direction < 0:
                continue
            if self.config.entry.trade_direction == TradeDirection.ONLY_SELL and direction > 0:
                continue
            
            # Calculer SL et TP
            sl, tp, rr = self.calculate_stops(df, i, direction, point_size)
            
            # Vérifier RR minimum
            if rr < self.config.stop_loss.min_rr:
                continue
            
            # Créer le signal
            signal = Signal(
                timestamp=row.name,
                direction=direction,
                entry_price=row['close'],
                sl_price=sl,
                tp_price=tp,
                rr_ratio=rr,
                confidence=self.calculate_confidence(row, direction),
                indicators={
                    'rsi': row['rsi'],
                    'bb_width': row['bb_width'],
                    'atr': row['atr'],
                    f'ema_{self.config.ema.fast_period}': row[f'ema_{self.config.ema.fast_period}'],
                    f'ema_{self.config.ema.slow_period}': row[f'ema_{self.config.ema.slow_period}'],
                },
                reason=f"FreeCandle_{self.config.entry.entry_mode.name}"
            )
            
            # Valider le signal avant de l'ajouter
            is_valid, error_msg = signal.validate()
            if is_valid:
                signals.append(signal)
            else:
                print(f"⚠️ Signal invalide ignoré à {signal.timestamp}: {error_msg}")
        
        return signals
    
    def __repr__(self) -> str:
        return f"FreeCandleStrategy(symbol={self.config.symbol.symbol}, mode={self.config.entry.entry_mode.name})"


if __name__ == "__main__":
    # Test de la stratégie
    from config import StrategyConfig
    
    # Créer configuration de test
    config = StrategyConfig()
    config.symbol.symbol = "EURUSD"
    config.symbol.timeframe = "H1"
    
    # Créer données de test
    dates = pd.date_range('2024-01-01', periods=500, freq='H')
    np.random.seed(42)
    close_prices = 1.1000 + np.cumsum(np.random.randn(500) * 0.0005)
    
    df_test = pd.DataFrame({
        'open': close_prices - 0.0002,
        'high': close_prices + 0.0003,
        'low': close_prices - 0.0003,
        'close': close_prices,
        'volume': np.random.randint(100, 1000, 500)
    }, index=dates)
    
    # Créer la stratégie
    strategy = FreeCandleStrategy(config)
    
    # Générer des signaux
    signals = strategy.generate_signals(df_test)
    
    print(f"Stratégie: {strategy}")
    print(f"\nNombre de signaux générés: {len(signals)}")
    
    if signals:
        print("\nPremiers signaux:")
        for sig in signals[:5]:
            print(f"  {sig.timestamp} - {'BUY' if sig.direction > 0 else 'SELL'} @ {sig.entry_price:.5f}")
            print(f"    SL: {sig.sl_price:.5f}, TP: {sig.tp_price:.5f}, RR: 1:{sig.rr_ratio:.2f}")
            print(f"    Confiance: {sig.confidence:.2f}, RSI: {sig.indicators['rsi']:.1f}")
            print()

