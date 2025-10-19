# 🕒 Filtres de Trading - Shared

Ce dossier contient plusieurs filtres de trading réutilisables pour vos Expert Advisors MQL5.

## 📁 Fichiers disponibles

### 1. **TimeFilter.mqh** - Filtre horaire simple
- **Usage** : Filtre basique par heure de début/fin
- **Inputs requis** : `SHInput`, `EHInput`
- **Fonction principale** : `IsTradingAllowed()`

### 2. **TimeRangeFilter.mqh** - Filtre par plages horaires
- **Usage** : Filtre avancé par plages horaires multiples
- **Inputs requis** : `UseTimeFilter`, `HourRanges`
- **Fonction principale** : `IsTimeRangeAllowed()`

### 3. **DayRangeFilter.mqh** - Filtre par jours de la semaine
- **Usage** : Filtre par jours de la semaine
- **Inputs requis** : `UseDayFilter`, `DayRanges`
- **Fonction principale** : `IsDayRangeAllowed()`

## 🚀 Comment utiliser

### Étape 1 : Ajouter les inputs dans votre EA (.mq5)

```mq5
// Pour TimeRangeFilter
input group "=== Time Range Filter ==="
input bool UseTimeFilter = true;               // Activer filtre horaire
input string HourRanges = "8-10;16";          // Plages horaires (ex: 8-10;16)

// Pour DayRangeFilter
input group "=== Day Range Filter ==="
input bool UseDayFilter = false;              // Activer filtre par jour
input string DayRanges = "1-5";              // Jours autorisés (0=Dim,1=Lun...6=Sam)
```

### Étape 2 : Inclure les fichiers

```mq5
#include "../Shared/TimeRangeFilter.mqh"
#include "../Shared/DayRangeFilter.mqh"
```

### Étape 3 : Utiliser dans votre code

```mq5
void OnTick()
{
   // Vérifier les filtres
   if(!IsTimeRangeAllowed() || !IsDayRangeAllowed())
   {
      // Trading non autorisé
      return;
   }
   
   // Votre logique de trading ici...
}
```

## 📝 Exemples de configuration

### TimeRangeFilter - Plages horaires

```mq5
// Trading de 8h à 10h et de 16h à 17h
HourRanges = "8-10;16";

// Trading overnight de 22h à 6h
HourRanges = "22-6";

// Trading aux heures exactes
HourRanges = "9;14;20";
```

### DayRangeFilter - Jours de la semaine

```mq5
// Trading du Lundi au Vendredi
DayRanges = "1-5";

// Trading le weekend
DayRanges = "0;6";

// Trading Lundi, Mercredi, Vendredi
DayRanges = "1;3;5";

// Trading Vendredi à Lundi (weekend étendu)
DayRanges = "5-1";
```

## 🎯 Classes avancées

Chaque filtre propose aussi une classe pour une utilisation plus avancée :

```mq5
// Créer une instance
TimeRangeFilter timeFilter;
DayRangeFilter dayFilter;

// Configurer
timeFilter.InitFromInputs(UseTimeFilter, HourRanges);
dayFilter.InitFromInputs(UseDayFilter, DayRanges);

// Utiliser
if(timeFilter.IsTradingAllowed() && dayFilter.IsTradingAllowed())
{
   // Trading autorisé
}
```

## ⚠️ Notes importantes

1. **Les inputs doivent être dans le fichier .mq5 principal**, pas dans les fichiers .mqh
2. **Les chemins d'inclusion** dépendent de la structure de vos dossiers
3. **Les fonctions globales** utilisent les inputs automatiquement
4. **Les classes** permettent une configuration plus flexible
