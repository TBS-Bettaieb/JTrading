"""
MT5 EA Multi-Configuration Launcher
Lance l'EA JTFreeCandle_v2 avec plusieurs configurations
"""

import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import json
import time
from pathlib import Path
import logging

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ea_launcher.log'),
        logging.StreamHandler()
    ]
)

class MT5EALauncher:
    """Gestionnaire de lancement d'EA avec configurations multiples"""
    
    def __init__(self, mt5_path: Optional[str] = None):
        """
        Initialise le launcher
        
        Args:
            mt5_path: Chemin vers terminal64.exe (optionnel)
        """
        self.mt5_path = mt5_path
        self.ea_name = "JTFreeCandle_v2"
        self.configurations = []
        self.results = []
        
    def connect(self) -> bool:
        """Connecte à MetaTrader 5"""
        if self.mt5_path:
            if not mt5.initialize(self.mt5_path):
                logging.error(f"Échec initialisation MT5: {mt5.last_error()}")
                return False
        else:
            if not mt5.initialize():
                logging.error(f"Échec initialisation MT5: {mt5.last_error()}")
                return False
        
        logging.info(f"MT5 connecté - Version: {mt5.version()}")
        logging.info(f"Compte: {mt5.account_info().login}")
        return True
    
    def disconnect(self):
        """Déconnecte de MT5"""
        mt5.shutdown()
        logging.info("MT5 déconnecté")
    
    def create_configuration(
        self,
        config_name: str,
        symbol: str = "EURUSD",
        timeframe: str = "H1",
        # Bollinger Bands
        bb_period: int = 20,
        bb_deviation: float = 2.0,
        # RSI
        use_rsi_filter: bool = True,
        rsi_period: int = 14,
        rsi_oversold: float = 29.0,
        rsi_overbought: float = 71.0,
        # EMA
        use_ema_filter: bool = True,
        ema_fast: int = 50,
        ema_slow: int = 100,
        ema_mode: str = "TREND",  # TREND, COUNTER, ZONE
        ema_zone_distance: float = 20.0,
        # Divergence
        use_divergence: bool = True,
        div_rsi_buy: float = 35.0,
        div_rsi_sell: float = 65.0,
        div_swing_length: int = 5,
        # Trading
        entry_mode: str = "REVERSION",  # REVERSION ou BREAKOUT
        trade_direction: str = "BOTH",  # BOTH, ONLY_BUY, ONLY_SELL
        risk_percent: float = 0.1,
        min_rr: float = 2.0,
        # SL/TP
        sl_period: int = 50,
        tp_period: int = 30,
        atr_multiplier: float = 2.0,
        # Filtres temps
        use_time_filter: bool = True,
        hour_ranges: str = "8-10;16",
        use_day_filter: bool = False,
        day_ranges: str = "1-5",
        # Magic
        magic: int = None
    ) -> Dict:
        """
        Crée une configuration pour l'EA
        
        Returns:
            Dictionnaire de configuration
        """
        if magic is None:
            magic = 20251007 + len(self.configurations)
        
        # Convertir timeframe string en ENUM
        tf_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "M30": mt5.TIMEFRAME_M30,
            "H1": mt5.TIMEFRAME_H1,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1
        }
        
        config = {
            "name": config_name,
            "symbol": symbol,
            "timeframe": tf_map.get(timeframe, mt5.TIMEFRAME_H1),
            "timeframe_str": timeframe,
            "magic": magic,
            # Paramètres EA (format pour MT5)
            "inputs": {
                "InpSymbol": symbol,
                "InpTF": tf_map.get(timeframe, mt5.TIMEFRAME_H1),
                "BB_Period": bb_period,
                "BB_Dev": bb_deviation,
                "Use_RSI_Filter": use_rsi_filter,
                "RSI_Period": rsi_period,
                "RSI_Oversold": rsi_oversold,
                "RSI_Overbought": rsi_overbought,
                "Use_EMA_Filter": use_ema_filter,
                "EMA_Fast_Period": ema_fast,
                "EMA_Slow_Period": ema_slow,
                "EMA_Filter_Mode": 0 if ema_mode == "TREND" else (1 if ema_mode == "COUNTER" else 2),
                "EMA_Zone_Distance": ema_zone_distance,
                "Use_Divergence_Validator": use_divergence,
                "Div_RSI_Buy_Level": div_rsi_buy,
                "Div_RSI_Sell_Level": div_rsi_sell,
                "Div_Swing_Length": div_swing_length,
                "Mode": 0 if entry_mode == "REVERSION" else 1,
                "TradeDir": 0 if trade_direction == "BOTH" else (1 if trade_direction == "ONLY_BUY" else 2),
                "Risk_Percent": risk_percent,
                "Min_RR": min_rr,
                "SL_Period": sl_period,
                "TP_Period": tp_period,
                "ATR_Multiplier": atr_multiplier,
                "UseTimeFilter": use_time_filter,
                "HourRanges": hour_ranges,
                "UseDayFilter": use_day_filter,
                "DayRanges": day_ranges,
                "Magic": magic
            }
        }
        
        self.configurations.append(config)
        logging.info(f"Configuration créée: {config_name}")
        return config
    
    def save_configurations(self, filename: str = "ea_configs.json"):
        """Sauvegarde les configurations dans un fichier JSON"""
        # Convertir les configs pour JSON (enlever les objets MT5)
        configs_to_save = []
        for config in self.configurations:
            config_copy = config.copy()
            # Garder seulement les valeurs sérialisables
            config_json = {
                "name": config_copy["name"],
                "symbol": config_copy["symbol"],
                "timeframe_str": config_copy["timeframe_str"],
                "magic": config_copy["magic"],
                "inputs": {}
            }
            # Copier les inputs en convertissant les bool
            for key, value in config_copy["inputs"].items():
                if isinstance(value, bool):
                    config_json["inputs"][key] = value
                else:
                    config_json["inputs"][key] = value
            configs_to_save.append(config_json)
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(configs_to_save, f, indent=2, ensure_ascii=False)
        
        logging.info(f"Configurations sauvegardées dans {filename}")
    
    def load_configurations(self, filename: str = "ea_configs.json"):
        """Charge les configurations depuis un fichier JSON"""
        with open(filename, 'r', encoding='utf-8') as f:
            configs = json.load(f)
        
        self.configurations = []
        tf_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "M30": mt5.TIMEFRAME_M30,
            "H1": mt5.TIMEFRAME_H1,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1
        }
        
        for config in configs:
            config["timeframe"] = tf_map.get(config["timeframe_str"], mt5.TIMEFRAME_H1)
            config["inputs"]["InpTF"] = config["timeframe"]
            self.configurations.append(config)
        
        logging.info(f"{len(self.configurations)} configurations chargées depuis {filename}")
    
    def generate_set_file(self, config: Dict, output_dir: str = "MT5_Sets") -> str:
        """
        Génère un fichier .set pour l'EA
        
        Args:
            config: Configuration à utiliser
            output_dir: Dossier de sortie
            
        Returns:
            Chemin du fichier .set créé
        """
        Path(output_dir).mkdir(exist_ok=True)
        
        filename = f"{output_dir}/{self.ea_name}_{config['name']}.set"
        
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(f"; Configuration: {config['name']}\n")
            f.write(f"; Generated: {datetime.now().strftime('%Y.%m.%d %H:%M:%S')}\n\n")
            
            for key, value in config['inputs'].items():
                # Convertir les valeurs en format .set
                if isinstance(value, bool):
                    set_value = "true" if value else "false"
                elif isinstance(value, str):
                    set_value = f"{value}"
                else:
                    set_value = str(value)
                
                f.write(f"{key}={set_value}\n")
        
        logging.info(f"Fichier .set créé: {filename}")
        return filename
    
    def run_backtest(
        self,
        config: Dict,
        start_date: datetime,
        end_date: datetime,
        initial_deposit: float = 10000.0,
        optimization: bool = False
    ) -> Optional[Dict]:
        """
        Lance un backtest avec une configuration
        
        Args:
            config: Configuration à tester
            start_date: Date de début
            end_date: Date de fin
            initial_deposit: Dépôt initial
            optimization: Si True, lance une optimisation
            
        Returns:
            Résultats du backtest
        """
        logging.info(f"Lancement backtest: {config['name']}")
        logging.info(f"Période: {start_date} -> {end_date}")
        
        # Note: MT5 Python ne supporte pas directement le backtesting
        # Il faut utiliser Strategy Tester de MT5 ou passer par des fichiers .set
        
        logging.warning("Le backtesting direct via Python n'est pas supporté par MT5")
        logging.info("Alternatives:")
        logging.info("1. Générer des fichiers .set et utiliser Strategy Tester MT5")
        logging.info("2. Utiliser l'API REST de MT5 si disponible")
        logging.info("3. Exécuter en live et suivre les résultats")
        
        # Générer le fichier .set pour utilisation manuelle
        set_file = self.generate_set_file(config)
        logging.info(f"Fichier .set créé: {set_file}")
        logging.info("Chargez ce fichier dans Strategy Tester de MT5 pour le backtest")
        
        return {
            "config_name": config["name"],
            "set_file": set_file,
            "status": "set_file_generated",
            "message": "Utilisez Strategy Tester MT5 avec ce fichier .set"
        }
    
    def monitor_live_positions(self) -> pd.DataFrame:
        """
        Surveille les positions ouvertes
        
        Returns:
            DataFrame avec les positions
        """
        positions = mt5.positions_get()
        
        if positions is None or len(positions) == 0:
            return pd.DataFrame()
        
        df = pd.DataFrame(list(positions), columns=positions[0]._asdict().keys())
        
        # Ajouter des colonnes calculées
        df['profit_pct'] = (df['profit'] / df['volume'] / 100000) * 100  # Approximatif
        df['duration_min'] = (datetime.now().timestamp() - df['time']) / 60
        
        return df
    
    def get_csv_results(self, symbol: str, magic: int = None) -> pd.DataFrame:
        """
        Lit les résultats CSV générés par l'EA
        
        Args:
            symbol: Symbole à analyser
            magic: Magic number (optionnel)
            
        Returns:
            DataFrame avec les trades
        """
        # Chercher le fichier CSV
        csv_pattern = f"TradeAnalysis_{symbol}_*.csv"
        csv_files = list(Path(mt5.terminal_info().data_path + "/MQL5/Files").glob(csv_pattern))
        
        if not csv_files:
            logging.warning(f"Aucun fichier CSV trouvé pour {symbol}")
            return pd.DataFrame()
        
        # Prendre le plus récent
        csv_file = max(csv_files, key=lambda p: p.stat().st_mtime)
        logging.info(f"Lecture CSV: {csv_file}")
        
        df = pd.read_csv(csv_file)
        
        if magic is not None:
            # Le CSV ne contient pas directement le magic, mais on peut filtrer par Mode
            pass
        
        return df
    
    def analyze_results(self, df: pd.DataFrame) -> Dict:
        """
        Analyse les résultats des trades
        
        Args:
            df: DataFrame avec les trades
            
        Returns:
            Dictionnaire avec les statistiques
        """
        if df.empty:
            return {"error": "Pas de données"}
        
        # Filtrer les trades fermés
        closed = df[df['CloseTime'].notna()].copy()
        
        if closed.empty:
            return {"error": "Pas de trades fermés"}
        
        stats = {
            "total_trades": len(closed),
            "wins": len(closed[closed['Profit'] > 0]),
            "losses": len(closed[closed['Profit'] < 0]),
            "win_rate": len(closed[closed['Profit'] > 0]) / len(closed) * 100,
            "total_profit": closed['Profit'].sum(),
            "avg_profit": closed['Profit'].mean(),
            "avg_win": closed[closed['Profit'] > 0]['Profit'].mean() if len(closed[closed['Profit'] > 0]) > 0 else 0,
            "avg_loss": closed[closed['Profit'] < 0]['Profit'].mean() if len(closed[closed['Profit'] < 0]) > 0 else 0,
            "best_trade": closed['Profit'].max(),
            "worst_trade": closed['Profit'].min(),
            "avg_rr": closed['ActualRR'].mean() if 'ActualRR' in closed.columns else 0,
            "profit_factor": abs(closed[closed['Profit'] > 0]['Profit'].sum() / closed[closed['Profit'] < 0]['Profit'].sum()) if len(closed[closed['Profit'] < 0]) > 0 else 0
        }
        
        return stats
    
    def compare_configurations(self) -> pd.DataFrame:
        """
        Compare les performances de toutes les configurations
        
        Returns:
            DataFrame comparatif
        """
        results = []
        
        for config in self.configurations:
            symbol = config['symbol']
            magic = config['magic']
            
            # Lire les résultats CSV
            df = self.get_csv_results(symbol, magic)
            
            if not df.empty:
                stats = self.analyze_results(df)
                stats['config_name'] = config['name']
                stats['symbol'] = symbol
                stats['timeframe'] = config['timeframe_str']
                stats['magic'] = magic
                results.append(stats)
        
        if not results:
            return pd.DataFrame()
        
        comparison_df = pd.DataFrame(results)
        
        # Trier par profit total
        comparison_df = comparison_df.sort_values('total_profit', ascending=False)
        
        return comparison_df


