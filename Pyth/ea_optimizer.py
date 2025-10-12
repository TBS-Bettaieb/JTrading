"""
Optimiseur et Analyseur pour EA JTFreeCandle_v2
Génère automatiquement des configurations optimales et analyse les résultats
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from typing import List, Dict, Tuple
import itertools
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class EAOptimizer:
    """Optimiseur de paramètres pour l'EA"""
    
    def __init__(self):
        self.parameter_ranges = {}
        self.best_configs = []
        
    def define_parameter_space(self):
        """Définit l'espace des paramètres à optimiser"""
        self.parameter_ranges = {
            # Bollinger Bands
            'bb_period': [15, 20, 25, 30],
            'bb_deviation': [1.5, 2.0, 2.5, 3.0],
            
            # RSI
            'rsi_period': [10, 14, 21],
            'rsi_oversold': [25, 30, 35],
            'rsi_overbought': [65, 70, 75],
            
            # EMA
            'ema_fast': [20, 50, 100],
            'ema_slow': [50, 100, 200],
            'ema_mode': ['TREND', 'COUNTER', 'ZONE'],
            
            # Trading
            'entry_mode': ['REVERSION', 'BREAKOUT'],
            'risk_percent': [0.5, 1.0, 1.5, 2.0],
            'min_rr': [1.5, 2.0, 2.5, 3.0],
            
            # SL/TP
            'sl_period': [30, 50, 100],
            'tp_period': [20, 30, 50],
            'atr_multiplier': [1.5, 2.0, 2.5]
        }
        
        logging.info(f"Espace de paramètres défini avec {self._count_combinations()} combinaisons possibles")
    
    def _count_combinations(self) -> int:
        """Compte le nombre total de combinaisons"""
        count = 1
        for values in self.parameter_ranges.values():
            count *= len(values)
        return count
    
    def generate_grid_search_configs(
        self,
        symbol: str = "EURUSD",
        timeframe: str = "H1",
        max_configs: int = 100
    ) -> List[Dict]:
        """
        Génère des configurations via grid search
        
        Args:
            symbol: Symbole à trader
            timeframe: Timeframe
            max_configs: Nombre maximum de configs à générer
            
        Returns:
            Liste de configurations
        """
        if not self.parameter_ranges:
            self.define_parameter_space()
        
        # Générer toutes les combinaisons possibles
        keys = list(self.parameter_ranges.keys())
        values = [self.parameter_ranges[k] for k in keys]
        
        all_combinations = list(itertools.product(*values))
        
        # Limiter le nombre si nécessaire
        if len(all_combinations) > max_configs:
            # Échantillonner de manière uniforme
            step = len(all_combinations) // max_configs
            selected_combinations = all_combinations[::step][:max_configs]
        else:
            selected_combinations = all_combinations
        
        configs = []
        for i, combination in enumerate(selected_combinations):
            config_dict = dict(zip(keys, combination))
            
            # Vérifier la cohérence (EMA fast < EMA slow)
            if config_dict['ema_fast'] >= config_dict['ema_slow']:
                continue
            
            # Vérifier RSI cohérent
            if config_dict['rsi_oversold'] >= config_dict['rsi_overbought']:
                continue
            
            config = {
                'name': f'Grid_{i}',
                'symbol': symbol,
                'timeframe': timeframe,
                **config_dict
            }
            configs.append(config)
        
        logging.info(f"Généré {len(configs)} configurations valides")
        return configs
    
    def generate_random_search_configs(
        self,
        symbol: str = "EURUSD",
        timeframe: str = "H1",
        n_configs: int = 50
    ) -> List[Dict]:
        """
        Génère des configurations via random search
        
        Args:
            symbol: Symbole à trader
            timeframe: Timeframe
            n_configs: Nombre de configurations à générer
            
        Returns:
            Liste de configurations
        """
        if not self.parameter_ranges:
            self.define_parameter_space()
        
        configs = []
        for i in range(n_configs):
            config = {
                'name': f'Random_{i}',
                'symbol': symbol,
                'timeframe': timeframe
            }
            
            # Choisir aléatoirement dans chaque plage
            for param, values in self.parameter_ranges.items():
                config[param] = np.random.choice(values)
            
            # Vérifier la cohérence
            if config['ema_fast'] >= config['ema_slow']:
                config['ema_slow'] = config['ema_fast'] + 50
            
            if config['rsi_oversold'] >= config['rsi_overbought']:
                config['rsi_overbought'] = config['rsi_oversold'] + 20
            
            configs.append(config)
        
        logging.info(f"Généré {len(configs)} configurations aléatoires")
        return configs
    
    def generate_smart_configs(
        self,
        symbol: str = "EURUSD",
        timeframe: str = "H1"
    ) -> List[Dict]:
        """
        Génère des configurations intelligentes basées sur les meilleures pratiques
        
        Returns:
            Liste de configurations optimisées
        """
        configs = [
            # Configuration 1: Scalping agressif
            {
                'name': 'Scalping_Aggressive',
                'symbol': symbol,
                'timeframe': 'M5',
                'bb_period': 15,
                'bb_deviation': 1.8,
                'rsi_period': 10,
                'rsi_oversold': 30,
                'rsi_overbought': 70,
                'use_rsi_filter': True,
                'ema_fast': 20,
                'ema_slow': 50,
                'ema_mode': 'TREND',
                'use_ema_filter': True,
                'entry_mode': 'BREAKOUT',
                'risk_percent': 0.5,
                'min_rr': 1.5,
                'sl_period': 20,
                'tp_period': 15,
                'atr_multiplier': 1.5
            },
            
            # Configuration 2: Day Trading équilibré
            {
                'name': 'DayTrading_Balanced',
                'symbol': symbol,
                'timeframe': 'M15',
                'bb_period': 20,
                'bb_deviation': 2.0,
                'rsi_period': 14,
                'rsi_oversold': 30,
                'rsi_overbought': 70,
                'use_rsi_filter': True,
                'ema_fast': 50,
                'ema_slow': 100,
                'ema_mode': 'TREND',
                'use_ema_filter': True,
                'entry_mode': 'REVERSION',
                'risk_percent': 1.0,
                'min_rr': 2.0,
                'sl_period': 30,
                'tp_period': 25,
                'atr_multiplier': 2.0
            },
            
            # Configuration 3: Swing Trading conservateur
            {
                'name': 'Swing_Conservative',
                'symbol': symbol,
                'timeframe': 'H1',
                'bb_period': 25,
                'bb_deviation': 2.5,
                'rsi_period': 14,
                'rsi_oversold': 25,
                'rsi_overbought': 75,
                'use_rsi_filter': True,
                'ema_fast': 50,
                'ema_slow': 200,
                'ema_mode': 'TREND',
                'use_ema_filter': True,
                'entry_mode': 'REVERSION',
                'risk_percent': 0.5,
                'min_rr': 3.0,
                'sl_period': 50,
                'tp_period': 40,
                'atr_multiplier': 2.5
            },
            
            # Configuration 4: Counter-trend avec divergence
            {
                'name': 'CounterTrend_Divergence',
                'symbol': symbol,
                'timeframe': 'H4',
                'bb_period': 20,
                'bb_deviation': 2.0,
                'rsi_period': 14,
                'rsi_oversold': 30,
                'rsi_overbought': 70,
                'use_rsi_filter': True,
                'ema_fast': 50,
                'ema_slow': 100,
                'ema_mode': 'COUNTER',
                'use_ema_filter': True,
                'use_divergence': True,
                'div_rsi_buy': 35,
                'div_rsi_sell': 65,
                'entry_mode': 'REVERSION',
                'risk_percent': 0.8,
                'min_rr': 2.5,
                'sl_period': 100,
                'tp_period': 50,
                'atr_multiplier': 2.0
            },
            
            # Configuration 5: Breakout momentum
            {
                'name': 'Breakout_Momentum',
                'symbol': symbol,
                'timeframe': 'H1',
                'bb_period': 15,
                'bb_deviation': 1.5,
                'rsi_period': 14,
                'rsi_oversold': 35,
                'rsi_overbought': 65,
                'use_rsi_filter': False,
                'ema_fast': 20,
                'ema_slow': 50,
                'ema_mode': 'TREND',
                'use_ema_filter': True,
                'entry_mode': 'BREAKOUT',
                'risk_percent': 1.5,
                'min_rr': 2.0,
                'sl_period': 30,
                'tp_period': 25,
                'atr_multiplier': 1.8
            }
        ]
        
        logging.info(f"Généré {len(configs)} configurations intelligentes")
        return configs


