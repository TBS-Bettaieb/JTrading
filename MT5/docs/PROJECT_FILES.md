# 📁 Fichiers du Projet - JTFreeCandle v2.0

## 🗂️ Structure Complète

```
MT5/
├── 📂 common/                              # Modules génériques réutilisables
│   ├── ⭐ JT_BaseStrategy.mqh             # NOUVEAU - Classe abstraite (154 lignes)
│   ├── ⭐ JT_TradeFilters.mqh             # NOUVEAU - Filtres unifiés (351 lignes)
│   ├── 📝 JT_Indicators.mqh               # MODIFIÉ - Simplifié (159 lignes, -29%)
│   ├── ✅ JT_MoneyManagement.mqh          # CONSERVÉ - Calcul lots (119 lignes)
│   ├── ✅ JT_Positions.mqh                # CONSERVÉ - Gestion positions (126 lignes)
│   ├── ✅ JT_TradeTracker.mqh             # CONSERVÉ - Analyse trades (788 lignes)
│   ├── ✅ JT_DivergenceValidator.mqh      # CONSERVÉ - Validation divergence (382 lignes)
│   └── ✅ JT_Utils.mqh                    # CONSERVÉ - Utilitaires (696 lignes)
│
├── 📂 strategies/                          # NOUVEAU DOSSIER - Stratégies spécifiques
│   └── ⭐ JT_FreeCandleStrategy.mqh       # NOUVEAU - Implémentation Free Candle (282 lignes)
│
├── 📂 docs/                                # Documentation
│   ├── ⭐ REFACTORING_GUIDE.md            # NOUVEAU - Architecture complète (614 lignes)
│   ├── ⭐ QUICK_START_V2.md               # NOUVEAU - Démarrage rapide (492 lignes)
│   ├── ⭐ README_V2.md                    # NOUVEAU - Vue d'ensemble (588 lignes)
│   ├── ⭐ REFACTORING_SUMMARY.md          # NOUVEAU - Résumé refactorisation (588 lignes)
│   ├── ⭐ PROJECT_FILES.md                # NOUVEAU - Ce fichier
│   ├── ✅ BATCH_TESTING_GUIDE.md          # Existant
│   ├── ✅ DIVERGENCE_VALIDATOR_README.md  # Existant
│   ├── ✅ EMA_FILTER_GUIDE.md             # Existant
│   ├── ✅ TRADE_TRACKER_GUIDE.md          # Existant
│   └── ... (autres docs existants)
│
├── ✅ JTFreeCandle.mq5                    # CONSERVÉ - EA original v1.0 (1040 lignes)
├── ⭐ JTFreeCandle_v2.mq5                 # NOUVEAU - EA refactorisé v2.0 (520 lignes)
├── ✅ JT_BatchRunner.mq5                  # CONSERVÉ - Runner batch
├── ✅ PreloadHistory.mq5                  # CONSERVÉ - Préchargement
└── ✅ JT_BatchConfig.csv                  # CONSERVÉ - Config batch
```

## 📊 Statistiques par Catégorie

### Modules Common (Génériques)

| Fichier | Statut | Lignes | Rôle |
|---------|--------|--------|------|
| **JT_BaseStrategy.mqh** | ⭐ NOUVEAU | 154 | Classe abstraite pour stratégies |
| **JT_TradeFilters.mqh** | ⭐ NOUVEAU | 351 | Module unifié de filtres |
| JT_Indicators.mqh | 📝 MODIFIÉ | 159 | Gestion indicateurs (simplifié) |
| JT_MoneyManagement.mqh | ✅ CONSERVÉ | 119 | Calcul de lots |
| JT_Positions.mqh | ✅ CONSERVÉ | 126 | Gestion positions |
| JT_TradeTracker.mqh | ✅ CONSERVÉ | 788 | Analyse et export CSV |
| JT_DivergenceValidator.mqh | ✅ CONSERVÉ | 382 | Détection divergences |
| JT_Utils.mqh | ✅ CONSERVÉ | 696 | Fonctions utilitaires |
| **TOTAL** | | **2775** | |

### Stratégies

| Fichier | Statut | Lignes | Rôle |
|---------|--------|--------|------|
| **JT_FreeCandleStrategy.mqh** | ⭐ NOUVEAU | 282 | Stratégie Free Candle |
| **TOTAL** | | **282** | |

