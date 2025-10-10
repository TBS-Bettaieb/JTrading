# 🔧 Guide de Dépannage - JTrading Python

## ❌ **PROBLÈMES COURANTS ET SOLUTIONS**

---

## 1. **"Terminal: Invalid params (-2)"**

### **Symptômes**
```
⚠️ Erreur récupération données: (-2, 'Terminal: Invalid params')
❌ No data available for EURUSD M3
```

### **Causes Possibles**

#### **A. Données historiques non disponibles**
Certains brokers ne fournissent pas toutes les données historiques anciennes pour tous les timeframes.

**Solution**:
```bash
# 1. Tester avec données récentes
python diagnose_mt5.py

# 2. Utiliser un timeframe plus standard
python backtest.py --symbol EURUSD --timeframe H1  # Au lieu de M3

# 3. Ou télécharger manuellement dans MT5
# Ouvrir graphique EURUSD M3 dans MT5
# Faire défiler vers le passé pour forcer le téléchargement
```

#### **B. Symbole non activé**
```bash
# Solution: Activer le symbole dans Market Watch
# MT5 → Market Watch → Clic droit → Afficher tout
# Ou double-cliquer sur le symbole pour ouvrir un graphique
```

#### **C. Conversion timeframe incorrecte**
✅ **CORRIGÉ** dans version 2.1.0

**Vérification**:
```python
python test_timeframes.py  # Test tous les timeframes
```

---

## 2. **"ModuleNotFoundError: No module named 'matplotlib'"**

### **Solution**
```bash
# Réinstaller les dépendances
pip install -r requirements.txt

# Ou installer uniquement matplotlib
pip install matplotlib seaborn plotly
```

---

## 3. **"Import could not be resolved"** (Tests)

### **Solution**
✅ **CORRIGÉ** - Tous les tests ont maintenant:
```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent / 'Pyth'))
```

---

## 4. **"No cache found" / Cache vide**

### **Solution**
```bash
# Option 1: Télécharger depuis MT5
python backtest.py --symbol EURUSD --timeframe H1

# Option 2: Importer depuis CSV
python -c "
from data import DataManager
import pandas as pd

df = pd.read_csv('your_data.csv', index_col='time', parse_dates=True)
dm = DataManager()
dm.cache_data(df, 'EURUSD', 'H1')
"
```

---

## 5. **"AttributeError: 'DivergenceConfig' object has no attribute 'min_bars'"**

### **Solution**
✅ **CORRIGÉ** dans version 2.1.0

**Vérification**:
```python
# Le DivergenceValidator utilise maintenant:
config.divergence.swing_length  # Au lieu de min_bars
config.divergence.rsi_buy_level  # Au lieu de config.rsi.oversold
```

---

## 6. **Performance lente (< 100k bars/sec)**

### **Causes**
- Trop de copies de DataFrame
- Utilisation de `.iloc[]` en boucle
- Pas d'optimisation `inplace`

### **Solution**
✅ **CORRIGÉ** dans version 2.0.0+

**Vérifications**:
```python
# Utiliser inplace=True quand possible
strategy.prepare_data(df, inplace=True)

# Le backtest engine utilise itertuples() (automatique)
```

---

## 7. **"No signals generated"**

### **Causes**
- Configuration trop restrictive (tous les filtres activés)
- Pas de Free Candles dans la période
- Paramètres Bollinger trop serrés

### **Solutions**

#### **A. Utiliser config_simple**
```python
from config_simple import get_simple_config

config = get_simple_config()  # Filtres désactivés
strategy = FreeCandleStrategy(config)
```

#### **B. Désactiver certains filtres**
```python
config = StrategyConfig()
config.rsi.use_filter = False
config.ema.use_filter = False
config.divergence.use_validator = False
config.time_filter.use_time_filter = False
```

#### **C. Ajuster paramètres Bollinger**
```python
config.bollinger.period = 15  # Au lieu de 20
config.bollinger.deviation = 1.5  # Au lieu de 2.0
```

---

## 8. **Point size incorrect pour symbole**

### **Solution**
✅ **CORRIGÉ** - Point size maintenant dynamique

**Vérification**:
```python
from strategies import FreeCandleStrategy
from config import StrategyConfig

config = StrategyConfig()
config.symbol.symbol = "XAUUSD"

strategy = FreeCandleStrategy(config)
print(f"Point size: {strategy.point_size}")  # Devrait être 0.01
```

**Ordre de priorité**:
1. MT5 (`SymbolInfo.point`)
2. `config/constants.py` (`POINT_SIZE_MAP`)
3. Défaut (0.00001)

---

## 9. **Jours de trading incorrects**

### **Symptôme**
Config "1-5" ne trade pas Lundi-Vendredi

### **Solution**
✅ **CORRIGÉ** - Conversion Python→MQL5

**Format MQL5** (utilisé par la config):
- 0 = Dimanche
- 1 = Lundi
- 2 = Mardi
- ...
- 6 = Samedi

