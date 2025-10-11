# Trade Tracker - Exemples Pratiques

## 📦 Utilisation Standard (Sans Divergence)

### Code de base

```cpp
#include "common/JT_TradeTracker.mqh"

// Déclaration globale
JTTradeTracker* tracker = NULL;

int OnInit() {
   // Initialiser le tracker
   tracker = new JTTradeTracker(
      Symbol(),           // Symbole
      12345,              // Magic number
      20,                 // BB period
      2.0,                // BB deviation
      14,                 // RSI period
      50,                 // EMA fast
      100                 // EMA slow
   );
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   // Afficher le rapport et libérer
   if(tracker != NULL) {
      tracker.PrintReport();
      delete tracker;
      tracker = NULL;
   }
}

void OnTick() {
   // Mettre à jour les trades ouverts
   if(tracker != NULL) {
      for(int i = PositionsTotal()-1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == 12345) {
               tracker.UpdateTrade(ticket);
            }
         }
      }
   }
   
   // Gérer les positions...
   ManageOpenPositions();
   
   // Vérifier les fermetures automatiques
   CheckClosedTrades();
   
   // Votre logique de trading...
}

// Quand vous ouvrez un trade
void OpenTrade(int direction) {
   // Ouvrir la position
   if(direction > 0) {
      trade.Buy(lots, symbol, ask, sl, tp, "BUY signal");
   } else {
      trade.Sell(lots, symbol, bid, sl, tp, "SELL signal");
   }
   
   // Enregistrer dans le tracker
   if(trade.ResultOrder() > 0 && tracker != NULL) {
      tracker.RecordTradeOpen(
         trade.ResultOrder(),    // Ticket
         "REVERSION",            // Mode
         false,                  // Pas de divergence
         "TREND"                 // Mode EMA
      );
   }
}

// Quand vous fermez manuellement un trade
void CloseTrade(ulong ticket, string reason) {
   if(trade.PositionClose(ticket)) {
      if(tracker != NULL) {
         tracker.RecordTradeClose(ticket, reason);
      }
   }
}

// Vérifier les fermetures automatiques (SL/TP)
void CheckClosedTrades() {
   if(tracker == NULL) return;
   
   static datetime lastCheck = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastCheck < 30) return;
   lastCheck = currentTime;
   
   if(!HistorySelect(currentTime - 86400, currentTime)) return;
   
   uint totalDeals = HistoryDealsTotal();
   
   for(uint i = 0; i < totalDeals; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == 12345 &&
         HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         
         ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
         string reason = "";
         
         if(StringFind(comment, "tp") >= 0 || StringFind(comment, "TP") >= 0)
            reason = "TP";
         else if(StringFind(comment, "sl") >= 0 || StringFind(comment, "SL") >= 0)
            reason = "SL";
         else
            reason = "Auto Close";
         
         tracker.RecordTradeClose(posTicket, reason);
      }
   }
}
```

---

## 📈 Utilisation Avancée (Avec Divergence)

### Code complet avec validation de divergence

