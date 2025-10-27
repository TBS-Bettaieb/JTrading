# 📊 Dynamic Stop-Loss Calculator

## 🎯 Description

Le `CDynamicStopLossCalculator` est une classe MQL5 qui calcule automatiquement le stop-loss optimal pour vos stratégies de trading en utilisant 4 méthodes prioritaires basées sur la structure du marché et la volatilité.

## 🔧 Fonctionnalités

### 📈 **4 Méthodes de Calcul Prioritaires**

1. **🏔️ Swing High/Low** - Structure du marché

   - Détection automatique des derniers swing points confirmés
   - Validation par volume et distance minimale
   - Buffer de sécurité configurable

2. **📊 ATR Classique** - Volatilité standard

   - Période ATR : 14
   - Multiplicateur : 1.5
   - Adapté à la volatilité courante

3. **⚡ ATR Long** - Volatilité élevée

   - Période ATR : 28
   - Multiplicateur : 1.2
   - Activé si volatilité > 1.7x la moyenne

4. **📉 Pourcentage Fixe** - Fallback
   - 0.5% du prix d'entrée par défaut
   - Utilisé si aucune autre méthode n'est valide

### 🛡️ **Validations Intégrées**

- ✅ Distance minimale du broker
- ✅ Volume suffisant pour les swings
- ✅ Logique directionnelle (achat/vente)
- ✅ Cache ATR pour performance
- ✅ Normalisation des prix

## 📋 Paramètres Configurables

```mql5
// Paramètres Swing Points
input int    SWING_LOOKBACK_PERIODS = 20;        // Périodes pour détecter les swings
input int    SWING_MIN_DISTANCE_POINTS = 30;     // Distance minimale swing (points)
input double SWING_VOLUME_THRESHOLD = 1.2;      // Seuil volume pour validation swing
input int    SWING_BUFFER_POINTS = 5;            // Buffer de sécurité swing (points)

// Paramètres ATR
input int    ATR_PERIOD = 14;                    // Période ATR standard
input double ATR_MULTIPLIER = 1.5;               // Multiplicateur ATR standard
input int    ATR_LONG_PERIOD = 28;               // Période ATR longue (volatilité élevée)
input double ATR_LONG_MULTIPLIER = 1.2;          // Multiplicateur ATR longue
input double ATR_VOLATILITY_THRESHOLD = 1.7;     // Seuil volatilité élevée (x moyenne)

// Paramètres Stop-Loss par défaut
input double DEFAULT_SL_PERCENT = 0.5;           // Stop-loss par défaut (% du prix)
```

## 🚀 Utilisation

### **Méthode Simple**

```mql5
#include "DynamicStopLossCalculator.mqh"

// Calcul automatique
double stopLoss = CalculateDynamicStopLoss(Symbol(), PERIOD_H1, true, 1.0850);

if(stopLoss > 0)
{
   Print("Stop-Loss: ", DoubleToString(stopLoss, 5));
}
```

### **Méthode Avancée avec Objet**

```mql5
#include "DynamicStopLossCalculator.mqh"

// Créer l'objet calculateur
CDynamicStopLossCalculator calculator(Symbol(), PERIOD_H1);

// Calculer le stop-loss
double entryPrice = 1.0850;
bool isBuy = true;
double stopLoss = calculator.CalculateStopLoss(isBuy, entryPrice);

// Afficher les informations de debug
Print(calculator.GetDebugInfo());
```

### **Intégration dans un EA**

```mql5
class MyEA
{
private:
   CDynamicStopLossCalculator* m_slCalculator;

public:
   MyEA()
   {
      m_slCalculator = new CDynamicStopLossCalculator(Symbol(), PERIOD_H1);
   }

   ~MyEA()
   {
      if(m_slCalculator != NULL)
         delete m_slCalculator;
   }

   bool OpenPosition(bool isBuy, double lotSize)
   {
      double entryPrice = isBuy ? Ask : Bid;
      double stopLoss = m_slCalculator.CalculateStopLoss(isBuy, entryPrice);

      if(stopLoss > 0)
      {
         // Ouvrir la position avec le SL calculé
         return m_trade.Buy(lotSize, Symbol(), entryPrice, stopLoss, 0, "Dynamic SL");
      }

      return false;
   }
};
```

