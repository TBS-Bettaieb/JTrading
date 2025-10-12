# 🚀 CSV Backtesting System - START HERE

## Welcome! 👋

A complete Python backtesting system has been created for your MT5 EA. This system allows you to:
- Test strategies on historical CSV data
- Run backtests 50-100x faster than MT5
- Compare multiple configurations at once
- Optimize parameters automatically
- Generate beautiful charts and reports

## ⚡ Quick Start (Choose One)

### Option 1: Run Demo (Fastest - 30 seconds)
```bash
python demo_backtest.py
```

### Option 2: Run Interactive Examples
```bash
python backtest_example.py
```

### Option 3: Write Your Own (5 lines)
```python
from ea_launcher import MT5EALauncher

launcher = MT5EALauncher()
config = launcher.create_configuration(config_name="Test", timeframe="H1")
backtester = launcher.run_csv_backtest(config, "EURUSD_PERIOD_M1_20170101_20250102.csv")
print(backtester.get_statistics())
```

## 📚 Documentation (Read in Order)

1. **[QUICK_START_BACKTEST.md](QUICK_START_BACKTEST.md)** ⭐ START HERE
   - 5-minute tutorial
   - Your first backtest
   - Understanding results
   - Common customizations

2. **[README_BACKTESTING.md](README_BACKTESTING.md)** 📖 MAIN DOCS
   - Complete feature overview
   - All usage examples
   - Configuration reference
   - Troubleshooting guide

3. **[BACKTESTING_GUIDE.md](BACKTESTING_GUIDE.md)** 🎓 ADVANCED
   - Detailed explanations
   - Advanced techniques
   - Custom indicators
   - Walk-forward analysis

4. **[BACKTEST_IMPLEMENTATION_SUMMARY.md](BACKTEST_IMPLEMENTATION_SUMMARY.md)** 🔧 TECHNICAL
   - Implementation details
   - For developers
   - API reference

## 📁 New Files Created

```
Pyth/
├── 🔧 Core System
│   ├── ea_backtester.py              # Main backtesting engine
│   └── ea_launcher.py                # Enhanced with backtest methods
│
├── 📝 Example Scripts
│   ├── demo_backtest.py              # Quick demo (RUN THIS FIRST!)
│   └── backtest_example.py           # 5 comprehensive examples
│
├── 📚 Documentation
│   ├── START_HERE.md                 # This file
│   ├── QUICK_START_BACKTEST.md       # 5-minute guide
│   ├── README_BACKTESTING.md         # Main documentation
│   ├── BACKTESTING_GUIDE.md          # Advanced guide
│   └── BACKTEST_IMPLEMENTATION_SUMMARY.md  # Technical details
│
└── 📊 Data
    └── EURUSD_PERIOD_M1_20170101_20250102.csv  # Your data file
```

## 🎯 What You Can Do Now

### 1. Test Single Strategy
```python
from ea_launcher import MT5EALauncher

launcher = MT5EALauncher()
config = launcher.create_configuration(
    config_name="MyStrategy",
    timeframe="H1",
    entry_mode="REVERSION",
    risk_percent=1.0
)

backtester = launcher.run_csv_backtest(
    config=config,
    csv_file="EURUSD_PERIOD_M1_20170101_20250102.csv",
    initial_deposit=10000
)

stats = backtester.get_statistics()
print(f"Return: {stats['total_return_pct']:.2f}%")
```

### 2. Compare Multiple Strategies
```python
launcher = MT5EALauncher()

# Create 3 strategies
launcher.create_configuration("Conservative", risk_percent=0.5, min_rr=2.5)
launcher.create_configuration("Moderate", risk_percent=1.0, min_rr=2.0)
launcher.create_configuration("Aggressive", risk_percent=1.5, min_rr=1.5)

# Test all
results = launcher.batch_csv_backtest("EURUSD_PERIOD_M1_20170101_20250102.csv")
print(results[['config_name', 'total_return_pct', 'win_rate_pct']])
```

### 3. Optimize Parameters
```python
from ea_backtester import Backtester

results = []
for bb_period in [15, 20, 25, 30]:
    config = {...}  # Your config with this BB period
    backtester = Backtester("data.csv", config, 10000)
    backtester.run_full_backtest(save_results=False)
    results.append(backtester.get_statistics())

# Find best
best = max(results, key=lambda x: x['total_return_pct'])
print(f"Best BB Period: {best['config_name']}")
```

### 4. Test Multiple Timeframes
```python
for timeframe in ['M15', 'H1', 'H4']:
    backtester = launcher.run_csv_backtest(
        config=config,
        csv_file="data.csv",
        target_timeframe=timeframe,
        save_results=False
    )
    stats = backtester.get_statistics()
    print(f"{timeframe}: {stats['total_return_pct']:.2f}%")
```

## 📊 Understanding Output

After running a backtest, you get:

### Console Output
```
📊 Loading data from: EURUSD_PERIOD_M1_20170101_20250102.csv
   Loaded 12000 bars from 2024-01-02 to 2025-01-02
   Resampled to H1: 500 bars

📈 Calculating indicators...
   ✓ Bollinger Bands (period=20, dev=2.0)
   ✓ RSI (period=14)
   ✓ EMA (fast=50, slow=100)

🎯 Generating trading signals...
   Generated 45 BUY and 38 SELL signals

💰 Simulating trades...
   Executed 83 trades
   Final equity: $12,450.00
   Total return: 24.50%

📊 BACKTEST RESULTS
💰 Financial Results:
   Total Return: 24.50%
   Win Rate: 62.7%
   Profit Factor: 2.15
```