```cpp
#include "common/JT_TradeTracker.mqh"
#include "common/JT_DivergenceValidator.mqh"

// Déclarations globales
JTTradeTracker* tracker = NULL;
JTDivergenceValidator divValidator;

int OnInit() {
   // Initialiser le tracker
   tracker = new JTTradeTracker(
      Symbol(),
      12345,
      20, 2.0,
      14,
      50, 100
   );
   
   // Initialiser le validateur de divergence
   if(!divValidator.Init(
      Symbol(),
      PERIOD_CURRENT,
      14,          // RSI period
      35.0,        // RSI Buy level
      65.0,        // RSI Sell level
      5            // Swing length
   )) {
      Print("Erreur initialisation divergence validator");
      return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

void OnTick() {
   // Mettre à jour les trades ouverts
   if(tracker != NULL) {
      for(int i = PositionsTotal()-1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == 12345) {
               tracker.UpdateTrade(ticket);
            }
         }
      }
   }
   
   // Détecter nouvelle barre
   static datetime last_bar = 0;
   if(!NewBar(Symbol(), PERIOD_CURRENT, last_bar)) return;
   
   // Détecter un Free Candle
   int signal = DetectFreeCandle();
   
   if(signal != 0) {
      // Mémoriser le Free Candle pour validation future
      double priceLevel = (signal > 0) ? SymbolInfoDouble(Symbol(), SYMBOL_BID) 
                                        : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      divValidator.RememberFreeCandle(1, priceLevel, signal);
      Print("Free Candle mémorisé, attente divergence...");
      return;
   }
   
   // Valider la divergence
   int divSignal = divValidator.ValidateDivergence();
   if(divSignal != 0) {
      Print("✓ DIVERGENCE VALIDÉE !");
      
      // Exécuter le trade
      ExecuteTrade(divSignal);
      
      // IMPORTANT : Enregistrer les métriques de divergence
      if(tracker != NULL) {
         tracker.SetDivergenceData(
            divValidator.GetLastDivergenceAngle(),      // Angle en degrés
            divValidator.GetLastDivergenceStrength(),   // Force
            divValidator.GetLastDivergenceBars()        // Nombre de barres
         );
         
         Print("Métriques divergence enregistrées: ",
               "Angle=", divValidator.GetLastDivergenceAngle(), "°, ",
               "Force=", divValidator.GetLastDivergenceStrength(), ", ",
               "Bars=", divValidator.GetLastDivergenceBars());
      }
   }
}

void ExecuteTrade(int direction) {
   // Calculer SL/TP...
   double sl = CalculateSL(direction);
   double tp = CalculateTP(direction);
   double lots = CalculateLots(sl);
   
   // Ouvrir la position
   if(direction > 0) {
      trade.Buy(lots, Symbol(), ask, sl, tp, "DIV BUY");
   } else {
      trade.Sell(lots, Symbol(), bid, sl, tp, "DIV SELL");
   }
   
   // Enregistrer dans le tracker
   if(trade.ResultOrder() > 0 && tracker != NULL) {
      tracker.RecordTradeOpen(
         trade.ResultOrder(),
         "REVERSION",
         true,              // ← Divergence = true
         "COUNTER"
      );
      
      Print("Trade enregistré avec divergence, ticket=", trade.ResultOrder());
   }
}
```

---

## 📊 Analyse des Résultats

### Lire le fichier CSV avec Python

