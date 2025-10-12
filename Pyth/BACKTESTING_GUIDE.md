# MT5 EA CSV Backtesting System

A comprehensive, vectorized backtesting system for the JTFreeCandle_v2 MT5 Expert Advisor using historical CSV data.

## 🌟 Features

- **Fast Vectorized Backtesting**: Uses pandas/numpy for efficient computation
- **Complete Indicator Suite**: Bollinger Bands, RSI, EMA, ATR
- **Multiple Entry Modes**: REVERSION and BREAKOUT strategies
- **Advanced Filters**: RSI, EMA trend/counter-trend, time filters
- **Realistic Position Sizing**: Risk-based position sizing with proper SL/TP
- **Comprehensive Metrics**: Win rate, profit factor, Sharpe ratio, max drawdown
- **Beautiful Visualizations**: Equity curves, drawdown charts, trade analysis
- **Multi-Timeframe Support**: Resample M1 data to any timeframe (M5, M15, H1, H4, D1)
- **Batch Testing**: Test multiple configurations simultaneously
- **Parameter Optimization**: Easy parameter sweep and optimization

## 📦 Installation

### Requirements

```bash
# Core dependencies (already in requirements.txt)
pip install pandas numpy matplotlib
```

### Files Structure

```
Pyth/
├── ea_backtester.py          # Core backtesting engine
├── ea_launcher.py            # MT5 launcher with backtest integration
├── backtest_example.py       # Usage examples
├── BACKTESTING_GUIDE.md      # This file
└── EURUSD_PERIOD_M1_*.csv   # Historical data
```

## 🚀 Quick Start

### Example 1: Simple Backtest

```python
from ea_launcher import MT5EALauncher

# Create launcher
launcher = MT5EALauncher()

# Create configuration
config = launcher.create_configuration(
    config_name="Conservative_H1",
    symbol="EURUSD",
    timeframe="H1",
    bb_period=20,
    bb_deviation=2.0,
    use_rsi_filter=True,
    rsi_oversold=30.0,
    rsi_overbought=70.0,
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

# Get results
stats = backtester.get_statistics()
print(f"Total Return: {stats['total_return_pct']:.2f}%")
print(f"Win Rate: {stats['win_rate_pct']:.1f}%")
print(f"Profit Factor: {stats['profit_factor']:.2f}")
```

### Example 2: Compare Multiple Configurations

```python
from ea_launcher import MT5EALauncher

launcher = MT5EALauncher()

# Create multiple strategies
launcher.create_configuration(
    config_name="Conservative",
    risk_percent=0.5,
    min_rr=2.5,
    entry_mode="REVERSION"
)

launcher.create_configuration(
    config_name="Aggressive",
    risk_percent=1.5,
    min_rr=1.8,
    entry_mode="BREAKOUT"
)

# Batch backtest all configurations
comparison = launcher.batch_csv_backtest(
    csv_file="EURUSD_PERIOD_M1_20170101_20250102.csv",
    initial_deposit=10000.0
)

# View comparison
print(comparison[['config_name', 'total_return_pct', 'win_rate_pct', 'profit_factor']])
```

### Example 3: Advanced Custom Backtest

```python
from ea_backtester import Backtester

# Custom configuration
config = {
    'name': 'Custom_Strategy',
    'symbol': 'EURUSD',
    'timeframe_str': 'H4',
    'inputs': {
        'BB_Period': 30,
        'BB_Dev': 2.5,
        'Use_RSI_Filter': True,
        'RSI_Period': 21,
        'RSI_Oversold': 25.0,
        'RSI_Overbought': 75.0,
        'Use_EMA_Filter': True,
        'EMA_Fast_Period': 50,
        'EMA_Slow_Period': 200,
        'EMA_Filter_Mode': 0,  # TREND
        'Mode': 0,  # REVERSION
        'Risk_Percent': 1.0,
        'Min_RR': 3.0
    }
}

# Create backtester
backtester = Backtester("EURUSD_PERIOD_M1_20170101_20250102.csv", config, 10000.0)

# Run step by step
backtester.load_data('H4')
backtester.calculate_indicators()
backtester.generate_signals()
backtester.simulate_trades()

# Get detailed results
stats = backtester.get_statistics()
trades_df = backtester.get_trades_dataframe()

# Save outputs
backtester.save_trades_csv("my_trades.csv")
backtester.plot_equity_curve("equity.png")
backtester.plot_trade_analysis("analysis.png")
```

## 📊 Understanding the Results

### Statistics Dictionary

The `get_statistics()` method returns a comprehensive dictionary:

