# Trendline Breakouts EA - Modular Architecture

## 🎯 Overview

The Trendline Breakouts EA has been successfully refactored from a monolithic 564-line file into a clean, modular, and extensible architecture. This refactoring follows the same design patterns as the ADX Score Master, making it easy to maintain, test, and extend.

## 📁 Directory Structure

```
MT5/DayTrading/TrendlineBreakouts/
├── Trendline Breakouts EA.mq5          # Main EA (simplified to 85 lines)
├── common/
│   ├── TrendlineTrader.mqh             # Main orchestrator class
│   ├── detectors/
│   │   ├── ISignalDetector.mqh         # Base interface for detectors
│   │   ├── PivotDetector.mqh           # Pivot High/Low detection
│   │   ├── TrendlineDetector.mqh       # Trendline calculation & tracking
│   │   └── BreakoutDetector.mqh        # Crossover/crossunder signals
│   ├── filters/
│   │   ├── IFilter.mqh                 # Base interface for filters
│   │   └── VolatilityFilter.mqh        # ATR/Zband calculation
│   └── managers/
│       └── TrendlineManager.mqh        # Chart drawing & object management
└── Sets/
    └── TrendlineBreakouts_Default.set  # Configuration file
```

## 🏗️ Architecture Components

### 1. Interfaces

#### `ISignalDetector.mqh`
Base interface for all signal detection components:
- `Initialize()` - Setup indicators/handles
- `Update()` - Refresh values on new bar
- `HasBuySignal()` - Returns true if BUY conditions met
- `HasSellSignal()` - Returns true if SELL conditions met
- `Release()` - Cleanup resources

#### `IFilter.mqh`
Base interface for all filter components:
- `Initialize()` - Setup filter
- `Update()` - Refresh filter values
- `IsFilterPassed()` - Returns true if filter conditions met
- `Release()` - Cleanup resources

### 2. Detectors

#### `PivotDetector.mqh`
**Purpose**: Detect Pivot Highs and Pivot Lows
- Extracted from original `PivotHigh()` and `PivotLow()` functions
- Tracks pivot values and bar positions
- Provides methods to detect new pivots
- **Key Methods**:
  - `GetPivotHigh()` / `GetPivotLow()`
  - `IsNewPivotHigh()` / `IsNewPivotLow()`
  - `GetPivotHighBar()` / `GetPivotLowBar()`

#### `TrendlineDetector.mqh`
**Purpose**: Calculate and track trendline parameters
- Extracted from original `CalculateTrendline()` function
- Manages upper (resistance) and lower (support) trendlines
- Validates slope direction for proper trendline behavior
- **Key Methods**:
  - `UpdateUpperTrendline()` / `UpdateLowerTrendline()`
  - `GetUpperLinePrice()` / `GetLowerLinePrice()`
  - `IsUpperSlopeValid()` / `IsLowerSlopeValid()`

#### `BreakoutDetector.mqh`
**Purpose**: Detect price crossovers/crossunders of trendlines
- Extracted from original `CheckLongSignal()` and `CheckShortSignal()` functions
- Uses dependency injection to access TrendlineDetector
- Applies Zband buffer for SELL signals
- **Key Methods**:
  - `HasBuySignal()` - Price crosses above resistance
  - `HasSellSignal()` - Price crosses below support
  - `SetZband()` - Update volatility buffer

### 3. Filters

#### `VolatilityFilter.mqh`
**Purpose**: Calculate Zband (volatility adjustment) using ATR
- Extracted from original `CalculateZband()` function
- Uses ATR indicator with 30-period
- Implements the formula: `Zband = min(ATR * 0.3, close * 0.003) / 2.0`
- **Key Methods**:
  - `GetZband()` - Current Zband value
  - `GetATR()` - Current ATR value

### 4. Managers

#### `TrendlineManager.mqh`
**Purpose**: Draw and manage trendline objects on chart
- Extracted from original drawing functions
- Manages all chart objects (trendlines, SL/TP lines, arrows, targets)
- Handles object cleanup and updates
- **Key Methods**:
  - `DrawUpperTrendline()` / `DrawLowerTrendline()`
  - `DrawSLTPLines()` / `UpdateSLTPLines()` / `ClearSLTPLines()`
  - `DrawSignalArrow()` / `DrawTargetLine()`
  - `ClearAllObjects()`

