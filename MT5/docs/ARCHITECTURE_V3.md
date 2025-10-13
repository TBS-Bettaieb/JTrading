# JTrading - Architecture v3.0 Orientée Objet

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Hiérarchie des Classes](#hiérarchie-des-classes)
4. [Guide d'utilisation](#guide-dutilisation)
5. [Créer une nouvelle stratégie](#créer-une-nouvelle-stratégie)
6. [Patterns de conception](#patterns-de-conception)
7. [Migration depuis v1/v2](#migration-depuis-v1v2)

---

## 🎯 Vue d'ensemble

### Objectifs du refactoring

L'architecture v3.0 transforme le code monolithique précédent en une **architecture modulaire et réutilisable** permettant de :

✅ **Réutiliser** la logique commune entre stratégies  
✅ **Étendre** facilement en créant de nouvelles stratégies  
✅ **Maintenir** le code plus facilement  
✅ **Tester** chaque composant indépendamment  
✅ **Composer** des stratégies complexes par héritage  

### Principes SOLID appliqués

- **S**ingle Responsibility: Chaque classe a une responsabilité unique
- **O**pen/Closed: Ouvert à l'extension, fermé à la modification
- **L**iskov Substitution: Les stratégies dérivées sont interchangeables
- **I**nterface Segregation: Interfaces minimales et spécifiques
- **D**ependency Inversion: Dépendance aux abstractions

---

## 🏗️ Architecture

### Structure des fichiers

```
MT5/
├── common/
│   ├── JT_BaseStrategy.mqh         ⭐ Classe de base abstraite
│   ├── JT_StrategyFactory.mqh      🏭 Factory pour créer les stratégies
│   ├── JT_TradeFilters.mqh         🔍 Gestion centralisée des filtres
│   ├── JT_MoneyManagement.mqh      💰 Gestion du risque
│   ├── JT_Enums.mqh                📝 Énumérations communes
│   ├── JT_Indicators.mqh           📊 Gestion des indicateurs
│   ├── JT_Positions.mqh            📈 Gestion des positions
│   ├── JT_Utils.mqh                🔧 Utilitaires
│   ├── JT_TradeTracker.mqh         📋 Suivi des trades
│   └── JT_DivergenceValidator.mqh  🔀 Validation des divergences
│
├── strategies/
│   ├── JT_FreeCandleStrategy.mqh   🕯️ Stratégie Free Candle
│   ├── JT_BreakoutStrategy.mqh     💥 Stratégie Breakout
│   └── JT_MeanReversionStrategy.mqh 📉 Stratégie Mean Reversion
│
├── JTFreeCandle_v3.mq5             🤖 EA principal (v3)
└── JTFreeCandle.mq5                🤖 EA legacy (v1/v2)
```

### Diagramme de classes simplifié

```
┌─────────────────────┐
│  JTBaseStrategy     │  ← Classe abstraite
│  (Abstract)         │
├─────────────────────┤
│ + OnTick()          │  Template Method Pattern
│ + Init()            │
│ + Deinit()          │
│ # ExecuteTrade()    │
│ # ManagePositions() │
│ - DetectSignal()* = 0    │  ← Méthode virtuelle pure
│ - ValidateEntry()*  = 0  │  ← Méthode virtuelle pure
└──────────┬──────────┘
           │
           ├──────────────────┬──────────────────┬───────────────────
           │                  │                  │
┌──────────▼──────────┐ ┌─────▼─────────┐ ┌─────▼──────────────┐
│ FreeCandleStrategy  │ │ BreakoutStrat │ │ MeanReversionStrat │
├─────────────────────┤ ├───────────────┤ ├────────────────────┤
│ + DetectSignal()    │ │ + DetectSignal│ │ + DetectSignal()   │
│ + ValidateEntry()   │ │ ...           │ │ + CalculateLevels()│
│ - IsFreeCandle()    │ └───────────────┘ └────────────────────┘
└─────────────────────┘
```

---

## 📦 Hiérarchie des Classes

### 1. JTBaseStrategy (Classe abstraite)

**Rôle**: Fournir la logique commune à toutes les stratégies

**Responsabilités**:
- ✅ Gestion du cycle de vie (Init, Deinit, OnTick)
- ✅ Gestion des positions (ouverture, fermeture, modification)
- ✅ Calcul du risque et sizing
- ✅ Filtres temporels (heures, jours)
- ✅ Protection Daily Drawdown
- ✅ Suivi des trades (TradeTracker)

**Méthodes virtuelles pures** (à implémenter obligatoirement):
```cpp
virtual int DetectSignal() = 0;        // Détection du signal
virtual bool ValidateEntry(int) = 0;   // Validation avant entrée
```

**Méthodes virtuelles** (peuvent être overridées):
```cpp
virtual string GetStrategyName();
virtual bool InitStrategy();
virtual void DeinitStrategy();
virtual bool CalculateLevels(bool isBuy, double &sl, double &tp);
virtual void ManagePositionStrategy(ulong ticket);
```

### 2. JTFreeCandleStrategy

**Rôle**: Implémenter la stratégie Free Candle (bougies hors BB)

**Hérite de**: `JTBaseStrategy`

**Fonctionnalités spécifiques**:
- 🕯️ Détection des Free Candles (bougies hors Bollinger Bands)
- 📊 Filtres RSI, EMA, Divergence
- 🎯 Modes REVERSION et BREAKOUT
- 🎨 Marqueurs visuels sur le graphique

**Exemple d'utilisation**:
```cpp
JTFreeCandleStrategy* strategy = new JTFreeCandleStrategy(symbol, tf, magic);
strategy.SetBBParameters(20, 2.0, 5, true);
strategy.SetRSIParameters(14, 29, 71);
strategy.EnableRSIFilter(true);
strategy.Init();
```

### 3. JTBreakoutStrategy

**Rôle**: Stratégie de breakout avec confirmation

**Hérite de**: `JTFreeCandleStrategy` (réutilise la détection de Free Candle)

**Différences**:
- ✅ Override de `DetectSignal()` pour ajouter confirmation
- ✅ Vérifie que les barres précédentes étaient dans les bandes
- ✅ Force le mode ENTRY_BREAKOUT

### 4. JTMeanReversionStrategy

**Rôle**: Stratégie de retour à la moyenne

**Hérite de**: `JTBaseStrategy` (stratégie totalement différente)

**Fonctionnalités**:
- 📉 Trade le retour du prix vers la médiane BB
- 🎯 TP = Médiane BB (objectif de retour)
- 🛡️ SL = Bande opposée + marge
- 📊 Filtre RSI pour confirmer les extrêmes

### 5. JTStrategyFactory

**Rôle**: Factory pattern pour créer les stratégies

**Méthodes**:
```cpp
// Création simple
static JTBaseStrategy* CreateStrategy(ENUM_STRATEGY_TYPE, symbol, tf, magic);

// Création avec configuration complète
static JTFreeCandleStrategy* CreateFreeCandleStrategy(...); // 40+ paramètres
```

---

## 🚀 Guide d'utilisation

### Option 1: Utiliser l'EA v3 (recommandé)

L'EA `JTFreeCandle_v3.mq5` est déjà configuré pour utiliser la nouvelle architecture:

1. **Compiler** l'EA:
   ```
   MT5 > Tools > MetaQuotes Language Editor > Compile JTFreeCandle_v3.mq5
   ```

2. **Attacher** à un graphique

3. **Configurer** via les inputs:
   - Profil de stratégie (CONSERVATIVE, AGGRESSIVE, CUSTOM, etc.)
   - Paramètres BB, RSI, EMA
   - Risk Management
   - Filtres temporels et DD

4. **Lancer** le trading

### Option 2: Créer un EA personnalisé

```cpp
#include "common/JT_StrategyFactory.mqh"

JTBaseStrategy* strategy = NULL;

int OnInit()
{
   // Créer la stratégie
   strategy = JTStrategyFactory::CreateStrategy(
      STRATEGY_FREE_CANDLE,
      _Symbol,
      PERIOD_CURRENT,
      123456
   );
   
   if(strategy == NULL) return INIT_FAILED;
   
   // Configurer
   strategy.SetRiskPercent(0.5);
   strategy.SetMinRR(2.0);
   strategy.EnableRSIFilter(true);
   
   // Initialiser
   if(!strategy.Init()) {
      delete strategy;
      return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(strategy != NULL) {
      strategy.Deinit();
      delete strategy;
   }
}

void OnTick()
{
   if(strategy != NULL) {
      strategy.OnTick();
   }
}
```

---

## 🔨 Créer une nouvelle stratégie

### Méthode 1: Hériter de JTFreeCandleStrategy

Pour une stratégie similaire à FreeCandle mais avec des variations:

```cpp
#include "JT_FreeCandleStrategy.mqh"

class MyCustomStrategy : public JTFreeCandleStrategy
{
public:
   MyCustomStrategy(string symbol, ENUM_TIMEFRAMES tf, ulong magic) 
      : JTFreeCandleStrategy(symbol, tf, magic) {}
   
   // Override uniquement ce qui change
   virtual string GetStrategyName() override {
      return "MyCustom";
   }
   
   virtual int DetectSignal() override {
      // Votre logique de détection
      // Vous pouvez appeler JTFreeCandleStrategy::DetectSignal()
      // ou implémenter une logique totalement nouvelle
   }
};
```

### Méthode 2: Hériter de JTBaseStrategy

Pour une stratégie complètement différente:

```cpp
#include "../common/JT_BaseStrategy.mqh"

class MyNewStrategy : public JTBaseStrategy
{
public:
   MyNewStrategy(string symbol, ENUM_TIMEFRAMES tf, ulong magic) 
      : JTBaseStrategy(symbol, tf, magic) {}
   
   virtual string GetStrategyName() override {
      return "MyNew";
   }
   
   virtual bool InitStrategy() override {
      // Initialiser vos indicateurs spécifiques
      return true;
   }
   
   virtual int DetectSignal() override {
      // Votre logique de détection
      // Retourner: +1 (BUY), -1 (SELL), 0 (NONE)
   }
   
   virtual bool ValidateEntry(int signal) override {
      // Vos filtres de validation
      return true;
   }
};
```

### Exemple complet: Stratégie RSI simple

```cpp
class JTRSIStrategy : public JTBaseStrategy
{
private:
   int m_rsiPeriod;
   double m_oversold;
   double m_overbought;
   
public:
   JTRSIStrategy(string symbol, ENUM_TIMEFRAMES tf, ulong magic) 
      : JTBaseStrategy(symbol, tf, magic) {
      m_rsiPeriod = 14;
      m_oversold = 30;
      m_overbought = 70;
   }
   
   void SetRSIParameters(int period, double oversold, double overbought) {
      m_rsiPeriod = period;
      m_oversold = oversold;
      m_overbought = overbought;
   }
   
   virtual string GetStrategyName() override {
      return "RSI_Simple";
   }
   
   virtual bool InitStrategy() override {
      // Initialiser le RSI
      if(!InitIndicators(m_indicators, m_symbol, m_timeframe, 
                        20, 2.0, 0, m_rsiPeriod)) {
         return false;
      }
      return true;
   }
   
   virtual int DetectSignal() override {
      // Récupérer le RSI
      if(!GetIndicatorData(m_indicators, m_buffers, 2, false)) return 0;
      
      double rsi = m_buffers.RSI[1];
      
      // Signal BUY si survente
      if(rsi < m_oversold) return +1;
      
      // Signal SELL si surachat
      if(rsi > m_overbought) return -1;
      
      return 0;
   }
   
   virtual bool ValidateEntry(int signal) override {
      // Validation simple (peut être étendue)
      return (signal != 0);
   }
};
```

---

## 🎨 Patterns de conception

### 1. Template Method Pattern

La méthode `OnTick()` définit le squelette de l'algorithme:

```cpp
void OnTick()
{
   // 1. Vérifier les filtres temporels
   if(!IsHourAllowed() || !IsDayAllowed()) return;
   
   // 2. Vérifier le Daily Drawdown
   if(CheckDailyDDLimit()) return;
   
   // 3. Gérer les positions ouvertes
   ManageOpenPositions();
   
   // 4. Détection de nouvelle bougie
   if(NewBar()) {
      int signal = DetectSignal();        // ← Implémenté par stratégie
      if(signal != 0 && ValidateEntry(signal)) {  // ← Implémenté par stratégie
         ExecuteTrade(signal);            // ← Méthode commune
      }
   }
}
```

### 2. Strategy Pattern

Chaque stratégie implémente sa propre logique de détection/validation:

```cpp
// Stratégie A: Free Candle
int DetectSignal() {
   return IsFreeCandle() ? signal : 0;
}

// Stratégie B: Breakout
int DetectSignal() {
   return IsBreakoutConfirmed() ? signal : 0;
}

// Stratégie C: Mean Reversion
int DetectSignal() {
   return IsFarFromMean() ? signal : 0;
}
```

### 3. Factory Pattern

Création centralisée des stratégies:

```cpp
JTBaseStrategy* strategy = JTStrategyFactory::CreateStrategy(
   STRATEGY_FREE_CANDLE,  // Type
   "XAUUSD",              // Symbol
   PERIOD_M5,             // Timeframe
   123456                 // Magic
);
```

### 4. Composition over Inheritance

Les filtres sont composés via `JTTradeFilters` au lieu d'être hérités:

```cpp
class JTFreeCandleStrategy : public JTBaseStrategy
{
private:
   JTTradeFilters* m_filters;  // ← Composition
   
public:
   bool ValidateEntry(int signal) {
      return m_filters.CheckEMAFilter(signal) &&
             m_filters.CheckRSIFilter(signal, rsi);
   }
};
```

---

## 🔄 Migration depuis v1/v2

### Différences principales

| Aspect | v1/v2 (Legacy) | v3 (OOP) |
|--------|----------------|----------|
| **Structure** | Monolithique (1300+ lignes) | Modulaire (classes séparées) |
| **Réutilisation** | Copier-coller | Héritage et composition |
| **Extension** | Modifier le code existant | Créer nouvelle classe |
| **Testing** | Difficile | Facile (classes isolées) |
| **Maintenance** | Code répété | DRY (Don't Repeat Yourself) |

### Équivalences de code

#### v1/v2: Logique dans l'EA
```cpp
int OnInit() {
   // 100+ lignes d'initialisation
   Magic = GenerateMagicNumber(s, t);
   InitIndicators(...);
   if(Use_EMA_Filter) { ... }
   // etc.
}

void OnTick() {
   // 200+ lignes de logique
   if(!IsHourAllowed()) return;
   if(CheckDailyDDLimit()) return;
   ManageOpenPositions();
   if(NewBar()) Process();
}

void Process() {
   int signal = SignalFromClosedBarStrict();
   if(signal && ValidateFilters(signal)) {
      ExecuteTrade(signal);
   }
}
```

#### v3: Logique dans les classes
```cpp
int OnInit() {
   strategy = JTStrategyFactory::CreateFreeCandleStrategy(...);
   return strategy.Init() ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
   if(strategy != NULL) {
      strategy.OnTick();  // Délègue tout à la stratégie
   }
}
```

### Avantages de v3

✅ **EA principal**: 150 lignes (vs 1300+ avant)  
✅ **Ajout d'une stratégie**: ~100 lignes (vs 500+ avant)  
✅ **Réutilisation**: Héritage (vs copier-coller)  
✅ **Testing**: Classes isolées (vs tout tester ensemble)  
✅ **Maintenance**: Modification localisée (vs impact global)  

---

## 📊 Comparaison des performances

| Métrique | v1/v2 | v3 |
|----------|-------|-----|
| **Lignes de code EA** | 1350 | 150 |
| **Temps ajout stratégie** | 4-8h | 1-2h |
| **Duplication de code** | Élevée | Minimale |
| **Testabilité** | Faible | Élevée |
| **Courbe d'apprentissage** | Moyenne | Élevée (OOP) |

---

## 🎓 Bonnes pratiques

### 1. Toujours hériter de la base appropriée

- Stratégie **similaire** à FreeCandle → Hériter de `JTFreeCandleStrategy`
- Stratégie **totalement différente** → Hériter de `JTBaseStrategy`

### 2. Override uniquement ce qui change

Ne pas réimplémenter la logique commune déjà dans la base:

```cpp
// ❌ Mauvais: réimplémenter la gestion des positions
virtual void OnTick() override {
   // Réimplémenter tout...
}

// ✅ Bon: override uniquement la détection
virtual int DetectSignal() override {
   // Seulement votre logique de signal
}
```

### 3. Utiliser la factory pour créer

```cpp
// ❌ Mauvais: instanciation directe avec configuration manuelle
JTFreeCandleStrategy* strategy = new JTFreeCandleStrategy(s, tf, magic);
strategy.SetBBParameters(...);
strategy.SetRSIParameters(...);
// ... 20+ lignes de configuration

// ✅ Bon: utiliser la factory
JTFreeCandleStrategy* strategy = 
   JTStrategyFactory::CreateFreeCandleStrategy(...); // Tout configuré
```

### 4. Logger les informations importantes

```cpp
virtual int DetectSignal() override {
   int signal = CalculateMySignal();
   
   if(signal != 0) {
      LogMessage("Signal détecté: " + (signal > 0 ? "BUY" : "SELL") + 
                " - Raison: " + GetSignalReason());
   }
   
   return signal;
}
```

---

## 🐛 Dépannage

### Erreur: "abstract class cannot be instantiated"

**Cause**: Tentative d'instancier `JTBaseStrategy` directement

**Solution**: Utiliser une classe dérivée concrète:
```cpp
// ❌ Erreur
JTBaseStrategy* strategy = new JTBaseStrategy(s, tf, magic);

// ✅ OK
JTBaseStrategy* strategy = new JTFreeCandleStrategy(s, tf, magic);
```

### Erreur: "must override pure virtual functions"

**Cause**: Classe dérivée n'implémente pas toutes les méthodes virtuelles pures

**Solution**: Implémenter `DetectSignal()` et `ValidateEntry()`:
```cpp
class MyStrategy : public JTBaseStrategy
{
   virtual int DetectSignal() override { /* ... */ }
   virtual bool ValidateEntry(int signal) override { /* ... */ }
};
```

### Les trades ne s'ouvrent pas

**Vérifier**:
1. `DetectSignal()` retourne bien +1 ou -1
2. `ValidateEntry()` retourne bien `true`
3. Les filtres (temps, DD, direction) ne bloquent pas
4. Les logs dans le journal Expert

---

## 📚 Ressources

- **Code source**: `/MT5/`
- **Exemples de stratégies**: `/MT5/strategies/`
- **Documentation originale**: `/MT5/docs/README_V2.md`
- **Guide de trading**: `/MT5/docs/QUICK_START_V2.md`

---

## 🎯 Prochaines étapes

1. ✅ Tester `JTFreeCandle_v3.mq5` en démo
2. ✅ Créer votre première stratégie personnalisée
3. ✅ Comparer les performances avec v1/v2
4. ✅ Contribuer avec de nouvelles stratégies

---

**Architecture développée en 2025** | Licence: MIT  
**Auteur**: JTrading Framework  
**Version**: 3.0.0