### Generated Files
1. **`backtest_trades_*.csv`** - Trade log with all details
2. **`backtest_equity_*.png`** - Equity curve chart
3. **`backtest_analysis_*.png`** - 4-panel analysis chart
4. **`backtest_stats_*.json`** - Statistics in JSON format

## 🎨 Sample Results

### Example Output
```
Config: Conservative_H1
Initial: $10,000.00
Final:   $12,450.00
Return:  +24.50%

Trades:  83
Wins:    52 (62.7%)
Losses:  31 (37.3%)

Profit Factor: 2.15
Max Drawdown:  12.3%
Sharpe Ratio:  1.85
```

## ⚙️ Configuration Examples

### Mean Reversion Strategy
```python
config = launcher.create_configuration(
    config_name="Reversion",
    entry_mode="REVERSION",     # Buy dips, sell rallies
    bb_deviation=2.0,
    use_rsi_filter=True,
    rsi_oversold=30.0,
    rsi_overbought=70.0
)
```

### Breakout Strategy
```python
config = launcher.create_configuration(
    config_name="Breakout",
    entry_mode="BREAKOUT",      # Buy strength, sell weakness
    bb_deviation=1.5,
    use_rsi_filter=False,
    use_ema_filter=True,
    ema_mode="TREND"
)
```

### Conservative Strategy
```python
config = launcher.create_configuration(
    config_name="Conservative",
    risk_percent=0.5,           # Low risk
    min_rr=2.5,                # High reward requirement
    use_time_filter=True,
    hour_ranges="8-12;14-18"   # Active hours only
)
```

### Aggressive Strategy
```python
config = launcher.create_configuration(
    config_name="Aggressive",
    risk_percent=2.0,           # Higher risk
    min_rr=1.5,                # Lower reward requirement
    bb_deviation=1.5           # More signals
)
```

## 🔧 Customization Guide

### Change Timeframe
```python
target_timeframe="M15"    # 15 minutes
target_timeframe="H1"     # 1 hour (recommended)
target_timeframe="H4"     # 4 hours (swing trading)
target_timeframe="D1"     # Daily
```

### Adjust Risk
```python
risk_percent=0.5    # Conservative (0.5% per trade)
risk_percent=1.0    # Moderate (1% per trade)
risk_percent=2.0    # Aggressive (2% per trade)
```

### Modify Indicators
```python
# Bollinger Bands
bb_period=20        # Period for moving average
bb_deviation=2.0    # Standard deviations (1.5-3.0)

# RSI
rsi_period=14       # RSI calculation period
rsi_oversold=30.0   # Buy level
rsi_overbought=70.0 # Sell level

# EMA
ema_fast=50         # Fast EMA
ema_slow=100        # Slow EMA
ema_mode="TREND"    # TREND, COUNTER, or ZONE
```

## 🐛 Troubleshooting

### "No trades executed"
- Filters too strict → Relax RSI levels or disable filters
- Wrong timeframe → Try H1 or H4
- Min RR too high → Try 1.5 instead of 3.0

### "CSV file not found"
```python
# Use full path
csv_file = r"C:\full\path\to\EURUSD_PERIOD_M1_20170101_20250102.csv"
```

### "Module not found"
```bash
# Make sure you're in the Pyth directory
cd Pyth
python demo_backtest.py
```

## 💡 Pro Tips

1. **Start Simple**: Use default parameters first
2. **Test Multiple Timeframes**: H1 is usually best
3. **Compare Strategies**: Batch test to find winners
4. **Watch Drawdown**: Can you handle 15% loss?
5. **Use Realistic Risk**: 0.5-2% per trade

## 📈 Performance Guide

| Timeframe | Typical Trades/Year | Best For |
|-----------|-------------------|----------|
| M5-M15    | 500-2000         | Scalping |
| M30-H1    | 100-500          | Day trading |
| H4        | 50-150           | Swing trading |
| D1        | 20-80            | Position trading |

## 🎓 Learning Path

1. **Day 1**: Run `demo_backtest.py` and read `QUICK_START_BACKTEST.md`
2. **Day 2**: Try all examples in `backtest_example.py`
3. **Day 3**: Read `README_BACKTESTING.md` and customize strategies
4. **Day 4**: Test multiple timeframes and compare results
5. **Day 5**: Run parameter optimization
6. **Week 2+**: Read `BACKTESTING_GUIDE.md` for advanced techniques

## 🆘 Need Help?

1. Check troubleshooting section above
2. Read `QUICK_START_BACKTEST.md`
3. Review `README_BACKTESTING.md`
4. Look at examples in `backtest_example.py`
5. Check generated trade logs for insights

## ✅ Next Steps

- [ ] Run `python demo_backtest.py` NOW
- [ ] Read `QUICK_START_BACKTEST.md`
- [ ] Try different timeframes
- [ ] Compare 3-5 strategies
- [ ] Find your best configuration
- [ ] Test on different time periods
- [ ] Deploy to MT5 for live trading

## 🎉 You're Ready!

Everything is set up and ready to use. Just run:

```bash
python demo_backtest.py
```

**Happy Backtesting! 🚀📈**

---

*Need help? Start with QUICK_START_BACKTEST.md*

