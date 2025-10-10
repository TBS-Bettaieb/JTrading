"""
Configuration complète de la stratégie JTFreeCandle
Conversion Python de l'EA MQL5
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List


class EntryMode(Enum):
    """Mode d'entrée"""
    REVERSION = 0  # Mean reversion (retour à la moyenne)
    BREAKOUT = 1   # Breakout (cassure)


class TradeDirection(Enum):
    """Direction des trades autorisés"""
    BOTH = 0         # Les deux directions
    ONLY_BUY = 1     # Seulement achats
    ONLY_SELL = 2    # Seulement ventes


class EMAMode(Enum):
    """Mode de filtrage EMA"""
    TREND = 0     # Suivre la tendance
    COUNTER = 1   # Contre-tendance
    ZONE = 2      # Éviter la zone neutre


@dataclass
class SymbolConfig:
    """Configuration du symbole et timeframe"""
    symbol: str = "EURUSD"
    timeframe: str = "H1"  # M1, M5, M15, M30, H1, H4, D1
    
    def to_mt5_timeframe(self) -> int:
        """Convertit le timeframe en constante MT5"""
        import MetaTrader5 as mt5
        tf_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "M30": mt5.TIMEFRAME_M30,
            "H1": mt5.TIMEFRAME_H1,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1,
            "W1": mt5.TIMEFRAME_W1,
            "MN1": mt5.TIMEFRAME_MN1,
        }
        return tf_map.get(self.timeframe, mt5.TIMEFRAME_H1)


@dataclass
class BollingerBandsConfig:
    """Configuration des Bollinger Bands"""
    period: int = 20
    deviation: float = 2.0
    shift: int = 0
    apply_to: str = "close"  # close, open, high, low, median, typical, weighted


@dataclass
class RSIConfig:
    """Configuration du RSI"""
    use_filter: bool = True
    period: int = 14
    oversold: float = 29.0   # Seuil survente (pour BUY)
    overbought: float = 71.0  # Seuil surachat (pour SELL)


@dataclass
class EMAConfig:
    """Configuration des EMAs"""
    use_filter: bool = True
    fast_period: int = 50
    slow_period: int = 100
    filter_mode: EMAMode = EMAMode.COUNTER
    zone_distance: float = 20.0  # Distance zone en points


@dataclass
class DivergenceConfig:
    """Configuration de la divergence"""
    use_validator: bool = True
    rsi_buy_level: float = 35.0   # Seuil RSI pour validation BUY
    rsi_sell_level: float = 65.0  # Seuil RSI pour validation SELL
    swing_length: int = 5         # Longueur pivot pour divergence


@dataclass
class EntryConfig:
    """Configuration des entrées"""
    entry_mode: EntryMode = EntryMode.REVERSION
    trade_direction: TradeDirection = TradeDirection.BOTH
    outside_padding_points: int = 5      # Marge mini au-delà de la bande (points)
    body_must_be_outside: bool = False    # Seulement le corps hors bande


@dataclass
class MoneyManagementConfig:
    """Configuration du money management"""
    risk_percent: float = 0.1           # % risque par trade
    one_pos_per_symbol: bool = True     # 1 position par symbole max
    magic_number: int = 20251007
    min_volume: float = 0.01            # Volume minimum
    max_volume: float = 100.0           # Volume maximum


@dataclass
class StopLossConfig:
    """Configuration Stop Loss & Take Profit"""
    sl_period: int = 50            # Période pour SL (barres)
    tp_period: int = 30            # Période pour TP (barres)
    min_rr: float = 2.0            # Ratio RR minimum (0 = désactivé)
    atr_multiplier: float = 2.0    # Multiplicateur ATR (fallback SL)
    atr_period: int = 14           # Période ATR


@dataclass
class TimeFilterConfig:
    """Configuration des filtres temporels"""
    use_time_filter: bool = True
    hour_ranges: str = "8-10;16"  # Plages horaires (ex: 8-10;16)
    use_day_filter: bool = False
    day_ranges: str = "1-5"       # Jours autorisés (0=Dim,1=Lun...6=Sam)


@dataclass
class PositionManagementConfig:
    """Configuration de la gestion des positions"""
    close_on_opposite_band: bool = True  # Fermer si touche bande opposée
    be_on_middle_band: bool = True       # Break-Even sur médiane
    be_offset_points: int = 0            # Offset BE (points)
    use_flat_time: bool = False          # Clôture forcée à heure fixe
    flat_hour: int = 23                  # Heure de clôture
    flat_minute: int = 40                # Minute de clôture
    exit_use_prev_bar: bool = True       # Utiliser bandes barre fermée
    touch_pad_points: int = 5            # Marge de touche (points)


@dataclass
class BacktestConfig:
    """Configuration du backtesting"""
    initial_capital: float = 10000.0
    commission: float = 0.0002      # Commission par unité (0.02%)
    slippage_points: int = 2        # Slippage en points
    start_date: str = "2023-01-01"
    end_date: str = "2024-12-31"
    leverage: int = 100
    

@dataclass
class LiveTradingConfig:
    """Configuration du trading live"""
    mt5_login: int = 0
    mt5_password: str = ""
    mt5_server: str = ""
    check_interval: int = 60  # Vérification toutes les X secondes
    max_retries: int = 3
    retry_delay: int = 5


