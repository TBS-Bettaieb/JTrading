"""
Example Usage: CSV Backtesting System
Demonstrates how to use the backtester with the MT5 EA launcher
"""

from ea_launcher import MT5EALauncher
from ea_backtester import Backtester
import pandas as pd
from pathlib import Path


def example_1_single_backtest():
    """Example 1: Run a single backtest"""
    print("\n" + "="*70)
    print("   EXAMPLE 1: Single Configuration Backtest")
    print("="*70)
    
    # Create launcher (no MT5 connection needed for backtesting)
    launcher = MT5EALauncher()
    
    # Create a configuration
    config = launcher.create_configuration(
        config_name="Conservative_H1_EURUSD",
        symbol="EURUSD",
        timeframe="H1",
        bb_period=20,
        bb_deviation=2.0,
        use_rsi_filter=True,
        rsi_period=14,
        rsi_oversold=30.0,
        rsi_overbought=70.0,
        use_ema_filter=True,
        ema_fast=50,
        ema_slow=100,
        ema_mode="TREND",
        use_divergence=False,
        entry_mode="REVERSION",
        trade_direction="BOTH",
        risk_percent=1.0,
        min_rr=2.0,
        sl_period=50,
        tp_period=30,
        atr_multiplier=2.0,
        use_time_filter=False
    )
    
    # Run backtest
    csv_file = "EURUSD_PERIOD_M1_20170101_20250102.csv"
    
    backtester = launcher.run_csv_backtest(
        config=config,
        csv_file=csv_file,
        initial_deposit=10000.0,
        target_timeframe="H1",  # Resample M1 data to H1
        save_results=True
    )
    
    if backtester:
        # Get statistics
        stats = backtester.get_statistics()
        
        print("\n✅ Backtest completed!")
        print(f"   Total Return: {stats['total_return_pct']:.2f}%")
        print(f"   Win Rate: {stats['win_rate_pct']:.1f}%")
        print(f"   Profit Factor: {stats['profit_factor']:.2f}")
        
        # Access trades dataframe
        trades_df = backtester.get_trades_dataframe()
        print(f"\n   Total trades executed: {len(trades_df)}")
        
        # Display first few trades
        if not trades_df.empty:
            print("\n   First 5 trades:")
            print(trades_df[['entry_time', 'direction', 'profit', 'exit_reason']].head())


def example_2_multiple_configurations():
    """Example 2: Test multiple configurations"""
    print("\n" + "="*70)
    print("   EXAMPLE 2: Multiple Configurations Comparison")
    print("="*70)
    
    launcher = MT5EALauncher()
    
    # Create multiple configurations
    
    # Config 1: Conservative
    launcher.create_configuration(
        config_name="Conservative_H1",
        symbol="EURUSD",
        timeframe="H1",
        bb_period=20,
        bb_deviation=2.0,
        use_rsi_filter=True,
        rsi_oversold=25.0,
        rsi_overbought=75.0,
        use_ema_filter=True,
        ema_mode="TREND",
        entry_mode="REVERSION",
        risk_percent=0.5,
        min_rr=2.5
    )
    
    # Config 2: Aggressive
    launcher.create_configuration(
        config_name="Aggressive_H1",
        symbol="EURUSD",
        timeframe="H1",
        bb_period=15,
        bb_deviation=1.8,
        use_rsi_filter=True,
        rsi_oversold=30.0,
        rsi_overbought=70.0,
        use_ema_filter=False,
        entry_mode="BREAKOUT",
        risk_percent=1.5,
        min_rr=1.8
    )
    
    # Config 3: Counter-trend
    launcher.create_configuration(
        config_name="CounterTrend_H1",
        symbol="EURUSD",
        timeframe="H1",
        bb_period=25,
        bb_deviation=2.5,
        use_rsi_filter=True,
        use_ema_filter=True,
        ema_mode="COUNTER",
        entry_mode="REVERSION",
        risk_percent=0.8,
        min_rr=3.0
    )
    
    # Config 4: Scalping style
    launcher.create_configuration(
        config_name="Scalping_M15",
        symbol="EURUSD",
        timeframe="M15",
        bb_period=15,
        bb_deviation=1.5,
        use_rsi_filter=False,
        use_ema_filter=True,
        ema_fast=20,
        ema_slow=50,
        entry_mode="BREAKOUT",
        risk_percent=1.0,
        min_rr=1.5
    )
    
    # Run batch backtest
    csv_file = "EURUSD_PERIOD_M1_20170101_20250102.csv"
    
    comparison_df = launcher.batch_csv_backtest(
        csv_file=csv_file,
        initial_deposit=10000.0,
        target_timeframe="H1",
        save_comparison=True
    )
    
    if not comparison_df.empty:
        print("\n✅ Batch backtest completed!")
        print("\n📊 Results Summary:")
        print(comparison_df[['config_name', 'total_return_pct', 'win_rate_pct', 
                            'profit_factor', 'total_trades', 'max_drawdown_pct']])


