# Règles de la Stratégie Triple RSI

## Vue d'ensemble

La stratégie Triple RSI est basée sur l'alignement de trois indicateurs RSI de périodes différentes pour générer des signaux de trading fiables.

## Indicateurs utilisés

- **RSI(7)**: RSI rapide - réagit rapidement aux changements de prix
- **RSI(14)**: RSI standard - équilibre entre réactivité et stabilité
- **RSI(21)**: RSI lent - filtre les faux signaux et confirme les tendances

## Logique de la stratégie

### Principe fondamental

Quand les trois RSI sont alignés dans la même direction, cela indique une forte tendance qui peut être exploitée pour le trading.

### Zones de trading

- **Zone Oversold**: RSI < 30 (potentiel d'achat)
- **Zone Overbought**: RSI > 70 (potentiel de vente)
- **Zone Neutre**: 30 ≤ RSI ≤ 70 (pas de signal)

## Règles d'entrée

### Signal d'achat (BUY)

**Conditions requises:**

1. RSI(7) > 30
2. RSI(14) > 30
3. RSI(21) > 30
4. Les trois RSI sont dans une tendance haussière

**Interprétation:**

- Le marché sort de la zone de survente
- La tendance haussière est confirmée par les trois timeframes
- Momentum positif sur toutes les périodes

**Action:**

- Ouvrir position BUY
- Stop Loss = Plus bas des 5 dernières barres
- Take Profit = Entry + (Entry - SL) × Ratio TP

### Signal de vente (SELL)

**Conditions requises:**

1. RSI(7) < 70
2. RSI(14) < 70
3. RSI(21) < 70
4. Les trois RSI sont dans une tendance baissière

**Interprétation:**

- Le marché sort de la zone de surachat
- La tendance baissière est confirmée par les trois timeframes
- Momentum négatif sur toutes les périodes

**Action:**

- Ouvrir position SELL
- Stop Loss = Plus haut des 5 dernières barres
- Take Profit = Entry - (SL - Entry) × Ratio TP

## Gestion des positions

### Stop Loss

**Calcul automatique:**

- **BUY**: Plus bas des N dernières barres + buffer de sécurité
- **SELL**: Plus haut des N dernières barres + buffer de sécurité
- **Buffer**: 2 points pour éviter les SL trop serrés

**Validation:**

- Distance minimum: 10 points
- Distance maximum: 500 points
- Ajustement automatique selon la volatilité

### Take Profit

**Ratio fixe:**

- TP = Entry ± (Distance SL × Ratio TP)
- Ratio par défaut: 2.0 (risque/récompense 1:2)
- Ajustable selon les préférences de risque

### Trailing Stop (optionnel)

**Activation:**

- Se déclenche après X points de profit
- Défaut: 50 points de profit

**Fonctionnement:**

- **BUY**: SL suit le prix à la hausse
- **SELL**: SL suit le prix à la baisse
- Distance fixe: 30 points (ajustable)

## Validation des entrées

### Vérifications préalables

1. **Symbole tradable**: Vérification des permissions
2. **Spread acceptable**: Entre 0 et 50 points
3. **Volume suffisant**: Au moins 50% de la moyenne
4. **Heures de trading**: Éviter les périodes de faible liquidité

### Filtres additionnels

- **Heures de faible liquidité**: 22h-02h GMT évitées
- **Validation des prix**: Vérification de la cohérence des prix
- **Capital disponible**: Vérification des fonds suffisants

## Gestion du risque

### Calcul de la taille de lot

**Formule:**

```
Lot Size = (Capital × Risk%) / (SL Distance × Tick Value)
```

**Normalisation:**

- Respect des lots minimum/maximum du symbole
- Arrondi selon le step de lot
- Vérification des contraintes du broker

### Limites de risque

- **Risque par trade**: Maximum 2% du capital
- **Risque total**: Maximum 10% du capital en positions ouvertes
- **Corrélation**: Éviter les positions corrélées sur plusieurs symboles

## Optimisation des paramètres

### Paramètres à optimiser

1. **Périodes RSI**: (5-10), (12-16), (18-24)
2. **Niveaux**: Oversold (20-35), Overbought (65-80)
3. **Ratio TP**: 1.5 à 3.0
4. **SL Points**: 50-200 points
5. **Trailing**: Trigger (30-100), Distance (20-50)

### Critères d'optimisation

- **Profit Factor**: > 1.5
- **Win Rate**: > 50%
- **Maximum Drawdown**: < 20%
- **Sharpe Ratio**: > 1.0

## Conditions de marché

### Marchés favorables

- **Tendances claires**: La stratégie fonctionne mieux en tendance
- **Volatilité modérée**: Éviter les marchés trop calmes ou trop volatils
- **Liquidité élevée**: Spreads faibles et exécution rapide

### Marchés défavorables

- **Marchés latéraux**: Beaucoup de faux signaux
- **Nouvelles importantes**: Volatilité excessive
- **Fermetures de marché**: Liquidité insuffisante

## Monitoring et ajustements

### Indicateurs de performance

- **Win Rate**: Pourcentage de trades gagnants
- **Profit Factor**: Ratio profit/perte
- **Maximum Drawdown**: Perte maximale en série
- **Average Trade**: Profit moyen par trade

### Ajustements recommandés

- **Réduire le risque** si drawdown > 15%
- **Augmenter les filtres** si trop de faux signaux
- **Ajuster les niveaux RSI** selon la volatilité du marché
- **Modifier le ratio TP** selon les conditions de marché

## Exemples de signaux

### Signal BUY typique

```
RSI(7) = 35.2  > 30 ✓
RSI(14) = 32.8 > 30 ✓
RSI(21) = 31.5 > 30 ✓
→ Signal BUY confirmé
```

### Signal SELL typique

```
RSI(7) = 68.1  < 70 ✓
RSI(14) = 69.3 < 70 ✓
RSI(21) = 71.2 < 70 ✗
→ Signal SELL non confirmé (RSI(21) encore > 70)
```

## Bonnes pratiques

### Avant le trading

1. Tester sur compte démo
2. Valider avec backtesting
3. Optimiser les paramètres
4. Vérifier les conditions de marché

### Pendant le trading

1. Surveiller les logs
2. Respecter la gestion du risque
3. Éviter le sur-trading
4. Garder des réserves de capital

### Après le trading

1. Analyser les performances
2. Identifier les améliorations
3. Ajuster les paramètres si nécessaire
4. Documenter les leçons apprises
