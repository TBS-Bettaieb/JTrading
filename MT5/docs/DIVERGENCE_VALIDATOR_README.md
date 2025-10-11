# 📊 Validateur de Divergence RSI - Documentation

## Vue d'ensemble

Le **Divergence Validator** est un système avancé de validation de signaux qui mémorise les Free Candles et n'exécute le trade que si une divergence RSI/Prix est confirmée avec un RSI dans la zone appropriée.

## 🎯 Principe de fonctionnement

### Flux de validation

```
Free Candle détecté
       ↓
Mémorisation (bar index, prix, direction)
       ↓
Nouvelle barre → Vérification RSI
       ↓
    ┌──────┴──────┐
    │             │
RSI > seuil   RSI < seuil (BUY)
    │         ou RSI > seuil (SELL)
    ↓             ↓
Invalider    Chercher divergence
mémoire           ↓
              ┌───┴───┐
              │       │
         Pas de    Divergence
       divergence   confirmée
              │       │
              ↓       ↓
           Attendre  EXÉCUTER
                    LE TRADE
```

### Règles de validation

#### Pour un signal BUY (Free Candle en survente)
1. **Free Candle détecté** → Mémorisation
2. **Chaque nouvelle barre** :
   - Si `RSI > 35` → ❌ **Invalider** (trop haut, conditions non remplies)
   - Si `RSI < 35` → Chercher divergence haussière
     - Prix fait un **LL** (Lower Low)
     - RSI fait un **HL** (Higher Low)
     - ✅ **Exécuter le trade**

#### Pour un signal SELL (Free Candle en surachat)
1. **Free Candle détecté** → Mémorisation
2. **Chaque nouvelle barre** :
   - Si `RSI < 65` → ❌ **Invalider** (trop bas, conditions non remplies)
   - Si `RSI > 65` → Chercher divergence baissière
     - Prix fait un **HH** (Higher High)
     - RSI fait un **LH** (Lower High)
     - ✅ **Exécuter le trade**

## ⚙️ Paramètres configurables

### Dans JTFreeCandle.mq5

```mql5
// Divergence Validator (validation avancée avec mémoire)
input bool   Use_Divergence_Validator = false;   // Activer validation par divergence
input double Div_RSI_Buy_Level        = 35.0;    // Seuil RSI pour validation BUY
input double Div_RSI_Sell_Level       = 65.0;    // Seuil RSI pour validation SELL
input int    Div_Swing_Length         = 5;       // Longueur pivot pour divergence
```

### Description des paramètres

| Paramètre | Défaut | Description |
|-----------|--------|-------------|
| `Use_Divergence_Validator` | `false` | Active/désactive le système de validation par divergence |
| `Div_RSI_Buy_Level` | `35.0` | Seuil RSI maximum pour valider un BUY (en dessous = OK) |
| `Div_RSI_Sell_Level` | `65.0` | Seuil RSI minimum pour valider un SELL (au dessus = OK) |
| `Div_Swing_Length` | `5` | Nombre de barres de chaque côté pour détecter un pivot (creux/sommet) |

## 📈 Exemple d'utilisation

### Scénario 1 : BUY validé

```
Barre 50: Free Candle BUY détecté (RSI = 32) → MÉMORISÉ
Barre 51: RSI = 38 → INVALIDÉ (> 35)
          Free Candle effacé de la mémoire

Barre 60: Free Candle BUY détecté (RSI = 28) → MÉMORISÉ
Barre 61: RSI = 30 → Cherche divergence
          Creux 1: Prix = 1.0500, RSI = 25
          Creux 2: Prix = 1.0480, RSI = 30 (LL en prix, HL en RSI)
          ✅ DIVERGENCE CONFIRMÉE → EXÉCUTE BUY
```

### Scénario 2 : SELL invalidé

```
Barre 100: Free Candle SELL détecté (RSI = 72) → MÉMORISÉ
Barre 101: RSI = 68 → Cherche divergence (pas encore trouvée)
Barre 102: RSI = 62 → INVALIDÉ (< 65)
           Free Candle effacé de la mémoire
```