```python
import pandas as pd
import matplotlib.pyplot as plt

# Charger les données
df = pd.read_csv('TradeAnalysis_EURUSD_H1_20241001_20241231.csv')

print("=== APERÇU DES DONNÉES ===")
print(df.head())
print(f"\nTotal trades: {len(df)}")
print(f"Colonnes: {df.columns.tolist()}")

# ============================================
# ANALYSE PAR TENDANCE EMA
# ============================================
print("\n=== PERFORMANCE PAR TENDANCE EMA ===")
ema_analysis = df.groupby('EMATrend').agg({
    'Profit': ['count', 'sum', 'mean'],
    'ActualRR': 'mean'
}).round(2)
print(ema_analysis)

# ============================================
# ANALYSE PAR POSITION PRIX/EMA
# ============================================
print("\n=== PERFORMANCE PAR POSITION PRIX/EMA ===")
position_analysis = df.groupby('PriceVsEMA').agg({
    'Profit': ['count', 'sum', 'mean'],
    'ActualRR': 'mean'
}).round(2)
print(position_analysis)

# ============================================
# ANALYSE DES DIVERGENCES
# ============================================
print("\n=== ANALYSE DES DIVERGENCES ===")
div_trades = df[df['Divergence'] == 'YES']
no_div_trades = df[df['Divergence'] == 'NO']

print(f"Trades avec divergence: {len(div_trades)}")
print(f"Trades sans divergence: {len(no_div_trades)}")

if len(div_trades) > 0:
    print(f"\nAvec divergence:")
    print(f"  Win rate: {(div_trades['Profit'] > 0).mean() * 100:.1f}%")
    print(f"  Profit moyen: ${div_trades['Profit'].mean():.2f}")
    print(f"  RR moyen: {div_trades['ActualRR'].mean():.2f}")
    print(f"  Angle moyen: {div_trades['DivAngle'].mean():.2f}°")
    print(f"  Force moyenne: {div_trades['DivStrength'].mean():.6f}")
    print(f"  Barres moyennes: {div_trades['DivBars'].mean():.0f}")

if len(no_div_trades) > 0:
    print(f"\nSans divergence:")
    print(f"  Win rate: {(no_div_trades['Profit'] > 0).mean() * 100:.1f}%")
    print(f"  Profit moyen: ${no_div_trades['Profit'].mean():.2f}")
    print(f"  RR moyen: {no_div_trades['ActualRR'].mean():.2f}")

# ============================================
# FILTRER LES DIVERGENCES FORTES
# ============================================
print("\n=== DIVERGENCES FORTES (Angle > 30°, Strength > 0.0001) ===")
strong_div = div_trades[
    (div_trades['DivAngle'] > 30) & 
    (div_trades['DivStrength'] > 0.0001)
]

if len(strong_div) > 0:
    print(f"Nombre: {len(strong_div)}")
    print(f"Win rate: {(strong_div['Profit'] > 0).mean() * 100:.1f}%")
    print(f"Profit total: ${strong_div['Profit'].sum():.2f}")
    print(f"RR moyen: {strong_div['ActualRR'].mean():.2f}")

# ============================================
# GRAPHIQUES
# ============================================
fig, axes = plt.subplots(2, 2, figsize=(15, 10))

# 1. Distribution des profits (avec/sans divergence)
axes[0, 0].hist([no_div_trades['Profit'], div_trades['Profit']], 
                label=['Sans divergence', 'Avec divergence'],
                bins=20, alpha=0.7)
axes[0, 0].set_title('Distribution des Profits')
axes[0, 0].set_xlabel('Profit ($)')
axes[0, 0].legend()
axes[0, 0].axvline(x=0, color='red', linestyle='--', alpha=0.5)

# 2. Performance par position prix/EMA
position_profit = df.groupby('PriceVsEMA')['Profit'].sum()
axes[0, 1].bar(position_profit.index, position_profit.values)
axes[0, 1].set_title('Profit Total par Position Prix/EMA')
axes[0, 1].set_xlabel('Position')
axes[0, 1].set_ylabel('Profit ($)')
axes[0, 1].axhline(y=0, color='red', linestyle='--', alpha=0.5)

# 3. Relation Angle vs Profit (divergences uniquement)
if len(div_trades) > 0:
    colors = ['green' if p > 0 else 'red' for p in div_trades['Profit']]
    axes[1, 0].scatter(div_trades['DivAngle'], div_trades['Profit'], 
                       c=colors, alpha=0.6)
    axes[1, 0].set_title('Angle de Divergence vs Profit')
    axes[1, 0].set_xlabel('Angle (degrés)')
    axes[1, 0].set_ylabel('Profit ($)')
    axes[1, 0].axhline(y=0, color='black', linestyle='--', alpha=0.3)

# 4. Performance par tendance EMA
trend_profit = df.groupby('EMATrend')['Profit'].sum()
axes[1, 1].bar(trend_profit.index, trend_profit.values, color=['red', 'green'])
axes[1, 1].set_title('Profit Total par Tendance EMA')
axes[1, 1].set_xlabel('Tendance')
axes[1, 1].set_ylabel('Profit ($)')
axes[1, 1].axhline(y=0, color='black', linestyle='--', alpha=0.3)

plt.tight_layout()
plt.savefig('trade_analysis.png', dpi=150)
plt.show()

print("\n✓ Graphiques sauvegardés dans 'trade_analysis.png'")
```

---

## 🎯 Optimisation Basée sur les Métriques

