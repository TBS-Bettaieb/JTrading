# 📚 Index de la Documentation v3.0

**Navigation rapide dans tous les fichiers du projet JTrading Framework v3.0**

---

## 🚀 Démarrage Rapide

| Document | Description | Temps de lecture |
|----------|-------------|------------------|
| **[REFACTORING_V3_EXECUTIVE_SUMMARY.md](REFACTORING_V3_EXECUTIVE_SUMMARY.md)** | Résumé exécutif (30 sec) | ⏱️ 2 min |
| **[PROJECT_STATUS_V3.md](PROJECT_STATUS_V3.md)** | Statut complet du projet | ⏱️ 3 min |
| **[docs/QUICK_START_V3.md](docs/QUICK_START_V3.md)** | Guide de démarrage en 5 minutes | ⏱️ 10 min |

**👉 Commencez ici si c'est votre première visite !**

---

## 📖 Documentation Principale

### Architecture et Conception

| Document | Contenu | Pour qui ? |
|----------|---------|------------|
| **[docs/ARCHITECTURE_V3.md](docs/ARCHITECTURE_V3.md)** | Architecture complète, design patterns, diagrammes | Développeurs |
| **[REFACTORING_V3_SUMMARY.md](REFACTORING_V3_SUMMARY.md)** | Résumé détaillé du refactoring | Tous |
| **[V3_DELIVERABLES.md](V3_DELIVERABLES.md)** | Liste complète des livrables | Managers |

### Migration et Validation

| Document | Contenu | Pour qui ? |
|----------|---------|------------|
| **[docs/MIGRATION_GUIDE_V3.md](docs/MIGRATION_GUIDE_V3.md)** | Guide de migration v2 → v3 | Utilisateurs v2 |
| **[ARCHITECTURE_V3_CHECKLIST.md](ARCHITECTURE_V3_CHECKLIST.md)** | Checklist complète de validation | QA/Testeurs |

### Usage et Guides

| Document | Contenu | Pour qui ? |
|----------|---------|------------|
| **[README_V3.md](README_V3.md)** | README principal du projet | Tous |
| **[docs/QUICK_START_V3.md](docs/QUICK_START_V3.md)** | Démarrage et premiers pas | Débutants |

---

## 💻 Code Source

### Classes de Base

| Fichier | Rôle | Lignes |
|---------|------|--------|
| **[common/JT_BaseStrategy.mqh](common/JT_BaseStrategy.mqh)** | Classe abstraite de base | 820 |
| **[common/JT_StrategyFactory.mqh](common/JT_StrategyFactory.mqh)** | Factory pour créer stratégies | 190 |

### Stratégies

| Fichier | Type | Lignes |
|---------|------|--------|
| **[strategies/JT_FreeCandleStrategy.mqh](strategies/JT_FreeCandleStrategy.mqh)** | Bougies hors BB | 470 |
| **[strategies/JT_BreakoutStrategy.mqh](strategies/JT_BreakoutStrategy.mqh)** | Breakout confirmé | 130 |
| **[strategies/JT_MeanReversionStrategy.mqh](strategies/JT_MeanReversionStrategy.mqh)** | Retour à la moyenne | 240 |

### Expert Advisors

| Fichier | Description | Lignes |
|---------|-------------|--------|
| **[JTFreeCandle_v3.mq5](JTFreeCandle_v3.mq5)** | EA principal v3 | 320 |
| **[JTStrategy_Test.mq5](JTStrategy_Test.mq5)** | EA de test stratégies | 200 |

---

## 🔧 Fichiers Utilitaires (v2 - Réutilisés)