@dataclass
class LoggingConfig:
    """Configuration du logging"""
    level: str = "INFO"  # DEBUG, INFO, WARNING, ERROR
    log_to_file: bool = True
    log_file: str = "trading.log"
    log_to_console: bool = True
    enable_trade_log: bool = True
    trade_log_file: str = "trades.csv"


@dataclass
class VisualizationConfig:
    """Configuration de la visualisation"""
    plot_equity: bool = True
    plot_drawdown: bool = True
    plot_trades: bool = True
    plot_indicators: bool = True
    save_plots: bool = True
    plot_directory: str = "plots"


@dataclass
class StrategyConfig:
    """Configuration complète de la stratégie"""
    
    # Composants de configuration
    symbol: SymbolConfig = field(default_factory=SymbolConfig)
    bollinger: BollingerBandsConfig = field(default_factory=BollingerBandsConfig)
    rsi: RSIConfig = field(default_factory=RSIConfig)
    ema: EMAConfig = field(default_factory=EMAConfig)
    divergence: DivergenceConfig = field(default_factory=DivergenceConfig)
    entry: EntryConfig = field(default_factory=EntryConfig)
    money_management: MoneyManagementConfig = field(default_factory=MoneyManagementConfig)
    stop_loss: StopLossConfig = field(default_factory=StopLossConfig)
    time_filter: TimeFilterConfig = field(default_factory=TimeFilterConfig)
    position_management: PositionManagementConfig = field(default_factory=PositionManagementConfig)
    backtest: BacktestConfig = field(default_factory=BacktestConfig)
    live_trading: LiveTradingConfig = field(default_factory=LiveTradingConfig)
    logging: LoggingConfig = field(default_factory=LoggingConfig)
    visualization: VisualizationConfig = field(default_factory=VisualizationConfig)
    
    @classmethod
    def from_dict(cls, config_dict: dict) -> 'StrategyConfig':
        """Crée une configuration à partir d'un dictionnaire"""
        return cls(**config_dict)
    
    def to_dict(self) -> dict:
        """Convertit la configuration en dictionnaire"""
        return {
            'symbol': self.symbol.__dict__,
            'bollinger': self.bollinger.__dict__,
            'rsi': self.rsi.__dict__,
            'ema': self.ema.__dict__,
            'divergence': self.divergence.__dict__,
            'entry': self.entry.__dict__,
            'money_management': self.money_management.__dict__,
            'stop_loss': self.stop_loss.__dict__,
            'time_filter': self.time_filter.__dict__,
            'position_management': self.position_management.__dict__,
            'backtest': self.backtest.__dict__,
            'live_trading': self.live_trading.__dict__,
            'logging': self.logging.__dict__,
            'visualization': self.visualization.__dict__,
        }
    
    def save_to_yaml(self, filepath: str):
        """Sauvegarde la configuration dans un fichier YAML"""
        import yaml
        with open(filepath, 'w') as f:
            yaml.dump(self.to_dict(), f, default_flow_style=False)
    
    @classmethod
    def load_from_yaml(cls, filepath: str) -> 'StrategyConfig':
        """Charge la configuration depuis un fichier YAML"""
        import yaml
        with open(filepath, 'r') as f:
            config_dict = yaml.safe_load(f)
        return cls.from_dict(config_dict)


# Configuration par défaut
DEFAULT_CONFIG = StrategyConfig()


# Configurations prédéfinies

def get_conservative_config() -> StrategyConfig:
    """Configuration conservative (risque faible)"""
    config = StrategyConfig()
    config.money_management.risk_percent = 0.05
    config.stop_loss.min_rr = 3.0
    config.rsi.oversold = 25.0
    config.rsi.overbought = 75.0
    return config


def get_aggressive_config() -> StrategyConfig:
    """Configuration aggressive (risque élevé)"""
    config = StrategyConfig()
    config.money_management.risk_percent = 0.5
    config.stop_loss.min_rr = 1.5
    config.rsi.oversold = 35.0
    config.rsi.overbought = 65.0
    return config


def get_scalping_config() -> StrategyConfig:
    """Configuration pour scalping (timeframes courts)"""
    config = StrategyConfig()
    config.symbol.timeframe = "M5"
    config.bollinger.period = 10
    config.rsi.period = 7
    config.ema.fast_period = 20
    config.ema.slow_period = 50
    config.stop_loss.min_rr = 1.5
    config.money_management.risk_percent = 0.2
    return config


def get_swing_trading_config() -> StrategyConfig:
    """Configuration pour swing trading (timeframes longs)"""
    config = StrategyConfig()
    config.symbol.timeframe = "H4"
    config.bollinger.period = 30
    config.rsi.period = 21
    config.ema.fast_period = 100
    config.ema.slow_period = 200
    config.stop_loss.min_rr = 3.0
    config.money_management.risk_percent = 0.1
    return config


if __name__ == "__main__":
    # Test de la configuration
    config = StrategyConfig()
    print("Configuration par défaut:")
    print(f"Symbol: {config.symbol.symbol}")
    print(f"Timeframe: {config.symbol.timeframe}")
    print(f"BB Period: {config.bollinger.period}")
    print(f"RSI Period: {config.rsi.period}")
    print(f"Risk: {config.money_management.risk_percent}%")
    print(f"Min RR: {config.stop_loss.min_rr}")
    
    # Sauvegarder dans YAML
    config.save_to_yaml("default_config.yaml")
    print("\nConfiguration sauvegardée dans 'default_config.yaml'")

