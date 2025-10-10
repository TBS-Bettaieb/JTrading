"""
Backtest Script
Script pour exécuter des backtests de la stratégie
"""

import argparse
import pandas as pd
from datetime import datetime

from config import StrategyConfig, get_conservative_config, get_aggressive_config
from strategies import FreeCandleStrategy
from backtesting import BacktestEngine, PerformanceMetrics
from analysis.performance import PerformanceAnalyzer
from analysis.visualization import Visualizer
from data import DataManager
from utils import setup_logger


def main():
    """Point d'entrée principal du script de backtest"""
    
    # Parser les arguments
    parser = argparse.ArgumentParser(description='Backtest FreeCandleStrategy')
    
    parser.add_argument('--symbol', type=str, default='EURUSD', help='Symbol to backtest')
    parser.add_argument('--timeframe', type=str, default='H1', help='Timeframe (M1, M5, H1, etc.)')
    parser.add_argument('--start-date', type=str, default='2023-01-01', help='Start date (YYYY-MM-DD)')
    parser.add_argument('--end-date', type=str, default='2024-12-31', help='End date (YYYY-MM-DD)')
    parser.add_argument('--capital', type=float, default=10000, help='Initial capital')
    parser.add_argument('--commission', type=float, default=0.0002, help='Commission (fraction)')
    parser.add_argument('--slippage', type=float, default=2.0, help='Slippage (points)')
    parser.add_argument('--config', type=str, default='default', 
                       choices=['default', 'conservative', 'aggressive'],
                       help='Configuration preset')
    parser.add_argument('--data-file', type=str, help='Path to CSV data file (optional)')
    parser.add_argument('--save-report', action='store_true', help='Save report to file')
    parser.add_argument('--plot', action='store_true', help='Generate plots')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    # Setup logger
    logger = setup_logger(
        name='backtest',
        log_file=f'logs/backtest_{args.symbol}_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log',
        level='DEBUG' if args.verbose else 'INFO'
    )
    
    logger.info("=" * 80)
    logger.info("BACKTEST STARTED")
    logger.info("=" * 80)
    logger.info(f"Symbol: {args.symbol}")
    logger.info(f"Timeframe: {args.timeframe}")
    logger.info(f"Period: {args.start_date} to {args.end_date}")
    logger.info(f"Initial Capital: ${args.capital:,.2f}")
    
    # Charger la configuration
    if args.config == 'conservative':
        config = get_conservative_config()
    elif args.config == 'aggressive':
        config = get_aggressive_config()
    else:
        config = StrategyConfig()
    
    config.symbol.symbol = args.symbol
    config.symbol.timeframe = args.timeframe
    
    logger.info(f"Configuration: {args.config}")
    
    # Charger les données
    data_manager = DataManager()
    
    if args.data_file:
        logger.info(f"Loading data from file: {args.data_file}")
        df = data_manager.load_csv(args.data_file)
    else:
        # Essayer de charger depuis le cache
        logger.info("Checking cache for data...")
        df = data_manager.load_from_cache(args.symbol, args.timeframe)
        
        if df is None:
            # Télécharger depuis MT5
            logger.info("No cache found. Downloading data from MT5...")
            from live_trading import MT5Connector
            
            connector = MT5Connector()
            if not connector.connect():
                logger.error("Failed to connect to MT5. Please make sure MT5 is running.")
                return
            
            try:
                logger.info(f"Downloading {args.symbol} {args.timeframe} data...")
                df = connector.get_ohlcv_range(
                    symbol=args.symbol,
                    timeframe=args.timeframe,
                    date_from=pd.to_datetime(args.start_date),
                    date_to=pd.to_datetime(args.end_date)
                )
                
                if df is None or len(df) == 0:
                    logger.error(f"No data available for {args.symbol} {args.timeframe}")
                    connector.disconnect()
                    return
                
                # Sauvegarder dans le cache pour la prochaine fois
                logger.info("Saving data to cache...")
                data_manager.cache_data(df, args.symbol, args.timeframe)
                
                logger.info(f"Downloaded {len(df)} bars")
                
            finally:
                connector.disconnect()
        else:
            logger.info(f"Loaded {len(df)} bars from cache")
    
    # Filtrer par dates
    start_date = pd.to_datetime(args.start_date)
    end_date = pd.to_datetime(args.end_date)
    df = df[(df.index >= start_date) & (df.index <= end_date)]
    
    logger.info(f"Data loaded: {len(df)} bars from {df.index[0]} to {df.index[-1]}")
    
    # Valider les données
    if not data_manager.validate_ohlcv(df):
        logger.error("Invalid OHLCV data")
        return
    
    # Créer la stratégie
    logger.info("Creating strategy...")
    strategy = FreeCandleStrategy(config)
    
    # Générer les signaux
    logger.info("Generating signals...")
    signals = strategy.generate_signals(df)
    logger.info(f"Generated {len(signals)} signals")
    
    if len(signals) == 0:
        logger.warning("No signals generated! Check your strategy parameters.")
        return
    
    # Exécuter le backtest
    logger.info("Running backtest...")
    engine = BacktestEngine(
        initial_capital=args.capital,
        commission=args.commission,
        slippage_points=args.slippage
    )
    
    results = engine.run_backtest(df, signals, config, verbose=args.verbose)
    
    # Afficher les résultats
    logger.info("\n" + "=" * 80)
    logger.info("BACKTEST RESULTS")
    logger.info("=" * 80)
    logger.info(f"Total Trades: {results.total_trades}")
    logger.info(f"Winning Trades: {results.winning_trades} ({results.win_rate:.2f}%)")
    logger.info(f"Losing Trades: {results.losing_trades}")
    logger.info(f"\nProfit Factor: {results.profit_factor:.2f}")
    logger.info(f"Net Profit: ${results.net_profit:,.2f}")
    logger.info(f"Total Return: {results.total_return_pct:.2f}%")
    logger.info(f"\nAvg Win: ${results.avg_win:.2f}")
    logger.info(f"Avg Loss: ${results.avg_loss:.2f}")
    logger.info(f"Avg RR: 1:{results.avg_rr:.2f}")
    logger.info(f"\nMax Drawdown: ${results.max_drawdown:,.2f} ({results.max_drawdown_pct:.2f}%)")
    logger.info(f"Sharpe Ratio: {results.sharpe_ratio:.2f}")
    logger.info(f"Sortino Ratio: {results.sortino_ratio:.2f}")
    logger.info(f"\nMax Consecutive Wins: {results.max_consecutive_wins}")
    logger.info(f"Max Consecutive Losses: {results.max_consecutive_losses}")
    logger.info("=" * 80)
    
    # Métriques avancées
    logger.info("\nCalculating advanced metrics...")
    PerformanceMetrics.print_metrics_report(results)
    
    # Analyse détaillée
    if args.save_report:
        logger.info("\nGenerating detailed analysis...")
        analyzer = PerformanceAnalyzer(results)
        report_file = f'reports/backtest_{args.symbol}_{datetime.now().strftime("%Y%m%d_%H%M%S")}.txt'
        analyzer.generate_report(save_to_file=report_file)
    
    # Visualisations
    if args.plot:
        logger.info("\nGenerating visualizations...")
        viz = Visualizer()
        
        plot_dir = f'plots/{args.symbol}_{datetime.now().strftime("%Y%m%d_%H%M%S")}'
        import os
        os.makedirs(plot_dir, exist_ok=True)
        
        viz.plot_equity_curve(results, save_path=f'{plot_dir}/equity_curve.png', show=False)
        viz.plot_drawdown(results, save_path=f'{plot_dir}/drawdown.png', show=False)
        viz.plot_profit_distribution(results, save_path=f'{plot_dir}/profit_dist.png', show=False)
        viz.plot_monthly_returns(results, save_path=f'{plot_dir}/monthly_returns.png', show=False)
        viz.create_dashboard(results, save_path=f'{plot_dir}/dashboard.png', show=False)
        
        logger.info(f"Plots saved to: {plot_dir}/")
    
    logger.info("\n" + "=" * 80)
    logger.info("BACKTEST COMPLETED")
    logger.info("=" * 80)


if __name__ == "__main__":
    main()

