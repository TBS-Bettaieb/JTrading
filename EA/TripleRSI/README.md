# Triple RSI Trading Strategy

## Description

Expert Advisor utilisant 3 RSI de périodes différentes pour détecter les alignements de tendance et générer des signaux de trading automatiques.

## Principe de la Stratégie

La stratégie Triple RSI utilise trois indicateurs RSI avec des périodes différentes (7, 14, 21) pour identifier les moments où tous les RSI sont alignés dans la même direction, indiquant une forte tendance.

### Règles d'entrée

- **Signal BUY**: Les 3 RSI sont au-dessus du niveau oversold (30)
- **Signal SELL**: Les 3 RSI sont en-dessous du niveau overbought (70)

### Gestion des risques

- **Stop Loss**: Basé sur le plus bas/haut des N dernières barres
- **Take Profit**: Ratio fixe configurable (ex: 2x SL)
- **Trailing Stop**: Optionnel avec déclenchement et distance configurables

## Installation

### Prérequis

- MetaTrader 5
- MetaEditor (pour compilation)
- Compte de trading (démo ou réel)

### Étapes d'installation

1. Copier le dossier `EA/TripleRSI/` dans le répertoire `Experts/` de MetaTrader 5
2. Ouvrir MetaEditor (F4 dans MT5)
3. Ouvrir le fichier `TripleRSI_EA.mq5`
4. Compiler le fichier (F7)
5. Attacher l'EA sur un graphique M15 ou M30

### Structure des fichiers

```
EA/TripleRSI/
├── TripleRSI_EA.mq5              # Fichier principal EA
├── Core/
│   ├── TripleRSIBot.mqh          # Moteur principal du bot
│   ├── TripleRSITrader.mqh       # Logique de trading par symbole
│   └── TripleRSIConfig.mqh       # Configuration de la stratégie
└── Logic/
    ├── RSI_Calculator.mqh         # Calcul des 3 RSI
    ├── RSI_AlignmentDetector.mqh  # Détection alignement
    └── EntryRulesValidator.mqh    # Validation règles d'entrée
```

## Configuration

### Paramètres principaux

- **Symboles**: Liste des symboles à trader (ex: "EURUSD,GBPUSD")
- **Timeframe**: Période d'analyse (M15 recommandé)
- **Magic Number**: Identifiant unique pour les ordres

### Paramètres RSI

- **RSI Période 1**: 7 (rapide)
- **RSI Période 2**: 14 (moyen)
- **RSI Période 3**: 21 (lent)
- **Niveau Oversold**: 30
- **Niveau Overbought**: 70

⚠️ **Validation des périodes RSI**: L'EA vérifie automatiquement que les périodes RSI respectent les règles suivantes :

- `Period2 - Period1 > 2` (différence minimale entre RSI rapide et moyen)
- `Period3 - Period2 > 2` (différence minimale entre RSI moyen et lent)

Si ces conditions ne sont pas respectées, l'EA retourne `INIT_FAILED` et ne démarre pas.

### Gestion des risques

- **Risque par trade**: 1% du capital (recommandé)
- **Stop Loss**: 100 points (ajustable selon le symbole)
- **Ratio TP**: 2.0 (Take Profit = 2x Stop Loss)

### Trailing Stop

- **Activer**: true/false
- **Déclenchement**: 50 points de profit
- **Distance**: 30 points de distance

### Alertes

- **Alertes**: Activer les alertes sonores
- **Notifications**: Envoyer des notifications push

## Utilisation

### Backtesting

1. Ouvrir Strategy Tester (Ctrl+R)
2. Sélectionner Expert: TripleRSI_EA
3. Symbol: EURUSD
4. Period: M15
5. Dates: Dernier 3 mois
6. Mode: Every tick
7. Lancer le test

### Optimisation

1. Aller dans l'onglet "Optimization"
2. Sélectionner les paramètres à optimiser:
   - RSI Periods: (5-10), (12-16), (18-24)
   - Oversold/Overbought: (20-35)/(65-80)
   - TP Ratio: 1.5 à 3.0
   - SL Points: 50-200
3. Lancer l'optimisation génétique

### Trading en direct

1. Tester d'abord sur compte démo
2. Utiliser des lots minimums
3. Surveiller les logs pour détecter les erreurs
4. Ajuster les paramètres selon les résultats

## Monitoring

### Logs

L'EA génère des logs détaillés avec différents niveaux:

- **ERROR**: Erreurs critiques
- **WARNING**: Avertissements
- **INFO**: Informations générales
- **DEBUG**: Informations de débogage

### Affichage graphique

L'EA affiche sur le graphique:

- Nombre de symboles actifs
- Nombre de positions ouvertes
- P&L total
- Statut de la stratégie

### Statistiques

- Nombre total de trades
- Taux de réussite
- Profit total
- Informations par symbole

## Dépannage

### Problèmes courants

1. **Erreur de compilation**: Vérifier que tous les fichiers .mqh sont présents
2. **INIT_FAILED - Validation RSI**:
   - Vérifier que `InpRSIPeriod2 - InpRSIPeriod1 > 2`
   - Vérifier que `InpRSIPeriod3 - InpRSIPeriod2 > 2`
   - Exemple valide: Period1=7, Period2=14, Period3=21
   - Exemple invalide: Period1=7, Period2=9, Period3=21 (différence = 2)
3. **Pas de signaux**: Vérifier les niveaux RSI et les données historiques
4. **Erreurs de trading**: Vérifier les permissions de trading et le spread
5. **Positions non ouvertes**: Vérifier le capital disponible et les lots minimums

### Vérifications

- Données historiques suffisantes (au moins 100 barres)
- Symboles disponibles dans Market Watch
- Permissions de trading activées
- Capital suffisant pour les lots calculés

## Recommandations

### Symboles recommandés

- EURUSD (spread faible, liquidité élevée)
- GBPUSD (bonne volatilité)
- USDJPY (tendance claire)

### Timeframes

- M15: Trading intraday
- M30: Swing trading court terme
- H1: Swing trading moyen terme

### Gestion du risque

- Ne jamais risquer plus de 2% par trade
- Utiliser des stops loss stricts
- Diversifier sur plusieurs symboles
- Surveiller les corrélations

## Support

### Logs utiles

- Vérifier les logs dans l'onglet "Experts" de MT5
- Niveau DEBUG pour diagnostic approfondi
- Surveiller les erreurs de trading

### Contact

Pour toute question ou problème, consulter les logs détaillés et vérifier la configuration des paramètres.

## Changelog

### Version 1.1

- ✅ **Nouveau**: Validation automatique des périodes RSI
- ✅ **Nouveau**: Filtrage des configurations invalides (différence ≤ 2)
- ✅ **Nouveau**: Messages d'erreur explicites pour le debugging
- ✅ **Nouveau**: Script de test pour validation RSI
- ✅ **Amélioration**: Documentation étendue avec exemples

### Version 1.0

- Implémentation initiale de la stratégie Triple RSI
- Support multi-symboles
- Gestion des risques intégrée
- Trailing stop optionnel
- Système de logging complet
- Interface graphique informative
