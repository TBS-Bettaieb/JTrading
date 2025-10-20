# Trading Bot Configurations by Group

*Generated from ConfigLoader.mqh - All trading configurations organized by group*

---

## 📊 Overview

This document contains all trading configurations organized by 5 different trading groups, each optimized for specific market instruments and trading sessions.

**Total Groups:** 5  
**Total Symbols:** 7

---

## 🏢 Group 1: EU_GU_Forex

### Symbols
- **EURUSD** - Euro/US Dollar
- **GBPUSD** - British Pound/US Dollar

### Strategy Configuration
| Parameter | Value |
|-----------|-------|
| **Strategy Name** | EU_GU_FXScalper V1.0 |
| **Strategy Comment** | EU_GU_FXScalper |
| **Base Magic Number** | 2971308 |
| **Timeframe** | PERIOD_M5 |
| **Strategy Mode** | STRATEGY_BREAKOUT |

### Risk Management
| Parameter | Value |
|-----------|-------|
| **Risk Percent** | 1.0% |
| **Take Profit (Points)** | 200 |
| **Stop Loss (Points)** | 180 |
| **TSL Trigger Points** | 10 |
| **TSL Points** | 10 |

### Trading Hours
| Parameter | Value |
|-----------|-------|
| **Start Hour** | 7:00 |
| **End Hour** | 20:00 |

### Strategy Parameters
| Parameter | Value |
|-----------|-------|
| **Bars N** | 5 |
| **Expiration Bars** | 50 |
| **Order Distance Points** | 80 |

### Trailing Take Profit
| Setting | Value |
|---------|-------|
| **Use Trailing TP** | ✅ Enabled |
| **Trailing Mode** | TRAILING_TP_CUSTOM |
| **Custom TP Levels** | `25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150` |

### Risk Multiplier
| Setting | Value |
|---------|-------|
| **Use Risk Multiplier** | ❌ Disabled |
| **Start Time** | 13:00 |
| **End Time** | 17:00 |
| **Multiplier** | 2.0x |
| **Description** | London-NY Overlap |

### News Filter
| Setting | Value |
|---------|-------|
| **Use News Filter** | ❌ Disabled |
| **Currencies** | USD, EUR, GBP |
| **Key Events** | NFP, JOLTS, Nonfarm, PMI, Interest Rate, CPI, GDP |
| **Stop Before News** | 30 minutes |
| **Start After News** | 10 minutes |
| **Lookup Days** | 7 |

---

## 🇩🇪 Group 2: GER40_Index

### Symbols
- **GER40.cash** - German DAX Index

### Strategy Configuration
| Parameter | Value |
|-----------|-------|
| **Strategy Name** | GER40 Scalper V1.0 |
| **Strategy Comment** | GER40_Scalper |
| **Base Magic Number** | 28834731 |
| **Timeframe** | PERIOD_M5 |
| **Strategy Mode** | STRATEGY_BREAKOUT |

### Risk Management
| Parameter | Value |
|-----------|-------|
| **Risk Percent** | 0.5% |
| **Take Profit (Points)** | 5000 |
| **Stop Loss (Points)** | 5000 |
| **TSL Trigger Points** | 200 |
| **TSL Points** | 150 |

### Trading Hours
| Parameter | Value |
|-----------|-------|
| **Start Hour** | 7:00 |
| **End Hour** | 21:00 |

### Strategy Parameters
| Parameter | Value |
|-----------|-------|
| **Bars N** | 6 |
| **Expiration Bars** | 60 |
| **Order Distance Points** | 120 |

### Trailing Take Profit
| Setting | Value |
|---------|-------|
| **Use Trailing TP** | ✅ Enabled |
| **Trailing Mode** | TRAILING_TP_STEPPED |
| **Custom TP Levels** | `25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150` |

### Risk Multiplier
| Setting | Value |
|---------|-------|
| **Use Risk Multiplier** | ✅ Enabled |
| **Start Time** | 8:00 |
| **End Time** | 10:00 |
| **Multiplier** | 2.0x |
| **Description** | Euro Session |

