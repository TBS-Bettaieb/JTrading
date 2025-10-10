"""
Test de Cohérence MQL5 vs Python
Compare les signaux générés par l'EA MQL5 avec la version Python
"""
import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
from typing import List, Dict
import sys

from strategies import FreeCandleStrategy
from config import StrategyConfig
from data import DataManager


class MQL5ConsistencyTester:
    """
    Teste la cohérence entre les signaux MQL5 et Python
    """
    
    def __init__(self, mql5_log_file: str = None):
        """
        Args:
            mql5_log_file: Fichier de log MQL5 avec les signaux
        """
        self.mql5_log_file = mql5_log_file
        self.differences = []
    
    def load_mql5_signals(self, log_file: str) -> pd.DataFrame:
        """
        Charge les signaux depuis un log MQL5
        
        Format attendu (CSV):
        SIGNAL|2023-01-05 10:00|EURUSD|1|1.05000|1.04500|1.06500|45.2|0.0015|0.0020
        
        Colonnes:
        type, timestamp, symbol, direction, entry, sl, tp, rsi, atr, bb_width
        """
        try:
            df = pd.read_csv(
                log_file, 
                sep='|',
                names=['type', 'timestamp', 'symbol', 'direction', 
                       'entry', 'sl', 'tp', 'rsi', 'atr', 'bb_width'],
                parse_dates=['timestamp']
            )
            
            # Filtrer seulement les lignes SIGNAL
            df = df[df['type'] == 'SIGNAL']
            
            print(f"✅ {len(df)} signaux MQL5 chargés depuis {log_file}")
            return df
            
        except FileNotFoundError:
            print(f"❌ Fichier non trouvé: {log_file}")
            print("\n💡 Pour créer ce fichier depuis MQL5:")
            print("   1. Ajouter dans OnInit():")
            print("      log_handle = FileOpen('signals.csv', FILE_WRITE|FILE_CSV);")
            print("   2. À chaque signal dans CheckEntry():")
            print("      string log = StringFormat('SIGNAL|%s|%s|%d|%.5f|%.5f|%.5f|%.2f|%.5f|%.5f',")
            print("                                TimeToString(...), _Symbol, direction,")
            print("                                entry, sl, tp, rsi, atr, bb_width);")
            print("      FileWrite(log_handle, log);")
            print("   3. Copier le fichier depuis MT5/MQL5/Files/")
            return None
    
    def compare_signals(
        self, 
        python_signals: List, 
        mql5_df: pd.DataFrame,
        tolerance: float = 0.00001
    ) -> Dict:
        """
        Compare les signaux Python avec MQL5
        
        Args:
            python_signals: Liste de Signal objects
            mql5_df: DataFrame avec signaux MQL5
            tolerance: Tolérance pour comparaison de prix
        
        Returns:
            Dict avec statistiques de comparaison
        """
        results = {
            'total_python': len(python_signals),
            'total_mql5': len(mql5_df),
            'matches': 0,
            'timestamp_diff': 0,
            'direction_diff': 0,
            'entry_diff': 0,
            'sl_diff': 0,
            'tp_diff': 0,
            'differences': []
        }
        
        # Créer un dict des signaux MQL5 par timestamp
        mql5_by_time = {}
        for _, row in mql5_df.iterrows():
            key = row['timestamp'].strftime('%Y-%m-%d %H:%M:%S')
            mql5_by_time[key] = row
        
        # Comparer chaque signal Python
        for i, py_signal in enumerate(python_signals):
            key = py_signal.timestamp.strftime('%Y-%m-%d %H:%M:%S')
            
            if key not in mql5_by_time:
                results['timestamp_diff'] += 1
                results['differences'].append({
                    'type': 'MISSING_IN_MQL5',
                    'timestamp': key,
                    'python': py_signal
                })
                continue
            
            mql5_signal = mql5_by_time[key]
            diff = {}
            
            # Comparer direction
            if py_signal.direction != mql5_signal['direction']:
                results['direction_diff'] += 1
                diff['direction'] = {
                    'python': py_signal.direction,
                    'mql5': mql5_signal['direction']
                }
            
            # Comparer entry price
            if abs(py_signal.entry_price - mql5_signal['entry']) > tolerance:
                results['entry_diff'] += 1
                diff['entry'] = {
                    'python': py_signal.entry_price,
                    'mql5': mql5_signal['entry'],
                    'diff': abs(py_signal.entry_price - mql5_signal['entry'])
                }
            
            # Comparer SL
            if abs(py_signal.sl_price - mql5_signal['sl']) > tolerance:
                results['sl_diff'] += 1
                diff['sl'] = {
                    'python': py_signal.sl_price,
                    'mql5': mql5_signal['sl'],
                    'diff': abs(py_signal.sl_price - mql5_signal['sl'])
                }
            
            # Comparer TP
            if abs(py_signal.tp_price - mql5_signal['tp']) > tolerance:
                results['tp_diff'] += 1
                diff['tp'] = {
                    'python': py_signal.tp_price,
                    'mql5': mql5_signal['tp'],
                    'diff': abs(py_signal.tp_price - mql5_signal['tp'])
                }
            
            if diff:
                diff['timestamp'] = key
                results['differences'].append(diff)
            else:
                results['matches'] += 1
        
        # Signaux MQL5 manquants en Python
        python_times = {s.timestamp.strftime('%Y-%m-%d %H:%M:%S') for s in python_signals}
        for key in mql5_by_time.keys():
            if key not in python_times:
                results['timestamp_diff'] += 1
                results['differences'].append({
                    'type': 'MISSING_IN_PYTHON',
                    'timestamp': key,
                    'mql5': mql5_by_time[key]
                })
        
        return results
    
    def display_comparison_report(self, results: Dict):
        """Affiche un rapport de comparaison"""
        print("\n" + "=" * 70)
        print("📊 RAPPORT DE COHÉRENCE MQL5 vs PYTHON")
        print("=" * 70)
        
        print(f"\n📈 Statistiques globales:")
        print(f"   Signaux Python: {results['total_python']}")
        print(f"   Signaux MQL5: {results['total_mql5']}")
        print(f"   Matches parfaits: {results['matches']}")
        
        total_diffs = results['timestamp_diff'] + results['direction_diff'] + \
                     results['entry_diff'] + results['sl_diff'] + results['tp_diff']
        
        if total_diffs == 0:
            print(f"\n✅ 100% COHÉRENT - Aucune différence détectée!")
            return
        
        print(f"\n⚠️  Différences détectées: {len(results['differences'])}")
        print(f"   Timestamps différents: {results['timestamp_diff']}")
        print(f"   Directions différentes: {results['direction_diff']}")
        print(f"   Entry prices différents: {results['entry_diff']}")
        print(f"   SL différents: {results['sl_diff']}")
        print(f"   TP différents: {results['tp_diff']}")
        
        # Afficher les premières différences
        print(f"\n🔍 Exemples de différences (5 premières):")
        for i, diff in enumerate(results['differences'][:5]):
            print(f"\n{i+1}. Timestamp: {diff.get('timestamp', 'N/A')}")
            if 'type' in diff:
                print(f"   Type: {diff['type']}")
            for key in ['direction', 'entry', 'sl', 'tp']:
                if key in diff:
                    print(f"   {key.upper()}: Python={diff[key]['python']:.5f}, "
                          f"MQL5={diff[key]['mql5']:.5f}, "
                          f"Diff={diff[key].get('diff', 0):.5f}")
        
        # Calcul du taux de cohérence
        if results['total_python'] > 0:
            coherence_rate = (results['matches'] / results['total_python']) * 100
            print(f"\n📊 Taux de cohérence: {coherence_rate:.1f}%")
            
            if coherence_rate < 90:
                print(f"\n❌ ALERTE: Cohérence < 90% - Vérification nécessaire!")
            elif coherence_rate < 95:
                print(f"\n⚠️  ATTENTION: Cohérence < 95% - Différences mineures")
            else:
                print(f"\n✅ EXCELLENT: Cohérence > 95%")
    
    def run_consistency_test(
        self, 
        symbol: str = "EURUSD", 
        timeframe: str = "H1",
        start_date: str = "2023-01-01",
        end_date: str = "2023-12-31"
    ):
        """
        Exécute le test de cohérence complet
        """
        print("\n" + "=" * 70)
        print("🔬 TEST DE COHÉRENCE MQL5 vs PYTHON")
        print("=" * 70)
        print(f"\nSymbole: {symbol}")
        print(f"Timeframe: {timeframe}")
        print(f"Période: {start_date} → {end_date}")
        
        # 1. Charger les données
        print("\n📊 Chargement des données...")
        data_manager = DataManager()
        df = data_manager.load_from_cache(symbol, timeframe)
        
        if df is None:
            print(f"❌ Pas de données en cache pour {symbol} {timeframe}")
            return None
        
        # Filtrer par période
        df = df[(df.index >= start_date) & (df.index < end_date)]
        print(f"✅ {len(df)} barres chargées")
        
        # 2. Générer signaux Python
        print("\n🎯 Génération des signaux Python...")
        config = StrategyConfig()
        config.symbol.symbol = symbol
        config.symbol.timeframe = timeframe
        
        strategy = FreeCandleStrategy(config)
        python_signals = strategy.generate_signals(df)
        print(f"✅ {len(python_signals)} signaux Python générés")
        
        # 3. Charger signaux MQL5
        if self.mql5_log_file:
            print(f"\n📂 Chargement des signaux MQL5...")
            mql5_df = self.load_mql5_signals(self.mql5_log_file)
            
            if mql5_df is not None:
                # 4. Comparer
                print(f"\n🔬 Comparaison des signaux...")
                results = self.compare_signals(python_signals, mql5_df)
                
                # 5. Afficher rapport
                self.display_comparison_report(results)
                
                return results
        else:
            print("\n⚠️  Pas de fichier log MQL5 fourni")
            print("   Impossible de comparer avec MQL5")
            print(f"\n   Signaux Python générés: {len(python_signals)}")
            
            # Afficher quelques signaux Python pour référence
            if python_signals:
                print(f"\n📈 Exemples de signaux Python (3 premiers):")
                for i, sig in enumerate(python_signals[:3]):
                    direction_str = "BUY" if sig.direction == 1 else "SELL"
                    print(f"   {i+1}. {sig.timestamp} | {direction_str} | "
                          f"Entry: {sig.entry_price:.5f} | SL: {sig.sl_price:.5f} | "
                          f"TP: {sig.tp_price:.5f}")
        
        return None


