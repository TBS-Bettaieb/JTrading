# 🚀 Guide de Démarrage Rapide - JTFreeCandle v2.0

## ⚡ Démarrage en 3 Minutes

### 1. Compilation

Dans MetaEditor:
```
1. Ouvrir MT5/JTFreeCandle_v2.mq5
2. Appuyer sur F7 (Compiler)
3. Vérifier qu'il n'y a pas d'erreurs
```

### 2. Installation

```
1. Dans MetaTrader 5, onglet "Navigateur"
2. Expert Advisors → JTFreeCandle_v2
3. Glisser-déposer sur le graphique
```

### 3. Configuration Rapide

#### Configuration Recommandée pour Débutants

**Symbole**: EURUSD  
**Timeframe**: H1  

**Paramètres**:
```
═══ Bollinger Bands ═══
BB_Period = 20
BB_Dev = 2.0

═══ RSI - Filtre de confirmation ═══
Use_RSI_Filter = true
RSI_Period = 14
RSI_Oversold = 29.0
RSI_Overbought = 71.0

═══ EMA - Filtre de tendance ═══
Use_EMA_Filter = true
EMA_Fast_Period = 50
EMA_Slow_Period = 100
EMA_Filter_Mode = EMA_TREND (0)

═══ Validateur de Divergence ═══
Use_Divergence_Validator = true
Div_RSI_Buy_Level = 35.0
Div_RSI_Sell_Level = 65.0

═══ Mode d'Entrée ═══
Mode = REVERSION (0)
TradeDir = DIR_BOTH (0)

═══ Money Management ═══
Risk_Percent = 0.1  (0.1% par trade)
One_Pos_Per_Symbol = true
Magic = 20251007

═══ Stop Loss & Take Profit ═══
SL_Period = 50
TP_Period = 30
Min_RR = 2.0
ATR_Multiplier = 2.0
ATR_Period = 14

═══ Filtre Horaire ═══
UseTimeFilter = true
HourRanges = "8-10;16"  (8h-10h et 16h-17h)

═══ Gestion de Position ═══
Close_On_OppositeBand = true
BE_On_MiddleBand = true
```

## 📊 Différences Principales avec v1.0

| Fonctionnalité | v1.0 | v2.0 |
|----------------|------|------|
| Architecture | Monolithique | Modulaire |
| Code EA | ~1040 lignes | ~520 lignes |
| Réutilisabilité | Faible | Élevée |
| Maintenance | Difficile | Facile |
| Extensibilité | Limitée | Excellente |
| Performance | Bonne | Meilleure |

## 🎯 Modes de Trading

### Mode REVERSION (Recommandé)

**Principe**: Trade le retour à la moyenne après excès

**Signaux**:
- ✅ **BUY**: Bougie verte sous bande inférieure + RSI < 29
- ✅ **SELL**: Bougie rouge au-dessus bande supérieure + RSI > 71

**Quand utiliser**:
- Marchés range-bound
- Après forte volatilité
- Sur indices et forex

### Mode BREAKOUT

**Principe**: Trade la cassure des bandes

**Signaux**:
- ✅ **BUY**: Bougie au-dessus bande supérieure
- ✅ **SELL**: Bougie sous bande inférieure

**Quand utiliser**:
- Tendances fortes
- Breakouts de consolidation
- News importantes

## 🎚️ Modes de Filtre EMA

### EMA_TREND (Par défaut)

**Principe**: Trade dans le sens de la tendance

**Conditions BUY**:
- EMA50 > EMA100
- Prix > EMA100

**Conditions SELL**:
- EMA50 < EMA100
- Prix < EMA100

**Idéal pour**: Marchés trending, suivi de tendance

---

### EMA_COUNTER

**Principe**: Trade les retournements aux extrêmes

**Conditions BUY**:
- Prix < EMA50 (downtrend)
- Distance > 20 points

**Conditions SELL**:
- Prix > EMA50 (uptrend)
- Distance > 20 points

**Idéal pour**: Marchés volatils, reversions extrêmes

---

### EMA_ZONE

**Principe**: Évite la zone de confusion entre EMAs

**Conditions**:
- Trade uniquement si prix hors zone EMA50-EMA100 ± 20pts

**Idéal pour**: Éviter les faux signaux, trades clairs

## 🔧 Validation par Divergence

### Comment ça marche ?

1. **Détection**: Free Candle détecté et mémorisé
2. **Observation**: Attente de formation pivot RSI/Prix
3. **Validation**: 
   - **BUY**: Prix fait LL mais RSI fait HL
   - **SELL**: Prix fait HH mais RSI fait LH
4. **Exécution**: Trade uniquement si divergence confirmée

### Avantages

- ✅ Réduit les faux signaux
- ✅ Meilleure qualité de trades
- ✅ Win rate plus élevé

### Inconvénients

- ⚠️ Moins de trades
- ⚠️ Attente plus longue
- ⚠️ Peut rater certains mouvements rapides

## 📈 Gestion de Position

### Break-Even Automatique

**Activation**: `BE_On_MiddleBand = true`

**Fonctionnement**:
- Position BUY: SL → prix d'entrée quand prix touche médiane BB
- Position SELL: SL → prix d'entrée quand prix touche médiane BB

**Offset**: `BE_Offset_Points` (points de profit garantis)

---

### Sortie Bande Opposée

**Activation**: `Close_On_OppositeBand = true`

**Fonctionnement**:
- Position BUY: Ferme si prix touche bande supérieure
- Position SELL: Ferme si prix touche bande inférieure

**Avantage**: Prend profit aux extrêmes

---

### Flat Time

