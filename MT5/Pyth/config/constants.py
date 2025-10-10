"""
Constantes globales du système de trading
"""

# ========== VALEURS PAR DÉFAUT ==========

# Backtesting
DEFAULT_INITIAL_CAPITAL = 10000.0
DEFAULT_COMMISSION = 0.0002  # 0.02%
DEFAULT_SLIPPAGE_POINTS = 2.0
DEFAULT_POINT_SIZE = 0.0001  # Pour Forex 5 digits
DEFAULT_POINT_VALUE = 10.0   # Pour EURUSD 1 lot

# Money Management
DEFAULT_RISK_PERCENT = 1.0
MIN_RISK_PERCENT = 0.1
MAX_RISK_PERCENT = 10.0
DEFAULT_MIN_VOLUME = 0.01
DEFAULT_MAX_VOLUME = 100.0
DEFAULT_VOLUME_STEP = 0.01

# Indicateurs
DEFAULT_BB_PERIOD = 20
DEFAULT_BB_DEVIATION = 2.0
DEFAULT_RSI_PERIOD = 14
DEFAULT_RSI_OVERSOLD = 30
DEFAULT_RSI_OVERBOUGHT = 70
DEFAULT_EMA_FAST = 12
DEFAULT_EMA_SLOW = 26
DEFAULT_ATR_PERIOD = 14

# Stop Loss / Take Profit
DEFAULT_SL_PERIOD = 50
DEFAULT_TP_PERIOD = 30
DEFAULT_MIN_RR = 1.5
DEFAULT_ATR_MULTIPLIER = 2.0

# ========== SEUILS CRITIQUES ==========

# RSI
RSI_EXTREME_OVERSOLD = 20
RSI_EXTREME_OVERBOUGHT = 80

# Confidence
CONFIDENCE_MIN = 0.0
CONFIDENCE_MAX = 1.0
CONFIDENCE_BASE = 0.5
CONFIDENCE_BOOST_EXTREME_RSI = 0.2
CONFIDENCE_BOOST_BB_EXPANSION = 0.15
CONFIDENCE_BOOST_EMA_ALIGNMENT = 0.15

# Risk Management
MAX_OPEN_POSITIONS = 10
MAX_TOTAL_RISK_PERCENT = 10.0
KELLY_FRACTION = 0.5  # Utiliser 50% du Kelly optimal (plus conservateur)

# ========== TIMEFRAMES ==========

# Nombre de périodes de trading par an (pour annualisation)
TRADING_PERIODS_PER_YEAR = {
    'M1': 525600,   # Minutes par an
    'M3': 175200,
    'M5': 105120,
    'M15': 35040,
    'M30': 17520,
    'H1': 8760,     # Heures par an
    'H4': 2190,
    'D1': 365,      # Jours par an
    'W1': 52,       # Semaines par an
    'MN1': 12       # Mois par an
}

# Pour Sharpe ratio (jours de trading par an)
TRADING_DAYS_PER_YEAR = 252

# ========== MT5 ==========

# Timeouts
MT5_DEFAULT_TIMEOUT = 60000  # ms
MT5_RETRY_MAX = 3
MT5_RETRY_DELAY = 0.5  # secondes
MT5_RETRY_BACKOFF = 2.0

# ========== PERFORMANCE ==========

# Limites pour warnings
WARNING_DRAWDOWN_PCT = 20.0
WARNING_WIN_RATE = 30.0
WARNING_PROFIT_FACTOR = 1.0

# Minimum de trades pour stats fiables
MIN_TRADES_FOR_STATS = 30

# ========== POINT SIZE PAR SYMBOLE ==========

POINT_SIZE_MAP = {
    # Forex major pairs (5 digits)
    'EURUSD': 0.00001,
    'GBPUSD': 0.00001,
    'USDJPY': 0.001,  # 3 digits
    'USDCHF': 0.00001,
    'AUDUSD': 0.00001,
    'USDCAD': 0.00001,
    'NZDUSD': 0.00001,
    
    # Indices
    'US100': 0.01,
    'US100.cash': 0.01,
    'US30': 0.01,
    'US500': 0.01,
    'GER40': 0.01,
    
    # Crypto
    'BTCUSD': 0.01,
    'ETHUSD': 0.01,
    
    # Commodities
    'XAUUSD': 0.01,  # Gold
    'XAGUSD': 0.001,  # Silver
    'USOIL': 0.01,
    'UKOIL': 0.01,
}

# Point value par symbole (pour 1 lot)
POINT_VALUE_MAP = {
    'EURUSD': 10.0,
    'GBPUSD': 10.0,
    'USDJPY': 10.0,
    'US100.cash': 1.0,
    'XAUUSD': 1.0,
}

# ========== VALIDATION ==========

# Limites pour validation
MAX_PRICE = 1000000.0
MIN_PRICE = 0.00001
MAX_SPREAD_POINTS = 100
MAX_RR_RATIO = 100.0
MIN_RR_RATIO = 0.1

# ========== LOGGING ==========

LOG_LEVELS = ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']
DEFAULT_LOG_LEVEL = 'INFO'

# ========== PATHS ==========

DEFAULT_CACHE_DIR = 'data_cache'
DEFAULT_LOGS_DIR = 'logs'
DEFAULT_REPORTS_DIR = 'reports'
DEFAULT_PLOTS_DIR = 'plots'

