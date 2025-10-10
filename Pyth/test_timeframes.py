"""Test rapide des timeframes disponibles"""
import MetaTrader5 as mt5
from datetime import datetime, timedelta

mt5.initialize()
mt5.symbol_select('EURUSD', True)

end = datetime.now()
start = end - timedelta(days=30)

timeframes = {
    'M1': mt5.TIMEFRAME_M1,
    'M3': mt5.TIMEFRAME_M3,
    'M5': mt5.TIMEFRAME_M5,
    'M15': mt5.TIMEFRAME_M15,
    'M30': mt5.TIMEFRAME_M30,
    'H1': mt5.TIMEFRAME_H1,
}

print("\n📊 Test des timeframes pour EURUSD:")
print("=" * 50)

for name, tf_const in timeframes.items():
    rates = mt5.copy_rates_range('EURUSD', tf_const, start, end)
    count = len(rates) if rates is not None else 0
    status = "✅" if count > 0 else "❌"
    error = mt5.last_error() if count == 0 else ""
    print(f"{name:5} {status} {count:6} barres   {error}")

mt5.shutdown()
print("=" * 50)

