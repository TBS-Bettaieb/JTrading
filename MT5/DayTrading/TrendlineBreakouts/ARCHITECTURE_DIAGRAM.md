# Trendline Breakouts EA - Architecture Diagram

## 🏗️ Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Trendline Breakouts EA.mq5                   │
│                         (Main EA - 85 lines)                   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TrendlineTrader.mqh                          │
│                   (Main Orchestrator)                           │
└─────────────────────────┬───────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  Detectors  │   │   Filters   │   │  Managers   │
└─────────────┘   └─────────────┘   └─────────────┘
        │                 │                 │
        ▼                 ▼                 ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│PivotDetector│   │Volatility   │   │Trendline    │
│             │   │Filter       │   │Manager      │
│Trendline    │   │             │   │             │
│Detector     │   │             │   │             │
│             │   │             │   │             │
│Breakout     │   │             │   │             │
│Detector     │   │             │   │             │
└─────────────┘   └─────────────┘   └─────────────┘
```

## 🔄 Data Flow

```
Market Data
     │
     ▼
┌─────────────┐
│PivotDetector│ ──► New Pivots
└─────────────┘
     │
     ▼
┌─────────────┐
│Trendline    │ ──► Trendline Data
│Detector     │
└─────────────┘
     │
     ▼
┌─────────────┐
│Breakout     │ ──► Trading Signals
│Detector     │
└─────────────┘
     │
     ▼
┌─────────────┐
│Trendline    │ ──► Trade Execution
│Trader       │
└─────────────┘
     │
     ▼
┌─────────────┐
│Trendline    │ ──► Chart Objects
│Manager      │
└─────────────┘
```

## 🎯 Component Responsibilities

### Detectors
- **PivotDetector**: Identifies pivot highs and lows
- **TrendlineDetector**: Calculates trendline slopes and prices
- **BreakoutDetector**: Detects price breakouts of trendlines

### Filters
- **VolatilityFilter**: Calculates ATR-based Zband values

### Managers
- **TrendlineManager**: Handles all chart drawing and object management

### Main Orchestrator
- **TrendlineTrader**: Coordinates all components and executes trades

## 🔗 Dependencies

```
TrendlineTrader
├── PivotDetector (independent)
├── TrendlineDetector (independent)
├── BreakoutDetector (depends on TrendlineDetector)
├── VolatilityFilter (independent)
└── TrendlineManager (independent)
```

## 📊 Interface Hierarchy

```
ISignalDetector (Interface)
├── PivotDetector
├── TrendlineDetector
└── BreakoutDetector

IFilter (Interface)
└── VolatilityFilter
```

## 🚀 Benefits of This Architecture

1. **Modularity**: Each component has a single responsibility
2. **Testability**: Components can be tested independently
3. **Extensibility**: Easy to add new detectors, filters, or managers
4. **Maintainability**: Clear separation of concerns
5. **Reusability**: Components can be reused in other EAs
6. **Type Safety**: Interface-based design ensures consistency