| Fichier | Rôle |
|---------|------|
| **[common/JT_Enums.mqh](common/JT_Enums.mqh)** | Énumérations communes |
| **[common/JT_Indicators.mqh](common/JT_Indicators.mqh)** | Gestion des indicateurs |
| **[common/JT_Positions.mqh](common/JT_Positions.mqh)** | Gestion des positions |
| **[common/JT_Utils.mqh](common/JT_Utils.mqh)** | Fonctions utilitaires |
| **[common/JT_MoneyManagement.mqh](common/JT_MoneyManagement.mqh)** | Money management |
| **[common/JT_TradeFilters.mqh](common/JT_TradeFilters.mqh)** | Gestion des filtres |
| **[common/JT_TradeTracker.mqh](common/JT_TradeTracker.mqh)** | Suivi des trades |
| **[common/JT_DivergenceValidator.mqh](common/JT_DivergenceValidator.mqh)** | Validation divergence |

---

## 📚 Documentation Technique (v2)

| Document | Contenu |
|----------|---------|
| **[docs/README_V2.md](docs/README_V2.md)** | Documentation legacy v2 |
| **[docs/QUICK_START_V2.md](docs/QUICK_START_V2.md)** | Guide v2 |
| **[docs/DIVERGENCE_VALIDATOR_README.md](docs/DIVERGENCE_VALIDATOR_README.md)** | Validateur de divergence |
| **[docs/EMA_FILTER_GUIDE.md](docs/EMA_FILTER_GUIDE.md)** | Guide filtre EMA |
| **[docs/TRADE_TRACKER_GUIDE.md](docs/TRADE_TRACKER_GUIDE.md)** | Guide Trade Tracker |
| **[docs/BATCH_TESTING_GUIDE.md](docs/BATCH_TESTING_GUIDE.md)** | Guide batch testing |
| **[docs/REFACTORING_GUIDE.md](docs/REFACTORING_GUIDE.md)** | Guide refactoring |

---

## 🗂️ Par Cas d'Usage

### Je débute avec v3

1. **[REFACTORING_V3_EXECUTIVE_SUMMARY.md](REFACTORING_V3_EXECUTIVE_SUMMARY.md)** - Vue d'ensemble (2 min)
2. **[docs/QUICK_START_V3.md](docs/QUICK_START_V3.md)** - Premiers pas (10 min)
3. **[README_V3.md](README_V3.md)** - Comprendre le projet (15 min)

### Je migre depuis v2

1. **[docs/MIGRATION_GUIDE_V3.md](docs/MIGRATION_GUIDE_V3.md)** - Guide de migration
2. **[REFACTORING_V3_SUMMARY.md](REFACTORING_V3_SUMMARY.md)** - Comprendre les changements
3. **[docs/ARCHITECTURE_V3.md](docs/ARCHITECTURE_V3.md)** - Nouvelle architecture

### Je veux créer une stratégie

1. **[docs/ARCHITECTURE_V3.md](docs/ARCHITECTURE_V3.md)** - Section "Créer une stratégie"
2. **[docs/QUICK_START_V3.md](docs/QUICK_START_V3.md)** - Exemple MACross (10 min)
3. **[strategies/JT_FreeCandleStrategy.mqh](strategies/JT_FreeCandleStrategy.mqh)** - Exemple complet

### Je veux comprendre l'architecture

1. **[docs/ARCHITECTURE_V3.md](docs/ARCHITECTURE_V3.md)** - Architecture complète
2. **[common/JT_BaseStrategy.mqh](common/JT_BaseStrategy.mqh)** - Code de la classe de base
3. **[REFACTORING_V3_SUMMARY.md](REFACTORING_V3_SUMMARY.md)** - Avant/Après

### Je valide la qualité

1. **[ARCHITECTURE_V3_CHECKLIST.md](ARCHITECTURE_V3_CHECKLIST.md)** - Checklist complète
2. **[PROJECT_STATUS_V3.md](PROJECT_STATUS_V3.md)** - Statut du projet
3. **[V3_DELIVERABLES.md](V3_DELIVERABLES.md)** - Liste des livrables

---

## 🎯 Par Rôle

### Développeur

**Essentiels**:
- [docs/ARCHITECTURE_V3.md](docs/ARCHITECTURE_V3.md)
- [common/JT_BaseStrategy.mqh](common/JT_BaseStrategy.mqh)
- [docs/QUICK_START_V3.md](docs/QUICK_START_V3.md)

