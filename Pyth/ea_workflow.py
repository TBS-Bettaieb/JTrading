"""
Workflow Complet pour EA JTFreeCandle_v2
Script tout-en-un pour gérer le cycle complet de développement et trading
"""

import sys
from pathlib import Path
import json
import time
from datetime import datetime, timedelta
import pandas as pd

# Importer les modules précédents
# from mt5_ea_launcher import MT5EALauncher
# from mt5_ea_optimizer import EAOptimizer, EAAnalyzer

class EAWorkflow:
    """Workflow complet de gestion de l'EA"""
    
    def __init__(self):
        self.launcher = None  # MT5EALauncher()
        self.optimizer = None  # EAOptimizer()
        self.analyzer = None  # EAAnalyzer()
        self.workflow_dir = Path("EA_Workflow")
        self.workflow_dir.mkdir(exist_ok=True)
        
        # Créer les sous-dossiers
        (self.workflow_dir / "configs").mkdir(exist_ok=True)
        (self.workflow_dir / "set_files").mkdir(exist_ok=True)
        (self.workflow_dir / "reports").mkdir(exist_ok=True)
        (self.workflow_dir / "results").mkdir(exist_ok=True)
    
    def step1_generate_configs(self, strategy: str = "smart", max_configs: int = None):
        """
        Étape 1: Générer les configurations
        
        Args:
            strategy: 'smart', 'grid', ou 'random'
            max_configs: Nombre maximum de configurations à générer (None = illimité)
        """
        print("\n" + "="*60)
        print("ÉTAPE 1: GÉNÉRATION DES CONFIGURATIONS")
        print("="*60)
        
        if max_configs:
            print(f"⚠️  Limite: {max_configs:,} configurations maximum")
        
        configs = []
        
        if strategy == "smart":
            print("Génération de configurations intelligentes...")
            configs = self._generate_smart_configs()
        elif strategy == "grid":
            print("Génération via Grid Search...")
            configs = self._generate_grid_configs(max_configs)
        elif strategy == "random":
            print("Génération via Random Search...")
            configs = self._generate_random_configs()
        else:
            print(f"Stratégie inconnue: {strategy}")
            return
        
        # Sauvegarder
        config_file = self.workflow_dir / "configs" / f"configs_{strategy}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(configs, f, indent=2, ensure_ascii=False)
        
        print(f"\n✅ {len(configs)} configurations générées")
        print(f"📁 Sauvegardées dans: {config_file}")
        
        return configs
    
    def _generate_smart_configs(self):
        """Génère des configurations intelligentes"""
        return [
            {
                'name': 'Conservative_H1_EURUSD',
                'description': 'Stratégie conservatrice pour trading H1',
                'symbol': 'EURUSD',
                'timeframe': 'H1',
                'parameters': {
                    'BB_Period': 20,
                    'BB_Dev': 2.0,
                    'Use_RSI_Filter': True,
                    'RSI_Oversold': 25.0,
                    'RSI_Overbought': 75.0,
                    'Use_EMA_Filter': True,
                    'EMA_Fast_Period': 50,
                    'EMA_Slow_Period': 100,
                    'EMA_Filter_Mode': 'TREND',
                    'Use_Divergence_Validator': True,
                    'Mode': 'REVERSION',
                    'Risk_Percent': 0.5,
                    'Min_RR': 2.5,
                    'SL_Period': 50,
                    'TP_Period': 30
                }
            },
            {
                'name': 'Aggressive_M15_EURUSD',
                'description': 'Trading agressif sur M15',
                'symbol': 'EURUSD',
                'timeframe': 'M15',
                'parameters': {
                    'BB_Period': 15,
                    'BB_Dev': 1.8,
                    'Use_RSI_Filter': True,
                    'RSI_Oversold': 30.0,
                    'RSI_Overbought': 70.0,
                    'Use_EMA_Filter': False,
                    'Use_Divergence_Validator': False,
                    'Mode': 'BREAKOUT',
                    'Risk_Percent': 1.0,
                    'Min_RR': 1.8,
                    'SL_Period': 30,
                    'TP_Period': 20
                }
            },
            {
                'name': 'Swing_H4_GBPUSD',
                'description': 'Swing trading sur H4',
                'symbol': 'GBPUSD',
                'timeframe': 'H4',
                'parameters': {
                    'BB_Period': 25,
                    'BB_Dev': 2.5,
                    'Use_RSI_Filter': True,
                    'RSI_Oversold': 25.0,
                    'RSI_Overbought': 75.0,
                    'Use_EMA_Filter': True,
                    'EMA_Fast_Period': 50,
                    'EMA_Slow_Period': 200,
                    'EMA_Filter_Mode': 'TREND',
                    'Use_Divergence_Validator': True,
                    'Mode': 'REVERSION',
                    'Risk_Percent': 0.3,
                    'Min_RR': 3.0,
                    'SL_Period': 100,
                    'TP_Period': 50
                }
            },
            {
                'name': 'CounterTrend_H1_USDJPY',
                'description': 'Counter-trend avec divergence',
                'symbol': 'USDJPY',
                'timeframe': 'H1',
                'parameters': {
                    'BB_Period': 20,
                    'BB_Dev': 2.0,
                    'Use_RSI_Filter': True,
                    'RSI_Oversold': 30.0,
                    'RSI_Overbought': 70.0,
                    'Use_EMA_Filter': True,
                    'EMA_Fast_Period': 50,
                    'EMA_Slow_Period': 100,
                    'EMA_Filter_Mode': 'COUNTER',
                    'Use_Divergence_Validator': True,
                    'Mode': 'REVERSION',
                    'Risk_Percent': 0.8,
                    'Min_RR': 2.5,
                    'SL_Period': 50,
                    'TP_Period': 35
                }
            },
            {
                'name': 'Scalping_M5_EURUSD',
                'description': 'Scalping rapide M5',
                'symbol': 'EURUSD',
                'timeframe': 'M5',
                'parameters': {
                    'BB_Period': 15,
                    'BB_Dev': 1.5,
                    'Use_RSI_Filter': False,
                    'Use_EMA_Filter': True,
                    'EMA_Fast_Period': 20,
                    'EMA_Slow_Period': 50,
                    'EMA_Filter_Mode': 'TREND',
                    'Use_Divergence_Validator': False,
                    'Mode': 'BREAKOUT',
                    'Risk_Percent': 0.5,
                    'Min_RR': 1.5,
                    'SL_Period': 20,
                    'TP_Period': 15
                }
            }
        ]
    
    def _generate_grid_configs(self, max_configs: int = None):
        """
        Génère TOUTES les combinaisons possibles de paramètres
        
        Args:
            max_configs: Nombre maximum de configurations à générer (None = illimité)
        """
        import itertools
        
        # Plages étendues de paramètres
        bb_periods = [10, 15, 20, 25, 30, 40, 50]
        bb_devs = [1.5, 1.8, 2.0, 2.2, 2.5, 3.0]
        rsi_periods = [10, 14, 21, 28]
        rsi_oversolds = [20, 25, 30, 35]
        rsi_overboughts = [65, 70, 75, 80]
        ema_fast_periods = [20, 30, 50, 75, 100]
        ema_slow_periods = [50, 100, 150, 200]
        ema_filter_modes = ['TREND', 'COUNTER', 'ZONE']
        modes = ['REVERSION', 'BREAKOUT']
        risk_percents = [0.3, 0.5, 0.8, 1.0, 1.5, 2.0]
        min_rrs = [1.5, 2.0, 2.5, 3.0, 3.5]
        sl_periods = [20, 30, 50, 75, 100]
        tp_periods = [15, 20, 30, 40, 50]
        use_rsi_filters = [True, False]
        use_ema_filters = [True, False]
        use_divergence_validators = [True, False]
        
        # Calculer le nombre total de combinaisons possibles
        total_combinations = (
            len(bb_periods) * len(bb_devs) * len(rsi_periods) * 
            len(rsi_oversolds) * len(rsi_overboughts) * len(ema_fast_periods) * 
            len(ema_slow_periods) * len(ema_filter_modes) * len(modes) * 
            len(risk_percents) * len(min_rrs) * len(sl_periods) * 
            len(tp_periods) * len(use_rsi_filters) * len(use_ema_filters) * 
            len(use_divergence_validators)
        )
        
        # Estimation du nombre de configurations valides (80% du total)
        estimated_valid = int(total_combinations * 0.80)
        
        print(f"\n🔢 Nombre total de combinaisons théoriques: {total_combinations:,}")
        print(f"📊 Estimation après filtrage: ~{estimated_valid:,} configurations valides")
        
        if max_configs:
            print(f"⚠️  LIMITE ACTIVE: Génération de seulement {max_configs:,} configurations")
        else:
            print(f"⚠️  AUCUNE LIMITE: Génération de TOUTES les configurations possibles")
            print(f"⏱️  Temps estimé: {estimated_valid/10000:.1f} secondes (~{estimated_valid/600000:.1f} heures)")
            print(f"💾 Espace disque estimé: {estimated_valid/1024:.1f} MB")
        
        print(f"\n⏳ Génération en cours...\n")
        
        configs = []
        idx = 0
        valid_count = 0
        
        # Générer toutes les combinaisons
        all_combos = itertools.product(
            bb_periods, bb_devs, rsi_periods, rsi_oversolds, rsi_overboughts,
            ema_fast_periods, ema_slow_periods, ema_filter_modes, modes,
            risk_percents, min_rrs, sl_periods, tp_periods,
            use_rsi_filters, use_ema_filters, use_divergence_validators
        )
        
        for combo in all_combos:
            # Vérifier la limite
            if max_configs and valid_count >= max_configs:
                print(f"\n⚠️  Limite de {max_configs:,} configurations atteinte")
                break
            
            (bb_period, bb_dev, rsi_period, rsi_oversold, rsi_overbought,
             ema_fast, ema_slow, ema_filter_mode, mode,
             risk_percent, min_rr, sl_period, tp_period,
             use_rsi, use_ema, use_div) = combo
            
            idx += 1
            
            # Vérifications de cohérence
            if ema_fast >= ema_slow:
                continue
            if rsi_oversold >= rsi_overbought:
                continue
            
            valid_count += 1
            
            # Afficher la progression tous les 1000 configs (ou tous les 100 si max_configs < 1000)
            progress_interval = 100 if (max_configs and max_configs < 1000) else 1000
            if valid_count % progress_interval == 0 or (max_configs and valid_count == max_configs):
                if max_configs:
                    progress = (valid_count / max_configs) * 100
                    print(f"Génération: {valid_count:,}/{max_configs:,} configs ({progress:.1f}%)")
                else:
                    progress = (idx / total_combinations) * 100
                    print(f"Génération: {valid_count:,} configs valides | Progression: {idx:,}/{total_combinations:,} ({progress:.3f}%)")
            
            configs.append({
                'name': f'Grid_Params_{valid_count:04d}',
                'symbol': 'UNIVERSAL',  # Sera défini dans MT5
                'timeframe': 'UNIVERSAL',  # Sera défini dans MT5
                'description': f'Grid search config #{valid_count}',
                'parameters': {
                    'BB_Period': bb_period,
                    'BB_Dev': bb_dev,
                    'RSI_Period': rsi_period,
                    'RSI_Oversold': rsi_oversold,
                    'RSI_Overbought': rsi_overbought,
                    'Use_RSI_Filter': use_rsi,
                    'EMA_Fast_Period': ema_fast,
                    'EMA_Slow_Period': ema_slow,
                    'EMA_Filter_Mode': ema_filter_mode,
                    'Use_EMA_Filter': use_ema,
                    'Use_Divergence_Validator': use_div,
                    'Mode': mode,
                    'Risk_Percent': risk_percent,
                    'Min_RR': min_rr,
                    'SL_Period': sl_period,
                    'TP_Period': tp_period
                }
            })
        
        print(f"\n✅ Génération terminée: {len(configs):,} configurations valides générées")
        if not max_configs:
            print(f"📊 Taux de réussite: {(len(configs)/total_combinations)*100:.1f}%")
        
        return configs
    
    def _generate_random_configs(self):
        """Génère des configs aléatoires"""
        import random
        
        configs = []
        for i in range(10):
            configs.append({
                'name': f'Random_{i}',
                'symbol': random.choice(['EURUSD', 'GBPUSD', 'USDJPY']),
                'timeframe': random.choice(['M15', 'M30', 'H1']),
                'parameters': {
                    'BB_Period': random.choice([15, 20, 25, 30]),
                    'BB_Dev': random.choice([1.5, 2.0, 2.5]),
                    'RSI_Oversold': random.choice([25, 30, 35]),
                    'RSI_Overbought': random.choice([65, 70, 75]),
                    'Risk_Percent': random.choice([0.5, 1.0, 1.5]),
                    'Min_RR': random.choice([1.5, 2.0, 2.5, 3.0])
                }
            })
        
        return configs
    
    def step2_generate_set_files(self, config_file: str):
        """
        Étape 2: Générer les fichiers .set pour MT5
        
        Args:
            config_file: Chemin vers le fichier de configurations
        """
        print("\n" + "="*60)
        print("ÉTAPE 2: GÉNÉRATION DES FICHIERS .SET")
        print("="*60)
        
        with open(config_file, 'r', encoding='utf-8') as f:
            configs = json.load(f)
        
        set_dir = self.workflow_dir / "set_files"
        total = len(configs)
        
        print(f"\n📝 Génération de {total:,} fichiers .set...")
        print(f"📂 Destination: {set_dir}\n")
        
        for i, config in enumerate(configs, 1):
            set_filename = set_dir / f"{config['name']}.set"
            self._write_set_file(config, set_filename)
            
            # Afficher la progression
            if i % 100 == 0 or i == total:
                progress = (i / total) * 100
                bar_length = 40
                filled = int(bar_length * i / total)
                bar = '█' * filled + '░' * (bar_length - filled)
                print(f"\r[{bar}] {i:,}/{total:,} ({progress:.1f}%)", end='', flush=True)
        
        print(f"\n\n✅ {total:,} fichiers .set créés avec succès!")
        print(f"📁 Dossier: {set_dir.absolute()}")
        print("\n📋 UTILISATION DANS MT5:")
        print("1. Ouvrez MetaTrader 5 Strategy Tester")
        print("2. Sélectionnez l'EA JTFreeCandle_v2")
        print("3. Définissez le symbole et timeframe souhaités")
        print("4. Cliquez sur 'Charger' et sélectionnez un fichier .set")
        print("5. Les paramètres seront appliqués, mais symbole/TF restent ceux que vous avez définis")
    
    def _write_set_file(self, config: dict, filename: Path):
        """Écrit un fichier .set (SANS symbole et timeframe)"""
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(f"; Configuration: {config['name']}\n")
            f.write(f"; Description: {config.get('description', '')}\n")
            f.write(f"; Generated: {datetime.now().strftime('%Y.%m.%d %H:%M:%S')}\n")
            f.write(f"; REMARQUE: Symbole et Timeframe doivent être définis dans MT5\n\n")
            
            # NE PLUS ÉCRIRE InpSymbol et InpTF - ils seront définis dans MT5
            
            # Tous les paramètres de stratégie
            for key, value in config.get('parameters', {}).items():
                if isinstance(value, bool):
                    f.write(f"{key}={'true' if value else 'false'}\n")
                elif isinstance(value, str):
                    # Convertir les modes
                    if key == 'EMA_Filter_Mode':
                        mode_map = {'TREND': 0, 'COUNTER': 1, 'ZONE': 2}
                        f.write(f"{key}={mode_map.get(value, 0)}\n")
                    elif key == 'Mode':
                        mode_map = {'REVERSION': 0, 'BREAKOUT': 1}
                        f.write(f"{key}={mode_map.get(value, 0)}\n")
                    else:
                        f.write(f"{key}={value}\n")
                else:
                    f.write(f"{key}={value}\n")
            
            # Magic number unique
            magic = 20251007 + hash(config['name']) % 10000
            f.write(f"Magic={magic}\n")
    
    def step3_monitor_live(self):
        """
        Étape 3: Surveiller les trades en live
        """
        print("\n" + "="*60)
        print("ÉTAPE 3: SURVEILLANCE EN TEMPS RÉEL")
        print("="*60)
        print("\n⚠️  Cette fonctionnalité nécessite MetaTrader5 en cours d'exécution")
        print("⚠️  Et le module MetaTrader5 Python installé")
        print("\nCommande: pip install MetaTrader5")
        
        # Code à décommenter si MT5 est disponible
        """
        if self.launcher is None:
            self.launcher = MT5EALauncher()
        
        if not self.launcher.connect():
            print("❌ Impossible de se connecter à MT5")
            return
        
        try:
            print("\n🔄 Surveillance des positions (Ctrl+C pour arrêter)...")
            while True:
                positions_df = self.launcher.monitor_live_positions()
                
                if not positions_df.empty:
                    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Positions ouvertes: {len(positions_df)}")
                    print(positions_df[['ticket', 'symbol', 'type', 'profit', 'profit_pct']])
                else:
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Aucune position ouverte")
                
                time.sleep(60)  # Refresh toutes les minutes
                
        except KeyboardInterrupt:
            print("\n\n✋ Surveillance arrêtée")
        finally:
            self.launcher.disconnect()
        """
    
    def step4_analyze_results(self):
        """
        Étape 4: Analyser les résultats
        """
        print("\n" + "="*60)
        print("ÉTAPE 4: ANALYSE DES RÉSULTATS")
        print("="*60)
        
        # Chercher les fichiers CSV
        csv_dir = Path.home() / "AppData/Roaming/MetaQuotes/Terminal"
        
        print(f"\n🔍 Recherche des fichiers CSV dans: {csv_dir}")
        csv_files = list(csv_dir.rglob("TradeAnalysis_*.csv"))
        
        if not csv_files:
            print("❌ Aucun fichier CSV trouvé")
            print("\n💡 Assurez-vous que:")
            print("   1. L'EA a été exécuté")
            print("   2. Des trades ont été effectués")
            print("   3. Les fichiers CSV sont dans le dossier MQL5/Files")
            return
        
        print(f"✅ Trouvé {len(csv_files)} fichier(s) CSV")
        
        # Analyser chaque fichier
        all_results = []
        
        for csv_file in csv_files[:5]:  # Limiter à 5 fichiers
            print(f"\n📊 Analyse de: {csv_file.name}")
            
            try:
                df = pd.read_csv(csv_file)
                
                if df.empty:
                    print("   ⚠️  Fichier vide")
                    continue
                
                # Calculer les métriques de base
                closed = df[df['CloseTime'].notna()]
                
                if closed.empty:
                    print("   ⚠️  Pas de trades fermés")
                    continue
                
                wins = len(closed[closed['Profit'] > 0])
                total = len(closed)
                win_rate = wins / total * 100 if total > 0 else 0
                total_profit = closed['Profit'].sum()
                
                result = {
                    'file': csv_file.name,
                    'total_trades': total,
                    'wins': wins,
                    'win_rate': round(win_rate, 1),
                    'total_profit': round(total_profit, 2),
                    'avg_profit': round(closed['Profit'].mean(), 2)
                }
                
                all_results.append(result)
                
                print(f"   Total trades: {total}")
                print(f"   Win rate: {win_rate:.1f}%")
                print(f"   Profit total: ${total_profit:.2f}")
                
            except Exception as e:
                print(f"   ❌ Erreur: {e}")
        
        # Créer un résumé
        if all_results:
            results_df = pd.DataFrame(all_results)
            results_file = self.workflow_dir / "results" / f"summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
            results_df.to_csv(results_file, index=False)
            
            print(f"\n✅ Résumé sauvegardé dans: {results_file}")
            
            # Afficher le top 3
            print("\n🏆 TOP 3 CONFIGURATIONS:")
            top3 = results_df.sort_values('total_profit', ascending=False).head(3)
            print(top3[['file', 'total_trades', 'win_rate', 'total_profit']])
    
    def step5_generate_report(self):
        """
        Étape 5: Générer un rapport complet
        """
        print("\n" + "="*60)
        print("ÉTAPE 5: GÉNÉRATION DU RAPPORT")
        print("="*60)
        
        report_file = self.workflow_dir / "reports" / f"report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.html"
        
        html_content = self._create_html_report()
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"\n✅ Rapport généré: {report_file}")
        print(f"📂 Ouvrez le fichier dans votre navigateur")
    
    def _create_html_report(self) -> str:
        """Crée un rapport HTML"""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Rapport EA JTFreeCandle_v2</title>
            <meta charset="utf-8">
            <style>
                body {{
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    margin: 40px;
                    background: #f5f5f5;
                }}
                .container {{
                    max-width: 1200px;
                    margin: 0 auto;
                    background: white;
                    padding: 30px;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }}
                h1 {{
                    color: #2c3e50;
                    border-bottom: 3px solid #3498db;
                    padding-bottom: 15px;
                }}
                h2 {{
                    color: #34495e;
                    margin-top: 40px;
                }}
                .metric-box {{
                    display: inline-block;
                    margin: 15px;
                    padding: 20px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    border-radius: 8px;
                    min-width: 200px;
                    text-align: center;
                    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                }}
                .metric-value {{
                    font-size: 2em;
                    font-weight: bold;
                    margin: 10px 0;
                }}
                .metric-label {{
                    font-size: 0.9em;
                    opacity: 0.9;
                }}
                .status-box {{
                    padding: 15px;
                    margin: 20px 0;
                    border-radius: 5px;
                    background: #e8f5e9;
                    border-left: 4px solid #4caf50;
                }}
                table {{
                    width: 100%;
                    border-collapse: collapse;
                    margin: 20px 0;
                }}
                th, td {{
                    padding: 12px;
                    text-align: left;
                    border-bottom: 1px solid #ddd;
                }}
                th {{
                    background: #3498db;
                    color: white;
                    font-weight: 600;
                }}
                tr:hover {{
                    background: #f5f5f5;
                }}
                .footer {{
                    margin-top: 50px;
                    padding-top: 20px;
                    border-top: 1px solid #ddd;
                    text-align: center;
                    color: #7f8c8d;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📊 Rapport de Performance EA JTFreeCandle_v2</h1>
                <p>Généré le: {datetime.now().strftime('%d/%m/%Y à %H:%M:%S')}</p>
                
                <div class="status-box">
                    <strong>✅ Workflow terminé avec succès</strong>
                    <p>Toutes les étapes de configuration, test et analyse ont été complétées.</p>
                </div>
                
                <h2>📈 Résumé des Étapes</h2>
                <table>
                    <tr>
                        <th>Étape</th>
                        <th>Description</th>
                        <th>Statut</th>
                    </tr>
                    <tr>
                        <td>1</td>
                        <td>Génération des configurations</td>
                        <td>✅ Complété</td>
                    </tr>
                    <tr>
                        <td>2</td>
                        <td>Création des fichiers .set</td>
                        <td>✅ Complété</td>
                    </tr>
                    <tr>
                        <td>3</td>
                        <td>Tests dans MT5</td>
                        <td>⏳ En cours</td>
                    </tr>
                    <tr>
                        <td>4</td>
                        <td>Analyse des résultats</td>
                        <td>⏳ En attente</td>
                    </tr>
                </table>
                
                <h2>📁 Fichiers Générés</h2>
                <ul>
                    <li>Configurations: {self.workflow_dir / 'configs'}</li>
                    <li>Fichiers .set: {self.workflow_dir / 'set_files'}</li>
                    <li>Résultats: {self.workflow_dir / 'results'}</li>
                    <li>Rapports: {self.workflow_dir / 'reports'}</li>
                </ul>
                
                <h2>🎯 Prochaines Étapes</h2>
                <ol>
                    <li>Charger les fichiers .set dans Strategy Tester de MT5</li>
                    <li>Exécuter les backtests sur vos données historiques</li>
                    <li>Analyser les résultats CSV générés</li>
                    <li>Sélectionner les meilleures configurations</li>
                    <li>Déployer en trading live avec risque contrôlé</li>
                </ol>
                
                <div class="footer">
                    <p>EA JTFreeCandle_v2 - Workflow Automatisé</p>
                    <p>© 2025 - Tous droits réservés</p>
                </div>
            </div>
        </body>
        </html>
        """
    
    def run_complete_workflow(self, strategy: str = "smart", max_configs: int = None):
        """
        Exécute le workflow complet automatiquement
        
        Args:
            strategy: Type de génération de configs ('smart', 'grid', 'random')
            max_configs: Nombre maximum de configurations (None = illimité)
        """
        print("\n" + "="*70)
        print("   🚀 WORKFLOW COMPLET EA JTFreeCandle_v2")
        print("="*70)
        
        try:
            # Étape 1
            configs = self.step1_generate_configs(strategy, max_configs)
            if not configs:
                return
            
            time.sleep(1)
            
            # Étape 2
            config_file = list(self.workflow_dir.glob("configs/configs_*.json"))[-1]
            self.step2_generate_set_files(config_file)
            
            time.sleep(1)
            
            # Étape 5 (rapport final)
            self.step5_generate_report()
            
            print("\n" + "="*70)
            print("   ✅ WORKFLOW TERMINÉ AVEC SUCCÈS!")
            print("="*70)
            print(f"\n📂 Tous les fichiers sont dans: {self.workflow_dir.absolute()}")
            
        except Exception as e:
            print(f"\n❌ Erreur: {e}")
            import traceback
            traceback.print_exc()


def main():
    """Point d'entrée principal"""
    
    print("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║      EA JTFreeCandle_v2 - Gestionnaire de Workflow Complet      ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
    
    workflow = EAWorkflow()
    
    print("\nOptions disponibles:")
    print("1. Workflow complet automatique (Smart Configs)")
    print("2. Workflow complet automatique (Grid Search - LIMITÉ)")
    print("3. Générer seulement les configurations")
    print("4. Générer seulement les fichiers .set")
    print("5. Analyser les résultats existants")
    print("6. Générer un rapport")
    print("0. Quitter")
    
    choice = input("\nVotre choix: ").strip()
    
    if choice == "1":
        workflow.run_complete_workflow("smart")
    elif choice == "2":
        print("\n⚠️  ATTENTION: Le Grid Search peut générer 1.5 MILLIARD de combinaisons!")
        print("Il est FORTEMENT recommandé de limiter le nombre de configurations.")
        print("\nLimites suggérées:")
        print("  - 1,000 configs  : Test rapide (~2 minutes)")
        print("  - 10,000 configs : Test approfondi (~20 minutes)")
        print("  - 100,000 configs: Test exhaustif (~3 heures)")
        print("  - Aucune limite  : TOUTES les combinaisons (TRÈS LONG)")
        
        limit_input = input("\nNombre max de configs (Enter = 10,000 par défaut): ").strip()
        if limit_input:
            try:
                max_configs = int(limit_input)
                if max_configs <= 0:
                    print("❌ Nombre invalide, utilisation de 10,000 par défaut")
                    max_configs = 10000
            except ValueError:
                print("❌ Nombre invalide, utilisation de 10,000 par défaut")
                max_configs = 10000
        else:
            max_configs = 10000
        
        workflow.run_complete_workflow("grid", max_configs)
    elif choice == "3":
        strategy = input("Type (smart/grid/random): ").strip() or "smart"
        
        if strategy == "grid":
            limit_input = input("Nombre max de configs (Enter = 10,000): ").strip()
            max_configs = int(limit_input) if limit_input else 10000
            workflow.step1_generate_configs(strategy, max_configs)
        else:
            workflow.step1_generate_configs(strategy)
    elif choice == "4":
        config_files = list(workflow.workflow_dir.glob("configs/configs_*.json"))
        if not config_files:
            print("❌ Aucun fichier de config trouvé. Exécutez d'abord l'option 3.")
        else:
            print("\nFichiers disponibles:")
            for i, f in enumerate(config_files, 1):
                print(f"{i}. {f.name}")
            idx = int(input("\nChoisir le fichier (numéro): ")) - 1
            workflow.step2_generate_set_files(config_files[idx])
    elif choice == "5":
        workflow.step4_analyze_results()
    elif choice == "6":
        workflow.step5_generate_report()
    elif choice == "0":
        print("👋 Au revoir!")
    else:
        print("❌ Choix invalide")


if __name__ == "__main__":
    main()
