# Component Interaction Flow

## 🏗️ Initialization Sequence

```
Main EA (OnInit)
    │
    └─► TrendlineTrader Constructor
            │
            ├─► Input Validation & Sanitization
            │   ├─► Symbol validation
            │   ├─► Magic number validation
            │   ├─► Period validation (2-100)
            │   ├─► Extension validation (10-100)
            │   ├─► Lot size validation (0-100)
            │   └─► Slippage validation (0-100)
            │
            ├─► Component Creation
            │   ├─► PivotDetector (symbol, timeframe, period, useWicks)
            │   ├─► TrendlineDetector (symbol, timeframe)
            │   ├─► BreakoutDetector (symbol, timeframe, trendlineDetector)
            │   ├─► VolatilityFilter (symbol, timeframe, 30)
            │   └─► TrendlineManager (symbol, extension, lineColor)
            │
            └─► CTrade Configuration
                ├─► SetExpertMagicNumber()
                ├─► SetDeviationInPoints()
                ├─► SetTypeFilling(ORDER_FILLING_IOC)
                └─► SetAsyncMode(false)
```

## 🔄 OnTick() Flow

```
OnTick()
  │
  ├─► ValidateComponentState() ────► [FAIL] ───► Log Warning & Return
  │                                   [PASS]
  │                                      │
  ├─► IsNewBar()? ────► [YES] ───────► OnNewBar()
  │                                      │
  │                                      ├─► PivotDetector.Update()
  │                                      │     │
  │                                      │     ├─► CalculatePivotHigh()
  │                                      │     │     └─► IsNewPivotHigh()?
  │                                      │     │           │
  │                                      │     │           └─► TrendlineDetector.UpdateUpperTrendline()
  │                                      │     │                 │
  │                                      │     │                 ├─► Calculate slope to current bar
  │                                      │     │                 ├─► Validate slope (≤ 0 for resistance)
  │                                      │     │                 └─► TrendlineManager.DrawUpperTrendline()
  │                                      │     │
  │                                      │     └─► CalculatePivotLow()
  │                                      │           └─► IsNewPivotLow()?
  │                                      │                 │
  │                                      │                 └─► TrendlineDetector.UpdateLowerTrendline()
  │                                      │                       │
  │                                      │                       ├─► Calculate slope to current bar
  │                                      │                       ├─► Validate slope (≥ 0 for support)
  │                                      │                       └─► TrendlineManager.DrawLowerTrendline()
  │                                      │
  │                                      └─► [Continue to signal detection]
  │
  ├─► VolatilityFilter.Update() ──────► Calculate Zband
  │                                      │
  │                                      ├─► Copy ATR buffer (bar 20)
  │                                      ├─► Calculate: min(ATR * 0.3, close * 0.003)
  │                                      └─► Divide by 2.0 → Zband
  │
  ├─► BreakoutDetector.SetZband() ────► Update volatility buffer
  │
  └─► CheckSignals() ──────► BreakoutDetector.HasBuySignal()?
                              │
                              ├─► [YES] ──► ExecuteBuySignal()
                              │             │
                              │             ├─► Calculate TP/SL from Zband
                              │             ├─► SendOrder(true)
                              │             │   ├─► Validate order parameters
                              │             │   ├─► Check minimum stop levels
                              │             │   ├─► Adjust SL/TP if too close
                              │             │   ├─► Execute Buy order
                              │             │   └─► Detailed error reporting if failed
                              │             ├─► TrendlineManager.DrawSLTPLines()
                              │             ├─► TrendlineManager.DrawSignalArrow()
                              │             └─► TrendlineManager.DrawTargetLine() (if enabled)
                              │
                              └─► BreakoutDetector.HasSellSignal()?
                                  │
                                  └─► [YES] ──► ExecuteSellSignal()
                                              │
                                              ├─► Calculate TP/SL from Zband
                                              ├─► SendOrder(false)
                                              ├─► TrendlineManager.DrawSLTPLines()
                                              ├─► TrendlineManager.DrawSignalArrow()
                                              └─► TrendlineManager.DrawTargetLine() (if enabled)
```

## 📊 Data Dependencies

### Component Dependencies
```
TrendlineTrader
├── PivotDetector (independent)
├── TrendlineDetector (independent)
├── BreakoutDetector (depends on TrendlineDetector)
├── VolatilityFilter (independent)
└── TrendlineManager (independent)
```

