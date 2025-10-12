"""
Simple Demo: Run a quick backtest to see the system in action
"""

from ea_launcher import MT5EALauncher


def main():
    print("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║              Quick Backtest Demo - JTFreeCandle_v2               ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
    
    print("\n🚀 Starting backtest demo...\n")
    
    # Create launcher
    launcher = MT5EALauncher()
    
    # Create a simple configuration
    print("📝 Creating strategy configuration...")
    config = launcher.create_configuration(
        config_name="Demo_Strategy_H1",
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
        entry_mode="REVERSION",
        trade_direction="BOTH",
        risk_percent=1.0,
        min_rr=2.0,
        use_time_filter=False
    )
    
    print("✅ Configuration created!\n")
    
    # Run backtest
    print("🔄 Running backtest on historical data...")
    print("   (This may take 10-30 seconds...)\n")
    
    csv_file = "EURUSD_PERIOD_M1_20170101_20250102.csv"
    
    backtester = launcher.run_csv_backtest(
        config=config,
        csv_file=csv_file,
        initial_deposit=10000.0,
        target_timeframe="H1",
        save_results=True
    )
    
    if backtester is None:
        print("\n❌ Backtest failed. Please check:")
        print("   1. CSV file exists: EURUSD_PERIOD_M1_20170101_20250102.csv")
        print("   2. Dependencies installed: pandas, numpy, matplotlib")
        print("   3. Run: pip install pandas numpy matplotlib")
        return
    
    # Display summary
    stats = backtester.get_statistics()
    
    print("\n" + "="*70)
    print("   🎉 DEMO COMPLETE - SUMMARY")
    print("="*70)
    
    print(f"\n💰 Financial Performance:")
    print(f"   Initial Deposit:     ${stats['initial_deposit']:>10,.2f}")
    print(f"   Final Equity:        ${stats['final_equity']:>10,.2f}")
    print(f"   Total Return:        {stats['total_return_pct']:>10.2f}%")
    print(f"   Total Profit:        ${stats['total_profit']:>10,.2f}")
    
    print(f"\n📈 Trading Statistics:")
    print(f"   Total Trades:        {stats['total_trades']:>10}")
    print(f"   Winning Trades:      {stats['wins']:>10}")
    print(f"   Losing Trades:       {stats['losses']:>10}")
    print(f"   Win Rate:            {stats['win_rate_pct']:>10.1f}%")
    print(f"   Profit Factor:       {stats['profit_factor']:>10.2f}")
    
    print(f"\n💹 Risk Metrics:")
    print(f"   Max Drawdown:        {stats['max_drawdown_pct']:>10.2f}%")
    print(f"   Sharpe Ratio:        {stats['sharpe_ratio']:>10.2f}")
    print(f"   Avg Win:             ${stats['avg_win']:>10.2f}")
    print(f"   Avg Loss:            ${stats['avg_loss']:>10.2f}")
    
    print(f"\n📊 Trade Details:")
    print(f"   TP Exits:            {stats['tp_exits']:>10}")
    print(f"   SL Exits:            {stats['sl_exits']:>10}")
    print(f"   Avg Duration:        {stats['avg_duration_hours']:>10.1f} hours")
    
    # Interpretation
    print("\n" + "="*70)
    print("   📖 INTERPRETATION")
    print("="*70)
    
    if stats['total_return_pct'] > 0:
        print(f"\n✅ PROFITABLE STRATEGY!")
        print(f"   Your strategy made {stats['total_return_pct']:.1f}% return on the test data.")
    else:
        print(f"\n⚠️  LOSING STRATEGY")
        print(f"   Your strategy lost {abs(stats['total_return_pct']):.1f}% on the test data.")
        print(f"   Try adjusting parameters or testing different timeframes.")
    
    if stats['win_rate_pct'] >= 50:
        print(f"   ✓ Good win rate at {stats['win_rate_pct']:.1f}%")
    else:
        print(f"   ! Lower win rate ({stats['win_rate_pct']:.1f}%), but can still be profitable with good R:R")
    
    if stats['profit_factor'] > 1.5:
        print(f"   ✓ Excellent profit factor: {stats['profit_factor']:.2f}")
    elif stats['profit_factor'] > 1.0:
        print(f"   ✓ Positive profit factor: {stats['profit_factor']:.2f}")
    else:
        print(f"   ! Poor profit factor: {stats['profit_factor']:.2f} (need > 1.0)")
    
    if stats['max_drawdown_pct'] < 20:
        print(f"   ✓ Acceptable drawdown: {stats['max_drawdown_pct']:.1f}%")
    else:
        print(f"   ! High drawdown: {stats['max_drawdown_pct']:.1f}% (risky!)")
    
    # Output files
    print("\n" + "="*70)
    print("   📁 GENERATED FILES")
    print("="*70)
    
    print("\n   The following files have been created:")
    print("   1. Trade log CSV with all trades")
    print("   2. Equity curve chart (PNG)")
    print("   3. Trade analysis charts (PNG)")
    print("   4. Statistics JSON file")
    
    print("\n   Look for files starting with 'backtest_*' in the current directory.")
    
    # Next steps
    print("\n" + "="*70)
    print("   🎯 NEXT STEPS")
    print("="*70)
    
    print("\n   1. Review the generated charts to visualize performance")
    print("   2. Check the trade log CSV for detailed trade information")
    print("   3. Try different parameters (risk, timeframe, indicators)")
    print("   4. Test multiple strategies using batch_csv_backtest()")
    print("   5. Read BACKTESTING_GUIDE.md for advanced features")
    
    print("\n   💡 Quick modifications you can try:")
    print("      - Change timeframe to 'H4' for swing trading")
    print("      - Set entry_mode='BREAKOUT' for momentum strategy")
    print("      - Adjust risk_percent (0.5 = conservative, 2.0 = aggressive)")
    print("      - Enable time filters for specific trading hours")
    
    print("\n" + "="*70)
    print("   ✅ Demo completed successfully!")
    print("="*70)
    
    print("\n   Run 'python backtest_example.py' for more examples!")
    print("   Read 'QUICK_START_BACKTEST.md' to learn more.\n")


if __name__ == "__main__":
    try:
        main()
    except FileNotFoundError as e:
        print(f"\n❌ Error: {e}")
        print("\n💡 Make sure you're in the Pyth/ directory and the CSV file exists.")
        print("   Expected file: EURUSD_PERIOD_M1_20170101_20250102.csv")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        print("\n💡 Please check:")
        print("   1. All dependencies are installed")
        print("   2. CSV file is properly formatted")
        print("   3. You have write permissions in the directory")