### 5. Main Orchestrator

#### `TrendlineTrader.mqh`
**Purpose**: Coordinate all components and execute trades
- Main orchestrator class that manages the entire trading workflow
- Implements dependency injection pattern
- Handles trade execution and management
- **Key Methods**:
  - `Initialize()` - Setup all components
  - `OnTick()` - Main tick handler
  - `OnNewBar()` - New bar processing
  - `CheckSignals()` - Signal detection
  - `ExecuteBuySignal()` / `ExecuteSellSignal()`
  - `ManageTrade()` - Trade management

## 🔄 Workflow

```
OnTick()
├── Check if new bar → OnNewBar()
│   ├── Update PivotDetector
│   ├── Update TrendlineDetector (if new pivots)
│   ├── Draw new trendlines
│   └── Update VolatilityFilter
│
├── Update BreakoutDetector (every tick)
│
├── If no trade open:
│   ├── Check BuySignal
│   └── Check SellSignal
│
└── If trade open:
    └── Manage SL/TP
```

## ✅ Key Improvements

### 1. **Separation of Concerns**
- **Detection**: PivotDetector, TrendlineDetector, BreakoutDetector
- **Filtering**: VolatilityFilter
- **Visualization**: TrendlineManager
- **Execution**: TrendlineTrader

### 2. **Dependency Injection**
- Components receive dependencies via constructor
- Loose coupling between components
- Easy to test and mock dependencies

### 3. **Interface-Based Design**
- All detectors implement `ISignalDetector`
- All filters implement `IFilter`
- Easy to add new components

### 4. **Memory Management**
- Proper cleanup in destructors
- No memory leaks
- Resource management handled automatically

### 5. **Testability**
- Each component can be unit tested independently
- Clear input/output contracts
- Mockable dependencies

## 📊 Code Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Main EA Lines | 564 | 85 | -85% |
| Files | 1 | 8 | +700% modularity |
| Components | 0 | 6 | Full separation |
| Interfaces | 0 | 2 | Type safety |
| Testability | Low | High | Easy unit testing |

## 🚀 Future Extensions

The modular architecture makes it easy to add:

1. **New Filters**:
   - `TimeFilter` - Trading hours filter
   - `SpreadFilter` - Spread validation
   - `NewsFilter` - News event filter

2. **New Detectors**:
   - `PriceActionDetector` - Candlestick patterns
   - `VolumeConfirmation` - Volume analysis
   - `MultiTimeframeDetector` - Higher TF confirmation

3. **Advanced Features**:
   - Trailing TP system
   - Dynamic lot sizing
   - Risk management
   - Multiple symbol trading

## 🔧 Usage

### Compilation
1. Compile the main EA file: `Trendline Breakouts EA.mq5`
2. All dependencies will be automatically included
3. No additional compilation steps required

### Configuration
- Use the provided `.set` file for default settings
- Modify input parameters as needed
- All original functionality preserved

### Testing
- Each component can be tested independently
- Use the Strategy Tester for backtesting
- Monitor logs for component initialization and signal detection

## 📝 Migration Notes

- **Same Trading Logic**: All original trading logic preserved
- **Same Parameters**: All input parameters maintained
- **Same Behavior**: Identical trading behavior as original EA
- **Enhanced Logging**: Better logging and debugging information
- **Improved Maintainability**: Much easier to modify and extend

## 🎯 Success Criteria Met

- ✅ All code compiles without errors
- ✅ Main EA file < 100 lines (85 lines)
- ✅ Each component file < 300 lines
- ✅ Clear separation of concerns
- ✅ Same trading behavior as original EA
- ✅ Easy to add new filters/indicators
- ✅ No code duplication
- ✅ Proper memory management
- ✅ Consistent naming conventions
- ✅ All objects properly released on deinit

The refactoring is complete and ready for use! 🎉
