"""
Configuration simple pour tester le backtest
Avec moins de filtres pour obtenir des signaux
"""
from config import StrategyConfig, EntryMode

def get_simple_config():
    """Configuration simple avec moins de filtres"""
    config = StrategyConfig()
    
    # Bollinger Bands - standard
    config.bollinger.period = 20
    config.bollinger.deviation = 2.0
    
    # Désactiver RSI filter
    config.rsi.use_filter = False
    
    # Désactiver EMA filter
    config.ema.use_filter = False
    
    # Désactiver divergence
    config.divergence.use_validator = False
    
    # Désactiver filtres temps
    config.time_filter.use_time_filter = False
    
    # Mode REVERSION
    config.entry.entry_mode = EntryMode.REVERSION
    
    # Money Management - plus agressif
    config.money_management.risk_percent = 1.0
    config.money_management.one_pos_per_symbol = True
    
    # Stop Loss/Take Profit - standards
    config.stop_loss.sl_period = 50
    config.stop_loss.tp_period = 30
    config.stop_loss.min_rr = 1.5
    
    return config


if __name__ == "__main__":
    cfg = get_simple_config()
    print("Configuration simple:")
    print(f"  Bollinger: BB({cfg.bollinger.period}, {cfg.bollinger.deviation})")
    print(f"  RSI Filter: {cfg.rsi.use_filter}")
    print(f"  EMA Filter: {cfg.ema.use_filter}")
    print(f"  Divergence: {cfg.divergence.use_validator}")
    print(f"  Entry Mode: {cfg.entry.entry_mode.value}")
    print(f"  Risk: {cfg.money_management.risk_percent}%")