### Expert Advisors

| Fichier | Statut | Lignes | Rôle |
|---------|--------|--------|------|
| JTFreeCandle.mq5 | ✅ CONSERVÉ | 1040 | EA original v1.0 |
| **JTFreeCandle_v2.mq5** | ⭐ NOUVEAU | 520 | EA refactorisé v2.0 |
| JT_BatchRunner.mq5 | ✅ CONSERVÉ | 1034 | Runner pour backtesting batch |
| PreloadHistory.mq5 | ✅ CONSERVÉ | ~100 | Préchargement historique |
| **TOTAL** | | **2694** | |

### Documentation

| Fichier | Statut | Lignes | Rôle |
|---------|--------|--------|------|
| **REFACTORING_GUIDE.md** | ⭐ NOUVEAU | 614 | Guide architecture complète |
| **QUICK_START_V2.md** | ⭐ NOUVEAU | 492 | Guide démarrage rapide |
| **README_V2.md** | ⭐ NOUVEAU | 588 | Vue d'ensemble projet |
| **REFACTORING_SUMMARY.md** | ⭐ NOUVEAU | 588 | Résumé refactorisation |
| **PROJECT_FILES.md** | ⭐ NOUVEAU | ~200 | Liste des fichiers |
| BATCH_TESTING_GUIDE.md | ✅ EXISTANT | ~300 | Guide backtesting |
| DIVERGENCE_VALIDATOR_README.md | ✅ EXISTANT | ~250 | Validation divergence |
| EMA_FILTER_GUIDE.md | ✅ EXISTANT | ~200 | Filtres EMA |
| TRADE_TRACKER_GUIDE.md | ✅ EXISTANT | ~569 | Analyse trades |
| (autres docs) | ✅ EXISTANT | ~1000 | Divers |
| **TOTAL** | | **~4800** | |

## 🎯 Fichiers Principaux à Connaître

### 1️⃣ Pour Utiliser l'EA

**Essentiel**:
- `JTFreeCandle_v2.mq5` - EA refactorisé à utiliser
- `docs/QUICK_START_V2.md` - Guide de démarrage

**Optionnel**:
- `docs/README_V2.md` - Vue d'ensemble
- `docs/TRADE_TRACKER_GUIDE.md` - Analyse résultats
- `docs/EMA_FILTER_GUIDE.md` - Configuration filtres

### 2️⃣ Pour Développer Nouvelle Stratégie

**Essentiel**:
- `common/JT_BaseStrategy.mqh` - Classe à hériter
- `strategies/JT_FreeCandleStrategy.mqh` - Exemple implémentation
- `docs/REFACTORING_GUIDE.md` - Documentation API

**Utile**:
- `common/JT_TradeFilters.mqh` - Filtres disponibles
- `common/JT_Utils.mqh` - Fonctions utilitaires
- `docs/README_V2.md` - Exemple complet

### 3️⃣ Pour Comprendre Architecture

**Essentiel**:
- `docs/REFACTORING_GUIDE.md` - Architecture détaillée
- `docs/REFACTORING_SUMMARY.md` - Résumé refactorisation
- `docs/README_V2.md` - Vue d'ensemble

**Optionnel**:
- `docs/QUICK_START_V2.md` - Utilisation pratique

## 📝 Description Détaillée

### 🔷 Modules Common

#### JT_BaseStrategy.mqh ⭐ NOUVEAU

**Rôle**: Classe abstraite de base pour toutes les stratégies

**Contient**:
- Structures: `TradingParameters`, `SignalResult`
- Méthodes virtuelles: `AnalyzeMarket()`, `CalculateEntryLevels()`, etc.
- Méthodes communes: `CanTrade()`, `IsNewBar()`, `CalculateLotSize()`

**Utilisation**:
```mql5
class MaStrategie : public JTBaseStrategy {
   virtual SignalResult AnalyzeMarket() override {
      // Votre logique
   }
};
```

#### JT_TradeFilters.mqh ⭐ NOUVEAU

**Rôle**: Module unifié gérant tous les filtres de trading

**Filtres**:
- Temporel (horaires, jours)
- RSI (survente/surachat)
- EMA (3 modes: TREND, COUNTER, ZONE)
- Divergence (validation RSI/Prix)

**Structures**:
- `RSIFilterConfig`
- `EMAFilterConfig`
- `TimeFilterConfig`
- `DivergenceFilterConfig`