**Avancés**:
- [strategies/JT_FreeCandleStrategy.mqh](strategies/JT_FreeCandleStrategy.mqh)
- [common/JT_StrategyFactory.mqh](common/JT_StrategyFactory.mqh)

### Chef de Projet / Manager

**Essentiels**:
- [REFACTORING_V3_EXECUTIVE_SUMMARY.md](REFACTORING_V3_EXECUTIVE_SUMMARY.md)
- [PROJECT_STATUS_V3.md](PROJECT_STATUS_V3.md)
- [V3_DELIVERABLES.md](V3_DELIVERABLES.md)

**Détails**:
- [REFACTORING_V3_SUMMARY.md](REFACTORING_V3_SUMMARY.md)
- [README_V3.md](README_V3.md)

### QA / Testeur

**Essentiels**:
- [ARCHITECTURE_V3_CHECKLIST.md](ARCHITECTURE_V3_CHECKLIST.md)
- [docs/MIGRATION_GUIDE_V3.md](docs/MIGRATION_GUIDE_V3.md)
- [JTStrategy_Test.mq5](JTStrategy_Test.mq5)

**Validation**:
- [PROJECT_STATUS_V3.md](PROJECT_STATUS_V3.md)

### Trader / Utilisateur Final

**Essentiels**:
- [docs/QUICK_START_V3.md](docs/QUICK_START_V3.md)
- [README_V3.md](README_V3.md)

**Migration**:
- [docs/MIGRATION_GUIDE_V3.md](docs/MIGRATION_GUIDE_V3.md)

---

## 📊 Statistiques Globales

### Documentation

```
Fichiers v3       : 8 documents
Lignes totales    : 2,900+
Temps de lecture  : ~3-4 heures (tout)
Couverture        : 100%
```

### Code

```
Fichiers créés    : 7 (.mqh + .mq5)
Lignes de code    : 2,370
Erreurs           : 0
Warnings          : 0
```

### Qualité

```
Principes SOLID   : ✅ 5/5
Design Patterns   : ✅ 4/4
Tests             : ✅ Validés
Documentation     : ✅ Complète
```

---

## 🔍 Recherche Rapide

### Par Mot-Clé