class EAAnalyzer:
    """Analyseur de performances de l'EA"""
    
    def __init__(self, csv_dir: str = ""):
        """
        Args:
            csv_dir: Répertoire contenant les fichiers CSV
        """
        self.csv_dir = csv_dir or str(Path.home() / "AppData/Roaming/MetaQuotes/Terminal/*/MQL5/Files")
        self.trades_df = None
        
    def load_trades(self, symbol: str, timeframe: str = None) -> pd.DataFrame:
        """
        Charge les trades depuis les fichiers CSV
        
        Args:
            symbol: Symbole à analyser
            timeframe: Timeframe (optionnel)
            
        Returns:
            DataFrame avec tous les trades
        """
        # Chercher les fichiers CSV
        pattern = f"TradeAnalysis_{symbol}"
        if timeframe:
            pattern += f"_{timeframe}"
        pattern += "*.csv"
        
        csv_files = list(Path(self.csv_dir).rglob(pattern))
        
        if not csv_files:
            logging.warning(f"Aucun fichier trouvé pour {pattern}")
            return pd.DataFrame()
        
        # Charger tous les fichiers
        dfs = []
        for csv_file in csv_files:
            try:
                df = pd.read_csv(csv_file)
                df['source_file'] = csv_file.name
                dfs.append(df)
            except Exception as e:
                logging.error(f"Erreur lecture {csv_file}: {e}")
        
        if not dfs:
            return pd.DataFrame()
        
        self.trades_df = pd.concat(dfs, ignore_index=True)
        
        # Convertir les dates
        if 'OpenTime' in self.trades_df.columns:
            self.trades_df['OpenTime'] = pd.to_datetime(self.trades_df['OpenTime'])
        if 'CloseTime' in self.trades_df.columns:
            self.trades_df['CloseTime'] = pd.to_datetime(self.trades_df['CloseTime'])
        
        logging.info(f"Chargé {len(self.trades_df)} trades depuis {len(csv_files)} fichiers")
        return self.trades_df
    
    def calculate_metrics(self, df: pd.DataFrame = None) -> Dict:
        """Calcule les métriques de performance"""
        if df is None:
            df = self.trades_df
        
        if df is None or df.empty:
            return {}
        
        # Filtrer les trades fermés
        closed = df[df['CloseTime'].notna()].copy()
        
        if closed.empty:
            return {"error": "Pas de trades fermés"}
        
        wins = closed[closed['Profit'] > 0]
        losses = closed[closed['Profit'] <= 0]
        
        metrics = {
            # Métriques de base
            'total_trades': len(closed),
            'winning_trades': len(wins),
            'losing_trades': len(losses),
            'win_rate': len(wins) / len(closed) * 100 if len(closed) > 0 else 0,
            
            # Profits
            'total_profit': closed['Profit'].sum(),
            'gross_profit': wins['Profit'].sum() if len(wins) > 0 else 0,
            'gross_loss': abs(losses['Profit'].sum()) if len(losses) > 0 else 0,
            'avg_trade': closed['Profit'].mean(),
            'avg_win': wins['Profit'].mean() if len(wins) > 0 else 0,
            'avg_loss': losses['Profit'].mean() if len(losses) > 0 else 0,
            'best_trade': closed['Profit'].max(),
            'worst_trade': closed['Profit'].min(),
            
            # Ratios
            'profit_factor': wins['Profit'].sum() / abs(losses['Profit'].sum()) if len(losses) > 0 and losses['Profit'].sum() != 0 else float('inf'),
            'avg_rr': closed['ActualRR'].mean() if 'ActualRR' in closed.columns else 0,
            
            # Drawdown
            'max_drawdown': self._calculate_max_drawdown(closed),
            
            # Durée
            'avg_duration_min': closed['Duration'].mean() if 'Duration' in closed.columns else 0,
            
            # Sharpe ratio (approximatif)
            'sharpe_ratio': self._calculate_sharpe(closed)
        }
        
        # Séries consécutives
        consecutive = self._calculate_consecutive(closed)
        metrics.update(consecutive)
        
        return metrics
    
    def _calculate_max_drawdown(self, df: pd.DataFrame) -> float:
        """Calcule le drawdown maximum"""
        if df.empty:
            return 0.0
        
        df_sorted = df.sort_values('CloseTime')
        cumulative = df_sorted['Profit'].cumsum()
        running_max = cumulative.expanding().max()
        drawdown = cumulative - running_max
        return abs(drawdown.min())
    
    def _calculate_sharpe(self, df: pd.DataFrame) -> float:
        """Calcule le ratio de Sharpe (approximatif)"""
        if df.empty or len(df) < 2:
            return 0.0
        
        returns = df['Profit']
        if returns.std() == 0:
            return 0.0
        
        return returns.mean() / returns.std() * np.sqrt(252)  # Annualisé
    
    def _calculate_consecutive(self, df: pd.DataFrame) -> Dict:
        """Calcule les séries consécutives"""
        if df.empty:
            return {'max_consecutive_wins': 0, 'max_consecutive_losses': 0}
        
        df_sorted = df.sort_values('CloseTime')
        wins = (df_sorted['Profit'] > 0).astype(int)
        
        # Calculer les séries
        consecutive_wins = 0
        consecutive_losses = 0
        max_wins = 0
        max_losses = 0
        
        for win in wins:
            if win == 1:
                consecutive_wins += 1
                consecutive_losses = 0
                max_wins = max(max_wins, consecutive_wins)
            else:
                consecutive_losses += 1
                consecutive_wins = 0
                max_losses = max(max_losses, consecutive_losses)
        
        return {
            'max_consecutive_wins': max_wins,
            'max_consecutive_losses': max_losses
        }
    
    def analyze_by_hour(self, df: pd.DataFrame = None) -> pd.DataFrame:
        """Analyse des performances par heure"""
        if df is None:
            df = self.trades_df
        
        if df is None or df.empty or 'Hour' not in df.columns:
            return pd.DataFrame()
        
        closed = df[df['CloseTime'].notna()]
        
        hourly = closed.groupby('Hour').agg({
            'Ticket': 'count',
            'Profit': ['sum', 'mean'],
            'ActualRR': 'mean'
        }).round(2)
        
        hourly.columns = ['Trades', 'Total_Profit', 'Avg_Profit', 'Avg_RR']
        hourly['Win_Rate'] = closed.groupby('Hour').apply(
            lambda x: (x['Profit'] > 0).sum() / len(x) * 100
        ).round(1)
        
        return hourly.sort_values('Total_Profit', ascending=False)
    
    def analyze_by_day(self, df: pd.DataFrame = None) -> pd.DataFrame:
        """Analyse des performances par jour de la semaine"""
        if df is None:
            df = self.trades_df
        
        if df is None or df.empty or 'DayOfWeek' not in df.columns:
            return pd.DataFrame()
        
        closed = df[df['CloseTime'].notna()]
        
        days = {0: 'Dimanche', 1: 'Lundi', 2: 'Mardi', 3: 'Mercredi', 
                4: 'Jeudi', 5: 'Vendredi', 6: 'Samedi'}
        
        daily = closed.groupby('DayOfWeek').agg({
            'Ticket': 'count',
            'Profit': ['sum', 'mean'],
            'ActualRR': 'mean'
        }).round(2)
        
        daily.columns = ['Trades', 'Total_Profit', 'Avg_Profit', 'Avg_RR']
        daily['Win_Rate'] = closed.groupby('DayOfWeek').apply(
            lambda x: (x['Profit'] > 0).sum() / len(x) * 100
        ).round(1)
        
        daily['Day_Name'] = daily.index.map(days)
        
        return daily.sort_values('Total_Profit', ascending=False)
    
    def plot_equity_curve(self, df: pd.DataFrame = None, save_path: str = None):
        """Trace la courbe d'équité"""
        if df is None:
            df = self.trades_df
        
        if df is None or df.empty:
            logging.warning("Pas de données pour tracer")
            return
        
        closed = df[df['CloseTime'].notna()].sort_values('CloseTime')
        
        plt.figure(figsize=(12, 6))
        cumulative_profit = closed['Profit'].cumsum()
        
        plt.plot(closed['CloseTime'], cumulative_profit, linewidth=2)
        plt.fill_between(closed['CloseTime'], cumulative_profit, alpha=0.3)
        plt.axhline(y=0, color='r', linestyle='--', alpha=0.5)
        
        plt.title('Courbe d\'Équité', fontsize=14, fontweight='bold')
        plt.xlabel('Date')
        plt.ylabel('Profit Cumulé ($)')
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            logging.info(f"Graphique sauvegardé: {save_path}")
        else:
            plt.show()
    
    def create_performance_report(self, output_file: str = "ea_performance_report.html"):
        """Crée un rapport HTML complet"""
        if self.trades_df is None or self.trades_df.empty:
            logging.warning("Pas de données pour le rapport")
            return
        
        metrics = self.calculate_metrics()
        hourly = self.analyze_by_hour()
        daily = self.analyze_by_day()
        
        html = f"""
        <html>
        <head>
            <title>Rapport de Performance EA</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                h1 {{ color: #2c3e50; }}
                h2 {{ color: #34495e; margin-top: 30px; }}
                table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
                th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
                th {{ background-color: #3498db; color: white; }}
                tr:nth-child(even) {{ background-color: #f2f2f2; }}
                .metric {{ display: inline-block; margin: 10px; padding: 15px; 
                         background: #ecf0f1; border-radius: 5px; min-width: 200px; }}
                .positive {{ color: #27ae60; font-weight: bold; }}
                .negative {{ color: #e74c3c; font-weight: bold; }}
            </style>
        </head>
        <body>
            <h1>📊 Rapport de Performance EA JTFreeCandle_v2</h1>
            <p>Généré le: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            
            <h2>📈 Métriques Principales</h2>
            <div class="metric">
                <strong>Total Trades:</strong> {metrics.get('total_trades', 0)}
            </div>
            <div class="metric">
                <strong>Win Rate:</strong> 
                <span class="{'positive' if metrics.get('win_rate', 0) > 50 else 'negative'}">
                    {metrics.get('win_rate', 0):.1f}%
                </span>
            </div>
            <div class="metric">
                <strong>Profit Total:</strong>
                <span class="{'positive' if metrics.get('total_profit', 0) > 0 else 'negative'}">
                    ${metrics.get('total_profit', 0):.2f}
                </span>
            </div>
            <div class="metric">
                <strong>Profit Factor:</strong> {metrics.get('profit_factor', 0):.2f}
            </div>
            <div class="metric">
                <strong>Sharpe Ratio:</strong> {metrics.get('sharpe_ratio', 0):.2f}
            </div>
            <div class="metric">
                <strong>Max Drawdown:</strong>
                <span class="negative">${metrics.get('max_drawdown', 0):.2f}</span>
            </div>
            
            <h2>📊 Performance par Heure</h2>
            {hourly.to_html() if not hourly.empty else "<p>Pas de données</p>"}
            
            <h2>📅 Performance par Jour</h2>
            {daily.to_html() if not daily.empty else "<p>Pas de données</p>"}
            
        </body>
        </html>
        """
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html)
        
        logging.info(f"Rapport HTML créé: {output_file}")


