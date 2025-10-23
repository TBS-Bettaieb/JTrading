# RSI Divergence Trading System

## 📋 Description

Système de trading complet basé sur les divergences RSI, composé de :

1. **RSI_Divergence_Indicator.mq5** - Indicateur visuel avec détection des divergences
2. **RSI_Divergence_EA.mq5** - Expert Advisor pour trading automatique

## 🎯 Fonctionnalités

### Indicateur (RSI_Divergence_Indicator.mq5)

- ✅ Détection des divergences RSI régulières (Bullish/Bearish)
- ✅ Détection des divergences RSI cachées (Hidden Bullish/Bearish)
- ✅ Affichage des trendlines de divergences
- ✅ RSI avec lissage MA optionnel et Bollinger Bands
- ✅ **4 buffers de signaux exposés pour l'EA** (buffers 10-13)

### Expert Advisor (RSI_Divergence_EA.mq5)

- ✅ Lecture automatique des signaux de l'indicateur
- ✅ Trading automatique sur les divergences détectées
- ✅ Money Management et Risk Management
- ✅ Trailing Stop automatique
- ✅ Filtres de tendance optionnels
- ✅ Gestion des positions multiples
- ✅ Statistiques de trading en temps réel

## 📁 Installation

### 1. Placer les fichiers

```
📁 MQL5/
├── 📁 Indicators/
│   └── RSI_Divergence_Indicator.mq5
└── 📁 Experts/
    └── RSI_Divergence_EA.mq5
```

### 2. Compiler les fichiers

1. Ouvrir MetaEditor (F4 dans MetaTrader 5)
2. Compiler `RSI_Divergence_Indicator.mq5` (F7)
3. Compiler `RSI_Divergence_EA.mq5` (F7)
4. Vérifier qu'il n'y a pas d'erreurs de compilation

## 🚀 Utilisation

### Étape 1 : Ajouter l'indicateur

1. Glisser `RSI_Divergence_Indicator` sur le graphique
2. Configurer les paramètres selon vos besoins
3. L'indicateur s'affiche dans une fenêtre séparée avec :
   - Ligne RSI
   - MA de lissage (si activée)
   - Bollinger Bands (si activées)
   - Marqueurs de divergences
   - Trendlines de divergences

### Étape 2 : Ajouter l'EA

1. Glisser `RSI_Divergence_EA` sur le même graphique
2. Configurer les paramètres de trading
3. **IMPORTANT** : Les paramètres de l'EA doivent correspondre à ceux de l'indicateur :
   - `InpRSIPeriod` = RSI Period de l'indicateur
   - `InpLookbackLeft/Right` = Lookback de l'indicateur
   - `InpRangeLower/Upper` = Range de l'indicateur
   - `InpShowHiddenDiv` = Show Hidden Divergences de l'indicateur

## ⚙️ Configuration

### Paramètres de l'Indicateur

```mql5
// RSI Settings
InpRSIPeriod = 3                    // Période RSI
InpRSIAppliedPrice = PRICE_CLOSE    // Prix appliqué

// Divergence Settings
InpLookbackLeft = 5                 // Barres à gauche pour pivot
InpLookbackRight = 5                // Barres à droite pour pivot
InpRangeLower = 5                   // Distance minimum entre pivots
InpRangeUpper = 60                  // Distance maximum entre pivots
InpShowTrendlines = true            // Afficher les trendlines

// Hidden Divergence Settings
InpShowHiddenDiv = true             // Afficher les divergences cachées
```

### Paramètres de l'EA

```mql5
// Indicateur Settings (DOIVENT correspondre à l'indicateur)
InpIndicatorName = "RSI_Divergence_Indicator"
InpRSIPeriod = 3
InpLookbackLeft = 5
InpLookbackRight = 5
InpRangeLower = 5
InpRangeUpper = 60
InpShowHiddenDiv = true

// Trading Settings
InpTradeRegularDiv = true           // Trader les divergences régulières
InpTradeHiddenDiv = false           // Trader les divergences cachées
InpLotSize = 0.01                   // Taille de lot
InpStopLoss = 50                    // Stop Loss en points
InpTakeProfit = 100                 // Take Profit en points
InpMagicNumber = 123456             // Numéro magique

// Risk Management
InpUseTrailingStop = true           // Utiliser trailing stop
InpTrailingStop = 30                // Distance trailing stop
InpTrailingStep = 5                 // Pas du trailing stop
InpMaxTrades = 1                    // Nombre max de positions simultanées
```

## 📊 Types de Divergences

### 1. Regular Bullish Divergence

- **Condition** : Prix fait Lower Low + RSI fait Higher Low
- **Signal** : Retournement haussier potentiel
- **Buffer** : `RegularBullishSignal[10] = 1.0`

### 2. Regular Bearish Divergence

- **Condition** : Prix fait Higher High + RSI fait Lower High
- **Signal** : Retournement baissier potentiel
- **Buffer** : `RegularBearishSignal[11] = 1.0`

### 3. Hidden Bullish Divergence

- **Condition** : Prix fait Higher Low + RSI fait Lower Low
- **Signal** : Continuation de tendance haussière
- **Buffer** : `HiddenBullishSignal[12] = 1.0`

### 4. Hidden Bearish Divergence

- **Condition** : Prix fait Lower High + RSI fait Higher High
- **Signal** : Continuation de tendance baissière
- **Buffer** : `HiddenBearishSignal[13] = 1.0`

## 🔧 Architecture Technique

### Communication Indicateur ↔ EA

