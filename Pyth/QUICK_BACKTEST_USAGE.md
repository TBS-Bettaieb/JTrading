# 🚀 Guide d'Utilisation - Quick Backtest CLI

## 📋 **4 MODES D'UTILISATION**

---

## 1️⃣ **MODE CLI CLASSIQUE** (Arguments)

### Usage Simple
```bash
# Backtest basique (EURUSD M3 2023)
python quick_backtest_cli.py

# Backtest personnalisé
python quick_backtest_cli.py --symbol GBPUSD --timeframe H1 --year 2022

# Avec capital et commission personnalisés
python quick_backtest_cli.py --symbol US100.cash --capital 20000 --commission 0.0001

# Mode silencieux (résultats seulement)
python quick_backtest_cli.py --quiet
```

### Arguments Disponibles
```
--symbol SYMBOL       Symbole (défaut: EURUSD)
--timeframe TF        Timeframe (défaut: M3)
--year YEAR           Année (défaut: 2023)
--capital CAPITAL     Capital initial (défaut: 10000)
--commission COMM     Commission (défaut: 0.0002)
--quiet, -q           Mode silencieux
```

---

## 2️⃣ **MODE INTERACTIF** (Menus)

### Lancement
```bash
python quick_backtest_cli.py --interactive
# ou
python quick_backtest_cli.py -i
```

### Workflow Interactif

#### **Étape 1: Choix du Symbole**
```
======================================================================
📊 SÉLECTION DU SYMBOLE
======================================================================

1. Forex Majors:
   1. EURUSD
   2. GBPUSD
   3. USDJPY
   4. USDCHF
   5. AUDUSD
   6. USDCAD
   7. NZDUSD

2. Forex Minors:
   8. EURGBP
   9. EURJPY
   ...

3. Indices:
   14. US100.cash
   15. US30.cash
   ...

4. Commodities:
   19. XAUUSD
   20. XAGUSD
   ...

5. Crypto:
   23. BTCUSD
   24. ETHUSD
   ...

0. Entrer un symbole personnalisé
======================================================================

Choisissez un symbole (numéro ou 0 pour custom): 1
```

#### **Étape 2: Choix du Timeframe**
```
======================================================================
⏰ SÉLECTION DU TIMEFRAME
======================================================================

Ultra-Court:
   1. M1
   2. M3
   3. M5

Court Terme:
   4. M15
   5. M30

Moyen Terme:
   6. H1
   7. H4

Long Terme:
   8. D1
   9. W1
   10. MN1
======================================================================

Choisissez un timeframe (numéro): 2
```

#### **Étape 3: Choix de l'Année**
```
======================================================================
📅 SÉLECTION DE L'ANNÉE
======================================================================

Années disponibles:
   1. 2020
   2. 2021
   3. 2022
   4. 2023
   5. 2024
   6. 2025
======================================================================

Choisissez une année (numéro): 4
```

#### **Étape 4: Capital et Commission**
```
======================================================================
💰 CAPITAL INITIAL
======================================================================

Capital initial (défaut: 10000): 15000

======================================================================
💳 COMMISSION
======================================================================
Exemples: 0.0002 (0.02%), 0.0001 (0.01%), 0.0005 (0.05%)

Commission par trade (défaut: 0.0002): 0.0001
```

Puis le backtest s'exécute automatiquement !

---

## 3️⃣ **MODE BATCH** (Backtests Multiples)

### Lancement
```bash
python quick_backtest_cli.py --batch
# ou
python quick_backtest_cli.py -b
```

### Configuration Batch

#### **Sélection Multiple**
```
======================================================================
🔄 MODE BATCH - Configuration
======================================================================

📊 Sélection des symboles (séparés par des virgules):
Exemples: EURUSD,GBPUSD,USDJPY ou tapez 'all' pour tous les Forex majors

Symboles: EURUSD,GBPUSD,USDJPY

⏰ Sélection des timeframes (séparés par des virgules):
Exemples: M3,H1,D1 ou tapez 'all' pour M3,H1

Timeframes: M3,H1

📅 Sélection des années (séparées par des virgules):
Exemples: 2023,2024 ou tapez '2023' pour une seule année

Années: 2023

======================================================================
🔄 MODE BATCH - BACKTESTS MULTIPLES
======================================================================

📊 6 backtests à exécuter
   Symboles: EURUSD, GBPUSD, USDJPY
   Timeframes: M3, H1
   Années: 2023

▶️  Continuer ? (o/n): o
```

### Résultats Batch