def main():
    """Point d'entrée principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Test de cohérence MQL5 vs Python')
    parser.add_argument('--symbol', type=str, default='EURUSD', help='Symbole')
    parser.add_argument('--timeframe', type=str, default='H1', help='Timeframe')
    parser.add_argument('--start-date', type=str, default='2023-01-01', help='Date début')
    parser.add_argument('--end-date', type=str, default='2023-12-31', help='Date fin')
    parser.add_argument('--mql5-log', type=str, help='Fichier log MQL5 (optionnel)')
    
    args = parser.parse_args()
    
    # Créer le testeur
    tester = MQL5ConsistencyTester(mql5_log_file=args.mql5_log)
    
    # Exécuter le test
    results = tester.run_consistency_test(
        symbol=args.symbol,
        timeframe=args.timeframe,
        start_date=args.start_date,
        end_date=args.end_date
    )
    
    if results and results['matches'] == results['total_python']:
        print("\n" + "=" * 70)
        print("🎉 TEST RÉUSSI - 100% de cohérence !")
        print("=" * 70)
        sys.exit(0)
    elif results:
        print("\n" + "=" * 70)
        print("⚠️  TEST ÉCHOUÉ - Différences détectées")
        print("=" * 70)
        sys.exit(1)
    else:
        print("\n" + "=" * 70)
        print("⚠️  TEST INCOMPLET - Log MQL5 manquant")
        print("=" * 70)
        sys.exit(2)


if __name__ == "__main__":
    main()

