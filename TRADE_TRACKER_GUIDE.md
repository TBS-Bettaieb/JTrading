# Guide du Trade Tracker - JTFreeCandle EA

## Vue d'ensemble

Le **Trade Tracker** est un système complet de suivi et d'analyse de vos trades qui enregistre **automatiquement** plus de 40 paramètres pour chaque trade, permettant une optimisation data-driven de votre stratégie.

## Fichiers générés

### Fichier CSV principal
**Nom**: `TradeAnalysis_[SYMBOL]_[MAGIC_NUMBER].csv`

**Exemple**: `TradeAnalysis_EURUSD_20251007.csv`

**Localisation**: Dossier `MQL5/Files/` de votre terminal MetaTrader 5

### Contenu du fichier CSV

Le fichier contient **33 colonnes** avec toutes les données de chaque trade:

#### Données de base (9 colonnes)
- `Ticket` - Numéro du trade
- `OpenTime` - Date/heure d'ouverture
- `CloseTime` - Date/heure de fermeture
- `Symbol` - Paire de devises
- `Type` - BUY ou SELL
- `Volume` - Taille du lot
- `OpenPrice` - Prix d'entrée
- `ClosePrice` - Prix de sortie
- `Profit` - Profit net ($)

#### Niveaux et résultats (8 colonnes)
- `SL` - Stop Loss
- `TP` - Take Profit
- `Pips` - Résultat en pips
- `Commission` - Commission du broker
- `Swap` - Frais de swap
- `PlannedRR` - Risk/Reward prévu à l'entrée
- `ActualRR` - Risk/Reward réel à la sortie
- `Duration` - Durée du trade (minutes)

#### Conditions de marché à l'entrée (8 colonnes)
- `RSI` - Valeur RSI au moment de l'entrée
- `ATR` - Average True Range
- `Spread` - Spread en points
- `BBWidth` - Largeur Bollinger Bands (points)
- `DistUpperBB` - Distance à la bande supérieure
- `DistLowerBB` - Distance à la bande inférieure
- `EMA50` - Valeur EMA rapide
- `EMA100` - Valeur EMA lente

#### Contexte temporel (3 colonnes)
- `Hour` - Heure d'entrée (0-23)
- `Minute` - Minute d'entrée (0-59)
- `DayOfWeek` - Jour de la semaine (0=Dimanche, 1=Lundi, ...)

#### Métriques de performance (2 colonnes)
- `MaxProfit` - Profit maximum atteint pendant le trade
- `MaxDD` - Drawdown maximum pendant le trade

#### Contexte stratégique (4 colonnes)
- `ExitReason` - Raison de sortie (TP/SL/Band Touch/Flat Time)
- `Mode` - Mode d'entrée (REVERSION/BREAKOUT)
- `Divergence` - Trade validé par divergence (YES/NO)
- `EMAMode` - Mode EMA utilisé (TREND/COUNTER/ZONE)

## Rapports automatiques

### Rapport dans l'onglet "Experts" de MT5

À chaque arrêt de l'EA (OnDeinit), un rapport complet est affiché:

```
╔════════════════════════════════════════╗
║     RAPPORT DE PERFORMANCE COMPLET     ║
╠════════════════════════════════════════╣
║ Total Trades: 47
║ Gagnants: 31 (66.0%)
║ Perdants: 16
║ Profit Net: $1,245.50
║ Profit Factor: 2.35
║ Gain Moyen: $65.20
║ Perte Moyenne: $28.40
║ RR Moyen: 1:2.15
║ Meilleur Trade: $185.00
║ Pire Trade: -$52.30
╚════════════════════════════════════════╝

=== PERFORMANCE PAR HEURE ===
08:00 - Trades: 5 | Profit: $245.20 | WR: 80.0%
09:00 - Trades: 8 | Profit: $320.50 | WR: 75.0%
16:00 - Trades: 12 | Profit: $480.30 | WR: 58.3%
...

=== PERFORMANCE PAR JOUR ===
Lundi: Trades: 8 | Profit: $340.50 | WR: 62.5%
Mardi: Trades: 12 | Profit: $520.80 | WR: 75.0%
Mercredi: Trades: 9 | Profit: $180.20 | WR: 55.6%
...
```

### Logs en temps réel

À chaque ouverture de trade:
```
=== NOUVEAU TRADE OUVERT ===
Ticket: 12345678 | BUY | Volume: 0.10
Entry: 1.08500 | SL: 1.08350 | TP: 1.08800
RR prévu: 1:2.00
RSI: 28.50 | Spread: 1.5 pts
BB Width: 45.2 pts
Heure: 9:30 | Jour: 2 (Mardi)
Mode: REVERSION | Divergence: NON | EMA: TREND
```