## 📊 Exemples de Résultats

### **Scénario 1: Swing Point Valide**

```
✓ Using SWING method: 1.0825
Final SL: 1.0825 | Method: SWING | Distance: 25.0 pts
```

### **Scénario 2: ATR Standard**

```
✓ Using ATR method: 1.0830
Final SL: 1.0830 | Method: ATR | Distance: 20.0 pts
```

### **Scénario 3: Volatilité Élevée**

```
High volatility detected: 2.1x average
✓ Using ATR_LONG method: 1.0840
Final SL: 1.0840 | Method: ATR_LONG | Distance: 10.0 pts
```

### **Scénario 4: Fallback Pourcentage**

```
✓ Using PERCENTAGE method: 1.0796
Final SL: 1.0796 | Method: PERCENTAGE | Distance: 54.0 pts
```

## 🔍 Debug et Monitoring

### **Informations de Debug**

```mql5
string debugInfo = calculator.GetDebugInfo();
Print(debugInfo);
```

**Sortie typique :**

```
=== DYNAMIC STOP-LOSS CALCULATOR DEBUG ===
Symbol: EURUSD
Timeframe: PERIOD_H1
ATR Handle: OK
ATR Long Handle: OK
Volume Handle: OK
Current ATR: 0.00085
Current ATR Long: 0.00092
ATR Average: 0.00078
Min Stop Distance: 0.00020
================================================
```

### **Logs Détaillés**

La classe utilise le système de logging intégré avec différents niveaux :

- **INFO** : Calculs principaux et résultats
- **DEBUG** : Détails des analyses (swing, ATR)
- **WARNING** : Ajustements et validations
- **ERROR** : Erreurs critiques

## ⚙️ Configuration Recommandée

### **Pour le Scalping (M1-M5)**

```mql5
SWING_LOOKBACK_PERIODS = 10
SWING_MIN_DISTANCE_POINTS = 15
ATR_PERIOD = 10
ATR_MULTIPLIER = 1.2
```

### **Pour le Day Trading (M15-H1)**

```mql5
SWING_LOOKBACK_PERIODS = 20
SWING_MIN_DISTANCE_POINTS = 30
ATR_PERIOD = 14
ATR_MULTIPLIER = 1.5
```

### **Pour le Swing Trading (H4-D1)**

```mql5
SWING_LOOKBACK_PERIODS = 50
SWING_MIN_DISTANCE_POINTS = 50
ATR_PERIOD = 21
ATR_MULTIPLIER = 2.0
```

## 🎯 Avantages

- ✅ **Automatique** : Aucune intervention manuelle
- ✅ **Adaptatif** : S'ajuste à la volatilité du marché
- ✅ **Robuste** : Multiple méthodes de fallback
- ✅ **Performant** : Cache et optimisations
- ✅ **Configurable** : Paramètres ajustables
- ✅ **Loggé** : Traçabilité complète

## ⚠️ Notes Importantes

1. **Compilation** : Compilez dans MetaEditor (F7)
2. **Test** : Testez d'abord sur un compte démo
3. **Paramètres** : Ajustez selon votre stratégie
4. **Monitoring** : Surveillez les logs pour optimiser
5. **Broker** : Vérifiez les distances minimales

## 📁 Fichiers Inclus

- `DynamicStopLossCalculator.mqh` - Classe principale
- `Example_DynamicStopLossUsage.mqh` - Exemples d'utilisation
- `Logger.mqh` - Système de logging (requis)
- `TradingEnums.mqh` - Énumérations (requis)