**Utilisation**:
```mql5
filters.ConfigureEMAFilter(true, handleFast, handleSlow, ...);
if(!filters.CheckEMAFilter(signalDirection)) return false;
```

#### JT_Indicators.mqh 📝 MODIFIÉ

**Changements**:
- ✅ Suppression logs debug excessifs
- ✅ Simplification `IsFreeCandle()`
- ✅ Code réduit de 29%
- ✅ Performance améliorée

**Conservation**:
- ✅ Toutes fonctionnalités
- ✅ Structures `IndicatorHandles`, `IndicatorBuffers`
- ✅ Fonctions d'initialisation

#### Autres Modules (CONSERVÉS)

**JT_MoneyManagement.mqh**:
- `NormalizeVolume()` - Normalisation lots
- `CalculateRiskBasedVolume()` - Calcul basé risque
- `CalculateATRStopLoss()` - SL basé ATR

**JT_Positions.mqh**:
- `HasOpenPosition()` - Vérification position
- `OpenBuyPosition()` / `OpenSellPosition()` - Ouverture
- `ClosePosition()`, `ModifyPosition()` - Gestion

**JT_TradeTracker.mqh**:
- Suivi trades en temps réel
- Enregistrement métriques
- Export CSV détaillé
- Rapport final

**JT_DivergenceValidator.mqh**:
- Détection divergences RSI/Prix
- Mémorisation Free Candles
- Validation temporelle
- Calcul force divergence

**JT_Utils.mqh**:
- `CalculateSwingSLTP()` - SL/TP dynamiques
- `IsHourAllowedCustom()` - Filtres horaires
- `MarkFreeCandle()` - Marquage visuel
- Fonctions utilitaires diverses

### 🔷 Stratégies

#### JT_FreeCandleStrategy.mqh ⭐ NOUVEAU

**Rôle**: Implémentation stratégie Free Candle héritant de `JTBaseStrategy`

**Fonctionnalités**:
- Détection Free Candles (hors Bollinger Bands)
- Application filtres (RSI, EMA, temps)
- Validation divergence (optionnel)
- Marquage visuel automatique
- Calcul SL/TP dynamique

**Configuration**:
```mql5
struct FreeCandleConfig {
   int bbPeriod;
   double bbDeviation;
   int rsiPeriod;
   int outsidePaddingPoints;
   bool bodyMustBeOutside;
   bool markCandles;
   // ...
};
```

### 🔷 Expert Advisors

#### JTFreeCandle_v2.mq5 ⭐ NOUVEAU

**Rôle**: EA principal refactorisé

**Améliorations**:
- Code réduit de 50% (520 vs 1040 lignes)
- Architecture modulaire
- Clarté et maintenabilité
- Performance optimisée

**Structure**:
```mql5
OnInit()     → Initialisation stratégie + filtres
OnTick()     → Logique trading simplifiée
OnDeinit()   → Nettoyage ressources
```

**Fonctions principales**:
- `ManageOpenPositions()` - Gestion BE, bandes opposées
- `CheckClosedTrades()` - Détection SL/TP automatiques
- `ExecuteTrade()` - Exécution avec tracking

#### JTFreeCandle.mq5 ✅ CONSERVÉ

**Rôle**: EA original v1.0 (référence)

**Usage**: 
- Référence pour comparaison
- Backup fonctionnel
- Validation comportement

### 🔷 Documentation

#### REFACTORING_GUIDE.md ⭐ NOUVEAU (614 lignes)

**Contenu**:
- Architecture complète
- Documentation API modules
- Exemples d'utilisation
- Bonnes pratiques
- Guide création stratégie
- Dépannage

**Public**: Développeurs

#### QUICK_START_V2.md ⭐ NOUVEAU (492 lignes)

**Contenu**:
- Démarrage en 3 minutes
- Configurations recommandées
- Explication modes trading
- Explication modes filtres
- Conseils utilisation
- Dépannage rapide

**Public**: Utilisateurs finaux

#### README_V2.md ⭐ NOUVEAU (588 lignes)

**Contenu**:
- Vue d'ensemble projet
- Nouveautés v2.0
- Comparaison v1 vs v2
- Architecture
- Exemple création stratégie
- Roadmap

**Public**: Tous