```python
{
    'config_name': 'Strategy name',
    'initial_deposit': 10000.0,
    'final_equity': 12500.0,
    'total_return_pct': 25.0,        # Total return percentage
    'total_profit': 2500.0,          # Total profit in currency
    'total_trades': 45,
    'wins': 30,
    'losses': 15,
    'win_rate_pct': 66.7,            # Win rate percentage
    'profit_factor': 2.5,            # Gross profit / Gross loss
    'avg_profit': 55.56,             # Average profit per trade
    'avg_win': 150.0,                # Average winning trade
    'avg_loss': -80.0,               # Average losing trade
    'best_trade': 450.0,             # Best single trade
    'worst_trade': -200.0,           # Worst single trade
    'max_drawdown_pct': 15.2,        # Maximum drawdown %
    'sharpe_ratio': 1.8,             # Risk-adjusted return
    'avg_planned_rr': 2.0,           # Average planned R:R
    'avg_actual_rr': 1.5,            # Average actual R:R
    'avg_duration_hours': 8.5,       # Average trade duration
    'tp_exits': 28,                  # Trades closed at TP
    'sl_exits': 17                   # Trades closed at SL
}
```

### Trade DataFrame Columns

```python
trades_df = backtester.get_trades_dataframe()

# Columns:
# - entry_time: Trade entry timestamp
# - exit_time: Trade exit timestamp
# - direction: 'BUY' or 'SELL'
# - entry_price: Entry price
# - exit_price: Exit price
# - position_size: Lot size
# - sl: Stop loss level
# - tp: Take profit level
# - profit: Profit/loss in currency
# - exit_reason: 'TP', 'SL', or 'FORCE_CLOSE'
# - planned_rr: Planned risk/reward ratio
# - actual_rr: Actual risk/reward achieved
# - duration_bars: Duration in minutes
```

## 🎯 Strategy Modes

### REVERSION Mode (Mean Reversion)

Enters when price touches Bollinger Band extremes and reverts to mean:

- **BUY Signal**: Price touches lower BB + RSI oversold
- **SELL Signal**: Price touches upper BB + RSI overbought
- **Target**: Price returns to BB middle or opposite band

```python
config = launcher.create_configuration(
    entry_mode="REVERSION",
    bb_deviation=2.0,
    use_rsi_filter=True,
    rsi_oversold=30.0,
    rsi_overbought=70.0
)
```

### BREAKOUT Mode

Enters when price breaks through Bollinger Bands with momentum:

- **BUY Signal**: Price breaks above upper BB with upward momentum
- **SELL Signal**: Price breaks below lower BB with downward momentum
- **Target**: Continuation of breakout move

```python
config = launcher.create_configuration(
    entry_mode="BREAKOUT",
    bb_deviation=1.5,
    use_rsi_filter=False  # Often disabled for breakouts
)
```

## 🔧 Configuration Parameters

### Bollinger Bands

```python
bb_period=20          # Period for moving average (default: 20)
bb_deviation=2.0      # Standard deviations (default: 2.0)
```

### RSI Filter

```python
use_rsi_filter=True   # Enable RSI filtering
rsi_period=14         # RSI calculation period
rsi_oversold=30.0     # Buy signal threshold
rsi_overbought=70.0   # Sell signal threshold
```

### EMA Filter

```python
use_ema_filter=True   # Enable EMA filtering
ema_fast=50           # Fast EMA period
ema_slow=100          # Slow EMA period
ema_mode="TREND"      # TREND, COUNTER, or ZONE
```

**EMA Modes:**
- `TREND`: Only trade with trend (price above/below slow EMA)
- `COUNTER`: Only trade against trend (counter-trend entries)
- `ZONE`: Trade when price is within distance of EMAs

### Risk Management

```python
risk_percent=1.0      # Risk per trade (% of equity)
min_rr=2.0           # Minimum risk/reward ratio
sl_period=50         # Period for swing-based SL
tp_period=30         # Period for TP calculation
atr_multiplier=2.0   # ATR multiplier for SL/TP
```

### Time Filters

```python
use_time_filter=True
hour_ranges="8-10;16-18"  # Trade during these hours

use_day_filter=True
day_ranges="1-5"          # Monday to Friday (1=Mon, 5=Fri)
```

## 📈 Visualization

### Equity Curve

```python
backtester.plot_equity_curve("equity.png")
```

Shows:
- Equity progression over time
- Trade markers (green up = win, red down = loss)
- Initial deposit baseline
- Performance statistics box

### Trade Analysis

```python
backtester.plot_trade_analysis("analysis.png")
```

Shows 4 panels:
1. **Profit Distribution**: Histogram of trade profits
2. **RR Ratio Comparison**: Planned vs actual R:R
3. **Cumulative Profit**: Running profit accumulation
4. **Duration Analysis**: Box plots of trade durations

## 🔄 Multi-Timeframe Testing

Test the same strategy across different timeframes:

```python
timeframes = ['M15', 'M30', 'H1', 'H4', 'D1']

for tf in timeframes:
    backtester = launcher.run_csv_backtest(
        config=config,
        csv_file="EURUSD_PERIOD_M1_20170101_20250102.csv",
        target_timeframe=tf,
        save_results=False
    )
    
    stats = backtester.get_statistics()
    print(f"{tf}: Return={stats['total_return_pct']:.2f}%")
```

## 🎛️ Parameter Optimization

### Grid Search Example