### News Filter
| Setting | Value |
|---------|-------|
| **Use News Filter** | ✅ Enabled |
| **Currencies** | USD, EUR, GBP |
| **Key Events** | NFP, JOLTS, Nonfarm, PMI, Interest Rate, CPI, GDP |
| **Stop Before News** | 30 minutes |
| **Start After News** | 10 minutes |
| **Lookup Days** | 7 |

---

## 💴 Group 3: USDJPY_Forex

### Symbols
- **USDJPY** - US Dollar/Japanese Yen

### Strategy Configuration
| Parameter | Value |
|-----------|-------|
| **Strategy Name** | USDJPY_FXScalper V1.0 |
| **Strategy Comment** | USDJPY_FXScalper |
| **Base Magic Number** | 37483647 |
| **Timeframe** | PERIOD_M5 |
| **Strategy Mode** | STRATEGY_BREAKOUT |

### Risk Management
| Parameter | Value |
|-----------|-------|
| **Risk Percent** | 0.5% |
| **Take Profit (Points)** | 200 |
| **Stop Loss (Points)** | 180 |
| **TSL Trigger Points** | 10 |
| **TSL Points** | 10 |

### Trading Hours
| Parameter | Value |
|-----------|-------|
| **Start Hour** | 13:00 |
| **End Hour** | 18:00 |

### Strategy Parameters
| Parameter | Value |
|-----------|-------|
| **Bars N** | 5 |
| **Expiration Bars** | 50 |
| **Order Distance Points** | 80 |

### Trailing Take Profit
| Setting | Value |
|---------|-------|
| **Use Trailing TP** | ✅ Enabled |
| **Trailing Mode** | TRAILING_TP_CUSTOM |
| **Custom TP Levels** | `25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150` |

### Risk Multiplier
| Setting | Value |
|---------|-------|
| **Use Risk Multiplier** | ✅ Enabled |
| **Start Time** | 14:00 |
| **End Time** | 15:30 |
| **Multiplier** | 2.0x |
| **Description** | London-NY Overlap |

### News Filter
| Setting | Value |
|---------|-------|
| **Use News Filter** | ❌ Disabled |
| **Currencies** | USD, EUR, GBP |
| **Key Events** | NFP, JOLTS, Nonfarm, PMI, Interest Rate, CPI, GDP |
| **Stop Before News** | 30 minutes |
| **Start After News** | 10 minutes |
| **Lookup Days** | 7 |

---

## 🇺🇸 Group 4: US_Indices

### Symbols
- **US100.cash** - NASDAQ 100 Index
- **US30.cash** - Dow Jones Industrial Average
- **US500.cash** - S&P 500 Index

### Strategy Configuration
| Parameter | Value |
|-----------|-------|
| **Strategy Name** | US Indices Scalper V1.0 |
| **Strategy Comment** | USIndices_Scalper |
| **Base Magic Number** | 29834757 |
| **Timeframe** | PERIOD_M5 |
| **Strategy Mode** | STRATEGY_BREAKOUT |

### Risk Management
| Parameter | Value |
|-----------|-------|
| **Risk Percent** | 1.5% |
| **Take Profit (Points)** | 5000 |
| **Stop Loss (Points)** | 5000 |
| **TSL Trigger Points** | 200 |
| **TSL Points** | 150 |

### Trading Hours
| Parameter | Value |
|-----------|-------|
| **Start Hour** | 0:00 (24/7) |
| **End Hour** | 0:00 (24/7) |

### Strategy Parameters
| Parameter | Value |
|-----------|-------|
| **Bars N** | 6 |
| **Expiration Bars** | 60 |
| **Order Distance Points** | 120 |

### Trailing Take Profit
| Setting | Value |
|---------|-------|
| **Use Trailing TP** | ✅ Enabled |
| **Trailing Mode** | TRAILING_TP_STEPPED |
| **Custom TP Levels** | `25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150` |

