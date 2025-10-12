"""
MT5 EA CSV Backtester
Fast vectorized backtesting system for JTFreeCandle_v2 EA
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import warnings
warnings.filterwarnings('ignore')


class Backtester:
    """
    Vectorized backtesting engine for MT5 EA strategies
    """
    
    def __init__(self, csv_file: str, config: Dict, initial_deposit: float = 10000.0):
        """
        Initialize backtester
        
        Args:
            csv_file: Path to CSV file with OHLC data
            config: Configuration dictionary from MT5EALauncher
            initial_deposit: Starting capital
        """
        self.csv_file = csv_file
        self.config = config
        self.initial_deposit = initial_deposit
        self.current_equity = initial_deposit
        
        # Load and prepare data
        self.data = None
        self.trades = []
        self.equity_curve = []
        self.drawdown_curve = []
        
        # Extract parameters from config
        self.params = self._extract_parameters(config)
        
        print(f"Backtester initialized: {config.get('name', 'Unnamed')}")
        print(f"Initial deposit: ${initial_deposit:,.2f}")
    
    def _extract_parameters(self, config: Dict) -> Dict:
        """Extract and normalize parameters from config"""
        inputs = config.get('inputs', {})
        
        # Handle both direct parameters and inputs structure
        params = {
            # Bollinger Bands
            'bb_period': inputs.get('BB_Period', 20),
            'bb_deviation': inputs.get('BB_Dev', 2.0),
            
            # RSI
            'use_rsi_filter': inputs.get('Use_RSI_Filter', True),
            'rsi_period': inputs.get('RSI_Period', 14),
            'rsi_oversold': inputs.get('RSI_Oversold', 30.0),
            'rsi_overbought': inputs.get('RSI_Overbought', 70.0),
            
            # EMA
            'use_ema_filter': inputs.get('Use_EMA_Filter', True),
            'ema_fast': inputs.get('EMA_Fast_Period', 50),
            'ema_slow': inputs.get('EMA_Slow_Period', 100),
            'ema_mode': inputs.get('EMA_Filter_Mode', 0),  # 0=TREND, 1=COUNTER, 2=ZONE
            'ema_zone_distance': inputs.get('EMA_Zone_Distance', 20.0),
            
            # Divergence
            'use_divergence': inputs.get('Use_Divergence_Validator', False),
            'div_rsi_buy': inputs.get('Div_RSI_Buy_Level', 35.0),
            'div_rsi_sell': inputs.get('Div_RSI_Sell_Level', 65.0),
            'div_swing_length': inputs.get('Div_Swing_Length', 5),
            
            # Trading
            'entry_mode': inputs.get('Mode', 0),  # 0=REVERSION, 1=BREAKOUT
            'trade_direction': inputs.get('TradeDir', 0),  # 0=BOTH, 1=ONLY_BUY, 2=ONLY_SELL
            'risk_percent': inputs.get('Risk_Percent', 0.5),
            'min_rr': inputs.get('Min_RR', 2.0),
            
            # SL/TP
            'sl_period': inputs.get('SL_Period', 50),
            'tp_period': inputs.get('TP_Period', 30),
            'atr_multiplier': inputs.get('ATR_Multiplier', 2.0),
            
            # Time filters
            'use_time_filter': inputs.get('UseTimeFilter', False),
            'hour_ranges': inputs.get('HourRanges', '8-10;16'),
            'use_day_filter': inputs.get('UseDayFilter', False),
            'day_ranges': inputs.get('DayRanges', '1-5'),
        }
        
        return params
    
    def load_data(self, target_timeframe: Optional[str] = None) -> pd.DataFrame:
        """
        Load and prepare OHLC data from CSV
        
        Args:
            target_timeframe: Target timeframe ('M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1')
                              If None, uses config timeframe
        
        Returns:
            Prepared DataFrame with OHLC data
        """
        print(f"\n📊 Loading data from: {self.csv_file}")
        
        # Read CSV
        df = pd.read_csv(self.csv_file, sep=';')
        
        # Parse timestamp
        df['time'] = pd.to_datetime(df['time_iso'])
        df = df.set_index('time')
        
        # Sort by time
        df = df.sort_index()
        
        print(f"   Loaded {len(df)} bars from {df.index[0]} to {df.index[-1]}")
        
        # Resample if needed
        if target_timeframe is None:
            target_timeframe = self.config.get('timeframe_str', 'H1')
        
        source_timeframe = self._detect_timeframe(df)
        print(f"   Source timeframe: {source_timeframe}")
        
        if target_timeframe != source_timeframe:
            df = self._resample_data(df, target_timeframe)
            print(f"   Resampled to {target_timeframe}: {len(df)} bars")
        
        self.data = df
        return df
    
    def _detect_timeframe(self, df: pd.DataFrame) -> str:
        """Detect timeframe from data"""
        if len(df) < 2:
            return 'M1'
        
        # Calculate median time difference in minutes
        time_diffs = df.index.to_series().diff().dt.total_seconds() / 60
        median_diff = time_diffs.median()
        
        if median_diff <= 1.5:
            return 'M1'
        elif median_diff <= 7:
            return 'M5'
        elif median_diff <= 20:
            return 'M15'
        elif median_diff <= 40:
            return 'M30'
        elif median_diff <= 90:
            return 'H1'
        elif median_diff <= 300:
            return 'H4'
        else:
            return 'D1'
    
    def _resample_data(self, df: pd.DataFrame, timeframe: str) -> pd.DataFrame:
        """Resample data to target timeframe"""
        # Map timeframe to pandas offset
        tf_map = {
            'M1': '1Min',
            'M5': '5Min',
            'M15': '15Min',
            'M30': '30Min',
            'H1': '1H',
            'H4': '4H',
            'D1': '1D'
        }
        
        offset = tf_map.get(timeframe, '1H')
        
        # Resample OHLC data
        resampled = df.resample(offset).agg({
            'open': 'first',
            'high': 'max',
            'low': 'min',
            'close': 'last',
            'tick_volume': 'sum',
            'real_volume': 'sum',
            'spread': 'mean'
        }).dropna()
        
        return resampled
    
    def calculate_indicators(self):
        """Calculate all technical indicators"""
        if self.data is None:
            raise ValueError("Data not loaded. Call load_data() first.")
        
        print("\n📈 Calculating indicators...")
        
        df = self.data
        
        # Bollinger Bands
        bb_period = self.params['bb_period']
        bb_dev = self.params['bb_deviation']
        
        df['bb_middle'] = df['close'].rolling(window=bb_period).mean()
        bb_std = df['close'].rolling(window=bb_period).std()
        df['bb_upper'] = df['bb_middle'] + (bb_std * bb_dev)
        df['bb_lower'] = df['bb_middle'] - (bb_std * bb_dev)
        df['bb_width'] = (df['bb_upper'] - df['bb_lower']) / df['bb_middle'] * 100
        
        # RSI
        rsi_period = self.params['rsi_period']
        df['rsi'] = self._calculate_rsi(df['close'], rsi_period)
        
        # EMA
        ema_fast = self.params['ema_fast']
        ema_slow = self.params['ema_slow']
        df['ema_fast'] = df['close'].ewm(span=ema_fast, adjust=False).mean()
        df['ema_slow'] = df['close'].ewm(span=ema_slow, adjust=False).mean()
        
        # ATR for SL/TP calculation
        atr_period = max(self.params['sl_period'], self.params['tp_period'])
        df['atr'] = self._calculate_atr(df, atr_period)
        
        # Swing highs/lows for SL/TP
        swing_period = self.params['div_swing_length']
        df['swing_high'] = df['high'].rolling(window=swing_period, center=True).max()
        df['swing_low'] = df['low'].rolling(window=swing_period, center=True).min()
        
        print(f"   ✓ Bollinger Bands (period={bb_period}, dev={bb_dev})")
        print(f"   ✓ RSI (period={rsi_period})")
        print(f"   ✓ EMA (fast={ema_fast}, slow={ema_slow})")
        print(f"   ✓ ATR (period={atr_period})")
        
        self.data = df
    
    def _calculate_rsi(self, prices: pd.Series, period: int) -> pd.Series:
        """Calculate RSI indicator"""
        delta = prices.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        
        return rsi
    
    def _calculate_atr(self, df: pd.DataFrame, period: int) -> pd.Series:
        """Calculate Average True Range"""
        high_low = df['high'] - df['low']
        high_close = np.abs(df['high'] - df['close'].shift())
        low_close = np.abs(df['low'] - df['close'].shift())
        
        ranges = pd.concat([high_low, high_close, low_close], axis=1)
        true_range = ranges.max(axis=1)
        
        atr = true_range.rolling(window=period).mean()
        
        return atr
    
    def generate_signals(self):
        """Generate trading signals based on EA logic"""
        if self.data is None or 'rsi' not in self.data.columns:
            raise ValueError("Indicators not calculated. Call calculate_indicators() first.")
        
        print("\n🎯 Generating trading signals...")
        
        df = self.data
        df['signal'] = 0  # 0=no signal, 1=buy, -1=sell
        
        entry_mode = self.params['entry_mode']
        
        if entry_mode == 0:  # REVERSION
            df['signal'] = self._generate_reversion_signals(df)
        else:  # BREAKOUT
            df['signal'] = self._generate_breakout_signals(df)
        
        # Apply filters
        df['signal'] = self._apply_filters(df, df['signal'])
        
        # Count signals
        buy_signals = (df['signal'] == 1).sum()
        sell_signals = (df['signal'] == -1).sum()
        
        print(f"   Generated {buy_signals} BUY and {sell_signals} SELL signals")
        
        self.data = df
    
    def _generate_reversion_signals(self, df: pd.DataFrame) -> pd.Series:
        """Generate mean reversion signals"""
        signals = pd.Series(0, index=df.index)
        
        # BUY: Price touches lower BB + RSI oversold
        buy_condition = (
            (df['close'] <= df['bb_lower']) &
            (df['rsi'] <= self.params['rsi_oversold'])
        )
        
        # SELL: Price touches upper BB + RSI overbought
        sell_condition = (
            (df['close'] >= df['bb_upper']) &
            (df['rsi'] >= self.params['rsi_overbought'])
        )
        
        signals[buy_condition] = 1
        signals[sell_condition] = -1
        
        return signals
    
    def _generate_breakout_signals(self, df: pd.DataFrame) -> pd.Series:
        """Generate breakout signals"""
        signals = pd.Series(0, index=df.index)
        
        # BUY: Price breaks above upper BB with momentum
        buy_condition = (
            (df['close'] > df['bb_upper']) &
            (df['close'] > df['close'].shift(1)) &  # Momentum
            (df['bb_width'] > df['bb_width'].shift(1))  # Expanding bands
        )
        
        # SELL: Price breaks below lower BB with momentum
        sell_condition = (
            (df['close'] < df['bb_lower']) &
            (df['close'] < df['close'].shift(1)) &  # Momentum
            (df['bb_width'] > df['bb_width'].shift(1))  # Expanding bands
        )
        
        signals[buy_condition] = 1
        signals[sell_condition] = -1
        
        return signals
    
    def _apply_filters(self, df: pd.DataFrame, signals: pd.Series) -> pd.Series:
        """Apply trading filters (RSI, EMA, time, etc.)"""
        filtered_signals = signals.copy()
        
        # EMA Filter
        if self.params['use_ema_filter']:
            ema_mode = self.params['ema_mode']
            
            if ema_mode == 0:  # TREND - only trade with trend
                # BUY only if price above both EMAs
                filtered_signals[(signals == 1) & (df['close'] < df['ema_slow'])] = 0
                # SELL only if price below both EMAs
                filtered_signals[(signals == -1) & (df['close'] > df['ema_slow'])] = 0
                
            elif ema_mode == 1:  # COUNTER - only trade against trend
                # BUY only if price below both EMAs
                filtered_signals[(signals == 1) & (df['close'] > df['ema_slow'])] = 0
                # SELL only if price above both EMAs
                filtered_signals[(signals == -1) & (df['close'] < df['ema_slow'])] = 0
        
        # Trade direction filter
        trade_dir = self.params['trade_direction']
        if trade_dir == 1:  # ONLY_BUY
            filtered_signals[signals == -1] = 0
        elif trade_dir == 2:  # ONLY_SELL
            filtered_signals[signals == 1] = 0
        
        # Time filter
        if self.params['use_time_filter']:
            filtered_signals = self._apply_time_filter(df, filtered_signals)
        
        return filtered_signals
    
    def _apply_time_filter(self, df: pd.DataFrame, signals: pd.Series) -> pd.Series:
        """Apply time-based filters"""
        filtered = signals.copy()
        
        # Parse hour ranges (e.g., "8-10;16")
        hour_ranges = self.params['hour_ranges']
        if hour_ranges:
            allowed_hours = set()
            for range_str in hour_ranges.split(';'):
                if '-' in range_str:
                    start, end = map(int, range_str.split('-'))
                    allowed_hours.update(range(start, end + 1))
                else:
                    allowed_hours.add(int(range_str))
            
            # Filter by hour
            hour_mask = df.index.hour.isin(allowed_hours)
            filtered[~hour_mask] = 0
        
        # Parse day ranges (e.g., "1-5" for Mon-Fri)
        if self.params['use_day_filter']:
            day_ranges = self.params['day_ranges']
            if day_ranges:
                allowed_days = set()
                for range_str in day_ranges.split(';'):
                    if '-' in range_str:
                        start, end = map(int, range_str.split('-'))
                        allowed_days.update(range(start, end + 1))
                    else:
                        allowed_days.add(int(range_str))
                
                # Filter by day (0=Monday, 6=Sunday)
                day_mask = df.index.dayofweek.isin([d - 1 for d in allowed_days])
                filtered[~day_mask] = 0
        
        return filtered
    
    def simulate_trades(self):
        """Simulate trading based on signals"""
        if self.data is None or 'signal' not in self.data.columns:
            raise ValueError("Signals not generated. Call generate_signals() first.")
        
        print("\n💰 Simulating trades...")
        
        df = self.data
        equity = self.initial_deposit
        peak_equity = equity
        
        open_position = None
        trades = []
        equity_curve = [equity]
        drawdown_curve = [0]
        
        for i in range(len(df)):
            current_bar = df.iloc[i]
            current_time = df.index[i]
            
            # Update equity if position is open
            if open_position is not None:
                # Check for exit
                exit_result = self._check_exit(open_position, current_bar, current_time)
                
                if exit_result is not None:
                    # Close position
                    trade = exit_result
                    trades.append(trade)
                    
                    # Update equity
                    equity += trade['profit']
                    peak_equity = max(peak_equity, equity)
                    
                    open_position = None
            
            # Check for new entry signal
            if open_position is None and current_bar['signal'] != 0:
                # Calculate position size
                position_size = self._calculate_position_size(
                    equity, 
                    current_bar['close'],
                    current_bar['atr']
                )
                
                # Calculate SL/TP
                if current_bar['signal'] == 1:  # BUY
                    sl, tp = self._calculate_sl_tp_buy(current_bar)
                else:  # SELL
                    sl, tp = self._calculate_sl_tp_sell(current_bar)
                
                # Check RR ratio
                if current_bar['signal'] == 1:
                    risk = current_bar['close'] - sl
                    reward = tp - current_bar['close']
                else:
                    risk = sl - current_bar['close']
                    reward = current_bar['close'] - tp
                
                if risk > 0:
                    rr_ratio = reward / risk
                else:
                    rr_ratio = 0
                
                # Only enter if RR is acceptable
                if rr_ratio >= self.params['min_rr']:
                    open_position = {
                        'entry_time': current_time,
                        'entry_price': current_bar['close'],
                        'direction': 'BUY' if current_bar['signal'] == 1 else 'SELL',
                        'position_size': position_size,
                        'sl': sl,
                        'tp': tp,
                        'rr_ratio': rr_ratio
                    }
            
            # Record equity
            equity_curve.append(equity)
            drawdown = (peak_equity - equity) / peak_equity * 100 if peak_equity > 0 else 0
            drawdown_curve.append(drawdown)
        
        # Close any remaining position
        if open_position is not None:
            last_bar = df.iloc[-1]
            exit_result = self._force_close(open_position, last_bar, df.index[-1])
            trades.append(exit_result)
            equity += exit_result['profit']
        
        self.trades = trades
        self.equity_curve = equity_curve
        self.drawdown_curve = drawdown_curve
        self.current_equity = equity
        
        print(f"   Executed {len(trades)} trades")
        print(f"   Final equity: ${equity:,.2f}")
        print(f"   Total return: {((equity / self.initial_deposit - 1) * 100):.2f}%")
    
    def _calculate_position_size(self, equity: float, price: float, atr: float) -> float:
        """Calculate position size based on risk percentage"""
        risk_amount = equity * (self.params['risk_percent'] / 100)
        
        # Use ATR for stop distance estimation
        stop_distance = atr * self.params['atr_multiplier']
        
        if stop_distance > 0:
            # Position size = risk amount / stop distance
            position_size = risk_amount / stop_distance
        else:
            position_size = 0.01  # Minimum lot size
        
        # Round to standard lot sizes (0.01)
        position_size = round(position_size, 2)
        position_size = max(0.01, min(100.0, position_size))  # Clamp between 0.01 and 100
        
        return position_size
    
    def _calculate_sl_tp_buy(self, bar: pd.Series) -> Tuple[float, float]:
        """Calculate SL and TP for BUY trade"""
        # SL: Below recent swing low or ATR-based
        if pd.notna(bar['swing_low']):
            sl = bar['swing_low']
        else:
            sl = bar['close'] - (bar['atr'] * self.params['atr_multiplier'])
        
        # TP: Based on RR ratio
        risk = bar['close'] - sl
        tp = bar['close'] + (risk * self.params['min_rr'])
        
        return sl, tp
    
    def _calculate_sl_tp_sell(self, bar: pd.Series) -> Tuple[float, float]:
        """Calculate SL and TP for SELL trade"""
        # SL: Above recent swing high or ATR-based
        if pd.notna(bar['swing_high']):
            sl = bar['swing_high']
        else:
            sl = bar['close'] + (bar['atr'] * self.params['atr_multiplier'])
        
        # TP: Based on RR ratio
        risk = sl - bar['close']
        tp = bar['close'] - (risk * self.params['min_rr'])
        
        return sl, tp
    
    def _check_exit(self, position: Dict, current_bar: pd.Series, current_time: datetime) -> Optional[Dict]:
        """Check if position should be exited"""
        direction = position['direction']
        entry_price = position['entry_price']
        sl = position['sl']
        tp = position['tp']
        
        # Check SL/TP
        if direction == 'BUY':
            if current_bar['low'] <= sl:
                # Stop loss hit
                exit_price = sl
                profit = (exit_price - entry_price) * position['position_size'] * 100000  # Convert to USD
                exit_reason = 'SL'
            elif current_bar['high'] >= tp:
                # Take profit hit
                exit_price = tp
                profit = (exit_price - entry_price) * position['position_size'] * 100000
                exit_reason = 'TP'
            else:
                return None
        else:  # SELL
            if current_bar['high'] >= sl:
                # Stop loss hit
                exit_price = sl
                profit = (entry_price - exit_price) * position['position_size'] * 100000
                exit_reason = 'SL'
            elif current_bar['low'] <= tp:
                # Take profit hit
                exit_price = tp
                profit = (entry_price - exit_price) * position['position_size'] * 100000
                exit_reason = 'TP'
            else:
                return None
        
        # Calculate actual RR
        if direction == 'BUY':
            risk = entry_price - sl
            reward = exit_price - entry_price
        else:
            risk = sl - entry_price
            reward = entry_price - exit_price
        
        actual_rr = reward / risk if risk > 0 else 0
        
        return {
            'entry_time': position['entry_time'],
            'exit_time': current_time,
            'direction': direction,
            'entry_price': entry_price,
            'exit_price': exit_price,
            'position_size': position['position_size'],
            'sl': sl,
            'tp': tp,
            'profit': profit,
            'exit_reason': exit_reason,
            'planned_rr': position['rr_ratio'],
            'actual_rr': actual_rr,
            'duration_bars': (current_time - position['entry_time']).total_seconds() / 60
        }
    
    def _force_close(self, position: Dict, current_bar: pd.Series, current_time: datetime) -> Dict:
        """Force close position at end of backtest"""
        direction = position['direction']
        entry_price = position['entry_price']
        exit_price = current_bar['close']
        
        if direction == 'BUY':
            profit = (exit_price - entry_price) * position['position_size'] * 100000
            risk = entry_price - position['sl']
            reward = exit_price - entry_price
        else:
            profit = (entry_price - exit_price) * position['position_size'] * 100000
            risk = position['sl'] - entry_price
            reward = entry_price - exit_price
        
        actual_rr = reward / risk if risk > 0 else 0
        
        return {
            'entry_time': position['entry_time'],
            'exit_time': current_time,
            'direction': direction,
            'entry_price': entry_price,
            'exit_price': exit_price,
            'position_size': position['position_size'],
            'sl': position['sl'],
            'tp': position['tp'],
            'profit': profit,
            'exit_reason': 'FORCE_CLOSE',
            'planned_rr': position['rr_ratio'],
            'actual_rr': actual_rr,
            'duration_bars': (current_time - position['entry_time']).total_seconds() / 60
        }
    
    def get_statistics(self) -> Dict:
        """Calculate performance statistics"""
        if not self.trades:
            return {
                'error': 'No trades executed',
                'total_trades': 0
            }
        
        trades_df = pd.DataFrame(self.trades)
        
        # Basic metrics
        total_trades = len(trades_df)
        wins = len(trades_df[trades_df['profit'] > 0])
        losses = len(trades_df[trades_df['profit'] < 0])
        win_rate = (wins / total_trades * 100) if total_trades > 0 else 0
        
        total_profit = trades_df['profit'].sum()
        avg_profit = trades_df['profit'].mean()
        
        winning_trades = trades_df[trades_df['profit'] > 0]
        losing_trades = trades_df[trades_df['profit'] < 0]
        
        avg_win = winning_trades['profit'].mean() if len(winning_trades) > 0 else 0
        avg_loss = losing_trades['profit'].mean() if len(losing_trades) > 0 else 0
        
        # Profit factor
        gross_profit = winning_trades['profit'].sum() if len(winning_trades) > 0 else 0
        gross_loss = abs(losing_trades['profit'].sum()) if len(losing_trades) > 0 else 0
        profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else 0
        
        # Max drawdown
        max_drawdown = max(self.drawdown_curve) if self.drawdown_curve else 0
        
        # Sharpe ratio (simplified)
        returns = trades_df['profit'] / self.initial_deposit * 100
        sharpe_ratio = (returns.mean() / returns.std()) if returns.std() > 0 else 0
        
        # Average RR
        avg_planned_rr = trades_df['planned_rr'].mean()
        avg_actual_rr = trades_df['actual_rr'].mean()
        
        # Trade duration
        avg_duration_hours = trades_df['duration_bars'].mean() / 60
        
        # Return metrics
        total_return = (self.current_equity / self.initial_deposit - 1) * 100
        
        stats = {
            'config_name': self.config.get('name', 'Unknown'),
            'initial_deposit': self.initial_deposit,
            'final_equity': self.current_equity,
            'total_return_pct': round(total_return, 2),
            'total_profit': round(total_profit, 2),
            'total_trades': total_trades,
            'wins': wins,
            'losses': losses,
            'win_rate_pct': round(win_rate, 2),
            'profit_factor': round(profit_factor, 2),
            'avg_profit': round(avg_profit, 2),
            'avg_win': round(avg_win, 2),
            'avg_loss': round(avg_loss, 2),
            'best_trade': round(trades_df['profit'].max(), 2),
            'worst_trade': round(trades_df['profit'].min(), 2),
            'max_drawdown_pct': round(max_drawdown, 2),
            'sharpe_ratio': round(sharpe_ratio, 2),
            'avg_planned_rr': round(avg_planned_rr, 2),
            'avg_actual_rr': round(avg_actual_rr, 2),
            'avg_duration_hours': round(avg_duration_hours, 2),
            'tp_exits': len(trades_df[trades_df['exit_reason'] == 'TP']),
            'sl_exits': len(trades_df[trades_df['exit_reason'] == 'SL']),
        }
        
        return stats
    
    def get_trades_dataframe(self) -> pd.DataFrame:
        """Return trades as DataFrame"""
        if not self.trades:
            return pd.DataFrame()
        
        return pd.DataFrame(self.trades)
    
    def save_trades_csv(self, filename: str = None):
        """Save trades to CSV file"""
        if not self.trades:
            print("No trades to save")
            return
        
        if filename is None:
            config_name = self.config.get('name', 'backtest')
            filename = f"backtest_trades_{config_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        
        trades_df = self.get_trades_dataframe()
        trades_df.to_csv(filename, index=False)
        
        print(f"\n💾 Trades saved to: {filename}")
    
    def plot_equity_curve(self, save_path: str = None):
        """Plot equity curve and drawdown"""
        if not self.equity_curve:
            print("No equity data to plot")
            return
        
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 8), sharex=True)
        
        # Equity curve
        ax1.plot(self.equity_curve, linewidth=2, color='#2ecc71')
        ax1.axhline(y=self.initial_deposit, color='gray', linestyle='--', alpha=0.5, label='Initial Deposit')
        ax1.set_ylabel('Equity ($)', fontsize=12, fontweight='bold')
        ax1.set_title(f'Backtest Results: {self.config.get("name", "Unknown")}', 
                     fontsize=14, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        ax1.legend()
        
        # Add trade markers
        trades_df = self.get_trades_dataframe()
        if not trades_df.empty:
            winning_trades = trades_df[trades_df['profit'] > 0]
            losing_trades = trades_df[trades_df['profit'] < 0]
            
            # Calculate equity at each trade
            equity_at_trades = []
            running_equity = self.initial_deposit
            for _, trade in trades_df.iterrows():
                running_equity += trade['profit']
                equity_at_trades.append(running_equity)
            
            trades_df['equity'] = equity_at_trades
            
            # Plot markers
            win_indices = trades_df[trades_df['profit'] > 0].index
            lose_indices = trades_df[trades_df['profit'] < 0].index
            
            ax1.scatter(win_indices, trades_df.loc[win_indices, 'equity'], 
                       color='green', marker='^', s=100, alpha=0.6, label='Win')
            ax1.scatter(lose_indices, trades_df.loc[lose_indices, 'equity'],
                       color='red', marker='v', s=100, alpha=0.6, label='Loss')
        
        # Drawdown curve
        ax2.fill_between(range(len(self.drawdown_curve)), self.drawdown_curve, 
                         color='#e74c3c', alpha=0.6)
        ax2.set_ylabel('Drawdown (%)', fontsize=12, fontweight='bold')
        ax2.set_xlabel('Trade Number', fontsize=12, fontweight='bold')
        ax2.grid(True, alpha=0.3)
        ax2.invert_yaxis()
        
        # Add statistics box
        stats = self.get_statistics()
        stats_text = f"""