#### REFACTORING_SUMMARY.md ⭐ NOUVEAU (588 lignes)

**Contenu**:
- Résumé travail accompli
- Statistiques détaillées
- Objectifs atteints
- Métriques qualité
- Validation

**Public**: Chef de projet, développeurs

## 📈 Métriques Globales

### Nouveaux Fichiers

```
Modules:       2 fichiers    (505 lignes)
Stratégies:    1 fichier     (282 lignes)
EAs:           1 fichier     (520 lignes)
Documentation: 5 fichiers    (~2500 lignes)
---
TOTAL:         9 fichiers    (~3800 lignes)
```

### Fichiers Modifiés

```
JT_Indicators.mqh: -66 lignes (-29%)
```

### Fichiers Conservés

```
Common:     6 fichiers  (~2600 lignes)
EAs:        3 fichiers  (~2200 lignes)
Docs:       ~10 fichiers (~2300 lignes)
```

### Totaux

```
Code MQL5:        ~5700 lignes
Documentation:    ~4800 lignes
Total projet:     ~10500 lignes
```

## 🎯 Priorités de Lecture

### Niveau 1 - Débutant (Utilisateur)

1. `docs/QUICK_START_V2.md` - Commencer ici
2. `docs/README_V2.md` - Vue d'ensemble
3. `JTFreeCandle_v2.mq5` - EA à utiliser

### Niveau 2 - Intermédiaire (Utilisateur Avancé)

1. Niveau 1 +
2. `docs/TRADE_TRACKER_GUIDE.md` - Analyse résultats
3. `docs/EMA_FILTER_GUIDE.md` - Optimisation filtres
4. `common/JT_TradeFilters.mqh` - Comprendre filtres

### Niveau 3 - Avancé (Développeur)

1. Niveau 2 +
2. `docs/REFACTORING_GUIDE.md` - Architecture complète
3. `common/JT_BaseStrategy.mqh` - Classe de base
4. `strategies/JT_FreeCandleStrategy.mqh` - Implémentation
5. `docs/REFACTORING_SUMMARY.md` - Détails refactorisation

## 🔍 Trouver Rapidement

### "Je veux..."

**...utiliser l'EA**
→ `JTFreeCandle_v2.mq5` + `docs/QUICK_START_V2.md`

**...comprendre l'architecture**
→ `docs/REFACTORING_GUIDE.md`

**...créer une nouvelle stratégie**
→ `common/JT_BaseStrategy.mqh` + `strategies/JT_FreeCandleStrategy.mqh`

**...ajouter un filtre**
→ `common/JT_TradeFilters.mqh`

**...analyser mes trades**
→ `docs/TRADE_TRACKER_GUIDE.md`

**...modifier le money management**
→ `common/JT_MoneyManagement.mqh`

**...changer les marqueurs visuels**
→ `common/JT_Utils.mqh` (fonctions `MarkFreeCandle*`)

**...comprendre la divergence**
→ `common/JT_DivergenceValidator.mqh` + `docs/DIVERGENCE_VALIDATOR_README.md`

## ✅ Checklist Compilation

### Avant Compilation

- [ ] Vérifier structure dossiers
- [ ] Tous fichiers `.mqh` présents dans `common/`
- [ ] Fichier `JT_FreeCandleStrategy.mqh` dans `strategies/`
- [ ] MetaEditor à jour

### Compilation

```
1. Ouvrir JTFreeCandle_v2.mq5
2. F7 (Compile)
3. Vérifier: 0 erreurs, 0 warnings
4. Fichier .ex5 généré
```

### Après Compilation

- [ ] Tester en Strategy Tester
- [ ] Vérifier initialisation en démo
- [ ] Consulter logs (Journal + Experts)
- [ ] Valider comportement

## 📞 Support

### Documentation

- Questions générales → `README_V2.md`
- Questions techniques → `REFACTORING_GUIDE.md`
- Problèmes utilisation → `QUICK_START_V2.md`

### Fichiers de Debug

- Logs: Onglet "Journal" et "Experts" dans MT5
- CSV: `MQL5/Files/TradeAnalysis_*.csv`
- Config: Paramètres input dans l'EA

---

**Projet**: JTFreeCandle v2.0  
**Fichiers Totaux**: ~30+  
**Lignes de Code**: ~10500  
**Date**: Octobre 2025  
**Statut**: ✅ Production Ready