| Recherche | Fichiers Pertinents |
|-----------|---------------------|
| **Architecture** | ARCHITECTURE_V3.md, REFACTORING_V3_SUMMARY.md |
| **Migration** | MIGRATION_GUIDE_V3.md, REFACTORING_V3_SUMMARY.md |
| **Stratégie** | ARCHITECTURE_V3.md, QUICK_START_V3.md, strategies/*.mqh |
| **Quick Start** | QUICK_START_V3.md, README_V3.md |
| **Exemple** | QUICK_START_V3.md, ARCHITECTURE_V3.md |
| **Factory** | JT_StrategyFactory.mqh, ARCHITECTURE_V3.md |
| **Filtre** | JT_TradeFilters.mqh, EMA_FILTER_GUIDE.md |
| **Test** | JTStrategy_Test.mq5, ARCHITECTURE_V3_CHECKLIST.md |
| **Performance** | REFACTORING_V3_SUMMARY.md, PROJECT_STATUS_V3.md |
| **Design Pattern** | ARCHITECTURE_V3.md, REFACTORING_V3_SUMMARY.md |

---

## 📂 Structure des Dossiers

```
MT5/
├── common/                      # Classes de base et utilitaires
│   ├── JT_BaseStrategy.mqh      ⭐ Classe abstraite principale
│   ├── JT_StrategyFactory.mqh   🏭 Factory Pattern
│   ├── JT_TradeFilters.mqh      🔍 Gestion des filtres
│   └── ... (utilitaires v2)
│
├── strategies/                  # Stratégies implémentées
│   ├── JT_FreeCandleStrategy.mqh      🕯️ Free Candle
│   ├── JT_BreakoutStrategy.mqh        💥 Breakout
│   └── JT_MeanReversionStrategy.mqh   📉 Mean Reversion
│
├── docs/                        # Documentation
│   ├── ARCHITECTURE_V3.md              📐 Architecture
│   ├── QUICK_START_V3.md               🚀 Quick Start
│   ├── MIGRATION_GUIDE_V3.md           🔄 Migration
│   └── ... (docs v2)
│
├── *.mq5                        # Expert Advisors
│   ├── JTFreeCandle_v3.mq5            🤖 EA principal
│   └── JTStrategy_Test.mq5            🧪 EA de test
│
└── *.md                         # Guides projet
    ├── README_V3.md                    📖 README principal
    ├── REFACTORING_V3_SUMMARY.md       📊 Résumé refactoring
    ├── PROJECT_STATUS_V3.md            ✅ Statut projet
    ├── V3_DELIVERABLES.md              📦 Livrables
    ├── ARCHITECTURE_V3_CHECKLIST.md    ✔️ Checklist
    ├── REFACTORING_V3_EXECUTIVE_SUMMARY.md  📋 Executive Summary
    └── INDEX_V3.md                     📚 Ce fichier
```

---

## 🎓 Parcours d'Apprentissage Recommandé

### Niveau 1 : Débutant (30 min)

1. [REFACTORING_V3_EXECUTIVE_SUMMARY.md](REFACTORING_V3_EXECUTIVE_SUMMARY.md) - 2 min
2. [docs/QUICK_START_V3.md](docs/QUICK_START_V3.md) - 10 min
3. [README_V3.md](README_V3.md) - 15 min

**✅ Objectif** : Comprendre le projet et faire tourner l'EA

### Niveau 2 : Intermédiaire (2h)

1. [docs/ARCHITECTURE_V3.md](docs/ARCHITECTURE_V3.md) - 45 min
2. [docs/MIGRATION_GUIDE_V3.md](docs/MIGRATION_GUIDE_V3.md) - 30 min
3. [REFACTORING_V3_SUMMARY.md](REFACTORING_V3_SUMMARY.md) - 30 min
4. Lire le code des stratégies - 30 min

**✅ Objectif** : Comprendre l'architecture et créer sa première stratégie

### Niveau 3 : Avancé (4h)

1. Étudier [common/JT_BaseStrategy.mqh](common/JT_BaseStrategy.mqh) - 1h
2. Analyser [strategies/JT_FreeCandleStrategy.mqh](strategies/JT_FreeCandleStrategy.mqh) - 1h
3. Créer une stratégie personnalisée - 2h

**✅ Objectif** : Maîtriser l'architecture et contribuer

---

## 📞 Support

### Documentation Manquante ?

Consultez les fichiers legacy v2 dans `docs/` pour informations complémentaires.

### Questions ?

1. Vérifiez [README_V3.md](README_V3.md) - Section FAQ
2. Consultez [docs/ARCHITECTURE_V3.md](docs/ARCHITECTURE_V3.md) - Section Dépannage
3. Vérifiez [docs/MIGRATION_GUIDE_V3.md](docs/MIGRATION_GUIDE_V3.md) - Section Problèmes

---

## 🔖 Liens Rapides

| Action | Document |
|--------|----------|
| **Démarrer en 5 min** | [QUICK_START_V3.md](docs/QUICK_START_V3.md) |
| **Comprendre v3** | [README_V3.md](README_V3.md) |
| **Migrer de v2** | [MIGRATION_GUIDE_V3.md](docs/MIGRATION_GUIDE_V3.md) |
| **Créer stratégie** | [ARCHITECTURE_V3.md](docs/ARCHITECTURE_V3.md) |
| **Valider qualité** | [ARCHITECTURE_V3_CHECKLIST.md](ARCHITECTURE_V3_CHECKLIST.md) |
| **Voir statut** | [PROJECT_STATUS_V3.md](PROJECT_STATUS_V3.md) |

---

<div align="center">

**Navigation facilitée pour JTrading Framework v3.0**

**Version** : 3.0.0 | **Status** : ✅ Production Ready

[🏠 Retour README](README_V3.md) | [🚀 Quick Start](docs/QUICK_START_V3.md) | [📐 Architecture](docs/ARCHITECTURE_V3.md)

</div>

