# Trade Tracker - Guide des Enrichissements

## Vue d'ensemble

Le système de tracking des trades a été enrichi avec de nouvelles métriques pour améliorer l'analyse des performances. Ce document décrit toutes les nouvelles fonctionnalités.

---

## 📊 Nouvelles Métriques EMA

### Ajouts dans TradeRecord

```cpp
// Métriques EMA enrichies
double   distEMAFastSlow; // Distance EMA50-EMA100 en points
double   emaSpread;       // (EMA50-EMA100)/EMA100 en %
string   emaTrend;        // "UP" si EMA50>EMA100, "DOWN" sinon
string   priceVsEMA;      // ABOVE_BOTH, BETWEEN, BELOW_BOTH
```

### Description

1. **distEMAFastSlow** : Distance absolue entre les deux EMAs en points
   - Utile pour mesurer la séparation des EMAs (divergence de tendance)
   - Plus la distance est grande, plus la tendance est forte

2. **emaSpread** : Spread en pourcentage
   - Formule : `(EMA50 - EMA100) / EMA100 * 100`
   - Positif = tendance haussière, Négatif = tendance baissière
   - Permet de comparer entre différents symboles

3. **emaTrend** : Direction de la tendance
   - "UP" si EMA50 > EMA100
   - "DOWN" si EMA50 < EMA100
   - Indique la direction globale du marché

4. **priceVsEMA** : Position relative du prix
   - "ABOVE_BOTH" : Prix au-dessus des deux EMAs (fort momentum haussier)
   - "BETWEEN" : Prix entre les EMAs (zone de consolidation)
   - "BELOW_BOTH" : Prix en-dessous des EMAs (fort momentum baissier)

### Exemple d'utilisation

```cpp
// Dans l'analyse CSV
if(rec.emaTrend == "UP" && rec.priceVsEMA == "ABOVE_BOTH") {
   // Configuration favorable pour un trade BUY
}

if(rec.emaSpread > 0.5) {
   // Tendance forte (spread > 0.5%)
}
```

---

## 📈 Données de Divergence

### Ajouts dans TradeRecord

```cpp
// Données divergence
double   divAngle;        // Angle d'inclinaison en degrés
double   divStrength;     // Force: diff RSI / diff prix
int      divBars;         // Nombre de barres entre pivots
```

### Description

1. **divAngle** : Angle d'inclinaison de la divergence
   - Mesuré en degrés (0-90°)
   - Plus l'angle est grand, plus la divergence est prononcée
   - Indique la force du désalignement prix/RSI

2. **divStrength** : Force de la divergence
   - Formule : `différence RSI / différence prix`
   - Plus la valeur est élevée, plus la divergence est significative
   - Permet de filtrer les divergences faibles

3. **divBars** : Nombre de barres entre les pivots
   - Distance temporelle entre les deux points de divergence
   - Utile pour filtrer les divergences trop courtes ou trop longues

### Utilisation avec le validateur de divergence

```cpp
// Dans JT_DivergenceValidator.mqh ou dans votre EA
if(Use_Divergence_Validator) {
   int divSignal = divValidator.ValidateDivergence();
   if(divSignal != 0) {
      // Ouvrir le trade
      ExecuteTradeFromDivergence(divSignal);
      
      // IMPORTANT : Définir les données de divergence APRÈS l'ouverture
      if(tracker != NULL) {
         // Calculer les métriques de divergence
         double angle = CalculateDivergenceAngle();        // Votre calcul
         double strength = CalculateDivergenceStrength();  // Votre calcul
         int bars = CountBarsBetweenPivots();              // Votre calcul
         
         // Enregistrer dans le tracker
         tracker.SetDivergenceData(angle, strength, bars);
      }
   }
}
```

### Cas où la divergence n'est pas utilisée

Si votre trade n'utilise pas la validation par divergence :
- `divAngle = 0`
- `divStrength = 0`
- `divBars = 0`

Ces valeurs par défaut indiquent qu'aucune divergence n'a été détectée.

---

## 📁 Nouveau Format de Fichier CSV

### Ancien Format
```
TradeAnalysis_[symbol]_[magic].csv
Exemple : TradeAnalysis_EURUSD_20251007.csv
```

### Nouveau Format
```
TradeAnalysis_[symbol]_[timeframe]_[dateFirstTrade]_[dateLastTrade].csv
Exemple : TradeAnalysis_EURUSD_H1_20241001_20241231.csv
```

### Avantages

1. **Identification du timeframe** : On sait immédiatement sur quel timeframe les trades ont été exécutés
2. **Période de trading** : Les dates de début et fin sont explicites
3. **Organisation** : Facile de comparer les résultats entre différents timeframes
4. **Archivage** : Renommage automatique à chaque nouveau trade

### Comportement

1. **Premier trade** : Le fichier est créé avec un nom temporaire basé sur le magic number
   - Après le premier trade, il est renommé avec la date du premier trade
   
2. **Trades suivants** : À chaque fermeture de trade, si la date change, le fichier est renommé
   - La date du dernier trade est mise à jour automatiquement

3. **Fin de session** : Le fichier conserve son nom final avec toute la période de trading