À chaque fermeture:
```
=== TRADE FERMÉ ===
Ticket: 12345678 | Profit: 75.50
Pips: 30.0 | RR réel: 1:2.00
Durée: 125 min | Raison: TP
Max Profit atteint: 85.20
Max Drawdown: -5.30
```

## Analyses recommandées

### 1. Performance par heure

**Objectif**: Identifier les heures les plus rentables

**Excel/Google Sheets**:
```
=SUMIF(Hour:Hour, 9, Profit:Profit)  // Profit total à 9h
=COUNTIF(Hour:Hour, 9)                // Nombre de trades à 9h
```

**Insights à chercher**:
- Win rate > 70% à certaines heures → Augmenter le volume
- Win rate < 40% à certaines heures → Désactiver ces heures
- Heures avec meilleur RR moyen

### 2. Performance par jour de la semaine

**Objectif**: Détecter les jours à éviter/favoriser

**Python (pandas)**:
```python
import pandas as pd
df = pd.read_csv('TradeAnalysis_EURUSD_20251007.csv')

# Performance par jour
by_day = df.groupby('DayOfWeek').agg({
    'Profit': ['sum', 'mean', 'count'],
    'Pips': 'mean',
    'ActualRR': 'mean'
})

print(by_day)
```

**Actions**:
- Jours avec profit négatif → Désactiver temporairement
- Jours avec RR élevé → Augmenter Risk_Percent

### 3. Impact des conditions de marché

**Objectif**: Comprendre quelles conditions favorisent vos trades

**Analyses clés**:
```
# Meilleurs trades par largeur BB
Filtre: BBWidth > 50 points → Win rate?
Filtre: BBWidth < 30 points → Win rate?

# Impact du spread
Filtre: Spread > 2.0 points → Profit moyen?

# Zones RSI optimales
Filtre: RSI < 25 (BUY) → RR moyen?
Filtre: RSI > 75 (SELL) → RR moyen?
```

### 4. Efficacité des modes EMA

**Objectif**: Quel mode EMA performe le mieux?

```
Trades TREND:   Win rate = ?  |  RR moyen = ?
Trades COUNTER: Win rate = ?  |  RR moyen = ?
Trades ZONE:    Win rate = ?  |  RR moyen = ?
```

**Décision**:
- Mode avec meilleur Profit Factor → Mode principal
- Mode avec meilleur RR → Pour trades sélectifs
- Mode avec trop de trades perdants → Désactiver

### 5. Performance divergences vs normales

**Objectif**: Les divergences valent-elles le délai?

```
Trades Divergence YES: Count = ? | Win rate = ? | RR = ?
Trades Divergence NO:  Count = ? | Win rate = ? | RR = ?
```

**Insights**:
- Divergences doivent avoir Win Rate +10-15% minimum
- Si RR divergence > RR normal de 0.5+ → Garder activé
- Si nombre trades divergence très faible → Peut-être assouplir critères

### 6. Analyse des sorties

**Objectif**: Optimiser vos sorties

```
Sorties TP:         Count = ? | Profit moyen = ?
Sorties SL:         Count = ? | Perte moyenne = ?
Sorties Band Touch: Count = ? | Profit moyen = ?
Sorties Flat Time:  Count = ? | Profit moyen = ?
```