### Risk Multiplier
| Setting | Value |
|---------|-------|
| **Use Risk Multiplier** | ✅ Enabled |
| **Start Time** | 14:00 |
| **End Time** | 18:00 |
| **Multiplier** | 2.0x |
| **Description** | London-NY Overlap |

### News Filter
| Setting | Value |
|---------|-------|
| **Use News Filter** | ✅ Enabled |
| **Currencies** | USD, EUR, GBP |
| **Key Events** | NFP, JOLTS, Nonfarm, PMI, Interest Rate, CPI, GDP |
| **Stop Before News** | 30 minutes |
| **Start After News** | 10 minutes |
| **Lookup Days** | 7 |

---

## 🥇 Group 5: XAUUSD_Gold

### Symbols
- **XAUUSD** - Gold vs. US Dollar

### Strategy Configuration
| Parameter | Value |
|-----------|-------|
| **Strategy Name** | XAUUSD Gold Scalper V1.0 |
| **Strategy Comment** | XAUUSD_Gold_Scalper |
| **Base Magic Number** | 29479999 |
| **Timeframe** | PERIOD_M5 |
| **Strategy Mode** | STRATEGY_BREAKOUT |

### Risk Management
| Parameter | Value |
|-----------|-------|
| **Risk Percent** | 0.5% |
| **Take Profit (Points)** | 1500 |
| **Stop Loss (Points)** | 1500 |
| **TSL Trigger Points** | 20 |
| **TSL Points** | 15 |

### Trading Hours
| Parameter | Value |
|-----------|-------|
| **Start Hour** | 10:00 |
| **End Hour** | 17:00 |

### Strategy Parameters
| Parameter | Value |
|-----------|-------|
| **Bars N** | 6 |
| **Expiration Bars** | 60 |
| **Order Distance Points** | 120 |

### Trailing Take Profit
| Setting | Value |
|---------|-------|
| **Use Trailing TP** | ✅ Enabled |
| **Trailing Mode** | TRAILING_TP_STEPPED |
| **Custom TP Levels** | `25:0:0, 50:25:25, 75:40:50, 100:60:100, 125:75:150` |

### Risk Multiplier
| Setting | Value |
|---------|-------|
| **Use Risk Multiplier** | ✅ Enabled |
| **Start Time** | 13:00 |
| **End Time** | 18:00 |
| **Multiplier** | 2.0x |
| **Description** | London-NY Overlap |

### News Filter
| Setting | Value |
|---------|-------|
| **Use News Filter** | ✅ Enabled |
| **Currencies** | USD, EUR, GBP |
| **Key Events** | NFP, JOLTS, Nonfarm, PMI, Interest Rate, CPI, GDP |
| **Stop Before News** | 30 minutes |
| **Start After News** | 10 minutes |
| **Lookup Days** | 7 |

---

## 🔧 System Messages

### Block Messages (All Groups)
| Message Type | Message |
|--------------|---------|
| **News Block** | 📰 TRADING PAUSED - High Impact News Event |
| **Hour Block** | ⏰ TRADING PAUSED - Outside Trading Hours |
| **Day Block** | 📅 TRADING PAUSED - Outside Trading Days |
| **Both Block** | 🚫 TRADING PAUSED - Outside Trading Schedule |

---

## 📈 Summary by Asset Type

### Forex Pairs (3 groups)
1. **EU_GU_Forex** - EUR/USD, GBP/USD
2. **USDJPY_Forex** - USD/JPY

### Indices (2 groups)
3. **GER40_Index** - German DAX
4. **US_Indices** - NASDAQ 100, Dow Jones, S&P 500

### Commodities (1 group)
5. **XAUUSD_Gold** - Gold

### Common Settings Across All Groups
- **Timeframe:** M5 (5 minutes)
- **Strategy Mode:** Breakout
- **Trailing TP:** Enabled for all groups
- **News Filter:** Enabled for indices and gold, disabled for major forex pairs

---

*Document generated from ConfigLoader.mqh - Last updated: 2025*
