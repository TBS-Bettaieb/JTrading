# Guide de Démarrage Rapide - Architecture v3.0

## 🚀 Démarrage en 5 minutes

### Étape 1: Compiler l'EA v3

1. Ouvrir **MetaEditor** (F4 depuis MT5)
2. Naviguer vers `Experts/JTrading/MT5/JTFreeCandle_v3.mq5`
3. Compiler (F7)
4. Vérifier qu'il n'y a pas d'erreurs

✅ **Résultat**: Fichier `JTFreeCandle_v3.ex5` créé

### Étape 2: Attacher à un graphique

1. Ouvrir un graphique (ex: XAUUSD M5)
2. Glisser-déposer `JTFreeCandle_v3` depuis le navigateur
3. Configurer les inputs:
   - **Strategy_Profile**: PROFILE_CUSTOM (ou un profil prédéfini)
   - **Risk_Percent**: 0.5 (ou selon votre tolérance)
   - **Min_RR**: 2.0
4. Activer **AutoTrading** (F7)

✅ **Résultat**: EA actif et prêt à trader

### Étape 3: Vérifier les logs

Dans l'onglet **Expert**, vérifier:

```
═══════════════════════════════════════════════════
  JTFreeCandle v3.0 - Architecture Modulaire
═══════════════════════════════════════════════════
Magic number: 123456 pour XAUUSD M5
Factory: Stratégie FreeCandle créée pour XAUUSD
✓ Stratégie FreeCandle initialisée avec succès
✓ EA initialisé avec succès - Prêt au trading
═══════════════════════════════════════════════════
```

✅ **Résultat**: Stratégie initialisée correctement

---

## 🎯 Tester les Différentes Stratégies

### Test 1: Stratégie FreeCandle

**Utiliser**: `JTFreeCandle_v3.mq5`

**Configuration recommandée**:
```
Strategy_Profile = PROFILE_CUSTOM
BB_Period = 20
BB_Dev = 2.0
Use_RSI_Filter = true
RSI_Oversold = 29
RSI_Overbought = 71
Mode = ENTRY_REVERSION
```

**Ce que ça fait**: Trade les bougies hors Bollinger en mode reversion

### Test 2: Stratégie Breakout

**Utiliser**: `JTStrategy_Test.mq5`

**Configuration**:
```
Strategy_Type = STRATEGY_BREAKOUT
Risk_Percent = 0.5
Min_RR = 2.0
```

**Ce que ça fait**: Trade les breakouts confirmés des bandes BB

### Test 3: Stratégie Mean Reversion

**Utiliser**: `JTStrategy_Test.mq5`

**Configuration**:
```
Strategy_Type = STRATEGY_MEAN_REVERSION
Risk_Percent = 0.5
Min_RR = 1.5
```

**Ce que ça fait**: Trade le retour du prix vers la médiane BB

---

## 🔧 Créer Votre Première Stratégie (10 minutes)

### Stratégie Simple: Cross de 2 EMAs

1. **Créer le fichier** `strategies/JT_MACrossStrategy.mqh`:

```cpp
#include "../common/JT_BaseStrategy.mqh"

class JTMACrossStrategy : public JTBaseStrategy
{
private:
   int m_emaFastHandle;
   int m_emaSlowHandle;
   int m_emaFastPeriod;
   int m_emaSlowPeriod;
   
public:
   JTMACrossStrategy(string symbol, ENUM_TIMEFRAMES tf, ulong magic) 
      : JTBaseStrategy(symbol, tf, magic)
   {
      m_emaFastPeriod = 12;
      m_emaSlowPeriod = 26;
      m_emaFastHandle = INVALID_HANDLE;
      m_emaSlowHandle = INVALID_HANDLE;
   }
   
   ~JTMACrossStrategy()
   {
      if(m_emaFastHandle != INVALID_HANDLE) IndicatorRelease(m_emaFastHandle);
      if(m_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(m_emaSlowHandle);
   }
   
   virtual string GetStrategyName() override { return "MACross"; }
   
   virtual bool InitStrategy() override
   {
      m_emaFastHandle = iMA(m_symbol, m_timeframe, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_emaSlowHandle = iMA(m_symbol, m_timeframe, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      if(m_emaFastHandle == INVALID_HANDLE || m_emaSlowHandle == INVALID_HANDLE) {
         LogError("Erreur d'initialisation des EMAs");
         return false;
      }
      
      LogMessage("Stratégie MACross initialisée: EMA" + IntegerToString(m_emaFastPeriod) + 
                 " / EMA" + IntegerToString(m_emaSlowPeriod));
      return true;
   }
   
   virtual int DetectSignal() override
   {
      double emaFast[], emaSlow[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);
      
      if(CopyBuffer(m_emaFastHandle, 0, 0, 3, emaFast) < 3) return 0;
      if(CopyBuffer(m_emaSlowHandle, 0, 0, 3, emaSlow) < 3) return 0;
      
      // Détection du cross
      bool crossUp = (emaFast[1] > emaSlow[1]) && (emaFast[2] <= emaSlow[2]);
      bool crossDown = (emaFast[1] < emaSlow[1]) && (emaFast[2] >= emaSlow[2]);
      
      if(crossUp) {
         LogMessage("EMA Cross UP détecté - Signal BUY");
         return +1;
      }
      
      if(crossDown) {
         LogMessage("EMA Cross DOWN détecté - Signal SELL");
         return -1;
      }
      
      return 0;
   }
   
   virtual bool ValidateEntry(int signal) override
   {
      // Validation simple - peut être étendue
      return (signal != 0);
   }
};
```

2. **Ajouter à la Factory** `common/JT_StrategyFactory.mqh`:

```cpp
// Dans les includes
#include "../strategies/JT_MACrossStrategy.mqh"

// Dans l'enum
enum ENUM_STRATEGY_TYPE
{
   STRATEGY_FREE_CANDLE,
   STRATEGY_BREAKOUT,
   STRATEGY_MEAN_REVERSION,
   STRATEGY_MA_CROSS,        // ← Nouveau
   STRATEGY_CUSTOM
};

// Dans CreateStrategy()
case STRATEGY_MA_CROSS:
   strategy = new JTMACrossStrategy(symbol, tf, magic);
   LogMessage("Factory: Stratégie MACross créée pour " + symbol);
   break;
```

3. **Utiliser dans un EA**:

```cpp
#include "common/JT_StrategyFactory.mqh"

JTBaseStrategy* strategy = NULL;

int OnInit()
{
   strategy = JTStrategyFactory::CreateStrategy(
      STRATEGY_MA_CROSS,
      _Symbol,
      PERIOD_CURRENT,
      123456
   );
   
   if(strategy == NULL || !strategy.Init()) return INIT_FAILED;
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
   if(strategy != NULL) strategy.OnTick();
}
```

4. **Compiler et tester**

✅ **Résultat**: Stratégie MA Cross fonctionnelle en ~50 lignes de code !

---

## 📊 Comparer v2 vs v3

### Test de validation

Pour vérifier que v3 fonctionne comme v2:

1. **Ouvrir 2 comptes démo**:
   - Compte A: `JTFreeCandle.mq5` (v2) avec Magic 111111
   - Compte B: `JTFreeCandle_v3.mq5` (v3) avec Magic 222222

2. **Configurer identiquement**:
   - Même symbole (ex: XAUUSD)
   - Même timeframe (ex: M5)
   - Mêmes paramètres (BB, RSI, EMA, etc.)

3. **Lancer pendant 1 semaine**

4. **Comparer les résultats**:
   - Nombre de trades
   - Prix d'entrée
   - SL/TP
   - Profits

✅ **Résultat attendu**: Trades identiques (à quelques microsecondes près)

---

## 🎨 Customisation Rapide

### Modifier les paramètres par défaut

**Dans `JT_BaseStrategy.mqh`**:

```cpp
// Modifier le risque par défaut
m_riskPercent = 0.5;  // ← Changer ici

// Modifier le RR minimum
m_minRR = 2.0;  // ← Changer ici
```

### Ajouter un nouveau filtre

**Dans `JT_FreeCandleStrategy.mqh`**:

```cpp
virtual bool ValidateEntry(int signal) override
{
   // Filtres existants
   if(!JTFreeCandleStrategy::ValidateEntry(signal)) {
      return false;
   }
   
   // Votre nouveau filtre
   if(!MyCustomFilter(signal)) {
      LogMessage("Signal rejeté par filtre personnalisé");
      return false;
   }
   
   return true;
}

bool MyCustomFilter(int signal)
{
   // Votre logique
   return true;
}
```

### Modifier le calcul SL/TP

**Dans votre stratégie dérivée**:

```cpp
virtual bool CalculateLevels(bool isBuy, double &sl, double &tp) override
{
   // Votre logique personnalisée
   sl = CalculateMyCustomSL(isBuy);
   tp = CalculateMyCustomTP(isBuy);
   return true;
}
```

---

## 🐛 Dépannage Rapide

### Problème: EA ne compile pas

**Erreur**: "cannot open include file"

**Solution**: Vérifier les chemins d'include:
```cpp
#include "common/JT_BaseStrategy.mqh"  // ✅ Bon
#include "JT_BaseStrategy.mqh"         // ❌ Mauvais
```

### Problème: Pas de trades

**Vérifier**:
1. AutoTrading activé (F7)
2. Filtres horaires/jours ne bloquent pas
3. Daily Drawdown non atteint
4. Logs dans l'onglet Expert

**Debug**:
```cpp
virtual int DetectSignal() override
{
   int signal = MyDetection();
   LogMessage("DetectSignal() retourne: " + IntegerToString(signal));
   return signal;
}
```

### Problème: Stratégie non trouvée

**Erreur**: "Stratégie XXX non encore implémentée"

**Solution**: Vérifier que la stratégie est ajoutée à la factory:
```cpp
case STRATEGY_XXX:
   strategy = new JTXXXStrategy(symbol, tf, magic);
   break;
```

---

## 📚 Ressources

### Documentation
- 📖 **Architecture complète**: `docs/ARCHITECTURE_V3.md`
- 🔄 **Guide de migration**: `docs/MIGRATION_GUIDE_V3.md`
- 📊 **Résumé refactoring**: `REFACTORING_V3_SUMMARY.md`

### Code source
- 🏗️ **Classe de base**: `common/JT_BaseStrategy.mqh`
- 🏭 **Factory**: `common/JT_StrategyFactory.mqh`
- 📈 **Stratégies**: `strategies/JT_*.mqh`

### Exemples
- 🕯️ **FreeCandle**: `strategies/JT_FreeCandleStrategy.mqh`
- 💥 **Breakout**: `strategies/JT_BreakoutStrategy.mqh`
- 📉 **MeanReversion**: `strategies/JT_MeanReversionStrategy.mqh`

---

## ✅ Checklist de Démarrage

Avant de trader en réel:

- [ ] Compiler sans erreurs
- [ ] Tester en démo pendant 1 semaine minimum
- [ ] Vérifier la parité avec v2 (si migration)
- [ ] Valider les niveaux SL/TP
- [ ] Tester la protection Daily Drawdown
- [ ] Vérifier les filtres horaires
- [ ] Analyser les logs de trading
- [ ] Backtester sur historique
- [ ] Documenter vos paramètres optimaux

---

## 🎯 Next Steps

1. ✅ Tester `JTFreeCandle_v3.mq5`
2. ✅ Créer votre première stratégie
3. ✅ Optimiser les paramètres
4. ✅ Partager vos stratégies

**Bon trading avec l'architecture v3.0 !** 🚀

---

**Version**: 3.0.0 | **Dernière mise à jour**: 2025  
**Support**: Consultez `ARCHITECTURE_V3.md` pour plus de détails