**Config correcte**:
```python
config.time_filter.day_ranges = "1-5"  # Lundi à Vendredi
```

---

## 10. **MT5 ne se connecte pas**

### **Diagnostic**
```bash
python diagnose_mt5.py
```

### **Solutions**

#### **A. MT5 non ouvert**
```
❌ Erreur initialisation MT5: (1, 'Terminal: General error')
```
→ Ouvrir MetaTrader 5

#### **B. Pas de connexion serveur**
```
Connexion: False
```
→ Se connecter à un compte démo/réel

#### **C. Firewall**
→ Autoriser Python et MT5 dans le pare-feu

---

## 11. **Tests unitaires échouent**

### **Import errors**
✅ **CORRIGÉ** - Chemins vers `Pyth/`

### **Fixture errors**
```bash
# Relancer conftest
python tests/run_tests.py config  # Test un seul module
```

### **Signal validation errors**
✅ **CORRIGÉ** - Signal.validate() ajoutée

---

## 12. **Backtest trop lent (> 10 sec pour 10k barres)**

### **Vérification version**
```bash
git log --oneline -1
# Devrait être >= be0252c (performance fixes)
```

### **Si version < 2.0.0**
```bash
git pull origin develop
pip install -r requirements.txt --upgrade
```

---

## 🛠️ **OUTILS DE DIAGNOSTIC**

### **1. Diagnostic MT5 complet**
```bash
python diagnose_mt5.py
```
Vérifie:
- Connexion MT5
- Symboles disponibles
- Test téléchargement
- Recommandations

### **2. Test timeframes**
```bash
python test_timeframes.py
```
Teste tous les timeframes pour EURUSD

### **3. Test installation**
```bash
python test_installation.py
```
Vérifie tous les modules Python

### **4. Test connexion MT5**
```bash
python test_mt5_connection.py
```
Test détaillé de la connexion

### **5. Test cohérence MQL5**
```bash
python test_mql5_consistency.py --symbol EURUSD --mql5-log signals.csv
```
Compare signaux MQL5 vs Python

---

## 📊 **SYMBOLES RECOMMANDÉS**

D'après le diagnostic, ces symboles fonctionnent le mieux :

| Symbole | Timeframes OK | Point Size |
|---------|---------------|------------|
| EURUSD | M1, M3, M5, H1, H4, D1 | 0.00001 |
| GBPUSD | M1, M3, M5, H1, H4, D1 | 0.00001 |
| US100.cash | M5, H1, H4, D1 | 0.01 |
| XAUUSD | M5, H1, H4, D1 | 0.01 |

**Recommandation**: Utiliser **H1** ou **H4** pour backtests (plus fiables)

---

## ⏰ **TIMEFRAMES DISPONIBLES**

| TF | Nom | Disponibilité | Recommandé |
|----|-----|---------------|------------|
| M1 | 1 minute | ✅ Partout | ⚠️ Beaucoup de données |
| M3 | 3 minutes | ⚠️ Selon broker | Non |
| M5 | 5 minutes | ✅ Partout | ✅ Oui |
| M15 | 15 minutes | ✅ Partout | ✅ Oui |
| M30 | 30 minutes | ✅ Partout | ✅ Oui |
| H1 | 1 heure | ✅ Partout | ✅✅ Optimal |
| H4 | 4 heures | ✅ Partout | ✅✅ Optimal |
| D1 | 1 jour | ✅ Partout | ✅ Oui |

---

## 🎯 **WORKFLOW DE DÉPANNAGE**

### **Étape 1: Diagnostic**
```bash
python diagnose_mt5.py
```
→ Note les symboles qui fonctionnent

### **Étape 2: Test rapide**
```bash
python test_timeframes.py
```
→ Note les timeframes qui fonctionnent

### **Étape 3: Télécharger données**
```bash
# Utiliser un symbole et TF confirmés
python backtest.py --symbol EURUSD --timeframe H1
```

### **Étape 4: Backtest**
```bash
python quick_backtest_cli.py --list  # Vérifier cache
python quick_backtest_cli.py -i      # Mode interactif
```

---

## 📞 **SUPPORT**

### **Logs utiles**
- `logs/backtest_*.log` - Logs détaillés
- `reports/backtest_*.txt` - Rapports
- Console output

### **Informations à fournir**
1. Version Python (`python --version`)
2. Version MT5 (`diagnose_mt5.py`)
3. Symbole et timeframe testés
4. Message d'erreur complet
5. Logs pertinents

---

## ✅ **VERSIONS CORRIGÉES**

| Version | Fixes |
|---------|-------|
| 2.0.0 | Performance (2x), optimisation mémoire |
| 2.1.0 | MQL5 alignment, point size, day filter |
| 2.1.1 | Timeframes complets, divergence config |

**Version actuelle**: 2.1.1  
**Commit**: 78e6a38

---

**Si problèmes persistants, voir PROJECT_SUMMARY.md et MQL5_ALIGNMENT_COMPLETE.md** 📚