## 🔧 Architecture technique

### Fichiers

- **JT_DivergenceValidator.mqh** : Classe de validation
- **JTFreeCandle.mq5** : Intégration dans l'EA

### Classes et structures

```mql5
// Structure de mémoire
struct FreeCandleMemory {
   bool isActive;        // True si un Free Candle est mémorisé
   int barIndex;         // Index de la barre du Free Candle
   datetime time;        // Timestamp
   double priceLevel;    // Niveau de prix
   int direction;        // +1 = BUY, -1 = SELL
};

// Classe principale
class JTDivergenceValidator {
   // Méthodes publiques
   bool Init(...)                                    // Initialiser
   void RememberFreeCandle(int, double, int)        // Mémoriser
   void ClearMemory()                                // Effacer
   bool HasFreeCandle()                              // Vérifier mémoire
   int ValidateDivergence()                          // Valider (+1/0/-1)
   
   // Méthodes privées
   bool IsBullishDivergence()                        // Détecter div haussière
   bool IsBearishDivergence()                        // Détecter div baissière
   bool IsSwingLow(int)                              // Détecter creux
   bool IsSwingHigh(int)                             // Détecter sommet
};
```

## 📊 Logs et débogage

Le système génère des logs détaillés :

```
[DIVERGENCE] Free Candle mémorisé: bar=1, direction=BUY, price=1.05000
[DIVERGENCE] Free Candle BUY invalidé: RSI 38.50 > 35.0
[DIVERGENCE] Divergence haussière détectée: Prix(1.0500 → 1.0480), RSI(25.0 → 30.0)
[DIVERGENCE] ✓ Divergence haussière confirmée avec RSI=30.00
[INFO] DIVERGENCE VALIDÉE - Signal BUY - Entry: 1.05100, SL: 1.04800, TP: 1.05700, RR: 1:2.00
```

## 🎓 Conseils d'utilisation

### Valeurs recommandées

| Timeframe | Div_RSI_Buy_Level | Div_RSI_Sell_Level | Div_Swing_Length |
|-----------|-------------------|--------------------|--------------------|
| M15       | 30-35             | 65-70              | 3-5                |
| H1        | 35-40             | 60-65              | 5-7                |
| H4        | 35-40             | 60-65              | 7-10               |
| D1        | 40-45             | 55-60              | 10-15              |

### Mode normal vs Mode divergence

**Sans divergence validator** (`Use_Divergence_Validator = false`)
- ✅ Exécution immédiate sur Free Candle + RSI
- ⚡ Rapide, réactif
- ⚠️ Peut générer plus de faux signaux

**Avec divergence validator** (`Use_Divergence_Validator = true`)
- ✅ Validation stricte avec divergence
- 🎯 Moins de trades, meilleure qualité
- ⏳ Peut manquer des opportunités rapides
- 🛡️ Protection contre faux signaux

## ⚠️ Limitations

1. **Nécessite historique** : Au moins `Div_Swing_Length × 2 + 2` barres
2. **Retard** : La divergence peut prendre plusieurs barres à se former
3. **One-shot** : Une fois validé ou invalidé, le Free Candle est effacé

## 🔄 Modes de fonctionnement combinés

Le système peut fonctionner seul ou avec les autres filtres :

```mql5
Use_RSI_Filter = true              // Filtre initial (survente/surachat)
Use_Divergence_Validator = true    // Validation par divergence

// Flux complet :
// 1. Free Candle hors Bollinger ✓
// 2. RSI en survente/surachat ✓
// 3. Free Candle mémorisé
// 4. Attente divergence + RSI < seuil
// 5. Exécution
```

## 📝 Notes de développement

- Le validateur utilise son propre handle RSI pour éviter les conflits
- La mémoire est effacée après validation (one-shot) ou invalidation
- Les pivots sont détectés avec une méthode simple (N barres de chaque côté)
- Compatible avec tous les timeframes et symboles

---

**Version** : 1.0  
**Date** : 2025-10-09  
**Auteur** : JTrading  