Total Trades: {stats['total_trades']}
Win Rate: {stats['win_rate_pct']:.1f}%
Profit Factor: {stats['profit_factor']:.2f}
Total Return: {stats['total_return_pct']:.2f}%
Max Drawdown: {stats['max_drawdown_pct']:.2f}%
Sharpe Ratio: {stats['sharpe_ratio']:.2f}
        """
        
        ax1.text(0.02, 0.98, stats_text.strip(), transform=ax1.transAxes,
                fontsize=10, verticalalignment='top',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"\n📊 Chart saved to: {save_path}")
        else:
            plt.show()
    
    def plot_trade_analysis(self, save_path: str = None):
        """Plot detailed trade analysis"""
        if not self.trades:
            print("No trades to analyze")
            return
        
        trades_df = self.get_trades_dataframe()
        
        fig, axes = plt.subplots(2, 2, figsize=(16, 10))
        
        # 1. Profit distribution
        ax1 = axes[0, 0]
        ax1.hist(trades_df['profit'], bins=30, color='steelblue', alpha=0.7, edgecolor='black')
        ax1.axvline(x=0, color='red', linestyle='--', linewidth=2)
        ax1.set_xlabel('Profit ($)', fontsize=11, fontweight='bold')
        ax1.set_ylabel('Frequency', fontsize=11, fontweight='bold')
        ax1.set_title('Profit Distribution', fontsize=12, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # 2. RR ratio comparison
        ax2 = axes[0, 1]
        x = np.arange(len(trades_df))
        width = 0.35
        ax2.bar(x - width/2, trades_df['planned_rr'], width, label='Planned RR', alpha=0.7)
        ax2.bar(x + width/2, trades_df['actual_rr'], width, label='Actual RR', alpha=0.7)
        ax2.axhline(y=self.params['min_rr'], color='red', linestyle='--', label='Min RR')
        ax2.set_xlabel('Trade Number', fontsize=11, fontweight='bold')
        ax2.set_ylabel('Risk/Reward Ratio', fontsize=11, fontweight='bold')
        ax2.set_title('RR Ratio Analysis', fontsize=12, fontweight='bold')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        # 3. Cumulative profit
        ax3 = axes[1, 0]
        cumulative_profit = trades_df['profit'].cumsum()
        ax3.plot(cumulative_profit, linewidth=2, color='darkgreen')
        ax3.fill_between(range(len(cumulative_profit)), cumulative_profit, alpha=0.3, color='green')
        ax3.axhline(y=0, color='red', linestyle='--', linewidth=1)
        ax3.set_xlabel('Trade Number', fontsize=11, fontweight='bold')
        ax3.set_ylabel('Cumulative Profit ($)', fontsize=11, fontweight='bold')
        ax3.set_title('Cumulative Profit', fontsize=12, fontweight='bold')
        ax3.grid(True, alpha=0.3)
        
        # 4. Trade duration analysis
        ax4 = axes[1, 1]
        duration_hours = trades_df['duration_bars'] / 60
        winning_duration = duration_hours[trades_df['profit'] > 0]
        losing_duration = duration_hours[trades_df['profit'] < 0]
        
        ax4.boxplot([winning_duration, losing_duration], 
                    labels=['Winning Trades', 'Losing Trades'],
                    patch_artist=True)
        ax4.set_ylabel('Duration (hours)', fontsize=11, fontweight='bold')
        ax4.set_title('Trade Duration Analysis', fontsize=12, fontweight='bold')
        ax4.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"\n📊 Analysis chart saved to: {save_path}")
        else:
            plt.show()
    
    def run_full_backtest(self, target_timeframe: str = None, save_results: bool = True):
        """
        Run complete backtest pipeline
        
        Args:
            target_timeframe: Target timeframe for resampling
            save_results: Whether to save results to files
        """
        print("\n" + "="*70)
        print(f"   🚀 RUNNING BACKTEST: {self.config.get('name', 'Unknown')}")
        print("="*70)
        
        # Load data
        self.load_data(target_timeframe)
        
        # Calculate indicators
        self.calculate_indicators()
        
        # Generate signals
        self.generate_signals()
        
        # Simulate trades
        self.simulate_trades()
        
        # Display statistics
        print("\n" + "="*70)
        print("   📊 BACKTEST RESULTS")
        print("="*70)
        
        stats = self.get_statistics()
        
        print(f"\n💰 Financial Results:")
        print(f"   Initial Deposit: ${stats['initial_deposit']:,.2f}")
        print(f"   Final Equity: ${stats['final_equity']:,.2f}")
        print(f"   Total Return: {stats['total_return_pct']:.2f}%")
        print(f"   Total Profit: ${stats['total_profit']:,.2f}")
        
        print(f"\n📈 Trading Performance:")
        print(f"   Total Trades: {stats['total_trades']}")
        print(f"   Wins: {stats['wins']} ({stats['win_rate_pct']:.1f}%)")
        print(f"   Losses: {stats['losses']}")
        print(f"   Profit Factor: {stats['profit_factor']:.2f}")
        
        print(f"\n💹 Trade Statistics:")
        print(f"   Average Profit: ${stats['avg_profit']:.2f}")
        print(f"   Average Win: ${stats['avg_win']:.2f}")
        print(f"   Average Loss: ${stats['avg_loss']:.2f}")
        print(f"   Best Trade: ${stats['best_trade']:.2f}")
        print(f"   Worst Trade: ${stats['worst_trade']:.2f}")
        
        print(f"\n📊 Risk Metrics:")
        print(f"   Max Drawdown: {stats['max_drawdown_pct']:.2f}%")
        print(f"   Sharpe Ratio: {stats['sharpe_ratio']:.2f}")
        print(f"   Avg Planned RR: {stats['avg_planned_rr']:.2f}")
        print(f"   Avg Actual RR: {stats['avg_actual_rr']:.2f}")
        
        print(f"\n⏱️  Other Metrics:")
        print(f"   Avg Trade Duration: {stats['avg_duration_hours']:.1f} hours")
        print(f"   TP Exits: {stats['tp_exits']}")
        print(f"   SL Exits: {stats['sl_exits']}")
        
        # Save results
        if save_results and self.trades:
            config_name = self.config.get('name', 'backtest').replace(' ', '_')
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            
            # Save trades CSV
            self.save_trades_csv(f"backtest_trades_{config_name}_{timestamp}.csv")
            
            # Save equity curve plot
            self.plot_equity_curve(f"backtest_equity_{config_name}_{timestamp}.png")
            
            # Save analysis plot
            self.plot_trade_analysis(f"backtest_analysis_{config_name}_{timestamp}.png")
            
            # Save statistics JSON
            import json
            with open(f"backtest_stats_{config_name}_{timestamp}.json", 'w') as f:
                json.dump(stats, f, indent=2)
            
            print(f"\n✅ All results saved with prefix: backtest_{config_name}_{timestamp}")
        
        print("\n" + "="*70)
        
        return stats

