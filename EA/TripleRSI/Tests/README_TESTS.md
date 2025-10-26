# Guide de Test et Optimisation - Triple RSI Strategy

## Tests Unitaires

### Script de Test Basique

Le fichier `Test_TripleRSI_Basic.mq5` permet de tester les composants individuels de la stratégie.

#### Utilisation

1. Ouvrir MetaEditor
2. Ouvrir le fichier `EA/TripleRSI/Tests/Test_TripleRSI_Basic.mq5`
3. Compiler (F7)
4. Exécuter dans Strategy Tester ou sur un graphique

#### Tests Inclus

- **Calcul RSI**: Vérification des valeurs RSI courantes et historiques
- **Détection d'alignement**: Test des signaux BUY/SELL/NONE
- **Validation d'entrée**: Test des règles de validation
- **Génération de signaux**: Test complet du système de signaux

#### Paramètres de Test

- `InpTestSymbol`: Symbole à tester (défaut: EURUSD)
- `InpTestTimeframe`: Timeframe de test (défaut: M15)
- `InpTestBars`: Nombre de barres à analyser (défaut: 100)
- `InpShowDetails`: Afficher les détails (défaut: true)

## Backtesting

### Configuration Strategy Tester

#### Paramètres de Base

1. **Expert**: TripleRSI_EA
2. **Symbol**: EURUSD (recommandé pour commencer)
3. **Period**: M15 ou M30
4. **Model**: Every tick based on real ticks
5. **Dates**: Dernier 3-6 mois
6. **Deposit**: 10000 (montant de test)

#### Paramètres Recommandés pour Test Initial

```
=== SYMBOLES & TIMEFRAME ===
InpSymbolsList = "EURUSD"
InpTimeframe = PERIOD_M15

=== RSI PARAMETERS ===
InpRSIPeriod1 = 7
InpRSIPeriod2 = 14
InpRSIPeriod3 = 21
InpOversold = 30
InpOverbought = 70

=== RISK MANAGEMENT ===
InpRiskPercent = 1.0
InpSLPoints = 100
InpTPRatio = 2.0

=== TRAILING STOP ===
InpUseTrailing = true
InpTSLTrigger = 50
InpTSLDistance = 30

=== ALERTES ===
InpUseAlerts = false
InpSendNotif = false

=== ADVANCED ===
InpMagicNumber = 123456
InpLogLevel = LOG_INFO
```

### Critères de Performance

#### Métriques Clés

- **Profit Factor**: > 1.5 (idéal: > 2.0)
- **Win Rate**: > 50% (idéal: > 60%)
- **Maximum Drawdown**: < 20% (idéal: < 15%)
- **Sharpe Ratio**: > 1.0 (idéal: > 1.5)
- **Total Trades**: > 100 (pour statistiques fiables)

#### Analyse des Résultats

1. **Vérifier la cohérence**: Les résultats doivent être cohérents sur différentes périodes
2. **Analyser les drawdowns**: Identifier les périodes de pertes importantes
3. **Examiner les trades**: Vérifier la logique des entrées/sorties
4. **Comparer les symboles**: Tester sur plusieurs paires de devises

## Optimisation

### Paramètres à Optimiser

#### RSI Periods

```
InpRSIPeriod1: 5, 6, 7, 8, 9, 10
InpRSIPeriod2: 12, 13, 14, 15, 16
InpRSIPeriod3: 18, 19, 20, 21, 22, 23, 24
```

#### RSI Levels

```
InpOversold: 20, 25, 30, 35
InpOverbought: 65, 70, 75, 80
```

#### Risk Management

```
InpRiskPercent: 0.5, 1.0, 1.5, 2.0
InpSLPoints: 50, 75, 100, 125, 150, 200
InpTPRatio: 1.5, 2.0, 2.5, 3.0
```

#### Trailing Stop

```
InpTSLTrigger: 30, 40, 50, 60, 70, 100
InpTSLDistance: 20, 25, 30, 35, 40, 50
```

### Stratégie d'Optimisation

#### Étape 1: Optimisation Large

- Utiliser l'algorithme génétique
- Optimiser tous les paramètres simultanément
- Analyser les meilleures combinaisons

