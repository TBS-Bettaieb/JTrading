# ⚡ Guide d'Utilisation - ea_optimizer.py

## 📋 Vue d'Ensemble

**`ea_optimizer.py`** est un optimiseur et analyseur avancé pour l'EA JTFreeCandle_v2. Il permet de:

- ✅ **Générer des configurations optimales** (Smart, Grid Search, Random Search)
- ✅ **Analyser les performances** avec métriques détaillées
- ✅ **Visualiser les résultats** (courbes d'équité, graphiques)
- ✅ **Créer des rapports HTML** professionnels
- ✅ **Optimiser les paramètres** automatiquement

---

## 🚀 Démarrage Rapide

### Utilisation Basique

```python
from ea_optimizer import EAOptimizer, EAAnalyzer

# 1. Optimisation
optimizer = EAOptimizer()
configs = optimizer.generate_smart_configs("EURUSD")

# 2. Analyse
analyzer = EAAnalyzer()
trades_df = analyzer.load_trades("EURUSD")
metrics = analyzer.calculate_metrics()

print(f"Win Rate: {metrics['win_rate']:.1f}%")
print(f"Profit Factor: {metrics['profit_factor']:.2f}")
```

---

## 🏗️ Classe EAOptimizer

### Initialisation

```python
from ea_optimizer import EAOptimizer

optimizer = EAOptimizer()
```

### Définir l'Espace de Paramètres

```python
optimizer.define_parameter_space()

# Espace défini par défaut:
# - bb_period: [15, 20, 25, 30]
# - bb_deviation: [1.5, 2.0, 2.5, 3.0]
# - rsi_period: [10, 14, 21]
# - rsi_oversold: [25, 30, 35]
# - rsi_overbought: [65, 70, 75]
# - ema_fast: [20, 50, 100]
# - ema_slow: [50, 100, 200]
# - entry_mode: ['REVERSION', 'BREAKOUT']
# - risk_percent: [0.5, 1.0, 1.5, 2.0]
# - min_rr: [1.5, 2.0, 2.5, 3.0]
```

### Méthodes de Génération

#### 1. Smart Configs (Recommandé)

Configurations intelligentes basées sur les meilleures pratiques.

```python
configs = optimizer.generate_smart_configs(
    symbol="EURUSD",
    timeframe="H1"
)

print(f"Généré {len(configs)} configurations intelligentes")
# 5 configurations pré-optimisées
```

**Configurations Générées**:
1. **Scalping_Aggressive** - M5, breakout rapide
2. **DayTrading_Balanced** - M15, équilibré
3. **Swing_Conservative** - H1, conservateur
4. **CounterTrend_Divergence** - H4, divergence
5. **Breakout_Momentum** - H1, momentum

#### 2. Grid Search

Exploration systématique de l'espace des paramètres.

```python
configs = optimizer.generate_grid_search_configs(
    symbol="EURUSD",
    timeframe="H1",
    max_configs=100  # Limite le nombre
)

print(f"Généré {len(configs)} configurations valides")
```

**Caractéristiques**:
- Explore toutes les combinaisons possibles
- Filtre les configurations invalides
- Peut générer des milliers de configs

#### 3. Random Search

Recherche aléatoire pour découvrir de nouvelles combinaisons.

```python
configs = optimizer.generate_random_search_configs(
    symbol="EURUSD",
    timeframe="H1",
    n_configs=50  # Nombre de configs
)
```

**Avantages**:
- Rapide
- Explore des zones inattendues
- Bon pour l'exploration initiale

### Sauvegarder les Configurations

```python
import pandas as pd

configs_df = pd.DataFrame(configs)
configs_df.to_csv('optimized_configs.csv', index=False)
```

---

## 📊 Classe EAAnalyzer

### Initialisation

```python
from ea_optimizer import EAAnalyzer

# Avec répertoire par défaut
analyzer = EAAnalyzer()

# Avec répertoire personnalisé
analyzer = EAAnalyzer(csv_dir="C:/Custom/Path/MT5/Files")
```

### Charger les Trades

```python
# Charger tous les trades d'un symbole
trades_df = analyzer.load_trades("EURUSD")

# Avec timeframe spécifique
trades_df = analyzer.load_trades("EURUSD", timeframe="H1")

print(f"Chargé {len(trades_df)} trades")
```

### Calculer les Métriques

```python
metrics = analyzer.calculate_metrics()

# Métriques disponibles:
print(f"Total trades: {metrics['total_trades']}")
print(f"Winning trades: {metrics['winning_trades']}")
print(f"Losing trades: {metrics['losing_trades']}")
print(f"Win rate: {metrics['win_rate']:.1f}%")
print(f"Total profit: ${metrics['total_profit']:.2f}")
print(f"Gross profit: ${metrics['gross_profit']:.2f}")
print(f"Gross loss: ${metrics['gross_loss']:.2f}")
print(f"Profit factor: {metrics['profit_factor']:.2f}")
print(f"Sharpe ratio: {metrics['sharpe_ratio']:.2f}")
print(f"Max drawdown: ${metrics['max_drawdown']:.2f}")
print(f"Avg win: ${metrics['avg_win']:.2f}")
print(f"Avg loss: ${metrics['avg_loss']:.2f}")
print(f"Best trade: ${metrics['best_trade']:.2f}")
print(f"Worst trade: ${metrics['worst_trade']:.2f}")
print(f"Max consecutive wins: {metrics['max_consecutive_wins']}")
print(f"Max consecutive losses: {metrics['max_consecutive_losses']}")
```

### Analyser par Heure

```python
hourly_analysis = analyzer.analyze_by_hour()

print("\nPerformance par Heure:")
print(hourly_analysis)

# Colonnes:
# - Trades: Nombre de trades
# - Total_Profit: Profit total
# - Avg_Profit: Profit moyen
# - Avg_RR: Risk/Reward moyen
# - Win_Rate: Taux de réussite
```

**Exemple de Sortie**:
```
Hour | Trades | Total_Profit | Avg_Profit | Avg_RR | Win_Rate
-----|--------|--------------|------------|--------|----------
  8  |   25   |    450.50    |   18.02    |  2.35  |  64.0%
  9  |   32   |    382.75    |   11.96    |  2.12  |  56.3%
 10  |   28   |    315.20    |   11.26    |  2.08  |  57.1%
```

### Analyser par Jour

```python
daily_analysis = analyzer.analyze_by_day()

print("\nPerformance par Jour de la Semaine:")
print(daily_analysis)

# Colonnes similaires + Day_Name
```

**Exemple de Sortie**:
```
Day | Day_Name | Trades | Total_Profit | Win_Rate
----|----------|--------|--------------|----------
 1  | Lundi    |   42   |    625.30    |  59.5%
 2  | Mardi    |   38   |    548.75    |  57.9%
 3  | Mercredi |   35   |    412.50    |  54.3%
```

### Visualiser la Courbe d'Équité

```python
# Afficher à l'écran
analyzer.plot_equity_curve()

# Sauvegarder dans un fichier
analyzer.plot_equity_curve(save_path='equity_curve.png')
```

### Créer un Rapport HTML

```python
analyzer.create_performance_report("rapport_performance.html")

print("✅ Rapport créé: rapport_performance.html")
```

**Contenu du Rapport**:
- Métriques principales
- Performance par heure
- Performance par jour
- Graphiques et visualisations

---

## 💡 Exemples Complets

### Exemple 1: Workflow Complet d'Optimisation

```python
from ea_optimizer import EAOptimizer, EAAnalyzer
import pandas as pd

# ===== ÉTAPE 1: GÉNÉRER DES CONFIGURATIONS =====
print("="*60)
print("ÉTAPE 1: GÉNÉRATION DES CONFIGURATIONS")
print("="*60)

optimizer = EAOptimizer()

# Générer 3 types de configurations
smart_configs = optimizer.generate_smart_configs("EURUSD")
grid_configs = optimizer.generate_grid_search_configs("EURUSD", max_configs=20)
random_configs = optimizer.generate_random_search_configs("EURUSD", n_configs=10)

all_configs = smart_configs + grid_configs + random_configs

print(f"\n✅ {len(all_configs)} configurations générées:")
print(f"  - Smart: {len(smart_configs)}")
print(f"  - Grid: {len(grid_configs)}")
print(f"  - Random: {len(random_configs)}")

# Sauvegarder
configs_df = pd.DataFrame(all_configs)
configs_df.to_csv('all_configs.csv', index=False)

# ===== ÉTAPE 2: ANALYSER LES RÉSULTATS =====
print("\n" + "="*60)
print("ÉTAPE 2: ANALYSE DES RÉSULTATS")
print("="*60)

analyzer = EAAnalyzer()
trades_df = analyzer.load_trades("EURUSD")

if not trades_df.empty:
    # Métriques globales
    metrics = analyzer.calculate_metrics()
    
    print(f"\n📊 MÉTRIQUES GLOBALES:")
    print(f"  Total trades: {metrics['total_trades']}")
    print(f"  Win rate: {metrics['win_rate']:.1f}%")
    print(f"  Profit total: ${metrics['total_profit']:.2f}")
    print(f"  Profit factor: {metrics['profit_factor']:.2f}")
    print(f"  Sharpe ratio: {metrics['sharpe_ratio']:.2f}")
    print(f"  Max drawdown: ${metrics['max_drawdown']:.2f}")
    
    # Top heures
    hourly = analyzer.analyze_by_hour()
    print(f"\n⏰ TOP 3 HEURES:")
    print(hourly.head(3)[['Trades', 'Total_Profit', 'Win_Rate']])
    
    # Top jours
    daily = analyzer.analyze_by_day()
    print(f"\n📅 TOP 3 JOURS:")
    print(daily.head(3)[['Day_Name', 'Trades', 'Total_Profit', 'Win_Rate']])
    
    # Courbe d'équité
    analyzer.plot_equity_curve(save_path='equity_curve.png')
    print("\n✅ Courbe d'équité sauvegardée: equity_curve.png")
    
    # Rapport HTML
    analyzer.create_performance_report('rapport_final.html')
    print("✅ Rapport HTML créé: rapport_final.html")
else:
    print("❌ Aucun trade trouvé")

print("\n" + "="*60)
print("WORKFLOW TERMINÉ")
print("="*60)
```

### Exemple 2: Comparaison de Stratégies

```python
from ea_optimizer import EAOptimizer, EAAnalyzer
import pandas as pd

optimizer = EAOptimizer()

# Générer différentes stratégies
strategies = {
    'Smart': optimizer.generate_smart_configs("EURUSD"),
    'Grid': optimizer.generate_grid_search_configs("EURUSD", max_configs=10),
    'Random': optimizer.generate_random_search_configs("EURUSD", n_configs=10)
}

# Analyser chaque stratégie
results = []

analyzer = EAAnalyzer()

for strategy_name, configs in strategies.items():
    print(f"\n{'='*60}")
    print(f"Analyse de: {strategy_name}")
    print(f"{'='*60}")
    
    # Sauvegarder les configs
    df_configs = pd.DataFrame(configs)
    df_configs.to_csv(f'configs_{strategy_name}.csv', index=False)
    
    # Analyser (si résultats disponibles)
    trades_df = analyzer.load_trades("EURUSD")
    
    if not trades_df.empty:
        metrics = analyzer.calculate_metrics()
        
        results.append({
            'Strategy': strategy_name,
            'Configs': len(configs),
            'Total_Trades': metrics.get('total_trades', 0),
            'Win_Rate': metrics.get('win_rate', 0),
            'Total_Profit': metrics.get('total_profit', 0),
            'Profit_Factor': metrics.get('profit_factor', 0),
            'Sharpe_Ratio': metrics.get('sharpe_ratio', 0)
        })

# Comparaison finale
if results:
    comparison_df = pd.DataFrame(results)
    comparison_df = comparison_df.sort_values('Total_Profit', ascending=False)
    
    print(f"\n{'='*60}")
    print("COMPARAISON FINALE")
    print(f"{'='*60}\n")
    print(comparison_df)
    
    # Sauvegarder
    comparison_df.to_csv('comparison_strategies.csv', index=False)
    print("\n✅ Comparaison sauvegardée: comparison_strategies.csv")
```

### Exemple 3: Optimisation Multi-Symboles

```python
from ea_optimizer import EAOptimizer, EAAnalyzer
import pandas as pd

optimizer = EAOptimizer()

symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD']
all_results = []

for symbol in symbols:
    print(f"\n{'='*60}")
    print(f"Optimisation pour: {symbol}")
    print(f"{'='*60}")
    
    # Générer configs smart
    configs = optimizer.generate_smart_configs(symbol)
    
    # Sauvegarder
    pd.DataFrame(configs).to_csv(f'configs_{symbol}.csv', index=False)
    
    # Analyser
    analyzer = EAAnalyzer()
    trades_df = analyzer.load_trades(symbol)
    
    if not trades_df.empty:
        metrics = analyzer.calculate_metrics()
        
        result = {
            'Symbol': symbol,
            'Configs': len(configs),
            **metrics
        }
        all_results.append(result)
        
        print(f"  Total trades: {metrics['total_trades']}")
        print(f"  Win rate: {metrics['win_rate']:.1f}%")
        print(f"  Profit total: ${metrics['total_profit']:.2f}")

# Résumé multi-symboles
if all_results:
    summary_df = pd.DataFrame(all_results)
    summary_df = summary_df.sort_values('total_profit', ascending=False)
    
    print(f"\n{'='*60}")
    print("RÉSUMÉ MULTI-SYMBOLES")
    print(f"{'='*60}\n")
    print(summary_df[['Symbol', 'total_trades', 'win_rate', 'total_profit', 'profit_factor']])
    
    summary_df.to_csv('summary_multi_symbols.csv', index=False)
    print("\n✅ Résumé sauvegardé: summary_multi_symbols.csv")
```

---

## 🎯 Personnalisation

### Modifier l'Espace de Paramètres

```python
optimizer = EAOptimizer()

# Personnaliser les plages
optimizer.parameter_ranges = {
    'bb_period': [10, 15, 20, 25, 30, 35],  # Plus de valeurs
    'bb_deviation': [1.0, 1.5, 2.0, 2.5, 3.0],
    'rsi_period': [7, 10, 14, 21, 28],
    'risk_percent': [0.1, 0.5, 1.0, 1.5, 2.0, 2.5],  # Nouveau: 0.1% et 2.5%
    # ... autres paramètres
}

# Compter les combinaisons
count = optimizer._count_combinations()
print(f"Nombre total de combinaisons: {count:,}")
```

### Ajouter des Configurations Smart

```python
# Éditer ea_optimizer.py
def generate_smart_configs(self, symbol, timeframe):
    configs = [
        # Configurations par défaut...
        
        # NOUVELLE configuration
        {
            'name': 'MyCustom_Strategy',
            'symbol': symbol,
            'timeframe': timeframe,
            'bb_period': 22,
            'bb_deviation': 2.2,
            'use_rsi_filter': True,
            'rsi_period': 16,
            'rsi_oversold': 28,
            'rsi_overbought': 72,
            'entry_mode': 'REVERSION',
            'risk_percent': 0.75,
            'min_rr': 2.8
        }
    ]
    return configs
```

---

## 📈 Métriques Expliquées

### Win Rate
Pourcentage de trades gagnants.
- **Bon**: > 50%
- **Excellent**: > 60%

### Profit Factor
Ratio profit brut / perte brute.
- **Minimum**: > 1.0
- **Bon**: > 1.5
- **Excellent**: > 2.0

### Sharpe Ratio
Mesure du rendement ajusté au risque.
- **Bon**: > 1.0
- **Très bon**: > 2.0
- **Excellent**: > 3.0

### Max Drawdown
Perte maximale depuis un pic.
- **Acceptable**: < 20%
- **Bon**: < 15%
- **Excellent**: < 10%

---

## 🔧 Troubleshooting

### Problème: Pas de données chargées

**Vérification**:
```python
analyzer = EAAnalyzer()
print(f"CSV Dir: {analyzer.csv_dir}")

import os
print(f"Dir exists: {os.path.exists(analyzer.csv_dir)}")
```

### Problème: Trop de configurations générées

**Solution**:
```python
# Limiter le grid search
configs = optimizer.generate_grid_search_configs(
    "EURUSD",
    max_configs=50  # Limite à 50
)
```

### Problème: Graphiques ne s'affichent pas

**Solution**:
```python
import matplotlib
matplotlib.use('Agg')  # Backend sans affichage
import matplotlib.pyplot as plt

# Puis sauvegarder au lieu d'afficher
analyzer.plot_equity_curve(save_path='equity.png')
```

---

## 📚 API Reference

### Classe: `EAOptimizer`

```python
class EAOptimizer:
    def __init__(self)
    def define_parameter_space(self)
    def generate_smart_configs(self, symbol: str, timeframe: str) -> List[Dict]
    def generate_grid_search_configs(self, symbol: str, timeframe: str, max_configs: int) -> List[Dict]
    def generate_random_search_configs(self, symbol: str, timeframe: str, n_configs: int) -> List[Dict]
```

### Classe: `EAAnalyzer`

```python
class EAAnalyzer:
    def __init__(self, csv_dir: str = "")
    def load_trades(self, symbol: str, timeframe: str = None) -> pd.DataFrame
    def calculate_metrics(self, df: pd.DataFrame = None) -> Dict
    def analyze_by_hour(self, df: pd.DataFrame = None) -> pd.DataFrame
    def analyze_by_day(self, df: pd.DataFrame = None) -> pd.DataFrame
    def plot_equity_curve(self, df: pd.DataFrame = None, save_path: str = None)
    def create_performance_report(self, output_file: str = "ea_performance_report.html")
```

---

**Version**: 1.0  
**Date**: Octobre 2025  
**Status**: ✅ **PRODUCTION READY**

