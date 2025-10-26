# 📁 Structure du dossier `common/`

Ce dossier contient tous les composants partagés du système BreakoutScalper, organisés par thèmes pour une meilleure maintenabilité.

## 🗂️ Organisation par dossiers

### 📁 `config/` - Configuration et paramètres

- **`BotConfig.mqh`** : Structure de configuration du bot
- **`ConfigLoader.mqh`** : Chargement des configurations par symbole
- **`RiskMultiplierManager.mqh`** : Gestion des multiplicateurs de risque

### 📁 `trading/` - Gestion des ordres et positions

- **`OrderManager.mqh`** : Gestionnaire d'ordres générique
- **`TrailingManager.mqh`** : Gestion du trailing TP/TSL générique
- **`ForexTrailingManager.mqh`** : Gestion du trailing spécialisé Forex
- **`TrendlineManager.mqh`** : Gestion des lignes TP/SL sur graphique
- **`ForexTrendlineManager.mqh`** : Gestion des trendlines spécialisé Forex

### 📁 `analysis/` - Analyse technique et signaux

- **`SwingAnalyzer.mqh`** : Analyseur de swing points générique
- **`SignalDetectionManager.mqh`** : Détection des signaux de trading

### 📁 `status/` - Statut et monitoring

- **`SymbolStatus.mqh`** : Gestionnaire de statut par symbole
- **`BreakoutScalperStatus.mqh`** : Statut spécialisé BreakoutScalper
- **`SymbolDisplay.mqh`** : Affichage des informations de symbole

### 📁 `display/` - Affichage et visualisation

- **`BreakoutScalperTraderDisplay.mqh`** : Affichage spécialisé du trader

### 📁 `examples/` - Exemples et documentation

- **`Example_SignalDetection.mqh`** : Exemple d'utilisation du SignalDetectionManager

## 🔗 Dépendances entre dossiers

```
config/ → (aucune dépendance interne)
trading/ → (aucune dépendance interne)
analysis/ → status/
status/ → (aucune dépendance interne)
display/ → status/, analysis/
examples/ → analysis/
```

## 📝 Conventions

- **Fichiers génériques** : Sans préfixe (ex: `OrderManager.mqh`)
- **Includes** : Utiliser des chemins relatifs appropriés selon la localisation

## 🚀 Utilisation

### Inclure un fichier de configuration

```mql5
#include "../common/config/BotConfig.mqh"
```

### Inclure un gestionnaire de trading

```mql5
#include "../common/trading/OrderManager.mqh"
```

### Inclure un analyseur

```mql5
#include "../common/analysis/SignalDetectionManager.mqh"
```

### Inclure un gestionnaire de statut

```mql5
#include "../common/status/SymbolStatus.mqh"
```

## ✅ Avantages de cette organisation

1. **Navigation facilitée** : Fichiers groupés par fonctionnalité
2. **Maintenance améliorée** : Plus facile de localiser et modifier les composants
3. **Évolutivité** : Facile d'ajouter de nouveaux fichiers dans la bonne catégorie
4. **Séparation des responsabilités** : Chaque dossier a un rôle clair
5. **Réutilisabilité** : Composants facilement réutilisables dans d'autres projets
