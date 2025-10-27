# DayTimesFilters - Gestionnaire Centralisé des Filtres Temporels

## 📁 Structure du Dossier

Ce dossier contient tous les filtres temporels organisés par catégorie pour une meilleure maintenabilité :

```
DayTimesFilters/
├── TradingTimeManager.mqh          # Gestionnaire principal centralisé
├── TimeFilters/                     # Filtres basés sur l'heure
│   ├── TimeRangeFilter.mqh         # Plages horaires (ex: "8-10;16")
│   ├── TimeMinuteFilter.mqh        # Plages précises heure:minute (ex: "8:30-10:45")
│   └── TimeFilter.mqh              # Filtre simple début/fin d'heure
├── DayFilters/                      # Filtres basés sur les jours
│   └── DayRangeFilter.mqh          # Jours de la semaine (ex: "1-5" = Lun-Ven)
├── SessionFilters/                  # Filtres basés sur les sessions
│   └── SessionFilter.mqh            # Sessions de trading (London, US, etc.)
├── NewsFilters/                     # Filtres basés sur les actualités
│   └── NewsFilter.mqh              # Filtrage par actualités économiques
└── RiskFilters/                     # Filtres de gestion des risques
    └── RiskMultiplierManager.mqh    # Multiplicateur de risque par période
```

## 🎯 Utilisation

### 1. Inclusion du Gestionnaire Principal

```mql5
#include "Shared/DayTimesFilters/TradingTimeManager.mqh"
```

### 2. Initialisation Modulaire

```mql5
TradingTimeManager* timeManager = new TradingTimeManager(chartManager);

// Initialiser uniquement les filtres nécessaires
timeManager.InitTimeRangeFilter(true, "8-10;16-18");
timeManager.InitDayRangeFilter(true, "1-5");
timeManager.InitSessionFilter(true, SESSION_OVERLAP, 30);
timeManager.InitNewsFilter(true, "USD,EUR", "NFP,PMI", 30, 10, 7, NEWS_COMMA);
timeManager.InitTimeMinuteFilter(true, "8:30-10:45;16:00");

// Vérification du trading
if(timeManager.IsTradingAllowed()) {
    // Trading autorisé
}
```

### 3. Utilisation des Filtres Individuels

```mql5
// Filtres de temps
#include "Shared/DayTimesFilters/TimeFilters/TimeRangeFilter.mqh"
if(IsTimeRangeAllowed(true, "8-10;16")) { /* ... */ }

// Filtres de jour
#include "Shared/DayTimesFilters/DayFilters/DayRangeFilter.mqh"
if(IsDayRangeAllowed(true, "1-5")) { /* ... */ }

// Filtres de session
#include "Shared/DayTimesFilters/SessionFilters/SessionFilter.mqh"
if(IsSessionAllowedCustom(SESSION_OVERLAP, 30)) { /* ... */ }
```

## 🔧 Architecture Modulaire

### Avantages

- **NULL-safe** : Les filtres non initialisés sont automatiquement ignorés
- **Modulaire** : Initialisez uniquement les filtres nécessaires
- **Évolutif** : Facile d'ajouter de nouveaux filtres par catégorie
- **Maintenable** : Structure claire et organisée

### Compatibilité Descendante

Le gestionnaire principal maintient la compatibilité avec l'ancienne méthode :

```mql5
// Méthode legacy (toujours supportée)
timeManager.Initialize(true, "8-10;16", true, "1-5", true);
```

## 📊 Types de Filtres

### TimeFilters

- **TimeRangeFilter** : Plages horaires simples (8-10;16)
- **TimeMinuteFilter** : Plages précises avec minutes (8:30-10:45)
- **TimeFilter** : Filtre basique début/fin d'heure

### DayFilters

- **DayRangeFilter** : Jours de la semaine (0=Dim, 1=Lun...6=Sam)

### SessionFilters

- **SessionFilter** : Sessions de trading (London, US, Overlap, Asia)

### NewsFilters

- **NewsFilter** : Filtrage par actualités économiques

### RiskFilters

- **RiskMultiplierManager** : Gestion des multiplicateurs de risque par période

## ⚠️ Notes Importantes

1. **Ordre des Includes** : L'ordre des includes dans TradingTimeManager.mqh est important pour les énumérations
2. **ChartManager** : Nécessite ChartManager.mqh dans le dossier parent
3. **Compilation** : Compilez dans MetaEditor après modification des chemins
4. **Tests** : Testez tous les filtres après réorganisation

## 🔄 Migration depuis l'Ancienne Structure

Si vous migrez depuis l'ancienne structure `Filters/`, mettez à jour vos includes :

```mql5
// Ancien
#include "Shared/Filters/TimeRangeFilter.mqh"

// Nouveau
#include "Shared/DayTimesFilters/TimeFilters/TimeRangeFilter.mqh"
```

## 📝 Exemples d'Utilisation

Voir les fichiers d'exemple dans le dossier parent `Shared/` :

- `Example_ModularUsage.mqh`
- `Example_DynamicTrailingStop_Usage.mqh`
