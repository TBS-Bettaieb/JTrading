"""Package de configuration"""

from .settings import (
    StrategyConfig,
    DEFAULT_CONFIG,
    get_conservative_config,
    get_aggressive_config,
    get_scalping_config,
    get_swing_trading_config,
    EntryMode,
    TradeDirection,
    EMAMode,
)

__all__ = [
    'StrategyConfig',
    'DEFAULT_CONFIG',
    'get_conservative_config',
    'get_aggressive_config',
    'get_scalping_config',
    'get_swing_trading_config',
    'EntryMode',
    'TradeDirection',
    'EMAMode',
]