### Trouver les meilleurs paramètres

```python
# Trouver la configuration optimale
print("\n=== CONFIGURATION OPTIMALE ===")

# Grouper par tous les facteurs
optimal = df.groupby(['EMATrend', 'PriceVsEMA', 'Divergence']).agg({
    'Profit': ['count', 'sum', 'mean'],
    'ActualRR': 'mean'
}).round(2)

# Filtrer les configurations avec au moins 10 trades
optimal = optimal[optimal[('Profit', 'count')] >= 10]

# Trier par profit total
optimal = optimal.sort_values(('Profit', 'sum'), ascending=False)

print("\nTop 5 configurations:")
print(optimal.head())

# Recommandations
print("\n=== RECOMMANDATIONS ===")
best_config = optimal.index[0]
print(f"Meilleure configuration:")
print(f"  - Tendance EMA: {best_config[0]}")
print(f"  - Position prix: {best_config[1]}")
print(f"  - Divergence: {best_config[2]}")
print(f"  - Profit total: ${optimal.iloc[0][('Profit', 'sum')]:.2f}")
print(f"  - Nombre de trades: {int(optimal.iloc[0][('Profit', 'count')])}")
```

---

## 📝 Checklist d'Intégration

### Étape 1 : Installation
- [x] Copier le nouveau `JT_TradeTracker.mqh`
- [x] Copier le nouveau `JT_DivergenceValidator.mqh`
- [x] Compiler les fichiers

### Étape 2 : Intégration de base
- [ ] Déclarer `JTTradeTracker* tracker = NULL;`
- [ ] Initialiser dans `OnInit()`
- [ ] Libérer dans `OnDeinit()`
- [ ] Appeler `UpdateTrade()` dans `OnTick()`
- [ ] Appeler `RecordTradeOpen()` après ouverture
- [ ] Appeler `RecordTradeClose()` après fermeture
- [ ] Implémenter `CheckClosedTrades()`

### Étape 3 : Intégration divergence (optionnel)
- [ ] Déclarer `JTDivergenceValidator divValidator;`
- [ ] Initialiser dans `OnInit()`
- [ ] Appeler `ValidateDivergence()` dans `OnTick()`
- [ ] Appeler `SetDivergenceData()` après validation

### Étape 4 : Tests
- [ ] Lancer un backtest
- [ ] Vérifier la création du fichier CSV
- [ ] Vérifier les colonnes (39 au total)
- [ ] Vérifier le format du nom de fichier
- [ ] Analyser les résultats avec Python

---

## 🐛 Débogage

### Problème : Le fichier CSV n'est pas créé

```cpp
// Vérifier dans OnInit()
if(tracker != NULL) {
   Print("Tracker initialisé avec succès");
} else {
   Print("ERREUR: Tracker non initialisé !");
}
```

### Problème : Les métriques de divergence sont à 0

```cpp
// Après validation de divergence
if(divSignal != 0) {
   Print("Divergence détectée !");
   Print("Angle: ", divValidator.GetLastDivergenceAngle());
   Print("Force: ", divValidator.GetLastDivergenceStrength());
   Print("Bars: ", divValidator.GetLastDivergenceBars());
   
   // Vérifier que SetDivergenceData est appelé
   if(tracker != NULL) {
      tracker.SetDivergenceData(...);
      Print("Métriques enregistrées");
   }
}
```

### Problème : Le fichier n'est pas renommé

```cpp
// Le renommage se fait automatiquement :
// 1. Au premier trade ouvert
// 2. À chaque fermeture de trade

// Vérifier les logs
Print("Fichier CSV actuel: ", tracker.GetCSVFileName());
```

---

## 📚 Ressources

- **Guide complet** : `TRADE_TRACKER_ENRICHMENT.md`
- **Documentation divergence** : `DIVERGENCE_VALIDATOR_README.md`
- **Exemples** : Ce fichier

Date de mise à jour : 2025-10-11
Version : 2.0

