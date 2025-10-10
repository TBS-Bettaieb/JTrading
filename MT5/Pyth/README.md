# 🤖 JTrading - Free Candle Strategy (Python)

[![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://www.python.org/)
[![MetaTrader5](https://img.shields.io/badge/MetaTrader-5-green.svg)](https://www.metatrader5.com/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> Conversion complète de l'Expert Advisor MQL5 **JTFreeCandle** en Python avec backtesting avancé et trading live via MetaTrader 5 API.

---

## 📋 Table des Matières

- [Aperçu](#aperçu)
- [Fonctionnalités](#fonctionnalités)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Architecture](#architecture)
- [Stratégie de Trading](#stratégie-de-trading)
- [Backtesting](#backtesting)
- [Trading Live](#trading-live)
- [Performances](#performances)
- [FAQ](#faq)

---

## 🎯 Aperçu

**JTrading** est une implémentation Python complète d'une stratégie de trading basée sur les **Free Candles** (bougies libres hors Bollinger Bands), combinant plusieurs filtres techniques pour optimiser les signaux d'entrée.

### Qu'est-ce qu'une Free Candle ?

Une **Free Candle** est une bougie dont :
- Le **corps** (mode BODY) ou
- La **totalité de la bougie** (mode FULL)

sort des **Bollinger Bands**, indiquant une **sur-extension** potentielle du prix.

### Stratégie

La stratégie utilise un mode **REVERSION** (mean reversion) ou **BREAKOUT** :

- **REVERSION** : Vendre quand bougie sort en haut, acheter quand elle sort en bas
- **BREAKOUT** : Acheter quand bougie sort en haut, vendre quand elle sort en bas

Avec des filtres optionnels :
- ✅ **RSI** : Confirmation survente/surachat
- ✅ **EMA** : Filtre de tendance (3 modes : TREND, COUNTER, ZONE)
- ✅ **Divergence** : Validation divergence RSI/Prix
- ✅ **Temps** : Filtres horaires et journaliers

---

## ✨ Fonctionnalités

### 📊 Indicateurs Techniques
- **Bollinger Bands** : Détection Free Candles
- **RSI** : Indicateur de momentum avec détection de divergence
- **EMA** : Moyennes mobiles (Fast/Slow) avec 3 modes de filtrage
- **ATR** : Mesure de volatilité pour SL/TP dynamiques

### 🎯 Stratégie
- **2 Modes** : REVERSION et BREAKOUT
- **Détection Free Candles** : Corps ou bougie complète
- **Filtres multiples** : RSI, EMA, Temps, Jours
- **Validateur de divergence** : RSI/Prix (bullish/bearish)
- **Money Management** : Position sizing basé sur le risque

### 💰 Gestion du Risque
- **Position Sizing** : Fixe, % risque, Kelly Criterion, Optimal f
- **Stop Loss** : Swing High/Low, ATR, Support/Résistance
- **Take Profit** : Multiple du SL ou prix fixe
- **Trailing Stop** : Break-even et trailing dynamique
- **Max Drawdown** : Limite de perte maximale

### 📈 Backtesting
- **Moteur de simulation** : Réaliste avec commission/slippage
- **20+ Métriques** : Win rate, Profit Factor, Sharpe, Sortino, Calmar
- **Analyse avancée** : MAE/MFE, distribution des gains/pertes
- **Optimisation** : Grid search, walk-forward analysis
- **Rapports détaillés** : Excel, CSV, JSON

### 🔴 Trading Live
- **Connexion MT5** : API officielle MetaTrader 5
- **Exécution en temps réel** : Ouverture/fermeture automatique
- **Gestion positions** : Modification SL/TP, trailing stop
- **Multi-symboles** : Trading simultané sur plusieurs paires
- **Logging complet** : Historique de tous les trades

### 📊 Analyse & Visualisation
- **Dashboards interactifs** : Plotly/Matplotlib
- **Graphiques** : Equity curve, drawdown, distribution
- **Heatmaps** : Performance par heure/jour/mois
- **Rapports HTML** : Rapports complets exportables

---

## 🚀 Installation

### Prérequis

1. **Python 3.11+** (recommandé : 3.11 ou 3.12)
   - Télécharger : https://www.python.org/downloads/
   - ⚠️ **Cocher "Add Python to PATH" lors de l'installation**

2. **MetaTrader 5** (pour trading live)
   - Télécharger : https://www.metatrader5.com/fr/download

3. **Git** (optionnel, pour cloner le repo)

### Étapes d'installation

```bash
# 1. Cloner ou naviguer vers le projet
cd MT5/Pyth

# 2. Créer un environnement virtuel (recommandé)
python -m venv venv

# 3. Activer l'environnement virtuel
# Windows PowerShell:
.\venv\Scripts\Activate.ps1
# Windows CMD:
venv\Scripts\activate.bat
# Linux/Mac:
source venv/bin/activate

# 4. Mettre à jour pip
pip install --upgrade pip

# 5. Installer les dépendances
pip install -r requirements.txt

# 6. Tester l'installation
python test_installation.py
```

### Vérification de l'installation

```bash
# Test des modules Python
python test_installation.py

# Test de connexion MT5 (MetaTrader 5 doit être lancé)
python test_mt5_connection.py
```

---

## ⚙️ Configuration

### 1. Configuration de Base

Éditez `config/settings.py` ou créez un fichier YAML :

```python
from config import StrategyConfig, EntryMode, TradeDirection, EMAMode

config = StrategyConfig()

# Symbole
config.symbol.symbol = "EURUSD"
config.symbol.timeframe = "H1"  # H1, H4, D1, etc.

# Mode stratégie
config.entry_mode = EntryMode.REVERSION  # ou BREAKOUT

# Free Candle
config.free_candle.enabled = True
config.free_candle.check_full_candle = False  # True pour bougie complète
config.free_candle.allow_touch = False

# Bollinger Bands
config.bollinger.period = 20
config.bollinger.deviation = 2.0

# RSI
config.rsi.enabled = True
config.rsi.period = 14
config.rsi.oversold = 30
config.rsi.overbought = 70

# EMA
config.ema.enabled = True
config.ema.mode = EMAMode.TREND  # TREND, COUNTER, ou ZONE
config.ema.fast_period = 50
config.ema.slow_period = 200

# Money Management
config.money_management.risk_percent = 1.0  # 1% par trade
config.money_management.fixed_lots = 0.01
config.money_management.max_positions = 1

# Stop Loss / Take Profit
config.stop_loss.use_swing = True
config.stop_loss.swing_lookback = 20
config.stop_loss.atr_multiplier = 1.5
config.take_profit.risk_reward_ratio = 2.0

# Filtres temporels
config.time_filter.enabled = True
config.time_filter.start_hour = 8
config.time_filter.end_hour = 20
config.time_filter.allowed_days = [0, 1, 2, 3, 4]  # Lun-Ven
```

### 2. Configuration MT5 (Trading Live)

Créez un fichier `.env` à la racine :

```env
MT5_LOGIN=12345678
MT5_PASSWORD=your_password
MT5_SERVER=YourBroker-Demo
MT5_TIMEOUT=60000
```

---

## 📖 Utilisation

### 1. Menu Interactif (Recommandé)

```bash
python main.py
```

Menu avec options :
1. Lancer un backtest
2. Démarrer trading live
3. Analyser résultats
4. Optimiser paramètres
5. Visualiser performance

### 2. Backtest Manuel

```bash
python backtest.py --symbol EURUSD --timeframe H1 --start 2023-01-01 --end 2024-12-31
```

Options :
```bash
--symbol EURUSD          # Symbole à trader
--timeframe H1           # Timeframe (M15, H1, H4, D1)
--start 2023-01-01       # Date de début
--end 2024-12-31         # Date de fin
--capital 10000          # Capital initial
--plot                   # Afficher les graphiques
--save-report            # Sauvegarder le rapport
--optimize               # Mode optimisation
```

### 3. Trading Live

```bash
python live_trade.py --symbol EURUSD --risk 1.0
```

⚠️ **ATTENTION** : Assurez-vous de :
1. Lancer **MetaTrader 5** d'abord
2. Se connecter à un **compte DÉMO** pour les tests
3. Vérifier la configuration dans `config/settings.py`

### 4. Analyse de Performance

```python
from analysis import PerformanceAnalyzer, Visualizer
from backtesting import BacktestEngine

# Charger résultats
analyzer = PerformanceAnalyzer()
results = analyzer.load_results("backtest_results.json")

# Afficher métriques
metrics = analyzer.calculate_metrics(results)
print(metrics)

# Créer visualisations
viz = Visualizer()
viz.create_dashboard(results, save_path="dashboard.html")
```

---

## 🏗️ Architecture

```
MT5/Pyth/
├── 📄 main.py                      # Menu principal
├── 📄 backtest.py                  # Script de backtesting
├── 📄 live_trade.py                # Script de trading live
├── 📄 requirements.txt             # Dépendances
├── 📄 .env                         # Configuration MT5 (git-ignored)
│
├── 📁 config/                      # ⚙️ Configuration
│   ├── __init__.py
│   └── settings.py                 # Tous les paramètres
│
├── 📁 indicators/                  # 📊 Indicateurs
│   ├── __init__.py
│   ├── bollinger_bands.py         # Bollinger Bands + Free Candles
│   ├── rsi.py                     # RSI
│   ├── ema.py                     # EMA (3 modes)
│   └── atr.py                     # ATR
│
├── 📁 strategies/                  # 🎯 Stratégies
│   ├── __init__.py
│   ├── free_candle.py             # Stratégie principale
│   └── divergence.py              # Validateur divergence
│
├── 📁 risk_management/             # 💰 Money Management
│   ├── __init__.py
│   ├── position_sizing.py         # Calcul taille positions
│   └── stop_loss.py               # SL/TP (Swing, ATR, S/R)
│
├── 📁 backtesting/                 # 📈 Backtesting
│   ├── __init__.py
│   ├── engine.py                  # Moteur de simulation
│   └── metrics.py                 # Métriques de performance
│
├── 📁 live_trading/                # 🔴 Trading Live
│   ├── __init__.py
│   ├── mt5_connector.py           # Connexion MT5
│   └── trade_executor.py          # Exécution des ordres
│
├── 📁 data/                        # 💾 Données
│   ├── __init__.py
│   └── data_manager.py            # Gestion données (cache, CSV)
│
├── 📁 analysis/                    # 📊 Analyse
│   ├── __init__.py
│   ├── performance.py             # Analyseur de performance
│   └── visualization.py           # Graphiques & dashboards
│
└── 📁 utils/                       # 🔧 Utilitaires
    ├── __init__.py
    ├── logger.py                   # Système de logging
    └── helpers.py                  # Fonctions utilitaires
```

---

## 📐 Stratégie de Trading

### Conditions d'Entrée

#### 🟢 ACHAT (BUY)

**Mode REVERSION** :
- ✅ Free Candle **en dessous** de la BB inférieure
- ✅ RSI < Oversold (30) [optionnel]
- ✅ Prix < EMA (mode TREND) [optionnel]
- ✅ Divergence haussière RSI/Prix [optionnel]

**Mode BREAKOUT** :
- ✅ Free Candle **au-dessus** de la BB supérieure
- ✅ RSI > Overbought (70) [optionnel]
- ✅ Prix > EMA (mode TREND) [optionnel]

#### 🔴 VENTE (SELL)

**Mode REVERSION** :
- ✅ Free Candle **au-dessus** de la BB supérieure
- ✅ RSI > Overbought (70) [optionnel]
- ✅ Prix > EMA (mode TREND) [optionnel]
- ✅ Divergence baissière RSI/Prix [optionnel]

**Mode BREAKOUT** :
- ✅ Free Candle **en dessous** de la BB inférieure
- ✅ RSI < Oversold (30) [optionnel]
- ✅ Prix < EMA (mode TREND) [optionnel]

### Stop Loss & Take Profit

#### Stop Loss
1. **Swing High/Low** : SL au dernier swing (lookback configurable)
2. **ATR** : SL = Prix ± (ATR × Multiplier)
3. **Support/Résistance** : SL au niveau S/R le plus proche

#### Take Profit
1. **Risk/Reward** : TP = SL × Ratio (par défaut 2.0)
2. **Fixe** : TP à un prix/distance fixe
3. **Trailing** : TP suit le prix avec trailing stop

---

## 📊 Backtesting

### Exemple Complet

```python
from config import StrategyConfig
from strategies import FreeCandleStrategy
from backtesting import BacktestEngine
from analysis import PerformanceAnalyzer, Visualizer
import pandas as pd

# 1. Configuration
config = StrategyConfig()
config.symbol.symbol = "EURUSD"
config.entry_mode = EntryMode.REVERSION
config.money_management.risk_percent = 1.0

# 2. Charger données historiques
from live_trading import MT5Connector
connector = MT5Connector()
df = connector.get_ohlcv("EURUSD", "H1", start_date="2023-01-01", end_date="2024-12-31")

# 3. Générer signaux
strategy = FreeCandleStrategy(config)
signals = strategy.generate_signals(df)

# 4. Backtest
engine = BacktestEngine(initial_capital=10000, commission=0.0001)
results = engine.run_backtest(df, signals, config)

# 5. Analyse
analyzer = PerformanceAnalyzer()
metrics = analyzer.calculate_metrics(results)

print(f"Total Trades: {metrics['total_trades']}")
print(f"Win Rate: {metrics['win_rate']:.2%}")
print(f"Profit Factor: {metrics['profit_factor']:.2f}")
print(f"Sharpe Ratio: {metrics['sharpe_ratio']:.2f}")
print(f"Max Drawdown: {metrics['max_drawdown']:.2%}")

# 6. Visualisation
viz = Visualizer()
viz.plot_equity_curve(results)
viz.plot_drawdown(results)
viz.create_dashboard(results, save_path="report.html")
```

### Métriques Disponibles

- **Rendement** : Total Return, CAGR, Monthly Returns
- **Risque** : Max Drawdown, Volatility, Downside Deviation
- **Ratios** : Sharpe, Sortino, Calmar, Omega
- **Trades** : Win Rate, Profit Factor, Average Win/Loss
- **Analyse** : MAE, MFE, Consecutive Wins/Losses

---

## 🔴 Trading Live

### Configuration MT5

```python
from live_trading import MT5Connector, TradeExecutor
from config import StrategyConfig

# 1. Connexion MT5
connector = MT5Connector()
if not connector.connect(login=12345678, password="xxx", server="Broker-Demo"):
    print("Erreur connexion")
    exit()

# 2. Configuration
config = StrategyConfig()
config.symbol.symbol = "EURUSD"

# 3. Exécuteur de trades
executor = TradeExecutor(connector, config)

# 4. Trading en temps réel
from strategies import FreeCandleStrategy

strategy = FreeCandleStrategy(config)

while True:
    # Récupérer dernières données
    df = connector.get_ohlcv("EURUSD", "H1", bars=100)
    
    # Générer signal
    signals = strategy.generate_signals(df)
    last_signal = signals.iloc[-1]
    
    # Exécuter trade si signal
    if last_signal['signal'] == 1:  # BUY
        executor.open_position(
            symbol="EURUSD",
            direction="BUY",
            stop_loss=last_signal['stop_loss'],
            take_profit=last_signal['take_profit']
        )
    elif last_signal['signal'] == -1:  # SELL
        executor.open_position(
            symbol="EURUSD",
            direction="SELL",
            stop_loss=last_signal['stop_loss'],
            take_profit=last_signal['take_profit']
        )
    
    # Attendre prochaine bougie
    time.sleep(3600)  # 1 heure pour H1
```

### Sécurité

⚠️ **IMPORTANT** :
1. **Toujours tester sur DÉMO** avant le réel
2. **Limiter le risque** à 1-2% par trade
3. **Activer le max drawdown** pour couper les pertes
4. **Surveiller régulièrement** le bot
5. **Garder des logs** de tous les trades

---

## 📈 Performances

### Résultats Historiques (EURUSD H1, 2023)

*Ces résultats sont des exemples et ne garantissent pas les performances futures*

| Métrique | Valeur |
|----------|--------|
| Total Trades | 245 |
| Win Rate | 62.4% |
| Profit Factor | 1.85 |
| Sharpe Ratio | 1.42 |
| Max Drawdown | -12.3% |
| Total Return | +34.5% |
| CAGR | +32.1% |

---

## ❓ FAQ

### Q: Puis-je utiliser ce système sur d'autres marchés ?
**R:** Oui ! Le système fonctionne sur Forex, indices, crypto, actions (si disponibles sur MT5).

### Q: Quels sont les meilleurs timeframes ?
**R:** H1 et H4 donnent généralement les meilleurs résultats. M15 est plus volatil.

### Q: Le système fonctionne-t-il en mode news ?
**R:** Il est recommandé de **désactiver le trading pendant les news** importantes.

### Q: Combien de capital minimal ?
**R:** Minimum 1000$ pour gérer le risque correctement (1% = 10$/trade).

### Q: Puis-je trader plusieurs paires ?
**R:** Oui, mais attention à la corrélation (ex: EURUSD et GBPUSD sont corrélés).

### Q: Comment optimiser les paramètres ?
**R:** Utilisez le module d'optimisation avec walk-forward analysis pour éviter l'overfitting.

---

## 📝 License

MIT License - Libre d'utilisation, modification et distribution.

---

## 🤝 Support

Pour toute question ou problème :
1. Consultez d'abord la [FAQ](#faq)
2. Vérifiez les [Issues GitHub](issues)
3. Créez une nouvelle issue si nécessaire

---

## ⚠️ Avertissement

**Le trading comporte des risques de perte en capital. Ce système est fourni à des fins éducatives uniquement. Tradez uniquement avec de l'argent que vous pouvez vous permettre de perdre. Les performances passées ne garantissent pas les résultats futurs.**

---

*Créé avec ❤️ pour la communauté de trading algorithmique*