---

## 📋 Nouvelles Colonnes CSV

Le fichier CSV contient maintenant les colonnes suivantes (ordre exact) :

```csv
Ticket,OpenTime,CloseTime,Symbol,Type,Volume,
OpenPrice,ClosePrice,SL,TP,Profit,Pips,
Commission,Swap,PlannedRR,ActualRR,
RSI,ATR,Spread,BBWidth,DistUpperBB,DistLowerBB,
EMA50,EMA100,
DistEMAFastSlow,EMASpread,EMATrend,PriceVsEMA,
DivAngle,DivStrength,DivBars,
Hour,Minute,DayOfWeek,
Duration,MaxProfit,MaxDD,ExitReason,Mode,Divergence,EMAMode
```

### Exemple de ligne

```csv
123456,2024-10-01 10:30:00,2024-10-01 12:45:00,EURUSD,BUY,0.10,
1.10500,1.10650,1.10300,1.10800,15.00,15.0,
-0.50,0.00,1.50,2.00,
45.5,0.00085,1.5,125.5,85.2,40.3,
1.10350,1.10250,
10.0,0.0905,UP,ABOVE_BOTH,
35.50,0.000125,8,
10,30,1,
135,20.50,-5.25,TP,REVERSION,YES,COUNTER
```

---

## 🔧 Compatibilité

### Avec le code existant

✅ **Aucune modification nécessaire** dans vos EAs existants !

Les nouvelles fonctionnalités sont :
- **Rétrocompatibles** : Tous les appels existants fonctionnent
- **Optionnelles** : Les métriques de divergence sont à 0 si non utilisées
- **Automatiques** : Les métriques EMA sont calculées automatiquement

### Méthodes inchangées

```cpp
// Ces appels fonctionnent exactement comme avant
tracker.RecordTradeOpen(ticket, mode, isDivergence, emaMode);
tracker.UpdateTrade(ticket);
tracker.RecordTradeClose(ticket, reason);
```

### Nouvelle méthode (optionnelle)

```cpp
// Seulement si vous utilisez la validation par divergence
tracker.SetDivergenceData(angle, strength, bars);
```

---

## 📊 Exemple d'Analyse

### Requête SQL sur le CSV (avec Python/Pandas)

```python
import pandas as pd

# Charger le CSV
df = pd.read_csv('TradeAnalysis_EURUSD_H1_20241001_20241231.csv')

# Analyser les trades selon la tendance EMA
trend_analysis = df.groupby('EMATrend').agg({
    'Profit': ['sum', 'mean'],
    'Ticket': 'count'
})

print("Performance par tendance EMA:")
print(trend_analysis)

# Analyser les trades avec divergence
div_trades = df[df['Divergence'] == 'YES']
print(f"\nTrades avec divergence: {len(div_trades)}")
print(f"Win rate: {(div_trades['Profit'] > 0).mean() * 100:.1f}%")

# Position du prix vs EMAs
position_analysis = df.groupby('PriceVsEMA').agg({
    'Profit': ['sum', 'mean'],
    'Ticket': 'count'
})

print("\nPerformance par position prix/EMA:")
print(position_analysis)
```

---

## 🎯 Cas d'Usage

### 1. Filtrer les trades selon la tendance

```cpp
// Dans votre stratégie
if(rec.emaTrend == "UP" && rec.emaSpread > 0.3) {
   // Seulement trades BUY en tendance forte
}
```

### 2. Analyser l'impact des divergences

```python
# Dans votre analyse Python
strong_div = df[(df['DivStrength'] > 0.0001) & (df['DivBars'] > 5)]
print(f"Win rate divergences fortes: {(strong_div['Profit'] > 0).mean()}")
```

### 3. Optimiser selon la position prix/EMA

```python
# Trouver la meilleure configuration
best_position = df.groupby(['EMATrend', 'PriceVsEMA'])['Profit'].sum()
print(best_position.sort_values(ascending=False))
```

---

## ⚠️ Notes Importantes

1. **Calcul des métriques EMA** : Automatique à chaque ouverture de trade
2. **Données de divergence** : Doivent être définies manuellement via `SetDivergenceData()`
3. **Renommage du fichier** : Automatique, peut prendre quelques ms
4. **Fichier temporaire** : Existe jusqu'au premier trade, puis est renommé
5. **Performance** : Impact négligeable sur les performances de l'EA

---

## 📝 Checklist d'Intégration

- [x] Installer le nouveau `JT_TradeTracker.mqh`
- [x] Compiler vos EAs (pas de modification nécessaire)
- [ ] Si vous utilisez la divergence, implémenter `SetDivergenceData()`
- [ ] Tester avec un backtest
- [ ] Vérifier la création du fichier CSV avec le nouveau format
- [ ] Analyser les nouvelles métriques dans vos rapports

---

## 🆘 Support

En cas de problème :
1. Vérifier que tous les fichiers sont à jour
2. Compiler avec succès sans erreurs
3. Vérifier les logs pour les messages du tracker
4. Le fichier CSV doit contenir les nouvelles colonnes

Date de mise à jour : 2025-10-11
Version : 2.0