# ===== EXEMPLE D'UTILISATION =====
def main():
    """Exemple complet d'utilisation"""
    
    # 1. Créer l'optimiseur
    optimizer = EAOptimizer()
    
    # 2. Générer des configurations intelligentes
    smart_configs = optimizer.generate_smart_configs(symbol="EURUSD")
    
    # 3. Ou générer des configs via random search
    # random_configs = optimizer.generate_random_search_configs(n_configs=20)
    
    # 4. Sauvegarder les configs pour utilisation
    configs_df = pd.DataFrame(smart_configs)
    configs_df.to_csv('ea_optimized_configs.csv', index=False)
    logging.info(f"Sauvegardé {len(smart_configs)} configurations dans ea_optimized_configs.csv")
    
    # 5. Analyser les résultats existants
    analyzer = EAAnalyzer()
    trades_df = analyzer.load_trades("EURUSD")
    
    if not trades_df.empty:
        # Calculer les métriques
        metrics = analyzer.calculate_metrics()
        print("\n=== MÉTRIQUES DE PERFORMANCE ===")
        for key, value in metrics.items():
            print(f"{key}: {value}")
        
        # Analyser par heure
        print("\n=== TOP 5 HEURES ===")
        hourly = analyzer.analyze_by_hour()
        print(hourly.head())
        
        # Analyser par jour
        print("\n=== PERFORMANCE PAR JOUR ===")
        daily = analyzer.analyze_by_day()
        print(daily)
        
        # Tracer la courbe d'équité
        analyzer.plot_equity_curve(save_path='equity_curve.png')
        
        # Créer un rapport HTML
        analyzer.create_performance_report()


if __name__ == "__main__":
    main()