#### **Exécution**
```
======================================================================
📊 Test 1/6: EURUSD M3 2023
======================================================================
✅ Profit: $-24.77 (-0.25%) | Trades: 10 | Win Rate: 10.0%

======================================================================
📊 Test 2/6: EURUSD H1 2023
======================================================================
✅ Profit: $150.50 (+1.51%) | Trades: 15 | Win Rate: 53.3%

... (4 autres tests)
```

#### **Comparaison Finale**
```
======================================================================
📊 COMPARAISON DES RÉSULTATS
======================================================================

🏆 CLASSEMENT PAR PERFORMANCE:
----------------------------------------------------------------------
1. GBPUSD       H1   2023 | Return:  +2.45% | Trades:  18 | Win Rate:  55.6%
2. EURUSD       H1   2023 | Return:  +1.51% | Trades:  15 | Win Rate:  53.3%
3. USDJPY       H1   2023 | Return:  +0.80% | Trades:  12 | Win Rate:  50.0%
4. GBPUSD       M3   2023 | Return:  -0.15% | Trades:   8 | Win Rate:  25.0%
5. EURUSD       M3   2023 | Return:  -0.25% | Trades:  10 | Win Rate:  10.0%
6. USDJPY       M3   2023 | Return:  -1.20% | Trades:   6 | Win Rate:  16.7%

======================================================================
📈 STATISTIQUES GLOBALES:
----------------------------------------------------------------------
Total backtests: 6
Rentables: 3
Perdants: 3

Meilleure performance: GBPUSD H1 (+2.45%)
Pire performance: USDJPY M3 (-1.20%)

Return moyen: +0.53%
Win rate moyen: 35.1%
======================================================================

💾 Sauvegarder les résultats en CSV ? (o/n): o
✅ Résultats sauvegardés: batch_results_20251010_102530.csv
```

---

## 4️⃣ **MODE LISTE** (Données Disponibles)

### Lancement
```bash
python quick_backtest_cli.py --list
# ou
python quick_backtest_cli.py -l
```

### Affichage
```
======================================================================
💾 DONNÉES DISPONIBLES EN CACHE
======================================================================

✅ 3 datasets disponibles:

   1. EURUSD          M3   
   2. EURUSD          H1   
   3. US100.cash      M3   
======================================================================
```

---

## 📊 **EXEMPLES D'UTILISATION**

### **Scénario 1: Test Rapide d'un Symbole**
```bash
# Mode interactif (le plus simple)
python quick_backtest_cli.py -i
# Puis suivez les menus...
```

### **Scénario 2: Comparer Plusieurs Symboles**
```bash
# Mode batch
python quick_backtest_cli.py --batch
# Entrez: EURUSD,GBPUSD,USDJPY
# Entrez: H1
# Entrez: 2023
```

### **Scénario 3: Test de Performance Timeframes**
```bash
# Mode batch - Tester tous les timeframes pour un symbole
python quick_backtest_cli.py --batch
# Entrez: EURUSD
# Entrez: M3,M5,M15,M30,H1,H4,D1
# Entrez: 2023
```

### **Scénario 4: Optimisation de Paramètres**
```bash
# Tester différentes commissions
python quick_backtest_cli.py --symbol EURUSD --commission 0.0001
python quick_backtest_cli.py --symbol EURUSD --commission 0.0002
python quick_backtest_cli.py --symbol EURUSD --commission 0.0005

# Tester différents capitaux
python quick_backtest_cli.py --capital 5000
python quick_backtest_cli.py --capital 10000
python quick_backtest_cli.py --capital 20000
```

---

## 🎯 **WORKFLOWS RECOMMANDÉS**

### **Débutant**
1. Lister les données disponibles: `python quick_backtest_cli.py --list`
2. Lancer mode interactif: `python quick_backtest_cli.py -i`
3. Choisir dans les menus

### **Avancé**
1. Mode batch pour comparer: `python quick_backtest_cli.py --batch`
2. Sauvegarder résultats en CSV
3. Analyser dans Excel/Python

### **Automation**
```bash
# Script batch pour tester plusieurs configurations
python quick_backtest_cli.py --symbol EURUSD --year 2023 --quiet
python quick_backtest_cli.py --symbol GBPUSD --year 2023 --quiet
python quick_backtest_cli.py --symbol USDJPY --year 2023 --quiet
```

---

## 🔧 **SYMBOLES DISPONIBLES**

### **Forex Majors** (Plus liquides)
- EURUSD, GBPUSD, USDJPY, USDCHF
- AUDUSD, USDCAD, NZDUSD

### **Forex Minors**
- EURGBP, EURJPY, GBPJPY, EURCHF
- AUDJPY, CADJPY