def example_usage():
    """Exemple d'utilisation du launcher"""
    
    # Créer le launcher
    launcher = MT5EALauncher()
    
    # Connecter à MT5
    if not launcher.connect():
        return
    
    try:
        # ===== CRÉER PLUSIEURS CONFIGURATIONS =====
        
        # Config 1: Conservative (défaut amélioré)
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
            risk_percent=0.5,
            min_rr=2.5
        )
        
        # Config 2: Aggressive
        launcher.create_configuration(
            config_name="Aggressive_M15",
            symbol="EURUSD",
            timeframe="M15",
            bb_period=15,
            bb_deviation=1.8,
            use_rsi_filter=True,
            rsi_oversold=30.0,
            rsi_overbought=70.0,
            use_ema_filter=False,
            risk_percent=1.0,
            min_rr=1.8
        )
        
        # Config 3: Counter-trend
        launcher.create_configuration(
            config_name="CounterTrend_H4",
            symbol="GBPUSD",
            timeframe="H4",
            bb_period=25,
            bb_deviation=2.5,
            ema_mode="COUNTER",
            use_divergence=True,
            risk_percent=0.3,
            min_rr=3.0
        )
        
        # Config 4: Breakout
        launcher.create_configuration(
            config_name="Breakout_H1",
            symbol="USDJPY",
            timeframe="H1",
            entry_mode="BREAKOUT",
            bb_deviation=1.5,
            use_rsi_filter=False,
            risk_percent=0.8,
            min_rr=2.0
        )
        
        # ===== SAUVEGARDER LES CONFIGURATIONS =====
        launcher.save_configurations("my_ea_configs.json")
        
        # ===== GÉNÉRER LES FICHIERS .SET =====
        logging.info("\n" + "="*60)
        logging.info("GÉNÉRATION DES FICHIERS .SET")
        logging.info("="*60)
        
        for config in launcher.configurations:
            launcher.generate_set_file(config)
        
        # ===== SURVEILLER LES POSITIONS EN LIVE =====
        logging.info("\n" + "="*60)
        logging.info("SURVEILLANCE DES POSITIONS")
        logging.info("="*60)
        
        positions_df = launcher.monitor_live_positions()
        if not positions_df.empty:
            print("\nPositions ouvertes:")
            print(positions_df[['ticket', 'symbol', 'type', 'volume', 'profit', 'profit_pct']])
        else:
            print("Aucune position ouverte")
        
        # ===== ANALYSER LES RÉSULTATS =====
        logging.info("\n" + "="*60)
        logging.info("ANALYSE DES RÉSULTATS")
        logging.info("="*60)
        
        comparison = launcher.compare_configurations()
        if not comparison.empty:
            print("\nComparaison des configurations:")
            print(comparison[['config_name', 'total_trades', 'win_rate', 
                            'total_profit', 'profit_factor', 'avg_rr']])
        
    finally:
        launcher.disconnect()


if __name__ == "__main__":
    example_usage()
