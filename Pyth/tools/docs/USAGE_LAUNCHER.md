# 📡 Guide d'Utilisation - ea_launcher.py

## 📋 Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Classe MT5EALauncher](#classe-mt5ealauncher)
3. [Méthodes Principales](#méthodes-principales)
4. [Exemples d'Utilisation](#exemples-dutilisation)
5. [Paramètres de Configuration](#paramètres-de-configuration)
6. [Cas d'Usage Avancés](#cas-dusage-avancés)
7. [API Reference](#api-reference)

---

## 🎯 Vue d'Ensemble

**`ea_launcher.py`** est un gestionnaire de lancement d'EA MetaTrader 5 avec support multi-configurations. Il permet de:

- ✅ Créer et gérer plusieurs configurations d'EA
- ✅ Générer des fichiers `.set` pour Strategy Tester
- ✅ Surveiller les positions en temps réel
- ✅ Analyser les résultats de trading
- ✅ Comparer les performances de différentes configurations

### Quand Utiliser ce Script ?

- **Configuration d'EA**: Créer des configurations personnalisées
- **Gestion Multi-Configs**: Gérer plusieurs stratégies simultanément
- **Monitoring Live**: Surveiller les trades en temps réel
- **Analyse Rapide**: Analyser les résultats CSV de MT5

---

## 🏗️ Classe MT5EALauncher

### Initialisation

```python
from ea_launcher import MT5EALauncher

# Initialisation simple
launcher = MT5EALauncher()

# Avec chemin MT5 personnalisé
launcher = MT5EALauncher(mt5_path="C:/Custom/Path/terminal64.exe")
```

### Propriétés

| Propriété | Type | Description |
|-----------|------|-------------|
| `mt5_path` | str | Chemin vers terminal64.exe |
| `ea_name` | str | Nom de l'EA ("JTFreeCandle_v2") |
| `configurations` | list | Liste des configurations créées |
| `results` | list | Liste des résultats d'analyse |

---

## 🔧 Méthodes Principales

### 1. Connexion / Déconnexion

#### `connect() -> bool`

Connecte à MetaTrader 5.

```python
launcher = MT5EALauncher()

if launcher.connect():
    print("✅ Connecté à MT5")
else:
    print("❌ Échec de connexion")
    exit()
```

**Retour**: `True` si connexion réussie, `False` sinon

**Affiche**:
- Version MT5
- Numéro de compte connecté

#### `disconnect()`

Déconnecte de MT5.

```python
launcher.disconnect()
print("Déconnecté de MT5")
```

---

### 2. Création de Configuration

#### `create_configuration(...) -> Dict`

Crée une configuration d'EA complète.

```python
config = launcher.create_configuration(
    config_name="MyStrategy_EURUSD_H1",
    symbol="EURUSD",
    timeframe="H1",
    
    # Bollinger Bands
    bb_period=20,
    bb_deviation=2.0,
    
    # RSI Filter
    use_rsi_filter=True,
    rsi_period=14,
    rsi_oversold=29.0,
    rsi_overbought=71.0,
    
    # EMA Filter
    use_ema_filter=True,
    ema_fast=50,
    ema_slow=100,
    ema_mode="TREND",  # TREND, COUNTER, ZONE
    
    # Trading
    entry_mode="REVERSION",  # REVERSION ou BREAKOUT
    trade_direction="BOTH",  # BOTH, ONLY_BUY, ONLY_SELL
    risk_percent=1.0,
    min_rr=2.0,
    
    # Stop Loss / Take Profit
    sl_period=50,
    tp_period=30,
    atr_multiplier=2.0,
    
    # Magic Number (auto si None)
    magic=20251012
)
```

**Retour**: Dictionnaire de configuration

**Structure du Retour**:
```python
{
    "name": "MyStrategy_EURUSD_H1",
    "symbol": "EURUSD",
    "timeframe": 16385,  # ENUM MT5
    "timeframe_str": "H1",
    "magic": 20251012,
    "inputs": {
        # Tous les paramètres pour MT5
        ...
    }
}
```

---

### 3. Gestion des Fichiers

#### `save_configurations(filename: str)`

Sauvegarde toutes les configurations dans un fichier JSON.

```python
launcher.save_configurations("my_configs.json")
```

**Fichier Généré**:
```json
[
  {
    "name": "Config1",
    "symbol": "EURUSD",
    "timeframe_str": "H1",
    "magic": 20251007,
    "inputs": { ... }
  },
  ...
]
```

#### `load_configurations(filename: str)`

Charge des configurations depuis un fichier JSON.

```python
launcher.load_configurations("my_configs.json")
print(f"Chargé {len(launcher.configurations)} configurations")
```

#### `generate_set_file(config: Dict, output_dir: str) -> str`

Génère un fichier `.set` pour MetaTrader 5.

```python
config = launcher.configurations[0]
set_file = launcher.generate_set_file(config, output_dir="MT5_Sets")
print(f"Fichier créé: {set_file}")
```

**Fichier .set Généré**:
```
; Configuration: MyStrategy_EURUSD_H1
; Generated: 2025.10.12 12:30:45

InpSymbol=EURUSD
InpTF=16385
BB_Period=20
BB_Dev=2.0
Use_RSI_Filter=true
...
```

---

### 4. Monitoring et Analyse

#### `monitor_live_positions() -> pd.DataFrame`

Surveille les positions ouvertes.

```python
positions_df = launcher.monitor_live_positions()

if not positions_df.empty:
    print(f"\n{len(positions_df)} positions ouvertes:")
    print(positions_df[['ticket', 'symbol', 'type', 'profit']])
else:
    print("Aucune position ouverte")
```

**Colonnes du DataFrame**:
- `ticket`: Numéro de ticket
- `symbol`: Symbole tradé
- `type`: Type (0=Buy, 1=Sell)
- `volume`: Volume en lots
- `profit`: Profit actuel
- `profit_pct`: Profit en pourcentage
- `duration_min`: Durée en minutes

#### `get_csv_results(symbol: str, magic: int) -> pd.DataFrame`

Lit les résultats CSV générés par l'EA.

```python
df = launcher.get_csv_results("EURUSD")

if not df.empty:
    print(f"Chargé {len(df)} trades")
else:
    print("Aucun fichier CSV trouvé")
```

#### `analyze_results(df: pd.DataFrame) -> Dict`

Analyse les résultats des trades.

```python
df = launcher.get_csv_results("EURUSD")
stats = launcher.analyze_results(df)

print(f"Total trades: {stats['total_trades']}")
print(f"Win rate: {stats['win_rate']:.1f}%")
print(f"Profit total: ${stats['total_profit']:.2f}")
print(f"Profit factor: {stats['profit_factor']:.2f}")
```

**Métriques Retournées**:
```python
{
    'total_trades': 150,
    'wins': 90,
    'losses': 60,
    'win_rate': 60.0,
    'total_profit': 1250.50,
    'avg_profit': 8.34,
    'avg_win': 25.50,
    'avg_loss': -15.25,
    'best_trade': 150.00,
    'worst_trade': -75.00,
    'avg_rr': 2.35,
    'profit_factor': 1.85
}
```

#### `compare_configurations() -> pd.DataFrame`

Compare les performances de toutes les configurations.

```python
comparison_df = launcher.compare_configurations()

print("\nComparaison:")
print(comparison_df[['config_name', 'total_trades', 'win_rate', 'total_profit']])
```

---

## 💡 Exemples d'Utilisation

### Exemple 1: Configuration Simple

```python
from ea_launcher import MT5EALauncher

# 1. Initialiser
launcher = MT5EALauncher()

# 2. Connecter à MT5
if not launcher.connect():
    print("Erreur de connexion")
    exit()

try:
    # 3. Créer une configuration
    config = launcher.create_configuration(
        config_name="Simple_Test",
        symbol="EURUSD",
        timeframe="H1",
        risk_percent=1.0,
        min_rr=2.0
    )
    
    # 4. Générer le fichier .set
    set_file = launcher.generate_set_file(config)
    print(f"✅ Fichier .set créé: {set_file}")
    
finally:
    # 5. Déconnecter
    launcher.disconnect()
```

### Exemple 2: Configurations Multiples

```python
from ea_launcher import MT5EALauncher

launcher = MT5EALauncher()
launcher.connect()

try:
    # Créer plusieurs configurations
    symbols = ["EURUSD", "GBPUSD", "USDJPY"]
    timeframes = ["M15", "H1", "H4"]
    
    for symbol in symbols:
        for tf in timeframes:
            launcher.create_configuration(
                config_name=f"{symbol}_{tf}",
                symbol=symbol,
                timeframe=tf,
                risk_percent=0.5,
                min_rr=2.5
            )
    
    # Sauvegarder toutes les configs
    launcher.save_configurations("multi_configs.json")
    
    # Générer tous les fichiers .set
    for config in launcher.configurations:
        launcher.generate_set_file(config, output_dir="MT5_Sets")
    
    print(f"✅ {len(launcher.configurations)} configurations créées")
    
finally:
    launcher.disconnect()
```

### Exemple 3: Monitoring en Temps Réel

```python
from ea_launcher import MT5EALauncher
import time

launcher = MT5EALauncher()
launcher.connect()

try:
    print("🔄 Surveillance des positions (Ctrl+C pour arrêter)...")
    
    while True:
        positions = launcher.monitor_live_positions()
        
        if not positions.empty:
            print(f"\n[{time.strftime('%H:%M:%S')}] {len(positions)} positions:")
            
            for _, pos in positions.iterrows():
                symbol = pos['symbol']
                profit = pos['profit']
                profit_pct = pos['profit_pct']
                
                emoji = "📈" if profit > 0 else "📉"
                print(f"  {emoji} {symbol}: ${profit:.2f} ({profit_pct:.2f}%)")
        else:
            print(f"[{time.strftime('%H:%M:%S')}] Aucune position")
        
        time.sleep(60)  # Refresh chaque minute
        
except KeyboardInterrupt:
    print("\n\n✋ Surveillance arrêtée")
    
finally:
    launcher.disconnect()
```

### Exemple 4: Analyse Complète

```python
from ea_launcher import MT5EALauncher

launcher = MT5EALauncher()
launcher.connect()

try:
    # Charger les configurations existantes
    launcher.load_configurations("my_configs.json")
    
    # Analyser chaque configuration
    for config in launcher.configurations:
        symbol = config['symbol']
        name = config['name']
        
        print(f"\n{'='*60}")
        print(f"Configuration: {name}")
        print(f"{'='*60}")
        
        # Charger les résultats
        df = launcher.get_csv_results(symbol)
        
        if df.empty:
            print("❌ Aucun résultat trouvé")
            continue
        
        # Analyser
        stats = launcher.analyze_results(df)
        
        # Afficher les métriques
        print(f"\nMétriques:")
        print(f"  Total trades: {stats['total_trades']}")
        print(f"  Win rate: {stats['win_rate']:.1f}%")
        print(f"  Profit total: ${stats['total_profit']:.2f}")
        print(f"  Profit factor: {stats['profit_factor']:.2f}")
        print(f"  Best trade: ${stats['best_trade']:.2f}")
        print(f"  Worst trade: ${stats['worst_trade']:.2f}")
        
    # Comparaison globale
    print(f"\n{'='*60}")
    print("COMPARAISON GLOBALE")
    print(f"{'='*60}\n")
    
    comparison = launcher.compare_configurations()
    print(comparison[['config_name', 'win_rate', 'total_profit', 'profit_factor']])
    
finally:
    launcher.disconnect()
```

---

## ⚙️ Paramètres de Configuration

### Bollinger Bands

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `bb_period` | int | 20 | Période des Bollinger Bands |
| `bb_deviation` | float | 2.0 | Déviation standard |

**Valeurs recommandées**:
- Scalping: period=15, deviation=1.8
- Day Trading: period=20, deviation=2.0
- Swing: period=25, deviation=2.5

### RSI Filter

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `use_rsi_filter` | bool | True | Activer le filtre RSI |
| `rsi_period` | int | 14 | Période du RSI |
| `rsi_oversold` | float | 29.0 | Niveau de survente |
| `rsi_overbought` | float | 71.0 | Niveau de surachat |

**Valeurs recommandées**:
- Conservative: 25/75
- Balanced: 30/70
- Aggressive: 35/65

### EMA Filter

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `use_ema_filter` | bool | True | Activer le filtre EMA |
| `ema_fast` | int | 50 | EMA rapide |
| `ema_slow` | int | 100 | EMA lente |
| `ema_mode` | str | "TREND" | Mode: TREND, COUNTER, ZONE |
| `ema_zone_distance` | float | 20.0 | Distance de la zone (points) |

**Modes**:
- **TREND**: Trading avec la tendance
- **COUNTER**: Trading contre-tendance
- **ZONE**: Trading dans une zone de prix

### Divergence

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `use_divergence` | bool | True | Activer détection divergence |
| `div_rsi_buy` | float | 35.0 | Niveau RSI achat divergence |
| `div_rsi_sell` | float | 65.0 | Niveau RSI vente divergence |
| `div_swing_length` | int | 5 | Longueur du swing |

### Trading

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `entry_mode` | str | "REVERSION" | REVERSION ou BREAKOUT |
| `trade_direction` | str | "BOTH" | BOTH, ONLY_BUY, ONLY_SELL |
| `risk_percent` | float | 0.1 | Risque par trade (%) |
| `min_rr` | float | 2.0 | Ratio risque/récompense minimum |

### Stop Loss / Take Profit

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `sl_period` | int | 50 | Période pour SL basé sur ATR |
| `tp_period` | int | 30 | Période pour TP basé sur ATR |
| `atr_multiplier` | float | 2.0 | Multiplicateur ATR |

### Filtres Temporels

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `use_time_filter` | bool | True | Activer filtre horaire |
| `hour_ranges` | str | "8-10;16" | Plages horaires (ex: "8-10;14-16") |
| `use_day_filter` | bool | False | Activer filtre jours |
| `day_ranges` | str | "1-5" | Jours de la semaine (1=Lundi, 5=Vendredi) |

---

## 🚀 Cas d'Usage Avancés

### Cas 1: Optimisation Multi-Symboles

```python
from ea_launcher import MT5EALauncher

launcher = MT5EALauncher()
launcher.connect()

try:
    # Paramètres de base
    base_config = {
        "timeframe": "H1",
        "risk_percent": 1.0,
        "min_rr": 2.0,
        "use_rsi_filter": True,
        "use_ema_filter": True
    }
    
    # Tester sur plusieurs symboles
    symbols = ["EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "NZDUSD"]
    
    for symbol in symbols:
        launcher.create_configuration(
            config_name=f"MultiSymbol_{symbol}",
            symbol=symbol,
            **base_config
        )
    
    # Sauvegarder et générer .set
    launcher.save_configurations("multi_symbol_configs.json")
    
    for config in launcher.configurations:
        launcher.generate_set_file(config, output_dir="MT5_Sets/MultiSymbol")
    
    print(f"✅ {len(symbols)} configurations multi-symboles créées")
    
finally:
    launcher.disconnect()
```

### Cas 2: Grid Search Manuel

```python
from ea_launcher import MT5EALauncher
import itertools

launcher = MT5EALauncher()
launcher.connect()

try:
    # Définir les plages de paramètres
    bb_periods = [15, 20, 25]
    rsi_thresholds = [(25, 75), (30, 70), (35, 65)]
    risk_percents = [0.5, 1.0, 1.5]
    
    # Générer toutes les combinaisons
    combinations = itertools.product(bb_periods, rsi_thresholds, risk_percents)
    
    for idx, (bb_period, (rsi_os, rsi_ob), risk) in enumerate(combinations):
        config_name = f"Grid_{idx}_BB{bb_period}_RSI{rsi_os}-{rsi_ob}_R{risk}"
        
        launcher.create_configuration(
            config_name=config_name,
            symbol="EURUSD",
            timeframe="H1",
            bb_period=bb_period,
            rsi_oversold=rsi_os,
            rsi_overbought=rsi_ob,
            risk_percent=risk
        )
    
    print(f"✅ {len(launcher.configurations)} configurations de grid search créées")
    
    # Sauvegarder
    launcher.save_configurations("grid_search_configs.json")
    
    # Générer les .set
    for config in launcher.configurations:
        launcher.generate_set_file(config, output_dir="MT5_Sets/GridSearch")
    
finally:
    launcher.disconnect()
```

### Cas 3: Analyse Comparative Automatique

```python
from ea_launcher import MT5EALauncher
import pandas as pd

launcher = MT5EALauncher()
launcher.connect()

try:
    # Charger plusieurs configurations
    launcher.load_configurations("my_configs.json")
    
    # Comparer toutes les configurations
    comparison = launcher.compare_configurations()
    
    if not comparison.empty:
        # Trier par profit factor
        comparison_sorted = comparison.sort_values('profit_factor', ascending=False)
        
        print("\n🏆 TOP 5 CONFIGURATIONS PAR PROFIT FACTOR:")
        print("="*80)
        
        top5 = comparison_sorted.head(5)
        for idx, row in top5.iterrows():
            print(f"\n{idx+1}. {row['config_name']}")
            print(f"   Symbol: {row['symbol']} | TF: {row['timeframe']}")
            print(f"   Total Trades: {row['total_trades']}")
            print(f"   Win Rate: {row['win_rate']:.1f}%")
            print(f"   Total Profit: ${row['total_profit']:.2f}")
            print(f"   Profit Factor: {row['profit_factor']:.2f}")
        
        # Exporter en CSV
        comparison_sorted.to_csv("comparison_results.csv", index=False)
        print(f"\n✅ Résultats exportés dans comparison_results.csv")
    else:
        print("❌ Aucun résultat à comparer")
    
finally:
    launcher.disconnect()
```

---

## 📚 API Reference

### Classe: `MT5EALauncher`

```python
class MT5EALauncher:
    """Gestionnaire de lancement d'EA avec configurations multiples"""
    
    def __init__(self, mt5_path: Optional[str] = None)
    def connect(self) -> bool
    def disconnect(self)
    def create_configuration(self, ...) -> Dict
    def save_configurations(self, filename: str = "ea_configs.json")
    def load_configurations(self, filename: str = "ea_configs.json")
    def generate_set_file(self, config: Dict, output_dir: str = "MT5_Sets") -> str
    def monitor_live_positions(self) -> pd.DataFrame
    def get_csv_results(self, symbol: str, magic: int = None) -> pd.DataFrame
    def analyze_results(self, df: pd.DataFrame) -> Dict
    def compare_configurations(self) -> pd.DataFrame
```

### Timeframes MT5

```python
TIMEFRAME_MAP = {
    "M1": 1,
    "M5": 5,
    "M15": 15,
    "M30": 30,
    "H1": 16385,
    "H4": 16388,
    "D1": 16408
}
```

---

## 📞 Support

### Logs
```python
import logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ea_launcher.log'),
        logging.StreamHandler()
    ]
)
```

### Commandes Utiles

```bash
# Vérifier les dépendances
python tools/check_dependencies.py

# Lancer un exemple
python -c "from ea_launcher import example_usage; example_usage()"
```

---

**Version**: 1.0  
**Date**: Octobre 2025  
**Status**: ✅ **PRODUCTION READY**