### **Indices**
- US100.cash (NASDAQ), US30.cash (Dow Jones)
- US500.cash (S&P 500), GER40.cash (DAX)
- UK100.cash (FTSE)

### **Commodities**
- XAUUSD (Gold), XAGUSD (Silver)
- USOIL (WTI), UKOIL (Brent)

### **Crypto**
- BTCUSD, ETHUSD, LTCUSD, XRPUSD

---

## ⏰ **TIMEFRAMES DISPONIBLES**

### **Ultra-Court Terme** (Scalping)
- M1, M3, M5

### **Court Terme** (Day Trading)
- M15, M30

### **Moyen Terme** (Swing Trading)
- H1, H4

### **Long Terme** (Position Trading)
- D1, W1, MN1

---

## 💡 **TIPS & ASTUCES**

### **Optimiser les Tests**
```bash
# 1. Toujours vérifier les données disponibles
python quick_backtest_cli.py --list

# 2. Télécharger les données manquantes
python backtest.py --symbol GBPUSD --timeframe H1 --start-date 2023-01-01 --end-date 2024-01-01

# 3. Lancer le test
python quick_backtest_cli.py --symbol GBPUSD --timeframe H1 --year 2023
```

### **Batch Optimal**
```bash
# Tester seulement les timeframes standards
python quick_backtest_cli.py --batch
# Symboles: all
# Timeframes: all  (M3,H1)
# Années: 2023
```

### **Export et Analyse**
Le mode batch sauvegarde en CSV, exploitable dans Excel ou Python:
```python
import pandas as pd
results = pd.read_csv('batch_results_20251010_102530.csv')
print(results.sort_values('return_pct', ascending=False))
```

---

## ⚡ **PERFORMANCES ATTENDUES**

| Timeframe | Barres/1an | Vitesse Backtest |
|-----------|------------|------------------|
| M1 | ~525,000 | ~2-3 sec |
| M3 | ~175,000 | ~0.5 sec |
| M5 | ~105,000 | ~0.3 sec |
| H1 | ~8,760 | ~0.02 sec |
| D1 | ~365 | ~0.001 sec |

**Note**: Avec les optimisations (~400k bars/sec), les backtests sont ultra-rapides ! ⚡

---

## 📝 **EXEMPLES COMPLETS**

### **Test 1: Comparer Forex Majors sur H1**
```bash
python quick_backtest_cli.py --batch

# Entrées:
Symboles: EURUSD,GBPUSD,USDJPY,AUDUSD
Timeframes: H1
Années: 2023

# Résultat: 4 backtests comparés
```

### **Test 2: Optimisation Timeframe pour EURUSD**
```bash
python quick_backtest_cli.py --batch

# Entrées:
Symboles: EURUSD
Timeframes: M3,M5,M15,M30,H1,H4,D1
Années: 2023

# Résultat: 7 backtests pour trouver le meilleur timeframe
```

### **Test 3: Backtesting Multi-Années**
```bash
python quick_backtest_cli.py --batch

# Entrées:
Symboles: EURUSD
Timeframes: H1
Années: 2021,2022,2023,2024

# Résultat: Performance sur 4 ans
```

---

## ⚠️ **LIMITATIONS**

1. **Données en Cache Requises**
   - Le quick_backtest utilise uniquement les données en cache
   - Téléchargez d'abord avec `backtest.py`

2. **Configuration Simple**
   - Utilise toujours `config_simple.py`
   - Pour config avancée, utilisez `backtest.py`

3. **Timeframe M3**
   - M3 n'existe pas nativement dans MT5
   - Utilise M5 comme fallback

---

## 🎓 **BONNES PRATIQUES**

### **Avant de Commencer**
1. ✅ Vérifier les données: `python quick_backtest_cli.py --list`
2. ✅ Télécharger si nécessaire: `python backtest.py ...`
3. ✅ Tester un symbole d'abord: `python quick_backtest_cli.py -i`
4. ✅ Puis mode batch pour comparer

### **Pour des Résultats Fiables**
- Tester sur minimum 1 an de données
- Comparer plusieurs timeframes
- Vérifier la robustesse sur plusieurs années
- Analyser les résultats batch dans Excel

### **Automation**
Créez un script PowerShell/Bash:
```powershell
# test_all.ps1
$symbols = @("EURUSD", "GBPUSD", "USDJPY")
foreach ($symbol in $symbols) {
    python quick_backtest_cli.py --symbol $symbol --year 2023 --quiet
}
```

---

**Le quick_backtest_cli.py est maintenant un outil puissant et flexible pour des backtests rapides !** 🚀