#### Étape 2: Optimisation Fine

- Sélectionner les meilleures combinaisons de l'étape 1
- Optimiser avec des intervalles plus petits
- Valider sur des périodes différentes

#### Étape 3: Validation

- Tester sur des données out-of-sample
- Vérifier la robustesse sur différents symboles
- Analyser la stabilité des paramètres

### Configuration d'Optimisation

#### Algorithme Génétique

- **Population**: 50-100
- **Générations**: 20-50
- **Mutation**: 0.1-0.2
- **Crossover**: 0.8-0.9

#### Critères d'Arrêt

- Profit Factor > 1.5
- Maximum Drawdown < 20%
- Win Rate > 50%
- Total Trades > 50

## Tests Multi-Symboles

### Symboles Recommandés

1. **EURUSD**: Spread faible, liquidité élevée
2. **GBPUSD**: Bonne volatilité
3. **USDJPY**: Tendance claire
4. **AUDUSD**: Corrélation faible avec EUR/USD
5. **USDCAD**: Commodity currency

### Configuration Multi-Symboles

```
InpSymbolsList = "EURUSD,GBPUSD,USDJPY"
```

### Analyse des Résultats

- **Performance par symbole**: Identifier les symboles les plus rentables
- **Corrélations**: Éviter les symboles trop corrélés
- **Diversification**: Répartir le risque sur plusieurs paires

## Tests de Robustesse

### Tests de Stress

1. **Périodes de crise**: Tester sur 2008, 2020
2. **Volatilité élevée**: Périodes de forte volatilité
3. **Marchés latéraux**: Périodes de consolidation
4. **Nouvelles importantes**: Événements économiques majeurs

### Tests de Sensibilité

1. **Variation des spreads**: Simuler des spreads élevés
2. **Slippage**: Tester avec différents niveaux de slippage
3. **Latence**: Simuler des délais d'exécution
4. **Interruptions**: Tester la récupération après arrêt

## Monitoring en Temps Réel

### Logs à Surveiller

- **Erreurs de trading**: Vérifier les erreurs d'exécution
- **Signaux générés**: Compter les signaux par jour
- **Positions ouvertes**: Surveiller le nombre de positions
- **P&L**: Suivre le profit/perte en temps réel

### Alertes Recommandées

- **Drawdown > 10%**: Alerte de risque élevé
- **Pas de trades > 24h**: Vérifier les données
- **Erreurs répétées**: Problème technique possible
- **Profit > 5%**: Objectif atteint

## Checklist de Validation

### Avant le Déploiement

- [ ] Tests unitaires passés
- [ ] Backtest sur 3+ mois positif
- [ ] Optimisation réalisée
- [ ] Tests multi-symboles validés
- [ ] Tests de robustesse effectués
- [ ] Documentation complète

### Après le Déploiement

- [ ] Monitoring des logs
- [ ] Vérification des performances
- [ ] Ajustement des paramètres si nécessaire
- [ ] Mise à jour de la documentation

## Dépannage

### Problèmes Courants

1. **Pas de signaux**: Vérifier les niveaux RSI et les données
2. **Trop de signaux**: Ajuster les niveaux ou ajouter des filtres
3. **Drawdown élevé**: Réduire le risque ou améliorer les filtres
4. **Erreurs d'exécution**: Vérifier les permissions et le capital

### Solutions

1. **Analyser les logs**: Identifier les problèmes spécifiques
2. **Ajuster les paramètres**: Modifier selon les conditions de marché
3. **Améliorer les filtres**: Ajouter des conditions supplémentaires
4. **Optimiser le risque**: Réduire la taille des positions

## Ressources Utiles

### Documentation

- README.md: Guide d'installation et d'utilisation
- STRATEGY_RULES.md: Règles détaillées de la stratégie
- Logs MT5: Informations de débogage

### Outils

- Strategy Tester: Backtesting et optimisation
- MetaEditor: Compilation et débogage
- Market Watch: Surveillance des symboles

### Support

- Logs détaillés avec niveau DEBUG
- Tests unitaires pour diagnostic
- Documentation complète des paramètres