```python
# Define parameter ranges
bb_periods = [15, 20, 25, 30]
bb_deviations = [1.5, 2.0, 2.5]

results = []

for period in bb_periods:
    for deviation in bb_deviations:
        # Create config with these parameters
        config = {...}
        
        # Run backtest
        backtester = Backtester(csv_file, config, 10000.0)
        backtester.run_full_backtest(save_results=False)
        
        stats = backtester.get_statistics()
        stats['bb_period'] = period
        stats['bb_deviation'] = deviation
        results.append(stats)

# Find best combination
results_df = pd.DataFrame(results)
best = results_df.sort_values('total_return_pct', ascending=False).iloc[0]
print(f"Best: BB({best['bb_period']}, {best['bb_deviation']})")
```

## 💡 Best Practices

### 1. Start Simple

Begin with default parameters and understand baseline performance before optimizing.

### 2. Use Appropriate Timeframes

- **M5-M15**: Scalping, requires more data
- **H1**: Day trading, good balance
- **H4-D1**: Swing trading, fewer trades

### 3. Watch for Overfitting

- Test on out-of-sample data
- Use walk-forward validation
- Keep parameter counts reasonable

### 4. Realistic Risk Settings

```python
risk_percent=0.5-2.0    # Conservative to aggressive
min_rr=1.5-3.0          # Ensure positive expectancy
```

### 5. Combine Filters Wisely

Don't over-filter - too many filters = too few trades:

```python
# Good: 2-3 filters
use_rsi_filter=True
use_ema_filter=True

# Risky: Too many filters
use_rsi_filter=True
use_ema_filter=True
use_divergence=True
use_time_filter=True  # May have very few trades
```

## 📝 Performance Metrics Explained

### Win Rate
```
Win Rate = (Winning Trades / Total Trades) × 100
```
Target: 40-60% (with good R:R)

### Profit Factor
```
Profit Factor = Gross Profit / Gross Loss
```
- `< 1.0`: Losing strategy
- `1.0-1.5`: Marginal
- `1.5-2.0`: Good
- `> 2.0`: Excellent

### Sharpe Ratio
```
Sharpe = (Mean Return) / (Std Dev of Returns)
```
- `< 1.0`: Poor risk-adjusted return
- `1.0-2.0`: Good
- `> 2.0`: Excellent

### Max Drawdown
Maximum peak-to-trough decline:
- `< 10%`: Very conservative
- `10-20%`: Moderate
- `20-30%`: Aggressive
- `> 30%`: Very risky

## 🐛 Troubleshooting

### "No trades executed"

**Possible causes:**
1. Filters too strict (relax RSI levels, disable some filters)
2. Wrong timeframe (try different timeframes)
3. Not enough data
4. Min RR too high

**Solution:**
```python
# Relax filters temporarily
use_rsi_filter=False
use_ema_filter=False
min_rr=1.5
```

### "Import error: ea_backtester"

**Solution:**
```bash
# Make sure you're in the correct directory
cd Pyth/
python backtest_example.py
```

### "CSV file not found"

**Solution:**
```python
# Use absolute path
csv_file = r"C:\full\path\to\EURUSD_PERIOD_M1_20170101_20250102.csv"
```

### Poor Performance

**Checklist:**
1. Verify indicator calculations are correct
2. Check if strategy logic matches EA behavior
3. Test on different time periods
4. Review trade log for unexpected behavior
5. Compare with MT5 Strategy Tester results

## 🔬 Advanced Topics

### Custom Indicator Integration

Add your own indicators by extending the `Backtester` class:

```python
class CustomBacktester(Backtester):
    def calculate_indicators(self):
        super().calculate_indicators()
        
        # Add custom indicator
        df = self.data
        df['custom_ma'] = df['close'].rolling(window=50).mean()
        self.data = df
    
    def _generate_reversion_signals(self, df):
        # Use custom indicator in signal generation
        signals = super()._generate_reversion_signals(df)
        
        # Add custom condition
        custom_condition = df['close'] > df['custom_ma']
        signals[~custom_condition] = 0
        
        return signals
```

### Walk-Forward Analysis

```python
# Split data into training and testing periods
train_start = '2017-01-01'
train_end = '2020-12-31'
test_start = '2021-01-01'
test_end = '2024-12-31'

# Optimize on training data
# ... parameter optimization code ...

# Test with best parameters on test data
# ... backtest code ...
```

### Monte Carlo Simulation

```python
import random

trades_df = backtester.get_trades_dataframe()

# Run 1000 simulations with random trade order
simulation_results = []

for i in range(1000):
    shuffled_trades = trades_df.sample(frac=1)
    equity = 10000.0
    
    for _, trade in shuffled_trades.iterrows():
        equity += trade['profit']
    
    simulation_results.append(equity)

# Analyze worst-case scenarios
percentile_5 = np.percentile(simulation_results, 5)
print(f"5th Percentile Equity: ${percentile_5:,.2f}")
```

## 📚 Additional Resources

- **MT5 EA Code**: `MT5/JTFreeCandle_v2.mq5`
- **Strategy Documentation**: `MT5/docs/`
- **Workflow Scripts**: `ea_workflow.py`
- **Optimizer**: `ea_optimizer.py`

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section
2. Review example scripts
3. Compare results with MT5 Strategy Tester
4. Check indicator calculations match EA code

## 📄 License

Part of the JTFreeCandle_v2 trading system.

---

**Happy Backtesting! 🚀📈**