```
Indicateur (RSI_Divergence_Indicator)
├── Buffer 0-9: Données visuelles (RSI, MA, BB, etc.)
└── Buffer 10-13: Signaux pour l'EA
    ├── Buffer 10: RegularBullishSignal
    ├── Buffer 11: RegularBearishSignal
    ├── Buffer 12: HiddenBullishSignal
    └── Buffer 13: HiddenBearishSignal

EA (RSI_Divergence_EA)
├── iCustom() → Lit les buffers 10-13
├── Détection nouveau signal: signal[1] == 1.0 && signal[2] == 0.0
└── Ouverture position selon le signal détecté
```

### Détection des Signaux

```mql5
// L'EA lit les buffers de l'indicateur
CopyBuffer(indicatorHandle, 10, 0, 3, bullSignal);      // Regular Bullish
CopyBuffer(indicatorHandle, 11, 0, 3, bearSignal);      // Regular Bearish
CopyBuffer(indicatorHandle, 12, 0, 3, hiddenBullSignal); // Hidden Bullish
CopyBuffer(indicatorHandle, 13, 0, 3, hiddenBearSignal); // Hidden Bearish

// Détection nouveau signal (évite les trades multiples)
if(bullSignal[1] == 1.0 && bullSignal[2] == 0.0)
{
    // Nouveau signal Regular Bullish détecté
    OpenTrade(ORDER_TYPE_BUY, "Regular Bullish Divergence");
}
```

## 📈 Affichage des Informations

### Indicateur

- RSI avec niveaux (10, 50, 90)
- MA de lissage (optionnelle)
- Bollinger Bands (optionnelles)
- Marqueurs de divergences
- Trendlines de divergences
- Informations RSI dans le commentaire

### EA

- Nombre de positions ouvertes
- Statistiques de trading (trades, win rate, profit)
- Dernier signal détecté
- Configuration active
- Temps actuel

## ⚠️ Points Importants

### 1. Synchronisation des Paramètres

**CRITIQUE** : Les paramètres de l'EA doivent correspondre exactement à ceux de l'indicateur :

- RSI Period
- Lookback Left/Right
- Range Lower/Upper
- Show Hidden Divergences

### 2. Ordre d'Installation

1. **D'abord** : Compiler et ajouter l'indicateur
2. **Ensuite** : Compiler et ajouter l'EA
3. L'EA ne peut pas fonctionner sans l'indicateur

### 3. Gestion des Erreurs

- L'EA vérifie que l'indicateur est chargé
- Validation des paramètres d'entrée
- Gestion des erreurs de trading
- Logs détaillés dans le journal

### 4. Performance

- L'indicateur optimise les calculs avec `prev_calculated`
- L'EA ne recalcule pas les divergences (lit les signaux)
- Gestion intelligente des trendlines (limite le nombre)

## 🧪 Test et Validation

### 1. Test Visuel

1. Ajouter l'indicateur → Vérifier l'affichage RSI et trendlines
2. Ajouter l'EA → Vérifier qu'il détecte les signaux
3. Observer les logs dans le journal

### 2. Test en Strategy Tester

1. Sélectionner l'EA dans le Strategy Tester
2. Configurer les paramètres
3. Lancer le test avec données historiques
4. Analyser les résultats

### 3. Test en Compte Démo

1. Utiliser un compte démo
2. Tester avec de petits lots
3. Vérifier le comportement en temps réel
4. Ajuster les paramètres si nécessaire

## 📝 Logs et Debugging

### Logs de l'Indicateur

```
✅ RSI Divergence Indicator Initialized!
Symbol: EURUSD
Timeframe: PERIOD_H1
🟢 BULLISH DIVERGENCE DETECTED!
Previous Pivot: Bar 15 RSI=25.30
Current Pivot: Bar 8 RSI=28.45
```

### Logs de l'EA

```
✅ RSI Divergence EA Initialized!
Symbol: EURUSD
Timeframe: PERIOD_H1
Indicator Handle: 1234567890
Magic Number: 123456
✅ Trade ouvert: Regular Bullish Divergence
Type: ORDER_TYPE_BUY
Lot: 0.01
Price: 1.08500
SL: 1.08000
TP: 1.09500
```

## 🔄 Mises à Jour

### Version 2.11 (Indicateur)

- ✅ Ajout des 4 buffers de signaux pour l'EA
- ✅ Amélioration de la détection des pivots
- ✅ Optimisation des performances
- ✅ Support des divergences cachées

### Version 1.00 (EA)

- ✅ Lecture des signaux de l'indicateur
- ✅ Trading automatique complet
- ✅ Money Management et Risk Management
- ✅ Trailing Stop automatique
- ✅ Statistiques de trading

## 🆘 Support et Dépannage

### Problèmes Courants

1. **"Impossible de charger l'indicateur"**

   - Vérifier que l'indicateur est compilé
   - Vérifier le nom exact de l'indicateur
   - Vérifier que l'indicateur est dans le bon dossier

2. **"Aucun signal détecté"**

   - Vérifier que les paramètres EA = paramètres indicateur
   - Vérifier que l'indicateur détecte des divergences
   - Vérifier les logs de l'indicateur

3. **"Erreur d'ouverture de position"**
   - Vérifier les limites de prix (Stop Level)
   - Vérifier la taille de lot
   - Vérifier les permissions de trading

### Contact

Pour toute question ou problème, vérifier :

1. Les logs dans le journal MetaTrader 5
2. La correspondance des paramètres entre indicateur et EA
3. La compilation sans erreurs des deux fichiers

---

**⚠️ N'oubliez pas de :**

1. Compiler les deux fichiers dans MetaEditor (F7)
2. Vérifier l'affichage graphique des données dans le testeur
3. Ne pas supprimer les fichiers de test
4. Tester d'abord en compte démo