def example_3_custom_backtest():
    """Example 3: Advanced custom backtest"""
    print("\n" + "="*70)
    print("   EXAMPLE 3: Advanced Custom Backtest")
    print("="*70)
    
    # Create a custom configuration
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
            'Use_Divergence_Validator': False,
            'Mode': 0,  # REVERSION
            'TradeDir': 0,  # BOTH
            'Risk_Percent': 1.0,
            'Min_RR': 3.0,
            'SL_Period': 100,
            'TP_Period': 50,
            'ATR_Multiplier': 2.5,
            'UseTimeFilter': True,
            'HourRanges': '8-12;14-18',  # Trade during active hours
            'UseDayFilter': True,
            'DayRanges': '1-5'  # Monday to Friday only
        }
    }
    
    # Create backtester directly
    csv_file = "EURUSD_PERIOD_M1_20170101_20250102.csv"
    backtester = Backtester(csv_file, config, initial_deposit=10000.0)
    
    # Run step by step
    print("\n1️⃣  Loading data...")
    backtester.load_data(target_timeframe='H4')
    
    print("\n2️⃣  Calculating indicators...")
    backtester.calculate_indicators()
    
    print("\n3️⃣  Generating signals...")
    backtester.generate_signals()
    
    print("\n4️⃣  Simulating trades...")
    backtester.simulate_trades()
    
    # Get detailed statistics
    stats = backtester.get_statistics()
    
    print("\n" + "="*70)
    print("   DETAILED RESULTS")
    print("="*70)
    
    for key, value in stats.items():
        if isinstance(value, float):
            print(f"   {key:25s}: {value:10.2f}")
        else:
            print(f"   {key:25s}: {value}")
    
    # Save results manually
    backtester.save_trades_csv("custom_backtest_trades.csv")
    backtester.plot_equity_curve("custom_backtest_equity.png")
    backtester.plot_trade_analysis("custom_backtest_analysis.png")
    
    print("\n✅ Custom backtest completed with manual control!")


def example_4_multi_timeframe_analysis():
    """Example 4: Test same strategy on multiple timeframes"""
    print("\n" + "="*70)
    print("   EXAMPLE 4: Multi-Timeframe Analysis")
    print("="*70)
    
    # Base configuration
    base_config = {
        'symbol': 'EURUSD',
        'inputs': {
            'BB_Period': 20,
            'BB_Dev': 2.0,
            'Use_RSI_Filter': True,
            'RSI_Period': 14,
            'RSI_Oversold': 30.0,
            'RSI_Overbought': 70.0,
            'Use_EMA_Filter': True,
            'EMA_Fast_Period': 50,
            'EMA_Slow_Period': 100,
            'EMA_Filter_Mode': 0,
            'Mode': 0,
            'TradeDir': 0,
            'Risk_Percent': 1.0,
            'Min_RR': 2.0,
            'SL_Period': 50,
            'TP_Period': 30,
            'ATR_Multiplier': 2.0,
            'UseTimeFilter': False,
            'UseDayFilter': False
        }
    }
    
    # Test on multiple timeframes
    timeframes = ['M15', 'M30', 'H1', 'H4']
    csv_file = "EURUSD_PERIOD_M1_20170101_20250102.csv"
    
    results = []
    
    for tf in timeframes:
        print(f"\n📊 Testing on {tf}...")
        
        config = base_config.copy()
        config['name'] = f'Strategy_{tf}'
        config['timeframe_str'] = tf
        
        try:
            backtester = Backtester(csv_file, config, initial_deposit=10000.0)
            backtester.load_data(target_timeframe=tf)
            backtester.calculate_indicators()
            backtester.generate_signals()
            backtester.simulate_trades()
            
            stats = backtester.get_statistics()
            stats['timeframe'] = tf
            results.append(stats)
            
            print(f"   ✓ Return: {stats['total_return_pct']:.2f}% | " +
                  f"Trades: {stats['total_trades']} | " +
                  f"Win Rate: {stats['win_rate_pct']:.1f}%")
            
        except Exception as e:
            print(f"   ✗ Failed: {e}")
    
    # Compare results
    if results:
        results_df = pd.DataFrame(results)
        print("\n" + "="*70)
        print("   TIMEFRAME COMPARISON")
        print("="*70)
        print(results_df[['timeframe', 'total_return_pct', 'total_trades', 
                         'win_rate_pct', 'profit_factor', 'max_drawdown_pct']])
        
        # Find best timeframe
        best = results_df.loc[results_df['total_return_pct'].idxmax()]
        print(f"\n🏆 Best Timeframe: {best['timeframe']} with {best['total_return_pct']:.2f}% return")