### Data Flow
```
Market Data
    │
    ├─► PivotDetector ──► Pivot High/Low values
    │                        │
    │                        └─► TrendlineDetector ──► Trendline slopes & prices
    │                                                      │
    │                                                      └─► BreakoutDetector ──► Trading signals
    │                                                                                │
    │                                                                                └─► Trade execution
    │
    ├─► VolatilityFilter ──► Zband values
    │                           │
    │                           └─► BreakoutDetector (for SELL signal buffer)
    │
    └─► TrendlineManager ──► Chart objects (trendlines, SL/TP, arrows)
```

## 🔍 Signal Detection Logic

### Buy Signal (Breakout Above Resistance)
```
1. TrendlineDetector.IsUpperSlopeValid() → true (slope ≤ 0)
2. Get current and previous prices
3. Calculate trendline prices at current and previous bars
4. Check crossover: (prevPrice < prevLine) && (currentPrice > currentLine)
5. Return true if crossover detected
```

### Sell Signal (Breakout Below Support)
```
1. TrendlineDetector.IsLowerSlopeValid() → true (slope ≥ 0)
2. Get current and previous prices
3. Calculate trendline prices at current and previous bars
4. Apply Zband buffer: zbandAdjustment = zband * 0.1
5. Check crossunder: (prevPrice > prevLine - buffer) && (currentPrice < currentLine - buffer)
6. Return true if crossunder detected
```

## 🎯 Trade Management Flow

```
Trade Open
    │
    ├─► ManageTrade() (called every tick)
    │   │
    │   ├─► Update SL/TP line positions
    │   │
    │   ├─► Check TP/SL hit conditions
    │   │   │
    │   │   ├─► Long Trade:
    │   │   │   ├─► high >= TP → Close at TP
    │   │   │   └─► close <= SL → Close at SL
    │   │   │
    │   │   └─► Short Trade:
    │   │       ├─► low <= TP → Close at TP
    │   │       └─► close >= SL → Close at SL
    │   │
    │   └─► Clear SL/TP lines when trade closes
    │
    └─► Continue monitoring until trade closes
```

## 🛡️ Error Handling & Validation

### Component State Validation
```
ValidateComponentState()
├── Check PivotDetector: NULL or !IsInitialized()
├── Check TrendlineDetector: NULL or !IsInitialized()
├── Check BreakoutDetector: NULL or !IsInitialized()
├── Check VolatilityFilter: NULL or !IsInitialized()
└── Check TrendlineManager: NULL
```

### Order Execution Validation
```
SendOrder()
├── Validate price > 0
├── Validate TP/SL > 0
├── Check minimum stop levels
├── Adjust SL/TP if too close
├── Execute order
└── Detailed error reporting with specific tips
```

### Initialization Error Handling
```
Initialize()
├── Track each component initialization
├── If any fails:
│   ├── Log specific error
│   ├── Cleanup previously initialized components
│   └── Return false
└── If all succeed: Return true
```

## 🔧 Component Lifecycle

### Creation
1. Constructor called with validated parameters
2. Components created with `new` operator
3. CTrade object configured

### Initialization
1. Each component's `Initialize()` method called
2. Resources allocated (indicators, handles)
3. State validated and set

### Operation
1. `OnTick()` called every market tick
2. Components updated as needed
3. Signals detected and trades executed

### Cleanup
1. `OnDeinit()` called on EA shutdown
2. `~TrendlineTrader()` destructor called
3. All components deleted with `delete` operator
4. Resources released automatically

## 📈 Performance Considerations

### Optimization Points
- **New Bar Detection**: Only update components on new bars
- **Component Validation**: Cached validation with rate-limited warnings
- **Memory Management**: Automatic cleanup in destructors
- **Error Logging**: Detailed but not excessive logging

### Resource Usage
- **Indicators**: ATR handle created once, reused
- **Objects**: Chart objects managed by TrendlineManager
- **Memory**: Components allocated once, cleaned up properly
- **CPU**: Minimal overhead with efficient validation

## 🧪 Testing Scenarios

### Unit Testing
- Test each component independently
- Mock dependencies for isolated testing
- Validate input/output contracts

### Integration Testing
- Test component interactions
- Verify data flow between components
- Test error propagation

### Stress Testing
- Run for extended periods
- Test with various market conditions
- Verify memory stability

### Edge Case Testing
- Invalid input parameters
- Component initialization failures
- Order execution failures
- Market closed scenarios