**Questions**:
- Band Touch est-elle prématurée? (MaxProfit bien supérieur au Profit réel)
- TP trop conservateur? (MaxProfit >> Profit TP)
- SL trop serré? (Beaucoup de SL suivis d'inversions)

### 7. Analyse Max Profit vs Profit réel

**Objectif**: Détecter les opportunités manquées

**Excel**:
```
= (MaxProfit - Profit) / MaxProfit  // % d'opportunité perdue
```

Si ce ratio est souvent > 50%:
- Envisager trailing stop
- TP peut-être trop conservateur
- Revoir la stratégie Band Touch

### 8. Corrélation RSI-Performance

**Objectif**: Affiner les seuils RSI

**Python**:
```python
# Trades BUY
buy_trades = df[df['Type'] == 'BUY']
buy_trades.plot.scatter(x='RSI', y='Pips', alpha=0.5)

# Identifier le RSI optimal
profitable_buys = buy_trades[buy_trades['Pips'] > 0]
print(f"RSI moyen trades BUY gagnants: {profitable_buys['RSI'].mean()}")
```

**Ajustements possibles**:
- Si meilleurs BUY ont RSI < 25 → Réduire RSI_Oversold de 29 à 25
- Si meilleurs SELL ont RSI > 75 → Augmenter RSI_Overbought

### 9. Optimisation des périodes SL/TP

**Objectif**: Vérifier si SL_Period et TP_Period sont optimaux

```
Grouper par PlannedRR:
RR 1:1.5 → Win rate = ?
RR 1:2.0 → Win rate = ?
RR 1:2.5 → Win rate = ?
RR 1:3.0 → Win rate = ?
```

**Règle d'or**:
```
Win Rate × RR > 1.0  (rentable)
Win Rate × RR > 1.5  (bon)
Win Rate × RR > 2.0  (excellent)
```

### 10. Analyse de séquences

**Objectif**: Détecter des patterns dans les séries

**À chercher**:
- Séries de pertes à certaines heures
- Trades gagnants souvent suivis de perdants (overtrading?)
- Performance après un gros gain/perte

## Dashboards recommandés

### Dashboard Excel basique

**Feuille 1: Vue d'ensemble**
```
Total Trades       │ [FORMULE]
Win Rate          │ [FORMULE] %
Profit Factor     │ [FORMULE]
RR Moyen          │ [FORMULE]
Profit Net        │ $[FORMULE]
```

**Feuille 2: Par heure**
- Tableau croisé dynamique: Heure en lignes, Sum(Profit) en valeurs

**Feuille 3: Par jour**
- Tableau croisé dynamique: DayOfWeek en lignes, Profit/Count/WinRate

**Feuille 4: Par mode EMA**
- Tableau croisé dynamique: EMAMode en lignes

### Dashboard Google Sheets (formules utiles)

```
// Win Rate
=COUNTIFS(Profit:Profit,">0")/COUNTA(Profit:Profit)

// Profit Factor
=SUMIF(Profit:Profit,">0")/ABS(SUMIF(Profit:Profit,"<0"))

// RR moyen
=AVERAGE(ActualRR:ActualRR)

// Meilleur heure
=INDEX(Hour:Hour, MATCH(MAX(Profit:Profit), Profit:Profit, 0))
```

### Dashboard Python (avec visualisations)

```python
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Charger les données
df = pd.read_csv('TradeAnalysis_EURUSD_20251007.csv')

# 1. Equity curve
df['CumProfit'] = df['Profit'].cumsum()
plt.figure(figsize=(12, 6))
plt.plot(df.index, df['CumProfit'])
plt.title('Equity Curve')
plt.xlabel('Trade Number')
plt.ylabel('Cumulative Profit ($)')
plt.grid(True)
plt.show()

# 2. Distribution profits
plt.figure(figsize=(10, 6))
plt.hist(df['Profit'], bins=30, edgecolor='black')
plt.title('Profit Distribution')
plt.xlabel('Profit ($)')
plt.ylabel('Frequency')
plt.axvline(0, color='red', linestyle='--')
plt.show()

# 3. Win rate par heure
hourly = df.groupby('Hour').agg({
    'Profit': lambda x: (x > 0).sum() / len(x) * 100
})
plt.figure(figsize=(12, 6))
hourly.plot(kind='bar')
plt.title('Win Rate by Hour')
plt.xlabel('Hour')
plt.ylabel('Win Rate (%)')
plt.xticks(rotation=0)
plt.show()

# 4. Heatmap corrélations
corr_columns = ['RSI', 'ATR', 'Spread', 'BBWidth', 'PlannedRR', 'Pips']
correlation = df[corr_columns].corr()
plt.figure(figsize=(10, 8))
sns.heatmap(correlation, annot=True, cmap='coolwarm', center=0)
plt.title('Correlation Matrix')
plt.show()

# 5. Performance par mode EMA
ema_perf = df.groupby('EMAMode').agg({
    'Profit': ['sum', 'mean', 'count'],
    'ActualRR': 'mean'
})
print(ema_perf)
```

## Cas d'usage pratiques

### Cas 1: "Mes trades du matin perdent"

**Analyse**:
```
Filtrer: Hour >= 6 AND Hour <= 10
Calculer: Win Rate, Profit Net

Si Win Rate < 50% ou Profit Net < 0:
→ Modifier HourRanges pour exclure ces heures
```

### Cas 2: "Mode COUNTER ne fonctionne pas"

**Analyse**:
```
Filtrer: EMAMode = "COUNTER"
Comparer avec: EMAMode = "TREND"

Si Profit Factor COUNTER < 1.0:
→ Désactiver mode COUNTER, utiliser uniquement TREND
```

### Cas 3: "Beaucoup de trades fermés sur SL"

**Analyse**:
```
Filtrer: ExitReason = "SL"
Examiner: MaxProfit

Si beaucoup de MaxProfit > 0 avant SL:
→ SL trop serré, augmenter SL_Period
→ Ou activer Trailing Stop
```

### Cas 4: "Win rate élevé mais profit faible"

**Analyse**:
```
Calculer: Gain Moyen vs Perte Moyenne

Si Perte Moyenne > Gain Moyen:
→ TP trop conservateur
→ Augmenter Min_RR de 2.0 à 2.5 ou 3.0
```

### Cas 5: "Optimiser pour un broker"

**Analyse**:
```
Examiner: Spread, Commission, Swap

Si Spread moyen > 2.0 points:
→ Filtrer trades avec Spread élevé
→ Trader uniquement heures de forte liquidité

Si Swap important:
→ Éviter positions overnight (UseFlatTime=true)
```

## Optimisation itérative

### Cycle d'amélioration (recommandé)

**Semaine 1**: Collecter données (minimum 30 trades)
- Laisser tourner avec paramètres par défaut
- Observer le CSV se remplir
- Ne pas toucher aux paramètres

**Semaine 2**: Première analyse
- Identifier 2-3 problèmes majeurs (exemple: mauvaise heure)
- Faire 1 seul ajustement à la fois
- Documenter le changement

**Semaine 3**: Test du changement
- Comparer avant/après
- Si amélioration: garder
- Si dégradation: revenir en arrière

**Semaine 4**: Optimisation fine
- Ajuster un 2ème paramètre
- Recommencer le cycle

**Important**: Ne jamais changer plus de 2 paramètres en même temps, sinon impossible de savoir ce qui fonctionne!

## Alertes et signaux d'alarme

### 🔴 Signaux négatifs (arrêter l'EA)

- **Win Rate < 40%** pendant 20 trades consécutifs
- **Profit Factor < 0.8** sur 30 trades
- **3+ grosses pertes consécutives** (> 2× risque moyen)
- **Drawdown > 20%** du capital

→ Action: Arrêter l'EA, analyser le CSV, identifier le problème

### 🟡 Signaux d'attention

- **Win Rate entre 40-50%**
- **RR moyen < 1.5**
- **Beaucoup de sorties SL** (> 60%)
- **Spread moyen > 2.5 points**

→ Action: Optimiser 1-2 paramètres clés

### 🟢 Signaux positifs (continuer)

- **Win Rate > 55%**
- **Profit Factor > 1.5**
- **RR moyen > 2.0**
- **Equity curve croissante**

→ Action: Augmenter progressivement Risk_Percent

## Export et sauvegarde

### Localisation du fichier

```
Windows:
C:\Users\[VotreNom]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Files\

Mac:
~/Library/Application Support/MetaTrader 5/Bottles/[ID]/drive_c/users/[User]/Application Data/MetaQuotes/Terminal/[ID]/MQL5/Files/
```

### Sauvegarde recommandée

1. **Journalière** (si trading actif):
   - Copier le CSV vers Dropbox/Google Drive
   - Renommer avec date: `TradeAnalysis_EURUSD_20250109.csv`

2. **Hebdomadaire**:
   - Créer une analyse Excel/Google Sheets
   - Documenter les changements de paramètres

3. **Mensuelle**:
   - Dashboard complet de performance
   - Comparaison mois vs mois

## Intégration avec autres outils

### TradingView
- Importer les heures d'entrée/sortie
- Annoter les graphiques
- Valider visuellement les setups

### MyFxBook
- Importer trades depuis CSV
- Comparaison avec autres traders
- Analyse de corrélation

### Excel Power Query
- Actualisation automatique du CSV
- Dashboards dynamiques
- Alertes conditionnelles

## FAQ

**Q: Le fichier CSV devient très gros, que faire?**
R: Créez un nouveau fichier par mois en changeant le Magic Number, ou archivez l'ancien CSV.

**Q: Puis-je modifier le CSV manuellement?**
R: Oui, mais faites une sauvegarde avant. Le tracker ne réécrit que les nouvelles lignes.

**Q: Certaines colonnes sont vides, pourquoi?**
R: Colonnes vides si trade encore ouvert (CloseTime, Profit, etc.) ou si indicateur non disponible.

**Q: Les rapports par heure sont vides**
R: Normal si peu de trades. Attendez au moins 50-100 trades pour des analyses statistiquement significatives.

**Q: Puis-je tracker plusieurs symboles?**
R: Oui, un fichier CSV par symbole est créé automatiquement.

**Q: Comment désactiver le tracker?**
R: Commentez l'initialisation dans OnInit(), mais c'est déconseillé car les données sont précieuses!

---

**Version**: 1.0  
**Date**: 2025-01-09  
**Auteur**: JTrading Expert Advisor  
**Support**: Analysez vos trades, optimisez votre stratégie! 📊