def example_5_parameter_optimization():
    """Example 5: Simple parameter optimization"""
    print("\n" + "="*70)
    print("   EXAMPLE 5: Parameter Optimization")
    print("="*70)
    
    csv_file = "EURUSD_PERIOD_M1_20170101_20250102.csv"
    
    # Test different BB periods
    bb_periods = [15, 20, 25, 30]
    bb_deviations = [1.5, 2.0, 2.5]
    
    results = []
    
    print("\n🔍 Testing BB parameter combinations...")
    
    for bb_period in bb_periods:
        for bb_dev in bb_deviations:
            config = {
                'name': f'BB_{bb_period}_{bb_dev}',
                'symbol': 'EURUSD',
                'timeframe_str': 'H1',
                'inputs': {
                    'BB_Period': bb_period,
                    'BB_Dev': bb_dev,
                    'Use_RSI_Filter': True,
                    'RSI_Period': 14,
                    'RSI_Oversold': 30.0,
                    'RSI_Overbought': 70.0,
                    'Use_EMA_Filter': False,
                    'Mode': 0,  # REVERSION
                    'TradeDir': 0,
                    'Risk_Percent': 1.0,
                    'Min_RR': 2.0,
                    'SL_Period': 50,
                    'TP_Period': 30,
                    'ATR_Multiplier': 2.0,
                    'UseTimeFilter': False,
                    'UseDayFilter': False
                }
            }
            
            try:
                backtester = Backtester(csv_file, config, initial_deposit=10000.0)
                backtester.load_data('H1')
                backtester.calculate_indicators()
                backtester.generate_signals()
                backtester.simulate_trades()
                
                stats = backtester.get_statistics()
                stats['bb_period'] = bb_period
                stats['bb_deviation'] = bb_dev
                results.append(stats)
                
                print(f"   BB({bb_period}, {bb_dev}): Return={stats['total_return_pct']:.2f}%, " +
                      f"Trades={stats['total_trades']}, WR={stats['win_rate_pct']:.1f}%")
                
            except Exception as e:
                print(f"   BB({bb_period}, {bb_dev}): Failed - {e}")
    
    # Find best parameters
    if results:
        results_df = pd.DataFrame(results)
        results_df = results_df.sort_values('total_return_pct', ascending=False)
        
        print("\n" + "="*70)
        print("   TOP 5 PARAMETER COMBINATIONS")
        print("="*70)
        
        top5 = results_df.head(5)
        print(top5[['bb_period', 'bb_deviation', 'total_return_pct', 
                   'win_rate_pct', 'profit_factor', 'total_trades']])
        
        best = top5.iloc[0]
        print(f"\n🏆 Optimal Parameters:")
        print(f"   BB Period: {best['bb_period']}")
        print(f"   BB Deviation: {best['bb_deviation']}")
        print(f"   Return: {best['total_return_pct']:.2f}%")
        
        # Save optimization results
        results_df.to_csv('bb_optimization_results.csv', index=False)
        print(f"\n💾 Optimization results saved to: bb_optimization_results.csv")


def main():
    """Run all examples"""
    print("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║          MT5 EA CSV Backtesting System - Examples                ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
    
    print("\nAvailable examples:")
    print("1. Single Configuration Backtest")
    print("2. Multiple Configurations Comparison")
    print("3. Advanced Custom Backtest")
    print("4. Multi-Timeframe Analysis")
    print("5. Parameter Optimization")
    print("6. Run All Examples")
    print("0. Exit")
    
    choice = input("\nSelect example (0-6): ").strip()
    
    if choice == "1":
        example_1_single_backtest()
    elif choice == "2":
        example_2_multiple_configurations()
    elif choice == "3":
        example_3_custom_backtest()
    elif choice == "4":
        example_4_multi_timeframe_analysis()
    elif choice == "5":
        example_5_parameter_optimization()
    elif choice == "6":
        print("\n🚀 Running all examples...\n")
        example_1_single_backtest()
        input("\nPress Enter to continue to Example 2...")
        example_2_multiple_configurations()
        input("\nPress Enter to continue to Example 3...")
        example_3_custom_backtest()
        input("\nPress Enter to continue to Example 4...")
        example_4_multi_timeframe_analysis()
        input("\nPress Enter to continue to Example 5...")
        example_5_parameter_optimization()
        print("\n✅ All examples completed!")
    elif choice == "0":
        print("👋 Goodbye!")
        return
    else:
        print("❌ Invalid choice")
        return
    
    print("\n" + "="*70)
    print("   ✅ EXAMPLE COMPLETED")
    print("="*70)


if __name__ == "__main__":
    main()

