# Quick Start: CSV Backtesting

Get started with backtesting in 5 minutes!

## 1️⃣ Installation

```bash
# Navigate to the Pyth directory
cd Pyth/

# Ensure dependencies are installed
pip install pandas numpy matplotlib
```

## 2️⃣ Run Your First Backtest

Create a file `my_first_backtest.py`:

```python
from ea_launcher import MT5EALauncher

# Create launcher
launcher = MT5EALauncher()

# Create a simple configuration
config = launcher.create_configuration(
    config_name="My_First_Strategy",
    symbol="EURUSD",
    timeframe="H1",
    entry_mode="REVERSION",
    risk_percent=1.0,
    min_rr=2.0
)

# Run backtest
backtester = launcher.run_csv_backtest(
    config=config,
    csv_file="EURUSD_PERIOD_M1_20170101_20250102.csv",
    initial_deposit=10000.0,
    target_timeframe="H1"
)

# View results
if backtester:
    stats = backtester.get_statistics()
    print(f"\n✅ Backtest Complete!")
    print(f"Total Return: {stats['total_return_pct']:.2f}%")
    print(f"Win Rate: {stats['win_rate_pct']:.1f}%")
    print(f"Total Trades: {stats['total_trades']}")
```

Run it:
```bash
python my_first_backtest.py
```

## 3️⃣ View Generated Files

After running, you'll find:
- `backtest_trades_*.csv` - Detailed trade log
- `backtest_equity_*.png` - Equity curve chart
- `backtest_analysis_*.png` - Trade analysis charts
- `backtest_stats_*.json` - Performance statistics

## 4️⃣ Try the Examples

```bash
# Run interactive examples
python backtest_example.py
```

Choose from:
1. Single backtest
2. Compare multiple strategies
3. Advanced custom backtest
4. Multi-timeframe analysis
5. Parameter optimization

## 5️⃣ Compare Multiple Strategies

```python
from ea_launcher import MT5EALauncher

launcher = MT5EALauncher()

# Create 3 different strategies
launcher.create_configuration(
    config_name="Conservative",
    risk_percent=0.5,
    min_rr=2.5
)

launcher.create_configuration(
    config_name="Moderate",
    risk_percent=1.0,
    min_rr=2.0
)

launcher.create_configuration(
    config_name="Aggressive",
    risk_percent=1.5,
    min_rr=1.5
)

# Batch test all
comparison = launcher.batch_csv_backtest(
    csv_file="EURUSD_PERIOD_M1_20170101_20250102.csv",
    initial_deposit=10000.0
)

# View comparison
print(comparison[['config_name', 'total_return_pct', 'win_rate_pct']])
```

## 📊 Understanding Output

```
Backtester initialized: My_First_Strategy
Initial deposit: $10,000.00

📊 Loading data from: EURUSD_PERIOD_M1_20170101_20250102.csv
   Loaded 12000 bars from 2024-01-02 to 2025-01-02
   Source timeframe: M1
   Resampled to H1: 500 bars

📈 Calculating indicators...
   ✓ Bollinger Bands (period=20, dev=2.0)
   ✓ RSI (period=14)
   ✓ EMA (fast=50, slow=100)
   ✓ ATR (period=50)

🎯 Generating trading signals...
   Generated 45 BUY and 38 SELL signals

💰 Simulating trades...
   Executed 83 trades
   Final equity: $12,450.00
   Total return: 24.50%

📊 BACKTEST RESULTS
💰 Financial Results:
   Total Return: 24.50%
   Total Profit: $2,450.00

📈 Trading Performance:
   Total Trades: 83
   Win Rate: 62.7%
   Profit Factor: 2.15

📊 Risk Metrics:
   Max Drawdown: 12.3%
   Sharpe Ratio: 1.85
```

## 🎯 Key Metrics

| Metric | What It Means | Good Value |
|--------|---------------|------------|
| **Total Return** | Overall profit/loss | > 10% |
| **Win Rate** | % of winning trades | 40-60% |
| **Profit Factor** | Profit/Loss ratio | > 1.5 |
| **Max Drawdown** | Worst decline | < 20% |
| **Sharpe Ratio** | Risk-adjusted return | > 1.0 |

## 🔧 Customize Strategy

### Change Entry Mode

```python
# Mean Reversion (buy dips, sell rallies)
entry_mode="REVERSION"

# Breakout (buy strength, sell weakness)
entry_mode="BREAKOUT"
```

### Adjust Risk

```python
risk_percent=0.5    # Conservative (0.5% per trade)
risk_percent=1.0    # Moderate (1% per trade)
risk_percent=2.0    # Aggressive (2% per trade)
```

### Modify Indicators

```python
# Tighter Bollinger Bands (more signals)
bb_period=15
bb_deviation=1.5

# Wider Bollinger Bands (fewer, higher quality signals)
bb_period=25
bb_deviation=2.5
```

### Add Filters

```python
# RSI Filter
use_rsi_filter=True
rsi_oversold=30.0
rsi_overbought=70.0

# EMA Trend Filter
use_ema_filter=True
ema_mode="TREND"  # Only trade with trend

# Time Filter
use_time_filter=True
hour_ranges="8-10;14-16"  # Trade during active hours
```

## 🎓 Next Steps

1. ✅ Read `BACKTESTING_GUIDE.md` for detailed documentation
2. ✅ Try different timeframes (M15, H1, H4)
3. ✅ Experiment with parameters
4. ✅ Compare multiple strategies
5. ✅ Optimize parameters using grid search

## 🚨 Common Issues

**Problem**: "No trades executed"
**Solution**: Relax filters or try different timeframe

**Problem**: "CSV file not found"  
**Solution**: Use full path to CSV file

**Problem**: Low win rate but profitable
**Solution**: This is OK! With 2:1 R:R, 40% win rate is profitable

**Problem**: High win rate but losing money
**Solution**: Check R:R ratio - you're cutting winners too early

## 💡 Tips

1. **Start Simple**: Test with default parameters first
2. **Use Realistic Risk**: 0.5-2% per trade is typical
3. **Test Multiple Timeframes**: Same strategy works differently on H1 vs H4
4. **Compare to Buy & Hold**: Is your strategy better than just buying and holding?
5. **Watch Drawdown**: Can you handle 15% drawdown psychologically?

## 📞 Need Help?

- Check `BACKTESTING_GUIDE.md` for detailed info
- Run `python backtest_example.py` for interactive examples
- Review the generated trade log CSV to understand behavior

---

**Happy Trading! 🚀**