**Activation**: `UseFlatTime = true`

**Fonctionnement**:
- Ferme toutes positions à heure spécifiée
- Évite risques overnight ou weekend

**Configuration**:
```
Flat_Hour = 23
Flat_Minute = 40
```

## 📝 Marqueurs Visuels

### Types de Marqueurs

**Free Candle Standard** (Vert/Rouge):
- Ligne verticale pointillée
- Flèche ↑ (BUY) ou ↓ (SELL)
- Optionnel: Rectangle, Texte

**Free Candle Divergence** (Vert/Rouge brillant):
- Ligne verticale pleine
- Flèche large
- Texte "DIV"

### Configuration

```
Mark_FreeCandles = true   // Activer marqueurs
Mark_DrawVLine = true     // Ligne verticale
Mark_DrawArrow = true     // Flèche
Mark_DrawBox = false      // Rectangle (optionnel)
Mark_DrawText = false     // Texte (optionnel)
```

## 📊 Analyse des Résultats

### Fichiers CSV Générés

**Emplacement**: `MQL5/Files/TradeAnalysis_[SYMBOL]_[MAGIC].csv`

**Contenu**:
- Tous les trades avec détails
- Métriques de divergence
- Configuration EA
- Analyse performance

### Colonnes Principales

```
Ticket, OpenTime, CloseTime, Type, Lots,
OpenPrice, ClosePrice, SL, TP,
Profit, MaxProfit, MaxDrawdown,
Duration, TradeMode, Divergence,
DivAngle, DivStrength, DivBars,
RSI_Entry, BB_Period, EMA_Mode, ...
```

## 🎓 Conseils d'Utilisation

### ✅ Bonnes Pratiques

1. **Backtesting**
   - Tester sur 6-12 mois de données
   - Vérifier différents timeframes
   - Analyser les résultats CSV

2. **Démo en Direct**
   - Minimum 1 mois en démo
   - Vérifier comportement en temps réel
   - Valider avec conditions réelles

3. **Démarrage Progressif**
   - Commencer avec `Risk_Percent = 0.1%`
   - Un seul symbole au début
   - Augmenter progressivement

4. **Monitoring**
   - Vérifier logs régulièrement
   - Analyser fichiers CSV
   - Ajuster paramètres si nécessaire

### ❌ Erreurs à Éviter

1. **Sur-optimisation**
   - Ne pas optimiser sur données courtes
   - Éviter trop de paramètres
   - Garder simplicité

2. **Risque Excessif**
   - Ne jamais dépasser 2% par trade
   - Diversifier symboles
   - Limiter positions simultanées

3. **Négliger les Filtres**
   - Ne pas trader 24/7
   - Respecter horaires configurés
   - Éviter périodes volatiles (news)

4. **Ignorer les Résultats**
   - Analyser CSV régulièrement
   - Apprendre des trades perdants
   - Ajuster stratégie

## 🔍 Dépannage Rapide

### Pas de Trades Générés

**Causes possibles**:
1. Filtres trop restrictifs
2. Pas de Free Candles détectés
3. Hors horaires autorisés
4. Position déjà ouverte

**Solutions**:
```mql5
// Dans les logs, chercher:
"Heure actuelle non autorisée"
"Position déjà ouverte"
"Signal rejeté par filtre EMA/RSI"
"Pas de Free Candle détectée"
```

### Trades Perdants Consécutifs

**Causes possibles**:
1. Mauvaises conditions de marché
2. Paramètres non adaptés
3. Timeframe incorrect

**Solutions**:
1. Analyser le CSV
2. Vérifier type de marché (trending vs range)
3. Ajuster filtres ou arrêter temporairement

### Erreurs de Compilation

**Causes possibles**:
1. Fichiers `.mqh` manquants
2. Chemins incorrects
3. Cache MetaEditor

**Solutions**:
```
1. Vérifier structure dossiers
2. Recompiler tous les .mqh
3. Tools → Options → Clean cache
4. Redémarrer MetaEditor
```

## 📚 Ressources Supplémentaires

### Documentation

- `REFACTORING_GUIDE.md` - Architecture complète
- `TRADE_TRACKER_GUIDE.md` - Analyse des trades
- `EMA_FILTER_GUIDE.md` - Filtres EMA détaillés

### Fichiers Clés

```
JTFreeCandle_v2.mq5         - EA principal
JT_FreeCandleStrategy.mqh   - Logique stratégie
JT_BaseStrategy.mqh         - Classe de base
JT_TradeFilters.mqh         - Tous les filtres
```

## 🎯 Configurations Pré-définies

### Configuration "Conservative"

```
Risk_Percent = 0.1
Min_RR = 2.5
Use_RSI_Filter = true
Use_EMA_Filter = true (TREND)
Use_Divergence_Validator = true
```

### Configuration "Balanced"

```
Risk_Percent = 0.2
Min_RR = 2.0
Use_RSI_Filter = true
Use_EMA_Filter = true (TREND)
Use_Divergence_Validator = false
```

### Configuration "Aggressive"

```
Risk_Percent = 0.5
Min_RR = 1.5
Use_RSI_Filter = false
Use_EMA_Filter = false
Use_Divergence_Validator = false
```

⚠️ **Attention**: Mode Aggressive = Plus de trades mais plus de risque !

## 🆘 Support

En cas de problème:
1. Vérifier les logs dans "Journal" et "Experts"
2. Consulter le fichier CSV pour analyse
3. Tester en compte démo d'abord
4. Vérifier la documentation complète

---

**Version**: 2.0  
**Date**: Octobre 2025  
**Bon trading !** 🚀

